const API = {
    url: "http://localhost:4444",
    sampleCount: 5,

    init: async () => {
        try {
            const res = await fetch('resource/sample_count');
            if (res.ok) API.sampleCount = parseInt(await res.text()) || 5;
        } catch (e) {}
    },

    randomImg: (id) => `resource/sample_${(id % API.sampleCount) + 1}.jpg`,

    req: async (method, path, body = null) => {
        const headers = { "Content-Type": "application/json" };
        const token = localStorage.getItem("token");
        if (token) headers["Authorization"] = "Bearer " + token;
        try {
            const opts = { method, headers };
            if (body) {
                if (method === "GET") {
                    const clean = {};
                    for (const k in body) if (body[k]) clean[k] = body[k];
                    path += "?" + new URLSearchParams(clean).toString();
                } else opts.body = JSON.stringify(body);
            }
            const res = await fetch(API.url + path, opts);
            const data = await res.json();
            if (!res.ok) throw new Error(data.error || "Request Failed");
            return data;
        } catch (e) {
            console.error(e);
            throw e;
        }
    },

    fmtMoney: (n) => new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(n),

    // --- DATA ENDPOINTS ---
    call_get_books: () => API.req("GET", "/get_all_books"), //
    call_search: (name, author, type) => API.req("GET", "/search_books", { name, author, type }), //
    call_get_book: (id) => API.req("GET", "/get_book_by_id", { id }), //
    call_books_by_author: (id) => API.req("GET", "/get_books_by_author", { id }), //
    call_books_by_category: (id) => API.req("GET", "/get_books_by_category", { id }), //
    call_all_authors: () => API.req("GET", "/get_all_authors"), //
    call_all_categories: () => API.req("GET", "/get_all_categories"), //
    call_get_sold_qty: (id) => API.req("GET", "/get_book_sold_qty", { id }), //
    
    call_get_cart: () => API.req("GET", "/get_current_cart"), //
    call_add_cart: (m, q) => API.req("POST", "/add_to_cart", { ma_sach: parseInt(m), so_luong: parseInt(q) }), //
    call_remove_cart: (m) => API.req("POST", "/remove_from_cart", { ma_sach: parseInt(m) }), //
    call_update_cart: (m, q) => API.req("POST", "/update_cart_qty", { ma_sach: parseInt(m), so_luong: parseInt(q) }), //
    call_checkout: (id) => API.req("POST", "/checkout", { cart_id: parseInt(id) }), //
    call_order_history: () => API.req("GET", "/get_order_history"), //
	call_order_detail: (id) => API.req("GET", "/get_order_detail", { id }),
    call_cancel_order: (id) => API.req("POST", "/cancel_order", { ma_don: parseInt(id) }), //
    call_login: (u, p) => API.req("POST", "/login_member", { ten_dang_nhap: u, mat_khau: p }), //
    call_register: (d) => API.req("POST", "/register_member", d), //
    call_me: () => API.req("GET", "/get_member_info"), //
    call_get_addr: () => API.req("GET", "/get_my_addresses"), //
    call_add_addr: (d) => API.req("POST", "/add_address", d), //
    call_set_addr: (id) => API.req("POST", "/set_shipping_address", { ma_dia_chi: parseInt(id) }), //
    call_set_payment: (m) => API.req("POST", "/set_payment_method", { hinh_thuc: m }), //
    call_get_ratings: (id) => API.req("GET", "/get_ratings_by_book", { id }), //
    call_add_rating: (id, s, c) => API.req("POST", "/add_rating", { ma_sach: parseInt(id), so_sao: parseInt(s), noi_dung: c }), //
    call_my_vouchers: () => API.req("GET", "/get_my_vouchers"), //
	call_apply_voucher: (code) => API.req("POST", "/apply_voucher", { voucher_code: code }),
	call_find_best_voucher: () => API.req("GET", "/find_best_voucher"),
	call_guest: async () => {
		const res = await API.req("POST", "/create_guest_session");
		return res.data;
	},
    // --- HTML GENERATORS ---

    html_book_list: (list) => {
        if (!list || !list.length) return "<p style='padding:20px; text-align:center; width:100%'>No books found.</p>";
        return list.map(b => `
            <div class="card">
                <div class="card-img-wrapper">
                    <img src="${API.randomImg(b.ma_sach)}" alt="${b.ten_sach}">
                </div>
                <div class="card-body">
                    <div style="font-weight:bold; height:45px; overflow:hidden;">${b.ten_sach}</div>
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                        <div class="price">${API.fmtMoney(b.gia_hien_tai)}</div>
                        <div style="font-size:0.9rem; color: #f5a623;">★ ${b.so_sao_trung_binh || 0}</div>
                    </div>
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; color: var(--text-muted); margin-bottom:5px;">
                        <span>${b.nam_xuat_ban} | ${b.so_trang} p</span>
                        <span id="sold-${b.ma_sach}">...</span>
                    </div>
                    <div class="mt" style="display:flex; gap:5px;">
                        <button class="btn-green" onclick="SITE.add(${b.ma_sach})">Buy</button>
                        <button class="btn-outline" onclick="DETAIL.open(${b.ma_sach})">Details</button>
                    </div>
                </div>
            </div>
        `).join("");
    },

    html_book_detail: (b, ratings, soldQty = 0) => {
        const authors = (b.danh_sach_tac_gia || []).map(a => `<span class="interact-tag" onclick="DETAIL.redirectToAuthor(${a.id}, '${a.name.replace(/'/g, "\\'")}')">${a.name}</span>`).join(" ");
        const cats = (b.danh_sach_the_loai || []).map(c => `<span class="interact-tag" onclick="DETAIL.redirectToCategory(${c.id}, '${c.name.replace(/'/g, "\\'")}')">${c.name}</span>`).join(" ");
        const reviews = (ratings || []).length ? ratings.map(r => `<div class="review-item"><div class="review-user"><span>${r.ten_nguoi_dung}</span><span class="review-stars">${'★'.repeat(r.so_sao)}</span></div><div class="review-content">${r.noi_dung}</div></div>`).join("") : `<p style="font-style:italic; color:#aaa; margin-top:10px;">No reviews yet.</p>`;
        const pubName = b.nha_xuat_ban ? b.nha_xuat_ban.name : "Unknown";
        const specs = [{ label: "Translator", val: b.ten_nguoi_dich }, { label: "Format", val: b.hinh_thuc }, { label: "Pages", val: b.so_trang }, { label: "Year", val: b.nam_xuat_ban }, { label: "Released", val: b.ngay_phat_hanh }, { label: "Age", val: b.do_tuoi ? `${b.do_tuoi}+` : null }].filter(item => item.val != null && item.val !== "");
        const specsHtml = specs.map(s => `<div style="font-size:0.85rem; color:var(--text-muted); margin-bottom:2px;"><span style="font-weight:bold; color:var(--primary);">${s.label}:</span> ${s.val}</div>`).join("");

        return `
            <div class="detail-wrapper">
                <div class="detail-header">
                    <h2 class="detail-title">${b.ten_sach}</h2>
                    <div class="detail-meta"><span class="meta-label">By:</span> ${authors || "Unknown"}<span class="meta-label" style="margin-left:10px">In:</span> ${cats || "General"}</div>
                </div>
                <div class="detail-content-row">
                    <div class="detail-img-box"><img src="${API.randomImg(b.ma_sach)}" class="detail-cover"></div>
                    <div class="detail-info-box">
                        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
                            <div class="detail-price">${API.fmtMoney(b.gia_hien_tai)}</div>
                            <div style="color:var(--primary); font-weight:bold;">Sold: ${soldQty}</div>
                        </div>
                        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:5px; margin-bottom:15px; padding-bottom:10px; border-bottom:1px solid rgba(255,255,255,0.1);">
                            <div><span style="font-weight:bold; color:var(--primary);">Pub:</span> ${pubName}</div>
                            <div><span style="font-weight:bold; color:var(--primary);">Rating:</span> ${b.so_sao_trung_binh} ★</div>
                            ${specsHtml}
                        </div>
                        <div class="detail-desc">${b.mo_ta || "No description."}</div>
                        <div class="detail-actions">
                            <button class="btn-green" onclick="SITE.add(${b.ma_sach})">Add to Cart</button>
                            <button class="btn-outline" onclick="DETAIL.rate(${b.ma_sach})">Review</button>
                        </div>
                    </div>
                </div>
                <div class="detail-reviews"><h3>Reviews</h3><div class="review-list-container">${reviews}</div></div>
            </div>`;
    },

html_cart_view: (res) => { 
    if (!res || res.message === "Cart Empty" || !res.data || !res.data.items.length) { 
        return `<div style="text-align:center; padding:40px;"><h3>Cart Empty</h3><button class="btn-primary" onclick="SITE.closeModal()">Shop</button></div>`; 
    } 
    const h = res.data.header; 
    const discount = res.data.discount || 0;
    
    const grid = res.data.items.map(i => `<div class="card"><div class="card-img-wrapper" style="height:140px;"><img src="${API.randomImg(i.ma_sach)}"></div><div class="card-body"><div style="font-weight:bold; height:40px; overflow:hidden;">${i.ten_sach}</div><div style="font-size:0.85rem; color:var(--text-muted);">Price: ${API.fmtMoney(i.gia_mua)}</div><div class="mt" style="border-top:1px solid var(--border); padding-top:10px; margin-top:auto;"><div style="display:flex; justify-content:space-between; margin-bottom:5px;"><label>Qty:</label> <input type="number" value="${i.so_luong}" style="width:50px" onchange="CART.update(${i.ma_sach}, this.value)"></div><div style="text-align:right; font-weight:bold; color:var(--primary);">${API.fmtMoney(i.thanh_tien)}</div><button class="btn-red w-100 mt" onclick="CART.remove(${i.ma_sach})">Remove</button></div></div></div>`).join(""); 
    
    const totalHTML = discount > 0 
        ? `<span>Total:</span><span><s style="color:var(--text-muted); font-size:0.9rem;">${API.fmtMoney(h.tong_tien + discount)}</s> ${API.fmtMoney(h.tong_tien)}</span>`
        : `<span>Total:</span><span>${API.fmtMoney(h.tong_tien)}</span>`;
    
    return `<div class="cart-wrapper">
        <div class="cart-header"><h2>Cart (#${h.ma_don})</h2></div>
        <div class="cart-grid">${grid}</div>
        <div class="cart-footer">
            <div style="position:relative; margin-bottom:10px;">
                <div style="display:flex; gap:5px;">
                    <input id="voucher-input" placeholder="Voucher code" style="flex:1; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                    <button class="btn-outline" onclick="CART.toggleVoucherList()">📋</button>
                    <button class="btn-outline" onclick="CART.applyVoucher()">Apply</button>
                    <button class="btn-outline" onclick="CART.findBestVoucher()">Best</button>
                </div>
                <div id="voucher-list" style="display:none; position:absolute; bottom:45px; left:0; right:0; max-height:250px; overflow-y:auto; background:var(--bg-card); border:1px solid var(--border); border-radius:4px; padding:5px; box-shadow:var(--shadow); z-index:100;"></div>
            </div>
            ${discount > 0 ? `<div class="cart-summary-row" style="color:var(--primary);"><span>Discount:</span><span>-${API.fmtMoney(discount)}</span></div>` : ''}
            <div class="cart-summary-row total">${totalHTML}</div>
            <button class="btn-green w-100" onclick="CART.toCheckout(${h.ma_don})">Checkout</button>
        </div>
    </div>`; 
},

    html_checkout_view: (cartId, addresses) => { const opts = addresses.map(a => `<option value="${a.ma_dia_chi}">${a.dia_chi_nha}, ${a.thanh_pho}</option>`).join(""); return `<div class="checkout-wrapper"><div class="checkout-header"><button class="btn-outline" onclick="CART.open()">Back</button><h2>Checkout</h2></div><div class="checkout-form"><label class="checkout-label">1. Address</label><div class="checkout-row"><select id="co-addr" class="checkout-select">${opts}</select><button class="btn-outline" onclick="CART.promptAddAddress()">+New</button></div><label class="checkout-label">2. Payment</label><select id="co-pay" class="checkout-select"><option value="Shipper">COD</option><option value="Visa">Visa</option></select><div class="checkout-actions"><button id="btn-place-order" class="btn-green w-100" onclick="CART.submitOrder(${cartId})">Confirm</button></div></div></div>`; },


html_profile: (u, orders, vouchers) => {
    const isGuest = !u; // If user is null, it's a guest
    
    const details = isGuest ? `
        <div style="padding:20px; text-align:center; border:2px dashed var(--border); border-radius:8px; background:var(--bg-input); margin-bottom:20px;">
            <h3 style="color:var(--primary); margin-bottom:10px;">👤 Guest Account</h3>
            <p style="color:var(--text-muted); margin-bottom:15px;">You're shopping as a guest. Register to unlock:</p>
            <ul style="text-align:left; color:var(--text-muted); margin:0 auto; max-width:300px;">
                <li>✓ Member rewards & points</li>
                <li>✓ Exclusive vouchers</li>
                <li>✓ Book reviews & ratings</li>
                <li>✓ Order history tracking</li>
            </ul>
            <button class="btn-primary mt" style="margin-top:15px;" onclick="AUTH.openRegister()">Register Now</button>
        </div>
    ` : `
        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:10px; font-size:0.9rem;">
            <div><span style="color:var(--text-muted)">User:</span> <b>${u.ten_dang_nhap}</b></div>
            <div><span style="color:var(--text-muted)">Rank:</span> <b style="color:var(--primary)">${u.cap_do_thanh_vien}</b></div>
            <div><span style="color:var(--text-muted)">Points:</span> <b>${u.diem_tich_luy}</b></div>
            <div><span style="color:var(--text-muted)">Spent:</span> <b>${API.fmtMoney(u.tong_chi_tieu)}</b></div>
            <div><span style="color:var(--text-muted)">Email:</span> ${u.email}</div>
            <div><span style="color:var(--text-muted)">Phone:</span> ${u.sdt}</div>
        </div>`;

    const orderRows = (orders || []).map(o => `
        <div class="order-card" style="display:flex; justify-content:space-between; align-items:center;">
            <div>
                <div style="font-weight:bold;">#${o.ma_don}</div>
                <div style="font-size:0.8rem; color:var(--text-muted);">${o.ngay_dat}</div>
                <div style="font-size:0.85rem;">${o.trang_thai}</div>
            </div>
            <div style="text-align:right;">
                <div style="font-weight:bold; color:var(--primary); margin-bottom:5px;">${API.fmtMoney(o.tong_tien)}</div>
                <button class="btn-outline" style="padding:4px 8px; font-size:0.8rem;" onclick="SITE.viewOrder(${o.ma_don})">View</button>
                ${o.trang_thai === 'Processing' ? 
                    `<button class="btn-red" style="padding:4px 8px; font-size:0.8rem; margin-left:5px;" onclick="SITE.cancelOrder(${o.ma_don})">Cancel</button>` : ''}
            </div>
        </div>`).join("");

    const voucherSection = isGuest ? '' : `
        <h3 style="color:var(--primary); border-bottom:1px solid var(--border); padding-bottom:5px; margin-bottom:10px; margin-top:20px;">My Vouchers</h3>
        <div style="display:flex; flex-direction:column; gap:5px;">${
            (vouchers || []).map(v => `
                <div style="border:1px dashed var(--primary); padding:8px; margin-bottom:5px; border-radius:4px; background:var(--bg-input);">
                    <div style="display:flex; justify-content:space-between;">
                        <b style="color:var(--primary)">${v.ma_code}</b>
                        <span style="font-size:0.9rem;">Qty: ${v.so_luong}</span>
                    </div>
                    <div style="font-size:0.85rem;">${v.ten_voucher}</div>
                    <div style="font-size:0.8rem; color:var(--text-muted);">Exp: ${v.ngay_het_han}</div>
                </div>`).join("") || '<p style="color:var(--text-muted); font-size:0.9rem;">No vouchers available.</p>'
        }</div>`;

    return `
        <div class="detail-wrapper">
            <div class="detail-header" style="display:flex; justify-content:space-between; align-items:center;">
                <h2 class="detail-title" style="margin:0; border:none;">${isGuest ? 'Guest Profile' : 'My Profile'}</h2>
            </div>
            <div style="overflow-y:auto; padding-right:5px;">
                <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid var(--border); padding-bottom:5px; margin-bottom:10px;">
                    <h3 style="color:var(--primary); margin:0;">${isGuest ? 'Guest Info' : 'Account Details'}</h3>
                    <button id="btn-logout" class="btn-red" style="padding:4px 10px; font-size:0.8rem;">Logout</button>
                </div>
                ${details}
                ${voucherSection}
                <h3 style="color:var(--primary); border-bottom:1px solid var(--border); padding-bottom:5px; margin-bottom:10px; margin-top:20px;">Order History</h3>
                <div style="display:flex; flex-direction:column; gap:10px;">${orderRows || '<p style="color:var(--text-muted); text-align:center;">No orders yet.</p>'}</div>
            </div>
        </div>`;
},


    html_order_detail_view: (orderId, items) => {
        const rows = items.map(i => `
            <div class="card" style="flex-direction:row; height:auto; min-height:80px; align-items:center; padding:10px;">
                <div style="width:60px; height:80px; margin-right:15px; flex-shrink:0;">
                    <img src="${API.randomImg(i.ma_sach)}" style="width:100%; height:100%; object-fit:cover; border:1px solid var(--border);">
                </div>
                <div style="flex:1;">
                    <div style="font-weight:bold; margin-bottom:5px;">${i.ten_sach}</div>
                    <div style="font-size:0.9rem; color:var(--text-muted);">${API.fmtMoney(i.gia_mua)} x ${i.so_luong}</div>
                </div>
                <div style="font-weight:bold; color:var(--primary);">${API.fmtMoney(i.thanh_tien)}</div>
            </div>`).join("");
        return `<div class="detail-wrapper"><div class="detail-header" style="display:flex; align-items:center; gap:10px;"><button class="btn-outline" style="padding:5px 10px;" onclick="AUTH.openProfile()">&#8592; Back</button><h2 class="detail-title" style="margin:0; border:none;">Order #${orderId}</h2></div><div style="overflow-y:auto; padding-right:5px; display:flex; flex-direction:column; gap:10px;">${rows}</div></div>`;
    },



html_checkout_inline: (cartId, addresses) => {
    const addrOptions = addresses.map(a => 
        `<option value="${a.ma_dia_chi}">${a.thanh_pho}, ${a.quan_huyen}, ${a.phuong_xa}, ${a.dia_chi_nha}</option>`
    ).join('');
    
    const cities = ['Hà Nội', 'Hồ Chí Minh', 'Đà Nẵng', 'Hải Phòng', 'Cần Thơ', 'An Giang', 'Bà Rịa-Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh', 'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 'Bình Thuận', 'Cà Mau', 'Cao Bằng', 'Đắk Lắk', 'Đắk Nông', 'Điện Biên', 'Đồng Nai', 'Đồng Tháp', 'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Tĩnh', 'Hải Dương', 'Hậu Giang', 'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum', 'Lai Châu', 'Lâm Đồng', 'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định', 'Nghệ An', 'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Quảng Bình', 'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 'Sóc Trăng', 'Sơn La', 'Tây Ninh', 'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang', 'Trà Vinh', 'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái'];
    
    const cityOptions = cities.map(c => `<option value="${c}">${c}</option>`).join('');
    
    return `
        <div id="checkout-section" style="border-top:2px solid var(--primary); padding-top:15px; margin-top:15px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px;">
                <h3 style="color:var(--primary); margin:0;">Checkout</h3>
                <button id="btn-back-to-cart" class="btn-outline" style="padding:5px 10px; font-size:0.85rem;">← Back to Cart</button>
            </div>
            
            <div style="margin-bottom:15px;">
                <label style="display:block; font-weight:bold; margin-bottom:5px; color:var(--primary);">1. Shipping Address</label>
                <div style="display:flex; gap:5px;">
                    <select id="co-addr" style="flex:1; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                        ${addrOptions || '<option value="">No saved addresses</option>'}
                    </select>
                    <button id="btn-add-address" class="btn-outline">+ New</button>
                </div>
                
                <div id="address-form" style="display:none; margin-top:10px; padding:15px; background:var(--bg-input); border:1px solid var(--border); border-radius:4px;">
                    <h4 style="margin:0 0 10px 0; color:var(--primary);">Add New Address</h4>
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:10px;">
                        <div>
                            <label style="font-size:0.85rem; color:var(--text-muted); display:block; margin-bottom:3px;">City/Province *</label>
                            <select id="addr-city" style="width:100%; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                                <option value="">Select City</option>
                                ${cityOptions}
                            </select>
                        </div>
                        <div>
                            <label style="font-size:0.85rem; color:var(--text-muted); display:block; margin-bottom:3px;">District *</label>
                            <input id="addr-district" placeholder="e.g. Quận 1" style="width:100%; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                        </div>
                    </div>
                    <div style="margin-bottom:10px;">
                        <label style="font-size:0.85rem; color:var(--text-muted); display:block; margin-bottom:3px;">Ward *</label>
                        <input id="addr-ward" placeholder="e.g. Phường Bến Nghé" style="width:100%; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                    </div>
                    <div style="margin-bottom:10px;">
                        <label style="font-size:0.85rem; color:var(--text-muted); display:block; margin-bottom:3px;">Street Address *</label>
                        <input id="addr-street" placeholder="e.g. 123 Nguyễn Huệ" style="width:100%; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                    </div>
                    <div style="display:flex; gap:5px;">
                        <button class="btn-primary" onclick="CART.saveAddress()">Save Address</button>
                        <button class="btn-outline" onclick="CART.showAddressForm()">Cancel</button>
                    </div>
                </div>
            </div>
            
            <div style="margin-bottom:15px;">
                <label style="display:block; font-weight:bold; margin-bottom:5px; color:var(--primary);">2. Payment Method</label>
                <select id="co-pay" style="width:100%; padding:8px; border:1px solid var(--border); background:var(--bg-input); color:var(--text-main); border-radius:4px;">
                    <option value="Shipper">Cash on Delivery (COD)</option>
                    <option value="Visa">Credit Card (Visa)</option>
                </select>
            </div>
            
            <button id="btn-place-order" class="btn-green w-100">Confirm Order</button>
        </div>
    `;
},


    html_login: () => `<h2>Login</h2><input id="l-user" class="auth-input" placeholder="User"><input id="l-pass" type="password" class="auth-input" placeholder="Pass"><button id="l-btn-submit" class="btn-green mt w-100">Login</button><button id="l-btn-guest" class="btn-outline mt w-100">Guest</button><a href="#" id="l-link-reg" class="auth-link">Register</a>`,
    html_register: () => `<h2>Register</h2><input id="r-user" class="auth-input" placeholder="User"><input id="r-pass" type="password" class="auth-input" placeholder="Pass"><input id="r-email" class="auth-input" placeholder="Email"><div class="auth-row mt"><input id="r-ho" class="auth-input" placeholder="Họ"><input id="r-ten" class="auth-input" placeholder="Tên"></div><input id="r-sdt" class="auth-input" placeholder="Phone"><input id="r-dob" type="date" class="auth-input"><button id="r-btn-submit" class="btn-green mt w-100">Sign Up</button><a href="#" id="r-link-login" class="auth-link">Login</a>`





};
