import Foundation
import XCTest
@testable import ClaudeIslandCore

final class HookEventTests: XCTestCase {
    func testDecodesPermissionRequestAndSummarizesCommand() throws {
        let data = Data(#"""
        {
          "session_id":"session-1",
          "cwd":"/Users/test/Projects/island",
          "hook_event_name":"PermissionRequest",
          "tool_name":"Bash",
          "tool_input":{"command":"swift test"},
          "permission_suggestions":[{"type":"addRules","behavior":"allow","destination":"localSettings","rules":[]}],
          "island_context":{"term_program":"Apple_Terminal"}
        }
        """#.utf8)

        let event = try HookEvent(data: data)

        XCTAssertEqual(event.sessionID, "session-1")
        XCTAssertEqual(event.projectName, "island")
        XCTAssertEqual(event.toolSummary, "swift test")
        XCTAssertEqual(event.terminalProgram, "Apple_Terminal")
        XCTAssertEqual(event.permissionSuggestions.count, 1)
    }

    func testDecodesQuestionOptions() throws {
        let data = Data(#"""
        {
          "session_id":"session-2",
          "hook_event_name":"PreToolUse",
          "tool_name":"AskUserQuestion",
          "tool_input":{"questions":[{"question":"Which target?","options":[{"label":"Production"},{"label":"Staging"}]}]}
        }
        """#.utf8)

        let event = try HookEvent(data: data)

        XCTAssertEqual(event.firstQuestionText, "Which target?")
        XCTAssertEqual(event.firstQuestionOptions, ["Production", "Staging"])
    }

    func testDecodesSubagentAndTerminalIdentity() throws {
        let data = Data(#"""
        {
          "session_id":"session-3",
          "cwd":"/Users/test/Projects/island",
          "hook_event_name":"SubagentStart",
          "agent_id":"agent-abc123",
          "agent_type":"Explore",
          "island_context":{
            "term_program":"iTerm.app",
            "term_session_id":"terminal-session",
            "iterm_session_id":"w0t1p0:agent-session"
          }
        }
        """#.utf8)

        let event = try HookEvent(data: data)

        XCTAssertEqual(event.agentID, "agent-abc123")
        XCTAssertEqual(event.agentType, "Explore")
        XCTAssertEqual(event.terminalSessionID, "terminal-session")
        XCTAssertEqual(event.iTermSessionID, "w0t1p0:agent-session")
        XCTAssertEqual(event.activitySummary, "Explore started")
    }
}
