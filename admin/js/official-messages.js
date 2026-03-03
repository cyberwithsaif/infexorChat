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
          <button class="btn btn-primary" id="omSendMsgBtn">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22 11 13 2 9l20-7z"/></svg>
            Send Message
          </button>
        </div>
      </div>

      <!-- Profile Card -->
      <div class="card" id="omProfileCard" style="margin-bottom:24px">
        <div class="card-header">
          <h3 class="card-title">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right:6px"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/></svg>
            Official Account Profile
          </h3>
        </div>
        <div style="padding:20px;display:flex;align-items:flex-start;gap:28px;flex-wrap:wrap">

          <!-- Avatar Section -->
          <div style="display:flex;flex-direction:column;align-items:center;gap:12px">
            <div id="omAvatarWrapper" style="position:relative;cursor:pointer" onclick="document.getElementById('omAvatarInput').click()">
              <div id="omAvatarCircle" style="
                width:90px;height:90px;border-radius:50%;
                background:linear-gradient(135deg,var(--primary),var(--primary-dark,#0040cc));
                display:flex;align-items:center;justify-content:center;
                font-size:32px;font-weight:700;color:#fff;
                overflow:hidden;position:relative;border:3px solid var(--border)
              ">
                <span id="omAvatarInitial">I</span>
                <img id="omAvatarImg" src="" alt="Official Avatar" style="display:none;width:100%;height:100%;object-fit:cover;position:absolute;inset:0" />
              </div>
              <div style="
                position:absolute;bottom:0;right:0;
                width:26px;height:26px;border-radius:50%;
                background:var(--primary);border:2px solid var(--bg-card);
                display:flex;align-items:center;justify-content:center
              ">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
              </div>
            </div>
            <input type="file" id="omAvatarInput" accept="image/*" style="display:none" />
            <p style="font-size:11px;color:var(--text-muted);text-align:center">Click to change photo</p>
          </div>

          <!-- Name + Save Section -->
          <div style="flex:1;min-width:220px">
            <div class="form-group" style="margin-bottom:10px">
              <label style="font-size:12px;color:var(--text-muted);margin-bottom:6px;display:block">Display Name</label>
              <input type="text" id="omNameInput" class="form-control" maxlength="50"
                placeholder="e.g. Infexor" style="max-width:320px" />
              <div style="font-size:11px;color:var(--text-dim);margin-top:4px">This name appears on every message sent from this account</div>
            </div>
            <div style="display:flex;gap:10px;align-items:center">
              <button class="btn btn-primary btn-sm" id="omSaveProfileBtn">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
                Save Profile
              </button>
              <span id="omSaveStatus" style="font-size:12px;color:var(--text-muted)"></span>
            </div>
          </div>
        </div>
      </div>

      <!-- Message History -->
      <div class="card">
        <div class="card-header">
          <h3 class="card-title">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right:6px"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            Sent Message History
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
      imgEl.src = avatarUrl;
      imgEl.style.display = 'block';
      initEl.style.display = 'none';
    } else {
      initEl.textContent = (name || 'I')[0].toUpperCase();
      imgEl.style.display = 'none';
      initEl.style.display = 'block';
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
          render: (m) => `
            <div style="max-width:400px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis" title="${Utils.escapeHtml(m.message)}">
              ${Utils.escapeHtml(m.message)}
            </div>`
        },
        {
          key: 'platform',
          label: 'Platform',
          width: '120px',
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
          width: '90px',
          render: (m) => `<span style="font-weight:600;color:var(--success)">${Utils.formatNumber(m.recipientCount || 0)}</span>`
        },
        {
          key: 'failedCount',
          label: 'Failed',
          width: '80px',
          render: (m) => {
            const f = m.failedCount || 0;
            return `<span style="font-weight:600;color:${f > 0 ? 'var(--danger)' : 'var(--text-dim)'}">${f}</span>`;
          }
        },
        {
          key: 'createdAt',
          label: 'Sent At',
          width: '160px',
          render: (m) => `<span style="color:var(--text-muted);font-size:12px">${Utils.formatDateTime(m.createdAt)}</span>`
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
        <form id="omForm" novalidate>
          <div class="form-group">
            <label>Message <span class="required">*</span></label>
            <textarea id="om-message" class="form-control" rows="5"
              placeholder="Type your message\u2026 This appears as a real chat message from the Infexor account." maxlength="2000"></textarea>
            <div class="char-counter" id="omCharCounter">0 / 2000</div>
            <div class="form-error" id="omMsgError"></div>
          </div>

          <div class="form-group">
            <label>Target Platform</label>
            <div class="platform-toggle" id="omPlatformToggle">
              <button type="button" class="platform-btn active" data-platform="both">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
                All Devices
              </button>
              <button type="button" class="platform-btn" data-platform="android">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24A9.88 9.88 0 0 0 12 8c-1.63 0-3.16.39-4.47 1.07L5.65 5.83c-.18-.28-.54-.37-.83-.22-.3.16-.42.54-.26.85l1.84 3.18C3.93 11.06 2.5 13.38 2.5 16h19c0-2.62-1.43-4.94-3.9-6.52M9 13.5a1 1 0 1 1 0-2 1 1 0 0 1 0 2m6 0a1 1 0 1 1 0-2 1 1 0 0 1 0 2"/></svg>
                Android Only
              </button>
              <button type="button" class="platform-btn" data-platform="ios">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11"/></svg>
                iPhone Only
              </button>
            </div>
          </div>

          <!-- Live preview -->
          <div style="background:var(--bg-hover);border-radius:10px;padding:14px;border:1px solid var(--border)">
            <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px">
              <div id="omPreviewAvatar" style="width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg,var(--primary),var(--primary-dark,#0040cc));display:flex;align-items:center;justify-content:center;overflow:hidden;flex-shrink:0">
                <span id="omPreviewInitial" style="color:#fff;font-weight:700;font-size:14px">I</span>
                <img id="omPreviewAvatarImg" src="" style="display:none;width:100%;height:100%;object-fit:cover" />
              </div>
              <div>
                <strong id="omPreviewName" style="color:var(--text)">Infexor</strong>
                <span style="color:var(--primary);font-size:11px;margin-left:4px">\u2713 Official</span>
              </div>
            </div>
            <div style="background:var(--bg-card);border-radius:8px;padding:10px 12px;margin-left:46px;border:1px solid var(--border)">
              <p id="omPreviewContent" style="color:var(--text-muted);font-size:13px;line-height:1.5;margin:0">Your message will appear here\u2026</p>
            </div>
          </div>
        </form>
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
            if (text.length < 3) {
              inner.querySelector('#omMsgError').textContent = 'Message must be at least 3 characters';
              return;
            }
            const platformLabels = { both: 'all devices', android: 'Android users', ios: 'iPhone users' };
            const confirmed = await Components.Modal.confirm({
              title: 'Confirm Sending',
              content: `
                <div style="display:flex;flex-direction:column;gap:12px">
                  <div style="background:var(--bg-hover);border-radius:8px;padding:12px 14px;border:1px solid var(--border)">
                    <p style="color:var(--text);font-size:13px;line-height:1.5">${Utils.escapeHtml(text)}</p>
                  </div>
                  <p>This message will be sent as a <strong>chat message from Infexor</strong> to <strong>${platformLabels[selectedPlatform]}</strong>.</p>
                  <p style="color:var(--warning);font-size:12px">\u26a0 This action cannot be undone.</p>
                </div>`,
              confirmLabel: 'Send Now',
              confirmClass: 'btn-primary'
            });
            if (confirmed) {
              await doSend(text);
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
        const img = currentModal && currentModal.querySelector('#omPreviewAvatarImg');
        const init = currentModal && currentModal.querySelector('#omPreviewInitial');
        if (img) { img.src = avatar; img.style.display = 'block'; }
        if (init) init.style.display = 'none';
      }
    } catch (_) { }
  }

  async function doSend(messageText) {
    try {
      const response = await API.post('/admin/official-messages', {
        message: messageText,
        platform: selectedPlatform
      });
      Components.Toast.success(`Message sent to ${Utils.formatNumber(response.data.recipientCount || 0)} users`);
      refresh();
    } catch (error) {
      console.error('Failed to send official message:', error);
      Components.Toast.error(error.message || 'Failed to send message');
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

  return { init, refresh, destroy, composeMessage };
})();
