import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import helmet from 'helmet';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';
import expressLayouts from 'express-ejs-layouts';

// Import configuration
import { config, validateConfig } from './config';

// Import routes
import authRoutes from './routes/auth';
import homeRoutes from './routes/home';

// Import middleware
import { attachUser } from './middleware/authMiddleware';

const app = express();

// Respect reverse proxy headers when deployed behind App Service/front-door/load balancers.
if (config.app.nodeEnv === 'production') {
  const trustProxy = config.app.trustProxy.trim().toLowerCase();
  if (trustProxy === 'true') {
    app.set('trust proxy', true);
  } else if (trustProxy === 'false') {
    app.set('trust proxy', false);
  } else {
    const trustProxyHops = Number.parseInt(trustProxy, 10);
    if (!Number.isNaN(trustProxyHops)) {
      app.set('trust proxy', trustProxyHops);
    }
  }
}

// Validate configuration on startup
try {
  validateConfig();
} catch (error) {
  if (error instanceof Error) {
    console.error('Configuration validation failed:', error.message);
    if (config.app.nodeEnv === 'production') {
      process.exit(1);
    }
  }
}

// View engine setup
app.set('views', path.join(__dirname, '../views'));
app.set('view engine', 'ejs');
app.use(expressLayouts);
app.set('layout', 'layouts/main');

// Security middleware
app.use(
  helmet({
    contentSecurityPolicy: false, // Disable CSP for Bootstrap/jQuery compatibility
    crossOriginEmbedderPolicy: false,
  })
);

// Logging middleware
if (config.app.nodeEnv === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// Third-party frontend libraries (served from node_modules)
app.use(
  '/lib/bootstrap/dist',
  express.static(path.join(__dirname, '../node_modules/bootstrap/dist'))
);
app.use(
  '/lib/jquery/dist',
  express.static(path.join(__dirname, '../node_modules/jquery/dist'))
);

// Static files middleware
app.use(express.static(path.join(__dirname, '../public')));

// Attach user information to all views
app.use(attachUser);

// Routes
app.use('/auth', authRoutes);
app.use('/', homeRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).render('error', {
    title: 'Not Found',
    message: 'The page you are looking for does not exist.',
    layout: false,
  });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Application error:', err.stack);
  
  const statusCode = res.statusCode !== 200 ? res.statusCode : 500;
  
  res.status(statusCode).render('error', {
    title: 'Error',
    message:
      config.app.nodeEnv === 'development'
        ? err.message
        : 'An error occurred while processing your request.',
    layout: false,
  });
});

// Start server
const PORT = config.app.port;

app.listen(PORT, () => {
  console.log('===========================================');
  console.log('CloudLAPS Portal - Node.js Edition');
  console.log('===========================================');
  console.log(`Environment: ${config.app.nodeEnv}`);
  console.log(`Server running on: http://localhost:${PORT}`);
  console.log(`Key Vault: ${config.keyVault.uri || 'NOT CONFIGURED'}`);
  console.log(`Log Analytics: ${config.logAnalytics.workspaceId || 'NOT CONFIGURED'}`);
  console.log('===========================================');
  console.log('');
  console.log('Available routes:');
  console.log('  GET  /              - Single-page portal');
  console.log('  GET  /search/execute - Search action');
  console.log('  GET  /privacy       - Redirects to #privacy section');
  console.log('  GET  /auth/signin   - Sign in');
  console.log('  GET  /auth/signout  - Sign out');
  console.log('');
  console.log('Press Ctrl+C to stop the server');
  console.log('===========================================');
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  process.exit(0);
});

export default app;
