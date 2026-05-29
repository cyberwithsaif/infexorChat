/**
 * Infexor Chat Admin - Official Messages Module
 * Manage the official Infexor account profile and send messages to users
 */

const OfficialMessagesModule = (() => {
  let currentTable = null;
  let currentModal = null;
  let selectedPlatform = 'both';
  let pendingAvatarFile = null;

  // ─── init ────────────────────────────────────────────────────────────────
  function init(container) {
    container.innerHTML = `
      <div class="section-header">
        <div>
          <h2>Official Messages</h2>
          <p class="section-subtitle">Manage the Infexor account and send in-app messages to users</p>
        </div>
        <div class="section-actions">
          <button class="btn btn-primary" id="omSendMsgBtn" style="padding:10px 20px;font-size:14px;box-shadow:0 4px 12px rgba(99,102,241,0.3)">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22 11 13 2 9l20-7z"/></svg>
            Send Message
          </button>
        </div>
      </div>

      <!-- Premium Profile Card -->
      <div class="card om-card-premium" id="omProfileCard" style="margin-bottom:24px">
        <div class="om-profile-layout">
          
          <!-- Avatar Section -->
          <div class="om-avatar-container">
            <div id="omAvatarWrapper" class="om-avatar-glow" onclick="document.getElementById('omAvatarInput').click()">
              <div class="om-avatar-inner">
                <span id="omAvatarInitial" style="font-size:42px;font-weight:700;color:#fff">I</span>
                <img id="omAvatarImg" src="" alt="Official Avatar" style="display:none;width:100%;height:100%;object-fit:cover;position:absolute;inset:0" />
              </div>
              <div class="om-avatar-badge">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
              </div>
            </div>
            <input type="file" id="omAvatarInput" accept="image/*" style="display:none" />
            <p style="font-size:12px;color:rgba(255,255,255,0.5);text-transform:uppercase;letter-spacing:1px">Official Photo</p>
          </div>

          <!-- Name & Actions Section -->
          <div class="om-profile-details">
            <div style="display:flex;flex-direction:column;gap:8px">
              <label style="font-size:12px;color:var(--text-muted);text-transform:uppercase;letter-spacing:1px;font-weight:600">Display Name</label>
              <input type="text" id="omNameInput" class="om-input-premium" maxlength="50" placeholder="e.g. Infexor" />
              <div style="font-size:12px;color:var(--text-dim);margin-top:4px">This name appears on every broadcast sent from this account</div>
            </div>
            
            <div style="display:flex;align-items:center;gap:16px;margin-top:8px">
              <button class="btn btn-primary" id="omSaveProfileBtn" style="padding:10px 24px">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                Save Profile
              </button>
              <span id="omSaveStatus" style="font-size:13px;font-weight:500"></span>
            </div>
          </div>
          
        </div>
      </div>

      <!-- Message History -->
      <div class="card">
        <div class="card-header">
          <h3 class="card-title">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.5" style="margin-right:8px"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            Broadcast History
          </h3>
        </div>
        <div id="omTableWrapper" style="padding:0 0 4px"></div>
      </div>
    `;

    document.getElementById('omSendMsgBtn').addEventListener('click', composeMessage);
    document.getElementById('omSaveProfileBtn').addEventListener('click', saveProfile);
    document.getElementById('omAvatarInput').addEventListener('change', handleAvatarPick);

    loadProfile();
    initTable();
  }

  // ─── profile ─────────────────────────────────────────────────────────────
  async function loadProfile() {
    try {
      const res = await API.get('/admin/official-profile');
      const { name, avatar } = res.data;
      const nameInput = document.getElementById('omNameInput');
      if (nameInput) nameInput.value = name || 'Infexor';
      setAvatarDisplay(avatar, name);
    } catch (e) {
      console.warn('Could not load official profile:', e.message);
    }
  }

  function setAvatarDisplay(avatarUrl, name) {
    const initEl = document.getElementById('omAvatarInitial');
    const imgEl = document.getElementById('omAvatarImg');
    if (!initEl || !imgEl) return;
    if (avatarUrl) {
      // If relative path, prepend origin
      const fullUrl = avatarUrl.startsWith('/') ? `${window.location.origin}${avatarUrl}` : avatarUrl;
      imgEl.src = fullUrl;
      imgEl.style.display = 'block';
      initEl.style.display = 'none';
    } else {
      initEl.textContent = (name || 'I')[0].toUpperCase();
      imgEl.style.display = 'none';
      initEl.style.display = '';
    }
  }

  function handleAvatarPick(e) {
    const file = e.target.files[0];
    if (!file) return;
    pendingAvatarFile = file;
    // Preview locally
    const reader = new FileReader();
    reader.onload = (ev) => {
      const imgEl = document.getElementById('omAvatarImg');
      const initEl = document.getElementById('omAvatarInitial');
      if (imgEl) { imgEl.src = ev.target.result; imgEl.style.display = 'block'; }
      if (initEl) initEl.style.display = 'none';
    };
    reader.readAsDataURL(file);
    setStatus('Photo selected — click Save Profile to apply', 'var(--text-muted)');
  }

  async function saveProfile() {
    const nameInput = document.getElementById('omNameInput');
    const name = nameInput ? nameInput.value.trim() : '';

    if (!name && !pendingAvatarFile) {
      setStatus('Nothing to save', 'var(--warning)');
      return;
    }
    if (name && name.length > 50) {
      setStatus('Name must be 50 characters or less', 'var(--danger)');
      return;
    }

    const saveBtn = document.getElementById('omSaveProfileBtn');
    saveBtn.disabled = true;
    setStatus('Saving…', 'var(--text-muted)');

    try {
      const formData = new FormData();
      if (name) formData.append('name', name);
      if (pendingAvatarFile) formData.append('avatar', pendingAvatarFile);

      const token = API.getToken();
      const res = await fetch(`${window.location.origin}/api/admin/official-profile`, {
        method: 'PUT',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: formData,
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Failed to update profile');

      pendingAvatarFile = null;
      document.getElementById('omAvatarInput').value = '';
      setAvatarDisplay(data.data.avatar, data.data.name);
      setStatus('Profile saved!', 'var(--success)');
      Components.Toast.success('Official profile updated');
      setTimeout(() => setStatus('', ''), 3000);
    } catch (err) {
      console.error(err);
      setStatus(err.message || 'Failed to save', 'var(--danger)');
      Components.Toast.error(err.message || 'Failed to save profile');
    } finally {
      saveBtn.disabled = false;
    }
  }

  function setStatus(msg, color) {
    const el = document.getElementById('omSaveStatus');
    if (el) { el.textContent = msg; el.style.color = color || 'var(--text-muted)'; }
  }

  // ─── message table ────────────────────────────────────────────────────────
  function initTable() {
    const wrapper = document.getElementById('omTableWrapper');
    if (!wrapper) return;

    currentTable = Components.Table.create({
      columns: [
        {
          key: 'message',
          label: 'Message',
          width: '30%',
          render: (m) => {
            const type = m.type || 'text';
            const typeBadge = type !== 'text' ? `<span style="font-size:10px;background:var(--primary);color:#fff;padding:2px 6px;border-radius:10px;margin-right:6px">${type.toUpperCase()}</span>` : '';
            const text = type === 'revoked' ? '<i style="color:var(--text-dim)">This message was deleted</i>' : Utils.escapeHtml(m.message || '');
            return `
              <div style="display:flex;align-items:center;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" title="${Utils.escapeHtml(m.message || '')}">
                ${typeBadge}${text}
              </div>`;
          }
        },
        {
          key: 'platform',
          label: 'Platform',
          width: '110px',
          render: (m) => {
            const icons = {
              android: '<svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24A9.88 9.88 0 0 0 12 8c-1.63 0-3.16.39-4.47 1.07L5.65 5.83c-.18-.28-.54-.37-.83-.22-.3.16-.42.54-.26.85l1.84 3.18C3.93 11.06 2.5 13.38 2.5 16h19c0-2.62-1.43-4.94-3.9-6.52M9 13.5a1 1 0 1 1 0-2 1 1 0 0 1 0 2m6 0a1 1 0 1 1 0-2 1 1 0 0 1 0 2"/></svg>',
              ios: '<svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11"/></svg>',
              both: '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>'
            };
            const labels = { android: 'Android', ios: 'iOS', both: 'All Devices' };
            const iconKey = m.platform || 'both';
            return `<span style="display:inline-flex;align-items:center;gap:5px;color:var(--text-muted)">${icons[iconKey] || icons.both} ${labels[iconKey] || 'All'}</span>`;
          }
        },
        {
          key: 'recipientCount',
          label: 'Sent To',
          width: '80px',
          render: (m) => `<span style="font-weight:600;color:var(--success)">${Utils.formatNumber(m.recipientCount || 0)}</span>`
        },
        {
          key: 'createdAt',
          label: 'Sent At',
          width: '140px',
          render: (m) => `<span style="color:var(--text-muted);font-size:12px">${Utils.formatDateTime(m.createdAt)}</span>`
        },
        {
          key: 'actions',
          label: 'Actions',
          width: '160px',
          render: (m) => {
            if (m.type === 'revoked') return '<span style="color:var(--text-dim);font-size:12px">Deleted</span>';
            return `
                 <div style="display:flex;gap:8px">
                    <button class="btn btn-sm btn-ghost" onclick="OfficialMessagesModule.viewStats('${m._id}')">
                       <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right:4px"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
                       Stats
                    </button>
                    <button class="btn btn-sm" style="color:var(--danger);background:rgba(255,59,48,0.1);border-color:transparent" onclick="OfficialMessagesModule.deleteMessage('${m._id}')">
                       <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right:4px"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                       Delete
                    </button>
                 </div>
              `;
          }
        }
      ],
      dataSource: fetchMessages,
      searchable: false,
      filterable: false
    });

    wrapper.appendChild(currentTable);
  }

  async function fetchMessages(state) {
    try {
      const params = new URLSearchParams({ page: state.page, limit: state.limit });
      const response = await API.get(`/admin/official-messages?${params}`);
      const pag = response.data.pagination || {};
      return {
        items: response.data.messages || [],
        pagination: {
          page: pag.page || state.page,
          totalPages: pag.totalPages || 1,
          total: pag.total || 0,
          limit: pag.limit || state.limit
        }
      };
    } catch (error) {
      console.error('Failed to fetch official messages:', error);
      return { items: [], pagination: { page: 1, totalPages: 1, total: 0, limit: state.limit } };
    }
  }

  // ─── compose ──────────────────────────────────────────────────────────────
  function composeMessage() {
    selectedPlatform = 'both';

    currentModal = Components.Modal.open({
      title: 'Send Official Message',
      size: 'large',
      content: `
        <form id="omForm" novalidate style="display:flex;flex-direction:column;gap:20px">
          
          <div style="display:flex;gap:20px;flex-wrap:wrap">
            <div style="flex:1;min-width:200px">
               <label style="display:block;margin-bottom:8px;font-size:13px;font-weight:500;color:var(--text)">Message Type <span class="required">*</span></label>
               <select id="om-type" class="form-control" style="background:var(--bg-input);color:var(--text);border-radius:8px">
                  <option value="text">Text Message</option>
                  <option value="image">Image Photo</option>
                  <option value="video">Video Clip</option>
                  <option value="audio">Audio Message</option>
                  <option value="document">Document / PDF</option>
               </select>
            </div>
            <div style="flex:1;min-width:200px" id="omMediaInputContainer" class="hidden">
               <label style="display:block;margin-bottom:8px;font-size:13px;font-weight:500;color:var(--text)">Media Attachment <span class="required">*</span></label>
               <input type="file" id="om-media" class="form-control" style="background:var(--bg-input);color:var(--text);border-radius:8px;padding:9px 12px" />
            </div>
          </div>

          <div>
            <label style="display:block;margin-bottom:8px;font-size:13px;font-weight:500;color:var(--text)">Message Text <span style="font-size:12px;color:var(--text-dim);font-weight:normal">(Optional if media is attached)</span></label>
            <textarea id="om-message" class="form-control" rows="4" style="background:var(--bg-input);color:var(--text);border-radius:8px;resize:vertical"
              placeholder="Type your official message here..." maxlength="2000"></textarea>
            <div style="display:flex;justify-content:space-between;margin-top:6px">
              <div class="form-error" id="omMsgError" style="margin:0"></div>
              <div class="char-counter" id="omCharCounter" style="margin:0;font-weight:500">0 / 2000</div>
            </div>
          </div>

          <div>
            <label style="display:block;margin-bottom:8px;font-size:13px;font-weight:500;color:var(--text)">Target Platform</label>
            <div class="platform-toggle" id="omPlatformToggle">
              <button type="button" class="platform-btn active" data-platform="both">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
                All Devices
              </button>
              <button type="button" class="platform-btn" data-platform="android">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24A9.88 9.88 0 0 0 12 8c-1.63 0-3.16.39-4.47 1.07L5.65 5.83c-.18-.28-.54-.37-.83-.22-.3.16-.42.54-.26.85l1.84 3.18C3.93 11.06 2.5 13.38 2.5 16h19c0-2.62-1.43-4.94-3.9-6.52M9 13.5a1 1 0 1 1 0-2 1 1 0 0 1 0 2m6 0a1 1 0 1 1 0-2 1 1 0 0 1 0 2"/></svg>
                Android
              </button>
              <button type="button" class="platform-btn" data-platform="ios">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11"/></svg>
                iPhone
              </button>
            </div>
          </div>

          <!-- Live smartphone chat preview -->
          <div class="om-chat-preview-container">
            <!-- Header -->
            <div class="om-chat-header">
              <div style="width:38px;height:38px;border-radius:50%;overflow:hidden;background:linear-gradient(135deg,var(--primary),#8b5cf6)">
                <img id="omPreviewAvatarImg" src="" style="display:none;width:100%;height:100%;object-fit:cover" />
                <div id="omPreviewInitial" style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:600;font-size:16px">I</div>
              </div>
              <div style="flex:1">
                <div style="display:flex;align-items:center;gap:6px">
                  <strong id="omPreviewName" style="color:#e9edef;font-size:15px;letter-spacing:0.3px">Infexor</strong>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="var(--success)" stroke="var(--bg-card)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M9 12l2 2 4-4"/></svg>
                </div>
                <div style="color:var(--primary);font-size:12px;font-weight:500;letter-spacing:0.5px">Official Account</div>
              </div>
            </div>

            <!-- Chat Bubble -->
            <div style="display:flex;flex-direction:column">
              <div class="om-chat-bubble">
                <div id="omPreviewMediaBox" class="om-msg-media-box" style="display:none;"></div>
                <div id="omPreviewContent" style="white-space:pre-wrap;word-wrap:break-word">Your message will appear here...</div>
                
                <div class="om-msg-footer">
                  <span>10:42 AM</span>
                </div>
              </div>
            </div>
          </div>
        </form>
        <style>
          .hidden { display: none !important; }
        </style>
      `,
      buttons: [
        {
          label: 'Cancel',
          className: 'btn-ghost',
          onClick: () => { Components.Modal.close(currentModal); currentModal = null; }
        },
        {
          label: 'Send to Users',
          className: 'btn-primary',
          onClick: async (inner) => {
            const text = inner.querySelector('#om-message').value.trim();
            const type = inner.querySelector('#om-type').value;
            const fileInput = inner.querySelector('#om-media');
            const file = fileInput.files[0];

            if (type !== 'text' && !file) {
              inner.querySelector('#omMsgError').textContent = 'Please select a media file to upload.';
              return;
            }
            if (type === 'text' && text.length < 1) {
              inner.querySelector('#omMsgError').textContent = 'Message text is required for text messages.';
              return;
            }

            const platformLabels = { both: 'all devices', android: 'Android users', ios: 'iPhone users' };
            const confirmed = await Components.Modal.confirm({
              title: 'Confirm Sending',
              content: `
                <div style="display:flex;flex-direction:column;gap:12px">
                  <div style="background:var(--bg-hover);border-radius:8px;padding:12px 14px;border:1px solid var(--border)">
                    ${type !== 'text' ? `<div style="color:var(--primary);font-size:12px;margin-bottom:4px">[\u{1F4CE} ${type.toUpperCase()}]</div>` : ''}
                    <p style="color:var(--text);font-size:13px;line-height:1.5">${Utils.escapeHtml(text)}</p>
                  </div>
                  <p>This message will be sent as a <strong>chat message from Infexor</strong> to <strong>${platformLabels[selectedPlatform]}</strong>.</p>
                  <p style="color:var(--warning);font-size:12px">\u26a0 This action cannot be undone.</p>
                </div>`,
              confirmLabel: 'Send Now',
              confirmClass: 'btn-primary'
            });
            if (confirmed) {
              await doSend(text, type, file);
              Components.Modal.close(currentModal);
              currentModal = null;
            }
          }
        }
      ],
      onClose: () => { currentModal = null; selectedPlatform = 'both'; }
    });

    // Fill in current profile info in preview
    loadProfileIntoPreview();

    // Platform toggle
    currentModal.querySelectorAll('#omPlatformToggle .platform-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        currentModal.querySelectorAll('#omPlatformToggle .platform-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        selectedPlatform = btn.dataset.platform;
      });
    });

    // Handle media type changing
    const typeSelect = currentModal.querySelector('#om-type');
    const mediaContainer = currentModal.querySelector('#omMediaInputContainer');
    const previewMediaBox = currentModal.querySelector('#omPreviewMediaBox');

    typeSelect.addEventListener('change', (e) => {
      if (e.target.value === 'text') {
        mediaContainer.classList.add('hidden');
        previewMediaBox.style.display = 'none';
      } else {
        mediaContainer.classList.remove('hidden');
        previewMediaBox.style.display = 'flex';
        previewMediaBox.textContent = `[${e.target.value.toUpperCase()} ATTACHMENT]`;
      }
    });

    // Char counter + preview update
    const ta = currentModal.querySelector('#om-message');
    ta.addEventListener('input', () => {
      currentModal.querySelector('#omCharCounter').textContent = `${ta.value.length} / 2000`;
      currentModal.querySelector('#omPreviewContent').textContent = ta.value || 'Your message will appear here\u2026';
      currentModal.querySelector('#omMsgError').textContent = '';
    });
    ta.focus();
  }

  async function loadProfileIntoPreview() {
    try {
      const res = await API.get('/admin/official-profile');
      const { name, avatar } = res.data;
      const nameEl = currentModal && currentModal.querySelector('#omPreviewName');
      if (nameEl) nameEl.textContent = name || 'Infexor';
      if (avatar) {
        const fullUrl = avatar.startsWith('/') ? `${window.location.origin}${avatar}` : avatar;
        const img = currentModal && currentModal.querySelector('#omPreviewAvatarImg');
        const init = currentModal && currentModal.querySelector('#omPreviewInitial');
        if (img) { img.src = fullUrl; img.style.display = 'block'; }
        if (init) init.style.display = 'none';
      }
    } catch (_) { }
  }

  async function doSend(messageText, type, file) {
    try {
      const formData = new FormData();
      formData.append('message', messageText);
      formData.append('type', type);
      formData.append('platform', selectedPlatform);
      if (file) {
        formData.append('media', file);
      }

      const token = API.getToken();
      const response = await fetch(`${window.location.origin}/api/admin/official-messages`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: formData,
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.message || 'Failed to send message');

      Components.Toast.success(`Message sent to ${Utils.formatNumber(data.data.recipientCount || 0)} users`);
      refresh();
    } catch (error) {
      console.error('Failed to send official message:', error);
      Components.Toast.error(error.message || 'Failed to send message');
    }
  }

  // ─── stat & delete actions ───────────────────────────────────────────────
  async function viewStats(id) {
    try {
      const res = await API.get(`/admin/official-messages/${id}/stats`);
      const stats = res.data.stats || [];

      const tableHtml = `
          <div style="max-height:400px;overflow-y:auto;border:1px solid var(--border);border-radius:6px">
            <table class="table" style="margin:0">
               <thead>
                  <tr>
                     <th>Recipient</th>
                     <th>Status</th>
                     <th>Updated At</th>
                  </tr>
               </thead>
               <tbody>
                  ${stats.map(s => {
        let statusColor = 'var(--text-dim)';
        if (s.status === 'delivered') statusColor = 'var(--primary)';
        if (s.status === 'read' || s.status === 'seen') statusColor = 'var(--success)';
        return `
                        <tr>
                           <td>
                              <div style="font-weight:500">${Utils.escapeHtml(s.recipientName)}</div>
                              <div style="font-size:12px;color:var(--text-muted)">${Utils.escapeHtml(s.recipientPhone)}</div>
                           </td>
                           <td><span style="color:${statusColor};font-weight:600;text-transform:capitalize">${s.status || 'Sent'}</span></td>
                           <td style="font-size:12px;color:var(--text-dim)">${Utils.formatDateTime(s.readAt || s.deliveredAt || new Date())}</td>
                        </tr>
                     `;
      }).join('')}
                  ${stats.length === 0 ? '<tr><td colspan="3" style="text-align:center;padding:20px 0;color:var(--text-muted)">No recipients found</td></tr>' : ''}
               </tbody>
            </table>
          </div>
        `;

      Components.Modal.open({
        title: 'Message Delivery Stats',
        size: 'large',
        content: `
             <p style="margin-bottom:16px;color:var(--text-muted)">Detailed tracking of who has received and read this official broadcast.</p>
             ${tableHtml}
           `,
        buttons: [
          { label: 'Close', className: 'btn-primary', onClick: () => Components.Modal.close() }
        ]
      });
    } catch (err) {
      Components.Toast.error(err.message || 'Failed to fetch stats');
    }
  }

  async function deleteMessage(id) {
    const confirmed = await Components.Modal.confirm({
      title: 'Delete for Everyone',
      content: '<p>Are you sure you want to revoke this message?</p><p style="color:var(--warning);font-size:13px">\u26a0 This will instantly remove the message from every recipient\'s chat device.</p>',
      confirmLabel: 'Delete for Everyone',
      confirmClass: 'btn-primary'
    });

    if (confirmed) {
      try {
        await API.del(`/admin/official-messages/${id}`);
        Components.Toast.success('Message revoked successfully');
        refresh();
      } catch (err) {
        Components.Toast.error(err.message || 'Failed to delete message');
      }
    }
  }

  // ─── lifecycle ────────────────────────────────────────────────────────────
  function refresh() {
    if (currentTable) Components.Table.refresh(currentTable);
    loadProfile();
  }

  function destroy() {
    if (currentModal) { Components.Modal.close(currentModal); currentModal = null; }
    pendingAvatarFile = null;
    currentTable = null;
  }

  return { init, refresh, destroy, composeMessage, viewStats, deleteMessage };
})();
