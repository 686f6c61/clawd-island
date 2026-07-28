import XCTest
@testable import ClaudeIsland

final class IslandPanelLayoutTests: XCTestCase {
    func testAgentStripIncludesBottomSpacing() {
        let withoutAgents = IslandPanelLayout.expandedSize(
            preferredWidth: 620,
            maximumWidth: 620,
            hasHardwareNotch: false,
            notchHeight: 0,
            activityCount: 1,
            sessionCount: 1,
            agentCount: 0,
            hasQuestion: false,
            showsUsage: false
        )
        let withAgents = IslandPanelLayout.expandedSize(
            preferredWidth: 620,
            maximumWidth: 620,
            hasHardwareNotch: false,
            notchHeight: 0,
            activityCount: 1,
            sessionCount: 1,
            agentCount: 1,
            hasQuestion: false,
            showsUsage: false
        )

        XCTAssertEqual(withAgents.height - withoutAgents.height, 30)
    }

    func testExpandedWidthNeverExceedsAvailableScreenWidth() {
        let result = IslandPanelLayout.expandedSize(
            preferredWidth: 760,
            maximumWidth: 500,
            hasHardwareNotch: true,
            notchHeight: 32,
            activityCount: 3,
            sessionCount: 2,
            agentCount: 8,
            hasQuestion: true,
            showsUsage: true
        )

        XCTAssertEqual(result.width, 500)
    }
}
