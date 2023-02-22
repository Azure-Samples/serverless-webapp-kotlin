# Project Name


- By default running in westeurope
- az deployment sub create --confirm-with-what-if --template-file core/bicep/main.bicep --location westeurope --name serverless-webapp-core --parameters core/bicep/main.parameters.json. Validate changes and confirm

-- if dns confirgured, update registrar

- Register azure cdn with subcription https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-register-resource-provider?tabs=azure-cli
- az provider register --namespace Microsoft.Cdn
- - az  deployment group create --confirm-with-what-if --template-file frontend/bicep/main.bicep  --name serverless-webapp-frontend -g <serverless-webapp-rg> --parameters frontend/bicep/main.parameters.json
  
- 
- if custom domin, enable cert cdn managed
- deåploy fronedn 
-   az storage account list --resource-group serverless-webapp -o table
- npm ci --legacy-peer-deps
- npm run build --if-present
- cd build ; az storage blob upload-batch --account-name  <<facerecogwebsite>> --auth-mode key -d '$web' -s . --overwrite

-- check if frontend is up and running now

Update parametes with hostnames etc

- az deployment group create --confirm-with-what-if --template-file backend/bicep/main.bicep  --name serverless-webapp-backend -g serverless-webapp-rg --parameters backend/bicep/main.parameters.json

if dns present then only

-  az deployment group create  --confirm-with-what-if --template-file backend/bicep/apimManagedCert.bicep  --name serverless-webapp-backend-apim-cert -g serverless-webapp-rg --parameters backend/bicep/apimManagedCert.parameters.json only if custom domain present and need on apim
- manually add the managed preview cert in the api azure portal

- mvn clean install -DappName=<<face-serverless-app4fxugbh6ecnak>>
- mvn azure-functions:deploy -DresourceGroup=<<serverless-webapp-rg>> -DappName=<<face-serverless-app4fxugbh6ecnak>> -DenableDebug
deploy the app .. update pom with region rg information.

-- Configure event subscription 
Add image storage account name and also
az deployment group create --confirm-with-what-if --template-file backend/bicep/eventSubscription.bicep  --name serverless-webapp-backend -g <<serverless-webapp-g>>

-- update url in the frontend app Global Constants
az storage blob upload-batch --account-name  <<facerecogwebsite>> --auth-mode key -d '$web' -s . --overwrite



## local

- running app locally fetch setting.. cd backend/faceApp ; func azure functionapp fetch-app-settings face-serverless-app --output-file local.settings.json
- mvn clean install -DappName=face-serverless-app3srt4jk7qqmgu; mvn azure-functions:run -DresourceGroup= <<serverless-webapp-rg>> -DappName=<<face-serverless-app4fxugbh6ecnak>> 
- https://learn.microsoft.com/en-us/azure/azure-functions/functions-event-grid-blob-trigger?pivots=programming-language-java#run-ngrok




the use logged in to azfunction storage account
ad signed-in-user show


role assignment create --role 'Storage Queue Data Contributor' --assignee-object-id e768e9d8-a222-4963-b79b-55e8ed141fd8 -g serverless-app-rg
role assignment create --role 'Storage Blob Data Owner' --assignee-object-id e768e9d8-a222-4963-b79b-55e8ed141fd8 -g serverless-app-rg
role assignment create --role 'Storage Account Contributor' --assignee-object-id e768e9d8-a222-4963-b79b-55e8ed141fd8 -g serverless-app-rg


keyvault  set-policy --secret-permissions all -g serverless-webapp-rg --name webapp-kv-epvgdpar24kmu --object-id e768e9d8-a222-4963-b79b-55e8ed141fd8
cosmosdb sql role definition list -g serverless-webapp-rg -a db-webapp-epvgdpar24kmu

cosmosdb sql role assignment create --principal-id e768e9d8-a222-4963-b79b-55e8ed141fd8 --role-definition-id 37b441dd-4cf2-5730-9160-c4b145b23423 --account-name db-webapp-3srt4jk7qqmgu --scope db-webapp-3srt4jk7qqmgu -g serverless-app-rg

run locally npm run start --watch , update global constartnat to localhost



## Features

This project framework provides the following features:

* Feature 1
* Feature 2
* ...

## Getting Started

### Prerequisites

(ideally very short, if any)

- OS
- Library version
- ...

### Installation

(ideally very short)

- npm install [package name]
- mvn install
- ...

### Quickstart
(Add steps to get up and running quickly)

1. git clone [repository clone url]
2. cd [repository name]
3. ...


## Demo

A demo app is included to show how to use the project.

To run the demo, follow these steps:

(Add steps to start up the demo)

1.
2.
3.

## Resources

(Any additional resources or related projects)

- Link to supporting information
- Link to similar sample
- ...
