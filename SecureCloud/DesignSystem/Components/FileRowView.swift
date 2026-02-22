import SwiftUI

// MARK: - FileRowView

struct FileRowView: View {
    let file: VaultFile

    var body: some View {
        HStack(spacing: 10) {
            // File type icon thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.icon)
                    .fill(thumbBg)
                    .frame(width: 32, height: 32)
                Image(systemName: file.fileType.icon) // SF: doc.fill / waveform / video.fill etc.
                    .font(.system(size: 14))
                    .foregroundStyle(thumbColor)
            }

            // File metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Tokens.Font.body(.medium))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)
                Text(fileInfo)
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
                StatusBadge(status: file.syncStatus)
            }

            Spacer()

            if file.isLocked {
                Image(systemName: "lock.fill") // SF: lock.fill
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Color.textTertiary)
            }

            Image(systemName: "chevron.right") // SF: chevron.right
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Tokens.Color.textQuaternary)
        }
        .padding(EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 11))
        .glassCard(radius: Tokens.Radius.cardSm)
    }

    // MARK: - Computed

    private var fileInfo: String {
        let size = ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file)
        return "\(size) · \(file.fileType.rawValue.uppercased())"
    }

    private var thumbBg: SwiftUI.Color {
        switch file.syncStatus {
        case .synced:    return Tokens.Color.greenDim
        case .pending:   return Tokens.Color.orange.opacity(0.10)
        case .localOnly: return Tokens.Color.textTertiary.opacity(0.10)
        case .syncing:   return Tokens.Color.accentDim
        case .failed:    return Tokens.Color.redDim
        }
    }

    private var thumbColor: SwiftUI.Color {
        switch file.syncStatus {
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
    VStack(spacing: 4) {
        ForEach(VaultFile.samples) { file in
            FileRowView(file: file)
        }
    }
    .padding()
    .background(Tokens.Color.background)
}
