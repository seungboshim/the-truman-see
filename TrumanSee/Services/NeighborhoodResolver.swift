import Foundation
import CoreLocation

/// 좌표 → 동네 이름. CLGeocoder는 좌표를 Apple 서버로 보내 역지오코딩한다.
/// 우리 LLM/프록시로는 좌표가 아니라 여기서 나온 **동네 이름 텍스트만** 전송된다. (프라이버시 규칙)
enum NeighborhoodResolver {
    /// 실패/미허용/타임아웃 시 nil. 동(subLocality) 우선, 없으면 시·구(locality)로 폴백.
    /// CLGeocoder는 스로틀링되면 수 분씩 지연될 수 있어 타임아웃으로 파이프라인 행을 방지한다.
    static func neighborhood(for coordinate: CLLocationCoordinate2D,
                             timeout seconds: Double = 8) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
                    location, preferredLocale: Locale(identifier: "ko_KR"))
                guard let p = placemarks?.first else { return nil }
                return p.subLocality ?? p.locality ?? p.name
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
