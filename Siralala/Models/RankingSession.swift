import Foundation
import SwiftData

@Model
final class RankingSession {
    var id: UUID
    var participantName: String
    var completedAt: Date?
    var selectedItemIDs: [UUID]
    var question: Question?
    @Relationship(deleteRule: .cascade, inverse: \RankingEntry.session)
    var entries: [RankingEntry]?

    init(participantName: String, question: Question, selectedItemIDs: [UUID]) {
        self.id = UUID()
        self.participantName = participantName
        self.question = question
        self.selectedItemIDs = selectedItemIDs
        self.completedAt = nil
        self.entries = []
    }

    var sortedEntries: [RankingEntry] {
        (entries ?? []).sorted { $0.rank < $1.rank }
    }

    var isCompleted: Bool {
        completedAt != nil
    }
}
