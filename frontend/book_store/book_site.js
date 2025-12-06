const SITE = {
    // Navigation Stack
    historyStack: [],
    currentState: null,

    init: async () => {
        await API.init();

        const bind = (id, fn) => { const el = document.getElementById(id); if(el) el.onclick = fn; };
        
        bind('btn-cart', CART.open);
        bind('btn-close-modal', SITE.closeModal);
        bind('btn-home', () => SITE.loadView({ type: 'all', label: 'All Books' }));
        bind('btn-history-back', SITE.goBack);
        bind('btn-search', SITE.performSearch);
        
        ['s-title', 's-author', 's-cat'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.addEventListener('keyup', (e) => { if (e.key === 'Enter') SITE.performSearch(); });
        });

        const toggle = document.getElementById('search-mode-toggle');
        if (toggle) {
            toggle.onchange = (e) => {
                const manual = document.getElementById('panel-manual');
                const browse = document.getElementById('panel-browse');
                const lM = document.getElementById('lbl-manual');
                const lB = document.getElementById('lbl-browse');
                
                if (e.target.checked) {
                    manual.style.display = 'none';
                    browse.style.display = 'block';
                    lM.classList.remove('active');
                    lB.classList.add('active');
                } else {
                    manual.style.display = 'block';
                    browse.style.display = 'none';
                    lM.classList.add('active');
                    lB.classList.remove('active');
                }
            };
        }

        bind('search-trigger', () => {
            document.getElementById('search-simple').style.display='none';
            document.getElementById('search-advanced').style.display='flex';
            document.getElementById('s-title').focus();
        });
        bind('btn-cancel-search', () => {
            document.getElementById('search-advanced').style.display='none';
            document.getElementById('search-simple').style.display='block';
        });

        bind('btn-authors', MENU.openAuthors);
        bind('btn-cats', MENU.openCategories);

        SITE.checkAuth();
        SITE.loadView({ type: 'all', label: 'All Books' }, false);
    },

    // --- CORE NAVIGATION (with shuffle on default view) ---
    loadView: async (state, pushToHistory = true) => {
        if (pushToHistory && SITE.currentState) {
            SITE.historyStack.push(SITE.currentState);
        }
        if (state.type === 'all') {
            SITE.historyStack = [];
        }
        
        SITE.currentState = state;
        SITE.updateFilterBar();

        const grid = document.getElementById('book-grid');
        grid.innerHTML = '<p style="text-align:center; padding:20px; color:var(--text-muted)">Loading...</p>';

        try {
            let list = [];
            
            if (state.type === 'all') {
                list = await API.call_get_books();
                // Shuffle for default view
                if (list && list.length > 0) {
                    SITE.shuffleArray(list);
                }
            }
            else if (state.type === 'search') list = await API.call_search(state.title, state.author, state.cat);
            else if (state.type === 'author') list = await API.call_books_by_author(state.id);
            else if (state.type === 'cat') list = await API.call_books_by_category(state.id);
            
            grid.innerHTML = API.html_book_list(list);
            SITE.updateSoldCounts(list);
        } catch (e) {
            grid.innerHTML = `<p style="color:var(--danger); text-align:center;">Error: ${e.message}</p>`;
        }
    },

    shuffleArray: (array) => {
        for (let i = array.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [array[i], array[j]] = [array[j], array[i]];
        }
    },

    updateSoldCounts: (list) => {
        if(!list || !Array.isArray(list)) return;
        list.forEach(async (book) => {
            const el = document.getElementById(`sold-${book.ma_sach}`);
            if (el) {
                try {
                    const res = await API.call_get_sold_qty(book.ma_sach);
                    const qty = res ? res.tong_da_ban : 0;
                    el.innerText = `${qty} sold`;
                    el.style.color = 'var(--primary)';
                } catch(e) {}
            }
        });
    },

    goBack: () => {
        if (SITE.historyStack.length === 0) return;
        const prev = SITE.historyStack.pop();
        SITE.loadView(prev, false);
    },

    updateFilterBar: () => {
        const bar = document.getElementById('filter-bar');
        const label = document.getElementById('filter-label');
        if (SITE.historyStack.length > 0) {
            bar.style.display = 'flex';
            label.innerText = SITE.currentState.label || "Results";
        } else {
            bar.style.display = 'none';
        }
    },

    performSearch: () => {
        const title = document.getElementById('s-title').value.trim();
        const author = document.getElementById('s-author').value.trim();
        const cat = document.getElementById('s-cat').value.trim();
        
        if (!title && !author && !cat) {
            SITE.loadView({ type: 'all', label: 'All Books' });
        } else {
            SITE.loadView({ 
                type: 'search', 
                title, author, cat, 
                label: `Search: ${title || author || cat}` 
            });
        }
    },

    filterByAuthor: (id, name) => {
        SITE.closeModal();
        SITE.loadView({ type: 'author', id, label: `Author: ${name}` });
    },

    filterByCategory: (id, name) => {
        SITE.closeModal();
        SITE.loadView({ type: 'cat', id, label: `Category: ${name}` });
    },


	checkAuth: () => {
		const div = document.getElementById('auth-container');
		if (!div) return;
		if (localStorage.getItem('token')) {
		    div.innerHTML = `<button class="btn-primary" id="btn-profile">Profile</button>`;
		    document.getElementById('btn-profile').onclick = AUTH.openProfile;
		} else {
		    div.innerHTML = `<button class="btn-primary" id="btn-login">Login</button>`;
		    document.getElementById('btn-login').onclick = AUTH.openLogin;
		}
	},


    add: async (id) => { 
        if(!localStorage.getItem('token')) return AUTH.openLogin(); 
        try { 
            await API.call_add_cart(id, 1); 
            alert("Added!"); 
        } catch(e) {} 
    },

    cancelOrder: async (id) => { 
        if(confirm("Cancel?")) { 
            await API.call_cancel_order(id); 
            AUTH.openProfile(); 
        } 
    },

    viewOrder: async (orderId) => {
        try {
            const items = await API.call_order_detail(orderId);
            const html = API.html_order_detail_view(orderId, items);
            SITE.openModal(html);
        } catch(e) {
            alert('Failed to load order');
        }
    },
    
    openModal: (html) => { 
        document.getElementById('modal-content').innerHTML = html; 
        document.getElementById('modal').style.display = 'flex'; 
    },
    
    closeModal: () => { 
        document.getElementById('modal').style.display = 'none'; 
        const box = document.getElementById('modal-box');
        box.classList.remove('book-skin');
        box.style.width = '450px';
        box.style.height = 'auto';
        box.style.padding = '';
        box.style.aspectRatio = 'auto';
    }
};

document.addEventListener('DOMContentLoaded', SITE.init);
