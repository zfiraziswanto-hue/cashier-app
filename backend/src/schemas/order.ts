import { z } from 'zod';

export const orderItemSchema = z.object({
  product_id: z.number().int().positive('Product ID harus positif'),
  qty: z.number().int().positive('Qty harus lebih dari 0')
});

export const createOrderSchema = z.object({
  items: z.array(orderItemSchema).min(1, 'Minimal ada 1 item')
});

export const confirmPaymentSchema = z.object({
  metode_bayar: z.enum(['tunai', 'qris', 'transfer'], {
    errorMap: () => ({ message: 'Metode bayar harus: tunai, qris, atau transfer' })
  }),
  uang_diterima: z.number().positive('Uang diterima harus positif')
});

export const orderParamsSchema = z.object({
  id: z.string().regex(/^\d+$/, 'ID harus berupa angka').transform(Number)
});

export type OrderItem = z.infer<typeof orderItemSchema>;
export type CreateOrderInput = z.infer<typeof createOrderSchema>;
export type ConfirmPaymentInput = z.infer<typeof confirmPaymentSchema>;
export type OrderParams = z.infer<typeof orderParamsSchema>;
