import SwiftUI

/// Native Liquid Glass on Tahoe, with readable material surfaces on macOS 14–15.
enum ScheduleAppearance {
    static let accent = Color(red: 0.02, green: 0.49, blue: 0.27)
    static let shadow = Color(red: 0.08, green: 0.25, blue: 0.18).opacity(0.09)
    static let background = LinearGradient(colors: [Color(red: 0.93, green: 0.98, blue: 0.95), .white,
                                                    Color(red: 0.96, green: 0.98, blue: 0.99)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct ScheduleControlStyle: ViewModifier {
    var prominent = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            if prominent { content.buttonStyle(.glassProminent).buttonBorderShape(.capsule) }
            else { content.buttonStyle(.glass).buttonBorderShape(.capsule) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule) }
            else { content.buttonStyle(.bordered).buttonBorderShape(.capsule) }
        }
    }
}

private struct SchedulePanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency { RoundedRectangle(cornerRadius: 24).fill(.white) }
                else { RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial) }
            }
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.85), lineWidth: 1))
            .shadow(color: ScheduleAppearance.shadow, radius: 12, x: 0, y: 5)
    }
}

extension View {
    func scheduleControls(prominent: Bool = false) -> some View { modifier(ScheduleControlStyle(prominent: prominent)) }
    func schedulePanel() -> some View { modifier(SchedulePanel()) }
}

struct ScheduleActionLabel: View {
    let title: String
    let icon: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 260, height: 30)
            .padding(.horizontal, 10).padding(.vertical, 6)
    }
}
