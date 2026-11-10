# Skenario Uji Coba (UAT) - Bazar OSIS

Dokumen ini berisi langkah-langkah pengujian end-to-end (UAT) untuk memastikan seluruh fungsionalitas aplikasi kasir OSIS berjalan sesuai PRD.

## Skenario 1: Transaksi Tunai Langsung di Kasir
1. **Langkah**: Kasir login ke `/login`, lalu membuka menu `/kasir` (POS).
2. **Aksi**: Tambah produk "Es Teh" (stok 100) ke keranjang sejumlah 2. Masukkan metode pembayaran Tunai dengan uang diterima Rp 10.000.
3. **Hasil yang Diharapkan**:
   - Total harga Rp 8.000, kembalian Rp 2.000 terhitung otomatis.
   - Transaksi berhasil disimpan, nomor transaksi `TRX-YYYYMMDD-XXXX` tercetak.
   - Stok "Es Teh" berkurang menjadi 98 di database.

## Skenario 2: Pemesanan oleh User & Konfirmasi Kasir
1. **Langkah**: User login, membuka `/katalog`, menambahkan "Roti Bakar" ke keranjang, lalu membuat pesanan.
2. **Aksi**: User mendapatkan kode pesanan `ORD-YYYYMMDD-XXXX`.
3. **Konfirmasi Kasir**: Kasir membuka `/kasir/pesanan`, memasukkan kode pesanan, lalu menekan "Konfirmasi Pembayaran".
4. **Hasil yang Diharapkan**:
   - Stok produk berkurang otomatis saat pembayaran dikonfirmasi.
   - Status pesanan berubah menjadi `dibayar` lalu `selesai`.

## Skenario 3: Pengajuan Void oleh Kasir & Persetujuan Admin
1. **Langkah**: Kasir membuka riwayat transaksi, memilih transaksi yang baru dibuat, lalu mengajukan void dengan alasan "Salah input jumlah".
2. **Aksi**: Admin login, membuka `/admin/void`, lalu menyetujui pengajuan tersebut.
3. **Hasil yang Diharapkan**:
   - Status transaksi berubah menjadi `void`.
   - Stok produk dikembalikan secara atomik ke jumlah semula.
   - Laporan laba/rugi otomatis menyesuaikan (mengabaikan transaksi void).
