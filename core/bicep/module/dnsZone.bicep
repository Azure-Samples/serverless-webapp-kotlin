param dnsZoneName string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  location: 'global'
  name: dnsZoneName
}

/* resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: 'me'
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: 'pankajagrawal16.github.io'
    }
  }
}
 */
 
output id string = dnsZone.id
output name string = dnsZone.name
