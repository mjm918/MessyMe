//
//  TaskDetailView.swift
//  Messy
//
//  Task detail and edit view using standard Apple Form style
//

import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let task: TaskItem

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var locationContext: LocationContext
    
    @State private var hasChanges = false
    @State private var showDeleteConfirmation = false

    init(isPresented: Binding<Bool>, task: TaskItem) {
        self._isPresented = isPresented
        self.task = task
        
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes ?? "")
        _priority = State(initialValue: task.priority ?? .none)
        _tags = State(initialValue: task.tags ?? [])
        _locationContext = State(initialValue: task.locationContext ?? .none)

        if let dueDateStr = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: String(dueDateStr.prefix(10))) {
                _dueDate = State(initialValue: date)
                _hasDueDate = State(initialValue: true)
            } else {
                _dueDate = State(initialValue: Date())
                _hasDueDate = State(initialValue: false)
            }
        } else {
            _dueDate = State(initialValue: Date())
            _hasDueDate = State(initialValue: false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // macOS-style toolbar header
            HStack {
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Edit Task")
                    .messyFont(.headline)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Save") {
                        saveChanges()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.messyBrand)
                    .disabled(!hasChanges)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Form content
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(.headline)
                        .onChange(of: title) { _, _ in hasChanges = true }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .environment(\.layoutDirection, .leftToRight)
                        .onChange(of: notes) { _, _ in hasChanges = true }
                } header: {
                    Text("Task Info")
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(TaskPriority.none)
                        Text("Low").tag(TaskPriority.low)
                        Text("Medium").tag(TaskPriority.medium)
                        Text("High").tag(TaskPriority.high)
                        Text("Urgent").tag(TaskPriority.urgent)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: priority) { _, _ in hasChanges = true }
                    
                    Toggle("Due Date", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { _, _ in hasChanges = true }
                    
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                            .onChange(of: dueDate) { _, _ in hasChanges = true }
                    }
                    
                    Picker("Location", selection: $locationContext) {
                        Text("None").tag(LocationContext.none)
                        Text("Home").tag(LocationContext.home)
                        Text("Work").tag(LocationContext.work)
                    }
                    .onChange(of: locationContext) { _, _ in hasChanges = true }
                } header: {
                    Text("Details")
                }

                Section {
                    // Selected tags as chips
                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(tag: tag, isSelected: true) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        tags.removeAll { $0 == tag }
                                        hasChanges = true
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Available tags to add
                    let unusedTags = appState.availableTags.filter { !tags.contains($0) }
                    if !unusedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(unusedTags, id: \.self) { tag in
                                    TagChip(tag: tag, isSelected: false) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            tags.append(tag)
                                            hasChanges = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Add new tag
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.secondary)
                        TextField("Create new tag...", text: $newTag)
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addTag()
                            }
                        if !newTag.isEmpty {
                            Text("Add")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.messyBrand)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .onTapGesture {
                                    addTag()
                                }
                        }
                    }
                } header: {
                    Text("Tags")
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Task")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog(
            "Delete Task",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await appState.deleteTask(task)
                    isPresented = false
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this task? This action cannot be undone.")
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        appState.addSavedTag(tag) // Also save to available tags
        newTag = ""
        hasChanges = true
    }
    
    private func saveChanges() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dueDateString = hasDueDate ? formatter.string(from: dueDate) : nil
        
        Task {
            await appState.updateTask(
                task,
                title: title,
                notes: notes,
                priority: priority,
                dueDate: dueDateString,
                tags: tags,
                locationContext: locationContext != .none ? locationContext : nil
            )
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("#\(tag)")
                    .font(.system(size: 12, weight: .medium))
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.messyBrand.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.messyBrand.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.messyBrand : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

