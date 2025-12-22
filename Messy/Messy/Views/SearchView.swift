//
//  SearchView.swift
//  Messy
//
//  Unified search view with AI chat capabilities
//

import SwiftUI
import AVFoundation

// MARK: - Helper Types

struct IdentifiableTask: Identifiable {
    let id: String
    let task: TaskItem
    
    init(task: TaskItem) {
        self.id = task.id
        self.task = task
    }
}

struct IdentifiableRecording: Identifiable {
    let id: String
    let recording: Recording
    
    init(recording: Recording) {
        self.id = recording.id
        self.recording = recording
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var sources: [SearchResult]?
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var askAIMode = false
    @State private var chatMessages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var selectedSourceTask: IdentifiableTask?
    @State private var selectedSourceRecording: IdentifiableRecording?
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider().opacity(0.3)
            
            // Content
            if askAIMode {
                chatView
            } else {
                searchResultsView
            }
            
            // Input bar (for AI chat mode)
            if askAIMode {
                chatInputBar
            }
        }
        .onChange(of: askAIMode) { _, newValue in
            // Clear results when switching modes
            appState.searchResults = []
            appState.aiAnswer = nil
            if !newValue {
                chatMessages = []
            }
        }
        .sheet(item: $selectedSourceTask) { identifiableTask in
            TaskDetailView(isPresented: Binding(
                get: { selectedSourceTask != nil },
                set: { if !$0 { selectedSourceTask = nil } }
            ), task: identifiableTask.task)
            .environmentObject(appState)
        }
        .sheet(item: $selectedSourceRecording) { identifiableRecording in
            RecordingDetailSheet(
                recording: identifiableRecording.recording,
                isPresented: Binding(
                    get: { selectedSourceRecording != nil },
                    set: { if !$0 { selectedSourceRecording = nil } }
                )
            )
            .environmentObject(appState)
        }
    }
    
    // MARK: - Source Tap Handler
    
    private func handleSourceTap(_ source: SearchResult) {
        // Handle tasks
        if source.type == "task" {
            // Try to find task by ID from metadata or by matching content
            if let taskId = source.metadata["taskId"]?.value as? String,
               let task = appState.tasks.first(where: { $0.id == taskId }) {
                selectedSourceTask = IdentifiableTask(task: task)
            } else if let task = appState.tasks.first(where: { $0.title == source.content || $0.id == source.id }) {
                selectedSourceTask = IdentifiableTask(task: task)
            } else {
                // Fallback: try to match by content similarity
                if let task = appState.tasks.first(where: { source.content.contains($0.title) || $0.title.contains(source.content) }) {
                    selectedSourceTask = IdentifiableTask(task: task)
                }
            }
        }
        // Handle recordings
        else if source.type == "recording" {
            // Try to find recording by ID from metadata or by matching content
            if let recordingId = source.metadata["recordingId"]?.value as? String,
               let recording = appState.recordings.first(where: { $0.id == recordingId }) {
                selectedSourceRecording = IdentifiableRecording(recording: recording)
            } else if let recording = appState.recordings.first(where: { $0.id == source.id }) {
                selectedSourceRecording = IdentifiableRecording(recording: recording)
            } else {
                // Fallback: try to match by title or transcript
                if let recording = appState.recordings.first(where: { 
                    ($0.title != nil && source.content.contains($0.title!)) ||
                    ($0.transcript != nil && source.content.contains($0.transcript!.prefix(50)))
                }) {
                    selectedSourceRecording = IdentifiableRecording(recording: recording)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text(askAIMode ? "Chat with AI" : "Search")
                .messyFont(.largeTitle)
                .contentTransition(.numericText())
                .animation(.snappy, value: askAIMode)
            
            Spacer()
            
            // Mode Toggle
            Picker("", selection: $askAIMode) {
                Image(systemName: "magnifyingglass").tag(false)
                Image(systemName: "sparkles").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .padding(20)
    }
    
    // MARK: - Search Results View (Non-AI mode)
    
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            // Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                
                TextField("Search tasks, recordings...", text: $query)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }
                
                if !query.isEmpty {
                    Button {
                        query = ""
                        appState.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                GlassMorphicCard(cornerRadius: 14, opacity: 0.6) {
                    Color.clear
                }
            )
            .padding(20)
            
            // Results
            if appState.searchResults.isEmpty && query.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Search everything")
                        .messyFont(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.searchResults) { result in
                            SearchResultRow(result: result)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Chat View (AI mode)
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if chatMessages.isEmpty {
                        // Welcome state
                        VStack(spacing: 20) {
                            Spacer().frame(height: 40)
                            
                            ZStack {
                                Circle()
                                    .fill(Color.messyBrand.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.orange)
                            }
                            
                            Text("Ask me anything")
                                .messyFont(.title)
                            
                            Text("I can help you find tasks, summarize meetings,\nand answer questions about your data.")
                                .messyFont(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            // Suggested prompts
                            VStack(spacing: 10) {
                                SuggestedPromptButton(text: "What are my urgent tasks?") {
                                    sendMessage("What are my urgent tasks?")
                                }
                                SuggestedPromptButton(text: "Summarize my recent meetings") {
                                    sendMessage("Summarize my recent meetings")
                                }
                                SuggestedPromptButton(text: "What did I record this week?") {
                                    sendMessage("What did I record this week?")
                                }
                            }
                            .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                    } else {
                        // Chat messages
                        ForEach(chatMessages) { message in
                            ChatBubbleView(message: message) { source in
                                handleSourceTap(source)
                            }
                            .id(message.id)
                        }
                        
                        // Typing indicator
                        if isTyping {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .id("typing")
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: chatMessages.count) { _, _ in
                if let lastMessage = chatMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isTyping) { _, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Chat Input Bar
    
    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask a question...", text: $query)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .onSubmit {
                    if !query.isEmpty {
                        sendMessage(query)
                    }
                }
            
            Button {
                if !query.isEmpty {
                    sendMessage(query)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(query.isEmpty ? .secondary : Color.messyBrand)
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty || isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            GlassMorphicCard(cornerRadius: 24, opacity: 0.8) {
                Color.clear
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !query.isEmpty else { return }
        Task {
            await appState.search(query: query)
        }
    }
    
    private func sendMessage(_ text: String) {
        let userMessage = ChatMessage(
            content: text,
            isUser: true,
            timestamp: Date()
        )
        chatMessages.append(userMessage)
        query = ""
        isTyping = true
        
        Task {
            await appState.askAI(query: text)
            
            await MainActor.run {
                isTyping = false
                
                if let answer = appState.aiAnswer {
                    let aiMessage = ChatMessage(
                        content: answer,
                        isUser: false,
                        timestamp: Date(),
                        sources: appState.searchResults.isEmpty ? nil : appState.searchResults
                    )
                    chatMessages.append(aiMessage)
                }
            }
        }
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: ChatMessage
    var onSourceTap: ((SearchResult) -> Void)?
    @State private var isExpanded = false
    @State private var hoveredSourceId: String?
    
    init(message: ChatMessage, onSourceTap: ((SearchResult) -> Void)? = nil) {
        self.message = message
        self.onSourceTap = onSourceTap
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(Color.messyBrand.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message bubble
                Text(message.content)
                    .messyFont(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? Color.messyBrand : Color(nsColor: .controlBackgroundColor))
                    )
                    .foregroundStyle(message.isUser ? .white : .primary)
                
                // Sources (for AI messages)
                if let sources = message.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                Text("\(sources.count) sources")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        if isExpanded {
                            VStack(spacing: 6) {
                                ForEach(sources.prefix(5)) { source in
                                    Button {
                                        onSourceTap?(source)
                                    } label: {
                                        HStack(spacing: 8) {
                                            sourceIcon(for: source.type)
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.messyBrand)
                                                .frame(width: 24, height: 24)
                                                .background(Color.messyBrand.opacity(0.1))
                                                .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(source.content)
                                                    .lineLimit(1)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.primary)
                                                
                                                Text(source.type.capitalized)
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            
                                            Spacer()
                                            
                                            if source.type == "task" {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(hoveredSourceId == source.id ? Color.messyBrand.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        hoveredSourceId = hovering ? source.id : nil
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.leading, 4)
                }
                
                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func sourceIcon(for type: String) -> Image {
        switch type {
        case "task": return Image(systemName: "checkmark.circle")
        case "recording": return Image(systemName: "waveform")
        case "meeting": return Image(systemName: "person.2")
        default: return Image(systemName: "doc")
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotScale: [CGFloat] = [1, 1, 1]
    
    var body: some View {
        HStack(spacing: 12) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(Color.messyBrand.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }
            
            // Dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScale[index])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .onAppear {
                animateDots()
            }
        }
    }
    
    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotScale[i] = 1.3
            }
        }
    }
}

// MARK: - Suggested Prompt Button

struct SuggestedPromptButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "sparkle")
                    .font(.caption)
                Text(text)
                    .font(.system(size: 13))
            }
            .foregroundStyle(Color.messyBrand)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.messyBrand.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.messyBrand.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Search Result Row (unchanged but simplified)

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        GlassMorphicCard(cornerRadius: 12, opacity: 0.4) {
            HStack(alignment: .top, spacing: 12) {
                iconForType(result.type)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.messyBrand)
                    .frame(width: 32, height: 32)
                    .background(Color.messyBrand.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.content)
                        .lineLimit(2)
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack {
                        Text(result.type.capitalized)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                        
                        Text("Score: \(Int(result.score * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
        }
    }
    
    private func iconForType(_ type: String) -> Image {
        switch type {
        case "task": return Image(systemName: "checkmark.circle")
        case "recording": return Image(systemName: "waveform")
        case "meeting": return Image(systemName: "person.2.fill")
        default: return Image(systemName: "doc")
        }
    }
}

// MARK: - Recording Detail Sheet

struct RecordingDetailSheet: View {
    @EnvironmentObject var appState: AppState
    let recording: Recording
    @Binding var isPresented: Bool
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var presignedUrl: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    audioPlayer.stop()
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Recording")
                    .messyFont(.headline)
                
                Spacer()
                
                // Placeholder for symmetry
                Text("Close").opacity(0)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Recording info card
                    VStack(spacing: 16) {
                        // Play button
                        Button {
                            Task {
                                if audioPlayer.isPlaying {
                                    audioPlayer.pause()
                                } else {
                                    await playAudio()
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.messyBrand)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Color.messyBrand.opacity(0.4), radius: 10, y: 5)
                                
                                if audioPlayer.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(recording.audioUrl == nil)
                        
                        // Title
                        Text(recording.title ?? "Recording")
                            .messyFont(.headline)
                        
                        // Progress
                        if audioPlayer.duration > 0 {
                            VStack(spacing: 8) {
                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(height: 6)
                                        
                                        Capsule()
                                            .fill(Color.messyBrand)
                                            .frame(width: geo.size.width * (audioPlayer.currentTime / audioPlayer.duration), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                
                                // Time labels
                                HStack {
                                    Text(formatDuration(Int(audioPlayer.currentTime)))
                                        .monospacedDigit()
                                    Spacer()
                                    Text(formatDuration(Int(audioPlayer.duration)))
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            Text(formatDuration(recording.durationSeconds ?? 0))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Date
                        if let date = recording.createdAt {
                            Text(date.formatted(date: .long, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        GlassMorphicCard(cornerRadius: 16, opacity: 0.5) { Color.clear }
                    )
                    
                    // Transcript
                    if let transcript = recording.transcript, !transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.quote")
                                    .foregroundStyle(Color.messyBrand)
                                Text("Transcript")
                                    .messyFont(.headline)
                            }
                            
                            Text(transcript)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary.opacity(0.9))
                                .textSelection(.enabled)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            GlassMorphicCard(cornerRadius: 16, opacity: 0.5) { Color.clear }
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.title)
                                .foregroundStyle(.tertiary)
                            Text("No transcript available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(
                            GlassMorphicCard(cornerRadius: 16, opacity: 0.3) { Color.clear }
                        )
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func playAudio() async {
        // If we already have a presigned URL and player is just paused, resume
        if let url = presignedUrl, audioPlayer.currentTime > 0 {
            audioPlayer.play(url: url)
            return
        }
        
        // Fetch presigned URL from backend
        audioPlayer.isLoading = true
        do {
            let response = try await APIClient.shared.getAudioUrl(recordingId: recording.id)
            if let url = URL(string: response.url) {
                presignedUrl = url
                audioPlayer.play(url: url)
            }
        } catch {
            print("Failed to get audio URL: \(error)")
            audioPlayer.isLoading = false
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
