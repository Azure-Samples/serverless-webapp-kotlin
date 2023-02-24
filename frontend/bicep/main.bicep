@description('Suffix for naming resources')
param appNameSuffix string = 'app${uniqueString(resourceGroup().id)}'
@description('Specifies the location for resources.')
param location string = resourceGroup().location
@description('Specifies the name of domain name to be delegated to Azure DNS')
param dnsZoneName string

targetScope =  'resourceGroup'

var customDomainSetupNeeded = !empty(dnsZoneName)
var storageAccountName = 'frontend${appNameSuffix}'

module siteSetup 'module/site.bicep' = {
  name: 'siteSetup-${appNameSuffix}'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

module cdn 'module/cdn.bicep' = {
  name:'frontendCdn-${appNameSuffix}'
  params: {
    location: location
    staticWebsiteUrl: siteSetup.outputs.staticWebsiteUrl
  }
}

module cdnCustomDomin 'module/cdnCustomDomain.bicep' = if(customDomainSetupNeeded) {
  name: 'cdnCustomDomain-${appNameSuffix}'
  params: {
    appARecord: 'app'
    cdnEndpointName: cdn.outputs.msEndpointName
    dnsZoneName: dnsZoneName
  }
}

output storageAccountNameForFrontEndArtifacts string = siteSetup.outputs.storageAccountName
output cdnEndpointHostName string = customDomainSetupNeeded ? 'app.${dnsZoneName}' : cdn.outputs.hostName

