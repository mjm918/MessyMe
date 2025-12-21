//
//  TasksAPI.swift
//  Messy
//
//  Tasks API endpoints
//

import Foundation

/// Task list filter options
enum TaskFilter: String {
    case all
    case today
    case upcoming
    case overdue
}

extension APIClient {

    // MARK: - Tasks API

    /// List user's tasks
    /// GET /tasks
    func getTasks(
        userId: String,
        orgId: String,
        filter: TaskFilter? = nil,
        completed: Bool? = nil
    ) async throws -> [TaskItem] {
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "orgId", value: orgId)
        ]

        if let filter = filter, filter != .all {
            queryItems.append(URLQueryItem(name: "filter", value: filter.rawValue))
        }

        if let completed = completed {
            queryItems.append(URLQueryItem(name: "completed", value: completed ? "true" : "false"))
        }

        return try await get(path: "/tasks", queryItems: queryItems)
    }

    /// Create task
    /// POST /tasks
    func createTask(
        userId: String,
        orgId: String,
        title: String,
        notes: String? = nil,
        priority: TaskPriority? = nil,
        dueDate: String? = nil,
        dueTime: String? = nil,
        tags: [String]? = nil,
        locationContext: LocationContext? = nil
    ) async throws -> TaskItem {
        var request = CreateTaskRequest(
            userId: userId,
            orgId: orgId,
            title: title
        )
        request.notes = notes
        request.priority = priority
        request.dueDate = dueDate
        request.dueTime = dueTime
        request.tags = tags
        request.locationContext = locationContext

        return try await post(path: "/tasks", body: request)
    }

    /// Get task by ID
    /// GET /tasks/:id
    func getTask(id: String) async throws -> TaskItem {
        try await get(path: "/tasks/\(id)")
    }

    /// Update task
    /// PUT /tasks/:id
    func updateTask(
        id: String,
        title: String? = nil,
        notes: String? = nil,
        priority: TaskPriority? = nil,
        dueDate: String? = nil,
        dueTime: String? = nil,
        tags: [String]? = nil,
        locationContext: LocationContext? = nil
    ) async throws -> TaskItem {
        var request = UpdateTaskRequest()
        request.title = title
        request.notes = notes
        request.priority = priority
        request.dueDate = dueDate
        request.dueTime = dueTime
        request.tags = tags
        request.locationContext = locationContext

        return try await put(path: "/tasks/\(id)", body: request)
    }

    /// Delete task
    /// DELETE /tasks/:id
    func deleteTask(id: String) async throws -> MessageResponse {
        try await delete(path: "/tasks/\(id)")
    }

    /// Mark task as complete
    /// POST /tasks/:id/complete
    func completeTask(id: String) async throws -> TaskItem {
        try await post(path: "/tasks/\(id)/complete")
    }

    /// Mark task as incomplete
    /// POST /tasks/:id/uncomplete
    func uncompleteTask(id: String) async throws -> TaskItem {
        try await post(path: "/tasks/\(id)/uncomplete")
    }
}
