package org.example

import com.azure.identity.DefaultAzureCredentialBuilder
import com.azure.security.keyvault.secrets.SecretClientBuilder
import com.azure.storage.blob.BlobContainerClientBuilder
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.microsoft.azure.functions.*
import com.microsoft.azure.functions.annotation.*
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.core.SdkBytes
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.rekognition.RekognitionClient
import software.amazon.awssdk.services.rekognition.model.*
import java.lang.RuntimeException
import java.util.*

class FileUploadProcessorFunction {
    private val mapper = jacksonObjectMapper()

    private val blobServiceClient = BlobContainerClientBuilder()
        .endpoint("https://${System.getenv("APP_STORAGE_ACCOUNT")}.blob.core.windows.net")
        .containerName("images")
        .credential(
            DefaultAzureCredentialBuilder()
                .build()
        )
        .buildClient()

    // todo switch once we have access
    private val COLLECTION_ID = "FaceAppCollection"

    private val keyVaultClient = SecretClientBuilder()
        .vaultUrl("https://${System.getenv("KEYVAULT_NAME")}.vault.azure.net/")
        .credential(DefaultAzureCredentialBuilder().build())
        .buildClient()

    private val recognitionClient = RekognitionClient
        .builder()
        .region(Region.EU_WEST_1)
        .credentialsProvider(
            StaticCredentialsProvider.create(
                AwsBasicCredentials.create(
                    keyVaultClient.getSecret("AWSAccessKey").value,
                    keyVaultClient.getSecret("AwsSecretKey").value
                )
            )
        ).build()

    init {
        val listCollections = recognitionClient.listCollections()

        val existsAlready = listCollections.collectionIds().any {
            it.equals(COLLECTION_ID)
        }

        if (existsAlready.not()) {
            val createCollection = recognitionClient.createCollection(
                CreateCollectionRequest.builder()
                    .collectionId(COLLECTION_ID)
                    .build()
            )

            println(createCollection)
        }
    }

    @FunctionName("file-upload-processor")
    @CosmosDBOutput(
        name = "database",
        databaseName = "%FACE_APP_DATABASE_NAME%",
        containerName = "%FACE_APP_CONTAINER_NAME%",
        connection = "FaceAppDatabaseConnectionString"
    )
    fun run(
        @BlobTrigger(
            name = "content",
            dataType = "binary",
            path = "images/{fileName}",
            source = "EventGrid",
            connection = "FaceStorage"
        ) content: ByteArray,
        @BindingName("fileName") fileName: String,
        context: ExecutionContext
    ): String {
        val blobClient = blobServiceClient.getBlobClient(fileName)

        val name: String = blobClient.properties.metadata["fullname"] ?: ""

        // TODO:  Add face api related logic here
        // val group = faceApi.personGroups().get(name)

        val indexFacesResponse: IndexFacesResponse =
            recognitionClient.indexFaces(IndexFacesRequest.builder()
                .collectionId(COLLECTION_ID)
                .image { builder: Image.Builder ->
                    builder.bytes(SdkBytes.fromByteArray(content))
                }
                .build())

        context.logger.info("Response from index face: $indexFacesResponse")
        val faceId = if (indexFacesResponse.sdkHttpResponse().isSuccessful) {
            FaceRegistration(indexFacesResponse.faceRecords()[0].face().faceId(), name)
        } else {
            throw RuntimeException("Failed with error $indexFacesResponse")
        }

        context.logger.info("Name: $fileName  Size: ${content.size} bytes Meta name: $name")
        return mapper.writeValueAsString(faceId)
    }
}
