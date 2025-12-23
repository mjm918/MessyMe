//
//  AppState.swift
//  Messy
//
//  Central app state management
//

import SwiftUI
import Combine
import AuthenticationServices

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
    @Published var isUploadingRecording = false
    @Published var uploadProgress: Double = 0 // 0 to 1

    // MARK: - Search
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []
    @Published var aiAnswer: String?

    // MARK: - Breaks
    @Published var breaks: [Break] = []
    @Published var breakHistory: [BreakHistoryWithBreak] = []

    // MARK: - Locations
    @Published var locations: [Location] = []

    // MARK: - Tags
    @Published var savedTags: [String] = [] {
        didSet { saveTags() }
    }
    
    /// All unique tags from tasks + saved tags
    var availableTags: [String] {
        var allTags = Set(savedTags)
        for task in tasks {
            if let taskTags = task.tags {
                allTags.formUnion(taskTags)
            }
        }
        return allTags.sorted()
    }

    // MARK: - Error Handling
    @Published var errorMessage: String?
    @Published var showError = false

    private var cancellables = Set<AnyCancellable>()
    private let api = APIClient.shared

    // MARK: - Persistence Keys
    private let userEmailKey = "messy_user_email"
    private let userIdKey = "messy_user_id"
    private let orgIdKey = "messy_org_id"
    private let savedTagsKey = "messy_saved_tags"

    private init() {
        setupBindings()
        restoreTags()
        restoreSession()
    }

    // MARK: - Session Persistence

    private func restoreSession() {
        guard let savedEmail = UserDefaults.standard.string(forKey: userEmailKey),
              let savedUserId = UserDefaults.standard.string(forKey: userIdKey) else {
            print("[AppState] No saved session found")
            return
        }

        print("[AppState] Restoring session for: \(savedEmail)")

        // Restore user and attempt to load data
        Task {
            await restoreUser(email: savedEmail, userId: savedUserId)
        }
    }

    private func restoreUser(email: String, userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get fresh user data
            let user = try await api.createOrGetUser(email: email)
            currentUser = user
            isAuthenticated = true

            // Restore org if saved
            if let savedOrgId = UserDefaults.standard.string(forKey: orgIdKey) {
                let memberships = try await api.getUserOrganizations(userId: user.id)
                if let org = memberships.first(where: { $0.org.id == savedOrgId })?.org {
                    currentOrg = org
                    await loadData()
                } else if let firstOrg = memberships.first?.org {
                    currentOrg = firstOrg
                    saveSession()
                    await loadData()
                }
            } else {
                let memberships = try await api.getUserOrganizations(userId: user.id)
                if let firstOrg = memberships.first?.org {
                    currentOrg = firstOrg
                    saveSession()
                    await loadData()
                }
            }

            print("[AppState] Session restored successfully")
        } catch {
            print("[AppState] Failed to restore session: \(error)")
            clearSession()
        }
    }

    private func saveSession() {
        guard let user = currentUser else { return }
        UserDefaults.standard.set(user.email, forKey: userEmailKey)
        UserDefaults.standard.set(user.id, forKey: userIdKey)
        if let org = currentOrg {
            UserDefaults.standard.set(org.id, forKey: orgIdKey)
        }
        print("[AppState] Session saved")
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: orgIdKey)
        print("[AppState] Session cleared")
    }
    
    // MARK: - Tag Persistence
    
    private func restoreTags() {
        if let tags = UserDefaults.standard.stringArray(forKey: savedTagsKey) {
            savedTags = tags
        }
    }
    
    private func saveTags() {
        UserDefaults.standard.set(savedTags, forKey: savedTagsKey)
    }
    
    func addSavedTag(_ tag: String) {
        let normalizedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !normalizedTag.isEmpty, !savedTags.contains(normalizedTag) else { return }
        savedTags.append(normalizedTag)
        savedTags.sort()
    }
    
    func removeSavedTag(_ tag: String) {
        savedTags.removeAll { $0 == tag }
    }

    func logout() {
        clearSession()
        currentUser = nil
        currentOrg = nil
        isAuthenticated = false
        tasks = []
        recordings = []
        breaks = []
        locations = []
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Debug
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let result: [TaskItem]
        switch tab {
        case .today:
            result = tasks.filter { task in
                guard let dueDateString = task.dueDate else { return false }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone.current 
                
                guard let taskDate = dateFormatter.date(from: String(dueDateString.prefix(10))) else {
                    return false
                }
                
                let isToday = calendar.isDate(taskDate, inSameDayAs: today)
                return isToday && !task.isCompleted
            }
        case .all:
            result = tasks.filter { !$0.isCompleted }
        case .upcoming:
            result = tasks.filter { task in
                guard let dueDateString = task.dueDate else { return false }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone.current
                
                guard let taskDate = dateFormatter.date(from: String(dueDateString.prefix(10))) else { return false }
                
                // Strictly greater than today
                return taskDate > today && !calendar.isDate(taskDate, inSameDayAs: today) && !task.isCompleted
            }
        case .overdue:
            result = tasks.filter { task in
                guard let dueDateString = task.dueDate else { return false }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone.current
                
                guard let taskDate = dateFormatter.date(from: String(dueDateString.prefix(10))) else { return false }
                
                return taskDate < today && !task.isCompleted
            }
        default:
            result = tasks
        }
        
        return result
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
                saveSession()
                await loadData()
            } else {
                print("[AppState] No organizations - showing org setup")
                saveSession()
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
            saveSession()
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
            saveSession()
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

    func updateTask(_ task: TaskItem, title: String? = nil, notes: String? = nil, priority: TaskPriority? = nil, dueDate: String? = nil, tags: [String]? = nil, locationContext: LocationContext? = nil) async {
        do {
            let updated = try await api.updateTask(
                id: task.id,
                title: title,
                notes: notes,
                priority: priority,
                dueDate: dueDate,
                tags: tags,
                locationContext: locationContext
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

    func askAI(query: String) async {
        guard let org = currentOrg, !query.isEmpty else { return }
        isLoading = true // Reuse global loading or use specific state?
        // Better to use local state in view, but since asking is significant, global loading is fine or we add isAskingAI
        
        do {
            // We can reuse searchResults to show sources
            let response = try await api.askAI(orgId: org.id, query: query)
            withAnimation(.easeInOut(duration: 0.3)) {
                // We'll store the answer in a new published property or use a callback.
                // Since AppState is centralized, let's add `aiAnswer` property.
                self.aiAnswer = response.answer
                self.searchResults = response.sources
            }
        } catch {
            showError(error)
        }
        isLoading = false
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

    func createRecording(type: RecordingType, title: String?, transcript: String?, audioUrl: String?, duration: Int?) async {
        guard let user = currentUser, let org = currentOrg else { return }

        do {
            let recording = try await api.createRecording(
                orgId: org.id,
                userId: user.id,
                type: type,
                title: title,
                transcript: transcript,
                audioUrl: audioUrl,
                durationSeconds: duration
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                recordings.insert(recording, at: 0)
            }
        } catch {
            showError(error)
        }
    }
    
    func uploadAndCreateRecording(type: RecordingType, title: String?, audioData: Data, filename: String, duration: Int?) async {
        guard let org = currentOrg, let user = currentUser else { return }
        
        isUploadingRecording = true
        uploadProgress = 0
        
        do {
            // 1. Get presigned upload URL from backend
            uploadProgress = 0.1
            let uploadInfo = try await api.getUploadUrl(orgId: org.id, ext: "m4a")
            
            // 2. Upload directly to S3 (bypasses server timeout)
            uploadProgress = 0.2
            try await api.uploadToS3(presignedUrl: uploadInfo.uploadUrl, audioData: audioData) { progress in
                Task { @MainActor in
                    // Map S3 upload progress to 0.2-0.8 range
                    self.uploadProgress = 0.2 + (progress * 0.6)
                }
            }
            
            // 3. Create recording and queue transcription job
            uploadProgress = 0.9
            let recording = try await api.createRecordingWithTranscription(
                orgId: org.id,
                userId: user.id,
                type: type,
                title: title,
                audioUrl: uploadInfo.audioUrl,
                durationSeconds: duration
            )
            
            uploadProgress = 1.0
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                recordings.insert(recording, at: 0)
            }
            
            // Brief delay to show completion
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            isUploadingRecording = false
            uploadProgress = 0
            
            // 4. Start polling for transcription completion
            startTranscriptionPolling(for: recording.id)
        } catch {
            isUploadingRecording = false
            uploadProgress = 0
            showError(error)
        }
    }
    
    /// Poll for transcription status and update recording when complete
    private func startTranscriptionPolling(for recordingId: String) {
        Task {
            var attempts = 0
            let maxAttempts = 60 // Max 5 minutes polling (5s intervals)
            
            while attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                attempts += 1
                
                do {
                    let status = try await api.getTranscriptionStatus(recordingId: recordingId)
                    
                    switch status.transcriptionStatus {
                    case .completed:
                        // Update the recording in our list with the transcript
                        if status.transcript != nil {
                            if let recording = try? await api.getRecording(id: recordingId) {
                                await MainActor.run {
                                    if let index = recordings.firstIndex(where: { $0.id == recordingId }) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            recordings[index] = recording
                                        }
                                    }
                                }
                            }
                        }
                        return // Done
                        
                    case .failed:
                        print("Transcription failed for \(recordingId): \(status.transcriptionError ?? "Unknown")")
                        return // Stop polling
                        
                    case .pending, .processing, .none:
                        continue // Keep polling
                    }
                } catch {
                    print("Error polling transcription status: \(error)")
                }
            }
            
            print("Transcription polling timed out for \(recordingId)")
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

    // MARK: - Location Operations

    func addLocation(name: String, type: LocationType?, address: String?, latitude: Double?, longitude: Double?) async {
        guard let user = currentUser else { return }

        do {
            let location = try await api.createLocation(
                userId: user.id,
                name: name,
                type: type,
                address: address,
                latitude: latitude,
                longitude: longitude
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                locations.append(location)
            }
        } catch {
            showError(error)
        }
    }

    func updateLocation(_ location: Location, name: String?, type: LocationType?, address: String?, latitude: Double?, longitude: Double?) async {
        do {
            let updated = try await api.updateLocation(
                id: location.id,
                name: name,
                type: type,
                address: address,
                latitude: latitude,
                longitude: longitude
            )
            if let index = locations.firstIndex(where: { $0.id == location.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    locations[index] = updated
                }
            }
        } catch {
            showError(error)
        }
    }

    func deleteLocation(_ location: Location) async {
        do {
            _ = try await api.deleteLocation(id: location.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                locations.removeAll { $0.id == location.id }
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
