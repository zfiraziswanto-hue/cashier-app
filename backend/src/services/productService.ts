import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { AppError } from '../utils/AppError';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key'
);

export class ProductService {
  static async getProducts(query: { search?: string; category_id?: string; is_active?: string }) {
    let q = supabase.from('products').select('*, categories(nama)');
    if (query.search) {
      q = q.ilike('nama', `%${query.search}%`);
    }
    if (query.category_id) {
      q = q.eq('category_id', query.category_id);
    }
    if (query.is_active !== undefined) {
      q = q.eq('is_active', query.is_active === 'true');
    }
    const { data, error } = await q;
    if (error) throw new AppError('DATABASE_ERROR', 'Gagal mengambil daftar produk', 500);
    return data;
  }

  static async createProduct(body: any, userId: string | null) {
    const { data, error } = await supabase.from('products').insert([body]).select().single();
    if (error) throw new AppError('DATABASE_ERROR', 'Gagal membuat produk', 500);
    
    if (userId) {
      await supabase.from('activity_logs').insert([{
        user_id: userId,
        aksi: 'TAMBAH_PRODUK',
        entitas: 'products',
        entitas_id: data.id,
        detail: body
      }]);
    }

    return data;
  }

  static async updateProduct(id: number, body: any, userId: string | null) {
    const { data, error } = await supabase.from('products').update(body).eq('id', id).select().single();
    if (error) throw new AppError('DATABASE_ERROR', 'Gagal memperbarui produk', 500);

    if (userId) {
      await supabase.from('activity_logs').insert([{
        user_id: userId,
        aksi: 'UPDATE_PRODUK',
        entitas: 'products',
        entitas_id: id,
        detail: body
      }]);
    }

    return data;
  }

  static async softDeleteProduct(id: number, userId: string | null) {
    const { data, error } = await supabase.from('products').update({ is_active: false }).eq('id', id).select().single();
    if (error) throw new AppError('DATABASE_ERROR', 'Gagal menonaktifkan produk', 500);

    if (userId) {
      await supabase.from('activity_logs').insert([{
        user_id: userId,
        aksi: 'NONAKTIFKAN_PRODUK',
        entitas: 'products',
        entitas_id: id
      }]);
    }

    return data;
  }

  static async updateStock(id: number, tipe: 'masuk' | 'keluar' | 'koreksi' | 'retur', jumlah: number, userId: string | null) {
    const { data: product, error: fetchError } = await supabase.from('products').select('stok').eq('id', id).single();
    if (fetchError || !product) throw new AppError('NOT_FOUND', 'Produk tidak ditemukan', 404);

    const stokSebelum = product.stok;
    let stokSesudah = stokSebelum;
    if (tipe === 'masuk' || tipe === 'retur') {
      stokSesudah = stokSebelum + jumlah;
    } else if (tipe === 'keluar') {
      stokSesudah = stokSebelum - jumlah;
    } else if (tipe === 'koreksi') {
      stokSesudah = jumlah;
    }

    if (stokSesudah < 0) throw new AppError('INVALID_STOCK', 'Stok tidak boleh negatif', 400);

    const { error: updateError } = await supabase.from('products').update({ stok: stokSesudah }).eq('id', id);
    if (updateError) throw new AppError('DATABASE_ERROR', 'Gagal memperbarui stok', 500);

    await supabase.from('stock_movements').insert([{
      product_id: id,
      tipe,
      jumlah: Math.abs(stokSesudah - stokSebelum),
      stok_sebelum: stokSebelum,
      stok_sesudah: stokSesudah,
      created_by: userId || null
    }]);

    if (userId) {
      await supabase.from('activity_logs').insert([{
        user_id: userId,
        aksi: 'KOREKSI_STOK',
        entitas: 'products',
        entitas_id: id,
        detail: { tipe, stok_sebelum: stokSebelum, stok_sesudah: stokSesudah }
      }]);
    }

    return { stok_sebelum: stokSebelum, stok_sesudah: stokSesudah };
  }

  static async getLowStock() {
    const { data, error } = await supabase.from('products').select('*').eq('is_active', true);
    if (error) throw new AppError('DATABASE_ERROR', 'Gagal mengambil stok rendah', 500);
    return (data || []).filter((p: any) => p.stok <= p.stok_minimum);
  }
}
