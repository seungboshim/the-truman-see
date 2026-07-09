import SwiftUI
import SwiftData

@main
struct TrumanSeeApp: App {
    @AppStorage("onboarded") private var onboarded = false

    init() {
        // 이전에 위치 기록을 켰다면 재개 (백그라운드 relaunch 포함)
        VisitTracker.shared.resumeIfEnabled()
    }

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
