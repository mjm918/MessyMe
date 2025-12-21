//
//  TaskListView.swift
//  Messy
//
//  Task list view with filtering and animations
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

            Divider()
                .padding(.horizontal)

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
            Task {
                await appState.loadTasks()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text(taskCountText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // AI Prioritize button
            Button {
                Task {
                    await appState.prioritizeTasks()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("Prioritize")
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.1))
                )
                .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
            .help("AI-powered task prioritization")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var taskCountText: String {
        let count = appState.filteredTasks.count
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    // MARK: - Quick Add

    private var quickAddView: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(isInputFocused ? .primary : .secondary)
                .symbolEffect(.bounce, value: isInputFocused)

            TextField("Add a task...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($inputFocused)
                .onSubmit {
                    addTask()
                }
                .onChange(of: inputFocused) { _, focused in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isInputFocused = focused
                    }
                }

            if !newTaskTitle.isEmpty {
                Button {
                    addTask()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isInputFocused ? Color.primary.opacity(0.2) : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: newTaskTitle.isEmpty)
    }

    private func addTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let title = newTaskTitle
        newTaskTitle = ""

        Task {
            // Extract tags from title
            let tags = extractTags(from: title)
            let cleanTitle = removeTagsFromTitle(title)

            // Set due date if today filter
            let dueDate: String? = filter == .today ? todayDateString : nil

            await appState.createTask(
                title: cleanTitle,
                dueDate: dueDate,
                tags: tags.isEmpty ? nil : tags
            )
        }
    }

    private func extractTags(from title: String) -> [String] {
        let pattern = "#(\\w+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(title.startIndex..., in: title)
        let matches = regex.matches(in: title, range: range)

        return matches.compactMap { match -> String? in
            guard let tagRange = Range(match.range(at: 1), in: title) else { return nil }
            return String(title[tagRange])
        }
    }

    private func removeTagsFromTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "#\\w+\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(appState.filteredTasks.enumerated()), id: \.element.id) { index, task in
                    TaskRowView(task: task)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.03), value: task.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 80, height: 80)

                Image(systemName: emptyStateIcon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
            }

            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .semibold))

            Text(emptyStateSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var emptyStateIcon: String {
        switch filter {
        case .today: return "sun.max"
        case .all: return "tray"
        case .upcoming: return "calendar"
        case .overdue: return "checkmark.circle"
        default: return "tray"
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .today: return "No tasks for today"
        case .all: return "All caught up!"
        case .upcoming: return "Nothing upcoming"
        case .overdue: return "No overdue tasks"
        default: return "No tasks"
        }
    }

    private var emptyStateSubtitle: String {
        switch filter {
        case .today: return "Add a task above to get started with your day"
        case .all: return "You've completed all your tasks. Time to celebrate!"
        case .upcoming: return "Schedule some tasks for the future"
        case .overdue: return "Great job staying on top of your tasks!"
        default: return "Add your first task to get started"
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var appState: AppState
    let task: TaskItem

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showConfetti = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            checkboxView

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Priority
                    if let priority = task.priority, priority != .none {
                        priorityBadge(priority)
                    }

                    // Due date
                    if let dueDate = task.dueDate {
                        dueDateBadge(dueDate)
                    }

                    // Tags
                    if let tags = task.tags, !tags.isEmpty {
                        ForEach(tags.prefix(2), id: \.self) { tag in
                            tagBadge(tag)
                        }
                    }
                }
            }

            Spacer()

            // Actions
            if isHovered {
                HStack(spacing: 4) {
                    actionButton(icon: "pencil") {
                        appState.selectedTask = task
                        appState.isShowingTaskDetail = true
                    }

                    actionButton(icon: "trash", color: .red) {
                        Task {
                            await appState.deleteTask(task)
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 6 : 3, y: isHovered ? 3 : 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            appState.selectedTask = task
            appState.isShowingTaskDetail = true
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .overlay(alignment: .topTrailing) {
            if showConfetti {
                ConfettiView()
                    .offset(x: -20, y: 10)
            }
        }
    }

    // MARK: - Checkbox

    private var checkboxView: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if !task.isCompleted {
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showConfetti = false
                    }
                }
            }
            Task {
                await appState.toggleTaskCompletion(task)
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? Color.green : Color.secondary.opacity(0.5), lineWidth: 2)
                    .frame(width: 22, height: 22)

                if task.isCompleted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 22, height: 22)

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce, value: task.isCompleted)
    }

    // MARK: - Badges

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(priorityColor(priority))
                .frame(width: 6, height: 6)

            Text(priority.rawValue.capitalized)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(priorityColor(priority))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(priorityColor(priority).opacity(0.1))
        )
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .none: return .gray
        }
    }

    private func dueDateBadge(_ dueDate: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 9))

            Text(formatDueDate(dueDate))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(dueDateColor(dueDate))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(dueDateColor(dueDate).opacity(0.1))
        )
    }

    private func formatDueDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: String(dateString.prefix(10))) else {
            return dateString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func dueDateColor(_ dateString: String) -> Color {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: String(dateString.prefix(10))) else {
            return .secondary
        }

        let today = Calendar.current.startOfDay(for: Date())
        if date < today {
            return .red
        } else if Calendar.current.isDateInToday(date) {
            return .orange
        }
        return .secondary
    }

    private func tagBadge(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
    }

    // MARK: - Action Button

    private func actionButton(icon: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var animate = false

    let colors: [Color] = [.red, .green, .blue, .orange, .purple, .yellow]

    var body: some View {
        ZStack {
            ForEach(0..<12) { i in
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: 6, height: 6)
                    .offset(
                        x: animate ? CGFloat.random(in: -30...30) : 0,
                        y: animate ? CGFloat.random(in: -40...10) : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.6)
                        .delay(Double(i) * 0.02),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    TaskListView(filter: .today)
        .environmentObject(AppState.shared)
        .frame(width: 350, height: 500)
}
