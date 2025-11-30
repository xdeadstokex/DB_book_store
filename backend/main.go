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

type Book struct {
	MaSach     int     `json:"ma_sach"`
	TenSach    string  `json:"ten_sach"`
	NamXuatBan int     `json:"nam_xuat_ban"`
	SoTrang    int     `json:"so_trang"`
	GiaHienTai float64 `json:"gia_hien_tai"`
}

type BookDetail struct {
	MaSach     int     `json:"ma_sach"`
	TenSach    string  `json:"ten_sach"`
	NamXuatBan int     `json:"nam_xuat_ban"`
	MaNXB      int     `json:"ma_nxb"`
	SoTrang    int     `json:"so_trang"`
	NgonNgu    string  `json:"ngon_ngu"`
	TrongLuong float64 `json:"trong_luong"`
	DoTuoi     int     `json:"do_tuoi"`
	HinhThuc   string  `json:"hinh_thuc"`
	MoTa       string  `json:"mo_ta"`
	TonKho     int     `json:"ton_kho"`
}

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
	GiaBan     *float64 `json:"gia_ban"`
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
	http.HandleFunc("/delete_book_permanently", delete_book_permanently)
	http.HandleFunc("/create_customer_order", create_customer_order)
}


//######################
//## 1. GET ALL BOOK ###
//######################
func get_all_books(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 1) { return }

	query := `
		SELECT s.ma_sach, s.ten_sach, s.nam_xuat_ban, s.so_trang, ISNULL(gb.gia, 0)
		FROM sach s
		OUTER APPLY (
			SELECT TOP 1 gia FROM gia_ban 
			WHERE ma_sach = s.ma_sach AND den_ngay IS NULL 
			ORDER BY tu_ngay DESC
		) gb
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

	query := `
		SELECT s.ma_sach, s.ten_sach, s.nam_xuat_ban, s.ma_nxb, s.so_trang, 
		       s.ngon_ngu, s.trong_luong, s.do_tuoi, s.hinh_thuc, s.mo_ta,
			   dbo.fn_TinhTongTonKho(s.ma_sach) as ton_kho
		FROM sach s
		WHERE s.ma_sach = @p1
	`
	var b BookDetail
	var nNam, nNXB, nPage, nAge, nStock sql.NullInt64
	var nLang, nForm, nDesc sql.NullString
	var nWeight sql.NullFloat64

	err := db.QueryRow(query, sql.Named("p1", id)).Scan(
		&b.MaSach, &b.TenSach, &nNam, &nNXB, &nPage, 
		&nLang, &nWeight, &nAge, &nForm, &nDesc, &nStock)

	if err == sql.ErrNoRows {
		sendError(w, 404, "Not Found")
		return
	} else if err != nil {
		sendError(w, 500, err.Error())
		return
	}

	b.NamXuatBan = nullToInt(nNam)
	b.MaNXB = nullToInt(nNXB)
	b.SoTrang = nullToInt(nPage)
	b.DoTuoi = nullToInt(nAge)
	b.TonKho = nullToInt(nStock)
	b.NgonNgu = nullToString(nLang)
	b.HinhThuc = nullToString(nForm)
	b.MoTa = nullToString(nDesc)
	b.TrongLuong = nullToFloat(nWeight)

	json.NewEncoder(w).Encode(b)
}


//##################
//## 3. ADD BOOK ###
//##################
func add_new_book(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return } // Flag 2 = POST

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

	var input BookInput
	json.NewDecoder(r.Body).Decode(&input)

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
	sendSuccess(w, "Updated", nil)
}


//#####################
//## 5. DELETE BOOK ###
//#####################
func delete_book_permanently(w http.ResponseWriter, r *http.Request) {
	if set_CORS_headers(w, r, 2) { return }

	idStr := r.URL.Query().Get("id")
	if idStr == "" { sendError(w, 400, "Missing ?id="); return }
	id, _ := strconv.Atoi(idStr)

	force := 0
	if r.URL.Query().Get("force") == "1" { force = 1 }

	_, err := db.ExecContext(context.Background(), 
		"EXEC sp_XoaSach @ma_sach=@p1, @xoa_vinh_vien=@p2",
		sql.Named("p1", id), sql.Named("p2", force))

	if err != nil {
		if strings.Contains(err.Error(), "50021") {
			sendError(w, 409, "Cannot delete: Book is in existing orders")
		} else {
			sendError(w, 500, err.Error())
		}
		return
	}
	sendSuccess(w, "Deleted", nil)
}


//######################
//## 6. CREATE ORDER ###
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
	// BLUNT FIX: triggers block 'OUTPUT inserted.id', so use 'SELECT SCOPE_IDENTITY()'
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
		var price float64
		err = tx.QueryRowContext(ctx, "SELECT TOP 1 gia FROM gia_ban WHERE ma_sach = @p1 AND den_ngay IS NULL ORDER BY tu_ngay DESC", 
			sql.Named("p1", item.MaSach)).Scan(&price)
		
		if err != nil {
			sendError(w, 400, fmt.Sprintf("Book %d invalid or no price", item.MaSach))
			return
		}

		_, err = tx.ExecContext(ctx, `
			INSERT INTO chi_tiet_don_hang (ma_don, ma_sach, gia_ban, so_luong)
			VALUES (@p1, @p2, @p3, @p4)
		`, sql.Named("p1", orderID), sql.Named("p2", item.MaSach), 
		   sql.Named("p3", price), sql.Named("p4", item.SoLuong))

		if err != nil {
			if strings.Contains(err.Error(), "không đủ tồn kho") {
				sendError(w, 409, "Out of Stock: " + err.Error())
			} else {
				sendError(w, 500, "DB Error: " + err.Error())
			}
			return
		}
		totalMoney += price * float64(item.SoLuong)
	}

	_, err = tx.ExecContext(ctx, "UPDATE don_hang SET tong_tien_thanh_toan = @p1 WHERE ma_don = @p2",
		sql.Named("p1", totalMoney), sql.Named("p2", orderID))
	
	if err != nil { sendError(w, 500, "Update Total Failed"); return }

	if err := tx.Commit(); err != nil { sendError(w, 500, "Commit Failed"); return }

	sendSuccess(w, "Order Placed", map[string]interface{}{"order_id": orderID})
}
