/**
 * Security Module
 */
const SecurityModule = (() => {
    function init(container) {
        container.innerHTML = `
      <div class="metrics-grid">
        <div class="metric-card accent-red"><div class="metric-label">Rate Limit Triggers</div><div class="metric-value" id="secRate">—</div></div>
        <div class="metric-card accent-orange"><div class="metric-label">TURN Status</div><div class="metric-value" id="secTurn">—</div></div>
      </div>
      <div class="table-card">
        <h3>Security Events</h3>
        <table class="data-table"><thead><tr><th>Type</th><th>User ID</th><th>Count</th><th>Key</th></tr></thead>
        <tbody id="secEventsTable"><tr><td colspan="4" class="loading">Loading...</td></tr></tbody></table>
      </div>
      <div class="cards-row">
        <div class="table-card flex-1">
          <h3>Alert Configuration</h3>
          <form id="alertForm" class="form">
            <div class="form-row"><label>CPU Threshold (%)</label><input type="number" id="aCpu" value="80" class="input-sm"></div>
            <div class="form-row"><label>RAM Threshold (%)</label><input type="number" id="aRam" value="85" class="input-sm"></div>
            <div class="form-row"><label>Disk Threshold (%)</label><input type="number" id="aDisk" value="85" class="input-sm"></div>
            <div class="form-row"><label>Telegram Bot Token</label><input type="text" id="aTgToken" class="input-sm" placeholder="bot123:ABC..."></div>
            <div class="form-row"><label>Telegram Chat ID</label><input type="text" id="aTgChat" class="input-sm" placeholder="-100123456"></div>
            <div class="form-row"><label>Slack Webhook</label><input type="url" id="aSlack" class="input-sm" placeholder="https://hooks.slack.com/..."></div>
            <button type="submit" class="btn btn-primary">Save Config</button>
          </form>
        </div>
        <div class="table-card flex-1">
          <h3>TURN Server</h3>
          <div class="kv-list" id="turnInfo">Loading...</div>
        </div>
      </div>`;

        loadEvents();
        loadAlertConfig();
        loadTurn();

        document.getElementById('alertForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            try {
                await API.put('/admin/alerts/config', {
                    cpuThreshold: parseInt(document.getElementById('aCpu').value),
                    ramThreshold: parseInt(document.getElementById('aRam').value),
                    diskThreshold: parseInt(document.getElementById('aDisk').value),
                    telegramBotToken: document.getElementById('aTgToken').value,
                    telegramChatId: document.getElementById('aTgChat').value,
                    slackWebhook: document.getElementById('aSlack').value,
                    enabled: true,
                });
                alert('Alert config saved!');
            } catch (e) { alert('Failed: ' + e.message); }
        });
    }

    async function loadEvents() {
        try {
            const r = await API.get('/admin/security/events');
            const events = r.data?.events || [];
            txt('secRate', events.length);
            const tb = document.getElementById('secEventsTable');
            if (!events.length) { tb.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:20px;color:var(--text-muted)">No security events</td></tr>'; return; }
            tb.innerHTML = events.map(e => `<tr><td><span class="badge badge-warning">${esc(e.type)}</span></td><td class="mono">${esc(e.userId)}</td><td>${e.count}</td><td class="mono">${esc(e.key)}</td></tr>`).join('');
        } catch (e) { console.error(e); }
    }

    async function loadAlertConfig() {
        try {
            const r = await API.get('/admin/alerts/config');
            const d = r.data;
            if (d.cpuThreshold) document.getElementById('aCpu').value = d.cpuThreshold;
            if (d.ramThreshold) document.getElementById('aRam').value = d.ramThreshold;
            if (d.diskThreshold) document.getElementById('aDisk').value = d.diskThreshold;
            if (d.telegramBotToken) document.getElementById('aTgToken').value = d.telegramBotToken;
            if (d.telegramChatId) document.getElementById('aTgChat').value = d.telegramChatId;
            if (d.slackWebhook) document.getElementById('aSlack').value = d.slackWebhook;
        } catch { }
    }

    async function loadTurn() {
        try {
            const r = await API.get('/admin/turn/status');
            const d = r.data;
            txt('secTurn', d.available ? 'Online' : 'Unavailable');
            document.getElementById('turnInfo').innerHTML = kv({ 'Status': d.available ? '✅ Online' : '❌ Offline', 'Active Allocations': d.activeAllocations ?? '—' });
        } catch (e) { document.getElementById('turnInfo').innerHTML = '<p>Error loading TURN status</p>'; }
    }

    function txt(id, v) { const el = document.getElementById(id); if (el) el.textContent = v ?? '—'; }
    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function kv(obj) { return Object.entries(obj).map(([k, v]) => `<div class="kv-row"><span class="kv-key">${k}</span><span class="kv-val">${v ?? '—'}</span></div>`).join(''); }
    function destroy() { }

    return { init, destroy };
})();
