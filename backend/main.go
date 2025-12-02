package main

import (
	"bufio"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"time"

	_ "github.com/denisenkom/go-mssqldb"
)

//###################
//## DATA STRUCTS ###
//###################
// Simple secret key for signing (Hardcoded for simplicity)
var SECRET_KEY = []byte("my-super-secret-key-123")

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
	MaSach     int     `json:"ma_sach"`
	TenSach    string  `json:"ten_sach"`
	NamXuatBan int     `json:"nam_xuat_ban"`
	SoTrang    int     `json:"so_trang"`
	GiaHienTai float64 `json:"gia_hien_tai"`
}

type BookDetail struct {
	MaSach          int     `json:"ma_sach"`
	TenSach         string  `json:"ten_sach"`
	GiaHienTai      float64 `json:"gia_hien_tai"`
	SoSaoTrungBinh  float64 `json:"so_sao_trung_binh"`
	TenNguoiDich    *string `json:"ten_nguoi_dich"`
	MoTa            *string `json:"mo_ta"`
	HinhThuc        *string `json:"hinh_thuc"`
	SoTrang         int     `json:"so_trang"`
	NamXuatBan      int     `json:"nam_xuat_ban"`
	NgayPhatHanh    *string `json:"ngay_phat_hanh"`
	TenNXB          string  `json:"ten_nxb"`
	DanhSachTacGia  *string `json:"danh_sach_tac_gia"`
	DanhSachTheLoai *string `json:"danh_sach_the_loai"`
}

// Input for creating a book
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
	TenNguoiDich *string  `json:"ten_nguoi_dich"` // Added
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
	TenNguoiDich *string  `json:"ten_nguoi_dich"` // Added
}

type PriceUpdateInput struct {
	GiaMoi float64 `json:"gia_moi"`
}

type OrderItem struct {
	MaSach  int `json:"ma_sach"`
	SoLuong int `json:"so_luong"`
}
type OrderInput struct {
	MaKhachHang int         `json:"customer_id"`
	MaVoucher   *int        `json:"voucher_id"`
	Items       []OrderItem `json:"items"`
}

// --- NEW AUTH & RATING STRUCTS ---
type RegisterInput struct {
	Ho          string `json:"ho"`
	HoTenDem    string `json:"ho_ten_dem"`
	Email       string `json:"email"`
	SDT         string `json:"sdt"`
	TenDangNhap string `json:"ten_dang_nhap"`
	MatKhau     string `json:"mat_khau"`
	GioiTinh    string `json:"gioi_tinh"`
	NgaySinh    string `json:"ngay_sinh"` // Format: YYYY-MM-DD
}

type LoginInput struct {
	TenDangNhap string `json:"ten_dang_nhap"`
	MatKhau     string `json:"mat_khau"`
}

type RatingInput struct {
	MaSach      int    `json:"ma_sach"`
	MaKhachHang int    `json:"customer_id"`
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

var db *sql.DB

//###################
//## MAIN SECTION ###
//###################
func main() {
	var err error
	connStr, err := read_connection_string("config.txt")
	if err != nil {
		log.Fatalf("Config Error: %v", err)
	}

	db, err = sql.Open("sqlserver", connStr)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatal(err)
	}

	handle_apis()

	log.Println("OK! API running on http://localhost:4444")
	log.Fatal(http.ListenAndServe(":4444", nil))
}

//############################
//## HELPER FUNCS SECTION ####
//############################
func nullToInt(n sql.NullInt64) int {
	if !n.Valid {
		return -1
	}
	return int(n.Int64)
}
func nullToString(n sql.NullString) string {
	if !n.Valid {
		return "-1"
	}
	return n.String
}
func nullToFloat(n sql.NullFloat64) float64 {
	if !n.Valid {
		return -1.0
	}
	return n.Float64
}

func read_connection_string(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "CONN_STRING=") {
			return strings.TrimPrefix(line, "CONN_STRING="), nil
		}
	}
	return "", fmt.Errorf("missing CONN_STRING")
}

// Returns TRUE if the request was handled (OPTIONS), so the caller should return.
func set_CORS_headers(w http.ResponseWriter, r *http.Request, flag int) bool {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// Added 'Authorization' so browsers allow the Bearer token
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	var methods string
	if flag == 0 {
		methods = "*"
	} else if flag == 1 {
		methods = "GET"
	} else if flag == 2 {
		methods = "POST"
	} else if flag == 3 {
		methods = "GET, POST"
	} else if flag == 4 {
		methods = "PUT"
	} else if flag == 5 {
		methods = "DELETE"
	} else {
		methods = "GET"
	}

	w.Header().Set("Access-Control-Allow-Methods", methods)

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return true
	}
	return false
}

func sendError(w http.ResponseWriter, code int, msg string) {
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func sendSuccess(w http.ResponseWriter, msg string, data interface{}) {
	resp := map[string]interface{}{"message": msg}
	if data != nil {
		resp["data"] = data
	}
	json.NewEncoder(w).Encode(resp)
}

func get_id_from_url(r *http.Request, w http.ResponseWriter) int {
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		sendError(w, 400, "Missing ?id=")
		return -1
	}

	id, err := strconv.Atoi(idStr)
	if err != nil {
		sendError(w, 400, "Invalid id format")
		return -1
	}
	return id
}

// Generate a simple signed token: "UserID:Timestamp.Signature"
func generate_token(userID int) string {
	// 1. Create Payload (ID + Expiry 24h)
	expiry := time.Now().Add(24 * time.Hour).Unix()
	payload := fmt.Sprintf("%d:%d", userID, expiry)

	// 2. Sign it
	h := hmac.New(sha256.New, SECRET_KEY)
	h.Write([]byte(payload))
	signature := base64.RawURLEncoding.EncodeToString(h.Sum(nil))

	// 3. Combine
	// We base64 the payload so it's URL safe
	encodedPayload := base64.RawURLEncoding.EncodeToString([]byte(payload))
	return fmt.Sprintf("%s.%s", encodedPayload, signature)
}

// Check token and return UserID. Returns 0 if invalid.
func validate_token(r *http.Request) int {
	// 1. Get header "Authorization: Bearer <token>"
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return 0
	}

	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		return 0
	}
	token := parts[1]

	// 2. Split Token
	tokenParts := strings.Split(token, ".")
	if len(tokenParts) != 2 {
		return 0
	}
	encodedPayload, signature := tokenParts[0], tokenParts[1]

	// 3. Verify Signature
	payloadBytes, _ := base64.RawURLEncoding.DecodeString(encodedPayload)
	h := hmac.New(sha256.New, SECRET_KEY)
	h.Write(payloadBytes)
	expectedSig := base64.RawURLEncoding.EncodeToString(h.Sum(nil))

	if signature != expectedSig {
		return 0
	} // Fake token

	// 4. Check Expiry
	payloadStr := string(payloadBytes)
	data := strings.Split(payloadStr, ":")
	if len(data) != 2 {
		return 0
	}

	userID, _ := strconv.Atoi(data[0])
	expiry, _ := strconv.ParseInt(data[1], 10, 64)

	if time.Now().Unix() > expiry {
		return 0
	} // Expired

	return userID
}

//#########################
//## APIS FUNCS SECTION ###
//#########################
func handle_apis() {
	http.HandleFunc("/get_all_books", get_all_books)
	http.HandleFunc("/get_book_by_id", get_book_by_id)
	http.HandleFunc("/get_books_by_author", get_books_by_author)
	http.HandleFunc("/get_books_by_category", get_books_by_category)
	http.HandleFunc("/add_new_book", add_new_book)
	http.HandleFunc("/update_book_info", update_book_info)
	http.HandleFunc("/change_book_price", change_book_price)
	http.HandleFunc("/delete_book", delete_book)

	http.HandleFunc("/create_customer_order", create_customer_order)

	http.HandleFunc("/get_nxb_by_id", get_nxb_by_id)
	http.HandleFunc("/get_price_by_id", get_price_by_id)

	http.HandleFunc("/register_member", register_member)
	http.HandleFunc("/login_member", login_member)

	http.HandleFunc("/add_rating", add_rating)
	http.HandleFunc("/get_ratings_by_book", get_ratings_by_book)
	http.HandleFunc("/get_rating_by_id", get_rating_by_id)
}

//######################
//## 1. GET ALL BOOK ###
//######################
func get_all_books(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}

	query := `
		SELECT ma_sach, ten_sach, nam_xuat_ban, so_trang, gia_hien_tai
		FROM sach 
		WHERE da_xoa = 0
	`
	rows, err := db.Query(query)
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	defer rows.Close()

	var books []Book
	for rows.Next() {
		var b Book
		var nNam, nPage sql.NullInt64
		var nPrice sql.NullFloat64
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nNam, &nPage, &nPrice); err != nil {
			continue
		}
		b.NamXuatBan = nullToInt(nNam)
		b.SoTrang = nullToInt(nPage)
		b.GiaHienTai = nullToFloat(nPrice)
		if b.GiaHienTai == -1 {
			b.GiaHienTai = 0
		}
		books = append(books, b)
	}
	if books == nil {
		books = []Book{}
	}
	json.NewEncoder(w).Encode(books)
}

//########################
//## 2. GET BOOK BY ID ###
//########################
func get_book_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	// 1. Call the SQL Function
	query := "SELECT * FROM fn_LayChiTietSach(@p1)"

	var b BookDetail
	// 2. Scan directly into the struct
	// The order MUST match the columns returned by fn_LayChiTietSach
	err := db.QueryRow(query, sql.Named("p1", id)).Scan(
		&b.MaSach, &b.TenSach, &b.GiaHienTai,
		&b.SoSaoTrungBinh, &b.TenNguoiDich, &b.MoTa,
		&b.HinhThuc, &b.SoTrang, &b.NamXuatBan, &b.NgayPhatHanh,
		&b.TenNXB, &b.DanhSachTacGia, &b.DanhSachTheLoai,
	)

	if err == sql.ErrNoRows {
		sendError(w, 404, "Book Not Found")
		return
	} else if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	json.NewEncoder(w).Encode(b)
}

//##################
//## 3. ADD BOOK ###
//##################
func add_new_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}

	var input BookInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		sendError(w, 400, "Invalid JSON: "+err.Error())
		return
	}

	var newID int
	query := `
		EXEC sp_ThemSach 
		@ten_sach=@p1, @nam_xuat_ban=@p2, @ma_nxb=@p3, @so_trang=@p4, 
		@ngon_ngu=@p5, @trong_luong=@p6, @do_tuoi=@p7, @hinh_thuc=@p8, 
		@mo_ta=@p9, @gia_ban=@p10, @ten_nguoi_dich=@p11, @ma_sach_moi=@pOut OUTPUT
	`
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("p1", input.TenSach), sql.Named("p2", input.NamXuatBan),
		sql.Named("p3", input.MaNXB), sql.Named("p4", input.SoTrang),
		sql.Named("p5", input.NgonNgu), sql.Named("p6", input.TrongLuong),
		sql.Named("p7", input.DoTuoi), sql.Named("p8", input.HinhThuc),
		sql.Named("p9", input.MoTa), sql.Named("p10", input.GiaBan),
		sql.Named("p11", input.TenNguoiDich), // Added translator
		sql.Named("pOut", sql.Out{Dest: &newID}),
	)

	if err != nil {
		sendError(w, 500, "SQL Error: "+err.Error())
		return
	}
	sendSuccess(w, "Added", map[string]int{"id": newID})
}

//#####################
//## 4. UPDATE BOOK ###
//#####################
func update_book_info(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	var input BookUpdateInput
	json.NewDecoder(r.Body).Decode(&input)

	query := `
		EXEC sp_SuaSach @ma_sach=@pid, @ten_sach=@p1, @nam_xuat_ban=@p2, 
		@ma_nxb=@p3, @so_trang=@p4, @ngon_ngu=@p5, @trong_luong=@p6, 
		@do_tuoi=@p7, @hinh_thuc=@p8, @mo_ta=@p9, @ten_nguoi_dich=@p10
	`
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("pid", id), sql.Named("p1", input.TenSach),
		sql.Named("p2", input.NamXuatBan), sql.Named("p3", input.MaNXB),
		sql.Named("p4", input.SoTrang), sql.Named("p5", input.NgonNgu),
		sql.Named("p6", input.TrongLuong), sql.Named("p7", input.DoTuoi),
		sql.Named("p8", input.HinhThuc), sql.Named("p9", input.MoTa),
		sql.Named("p10", input.TenNguoiDich), // Added translator
	)

	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	sendSuccess(w, "Updated Info (Price Unchanged)", nil)
}

//#######################
//## 5. CHANGE PRICE ####
//#######################
func change_book_price(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	var input PriceUpdateInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Invalid JSON")
		return
	}

	query := `EXEC sp_CapNhatGia @ma_sach=@p1, @gia_moi=@p2`
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("p1", id), sql.Named("p2", input.GiaMoi))

	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	sendSuccess(w, "Price Updated & History Logged", nil)
}

//#####################
//## 6. DELETE BOOK ###
//#####################
func delete_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	_, err := db.ExecContext(context.Background(),
		"EXEC sp_XoaSach @ma_sach=@p1",
		sql.Named("p1", id))

	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	sendSuccess(w, "Book Soft Deleted", nil)
}

//######################
//## 7. CREATE ORDER ###
//######################
func create_customer_order(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}

	var input OrderInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Bad JSON")
		return
	}

	ctx := context.Background()
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		sendError(w, 500, "Tx Start Error")
		return
	}
	defer tx.Rollback()

	var orderID int
	queryOrder := `
		INSERT INTO don_hang (ma_khach_hang, ma_voucher, tong_tien_thanh_toan, trang_thai_don_hang)
		VALUES (@p1, @p2, 0, N'Chờ xử lý');
		SELECT CAST(SCOPE_IDENTITY() AS INT);
	`
	err = tx.QueryRowContext(ctx, queryOrder,
		sql.Named("p1", input.MaKhachHang),
		sql.Named("p2", input.MaVoucher)).Scan(&orderID)

	if err != nil {
		sendError(w, 500, "Order Creation Error: "+err.Error())
		return
	}

	totalMoney := 0.0
	for _, item := range input.Items {
		var currentPrice float64
		var currentPriceID int

		// FETCH PRICE SNAPSHOT
		err = tx.QueryRowContext(ctx,
			`SELECT gia_hien_tai, ma_gia_hien_tai 
			 FROM sach WHERE ma_sach = @p1 AND da_xoa = 0`,
			sql.Named("p1", item.MaSach)).Scan(&currentPrice, &currentPriceID)

		if err != nil {
			sendError(w, 400, fmt.Sprintf("Book %d invalid or deleted", item.MaSach))
			return
		}

		// INSERT WITH PRICE LOCK
		_, err = tx.ExecContext(ctx, `
			INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong)
			VALUES (@p1, @p2, @p3, @p4, @p5)
		`, sql.Named("p1", orderID), sql.Named("p2", item.MaSach),
			sql.Named("p3", currentPriceID),
			sql.Named("p4", currentPrice),
			sql.Named("p5", item.SoLuong))

		if err != nil {
			if strings.Contains(err.Error(), "không đủ tồn kho") {
				sendError(w, 409, "Out of Stock: "+err.Error())
			} else {
				sendError(w, 500, "DB Error: "+err.Error())
			}
			return
		}
		totalMoney += currentPrice * float64(item.SoLuong)
	}

	_, err = tx.ExecContext(ctx, "UPDATE don_hang SET tong_tien_thanh_toan = @p1 WHERE ma_don = @p2",
		sql.Named("p1", totalMoney), sql.Named("p2", orderID))

	if err != nil {
		sendError(w, 500, "Update Total Failed")
		return
	}

	if err := tx.Commit(); err != nil {
		sendError(w, 500, "Commit Failed")
		return
	}

	sendSuccess(w, "Order Placed", map[string]interface{}{"order_id": orderID})
}

//#######################
//## 8. GET NXB BY ID ###
//#######################
func get_nxb_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	query := `SELECT ma_nxb, ten_nxb, email, dia_chi, sdt FROM nha_xuat_ban WHERE ma_nxb = @p1`

	var p Publisher
	var nEmail, nDiaChi, nSDT sql.NullString

	err := db.QueryRow(query, sql.Named("p1", id)).Scan(
		&p.MaNXB, &p.TenNXB, &nEmail, &nDiaChi, &nSDT)

	if err == sql.ErrNoRows {
		sendError(w, 404, "Publisher Not Found")
		return
	} else if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	p.Email = nullToString(nEmail)
	p.DiaChi = nullToString(nDiaChi)
	p.SDT = nullToString(nSDT)

	json.NewEncoder(w).Encode(p)
}

//#########################
//## 9. GET PRICE BY ID ###
//#########################
func get_price_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	query := `
		SELECT ma_gia, ma_sach, gia, FORMAT(ngay_ap_dung, 'yyyy-MM-dd HH:mm:ss') 
		FROM gia_ban 
		WHERE ma_gia = @p1
	`

	var pr PriceRecord
	err := db.QueryRow(query, sql.Named("p1", id)).Scan(
		&pr.MaGia, &pr.MaSach, &pr.Gia, &pr.NgayApDung)

	if err == sql.ErrNoRows {
		sendError(w, 404, "Price Record Not Found")
		return
	} else if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	json.NewEncoder(w).Encode(pr)
}

//##########################
//## 10. REGISTER MEMBER ###
//##########################
func register_member(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}

	var input RegisterInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Bad JSON")
		return
	}

	// Handle optional birthdate
	var ngaySinh interface{} = nil
	if input.NgaySinh != "" {
		ngaySinh = input.NgaySinh
	}

	var newID int
	query := `
		EXEC sp_DangKyThanhVien 
		@ho=@p1, @ho_ten_dem=@p2, @email=@p3, @sdt=@p4, 
		@ten_dang_nhap=@p5, @mat_khau=@p6, @gioi_tinh=@p7, @ngay_sinh=@p8
	`

	err := db.QueryRow(query,
		sql.Named("p1", input.Ho),
		sql.Named("p2", input.HoTenDem),
		sql.Named("p3", input.Email),
		sql.Named("p4", input.SDT),
		sql.Named("p5", input.TenDangNhap),
		sql.Named("p6", input.MatKhau),
		sql.Named("p7", input.GioiTinh),
		sql.Named("p8", ngaySinh)).Scan(&newID)

	if err != nil {
		if strings.Contains(err.Error(), "50030") {
			sendError(w, 409, "Username taken")
		} else if strings.Contains(err.Error(), "50031") {
			sendError(w, 409, "Email taken")
		} else {
			sendError(w, 500, err.Error())
		}
		return
	}
	sendSuccess(w, "Registered", map[string]int{"customer_id": newID})
}

//#######################
//## 11. LOGIN MEMBER ###
//#######################
func login_member(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}

	var input LoginInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Bad JSON")
		return
	}

	var id int
	var username, fullname string

	query := `EXEC sp_DangNhap @ten_dang_nhap=@p1, @mat_khau=@p2`
	err := db.QueryRow(query,
		sql.Named("p1", input.TenDangNhap),
		sql.Named("p2", input.MatKhau)).Scan(&id, &username, &fullname)

	if err != nil {
		// BLUNT: You asked for 404 Not Found on login fail
		sendError(w, 404, "User Not Found")
		return
	}

	// Generate simple token
	token := generate_token(id)

	// Return ONLY the token
	json.NewEncoder(w).Encode(map[string]string{"token": token})
}

//#####################
//## 12. ADD RATING ###
//#####################
func add_rating(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) {
		return
	}

	// 1. AUTH CHECK
	userID := validate_token(r)
	if userID == 0 {
		sendError(w, 401, "Unauthorized: Invalid or Missing Token")
		return
	}

	var input RatingInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Bad JSON")
		return
	}

	// 2. OVERWRITE ID (Security)
	// We don't care what ID they sent in JSON. We use the ID from the Token.
	input.MaKhachHang = userID

	// 3. EXECUTE
	_, err := db.ExecContext(context.Background(),
		"EXEC sp_ThemDanhGia @ma_sach=@p1, @ma_khach_hang=@p2, @so_sao=@p3, @noi_dung=@p4",
		sql.Named("p1", input.MaSach),
		sql.Named("p2", input.MaKhachHang), // Using verified ID
		sql.Named("p3", input.SoSao),
		sql.Named("p4", input.NoiDung))

	if err != nil {
		if strings.Contains(err.Error(), "50040") {
			sendError(w, 404, "Book not found")
		} else {
			sendError(w, 500, err.Error())
		}
		return
	}
	sendSuccess(w, "Rating Added", nil)
}

//######################
//## 13. GET RATINGS ###
//######################
func get_ratings_by_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	// Fetch raw history list
	query := `
		SELECT dg.ma_dg, kh.ho + ' ' + kh.ho_ten_dem, dg.so_sao, dg.noi_dung, 
		       FORMAT(dg.ngay_danh_gia, 'yyyy-MM-dd')
		FROM danh_gia dg
		JOIN khach_hang kh ON dg.ma_khach_hang = kh.ma_khach_hang
		WHERE dg.ma_sach = @p1
		ORDER BY dg.ngay_danh_gia DESC
	`
	rows, err := db.Query(query, sql.Named("p1", id))
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	defer rows.Close()

	var list []RatingRecord
	for rows.Next() {
		var r RatingRecord
		if err := rows.Scan(&r.MaDG, &r.TenNguoi, &r.SoSao, &r.NoiDung, &r.NgayDanhGia); err == nil {
			list = append(list, r)
		}
	}
	if list == nil {
		list = []RatingRecord{}
	}

	json.NewEncoder(w).Encode(list)
}

//###########################
//## 14. GET RATING BY ID ###
//###########################
func get_rating_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	// Fetch single review detail
	query := `
		SELECT dg.ma_dg, kh.ho + ' ' + kh.ho_ten_dem, dg.so_sao, dg.noi_dung, 
		       FORMAT(dg.ngay_danh_gia, 'yyyy-MM-dd')
		FROM danh_gia dg
		JOIN khach_hang kh ON dg.ma_khach_hang = kh.ma_khach_hang
		WHERE dg.ma_dg = @p1
	`

	var rec RatingRecord
	err := db.QueryRow(query, sql.Named("p1", id)).Scan(
		&rec.MaDG, &rec.TenNguoi, &rec.SoSao, &rec.NoiDung, &rec.NgayDanhGia)

	if err == sql.ErrNoRows {
		sendError(w, 404, "Review Not Found")
		return
	} else if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	json.NewEncoder(w).Encode(rec)
}

//################################
//## 15. GET BOOKS BY AUTHOR #####
//################################
func get_books_by_author(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	// Matches get_all_books style
	query := "SELECT * FROM fn_LaySachTheoTacGia(@p1)"

	rows, err := db.Query(query, sql.Named("p1", id))
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	defer rows.Close()

	var books []Book
	for rows.Next() {
		var b Book
		var nNam, nPage sql.NullInt64
		var nPrice sql.NullFloat64
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nNam, &nPage, &nPrice); err != nil {
			continue
		}
		b.NamXuatBan = nullToInt(nNam)
		b.SoTrang = nullToInt(nPage)
		b.GiaHienTai = nullToFloat(nPrice)
		if b.GiaHienTai == -1 {
			b.GiaHienTai = 0
		}
		books = append(books, b)
	}
	if books == nil {
		books = []Book{}
	}
	json.NewEncoder(w).Encode(books)
}

//##################################
//## 16. GET BOOKS BY CATEGORY #####
//##################################
func get_books_by_category(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) {
		return
	}
	id := get_id_from_url(r, w)
	if id == -1 {
		return
	}

	// Matches get_all_books style
	query := "SELECT * FROM fn_LaySachTheoTheLoai(@p1)"

	rows, err := db.Query(query, sql.Named("p1", id))
	if err != nil {
		sendError(w, 500, err.Error())
		return
	}
	defer rows.Close()

	var books []Book
	for rows.Next() {
		var b Book
		var nNam, nPage sql.NullInt64
		var nPrice sql.NullFloat64
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nNam, &nPage, &nPrice); err != nil {
			continue
		}
		b.NamXuatBan = nullToInt(nNam)
		b.SoTrang = nullToInt(nPage)
		b.GiaHienTai = nullToFloat(nPrice)
		if b.GiaHienTai == -1 {
			b.GiaHienTai = 0
		}
		books = append(books, b)
	}
	if books == nil {
		books = []Book{}
	}
	json.NewEncoder(w).Encode(books)
}
