import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  Shield,
  Calendar,
  Clock,
  LogIn,
  LogOut,
  AlertCircle,
  CheckCircle,
  XCircle,
  Search,
  RefreshCw,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { dashboardApi } from '@/lib/api';
import { formatTime, formatDate, getInitials, getStatusColor, cn } from '@/lib/utils';
import useAuthStore from '@/stores/authStore';

const STATUS_ICONS = {
  pending: AlertCircle,
  accepted: CheckCircle,
  denied: XCircle,
  checked_in: LogIn,
  checked_out: LogOut,
  cancelled: XCircle,
};

export default function GateLogs() {
  const { societies } = useAuthStore();
  const societyId = societies[0]?.id;
  const [selectedDate, setSelectedDate] = useState(
    new Date().toISOString().split('T')[0]
  );

  const { data, isLoading, refetch } = useQuery({
    queryKey: ['gate-logs', societyId, selectedDate],
    queryFn: async () => {
      const response = await dashboardApi.getGateLogs(societyId, {
        date: selectedDate,
      });
      return response.data.data;
    },
    enabled: !!societyId,
    refetchInterval: 30000, // Refetch every 30 seconds
  });

  const logs = data?.logs || [];
  const counts = data?.counts || {};

  if (!societyId) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <Shield className="h-12 w-12 text-muted-foreground/20 mb-4" />
        <p className="text-lg font-medium">No Society Assigned</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">Gate Logs</h1>
          <p className="text-muted-foreground">
            Visitor entry and exit records
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Input
            type="date"
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value)}
            className="w-auto"
          />
          <Button variant="outline" size="icon" onClick={() => refetch()}>
            <RefreshCw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid gap-4 grid-cols-2 md:grid-cols-5">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-muted-foreground">Total</p>
            <p className="text-2xl font-bold">{counts.total || 0}</p>
          </CardContent>
        </Card>
        <Card className="bg-green-50 border-green-200">
          <CardContent className="p-4 text-center">
            <p className="text-sm text-green-600">Checked In</p>
            <p className="text-2xl font-bold text-green-700">{counts.checked_in || 0}</p>
          </CardContent>
        </Card>
        <Card className="bg-blue-50 border-blue-200">
          <CardContent className="p-4 text-center">
            <p className="text-sm text-blue-600">Checked Out</p>
            <p className="text-2xl font-bold text-blue-700">{counts.checked_out || 0}</p>
          </CardContent>
        </Card>
        <Card className="bg-amber-50 border-amber-200">
          <CardContent className="p-4 text-center">
            <p className="text-sm text-amber-600">Pending</p>
            <p className="text-2xl font-bold text-amber-700">{counts.pending || 0}</p>
          </CardContent>
        </Card>
        <Card className="bg-red-50 border-red-200">
          <CardContent className="p-4 text-center">
            <p className="text-sm text-red-600">Denied</p>
            <p className="text-2xl font-bold text-red-700">{counts.denied || 0}</p>
          </CardContent>
        </Card>
      </div>

      {/* Logs List */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-lg flex items-center gap-2">
              <Calendar className="h-5 w-5" />
              {formatDate(selectedDate, { weekday: 'long', month: 'long', day: 'numeric' })}
            </CardTitle>
            <Badge variant="secondary">{logs.length} entries</Badge>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-4">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="animate-pulse flex items-center gap-4">
                  <div className="h-10 w-10 bg-muted rounded-full" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-32 bg-muted rounded" />
                    <div className="h-3 w-48 bg-muted rounded" />
                  </div>
                </div>
              ))}
            </div>
          ) : logs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12">
              <Shield className="h-12 w-12 text-muted-foreground/20 mb-4" />
              <p className="text-muted-foreground">No visitor logs for this date</p>
            </div>
          ) : (
            <div className="space-y-3">
              {logs.map((log) => {
                const StatusIcon = STATUS_ICONS[log.status] || AlertCircle;

                return (
                  <div
                    key={log.id}
                    className="flex items-center gap-4 rounded-lg border p-3"
                  >
                    <Avatar className="h-10 w-10">
                      <AvatarFallback className={cn(
                        log.status === 'checked_in' && 'bg-green-100 text-green-700',
                        log.status === 'checked_out' && 'bg-blue-100 text-blue-700',
                        log.status === 'pending' && 'bg-amber-100 text-amber-700',
                        log.status === 'denied' && 'bg-red-100 text-red-700'
                      )}>
                        {getInitials(log.visitor_name)}
                      </AvatarFallback>
                    </Avatar>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="font-medium truncate">{log.visitor_name}</p>
                        <Badge className={getStatusColor(log.status)}>
                          <StatusIcon className="h-3 w-3 mr-1" />
                          {log.status.replace('_', ' ')}
                        </Badge>
                      </div>
                      <p className="text-sm text-muted-foreground">
                        {log.block_name} - {log.flat_number}
                        {log.purpose && ` • ${log.purpose}`}
                      </p>
                    </div>

                    <div className="text-right text-sm">
                      {log.checkin_time && (
                        <div className="flex items-center gap-1 text-green-600">
                          <LogIn className="h-3 w-3" />
                          {formatTime(log.checkin_time)}
                        </div>
                      )}
                      {log.checkout_time && (
                        <div className="flex items-center gap-1 text-blue-600">
                          <LogOut className="h-3 w-3" />
                          {formatTime(log.checkout_time)}
                        </div>
                      )}
                      {!log.checkin_time && !log.checkout_time && (
                        <p className="text-muted-foreground">
                          {formatTime(log.created_at)}
                        </p>
                      )}
                      {log.guard_name && (
                        <p className="text-xs text-muted-foreground mt-1">
                          by {log.guard_name}
                        </p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
