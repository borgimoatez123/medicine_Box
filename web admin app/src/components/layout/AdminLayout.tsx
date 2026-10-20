'use client';

import { useState } from 'react';
import AdminSidebar, { MobileNavTrigger } from './AdminSidebar';
import { cn } from '@/lib/utils';

interface AdminLayoutProps {
  children: React.ReactNode;
}

export default function AdminLayout({ children }: AdminLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="flex min-h-screen bg-slate-50 dark:bg-slate-900">
      <AdminSidebar />

      <div className="md:pl-64 flex flex-col flex-1 min-h-screen w-full transition-all duration-300">
        <header className="md:hidden sticky top-0 z-30 flex items-center gap-3 h-16 px-4 bg-white dark:bg-slate-950 border-b border-slate-200 dark:border-slate-800">
          <MobileNavTrigger onClick={() => setSidebarOpen(true)} />
          <h1 className="font-semibold text-lg truncate">SMD Admin</h1>
        </header>

        <main
          className={cn(
            'flex-1 overflow-auto',
            'min-h-screen',
            'p-4 md:p-6 lg:p-8'
          )}
        >
          {children}
        </main>
      </div>
    </div>
  );
}
