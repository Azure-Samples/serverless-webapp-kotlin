package org.example

import com.azure.cosmos.CosmosAsyncClient
import com.azure.cosmos.CosmosClientBuilder
import com.azure.cosmos.models.PartitionKey
import com.azure.identity.DefaultAzureCredentialBuilder
import com.azure.security.keyvault.secrets.SecretClientBuilder
import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.microsoft.azure.functions.*
import com.microsoft.azure.functions.annotation.AuthorizationLevel
import com.microsoft.azure.functions.annotation.FunctionName
import com.microsoft.azure.functions.annotation.HttpTrigger
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.core.SdkBytes
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.rekognition.RekognitionClient
import software.amazon.awssdk.services.rekognition.model.FaceMatch
import software.amazon.awssdk.services.rekognition.model.Image
import software.amazon.awssdk.services.rekognition.model.SearchFacesByImageResponse
import java.util.*


class FindPersonFunction {
    private val mapper = jacksonObjectMapper()

    private val COLLECTION_ID = "FaceAppCollection"

    private val keyVaultClient = SecretClientBuilder()
        .vaultUrl("https://${System.getenv("KEYVAULT_NAME")}.vault.azure.net/")
        .credential(DefaultAzureCredentialBuilder().build())
        .buildClient()

    private val cosmoClient: CosmosAsyncClient = CosmosClientBuilder()
        .credential(DefaultAzureCredentialBuilder().build())
        .endpoint(System.getenv("FaceAppDatabaseConnectionString__accountEndpoint"))
        .buildAsyncClient()

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
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL)
    }

    @FunctionName("find-person")
    fun run(
        @HttpTrigger(
            name = "req",
            methods = [HttpMethod.POST],
            authLevel = AuthorizationLevel.FUNCTION
        ) request: HttpRequestMessage<Optional<String>>,
        context: ExecutionContext
    ): HttpResponseMessage {

        return if (request.body.isPresent.not()) {
            request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                .header("Content-Type", "application/json")
                .header("Access-Control-Allow-Origin", "*")
                .body(mapper.writeValueAsString(FindPersonResponse(message = "No image found in body. Pass base 64 encode image in the request body")))
                .build()
        } else {
            val responseBuilder = request.createResponseBuilder(HttpStatus.OK)
                .header("Content-Type", "application/json")
                .header("Access-Control-Allow-Origin", "*")

            val decodedImage: ByteArray = Base64.getDecoder().decode(request.body.get())

            val faceSearch = faceSearch(decodedImage, context)

            if (faceSearch.isNotEmpty()) {
                val faceMatch: FaceMatch = faceSearch[0]

                val (_, name) = cosmoClient.getDatabase("faceapp")
                    .getContainer("faces")
                    .readAllItems(PartitionKey(faceMatch.face().faceId()), FaceRegistration::class.java)
                    .blockFirst()!!

                responseBuilder
                    .body(mapper.writeValueAsString(FindPersonResponse(person_name = name)))
                    .build()
            } else {
                responseBuilder
                    .body(mapper.writeValueAsString(FindPersonResponse(message = "No match found in the record")))
                    .build()
            }
        }
    }

    private fun faceSearch(decodedImage: ByteArray, context: ExecutionContext): List<FaceMatch> {
        return try {
            val searchFacesByImageResponse: SearchFacesByImageResponse =
                recognitionClient.searchFacesByImage { builder ->
                    builder.collectionId(COLLECTION_ID)
                        .image(
                            Image.builder()
                                .bytes(SdkBytes.fromByteArray(decodedImage)).build()
                        )
                        .maxFaces(1)
                        .faceMatchThreshold(90f)
                }

            context.logger.info("Service response for find face $searchFacesByImageResponse")
            searchFacesByImageResponse
                .faceMatches()
        } catch (e: Exception) {
            context.logger.severe("Failed getting find face result. Reason: $e")
            emptyList()
        }
    }
}