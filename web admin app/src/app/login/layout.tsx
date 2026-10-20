import { Suspense } from 'react';
import { Pill } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';

export default function LoginLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-slate-50 dark:bg-slate-900">
          <div className="flex flex-col items-center gap-4">
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Pill className="w-6 h-6 text-primary" />
            </div>
            <Skeleton className="h-4 w-24" />
          </div>
        </div>
      }
    >
      {children}
    </Suspense>
  );
}
