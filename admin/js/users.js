/**
 * Enhanced Users Module — full user management
 */
const UsersModule = (() => {
  let currentPage = 1;

  function init(container) {
    container.innerHTML = `
      <div class="card-header">
        <div class="card-actions">
          <input type="text" id="userSearch" class="input-sm" placeholder="Search by name, phone...">
          <select id="userStatus" class="input-sm"><option value="">All Status</option><option value="active">Active</option><option value="suspended">Suspended</option><option value="banned">Banned</option></select>
        </div>
      </div>
      <div class="table-card">
        <table class="data-table"><thead><tr><th>User</th><th>Phone</th><th>Status</th><th>Online</th><th>Joined</th><th>Actions</th></tr></thead>
        <tbody id="usersTable"><tr><td colspan="6" class="loading">Loading...</td></tr></tbody></table>
        <div id="usersPagination" class="pagination"></div>
      </div>
      <div id="userDetailPanel" class="detail-panel hidden"></div>`;

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

      // Pagination
      if (pg?.pages > 1) {
        document.getElementById('usersPagination').innerHTML = Array.from({ length: Math.min(pg.pages, 10) }, (_, i) =>
          `<button class="btn btn-sm ${i + 1 === pg.page ? 'btn-primary' : ''}" onclick="UsersModule.loadUsers(${i + 1})">${i + 1}</button>`
        ).join(' ') + (pg.pages > 10 ? ` ... <button class="btn btn-sm" onclick="UsersModule.loadUsers(${pg.pages})">${pg.pages}</button>` : '');
      }
    } catch (e) { console.error(e); }
  }

  async function viewDetails(id) {
    const panel = document.getElementById('userDetailPanel');
    panel.classList.remove('hidden');
    panel.innerHTML = '<div class="loading">Loading user details...</div>';
    try {
      const r = await API.get(`/admin/users/${id}`);
      const u = r.data?.user;
      const s = r.data?.stats;
      const calls = r.data?.callHistory || [];
      const devices = r.data?.devices || [];
      panel.innerHTML = `
        <div class="detail-header">
          <h3>${esc(u.name)}</h3>
          <button class="btn btn-sm" onclick="document.getElementById('userDetailPanel').classList.add('hidden')">✕ Close</button>
        </div>
        <div class="kv-list">
          <div class="kv-row"><span class="kv-key">ID</span><span class="kv-val mono">${u._id}</span></div>
          <div class="kv-row"><span class="kv-key">Phone</span><span class="kv-val">${esc(u.phone)}</span></div>
          <div class="kv-row"><span class="kv-key">Status</span><span class="kv-val"><span class="badge badge-${u.status === 'active' ? 'success' : 'danger'}">${u.status}</span></span></div>
          <div class="kv-row"><span class="kv-key">Online</span><span class="kv-val">${u.isOnline ? '🟢 Yes' : '⚫ No'}</span></div>
          <div class="kv-row"><span class="kv-key">Last Seen</span><span class="kv-val">${u.lastSeen ? new Date(u.lastSeen).toLocaleString() : '—'}</span></div>
          <div class="kv-row"><span class="kv-key">Joined</span><span class="kv-val">${new Date(u.createdAt).toLocaleDateString()}</span></div>
          <div class="kv-row"><span class="kv-key">Messages</span><span class="kv-val">${s.messageCount}</span></div>
          <div class="kv-row"><span class="kv-key">Chats</span><span class="kv-val">${s.chatCount}</span></div>
          <div class="kv-row"><span class="kv-key">Groups</span><span class="kv-val">${s.groupCount}</span></div>
          <div class="kv-row"><span class="kv-key">FCM Token</span><span class="kv-val mono" style="word-break:break-all;font-size:11px;">${esc(u.fcmToken || '—')}</span></div>
        </div>
        <div class="detail-actions">
          <button class="btn btn-sm btn-warning" onclick="UsersModule.forceLogout('${u._id}')">Force Logout</button>
          <button class="btn btn-sm" onclick="UsersModule.resetRate('${u._id}')">Reset Rate Limit</button>
          <button class="btn btn-sm btn-danger" onclick="UsersModule.deleteUser('${u._id}')">Delete User</button>
        </div>
        ${devices.length ? `<h4 style="margin-top:16px">Devices</h4><div class="kv-list">${devices.map(d => `<div class="kv-row"><span class="kv-key">${esc(d.platform || 'Unknown')}</span><span class="kv-val">${esc(d.model || '')} — ${timeAgo(d.lastActive)}</span></div>`).join('')}</div>` : ''}
        ${calls.length ? `<h4 style="margin-top:16px">Recent Calls</h4><table class="data-table"><thead><tr><th>Type</th><th>Status</th><th>Duration</th><th>Date</th></tr></thead><tbody>${calls.slice(0, 10).map(c => `<tr><td>${c.type}</td><td><span class="badge badge-${c.status === 'completed' ? 'success' : 'warning'}">${c.status}</span></td><td>${c.duration || '—'}s</td><td>${timeAgo(c.createdAt)}</td></tr>`).join('')}</tbody></table>` : ''}
      `;
    } catch (e) { panel.innerHTML = `<p class="error">Failed to load: ${e.message}</p>`; }
  }

  async function banUser(id, currentStatus) {
    const newStatus = currentStatus === 'banned' ? 'active' : 'banned';
    if (!confirm(`${newStatus === 'banned' ? 'Ban' : 'Unban'} this user?`)) return;
    try { await API.put(`/admin/users/${id}/status`, { status: newStatus }); loadUsers(); } catch (e) { alert(e.message); }
  }

  async function forceLogout(id) {
    if (!confirm('Force logout this user?')) return;
    try { await API.post(`/admin/users/${id}/force-logout`); alert('User logged out'); viewDetails(id); } catch (e) { alert(e.message); }
  }

  async function deleteUser(id) {
    if (!confirm('PERMANENTLY delete this user? This cannot be undone.')) return;
    try { await API.del(`/admin/users/${id}`); document.getElementById('userDetailPanel').classList.add('hidden'); loadUsers(); } catch (e) { alert(e.message); }
  }

  async function resetRate(id) {
    try { await API.post(`/admin/users/${id}/reset-rate-limit`); alert('Rate limit reset'); } catch (e) { alert(e.message); }
  }

  function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
  function timeAgo(d) { if (!d) return '—'; const s = Math.floor((Date.now() - new Date(d)) / 1000); if (s < 60) return 'just now'; if (s < 3600) return Math.floor(s / 60) + 'm ago'; if (s < 86400) return Math.floor(s / 3600) + 'h ago'; return Math.floor(s / 86400) + 'd ago'; }
  function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }
  async function refresh() {
    await loadUsers(currentPage);
  }

  function destroy() { }

  return { init, destroy, viewDetails, loadUsers, banUser, forceLogout, deleteUser, resetRate, refresh };
})();
