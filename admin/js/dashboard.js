/**
 * Infexor Chat Admin - Dashboard Module
 * Enhanced dashboard with real-time stats and charts
 */

const DashboardModule = (() => {
  let statsInterval = null;
  let messagesChart = null;
  let usersChart = null;
  let lastUpdateTime = Date.now();

  /**
   * Initialize dashboard
   * @param {HTMLElement} container - Content container
   */
  async function init(container) {
    container.innerHTML = `
      <!-- Stats Grid -->
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
          </div>
          <div class="stat-content">
            <div class="label">Total Users</div>
            <div class="value" id="statUsers">--</div>
            <div class="change" id="statUsersChange">Loading...</div>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
            </svg>
          </div>
          <div class="stat-content">
            <div class="label">Messages Today</div>
            <div class="value" id="statMessages">--</div>
            <div class="change" id="statMessagesChange">Loading...</div>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
          </div>
          <div class="stat-content">
            <div class="label">Active Today</div>
            <div class="value" id="statActive">--</div>
            <div class="change" id="statActiveChange">Loading...</div>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="2" y="7" width="20" height="14" rx="2" ry="2"/>
              <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>
            </svg>
          </div>
          <div class="stat-content">
            <div class="label">Server Status</div>
            <div class="value" style="font-size: 18px;">
              <span class="badge badge-success" id="serverStatus">Healthy</span>
            </div>
            <div class="change" id="serverUptime">--</div>
          </div>
        </div>
      </div>

      <!-- Charts Section -->
      <div class="charts-grid">
        <div class="chart-card">
          <div class="chart-header">
            <h3>Messages Per Day</h3>
            <span class="chart-subtitle">Last 7 days</span>
          </div>
          <div class="chart-container">
            <canvas id="messagesChart"></canvas>
          </div>
        </div>

        <div class="chart-card">
          <div class="chart-header">
            <h3>New Users Per Day</h3>
            <span class="chart-subtitle">Last 7 days</span>
          </div>
          <div class="chart-container">
            <canvas id="usersChart"></canvas>
          </div>
        </div>
      </div>

      <!-- Recent Users Table -->
      <div class="table-container">
        <div class="table-header">
          <h3>Recent Users</h3>
          <a href="#users" class="btn btn-secondary btn-sm">View All</a>
        </div>
        <table class="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>Status</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody id="recentUsersTable">
            <tr>
              <td colspan="4">
                <div class="loader"><div class="spinner"></div></div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Last Update Indicator -->
      <div class="last-update">
        Last updated <span id="lastUpdate">just now</span>
      </div>
    `;

    // Load initial data
    await loadStats();
    await loadRecentUsers();

    // Auto-refresh every 30 seconds
    statsInterval = setInterval(() => {
      loadStats();
      updateLastUpdateTime();
    }, 30000);

    // Update "last updated" every 10 seconds
    setInterval(updateLastUpdateTime, 10000);
  }

  /**
   * Load dashboard statistics
   */
  async function loadStats() {
    try {
      const response = await API.get('/admin/dashboard/stats');
      const stats = response.data;

      // Update stat cards with animation
      Utils.animateNumber(document.getElementById('statUsers'), stats.totalUsers || 0);
      Utils.animateNumber(document.getElementById('statActive'), stats.activeToday || 0);
      Utils.animateNumber(document.getElementById('statMessages'), stats.totalMessages || 0);

      // Update change indicators
      const usersChangeEl = document.getElementById('statUsersChange');
      const activeThisWeek = stats.activeWeek || 0;
      usersChangeEl.innerHTML = `
        <span class="change positive">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="18 15 12 9 6 15"/>
          </svg>
          ${Utils.formatNumber(activeThisWeek)} active this week
        </span>
      `;

      const messagesChangeEl = document.getElementById('statMessagesChange');
      const messagesPerDay = stats.messagesPerDay || [];
      if (messagesPerDay.length > 0) {
        const todayMessages = messagesPerDay[messagesPerDay.length - 1]?.count || 0;
        messagesChangeEl.innerHTML = `
          <span class="change positive">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="18 15 12 9 6 15"/>
            </svg>
            ${Utils.formatNumber(todayMessages)} today
          </span>
        `;
      }

      const activeChangeEl = document.getElementById('statActiveChange');
      const activeThisMonth = stats.activeMonth || 0;
      activeChangeEl.innerHTML = `
        <span class="change positive">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="18 15 12 9 6 15"/>
          </svg>
          ${Utils.formatNumber(activeThisMonth)} this month
        </span>
      `;

      // Update server status
      const serverStatusEl = document.getElementById('serverStatus');
      const serverUptimeEl = document.getElementById('serverUptime');
      serverStatusEl.textContent = 'Healthy';
      serverStatusEl.className = 'badge badge-success';
      serverUptimeEl.innerHTML = `<span class="change">Online</span>`;

      // Update charts
      updateCharts(stats);

      lastUpdateTime = Date.now();
    } catch (error) {
      console.error('Failed to load dashboard stats:', error);

      // Update server status to show error
      const serverStatusEl = document.getElementById('serverStatus');
      const serverUptimeEl = document.getElementById('serverUptime');
      if (serverStatusEl && serverUptimeEl) {
        serverStatusEl.textContent = 'Error';
        serverStatusEl.className = 'badge badge-danger';
        serverUptimeEl.innerHTML = `<span class="change negative">Connection failed</span>`;
      }

      Components.Toast.error('Failed to load dashboard stats');
    }
  }

  /**
   * Update charts with new data
   * @param {Object} stats - Dashboard statistics
   */
  function updateCharts(stats) {
    // Messages Per Day Chart
    const messagesData = stats.messagesPerDay || [];
    const messagesChartData = {
      labels: messagesData.map(d => ChartConfig.formatChartDate(d._id)),
      datasets: [{
        label: 'Messages',
        data: messagesData.map(d => d.count),
        borderColor: ChartConfig.colors.primary,
        backgroundColor: ChartConfig.colors.primary
      }]
    };

    if (messagesChart) {
      ChartConfig.updateChart(messagesChart, messagesChartData);
    } else {
      messagesChart = ChartConfig.createLineChart('messagesChart', messagesChartData);
    }

    // New Users Per Day Chart
    const usersData = stats.newUsersPerDay || [];
    const usersChartData = {
      labels: usersData.map(d => ChartConfig.formatChartDate(d._id)),
      datasets: [{
        label: 'New Users',
        data: usersData.map(d => d.count),
        borderColor: ChartConfig.colors.secondary,
        backgroundColor: ChartConfig.colors.secondary
      }]
    };

    if (usersChart) {
      ChartConfig.updateChart(usersChart, usersChartData);
    } else {
      usersChart = ChartConfig.createLineChart('usersChart', usersChartData);
    }
  }

  /**
   * Load recent users
   */
  async function loadRecentUsers() {
    const tbody = document.getElementById('recentUsersTable');

    try {
      const response = await API.get('/admin/users?limit=10');
      const users = response.data.users || [];

      if (users.length === 0) {
        tbody.innerHTML = `
          <tr>
            <td colspan="4" class="empty-state">
              <div class="empty-state-content">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                  <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
                <p>No users yet</p>
              </div>
            </td>
          </tr>
        `;
        return;
      }

      tbody.innerHTML = users.map((user, index) => `
        <tr class="table-row" onclick="window.location.hash='users'; setTimeout(() => UsersModule.viewDetails('${user._id}'), 100)" style="cursor: pointer;">
          <td>
            <div style="display: flex; align-items: center; gap: 10px;">
              ${user.isOnline ? '<span class="status-dot online"></span>' : '<span class="status-dot"></span>'}
              <span>${Utils.escapeHtml(user.name)}</span>
            </div>
          </td>
          <td>${Utils.formatPhoneNumber(user.phone)}</td>
          <td><span class="badge badge-${Utils.getStatusColor(user.status)}">${user.status}</span></td>
          <td>${Utils.formatTimeAgo(user.createdAt)}</td>
        </tr>
      `).join('');

      // Fade in animation
      const rows = tbody.querySelectorAll('.table-row');
      rows.forEach((row, index) => {
        setTimeout(() => row.classList.add('visible'), index * 50);
      });
    } catch (error) {
      console.error('Failed to load recent users:', error);
      tbody.innerHTML = `
        <tr>
          <td colspan="4" class="error-state">
            <div class="error-state-content">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <circle cx="12" cy="12" r="10"/>
                <line x1="15" y1="9" x2="9" y2="15"/>
                <line x1="9" y1="9" x2="15" y2="15"/>
              </svg>
              <p>Failed to load users</p>
              <button class="btn btn-secondary btn-sm" onclick="DashboardModule.loadStats()">Retry</button>
            </div>
          </td>
        </tr>
      `;
    }
  }

  /**
   * Update "last updated" time
   */
  function updateLastUpdateTime() {
    const lastUpdateEl = document.getElementById('lastUpdate');
    if (lastUpdateEl) {
      const secondsAgo = Math.floor((Date.now() - lastUpdateTime) / 1000);
      if (secondsAgo < 60) {
        lastUpdateEl.textContent = 'just now';
      } else if (secondsAgo < 3600) {
        lastUpdateEl.textContent = `${Math.floor(secondsAgo / 60)} minutes ago`;
      } else {
        lastUpdateEl.textContent = `${Math.floor(secondsAgo / 3600)} hours ago`;
      }
    }
  }

  /**
   * Cleanup dashboard resources
   */
  function destroy() {
    if (statsInterval) {
      clearInterval(statsInterval);
      statsInterval = null;
    }

    if (messagesChart) {
      ChartConfig.destroyChart(messagesChart);
      messagesChart = null;
    }

    if (usersChart) {
      ChartConfig.destroyChart(usersChart);
      usersChart = null;
    }
  }

  // Public API
  return {
    init,
    destroy,
    loadStats,
    loadRecentUsers
  };
})();
