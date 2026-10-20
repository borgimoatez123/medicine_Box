'use client';

import { useEffect } from 'react';
import { useRequireAdmin } from '@/lib/auth/hooks';
import { useRouter, usePathname } from 'next/navigation';
import LoadingState from '@/components/feedback/LoadingState';
import ErrorState from '@/components/feedback/ErrorState';
import { Button } from '@/components/ui/button';

interface RequireAdminProps {
  children: React.ReactNode;
}

export default function RequireAdmin({ children }: RequireAdminProps) {
  const { isReady, isAdmin, user } = useRequireAdmin();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (isReady && !user) {
      router.push('/login?redirect=' + encodeURIComponent(pathname));
    }
  }, [isReady, user, router, pathname]);

  if (!isReady) {
    return (
      <div className="flex items-center justify-center min-h-[400px] w-full">
        <LoadingState label="Verifying access..." count={1} />
      </div>
    );
  }

  if (isReady && user && !isAdmin) {
    return (
      <div className="max-w-lg mx-auto py-12">
        <ErrorState
          title="Administrator access required"
          error="Your account does not have permission to access the Admin Dashboard. Please login with an administrator account."
        />
        <div className="mt-6 text-center">
          <Button onClick={() => router.push('/login')}>Go to login</Button>
        </div>
      </div>
    );
  }

  if (isReady && !user) {
    return null;
  }

  return <>{children}</>;
}
