/**
 * Infexor Chat Admin - Reports Management Module
 * Handle user-submitted reports with filtering and resolution
 */

const ReportsModule = (() => {
  let currentTable = null;
  let currentModal = null;
  let currentFilter = '';

  /**
   * Initialize reports module
   * @param {HTMLElement} container - Content container
   */
  function init(container) {
    container.innerHTML = `
      <div class="section-header">
        <div>
          <h2>Reports Management</h2>
          <p class="section-subtitle">Review and resolve user reports</p>
        </div>
      </div>

      <!-- Filter Tabs -->
      <div class="filter-tabs">
        <button class="filter-tab active" data-status="" onclick="ReportsModule.filterByStatus('')">
          All Reports
        </button>
        <button class="filter-tab" data-status="pending" onclick="ReportsModule.filterByStatus('pending')">
          Pending
        </button>
        <button class="filter-tab" data-status="reviewing" onclick="ReportsModule.filterByStatus('reviewing')">
          Reviewing
        </button>
        <button class="filter-tab" data-status="resolved" onclick="ReportsModule.filterByStatus('resolved')">
          Resolved
        </button>
        <button class="filter-tab" data-status="dismissed" onclick="ReportsModule.filterByStatus('dismissed')">
          Dismissed
        </button>
      </div>

      <div id="reportsTableWrapper"></div>
    `;

    loadReportsTable();
  }

  /**
   * Load reports table
   */
  function loadReportsTable() {
    const tableWrapper = document.getElementById('reportsTableWrapper');

    currentTable = Components.Table.create({
      columns: [
        {
          key: 'reporter',
          label: 'Reporter',
          render: (report) => {
            const reporter = report.reporterId || {};
            return `
              <div style="display: flex; align-items: center; gap: 10px;">
                <img src="${reporter.avatar || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(reporter.name || 'Unknown') + '&background=6366f1&color=fff&size=32'}"
                     class="table-avatar" style="width: 32px; height: 32px;"
                     alt="${Utils.escapeHtml(reporter.name || 'Unknown')}" />
                <div>
                  <div>${Utils.escapeHtml(reporter.name || 'Unknown User')}</div>
                  <small style="color: var(--text-muted);">${Utils.formatPhoneNumber(reporter.phone || '')}</small>
                </div>
              </div>
            `;
          }
        },
        {
          key: 'targetType',
          label: 'Type',
          width: '100px',
          render: (report) => `<span class="badge badge-secondary">${report.targetType}</span>`
        },
        {
          key: 'reason',
          label: 'Reason',
          width: '120px',
          render: (report) => {
            const reasonColors = {
              spam: 'warning',
              harassment: 'danger',
              hate_speech: 'danger',
              inappropriate_content: 'warning',
              fake_account: 'info',
              other: 'secondary'
            };
            const color = reasonColors[report.reason] || 'secondary';
            return `<span class="badge badge-${color}">${report.reason.replace('_', ' ')}</span>`;
          }
        },
        {
          key: 'status',
          label: 'Status',
          width: '110px',
          render: (report) => {
            const isUrgent = report.status === 'pending' &&
                           (Date.now() - new Date(report.createdAt).getTime()) > 86400000; // 24 hours
            return `
              <div style="display: flex; align-items: center; gap: 5px;">
                ${isUrgent ? '<span style="color: var(--warning);" title="Pending for over 24 hours">⚠️</span>' : ''}
                <span class="badge badge-${Utils.getStatusColor(report.status)}">${report.status}</span>
              </div>
            `;
          }
        },
        {
          key: 'createdAt',
          label: 'Reported',
          width: '130px',
          render: (report) => Utils.formatTimeAgo(report.createdAt)
        },
        {
          key: 'actions',
          label: 'Actions',
          width: '140px',
          render: (report) => `
            <div class="btn-group">
              <button class="btn btn-icon" onclick="ReportsModule.viewDetails('${report._id}')" title="View Details">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                  <circle cx="12" cy="12" r="3"/>
                </svg>
              </button>
              ${report.status === 'pending' || report.status === 'reviewing' ? `
                <button class="btn btn-icon btn-success" onclick="ReportsModule.quickResolve('${report._id}')" title="Quick Resolve">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                </button>
                <button class="btn btn-icon btn-danger" onclick="ReportsModule.dismissReport('${report._id}')" title="Dismiss">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
                  </svg>
                </button>
              ` : ''}
            </div>
          `
        }
      ],
      dataSource: fetchReports,
      searchable: false,
      filterable: false,
      onRowClick: (report) => viewDetails(report._id)
    });

    tableWrapper.innerHTML = '';
    tableWrapper.appendChild(currentTable);
  }

  /**
   * Fetch reports from API
   * @param {Object} state - Table state
   * @returns {Promise<Object>} Reports data with pagination
   */
  async function fetchReports(state) {
    const params = new URLSearchParams({
      page: state.page,
      limit: state.limit,
      status: currentFilter || ''
    });

    const response = await API.get(`/admin/reports?${params}`);

    return {
      items: response.data.reports || [],
      pagination: response.data.pagination || {
        page: state.page,
        totalPages: 1,
        total: 0,
        limit: state.limit
      }
    };
  }

  /**
   * Filter reports by status
   * @param {String} status - Status filter
   */
  function filterByStatus(status) {
    currentFilter = status;

    // Update active tab
    const tabs = document.querySelectorAll('.filter-tab');
    tabs.forEach(tab => {
      if (tab.dataset.status === status) {
        tab.classList.add('active');
      } else {
        tab.classList.remove('active');
      }
    });

    // Reload table
    if (currentTable) {
      currentTable._tableState.page = 1;
      Components.Table.refresh(currentTable);
    }
  }

  /**
   * View report details
   * @param {String} reportId - Report ID
   */
  async function viewDetails(reportId) {
    try {
      const response = await API.get(`/admin/reports?status=`);
      const report = (response.data.reports || []).find(r => r._id === reportId);

      if (!report) {
        Components.Toast.error('Report not found');
        return;
      }

      const reporter = report.reporterId || {};
      const target = report.targetId || {};

      currentModal = Components.Modal.open({
        title: 'Report Details',
        size: 'large',
        content: `
          <div class="report-detail">
            <!-- Reporter Info -->
            <div class="detail-section">
              <h4>Reporter Information</h4>
              <div class="user-info-compact">
                <img src="${reporter.avatar || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(reporter.name || 'Unknown') + '&background=6366f1&color=fff&size=48'}"
                     class="user-avatar-sm" alt="${Utils.escapeHtml(reporter.name || 'Unknown')}" />
                <div>
                  <strong>${Utils.escapeHtml(reporter.name || 'Unknown User')}</strong>
                  <p style="color: var(--text-muted); margin: 0;">${Utils.formatPhoneNumber(reporter.phone || 'N/A')}</p>
                </div>
              </div>
            </div>

            <!-- Report Details -->
            <div class="detail-section">
              <h4>Report Details</h4>
              <div class="detail-grid">
                <div class="detail-item">
                  <label>Target Type</label>
                  <p><span class="badge badge-secondary">${report.targetType}</span></p>
                </div>
                <div class="detail-item">
                  <label>Reason</label>
                  <p><span class="badge badge-warning">${report.reason.replace('_', ' ')}</span></p>
                </div>
                <div class="detail-item">
                  <label>Status</label>
                  <p><span class="badge badge-${Utils.getStatusColor(report.status)}">${report.status}</span></p>
                </div>
                <div class="detail-item">
                  <label>Reported At</label>
                  <p>${Utils.formatDateTime(report.createdAt)}</p>
                </div>
              </div>

              ${report.description ? `
                <div class="detail-item" style="margin-top: 15px;">
                  <label>Description</label>
                  <p>${Utils.escapeHtml(report.description)}</p>
                </div>
              ` : ''}
            </div>

            <!-- Resolution Form -->
            ${report.status !== 'resolved' && report.status !== 'dismissed' ? `
              <div class="detail-section">
                <h4>Resolve Report</h4>
                <form id="resolveForm">
                  <div class="form-group">
                    <label>Status <span class="required">*</span></label>
                    <select name="status" class="form-control" required>
                      <option value="pending" ${report.status === 'pending' ? 'selected' : ''}>Pending</option>
                      <option value="reviewing" ${report.status === 'reviewing' ? 'selected' : ''}>Reviewing</option>
                      <option value="resolved">Resolved</option>
                      <option value="dismissed">Dismissed</option>
                    </select>
                  </div>

                  <div class="form-group">
                    <label>Action Taken</label>
                    <select name="action" class="form-control">
                      <option value="">None</option>
                      <option value="warned">User Warned</option>
                      <option value="content_removed">Content Removed</option>
                      <option value="suspended">User Suspended</option>
                      <option value="banned">User Banned</option>
                    </select>
                  </div>

                  <div class="form-group">
                    <label>Review Notes</label>
                    <textarea name="reviewNote" class="form-control" rows="3" placeholder="Add notes about your decision..."></textarea>
                  </div>
                </form>
              </div>
            ` : report.reviewNote ? `
              <div class="detail-section">
                <h4>Resolution Details</h4>
                <div class="detail-item">
                  <label>Action Taken</label>
                  <p>${report.action || 'None'}</p>
                </div>
                <div class="detail-item">
                  <label>Review Notes</label>
                  <p>${Utils.escapeHtml(report.reviewNote)}</p>
                </div>
                ${report.resolvedAt ? `
                  <div class="detail-item">
                    <label>Resolved At</label>
                    <p>${Utils.formatDateTime(report.resolvedAt)}</p>
                  </div>
                ` : ''}
              </div>
            ` : ''}
          </div>
        `,
        buttons: report.status !== 'resolved' && report.status !== 'dismissed' ? [
          {
            label: 'Save',
            className: 'btn-primary',
            onClick: async (modal) => {
              const form = modal.querySelector('#resolveForm');
              const formData = new FormData(form);
              const status = formData.get('status');
              const action = formData.get('action');
              const reviewNote = formData.get('reviewNote');

              if ((status === 'resolved' || status === 'dismissed') && !action && !reviewNote) {
                Components.Toast.warning('Please add action taken or review notes');
                return;
              }

              await resolveReport(reportId, { status, action, reviewNote });
              Components.Modal.close(modal);
            }
          },
          {
            label: 'Cancel',
            className: 'btn-ghost',
            onClick: (modal) => Components.Modal.close(modal)
          }
        ] : [
          {
            label: 'Close',
            className: 'btn-ghost',
            onClick: (modal) => Components.Modal.close(modal)
          }
        ],
        onClose: () => currentModal = null
      });
    } catch (error) {
      console.error('Failed to load report details:', error);
      Components.Toast.error('Failed to load report details');
    }
  }

  /**
   * Resolve report
   * @param {String} reportId - Report ID
   * @param {Object} data - Resolution data
   */
  async function resolveReport(reportId, data) {
    try {
      await API.put(`/admin/reports/${reportId}`, data);
      Components.Toast.success('Report updated successfully');
      refresh();
    } catch (error) {
      console.error('Failed to resolve report:', error);
      Components.Toast.error(error.response?.data?.message || 'Failed to update report');
    }
  }

  /**
   * Quick resolve report
   * @param {String} reportId - Report ID
   */
  async function quickResolve(reportId) {
    const confirmed = await Components.Modal.confirm({
      title: 'Quick Resolve',
      content: '<p>Mark this report as resolved?</p>',
      confirmLabel: 'Resolve',
      confirmClass: 'btn-success',
      onConfirm: async () => {
        await resolveReport(reportId, { status: 'resolved', action: '', reviewNote: 'Quick resolved by admin' });
        return true;
      }
    });
  }

  /**
   * Dismiss report
   * @param {String} reportId - Report ID
   */
  async function dismissReport(reportId) {
    const confirmed = await Components.Modal.confirm({
      title: 'Dismiss Report',
      content: `
        <p>Dismiss this report?</p>
        <form id="dismissForm">
          <div class="form-group">
            <label>Reason for dismissal</label>
            <textarea name="reviewNote" class="form-control" rows="2" placeholder="Why is this report being dismissed?" required></textarea>
          </div>
        </form>
      `,
      confirmLabel: 'Dismiss',
      confirmClass: 'btn-danger',
      onConfirm: async (modal) => {
        const form = modal.querySelector('#dismissForm');
        const formData = new FormData(form);
        const reviewNote = formData.get('reviewNote');

        if (!reviewNote) {
          Components.Toast.warning('Please provide a reason for dismissal');
          return false;
        }

        await resolveReport(reportId, { status: 'dismissed', action: '', reviewNote });
        return true;
      }
    });
  }

  /**
   * Refresh reports table
   */
  function refresh() {
    if (currentTable) {
      Components.Table.refresh(currentTable);
    }
  }

  /**
   * Cleanup reports module
   */
  function destroy() {
    if (currentModal) {
      Components.Modal.close(currentModal);
      currentModal = null;
    }
    currentTable = null;
    currentFilter = '';
  }

  // Public API
  return {
    init,
    refresh,
    destroy,
    filterByStatus,
    viewDetails,
    resolveReport,
    quickResolve,
    dismissReport
  };
})();
