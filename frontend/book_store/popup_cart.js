const CART = {
    open: async () => {
        if (!localStorage.getItem('token')) return AUTH.openLogin();
        
        const modalBox = document.getElementById('modal-box');
        modalBox.style.width = '800px'; 
        modalBox.style.height = '85vh';

        SITE.openModal('<p style="padding:20px; text-align:center;">Loading Cart...</p>');

        try {
            const res = await API.call_get_cart();
            const html = API.html_cart_view(res);
            SITE.openModal(html);
        } catch (e) {
            console.error(e);
            SITE.openModal(`<p style="color:var(--danger); padding:20px;">Error loading cart.</p>`);
        }
    },

    update: async (id, qty) => {
        const q = parseInt(qty);
        if (isNaN(q) || q < 1) return; 

        try {
            await API.call_update_cart(id, q);
            const res = await API.call_get_cart();
            const html = API.html_cart_view(res);
            document.getElementById('modal-content').innerHTML = html;
        } catch (e) {
            alert("Failed to update: " + e.message);
        }
    },

    remove: async (id) => {
        if (!confirm("Remove this item?")) return;
        try {
            await API.call_remove_cart(id);
            const res = await API.call_get_cart();
            const html = API.html_cart_view(res);
            document.getElementById('modal-content').innerHTML = html;
        } catch (e) {
            alert(e.message);
        }
    },

    toggleVoucherList: async () => {
        const list = document.getElementById('voucher-list');
        if (list.style.display === 'block') {
            list.style.display = 'none';
            return;
        }

        list.innerHTML = '<p style="padding:10px; color:var(--text-muted);">Loading...</p>';
        list.style.display = 'block';

        try {
            const vouchers = await API.call_my_vouchers();
            if (!vouchers || vouchers.length === 0) {
                list.innerHTML = '<p style="padding:10px; color:var(--text-muted); font-size:0.9rem;">No vouchers available</p>';
                return;
            }

            const rows = vouchers.map(v => `
                <div style="border:1px solid var(--border); padding:8px; margin-bottom:5px; border-radius:4px; background:var(--bg-input); cursor:pointer;" onclick="CART.selectVoucher('${v.ma_code}')">
                    <div style="display:flex; justify-content:space-between; margin-bottom:3px;">
                        <b style="color:var(--primary)">${v.ma_code}</b>
                        <span style="font-size:0.85rem; color:var(--text-muted);">Qty: ${v.so_luong}</span>
                    </div>
                    <div style="font-size:0.9rem; margin-bottom:2px;">${v.ten_voucher}</div>
                    <div style="font-size:0.85rem; color:var(--text-muted);">
                        ${v.loai_giam === 'Số tiền' ? API.fmtMoney(v.gia_tri_giam) : v.gia_tri_giam + '%'} off
                        ${v.giam_toi_da ? ' (max ' + API.fmtMoney(v.giam_toi_da) + ')' : ''}
                    </div>
                    <div style="font-size:0.8rem; color:var(--text-muted);">Expires: ${v.ngay_het_han}</div>
                </div>
            `).join('');

            list.innerHTML = rows;
        } catch (e) {
            list.innerHTML = '<p style="padding:10px; color:var(--danger);">Failed to load vouchers</p>';
        }
    },

    selectVoucher: (code) => {
        document.getElementById('voucher-input').value = code;
        document.getElementById('voucher-list').style.display = 'none';
    },

	applyVoucher: async () => {
		const code = document.getElementById('voucher-input').value.trim();
		if (!code) return alert("Enter voucher code");
		
		try {
		    const result = await API.call_apply_voucher(code);
		    const discount = result.data.discount_amount;
		    const eligible = result.data.eligible_total;
		    alert(`Voucher applied!\nEligible: ${API.fmtMoney(eligible)}\nDiscount: ${API.fmtMoney(discount)}`);
		    
		    // Reload cart to show updated total
		    const res = await API.call_get_cart();
		    const html = API.html_cart_view(res, discount); // Pass discount
		    document.getElementById('modal-content').innerHTML = html;
		} catch (e) {
		    alert("Voucher failed: " + e.message);
		}
	},

    findBestVoucher: async () => {
        try {
            const result = await API.call_find_best_voucher();
            if (result.data && result.data.voucher_code) {
                document.getElementById('voucher-input').value = result.data.voucher_code;
                alert(`Best voucher: ${result.data.voucher_code}\n${result.data.message}`);
            } else {
                alert("No applicable vouchers");
            }
        } catch (e) {
            alert("Failed: " + e.message);
        }
    },


	toCheckout: async (cartId) => {
		try {
		    const addrs = await API.call_get_addr();
		    
		    // Don't change modal size, just append checkout form
		    const checkoutSection = API.html_checkout_inline(cartId, addrs);
		    
		    // Insert after cart footer
		    const cartWrapper = document.querySelector('.cart-wrapper');
		    const existingCheckout = document.getElementById('checkout-section');
		    if (existingCheckout) existingCheckout.remove();
		    
		    cartWrapper.insertAdjacentHTML('beforeend', checkoutSection);
		    
		    // Bind events
		    document.getElementById('btn-back-to-cart').onclick = () => {
		        document.getElementById('checkout-section').remove();
		    };
		    
		    document.getElementById('btn-add-address').onclick = CART.showAddressForm;
		    document.getElementById('btn-place-order').onclick = () => CART.submitOrder(cartId);
		    
		} catch (e) {
		    alert("Could not load checkout: " + e.message);
		}
	},


	showAddressForm: () => {
		const form = document.getElementById('address-form');
		form.style.display = form.style.display === 'none' ? 'block' : 'none';
	},

	saveAddress: async () => {
		const city = document.getElementById('addr-city').value;
		const district = document.getElementById('addr-district').value;
		const ward = document.getElementById('addr-ward').value;
		const street = document.getElementById('addr-street').value.trim();
		
		if (!city || !district || !ward || !street) {
		    return alert("Please fill all address fields");
		}
		
		const data = {
		    thanh_pho: city,
		    quan_huyen: district,
		    phuong_xa: ward,
		    dia_chi_nha: street
		};
		
		try {
		    await API.call_add_addr(data);
		    alert("Address saved!");
		    
		    // Reload addresses
		    const addrs = await API.call_get_addr();
		    const select = document.getElementById('co-addr');
		    select.innerHTML = addrs.map(a => 
		        `<option value="${a.ma_dia_chi}">${a.thanh_pho}, ${a.quan_huyen}, ${a.phuong_xa}, ${a.dia_chi_nha}</option>`
		    ).join('');
		    
		    document.getElementById('address-form').style.display = 'none';
		} catch (e) {
		    alert(e.message);
		}
	},

    promptAddAddress: async () => {
        const raw = prompt("Format: City, District, Ward, Street");
        if (!raw) return;
        
        const p = raw.split(',');
        if (p.length < 4) return alert("Need 4 parts separated by comma");

        const data = {
            thanh_pho: p[0].trim(),
            quan_huyen: p[1].trim(),
            phuong_xa: p[2].trim(),
            dia_chi_nha: p[3].trim()
        };

        try {
            await API.call_add_addr(data);
            alert("Address added!");
            CART.open(); 
        } catch (e) {
            alert(e.message);
        }
    },

    submitOrder: async (cartId) => {
        const addrId = document.getElementById('co-addr').value;
        const payMethod = document.getElementById('co-pay').value;
        const btn = document.getElementById('btn-place-order');

        if (!addrId) return alert("Select shipping address");
        if (!payMethod) return alert("Select payment method");

        btn.disabled = true;
        btn.innerText = "Processing...";

        try {
            await API.call_set_addr(addrId);
            await API.call_set_payment(payMethod);
            await API.call_checkout(cartId);

            alert("Order Placed!");
            SITE.closeModal();
            AUTH.openProfile();

        } catch (e) {
            alert("Checkout Failed: " + e.message);
            btn.disabled = false;
            btn.innerText = "Confirm Order";
        }
    }
};
