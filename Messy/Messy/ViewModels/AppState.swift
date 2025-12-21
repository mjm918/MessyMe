//
//  AppState.swift
//  Messy
//
//  Central app state management
//

import SwiftUI
import Combine

// MARK: - Navigation

enum NavigationTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case all = "All Tasks"
    case upcoming = "Upcoming"
    case overdue = "Overdue"
    case recordings = "Recordings"
    case search = "Search"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .all: return "tray.full"
        case .upcoming: return "calendar"
        case .overdue: return "exclamationmark.circle"
        case .recordings: return "waveform"
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        }
    }

    var color: Color {
        switch self {
        case .today: return .orange
        case .all: return .blue
        case .upcoming: return .purple
        case .overdue: return .red
        case .recordings: return .green
        case .search: return .gray
        case .settings: return .gray
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Navigation
    @Published var selectedTab: NavigationTab = .today
    @Published var selectedTask: TaskItem?
    @Published var isShowingTaskDetail = false
    @Published var isShowingNewTask = false

    // MARK: - User & Org
    @Published var currentUser: User?
    @Published var currentOrg: Organization?
    @Published var isAuthenticated = false
    @Published var isLoading = false

    // MARK: - Tasks
    @Published var tasks: [TaskItem] = []
    @Published var filteredTasks: [TaskItem] = []

    // MARK: - Recordings
    @Published var recordings: [Recording] = []
    @Published var isRecording = false

    // MARK: - Search
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []

    // MARK: - Breaks
    @Published var breaks: [Break] = []
    @Published var breakHistory: [BreakHistoryWithBreak] = []

    // MARK: - Locations
    @Published var locations: [Location] = []

    // MARK: - Error Handling
    @Published var errorMessage: String?
    @Published var showError = false

    private var cancellables = Set<AnyCancellable>()
    private let api = APIClient.shared

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        // Filter tasks when tab changes
        $selectedTab
            .combineLatest($tasks)
            .map { tab, tasks in
                self.filterTasks(tasks, for: tab)
            }
            .assign(to: &$filteredTasks)
    }

    private func filterTasks(_ tasks: [TaskItem], for tab: NavigationTab) -> [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let todayString = ISO8601DateFormatter().string(from: today).prefix(10)

        switch tab {
        case .today:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate.hasPrefix(String(todayString)) && !task.isCompleted
            }
        case .all:
            return tasks.filter { !$0.isCompleted }
        case .upcoming:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate > String(todayString) && !task.isCompleted
            }
        case .overdue:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < String(todayString) && !task.isCompleted
            }
        default:
            return tasks
        }
    }

    // MARK: - Authentication

    func login(email: String) async {
        isLoading = true
        defer { isLoading = false }

        print("[AppState] Starting login for: \(email)")

        do {
            let user = try await api.createOrGetUser(email: email)
            print("[AppState] Got user: \(user.id)")
            currentUser = user
            isAuthenticated = true

            // Get user's orgs
            let memberships = try await api.getUserOrganizations(userId: user.id)
            print("[AppState] User has \(memberships.count) organizations")
            if let firstOrg = memberships.first?.org {
                currentOrg = firstOrg
                print("[AppState] Set current org: \(firstOrg.name)")
                await loadData()
            } else {
                print("[AppState] No organizations - showing org setup")
            }
        } catch {
            print("[AppState] Login error: \(error)")
            showError(error)
        }
    }

    func createOrganization(name: String) async {
        guard let user = currentUser else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let org = try await api.createOrganization(name: name, adminEmail: user.email)
            currentOrg = org
            await loadData()
        } catch {
            showError(error)
        }
    }

    func joinOrganization(inviteCode: String) async {
        guard let user = currentUser else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.joinOrganization(inviteCode: inviteCode, email: user.email)
            currentOrg = response.org
            await loadData()
        } catch {
            showError(error)
        }
    }

    // MARK: - Load Data

    func loadData() async {
        guard let user = currentUser, let org = currentOrg else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTasks() }
            group.addTask { await self.loadRecordings() }
            group.addTask { await self.loadBreaks() }
            group.addTask { await self.loadLocations() }
        }
    }

    func loadTasks() async {
        guard let user = currentUser, let org = currentOrg else { return }

        do {
            tasks = try await api.getTasks(userId: user.id, orgId: org.id)
        } catch {
            showError(error)
        }
    }

    func loadRecordings() async {
        guard let org = currentOrg else { return }

        do {
            recordings = try await api.getRecordings(orgId: org.id)
        } catch {
            showError(error)
        }
    }

    func loadBreaks() async {
        guard let user = currentUser else { return }

        do {
            breaks = try await api.getBreaks(userId: user.id)
            breakHistory = try await api.getBreakHistory(userId: user.id)
        } catch {
            showError(error)
        }
    }

    func loadLocations() async {
        guard let user = currentUser else { return }

        do {
            locations = try await api.getLocations(userId: user.id)
        } catch {
            showError(error)
        }
    }

    // MARK: - Task Operations

    func createTask(title: String, notes: String? = nil, priority: TaskPriority? = nil, dueDate: String? = nil, tags: [String]? = nil) async {
        guard let user = currentUser, let org = currentOrg else { return }

        do {
            let task = try await api.createTask(
                userId: user.id,
                orgId: org.id,
                title: title,
                notes: notes,
                priority: priority,
                dueDate: dueDate,
                tags: tags
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                tasks.insert(task, at: 0)
            }
        } catch {
            showError(error)
        }
    }

    func updateTask(_ task: TaskItem, title: String? = nil, notes: String? = nil, priority: TaskPriority? = nil, dueDate: String? = nil, tags: [String]? = nil) async {
        do {
            let updated = try await api.updateTask(
                id: task.id,
                title: title,
                notes: notes,
                priority: priority,
                dueDate: dueDate,
                tags: tags
            )
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    tasks[index] = updated
                }
            }
        } catch {
            showError(error)
        }
    }

    func toggleTaskCompletion(_ task: TaskItem) async {
        do {
            let updated: TaskItem
            if task.isCompleted {
                updated = try await api.uncompleteTask(id: task.id)
            } else {
                updated = try await api.completeTask(id: task.id)
            }

            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    tasks[index] = updated
                }
            }
        } catch {
            showError(error)
        }
    }

    func deleteTask(_ task: TaskItem) async {
        do {
            _ = try await api.deleteTask(id: task.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tasks.removeAll { $0.id == task.id }
            }
        } catch {
            showError(error)
        }
    }

    // MARK: - Recording Operations

    func createRecording(type: RecordingType, title: String?, transcript: String?, duration: Int?) async {
        guard let user = currentUser, let org = currentOrg else { return }

        do {
            let recording = try await api.createRecording(
                orgId: org.id,
                userId: user.id,
                type: type,
                title: title,
                transcript: transcript,
                durationSeconds: duration
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                recordings.insert(recording, at: 0)
            }
        } catch {
            showError(error)
        }
    }

    func deleteRecording(_ recording: Recording) async {
        do {
            _ = try await api.deleteRecording(id: recording.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                recordings.removeAll { $0.id == recording.id }
            }
        } catch {
            showError(error)
        }
    }

    // MARK: - Search

    func search(query: String) async {
        guard let org = currentOrg, !query.isEmpty else {
            searchResults = []
            return
        }

        do {
            let response = try await api.searchKnowledgeBase(orgId: org.id, query: query)
            withAnimation(.easeInOut(duration: 0.2)) {
                searchResults = response.results
            }
        } catch {
            showError(error)
        }
    }

    // MARK: - AI Prioritization

    func prioritizeTasks(latitude: Double? = nil, longitude: Double? = nil) async {
        guard let user = currentUser, let org = currentOrg else { return }

        do {
            let response: PrioritizeResponse
            if let lat = latitude, let lon = longitude {
                response = try await api.prioritizeTasks(userId: user.id, orgId: org.id, latitude: lat, longitude: lon)
            } else {
                response = try await api.prioritizeTasks(userId: user.id, orgId: org.id)
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                tasks = response.tasks
            }
        } catch {
            showError(error)
        }
    }

    // MARK: - Error Handling

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showError = false
            }
        }
    }
}
