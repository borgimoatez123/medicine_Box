'use client';

import { Check, X } from 'lucide-react';
import { useSchedules } from '@/hooks/useSchedules';
import PageHeader from '@/components/feedback/PageHeader';
import DataTable from '@/components/tables/DataTable';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/utils';
import type { Schedule, ScheduleStatus } from '@/types';

const statusBadgeVariants: Record<ScheduleStatus, 'success' | 'warning' | 'secondary' | 'default'> = {
  ACTIVE: 'success',
  PAUSED: 'warning',
  COMPLETED: 'secondary',
  ARCHIVED: 'default',
};

export default function SchedulesPage() {
  const { data, isLoading, error, refetch } = useSchedules();

  const columns = [
    { key: 'id', header: 'ID', className: 'font-mono text-xs max-w-[120px] truncate' },
    {
      key: 'medicationId',
      header: 'Medication ID',
      className: 'font-mono text-xs max-w-[140px]',
      render: (row: Schedule) => (
        <span className="truncate inline-block max-w-[140px]" title={row.medicationId}>
          {row.medicationId}
        </span>
      ),
    },
    { key: 'dosage', header: 'Dosage' },
    {
      key: 'times',
      header: 'Times',
      render: (row: Schedule) => (row.times && row.times.length > 0 ? row.times.join(', ') : '-'),
    },
    {
      key: 'daysOfWeek',
      header: 'Days',
      render: (row: Schedule) => {
        if (!row.daysOfWeek || row.daysOfWeek.length === 0) return '-';
        const dayAbbrs = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return row.daysOfWeek
          .map((d) => (d >= 1 && d <= 7 ? dayAbbrs[d - 1] : '-'))
          .join(', ');
      },
    },
    {
      key: 'startDate',
      header: 'Start Date',
      render: (row: Schedule) => formatDate(row.startDate),
    },
    {
      key: 'endDate',
      header: 'End Date',
      render: (row: Schedule) => formatDate(row.endDate),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row: Schedule) => (
        <Badge variant={statusBadgeVariants[row.status]}>
          {row.status}
        </Badge>
      ),
    },
    {
      key: 'isActive',
      header: 'isActive',
      render: (row: Schedule) =>
        row.isActive ? (
          <Badge variant="info" className="gap-1">
            <Check className="w-3 h-3" />
            Active
          </Badge>
        ) : (
          <Badge variant="secondary" className="gap-1 text-muted-foreground">
            <X className="w-3 h-3" />
            Inactive
          </Badge>
        ),
    },
  ];

  return (
    <div>
      <PageHeader
        title="Schedules"
        description="Medication administration schedules"
      />

      <DataTable<Schedule>
        columns={columns}
        data={data?.data ?? []}
        loading={isLoading}
        error={error as Error | undefined}
        onRetry={() => refetch()}
        emptyTitle="No schedules found."
      />
    </div>
  );
}
