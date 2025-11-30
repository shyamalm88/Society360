import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { authApi } from '@/lib/api';

const useAuthStore = create(
  persist(
    (set, get) => ({
      user: null,
      roles: [],
      societies: [],
      isAuthenticated: false,
      isLoading: false,
      error: null,
      _hasHydrated: false,

      // Set hydration complete
      setHasHydrated: (state) => {
        set({ _hasHydrated: state });
      },

      // Login action
      login: async (email, password) => {
        set({ isLoading: true, error: null });
        try {
          const response = await authApi.login(email, password);
          const { accessToken, refreshToken, user, societies } = response.data.data;

          // Store tokens
          localStorage.setItem('accessToken', accessToken);
          localStorage.setItem('refreshToken', refreshToken);

          set({
            user: {
              id: user.id,
              userId: user.userId,
              email: user.email,
              name: user.name,
              phone: user.phone,
              avatarUrl: user.avatarUrl,
            },
            roles: user.roles,
            societies: societies || [],
            isAuthenticated: true,
            isLoading: false,
          });

          return user.defaultRoute;
        } catch (error) {
          const message = error.response?.data?.error || 'Login failed';
          set({ error: message, isLoading: false });
          throw new Error(message);
        }
      },

      // Logout action
      logout: async () => {
        try {
          const refreshToken = localStorage.getItem('refreshToken');
          if (refreshToken) {
            await authApi.logout(refreshToken);
          }
        } catch (error) {
          console.error('Logout error:', error);
        } finally {
          localStorage.removeItem('accessToken');
          localStorage.removeItem('refreshToken');
          set({
            user: null,
            roles: [],
            societies: [],
            isAuthenticated: false,
          });
        }
      },

      // Fetch current user profile
      fetchProfile: async () => {
        set({ isLoading: true });
        try {
          const response = await authApi.getProfile();
          const { user, roles, societies } = response.data.data;

          set({
            user,
            roles,
            societies,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          set({ isLoading: false });
          // If profile fetch fails, clear auth
          if (error.response?.status === 401) {
            get().logout();
          }
        }
      },

      // Check if user has specific role
      hasRole: (role) => {
        const { roles } = get();
        return roles.some((r) => r.role === role);
      },

      // Check if user has access to specific society
      hasSocietyAccess: (societyId) => {
        const { roles } = get();
        if (roles.some((r) => r.role === 'super_admin')) return true;
        return roles.some((r) => r.scope_type === 'society' && r.scope_id === societyId);
      },

      // Get primary role
      getPrimaryRole: () => {
        const { roles } = get();
        if (roles.some((r) => r.role === 'super_admin')) return 'super_admin';
        if (roles.some((r) => r.role === 'society_admin')) return 'society_admin';
        if (roles.some((r) => r.role === 'guard')) return 'guard';
        return 'resident';
      },

      // Get default route based on role
      getDefaultRoute: () => {
        const primaryRole = get().getPrimaryRole();
        switch (primaryRole) {
          case 'super_admin':
            return '/saas-dashboard';
          case 'society_admin':
            return '/society-dashboard';
          case 'guard':
            return '/gate-logs';
          default:
            return '/unauthorized';
        }
      },

      // Clear error
      clearError: () => set({ error: null }),
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        roles: state.roles,
        societies: state.societies,
        isAuthenticated: state.isAuthenticated,
      }),
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);
      },
    }
  )
);

export default useAuthStore;
