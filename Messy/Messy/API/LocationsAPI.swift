//
//  LocationsAPI.swift
//  Messy
//
//  Locations API endpoints
//

import Foundation

extension APIClient {

    // MARK: - Locations API

    /// List user's locations
    /// GET /locations
    func getLocations(userId: String) async throws -> [Location] {
        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await get(path: "/locations", queryItems: queryItems)
    }

    /// Create location
    /// POST /locations
    func createLocation(
        userId: String,
        name: String,
        type: LocationType? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> Location {
        var request = CreateLocationRequest(name: name)
        request.type = type
        request.address = address
        request.latitude = latitude
        request.longitude = longitude

        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await post(path: "/locations", queryItems: queryItems, body: request)
    }

    /// Get location by ID
    /// GET /locations/:id
    func getLocation(id: String) async throws -> Location {
        try await get(path: "/locations/\(id)")
    }

    /// Update location
    /// PUT /locations/:id
    func updateLocation(
        id: String,
        name: String? = nil,
        type: LocationType? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> Location {
        var request = UpdateLocationRequest()
        request.name = name
        request.type = type
        request.address = address
        request.latitude = latitude
        request.longitude = longitude

        return try await put(path: "/locations/\(id)", body: request)
    }

    /// Delete location
    /// DELETE /locations/:id
    func deleteLocation(id: String) async throws -> MessageResponse {
        try await delete(path: "/locations/\(id)")
    }

    // MARK: - Location History

    /// Log current location
    /// POST /locations/history
    func logLocationHistory(
        userId: String,
        latitude: Double,
        longitude: Double,
        locationId: String? = nil
    ) async throws -> LocationHistory {
        var request = LogLocationHistoryRequest(latitude: latitude, longitude: longitude)
        request.locationId = locationId

        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await post(path: "/locations/history", queryItems: queryItems, body: request)
    }

    /// Get location history
    /// GET /locations/history/list
    func getLocationHistory(userId: String, limit: Int = 100) async throws -> [LocationHistory] {
        let queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await get(path: "/locations/history/list", queryItems: queryItems)
    }
}
