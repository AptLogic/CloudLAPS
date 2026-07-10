import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

export const config = {
  keyVault: {
    uri: process.env.KEY_VAULT_URI || '',
  },
  logAnalytics: {
    workspaceId: process.env.LOG_ANALYTICS_WORKSPACE_ID || '',
    sharedKey: process.env.LOG_ANALYTICS_SHARED_KEY || '',
    logType: process.env.LOG_ANALYTICS_LOG_TYPE || 'CloudLAPSAudit',
  },
  app: {
    port: parseInt(process.env.PORT || '3000', 10),
    nodeEnv: process.env.NODE_ENV || 'development',
    trustProxy: process.env.TRUST_PROXY || (process.env.NODE_ENV === 'production' ? '1' : '0'),
    baseUrl: process.env.APP_BASE_URL || '',
  },
};

// Validate required configuration
export function validateConfig(): void {
  const required = [
    { key: 'KEY_VAULT_URI', value: config.keyVault.uri },
    { key: 'LOG_ANALYTICS_WORKSPACE_ID', value: config.logAnalytics.workspaceId },
    { key: 'LOG_ANALYTICS_SHARED_KEY', value: config.logAnalytics.sharedKey },
  ];

  const missing = required.filter((item) => !item.value);

  if (missing.length > 0 && config.app.nodeEnv !== 'development') {
    const missingKeys = missing.map((item) => item.key).join(', ');
    throw new Error(`Missing required environment variables: ${missingKeys}`);
  }

  if (config.app.nodeEnv === 'production' && !config.app.baseUrl) {
    throw new Error('APP_BASE_URL is required in production for Easy Auth sign-out redirect');
  }

  if (missing.length > 0) {
    console.warn('⚠️  Warning: Missing environment variables:', missing.map((item) => item.key).join(', '));
    console.warn('⚠️  Please copy .env.example to .env and fill in the values');
  }
}
