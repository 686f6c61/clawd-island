import SwiftUI

enum IslandPalette {
    static let amber = Color(red: 0.98, green: 0.61, blue: 0.22)
    static let green = Color(red: 0.35, green: 0.78, blue: 0.50)
    static let red = Color(red: 0.92, green: 0.40, blue: 0.36)
    static let secondary = Color.white.opacity(0.52)
    static let separator = Color.white.opacity(0.10)
    static let row = Color.white.opacity(0.035)
    static let menuSeparator = Color.white.opacity(0.08)
    static let menuIdle = Color.white.opacity(0.32)

    static func statusColor(_ status: SessionStatus, idle: Color? = nil) -> Color {
        switch status {
        case .running, .waiting: amber
        case .completed: green
        case .failed: red
        case .idle: idle ?? Color.white.opacity(0.28)
        }
    }
}
