const THEME = {
    init: () => {
        // 1. Check LocalStorage
        const saved = localStorage.getItem('theme') || 'tree';
        THEME.apply(saved);

        // 2. Bind Selector
        const selector = document.getElementById('theme-select');
        if (selector) {
            selector.value = saved;
            selector.addEventListener('change', (e) => THEME.apply(e.target.value));
        }
    },

    apply: (name) => {
        // Set attribute on HTML tag so CSS picks it up
        if (name === 'dungeon') {
            document.documentElement.setAttribute('data-theme', 'dungeon');
        } else {
            document.documentElement.removeAttribute('data-theme');
        }
        
        localStorage.setItem('theme', name);
    }
};

// Run immediately
document.addEventListener('DOMContentLoaded', THEME.init);
