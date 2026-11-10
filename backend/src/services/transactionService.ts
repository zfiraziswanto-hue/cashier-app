import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { AppError } from '../utils/AppError';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key'
);

export interface TransactionItem {
  product_id: number;
  qty: number;
}

export interface CreateTransactionInput {
  items: TransactionItem[];
  metode_bayar: 'tunai' | 'qris' | 'transfer';
  uang_diterima: number;
  order_id?: number;
}

export interface TransactionResponse {
  id: number;
  nomor_transaksi: string;
  kasir_id: string;
  subtotal: number;
  diskon: number;
  total: number;
  total_modal: number;
  laba: number;
  metode_bayar: string;
  uang_diterima: number;
  kembalian: number;
  items: Array<{
    product_id: number;
    nama_produk: string;
    qty: number;
    harga_jual: number;
    harga_modal: number;
  }>;
  created_at: string;
}

export class TransactionService {
  static async createTransaction(
    input: CreateTransactionInput,
    kasirId: string
  ): Promise<TransactionResponse> {
    try {
      // For non-tunai, uang_diterima must equal total
      // First, get product details dan hitung total
      const productIds = input.items.map(item => item.product_id);
      
      const { data: products, error: productError } = await supabase
        .from('products')
        .select('id, nama, harga_jual, harga_modal, stok')
        .in('id', productIds);

      if (productError || !products) {
        throw new AppError('PRODUCT_ERROR', 'Gagal mengambil data produk', 500);
      }

      // Validate quantities and calculate totals
      let subtotal = 0;
      let total_modal = 0;
      const productMap = new Map(products.map(p => [p.id, p]));

      for (const item of input.items) {
        const product = productMap.get(item.product_id);
        if (!product) {
          throw new AppError('PRODUCT_NOT_FOUND', `Produk ${item.product_id} tidak ditemukan`, 404);
        }
        if (item.qty > product.stok) {
          throw new AppError(
            'INSUFFICIENT_STOCK',
            `Stok ${product.nama} tidak cukup (tersedia: ${product.stok})`,
            409
          );
        }
        subtotal += product.harga_jual * item.qty;
        total_modal += product.harga_modal * item.qty;
      }

      const diskon = 0; // For now, no discount
      const total = subtotal - diskon;
      const kembalian = input.metode_bayar === 'tunai' ? input.uang_diterima - total : 0;
      const laba = total - total_modal;

      // Validate uang_diterima
      if (input.metode_bayar !== 'tunai' && input.uang_diterima !== total) {
        throw new AppError(
          'INVALID_PAYMENT',
          'Untuk pembayaran non-tunai, uang_diterima harus sama dengan total',
          400
        );
      }

      if (input.metode_bayar === 'tunai' && input.uang_diterima < total) {
        throw new AppError(
          'INSUFFICIENT_PAYMENT',
          'Uang yang diterima kurang dari total',
          400
        );
      }

      // Call atomic transaction function
      const { data: txnData, error: txnError } = await supabase.rpc(
        'create_transaction_atomic',
        {
          p_items: input.items,
          p_metode_bayar: input.metode_bayar,
          p_uang_diterima: input.uang_diterima,
          p_kasir_id: kasirId,
          p_order_id: input.order_id || null,
          p_subtotal: subtotal,
          p_diskon: diskon,
          p_total: total,
          p_total_modal: total_modal,
          p_laba: laba,
          p_kembalian: kembalian
        }
      );

      if (txnError || !txnData) {
        throw new AppError('TXN_ERROR', 'Gagal membuat transaksi', 500);
      }

      // Get created transaction with items
      const { data: createdTxn, error: fetchError } = await supabase
        .from('transactions')
        .select(
          `*,
           transaction_items(
             id,
             product_id,
             nama_produk,
             qty,
             harga_jual,
             harga_modal
           )`
        )
        .eq('id', txnData.id)
        .single();

      if (fetchError || !createdTxn) {
        throw new AppError('FETCH_ERROR', 'Gagal mengambil data transaksi', 500);
      }

      // Log activity
      await supabase.from('activity_logs').insert([
        {
          user_id: kasirId,
          aksi: 'CREATE_TRANSACTION',
          entitas: 'transactions',
          entitas_id: createdTxn.id,
          detail: {
            nomor_transaksi: createdTxn.nomor_transaksi,
            total,
            metode_bayar: input.metode_bayar
          }
        }
      ]);

      return {
        id: createdTxn.id,
        nomor_transaksi: createdTxn.nomor_transaksi,
        kasir_id: createdTxn.kasir_id,
        subtotal: createdTxn.subtotal,
        diskon: createdTxn.diskon,
        total: createdTxn.total,
        total_modal: createdTxn.total_modal,
        laba: createdTxn.laba,
        metode_bayar: createdTxn.metode_bayar,
        uang_diterima: createdTxn.uang_diterima,
        kembalian: createdTxn.kembalian,
        items: createdTxn.transaction_items,
        created_at: createdTxn.created_at
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('TXN_ERROR', 'Gagal membuat transaksi', 500);
    }
  }

  static async listTransactions(
    userId: string,
    userRole: string,
    filters: {
      from_date?: string;
      to_date?: string;
      kasir_id?: string;
      metode_bayar?: string;
      page: number;
      limit: number;
    }
  ): Promise<{ data: any[]; total: number; page: number; limit: number }> {
    try {
      let query = supabase.from('transactions').select('*, transaction_items(*)', { count: 'exact' });

      // Authorization: kasir hanya lihat miliknya
      if (userRole === 'kasir') {
        query = query.eq('kasir_id', userId);
      } else if (filters.kasir_id) {
        // Admin bisa filter by kasir_id
        query = query.eq('kasir_id', filters.kasir_id);
      }

      // Date range filter
      if (filters.from_date) {
        query = query.gte('created_at', filters.from_date);
      }
      if (filters.to_date) {
        query = query.lte('created_at', filters.to_date);
      }

      // Metode bayar filter
      if (filters.metode_bayar) {
        query = query.eq('metode_bayar', filters.metode_bayar);
      }

      // Pagination
      const offset = (filters.page - 1) * filters.limit;
      query = query.order('created_at', { ascending: false }).range(offset, offset + filters.limit - 1);

      const { data, error, count } = await query;

      if (error) {
        throw new AppError('QUERY_ERROR', 'Gagal mengambil daftar transaksi', 500);
      }

      return {
        data: data || [],
        total: count || 0,
        page: filters.page,
        limit: filters.limit
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('QUERY_ERROR', 'Gagal mengambil daftar transaksi', 500);
    }
  }

  static async getTransactionDetail(transactionId: number, userId: string, userRole: string): Promise<TransactionResponse> {
    try {
      const { data, error } = await supabase
        .from('transactions')
        .select(
          `*,
           transaction_items(
             id,
             product_id,
             nama_produk,
             qty,
             harga_jual,
             harga_modal
           )`
        )
        .eq('id', transactionId)
        .single();

      if (error || !data) {
        throw new AppError('NOT_FOUND', 'Transaksi tidak ditemukan', 404);
      }

      // Authorization: kasir hanya lihat miliknya
      if (userRole === 'kasir' && data.kasir_id !== userId) {
        throw new AppError('FORBIDDEN', 'Anda tidak bisa mengakses transaksi ini', 403);
      }

      return {
        id: data.id,
        nomor_transaksi: data.nomor_transaksi,
        kasir_id: data.kasir_id,
        subtotal: data.subtotal,
        diskon: data.diskon,
        total: data.total,
        total_modal: data.total_modal,
        laba: data.laba,
        metode_bayar: data.metode_bayar,
        uang_diterima: data.uang_diterima,
        kembalian: data.kembalian,
        items: data.transaction_items,
        created_at: data.created_at
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('FETCH_ERROR', 'Gagal mengambil detail transaksi', 500);
    }
  }

  static async getReceipt(
    transactionId: number,
    userId: string,
    userRole: string,
    paperSize: '58mm' | '80mm' = '58mm'
  ): Promise<string> {
    try {
      // Get transaction detail
      const txn = await this.getTransactionDetail(transactionId, userId, userRole);

      // Get store settings
      const { data: storeSettings, error: settingsError } = await supabase
        .from('store_settings')
        .select('*')
        .single();

      if (settingsError) {
        throw new AppError('SETTINGS_ERROR', 'Gagal mengambil pengaturan toko', 500);
      }

      // Get kasir name
      const { data: kasirProfile, error: kasirError } = await supabase
        .from('profiles')
        .select('nama')
        .eq('id', txn.kasir_id)
        .single();

      if (kasirError) {
        throw new AppError('PROFILE_ERROR', 'Gagal mengambil data kasir', 500);
      }

      // Generate receipt HTML
      const receipt = this.generateReceipt(txn, storeSettings, kasirProfile?.nama || 'Unknown', paperSize);
      return receipt;
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('RECEIPT_ERROR', 'Gagal membuat struk', 500);
    }
  }

  private static generateReceipt(
    txn: TransactionResponse,
    storeSettings: any,
    kasirName: string,
    paperSize: '58mm' | '80mm'
  ): string {
    const width = paperSize === '58mm' ? '200px' : '280px';
    const charPerLine = paperSize === '58mm' ? 32 : 48;

    const divider = '='.repeat(charPerLine);
    const subDivider = '-'.repeat(charPerLine);

    const formatDate = (date: string) => {
      return new Date(date).toLocaleString('id-ID', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });
    };

    const padRight = (text: string, width: number) => text.padEnd(width);
    const padLeft = (text: string, width: number) => text.padStart(width);
    const center = (text: string, width: number) => {
      const pad = Math.max(0, width - text.length);
      const leftPad = Math.floor(pad / 2);
      return text.padStart(text.length + leftPad).padEnd(width);
    };

    const formatCurrency = (amount: number) => {
      return new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        minimumFractionDigits: 0
      }).format(amount);
    };

    let receipt = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Struk Transaksi</title>
  <style>
    body {
      font-family: 'Courier New', monospace;
      margin: 0;
      padding: 0;
      width: ${width};
      font-size: 12px;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-wrap: break-word;
      font-family: 'Courier New', monospace;
    }
  </style>
</head>
<body>
<pre>
${center(storeSettings.nama_toko || 'TOKO', charPerLine)}
${center(storeSettings.alamat || '', charPerLine)}
${center(storeSettings.kontak || '', charPerLine)}
${divider}
${padRight('No. Struk:', charPerLine / 2)} ${txn.nomor_transaksi}
${padRight('Tanggal:', charPerLine / 2)} ${formatDate(txn.created_at)}
${padRight('Kasir:', charPerLine / 2)} ${kasirName}
${divider}

ITEM                    QTY      HARGA      TOTAL
${subDivider}
`;

    // Items
    for (const item of txn.items) {
      const itemTotal = item.harga_jual * item.qty;
      const itemName = item.nama_produk.substring(0, 20);
      const line = `${padRight(itemName, 20)} ${padLeft(item.qty.toString(), 3)} ${padLeft(formatCurrency(item.harga_jual), 9)} ${padLeft(formatCurrency(itemTotal), 10)}`;
      receipt += line + '\n';
    }

    receipt += `
${subDivider}
${padRight('SUBTOTAL', charPerLine - 15)} ${padLeft(formatCurrency(txn.subtotal), 15)}
${padRight('DISKON', charPerLine - 15)} ${padLeft(formatCurrency(txn.diskon), 15)}
${divider}
${padRight('TOTAL', charPerLine - 15)} ${padLeft(formatCurrency(txn.total), 15)}
${divider}

PEMBAYARAN:
${padRight('Metode:', charPerLine / 2)} ${txn.metode_bayar.toUpperCase()}
${padRight('Diterima:', charPerLine / 2)} ${formatCurrency(txn.uang_diterima)}
${padRight('Kembalian:', charPerLine / 2)} ${formatCurrency(txn.kembalian)}

${divider}
${center(storeSettings.footer_struk || 'Terima kasih telah berbelanja', charPerLine)}
${divider}
</pre>
</body>
</html>
`;

    return receipt;
  }

  static async createVoidRequest(
    transactionId: number,
    userId: string,
    alasan: string
  ): Promise<{ id: number; status: string }> {
    try {
      // Get transaction
      const { data: txn, error: txnError } = await supabase
        .from('transactions')
        .select('id, status')
        .eq('id', transactionId)
        .single();

      if (txnError || !txn) {
        throw new AppError('NOT_FOUND', 'Transaksi tidak ditemukan', 404);
      }

      // Check if already void
      if (txn.status === 'void') {
        throw new AppError('ALREADY_VOID', 'Transaksi sudah void', 400);
      }

      // Check if request already pending
      const { data: existingRequest, error: existingError } = await supabase
        .from('void_requests')
        .select('id, status')
        .eq('transaction_id', transactionId)
        .eq('status', 'menunggu')
        .single();

      if (existingRequest) {
        throw new AppError('REQUEST_PENDING', 'Ada permintaan void yang masih menunggu', 400);
      }

      // Create void request
      const { data: voidRequest, error: createError } = await supabase
        .from('void_requests')
        .insert([
          {
            transaction_id: transactionId,
            diajukan_oleh: userId,
            alasan,
            status: 'menunggu'
          }
        ])
        .select()
        .single();

      if (createError || !voidRequest) {
        throw new AppError('CREATE_ERROR', 'Gagal membuat permintaan void', 500);
      }

      // Log activity
      await supabase.from('activity_logs').insert([
        {
          user_id: userId,
          aksi: 'REQUEST_VOID',
          entitas: 'transactions',
          entitas_id: transactionId,
          detail: { alasan }
        }
      ]);

      return {
        id: voidRequest.id,
        status: voidRequest.status
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('VOID_ERROR', 'Gagal membuat permintaan void', 500);
    }
  }
}
