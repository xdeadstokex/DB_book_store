USE book_store;
GO

-- ======================================================
-- TRIGGER 1: Auto-update tong_chi_tieu and diem_tich_luy
-- After INSERT on don_hang
-- ======================================================
CREATE OR ALTER TRIGGER trg_CapNhatThanhVien_SauKhiDatHang
ON don_hang
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE tv
    SET 
        tv.tong_chi_tieu = tv.tong_chi_tieu + i.tong_tien_thanh_toan,
        tv.diem_tich_luy = tv.diem_tich_luy + FLOOR(i.tong_tien_thanh_toan / 1000)
    FROM thanh_vien tv
    INNER JOIN inserted i ON tv.ma_khach_hang = i.ma_khach_hang
    WHERE EXISTS (SELECT 1 FROM thanh_vien WHERE ma_khach_hang = i.ma_khach_hang);
END;
GO

-- ======================================================
-- TRIGGER 2: Auto-update so_sao_trung_binh when review added/updated/deleted
-- ======================================================
CREATE OR ALTER TRIGGER trg_CapNhatSaoTrungBinh_SauDanhGia
ON danh_gia
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update books affected by INSERT/UPDATE
    UPDATE s
    SET s.so_sao_trung_binh = (
        SELECT AVG(CAST(dg.so_sao AS DECIMAL(3,2)))
        FROM danh_gia dg
        WHERE dg.ma_sach = s.ma_sach
    )
    FROM sach s
    WHERE s.ma_sach IN (SELECT ma_sach FROM inserted);
    
    -- Update books affected by DELETE
    UPDATE s
    SET s.so_sao_trung_binh = (
        SELECT AVG(CAST(dg.so_sao AS DECIMAL(3,2)))
        FROM danh_gia dg
        WHERE dg.ma_sach = s.ma_sach
    )
    FROM sach s
    WHERE s.ma_sach IN (SELECT ma_sach FROM deleted);
END;
GO

-- ======================================================
-- TRIGGER 3: Prevent review if customer hasn't bought the book
-- Business rule: Only members who purchased (and received) a book can review it
-- ======================================================
CREATE OR ALTER TRIGGER trg_KiemTraQuyenDanhGia
ON danh_gia
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MaKhach INT, @MaSach INT, @SoSao INT, @NoiDung NVARCHAR(MAX);
    
    DECLARE cur CURSOR FOR 
        SELECT ma_khach_hang, ma_sach, so_sao, noi_dung FROM inserted;
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @MaKhach, @MaSach, @SoSao, @NoiDung;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check if customer bought and received the book
        IF EXISTS (
            SELECT 1
            FROM don_hang dh
            INNER JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don
            WHERE dh.ma_khach_hang = @MaKhach
              AND ct.ma_sach = @MaSach
              AND dh.trang_thai_don_hang = N'Đã giao'
        )
        BEGIN
            INSERT INTO danh_gia (ma_sach, ma_khach_hang, noi_dung, so_sao)
            VALUES (@MaSach, @MaKhach, @NoiDung, @SoSao);
        END
        ELSE
        BEGIN
            RAISERROR(N'Khách hàng %d chưa mua hoặc chưa nhận được sách %d. Không thể đánh giá!', 16, 1, @MaKhach, @MaSach);
        END
        
        FETCH NEXT FROM cur INTO @MaKhach, @MaSach, @SoSao, @NoiDung;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- ======================================================
-- TRIGGER 4: Check inventory before order
-- Prevent order if not enough stock across all warehouses
-- ======================================================
CREATE OR ALTER TRIGGER trg_KiemTraKho_TruocKhiDat
ON chi_tiet_don_hang
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MaSach INT, @SoLuong INT, @TongTon INT;
    
    DECLARE cur CURSOR FOR 
        SELECT ma_sach, so_luong FROM inserted;
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @MaSach, @SoLuong;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @TongTon = SUM(so_luong_ton)
        FROM so_luong_sach_kho
        WHERE ma_sach = @MaSach;
        
        IF @TongTon IS NULL OR @TongTon < @SoLuong
        BEGIN
            RAISERROR(N'Sách %d không đủ tồn kho. Tồn: %d, Yêu cầu: %d', 16, 1, @MaSach, @TongTon, @SoLuong);
            ROLLBACK;
            RETURN;
        END
        
        FETCH NEXT FROM cur INTO @MaSach, @SoLuong;
    END
    
    CLOSE cur;
    DEALLOCATE cur;
    
    -- If all checks pass, insert the records
    INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, gia_ban, so_luong, the_loai)
    SELECT ma_don, ma_sach, gia_ban, so_luong, the_loai FROM inserted;
END;
GO

-- ======================================================
-- TEST TRIGGERS
-- ======================================================

PRINT N'--- Test Trigger 1: Cập nhật tổng chi tiêu ---';
SELECT ma_khach_hang, tong_chi_tieu, diem_tich_luy FROM thanh_vien WHERE ma_khach_hang = 1;
-- This will auto-trigger when order is inserted
GO

PRINT N'--- Test Trigger 2: Cập nhật sao trung bình ---';
SELECT ma_sach, so_sao_trung_binh FROM sach WHERE ma_sach = 1;
GO

PRINT N'--- Test Trigger 3: Kiểm tra quyền đánh giá (PASS) ---';
-- Customer 1 bought book 1 and order delivered → Should work
INSERT INTO danh_gia (ma_sach, ma_khach_hang, noi_dung, so_sao)
VALUES (1, 1, N'Test đánh giá hợp lệ', 5);
GO

PRINT N'--- Test Trigger 3: Kiểm tra quyền đánh giá (FAIL) ---';
-- Customer 4 hasn't bought book 1 → Should fail
BEGIN TRY
    INSERT INTO danh_gia (ma_sach, ma_khach_hang, noi_dung, so_sao)
    VALUES (1, 4, N'Test không hợp lệ', 5);
END TRY
BEGIN CATCH
    PRINT N'Lỗi: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'Triggers created successfully!';
GO