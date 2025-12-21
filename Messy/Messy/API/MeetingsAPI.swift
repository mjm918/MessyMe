//
//  MeetingsAPI.swift
//  Messy
//
//  Meetings API endpoints
//

import Foundation

extension APIClient {

    // MARK: - Meetings API

    /// List meetings for organization
    /// GET /meetings
    func getMeetings(orgId: String) async throws -> [Meeting] {
        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await get(path: "/meetings", queryItems: queryItems)
    }

    /// Create meeting
    /// POST /meetings
    func createMeeting(
        orgId: String,
        userId: String,
        title: String,
        notes: String? = nil,
        meetingDate: Date? = nil,
        participants: [String]? = nil
    ) async throws -> Meeting {
        var request = CreateMeetingRequest(userId: userId, title: title)
        request.notes = notes
        request.meetingDate = meetingDate.map { ISO8601DateFormatter().string(from: $0) }
        request.participants = participants

        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await post(path: "/meetings", queryItems: queryItems, body: request)
    }

    /// Get meeting by ID
    /// GET /meetings/:id
    func getMeeting(id: String) async throws -> Meeting {
        try await get(path: "/meetings/\(id)")
    }

    /// Update meeting
    /// PUT /meetings/:id
    func updateMeeting(
        id: String,
        title: String? = nil,
        notes: String? = nil,
        meetingDate: Date? = nil,
        participants: [String]? = nil
    ) async throws -> Meeting {
        var request = UpdateMeetingRequest()
        request.title = title
        request.notes = notes
        request.meetingDate = meetingDate.map { ISO8601DateFormatter().string(from: $0) }
        request.participants = participants

        return try await put(path: "/meetings/\(id)", body: request)
    }

    /// Delete meeting
    /// DELETE /meetings/:id
    func deleteMeeting(id: String) async throws -> MessageResponse {
        try await delete(path: "/meetings/\(id)")
    }
}
