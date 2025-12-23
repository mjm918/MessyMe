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
    
    /// Upload audio file to S3 (legacy - uploads through server)
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
    
    // MARK: - Presigned Upload Flow (Async Transcription)
    
    /// Get presigned URL for direct S3 upload
    /// GET /recordings/upload-url
    func getUploadUrl(orgId: String, ext: String = "m4a") async throws -> PresignedUploadResponse {
        let queryItems = [
            URLQueryItem(name: "orgId", value: orgId),
            URLQueryItem(name: "ext", value: ext)
        ]
        return try await get(path: "/recordings/upload-url", queryItems: queryItems)
    }
    
    /// Upload file directly to S3 using presigned URL with progress tracking
    func uploadToS3(presignedUrl: String, audioData: Data, contentType: String = "audio/mp4", progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let url = URL(string: presignedUrl) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(audioData.count), forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 300 // 5 min timeout for large files
        
        // Use URLSessionUploadTask with delegate for progress tracking
        let delegate = UploadProgressDelegate(progressHandler: progressHandler)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        let (_, response) = try await session.upload(for: request, from: audioData)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: "S3 upload failed")
        }
    }
    
    /// Create recording and queue transcription job
    /// POST /recordings/create-with-transcription
    func createRecordingWithTranscription(
        orgId: String,
        userId: String,
        type: RecordingType,
        title: String? = nil,
        audioUrl: String,
        durationSeconds: Int? = nil
    ) async throws -> Recording {
        var request = CreateRecordingRequest(userId: userId, type: type)
        request.title = title
        request.audioUrl = audioUrl
        request.durationSeconds = durationSeconds
        
        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await post(path: "/recordings/create-with-transcription", queryItems: queryItems, body: request)
    }
    
    /// Get transcription status for a recording
    /// GET /recordings/:id/transcription-status
    func getTranscriptionStatus(recordingId: String) async throws -> TranscriptionStatusResponse {
        try await get(path: "/recordings/\(recordingId)/transcription-status")
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

struct PresignedUploadResponse: Codable {
    let uploadUrl: String
    let audioUrl: String
    let filename: String
    let s3Key: String
}

struct TranscriptionStatusResponse: Codable {
    let id: String
    let transcriptionStatus: TranscriptionStatus?
    let transcriptionError: String?
    let transcript: String?
}

// MARK: - Upload Progress Delegate

class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let progressHandler: ((Double) -> Void)?
    
    init(progressHandler: ((Double) -> Void)?) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressHandler?(progress)
    }
}
