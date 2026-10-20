'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import {
  Edit2, Box, ArrowLeft, LayoutGrid, AlertTriangle, LockKeyhole } from 'lucide-react';
import {
  useAdminMedicineBoxById,
  useUpdateAdminMedicineBox,
  useProvisionDrawers,
} from '@/hooks/useMedicineBoxes';
import { useAdminDrawers } from '@/hooks/useDrawers';
import PageHeader from '@/components/feedback/PageHeader';
import LoadingState from '@/components/feedback/LoadingState';
import ErrorState from '@/components/feedback/ErrorState';
import EmptyState from '@/components/feedback/EmptyState';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { cn, formatDateTime } from '@/lib/utils';
import type { MedicineBoxStatus, DrawerStatus } from '@/types';
import ProvisionQrCode from '@/components/qr/ProvisionQrCode';
import { useQrTempStore } from '@/components/qr/ProvisionQrTempStore';

const updateBoxSchema = z.object({
  name: z.string().min(1, 'Name is required').optional(),
  numberOfDrawers: z.coerce
    .number()
    .int()
    .min(1, 'Minimum 1 drawer')
    .optional(),
  drawerCapacity: z.coerce
    .number()
    .int()
    .min(1, 'Minimum capacity of 1')
    .optional(),
});

type UpdateBoxFormValues = z.infer<typeof updateBoxSchema>;

function getBoxStatusBadgeVariant(status: MedicineBoxStatus) {
  switch (status) {
    case 'REGISTERED':
      return 'default';
    case 'ACTIVE':
      return 'secondary';
    case 'OFFLINE':
      return 'destructive';
    case 'MAINTENANCE':
      return 'outline';
    default:
      return 'default';
  }
}

function getBoxStatusColor(status: MedicineBoxStatus) {
  switch (status) {
    case 'REGISTERED':
      return 'bg-amber-500';
    case 'ACTIVE':
      return 'bg-green-500';
    case 'OFFLINE':
      return 'bg-red-500';
    case 'MAINTENANCE':
      return 'bg-slate-500';
    default:
      return 'bg-slate-400';
  }
}

function getDrawerStatusBadgeVariant(status: DrawerStatus) {
  switch (status) {
    case 'EMPTY':
      return 'outline';
    case 'LOADED':
      return 'secondary';
    case 'LOCKED':
      return 'default';
    case 'DISPENSING':
      return 'default';
    case 'ERROR':
      return 'destructive';
    default:
      return 'default';
  }
}

export default function MedicineBoxDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const qrStore = useQrTempStore();
  const qrPayload = qrStore.getPayload(id);

  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [provisionDialogOpen, setProvisionDialogOpen] = useState(false);

  const {
    data: medicineBox,
    isLoading,
    error,
    refetch,
  } = useAdminMedicineBoxById(id);
  const { data: drawers, isLoading: drawersLoading } = useAdminDrawers();
  const updateMutation = useUpdateAdminMedicineBox(id);
  const provisionDrawersMutation = useProvisionDrawers();

  const form = useForm<UpdateBoxFormValues>({
    resolver: zodResolver(updateBoxSchema),
    defaultValues: {
      name: medicineBox?.name ?? '',
      numberOfDrawers: medicineBox?.numberOfDrawers,
      drawerCapacity: medicineBox?.drawerCapacity,
    },
  });

  const boxDrawers = drawers
    ? drawers.filter((d) => d.medicineBoxId === id)
    : [];
  const actualDrawerCount = boxDrawers.length;
  const expectedDrawerCount = medicineBox?.numberOfDrawers ?? 0;
  const needsProvisioning = actualDrawerCount < expectedDrawerCount;

  function openEditDialog() {
    form.reset({
      name: medicineBox?.name ?? '',
      numberOfDrawers: medicineBox?.numberOfDrawers,
      drawerCapacity: medicineBox?.drawerCapacity,
    });
    setEditDialogOpen(true);
  }

  async function onEditSubmit(values: UpdateBoxFormValues) {
    try {
      await updateMutation.mutateAsync({
        ...(values.name !== undefined ? { name: values.name } : {}),
        ...(values.numberOfDrawers !== undefined
          ? { numberOfDrawers: values.numberOfDrawers }
          : {}),
        ...(values.drawerCapacity !== undefined
          ? { drawerCapacity: values.drawerCapacity }
          : {}),
      });
      setEditDialogOpen(false);
    } catch {
    }
  }

  async function onProvisionDrawers() {
    try {
      await provisionDrawersMutation.mutateAsync(id);
      setProvisionDialogOpen(false);
    } catch {
    }
  }

  if (isLoading) {
    return (
      <div className="space-y-6">
      <PageHeader
        title="Medicine Box Details"
        description="View and manage medicine dispenser device information"
      >
        <Button variant="ghost" asChild>
          <Link href="/medicine-boxes">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back
          </Link>
        </Button>
      </PageHeader>
        <LoadingState count={6} />
      </div>
    );
  }

  if (error || !medicineBox) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Medicine Box Details"
          description="View and manage medicine dispenser device information"
        >
          <Button variant="ghost" asChild>
            <Link href="/medicine-boxes">
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back
            </Link>
          </Button>
        </PageHeader>
        <ErrorState
          error={error ?? 'Medicine box not found'}
          onRetry={refetch}
        />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Medicine Box Details"
        description="View and manage medicine dispenser device information"
      >
        <div className="flex items-center gap-2">
          <Button variant="ghost" asChild>
            <Link href="/medicine-boxes">
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back
            </Link>
          </Button>
          <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
            <DialogTrigger asChild>
              <Button variant="outline" onClick={openEditDialog}>
                <Edit2 className="w-4 h-4 mr-2" />
                Edit
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Edit Medicine Box</DialogTitle>
                <DialogDescription>
                  Update the medicine box configuration.
                </DialogDescription>
              </DialogHeader>
              <Form {...form}>
                <form
                  onSubmit={form.handleSubmit(onEditSubmit)}
                  className="space-y-4"
                >
                  <FormField
                    control={form.control}
                    name="name"
                    render={({ field }) => (
                    <FormItem>
                      <FormLabel>Name</FormLabel>
                      <FormControl>
                        <Input placeholder="Device name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                  />
                  <div className="grid grid-cols-2 gap-4">
                    <FormField
                      control={form.control}
                      name="numberOfDrawers"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Number of Drawers</FormLabel>
                          <FormControl>
                            <Input type="number" min={1} {...field} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="drawerCapacity"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Drawer Capacity</FormLabel>
                          <FormControl>
                            <Input type="number" min={1} {...field} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>
                  <DialogFooter>
                    <Button
                      type="button"
                      variant="ghost"
                      onClick={() => setEditDialogOpen(false)}
                    >
                      Cancel
                    </Button>
                    <Button type="submit" disabled={updateMutation.isPending}>
                      {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
                    </Button>
                  </DialogFooter>
                </form>
              </Form>
            </DialogContent>
          </Dialog>
          {needsProvisioning && (
            <Dialog
              open={provisionDialogOpen}
              onOpenChange={setProvisionDialogOpen}
            >
              <DialogTrigger asChild>
                <Button>
                  <LayoutGrid className="w-4 h-4 mr-2" />
                  Provision Drawers
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Provision Drawers</DialogTitle>
                  <DialogDescription>
                    This will create {expectedDrawerCount - actualDrawerCount}{' '}
                    missing drawer records for this medicine box.
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button
                    type="button"
                    variant="ghost"
                    onClick={() => setProvisionDialogOpen(false)}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={onProvisionDrawers}
                    disabled={provisionDrawersMutation.isPending}
                  >
                    {provisionDrawersMutation.isPending
                      ? 'Provisioning...'
                      : 'Provision Drawers'}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          )}
        </div>
      </PageHeader>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
            <Box className="w-5 h-5" />
            Device Details
          </CardTitle>
            <CardDescription>
              Device configuration and status
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">
                Device ID
              </p>
              <p className="font-mono text-sm">{medicineBox.deviceId}</p>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">Name</p>
              <p className="text-sm font-medium">{medicineBox.name}</p>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">Status</p>
              <div className="flex items-center gap-2">
                <span
                  className={cn(
                    'h-2 w-2 rounded-full',
                    getBoxStatusColor(medicineBox.status)
                  )}
                />
                <Badge variant={getBoxStatusBadgeVariant(medicineBox.status)}>
                  {medicineBox.status}
                </Badge>
              </div>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">User</p>
              <p className="text-sm">
                {medicineBox.userId ? (
                  <span className="font-mono text-xs">
                  {medicineBox.userId}
                </span>
                ) : (
                  <span className="text-muted-foreground">Unassigned</span>
                )}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">
                Number of Drawers
              </p>
              <p className="text-sm">{medicineBox.numberOfDrawers}</p>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">
                Drawer Capacity
              </p>
              <p className="text-sm">{medicineBox.drawerCapacity} pills</p>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">
                Created At
              </p>
              <p className="text-sm">
                {formatDateTime(medicineBox.createdAt)}
              </p>
            </div>
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground font-medium">
                Updated At
              </p>
              <p className="text-sm">
                {formatDateTime(medicineBox.updatedAt)}
              </p>
            </div>
          </CardContent>
        </Card>

        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Box className="w-5 h-5" />
              Device QR Code
            </CardTitle>
            <CardDescription>
              Scanned by the mobile app to activate the device.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {qrPayload && qrPayload.deviceId && qrPayload.deviceToken ? (
              <ProvisionQrCode
                deviceId={qrPayload.deviceId}
                deviceToken={qrPayload.deviceToken}
                size={224}
              />
            ) : (
              <div className="flex flex-col items-start gap-3 rounded-lg border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/40 p-5">
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-full bg-amber-100 dark:bg-amber-950/60 text-amber-700 dark:text-amber-300">
                    <LockKeyhole className="w-5 h-5" />
                  </div>
                  <div className="space-y-1">
                    <p className="text-sm font-semibold text-slate-900 dark:text-slate-100">
                      QR code is unavailable.
                    </p>
                    <p className="text-xs text-muted-foreground leading-relaxed">
                      The device token is only available during initial
                      provisioning. Re-provision the device if you need a new
                      QR code.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="lg:col-span-3 xl:col-span-1">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <LayoutGrid className="w-5 h-5" />
                  Drawers ({actualDrawerCount} of {expectedDrawerCount}{' '}
                  provisioned
                </CardTitle>
                <CardDescription>
                  Individual drawer compartments and their status
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            {needsProvisioning && (
            <div className="flex items-start gap-3 p-4 rounded-lg bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-900">
              <AlertTriangle className="w-5 h-5 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
              <div className="flex-1">
                <p className="text-sm font-medium text-amber-800 dark:text-amber-200">
                  Drawers not fully provisioned
                </p>
                <p className="text-sm text-amber-700 dark:text-amber-300 mt-1">
                  {expectedDrawerCount - actualDrawerCount} drawer
                  {expectedDrawerCount - actualDrawerCount === 1 ? '' : 's'}{' '}
                  still need to be created.
                </p>
              </div>
              <Button
                size="sm"
                onClick={() => setProvisionDialogOpen(true)}
              >
                <LayoutGrid className="w-4 h-4 mr-2" />
                Provision Now
              </Button>
            </div>
          )}

            {drawersLoading ? (
              <LoadingState count={4} />
            ) : actualDrawerCount === 0 ? (
              <EmptyState
                title="No drawers provisioned"
                description="Provision drawers to start managing medication storage."
                icon={LayoutGrid}
                action={
                  needsProvisioning
                    ? {
                        label: 'Provision Drawers',
                        onClick: () => setProvisionDialogOpen(true),
                      }
                    : undefined
                }
              />
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-2 gap-4">
                {boxDrawers
                  .sort((a, b) => a.drawerNumber - b.drawerNumber)
                  .map((drawer) => (
                    <Card
                      key={drawer.id}
                      className="hover:shadow-md transition-shadow"
                    >
                      <CardContent className="p-4 space-y-3">
                        <div className="flex items-center justify-between">
                          <p className="font-semibold text-sm">
                            Drawer {drawer.drawerNumber}
                          </p>
                          <Badge
                            variant={getDrawerStatusBadgeVariant(drawer.status)}
                          >
                            {drawer.status}
                          </Badge>
                        </div>
                        <div className="space-y-1">
                          <p className="text-xs text-muted-foreground">ID</p>
                          <p className="font-mono text-xs truncate">
                            {drawer.id.slice(0, 8)}...
                          </p>
                        </div>
                        <div className="space-y-1">
                          <p className="text-xs text-muted-foreground">
                            Created
                          </p>
                          <p className="text-xs">
                            {formatDateTime(drawer.createdAt)}
                          </p>
                        </div>
                        <Button asChild variant="outline" size="sm" className="w-full">
                          <Link href={`/drawers/${drawer.id}`}>Update</Link>
                        </Button>
                      </CardContent>
                    </Card>
                  ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
