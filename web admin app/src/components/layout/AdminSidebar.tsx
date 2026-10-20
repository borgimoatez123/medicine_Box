'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  Users,
  Package,
  Boxes,
  LogOut,
  Menu,
  X,
  ChevronRight,
} from 'lucide-react';
import { useAuth } from '@/lib/auth/hooks';
import { clearAuth } from '@/lib/auth/storage';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogTrigger,
} from '@/components/ui/dialog';

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}

const navItems: NavItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/users', label: 'Users', icon: Users },
  { href: '/medicine-boxes', label: 'Medicine Boxes', icon: Package },
  { href: '/drawers', label: 'Drawers', icon: Boxes },
];

function getInitials(firstName: string | null, lastName: string | null): string {
  const first = firstName?.charAt(0)?.toUpperCase() ?? '';
  const last = lastName?.charAt(0)?.toUpperCase() ?? '';
  return first + last || 'U';
}

interface AdminSidebarContentProps {
  collapsed: boolean;
  onNavigate?: () => void;
}

function AdminSidebarContent({ collapsed, onNavigate }: AdminSidebarContentProps) {
  const pathname = usePathname();
  const router = useRouter();
  const { user } = useAuth();
  const [logoutOpen, setLogoutOpen] = useState(false);

  const handleLogoutConfirm = () => {
    clearAuth();
    setLogoutOpen(false);
    router.push('/login');
  };

  return (
    <div
      className={cn(
        'flex flex-col h-full bg-white dark:bg-slate-950 border-r border-slate-200 dark:border-slate-800 transition-all duration-300',
        collapsed ? 'w-16' : 'w-64'
      )}
    >
      <div
        className={cn(
          'flex items-center gap-3 px-4 h-16 border-b border-slate-200 dark:border-slate-800 shrink-0',
          collapsed && 'justify-center px-2'
        )}
      >
        <div className="flex items-center justify-center w-9 h-9 rounded-lg bg-primary text-primary-foreground shrink-0">
          <Package className="w-5 h-5" />
        </div>
        {!collapsed && (
          <span className="font-bold text-lg tracking-tight truncate">SMD Admin</span>
        )}
      </div>

      <nav className="flex-1 overflow-y-auto p-3 space-y-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive =
            pathname === item.href || pathname?.startsWith(item.href + '/');

          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onNavigate}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors group',
                isActive
                  ? 'bg-slate-100 dark:bg-slate-800 text-primary font-medium'
                  : 'text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800',
                collapsed && 'justify-center px-2'
              )}
              title={collapsed ? item.label : undefined}
            >
              <Icon className={cn('w-5 h-5 shrink-0', isActive ? 'text-primary' : 'text-slate-500 dark:text-slate-400 group-hover:text-slate-700 dark:group-hover:text-slate-200')} />
              {!collapsed && (
                <>
                  <span className="flex-1 truncate">{item.label}</span>
                  {isActive && <ChevronRight className="w-4 h-4 text-primary" />}
                </>
              )}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-slate-200 dark:border-slate-800 p-3 shrink-0">
        {!collapsed && user ? (
          <div className="mb-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-900">
            <div className="flex items-center gap-3">
              <div className="flex items-center justify-center w-10 h-10 rounded-full bg-primary text-primary-foreground font-semibold text-sm shrink-0">
                {getInitials(user.firstName, user.lastName)}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="font-medium text-sm truncate">
                    {user.firstName} {user.lastName}
                  </span>
                </div>
                <p className="text-xs text-slate-500 dark:text-slate-400 truncate mt-0.5">
                  {user.email}
                </p>
                <Badge variant="default" className="mt-1.5 text-[10px] h-5">
                  ADMIN
                </Badge>
              </div>
            </div>
          </div>
        ) : collapsed && user ? (
          <div
            className="flex items-center justify-center mb-3"
            title={`${user.firstName} ${user.lastName} - ${user.email}`}
          >
            <div className="flex items-center justify-center w-10 h-10 rounded-full bg-primary text-primary-foreground font-semibold text-sm">
              {getInitials(user.firstName, user.lastName)}
            </div>
          </div>
        ) : null}

        <Dialog open={logoutOpen} onOpenChange={setLogoutOpen}>
          <DialogTrigger asChild>
            <Button
              variant={collapsed ? 'ghost' : 'outline'}
              size={collapsed ? 'icon' : 'default'}
              className={cn(
                'w-full text-red-600 dark:text-red-400 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-950 border-red-200 dark:border-red-900',
                collapsed && 'hover:bg-red-50 dark:hover:bg-red-950'
              )}
              title={collapsed ? 'Logout' : undefined}
            >
              <LogOut className={cn('w-4 h-4', !collapsed && 'mr-2')} />
              {!collapsed && 'Logout'}
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Confirm Logout</DialogTitle>
              <DialogDescription>
                Are you sure you want to log out? You will need to log in again to access the admin dashboard.
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button variant="outline" onClick={() => setLogoutOpen(false)}>
                Cancel
              </Button>
              <Button variant="destructive" onClick={handleLogoutConfirm}>
                Logout
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}

interface MobileNavTriggerProps {
  onClick: () => void;
  className?: string;
}

export function MobileNavTrigger({ onClick, className }: MobileNavTriggerProps) {
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={onClick}
      className={cn('md:hidden', className)}
      aria-label="Open navigation"
    >
      <Menu className="w-5 h-5" />
    </Button>
  );
}

interface AdminSidebarProps {
  className?: string;
}

export default function AdminSidebar({ className }: AdminSidebarProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      <aside
        className={cn(
          'hidden md:flex fixed inset-y-0 left-0 z-40',
          className
        )}
      >
        <AdminSidebarContent collapsed={collapsed} />
        <button
          onClick={() => setCollapsed((v) => !v)}
          className="absolute top-1/2 -right-3 z-10 hidden md:flex items-center justify-center w-6 h-6 rounded-full border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 shadow-sm hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          <ChevronRight
            className={cn(
              'w-3.5 h-3.5 text-slate-500 transition-transform duration-300',
              collapsed ? '' : 'rotate-180'
            )}
          />
        </button>
      </aside>

      <Dialog open={mobileOpen} onOpenChange={setMobileOpen}>
        <DialogContent
          className="p-0 border-0 !max-w-none !w-[85vw] !h-screen !left-0 !top-0 !translate-x-0 !translate-y-0 !m-0 sm:rounded-none flex flex-col gap-0"
          showClose={false}
        >
          <div className="absolute right-4 top-4 z-10">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setMobileOpen(false)}
              aria-label="Close navigation"
            >
              <X className="w-5 h-5" />
            </Button>
          </div>
          <AdminSidebarContent
            collapsed={false}
            onNavigate={() => setMobileOpen(false)}
          />
        </DialogContent>
      </Dialog>

      <MobileNavTrigger onClick={() => setMobileOpen(true)} />
    </>
  );
}
