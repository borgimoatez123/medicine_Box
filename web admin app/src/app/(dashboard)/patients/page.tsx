'use client';

import Link from 'next/link';
import { ShieldAlert, Eye } from 'lucide-react';
import { usePatients } from '@/hooks/usePatients';
import PageHeader from '@/components/feedback/PageHeader';
import DataTable from '@/components/tables/DataTable';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { formatDate } from '@/lib/utils';
import type { Patient } from '@/types';

export default function PatientsPage() {
  const { data, isLoading, error, refetch } = usePatients();

  const columns = [
    { key: 'id', header: 'ID', className: 'font-mono text-xs max-w-[120px] truncate' },
    { key: 'fullName', header: 'Full Name' },
    {
      key: 'dateOfBirth',
      header: 'Date of Birth',
      render: (row: Patient) => formatDate(row.dateOfBirth),
    },
    { key: 'gender', header: 'Gender' },
    {
      key: 'weightKg',
      header: 'Weight (kg)',
      render: (row: Patient) => row.weightKg ?? '-',
    },
    {
      key: 'heightCm',
      header: 'Height (cm)',
      render: (row: Patient) => row.heightCm ?? '-',
    },
    { key: 'bloodType', header: 'Blood Type' },
    {
      key: 'createdAt',
      header: 'Created At',
      render: (row: Patient) => formatDate(row.createdAt),
    },
  ];

  return (
    <div>
      <PageHeader
        title="Patients"
        description="Patient records (medical data privacy enforced by patient ownership"
      />

      <div className="border-amber-200 bg-amber-50 border rounded-lg p-4 mb-6">
        <div className="flex gap-3">
          <ShieldAlert className="w-6 h-6 text-amber-600 shrink-0 mt-0.5" />
          <div>
            <p className="font-bold text-amber-900">Medical Data Privacy Notice:</p>
            <p className="text-amber-800 text-sm mt-1">
              Per backend enforces strict ownership-based access control.
            </p>
            <p className="text-amber-800 text-sm">
              Admin accounts CANNOT access patient medical records of other users. This list displays patients owned by the currently authenticated admin user only.
            </p>
            <p className="text-amber-800 text-sm">
              The backend does NOT expose an admin-wide patients endpoint. Per medical privacy regulations.
            </p>
          </div>
        </div>
      </div>

      <DataTable<Patient>
        columns={columns}
        data={data?.data ?? []}
        loading={isLoading}
        error={error as Error | undefined}
        onRetry={() => refetch()}
        emptyTitle="No patients found for this account."
        renderRowActions={(row) => (
          <Button asChild variant="ghost" size="sm">
            <Link href={`/patients/${row.id}`}>
              <Eye className="w-4 h-4 mr-1" />
              View
            </Link>
          </Button>
        )}
      />
    </div>
  );
}
