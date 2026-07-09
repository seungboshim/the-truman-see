import Foundation
import BackgroundTasks

/// 밤마다 자동으로 에피소드를 생성하는 백그라운드 태스크 (BGProcessingTask).
/// 충전 중(주로 밤)에 실행 → 온디바이스 FM은 네트워크 없이도 생성 가능한 게 이점.
/// 완료 시 알림 → "밤에 알림 받고 시청만 한다"는 핵심 UX 완성.
enum NightlyEpisodeTask {
    static let identifier = "com.seungboshim.trumansee.nightly"

    /// 앱 실행 완료 전에 호출해야 함 (App.init).
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task as! BGProcessingTask)
        }
        DebugLog.log("[BG] 등록됨")
    }

    static func schedule() {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresExternalPower = true                              // 충전 중(밤)에
        request.requiresNetworkConnectivity = CaptionerFactory.vividModeEnabled  // 생생 모드만 네트워크
        request.earliestBeginDate = nextEarlyMorning()
        do {
            try BGTaskScheduler.shared.submit(request)
            DebugLog.log("[BG] 예약 \(request.earliestBeginDate?.description ?? "")")
        } catch {
            DebugLog.log("[BG] 예약 실패 \(error)")
        }
    }

    private static func nextEarlyMorning() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 3; comps.minute = 0
        var target = cal.date(from: comps)!
        if target <= Date() { target = cal.date(byAdding: .day, value: 1, to: target)! }
        return target
    }

    private static func handle(_ task: BGProcessingTask) {
        schedule()   // 다음 밤 재예약 (연쇄)
        let work = Task { @MainActor in
            do {
                let name = UserDefaults.standard.string(forKey: "protagonistName") ?? "주인공"
                let ep = try await EpisodeComposer.compose(
                    day: EpisodeComposer.latestDayWithPhotos(),
                    protagonist: name,
                    narrator: NarratorFactory.make(),
                    context: AppData.container.mainContext)
                await NotificationScheduler.postEpisodeReady(code: ep.code, title: ep.title)
                DebugLog.log("[BG] 생성 완료 \(ep.code)")
                task.setTaskCompleted(success: true)
            } catch {
                DebugLog.log("[BG] 생성 실패 \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { work.cancel() }
    }
}
