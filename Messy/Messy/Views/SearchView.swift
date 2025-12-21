//
//  SearchView.swift
//  Messy
//
//  AI-powered knowledge base search
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var isSearching = false
    @State private var askAIMode = false
    @State private var aiResponse: String?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(.horizontal)

            // Search input
            searchInputView

            // Results
            if isSearching {
                loadingView
            } else if let response = aiResponse, askAIMode {
                aiResponseView(response)
            } else if !appState.searchResults.isEmpty {
                searchResultsView
            } else if !query.isEmpty {
                noResultsView
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Search")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Find tasks, recordings & meetings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mode toggle
            Picker("", selection: $askAIMode) {
                Image(systemName: "magnifyingglass").tag(false)
                Image(systemName: "sparkles").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .onChange(of: askAIMode) { _, _ in
                // Clear results when switching modes
                appState.searchResults = []
                aiResponse = nil
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Search Input

    private var searchInputView: some View {
        HStack(spacing: 10) {
            Image(systemName: askAIMode ? "sparkles" : "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(isInputFocused ? (askAIMode ? .purple : .blue) : .secondary)
                .symbolEffect(.bounce, value: isInputFocused)

            TextField(askAIMode ? "Ask AI anything..." : "Search knowledge base...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isInputFocused)
                .onSubmit {
                    performSearch()
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    appState.searchResults = []
                    aiResponse = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))

                Button {
                    performSearch()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(askAIMode ? .purple : .blue)
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
                        .stroke(
                            isInputFocused ? (askAIMode ? Color.purple.opacity(0.3) : Color.blue.opacity(0.3)) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: query.isEmpty)
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true

        Task {
            if askAIMode {
                await askAI()
            } else {
                await search()
            }
            isSearching = false
        }
    }

    private func search() async {
        await appState.search(query: query)
    }

    private func askAI() async {
        guard let org = appState.currentOrg else { return }

        do {
            let response = try await APIClient.shared.askAI(orgId: org.id, query: query)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                aiResponse = response.answer
                appState.searchResults = response.sources
            }
        } catch {
            aiResponse = "Sorry, I couldn't process your request. Please try again."
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)

            Text(askAIMode ? "AI is thinking..." : "Searching...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - AI Response View

    private func aiResponseView(_ response: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // AI Response card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.purple)

                        Text("AI Response")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.purple)
                    }

                    Text(response)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                )

                // Sources
                if !appState.searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sources")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(appState.searchResults) { result in
                            SearchResultRow(result: result, compact: true)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(appState.searchResults.enumerated()), id: \.element.id) { index, result in
                    SearchResultRow(result: result)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: result.id)
                }
            }
            .padding(16)
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)

            Text("No results found")
                .font(.system(size: 16, weight: .semibold))

            Text("Try different keywords or ask AI for help")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated search illustration
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                }

                Image(systemName: askAIMode ? "sparkles" : "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text(askAIMode ? "Ask AI anything" : "Search your knowledge")
                    .font(.system(size: 16, weight: .semibold))

                Text(askAIMode
                    ? "Get intelligent answers from your tasks, meetings, and recordings"
                    : "Find related content across tasks, recordings, and meetings"
                )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            }

            // Quick search suggestions
            VStack(spacing: 8) {
                Text("Try searching for:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 8) {
                    suggestionChip("project updates")
                    suggestionChip("meeting notes")
                }

                HStack(spacing: 8) {
                    suggestionChip("urgent tasks")
                    suggestionChip("this week")
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            query = text
            performSearch()
        } label: {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                )
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    var compact: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)

                Image(systemName: typeIcon)
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundStyle(typeColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(result.type.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(typeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(typeColor.opacity(0.1))
                        )

                    // Score badge
                    if !compact {
                        Text("\(Int(result.score * 100))% match")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(result.content)
                    .font(.system(size: compact ? 12 : 13))
                    .lineLimit(compact ? 1 : 2)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(compact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 8 : 10)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color(.controlBackgroundColor))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var typeIcon: String {
        switch result.type {
        case "task": return "checkmark.circle"
        case "recording": return "waveform"
        case "meeting": return "person.3"
        default: return "doc"
        }
    }

    private var typeColor: Color {
        switch result.type {
        case "task": return .blue
        case "recording": return .green
        case "meeting": return .purple
        default: return .gray
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState.shared)
        .frame(width: 350, height: 500)
}
