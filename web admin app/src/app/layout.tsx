import type { Metadata } from 'next';
import './globals.css';
import QueryProvider from '@/lib/query/provider';

export const metadata: Metadata = {
  title: 'Smart Medicine Admin',
  description: 'Smart Medicine administration dashboard',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased min-h-screen">
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  );
}
