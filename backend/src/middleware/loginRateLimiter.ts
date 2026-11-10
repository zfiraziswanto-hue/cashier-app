import { Request, Response, NextFunction } from 'express';
import { rateLimit } from 'express-rate-limit';

// Store untuk track failed attempts per IP+email
const failedAttempts = new Map<string, { count: number; resetTime: number }>();

export const loginRateLimiter = (req: Request, res: Response, next: NextFunction) => {
  const email = req.body?.email || 'unknown';
  const ip = req.ip || 'unknown';
  const key = `${ip}:${email}`;
  const now = Date.now();
  const fiveMinutes = 5 * 60 * 1000;

  const attempt = failedAttempts.get(key);

  // Reset jika sudah lebih dari 5 menit
  if (attempt && now > attempt.resetTime) {
    failedAttempts.delete(key);
    return next();
  }

  // Jika sudah 5x gagal dalam 5 menit, block
  if (attempt && attempt.count >= 5) {
    return res.status(429).json({
      success: false,
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Terlalu banyak percobaan login. Coba lagi dalam beberapa menit.'
      }
    });
  }

  // Attach helper untuk track failed attempts
  (req as any).recordLoginFailure = () => {
    if (!attempt) {
      failedAttempts.set(key, {
        count: 1,
        resetTime: now + fiveMinutes
      });
    } else {
      attempt.count++;
    }
  };

  (req as any).clearLoginAttempts = () => {
    failedAttempts.delete(key);
  };

  next();
};

// Global rate limiter untuk semua endpoint
export const globalRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 menit
  max: 100, // 100 requests per windowMs
  message: 'Terlalu banyak request, coba lagi nanti',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => process.env.NODE_ENV === 'development'
});
