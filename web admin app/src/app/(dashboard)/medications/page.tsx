'use client';

import Link from 'next/link';
import { Eye, Users } from 'lucide-react';
import { useMedications } from '@/hooks/useMedications';
import PageHeader from '@/components/feedback/PageHeader';
import DataTable from '@/components/tables/DataTable';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { formatDate } from '@/lib/utils';
import type { Medication, MedicationForm } from '@/types';

const formBadgeVariants: Record<MedicationForm, 'info' | 'success' | 'secondary' | 'warning' | 'default' | 'destructive' | 'outline'> = {
  TABLET: 'info',
  CAPSULE: 'success',
  LIQUID: 'secondary',
  INJECTION: 'warning',
  CREAM: 'default',
  POWDER: 'destructive',
  OTHER: 'outline',
};

export default function MedicationsPage() {
  const { data, isLoading, error, refetch } = useMedications();

  const columns = [
    { key: 'id', header: 'ID', className: 'font-mono text-xs max-w-[120px] truncate' },
    { key: 'name', header: 'Name' },
    { key: 'dosage', header: 'Dosage' },
    {
      key: 'form',
      header: 'Form',
      render: (row: Medication) => (
        <Badge variant={formBadgeVariants[row.form]}>
          {row.form}
        </Badge>
      ),
    },
    { key: 'quantity', header: 'Quantity' },
    {
      key: 'expiryDate',
      header: 'Expiry Date',
      render: (row: Medication) => formatDate(row.expiryDate),
    },
    {
      key: 'createdAt',
      header: 'Created At',
      render: (row: Medication) => formatDate(row.createdAt),
    },
  ];

  return (
    <div>
      <PageHeader
        title="Medications"
        description="Medication inventory"
      />

      <DataTable<Medication>
        columns={columns}
        data={data?.data ?? []}
        loading={isLoading}
        error={error as Error | undefined}
        onRetry={() => refetch()}
        emptyTitle="No medications found."
        renderRowActions={(row) => (
          <>
            <Button asChild variant="ghost" size="sm">
              <Link href={`/medications/${row.id}`}>
                <Eye className="w-4 h-4 mr-1" />
                View
              </Link>
            </Button>
            <Button asChild variant="ghost" size="sm">
              <Link href={`/users`}>
                <Users className="w-4 h-4 mr-1" />
                Users
              </Link>
            </Button>
          </>
        )}
      />
    </div>
  );
}
