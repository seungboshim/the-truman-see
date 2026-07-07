import Foundation
import SwiftData

/// 에피소드를 구성하는 장면 단위.
/// (SwiftUI의 `Scene` 프로토콜과 이름 충돌을 피하려고 EpisodeScene으로 명명)
@Model
final class EpisodeScene {
    var id: UUID
    var order: Int
    /// 3인칭 방송 내레이션
    var narration: String
    var capturedAt: Date?
    /// 온디바이스 역지오코딩한 동네 이름 (GPS 좌표 아님)
    var locationName: String?
    /// 이 장면의 근거가 된 사진의 PHAsset localIdentifier. 원본 이미지는 저장하지 않는다.
    var photoAssetID: String?
    /// 실제로 LLM에 전송된 캡션/태그 텍스트 — 투명성 화면 "제작진이 본 것"에 그대로 노출
    var observedText: String?

    var episode: Episode?

    @Relationship(inverse: \CastMember.scenes)
    var cast: [CastMember]

    init(order: Int, narration: String, capturedAt: Date? = nil,
         locationName: String? = nil, photoAssetID: String? = nil,
         observedText: String? = nil) {
        self.id = UUID()
        self.order = order
        self.narration = narration
        self.capturedAt = capturedAt
        self.locationName = locationName
        self.photoAssetID = photoAssetID
        self.observedText = observedText
        self.cast = []
    }
}
