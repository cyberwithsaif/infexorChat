/**
 * Infexor Chat Admin - Chart Configuration
 * Chart.js wrapper with glassmorphism theme
 */

const ChartConfig = (() => {
  // Color palette matching CSS variables
  const colors = {
    primary: '#6366f1',
    secondary: '#a855f7',
    success: '#10b981',
    danger: '#ef4444',
    warning: '#f59e0b',
    info: '#3b82f6',
    purple: '#a855f7',
    blue: '#6366f1',
    text: 'rgba(255, 255, 255, 0.9)',
    textMuted: 'rgba(255, 255, 255, 0.5)',
    gridLines: 'rgba(255, 255, 255, 0.1)',
    backdrop: 'rgba(15, 23, 42, 0.8)'
  };

  // Default chart options with glassmorphism styling
  const defaultOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: true,
        position: 'bottom',
        labels: {
          color: colors.text,
          font: {
            family: "'Inter', sans-serif",
            size: 12
          },
          padding: 15,
          usePointStyle: true,
          pointStyle: 'circle'
        }
      },
      tooltip: {
        backgroundColor: colors.backdrop,
        titleColor: colors.text,
        bodyColor: colors.text,
        borderColor: 'rgba(255, 255, 255, 0.1)',
        borderWidth: 1,
        padding: 12,
        cornerRadius: 8,
        displayColors: true,
        titleFont: {
          size: 13,
          weight: 'bold'
        },
        bodyFont: {
          size: 12
        },
        callbacks: {
          label: function(context) {
            let label = context.dataset.label || '';
            if (label) {
              label += ': ';
            }
            if (context.parsed.y !== null) {
              label += Utils.formatNumber(context.parsed.y);
            }
            return label;
          }
        }
      }
    },
    interaction: {
      mode: 'index',
      intersect: false
    }
  };

  /**
   * Create a line chart
   * @param {String} canvasId - Canvas element ID
   * @param {Object} data - Chart data
   * @param {Object} customOptions - Custom options to merge
   * @returns {Chart} Chart instance
   */
  function createLineChart(canvasId, data, customOptions = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
      console.error(`Canvas element with ID "${canvasId}" not found`);
      return null;
    }

    const ctx = canvas.getContext('2d');

    const options = {
      ...defaultOptions,
      scales: {
        y: {
          beginAtZero: true,
          grid: {
            color: colors.gridLines,
            borderColor: 'rgba(255, 255, 255, 0.1)'
          },
          ticks: {
            color: colors.textMuted,
            font: {
              size: 11
            },
            callback: function(value) {
              return Utils.formatNumber(value);
            }
          }
        },
        x: {
          grid: {
            color: 'rgba(255, 255, 255, 0.05)',
            borderColor: 'rgba(255, 255, 255, 0.1)'
          },
          ticks: {
            color: colors.textMuted,
            font: {
              size: 11
            }
          }
        }
      },
      ...customOptions
    };

    // Apply gradient if not already applied
    if (data.datasets) {
      data.datasets = data.datasets.map(dataset => {
        if (!dataset.backgroundColor || typeof dataset.backgroundColor === 'string') {
          const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
          const color = dataset.borderColor || colors.primary;
          gradient.addColorStop(0, color.replace(')', ', 0.2)').replace('rgb', 'rgba'));
          gradient.addColorStop(1, color.replace(')', ', 0)').replace('rgb', 'rgba'));
          dataset.backgroundColor = gradient;
        }
        return {
          fill: true,
          tension: 0.4,
          borderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: '#fff',
          pointBorderWidth: 2,
          ...dataset
        };
      });
    }

    return new Chart(ctx, {
      type: 'line',
      data,
      options
    });
  }

  /**
   * Create a doughnut chart
   * @param {String} canvasId - Canvas element ID
   * @param {Object} data - Chart data
   * @param {Object} customOptions - Custom options to merge
   * @returns {Chart} Chart instance
   */
  function createDoughnutChart(canvasId, data, customOptions = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
      console.error(`Canvas element with ID "${canvasId}" not found`);
      return null;
    }

    const ctx = canvas.getContext('2d');

    const options = {
      ...defaultOptions,
      cutout: '70%',
      plugins: {
        ...defaultOptions.plugins,
        tooltip: {
          ...defaultOptions.plugins.tooltip,
          callbacks: {
            label: function(context) {
              const label = context.label || '';
              const value = context.parsed || 0;
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = ((value / total) * 100).toFixed(1);
              return `${label}: ${Utils.formatNumber(value)} (${percentage}%)`;
            }
          }
        }
      },
      ...customOptions
    };

    // Apply default colors if not provided
    if (data.datasets && data.datasets[0] && !data.datasets[0].backgroundColor) {
      data.datasets[0].backgroundColor = [
        colors.success,
        colors.warning,
        colors.danger,
        colors.info,
        colors.secondary
      ];
      data.datasets[0].borderWidth = 2;
      data.datasets[0].borderColor = 'rgba(15, 23, 42, 0.8)';
    }

    return new Chart(ctx, {
      type: 'doughnut',
      data,
      options
    });
  }

  /**
   * Create a bar chart
   * @param {String} canvasId - Canvas element ID
   * @param {Object} data - Chart data
   * @param {Object} customOptions - Custom options to merge
   * @returns {Chart} Chart instance
   */
  function createBarChart(canvasId, data, customOptions = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
      console.error(`Canvas element with ID "${canvasId}" not found`);
      return null;
    }

    const ctx = canvas.getContext('2d');

    const options = {
      ...defaultOptions,
      scales: {
        y: {
          beginAtZero: true,
          grid: {
            color: colors.gridLines,
            borderColor: 'rgba(255, 255, 255, 0.1)'
          },
          ticks: {
            color: colors.textMuted,
            font: {
              size: 11
            }
          }
        },
        x: {
          grid: {
            display: false,
            borderColor: 'rgba(255, 255, 255, 0.1)'
          },
          ticks: {
            color: colors.textMuted,
            font: {
              size: 11
            }
          }
        }
      },
      ...customOptions
    };

    // Apply default styling to datasets
    if (data.datasets) {
      data.datasets = data.datasets.map(dataset => ({
        backgroundColor: colors.primary,
        borderColor: colors.primary,
        borderWidth: 0,
        borderRadius: 6,
        ...dataset
      }));
    }

    return new Chart(ctx, {
      type: 'bar',
      data,
      options
    });
  }

  /**
   * Update chart data
   * @param {Chart} chart - Chart instance
   * @param {Object} newData - New chart data
   */
  function updateChart(chart, newData) {
    if (!chart) return;

    if (newData.labels) {
      chart.data.labels = newData.labels;
    }

    if (newData.datasets) {
      chart.data.datasets = newData.datasets;
    }

    chart.update('none'); // Update without animation for smoother updates
  }

  /**
   * Destroy chart instance
   * @param {Chart} chart - Chart instance to destroy
   */
  function destroyChart(chart) {
    if (chart && typeof chart.destroy === 'function') {
      chart.destroy();
    }
  }

  /**
   * Format date for chart labels
   * @param {String} dateStr - Date string
   * @returns {String} Formatted date
   */
  function formatChartDate(dateStr) {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  /**
   * Generate gradient for chart background
   * @param {CanvasRenderingContext2D} ctx - Canvas context
   * @param {String} color - Base color
   * @param {Number} height - Canvas height
   * @returns {CanvasGradient} Gradient
   */
  function createGradient(ctx, color, height) {
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, color.replace(')', ', 0.2)').replace('rgb', 'rgba'));
    gradient.addColorStop(1, color.replace(')', ', 0)').replace('rgb', 'rgba'));
    return gradient;
  }

  // Override Chart.js components with new implementations
  // This updates the Components.Chart methods to use these functions
  if (typeof Components !== 'undefined' && Components.Chart) {
    Components.Chart.line = createLineChart;
    Components.Chart.doughnut = createDoughnutChart;
    Components.Chart.bar = createBarChart;
    Components.Chart.update = updateChart;
    Components.Chart.destroy = destroyChart;
  }

  // Public API
  return {
    colors,
    defaultOptions,
    createLineChart,
    createDoughnutChart,
    createBarChart,
    updateChart,
    destroyChart,
    formatChartDate,
    createGradient
  };
})();
