/**
 * API Client — handles auth, GET, POST, PUT, DELETE
 */
const API = (() => {
    const BASE_URL = window.location.origin;

    function getToken() { return localStorage.getItem('adminToken'); }
    function setToken(token) { localStorage.setItem('adminToken', token); }
    function clearToken() { localStorage.removeItem('adminToken'); localStorage.removeItem('adminUser'); }
    function isAuthenticated() { return !!getToken(); }

    async function request(method, path, body = null) {
        const opts = {
            method,
            headers: { 'Content-Type': 'application/json' },
        };
        const token = getToken();
        if (token) opts.headers['Authorization'] = `Bearer ${token}`;
        if (body) opts.body = JSON.stringify(body);

        const res = await fetch(`${BASE_URL}/api${path}`, opts);
        const data = await res.json();

        if (res.status === 401) {
            clearToken();
            window.location.href = 'index.html';
            throw new Error('Session expired');
        }
        if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
        return data;
    }

    async function upload(path, file, fieldName = 'file') {
        const formData = new FormData();
        formData.append(fieldName, file);

        const opts = { method: 'POST', body: formData };
        const token = getToken();
        if (token) opts.headers = { 'Authorization': `Bearer ${token}` };

        const res = await fetch(`${BASE_URL}/api${path}`, opts);
        const data = await res.json();

        if (res.status === 401) {
            clearToken();
            window.location.href = 'index.html';
            throw new Error('Session expired');
        }
        if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
        return data;
    }

    return {
        get: (path) => request('GET', path),
        post: (path, body) => request('POST', path, body),
        put: (path, body) => request('PUT', path, body),
        del: (path, body) => request('DELETE', path, body),
        upload,
        getToken, setToken, clearToken, isAuthenticated,
    };
})();
