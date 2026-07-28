import Foundation
import XCTest
@testable import ClaudeIsland

final class AgentRetentionPolicyTests: XCTestCase {
    func testRetainsExactlyTwentyAgentsWhenAllAreBusy() {
        let now = Date()
        let agents = Dictionary(uniqueKeysWithValues: (0 ..< 25).map { index in
            let id = "agent-\(index)"
            return (
                id,
                AgentRecord(
                    id: id,
                    type: "Worker",
                    status: index.isMultiple(of: 2) ? .running : .waiting,
                    lastActivity: "Working",
                    lastUpdated: now.addingTimeInterval(TimeInterval(index))
                )
            )
        })

        let retained = AgentRetentionPolicy.retained(from: agents)

        XCTAssertEqual(retained.count, 20)
        XCTAssertNotNil(retained["agent-24"])
        XCTAssertNotNil(retained["agent-23"])
    }

    func testActiveAgentsDisplaceOlderCompletedAgents() {
        let now = Date()
        var agents = Dictionary(uniqueKeysWithValues: (0 ..< 20).map { index in
            let id = "completed-\(index)"
            return (
                id,
                AgentRecord(
                    id: id,
                    type: "Worker",
                    status: .completed,
                    lastActivity: "Done",
                    lastUpdated: now.addingTimeInterval(TimeInterval(index))
                )
            )
        })
        agents["waiting"] = AgentRecord(
            id: "waiting",
            type: "Reviewer",
            status: .waiting,
            lastActivity: "Needs permission",
            lastUpdated: now.addingTimeInterval(-1_000)
        )

        let retained = AgentRetentionPolicy.retained(from: agents)

        XCTAssertEqual(retained.count, 20)
        XCTAssertNotNil(retained["waiting"])
        XCTAssertNil(retained["completed-0"])
    }
}
