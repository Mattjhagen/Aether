import SwiftUI
import SwiftData

@main
public struct AetherApp: App {
    
    public var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Document.self,
            ReadingProgress.self,
            Highlight.self,
            VoiceProfile.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark) // Force dark, distraction-free aesthetic
        }
        .modelContainer(sharedModelContainer)
    }
}
