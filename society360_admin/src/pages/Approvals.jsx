import React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  ClipboardList,
  CheckCircle,
  XCircle,
  Phone,
  Mail,
  Home,
  RefreshCw,
  AlertTriangle,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatRelativeTime, getInitials } from '@/lib/utils';
import useAuthStore from '@/stores/authStore';
import api from '@/lib/api';

export default function Approvals() {
  const queryClient = useQueryClient();
  const { societies } = useAuthStore();
  const societyId = societies[0]?.id;

  // Fetch pending approvals
  const { data: approvals, isLoading, error, refetch } = useQuery({
    queryKey: ['approvals', societyId],
    queryFn: async () => {
      const response = await api.get('/admin/approvals', {
        params: { society_id: societyId, status: 'pending' },
      });
      return response.data.data || [];
    },
    enabled: !!societyId,
    refetchInterval: (query) => (query.state.error ? false : 30000),
    retry: 1,
  });

  // Approve mutation
  const approveMutation = useMutation({
    mutationFn: async (id) => {
      return api.put(`/admin/approvals/${id}/approve`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['approvals']);
    },
  });

  // Reject mutation
  const rejectMutation = useMutation({
    mutationFn: async (id) => {
      return api.put(`/admin/approvals/${id}/reject`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['approvals']);
    },
  });

  if (!societyId) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <AlertTriangle className="h-12 w-12 text-muted-foreground/20 mb-4" />
        <p className="text-lg font-medium">No Society Assigned</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <AlertTriangle className="h-12 w-12 text-destructive mb-4" />
        <p className="text-lg font-medium">Failed to load approvals</p>
        <Button onClick={() => refetch()} className="mt-4" variant="outline">
          <RefreshCw className="mr-2 h-4 w-4" />
          Retry
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl flex items-center gap-2">
            <ClipboardList className="h-8 w-8 text-primary" />
            Approvals
          </h1>
          <p className="text-muted-foreground">
            Review and approve resident registration requests
          </p>
        </div>
        <Button variant="outline" onClick={() => refetch()}>
          <RefreshCw className="mr-2 h-4 w-4" />
          Refresh
        </Button>
      </div>

      {/* Stats Card */}
      <div className="grid gap-4 grid-cols-2 md:grid-cols-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Pending Requests</p>
                <p className="text-2xl font-bold">{approvals?.length || 0}</p>
              </div>
              <ClipboardList className="h-8 w-8 text-primary/20" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Approvals Table - Desktop */}
      <Card className="hidden md:block">
        <CardHeader>
          <CardTitle className="text-lg">Pending Requests</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-4">
              {[...Array(3)].map((_, i) => (
                <div key={i} className="animate-pulse flex items-center gap-4">
                  <div className="h-10 w-10 bg-muted rounded-full" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-32 bg-muted rounded" />
                    <div className="h-3 w-24 bg-muted rounded" />
                  </div>
                </div>
              ))}
            </div>
          ) : approvals?.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12">
              <CheckCircle className="h-16 w-16 text-green-500 mb-4" />
              <p className="text-lg font-medium text-green-700">All Caught Up!</p>
              <p className="text-green-600">No pending approval requests</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Applicant</TableHead>
                  <TableHead>Flat</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Submitted</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {approvals.map((request) => (
                  <TableRow key={request.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <Avatar>
                          <AvatarFallback className="bg-primary/10 text-primary">
                            {getInitials(request.requesting_user_name)}
                          </AvatarFallback>
                        </Avatar>
                        <div>
                          <p className="font-medium">{request.requesting_user_name}</p>
                          {request.note && (
                            <p className="text-xs text-muted-foreground truncate max-w-[200px]">
                              {request.note}
                            </p>
                          )}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <Home className="h-4 w-4 text-muted-foreground" />
                        <span>
                          {request.block_name} - {request.flat_number}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="space-y-1">
                        {request.requesting_user_phone && (
                          <div className="flex items-center gap-1 text-sm">
                            <Phone className="h-3 w-3" />
                            {request.requesting_user_phone}
                          </div>
                        )}
                        {request.requesting_user_email && (
                          <div className="flex items-center gap-1 text-sm text-muted-foreground">
                            <Mail className="h-3 w-3" />
                            {request.requesting_user_email}
                          </div>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" className="capitalize">
                        {request.requested_role}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatRelativeTime(request.submitted_at)}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Button
                          size="sm"
                          onClick={() => approveMutation.mutate(request.id)}
                          disabled={approveMutation.isPending || rejectMutation.isPending}
                        >
                          <CheckCircle className="mr-1 h-4 w-4" />
                          Approve
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => rejectMutation.mutate(request.id)}
                          disabled={approveMutation.isPending || rejectMutation.isPending}
                        >
                          <XCircle className="mr-1 h-4 w-4" />
                          Reject
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Approvals Cards - Mobile */}
      <div className="md:hidden space-y-3">
        {isLoading ? (
          [...Array(3)].map((_, i) => (
            <Card key={i}>
              <CardContent className="p-4">
                <div className="animate-pulse flex items-center gap-4">
                  <div className="h-12 w-12 bg-muted rounded-full" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-32 bg-muted rounded" />
                    <div className="h-3 w-24 bg-muted rounded" />
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        ) : approvals?.length === 0 ? (
          <Card className="border-green-200 bg-green-50">
            <CardContent className="flex flex-col items-center justify-center py-12">
              <CheckCircle className="h-16 w-16 text-green-500 mb-4" />
              <p className="text-lg font-medium text-green-700">All Caught Up!</p>
              <p className="text-green-600">No pending approval requests</p>
            </CardContent>
          </Card>
        ) : (
          approvals.map((request) => (
            <Card key={request.id}>
              <CardContent className="p-4">
                <div className="flex items-start gap-3">
                  <Avatar className="h-12 w-12">
                    <AvatarFallback className="bg-primary/10 text-primary">
                      {getInitials(request.requesting_user_name)}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <p className="font-semibold truncate">{request.requesting_user_name}</p>
                      <Badge variant="outline" className="capitalize ml-2">
                        {request.requested_role}
                      </Badge>
                    </div>
                    <div className="flex items-center gap-1 text-sm text-muted-foreground mt-1">
                      <Home className="h-3 w-3" />
                      {request.block_name} - {request.flat_number}
                    </div>
                    {request.requesting_user_phone && (
                      <div className="flex items-center gap-1 text-sm text-muted-foreground mt-1">
                        <Phone className="h-3 w-3" />
                        {request.requesting_user_phone}
                      </div>
                    )}
                    <div className="text-xs text-muted-foreground mt-1">
                      {formatRelativeTime(request.submitted_at)}
                    </div>
                    <div className="flex gap-2 mt-3">
                      <Button
                        size="sm"
                        onClick={() => approveMutation.mutate(request.id)}
                        disabled={approveMutation.isPending || rejectMutation.isPending}
                        className="flex-1"
                      >
                        <CheckCircle className="mr-1 h-4 w-4" />
                        Approve
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => rejectMutation.mutate(request.id)}
                        disabled={approveMutation.isPending || rejectMutation.isPending}
                        className="flex-1"
                      >
                        <XCircle className="mr-1 h-4 w-4" />
                        Reject
                      </Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
