import SwiftUI

// MARK: - ChipView

struct ChipView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Font.caption1(.medium))
                .foregroundStyle(isSelected ? Tokens.Color.accent : Tokens.Color.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Tokens.Color.accentDim : Tokens.Color.surface)
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? Tokens.Color.accent.opacity(0.2) : Tokens.Color.border,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - ChipBar

struct ChipBar: View {
    let options: [FileFilter]
    @Binding var selected: FileFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    ChipView(
                        label: option.rawValue,
                        isSelected: selected == option
                    ) {
                        selected = option
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Preview

#Preview {
    @State var selected: FileFilter = .all
    return ChipBar(options: FileFilter.allCases, selected: $selected)
        .padding()
        .background(Tokens.Color.background)
}
