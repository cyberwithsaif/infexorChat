/**
 * Infexor Chat Admin - Broadcasts Module
 * Create and manage broadcast notifications to users
 */

const BroadcastsModule = (() => {
  let currentTable = null;
  let currentModal = null;
  let currentData = [];

  /**
   * Initialize broadcasts module
   * @param {HTMLElement} container - Content container
   */
  function init(container) {
    container.innerHTML = `
      <div class="section-header">
        <div>
          <h2>Broadcast Notifications</h2>
          <p class="section-subtitle">Send notifications to users</p>
        </div>
        <div class="section-actions">
          <button class="btn btn-primary" onclick="BroadcastsModule.createBroadcast()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 2L11 13"/><path d="M22 2L15 22 11 13 2 9l20-7z"/>
            </svg>
            Create Broadcast
          </button>
        </div>
      </div>
      <div id="broadcastsTableWrapper"></div>
    `;

    const tableWrapper = document.getElementById('broadcastsTableWrapper');

    currentTable = Components.Table.create({
      columns: [
        {
          key: 'title',
          label: 'Title',
          render: (broadcast) => `
            <div>
              <strong>${Utils.escapeHtml(broadcast.title)}</strong>
              <p style="color: var(--text-muted); margin: 4px 0 0 0; font-size: 13px;">
                ${Utils.escapeHtml((broadcast.content || '').substring(0, 60))}${broadcast.content && broadcast.content.length > 60 ? '...' : ''}
              </p>
            </div>
          `
        },
        {
          key: 'segment',
          label: 'Segment',
          width: '150px',
          render: (broadcast) => {
            const segmentLabels = {
              all: 'All Users',
              active_week: 'Active This Week',
              active_month: 'Active This Month'
            };
            return segmentLabels[broadcast.segment] || broadcast.segment;
          }
        },
        {
          key: 'recipientCount',
          label: 'Recipients',
          width: '110px',
          render: (broadcast) => Utils.formatNumber(broadcast.stats?.recipientCount || broadcast.recipientCount || 0)
        },
        {
          key: 'status',
          label: 'Status',
          width: '110px',
          render: (broadcast) => `<span class="badge badge-${Utils.getStatusColor(broadcast.status)}">${broadcast.status}</span>`
        },
        {
          key: 'sentAt',
          label: 'Sent At',
          width: '160px',
          render: (broadcast) => broadcast.sentAt ? Utils.formatDateTime(broadcast.sentAt) : '-'
        },
        {
          key: 'actions',
          label: 'Actions',
          width: '80px',
          render: (broadcast) => `
            <div class="btn-group">
              <button class="btn btn-icon" onclick="BroadcastsModule.viewDetails('${broadcast._id}')" title="View Details">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                  <circle cx="12" cy="12" r="3"/>
                </svg>
              </button>
            </div>
          `
        }
      ],
      dataSource: fetchBroadcasts,
      searchable: false,
      filterable: false,
      onRowClick: (broadcast) => viewDetails(broadcast._id)
    });

    tableWrapper.appendChild(currentTable);
  }

  /**
   * Fetch broadcasts from API
   * @param {Object} state - Table state
   * @returns {Promise<Object>} Broadcasts data with pagination
   */
  async function fetchBroadcasts(state) {
    try {
      const params = new URLSearchParams({
        page: state.page,
        limit: state.limit
      });

      const response = await API.get(`/admin/broadcasts?${params}`);
      currentData = response.data.broadcasts || [];

      return {
        items: currentData,
        pagination: response.data.pagination || {
          page: state.page,
          totalPages: 1,
          total: 0,
          limit: state.limit
        }
      };
    } catch (error) {
      // If broadcasts endpoint doesn't exist or returns error, return empty data
      console.error('Failed to fetch broadcasts:', error);
      return {
        items: [],
        pagination: { page: 1, totalPages: 1, total: 0, limit: state.limit }
      };
    }
  }

  /**
   * Create new broadcast
   */
  function createBroadcast() {
    currentModal = Components.Modal.open({
      title: 'Create Broadcast',
      size: 'large',
      content: `
        <form id="broadcastForm">
          <div class="form-group">
            <label>Title <span class="required">*</span></label>
            <input type="text" name="title" class="form-control" placeholder="Enter broadcast title" required minlength="5" maxlength="200" />
            <div class="char-counter">0 / 200</div>
          </div>

          <div class="form-group">
            <label>Content <span class="required">*</span></label>
            <textarea name="content" class="form-control" rows="5" placeholder="Enter your message" required minlength="10" maxlength="1000"></textarea>
            <div class="char-counter">0 / 1000</div>
          </div>

          <div class="form-group">
            <label>Target Audience <span class="required">*</span></label>
            <div class="radio-group">
              <label class="radio-label">
                <input type="radio" name="segment" value="active" checked />
                <span>Active Users (Recommended)</span>
              </label>
              <label class="radio-label">
                <input type="radio" name="segment" value="all" />
                <span>All Users</span>
              </label>
              <label class="radio-label">
                <input type="radio" name="segment" value="inactive" />
                <span>Inactive Users</span>
              </label>
            </div>
            <div class="form-help">
              Estimated recipients: <span id="estimatedRecipients">Calculating...</span>
            </div>
          </div>

          <!-- Preview Section -->
          <div class="broadcast-preview">
            <h4>Notification Preview</h4>
            <div class="notification-preview-card">
              <div class="notification-preview-icon">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M22 2L11 13"/><path d="M22 2L15 22 11 13 2 9l20-7z"/>
                </svg>
              </div>
              <div class="notification-preview-content">
                <strong id="previewTitle">Broadcast Title</strong>
                <p id="previewContent">Your message will appear here</p>
              </div>
            </div>
          </div>
        </form>
      `,
      buttons: [
        {
          label: 'Cancel',
          className: 'btn-ghost',
          onClick: (modal) => Components.Modal.close(modal)
        },
        {
          label: 'Send Now',
          className: 'btn-primary',
          onClick: async (modal) => {
            const form = modal.querySelector('#broadcastForm');
            const formData = new FormData(form);

            // Validate
            if (!form.checkValidity()) {
              form.reportValidity();
              return;
            }

            const title = formData.get('title');
            const content = formData.get('content');
            const segment = formData.get('segment');

            // Confirm before sending
            const confirmed = await Components.Modal.confirm({
              title: 'Confirm Broadcast',
              content: `
                <p>Send this broadcast to <strong>${document.getElementById('estimatedRecipients').textContent}</strong>?</p>
                <p style="color: var(--text-muted); margin-top: 10px;">This action cannot be undone.</p>
              `,
              confirmLabel: 'Send Broadcast',
              confirmClass: 'btn-primary'
            });

            if (confirmed) {
              await sendBroadcast({ title, content, segment });
              Components.Modal.close(modal);
            }
          }
        }
      ],
      onClose: () => currentModal = null
    });

    // Add character counters
    const titleInput = currentModal.querySelector('[name="title"]');
    const contentInput = currentModal.querySelector('[name="content"]');
    const counters = currentModal.querySelectorAll('.char-counter');

    titleInput.addEventListener('input', () => {
      counters[0].textContent = `${titleInput.value.length} / 200`;
      document.getElementById('previewTitle').textContent = titleInput.value || 'Broadcast Title';
    });

    contentInput.addEventListener('input', () => {
      counters[1].textContent = `${contentInput.value.length} / 1000`;
      document.getElementById('previewContent').textContent = contentInput.value || 'Your message will appear here';
    });

    // Estimate recipients
    estimateRecipients('active');

    // Update estimate on segment change
    const segmentRadios = currentModal.querySelectorAll('[name="segment"]');
    segmentRadios.forEach(radio => {
      radio.addEventListener('change', () => {
        if (radio.checked) {
          estimateRecipients(radio.value);
        }
      });
    });
  }

  /**
   * Estimate recipient count
   * @param {String} segment - Target segment
   */
  async function estimateRecipients(segment) {
    const estimateEl = document.getElementById('estimatedRecipients');
    if (!estimateEl) return;

    estimateEl.textContent = 'Calculating...';

    try {
      // Get dashboard stats for user counts
      const response = await API.get('/admin/dashboard/stats');
      const stats = response.data;

      let estimate = 0;
      switch (segment) {
        case 'all':
          estimate = stats.totalUsers || 0;
          break;
        case 'active':
          estimate = stats.activeUsers || stats.activeWeek || Math.floor((stats.totalUsers || 0) * 0.6);
          break;
        case 'inactive':
          estimate = Math.max(0, (stats.totalUsers || 0) - (stats.activeUsers || stats.activeWeek || 0));
          break;
      }

      estimateEl.textContent = `${Utils.formatNumber(estimate)} users`;
    } catch (error) {
      estimateEl.textContent = 'Unable to estimate';
    }
  }

  /**
   * Send broadcast
   * @param {Object} data - Broadcast data
   */
  async function sendBroadcast(data) {
    try {
      const response = await API.post('/admin/broadcasts', data);
      const recipientCount = response.data.broadcast?.recipientCount || 0;
      Components.Toast.success(`Broadcast sent to ${Utils.formatNumber(recipientCount)} users`);
      refresh();
    } catch (error) {
      console.error('Failed to send broadcast:', error);
      Components.Toast.error(error.response?.data?.message || 'Failed to send broadcast');
    }
  }

  /**
   * View broadcast details
   * @param {String} broadcastId - Broadcast ID
   */
  async function viewDetails(broadcastId) {
    try {
      const broadcast = currentData.find(b => b._id === broadcastId);

      if (!broadcast) {
        Components.Toast.error('Broadcast not found');
        return;
      }

      const segmentLabels = {
        all: 'All Users',
        active_week: 'Active This Week',
        active_month: 'Active This Month'
      };

      currentModal = Components.Modal.open({
        title: 'Broadcast Details',
        size: 'medium',
        content: `
          <div class="broadcast-detail">
            <div class="detail-section">
              <h4>${Utils.escapeHtml(broadcast.title)}</h4>
              <p style="color: var(--text-muted); margin-top: 10px; line-height: 1.6;">
                ${Utils.escapeHtml(broadcast.content)}
              </p>
            </div>

            <div class="detail-section">
              <h4>Broadcast Information</h4>
              <div class="detail-grid">
                <div class="detail-item">
                  <label>Segment</label>
                  <p>${segmentLabels[broadcast.segment] || broadcast.segment}</p>
                </div>
                <div class="detail-item">
                  <label>Recipients</label>
                  <p>${Utils.formatNumber(broadcast.stats?.recipientCount || broadcast.recipientCount || 0)}</p>
                </div>
                <div class="detail-item">
                  <label>Status</label>
                  <p><span class="badge badge-${Utils.getStatusColor(broadcast.status)}">${broadcast.status}</span></p>
                </div>
                <div class="detail-item">
                  <label>Sent At</label>
                  <p>${broadcast.sentAt ? Utils.formatDateTime(broadcast.sentAt) : 'Not sent'}</p>
                </div>
              </div>
            </div>

            ${broadcast.stats ? `
              <div class="detail-section">
                <h4>Delivery Statistics</h4>
                <div class="stats-grid-modal">
                  <div class="stat-item-modal">
                    <div class="stat-value-modal">${Utils.formatNumber(broadcast.stats.sentCount || 0)}</div>
                    <div class="stat-label-modal">Sent</div>
                  </div>
                  <div class="stat-item-modal">
                    <div class="stat-value-modal">${Utils.formatNumber(broadcast.stats.failedCount || 0)}</div>
                    <div class="stat-label-modal">Failed</div>
                  </div>
                  <div class="stat-item-modal">
                    <div class="stat-value-modal">${broadcast.stats.failedCount ? Math.round((broadcast.stats.sentCount / broadcast.stats.recipientCount) * 100) : 100}%</div>
                    <div class="stat-label-modal">Success Rate</div>
                  </div>
                </div>
              </div>
            ` : ''}
          </div>
        `,
        buttons: [
          {
            label: 'Close',
            className: 'btn-ghost',
            onClick: (modal) => Components.Modal.close(modal)
          }
        ],
        onClose: () => currentModal = null
      });
    } catch (error) {
      console.error('Failed to load broadcast details:', error);
      Components.Toast.error('Failed to load broadcast details');
    }
  }

  /**
   * Refresh broadcasts table
   */
  function refresh() {
    if (currentTable) {
      Components.Table.refresh(currentTable);
    }
  }

  /**
   * Cleanup broadcasts module
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
    createBroadcast,
    viewDetails
  };
})();
