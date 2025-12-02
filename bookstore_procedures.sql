USE book_store;
GO

-- ======================================================
-- PROCEDURE 1: AUTH - Register (Customer + Member)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_DangKyThanhVien
    @ho NVARCHAR(100),
    @ho_ten_dem NVARCHAR(200),
    @email NVARCHAR(200),
    @sdt NVARCHAR(20),
    @ten_dang_nhap NVARCHAR(100),
    @mat_khau NVARCHAR(200), -- Hash this in Go!
    @gioi_tinh NVARCHAR(10) = 'Khac',
    @ngay_sinh DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Check Duplicates
        IF EXISTS (SELECT 1 FROM thanh_vien WHERE ten_dang_nhap = @ten_dang_nhap)
            THROW 50030, N'Tên đăng nhập đã tồn tại', 1;
            
        IF EXISTS (SELECT 1 FROM khach_hang WHERE email = @email)
            THROW 50031, N'Email đã được sử dụng', 1;

        -- 2. Insert Base Customer
        INSERT INTO khach_hang (ho_ten_dem, ho, ngay_sinh, email, sdt)
        VALUES (@ho_ten_dem, @ho, @ngay_sinh, @email, @sdt);

        DECLARE @new_kh_id INT = SCOPE_IDENTITY();

        -- 3. Insert Member Credentials
        INSERT INTO thanh_vien (ma_khach_hang, ten_dang_nhap, mat_khau_ma_hoa, gioi_tinh)
        VALUES (@new_kh_id, @ten_dang_nhap, @mat_khau, @gioi_tinh);

        COMMIT TRANSACTION;
        
        -- Return the new ID
        SELECT @new_kh_id AS ma_khach_hang;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 2: AUTH - Login
-- ======================================================
CREATE OR ALTER PROCEDURE sp_DangNhap
    @ten_dang_nhap NVARCHAR(100),
    @mat_khau NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @id INT;
    SELECT @id = ma_khach_hang 
    FROM thanh_vien 
    WHERE ten_dang_nhap = @ten_dang_nhap AND mat_khau_ma_hoa = @mat_khau;

    IF @id IS NULL THROW 50035, N'Sai tên đăng nhập hoặc mật khẩu', 1;

    -- Return Basic Info
    SELECT tv.ma_khach_hang, tv.ten_dang_nhap, kh.ho + ' ' + kh.ho_ten_dem as ho_ten
    FROM thanh_vien tv
    JOIN khach_hang kh ON tv.ma_khach_hang = kh.ma_khach_hang
    WHERE tv.ma_khach_hang = @id;
END;
GO

-- ======================================================
-- PROC 3: sp_ThemSach (CLEAN VERSION)
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
    @ten_nguoi_dich NVARCHAR(200) = NULL,
    @gia_ban MONEY, 
    @ma_sach_moi INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- [LOGIC ONLY - Validations handled by Triggers/Constraints]
        
        -- 1. Insert Book
        INSERT INTO sach (
            ten_sach, nam_xuat_ban, ma_nxb, so_trang, ngon_ngu,
            trong_luong, do_tuoi, hinh_thuc, mo_ta, ten_nguoi_dich,
            gia_hien_tai, ma_gia_hien_tai, 
            so_sao_trung_binh, tong_so_danh_gia, ma_rating_hien_tai,
            da_xoa
        )
        VALUES (
            @ten_sach, @nam_xuat_ban, @ma_nxb, @so_trang, @ngon_ngu,
            @trong_luong, @do_tuoi, @hinh_thuc, @mo_ta, @ten_nguoi_dich,
            @gia_ban, NULL, 
            0, 0, NULL,     
            0
        );
        
        SET @ma_sach_moi = SCOPE_IDENTITY();
        
        -- 2. Create Initial Price History (Trigger checks @gia_ban here)
        INSERT INTO gia_ban (ma_sach, gia) VALUES (@ma_sach_moi, @gia_ban);
        DECLARE @pid INT = SCOPE_IDENTITY();

        -- 3. Create Initial Rating History
        INSERT INTO tong_hop_danh_gia (ma_sach, diem_trung_binh, tong_luot_danh_gia) 
        VALUES (@ma_sach_moi, 0, 0);
        DECLARE @rid INT = SCOPE_IDENTITY();

        -- 4. Wire up Pointers
        UPDATE sach 
        SET ma_gia_hien_tai = @pid, ma_rating_hien_tai = @rid
        WHERE ma_sach = @ma_sach_moi;
        
        -- 5. Init Inventory
        DECLARE @ma_kho_mac_dinh INT = (SELECT TOP 1 ma_kho FROM kho ORDER BY ma_kho);
        IF @ma_kho_mac_dinh IS NOT NULL
            INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton)
            VALUES (@ma_kho_mac_dinh, @ma_sach_moi, 0);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROC 4: sp_SuaSach (CLEAN VERSION)
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
    @mo_ta NVARCHAR(MAX) = NULL,
    @ten_nguoi_dich NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Triggers will validate the data update automatically
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
            mo_ta = ISNULL(@mo_ta, mo_ta),
            ten_nguoi_dich = ISNULL(@ten_nguoi_dich, ten_nguoi_dich)
        WHERE ma_sach = @ma_sach;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROC 5: sp_CapNhatGia (CLEAN VERSION)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_CapNhatGia
    @ma_sach INT,
    @gia_moi MONEY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Add to History (Trigger checks @gia_moi here)
        INSERT INTO gia_ban (ma_sach, gia) VALUES (@ma_sach, @gia_moi);
        DECLARE @new_price_id INT = SCOPE_IDENTITY();

        -- 2. Update Cache & Pointer
        UPDATE sach 
        SET gia_hien_tai = @gia_moi, ma_gia_hien_tai = @new_price_id 
        WHERE ma_sach = @ma_sach;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROC 6: sp_ThemDanhGia (CLEAN VERSION)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_ThemDanhGia
    @ma_sach INT,
    @ma_khach_hang INT,
    @so_sao INT,
    @noi_dung NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 1. Insert Raw Review (Trigger checks @so_sao here)
        INSERT INTO danh_gia (ma_sach, ma_khach_hang, so_sao, noi_dung, ngay_danh_gia)
        VALUES (@ma_sach, @ma_khach_hang, @so_sao, @noi_dung, GETDATE());

        -- 2. Calculate Math
        DECLARE @new_avg DECIMAL(3,2);
        DECLARE @new_count INT;

        SELECT 
            @new_avg = CAST(AVG(CAST(so_sao AS DECIMAL(10,2))) AS DECIMAL(3,2)),
            @new_count = COUNT(*)
        FROM danh_gia 
        WHERE ma_sach = @ma_sach;

        -- 3. Insert Snapshot & Update Cache
        INSERT INTO tong_hop_danh_gia (ma_sach, diem_trung_binh, tong_luot_danh_gia)
        VALUES (@ma_sach, @new_avg, @new_count);
        DECLARE @rid INT = SCOPE_IDENTITY();

        UPDATE sach 
        SET so_sao_trung_binh = @new_avg, 
            tong_so_danh_gia = @new_count,
            ma_rating_hien_tai = @rid
        WHERE ma_sach = @ma_sach;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT N'Clean Procedures Updated Successfully!';
GO

-- ======================================================
-- PROCEDURE 7: sp_XoaSach (Soft Delete)
-- ======================================================
CREATE OR ALTER PROCEDURE sp_XoaSach
    @ma_sach INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE sach SET da_xoa = 1 WHERE ma_sach = @ma_sach;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ======================================================
-- PROCEDURE 8: Search Books with Voucher
-- FIXED for V4 Schema (No 'khuyen_mai_voucher' table)
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
    WHERE S.da_xoa = 0 
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
        SELECT ma_sach, SUM(so_luong_ton) AS TongTon
        FROM so_luong_sach_kho 
        GROUP BY ma_sach
        HAVING SUM(so_luong_ton) > 0
    ) AS KHO_TON ON SLQ.ma_sach = KHO_TON.ma_sach
    -- Fix: Vouchers now link to NXB directly (or are null for global)
    LEFT JOIN voucher AS V 
        ON (V.ma_nxb = NXB.ma_nxb OR V.ma_nxb IS NULL)
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
-- PROCEDURE 9: Get Reviews
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

PRINT N'All Procedures (V4) updated successfully!';
GO
