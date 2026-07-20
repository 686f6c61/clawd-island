import Foundation

public enum ClaudePermissionMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case `default`
    case acceptEdits
    case plan
    case auto
    case dontAsk
    case bypassPermissions

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .default: "Ask for approval"
        case .acceptEdits: "Accept edits"
        case .plan: "Plan only"
        case .auto: "Auto"
        case .dontAsk: "Pre-approved only"
        case .bypassPermissions: "Bypass permissions"
        }
    }

    public var detail: String {
        switch self {
        case .default: "Reads run automatically; changes ask first."
        case .acceptEdits: "Edits and common filesystem actions run automatically."
        case .plan: "Claude explores and proposes a plan without editing."
        case .auto: "Claude uses background safety checks to approve actions."
        case .dontAsk: "Anything not explicitly allowed is denied."
        case .bypassPermissions: "All permission checks are skipped. Use only in isolated environments."
        }
    }

    public var isDangerous: Bool { self == .bypassPermissions }
}

public struct ClaudeSettingsSnapshot: Equatable, Sendable {
    public let mode: ClaudePermissionMode
    public let allowRules: [String]
    public let askRules: [String]
    public let denyRules: [String]

    public init(
        mode: ClaudePermissionMode,
        allowRules: [String],
        askRules: [String],
        denyRules: [String]
    ) {
        self.mode = mode
        self.allowRules = allowRules
        self.askRules = askRules
        self.denyRules = denyRules
    }
}

public struct ClaudeSettingsApplyResult: Equatable, Sendable {
    public let changedFiles: [URL]
    public let backupFiles: [URL]
}

public enum ClaudeSettingsManager {
    public static let configurableTools = [
        "Bash", "Edit", "Write", "Read", "WebFetch", "WebSearch", "Agent", "AskUserQuestion",
    ]

    public static func snapshot(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> ClaudeSettingsSnapshot {
        let userURL = settingsURL(homeDirectory: homeDirectory, filename: "settings.json")
        let localURL = settingsURL(homeDirectory: homeDirectory, filename: "settings.local.json")
        let user = try readObject(at: userURL)
        let local = try readObject(at: localURL)
        let userPermissions = user["permissions"] as? [String: Any] ?? [:]
        let localPermissions = local["permissions"] as? [String: Any] ?? [:]
        let modeValue = (localPermissions["defaultMode"] as? String)
            ?? (local["defaultMode"] as? String)
            ?? (userPermissions["defaultMode"] as? String)
            ?? (user["defaultMode"] as? String)
            ?? ClaudePermissionMode.default.rawValue

        return ClaudeSettingsSnapshot(
            mode: ClaudePermissionMode(rawValue: modeValue) ?? .default,
            allowRules: stringArray(userPermissions["allow"]),
            askRules: stringArray(userPermissions["ask"]),
            denyRules: stringArray(userPermissions["deny"])
        )
    }

    public static func apply(
        mode: ClaudePermissionMode,
        alwaysAskTools: Set<String>,
        removingAllowRules: Set<String> = [],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date()
    ) throws -> ClaudeSettingsApplyResult {
        let fileManager = FileManager.default
        let claudeDirectory = homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        try fileManager.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)

        var changedFiles: [URL] = []
        var backupFiles: [URL] = []
        let userURL = settingsURL(homeDirectory: homeDirectory, filename: "settings.json")
        var user = try readObject(at: userURL)
        var permissions = user["permissions"] as? [String: Any] ?? [:]

        let existingAllow = stringArray(permissions["allow"])
        permissions["allow"] = existingAllow.filter { !removingAllowRules.contains($0) }

        let managedTools = Set(configurableTools)
        let existingAsk = stringArray(permissions["ask"])
            .filter { !managedTools.contains($0) }
        permissions["ask"] = Array(Set(existingAsk).union(alwaysAskTools)).sorted()
        permissions["defaultMode"] = mode.rawValue
        user["permissions"] = permissions
        user["defaultMode"] = mode.rawValue
        let userResult = try writeIfChanged(user, to: userURL, now: now)
        if userResult.changed {
            changedFiles.append(userURL)
            if let backup = userResult.backup { backupFiles.append(backup) }
        }

        let localURL = settingsURL(homeDirectory: homeDirectory, filename: "settings.local.json")
        if fileManager.fileExists(atPath: localURL.path) {
            var local = try readObject(at: localURL)
            var localPermissions = local["permissions"] as? [String: Any] ?? [:]
            localPermissions["defaultMode"] = mode.rawValue
            local["permissions"] = localPermissions
            local["defaultMode"] = mode.rawValue
            let localResult = try writeIfChanged(local, to: localURL, now: now)
            if localResult.changed {
                changedFiles.append(localURL)
                if let backup = localResult.backup { backupFiles.append(backup) }
            }
        }

        return ClaudeSettingsApplyResult(changedFiles: changedFiles, backupFiles: backupFiles)
    }

    public static func settingsURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        filename: String = "settings.json"
    ) -> URL {
        homeDirectory.appendingPathComponent(".claude/\(filename)")
    }

    private static func stringArray(_ value: Any?) -> [String] {
        value as? [String] ?? []
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

    private static func writeIfChanged(
        _ object: [String: Any],
        to url: URL,
        now: Date
    ) throws -> (changed: Bool, backup: URL?) {
        let newData = try encoded(object)
        if let current = try? Data(contentsOf: url), normalizedJSON(current) == normalizedJSON(newData) {
            return (false, nil)
        }

        var backup: URL?
        if FileManager.default.fileExists(atPath: url.path) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let backupURL = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).island-settings-backup-\(formatter.string(from: now))")
            try FileManager.default.copyItem(at: url, to: backupURL)
            backup = backupURL
        }
        try newData.write(to: url, options: .atomic)
        return (true, backup)
    }

    private static func encoded(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    private static func normalizedJSON(_ data: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
