@description('The name of the function app that you wish to create.')
param appName string = 'app${uniqueString(resourceGroup().id)}'

param allowedOrigins array

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
])
param runtime string = 'java'

param keyVaultName string

var functionAppName = 'face-serverless-${appName}'
var hostingPlanName = 'plan-${appName}'
var applicationInsightsName = 'face-app-insights'
var functionsStorageName = 'azFunctions${uniqueString(resourceGroup().id)}'
var functionWorkerRuntime = runtime

@description('Cosmo db database name')
param cosmoDatabaseName string

@description('Cosmo db database name')
param cosmoContainerName string

@description('Cosmo db database name')
param dbAccountName string

resource functionStorage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: toLower(functionsStorageName)
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource imageStore 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: toLower('iStore${appName}')
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource imageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: imageStore
  properties: {
    cors: {
      corsRules: [ for origin in allowedOrigins: {

                allowedHeaders: [
                  '*'
                ]
                allowedMethods: [
                  'PUT'
                ]
                allowedOrigins: [
                  origin
                ]
                exposedHeaders: [
                  '*'
                ]
                maxAgeInSeconds: 5
      }]
    }
  }
}

resource imageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${imageStore.name}/default/images'
  properties: {
    publicAccess: 'None'
  }
}

resource deleteLifeCyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2022-05-01' = {
  name: 'default'
  parent: imageStore
  properties: {
    policy: {
      rules:  [
         {
          name: 'deleteImagesOlderThanDays'
          definition: {
            filters: {
             prefixMatch: [
              'images/'
             ]
             blobTypes: [
              'blockBlob'
             ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterCreationGreaterThan: 7
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 7
                }
              }
              version: {
                 delete: {
                  daysAfterCreationGreaterThan: 7
                 }
              }
            }
          }
          type: 'Lifecycle' 
         }
      ] 
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind:'functionapp'
  properties: {
    reserved: true
  }
}

resource faceAppCosmoDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' existing = {
  name: dbAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}


resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id

    siteConfig: {
      ipSecurityRestrictions:  [for (ip, index) in loadJsonContent('../resources/ServiceTags_Public_20221107.json').properties.addressPrefixes: {
          action: 'Allow'
          ipAddress: ip
          priority: index
          description: 'AzureCloud.westeurope IP'
        }]
      localMySqlEnabled: false
      linuxFxVersion:'java|8'
    }
    httpsOnly: true
  }
}

// workaround for https://github.com/Azure/azure-functions-host/issues/8189
module appSettings 'functionAppSettings.bicep' = {
  name: '${functionAppName}-appsettings'
  params: {
    appSettings: {
      // Although we are using identity based auth for blob triggered
      // we are forced to use connection string as deployment plugin is still dependant on this config.
      // we are not using this property anymore for trigger itself.
      // https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference?tabs=blob#connecting-to-host-storage-with-an-identity-preview
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionStorage.listKeys().keys[0].value}'
      AzureWebJobsStorage__accountName: functionStorage.name
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionStorage.listKeys().keys[0].value}'
      WEBSITE_CONTENTSHARE: toLower(functionAppName)
      FUNCTIONS_EXTENSION_VERSION: '~4'
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
      FUNCTIONS_WORKER_RUNTIME: functionWorkerRuntime
      APP_STORAGE_ACCOUNT: imageStore.name
      AZURE_TENANT_ID: subscription().tenantId
      FaceAppDatabaseConnectionString__accountEndpoint: 'https://${faceAppCosmoDbAccount.name}.documents.azure.com:443/'
      KEYVAULT_NAME: keyVaultName 
      // Can be replaced with single prop of service uri as mentioned
      // here https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-trigger?tabs=in-process%2Cextensionv5&pivots=programming-language-java#identity-based-connections
      // once this is fixed https://github.com/Azure/azure-functions-host/issues/8019
      FaceStorage__queueServiceUri:'https://${imageStore.name}.queue.${environment().suffixes.storage}'
      FaceStorage__blobServiceUri:'https://${imageStore.name}.blob.${environment().suffixes.storage}'
      FACE_APP_DATABASE_NAME: cosmoDatabaseName
      FACE_APP_CONTAINER_NAME: cosmoContainerName
    }

    currentAppSettings: list(resourceId('Microsoft.Web/sites/config', functionApp.name, 'appsettings'), '2022-03-01').properties
    functionAppName: functionApp.name
  }
}

resource faceBlobContributor'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'))
  scope: imageStore
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

resource faceBlobOnwer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'))
  scope: imageStore
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  }
}

resource faceQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88'))
  scope: imageStore
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  }
}

resource appStorageQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, functionStorage.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88'))
  scope: functionStorage
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  }
}

resource appStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, functionStorage.id ,subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab'))
  scope: functionStorage
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  }
}

resource appStorageBlobOnwer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, functionStorage.id ,subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'))
  scope: functionStorage
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  }
}

@description('Friendly name for the SQL Role Definition')
param roleDefinitionName string = 'FaceApp Read/Write Role'

@description('Data actions permitted by the Role Definition')
param dataActions array = [
  'Microsoft.DocumentDB/databaseAccounts/readMetadata'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
  'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
]

var roleDefinitionId = guid('sql-role-definition-', faceAppCosmoDbAccount.id)
var roleAssignmentId = guid(roleDefinitionId, faceAppCosmoDbAccount.id)

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2022-08-15' = {
  name: '${faceAppCosmoDbAccount.name}/${roleDefinitionId}'
  properties: {
    roleName: roleDefinitionName
    type: 'CustomRole'
    assignableScopes: [
      faceAppCosmoDbAccount.id
    ]
    permissions: [
      {
        dataActions: dataActions
      }
    ]
  }
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-08-15' = {
  name: '${faceAppCosmoDbAccount.name}/${roleAssignmentId}'
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: functionApp.identity.principalId
    scope: faceAppCosmoDbAccount.id
   }
}

resource appKeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
	name: keyVaultName
}

resource accessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = {
  parent: appKeyVault
  name: 'add'
  properties: {
    accessPolicies:  [
      {
        objectId: functionApp.identity.principalId
        permissions: {
          keys: [
            'list'
          ]
          secrets:  [
            'list'
            'get'
          ]
        }
        tenantId: functionApp.identity.tenantId
      }
    ]
  }
}

output appInsightName string= applicationInsightsName
output appInsightKey string= applicationInsights.properties.InstrumentationKey
output functionAppName string= functionAppName
output imageStorageAccountName string = imageStore.name
