import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { loginRateLimiter } from '../middleware/loginRateLimiter';
import {
  registerSchema,
  loginSchema,
  changePasswordSchema,
  resetPasswordParamsSchema
} from '../schemas/auth';

const router = Router();

// Public endpoints
router.post(
  '/register',
  validate({ body: registerSchema }),
  AuthController.register
);

router.post(
  '/login',
  loginRateLimiter,
  validate({ body: loginSchema }),
  AuthController.login
);

// Protected endpoints
router.post(
  '/logout',
  authenticate,
  AuthController.logout
);

router.patch(
  '/password',
  authenticate,
  validate({ body: changePasswordSchema }),
  AuthController.changePassword
);

// Admin endpoints
router.post(
  '/admin/reset-password/:userId',
  authenticate,
  authorize(['admin']),
  validate({ params: resetPasswordParamsSchema }),
  AuthController.adminResetPassword
);

export default router;
