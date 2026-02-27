/**
 * Infexor Chat Admin - Broadcasts Module
 */

const BroadcastsModule = (() => {
  let currentTable = null;
  let currentModal = null;
  let currentData = [];
  let selectedPlatform = 'both';

  const ICONS = {
    android: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24A9.88 9.88 0 0 0 12 8c-1.63 0-3.16.39-4.47 1.07L5.65 5.83c-.18-.28-.54-.37-.83-.22-.3.16-.42.54-.26.85l1.84 3.18C3.93 11.06 2.5 13.38 2.5 16h19c0-2.62-1.43-4.94-3.9-6.52M9 13.5a1 1 0 1 1 0-2 1 1 0 0 1 0 2m6 0a1 1 0 1 1 0-2 1 1 0 0 1 0 2"/></svg>`,
    ios: `<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11"/></svg>`,
    both: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>`,
    send: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22 11 13 2 9l20-7z"/></svg>`
  };

  function init(container) {
    container.innerHTML = `
      <div class="section-header">
        <div>
          <h2>Broadcast Notifications</h2>
          <p class="section-subtitle">Send push notifications to your users</p>
        </div>
        <div class="section-actions">
          <button class="btn btn-primary" onclick="BroadcastsModule.createBroadcast()">
            ${ICONS.send} Create Broadcast
          </button>
        </div>
      </div>
      <div id="broadcastsTableWrapper"></div>
    `;

    currentTable = Components.Table.create({
      columns: [
        {
          key: 'title',
          label: 'Title / Message',
          render: (b) => `
            <div>
              <strong style="color:var(--text)">${Utils.escapeHtml(b.title)}</strong>
              <p style="color:var(--text-muted);margin:3px 0 0;font-size:12px;line-height:1.4">
                ${Utils.escapeHtml((b.message || '').substring(0, 80))}${b.message && b.message.length > 80 ? '\u2026' : ''}
              </p>
            </div>`
        },
        {
          key: 'segment',
          label: 'Audience',
          width: '120px',
          render: (b) => {
            const map = { all: 'All Users', active: 'Active', banned: 'Banned', custom: 'Custom' };
            const colors = { all: 'blue', active: 'success', banned: 'danger', custom: 'purple' };
            return `<span class="badge badge-${colors[b.segment] || 'blue'}">${map[b.segment] || b.segment}</span>`;
          }
        },
        {
          key: 'platform',
          label: 'Platform',
          width: '100px',
          render: (b) => {
            const icon = ICONS[b.platform] || ICONS.both;
            const labels = { android: 'Android', ios: 'iOS', both: 'All' };
            return `<span style="display:inline-flex;align-items:center;gap:5px;color:var(--text-muted)">${icon} ${labels[b.platform] || 'All'}</span>`;
          }
        },
        {
          key: 'totalRecipients',
          label: 'Recipients',
          width: '95px',
          render: (b) => `<span style="font-weight:600">${Utils.formatNumber(b.totalRecipients || 0)}</span>`
        },
        {
          key: 'status',
          label: 'Status',
          width: '95px',
          render: (b) => {
            const colors = { sent: 'success', failed: 'danger', sending: 'warning', queued: 'blue', draft: 'purple' };
            return `<span class="badge badge-${colors[b.status] || 'blue'}">${b.status}</span>`;
          }
        },
        {
          key: 'sentAt',
          label: 'Sent At',
          width: '145px',
          render: (b) => b.sentAt
            ? `<span style="color:var(--text-muted);font-size:12px">${Utils.formatDateTime(b.sentAt)}</span>`
            : '<span style="color:var(--text-dim)">\u2014</span>'
        },
        {
          key: 'actions',
          label: '',
          width: '46px',
          render: (b) => `
            <button class="btn btn-icon" onclick="event.stopPropagation();BroadcastsModule.viewDetails('${b._id}')" title="View Details">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                <circle cx="12" cy="12" r="3"/>
              </svg>
            </button>`
        }
      ],
      dataSource: fetchBroadcasts,
      searchable: true,
      searchPlaceholder: 'Search by title or message\u2026',
      filterable: true,
      filters: [
        {
          key: 'status',
          label: 'Status',
          options: [
            { value: '', label: 'All Status' },
            { value: 'sent', label: 'Sent' },
            { value: 'sending', label: 'Sending' },
            { value: 'queued', label: 'Queued' },
            { value: 'failed', label: 'Failed' },
            { value: 'draft', label: 'Draft' }
          ]
        },
        {
          key: 'segment',
          label: 'Audience',
          options: [
            { value: '', label: 'All Audiences' },
            { value: 'active', label: 'Active Users' },
            { value: 'all', label: 'All Users' },
            { value: 'banned', label: 'Banned Users' }
          ]
        },
        {
          key: 'platform',
          label: 'Platform',
          options: [
            { value: '', label: 'All Platforms' },
            { value: 'android', label: 'Android' },
            { value: 'ios', label: 'iOS' },
            { value: 'both', label: 'Both' }
          ]
        }
      ],
      onRowClick: (b) => viewDetails(b._id)
    });

    document.getElementById('broadcastsTableWrapper').appendChild(currentTable);
  }

  async function fetchBroadcasts(state) {
    try {
      const params = new URLSearchParams({ page: state.page, limit: state.limit });
      const response = await API.get(`/admin/broadcasts?${params}`);
      currentData = response.data.broadcasts || [];

      // Client-side search + filter
      let items = [...currentData];
      if (state.search) {
        const q = state.search.toLowerCase();
        items = items.filter(b =>
          (b.title || '').toLowerCase().includes(q) ||
          (b.message || '').toLowerCase().includes(q)
        );
      }
      if (state.filters?.status) items = items.filter(b => b.status === state.filters.status);
      if (state.filters?.segment) items = items.filter(b => b.segment === state.filters.segment);
      if (state.filters?.platform) items = items.filter(b => b.platform === state.filters.platform);

      const pag = response.data.pagination || {};
      return {
        items,
        pagination: {
          page: pag.page || state.page,
          totalPages: pag.totalPages || pag.pages || 1,
          total: items.length,
          limit: pag.limit || state.limit
        }
      };
    } catch (error) {
      console.error('Failed to fetch broadcasts:', error);
      return { items: [], pagination: { page: 1, totalPages: 1, total: 0, limit: state.limit } };
    }
  }

  function createBroadcast() {
    selectedPlatform = 'both';

    currentModal = Components.Modal.open({
      title: 'Create Broadcast',
      size: 'large',
      content: `
        <form id="broadcastForm" novalidate>
          <div class="form-group">
            <label>Title <span class="required">*</span></label>
            <input type="text" id="bc-title" class="form-control"
              placeholder="e.g. New Feature Available!" maxlength="200" autocomplete="off" />
            <div class="char-counter" id="titleCounter">0 / 200</div>
            <div class="form-error" id="titleError"></div>
          </div>

          <div class="form-group">
            <label>Message <span class="required">*</span></label>
            <textarea id="bc-message" class="form-control" rows="4"
              placeholder="Write your notification message here\u2026" maxlength="1000"></textarea>
            <div class="char-counter" id="messageCounter">0 / 1000</div>
            <div class="form-error" id="messageError"></div>
          </div>

          <div class="form-group">
            <label>Action URL <span style="color:var(--text-dim);font-weight:400">(optional)</span></label>
            <input type="url" id="bc-link" class="form-control"
              placeholder="https://example.com" autocomplete="off" />
            <div class="form-help" style="margin-top:4px">
              Users will be taken to this URL when they tap the notification.
            </div>
            <div class="form-error" id="linkError"></div>
          </div>

          <div class="form-group">
            <label>Target Platform</label>
            <div class="platform-toggle" id="platformToggle">
              <button type="button" class="platform-btn active" data-platform="both">
                ${ICONS.both} All Devices
              </button>
              <button type="button" class="platform-btn" data-platform="android">
                ${ICONS.android} Android Only
              </button>
              <button type="button" class="platform-btn" data-platform="ios">
                ${ICONS.ios} iOS Only
              </button>
            </div>
          </div>

          <div class="form-group">
            <label>Target Audience <span class="required">*</span></label>
            <div class="radio-group">
              <label class="radio-label">
                <input type="radio" name="segment" value="active" checked />
                <span>
                  <strong>Active Users</strong> &mdash; Recommended<br>
                  <small style="color:var(--text-muted)">Users active in the last 7 days</small>
                </span>
              </label>
              <label class="radio-label">
                <input type="radio" name="segment" value="all" />
                <span>
                  <strong>All Users</strong><br>
                  <small style="color:var(--text-muted)">Every registered user</small>
                </span>
              </label>
              <label class="radio-label">
                <input type="radio" name="segment" value="banned" />
                <span>
                  <strong>Banned Users</strong><br>
                  <small style="color:var(--text-muted)">Users with restricted access</small>
                </span>
              </label>
            </div>
            <div class="form-help" style="margin-top:8px">
              Estimated recipients:
              <strong id="estimatedRecipients" style="color:var(--primary)">Calculating\u2026</strong>
            </div>
          </div>

          <div class="broadcast-preview">
            <h4>Notification Preview</h4>
            <div class="notification-preview-card">
              <div class="notification-preview-icon">${ICONS.send}</div>
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
          onClick: () => {
            Components.Modal.close(currentModal);
            currentModal = null;
          }
        },
        {
          label: 'Send Now',
          className: 'btn-primary',
          onClick: async (innerModal) => {
            if (!validateForm(innerModal)) return;
            const title = innerModal.querySelector('#bc-title').value.trim();
            const message = innerModal.querySelector('#bc-message').value.trim();
            const link = innerModal.querySelector('#bc-link').value.trim();
            const segment = innerModal.querySelector('[name="segment"]:checked')?.value || 'active';
            const estimateText = document.getElementById('estimatedRecipients')?.textContent || 'selected users';

            const confirmed = await Components.Modal.confirm({
              title: 'Confirm Broadcast',
              content: `
                <div style="display:flex;flex-direction:column;gap:12px">
                  <div style="background:var(--bg-hover);border-radius:8px;padding:12px 14px;border:1px solid var(--border)">
                    <strong style="font-size:15px">${Utils.escapeHtml(title)}</strong>
                    <p style="color:var(--text-muted);margin-top:4px;font-size:13px">${Utils.escapeHtml(message)}</p>
                  </div>
                  <p>Will send to <strong style="color:var(--primary)">${estimateText}</strong>
                     on <strong>${selectedPlatform === 'both' ? 'all devices' : selectedPlatform}</strong>.</p>
                  <p style="color:var(--warning);font-size:12px">\u26a0 This action cannot be undone.</p>
                </div>`,
              confirmLabel: 'Send Broadcast',
              confirmClass: 'btn-primary'
            });

            if (confirmed) {
              await sendBroadcast({ title, message, link, segment, platform: selectedPlatform });
              if (currentModal) {
                Components.Modal.close(currentModal);
                currentModal = null;
              }
            }
          }
        }
      ],
      onClose: () => { currentModal = null; selectedPlatform = 'both'; }
    });

    // Platform toggle
    currentModal.querySelectorAll('.platform-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        currentModal.querySelectorAll('.platform-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        selectedPlatform = btn.dataset.platform;
        estimateRecipients(currentModal.querySelector('[name="segment"]:checked')?.value || 'active');
      });
    });

    const titleInput = currentModal.querySelector('#bc-title');
    const messageInput = currentModal.querySelector('#bc-message');

    titleInput.addEventListener('input', () => {
      currentModal.querySelector('#titleCounter').textContent = `${titleInput.value.length} / 200`;
      currentModal.querySelector('#previewTitle').textContent = titleInput.value || 'Broadcast Title';
      currentModal.querySelector('#titleError').textContent = '';
    });

    messageInput.addEventListener('input', () => {
      currentModal.querySelector('#messageCounter').textContent = `${messageInput.value.length} / 1000`;
      currentModal.querySelector('#previewContent').textContent = messageInput.value || 'Your message will appear here';
      currentModal.querySelector('#messageError').textContent = '';
    });

    estimateRecipients('active');
    currentModal.querySelectorAll('[name="segment"]').forEach(r => {
      r.addEventListener('change', () => { if (r.checked) estimateRecipients(r.value); });
    });

    titleInput.focus();
  }

  function validateForm(modal) {
    const title = modal.querySelector('#bc-title').value.trim();
    const message = modal.querySelector('#bc-message').value.trim();
    const link = modal.querySelector('#bc-link').value.trim();
    let valid = true;
    if (title.length < 3) {
      modal.querySelector('#titleError').textContent = 'Title must be at least 3 characters';
      valid = false;
    }
    if (message.length < 10) {
      modal.querySelector('#messageError').textContent = 'Message must be at least 10 characters';
      valid = false;
    }
    if (link && !/^https?:\/\/.+/.test(link)) {
      modal.querySelector('#linkError').textContent = 'URL must start with http:// or https://';
      valid = false;
    }
    return valid;
  }

  async function estimateRecipients(segment) {
    const el = document.getElementById('estimatedRecipients');
    if (!el) return;
    el.textContent = 'Calculating\u2026';
    try {
      const response = await API.get('/admin/dashboard/stats');
      const stats = response.data;
      let estimate = 0;
      if (segment === 'all') {
        estimate = stats.totalUsers || 0;
      } else if (segment === 'active') {
        estimate = stats.activeUsers || stats.activeWeek || Math.floor((stats.totalUsers || 0) * 0.6);
      } else if (segment === 'banned') {
        estimate = stats.bannedUsers || 0;
      }
      if (selectedPlatform === 'android') estimate = Math.round(estimate * 0.8);
      else if (selectedPlatform === 'ios') estimate = Math.round(estimate * 0.2);
      el.textContent = `~${Utils.formatNumber(estimate)} users`;
    } catch {
      el.textContent = 'Unable to estimate';
    }
  }

  async function sendBroadcast(data) {
    try {
      const response = await API.post('/admin/broadcasts', data);
      const recipientCount = response.data.broadcast?.totalRecipients || 0;
      Components.Toast.success(`Broadcast queued \u2014 ${Utils.formatNumber(recipientCount)} recipients`);
      refresh();
    } catch (error) {
      console.error('Failed to send broadcast:', error);
      Components.Toast.error(error.message || 'Failed to send broadcast');
    }
  }

  function viewDetails(broadcastId) {
    const b = currentData.find(x => x._id === broadcastId);
    if (!b) { Components.Toast.error('Broadcast not found'); return; }

    const segmentLabels = { all: 'All Users', active: 'Active Users', banned: 'Banned Users', custom: 'Custom' };
    const platformLabels = { android: 'Android Only', ios: 'iOS Only', both: 'All Devices (Android + iOS)' };
    const statusColors = { sent: 'success', failed: 'danger', sending: 'warning', queued: 'blue', draft: 'purple' };

    const totalRecipients = b.totalRecipients || 0;
    const successCount = b.successCount || 0;
    const failureCount = b.failureCount || 0;
    const delivered = successCount + failureCount;
    const successRate = delivered > 0 ? Math.round((successCount / delivered) * 100) : (b.status === 'sent' ? 100 : 0);

    currentModal = Components.Modal.open({
      title: 'Broadcast Details',
      size: 'medium',
      content: `
        <div class="broadcast-detail">
          <div class="detail-section">
            <h4>Message</h4>
            <strong style="font-size:15px;color:var(--text);display:block;margin-bottom:6px">
              ${Utils.escapeHtml(b.title)}
            </strong>
            <p style="color:var(--text-muted);line-height:1.6;font-size:13px">
              ${Utils.escapeHtml(b.message || '')}
            </p>
          </div>

          <div class="detail-section">
            <h4>Broadcast Information</h4>
            <div class="detail-grid">
              <div class="detail-item">
                <label>Status</label>
                <p><span class="badge badge-${statusColors[b.status] || 'blue'}">${b.status}</span></p>
              </div>
              <div class="detail-item">
                <label>Audience</label>
                <p>${segmentLabels[b.segment] || b.segment}</p>
              </div>
              <div class="detail-item">
                <label>Platform</label>
                <p style="display:inline-flex;align-items:center;gap:6px">
                  ${ICONS[b.platform] || ICONS.both} ${platformLabels[b.platform] || 'All Devices'}
                </p>
              </div>
              <div class="detail-item">
                <label>Total Recipients</label>
                <p>${Utils.formatNumber(totalRecipients)}</p>
              </div>
              <div class="detail-item">
                <label>Created</label>
                <p>${b.createdAt ? Utils.formatDateTime(b.createdAt) : '\u2014'}</p>
              </div>
              <div class="detail-item">
                <label>Sent At</label>
                <p>${b.sentAt ? Utils.formatDateTime(b.sentAt) : '\u2014'}</p>
              </div>
            </div>
            ${b.link ? `
              <div style="margin-top:12px;padding-top:12px;border-top:1px solid var(--border)">
                <label style="display:block;font-size:11px;color:var(--text-muted);margin-bottom:4px;text-transform:uppercase;letter-spacing:0.5px">Action URL</label>
                <a href="${Utils.escapeHtml(b.link)}" target="_blank" rel="noopener noreferrer"
                   style="color:var(--primary);font-size:13px;word-break:break-all;text-decoration:underline">
                  ${Utils.escapeHtml(b.link)}
                </a>
              </div>` : ''}
          </div>

          ${(b.status === 'sent' || b.status === 'sending') ? `
            <div class="detail-section">
              <h4>Delivery Statistics</h4>
              <div class="stats-grid-modal">
                <div class="stat-item-modal">
                  <div class="stat-value-modal" style="color:var(--success)">${Utils.formatNumber(successCount)}</div>
                  <div class="stat-label-modal">Delivered</div>
                </div>
                <div class="stat-item-modal">
                  <div class="stat-value-modal" style="color:${failureCount > 0 ? 'var(--danger)' : 'var(--text-dim)'}">${Utils.formatNumber(failureCount)}</div>
                  <div class="stat-label-modal">Failed</div>
                </div>
                <div class="stat-item-modal">
                  <div class="stat-value-modal" style="color:${successRate >= 90 ? 'var(--success)' : successRate >= 70 ? 'var(--warning)' : 'var(--danger)'}">${successRate}%</div>
                  <div class="stat-label-modal">Success Rate</div>
                </div>
              </div>
            </div>
          ` : ''}

          ${b.status === 'queued' ? `
            <div class="detail-section" style="border-color:rgba(59,130,246,0.4);background:rgba(59,130,246,0.05)">
              <h4 style="color:var(--blue)">\u23f3 Queued for Sending</h4>
              <p style="color:var(--text-muted);font-size:13px">
                This broadcast is queued and will be processed shortly. Refresh to see updated status.
              </p>
            </div>
          ` : ''}

          ${b.status === 'failed' ? `
            <div class="detail-section" style="border-color:rgba(239,68,68,0.4);background:rgba(239,68,68,0.05)">
              <h4 style="color:var(--danger)">\u26a0 Broadcast Failed</h4>
              <p style="color:var(--text-muted);font-size:13px">
                An error occurred while processing this broadcast. Check server logs for details.
              </p>
            </div>
          ` : ''}
        </div>
      `,
      buttons: [
        { label: 'Close', className: 'btn-ghost', onClick: (m) => Components.Modal.close(m) }
      ],
      onClose: () => currentModal = null
    });
  }

  function refresh() {
    if (currentTable) Components.Table.refresh(currentTable);
  }

  function destroy() {
    if (currentModal) { Components.Modal.close(currentModal); currentModal = null; }
    currentTable = null;
    currentData = [];
  }

  return { init, refresh, destroy, createBroadcast, viewDetails };
})();
