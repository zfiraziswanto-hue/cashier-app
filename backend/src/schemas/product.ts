import { z } from 'zod';

export const createProductSchema = z.object({
  category_id: z.number().int().positive('Category ID harus positif'),
  nama: z.string().min(1, 'Nama produk tidak boleh kosong').max(255),
  harga_modal: z.number().positive('Harga modal harus positif'),
  harga_jual: z.number().positive('Harga jual harus positif'),
  stok: z.number().int().nonnegative('Stok tidak boleh negatif').default(0),
  stok_minimum: z.number().int().nonnegative('Stok minimum tidak boleh negatif').default(5)
});

export const updateProductSchema = createProductSchema.partial();

export const updateStockSchema = z.object({
  tipe: z.enum(['masuk', 'keluar', 'koreksi', 'retur'], {
    errorMap: () => ({ message: 'Tipe stok harus: masuk, keluar, koreksi, atau retur' })
  }),
  jumlah: z.number().int().positive('Jumlah harus lebih dari 0')
});

export const getProductsQuerySchema = z.object({
  search: z.string().optional(),
  category_id: z.string().optional(),
  is_active: z.enum(['true', 'false']).optional()
});

export const productParamsSchema = z.object({
  id: z.string().regex(/^\d+$/, 'ID harus berupa angka').transform(Number)
});

export type CreateProductInput = z.infer<typeof createProductSchema>;
export type UpdateProductInput = z.infer<typeof updateProductSchema>;
export type UpdateStockInput = z.infer<typeof updateStockSchema>;
export type GetProductsQuery = z.infer<typeof getProductsQuerySchema>;
