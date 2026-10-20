'use client';

import { Skeleton } from '@/components/ui/skeleton';

interface LoadingStateProps {
  label?: string;
  count?: number;
}

export default function LoadingState({ label, count = 3 }: LoadingStateProps) {
  return (
    <div className="w-full">
      <div className="space-y-0">
        {Array.from({ length: count }).map((_, i) => (
          <Skeleton key={i} className="h-12 rounded mb-3 w-full" />
        ))}
      </div>
      {label !== undefined ? (
        <p className="text-sm text-muted-foreground text-center mt-4">
          {label || 'Loading...'}
        </p>
      ) : null}
    </div>
  );
}
