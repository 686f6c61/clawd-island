import Foundation

public enum IslandDisplayAttachment: String, Equatable, Sendable {
    case hardwareNotch
    case topEdge
}

public struct IslandDisplayGeometry: Equatable, Sendable {
    public let attachment: IslandDisplayAttachment
    public let notchWidth: Double
    public let notchHeight: Double

    public var hasHardwareNotch: Bool { attachment == .hardwareNotch }
}

public enum IslandDisplayGeometryResolver {
    public static func resolve(
        safeAreaTop: Double,
        auxiliaryLeftMaxX: Double?,
        auxiliaryRightMinX: Double?,
        screenWidth: Double,
        screenHeight: Double,
        scaleFactor: Double
    ) -> IslandDisplayGeometry {
        guard
            safeAreaTop.isFinite,
            safeAreaTop > 0,
            safeAreaTop < screenHeight * 0.25,
            let auxiliaryLeftMaxX,
            let auxiliaryRightMinX,
            auxiliaryLeftMaxX.isFinite,
            auxiliaryRightMinX.isFinite
        else {
            return topEdge
        }

        let gap = auxiliaryRightMinX - auxiliaryLeftMaxX
        guard gap >= 40, gap <= screenWidth * 0.5 else { return topEdge }

        let scale = max(1, scaleFactor.isFinite ? scaleFactor : 1)
        return IslandDisplayGeometry(
            attachment: .hardwareNotch,
            notchWidth: (gap * scale).rounded() / scale,
            notchHeight: (safeAreaTop * scale).rounded(.up) / scale
        )
    }

    private static let topEdge = IslandDisplayGeometry(
        attachment: .topEdge,
        notchWidth: 0,
        notchHeight: 0
    )
}
