import React, { useEffect } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import Layout from '@/components/layout/Layout';
import useAuthStore from '@/stores/authStore';

// Lazy load pages
const Login = React.lazy(() => import('@/pages/Login'));
const SaasDashboard = React.lazy(() => import('@/pages/SaasDashboard'));
const SocietyDashboard = React.lazy(() => import('@/pages/SocietyDashboard'));
const Societies = React.lazy(() => import('@/pages/Societies'));
const SocietyOnboarding = React.lazy(() => import('@/pages/SocietyOnboarding'));
const Residents = React.lazy(() => import('@/pages/Residents'));
const Notices = React.lazy(() => import('@/pages/Notices'));
const Complaints = React.lazy(() => import('@/pages/Complaints'));
const GateLogs = React.lazy(() => import('@/pages/GateLogs'));
const Emergencies = React.lazy(() => import('@/pages/Emergencies'));
const Approvals = React.lazy(() => import('@/pages/Approvals'));
const Unauthorized = React.lazy(() => import('@/pages/Unauthorized'));

// Loading fallback
function PageLoader() {
  return (
    <div className="flex h-full min-h-[400px] items-center justify-center">
      <div className="flex flex-col items-center gap-2">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
        <span className="text-sm text-muted-foreground">Loading...</span>
      </div>
    </div>
  );
}

// Protected route wrapper
function ProtectedRoute({ children, allowedRoles = [] }) {
  const { isAuthenticated, hasRole, isLoading, _hasHydrated } = useAuthStore();
  const location = useLocation();

  // Wait for hydration before making routing decisions
  if (!_hasHydrated || isLoading) {
    return <PageLoader />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (allowedRoles.length > 0 && !allowedRoles.some((role) => hasRole(role))) {
    return <Navigate to="/unauthorized" replace />;
  }

  return children;
}

// Public route wrapper (redirects authenticated users)
function PublicRoute({ children }) {
  const { isAuthenticated, getDefaultRoute, _hasHydrated } = useAuthStore();

  // Wait for hydration before making routing decisions
  if (!_hasHydrated) {
    return <PageLoader />;
  }

  if (isAuthenticated) {
    return <Navigate to={getDefaultRoute()} replace />;
  }

  return children;
}

// Root redirect - handles "/" route
function RootRedirect() {
  const { isAuthenticated, getDefaultRoute, _hasHydrated } = useAuthStore();

  // Wait for hydration before making routing decisions
  if (!_hasHydrated) {
    return <PageLoader />;
  }

  if (isAuthenticated) {
    return <Navigate to={getDefaultRoute()} replace />;
  }

  return <Navigate to="/login" replace />;
}

export default function App() {
  const { isAuthenticated, fetchProfile } = useAuthStore();

  // Fetch profile on mount if authenticated
  useEffect(() => {
    const accessToken = localStorage.getItem('accessToken');
    if (accessToken && isAuthenticated) {
      fetchProfile();
    }
  }, []);

  return (
    <React.Suspense fallback={<PageLoader />}>
      <Routes>
        {/* Public Routes */}
        <Route
          path="/login"
          element={
            <PublicRoute>
              <Login />
            </PublicRoute>
          }
        />

        {/* Protected Routes - Super Admin */}
        <Route
          path="/saas-dashboard"
          element={
            <ProtectedRoute allowedRoles={['super_admin']}>
              <Layout>
                <SaasDashboard />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/societies"
          element={
            <ProtectedRoute allowedRoles={['super_admin']}>
              <Layout>
                <Societies />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/societies/new"
          element={
            <ProtectedRoute allowedRoles={['super_admin']}>
              <Layout>
                <SocietyOnboarding />
              </Layout>
            </ProtectedRoute>
          }
        />

        {/* Protected Routes - Society Admin */}
        <Route
          path="/society-dashboard"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin']}>
              <Layout>
                <SocietyDashboard />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/residents"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin']}>
              <Layout>
                <Residents />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/notices"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin']}>
              <Layout>
                <Notices />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/complaints"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin']}>
              <Layout>
                <Complaints />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/approvals"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin']}>
              <Layout>
                <Approvals />
              </Layout>
            </ProtectedRoute>
          }
        />

        {/* Protected Routes - All Admin Roles */}
        <Route
          path="/gate-logs"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin', 'guard']}>
              <Layout>
                <GateLogs />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/emergencies"
          element={
            <ProtectedRoute allowedRoles={['super_admin', 'society_admin', 'guard']}>
              <Layout>
                <Emergencies />
              </Layout>
            </ProtectedRoute>
          }
        />

        {/* Unauthorized page */}
        <Route
          path="/unauthorized"
          element={<Unauthorized />}
        />

        {/* Root route - redirect based on auth status */}
        <Route
          path="/"
          element={
            <RootRedirect />
          }
        />

        {/* Catch all - redirect to login */}
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </React.Suspense>
  );
}
