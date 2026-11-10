import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/AppError';

export const errorHandler = (err: any, req: Request, res: Response, next: NextFunction) => {
  const isDevelopment = process.env.NODE_ENV !== 'production';

  // Handle AppError
  if (err instanceof AppError) {
    return res.status(err.statusCode).json(err.toJSON());
  }

  // Handle Zod validation errors
  if (err.name === 'ZodError') {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request data',
        details: err.errors.map((e: any) => ({
          path: e.path.join('.'),
          message: e.message
        }))
      }
    });
  }

  // Handle generic errors
  console.error('Unhandled error:', err);
  
  const errorResponse: any = {
    success: false,
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Internal server error'
    }
  };

  if (isDevelopment) {
    errorResponse.error.stack = err.stack;
  }

  res.status(500).json(errorResponse);
};
