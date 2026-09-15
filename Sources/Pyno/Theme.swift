import SwiftUI

/// Colors. Pyno's accent is the orange from the app icon.
enum Theme {
    static let orange = Color(red: 0.95, green: 0.47, blue: 0.13)
    static let orangeDeep = Color(red: 0.88, green: 0.33, blue: 0.03)

    static let quiet = Color(red: 0.30, green: 0.72, blue: 0.45)
    static let loud = Color(red: 0.91, green: 0.30, blue: 0.24)

    /// Green while speech is comfortable, orange as it gets loud, red near clipping.
    static func level(_ value: Float) -> Color {
        switch value {
        case ..<0.45: return quiet
        case ..<0.78: return orange
        default: return loud
        }
    }
}

/// Microphone glyph plus a bar meter, both following the input level.
struct MicLevel: View {
    let level: Float

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: level > 0.06 ? "mic.fill" : "mic")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(level > 0.06 ? Theme.level(level) : Color.secondary.opacity(0.5))
                .animation(.easeOut(duration: 0.12), value: level > 0.06)

            HStack(spacing: 2) {
                ForEach(0..<14, id: \.self) { index in
                    let threshold = Float(index) / 14
                    let lit = level > threshold
                    RoundedRectangle(cornerRadius: 1)
                        .fill(lit ? Theme.level(threshold + 0.08) : Color.secondary.opacity(0.18))
                        .frame(width: 3, height: 5 + CGFloat(index) * 0.85)
                }
            }
            .frame(height: 18, alignment: .bottom)
            .animation(.linear(duration: 0.08), value: level)
        }
    }
}

/// Small rounded label used for the session language.
struct Chip: View {
    let text: String
    var tint: Color = Theme.orange

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}
