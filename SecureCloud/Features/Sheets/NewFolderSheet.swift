import SwiftUI

// MARK: - NewFolderSheet (Screen 08)

struct NewFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = NewFolderViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                VStack(spacing: Tokens.Spacing.md) {
                    // Folder icon preview
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Tokens.Color.accentDim)
                                .frame(width: 72, height: 72)
                            Image(systemName: "folder.fill") // SF: folder.fill
                                .font(.system(size: 32))
                                .foregroundStyle(Tokens.Color.accent)
                        }

                        Text(vm.name.isEmpty ? "New Folder" : vm.name)
                            .font(Tokens.Font.headline())
                            .foregroundStyle(
                                vm.name.isEmpty ? Tokens.Color.textTertiary : Tokens.Color.textPrimary
                            )
                            .animation(.easeInOut(duration: 0.15), value: vm.name)
                    }
                    .padding(.top, 24)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folder Name")
                            .font(Tokens.Font.caption1(.medium))
                            .foregroundStyle(Tokens.Color.textTertiary)
                            .textCase(.uppercase)
                            .kerning(0.5)

                        TextField("My Folder", text: $vm.name)
                            .font(Tokens.Font.body())
                            .foregroundStyle(Tokens.Color.textPrimary)
                            .focused($isFocused)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassCard(radius: Tokens.Radius.cardSm)
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(Tokens.Font.caption1())
                            .foregroundStyle(Tokens.Color.red)
                    }

                    Spacer()
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Tokens.Font.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task {
                            await vm.create()
                            if vm.errorMessage == nil { dismiss() }
                        }
                    }
                    .font(Tokens.Font.body(.semibold))
                    .foregroundStyle(
                        vm.name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Tokens.Color.textTertiary
                            : Tokens.Color.accent
                    )
                    .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - NewFolderViewModel

@MainActor
final class NewFolderViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var errorMessage: String?

    private let useCase: VaultUseCaseProtocol

    init(useCase: VaultUseCaseProtocol = DependencyContainer.shared.vaultUseCase) {
        self.useCase = useCase
    }

    func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a folder name."
            return
        }
        do {
            _ = try await useCase.createFolder(name: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    NewFolderSheet()
}
