import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { AppError } from '../utils/AppError';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key'
);

export interface OrderItem {
  product_id: number;
  qty: number;
}

export interface CreateOrderInput {
  items: OrderItem[];
}

export interface OrderResponse {
  id: number;
  kode_pesanan: string;
  user_id: string;
  status: string;
  total: number;
  expires_at: string;
  items: Array<{
    product_id: number;
    qty: number;
    harga_jual: number;
    harga_modal: number;
  }>;
  created_at: string;
}

export class OrderService {
  private static async generateUniqueKode(): Promise<string> {
    const now = new Date();
    const yymmdd = now.toISOString().slice(2, 8).replace(/-/g, '');
    let kode = '';
    let exists = true;
    let retries = 0;
    const maxRetries = 100;

    while (exists && retries < maxRetries) {
      const random = Math.floor(Math.random() * 10000)
        .toString()
        .padStart(4, '0');
      kode = `ORD-${yymmdd}-${random}`;

      const { data, error } = await supabase
        .from('orders')
        .select('id')
        .eq('kode_pesanan', kode)
        .single();

      exists = !error; // If no error, it exists
      retries++;
    }

    if (exists) {
      throw new AppError('KODE_GENERATION_FAILED', 'Gagal membuat kode pesanan unik', 500);
    }

    return kode;
  }

  static async createOrder(input: CreateOrderInput, userId: string): Promise<OrderResponse> {
    try {
      // Validate items
      if (!input.items || input.items.length === 0) {
        throw new AppError('EMPTY_ITEMS', 'Minimal ada 1 item', 400);
      }

      const productIds = input.items.map(item => item.product_id);

      // Get products
      const { data: products, error: productError } = await supabase
        .from('products')
        .select('id, nama, harga_jual, harga_modal, stok, is_active')
        .in('id', productIds);

      if (productError || !products) {
        throw new AppError('PRODUCT_ERROR', 'Gagal mengambil data produk', 500);
      }

      const productMap = new Map(products.map(p => [p.id, p]));

      // Validate each item
      let total = 0;
      for (const item of input.items) {
        const product = productMap.get(item.product_id);
        if (!product) {
          throw new AppError('PRODUCT_NOT_FOUND', `Produk ${item.product_id} tidak ditemukan`, 404);
        }
        if (!product.is_active) {
          throw new AppError('PRODUCT_INACTIVE', `Produk ${product.nama} tidak aktif`, 400);
        }
        if (item.qty > product.stok) {
          throw new AppError(
            'INSUFFICIENT_STOCK',
            `Stok ${product.nama} tidak cukup (tersedia: ${product.stok})`,
            409
          );
        }
        total += product.harga_jual * item.qty;
      }

      // Generate unique kode_pesanan
      const kode_pesanan = await this.generateUniqueKode();

      // Calculate expires_at (30 minutes from now)
      const expires_at = new Date(Date.now() + 30 * 60 * 1000).toISOString();

      // Create order
      const { data: order, error: orderError } = await supabase
        .from('orders')
        .insert([
          {
            kode_pesanan,
            user_id: userId,
            status: 'menunggu_pembayaran',
            total,
            expires_at
          }
        ])
        .select()
        .single();

      if (orderError || !order) {
        throw new AppError('ORDER_CREATE_ERROR', 'Gagal membuat pesanan', 500);
      }

      // Create order items
      const orderItems = input.items.map(item => {
        const product = productMap.get(item.product_id)!;
        return {
          order_id: order.id,
          product_id: item.product_id,
          qty: item.qty,
          harga_jual: product.harga_jual,
          harga_modal: product.harga_modal
        };
      });

      const { error: itemsError } = await supabase
        .from('order_items')
        .insert(orderItems);

      if (itemsError) {
        throw new AppError('ORDER_ITEMS_ERROR', 'Gagal membuat item pesanan', 500);
      }

      // Log activity
      await supabase.from('activity_logs').insert([
        {
          user_id: userId,
          aksi: 'CREATE_ORDER',
          entitas: 'orders',
          entitas_id: order.id,
          detail: { kode_pesanan, total, item_count: input.items.length }
        }
      ]);

      // Return with items
      const { data: createdOrder, error: fetchError } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', order.id)
        .single();

      if (fetchError || !createdOrder) {
        throw new AppError('FETCH_ERROR', 'Gagal mengambil data pesanan', 500);
      }

      return {
        id: createdOrder.id,
        kode_pesanan: createdOrder.kode_pesanan,
        user_id: createdOrder.user_id,
        status: createdOrder.status,
        total: createdOrder.total,
        expires_at: createdOrder.expires_at,
        items: createdOrder.order_items,
        created_at: createdOrder.created_at
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('ORDER_ERROR', 'Gagal membuat pesanan', 500);
    }
  }

  static async getUserOrders(userId: string): Promise<OrderResponse[]> {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) {
        throw new AppError('QUERY_ERROR', 'Gagal mengambil daftar pesanan', 500);
      }

      return (data || []).map(order => ({
        id: order.id,
        kode_pesanan: order.kode_pesanan,
        user_id: order.user_id,
        status: order.status,
        total: order.total,
        expires_at: order.expires_at,
        items: order.order_items,
        created_at: order.created_at
      }));
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('QUERY_ERROR', 'Gagal mengambil daftar pesanan', 500);
    }
  }

  static async cancelOrder(orderId: number, userId: string): Promise<{ id: number; status: string }> {
    try {
      // Get order
      const { data: order, error: orderError } = await supabase
        .from('orders')
        .select('id, user_id, status')
        .eq('id', orderId)
        .single();

      if (orderError || !order) {
        throw new AppError('NOT_FOUND', 'Pesanan tidak ditemukan', 404);
      }

      // Check ownership
      if (order.user_id !== userId) {
        throw new AppError('FORBIDDEN', 'Anda tidak bisa membatalkan pesanan ini', 403);
      }

      // Check status
      if (order.status !== 'menunggu_pembayaran') {
        throw new AppError('INVALID_STATUS', 'Pesanan hanya bisa dibatalkan jika menunggu pembayaran', 400);
      }

      // Update status
      const { data: updated, error: updateError } = await supabase
        .from('orders')
        .update({ status: 'dibatalkan' })
        .eq('id', orderId)
        .select()
        .single();

      if (updateError || !updated) {
        throw new AppError('UPDATE_ERROR', 'Gagal membatalkan pesanan', 500);
      }

      // Log activity
      await supabase.from('activity_logs').insert([
        {
          user_id: userId,
          aksi: 'CANCEL_ORDER',
          entitas: 'orders',
          entitas_id: orderId
        }
      ]);

      return { id: updated.id, status: updated.status };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('CANCEL_ERROR', 'Gagal membatalkan pesanan', 500);
    }
  }

  static async getOrderByKode(kodePesanan: string, userRole: string): Promise<OrderResponse> {
    try {
      // Only kasir and admin can search by kode
      if (!['kasir', 'admin'].includes(userRole)) {
        throw new AppError('FORBIDDEN', 'Hanya kasir dan admin yang bisa mencari pesanan', 403);
      }

      const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('kode_pesanan', kodePesanan)
        .single();

      if (error || !data) {
        throw new AppError('NOT_FOUND', 'Pesanan tidak ditemukan', 404);
      }

      return {
        id: data.id,
        kode_pesanan: data.kode_pesanan,
        user_id: data.user_id,
        status: data.status,
        total: data.total,
        expires_at: data.expires_at,
        items: data.order_items,
        created_at: data.created_at
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('QUERY_ERROR', 'Gagal mencari pesanan', 500);
    }
  }

  static async confirmPayment(
    orderId: number,
    kasirId: string,
    metode_bayar: string,
    uang_diterima: number
  ): Promise<{ transaction_id: number; order_status: string }> {
    try {
      // Get order with items
      const { data: order, error: orderError } = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', orderId)
        .single();

      if (orderError || !order) {
        throw new AppError('NOT_FOUND', 'Pesanan tidak ditemukan', 404);
      }

      // Check status
      if (order.status !== 'menunggu_pembayaran') {
        throw new AppError('INVALID_STATUS', 'Pesanan tidak menunggu pembayaran', 400);
      }

      // Check if expired
      if (new Date(order.expires_at) < new Date()) {
        throw new AppError('ORDER_EXPIRED', 'Pesanan sudah kadaluarsa', 400);
      }

      // Validate payment
      if (metode_bayar !== 'tunai' && uang_diterima !== order.total) {
        throw new AppError(
          'INVALID_PAYMENT',
          'Untuk pembayaran non-tunai, uang_diterima harus sama dengan total',
          400
        );
      }

      if (metode_bayar === 'tunai' && uang_diterima < order.total) {
        throw new AppError('INSUFFICIENT_PAYMENT', 'Uang yang diterima kurang dari total', 400);
      }

      // Calculate transaction data
      const kembalian = metode_bayar === 'tunai' ? uang_diterima - order.total : 0;
      const total_modal = order.order_items.reduce(
        (sum: number, item: any) => sum + item.harga_modal * item.qty,
        0
      );
      const laba = order.total - total_modal;

      // Call atomic transaction function
      const { data: txnData, error: txnError } = await supabase.rpc(
        'create_transaction_atomic',
        {
          p_items: order.order_items.map((item: any) => ({
            product_id: item.product_id,
            qty: item.qty
          })),
          p_metode_bayar: metode_bayar,
          p_uang_diterima: uang_diterima,
          p_kasir_id: kasirId,
          p_order_id: orderId,
          p_subtotal: order.total,
          p_diskon: 0,
          p_total: order.total,
          p_total_modal: total_modal,
          p_laba: laba,
          p_kembalian: kembalian
        }
      );

      if (txnError || !txnData) {
        throw new AppError('TXN_ERROR', 'Gagal membuat transaksi', 500);
      }

      // Update order status
      const { data: updatedOrder, error: updateError } = await supabase
        .from('orders')
        .update({ status: 'selesai' })
        .eq('id', orderId)
        .select()
        .single();

      if (updateError || !updatedOrder) {
        throw new AppError('UPDATE_ERROR', 'Gagal memperbarui status pesanan', 500);
      }

      // Log activity
      await supabase.from('activity_logs').insert([
        {
          user_id: kasirId,
          aksi: 'CONFIRM_ORDER_PAYMENT',
          entitas: 'orders',
          entitas_id: orderId,
          detail: {
            metode_bayar,
            uang_diterima,
            kembalian,
            transaction_id: txnData.id
          }
        }
      ]);

      return {
        transaction_id: txnData.id,
        order_status: updatedOrder.status
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('CONFIRM_ERROR', 'Gagal mengkonfirmasi pembayaran', 500);
    }
  }
}
