import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { AppError } from '../utils/AppError';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key'
);

export interface RegisterInput {
  email: string;
  password: string;
  nama: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthUser {
  id: string;
  email: string;
  role: 'admin' | 'kasir' | 'user';
  nama: string;
}

export class AuthService {
  static async register(input: RegisterInput): Promise<AuthUser> {
    try {
      // Create user in Supabase Auth
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: input.email,
        password: input.password,
        email_confirm: true
      });

      if (authError || !authData.user) {
        throw new AppError('AUTH_ERROR', 'Gagal membuat akun', 400);
      }

      // Create profile (always role = 'user')
      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .insert([
          {
            id: authData.user.id,
            nama: input.nama,
            username: input.email.split('@')[0],
            role: 'user',
            is_active: true
          }
        ])
        .select()
        .single();

      if (profileError) {
        // Clean up auth user if profile creation fails
        await supabase.auth.admin.deleteUser(authData.user.id);
        throw new AppError('PROFILE_ERROR', 'Gagal membuat profil pengguna', 500);
      }

      return {
        id: profileData.id,
        email: authData.user.email || '',
        role: profileData.role,
        nama: profileData.nama
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      
      // Handle duplicate email
      if (error.message?.includes('duplicate') || error.message?.includes('already exists')) {
        throw new AppError('EMAIL_EXISTS', 'Email sudah terdaftar', 400);
      }
      
      throw new AppError('AUTH_ERROR', 'Gagal membuat akun', 500);
    }
  }

  static async login(input: LoginInput, ipAddress: string): Promise<{ access_token: string; user: AuthUser }> {
    try {
      // Generic error message to avoid email/password enumeration
      const genericError = new AppError(
        'INVALID_CREDENTIALS',
        'Email atau password salah',
        401
      );

      // Login with Supabase
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: input.email,
        password: input.password
      });

      if (authError || !authData.session) {
        throw genericError;
      }

      // Get user profile
      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authData.user?.id)
        .single();

      if (profileError || !profileData) {
        throw genericError;
      }

      // Check if user is active
      if (!profileData.is_active) {
        throw new AppError('ACCOUNT_INACTIVE', 'Akun tidak aktif', 403);
      }

      // Log login (untuk kasir, catat sesi; untuk user/admin, catat activity_log)
      if (profileData.role === 'kasir') {
        await supabase.from('cashier_sessions').insert([
          {
            kasir_id: authData.user.id,
            login_at: new Date().toISOString(),
            kas_awal: 0
          }
        ]);
      }

      // Activity log
      await supabase.from('activity_logs').insert([
        {
          user_id: authData.user.id,
          aksi: 'LOGIN',
          entitas: 'auth',
          entitas_id: authData.user.id,
          detail: { ip_address: ipAddress }
        }
      ]);

      return {
        access_token: authData.session.access_token,
        user: {
          id: authData.user.id,
          email: authData.user.email || '',
          role: profileData.role,
          nama: profileData.nama
        }
      };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('LOGIN_ERROR', 'Email atau password salah', 401);
    }
  }

  static async logout(userId: string): Promise<void> {
    try {
      // If kasir, close session
      const { data: profileData } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

      if (profileData?.role === 'kasir') {
        await supabase
          .from('cashier_sessions')
          .update({ logout_at: new Date().toISOString() })
          .eq('kasir_id', userId)
          .is('logout_at', null)
          .limit(1);
      }

      // Activity log
      await supabase.from('activity_logs').insert([
        {
          user_id: userId,
          aksi: 'LOGOUT',
          entitas: 'auth',
          entitas_id: userId
        }
      ]);

      // Sign out
      await supabase.auth.signOut();
    } catch (error: any) {
      throw new AppError('LOGOUT_ERROR', 'Gagal logout', 500);
    }
  }

  static async changePassword(userId: string, oldPassword: string, newPassword: string): Promise<void> {
    try {
      // Get user email for verification
      const { data: userData, error: userError } = await supabase.auth.admin.getUserById(userId);

      if (userError || !userData.user?.email) {
        throw new AppError('USER_NOT_FOUND', 'Pengguna tidak ditemukan', 404);
      }

      // Verify old password by attempting login
      const { error: verifyError } = await supabase.auth.signInWithPassword({
        email: userData.user.email,
        password: oldPassword
      });

      if (verifyError) {
        throw new AppError('INVALID_PASSWORD', 'Password lama salah', 401);
      }

      // Update password
      const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
        password: newPassword
      });

      if (updateError) {
        throw new AppError('PASSWORD_UPDATE_ERROR', 'Gagal mengubah password', 500);
      }

      // Activity log
      await supabase.from('activity_logs').insert([
        {
          user_id: userId,
          aksi: 'CHANGE_PASSWORD',
          entitas: 'auth',
          entitas_id: userId
        }
      ]);
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('PASSWORD_ERROR', 'Gagal mengubah password', 500);
    }
  }

  static async adminResetPassword(adminId: string, targetUserId: string): Promise<{ temp_password: string }> {
    try {
      // Verify admin
      const { data: adminProfile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', adminId)
        .single();

      if (adminProfile?.role !== 'admin') {
        throw new AppError('FORBIDDEN', 'Hanya admin yang bisa reset password', 403);
      }

      // Get target user
      const { data: targetUserData, error: targetError } = await supabase.auth.admin.getUserById(targetUserId);

      if (targetError || !targetUserData.user?.email) {
        throw new AppError('USER_NOT_FOUND', 'Pengguna tidak ditemukan', 404);
      }

      // Generate temporary password
      const tempPassword = Math.random().toString(36).slice(-8) + Math.random().toString(36).slice(-8);

      // Update password
      const { error: updateError } = await supabase.auth.admin.updateUserById(targetUserId, {
        password: tempPassword
      });

      if (updateError) {
        throw new AppError('RESET_ERROR', 'Gagal reset password', 500);
      }

      // Activity log
      await supabase.from('activity_logs').insert([
        {
          user_id: adminId,
          aksi: 'ADMIN_RESET_PASSWORD',
          entitas: 'auth',
          entitas_id: targetUserId,
          detail: { target_email: targetUserData.user.email }
        }
      ]);

      return { temp_password: tempPassword };
    } catch (error: any) {
      if (error instanceof AppError) throw error;
      throw new AppError('RESET_ERROR', 'Gagal reset password', 500);
    }
  }
}
