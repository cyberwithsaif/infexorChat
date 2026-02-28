/**
 * Enhanced Users Module — full user management with modal profile view
 */
const UsersModule = (() => {
  let currentPage = 1;
  let currentModal = null;

  function init(container) {
    container.innerHTML = `
      <div class="card-header">
        <div class="card-actions">
          <input type="text" id="userSearch" class="input-sm" placeholder="Search by name, phone...">
          <select id="userStatus" class="input-sm">
            <option value="">All Status</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
            <option value="banned">Banned</option>
          </select>
        </div>
      </div>
      <div class="table-card">
        <table class="data-table">
          <thead><tr><th>User</th><th>Phone</th><th>Status</th><th>Online</th><th>Joined</th><th>Actions</th></tr></thead>
          <tbody id="usersTable"><tr><td colspan="6" class="loading">Loading...</td></tr></tbody>
        </table>
        <div id="usersPagination" class="pagination"></div>
      </div>`;

    loadUsers();
    document.getElementById('userSearch').addEventListener('input', debounce(() => { currentPage = 1; loadUsers(); }, 300));
    document.getElementById('userStatus').addEventListener('change', () => { currentPage = 1; loadUsers(); });
  }

  async function loadUsers(page = currentPage) {
    currentPage = page;
    const search = document.getElementById('userSearch')?.value || '';
    const status = document.getElementById('userStatus')?.value || '';
    try {
      const r = await API.get(`/admin/users?page=${page}&limit=15&search=${encodeURIComponent(search)}&status=${status}`);
      const users = r.data?.users || [];
      const pg = r.data?.pagination;
      const tb = document.getElementById('usersTable');
      tb.innerHTML = users.map(u => `<tr>
        <td><span class="status-dot ${u.isOnline ? 'online' : ''}"></span> ${esc(u.name)}</td>
        <td>${esc(u.phone)}</td>
        <td><span class="badge badge-${u.status === 'active' ? 'success' : u.status === 'banned' ? 'danger' : 'warning'}">${u.status}</span></td>
        <td>${u.isOnline ? '🟢' : '⚫'}</td>
        <td>${timeAgo(u.createdAt)}</td>
        <td>
          <button class="btn btn-sm" onclick="UsersModule.viewDetails('${u._id}')">View</button>
          <button class="btn btn-sm btn-danger" onclick="UsersModule.banUser('${u._id}', '${u.status}')">
            ${u.status === 'banned' ? 'Unban' : 'Ban'}
          </button>
        </td>
      </tr>`).join('') || '<tr><td colspan="6">No users found</td></tr>';

      if (pg?.pages > 1) {
        document.getElementById('usersPagination').innerHTML = Array.from({ length: Math.min(pg.pages, 10) }, (_, i) =>
          `<button class="btn btn-sm ${i + 1 === pg.page ? 'btn-primary' : ''}" onclick="UsersModule.loadUsers(${i + 1})">${i + 1}</button>`
        ).join(' ') + (pg.pages > 10 ? ` ... <button class="btn btn-sm" onclick="UsersModule.loadUsers(${pg.pages})">${pg.pages}</button>` : '');
      }
    } catch (e) { console.error(e); }
  }

  async function viewDetails(id) {
    // Show loading modal immediately
    currentModal = Components.Modal.open({
      title: 'User Profile',
      size: 'large',
      content: '<div style="text-align:center;padding:40px"><div class="spinner"></div><p style="margin-top:12px;color:var(--text-muted)">Loading user profile…</p></div>',
      buttons: [{ label: 'Close', className: 'btn-ghost', onClick: (m) => Components.Modal.close(m) }],
      onClose: () => { currentModal = null; }
    });

    try {
      const r = await API.get(`/admin/users/${id}`);
      const u = r.data?.user;
      const s = r.data?.stats;
      const calls = r.data?.callHistory || [];
      const devices = r.data?.devices || [];

      if (!u) {
        _updateModalBody('<p style="text-align:center;color:var(--danger);padding:40px">User not found</p>');
        return;
      }

      const statusColor = u.status === 'active' ? 'success' : u.status === 'banned' ? 'danger' : 'warning';
      const joinedDate = u.createdAt ? new Date(u.createdAt) : null;
      const joinedStr = joinedDate ? joinedDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }) : '—';
      const joinedTimeAgo = joinedDate ? timeAgo(u.createdAt) : '';
      const lastSeenStr = u.lastSeen ? new Date(u.lastSeen).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' }) : '—';
      const updatedStr = u.updatedAt ? new Date(u.updatedAt).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' }) : '—';

      // Calculate call stats from history
      const totalCalls = calls.length;
      const completedCalls = calls.filter(c => c.status === 'completed').length;
      const totalCallDuration = calls.reduce((sum, c) => sum + (c.duration || 0), 0);
      const audioCalls = calls.filter(c => c.type === 'audio').length;
      const videoCalls = calls.filter(c => c.type === 'video').length;

      const content = `
        <div class="user-profile-modal">
          <!-- User Header -->
          <div style="display:flex;align-items:center;gap:16px;padding-bottom:20px;border-bottom:1px solid var(--border);margin-bottom:20px">
            <div style="width:64px;height:64px;border-radius:50%;background:linear-gradient(135deg,var(--primary),#7c3aed);display:flex;align-items:center;justify-content:center;color:#fff;font-size:24px;font-weight:700;flex-shrink:0">
              ${esc(u.name?.[0]?.toUpperCase() || '?')}
            </div>
            <div style="flex:1;min-width:0">
              <h3 style="margin:0;font-size:18px;color:var(--text)">${esc(u.name)}</h3>
              <p style="margin:3px 0 0;color:var(--text-muted);font-size:13px">${esc(u.phone)}</p>
              <div style="display:flex;gap:8px;margin-top:6px;flex-wrap:wrap">
                <span class="badge badge-${statusColor}">${u.status}</span>
                <span class="badge badge-${u.isOnline ? 'success' : 'blue'}">${u.isOnline ? '● Online' : '○ Offline'}</span>
              </div>
            </div>
          </div>

          <!-- Stats Cards -->
          <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px">
            <div style="background:var(--bg-hover);border-radius:10px;padding:14px;text-align:center;border:1px solid var(--border)">
              <div style="font-size:20px;font-weight:700;color:var(--primary)">${fmtN(s.messageCount)}</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:2px">Messages</div>
            </div>
            <div style="background:var(--bg-hover);border-radius:10px;padding:14px;text-align:center;border:1px solid var(--border)">
              <div style="font-size:20px;font-weight:700;color:var(--success)">${fmtN(s.chatCount)}</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:2px">Chats</div>
            </div>
            <div style="background:var(--bg-hover);border-radius:10px;padding:14px;text-align:center;border:1px solid var(--border)">
              <div style="font-size:20px;font-weight:700;color:#7c3aed">${fmtN(s.groupCount)}</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:2px">Groups</div>
            </div>
            <div style="background:var(--bg-hover);border-radius:10px;padding:14px;text-align:center;border:1px solid var(--border)">
              <div style="font-size:20px;font-weight:700;color:var(--warning)">${fmtN(totalCalls)}</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:2px">Calls</div>
            </div>
          </div>

          <!-- Tabbed sections -->
          <div class="profile-tabs" id="profileTabs">
            <button class="profile-tab active" data-tab="info">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
              Profile Info
            </button>
            <button class="profile-tab" data-tab="activity">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
              Activity
            </button>
            <button class="profile-tab" data-tab="calls">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72"/></svg>
              Call History
            </button>
            <button class="profile-tab" data-tab="devices">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
              Devices
            </button>
          </div>

          <!-- Tab: Profile Info -->
          <div class="profile-tab-content active" id="tab-info">
            <div class="detail-grid" style="display:grid;grid-template-columns:1fr 1fr;gap:0">
              ${_detailRow('User ID', u._id, true)}
              ${_detailRow('Full Name', u.name)}
              ${_detailRow('Phone Number', u.phone)}
              ${_detailRow('Status', `<span class="badge badge-${statusColor}">${u.status}</span>`)}
              ${_detailRow('Online', u.isOnline ? '<span style="color:var(--success)">● Online now</span>' : '<span style="color:var(--text-dim)">○ Offline</span>')}
              ${_detailRow('Joined', `${joinedStr} <span style="color:var(--text-dim);font-size:11px">(${joinedTimeAgo})</span>`)}
              ${_detailRow('Last Seen', lastSeenStr)}
              ${_detailRow('Last Updated', updatedStr)}
              ${u.about ? _detailRow('About', esc(u.about)) : ''}
              ${_detailRow('FCM Token', u.fcmToken ? `<span style="font-family:monospace;font-size:10px;word-break:break-all;color:var(--text-muted)">${esc(u.fcmToken.substring(0, 40))}…</span>` : '<span style="color:var(--text-dim)">Not registered</span>')}
            </div>
          </div>

          <!-- Tab: Activity -->
          <div class="profile-tab-content" id="tab-activity" style="display:none">
            <div class="detail-grid" style="display:grid;grid-template-columns:1fr 1fr;gap:0">
              ${_detailRow('Total Messages Sent', fmtN(s.messageCount))}
              ${_detailRow('Active Chats', fmtN(s.chatCount))}
              ${_detailRow('Groups Joined', fmtN(s.groupCount))}
              ${_detailRow('Total Calls', fmtN(totalCalls))}
              ${_detailRow('Completed Calls', fmtN(completedCalls))}
              ${_detailRow('Audio Calls', fmtN(audioCalls))}
              ${_detailRow('Video Calls', fmtN(videoCalls))}
              ${_detailRow('Total Call Duration', formatDuration(totalCallDuration))}
              ${_detailRow('Account Age', joinedDate ? daysSince(joinedDate) : '—')}
              ${_detailRow('Registered Devices', fmtN(devices.length))}
            </div>
          </div>

          <!-- Tab: Call History -->
          <div class="profile-tab-content" id="tab-calls" style="display:none">
            ${calls.length ? `
              <table class="data-table" style="font-size:13px">
                <thead><tr><th>Type</th><th>Direction</th><th>Status</th><th>Duration</th><th>Date</th></tr></thead>
                <tbody>
                  ${calls.slice(0, 20).map(c => {
        const isOutgoing = c.callerId?.toString() === id;
        const statusColor = c.status === 'completed' ? 'success' : c.status === 'missed' ? 'danger' : 'warning';
        return `<tr>
                      <td><span style="display:inline-flex;align-items:center;gap:4px">
                        ${c.type === 'video' ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg>' : '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72"/></svg>'}
                        ${c.type || 'audio'}
                      </span></td>
                      <td>${isOutgoing ? '↗ Outgoing' : '↙ Incoming'}</td>
                      <td><span class="badge badge-${statusColor}">${c.status}</span></td>
                      <td>${c.duration ? formatDuration(c.duration) : '—'}</td>
                      <td style="color:var(--text-muted);font-size:12px">${c.createdAt ? new Date(c.createdAt).toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' }) : '—'}</td>
                    </tr>`;
      }).join('')}
                </tbody>
              </table>
            ` : '<p style="text-align:center;color:var(--text-muted);padding:30px">No call history found</p>'}
          </div>

          <!-- Tab: Devices -->
          <div class="profile-tab-content" id="tab-devices" style="display:none">
            ${devices.length ? `
              <div style="display:flex;flex-direction:column;gap:10px">
                ${devices.map(d => `
                  <div style="background:var(--bg-hover);border-radius:10px;padding:14px;border:1px solid var(--border);display:flex;align-items:center;gap:12px">
                    <div style="width:40px;height:40px;border-radius:8px;background:var(--bg-card);border:1px solid var(--border);display:flex;align-items:center;justify-content:center">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
                    </div>
                    <div style="flex:1;min-width:0">
                      <div style="font-weight:600;font-size:13px;color:var(--text)">${esc(d.platform || 'Unknown')} ${esc(d.model || '')}</div>
                      <div style="font-size:11px;color:var(--text-muted);margin-top:2px">
                        ${d.appVersion ? `v${esc(d.appVersion)} • ` : ''}
                        Last active: ${d.lastActive ? timeAgo(d.lastActive) : '—'}
                      </div>
                    </div>
                  </div>
                `).join('')}
              </div>
            ` : '<p style="text-align:center;color:var(--text-muted);padding:30px">No devices found</p>'}
          </div>

          <!-- Quick Actions -->
          <div style="margin-top:20px;padding-top:16px;border-top:1px solid var(--border);display:flex;gap:8px;flex-wrap:wrap">
            <button class="btn btn-sm btn-warning" onclick="UsersModule.forceLogout('${u._id}')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
              Force Logout
            </button>
            <button class="btn btn-sm" onclick="UsersModule.resetRate('${u._id}')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
              Reset Rate Limit
            </button>
            <button class="btn btn-sm btn-danger" onclick="UsersModule.deleteUser('${u._id}')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              Delete User
            </button>
            <button class="btn btn-sm btn-${u.status === 'banned' ? 'success' : 'danger'}" onclick="UsersModule.banUser('${u._id}', '${u.status}')">
              ${u.status === 'banned' ? '✓ Unban User' : '⊘ Ban User'}
            </button>
          </div>
        </div>
      `;

      _updateModalBody(content);
      _initTabs();
    } catch (e) {
      _updateModalBody(`<p style="text-align:center;color:var(--danger);padding:40px">Failed to load user profile: ${esc(e.message)}</p>`);
    }
  }

  function _updateModalBody(html) {
    if (!currentModal) return;
    const body = currentModal.querySelector('.modal-body');
    if (body) body.innerHTML = html;
  }

  function _initTabs() {
    if (!currentModal) return;
    const tabs = currentModal.querySelectorAll('.profile-tab');
    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        currentModal.querySelectorAll('.profile-tab-content').forEach(c => c.style.display = 'none');
        const target = currentModal.querySelector(`#tab-${tab.dataset.tab}`);
        if (target) target.style.display = 'block';
      });
    });
  }

  function _detailRow(label, value, isMono = false) {
    return `<div style="padding:10px 14px;border-bottom:1px solid var(--border)">
      <div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;margin-bottom:3px">${label}</div>
      <div style="font-size:13px;color:var(--text);${isMono ? 'font-family:monospace;font-size:11px;word-break:break-all;' : ''}">${value}</div>
    </div>`;
  }

  async function banUser(id, currentStatus) {
    const newStatus = currentStatus === 'banned' ? 'active' : 'banned';
    if (!confirm(`${newStatus === 'banned' ? 'Ban' : 'Unban'} this user?`)) return;
    try {
      await API.put(`/admin/users/${id}/status`, { status: newStatus });
      if (currentModal) { Components.Modal.close(currentModal); currentModal = null; }
      loadUsers();
    } catch (e) { alert(e.message); }
  }

  async function forceLogout(id) {
    if (!confirm('Force logout this user?')) return;
    try {
      await API.post(`/admin/users/${id}/force-logout`);
      Components.Toast.success('User has been forced out');
      viewDetails(id);
    } catch (e) { alert(e.message); }
  }

  async function deleteUser(id) {
    if (!confirm('PERMANENTLY delete this user? This cannot be undone.')) return;
    try {
      await API.del(`/admin/users/${id}`);
      if (currentModal) { Components.Modal.close(currentModal); currentModal = null; }
      loadUsers();
    } catch (e) { alert(e.message); }
  }

  async function resetRate(id) {
    try {
      await API.post(`/admin/users/${id}/reset-rate-limit`);
      Components.Toast.success('Rate limit has been reset');
    } catch (e) { alert(e.message); }
  }

  function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
  function fmtN(n) { return n != null ? Number(n).toLocaleString() : '0'; }
  function timeAgo(d) { if (!d) return '—'; const s = Math.floor((Date.now() - new Date(d)) / 1000); if (s < 60) return 'just now'; if (s < 3600) return Math.floor(s / 60) + 'm ago'; if (s < 86400) return Math.floor(s / 3600) + 'h ago'; return Math.floor(s / 86400) + 'd ago'; }
  function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }
  function formatDuration(secs) {
    if (!secs || secs <= 0) return '0s';
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    if (h > 0) return `${h}h ${m}m`;
    if (m > 0) return `${m}m ${s}s`;
    return `${s}s`;
  }
  function daysSince(date) {
    const days = Math.floor((Date.now() - date.getTime()) / 86400000);
    if (days === 0) return 'Today';
    if (days === 1) return '1 day';
    if (days < 30) return `${days} days`;
    if (days < 365) return `${Math.floor(days / 30)} months`;
    return `${(days / 365).toFixed(1)} years`;
  }

  async function refresh() { await loadUsers(currentPage); }
  function destroy() {
    if (currentModal) { Components.Modal.close(currentModal); currentModal = null; }
  }

  return { init, destroy, viewDetails, loadUsers, banUser, forceLogout, deleteUser, resetRate, refresh };
})();
