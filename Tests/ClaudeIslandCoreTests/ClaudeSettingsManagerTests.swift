import Foundation
import XCTest
@testable import ClaudeIslandCore

final class ClaudeSettingsManagerTests: XCTestCase {
    func testSnapshotUsesLocalModeAndReadsUserRules() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try write([
            "permissions": [
                "defaultMode": "default",
                "allow": ["Bash(git status)", "Edit"],
                "ask": ["WebFetch"],
                "deny": ["Read(.env)"],
            ],
        ], to: home.appendingPathComponent(".claude/settings.json"))
        try write([
            "permissions": ["defaultMode": "plan"],
        ], to: home.appendingPathComponent(".claude/settings.local.json"))

        let snapshot = try ClaudeSettingsManager.snapshot(homeDirectory: home)

        XCTAssertEqual(snapshot.mode, .plan)
        XCTAssertEqual(snapshot.allowRules, ["Bash(git status)", "Edit"])
        XCTAssertEqual(snapshot.askRules, ["WebFetch"])
        XCTAssertEqual(snapshot.denyRules, ["Read(.env)"])
    }

    func testApplyBacksUpSettingsAndMergesManagedAskRules() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let userURL = home.appendingPathComponent(".claude/settings.json")
        let localURL = home.appendingPathComponent(".claude/settings.local.json")
        try write([
            "unrelated": true,
            "permissions": [
                "defaultMode": "default",
                "allow": ["Bash(git status)", "Edit"],
                "ask": ["CustomTool", "Read"],
            ],
        ], to: userURL)
        try write(["permissions": ["defaultMode": "default"]], to: localURL)

        let result = try ClaudeSettingsManager.apply(
            mode: .acceptEdits,
            alwaysAskTools: ["Bash", "WebFetch"],
            removingAllowRules: ["Edit"],
            homeDirectory: home,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(Set(result.changedFiles), Set([userURL, localURL]))
        XCTAssertEqual(result.backupFiles.count, 2)
        let user = try read(userURL)
        let permissions = try XCTUnwrap(user["permissions"] as? [String: Any])
        XCTAssertEqual(permissions["defaultMode"] as? String, "acceptEdits")
        XCTAssertEqual(permissions["allow"] as? [String], ["Bash(git status)"])
        XCTAssertEqual(Set(permissions["ask"] as? [String] ?? []), Set(["Bash", "CustomTool", "WebFetch"]))
        XCTAssertEqual(user["unrelated"] as? Bool, true)

        let local = try read(localURL)
        XCTAssertEqual((local["permissions"] as? [String: Any])?["defaultMode"] as? String, "acceptEdits")
    }

    private func makeHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        return home
    }

    private func write(_ object: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object).write(to: url)
    }

    private func read(_ url: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }
}
