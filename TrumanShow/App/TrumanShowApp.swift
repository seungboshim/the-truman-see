import SwiftUI
import SwiftData

@main
struct TrumanShowApp: App {
    @AppStorage("onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            if onboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: [Episode.self, EpisodeScene.self, CastMember.self])
    }
}
