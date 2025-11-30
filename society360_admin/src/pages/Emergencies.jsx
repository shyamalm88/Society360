import React, { useEffect, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  AlertTriangle,
  Phone,
  MapPin,
  Clock,
  CheckCircle,
  Volume2,
  VolumeX,
  RefreshCw,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { formatRelativeTime, formatDateTime, getInitials, cn } from '@/lib/utils';
import useAuthStore from '@/stores/authStore';
import { io } from 'socket.io-client';
import api from '@/lib/api';

export default function Emergencies() {
  const queryClient = useQueryClient();
  const { societies } = useAuthStore();
  const societyId = societies[0]?.id;
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [socket, setSocket] = useState(null);

  // Fetch emergencies
  const { data: emergencies, isLoading, error, refetch } = useQuery({
    queryKey: ['emergencies', societyId],
    queryFn: async () => {
      const response = await api.get('/admin/emergencies', {
        params: { society_id: societyId },
      });
      return response.data.data || [];
    },
    enabled: !!societyId,
    refetchInterval: (query) => (query.state.error ? false : 10000), // Stop refetching on error
    retry: 1,
  });

  // Resolve emergency mutation
  const resolveMutation = useMutation({
    mutationFn: async (id) => {
      return api.put(`/admin/emergencies/${id}/resolve`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['emergencies']);
    },
  });

  // Setup Socket.io for real-time alerts
  useEffect(() => {
    if (!societyId) return;

    const socketUrl = import.meta.env.VITE_SOCKET_URL || 'http://localhost:3000';
    const newSocket = io(socketUrl, {
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 3,
      reconnectionDelay: 5000,
      timeout: 10000,
    });

    newSocket.on('connect', () => {
      console.log('Emergency socket connected');
      newSocket.emit('join_room', {
        room_type: 'society',
        room_id: societyId,
      });
    });

    newSocket.on('connect_error', (err) => {
      console.log('Emergency socket connection error:', err.message);
    });

    newSocket.on('emergency_alert', (data) => {
      // Play alert sound
      if (soundEnabled) {
        try {
          const audio = new Audio('/alert-sound.mp3');
          audio.play().catch(() => {});
        } catch (e) {
          // Ignore audio errors
        }
      }
      // Refetch emergencies
      refetch();
    });

    setSocket(newSocket);

    return () => {
      newSocket.disconnect();
    };
  }, [societyId, soundEnabled]);

  const activeEmergencies = emergencies?.filter((e) => !e.resolved_at) || [];
  const resolvedEmergencies = emergencies?.filter((e) => e.resolved_at) || [];

  if (!societyId) {
    return (
      <div className="flex flex-col items-center justify-center py-12">
        <AlertTriangle className="h-12 w-12 text-muted-foreground/20 mb-4" />
        <p className="text-lg font-medium">No Society Assigned</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl flex items-center gap-2">
            <AlertTriangle className="h-8 w-8 text-destructive" />
            Emergencies
          </h1>
          <p className="text-muted-foreground">
            Monitor and respond to panic alerts
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={() => setSoundEnabled(!soundEnabled)}
            title={soundEnabled ? 'Mute alerts' : 'Enable sound'}
          >
            {soundEnabled ? (
              <Volume2 className="h-4 w-4" />
            ) : (
              <VolumeX className="h-4 w-4 text-muted-foreground" />
            )}
          </Button>
          <Button variant="outline" size="icon" onClick={() => refetch()}>
            <RefreshCw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Active Emergencies */}
      {activeEmergencies.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-lg font-semibold flex items-center gap-2 text-destructive">
            <span className="relative flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
            </span>
            Active Alerts ({activeEmergencies.length})
          </h2>

          <div className="grid gap-4 md:grid-cols-2">
            {activeEmergencies.map((emergency) => (
              <Card
                key={emergency.id}
                className="border-destructive bg-destructive/5 panic-alert"
              >
                <CardContent className="p-4">
                  <div className="flex items-start gap-4">
                    <div className="flex h-12 w-12 items-center justify-center rounded-full bg-destructive text-white">
                      <AlertTriangle className="h-6 w-6" />
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-2">
                        <Badge variant="destructive" className="text-sm">
                          PANIC ALERT
                        </Badge>
                        <span className="text-sm text-muted-foreground">
                          {formatRelativeTime(emergency.created_at)}
                        </span>
                      </div>

                      <div className="space-y-2">
                        <div className="flex items-center gap-2">
                          <Avatar className="h-8 w-8">
                            <AvatarFallback className="bg-destructive/20 text-destructive">
                              {getInitials(emergency.reported_by_name)}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <p className="font-semibold">{emergency.reported_by_name}</p>
                            {emergency.reported_by_phone && (
                              <a
                                href={`tel:${emergency.reported_by_phone}`}
                                className="flex items-center gap-1 text-sm text-primary hover:underline"
                              >
                                <Phone className="h-3 w-3" />
                                {emergency.reported_by_phone}
                              </a>
                            )}
                          </div>
                        </div>

                        <div className="flex items-center gap-1 text-sm">
                          <MapPin className="h-4 w-4 text-muted-foreground" />
                          <span>
                            {emergency.block_name} - {emergency.flat_number}
                          </span>
                        </div>

                        {emergency.message && (
                          <p className="text-sm bg-white/50 rounded p-2">
                            {emergency.message}
                          </p>
                        )}
                      </div>

                      <Button
                        className="mt-4 w-full"
                        variant="default"
                        onClick={() => resolveMutation.mutate(emergency.id)}
                        disabled={resolveMutation.isPending}
                      >
                        <CheckCircle className="mr-2 h-4 w-4" />
                        Mark as Resolved
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* No Active Emergencies */}
      {activeEmergencies.length === 0 && (
        <Card className="border-green-200 bg-green-50">
          <CardContent className="flex flex-col items-center justify-center py-12">
            <CheckCircle className="h-16 w-16 text-green-500 mb-4" />
            <p className="text-lg font-medium text-green-700">All Clear</p>
            <p className="text-green-600">No active emergency alerts</p>
          </CardContent>
        </Card>
      )}

      {/* Resolved Emergencies */}
      {resolvedEmergencies.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-lg font-semibold text-muted-foreground">
            Recently Resolved
          </h2>

          <div className="space-y-3">
            {resolvedEmergencies.slice(0, 5).map((emergency) => (
              <Card key={emergency.id} className="bg-muted/30">
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 items-center justify-center rounded-full bg-green-100">
                        <CheckCircle className="h-5 w-5 text-green-600" />
                      </div>
                      <div>
                        <p className="font-medium">{emergency.reported_by_name}</p>
                        <p className="text-sm text-muted-foreground">
                          {emergency.block_name} - {emergency.flat_number}
                        </p>
                      </div>
                    </div>
                    <div className="text-right text-sm text-muted-foreground">
                      <p>Reported: {formatDateTime(emergency.created_at)}</p>
                      <p>Resolved: {formatDateTime(emergency.resolved_at)}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="space-y-4">
          {[...Array(2)].map((_, i) => (
            <Card key={i}>
              <CardContent className="p-6">
                <div className="animate-pulse flex items-center gap-4">
                  <div className="h-12 w-12 bg-muted rounded-full" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-32 bg-muted rounded" />
                    <div className="h-3 w-48 bg-muted rounded" />
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
