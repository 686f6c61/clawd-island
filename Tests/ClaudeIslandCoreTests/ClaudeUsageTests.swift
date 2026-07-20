import ClaudeIslandCore
import XCTest

final class ClaudeUsageTests: XCTestCase {
    func testDecodesCurrentAndWeeklyWindows() throws {
        let data = Data(#"""
        {
          "five_hour": {
            "utilization": 42.5,
            "resets_at": "2026-07-19T12:09:59.969620+00:00"
          },
          "seven_day": {
            "utilization": 13,
            "resets_at": "2026-07-26T00:59:59+00:00"
          },
          "seven_day_opus": null
        }
        """#.utf8)

        let snapshot = try ClaudeUsageSnapshot.decodeAPIResponse(from: data)

        XCTAssertEqual(snapshot.fiveHour?.utilization, 42.5)
        XCTAssertEqual(snapshot.sevenDay?.utilization, 13)
        XCTAssertNotNil(snapshot.fiveHour?.resetsAt)
        XCTAssertNotNil(snapshot.sevenDay?.resetsAt)
    }

    func testClampsUnexpectedUtilizationValues() throws {
        let snapshot = ClaudeUsageSnapshot(
            fiveHour: ClaudeUsageWindow(utilization: -4, resetsAt: nil),
            sevenDay: ClaudeUsageWindow(utilization: 112, resetsAt: nil)
        )

        XCTAssertEqual(snapshot.fiveHour?.utilization, 0)
        XCTAssertEqual(snapshot.sevenDay?.utilization, 100)
    }
}
