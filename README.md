# Book Store Database Setup

## Overview
- **bookstore_drop.sql**: Reset the database, dropping all tables and data.
- **bookstore_create_tables.sql**: Set up the database and populate it with sample data.
- **bookstore_functions.sql**: Set up all normal func.
- **bookstore_functions_cursor.sql**: Set up cursor func.
- **bookstore_procedures.sql**: Set up all trigger.
- **bookstore_triggers.sql**: Set up all trigger.
- **bookstore_insert_data.sql**: Insert sample data for testing

## FILE RUNNING ORDER:
<p style="margin-left: 40px;">
  <img src="resource/running_order.png">
</p>

## DB OVERVIEW:
<p style="margin-left: 40px;">
  <img src="resource/table_overview.png">
</p>

## FOR BOTH FRONTEND AND BACKEND:
- 1/ YOU MUST CREATE DB FIRST, MEAN DO AS ABOVE (OR IF WANT FAST TEST CAN DO **create_tables** and
**insert_data** ONLY).

- 2/ for sql server management studio user, MUST open TCP connection for backend to connect.
<p style="margin-left: 40px;">
  <img src="resource/open_TCP_connection.jpeg">
</p>

- 3/ dev backend and frontend as guided in how_to_run.txt in both backend and frontend folder.

# APIS FOR WEB

**Base URL:** `http://localhost:4444`

---

### Important Notes

1.  **Book IDs Jumping (1 -> 1000):**
    * This is **not a bug**. It is SQL Server's "Identity Caching".
    * *Fix:* Run `ALTER DATABASE SCOPED CONFIGURATION SET IDENTITY_CACHE = OFF;` if it annoys you. Otherwise, ignore it.

2.  **NULL Handling:**
    * The database allows NULLs, but this API returns "Sentinel Values" instead of null.
    * **Integer fields** (e.g., `nam_xuat_ban`): Returns `-1`.
    * **String fields** (e.g., `mo_ta`): Returns `"-1"`.
    * **Float fields** (e.g., `trong_luong`): Returns `-1`.

3.  **JSON Rules:**
    * **Strict Types:** Do not quote numbers.
    * Right: `"gia_ban": 100000`
    * Wrong: `"gia_ban": "100000"` (Will cause 400 Bad Request).

[!] RULES FOR FRONTEND DEV:
1.  **PRICES (READ):** Prices are "Cached" in the Book object (`gia_hien_tai`). 
    Always trust this field. Do not try to calculate price from history or joins.

2.  **PRICES (WRITE):** You CANNOT update price via `/update_book_info`. 
    The backend will ignore it. You MUST use `/change_book_price`.

3.  **DELETE:** Deleting is a "Soft Delete" (`da_xoa = 1`).
    * The book vanishes from the main list.
    * Old orders still link to it safely.
    * You can still fetch it via ID, but `da_xoa` will be `true`.

4.  **IDS:** All ID fields (`ma_sach`, `ma_nxb`, `ma_gia_hien_tai`) are grouped at the top of the JSON object.

---

### OVERVIEW
```txt
GET  /get_all_books                          OK
GET  /get_book_by_id?id={id}                 OK
GET  /get_nxb_by_id?id={id}                  OK  (New)
GET  /get_price_by_id?id={id}                OK  (New)

POST /add_new_book                           OK
POST /update_book_info?id={id}               OK  (No longer updates price)
POST /change_book_price?id={id}              OK  (New - Handles history log)
POST /delete_book?id={id}                    OK  (Renamed - Soft delete)

POST /create_customer_order                  OK  (Fixed - Locks price history)
```

### DETAILS
```txt
================================================================================
1. READ APIS (GET)
================================================================================
/////////////////////
[GET] /get_all_books
/////////////////////
Logic: Returns summary of ACTIVE books only (da_xoa = 0).
Response:
[
  {
    "ma_sach": 101,
    "ten_sach": "Pro Go Coding",
    "nam_xuat_ban": 2024,
    "so_trang": 300,
    "gia_hien_tai": 150000
  },
  ...
]


//////////////////////////////
[GET] /get_book_by_id?id=101
//////////////////////////////
Logic: Returns FULL specs for editing/details. Includes total inventory count. (get id from get_all_books response)
Response:
{
  "ma_sach": 101,          // <-- IDs at top
  "ma_nxb": 5,
  "ma_gia_hien_tai": 505,
  
  "ten_sach": "Pro Go Coding",
  "gia_hien_tai": 150000,
  "ton_kho": 42,           // Calculated from all warehouses
  "da_xoa": false,

  "nam_xuat_ban": 2024,
  "so_trang": 300,
  "ngon_ngu": "Tiếng Việt",
  "trong_luong": 500.5,
  "do_tuoi": 16,
  "hinh_thuc": "Bìa Mềm",
  "kich_thuoc_bao_bi": "20x30cm",
  "nha_cung_cap": "Alpha Books",
  "so_sao_trung_binh": 4.5,
  "ngay_du_kien_co_hang": "2024-01-01",
  "ngay_du_kien_phat_hanh": "2024-01-05",
  "mo_ta": "Description text..."
}


//////////////////////////
[GET] /get_nxb_by_id?id=5
//////////////////////////
Logic: Helper to get Publisher name from ID. (get id from get_book_by_id response)
Response:
{
  "ma_nxb": 5,
  "ten_nxb": "Kim Dong",
  "email": "contact@kimdong.com",
  "dia_chi": "Hanoi",
  "sdt": "09090909"
}


//////////////////////////////
[GET] /get_price_by_id?id=505
//////////////////////////////
Logic: Helper to view historical price record. (get id from get_book_by_id response)
Response:
{
  "ma_gia": 505,
  "ma_sach": 101,
  "gia": 150000,
  "ngay_ap_dung": "2024-01-01 12:00:00"
}

================================================================================
2. WRITE APIS (POST)
================================================================================
/////////////////////
[POST] /add_new_book
/////////////////////
Logic: Creates Book + First Price Entry + Inventory(0).
Input:
{
  "ten_sach": "New Book",
  "nam_xuat_ban": 2025,
  "ma_nxb": 1,
  "so_trang": 100,
  "ngon_ngu": "English",
  "trong_luong": 200.0,
  "do_tuoi": 12,
  "hinh_thuc": "Bìa Cứng",
  "mo_ta": "Desc...",
  "gia_ban": 50000     // <--- REQUIRED
}


////////////////////////////////
[POST] /update_book_info?id=101
////////////////////////////////
Logic: Updates metadata ONLY. You CANNOT update price here.
Input: (Send only fields to change)
{
  "ten_sach": "New Name",
  "so_trang": 120
}


/////////////////////////////////
[POST] /change_book_price?id=101
/////////////////////////////////
Logic: Updates Price + Logs History + Updates Cache.
Input:
{
  "gia_moi": 60000
}


///////////////////////////
[POST] /delete_book?id=101
///////////////////////////
Logic: Soft Delete. Sets 'da_xoa' = 1.
Input: {} (Empty JSON)

================================================================================
3. TRANSACTION APIS (POST)
================================================================================
//////////////////////////////
[POST] /create_customer_order
//////////////////////////////
Logic:
1. Creates Order Header.
2. Locks the CURRENT price ID (ma_gia_hien_tai) into the Order Detail.
3. Updates Total.
Note: Will fail (409) if out of stock.

Input:
{
  "customer_id": 10,
  "voucher_id": null,
  "items": [
    { "ma_sach": 101, "so_luong": 1 },
    { "ma_sach": 102, "so_luong": 2 }
  ]
}

Response:
{
  "message": "Order Placed",
  "data": { "order_id": 5001 }
}

================================================================================
ERROR CODES
================================================================================
200: OK
400: Bad Request (Missing ID, Invalid JSON, Price < 0)
404: Not Found (Book ID invalid)
409: Conflict (Out of Stock, or attempting to hard-delete ordered book)
500: Server Error (SQL Exploded)
```
