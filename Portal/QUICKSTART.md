# CloudLAPS Portal - Quick Start Guide

## Local Development Setup (5 minutes)

### 1. Install Node.js
Download and install Node.js 18+ from: https://nodejs.org/

Verify installation:
```bash
node --version  # Should show v18.x.x or higher
npm --version   # Should show v9.x.x or higher
```

### 2. Install Dependencies
```bash
cd node-rewrite
npm install
```

### 3. Configure Environment
```bash
cp .env.example .env
```

Edit `.env` and fill in these required values:
- `APP_BASE_URL` - Public app URL used for Easy Auth sign-out redirects
- `KEY_VAULT_URI` - Your Key Vault URL
- `LOG_ANALYTICS_WORKSPACE_ID` - From Log Analytics
- `LOG_ANALYTICS_SHARED_KEY` - From Log Analytics

Sign-in parity mode notes:
- Authentication is enforced by Azure App Service Easy Auth.

### 4. Build and Run
```bash
npm run build
npm run dev
```

Open browser to: http://localhost:3000

## Azure Setup Checklist

### App Service Easy Auth
- [ ] Enable App Service Authentication
- [ ] Add Microsoft identity provider (single tenant)
- [ ] Set unauthenticated requests to "Require authentication"
- [ ] Add callback URI: `https://<app-name>.azurewebsites.net/.auth/login/aad/callback`

### Azure Key Vault
- [ ] Grant app registration "Get" and "List" secret permissions
- [ ] Verify secrets are stored with correct naming (serial number/computer name)
- [ ] Verify secrets have tags: DeviceName, UserName, AzureADDeviceID

### Azure Log Analytics
- [ ] Copy Workspace ID
- [ ] Copy Primary Key (Shared Key)
- [ ] Verify CloudLAPSAudit_CL table appears after first log

## Common Issues

**"npm not found"**
- Install Node.js first

**"Missing environment variables"**
- Copy .env.example to .env and fill in values

**"Cannot find module"**
- Run `npm install` first

**"Authentication error"**
- Verify App Service Authentication is enabled and requires authentication
- Check the Easy Auth callback URI is configured correctly

**"Key Vault error"**
- Run `az login` for local development
- Verify Key Vault permissions

## Production Deployment

See README.md for full deployment instructions to Azure App Service.

Quick version:
1. Create Node.js App Service
2. Enable Managed Identity
3. Grant Key Vault access to Managed Identity
4. Configure environment variables
5. Deploy code

## Support

- Full documentation: See README.md
- Original C# version: https://github.com/MSEndpointMgr/CloudLAPS
