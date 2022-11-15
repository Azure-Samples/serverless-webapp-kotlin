param location string = resourceGroup().location

@description('Name of storage account for which sysmtem topic and subscription will be created')
param storageAccountName string

@description('Name of function app where function which will be subscribed is hosted')
param functionApp string

@description('Name of the function which will be subscribed to blob created event')
param functionName string

@description('If you have a dev setup with ngrok, pass the proxy domain, else leave it empty')
param devSubsriptionUrl string

resource functionApplication 'Microsoft.Web/sites@2021-03-01' existing = {
  name: functionApp
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}
resource faceStorageTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: 'faceStorageTopic'
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

var systemKeyBlobExtension = listkeys('${resourceId('Microsoft.Web/sites', functionApplication.name)}/host/default/','2021-02-01').systemkeys.blobs_extension

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = {
  parent: faceStorageTopic
  name: 'fileUploadSubsciption'
  properties: {
    destination: {
      properties: {
        endpointUrl: 'https://${functionApplication.properties.defaultHostName}/runtime/webhooks/blobs?functionName=Host.Functions.${functionName}&code=${systemKeyBlobExtension}'
      }
      endpointType: 'WebHook'
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource eventSubscriptionDev 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = if (!empty(devSubsriptionUrl)) {
  parent: faceStorageTopic
  name: 'fileUploadSubsciptionDev'
  properties: {
    destination: {
      properties: {
        endpointUrl: '${devSubsriptionUrl}/runtime/webhooks/blobs?functionName=Host.Functions.${functionName}'
      }
      endpointType: 'WebHook'
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

