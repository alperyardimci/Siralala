import SwiftData
import Foundation

struct MockData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Pool>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let pool = Pool(name: "Efsane Futbolcular")
        context.insert(pool)

        let players = [
            "Messi", "Ronaldo", "Neymar", "Mbappé", "Haaland",
            "Salah", "De Bruyne", "Modric", "Kroos", "Benzema",
            "Lewandowski", "Vinícius Jr.", "Bellingham", "Saka", "Foden",
            "Müller", "Kimmich", "Pedri", "Gavi", "Yamal"
        ]

        for name in players {
            let item = PoolItem(name: name)
            item.pool = pool
            context.insert(item)
        }

        try? context.save()
    }
}
