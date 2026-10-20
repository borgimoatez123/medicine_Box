'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { ArrowRight, Search, Edit3, Loader2 } from 'lucide-react';
import PageHeader from '@/components/feedback/PageHeader';
import DataTable from '@/components/tables/DataTable';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
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
import { useAdminDrawers, useUpdateAdminDrawer } from '@/hooks/useDrawers';
import { formatDateTime, cn } from '@/lib/utils';
import type { Drawer, DrawerStatus } from '@/types';

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

function truncateId(id: string, length: number = 8): string {
  if (id.length <= length) return id;
  const start = id.slice(0, Math.floor(length / 2) - 1);
  const end = id.slice(-Math.ceil(length / 2) + 1);
  return `${start}...${end}`;
}

function UpdateStatusDialog({ drawer }: { drawer: Drawer }) {
  const [open, setOpen] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<DrawerStatus>(drawer.status);
  const updateMutation = useUpdateAdminDrawer(drawer.id);

  const handleSubmit = async () => {
    await updateMutation.mutateAsync({ status: selectedStatus });
    setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
          <Edit3 className="h-4 w-4" />
          <span className="sr-only">Edit Status</span>
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Update Drawer Status</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <Label htmlFor={`status-select-${drawer.id}`}>Drawer Status</Label>
            <Select
              value={selectedStatus}
              onValueChange={(v) => setSelectedStatus(v as DrawerStatus)}
            >
              <SelectTrigger id={`status-select-${drawer.id}`}>
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
          <div className="text-sm text-muted-foreground">
            Drawer #{drawer.drawerNumber} (ID: {truncateId(drawer.id)})
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
          <Button onClick={handleSubmit} disabled={updateMutation.isPending}>
            {updateMutation.isPending && (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            )}
            Save Changes
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export default function DrawersPage() {
  const { data, isLoading, error, refetch } = useAdminDrawers();
  const [searchTerm, setSearchTerm] = useState('');

  const filteredData = useMemo(() => {
    if (!data) return [];
    if (!searchTerm.trim()) return data;
    const term = searchTerm.toLowerCase().trim();
    return data.filter(
      (d) =>
        d.id.toLowerCase().includes(term) ||
        d.medicineBoxId.toLowerCase().includes(term) ||
        d.drawerNumber.toString().includes(term)
    );
  }, [data, searchTerm]);

  const columns = [
    {
      key: 'id',
      header: 'ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: Drawer) => (
        <span className="font-mono text-xs truncate block max-w-[140px]" title={row.id}>
          {truncateId(row.id, 12)}
        </span>
      ),
    },
    {
      key: 'medicineBoxId',
      header: 'Medicine Box ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: Drawer) => (
        <span className="font-mono text-xs truncate block max-w-[140px]" title={row.medicineBoxId}>
          {truncateId(row.medicineBoxId, 12)}
        </span>
      ),
    },
    {
      key: 'drawerNumber',
      header: 'Drawer Number',
      render: (row: Drawer) => (
        <Badge variant="secondary" className="font-mono">
          #{row.drawerNumber}
        </Badge>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row: Drawer) => <StatusBadge status={row.status} />,
    },
    {
      key: 'createdAt',
      header: 'Created At',
      render: (row: Drawer) => (
        <span className="text-sm text-muted-foreground">
          {formatDateTime(row.createdAt)}
        </span>
      ),
    },
    {
      key: 'updatedAt',
      header: 'Updated At',
      render: (row: Drawer) => (
        <span className="text-sm text-muted-foreground">
          {formatDateTime(row.updatedAt)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Drawers"
        description="Monitor and manage drawer inventory"
      >
        <div className="relative w-full max-w-sm">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            type="text"
            placeholder="Search by drawer ID, box ID, number..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-8"
          />
        </div>
      </PageHeader>

      <DataTable
        columns={columns}
        data={filteredData}
        loading={isLoading}
        error={error as Error | string | undefined}
        onRetry={refetch}
        emptyTitle="No drawers found"
        emptyDescription={
          searchTerm
            ? 'Try adjusting your search filters.'
            : 'Drawers will appear here once medicine boxes are provisioned.'
        }
        renderRowActions={(row: Drawer) => (
          <>
            <Button asChild variant="ghost" size="sm" className="h-8 gap-1">
              <Link href={`/drawers/${row.id}`}>
                Details
                <ArrowRight className="h-3.5 w-3.5" />
              </Link>
            </Button>
            <UpdateStatusDialog drawer={row} />
          </>
        )}
      />
    </div>
  );
}
