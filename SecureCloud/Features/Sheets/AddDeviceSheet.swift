import SwiftUI

// MARK: - AddDeviceSheet (Screen 09)

struct AddDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddDeviceViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                ScrollView {
                    VStack(spacing: Tokens.Spacing.md) {

                        // QR placeholder card
                        VStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Tokens.Color.textQuaternary)
                                    .frame(width: 180, height: 180)
                                Image(systemName: "qrcode") // SF: qrcode
                                    .font(.system(size: 80))
                                    .foregroundStyle(Tokens.Color.textTertiary)
                            }

                            Text("Scan this QR code on the other device\nto link it to your vault.")
                                .font(Tokens.Font.body())
                                .foregroundStyle(Tokens.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard()

                        // OR divider
                        HStack {
                            Rectangle().fill(Tokens.Color.border).frame(height: 1)
                            Text("or enter code manually")
                                .font(Tokens.Font.caption2())
                                .foregroundStyle(Tokens.Color.textTertiary)
                                .padding(.horizontal, 8)
                            Rectangle().fill(Tokens.Color.border).frame(height: 1)
                        }

                        // Manual code entry
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pairing Code")
                                .font(Tokens.Font.caption1(.medium))
                                .foregroundStyle(Tokens.Color.textTertiary)
                                .textCase(.uppercase)
                                .kerning(0.5)

                            TextField("XXXX-XXXX", text: $vm.pairingCode)
                                .font(.custom("Inter", size: 20).weight(.semibold))
                                .foregroundStyle(Tokens.Color.textPrimary)
                                .multilineTextAlignment(.center)
                                .keyboardType(.asciiCapable)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .glassCard(radius: Tokens.Radius.cardSm)
                        }
                        .padding(.horizontal, Tokens.Spacing.lg)

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(Tokens.Font.caption1())
                                .foregroundStyle(Tokens.Color.red)
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Link Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Tokens.Font.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Link") {
                        Task {
                            await vm.link()
                            if vm.errorMessage == nil { dismiss() }
                        }
                    }
                    .font(Tokens.Font.body(.semibold))
                    .foregroundStyle(
                        vm.pairingCode.count < 9
                            ? Tokens.Color.textTertiary
                            : Tokens.Color.accent
                    )
                    .disabled(vm.pairingCode.count < 9)
                }
            }
        }
    }
}

// MARK: - AddDeviceViewModel

@MainActor
final class AddDeviceViewModel: ObservableObject {
    @Published var pairingCode: String = ""
    @Published var errorMessage: String?

    private let useCase: SyncUseCaseProtocol

    init(useCase: SyncUseCaseProtocol = DependencyContainer.shared.syncUseCase) {
        self.useCase = useCase
    }

    func link() async {
        let code = pairingCode.trimmingCharacters(in: .whitespaces)
        guard code.count >= 9 else {
            errorMessage = "Enter a valid pairing code."
            return
        }
        do {
            _ = try await useCase.addDevice(pairingCode: code, name: "Linked Device")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    AddDeviceSheet()
}
