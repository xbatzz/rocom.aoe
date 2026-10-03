import SwiftUI

/// A bounded, static color field. Reading content stays opaque; system chrome owns glass.
struct CompanionAccentSurface: ViewModifier {
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var solidSurface: Bool {
        #if DEBUG
        reduceTransparency || ProcessInfo.processInfo.arguments.contains("--visual-solid-surfaces")
        #else
        reduceTransparency
        #endif
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        if !solidSurface {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(LinearGradient(
                                    colors: [tint.opacity(colorScheme == .dark ? 0.18 : 0.12), tint.opacity(0.03), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(contrast == .increased ? Color.primary : Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.07), lineWidth: 1)
            }
    }
}

extension View {
    func companionAccentSurface(tint: Color) -> some View {
        modifier(CompanionAccentSurface(tint: tint))
    }
}
