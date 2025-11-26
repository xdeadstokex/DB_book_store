package main

import (
"bufio"
"fmt"
"log"
"os"
"strings"

"database/sql"
"encoding/json"
"net/http"

_ "github.com/denisenkom/go-mssqldb"
)




//###################
//## DATA SECTION ###
//###################
type Book struct {
MaSach  int`json:"ma_sach"`
TenSach string `json:"ten_sach"`
NamXuatBan  int`json:"nam_xuat_ban"`
SoTrang int`json:"so_trang"`
}

var db *sql.DB




//###################
//## MAIN SECTION ###
//###################
func main() {
var err error

connection_string, err := read_connection_string("config.txt")
if err != nil { log.Fatalf("Error: %v", err) }


db, err = sql.Open("sqlserver", connection_string)
if err != nil { log.Fatal(err) }
defer db.Close()

if err = db.Ping(); err != nil { log.Fatal(err) }

handle_apis()

log.Println("API running on http://localhost:4444")
log.Fatal(http.ListenAndServe(":4444", nil))
}




//############################
//## HELPER FUNCS SECTION ####
//############################
func read_connection_string(filePath string) (string, error) {
// Open the config file
file, err := os.Open(filePath)
if err != nil {
return "", fmt.Errorf("error opening config file: %v", err)
}
defer file.Close()

// Read the file line by line
scanner := bufio.NewScanner(file)
for scanner.Scan() {
line := scanner.Text()
// Check for the line that contains "CONN_STRING"
if strings.HasPrefix(line, "CONN_STRING=") {
// Return the value after "CONN_STRING="
return strings.TrimPrefix(line, "CONN_STRING="), nil
}
}

// If no connection string is found, return an error
if scanner.Err() != nil {
return "", fmt.Errorf("error reading config file: %v", scanner.Err())
}

return "", fmt.Errorf("connection string not found in config file")
}




func set_CORS_headers(w http.ResponseWriter, flag int){
w.Header().Set("Content-Type", "application/json")
w.Header().Set("Access-Control-Allow-Origin", "*")
w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

var methods string
if flag == 0 { methods = "*"
} else if flag == 1 { methods = "GET"
} else if flag == 2 { methods = "POST"
} else if flag == 3 { methods = "GET, POST"
} else if flag == 4 { methods = "PUT"
} else if flag == 5 { methods = "DELETE"
} else { methods = "GET" // fallback default
}

w.Header().Set("Access-Control-Allow-Methods", methods)
}




//#########################
//## APIS FUNCS SECTION ###
//#########################
// Function to handle registering all the routes
func handle_apis(){
http.HandleFunc("/api/books", get_all_books)  // Handle GET requests to /api/books
}




func get_all_books(w http.ResponseWriter, r *http.Request){
set_CORS_headers(w, 1) // 1 = only GET
log.Println("get all books req")
rows, err := db.Query("SELECT ma_sach, ten_sach, nam_xuat_ban, so_trang FROM sach")

if err != nil {
http.Error(w, err.Error(), 500)
return
}
defer rows.Close()

var books []Book
for rows.Next() {
var b Book
if err := rows.Scan(&b.MaSach, &b.TenSach, &b.NamXuatBan, &b.SoTrang); err != nil {
log.Println("error get all book")
http.Error(w, err.Error(), 500)
return
}
books = append(books, b)
}

json.NewEncoder(w).Encode(books)
}
