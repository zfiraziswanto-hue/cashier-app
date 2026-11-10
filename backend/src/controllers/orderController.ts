import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { OrderService } from '../services/orderService';
import { asyncHandler } from '../utils/asyncHandler';
import { AppError } from '../utils/AppError';

export class OrderController {
  static createOrder = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }
    if (req.user.role !== 'user') {
      throw new AppError('FORBIDDEN', 'Hanya user yang bisa membuat pesanan', 403);
    }
    
    const data = await OrderService.createOrder(req.body, req.user.id);
    res.status(201).json({ success: true, data });
  });

  static getUserOrders = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }
    if (req.user.role !== 'user') {
      throw new AppError('FORBIDDEN', 'Hanya user yang bisa melihat pesanan mereka', 403);
    }
    
    const data = await OrderService.getUserOrders(req.user.id);
    res.json({ success: true, data });
  });

  static cancelOrder = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }
    if (req.user.role !== 'user') {
      throw new AppError('FORBIDDEN', 'Hanya user yang bisa membatalkan pesanan', 403);
    }
    
    const orderId = req.params.id as any;
    if (!orderId) {
      throw new AppError('INVALID_ID', 'ID pesanan tidak valid', 400);
    }
    
    const data = await OrderService.cancelOrder(orderId, req.user.id);
    res.json({ success: true, data });
  });

  static getOrderByKode = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id || !req.user?.role) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }
    
    const kodePesanan = req.query.kode_pesanan as string;
    if (!kodePesanan) {
      throw new AppError('MISSING_PARAM', 'Kode pesanan harus diisi', 400);
    }
    
    const data = await OrderService.getOrderByKode(kodePesanan, req.user.role);
    res.json({ success: true, data });
  });

  static confirmPayment = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }
    if (req.user.role !== 'kasir') {
      throw new AppError('FORBIDDEN', 'Hanya kasir yang bisa mengkonfirmasi pembayaran', 403);
    }
    
    const orderId = req.params.id as any;
    if (!orderId) {
      throw new AppError('INVALID_ID', 'ID pesanan tidak valid', 400);
    }
    
    const { metode_bayar, uang_diterima } = req.body;
    
    const data = await OrderService.confirmPayment(orderId, req.user.id, metode_bayar, uang_diterima);
    res.json({ success: true, data });
  });
}
