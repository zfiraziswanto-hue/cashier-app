import pino from 'pino';

const logger = pino();

const requiredEnvVars = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY'
];

const optionalEnvVars = [
  'PORT',
  'NODE_ENV',
  'FRONTEND_URL',
  'AUTO_CANCEL_ORDERS_ENABLED'
];

export const validateEnv = () => {
  const missing: string[] = [];

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      missing.push(envVar);
    }
  }

  if (missing.length > 0) {
    logger.error(`Missing required environment variables: ${missing.join(', ')}`);
    logger.error('Please check your .env file and ensure all required variables are set.');
    process.exit(1);
  }

  logger.info('✓ All required environment variables are set');

  // Log optional vars that are set
  const setOptional = optionalEnvVars.filter(v => process.env[v]);
  if (setOptional.length > 0) {
    logger.info(`Optional variables set: ${setOptional.join(', ')}`);
  }
};
