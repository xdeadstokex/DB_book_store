-- ======================================================
--   COMPLETE BOOK STORE DATABASE (SQL Server)
-- ======================================================

IF DB_ID('book_store') IS NULL
    CREATE DATABASE book_store;
GO

USE book_store;
GO

-- ======================================================
--   1. nha_xuat_ban (Publisher)
-- ======================================================
CREATE TABLE nha_xuat_ban (
    ma_nxb INT IDENTITY(1,1) PRIMARY KEY,
    ten_nxb NVARCHAR(200) NOT NULL,
    email NVARCHAR(200) UNIQUE NOT NULL,
    dia_chi NVARCHAR(200) NOT NULL,
    sdt NVARCHAR(20)
);
GO

-- ======================================================
--   2. sach (Book)
-- ======================================================
CREATE TABLE sach (
    ma_sach INT IDENTITY(1,1) PRIMARY KEY,
    ten_sach NVARCHAR(200) NOT NULL,
    nam_xuat_ban INT CHECK (nam_xuat_ban BETWEEN 1900 AND YEAR(GETDATE())),
    ngay_du_kien_co_hang DATE NULL,
    trong_luong DECIMAL(10,2) CHECK (trong_luong >= 0),
    ngay_du_kien_phat_hanh DATE NULL,
    do_tuoi INT CHECK (do_tuoi >= 0),
    kich_thuoc_bao_bi NVARCHAR(100),
    nha_cung_cap NVARCHAR(100),
    so_trang INT CHECK (so_trang > 0),
    so_sao_trung_binh DECIMAL(3,2) CHECK (so_sao_trung_binh BETWEEN 0 AND 5),
    hinh_thuc NVARCHAR(50),
    ngon_ngu NVARCHAR(50),
    mo_ta NVARCHAR(MAX),
    ma_nxb INT NOT NULL,
    
    CONSTRAINT fk_sach_nxb FOREIGN KEY (ma_nxb)
        REFERENCES nha_xuat_ban(ma_nxb)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO

-- ======================================================
--   3. gia_ban (Book Price History)
-- ======================================================
CREATE TABLE gia_ban (
    ma_gia INT IDENTITY(1,1) PRIMARY KEY,
    ma_sach INT NOT NULL,
    gia MONEY NOT NULL CHECK (gia >= 0),
    tu_ngay DATE NOT NULL,
    den_ngay DATE NULL,
    
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE
);
GO

-- ======================================================
--   4. the_loai (Category)
-- ======================================================
CREATE TABLE the_loai (
    ma_tl INT IDENTITY(1,1) PRIMARY KEY,
    ten_tl NVARCHAR(200) NOT NULL
);
GO

-- ======================================================
--   5. sach_the_loai (Book-Category)
-- ======================================================
CREATE TABLE sach_the_loai (
    ma_sach INT NOT NULL,
    ma_tl INT NOT NULL,
    
    PRIMARY KEY (ma_sach, ma_tl),
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE,
    FOREIGN KEY (ma_tl) REFERENCES the_loai(ma_tl) ON DELETE CASCADE
);
GO

-- ======================================================
--   6. tac_gia (Author)
-- ======================================================
CREATE TABLE tac_gia (
    ma_tg INT IDENTITY(1,1) PRIMARY KEY,
    ten_tg NVARCHAR(200) NOT NULL,
    quoc_tich NVARCHAR(100),
    mo_ta NVARCHAR(MAX)
);
GO

-- ======================================================
--   7. sach_tac_gia (Book-Author)
-- ======================================================
CREATE TABLE sach_tac_gia (
    ma_sach INT NOT NULL,
    ma_tg INT NOT NULL,
    
    PRIMARY KEY (ma_sach, ma_tg),
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE,
    FOREIGN KEY (ma_tg) REFERENCES tac_gia(ma_tg) ON DELETE CASCADE
);
GO

-- ======================================================
--   8. nguoi_dich (Translator)
-- ======================================================
CREATE TABLE nguoi_dich (
    ma_ng_dich INT IDENTITY(1,1) PRIMARY KEY,
    ten_ng_dich NVARCHAR(200) NOT NULL,
    ngon_ngu_dich NVARCHAR(128) NOT NULL
);
GO

-- ======================================================
--   9. sach_nguoi_dich (Book-Translator)
-- ======================================================
CREATE TABLE sach_nguoi_dich (
    ma_sach INT NOT NULL,
    ma_ng_dich INT NOT NULL,
    
    PRIMARY KEY (ma_sach, ma_ng_dich),
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE,
    FOREIGN KEY (ma_ng_dich) REFERENCES nguoi_dich(ma_ng_dich) ON DELETE CASCADE
);
GO

-- ======================================================
--   10. khach_hang (Customer - Base)
-- ======================================================
CREATE TABLE khach_hang (
    ma_khach_hang INT IDENTITY(1,1) PRIMARY KEY,
    ho_ten_dem NVARCHAR(200),
    ho NVARCHAR(100),
    ngay_sinh DATE,
    email NVARCHAR(200) UNIQUE NOT NULL,
    so_dien_thoai NVARCHAR(20)
);
GO

-- ======================================================
--   11. thanh_vien (Member)
-- ======================================================
CREATE TABLE thanh_vien (
    ma_khach_hang INT PRIMARY KEY,
    cap_do_thanh_vien NVARCHAR(50),
    ten_dang_nhap NVARCHAR(100) UNIQUE NOT NULL,
    ngay_dang_ky DATE,
    gioi_tinh NVARCHAR(10),
    mat_khau_ma_hoa NVARCHAR(200),
    tuoi INT,
    tong_chi_tieu DECIMAL(18,2) DEFAULT 0,
    diem_tich_luy INT DEFAULT 0,
    
    FOREIGN KEY (ma_khach_hang) REFERENCES khach_hang(ma_khach_hang)
);
GO

-- ======================================================
--   12. khach (Guest)
-- ======================================================
CREATE TABLE khach (
    ma_khach_hang INT PRIMARY KEY,
    ma_session NVARCHAR(200) NOT NULL,
    
    FOREIGN KEY (ma_khach_hang) REFERENCES khach_hang(ma_khach_hang)
);
GO

-- ======================================================
--   13. dia_chi_cu_the (Address)
-- ======================================================
CREATE TABLE dia_chi_cu_the (
    ma_dia_chi INT IDENTITY(1,1) PRIMARY KEY,
    ma_khach_hang INT NOT NULL,
    thanh_pho NVARCHAR(200),
    quan_huyen NVARCHAR(200),
    phuong_xa NVARCHAR(200),
    dia_chi_nha NVARCHAR(300),
    
    FOREIGN KEY (ma_khach_hang) REFERENCES khach_hang(ma_khach_hang) ON DELETE CASCADE
);
GO

-- ======================================================
--   14. voucher (Voucher)
-- ======================================================
CREATE TABLE voucher (
    ma_voucher INT IDENTITY(1,1) PRIMARY KEY,
    ma_nxb INT NOT NULL,
    ten_voucher NVARCHAR(200) NOT NULL,
    bat_dau DATE NOT NULL,
    ket_thuc DATE NOT NULL,
    loai_giam NVARCHAR(20) CHECK (loai_giam IN (N'Phần trăm', N'Số tiền')),
    gia_tri_giam DECIMAL(10,2) NOT NULL CHECK (gia_tri_giam > 0),
    
    FOREIGN KEY (ma_nxb) REFERENCES nha_xuat_ban(ma_nxb) ON DELETE CASCADE
);
GO

-- ======================================================
--   15. khuyen_mai_voucher (Voucher Promotion)
-- ======================================================
CREATE TABLE khuyen_mai_voucher (
    ma_voucher INT PRIMARY KEY,
    dieu_kien_ap_dung NVARCHAR(MAX),
    ngay_het_han DATETIME,
    
    FOREIGN KEY (ma_voucher) REFERENCES voucher(ma_voucher) ON DELETE CASCADE
);
GO

-- ======================================================
--   16. su_dung_voucher (Voucher Usage)
-- ======================================================
CREATE TABLE su_dung_voucher (
    ma_voucher INT NOT NULL,
    ma_khach_hang INT NOT NULL,
    ngay_su_dung DATETIME DEFAULT GETDATE(),
    
    PRIMARY KEY (ma_voucher, ma_khach_hang),
    FOREIGN KEY (ma_voucher) REFERENCES voucher(ma_voucher) ON DELETE CASCADE,
    FOREIGN KEY (ma_khach_hang) REFERENCES thanh_vien(ma_khach_hang) ON DELETE CASCADE
);
GO

-- ======================================================
--   17. don_hang (Order)
-- ======================================================
CREATE TABLE don_hang (
    ma_don INT IDENTITY(1,1) PRIMARY KEY,
    ma_khach_hang INT NOT NULL,
    ma_voucher INT NULL,
    thoi_diem_dat_hang DATETIME NOT NULL DEFAULT GETDATE(),
    tong_tien_thanh_toan MONEY NOT NULL CHECK (tong_tien_thanh_toan >= 0),
    trang_thai_don_hang NVARCHAR(50) NOT NULL,
    gia_tri_giam_gia MONEY DEFAULT 0,
    ngay_du_kien_nhan_hang DATETIME NULL,
    
    FOREIGN KEY (ma_khach_hang) REFERENCES khach_hang(ma_khach_hang) ON DELETE CASCADE,
    FOREIGN KEY (ma_voucher) REFERENCES voucher(ma_voucher) ON DELETE SET NULL
);
GO

-- ======================================================
--   18. chi_tiet_don_hang (Order Detail)
-- ======================================================
CREATE TABLE chi_tiet_don_hang (
    ma_don INT NOT NULL,
    ma_sach INT NOT NULL,
    gia_ban MONEY NOT NULL CHECK (gia_ban >= 0),
    so_luong INT NOT NULL CHECK (so_luong > 0),
    the_loai NVARCHAR(100),
    
    PRIMARY KEY (ma_don, ma_sach),
    FOREIGN KEY (ma_don) REFERENCES don_hang(ma_don) ON DELETE CASCADE,
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE NO ACTION
);
GO

-- ======================================================
--   19. thanh_toan (Payment)
-- ======================================================
CREATE TABLE thanh_toan (
    ma_thanh_toan INT IDENTITY(1,1) PRIMARY KEY,
    ma_don INT NOT NULL UNIQUE,
    hinh_thuc NVARCHAR(50) NOT NULL,
    trinh_trang NVARCHAR(50) NOT NULL,
    thanh_tien MONEY NOT NULL CHECK (thanh_tien >= 0),
    
    FOREIGN KEY (ma_don) REFERENCES don_hang(ma_don) ON DELETE CASCADE
);
GO

-- ======================================================
--   20. kho (Inventory)
-- ======================================================
CREATE TABLE kho (
    ma_kho INT IDENTITY(1,1) PRIMARY KEY,
    ma_sach INT NOT NULL UNIQUE,
    so_luong_ton INT NOT NULL CHECK (so_luong_ton >= 0),
    
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE
);
GO

-- ======================================================
--   21. danh_gia (Review)
-- ======================================================
CREATE TABLE danh_gia (
    ma_dg INT IDENTITY(1,1) PRIMARY KEY,
    ma_sach INT NOT NULL,
    ma_khach_hang INT NOT NULL,
    noi_dung NVARCHAR(MAX),
    so_sao INT NOT NULL CHECK (so_sao BETWEEN 1 AND 5),
    ngay_danh_gia DATETIME DEFAULT GETDATE(),
    
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE,
    FOREIGN KEY (ma_khach_hang) REFERENCES thanh_vien(ma_khach_hang) ON DELETE CASCADE
);
GO

-- ======================================================
--   INDEXES FOR PERFORMANCE
-- ======================================================
CREATE INDEX idx_sach_nxb ON sach(ma_nxb);
CREATE INDEX idx_gia_ban_sach ON gia_ban(ma_sach);
CREATE INDEX idx_don_hang_khach ON don_hang(ma_khach_hang);
CREATE INDEX idx_don_hang_ngay ON don_hang(thoi_diem_dat_hang);
CREATE INDEX idx_danh_gia_sach ON danh_gia(ma_sach);
GO

-- ======================================================
--   SAMPLE DATA
-- ======================================================

-- Publishers
INSERT INTO nha_xuat_ban (ten_nxb, email, dia_chi, sdt) VALUES 
(N'Nhà xuất bản Trẻ', 'contact@nxbtre.com.vn', N'161B Lý Chính Thắng, Q.3, TP.HCM', '028-39316289'),
(N'Nhà xuất bản Kim Đồng', 'info@nxbkimdong.com.vn', N'55 Quang Trung, Hai Bà Trưng, Hà Nội', '024-39434730'),
(N'Nhà xuất bản Văn học', 'nxbvanhoc@hn.vnn.vn', N'18 Nguyễn Trường Tộ, Ba Đình, Hà Nội', '024-38223500');
GO

-- Authors
INSERT INTO tac_gia (ten_tg, quoc_tich, mo_ta) VALUES 
(N'Nguyễn Nhật Ánh', N'Việt Nam', N'Nhà văn nổi tiếng với các tác phẩm văn học thiếu nhi'),
(N'Tô Hoài', N'Việt Nam', N'Nhà văn, nhà thơ Việt Nam'),
(N'Nam Cao', N'Việt Nam', N'Nhà văn hiện thực phê phán');
GO

-- Translators
INSERT INTO nguoi_dich (ten_ng_dich, ngon_ngu_dich) VALUES 
(N'Đỗ Kh.', N'Tiếng Anh'),
(N'Lê Thu Hương', N'Tiếng Pháp');
GO

-- Categories
INSERT INTO the_loai (ten_tl) VALUES 
(N'Văn học'),
(N'Thiếu nhi'),
(N'Triết học');
GO

-- Books
INSERT INTO sach (ten_sach, nam_xuat_ban, so_trang, ngon_ngu, ma_nxb) VALUES 
(N'Tôi thấy hoa vàng trên cỏ xanh', 2010, 456, N'Tiếng Việt', 1),
(N'Dế Mèn phiêu lưu ký', 1941, 256, N'Tiếng Việt', 2);
GO

-- Prices
INSERT INTO gia_ban (ma_sach, gia, tu_ngay) VALUES 
(1, 95000, '2024-01-01'),
(2, 65000, '2024-01-01');
GO

-- Book-Author
INSERT INTO sach_tac_gia (ma_sach, ma_tg) VALUES (1, 1), (2, 2);
GO

-- Book-Category
INSERT INTO sach_the_loai (ma_sach, ma_tl) VALUES (1, 1), (2, 2);
GO

-- Inventory
INSERT INTO kho (ma_sach, so_luong_ton) VALUES (1, 100), (2, 50);
GO

PRINT 'Database created successfully!';
GO
