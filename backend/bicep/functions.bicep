@description('The name of the function app that you wish to create.')
param appName string = 'faceRecogApp'

@description('Do you want to create new APIM?')
param createApim bool

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Location for Application Insights')
param appInsightsLocation string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
])
param runtime string = 'java'

// For until https://github.com/Azure/azure-functions-host/issues/8189
@allowed([
  'new'
  'existing'
])
param newOrExisting string

var functionAppName = appName
var hostingPlanName = appName
var applicationInsightsName = appName
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'
var functionWorkerRuntime = runtime

@description('Cosmo db database name')
param cosmoDatabaseName string = 'faceapp'

@description('Cosmo db database name')
param cosmoContainerName string = 'faces'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource face 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: toLower('${appName}Store')
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource faceblobservice 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: face
  properties: {
    cors: {
      corsRules: [
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'PUT'
          ]
          allowedOrigins: [
            'http://localhost:3000'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 5
        }
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'PUT'
          ]
          allowedOrigins: [
            'https://localhost:3000'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 5
        }
        {
          allowedHeaders: [
            '*'
          ]
          allowedMethods: [
            'PUT'
          ]
          allowedOrigins: [
            'https://*.pankaagr.cloud'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 5
        }
      ]
    }
  }
}

resource imageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${face.name}/default/images'
  properties: {
    publicAccess: 'None'
  }
}

resource deleteLifeCyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2022-05-01' = {
  name: 'default'
  parent: face
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
  name: 'faceapp-${uniqueString(resourceGroup().id)}'
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = if (newOrExisting == 'new') {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    
    siteConfig: {
      ipSecurityRestrictions:  [for (ip, index) in loadJsonContent('ServiceTags_Public_20221107.json').properties.addressPrefixes: {
          action: 'Allow'
          ipAddress: ip
          priority: index
          description: 'AzureCloud.westeurope IP'
        }]
      localMySqlEnabled: false
      linuxFxVersion:'java|8'
      appSettings: [
        // Although we are using identity based auth for blob triggered
        // we are forced to use connection string as deployment plugin is still dependant on this config.
        // we are not using this property anymore for trigger itself.
        // https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference?tabs=blob#connecting-to-host-storage-with-an-identity-preview
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'APP_STORAGE_ACCOUNT'
          value: face.name
        }
        {
          name: 'AZURE_TENANT_ID'
          value: subscription().tenantId
        }
        // {
        //   name: 'FaceAppDatabaseConnectionString'
        //   value: faceAppCosmoDbAccount.listConnectionStrings().connectionStrings[0].connectionString
        // }
        {
          name: 'FaceAppDatabaseConnectionString__accountEndpoint'
          value: 'https://${faceAppCosmoDbAccount.name}.documents.azure.com:443/'
        }
        {
          name: 'KEYVAULT_NAME'
          value: 'FaceAppKv-${uniqueString(resourceGroup().id)}'
        }
        // Using temp property until latest version is released to maven central https://github.com/Azure/azure-functions-java-library/issues/190
        {
          name:'FUNCTIONS_EXTENSIONBUNDLE_SOURCE_URI'
          value:'https://functionscdnstaging.azureedge.net/public'
        }
        // Can be replaced with single prop of service uri as mentioned
        // here https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-trigger?tabs=in-process%2Cextensionv5&pivots=programming-language-java#identity-based-connections
        // once this is fixed https://github.com/Azure/azure-functions-host/issues/8019
        {
          name:'FaceStorage__queueServiceUri'
          value:'https://${face.name}.queue.${environment().suffixes.storage}'
        }
        {
          name:'FaceStorage__blobServiceUri'
          value:'https://${face.name}.blob.${environment().suffixes.storage}'
        }
        {
          name: 'FACE_APP_DATABASE_NAME'
          value: cosmoDatabaseName
        }
        {
          name: 'FACE_APP_CONTAINER_NAME'
          value: cosmoContainerName
        }
      ]
    }
    httpsOnly: true
  }
}

resource faceBlobContributor'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'))
  scope: face
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

resource faceBlobOnwer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'))
  scope: face
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  }
}

resource faceQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88'))
  scope: face
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  }
}

resource appStorageQueueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, storageAccount.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88'))
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  }
}

resource appStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, storageAccount.id ,subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab'))
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  }
}

resource appStorageBlobOnwer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, functionApp.id, storageAccount.id ,subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'))
  scope: storageAccount
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

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

param resourceTags object = {
  ProjectType: 'FaceApp'
  Purpose: 'Demo'
}

module apim 'apim.bicep' = if (createApim) {
  name: 'apim'
  params: {
    location: location
    apimName: 'face-api-${uniqueString(resourceGroup().id)}'
    appInsightsName: applicationInsights.name
    appInsightsInstrumentationKey: applicationInsights.properties.InstrumentationKey
    sku: 'Consumption'
    skuCount:0
    resourceTags: resourceTags
  }
}

module apimAPI 'apimAPI.bicep' = {
  name: 'apimAPI'
  params: {
    apiName:'face'
    originUrl:'https://app.pankaagr.cloud'
    devOriginUrl: 'http://localhost:3000'
    apimName: 'face-api-${uniqueString(resourceGroup().id)}'
    backendApiName: functionApp.name
    currentResourceGroup: resourceGroup().name
  }
}

output storageAccountName string = face.name
output functionApplicationName string = functionApp.name
output systemAssignedManagedIdentityId string = functionApp.identity.principalId
