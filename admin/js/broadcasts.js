/**
 * Infexor Chat Admin - Broadcasts Module
 * High-Performance BullMQ Broadcast Notification System
 */

const BroadcastsModule = (() => {
  let currentTable = null;
  let currentModal = null;
  let currentData = [];
  let pollingInterval = null;

  function init(container) {
    container.innerHTML = `
      <div class="card-header" style="margin-bottom: 24px;">
        <div>
          <h2>Broadcast Notifications</h2>
          <p class="section-subtitle" style="color: var(--text-muted); font-size: 13px;">Push massively via FCM & APNs</p>
        </div>
        <div class="card-actions">
          <button class="btn btn-primary" onclick="BroadcastsModule.createBroadcast()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 2L11 13"/><path d="M22 2L15 22 11 13 2 9l20-7z"/>
            </svg>
            Create Broadcast
          </button>
        </div>
      </div>
      
      <!-- Stats Container -->
      <div class="metrics-grid" id="broadcastStats">
        <div class="metric-card accent-blue"><div class="metric-label">Queue Size</div><div class="metric-value" id="statQueue">-</div></div>
        <div class="metric-card accent-orange"><div class="metric-label">Active Workers</div><div class="metric-value" id="statWorkers">-</div></div>
        <div class="metric-card accent-green"><div class="metric-label">Total Sent</div><div class="metric-value" id="statTotalSent">-</div></div>
        <div class="metric-card accent-purple"><div class="metric-label">Success Rate</div><div class="metric-value" id="statSuccessRate">-</div></div>
      </div>

      <div class="table-card" id="broadcastsTableWrapper" style="margin-top: 24px;"></div>
    `;

    loadStats();

    currentTable = Components.Table.create({
      columns: [
        {
          key: 'title',
          label: 'Title',
          width: '25%',
          render: (b) => `
            <div>
              <strong>${Utils.escapeHtml(b.title)}</strong>
              <p style="color: var(--text-muted); margin: 4px 0 0 0; font-size: 13px;">
                ${Utils.escapeHtml((b.message || '').substring(0, 50))}${b.message && b.message.length > 50 ? '...' : ''}
              </p>
            </div>
          `
        },
        {
          key: 'audience',
          label: 'Audience',
          width: '150px',
          render: (b) => {
            const seg = { all: 'All Users', active: 'Active Users', banned: 'Banned', custom: 'Custom' }[b.segment] || b.segment;
            const plat = { ios: 'iOS', android: 'Android', both: 'All Platforms' }[b.platform] || 'All';
            return `<div><div>${seg}</div><small style="color:var(--text-muted)">${plat}</small></div>`;
          }
        },
        {
          key: 'progress',
          label: 'Progress',
          width: '200px',
          render: (b) => {
            const total = b.totalRecipients || 0;
            const done = (b.successCount || 0) + (b.failureCount || 0);
            let percent = total > 0 ? Math.floor((done / total) * 100) : 0;
            if (b.status === 'sent') percent = 100;

            return `
               <div style="display:flex; flex-direction:column; gap:4px; width: 100%;">
                 <div style="display:flex; justify-content:space-between; font-size:12px;">
                   <span>${Utils.formatNumber(done)} / ${Utils.formatNumber(total)}</span>
                   <span>${percent}%</span>
                 </div>
                 <div style="width:100%; height:6px; background:var(--border-color); border-radius:3px; overflow:hidden;">
                   <div style="width:${percent}%; height:100%; background:var(--primary-color); transition:width 0.3s ease;"></div>
                 </div>
               </div>
             `;
          }
        },
        {
          key: 'status',
          label: 'Status',
          width: '100px',
          render: (b) => {
            let color = 'secondary';
            if (b.status === 'sending') color = 'warning';
            if (b.status === 'sent') color = 'success';
            if (b.status === 'failed') color = 'danger';
            if (b.status === 'queued') color = 'info';
            return `<span class="badge badge-${color}">${b.status}</span>`;
          }
        },
        {
          key: 'sentAt',
          label: 'Created',
          width: '140px',
          render: (b) => Utils.formatDateTime(b.createdAt)
        },
        {
          key: 'actions',
          label: 'Actions',
          width: '60px',
          render: (b) => `
            <div class="btn-group">
              <button class="btn btn-icon" onclick="BroadcastsModule.viewDetails('${b._id}')" title="View Details">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
                </svg>
              </button>
            </div>
          `
        }
      ],
      dataSource: fetchBroadcasts,
      searchable: false,
      filterable: false,
    });

    document.getElementById('broadcastsTableWrapper').appendChild(currentTable);

    // Auto-polling for progress
    startPolling();
  }

  async function loadStats() {
    try {
      const res = await API.get('/admin/broadcasts/stats');
      const data = res.data;
      document.getElementById('statQueue').textContent = Utils.formatNumber(data.queueSize);
      document.getElementById('statWorkers').textContent = data.activeCount;
      document.getElementById('statTotalSent').textContent = Utils.formatNumber(data.totalSuccess);
      document.getElementById('statSuccessRate').textContent = `${data.successRate.toFixed(1)}%`;
    } catch (e) { }
  }

  function startPolling() {
    if (pollingInterval) clearInterval(pollingInterval);
    pollingInterval = setInterval(() => {
      // Only refresh if there are active broadcasts
      const hasActive = currentData.some(b => b.status === 'sending' || b.status === 'queued');
      if (hasActive) {
        refresh();
        loadStats();
      }
    }, 3000);
  }

  async function fetchBroadcasts(state) {
    try {
      const params = new URLSearchParams({ page: state.page, limit: state.limit });
      const response = await API.get(`/admin/broadcasts?${params}`);
      currentData = response.data.broadcasts || [];
      return {
        items: currentData,
        pagination: response.data.pagination || { page: state.page, totalPages: 1, total: 0, limit: state.limit }
      };
    } catch (error) {
      return { items: [], pagination: { page: 1, totalPages: 1, total: 0, limit: state.limit } };
    }
  }

  function createBroadcast() {
    currentModal = Components.Modal.open({
      title: 'Create Bulk Push Broadcast',
      size: 'large',
      content: `
        <form id="broadcastForm">
          <div class="form-group">
            <label>Push Title <span class="required">*</span></label>
            <input type="text" name="title" class="form-control" placeholder="Flash Sale / Important Update" required minlength="2" maxlength="200" />
          </div>

          <div class="form-group">
            <label>Push Message <span class="required">*</span></label>
            <textarea name="message" class="form-control" rows="4" placeholder="Enter notification body..." required minlength="5" maxlength="1000"></textarea>
          </div>

          <div style="display:flex; gap: 20px; flex-wrap: wrap;">
            <div class="form-group" style="flex:1">
              <label>Target Segment <span class="required">*</span></label>
              <select name="segment" class="form-control" required>
                <option value="active">Active Users (7 days)</option>
                <option value="all">All Registered Users</option>
                <option value="banned">Banned Users</option>
              </select>
            </div>
            <div class="form-group" style="flex:1">
              <label>Platform Target <span class="required">*</span></label>
              <select name="platform" class="form-control" required>
                <option value="both">Both (iOS & Android)</option>
                <option value="android">Android Only (FCM)</option>
                <option value="ios">iOS Only (APNs)</option>
              </select>
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
          label: 'Dispatch to Queue',
          className: 'btn-primary',
          onClick: async (modal, btn) => {
            const form = modal.querySelector('#broadcastForm');
            if (!form.checkValidity()) return form.reportValidity();

            const title = form.querySelector('[name="title"]').value;
            const message = form.querySelector('[name="message"]').value;
            const segment = form.querySelector('[name="segment"]').value;
            const platform = form.querySelector('[name="platform"]').value;

            const confirmed = await Components.Modal.confirm({
              title: 'Confirm Mass Push',
              content: '<p>You are about to enqueue a massive push notification to device tokens via Firebase and APNs.</p><p style="color:#e74c3c; margin-top:10px; font-weight:bold;">This action cannot be undone once processing begins.</p>',
              confirmLabel: 'Yes, Send Now',
              confirmClass: 'btn-danger'
            });

            if (confirmed) {
              btn.disabled = true;
              btn.textContent = 'Queuing...';
              try {
                await API.post('/admin/broadcasts', { title, message, segment, platform });
                Components.Toast.success('Broadcast successfully added to BullMQ!');
                Components.Modal.close(modal);
                refresh();
                loadStats();
              } catch (e) {
                btn.disabled = false;
                btn.textContent = 'Dispatch to Queue';
                Components.Toast.error(e.response?.data?.message || 'Failed to dispatch broadcast');
              }
            }
          }
        }
      ],
      onClose: () => currentModal = null
    });
  }

  function viewDetails(broadcastId) {
    const broadcast = currentData.find(b => b._id === broadcastId);
    if (!broadcast) return Components.Toast.error('Broadcast not found');

    const total = broadcast.totalRecipients || 0;
    const success = broadcast.successCount || 0;
    const failed = broadcast.failureCount || 0;
    const sr = total > 0 ? ((success / total) * 100).toFixed(1) : 0;

    currentModal = Components.Modal.open({
      title: 'Broadcast Dispatch Details',
      size: 'medium',
      content: `
        <div class="broadcast-detail">
          <div class="detail-section">
            <h4>${Utils.escapeHtml(broadcast.title)}</h4>
            <p style="color: var(--text-muted); margin-top: 10px; line-height: 1.6;">${Utils.escapeHtml(broadcast.message)}</p>
          </div>

          <div class="detail-section">
            <h4>Audience & Status</h4>
            <div class="detail-grid">
              <div class="detail-item"><label>Platform</label><p style="text-transform:capitalize;">${broadcast.platform}</p></div>
              <div class="detail-item"><label>Segment</label><p style="text-transform:capitalize;">${broadcast.segment}</p></div>
              <div class="detail-item"><label>Status</label><p><span class="badge badge-info">${broadcast.status}</span></p></div>
              <div class="detail-item"><label>Created By</label><p>${broadcast.createdBy?.username || 'Admin'}</p></div>
            </div>
          </div>

          <div class="detail-section">
            <h4>Push Delivery Statistics</h4>
            <div class="stats-grid-modal" style="display:flex; justify-content:space-between; gap:10px; text-align:center; margin-top:15px;">
              <div style="flex:1; background:var(--bg-secondary); padding:15px; border-radius:8px;">
                <div style="font-size:24px; font-weight:bold; color:var(--text-color);">${Utils.formatNumber(total)}</div>
                <div style="font-size:12px; color:var(--text-muted);">Target Pool</div>
              </div>
              <div style="flex:1; background:var(--bg-secondary); padding:15px; border-radius:8px;">
                <div style="font-size:24px; font-weight:bold; color:var(--success-color);">${Utils.formatNumber(success)}</div>
                <div style="font-size:12px; color:var(--text-muted);">Delivered</div>
              </div>
              <div style="flex:1; background:var(--bg-secondary); padding:15px; border-radius:8px;">
                <div style="font-size:24px; font-weight:bold; color:var(--danger-color);">${Utils.formatNumber(failed)}</div>
                <div style="font-size:12px; color:var(--text-muted);">Failed/Dead Tokens</div>
              </div>
              <div style="flex:1; background:var(--bg-secondary); padding:15px; border-radius:8px;">
                <div style="font-size:24px; font-weight:bold; color:var(--primary-color);">${sr}%</div>
                <div style="font-size:12px; color:var(--text-muted);">Success Rate</div>
              </div>
            </div>
          </div>
        </div>
      `,
      buttons: [{ label: 'Close', className: 'btn-ghost', onClick: (modal) => Components.Modal.close(modal) }],
      onClose: () => currentModal = null
    });
  }

  function refresh() { if (currentTable) Components.Table.refresh(currentTable); }
  function destroy() {
    if (currentModal) { Components.Modal.close(currentModal); currentModal = null; }
    if (pollingInterval) { clearInterval(pollingInterval); pollingInterval = null; }
    currentTable = null; currentData = [];
  }

  return { init, refresh, destroy, createBroadcast, viewDetails };
})();
