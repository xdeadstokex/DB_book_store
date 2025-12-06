const AUTH = {
    openLogin: () => {
        const html = API.html_login();
        SITE.openModal(html);
        document.getElementById('l-btn-submit').onclick = AUTH.doLogin;
        document.getElementById('l-link-reg').onclick = AUTH.openRegister;
        document.getElementById('l-btn-guest').onclick = AUTH.doGuest;
    },

    openRegister: () => {
        const html = API.html_register();
        SITE.openModal(html);
        document.getElementById('r-btn-submit').onclick = AUTH.doRegister;
        document.getElementById('r-link-login').onclick = AUTH.openLogin;
    },

	openProfile: async () => {
		try {
		    const [user, orders, vouchers] = await Promise.all([
		        API.call_me().catch(() => null), // Allow failure for guests
		        API.call_order_history(),
		        API.call_my_vouchers().catch(() => []) // Guests have no vouchers
		    ]);

		    const html = API.html_profile(user, orders, vouchers);
		    SITE.openModal(html);

		    const btn = document.getElementById('btn-logout');
		    if(btn) {
		        btn.onclick = () => {
		            localStorage.removeItem('token');
		            location.reload();
		        };
		    }

		} catch (e) {
		    console.error(e);
		    alert("Failed to load profile");
		    AUTH.openLogin();
		}
	},

    // Actions
    doLogin: async () => {
        const u = document.getElementById('l-user').value;
        const p = document.getElementById('l-pass').value;
        try {
            const res = await API.call_login(u, p); //
            localStorage.setItem('token', res.token);
            SITE.closeModal();
            SITE.checkAuth();
        } catch(e) {}
    },

    doGuest: async () => {
        try {
            const res = await API.call_guest(); //
            localStorage.setItem('token', res.token);
            SITE.closeModal();
            SITE.checkAuth();
        } catch(e) {}
    },

    doRegister: async () => {
        const data = {
            ten_dang_nhap: document.getElementById('r-user').value,
            mat_khau: document.getElementById('r-pass').value,
            email: document.getElementById('r-email').value,
            ho: document.getElementById('r-ho').value,
            ho_ten_dem: document.getElementById('r-ten').value,
            sdt: document.getElementById('r-sdt').value,
            gioi_tinh: 'Nam', 
            ngay_sinh: document.getElementById('r-dob').value
        };
        try {
            await API.call_register(data); //
            alert("Registered!");
            AUTH.openLogin();
        } catch(e) {}
    }
};
