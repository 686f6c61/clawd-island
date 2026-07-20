import ClaudeIslandCore
import XCTest

final class ClaudeTerminalCommandTests: XCTestCase {
    func testBuildsNewSessionCommandInSelectedDirectory() {
        XCTAssertEqual(
            ClaudeTerminalCommand.shellCommand(directory: "/tmp/Claude Project"),
            "cd '/tmp/Claude Project' && exec 'claude'"
        )
    }

    func testBuildsSafelyQuotedResumeCommand() {
        XCTAssertEqual(
            ClaudeTerminalCommand.shellCommand(
                directory: "/tmp/Claude's Project",
                resumeSessionID: "session-id"
            ),
            "cd '/tmp/Claude'\\''s Project' && exec 'claude' '--resume' 'session-id'"
        )
    }
}
