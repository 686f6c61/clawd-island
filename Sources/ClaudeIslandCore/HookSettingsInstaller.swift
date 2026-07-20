import Foundation
import CryptoKit

public struct HookInstallationResult: Sendable, Equatable {
    public let settingsURL: URL
    public let helperURL: URL
    public let configurationChanged: Bool
    public let permissionMode: String
}

public struct HookRemovalResult: Sendable, Equatable {
    public let settingsURL: URL
    public let removedHandlers: Int
    public let backupURL: URL?
}

public enum HookSettingsInstaller {
    public static let port: UInt16 = 47_835

    public static func install(
        helperSourceURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> HookInstallationResult {
        let fileManager = FileManager.default
        let supportDirectory = HookBridgeCredential.supportDirectory(homeDirectory: homeDirectory)
        _ = try HookBridgeCredential.ensureToken(homeDirectory: homeDirectory)

        let sourceAttributes = try fileManager.attributesOfItem(atPath: helperSourceURL.path)
        guard sourceAttributes[.type] as? FileAttributeType == .typeRegular,
              let sourceSize = sourceAttributes[.size] as? NSNumber,
              sourceSize.intValue > 0,
              sourceSize.intValue <= 64 * 1_024 * 1_024
        else { throw InstallationError.invalidHelper }
        let expectedDigest = SHA256.hash(data: try Data(contentsOf: helperSourceURL, options: .mappedIfSafe))

        let helperURL = supportDirectory.appendingPathComponent("ClaudeIslandHook")
        if fileManager.fileExists(atPath: helperURL.path) {
            try fileManager.removeItem(at: helperURL)
        }
        try fileManager.copyItem(at: helperSourceURL, to: helperURL)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperURL.path)
        let installedDigest = SHA256.hash(data: try Data(contentsOf: helperURL, options: .mappedIfSafe))
        guard installedDigest == expectedDigest else { throw InstallationError.helperVerificationFailed }

        let settingsURL = homeDirectory.appendingPathComponent(".claude/settings.json")
        try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var settings = try readObject(at: settingsURL)
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let command = shellQuote(helperURL.path)
        var changed = false

        for definition in hookDefinitions(command: command) {
            var groups = hooks[definition.event] as? [[String: Any]] ?? []
            let expectedMatcher = definition.group["matcher"] as? String
            let alreadyInstalled = groups.contains { group in
                guard (group["matcher"] as? String) == expectedMatcher else { return false }
                let handlers = group["hooks"] as? [[String: Any]] ?? []
                return handlers.contains { ($0["command"] as? String) == command }
            }
            if !alreadyInstalled {
                groups.append(definition.group)
                hooks[definition.event] = groups
                changed = true
            }
        }

        if changed {
            settings["hooks"] = hooks
            if fileManager.fileExists(atPath: settingsURL.path) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd-HHmmss"
                let backupURL = settingsURL.deletingLastPathComponent()
                    .appendingPathComponent("settings.json.island-backup-\(formatter.string(from: Date()))")
                try fileManager.copyItem(at: settingsURL, to: backupURL)
            }
            try writeObject(settings, to: settingsURL)
        }

        return HookInstallationResult(
            settingsURL: settingsURL,
            helperURL: helperURL,
            configurationChanged: changed,
            permissionMode: effectivePermissionMode(homeDirectory: homeDirectory)
        )
    }

    public static func effectivePermissionMode(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let candidates = [
            homeDirectory.appendingPathComponent(".claude/settings.local.json"),
            homeDirectory.appendingPathComponent(".claude/settings.json"),
        ]
        for url in candidates {
            guard let object = try? readObject(at: url) else { continue }
            if let mode = (object["permissions"] as? [String: Any])?["defaultMode"] as? String {
                return mode
            }
            if let mode = object["defaultMode"] as? String {
                return mode
            }
        }
        return "default"
    }

    public static func enablePermissionPrompts(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        let fileManager = FileManager.default
        for filename in ["settings.json", "settings.local.json"] {
            let url = homeDirectory.appendingPathComponent(".claude/\(filename)")
            guard fileManager.fileExists(atPath: url.path) else { continue }
            var object = try readObject(at: url)
            var permissions = object["permissions"] as? [String: Any] ?? [:]
            permissions["defaultMode"] = "default"
            object["permissions"] = permissions
            object["defaultMode"] = "default"
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("\(filename).island-permissions-backup")
            if !fileManager.fileExists(atPath: backup.path) {
                try fileManager.copyItem(at: url, to: backup)
            }
            try writeObject(object, to: url)
        }
    }

    public static func isInstalled(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        let ownedCommand = installedCommand(homeDirectory: homeDirectory)
        let settingsURL = homeDirectory.appendingPathComponent(".claude/settings.json")
        guard let settings = try? readObject(at: settingsURL) else { return false }
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        return hooks.values.contains { value in
            let groups = value as? [[String: Any]] ?? []
            return groups.contains { group in
                let handlers = group["hooks"] as? [[String: Any]] ?? []
                return handlers.contains { ($0["command"] as? String) == ownedCommand }
            }
        }
    }

    @discardableResult
    public static func uninstall(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        removeHelper: Bool = true
    ) throws -> HookRemovalResult {
        let fileManager = FileManager.default
        let settingsURL = homeDirectory.appendingPathComponent(".claude/settings.json")
        var settings = try readObject(at: settingsURL)
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var removedHandlers = 0
        let ownedCommand = installedCommand(homeDirectory: homeDirectory)

        for event in Array(hooks.keys) {
            let value = hooks[event]
            let groups = value as? [[String: Any]] ?? []
            let updatedGroups = groups.compactMap { group -> [String: Any]? in
                var updated = group
                let handlers = group["hooks"] as? [[String: Any]] ?? []
                let kept = handlers.filter { handler in
                    let isIsland = (handler["command"] as? String) == ownedCommand
                    if isIsland { removedHandlers += 1 }
                    return !isIsland
                }
                guard !kept.isEmpty else { return nil }
                updated["hooks"] = kept
                return updated
            }
            if updatedGroups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = updatedGroups
            }
        }

        var backupURL: URL?
        if removedHandlers > 0, fileManager.fileExists(atPath: settingsURL.path) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let backup = settingsURL.deletingLastPathComponent()
                .appendingPathComponent("settings.json.island-uninstall-backup-\(formatter.string(from: Date()))")
            try fileManager.copyItem(at: settingsURL, to: backup)
            backupURL = backup
            settings["hooks"] = hooks
            try writeObject(settings, to: settingsURL)
        }

        if removeHelper {
            let helperURL = homeDirectory
                .appendingPathComponent("Library/Application Support/ClaudeIsland/ClaudeIslandHook")
            if fileManager.fileExists(atPath: helperURL.path) {
                try fileManager.removeItem(at: helperURL)
            }
            try HookBridgeCredential.removeToken(homeDirectory: homeDirectory)
        }

        return HookRemovalResult(
            settingsURL: settingsURL,
            removedHandlers: removedHandlers,
            backupURL: backupURL
        )
    }

    private struct HookDefinition {
        let event: String
        let group: [String: Any]
    }

    private enum InstallationError: LocalizedError {
        case invalidHelper
        case helperVerificationFailed

        var errorDescription: String? {
            switch self {
            case .invalidHelper:
                "Claude Island's bundled hook helper is invalid."
            case .helperVerificationFailed:
                "Claude Island could not verify the installed hook helper."
            }
        }
    }

    private static func hookDefinitions(command: String) -> [HookDefinition] {
        func definition(_ event: String, matcher: String? = nil, timeout: Int = 3) -> HookDefinition {
            var group: [String: Any] = [
                "hooks": [[
                    "type": "command",
                    "command": command,
                    "timeout": timeout,
                ]],
            ]
            if let matcher { group["matcher"] = matcher }
            return HookDefinition(event: event, group: group)
        }

        return [
            definition("SessionStart"),
            definition("UserPromptSubmit"),
            definition("PreToolUse", matcher: "AskUserQuestion", timeout: 360),
            definition("PreToolUse", matcher: "Bash|Edit|Write|Read|Glob|Grep|NotebookEdit|WebFetch|WebSearch|Agent"),
            definition("PermissionRequest", matcher: "", timeout: 360),
            definition("PostToolUse"),
            definition("PostToolUseFailure"),
            definition("Notification", matcher: ""),
            definition("Stop"),
            definition("SessionEnd"),
            definition("SubagentStart", matcher: ""),
            definition("SubagentStop"),
        ]
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func installedCommand(homeDirectory: URL) -> String {
        shellQuote(
            HookBridgeCredential.supportDirectory(homeDirectory: homeDirectory)
                .appendingPathComponent("ClaudeIslandHook")
                .path
        )
    }

    private static func readObject(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return object
    }

    private static func writeObject(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var output = data
        output.append(0x0A)
        try output.write(to: url, options: .atomic)
    }
}
