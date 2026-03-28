import SwiftUI
import SwiftData
import PhotosUI

@Observable
final class PoolViewModel {
    var poolName: String = ""
    var newItemName: String = ""
    var selectedPhoto: PhotosPickerItem? = nil
    var selectedImageData: Data? = nil

    func createPool(context: ModelContext) -> Pool? {
        guard !poolName.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let pool = Pool(name: poolName.trimmingCharacters(in: .whitespaces))
        context.insert(pool)
        try? context.save()
        poolName = ""
        return pool
    }

    func addItem(to pool: Pool, context: ModelContext) {
        guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let item = PoolItem(
            name: newItemName.trimmingCharacters(in: .whitespaces),
            imageData: selectedImageData
        )
        item.pool = pool
        context.insert(item)
        pool.items?.append(item)
        try? context.save()
        newItemName = ""
        selectedPhoto = nil
        selectedImageData = nil
    }

    func deleteItem(_ item: PoolItem, from pool: Pool, context: ModelContext) {
        pool.items?.removeAll { $0.id == item.id }
        context.delete(item)
        try? context.save()
    }

    func deletePool(_ pool: Pool, context: ModelContext) {
        context.delete(pool)
        try? context.save()
    }

    func loadImage() async {
        guard let photo = selectedPhoto else { return }
        if let data = try? await photo.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            let compressed = uiImage.compressed(maxDimension: 300, quality: 0.7)
            await MainActor.run {
                self.selectedImageData = compressed
            }
        }
    }
}
