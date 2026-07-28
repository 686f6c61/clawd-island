import Foundation
import XCTest
@testable import ClaudeIsland

final class RecentSessionHistoryTests: XCTestCase {
    func testKeepsConcurrentSessionsInsteadOfThrottlingThemAway() {
        let now = Date()
        let first = RecentClaudeSession(
            id: "one",
            projectName: "One",
            cwd: "/tmp/one",
            lastUpdated: now
        )
        let second = RecentClaudeSession(
            id: "two",
            projectName: "Two",
            cwd: "/tmp/two",
            lastUpdated: now.addingTimeInterval(0.1)
        )

        let afterFirst = RecentSessionHistory.updating(
            [],
            with: first,
            now: now,
            retention: 60,
            limit: 12
        )
        let afterSecond = RecentSessionHistory.updating(
            afterFirst,
            with: second,
            now: now,
            retention: 60,
            limit: 12
        )

        XCTAssertEqual(afterSecond.map(\.id), ["two", "one"])
    }

    func testUpdatesExistingSessionAndPrunesExpiredEntries() {
        let now = Date()
        let expired = RecentClaudeSession(
            id: "expired",
            projectName: "Old",
            cwd: "/tmp/old",
            lastUpdated: now.addingTimeInterval(-120)
        )
        let previous = RecentClaudeSession(
            id: "active",
            projectName: "Before",
            cwd: "/tmp/active",
            lastUpdated: now.addingTimeInterval(-10)
        )
        let updated = RecentClaudeSession(
            id: "active",
            projectName: "After",
            cwd: "/tmp/active",
            lastUpdated: now
        )

        let result = RecentSessionHistory.updating(
            [expired, previous],
            with: updated,
            now: now,
            retention: 60,
            limit: 12
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "active")
        XCTAssertEqual(result.first?.projectName, "After")
    }

    func testRepairsDuplicateStoredSessionsWithoutCrashing() {
        let now = Date()
        let older = RecentClaudeSession(
            id: "duplicate",
            projectName: "Older",
            cwd: "/tmp/older",
            lastUpdated: now.addingTimeInterval(-10)
        )
        let newer = RecentClaudeSession(
            id: "duplicate",
            projectName: "Newer",
            cwd: "/tmp/newer",
            lastUpdated: now
        )
        let candidate = RecentClaudeSession(
            id: "other",
            projectName: "Other",
            cwd: "/tmp/other",
            lastUpdated: now.addingTimeInterval(-1)
        )

        let result = RecentSessionHistory.updating(
            [older, newer],
            with: candidate,
            now: now,
            retention: 60,
            limit: 12
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first { $0.id == "duplicate" }?.projectName, "Newer")
    }
}
