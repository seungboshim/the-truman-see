import Foundation
import UserNotifications

/// 밤마다 "오늘 에피소드 공개" 로컬 알림.
enum NotificationScheduler {
    static let hour = 21, minute = 30   // ponytail: 고정 시각. 설정 화면 생기면 옵션화

    static func scheduleNightly() async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "본방 사수 📺"
        content.body = "오늘 촬영분 편집이 끝났습니다. 새 에피소드가 공개됐어요. — 제작진"
        content.sound = .default

        var date = DateComponents()
        date.hour = hour; date.minute = minute
        let request = UNNotificationRequest(
            identifier: "nightly-episode",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        try? await center.add(request)   // 같은 id 재등록 = 갱신
    }
}
