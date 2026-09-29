import SwiftUI

/// Liquid Glass on macOS 26 and newer; a native material with a hairline edge on macOS 14 and 15.
extension View {
    @ViewBuilder
    func readerGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
        }
    }

    @ViewBuilder
    func readerGlassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Groups nearby glass shapes so they blend and morph together on macOS 26.
    @ViewBuilder
    func readerGlassContainer(spacing: CGFloat = 12) -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

/// Borderless icon button used inside glass surfaces.
struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .contentShape(Circle())
            .background(Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Solid amber circle for the primary playback action.
struct PlayButtonStyle: ButtonStyle {
    var diameter: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.readerInk)
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(Color.readerAmber.gradient)
                    .shadow(color: Color.readerAmber.opacity(0.35), radius: configuration.isPressed ? 2 : 8, y: 2)
            )
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
