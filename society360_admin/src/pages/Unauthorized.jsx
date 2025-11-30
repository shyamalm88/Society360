import React from 'react';
import { ShieldX } from 'lucide-react';
import { Button } from '@/components/ui/button';
import useAuthStore from '@/stores/authStore';

export default function Unauthorized() {
  const { logout } = useAuthStore();

  const handleLogout = async () => {
    await logout();
    window.location.href = '/login';
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="text-center p-8">
        <ShieldX className="h-16 w-16 text-destructive mx-auto mb-4" />
        <h1 className="text-2xl font-bold mb-2">Access Denied</h1>
        <p className="text-muted-foreground mb-6">
          You don't have permission to access the admin portal.
          <br />
          Please contact your administrator if you believe this is an error.
        </p>
        <Button onClick={handleLogout} variant="outline">
          Back to Login
        </Button>
      </div>
    </div>
  );
}
