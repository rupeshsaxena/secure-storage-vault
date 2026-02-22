import SwiftUI

// MARK: - VaultView (Screens 01 · Syncing, 02 · Protected, 03 · Empty)

struct VaultView: View {
    @StateObject private var vm = VaultViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showAddFile = false
    @State private var showNewFolder = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenBackground(style: .vault)

            ScrollView {
                VStack(spacing: Tokens.Spacing.md) {

                    // Search bar
                    SearchBarView(text: $vm.searchText, placeholder: "Search files…")
                        .onChange(of: vm.searchText) { _, _ in
                            Task { await vm.performSearch() }
                        }

                    // Status banner
                    SyncBanner(state: vm.syncState)

                    // Filter chips
                    ChipBar(options: FileFilter.allCases, selected: $vm.activeFilter)

                    if vm.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if vm.filteredFiles.isEmpty && vm.folders.isEmpty {
                        // Screen 03 — Empty state
                        VaultEmptyView { showAddFile = true }
                    } else {
                        // Folders section
                        if !vm.folders.isEmpty {
                            SectionHeader(title: "Folders")
                            FolderRow(folders: vm.folders)
                        }

                        // Files section
                        if !vm.filteredFiles.isEmpty {
                            SectionHeader(title: "Files", count: vm.filteredFiles.count)
                            LazyVStack(spacing: 4) {
                                ForEach(vm.filteredFiles) { file in
                                    NavigationLink(value: file) {
                                        FileRowView(file: file)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await vm.deleteFile(id: file.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash") // SF: trash
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.top, 8)
                .padding(.bottom, 90) // clear floating tab bar
            }
        }
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        vm.showSortSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.filter") // SF: line.3.horizontal.filter
                            .iconButton()
                    }

                    Button {
                        showAddFile = true
                    } label: {
                        Image(systemName: "plus") // SF: plus
                            .iconButtonAccent()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddFile) {
            AddFileSheet()
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet()
        }
        .navigationDestination(for: VaultFile.self) { file in
            if file.fileType.isAudio {
                AudioPlayerView(file: file)
            } else if file.fileType.isVideo {
                VideoPlayerView(file: file)
            } else {
                FileDetailView(file: file)
            }
        }
        .navigationDestination(for: VaultFolder.self) { folder in
            FolderContentsView(folder: folder)
        }
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load()
        }
    }
}

// MARK: - VaultEmptyView (Screen 03)

struct VaultEmptyView: View {
    let onAddFile: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.doc.fill") // SF: lock.doc.fill
                    .font(.system(size: 30))
                    .foregroundStyle(Tokens.Color.accent)
            }
            .padding(.top, 40)

            VStack(spacing: 6) {
                Text("Vault is empty")
                    .font(Tokens.Font.headline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text("Add your first encrypted file to get started.")
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAddFile) {
                Label("Add File", systemImage: "plus") // SF: plus
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Tokens.Color.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    var count: Int?
    var action: (() -> Void)?
    var actionLabel: String = "See all"

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Tokens.Font.label())
                .foregroundStyle(Tokens.Color.textTertiary)
                .kerning(0.8)

            if let count {
                Text("(\(count))")
                    .font(Tokens.Font.label())
                    .foregroundStyle(Tokens.Color.textQuaternary)
            }

            Spacer()

            if let action {
                Button(actionLabel, action: action)
                    .font(Tokens.Font.caption1())
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
    }
}

// MARK: - Toolbar icon button styles

extension Image {
    func iconButton() -> some View {
        self
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Tokens.Color.textSecondary)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Tokens.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Tokens.Color.border, lineWidth: 1)
                    )
            )
    }

    func iconButtonAccent() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Tokens.Color.accent)
            )
    }
}

// MARK: - SearchBarView

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search…"
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass") // SF: magnifyingglass
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Color.textTertiary)

            TextField(placeholder, text: $text)
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textPrimary)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill") // SF: xmark.circle.fill
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassCard(radius: Tokens.Radius.cardSm)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VaultView()
            .environmentObject(AppState())
    }
}
