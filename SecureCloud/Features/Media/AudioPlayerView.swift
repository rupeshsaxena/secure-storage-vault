import SwiftUI

// MARK: - AudioPlayerView (Screen 15 — Now Playing)

struct AudioPlayerView: View {
    let file: VaultFile
    @StateObject private var vm: AudioPlayerViewModel
    @State private var showQueue = false

    init(file: VaultFile) {
        self.file = file
        self._vm = StateObject(wrappedValue: AudioPlayerViewModel(file: file))
    }

    var body: some View {
        ZStack {
            ScreenBackground(style: .vault)

            if vm.isLoading {
                ProgressView("Decrypting…")
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
            } else if let error = vm.errorMessage {
                errorView(error)
            } else {
                playerContent
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet") // SF: list.bullet
                        .iconButton()
                }
            }
        }
        .navigationDestination(isPresented: $showQueue) {
            AudioQueueView(vm: vm)
        }
        .task { await vm.load() }
    }

    // MARK: - Player Content

    private var playerContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Artwork / waveform card
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 220, height: 220)
                    .shadow(color: Tokens.Color.accent.opacity(0.15), radius: 24, x: 0, y: 12)

                Image(systemName: "waveform") // SF: waveform
                    .font(.system(size: 72))
                    .foregroundStyle(Tokens.Color.accent.opacity(0.6))
                    .symbolEffect(.variableColor.iterative, isActive: vm.isPlaying)
            }

            Spacer().frame(height: 32)

            // Track info
            VStack(spacing: 6) {
                Text(vm.mediaItem?.title ?? file.name)
                    .font(Tokens.Font.title())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 32)

                if let artist = vm.mediaItem?.artist {
                    Text(artist)
                        .font(Tokens.Font.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }

                // Encrypted badge
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill") // SF: lock.fill
                        .font(.system(size: 9))
                    Text("AES-256-GCM")
                        .font(Tokens.Font.caption2())
                }
                .foregroundStyle(Tokens.Color.textTertiary)
                .padding(.top, 2)
            }
            .multilineTextAlignment(.center)

            Spacer().frame(height: 28)

            // Scrubber
            ScrubberView(
                progress: Binding(
                    get: { vm.progress },
                    set: { vm.seek(to: $0) }
                ),
                currentTime: vm.currentTime,
                remainingTime: vm.remainingTime
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 28)

            // Controls row
            HStack(spacing: 32) {
                // Shuffle
                Button { vm.toggleShuffle() } label: {
                    Image(systemName: "shuffle") // SF: shuffle
                        .font(.system(size: 18))
                        .foregroundStyle(
                            vm.isShuffled ? Tokens.Color.accent : Tokens.Color.textTertiary
                        )
                }
                .buttonStyle(.plain)

                // Previous
                Button { vm.previousTrack() } label: {
                    Image(systemName: "backward.fill") // SF: backward.fill
                        .font(.system(size: 28))
                        .foregroundStyle(Tokens.Color.textPrimary)
                }
                .buttonStyle(.plain)

                // Play/Pause
                Button { vm.togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(Tokens.Color.accent)
                            .frame(width: 64, height: 64)
                            .shadow(color: Tokens.Color.accent.opacity(0.30), radius: 12, x: 0, y: 6)
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill") // SF: pause.fill / play.fill
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                // Next
                Button { vm.nextTrack() } label: {
                    Image(systemName: "forward.fill") // SF: forward.fill
                        .font(.system(size: 28))
                        .foregroundStyle(Tokens.Color.textPrimary)
                }
                .buttonStyle(.plain)

                // Repeat
                Button { vm.cycleRepeat() } label: {
                    Image(systemName: repeatIcon) // SF: repeat / repeat.1
                        .font(.system(size: 18))
                        .foregroundStyle(
                            vm.repeatMode == .off ? Tokens.Color.textTertiary : Tokens.Color.accent
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            // Skip buttons
            HStack(spacing: 40) {
                Button { vm.skipBack() } label: {
                    Label("−15s", systemImage: "gobackward.15") // SF: gobackward.15
                        .font(Tokens.Font.caption1())
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)

                Button { vm.skipForward() } label: {
                    Label("+15s", systemImage: "goforward.15") // SF: goforward.15
                        .font(Tokens.Font.caption1())
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var repeatIcon: String {
        switch vm.repeatMode {
        case .off, .all: return "repeat"
        case .one:        return "repeat.1"
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle") // SF: exclamationmark.circle
                .font(.system(size: 40))
                .foregroundStyle(Tokens.Color.red)
            Text(message)
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - AudioQueueView (Screen 16)

struct AudioQueueView: View {
    @ObservedObject var vm: AudioPlayerViewModel

    var body: some View {
        ZStack {
            ScreenBackground(style: .vault)

            if vm.queue.isEmpty {
                Text("Queue is empty")
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(vm.queue.enumerated()), id: \.element.id) { index, file in
                            Button {
                                vm.currentIndex = index
                            } label: {
                                HStack(spacing: 10) {
                                    FileRowView(file: file)
                                    if index == vm.currentIndex {
                                        Image(systemName: "waveform") // SF: waveform
                                            .font(.system(size: 14))
                                            .foregroundStyle(Tokens.Color.accent)
                                            .symbolEffect(.variableColor.iterative, isActive: vm.isPlaying)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }
            }
        }
        .navigationTitle("Queue")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AudioPlayerView(file: VaultFile.samples[3])
            .environmentObject(AppState())
    }
}
