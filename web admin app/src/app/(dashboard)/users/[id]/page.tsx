'use client';

import { useParams } from 'next/navigation';
import Link from 'next/link';
import { useUserById } from '@/hooks';
import PageHeader from '@/components/feedback/PageHeader';
import LoadingState from '@/components/feedback/LoadingState';
import ErrorState from '@/components/feedback/ErrorState';
import EmptyState from '@/components/feedback/EmptyState';
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { formatDate } from '@/lib/utils';
import { ArrowLeft, User } from 'lucide-react';

interface ProfileRowProps {
  label: string;
  value: React.ReactNode;
}

function ProfileRow({ label, value }: ProfileRowProps) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between py-3 border-b last:border-b-0 gap-1">
      <span className="text-sm font-medium text-muted-foreground">{label}</span>
      <span className="text-sm">{value}</span>
    </div>
  );
}

export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params?.id;
  const user = useUserById(id ?? '');

  return (
    <div className="space-y-6">
      <PageHeader title="User Details">
        <Button asChild variant="outline" size="sm">
          <Link href="/users">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Users
          </Link>
        </Button>
      </PageHeader>

      {user.isPending ? (
        <LoadingState count={6} label="Loading user details..." />
      ) : user.isError ? (
        <ErrorState
          error={user.error}
          onRetry={() => user.refetch()}
          title="Failed to load user"
        />
      ) : !user.data ? (
        <EmptyState
          title="User not found"
          description="The requested user does not exist or may have been removed."
          icon={User}
          action={{ label: 'Back to Users', href: '/users' }}
        />
      ) : (
        <div className="grid lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle>Profile</CardTitle>
              <CardDescription>
                Account information and user details
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ProfileRow
                label="First Name"
                value={user.data.firstName ?? '—'}
              />
              <ProfileRow
                label="Last Name"
                value={user.data.lastName ?? '—'}
              />
              <ProfileRow label="Email" value={user.data.email} />
              <ProfileRow label="Phone" value={user.data.phone ?? '—'} />
              <ProfileRow
                label="Role"
                value={
                  <Badge
                    variant={user.data.role === 'ADMIN' ? 'secondary' : 'default'}
                    className={
                      user.data.role === 'ADMIN'
                        ? 'bg-green-500/15 text-green-700 dark:text-green-400 border-transparent'
                        : ''
                    }
                  >
                    {user.data.role}
                  </Badge>
                }
              />
              <ProfileRow
                label="Created At"
                value={formatDate(user.data.createdAt)}
              />
              <ProfileRow
                label="Updated At"
                value={formatDate(user.data.updatedAt)}
              />
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Admin Actions</CardTitle>
              <CardDescription>
                Administrative operations for this user
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="py-12 text-center text-sm text-muted-foreground">
                This user has no additional admin actions available.
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
