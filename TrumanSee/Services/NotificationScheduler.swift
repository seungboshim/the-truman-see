import Foundation
import UserNotifications

/// 로컬 알림. 밤 자동 생성이 끝나면 완료 알림을 쏜다 (블라인드 반복 알림 대신 실제 생성 시점에만).
enum NotificationScheduler {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// 에피소드 생성 완료 알림 — 트루먼쇼 명대사 모티프.
    static func postEpisodeReady(code: String, title: String) async {
        let content = UNMutableNotificationContent()
        content.title = "굿모닝 굿나잇 📺"
        content.body = "어젯밤 방송이 공개됐습니다. \(code) 〈\(title)〉 — 제작진"
        content.sound = .default
        // trigger nil = 즉시 전달 (BG 태스크가 밤에 실행되므로 그때 도착)
        let request = UNNotificationRequest(identifier: "episode-\(code)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
