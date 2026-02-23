/**
 * Infexor Chat Admin - Users Management Module
 * Complete user management with search, filter, pagination, and actions
 */

const UsersModule = (() => {
  let currentTable = null;
  let currentModal = null;
  let currentData = [];

  /**
   * Initialize users module
   * @param {HTMLElement} container - Content container
   */
  function init(container) {
    container.innerHTML = `
      <div class="section-header">
        <div>
          <h2>User Management</h2>
          <p class="section-subtitle">Manage and monitor all users</p>
        </div>
        <div class="section-actions">
          <button class="btn btn-secondary" onclick="UsersModule.exportCSV()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
              <polyline points="7 10 12 15 17 10"/>
              <line x1="12" y1="15" x2="12" y2="3"/>
            </svg>
            Export CSV
          </button>
        </div>
      </div>
      <div id="usersTableWrapper"></div>
    `;

    const tableWrapper = document.getElementById('usersTableWrapper');

    currentTable = Components.Table.create({
      columns: [
        {
          key: 'avatar',
          label: '',
          width: '60px',
          render: (user) => `
            <div class="table-avatar-wrapper">
              <img src="${user.avatar || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(user.name) + '&background=6366f1&color=fff'}"
                   class="table-avatar"
                   alt="${Utils.escapeHtml(user.name)}" />
              ${user.isOnline ? '<span class="status-dot online"></span>' : ''}
            </div>
          `
        },
        {
          key: 'name',
          label: 'Name',
          render: (user) => Utils.escapeHtml(user.name)
        },
        {
          key: 'phone',
          label: 'Phone',
          render: (user) => Utils.formatPhoneNumber(user.phone)
        },
        {
          key: 'status',
          label: 'Status',
          width: '120px',
          render: (user) => `<span class="badge badge-${Utils.getStatusColor(user.status)}">${user.status}</span>`
        },
        {
          key: 'lastSeen',
          label: 'Last Seen',
          width: '150px',
          render: (user) => Utils.formatTimeAgo(user.lastSeen)
        },
        {
          key: 'actions',
          label: 'Actions',
          width: '160px',
          render: (user) => `
            <div class="btn-group">
              <button class="btn btn-icon" onclick="UsersModule.viewDetails('${user._id}')" title="View Details">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                  <circle cx="12" cy="12" r="3"/>
                </svg>
              </button>
              <button class="btn btn-icon" onclick="UsersModule.changeStatus('${user._id}')" title="Change Status">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                  <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                </svg>
              </button>
              <button class="btn btn-icon btn-danger" onclick="UsersModule.forceLogout('${user._id}')" title="Force Logout">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M18.36 6.64a9 9 0 1 1-12.73 0"/>
                  <line x1="12" y1="2" x2="12" y2="12"/>
                </svg>
              </button>
            </div>
          `
        }
      ],
      dataSource: fetchUsers,
      searchable: true,
      searchPlaceholder: 'Search by name or phone...',
      filterable: true,
      filters: [
        {
          key: 'status',
          label: 'Status',
          type: 'select',
          options: [
            { value: '', label: 'All Status' },
            { value: 'active', label: 'Active' },
            { value: 'suspended', label: 'Suspended' },
            { value: 'banned', label: 'Banned' }
          ]
        }
      ],
      onRowClick: (user) => viewDetails(user._id)
    });

    tableWrapper.appendChild(currentTable);
  }

  /**
   * Fetch users from API
   * @param {Object} state - Table state (page, limit, search, filters)
   * @returns {Promise<Object>} Users data with pagination
   */
  async function fetchUsers(state) {
    const params = new URLSearchParams({
      page: state.page,
      limit: state.limit,
      search: state.search || '',
      status: state.filters.status || ''
    });

    const response = await API.get(`/admin/users?${params}`);

    // Store current data for CSV export
    currentData = response.data.users || [];

    return {
      items: response.data.users || [],
      pagination: response.data.pagination || {
        page: state.page,
        totalPages: 1,
        total: 0,
        limit: state.limit
      }
    };
  }

  /**
   * View user details in modal
   * @param {String} userId - User ID
   */
  async function viewDetails(userId) {
    try {
      const response = await API.get(`/admin/users/${userId}`);
      const { user, stats } = response.data;

      currentModal = Components.Modal.open({
        title: 'User Details',
        size: 'large',
        content: `
          <div class="user-detail">
            <div class="user-detail-header">
              <img src="${user.avatar || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(user.name) + '&background=6366f1&color=fff&size=128'}"
                   class="user-detail-avatar"
                   alt="${Utils.escapeHtml(user.name)}" />
              <div class="user-detail-info">
                <h3>${Utils.escapeHtml(user.name)}</h3>
                <p class="user-phone">${Utils.formatPhoneNumber(user.phone)}</p>
                <div style="display: flex; gap: 10px; align-items: center; margin-top: 8px;">
                  <span class="badge badge-${Utils.getStatusColor(user.status)}">${user.status}</span>
                  ${user.isOnline ? '<span class="status-dot online" style="position: relative; margin: 0;">Online</span>' : '<span class="status-dot" style="position: relative; margin: 0;">Offline</span>'}
                </div>
              </div>
            </div>

            <div class="tabs">
              <button class="tab active" data-tab="profile">Profile</button>
              <button class="tab" data-tab="stats">Statistics</button>
              <button class="tab" data-tab="privacy">Privacy</button>
            </div>

            <div class="tab-content">
              <div id="tab-profile" class="tab-panel active">
                <div class="detail-grid">
                  <div class="detail-item">
                    <label>About</label>
                    <p>${Utils.escapeHtml(user.about || 'No about text')}</p>
                  </div>
                  <div class="detail-item">
                    <label>Joined</label>
                    <p>${Utils.formatDateTime(user.createdAt)}</p>
                  </div>
                  <div class="detail-item">
                    <label>Last Seen</label>
                    <p>${Utils.formatDateTime(user.lastSeen)}</p>
                  </div>
                  <div class="detail-item">
                    <label>User ID</label>
                    <p><code>${user._id}</code></p>
                  </div>
                </div>
              </div>

              <div id="tab-stats" class="tab-panel">
                <div class="stats-grid-modal">
                  <div class="stat-item-modal">
                    <div class="stat-value-modal">${Utils.formatNumber(stats.messageCount || 0)}</div>
                    <div class="stat-label-modal">Messages Sent</div>
                  </div>
                  <div class="stat-item-modal">
                    <div class="stat-value-modal">${Utils.formatNumber(stats.chatCount || 0)}</div>
                    <div class="stat-label-modal">Active Chats</div>
                  </div>
                  <div class="stat-item-modal">
                    <div class="stat-value-modal">${Utils.formatNumber(stats.groupCount || 0)}</div>
                    <div class="stat-label-modal">Groups Joined</div>
                  </div>
                </div>
              </div>

              <div id="tab-privacy" class="tab-panel">
                <div class="detail-grid">
                  <div class="detail-item">
                    <label>Last Seen Visibility</label>
                    <p>${user.privacySettings?.lastSeen || 'everyone'}</p>
                  </div>
                  <div class="detail-item">
                    <label>Profile Photo Visibility</label>
                    <p>${user.privacySettings?.profilePhoto || 'everyone'}</p>
                  </div>
                  <div class="detail-item">
                    <label>About Visibility</label>
                    <p>${user.privacySettings?.about || 'everyone'}</p>
                  </div>
                  <div class="detail-item">
                    <label>Read Receipts</label>
                    <p>${user.privacySettings?.readReceipts ? 'Enabled' : 'Disabled'}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        `,
        buttons: [
          {
            label: 'Change Status',
            className: 'btn-secondary',
            onClick: () => {
              Components.Modal.close(currentModal);
              changeStatus(userId);
            }
          },
          {
            label: 'Force Logout',
            className: 'btn-danger',
            onClick: () => {
              Components.Modal.close(currentModal);
              forceLogout(userId);
            }
          },
          {
            label: 'Close',
            className: 'btn-ghost',
            onClick: () => Components.Modal.close(currentModal)
          }
        ],
        onClose: () => currentModal = null
      });

      // Tab switching
      const tabs = currentModal.querySelectorAll('.tab');
      const panels = currentModal.querySelectorAll('.tab-panel');

      tabs.forEach(tab => {
        tab.addEventListener('click', () => {
          tabs.forEach(t => t.classList.remove('active'));
          panels.forEach(p => p.classList.remove('active'));

          tab.classList.add('active');
          const panel = currentModal.querySelector(`#tab-${tab.dataset.tab}`);
          if (panel) panel.classList.add('active');
        });
      });
    } catch (error) {
      console.error('Failed to load user details:', error);
      Components.Toast.error('Failed to load user details');
    }
  }

  /**
   * Change user status
   * @param {String} userId - User ID
   */
  async function changeStatus(userId) {
    try {
      // Get current user data
      const response = await API.get(`/admin/users/${userId}`);
      const user = response.data.user;

      const confirmed = await Components.Modal.confirm({
        title: 'Change User Status',
        content: `
          <p style="margin-bottom: 20px;">Change status for <strong>${Utils.escapeHtml(user.name)}</strong></p>
          <form id="statusForm">
            <div class="form-group">
              <label>New Status <span class="required">*</span></label>
              <select name="status" class="form-control" required>
                <option value="active" ${user.status === 'active' ? 'selected' : ''}>Active</option>
                <option value="suspended" ${user.status === 'suspended' ? 'selected' : ''}>Suspended</option>
                <option value="banned" ${user.status === 'banned' ? 'selected' : ''}>Banned</option>
              </select>
            </div>
          </form>
        `,
        confirmLabel: 'Update Status',
        confirmClass: 'btn-primary',
        onConfirm: async (modal) => {
          const form = modal.querySelector('#statusForm');
          const formData = new FormData(form);
          const newStatus = formData.get('status');

          if (newStatus === user.status) {
            Components.Toast.info('Status unchanged');
            return false;
          }

          await API.put(`/admin/users/${userId}/status`, { status: newStatus });
          Components.Toast.success(`User status updated to ${newStatus}`);
          refresh();
          return true;
        }
      });
    } catch (error) {
      console.error('Failed to change status:', error);
      Components.Toast.error(error.response?.data?.message || 'Failed to update status');
    }
  }

  /**
   * Force logout user
   * @param {String} userId - User ID
   */
  async function forceLogout(userId) {
    try {
      // Get user data for confirmation
      const response = await API.get(`/admin/users/${userId}`);
      const user = response.data.user;

      const confirmed = await Components.Modal.confirm({
        title: 'Force Logout User',
        content: `
          <p>Are you sure you want to force logout <strong>${Utils.escapeHtml(user.name)}</strong>?</p>
          <p style="color: var(--text-muted); margin-top: 10px;">They will need to log in again on all devices.</p>
        `,
        confirmLabel: 'Force Logout',
        confirmClass: 'btn-danger',
        onConfirm: async () => {
          await API.post(`/admin/users/${userId}/force-logout`);
          Components.Toast.success('User logged out successfully');
          refresh();
          return true;
        }
      });
    } catch (error) {
      console.error('Failed to force logout:', error);
      Components.Toast.error(error.response?.data?.message || 'Failed to logout user');
    }
  }

  /**
   * Export users to CSV
   */
  function exportCSV() {
    if (!currentData || currentData.length === 0) {
      Components.Toast.warning('No data to export');
      return;
    }

    const csvData = currentData.map(user => ({
      Name: user.name,
      Phone: user.phone,
      Status: user.status,
      'Last Seen': new Date(user.lastSeen).toLocaleString(),
      Joined: new Date(user.createdAt).toLocaleString()
    }));

    const filename = `users-export-${new Date().toISOString().split('T')[0]}.csv`;
    Utils.downloadCSV(csvData, filename);
    Components.Toast.success('Users exported successfully');
  }

  /**
   * Refresh users table
   */
  function refresh() {
    if (currentTable) {
      Components.Table.refresh(currentTable);
    }
  }

  /**
   * Cleanup users module
   */
  function destroy() {
    if (currentModal) {
      Components.Modal.close(currentModal);
      currentModal = null;
    }
    currentTable = null;
    currentData = [];
  }

  // Public API
  return {
    init,
    refresh,
    destroy,
    viewDetails,
    changeStatus,
    forceLogout,
    exportCSV
  };
})();
