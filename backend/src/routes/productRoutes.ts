import { Router } from 'express';
import { ProductController } from '../controllers/productController';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import {
  createProductSchema,
  updateProductSchema,
  updateStockSchema,
  getProductsQuerySchema,
  productParamsSchema
} from '../schemas/product';

const router = Router();

router.get(
  '/',
  authenticate,
  validate({ query: getProductsQuerySchema }),
  ProductController.getProducts
);

router.get(
  '/low-stock',
  authenticate,
  authorize(['admin', 'kasir']),
  ProductController.getLowStock
);

router.post(
  '/',
  authenticate,
  authorize(['admin', 'kasir']),
  validate({ body: createProductSchema }),
  ProductController.createProduct
);

router.patch(
  '/:id',
  authenticate,
  authorize(['admin', 'kasir']),
  validate({ params: productParamsSchema, body: updateProductSchema }),
  ProductController.updateProduct
);

router.delete(
  '/:id',
  authenticate,
  authorize(['admin']),
  validate({ params: productParamsSchema }),
  ProductController.softDeleteProduct
);

router.post(
  '/:id/stock',
  authenticate,
  authorize(['admin', 'kasir']),
  validate({ params: productParamsSchema, body: updateStockSchema }),
  ProductController.updateStock
);

export default router;
