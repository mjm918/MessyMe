//
//  RecordingsAPI.swift
//  Messy
//
//  Recordings API endpoints
//

import Foundation

extension APIClient {

    // MARK: - Recordings API

    /// List recordings for organization
    /// GET /recordings
    func getRecordings(orgId: String) async throws -> [Recording] {
        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await get(path: "/recordings", queryItems: queryItems)
    }

    /// Create recording
    /// POST /recordings
    func createRecording(
        orgId: String,
        userId: String,
        type: RecordingType,
        title: String? = nil,
        transcript: String? = nil,
        audioUrl: String? = nil,
        durationSeconds: Int? = nil
    ) async throws -> Recording {
        var request = CreateRecordingRequest(userId: userId, type: type)
        request.title = title
        request.transcript = transcript
        request.audioUrl = audioUrl
        request.durationSeconds = durationSeconds

        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await post(path: "/recordings", queryItems: queryItems, body: request)
    }

    /// Get recording by ID
    /// GET /recordings/:id
    func getRecording(id: String) async throws -> Recording {
        try await get(path: "/recordings/\(id)")
    }

    /// Update recording
    /// PUT /recordings/:id
    func updateRecording(
        id: String,
        type: RecordingType? = nil,
        title: String? = nil,
        transcript: String? = nil,
        audioUrl: String? = nil,
        durationSeconds: Int? = nil
    ) async throws -> Recording {
        var request = UpdateRecordingRequest()
        request.type = type
        request.title = title
        request.transcript = transcript
        request.audioUrl = audioUrl
        request.durationSeconds = durationSeconds

        return try await put(path: "/recordings/\(id)", body: request)
    }

    /// Delete recording
    /// DELETE /recordings/:id
    func deleteRecording(id: String) async throws -> MessageResponse {
        try await delete(path: "/recordings/\(id)")
    }
    
    /// Get presigned audio URL for playback
    /// GET /recordings/:id/audio-url
    func getAudioUrl(recordingId: String) async throws -> AudioUrlResponse {
        try await get(path: "/recordings/\(recordingId)/audio-url")
    }
    
    /// Upload audio file to S3
    /// POST /recordings/upload
    func uploadAudio(orgId: String, audioData: Data, filename: String) async throws -> UploadResponse {
        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await uploadMultipart(
            path: "/recordings/upload",
            queryItems: queryItems,
            fileData: audioData,
            filename: filename,
            fieldName: "audio",
            mimeType: "audio/mp4"
        )
    }
}

struct UploadResponse: Codable {
    let audioUrl: String
    let filename: String
    let transcript: String?
    let languageCode: String?
}

struct AudioUrlResponse: Codable {
    let url: String
}
