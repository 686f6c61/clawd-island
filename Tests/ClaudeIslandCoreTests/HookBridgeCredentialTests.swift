import Foundation
import XCTest
@testable import ClaudeIslandCore

final class HookBridgeCredentialTests: XCTestCase {
    func testCreatesStablePrivateCredential() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let first = try HookBridgeCredential.ensureToken(homeDirectory: home)
        let second = try HookBridgeCredential.ensureToken(homeDirectory: home)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 64)
        XCTAssertTrue(first.allSatisfy { $0.isHexDigit && !$0.isUppercase })

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: HookBridgeCredential.supportDirectory(homeDirectory: home).path
        )
        let tokenAttributes = try FileManager.default.attributesOfItem(
            atPath: HookBridgeCredential.tokenURL(homeDirectory: home).path
        )
        XCTAssertEqual(((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue ?? -1) & 0o777, 0o700)
        XCTAssertEqual(((tokenAttributes[.posixPermissions] as? NSNumber)?.intValue ?? -1) & 0o777, 0o600)
    }

    func testRejectsInvalidExistingCredential() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = HookBridgeCredential.supportDirectory(homeDirectory: home)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-a-token\n".utf8).write(to: HookBridgeCredential.tokenURL(homeDirectory: home))

        XCTAssertThrowsError(try HookBridgeCredential.ensureToken(homeDirectory: home))
    }
}
