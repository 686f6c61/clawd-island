import Foundation
import XCTest
@testable import ClaudeIslandCore

final class HookDecisionTests: XCTestCase {
    func testAllowPermissionIncludesOriginalInputAndSuggestion() throws {
        let event = HookEvent(raw: [
            "hook_event_name": .string("PermissionRequest"),
            "tool_name": .string("Bash"),
            "tool_input": .object(["command": .string("swift test")]),
            "permission_suggestions": .array([.object(["type": .string("addRules")])]),
        ])

        let data = try HookDecision.allowPermission(for: event, always: true)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let output = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let decision = try XCTUnwrap(output["decision"] as? [String: Any])

        XCTAssertEqual(decision["behavior"] as? String, "allow")
        XCTAssertEqual((decision["updatedInput"] as? [String: Any])?["command"] as? String, "swift test")
        XCTAssertEqual((decision["updatedPermissions"] as? [Any])?.count, 1)
    }

    func testQuestionAnswerPreservesQuestionsAndAddsAnswer() throws {
        let questions: JSONValue = .array([.object([
            "question": .string("Which target?"),
            "options": .array([.object(["label": .string("Production")])]),
        ])])
        let event = HookEvent(raw: [
            "hook_event_name": .string("PreToolUse"),
            "tool_name": .string("AskUserQuestion"),
            "tool_input": .object(["questions": questions]),
        ])

        let data = try HookDecision.answerQuestion(event: event, answer: "Production")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let output = try XCTUnwrap(object["hookSpecificOutput"] as? [String: Any])
        let input = try XCTUnwrap(output["updatedInput"] as? [String: Any])
        let answers = try XCTUnwrap(input["answers"] as? [String: String])

        XCTAssertEqual(output["permissionDecision"] as? String, "allow")
        XCTAssertEqual(answers["Which target?"], "Production")
        XCTAssertNotNil(input["questions"])
    }
}
