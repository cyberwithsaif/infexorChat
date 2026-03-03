/**
 * Verification Module — manage blue tick verification requests
 */
const VerificationModule = (() => {
    let currentPage = 1;
    let currentStatus = 'pending';

    function init(container) {
        container.innerHTML = `
      <div class="card-header">
        <div class="card-actions">
          <div class="verification-tabs" style="display:flex;gap:8px">
            <button class="btn btn-sm btn-primary" data-status="pending" id="vTabPending">⏳ Pending <span id="vCountPending" class="badge badge-warning" style="margin-left:4px">0</span></button>
            <button class="btn btn-sm" data-status="approved" id="vTabApproved">✓ Approved <span id="vCountApproved" class="badge badge-success" style="margin-left:4px">0</span></button>
            <button class="btn btn-sm" data-status="rejected" id="vTabRejected">✗ Rejected <span id="vCountRejected" class="badge badge-danger" style="margin-left:4px">0</span></button>
          </div>
        </div>
      </div>
      <div class="table-card">
        <table class="data-table">
          <thead><tr><th>User</th><th>Phone</th><th>Reason</th><th>Requested</th><th>Actions</th></tr></thead>
          <tbody id="verificationTable"><tr><td colspan="5" class="loading">Loading...</td></tr></tbody>
        </table>
        <div id="verificationPagination" class="pagination"></div>
      </div>`;

        document.querySelectorAll('.verification-tabs .btn').forEach(btn => {
            btn.addEventListener('click', () => {
                currentStatus = btn.dataset.status;
                currentPage = 1;
                document.querySelectorAll('.verification-tabs .btn').forEach(b => b.classList.remove('btn-primary'));
                btn.classList.add('btn-primary');
                loadRequests();
            });
        });
        loadRequests();
    }

    async function loadRequests(page = currentPage) {
        currentPage = page;
        try {
            const r = await API.get(`/admin/verification/requests?page=${page}&limit=15&status=${currentStatus}`);
            const requests = r.data?.requests || [];
            const counts = r.data?.counts || {};
            const pg = r.data?.pagination;

            // Update count badges
            const pcEl = document.getElementById('vCountPending');
            const acEl = document.getElementById('vCountApproved');
            const rcEl = document.getElementById('vCountRejected');
            if (pcEl) pcEl.textContent = counts.pending || 0;
            if (acEl) acEl.textContent = counts.approved || 0;
            if (rcEl) rcEl.textContent = counts.rejected || 0;

            const tb = document.getElementById('verificationTable');
            if (!requests.length) {
                tb.innerHTML = `<tr><td colspan="5" style="text-align:center;color:var(--text-muted);padding:30px">No ${currentStatus} verification requests</td></tr>`;
                document.getElementById('verificationPagination').innerHTML = '';
                return;
            }

            tb.innerHTML = requests.map(u => {
                const vr = u.verificationRequest || {};
                const requestedAt = vr.requestedAt ? timeAgo(vr.requestedAt) : '—';
                const reason = esc(vr.reason || '—');
                let actions = '';

                if (currentStatus === 'pending') {
                    actions = `
            <button class="btn btn-sm btn-success" onclick="VerificationModule.approve('${u._id}')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
              Approve
            </button>
            <button class="btn btn-sm btn-danger" onclick="VerificationModule.reject('${u._id}')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              Reject
            </button>`;
                } else if (currentStatus === 'approved') {
                    actions = `<span class="badge badge-success">✓ Verified</span>
            <button class="btn btn-sm btn-danger" onclick="VerificationModule.revoke('${u._id}')">Revoke</button>`;
                } else {
                    actions = `<span class="badge badge-danger">✗ Rejected</span>
            ${vr.adminNote ? `<span style="font-size:11px;color:var(--text-muted)" title="${esc(vr.adminNote)}">📝</span>` : ''}`;
                }

                return `<tr>
          <td>
            <div style="display:flex;align-items:center;gap:8px">
              <div style="width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,var(--primary),#7c3aed);display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px;font-weight:700;flex-shrink:0">
                ${esc(u.name?.[0]?.toUpperCase() || '?')}
              </div>
              <div>
                <span style="font-weight:600">${esc(u.name)}</span>
                ${u.isVerified ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="#1DA1F2" style="vertical-align:middle;margin-left:4px"><path d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5s-2.816.917-3.437 2.25c-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484zm-6.616-3.334l-4.334 6.5c-.145.217-.382.334-.625.334-.143 0-.288-.04-.416-.126l-.115-.094-2.415-2.415c-.293-.293-.293-.768 0-1.06s.768-.294 1.06 0l1.77 1.767 3.825-5.74c.23-.345.696-.436 1.04-.207.346.23.44.696.21 1.04z"/></svg>' : ''}
              </div>
            </div>
          </td>
          <td>${esc(u.phone)}</td>
          <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${reason}">${reason}</td>
          <td style="color:var(--text-muted);font-size:12px">${requestedAt}</td>
          <td style="display:flex;gap:6px;flex-wrap:wrap">${actions}</td>
        </tr>`;
            }).join('');

            if (pg?.pages > 1) {
                document.getElementById('verificationPagination').innerHTML = Array.from({ length: Math.min(pg.pages, 10) }, (_, i) =>
                    `<button class="btn btn-sm ${i + 1 === pg.page ? 'btn-primary' : ''}" onclick="VerificationModule.loadRequests(${i + 1})">${i + 1}</button>`
                ).join(' ');
            } else {
                document.getElementById('verificationPagination').innerHTML = '';
            }
        } catch (e) { console.error(e); }
    }

    async function approve(userId) {
        const note = prompt('Admin note (optional):') || '';
        try {
            await API.put(`/admin/verification/${userId}`, { action: 'approve', adminNote: note });
            Components.Toast.success('User verified successfully!');
            loadRequests();
        } catch (e) { alert(e.message); }
    }

    async function reject(userId) {
        const note = prompt('Reason for rejection (shown to user):');
        if (note === null) return; // cancelled
        try {
            await API.put(`/admin/verification/${userId}`, { action: 'reject', adminNote: note });
            Components.Toast.success('Verification request rejected');
            loadRequests();
        } catch (e) { alert(e.message); }
    }

    async function revoke(userId) {
        if (!confirm('Revoke this user\'s verification badge?')) return;
        try {
            await API.put(`/admin/verification/${userId}`, { action: 'reject', adminNote: 'Verification revoked by admin' });
            Components.Toast.success('Verification revoked');
            loadRequests();
        } catch (e) { alert(e.message); }
    }

    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function timeAgo(d) { if (!d) return '—'; const s = Math.floor((Date.now() - new Date(d)) / 1000); if (s < 60) return 'just now'; if (s < 3600) return Math.floor(s / 60) + 'm ago'; if (s < 86400) return Math.floor(s / 3600) + 'h ago'; return Math.floor(s / 86400) + 'd ago'; }

    async function refresh() { await loadRequests(currentPage); }
    function destroy() { }

    return { init, destroy, loadRequests, approve, reject, revoke, refresh };
})();
