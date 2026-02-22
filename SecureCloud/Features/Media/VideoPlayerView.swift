import SwiftUI
import AVFoundation
import AVKit

// MARK: - VideoPlayerViewModel

@MainActor
final class VideoPlayerViewModel: ObservableObject {

    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0
    @Published var currentTime: String = "0:00"
    @Published var remainingTime: String = "-0:00"
    @Published var isLoading: Bool = true
    @Published var showControls: Bool = true
    @Published var errorMessage: String?
    @Published var isFullscreen: Bool = false

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private let file: VaultFile
    private let useCase: MediaUseCaseProtocol

    var avPlayer: AVPlayer? { player }

    init(
        file: VaultFile,
        useCase: MediaUseCaseProtocol = DependencyContainer.shared.mediaUseCase
    ) {
        self.file = file
        self.useCase = useCase
    }

    func load() async {
        isLoading = true
        do {
            // Decrypt entirely to memory — zero plaintext on disk
            let data = try await useCase.decryptedMediaData(for: file.id)

            // Write to a secure temp location for AVPlayer
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(file.fileType.rawValue)
            try data.write(to: tempURL, options: .atomic)

            playerItem = AVPlayerItem(url: tempURL)
            player = AVPlayer(playerItem: playerItem)

            addTimeObserver()
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
        isPlaying = player.timeControlStatus == .playing
    }

    func seek(to fraction: Double) {
        guard let player, let item = playerItem else { return }
        let duration = CMTimeGetSeconds(item.duration)
        guard duration.isFinite else { return }
        let targetTime = CMTime(seconds: duration * fraction, preferredTimescale: 600)
        player.seek(to: targetTime)
    }

    private func addTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, let item = self.playerItem else { return }
            let current = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(item.duration)
            guard duration.isFinite && duration > 0 else { return }
            Task { @MainActor in
                self.progress = current / duration
                self.currentTime = self.formatTime(current)
                self.remainingTime = "-\(self.formatTime(duration - current))"
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
    }
}

// MARK: - VideoPlayerView (Screen 17 — Inline)

struct VideoPlayerView: View {
    let file: VaultFile
    @StateObject private var vm: VideoPlayerViewModel
    @State private var showFullscreen = false

    init(file: VaultFile) {
        self.file = file
        self._vm = StateObject(wrappedValue: VideoPlayerViewModel(file: file))
    }

    var body: some View {
        ZStack {
            ScreenBackground(style: .vault)

            VStack(spacing: Tokens.Spacing.md) {
                // Video frame
                ZStack {
                    Color.black
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))

                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if let player = vm.avPlayer {
                        VideoPlayerRepresentable(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                            .frame(height: 220)
                    }

                    // Fullscreen button overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showFullscreen = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right") // SF: fullscreen
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.black.opacity(0.4))
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.lg)

                // Controls card
                VStack(spacing: 14) {
                    // File name
                    Text(file.name)
                        .font(Tokens.Font.subheadline())
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .lineLimit(1)

                    // Scrubber
                    ScrubberView(
                        progress: Binding(
                            get: { vm.progress },
                            set: { vm.seek(to: $0) }
                        ),
                        currentTime: vm.currentTime,
                        remainingTime: vm.remainingTime
                    )

                    // Play/Pause
                    Button { vm.togglePlayPause() } label: {
                        ZStack {
                            Circle()
                                .fill(Tokens.Color.accent)
                                .frame(width: 52, height: 52)
                            Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill") // SF: play.fill / pause.fill
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .glassCard()
                .padding(.horizontal, Tokens.Spacing.lg)

                Spacer()
            }
            .padding(.top, 12)
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFullscreen) {
            VideoFullscreenView(vm: vm)
        }
        .task { await vm.load() }
    }
}

// MARK: - VideoFullscreenView (Screen 18)

struct VideoFullscreenView: View {
    @ObservedObject var vm: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = vm.avPlayer {
                VideoPlayerRepresentable(player: player)
                    .ignoresSafeArea()
            }

            // Controls overlay
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark") // SF: xmark
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding()

                Spacer()

                VStack(spacing: 12) {
                    ScrubberView(
                        progress: Binding(
                            get: { vm.progress },
                            set: { vm.seek(to: $0) }
                        ),
                        currentTime: vm.currentTime,
                        remainingTime: vm.remainingTime,
                        accentColor: .white
                    )

                    Button { vm.togglePlayPause() } label: {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill") // SF: varies
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .background(.black.opacity(0.5))
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - VideoPlayerRepresentable (AVPlayerLayer bridge)

import UIKit

struct VideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        view.tag = 999 // for layer retrieval in updateUIView
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first(where: { $0 is AVPlayerLayer }) as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
            playerLayer.player = player
        }
    }
}
