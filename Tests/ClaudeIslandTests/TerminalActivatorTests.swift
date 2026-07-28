import Foundation
import XCTest
@testable import ClaudeIsland

@MainActor
final class TerminalActivatorTests: XCTestCase {
    func testTerminalLaunchUsesInjectedAsyncAppleScriptRunner() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let recorder = ScriptRecorder()
        let runner = TerminalActivator.AppleScriptRunner { source in
            await recorder.record(source)
        }

        try await TerminalActivator.launchClaude(
            at: folder.path,
            resumeSessionID: "session-id",
            preference: .terminal,
            appleScriptRunner: runner
        )

        let script = await recorder.script
        XCTAssertTrue(script.contains("tell application \"Terminal\""))
        XCTAssertTrue(script.contains("--resume"))
        XCTAssertTrue(script.contains("session-id"))
        XCTAssertTrue(script.contains(folder.path))
    }
}

private actor ScriptRecorder {
    private(set) var script = ""

    func record(_ source: String) {
        script = source
    }
}
