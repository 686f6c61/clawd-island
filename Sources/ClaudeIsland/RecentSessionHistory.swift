import Foundation

enum RecentSessionHistory {
    static func updating(
        _ existing: [RecentClaudeSession],
        with candidate: RecentClaudeSession,
        now: Date,
        retention: TimeInterval,
        limit: Int
    ) -> [RecentClaudeSession] {
        guard limit > 0 else { return [] }

        let cutoff = now.addingTimeInterval(-retention)
        var sessionsByID: [String: RecentClaudeSession] = [:]
        for session in existing where session.lastUpdated >= cutoff {
            if let current = sessionsByID[session.id],
               current.lastUpdated >= session.lastUpdated {
                continue
            }
            sessionsByID[session.id] = session
        }

        if candidate.lastUpdated >= cutoff,
           sessionsByID[candidate.id]?.lastUpdated ?? .distantPast <= candidate.lastUpdated {
            sessionsByID[candidate.id] = candidate
        }

        return Array(
            sessionsByID.values
                .sorted { left, right in
                    if left.lastUpdated != right.lastUpdated {
                        return left.lastUpdated > right.lastUpdated
                    }
                    return left.id < right.id
                }
                .prefix(limit)
        )
    }
}
