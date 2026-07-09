import Foundation
import SwiftData
import CoreGraphics

/// 하루 데이터 → 에피소드 파이프라인 글루.
/// 사진 수집 → 온디바이스 캡셔닝 → 타임라인 → 프롬프트 → 내레이터 → SwiftData 저장.
@MainActor
enum EpisodeComposer {

    enum ComposeError: Error { case photoAccessDenied }

    /// 방송일: 새벽 4시까지는 전날 취급 (자정 직후 생성 시 "오늘 사진 0장" 방지)
    static func broadcastDay(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .hour, value: -4, to: now)!
    }

    /// 방송일에 촬영분이 없으면 최대 lookback일 전까지 거슬러 올라가 사진 있는 날을 찾는다.
    /// 전부 없으면 방송일 그대로 반환 → 방송사고 에피소드.
    static func latestDayWithPhotos(lookback: Int = 2, calendar: Calendar = .current) -> Date {
        let base = broadcastDay(calendar: calendar)
        for back in 0...lookback {
            let candidate = calendar.date(byAdding: .day, value: -back, to: base)!
            if !PhotoCollector.photos(on: candidate, calendar: calendar).isEmpty { return candidate }
        }
        return base
    }

    /// 해당 날짜의 에피소드를 생성해 저장한다. 이미 있으면 지우고 다시 만든다(테스트 편의, 멱등).
    /// onProgress: 단계별 상태 문자열 (UI 표시 + 디버깅용)
    @discardableResult
    static func compose(day: Date = Date(), protagonist: String,
                        narrator: Narrator, context: ModelContext,
                        onProgress: @escaping (String) -> Void = { _ in }) async throws -> Episode {
        func stage(_ msg: String) { DebugLog.log("[Composer] \(msg)"); onProgress(msg) }

        guard PhotoCollector.authorizationStatus == .authorized
                || PhotoCollector.authorizationStatus == .limited else {
            throw ComposeError.photoAccessDenied
        }

        // 1. 수집 + 캡셔닝
        let allPhotos = PhotoCollector.photos(on: day)
        // 비슷한 시간대(10분 내) 연사는 대표컷 1장만, 최대 12장면 (FM 컨텍스트 보호)
        var photos: [DayPhoto] = []
        for p in allPhotos {
            if let last = photos.last, p.capturedAt.timeIntervalSince(last.capturedAt) < 600 { continue }
            photos.append(p)
        }
        if photos.count > 12 { photos = Array(photos.prefix(12)) }
        stage("촬영분 \(allPhotos.count)장 중 \(photos.count)장면 선별")
        let captioner = CaptionerFactory.make()
        var items: [TimelineItem] = []
        var geoCache: [String: String?] = [:]   // 근접 좌표 재사용 (CLGeocoder 스로틀 방지)
        for (i, photo) in photos.enumerated() {
            stage("장면 분석 중 \(i + 1)/\(photos.count)")
            // 캡셔닝엔 512px이면 충분 — 원본 로드 낭비 방지
            guard let cg = await PhotoCollector.image(for: photo.assetID,
                                                      targetSize: .init(width: 512, height: 512))?.cgImage
            else { stage("장면 \(i + 1) 이미지 로드 실패 — 건너뜀"); continue }
            let caption = (try? await captioner.caption(cg, isScreenshot: photo.isScreenshot)) ?? "(분석 실패)"
            var neighborhood: String? = nil
            if let coord = photo.coordinate {
                // ~1km 그리드로 캐시. 같은 동네 사진 수십 장이 지오코딩 1회로 처리됨
                let key = "\((coord.latitude * 100).rounded()),\((coord.longitude * 100).rounded())"
                if let cached = geoCache[key] {
                    neighborhood = cached
                } else {
                    neighborhood = await NeighborhoodResolver.neighborhood(for: coord, timeout: 8)
                    geoCache[key] = neighborhood
                }
            }
            // 셀카 레퍼런스가 있으면 얼굴 매칭으로 주인공 등장 판별, 없으면 "카메라 뒤" 가정
            // 스크린샷 속 인물(TV·화면)은 실제 출연진이 아니므로 세지 않는다
            // ponytail: 캡션 문자열의 "인물 N명" 재파싱 — 캡셔너 구조화 필요해지면 프로토콜 확장
            var castLabels: [String] = []
            let faceCount = caption.firstMatch(of: /인물 (\d+)명/).flatMap { Int($0.1) } ?? 0
            if faceCount > 0 && !photo.isScreenshot {
                if FaceMatcher.hasReference, FaceMatcher.containsProtagonist(cg) {
                    castLabels.append("주인공 본인 등장")
                    if faceCount > 1 { castLabels.append("이름 모를 출연자 \(faceCount - 1)명") }
                } else {
                    castLabels.append("이름 모를 출연자 \(faceCount)명")
                }
            }
            DebugLog.log("[Caption] \(i + 1)/\(photos.count) \(Self.timeText(photo.capturedAt)) → \(caption) | 출연: \(castLabels.joined(separator: ","))")
            items.append(TimelineItem(timeText: Self.timeText(photo.capturedAt),
                                      neighborhood: neighborhood,
                                      caption: caption,
                                      castLabels: castLabels,
                                      isScreenshot: photo.isScreenshot))
        }

        // 2. 프롬프트 → 내레이션
        stage("작가가 대본 집필 중… (온디바이스)")
        let number = nextEpisodeNumber(context: context)
        let ctx = DayContext(protagonistName: protagonist,
                             episodeCode: String(format: "S01E%02d", number),
                             dateText: Self.dateText(day),
                             items: items)
        let draft = try await narrator.generate(EpisodePromptBuilder.build(ctx))
        stage("편집 및 방송 준비")

        // 3. 저장 (같은 날 기존 에피소드는 교체)
        let dayStart = Calendar.current.startOfDay(for: day)
        try deleteExisting(airDate: dayStart, context: context)

        let episode = Episode(episode: number, airDate: dayStart, title: draft.title,
                              synopsis: draft.synopsis, viewerRating: draft.viewerRating,
                              viewerComments: draft.viewerComments,
                              isBroadcastAccident: items.isEmpty)
        episode.usedCloudVision = CaptionerFactory.vividModeEnabled
        context.insert(episode)
        for (i, scene) in draft.scenes.enumerated() {
            // 정상 에피소드는 장면=사진 1:1 (프롬프트 계약). 방송사고는 사진 없음.
            let src: TimelineItem? = items.indices.contains(i) ? items[i] : nil
            let photo: DayPhoto? = photos.indices.contains(i) ? photos[i] : nil
            let s = EpisodeScene(order: i, narration: scene.narration,
                                 capturedAt: photo?.capturedAt,
                                 locationName: src?.neighborhood,
                                 photoAssetID: photo?.assetID,
                                 observedText: src?.caption)   // 투명성: 실제 전송 텍스트
            s.episode = episode
            context.insert(s)
        }
        try context.save()
        return episode
    }

    // MARK: - 헬퍼

    static func nextEpisodeNumber(context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<Episode>())) ?? []
        return (all.map(\.episode).max() ?? 0) + 1
    }

    private static func deleteExisting(airDate: Date, context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Episode>(
            predicate: #Predicate { $0.airDate == airDate }))
        existing.forEach { context.delete($0) }
    }

    static func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h시 m분"
        return f.string(from: date)
    }

    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        return f.string(from: date)
    }
}
