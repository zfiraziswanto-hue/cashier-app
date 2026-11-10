import { Request, Response, NextFunction } from 'express';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key'
);

export interface AuthRequest extends Request {
  user?: {
    id: string;
    email?: string;
    role: 'admin' | 'kasir' | 'user';
    nama: string;
  };
}

export const authenticate = async (req: AuthRequest, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Token tidak ditemukan' } });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Token tidak valid' } });
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (profileError || !profile || !profile.is_active) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Akun tidak aktif atau tidak ditemukan' } });
      return;
    }

    req.user = {
      id: user.id,
      email: user.email,
      role: profile.role,
      nama: profile.nama
    };

    next();
  } catch {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Kesalahan server otentikasi' } });
  }
};

export const authorize = (allowedRoles: ('admin' | 'kasir' | 'user')[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Akses ditolak' } });
      return;
    }
    next();
  };
};
