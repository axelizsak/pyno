import SwiftUI

/// Colors and small custom shapes. Pyno's accent is the orange from the app icon.
enum Theme {
    static let orange = Color(red: 0.95, green: 0.47, blue: 0.13)
    static let orangeDeep = Color(red: 0.88, green: 0.33, blue: 0.03)
    /// Claude's warm accent, used only on the "Analyze in Claude" control.
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)

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

/// A tapered starburst, drawn rather than shipped as an image asset.
/// It marks the hand-off to Claude; it is not Anthropic's official logo.
struct Burst: Shape {
    var spokes = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let centerY = rect.midY
        let radius = min(rect.width, rect.height) / 2
        let halfWidth: CGFloat = radius * 0.17

        for index in 0..<spokes {
            let angle = CGFloat(index) / CGFloat(spokes) * 2 * CGFloat.pi
            let dirX = cos(angle)
            let dirY = sin(angle)
            let sideX = cos(angle + CGFloat.pi / 2)
            let sideY = sin(angle + CGFloat.pi / 2)

            let tip = CGPoint(x: centerX + dirX * radius, y: centerY + dirY * radius)
            let left = CGPoint(x: centerX + sideX * halfWidth, y: centerY + sideY * halfWidth)
            let right = CGPoint(x: centerX - sideX * halfWidth, y: centerY - sideY * halfWidth)

            let midX = centerX + dirX * radius * 0.55
            let midY = centerY + dirY * radius * 0.55
            let bulge: CGFloat = halfWidth * 0.7
            let leftControl = CGPoint(x: midX + sideX * bulge, y: midY + sideY * bulge)
            let rightControl = CGPoint(x: midX - sideX * bulge, y: midY - sideY * bulge)

            path.move(to: left)
            path.addQuadCurve(to: tip, control: leftControl)
            path.addQuadCurve(to: right, control: rightControl)
            path.closeSubpath()
        }
        return path
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
