import Foundation

public struct HookEvent: Sendable, Equatable {
    public let raw: [String: JSONValue]

    public init(data: Data) throws {
        raw = try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    public init(raw: [String: JSONValue]) {
        self.raw = raw
    }

    public var sessionID: String { raw["session_id"]?.stringValue ?? "unknown" }
    public var eventName: String { raw["hook_event_name"]?.stringValue ?? "Unknown" }
    public var cwd: String { raw["cwd"]?.stringValue ?? "" }
    public var transcriptPath: String { raw["transcript_path"]?.stringValue ?? "" }
    public var permissionMode: String { raw["permission_mode"]?.stringValue ?? "default" }
    public var toolName: String? { raw["tool_name"]?.stringValue }
    public var toolInput: [String: JSONValue] { raw["tool_input"]?.objectValue ?? [:] }
    public var permissionSuggestions: [JSONValue] { raw["permission_suggestions"]?.arrayValue ?? [] }
    public var prompt: String? { raw["prompt"]?.stringValue }
    public var notificationType: String? { raw["notification_type"]?.stringValue }
    public var message: String? { raw["message"]?.stringValue }
    public var agentID: String? { raw["agent_id"]?.stringValue }
    public var agentType: String? { raw["agent_type"]?.stringValue }
    public var lastAssistantMessage: String? { raw["last_assistant_message"]?.stringValue }
    public var terminalProgram: String? { raw["island_context"]?["term_program"]?.stringValue }
    public var terminalSessionID: String? { raw["island_context"]?["term_session_id"]?.stringValue }
    public var iTermSessionID: String? { raw["island_context"]?["iterm_session_id"]?.stringValue }

    public var projectName: String {
        let value = cwd.isEmpty ? transcriptPath : cwd
        let url = URL(fileURLWithPath: value)
        let candidate = cwd.isEmpty ? url.deletingLastPathComponent().lastPathComponent : url.lastPathComponent
        return candidate.isEmpty ? "Claude Code" : candidate
    }

    public var activitySummary: String {
        switch eventName {
        case "SessionStart":
            return "Session started"
        case "UserPromptSubmit":
            return prompt.map { "You: \($0)" } ?? "Prompt submitted"
        case "Stop":
            return "Done — waiting for you"
        case "SessionEnd":
            return "Session ended"
        case "SubagentStart":
            return "\(agentType ?? "Subagent") started"
        case "SubagentStop":
            return "\(agentType ?? "Subagent") finished"
        case "PostToolUseFailure":
            return "\(toolName ?? "Tool") failed"
        case "Notification":
            return message ?? "Claude needs attention"
        default:
            return toolSummary
        }
    }

    public var toolSummary: String {
        guard let toolName else { return eventName }
        switch toolName {
        case "Bash":
            return toolInput["command"]?.stringValue ?? "Running command"
        case "Edit", "Write", "Read", "NotebookEdit":
            let path = toolInput["file_path"]?.stringValue ?? toolInput["notebook_path"]?.stringValue
            return path.map { "\(toolName) \(Self.shortPath($0))" } ?? toolName
        case "Grep":
            return toolInput["pattern"]?.stringValue.map { "Searching for \($0)" } ?? "Searching files"
        case "Glob":
            return toolInput["pattern"]?.stringValue.map { "Finding \($0)" } ?? "Finding files"
        case "AskUserQuestion":
            return firstQuestionText ?? "Claude asks a question"
        default:
            return toolName
        }
    }

    public var firstQuestionText: String? {
        guard
            let questions = toolInput["questions"]?.arrayValue,
            let question = questions.first?.objectValue
        else { return nil }
        return question["question"]?.stringValue
    }

    public var firstQuestionOptions: [String] {
        guard
            let questions = toolInput["questions"]?.arrayValue,
            let question = questions.first?.objectValue,
            let options = question["options"]?.arrayValue
        else { return [] }
        return options.compactMap { $0.objectValue?["label"]?.stringValue }
    }

    private static func shortPath(_ path: String) -> String {
        let components = URL(fileURLWithPath: path).pathComponents
        return components.suffix(3).joined(separator: "/")
    }
}
