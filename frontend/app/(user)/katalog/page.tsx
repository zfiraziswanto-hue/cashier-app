'use client';

import { useAuth } from '@/hooks/useAuth';

export default function Page() {
  const { user, logout } = useAuth();

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold">Katalog Produk</h1>
      <p className="mt-4">Selamat datang, {user?.nama}!</p>
      <button
        onClick={logout}
        className="mt-8 bg-red-500 text-white px-4 py-2 rounded"
      >
        Logout
      </button>
    </div>
  );
}
