import SwiftUI
import SwiftData

@main
struct TrumanSeeApp: App {
    @AppStorage("onboarded") private var onboarded = false

    init() {
        NightlyEpisodeTask.register()           // 앱 실행 완료 전에 등록 필수
        VisitTracker.shared.resumeIfEnabled()   // 위치 기록 재개(백그라운드 relaunch 포함)
        if onboarded { NightlyEpisodeTask.schedule() }  // 다음 밤 자동 생성 예약(갱신)
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
        .modelContainer(AppData.container)
    }
}
