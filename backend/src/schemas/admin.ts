import { z } from 'zod';

// Placeholder - akan diisi di prompt berikutnya
export const createCashierSchema = z.object({
  nama: z.string().min(1),
  username: z.string().min(1),
  password: z.string().min(6),
  email: z.string().email()
});

export type CreateCashierInput = z.infer<typeof createCashierSchema>;
