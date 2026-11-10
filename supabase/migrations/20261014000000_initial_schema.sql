-- Enums
CREATE TYPE user_role AS ENUM ('admin', 'kasir', 'user');
CREATE TYPE order_status AS ENUM ('menunggu_pembayaran', 'dibayar', 'selesai', 'dibatalkan');
CREATE TYPE transaction_status AS ENUM ('selesai', 'void');
CREATE TYPE payment_method AS ENUM ('tunai', 'qris', 'transfer');
CREATE TYPE stock_movement_type AS ENUM ('masuk', 'keluar', 'koreksi', 'retur');
CREATE TYPE void_status AS ENUM ('menunggu', 'disetujui', 'ditolak');

-- Tables
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  role user_role NOT NULL DEFAULT 'user',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE store_settings (
  id SERIAL PRIMARY KEY,
  nama_toko TEXT NOT NULL,
  logo_url TEXT,
  alamat TEXT,
  kontak TEXT,
  footer_struk TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  nama TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  category_id INTEGER REFERENCES categories(id),
  nama TEXT NOT NULL,
  harga_modal INTEGER NOT NULL CHECK (harga_modal >= 0),
  harga_jual INTEGER NOT NULL CHECK (harga_jual >= 0),
  stok INTEGER NOT NULL DEFAULT 0 CHECK (stok >= 0),
  stok_minimum INTEGER NOT NULL DEFAULT 0,
  foto_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE stock_movements (
  id SERIAL PRIMARY KEY,
  product_id INTEGER REFERENCES products(id),
  tipe stock_movement_type NOT NULL,
  jumlah INTEGER NOT NULL CHECK (jumlah > 0),
  stok_sebelum INTEGER NOT NULL,
  stok_sesudah INTEGER NOT NULL,
  referensi_id INTEGER,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  kode_pesanan TEXT UNIQUE NOT NULL,
  user_id UUID REFERENCES profiles(id),
  status order_status NOT NULL DEFAULT 'menunggu_pembayaran',
  total INTEGER NOT NULL CHECK (total >= 0),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id),
  product_id INTEGER REFERENCES products(id),
  qty INTEGER NOT NULL CHECK (qty > 0),
  harga_jual INTEGER NOT NULL,
  harga_modal INTEGER NOT NULL
);

CREATE TABLE transactions (
  id SERIAL PRIMARY KEY,
  nomor_transaksi TEXT UNIQUE NOT NULL,
  order_id INTEGER REFERENCES orders(id),
  kasir_id UUID REFERENCES profiles(id),
  subtotal INTEGER NOT NULL,
  diskon INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL,
  total_modal INTEGER NOT NULL,
  laba INTEGER NOT NULL,
  metode_bayar payment_method NOT NULL,
  uang_diterima INTEGER NOT NULL,
  kembalian INTEGER NOT NULL,
  status transaction_status NOT NULL DEFAULT 'selesai',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE transaction_items (
  id SERIAL PRIMARY KEY,
  transaction_id INTEGER REFERENCES transactions(id),
  product_id INTEGER REFERENCES products(id),
  nama_produk TEXT NOT NULL,
  qty INTEGER NOT NULL CHECK (qty > 0),
  harga_jual INTEGER NOT NULL,
  harga_modal INTEGER NOT NULL
);

CREATE TABLE void_requests (
  id SERIAL PRIMARY KEY,
  transaction_id INTEGER REFERENCES transactions(id),
  diajukan_oleh UUID REFERENCES profiles(id),
  alasan TEXT,
  status void_status NOT NULL DEFAULT 'menunggu',
  diproses_oleh UUID REFERENCES profiles(id),
  diproses_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE cashier_sessions (
  id SERIAL PRIMARY KEY,
  kasir_id UUID REFERENCES profiles(id),
  login_at TIMESTAMPTZ NOT NULL,
  logout_at TIMESTAMPTZ,
  kas_awal INTEGER NOT NULL,
  kas_akhir INTEGER,
  selisih INTEGER
);

CREATE TABLE activity_logs (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  aksi TEXT NOT NULL,
  entitas TEXT NOT NULL,
  entitas_id INTEGER,
  detail JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
CREATE INDEX idx_transactions_kasir_id ON transactions(kasir_id);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_orders_kode_pesanan ON orders(kode_pesanan);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER update_store_settings_updated_at BEFORE UPDATE ON store_settings FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Function to create profile on auth.user insert
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nama, username, role)
  VALUES (new.id, new.raw_user_meta_data->>'name', new.email, 'user');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read active products" ON products FOR SELECT USING (is_active = true);
CREATE POLICY "Users can read own orders" ON orders FOR SELECT USING (auth.uid() = user_id);
