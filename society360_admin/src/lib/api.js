import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || '/v1';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Helper to clear all auth data
const clearAuthData = () => {
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('user');
  localStorage.removeItem('auth-storage'); // Clear Zustand persisted state
};

// Response interceptor to handle token refresh
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // If 401 and not already retrying
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      // Check if token expired - try to refresh
      if (error.response?.data?.code === 'TOKEN_EXPIRED') {
        try {
          const refreshToken = localStorage.getItem('refreshToken');
          if (!refreshToken) {
            throw new Error('No refresh token');
          }

          const response = await axios.post(`${API_BASE_URL}/admin/auth/refresh`, {
            refreshToken,
          });

          const { accessToken } = response.data.data;
          localStorage.setItem('accessToken', accessToken);

          // Retry original request
          originalRequest.headers.Authorization = `Bearer ${accessToken}`;
          return api(originalRequest);
        } catch (refreshError) {
          // Clear all auth data and redirect to login
          clearAuthData();
          window.location.href = '/login';
          return Promise.reject(refreshError);
        }
      }

      // Other 401 errors - clear auth and redirect to login
      clearAuthData();
      window.location.href = '/login';
    }

    return Promise.reject(error);
  }
);

// Auth API
export const authApi = {
  login: (email, password) =>
    api.post('/admin/auth/login', { email, password }),

  logout: (refreshToken) =>
    api.post('/admin/auth/logout', { refreshToken }),

  refreshToken: (refreshToken) =>
    api.post('/admin/auth/refresh', { refreshToken }),

  getProfile: () =>
    api.get('/admin/auth/me'),

  register: (data) =>
    api.post('/admin/auth/register', data),

  changePassword: (currentPassword, newPassword) =>
    api.post('/admin/auth/change-password', { currentPassword, newPassword }),
};

// Dashboard API
export const dashboardApi = {
  getSaasDashboard: () =>
    api.get('/admin/dashboard/saas'),

  getSocietyDashboard: (societyId) =>
    api.get(`/admin/dashboard/society/${societyId}`),

  getGateLogs: (societyId, params) =>
    api.get(`/admin/dashboard/gate-logs/${societyId}`, { params }),
};

// Societies API
export const societiesApi = {
  getAll: () =>
    api.get('/admin/societies'),

  getById: (id) =>
    api.get(`/admin/societies/${id}`),

  create: (data) =>
    api.post('/admin/societies', data),

  update: (id, data) =>
    api.put(`/admin/societies/${id}`, data),

  createStructure: (id, data) =>
    api.post(`/admin/societies/${id}/structure`, data),

  updatePolicies: (id, policies) =>
    api.put(`/admin/societies/${id}/policies`, { policies }),

  getResidents: (id, params) =>
    api.get(`/admin/societies/${id}/residents`, { params }),

  getPendingRequests: (id) =>
    api.get(`/admin/societies/${id}/pending-requests`),
};

// Notices API
export const noticesApi = {
  getAll: (params) =>
    api.get('/notices', { params }),

  getById: (id) =>
    api.get(`/notices/${id}`),

  create: (data) =>
    api.post('/notices', data),

  update: (id, data) =>
    api.put(`/notices/${id}`, data),

  delete: (id) =>
    api.delete(`/notices/${id}`),
};

// Complaints API
export const complaintsApi = {
  getAll: (params) =>
    api.get('/complaints', { params }),

  getById: (id) =>
    api.get(`/complaints/${id}`),

  create: (data) =>
    api.post('/complaints', data),

  update: (id, data) =>
    api.put(`/complaints/${id}`, data),

  delete: (id) =>
    api.delete(`/complaints/${id}`),

  addComment: (id, comment, isInternal = false) =>
    api.post(`/complaints/${id}/comments`, { comment, is_internal: isInternal }),
};

// Visitors API
export const visitorsApi = {
  getAll: (params) =>
    api.get('/visitors', { params }),

  getById: (id) =>
    api.get(`/visitors/${id}`),
};

// Emergencies API (Admin)
export const emergenciesApi = {
  getAll: (societyId, params) =>
    api.get('/admin/emergencies', { params: { society_id: societyId, ...params } }),

  resolve: (id) =>
    api.put(`/admin/emergencies/${id}/resolve`),
};

export default api;
