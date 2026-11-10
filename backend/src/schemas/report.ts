import { z } from 'zod';

// Placeholder - akan diisi di prompt berikutnya
export const getProfitReportSchema = z.object({
  from_date: z.string().datetime().optional(),
  to_date: z.string().datetime().optional()
});

export type GetProfitReportInput = z.infer<typeof getProfitReportSchema>;
