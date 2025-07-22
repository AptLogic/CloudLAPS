// Define parameters
@description('Provide a unique name for the CloudLAPS Application. This will be used to name select other resources.')
param ApplicationName string
@description('Provide the unique ID for the CloudLAPS App Registration.')
param AppRegistrationId string
@description('Provide a name for the Function App that consists of alphanumerics. Name must be globally unique in Azure and cannot start or end with a hyphen.')
param FunctionAppName string
@description('Provide a name for the portal website that consists of alphanumerics. Name must be globally unique in Azure and cannot start or end with a hyphen.')
param PortalWebAppName string
@allowed([
  'B1'
  'P1V2'
  'P1V3'
  'P2V2'
  'P2V3'
  'P3V2'
  'P3V3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
])
@description('Select the desired App Service Plan for the system. Select B1, SKU for minimum cost. Recommended SKU for optimal performance and cost is S1.')
param AppServicePlanSKU string = 'S1'
@description('Provide any tags required by your organization (optional)')
param Tags object = {}

// Define variables
var KeyVaultName = '${toLower(ApplicationName)}-kv'
var LogAnalyticsWorkspaceName = '${toLower(ApplicationName)}-law'
var FunctionAppNameNoDash = replace(FunctionAppName, '-', '')
var FunctionAppNameNoDashUnderScore = replace(FunctionAppNameNoDash, '_', '')
var PortalWebAppNameNoDash = replace(PortalWebAppName, '-', '')
var StorageAccountName = toLower('${take(FunctionAppNameNoDashUnderScore, 17)}sa')
var AppServicePlanName = '${ApplicationName}-plan'
var FunctionAppInsightsName = '${ApplicationName}-fa-ai'
var PortalAppInsightsName = '${ApplicationName}-wa-ai'
var KeyVaultAppSettingsName = '${take(KeyVaultName, 21)}-as'
var VirtualNetworkName string = '${FunctionAppName}-vnet'

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: VirtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'sn0'
        properties: {
          addressPrefix: '10.0.0.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                resourceGroup().location
              ]
            }
            {
              service: 'Microsoft.KeyVault'
              locations: [
                resourceGroup().location
              ]
            }
            {
              service: 'Microsoft.Web'
              locations: [
                resourceGroup().location
              ]
            }
          ]
          delegations: [
            {
              name: 'Microsoft.Web/ServerFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource StorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: StorageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
  }
  tags: Tags
}

resource AppServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: AppServicePlanName
  location: resourceGroup().location
  sku: {
    name: AppServicePlanSKU
  }
  kind: 'Windows'
  properties: {}
  tags: Tags
}

// Create application insights for Function App
resource FunctionAppInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: FunctionAppInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
  tags: union(Tags, {
    'hidden-link:${resourceId('Microsoft.Web/sites', FunctionAppInsightsName)}': 'Resource'
  })
}

resource FunctionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: FunctionAppName
  location: resourceGroup().location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: AppServicePlan.id
    containerSize: 1536
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      alwaysOn: true
      minTlsVersion: '1.2'
      powerShellVersion: '~7.4'
      scmType: 'None'
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('CloudLAPS')
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'AzureWebJobsDisableHomepage'
          value: 'true'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_PROCESS_COUNT'
          value: '3'
        }
        {
          name: 'PSWorkerInProcConcurrencyUpperBound'
          value: '10'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: FunctionAppInsightsComponents.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: FunctionAppInsightsComponents.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
      ]
    }
  }
}

resource PortalApp 'Microsoft.Web/sites@2024-04-01' = {
  name: PortalWebAppNameNoDash
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'app'
  properties: {
    serverFarmId: AppServicePlan.id
    siteConfig: {
      alwaysOn: true
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnetcore'
        }
      ]
    }
  }
}

// Create application insights for CloudLAPS portal
resource PortalAppInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: PortalAppInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
  tags: union(Tags, {
    'hidden-link:${resourceId('Microsoft.Web/sites', PortalWebAppName)}': 'Resource'
  })
}

// Create Key Vault for local admin passwords
resource KeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: KeyVaultName
  location: resourceGroup().location
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: FunctionApp.identity.tenantId
        objectId: FunctionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'set'
          ]
        }
      }
      {
        tenantId: PortalApp.identity.tenantId
        objectId: PortalApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks/subnets', VirtualNetworkName, 'sn0')
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

// Create Key Vault for Function App application settings
resource KeyVaultAppSettings 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: KeyVaultAppSettingsName
  location: resourceGroup().location
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: FunctionApp.identity.tenantId
        objectId: FunctionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: PortalApp.identity.tenantId
        objectId: PortalApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks/subnets', VirtualNetworkName, 'sn0')
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

// Collect Log Analytics workspace properties to be added to Key Vault as secrets
var LogAnalyticsWorkspaceId = LogAnalyticsWorkspace.properties.customerId
var LogAnalyticsWorkspaceSharedKey = LogAnalyticsWorkspace.listKeys().primarySharedKey

// Construct secrets in Key Vault
resource WorkspaceIdSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: KeyVaultAppSettings
  name: 'LogAnalyticsWorkspaceId'
  properties: {
    value: LogAnalyticsWorkspaceId
  }
  dependsOn: [
    KeyVaultAppSettings
  ]
}
resource SharedKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: KeyVaultAppSettings
  name: 'LogAnalyticsWorkspaceSharedKey'
  properties: {
    value: LogAnalyticsWorkspaceSharedKey
  }
  dependsOn: [
    KeyVaultAppSettings
  ]
}

// Deploy application settings for CloudLAPS Function App
resource FunctionAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: FunctionApp
  name: 'appsettings'
  properties: {
    AzureWebJobsDashboard: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value}'
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${StorageAccount.listKeys().keys[0].value}'
    WEBSITE_CONTENTSHARE: toLower('CloudLAPS')
    WEBSITE_RUN_FROM_PACKAGE: '1'
    AzureWebJobsDisableHomepage: 'true'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_PROCESS_COUNT: '3'
    PSWorkerInProcConcurrencyUpperBound: '10'
    APPINSIGHTS_INSTRUMENTATIONKEY: FunctionAppInsightsComponents.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: FunctionAppInsightsComponents.properties.ConnectionString
    FUNCTIONS_WORKER_RUNTIME: 'powershell'
    UpdateFrequencyDays: '3'
    KeyVaultName: KeyVaultName
    DebugLogging: 'False'
    PasswordLength: '16'
    PasswordAllowedCharacters: 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz.:;,-_!?$%*=+&<>@#()23456789'
    LogAnalyticsWorkspaceId: '@Microsoft.KeyVault(VaultName=${KeyVaultAppSettingsName};SecretName=LogAnalyticsWorkspaceId)'
    LogAnalyticsWorkspaceSharedKey: '@Microsoft.KeyVault(VaultName=${KeyVaultAppSettingsName};SecretName=LogAnalyticsWorkspaceSharedKey)'
    LogTypeClient: 'CloudLAPSClient'
  }
  dependsOn: [
    FunctionAppZipDeploy
  ]
}

// Deploy application settings for CloudLAPS Portal
resource PortalAppServiceAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: PortalApp
  name: 'appsettings'
  properties: {
      AzureWebJobsSecretStorageKeyVaultName: KeyVault.name
      APPLICATIONINSIGHTS_CONNECTION_STRING: PortalAppInsightsComponents.properties.ConnectionString
      APPINSIGHTS_INSTRUMENTATIONKEY: PortalAppInsightsComponents.properties.InstrumentationKey
      AzureAd__TenantId: subscription().tenantId
      AzureAd__ClientId: AppRegistrationId
      KeyVault__Uri: KeyVault.properties.vaultUri
      LogAnalytics__WorkspaceId: '@Microsoft.KeyVault(VaultName=${KeyVaultAppSettingsName};SecretName=LogAnalyticsWorkspaceId)'
      LogAnalytics__SharedKey: '@Microsoft.KeyVault(VaultName=${KeyVaultAppSettingsName};SecretName=LogAnalyticsWorkspaceSharedKey)'
      LogAnalytics__LogType: 'CloudLAPSAudit'
  }
  dependsOn: [
    PortalZipDeploy
  ]
}

// Add ZipDeploy for Function App
resource FunctionAppZipDeploy 'Microsoft.Web/sites/extensions@2024-11-01' = {
    parent: FunctionApp
    name: 'ZipDeploy'
    properties: {
        packageUri: 'https://github.com/AptLogic/CloudLAPS/releases/download/v1.3.0/CloudLAPS-FunctionApp1.3.0.zip'
    }
}

// Add ZipDeploy for CloudLAPS Portal
resource PortalZipDeploy 'Microsoft.Web/sites/extensions@2024-11-01' = {
  parent: PortalApp
  name: 'ZipDeploy'
  properties: {
      packageUri: 'https://github.com/AptLogic/CloudLAPS/releases/download/v1.3.0/CloudLAPS-Portal1.1.0.zip'
  }
  dependsOn: [
    FunctionAppZipDeploy
  ]
}

// Create Log Analytics workspace
resource LogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: LogAnalyticsWorkspaceName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}
