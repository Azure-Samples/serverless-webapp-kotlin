param currentAppSettings object
param  appSettings object
param  functionAppName string


resource siteconfig 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${functionAppName}/appsettings'
  properties: union(currentAppSettings, appSettings)
}
