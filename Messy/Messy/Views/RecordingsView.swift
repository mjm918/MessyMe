//
//  RecordingsView.swift
//  Messy
//
//  Audio recordings view with waveform visualization
//

import SwiftUI
import AVFoundation
import Combine

struct RecordingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioManager = AudioRecordingManager()

    @State private var recordingType: RecordingType = .voiceMemo
    @State private var showingRecordingSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(.horizontal)

            // Recording controls
            recordingControlsView

            // Recordings list
            if appState.recordings.isEmpty && !audioManager.isRecording {
                emptyStateView
            } else {
                recordingsListView
            }
        }
        .onAppear {
            Task {
                await appState.loadRecordings()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recordings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text(recordingCountText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Type picker
            Picker("", selection: $recordingType) {
                Text("Voice Memo").tag(RecordingType.voiceMemo as RecordingType)
                Text("Meeting").tag(RecordingType.meeting as RecordingType)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var recordingCountText: String {
        let count = appState.recordings.count
        return count == 1 ? "1 recording" : "\(count) recordings"
    }

    // MARK: - Recording Controls

    private var recordingControlsView: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            if audioManager.isRecording {
                WaveformView(levels: audioManager.audioLevels)
                    .frame(height: 60)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Record button
            HStack(spacing: 20) {
                if audioManager.isRecording {
                    // Duration
                    Text(formatDuration(audioManager.recordingDuration))
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                }

                // Main record button
                recordButton

                if audioManager.isRecording {
                    // Cancel button
                    Button {
                        audioManager.cancelRecording()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(.controlBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioManager.isRecording)
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(audioManager.isRecording ? Color.red.opacity(0.05) : Color.clear)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var recordButton: some View {
        Button {
            if audioManager.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                // Outer ring animation
                if audioManager.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .frame(width: 72, height: 72)
                        .scaleEffect(audioManager.isRecording ? 1.2 : 1)
                        .opacity(audioManager.isRecording ? 0 : 1)
                        .animation(
                            .easeInOut(duration: 1)
                            .repeatForever(autoreverses: false),
                            value: audioManager.isRecording
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: audioManager.isRecording ? [.red, .red.opacity(0.8)] : [.black, .gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: audioManager.isRecording ? .red.opacity(0.4) : .black.opacity(0.2), radius: 8, y: 4)

                if audioManager.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(audioManager.isRecording ? 1.05 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.isRecording)
    }

    private func startRecording() {
        audioManager.startRecording()
    }

    private func stopRecording() {
        audioManager.stopRecording { url, duration in
            // TODO: Transcribe and save
            Task {
                await appState.createRecording(
                    type: recordingType,
                    title: recordingType == .voiceMemo ? "Voice Memo" : "Meeting Recording",
                    transcript: nil,
                    duration: Int(duration)
                )
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Recordings List

    private var recordingsListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(appState.recordings.enumerated()), id: \.element.id) { index, recording in
                    RecordingRowView(recording: recording)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: recording.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
            }

            Text("No recordings yet")
                .font(.system(size: 16, weight: .semibold))

            Text("Tap the record button to capture voice memos or meeting notes")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [CGFloat]
    @State private var animate = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<40, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.15),
                        value: levels
                    )
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level: CGFloat
        if index < levels.count {
            level = levels[index]
        } else {
            level = CGFloat.random(in: 0.1...0.3)
        }
        return max(4, level * 60)
    }
}

// MARK: - Recording Row View

struct RecordingRowView: View {
    @EnvironmentObject var appState: AppState
    let recording: Recording

    @State private var isHovered = false
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button {
                isPlaying.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(recording.type == .voiceMemo ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(recording.type == .voiceMemo ? .green : .blue)
                }
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: recording.type == .voiceMemo ? "mic.fill" : "person.3.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(recording.title ?? (recording.type == .voiceMemo ? "Voice Memo" : "Meeting"))
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    // Duration
                    if let duration = recording.durationSeconds {
                        Text(formatDuration(duration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    // Date
                    if let createdAt = recording.createdAt {
                        Text(formatDate(createdAt))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Transcript preview
                if let transcript = recording.transcript, !transcript.isEmpty {
                    Text(transcript)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Actions
            if isHovered {
                Button {
                    Task {
                        await appState.deleteRecording(recording)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color(.controlBackgroundColor))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Audio Recording Manager

@MainActor
class AudioRecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 40)

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    func startRecording() {
        do {
            // On macOS, we don't need AVAudioSession - just create the recorder directly
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
            recordingURL = documentsPath.appendingPathComponent(fileName)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0

            // Duration timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    self?.recordingDuration += 1
                }
            }

            // Level meter timer
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    self?.updateAudioLevels()
                }
            }
        } catch {
            print("Recording error: \(error)")
        }
    }

    func stopRecording(completion: @escaping (URL?, TimeInterval) -> Void) {
        guard isRecording else { return }

        let duration = recordingDuration
        let url = recordingURL

        audioRecorder?.stop()
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        isRecording = false
        recordingDuration = 0
        audioLevels = Array(repeating: 0.1, count: 40)

        completion(url, duration)
    }

    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        // Delete the file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        isRecording = false
        recordingDuration = 0
        audioLevels = Array(repeating: 0.1, count: 40)
    }

    private func updateAudioLevels() {
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        let normalizedLevel = max(0, (level + 60) / 60) // Normalize from -60dB to 0dB

        withAnimation(.easeInOut(duration: 0.1)) {
            audioLevels.removeFirst()
            audioLevels.append(CGFloat(normalizedLevel))
        }
    }
}

#Preview {
    RecordingsView()
        .environmentObject(AppState.shared)
        .frame(width: 350, height: 500)
}
