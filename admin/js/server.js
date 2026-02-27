/**
 * Server Status Module
 */
const ServerModule = (() => {
    let interval = null;

    function init(container) {
        container.innerHTML = `
      <div class="metrics-grid">
        <div class="metric-card accent-blue"><div class="metric-label">CPU</div><div class="metric-value" id="sCpu">—</div><div class="metric-bar"><div class="metric-bar-fill" id="sCpuBar"></div></div></div>
        <div class="metric-card accent-green"><div class="metric-label">Memory</div><div class="metric-value" id="sMem">—</div><div class="metric-bar"><div class="metric-bar-fill" id="sMemBar"></div></div></div>
        <div class="metric-card accent-purple"><div class="metric-label">Heap</div><div class="metric-value" id="sHeap">—</div></div>
        <div class="metric-card accent-orange"><div class="metric-label">Event Loop</div><div class="metric-value" id="sLoop">—</div></div>
        <div class="metric-card accent-cyan"><div class="metric-label">Sockets</div><div class="metric-value" id="sSockets">—</div></div>
        <div class="metric-card"><div class="metric-label">Uptime</div><div class="metric-value" id="sUptime">—</div></div>
      </div>
      <div class="cards-row">
        <div class="table-card flex-1">
          <h3>Redis</h3>
          <div class="kv-list" id="redisInfo">Loading...</div>
        </div>
        <div class="table-card flex-1">
          <h3>MongoDB</h3>
          <div class="kv-list" id="mongoInfo">Loading...</div>
        </div>
      </div>
      <div class="table-card">
        <h3>PM2 Processes</h3>
        <table class="data-table"><thead><tr><th>Name</th><th>Mode</th><th>PID</th><th>Status</th><th>CPU</th><th>Memory</th><th>Restarts</th></tr></thead>
        <tbody id="pm2Table"><tr><td colspan="7" class="loading">Loading...</td></tr></tbody></table>
      </div>`;
        load();
        interval = setInterval(load, 5000);
    }

    async function load() {
        try {
            const r = await API.get('/admin/server/status');
            const d = r.data;
            const s = d.system;
            if (s) {
                txt('sCpu', s.cpu?.percent + '%'); bar('sCpuBar', s.cpu?.percent);
                txt('sMem', s.memory?.percent + '%'); bar('sMemBar', s.memory?.percent);
                txt('sHeap', s.heap?.usedMB + ' MB'); txt('sLoop', s.eventLoopLag + ' ms');
                txt('sUptime', fmtUptime(s.processUptime));
            }
            txt('sSockets', d.sockets?.connected);

            // Redis
            const ri = d.redis || {};
            document.getElementById('redisInfo').innerHTML = kv({ 'Clients': ri.connected_clients, 'Memory': ri.used_memory_human, 'Ops/s': ri.instantaneous_ops_per_sec, 'Hit Rate': ri.hit_rate, 'Expired Keys': ri.expired_keys });

            // MongoDB
            const mi = d.mongodb || {};
            document.getElementById('mongoInfo').innerHTML = kv({ 'Current Conns': mi.connections?.current, 'Available': mi.connections?.available, 'Inserts': mi.opcounters?.insert, 'Queries': mi.opcounters?.query, 'Uptime': mi.uptime ? fmtUptime(mi.uptime) : '—' });

            // PM2
            const tb = document.getElementById('pm2Table');
            const procs = d.pm2 || [];
            tb.innerHTML = procs.map(p => `<tr>
        <td><strong>${esc(p.name)}</strong></td><td>${p.mode}</td><td>${p.pid}</td>
        <td><span class="badge badge-${p.status === 'online' ? 'success' : 'danger'}">${p.status}</span></td>
        <td>${p.cpu}%</td><td>${p.memoryMB} MB</td><td>${p.restarts}</td>
      </tr>`).join('') || '<tr><td colspan="7">No processes</td></tr>';
        } catch (e) { console.error(e); }
    }

    function txt(id, v) { const el = document.getElementById(id); if (el) el.textContent = v ?? '—'; }
    function bar(id, pct) { const el = document.getElementById(id); if (el) { el.style.width = Math.min(pct || 0, 100) + '%'; el.className = 'metric-bar-fill' + (pct > 80 ? ' danger' : pct > 60 ? ' warning' : ''); } }
    function kv(obj) { return Object.entries(obj).map(([k, v]) => `<div class="kv-row"><span class="kv-key">${k}</span><span class="kv-val">${v ?? '—'}</span></div>`).join(''); }
    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function fmtUptime(s) { const h = Math.floor(s / 3600); const m = Math.floor((s % 3600) / 60); return h > 24 ? Math.floor(h / 24) + 'd ' + (h % 24) + 'h' : h + 'h ' + m + 'm'; }
    function destroy() { if (interval) clearInterval(interval); interval = null; }

    return { init, destroy };
})();
