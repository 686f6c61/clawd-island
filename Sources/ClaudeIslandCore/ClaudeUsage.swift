import Foundation

public struct ClaudeUsageWindow: Codable, Sendable, Equatable {
    public let utilization: Double
    public let resetsAt: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = min(max(utilization, 0), 100)
        self.resetsAt = resetsAt
    }
}

public struct ClaudeUsageSnapshot: Codable, Sendable, Equatable {
    public let fiveHour: ClaudeUsageWindow?
    public let sevenDay: ClaudeUsageWindow?

    public init(fiveHour: ClaudeUsageWindow?, sevenDay: ClaudeUsageWindow?) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    public static func decodeAPIResponse(from data: Data) throws -> ClaudeUsageSnapshot {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
                return date
            }
            if let date = try? Date.ISO8601FormatStyle().parse(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
        return try decoder.decode(ClaudeUsageSnapshot.self, from: data)
    }
}
