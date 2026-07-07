import SwiftUI
import SwiftData

@main
struct TrumanShowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Episode.self, EpisodeScene.self, CastMember.self])
    }
}
