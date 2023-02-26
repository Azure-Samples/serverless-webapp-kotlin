param location string = resourceGroup().location
param staticWebsiteUrl string = ''


var storageAccountHostName = replace(replace(staticWebsiteUrl, 'https://', ''), '/', '')

var profileName  = 'cdn-${uniqueString(resourceGroup().id)}'
var endpointName = 'endpoint-${uniqueString(resourceGroup().id)}'

resource msCdn 'Microsoft.Cdn/profiles@2022-05-01-preview' = {
  name: 'ms-${profileName}'
  location: location
  tags: {
    displayName: 'ms-${profileName}'
  }
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource msEndpoint 'Microsoft.Cdn/profiles/endpoints@2022-05-01-preview' = {
  parent: msCdn
  name: 'ms-${endpointName}'
  location: location
  tags: {
    displayName: 'ms-${endpointName}'
  }
  properties: {
    originHostHeader: storageAccountHostName
    isHttpAllowed: true
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/x-javascript'
      'text/javascript'
    ]
    isCompressionEnabled: true
    origins: [
      {
        name: replace(storageAccountHostName,'.','-')
        properties: {
          hostName: storageAccountHostName
        }
      }
    ]
    deliveryPolicy: {
      rules:  [
       {
        actions: [
          {
            name: 'UrlRedirect'
            parameters: {
              redirectType: 'Found'
              typeName: 'DeliveryRuleUrlRedirectActionParameters'
              destinationProtocol:'Https'
            }
          }
        ]
        conditions:[
          {
            name: 'RequestScheme'
            parameters: {
              operator: 'Equal'
              typeName: 'DeliveryRuleRequestSchemeConditionParameters'
              matchValues: [
                'HTTP'
              ]
              negateCondition:false
            }
          }
        ]
        order: 1
        name: 'redirect'
       } 
       {
        actions: [
          {
            name:  'UrlRewrite'
            parameters: {
              typeName: 'DeliveryRuleUrlRewriteActionParameters'
              destination: '/index.html'
              sourcePattern: '/'
              preserveUnmatchedPath: false
            }
          }
        ]
        conditions:[
          {
            name: 'UrlFileExtension'
            parameters: {
              operator: 'LessThan'
              typeName: 'DeliveryRuleUrlFileExtensionMatchConditionParameters'
              matchValues: [
                '1'
              ]
              negateCondition:false
            }
          }
        ]
        order: 2
        name: 'rewritespa'
       } 
      ]
    }
  }
}

output hostName string = msEndpoint.properties.hostName
output msEndpointName string = '${msCdn.name}/${msEndpoint.name}'
output msCdnName string = msCdn.name
output originHostHeader string = msEndpoint.properties.originHostHeader
