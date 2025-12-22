//
//  SettingsView.swift
//  Messy
//
//  App settings with Apple-style animations
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: SettingsSection = .account
    @Namespace private var animation
    
    // Location Sheet State
    @State private var showAddLocation = false

    enum SettingsSection: String, CaseIterable, Identifiable {
        case account = "Account"
        case organization = "Organization"
        case locations = "Locations"
        case tags = "Tags"
        case about = "About"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .account: return "person.circle"
            case .organization: return "building.2"
            case .locations: return "location"
            case .tags: return "tag"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)
            sectionPicker
            
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .account: accountSection
                    case .organization: organizationSection
                    case .locations: locationsSection
                    case .tags: tagsSection
                    case .about: aboutSection
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showAddLocation) {
            AddLocationView(isPresented: $showAddLocation)
        }
    }

    private var headerView: some View {
        HStack {
            Text("Settings")
                .messyFont(.largeTitle)
            Spacer()
        }
        .padding(20)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        withAnimation(.spring) { selectedSection = section }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                            Text(section.rawValue)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selectedSection == section {
                                Capsule()
                                    .fill(Color.messyBrand.opacity(0.15))
                                    .matchedGeometryEffect(id: "sel", in: animation)
                            }
                        }
                        .foregroundStyle(selectedSection == section ? Color.messyBrand : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        VStack(spacing: 12) {
            GlassMorphicCard {
                HStack(spacing: 16) {
                    Circle()
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                        .overlay(Text(String(appState.currentUser?.name?.prefix(1) ?? "U")).font(.title2).bold().foregroundStyle(.white))
                    
                    VStack(alignment: .leading) {
                        Text(appState.currentUser?.name ?? "User")
                            .messyFont(.headline)
                        Text(appState.currentUser?.email ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign Out") { appState.logout() }
                        .buttonStyle(BouncyButtonStyle())
                        .foregroundStyle(.red)
                }
                .padding(16)
            }
        }
    }

    private var organizationSection: some View {
        VStack(spacing: 12) {
            if let org = appState.currentOrg {
                GlassMorphicCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.2.fill").foregroundStyle(Color.messyBrand)
                            Text(org.name).messyFont(.headline)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Text("Invite Code:")
                            Text(org.inviteCode ?? "NONE").font(.monospaced(.body)()).bold()
                            Spacer()
                            if let code = org.inviteCode {
                                CopyButton(textToCopy: code)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                
                // Placeholder for leaving/switching (logic not fully in AppState yet, but UI added)
                Button("Leave Organization") {
                    // Logic to leave would go here
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.caption)
            } else {
                Text("No organization found.")
            }
        }
    }

    private var locationsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Your Locations")
                    .messyFont(.headline)
                Spacer()
                Button {
                    showAddLocation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.messyBrand)
                }
                .buttonStyle(BouncyButtonStyle())
            }
            .padding(.horizontal, 4)

            if appState.locations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No locations added")
                        .messyFont(.body)
                        .foregroundStyle(.secondary)
                    Text("Add home or work locations to enable\nlocation-based task suggestions.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(GlassMorphicCard { Color.clear })
            } else {
                ForEach(appState.locations) { location in
                    LocationRowView(location: location)
                }
            }
        }
    }
    
    private func locationIcon(for type: LocationType?) -> String {
        switch type {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        default: return "mappin.and.ellipse"
        }
    }
    
    // MARK: - Tags Section
    
    @State private var newTagText = ""
    
    private var tagsSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Manage Tags")
                    .messyFont(.headline)
                Spacer()
                Text("\(appState.availableTags.count) tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Add new tag
            GlassMorphicCard {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.messyBrand)
                    
                    TextField("Create new tag...", text: $newTagText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            if !newTagText.isEmpty {
                                appState.addSavedTag(newTagText)
                                newTagText = ""
                            }
                        }
                    
                    if !newTagText.isEmpty {
                        Button("Add") {
                            appState.addSavedTag(newTagText)
                            newTagText = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.messyBrand)
                        .controlSize(.small)
                    }
                }
                .padding(16)
            }
            
            // Tags list
            if appState.availableTags.isEmpty {
                GlassMorphicCard {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No tags yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Tags you create will appear here.\nYou can also add tags directly from tasks.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
            } else {
                GlassMorphicCard {
                    VStack(spacing: 0) {
                        ForEach(appState.availableTags, id: \.self) { tag in
                            TagRowView(tag: tag)
                            
                            if tag != appState.availableTags.last {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Info text
            Text("Tags help you organize and filter tasks. Deleting a tag here removes it from suggestions but won't remove it from existing tasks.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 16) {
            GlassMorphicCard {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.messyBrand)
                    Text("MessyMe").font(.title2.bold())
                    Text("Version 1.0.0").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            
            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit MessyMe")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                )
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Location Row View

struct LocationRowView: View {
    @EnvironmentObject var appState: AppState
    let location: Location
    @State private var isHovered = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        GlassMorphicCard(cornerRadius: 12, opacity: isHovered ? 0.7 : 0.5) {
            HStack(spacing: 12) {
                Image(systemName: iconForType(location.type))
                    .font(.system(size: 18))
                    .foregroundStyle(Color.messyBrand)
                    .frame(width: 36, height: 36)
                    .background(Color.messyBrand.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.system(size: 14, weight: .medium))
                    if let address = location.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isHovered {
                    HStack(spacing: 8) {
                        Button {
                            showEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
            .padding(12)
        }
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showEditSheet) {
            AddLocationView(isPresented: $showEditSheet, editingLocation: location)
        }
        .confirmationDialog(
            "Delete Location",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await appState.deleteLocation(location)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(location.name)\"?")
        }
    }
    
    private func iconForType(_ type: LocationType?) -> String {
        switch type {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        default: return "mappin.and.ellipse"
        }
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    @EnvironmentObject var appState: AppState
    let tag: String
    @State private var isHovered = false
    @State private var showDeleteAlert = false
    
    // Count tasks using this tag
    private var taskCount: Int {
        appState.tasks.filter { $0.tags?.contains(tag) == true }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Tag icon
            ZStack {
                Circle()
                    .fill(Color.messyBrand.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "tag.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.messyBrand)
            }
            
            // Tag name
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(tag)")
                    .font(.system(size: 14, weight: .medium))
                
                if taskCount > 0 {
                    Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button (shown on hover)
            if isHovered {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(6)
                    .background(Circle().fill(Color.red.opacity(0.1)))
                    .onTapGesture {
                        showDeleteAlert = true
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .alert("Delete Tag", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    appState.removeSavedTag(tag)
                }
            }
        } message: {
            Text("Remove \"\(tag)\" from your saved tags? This won't remove the tag from existing tasks.")
        }
    }
}

// MARK: - Location Manager Helper

@MainActor
class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating = false
    @Published var error: String?
    
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((CLLocation?) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        error = nil
        locationCompletion = completion
        isLocating = true
        
        // Check if location services are enabled at system level
        guard CLLocationManager.locationServicesEnabled() else {
            isLocating = false
            error = "Location Services are disabled. Enable in System Preferences > Privacy & Security > Location Services."
            completion(nil)
            return
        }
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            isLocating = false
            error = "Location access denied. Enable in System Preferences > Privacy & Security > Location Services."
            completion(nil)
        case .authorized, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default:
            isLocating = false
            error = "Unknown location authorization status."
            completion(nil)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            isLocating = false
            if let location = locations.first {
                currentLocation = location
                locationCompletion?(location)
            } else {
                error = "Could not get location."
                locationCompletion?(nil)
            }
            locationCompletion = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLocating = false
            // Provide more user-friendly error messages
            let nsError = error as NSError
            if nsError.domain == kCLErrorDomain {
                switch CLError.Code(rawValue: nsError.code) {
                case .locationUnknown:
                    self.error = "Unable to determine location. Please try again."
                case .denied:
                    self.error = "Location access denied. Enable in System Preferences."
                case .network:
                    self.error = "Network error. Check your internet connection."
                default:
                    self.error = "Location error. Please try again."
                }
            } else {
                self.error = "Location error: \(error.localizedDescription)"
            }
            locationCompletion?(nil)
            locationCompletion = nil
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = manager.authorizationStatus
            authorizationStatus = newStatus
            
            print("[LocationHelper] Authorization changed to: \(newStatus.rawValue)")
            
            // If we were waiting for authorization and it's now granted, request location
            if newStatus == .authorized || newStatus == .authorizedAlways {
                if isLocating && locationCompletion != nil {
                    print("[LocationHelper] Authorization granted, requesting location...")
                    manager.requestLocation()
                }
            } else if newStatus == .denied || newStatus == .restricted {
                isLocating = false
                error = "Location access denied. Enable in System Preferences."
                locationCompletion?(nil)
                locationCompletion = nil
            }
        }
    }
}

// MARK: - Add/Edit Location View

struct AddLocationView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @StateObject private var locationHelper = LocationHelper()
    
    // Edit mode
    var editingLocation: Location?
    
    @State private var name = ""
    @State private var address = ""
    @State private var type: LocationType = .custom
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var showMapPicker = false
    
    private var isEditing: Bool { editingLocation != nil }
    
    init(isPresented: Binding<Bool>, editingLocation: Location? = nil) {
        self._isPresented = isPresented
        self.editingLocation = editingLocation
        
        if let location = editingLocation {
            _name = State(initialValue: location.name)
            _address = State(initialValue: location.address ?? "")
            _type = State(initialValue: location.type ?? .custom)
            _latitude = State(initialValue: location.latitude)
            _longitude = State(initialValue: location.longitude)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(isEditing ? "Edit Location" : "Add Location")
                    .messyFont(.headline)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Add") {
                    saveLocation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.messyBrand)
                .disabled(type == .custom && name.isEmpty)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Add Options
                    if !isEditing {
                        VStack(spacing: 12) {
                            // Current Location
                            Button {
                                useCurrentLocation()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 44, height: 44)
                                        
                                        if locationHelper.isLocating {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Current Location")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Text("Use your current GPS location")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .background(
                                    GlassMorphicCard(cornerRadius: 12, opacity: 0.5) { Color.clear }
                                )
                            }
                            .buttonStyle(BouncyButtonStyle())
                            .disabled(locationHelper.isLocating)
                            
                            // Pin on Map
                            Button {
                                showMapPicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.1))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.green)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pin on Map")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Text("Drop a pin to mark a location")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .background(
                                    GlassMorphicCard(cornerRadius: 12, opacity: 0.5) { Color.clear }
                                )
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                        
                        // Divider with "or"
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                            Text("or enter manually")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Manual Entry Form
                    VStack(spacing: 16) {
                        // Location Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                LocationTypeButton(type: .home, selectedType: $type, icon: "house.fill", label: "Home")
                                LocationTypeButton(type: .work, selectedType: $type, icon: "briefcase.fill", label: "Work")
                                LocationTypeButton(type: .custom, selectedType: $type, icon: "mappin", label: "Other")
                            }
                        }
                        
                        // Name (only show for custom type)
                        if type == .custom {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Location name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(nsColor: .controlBackgroundColor))
                                    )
                            }
                        }
                        
                        // Address
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("Street address", text: $address)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                        }
                        
                        // Coordinates (if available)
                        if let lat = latitude, let lon = longitude {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Coordinates: \(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Error
                        if let error = locationHelper.error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Delete button (edit mode only)
                    if isEditing, let location = editingLocation {
                        Button(role: .destructive) {
                            Task {
                                await appState.deleteLocation(location)
                                isPresented = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Location")
                            }
                            .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: isEditing ? 400 : 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showMapPicker) {
            MapPickerView(
                latitude: $latitude,
                longitude: $longitude,
                address: $address,
                name: $name,
                locationType: type,
                isPresented: $showMapPicker
            )
        }
    }
    
    private func useCurrentLocation() {
        locationHelper.requestLocation { location in
            guard let location = location else { return }
            
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            
            // Auto-fill name based on type
            if name.isEmpty {
                name = type == .home ? "Home" : type == .work ? "Work" : "My Location"
            }
            
            // Reverse geocode for address
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let placemark = placemarks?.first {
                    var addressParts: [String] = []
                    if let street = placemark.thoroughfare { addressParts.append(street) }
                    if let city = placemark.locality { addressParts.append(city) }
                    if let state = placemark.administrativeArea { addressParts.append(state) }
                    address = addressParts.joined(separator: ", ")
                }
            }
        }
    }
    
    private func saveLocation() {
        // Auto-set name for Home/Work types
        let locationName: String
        switch type {
        case .home: locationName = "Home"
        case .work: locationName = "Work"
        case .custom: locationName = name
        }
        
        Task {
            if let location = editingLocation {
                await appState.updateLocation(
                    location,
                    name: locationName,
                    type: type,
                    address: address.isEmpty ? nil : address,
                    latitude: latitude,
                    longitude: longitude
                )
            } else {
                await appState.addLocation(
                    name: locationName,
                    type: type,
                    address: address.isEmpty ? nil : address,
                    latitude: latitude,
                    longitude: longitude
                )
            }
            isPresented = false
        }
    }
}

// MARK: - Location Type Button

struct LocationTypeButton: View {
    let type: LocationType
    @Binding var selectedType: LocationType
    let icon: String
    let label: String
    
    var isSelected: Bool { selectedType == type }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedType = type
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.messyBrand : .secondary)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.messyBrand.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.messyBrand : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Map Picker View

struct MapPickerView: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var address: String
    @Binding var name: String
    let locationType: LocationType
    @Binding var isPresented: Bool
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco default
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Pin on Map")
                    .messyFont(.headline)
                
                Spacer()
                
                Button("Done") {
                    if let pin = pinCoordinate {
                        latitude = pin.latitude
                        longitude = pin.longitude
                        
                        // Auto-fill name if empty
                        if name.isEmpty {
                            name = locationType == .home ? "Home" : locationType == .work ? "Work" : "My Location"
                        }
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.messyBrand)
                .disabled(pinCoordinate == nil)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search for a place...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        searchLocation()
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Map
            ZStack {
                Map(coordinateRegion: $region, annotationItems: pinAnnotations) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.red)
                            
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                                .offset(y: -5)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Calculate tap location on map
                            // For macOS, we need to convert the gesture location
                        }
                )
                .overlay(alignment: .center) {
                    // Crosshair for center
                    if pinCoordinate == nil {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.secondary)
                            
                            Text("Tap to drop pin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                }
                .onTapGesture { location in
                    // Drop pin at center of current view
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        pinCoordinate = region.center
                    }
                    reverseGeocode(coordinate: region.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Instructions / Selected location info
            VStack(spacing: 8) {
                if let pin = pinCoordinate {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if !address.isEmpty {
                                Text(address)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(2)
                            }
                            Text("\(String(format: "%.4f", pin.latitude)), \(String(format: "%.4f", pin.longitude))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                pinCoordinate = nil
                                address = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundStyle(.secondary)
                        Text("Tap on the map to drop a pin")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 450, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Try to center on user's current location
            let locationManager = CLLocationManager()
            if let location = locationManager.location {
                region.center = location.coordinate
            }
        }
    }
    
    private var pinAnnotations: [PinAnnotation] {
        if let pin = pinCoordinate {
            return [PinAnnotation(coordinate: pin)]
        }
        return []
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            if let response = response, let item = response.mapItems.first {
                withAnimation(.easeInOut(duration: 0.3)) {
                    region.center = item.placemark.coordinate
                    region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    pinCoordinate = item.placemark.coordinate
                }
                
                // Set address from placemark
                if let placemark = item.placemark as? MKPlacemark {
                    var addressParts: [String] = []
                    if let street = placemark.thoroughfare { addressParts.append(street) }
                    if let city = placemark.locality { addressParts.append(city) }
                    if let state = placemark.administrativeArea { addressParts.append(state) }
                    address = addressParts.joined(separator: ", ")
                }
            }
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                var addressParts: [String] = []
                if let street = placemark.thoroughfare { addressParts.append(street) }
                if let city = placemark.locality { addressParts.append(city) }
                if let state = placemark.administrativeArea { addressParts.append(state) }
                address = addressParts.joined(separator: ", ")
            }
        }
    }
}

struct PinAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Copy Button with Feedback

struct CopyButton: View {
    let textToCopy: String
    @State private var showCopied = false
    
    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToCopy, forType: .string)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopied = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCopied = false
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                Text(showCopied ? "Copied!" : "Copy")
            }
            .font(.caption)
            .foregroundStyle(showCopied ? .green : .secondary)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}
