//
//  APIClient.swift
//  Messy
//
//  Base API client for MessyMe backend
//

import Foundation
import Combine

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP Error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - API Client

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // Current user email for auth header
    @Published var currentUserEmail: String?

    private init() {
        // Use 127.0.0.1 instead of localhost to avoid DNS resolution issues in sandboxed macOS apps
        let host = ProcessInfo.processInfo.environment["API_HOST"] ?? "127.0.0.1"
        let port = ProcessInfo.processInfo.environment["API_PORT"] ?? "3000"
        self.baseURL = URL(string: "http://\(host):\(port)")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try date-only format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Configuration

    func configure(baseURL: URL) {
        // Note: In a real app, you'd want to make baseURL mutable
        // or use a different configuration approach
    }

    // MARK: - Request Building

    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems?.isEmpty == false ? queryItems : nil

        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func buildRequest(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        additionalHeaders: [String: String]? = nil
    ) throws -> URLRequest {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth header if available
        if let email = currentUserEmail {
            request.setValue(email, forHTTPHeaderField: "X-User-Email")
        }

        // Add additional headers
        additionalHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    // MARK: - Request Execution

    func request<T: Decodable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> T {
        let request = try buildRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            additionalHeaders: additionalHeaders
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Check for error status codes
        if httpResponse.statusCode >= 400 {
            // Try to decode error message
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse.error)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func requestWithoutResponse(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws {
        let request = try buildRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            additionalHeaders: additionalHeaders
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse.error)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    // MARK: - Convenience Methods

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        try await request(method: .get, path: path, queryItems: queryItems)
    }

    func post<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        try await request(method: .post, path: path, queryItems: queryItems, body: body)
    }

    func put<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        try await request(method: .put, path: path, queryItems: queryItems, body: body)
    }

    func delete<T: Decodable>(path: String) async throws -> T {
        try await request(method: .delete, path: path)
    }

    func delete(path: String) async throws {
        try await requestWithoutResponse(method: .delete, path: path)
    }
    
    // MARK: - Multipart Upload
    
    func uploadMultipart<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        fileData: Data,
        filename: String,
        fieldName: String,
        mimeType: String
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add auth header if available
        if let email = currentUserEmail {
            request.setValue(email, forHTTPHeaderField: "X-User-Email")
        }
        
        // Build multipart body
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse.error)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
