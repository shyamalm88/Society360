import React from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Building2,
  Users,
  Bell,
  MessageSquare,
  ClipboardList,
  Settings,
  Shield,
  LogOut,
  ChevronDown,
  AlertTriangle,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import useAuthStore from '@/stores/authStore';
import { getInitials } from '@/lib/utils';

const superAdminNavItems = [
  {
    title: 'SaaS Dashboard',
    href: '/saas-dashboard',
    icon: LayoutDashboard,
  },
  {
    title: 'Societies',
    href: '/societies',
    icon: Building2,
  },
  {
    title: 'All Users',
    href: '/users',
    icon: Users,
  },
  {
    title: 'Settings',
    href: '/settings',
    icon: Settings,
  },
];

const societyAdminNavItems = [
  {
    title: 'Dashboard',
    href: '/society-dashboard',
    icon: LayoutDashboard,
  },
  {
    title: 'Residents',
    href: '/residents',
    icon: Users,
  },
  {
    title: 'Notices',
    href: '/notices',
    icon: Bell,
  },
  {
    title: 'Complaints',
    href: '/complaints',
    icon: MessageSquare,
  },
  {
    title: 'Approvals',
    href: '/approvals',
    icon: ClipboardList,
  },
  {
    title: 'Gate Logs',
    href: '/gate-logs',
    icon: Shield,
  },
  {
    title: 'Emergencies',
    href: '/emergencies',
    icon: AlertTriangle,
  },
];

const guardNavItems = [
  {
    title: 'Gate Logs',
    href: '/gate-logs',
    icon: Shield,
  },
  {
    title: 'Emergencies',
    href: '/emergencies',
    icon: AlertTriangle,
  },
];

export default function Sidebar({ className, onNavigate }) {
  const location = useLocation();
  const { user, logout, getPrimaryRole, societies } = useAuthStore();
  const primaryRole = getPrimaryRole();

  const getNavItems = () => {
    switch (primaryRole) {
      case 'super_admin':
        return superAdminNavItems;
      case 'society_admin':
        return societyAdminNavItems;
      case 'guard':
        return guardNavItems;
      default:
        return [];
    }
  };

  const navItems = getNavItems();

  const handleLogout = async () => {
    await logout();
    window.location.href = '/login';
  };

  const handleNavClick = () => {
    if (onNavigate) {
      onNavigate();
    }
  };

  return (
    <div className={cn('flex h-full flex-col', className)}>
      {/* Logo */}
      <div className="flex h-16 items-center border-b px-6">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <Building2 className="h-5 w-5 text-white" />
          </div>
          <span className="text-xl font-bold text-primary">Society360</span>
        </div>
      </div>

      {/* Society Selector (for society admin) */}
      {primaryRole === 'society_admin' && societies.length > 0 && (
        <div className="border-b px-4 py-3">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="outline"
                className="w-full justify-between text-left font-normal"
              >
                <span className="truncate">{societies[0]?.name || 'Select Society'}</span>
                <ChevronDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-[200px]">
              {societies.map((society) => (
                <DropdownMenuItem key={society.id}>
                  {society.name}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      )}

      {/* Navigation */}
      <nav className="flex-1 space-y-1 overflow-y-auto p-4">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = location.pathname === item.href;

          return (
            <NavLink
              key={item.href}
              to={item.href}
              onClick={handleNavClick}
              className={cn(
                'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors touch-target',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:bg-muted hover:text-foreground'
              )}
            >
              <Icon className="h-5 w-5" />
              {item.title}
            </NavLink>
          );
        })}
      </nav>

      {/* User Profile */}
      <div className="border-t p-4">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              className="w-full justify-start gap-3 px-3 py-6"
            >
              <Avatar className="h-9 w-9">
                <AvatarImage src={user?.avatarUrl} alt={user?.name} />
                <AvatarFallback className="bg-primary/10 text-primary">
                  {getInitials(user?.name)}
                </AvatarFallback>
              </Avatar>
              <div className="flex flex-col items-start text-left">
                <span className="text-sm font-medium">{user?.name}</span>
                <span className="text-xs text-muted-foreground capitalize">
                  {primaryRole.replace('_', ' ')}
                </span>
              </div>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel>
              <div className="flex flex-col">
                <span>{user?.name}</span>
                <span className="text-xs font-normal text-muted-foreground">
                  {user?.email}
                </span>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem>
              <Settings className="mr-2 h-4 w-4" />
              Settings
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              className="text-destructive focus:text-destructive"
              onClick={handleLogout}
            >
              <LogOut className="mr-2 h-4 w-4" />
              Logout
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  );
}
