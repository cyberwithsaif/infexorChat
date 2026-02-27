document.addEventListener('DOMContentLoaded', () => {
    if (!API.isAuthenticated()) { window.location.href = 'index.html'; return; }
    let currentModule = null;
    const navItems = document.querySelectorAll('.nav-item[data-page]');
    const pageTitle = document.getElementById('pageTitle');

    const modules = {
        dashboard: { mod: () => DashboardModule, title: 'Dashboard' },
        users: { mod: () => UsersModule, title: 'User Management' },
        calls: { mod: () => CallsModule, title: 'Call Analytics' },
        chats: { mod: () => ChatsModule, title: 'Chat Analytics' },
        server: { mod: () => ServerModule, title: 'Server Status' },
        storage: { mod: () => StorageModule, title: 'Storage & Media' },
        security: { mod: () => SecurityModule, title: 'Security' },
        reports: { mod: () => ReportsModule, title: 'Reports' },
        broadcasts: { mod: () => BroadcastsModule, title: 'Broadcasts' },
    };

    navItems.forEach(item => item.addEventListener('click', () => navigateTo(item.dataset.page)));

    function navigateTo(page) {
        navItems.forEach(n => n.classList.remove('active'));
        const activeNav = document.querySelector(`[data-page="${page}"]`);
        if (activeNav) activeNav.classList.add('active');
        pageTitle.textContent = modules[page]?.title || 'Dashboard';
        window.location.hash = page;
        loadPage(page);
    }

    function loadPage(page) {
        const content = document.getElementById('pageContent');
        if (currentModule?.destroy) { try { currentModule.destroy(); } catch { } }
        currentModule = null;
        content.innerHTML = '';

        const entry = modules[page];
        if (entry) {
            try {
                const m = entry.mod();
                currentModule = m;
                m.init(content);
            } catch (err) {
                console.error('Error loading page:', err);
                content.innerHTML = `<div style="text-align:center;padding:80px 20px;color:var(--text-muted)"><h3 style="color:var(--danger)">Error</h3><p>${err.message}</p></div>`;
            }
        } else {
            content.innerHTML = `<div style="text-align:center;padding:80px 20px;color:var(--text-muted)"><h3>Page Not Found</h3></div>`;
        }
    }

    document.getElementById('logoutBtn').addEventListener('click', () => { API.clearToken(); window.location.href = 'index.html'; });

    // Refresh Logic
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', async () => {
            refreshBtn.classList.add('spinning');
            try {
                if (currentModule?.refresh) {
                    await currentModule.refresh();
                } else if (currentModule?.loadStats) {
                    await currentModule.loadStats();
                } else {
                    const page = window.location.hash.slice(1) || 'dashboard';
                    loadPage(page);
                }
            } catch (err) {
                console.error('Refresh error:', err);
            } finally {
                setTimeout(() => refreshBtn.classList.remove('spinning'), 600);
            }
        });
    }

    const initialPage = window.location.hash.slice(1) || 'dashboard';
    navigateTo(initialPage);
    window.addEventListener('hashchange', () => {
        const page = window.location.hash.slice(1) || 'dashboard';
        const activeNav = document.querySelector(`.nav-item[data-page="${page}"]`);
        if (activeNav && !activeNav.classList.contains('active')) {
            navigateTo(page);
        }
    });
});
