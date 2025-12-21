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
        durationSeconds: Int? = nil
    ) async throws -> Recording {
        var request = CreateRecordingRequest(userId: userId, type: type)
        request.title = title
        request.transcript = transcript
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
        durationSeconds: Int? = nil
    ) async throws -> Recording {
        var request = UpdateRecordingRequest()
        request.type = type
        request.title = title
        request.transcript = transcript
        request.durationSeconds = durationSeconds

        return try await put(path: "/recordings/\(id)", body: request)
    }

    /// Delete recording
    /// DELETE /recordings/:id
    func deleteRecording(id: String) async throws -> MessageResponse {
        try await delete(path: "/recordings/\(id)")
    }
}
