import Foundation
import SwiftData

/// 하루치 방송 에피소드 (S01E01 ...). 로컬 전용, 서버 저장 없음.
@Model
final class Episode {
    var id: UUID
    var season: Int
    var episode: Int
    /// 이 에피소드가 다루는 날 (자정 기준)
    var airDate: Date
    var title: String
    var synopsis: String?
    /// 가상의 시청률 (연출용 수치)
    var viewerRating: Double
    /// 가짜 시청자 댓글 3개 (연출)
    var viewerComments: [String]
    /// 제작 리포트 — 스크린타임 룰셋 코멘트. 온디바이스 전용, 절대 외부 전송 금지.
    var productionReport: String?
    /// 데이터 결측일 = 방송 사고 에피소드
    var isBroadcastAccident: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \EpisodeScene.episode)
    var scenes: [EpisodeScene]

    init(season: Int = 1, episode: Int, airDate: Date, title: String,
         synopsis: String? = nil, viewerRating: Double = 0,
         viewerComments: [String] = [], productionReport: String? = nil,
         isBroadcastAccident: Bool = false) {
        self.id = UUID()
        self.season = season
        self.episode = episode
        self.airDate = airDate
        self.title = title
        self.synopsis = synopsis
        self.viewerRating = viewerRating
        self.viewerComments = viewerComments
        self.productionReport = productionReport
        self.isBroadcastAccident = isBroadcastAccident
        self.createdAt = Date()
        self.scenes = []
    }

    /// "S01E01" 형식
    var code: String { String(format: "S%02dE%02d", season, episode) }

    var orderedScenes: [EpisodeScene] { scenes.sorted { $0.order < $1.order } }
}
