USE book_store;
GO

-- ======================================================
-- FUNCTION: fn_CheckBestSellerStatus
-- Check if book is best-seller in last 30 days
-- Uses: IF, LOOP (WHILE), CURSOR, Query
-- ======================================================
CREATE OR ALTER FUNCTION fn_CheckBestSellerStatus (
    @BookID INT,
    @MinQuantity INT -- Minimum quantity to be "best seller"
)
RETURNS @StatusTable TABLE (
    BookID INT,
    BookName NVARCHAR(200),
    IsBestSeller BIT,
    SalesLast30Days INT
)
AS
BEGIN
    -- 1. Validate input parameters (IF)
    IF @BookID IS NULL OR @MinQuantity <= 0
    BEGIN
        RETURN;
    END

    DECLARE @TotalSales INT = 0;
    DECLARE @CurrentBookName NVARCHAR(200);
    DECLARE @BestSellerStatus BIT = 0;
    DECLARE @SaleQuantity INT;
    
    -- 2. Declare CURSOR to iterate through sales
    DECLARE SalesCursor CURSOR FOR
    SELECT ct.so_luong
    FROM don_hang dh
    JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don  -- Fixed: was joining to itself
    WHERE ct.ma_sach = @BookID
      AND dh.thoi_diem_dat_hang >= DATEADD(day, -30, GETDATE())
      AND dh.trang_thai_don_hang = N'Đã giao';  -- Only count delivered orders

    OPEN SalesCursor;
    FETCH NEXT FROM SalesCursor INTO @SaleQuantity;

    -- 3. Loop through cursor (WHILE)
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @TotalSales = @TotalSales + @SaleQuantity;
        FETCH NEXT FROM SalesCursor INTO @SaleQuantity;
    END

    CLOSE SalesCursor;
    DEALLOCATE SalesCursor;

    -- 4. Get book name (Query)
    SELECT @CurrentBookName = ten_sach
    FROM sach
    WHERE ma_sach = @BookID;

    -- 5. Check best seller status (IF)
    IF @TotalSales >= @MinQuantity
    BEGIN
        SET @BestSellerStatus = 1;
    END

    -- 6. Return result
    INSERT INTO @StatusTable (BookID, BookName, IsBestSeller, SalesLast30Days)
    VALUES (@BookID, @CurrentBookName, @BestSellerStatus, @TotalSales);

    RETURN;
END;
GO

-- ======================================================
-- FUNCTION 2: fn_TinhDoanhThuTheoKhachHang
-- Calculate customer revenue with cursor
-- Uses: IF, LOOP, CURSOR, Query
-- ======================================================
CREATE OR ALTER FUNCTION fn_TinhDoanhThuTheoKhachHang (
    @MaKhachHang INT
)
RETURNS @DoanhThu TABLE (
    MaKhachHang INT,
    TenKhachHang NVARCHAR(300),
    SoDonHang INT,
    TongDoanhThu MONEY,
    CapDoThanhVien NVARCHAR(50)
)
AS
BEGIN
    -- Validate input
    IF @MaKhachHang IS NULL OR @MaKhachHang <= 0
    BEGIN
        RETURN;
    END

    -- Check customer exists
    IF NOT EXISTS (SELECT 1 FROM khach_hang WHERE ma_khach_hang = @MaKhachHang)
    BEGIN
        RETURN;
    END

    DECLARE @TenKH NVARCHAR(300);
    DECLARE @SoDon INT = 0;
    DECLARE @TongTien MONEY = 0;
    DECLARE @CapDo NVARCHAR(50);
    DECLARE @GiaDon MONEY;
    
    -- Get customer name
    SELECT @TenKH = CONCAT(ho, ' ', ho_ten_dem)
    FROM khach_hang
    WHERE ma_khach_hang = @MaKhachHang;
    
    -- Cursor to loop through orders
    DECLARE OrderCursor CURSOR FOR
    SELECT tong_tien_thanh_toan
    FROM don_hang
    WHERE ma_khach_hang = @MaKhachHang
      AND trang_thai_don_hang = N'Đã giao';

    OPEN OrderCursor;
    FETCH NEXT FROM OrderCursor INTO @GiaDon;

    -- Loop and calculate
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SoDon = @SoDon + 1;
        SET @TongTien = @TongTien + @GiaDon;
        FETCH NEXT FROM OrderCursor INTO @GiaDon;
    END

    CLOSE OrderCursor;
    DEALLOCATE OrderCursor;

    -- Determine membership tier
    IF @TongTien >= 10000000
        SET @CapDo = N'Gold';
    ELSE IF @TongTien >= 5000000
        SET @CapDo = N'VIP';
    ELSE IF @TongTien >= 1000000
        SET @CapDo = N'Standard';
    ELSE
        SET @CapDo = N'Basic';

    -- Return result
    INSERT INTO @DoanhThu
    VALUES (@MaKhachHang, @TenKH, @SoDon, @TongTien, @CapDo);

    RETURN;
END;
GO

-- ======================================================
-- TEST FUNCTIONS
-- ======================================================

PRINT N'--- Test fn_CheckBestSellerStatus ---';
-- Check if book 1 is best seller (min 5 sold in last 30 days)
SELECT * FROM dbo.fn_CheckBestSellerStatus(1, 5);
GO

-- Check multiple books
SELECT * FROM dbo.fn_CheckBestSellerStatus(1, 2);
SELECT * FROM dbo.fn_CheckBestSellerStatus(2, 1);
SELECT * FROM dbo.fn_CheckBestSellerStatus(3, 10);
GO

PRINT N'--- Test fn_TinhDoanhThuTheoKhachHang ---';
-- Calculate revenue for customer 1
SELECT * FROM dbo.fn_TinhDoanhThuTheoKhachHang(1);
GO

-- Check all customers
SELECT * FROM dbo.fn_TinhDoanhThuTheoKhachHang(1)
UNION ALL
SELECT * FROM dbo.fn_TinhDoanhThuTheoKhachHang(2)
UNION ALL
SELECT * FROM dbo.fn_TinhDoanhThuTheoKhachHang(3);
GO

PRINT N'Functions with cursor created successfully!';
GO