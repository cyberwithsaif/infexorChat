/**
 * Dashboard Module — 17 live widgets + charts
 * • loadLive() polls every 5 seconds  (CPU, RAM, online count, etc.)
 * • loadStats() polls every 30 seconds (users, messages today, charts, recent users)
 */
const DashboardModule = (() => {
    let liveInterval = null;
    let statsInterval = null;
    let msgsChart = null;
    let usersChart = null;

    function init(container) {
        container.innerHTML = `
      <div class="metrics-grid">
        <div class="metric-card accent-blue"><div class="metric-label">Registered Users</div><div class="metric-value" id="mUsers">—</div></div>
        <div class="metric-card accent-green"><div class="metric-label">Online Now</div><div class="metric-value" id="mOnline">—</div><div class="metric-sub" id="mSockets"></div></div>
        <div class="metric-card accent-purple"><div class="metric-label">Audio Calls</div><div class="metric-value" id="mAudio">—</div></div>
        <div class="metric-card accent-orange"><div class="metric-label">Video Calls</div><div class="metric-value" id="mVideo">—</div></div>
        <div class="metric-card accent-cyan"><div class="metric-label">Calls Today</div><div class="metric-value" id="mCallsToday">—</div></div>
        <div class="metric-card accent-pink"><div class="metric-label">Msgs Today</div><div class="metric-value" id="mMsgsToday">—</div></div>
        <div class="metric-card accent-red"><div class="metric-label">CPU</div><div class="metric-value" id="mCpu">—</div><div class="metric-bar"><div class="metric-bar-fill" id="mCpuBar"></div></div></div>
        <div class="metric-card accent-yellow"><div class="metric-label">RAM</div><div class="metric-value" id="mRam">—</div><div class="metric-bar"><div class="metric-bar-fill" id="mRamBar"></div></div></div>
        <div class="metric-card"><div class="metric-label">Disk</div><div class="metric-value" id="mDisk">—</div><div class="metric-bar"><div class="metric-bar-fill" id="mDiskBar"></div></div></div>
        <div class="metric-card"><div class="metric-label">Heap Used</div><div class="metric-value" id="mHeap">—</div></div>
        <div class="metric-card"><div class="metric-label">Event Loop Lag</div><div class="metric-value" id="mLoop">—</div></div>
        <div class="metric-card"><div class="metric-label">Redis Ops/s</div><div class="metric-value" id="mRedisOps">—</div></div>
      </div>
      <div class="charts-grid">
        <div class="chart-card"><h3>Messages (7d)</h3><canvas id="chartMsgs"></canvas></div>
        <div class="chart-card"><h3>New Users (30d)</h3><canvas id="chartUsers"></canvas></div>
      </div>
      <div class="table-card">
        <h3>Recent Users</h3>
        <table class="data-table"><thead><tr><th>Name</th><th>Phone</th><th>Status</th><th>Joined</th></tr></thead>
        <tbody id="recentUsersTable"><tr><td colspan="4" class="loading">Loading...</td></tr></tbody></table>
      </div>`;

        loadStats();
        loadLive();
        liveInterval = setInterval(loadLive, 5000);
        statsInterval = setInterval(loadStats, 30000);
    }

    async function loadStats() {
        try {
            const r = await API.get('/admin/dashboard/stats');
            const d = r.data;
            setText('mUsers', fmt(d.totalUsers));
            setText('mMsgsToday', fmt(d.messagesToday));
            setText('mCallsToday', fmt(d.callsToday));

            // Destroy old charts before creating new ones
            if (msgsChart) { msgsChart.destroy(); msgsChart = null; }
            if (usersChart) { usersChart.destroy(); usersChart = null; }

            if (d.messagesPerDay?.length) {
                const el = document.getElementById('chartMsgs');
                if (el) {
                    msgsChart = new Chart(el, {
                        type: 'line', data: {
                            labels: d.messagesPerDay.map(x => x._id.slice(5)),
                            datasets: [{ label: 'Messages', data: d.messagesPerDay.map(x => x.count), borderColor: '#6366f1', backgroundColor: 'rgba(99,102,241,0.1)', fill: true, tension: 0.4 }]
                        }, options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
                    });
                }
            }
            if (d.newUsersPerDay?.length) {
                const el = document.getElementById('chartUsers');
                if (el) {
                    usersChart = new Chart(el, {
                        type: 'line', data: {
                            labels: d.newUsersPerDay.map(x => x._id.slice(5)),
                            datasets: [{ label: 'Users', data: d.newUsersPerDay.map(x => x.count), borderColor: '#10b981', backgroundColor: 'rgba(16,185,129,0.1)', fill: true, tension: 0.4 }]
                        }, options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
                    });
                }
            }

            // Recent users
            const ur = await API.get('/admin/users?limit=8');
            const users = ur.data?.users || [];
            const tbody = document.getElementById('recentUsersTable');
            if (tbody) {
                tbody.innerHTML = users.map(u => `<tr><td><span class="status-dot ${u.isOnline ? 'online' : ''}"></span> ${esc(u.name)}</td><td>${esc(u.phone)}</td><td><span class="badge badge-${u.status === 'active' ? 'success' : 'danger'}">${u.status}</span></td><td>${timeAgo(u.createdAt)}</td></tr>`).join('') || '<tr><td colspan="4">No users</td></tr>';
            }
        } catch (e) { console.error('Dashboard stats error:', e); }
    }

    async function loadLive() {
        try {
            const r = await API.get('/admin/dashboard/live');
            const d = r.data;
            setText('mOnline', fmt(d.connectedSockets));
            setText('mSockets', `${d.connectedSockets} sockets`);
            setText('mAudio', fmt(d.activeAudioCalls));
            setText('mVideo', fmt(d.activeVideoCalls));

            if (d.system) {
                setText('mCpu', d.system.cpu?.percent + '%');
                setBar('mCpuBar', d.system.cpu?.percent);
                setText('mRam', d.system.memory?.percent + '%');
                setBar('mRamBar', d.system.memory?.percent);
                setText('mDisk', d.system.disk?.percent + '%');
                setBar('mDiskBar', d.system.disk?.percent);
                setText('mHeap', d.system.heap?.usedMB + ' MB');
                setText('mLoop', d.system.eventLoopLag + ' ms');
            }
            if (d.redis) {
                setText('mRedisOps', d.redis.instantaneous_ops_per_sec || '0');
            }

            document.getElementById('lastUpdate').textContent = 'Updated just now';
        } catch (e) { console.error('Live metrics error:', e); }
    }

    function setText(id, val) { const el = document.getElementById(id); if (el) el.textContent = val; }
    function setBar(id, pct) { const el = document.getElementById(id); if (el) { el.style.width = Math.min(pct, 100) + '%'; el.className = 'metric-bar-fill' + (pct > 80 ? ' danger' : pct > 60 ? ' warning' : ''); } }
    function fmt(n) { return n != null ? n.toLocaleString() : '—'; }
    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function timeAgo(d) { const s = Math.floor((Date.now() - new Date(d)) / 1000); if (s < 60) return 'just now'; if (s < 3600) return Math.floor(s / 60) + 'm ago'; if (s < 86400) return Math.floor(s / 3600) + 'h ago'; return Math.floor(s / 86400) + 'd ago'; }

    async function refresh() {
        await Promise.all([loadStats(), loadLive()]);
    }

    function destroy() {
        if (liveInterval) { clearInterval(liveInterval); liveInterval = null; }
        if (statsInterval) { clearInterval(statsInterval); statsInterval = null; }
        if (msgsChart) { msgsChart.destroy(); msgsChart = null; }
        if (usersChart) { usersChart.destroy(); usersChart = null; }
    }
    return { init, destroy, loadStats, refresh };
})();
