import Foundation

public enum HookDecision {
    public static func allowPermission(for event: HookEvent, always: Bool) throws -> Data {
        var decision: [String: JSONValue] = [
            "behavior": .string("allow"),
            "updatedInput": .object(event.toolInput),
        ]
        if always, let suggestion = event.permissionSuggestions.first {
            decision["updatedPermissions"] = .array([suggestion])
        }
        return try encode([
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(decision),
            ]),
        ])
    }

    public static func denyPermission(message: String = "Denied from Claude Island") throws -> Data {
        try encode([
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("deny"),
                    "message": .string(message),
                    "interrupt": .bool(false),
                ]),
            ]),
        ])
    }

    public static func answerQuestion(event: HookEvent, answer: String) throws -> Data {
        guard let question = event.firstQuestionText else { return empty }
        var updatedInput = event.toolInput
        updatedInput["answers"] = .object([question: .string(answer)])
        return try encode([
            "hookSpecificOutput": .object([
                "hookEventName": .string("PreToolUse"),
                "permissionDecision": .string("allow"),
                "updatedInput": .object(updatedInput),
            ]),
        ])
    }

    public static let empty = Data("{}".utf8)

    private static func encode(_ object: [String: JSONValue]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(object)
    }
}
