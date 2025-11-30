import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  Bell,
  Plus,
  MoreHorizontal,
  Edit,
  Trash2,
  Pin,
  Eye,
  AlertTriangle,
  Loader2,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
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
  SheetFooter,
} from '@/components/ui/sheet';
import { noticesApi } from '@/lib/api';
import { formatDate, formatRelativeTime, getPriorityColor, cn } from '@/lib/utils';
import useAuthStore from '@/stores/authStore';

export default function Notices() {
  const queryClient = useQueryClient();
  const { societies, hasRole } = useAuthStore();
  const societyId = societies[0]?.id;
  const isSuperAdmin = hasRole('super_admin');

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingNotice, setEditingNotice] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    body: '',
    priority: 'medium',
    is_pinned: false,
  });

  const { data, isLoading } = useQuery({
    queryKey: ['notices', societyId],
    queryFn: async () => {
      const params = isSuperAdmin ? {} : { society_id: societyId };
      const response = await noticesApi.getAll(params);
      return response.data;
    },
    enabled: isSuperAdmin || !!societyId,
  });

  const createMutation = useMutation({
    mutationFn: (data) => noticesApi.create({ ...data, society_id: societyId }),
    onSuccess: () => {
      queryClient.invalidateQueries(['notices']);
      setIsCreateOpen(false);
      resetForm();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => noticesApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries(['notices']);
      setEditingNotice(null);
      resetForm();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => noticesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries(['notices']);
    },
  });

  const resetForm = () => {
    setFormData({ title: '', body: '', priority: 'medium', is_pinned: false });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (editingNotice) {
      updateMutation.mutate({ id: editingNotice.id, data: formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  const openEditSheet = (notice) => {
    setFormData({
      title: notice.title,
      body: notice.body || '',
      priority: notice.priority,
      is_pinned: notice.is_pinned,
    });
    setEditingNotice(notice);
  };

  const getPriorityBadgeVariant = (priority) => {
    switch (priority) {
      case 'critical':
        return 'destructive';
      case 'high':
        return 'warning';
      case 'medium':
        return 'info';
      default:
        return 'secondary';
    }
  };

  const notices = data?.data || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">Notices</h1>
          <p className="text-muted-foreground">
            Manage society announcements and updates
          </p>
        </div>
        <Button onClick={() => setIsCreateOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Post Notice
        </Button>
      </div>

      {/* Notices List */}
      {isLoading ? (
        <div className="space-y-4">
          {[...Array(3)].map((_, i) => (
            <Card key={i}>
              <CardContent className="p-6">
                <div className="animate-pulse space-y-3">
                  <div className="h-5 w-48 bg-muted rounded" />
                  <div className="h-4 w-full bg-muted rounded" />
                  <div className="h-4 w-3/4 bg-muted rounded" />
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : notices.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <Bell className="h-16 w-16 text-muted-foreground/20 mb-4" />
            <p className="text-lg font-medium">No notices yet</p>
            <p className="text-muted-foreground mb-4">
              Post your first announcement to residents
            </p>
            <Button onClick={() => setIsCreateOpen(true)}>
              <Plus className="mr-2 h-4 w-4" />
              Post Notice
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {notices.map((notice) => (
            <Card
              key={notice.id}
              className={cn(
                'transition-all',
                notice.is_pinned && 'border-primary/50 bg-primary/5'
              )}
            >
              <CardContent className="p-4 md:p-6">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex flex-wrap items-center gap-2 mb-2">
                      {notice.is_pinned && (
                        <Pin className="h-4 w-4 text-primary" />
                      )}
                      <h3 className="font-semibold text-lg">{notice.title}</h3>
                      <Badge variant={getPriorityBadgeVariant(notice.priority)}>
                        {notice.priority}
                      </Badge>
                    </div>
                    {notice.body && (
                      <p className="text-muted-foreground mb-3 line-clamp-2">
                        {notice.body}
                      </p>
                    )}
                    <div className="flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
                      <span>{formatRelativeTime(notice.created_at)}</span>
                      {notice.created_by_name && (
                        <span>by {notice.created_by_name}</span>
                      )}
                      {notice.society_name && isSuperAdmin && (
                        <Badge variant="outline">{notice.society_name}</Badge>
                      )}
                      <span className="flex items-center gap-1">
                        <Eye className="h-3 w-3" />
                        {notice.read_count || 0} reads
                      </span>
                    </div>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon-sm">
                        <MoreHorizontal className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem onClick={() => openEditSheet(notice)}>
                        <Edit className="mr-2 h-4 w-4" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        className="text-destructive"
                        onClick={() => deleteMutation.mutate(notice.id)}
                      >
                        <Trash2 className="mr-2 h-4 w-4" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Create/Edit Sheet */}
      <Sheet
        open={isCreateOpen || !!editingNotice}
        onOpenChange={(open) => {
          if (!open) {
            setIsCreateOpen(false);
            setEditingNotice(null);
            resetForm();
          }
        }}
      >
        <SheetContent className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>
              {editingNotice ? 'Edit Notice' : 'Post New Notice'}
            </SheetTitle>
            <SheetDescription>
              {editingNotice
                ? 'Update the notice details'
                : 'Create a new announcement for residents'}
            </SheetDescription>
          </SheetHeader>

          <form onSubmit={handleSubmit} className="space-y-4 mt-6">
            <div className="space-y-2">
              <Label htmlFor="title">Title *</Label>
              <Input
                id="title"
                placeholder="Notice title"
                value={formData.title}
                onChange={(e) =>
                  setFormData((prev) => ({ ...prev, title: e.target.value }))
                }
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="body">Message</Label>
              <textarea
                id="body"
                className="flex min-h-[120px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                placeholder="Notice details..."
                value={formData.body}
                onChange={(e) =>
                  setFormData((prev) => ({ ...prev, body: e.target.value }))
                }
              />
            </div>

            <div className="space-y-2">
              <Label>Priority</Label>
              <div className="flex flex-wrap gap-2">
                {['low', 'medium', 'high', 'critical'].map((priority) => (
                  <Button
                    key={priority}
                    type="button"
                    variant={formData.priority === priority ? 'default' : 'outline'}
                    size="sm"
                    onClick={() =>
                      setFormData((prev) => ({ ...prev, priority }))
                    }
                  >
                    {priority}
                  </Button>
                ))}
              </div>
            </div>

            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="is_pinned"
                checked={formData.is_pinned}
                onChange={(e) =>
                  setFormData((prev) => ({ ...prev, is_pinned: e.target.checked }))
                }
                className="h-4 w-4 rounded border-gray-300"
              />
              <Label htmlFor="is_pinned" className="font-normal">
                Pin this notice to the top
              </Label>
            </div>

            <SheetFooter className="mt-6">
              <Button
                type="submit"
                disabled={createMutation.isPending || updateMutation.isPending}
                className="w-full"
              >
                {createMutation.isPending || updateMutation.isPending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    {editingNotice ? 'Updating...' : 'Posting...'}
                  </>
                ) : editingNotice ? (
                  'Update Notice'
                ) : (
                  'Post Notice'
                )}
              </Button>
            </SheetFooter>
          </form>
        </SheetContent>
      </Sheet>
    </div>
  );
}
