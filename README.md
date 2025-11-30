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
    * If you restart the server, SQL throws away unused cached IDs.
    * **Fix:** Run `ALTER DATABASE SCOPED CONFIGURATION SET IDENTITY_CACHE = OFF;` in SQL if you hate it. Otherwise, ignore it.

2.  **NULL Handling:**
    * The database allows NULLs, but the API returns strict types.
    * **Integer fields** (e.g., `nam_xuat_ban`): If NULL, returns `-1`.
    * **String fields** (e.g., `mo_ta`): If NULL, returns `"-1"`.
    * **Float fields** (e.g., `gia_ban`): If NULL, returns `-1`.

3.  **JSON Rules:**
    * **Do not use quotes for numbers.**
    * Right: `"price": 100000`
    * Wrong: `"price": "100000"` (Will cause 400 Bad JSON error).

---

### OVERVIEW
```txt
GET  /get_all_books                              OK
GET  /get_book_by_id?id={id}                     OK
POST /add_new_book                               OK
POST /update_book_info?id={id}                   MEH
POST /delete_book_permanently?id={id}&force=1    MEH
POST /create_customer_order                      MEH
```

### DETAILS

## 1. Get All Books
**URL:** `/get_all_books`

**Method:** `GET`

**Usage:** Fetches a lightweight list for the homepage. Includes calculated current price.

**Response:**
```json
[
  {
    "ma_sach": 1,
    "ten_sach": "Clean Code",
    "nam_xuat_ban": 2008,
    "so_trang": 464,
    "gia_hien_tai": 100000
  },
  {
    "ma_sach": 1002,
    "ten_sach": "The Pragmatic Programmer",
    "nam_xuat_ban": -1,
    "so_trang": 352,
    "gia_hien_tai": 0
  }
]
```

## 2. Get Book Detail
**URL:** /get_book_by_id?id={ID}

**Method:** GET

**Usage:** Fetches full details. Includes real-time inventory count (ton_kho) from all warehouses.

Response:
```json
{
  "ma_sach": 1,
  "ten_sach": "Clean Code",
  "nam_xuat_ban": 2008,
  "ma_nxb": 1,
  "so_trang": 464,
  "ngon_ngu": "English",
  "trong_luong": 0.5,
  "do_tuoi": 18,
  "hinh_thuc": "Hardcover",
  "mo_ta": "Classic book on software craftsmanship",
  "ton_kho": 50
}
```

## 3. Add New Book
**URL:** /add_new_book

**Method:** POST

**Usage:** Calls Stored Procedure sp_ThemSach.

Request Body:
```json
{
    "ten_sach": "Advanced SQL",
    "nam_xuat_ban": 2024,
    "ma_nxb": 1,
    "so_trang": 300,
    "ngon_ngu": "English",
    "gia_ban": 150000.0,
    "trong_luong": 0.5,
    "do_tuoi": 18,
    "hinh_thuc": "Paperback",
    "mo_ta": "Deep dive into SQL Server"
}
```
Common Errors:
```txt
400 Bad Request: Price is too low (< 1000) or Invalid JSON.
409 Conflict: Book with same name/year/publisher already exists.
```

## 4. Update Book Info
**URL:** /update_book_info?id={ID}

**Method:** POST

**Usage:** Calls sp_SuaSach. You can send just one field or all fields.

Request Body (Partial Update Example):
```json
{
    "ten_sach": "Advanced SQL (2nd Edition)",
    "gia_ban": 180000.0
}
```

## 5. Delete Book
**URL:** /delete_book_permanently?id={ID}

**Method:** POST Optional

**Param:** ?force=1 (Allows deleting even if stock exists).

**Usage:**
```txt
Standard: /delete_book_permanently?id=1 -> Fails if stock > 0.
Forced: /delete_book_permanently?id=1&force=1 -> Deletes stock, then book.
Note: Always fails if the book is part of a past Order (Foreign Key constraint).
```

Response:
```json
{ "message": "Book Deleted" }
```

## 6. Create Order
**URL:** /create_customer_order

**Method:** POST

**Usage:** Creates order, adds items, and triggers inventory check.

Request Body:
```json
{
  "customer_id": 1,
  "voucher_id": null,
  "items": [
    { "ma_sach": 1, "so_luong": 2 },
    { "ma_sach": 5, "so_luong": 1 }
  ]
}
```
Responses:
```txt
200 OK: Order success.
409 Conflict: "Out of Stock". The database trigger blocked the order because so_luong_ton was too low.
500 Internal Server Error: Database connection fail or other SQL error.
```
