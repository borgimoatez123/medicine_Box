import AdminLayout from '@/components/layout/AdminLayout';
import RequireAdmin from '@/components/auth/RequireAdmin';

export default function DashboardGroupLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <RequireAdmin>
      <AdminLayout>{children}</AdminLayout>
    </RequireAdmin>
  );
}
