import SwiftUI

// MARK: - FolderCardView

struct FolderCardView: View {
    let folder: VaultFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.icon)
                    .fill(Tokens.Color.accentDim)
                    .frame(width: 36, height: 36)
                Image(systemName: "folder.fill") // SF: folder.fill
                    .font(.system(size: 16))
                    .foregroundStyle(Tokens.Color.accent)
            }

            // Folder name
            Text(folder.name)
                .font(Tokens.Font.body(.medium))
                .foregroundStyle(Tokens.Color.textPrimary)
                .lineLimit(1)

            // File count + status
            HStack(spacing: 4) {
                Text("\(folder.fileCount) files")
                    .font(Tokens.Font.caption2())
                    .foregroundStyle(Tokens.Color.textTertiary)
                Spacer()
                StatusBadge(status: folder.syncStatus)
            }
        }
        .padding(10)
        .frame(width: 120)
        .glassCard()
    }
}

// MARK: - FolderRow (horizontal scroll)

struct FolderRow: View {
    let folders: [VaultFolder]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(folders) { folder in
                    NavigationLink(value: folder) {
                        FolderCardView(folder: folder)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Preview

#Preview {
    FolderRow(folders: VaultFolder.samples)
        .padding()
        .background(Tokens.Color.background)
}
