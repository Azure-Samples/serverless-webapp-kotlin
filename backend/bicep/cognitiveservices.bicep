@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param cognitiveServiceName string = 'FaceApp-${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'F0'
])
param sku string = 'F0'

@description('Object ID of the AAD identity. Must be a GUID.')
param principalId string

@description('Data actions permitted by the Role Definition')
param dataActions array = [
  'Microsoft.CognitiveServices/accounts/Face/facelists/persistedfaces/write'
  'Microsoft.CognitiveServices/accounts/Face/persongroups/write'
  'Microsoft.CognitiveServices/accounts/Face/detect/action'
  'Microsoft.CognitiveServices/accounts/Face/findsimilars/action'
  'Microsoft.CognitiveServices/accounts/Face/group/action'
  'Microsoft.CognitiveServices/accounts/Face/identify/action'
  'Microsoft.CognitiveServices/accounts/Face/verify/action'
  'Microsoft.CognitiveServices/accounts/Face/compare/action'
  'Microsoft.CognitiveServices/accounts/Face/facelists/write'
  'Microsoft.CognitiveServices/accounts/Face/persongroups/train/action'
  'Microsoft.CognitiveServices/accounts/Face/persongroups/persons/action'
]

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

resource dataActionsRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, string(dataActions))
  properties: {
    roleName: 'Face Api data actions'
    description: 'Data action role to access cognitive face service apis'
    type: 'CustomRole'
    permissions: [
      {
        dataActions: dataActions
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource functionAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, cognitiveService.id ,dataActionsRole.id)
  scope: cognitiveService
  properties: {
    principalId: principalId
    roleDefinitionId: dataActionsRole.id
  }
}

module keyVault 'kevault.bicep' = {
  name: 'keyVault'
  params: {
    location: location
    keyVaultName: 'FaceAppKv-${uniqueString(resourceGroup().id)}'
    objectId: principalId
    secretName: 'CognitiveServiceKey'
    secretValue: cognitiveService.listKeys().key1
  }
}
