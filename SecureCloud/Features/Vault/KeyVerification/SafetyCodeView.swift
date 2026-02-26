import SwiftUI

// MARK: - SafetyCodeView
//
// Shown immediately after generating a recipient FEKBlock via `addRecipient`.
// Displays the 8-character safety code (SHA-256(ephPK ‖ recipientPK).prefix(4))
// that the recipient should see on their device as well.
//
// The sender reads the code aloud to the recipient over a trusted channel
// (phone call, in person) before the recipient decrypts the file.

struct SafetyCodeView: View {
    let safetyCode: String          // "A1B2 C3D4"
    let recipientName: String
    let filename: String
    var onDone: (() -> Void)? = nil

    @State private var codeCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                ScrollView {
                    VStack(spacing: Tokens.Spacing.xxl) {

                        // ── Shield icon ────────────────────────────────────────
                        ZStack {
                            Circle()
                                .fill(Tokens.Color.greenDim)
                                .frame(width: 80, height: 80)
                            Image(systemName: "lock.shield.fill")  // SF: lock.shield.fill
                                .font(.system(size: 36))
                                .foregroundStyle(Tokens.Color.green)
                        }

                        // ── Title + subtitle ───────────────────────────────────
                        VStack(spacing: 6) {
                            Text("Share Grant Created")
                                .font(Tokens.Font.headline())
                                .foregroundStyle(Tokens.Color.textPrimary)
                            Text("\"\(filename)\" was securely granted to \(recipientName)")
                                .font(Tokens.Font.body())
                                .foregroundStyle(Tokens.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // ── Safety code display ────────────────────────────────
                        safetyCodeCard

                        // ── How it works ───────────────────────────────────────
                        howItWorksCard

                        // ── Done button ────────────────────────────────────────
                        Button {
                            onDone?()
                        } label: {
                            Text("Done")
                                .font(Tokens.Font.subheadline())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Tokens.Color.accent)
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, Tokens.Spacing.xl)
                }
            }
            .navigationTitle("Verify Share")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sub-views

    private var safetyCodeCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("SAFETY CODE")
                    .font(Tokens.Font.label(.semibold))
                    .foregroundStyle(Tokens.Color.textTertiary)
                Spacer()
                Button {
                    UIPasteboard.general.string = safetyCode.replacingOccurrences(of: " ", with: "")
                    withAnimation { codeCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { codeCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")  // SF: doc.on.doc
                            .font(.system(size: 11))
                        Text(codeCopied ? "Copied!" : "Copy")
                            .font(Tokens.Font.caption1())
                    }
                    .foregroundStyle(codeCopied ? Tokens.Color.green : Tokens.Color.accent)
                }
                .buttonStyle(.plain)
            }

            // Large code display
            HStack(spacing: 20) {
                ForEach(safetyCode.components(separatedBy: " "), id: \.self) { part in
                    Text(part)
                        .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                        .foregroundStyle(Tokens.Color.accent)
                        .tracking(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .fill(Tokens.Color.accentDim)
            )

            // Instruction
            Label(
                "Read this code to \(recipientName) over a trusted channel.",
                systemImage: "phone.fill"  // SF: phone.fill
            )
            .font(Tokens.Font.caption1())
            .foregroundStyle(Tokens.Color.textSecondary)
        }
        .padding(14)
        .glassCard()
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HOW IT WORKS")
                .font(Tokens.Font.label(.semibold))
                .foregroundStyle(Tokens.Color.textTertiary)

            stepRow(
                number: "1",
                icon: "key.fill",  // SF: key.fill
                text: "The file's encryption key was wrapped under \(recipientName)'s public key — only their device can unwrap it."
            )
            stepRow(
                number: "2",
                icon: "signature",  // SF: signature
                text: "This grant is signed with your private key. Any tampering will be detected automatically."
            )
            stepRow(
                number: "3",
                icon: "speaker.wave.2.fill",  // SF: speaker.wave.2.fill
                text: "The safety code above confirms the correct keys were used. Verify with \(recipientName) before they open the file."
            )
        }
        .padding(14)
        .glassCard()
    }

    private func stepRow(number: String, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Color.accent)
            }
            Text(text)
                .font(Tokens.Font.caption1())
                .foregroundStyle(Tokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
