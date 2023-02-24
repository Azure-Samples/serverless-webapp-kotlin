param dnsZoneName string
param appARecord string
param cdnEndpointName string
param msCdnName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
}

resource msEndpoint 'Microsoft.Cdn/profiles/endpoints@2022-05-01-preview' existing = {
  name: cdnEndpointName
}

resource msCdn 'Microsoft.Cdn/profiles@2022-11-01-preview' existing = {
  name: msCdnName
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

resource msSymbolicName 'Microsoft.Cdn/profiles/customDomains@2022-11-01-preview' = {
  parent: msCdn
  name: appARecord
  properties: {
    hostName: '${appARecord}.${dnsZoneName}'
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
  dependsOn: [
    aRecord
  ]
}
