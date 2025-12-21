//
//  TaskDetailView.swift
//  Messy
//
//  Task detail and edit view
//

import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let task: TaskItem

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var showDatePicker = false
    @State private var hasChanges = false

    init(isPresented: Binding<Bool>, task: TaskItem) {
        self._isPresented = isPresented
        self.task = task

        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes ?? "")
        _priority = State(initialValue: task.priority ?? .none)
        _tags = State(initialValue: task.tags ?? [])

        if let dueDateStr = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _dueDate = State(initialValue: formatter.date(from: String(dueDateStr.prefix(10))))
            _hasDueDate = State(initialValue: true)
        } else {
            _dueDate = State(initialValue: nil)
            _hasDueDate = State(initialValue: false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    titleSection

                    // Notes
                    notesSection

                    // Priority
                    prioritySection

                    // Due Date
                    dueDateSection

                    // Tags
                    tagsSection

                    // Danger Zone
                    dangerZone
                }
                .padding(20)
            }
        }
        .frame(width: 350, height: 500)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Task Details")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Button {
                saveChanges()
            } label: {
                Text("Save")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasChanges ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Title")

            TextField("Task title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.textBackgroundColor))
                )
                .onChange(of: title) { _, _ in hasChanges = true }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Notes")

            TextEditor(text: $notes)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.textBackgroundColor))
                )
                .onChange(of: notes) { _, _ in hasChanges = true }
        }
    }

    // MARK: - Priority Section

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Priority")

            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    priorityButton(p)
                }
            }
        }
    }

    private func priorityButton(_ p: TaskPriority) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                priority = p
                hasChanges = true
            }
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(priorityColor(p))
                    .frame(width: priority == p ? 12 : 8, height: priority == p ? 12 : 8)

                Text(p == .none ? "None" : p.rawValue.capitalized)
                    .font(.system(size: 10, weight: priority == p ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(priority == p ? priorityColor(p).opacity(0.15) : Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(priority == p ? priorityColor(p).opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    // MARK: - Due Date Section

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("Due Date")

                Spacer()

                Toggle("", isOn: $hasDueDate)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .onChange(of: hasDueDate) { _, newValue in
                        hasChanges = true
                        if newValue && dueDate == nil {
                            dueDate = Date()
                        }
                    }
            }

            if hasDueDate {
                HStack(spacing: 12) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0; hasChanges = true }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()

                    // Quick date buttons
                    quickDateButton("Today") {
                        dueDate = Date()
                        hasChanges = true
                    }

                    quickDateButton("Tomorrow") {
                        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                        hasChanges = true
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasDueDate)
    }

    private func quickDateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(.controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Tags")

            // Existing tags
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }

                // Add tag button
                addTagButton
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.system(size: 12, weight: .medium))

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    tags.removeAll { $0 == tag }
                    hasChanges = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.08))
        )
    }

    private var addTagButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .semibold))

            TextField("Add tag", text: $newTag)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 60)
                .onSubmit {
                    addTag()
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !tags.contains(tag) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tags.append(tag)
            newTag = ""
            hasChanges = true
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            Button {
                Task {
                    await appState.deleteTask(task)
                    isPresented = false
                }
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Task")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func saveChanges() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dueDateString: String? = hasDueDate ? (dueDate.map { formatter.string(from: $0) }) : nil

        Task {
            await appState.updateTask(
                task,
                title: title,
                notes: notes.isEmpty ? nil : notes,
                priority: priority,
                dueDate: dueDateString,
                tags: tags.isEmpty ? nil : tags
            )
            isPresented = false
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

#Preview {
    let task = TaskItem(
        id: "1",
        userId: "1",
        orgId: "1",
        title: "Test task",
        notes: "Some notes",
        priority: .high,
        dueDate: "2024-12-20",
        dueTime: nil,
        tags: ["work", "urgent"],
        locationContext: nil,
        isCompleted: false,
        completedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    )

    TaskDetailView(isPresented: .constant(true), task: task)
        .environmentObject(AppState.shared)
}
