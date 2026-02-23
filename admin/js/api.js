/**
 * Infexor Chat Admin - API Utility
 * Fetch wrapper with JWT authentication
 */
const API = (() => {
  const BASE_URL = '/api';

  function getToken() {
    return localStorage.getItem('admin_token');
  }

  function setToken(token) {
    localStorage.setItem('admin_token', token);
  }

  function clearToken() {
    localStorage.removeItem('admin_token');
  }

  function isAuthenticated() {
    return !!getToken();
  }

  async function request(endpoint, options = {}) {
    const url = `${BASE_URL}${endpoint}`;
    const token = getToken();

    const headers = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    try {
      const response = await fetch(url, {
        ...options,
        headers,
      });

      const data = await response.json();

      if (response.status === 401) {
        clearToken();
        window.location.href = 'index.html';
        return null;
      }

      if (!response.ok) {
        throw new Error(data.message || 'Request failed');
      }

      return data;
    } catch (error) {
      console.error(`API Error [${endpoint}]:`, error.message);
      throw error;
    }
  }

  return {
    BASE_URL,
    getToken,
    setToken,
    clearToken,
    isAuthenticated,

    get(endpoint) {
      return request(endpoint, { method: 'GET' });
    },

    post(endpoint, body) {
      return request(endpoint, {
        method: 'POST',
        body: JSON.stringify(body),
      });
    },

    put(endpoint, body) {
      return request(endpoint, {
        method: 'PUT',
        body: JSON.stringify(body),
      });
    },

    delete(endpoint) {
      return request(endpoint, { method: 'DELETE' });
    },
  };
})();













