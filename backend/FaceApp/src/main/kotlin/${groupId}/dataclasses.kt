package org.example

import com.fasterxml.jackson.annotation.JsonProperty

data class FaceRegistration(@JsonProperty("id") val id: String, @JsonProperty("name") val name: String)

data class FindPersonResponse(val person_name: String? = null, val message: String? = null)

data class UploadImageResponse(val uploadURL: String, val fileName: String)

data class UploadImageErrorResponse(val message: String)

