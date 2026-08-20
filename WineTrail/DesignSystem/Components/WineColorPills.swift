import SwiftUI

/// A horizontal row of tappable color pills for selecting a wine color.
/// The selected pill is filled with the wine's accent color; unselected pills
/// show an outline with a subtle fill.
struct WineColorPills: View {
    @Binding var selected: Components.Schemas.WineColor?

    private let allColors: [Components.Schemas.WineColor] = [
        .RED, .WHITE, .ROSE, .ORANGE, .SPARKLING
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allColors, id: \.self) { color in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selected == color {
                                selected = nil
                            } else {
                                selected = color
                            }
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(color.displayName)
                            .font(.subheadline.weight(selected == color ? .semibold : .regular))
                            .fixedSize()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(selected == color ? .white : .primary)
                            .background(
                                selected == color ? color.accentColor : color.accentColor.opacity(0.12),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selected == color ? Color.clear : color.accentColor.opacity(0.4),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.displayName)
                    .accessibilityAddTraits(selected == color ? .isSelected : [])
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var color: Components.Schemas.WineColor? = nil
    WineColorPills(selected: $color)
        .padding()
}
