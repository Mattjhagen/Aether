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
            print("SwiftData ModelContainer initialization failed (likely due to schema mismatch). Resetting store...")
            
            // Clean up the legacy SQLite files from Application Support to solve schema conflicts
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if let files = try? fileManager.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil) {
                    for file in files {
                        if file.lastPathComponent.contains("default.store") {
                            try? fileManager.removeItem(at: file)
                        }
                    }
                }
            }
            
            // Attempt to recreate the ModelContainer
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create SwiftData ModelContainer after reset: \(error.localizedDescription)")
            }
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
