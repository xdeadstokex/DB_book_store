# Book Store Database Setup

## Overview
- **bookstore_drop.sql**: Reset the database, dropping all tables and data.
- **bookstore_create_tables.sql**: Set up the database and populate it with sample data.
- **bookstore_functions.sql**: Set up all normal func.
- **bookstore_procedures.sql**: Set up all trigger.
- **bookstore_triggers.sql**: Set up all trigger.
- **bookstore_insert_data.sql**: Insert sample data for testing

## FILE RUNNING ORDER:

**the same as overview order**

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
---

### OVERVIEW
```txt
GET  /get_all_books                          OK
GET  /get_book_by_id?id={id}                 OK
GET  /get_books_by_author?id={id}            OK (New)
GET  /get_books_by_category?id={id}          OK (New)

GET  /get_nxb_by_id?id={id}                  OK
GET  /get_price_by_id?id={id}                OK

POST /add_new_book                           OK
POST /update_book_info?id={id}               OK (Meta only, no price)
POST /change_book_price?id={id}              OK (Logs history)
POST /delete_book?id={id}                    OK (Soft delete)

POST /register_member                        OK (New - Auth)
POST /login_member                           OK (New - Returns Token)

POST /add_rating                             OK (New - Requires Token)
GET  /get_ratings_by_book?id={id}            OK (New)
GET  /get_rating_by_id?id={id}               OK (New)

POST /create_customer_order                  OK (Transactional)
```

### DETAILS
```txt
================================================================================
1. READ APIS (BOOKS)
================================================================================
/////////////////////
[GET] /get_all_books
/////////////////////
Logic: Returns summary of ACTIVE books only (da_xoa = 0).
Response:
[
  {
    "ma_sach": 1,
    "ten_sach": "Clean Code",
    "nam_xuat_ban": 2008,
    "so_trang": 464,
    "gia_hien_tai": 150000
  },
  ...
]

////////////////////////////////
[GET] /get_book_by_id?id=1
////////////////////////////////
Logic: Returns FULL specs. Joins with Authors, Categories, and NXB.
Response:
{
  "ma_sach": 1,
  "ten_sach": "Clean Code",
  "gia_hien_tai": 150000,
  "so_sao_trung_binh": 4.5,
  "ten_nguoi_dich": "Nguyen Van A",
  "mo_ta": "Description...",
  "hinh_thuc": "Bìa Mềm",
  "so_trang": 464,
  "nam_xuat_ban": 2008,
  "ngay_phat_hanh": "2008-08-01",
  "ten_nxb": "NXB Tre",
  "danh_sach_tac_gia": "Robert C. Martin",
  "danh_sach_the_loai": "IT, Education"
}

/////////////////////////////////////
[GET] /get_books_by_author?id=10
[GET] /get_books_by_category?id=5
/////////////////////////////////////
Logic: Same output format as /get_all_books, filtered by relation.

================================================================================
2. UTILITY APIS (READ)
================================================================================
//////////////////////////
[GET] /get_nxb_by_id?id=5
//////////////////////////
Logic: Helper to get Publisher details.
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
Logic: Helper to view specific historical price record.
Response:
{
  "ma_gia": 505,
  "ma_sach": 1,
  "gia": 150000,
  "ngay_ap_dung": "2024-01-01 12:00:00"
}

================================================================================
3. AUTH & USER APIS
================================================================================
//////////////////////
[POST] /register_member
//////////////////////
Logic: Creates user. Checks for duplicate Username/Email.
Input:
{
  "ho": "Nguyen",
  "ho_ten_dem": "Van A",
  "email": "a@test.com",
  "sdt": "0909123456",
  "ten_dang_nhap": "user1",
  "mat_khau": "123456",
  "gioi_tinh": "Nam",
  "ngay_sinh": "1999-01-01"
}

//////////////////////
[POST] /login_member
//////////////////////
Logic: Verifies Creds. Returns Signed Bearer Token.
Input:
{
  "ten_dang_nhap": "user1",
  "mat_khau": "123456"
}
Response:
{
  "token": "MTA:17384.signature..."
}

================================================================================
4. WRITE APIS (BOOKS)
================================================================================
/////////////////////
[POST] /add_new_book
/////////////////////
Logic: Creates Book + Price + Inventory(0).
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
  "ten_nguoi_dich": "Translator Name",
  "gia_ban": 50000      // <-- REQUIRED
}

////////////////////////////////
[POST] /update_book_info?id=1
////////////////////////////////
Logic: Updates metadata ONLY.
Input: (Send only fields to change)
{
  "ten_sach": "New Name",
  "ten_nguoi_dich": "New Translator"
}

/////////////////////////////////
[POST] /change_book_price?id=1
/////////////////////////////////
Logic: Updates Price + Logs History.
Input:
{
  "gia_moi": 60000
}

///////////////////////////
[POST] /delete_book?id=1
///////////////////////////
Logic: Soft Delete.
Input: {} (Empty JSON)

================================================================================
5. RATINGS APIS
================================================================================
/////////////////////////
[POST] /add_rating
/////////////////////////
Logic: Adds review. REQUIRES HEADER: "Authorization: Bearer <token>"
Input:
{
  "ma_sach": 1,
  "customer_id": 0, // <--- Ignored, ID comes from Token
  "so_sao": 5,
  "noi_dung": "Good book"
}

////////////////////////////////
[GET] /get_ratings_by_book?id=1
////////////////////////////////
Logic: Lists all reviews for a book.
Response:
[
  { "ma_dg": 10, "ten_nguoi_dung": "A", "so_sao": 5, "noi_dung": "...", "ngay_danh_gia": "..." }
]

================================================================================
6. TRANSACTION APIS
================================================================================
//////////////////////////////
[POST] /create_customer_order
//////////////////////////////
Logic: Locks price snapshot. Fails if out of stock.
Input:
{
  "customer_id": 10,
  "voucher_id": null,
  "items": [
    { "ma_sach": 1, "so_luong": 1 }
  ]
}
```
