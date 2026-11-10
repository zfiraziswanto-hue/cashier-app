CREATE OR REPLACE FUNCTION approve_void(p_void_request_id INT, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
  v_transaction_id INT;
  v_item RECORD;
BEGIN
  -- Ambil transaksi id dari void_requests
  SELECT transaction_id INTO v_transaction_id
  FROM void_requests
  WHERE id = p_void_request_id AND status = 'menunggu';

  IF v_transaction_id IS NULL THEN
    RAISE EXCEPTION 'Permintaan void tidak ditemukan atau sudah diproses';
  END IF;

  -- Update status transaksi menjadi void
  UPDATE transactions
  SET status = 'void'
  WHERE id = v_transaction_id AND status = 'selesai';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaksi sudah di-void atau tidak ditemukan';
  END IF;

  -- Kembalikan stok dan catat stock_movements untuk setiap item transaksi
  FOR v_item IN 
    SELECT product_id, qty FROM transaction_items WHERE transaction_id = v_transaction_id
  LOOP
    -- Update stok produk
    UPDATE products
    SET stok = stok + v_item.qty
    WHERE id = v_item.product_id;

    -- Catat stock_movement
    INSERT INTO stock_movements (product_id, tipe, jumlah, stok_sebelum, stok_sesudah, referensi_id, created_by)
    SELECT 
      v_item.product_id,
      'retur',
      v_item.qty,
      stok - v_item.qty,
      stok,
      v_transaction_id,
      p_admin_id
    FROM products WHERE id = v_item.product_id;
  END LOOP;

  -- Update status void_request menjadi disetujui
  UPDATE void_requests
  SET status = 'disetujui',
      diproses_oleh = p_admin_id,
      diproses_at = NOW()
  WHERE id = p_void_request_id;

  -- Catat activity log
  INSERT INTO activity_logs (user_id, aksi, entitas, entitas_id, detail)
  VALUES (p_admin_id, 'SETUJUI_VOID', 'transactions', v_transaction_id, json_build_object('void_request_id', p_void_request_id));

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
