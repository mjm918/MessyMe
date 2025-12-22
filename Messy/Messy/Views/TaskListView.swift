//
//  TaskListView.swift
//  Messy
//
//  Task list view with Apple-style animations and glassmorphism
//

import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var appState: AppState
    let filter: NavigationTab

    @State private var newTaskTitle = ""
    @State private var isInputFocused = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider().opacity(0.3)

            // Quick add
            quickAddView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Task list
            if appState.filteredTasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .onAppear {
            Task { await appState.loadTasks() }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.rawValue)
                    .messyFont(.largeTitle)
                    .foregroundStyle(.primary)

                Text(taskCountText)
                    .messyFont(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // AI Prioritize button
            Button {
                Task { await appState.prioritizeTasks() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Prioritize")
                }
                .messyFont(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.messyBrand.opacity(0.1))
                        .overlay(Capsule().stroke(Color.messyBrand.opacity(0.3), lineWidth: 1))
                )
                .foregroundStyle(Color.messyBrand)
            }
            .buttonStyle(BouncyButtonStyle())
        }
        .padding(16)
    }

    private var taskCountText: String {
        let count = appState.filteredTasks.count
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    // MARK: - Quick Add

    private var quickAddView: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(isInputFocused ? Color.messyBrand : .secondary)

            TextField("Add a task...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($inputFocused)
                .onSubmit { addTask() }
                .onChange(of: inputFocused) { _, focused in
                    withAnimation { isInputFocused = focused }
                }

            if !newTaskTitle.isEmpty {
                Button { addTask() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.messyBrand)
                }
                .buttonStyle(BouncyButtonStyle())
                .transition(.scale)
            }
        }
        .padding(12)
        .background(
            GlassMorphicCard(cornerRadius: 12) { Color.clear }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isInputFocused ? Color.messyBrand.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }

    private func addTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let title = newTaskTitle
        newTaskTitle = ""
        Task {
            let tags = extractTags(from: title)
            let cleanTitle = removeTagsFromTitle(title)
            // Auto-due date if in Today view
            let dueDate: String? = filter == .today ? ISO8601DateFormatter().string(from: Date()) : nil
            await appState.createTask(title: cleanTitle, dueDate: dueDate, tags: tags.isEmpty ? nil : tags)
        }
    }
    
    private func extractTags(from title: String) -> [String] {
        let pattern = "#(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(title.startIndex..., in: title)
        return regex.matches(in: title, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: title) else { return nil }
            return String(title[r])
        }
    }

    private func removeTagsFromTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "#\\w+\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(appState.filteredTasks) { task in
                    TaskRowView(task: task)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State (Clean)

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No tasks found")
                .messyFont(.headline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var appState: AppState
    let task: TaskItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                Task { await appState.toggleTaskCompletion(task) }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? Color.messyBrand : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                
                if hasMetadata {
                    HStack(spacing: 8) {
                        if let priority = task.priority, priority != .none {
                            Constants.badge(text: priority.rawValue.capitalized, color: priorityColor(priority))
                        }
                        if let count = task.tags?.count, count > 0 {
                            Constants.badge(text: "#tags", color: .secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Hover Actions
            if isHovered {
                HStack {
                    Button {
                         appState.selectedTask = task
                         appState.isShowingTaskDetail = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await appState.deleteTask(task) }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            GlassMorphicCard(cornerRadius: 12, opacity: isHovered ? 0.8 : 0.5) { Color.clear }
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            appState.selectedTask = task
            appState.isShowingTaskDetail = true
        }
    }
    
    var hasMetadata: Bool {
        (task.priority != nil && task.priority != .none) || (task.tags != nil && !task.tags!.isEmpty)
    }

    func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        default: return .gray
        }
    }
}

// Helper for badges
struct Constants {
    static func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.1)))
    }
}
