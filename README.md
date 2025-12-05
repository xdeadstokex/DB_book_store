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
Note: For Admin Token, copy from terminal. Changes every 5 min.
      Auth mean bearer token is req.

1. BOOKS & SEARCH (Public)
GET  /get_all_books                          [OPEN]
GET  /get_book_by_id?id={id}                 [OPEN]
GET  /search_books?name={x}&author={y}...    [OPEN]
GET  /get_books_by_author?id={id}            [OPEN]
GET  /get_books_by_category?id={id}          [OPEN]
GET  /get_nxb_by_id?id={id}                  [OPEN]
GET  /get_price_by_id?id={id}                [OPEN]

2. ADMIN MANAGEMENT (Header: Authorization: Bearer <AdminToken>)
POST /add_new_book                           [ADMIN]
POST /update_book_info?id={id}               [ADMIN]
POST /change_book_price?id={id}              [ADMIN]
POST /delete_book?id={id}                    [ADMIN]
GET  /admin/get_all_orders                   [ADMIN]
POST /admin/restock_book                     [ADMIN]
POST /update_order_status                    [ADMIN]

3. AUTH & SESSION
POST /register_member                        [OPEN]
POST /login_member                           [OPEN]  -> Returns Member Token
POST /create_guest_session                   [OPEN]  -> Returns Guest Token (REQUIRED for Guest Shopping)
GET  /get_member_info                        [AUTH]  (Member Only - Guest gets 403)
POST /add_address                            [AUTH]
GET  /get_my_addresses                       [AUTH]

4. SHOPPING FLOW (Header: Authorization: Bearer <UserToken>)
Works for both Guests and Members.
POST /add_to_cart                            [AUTH] (ID from Token)
POST /remove_from_cart                       [AUTH] (ID from Token)
POST /update_cart_qty                        [AUTH] (ID from Token)
GET  /get_current_cart                       [AUTH] (ID from Token)
POST /checkout                               [AUTH] (Uses cart_id in JSON)
POST /set_shipping_address                   [AUTH]
POST /set_payment_method                     [AUTH]
POST /cancel_order                           [AUTH]
GET  /get_order_history                      [AUTH]

5. MEMBER EXCLUSIVES (Header: Authorization: Bearer <MemberToken>)
Guests will receive Error 403 or Empty Lists.
POST /apply_voucher                          [AUTH] (Member Only)
GET  /get_my_vouchers                        [AUTH] (Member Only)
GET  /find_best_voucher                      [AUTH] (Member Only)
GET  /get_last_payment_method                [AUTH] (Member Only)
POST /add_rating                             [AUTH] (Member Only)

6. PUBLIC DATA
GET  /get_order_detail?id={oid}              [AUTH] (Checks ownership of Order ID)
GET  /get_ratings_by_book?id={id}            [OPEN]
GET  /get_rating_by_id?id={id}               [OPEN]
```

### DETAILS
```txt
================================================================================
1. PUBLIC READ (BOOKS & SEARCH)
================================================================================
/////////////////////
[GET] /get_all_books
/////////////////////
Logic: Returns list of non-deleted books.
Response:
[
  { "ma_sach": 1, "ten_sach": "A", "nam_xuat_ban": 2020, "so_trang": 100, "gia_hien_tai": 50000 }
]

////////////////////////////////
[GET] /get_book_by_id?id={id}
////////////////////////////////
Logic: Returns full details via `fn_LayChiTietSach`.
Response:
{
  "ma_sach": 1, "ten_sach": "A", "gia_hien_tai": 50000, "so_sao_trung_binh": 4.5,
  "ten_nguoi_dich": "B", "mo_ta": "...", "hinh_thuc": "Soft", "so_trang": 100,
  "nam_xuat_ban": 2020, "ngay_phat_hanh": "2020-01-01", "ten_nxb": "NXB Kim Dong",
  "danh_sach_tac_gia": "Nam Cao", "danh_sach_the_loai": "Novel"
}

///////////////////////////////////////////////////////
[GET] /search_books?name={x}&author={y}&type={z}
///////////////////////////////////////////////////////
Logic: Advanced search. `name` is required. `author` and `type` are optional.
Response:
[
  { "ma_sach": 1, "ten_sach": "A", "gia_hien_tai": 50000, "hinh_thuc": "Soft", "nam_xuat_ban": 2020 }
]

////////////////////////////////
[GET] /get_books_by_author?id={id}
////////////////////////////////
Logic: Lists books by specific author ID. Same format as get_all_books.

////////////////////////////////
[GET] /get_books_by_category?id={id}
////////////////////////////////
Logic: Lists books by specific category ID. Same format as get_all_books.

////////////////////////////////
[GET] /get_nxb_by_id?id={id}
////////////////////////////////
Logic: Publisher details.
Response: { "ma_nxb": 1, "ten_nxb": "Kim Dong", "email": "...", "dia_chi": "...", "sdt": "..." }

////////////////////////////////
[GET] /get_price_by_id?id={id}
////////////////////////////////
Logic: View specific price history record.
Response: { "ma_gia": 10, "ma_sach": 1, "gia": 50000, "ngay_ap_dung": "2025-01-01 10:00:00" }

================================================================================
2. ADMIN OPERATIONS
   * Requires Header: Authorization: Bearer <AdminToken>
================================================================================
/////////////////////
[POST] /add_new_book
/////////////////////
Logic: Inserts Book + Price + Inventory.
Input:
{
  "ten_sach": "New Book Title",
  "nam_xuat_ban": 2024,
  "ma_nxb": 1,
  "so_trang": 300,
  "ngon_ngu": "Tiếng Việt",
  "trong_luong": 250.5,
  "do_tuoi": 16,
  "hinh_thuc": "Bìa Mềm",
  "mo_ta": "Full description...",
  "ten_nguoi_dich": "Nguyen Van A",
  "gia_ban": 150000
}
////////////////////////////////
[POST] /update_book_info?id={id}
////////////////////////////////
Logic: Updates Book metadata.
Input:
{
  "ten_sach": "Updated Title",
  "nam_xuat_ban": 2024,
  "ma_nxb": 1,
  "so_trang": 300,
  "ngon_ngu": "Tiếng Việt",
  "trong_luong": 250.5,
  "do_tuoi": 16,
  "hinh_thuc": "Bìa Mềm",
  "mo_ta": "Updated description...",
  "ten_nguoi_dich": "Nguyen Van B"
}

////////////////////////////////
[POST] /change_book_price?id={id}
////////////////////////////////
Logic: Updates price table.
Input:
{
  "gia_moi": 180000
}

////////////////////////////////
[POST] /delete_book?id={id}
////////////////////////////////
Logic: Soft delete (da_xoa = 1).
Input: {}

///////////////////////////
[GET] /admin/get_all_orders
///////////////////////////
Logic: View all 'placed' orders for processing.
Response:
[
  { "ma_don": 99, "khach_hang": "a@a.com", "ngay_dat": "...", "tong_tien": 500000, "trang_thai": "Processing", "dia_chi": "VN" }
]

///////////////////////////
[POST] /admin/restock_book
///////////////////////////
Logic: Adds stock to warehouse.
Input:
{
  "ma_sach": 1,
  "ma_kho": 1,
  "so_luong_them": 50
}

///////////////////////////
[POST] /update_order_status
///////////////////////////
Logic: Sets order to Delivered.
Input:
{
  "ma_don": 99,
  "status": "Delivered"
}

================================================================================
3. AUTH & USER DATA
================================================================================
///////////////////////
[POST] /register_member
///////////////////////
Logic: Register new user.
Input:
{
  "ho": "Tran",
  "ho_ten_dem": "Van",
  "email": "user@email.com",
  "sdt": "0987654321",
  "ten_dang_nhap": "myuser1",
  "mat_khau": "mypassword",
  "gioi_tinh": "Nam",
  "ngay_sinh": "1995-05-20"
}

////////////////////
[POST] /login_member
////////////////////
Logic: Returns Bearer Token.
Input:
{
  "ten_dang_nhap": "myuser1",
  "mat_khau": "mypassword"
}
Response: { "token": "..." }

/////////////////////
[GET] /get_member_info
/////////////////////
Logic: Returns profile of logged-in user. Header Token required.

////////////////////
[POST] /add_address
////////////////////
Logic: Adds new shipping address. Header Token required.
Input:
{
  "thanh_pho": "Ho Chi Minh",
  "quan_huyen": "Quan 1",
  "phuong_xa": "Ben Nghe",
  "dia_chi_nha": "123 Duong Le Loi"
}

///////////////////////
[GET] /get_my_addresses
///////////////////////
Logic: List all addresses for logged-in user. Header Token required.

////////////////////
[POST] /create_guest_session
////////////////////
Logic: creates temporary guest and returns guest id and token.
Response:
{
  "data": {
    "token": "ey...",
    "customer_id": 6,
    "role": "guest",
    "session_token": "96zzM8vjGD7c_AFl3b5sCQ"
  },
  "message": "Guest Session Started"
}
================================================================================
4. CART & ORDER FLOW
   * Requires Header: Authorization: Bearer <UserToken> (Guest or Member)
================================================================================
////////////////////
[POST] /add_to_cart
////////////////////
Logic: Add item. ID extracted from Token.
Input:
{
  "ma_sach": 5,
  "so_luong": 1
}

/////////////////////////
[POST] /remove_from_cart
/////////////////////////
Logic: Remove item. ID extracted from Token.
Input:
{
  "ma_sach": 5
}

////////////////////////
[POST] /update_cart_qty
////////////////////////
Logic: Change quantity. ID extracted from Token.
Input:
{
  "ma_sach": 5,
  "so_luong": 3
}

//////////////////////
[GET] /get_current_cart
//////////////////////
Logic: Returns Cart + Items + Live Stock/Price Warnings. ID extracted from Token.
Response:
{
  "header": { "ma_don": 100, ... },
  "items": [ ... ],
  "warnings": [ "[LOW_STOCK] Book A: Warehouse has 0 left" ]
}

/////////////////////////////
[POST] /set_shipping_address
/////////////////////////////
Logic: Link address to cart. Header Token required.
Input:
{
  "ma_dia_chi": 101
}

///////////////////////////
[POST] /set_payment_method
///////////////////////////
Logic: Set 'Visa' or 'Shipper'. ID extracted from Token.
Input:
{
  "hinh_thuc": "Visa" // or "Shipper"
}

/////////////////
[POST] /checkout
/////////////////
Logic: Validates Address & Payment exist. Checks Stock. Commits order.
Input:
{
  "cart_id": 555
}

/////////////////////
[POST] /cancel_order
/////////////////////
Logic: Cancel if not shipped. Header Token required.
Input:
{
  "ma_don": 555
}

////////////////////////////////////
[GET] /get_order_history
////////////////////////////////////
Logic: List past orders. ID extracted from Token.
Response:
[
  {
    "stt_don": 2,
    "ma_don": 2,
    "ngay_dat": "2024-02-02T00:00:00Z",
    "tong_tien": 120000,
    "trang_thai": "Đã giao",
    "tong_items": 1
  },
  {
    "stt_don": 1,
    "ma_don": 1,
    "ngay_dat": "2024-01-10T00:00:00Z",
    "tong_tien": 95000,
    "trang_thai": "Đã giao",
    "tong_items": 1
  }
]

================================================================================
5. MEMBER EXCLUSIVES (HISTORY & RATINGS)
   * Requires Header: Authorization: Bearer <MemberToken>
   * Guest Tokens will receive 403 Forbidden
================================================================================
//////////////////////////////
[GET] /get_last_payment_method
//////////////////////////////
Logic: Get last used method.
Response:
{
  "data": {
    "hinh_thuc": "Shipper"
  },
  "message": "Found"
}

//////////////////////
[POST] /apply_voucher
//////////////////////
Logic: Apply code.
Input:
{
  "voucher_code": "SUMMER2025"
}

///////////////////////
[GET] /get_my_vouchers
///////////////////////
Logic: Get owned vouchers.
Response:
[
  {
    "ma_voucher": 1,
    "ma_code": "WELCOME10",
    "ten_voucher": "Giảm 10% Toàn Sàn",
    "loai_giam": "Phần trăm",
    "gia_tri_giam": 10,
    "giam_toi_da": 50000,
    "ngay_het_han": "2025-12-31T00:00:00Z",
    "so_luong": 2
  },
  {
    "ma_voucher": 3,
    "ma_code": "BIGSALE50",
    "ten_voucher": "Giảm 50% (Max 100k)",
    "loai_giam": "Phần trăm",
    "gia_tri_giam": 50,
    "giam_toi_da": 100000,
    "ngay_het_han": "2025-12-31T00:00:00Z",
    "so_luong": 1
  }
]
////////////////////////
[GET] /find_best_voucher
////////////////////////
Logic: Auto-find best code.

/////////////////
[POST] /add_rating
/////////////////
Logic: Review a book.
Input:
{
  "ma_sach": 5,
  "so_sao": 5,
  "noi_dung": "Sach rat hay!"
}

================================================================================
6. PUBLIC DATA (REVIEWS & DETAILS)
================================================================================
////////////////////////////////////
[GET] /get_order_detail?id={order_id}
////////////////////////////////////
Logic: List items in past order. Requires Auth (Ownership check).
Response:
[
  {
    "ma_sach": 1,
    "ten_sach": "Tôi thấy hoa vàng trên cỏ xanh",
    "hinh_thuc": "Bìa mềm",
    "so_luong": 1,
    "gia_mua": 95000,
    "thanh_tien": 95000
  }
]

////////////////////////////////
[GET] /get_ratings_by_book?id={id}
////////////////////////////////
Logic: List reviews.
Response:
[
  {
    "ma_dg": 1,
    "ten_nguoi_dung": "Lê Văn Nam",
    "so_sao": 5,
    "noi_dung": "Sách rất hay, bìa đẹp",
    "ngay_danh_gia": "2024-01-15"
  }
]

//////////////////////////////
[GET] /get_rating_by_id?id={id}
//////////////////////////////
Logic: Get single review.
Response:
{
  "ma_dg": 1,
  "ten_nguoi_dung": "Lê Văn Nam",
  "so_sao": 5,
  "noi_dung": "Sách rất hay, bìa đẹp",
  "ngay_danh_gia": "2024-01-15"
}
```
