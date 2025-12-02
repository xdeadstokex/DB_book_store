USE book_store;
GO

PRINT '--- 1. INSERTING LOOKUP DATA (Publishers, Authors, Categories) ---';

-- 1. nha_xuat_ban
INSERT INTO nha_xuat_ban (ten_nxb, email, dia_chi, sdt) VALUES
(N'Nhà xuất bản Trẻ', 'lienhe@nxbtre.vn', N'Quận 3, TP.HCM', '028-123456'),
(N'Nhà xuất bản Kim Đồng', 'contact@kimdong.vn', N'Hai Bà Trưng, HN', '024-654321'),
(N'NXB Văn Học', 'vanhoc@nxb.vn', N'Ba Đình, HN', '024-998877'),
(N'NXB Khoa Học', 'science@nxb.vn', N'Quận 1, TP.HCM', '028-443322'),
(N'NXB Thế Giới', 'worldbook@nxb.vn', N'Đống Đa, HN', '024-111222');

-- 2. the_loai
INSERT INTO the_loai (ten_tl) VALUES
(N'Văn học'),
(N'Thiếu nhi'),
(N'Khoa học'),
(N'Kinh tế'),
(N'Tư duy - Phát triển');

-- 3. tac_gia
INSERT INTO tac_gia (ten_tg, quoc_tich, mo_ta) VALUES
(N'Nguyễn Nhật Ánh', N'Việt Nam', N'Tác giả văn học thiếu nhi'),
(N'Tô Hoài', N'Việt Nam', N'Nhà văn nổi tiếng'),
(N'Stephen Hawking', N'Anh', N'Nhà vật lý lỗi lạc'),
(N'Nguyễn Duy', N'Việt Nam', N'Nhà văn hiện đại'),
(N'Yuval Noah Harari', N'Israel', N'Tác giả Sapiens');

PRINT '--- 2. INSERTING BOOKS (Initial Insert - Pointers NULL) ---';

-- 4. sach (Insert with Cache Values = 0/NULL initially)
INSERT INTO sach 
(ten_sach, nam_xuat_ban, so_trang, ngon_ngu, ma_nxb, ngay_du_kien_phat_hanh, do_tuoi, ten_nguoi_dich, mo_ta)
VALUES
(N'Tôi thấy hoa vàng trên cỏ xanh', 2010, 456, N'Tiếng Việt', 1, NULL, 10, NULL, N'Câu chuyện về tuổi thơ...'),
(N'Dế Mèn phiêu lưu ký', 1941, 256, N'Tiếng Việt', 2, NULL, 8, NULL, N'Cuộc phiêu lưu của Dế Mèn...'),
(N'Lược sử thời gian', 2020, 320, N'Tiếng Việt', 4, NULL, 16, N'Vũ Thanh Bình', N'Về vũ trụ và thời gian...'),
(N'Sapiens: Lược sử loài người', 2021, 500, N'Tiếng Việt', 5, NULL, 18, N'Nguyễn Thủy Chung', N'Lịch sử loài người...'),
(N'Cho tôi xin một vé đi tuổi thơ', 2008, 280, N'Tiếng Việt', 1, NULL, 12, NULL, N'Vé đi tuổi thơ...');

PRINT '--- 3. INSERTING HISTORY LOGS & UPDATING BOOK POINTERS ---';

-- 5. gia_ban (Insert Prices)
INSERT INTO gia_ban (ma_sach, gia, ngay_ap_dung) VALUES
(1, 95000, '2024-01-01'),
(2, 65000, '2024-01-01'),
(3, 120000, '2024-01-05'),
(4, 180000, '2024-10-01'),
(5, 90000, '2024-01-01');

-- 6. tong_hop_danh_gia (Insert Initial Rating Snapshots - mostly empty)
INSERT INTO tong_hop_danh_gia (ma_sach, diem_trung_binh, tong_luot_danh_gia) VALUES
(1, 4.7, 10),
(2, 4.9, 25),
(3, 4.5, 5),
(4, 0, 0), -- New book
(5, 4.2, 8);

-- 7. UPDATE SACH (Link Pointers & Cache Values)
-- Book 1
UPDATE sach SET gia_hien_tai=95000, ma_gia_hien_tai=1, so_sao_trung_binh=4.7, tong_so_danh_gia=10, ma_rating_hien_tai=1 WHERE ma_sach=1;
-- Book 2
UPDATE sach SET gia_hien_tai=65000, ma_gia_hien_tai=2, so_sao_trung_binh=4.9, tong_so_danh_gia=25, ma_rating_hien_tai=2 WHERE ma_sach=2;
-- Book 3
UPDATE sach SET gia_hien_tai=120000, ma_gia_hien_tai=3, so_sao_trung_binh=4.5, tong_so_danh_gia=5, ma_rating_hien_tai=3 WHERE ma_sach=3;
-- Book 4
UPDATE sach SET gia_hien_tai=180000, ma_gia_hien_tai=4, so_sao_trung_binh=0, tong_so_danh_gia=0, ma_rating_hien_tai=4 WHERE ma_sach=4;
-- Book 5
UPDATE sach SET gia_hien_tai=90000, ma_gia_hien_tai=5, so_sao_trung_binh=4.2, tong_so_danh_gia=8, ma_rating_hien_tai=5 WHERE ma_sach=5;

PRINT '--- 4. LINKING BOOKS TO AUTHORS & CATEGORIES ---';

-- 8. sach_tac_gia (Book-Author)
INSERT INTO sach_tac_gia (ma_sach, ma_tg) VALUES
(1, 1), -- Nguyen Nhat Anh
(5, 1), -- Nguyen Nhat Anh (Another book)
(2, 2), -- To Hoai
(3, 3), -- Hawking
(4, 5); -- Harari

-- 9. sach_the_loai (Book-Category)
INSERT INTO sach_the_loai (ma_sach, ma_tl) VALUES
(1, 1), (1, 2), -- Book 1 is Literature & Kids
(2, 2),
(3, 3),
(4, 3), (4, 5), -- Book 4 is Science & Thinking
(5, 1), (5, 2);

PRINT '--- 5. INSERTING USERS (Customers & Members) ---';

-- 10. khach_hang
INSERT INTO khach_hang (ho_ten_dem, ho, ngay_sinh, email, sdt) VALUES
(N'Văn Nam', N'Lê', '2002-07-12', 'nam.le@mail.com', '098111222'),
(N'Minh Anh', N'Nguyễn', '2000-02-10', 'anh.nguyen@mail.com', '098333444'),
(N'Hoài Thu', N'Phạm', '1995-11-25', 'thu.pham@mail.com', '090987321'),
(N'Hải', N'Lâm', '1990-01-01', 'lam.hai@mail.com', '091555444'),
(N'Hưng', N'Trần', '1988-10-10', 'hung.tran@mail.com', '093353535');

-- 11. thanh_vien (Password is '123456' hashed or plain for test)
INSERT INTO thanh_vien 
(ma_khach_hang, cap_do_thanh_vien, ten_dang_nhap, ngay_dang_ky, gioi_tinh, mat_khau_ma_hoa, tong_chi_tieu)
VALUES
(1, N'Standard', 'le_nam', '2023-01-10', N'Nam', '123456', 225000),
(2, N'VIP', 'minh_anh', '2023-02-15', N'Nữ', '123456', 65000),
(3, N'Gold', 'hoai_thu', '2022-12-20', N'Nữ', '123456', 360000),
(4, N'Basic', 'lam_hai', '2023-03-08', N'Nam', '123456', 90000),
(5, N'Standard', 'hung_tran', '2024-01-01', N'Nam', '123456', 0);

-- 12. dia_chi_cu_the
INSERT INTO dia_chi_cu_the (ma_khach_hang, thanh_pho, quan_huyen, phuong_xa, dia_chi_nha) VALUES
(1, N'HCM', N'Q1', N'P Bến Nghé', N'12 Lê Duẩn'),
(2, N'HCM', N'Q3', N'P Võ Thị Sáu', N'66 Nguyễn Thái Học'),
(3, N'Hà Nội', N'Hoàn Kiếm', N'Hàng Bông', N'22 Hàng Bông');

PRINT '--- 6. WAREHOUSE & INVENTORY ---';

-- 13. kho
INSERT INTO kho (ten_kho, dia_chi) VALUES
(N'Kho HCM', N'Quận 7, TP.HCM'),
(N'Kho Hà Nội', N'Cầu Giấy, HN');

-- 14. so_luong_sach_kho
INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton) VALUES
(1, 1, 50), (1, 2, 30), (1, 3, 20),
(2, 1, 50), (2, 2, 50), (2, 4, 100), -- Book 4 stock in HN
(1, 5, 70);

PRINT '--- 7. VOUCHERS ---';

-- 15. voucher
INSERT INTO voucher (ma_code, ten_voucher, ma_nxb, bat_dau, ket_thuc, loai_giam, gia_tri_giam) VALUES
('WELCOME25', N'Chào thành viên mới', NULL, '2024-01-01', '2025-12-31', N'Phần trăm', 10), -- System wide
('KIMDONG10', N'Giảm giá Kim Đồng', 2, '2024-01-01', '2025-06-01', N'Số tiền', 20000);  -- Specific Publisher

-- 16. voucher_thanh_vien (Wallet)
INSERT INTO voucher_thanh_vien (ma_voucher, ma_khach_hang, so_luong) VALUES
(1, 1, 2), -- User 1 has 2 Welcome vouchers
(1, 2, 1),
(2, 1, 1); -- User 1 also has Kim Dong voucher

PRINT '--- 8. ORDERS & REVIEWS ---';

-- 17. don_hang (Orders)
INSERT INTO don_hang (ma_khach_hang, thoi_diem_dat_hang, tong_tien_thanh_toan, trang_thai_don_hang)
VALUES
(1, '2024-01-10', 95000, N'Đã giao'),
(1, '2024-02-02', 130000, N'Đang giao'),
(2, '2024-01-03', 65000, N'Đã giao'),
(3, '2024-02-01', 360000, N'Đang xử lý');

-- 18. chi_tiet_don_hang (Order Details)
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong) VALUES
-- Order 1: Book 1
(1, 1, 1, 95000, 1), 
-- Order 2: Book 3
(2, 3, 3, 120000, 1),
-- Order 3: Book 2
(3, 2, 2, 65000, 1),
-- Order 4: Book 3 (qty 3)
(4, 3, 3, 120000, 3);

-- 19. danh_gia (Reviews)
INSERT INTO danh_gia (ma_sach, ma_khach_hang, noi_dung, so_sao) VALUES
(1, 1, N'Sách rất hay, bìa đẹp', 5),
(2, 2, N'Tuổi thơ ùa về', 5),
(3, 3, N'Dễ hiểu, cuốn hút', 4),
(1, 5, N'Khá ổn', 4);

PRINT '--- DATA INSERTION COMPLETE ---';
GO
