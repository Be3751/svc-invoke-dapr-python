param containerAppsEnvName string
param containerRegistryName string
param location string
param logAnalyticsWorkspaceName string
param applicationInsightsName string

// Container apps host (including container registry)
module containerApps '../core/host/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    name: 'app'
    containerAppsEnvironmentName: containerAppsEnvName
    containerRegistryName: containerRegistryName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
  }
}

output environmentName string = containerApps.outputs.environmentName
output registryLoginServer string = containerApps.outputs.registryLoginServer
output registryName string = containerApps.outputs.registryName
