USE book_store;
GO

-- ======================================================
-- FUNCTION 1: Check if customer can review a book
-- Returns: 1 = Can review, 0 = Cannot
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
    
    -- Check if customer is a member and bought the book (order delivered)
    IF EXISTS (
        SELECT 1
        FROM don_hang dh
        INNER JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don
        INNER JOIN thanh_vien tv ON dh.ma_khach_hang = tv.ma_khach_hang
        WHERE dh.ma_khach_hang = @MaKhachHang
          AND ct.ma_sach = @MaSach
          AND dh.trang_thai_don_hang = N'Đã giao'
    )
        SET @KetQua = 1;
    
    RETURN @KetQua;
END;
GO

-- ======================================================
-- FUNCTION 2: Calculate total inventory across all warehouses
-- Returns: Total quantity of a book in all warehouses
-- ======================================================
CREATE OR ALTER FUNCTION fn_TinhTongTonKho
(
    @MaSach INT
)
RETURNS INT
AS
BEGIN
    DECLARE @TongTon INT;
    
    SELECT @TongTon = SUM(so_luong_ton)
    FROM so_luong_sach_kho
    WHERE ma_sach = @MaSach;
    
    RETURN ISNULL(@TongTon, 0);
END;
GO

-- ======================================================
-- FUNCTION 3: Calculate discount amount for voucher
-- Returns: Actual discount value in money
-- ======================================================
CREATE OR ALTER FUNCTION fn_TinhGiaTriGiamGia
(
    @MaVoucher INT,
    @GiaTriDonHang MONEY
)
RETURNS MONEY
AS
BEGIN
    DECLARE @GiamGia MONEY = 0;
    DECLARE @LoaiGiam NVARCHAR(20);
    DECLARE @GiaTriGiam DECIMAL(10,2);
    
    -- Get voucher info
    SELECT @LoaiGiam = loai_giam, @GiaTriGiam = gia_tri_giam
    FROM voucher
    WHERE ma_voucher = @MaVoucher
      AND GETDATE() BETWEEN bat_dau AND ket_thuc;
    
    -- Calculate discount
    IF @LoaiGiam = N'Phần trăm'
        SET @GiamGia = @GiaTriDonHang * (@GiaTriGiam / 100.0);
    ELSE IF @LoaiGiam = N'Số tiền'
        SET @GiamGia = @GiaTriGiam;
    
    -- Discount cannot exceed order value
    IF @GiamGia > @GiaTriDonHang
        SET @GiamGia = @GiaTriDonHang;
    
    RETURN @GiamGia;
END;
GO

-- ======================================================
-- FUNCTION 4: Get customer membership tier based on spending
-- Returns: Membership tier name
-- ======================================================
CREATE OR ALTER FUNCTION fn_XacDinhCapDoThanhVien
(
    @TongChiTieu DECIMAL(18,2)
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @CapDo NVARCHAR(50);
    
    IF @TongChiTieu >= 10000000
        SET @CapDo = N'Gold';
    ELSE IF @TongChiTieu >= 5000000
        SET @CapDo = N'VIP';
    ELSE IF @TongChiTieu >= 1000000
        SET @CapDo = N'Standard';
    ELSE
        SET @CapDo = N'Basic';
    
    RETURN @CapDo;
END;
GO

-- ======================================================
-- TEST FUNCTIONS
-- ======================================================

PRINT N'--- Test fn_KiemTraQuyenDanhGia ---';
-- Customer 1 bought book 1 (order delivered) → Result = 1
SELECT dbo.fn_KiemTraQuyenDanhGia(1, 1) AS KetQua1;

-- Customer 4 hasn't bought book 1 → Result = 0
SELECT dbo.fn_KiemTraQuyenDanhGia(4, 1) AS KetQua2;
GO

PRINT N'--- Test fn_TinhTongTonKho ---';
-- Total inventory for book 1 across all warehouses
SELECT dbo.fn_TinhTongTonKho(1) AS TongTonKho;
GO

PRINT N'--- Test fn_TinhGiaTriGiamGia ---';
-- Need to insert a test voucher first
INSERT INTO voucher (ma_nxb, ten_voucher, bat_dau, ket_thuc, loai_giam, gia_tri_giam)
VALUES (1, N'Giảm 10%', '2024-01-01', '2024-12-31', N'Phần trăm', 10);
GO

-- Calculate discount for 200,000 VND order with 10% voucher
DECLARE @MaVoucher INT = (SELECT TOP 1 ma_voucher FROM voucher ORDER BY ma_voucher DESC);
SELECT dbo.fn_TinhGiaTriGiamGia(@MaVoucher, 200000) AS GiamGia;
GO

PRINT N'--- Test fn_XacDinhCapDoThanhVien ---';
SELECT dbo.fn_XacDinhCapDoThanhVien(500000) AS CapDo1;    -- Basic
SELECT dbo.fn_XacDinhCapDoThanhVien(2000000) AS CapDo2;   -- Standard
SELECT dbo.fn_XacDinhCapDoThanhVien(6000000) AS CapDo3;   -- VIP
SELECT dbo.fn_XacDinhCapDoThanhVien(12000000) AS CapDo4;  -- Gold
GO

PRINT N'Functions created successfully!';
GO