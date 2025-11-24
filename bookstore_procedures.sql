USE book_store;
GO

-- ======================================================
-- PROCEDURE 1: sp_ThemSach - Add Book
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
    @gia_ban MONEY = NULL,
    @ma_sach_moi INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate name
        IF LTRIM(RTRIM(@ten_sach)) = '' OR @ten_sach IS NULL
            THROW 50001, N'Tên sách không được trống', 1;
        
        -- Validate year
        IF @nam_xuat_ban < 1900 OR @nam_xuat_ban > YEAR(GETDATE())
            THROW 50002, N'Năm xuất bản không hợp lệ (1900 - hiện tại)', 1;
        
        -- Validate publisher exists
        IF NOT EXISTS (SELECT 1 FROM nha_xuat_ban WHERE ma_nxb = @ma_nxb)
            THROW 50003, N'Mã nhà xuất bản không tồn tại', 1;
        
        -- Validate pages
        IF @so_trang <= 0 OR @so_trang > 10000
            THROW 50004, N'Số trang phải từ 1-10,000', 1;
        
        -- Validate weight
        IF @trong_luong IS NOT NULL AND (@trong_luong < 0 OR @trong_luong > 50000)
            THROW 50005, N'Trọng lượng không hợp lệ (0-50,000g)', 1;
        
        -- Validate age rating
        IF @do_tuoi IS NOT NULL AND @do_tuoi NOT IN (0, 6, 12, 16, 18)
            THROW 50006, N'Độ tuổi phải là 0+, 6+, 12+, 16+, 18+', 1;
        
        -- Validate price
        IF @gia_ban IS NOT NULL AND (@gia_ban < 0 OR @gia_ban < 1000)
            THROW 50007, N'Giá bán phải >= 1,000 VNĐ', 1;
        
        -- Check duplicate
        IF EXISTS (
            SELECT 1 FROM sach 
            WHERE ten_sach = @ten_sach 
              AND nam_xuat_ban = @nam_xuat_ban
              AND ma_nxb = @ma_nxb
        )
            THROW 50008, N'Sách này đã tồn tại', 1;
        
        -- Insert book
        INSERT INTO sach (
            ten_sach, nam_xuat_ban, ma_nxb, so_trang, ngon_ngu,
            trong_luong, do_tuoi, hinh_thuc, mo_ta, so_sao_trung_binh
        )
        VALUES (
            @ten_sach, @nam_xuat_ban, @ma_nxb, @so_trang, @ngon_ngu,
            @trong_luong, @do_tuoi, @hinh_thuc, @mo_ta, 0.00
        );
        
        SET @ma_sach_moi = SCOPE_IDENTITY();
        
        -- Add price
        IF @gia_ban IS NOT NULL
        BEGIN
            INSERT INTO gia_ban (ma_sach, gia, tu_ngay, den_ngay)
            VALUES (@ma_sach_moi, @gia_ban, GETDATE(), NULL);
        END
        
        -- Add to warehouse (default first warehouse)
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
-- PROCEDURE 2: sp_SuaSach - Update Book
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
        
        -- Check book exists
        IF NOT EXISTS (SELECT 1 FROM sach WHERE ma_sach = @ma_sach)
            THROW 50010, N'Không tìm thấy sách', 1;
        
        -- Check if book in orders
        IF EXISTS (SELECT 1 FROM chi_tiet_don_hang WHERE ma_sach = @ma_sach)
        BEGIN
            IF @ten_sach IS NOT NULL OR @nam_xuat_ban IS NOT NULL OR @ma_nxb IS NOT NULL
                THROW 50011, N'Không thể đổi tên/năm/NXB của sách đã có đơn hàng', 1;
        END
        
        -- Validate new values
        IF @nam_xuat_ban IS NOT NULL AND (@nam_xuat_ban < 1900 OR @nam_xuat_ban > YEAR(GETDATE()))
            THROW 50012, N'Năm xuất bản không hợp lệ', 1;
        
        IF @ma_nxb IS NOT NULL AND NOT EXISTS (SELECT 1 FROM nha_xuat_ban WHERE ma_nxb = @ma_nxb)
            THROW 50013, N'Mã NXB không tồn tại', 1;
        
        IF @so_trang IS NOT NULL AND (@so_trang <= 0 OR @so_trang > 10000)
            THROW 50014, N'Số trang phải từ 1-10,000', 1;
        
        IF @trong_luong IS NOT NULL AND (@trong_luong < 0 OR @trong_luong > 50000)
            THROW 50015, N'Trọng lượng không hợp lệ', 1;
        
        IF @do_tuoi IS NOT NULL AND @do_tuoi NOT IN (0, 6, 12, 16, 18)
            THROW 50016, N'Độ tuổi phải là 0+, 6+, 12+, 16+, 18+', 1;
        
        -- Update
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
        PRINT N'Cập nhật sách thành công!';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 3: sp_XoaSach - Delete Book
-- ======================================================
CREATE OR ALTER PROCEDURE sp_XoaSach
    @ma_sach INT,
    @xoa_vinh_vien BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Check book exists
        IF NOT EXISTS (SELECT 1 FROM sach WHERE ma_sach = @ma_sach)
            THROW 50020, N'Không tìm thấy sách', 1;
        
        -- Check if in orders
        DECLARE @so_don_hang INT;
        SELECT @so_don_hang = COUNT(DISTINCT ma_don)
        FROM chi_tiet_don_hang
        WHERE ma_sach = @ma_sach;
        
        IF @so_don_hang > 0
            THROW 50021, N'Không thể xóa sách đã có trong đơn hàng', 1;
        
        -- Check inventory
        DECLARE @ton_kho INT;
        SELECT @ton_kho = SUM(so_luong_ton) 
        FROM so_luong_sach_kho 
        WHERE ma_sach = @ma_sach;
        
        IF @ton_kho > 0 AND @xoa_vinh_vien = 0
            THROW 50022, N'Sách còn tồn kho. Đặt @xoa_vinh_vien=1 để xóa', 1;
        
        -- Delete
        DELETE FROM sach WHERE ma_sach = @ma_sach;
        
        COMMIT TRANSACTION;
        PRINT N'Xóa sách thành công!';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 4: sp_TimSachCoMoTaGanGiong_VaDangCoVoucher
-- Search books by description with active vouchers
-- ======================================================
CREATE OR ALTER PROCEDURE TimSachCoMoTaGanGiong_VaDangCoVoucher
    @decription NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        S.ma_sach,
        S.ten_sach,
        S.ma_nxb,
        CASE 
            WHEN CHARINDEX(@decription, S.mo_ta) > 0 
                 THEN 100 
                 ELSE 0 
        END AS DoLienQuan
    INTO #SachLienQuan
    FROM sach AS S
    WHERE DATEDIFF(DAY, S.ngay_du_kien_phat_hanh, GETDATE()) >= 0
      AND CHARINDEX(@decription, S.mo_ta) > 0
    ORDER BY DoLienQuan DESC;

    SELECT
        SLQ.ten_sach,
        NXB.ten_nxb,
        SLQ.DoLienQuan,
        COUNT(V.ma_voucher) AS SoLuongVoucherDangApDung
    FROM #SachLienQuan AS SLQ
    JOIN nha_xuat_ban AS NXB 
        ON SLQ.ma_nxb = NXB.ma_nxb
    INNER JOIN (
        SELECT ma_sach, SUM(so_luong_ton) AS TongTon
        FROM kho 
        GROUP BY ma_sach
        HAVING SUM(so_luong_ton) > 0
    ) AS KHO_TON 
        ON SLQ.ma_sach = KHO_TON.ma_sach
    LEFT JOIN voucher AS V 
        ON NXB.ma_nxb = V.ma_nxb
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
-- PROCEDURE 5: sp_LayDanhGiaSach_TheoSao
-- Get reviews by star rating
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
    INNER JOIN thanh_vien TV ON DG.ma_khach_hang = TV.ma_khach_hang
    INNER JOIN khach_hang KH ON DG.ma_khach_hang = KH.ma_khach_hang   
    WHERE DG.ma_sach = @MaSach        
      AND DG.so_sao >= @SoSaoToiThieu 
    ORDER BY DG.ngay_danh_gia DESC;
END;
GO

PRINT N'Procedures created successfully!';
GO
