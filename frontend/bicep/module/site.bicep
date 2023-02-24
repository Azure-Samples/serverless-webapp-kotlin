param location string = resourceGroup().location
param storageAccountName string

var jsonServiceTag = loadJsonContent('../resources/ServiceTags_Public_20221031.json')
var ipRulesArray = [for ip in jsonServiceTag.addressPrefixes : {
    value: ip
}]

resource frontEndStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  kind: 'StorageV2'
  location: location
  name: storageAccountName
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
     supportsHttpsTrafficOnly: true
       encryption: {
         services: {
           file: {
             keyType: 'Account'
             enabled: true
           }
           blob: {
             keyType: 'Account'
             enabled: true
           }
         }
         keySource: 'Microsoft.Storage'
       }
       accessTier: 'Hot'
    // networkAcls: {
    //   defaultAction: 'Deny'
    //   ipRules: ipRulesArray
    // }
  }
}

resource deploymentScript 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name:'deployment-script'
  location: location
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, deploymentScript.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab'))
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
    principalId: deploymentScript.properties.principalId
    principalType: 'ServicePrincipal'

  }
}

resource Microsoft_Resources_deploymentScripts_deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentScript'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScript.id}': {
      }
    }
  }
  properties: {
      azPowerShellVersion: '6.1'
      timeout: 'PT30M'
      arguments: '-storageAccount ${frontEndStorageAccount.name} -resourceGroup ${resourceGroup().name}'
      scriptContent: '''
        param([string] $storageAccount, [string] $resourceGroup)
        $storage = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount
        $ctx = $storage.Context
        Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument index.html -ErrorDocument404Path notfound.html
        $output = $storage.PrimaryEndpoints.Web
        $output = $output.TrimEnd('/')
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['URL'] = $output
      '''
      cleanupPreference: 'Always'
      retentionInterval: 'P1D'
    }
}

output staticWebsiteUrl string = frontEndStorageAccount.properties.primaryEndpoints.web
output staticBlobUrl string = frontEndStorageAccount.properties.primaryEndpoints.blob
output storageAccountName string = frontEndStorageAccount.name
