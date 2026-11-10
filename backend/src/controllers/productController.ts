import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { ProductService } from '../services/productService';
import { asyncHandler } from '../utils/asyncHandler';
import { AppError } from '../utils/AppError';

export class ProductController {
  static getProducts = asyncHandler(async (req: AuthRequest, res: Response) => {
    const query = req.query as any;
    const data = await ProductService.getProducts(query);
    
    let warning = null;
    const hasWarning = (data as any[]).some(p => p.harga_jual < p.harga_modal);
    if (hasWarning) {
      warning = 'Ada produk dengan harga jual lebih kecil dari harga modal.';
    }
    
    res.json({ success: true, data, warning });
  });

  static createProduct = asyncHandler(async (req: AuthRequest, res: Response) => {
    const userId = req.user?.id ? String(req.user.id) : null;
    const data = await ProductService.createProduct(req.body, userId);
    
    const warning = data.harga_jual < data.harga_modal ? 'Harga jual lebih kecil dari harga modal.' : null;
    res.status(201).json({ success: true, data, warning });
  });

  static updateProduct = asyncHandler(async (req: AuthRequest, res: Response) => {
    const id = req.params.id as any;
    const userId = req.user?.id ? String(req.user.id) : null;
    
    const data = await ProductService.updateProduct(id, req.body, userId);
    const warning = data.harga_jual < data.harga_modal ? 'Harga jual lebih kecil dari harga modal.' : null;
    
    res.json({ success: true, data, warning });
  });

  static softDeleteProduct = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (req.user!.role !== 'admin') {
      throw new AppError('FORBIDDEN', 'Hanya admin yang dapat menonaktifkan produk', 403);
    }
    
    const id = req.params.id as any;
    const userId = req.user?.id ? String(req.user.id) : null;
    
    const data = await ProductService.softDeleteProduct(id, userId);
    res.json({ success: true, data });
  });

  static updateStock = asyncHandler(async (req: AuthRequest, res: Response) => {
    const id = req.params.id as any;
    const { tipe, jumlah } = req.body;
    const userId = req.user?.id ? String(req.user.id) : null;
    
    const data = await ProductService.updateStock(id, tipe, jumlah, userId);
    res.json({ success: true, data });
  });

  static getLowStock = asyncHandler(async (req: AuthRequest, res: Response) => {
    const data = await ProductService.getLowStock();
    res.json({ success: true, data });
  });
}
