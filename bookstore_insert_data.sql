USE book_store;
GO

-- ======================================================
-- 1. LOOKUP DATA (NXB, Category, Author)
-- ======================================================
PRINT '--- 1. LOOKUP DATA ---';

INSERT INTO nha_xuat_ban (ten_nxb, email, dia_chi, sdt) VALUES
(N'NXB Trẻ', 'contact@nxbtre.vn', N'161B Lý Chính Thắng, Q3, TP.HCM', '028-123456'),
(N'NXB Kim Đồng', 'info@kimdong.vn', N'55 Quang Trung, Hai Bà Trưng, HN', '024-654321'),
(N'NXB Văn Học', 'vanhoc@nxb.vn', N'18 Nguyễn Trường Tộ, HN', '024-998877'),
(N'NXB Hội Nhà Văn', 'hoinhavan@nxb.vn', N'65 Nguyễn Du, HN', '024-555555'),
(N'NXB Nhã Nam', 'info@nhanam.vn', N'59 Đỗ Quang, Cầu Giấy, HN', '024-111222'),
(N'NXB Tổng Hợp', 'tonghop@nxb.vn', N'62 Nguyễn Thị Minh Khai, Q1, HCM', '028-333444');

INSERT INTO the_loai (ten_tl) VALUES 
(N'Tiểu thuyết'), (N'Truyện ngắn'), (N'Thiếu nhi'), (N'Khoa học'), 
(N'Kinh tế'), (N'Kỹ năng sống'), (N'Lịch sử'), (N'Giả tưởng');

INSERT INTO tac_gia (ten_tg, quoc_tich, mo_ta) VALUES
(N'Nguyễn Nhật Ánh', N'Việt Nam', N'Chuyên viết cho tuổi mới lớn.'),
(N'Tô Hoài', N'Việt Nam', N'Tác giả Dế Mèn phiêu lưu ký.'),
(N'J.K. Rowling', N'Anh', N'Tác giả Harry Potter.'),
(N'Haruki Murakami', N'Nhật Bản', N'Tác giả Rừng Na Uy.'),
(N'Nam Cao', N'Việt Nam', N'Nhà văn hiện thực phê phán.'),
(N'Rosie Nguyễn', N'Việt Nam', N'Tác giả Tuổi trẻ đáng giá bao nhiêu.'),
(N'Stephen Hawking', N'Anh', N'Nhà vật lý thiên tài.');

-- ======================================================
-- 2. BOOKS (Sach) - 12 Items
-- ======================================================
PRINT '--- 2. BOOKS ---';

INSERT INTO sach (ten_sach, nam_xuat_ban, so_trang, ngon_ngu, ma_nxb, do_tuoi, hinh_thuc, gia_hien_tai) VALUES
(N'Tôi thấy hoa vàng trên cỏ xanh', 2010, 380, N'Tiếng Việt', 1, 10, N'Bìa mềm', 115000), -- 1
(N'Dế Mèn phiêu lưu ký', 1941, 198, N'Tiếng Việt', 2, 6, N'Bìa cứng', 80000),    -- 2
(N'Harry Potter và Hòn đá Phù thủy', 1997, 400, N'Tiếng Việt', 1, 10, N'Bìa mềm', 150000), -- 3
(N'Rừng Na Uy', 1987, 500, N'Tiếng Việt', 5, 18, N'Bìa mềm', 130000), -- 4
(N'Chí Phèo', 1941, 120, N'Tiếng Việt', 3, 16, N'Bìa mềm', 45000), -- 5
(N'Tuổi trẻ đáng giá bao nhiêu', 2016, 250, N'Tiếng Việt', 5, 15, N'Bìa mềm', 90000), -- 6
(N'Lược sử thời gian', 1988, 300, N'Tiếng Việt', 4, 16, N'Bìa cứng', 180000), -- 7
(N'Mắt Biếc', 1990, 320, N'Tiếng Việt', 1, 13, N'Bìa mềm', 110000), -- 8
(N'Kính Vạn Hoa', 1995, 200, N'Tiếng Việt', 2, 10, N'Bìa mềm', 65000), -- 9
(N'Đất Rừng Phương Nam', 1957, 350, N'Tiếng Việt', 2, 12, N'Bìa cứng', 120000), -- 10
(N'Sapiens: Lược sử loài người', 2011, 600, N'Tiếng Việt', 6, 18, N'Bìa cứng', 250000), -- 11
(N'Nhà Giả Kim', 1988, 220, N'Tiếng Việt', 5, 12, N'Bìa mềm', 75000); -- 12

-- Link Books to Authors
INSERT INTO sach_tac_gia (ma_sach, ma_tg) VALUES 
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 1), (9, 1), (10, 2), (11, 7), (12, 6);

-- Link Books to Categories
INSERT INTO sach_the_loai (ma_sach, ma_tl) VALUES
(1, 1), (1, 3), (2, 3), (3, 8), (4, 1), (5, 1), (6, 6), (7, 4), (8, 1), (9, 3), (10, 1), (11, 7), (12, 1);

-- Initial Price History
INSERT INTO gia_ban (ma_sach, gia)
SELECT ma_sach, gia_hien_tai FROM sach;

-- Update Cache Pointers
UPDATE s
SET ma_gia_hien_tai = g.ma_gia
FROM sach s
JOIN gia_ban g ON s.ma_sach = g.ma_sach;

-- ======================================================
-- 3. USERS & ADDRESSES
-- ======================================================
PRINT '--- 3. USERS ---';

INSERT INTO khach_hang (ho_ten_dem, ho, email, sdt) VALUES
(N'Văn A', N'Nguyễn', 'a@mail.com', '0901111111'),
(N'Thị B', N'Trần', 'b@mail.com', '0902222222'),
(N'Văn C', N'Lê', 'c@mail.com', '0903333333'),
(N'Thị D', N'Phạm', 'd@mail.com', '0904444444'),
(N'Guest 1', N'Vãng Lai', 'guest1@temp.com', NULL),
(N'Minh E', N'Hoàng', 'e@mail.com', '0905555555'),
(N'Tuấn F', N'Đỗ', 'f@mail.com', '0906666666'),
(N'Lan G', N'Vũ', 'g@mail.com', '0907777777');

-- Members (Users 1-4, 6-8)
INSERT INTO thanh_vien (ma_khach_hang, ten_dang_nhap, mat_khau_ma_hoa, cap_do_thanh_vien) VALUES
(1, 'nguyena', '123456', 'Gold'),
(2, 'tranb', '123456', 'Silver'),
(3, 'lec', '123456', 'Bronze'),
(4, 'phamd', '123456', 'VIP'),
(6, 'hoange', '123456', 'Bronze'),
(7, 'dof', '123456', 'Silver'),
(8, 'vug', '123456', 'Gold');

-- Guest Session
INSERT INTO khach (ma_khach_hang, ma_session) VALUES (5, 'SESSION-XYZ-123');

-- Addresses
INSERT INTO dia_chi_cu_the (ma_khach_hang, dia_chi_nha, phuong_xa, quan_huyen, thanh_pho) VALUES
(1, N'12 Lê Lợi', N'Bến Nghé', N'Quận 1', N'HCM'),
(2, N'34 Nguyễn Huệ', N'Bến Nghé', N'Quận 1', N'HCM'),
(3, N'56 Cầu Giấy', N'Quan Hoa', N'Cầu Giấy', N'Hà Nội'),
(4, N'78 Láng Hạ', N'Láng Hạ', N'Đống Đa', N'Hà Nội'),
(6, N'90 Trần Phú', N'Hải Châu 1', N'Hải Châu', N'Đà Nẵng'),
(7, N'12 Bạch Đằng', N'Hải Châu 1', N'Hải Châu', N'Đà Nẵng');

-- ======================================================
-- 4. INVENTORY (Warehouses)
-- ======================================================
PRINT '--- 4. INVENTORY ---';

INSERT INTO kho (ten_kho, dia_chi) VALUES 
(N'Kho Tổng HCM', N'Quận 7, HCM'),
(N'Kho Tổng HN', N'Gia Lâm, HN');

INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton) VALUES
(1, 1, 50), (2, 1, 20),  -- Book 1: Plenty
(1, 2, 10), (2, 2, 5),   -- Book 2: Low
(1, 3, 100), (2, 3, 100),-- Book 3: High
(1, 4, 0), (2, 4, 2),    -- Book 4: Critical (Only 2 left in HN)
(1, 5, 20), (2, 5, 20),
(1, 6, 30), (2, 6, 0),
(1, 7, 5), (2, 7, 5),    -- Book 7: Low
(1, 8, 200), (2, 8, 50),
(1, 9, 10), (2, 9, 10),
(1, 10, 15), (2, 10, 15),
(1, 11, 50), (2, 11, 50),
(1, 12, 100), (2, 12, 0);

-- ======================================================
-- 5. VOUCHERS
-- ======================================================
PRINT '--- 5. VOUCHERS ---';

INSERT INTO voucher (ma_code, ten_voucher, bat_dau, ket_thuc, loai_giam, gia_tri_giam, giam_toi_da) VALUES
('WELCOME2024', N'Chào bạn mới', '2024-01-01', '2025-12-31', N'Phần trăm', 10, 50000),
('FREESHIP', N'Miễn phí vận chuyển', '2024-01-01', '2025-12-31', N'Số tiền', 30000, NULL),
('BOOKLOVER', N'Giảm sâu sách văn học', '2024-01-01', '2025-06-01', N'Phần trăm', 20, 100000),
('KIMDONG20', N'Giảm 20k sách Kim Đồng', '2024-01-01', '2025-12-31', N'Số tiền', 20000, NULL),
('VIP50', N'Giảm 50% cho VIP', '2024-01-01', '2025-12-31', N'Phần trăm', 50, 500000);

-- Set scope for KimDong voucher
UPDATE voucher SET ma_nxb = 2 WHERE ma_code = 'KIMDONG20';

-- Distribute Vouchers
INSERT INTO voucher_thanh_vien (ma_voucher, ma_khach_hang, so_luong) VALUES
(1, 1, 1), (1, 2, 1), (1, 3, 1), (1, 4, 1), -- Everyone gets Welcome
(2, 1, 5), -- User 1 has many Freeship
(5, 4, 2); -- Only VIP User 4 gets VIP voucher

-- ======================================================
-- 6. ORDERS (Transactions)
-- ======================================================
PRINT '--- 6. ORDERS ---';

-- Disable Triggers to inject history
ALTER TABLE don_hang DISABLE TRIGGER ALL;
ALTER TABLE chi_tiet_don_hang DISABLE TRIGGER ALL;
ALTER TABLE danh_gia DISABLE TRIGGER ALL;

-- 1. Completed Order (User 1)
INSERT INTO don_hang (ma_khach_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, dia_chi_giao_hang, thoi_diem_dat_hang)
VALUES (1, 195000, 1, 1, N'12 Lê Lợi, Q1', '2024-01-10');
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (1, 1, 1, 115000, 1), (1, 2, 2, 80000, 1);
INSERT INTO thanh_toan (ma_don, hinh_thuc, thanh_tien, trinh_trang) VALUES (1, 'Visa', 195000, 'Success');

-- 2. Completed Order (User 2)
INSERT INTO don_hang (ma_khach_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, dia_chi_giao_hang, thoi_diem_dat_hang)
VALUES (2, 300000, 1, 1, N'34 Nguyễn Huệ, Q1', '2024-01-12');
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (2, 3, 3, 150000, 2);
INSERT INTO thanh_toan (ma_don, hinh_thuc, thanh_tien, trinh_trang) VALUES (2, 'Shipper', 300000, 'Success');

-- 3. Cancelled Order (User 1)
INSERT INTO don_hang (ma_khach_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, da_huy, dia_chi_giao_hang, thoi_diem_dat_hang)
VALUES (1, 45000, 1, 0, 1, N'12 Lê Lợi, Q1', '2024-01-15');
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (3, 5, 5, 45000, 1);

-- 4. Processing Order (User 3)
INSERT INTO don_hang (ma_khach_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang, dia_chi_giao_hang, thoi_diem_dat_hang)
VALUES (3, 260000, 1, 0, N'56 Cầu Giấy, HN', GETDATE());
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (4, 4, 4, 130000, 2);
INSERT INTO thanh_toan (ma_don, hinh_thuc, thanh_tien, trinh_trang) VALUES (4, 'Visa', 260000, 'Success');

-- 5. Active Cart (User 1) - Shopping
INSERT INTO don_hang (ma_khach_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang)
VALUES (1, 180000, 0, 0);
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (5, 7, 7, 180000, 1);

-- 6. Active Cart (User 4) - Shopping
INSERT INTO don_hang (ma_khach_hang, tong_tien_thanh_toan, da_dat_hang, da_giao_hang)
VALUES (4, 250000, 0, 0);
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES (6, 11, 11, 250000, 1);

-- ======================================================
-- 7. REVIEWS
-- ======================================================
PRINT '--- 7. REVIEWS ---';

INSERT INTO danh_gia (ma_sach, ma_khach_hang, so_sao, noi_dung, ngay_danh_gia) VALUES
(1, 1, 5, N'Sách rất hay, cảm động.', '2024-01-20'),
(2, 1, 4, N'Truyện kinh điển, bìa đẹp.', '2024-01-21'),
(3, 2, 5, N'Harry Potter đỉnh của chóp!', '2024-01-22'),
(1, 2, 4, N'Hơi buồn nhưng đáng đọc.', '2024-02-01'),
(3, 4, 5, N'Mua tặng con, con rất thích.', '2024-02-05');

-- Re-enable Triggers
ALTER TABLE don_hang ENABLE TRIGGER ALL;
ALTER TABLE chi_tiet_don_hang ENABLE TRIGGER ALL;
ALTER TABLE danh_gia ENABLE TRIGGER ALL;

-- Update Rating Caches
UPDATE sach 
SET so_sao_trung_binh = (SELECT AVG(CAST(so_sao AS FLOAT)) FROM danh_gia WHERE ma_sach = sach.ma_sach),
    tong_so_danh_gia = (SELECT COUNT(*) FROM danh_gia WHERE ma_sach = sach.ma_sach);

PRINT '--- DATA LOAD COMPLETE (V5 Extended) ---';
GO
