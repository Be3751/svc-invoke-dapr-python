param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string = ''
param containerName string = 'main'
param containerRegistryName string = ''
param env array = []
param imageName string
param keyVaultName string = ''
param managedIdentityEnabled bool = !empty(keyVaultName)
param managedIdentityName string = ''

@description('CPU cores allocated to a single container instance, e.g. 0.5')
param containerCpuCoreCount string = '0.5'

@description('Memory allocated to a single container instance, e.g. 1Gi')
param containerMemory string = '1.0Gi'

resource app 'Microsoft.App/containerApps@2022-03-01' = {
  name: name
  location: location
  tags: tags
  identity: managedIdentityEnabled ? {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}' : {}
    }
  } : { type: 'None' }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'single'
      ingress: containerAppsEnvironmentName != '' ? {
        external: false
      } : null
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          image: imageName
          name: containerName
          env: env
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: containerAppsEnvironmentName
}

// 2022-02-01-preview needed for anonymousPullEnabled
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryName
}

// user assigned managed identity to use throughout
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: managedIdentityName
}

output identityPrincipalId string = managedIdentityEnabled ? app.identity.principalId : ''
output imageName string = imageName
output name string = app.name
