'use client';

import { useUsers, useAdminMedicineBoxes, useAdminDrawers } from '@/hooks';
import PageHeader from '@/components/feedback/PageHeader';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { formatDate } from '@/lib/utils';
import type { MedicineBoxStatus, DrawerStatus } from '@/types';
import Link from 'next/link';
import {
  Users,
  Package,
  Boxes,
  LayoutGrid,
  Eye,
} from 'lucide-react';

const boxStatusBadge = (status: MedicineBoxStatus) => {
  const variantMap: Record<MedicineBoxStatus, string> = {
    ACTIVE: 'bg-green-500/15 text-green-700 dark:text-green-400 border-transparent',
    REGISTERED: 'bg-blue-500/15 text-blue-700 dark:text-blue-400 border-transparent',
    OFFLINE: 'bg-slate-500/15 text-slate-700 dark:text-slate-400 border-transparent',
    MAINTENANCE: 'bg-yellow-500/15 text-yellow-700 dark:text-yellow-400 border-transparent',
  };
  return (
    <Badge variant="outline" className={variantMap[status]}>
      {status}
    </Badge>
  );
};

const drawerStatusBadge = (status: DrawerStatus, count: number) => {
  const variantMap: Record<DrawerStatus, string> = {
    LOADED: 'bg-green-500/15 text-green-700 dark:text-green-400 border-transparent',
    EMPTY: 'bg-slate-500/15 text-slate-700 dark:text-slate-400 border-transparent',
    LOCKED: 'bg-blue-500/15 text-blue-700 dark:text-blue-400 border-transparent',
    DISPENSING: 'bg-purple-500/15 text-purple-700 dark:text-purple-400 border-transparent',
    ERROR: 'bg-red-500/15 text-red-700 dark:text-red-400 border-transparent',
  };
  return (
    <Badge variant="outline" className={variantMap[status]}>
      {status}: {count}
    </Badge>
  );
};

interface StatCardProps {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: number | undefined;
  isPending: boolean;
  iconBg?: string;
  iconColor?: string;
}

function StatCard({
  icon: Icon,
  label,
  value,
  isPending,
  iconBg = 'bg-primary/10',
  iconColor = 'text-primary',
}: StatCardProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <div className="text-sm font-medium text-muted-foreground">{label}</div>
        <div className={`rounded-full p-2 ${iconBg}`}>
          <Icon className={`h-4 w-4 ${iconColor}`} />
        </div>
      </CardHeader>
      <CardContent>
        {isPending ? (
          <Skeleton className="h-8 w-16" />
        ) : (
          <div className="text-2xl font-bold">{value ?? 0}</div>
        )}
      </CardContent>
    </Card>
  );
}

export default function DashboardPage() {
  const users = useUsers();
  const boxes = useAdminMedicineBoxes();
  const drawers = useAdminDrawers();

  const isAnyLoading = users.isPending || boxes.isPending || drawers.isPending;
  const hasAnyError = users.isError || boxes.isError || drawers.isError;

  const totalUsers = users.isError ? 0 : users.data?.length;
  const totalBoxes = boxes.isError ? 0 : boxes.data?.length;
  const activeBoxes = boxes.isError
    ? 0
    : boxes.data?.filter((b) => b.status === 'ACTIVE').length;
  const registeredBoxes = boxes.isError
    ? 0
    : boxes.data?.filter((b) => b.status === 'REGISTERED').length;
  const totalDrawers = drawers.isError ? 0 : drawers.data?.length;
  const activeDrawers = drawers.isError
    ? 0
    : drawers.data?.filter((d) => d.status === 'LOADED').length;

  const drawerStatusCounts = (drawers.data ?? []).reduce((acc, d) => {
    acc[d.status] = (acc[d.status] ?? 0) + 1;
    return acc;
  }, {} as Record<DrawerStatus, number>);

  const boxStatusCounts = (boxes.data ?? []).reduce((acc, b) => {
    acc[b.status] = (acc[b.status] ?? 0) + 1;
    return acc;
  }, {} as Record<MedicineBoxStatus, number>);

  const recentUsers = (users.data ?? []).slice(0, 5);
  const recentBoxes = (boxes.data ?? []).slice(-5).reverse();

  return (
    <div className="space-y-8">
      <PageHeader
        title="Dashboard"
        description="System overview and device management"
      />

      <div className="2xl:grid-cols-3 lg:grid-cols-2 grid-cols-1 grid gap-4 mb-8">
        <StatCard
          icon={Users}
          label="Total Users"
          value={totalUsers}
          isPending={users.isPending}
          iconBg="bg-blue-500/10"
          iconColor="text-blue-600 dark:text-blue-400"
        />
        <StatCard
          icon={Package}
          label="Total Medicine Boxes"
          value={totalBoxes}
          isPending={boxes.isPending}
          iconBg="bg-indigo-500/10"
          iconColor="text-indigo-600 dark:text-indigo-400"
        />
        <StatCard
          icon={Boxes}
          label="Active Boxes"
          value={activeBoxes}
          isPending={boxes.isPending}
          iconBg="bg-green-500/10"
          iconColor="text-green-600 dark:text-green-400"
        />
        <StatCard
          icon={Package}
          label="Registered Boxes"
          value={registeredBoxes}
          isPending={boxes.isPending}
          iconBg="bg-cyan-500/10"
          iconColor="text-cyan-600 dark:text-cyan-400"
        />
        <StatCard
          icon={LayoutGrid}
          label="Total Drawers"
          value={totalDrawers}
          isPending={drawers.isPending}
          iconBg="bg-orange-500/10"
          iconColor="text-orange-600 dark:text-orange-400"
        />
        <StatCard
          icon={LayoutGrid}
          label="Active Drawers"
          value={activeDrawers}
          isPending={drawers.isPending}
          iconBg="bg-emerald-500/10"
          iconColor="text-emerald-600 dark:text-emerald-400"
        />
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <div className="text-lg font-semibold">Recent Users</div>
            <p className="text-sm text-muted-foreground">
              Last 5 registered users
            </p>
          </CardHeader>
          <CardContent>
            {users.isPending ? (
              <div className="space-y-3">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-12 w-full" />
                ))}
              </div>
            ) : users.isError ? (
              <div className="py-8 text-center text-sm text-muted-foreground">
                Failed to load users
              </div>
            ) : recentUsers.length === 0 ? (
              <div className="py-8 text-center text-sm text-muted-foreground">
                No users yet
              </div>
            ) : (
              <div className="rounded-md border overflow-hidden">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Name</TableHead>
                      <TableHead>Email</TableHead>
                      <TableHead>Role</TableHead>
                      <TableHead>Created</TableHead>
                      <TableHead className="w-[80px]"></TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {recentUsers.map((user) => (
                      <TableRow key={user.id}>
                        <TableCell className="font-medium">
                          {user.firstName || user.lastName
                            ? `${user.firstName ?? ''} ${user.lastName ?? ''}`.trim()
                            : '—'}
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          {user.email}
                        </TableCell>
                        <TableCell>
                          <Badge
                            variant={user.role === 'ADMIN' ? 'secondary' : 'default'}
                            className={
                              user.role === 'ADMIN'
                                ? 'bg-green-500/15 text-green-700 dark:text-green-400 border-transparent'
                                : ''
                            }
                          >
                            {user.role}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          {formatDate(user.createdAt)}
                        </TableCell>
                        <TableCell>
                          <Button asChild variant="ghost" size="icon">
                            <Link href={`/users/${user.id}`}>
                              <Eye className="h-4 w-4" />
                              <span className="sr-only">View</span>
                            </Link>
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div className="text-lg font-semibold">Recent Medicine Boxes</div>
            <p className="text-sm text-muted-foreground">
              Last 5 registered devices
            </p>
          </CardHeader>
          <CardContent>
            {boxes.isPending ? (
              <div className="space-y-3">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-12 w-full" />
                ))}
              </div>
            ) : boxes.isError ? (
              <div className="py-8 text-center text-sm text-muted-foreground">
                Failed to load medicine boxes
              </div>
            ) : recentBoxes.length === 0 ? (
              <div className="py-8 text-center text-sm text-muted-foreground">
                No medicine boxes yet
              </div>
            ) : (
              <div className="rounded-md border overflow-hidden">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Device ID</TableHead>
                      <TableHead>Name</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Created</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {recentBoxes.map((box) => (
                      <TableRow key={box.id}>
                        <TableCell className="font-mono text-sm">
                          {box.deviceId}
                        </TableCell>
                        <TableCell className="font-medium">{box.name}</TableCell>
                        <TableCell>{boxStatusBadge(box.status)}</TableCell>
                        <TableCell className="text-muted-foreground">
                          {formatDate(box.createdAt)}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <div className="text-lg font-semibold">Device Status Overview</div>
          <p className="text-sm text-muted-foreground">
            Current status distribution across all medicine boxes and drawers
          </p>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <div className="text-sm font-medium mb-3 text-muted-foreground">
              Medicine Box Status
            </div>
            <div className="flex flex-wrap gap-2">
              {boxes.isPending ? (
                Array.from({ length: 4 }).map((_, i) => (
                  <Skeleton key={i} className="h-6 w-32 rounded-full" />
                ))
              ) : boxes.isError ? (
                <span className="text-sm text-muted-foreground">
                  Status unavailable
                </span>
              ) : Object.keys(boxStatusCounts).length === 0 ? (
                <span className="text-sm text-muted-foreground">
                  No devices registered
                </span>
              ) : (
                (Object.entries(boxStatusCounts) as [MedicineBoxStatus, number][]).map(
                  ([status, count]) => (
                    <div key={status} className="flex items-center gap-2">
                      {boxStatusBadge(status)}
                      <span className="text-sm font-medium">x{count}</span>
                    </div>
                  )
                )
              )}
            </div>
          </div>
          <div>
            <div className="text-sm font-medium mb-3 text-muted-foreground">
              Drawer Status
            </div>
            <div className="flex flex-wrap gap-2">
              {drawers.isPending ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-6 w-32 rounded-full" />
                ))
              ) : drawers.isError ? (
                <span className="text-sm text-muted-foreground">
                  Status unavailable
                </span>
              ) : Object.keys(drawerStatusCounts).length === 0 ? (
                <span className="text-sm text-muted-foreground">
                  No drawers provisioned
                </span>
              ) : (
                (Object.entries(drawerStatusCounts) as [DrawerStatus, number][]).map(
                  ([status, count]) => drawerStatusBadge(status, count)
                )
              )}
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
