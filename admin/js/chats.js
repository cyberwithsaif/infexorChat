/**
 * Chat Analytics Module
 */
const ChatsModule = (() => {
    let interval = null;

    function init(container) {
        container.innerHTML = `
      <div class="metrics-grid">
        <div class="metric-card accent-blue"><div class="metric-label">Messages Today</div><div class="metric-value" id="chMsgsToday">—</div></div>
        <div class="metric-card accent-green"><div class="metric-label">Last Hour</div><div class="metric-value" id="chMsgsHour">—</div></div>
        <div class="metric-card accent-purple"><div class="metric-label">Msgs/sec</div><div class="metric-value" id="chMsgsSec">—</div></div>
        <div class="metric-card accent-cyan"><div class="metric-label">Total Chats</div><div class="metric-value" id="chTotal">—</div></div>
      </div>
      <div class="table-card">
        <h3>Top Active Chats</h3>
        <table class="data-table"><thead><tr><th>Chat</th><th>Type</th><th>Last Active</th></tr></thead>
        <tbody id="topChatsTable"><tr><td colspan="3" class="loading">Loading...</td></tr></tbody></table>
      </div>`;
        load();
        interval = setInterval(load, 10000);
    }

    async function load() {
        try {
            const r = await API.get('/admin/chats/analytics');
            const d = r.data;
            txt('chMsgsToday', fmt(d.messagesToday)); txt('chMsgsHour', fmt(d.messagesLastHour));
            txt('chMsgsSec', d.messagesPerSecond); txt('chTotal', fmt(d.totalChats));

            const tb = document.getElementById('topChatsTable');
            const chats = d.topChats || [];
            tb.innerHTML = chats.map(c => {
                const names = (c.participants || []).map(p => p.name || 'Unknown').join(', ');
                return `<tr><td>${esc(names)}</td><td><span class="badge">${c.type}</span></td><td>${timeAgo(c.lastMessageAt)}</td></tr>`;
            }).join('') || '<tr><td colspan="3">No chats</td></tr>';
        } catch (e) { console.error(e); }
    }

    function txt(id, v) { const el = document.getElementById(id); if (el) el.textContent = v; }
    function fmt(n) { return n != null ? n.toLocaleString() : '—'; }
    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function timeAgo(d) { if (!d) return '—'; const s = Math.floor((Date.now() - new Date(d)) / 1000); if (s < 60) return 'just now'; if (s < 3600) return Math.floor(s / 60) + 'm ago'; if (s < 86400) return Math.floor(s / 3600) + 'h ago'; return Math.floor(s / 86400) + 'd ago'; }
    function destroy() { if (interval) clearInterval(interval); interval = null; }

    return { init, destroy };
})();
