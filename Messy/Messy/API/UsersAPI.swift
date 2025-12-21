//
//  UsersAPI.swift
//  Messy
//
//  Users API endpoints
//

import Foundation

extension APIClient {

    // MARK: - Users API

    /// Create or get user (JIT by email)
    /// POST /users
    func createOrGetUser(email: String, name: String? = nil) async throws -> User {
        let request = CreateUserRequest(email: email, name: name)
        let user: User = try await post(path: "/users", body: request)

        // Update current user email for auth
        self.currentUserEmail = user.email

        return user
    }

    /// Get user by ID
    /// GET /users/:id
    func getUser(id: String) async throws -> User {
        try await get(path: "/users/\(id)")
    }

    /// Get user's organizations
    /// GET /users/:id/orgs
    func getUserOrganizations(userId: String) async throws -> [UserOrgMembership] {
        try await get(path: "/users/\(userId)/orgs")
    }
}
