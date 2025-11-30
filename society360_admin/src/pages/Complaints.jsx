import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  MessageSquare,
  Plus,
  Filter,
  MoreHorizontal,
  Clock,
  CheckCircle,
  AlertCircle,
  XCircle,
  Send,
  Loader2,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import { complaintsApi } from '@/lib/api';
import { formatRelativeTime, getInitials, cn } from '@/lib/utils';
import useAuthStore from '@/stores/authStore';

const STATUS_CONFIG = {
  open: { icon: AlertCircle, color: 'text-blue-600', bg: 'bg-blue-100' },
  in_progress: { icon: Clock, color: 'text-amber-600', bg: 'bg-amber-100' },
  resolved: { icon: CheckCircle, color: 'text-green-600', bg: 'bg-green-100' },
  closed: { icon: XCircle, color: 'text-slate-600', bg: 'bg-slate-100' },
};

const CATEGORY_OPTIONS = [
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'security', label: 'Security' },
  { value: 'amenities', label: 'Amenities' },
  { value: 'billing', label: 'Billing' },
  { value: 'noise', label: 'Noise' },
  { value: 'parking', label: 'Parking' },
  { value: 'other', label: 'Other' },
];

export default function Complaints() {
  const queryClient = useQueryClient();
  const { societies, hasRole } = useAuthStore();
  const societyId = societies[0]?.id;
  const isSuperAdmin = hasRole('super_admin');

  const [selectedComplaint, setSelectedComplaint] = useState(null);
  const [statusFilter, setStatusFilter] = useState('all');
  const [newComment, setNewComment] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['complaints', societyId, statusFilter],
    queryFn: async () => {
      const params = { society_id: isSuperAdmin ? undefined : societyId };
      if (statusFilter !== 'all') params.status = statusFilter;
      const response = await complaintsApi.getAll(params);
      return response.data;
    },
    enabled: isSuperAdmin || !!societyId,
  });

  const { data: complaintDetails, isLoading: isLoadingDetails } = useQuery({
    queryKey: ['complaint', selectedComplaint?.id],
    queryFn: async () => {
      const response = await complaintsApi.getById(selectedComplaint.id);
      return response.data.data;
    },
    enabled: !!selectedComplaint,
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ id, status }) => complaintsApi.update(id, { status }),
    onSuccess: () => {
      queryClient.invalidateQueries(['complaints']);
      queryClient.invalidateQueries(['complaint']);
    },
  });

  const addCommentMutation = useMutation({
    mutationFn: ({ id, comment }) => complaintsApi.addComment(id, comment),
    onSuccess: () => {
      queryClient.invalidateQueries(['complaint']);
      setNewComment('');
    },
  });

  const handleStatusChange = (complaintId, newStatus) => {
    updateStatusMutation.mutate({ id: complaintId, status: newStatus });
  };

  const handleAddComment = (e) => {
    e.preventDefault();
    if (!newComment.trim() || !selectedComplaint) return;
    addCommentMutation.mutate({ id: selectedComplaint.id, comment: newComment });
  };

  const complaints = data?.data || [];
  const statusCounts = data?.statusCounts || {};

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">Complaints</h1>
          <p className="text-muted-foreground">
            Manage resident helpdesk tickets
          </p>
        </div>
      </div>

      {/* Status Filter Tabs */}
      <div className="flex flex-wrap gap-2">
        <Button
          variant={statusFilter === 'all' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setStatusFilter('all')}
        >
          All
          <Badge variant="secondary" className="ml-2">
            {(statusCounts.open || 0) + (statusCounts.in_progress || 0) + (statusCounts.resolved || 0) + (statusCounts.closed || 0)}
          </Badge>
        </Button>
        {Object.entries(STATUS_CONFIG).map(([status, config]) => {
          const Icon = config.icon;
          return (
            <Button
              key={status}
              variant={statusFilter === status ? 'default' : 'outline'}
              size="sm"
              onClick={() => setStatusFilter(status)}
            >
              <Icon className={cn('h-4 w-4 mr-1', statusFilter !== status && config.color)} />
              {status.replace('_', ' ')}
              <Badge variant="secondary" className="ml-2">
                {statusCounts[status] || 0}
              </Badge>
            </Button>
          );
        })}
      </div>

      {/* Complaints List */}
      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {[...Array(6)].map((_, i) => (
            <Card key={i}>
              <CardContent className="p-4">
                <div className="animate-pulse space-y-3">
                  <div className="h-5 w-32 bg-muted rounded" />
                  <div className="h-4 w-full bg-muted rounded" />
                  <div className="h-4 w-24 bg-muted rounded" />
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : complaints.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <MessageSquare className="h-16 w-16 text-muted-foreground/20 mb-4" />
            <p className="text-lg font-medium">No complaints found</p>
            <p className="text-muted-foreground">
              {statusFilter !== 'all'
                ? `No ${statusFilter.replace('_', ' ')} complaints`
                : 'All complaints will appear here'}
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {complaints.map((complaint) => {
            const statusConfig = STATUS_CONFIG[complaint.status];
            const StatusIcon = statusConfig?.icon || AlertCircle;

            return (
              <Card
                key={complaint.id}
                className="cursor-pointer hover:shadow-md transition-shadow"
                onClick={() => setSelectedComplaint(complaint)}
              >
                <CardContent className="p-4">
                  <div className="flex items-start justify-between mb-3">
                    <div className={cn('p-2 rounded-lg', statusConfig?.bg)}>
                      <StatusIcon className={cn('h-4 w-4', statusConfig?.color)} />
                    </div>
                    <Badge variant="outline" className="capitalize">
                      {complaint.category}
                    </Badge>
                  </div>

                  <h3 className="font-semibold mb-1 line-clamp-1">{complaint.title}</h3>
                  {complaint.description && (
                    <p className="text-sm text-muted-foreground mb-3 line-clamp-2">
                      {complaint.description}
                    </p>
                  )}

                  <div className="flex items-center justify-between text-sm">
                    <div className="flex items-center gap-2">
                      <Avatar className="h-6 w-6">
                        <AvatarFallback className="text-xs">
                          {getInitials(complaint.submitted_by_name)}
                        </AvatarFallback>
                      </Avatar>
                      <span className="text-muted-foreground truncate max-w-[100px]">
                        {complaint.submitted_by_name}
                      </span>
                    </div>
                    <span className="text-muted-foreground">
                      {formatRelativeTime(complaint.created_at)}
                    </span>
                  </div>

                  {(complaint.block_name || complaint.flat_number) && (
                    <p className="text-xs text-muted-foreground mt-2">
                      {complaint.block_name} - {complaint.flat_number}
                    </p>
                  )}
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* Complaint Detail Sheet */}
      <Sheet
        open={!!selectedComplaint}
        onOpenChange={(open) => !open && setSelectedComplaint(null)}
      >
        <SheetContent className="w-full sm:max-w-lg overflow-y-auto">
          <SheetHeader>
            <SheetTitle>{selectedComplaint?.title}</SheetTitle>
            <SheetDescription>
              {selectedComplaint?.block_name} - {selectedComplaint?.flat_number}
            </SheetDescription>
          </SheetHeader>

          {isLoadingDetails ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            </div>
          ) : complaintDetails && (
            <div className="space-y-6 mt-6">
              {/* Status & Actions */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-muted-foreground">Status:</span>
                  <Badge className={cn(
                    STATUS_CONFIG[complaintDetails.status]?.bg,
                    STATUS_CONFIG[complaintDetails.status]?.color,
                    'border-0'
                  )}>
                    {complaintDetails.status.replace('_', ' ')}
                  </Badge>
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="outline" size="sm">
                      Change Status
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent>
                    {Object.keys(STATUS_CONFIG).map((status) => (
                      <DropdownMenuItem
                        key={status}
                        onClick={() => handleStatusChange(complaintDetails.id, status)}
                        disabled={status === complaintDetails.status}
                      >
                        {status.replace('_', ' ')}
                      </DropdownMenuItem>
                    ))}
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>

              {/* Details */}
              <div className="space-y-3">
                <div>
                  <Label className="text-muted-foreground">Description</Label>
                  <p className="mt-1">{complaintDetails.description || 'No description provided'}</p>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-muted-foreground">Category</Label>
                    <p className="mt-1 capitalize">{complaintDetails.category}</p>
                  </div>
                  <div>
                    <Label className="text-muted-foreground">Priority</Label>
                    <p className="mt-1 capitalize">{complaintDetails.priority}</p>
                  </div>
                </div>
                <div>
                  <Label className="text-muted-foreground">Submitted by</Label>
                  <div className="mt-1 flex items-center gap-2">
                    <Avatar className="h-8 w-8">
                      <AvatarFallback>
                        {getInitials(complaintDetails.submitted_by_name)}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <p className="font-medium">{complaintDetails.submitted_by_name}</p>
                      <p className="text-sm text-muted-foreground">
                        {complaintDetails.submitted_by_phone}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Comments */}
              <div>
                <Label className="text-muted-foreground mb-3 block">
                  Comments ({complaintDetails.comments?.length || 0})
                </Label>
                <div className="space-y-3 max-h-[200px] overflow-y-auto">
                  {complaintDetails.comments?.map((comment) => (
                    <div key={comment.id} className="rounded-lg bg-muted p-3">
                      <div className="flex items-center gap-2 mb-1">
                        <Avatar className="h-6 w-6">
                          <AvatarFallback className="text-xs">
                            {getInitials(comment.user_name)}
                          </AvatarFallback>
                        </Avatar>
                        <span className="text-sm font-medium">{comment.user_name}</span>
                        <span className="text-xs text-muted-foreground">
                          {formatRelativeTime(comment.created_at)}
                        </span>
                      </div>
                      <p className="text-sm">{comment.comment}</p>
                    </div>
                  ))}
                  {(!complaintDetails.comments || complaintDetails.comments.length === 0) && (
                    <p className="text-sm text-muted-foreground text-center py-4">
                      No comments yet
                    </p>
                  )}
                </div>

                {/* Add Comment Form */}
                <form onSubmit={handleAddComment} className="mt-4 flex gap-2">
                  <Input
                    placeholder="Add a comment..."
                    value={newComment}
                    onChange={(e) => setNewComment(e.target.value)}
                    className="flex-1"
                  />
                  <Button
                    type="submit"
                    size="icon"
                    disabled={!newComment.trim() || addCommentMutation.isPending}
                  >
                    {addCommentMutation.isPending ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Send className="h-4 w-4" />
                    )}
                  </Button>
                </form>
              </div>
            </div>
          )}
        </SheetContent>
      </Sheet>
    </div>
  );
}
