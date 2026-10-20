'use client';

import Link from 'next/link';
import { ArrowRight, Info, Eye, ShieldCheck } from 'lucide-react';
import PageHeader from '@/components/feedback/PageHeader';
import DataTable from '@/components/tables/DataTable';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useAdminDrawerMedications } from '@/hooks/useDrawerMedications';
import { formatDateTime, cn } from '@/lib/utils';
import type { DrawerMedication } from '@/types';

function truncateId(id: string, length: number = 8): string {
  if (id.length <= length) return id;
  const start = id.slice(0, Math.floor(length / 2) - 1);
  const end = id.slice(-Math.ceil(length / 2) + 1);
  return `${start}...${end}`;
}

export default function DrawerMedicationsPage() {
  const { data, isLoading, error, refetch } = useAdminDrawerMedications();

  const columns = [
    {
      key: 'id',
      header: 'Assignment ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: DrawerMedication) => (
        <span
          className="font-mono text-xs truncate block max-w-[140px]"
          title={row.id}
        >
          {truncateId(row.id, 12)}
        </span>
      ),
    },
    {
      key: 'drawerId',
      header: 'Drawer ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: DrawerMedication) => (
        <Link
          href={`/drawers/${row.drawerId}`}
          className={cn(
            'font-mono text-xs truncate block max-w-[140px] text-primary hover:underline'
          )}
          title={row.drawerId}
        >
          {truncateId(row.drawerId, 12)}
        </Link>
      ),
    },
    {
      key: 'medicationId',
      header: 'Medication ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: DrawerMedication) => (
        <span
          className="font-mono text-xs truncate block max-w-[140px]"
          title={row.medicationId}
        >
          {truncateId(row.medicationId, 12)}
        </span>
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
    {
      key: 'isActive',
      header: 'Active',
      render: (row: DrawerMedication) =>
        row.isActive ? (
          <Badge
            variant="outline"
            className="bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800 gap-1"
          >
            <svg
              className="h-3 w-3"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={3}
                d="M5 13l4 4L19 7"
              />
            </svg>
            Active
          </Badge>
        ) : (
          <Badge variant="secondary">Inactive</Badge>
        ),
    },
    {
      key: 'createdAt',
      header: 'Created At',
      render: (row: DrawerMedication) => (
        <span className="text-sm text-muted-foreground">
          {formatDateTime(row.createdAt)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Drawer Assignments"
        description="Read-only view of medication-to-drawer assignments (admin)"
      />

      <Card className="border-blue-200 bg-blue-50/50 dark:border-blue-800/50 dark:bg-blue-950/20">
        <CardContent className="py-4 px-5">
          <div className="flex items-start gap-3">
            <div className="rounded-full bg-blue-100 dark:bg-blue-900/50 p-2 shrink-0">
              <ShieldCheck className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <div className="flex-1 pt-0.5">
              <p className="text-sm font-medium text-blue-800 dark:text-blue-300 flex items-center gap-2">
                <Info className="h-4 w-4" />
                Admin Read-Only Access
              </p>
              <p className="text-sm text-blue-700 dark:text-blue-400 mt-1">
                Admin accounts have read-only access. Create/edit/delete are
                user-only operations.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      <DataTable
        columns={columns}
        data={data ?? []}
        loading={isLoading}
        error={error as Error | string | undefined}
        onRetry={refetch}
        emptyTitle="No drawer assignments found"
        emptyDescription="Medication-to-drawer assignments will appear here once created by users."
        renderRowActions={(row: DrawerMedication) => (
          <Button asChild variant="ghost" size="sm" className="h-8 gap-1">
            <Link href={`/drawer-medications/${row.id}`}>
              <Eye className="h-3.5 w-3.5" />
              View
            </Link>
          </Button>
        )}
      />
    </div>
  );
}
