import Foundation

public enum ClaudeTerminalCommand {
    public static func shellCommand(directory: String, resumeSessionID: String? = nil) -> String {
        let arguments = resumeSessionID.map { ["--resume", $0] } ?? []
        let command = (["claude"] + arguments).map(shellQuote).joined(separator: " ")
        return "cd \(shellQuote(directory)) && exec \(command)"
    }

    public static func executableCommand(resumeSessionID: String? = nil) -> String {
        let arguments = resumeSessionID.map { ["--resume", $0] } ?? []
        return (["claude"] + arguments).map(shellQuote).joined(separator: " ")
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
