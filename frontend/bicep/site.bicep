param location string = resourceGroup().location
param siteDeployRequired string

var jsonServiceTag = loadJsonContent('ServiceTags_Public_20221031.json')

var ipRulesArray = [for ip in jsonServiceTag.addressPrefixes : {
    value: ip
}]

resource siteaccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  kind: 'StorageV2'
  location: location
  name: 'facerecogwebsite'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    // networkAcls: {
    //   defaultAction: 'Deny'
    //   ipRules: ipRulesArray
    // }
  }
}

resource deploymentscript 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name:'website-depoymentscript'
  location: location
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id, deploymentscript.id, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab'))
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
    principalId: deploymentscript.properties.principalId
    principalType: 'ServicePrincipal'

  }
}

resource Microsoft_Resources_deploymentScripts_deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if(siteDeployRequired == 'Yes') {
  name: 'deploymentScript'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentscript.id}': {
      }
    }
  }
  properties: {
    azPowerShellVersion: '3.0'
    scriptContent: '$ErrorActionPreference = \'Stop\'\n$storageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResourceGroupName -AccountName $env:StorageAccountName\n\n# Enable the static website feature on the storage account.\n$ctx = $storageAccount.Context\nEnable-AzStorageStaticWebsite -Context $ctx -IndexDocument $env:IndexDocumentPath -ErrorDocument404Path $env:ErrorDocument404Path\n\n# Add the two HTML pages.\n$tempIndexFile = New-TemporaryFile\nSet-Content $tempIndexFile $env:IndexDocumentContents -Force\nSet-AzStorageBlobContent -Context $ctx -Container \'$web\' -File $tempIndexFile -Blob $env:IndexDocumentPath -Properties @{\'ContentType\' = \'text/html\'} -Force\n\n$tempErrorDocument404File = New-TemporaryFile\nSet-Content $tempErrorDocument404File $env:ErrorDocument404Contents -Force\nSet-AzStorageBlobContent -Context $ctx -Container \'$web\' -File $tempErrorDocument404File -Blob $env:ErrorDocument404Path -Properties @{\'ContentType\' = \'text/html\'} -Force\n'
    retentionInterval: 'PT4H'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'StorageAccountName'
        value: siteaccount.name
      }
      {
        name: 'IndexDocumentPath'
        value: 'index.html'
      }
      {
        name: 'IndexDocumentContents'
        value: '<h1>Example static website</h1>'
      }
      {
        name: 'ErrorDocument404Path'
        value: 'error.html'
      }
      {
        name: 'ErrorDocument404Contents'
        value: '<h1>Example 404 error page</h1>'
      }
    ]
  }
}

output staticWebsiteUrl string = siteaccount.properties.primaryEndpoints.web
output staticBlobUrl string = siteaccount.properties.primaryEndpoints.blob
