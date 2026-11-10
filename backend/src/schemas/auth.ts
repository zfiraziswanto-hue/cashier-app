import { z } from 'zod';

export const registerSchema = z.object({
  email: z.string().email('Email tidak valid'),
  password: z.string().min(8, 'Password minimal 8 karakter'),
  nama: z.string().min(1, 'Nama tidak boleh kosong').max(255)
});

export const loginSchema = z.object({
  email: z.string().email('Email tidak valid'),
  password: z.string().min(1, 'Password tidak boleh kosong')
});

export const changePasswordSchema = z.object({
  old_password: z.string().min(1, 'Password lama tidak boleh kosong'),
  new_password: z.string().min(8, 'Password baru minimal 8 karakter')
});

export const resetPasswordParamsSchema = z.object({
  userId: z.string().uuid('User ID tidak valid')
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
export type ResetPasswordParams = z.infer<typeof resetPasswordParamsSchema>;
