package org.example

import com.azure.cosmos.CosmosClientBuilder
import com.azure.cosmos.models.CosmosQueryRequestOptions
import com.azure.identity.DefaultAzureCredentialBuilder
import com.azure.security.keyvault.secrets.SecretClientBuilder
import com.azure.storage.blob.BlobContainerClientBuilder
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.microsoft.azure.cognitiveservices.vision.faceapi.FaceAPIManager
import com.microsoft.azure.cognitiveservices.vision.faceapi.models.*
import com.microsoft.azure.functions.*
import com.microsoft.azure.functions.annotation.*
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

    private val container = CosmosClientBuilder()
        .endpoint(System.getenv("FaceAppDatabaseConnectionString__accountEndpoint"))
        .credential(
            DefaultAzureCredentialBuilder()
                .build()
        )
        .buildClient()
        .getDatabase(System.getenv("FACE_APP_DATABASE_NAME"))
        .getContainer(System.getenv("FACE_APP_CONTAINER_NAME"))


    private val keyVaultClient = SecretClientBuilder()
        .vaultUrl("https://${System.getenv("KEYVAULT_NAME")}.vault.azure.net/")
        .credential(DefaultAzureCredentialBuilder().build())
        .buildClient()

    private val faceApi = FaceAPIManager.authenticate(
        AzureRegions.WESTEUROPE, keyVaultClient.getSecret("CognitiveServiceKey").value)

    init {
        val group: PersonGroup? = faceApi.personGroups().get(PERSON_GROUP_ID)

        if (group == null) {
            faceApi.personGroups().create(
                PERSON_GROUP_ID, CreatePersonGroupsOptionalParameter()
                    .withName("faceAppGroup")
            )
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

        val item =
        container.queryItems( "SELECT c.id, c.name, c.faceIds FROM c WHERE c.name = '${name}'", CosmosQueryRequestOptions(), FaceRegistration::class.java)

        val faceRegistration = if (item.iterator().hasNext()) {
             item.iterator().next()
        } else {
            val person = faceApi.personGroupPersons().create(
                PERSON_GROUP_ID, CreatePersonGroupPersonsOptionalParameter()
                    .withName(name)
            )

            FaceRegistration(person.personId().toString(), name)
        }

        val persistedFace = faceApi.personGroupPersons().addPersonFaceFromStream(
            PERSON_GROUP_ID,
            UUID.fromString(faceRegistration.id),
            content,
            AddPersonFaceFromStreamOptionalParameter()
        )

        context.logger.info("Response from persisting face: $persistedFace")

        faceRegistration.faceIds.add(persistedFace.persistedFaceId().toString())

        faceApi.personGroups().train(PERSON_GROUP_ID)

        context.logger.info("Name: $fileName  Size: ${content.size} bytes Meta name: $name")
        return mapper.writeValueAsString(faceRegistration)
    }
}
