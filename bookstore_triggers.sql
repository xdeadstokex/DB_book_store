USE book_store;
GO

-- ======================================================
-- TRIGGER A: Validate Book Data (Universal Rules)
-- Enforces: Year, Pages, Name
-- ======================================================
CREATE OR ALTER TRIGGER trg_ValidateSach_Data
ON sach
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Check Name Empty
    IF EXISTS (SELECT 1 FROM inserted WHERE LTRIM(RTRIM(ten_sach)) = '')
    BEGIN
        RAISERROR(N'Tên sách không được để trống.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 2. Check Publish Year (1900 -> Next Year)
    IF EXISTS (SELECT 1 FROM inserted WHERE nam_xuat_ban < 1900 OR nam_xuat_ban > YEAR(GETDATE()) + 1)
    BEGIN
        RAISERROR(N'Năm xuất bản không hợp lệ (1900 - Năm sau).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 3. Check Page Count
    IF EXISTS (SELECT 1 FROM inserted WHERE so_trang <= 0 OR so_trang > 10000)
    BEGIN
        RAISERROR(N'Số trang phải từ 1 đến 10,000.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 4. Prevent modifying Soft-Deleted Books
    -- If we try to UPDATE a book that was ALREADY deleted (da_xoa=1 in deleted table), stop it.
    -- Unless we are un-deleting it (da_xoa changing from 1 to 0).
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        JOIN deleted d ON i.ma_sach = d.ma_sach
        WHERE d.da_xoa = 1 AND i.da_xoa = 1
    )
    BEGIN
        RAISERROR(N'Không thể chỉnh sửa sách đã bị xóa.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- ======================================================
-- TRIGGER B: Validate Price (Universal Rules)
-- Enforces: Price >= 1000
-- ======================================================
CREATE OR ALTER TRIGGER trg_ValidateGiaBan
ON gia_ban
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE gia < 1000)
    BEGIN
        RAISERROR(N'Giá bán phải lớn hơn hoặc bằng 1,000 VNĐ.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- ======================================================
-- TRIGGER: All-In-One Rating Validation
-- Replaces: trg_ValidateDanhGia_Input
-- ======================================================
CREATE OR ALTER TRIGGER trg_KiemTraHopLe_DanhGia
ON danh_gia
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. CHECK STARS (1-5)
    IF EXISTS (SELECT 1 FROM inserted WHERE so_sao < 1 OR so_sao > 5)
    BEGIN
        RAISERROR(N'Điểm đánh giá phải từ 1 đến 5 sao.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 2. CHECK DUPLICATE REVIEWS (1 Review per Book per User)
    -- We check if the count > 1 for any (ma_khach, ma_sach) pair currently in the table.
    -- (Since this is AFTER INSERT, the new row is already in the table).
    IF EXISTS (
        SELECT ma_khach_hang, ma_sach
        FROM danh_gia
        WHERE ma_khach_hang IN (SELECT ma_khach_hang FROM inserted)
          AND ma_sach IN (SELECT ma_sach FROM inserted)
        GROUP BY ma_khach_hang, ma_sach
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR(N'Bạn đã đánh giá sách này rồi. Vui lòng sửa đánh giá cũ thay vì tạo mới.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 3. CHECK PURCHASE & DELIVERY (Using Helper Function)
    -- We join 'inserted' with our logic to find any invalid rows.
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        WHERE dbo.fn_KiemTraQuyenDanhGia(i.ma_khach_hang, i.ma_sach) = 0
    )
    BEGIN
        RAISERROR(N'Bạn chỉ được đánh giá sách khi đã mua và đơn hàng đã giao thành công.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    
    -- Note: "Non-Member" check is handled automatically by the Foreign Key 
    -- on the table (ma_khach_hang references thanh_vien). 
    -- If a non-member tries to insert, the DB engine throws a FK error before this trigger fires.
END;
GO

USE book_store;
GO

-- ======================================================
-- TRIGGER: Auto-Timestamp, Stats & Member Level (Buy & Cancel)
-- ======================================================
CREATE OR ALTER TRIGGER trg_TuDongKhiDatHang_VaHuy
ON don_hang
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- ==================================================
    -- CASE 1: CHECKOUT (da_dat_hang 0 -> 1)
    -- ==================================================
    IF UPDATE(da_dat_hang)
    BEGIN
        -- 1. Auto-set Timestamp
        UPDATE d
        SET d.thoi_diem_dat_hang = GETDATE()
        FROM don_hang d
        INNER JOIN inserted i ON d.ma_don = i.ma_don
        INNER JOIN deleted del ON d.ma_don = del.ma_don
        WHERE i.da_dat_hang = 1 AND del.da_dat_hang = 0;

        -- 2. ADD Stats (Spend + Points) & UPGRADE Level
        UPDATE tv
        SET 
            tv.tong_chi_tieu = tv.tong_chi_tieu + i.tong_tien_thanh_toan,
            tv.diem_tich_luy = tv.diem_tich_luy + FLOOR(i.tong_tien_thanh_toan / 100000),
            tv.cap_do_thanh_vien = CASE 
                WHEN (tv.tong_chi_tieu + i.tong_tien_thanh_toan) >= 10000000 THEN 'Diamond'
                WHEN (tv.tong_chi_tieu + i.tong_tien_thanh_toan) >= 5000000 THEN 'Gold'
                WHEN (tv.tong_chi_tieu + i.tong_tien_thanh_toan) >= 2000000 THEN 'Silver'
                ELSE 'Bronze'
            END
        FROM thanh_vien tv
        INNER JOIN inserted i ON tv.ma_khach_hang = i.ma_khach_hang
        INNER JOIN deleted del ON i.ma_don = del.ma_don
        WHERE i.da_dat_hang = 1 AND del.da_dat_hang = 0;
    END

    -- ==================================================
    -- CASE 2: CANCEL (da_huy 0 -> 1)
    -- Logic: Only revert stats if the order was previously CONFIRMED (da_dat_hang=1)
    -- ==================================================
    IF UPDATE(da_huy)
    BEGIN
        -- SUBTRACT Stats & DOWNGRADE Level
        UPDATE tv
        SET 
            tv.tong_chi_tieu = CASE 
                WHEN (tv.tong_chi_tieu - i.tong_tien_thanh_toan) < 0 THEN 0 
                ELSE (tv.tong_chi_tieu - i.tong_tien_thanh_toan) 
            END,
            tv.diem_tich_luy = CASE 
                WHEN (tv.diem_tich_luy - FLOOR(i.tong_tien_thanh_toan / 100000)) < 0 THEN 0
                ELSE (tv.diem_tich_luy - FLOOR(i.tong_tien_thanh_toan / 100000))
            END,
            -- Re-evaluate level based on NEW reduced total
            tv.cap_do_thanh_vien = CASE 
                WHEN (tv.tong_chi_tieu - i.tong_tien_thanh_toan) >= 10000000 THEN 'Diamond'
                WHEN (tv.tong_chi_tieu - i.tong_tien_thanh_toan) >= 5000000 THEN 'Gold'
                WHEN (tv.tong_chi_tieu - i.tong_tien_thanh_toan) >= 2000000 THEN 'Silver'
                ELSE 'Bronze'
            END
        FROM thanh_vien tv
        INNER JOIN inserted i ON tv.ma_khach_hang = i.ma_khach_hang
        INNER JOIN deleted del ON i.ma_don = del.ma_don
        WHERE i.da_huy = 1 AND del.da_huy = 0  -- Just cancelled
          AND i.da_dat_hang = 1;               -- Was a real order
    END
END;
GO

-- ======================================================
-- 2. TRIGGER: Lock Cart Items
-- WHEN: Someone tries to Add/Remove items (INSERT/DELETE/UPDATE)
-- CHECK: Is the Order already confirmed (da_dat_hang = 1)?
-- ACTION: STOP THEM. You can't change a basket after it's ordered.
-- ======================================================
CREATE OR ALTER TRIGGER trg_KhoaDonHang_ChiTiet
ON chi_tiet_don_hang
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Check Parent Status for INSERT/UPDATE
    IF EXISTS (
        SELECT 1 
        FROM don_hang dh
        INNER JOIN inserted i ON dh.ma_don = i.ma_don
        WHERE dh.da_dat_hang = 1 OR dh.da_huy = 1
    )
    BEGIN
        RAISERROR(N'Không thể chỉnh sửa chi tiết khi đơn hàng đã đặt hoặc đã hủy.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Check Parent Status for DELETE
    IF EXISTS (
        SELECT 1 
        FROM don_hang dh
        INNER JOIN deleted d ON dh.ma_don = d.ma_don
        WHERE dh.da_dat_hang = 1 OR dh.da_huy = 1
    )
    BEGIN
        RAISERROR(N'Không thể xóa chi tiết khi đơn hàng đã đặt hoặc đã hủy.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- ======================================================
-- 3. TRIGGER: Prevent Status Hacking
-- WHEN: Someone tries to "Un-cancel" or "Un-order"
-- ACTION: Stop them. History is immutable.
-- ======================================================
CREATE OR ALTER TRIGGER trg_BaoVeTrangThai
ON don_hang
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Prevent changing 'da_dat_hang' from 1 back to 0
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        JOIN deleted d ON i.ma_don = d.ma_don 
        WHERE d.da_dat_hang = 1 AND i.da_dat_hang = 0
    )
    BEGIN
        RAISERROR(N'Không thể chuyển đơn hàng từ "Đã đặt" về "Giỏ hàng".', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- ======================================================
-- 1. CALCULATION TRIGGER (The "Shenanigan" Automated)
-- Logic: After Review -> Calc Avg -> Log History -> Update Book Cache
-- This replaces the logic inside sp_ThemDanhGia
-- ======================================================
CREATE OR ALTER TRIGGER trg_TuDongTinhToan_Rating
ON danh_gia
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- We need to update books referenced in INSERTED and DELETED (in case of update/delete)
    DECLARE @AffectedBooks TABLE (ma_sach INT);
    
    INSERT INTO @AffectedBooks
    SELECT ma_sach FROM inserted
    UNION
    SELECT ma_sach FROM deleted;

    DECLARE @ma_sach INT;
    
    -- Iterate through affected books (Cursor-free approach possible, but loop is safe here for small batches)
    DECLARE cur CURSOR FOR SELECT ma_sach FROM @AffectedBooks;
    OPEN cur;
    FETCH NEXT FROM cur INTO @ma_sach;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- A. Calculate Math
        DECLARE @new_avg DECIMAL(3,2);
        DECLARE @new_count INT;

        SELECT 
            @new_avg = CAST(AVG(CAST(so_sao AS DECIMAL(10,2))) AS DECIMAL(3,2)),
            @new_count = COUNT(*)
        FROM danh_gia 
        WHERE ma_sach = @ma_sach;

        -- Handle NULL (if all reviews deleted)
        SET @new_avg = ISNULL(@new_avg, 0);
        SET @new_count = ISNULL(@new_count, 0);

        -- B. Insert Rating Snapshot (Log)
        INSERT INTO tong_hop_danh_gia (ma_sach, diem_trung_binh, tong_luot_danh_gia)
        VALUES (@ma_sach, @new_avg, @new_count);
        
        DECLARE @rid INT = SCOPE_IDENTITY();

        -- C. Update Book Cache & Pointer
        UPDATE sach 
        SET so_sao_trung_binh = @new_avg, 
            tong_so_danh_gia = @new_count,
            ma_rating_hien_tai = @rid
        WHERE ma_sach = @ma_sach;

        FETCH NEXT FROM cur INTO @ma_sach;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- ======================================================
-- TRIGGER: Automatic Inventory Management
-- 1. ORDERED (0 -> 1): Find warehouses & Subtract stock.
-- 2. CANCELLED (0 -> 1): Find warehouse & Return stock.
-- ======================================================
CREATE OR ALTER TRIGGER trg_QuanLyKho_TuDong
ON don_hang
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- ==================================================
    -- CASE 1: ORDER CONFIRMED (Subtract Stock)
    -- ==================================================
    IF EXISTS (
        SELECT 1 FROM inserted i 
        JOIN deleted d ON i.ma_don = d.ma_don 
        WHERE i.da_dat_hang = 1 AND d.da_dat_hang = 0
    )
    BEGIN
        DECLARE @MaDon INT;
        SELECT @MaDon = ma_don FROM inserted WHERE da_dat_hang = 1;

        -- Cursor to loop through items in this order
        DECLARE @MaSach INT, @SoLuongCan INT;
        DECLARE cur_items CURSOR FOR 
            SELECT ma_sach, so_luong FROM chi_tiet_don_hang WHERE ma_don = @MaDon;
        
        OPEN cur_items;
        FETCH NEXT FROM cur_items INTO @MaSach, @SoLuongCan;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 1. Check Total Stock across all warehouses
            DECLARE @TongTon INT;
            SELECT @TongTon = SUM(so_luong_ton) FROM so_luong_sach_kho WHERE ma_sach = @MaSach;
            
            IF ISNULL(@TongTon, 0) < @SoLuongCan
            BEGIN
                RAISERROR(N'Sách (ID: %d) không đủ hàng trong kho. Tổng tồn: %d, Cần: %d', 16, 1, @MaSach, @TongTon, @SoLuongCan);
                ROLLBACK TRANSACTION;
                CLOSE cur_items; DEALLOCATE cur_items;
                RETURN;
            END

            -- 2. Deduct Logic (Multi-Warehouse)
            -- We take from warehouses with stock until requirement is met
            DECLARE @MaKho INT, @TonKhoHienTai INT;
            
            DECLARE cur_warehouses CURSOR FOR 
                SELECT ma_kho, so_luong_ton 
                FROM so_luong_sach_kho 
                WHERE ma_sach = @MaSach AND so_luong_ton > 0
                ORDER BY so_luong_ton DESC; -- Take from largest pile first
            
            OPEN cur_warehouses;
            FETCH NEXT FROM cur_warehouses INTO @MaKho, @TonKhoHienTai;
            
            WHILE @@FETCH_STATUS = 0 AND @SoLuongCan > 0
            BEGIN
                DECLARE @LayDi INT;
                
                IF @TonKhoHienTai >= @SoLuongCan
                    SET @LayDi = @SoLuongCan; -- Warehouse has enough
                ELSE
                    SET @LayDi = @TonKhoHienTai; -- Take everything from this warehouse
                
                -- Execute Deduction
                UPDATE so_luong_sach_kho 
                SET so_luong_ton = so_luong_ton - @LayDi 
                WHERE ma_kho = @MaKho AND ma_sach = @MaSach;
                
                -- Update remaining need
                SET @SoLuongCan = @SoLuongCan - @LayDi;
                
                FETCH NEXT FROM cur_warehouses INTO @MaKho, @TonKhoHienTai;
            END
            
            CLOSE cur_warehouses;
            DEALLOCATE cur_warehouses;

            FETCH NEXT FROM cur_items INTO @MaSach, @SoLuongCan;
        END
        
        CLOSE cur_items;
        DEALLOCATE cur_items;
    END

    -- ==================================================
    -- CASE 2: ORDER CANCELLED (Restock / Add Back)
    -- ==================================================
    IF EXISTS (
        SELECT 1 FROM inserted i 
        JOIN deleted d ON i.ma_don = d.ma_don 
        WHERE i.da_huy = 1 AND d.da_huy = 0 AND d.da_dat_hang = 1
    )
    BEGIN
        DECLARE @MaDonHuy INT;
        SELECT @MaDonHuy = ma_don FROM inserted WHERE da_huy = 1;

        DECLARE @MaSachTra INT, @SoLuongTra INT;
        
        DECLARE cur_restock CURSOR FOR 
            SELECT ma_sach, so_luong FROM chi_tiet_don_hang WHERE ma_don = @MaDonHuy;
        
        OPEN cur_restock;
        FETCH NEXT FROM cur_restock INTO @MaSachTra, @SoLuongTra;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Logic: Dump items back into the first warehouse found for this book
            -- (Simplification: We don't track exactly which warehouse sent it originally)
            DECLARE @KhoNhan INT;
            SELECT TOP 1 @KhoNhan = ma_kho FROM so_luong_sach_kho WHERE ma_sach = @MaSachTra;
            
            IF @KhoNhan IS NOT NULL
            BEGIN
                UPDATE so_luong_sach_kho 
                SET so_luong_ton = so_luong_ton + @SoLuongTra 
                WHERE ma_kho = @KhoNhan AND ma_sach = @MaSachTra;
            END
            
            FETCH NEXT FROM cur_restock INTO @MaSachTra, @SoLuongTra;
        END
        
        CLOSE cur_restock;
        DEALLOCATE cur_restock;
    END
END;
GO

-- ======================================================
-- 3. TRIGGER: Enforce Payment Before Checkout
-- WHEN: Order Status changes 0 -> 1
-- CHECK: Does table 'thanh_toan' have a row for this 'ma_don'?
-- ======================================================
CREATE OR ALTER TRIGGER trg_KiemTraThanhToan_TruocKhiDat
ON don_hang
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only check if we are confirming an order (da_dat_hang 0 -> 1)
    IF EXISTS (
        SELECT 1 FROM inserted i 
        JOIN deleted d ON i.ma_don = d.ma_don 
        WHERE i.da_dat_hang = 1 AND d.da_dat_hang = 0
    )
    BEGIN
        -- Find orders that are confirmed BUT missing payment record
        IF EXISTS (
            SELECT 1 
            FROM inserted i
            LEFT JOIN thanh_toan tt ON i.ma_don = tt.ma_don
            WHERE i.da_dat_hang = 1 
              AND tt.ma_thanh_toan IS NULL -- Missing Payment
        )
        BEGIN
            RAISERROR(N'Bạn phải chọn phương thức thanh toán trước khi đặt hàng.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
    END
END;
GO

-- ======================================================
-- TRIGGER: Decrement Voucher Quantity on Checkout
-- ======================================================
CREATE OR ALTER TRIGGER trg_TruVoucher_KhiDatHang
ON don_hang
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only run if Order is Confirmed (0 -> 1)
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.ma_don = d.ma_don WHERE i.da_dat_hang = 1 AND d.da_dat_hang = 0)
    BEGIN
        DECLARE @MaDon INT, @MaVoucher INT, @MaKhach INT;
        
        SELECT @MaDon = ma_don, @MaVoucher = ma_voucher, @MaKhach = ma_khach_hang 
        FROM inserted WHERE da_dat_hang = 1;

        -- If a voucher was applied
        IF @MaVoucher IS NOT NULL
        BEGIN
            -- Check if user still has quantity (Double check to prevent race condition)
            DECLARE @Qty INT;
            SELECT @Qty = so_luong FROM voucher_thanh_vien WHERE ma_voucher = @MaVoucher AND ma_khach_hang = @MaKhach;
            
            IF ISNULL(@Qty, 0) <= 0
            BEGIN
                RAISERROR(N'Voucher đã hết lượt sử dụng.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Decrement Quantity
            UPDATE voucher_thanh_vien
            SET so_luong = so_luong - 1
            WHERE ma_voucher = @MaVoucher AND ma_khach_hang = @MaKhach;
        END
    END
END;
GO

PRINT N'Validation Triggers Created Successfully!';
GO
