param dnsZoneName string
param appARecord string
param cdnEndpointName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
}

resource msEndpoint 'Microsoft.Cdn/profiles/endpoints@2022-05-01-preview' existing = {
  name: cdnEndpointName
}


resource aRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: appARecord
  properties: {
    targetResource: {
      id: msEndpoint.id
    }
    TTL: 15
  }
}

resource msSymbolicName 'Microsoft.Cdn/profiles/endpoints/customDomains@2022-11-01-preview' = {
  parent: msEndpoint
  name: appARecord
  properties: {
    hostName: '${appARecord}.${dnsZoneName}'
  }
  dependsOn: [
    aRecord
  ]
}
