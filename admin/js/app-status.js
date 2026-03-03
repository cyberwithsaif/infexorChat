/**
 * Infexor Chat Admin - Official App Status Module
 */
const AppStatusModule = (() => {
    let currentTable = null;
    let currentModal = null;
    let currentData = [];

    function init(container) {
        container.innerHTML = `
      <div class="section-header">
        <div>
          <h2>Official App Status</h2>
          <p class="section-subtitle">Manage system-wide status updates visible to all users</p>
        </div>
        <div class="section-actions">
          <button class="btn btn-primary" onclick="AppStatusModule.createStatus()">
             <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg> Add Status
          </button>
        </div>
      </div>
      <div id="statusTableWrapper"></div>
    `;

        currentTable = Components.Table.create({
            columns: [
                {
                    key: 'type',
                    label: 'Type',
                    width: '80px',
                    render: (s) => {
                        const icons = {
                            text: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 7 4 4 20 4 20 7"/><line x1="9" y1="20" x2="15" y2="20"/><line x1="12" y1="4" x2="12" y2="20"/></svg>',
                            image: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>',
                            video: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2" ry="2"/></svg>'
                        };
                        return `<span style="display:inline-flex;align-items:center;gap:5px;text-transform:capitalize">${icons[s.type] || ''} ${s.type}</span>`;
                    }
                },
                {
                    key: 'content',
                    label: 'Content / Media',
                    render: (s) => {
                        if (s.type === 'text') {
                            return `<div style="display:flex;align-items:center;gap:10px">
                <div style="width:30px;height:30px;border-radius:6px;background:${s.backgroundColor || '#075E54'}"></div>
                <div style="flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" title="${Utils.escapeHtml(s.content)}">${Utils.escapeHtml(s.content)}</div>
              </div>`;
                        } else {
                            const url = s.media?.url || '';
                            return `<div style="display:flex;align-items:center;gap:10px">
                <div style="width:30px;height:30px;border-radius:6px;background:var(--bg-hover);display:flex;align-items:center;justify-content:center;overflow:hidden">
                  ${s.type === 'image' && url ? `<img src="${url}" style="width:100%;height:100%;object-fit:cover">` : '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>'}
                </div>
                <div style="flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--primary)"><a href="${url}" target="_blank" style="text-decoration:none;color:inherit">${url.split('/').pop() || 'Media File'}</a></div>
              </div>`;
                        }
                    }
                },
                {
                    key: 'createdAt',
                    label: 'Created',
                    width: '140px',
                    render: (s) => `<span style="color:var(--text-muted);font-size:12px">${Utils.formatDateTime(s.createdAt)}</span>`
                },
                {
                    key: 'expiresAt',
                    label: 'Expires',
                    width: '140px',
                    render: (s) => {
                        const isExpired = new Date(s.expiresAt) <= new Date();
                        return `<span style="font-size:12px;color:var(--${isExpired ? 'danger' : 'text-muted'})">${Utils.formatDateTime(s.expiresAt)}</span>`;
                    }
                },
                {
                    key: 'actions',
                    label: '',
                    width: '100px',
                    render: (s) => `
            <div style="display:flex;gap:4px">
              <button class="btn btn-icon btn-ghost" onclick="event.stopPropagation();AppStatusModule.viewStatusViewers('${s._id}')" title="Viewers (${s.viewers ? s.viewers.length : 0})">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                  <circle cx="12" cy="12" r="3"></circle>
                </svg>
              </button>
              <button class="btn btn-icon btn-danger" onclick="event.stopPropagation();AppStatusModule.deleteStatus('${s._id}')" title="Delete Status">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                </svg>
              </button>
            </div>`
                }
            ],
            dataSource: fetchStatuses,
            searchable: false,
            filterable: false
        });

        document.getElementById('statusTableWrapper').appendChild(currentTable);
    }

    async function fetchStatuses(state) {
        try {
            const response = await API.get('/admin/status');
            currentData = response.data.statuses || [];
            return {
                items: currentData,
                pagination: { page: 1, totalPages: 1, total: currentData.length, limit: 100 }
            };
        } catch (error) {
            console.error('Failed to fetch official statuses:', error);
            return { items: [], pagination: { page: 1, totalPages: 1, total: 0, limit: 100 } };
        }
    }

    function createStatus() {
        currentModal = Components.Modal.open({
            title: 'Post Official Status',
            size: 'medium',
            content: `
        <form id="statusForm" novalidate>
          <div class="form-group">
            <label>Status Type</label>
            <div class="platform-toggle" id="typeToggle">
              <button type="button" class="platform-btn active" data-type="text">
                 <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 7 4 4 20 4 20 7"/><line x1="9" y1="20" x2="15" y2="20"/><line x1="12" y1="4" x2="12" y2="20"/></svg> Text
              </button>
              <button type="button" class="platform-btn" data-type="image">
                 <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg> Image
              </button>
              <button type="button" class="platform-btn" data-type="video">
                 <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2" ry="2"/></svg> Video
              </button>
            </div>
          </div>

          <div id="textContentSection">
            <div class="form-group">
              <label>Text Content <span class="required">*</span></label>
              <textarea id="st-content" class="form-control" rows="3" placeholder="Type your status..." maxlength="500"></textarea>
              <div class="char-counter" id="contentCounter">0 / 500</div>
              <div class="form-error" id="contentError"></div>
            </div>
            <div class="form-group">
              <label>Background Color</label>
              <div style="display:flex;gap:10px;align-items:center">
                <input type="color" id="st-color" value="#075E54" style="width:40px;height:40px;padding:0;border:none;border-radius:6px;cursor:pointer">
                <span id="st-color-val" style="font-family:monospace;font-size:13px;color:var(--text-muted)">#075E54</span>
              </div>
            </div>
          </div>

          <div id="mediaContentSection" style="display:none">
            <div class="form-group">
              <label>Media Source <span class="required">*</span></label>
              <div style="display:flex; gap:10px; margin-bottom: 10px;">
                <input type="file" id="st-media-file" class="form-control" accept="image/*,video/*">
                <span id="st-media-uploading" style="display:none;align-items:center;color:var(--primary);font-size:13px;">Uploading...</span>
              </div>
              <div class="form-divider" style="text-align:center; font-size:12px; margin: 10px 0;">OR ENTER URL</div>
              <input type="text" id="st-media-url" class="form-control" placeholder="https://example.com/image.jpg or /api/upload/...">
              <div class="form-help">Upload a file or provide a direct link.</div>
              <div class="form-error" id="mediaError"></div>
            </div>
            <div class="form-group" style="display:none" id="thumbnailSection">
              <label>Video Thumbnail URL <span style="color:var(--text-dim)">(optional)</span></label>
              <input type="text" id="st-media-thumb" class="form-control" placeholder="https://example.com/thumb.jpg or /api/upload/...">
            </div>
          </div>

        </form>
      `,
            buttons: [
                { label: 'Cancel', className: 'btn-ghost', onClick: (m) => Components.Modal.close(m) },
                { label: 'Post Status', className: 'btn-primary', onClick: validateAndSubmit }
            ],
            onClose: () => currentModal = null
        });

        const typeToggle = currentModal.querySelectorAll('.platform-btn');
        const textSection = currentModal.querySelector('#textContentSection');
        const mediaSection = currentModal.querySelector('#mediaContentSection');
        const thumbSection = currentModal.querySelector('#thumbnailSection');
        const colorInput = currentModal.querySelector('#st-color');
        const contentInput = currentModal.querySelector('#st-content');

        let currentType = 'text';

        typeToggle.forEach(btn => {
            btn.addEventListener('click', () => {
                typeToggle.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentType = btn.dataset.type;

                if (currentType === 'text') {
                    textSection.style.display = 'block';
                    mediaSection.style.display = 'none';
                } else {
                    textSection.style.display = 'none';
                    mediaSection.style.display = 'block';
                    thumbSection.style.display = currentType === 'video' ? 'block' : 'none';
                }
            });
        });

        colorInput.addEventListener('input', (e) => {
            currentModal.querySelector('#st-color-val').textContent = e.target.value.toUpperCase();
        });

        contentInput.addEventListener('input', () => {
            currentModal.querySelector('#contentCounter').textContent = `${contentInput.value.length} / 500`;
            currentModal.querySelector('#contentError').textContent = '';
        });

        const fileInput = currentModal.querySelector('#st-media-file');
        const urlInput = currentModal.querySelector('#st-media-url');
        const uploadIndicator = currentModal.querySelector('#st-media-uploading');

        fileInput.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;

            uploadIndicator.style.display = 'inline-flex';
            try {
                const isVideo = file.type.startsWith('video');
                const uploadRoute = isVideo ? '/admin/upload/video' : '/admin/upload/image';
                const fieldName = isVideo ? 'video' : 'image';

                // Ensure the selected type matches the uploaded file
                if ((isVideo && currentType !== 'video') || (!isVideo && currentType !== 'image')) {
                    const btnToClick = Array.from(typeToggle).find(b => b.dataset.type === (isVideo ? 'video' : 'image'));
                    if (btnToClick) btnToClick.click();
                }

                const response = await API.upload(uploadRoute, file, fieldName);
                if (response.data && response.data.url) {
                    urlInput.value = response.data.url;
                    // For images, if thumbnail was generated, it might be useful, but url is fine
                    if (response.data.thumbnail && currentType === 'video') {
                        currentModal.querySelector('#st-media-thumb').value = response.data.thumbnail;
                    }
                }
                Components.Toast.success('File uploaded successfully');
            } catch (err) {
                console.error('Upload failed:', err);
                Components.Toast.error('Upload failed: ' + err.message);
                fileInput.value = ''; // clear 
            } finally {
                uploadIndicator.style.display = 'none';
            }
        });

        currentModal.dataset.statusType = 'text';
    }

    async function validateAndSubmit(modal) {
        const activeBtn = modal.querySelector('.platform-btn.active');
        const type = activeBtn ? activeBtn.dataset.type : 'text';

        const payload = { type };

        if (type === 'text') {
            const content = modal.querySelector('#st-content').value.trim();
            if (!content) {
                modal.querySelector('#contentError').textContent = 'Text content is required';
                return;
            }
            payload.content = content;
            payload.backgroundColor = modal.querySelector('#st-color').value;
        } else {
            const url = modal.querySelector('#st-media-url').value.trim();
            const thumb = modal.querySelector('#st-media-thumb').value.trim();
            if (!url || !/^(https?:\/\/|\/)/.test(url)) {
                modal.querySelector('#mediaError').textContent = 'Valid media URL or relative path is required';
                return;
            }
            payload.media = { url, thumbnail: thumb };
        }

        try {
            await API.post('/admin/status', payload);
            Components.Toast.success('Official Status posted successfully');
            Components.Modal.close(currentModal);
            refresh();
        } catch (error) {
            Components.Toast.error(error.message || 'Failed to post status');
        }
    }

    async function deleteStatus(id) {
        if (!confirm('Are you sure you want to delete this status? It will disappear for all users immediately.')) return;
        try {
            await API.del(`/admin/status/${id}`);
            Components.Toast.success('Status deleted');
            refresh();
        } catch (e) {
            Components.Toast.error(e.message || 'Delete failed');
        }
    }

    function viewStatusViewers(id) {
        const status = currentData.find(s => s._id === id);
        if (!status) return;

        const viewers = status.viewers || [];

        let content = '';
        if (viewers.length === 0) {
            content = '<div style="padding: 20px; text-align: center; color: var(--text-muted);">No views yet</div>';
        } else {
            content = '<div style="display:flex;flex-direction:column;gap:12px;max-height:400px;overflow-y:auto;padding-right:8px;">';
            viewers.forEach(v => {
                const user = v.userId || {};
                const name = user.name || 'Unknown User';
                const phone = user.phone || 'Unknown Phone';
                const avatar = user.avatar ? (user.avatar.startsWith('http') ? user.avatar : `/uploads/${user.avatar}`) : '';
                const viewedAt = Utils.formatDateTime(v.viewedAt);

                content += `
                    <div style="display:flex;align-items:center;gap:12px;padding:8px;border-radius:8px;background:var(--bg-hover);">
                        <div style="width:40px;height:40px;border-radius:50%;background:var(--bg-card);display:flex;align-items:center;justify-content:center;overflow:hidden;flex-shrink:0;">
                            ${avatar ? `<img src="${avatar}" style="width:100%;height:100%;object-fit:cover;">` : `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>`}
                        </div>
                        <div style="flex:1;min-width:0;">
                            <div style="font-weight:600;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${name}</div>
                            <div style="font-size:12px;color:var(--text-muted);">${phone}</div>
                        </div>
                        <div style="font-size:12px;color:var(--text-muted);white-space:nowrap;">
                            ${viewedAt}
                        </div>
                    </div>
                `;
            });
            content += '</div>';
        }

        currentModal = Components.Modal.open({
            title: `Viewed by ${viewers.length}`,
            size: 'medium',
            content: content,
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

    return { init, refresh, destroy, createStatus, deleteStatus, viewStatusViewers };
})();
