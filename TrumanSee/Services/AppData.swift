import SwiftData

/// 앱 전역 SwiftData 컨테이너. 뷰(.modelContainer)와 백그라운드 태스크가 공유한다.
enum AppData {
    static let container: ModelContainer = {
        do { return try ModelContainer(for: Episode.self, EpisodeScene.self, CastMember.self) }
        catch { fatalError("ModelContainer 생성 실패: \(error)") }
    }()
}
