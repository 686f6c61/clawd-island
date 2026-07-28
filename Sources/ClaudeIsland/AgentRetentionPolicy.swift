import Foundation

enum AgentRetentionPolicy {
    static let defaultLimit = 20

    static func retained(
        from agents: [String: AgentRecord],
        limit: Int = defaultLimit
    ) -> [String: AgentRecord] {
        guard limit > 0 else { return [:] }
        guard agents.count > limit else { return agents }

        let retained = agents.values.sorted { left, right in
            let leftPriority = priority(of: left.status)
            let rightPriority = priority(of: right.status)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            if left.lastUpdated != right.lastUpdated {
                return left.lastUpdated > right.lastUpdated
            }
            return left.id < right.id
        }
        .prefix(limit)

        return Dictionary(uniqueKeysWithValues: retained.map { ($0.id, $0) })
    }

    private static func priority(of status: SessionStatus) -> Int {
        switch status {
        case .waiting: 0
        case .running: 1
        case .failed: 2
        case .completed: 3
        case .idle: 4
        }
    }
}
