# CloudLAPS Portal - Node.js Edition

A secure web portal for IT administrators to retrieve local administrator passwords stored in Azure Key Vault. This is a Node.js/TypeScript port of the original ASP.NET Core application.

## Overview

CloudLAPS Portal provides a cloud-based implementation of Microsoft's LAPS (Local Administrator Password Solution) using Azure Key Vault for secure password storage and Azure Log Analytics for comprehensive audit logging.

## Features

- **Azure AD Authentication**: Secure sign-in using Microsoft Azure Active Directory
- **Key Vault Integration**: Retrieve passwords stored securely in Azure Key Vault
- **Audit Logging**: All password retrievals are logged to Azure Log Analytics
- **Device Search**: Search by serial number (physical devices) or computer name (virtual machines)
- **Responsive UI**: Bootstrap-based interface that works on desktop and mobile
- **TypeScript**: Fully typed codebase for better maintainability and fewer bugs

## Technology Stack

- **Runtime**: Node.js 26+ / TypeScript 6+
- **Web Framework**: Express.js
- **View Engine**: EJS (Embedded JavaScript templating)
- **Authentication**: Azure App Service Authentication (Easy Auth)
- **Azure SDKs**: 
  - `@azure/identity` - Managed Identity authentication
  - `@azure/keyvault-secrets` - Key Vault access
- **Security**: Helmet

## Prerequisites

Before you begin, ensure you have the following installed:

- [Node.js](https://nodejs.org/) (v26.0.0 or higher)
- [npm](https://www.npmjs.com/) (v11.0.0 or higher)
- An Azure subscription with the following resources:
  - Azure Key Vault
  - Azure Log Analytics Workspace
  - Azure AD App Registration

Authentication notes:
- The app relies on Azure App Service Easy Auth for interactive login.
- No app-managed Azure AD secret or callback handling exists in this runtime.

## Installation

### 1. Clone the Repository

```bash
cd node-rewrite
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment Variables

Copy the `.env.example` file to `.env`:

```bash
cp .env.example .env
```

Edit the `.env` file and fill in your Azure configuration:

```env
# Authentication
APP_BASE_URL=http://localhost:3000

# Azure Key Vault
KEY_VAULT_URI=https://your-keyvault.vault.azure.net

# Azure Log Analytics
LOG_ANALYTICS_WORKSPACE_ID=your-workspace-id-here
LOG_ANALYTICS_SHARED_KEY=your-shared-key-here
LOG_ANALYTICS_LOG_TYPE=CloudLAPSAudit

# Application Settings
NODE_ENV=development
PORT=3000
TRUST_PROXY=0
```

### 4. Build the Application

```bash
npm run build
```

### 5. Run the Application

For development (with auto-reload):
```bash
npm run dev
```

For production:
```bash
npm start
```

The application will be available at `http://localhost:3000`

## Azure Configuration

### 1. App Service Authentication (Easy Auth)

1. Navigate to Azure Portal → App Service → Authentication
2. Add Microsoft identity provider (single tenant)
3. Set "Unauthenticated requests" to "Require authentication"
4. Ensure callback URI is configured in Entra app registration:
   - `https://<your-app-name>.azurewebsites.net/.auth/login/aad/callback`
5. Keep scope usage identity-only for app gating and user identity display.

### 2. Azure Key Vault

Your Key Vault should already contain device passwords stored as secrets with:
- **Secret name**: Device serial number or computer name
- **Secret value**: Local administrator password
- **Tags**:
  - `DeviceName`: Computer name
  - `UserName`: Local admin username
  - `AzureADDeviceID`: Azure AD device ID

Configure access:
1. Navigate to your Key Vault → Access policies
2. Add access policy:
   - **Secret permissions**: Get, List
   - **Select principal**: Your Azure AD App Registration

For local development with Managed Identity:
```bash
az login
```

### 3. Azure Log Analytics

1. Navigate to your Log Analytics workspace
2. Go to "Agents management"
3. Note the **Workspace ID** and **Primary Key**
4. These will be used for audit logging

The application creates a custom log table named `CloudLAPSAudit_CL` with the following fields:
- AzureADDeviceId
- UserPrincipalName
- ComputerName
- SerialNumber
- Action
- CreatedOn
- Result
- Id

## Project Structure

```
Portal/
├── src/
│   ├── app.ts                      # Main application entry point
│   ├── config/
│   │   ├── index.ts                # Configuration management
│   ├── models/
│   │   ├── AuditEvent.ts           # Audit event interface
│   │   ├── KeyVaultSecret.ts       # Key Vault operations
│   │   └── LogAnalyticsWrapper.ts  # Log Analytics client
│   ├── routes/
│   │   ├── auth.ts                 # Authentication routes
│   │   └── home.ts                 # Main application routes
│   ├── middleware/
│   │   └── authMiddleware.ts       # Authentication middleware
├── views/
│   ├── layouts/
│   │   └── main.ejs                # Main layout template
│   ├── home/
│   │   ├── index.ejs               # Home page
│   │   ├── search.ejs              # Search page
│   │   └── privacy.ejs             # Privacy policy
│   ├── partials/
│   │   └── loading.ejs             # Loading spinner
│   └── error.ejs                   # Error page
├── public/
│   ├── css/
│   │   └── site.css                # Custom styles
│   ├── js/
│   │   └── site.js                 # Custom JavaScript
│   ├── images/
│   │   └── logo.png                # Application logo
│   └── lib/                        # Bootstrap, jQuery
├── package.json                    # Node.js dependencies
├── tsconfig.json                   # TypeScript configuration
├── .env.example                    # Environment variables template
└── README.md                       # This file
```

## Usage

### Sign In

1. Navigate to `http://localhost:3000`
2. Click "Sign in" in the navigation bar
3. Authenticate with your Azure AD credentials

Authentication is completed by Azure App Service Easy Auth before requests reach the app.

### Search for Password

1. After signing in, click "Search" in the navigation
2. Enter:
   - **Serial number** for physical devices
   - **Computer name** for virtual machines
3. Click "Search"
4. The password and device information will be displayed

### Audit Trail

All password retrievals are automatically logged to Azure Log Analytics. To view the audit log:

```kusto
CloudLAPSAudit_CL
| where TimeGenerated > ago(30d)
| project TimeGenerated, UserPrincipalName_s, ComputerName_s, SerialNumber_s, Action_s, Result_s
| order by TimeGenerated desc
```

## Development

### Available Scripts

- `npm run dev` - Run in development mode with auto-reload
- `npm run build` - Compile TypeScript to JavaScript
- `npm start` - Run the compiled application
- `npm run watch` - Watch TypeScript files for changes
- `npm run clean` - Remove compiled files

### Code Style

This project uses:
- TypeScript strict mode
- ES2020 target
- CommonJS modules

## Deployment

### Docker Container Deployment to Azure App Service

The Docker image is prebuilt and available at `ghcr.io/aptlogic/cloudlaps-portal`.

1. **Create or update App Service**:
   ```bash
   az appservice plan create --name <plan-name> --resource-group <rg-name> --sku B2 --is-linux
   az webapp create --resource-group <rg-name> --plan <plan-name> --name <app-name> --deployment-container-image-name ghcr.io/aptlogic/cloudlaps-portal:latest
   ```

2. **Configure container settings**:
   - In Azure Portal → App Service → Deployment → Container settings
   - Set Image Source to Other Registry
   - Enter image: `ghcr.io/aptlogic/cloudlaps-portal:latest`

3. **Set application settings** (see below)

4. **Restart the App Service**:
   ```bash
   az webapp restart --resource-group <rg-name> --name <app-name>
   ```

### App Service Application Settings

In Azure App Service → Settings → Environment Variables, set runtime app settings required by this app (matching `.env.example`), including `APP_BASE_URL`, Key Vault, Log Analytics, and port/trust-proxy values as needed.

Ensure the following are configured:
- `PORT=3000` (or your configured port)
- `WEBSITES_ENABLE_APP_SERVICE_STORAGE=false` (for stateless containers)
- All environment variables from `.env.example`

## Security Considerations

- **Easy Auth Required**: The app expects App Service Authentication to enforce sign-in
- **HTTPS**: Always use HTTPS in production
- **Environment Variables**: Never commit `.env` file to source control
- **Key Vault Access**: Use Managed Identity in production (no credentials in code)
- **Audit Logging**: All password retrievals are logged for compliance
- **Rate Limiting**: Consider adding rate limiting for the search endpoint

## Troubleshooting

### "Missing required environment variables"

Ensure all required variables are set in your `.env` file. Copy from `.env.example` and fill in the values.

### "Error retrieving secret from Key Vault"

1. Verify the Key Vault URI is correct
2. Ensure your Azure AD app or Managed Identity has "Get" and "List" secret permissions
3. Check that the secret name (serial number/computer name) exists in Key Vault
4. Run `az login` for local development

### "Authentication Error"

1. Verify App Service Authentication is enabled and set to require authentication
2. Ensure callback URI is configured as `/.auth/login/aad/callback`
3. Confirm the app receives `x-ms-client-principal` headers in requests

### "Failed to send audit log"

1. Verify Log Analytics Workspace ID and Shared Key
2. Check network connectivity to Azure
3. Review application logs for detailed error messages

## Migration from C# Version

This application is a direct port of the ASP.NET Core version with the following improvements:

- **Better Error Handling**: No silent exception swallowing
- **Modern JavaScript**: TypeScript for type safety
- **Improved Security**: Helmet middleware and App Service Easy Auth enforcement
- **Simplified Deployment**: Single runtime (Node.js)
- **Lower Resource Usage**: Potentially lower hosting costs

All functionality is preserved:
- Azure AD authentication
- Key Vault integration
- Log Analytics auditing
- Device password search

## License

This project maintains the same license as the original CloudLAPS project.

## Credits

- Original C# version: [Nickolaj Andersen](https://github.com/MSEndpointMgr) (MSEndpointMgr.com)
- Log Analytics integration based on: [Tobias Zimmergren's blog](https://zimmergren.net/building-custom-data-collectors-for-azure-log-analytics/)