import AppKit
import ClaudeIslandCore
import Foundation

@MainActor
enum TerminalActivator {
    struct Identity {
        let title: String
        let icon: NSImage?
    }

    static func identity(
        program: String?,
        preference: TerminalPreference = AppSettings.shared.preferredTerminal
    ) -> Identity {
        let resolved = resolve(preference: preference, program: program)
        guard let bundleIdentifier = resolved.bundleIdentifier,
              let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            return Identity(title: resolved.title, icon: nil)
        }

        let sourceIcon = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier })?
            .icon
            ?? NSWorkspace.shared.icon(forFile: applicationURL.path)
        let icon = (sourceIcon.copy() as? NSImage) ?? sourceIcon
        icon.size = NSSize(width: 16, height: 16)
        return Identity(title: resolved.title, icon: icon)
    }

    static func activate(program: String?, preference: TerminalPreference = AppSettings.shared.preferredTerminal) {
        let resolved = resolve(preference: preference, program: program)
        if let bundleIdentifier = resolved.bundleIdentifier,
           let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            running.activate(options: [.activateAllWindows])
            return
        }
        guard let bundleIdentifier = resolved.bundleIdentifier,
              let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
    }

    static func launchClaude(
        at directory: String,
        resumeSessionID: String? = nil,
        preference: TerminalPreference = AppSettings.shared.preferredTerminal
    ) async throws {
        let folder = URL(fileURLWithPath: directory).standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: folder) else {
            throw TerminalLaunchError.folderMissing(folder)
        }
        let resolved = resolve(preference: preference, program: nil)

        switch resolved {
        case .ghostty:
            let command = ClaudeTerminalCommand.shellCommand(directory: folder, resumeSessionID: resumeSessionID)
            try launchProcess(
                executable: "/usr/bin/open",
                arguments: [
                    "-na", "Ghostty.app", "--args",
                    "--working-directory=\(folder)",
                    "--wait-after-command=true",
                    "-e", "/bin/zsh", "-lic", command,
                ]
            )
        case .terminal:
            let command = ClaudeTerminalCommand.shellCommand(directory: folder, resumeSessionID: resumeSessionID)
            try await runAppleScriptDetached("""
            tell application "Terminal"
                activate
                do script "\(appleScriptEscaped(command))"
            end tell
            """)
        case .iTerm:
            let command = ClaudeTerminalCommand.shellCommand(directory: folder, resumeSessionID: resumeSessionID)
            try await runAppleScriptDetached("""
            tell application "iTerm2"
                activate
                create window with default profile command "\(appleScriptEscaped(command))"
            end tell
            """)
        case .warp:
            try launchWarp(directory: folder, resumeSessionID: resumeSessionID)
        case .automatic:
            // resolve(preference:program:) always returns a concrete terminal.
            try await launchClaude(at: folder, resumeSessionID: resumeSessionID, preference: .terminal)
        }
    }

    static func isAvailable(_ preference: TerminalPreference) -> Bool {
        guard let bundleIdentifier = preference.bundleIdentifier else { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    private static func resolve(preference: TerminalPreference, program: String?) -> TerminalPreference {
        if preference != .automatic, isAvailable(preference) { return preference }

        if let program {
            let normalized = program.lowercased()
            if normalized.contains("ghostty") { return .ghostty }
            if normalized.contains("iterm") { return .iTerm }
            if normalized.contains("warp") { return .warp }
            if normalized.contains("terminal") || normalized.contains("apple_terminal") { return .terminal }
        }

        for candidate in [TerminalPreference.ghostty, .iTerm, .warp, .terminal] where isAvailable(candidate) {
            return candidate
        }
        return .terminal
    }

    private static func launchWarp(directory: String, resumeSessionID: String?) throws {
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaudeIsland/Warp", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let config = support.appendingPathComponent("claude-island.yaml")
        let command = ClaudeTerminalCommand.executableCommand(resumeSessionID: resumeSessionID)
        let yaml = """
        ---
        name: Claude Island
        windows:
          - tabs:
              - title: Claude Code
                layout:
                  cwd: '\(yamlSingleQuoted(directory))'
                  commands:
                    - exec: '\(yamlSingleQuoted(command))'
        """
        try Data(yaml.utf8).write(to: config, options: .atomic)
        var components = URLComponents()
        components.scheme = "warp"
        components.host = "launch"
        components.path = config.path
        guard let url = components.url else { throw TerminalLaunchError.couldNotBuildWarpURL }
        NSWorkspace.shared.open(url)
    }

    private static func launchProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
    }

    private static func runAppleScriptDetached(_ source: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw TerminalLaunchError.appleScriptFailed("Invalid script")
            }
            script.executeAndReturnError(&error)
            if let error {
                throw TerminalLaunchError.appleScriptFailed(error.description)
            }
        }.value
    }

    private static func yamlSingleQuoted(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private enum TerminalLaunchError: LocalizedError {
        case folderMissing(String)
        case appleScriptFailed(String)
        case couldNotBuildWarpURL

        var errorDescription: String? {
            switch self {
            case let .folderMissing(path): "The folder no longer exists: \(path)"
            case let .appleScriptFailed(message): "The terminal could not be opened: \(message)"
            case .couldNotBuildWarpURL: "The Warp launch URL could not be created."
            }
        }
    }
}
