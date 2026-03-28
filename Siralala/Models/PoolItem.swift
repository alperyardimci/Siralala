import Foundation
import SwiftData

@Model
final class PoolItem {
    var id: UUID
    var name: String
    @Attribute(.externalStorage)
    var imageData: Data?
    var pool: Pool?

    init(name: String, imageData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.imageData = imageData
    }
}
