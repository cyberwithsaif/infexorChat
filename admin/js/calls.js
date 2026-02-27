/**
 * Call Analytics Module
 */
const CallsModule = (() => {
    let interval = null;

    function init(container) {
        container.innerHTML = `
      <div class="metrics-grid">
        <div class="metric-card accent-blue"><div class="metric-label">Total Calls</div><div class="metric-value" id="cTotal">—</div></div>
        <div class="metric-card accent-green"><div class="metric-label">Calls Today</div><div class="metric-value" id="cToday">—</div></div>
        <div class="metric-card accent-purple"><div class="metric-label">Completed</div><div class="metric-value" id="cCompleted">—</div></div>
        <div class="metric-card accent-orange"><div class="metric-label">Missed</div><div class="metric-value" id="cMissed">—</div></div>
        <div class="metric-card accent-red"><div class="metric-label">Drop Rate</div><div class="metric-value" id="cDrop">—</div></div>
        <div class="metric-card accent-cyan"><div class="metric-label">Avg Duration</div><div class="metric-value" id="cAvg">—</div></div>
      </div>
      <div class="chart-card"><h3>Calls per Day (7d)</h3><div style="height:280px"><canvas id="chartCalls"></canvas></div></div>
      <div class="table-card">
        <h3>Active Calls <span class="badge badge-success" id="activeCount">0</span></h3>
        <table class="data-table"><thead><tr><th>Caller</th><th>Receiver</th><th>Type</th><th>Status</th><th>Duration</th><th>Action</th></tr></thead>
        <tbody id="activeCallsTable"><tr><td colspan="6" class="loading">Loading...</td></tr></tbody></table>
      </div>`;
        loadAnalytics();
        loadActive();
        interval = setInterval(loadActive, 5000);
    }

    async function loadAnalytics() {
        try {
            const r = await API.get('/admin/calls/analytics');
            const d = r.data;
            txt('cTotal', fmt(d.totalCalls)); txt('cToday', fmt(d.callsToday));
            txt('cCompleted', fmt(d.completedCalls)); txt('cMissed', fmt(d.missedCalls));
            txt('cDrop', d.dropRate + '%'); txt('cAvg', d.avgDuration + 's');
            if (d.callsPerDay?.length) {
                new Chart(document.getElementById('chartCalls'), {
                    type: 'bar', data: { labels: d.callsPerDay.map(x => x._id.slice(5)), datasets: [{ label: 'Calls', data: d.callsPerDay.map(x => x.count), backgroundColor: 'rgba(99,102,241,0.7)', borderRadius: 6 }] },
                    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
                });
            }
        } catch (e) { console.error(e); }
    }

    async function loadActive() {
        try {
            const r = await API.get('/admin/calls/active');
            const calls = r.data?.calls || [];
            txt('activeCount', calls.length);
            const tb = document.getElementById('activeCallsTable');
            if (!calls.length) { tb.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:20px;color:var(--text-muted)">No active calls</td></tr>'; return; }
            tb.innerHTML = calls.map(c => `<tr>
        <td>${esc(c.callerId?.name || c.callerId)}</td>
        <td>${esc(c.receiverId?.name || c.receiverId)}</td>
        <td><span class="badge badge-${c.type === 'video' ? 'purple' : 'blue'}">${c.type}</span></td>
        <td><span class="badge badge-${c.status === 'accepted' ? 'success' : 'warning'}">${c.status}</span></td>
        <td>${c.liveDuration ? fmtDur(c.liveDuration) : '—'}</td>
        <td><button class="btn btn-sm btn-danger" onclick="CallsModule.forceEnd('${c._id}')">End</button></td>
      </tr>`).join('');
        } catch (e) { console.error(e); }
    }

    async function forceEnd(id) {
        if (!confirm('Force end this call?')) return;
        try { await API.post(`/admin/calls/${id}/force-end`); loadActive(); } catch (e) { alert('Failed: ' + e.message); }
    }

    function txt(id, v) { const el = document.getElementById(id); if (el) el.textContent = v; }
    function fmt(n) { return n != null ? n.toLocaleString() : '—'; }
    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function fmtDur(s) { const m = Math.floor(s / 60); return m > 0 ? `${m}m ${s % 60}s` : `${s}s`; }
    function destroy() { if (interval) clearInterval(interval); interval = null; }

    return { init, destroy, forceEnd };
})();
