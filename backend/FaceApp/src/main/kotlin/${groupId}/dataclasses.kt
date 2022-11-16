package org.example

import com.fasterxml.jackson.annotation.JsonProperty
import java.util.*

val PERSON_GROUP_ID = UUID.nameUUIDFromBytes("faceAppGroup".toByteArray()).toString()

data class FaceRegistration(
    @JsonProperty("id") val id: String,
    @JsonProperty("name") val name: String,
    @JsonProperty("faceIds") val faceIds: MutableList<String> = mutableListOf()
)

data class FindPersonResponse(val person_name: String? = null, val message: String? = null)

data class UploadImageResponse(val uploadURL: String, val fileName: String)

data class UploadImageErrorResponse(val message: String)

