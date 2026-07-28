import Combine
import CoreGraphics

@MainActor
final class IslandDisplayState: ObservableObject {
    @Published private(set) var notchWidth: CGFloat
    @Published private(set) var notchHeight: CGFloat
    @Published private(set) var hasHardwareNotch: Bool

    init(
        notchWidth: CGFloat = 0,
        notchHeight: CGFloat = 0,
        hasHardwareNotch: Bool = false
    ) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.hasHardwareNotch = hasHardwareNotch
    }

    func update(
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        hasHardwareNotch: Bool
    ) {
        if self.notchWidth != notchWidth {
            self.notchWidth = notchWidth
        }
        if self.notchHeight != notchHeight {
            self.notchHeight = notchHeight
        }
        if self.hasHardwareNotch != hasHardwareNotch {
            self.hasHardwareNotch = hasHardwareNotch
        }
    }
}
