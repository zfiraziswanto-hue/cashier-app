import { z } from 'zod';

export const transactionItemSchema = z.object({
  product_id: z.number().int().positive('Product ID harus positif'),
  qty: z.number().int().positive('Qty harus lebih dari 0')
});

export const createTransactionSchema = z.object({
  items: z.array(transactionItemSchema).min(1, 'Minimal ada 1 item'),
  metode_bayar: z.enum(['tunai', 'qris', 'transfer'], {
    errorMap: () => ({ message: 'Metode bayar harus: tunai, qris, atau transfer' })
  }),
  uang_diterima: z.number().positive('Uang diterima harus positif'),
  order_id: z.number().int().optional()
});

export const voidRequestSchema = z.object({
  alasan: z.string().min(1, 'Alasan tidak boleh kosong').max(500)
});

export const getTransactionsQuerySchema = z.object({
  from_date: z.string().datetime().optional(),
  to_date: z.string().datetime().optional(),
  kasir_id: z.string().uuid().optional(),
  metode_bayar: z.enum(['tunai', 'qris', 'transfer']).optional(),
  page: z.string().transform(Number).optional(),
  limit: z.string().transform(Number).optional()
});

export const transactionParamsSchema = z.object({
  id: z.string().regex(/^\d+$/, 'ID harus berupa angka').transform(Number)
});

export type TransactionItem = z.infer<typeof transactionItemSchema>;
export type CreateTransactionInput = z.infer<typeof createTransactionSchema>;
export type VoidRequestInput = z.infer<typeof voidRequestSchema>;
export type GetTransactionsQuery = z.infer<typeof getTransactionsQuerySchema>;
export type TransactionParams = z.infer<typeof transactionParamsSchema>;

