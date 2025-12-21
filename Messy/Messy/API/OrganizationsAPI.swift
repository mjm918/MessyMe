//
//  OrganizationsAPI.swift
//  Messy
//
//  Organizations API endpoints
//

import Foundation

extension APIClient {

    // MARK: - Organizations API

    /// Create organization
    /// POST /orgs
    func createOrganization(name: String, adminEmail: String) async throws -> Organization {
        let request = CreateOrgRequest(name: name, adminEmail: adminEmail)
        return try await post(path: "/orgs", body: request)
    }

    /// Get organization with members
    /// GET /orgs/:id
    func getOrganization(id: String) async throws -> OrganizationWithMembers {
        try await get(path: "/orgs/\(id)")
    }

    /// Join organization via invite code
    /// POST /orgs/join
    func joinOrganization(inviteCode: String, email: String) async throws -> JoinOrgResponse {
        let request = JoinOrgRequest(inviteCode: inviteCode, email: email)
        return try await post(path: "/orgs/join", body: request)
    }

    /// Delete organization (admin only)
    /// DELETE /orgs/:id
    func deleteOrganization(id: String) async throws -> MessageResponse {
        try await delete(path: "/orgs/\(id)")
    }

    /// Kick member from organization (admin only)
    /// DELETE /orgs/:id/members/:userId
    func kickMember(orgId: String, userId: String) async throws -> MessageResponse {
        try await delete(path: "/orgs/\(orgId)/members/\(userId)")
    }
}
