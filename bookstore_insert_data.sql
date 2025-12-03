USE book_store;
GO

PRINT '--- 1. LOOKUP DATA (NXB, Category, Author) ---';
INSERT INTO nha_xuat_ban (ten_nxb, email, dia_chi, sdt) VALUES
(N'Nhà xuất bản Trẻ', 'lienhe@nxbtre.vn', N'161B Lý Chính Thắng, Quận 3, TP.HCM', '028-123456'),
(N'Nhà xuất bản Kim Đồng', 'contact@kimdong.vn', N'55 Quang Trung, Hai Bà Trưng, HN', '024-654321'),
(N'NXB Văn Học', 'vanhoc@nxb.vn', N'18 Nguyễn Trường Tộ, Ba Đình, HN', '024-998877'),
(N'NXB Khoa Học', 'science@nxb.vn', N'Nguyễn Thị Minh Khai, Quận 1, TP.HCM', '028-443322'),
(N'NXB Thế Giới', 'worldbook@nxb.vn', N'Đống Đa, HN', '024-111222');

INSERT INTO the_loai (ten_tl) VALUES 
(N'Văn học'), (N'Thiếu nhi'), (N'Khoa học'), (N'Kinh tế'), (N'Tư duy - Phát triển'), (N'Tiểu thuyết');

INSERT INTO tac_gia (ten_tg, quoc_tich, mo_ta) VALUES
(N'Nguyễn Nhật Ánh', N'Việt Nam', N'Tác giả văn học thiếu nhi'),
(N'Tô Hoài', N'Việt Nam', N'Nhà văn nổi tiếng với Dế Mèn'),
(N'Stephen Hawking', N'Anh', N'Nhà vật lý lý thuyết, vũ trụ học'),
(N'Nguyễn Duy', N'Việt Nam', N'Nhà thơ, nhà văn hiện đại'),
(N'Yuval Noah Harari', N'Israel', N'Tác giả Sapiens, Homo Deus');

PRINT '--- 2. BOOKS (Sach) ---';
INSERT INTO sach (ten_sach, nam_xuat_ban, so_trang, ngon_ngu, ma_nxb, ngay_du_kien_phat_hanh, do_tuoi, ten_nguoi_dich, mo_ta, hinh_thuc) VALUES
(N'Tôi thấy hoa vàng trên cỏ xanh', 2010, 380, N'Tiếng Việt', 1, NULL, 10, NULL, N'Câu chuyện về tuổi thơ nghèo khó nhưng đầy tình thương...', N'Bìa mềm'),
(N'Dế Mèn phiêu lưu ký', 1941, 198, N'Tiếng Việt', 2, NULL, 6, NULL, N'Cuộc phiêu lưu của chú Dế Mèn qua thế giới loài vật...', N'Bìa cứng'),
(N'Lược sử thời gian', 2020, 320, N'Tiếng Việt', 4, NULL, 16, N'Vũ Thanh Bình', N'Về vũ trụ, Big Bang và lỗ đen...', N'Bìa mềm'),
(N'Sapiens: Lược sử loài người', 2021, 500, N'Tiếng Việt', 5, NULL, 18, N'Nguyễn Thủy Chung', N'Lịch sử tiến hóa của loài người từ thời tiền sử...', N'Bìa cứng'),
(N'Cho tôi xin một vé đi tuổi thơ', 2008, 280, N'Tiếng Việt', 1, NULL, 12, NULL, N'Vé đi tuổi thơ để gột rửa tâm hồn...', N'Bìa mềm');

-- Mapping Books to Authors & Categories
INSERT INTO sach_tac_gia (ma_sach, ma_tg) VALUES (1, 1), (5, 1), (2, 2), (3, 3), (4, 5);
INSERT INTO sach_the_loai (ma_sach, ma_tl) VALUES (1, 1), (1, 2), (2, 2), (2, 6), (3, 3), (4, 3), (4, 5), (5, 1);

PRINT '--- 3. HISTORY (Prices & Ratings) ---';
INSERT INTO gia_ban (ma_sach, gia, ngay_ap_dung) VALUES
(1, 95000, '2024-01-01'), (2, 65000, '2024-01-01'), (3, 120000, '2024-01-05'), (4, 180000, '2024-10-01'), (5, 90000, '2024-01-01');

-- Manually update cache to match (Triggers usually do this, but we force it for initial data)
UPDATE sach SET gia_hien_tai=95000, ma_gia_hien_tai=1 WHERE ma_sach=1;
UPDATE sach SET gia_hien_tai=65000, ma_gia_hien_tai=2 WHERE ma_sach=2;
UPDATE sach SET gia_hien_tai=120000, ma_gia_hien_tai=3 WHERE ma_sach=3;
UPDATE sach SET gia_hien_tai=180000, ma_gia_hien_tai=4 WHERE ma_sach=4;
UPDATE sach SET gia_hien_tai=90000, ma_gia_hien_tai=5 WHERE ma_sach=5;

PRINT '--- 4. USERS & ADDRESSES (Critical for V5) ---';
INSERT INTO khach_hang (ho_ten_dem, ho, ngay_sinh, email, sdt) VALUES
(N'Văn Nam', N'Lê', '2002-07-12', 'nam.le@mail.com', '098111222'),
(N'Minh Anh', N'Nguyễn', '2000-02-10', 'anh.nguyen@mail.com', '098333444'),
(N'Hoài Thu', N'Phạm', '1995-11-25', 'thu.pham@mail.com', '090987321'),
(N'Hải', N'Lâm', '1990-01-01', 'lam.hai@mail.com', '091555444'),
(N'Hưng', N'Trần', '1988-10-10', 'hung.tran@mail.com', '093353535');

-- Member Credentials
INSERT INTO thanh_vien (ma_khach_hang, cap_do_thanh_vien, ten_dang_nhap, ngay_dang_ky, gioi_tinh, mat_khau_ma_hoa, tong_chi_tieu, diem_tich_luy) VALUES
(1, N'Standard', 'le_nam', '2023-01-10', N'Nam', '123456', 225000, 2),
(2, N'VIP', 'minh_anh', '2023-02-15', N'Nữ', '123456', 65000, 0),
(3, N'Gold', 'hoai_thu', '2022-12-20', N'Nữ', '123456', 360000, 3),
(4, N'Basic', 'lam_hai', '2023-03-08', N'Nam', '123456', 90000, 0),
(5, N'Standard', 'hung_tran', '2024-01-01', N'Nam', '123456', 0, 0);

-- Addresses (Required for Checkout logic)
INSERT INTO dia_chi_cu_the (ma_khach_hang, thanh_pho, quan_huyen, phuong_xa, dia_chi_nha) VALUES
(1, N'HCM', N'Quận 1', N'P. Bến Nghé', N'12 Lê Duẩn'), 
(2, N'HCM', N'Quận 3', N'P. Võ Thị Sáu', N'66 Nguyễn Thái Học'),
(3, N'Hà Nội', N'Đống Đa', N'P. Láng Thượng', N'102 Chùa Láng'),
(4, N'Đà Nẵng', N'Hải Châu', N'P. Thạch Thang', N'15 Lê Duẩn');

PRINT '--- 5. INVENTORY (Setup for Cursor Warnings) ---';
INSERT INTO kho (ten_kho, dia_chi) VALUES (N'Kho HCM', N'Quận 7, TP.HCM'), (N'Kho Hà Nội', N'Cầu Giấy, HN');

INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton) VALUES
(1, 1, 5),   -- [LOW STOCK] Book 1 (5 copies left) -> Good for testing Warning
(1, 2, 50),
(1, 3, 20),
(2, 1, 5),   -- Total Book 1 = 10 copies
(2, 4, 100),
(2, 5, 0);   -- [OUT OF STOCK] Book 5 in Hanoi

PRINT '--- 6. VOUCHERS (Setup for "Best Voucher" Cursor) ---';
INSERT INTO voucher (ma_code, ten_voucher, bat_dau, ket_thuc, loai_giam, gia_tri_giam, giam_toi_da) VALUES
('WELCOME10', N'Giảm 10% Toàn Sàn', '2024-01-01', '2025-12-31', N'Phần trăm', 10, 50000), 
('KIMDONG20K', N'Giảm 20k cho Kim Đồng', '2024-01-01', '2025-06-01', N'Số tiền', 20000, NULL),
('BIGSALE50', N'Giảm 50% (Max 100k)', '2024-01-01', '2025-12-31', N'Phần trăm', 50, 100000);

-- Specific Scope for Voucher 2
UPDATE voucher SET ma_nxb = 2, ap_dung_tat_ca_sach = 1 WHERE ma_code = 'KIMDONG20K';

-- Give User 1 multiple vouchers to test the "Best Logic"
INSERT INTO voucher_thanh_vien (ma_voucher, ma_khach_hang, so_luong) VALUES 
(1, 1, 2), -- Has 10% Off
(3, 1, 1); -- Has 50% Off (Best one)

PRINT '--- 7. ORDERS (With Address Snapshots) ---';

-- [FORCE] Disable triggers to insert historical/completed data
ALTER TABLE chi_tiet_don_hang DISABLE TRIGGER ALL;
ALTER TABLE don_hang DISABLE TRIGGER ALL;
ALTER TABLE danh_gia DISABLE TRIGGER ALL;

-- ORDER 1: Delivered (User 1)
INSERT INTO don_hang (ma_khach_hang, thoi_diem_dat_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, da_huy, dia_chi_giao_hang)
VALUES (1, '2024-01-10', 95000, 1, 1, 0, N'12 Lê Duẩn, P. Bến Nghé, Quận 1, HCM');

INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (1, 1, 1, 95000, 1);
INSERT INTO thanh_toan (ma_don, hinh_thuc, trinh_trang, thanh_tien) VALUES (1, 'Visa', 'Success', 95000);

-- ORDER 2: Delivered (User 1)
INSERT INTO don_hang (ma_khach_hang, thoi_diem_dat_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, da_huy, dia_chi_giao_hang)
VALUES (1, '2024-02-02', 120000, 1, 1, 0, N'12 Lê Duẩn, P. Bến Nghé, Quận 1, HCM');

INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (2, 3, 3, 120000, 1);
INSERT INTO thanh_toan (ma_don, hinh_thuc, trinh_trang, thanh_tien) VALUES (2, 'Shipper', 'Success', 120000);

-- ORDER 3: Cancelled (User 2)
INSERT INTO don_hang (ma_khach_hang, thoi_diem_dat_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, da_huy, dia_chi_giao_hang)
VALUES (2, '2024-01-03', 65000, 1, 0, 1, N'66 Nguyễn Thái Học, P. Võ Thị Sáu, Quận 3, HCM');

INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (3, 2, 2, 65000, 1);
INSERT INTO thanh_toan (ma_don, hinh_thuc, trinh_trang, thanh_tien) VALUES (3, 'Visa', 'Success', 65000);

-- ORDER 4: ACTIVE BASKET (User 3) - No Address Snapshot yet
INSERT INTO don_hang (ma_khach_hang, thoi_diem_dat_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, da_huy, dia_chi_giao_hang)
VALUES (3, NULL, 360000, 0, 0, 0, NULL);

INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (4, 3, 3, 120000, 3);

-- Reviews
INSERT INTO danh_gia (ma_sach, ma_khach_hang, noi_dung, so_sao, ngay_danh_gia) VALUES
(1, 1, N'Sách rất hay, bìa đẹp', 5, '2024-01-15'),
(3, 1, N'Hơi khó hiểu nhưng hay', 4, '2024-02-10');

-- Update Cache for Ratings
UPDATE sach SET so_sao_trung_binh=5, tong_so_danh_gia=1 WHERE ma_sach=1;
UPDATE sach SET so_sao_trung_binh=4, tong_so_danh_gia=1 WHERE ma_sach=3;

-- [RESTORE] Re-enable triggers
ALTER TABLE chi_tiet_don_hang ENABLE TRIGGER ALL;
ALTER TABLE don_hang ENABLE TRIGGER ALL;
ALTER TABLE danh_gia ENABLE TRIGGER ALL;

PRINT '--- DATA INSERTION COMPLETE (V5) ---';
GO
