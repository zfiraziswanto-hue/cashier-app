PRD Aplikasi Kasir OSIS
Product Requirements Document · Versi 1.0 · Stack: Next.js, Express.js, Supabase (PostgreSQL)
1. Ringkasan Produk
Aplikasi kasir berbasis web untuk kebutuhan program kerja (proker) OSIS, misalnya bazar, kantin, atau penjualan merchandise. Aplikasi memiliki tiga peran: Admin, Kasir, dan User (pembeli). Admin mengelola kasir, produk, dan profil toko serta memantau aktivitas. Kasir memproses transaksi, mencetak struk, memantau stok, dan membuat rekap harian. User melihat katalog dan membuat pesanan yang dikonfirmasi pembayarannya oleh kasir.
2. Latar Belakang dan Masalah
• Pencatatan penjualan manual rawan salah hitung dan sulit dipertanggungjawabkan saat laporan proker.
• Stok barang sering habis tanpa disadari.
• Tidak ada jejak siapa kasir yang bertugas, kapan, dan transaksi apa yang dibuat.
• Modal dan keuntungan sulit dihitung cepat per hari atau per periode.
3. Tujuan dan Metrik Keberhasilan
Tujuan
• Mempercepat proses transaksi di kasir.
• Menyediakan laporan modal, pendapatan, dan laba yang akurat dan otomatis.
• Mencegah kehabisan stok dengan peringatan dini.
• Menyediakan jejak audit untuk transparansi dana OSIS.
Metrik keberhasilan
• Satu transaksi selesai dalam kurang dari 30 detik oleh kasir.
• Selisih antara rekap sistem dan uang fisik di kas mendekati nol.
• 100% transaksi tercatat beserta nama kasir dan waktunya.
• Rekap harian dapat diekspor dalam kurang dari 10 detik.
4. Ruang Lingkup
Termasuk (In Scope)
• Autentikasi dan otorisasi berbasis peran.
• Manajemen kasir, produk, kategori, dan stok.
• Transaksi kasir, cetak struk, dan pembayaran tunai.
• Pemesanan oleh user dengan konfirmasi oleh kasir.
• Laporan modal dan laba otomatis, rekap harian, ekspor PDF dan Excel.
• Log aktivitas dan sesi login kasir.
• Pengaturan profil toko.
Tidak termasuk (Out of Scope) untuk versi 1.0
• Integrasi payment gateway otomatis (QRIS dinamis). QRIS atau transfer dicatat manual oleh kasir.
• Aplikasi mobile native.
• Multi-cabang atau multi-toko.
• Sistem poin atau membership.
5. Persona dan Peran
Admin (Ketua atau Bendahara OSIS)
• Mengelola akun kasir, produk, dan profil toko.
• Memantau aktivitas kasir dan laporan keuangan.
• Menyetujui void atau retur transaksi.
Kasir (Anggota OSIS yang bertugas)
• Memproses transaksi langsung dan pesanan dari user.
• Mengelola stok dan menerima alert stok menipis.
• Mencetak struk dan membuat rekap harian.
User (Siswa atau pengunjung)
• Melihat katalog produk yang tersedia.
• Membuat pesanan dan melihat status pesanannya.
6. Matriks Hak Akses
• Kelola akun kasir (CRUD): Admin ✔, Kasir ✘, User ✘
• Lihat log login/logout dan aktivitas kasir: Admin ✔, Kasir ✘, User ✘
• Atur profil toko: Admin ✔, Kasir ✘, User ✘
• Tambah dan edit produk: Admin ✔, Kasir ✔, User ✘
• Nonaktifkan atau hapus produk: Admin ✔, Kasir ✘, User ✘
• Tambah dan edit stok: Admin ✔, Kasir ✔, User ✘
• Buat transaksi kasir dan cetak struk: Admin ✔ (opsional), Kasir ✔, User ✘
• Konfirmasi pembayaran pesanan: Admin ✔, Kasir ✔, User ✘
• Ajukan void atau retur: Kasir ✔, Admin ✔, User ✘
• Setujui void atau retur: Admin ✔, Kasir ✘, User ✘
• Lihat laporan modal dan laba: Admin ✔, Kasir ✔, User ✘
• Buat dan ekspor rekap harian: Admin ✔, Kasir ✔, User ✘
• Lihat katalog dan buat pesanan: Admin ✘, Kasir ✘, User ✔
7. Alur Pengguna Utama
7.1 Transaksi langsung di kasir
1. Kasir login, sistem mencatat awal sesi.
2. Kasir memilih produk atau memindai/mencari nama produk, lalu mengatur jumlah.
3. Sistem menghitung total secara otomatis.
4. Kasir memilih metode pembayaran (tunai, QRIS, transfer). Untuk tunai, kasir mengisi uang diterima dan sistem menghitung kembalian.
5. Transaksi disimpan, stok berkurang otomatis, struk dicetak.
6. Jika stok produk mencapai batas minimum, alert tampil di dashboard kasir.
7.2 Pesanan dari user
1. User membuka katalog, memasukkan produk ke keranjang, lalu membuat pesanan. Status: Menunggu Pembayaran.
2. User menyebutkan kode pesanan ke kasir dan membayar tunai (atau metode lain).
3. Kasir membuka pesanan berdasarkan kode, mengonfirmasi pembayaran. Status: Dibayar, stok berkurang, struk dicetak.
4. Setelah barang diserahkan, status menjadi Selesai. Pesanan yang tidak dibayar dalam batas waktu (misalnya 30 menit) otomatis Dibatalkan.
7.3 Rekap harian
1. Kasir membuka menu Rekap Harian dan memilih tanggal.
2. Sistem menampilkan jumlah transaksi, total pendapatan, total modal, laba, rincian per metode pembayaran, dan produk terjual.
3. Kasir menyimpan atau mengekspor rekap ke PDF atau Excel.
7.4 Void atau retur
1. Kasir mengajukan void dengan alasan pada transaksi tertentu.
2. Admin menyetujui atau menolak.
3. Jika disetujui, transaksi berstatus Void, stok dikembalikan, dan angka laporan disesuaikan. Tercatat di log aktivitas.
8. Kebutuhan Fungsional
Prioritas: P0 wajib untuk MVP, P1 penting, P2 opsional.
8.1 Autentikasi dan Sesi
• F-AUTH-01 (P0): Login dengan username/email dan password. Password disimpan ter-hash.
• F-AUTH-02 (P0): Akses halaman dan API dibatasi berdasarkan peran.
• F-AUTH-03 (P0): Sistem mencatat waktu login dan logout kasir. Sesi yang kedaluwarsa dicatat sebagai logout otomatis.
• F-AUTH-04 (P1): Admin dapat mereset password kasir. Semua pengguna dapat mengganti password sendiri.
• F-AUTH-05 (P1): Registrasi user (pembeli) mandiri dengan nama dan email, atau opsi pesan tanpa akun dengan nama saja (diputuskan di Pertanyaan Terbuka).
8.2 Modul Admin
• F-ADM-01 (P0): CRUD akun kasir (nama, username, password, status aktif/nonaktif). Menghapus kasir yang punya riwayat transaksi diganti dengan menonaktifkan akun.
• F-ADM-02 (P0): Halaman log sesi kasir: nama kasir, waktu login, waktu logout, durasi aktif. Dapat difilter per tanggal dan per kasir.
• F-ADM-03 (P0): Pengaturan profil toko: nama toko, logo, alamat, kontak, dan teks footer struk.
• F-ADM-04 (P1): Log aktivitas: transaksi dibuat, void, perubahan produk, perubahan harga, perubahan stok, dengan pelaku dan waktu.
• F-ADM-05 (P1): Persetujuan void atau retur.
• F-ADM-06 (P2): Dashboard ringkasan: grafik penjualan, produk terlaris, total laba, dan kasir teraktif.
8.3 Modul Produk dan Stok
• F-PRD-01 (P0): CRUD produk dengan atribut: nama, kategori, harga modal, harga jual, stok, batas minimum stok, status aktif.
• F-PRD-02 (P0): Hapus produk menggunakan soft delete (nonaktifkan). Hanya admin yang dapat menonaktifkan produk. Produk nonaktif tidak tampil di katalog tetapi tetap tersimpan di riwayat transaksi.
• F-PRD-03 (P0): Stok berkurang otomatis saat transaksi dibayar dan bertambah saat void atau retur.
• F-PRD-04 (P0): Alert stok menipis jika stok kurang dari atau sama dengan batas minimum. Alert tampil di dashboard kasir dan badge pada daftar produk.
• F-PRD-05 (P1): Kategori produk (makanan, minuman, merchandise, dll.) dengan CRUD kategori.
• F-PRD-06 (P1): Riwayat perubahan stok (stok masuk, terjual, koreksi) beserta pelakunya.
• F-PRD-07 (P2): Foto produk.
• F-PRD-08 (P2): Diskon atau promo sederhana (potongan nominal atau persen per produk).
8.4 Modul Kasir
• F-CSH-01 (P0): Halaman kasir (POS): pencarian produk, filter kategori, keranjang, ubah jumlah, hapus item.
• F-CSH-02 (P0): Perhitungan total, uang diterima, dan kembalian otomatis untuk pembayaran tunai.
• F-CSH-03 (P0): Pilihan metode pembayaran: tunai, QRIS, transfer.
• F-CSH-04 (P0): Cetak struk berisi nama toko, logo, nomor transaksi, tanggal dan jam, nama kasir, daftar item, total, metode bayar, dan kembalian. Menggunakan tampilan cetak browser (ukuran 58mm atau 80mm).
• F-CSH-05 (P0): Menu penghitungan modal dan untung: laporan otomatis total modal, total pendapatan, dan laba bersih per hari atau rentang tanggal, dihitung dari harga modal dan harga jual yang tersimpan di tiap transaksi. Kasir tidak menginput manual angka untung.
• F-CSH-06 (P0): Rekap harian: jumlah transaksi, pendapatan, modal, laba, rincian per metode bayar, dan daftar produk terjual.
• F-CSH-07 (P1): Ekspor rekap harian ke PDF dan Excel.
• F-CSH-08 (P1): Riwayat transaksi dengan pencarian dan filter per tanggal, kasir, dan status.
• F-CSH-09 (P1): Pengajuan void atau retur dengan alasan.
• F-CSH-10 (P1): Daftar pesanan masuk dari user, pencarian berdasarkan kode pesanan, dan konfirmasi pembayaran.
• F-CSH-11 (P1): Pembukaan dan penutupan kas: kasir mengisi modal kas awal dan uang fisik akhir, sistem menampilkan selisih terhadap hitungan sistem.
8.5 Modul User (Pembeli)
• F-USR-01 (P0): Katalog produk aktif dengan harga, kategori, dan ketersediaan stok. Produk dengan stok 0 ditandai habis dan tidak bisa dipesan.
• F-USR-02 (P0): Keranjang dan pembuatan pesanan, menghasilkan kode pesanan unik.
• F-USR-03 (P0): Status pesanan: Menunggu Pembayaran, Dibayar, Selesai, Dibatalkan.
• F-USR-04 (P1): Riwayat pesanan milik user.
• F-USR-05 (P1): Pembatalan pesanan oleh user selama belum dibayar.
• F-USR-06 (P1): Pencarian dan filter kategori pada katalog.
9. Aturan Bisnis
• Harga modal dan harga jual disalin (snapshot) ke tiap item transaksi, sehingga perubahan harga di masa depan tidak mengubah laporan lama.
• Laba per item = (harga jual - harga modal) × jumlah. Laba transaksi adalah jumlah laba semua item dikurangi diskon.
• Stok tidak boleh bernilai negatif. Transaksi ditolak jika stok tidak cukup.
• Stok pesanan user baru dikurangi saat pembayaran dikonfirmasi (bukan saat pesanan dibuat). Saat konfirmasi, stok dicek ulang.
• Transaksi yang sudah selesai tidak dapat diedit atau dihapus, hanya bisa di-void melalui persetujuan admin.
• Akun dan produk yang punya riwayat tidak dihapus permanen, hanya dinonaktifkan.
• Semua perubahan penting (harga, stok, void, akun) tercatat di log aktivitas.
• Nomor transaksi berformat TRX-YYYYMMDD-XXXX dan nomor pesanan berformat ORD-YYYYMMDD-XXXX.
10. Kebutuhan Non-Fungsional
• Keamanan: password ter-hash (bcrypt atau Supabase Auth), JWT dengan masa berlaku terbatas, validasi input di backend, rate limiting pada endpoint login, CORS dibatasi ke domain frontend, dan kunci service_role Supabase hanya ada di server.
• Performa: halaman kasir memuat dalam kurang dari 2 detik pada jaringan sekolah/WiFi biasa. Respons API normal di bawah 500 ms.
• Ketersediaan: dapat dipakai di laptop, tablet, dan HP (responsif). Tampilan kasir dioptimalkan untuk layar tablet dan laptop.
• Integritas data: transaksi dan pengurangan stok dijalankan atomik (satu transaksi database) agar tidak terjadi stok ganda atau transaksi setengah jadi.
• Kemudahan pakai: antarmuka berbahasa Indonesia, ringkas, dan bisa dipelajari anggota OSIS dalam kurang dari 15 menit.
• Audit: data log tidak dapat diubah atau dihapus dari antarmuka aplikasi.
11. Arsitektur dan Tech Stack
• Frontend: Next.js (App Router) dengan TypeScript, Tailwind CSS, dan komponen UI seperti shadcn/ui. Data fetching dengan TanStack Query. Form dengan React Hook Form dan Zod.
• Backend: Express.js (Node.js, TypeScript) sebagai REST API. Validasi dengan Zod, logging dengan morgan/pino, keamanan dengan helmet dan express-rate-limit.
• Database dan Auth: Supabase (PostgreSQL). Autentikasi memakai Supabase Auth, token JWT diverifikasi oleh middleware Express. Backend mengakses database lewat supabase-js menggunakan service_role key. Row Level Security (RLS) diaktifkan sebagai lapisan pertahanan tambahan.
• Storage: Supabase Storage untuk logo toko dan foto produk.
• Realtime (opsional): Supabase Realtime untuk alert stok dan notifikasi pesanan baru di layar kasir.
• Ekspor laporan: PDF dengan pdfkit atau puppeteer, Excel dengan exceljs.
• Deployment: Frontend di Vercel, backend Express di Render/Railway/VPS, database di Supabase. Variabel rahasia disimpan di environment variables.
Alur singkat: Browser (Next.js) → REST API (Express, middleware auth dan role) → Supabase (PostgreSQL, Storage). Transaksi yang melibatkan banyak tabel dijalankan lewat fungsi database (RPC/PL/pgSQL) agar atomik.
12. Rancangan Database
Tabel utama (PostgreSQL di Supabase):
• profiles: id (uuid, sama dengan auth.users.id), nama, username, role (admin | kasir | user), is_active, created_at.
• store_settings: id, nama_toko, logo_url, alamat, kontak, footer_struk, updated_at.
• categories: id, nama, is_active.
• products: id, category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active, created_at, updated_at.
• stock_movements: id, product_id, tipe (masuk | keluar | koreksi | retur), jumlah, stok_sebelum, stok_sesudah, referensi_id, created_by, created_at.
• orders: id, kode_pesanan, user_id, status (menunggu_pembayaran | dibayar | selesai | dibatalkan), total, expires_at, created_at.
• order_items: id, order_id, product_id, qty, harga_jual, harga_modal.
• transactions: id, nomor_transaksi, order_id (nullable), kasir_id, subtotal, diskon, total, total_modal, laba, metode_bayar (tunai | qris | transfer), uang_diterima, kembalian, status (selesai | void), created_at.
• transaction_items: id, transaction_id, product_id, nama_produk (snapshot), qty, harga_jual, harga_modal.
• void_requests: id, transaction_id, diajukan_oleh, alasan, status (menunggu | disetujui | ditolak), diproses_oleh, diproses_at, created_at.
• cashier_sessions: id, kasir_id, login_at, logout_at, kas_awal, kas_akhir, selisih.
• activity_logs: id, user_id, aksi, entitas, entitas_id, detail (jsonb), created_at.
Catatan desain
• Gunakan index pada transactions(created_at), transactions(kasir_id), products(is_active), dan orders(kode_pesanan).
• Fungsi database create_transaction(...) melakukan: cek stok, insert transaksi dan item, kurangi stok, catat stock_movements, dalam satu transaksi.
• Fungsi approve_void(...) mengembalikan stok dan mengubah status transaksi menjadi void.
• Pembatalan otomatis pesanan kedaluwarsa dijalankan oleh pg_cron atau job terjadwal di Express.
13. Rancangan Endpoint API (REST)
Semua endpoint diawali /api/v1. Middleware: authenticate (verifikasi JWT) dan authorize(roles).
Auth
• POST /auth/login, POST /auth/logout, POST /auth/register (user), PATCH /auth/password
Admin
• GET/POST /admin/cashiers, PATCH/DELETE /admin/cashiers/:id (DELETE = nonaktifkan), POST /admin/cashiers/:id/reset-password
• GET /admin/sessions (log login/logout), GET /admin/activity-logs
• GET/PUT /admin/store-settings
• GET /admin/void-requests, PATCH /admin/void-requests/:id (setujui/tolak)
• GET /admin/dashboard
Produk dan kategori
• GET /products (publik untuk user, dengan filter dan pencarian), POST /products, PATCH /products/:id (admin dan kasir)
• DELETE /products/:id (admin saja, nonaktifkan)
• POST /products/:id/stock (tambah atau koreksi stok), GET /products/low-stock
• GET/POST/PATCH /categories
Kasir
• POST /transactions (buat transaksi), GET /transactions, GET /transactions/:id, GET /transactions/:id/receipt
• POST /transactions/:id/void-request
• GET /reports/profit?from=&to= (modal, pendapatan, laba)
• GET /reports/daily?date=, GET /reports/daily/export?date=&format=pdf|xlsx
• POST /cashier-sessions/open, POST /cashier-sessions/close
Pesanan
• POST /orders (user), GET /orders/mine (user), PATCH /orders/:id/cancel (user)
• GET /orders?kode= (kasir), POST /orders/:id/confirm-payment (kasir)
14. Halaman Frontend (Next.js)
Publik dan User
• /login, /register
• /katalog (daftar produk, filter, pencarian)
• /keranjang dan /pesanan (riwayat dan status)
Kasir
• /kasir (POS: produk, keranjang, pembayaran, cetak struk)
• /kasir/pesanan (konfirmasi pesanan user)
• /kasir/produk (kelola produk dan stok, dengan alert stok menipis)
• /kasir/transaksi (riwayat dan pengajuan void)
• /kasir/penghitungan (laporan modal dan untung)
• /kasir/rekap (rekap harian dan ekspor)
Admin
• /admin (dashboard)
• /admin/kasir (CRUD kasir)
• /admin/sesi (log login dan logout)
• /admin/aktivitas (log aktivitas)
• /admin/produk (kelola produk, termasuk nonaktifkan)
• /admin/void (persetujuan void)
• /admin/toko (profil toko)
Proteksi route dilakukan lewat Next.js middleware berdasarkan peran, dan tetap divalidasi ulang di backend.
15. Roadmap dan Prioritas Pengerjaan
Fase 1: Fondasi (Minggu 1)
• Setup repo, Supabase project, skema database, dan seed data.
• Login, peran, dan middleware otorisasi.
• CRUD produk, kategori, dan stok.
Fase 2: Inti Kasir (Minggu 2)
• Halaman POS, transaksi atomik, dan pengurangan stok.
• Cetak struk dan alert stok menipis.
Fase 3: Sisi User (Minggu 3)
• Katalog, keranjang, pesanan, dan konfirmasi pembayaran oleh kasir.
• Status pesanan dan pembatalan otomatis.
Fase 4: Laporan dan Admin (Minggu 4)
• Penghitungan modal dan untung, rekap harian, dan ekspor PDF/Excel.
• CRUD kasir, log sesi login/logout, log aktivitas, dan profil toko.
Fase 5: Penyempurnaan (Minggu 5)
• Void dan retur dengan persetujuan, buka/tutup kas.
• Dashboard admin, pengujian, perbaikan bug, dan uji coba dengan anggota OSIS.
MVP minimum jika waktu mepet: Fase 1 sampai 3 ditambah rekap harian sederhana dan profil toko.
16. Rencana Pengujian
• Unit test untuk perhitungan total, laba, dan kembalian.
• Integration test untuk endpoint transaksi, stok, dan otorisasi peran.
• Uji konkurensi: dua kasir menjual produk yang sama dengan stok tersisa 1, hanya satu yang berhasil.
• UAT: simulasi satu hari bazar dengan data nyata, bandingkan rekap sistem dengan uang fisik.
17. Risiko dan Mitigasi
• Koneksi internet sekolah tidak stabil: siapkan hotspot cadangan, sediakan prosedur pencatatan manual darurat, dan pertimbangkan penyimpanan keranjang sementara di browser.
• Selisih uang kas: gunakan fitur buka/tutup kas dan log aktivitas.
• Salah input harga atau stok: batasi hak ubah harga hanya untuk admin atau catat semua perubahan di log.
• Printer struk tidak tersedia: sediakan opsi cetak ke PDF dan struk digital yang bisa disimpan.
• Waktu pengerjaan terbatas: kerjakan berdasarkan prioritas P0, lalu P1, lalu P2.
• Batas gratis Supabase atau hosting: pantau pemakaian dan pastikan ukuran data kecil (tanpa foto beresolusi besar).
18. Pertanyaan Terbuka
• Apakah user wajib punya akun, atau cukup memesan dengan memasukkan nama dan kelas?
• Metode pembayaran apa saja yang benar-benar dipakai saat acara (tunai saja, atau juga QRIS/transfer)?
• Apakah kasir boleh mengubah harga jual, atau hanya admin?
• Ukuran kertas printer struk yang tersedia (58mm, 80mm, atau tidak ada printer)?
• Berapa jumlah kasir dan perangkat yang akan dipakai bersamaan saat acara?
• Apakah diperlukan fitur diskon atau promo pada acara tahun ini?
