/**
 * Infexor Chat Admin - Main App Controller
 * Handles SPA routing and page initialization
 */
document.addEventListener('DOMContentLoaded', () => {
  // Auth check
  if (!API.isAuthenticated()) {
    window.location.href = 'index.html';
    return;
  }

  // Current module reference for cleanup
  let currentModule = null;

  // Navigation
  const navItems = document.querySelectorAll('.nav-item[data-page]');
  const pageTitle = document.getElementById('pageTitle');

  navItems.forEach((item) => {
    item.addEventListener('click', () => {
      const page = item.dataset.page;
      navigateTo(page);
    });
  });

  function navigateTo(page) {
    // Update active nav
    navItems.forEach((n) => n.classList.remove('active'));
    const activeNav = document.querySelector(`[data-page="${page}"]`);
    if (activeNav) activeNav.classList.add('active');

    // Update title
    const titles = {
      dashboard: 'Dashboard',
      users: 'User Management',
      reports: 'Reports',
      broadcasts: 'Broadcasts',
      monitoring: 'System Monitoring',
    };
    pageTitle.textContent = titles[page] || 'Dashboard';

    // Update URL hash
    window.location.hash = page;

    // Load page content
    loadPage(page);
  }

  function loadPage(page) {
    const content = document.getElementById('pageContent');

    // Cleanup previous module
    if (currentModule && currentModule.destroy) {
      try {
        currentModule.destroy();
      } catch (error) {
        console.error('Error destroying module:', error);
      }
    }
    currentModule = null;

    // Clear content
    content.innerHTML = '';

    // Load appropriate module
    try {
      switch (page) {
        case 'dashboard':
          currentModule = DashboardModule;
          DashboardModule.init(content);
          break;

        case 'users':
          currentModule = UsersModule;
          UsersModule.init(content);
          break;

        case 'reports':
          currentModule = ReportsModule;
          ReportsModule.init(content);
          break;

        case 'broadcasts':
          currentModule = BroadcastsModule;
          BroadcastsModule.init(content);
          break;

        case 'monitoring':
          currentModule = MonitoringModule;
          MonitoringModule.init(content);
          break;

        default:
          content.innerHTML = `
            <div style="text-align: center; padding: 80px 20px; color: var(--text-muted);">
              <h3 style="color: var(--text-primary);">Page Not Found</h3>
              <p>The requested page does not exist.</p>
            </div>
          `;
      }
    } catch (error) {
      console.error('Error loading page:', error);
      content.innerHTML = `
        <div style="text-align: center; padding: 80px 20px; color: var(--text-muted);">
          <h3 style="color: var(--danger);">Error Loading Page</h3>
          <p>${Utils.escapeHtml(error.message || 'An error occurred')}</p>
          <button class="btn btn-secondary" onclick="window.location.reload()">Reload Page</button>
        </div>
      `;
    }
  }

  // Logout
  document.getElementById('logoutBtn').addEventListener('click', () => {
    API.clearToken();
    window.location.href = 'index.html';
  });

  // Handle hash routing
  const initialPage = window.location.hash.slice(1) || 'dashboard';
  navigateTo(initialPage);

  window.addEventListener('hashchange', () => {
    const page = window.location.hash.slice(1) || 'dashboard';
    navigateTo(page);
  });
});
