resource pankaagr 'Microsoft.Network/dnsZones@2018-05-01' = {
  location: 'global'
  name: 'pankaagr.cloud'
}

output id string = pankaagr.id
output name string = pankaagr.name
