import { Router } from 'express';
import { OrderController } from '../controllers/orderController';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import {
  createOrderSchema,
  confirmPaymentSchema,
  orderParamsSchema
} from '../schemas/order';

const router = Router();

// POST /orders - Create order (user only)
router.post(
  '/',
  authenticate,
  authorize(['user']),
  validate({ body: createOrderSchema }),
  OrderController.createOrder
);

// GET /mine - Get user's orders (MUST be before /:id)
router.get(
  '/mine',
  authenticate,
  authorize(['user']),
  OrderController.getUserOrders
);

// GET / - Search by kode_pesanan (kasir/admin)
router.get(
  '/',
  authenticate,
  authorize(['kasir', 'admin']),
  OrderController.getOrderByKode
);

// PATCH /:id/cancel - Cancel order (user only)
router.patch(
  '/:id/cancel',
  authenticate,
  authorize(['user']),
  validate({ params: orderParamsSchema }),
  OrderController.cancelOrder
);

// POST /:id/confirm-payment - Confirm payment (kasir only)
router.post(
  '/:id/confirm-payment',
  authenticate,
  authorize(['kasir']),
  validate({ params: orderParamsSchema, body: confirmPaymentSchema }),
  OrderController.confirmPayment
);

export default router;
