USE book_store;
GO

-- ======================================================
-- PROCEDURE 1: sp_ThemSach (Add Book - Hybrid Model)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_ThemSach
    @ten_sach NVARCHAR(200),
    @nam_xuat_ban INT,
    @ma_nxb INT,
    @so_trang INT,
    @ngon_ngu NVARCHAR(50),
    @trong_luong DECIMAL(10,2) = NULL,
    @do_tuoi INT = NULL,
    @hinh_thuc NVARCHAR(50) = NULL,
    @mo_ta NVARCHAR(MAX) = NULL,
    @gia_ban MONEY, -- Price is required for new books
    @ma_sach_moi INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- [VALIDATIONS] ---------------------------------------------
        IF LTRIM(RTRIM(@ten_sach)) = '' OR @ten_sach IS NULL THROW 50001, N'Tên sách không được trống', 1;
        IF @nam_xuat_ban < 1900 OR @nam_xuat_ban > YEAR(GETDATE()) THROW 50002, N'Năm xuất bản không hợp lệ', 1;
        IF NOT EXISTS (SELECT 1 FROM nha_xuat_ban WHERE ma_nxb = @ma_nxb) THROW 50003, N'Mã nhà xuất bản không tồn tại', 1;
        IF @so_trang <= 0 OR @so_trang > 10000 THROW 50004, N'Số trang phải từ 1-10,000', 1;
        IF @gia_ban < 0 OR @gia_ban < 1000 THROW 50007, N'Giá bán phải >= 1,000 VNĐ', 1;
        
        -- Check duplicate (Only check Active books)
        IF EXISTS (
            SELECT 1 FROM sach 
            WHERE ten_sach = @ten_sach 
              AND nam_xuat_ban = @nam_xuat_ban 
              AND ma_nxb = @ma_nxb
              AND da_xoa = 0
        ) THROW 50008, N'Sách này đã tồn tại', 1;
        
        -- [LOGIC] ---------------------------------------------------
        
        -- 1. Insert Book (Pointer is NULL initially)
        INSERT INTO sach (
            ten_sach, nam_xuat_ban, ma_nxb, so_trang, ngon_ngu,
            trong_luong, do_tuoi, hinh_thuc, mo_ta, so_sao_trung_binh,
            gia_hien_tai, ma_gia_hien_tai, da_xoa
        )
        VALUES (
            @ten_sach, @nam_xuat_ban, @ma_nxb, @so_trang, @ngon_ngu,
            @trong_luong, @do_tuoi, @hinh_thuc, @mo_ta, 0.00,
            @gia_ban, NULL, 0
        );
        
        SET @ma_sach_moi = SCOPE_IDENTITY();
        
        -- 2. Insert Price History
        INSERT INTO gia_ban (ma_sach, gia)
        VALUES (@ma_sach_moi, @gia_ban);
        
        DECLARE @ma_gia_moi INT = SCOPE_IDENTITY();

        -- 3. Update Book to Point to Price
        UPDATE sach 
        SET ma_gia_hien_tai = @ma_gia_moi 
        WHERE ma_sach = @ma_sach_moi;
        
        -- 4. Add to default warehouse (Initialize inventory at 0)
        DECLARE @ma_kho_mac_dinh INT = (SELECT TOP 1 ma_kho FROM kho ORDER BY ma_kho);
        IF @ma_kho_mac_dinh IS NOT NULL
        BEGIN
            INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton)
            VALUES (@ma_kho_mac_dinh, @ma_sach_moi, 0);
        END
        
        COMMIT TRANSACTION;
        PRINT N'Thêm sách thành công! Mã: ' + CAST(@ma_sach_moi AS NVARCHAR(10));
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 2: sp_SuaSach (Update Info - NO PRICE)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_SuaSach
    @ma_sach INT,
    @ten_sach NVARCHAR(200) = NULL,
    @nam_xuat_ban INT = NULL,
    @ma_nxb INT = NULL,
    @so_trang INT = NULL,
    @ngon_ngu NVARCHAR(50) = NULL,
    @trong_luong DECIMAL(10,2) = NULL,
    @do_tuoi INT = NULL,
    @hinh_thuc NVARCHAR(50) = NULL,
    @mo_ta NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Check existence
        IF NOT EXISTS (SELECT 1 FROM sach WHERE ma_sach = @ma_sach AND da_xoa = 0)
            THROW 50010, N'Không tìm thấy sách hoặc sách đã bị xóa', 1;
        
        -- Simple Validations
        IF @nam_xuat_ban IS NOT NULL AND (@nam_xuat_ban < 1900 OR @nam_xuat_ban > YEAR(GETDATE()))
            THROW 50012, N'Năm xuất bản không hợp lệ', 1;
        
        -- Update Info (Ignores Price)
        UPDATE sach
        SET 
            ten_sach = ISNULL(@ten_sach, ten_sach),
            nam_xuat_ban = ISNULL(@nam_xuat_ban, nam_xuat_ban),
            ma_nxb = ISNULL(@ma_nxb, ma_nxb),
            so_trang = ISNULL(@so_trang, so_trang),
            ngon_ngu = ISNULL(@ngon_ngu, ngon_ngu),
            trong_luong = ISNULL(@trong_luong, trong_luong),
            do_tuoi = ISNULL(@do_tuoi, do_tuoi),
            hinh_thuc = ISNULL(@hinh_thuc, hinh_thuc),
            mo_ta = ISNULL(@mo_ta, mo_ta)
        WHERE ma_sach = @ma_sach;
        
        COMMIT TRANSACTION;
        PRINT N'Cập nhật thông tin sách thành công!';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 3: sp_CapNhatGia (New - Update Price Logic)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_CapNhatGia
    @ma_sach INT,
    @gia_moi MONEY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @gia_moi < 0 OR @gia_moi < 1000 THROW 50007, N'Giá bán phải >= 1,000 VNĐ', 1;

        -- 1. Add to History
        INSERT INTO gia_ban (ma_sach, gia) VALUES (@ma_sach, @gia_moi);
        DECLARE @new_price_id INT = SCOPE_IDENTITY();

        -- 2. Update Cache & Pointer
        UPDATE sach 
        SET gia_hien_tai = @gia_moi, ma_gia_hien_tai = @new_price_id 
        WHERE ma_sach = @ma_sach;

        COMMIT TRANSACTION;
        PRINT N'Cập nhật giá thành công!';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 4: sp_XoaSach (Soft Delete)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_XoaSach
    @ma_sach INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- We just hide it. We don't care if it was ordered.
        -- History is preserved.
        UPDATE sach SET da_xoa = 1 WHERE ma_sach = @ma_sach;
        
        PRINT N'Sách đã được chuyển vào thùng rác (Soft Delete).';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 5: Search Books (Fixed Joins)
-- ======================================================
CREATE OR ALTER PROCEDURE TimSachCoMoTaGanGiong_VaDangCoVoucher
    @decription NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Find candidates (Active books only)
    SELECT 
        S.ma_sach,
        S.ten_sach,
        S.ma_nxb,
        CASE 
            WHEN CHARINDEX(@decription, S.mo_ta) > 0 THEN 100 
            ELSE 0 
        END AS DoLienQuan
    INTO #SachLienQuan
    FROM sach AS S
    WHERE S.da_xoa = 0 -- IMPORTANT: Soft delete check
      AND CHARINDEX(@decription, S.mo_ta) > 0
    ORDER BY DoLienQuan DESC;

    -- 2. Join with Inventory and Vouchers
    SELECT
        SLQ.ten_sach,
        NXB.ten_nxb,
        SLQ.DoLienQuan,
        COUNT(V.ma_voucher) AS SoLuongVoucherDangApDung
    FROM #SachLienQuan AS SLQ
    JOIN nha_xuat_ban AS NXB ON SLQ.ma_nxb = NXB.ma_nxb
    INNER JOIN (
        -- Fixed: Use 'so_luong_sach_kho', not 'kho'
        SELECT ma_sach, SUM(so_luong_ton) AS TongTon
        FROM so_luong_sach_kho 
        GROUP BY ma_sach
        HAVING SUM(so_luong_ton) > 0
    ) AS KHO_TON ON SLQ.ma_sach = KHO_TON.ma_sach
    LEFT JOIN voucher AS V ON NXB.ma_nxb = V.ma_nxb
    WHERE 
        V.ma_voucher IS NOT NULL
        AND V.ket_thuc > GETDATE()
    GROUP BY
        SLQ.ten_sach,
        NXB.ten_nxb,
        SLQ.DoLienQuan
    HAVING COUNT(V.ma_voucher) >= 1
    ORDER BY SLQ.DoLienQuan DESC;

    DROP TABLE #SachLienQuan;
END;
GO

-- ======================================================
-- PROCEDURE 6: Get Reviews
-- ======================================================
CREATE OR ALTER PROCEDURE sp_LayDanhGiaSach_TheoSao
    @MaSach INT,
    @SoSaoToiThieu INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DG.ma_khach_hang,
        KH.ho,
        KH.ho_ten_dem,
        DG.so_sao,
        DG.noi_dung,
        DG.ngay_danh_gia
    FROM danh_gia DG
    INNER JOIN khach_hang KH ON DG.ma_khach_hang = KH.ma_khach_hang    
    WHERE DG.ma_sach = @MaSach        
      AND DG.so_sao >= @SoSaoToiThieu 
    ORDER BY DG.ngay_danh_gia DESC;
END;
GO

PRINT N'All Procedures updated successfully!';
GO
