import express, { Request, Response } from 'express';
import { config } from '../config';

const router = express.Router();

/**
 * Redirect to App Service Easy Auth login endpoint
 */
router.get('/signin', (req: Request, res: Response) => {
  const returnTo = encodeURIComponent(req.query.returnTo as string || '/');
  res.redirect(`/.auth/login/aad?post_login_redirect_uri=${returnTo}`);
});

/**
 * Legacy callback endpoint removed - Easy Auth owns callback handling.
 */
router.get('/callback', (_req: Request, res: Response) => {
  res.status(410).render('error', {
    title: 'Authentication Changed',
    message: 'This application now uses Azure App Service Easy Auth. Use /auth/signin to start sign-in.',
    layout: false,
  });
});

/**
 * Redirect to App Service Easy Auth logout endpoint
 */
router.get('/signout', (req: Request, res: Response) => {
  const fallbackBaseUrl = `${req.protocol}://${req.get('host')}`;
  const postLogoutUri = config.app.baseUrl || fallbackBaseUrl;
  const encodedReturnUri = encodeURIComponent(postLogoutUri);
  res.redirect(`/.auth/logout?post_logout_redirect_uri=${encodedReturnUri}`);
});

export default router;
