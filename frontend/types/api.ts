// Types for API responses

export interface Product {
  id: number;
  category_id: number;
  nama: string;
  harga_modal: number;
  harga_jual: number;
  stok: number;
  stok_minimum: number;
  foto_url: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  categories?: {
    nama: string;
  };
}

export interface Category {
  id: number;
  nama: string;
  is_active: boolean;
}

export interface Order {
  id: number;
  kode_pesanan: string;
  user_id: string;
  status: 'menunggu_pembayaran' | 'dibayar' | 'selesai' | 'dibatalkan';
  total: number;
  expires_at: string;
  created_at: string;
  order_items?: OrderItem[];
}

export interface OrderItem {
  id: number;
  order_id: number;
  product_id: number;
  qty: number;
  harga_jual: number;
  harga_modal: number;
}

export interface Transaction {
  id: number;
  nomor_transaksi: string;
  order_id: number | null;
  kasir_id: string;
  subtotal: number;
  diskon: number;
  total: number;
  total_modal: number;
  laba: number;
  metode_bayar: 'tunai' | 'qris' | 'transfer';
  uang_diterima: number;
  kembalian: number;
  status: 'selesai' | 'void';
  created_at: string;
  transaction_items?: TransactionItem[];
}

export interface TransactionItem {
  id: number;
  transaction_id: number;
  product_id: number;
  nama_produk: string;
  qty: number;
  harga_jual: number;
  harga_modal: number;
}

export interface User {
  id: string;
  email: string;
  role: 'admin' | 'kasir' | 'user';
  nama: string;
  username?: string;
  is_active: boolean;
  created_at: string;
}

export interface StoreSettings {
  id: number;
  nama_toko: string;
  logo_url: string | null;
  alamat: string | null;
  kontak: string | null;
  footer_struk: string | null;
  updated_at: string;
}

export interface ActivityLog {
  id: number;
  user_id: string;
  aksi: string;
  entitas: string;
  entitas_id: number | null;
  detail: Record<string, any>;
  created_at: string;
  profiles?: {
    nama: string;
  };
}
