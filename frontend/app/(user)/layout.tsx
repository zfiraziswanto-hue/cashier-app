'use client';

import { redirect } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth';

export default function Layout({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();

  if (!loading && !user) {
    redirect('/login');
  }

  return (
    <div className="flex flex-col min-h-screen">
      {children}
    </div>
  );
}
