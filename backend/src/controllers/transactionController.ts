import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { TransactionService } from '../services/transactionService';
import { asyncHandler } from '../utils/asyncHandler';
import { AppError } from '../utils/AppError';

const getString = (value: any): string | undefined => {
  if (Array.isArray(value)) return value[0];
  if (typeof value === 'string') return value;
  return undefined;
};

export class TransactionController {
  static createTransaction = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }
    const data = await TransactionService.createTransaction(req.body, req.user.id);
    res.status(201).json({ success: true, data });
  });

  static listTransactions = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id || !req.user?.role) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }

    const page = Math.max(1, parseInt(getString(req.query.page) || '1') || 1);
    const limit = Math.max(1, Math.min(100, parseInt(getString(req.query.limit) || '10') || 10));

    const data = await TransactionService.listTransactions(req.user.id, req.user.role, {
      from_date: getString(req.query.from_date),
      to_date: getString(req.query.to_date),
      kasir_id: getString(req.query.kasir_id),
      metode_bayar: getString(req.query.metode_bayar),
      page,
      limit
    });

    res.json({
      success: true,
      data: data.data,
      pagination: {
        page: data.page,
        limit: data.limit,
        total: data.total,
        pages: Math.ceil(data.total / data.limit)
      }
    });
  });

  static getTransaction = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id || !req.user?.role) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }

    const transactionId = req.params.id as any;
    if (!transactionId) {
      throw new AppError('INVALID_ID', 'ID transaksi tidak valid', 400);
    }

    const data = await TransactionService.getTransactionDetail(transactionId, req.user.id, req.user.role);
    res.json({ success: true, data });
  });

  static getReceipt = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id || !req.user?.role) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }

    const transactionId = req.params.id as any;
    if (!transactionId) {
      throw new AppError('INVALID_ID', 'ID transaksi tidak valid', 400);
    }

    const paperSize = (getString(req.query.paperSize) || '58mm') as '58mm' | '80mm';
    if (!['58mm', '80mm'].includes(paperSize)) {
      throw new AppError('INVALID_SIZE', 'Ukuran kertas harus 58mm atau 80mm', 400);
    }

    const html = await TransactionService.getReceipt(transactionId, req.user.id, req.user.role, paperSize);
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(html);
  });

  static createVoidRequest = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.user?.id) {
      throw new AppError('UNAUTHORIZED', 'User tidak ditemukan', 401);
    }

    const transactionId = req.params.id as any;
    if (!transactionId) {
      throw new AppError('INVALID_ID', 'ID transaksi tidak valid', 400);
    }

    const { alasan } = req.body;
    if (!alasan) {
      throw new AppError('MISSING_REASON', 'Alasan void harus diisi', 400);
    }

    const data = await TransactionService.createVoidRequest(transactionId, req.user.id, alasan);
    res.status(201).json({ success: true, data });
  });
}


