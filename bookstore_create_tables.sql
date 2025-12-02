-- ======================================================
--     BOOK STORE DATABASE (SQL Server) - CLEAN V4
-- ======================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DB_ID('book_store') IS NULL
    CREATE DATABASE book_store;
GO

USE book_store;
GO

-- ======================================================
-- 1. nha_xuat_ban (Publisher)
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
-- 2. sach (Book)
-- ======================================================
CREATE TABLE sach (
    ma_sach INT IDENTITY(1,1) PRIMARY KEY,
    ten_sach NVARCHAR(200) NOT NULL,

    -- [MERGED TRANSLATOR] - Just a name, no complex table
    ten_nguoi_dich NVARCHAR(200),

    -- [CACHE 1: PRICE]
    gia_hien_tai MONEY DEFAULT 0 CHECK (gia_hien_tai >= 0),
    ma_gia_hien_tai INT NULL, -- Pointer to Price Log

    -- [CACHE 2: RATING]
    so_sao_trung_binh DECIMAL(3,2) DEFAULT 0 CHECK (so_sao_trung_binh BETWEEN 0 AND 5),
    tong_so_danh_gia INT DEFAULT 0 CHECK (tong_so_danh_gia >= 0),
    ma_rating_hien_tai INT NULL, -- Pointer to Rating Log

    -- [METADATA]
    da_xoa BIT DEFAULT 0,
    nam_xuat_ban INT CHECK (nam_xuat_ban BETWEEN 1900 AND YEAR(GETDATE()) + 1),
    ngay_du_kien_co_hang DATE NULL,
    trong_luong DECIMAL(10,2) CHECK (trong_luong >= 0),
    ngay_du_kien_phat_hanh DATE NULL,
    do_tuoi INT CHECK (do_tuoi >= 0),
    kich_thuoc_bao_bi NVARCHAR(100),
    nha_cung_cap NVARCHAR(100),
    so_trang INT CHECK (so_trang > 0),
    hinh_thuc NVARCHAR(50),
    ngon_ngu NVARCHAR(50),
    mo_ta NVARCHAR(MAX),
    ma_nxb INT NOT NULL,
    
    CONSTRAINT fk_sach_nxb FOREIGN KEY (ma_nxb) 
        REFERENCES nha_xuat_ban(ma_nxb) 
        ON UPDATE CASCADE
);
GO

-- ======================================================
-- 3. gia_ban (Price History)
-- ======================================================
CREATE TABLE gia_ban (
    ma_gia INT IDENTITY(1,1) PRIMARY KEY,
    ma_sach INT NOT NULL,
    gia MONEY NOT NULL CHECK (gia >= 0),
    ngay_ap_dung DATETIME DEFAULT GETDATE(),
    
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE
);
GO

-- ======================================================
-- 4. tong_hop_danh_gia (Rating History)
-- ======================================================
CREATE TABLE tong_hop_danh_gia (
    ma_rating INT IDENTITY(1,1) PRIMARY KEY,
    ma_sach INT NOT NULL,
    diem_trung_binh DECIMAL(3,2) NOT NULL DEFAULT 0,
    tong_luot_danh_gia INT NOT NULL DEFAULT 0,
    thoi_diem_cap_nhat DATETIME DEFAULT GETDATE(),

    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE
);
GO

-- ======================================================
-- 5. LINKING THE POINTERS (Circular Fixes)
-- ======================================================
ALTER TABLE sach ADD CONSTRAINT fk_sach_gia_current 
FOREIGN KEY (ma_gia_hien_tai) REFERENCES gia_ban(ma_gia);

ALTER TABLE sach ADD CONSTRAINT fk_sach_rating_current 
FOREIGN KEY (ma_rating_hien_tai) REFERENCES tong_hop_danh_gia(ma_rating);
GO

-- ======================================================
-- 6. the_loai (Category)
-- ======================================================
CREATE TABLE the_loai (
    ma_tl INT IDENTITY(1,1) PRIMARY KEY,
    ten_tl NVARCHAR(200) NOT NULL
);
GO

-- ======================================================
-- 7. sach_the_loai (Book-Category Map)
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
-- 8. tac_gia (Author)
-- ======================================================
CREATE TABLE tac_gia (
    ma_tg INT IDENTITY(1,1) PRIMARY KEY,
    ten_tg NVARCHAR(200) NOT NULL,
    quoc_tich NVARCHAR(100),
    mo_ta NVARCHAR(MAX)
);
GO

-- ======================================================
-- 9. sach_tac_gia (Book-Author Map)
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
-- 10. khach_hang (Customer - Base)
-- ======================================================
CREATE TABLE khach_hang (
    ma_khach_hang INT IDENTITY(1,1) PRIMARY KEY,
    ho_ten_dem NVARCHAR(200),
    ho NVARCHAR(100),
    ngay_sinh DATE,
    email NVARCHAR(200) UNIQUE NOT NULL,
    sdt NVARCHAR(20)
);
GO

-- ======================================================
-- 11. thanh_vien (Member)
-- ======================================================
CREATE TABLE thanh_vien (
    ma_khach_hang INT PRIMARY KEY,
    cap_do_thanh_vien NVARCHAR(50) DEFAULT 'Bronze',
    ten_dang_nhap NVARCHAR(100) UNIQUE NOT NULL,
    ngay_dang_ky DATETIME DEFAULT GETDATE(),
    gioi_tinh NVARCHAR(10),
    mat_khau_ma_hoa NVARCHAR(200) NOT NULL,
    tuoi INT,
    tong_chi_tieu DECIMAL(18,2) DEFAULT 0,
    diem_tich_luy INT DEFAULT 0,
    
    FOREIGN KEY (ma_khach_hang) REFERENCES khach_hang(ma_khach_hang) ON DELETE CASCADE
);
GO

-- ======================================================
-- 12. khach (Guest)
-- ======================================================
CREATE TABLE khach (
    ma_khach_hang INT PRIMARY KEY,
    ma_session NVARCHAR(200) NOT NULL,
    FOREIGN KEY (ma_khach_hang) REFERENCES khach_hang(ma_khach_hang) ON DELETE CASCADE
);
GO

-- ======================================================
-- 13. dia_chi_cu_the (Address)
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
-- 14. voucher (Voucher Definitions)
-- ======================================================
CREATE TABLE voucher (
    ma_voucher INT IDENTITY(1,1) PRIMARY KEY,
    ma_code NVARCHAR(50) UNIQUE NOT NULL,
    ten_voucher NVARCHAR(200) NOT NULL,
    
    -- [NULLABLE PUBLISHER]
    -- NULL = System/Celebration voucher
    -- NOT NULL = Publisher specific voucher
    ma_nxb INT NULL,
    
    bat_dau DATE NOT NULL,
    ket_thuc DATE NOT NULL,
    loai_giam NVARCHAR(20) CHECK (loai_giam IN (N'Phần trăm', N'Số tiền')),
    gia_tri_giam DECIMAL(10,2) NOT NULL CHECK (gia_tri_giam > 0),
    
    FOREIGN KEY (ma_nxb) REFERENCES nha_xuat_ban(ma_nxb) ON DELETE SET NULL
);
GO

-- ======================================================
-- 15. voucher_thanh_vien (User Wallet)
-- ======================================================
CREATE TABLE voucher_thanh_vien (
    ma_voucher INT NOT NULL,
    ma_khach_hang INT NOT NULL,
    
    -- [QUANTITY] 
    -- Allows user to have 5 "Free Shipping" vouchers
    so_luong INT NOT NULL DEFAULT 1 CHECK (so_luong >= 0),
    
    PRIMARY KEY (ma_voucher, ma_khach_hang),
    FOREIGN KEY (ma_voucher) REFERENCES voucher(ma_voucher) ON DELETE CASCADE,
    FOREIGN KEY (ma_khach_hang) REFERENCES thanh_vien(ma_khach_hang) ON DELETE CASCADE
);
GO

-- ======================================================
-- 16. don_hang (Order)
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
-- 17. chi_tiet_don_hang (Order Detail)
-- ======================================================
CREATE TABLE chi_tiet_don_hang (
    ma_don INT NOT NULL,
    ma_sach INT NOT NULL,
    
    -- [SNAPSHOTS]
    ma_gia INT NOT NULL, 
    gia_ban MONEY NOT NULL CHECK (gia_ban >= 0),
    so_luong INT NOT NULL CHECK (so_luong > 0),
    the_loai NVARCHAR(100),
    
    PRIMARY KEY (ma_don, ma_sach),
    FOREIGN KEY (ma_don) REFERENCES don_hang(ma_don) ON DELETE CASCADE,
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE NO ACTION,
    FOREIGN KEY (ma_gia) REFERENCES gia_ban(ma_gia)
);
GO

-- ======================================================
-- 18. thanh_toan (Payment)
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
-- 19. kho (Inventory)
-- ======================================================
CREATE TABLE kho (
    ma_kho INT IDENTITY(1,1) PRIMARY KEY,
    ten_kho NVARCHAR(200) NOT NULL,
    dia_chi NVARCHAR(300)
);
GO

-- ======================================================
-- 20. so_luong_sach_kho (Inventory Level)
-- ======================================================
CREATE TABLE so_luong_sach_kho (
    ma_kho INT NOT NULL,
    ma_sach INT NOT NULL,
    so_luong_ton INT NOT NULL CHECK (so_luong_ton >= 0),
    
    PRIMARY KEY (ma_kho, ma_sach),
    FOREIGN KEY (ma_kho) REFERENCES kho(ma_kho) ON DELETE CASCADE,
    FOREIGN KEY (ma_sach) REFERENCES sach(ma_sach) ON DELETE CASCADE
);
GO

-- ======================================================
-- 21. danh_gia (Review)
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
-- 22. INDEXES
-- ======================================================
CREATE INDEX idx_sach_nxb ON sach(ma_nxb);
CREATE INDEX idx_gia_ban_sach ON gia_ban(ma_sach);
CREATE INDEX idx_don_hang_khach ON don_hang(ma_khach_hang);
CREATE INDEX idx_rating_snapshot ON tong_hop_danh_gia(ma_sach);

-- Unique index for Soft Deletes
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_active_book_name
ON sach(ten_sach)
WHERE da_xoa = 0; 

PRINT 'Database (Clean V4) created successfully!';
GO
