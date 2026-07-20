import ClaudeIslandCore
import XCTest

final class IslandDisplayGeometryTests: XCTestCase {
    func testUsesMeasuredCameraHousingInsteadOfADeviceTable() {
        let compact = IslandDisplayGeometryResolver.resolve(
            safeAreaTop: 32,
            auxiliaryLeftMaxX: 630,
            auxiliaryRightMinX: 840,
            screenWidth: 1_470,
            screenHeight: 956,
            scaleFactor: 2
        )
        let wide = IslandDisplayGeometryResolver.resolve(
            safeAreaTop: 38,
            auxiliaryLeftMaxX: 740,
            auxiliaryRightMinX: 980,
            screenWidth: 1_720,
            screenHeight: 1_080,
            scaleFactor: 2
        )

        XCTAssertEqual(compact.attachment, .hardwareNotch)
        XCTAssertEqual(compact.notchWidth, 210)
        XCTAssertEqual(compact.notchHeight, 32)
        XCTAssertEqual(wide.notchWidth, 240)
        XCTAssertEqual(wide.notchHeight, 38)
    }

    func testFallsBackToTopEdgeWithoutCameraHousingAreas() {
        let result = IslandDisplayGeometryResolver.resolve(
            safeAreaTop: 0,
            auxiliaryLeftMaxX: nil,
            auxiliaryRightMinX: nil,
            screenWidth: 1_920,
            screenHeight: 1_080,
            scaleFactor: 1
        )

        XCTAssertEqual(result.attachment, .topEdge)
        XCTAssertEqual(result.notchWidth, 0)
        XCTAssertEqual(result.notchHeight, 0)
    }

    func testDoesNotInventANotchFromOnlyASafeInset() {
        let result = IslandDisplayGeometryResolver.resolve(
            safeAreaTop: 32,
            auxiliaryLeftMaxX: nil,
            auxiliaryRightMinX: nil,
            screenWidth: 1_470,
            screenHeight: 956,
            scaleFactor: 2
        )

        XCTAssertEqual(result.attachment, .topEdge)
    }

    func testRejectsInvalidAuxiliaryAreaOrdering() {
        let result = IslandDisplayGeometryResolver.resolve(
            safeAreaTop: 32,
            auxiliaryLeftMaxX: 900,
            auxiliaryRightMinX: 800,
            screenWidth: 1_470,
            screenHeight: 956,
            scaleFactor: 2
        )

        XCTAssertEqual(result.attachment, .topEdge)
    }
}
