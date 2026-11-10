# AGENTS.md - Aturan Tetap Proyek Kasir OSIS

## 1. RINGKASAN PROYEK
Aplikasi kasir web untuk proker OSIS dengan 3 role: admin, kasir, user (pembeli). Rujukan utama: docs/PRD.md. Jika ada konflik antara instruksi sesi dan PRD, tanyakan dulu, jangan menebak.

## 2. STRUKTUR MONOREPO
- `/frontend`  : Next.js (App Router) + TypeScript + Tailwind CSS + shadcn/ui + TanStack Query + React Hook Form + Zod
- `/backend`   : Express.js + TypeScript + Zod + helmet + cors + express-rate-limit + pino
- `/supabase`  : migrations SQL, seed, dan fungsi database (RPC)
- `/docs`      : PRD dan dokumentasi

## 3. ATURAN KODE
- Semua kode TypeScript strict mode, tanpa `any` kecuali dengan komentar alasan.
- Backend berlapis: routes -> controllers -> services -> repositories. Controller tidak boleh berisi logika bisnis.
- Validasi semua input request dengan Zod di backend; frontend memakai skema Zod yang sama atau setara.
- Format respons API seragam: `{ success: boolean, data?: any, error?: { code: string, message: string } }`.
- Semua teks antarmuka berbahasa Indonesia. Nama variabel, fungsi, dan kolom database berbahasa Inggris, kecuali istilah domain yang sudah ditetapkan di PRD.
- Mata uang Rupiah, format `Rp 12.500`. Simpan uang sebagai integer (rupiah) di database, tanpa desimal.
- Zona waktu tampilan: Asia/Jakarta (WIB). Simpan timestamp dalam UTC.

## 4. ATURAN KEAMANAN (WAJIB)
- Jangan pernah meng-hardcode atau meng-commit rahasia. Gunakan .env dan sediakan .env.example untuk frontend dan backend.
- SUPABASE_SERVICE_ROLE_KEY hanya dipakai di backend. Jangan pernah dikirim ke frontend atau diawali NEXT_PUBLIC_.
- Semua endpoint selain login/register/katalog publik wajib melewati middleware authenticate dan authorize(roles).
- Role diambil dari database (tabel profiles), bukan dari input klien.
- Aktifkan RLS di semua tabel Supabase.
- Rate limit pada endpoint login. CORS dibatasi ke domain frontend.
- Jangan tampilkan stack trace atau pesan error internal ke klien.

## 5. ATURAN BISNIS KRITIS
- Transaksi dan pengurangan stok harus ATOMIK lewat fungsi database (PL/pgSQL, dipanggil via RPC), dengan penguncian baris (SELECT ... FOR UPDATE) untuk mencegah stok negatif akibat transaksi bersamaan.
- Harga modal dan harga jual disalin (snapshot) ke transaction_items dan order_items.
- Produk dan akun tidak dihapus permanen; gunakan is_active (soft delete). Hanya admin yang boleh menonaktifkan produk.
- Transaksi selesai tidak boleh diedit atau dihapus; hanya bisa di-void lewat persetujuan admin.
- Laba dihitung otomatis dari data transaksi, tidak diinput manual.
- Setiap aksi penting dicatat ke activity_logs.

## 6. ALUR KERJA AGENT
- Sebelum menulis kode untuk sebuah fase, tuliskan rencana singkat (file yang akan dibuat/diubah) dan tunggu persetujuan jika fase besar.
- Kerjakan satu fase pada satu waktu. Jangan membuat fitur di luar fase yang diminta.
- Setelah selesai, jalankan lint, typecheck, dan test yang relevan, lalu laporkan hasilnya jujur (termasuk yang gagal atau belum dikerjakan).
- Jangan mengubah file di luar cakupan tugas tanpa menyebutkan alasannya.
- Jangan menginstal dependency baru tanpa menyebutkan alasan dan fungsinya.
- Jika ada kebutuhan yang ambigu, ajukan pertanyaan spesifik dan berikan rekomendasi default.

## 7. COMMAND PENTING
*(Diisi setelah fase 1 selesai)*
- Frontend:
  - Install: `npm install` (di /frontend)
  - Dev: `npm run dev`
  - Build: `npm run build`
  - Lint: `npm run lint`
  - Typecheck: `npm run typecheck`
  - Test: `npm run test`
- Backend:
  - Install: `npm install` (di /backend)
  - Dev: `npm run dev`
  - Build: `npm run build`
  - Lint: `npm run lint`
  - Typecheck: `npm run typecheck`
  - Test: `npm run test`
