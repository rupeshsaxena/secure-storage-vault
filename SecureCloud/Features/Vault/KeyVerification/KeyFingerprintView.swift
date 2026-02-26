import SwiftUI

// MARK: - KeyFingerprintView
//
// Displays a contact's full 64-character SHA-256 fingerprint (grouped as
// 8 blocks of 4) for out-of-band MITM verification — shown on BOTH devices.
// The user reads the code aloud or compares screens side-by-side.

struct KeyFingerprintView: View {
    let contact: TrustedContact
    let myIdentity: VaultIdentity
    var onVerified:  (() -> Void)? = nil
    var onDismiss:   (() -> Void)? = nil

    @State private var showFullFingerprint = false

    // ── Pre-computed values ────────────────────────────────────────────────

    private var shortCode: String { contact.shortFingerprint }

    private var fullFingerprint: String { contact.fingerprint }

    private var fullFingerprintGroups: [String] {
        // Split into 8 blocks of 4 characters for better readability
        stride(from: 0, to: fullFingerprint.count, by: 9).map { i -> String in
            // The fingerprintString already has spaces every 4 chars; just return
            String(fullFingerprint)
        }
        // Actually: return the pre-formatted string split on spaces
        return fullFingerprint.components(separatedBy: " ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)

                ScrollView {
                    VStack(spacing: Tokens.Spacing.xxl) {

                        // ── Header: Avatar + name ──────────────────────────────
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Tokens.Color.accentDim)
                                    .frame(width: 72, height: 72)
                                Text(contact.displayName.prefix(2).uppercased())
                                    .font(.custom("Inter", size: 24).weight(.semibold))
                                    .foregroundStyle(Tokens.Color.accent)
                            }
                            Text(contact.displayName)
                                .font(Tokens.Font.headline())
                                .foregroundStyle(Tokens.Color.textPrimary)

                            verificationBadge
                        }

                        // ── Instruction ────────────────────────────────────────
                        instructionCard

                        // ── Short fingerprint (default) ────────────────────────
                        shortFingerprintCard

                        // ── Full fingerprint (expandable) ──────────────────────
                        fullFingerprintCard

                        // ── Actions ────────────────────────────────────────────
                        actionButtons

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, Tokens.Spacing.xl)
                }
            }
            .navigationTitle("Verify Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss?() }
                        .font(Tokens.Font.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var verificationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: contact.verificationMethod.icon)
                .font(.system(size: 12))
            Text(contact.verificationMethod.label)
                .font(Tokens.Font.caption1())
        }
        .foregroundStyle(
            contact.verificationMethod.isVerified ? Tokens.Color.green : Tokens.Color.orange
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(contact.verificationMethod.isVerified
                    ? Tokens.Color.greenDim
                    : Tokens.Color.orange.opacity(0.10))
        )
    }

    private var instructionCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")  // SF: shield.lefthalf.filled
                .font(.system(size: 20))
                .foregroundStyle(Tokens.Color.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Verify Out-of-Band")
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text("Compare this safety code with \(contact.displayName) in person, by phone call, or via a trusted channel. If the codes match, this identity is authentic.")
                    .font(Tokens.Font.caption1())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassCard()
    }

    private var shortFingerprintCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("SAFETY CODE")
                    .font(Tokens.Font.label(.semibold))
                    .foregroundStyle(Tokens.Color.textTertiary)
                Spacer()
                Text("4 groups · 8 chars")
                    .font(Tokens.Font.label())
                    .foregroundStyle(Tokens.Color.textTertiary)
            }

            // Large monospace groups
            HStack(spacing: 16) {
                ForEach(shortCode.components(separatedBy: "-"), id: \.self) { group in
                    Text(group)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Tokens.Color.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.cardSm, style: .continuous)
                    .fill(Tokens.Color.accentDim)
            )
        }
        .padding(14)
        .glassCard()
    }

    private var fullFingerprintCard: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFullFingerprint.toggle()
                }
            } label: {
                HStack {
                    Text("FULL FINGERPRINT")
                        .font(Tokens.Font.label(.semibold))
                        .foregroundStyle(Tokens.Color.textTertiary)
                    Spacer()
                    Image(systemName: showFullFingerprint
                          ? "chevron.up"
                          : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tokens.Color.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if showFullFingerprint {
                let groups = fullFingerprint.components(separatedBy: " ")
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 4),
                    spacing: 8
                ) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Text(group)
                            .font(.system(.footnote, design: .monospaced).weight(.medium))
                            .foregroundStyle(Tokens.Color.textPrimary)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Tokens.Color.textQuaternary)
                            )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .glassCard()
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onVerified?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")  // SF: checkmark.shield.fill
                        .font(.system(size: 14))
                    Text("Keys Match — Mark as Verified")
                        .font(Tokens.Font.subheadline())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Color.green)
                )
            }
            .buttonStyle(.plain)

            Button {
                onDismiss?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")  // SF: xmark.circle
                        .font(.system(size: 14))
                    Text("Codes Don't Match")
                        .font(Tokens.Font.subheadline())
                }
                .foregroundStyle(Tokens.Color.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Color.redDim)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
