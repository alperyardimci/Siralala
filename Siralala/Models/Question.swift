import Foundation
import SwiftData

@Model
final class Question {
    var id: UUID
    var text: String
    var itemCount: Int
    var createdAt: Date
    var isActive: Bool
    var pool: Pool?
    @Relationship(deleteRule: .cascade, inverse: \RankingSession.question)
    var sessions: [RankingSession]?

    init(text: String, pool: Pool, itemCount: Int = 10) {
        self.id = UUID()
        self.text = text
        self.pool = pool
        self.itemCount = min(itemCount, pool.itemCount)
        self.createdAt = Date()
        self.isActive = true
        self.sessions = []
    }

    var completedSessionCount: Int {
        sessions?.filter { $0.completedAt != nil }.count ?? 0
    }
}
