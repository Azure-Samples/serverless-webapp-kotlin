@description('Name of the dns zone if present')
param dnsZoneName string

@description('Name of the api on which custom domain has to be configured')
param apimName string

@description('TXT hash of the managed cert. This needs to be fetched from the azure portal')
param txtHash string

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: apimName
}

// Managed preview certificate is used to create custom domain via click
resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = if(dnsZoneName != ''){
  name: dnsZoneName
}

resource apiCname 'Microsoft.Network/dnsZones/CNAME@2018-05-01'= if(dnsZoneName != '') {
  name: 'api'
  parent: dnsZone
  properties: {
    TTL: 15
    CNAMERecord: {
      cname: '${apim.name}.azure-api.net'
    }
  }
}

resource apiTxt 'Microsoft.Network/dnsZones/TXT@2018-05-01'= if(dnsZoneName != '') {
  name: 'apimuid.api'
  parent: dnsZone
  properties: {
    TTL: 15
    TXTRecords: [
      {
        value: [
          txtHash
        ]
      }
    ]
}
}