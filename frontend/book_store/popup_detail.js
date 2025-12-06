const DETAIL = {
    open: async (id) => {
        try {
            const modalBox = document.getElementById('modal-box');
            modalBox.classList.add('book-skin');
            modalBox.style.width = ''; modalBox.style.height = ''; 

            // PARALLEL FETCH: Book, Ratings, Sold Quantity
            const [b, r, s] = await Promise.all([
                API.call_get_book(id), //
                API.call_get_ratings(id), //
                API.call_get_sold_qty(id) //
            ]);
            
            const soldQty = s ? s.tong_da_ban : 0;

            const html = API.html_book_detail(b, r, soldQty);
            SITE.openModal(html);
        } catch (e) { console.error(e); }
    },

    redirectToAuthor: (id, name) => SITE.filterByAuthor(id, name),
    redirectToCategory: (id, name) => SITE.filterByCategory(id, name),

    rate: async (id) => {
        if (!localStorage.getItem('token')) return AUTH.openLogin();
        const stars = prompt("Stars (1-5):");
        const content = prompt("Review:");
        if (stars && content) {
            try { await API.call_add_rating(id, parseInt(stars), content); alert("Submitted!"); DETAIL.open(id); } catch (e) {}
        }
    }
};
