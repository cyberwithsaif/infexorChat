/**
 * Storage & Media Browser Module
 */
const StorageModule = (() => {
    let currentPath = '';

    function init(container) {
        container.innerHTML = `
      <div class="metrics-grid">
        <div class="metric-card accent-blue"><div class="metric-label">Disk Used</div><div class="metric-value" id="stDisk">—</div><div class="metric-bar"><div class="metric-bar-fill" id="stDiskBar"></div></div></div>
        <div class="metric-card accent-green"><div class="metric-label">Uploads</div><div class="metric-value" id="stUploads">—</div></div>
        <div class="metric-card accent-purple"><div class="metric-label">Logs</div><div class="metric-value" id="stLogs">—</div></div>
        <div class="metric-card accent-orange"><div class="metric-label">Available</div><div class="metric-value" id="stFree">—</div></div>
      </div>
      <div class="table-card">
        <div class="card-header">
          <h3>Media Browser</h3>
          <div class="card-actions">
            <select id="mediaFilter" class="input-sm"><option value="">All</option><option value="image">Images</option><option value="video">Videos</option><option value="audio">Audio</option></select>
            <input type="text" id="mediaSearch" class="input-sm" placeholder="Search files...">
          </div>
        </div>
        <div id="breadcrumb" class="breadcrumb"></div>
        <table class="data-table"><thead><tr><th>Name</th><th>Type</th><th>Size</th><th>Modified</th><th>Actions</th></tr></thead>
        <tbody id="mediaTable"><tr><td colspan="5" class="loading">Loading...</td></tr></tbody></table>
        <div id="mediaPagination" class="pagination"></div>
      </div>`;

        loadStorage();
        browse('');
        document.getElementById('mediaFilter').addEventListener('change', () => browse(currentPath));
        document.getElementById('mediaSearch').addEventListener('input', debounce(() => browse(currentPath), 300));
    }

    async function loadStorage() {
        try {
            const r = await API.get('/admin/storage/stats');
            const d = r.data;
            txt('stDisk', d.disk?.percent + '%'); bar('stDiskBar', d.disk?.percent);
            txt('stUploads', d.uploads?.mb + ' MB'); txt('stLogs', d.logs?.mb + ' MB');
            txt('stFree', ((d.disk?.available || 0) / 1073741824).toFixed(1) + ' GB');
        } catch (e) { console.error(e); }
    }

    async function browse(path, page = 1) {
        currentPath = path;
        const filter = document.getElementById('mediaFilter')?.value || '';
        const search = document.getElementById('mediaSearch')?.value || '';
        try {
            const r = await API.get(`/admin/storage/browse?path=${encodeURIComponent(path)}&filter=${filter}&search=${encodeURIComponent(search)}&page=${page}&limit=30`);
            const d = r.data;

            // Breadcrumb
            const bc = document.getElementById('breadcrumb');
            const parts = path ? path.split('/').filter(Boolean) : [];
            bc.innerHTML = `<a class="bc-link" onclick="StorageModule.browse('')">uploads</a>` +
                parts.map((p, i) => ` / <a class="bc-link" onclick="StorageModule.browse('${parts.slice(0, i + 1).join('/')}')">${esc(p)}</a>`).join('');

            // Table
            const tb = document.getElementById('mediaTable');
            const items = d.items || [];
            if (!items.length) { tb.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:20px;color:var(--text-muted)">Empty folder</td></tr>'; return; }
            tb.innerHTML = items.map(f => {
                if (f.isDirectory) {
                    return `<tr onclick="StorageModule.browse('${esc(f.path)}')" style="cursor:pointer"><td>📁 <strong>${esc(f.name)}</strong></td><td>Folder</td><td>—</td><td>—</td><td>—</td></tr>`;
                }
                const icon = f.mediaType === 'image' ? '🖼️' : f.mediaType === 'video' ? '🎬' : f.mediaType === 'audio' ? '🎵' : '📄';
                return `<tr>
          <td>${icon} ${esc(f.name)}</td>
          <td><span class="badge">${f.mediaType}</span></td>
          <td>${f.sizeMB} MB</td>
          <td>${f.modified ? new Date(f.modified).toLocaleDateString() : '—'}</td>
          <td>
            <a href="${f.url}" target="_blank" class="btn btn-sm">View</a>
            <button class="btn btn-sm btn-danger" onclick="StorageModule.deleteFile('${esc(f.path)}')">Del</button>
          </td>
        </tr>`;
            }).join('');

            // Pagination
            const pg = d.pagination;
            if (pg && pg.pages > 1) {
                document.getElementById('mediaPagination').innerHTML = Array.from({ length: pg.pages }, (_, i) =>
                    `<button class="btn btn-sm ${i + 1 === pg.page ? 'btn-primary' : ''}" onclick="StorageModule.browse('${esc(currentPath)}', ${i + 1})">${i + 1}</button>`
                ).join(' ');
            }
        } catch (e) { console.error(e); }
    }

    async function deleteFile(path) {
        if (!confirm(`Delete ${path}?`)) return;
        try { await API.del('/admin/storage/media', { path }); browse(currentPath); } catch (e) { alert('Failed: ' + e.message); }
    }

    function txt(id, v) { const el = document.getElementById(id); if (el) el.textContent = v ?? '—'; }
    function bar(id, pct) { const el = document.getElementById(id); if (el) { el.style.width = Math.min(pct || 0, 100) + '%'; el.className = 'metric-bar-fill' + (pct > 80 ? ' danger' : pct > 60 ? ' warning' : ''); } }
    function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
    function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }
    function destroy() { }

    return { init, destroy, browse, deleteFile };
})();
