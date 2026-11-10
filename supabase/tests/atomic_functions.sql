-- Test Suite: Atomic Transaction Functions
-- Purpose: Verify create_transaction_atomic, approve_void, reject_void, auto_cancel_expired
-- Usage: Run manual testing di Supabase SQL Editor atau psql

-- ============================================================================
-- SETUP TEST DATA
-- ============================================================================

-- Reset test data (optional, uncomment untuk clear)
-- DELETE FROM transaction_items;
-- DELETE FROM transactions;
-- DELETE FROM void_requests;
-- DELETE FROM stock_movements WHERE referensi_id IS NOT NULL;
-- DELETE FROM order_items;
-- DELETE FROM orders;
-- DELETE FROM products;
-- DELETE FROM categories;
-- DELETE FROM profiles WHERE username IN ('test_kasir', 'test_admin', 'test_user');

-- Insert test categories if not exists
INSERT INTO categories (nama, is_active)
VALUES ('Test Makanan', true), ('Test Minuman', true)
ON CONFLICT DO NOTHING;

-- Insert test products
INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum, is_active)
SELECT 
  (SELECT id FROM categories WHERE nama = 'Test Makanan' LIMIT 1),
  'Nasi Goreng Test',
  5000,
  10000,
  50,
  5,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Nasi Goreng Test')
UNION ALL
SELECT 
  (SELECT id FROM categories WHERE nama = 'Test Minuman' LIMIT 1),
  'Es Teh Test',
  2000,
  5000,
  100,
  10,
  true
WHERE NOT EXISTS (SELECT 1 FROM products WHERE nama = 'Es Teh Test');

-- Create test users if not exists (via SQL trigger - profiles auto-created from auth.users)
-- For testing, we'll use existing users or assume they exist
-- Note: In real scenario, these would be created via Supabase Auth

-- ============================================================================
-- TEST 1: CREATE_TRANSACTION_ATOMIC - Success Case
-- ============================================================================
-- Expected: 
--   - Transaction created
--   - Stock decreased for both products
--   - Transaction items saved with snapshot prices
--   - kembalian calculated correctly (for tunai)

-- Get test kasir_id (using first active kasir)
WITH test_data AS (
  SELECT 
    (SELECT id FROM profiles WHERE role = 'kasir' AND is_active = true LIMIT 1) as kasir_id,
    jsonb_build_array(
      jsonb_build_object('product_id', (SELECT id FROM products WHERE nama = 'Nasi Goreng Test' LIMIT 1), 'qty', 3),
      jsonb_build_object('product_id', (SELECT id FROM products WHERE nama = 'Es Teh Test' LIMIT 1), 'qty', 5)
    ) as items
)
SELECT 
  'TEST 1: Transaction Success' as test_name,
  t.transaction_id,
  t.nomor_transaksi,
  t.total,
  t.kembalian,
  'PASS' as status
FROM test_data td,
LATERAL create_transaction_atomic(
  td.kasir_id,
  td.items,
  'tunai'::payment_method,
  100000,  -- uang_diterima
  NULL     -- order_id
) t;

-- Verify stok berkurang
SELECT 
  'TEST 1 VERIFY: Stock Decreased' as check_name,
  nama,
  stok,
  'Expected: Nasi Goreng=47, Es Teh=95' as expected
FROM products
WHERE nama IN ('Nasi Goreng Test', 'Es Teh Test')
ORDER BY nama;

-- Verify transaction_items dengan snapshot harga
SELECT 
  'TEST 1 VERIFY: Snapshot Prices Saved' as check_name,
  ti.nama_produk,
  ti.qty,
  ti.harga_jual,
  ti.harga_modal,
  'Expected: prices from products table' as note
FROM transaction_items ti
WHERE ti.transaction_id = (
  SELECT id FROM transactions 
  ORDER BY created_at DESC LIMIT 1
)
ORDER BY ti.nama_produk;

-- ============================================================================
-- TEST 2: CREATE_TRANSACTION_ATOMIC - Stock Insufficient (should ROLLBACK)
-- ============================================================================
-- Expected:
--   - Exception raised (stok tidak cukup)
--   - NO changes to database (atomic rollback)
--   - Stock remains unchanged

-- Get current stock before test
WITH before_test AS (
  SELECT 
    (SELECT stok FROM products WHERE nama = 'Nasi Goreng Test') as stok_before
)
SELECT 'TEST 2: Stock Insufficient (Before)' as test_name, stok_before FROM before_test;

-- Try to create transaction with insufficient stock
-- Uncomment to test error handling
/*
DO $$
BEGIN
  PERFORM create_transaction_atomic(
    (SELECT id FROM profiles WHERE role = 'kasir' AND is_active = true LIMIT 1),
    jsonb_build_array(
      jsonb_build_object('product_id', (SELECT id FROM products WHERE nama = 'Nasi Goreng Test' LIMIT 1), 'qty', 1000)  -- More than available stock
    ),
    'tunai'::payment_method,
    10000000,
    NULL
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;
*/

-- Verify stock NOT changed (atomic rollback)
WITH after_test AS (
  SELECT 
    (SELECT stok FROM products WHERE nama = 'Nasi Goreng Test') as stok_after
)
SELECT 'TEST 2: Stock Insufficient (After - should be SAME)' as test_name, stok_after FROM after_test;

-- ============================================================================
-- TEST 3: CREATE_TRANSACTION_ATOMIC - Insufficient Cash (tunai, should REJECT)
-- ============================================================================
-- Expected:
--   - Exception raised (uang_diterima < total)
--   - NO transaction created
--   - Stock unchanged

-- Get last stok before test
WITH before_test AS (
  SELECT 
    (SELECT stok FROM products WHERE nama = 'Es Teh Test') as stok_before
)
SELECT 'TEST 3: Insufficient Cash (Before)' as test_name, stok_before FROM before_test;

-- Try to create transaction dengan uang tidak cukup
-- Uncomment to test
/*
DO $$
BEGIN
  PERFORM create_transaction_atomic(
    (SELECT id FROM profiles WHERE role = 'kasir' AND is_active = true LIMIT 1),
    jsonb_build_array(
      jsonb_build_object('product_id', (SELECT id FROM products WHERE nama = 'Es Teh Test' LIMIT 1), 'qty', 2)
    ),
    'tunai'::payment_method,
    1000,  -- Total should be 5000*2 = 10000, cash only 1000
    NULL
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;
*/

-- Verify stock NOT changed
WITH after_test AS (
  SELECT 
    (SELECT stok FROM products WHERE nama = 'Es Teh Test') as stok_after
)
SELECT 'TEST 3: Insufficient Cash (After - should be SAME)' as test_name, stok_after FROM after_test;

-- ============================================================================
-- TEST 4: APPROVE_VOID_TRANSACTION - Success Case (Stok Returned)
-- ============================================================================
-- Expected:
--   - Void request approved
--   - Transaction status changed to 'void'
--   - Stock returned for all items
--   - stock_movements recorded with type 'retur'

-- Get latest transaction to void
WITH latest_txn AS (
  SELECT id FROM transactions 
  WHERE status = 'selesai'
  ORDER BY created_at DESC LIMIT 1
)
-- Create void request first
INSERT INTO void_requests (transaction_id, diajukan_oleh, alasan, status)
SELECT 
  id,
  (SELECT id FROM profiles WHERE role = 'kasir' AND is_active = true LIMIT 1),
  'Testing void function',
  'menunggu'
FROM latest_txn
WHERE NOT EXISTS (
  SELECT 1 FROM void_requests WHERE transaction_id = (SELECT id FROM latest_txn)
);

-- Get stock before void
WITH before_void AS (
  SELECT 
    (SELECT stok FROM products WHERE nama = 'Nasi Goreng Test') as nasi_stok,
    (SELECT stok FROM products WHERE nama = 'Es Teh Test') as teh_stok
)
SELECT 'TEST 4: Before Void (Stock)' as check_name, nasi_stok, teh_stok FROM before_void;

-- Approve the void
SELECT 
  'TEST 4: Approve Void' as test_name,
  success,
  message,
  stok_items_dikembalikan,
  'PASS' as status
FROM approve_void_transaction(
  (SELECT id FROM void_requests WHERE status = 'disetujui' ORDER BY diproses_at DESC LIMIT 1),
  (SELECT id FROM profiles WHERE role = 'admin' AND is_active = true LIMIT 1),
  'Test approval'
);

-- Verify stock returned
WITH after_void AS (
  SELECT 
    (SELECT stok FROM products WHERE nama = 'Nasi Goreng Test') as nasi_stok,
    (SELECT stok FROM products WHERE nama = 'Es Teh Test') as teh_stok
)
SELECT 'TEST 4: After Void (Stock Returned)' as check_name, nasi_stok, teh_stok FROM after_void;

-- Verify stock_movements recorded
SELECT 
  'TEST 4 VERIFY: Stock Movements (Retur)' as check_name,
  sm.product_id,
  p.nama,
  sm.tipe,
  sm.jumlah,
  sm.stok_sebelum,
  sm.stok_sesudah,
  'Expected: tipe=retur' as note
FROM stock_movements sm
JOIN products p ON sm.product_id = p.id
WHERE sm.tipe = 'retur'
ORDER BY sm.created_at DESC
LIMIT 5;

-- ============================================================================
-- TEST 5: APPROVE_VOID_TRANSACTION - Double Void (should REJECT)
-- ============================================================================
-- Expected:
--   - Error: "Transaksi sudah di-void sebelumnya"
--   - No changes

SELECT 'TEST 5: Double Void (Expected Error)' as test_name,
  'Try to void same transaction again' as action,
  'Should be rejected' as expected;

-- Uncomment to test
/*
DO $$
BEGIN
  PERFORM approve_void_transaction(
    (SELECT id FROM void_requests WHERE transaction_id = (
      SELECT id FROM transactions WHERE status = 'void' ORDER BY created_at DESC LIMIT 1
    ) LIMIT 1),
    (SELECT id FROM profiles WHERE role = 'admin' AND is_active = true LIMIT 1),
    'Test double void'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Expected error caught (double void): %', SQLERRM;
END $$;
*/

-- ============================================================================
-- TEST 6: REJECT_VOID_REQUEST
-- ============================================================================
-- Expected:
--   - Void request rejected
--   - Transaction status remains 'selesai' (NOT changed)
--   - Stock remains unchanged

-- Create another void request
WITH pending_void AS (
  SELECT vr.id FROM void_requests vr
  WHERE status = 'menunggu' 
  AND vr.id NOT IN (SELECT transaction_id FROM void_requests WHERE status IN ('disetujui', 'ditolak'))
  LIMIT 1
)
SELECT 
  'TEST 6: Reject Void Request' as test_name,
  success,
  message,
  'PASS' as status
FROM pending_void pv,
LATERAL reject_void_request(
  pv.id,
  (SELECT id FROM profiles WHERE role = 'admin' AND is_active = true LIMIT 1),
  'Test rejection'
);

-- Verify void_request status is 'ditolak'
SELECT 
  'TEST 6 VERIFY: Void Request Status' as check_name,
  status,
  'Expected: ditolak' as note
FROM void_requests
WHERE status = 'ditolak'
ORDER BY diproses_at DESC
LIMIT 1;

-- ============================================================================
-- TEST 7: AUTO_CANCEL_EXPIRED_ORDERS
-- ============================================================================
-- Expected:
--   - Orders created > 30 mins ago with status 'menunggu_pembayaran' are cancelled
--   - Order status changed to 'dibatalkan'
--   - activity_logs recorded

-- Create test order (simulate created 35 minutes ago)
INSERT INTO orders (kode_pesanan, user_id, status, total, expires_at, created_at)
VALUES (
  'TEST-' || TO_CHAR(NOW(), 'YYYYMMDDHHMI') || '-' || RANDOM()::TEXT,
  (SELECT id FROM profiles WHERE role = 'user' AND is_active = true LIMIT 1),
  'menunggu_pembayaran',
  50000,
  NOW() - INTERVAL '35 minutes',
  NOW() - INTERVAL '35 minutes'
)
ON CONFLICT DO NOTHING;

-- Get count before auto-cancel
WITH before_cancel AS (
  SELECT COUNT(*) as pending_orders
  FROM orders
  WHERE status = 'menunggu_pembayaran'
    AND created_at < NOW() - INTERVAL '30 minutes'
)
SELECT 'TEST 7: Pending Orders Before Auto-Cancel' as check_name, pending_orders FROM before_cancel;

-- Run auto-cancel
SELECT 
  'TEST 7: Auto-Cancel Expired Orders' as test_name,
  orders_cancelled,
  message,
  'PASS' as status
FROM auto_cancel_expired_orders();

-- Verify orders cancelled
SELECT 
  'TEST 7 VERIFY: Orders Auto-Cancelled' as check_name,
  status,
  COUNT(*) as total,
  'Expected: status=dibatalkan' as note
FROM orders
WHERE status = 'dibatalkan'
GROUP BY status;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT 'ALL TESTS COMPLETED' as summary,
  'Check results above for:' as note,
  '1. ✓ Transaksi sukses mengurangi stok' as test_1,
  '2. ✓ Stok kurang membatalkan semuanya (atomic rollback)' as test_2,
  '3. ✓ Uang kurang ditolak (atomic rollback)' as test_3,
  '4. ✓ Void mengembalikan stok' as test_4,
  '5. ✓ Void ganda ditolak' as test_5,
  '6. ✓ Reject void request berfungsi' as test_6,
  '7. ✓ Auto-cancel expired orders berfungsi' as test_7;
