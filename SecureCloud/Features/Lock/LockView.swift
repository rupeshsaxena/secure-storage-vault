import SwiftUI

// MARK: - LockView (Screen 10 — Biometric / Passcode Gate)

struct LockView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = LockViewModel()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "F0F2F5"), Color(hex: "E8EBF2")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon + branding
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Tokens.Color.accent)
                            .frame(width: 80, height: 80)
                            .shadow(color: Tokens.Color.accent.opacity(0.30), radius: 16, x: 0, y: 8)
                        Image(systemName: "lock.shield.fill") // SF: lock.shield.fill
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 4) {
                        Text("SecureCloud")
                            .font(Tokens.Font.largeTitle())
                            .foregroundStyle(Tokens.Color.textPrimary)
                        Text("Your encrypted vault")
                            .font(Tokens.Font.body())
                            .foregroundStyle(Tokens.Color.textSecondary)
                    }
                }

                Spacer()

                // Auth section
                VStack(spacing: 20) {
                    if vm.showFallback {
                        passcodeSection
                    } else {
                        biometricSection
                    }

                    // Error message
                    if vm.authFailed {
                        Text("Authentication failed. Try again.")
                            .font(Tokens.Font.footnote())
                            .foregroundStyle(Tokens.Color.red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Footer
                Text("Zero-knowledge · AES-256-GCM")
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            // Auto-trigger biometric on appear
            if !vm.showFallback {
                vm.authenticate { appState.unlockVault() }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showFallback)
        .animation(.easeInOut(duration: 0.2), value: vm.authFailed)
    }

    // MARK: - Biometric Section

    private var biometricSection: some View {
        VStack(spacing: 16) {
            Button {
                vm.authenticate { appState.unlockVault() }
            } label: {
                HStack(spacing: 10) {
                    if vm.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: vm.biometryType.icon) // SF: faceid / touchid
                            .font(.system(size: 18))
                    }
                    Text(vm.biometryType.label)
                        .font(Tokens.Font.subheadline())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Color.accent)
                        .shadow(color: Tokens.Color.accent.opacity(0.25), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isAuthenticating)

            Button("Use Passcode") {
                vm.showFallback = true
            }
            .font(Tokens.Font.body())
            .foregroundStyle(Tokens.Color.textSecondary)
        }
    }

    // MARK: - Passcode Section

    private var passcodeSection: some View {
        VStack(spacing: 16) {
            Text("Enter Passcode")
                .font(Tokens.Font.subheadline())
                .foregroundStyle(Tokens.Color.textSecondary)

            // PIN dots display
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < vm.pinInput.count ? Tokens.Color.accent : Tokens.Color.border)
                        .frame(width: 12, height: 12)
                        .animation(.spring(response: 0.2), value: vm.pinInput.count)
                }
            }

            // Hidden text field for keyboard input
            SecureField("", text: $vm.pinInput)
                .keyboardType(.numberPad)
                .frame(height: 0)
                .opacity(0.01)   // Invisible but focusable
                .onChange(of: vm.pinInput) { _, newVal in
                    // Cap at 6 digits
                    if newVal.count > 6 {
                        vm.pinInput = String(newVal.prefix(6))
                    }
                    if vm.pinInput.count == 6 {
                        vm.authenticateWithPin(pin: vm.pinInput) {
                            appState.unlockVault()
                        }
                        if vm.authFailed { vm.clearPin() }
                    }
                }

            if vm.biometryType != .none {
                Button("Use \(vm.biometryType.label.replacingOccurrences(of: "Use ", with: ""))") {
                    vm.showFallback = false
                    vm.clearPin()
                }
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.accent)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let appState = AppState()
    return LockView()
        .environmentObject(appState)
}
