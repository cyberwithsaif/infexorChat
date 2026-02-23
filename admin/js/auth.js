/**
 * Infexor Chat Admin - Authentication
 */
document.addEventListener('DOMContentLoaded', () => {
  // If already authenticated, redirect to dashboard
  if (API.isAuthenticated()) {
    window.location.href = 'dashboard.html';
    return;
  }

  const form = document.getElementById('loginForm');
  const errorEl = document.getElementById('loginError');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';

    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;

    if (!username || !password) {
      errorEl.textContent = 'Please fill in all fields';
      errorEl.style.display = 'block';
      return;
    }

    try {
      const data = await API.post('/admin/auth/login', { username, password });

      if (data && data.data && data.data.token) {
        API.setToken(data.data.token);
        window.location.href = 'dashboard.html';
      } else {
        errorEl.textContent = 'Invalid response from server';
        errorEl.style.display = 'block';
      }
    } catch (error) {
      errorEl.textContent = error.message || 'Login failed';
      errorEl.style.display = 'block';
    }
  });
});
