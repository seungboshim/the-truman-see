import Foundation
import SwiftData

/// 출연진. 주인공은 기본적으로 카메라 뒤(미등장) 가정.
/// 사진 속 인물은 조연/특별 게스트로 서술한다.
@Model
final class CastMember {
    var id: UUID
    /// 사용자가 지정한 이름. nil = 아직 미확인 인물 ("제작진이 알아보지 못한 출연자")
    var name: String?
    var isProtagonist: Bool
    /// 배역 라벨: "조연", "특별 게스트" 등 연출용
    var roleLabel: String
    /// lazy 등록된 레퍼런스 사진들의 PHAsset localIdentifier
    var referenceAssetIDs: [String]
    var appearanceCount: Int
    var createdAt: Date

    var scenes: [EpisodeScene]

    init(name: String? = nil, isProtagonist: Bool = false,
         roleLabel: String = "조연", referenceAssetIDs: [String] = []) {
        self.id = UUID()
        self.name = name
        self.isProtagonist = isProtagonist
        self.roleLabel = roleLabel
        self.referenceAssetIDs = referenceAssetIDs
        self.appearanceCount = 0
        self.createdAt = Date()
        self.scenes = []
    }
}
