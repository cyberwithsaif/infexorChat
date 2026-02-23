/**
 * Infexor Chat Admin - Reusable UI Components
 * Component builders for Table, Modal, Form, Toast, and Chart
 */

const Components = (() => {
  // ========================================
  // TABLE COMPONENT
  // ========================================
  const Table = {
    /**
     * Create a table with pagination, search, and filters
     * @param {Object} config - Table configuration
     * @param {Array} config.columns - Column definitions
     * @param {Function} config.dataSource - Async function to fetch data
     * @param {Boolean} config.searchable - Enable search
     * @param {String} config.searchPlaceholder - Search input placeholder
     * @param {Boolean} config.filterable - Enable filters
     * @param {Array} config.filters - Filter definitions
     * @param {Function} config.onRowClick - Row click handler
     * @returns {HTMLElement} Table container element
     */
    create(config) {
      const {
        columns,
        dataSource,
        searchable = false,
        searchPlaceholder = 'Search...',
        filterable = false,
        filters = [],
        onRowClick = null
      } = config;

      const wrapper = document.createElement('div');
      wrapper.className = 'table-wrapper';

      // Header with search and filters
      if (searchable || filterable) {
        const header = this._createHeader(config);
        wrapper.appendChild(header);
      }

      // Table element
      const tableContainer = document.createElement('div');
      tableContainer.className = 'table-scroll';

      const table = document.createElement('table');
      table.className = 'data-table';

      // Table header
      const thead = document.createElement('thead');
      const headerRow = document.createElement('tr');
      columns.forEach(col => {
        const th = document.createElement('th');
        th.textContent = col.label;
        if (col.width) th.style.width = col.width;
        headerRow.appendChild(th);
      });
      thead.appendChild(headerRow);
      table.appendChild(thead);

      // Table body
      const tbody = document.createElement('tbody');
      table.appendChild(tbody);

      tableContainer.appendChild(table);
      wrapper.appendChild(tableContainer);

      // Pagination
      const pagination = this._createPagination();
      wrapper.appendChild(pagination);

      // Store config and state
      wrapper._tableConfig = config;
      wrapper._tableState = {
        page: 1,
        limit: 20,
        search: '',
        filters: {},
        data: null
      };

      // Attach event handlers
      this._attachHandlers(wrapper);

      // Initial load
      this.loadData(wrapper);

      return wrapper;
    },

    _createHeader(config) {
      const header = document.createElement('div');
      header.className = 'table-header';

      const leftSection = document.createElement('div');
      leftSection.className = 'table-header-left';

      // Search input
      if (config.searchable) {
        const searchWrapper = document.createElement('div');
        searchWrapper.className = 'search-bar';

        const searchInput = document.createElement('input');
        searchInput.type = 'text';
        searchInput.placeholder = config.searchPlaceholder || 'Search...';
        searchInput.className = 'search-input';
        searchInput.setAttribute('data-search', 'true');

        const searchIcon = document.createElement('span');
        searchIcon.className = 'search-icon';
        searchIcon.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
        </svg>`;

        searchWrapper.appendChild(searchIcon);
        searchWrapper.appendChild(searchInput);
        leftSection.appendChild(searchWrapper);
      }

      // Filters
      if (config.filterable && config.filters) {
        config.filters.forEach(filter => {
          const filterWrapper = document.createElement('div');
          filterWrapper.className = 'filter-group';

          const label = document.createElement('label');
          label.textContent = filter.label;
          label.className = 'filter-label';

          const select = document.createElement('select');
          select.className = 'filter-select';
          select.setAttribute('data-filter', filter.key);

          filter.options.forEach(option => {
            const opt = document.createElement('option');
            opt.value = option.value;
            opt.textContent = option.label;
            select.appendChild(opt);
          });

          filterWrapper.appendChild(label);
          filterWrapper.appendChild(select);
          leftSection.appendChild(filterWrapper);
        });
      }

      header.appendChild(leftSection);

      // Right section for action buttons
      const rightSection = document.createElement('div');
      rightSection.className = 'table-header-right';
      header.appendChild(rightSection);

      return header;
    },

    _createPagination() {
      const pagination = document.createElement('div');
      pagination.className = 'pagination';
      pagination.innerHTML = `
        <div class="pagination-info"></div>
        <div class="pagination-controls">
          <button class="pagination-btn" data-action="prev" disabled>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="15 18 9 12 15 6"/>
            </svg>
            Previous
          </button>
          <div class="pagination-pages"></div>
          <button class="pagination-btn" data-action="next" disabled>
            Next
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="9 18 15 12 9 6"/>
            </svg>
          </button>
        </div>
      `;
      return pagination;
    },

    _attachHandlers(wrapper) {
      // Search input with debounce
      const searchInput = wrapper.querySelector('[data-search]');
      if (searchInput) {
        let searchTimeout;
        searchInput.addEventListener('input', (e) => {
          clearTimeout(searchTimeout);
          searchTimeout = setTimeout(() => {
            wrapper._tableState.search = e.target.value;
            wrapper._tableState.page = 1;
            this.loadData(wrapper);
          }, 300);
        });
      }

      // Filter selects
      const filters = wrapper.querySelectorAll('[data-filter]');
      filters.forEach(select => {
        select.addEventListener('change', (e) => {
          wrapper._tableState.filters[e.target.dataset.filter] = e.target.value;
          wrapper._tableState.page = 1;
          this.loadData(wrapper);
        });
      });

      // Pagination buttons
      const prevBtn = wrapper.querySelector('[data-action="prev"]');
      const nextBtn = wrapper.querySelector('[data-action="next"]');

      if (prevBtn) {
        prevBtn.addEventListener('click', () => {
          if (wrapper._tableState.page > 1) {
            wrapper._tableState.page--;
            this.loadData(wrapper);
          }
        });
      }

      if (nextBtn) {
        nextBtn.addEventListener('click', () => {
          const totalPages = wrapper._tableState.data?.pagination?.totalPages || 1;
          if (wrapper._tableState.page < totalPages) {
            wrapper._tableState.page++;
            this.loadData(wrapper);
          }
        });
      }
    },

    async loadData(wrapper) {
      const { dataSource } = wrapper._tableConfig;
      const state = wrapper._tableState;

      this.showLoader(wrapper);

      try {
        const data = await dataSource(state);
        wrapper._tableState.data = data;
        this.updateData(wrapper, data);
      } catch (error) {
        console.error('Table data load error:', error);
        this.showError(wrapper, error.message || 'Failed to load data');
      }
    },

    updateData(wrapper, data) {
      const tbody = wrapper.querySelector('tbody');
      const { columns, onRowClick } = wrapper._tableConfig;

      tbody.innerHTML = '';

      if (!data.items || data.items.length === 0) {
        const emptyRow = document.createElement('tr');
        emptyRow.innerHTML = `<td colspan="${columns.length}" class="empty-state">
          <div class="empty-state-content">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
            </svg>
            <p>No data found</p>
          </div>
        </td>`;
        tbody.appendChild(emptyRow);
        this._updatePagination(wrapper, { page: 1, totalPages: 1, total: 0 });
        return;
      }

      data.items.forEach((item, index) => {
        const row = document.createElement('tr');
        row.className = 'table-row';

        columns.forEach(col => {
          const td = document.createElement('td');
          if (col.render) {
            td.innerHTML = col.render(item);
          } else {
            td.textContent = item[col.key] || '-';
          }
          row.appendChild(td);
        });

        if (onRowClick) {
          row.style.cursor = 'pointer';
          row.addEventListener('click', () => onRowClick(item));
        }

        tbody.appendChild(row);

        // Fade in animation with stagger
        setTimeout(() => row.classList.add('visible'), index * 50);
      });

      this._updatePagination(wrapper, data.pagination);
    },

    _updatePagination(wrapper, pagination) {
      const { page = 1, totalPages = 1, total = 0, limit = 20 } = pagination;

      const paginationInfo = wrapper.querySelector('.pagination-info');
      const start = (page - 1) * limit + 1;
      const end = Math.min(page * limit, total);
      paginationInfo.textContent = `Showing ${start}-${end} of ${total}`;

      const prevBtn = wrapper.querySelector('[data-action="prev"]');
      const nextBtn = wrapper.querySelector('[data-action="next"]');

      prevBtn.disabled = page <= 1;
      nextBtn.disabled = page >= totalPages;

      // Page numbers
      const pagesContainer = wrapper.querySelector('.pagination-pages');
      pagesContainer.innerHTML = '';

      const maxVisible = 5;
      let startPage = Math.max(1, page - Math.floor(maxVisible / 2));
      let endPage = Math.min(totalPages, startPage + maxVisible - 1);

      if (endPage - startPage + 1 < maxVisible) {
        startPage = Math.max(1, endPage - maxVisible + 1);
      }

      for (let i = startPage; i <= endPage; i++) {
        const pageBtn = document.createElement('button');
        pageBtn.className = 'pagination-page';
        if (i === page) pageBtn.classList.add('active');
        pageBtn.textContent = i;
        pageBtn.addEventListener('click', () => {
          wrapper._tableState.page = i;
          this.loadData(wrapper);
        });
        pagesContainer.appendChild(pageBtn);
      }
    },

    showLoader(wrapper) {
      const tbody = wrapper.querySelector('tbody');
      const columns = wrapper._tableConfig.columns;
      tbody.innerHTML = `
        <tr>
          <td colspan="${columns.length}">
            <div class="loader">
              <div class="spinner"></div>
            </div>
          </td>
        </tr>
      `;
    },

    showError(wrapper, message) {
      const tbody = wrapper.querySelector('tbody');
      const columns = wrapper._tableConfig.columns;
      tbody.innerHTML = `
        <tr>
          <td colspan="${columns.length}" class="error-state">
            <div class="error-state-content">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>
              </svg>
              <p>${Utils.escapeHtml(message)}</p>
              <button class="btn btn-secondary btn-sm" onclick="this.closest('.table-wrapper')._retry()">
                Retry
              </button>
            </div>
          </td>
        </tr>
      `;

      wrapper._retry = () => this.loadData(wrapper);
    },

    refresh(wrapper) {
      this.loadData(wrapper);
    }
  };

  // ========================================
  // MODAL COMPONENT
  // ========================================
  const Modal = {
    /**
     * Open a modal
     * @param {Object} config - Modal configuration
     * @param {String} config.title - Modal title
     * @param {String} config.content - Modal HTML content
     * @param {Array} config.buttons - Button configurations
     * @param {String} config.size - Modal size: 'small', 'medium', 'large'
     * @returns {HTMLElement} Modal element
     */
    open(config) {
      const {
        title,
        content,
        buttons = [],
        size = 'medium',
        onClose = null
      } = config;

      // Create backdrop
      const backdrop = document.createElement('div');
      backdrop.className = 'modal-backdrop';

      // Create modal container
      const modal = document.createElement('div');
      modal.className = `modal-container modal-${size}`;

      // Modal header
      const header = document.createElement('div');
      header.className = 'modal-header';

      const titleEl = document.createElement('h3');
      titleEl.textContent = title;

      const closeBtn = document.createElement('button');
      closeBtn.className = 'modal-close';
      closeBtn.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
      </svg>`;
      closeBtn.onclick = () => {
        if (onClose) onClose();
        this.close(backdrop);
      };

      header.appendChild(titleEl);
      header.appendChild(closeBtn);

      // Modal body
      const body = document.createElement('div');
      body.className = 'modal-body';
      body.innerHTML = content;

      // Modal footer
      const footer = document.createElement('div');
      footer.className = 'modal-footer';

      buttons.forEach(btn => {
        const button = document.createElement('button');
        button.className = `btn ${btn.className || 'btn-primary'}`;
        button.textContent = btn.label;
        button.onclick = () => {
          if (btn.onClick) btn.onClick(modal);
        };
        footer.appendChild(button);
      });

      modal.appendChild(header);
      modal.appendChild(body);
      if (buttons.length > 0) modal.appendChild(footer);

      backdrop.appendChild(modal);
      document.body.appendChild(backdrop);

      // Animations
      requestAnimationFrame(() => {
        backdrop.classList.add('visible');
        modal.classList.add('visible');
      });

      // Close on backdrop click
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          if (onClose) onClose();
          this.close(backdrop);
        }
      });

      // Close on Escape key
      const escapeHandler = (e) => {
        if (e.key === 'Escape') {
          if (onClose) onClose();
          this.close(backdrop);
          document.removeEventListener('keydown', escapeHandler);
        }
      };
      document.addEventListener('keydown', escapeHandler);

      backdrop._escapeHandler = escapeHandler;

      return backdrop;
    },

    close(backdrop) {
      const modal = backdrop.querySelector('.modal-container');

      backdrop.classList.remove('visible');
      modal.classList.remove('visible');

      setTimeout(() => {
        if (backdrop._escapeHandler) {
          document.removeEventListener('keydown', backdrop._escapeHandler);
        }
        backdrop.remove();
      }, 300);
    },

    /**
     * Open a confirmation dialog
     * @param {Object} config - Confirmation configuration
     * @returns {Promise<Boolean>} Resolves to true if confirmed, false if cancelled
     */
    confirm(config) {
      return new Promise((resolve) => {
        const {
          title = 'Confirm',
          content = 'Are you sure?',
          confirmLabel = 'Confirm',
          cancelLabel = 'Cancel',
          confirmClass = 'btn-danger',
          onConfirm = null
        } = config;

        const backdrop = this.open({
          title,
          content,
          size: 'small',
          buttons: [
            {
              label: cancelLabel,
              className: 'btn-ghost',
              onClick: () => {
                this.close(backdrop);
                resolve(false);
              }
            },
            {
              label: confirmLabel,
              className: confirmClass,
              onClick: async (modal) => {
                try {
                  let result = true;
                  if (onConfirm) {
                    result = await onConfirm(modal);
                  }
                  this.close(backdrop);
                  resolve(result);
                } catch (error) {
                  console.error('Confirmation error:', error);
                  resolve(false);
                }
              }
            }
          ]
        });
      });
    }
  };

  // ========================================
  // FORM COMPONENT
  // ========================================
  const Form = {
    /**
     * Create a form
     * @param {Object} config - Form configuration
     * @param {Array} config.fields - Field definitions
     * @param {Function} config.onSubmit - Submit handler
     * @returns {HTMLElement} Form element
     */
    create(config) {
      const { fields = [], onSubmit = null } = config;

      const form = document.createElement('form');
      form.className = 'form';

      fields.forEach(field => {
        const fieldWrapper = this._createField(field);
        form.appendChild(fieldWrapper);
      });

      if (onSubmit) {
        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          if (this.validate(form)) {
            const data = this.getData(form);
            await onSubmit(data);
          }
        });
      }

      return form;
    },

    _createField(field) {
      const wrapper = document.createElement('div');
      wrapper.className = 'form-group';

      const label = document.createElement('label');
      label.textContent = field.label;
      if (field.required) {
        label.innerHTML += ' <span class="required">*</span>';
      }
      wrapper.appendChild(label);

      let input;

      switch (field.type) {
        case 'textarea':
          input = document.createElement('textarea');
          input.rows = field.rows || 4;
          if (field.maxLength) {
            input.maxLength = field.maxLength;
            const counter = document.createElement('div');
            counter.className = 'char-counter';
            counter.textContent = `0 / ${field.maxLength}`;
            input.addEventListener('input', () => {
              counter.textContent = `${input.value.length} / ${field.maxLength}`;
            });
            wrapper.appendChild(counter);
          }
          break;

        case 'select':
          input = document.createElement('select');
          field.options.forEach(opt => {
            const option = document.createElement('option');
            option.value = opt.value;
            option.textContent = opt.label;
            input.appendChild(option);
          });
          break;

        case 'radio':
          const radioGroup = document.createElement('div');
          radioGroup.className = 'radio-group';
          field.options.forEach(opt => {
            const radioLabel = document.createElement('label');
            radioLabel.className = 'radio-label';

            const radio = document.createElement('input');
            radio.type = 'radio';
            radio.name = field.name;
            radio.value = opt.value;
            if (opt.checked) radio.checked = true;

            radioLabel.appendChild(radio);
            radioLabel.appendChild(document.createTextNode(opt.label));
            radioGroup.appendChild(radioLabel);
          });
          wrapper.appendChild(radioGroup);
          return wrapper;

        case 'checkbox':
          input = document.createElement('input');
          input.type = 'checkbox';
          wrapper.classList.add('form-group-checkbox');
          break;

        default:
          input = document.createElement('input');
          input.type = field.type || 'text';
      }

      input.name = field.name;
      input.className = 'form-control';
      if (field.placeholder) input.placeholder = field.placeholder;
      if (field.required) input.required = true;
      if (field.value) input.value = field.value;
      if (field.min) input.min = field.min;
      if (field.max) input.max = field.max;

      wrapper.appendChild(input);

      if (field.help) {
        const helpText = document.createElement('div');
        helpText.className = 'form-help';
        helpText.textContent = field.help;
        wrapper.appendChild(helpText);
      }

      // Error message container
      const errorMsg = document.createElement('div');
      errorMsg.className = 'form-error';
      wrapper.appendChild(errorMsg);

      return wrapper;
    },

    validate(form) {
      let isValid = true;
      const inputs = form.querySelectorAll('.form-control, input[type="radio"]');

      inputs.forEach(input => {
        const wrapper = input.closest('.form-group');
        const errorMsg = wrapper?.querySelector('.form-error');

        if (errorMsg) errorMsg.textContent = '';
        wrapper?.classList.remove('has-error');

        if (input.required && !input.value) {
          if (errorMsg) errorMsg.textContent = 'This field is required';
          wrapper?.classList.add('has-error');
          isValid = false;
        }

        if (input.min && input.value && input.value.length < parseInt(input.min)) {
          if (errorMsg) errorMsg.textContent = `Minimum ${input.min} characters required`;
          wrapper?.classList.add('has-error');
          isValid = false;
        }
      });

      return isValid;
    },

    getData(form) {
      const data = {};
      const inputs = form.querySelectorAll('.form-control, input[type="radio"]:checked, input[type="checkbox"]');

      inputs.forEach(input => {
        if (input.type === 'checkbox') {
          data[input.name] = input.checked;
        } else {
          data[input.name] = input.value;
        }
      });

      return data;
    },

    reset(form) {
      form.reset();
      form.querySelectorAll('.form-error').forEach(el => el.textContent = '');
      form.querySelectorAll('.has-error').forEach(el => el.classList.remove('has-error'));
      form.querySelectorAll('.char-counter').forEach(el => {
        const match = el.textContent.match(/\d+ \/ (\d+)/);
        if (match) el.textContent = `0 / ${match[1]}`;
      });
    }
  };

  // ========================================
  // TOAST NOTIFICATION
  // ========================================
  const Toast = {
    _container: null,
    _toasts: [],

    _getContainer() {
      if (!this._container) {
        this._container = document.createElement('div');
        this._container.className = 'toast-container';
        document.body.appendChild(this._container);
      }
      return this._container;
    },

    _show(message, type) {
      const container = this._getContainer();

      // Remove oldest toast if we have 3
      if (this._toasts.length >= 3) {
        const oldest = this._toasts.shift();
        oldest.classList.remove('visible');
        setTimeout(() => oldest.remove(), 300);
      }

      const toast = document.createElement('div');
      toast.className = `toast toast-${type}`;

      const icon = this._getIcon(type);
      const iconEl = document.createElement('span');
      iconEl.className = 'toast-icon';
      iconEl.innerHTML = icon;

      const messageEl = document.createElement('span');
      messageEl.className = 'toast-message';
      messageEl.textContent = message;

      const closeBtn = document.createElement('button');
      closeBtn.className = 'toast-close';
      closeBtn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
      </svg>`;
      closeBtn.onclick = () => this._remove(toast);

      toast.appendChild(iconEl);
      toast.appendChild(messageEl);
      toast.appendChild(closeBtn);

      container.appendChild(toast);
      this._toasts.push(toast);

      requestAnimationFrame(() => toast.classList.add('visible'));

      setTimeout(() => this._remove(toast), 3000);
    },

    _remove(toast) {
      toast.classList.remove('visible');
      setTimeout(() => {
        toast.remove();
        this._toasts = this._toasts.filter(t => t !== toast);
      }, 300);
    },

    _getIcon(type) {
      const icons = {
        success: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="20 6 9 17 4 12"/>
        </svg>`,
        error: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>
        </svg>`,
        warning: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
          <line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
        </svg>`,
        info: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>
        </svg>`
      };
      return icons[type] || icons.info;
    },

    success(message) {
      this._show(message, 'success');
    },

    error(message) {
      this._show(message, 'error');
    },

    warning(message) {
      this._show(message, 'warning');
    },

    info(message) {
      this._show(message, 'info');
    }
  };

  // ========================================
  // CHART WRAPPER (Placeholder for Chart.js integration)
  // ========================================
  const Chart = {
    /**
     * Create a line chart
     * @param {String} canvasId - Canvas element ID
     * @param {Object} data - Chart data
     * @param {Object} options - Chart options
     * @returns {Object} Chart instance
     */
    line(canvasId, data, options = {}) {
      // This will be fully implemented when Chart.js is loaded
      console.log('Chart.line called for', canvasId);
      return null;
    },

    /**
     * Create a doughnut chart
     * @param {String} canvasId - Canvas element ID
     * @param {Object} data - Chart data
     * @param {Object} options - Chart options
     * @returns {Object} Chart instance
     */
    doughnut(canvasId, data, options = {}) {
      // This will be fully implemented when Chart.js is loaded
      console.log('Chart.doughnut called for', canvasId);
      return null;
    },

    update(chart, newData) {
      if (chart && chart.data) {
        chart.data = newData;
        chart.update();
      }
    },

    destroy(chart) {
      if (chart && chart.destroy) {
        chart.destroy();
      }
    }
  };

  // Public API
  return {
    Table,
    Modal,
    Form,
    Toast,
    Chart
  };
})();
