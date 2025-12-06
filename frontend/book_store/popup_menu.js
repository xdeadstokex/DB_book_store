const MENU = {
    listCache: [], currentType: null,
    openAuthors: async () => {
        try { MENU.listCache = await API.call_all_authors(); MENU.currentType = 'author'; MENU.render("Authors", MENU.listCache); } catch (e) {}
    },
    openCategories: async () => {
        try { MENU.listCache = await API.call_all_categories(); MENU.currentType = 'cat'; MENU.render("Categories", MENU.listCache); } catch (e) {}
    },
    render: (title, list) => {
        SITE.openModal(`<div class="menu-wrapper"><div class="menu-header"><h2>${title}</h2><input class="menu-search" placeholder="Filter..." onkeyup="MENU.filter(this.value)"></div><div id="menu-group-container" class="menu-list"></div></div>`);
        MENU.renderGroups(list);
    },
    renderGroups: (list) => {
        const container = document.getElementById('menu-group-container');
        if (!list.length) { container.innerHTML = "<p>No matches.</p>"; return; }
        const groups = {};
        list.forEach(i => { const l = i.name.charAt(0).toUpperCase(); if(!groups[l]) groups[l]=[]; groups[l].push(i); });
        
        let html = "";
        Object.keys(groups).sort().forEach(l => {
            const items = groups[l].map(i => {
                // IMPORTANT: Calls SITE.filterBy...
                const fn = MENU.currentType === 'author' ? `SITE.filterByAuthor(${i.id}, '${i.name.replace(/'/g, "\\'")}')` : `SITE.filterByCategory(${i.id}, '${i.name.replace(/'/g, "\\'")}')`;
                return `<div class="menu-item" onclick="${fn}">${i.name}</div>`;
            }).join("");
            html += `<div class="menu-group"><div class="menu-letter">${l}</div><div class="menu-items-grid">${items}</div></div>`;
        });
        container.innerHTML = html;
    },
    filter: (t) => MENU.renderGroups(MENU.listCache.filter(i => i.name.toLowerCase().includes(t.toLowerCase())))
};
