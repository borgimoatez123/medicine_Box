'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { Plus, Package, Search, Eye, RefreshCw, Copy, Check, XCircle } from 'lucide-react';
import {
  useAdminMedicineBoxes,
  useCreateMedicineBox,
  useProvisionDrawers,
} from '@/hooks/useMedicineBoxes';
import { useAdminDrawers } from '@/hooks/useDrawers';
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
import {
  Card,
  CardContent,
} from '@/components/ui/card';
import { formatDateTime, cn } from '@/lib/utils';
import type { MedicineBox, MedicineBoxStatus } from '@/types';
import ProvisionQrCode from '@/components/qr/ProvisionQrCode';
import { useQrTempStore } from '@/components/qr/ProvisionQrTempStore';
import { toast } from 'sonner';

const DEVICE_ID_PREFIX = 'DEV-BOX-';
const DEVICE_ID_RANDOM_LENGTH = 7;
const DEVICE_TOKEN_BYTE_LENGTH = 32;

const ALPHANUMERIC =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function randomAlphanumeric(length: number): string {
  if (
    typeof crypto !== 'undefined' &&
    typeof crypto.getRandomValues === 'function'
  ) {
    const values = crypto.getRandomValues(new Uint8Array(length));
    let out = '';
    for (let i = 0; i < length; i++) {
      out += ALPHANUMERIC[values[i] % ALPHANUMERIC.length];
    }
    return out;
  }
  let out = '';
  for (let i = 0; i < length; i++) {
    out += ALPHANUMERIC[Math.floor(Math.random() * ALPHANUMERIC.length)];
  }
  return out;
}

function generateDeviceId(): string {
  return `${DEVICE_ID_PREFIX}${randomAlphanumeric(DEVICE_ID_RANDOM_LENGTH)}`;
}

function generateDeviceToken(): string {
  if (
    typeof crypto !== 'undefined' &&
    typeof crypto.getRandomValues === 'function'
  ) {
    const raw = crypto.getRandomValues(
      new Uint8Array(DEVICE_TOKEN_BYTE_LENGTH),
    );
    let out = '';
    for (let i = 0; i < raw.length; i++) {
      out += raw[i].toString(16).padStart(2, '0');
    }
    return out;
  }
  return randomAlphanumeric(DEVICE_TOKEN_BYTE_LENGTH * 2);
}

const provisionSchema = z.object({
  deviceId: z
    .string()
    .regex(
      /^DEV-BOX-[A-Za-z0-9]{7}$/,
      'Device ID must be auto-generated format DEV-BOX-XXXXXXX',
    ),
  deviceToken: z
    .string()
    .min(32, 'Device Token must be at least 32 characters (auto-generated)'),
  name: z.string().min(1, 'Name is required'),
  numberOfDrawers: z.coerce.number().int().min(1, 'Minimum 1 drawer'),
  drawerCapacity: z.coerce.number().int().min(1, 'Minimum capacity of 1'),
});

type ProvisionFormValues = z.infer<typeof provisionSchema>;

function buildFreshProvisionDefaults(): ProvisionFormValues {
  return {
    deviceId: generateDeviceId(),
    deviceToken: generateDeviceToken(),
    name: '',
    numberOfDrawers: 4,
    drawerCapacity: 20,
  };
}

function getStatusBadgeVariant(status: MedicineBoxStatus) {
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

interface ProvisionSuccessState {
  medicineBoxId: string;
  deviceId: string;
  deviceToken: string;
  status: MedicineBoxStatus;
  numberOfDrawers: number;
  drawerCapacity: number;
}

export default function MedicineBoxesPage() {
  const router = useRouter();
  const qrStore = useQrTempStore();
  const [searchTerm, setSearchTerm] = useState('');
  const [provisionDialogOpen, setProvisionDialogOpen] = useState(false);
  const [successState, setSuccessState] = useState<ProvisionSuccessState | null>(null);
  const [copiedToken, setCopiedToken] = useState(false);

  const {
    data: medicineBoxes,
    isLoading,
    error,
    refetch,
  } = useAdminMedicineBoxes();
  const { data: drawers } = useAdminDrawers();
  const createMutation = useCreateMedicineBox();
  const provisionDrawersMutation = useProvisionDrawers();

  const form = useForm<ProvisionFormValues>({
    resolver: zodResolver(provisionSchema),
    defaultValues: buildFreshProvisionDefaults(),
  });

  const regenerateDeviceId = () => form.setValue('deviceId', generateDeviceId(), { shouldDirty: true, shouldTouch: true, shouldValidate: true });
  const regenerateDeviceToken = () => {
    setCopiedToken(false);
    form.setValue('deviceToken', generateDeviceToken(), { shouldDirty: true, shouldTouch: true, shouldValidate: true });
  };

  const filteredBoxes = (medicineBoxes ?? []).filter((box) => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    return (
      box.deviceId.toLowerCase().includes(term) ||
      box.name.toLowerCase().includes(term) ||
      (box.userId?.toLowerCase() ?? '').includes(term)
    );
  });

  function copyDeviceTokenToClipboard() {
    const value = form.getValues('deviceToken');
    if (!value) return;
    setCopiedToken(false);
    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(value).then(() => {
        setCopiedToken(true);
        window.setTimeout(() => setCopiedToken(false), 1800);
      }, () => {});
    }
  }

  function closeProvisioningFlow() {
    setSuccessState(null);
    form.reset(buildFreshProvisionDefaults());
    setCopiedToken(false);
    setProvisionDialogOpen(false);
  }

  function viewMedicineBoxDetails() {
    if (!successState) return;
    qrStore.setPayload({
      medicineBoxId: successState.medicineBoxId,
      deviceId: successState.deviceId,
      deviceToken: successState.deviceToken,
    });
    const target = successState.medicineBoxId;
    const deviceTokenCopies = {
      id: successState.deviceId,
      token: successState.deviceToken,
    };
    void deviceTokenCopies;
    router.push(`/medicine-boxes/${target}`);
  }

  async function onProvisionSubmit(values: ProvisionFormValues) {
    try {
      const created = await createMutation.mutateAsync({
        deviceId: values.deviceId,
        deviceToken: values.deviceToken,
        name: values.name,
        numberOfDrawers: values.numberOfDrawers,
        drawerCapacity: values.drawerCapacity,
      });
      setSuccessState({
        medicineBoxId: created.id,
        deviceId: values.deviceId,
        deviceToken: values.deviceToken,
        status: (created.status as MedicineBoxStatus) ?? 'REGISTERED',
        numberOfDrawers: created.numberOfDrawers,
        drawerCapacity: created.drawerCapacity,
      });
      toast.success('Medicine Box provisioned successfully');
    } catch (err: any) {
      const statusCode: number | undefined =
        err?.statusCode ?? err?.status;
      if (statusCode === 409) {
        toast.error('Duplicate device ID. Please regenerate and try again.');
      } else if (statusCode === 403) {
        toast.error('Administrator access required.');
      } else if (statusCode === 400) {
        toast.error(
          err?.message ?? 'Validation error. Review the form and try again.',
        );
      } else if (statusCode === 500) {
        toast.error('Server error. Please try again later.');
      }
    }
  }

  const columns = [
    {
      key: 'deviceId',
      header: 'Device ID',
      render: (row: MedicineBox) => (
        <span className="font-mono text-xs">{row.deviceId}</span>
      ),
    },
    {
      key: 'name',
      header: 'Name',
    },
    {
      key: 'status',
      header: 'Status',
      render: (row: MedicineBox) => (
        <Badge variant={getStatusBadgeVariant(row.status)}>{row.status}</Badge>
      ),
    },
    {
      key: 'userId',
      header: 'User ID',
      render: (row: MedicineBox) =>
        row.userId ? (
          <span className="font-mono text-xs">{row.userId}</span>
        ) : (
          <span className="text-muted-foreground">Unassigned</span>
        ),
    },
    {
      key: 'numberOfDrawers',
      header: '# Drawers',
      render: (row: MedicineBox) => {
        const actualDrawers =
          drawers?.filter((d) => d.medicineBoxId === row.id).length ?? 0;
        return (
          <span>
            {actualDrawers}/{row.numberOfDrawers}
          </span>
        );
      },
    },
    {
      key: 'drawerCapacity',
      header: 'Capacity',
    },
    {
      key: 'createdAt',
      header: 'Created At',
      render: (row: MedicineBox) => formatDateTime(row.createdAt),
    },
    {
      key: 'updatedAt',
      header: 'Updated At',
      render: (row: MedicineBox) => formatDateTime(row.updatedAt),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Medicine Boxes"
        description="Provision and manage smart medicine dispenser devices"
      >
        <Dialog
          open={provisionDialogOpen}
          onOpenChange={(open) => {
            if (open) {
              form.reset(buildFreshProvisionDefaults());
              setSuccessState(null);
              setCopiedToken(false);
            } else {
              setSuccessState(null);
              setCopiedToken(false);
            }
            setProvisionDialogOpen(open);
          }}
        >
          <DialogTrigger asChild>
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Provision Device
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-3xl">
            {!successState ? (
              <>
                <DialogHeader>
                  <DialogTitle>Provision New Device</DialogTitle>
                  <DialogDescription>
                    Register a new smart medicine dispenser. Device ID and token are
                    auto-generated securely for each new device.
                  </DialogDescription>
                </DialogHeader>
                <Form {...form}>
                  <form
                    onSubmit={form.handleSubmit(onProvisionSubmit)}
                    className="space-y-4"
                  >
                    <FormField
                      control={form.control}
                      name="deviceId"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Device ID</FormLabel>
                          <div className="flex gap-2">
                            <FormControl className="flex-1">
                              <Input
                                placeholder={generateDeviceId()}
                                readOnly
                                className={cn(
                                  'font-mono text-xs bg-slate-50 dark:bg-slate-900 cursor-default',
                                )}
                                {...field}
                              />
                            </FormControl>
                            <Button
                              type="button"
                              variant="outline"
                              size="icon"
                              onClick={regenerateDeviceId}
                              title="Regenerate Device ID"
                              tabIndex={-1}
                            >
                              <RefreshCw className="w-4 h-4" />
                            </Button>
                          </div>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="deviceToken"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Device Token</FormLabel>
                          <div className="flex gap-2">
                            <FormControl className="flex-1">
                              <Input
                                type="password"
                                placeholder={generateDeviceToken()}
                                readOnly
                                className={cn(
                                  'font-mono text-xs bg-slate-50 dark:bg-slate-900 cursor-default pr-10',
                                )}
                                {...field}
                              />
                            </FormControl>
                            <Button
                              type="button"
                              variant="outline"
                              size="icon"
                              onClick={copyDeviceTokenToClipboard}
                              title={copiedToken ? 'Copied!' : 'Copy token'}
                              tabIndex={-1}
                            >
                              {copiedToken ? (
                                <Check className="w-4 h-4 text-green-600 dark:text-green-400" />
                              ) : (
                                <Copy className="w-4 h-4" />
                              )}
                            </Button>
                            <Button
                              type="button"
                              variant="outline"
                              size="icon"
                              onClick={regenerateDeviceToken}
                              title="Regenerate Device Token"
                              tabIndex={-1}
                            >
                              <RefreshCw className="w-4 h-4" />
                            </Button>
                          </div>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="name"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Name</FormLabel>
                          <FormControl>
                            <Input
                              placeholder="Living Room Dispenser"
                              autoFocus
                              {...field}
                            />
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
                        onClick={() => {
                          setProvisionDialogOpen(false);
                          form.reset(buildFreshProvisionDefaults());
                          setCopiedToken(false);
                        }}
                      >
                        Cancel
                      </Button>
                      <Button
                        type="submit"
                        disabled={createMutation.isPending}
                      >
                        {createMutation.isPending
                          ? 'Provisioning...'
                          : 'Provision Device'}
                      </Button>
                    </DialogFooter>
                  </form>
                </Form>
              </>
            ) : (
              <div className="space-y-6">
                <DialogHeader>
                  <DialogTitle className="text-emerald-700 dark:text-emerald-400">
                    Medicine Box provisioned successfully
                  </DialogTitle>
                  <DialogDescription>
                    Scan the QR code below with the mobile/device application to
                    complete the device activation.
                  </DialogDescription>
                </DialogHeader>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-start">
                  <ProvisionQrCode
                    deviceId={successState.deviceId}
                    deviceToken={successState.deviceToken}
                    size={256}
                  />
                  <Card>
                    <CardContent className="p-6 space-y-3">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-medium text-muted-foreground">
                          Device ID
                        </span>
                        <span className="font-mono text-xs">
                          {successState.deviceId}
                        </span>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-medium text-muted-foreground">
                          Status
                        </span>
                        <Badge
                          variant={getStatusBadgeVariant(successState.status)}
                        >
                          {successState.status}
                        </Badge>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-medium text-muted-foreground">
                          Number of drawers
                        </span>
                        <span className="text-sm">
                          {successState.numberOfDrawers}
                        </span>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-medium text-muted-foreground">
                          Drawer capacity
                        </span>
                        <span className="text-sm">
                          {successState.drawerCapacity}
                        </span>
                      </div>
                      <div className="pt-2 border-t flex items-start gap-2 rounded-lg bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-900 p-3">
                        <XCircle className="w-4 h-4 text-amber-600 dark:text-amber-400 mt-0.5 shrink-0" />
                        <p className="text-xs text-amber-800 dark:text-amber-200">
                          This is the only time the device token is available in
                          plaintext. Download or print the QR code before closing.
                        </p>
                      </div>
                    </CardContent>
                  </Card>
                </div>
                <DialogFooter>
                  <Button
                    type="button"
                    variant="ghost"
                    onClick={closeProvisioningFlow}
                  >
                    Close
                  </Button>
                  <Button type="button" onClick={viewMedicineBoxDetails}>
                    View Medicine Box Details
                  </Button>
                </DialogFooter>
              </div>
            )}
          </DialogContent>
        </Dialog>
      </PageHeader>

      <div className="mb-4">
        <div className="relative max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search devices..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      <DataTable
        columns={columns}
        data={filteredBoxes}
        loading={isLoading}
        error={error ? String(error) : undefined}
        onRetry={refetch}
        emptyTitle="No medicine boxes found"
        emptyDescription="Provision your first smart medicine dispenser device to get started."
        renderRowActions={(row: MedicineBox) => (
          <>
            <Button asChild variant="ghost" size="icon">
              <Link href={`/medicine-boxes/${row.id}`}>
                <Eye className="h-4 w-4" />
              </Link>
            </Button>
          </>
        )}
      />
    </div>
  );
}
