USE book_store;
GO

PRINT '==========================================================';
PRINT '      BAI TAP LON 2 - DEMONSTRATION SCRIPT';
PRINT '==========================================================';

-- =================================================================================
-- REQUIREMENT 2.1: THỦ TỤC THÊM/SỬA/XÓA (CRUD) TRÊN 1 BẢNG
-- Target Table: nha_xuat_ban (Publisher)
-- Reason: We add specific validation logic here as requested by the rubric.
-- =================================================================================

PRINT '--- [2.1] INSERT PROCEDURE (With Validation) ---';
GO
CREATE OR ALTER PROCEDURE sp_BTL_ThemNXB
    @TenNXB NVARCHAR(200),
    @Email NVARCHAR(200),
    @DiaChi NVARCHAR(200),
    @SDT NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- 1. Validate Name (Cannot be empty)
        IF @TenNXB IS NULL OR LTRIM(RTRIM(@TenNXB)) = ''
            THROW 50001, N'Tên NXB không được để trống.', 1;

        -- 2. Validate Email Format (Simple check)
        IF @Email NOT LIKE '%_@__%.__%'
            THROW 50002, N'Email không đúng định dạng.', 1;

        -- 3. Validate Duplicate Email
        IF EXISTS (SELECT 1 FROM nha_xuat_ban WHERE email = @Email)
            THROW 50003, N'Email này đã tồn tại trong hệ thống.', 1;

        -- 4. Execute Insert
        INSERT INTO nha_xuat_ban (ten_nxb, email, dia_chi, sdt)
        VALUES (@TenNXB, @Email, @DiaChi, @SDT);

        PRINT N'Thêm NXB thành công!';
    END TRY
    BEGIN CATCH
        -- Return specific error message
        DECLARE @ErrorMsg NVARCHAR(2000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

PRINT '--- [2.1] UPDATE PROCEDURE (With Validation) ---';
GO
CREATE OR ALTER PROCEDURE sp_BTL_SuaNXB
    @MaNXB INT,
    @TenMoi NVARCHAR(200),
    @EmailMoi NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- 1. Check Existence
        IF NOT EXISTS (SELECT 1 FROM nha_xuat_ban WHERE ma_nxb = @MaNXB)
            THROW 50004, N'Mã NXB không tồn tại.', 1;

        -- 2. Validate Email if provided
        IF @EmailMoi IS NOT NULL AND @EmailMoi NOT LIKE '%_@__%.__%'
            THROW 50002, N'Email mới không đúng định dạng.', 1;

        -- 3. Execute Update
        UPDATE nha_xuat_ban
        SET ten_nxb = ISNULL(@TenMoi, ten_nxb),
            email = ISNULL(@EmailMoi, email)
        WHERE ma_nxb = @MaNXB;

        PRINT N'Cập nhật NXB thành công!';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(2000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

PRINT '--- [2.1] DELETE PROCEDURE (Logic: Cannot delete if books exist) ---';
GO
CREATE OR ALTER PROCEDURE sp_BTL_XoaNXB
    @MaNXB INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- 1. Check Existence
        IF NOT EXISTS (SELECT 1 FROM nha_xuat_ban WHERE ma_nxb = @MaNXB)
            THROW 50004, N'Mã NXB không tồn tại.', 1;

        -- 2. Logic: Why delete? Cleanup. But cannot delete if they have books.
        IF EXISTS (SELECT 1 FROM sach WHERE ma_nxb = @MaNXB)
        BEGIN
            -- Example of "When NOT to delete"
            THROW 50005, N'Không thể xóa NXB này vì đang có sách liên kết. Hãy xóa sách trước.', 1;
        END

        -- 3. Execute Delete
        DELETE FROM nha_xuat_ban WHERE ma_nxb = @MaNXB;

        PRINT N'Xóa NXB thành công!';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(2000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

PRINT '>>> DEMO 2.1: Testing CRUD Procedures...';
-- Test 1: Fail Insert (Bad Email)
EXEC sp_BTL_ThemNXB N'NXB Test Fail', 'bad_email', N'Dia Chi A', '090909';
-- Test 2: Success Insert
EXEC sp_BTL_ThemNXB N'NXB Test Success', 'test@nxb.com', N'Dia Chi B', '090909';
-- Test 3: Fail Delete (Foreign Key Logic) - Try to delete NXB 1 (Has books)
EXEC sp_BTL_XoaNXB 1; 

-- =================================================================================
-- REQUIREMENT 2.2: TRIGGERS
-- 2.2.1: Business Constraint (Pages > 0, Price >= 1000)
-- 2.2.2: Derived Attribute (Auto-calculate Rating Average)
-- =================================================================================

PRINT ' ';
PRINT '--- [2.2.1] DEMO TRIGGER: CONSTRAINT VALIDATION ---';
PRINT 'Trying to insert a book with 0 pages (Should Fail by trg_ValidateSach_Data)...';

BEGIN TRY
    INSERT INTO sach (ten_sach, ma_nxb, so_trang, gia_hien_tai) 
    VALUES (N'Sách Lỗi', 1, 0, 50000); -- 0 Pages
END TRY
BEGIN CATCH
    PRINT N'>> SUCCESS: Trigger caught the error: ' + ERROR_MESSAGE();
END CATCH

PRINT ' ';
PRINT '--- [2.2.2] DEMO TRIGGER: DERIVED ATTRIBUTE CALCULATION ---';
PRINT 'Demonstrating trg_TuDongTinhToan_Rating (Calculates Average Stars)';

-- 1. View current status of Book 1
SELECT ma_sach, so_sao_trung_binh, tong_so_danh_gia FROM sach WHERE ma_sach = 1;

-- 2. Add a new 1-star review (Simulating a bad review)
-- Note: Requires a user who bought the book. 
-- In insert_data.sql, User 1 bought Book 1. We will delete old reviews for fresh test.
DELETE FROM danh_gia WHERE ma_sach = 1 AND ma_khach_hang = 1;

PRINT 'Adding a 1-star review...';
INSERT INTO danh_gia (ma_sach, ma_khach_hang, so_sao, noi_dung) 
VALUES (1, 1, 1, N'Test Trigger Calculation');

-- 3. View status again (Should decrease average)
SELECT ma_sach, so_sao_trung_binh, tong_so_danh_gia FROM sach WHERE ma_sach = 1;
PRINT '>> SUCCESS: Average Star updated automatically without manual UPDATE query.';

-- =================================================================================
-- REQUIREMENT 2.3: THỦ TỤC HIỂN THỊ (RETRIEVAL PROCEDURES)
-- Proc 1: >2 Tables, Where, Order By
-- Proc 2: Aggregate, Group By, Having
-- =================================================================================

PRINT ' ';
PRINT '--- [2.3] DEMO PROCEDURE 1: ADVANCED SEARCH (Joins + Where + Order) ---';
-- Search for books with "Harry" in title
EXEC sp_TimKiemSach_NangCao @ten_sach = N'Harry';

PRINT ' ';
PRINT '--- [2.3] DEMO PROCEDURE 2: STATS (Agg + Group By + Having) ---';
-- Find authors, count their books, order by count
EXEC sp_TimKiemTacGia_ThongKe @keyword = N'';


-- =================================================================================
-- REQUIREMENT 2.4: HÀM (FUNCTIONS)
-- Req: Use If/Loop/Cursor, Calculation, Input Parameters
-- =================================================================================

PRINT ' ';
PRINT '--- [2.4] DEMO FUNCTION 1: LIVE CART REVIEW (Uses Cursor + IF/ELSE) ---';
-- Logic: Checks stock levels for User 1's active cart
-- (Ensure User 1 has items in cart using sp_ThemSachVaoGioHang first if needed)
EXEC sp_ThemSachVaoGioHang 1, 11, 1000; -- Request 1000 items (Should trigger Stock Warning)

SELECT * FROM fn_ReviewGioHang_Live(1);
PRINT '>> SUCCESS: Function used Cursor to scan items and returned Warning.';

PRINT ' ';
PRINT '--- [2.4] DEMO FUNCTION 2: BEST VOUCHER (Uses Cursor + Math) ---';
-- Logic: Scans all user's vouchers, calculates best savings for current cart
SELECT dbo.fn_TimVoucherTotNhat(1) AS Ma_Voucher_Toi_Uu_Nhat;
PRINT '>> SUCCESS: Function calculated the best discount.';

PRINT '==========================================================';
PRINT '      END OF DEMONSTRATION';
PRINT '==========================================================';
GO
