package main

//###################
//## DATA STRUCTS ###
//###################
// --- BOOKS & CORE ---
type Publisher struct {
	MaNXB   int    `json:"ma_nxb"`
	TenNXB  string `json:"ten_nxb"`
	Email   string `json:"email"`
	DiaChi  string `json:"dia_chi"`
	SDT     string `json:"sdt"`
}

type PriceRecord struct {
	MaGia      int     `json:"ma_gia"`
	MaSach     int     `json:"ma_sach"`
	Gia        float64 `json:"gia"`
	NgayApDung string  `json:"ngay_ap_dung"`
}

type Book struct {
	MaSach         int     `json:"ma_sach"`
	TenSach        string  `json:"ten_sach"`
	NamXuatBan     int     `json:"nam_xuat_ban"`
	SoTrang        int     `json:"so_trang"`
	GiaHienTai     float64 `json:"gia_hien_tai"`
	SoSaoTrungBinh float64 `json:"so_sao_trung_binh"`
}

type IdName struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type BookDetail struct {
	MaSach          int       `json:"ma_sach"`
	TenSach         string    `json:"ten_sach"`
	GiaHienTai      float64   `json:"gia_hien_tai"`
	SoSaoTrungBinh  float64   `json:"so_sao_trung_binh"`
	TenNguoiDich    *string   `json:"ten_nguoi_dich"`
	MoTa            *string   `json:"mo_ta"`
	HinhThuc        *string   `json:"hinh_thuc"`
	SoTrang         int       `json:"so_trang"`
	NamXuatBan      int       `json:"nam_xuat_ban"`
	NgayPhatHanh    *string   `json:"ngay_phat_hanh"`
	DoTuoi          *int      `json:"do_tuoi"`
	NhaXuatBan      IdName    `json:"nha_xuat_ban"`
	ListTacGia      []IdName  `json:"danh_sach_tac_gia"`
	ListTheLoai     []IdName  `json:"danh_sach_the_loai"`
}

type SearchResult struct {
	MaSach         int     `json:"ma_sach"`
	TenSach        string  `json:"ten_sach"`
	GiaHienTai     float64 `json:"gia_hien_tai"`
	SoSaoTrungBinh float64 `json:"so_sao_trung_binh"`
	TenNXB         string  `json:"ten_nxb"`
	NamXuatBan     int     `json:"nam_xuat_ban"`
	HinhThuc       *string `json:"hinh_thuc"`
}

type BookInput struct {
	TenSach      string   `json:"ten_sach"`
	NamXuatBan   int      `json:"nam_xuat_ban"`
	MaNXB        int      `json:"ma_nxb"`
	SoTrang      int      `json:"so_trang"`
	NgonNgu      string   `json:"ngon_ngu"`
	TrongLuong   *float64 `json:"trong_luong"`
	DoTuoi       *int     `json:"do_tuoi"`
	HinhThuc     *string  `json:"hinh_thuc"`
	MoTa         *string  `json:"mo_ta"`
	TenNguoiDich *string  `json:"ten_nguoi_dich"`
	GiaBan       float64  `json:"gia_ban"`
}

type BookUpdateInput struct {
	TenSach      *string  `json:"ten_sach"`
	NamXuatBan   *int     `json:"nam_xuat_ban"`
	MaNXB        *int     `json:"ma_nxb"`
	SoTrang      *int     `json:"so_trang"`
	NgonNgu      *string  `json:"ngon_ngu"`
	TrongLuong   *float64 `json:"trong_luong"`
	DoTuoi       *int     `json:"do_tuoi"`
	HinhThuc     *string  `json:"hinh_thuc"`
	MoTa         *string  `json:"mo_ta"`
	TenNguoiDich *string  `json:"ten_nguoi_dich"`
}

type PriceUpdateInput struct {
	GiaMoi float64 `json:"gia_moi"`
}

// --- CART & ORDER ---
type CartActionInput struct {
	MaSach      int `json:"ma_sach"`
	SoLuong     int `json:"so_luong"`
}

type CartHeader struct {
	MaDon       int     `json:"ma_don"`
	NgayTao     string  `json:"ngay_tao"`
	TongTien    float64 `json:"tong_tien"`
	TongSoLuong int     `json:"tong_so_luong"`
}

type CartItem struct {
	MaSach    int     `json:"ma_sach"`
	TenSach   string  `json:"ten_sach"`
	HinhThuc  *string `json:"hinh_thuc"`
	SoLuong   int     `json:"so_luong"`
	GiaMua    float64 `json:"gia_mua"`
	ThanhTien float64 `json:"thanh_tien"`
}

type OrderHistory struct {
	STT       int     `json:"stt_don"`
	MaDon     int     `json:"ma_don"`
	NgayDat   string  `json:"ngay_dat"`
	TongTien  float64 `json:"tong_tien"`
	TrangThai string  `json:"trang_thai"`
	TongItems int     `json:"tong_items"`
}

type PaymentMethodInput struct {
	HinhThuc    string `json:"hinh_thuc"` // "Visa" or "Shipper"
}

type ApplyVoucherInput struct {
	MaCode      string `json:"voucher_code"`
}

type UserVoucher struct {
	MaVoucher  int      `json:"ma_voucher"`
	MaCode     string   `json:"ma_code"`
	TenVoucher string   `json:"ten_voucher"`
	LoaiGiam   string   `json:"loai_giam"`
	GiaTriGiam float64  `json:"gia_tri_giam"`
	GiamToiDa  *float64 `json:"giam_toi_da"`
	NgayHetHan string   `json:"ngay_het_han"`
	SoLuong    int      `json:"so_luong"`
}

// --- USER & ADDRESS ---
type RegisterInput struct {
	Ho          string `json:"ho"`
	HoTenDem    string `json:"ho_ten_dem"`
	Email       string `json:"email"`
	SDT         string `json:"sdt"`
	TenDangNhap string `json:"ten_dang_nhap"`
	MatKhau     string `json:"mat_khau"`
	GioiTinh    string `json:"gioi_tinh"`
	NgaySinh    string `json:"ngay_sinh"`
}

type LoginInput struct {
	TenDangNhap string `json:"ten_dang_nhap"`
	MatKhau     string `json:"mat_khau"`
}

type MemberInfo struct {
	MaKhachHang int     `json:"ma_khach_hang"`
	HoTen       string  `json:"ho_ten"`
	Email       string  `json:"email"`
	SDT         string  `json:"sdt"`
	NgaySinh    string  `json:"ngay_sinh"`
	CapDo       string  `json:"cap_do_thanh_vien"`
	DiemTichLuy int     `json:"diem_tich_luy"`
	TongChiTieu float64 `json:"tong_chi_tieu"`
	TenDangNhap string  `json:"ten_dang_nhap"`
}

type AddressInput struct {
	ThanhPho  string `json:"thanh_pho"`
	QuanHuyen string `json:"quan_huyen"`
	PhuongXa  string `json:"phuong_xa"`
	DiaChiNha string `json:"dia_chi_nha"`
}

type AddressRecord struct {
	MaDiaChi  int    `json:"ma_dia_chi"`
	ThanhPho  string `json:"thanh_pho"`
	QuanHuyen string `json:"quan_huyen"`
	PhuongXa  string `json:"phuong_xa"`
	DiaChiNha string `json:"dia_chi_nha"`
}

// --- RATING ---
type RatingInput struct {
	MaSach      int    `json:"ma_sach"`
	SoSao       int    `json:"so_sao"`
	NoiDung     string `json:"noi_dung"`
}

type RatingRecord struct {
	MaDG        int    `json:"ma_dg"`
	TenNguoi    string `json:"ten_nguoi_dung"`
	SoSao       int    `json:"so_sao"`
	NoiDung     string `json:"noi_dung"`
	NgayDanhGia string `json:"ngay_danh_gia"`
}

// --- Admin ---
type AdminOrderRow struct {
	MaDon       int     `json:"ma_don"`
	KhachHang   string  `json:"khach_hang"`
	NgayDat     string  `json:"ngay_dat"`
	TongTien    float64 `json:"tong_tien"`
	TrangThai   string  `json:"trang_thai"`
	DiaChi      string  `json:"dia_chi"`
}
