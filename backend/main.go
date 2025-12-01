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

	_ "github.com/denisenkom/go-mssqldb"
)

//###################
//## DATA STRUCTS ###
//###################
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
	// --- IDs (Grouped at Top) ---
	MaSach       int `json:"ma_sach"`
	MaNXB        int `json:"ma_nxb"`
	MaGiaHienTai int `json:"ma_gia_hien_tai"` // The specific price ID being used

	// --- Core Info ---
	TenSach        string  `json:"ten_sach"`
	GiaHienTai     float64 `json:"gia_hien_tai"`
	TonKho         int     `json:"ton_kho"`
	DaXoa          bool    `json:"da_xoa"` // useful to know if it's hidden

	// --- Full Specs ---
	NamXuatBan         int     `json:"nam_xuat_ban"`
	SoTrang            int     `json:"so_trang"`
	NgonNgu            string  `json:"ngon_ngu"`
	TrongLuong         float64 `json:"trong_luong"`
	DoTuoi             int     `json:"do_tuoi"`
	HinhThuc           string  `json:"hinh_thuc"`
	KichThuocBaoBi     string  `json:"kich_thuoc_bao_bi"`
	NhaCungCap         string  `json:"nha_cung_cap"`
	SoSaoTrungBinh     float64 `json:"so_sao_trung_binh"`
	NgayDuKienCoHang   string  `json:"ngay_du_kien_co_hang"`   // "yyyy-mm-dd"
	NgayDuKienPhatHanh string  `json:"ngay_du_kien_phat_hanh"` // "yyyy-mm-dd"
	MoTa               string  `json:"mo_ta"`
}

// Input for creating a book (Price required)
type BookInput struct {
	TenSach    string   `json:"ten_sach"`
	NamXuatBan int      `json:"nam_xuat_ban"`
	MaNXB      int      `json:"ma_nxb"`
	SoTrang    int      `json:"so_trang"`
	NgonNgu    string   `json:"ngon_ngu"`
	TrongLuong *float64 `json:"trong_luong"`
	DoTuoi     *int     `json:"do_tuoi"`
	HinhThuc   *string  `json:"hinh_thuc"`
	MoTa       *string  `json:"mo_ta"`
	GiaBan     float64  `json:"gia_ban"`
}

// Input for updating info (No Price)
type BookUpdateInput struct {
	TenSach    *string  `json:"ten_sach"`
	NamXuatBan *int     `json:"nam_xuat_ban"`
	MaNXB      *int     `json:"ma_nxb"`
	SoTrang    *int     `json:"so_trang"`
	NgonNgu    *string  `json:"ngon_ngu"`
	TrongLuong *float64 `json:"trong_luong"`
	DoTuoi     *int     `json:"do_tuoi"`
	HinhThuc   *string  `json:"hinh_thuc"`
	MoTa       *string  `json:"mo_ta"`
}

// Input for changing price
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

var db *sql.DB

//###################
//## MAIN SECTION ###
//###################
func main() {
	var err error
	connStr, err := read_connection_string("config.txt")
	if err != nil { log.Fatalf("Config Error: %v", err) }

	db, err = sql.Open("sqlserver", connStr)
	if err != nil { log.Fatal(err) }
	defer db.Close()

	if err = db.Ping(); err != nil { log.Fatal(err) }

	handle_apis()

	log.Println("OK! API running on http://localhost:4444")
	log.Fatal(http.ListenAndServe(":4444", nil))
}

//############################
//## HELPER FUNCS SECTION ####
//############################
func nullToInt(n sql.NullInt64) int {
	if !n.Valid { return -1 }
	return int(n.Int64)
}
func nullToString(n sql.NullString) string {
	if !n.Valid { return "-1" }
	return n.String
}
func nullToFloat(n sql.NullFloat64) float64 {
	if !n.Valid { return -1.0 }
	return n.Float64
}

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

// Returns TRUE if the request was handled (OPTIONS), so the caller should return.
func set_CORS_headers(w http.ResponseWriter, r *http.Request, flag int) bool {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	var methods string
	if flag == 0 { methods = "*";
	} else if flag == 1 { methods = "GET"
	} else if flag == 2 { methods = "POST"
	} else if flag == 3 { methods = "GET, POST"
	} else if flag == 4 { methods = "PUT"
	} else if flag == 5 { methods = "DELETE"
	} else { methods = "GET" // fallback default
	}

	w.Header().Set("Access-Control-Allow-Methods", methods)

	if (r.Method == "OPTIONS") { w.WriteHeader(http.StatusOK); return true; }
	return false;
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

//#########################
//## APIS FUNCS SECTION ###
//#########################
func handle_apis() {
	http.HandleFunc("/get_all_books", get_all_books)
	http.HandleFunc("/get_book_by_id", get_book_by_id)
	http.HandleFunc("/add_new_book", add_new_book)
	http.HandleFunc("/update_book_info", update_book_info)
	http.HandleFunc("/change_book_price", change_book_price)
	http.HandleFunc("/delete_book", delete_book)
	http.HandleFunc("/create_customer_order", create_customer_order)
	http.HandleFunc("/get_nxb_by_id", get_nxb_by_id)
	http.HandleFunc("/get_price_by_id", get_price_by_id)
}

//######################
//## 1. GET ALL BOOK ###
//######################
func get_all_books(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }

	// REVISED: Query 'sach' directly (O(1) Cache) & filter Soft Delete
	query := `
		SELECT ma_sach, ten_sach, nam_xuat_ban, so_trang, gia_hien_tai
		FROM sach 
		WHERE da_xoa = 0
	`
	rows, err := db.Query(query)
	if err != nil { sendError(w, 500, err.Error()); return }
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
		if b.GiaHienTai == -1 { b.GiaHienTai = 0 }
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

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	// QUERY: We explicitly select EVERY column. 
	// We use FORMAT() for dates to get simple strings (YYYY-MM-DD) or NULL.
	query := `
		SELECT 
			-- IDs
			s.ma_sach, s.ma_nxb, s.ma_gia_hien_tai,
			-- Core
			s.ten_sach, s.gia_hien_tai, s.da_xoa,
			-- Specs
			s.nam_xuat_ban, s.so_trang, s.ngon_ngu, s.trong_luong, s.do_tuoi, 
			s.hinh_thuc, s.kich_thuoc_bao_bi, s.nha_cung_cap, s.so_sao_trung_binh, s.mo_ta,
			-- Dates
			FORMAT(s.ngay_du_kien_co_hang, 'yyyy-MM-dd'),
			FORMAT(s.ngay_du_kien_phat_hanh, 'yyyy-MM-dd'),
			-- Calc
			(SELECT ISNULL(SUM(so_luong_ton),0) FROM so_luong_sach_kho WHERE ma_sach = s.ma_sach) as ton_kho
		FROM sach s
		WHERE s.ma_sach = @p1
	`
	
	// Prepare Nullable variables for SQL Scan
	var b BookDetail
	var nMaNXB, nMaGia, nNam, nPage, nAge, nStock sql.NullInt64
	var nPrice, nWeight, nStars sql.NullFloat64
	var nLang, nForm, nSize, nSupplier, nDesc, nDate1, nDate2 sql.NullString
	
	// Note: 'da_xoa' (BIT) usually scans directly to bool, no NullBool needed if column is NOT NULL default
	
	err := db.QueryRow(query, sql.Named("p1", id)).Scan(
		// IDs
		&b.MaSach, &nMaNXB, &nMaGia,
		// Core
		&b.TenSach, &nPrice, &b.DaXoa,
		// Specs
		&nNam, &nPage, &nLang, &nWeight, &nAge,
		&nForm, &nSize, &nSupplier, &nStars, &nDesc,
		// Dates
		&nDate1, &nDate2,
		// Calc
		&nStock,
	)

	if err == sql.ErrNoRows {
		sendError(w, 404, "Not Found")
		return
	} else if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	// Map Nullables to Struct
	b.MaNXB = nullToInt(nMaNXB)
	b.MaGiaHienTai = nullToInt(nMaGia)
	b.GiaHienTai = nullToFloat(nPrice)
	b.NamXuatBan = nullToInt(nNam)
	b.SoTrang = nullToInt(nPage)
	b.NgonNgu = nullToString(nLang)
	b.TrongLuong = nullToFloat(nWeight)
	b.DoTuoi = nullToInt(nAge)
	b.HinhThuc = nullToString(nForm)
	b.KichThuocBaoBi = nullToString(nSize)
	b.NhaCungCap = nullToString(nSupplier)
	b.SoSaoTrungBinh = nullToFloat(nStars)
	b.MoTa = nullToString(nDesc)
	b.NgayDuKienCoHang = nullToString(nDate1)
	b.NgayDuKienPhatHanh = nullToString(nDate2)
	b.TonKho = nullToInt(nStock)

	json.NewEncoder(w).Encode(b)
}


//##################
//## 3. ADD BOOK ###
//##################
func add_new_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return } 

	var input BookInput
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		sendError(w, 400, "Invalid JSON: "+err.Error())
		return
	}

	var newID int
	// REVISED: Calls sp_ThemSach (Handles Book + Price History + Link)
	query := `
		EXEC sp_ThemSach 
		@ten_sach=@p1, @nam_xuat_ban=@p2, @ma_nxb=@p3, @so_trang=@p4, 
		@ngon_ngu=@p5, @trong_luong=@p6, @do_tuoi=@p7, @hinh_thuc=@p8, 
		@mo_ta=@p9, @gia_ban=@p10, @ma_sach_moi=@pOut OUTPUT
	`
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("p1", input.TenSach), sql.Named("p2", input.NamXuatBan),
		sql.Named("p3", input.MaNXB), sql.Named("p4", input.SoTrang),
		sql.Named("p5", input.NgonNgu), sql.Named("p6", input.TrongLuong),
		sql.Named("p7", input.DoTuoi), sql.Named("p8", input.HinhThuc),
		sql.Named("p9", input.MoTa), sql.Named("p10", input.GiaBan),
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
	if set_CORS_headers(w, r, 2) { return }

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	var input BookUpdateInput
	json.NewDecoder(r.Body).Decode(&input)

	// REVISED: Calls sp_SuaSach (Does NOT touch Price)
	query := `
		EXEC sp_SuaSach @ma_sach=@pid, @ten_sach=@p1, @nam_xuat_ban=@p2, 
		@ma_nxb=@p3, @so_trang=@p4, @ngon_ngu=@p5, @trong_luong=@p6, 
		@do_tuoi=@p7, @hinh_thuc=@p8, @mo_ta=@p9
	`
	_, err := db.ExecContext(context.Background(), query,
		sql.Named("pid", id), sql.Named("p1", input.TenSach),
		sql.Named("p2", input.NamXuatBan), sql.Named("p3", input.MaNXB),
		sql.Named("p4", input.SoTrang), sql.Named("p5", input.NgonNgu),
		sql.Named("p6", input.TrongLuong), sql.Named("p7", input.DoTuoi),
		sql.Named("p8", input.HinhThuc), sql.Named("p9", input.MoTa),
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
	if set_CORS_headers(w, r, 2) { return } // POST

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	var input PriceUpdateInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Invalid JSON")
		return
	}

	// REVISED: New Procedure handling History Log + Cache Update
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
	if set_CORS_headers(w, r, 2) { return } // POST/DELETE

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	// REVISED: Calls sp_XoaSach (Soft Delete)
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
	if set_CORS_headers(w, r, 2) { return }

	var input OrderInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		sendError(w, 400, "Bad JSON")
		return
	}

	ctx := context.Background()
	tx, err := db.BeginTx(ctx, nil)
	if err != nil { sendError(w, 500, "Tx Start Error"); return }
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

		// REVISED: Fetch Price AND Price ID from 'sach' (Cache)
		// This ID (ma_gia_hien_tai) is what we lock into the order
		err = tx.QueryRowContext(ctx, 
			`SELECT gia_hien_tai, ma_gia_hien_tai 
			 FROM sach WHERE ma_sach = @p1 AND da_xoa = 0`, 
			sql.Named("p1", item.MaSach)).Scan(&currentPrice, &currentPriceID)
		
		if err != nil {
			sendError(w, 400, fmt.Sprintf("Book %d invalid or deleted", item.MaSach))
			return
		}

		// Insert with ma_gia to freeze history
		_, err = tx.ExecContext(ctx, `
			INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, ma_gia, gia_ban, so_luong)
			VALUES (@p1, @p2, @p3, @p4, @p5)
		`, sql.Named("p1", orderID), sql.Named("p2", item.MaSach), 
		   sql.Named("p3", currentPriceID), // <-- The Logic Fix
		   sql.Named("p4", currentPrice), 
		   sql.Named("p5", item.SoLuong))

		if err != nil {
			if strings.Contains(err.Error(), "không đủ tồn kho") {
				sendError(w, 409, "Out of Stock: " + err.Error())
			} else {
				sendError(w, 500, "DB Error: " + err.Error())
			}
			return
		}
		totalMoney += currentPrice * float64(item.SoLuong)
	}

	_, err = tx.ExecContext(ctx, "UPDATE don_hang SET tong_tien_thanh_toan = @p1 WHERE ma_don = @p2",
		sql.Named("p1", totalMoney), sql.Named("p2", orderID))
	
	if err != nil { sendError(w, 500, "Update Total Failed"); return }

	if err := tx.Commit(); err != nil { sendError(w, 500, "Commit Failed"); return }

	sendSuccess(w, "Order Placed", map[string]interface{}{"order_id": orderID})
}

//#######################
//## 8. GET NXB BY ID ###
//#######################
func get_nxb_by_id(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	query := `SELECT ma_nxb, ten_nxb, email, dia_chi, sdt FROM nha_xuat_ban WHERE ma_nxb = @p1`
	
	var p Publisher
	var nEmail, nDiaChi, nSDT sql.NullString // Handle potential nulls

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
	if set_CORS_headers(w, r, 1) { return }

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	// We format the date in SQL so Go doesn't have to parse it
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
