import { Request, Response, NextFunction } from 'express';
import pino from 'pino';

const logger = pino();

export const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  const originalSend = res.send;

  res.send = function(data: any) {
    const duration = Date.now() - startTime;
    
    // Mask sensitive data from logs
    const authHeader = req.headers.authorization ? 'Bearer [REDACTED]' : undefined;
    const body = req.body ? { ...req.body } : undefined;
    
    // Remove passwords and tokens from body logs
    if (body) {
      if ('password' in body) body.password = '[REDACTED]';
      if ('token' in body) body.token = '[REDACTED]';
      if ('old_password' in body) body.old_password = '[REDACTED]';
      if ('new_password' in body) body.new_password = '[REDACTED]';
    }

    logger.info({
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userId: (req as any).user?.id || 'anonymous',
      ...(body && { body }),
      ...(authHeader && { authorization: authHeader })
    });

    return originalSend.call(this, data);
  };

  next();
};
