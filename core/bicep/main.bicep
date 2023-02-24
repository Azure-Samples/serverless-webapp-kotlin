@description('Specifies the location for resources.')
param location string

@description('Specifies the name of resource group where all the application resources will be deployed')
param resourceGroup string

@description('Specifies the name of domain name to be delegated to Azure DNS')
param dnsZoneName string

targetScope =  'subscription'

resource websiteRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name: resourceGroup
}

module dnsZone 'module/dnsZone.bicep' = if(dnsZoneName != '') {
	scope: websiteRg
	name : 'dnsZone'
	params: {
		dnsZoneName: dnsZoneName
	}
}

