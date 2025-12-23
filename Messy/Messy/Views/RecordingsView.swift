//
//  RecordingsView.swift
//  Messy
//
//  Audio recordings view with Apple-style waveform visualization
//

import SwiftUI
import AVFoundation
import Combine

struct RecordingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioManager = AudioRecordingManager()
    @State private var recordingType: RecordingType = .voiceMemo
    @State private var waveformHeights: [CGFloat] = Array(repeating: 8, count: 30)

    private func updateWaveform() {
        guard audioManager.isRecording else { return }
        
        let level = audioManager.audioLevel
        let maxHeight: CGFloat = 45
        let minHeight: CGFloat = 6
        let idleHeight: CGFloat = 8
        
        // Calculate target heights based on audio level
        let speakingThreshold: CGFloat = 0.08
        
        for index in 0..<30 {
            // Center bars are taller (bell curve)
            let normalizedIndex = CGFloat(index) / 30.0
            let centerBias = 0.4 + (1.0 - abs(normalizedIndex - 0.5) * 2.0) * 0.6
            
            let newHeight: CGFloat
            if level < speakingThreshold {
                // Silent - minimal movement
                newHeight = idleHeight * centerBias + minHeight
            } else {
                // Speaking - audio reactive with per-bar variation
                let variation = CGFloat.random(in: 0.7...1.0)
                let audioHeight = level * (maxHeight - idleHeight) * centerBias * variation
                newHeight = minHeight + idleHeight + audioHeight
            }
            
            // Smooth interpolation toward target
            let smoothFactor: CGFloat = level > waveformHeights[index] / maxHeight ? 0.6 : 0.3
            waveformHeights[index] = waveformHeights[index] * (1 - smoothFactor) + newHeight * smoothFactor
            waveformHeights[index] = max(minHeight, min(maxHeight, waveformHeights[index]))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider().opacity(0.3)

            // Recorder
            recorderView
                .padding(20)

            // List
            if appState.recordings.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.recordings) { recording in
                            RecordingRowView(recording: recording)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            Task { await appState.loadRecordings() }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Recordings")
                .messyFont(.largeTitle)
            Spacer()
            Picker("", selection: $recordingType) {
                Text("Voice Memo").tag(RecordingType.voiceMemo)
                Text("Meeting").tag(RecordingType.meeting)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(20)
    }

    // MARK: - Recorder

    private var recorderView: some View {
        VStack(spacing: 20) {
            if audioManager.isRecording {
                // Time
                Text(formatDuration(audioManager.recordingDuration))
                    .font(.system(size: 40, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                
                // Active Waveform
                HStack(spacing: 3) {
                    ForEach(0..<30, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: 4, height: waveformHeights[index])
                            .animation(.easeOut(duration: 0.08), value: waveformHeights[index])
                    }
                }
                .frame(height: 50)
                .onChange(of: audioManager.audioLevel) { _, _ in
                    updateWaveform()
                }
            } else {
                Text("Tap to Record")
                    .messyFont(.headline)
                    .foregroundStyle(.secondary)
            }

            // Controls
            HStack(spacing: 40) {
                if audioManager.isRecording {
                    Button {
                        audioManager.cancelRecording()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(BouncyButtonStyle())
                }

                // Main Button
                Button {
                    if audioManager.isRecording {
                        stopRecording()
                    } else {
                        audioManager.startRecording()
                    }
                } label: {
                    ZStack {
                        // Outer Glow
                        if audioManager.isRecording {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .scaleEffect(1.1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: audioManager.isRecording)
                        }
                        
                        // Button
                        Circle()
                            .fill(audioManager.isRecording ? Color.red : Color.messyBrand)
                            .frame(width: 70, height: 70)
                            .shadow(color: (audioManager.isRecording ? Color.red : Color.messyBrand).opacity(0.4), radius: 10, y: 5)
                        
                        Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(BouncyButtonStyle())
                
                // Spacer item to balance layout
                if audioManager.isRecording {
                    Spacer().frame(width: 50) // Placeholder
                }
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(
            GlassMorphicCard(cornerRadius: 20, opacity: 0.5) { Color.clear }
        )
    }

    private func stopRecording() {
        audioManager.stopRecording { url, duration in
            guard let audioUrl = url else { return }
            
            Task {
                // Read audio file data
                guard let audioData = try? Data(contentsOf: audioUrl) else {
                    print("Failed to read audio file")
                    return
                }
                
                let filename = audioUrl.lastPathComponent
                let title = "\(recordingType == .voiceMemo ? "Memo" : "Meeting") \(Date().formatted(date: .numeric, time: .shortened))"
                
                // Upload and create recording - transcription is done on backend via ElevenLabs
                await appState.uploadAndCreateRecording(
                    type: recordingType,
                    title: title,
                    audioData: audioData,
                    filename: filename,
                    duration: Int(duration)
                )
                
                // Clean up local file
                try? FileManager.default.removeItem(at: audioUrl)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No recordings yet").messyFont(.body).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct RecordingRowView: View {
    @EnvironmentObject var appState: AppState
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isHovered = false
    @State private var showTranscript = false
    @State private var presignedUrl: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Play/Pause button
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
                            .fill(Color.messyBrand.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        if audioPlayer.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.messyBrand)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(recording.audioUrl == nil)
                .opacity(recording.audioUrl == nil ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title ?? "Recording")
                        .messyFont(.caption)
                    
                    HStack(spacing: 8) {
                        // Duration / Progress
                        if audioPlayer.isPlaying || audioPlayer.currentTime > 0 {
                            Text(formatDuration(Int(audioPlayer.currentTime)))
                                .monospacedDigit()
                            Text("/")
                        }
                        Text(formatDuration(recording.durationSeconds ?? 0))
                        
                        Text("•")
                        
                        Text(recording.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    // Progress bar
                    if audioPlayer.duration > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(Color.messyBrand)
                                    .frame(width: geo.size.width * (audioPlayer.currentTime / audioPlayer.duration), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Transcript button
                    if recording.transcript != nil {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showTranscript.toggle()
                            }
                        } label: {
                            Image(systemName: showTranscript ? "text.quote.rtl" : "text.quote")
                                .foregroundStyle(showTranscript ? Color.messyBrand : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isHovered {
                        Button {
                            Task { await appState.deleteRecording(recording) }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            
            // Transcript section
            if showTranscript, let transcript = recording.transcript {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("Transcript")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(transcript)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.9))
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(GlassMorphicCard(cornerRadius: 12, opacity: isHovered ? 0.7 : 0.4) { Color.clear })
        .onHover { isHovered = $0 }
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
    
    func formatDuration(_ seconds: Int) -> String {
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Audio Player Manager

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    override init() {
        super.init()
    }
    
    func play(url: URL) {
        // If same URL and paused, just resume
        if let currentItem = player?.currentItem,
           (currentItem.asset as? AVURLAsset)?.url == url,
           player?.rate == 0 {
            player?.play()
            isPlaying = true
            return
        }
        
        // New URL - create new player
        isLoading = true
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe when ready to play
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Add time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                    self?.duration = duration
                }
            }
        }
        
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentTime = 0
    }
    
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
    }
    
    override nonisolated func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            Task { @MainActor in
                self.isLoading = false
                if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                    self.duration = duration
                }
            }
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// Real Audio Manager using AVAudioRecorder
@MainActor
class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: CGFloat = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var displayLink: CVDisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var timerTask: Task<Void, Never>?
    
    override init() {
        super.init()
    }
    
    func startRecording() {
        // macOS permissions are assumed handled or sandbox allows
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            let started = audioRecorder?.record() ?? false
            
            if started {
                isRecording = true
                startMetering()
            } else {
                print("Failed to start recording")
            }
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    private func startMetering() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isRecording else { break }
                
                self.recordingDuration += 0.05
                self.audioRecorder?.updateMeters()
                
                if let power = self.audioRecorder?.averagePower(forChannel: 0) {
                    // Typical speech is around -20 to -10 dB, silence is around -60 dB
                    let minDb: Float = -60
                    let maxDb: Float = -5
                    let clamped = max(minDb, min(maxDb, power))
                    let normalized = CGFloat((clamped - minDb) / (maxDb - minDb))
                    
                    // Faster response, slower decay
                    let newLevel = normalized
                    if newLevel > self.audioLevel {
                        // Fast attack
                        self.audioLevel = self.audioLevel * 0.3 + newLevel * 0.7
                    } else {
                        // Slow decay
                        self.audioLevel = self.audioLevel * 0.85 + newLevel * 0.15
                    }
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
    
    func stopRecording(completion: @escaping (URL?, TimeInterval) -> Void) {
        timerTask?.cancel()
        timerTask = nil
        
        let url = audioRecorder?.url
        let duration = recordingDuration
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        completion(url, duration)
        
        // Reset
        recordingDuration = 0
        audioLevel = 0.0
    }
    
    func cancelRecording() {
        timerTask?.cancel()
        timerTask = nil
        
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        audioRecorder = nil
        isRecording = false
        recordingDuration = 0
        audioLevel = 0.0
    }
}
