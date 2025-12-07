package main

// data type is in data.go
import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/denisenkom/go-mssqldb"
)

//###################
//## CONFIG & VARS ##
//###################
var db *sql.DB
var SECRET_KEY = []byte("user-secret-key-123")
var ADMIN_SECRET = []byte("admin-super-secret-999")

//###################
//## MAIN SECTION ###
//###################
func main() {
	connStr, err := read_connection_string("config.txt")
	if err != nil { log.Fatalf("Config Error: %v", err) }

	db, err = sql.Open("sqlserver", connStr)
	if err != nil { log.Fatal(err) }
	defer db.Close()

	if err = db.Ping(); err != nil { log.Fatal(err) }

	// [Auto-Gen Admin Token to Terminal]
	go func() {
		for {
			token := generate_admin_token()
			fmt.Printf("\n\n[ADMIN ACCESS] Copy this header:\nAuthorization: Bearer %s\n\n", token)
			time.Sleep(5 * time.Minute)
		}
	}()

	handle_apis()
	log.Println("OK! API running on http://localhost:4444")
	log.Fatal(http.ListenAndServe(":4444", nil))
}

//############################
//## HELPER FUNCS SECTION ####
//############################
func nullToInt(n sql.NullInt64) int { if !n.Valid { return -1 }; return int(n.Int64) }
func nullToString(n sql.NullString) string { if !n.Valid { return "" }; return n.String }
func nullToFloat(n sql.NullFloat64) float64 { if !n.Valid { return -1.0 }; return n.Float64 }

func read_connection_string(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil { return "", err }
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

func set_CORS_headers(w http.ResponseWriter, r *http.Request, flag int) bool {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	methods := "GET"
	if flag == 0 { methods = "*"
	} else if flag == 1 { methods = "GET"
	} else if flag == 2 { methods = "POST"
	} else if flag == 3 { methods = "GET, POST"
	} else if flag == 4 { methods = "PUT"
	} else if flag == 5 { methods = "DELETE" }
	w.Header().Set("Access-Control-Allow-Methods", methods)
	if r.Method == "OPTIONS" { w.WriteHeader(http.StatusOK); return true }
	return false
}

func sendError(w http.ResponseWriter, code int, msg string) {
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func sendSuccess(w http.ResponseWriter, msg string, data interface{}) {
	resp := map[string]interface{}{"message": msg}
	if data != nil { resp["data"] = data }
	json.NewEncoder(w).Encode(resp)
}

func get_id_from_url(r *http.Request, w http.ResponseWriter) int {
	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return -1 }
	id, err := strconv.Atoi(idStr)
	if err != nil { sendError(w, 400, "Invalid id format"); return -1 }
	return id
}

func generate_token(userID int) string {
	expiry := time.Now().Add(24 * time.Hour).Unix()
	payload := fmt.Sprintf("%d:%d", userID, expiry)
	h := hmac.New(sha256.New, SECRET_KEY)
	h.Write([]byte(payload))
	sig := base64.RawURLEncoding.EncodeToString(h.Sum(nil))
	pl := base64.RawURLEncoding.EncodeToString([]byte(payload))
	return fmt.Sprintf("%s.%s", pl, sig)
}

func validate_token(r *http.Request) int {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" { return 0 }
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" { return 0 }
	tokenParts := strings.Split(parts[1], ".")
	if len(tokenParts) != 2 { return 0 }
	plBytes, _ := base64.RawURLEncoding.DecodeString(tokenParts[0])
	h := hmac.New(sha256.New, SECRET_KEY)
	h.Write(plBytes)
	if tokenParts[1] != base64.RawURLEncoding.EncodeToString(h.Sum(nil)) { return 0 }
	data := strings.Split(string(plBytes), ":")
	if len(data) != 2 { return 0 }
	uid, _ := strconv.Atoi(data[0])
	exp, _ := strconv.ParseInt(data[1], 10, 64)
	if time.Now().Unix() > exp { return 0 }
	return uid
}

func generate_admin_token() string {
	payload := fmt.Sprintf("ADMIN:%d", time.Now().Add(5*time.Minute).Unix())
	h := hmac.New(sha256.New, ADMIN_SECRET)
	h.Write([]byte(payload))
	signature := h.Sum(nil)
	enc := base64.RawURLEncoding
	return enc.EncodeToString([]byte(payload)) + "." + enc.EncodeToString(signature)
}

func validate_admin_token(r *http.Request) bool {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" { return false }
	headerParts := strings.Split(authHeader, " ")
	if len(headerParts) != 2 || headerParts[0] != "Bearer" { return false }
	tokenParts := strings.Split(headerParts[1], ".")
	if len(tokenParts) != 2 { return false }
	payloadBytes, err := base64.RawURLEncoding.DecodeString(tokenParts[0])
	if err != nil { return false }
	mac := hmac.New(sha256.New, ADMIN_SECRET)
	mac.Write(payloadBytes)
	expectedSig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	if tokenParts[1] != expectedSig { return false }
	data := strings.Split(string(payloadBytes), ":")
	if len(data) != 2 || data[0] != "ADMIN" { return false }
	exp, err := strconv.ParseInt(data[1], 10, 64)
	if err != nil { return false }
	return time.Now().Unix() <= exp
}

func generate_session_id() string {
	b := make([]byte, 16)
	_, err := rand.Read(b) 
	if err != nil { return fmt.Sprintf("%d", time.Now().UnixNano()) }
	return base64.RawURLEncoding.EncodeToString(b)
}

//#########################
//## APIS FUNCS SECTION ###
//#########################
func handle_apis() {
	// Book CRUD
	http.HandleFunc("/get_all_books", get_all_books)
	http.HandleFunc("/get_book_by_id", get_book_by_id)
	http.HandleFunc("/add_new_book", add_new_book)
	http.HandleFunc("/update_book_info", update_book_info)
	http.HandleFunc("/change_book_price", change_book_price)
	http.HandleFunc("/delete_book", delete_book)
	http.HandleFunc("/search_books", search_books)
	http.HandleFunc("/get_book_sold_qty", get_book_sold_qty)
	
	// Cart & Checkout
	http.HandleFunc("/add_to_cart", add_to_cart)
	http.HandleFunc("/remove_from_cart", remove_from_cart)
	http.HandleFunc("/update_cart_qty", update_cart_qty)
	http.HandleFunc("/get_current_cart", get_current_cart)
	http.HandleFunc("/checkout", checkout)

	// Address
	http.HandleFunc("/set_shipping_address", set_shipping_address)
	http.HandleFunc("/add_address", add_address)
	http.HandleFunc("/get_my_addresses", get_my_addresses)

	// Order Management
	http.HandleFunc("/cancel_order", cancel_order)
	http.HandleFunc("/update_order_status", update_order_status)
	http.HandleFunc("/get_order_history", get_order_history)
	http.HandleFunc("/get_order_detail", get_order_detail)

	// Member Auth
	http.HandleFunc("/register_member", register_member)
	http.HandleFunc("/login_member", login_member)
	http.HandleFunc("/get_member_info", get_member_info)

	// Payment
	http.HandleFunc("/set_payment_method", set_payment_method)
	http.HandleFunc("/get_last_payment_method", get_last_payment_method)

	// Vouchers
	http.HandleFunc("/apply_voucher", apply_voucher)
	http.HandleFunc("/get_my_vouchers", get_my_vouchers)
	http.HandleFunc("/find_best_voucher", find_best_voucher)

	// Misc
	http.HandleFunc("/get_nxb_by_id", get_nxb_by_id)
	http.HandleFunc("/get_price_by_id", get_price_by_id)
	http.HandleFunc("/get_all_categories", get_all_categories)
	http.HandleFunc("/get_all_authors", get_all_authors)

	// Ratings
	http.HandleFunc("/add_rating", add_rating)
	http.HandleFunc("/get_ratings_by_book", get_ratings_by_book)
	http.HandleFunc("/get_rating_by_id", get_rating_by_id)

	// Filters
	http.HandleFunc("/get_books_by_author", get_books_by_author)
	http.HandleFunc("/get_books_by_category", get_books_by_category)

	// Admin
	http.HandleFunc("/admin/get_all_orders", admin_get_all_orders)
	http.HandleFunc("/admin/restock_book", admin_restock_book)
	http.HandleFunc("/get_deleted_books", get_deleted_books)

	// Guest
	http.HandleFunc("/create_guest_session", create_guest_session)
}

// ######################
// ## 1. GET ALL BOOKS ##
// ######################
func get_all_books(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }

	// [UPDATED] Added 'so_sao_trung_binh' to SELECT
	query := "SELECT ma_sach, ten_sach, nam_xuat_ban, so_trang, gia_hien_tai, so_sao_trung_binh FROM sach WHERE da_xoa = 0"
	
	rows, err := db.Query(query)
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()

	var books []Book
	for rows.Next() {
		var b Book
		var nNam, nPage sql.NullInt64
		var nPrice, nStar sql.NullFloat64

		// [UPDATED] Added &nStar to Scan
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nNam, &nPage, &nPrice, &nStar); err != nil { continue }

		b.NamXuatBan = nullToInt(nNam)
		b.SoTrang = nullToInt(nPage)
		
		b.GiaHienTai = nullToFloat(nPrice)
		if b.GiaHienTai == -1 { b.GiaHienTai = 0 }

		// Handle Null Star (Default to 0)
		b.SoSaoTrungBinh = nullToFloat(nStar)
		if b.SoSaoTrungBinh == -1 { b.SoSaoTrungBinh = 0 }

		books = append(books, b)
	}
	
	if books == nil { books = []Book{} }
	json.NewEncoder(w).Encode(books)
}

//########################
//## 2. GET BOOK BY ID ###
//########################
func get_book_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }

	var b BookDetail
	
	// [FIX] Use Null types for data that might be NULL in DB
	var rawAuthors, rawCategories sql.NullString
	var nStar sql.NullFloat64 
	
	err := db.QueryRow("SELECT * FROM fn_LayChiTietSach(@p1)", sql.Named("p1", id)).Scan(
		&b.MaSach, &b.TenSach, &b.GiaHienTai, &nStar, // <--- Scan into nStar, NOT b.SoSaoTrungBinh
		&b.TenNguoiDich, &b.MoTa, &b.HinhThuc, &b.SoTrang, &b.NamXuatBan, &b.NgayPhatHanh, &b.DoTuoi,
		&b.NhaXuatBan.ID, &b.NhaXuatBan.Name, 
		&rawAuthors, &rawCategories)

	if err == sql.ErrNoRows { sendError(w, 404, "Book Not Found"); return }
	if err != nil { sendError(w, 500, err.Error()); return }

	// [FIX] Assign value if valid, otherwise it stays 0
	if nStar.Valid { b.SoSaoTrungBinh = nStar.Float64 }

	if rawAuthors.Valid {
		json.Unmarshal([]byte(rawAuthors.String), &b.ListTacGia)
	} else {
		b.ListTacGia = []IdName{}
	}

	if rawCategories.Valid {
		json.Unmarshal([]byte(rawCategories.String), &b.ListTheLoai)
	} else {
		b.ListTheLoai = []IdName{}
	}

	json.NewEncoder(w).Encode(b)
}

//##################
//## 3. ADD BOOK ###
//##################
func add_new_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Unauthorized: Invalid or expired admin token"); return }

	var input BookInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Invalid JSON"); return }

	var newID int
	query := `EXEC sp_ThemSach @ten_sach=@p1, @nam_xuat_ban=@p2, @ma_nxb=@p3, @so_trang=@p4, 
		@ngon_ngu=@p5, @trong_luong=@p6, @do_tuoi=@p7, @hinh_thuc=@p8, @mo_ta=@p9, 
		@gia_ban=@p10, @ten_nguoi_dich=@p11, @ma_sach_moi=@pOut OUTPUT`
	
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("p1", input.TenSach), sql.Named("p2", input.NamXuatBan),
		sql.Named("p3", input.MaNXB), sql.Named("p4", input.SoTrang),
		sql.Named("p5", input.NgonNgu), sql.Named("p6", input.TrongLuong),
		sql.Named("p7", input.DoTuoi), sql.Named("p8", input.HinhThuc),
		sql.Named("p9", input.MoTa), sql.Named("p10", input.GiaBan),
		sql.Named("p11", input.TenNguoiDich), sql.Named("pOut", sql.Out{Dest: &newID}))

	if err != nil { sendError(w, 500, "SQL Error: "+err.Error()); return }
	sendSuccess(w, "Added", map[string]int{"id": newID})
}

//#####################
//## 4. UPDATE BOOK ###
//#####################
func update_book_info(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Unauthorized"); return }

	id := get_id_from_url(r, w); if id == -1 { return }
	var input BookUpdateInput
	json.NewDecoder(r.Body).Decode(&input)

	query := `EXEC sp_SuaSach @ma_sach=@pid, @ten_sach=@p1, @nam_xuat_ban=@p2, 
		@ma_nxb=@p3, @so_trang=@p4, @ngon_ngu=@p5, @trong_luong=@p6, @do_tuoi=@p7, 
		@hinh_thuc=@p8, @mo_ta=@p9, @ten_nguoi_dich=@p10`
	
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("pid", id), sql.Named("p1", input.TenSach),
		sql.Named("p2", input.NamXuatBan), sql.Named("p3", input.MaNXB),
		sql.Named("p4", input.SoTrang), sql.Named("p5", input.NgonNgu),
		sql.Named("p6", input.TrongLuong), sql.Named("p7", input.DoTuoi),
		sql.Named("p8", input.HinhThuc), sql.Named("p9", input.MoTa),
		sql.Named("p10", input.TenNguoiDich))

	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Updated Info", nil)
}

//#######################
//## 5. CHANGE PRICE ####
//#######################
func change_book_price(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Unauthorized"); return }

	id := get_id_from_url(r, w); if id == -1 { return }
	var input PriceUpdateInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Invalid JSON"); return }

	_, err := db.ExecContext(context.Background(), "EXEC sp_CapNhatGia @ma_sach=@p1, @gia_moi=@p2",
		sql.Named("p1", id), sql.Named("p2", input.GiaMoi))

	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Price Updated", nil)
}

//#####################
//## 6. DELETE BOOK ###
//#####################
func delete_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Unauthorized"); return }

	id := get_id_from_url(r, w); if id == -1 { return }
	_, err := db.ExecContext(context.Background(), "EXEC sp_XoaSach @ma_sach=@p1", sql.Named("p1", id))
	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Book Soft Deleted", nil)
}

//############################################
//## 7. SEARCH BOOKS (Name*, Author, Type) ###
//############################################
func search_books(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	name := r.URL.Query().Get("name")
	author := r.URL.Query().Get("author")
	bType := r.URL.Query().Get("type")

	if name == "" { sendError(w, 400, "Missing required parameter: name"); return }

	var sAuthor, sType sql.NullString
	if strings.TrimSpace(author) != "" { sAuthor = sql.NullString{String: author, Valid: true} }
	if strings.TrimSpace(bType) != "" { sType = sql.NullString{String: bType, Valid: true} }

	rows, err := db.Query("EXEC sp_TimKiemSach_NangCao @ten_sach=@p1, @ten_tac_gia=@p2, @ten_the_loai=@p3",
		sql.Named("p1", name), sql.Named("p2", sAuthor), sql.Named("p3", sType))

	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()

	var results []SearchResult
	for rows.Next() {
		var b SearchResult
		var nHinh sql.NullString
		var nStar sql.NullFloat64 // [FIX] Handle NULL rating

		// [FIX] Scan into nStar
		if err := rows.Scan(&b.MaSach, &b.TenSach, &b.GiaHienTai, &nStar, &b.TenNXB, &b.NamXuatBan, &nHinh); err == nil {
			if nHinh.Valid { b.HinhThuc = &nHinh.String }
			if nStar.Valid { b.SoSaoTrungBinh = nStar.Float64 } // [FIX] Assign
			results = append(results, b)
		}
	}
	if results == nil { results = []SearchResult{} }
	json.NewEncoder(w).Encode(results)
}

//###########################
//## 8. CART: ADD ITEM ######
//###########################
func add_to_cart(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var input CartActionInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }

	var cartID int
	err := db.QueryRowContext(context.Background(), "EXEC sp_ThemSachVaoGioHang @ma_khach_hang=@p1, @ma_sach=@p2, @so_luong=@p3",
		sql.Named("p1", uid), sql.Named("p2", input.MaSach),
		sql.Named("p3", input.SoLuong)).Scan(&cartID)

	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Item Added to Cart", map[string]int{"cart_id": cartID})
}


//###########################
//## 9. CART: REMOVE ITEM ###
//###########################
func remove_from_cart(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var input CartActionInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }

	_, err := db.ExecContext(context.Background(), "EXEC sp_XoaKhoiGioHang @ma_khach_hang=@p1, @ma_sach=@p2",
		sql.Named("p1", uid), sql.Named("p2", input.MaSach))

	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Item Removed", nil)
}

//###########################
//## 10. CART: UPDATE QTY ###
//###########################
func update_cart_qty(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var input CartActionInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }

	_, err := db.ExecContext(context.Background(), "EXEC sp_CapNhatSoLuongGioHang @ma_khach_hang=@p1, @ma_sach=@p2, @so_luong_moi=@p3",
		sql.Named("p1", uid), sql.Named("p2", input.MaSach), sql.Named("p3", input.SoLuong))

	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Cart Updated", nil)
}

//########################################
//## 11. CART: GET CURRENT (With Cursor) #
//########################################
func get_current_cart(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var h CartHeader
	var discount sql.NullFloat64
	
	err := db.QueryRow("SELECT dh.ma_don, dh.thoi_diem_tao_gio_hang, dh.tong_tien_thanh_toan, COUNT(ct.ma_sach), dh.gia_tri_giam_gia FROM don_hang dh LEFT JOIN chi_tiet_don_hang ct ON dh.ma_don = ct.ma_don WHERE dh.ma_khach_hang = @p1 AND dh.da_dat_hang = 0 GROUP BY dh.ma_don, dh.thoi_diem_tao_gio_hang, dh.tong_tien_thanh_toan, dh.gia_tri_giam_gia", 
		sql.Named("p1", uid)).Scan(&h.MaDon, &h.NgayTao, &h.TongTien, &h.TongSoLuong, &discount)
	
	if err == sql.ErrNoRows { sendSuccess(w, "Cart Empty", nil); return }
	if err != nil { sendError(w, 500, err.Error()); return }

	rows, _ := db.Query("SELECT * FROM fn_LayChiTietDonHang(@p1)", sql.Named("p1", h.MaDon))
	var items []CartItem
	for rows.Next() {
		var i CartItem
		rows.Scan(&i.MaSach, &i.TenSach, &i.HinhThuc, &i.SoLuong, &i.GiaMua, &i.ThanhTien)
		items = append(items, i)
	}
	rows.Close()

	warnRows, _ := db.Query("SELECT * FROM fn_ReviewGioHang_Live(@p1)", sql.Named("p1", uid))
	var warnings []string
	for warnRows.Next() {
		var ms int; var ts, code, msg string
		warnRows.Scan(&ms, &ts, &code, &msg)
		warnings = append(warnings, fmt.Sprintf("[%s] %s: %s", code, ts, msg))
	}
	warnRows.Close()

	if items == nil { items = []CartItem{} }
	if warnings == nil { warnings = []string{} }

	discountValue := 0.0
	if discount.Valid { discountValue = discount.Float64 }

	sendSuccess(w, "Current Cart", map[string]interface{}{
		"header": h, 
		"items": items, 
		"warnings": warnings,
		"discount": discountValue,
	})
}

//#################################################
//## 12. CART: CHECKOUT (Strict Validation) #######
//#################################################
func checkout(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var input struct { CartID int `json:"cart_id"` }
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }

	// [FIX] Verify cart ownership
	var ownerID int
	err := db.QueryRow("SELECT ma_khach_hang FROM don_hang WHERE ma_don = @p1", sql.Named("p1", input.CartID)).Scan(&ownerID)
	if err != nil { sendError(w, 404, "Cart Not Found"); return }
	if ownerID != uid { sendError(w, 403, "This cart does not belong to you"); return }

	var addrCheck sql.NullString
	var paymentCheck int
	query := `SELECT dh.dia_chi_giao_hang, COUNT(tt.ma_thanh_toan)
		FROM don_hang dh
		LEFT JOIN thanh_toan tt ON dh.ma_don = tt.ma_don
		WHERE dh.ma_don = @p1 GROUP BY dh.dia_chi_giao_hang`
	err = db.QueryRow(query, sql.Named("p1", input.CartID)).Scan(&addrCheck, &paymentCheck)
	
	if !addrCheck.Valid || addrCheck.String == "" { sendError(w, 400, "Missing Shipping Address"); return }
	if paymentCheck == 0 { sendError(w, 400, "Missing Payment Method"); return }

	_, err = db.ExecContext(context.Background(), "UPDATE don_hang SET da_dat_hang = 1 WHERE ma_don = @p1", sql.Named("p1", input.CartID))
	if err != nil {
		if strings.Contains(err.Error(), "không đủ hàng") { sendError(w, 409, "Out of Stock: "+err.Error()); return }
		sendError(w, 500, err.Error()); return 
	}
	sendSuccess(w, "Order Placed Successfully", nil)
}

//###########################################
//## 13. ADDRESS: SET FOR ORDER (Snapshot) ##
//###########################################
func set_shipping_address(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var input struct { MaDiaChi int `json:"ma_dia_chi"` }
	if json.NewDecoder(r.Body).Decode(&input) != nil { sendError(w, 400, "Bad JSON"); return }

	_, err := db.ExecContext(context.Background(), "EXEC sp_ChonDiaChiGiaoHang @ma_khach_hang=@p1, @ma_dia_chi=@p2",
		sql.Named("p1", uid), sql.Named("p2", input.MaDiaChi))

	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Address Set for Order", nil)
}

//#####################
//## 14. ADD ADDRESS ##
//#####################
func add_address(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	var i AddressInput
	if json.NewDecoder(r.Body).Decode(&i) != nil { sendError(w, 400, "Bad JSON"); return }
	_, err := db.ExecContext(context.Background(), 
		"INSERT INTO dia_chi_cu_the (ma_khach_hang, thanh_pho, quan_huyen, phuong_xa, dia_chi_nha) VALUES (@p1, @p2, @p3, @p4, @p5)",
		sql.Named("p1", uid), sql.Named("p2", i.ThanhPho), sql.Named("p3", i.QuanHuyen), sql.Named("p4", i.PhuongXa), sql.Named("p5", i.DiaChiNha))
	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Address Added", nil)
}

//##########################
//## 15. GET MY ADDRESSES ##
//##########################
func get_my_addresses(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	rows, err := db.Query("SELECT ma_dia_chi, thanh_pho, quan_huyen, phuong_xa, dia_chi_nha FROM dia_chi_cu_the WHERE ma_khach_hang = @p1", sql.Named("p1", uid))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	var list []AddressRecord
	for rows.Next() {
		var a AddressRecord
		var tp, qh, px, dc sql.NullString
		rows.Scan(&a.MaDiaChi, &tp, &qh, &px, &dc)
		a.ThanhPho = nullToString(tp); a.QuanHuyen = nullToString(qh); 
		a.PhuongXa = nullToString(px); a.DiaChiNha = nullToString(dc)
		list = append(list, a)
	}
	if list == nil { list = []AddressRecord{} }
	json.NewEncoder(w).Encode(list)
}


//##########################################
//## 16. ORDER: CANCEL (Triggers Logic) ####
//##########################################
func cancel_order(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	var input struct { MaDon int `json:"ma_don"` }
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }

	// Logic: User can only cancel if it belongs to them (uid check in SQL)
	query := `UPDATE don_hang SET da_huy = 1 WHERE ma_don = @p1 AND ma_khach_hang = @p2 
		  AND da_dat_hang = 1 AND da_giao_hang = 0 AND da_huy = 0`
	res, err := db.ExecContext(context.Background(), query, sql.Named("p1", input.MaDon), sql.Named("p2", uid))
	if err != nil { sendError(w, 500, err.Error()); return }
	rows, _ := res.RowsAffected()
	if rows == 0 { sendError(w, 400, "Cannot cancel: Order invalid or not yours."); return }
	sendSuccess(w, "Order Cancelled", nil)
}

//########################################
//## 17. ADMIN: UPDATE STATUS (Deliver) ##
//########################################
func update_order_status(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Admin only"); return }
	var input struct { MaDon int `json:"ma_don"`; Status string `json:"status"` }
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }

	if input.Status == "Delivered" {
		_, err := db.ExecContext(context.Background(), "UPDATE don_hang SET da_giao_hang = 1, ngay_du_kien_nhan_hang = GETDATE() WHERE ma_don = @p1", sql.Named("p1", input.MaDon))
		if err != nil { sendError(w, 500, err.Error()); return }
		sendSuccess(w, "Marked as Delivered", nil)
	} else {
		sendError(w, 400, "Unsupported Status")
	}
}


// ############################
// ## 18. GET ORDER HISTORY ###
// ############################
func get_order_history(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	
	rows, err := db.Query("SELECT * FROM fn_LayTatCaDonHang(@p1) ORDER BY stt_don DESC", sql.Named("p1", uid))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	
	var list []OrderHistory
	for rows.Next() {
		var o OrderHistory
		rows.Scan(&o.STT, &o.MaDon, &o.NgayDat, &o.TongTien, &o.TrangThai, &o.TongItems)
		list = append(list, o)
	}
	if list == nil { list = []OrderHistory{} }
	json.NewEncoder(w).Encode(list)
}


//###########################
//## 19. GET ORDER DETAIL ###
//###########################
func get_order_detail(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	
	id := get_id_from_url(r, w); if id == -1 { return } // This is Order ID, not User ID

	// [FIX] Security Check: Does Order belong to UID?
	var owner int
	err := db.QueryRow("SELECT ma_khach_hang FROM don_hang WHERE ma_don = @p1", sql.Named("p1", id)).Scan(&owner)
	if err != nil { sendError(w, 404, "Order Not Found"); return }
	if owner != uid { sendError(w, 403, "Access Denied"); return }

	rows, err := db.Query("SELECT * FROM fn_LayChiTietDonHang(@p1)", sql.Named("p1", id))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	var items []CartItem
	for rows.Next() {
		var i CartItem
		rows.Scan(&i.MaSach, &i.TenSach, &i.HinhThuc, &i.SoLuong, &i.GiaMua, &i.ThanhTien)
		items = append(items, i)
	}
	if items == nil { items = []CartItem{} }
	json.NewEncoder(w).Encode(items)
}

//#########################
//## 20. REGISTER MEMBER ##
//#########################
func register_member(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	var input RegisterInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }
	var nID int
	var dob interface{} = nil; if input.NgaySinh != "" { dob = input.NgaySinh }
	
	err := db.QueryRow("EXEC sp_DangKyThanhVien @ho=@p1, @ho_ten_dem=@p2, @email=@p3, @sdt=@p4, @ten_dang_nhap=@p5, @mat_khau=@p6, @gioi_tinh=@p7, @ngay_sinh=@p8",
		sql.Named("p1", input.Ho), sql.Named("p2", input.HoTenDem), sql.Named("p3", input.Email),
		sql.Named("p4", input.SDT), sql.Named("p5", input.TenDangNhap), sql.Named("p6", input.MatKhau),
		sql.Named("p7", input.GioiTinh), sql.Named("p8", dob)).Scan(&nID)

	if err != nil {
		if strings.Contains(err.Error(), "50030") { sendError(w, 409, "Username taken"); return }
		if strings.Contains(err.Error(), "50031") { sendError(w, 409, "Email taken"); return }
		sendError(w, 500, err.Error()); return
	}
	sendSuccess(w, "Registered", map[string]int{"customer_id": nID})
}

//######################
//## 21. LOGIN MEMBER ##
//######################
func login_member(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	var input LoginInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }
	var id int
	var u, f string
	err := db.QueryRow("EXEC sp_DangNhap @ten_dang_nhap=@p1, @mat_khau=@p2",
		sql.Named("p1", input.TenDangNhap), sql.Named("p2", input.MatKhau)).Scan(&id, &u, &f)
	if err != nil { sendError(w, 404, "User Not Found"); return }
	json.NewEncoder(w).Encode(map[string]string{"token": generate_token(id)})
}

//#########################
//## 22. GET MEMBER INFO ##
//#########################
func get_member_info(w http.ResponseWriter, r *http.Request) {
    if set_CORS_headers(w, r, 1) { return }
    uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
    
    var m MemberInfo
    var nDob sql.NullString
    
    err := db.QueryRow("SELECT * FROM fn_LayThongTinCaNhan(@p1)", sql.Named("p1", uid)).Scan(
        &m.MaKhachHang, &m.HoTen, &m.Email, &m.SDT, &nDob,
        &m.CapDo, &m.DiemTichLuy, &m.TongChiTieu, &m.TenDangNhap)
    
    // [NEW] Handle Guest (No Rows) gracefully
    if err == sql.ErrNoRows { 
        sendError(w, 403, "Guest account has no member profile")
        return 
    }
    if err != nil { sendError(w, 500, err.Error()); return }
    
    m.NgaySinh = nullToString(nDob)
    json.NewEncoder(w).Encode(m)
}

//############################
//## 23. SET PAYMENT METHOD ##
//############################
func set_payment_method(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var input PaymentMethodInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil { sendError(w, 400, "Bad JSON"); return }
	
	// [FIX] Uses 'uid' token
	_, err := db.ExecContext(context.Background(), "EXEC sp_ChonPhuongThucThanhToan @ma_khach_hang=@p1, @hinh_thuc=@p2",
		sql.Named("p1", uid), sql.Named("p2", input.HinhThuc))
	if err != nil { sendError(w, 500, err.Error()); return }
	sendSuccess(w, "Payment Method Set", nil)
}

//#############################
//## 24. GET LAST PAYMENT M. ##
//#############################
func get_last_payment_method(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	var method string
	err := db.QueryRowContext(context.Background(), "EXEC sp_LayThanhToanGanNhat @ma_khach_hang=@p1", sql.Named("p1", uid)).Scan(&method)
	if err == sql.ErrNoRows { sendError(w, 404, "None"); return }
	sendSuccess(w, "Found", map[string]string{"hinh_thuc": method})
}

//#######################
//## 25. APPLY VOUCHER ##
//#######################
func apply_voucher(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }

	var i ApplyVoucherInput
	if json.NewDecoder(r.Body).Decode(&i) != nil { sendError(w, 400, "Bad JSON"); return }
	var discount, eligible float64
	// [FIX] Uses 'uid' token
	err := db.QueryRowContext(context.Background(), "EXEC sp_ApDungVoucherVaoGioHang @ma_khach_hang=@p1, @ma_code=@p2",
		sql.Named("p1", uid), sql.Named("p2", i.MaCode)).Scan(&discount, &eligible)

    if err != nil { 
        if strings.Contains(err.Error(), "50099") { sendError(w, 403, "Guests cannot use member vouchers."); return }
        sendError(w, 500, err.Error()); return
	}



	sendSuccess(w, "Voucher Applied", map[string]float64{"discount_amount": discount, "eligible_total": eligible})
}

//#########################
//## 26. GET MY VOUCHERS ##
//#########################
func get_my_vouchers(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	rows, err := db.Query("SELECT * FROM fn_LayVoucherCuaToi(@p1)", sql.Named("p1", uid))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	var list []UserVoucher
	for rows.Next() {
		var v UserVoucher; var maxD sql.NullFloat64
		rows.Scan(&v.MaVoucher, &v.MaCode, &v.TenVoucher, &v.LoaiGiam, &v.GiaTriGiam, &maxD, &v.NgayHetHan, &v.SoLuong)
		if maxD.Valid { v.GiamToiDa = &maxD.Float64 }
		list = append(list, v)
	}
	if list == nil { list = []UserVoucher{} }
	json.NewEncoder(w).Encode(list)
}

//###########################
//## 27. FIND BEST VOUCHER ##
//###########################
func find_best_voucher(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	var bestCode sql.NullString
	err := db.QueryRow("SELECT dbo.fn_TimVoucherTotNhat(@p1)", sql.Named("p1", uid)).Scan(&bestCode)
	if err != nil { sendError(w, 500, err.Error()); return }
	if bestCode.Valid {
		sendSuccess(w, "Best Deal Found", map[string]string{"voucher_code": bestCode.String, "message": "Calculated optimal savings!"})
	} else {
		sendSuccess(w, "No applicable vouchers", nil)
	}
}

//######################
//## 28. GET NXB BY ID #
//######################
func get_nxb_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }
	var p Publisher; var nE, nD, nS sql.NullString
	err := db.QueryRow("SELECT ma_nxb, ten_nxb, email, dia_chi, sdt FROM nha_xuat_ban WHERE ma_nxb = @p1", sql.Named("p1", id)).Scan(&p.MaNXB, &p.TenNXB, &nE, &nD, &nS)
	if err != nil { sendError(w, 404, "Not Found"); return }
	p.Email = nullToString(nE); p.DiaChi = nullToString(nD); p.SDT = nullToString(nS)
	json.NewEncoder(w).Encode(p)
}

//########################
//## 29. GET PRICE BY ID #
//########################
func get_price_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }
	var pr PriceRecord
	err := db.QueryRow("SELECT ma_gia, ma_sach, gia, FORMAT(ngay_ap_dung, 'yyyy-MM-dd HH:mm:ss') FROM gia_ban WHERE ma_gia = @p1", sql.Named("p1", id)).Scan(&pr.MaGia, &pr.MaSach, &pr.Gia, &pr.NgayApDung)
	if err != nil { sendError(w, 404, "Not Found"); return }
	json.NewEncoder(w).Encode(pr)
}

//####################
//## 30. ADD RATING ##
//####################
func add_rating(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	uid := validate_token(r); if uid == 0 { sendError(w, 401, "Unauthorized"); return }
	var input RatingInput
	if json.NewDecoder(r.Body).Decode(&input) != nil { sendError(w, 400, "Bad JSON"); return }

	_, err := db.ExecContext(context.Background(), "EXEC sp_ThemDanhGia @ma_sach=@p1, @ma_khach_hang=@p2, @so_sao=@p3, @noi_dung=@p4",
		sql.Named("p1", input.MaSach), sql.Named("p2", uid), sql.Named("p3", input.SoSao), sql.Named("p4", input.NoiDung))

    if err != nil {
        if strings.Contains(err.Error(), "50099") { sendError(w, 403, "Guests cannot rate books."); return }
        sendError(w, 500, err.Error()); return 
	}

	sendSuccess(w, "Rating Added", nil)
}

//#############################
//## 31. GET RATINGS BY BOOK ##
//#############################
func get_ratings_by_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }
	rows, err := db.Query("SELECT dg.ma_dg, kh.ho + ' ' + kh.ho_ten_dem, dg.so_sao, dg.noi_dung, FORMAT(dg.ngay_danh_gia, 'yyyy-MM-dd') FROM danh_gia dg JOIN khach_hang kh ON dg.ma_khach_hang = kh.ma_khach_hang WHERE dg.ma_sach = @p1 ORDER BY dg.ngay_danh_gia DESC", sql.Named("p1", id))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	var list []RatingRecord
	for rows.Next() {
		var r RatingRecord
		rows.Scan(&r.MaDG, &r.TenNguoi, &r.SoSao, &r.NoiDung, &r.NgayDanhGia)
		list = append(list, r)
	}
	if list == nil { list = []RatingRecord{} }
	json.NewEncoder(w).Encode(list)
}

//###########################
//## 32. GET RATING BY ID ###
//###########################
func get_rating_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }
	var ratings RatingRecord
	err := db.QueryRow("SELECT dg.ma_dg, kh.ho + ' ' + kh.ho_ten_dem, dg.so_sao, dg.noi_dung, FORMAT(dg.ngay_danh_gia, 'yyyy-MM-dd') FROM danh_gia dg JOIN khach_hang kh ON dg.ma_khach_hang = kh.ma_khach_hang WHERE dg.ma_dg = @p1", sql.Named("p1", id)).Scan(&ratings.MaDG, &ratings.TenNguoi, &ratings.SoSao, &ratings.NoiDung, &ratings.NgayDanhGia)
	if err != nil { sendError(w, 404, "Not Found"); return }
	json.NewEncoder(w).Encode(ratings)
}

//#############################
//## 33. GET BOOKS BY AUTHOR ##
//#############################
func get_books_by_author(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }
	rows, err := db.Query("SELECT * FROM fn_LaySachTheoTacGia(@p1)", sql.Named("p1", id))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	var books []Book
	for rows.Next() {
		var b Book; var nN, nP sql.NullInt64; var nPr sql.NullFloat64
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nN, &nP, &nPr); err == nil {
			b.NamXuatBan=nullToInt(nN); b.SoTrang=nullToInt(nP); b.GiaHienTai=nullToFloat(nPr)
			if b.GiaHienTai == -1 { b.GiaHienTai = 0 }
			books = append(books, b)
		}
	}
	if books == nil { books = []Book{} }
	json.NewEncoder(w).Encode(books)
}

//###############################
//## 34. GET BOOKS BY CATEGORY ##
//###############################
func get_books_by_category(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }
	rows, err := db.Query("SELECT * FROM fn_LaySachTheoTheLoai(@p1)", sql.Named("p1", id))
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()
	var books []Book
	for rows.Next() {
		var b Book; var nN, nP sql.NullInt64; var nPr sql.NullFloat64
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nN, &nP, &nPr); err == nil {
			b.NamXuatBan=nullToInt(nN); b.SoTrang=nullToInt(nP); b.GiaHienTai=nullToFloat(nPr)
			if b.GiaHienTai == -1 { b.GiaHienTai = 0 }
			books = append(books, b)
		}
	}
	if books == nil { books = []Book{} }
	json.NewEncoder(w).Encode(books)
}

// ###############################################
// ## 35. ADMIN: GET ALL ORDERS (To Manage) ######
// ###############################################
func admin_get_all_orders(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Admin only"); return }

    // Logic: Get all orders that are "Placed" (da_dat_hang=1)
    // Sort by Date Descending
	query := `
		SELECT 
            dh.ma_don, 
            kh.email, 
            ISNULL(FORMAT(dh.thoi_diem_dat_hang, 'yyyy-MM-dd HH:mm'), 'N/A'),
            dh.tong_tien_thanh_toan,
            CASE 
                WHEN dh.da_huy = 1 THEN 'Cancelled'
                WHEN dh.da_giao_hang = 1 THEN 'Delivered'
                ELSE 'Processing' 
            END as trang_thai,
            ISNULL(dh.dia_chi_giao_hang, 'N/A')
		FROM don_hang dh
        JOIN khach_hang kh ON dh.ma_khach_hang = kh.ma_khach_hang
		WHERE dh.da_dat_hang = 1
        ORDER BY dh.thoi_diem_dat_hang DESC`

	rows, err := db.Query(query)
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()

	var list []AdminOrderRow
	for rows.Next() {
		var o AdminOrderRow
		rows.Scan(&o.MaDon, &o.KhachHang, &o.NgayDat, &o.TongTien, &o.TrangThai, &o.DiaChi)
		list = append(list, o)
	}
	if list == nil { list = []AdminOrderRow{} }
	json.NewEncoder(w).Encode(list)
}

// ###############################################
// ## 36. ADMIN: RESTOCK BOOK (Add Inventory) ####
// ###############################################
func admin_restock_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }
	if !validate_admin_token(r) { sendError(w, 401, "Admin only"); return }

	var input struct {
        MaSach int `json:"ma_sach"`
        MaKho  int `json:"ma_kho"`
        SoLuongThem int `json:"so_luong_them"`
    }
	if json.NewDecoder(r.Body).Decode(&input) != nil { sendError(w, 400, "Bad JSON"); return }

    // Simple Update: Add stock to existing record
    // Note: sp_ThemSach creates the 0-record, so UPDATE is safe.
    // If you have multiple warehouses, MaKho 1 is usually default.
    query := `UPDATE so_luong_sach_kho 
              SET so_luong_ton = so_luong_ton + @p3 
              WHERE ma_sach = @p1 AND ma_kho = @p2`
     
	res, err := db.ExecContext(context.Background(), query, 
        sql.Named("p1", input.MaSach), 
        sql.Named("p2", input.MaKho), 
        sql.Named("p3", input.SoLuongThem))

	if err != nil { sendError(w, 500, err.Error()); return }
     
    rows, _ := res.RowsAffected()
    if rows == 0 {
        // If row doesn't exist (rare case if sp_ThemSach logic failed), Insert it
        _, err = db.ExecContext(context.Background(), 
            "INSERT INTO so_luong_sach_kho (ma_kho, ma_sach, so_luong_ton) VALUES (@p1, @p2, @p3)",
            sql.Named("p1", input.MaKho), sql.Named("p2", input.MaSach), sql.Named("p3", input.SoLuongThem))
        if err != nil { sendError(w, 500, "Failed to restock: " + err.Error()); return }
    }

	sendSuccess(w, "Inventory Updated", nil)
}

// ###############################################
// ## 37. GUEST: CREATE SESSION (Start Shopping) #
// ###############################################
func create_guest_session(w http.ResponseWriter, r *http.Request) {
    if set_CORS_headers(w, r, 2) { return }

    sessionToken := generate_session_id()
    var newID int
    
    // Database Call
    query := `EXEC sp_TaoSessionKhach @ma_session=@p1, @ma_khach_hang=@pOut OUTPUT`
    _, err := db.ExecContext(context.Background(), query,
        sql.Named("p1", sessionToken),
        sql.Named("pOut", sql.Out{Dest: &newID}))

    if err != nil { sendError(w, 500, "Failed to create guest: "+err.Error()); return }

    // [NEW] Generate JWT for the Guest so they can pass validate_token()
    jwtToken := generate_token(newID)

    sendSuccess(w, "Guest Session Started", map[string]interface{}{
        "token":         jwtToken,
        "customer_id":   newID,
        "session_token": sessionToken,
        "role":          "guest",
    })
}

// ###################################
// ## 39. GET ALL CATEGORIES (Menu) ##
// ###################################
func get_all_categories(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }

	rows, err := db.Query("SELECT ma_tl, ten_tl FROM the_loai ORDER BY ten_tl ASC")
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()

	// Reuse existing IdName struct
	var list []IdName
	for rows.Next() {
		var i IdName
		if err := rows.Scan(&i.ID, &i.Name); err == nil {
			list = append(list, i)
		}
	}
	
	if list == nil { list = []IdName{} }
	json.NewEncoder(w).Encode(list)
}

// ###############################
// ## 40. GET ALL AUTHORS (Menu) #
// ###############################
func get_all_authors(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }

	// Select ID and Name from Author table
	rows, err := db.Query("SELECT ma_tg, ten_tg FROM tac_gia ORDER BY ten_tg ASC")
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()

	var list []IdName
	for rows.Next() {
		var i IdName
		if err := rows.Scan(&i.ID, &i.Name); err == nil {
			list = append(list, i)
		}
	}
	
	if list == nil { list = []IdName{} }
	json.NewEncoder(w).Encode(list)
}

// ###################################
// ## 41. GET BOOK SOLD QUANTITY #####
// ###################################
func get_book_sold_qty(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	id := get_id_from_url(r, w); if id == -1 { return }

	// Logic: Sum quantity from details linked to CONFIRMED and NOT CANCELLED orders
	query := `
		SELECT ISNULL(SUM(ct.so_luong), 0)
		FROM chi_tiet_don_hang ct
		JOIN don_hang dh ON ct.ma_don = dh.ma_don
		WHERE ct.ma_sach = @p1
		  AND dh.da_dat_hang = 1 
		  AND dh.da_huy = 0`

	var soldQty int
	err := db.QueryRow(query, sql.Named("p1", id)).Scan(&soldQty)
	
	if err != nil { sendError(w, 500, err.Error()); return }

	// Direct JSON output: {"tong_da_ban": 120}
	json.NewEncoder(w).Encode(map[string]int{
		"tong_da_ban": soldQty,
	})
}


// ###########################
// ## 42. GET DELETED BOOK ###
// ###########################
func get_deleted_books(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }
	
	// The only difference is WHERE da_xoa = 1
	query := "SELECT ma_sach, ten_sach, nam_xuat_ban, so_trang, gia_hien_tai, so_sao_trung_binh FROM sach WHERE da_xoa = 1"
	
	rows, err := db.Query(query)
	if err != nil { sendError(w, 500, err.Error()); return }
	defer rows.Close()

	var books []Book
	for rows.Next() {
		var b Book
		var nNam, nPage sql.NullInt64
		var nPrice, nStar sql.NullFloat64
		if err := rows.Scan(&b.MaSach, &b.TenSach, &nNam, &nPage, &nPrice, &nStar); err != nil { continue }
		
		b.NamXuatBan = nullToInt(nNam); b.SoTrang = nullToInt(nPage)
		b.GiaHienTai = nullToFloat(nPrice); if b.GiaHienTai == -1 { b.GiaHienTai = 0 }
		b.SoSaoTrungBinh = nullToFloat(nStar); if b.SoSaoTrungBinh == -1 { b.SoSaoTrungBinh = 0 }
		books = append(books, b)
	}
	if books == nil { books = []Book{} }
	json.NewEncoder(w).Encode(books)
}
