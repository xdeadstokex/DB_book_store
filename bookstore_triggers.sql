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
-- TRIGGER C: Validate Rating (Universal Rules)
-- Enforces: Stars 1-5
-- ======================================================
CREATE OR ALTER TRIGGER trg_ValidateDanhGia_Input
ON danh_gia
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE so_sao < 1 OR so_sao > 5)
    BEGIN
        RAISERROR(N'Điểm đánh giá phải từ 1 đến 5 sao.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

PRINT N'Validation Triggers Created Successfully!';
GO
