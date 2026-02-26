import SwiftUI

// MARK: - ContactShareView
//
// Full SE-based encrypted file share flow.
//
// Step 1 — Contact picker: shows trusted contacts; warns about unverified ones.
// Step 2 — Confirmation: review recipient + show safety code after grant created.
// Step 3 — Success or error feedback.

struct ContactShareView: View {
    let file: VaultFile
    var onDismiss: (() -> Void)? = nil

    @StateObject private var vm: ContactShareViewModel
    @State private var showFingerprintFor: TrustedContact? = nil
    @State private var showSafetyCode = false

    init(file: VaultFile, onDismiss: (() -> Void)? = nil) {
        self.file = file
        self.onDismiss = onDismiss
        self._vm = StateObject(wrappedValue: ContactShareViewModel(file: file))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .sheet)
                stepContent
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(item: $showFingerprintFor) { contact in
                if let identity = vm.myIdentity {
                    KeyFingerprintView(
                        contact: contact,
                        myIdentity: identity,
                        onVerified: {
                            Task { await vm.markContactVerified(contact) }
                            showFingerprintFor = nil
                        },
                        onDismiss: { showFingerprintFor = nil }
                    )
                }
            }
            .sheet(isPresented: $showSafetyCode) {
                if let code = vm.safetyCode, let recipient = vm.selectedContact {
                    SafetyCodeView(
                        safetyCode: code,
                        recipientName: recipient.displayName,
                        filename: file.name,
                        onDone: {
                            showSafetyCode = false
                            onDismiss?()
                        }
                    )
                }
            }
            .task { await vm.loadContacts() }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .selectContact:
            contactListContent
        case .confirm:
            confirmContent
        case .success:
            successContent
        case .error(let msg):
            errorContent(msg)
        }
    }

    // ── Step 1: Contact list ───────────────────────────────────────────────

    private var contactListContent: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.md) {

                // File preview
                fileCard

                // Section header
                HStack {
                    Text("TRUSTED CONTACTS")
                        .font(Tokens.Font.label(.semibold))
                        .foregroundStyle(Tokens.Color.textTertiary)
                    Spacer()
                    NavigationLink {
                        // Future: AddContactView
                    } label: {
                        Label("Add", systemImage: "plus")  // SF: plus
                            .font(Tokens.Font.caption1())
                            .foregroundStyle(Tokens.Color.accent)
                    }
                }
                .padding(.horizontal, 2)

                if vm.isLoadingContacts {
                    ProgressView()
                        .padding(.vertical, 32)
                } else if vm.contacts.isEmpty {
                    emptyContactsPlaceholder
                } else {
                    ForEach(vm.contacts) { contact in
                        contactRow(contact)
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.top, Tokens.Spacing.xl)
        }
    }

    private func contactRow(_ contact: TrustedContact) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(contact.verificationMethod.isVerified
                          ? Tokens.Color.greenDim
                          : Tokens.Color.orange.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(contact.displayName.prefix(2).uppercased())
                    .font(.custom("Inter", size: 16).weight(.semibold))
                    .foregroundStyle(contact.verificationMethod.isVerified
                                     ? Tokens.Color.green
                                     : Tokens.Color.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: contact.verificationMethod.icon)
                        .font(.system(size: 10))
                    Text(contact.verificationMethod.label)
                        .font(Tokens.Font.caption2())
                }
                .foregroundStyle(contact.verificationMethod.isVerified
                                 ? Tokens.Color.green
                                 : Tokens.Color.orange)
            }

            Spacer()

            // Verify / Select button
            if contact.verificationMethod.isVerified {
                Button {
                    vm.selectedContact = contact
                    vm.step = .confirm
                } label: {
                    Text("Share")
                        .font(Tokens.Font.caption1(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Tokens.Color.accent)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showFingerprintFor = contact
                } label: {
                    Text("Verify")
                        .font(Tokens.Font.caption1(.semibold))
                        .foregroundStyle(Tokens.Color.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Tokens.Color.orange.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassCard()
    }

    private var emptyContactsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")  // SF: person.2.slash
                .font(.system(size: 36))
                .foregroundStyle(Tokens.Color.textTertiary)
            Text("No Trusted Contacts")
                .font(Tokens.Font.subheadline())
                .foregroundStyle(Tokens.Color.textPrimary)
            Text("Add a contact by scanning their QR code or importing their identity.")
                .font(Tokens.Font.caption1())
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassCard()
    }

    // ── Step 2: Confirm ────────────────────────────────────────────────────

    private var confirmContent: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            Spacer().frame(height: 8)

            guard let contact = vm.selectedContact else {
                return AnyView(EmptyView())
            }

            return AnyView(
                ScrollView {
                    VStack(spacing: Tokens.Spacing.xl) {
                        fileCard

                        // Recipient card
                        VStack(spacing: 12) {
                            HStack {
                                Text("RECIPIENT")
                                    .font(Tokens.Font.label(.semibold))
                                    .foregroundStyle(Tokens.Color.textTertiary)
                                Spacer()
                                Button("Change") {
                                    vm.step = .selectContact
                                }
                                .font(Tokens.Font.caption1())
                                .foregroundStyle(Tokens.Color.accent)
                            }

                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Tokens.Color.greenDim)
                                        .frame(width: 44, height: 44)
                                    Text(contact.displayName.prefix(2).uppercased())
                                        .font(.custom("Inter", size: 16).weight(.semibold))
                                        .foregroundStyle(Tokens.Color.green)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.displayName)
                                        .font(Tokens.Font.subheadline())
                                        .foregroundStyle(Tokens.Color.textPrimary)
                                    Text(contact.shortFingerprint)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Tokens.Color.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.shield.fill")  // SF: checkmark.shield.fill
                                    .foregroundStyle(Tokens.Color.green)
                            }
                        }
                        .padding(14)
                        .glassCard()

                        // Security note
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")  // SF: info.circle
                                .foregroundStyle(Tokens.Color.accent)
                            Text("Only \(contact.displayName)'s Secure Enclave can decrypt the key grant. The original file remains encrypted.")
                                .font(Tokens.Font.caption1())
                                .foregroundStyle(Tokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .glassCard()
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                                .stroke(Tokens.Color.accent.opacity(0.15), lineWidth: 1)
                        )

                        // Grant button
                        Button {
                            Task {
                                await vm.grantAccess()
                                if vm.safetyCode != nil {
                                    showSafetyCode = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isGranting {
                                    ProgressView().tint(.white).scaleEffect(0.85)
                                } else {
                                    Image(systemName: "key.fill")  // SF: key.fill
                                        .font(.system(size: 14))
                                }
                                Text(vm.isGranting ? "Granting Access…" : "Grant Access to \(contact.displayName)")
                                    .font(Tokens.Font.subheadline())
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Tokens.Color.accent)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isGranting)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .padding(.top, Tokens.Spacing.xl)
                }
            )
        }
    }

    // ── Step 3: Success ────────────────────────────────────────────────────

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tokens.Color.greenDim)
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")  // SF: checkmark.circle.fill
                    .font(.system(size: 40))
                    .foregroundStyle(Tokens.Color.green)
            }
            VStack(spacing: 8) {
                Text("Access Granted")
                    .font(Tokens.Font.headline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text("\(vm.selectedContact?.displayName ?? "Recipient") can now decrypt \"\(file.name)\".")
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button { onDismiss?() } label: {
                Text("Done")
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Tokens.Color.green)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Tokens.Spacing.lg)
            Spacer()
        }
    }

    // ── Error ──────────────────────────────────────────────────────────────

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tokens.Color.redDim)
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")  // SF: exclamationmark.triangle.fill
                    .font(.system(size: 36))
                    .foregroundStyle(Tokens.Color.red)
            }
            VStack(spacing: 8) {
                Text("Share Failed")
                    .font(Tokens.Font.headline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text(message)
                    .font(Tokens.Font.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button { vm.step = .selectContact } label: {
                Text("Try Again")
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(Tokens.Color.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Tokens.Color.accentDim)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Tokens.Spacing.lg)
            Spacer()
        }
    }

    // MARK: - Shared

    private var fileCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.icon)
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 44, height: 44)
                Image(systemName: file.fileType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Tokens.Color.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(Tokens.Font.subheadline())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
            }
            Spacer()
            Image(systemName: "lock.fill")  // SF: lock.fill
                .font(.system(size: 12))
                .foregroundStyle(Tokens.Color.green)
        }
        .padding(12)
        .glassCard()
    }

    private var navigationTitle: String {
        switch vm.step {
        case .selectContact: return "Share Encrypted"
        case .confirm:       return "Confirm Share"
        case .success:       return "Share Complete"
        case .error:         return "Share Failed"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { onDismiss?() }
                .font(Tokens.Font.body())
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }
}

// MARK: - ContactShareViewModel

@MainActor
final class ContactShareViewModel: ObservableObject {

    enum Step {
        case selectContact
        case confirm
        case success
        case error(String)
    }

    let file: VaultFile

    @Published var step: Step = .selectContact
    @Published var contacts: [TrustedContact] = []
    @Published var selectedContact: TrustedContact? = nil
    @Published var isLoadingContacts = false
    @Published var isGranting = false
    @Published var safetyCode: String? = nil
    @Published var myIdentity: VaultIdentity? = nil

    private let container = DependencyContainer.shared

    init(file: VaultFile) {
        self.file = file
    }

    func loadContacts() async {
        isLoadingContacts = true
        defer { isLoadingContacts = false }

        do {
            myIdentity = try container.seService.loadIdentity()
            contacts   = try await container.trustedContactsStore.allContacts()
        } catch {
            // No identity yet — contacts list stays empty; identity setup flow
            // should be triggered from Settings before this view is reached.
        }
    }

    func grantAccess() async {
        guard let contact = selectedContact else { return }

        isGranting = true
        defer { isGranting = false }

        do {
            let keyPair       = try container.seService.loadKeyPair()
            let encryptedData = try await container.vaultRepository.loadEncryptedData(for: file.id)

            let (updatedData, code) = try container.seEncryptionService.addRecipient(
                to:               encryptedData,
                recipientContact: contact,
                ownerKeyPair:     keyPair
            )

            // Persist the updated file (header now contains recipient FEKBlock)
            try await container.vaultRepository.saveEncryptedData(updatedData, for: file.id)

            safetyCode = code
            step = .success
        } catch SEEncryptionError.contactNotVerified {
            step = .error("Please verify \(contact.displayName)'s identity before sharing.")
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    func markContactVerified(_ contact: TrustedContact) async {
        do {
            try await container.trustedContactsStore.markVerified(
                id:     contact.id,
                method: .safetyNumber
            )
            contacts = try await container.trustedContactsStore.allContacts()
        } catch {
            // Silently fail; contact list will refresh on next load
        }
    }
}
