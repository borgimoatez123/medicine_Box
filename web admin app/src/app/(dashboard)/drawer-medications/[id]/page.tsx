'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  ArrowLeft,
  ArrowRight,
  Box,
  Package,
  Pill,
  User,
  UserCircle,
  ShieldAlert,
  Calendar,
} from 'lucide-react';
import PageHeader from '@/components/feedback/PageHeader';
import LoadingState from '@/components/feedback/LoadingState';
import ErrorState from '@/components/feedback/ErrorState';
import EmptyState from '@/components/feedback/EmptyState';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useAdminDrawerMedicationById } from '@/hooks/useDrawerMedications';
import { useAdminDrawerById } from '@/hooks/useDrawers';
import { useAdminMedicineBoxById } from '@/hooks/useMedicineBoxes';
import { useMedicationById } from '@/hooks/useMedications';
import { formatDateTime, cn } from '@/lib/utils';
import type { DrawerStatus, MedicineBoxStatus } from '@/types';

function getDrawerStatusVariant(status: DrawerStatus): string {
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

function getBoxStatusVariant(status: MedicineBoxStatus): string {
  switch (status) {
    case 'REGISTERED':
      return 'bg-slate-100 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700';
    case 'ACTIVE':
      return 'bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800';
    case 'OFFLINE':
      return 'bg-slate-500/10 text-slate-600 border-slate-300 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700';
    case 'MAINTENANCE':
      return 'bg-amber-100 text-amber-700 border-amber-200 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-800';
    default:
      return '';
  }
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

function ResourceFallback({
  resourceName,
  id,
  reason,
}: {
  resourceName: string;
  id: string;
  reason: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex items-center gap-2">
        <span className="font-mono text-xs break-all">{id}</span>
      </div>
      <p className="text-xs text-muted-foreground flex items-center gap-1">
        <ShieldAlert className="h-3 w-3" />
        {resourceName} {reason}
      </p>
    </div>
  );
}

export default function DrawerMedicationDetailPage() {
  const params = useParams<{ id: string }>();
  const assignmentId = params?.id as string;

  const {
    data: assignment,
    isLoading: assignmentLoading,
    error: assignmentError,
    refetch: assignmentRefetch,
  } = useAdminDrawerMedicationById(assignmentId);

  const drawerId = assignment?.drawerId ?? '';
  const medicationId = assignment?.medicationId ?? '';

  const {
    data: drawer,
    isLoading: drawerLoading,
    error: drawerError,
  } = useAdminDrawerById(drawerId);

  const medicineBoxId = drawer?.medicineBoxId ?? '';
  const {
    data: medicineBox,
    isLoading: boxLoading,
    error: boxError,
  } = useAdminMedicineBoxById(medicineBoxId);

  const {
    data: medication,
    isLoading: medicationLoading,
    error: medicationError,
  } = useMedicationById(medicationId);

  const patientId = medication?.patientId;

  if (assignmentLoading) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="Drawer Assignment Details"
          description="Loading assignment information..."
        >
          <Button asChild variant="outline" size="sm">
            <Link href="/drawer-medications">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Assignments
            </Link>
          </Button>
        </PageHeader>
        <LoadingState count={5} />
      </div>
    );
  }

  if (assignmentError) {
    return (
      <div className="space-y-6">
        <PageHeader title="Drawer Assignment Details">
          <Button asChild variant="outline" size="sm">
            <Link href="/drawer-medications">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Assignments
            </Link>
          </Button>
        </PageHeader>
        <ErrorState
          error={assignmentError as Error | string}
          onRetry={assignmentRefetch}
        />
      </div>
    );
  }

  if (!assignment) {
    return (
      <div className="space-y-6">
        <PageHeader title="Drawer Assignment Details">
          <Button asChild variant="outline" size="sm">
            <Link href="/drawer-medications">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Assignments
            </Link>
          </Button>
        </PageHeader>
        <EmptyState
          title="Assignment not found"
          description="The requested drawer medication assignment could not be located."
          action={{ label: 'Back to Assignments', href: '/drawer-medications' }}
        />
      </div>
    );
  }

  const anyRelatedMissing =
    drawerError || boxError || medicationError;

  return (
    <div className="space-y-6">
      <PageHeader title="Drawer Assignment Details">
        <Button asChild variant="outline" size="sm">
          <Link href="/drawer-medications">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Assignments
          </Link>
        </Button>
      </PageHeader>

      {anyRelatedMissing && (
        <Card className="border-amber-200 bg-amber-50/50 dark:border-amber-800/50 dark:bg-amber-950/20">
          <CardContent className="py-4 px-5">
            <div className="flex items-start gap-3">
              <div className="rounded-full bg-amber-100 dark:bg-amber-900/50 p-2 shrink-0">
                <ShieldAlert className="h-4 w-4 text-amber-600 dark:text-amber-400" />
              </div>
              <div className="flex-1 pt-0.5">
                <p className="text-sm font-medium text-amber-800 dark:text-amber-300">
                  Restricted Resource Access
                </p>
                <p className="text-sm text-amber-700 dark:text-amber-400 mt-1">
                  Some related resources may be empty or return 404 due to admin
                  restricted access. Ownership boundaries apply to user-created
                  resources (medications, patients, user accounts).
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Calendar className="h-5 w-5 text-primary" />
              Assignment
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            <DetailRow
              label="Assignment ID"
              value={<span className="font-mono text-xs">{assignment.id}</span>}
            />
            <Separator />
            <DetailRow
              label="Status"
              value={
                assignment.isActive ? (
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
                )
              }
            />
            <Separator />
            <DetailRow
              label="Assigned At"
              value={
                <span className="text-muted-foreground">
                  {formatDateTime(assignment.assignedAt)}
                </span>
              }
            />
            <Separator />
            <DetailRow
              label="Created At"
              value={
                <span className="text-muted-foreground">
                  {formatDateTime(assignment.createdAt)}
                </span>
              }
            />
            <Separator />
            <DetailRow
              label="Updated At"
              value={
                <span className="text-muted-foreground">
                  {formatDateTime(assignment.updatedAt)}
                </span>
              }
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Box className="h-5 w-5 text-primary" />
              Drawer
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {drawerLoading ? (
              <LoadingState count={2} />
            ) : drawerError || !drawer ? (
              <ResourceFallback
                resourceName="Drawer"
                id={assignment.drawerId}
                reason="could not be loaded (admin access restrictions or missing)"
              />
            ) : (
              <>
                <DetailRow
                  label="Drawer ID"
                  value={
                    <Link
                      href={`/drawers/${drawer.id}`}
                      className="font-mono text-xs inline-flex items-center gap-1 text-primary hover:underline"
                    >
                      {drawer.id}
                      <ArrowRight className="h-3 w-3" />
                    </Link>
                  }
                />
                <Separator />
                <DetailRow
                  label="Drawer Number"
                  value={
                    <Badge variant="secondary" className="font-mono">
                      #{drawer.drawerNumber}
                    </Badge>
                  }
                />
                <Separator />
                <DetailRow
                  label="Status"
                  value={
                    <Badge
                      variant="outline"
                      className={cn(getDrawerStatusVariant(drawer.status))}
                    >
                      {drawer.status}
                    </Badge>
                  }
                />
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Package className="h-5 w-5 text-primary" />
              Medicine Box
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {!drawer ? (
              <ResourceFallback
                resourceName="Medicine Box"
                id={medicineBoxId || '—'}
                reason="requires drawer data first (link missing from drawer)"
              />
            ) : boxLoading ? (
              <LoadingState count={2} />
            ) : boxError || !medicineBox ? (
              <ResourceFallback
                resourceName="Medicine Box"
                id={drawer.medicineBoxId}
                reason="could not be loaded (admin access restrictions or missing)"
              />
            ) : (
              <>
                <DetailRow
                  label="Box ID"
                  value={
                    <Link
                      href={`/medicine-boxes/${medicineBox.id}`}
                      className="font-mono text-xs inline-flex items-center gap-1 text-primary hover:underline"
                    >
                      {medicineBox.id}
                      <ArrowRight className="h-3 w-3" />
                    </Link>
                  }
                />
                <Separator />
                <DetailRow label="Name" value={medicineBox.name} />
                <Separator />
                <DetailRow
                  label="Device ID"
                  value={
                    <span className="font-mono text-xs">
                      {medicineBox.deviceId}
                    </span>
                  }
                />
                <Separator />
                <DetailRow
                  label="Status"
                  value={
                    <Badge
                      variant="outline"
                      className={cn(getBoxStatusVariant(medicineBox.status))}
                    >
                      {medicineBox.status}
                    </Badge>
                  }
                />
                <Separator />
                <DetailRow
                  label="Drawers"
                  value={`${medicineBox.numberOfDrawers} total`}
                />
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Pill className="h-5 w-5 text-primary" />
              Medication
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {medicationLoading ? (
              <LoadingState count={3} />
            ) : medicationError || !medication ? (
              <ResourceFallback
                resourceName="Medication"
                id={assignment.medicationId}
                reason="not accessible (ownership restricted — admin cannot view user medications)"
              />
            ) : (
              <>
                <DetailRow
                  label="Medication ID"
                  value={
                    <span className="font-mono text-xs">{medication.id}</span>
                  }
                />
                <Separator />
                <DetailRow label="Name" value={medication.name} />
                <Separator />
                <DetailRow label="Dosage" value={medication.dosage} />
                <Separator />
                <DetailRow label="Form" value={medication.form} />
                <Separator />
                <DetailRow
                  label="Quantity"
                  value={medication.quantity.toString()}
                />
                {medication.expiryDate && (
                  <>
                    <Separator />
                    <DetailRow
                      label="Expiry"
                      value={formatDateTime(medication.expiryDate)}
                    />
                  </>
                )}
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <User className="h-5 w-5 text-primary" />
              Patient
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {!medication ? (
              <ResourceFallback
                resourceName="Patient"
                id="—"
                reason="requires medication data first (patient link unavailable)"
              />
            ) : !patientId ? (
              <ResourceFallback
                resourceName="Patient"
                id="—"
                reason="has no patient ID associated with this medication"
              />
            ) : (
              <ResourceFallback
                resourceName="Patient"
                id={patientId}
                reason="ownership-restricted (admin cannot view patient details)"
              />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <UserCircle className="h-5 w-5 text-primary" />
              Owner / User
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {!medicineBox ? (
              <ResourceFallback
                resourceName="User"
                id="—"
                reason="requires medicine box data first (ownership unavailable)"
              />
            ) : !medicineBox.userId ? (
              <ResourceFallback
                resourceName="User"
                id="—"
                reason="is not assigned to any user account"
              />
            ) : (
              <ResourceFallback
                resourceName="User"
                id={medicineBox.userId}
                reason="ownership-restricted (admin cannot view user account details)"
              />
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
