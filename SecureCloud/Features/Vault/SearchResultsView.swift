import SwiftUI

// MARK: - SearchResultsView (Screen 14)

struct SearchResultsView: View {
    @Binding var query: String
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        ZStack {
            ScreenBackground(style: .vault)

            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.results.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(vm.results) { file in
                                NavigationLink(value: file) {
                                    FileRowView(file: file)
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
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: VaultFile.self) { file in
            if file.fileType.isAudio {
                AudioPlayerView(file: file)
            } else if file.fileType.isVideo {
                VideoPlayerView(file: file)
            } else {
                FileDetailView(file: file)
            }
        }
        .task(id: query) {
            await vm.search(query: query)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass") // SF: magnifyingglass
                .font(.system(size: 40))
                .foregroundStyle(Tokens.Color.textTertiary)
            Text(query.isEmpty ? "Start typing to search" : "No results for "\(query)"")
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - SearchViewModel

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var results: [VaultFile] = []
    @Published var isLoading = false

    private let useCase: VaultUseCaseProtocol

    init(useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase) {
        self.useCase = useCase
    }

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        isLoading = true
        results = (try? await useCase.search(query: query)) ?? []
        isLoading = false
    }
}
