import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  Building2,
  Users,
  Home,
  Plus,
  MoreHorizontal,
  Settings,
  Eye,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { societiesApi } from '@/lib/api';
import { formatDate } from '@/lib/utils';

export default function Societies() {
  const { data: societies, isLoading, error } = useQuery({
    queryKey: ['societies'],
    queryFn: async () => {
      const response = await societiesApi.getAll();
      return response.data.data;
    },
  });

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div className="animate-pulse">
            <div className="h-8 w-32 bg-muted rounded mb-2" />
            <div className="h-4 w-48 bg-muted rounded" />
          </div>
        </div>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {[...Array(6)].map((_, i) => (
            <Card key={i}>
              <CardContent className="p-6">
                <div className="animate-pulse space-y-4">
                  <div className="h-10 w-10 bg-muted rounded-lg" />
                  <div className="h-5 w-32 bg-muted rounded" />
                  <div className="h-4 w-24 bg-muted rounded" />
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">Societies</h1>
          <p className="text-muted-foreground">
            Manage all onboarded societies
          </p>
        </div>
        <Button asChild>
          <Link to="/societies/new">
            <Plus className="mr-2 h-4 w-4" />
            Onboard Society
          </Link>
        </Button>
      </div>

      {/* Societies Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {societies?.map((society) => (
          <Card key={society.id} className="group hover:shadow-md transition-shadow">
            <CardHeader className="pb-3">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary/10">
                    {society.logo_url ? (
                      <img
                        src={society.logo_url}
                        alt={society.name}
                        className="h-10 w-10 rounded object-cover"
                      />
                    ) : (
                      <Building2 className="h-6 w-6 text-primary" />
                    )}
                  </div>
                  <div>
                    <CardTitle className="text-lg">{society.name}</CardTitle>
                    <CardDescription>{society.city}</CardDescription>
                  </div>
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-sm">
                      <MoreHorizontal className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem>
                      <Eye className="mr-2 h-4 w-4" />
                      View Details
                    </DropdownMenuItem>
                    <DropdownMenuItem>
                      <Settings className="mr-2 h-4 w-4" />
                      Settings
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-3 gap-4 text-center">
                <div className="rounded-lg bg-muted/50 p-2">
                  <div className="flex items-center justify-center gap-1 text-muted-foreground">
                    <Home className="h-3 w-3" />
                    <span className="text-xs">Blocks</span>
                  </div>
                  <p className="text-lg font-semibold">{society.block_count || 0}</p>
                </div>
                <div className="rounded-lg bg-muted/50 p-2">
                  <div className="flex items-center justify-center gap-1 text-muted-foreground">
                    <Home className="h-3 w-3" />
                    <span className="text-xs">Flats</span>
                  </div>
                  <p className="text-lg font-semibold">{society.flat_count || 0}</p>
                </div>
                <div className="rounded-lg bg-muted/50 p-2">
                  <div className="flex items-center justify-center gap-1 text-muted-foreground">
                    <Users className="h-3 w-3" />
                    <span className="text-xs">Residents</span>
                  </div>
                  <p className="text-lg font-semibold">{society.resident_count || 0}</p>
                </div>
              </div>
              <div className="mt-4 flex items-center justify-between text-sm">
                <Badge variant="secondary">
                  {formatDate(society.created_at)}
                </Badge>
                <span className="text-muted-foreground">
                  {society.address?.substring(0, 30)}...
                </span>
              </div>
            </CardContent>
          </Card>
        ))}

        {/* Empty state */}
        {societies?.length === 0 && (
          <Card className="md:col-span-2 lg:col-span-3">
            <CardContent className="flex flex-col items-center justify-center py-12">
              <Building2 className="h-16 w-16 text-muted-foreground/20 mb-4" />
              <p className="text-lg font-medium">No societies onboarded</p>
              <p className="text-muted-foreground mb-4">
                Get started by onboarding your first society
              </p>
              <Button asChild>
                <Link to="/societies/new">
                  <Plus className="mr-2 h-4 w-4" />
                  Onboard Society
                </Link>
              </Button>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
