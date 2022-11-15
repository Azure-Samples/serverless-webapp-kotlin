@description('Specifies the location for resources.')
param location string = 'westeurope'

@description('Do we need to invoke deploy script?')
@allowed( [
  'Yes'
  'No' 
]
)
param siteDeployRequired string

targetScope =  'subscription'

resource staticsite 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name: 'staticwebsite'
}

module site 'site.bicep' = {
  name: 'frontendsite'
  scope: staticsite
  params: {
    location: location
    siteDeployRequired: siteDeployRequired
  }
}

module dnszone 'dnszone.bicep'= {
  scope: staticsite
  name: 'dnszone'
}

module cdn 'cdn.bicep' = {
  name:'frontendcdn'
  scope: staticsite
  params: {
    location: location
    staticWebsiteUrl: site.outputs.staticWebsiteUrl
    dnsZoneName: dnszone.outputs.name
  }
}

module dns 'dns-settings.bicep' = {
  name: 'dns'
  scope: staticsite
  params: {
    dnsZoneName: dnszone.outputs.name
  }
}
