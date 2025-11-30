import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  Building2,
  Users,
  UserCheck,
  Shield,
  AlertTriangle,
  TrendingUp,
  Plus,
  ArrowRight,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { dashboardApi } from '@/lib/api';
import { formatDate, formatRelativeTime } from '@/lib/utils';

function StatCard({ title, value, icon: Icon, trend, description, className }) {
  return (
    <Card className={className}>
      <CardContent className="p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <p className="mt-1 text-3xl font-bold">{value}</p>
            {description && (
              <p className="mt-1 text-xs text-muted-foreground">{description}</p>
            )}
          </div>
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
            <Icon className="h-6 w-6 text-primary" />
          </div>
        </div>
        {trend && (
          <div className="mt-4 flex items-center text-sm">
            <TrendingUp className="mr-1 h-4 w-4 text-green-500" />
            <span className="text-green-500 font-medium">{trend}</span>
            <span className="ml-1 text-muted-foreground">vs last month</span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export default function SaasDashboard() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['saas-dashboard'],
    queryFn: async () => {
      const response = await dashboardApi.getSaasDashboard();
      return response.data.data;
    },
  });

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="animate-pulse">
          <div className="h-8 w-48 bg-muted rounded mb-2" />
          <div className="h-4 w-64 bg-muted rounded" />
        </div>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
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
        <p className="text-muted-foreground">{error.message}</p>
      </div>
    );
  }

  const { stats, recentSocieties, visitorTrends, activeEmergencies } = data;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">SaaS Dashboard</h1>
          <p className="text-muted-foreground">
            Overview of all societies and system metrics
          </p>
        </div>
        <Button asChild>
          <Link to="/societies/new">
            <Plus className="mr-2 h-4 w-4" />
            Onboard Society
          </Link>
        </Button>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Total Societies"
          value={stats.total_societies}
          icon={Building2}
        />
        <StatCard
          title="Total Users"
          value={stats.total_users}
          icon={Users}
        />
        <StatCard
          title="Active Residents"
          value={stats.total_residents}
          icon={UserCheck}
        />
        <StatCard
          title="Active Guards"
          value={stats.total_guards}
          icon={Shield}
        />
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
                  {activeEmergencies.length} Active Emergency Alert{activeEmergencies.length > 1 ? 's' : ''}
                </p>
                <p className="text-sm text-muted-foreground">
                  Immediate attention required
                </p>
              </div>
              <Button variant="destructive" size="sm">
                View All
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Content Grid */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Recent Societies */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <div>
              <CardTitle className="text-lg">Recent Societies</CardTitle>
              <CardDescription>Latest onboarded societies</CardDescription>
            </div>
            <Button variant="ghost" size="sm" asChild>
              <Link to="/societies">
                View all
                <ArrowRight className="ml-1 h-4 w-4" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {recentSocieties.map((society) => (
                <div
                  key={society.id}
                  className="flex items-center justify-between rounded-lg border p-3"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                      <Building2 className="h-5 w-5 text-primary" />
                    </div>
                    <div>
                      <p className="font-medium">{society.name}</p>
                      <p className="text-sm text-muted-foreground">
                        {society.city} • {society.resident_count} residents
                      </p>
                    </div>
                  </div>
                  <Badge variant="secondary">
                    {formatDate(society.created_at)}
                  </Badge>
                </div>
              ))}
              {recentSocieties.length === 0 && (
                <p className="text-center text-muted-foreground py-4">
                  No societies onboarded yet
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Today's Activity */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Today's Activity</CardTitle>
            <CardDescription>Visitor activity for today</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-center py-8">
              <div className="text-center">
                <p className="text-5xl font-bold text-primary">{stats.visitors_today}</p>
                <p className="mt-2 text-muted-foreground">Visitors Today</p>
              </div>
            </div>

            {/* Visitor Trend Mini Chart */}
            {visitorTrends.length > 0 && (
              <div className="mt-4 border-t pt-4">
                <p className="text-sm font-medium mb-3">Last 7 Days</p>
                <div className="flex items-end gap-1 h-16">
                  {visitorTrends.map((day, i) => {
                    const maxCount = Math.max(...visitorTrends.map(d => d.count));
                    const height = maxCount > 0 ? (day.count / maxCount) * 100 : 0;
                    return (
                      <div
                        key={day.date}
                        className="flex-1 bg-primary/20 hover:bg-primary/30 rounded-t transition-colors"
                        style={{ height: `${Math.max(height, 5)}%` }}
                        title={`${day.count} visitors on ${formatDate(day.date)}`}
                      />
                    );
                  })}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Active Emergencies */}
        {activeEmergencies.length > 0 && (
          <Card className="lg:col-span-2">
            <CardHeader>
              <CardTitle className="text-lg text-destructive flex items-center gap-2">
                <AlertTriangle className="h-5 w-5" />
                Active Emergencies
              </CardTitle>
              <CardDescription>Unresolved emergency alerts</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {activeEmergencies.slice(0, 5).map((emergency) => (
                  <div
                    key={emergency.id}
                    className="flex items-center justify-between rounded-lg border border-destructive/20 bg-destructive/5 p-3"
                  >
                    <div>
                      <p className="font-medium">
                        {emergency.society_name}
                        {emergency.block_name && ` - ${emergency.block_name}`}
                        {emergency.flat_number && ` - ${emergency.flat_number}`}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        Reported by {emergency.reported_by_name} • {formatRelativeTime(emergency.created_at)}
                      </p>
                    </div>
                    <Badge variant="destructive">Urgent</Badge>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
