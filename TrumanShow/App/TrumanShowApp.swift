import SwiftUI
import SwiftData

@main
struct TrumanShowApp: App {
    @AppStorage("onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    ContentView().transition(.opacity)
                } else {
                    OnboardingView().transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: onboarded)
        }
        .modelContainer(for: [Episode.self, EpisodeScene.self, CastMember.self])
    }
}
