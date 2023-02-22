@description('Suffix for naming resources')
param appNameSuffix string = 'app${uniqueString(resourceGroup().id)}'

@description('Specifies the location for resources.')
param location string = resourceGroup().location

@description('Do we need to invoke deploy script?')
@allowed( [
  'Yes'
  'No'
]
)
param siteDeployRequired string

@description('Specifies the name of domain name to be delegated to Azure DNS')
param dnsZoneName string
var customDomainSetupNeeded = !empty(dnsZoneName)

targetScope =  'resourceGroup'

var storageAccountName = 'frontend${appNameSuffix}'

module siteSetup 'module/site.bicep' = {
  name: 'siteSetup-${appNameSuffix}'
  params: {
    location: location
    siteDeployRequired: siteDeployRequired
    storageAccountName: storageAccountName
  }
}

module cdn 'module/cdn.bicep' = {
  name:'frontendCdn${appNameSuffix}'
  params: {
    location: location
    staticWebsiteUrl: siteSetup.outputs.staticWebsiteUrl
  }
}

module cdnCustomDomin 'module/cdnCustomDomain.bicep' = if(customDomainSetupNeeded) {
  name: 'cdnCustomDomin'
  params: {
    appARecord: 'app'
    cdnEndpointName: cdn.outputs.msEndpointName
    dnsZoneName: dnsZoneName
  }
}

output storageAccountNameForFrontEndArtifacts string = siteSetup.outputs.storageAccountName
