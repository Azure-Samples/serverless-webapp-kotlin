param apimName string
param currentResourceGroup string
param backendApiName string
param apiName string
param originUrl string
param devOriginUrl string

var functionAppKeyName = '${backendApiName}-key'

resource backendApiApp 'Microsoft.Web/sites@2021-01-15' existing = {
  name: backendApiName
  scope: resourceGroup(currentResourceGroup)
}

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: apimName
}

resource namedValues 'Microsoft.ApiManagement/service/namedValues@2021-01-01-preview' = {
  parent: apim
  name: functionAppKeyName
  properties: {
    displayName: functionAppKeyName
    value: listKeys('${backendApiApp.id}/host/default','2019-08-01').functionKeys.default
  }
}

resource backendApi 'Microsoft.ApiManagement/service/backends@2021-01-01-preview' = {
  parent: apim
  name: backendApiName
  properties: {
    description: backendApiName
    resourceId: 'https://${environment().resourceManager}${backendApiApp.id}'
    credentials: {
      header:{
        'x-functions-key': [
          '{{${namedValues.properties.displayName}}}'
        ]
      }
    }
    url: 'https://${backendApiApp.properties.hostNames[0]}/api'
    protocol: 'http'
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2021-01-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    path:apiName
    displayName: apiName
    isCurrent: true
    subscriptionRequired: true
    protocols: [
      'https'
    ]
   subscriptionKeyParameterNames:{
    query:'code'
    header:'X-Api-Key'
   }
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-01-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(replace(loadTextContent('../resources/cos-policy.xml'),'__ORIGIN__',originUrl), '__DEV_ORIGIN__', devOriginUrl)
  }
}

resource opGetUploadUrl 'Microsoft.ApiManagement/service/apis/operations@2021-01-01-preview' = {
  name: 'getUploadUrl'
  parent: api
  properties: {
    displayName: 'Get Upload Url'
    method: 'GET'
    urlTemplate: '/upload-url'
  }
}

resource opGetUploadUrlPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2021-01-01-preview' = {
  parent: opGetUploadUrl
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('../resources/api-policy.xml'),'__BACKEND-ID__', backendApi.name)
  }
}

resource opPostFindFace 'Microsoft.ApiManagement/service/apis/operations@2021-01-01-preview' = {
  name: 'getFindFace'
  parent: api
  properties: {
    displayName: 'Post image to find face'
    method: 'POST'
    urlTemplate: '/find-person'
  }
}

resource opPostFindFacePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2021-01-01-preview' = {
  parent: opPostFindFace
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('../resources/api-policy.xml'),'__BACKEND-ID__', backendApi.name)
  }
}

resource subscriptionKey 'Microsoft.ApiManagement/service/subscriptions@2021-12-01-preview' = {
  name: 'face-app-frontend'
  parent: apim
  properties: {
    allowTracing: true
    displayName: 'face-app-frontend'
    state: 'active'
    scope: '/apis'
  }
}

output uploadURl string = '${apim.properties.gatewayUrl}/${api.name}${opGetUploadUrl.properties.urlTemplate}'
output findPersonUrl string = '${apim.properties.gatewayUrl}/${api.name}${opPostFindFace.properties.urlTemplate}'
