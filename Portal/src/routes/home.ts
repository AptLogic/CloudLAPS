import express, { Request, Response } from 'express';
import { KeyVaultSecret } from '../models/KeyVaultSecret';
import { LogAnalyticsWrapper } from '../models/LogAnalyticsWrapper';
import { AuditEvent } from '../models/AuditEvent';
import { config } from '../config';
import { ensureAuthenticated } from '../middleware/authMiddleware';

const router = express.Router();

// All routes require authentication
router.use(ensureAuthenticated);

/**
 * Home page route
 */
router.get('/', (req: Request, res: Response) => {
  res.render('home/index', {
    title: 'CloudLAPS Portal',
    layout: 'layouts/main',
    result: null,
    secret: null,
    searchValue: '',
  });
});

/**
 * Legacy search page route
 * Redirects to the single-page root
 */
router.get('/search', (req: Request, res: Response) => {
  res.redirect('/');
});

/**
 * Search action route
 * Retrieves password from Key Vault and renders result on the single page
 */
router.get('/search/execute', async (req: Request, res: Response) => {
  const searchValue = req.query.searchValue as string;

  if (!searchValue || searchValue.trim() === '') {
    return res.render('home/index', {
      title: 'CloudLAPS Portal',
      layout: 'layouts/main',
      result: null,
      secret: null,
      searchValue: '',
    });
  }

  const trimmedSearchValue = searchValue.trim();

  try {
    const secret = await KeyVaultSecret.getComputerAsync(
      config.keyVault.uri,
      trimmedSearchValue
    );

    if (secret) {
      const logClient = new LogAnalyticsWrapper(
        config.logAnalytics.workspaceId,
        config.logAnalytics.sharedKey,
        config.logAnalytics.logType
      );

      const auditEvent: AuditEvent = {
        AzureADDeviceId: secret.secretAzureADDeviceId,
        UserPrincipalName: res.locals.user?.username || 'unknown',
        ComputerName: secret.secretDeviceName,
        SerialNumber: secret.secretSerialNumber,
        Action: 'SecretGet',
        CreatedOn: new Date().toISOString(),
        Result: 'Success',
        Id: secret.secretId,
      };

      logClient.sendLogEntry(auditEvent).catch((error) => {
        console.error('Failed to send audit log:', error);
      });

      return res.render('home/index', {
        title: 'CloudLAPS Portal',
        layout: 'layouts/main',
        result: 'Success',
        secret: secret,
        searchValue: trimmedSearchValue,
      });
    }

    return res.render('home/index', {
      title: 'CloudLAPS Portal',
      layout: 'layouts/main',
      result: 'Failed',
      secret: null,
      searchValue: trimmedSearchValue,
    });
  } catch (error) {
    console.error('Search error:', error);

    return res.render('home/index', {
      title: 'CloudLAPS Portal',
      layout: 'layouts/main',
      result: 'Failed',
      secret: null,
      searchValue: trimmedSearchValue,
    });
  }
});

export default router;
