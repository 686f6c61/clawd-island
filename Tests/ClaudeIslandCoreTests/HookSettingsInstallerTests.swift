import Foundation
import XCTest
@testable import ClaudeIslandCore

final class HookSettingsInstallerTests: XCTestCase {
    func testInstallationPreservesExistingHooksAndIsIdempotent() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let claude = home.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        let settingsURL = claude.appendingPathComponent("settings.json")
        let existing: [String: Any] = [
            "permissions": ["defaultMode": "bypassPermissions"],
            "hooks": [
                "Stop": [["hooks": [["type": "command", "command": "existing-lcd-hook"]]]],
            ],
        ]
        try JSONSerialization.data(withJSONObject: existing).write(to: settingsURL)
        let helper = home.appendingPathComponent("source-helper")
        try Data("helper".utf8).write(to: helper)

        let first = try HookSettingsInstaller.install(helperSourceURL: helper, homeDirectory: home)
        let second = try HookSettingsInstaller.install(helperSourceURL: helper, homeDirectory: home)

        XCTAssertTrue(first.configurationChanged)
        XCTAssertFalse(second.configurationChanged)
        XCTAssertEqual(first.permissionMode, "bypassPermissions")
        XCTAssertEqual(try HookBridgeCredential.readToken(homeDirectory: home).count, 64)

        let installed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? [String: Any])
        let hooks = try XCTUnwrap(installed["hooks"] as? [String: Any])
        let stopGroups = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        XCTAssertEqual(stopGroups.count, 2)
        XCTAssertTrue(stopGroups.contains { group in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            return handlers.contains { ($0["command"] as? String) == "existing-lcd-hook" }
        })

        let preToolGroups = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        let islandMatchers = preToolGroups.compactMap { group -> String? in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            guard handlers.contains(where: { ($0["command"] as? String)?.contains("ClaudeIslandHook") == true }) else {
                return nil
            }
            return group["matcher"] as? String
        }
        XCTAssertEqual(islandMatchers.count, 2)
        XCTAssertTrue(islandMatchers.contains("AskUserQuestion"))
        XCTAssertTrue(islandMatchers.contains("Bash|Edit|Write|Read|Glob|Grep|NotebookEdit|WebFetch|WebSearch|Agent"))
    }

    func testEnablingPromptsUpdatesBothSettingsFiles() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let claude = home.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        for name in ["settings.json", "settings.local.json"] {
            let url = claude.appendingPathComponent(name)
            try JSONSerialization.data(withJSONObject: [
                "defaultMode": "bypassPermissions",
                "permissions": ["defaultMode": "bypassPermissions"],
            ]).write(to: url)
        }

        try HookSettingsInstaller.enablePermissionPrompts(homeDirectory: home)

        XCTAssertEqual(HookSettingsInstaller.effectivePermissionMode(homeDirectory: home), "default")
        for name in ["settings.json", "settings.local.json"] {
            let url = claude.appendingPathComponent(name)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            XCTAssertEqual(object["defaultMode"] as? String, "default")
            XCTAssertEqual((object["permissions"] as? [String: Any])?["defaultMode"] as? String, "default")
        }
    }

    func testUninstallRemovesOnlyIslandHooksAndHelper() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let claude = home.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        let settingsURL = claude.appendingPathComponent("settings.json")
        let installedCommand = "'\(home.appendingPathComponent("Library/Application Support/ClaudeIsland/ClaudeIslandHook").path)'"
        try JSONSerialization.data(withJSONObject: [
            "hooks": [
                "Stop": [["hooks": [
                    ["type": "command", "command": "existing-hook"],
                    ["type": "command", "command": installedCommand],
                ]]],
                "SessionStart": [["hooks": [
                    ["type": "command", "command": installedCommand],
                ]]],
            ],
        ]).write(to: settingsURL)
        let helper = home.appendingPathComponent("Library/Application Support/ClaudeIsland/ClaudeIslandHook")
        try FileManager.default.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("helper".utf8).write(to: helper)
        _ = try HookBridgeCredential.ensureToken(homeDirectory: home)

        let result = try HookSettingsInstaller.uninstall(homeDirectory: home)

        XCTAssertEqual(result.removedHandlers, 2)
        XCTAssertNotNil(result.backupURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: helper.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: HookBridgeCredential.tokenURL(homeDirectory: home).path
        ))
        XCTAssertFalse(HookSettingsInstaller.isInstalled(homeDirectory: home))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let stop = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        let handlers = try XCTUnwrap(stop.first?["hooks"] as? [[String: Any]])
        XCTAssertEqual(handlers.count, 1)
        XCTAssertEqual(handlers.first?["command"] as? String, "existing-hook")
        XCTAssertNil(hooks["SessionStart"])
    }
}
