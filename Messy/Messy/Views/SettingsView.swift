//
//  SettingsView.swift
//  Messy
//
//  App settings and preferences
//

import SwiftUI
import MapKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: SettingsSection = .account

    enum SettingsSection: String, CaseIterable, Identifiable {
        case account = "Account"
        case organization = "Organization"
        case locations = "Locations"
        case breaks = "Breaks"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .account: return "person.circle"
            case .organization: return "building.2"
            case .locations: return "location"
            case .breaks: return "cup.and.saucer"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(.horizontal)

            // Section picker
            sectionPicker

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .account:
                        accountSection
                    case .organization:
                        organizationSection
                    case .locations:
                        locationsSection
                    case .breaks:
                        breaksSection
                    case .about:
                        aboutSection
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SettingsSection.allCases) { section in
                    sectionButton(section)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func sectionButton(_ section: SettingsSection) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 12))

                Text(section.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedSection == section ? Color.primary.opacity(0.1) : Color.clear)
            )
            .foregroundStyle(selectedSection == section ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 12) {
            settingsCard {
                VStack(spacing: 16) {
                    // User info
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)

                            Text(userInitials)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.currentUser?.name ?? "User")
                                .font(.system(size: 15, weight: .semibold))

                            Text(appState.currentUser?.email ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Divider()

                    // Sign out
                    Button {
                        signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var userInitials: String {
        let name = appState.currentUser?.name ?? appState.currentUser?.email ?? "U"
        return String(name.prefix(2)).uppercased()
    }

    private func signOut() {
        appState.currentUser = nil
        appState.currentOrg = nil
        appState.isAuthenticated = false
        appState.tasks = []
        appState.recordings = []
    }

    // MARK: - Organization Section

    @State private var showInviteCode = false
    @State private var joinCode = ""

    private var organizationSection: some View {
        VStack(spacing: 12) {
            if let org = appState.currentOrg {
                settingsCard {
                    VStack(spacing: 16) {
                        // Org info
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 50, height: 50)

                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.purple)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(org.name)
                                    .font(.system(size: 15, weight: .semibold))

                                Text("Organization")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        Divider()

                        // Invite code
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invite Code")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)

                                Text(showInviteCode ? (org.inviteCode ?? "N/A") : "••••••")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                            }

                            Spacer()

                            Button {
                                showInviteCode.toggle()
                            } label: {
                                Image(systemName: showInviteCode ? "eye.slash" : "eye")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let code = org.inviteCode {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(code, forType: .string)
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Join another org
            settingsCard {
                VStack(spacing: 12) {
                    Text("Join Another Organization")
                        .font(.system(size: 13, weight: .semibold))

                    HStack {
                        TextField("Enter invite code", text: $joinCode)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.textBackgroundColor))
                            )

                        Button {
                            Task {
                                await appState.joinOrganization(inviteCode: joinCode)
                                joinCode = ""
                            }
                        } label: {
                            Text("Join")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(joinCode.count == 6 ? Color.blue : Color.gray.opacity(0.3))
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(joinCode.count != 6)
                    }
                }
            }
        }
    }

    // MARK: - Locations Section

    @State private var showAddLocation = false
    @State private var newLocationName = ""
    @State private var newLocationType: LocationType = .custom

    private var locationsSection: some View {
        VStack(spacing: 12) {
            // Add location
            settingsCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("Your Locations")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        Button {
                            showAddLocation.toggle()
                        } label: {
                            Image(systemName: showAddLocation ? "minus" : "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if showAddLocation {
                        VStack(spacing: 10) {
                            TextField("Location name", text: $newLocationName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.textBackgroundColor))
                                )

                            Picker("Type", selection: $newLocationType) {
                                Text("Home").tag(LocationType.home as LocationType)
                                Text("Work").tag(LocationType.work as LocationType)
                                Text("Custom").tag(LocationType.custom as LocationType)
                            }
                            .pickerStyle(.segmented)

                            Button {
                                addLocation()
                            } label: {
                                Text("Add Location")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(newLocationName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                    )
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(newLocationName.isEmpty)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Location list
                    ForEach(appState.locations) { location in
                        locationRow(location)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAddLocation)
    }

    private func locationRow(_ location: Location) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(locationTypeColor(location.type).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: locationTypeIcon(location.type))
                    .font(.system(size: 14))
                    .foregroundStyle(locationTypeColor(location.type))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.system(size: 13, weight: .medium))

                if let address = location.address {
                    Text(address)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                Task {
                    _ = try? await APIClient.shared.deleteLocation(id: location.id)
                    await appState.loadLocations()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func locationTypeIcon(_ type: LocationType?) -> String {
        switch type {
        case .home: return "house.fill"
        case .work: return "building.2.fill"
        default: return "mappin"
        }
    }

    private func locationTypeColor(_ type: LocationType?) -> Color {
        switch type {
        case .home: return .orange
        case .work: return .blue
        default: return .gray
        }
    }

    private func addLocation() {
        guard let user = appState.currentUser, !newLocationName.isEmpty else { return }

        Task {
            _ = try? await APIClient.shared.createLocation(
                userId: user.id,
                name: newLocationName,
                type: newLocationType
            )
            await appState.loadLocations()
            newLocationName = ""
            showAddLocation = false
        }
    }

    // MARK: - Breaks Section

    @State private var showAddBreak = false
    @State private var newBreakName = ""
    @State private var newBreakType: BreakType = .rest

    private var breaksSection: some View {
        VStack(spacing: 12) {
            settingsCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("Break Schedules")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        Button {
                            showAddBreak.toggle()
                        } label: {
                            Image(systemName: showAddBreak ? "minus" : "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if showAddBreak {
                        VStack(spacing: 10) {
                            TextField("Break name (e.g., Lunch)", text: $newBreakName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.textBackgroundColor))
                                )

                            Picker("Type", selection: $newBreakType) {
                                Text("Prayer").tag(BreakType.prayer as BreakType)
                                Text("Meal").tag(BreakType.meal as BreakType)
                                Text("Rest").tag(BreakType.rest as BreakType)
                            }
                            .pickerStyle(.segmented)

                            Button {
                                addBreak()
                            } label: {
                                Text("Add Break")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(newBreakName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                    )
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(newBreakName.isEmpty)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    ForEach(appState.breaks) { breakItem in
                        breakRow(breakItem)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAddBreak)
    }

    private func breakRow(_ breakItem: Break) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(breakTypeColor(breakItem.type).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: breakTypeIcon(breakItem.type))
                    .font(.system(size: 14))
                    .foregroundStyle(breakTypeColor(breakItem.type))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(breakItem.name)
                    .font(.system(size: 13, weight: .medium))

                Text(breakItem.type.rawValue.capitalized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    _ = try? await APIClient.shared.deleteBreak(id: breakItem.id)
                    await appState.loadBreaks()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func breakTypeIcon(_ type: BreakType) -> String {
        switch type {
        case .prayer: return "moon.stars"
        case .meal: return "fork.knife"
        case .rest: return "cup.and.saucer"
        }
    }

    private func breakTypeColor(_ type: BreakType) -> Color {
        switch type {
        case .prayer: return .purple
        case .meal: return .orange
        case .rest: return .green
        }
    }

    private func addBreak() {
        guard let user = appState.currentUser, !newBreakName.isEmpty else { return }

        Task {
            _ = try? await APIClient.shared.createBreak(
                userId: user.id,
                type: newBreakType,
                name: newBreakName
            )
            await appState.loadBreaks()
            newBreakName = ""
            showAddBreak = false
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 12) {
            settingsCard {
                VStack(spacing: 16) {
                    // App icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.black, .gray.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 4) {
                        Text("MessyMe")
                            .font(.system(size: 18, weight: .bold))

                        Text("Version 1.0.0")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(spacing: 12) {
                        aboutRow(icon: "keyboard", title: "Global Hotkey", value: "⌘⇧Space")
                        aboutRow(icon: "arrow.clockwise", title: "Auto Sync", value: "Enabled")
                        aboutRow(icon: "sparkles", title: "AI Features", value: "Gemini 2.5 Pro")
                    }
                }
            }
        }
    }

    private func aboutRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Views

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 350, height: 500)
}
