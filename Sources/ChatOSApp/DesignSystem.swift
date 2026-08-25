import SwiftUI

enum AppPalette {
    static let ai = Color(red: 0.43, green: 0.34, blue: 0.84)
    static let aiSoft = Color(red: 0.94, green: 0.92, blue: 1.0)
    static let selection = Color.accentColor.opacity(0.12)
    static let canvas = Color(red: 0.985, green: 0.990, blue: 1.0)
    static let surface = Color.white
    static let surfaceSubtle = Color(red: 0.955, green: 0.975, blue: 1.0)
    static let inputSurface = Color.white
    static let border = Color(red: 0.78, green: 0.84, blue: 0.93)
    static let idleControl = Color(red: 0.34, green: 0.47, blue: 0.68)
    static let terminalGreen = Color(red: 0.10, green: 0.62, blue: 0.28)
    static let terminalOrange = Color(red: 0.84, green: 0.39, blue: 0.08)
}

struct StatusCapsule: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .appFont(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.11), in: Capsule())
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .appFont(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

extension View {
    /// Keeps a top-level workspace stable while its loading, empty, error and
    /// populated states have very different intrinsic sizes.
    func workspaceFill(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    func workspaceBackground() -> some View {
        background(AppPalette.canvas)
    }
}
