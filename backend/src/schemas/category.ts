import { z } from 'zod';

// Placeholder - akan diisi di prompt berikutnya
export const createCategorySchema = z.object({
  nama: z.string().min(1, 'Nama kategori tidak boleh kosong').max(255)
});

export const updateCategorySchema = createCategorySchema.partial();

export type CreateCategoryInput = z.infer<typeof createCategorySchema>;
export type UpdateCategoryInput = z.infer<typeof updateCategorySchema>;
