import { Request, Response, NextFunction } from 'express';

interface EasyAuthClaim {
  typ?: string;
  val?: string;
}

interface EasyAuthPrincipal {
  claims?: EasyAuthClaim[];
}

function getClaimValue(claims: EasyAuthClaim[], types: string[]): string {
  for (const type of types) {
    const claim = claims.find((item) => item.typ === type && item.val);
    if (claim?.val) {
      return claim.val;
    }
  }
  return '';
}

function decodePrincipal(encodedPrincipal: string): EasyAuthPrincipal | null {
  try {
    const decoded = Buffer.from(encodedPrincipal, 'base64').toString('utf8');
    return JSON.parse(decoded) as EasyAuthPrincipal;
  } catch {
    return null;
  }
}

export function resolveEasyAuthUser(req: Request): {
  name: string;
  username: string;
  isAuthenticated: boolean;
} {
  const encodedPrincipal = req.header('x-ms-client-principal');
  if (!encodedPrincipal) {
    return { name: '', username: '', isAuthenticated: false };
  }

  const principal = decodePrincipal(encodedPrincipal);
  const claims = Array.isArray(principal?.claims) ? principal.claims : [];
  const headerPrincipalName = req.header('x-ms-client-principal-name') || '';

  const username =
    headerPrincipalName ||
    getClaimValue(claims, [
      'preferred_username',
      'upn',
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn',
      'email',
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress',
      'unique_name',
    ]);

  const displayName =
    getClaimValue(claims, [
      'name',
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name',
    ]) || username;

  if (!username && !displayName) {
    return { name: '', username: '', isAuthenticated: false };
  }

  return {
    name: displayName,
    username: username || displayName,
    isAuthenticated: true,
  };
}

/**
 * Middleware to ensure user is authenticated
 * Redirects to sign-in page if not authenticated
 */
export function ensureAuthenticated(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const user = resolveEasyAuthUser(req);
  if (user.isAuthenticated) {
    return next();
  }

  const returnTo = encodeURIComponent(req.originalUrl || '/');
  res.redirect(`/.auth/login/aad?post_login_redirect_uri=${returnTo}`);
}

/**
 * Middleware to attach user information to response locals
 * Makes user data available in all views
 */
export function attachUser(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  res.locals.user = resolveEasyAuthUser(req);
  next();
}
