targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param apiContainerAppName string = ''
param apiServiceName string = 'order-processor'
param receiptApiServiceName string = 'receipt'
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param workerContainerAppName string = ''
param workerServiceName string = 'checkout'

@description('Flag to use Azure API Management to mediate the calls between the Web frontend and the backend API')
param useAPIM bool = false

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('The image name for the api service')
param apiImageName string = ''

@description('The image name for the web service')
param workerImageName string = ''

@description('The name of the storage account')
param storageAccountName string = ''

@description('The name of the blob container')
param blobContainerName string = 'orders'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Shared App Env
module appEnv './app/app-env.bicep' = {
  name: '${deployment().name}-app-env'
  scope: rg
  params: {
    containerAppsEnvName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
  }
}

// Worker
module worker './app/worker.bicep' = {
  name: workerServiceName
  scope: rg
  params: {
    name: !empty(workerContainerAppName) ? workerContainerAppName : '${abbrs.appContainerApps}${workerServiceName}-${resourceToken}'
    location: location
    imageName: workerImageName
    containerAppsEnvironmentName: appEnv.outputs.environmentName
    containerRegistryName: appEnv.outputs.registryName
    serviceName: workerServiceName
    managedIdentityName: security.outputs.managedIdentityName
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
  }
}

// API
module api './app/order-processor-api.bicep' = {
  name: apiServiceName
  scope: rg
  params: {
    name: !empty(apiContainerAppName) ? apiContainerAppName : '${abbrs.appContainerApps}${apiServiceName}-${resourceToken}'
    location: location
    imageName: apiImageName
    containerAppsEnvironmentName: appEnv.outputs.environmentName
    containerRegistryName: appEnv.outputs.registryName
    serviceName: apiServiceName
    managedIdentityName: security.outputs.managedIdentityName
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
  }
}

module receiptApi './app/receipt-api.bicep' = {
  name: receiptApiServiceName
  scope: rg
  params: {
    name: !empty(apiContainerAppName) ? apiContainerAppName : '${abbrs.appContainerApps}${receiptApiServiceName}-${resourceToken}'
    containerAppsEnvironmentName: appEnv.outputs.environmentName
    containerRegistryName: appEnv.outputs.registryName
    imageName: apiImageName
    serviceName: receiptApiServiceName
    managedIdentityName: security.outputs.managedIdentityName
    storageAccountName: storageAccount.outputs.name
    containerName: blobContainerName
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
  }
}

// Provision Storage Account
module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    containers: [
      {
        name: blobContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// Setup managed identity
module security './app/security.bicep' = {
  name: 'security'
  scope: rg
  params: {
    managedIdentityName: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output AZURE_CONTAINER_ENVIRONMENT_NAME string = appEnv.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = appEnv.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = appEnv.outputs.registryName
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output SERVICE_RECEIPT_API_NAME string = receiptApi.outputs.SERVICE_API_NAME
output SERVICE_WORKER_NAME string = worker.outputs.SERVICE_WEB_NAME
output USE_APIM bool = useAPIM
output PRINCIPAL_ID string = principalId
output AZURE_MANAGED_IDENTITY_NAME string = security.outputs.managedIdentityName
