import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { AuthService } from '../services/authService';
import { asyncHandler } from '../utils/asyncHandler';

export class AuthController {
  static register = asyncHandler(async (req: AuthRequest, res: Response) => {
    const data = await AuthService.register(req.body);
    res.status(201).json({ success: true, data });
  });

  static login = asyncHandler(async (req: AuthRequest, res: Response) => {
    const ipAddress = req.ip || 'unknown';
    const data = await AuthService.login(req.body, ipAddress);
    res.json({ success: true, data });
  });

  static logout = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new Error('User not found');
    }
    await AuthService.logout(req.user.id);
    res.json({ success: true, data: { message: 'Logout berhasil' } });
  });

  static changePassword = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new Error('User not found');
    }
    const { old_password, new_password } = req.body;
    await AuthService.changePassword(req.user.id, old_password, new_password);
    res.json({ success: true, data: { message: 'Password berhasil diubah' } });
  });

  static adminResetPassword = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new Error('User not found');
    }
    const userId = Array.isArray(req.params.userId) ? req.params.userId[0] : req.params.userId;
    const data = await AuthService.adminResetPassword(req.user.id, userId);
    res.json({ success: true, data });
  });
}
