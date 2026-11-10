import cron from 'node-cron';
import { createClient } from '@supabase/supabase-js';
import pino from 'pino';

const logger = pino();

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://placeholder.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key'
);

export const startAutoCancelOrdersJob = () => {
  const isEnabled = process.env.AUTO_CANCEL_ORDERS_ENABLED !== 'false';

  if (!isEnabled) {
    logger.info('Auto-cancel orders job is disabled');
    return null;
  }

  // Jalankan setiap 5 menit
  const job = cron.schedule('*/5 * * * *', async () => {
    try {
      logger.info('Running auto-cancel expired orders job');

      // Call database function
      const { error } = await supabase.rpc('auto_cancel_expired_orders');

      if (error) {
        logger.error({ error: error.message }, 'Error in auto-cancel job');
      } else {
        logger.info('Auto-cancel expired orders job completed successfully');
      }
    } catch (err: any) {
      logger.error({ error: err.message }, 'Unhandled error in auto-cancel job');
    }
  });

  logger.info('Auto-cancel orders job started (runs every 5 minutes)');
  return job;
};

export const stopAutoCancelOrdersJob = (job: any) => {
  if (job) {
    job.stop();
    logger.info('Auto-cancel orders job stopped');
  }
};
