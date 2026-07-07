import Foundation
import CoreLocation

/// 좌표 → 동네 이름. CLGeocoder는 좌표를 Apple 서버로 보내 역지오코딩한다.
/// 우리 LLM/프록시로는 좌표가 아니라 여기서 나온 **동네 이름 텍스트만** 전송된다. (프라이버시 규칙)
enum NeighborhoodResolver {
    /// 실패/미허용 시 nil. 동(subLocality) 우선, 없으면 시·구(locality)로 폴백.
    static func neighborhood(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "ko_KR"))
        guard let p = placemarks?.first else { return nil }
        return p.subLocality ?? p.locality ?? p.name
    }
}
