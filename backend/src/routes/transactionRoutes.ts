import { Router } from 'express';
import { TransactionController } from '../controllers/transactionController';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import {
  createTransactionSchema,
  voidRequestSchema,
  getTransactionsQuerySchema,
  transactionParamsSchema
} from '../schemas/transaction';

const router = Router();

// All transaction endpoints require authentication
// Only kasir and admin can access

router.post(
  '/',
  authenticate,
  authorize(['kasir', 'admin']),
  validate({ body: createTransactionSchema }),
  TransactionController.createTransaction
);

router.get(
  '/',
  authenticate,
  authorize(['kasir', 'admin']),
  validate({ query: getTransactionsQuerySchema }),
  TransactionController.listTransactions
);

router.get(
  '/:id',
  authenticate,
  authorize(['kasir', 'admin']),
  validate({ params: transactionParamsSchema }),
  TransactionController.getTransaction
);

router.get(
  '/:id/receipt',
  authenticate,
  authorize(['kasir', 'admin']),
  validate({ params: transactionParamsSchema }),
  TransactionController.getReceipt
);

router.post(
  '/:id/void-request',
  authenticate,
  authorize(['kasir', 'admin']),
  validate({ params: transactionParamsSchema, body: voidRequestSchema }),
  TransactionController.createVoidRequest
);

export default router;
