//
//  MainContentView.swift
//  Messy
//
//  Main content view with navigation sidebar
//

import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var hoverTab: NavigationTab?
    @Namespace private var animation

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if appState.currentOrg != nil {
                    authenticatedView
                } else {
                    OrganizationSetupView()
                }
            } else {
                LoginView()
            }
        }
        .frame(width: 420, height: 600)
        .background(Color(.windowBackgroundColor))
    }

    private var authenticatedView: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebarView
                .frame(width: 70)
                .background(
                    Color(.controlBackgroundColor)
                        .opacity(0.5)
                )

            Divider()

            // Main content
            ZStack {
                contentView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.selectedTab)
        }
        .overlay(alignment: .top) {
            errorBanner
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 4) {
            // App logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.black, .gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Navigation tabs
            ForEach(NavigationTab.allCases.filter { $0 != .settings }) { tab in
                sidebarButton(for: tab)
            }

            Spacer()

            // Settings at bottom
            sidebarButton(for: .settings)
                .padding(.bottom, 12)
        }
    }

    private func sidebarButton(for tab: NavigationTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appState.selectedTab = tab
            }
        } label: {
            ZStack {
                // Selection indicator
                if appState.selectedTab == tab {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.1))
                        .matchedGeometryEffect(id: "selection", in: animation)
                }

                // Hover state
                if hoverTab == tab && appState.selectedTab != tab {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: appState.selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(appState.selectedTab == tab ? tab.color : .secondary)
                        .symbolEffect(.bounce, value: appState.selectedTab == tab)

                    Text(tab.rawValue.split(separator: " ").first ?? "")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(appState.selectedTab == tab ? .primary : .secondary)
                }
                .frame(width: 54, height: 50)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoverTab = hovering ? tab : nil
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedTab {
        case .today, .all, .upcoming, .overdue:
            TaskListView(filter: appState.selectedTab)
        case .recordings:
            RecordingsView()
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if appState.showError, let message = appState.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation {
                        appState.showError = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
            .padding(.horizontal, 80)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var isAnimating = false
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo animation
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.black.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 80 + CGFloat(i * 30), height: 80 + CGFloat(i * 30))
                        .scaleEffect(isAnimating ? 1.1 : 1)
                        .opacity(isAnimating ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.4),
                            value: isAnimating
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.black, .gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .onAppear { isAnimating = true }

            Text("MessyMe")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.top, 24)

            Text("Stay organized, stay focused")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Login form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isEmailFocused ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                        .focused($isEmailFocused)
                        .onSubmit {
                            login()
                        }
                }

                Button {
                    login()
                } label: {
                    ZStack {
                        if appState.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .colorScheme(.dark)
                        } else {
                            Text("Get Started")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(email.isEmpty ? Color.gray : Color.black)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(email.isEmpty || appState.isLoading)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    private func login() {
        guard !email.isEmpty else { return }
        Task {
            await appState.login(email: email)
        }
    }
}

// MARK: - Organization Setup View

struct OrganizationSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var orgName = ""
    @State private var inviteCode = ""
    @State private var showJoinOrg = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)

                Image(systemName: "building.2.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Set Up Your Workspace")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.top, 24)

            Text("Create a new organization or join an existing one")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 40)

            Spacer()

            // Forms
            VStack(spacing: 20) {
                if showJoinOrg {
                    // Join org form
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Invite Code")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Enter invite code", text: $inviteCode)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isCodeFocused ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                            )
                            .focused($isCodeFocused)
                            .onSubmit { joinOrg() }
                    }

                    Button { joinOrg() } label: {
                        Text("Join Organization")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(inviteCode.isEmpty ? Color.gray : Color.blue)
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(inviteCode.isEmpty || appState.isLoading)

                    Button { showJoinOrg = false } label: {
                        Text("Create new organization instead")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Create org form
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Organization Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("My Team", text: $orgName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isNameFocused ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                            )
                            .focused($isNameFocused)
                            .onSubmit { createOrg() }
                    }

                    Button { createOrg() } label: {
                        ZStack {
                            if appState.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .colorScheme(.dark)
                            } else {
                                Text("Create Organization")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(orgName.isEmpty ? Color.gray : Color.black)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(orgName.isEmpty || appState.isLoading)

                    Button { showJoinOrg = true } label: {
                        Text("Join existing organization")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
            .animation(.easeInOut(duration: 0.2), value: showJoinOrg)
        }
    }

    private func createOrg() {
        guard !orgName.isEmpty else { return }
        Task {
            await appState.createOrganization(name: orgName)
        }
    }

    private func joinOrg() {
        guard !inviteCode.isEmpty else { return }
        Task {
            await appState.joinOrganization(inviteCode: inviteCode)
        }
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppState.shared)
}
