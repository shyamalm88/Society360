import React, { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  Users,
  Home,
  Shield,
  UserCheck,
  AlertTriangle,
  MessageSquare,
  Clock,
  Bell,
  RefreshCw,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { dashboardApi } from '@/lib/api';
import { formatTime, formatRelativeTime, getInitials, getStatusColor } from '@/lib/utils';
import useAuthStore from '@/stores/authStore';
import { io } from 'socket.io-client';

function StatCard({ title, value, icon: Icon, variant = 'default' }) {
  const variantStyles = {
    default: 'bg-primary/10 text-primary',
    warning: 'bg-amber-500/10 text-amber-600',
    success: 'bg-green-500/10 text-green-600',
    danger: 'bg-red-500/10 text-red-600',
  };

  return (
    <Card>
      <CardContent className="p-4 md:p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <p className="mt-1 text-2xl md:text-3xl font-bold">{value}</p>
          </div>
          <div className={`flex h-10 w-10 md:h-12 md:w-12 items-center justify-center rounded-full ${variantStyles[variant]}`}>
            <Icon className="h-5 w-5 md:h-6 md:w-6" />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function SocietyDashboard() {
  const { societies } = useAuthStore();
  const societyId = societies[0]?.id;
  const [socket, setSocket] = useState(null);

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['society-dashboard', societyId],
    queryFn: async () => {
      if (!societyId) return null;
      const response = await dashboardApi.getSocietyDashboard(societyId);
      return response.data.data;
    },
    enabled: !!societyId,
    refetchInterval: (query) => (query.state.error ? false : 30000), // Stop refetching on error
    retry: 1,
  });

  // Setup Socket.io connection
  useEffect(() => {
    if (!societyId) return;

    const socketUrl = import.meta.env.VITE_SOCKET_URL || 'http://localhost:3000';
    const newSocket = io(socketUrl, {
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 3,
      reconnectionDelay: 5000,
      timeout: 10000,
      autoConnect: true,
    });

    newSocket.on('connect', () => {
      console.log('Socket connected');
      newSocket.emit('join_room', {
        room_type: 'society',
        room_id: societyId,
      });
    });

    newSocket.on('connect_error', (error) => {
      console.log('Socket connection error:', error.message);
    });

    newSocket.on('visitor_update', () => {
      refetch();
    });

    newSocket.on('emergency_alert', () => {
      refetch();
    });

    setSocket(newSocket);

    return () => {
      newSocket.disconnect();
    };
  }, [societyId]);

  if (!societyId) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <AlertTriangle className="h-12 w-12 text-warning mb-4" />
        <p className="text-lg font-medium">No Society Assigned</p>
        <p className="text-muted-foreground">Please contact administrator</p>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="animate-pulse">
          <div className="h-8 w-48 bg-muted rounded mb-2" />
          <div className="h-4 w-64 bg-muted rounded" />
        </div>
        <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i}>
              <CardContent className="p-6">
                <div className="animate-pulse space-y-3">
                  <div className="h-4 w-24 bg-muted rounded" />
                  <div className="h-8 w-16 bg-muted rounded" />
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <AlertTriangle className="h-12 w-12 text-destructive mb-4" />
        <p className="text-lg font-medium">Failed to load dashboard</p>
        <Button onClick={() => refetch()} className="mt-4">
          <RefreshCw className="mr-2 h-4 w-4" />
          Retry
        </Button>
      </div>
    );
  }

  const { stats, liveGateFeed, recentNotices, complaintSummary, activeEmergencies, visitorTrends } = data;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">Dashboard</h1>
          <p className="text-muted-foreground">
            {societies[0]?.name} • Real-time overview
          </p>
        </div>
        <Button variant="outline" onClick={() => refetch()}>
          <RefreshCw className="mr-2 h-4 w-4" />
          Refresh
        </Button>
      </div>

      {/* Emergency Alert Banner */}
      {activeEmergencies.length > 0 && (
        <Card className="border-destructive bg-destructive/5">
          <CardContent className="p-4">
            <div className="flex items-center gap-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-destructive panic-alert">
                <AlertTriangle className="h-5 w-5 text-white" />
              </div>
              <div className="flex-1">
                <p className="font-semibold text-destructive">
                  PANIC ALERT - {activeEmergencies.length} Active
                </p>
                <p className="text-sm text-muted-foreground">
                  {activeEmergencies[0]?.block_name} - {activeEmergencies[0]?.flat_number}
                </p>
              </div>
              <Button variant="destructive">View</Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Stats Grid */}
      <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Residents"
          value={stats.total_residents}
          icon={Users}
        />
        <StatCard
          title="Total Flats"
          value={stats.total_flats}
          icon={Home}
        />
        <StatCard
          title="Active Visitors"
          value={stats.active_visitors}
          icon={UserCheck}
          variant="success"
        />
        <StatCard
          title="Open Complaints"
          value={stats.open_complaints}
          icon={MessageSquare}
          variant={stats.open_complaints > 0 ? 'warning' : 'default'}
        />
      </div>

      {/* Second Row Stats */}
      <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Guards on Duty"
          value={stats.total_guards}
          icon={Shield}
        />
        <StatCard
          title="Visitors Today"
          value={stats.visitors_today}
          icon={Clock}
        />
        <StatCard
          title="Pending Approvals"
          value={stats.pending_approvals}
          icon={Bell}
          variant={stats.pending_approvals > 0 ? 'warning' : 'default'}
        />
        <StatCard
          title="Emergencies"
          value={activeEmergencies.length}
          icon={AlertTriangle}
          variant={activeEmergencies.length > 0 ? 'danger' : 'default'}
        />
      </div>

      {/* Content Grid */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Live Gate Feed */}
        <Card className="lg:row-span-2">
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-lg flex items-center gap-2">
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
                  </span>
                  Live Gate Feed
                </CardTitle>
                <CardDescription>Currently checked-in visitors</CardDescription>
              </div>
              <Badge variant="secondary">{liveGateFeed.length} Inside</Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-3 max-h-[400px] overflow-y-auto">
              {liveGateFeed.map((visitor) => (
                <div
                  key={visitor.id}
                  className="flex items-center gap-3 rounded-lg border p-3"
                >
                  <Avatar className="h-10 w-10">
                    <AvatarFallback className="bg-green-100 text-green-700">
                      {getInitials(visitor.visitor_name)}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <p className="font-medium truncate">{visitor.visitor_name}</p>
                    <p className="text-sm text-muted-foreground">
                      {visitor.block_name} - {visitor.flat_number}
                    </p>
                  </div>
                  <div className="text-right">
                    <Badge className={getStatusColor('checked_in')}>
                      Inside
                    </Badge>
                    <p className="text-xs text-muted-foreground mt-1">
                      {visitor.checkin_time ? formatTime(visitor.checkin_time) : 'N/A'}
                    </p>
                  </div>
                </div>
              ))}
              {liveGateFeed.length === 0 && (
                <div className="text-center py-8 text-muted-foreground">
                  <UserCheck className="h-12 w-12 mx-auto mb-2 opacity-20" />
                  <p>No visitors currently inside</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Recent Notices */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">Recent Notices</CardTitle>
            <CardDescription>Latest announcements</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {recentNotices.slice(0, 3).map((notice) => (
                <div
                  key={notice.id}
                  className="flex items-start gap-3 rounded-lg border p-3"
                >
                  <div className={`mt-0.5 flex h-8 w-8 items-center justify-center rounded-full ${
                    notice.priority === 'critical' ? 'bg-red-100' :
                    notice.priority === 'high' ? 'bg-orange-100' :
                    'bg-blue-100'
                  }`}>
                    <Bell className={`h-4 w-4 ${
                      notice.priority === 'critical' ? 'text-red-600' :
                      notice.priority === 'high' ? 'text-orange-600' :
                      'text-blue-600'
                    }`} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-medium truncate">{notice.title}</p>
                    <p className="text-sm text-muted-foreground">
                      {formatRelativeTime(notice.created_at)}
                    </p>
                  </div>
                  {notice.is_pinned && (
                    <Badge variant="secondary">Pinned</Badge>
                  )}
                </div>
              ))}
              {recentNotices.length === 0 && (
                <p className="text-center text-muted-foreground py-4">
                  No notices posted yet
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Complaint Summary */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">Complaints Overview</CardTitle>
            <CardDescription>Ticket status distribution</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4">
              <div className="rounded-lg bg-blue-50 p-4 text-center">
                <p className="text-2xl font-bold text-blue-700">
                  {complaintSummary.open || 0}
                </p>
                <p className="text-sm text-blue-600">Open</p>
              </div>
              <div className="rounded-lg bg-amber-50 p-4 text-center">
                <p className="text-2xl font-bold text-amber-700">
                  {complaintSummary.in_progress || 0}
                </p>
                <p className="text-sm text-amber-600">In Progress</p>
              </div>
              <div className="rounded-lg bg-green-50 p-4 text-center">
                <p className="text-2xl font-bold text-green-700">
                  {complaintSummary.resolved || 0}
                </p>
                <p className="text-sm text-green-600">Resolved</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-4 text-center">
                <p className="text-2xl font-bold text-slate-700">
                  {complaintSummary.closed || 0}
                </p>
                <p className="text-sm text-slate-600">Closed</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
