//
//  MainContentView.swift
//  Messy
//
//  Main content view with navigation sidebar - Apple-style UI
//

import SwiftUI
import AuthenticationServices

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @Namespace var animation
    @State private var hoverTab: NavigationTab?
    
    // We bind this to TaskListView and TaskDetailView to coordinate the hero animation
    // Ideally these would be passed down or avail via environment, but for now we pass a namespace via a container if needed.
    // Since we can't pass Namespace easily through Environment without wrapper, we'll organize proper structure.

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
        .frame(width: 480, height: 640)
        .background(
            ZStack {
                Color(.windowBackgroundColor)
                // Subtle animated gradient overlay - ORANGE Tint
                RadialGradient(
                    colors: [.messyBrand.opacity(0.04), .clear],
                    center: .topTrailing,
                    startRadius: 100,
                    endRadius: 500
                )
            }
        )
    }

    private var authenticatedView: some View {
        ZStack {
            HStack(spacing: 0) {
                // Enhanced Sidebar
                sidebarView
                    .frame(width: 70)
                    .padding(4)
                    .background(
                        ZStack {
                            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                            Color(.controlBackgroundColor).opacity(0.3)
                        }
                    )
                
                Divider()
                    .opacity(0.5)

                // Main Content
                ZStack {
                    contentView
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.selectedTab)
            }
            .blur(radius: appState.isShowingTaskDetail ? 5 : 0) // Blur background when detail is open
            .scaleEffect(appState.isShowingTaskDetail ? 0.98 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.isShowingTaskDetail)

            // Hero Overlay for Task Detail
            if appState.isShowingTaskDetail, let task = appState.selectedTask {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            appState.isShowingTaskDetail = false
                        }
                    }
                    .transition(.opacity)
                
                TaskDetailView(isPresented: $appState.isShowingTaskDetail, task: task)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
            
            // Error Banner
            errorBanner
        }
    }

    // MARK: - Enhanced Sidebar

    private var sidebarView: some View {
        VStack(spacing: 8) {
            // Animated App logo
            AnimatedLogoView()
                .padding(.top, 16)
                .padding(.bottom, 12)

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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                appState.selectedTab = tab
            }
        } label: {
            ZStack {
                // Background Selection
                if appState.selectedTab == tab {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.messyBrand.opacity(0.1))
                        .matchedGeometryEffect(id: "nav_bg", in: animation)
                }

                // Hover state
                if hoverTab == tab && appState.selectedTab != tab {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.05))
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: appState.selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(appState.selectedTab == tab ? Color.messyBrand : .secondary)
                        .symbolEffect(.bounce.down, value: appState.selectedTab == tab)

                    Text(tab.rawValue.split(separator: " ").first ?? "")
                        .font(.system(size: 10, weight: appState.selectedTab == tab ? .medium : .regular))
                        .foregroundStyle(appState.selectedTab == tab ? .primary : .secondary)
                }
                .frame(width: 54, height: 50)
            }
        }
        .buttonStyle(BouncyButtonStyle())
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

    // MARK: - Enhanced Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if appState.showError, let message = appState.errorMessage {
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange) // Semantic warning color

                    Text(message)
                        .messyFont(.caption)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        withAnimation {
                            appState.showError = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    GlassMorphicCard(cornerRadius: 12, opacity: 0.95) {
                        Color.clear
                    }
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.horizontal, 30)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                
                Spacer()
            }
            .zIndex(200)
        }
    }
}

// MARK: - Animated Logo View

struct AnimatedLogoView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Clean Logo
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.black, .gray.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.messyBrand)
        }
    }
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Enhanced Login View (Cleaned Up)

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Subtle ambient background
            FloatingParticlesView(count: 10, color: .messyBrand)
                .opacity(0.3)
            
            VStack(spacing: 24) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.black, .gray.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        .glow(color: .messyBrand, radius: 15)

                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.messyBrand)
                }

                VStack(spacing: 8) {
                    Text("MessyMe")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Stay organized, stay focused")
                        .messyFont(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Enhanced Sign in
                if appState.isLoading {
                    ProgressView()
                        .padding(.bottom, 20)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleSignInWithApple(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .frame(maxWidth: 260)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4)
                    .padding(.bottom, 50)
                }
            }
        }
    }

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let stableEmail = "\(userIdentifier)@apple.messy.id"
                Task {
                    await appState.login(email: stableEmail)
                }
            }
        case .failure(let error):
            print("Login failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Organization Setup View (Cleaned Up)

struct OrganizationSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var orgName = ""
    @State private var inviteCode = ""
    @State private var showJoinOrg = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [.messyBrand.opacity(0.05), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            
            VStack(spacing: 30) {
                Spacer()

                // Icon
                Image(systemName: "building.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.messyBrand, .orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .messyBrand.opacity(0.3), radius: 10)

                VStack(spacing: 8) {
                    Text("Workspace Setup")
                        .messyFont(.largeTitle)
                    
                    Text("Create or join a team to get started")
                        .messyFont(.body)
                        .foregroundStyle(.secondary)
                }

                if showJoinOrg {
                    joinOrgForm
                } else {
                    createOrgForm
                }
                
                Spacer()
            }
            .padding(40)
            .animation(.spring, value: showJoinOrg)
        }
    }
    
    private var joinOrgForm: some View {
        VStack(spacing: 16) {
            TextField("Invite Code", text: $inviteCode)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.textBackgroundColor)))
            
            Button("Join Organization") {
                Task { await appState.joinOrganization(inviteCode: inviteCode) }
            }
            .buttonStyle(BouncyButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.messyBrand)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .disabled(inviteCode.isEmpty)

            Button("Creat New Organization") { showJoinOrg = false }
                .buttonStyle(.plain)
                .foregroundStyle(.messyBrand)
                .font(.caption)
        }
        .transition(.move(edge: .trailing))
    }
    
    private var createOrgForm: some View {
        VStack(spacing: 16) {
            TextField("Organization Name", text: $orgName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.textBackgroundColor)))
            
            Button("Create Organization") {
                Task { await appState.createOrganization(name: orgName) }
            }
            .buttonStyle(BouncyButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.messyBrand)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .disabled(orgName.isEmpty)

            Button("Join Existing Organization") { showJoinOrg = true }
                .buttonStyle(.plain)
                .foregroundStyle(.messyBrand)
                .font(.caption)
        }
        .transition(.move(edge: .leading))
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppState.shared)
}
