USE book_store;
GO

-- ======================================================
-- 1. GET BOOK DETAIL (Returns IDs and Names for Frontend)
-- ======================================================
CREATE OR ALTER FUNCTION fn_LayChiTietSach (@MaSach INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        s.ma_sach, 
        s.ten_sach, 
        s.gia_hien_tai, 
        s.so_sao_trung_binh, 
        s.ten_nguoi_dich,
        s.mo_ta, 
        s.hinh_thuc, 
        s.so_trang, 
        s.nam_xuat_ban, 
        s.ngay_du_kien_phat_hanh, 
        s.do_tuoi,
        
        -- Publisher Info
        nxb.ma_nxb,
        nxb.ten_nxb,
        
        -- JSON List of Authors: [{"id": 1, "name": "Nam Cao"}, ...]
        (
            SELECT tg.ma_tg AS id, tg.ten_tg AS name
            FROM tac_gia tg 
            JOIN sach_tac_gia stg ON tg.ma_tg = stg.ma_tg 
            WHERE stg.ma_sach = s.ma_sach
            FOR JSON PATH
        ) AS danh_sach_tac_gia_json,
        
        -- JSON List of Categories: [{"id": 2, "name": "Horror"}, ...]
        (
            SELECT tl.ma_tl AS id, tl.ten_tl AS name
            FROM the_loai tl 
            JOIN sach_the_loai stl ON tl.ma_tl = stl.ma_tl 
            WHERE stl.ma_sach = s.ma_sach
            FOR JSON PATH
        ) AS danh_sach_the_loai_json

    FROM sach s
    JOIN nha_xuat_ban nxb ON s.ma_nxb = nxb.ma_nxb
    WHERE s.ma_sach = @MaSach
);
GO

-- ======================================================
-- FN: Get Books by Category (Fast Style)
-- ======================================================
CREATE OR ALTER FUNCTION fn_LaySachTheoTheLoai (@MaTheLoai INT)
RETURNS TABLE
AS
RETURN
(
    SELECT s.ma_sach, s.ten_sach, s.nam_xuat_ban, s.so_trang, s.gia_hien_tai
    FROM sach s
    JOIN sach_the_loai stl ON s.ma_sach = stl.ma_sach
    WHERE stl.ma_tl = @MaTheLoai
      AND s.da_xoa = 0 
);
GO

-- ======================================================
-- FN: Get Books by Author (Fast Style)
-- ======================================================
CREATE OR ALTER FUNCTION fn_LaySachTheoTacGia (@MaTacGia INT)
RETURNS TABLE
AS
RETURN
(
    SELECT s.ma_sach, s.ten_sach, s.nam_xuat_ban, s.so_trang, s.gia_hien_tai
    FROM sach s
    JOIN sach_tac_gia stg ON s.ma_sach = stg.ma_sach
    WHERE stg.ma_tg = @MaTacGia
      AND s.da_xoa = 0
);
GO

-- ======================================================
-- 2. FUNCTION: Get All Previous Orders (Updated)
-- Returns: History with "Customer Order Number" (STT)
-- ======================================================
CREATE OR ALTER FUNCTION fn_LayTatCaDonHang (@MaKhachHang INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        -- Calculates 1, 2, 3... based on purchase date (Oldest = 1)
        ROW_NUMBER() OVER (ORDER BY thoi_diem_dat_hang ASC) AS stt_don,
        
        ma_don,
        thoi_diem_dat_hang,
        tong_tien_thanh_toan,
        CASE 
            WHEN da_huy = 1 THEN N'Đã hủy'
            WHEN da_giao_hang = 1 THEN N'Đã giao'
            WHEN da_dat_hang = 1 THEN N'Đang xử lý'
            ELSE N'Lỗi trạng thái' 
        END AS trang_thai_hien_thi,
        (SELECT COUNT(*) FROM chi_tiet_don_hang WHERE ma_don = don_hang.ma_don) as tong_so_item
    FROM don_hang
    WHERE ma_khach_hang = @MaKhachHang
      AND (da_dat_hang = 1 OR da_huy = 1) -- Only history
);
GO

-- ======================================================
-- 3. FUNCTION: Get Order/Cart Detail by ID
-- Returns: Items inside a specific Order or Cart
-- ======================================================
CREATE OR ALTER FUNCTION fn_LayChiTietDonHang (@MaDon INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        ct.ma_sach,
        s.ten_sach,
        s.hinh_thuc, -- e.g. Hardcover
        ct.so_luong,
        ct.gia_ban AS gia_tai_thoi_diem_mua,
        (ct.so_luong * ct.gia_ban) AS thanh_tien
    FROM chi_tiet_don_hang ct
    JOIN sach s ON ct.ma_sach = s.ma_sach
    WHERE ct.ma_don = @MaDon
);
GO

-- ======================================================
-- 4. FUNCTION: Get Current Active Basket Info
-- Returns: Basic info of the ONE active cart (if any)
-- ======================================================
CREATE OR ALTER FUNCTION fn_LayGioHangHienTai (@MaKhachHang INT)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP 1
        ma_don,
        thoi_diem_tao_gio_hang,
        tong_tien_thanh_toan,
        (SELECT SUM(so_luong) FROM chi_tiet_don_hang WHERE ma_don = don_hang.ma_don) as tong_so_luong_sach
    FROM don_hang
    WHERE ma_khach_hang = @MaKhachHang
      AND da_dat_hang = 0 
      AND da_huy = 0
    ORDER BY ma_don DESC -- Should only be one, but safety first
);
GO

-- ======================================================
-- HELPER FUNCTION: Check if User Bought & Received Book
-- Returns: 1 (Valid), 0 (Invalid)
-- ======================================================
CREATE OR ALTER FUNCTION fn_KiemTraQuyenDanhGia
(
    @MaKhachHang INT,
    @MaSach INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @KetQua BIT = 0;

    -- Check if there is at least one order that is:
    -- 1. By this customer
    -- 2. Contains this book
    -- 3. Is Delivered (da_giao_hang = 1)
    -- 4. Is Not Cancelled (da_huy = 0)
    IF EXISTS (
        SELECT 1
        FROM don_hang dh
        INNER JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don
        WHERE dh.ma_khach_hang = @MaKhachHang
          AND ct.ma_sach = @MaSach
          AND dh.da_giao_hang = 1
          AND dh.da_huy = 0
    )
    BEGIN
        SET @KetQua = 1;
    END

    RETURN @KetQua;
END;
GO

-- ======================================================
-- FUNCTION: Get My Vouchers
-- Returns: List of valid vouchers owned by the user
-- ======================================================
CREATE OR ALTER FUNCTION fn_LayVoucherCuaToi (@MaKhachHang INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        v.ma_voucher,
        v.ma_code,
        v.ten_voucher,
        v.loai_giam,      -- 'Phần trăm' or 'Số tiền'
        v.gia_tri_giam,   -- 10 or 50000
        v.giam_toi_da,    -- NULL or Max Cap
        v.ket_thuc AS ngay_het_han,
        vtv.so_luong      -- Quantity owned
    FROM voucher_thanh_vien vtv
    JOIN voucher v ON vtv.ma_voucher = v.ma_voucher
    WHERE vtv.ma_khach_hang = @MaKhachHang
      AND vtv.so_luong > 0
      AND v.ket_thuc >= CAST(GETDATE() AS DATE)
);
GO

USE book_store;
GO

-- ======================================================
-- FUNCTION: Get Member Info
-- Logic: Joins Member + Customer tables to get full profile
-- ======================================================
CREATE OR ALTER FUNCTION fn_LayThongTinCaNhan
(
    @MaKhachHang INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        k.ma_khach_hang, 
        k.ho + ' ' + k.ho_ten_dem AS ho_ten,
        k.email, 
        k.sdt, 
        k.ngay_sinh,
        tv.cap_do_thanh_vien, 
        tv.diem_tich_luy, 
        tv.tong_chi_tieu,
        tv.ten_dang_nhap
    FROM thanh_vien tv
    JOIN khach_hang k ON tv.ma_khach_hang = k.ma_khach_hang
    WHERE tv.ma_khach_hang = @MaKhachHang
);
GO

--
-- CURSOR FUNCS BELOW
--
-- ======================================================
-- 1. TABLE FUNCTION: Live Cart Review (Cursor Requirement)
-- Logic: Loops through cart items (CURSOR).
--        Checks total stock vs requested quantity (IF/ELSE).
--        Returns warnings if Stock < Requested.
-- ======================================================
CREATE OR ALTER FUNCTION fn_ReviewGioHang_Live
(
    @MaKhachHang INT
)
RETURNS @KetQua TABLE 
(
    MaSach INT,
    TenSach NVARCHAR(200),
    LoaiCanhBao NVARCHAR(50), -- 'STOCK_WARNING' or 'PRICE_CHANGE'
    NoiDung NVARCHAR(500)
)
AS
BEGIN
    -- [VALIDATE INPUT]
    IF @MaKhachHang IS NULL RETURN;

    -- Variables for Cursor
    DECLARE @MaSach INT, @TenSach NVARCHAR(200);
    DECLARE @GiaTrongGio MONEY, @SoLuongMua INT;
    DECLARE @GiaHienTai MONEY, @TongTonKho INT, @DaXoa BIT;

    -- [CURSOR DEFINITION]
    -- Get items from the active cart (da_dat_hang = 0)
    DECLARE cur_cart CURSOR FOR
        SELECT s.ma_sach, s.ten_sach, ct.gia_ban, ct.so_luong, s.gia_hien_tai, s.da_xoa
        FROM don_hang dh
        JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don
        JOIN sach s ON ct.ma_sach = s.ma_sach
        WHERE dh.ma_khach_hang = @MaKhachHang 
          AND dh.da_dat_hang = 0 
          AND dh.da_huy = 0;

    OPEN cur_cart;
    FETCH NEXT FROM cur_cart INTO @MaSach, @TenSach, @GiaTrongGio, @SoLuongMua, @GiaHienTai, @DaXoa;

    -- [LOOP START]
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Logic 1: Check if product is discontinued
        IF @DaXoa = 1
        BEGIN
            INSERT INTO @KetQua VALUES (@MaSach, @TenSach, 'ERROR', N'Sản phẩm này đã ngừng kinh doanh.');
        END
        ELSE
        BEGIN
            -- Logic 2: Check Stock (Your "fair logic")
            SELECT @TongTonKho = SUM(so_luong_ton) FROM so_luong_sach_kho WHERE ma_sach = @MaSach;
            SET @TongTonKho = ISNULL(@TongTonKho, 0);

            -- If we have less than you want -> Warning
            IF @TongTonKho < @SoLuongMua
            BEGIN
                INSERT INTO @KetQua VALUES (@MaSach, @TenSach, 'STOCK_WARNING', 
                    N'Kho chỉ còn ' + CAST(@TongTonKho AS NVARCHAR(10)) + N' cuốn (Bạn đặt ' + CAST(@SoLuongMua AS NVARCHAR(10)) + N').');
            END

            -- Logic 3: Check Price Integrity
            IF @GiaTrongGio <> @GiaHienTai
            BEGIN
                INSERT INTO @KetQua VALUES (@MaSach, @TenSach, 'PRICE_CHANGE', 
                    N'Giá đã thay đổi: ' + CONVERT(NVARCHAR, @GiaTrongGio, 0) + N' -> ' + CONVERT(NVARCHAR, @GiaHienTai, 0));
            END
        END

        FETCH NEXT FROM cur_cart INTO @MaSach, @TenSach, @GiaTrongGio, @SoLuongMua, @GiaHienTai, @DaXoa;
    END
    -- [LOOP END]

    CLOSE cur_cart;
    DEALLOCATE cur_cart;
    RETURN;
END;
GO

-- ======================================================
-- 2. SCALAR FUNCTION: Find Best Voucher (Cursor Requirement)
-- Logic: Loops through user's vouchers (CURSOR).
--        Calculates potential discount for current cart.
--        Returns the Voucher Code giving the MAX discount.
-- ======================================================
CREATE OR ALTER FUNCTION fn_TimVoucherTotNhat
(
    @MaKhachHang INT
)
RETURNS NVARCHAR(50) -- Returns the Best Voucher Code
AS
BEGIN
    IF @MaKhachHang IS NULL RETURN NULL;

    DECLARE @BestCode NVARCHAR(50) = NULL;
    DECLARE @MaxSaved MONEY = -1; -- Start lower than 0

    -- Variables for Voucher Data
    DECLARE @Code NVARCHAR(50), @Loai NVARCHAR(20), @Val DECIMAL(10,2), @MaxCap MONEY;
    DECLARE @MaNXB INT, @AllBooks BIT, @MaVoucher INT;

    -- [CURSOR DEFINITION]
    DECLARE cur_vouchers CURSOR FOR
        SELECT v.ma_voucher, v.ma_code, v.loai_giam, v.gia_tri_giam, v.giam_toi_da, v.ma_nxb, v.ap_dung_tat_ca_sach
        FROM voucher_thanh_vien vtv
        JOIN voucher v ON vtv.ma_voucher = v.ma_voucher
        WHERE vtv.ma_khach_hang = @MaKhachHang 
          AND vtv.so_luong > 0
          AND GETDATE() BETWEEN v.bat_dau AND v.ket_thuc;

    OPEN cur_vouchers;
    FETCH NEXT FROM cur_vouchers INTO @MaVoucher, @Code, @Loai, @Val, @MaxCap, @MaNXB, @AllBooks;

    -- [LOOP START]
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calculate Eligible Total for THIS voucher
        DECLARE @EligibleTotal MONEY = 0;

        SELECT @EligibleTotal = SUM(ct.so_luong * ct.gia_ban)
        FROM don_hang dh
        JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don
        JOIN sach s ON ct.ma_sach = s.ma_sach
        WHERE dh.ma_khach_hang = @MaKhachHang AND dh.da_dat_hang = 0
          AND (@MaNXB IS NULL OR s.ma_nxb = @MaNXB) -- Check Publisher scope
          AND (@AllBooks = 1 OR EXISTS (SELECT 1 FROM voucher_sach vs WHERE vs.ma_voucher = @MaVoucher AND vs.ma_sach = s.ma_sach)); -- Check Book scope

        SET @EligibleTotal = ISNULL(@EligibleTotal, 0);

        -- If applicable, calculate savings
        IF @EligibleTotal > 0
        BEGIN
            DECLARE @Savings MONEY = 0;
            
            IF @Loai = N'Số tiền' 
                SET @Savings = @Val;
            ELSE 
                SET @Savings = @EligibleTotal * (@Val / 100.0);

            -- Apply Max Cap logic
            IF @MaxCap IS NOT NULL AND @Savings > @MaxCap SET @Savings = @MaxCap;
            IF @Savings > @EligibleTotal SET @Savings = @EligibleTotal;

            -- [COMPARE] Is this better than what we found so far?
            IF @Savings > @MaxSaved
            BEGIN
                SET @MaxSaved = @Savings;
                SET @BestCode = @Code;
            END
        END

        FETCH NEXT FROM cur_vouchers INTO @MaVoucher, @Code, @Loai, @Val, @MaxCap, @MaNXB, @AllBooks;
    END
    -- [LOOP END]

    CLOSE cur_vouchers;
    DEALLOCATE cur_vouchers;

    RETURN @BestCode;
END;
GO

PRINT N'Validation Function Created Successfully!';
GO
