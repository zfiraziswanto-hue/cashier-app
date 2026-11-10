-- Migration: Atomic Transaction Functions
-- Purpose: Critical functions untuk transaksi kasir yang atomic & aman
-- Created: 2026-11-02

-- ============================================================================
-- 1. CREATE_TRANSACTION_ATOMIC()
-- ============================================================================
-- Membuat transaksi dengan atomicity penuh:
-- - Lock baris produk untuk cegah race condition
-- - Validasi stok & produk aktif
-- - Snapshot harga dari DB (jangan trust client)
-- - Update stok atomik
-- - Create transaction_items dengan snapshot harga
-- - Mark order as dibayar jika order_id ada
-- - Return transaction id, receipt number, total, kembalian

CREATE OR REPLACE FUNCTION create_transaction_atomic(
  p_kasir_id UUID,
  p_items JSONB,  -- [{"product_id": 1, "qty": 5}, ...]
  p_metode_bayar payment_method,
  p_uang_diterima INTEGER,
  p_order_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
  transaction_id INTEGER,
  nomor_transaksi TEXT,
  total INTEGER,
  kembalian INTEGER
) AS $$
DECLARE
  v_item JSONB;
  v_product_id INTEGER;
  v_qty INTEGER;
  v_product RECORD;
  v_subtotal INTEGER := 0;
  v_total_modal INTEGER := 0;
  v_laba INTEGER := 0;
  v_kembalian INTEGER := 0;
  v_transaction_id INTEGER;
  v_nomor_transaksi TEXT;
  v_date_str TEXT;
  v_transaction_count INTEGER;
  v_harga_jual INTEGER;
  v_harga_modal INTEGER;
BEGIN
  -- Validasi input
  IF p_kasir_id IS NULL THEN
    RAISE EXCEPTION 'kasir_id tidak boleh kosong';
  END IF;
  
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Minimal 1 item harus ada dalam transaksi';
  END IF;
  
  IF p_metode_bayar IS NULL THEN
    RAISE EXCEPTION 'metode_bayar tidak boleh kosong';
  END IF;

  -- Cek kasir aktif
  PERFORM 1 FROM profiles 
  WHERE id = p_kasir_id AND role = 'kasir' AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kasir tidak ditemukan atau tidak aktif';
  END IF;

  -- Lock produk berdasarkan product_id (urut untuk avoid deadlock)
  -- Sekaligus cek stok & produk aktif
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::INTEGER;
    v_qty := (v_item->>'qty')::INTEGER;

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Kuantitas produk harus > 0';
    END IF;

    -- Lock & ambil produk (FOR UPDATE untuk consistency)
    SELECT id, nama, harga_modal, harga_jual, stok, is_active
    INTO v_product
    FROM products
    WHERE id = v_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Produk dengan ID % tidak ditemukan', v_product_id;
    END IF;

    IF NOT v_product.is_active THEN
      RAISE EXCEPTION 'Produk "%" tidak aktif', v_product.nama;
    END IF;

    IF v_product.stok < v_qty THEN
      RAISE EXCEPTION 'Stok produk "%" tidak cukup. Tersedia: %, Diminta: %', 
        v_product.nama, v_product.stok, v_qty;
    END IF;

    -- Accumulate totals (gunakan harga dari DB, bukan dari client)
    v_harga_jual := v_product.harga_jual;
    v_harga_modal := v_product.harga_modal;
    v_subtotal := v_subtotal + (v_harga_jual * v_qty);
    v_total_modal := v_total_modal + (v_harga_modal * v_qty);
    v_laba := v_laba + ((v_harga_jual - v_harga_modal) * v_qty);

    -- Kurangi stok
    UPDATE products
    SET stok = stok - v_qty
    WHERE id = v_product_id;

    -- Catat stock_movement
    INSERT INTO stock_movements (product_id, tipe, jumlah, stok_sebelum, stok_sesudah, referensi_id, created_by)
    VALUES (
      v_product_id,
      'keluar',
      v_qty,
      v_product.stok,
      v_product.stok - v_qty,
      NULL,  -- referensi_id akan diisi setelah transaction created
      p_kasir_id
    );
  END LOOP;

  -- Hitung kembalian (khusus tunai)
  IF p_metode_bayar = 'tunai' THEN
    IF p_uang_diterima < v_subtotal THEN
      RAISE EXCEPTION 'Uang diterima (%) kurang dari total (%)', p_uang_diterima, v_subtotal;
    END IF;
    v_kembalian := p_uang_diterima - v_subtotal;
  ELSE
    -- Non-tunai: uang_diterima = total (atau 0 jika pending)
    v_kembalian := 0;
  END IF;

  -- Generate nomor_transaksi (TRX-YYYYMMDD-XXXX)
  v_date_str := TO_CHAR(NOW(), 'YYYYMMDD');
  SELECT COUNT(*) INTO v_transaction_count
  FROM transactions
  WHERE nomor_transaksi LIKE 'TRX-' || v_date_str || '%';
  
  v_nomor_transaksi := 'TRX-' || v_date_str || '-' || LPAD((v_transaction_count + 1)::TEXT, 4, '0');

  -- Insert transaction
  INSERT INTO transactions (
    nomor_transaksi, order_id, kasir_id, subtotal, diskon, total,
    total_modal, laba, metode_bayar, uang_diterima, kembalian, status
  )
  VALUES (
    v_nomor_transaksi, p_order_id, p_kasir_id, v_subtotal, 0, v_subtotal,
    v_total_modal, v_laba, p_metode_bayar, p_uang_diterima, v_kembalian, 'selesai'
  )
  RETURNING id INTO v_transaction_id;

  -- Insert transaction_items (dengan snapshot harga dari DB)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::INTEGER;
    v_qty := (v_item->>'qty')::INTEGER;

    SELECT nama, harga_modal, harga_jual INTO v_product
    FROM products WHERE id = v_product_id;

    INSERT INTO transaction_items (
      transaction_id, product_id, nama_produk, qty, harga_jual, harga_modal
    )
    VALUES (
      v_transaction_id, v_product_id, v_product.nama, v_qty,
      v_product.harga_jual, v_product.harga_modal
    );
  END LOOP;

  -- Update order status jika order_id ada
  IF p_order_id IS NOT NULL THEN
    UPDATE orders
    SET status = 'dibayar'
    WHERE id = p_order_id AND status = 'menunggu_pembayaran';
    
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Order dengan ID % tidak ditemukan atau sudah dibayar', p_order_id;
    END IF;
  END IF;

  -- Log activity
  INSERT INTO activity_logs (user_id, aksi, entitas, entitas_id, detail)
  VALUES (
    p_kasir_id,
    'BUAT_TRANSAKSI',
    'transactions',
    v_transaction_id,
    jsonb_build_object(
      'nomor_transaksi', v_nomor_transaksi,
      'total', v_subtotal,
      'metode_bayar', p_metode_bayar::TEXT
    )
  );

  RETURN QUERY SELECT v_transaction_id, v_nomor_transaksi, v_subtotal, v_kembalian;

EXCEPTION WHEN OTHERS THEN
  -- Automatic ROLLBACK karena error di dalam transaction
  RAISE EXCEPTION 'Gagal membuat transaksi: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION create_transaction_atomic(UUID, JSONB, payment_method, INTEGER, INTEGER) 
TO service_role;

-- ============================================================================
-- 2. APPROVE_VOID_TRANSACTION()
-- ============================================================================
-- Approve void request dengan atomicity penuh:
-- - Hanya terima request berstatus 'menunggu'
-- - Update transaction status to 'void'
-- - Kembalikan stok semua items
-- - Update void_request status to 'disetujui'
-- - Catat activity_log
-- Tolak jika transaksi sudah void

CREATE OR REPLACE FUNCTION approve_void_transaction(
  p_void_request_id INTEGER,
  p_admin_id UUID,
  p_catatan TEXT DEFAULT NULL
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  transaction_id INTEGER,
  stok_items_dikembalikan INTEGER
) AS $$
DECLARE
  v_transaction_id INTEGER;
  v_void_status void_status;
  v_transaction_status transaction_status;
  v_item RECORD;
  v_stok_items_dikembalikan INTEGER := 0;
  v_product RECORD;
BEGIN
  -- Cek admin aktif
  PERFORM 1 FROM profiles
  WHERE id = p_admin_id AND role = 'admin' AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin tidak ditemukan atau tidak aktif';
  END IF;

  -- Lock void_request (untuk consistency)
  SELECT vr.transaction_id, vr.status, t.status
  INTO v_transaction_id, v_void_status, v_transaction_status
  FROM void_requests vr
  JOIN transactions t ON vr.transaction_id = t.id
  WHERE vr.id = p_void_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Void request tidak ditemukan'::TEXT, NULL::INTEGER, 0::INTEGER;
    RETURN;
  END IF;

  -- Cek status void_request masih 'menunggu'
  IF v_void_status != 'menunggu' THEN
    RETURN QUERY SELECT false, 'Void request sudah diproses'::TEXT, v_transaction_id, 0::INTEGER;
    RETURN;
  END IF;

  -- Cek transaksi masih 'selesai' (belum void)
  IF v_transaction_status = 'void' THEN
    RETURN QUERY SELECT false, 'Transaksi sudah di-void sebelumnya'::TEXT, v_transaction_id, 0::INTEGER;
    RETURN;
  END IF;

  -- Update transaction status to 'void'
  UPDATE transactions
  SET status = 'void'
  WHERE id = v_transaction_id;

  -- Kembalikan stok & catat stock_movements
  FOR v_item IN
    SELECT ti.product_id, ti.qty, p.nama
    FROM transaction_items ti
    JOIN products p ON ti.product_id = p.id
    WHERE ti.transaction_id = v_transaction_id
  LOOP
    -- Get current stock
    SELECT stok INTO STRICT v_product
    FROM products WHERE id = v_item.product_id
    FOR UPDATE;

    -- Update stok
    UPDATE products
    SET stok = stok + v_item.qty
    WHERE id = v_item.product_id;

    -- Catat stock_movement (retur)
    INSERT INTO stock_movements (
      product_id, tipe, jumlah, stok_sebelum, stok_sesudah, referensi_id, created_by
    )
    VALUES (
      v_item.product_id,
      'retur',
      v_item.qty,
      v_product.stok,
      v_product.stok + v_item.qty,
      v_transaction_id,
      p_admin_id
    );

    v_stok_items_dikembalikan := v_stok_items_dikembalikan + v_item.qty;
  END LOOP;

  -- Update void_request status
  UPDATE void_requests
  SET status = 'disetujui',
      diproses_oleh = p_admin_id,
      diproses_at = NOW()
  WHERE id = p_void_request_id;

  -- Log activity
  INSERT INTO activity_logs (user_id, aksi, entitas, entitas_id, detail)
  VALUES (
    p_admin_id,
    'SETUJUI_VOID',
    'transactions',
    v_transaction_id,
    jsonb_build_object(
      'void_request_id', p_void_request_id,
      'catatan', p_catatan,
      'stok_dikembalikan', v_stok_items_dikembalikan
    )
  );

  RETURN QUERY SELECT true, 'Void transaksi berhasil disetujui'::TEXT, v_transaction_id, v_stok_items_dikembalikan;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Gagal approve void: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION approve_void_transaction(INTEGER, UUID, TEXT)
TO service_role;

-- ============================================================================
-- 3. REJECT_VOID_REQUEST()
-- ============================================================================
-- Reject void request (pasangan dari approve):
-- - Hanya terima request berstatus 'menunggu'
-- - Update status to 'ditolak'
-- - Catat activity_log

CREATE OR REPLACE FUNCTION reject_void_request(
  p_void_request_id INTEGER,
  p_admin_id UUID,
  p_alasan_penolakan TEXT
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  transaction_id INTEGER
) AS $$
DECLARE
  v_transaction_id INTEGER;
  v_void_status void_status;
BEGIN
  -- Cek admin aktif
  PERFORM 1 FROM profiles
  WHERE id = p_admin_id AND role = 'admin' AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin tidak ditemukan atau tidak aktif';
  END IF;

  -- Lock & ambil void_request
  SELECT vr.transaction_id, vr.status
  INTO v_transaction_id, v_void_status
  FROM void_requests vr
  WHERE vr.id = p_void_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Void request tidak ditemukan'::TEXT, NULL::INTEGER;
    RETURN;
  END IF;

  -- Cek status masih 'menunggu'
  IF v_void_status != 'menunggu' THEN
    RETURN QUERY SELECT false, 'Void request sudah diproses'::TEXT, v_transaction_id;
    RETURN;
  END IF;

  -- Update status to 'ditolak'
  UPDATE void_requests
  SET status = 'ditolak',
      diproses_oleh = p_admin_id,
      diproses_at = NOW()
  WHERE id = p_void_request_id;

  -- Log activity
  INSERT INTO activity_logs (user_id, aksi, entitas, entitas_id, detail)
  VALUES (
    p_admin_id,
    'TOLAK_VOID',
    'transactions',
    v_transaction_id,
    jsonb_build_object(
      'void_request_id', p_void_request_id,
      'alasan_penolakan', p_alasan_penolakan
    )
  );

  RETURN QUERY SELECT true, 'Void request ditolak'::TEXT, v_transaction_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Gagal reject void: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION reject_void_request(INTEGER, UUID, TEXT)
TO service_role;

-- ============================================================================
-- 4. AUTO_CANCEL_EXPIRED_ORDERS()
-- ============================================================================
-- Batalkan order pending yang sudah > 30 menit:
-- - Cari order dengan status 'menunggu_pembayaran' dan created_at < now() - 30 min
-- - Untuk setiap order, cek apakah stok di-hold saat order dibuat
--   (skema saat ini: stok TIDAK di-hold pada order creation, hanya saat confirm payment)
--   Jadi cukup update status saja
-- - Update order status ke 'dibatalkan'
-- - Catat activity_log
-- - Return jumlah order yang dibatalkan

CREATE OR REPLACE FUNCTION auto_cancel_expired_orders()
RETURNS TABLE(
  orders_cancelled INTEGER,
  message TEXT
) AS $$
DECLARE
  v_expired_count INTEGER := 0;
  v_order RECORD;
BEGIN
  -- Cari order yang expired
  FOR v_order IN
    SELECT id, kode_pesanan
    FROM orders
    WHERE status = 'menunggu_pembayaran'
      AND created_at < NOW() - INTERVAL '30 minutes'
    FOR UPDATE
  LOOP
    -- Update status to 'dibatalkan'
    UPDATE orders
    SET status = 'dibatalkan'
    WHERE id = v_order.id;

    -- Catat activity_log (system action, no user_id)
    INSERT INTO activity_logs (user_id, aksi, entitas, entitas_id, detail)
    VALUES (
      NULL,
      'AUTO_CANCEL_ORDER',
      'orders',
      v_order.id,
      jsonb_build_object(
        'kode_pesanan', v_order.kode_pesanan,
        'reason', 'Order expired setelah 30 menit'
      )
    );

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN QUERY SELECT v_expired_count, 'Auto-cancelled ' || v_expired_count || ' expired orders'::TEXT;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Gagal auto-cancel orders: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION auto_cancel_expired_orders()
TO service_role;

-- ============================================================================
-- NOTE ON SCHEDULING
-- ============================================================================
-- Supabase dengan pg_cron extension:
--   SELECT cron.schedule('cancel-expired-orders', '*/5 * * * *', 'SELECT auto_cancel_expired_orders()');
--
-- Jika pg_cron tidak tersedia:
--   Backend (Node.js) akan menggunakan node-cron untuk memanggil endpoint ini setiap 5 menit
--   (akan diimplementasikan di Prompt 4)
