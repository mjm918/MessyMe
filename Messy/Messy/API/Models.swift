//
//  Models.swift
//  Messy
//
//  API Models matching backend database schemas
//

import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateUserRequest: Codable {
    let email: String
    let name: String?
}

// MARK: - Organization

struct Organization: Codable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String?
    let adminUserId: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case adminUserId = "admin_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct OrganizationWithMembers: Codable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String?
    let adminUserId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let members: [OrgMember]?

    enum CodingKeys: String, CodingKey {
        case id, name, members
        case inviteCode = "invite_code"
        case adminUserId = "admin_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct OrgMember: Codable {
    let user: User
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case user
        case joinedAt = "joined_at"
    }
}

struct UserOrgMembership: Codable {
    let org: Organization
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case org
        case joinedAt = "joined_at"
    }
}

struct CreateOrgRequest: Codable {
    let name: String
    let adminEmail: String
}

struct JoinOrgRequest: Codable {
    let inviteCode: String
    let email: String
}

struct JoinOrgResponse: Codable {
    let message: String
    let org: Organization
}

// MARK: - TaskItem

enum TaskPriority: String, Codable, CaseIterable {
    case none
    case low
    case medium
    case high
    case urgent
}

enum LocationContext: String, Codable, CaseIterable {
    case none
    case home
    case work
}

struct TaskItem: Codable, Identifiable {
    let id: String
    let userId: String?
    let orgId: String?
    let title: String
    let notes: String?
    let priority: TaskPriority?
    let dueDate: String?
    let dueTime: String?
    let tags: [String]?
    let locationContext: LocationContext?
    let isCompleted: Bool
    let completedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    // AI prioritization fields (optional, returned from AI endpoint)
    var suggestedPriority: Int?
    var priorityReason: String?

    enum CodingKeys: String, CodingKey {
        case id, title, notes, priority, tags
        case userId = "user_id"
        case orgId = "org_id"
        case dueDate = "due_date"
        case dueTime = "due_time"
        case locationContext = "location_context"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case suggestedPriority = "suggested_priority"
        case priorityReason = "priority_reason"
    }
}

struct CreateTaskRequest: Codable {
    let userId: String
    let orgId: String
    let title: String
    var notes: String?
    var priority: TaskPriority?
    var dueDate: String?
    var dueTime: String?
    var tags: [String]?
    var locationContext: LocationContext?
}

struct UpdateTaskRequest: Codable {
    var title: String?
    var notes: String?
    var priority: TaskPriority?
    var dueDate: String?
    var dueTime: String?
    var tags: [String]?
    var locationContext: LocationContext?
}

// MARK: - Recording

enum RecordingType: String, Codable, CaseIterable {
    case voiceMemo = "voice_memo"
    case meeting
}

struct Recording: Codable, Identifiable {
    let id: String
    let orgId: String?
    let userId: String?
    let type: RecordingType
    let title: String?
    let transcript: String?
    let durationSeconds: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, transcript
        case orgId = "org_id"
        case userId = "user_id"
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateRecordingRequest: Codable {
    let userId: String
    let type: RecordingType
    var title: String?
    var transcript: String?
    var durationSeconds: Int?
}

struct UpdateRecordingRequest: Codable {
    var type: RecordingType?
    var title: String?
    var transcript: String?
    var durationSeconds: Int?
}

// MARK: - Meeting

struct Meeting: Codable, Identifiable {
    let id: String
    let orgId: String?
    let userId: String?
    let title: String
    let notes: String?
    let meetingDate: Date?
    let participants: [String]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, notes, participants
        case orgId = "org_id"
        case userId = "user_id"
        case meetingDate = "meeting_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateMeetingRequest: Codable {
    let userId: String
    let title: String
    var notes: String?
    var meetingDate: String?
    var participants: [String]?
}

struct UpdateMeetingRequest: Codable {
    var title: String?
    var notes: String?
    var meetingDate: String?
    var participants: [String]?
}

// MARK: - Location

enum LocationType: String, Codable, CaseIterable {
    case home
    case work
    case custom
}

struct Location: Codable, Identifiable {
    let id: String
    let userId: String?
    let name: String
    let type: LocationType?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, type, address, latitude, longitude
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateLocationRequest: Codable {
    let name: String
    var type: LocationType?
    var address: String?
    var latitude: Double?
    var longitude: Double?
}

struct UpdateLocationRequest: Codable {
    var name: String?
    var type: LocationType?
    var address: String?
    var latitude: Double?
    var longitude: Double?
}

struct LocationHistory: Codable, Identifiable {
    let id: String
    let userId: String?
    let locationId: String?
    let latitude: Double?
    let longitude: Double?
    let recordedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude
        case userId = "user_id"
        case locationId = "location_id"
        case recordedAt = "recorded_at"
    }
}

struct LogLocationHistoryRequest: Codable {
    var locationId: String?
    let latitude: Double
    let longitude: Double
}

// MARK: - Break

enum BreakType: String, Codable, CaseIterable {
    case prayer
    case meal
    case rest
}

enum RecurrencePattern: String, Codable, CaseIterable {
    case daily
    case weekdays
    case weekends
    case custom
}

struct Break: Codable, Identifiable {
    let id: String
    let userId: String?
    let type: BreakType
    let name: String
    let scheduledTime: String?
    let isRecurring: Bool?
    let recurrencePattern: RecurrencePattern?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, name
        case userId = "user_id"
        case scheduledTime = "scheduled_time"
        case isRecurring = "is_recurring"
        case recurrencePattern = "recurrence_pattern"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateBreakRequest: Codable {
    let type: BreakType
    let name: String
    var scheduledTime: String?
    var isRecurring: Bool?
    var recurrencePattern: RecurrencePattern?
}

struct UpdateBreakRequest: Codable {
    var type: BreakType?
    var name: String?
    var scheduledTime: String?
    var isRecurring: Bool?
    var recurrencePattern: RecurrencePattern?
}

struct BreakHistory: Codable, Identifiable {
    let id: String
    let breakId: String?
    let userId: String?
    let startedAt: Date?
    let endedAt: Date?
    let durationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case breakId = "break_id"
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
    }
}

struct BreakHistoryWithBreak: Codable {
    let history: BreakHistory
    let `break`: Break?
}

struct LogBreakRequest: Codable {
    var breakId: String?
    let startedAt: String
    var endedAt: String?
    var durationMinutes: Int?
}

// MARK: - AI / RAG

struct SearchRequest: Codable {
    let query: String
    var limit: Int?
    var type: String?
}

struct SearchResult: Codable, Identifiable {
    let id: String
    let score: Double
    let type: String
    let content: String
    let metadata: [String: AnyCodable]
}

struct SearchResponse: Codable {
    let results: [SearchResult]
}

struct AskRequest: Codable {
    let query: String
}

struct AskResponse: Codable {
    let answer: String
    let sources: [SearchResult]
}

struct PrioritizeRequest: Codable {
    var currentLocation: CurrentLocation?
}

struct CurrentLocation: Codable {
    let latitude: Double
    let longitude: Double
}

struct PrioritizeResponse: Codable {
    let tasks: [TaskItem]
}

// MARK: - Generic Responses

struct MessageResponse: Codable {
    let message: String
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - AnyCodable for flexible metadata

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}
