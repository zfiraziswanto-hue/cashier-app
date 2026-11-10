# Migration Testing Guide: Atomic Transaction Functions

**Migration File:** `supabase/migrations/20261102000002_atomic_transaction_functions.sql`

**Status:** Ready for deployment

---

## 📋 How to Deploy & Test

### Step 1: Deploy Migration in Supabase

1. Go to Supabase Dashboard → Your Project → SQL Editor
2. Create new query
3. Copy entire content from `supabase/migrations/20261102000002_atomic_transaction_functions.sql`
4. Execute query
5. Expected output: No errors, functions created

**Functions created:**
- `create_transaction_atomic(UUID, JSONB, payment_method, INTEGER, INTEGER)` ✓
- `approve_void_transaction(INTEGER, UUID, TEXT)` ✓
- `reject_void_request(INTEGER, UUID, TEXT)` ✓
- `auto_cancel_expired_orders()` ✓

---

### Step 2: Manual Testing

1. Go to SQL Editor → New query
2. Copy content from `supabase/tests/atomic_functions.sql`
3. Run each test block sequentially

**Test Cases:**

#### TEST 1: Transaction Success
- Creates transaction with 2 items
- Verifies stock decreased for both products
- Verifies kembalian calculated correctly (tunai: 100000 - (10000*3 + 5000*5) = 55000)
- Expected: ✓ Pass

#### TEST 2: Stock Insufficient (Rollback)
- Attempts transaction with qty > available stok
- Expected: ✗ Exception "Stok produk ... tidak cukup"
- Verifies: Stock NOT changed (atomic rollback)

#### TEST 3: Insufficient Cash (Rollback)
- Attempts tunai transaction where uang_diterima < total
- Expected: ✗ Exception "Uang diterima ... kurang dari total"
- Verifies: Stock NOT changed (atomic rollback)

#### TEST 4: Approve Void (Stock Returned)
- Creates void request
- Approves void
- Verifies: transaction.status = 'void'
- Verifies: Stock increased back to original
- Verifies: stock_movements recorded with type='retur'

#### TEST 5: Double Void (Rejection)
- Attempts to void same transaction twice
- Expected: ✗ Exception "Transaksi sudah di-void sebelumnya"
- Verifies: No changes made

#### TEST 6: Reject Void Request
- Creates void request
- Rejects void request
- Verifies: void_request.status = 'ditolak'
- Verifies: transaction.status remains 'selesai'
- Verifies: Stock unchanged

#### TEST 7: Auto-Cancel Expired Orders
- Creates test order with created_at 35 minutes ago
- Runs auto_cancel_expired_orders()
- Verifies: order.status = 'dibatalkan'
- Verifies: activity_logs recorded

---

## 🔒 Security & Atomicity

### Atomicity Guarantees

✓ **create_transaction_atomic():**
- Uses `SELECT ... FOR UPDATE` to lock product rows
- Locks ordered by product_id to prevent deadlock
- All operations in single transaction
- Automatic ROLLBACK on any error

✓ **approve_void_transaction():**
- Uses `SELECT ... FOR UPDATE` for void_request & transaction
- Validates status before processing
- Returns to original state on error

✓ **reject_void_request():**
- Uses `SELECT ... FOR UPDATE` for void_request
- No data changes, only status update

✓ **auto_cancel_expired_orders():**
- Uses `SELECT ... FOR UPDATE` for orders
- Only updates status, no financial impact

### Permission Model

- **Create:** service_role only (backend API)
- **Approve/Reject:** service_role only (backend API)
- **Auto-cancel:** service_role only (backend scheduled job)
- **Anonymous users:** No direct access (via RLS)

---

## 📊 Function Specifications

### 1. create_transaction_atomic()

**Input:**
```json
{
  "p_kasir_id": "uuid",
  "p_items": "[{\"product_id\": 1, \"qty\": 5}, ...]",
  "p_metode_bayar": "tunai|qris|transfer",
  "p_uang_diterima": 100000,
  "p_order_id": null
}
```

**Output:**
```json
{
  "transaction_id": 123,
  "nomor_transaksi": "TRX-20261102-0001",
  "total": 50000,
  "kembalian": 50000
}
```

**Validations:**
- ✓ Kasir aktif & role=kasir
- ✓ Minimal 1 item
- ✓ Setiap produk: aktif, stok cukup
- ✓ Untuk tunai: uang_diterima >= total
- ✓ Harga dari DB (snapshot), bukan dari client

**Atomicity:**
- ✓ All-or-nothing: jika ada error, semua rollback
- ✓ No partial updates: stok tidak berubah sebagian
- ✓ Lock strategy: SELECT ... FOR UPDATE urut product_id

---

### 2. approve_void_transaction()

**Input:**
```json
{
  "p_void_request_id": 5,
  "p_admin_id": "uuid",
  "p_catatan": "Kesalahan input"
}
```

**Output:**
```json
{
  "success": true,
  "message": "Void transaksi berhasil disetujui",
  "transaction_id": 123,
  "stok_items_dikembalikan": 8
}
```

**Validations:**
- ✓ Admin aktif & role=admin
- ✓ Void request status='menunggu' only
- ✓ Transaction status='selesai' only (reject jika sudah void)

**Atomicity:**
- ✓ All-or-nothing: jika ada error, semua rollback
- ✓ Stock returned completely or not at all

---

### 3. reject_void_request()

**Input:**
```json
{
  "p_void_request_id": 5,
  "p_admin_id": "uuid",
  "p_alasan_penolakan": "Produk sudah diterima"
}
```

**Output:**
```json
{
  "success": true,
  "message": "Void request ditolak",
  "transaction_id": 123
}
```

**Atomicity:**
- ✓ Simple status update, no data modification

---

### 4. auto_cancel_expired_orders()

**Input:** None

**Output:**
```json
{
  "orders_cancelled": 3,
  "message": "Auto-cancelled 3 expired orders"
}
```

**Logic:**
- Orders dengan status='menunggu_pembayaran'
- created_at < NOW() - 30 minutes
- Status diubah menjadi 'dibatalkan'
- Activity logged dengan reason='Order expired setelah 30 menit'

**Scheduling:**
- **Option 1 (Preferred):** pg_cron di Supabase
  ```sql
  SELECT cron.schedule('cancel-expired-orders', '*/5 * * * *', 'SELECT auto_cancel_expired_orders()');
  ```
  Runs every 5 minutes

- **Option 2:** Node.js node-cron di backend
  ```typescript
  cron.schedule('*/5 * * * *', async () => {
    await supabase.rpc('auto_cancel_expired_orders');
  });
  ```
  (akan diimplementasikan di Prompt 4)

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] All 4 functions created successfully
- [ ] TEST 1: Transaction reduces stock correctly
- [ ] TEST 2: Insufficient stock causes rollback
- [ ] TEST 3: Insufficient cash causes rollback
- [ ] TEST 4: Void returns stock completely
- [ ] TEST 5: Double void is rejected
- [ ] TEST 6: Reject void request works
- [ ] TEST 7: Auto-cancel expires orders

---

## 🚨 Known Limitations

1. **auto_cancel_expired_orders():**
   - Requires pg_cron extension (may not be available in free Supabase tier)
   - Alternative: Backend will call via node-cron

2. **Order Stock Hold:**
   - Current schema does NOT hold stock when order created
   - Stock only decreases when payment confirmed
   - If payment never confirmed, auto_cancel_expired_orders just changes status
   - (No need to "return" stock because it was never held)

3. **Diskon & Promo:**
   - Not implemented (P2 feature, backlog for v2)
   - Transaction diskon field always 0
   - Laba calculation: (harga_jual - harga_modal) * qty

---

## 📝 Production Deployment Notes

Before going live:

1. ✓ Test with realistic data volume (1000+ transactions)
2. ✓ Verify performance: SELECT...FOR UPDATE on products table
3. ✓ Setup auto_cancel_expired_orders scheduling
4. ✓ Document for backup/recovery procedures
5. ✓ Monitor transaction latency (should be <500ms)

---

**Migration File Size:** ~6.5 KB
**Functions Count:** 4
**Grants Added:** service_role only
**Created:** 2026-11-02

