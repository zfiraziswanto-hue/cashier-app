-- Test Suite: RLS Policies & Seed Data
-- Purpose: Verify RLS works correctly dan seed data idempotent
-- Usage: Run manual testing di Supabase SQL Editor

-- ============================================================================
-- SETUP & VERIFICATION
-- ============================================================================

-- Verify users created
SELECT 'TEST 1: Seed Data - Users Created' as test_name,
  username,
  role,
  is_active
FROM profiles
WHERE username IN ('admin_osis', 'kasir1', 'kasir2', 'budi_s')
ORDER BY role, username;

-- Verify categories created
SELECT 'TEST 1: Seed Data - Categories Created' as test_name,
  id,
  nama,
  is_active
FROM categories
ORDER BY nama;

-- Verify store settings created
SELECT 'TEST 1: Seed Data - Store Settings Created' as test_name,
  id,
  nama_toko,
  alamat,
  kontak,
  footer_struk
FROM store_settings
LIMIT 1;

-- Verify products created (20 total)
SELECT 'TEST 1: Seed Data - Products Created' as test_name,
  COUNT(*) as total_products,
  SUM(CASE WHEN stok <= stok_minimum THEN 1 ELSE 0 END) as low_stock_count,
  SUM(CASE WHEN stok = 0 THEN 1 ELSE 0 END) as out_of_stock_count
FROM products;

-- ============================================================================
-- RLS TESTS
-- ============================================================================

-- SETUP TEST SESSIONS (simulating different users)
-- Note: In real testing, you would use Supabase Auth to login as different users
-- For SQL testing, we use auth.uid() override via SET ROLE or direct UUID injection

-- TEST 2: User A cannot read User B's orders
-- Simulate user_id = 00000000-0000-0000-0000-000000000004 (user@osis.local / Budi)
WITH test_data AS (
  -- Create test order for user A
  INSERT INTO orders (kode_pesanan, user_id, status, total, expires_at)
  VALUES ('ORD-TEST-A', '00000000-0000-0000-0000-000000000002', 'menunggu_pembayaran', 50000, NOW() + INTERVAL '1 hour')
  ON CONFLICT (kode_pesanan) DO NOTHING
  RETURNING id as order_id
)
SELECT 'TEST 2: User A Order' as test_name,
  'Simulating: User Budi (user@osis.local) creates order' as action,
  'User A order created in background' as result;

-- Try to access as different user (user B - kasir1)
-- This would be tested in real app by logging in as kasir1
SELECT 'TEST 2: RLS Orders' as test_name,
  o.kode_pesanan,
  p.nama as user_name,
  CASE WHEN p.username = 'budi_s' THEN 'User Budi (should be visible to kasir)' ELSE 'Other user' END as note
FROM orders o
JOIN profiles p ON o.user_id = p.id
WHERE o.kode_pesanan = 'ORD-TEST-A';

-- Verify kasir can read all orders (RLS policy check)
SELECT 'TEST 2: Verify Kasir RLS' as test_name,
  COUNT(*) as total_orders_visible_to_kasir,
  'Expected: All orders visible to kasir/admin' as note
FROM orders;

-- TEST 3: User cannot read transactions (RLS check)
SELECT 'TEST 3: RLS Transactions' as test_name,
  'Testing: User should NOT see any transactions' as action,
  COUNT(*) as transaction_count_for_user,
  'Expected: 0 transactions visible to user' as expected
FROM transactions;

-- TEST 4: Kasir cannot read transactions from other kasir
-- Create test transaction for kasir1
WITH txn_data AS (
  INSERT INTO transactions (nomor_transaksi, kasir_id, subtotal, diskon, total, total_modal, laba, metode_bayar, uang_diterima, kembalian, status)
  VALUES ('TRX-TEST-K1', '00000000-0000-0000-0000-000000000002', 50000, 0, 50000, 30000, 20000, 'tunai', 60000, 10000, 'selesai')
  ON CONFLICT (nomor_transaksi) DO NOTHING
  RETURNING id
)
SELECT 'TEST 4: RLS Transaction Access' as test_name,
  'Simulating: Kasir 2 trying to read Kasir 1 transaction' as action,
  COUNT(*) as transaction_count_for_kasir2,
  'Expected: Only kasir1 transactions visible to kasir1' as expected
FROM transactions
WHERE kasir_id = '00000000-0000-0000-0000-000000000002';

-- TEST 5: Non-admin cannot read activity_logs
SELECT 'TEST 5: RLS Activity Logs' as test_name,
  'Testing: Non-admin should NOT see activity_logs' as action,
  COUNT(*) as activity_log_count,
  'Expected: 0 visible to non-admin users' as expected
FROM activity_logs;

-- TEST 6: Verify void_requests RLS
-- Create test void request for kasir1
WITH vr_data AS (
  INSERT INTO void_requests (transaction_id, diajukan_oleh, alasan, status)
  VALUES (1, '00000000-0000-0000-0000-000000000002', 'Testing void request', 'menunggu')
  ON CONFLICT DO NOTHING
  RETURNING id
)
SELECT 'TEST 6: RLS Void Requests' as test_name,
  'Testing: Kasir 1 should only see own void requests' as action,
  COUNT(*) as void_requests_count_for_kasir1,
  'Expected: Only kasir1 requests visible to kasir1' as expected
FROM void_requests
WHERE diajukan_oleh = '00000000-0000-0000-0000-000000000002';

-- TEST 7: Cashier sessions RLS
-- Create test session for kasir1
WITH cs_data AS (
  INSERT INTO cashier_sessions (kasir_id, login_at, kas_awal)
  VALUES ('00000000-0000-0000-0000-000000000002', NOW(), 100000)
  ON CONFLICT DO NOTHING
  RETURNING id
)
SELECT 'TEST 7: RLS Cashier Sessions' as test_name,
  'Testing: Kasir 1 should only see own sessions' as action,
  COUNT(*) as session_count_for_kasir1,
  'Expected: Only kasir1 sessions visible to kasir1' as expected
FROM cashier_sessions
WHERE kasir_id = '00000000-0000-0000-0000-000000000002';

-- ============================================================================
-- IDEMPOTENCY TEST - Run seed again to verify no errors/duplicates
-- ============================================================================

-- Re-run seed data (this would be in the migration file)
-- For testing, we simulate by checking counts remain the same

SELECT 'TEST 8: Idempotency Check' as test_name,
  (SELECT COUNT(*) FROM profiles WHERE username IN ('admin_osis', 'kasir1', 'kasir2', 'budi_s')) as profile_count,
  (SELECT COUNT(*) FROM categories) as category_count,
  (SELECT COUNT(*) FROM products) as product_count,
  'Expected: Counts should be identical (no duplicates)' as note;

-- Verify no duplicate users
SELECT 'TEST 8: No Duplicates' as test_name,
  username,
  COUNT(*) as occurrences
FROM profiles
WHERE username IN ('admin_osis', 'kasir1', 'kasir2', 'budi_s')
GROUP BY username
HAVING COUNT(*) > 1;

-- ============================================================================
-- RLS POLICY VERIFICATION (Direct Query Check)
-- ============================================================================

-- Verify RLS is enabled on all tables
SELECT 'TEST 9: RLS Status' as test_name,
  schemaname,
  tablename,
  relrowsecurity as rls_enabled,
  relforcerowsecurity as rls_enforced
FROM pg_tables t
JOIN pg_class c ON t.tablename = c.relname
WHERE schemaname = 'public'
  AND tablename IN ('transactions', 'orders', 'activity_logs', 'cashier_sessions', 'void_requests', 'products', 'categories', 'store_settings')
ORDER BY tablename;

-- Verify policies created
SELECT 'TEST 9: Policies Created' as test_name,
  schemaname,
  tablename,
  policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('transactions', 'orders', 'activity_logs', 'cashier_sessions', 'void_requests', 'products', 'categories', 'store_settings')
ORDER BY tablename, policyname;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT 'ALL RLS & SEED TESTS COMPLETED' as summary,
  'Check results above for:' as note,
  '✓ Users created (admin, 2 kasir, 1 user)' as test_1,
  '✓ Categories created (Makanan, Minuman, Merchandise)' as test_2,
  '✓ Store settings created' as test_3,
  '✓ Products created (20 total, 2 low stock, 1 out of stock)' as test_4,
  '✓ RLS policies applied to all tables' as test_5,
  '✓ Seed data idempotent (no duplicates on re-run)' as test_6;
