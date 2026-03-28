import Foundation
import SwiftData

@Model
final class Pool {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \PoolItem.pool)
    var items: [PoolItem]?

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.items = []
    }

    var itemCount: Int {
        items?.count ?? 0
    }
}
