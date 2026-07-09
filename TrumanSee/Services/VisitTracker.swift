import Foundation
import CoreLocation

/// CLVisit 백그라운드 방문 기록. 사진이 없는 시간대의 동선을 채운다 (저전력).
/// Always 권한 필요. 방문은 앱이 꺼져 있어도 시스템이 relaunch해 전달 → 파일에 누적.
struct VisitRecord: Codable {
    let latitude: Double
    let longitude: Double
    let arrival: Date
    let departure: Date
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

final class VisitTracker: NSObject, CLLocationManagerDelegate {
    static let shared = VisitTracker()

    private let manager = CLLocationManager()
    private static let storeURL = URL.documentsDirectory.appendingPathComponent("visits.json")
    private static let enabledKey = "visitTracking"

    override init() {
        super.init()
        manager.delegate = self
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 위치 기록 시작 — Always 권한 요청 + 방문 모니터링.
    func enable() {
        Self.isEnabled = true
        manager.requestAlwaysAuthorization()
        manager.startMonitoringVisits()
        DebugLog.log("[Visit] 모니터링 시작")
    }

    func disable() {
        Self.isEnabled = false
        manager.stopMonitoringVisits()
    }

    /// 앱 실행 시 이전에 켜져 있었으면 재개 (백그라운드 relaunch 포함).
    func resumeIfEnabled() {
        if Self.isEnabled { manager.startMonitoringVisits() }
    }

    // MARK: 델리게이트

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // arrival 미상이면 distantPast, 아직 머무는 중이면 departure = distantFuture
        let arrival = visit.arrivalDate == .distantPast ? Date() : visit.arrivalDate
        Self.append(VisitRecord(latitude: visit.coordinate.latitude,
                                longitude: visit.coordinate.longitude,
                                arrival: arrival,
                                departure: visit.departureDate))
        DebugLog.log("[Visit] 기록 (\(visit.coordinate.latitude), \(visit.coordinate.longitude))")
    }

    // MARK: 저장 (append-only JSON, 14일 보관)

    private static func load() -> [VisitRecord] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        return (try? JSONDecoder().decode([VisitRecord].self, from: data)) ?? []
    }

    private static func append(_ rec: VisitRecord) {
        let cutoff = Date().addingTimeInterval(-14 * 86400)
        let all = (load() + [rec]).filter { $0.arrival > cutoff }
        try? JSONEncoder().encode(all).write(to: storeURL)
    }

    /// 해당 날짜에 도착한 방문들 (시간순).
    static func visits(on day: Date, calendar: Calendar = .current) -> [VisitRecord] {
        let b = PhotoCollector.dayBounds(for: day, calendar: calendar)
        return load().filter { $0.arrival >= b.start && $0.arrival < b.end }
                     .sorted { $0.arrival < $1.arrival }
    }
}
