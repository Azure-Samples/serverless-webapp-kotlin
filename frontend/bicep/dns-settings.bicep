param cnameRecordName string = 'me'
param dnsZoneName string = ''

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
}

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: cnameRecordName
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: 'pankajagrawal16.github.io'
    }
  }
}
