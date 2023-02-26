package org.example

import com.azure.identity.DefaultAzureCredentialBuilder
import com.azure.storage.blob.BlobContainerClient
import com.azure.storage.blob.BlobServiceClient
import com.azure.storage.blob.BlobServiceClientBuilder
import com.azure.storage.blob.sas.BlobSasPermission
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.microsoft.azure.functions.*
import com.microsoft.azure.functions.annotation.*
import java.time.OffsetDateTime
import java.util.*

class UploadFunction {

    private val mapper = jacksonObjectMapper()

    private val storageAccountUrl = "https://${System.getenv("APP_STORAGE_ACCOUNT")}.blob.core.windows.net"

    private val client: BlobServiceClient = BlobServiceClientBuilder()
        .endpoint(storageAccountUrl)
        .credential(DefaultAzureCredentialBuilder().build())
        .buildClient()

    @FunctionName("upload-url")
    fun run(
        @HttpTrigger(
            name = "req",
            methods = [HttpMethod.GET],
            authLevel = AuthorizationLevel.FUNCTION
        ) request: HttpRequestMessage<Optional<String>>,
        context: ExecutionContext
    ): HttpResponseMessage {

        context.logger.info("HTTP trigger processed a ${request.httpMethod.name} request.")

        val fileExtension = request.queryParameters["file-extension"]
        val fileName = fileExtension?.let { UUID.randomUUID().toString() + it }

        fileName?.let {
            val blobSasPermission = BlobSasPermission.parse("cw")

            val blobServiceSasSignatureValues =
                BlobServiceSasSignatureValues(OffsetDateTime.now().plusMinutes(5), blobSasPermission)

            val blobContainerClient: BlobContainerClient = client.getBlobContainerClient("images")
            val blobClient = blobContainerClient.getBlobClient(fileName)

            val userDelegationKey = client.getUserDelegationKey(
                blobServiceSasSignatureValues.startTime,
                blobServiceSasSignatureValues.expiryTime
            )

            val generateUserDelegationSas =
                blobClient.generateUserDelegationSas(blobServiceSasSignatureValues, userDelegationKey)

            return request
                .createResponseBuilder(HttpStatus.OK)
                .header("Content-Type", "application/json")
                .header("Access-Control-Allow-Origin", "*")
                .body(mapper.writeValueAsString(UploadImageResponse("${storageAccountUrl}/images/$fileName?$generateUserDelegationSas", it)))
                .build()
        }

        return request
            .createResponseBuilder(HttpStatus.BAD_REQUEST)
            .header("Content-Type", "application/json")
            .body(mapper.writeValueAsString(UploadImageErrorResponse("Please pass a file-extension on the query string")))
            .build()
    }
}