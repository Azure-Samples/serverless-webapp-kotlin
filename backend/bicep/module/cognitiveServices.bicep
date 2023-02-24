@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param cognitiveServiceName string

@description('Location for all resources.')
param location string = resourceGroup().location

param keyVaultName string

@allowed([
  'F0'
])
param sku string = 'F0'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2022-10-01' = {
  name: cognitiveServiceName
  location: location
  sku: {
    tier: 'Free'
    name: sku
  }
  kind: 'Face'
  properties: {
    apiProperties: {
      statisticsEnabled: true
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource appKeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
	name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
    parent: appKeyVault
	name: 'CognitiveServiceKey'
    properties: {
        value: cognitiveService.listKeys().key1
    }
}

