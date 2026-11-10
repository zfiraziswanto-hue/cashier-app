# Aplikasi Kasir OSIS

Aplikasi kasir berbasis web untuk program kerja OSIS (bazar, kantin, merchandise) dengan tiga peran: **Admin**, **Kasir**, dan **User (Pembeli)**.

## Fitur Utama
- **Autentikasi & Otorisasi**: Berbasis Supabase Auth dengan kontrol akses berbasis peran (RBAC) pada tabel `profiles`.
- **Manajemen Produk & Stok**: CRUD produk, kategori, stok minimum, alert stok menipis, dan pencatatan riwayat stok (`stock_movements`).
- **POS Kasir**: Transaksi penjualan langsung, perhitungan kembalian otomatis, metode pembayaran tunai/non-tunai, cetak struk ukuran 58mm/80mm, dan pengajuan void.
- **Sisi User (Pembeli)**: Katalog produk aktif, keranjang, pembuatan pesanan mandiri dengan kode unik, dan pelacakan status pesanan.
- **Laporan & Rekap**: Laporan laba/rugi otomatis (berdasarkan snapshot harga modal dan jual), rekap harian, dan ekspor ke PDF & Excel.
- **Modul Admin**: Dashboard analitik penjualan 7 hari terakhir, log sesi login kasir, log aktivitas, dan pengaturan profil toko dengan upload logo ke Supabase Storage.

## Teknologi
- **Frontend**: Next.js (App Router), TypeScript, Tailwind CSS, shadcn/ui, TanStack Query, React Hook Form, Zod.
- **Backend**: Express.js (Node.js), TypeScript, Zod validation, helmet, cors, express-rate-limit, pino.
- **Database**: Supabase (PostgreSQL) dengan Row Level Security (RLS) dan fungsi PL/pgSQL atomik (RPC).

## Cara Setup
1. Clone repositori ini.
2. Buat proyek baru di [Supabase](https://supabase.com).
3. Jalankan file migrasi SQL di folder `/supabase/migrations` pada SQL Editor Supabase.
4. Jalankan script seed di `/supabase/seed.sql` untuk mengisi data awal.
5. Konfigurasi file `.env` di `/backend` dan `/frontend` berdasarkan `.env.example`.

### Perintah Penting
- **Backend**:
  - Install: `npm install` (di dalam folder `/backend`)
  - Dev: `npm run dev`
  - Build: `npm run build`
  - Lint: `npm run lint`
  - Typecheck: `npm run typecheck`
  - Test: `npm run test`
- **Frontend**:
  - Install: `npm install` (di dalam folder `/frontend`)
  - Dev: `npm run dev`
  - Build: `npm run build`
  - Lint: `npm run lint`
  - Typecheck: `npm run typecheck`
  - Test: `npm run test`

## Cara Deploy
- **Frontend**: Deploy ke **Vercel** dengan menghubungkan repositori GitHub dan mengatur variabel lingkungan (`NEXT_PUBLIC_SUPABASE_URL`, dll).
- **Backend**: Deploy ke **Render** atau **Railway** sebagai Web Service Node.js, pastikan environment variables (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FRONTEND_URL`) terisi dengan benar.

## Akun Demo
(Dibuat melalui dashboard Supabase Auth & tabel profiles dengan role masing-masing).
- Admin: `admin@osis.local`
- Kasir: `kasir@osis.local`
- User: `user@osis.local`

## Masalah yang Diketahui (Known Issues)
- Koneksi offline belum didukung penuh; aplikasi memerlukan koneksi internet stabil ke server Supabase dan Express API.
