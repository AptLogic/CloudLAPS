# Deployment Guide - Azure App Service

Authentication parity mode for this app:
- Uses Azure App Service Easy Auth for interactive sign-in.
- Does not perform app-managed Azure AD callback/token redemption.

## Prerequisites

- Azure CLI installed: `az --version`
- Logged in to Azure: `az login`
- Azure subscription with appropriate permissions

## Step-by-Step Deployment

### 1. Create Resource Group (if needed)

```bash
RESOURCE_GROUP="rg-cloudlaps"
LOCATION="eastus"

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 2. Create App Service Plan

```bash
APP_SERVICE_PLAN="plan-cloudlaps"

az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --sku B1 \
  --is-linux
```

### 3. Create Web App

```bash
APP_NAME="cloudlaps-portal-node"  # Must be globally unique

az webapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --runtime "NODE:18-lts"
```

### 4. Enable Managed Identity

```bash
az webapp identity assign \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
```

Get the identity's principal ID:
```bash
PRINCIPAL_ID=$(az webapp identity show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId \
  --output tsv)

echo "Principal ID: $PRINCIPAL_ID"
```

### 5. Grant Key Vault Access

```bash
KEY_VAULT_NAME="your-keyvault-name"

az keyvault set-policy \
  --name $KEY_VAULT_NAME \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### 6. Configure Application Settings

```bash
# Key Vault Settings
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    KEY_VAULT_URI="https://$KEY_VAULT_NAME.vault.azure.net"

# Log Analytics Settings
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    LOG_ANALYTICS_WORKSPACE_ID="your-workspace-id" \
    LOG_ANALYTICS_SHARED_KEY="your-shared-key" \
    LOG_ANALYTICS_LOG_TYPE="CloudLAPSAudit"

# Application Settings
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    APP_BASE_URL="https://$APP_NAME.azurewebsites.net" \
    NODE_ENV="production" \
    PORT="8080" \
    TRUST_PROXY="1"
```

### 7. Enable App Service Authentication

Configure App Service Authentication with Microsoft Entra ID and require authentication for all requests.
Ensure the callback URI in the Entra app registration is:
```
https://<your-app-name>.azurewebsites.net/.auth/login/aad/callback
```

### 8. Build and Deploy

```bash
# Build the application
npm run build

# Create deployment package
cd ..
zip -r deploy.zip node-rewrite/ -x "node-rewrite/node_modules/*" "node-rewrite/.env" "node-rewrite/src/*"

# Deploy to Azure
az webapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --src deploy.zip
```

### 9. Configure Startup Command (if needed)

```bash
az webapp config set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --startup-file "npm start"
```

### 10. Enable HTTPS Only

```bash
az webapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --https-only true
```

## Verify Deployment

### Check Application Status
```bash
az webapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query state
```

### View Logs
```bash
az webapp log tail \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
```

### Test the Application
Open browser to: `https://<your-app-name>.azurewebsites.net`

## Alternative Deployment Methods

### GitHub Actions

Create `.github/workflows/azure-deploy.yml`:

```yaml
name: Deploy to Azure App Service

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: node-rewrite/package-lock.json
    
    - name: Install dependencies
      run: |
        cd node-rewrite
        npm ci
    
    - name: Build
      run: |
        cd node-rewrite
        npm run build
    
    - name: Deploy to Azure Web App
      uses: azure/webapps-deploy@v2
      with:
        app-name: ${{ secrets.AZURE_WEBAPP_NAME }}
        publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
        package: ./node-rewrite
```

### Azure DevOps

Create `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
    - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  azureSubscription: 'your-service-connection'
  webAppName: 'cloudlaps-portal-node'
  
steps:
- task: NodeTool@0
  inputs:
    versionSpec: '18.x'
  displayName: 'Install Node.js'

- script: |
    cd node-rewrite
    npm ci
    npm run build
  displayName: 'npm install and build'

- task: AzureWebApp@1
  displayName: 'Deploy to Azure Web App'
  inputs:
    azureSubscription: $(azureSubscription)
    appName: $(webAppName)
    package: $(System.DefaultWorkingDirectory)/node-rewrite
```

### Docker Deployment

Build and deploy as container:

```bash
# Build image
docker build -t cloudlaps-portal:latest ./node-rewrite

# Tag for Azure Container Registry
docker tag cloudlaps-portal:latest <your-acr>.azurecr.io/cloudlaps-portal:latest

# Push to ACR
docker push <your-acr>.azurecr.io/cloudlaps-portal:latest

# Deploy to App Service
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --name $APP_NAME \
  --deployment-container-image-name <your-acr>.azurecr.io/cloudlaps-portal:latest
```

## Monitoring

### Enable Application Insights

```bash
az monitor app-insights component create \
  --app cloudlaps-insights \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP

INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app cloudlaps-insights \
  --resource-group $RESOURCE_GROUP \
  --query instrumentationKey \
  --output tsv)

az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$INSTRUMENTATION_KEY"
```

### Set Up Alerts

```bash
# Alert on HTTP 500 errors
az monitor metrics alert create \
  --name "HTTP 5xx Errors" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/<subscription-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME" \
  --condition "count Http5xx > 10" \
  --window-size 5m \
  --evaluation-frequency 1m
```

## Rollback

If deployment fails, rollback to previous version:

```bash
az webapp deployment slot swap \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --slot staging \
  --action swap
```

Or redeploy previous version from GitHub/Azure DevOps.

## Scaling

### Scale Up (Vertical)
```bash
az appservice plan update \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --sku S1
```

### Scale Out (Horizontal)
```bash
az appservice plan update \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --number-of-workers 3
```

### Auto-scaling
```bash
az monitor autoscale create \
  --resource-group $RESOURCE_GROUP \
  --resource $APP_NAME \
  --resource-type Microsoft.Web/sites \
  --name autoscale-cloudlaps \
  --min-count 1 \
  --max-count 5 \
  --count 1
```

## Troubleshooting

### View Application Logs
```bash
az webapp log download \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --log-file logs.zip
```

### SSH into Container
```bash
az webapp ssh \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
```

### Check Environment Variables
```bash
az webapp config appsettings list \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP
```

## Cost Optimization

- Use B1 (Basic) tier for small deployments (~$13/month)
- Use S1 (Standard) for production with scaling (~$70/month)
- Enable auto-shutdown for development environments
- Consider Azure Front Door for multi-region deployments

## Security Checklist

- [ ] HTTPS only enabled
- [ ] App Service Easy Auth enabled and requires authentication
- [ ] Managed Identity configured
- [ ] Key Vault access granted
- [ ] Application Insights enabled
- [ ] Alerts configured
- [ ] Backup strategy defined
- [ ] Disaster recovery plan documented
