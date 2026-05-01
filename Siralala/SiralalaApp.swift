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
            // Demo content is now seeded server-side during onboarding
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .tint(Color.dsDeep)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
        .modelContainer(container)
    }
}
