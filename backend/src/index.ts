import 'dotenv/config';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import pino from 'pino';
import productRoutes from './routes/productRoutes';
import authRoutes from './routes/authRoutes';
import transactionRoutes from './routes/transactionRoutes';
import orderRoutes from './routes/orderRoutes';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';
import { globalRateLimiter } from './middleware/loginRateLimiter';
import { validateEnv } from './utils/validateEnv';
import { startAutoCancelOrdersJob } from './jobs/autoCancelOrders';

// Validate environment variables at startup
validateEnv();

const logger = pino();
const app = express();
const port = process.env.PORT || 4000;

// Middleware
app.use(helmet());
app.use(cors({ origin: process.env.FRONTEND_URL || 'http://localhost:3000' }));
app.use(express.json());
app.use(globalRateLimiter);
app.use(requestLogger);

// Health check endpoint
app.get('/api/v1/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok', timestamp: new Date().toISOString() } });
});

// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/products', productRoutes);
app.use('/api/v1/transactions', transactionRoutes);
app.use('/api/v1/orders', orderRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: `Endpoint ${req.method} ${req.path} tidak ditemukan`
    }
  });
});

// Error handler (harus di akhir)
app.use(errorHandler);

// Start server
const server = app.listen(port, () => {
  logger.info(`✓ Server berjalan di port ${port}`);
  logger.info(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Start scheduler untuk auto-cancel orders
const autoCancelJob = startAutoCancelOrdersJob();

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    if (autoCancelJob) {
      autoCancelJob.stop();
    }
    process.exit(0);
  });
});

export default app;
