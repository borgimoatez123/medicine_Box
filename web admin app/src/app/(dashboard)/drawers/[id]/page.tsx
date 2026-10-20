'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft, ArrowRight, Edit3, Loader2, Pill, AlertTriangle } from 'lucide-react';
import PageHeader from '@/components/feedback/PageHeader';
import LoadingState from '@/components/feedback/LoadingState';
import ErrorState from '@/components/feedback/ErrorState';
import EmptyState from '@/components/feedback/EmptyState';
import DataTable from '@/components/tables/DataTable';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import {
  useAdminDrawerById,
  useUpdateAdminDrawer,
} from '@/hooks/useDrawers';
import { useAdminDrawerMedications } from '@/hooks/useDrawerMedications';
import { formatDateTime, cn } from '@/lib/utils';
import type { DrawerStatus, DrawerMedication } from '@/types';

const DRAWER_STATUS_OPTIONS: DrawerStatus[] = [
  'EMPTY',
  'LOADED',
  'LOCKED',
  'DISPENSING',
  'ERROR',
];

function getStatusBadgeVariant(status: DrawerStatus): string {
  switch (status) {
    case 'EMPTY':
      return 'bg-slate-100 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700';
    case 'LOADED':
      return 'bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800';
    case 'LOCKED':
      return 'bg-amber-100 text-amber-700 border-amber-200 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-800';
    case 'DISPENSING':
      return 'bg-blue-100 text-blue-700 border-blue-200 dark:bg-blue-900/30 dark:text-blue-400 dark:border-blue-800';
    case 'ERROR':
      return 'bg-red-100 text-red-700 border-red-200 dark:bg-red-900/30 dark:text-red-400 dark:border-red-800';
    default:
      return '';
  }
}

function StatusBadge({ status }: { status: DrawerStatus }) {
  return (
    <Badge variant="outline" className={cn(getStatusBadgeVariant(status))}>
      {status}
    </Badge>
  );
}

function DetailRow({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 py-3">
      <div className="text-sm font-medium text-muted-foreground">{label}</div>
      <div className="sm:col-span-2 text-sm break-words">{value}</div>
    </div>
  );
}

export default function DrawerDetailPage() {
  const params = useParams<{ id: string }>();
  const drawerId = params?.id as string;

  const { data: drawer, isLoading, error, refetch } = useAdminDrawerById(drawerId);
  const {
    data: allAssignments,
    isLoading: assignmentsLoading,
  } = useAdminDrawerMedications();

  const relatedAssignments: DrawerMedication[] = allAssignments
    ? allAssignments.filter((a) => a.drawerId === drawerId)
    : [];

  const [open, setOpen] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<DrawerStatus | undefined>(
    drawer?.status
  );
  const updateMutation = useUpdateAdminDrawer(drawerId);

  const handleOpenChange = (nextOpen: boolean) => {
    setOpen(nextOpen);
    if (nextOpen && drawer) {
      setSelectedStatus(drawer.status);
    }
  };

  const handleSubmit = async () => {
    if (!selectedStatus) return;
    await updateMutation.mutateAsync({ status: selectedStatus });
    setOpen(false);
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Drawer Details"
          description="Loading drawer information..."
        >
          <Button asChild variant="outline" size="sm">
            <Link href="/drawers">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Drawers
            </Link>
          </Button>
        </PageHeader>
        <LoadingState count={4} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-6">
        <PageHeader title="Drawer Details">
          <Button asChild variant="outline" size="sm">
            <Link href="/drawers">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Drawers
            </Link>
          </Button>
        </PageHeader>
        <ErrorState error={error as Error | string} onRetry={refetch} />
      </div>
    );
  }

  if (!drawer) {
    return (
      <div className="space-y-6">
        <PageHeader title="Drawer Details">
          <Button asChild variant="outline" size="sm">
            <Link href="/drawers">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Drawers
            </Link>
          </Button>
        </PageHeader>
        <EmptyState
          title="Drawer not found"
          description="The requested drawer could not be located."
          action={{ label: 'Back to Drawers', href: '/drawers' }}
        />
      </div>
    );
  }

  const assignmentColumns = [
    {
      key: 'id',
      header: 'Assignment ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: DrawerMedication) => (
        <span
          className="font-mono text-xs truncate block max-w-[140px]"
          title={row.id}
        >
          {row.id.slice(0, 4)}...{row.id.slice(-4)}
        </span>
      ),
    },
    {
      key: 'medicationId',
      header: 'Medication ID',
      className: 'font-mono text-xs',
      render: (row: DrawerMedication) => (
        <span className="font-mono text-xs" title={row.medicationId}>
          {row.medicationId.slice(0, 4)}...{row.medicationId.slice(-4)}
        </span>
      ),
    },
    {
      key: 'isActive',
      header: 'Active',
      render: (row: DrawerMedication) =>
        row.isActive ? (
          <Badge
            variant="outline"
            className="bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800"
          >
            Active
          </Badge>
        ) : (
          <Badge variant="secondary">Inactive</Badge>
        ),
    },
    {
      key: 'assignedAt',
      header: 'Assigned At',
      render: (row: DrawerMedication) => (
        <span className="text-sm text-muted-foreground">
          {formatDateTime(row.assignedAt)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader title="Drawer Details">
        <Button asChild variant="outline" size="sm">
          <Link href="/drawers">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Drawers
          </Link>
        </Button>
      </PageHeader>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between space-y-0">
            <CardTitle className="text-xl">Drawer Information</CardTitle>
            <Dialog open={open} onOpenChange={handleOpenChange}>
              <DialogTrigger asChild>
                <Button variant="outline" size="sm">
                  <Edit3 className="mr-2 h-4 w-4" />
                  Edit Status
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Update Drawer Status</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 py-2">
                  <div className="space-y-2">
                    <Label htmlFor="status-select">Drawer Status</Label>
                    <Select
                      value={selectedStatus || drawer.status}
                      onValueChange={(v) =>
                        setSelectedStatus(v as DrawerStatus)
                      }
                    >
                      <SelectTrigger id="status-select">
                        <SelectValue placeholder="Select status" />
                      </SelectTrigger>
                      <SelectContent>
                        {DRAWER_STATUS_OPTIONS.map((s) => (
                          <SelectItem key={s} value={s}>
                            {s}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <DialogFooter>
                  <Button
                    variant="outline"
                    onClick={() => setOpen(false)}
                    disabled={updateMutation.isPending}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleSubmit}
                    disabled={updateMutation.isPending}
                  >
                    {updateMutation.isPending && (
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    )}
                    Save Changes
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </CardHeader>
          <CardContent className="space-y-1">
            <DetailRow label="ID" value={<span className="font-mono text-xs">{drawer.id}</span>} />
            <Separator />
            <DetailRow
              label="Medicine Box ID"
              value={
                <Link
                  href={`/medicine-boxes/${drawer.medicineBoxId}`}
                  className="font-mono text-xs inline-flex items-center gap-1 text-primary hover:underline"
                >
                  {drawer.medicineBoxId}
                  <ArrowRight className="h-3 w-3" />
                </Link>
              }
            />
            <Separator />
            <DetailRow
              label="Drawer Number"
              value={<Badge variant="secondary" className="font-mono">#{drawer.drawerNumber}</Badge>}
            />
            <Separator />
            <DetailRow label="Status" value={<StatusBadge status={drawer.status} />} />
            <Separator />
            <DetailRow
              label="Created At"
              value={<span className="text-muted-foreground">{formatDateTime(drawer.createdAt)}</span>}
            />
            <Separator />
            <DetailRow
              label="Updated At"
              value={<span className="text-muted-foreground">{formatDateTime(drawer.updatedAt)}</span>}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-amber-500" />
              Quick Actions
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <p className="text-muted-foreground">
              Use admin tools with caution. Drawer state changes may affect
              dispensing behavior for assigned medications.
            </p>
            <div className="pt-2 space-y-2">
              <Button
                asChild
                variant="outline"
                className="w-full justify-start"
              >
                <Link href={`/medicine-boxes/${drawer.medicineBoxId}`}>
                  View Medicine Box
                  <ArrowRight className="ml-auto h-4 w-4" />
                </Link>
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-xl flex items-center gap-2">
            <Pill className="h-5 w-5" />
            Related Drawer Medications
          </CardTitle>
        </CardHeader>
        <CardContent>
          <DataTable
            columns={assignmentColumns}
            data={relatedAssignments}
            loading={assignmentsLoading}
            emptyTitle="No medication assignments"
            emptyDescription="This drawer has no active medication assignments yet."
            renderRowActions={(row: DrawerMedication) => (
              <Button asChild variant="ghost" size="sm" className="h-8 gap-1">
                <Link href={`/drawer-medications/${row.id}`}>
                  View
                  <ArrowRight className="h-3.5 w-3.5" />
                </Link>
              </Button>
            )}
          />
        </CardContent>
      </Card>
    </div>
  );
}
