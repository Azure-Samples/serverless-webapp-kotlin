@description('Specifies the location for resources.')
param location string = resourceGroup().location
@description('Frontend application origin host. Its needed to set proper CORS policies')
param originHostForFrontend string
@description('Do you want to create new APIM? Switch off after initial deploy of custom domain')
param createApim bool

var frontEndSiteOrigin = 'https://${originHostForFrontend}'
var allowedOrigins = [
'http://localhost:3000', 'https://localhost:3000', frontEndSiteOrigin
]
var appName = 'webapp-${uniqueString(resourceGroup().id)}'

module keyVault 'module/keyVault.bicep' = {
  name: 'key-vault'
  params: {
    location: location
    keyVaultName: 'webapp-kv-${uniqueString(resourceGroup().id)}'
  }
}

module cognitiveService 'module/cognitiveServices.bicep' = {
	name:'cognitive-services'
	params: {
	    location: location
	    keyVaultName: keyVault.outputs.vaultName
	    cognitiveServiceName: 'webapp-${uniqueString(resourceGroup().id)}'
	}
}

module appCosmoDb 'module/database.bicep' = {
	name: 'db-${appName}'
	params: {
        location: location
        accountName: 'db-${appName}'
        containerName: 'faceapp'
        databaseName:'faces'
	}
}

module functionBackend 'module/functionBackend.bicep' = {
	name: 'function-backend-${appName}'
	params: {
    location: location
    dbAccountName: 'db-${appName}'
		cosmoContainerName: 'faceapp'
		cosmoDatabaseName : 'faces'
		allowedOrigins: allowedOrigins
    keyVaultName: keyVault.outputs.vaultName
	} 
  dependsOn: [
    appCosmoDb
  ]
}

param resourceTags object = {
  ProjectType: 'FaceApp'
  Purpose: 'Demo'
}

var apiManagementName = 'face-app-api-${uniqueString(resourceGroup().id)}'

module apim 'module/apim.bicep'= if(createApim) {
  name: 'apim'
  params: {
    location: location
    apimName: apiManagementName
    appInsightsName: functionBackend.outputs.appInsightName
    appInsightsInstrumentationKey: functionBackend.outputs.appInsightKey
    sku: 'Consumption'
    skuCount:0
    resourceTags: resourceTags
  } 
  dependsOn: [
    functionBackend
  ]
} 

module apimAPI 'module/apimAPI.bicep'= {
  name: 'apimAPI'
  params: {
    apiName:'face'
    originUrl:frontEndSiteOrigin
    devOriginUrl: 'http://localhost:3000'
    apimName: apiManagementName
    backendApiName: functionBackend.outputs.functionAppName
    currentResourceGroup: resourceGroup().name
  }
  dependsOn: [
    apim
  ]
}

output uploadURl string = apimAPI.outputs.uploadURl
output findPersonUrl string = apimAPI.outputs.findPersonUrl
output imageStorageAccountName string = functionBackend.outputs.imageStorageAccountName
output functionAppName string = functionBackend.outputs.functionAppName
output apiManagementName string = apiManagementName
output kvName string = keyVault.outputs.vaultName
output dbAccountName string = appCosmoDb.outputs.accountName
