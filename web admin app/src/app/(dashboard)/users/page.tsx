'use client';

import { useMemo, useState } from 'react';
import { useUsers } from '@/hooks';
import PageHeader from '@/components/feedback/PageHeader';
import DataTable from '@/components/tables/DataTable';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { formatDate } from '@/lib/utils';
import type { PublicUser } from '@/types';
import Link from 'next/link';
import { Search, Eye } from 'lucide-react';

export default function UsersPage() {
  const users = useUsers();
  const [searchQuery, setSearchQuery] = useState('');

  const filteredUsers = useMemo(() => {
    if (!users.data || searchQuery.trim() === '') return users.data ?? [];
    const query = searchQuery.toLowerCase();
    return users.data.filter((user) => {
      const firstName = user.firstName?.toLowerCase() ?? '';
      const lastName = user.lastName?.toLowerCase() ?? '';
      const email = user.email.toLowerCase();
      return (
        firstName.includes(query) ||
        lastName.includes(query) ||
        email.includes(query)
      );
    });
  }, [users.data, searchQuery]);

  const columns = [
    {
      key: 'firstName',
      header: 'First Name',
      render: (row: PublicUser) => row.firstName ?? '—',
    },
    {
      key: 'lastName',
      header: 'Last Name',
      render: (row: PublicUser) => row.lastName ?? '—',
    },
    {
      key: 'email',
      header: 'Email',
    },
    {
      key: 'phone',
      header: 'Phone',
      render: (row: PublicUser) => row.phone ?? '—',
    },
    {
      key: 'role',
      header: 'Role',
      render: (row: PublicUser) => (
        <Badge
          variant={row.role === 'ADMIN' ? 'secondary' : 'default'}
          className={
            row.role === 'ADMIN'
              ? 'bg-green-500/15 text-green-700 dark:text-green-400 border-transparent'
              : ''
          }
        >
          {row.role}
        </Badge>
      ),
    },
    {
      key: 'createdAt',
      header: 'Created At',
      render: (row: PublicUser) => formatDate(row.createdAt),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Users"
        description="Manage system users and administrators"
      >
        <div className="relative w-full max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            type="text"
            placeholder="Search users..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>
      </PageHeader>

      <DataTable<PublicUser>
        columns={columns}
        data={filteredUsers}
        loading={users.isPending}
        error={users.isError ? users.error : undefined}
        onRetry={() => users.refetch()}
        emptyTitle="No users found"
        emptyDescription={
          searchQuery
            ? 'No users match your search criteria.'
            : 'No users have been registered yet.'
        }
        renderRowActions={(row) => (
          <Button asChild variant="ghost" size="icon">
            <Link href={`/users/${row.id}`}>
              <Eye className="h-4 w-4" />
              <span className="sr-only">View</span>
            </Link>
          </Button>
        )}
      />
    </div>
  );
}
