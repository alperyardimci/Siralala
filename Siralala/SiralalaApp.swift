import SwiftUI
import SwiftData

@main
struct SiralalaApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Pool.self,
            PoolItem.self,
            Question.self,
            RankingSession.self,
            RankingEntry.self
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            MockData.seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
