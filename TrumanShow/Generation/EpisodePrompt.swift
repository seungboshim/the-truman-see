import Foundation

// 에피소드 생성 프롬프트. 세계관/톤 규칙(킥오프)을 여기서 반복 튜닝한다.
// 순수 Foundation만 사용 — SwiftData/SwiftUI와 분리해 엔진(FM/클라우드) 무관하게 재사용·테스트.

// MARK: - 입력 (순수 값 타입)

/// 타임라인 항목 1개 = 그날의 한 순간. 장면 1개에 대응된다.
struct TimelineItem {
    /// 사람이 읽는 시각 문자열 ("오후 2시 13분"). 정밀 타임스탬프·좌표는 넣지 않는다.
    let timeText: String
    /// 온디바이스 역지오코딩한 동네 이름. 없으면 nil.
    let neighborhood: String?
    /// 온디바이스 캡션/태그(Vision 또는 FM). "제작진이 본 것"에 그대로 노출되는 텍스트.
    let caption: String?
    /// 이 순간의 출연진 라벨. 이름이 있으면 이름, 없으면 "이름 모를 조연" 등.
    let castLabels: [String]
}

/// 하루치 생성 컨텍스트.
struct DayContext {
    let protagonistName: String
    let episodeCode: String     // "S01E03"
    let dateText: String        // "2026년 7월 7일 화요일"
    let items: [TimelineItem]   // 시간순
}

/// LLM에 넘길 최종 프롬프트 (엔진에 따라 system=instructions, user=prompt로 매핑).
struct EpisodePrompt {
    let system: String
    let user: String
}

// MARK: - 빌더

enum EpisodePromptBuilder {

    static func build(_ ctx: DayContext) -> EpisodePrompt {
        EpisodePrompt(system: systemPrompt,
                      user: ctx.items.isEmpty ? accidentUser(ctx) : normalUser(ctx))
    }

    // MARK: 세계관 규칙 (튜닝 포인트) ──────────────────────────────────────────

    static let systemPrompt = """
    너는 리얼리티 관찰 예능 〈트루먼쇼〉의 전담 내레이터이자 작가다.
    한 사람의 평범한 하루를, 온 국민이 지켜보는 황금시간대 방송처럼 각색한다.

    [목소리]
    - 항상 3인칭. 주인공을 "그", "그녀", 또는 이름으로 부른다. "너/당신"은 쓰지 않는다.
    - 무미건조한 데이터를 드라마틱하게 과장한다. (예: "인스타그램 2시간" → "주인공의 도피는 오후 내내 계속됐다.")
    - 애정 어린 관찰 예능 톤. 주인공을 아끼는 제작진의 시선이다.
      감시·공포·협박 톤 금지("지켜보고 있다" 류 금지). 따뜻하고 능청스럽게.

    [카메라 규칙]
    - 사진은 주인공이 '찍은' 것이다. 그러므로 주인공은 기본적으로 카메라 뒤에 있다.
    - 사진 속 인물은 기본적으로 출연진 — 조연, 특별 게스트로 서술한다. 주인공이라고 단정하지 마라.
    - 단, 출연 정보에 '주인공 본인 등장'이 있는 장면은 주인공이 실제로 프레임에 잡힌 것이다.
      그 장면에서만 주인공의 모습을 묘사할 수 있다 — 좀처럼 카메라에 안 잡히던 주인공이 포착된 순간처럼 연출하라.
    - 그 외 장면에서 주인공의 표정·뒷모습·옷차림을 직접 봤다고 서술하지 마라 — 카메라 뒤라 보이지 않는다.
      대신 제작진의 능청스러운 추정으로 처리하라. (예: "표정은 잡히지 않았지만, 제작진은 그가 웃고 있었으리라 확신한다.")

    [정서 규칙]
    - 사진에 인물이 없다고 주인공이 외롭다고 해석하지 마라. 주인공은 카메라 뒤에 있을 뿐이다.
      '고독', '외로움', '쓸쓸함' 같은 단어와 그 클리셰를 금지한다.
    - 감정을 단정하지 말고, 장면마다 정서를 다르게 가져가라: 능청, 유머, 긴장, 설렘, 허세, 반전.

    [출력 형식]
    - 오직 JSON만 출력한다. 코드펜스(```)·설명·머리말 없이 JSON 객체 하나만.
    - 시청률과 시청자 댓글은 전부 가상의 연출이다. 실제 수치가 아니다.
    - 한국어로 쓴다.
    """

    // MARK: 정상 에피소드 ────────────────────────────────────────────────────

    static func normalUser(_ ctx: DayContext) -> String {
        let timeline = ctx.items.enumerated().map { i, item in
            let loc = item.neighborhood.map { " · \($0)" } ?? ""
            let obs = item.caption ?? "(장면 정보 없음)"
            let cast = item.castLabels.isEmpty ? "" : " · 출연: \(item.castLabels.joined(separator: ", "))"
            return "\(i + 1). \(item.timeText)\(loc)\(cast)\n   관찰: \(obs)"
        }.joined(separator: "\n")

        return """
        [에피소드] \(ctx.episodeCode) — \(ctx.dateText)
        [주인공] \(ctx.protagonistName)

        [오늘의 관찰 기록 — 시간순]
        \(timeline)

        위 기록으로 오늘 에피소드를 각색하라.
        - scenes 배열은 위 관찰 기록과 **같은 개수·같은 순서**로 만든다. (항목 N개 → 장면 N개)
        - 각 narration은 해당 항목을 각색한 3인칭 내레이션 2~4문장.

        \(schema)
        """
    }

    // MARK: 방송 사고 에피소드 (데이터 결측) ──────────────────────────────────

    static func accidentUser(_ ctx: DayContext) -> String {
        """
        [에피소드] \(ctx.episodeCode) — \(ctx.dateText)
        [주인공] \(ctx.protagonistName)

        오늘 주인공이 카메라에 거의 잡히지 않았다. 제작진에게 들어온 신호가 없다.
        이것을 '방송 사고' 에피소드로 만든다 — 신호를 잃은 제작진의 당혹, 정적, 시청률 급락을 메타적으로 각색하라.
        결측 자체가 콘텐츠다. 억지로 사실을 지어내지 말고, 아무 일도 잡히지 않았다는 상황을 드라마로 만든다.

        - scenes는 3~4개 자유 구성.
        - viewerRating은 평소보다 확 낮은 급락 수치로.

        \(schema)
        """
    }

    // MARK: 공통 출력 스키마 ──────────────────────────────────────────────────

    static let schema = """
    아래 JSON 스키마로만 응답하라:
    {
      "title": "짧고 자극적인 에피소드 제목",
      "synopsis": "한 줄 예고편 카피",
      "viewerRating": 0~30 사이 소수점 1자리 시청률 숫자(%),
      "scenes": [ { "narration": "3인칭 방송 내레이션" } ],
      "viewerComments": ["가짜 시청자 댓글", "가짜 시청자 댓글", "가짜 시청자 댓글"]
    }
    viewerComments는 정확히 3개. 그날 내용을 능청스럽게 물고 늘어지는 댓글로.
    """
}
