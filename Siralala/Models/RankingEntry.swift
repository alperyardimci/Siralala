import Foundation
import SwiftData

@Model
final class RankingEntry {
    var id: UUID
    var rank: Int
    var item: PoolItem?
    var session: RankingSession?

    init(rank: Int, item: PoolItem) {
        self.id = UUID()
        self.rank = rank
        self.item = item
    }
}
