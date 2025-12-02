USE book_store;
GO

-- ======================================================
-- 1. GET BOOK DETAIL (Single Row with Aggregated Strings)
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
        
        -- Publisher Name
        nxb.ten_nxb,
        
        -- Combine Authors into one string: "Nam Cao, To Hoai"
        (
            SELECT STRING_AGG(tg.ten_tg, ', ') 
            FROM tac_gia tg 
            JOIN sach_tac_gia stg ON tg.ma_tg = stg.ma_tg 
            WHERE stg.ma_sach = s.ma_sach
        ) AS danh_sach_tac_gia,
        
        -- Combine Categories into one string: "Novel, Horror"
        (
            SELECT STRING_AGG(tl.ten_tl, ', ') 
            FROM the_loai tl 
            JOIN sach_the_loai stl ON tl.ma_tl = stl.ma_tl 
            WHERE stl.ma_sach = s.ma_sach
        ) AS danh_sach_the_loai

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
    SELECT 
        s.ma_sach, 
        s.ten_sach, 
        s.nam_xuat_ban, 
        s.so_trang, 
        s.gia_hien_tai
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
    SELECT 
        s.ma_sach, 
        s.ten_sach, 
        s.nam_xuat_ban, 
        s.so_trang, 
        s.gia_hien_tai
    FROM sach s
    JOIN sach_tac_gia stg ON s.ma_sach = stg.ma_sach
    WHERE stg.ma_tg = @MaTacGia
      AND s.da_xoa = 0
);
GO
