import SwiftUI

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon) // SF: varies by status — see SyncStatus.icon
                .font(.system(size: 10))
            Text(status.label)
                .font(Tokens.Font.caption2(.medium))
        }
        .foregroundStyle(color)
    }

    private var color: SwiftUI.Color {
        switch status {
        case .synced:    return Tokens.Color.green
        case .pending:   return Tokens.Color.orange
        case .localOnly: return Tokens.Color.textTertiary
        case .syncing:   return Tokens.Color.accent
        case .failed:    return Tokens.Color.red
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(SyncStatus.allCases, id: \.self) { status in
            StatusBadge(status: status)
        }
    }
    .padding()
}
