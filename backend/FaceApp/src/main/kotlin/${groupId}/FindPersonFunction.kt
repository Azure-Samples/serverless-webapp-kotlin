package org.example

import com.azure.cosmos.CosmosAsyncClient
import com.azure.cosmos.CosmosClientBuilder
import com.azure.cosmos.models.PartitionKey
import com.azure.identity.DefaultAzureCredentialBuilder
import com.azure.security.keyvault.secrets.SecretClientBuilder
import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.microsoft.azure.cognitiveservices.vision.faceapi.FaceAPIManager
import com.microsoft.azure.cognitiveservices.vision.faceapi.models.*
import com.microsoft.azure.functions.*
import com.microsoft.azure.functions.annotation.AuthorizationLevel
import com.microsoft.azure.functions.annotation.FunctionName
import com.microsoft.azure.functions.annotation.HttpTrigger
import java.util.*


class FindPersonFunction {
    private val mapper = jacksonObjectMapper()

    private val keyVaultClient = SecretClientBuilder()
        .vaultUrl("https://${System.getenv("KEYVAULT_NAME")}.vault.azure.net/")
        .credential(DefaultAzureCredentialBuilder().build())
        .buildClient()

    private val cosmoClient: CosmosAsyncClient = CosmosClientBuilder()
        .credential(DefaultAzureCredentialBuilder().build())
        .endpoint(System.getenv("FaceAppDatabaseConnectionString__accountEndpoint"))
        .buildAsyncClient()

    private val faceApi = FaceAPIManager.authenticate(
        AzureRegions.WESTEUROPE, keyVaultClient.getSecret("CognitiveServiceKey").value
    )

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

            var trainingStatus = TrainingStatus()
                .withStatus(TrainingStatusType.RUNNING)

            while (trainingStatus.status() == TrainingStatusType.NONSTARTED
                || trainingStatus.status() == TrainingStatusType.RUNNING
            ) {

                trainingStatus = faceApi.personGroups().getTrainingStatus(PERSON_GROUP_ID)

                // Possibly person group is not created yet. Meaning register image has not been invoked even once.
                if (trainingStatus == null) {
                    return responseBuilder
                        .body(mapper.writeValueAsString(FindPersonResponse(message = "No match found in the record")))
                        .build()
                }
            }

            val detectedFaces = faceApi.faces().detectWithStream(
                decodedImage, DetectWithStreamOptionalParameter()
                    .withReturnFaceId(true)
                    .withReturnFaceLandmarks(true)
            )

            val identify = faceApi.faces()
                .identify(
                    PERSON_GROUP_ID, detectedFaces.map { it.faceId() }, IdentifyOptionalParameter()
                        .withMaxNumOfCandidatesReturned(1)
                        .withConfidenceThreshold(0.7)
                )

            val personId =
                identify.flatMap { it.candidates() }
                    .map { it.personId() }
                    .map { it.toString() }
                    .firstOrNull()

            if (personId != null) {
                val faceRegistration = cosmoClient.getDatabase(System.getenv("FACE_APP_DATABASE_NAME"))
                    .getContainer(System.getenv("FACE_APP_CONTAINER_NAME"))
                    .readAllItems(PartitionKey(personId), FaceRegistration::class.java)
                    .blockFirst()

                if (faceRegistration != null) {
                    responseBuilder
                        .body(mapper.writeValueAsString(FindPersonResponse(person_name = faceRegistration.name)))
                        .build()
                } else {
                    responseBuilder
                        .body(mapper.writeValueAsString(FindPersonResponse(message = "No match found in the record")))
                        .build()
                }
            } else {
                responseBuilder
                    .body(mapper.writeValueAsString(FindPersonResponse(message = "No match found in the record")))
                    .build()
            }
        }
    }
}