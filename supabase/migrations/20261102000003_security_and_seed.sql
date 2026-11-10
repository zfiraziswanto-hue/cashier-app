-- Migration: Security & Seed Data
-- Purpose: Complete RLS policies + Idempotent seed data
-- Created: 2026-11-02

-- ============================================================================
-- HELPER FUNCTION: get_my_role()
-- ============================================================================
-- Helper function untuk ambil role user saat ini dari database
-- Menghindari pengulangan query di setiap policy

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role
  FROM profiles
  WHERE id = auth.uid() AND is_active = true;
  
  RETURN COALESCE(v_role, 'anonymous');
EXCEPTION WHEN OTHERS THEN
  RETURN 'anonymous';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Enable RLS on tables yang belum
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE cashier_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE void_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 1. TRANSACTIONS POLICIES
-- ============================================================================
-- kasir: hanya transaksi miliknya sendiri
-- admin: semua transaksi
-- user: tidak punya akses

CREATE POLICY "Users cannot access transactions"
  ON transactions FOR ALL
  USING (get_my_role() = 'user');

CREATE POLICY "Kasir can read own transactions"
  ON transactions FOR SELECT
  USING (get_my_role() = 'kasir' AND kasir_id = auth.uid());

CREATE POLICY "Kasir can write transactions"
  ON transactions FOR INSERT
  WITH CHECK (get_my_role() = 'kasir');

CREATE POLICY "Admin can access all transactions"
  ON transactions FOR ALL
  USING (get_my_role() = 'admin');

-- ============================================================================
-- 2. ORDERS & ORDER_ITEMS POLICIES
-- ============================================================================
-- user: hanya order miliknya
-- kasir: semua orders (untuk konfirmasi pembayaran)
-- admin: semua orders

-- orders policies
CREATE POLICY "Users can read own orders"
  ON orders FOR SELECT
  USING (get_my_role() = 'user' AND user_id = auth.uid());

CREATE POLICY "Users can create orders"
  ON orders FOR INSERT
  WITH CHECK (get_my_role() = 'user' AND user_id = auth.uid());

CREATE POLICY "Users can update own orders (cancel)"
  ON orders FOR UPDATE
  USING (get_my_role() = 'user' AND user_id = auth.uid())
  WITH CHECK (get_my_role() = 'user' AND user_id = auth.uid());

CREATE POLICY "Kasir can read all orders"
  ON orders FOR SELECT
  USING (get_my_role() = 'kasir');

CREATE POLICY "Kasir can update orders (confirm payment)"
  ON orders FOR UPDATE
  USING (get_my_role() = 'kasir');

CREATE POLICY "Admin can read all orders"
  ON orders FOR SELECT
  USING (get_my_role() = 'admin');

CREATE POLICY "Admin can update orders"
  ON orders FOR UPDATE
  USING (get_my_role() = 'admin');

-- order_items policies (follow orders)
CREATE POLICY "Users can read own order items"
  ON order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_items.order_id 
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Kasir can read all order items"
  ON order_items FOR SELECT
  USING (get_my_role() = 'kasir');

CREATE POLICY "Admin can read all order items"
  ON order_items FOR SELECT
  USING (get_my_role() = 'admin');

-- ============================================================================
-- 3. ACTIVITY_LOGS POLICIES
-- ============================================================================
-- admin: semua activity logs
-- kasir: tidak punya akses
-- user: tidak punya akses

CREATE POLICY "Only admin can read activity_logs"
  ON activity_logs FOR SELECT
  USING (get_my_role() = 'admin');

CREATE POLICY "Only admin can insert activity_logs"
  ON activity_logs FOR INSERT
  WITH CHECK (get_my_role() = 'admin');

-- ============================================================================
-- 4. CASHIER_SESSIONS POLICIES
-- ============================================================================
-- kasir: hanya sesinya sendiri
-- admin: semua sessions

CREATE POLICY "Kasir can read own sessions"
  ON cashier_sessions FOR SELECT
  USING (get_my_role() = 'kasir' AND kasir_id = auth.uid());

CREATE POLICY "Admin can read all sessions"
  ON cashier_sessions FOR SELECT
  USING (get_my_role() = 'admin');

CREATE POLICY "Only system can insert sessions (via RPC)"
  ON cashier_sessions FOR INSERT
  WITH CHECK (get_my_role() = 'service_role');

CREATE POLICY "Only system can update sessions (via RPC)"
  ON cashier_sessions FOR UPDATE
  USING (get_my_role() = 'service_role');

-- ============================================================================
-- 5. VOID_REQUESTS POLICIES
-- ============================================================================
-- admin: semua void requests
-- kasir: hanya request yang ia buat

CREATE POLICY "Kasir can read own void requests"
  ON void_requests FOR SELECT
  USING (get_my_role() = 'kasir' AND diajukan_oleh = auth.uid());

CREATE POLICY "Kasir can create void requests"
  ON void_requests FOR INSERT
  WITH CHECK (get_my_role() = 'kasir' AND diajukan_oleh = auth.uid());

CREATE POLICY "Admin can read all void requests"
  ON void_requests FOR SELECT
  USING (get_my_role() = 'admin');

CREATE POLICY "Only admin can update void requests (approve/reject)"
  ON void_requests FOR UPDATE
  USING (get_my_role() = 'admin');

-- ============================================================================
-- 6. PRODUCTS POLICIES
-- ============================================================================
-- All authenticated users: READ active products
-- kasir/admin: CREATE, READ, UPDATE (products + stock)
-- admin: DELETE (soft delete)

CREATE POLICY "Users can read active products"
  ON products FOR SELECT
  USING (
    get_my_role() != 'anonymous' AND is_active = true
  );

CREATE POLICY "Kasir can read all products"
  ON products FOR SELECT
  USING (get_my_role() = 'kasir');

CREATE POLICY "Admin can read all products"
  ON products FOR SELECT
  USING (get_my_role() = 'admin');

CREATE POLICY "Kasir can create products"
  ON products FOR INSERT
  WITH CHECK (get_my_role() = 'kasir');

CREATE POLICY "Kasir can update products (stock & info)"
  ON products FOR UPDATE
  USING (get_my_role() = 'kasir');

CREATE POLICY "Admin can delete products (soft delete)"
  ON products FOR DELETE
  USING (get_my_role() = 'admin');

-- ============================================================================
-- 7. CATEGORIES POLICIES
-- ============================================================================
-- All authenticated users: READ
-- kasir/admin: CREATE, READ, UPDATE
-- admin: DELETE

CREATE POLICY "Users can read categories"
  ON categories FOR SELECT
  USING (get_my_role() != 'anonymous');

CREATE POLICY "Kasir can read categories"
  ON categories FOR SELECT
  USING (get_my_role() = 'kasir');

CREATE POLICY "Kasir can create categories"
  ON categories FOR INSERT
  WITH CHECK (get_my_role() = 'kasir');

CREATE POLICY "Kasir can update categories"
  ON categories FOR UPDATE
  USING (get_my_role() = 'kasir');

CREATE POLICY "Admin can delete categories"
  ON categories FOR DELETE
  USING (get_my_role() = 'admin');

-- ============================================================================
-- 8. STORE_SETTINGS POLICIES
-- ============================================================================
-- All authenticated users: READ
-- admin: UPDATE

CREATE POLICY "Users can read store settings"
  ON store_settings FOR SELECT
  USING (get_my_role() != 'anonymous');

CREATE POLICY "Only admin can update store settings"
  ON store_settings FOR UPDATE
  USING (get_my_role() = 'admin');

-- ============================================================================
-- 9. PROFILES POLICIES
-- ============================================================================
-- Prevent infinite recursion: only allow SELECT
-- All authenticated users: READ (basic info)

CREATE POLICY "Users can read profiles"
  ON profiles FOR SELECT
  USING (get_my_role() != 'anonymous');

-- ============================================================================
-- 10. STOCK_MOVEMENTS POLICIES
-- ============================================================================
-- All authenticated users: READ (audit trail)

CREATE POLICY "Users can read stock movements"
  ON stock_movements FOR SELECT
  USING (get_my_role() != 'anonymous');

-- ============================================================================
-- REVOKE PUBLIC ACCESS TO PROFILES
-- ============================================================================
-- Disable RLS on profiles untuk mencegah infinite recursion
-- hanya SELECT via get_my_role()

ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SEED DATA (IDEMPOTENT)
-- ============================================================================
-- Gunakan ON CONFLICT untuk safety - bisa dijalankan berulang tanpa error

-- Seed 1: Create admin user (via auth.users + profiles trigger)
-- Password: admin123 (dev only - ganti di production!)
INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_user_meta_data, is_super_admin, role
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'admin@osis.local',
  crypt('admin123', gen_salt('bf', 10)),
  NOW(),
  NOW(),
  NOW(),
  '{"name": "Admin OSIS"}'::jsonb,
  false,
  'authenticated'
) ON CONFLICT (email) DO NOTHING;

-- Insert admin profile
INSERT INTO profiles (id, nama, username, role)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Admin OSIS',
  'admin_osis',
  'admin'
) ON CONFLICT (id) DO NOTHING;

-- Seed 2: Create kasir users
INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_user_meta_data, is_super_admin, role
) VALUES (
  '00000000-0000-0000-0000-000000000002',
  'kasir1@osis.local',
  crypt('kasir123', gen_salt('bf', 10)),
  NOW(),
  NOW(),
  NOW(),
  '{"name": "Kasir 1"}'::jsonb,
  false,
  'authenticated'
) ON CONFLICT (email) DO NOTHING;

INSERT INTO profiles (id, nama, username, role)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'Kasir 1',
  'kasir1',
  'kasir'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_user_meta_data, is_super_admin, role
) VALUES (
  '00000000-0000-0000-0000-000000000003',
  'kasir2@osis.local',
  crypt('kasir123', gen_salt('bf', 10)),
  NOW(),
  NOW(),
  NOW(),
  '{"name": "Kasir 2"}'::jsonb,
  false,
  'authenticated'
) ON CONFLICT (email) DO NOTHING;

INSERT INTO profiles (id, nama, username, role)
VALUES (
  '00000000-0000-0000-0000-000000000003',
  'Kasir 2',
  'kasir2',
  'kasir'
) ON CONFLICT (id) DO NOTHING;

-- Seed 3: Create user (pembeli)
INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_user_meta_data, is_super_admin, role
) VALUES (
  '00000000-0000-0000-0000-000000000004',
  'user@osis.local',
  crypt('user123', gen_salt('bf', 10)),
  NOW(),
  NOW(),
  NOW(),
  '{"name": "User Siswa"}'::jsonb,
  false,
  'authenticated'
) ON CONFLICT (email) DO NOTHING;

INSERT INTO profiles (id, nama, username, role)
VALUES (
  '00000000-0000-0000-0000-000000000004',
  'Budi Santoso',
  'budi_s',
  'user'
) ON CONFLICT (id) DO NOTHING;

-- Seed 4: Categories (idempotent)
INSERT INTO categories (nama, is_active)
VALUES ('Makanan', true), ('Minuman', true), ('Merchandise', true)
ON CONFLICT DO NOTHING;

-- Seed 5: Store Settings (idempotent)
INSERT INTO store_settings (nama_toko, alamat, kontak, footer_struk)
VALUES (
  'Kantin OSIS Sekolahnesia',
  'Jl. Sekolah No. 1, Jakarta',
  '021-12345678',
  'Terima kasih telah berbelanja di Kantin OSIS!'
)
ON CONFLICT DO NOTHING;

-- Seed 6: Products (idempotent - 18 products dengan variasi stok)
-- 2 products stok rendah, 1 produk stok 0
INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Roti Bakar',
  5000,
  8000,
  50,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Roti Bakar');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Mie Goreng',
  4000,
  7000,
  50,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Mie Goreng');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Es Teh Manis',
  2000,
  4000,
  100,
  20,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Es Teh Manis');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Kopi Susu',
  3000,
  6000,
  100,
  20,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Kopi Susu');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Gantungan Kunci OSIS',
  5000,
  10000,
  20,
  5,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Gantungan Kunci OSIS');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Stiker OSIS',
  1000,
  3000,
  100,
  50,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Stiker OSIS');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Siomay Goreng',
  5000,
  9000,
  50,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Siomay Goreng');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Air Mineral 600ml',
  2000,
  3000,
  200,
  50,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Air Mineral 600ml');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Kaos OSIS',
  50000,
  85000,
  10,
  5,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Kaos OSIS');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Batagor',
  6000,
  10000,
  40,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Batagor');

-- 2 Products stok rendah (alert threshold)
INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Nasi Goreng Spesial',
  8000,
  15000,
  8,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Nasi Goreng Spesial');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Jus Mangga',
  5000,
  10000,
  5,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Jus Mangga');

-- 1 Product stok 0 (out of stock)
INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Totebag OSIS Limited',
  15000,
  35000,
  0,
  5,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Totebag OSIS Limited');

-- Additional products (9 more)
INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Pisang Goreng',
  3000,
  5000,
  30,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Pisang Goreng');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Es Jeruk',
  3000,
  6000,
  50,
  20,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Es Jeruk');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Lapel Pin OSIS',
  2000,
  5000,
  25,
  5,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Lapel Pin OSIS');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Paha Ayam Goreng',
  7000,
  12000,
  35,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Paha Ayam Goreng');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Susu Coklat',
  4000,
  8000,
  40,
  15,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Susu Coklat');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Buku Catatan OSIS',
  10000,
  25000,
  15,
  5,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Buku Catatan OSIS');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Makanan' LIMIT 1),
  'Sosis Bakar',
  4000,
  7000,
  45,
  10,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Sosis Bakar');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Minuman' LIMIT 1),
  'Teh Botol',
  3000,
  6000,
  80,
  25,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Teh Botol');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, foto_url, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Merchandise' LIMIT 1),
  'Tumbler OSIS',
  25000,
  55000,
  8,
  5,
  NULL,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Tumbler OSIS');

-- ============================================================================
-- GRANT EXECUTE ON HELPER FUNCTION
-- ============================================================================
GRANT EXECUTE ON FUNCTION get_my_role() TO authenticated;
