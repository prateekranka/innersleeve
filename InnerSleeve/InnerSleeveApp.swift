import SwiftUI
import SwiftData

@main
struct InnerSleeveApp: App {
    let container: ModelContainer
    @State private var settings = SettingsStore()

    init() {
        do {
            container = try ModelContainer(
                for: Record.self, Track.self, PackageAttachment.self, WishlistItem.self, PlayLogEntry.self
            )
            let context = ModelContext(container)
            try FixtureData.seedIfNeeded(into: context)
        } catch {
            fatalError("Failed to set up the Inner Sleeve model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .environment(settings)
        }
        .modelContainer(container)
    }
}
