USE book_store;
GO

-- ======================================================
-- 1. nha_xuat_ban (Publishers)
-- ======================================================
INSERT INTO nha_xuat_ban (ten_nxb, email, dia_chi, sdt) VALUES
(N'Nhà xuất bản Trẻ', 'lienhe@nxbtre.vn', N'Quận 3, TP.HCM', '028-123456'),
(N'Nhà xuất bản Kim Đồng', 'contact@kimdong.vn', N'Hai Bà Trưng, HN', '024-654321'),
(N'NXB Văn Học', 'vanhoc@nxb.vn', N'Ba Đình, HN', '024-998877'),
(N'NXB Khoa Học', 'science@nxb.vn', N'Quận 1, TP.HCM', '028-443322'),
(N'NXB Thế Giới', 'worldbook@nxb.vn', N'Đống Đa, HN', '024-111222');
GO

-- ======================================================
-- 2. the_loai (Categories)
-- ======================================================
INSERT INTO the_loai (ten_tl) VALUES
(N'Văn học'),
(N'Thiếu nhi'),
(N'Khoa học'),
(N'Kinh tế'),
(N'Tư duy - Phát triển');
GO

-- ======================================================
-- 3. tac_gia (Authors)
-- ======================================================
INSERT INTO tac_gia (ten_tg, quoc_tich, mo_ta) VALUES
(N'Nguyễn Nhật Ánh', N'Việt Nam', N'Tác giả văn học thiếu nhi'),
(N'Tô Hoài', N'Việt Nam', N'Nhà văn nổi tiếng'),
(N'Hawking', N'Anh', N'Nhà vật lý lỗi lạc'),
(N'Nguyễn Duy', N'Việt Nam', N'Nhà văn hiện đại'),
(N'ABC Writer', N'Mỹ', N'Tác giả quốc tế');
GO

-- ======================================================
-- 4. nguoi_dich (Translators)
-- ======================================================
INSERT INTO nguoi_dich (ten_ng_dich, ngon_ngu_dich) VALUES
(N'Trần Thuý Lan', N'Tiếng Anh'),
(N'Võ Thanh Hải', N'Tiếng Pháp'),
(N'Nguyễn Đăng Minh', N'Tiếng Nhật'),
(N'Lê Thị Thương', N'Tiếng Trung'),
(N'Lâm Kiều Hương', N'Tiếng Hàn');
GO

-- ======================================================
-- 5. sach (Books)
-- ======================================================
INSERT INTO sach 
(ten_sach, nam_xuat_ban, so_trang, ngon_ngu, ma_nxb, ngay_du_kien_phat_hanh, do_tuoi, so_sao_trung_binh)
VALUES
(N'Tôi thấy hoa vàng trên cỏ xanh', 2010, 456, N'Tiếng Việt', 1, NULL, 10, 4.7),
(N'Dế Mèn phiêu lưu ký', 1941, 256, N'Tiếng Việt', 2, NULL, 8, 4.9),
(N'Lược sử thời gian', 2020, 320, N'Tiếng Việt', 4, NULL, 16, 4.5),
(N'Loài người trong tương lai', 2025, 300, N'Tiếng Việt', 5, '2025-12-01', 16, NULL),
(N'Hành trình về phương Đông', 2005, 280, N'Tiếng Việt', 3, NULL, 15, 4.2);
GO

-- ======================================================
-- 6. gia_ban (Book Prices)
-- ======================================================
INSERT INTO gia_ban (ma_sach, gia, tu_ngay, den_ngay) VALUES
(1, 95000, '2024-01-01', NULL),
(2, 65000, '2024-01-01', NULL),
(3, 120000, '2024-01-05', NULL),
(4, 180000, '2024-10-01', NULL),
(5, 90000, '2024-01-01', NULL);
GO

-- ======================================================
-- 7. sach_the_loai (Book-Category)
-- ======================================================
INSERT INTO sach_the_loai (ma_sach, ma_tl) VALUES
(1, 1), (2, 2), (3, 3), (4, 3), (5, 5);
GO

-- ======================================================
-- 8. sach_tac_gia (Book-Author)
-- ======================================================
INSERT INTO sach_tac_gia (ma_sach, ma_tg) VALUES
(1, 1), (2, 2), (3, 3), (4, 5), (5, 4);
GO

-- ======================================================
-- 9. sach_nguoi_dich (Book-Translator)
-- ======================================================
INSERT INTO sach_nguoi_dich (ma_sach, ma_ng_dich) VALUES
(3, 1), (4, 2);
GO

-- ======================================================
-- 10. khach_hang (Customers)
-- ======================================================
INSERT INTO khach_hang (ho_ten_dem, ho, ngay_sinh, email, so_dien_thoai) VALUES
(N'Văn Nam', N'Lê', '2002-07-12', 'nam.le@mail.com', '098111222'),
(N'Minh Anh', N'Nguyễn', '2000-02-10', 'anh.nguyen@mail.com', '098333444'),
(N'Hoài Thu', N'Phạm', '1995-11-25', 'thu.pham@mail.com', '090987321'),
(N'Hải', N'Lâm', '1990-01-01', 'lam.hai@mail.com', '091555444'),
(N'Hưng', N'Trần', '1988-10-10', 'hung.tran@mail.com', '093353535');
GO

-- ======================================================
-- 11. thanh_vien (Members)
-- ======================================================
INSERT INTO thanh_vien 
(ma_khach_hang, cap_do_thanh_vien, ten_dang_nhap, ngay_dang_ky, gioi_tinh, tuoi)
VALUES
(1, N'Standard', 'le_nam', '2023-01-10', N'Nam', 22),
(2, N'VIP', 'minh_anh', '2023-02-15', N'Nữ', 24),
(3, N'Gold', 'hoai_thu', '2022-12-20', N'Nữ', 29),
(4, N'Basic', 'lam_hai', '2023-03-08', N'Nam', 34),
(5, N'Standard', 'hung_tran', '2024-01-01', N'Nam', 36);
GO

-- ======================================================
-- 12. dia_chi_cu_the (Addresses)
-- ======================================================
INSERT INTO dia_chi_cu_the (ma_khach_hang, thanh_pho, quan_huyen, phuong_xa, dia_chi_nha) VALUES
(1, N'HCM', N'Q1', N'P Bến Nghé', N'12 Lê Duẩn'),
(2, N'HCM', N'Q3', N'P Võ Thị Sáu', N'66 Nguyễn Thái Học'),
(3, N'Hà Nội', N'Hoàn Kiếm', N'Hàng Bông', N'22 Hàng Bông'),
(4, N'Đà Nẵng', N'Hải Châu', N'Hòa Thuận', N'233 Trưng Nữ Vương'),
(5, N'Hà Nội', N'Thanh Xuân', N'Thanh Xuân Bắc', N'11 Nguyễn Tuân');
GO

-- ======================================================
-- 13. kho (Warehouses)
-- ======================================================
INSERT INTO kho (ten_kho, dia_chi) VALUES
(N'Kho HCM', N'Quận 7, TP.HCM'),
(N'Kho Hà Nội', N'Cầu Giấy, HN'),
(N'Kho Đà Nẵng', N'Liên Chiểu, ĐN');
GO

-- ======================================================
-- 14. so_luong_sach_kho (Inventory per Warehouse)
-- ======================================================
INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton) VALUES
(1, 1, 50), (1, 2, 30), (1, 3, 20),
(2, 1, 50), (2, 2, 50), (2, 4, 0),
(3, 5, 70);
GO

-- ======================================================
-- 15. don_hang (Orders)
-- ======================================================
INSERT INTO don_hang (ma_khach_hang, thoi_diem_dat_hang, tong_tien_thanh_toan, trang_thai_don_hang)
VALUES
(1, '2024-01-10', 95000, N'Đã giao'),
(1, '2024-02-02', 130000, N'Đang giao'),
(2, '2024-01-03', 65000, N'Đã giao'),
(3, '2024-02-01', 360000, N'Đang xử lý'),
(4, '2024-03-10', 90000, N'Chờ xác nhận');
GO

-- ======================================================
-- 16. chi_tiet_don_hang (Order Details)
-- ======================================================
INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, gia_ban, so_luong) VALUES
(1, 1, 95000, 1),
(2, 3, 120000, 1),
(3, 2, 65000, 1),
(4, 3, 120000, 3),
(5, 5, 90000, 1);
GO

-- ======================================================
-- 17. danh_gia (Reviews)
-- ======================================================
INSERT INTO danh_gia (ma_sach, ma_khach_hang, noi_dung, so_sao) VALUES
(1, 1, N'Sách rất hay', 5),
(2, 2, N'Tuổi thơ ùa về', 5),
(3, 3, N'Dễ hiểu, cuốn hút', 4),
(5, 4, N'Nội dung sâu sắc', 4),
(1, 5, N'Khá ổn', 4);
GO

PRINT N'Dữ liệu đã nhập thành công!';
GO