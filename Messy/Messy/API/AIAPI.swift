//
//  AIAPI.swift
//  Messy
//
//  AI / RAG API endpoints
//

import Foundation

/// Search result type filter
enum SearchType: String, Codable {
    case task
    case recording
    case meeting
}

extension APIClient {

    // MARK: - AI / RAG API

    /// Search knowledge base
    /// POST /ai/search
    func searchKnowledgeBase(
        orgId: String,
        query: String,
        limit: Int? = nil,
        type: SearchType? = nil
    ) async throws -> SearchResponse {
        var searchRequest = SearchRequest(query: query)
        searchRequest.limit = limit
        searchRequest.type = type?.rawValue

        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await post(path: "/ai/search", queryItems: queryItems, body: searchRequest)
    }

    /// Ask AI with RAG context
    /// POST /ai/ask
    func askAI(orgId: String, query: String) async throws -> AskResponse {
        let request = AskRequest(query: query)
        let queryItems = [URLQueryItem(name: "orgId", value: orgId)]
        return try await post(path: "/ai/ask", queryItems: queryItems, body: request)
    }

    /// Get AI task prioritization
    /// POST /ai/prioritize
    func prioritizeTasks(
        userId: String,
        orgId: String,
        currentLocation: CurrentLocation? = nil
    ) async throws -> PrioritizeResponse {
        var request = PrioritizeRequest()
        request.currentLocation = currentLocation

        let queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "orgId", value: orgId)
        ]
        return try await post(path: "/ai/prioritize", queryItems: queryItems, body: request)
    }

    /// Convenience method: Prioritize tasks with CLLocationCoordinate2D
    func prioritizeTasks(
        userId: String,
        orgId: String,
        latitude: Double,
        longitude: Double
    ) async throws -> PrioritizeResponse {
        let location = CurrentLocation(latitude: latitude, longitude: longitude)
        return try await prioritizeTasks(userId: userId, orgId: orgId, currentLocation: location)
    }
}
