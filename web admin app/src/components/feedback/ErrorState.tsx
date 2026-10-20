'use client';

import { AlertCircle, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface ErrorStateProps {
  error: string | Error;
  onRetry?: () => void;
  title?: string;
}

export default function ErrorState({ error, onRetry, title }: ErrorStateProps) {
  const errorMessage =
    typeof error === 'string' ? error : error?.message || 'An unexpected error occurred';

  return (
    <div className="py-12 px-6 text-center border rounded-xl bg-card">
      <div className="rounded-full bg-red-50 dark:bg-red-950/50 p-4 mx-auto mb-4 w-16 h-16 flex items-center justify-center">
        <AlertCircle className="w-8 h-8 text-red-600 dark:text-red-400" />
      </div>
      <h3 className="text-xl font-semibold">{title ?? 'Something went wrong'}</h3>
      <p className="text-muted-foreground mt-2 max-w-md mx-auto">{errorMessage}</p>
      {onRetry && (
        <div className="mt-6">
          <Button onClick={onRetry}>
            <Loader2 className="w-4 h-4 mr-2 hidden" />
            Retry
          </Button>
        </div>
      )}
    </div>
  );
}
