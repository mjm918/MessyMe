//
//  BreaksAPI.swift
//  Messy
//
//  Breaks API endpoints
//

import Foundation

extension APIClient {

    // MARK: - Breaks API

    /// List user's break schedules
    /// GET /breaks
    func getBreaks(userId: String) async throws -> [Break] {
        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await get(path: "/breaks", queryItems: queryItems)
    }

    /// Create break schedule
    /// POST /breaks
    func createBreak(
        userId: String,
        type: BreakType,
        name: String,
        scheduledTime: String? = nil,
        isRecurring: Bool? = nil,
        recurrencePattern: RecurrencePattern? = nil
    ) async throws -> Break {
        var request = CreateBreakRequest(type: type, name: name)
        request.scheduledTime = scheduledTime
        request.isRecurring = isRecurring
        request.recurrencePattern = recurrencePattern

        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await post(path: "/breaks", queryItems: queryItems, body: request)
    }

    /// Get break schedule by ID
    /// GET /breaks/:id
    func getBreak(id: String) async throws -> Break {
        try await get(path: "/breaks/\(id)")
    }

    /// Update break schedule
    /// PUT /breaks/:id
    func updateBreak(
        id: String,
        type: BreakType? = nil,
        name: String? = nil,
        scheduledTime: String? = nil,
        isRecurring: Bool? = nil,
        recurrencePattern: RecurrencePattern? = nil
    ) async throws -> Break {
        var request = UpdateBreakRequest()
        request.type = type
        request.name = name
        request.scheduledTime = scheduledTime
        request.isRecurring = isRecurring
        request.recurrencePattern = recurrencePattern

        return try await put(path: "/breaks/\(id)", body: request)
    }

    /// Delete break schedule
    /// DELETE /breaks/:id
    func deleteBreak(id: String) async throws -> MessageResponse {
        try await delete(path: "/breaks/\(id)")
    }

    // MARK: - Break History

    /// Log a break taken
    /// POST /breaks/log
    func logBreak(
        userId: String,
        startedAt: Date,
        endedAt: Date? = nil,
        durationMinutes: Int? = nil,
        breakId: String? = nil
    ) async throws -> BreakHistory {
        let formatter = ISO8601DateFormatter()
        var request = LogBreakRequest(startedAt: formatter.string(from: startedAt))
        request.endedAt = endedAt.map { formatter.string(from: $0) }
        request.durationMinutes = durationMinutes
        request.breakId = breakId

        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await post(path: "/breaks/log", queryItems: queryItems, body: request)
    }

    /// Get break history
    /// GET /breaks/history/list
    func getBreakHistory(userId: String, limit: Int = 100) async throws -> [BreakHistoryWithBreak] {
        let queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await get(path: "/breaks/history/list", queryItems: queryItems)
    }
}
