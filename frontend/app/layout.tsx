import type { Metadata } from 'next';
import './globals.css';
import { fontSans, fontMono } from '@/lib/fonts';
import { AuthProvider } from '@/hooks/useAuth';
import { Providers } from '@/components/providers';
import { cn } from '@/lib/utils';

export const metadata: Metadata = {
  title: 'Kasir OSIS',
  description: 'Aplikasi kasir berbasis web untuk program kerja OSIS',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id" className={cn(fontSans.variable, fontMono.variable)} suppressHydrationWarning>
      <body className="min-h-full flex flex-col bg-kertas text-tinta font-sans antialiased">
        <AuthProvider>
          <Providers>{children}</Providers>
        </AuthProvider>
      </body>
    </html>
  );
}
