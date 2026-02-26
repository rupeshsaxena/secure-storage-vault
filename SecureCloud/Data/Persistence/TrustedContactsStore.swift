import Foundation

// MARK: - TrustedContactsStore
//
// Actor-isolated JSON-on-disk persistence for the local trusted contact registry.
// Thread-safe; all mutations are serialised through the actor executor.

actor TrustedContactsStore {

    // ── Storage path ───────────────────────────────────────────────────────

    private let fileURL: URL = {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("trusted_contacts_v2.json")
    }()

    private var contacts: [TrustedContact] = []
    private var isLoaded = false

    // MARK: - Load / Save

    func loadIfNeeded() throws {
        guard !isLoaded else { return }
        isLoaded = true

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let data    = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.dataDecodingStrategy = .base64
        contacts = try decoder.decode([TrustedContact].self, from: data)
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy   = .iso8601
        encoder.dataEncodingStrategy   = .base64
        encoder.outputFormatting       = .prettyPrinted
        let data = try encoder.encode(contacts)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Read

    func allContacts() throws -> [TrustedContact] {
        try loadIfNeeded()
        return contacts
    }

    func contact(id: UUID) throws -> TrustedContact? {
        try loadIfNeeded()
        return contacts.first { $0.id == id }
    }

    func contact(remoteUserId: UUID) throws -> TrustedContact? {
        try loadIfNeeded()
        return contacts.first { $0.remoteUserId == remoteUserId }
    }

    // MARK: - Write

    func upsert(_ contact: TrustedContact) throws {
        try loadIfNeeded()
        if let idx = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[idx] = contact
        } else {
            contacts.append(contact)
        }
        try save()
    }

    func delete(id: UUID) throws {
        try loadIfNeeded()
        contacts.removeAll { $0.id == id }
        try save()
    }

    func markVerified(
        id: UUID,
        method: TrustedContact.VerificationMethod
    ) throws {
        try loadIfNeeded()
        guard let idx = contacts.firstIndex(where: { $0.id == id }) else { return }
        var c = contacts[idx]
        c.verifiedAt         = Date()
        c.verificationMethod = method
        contacts[idx] = c
        try save()
    }
}
