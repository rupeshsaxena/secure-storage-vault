import Foundation
import AVFoundation
import Combine

// MARK: - AudioPlayerViewModel

@MainActor
final class AudioPlayerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0          // 0.0 – 1.0
    @Published var currentTime: String = "0:00"
    @Published var remainingTime: String = "-0:00"
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var mediaItem: MediaItem?
    @Published var queue: [VaultFile] = []
    @Published var currentIndex: Int = 0
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off

    // MARK: - RepeatMode

    enum RepeatMode { case off, one, all }

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private let file: VaultFile
    private let useCase: MediaUseCaseProtocol

    init(
        file: VaultFile,
        useCase: MediaUseCaseProtocol = DependencyContainer.shared.mediaUseCase
    ) {
        self.file = file
        self.useCase = useCase
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // Decrypt to memory — never writes plaintext to disk
            let data = try await useCase.decryptedMediaData(for: file.id)
            mediaItem = try await useCase.fetchMediaItem(for: file.id)

            // Set up AVAudioPlayer from in-memory data
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()

            updateTimeLabels()
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying = player.isPlaying
    }

    func seek(to newProgress: Double) {
        guard let player else { return }
        player.currentTime = player.duration * newProgress
        updateTimeLabels()
    }

    func skipForward(seconds: TimeInterval = 15) {
        guard let player else { return }
        player.currentTime = min(player.currentTime + seconds, player.duration)
        updateTimeLabels()
    }

    func skipBack(seconds: TimeInterval = 15) {
        guard let player else { return }
        player.currentTime = max(player.currentTime - seconds, 0)
        updateTimeLabels()
    }

    func nextTrack() {
        guard currentIndex < queue.count - 1 else {
            if repeatMode == .all { currentIndex = 0 }
            return
        }
        currentIndex += 1
    }

    func previousTrack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func toggleShuffle() { isShuffled.toggle() }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTimeLabels()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimeLabels() {
        guard let player else { return }
        let current = player.currentTime
        let duration = player.duration
        progress = duration > 0 ? current / duration : 0
        currentTime = formatTime(current)
        remainingTime = "-\(formatTime(duration - current))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    deinit {
        timer?.invalidate()
        player?.stop()
    }
}
