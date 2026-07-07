import Foundation

/// LLM이 돌려준 JSON을 파싱한 결과. 이후 앱 레이어에서 타임라인과 zip 해
/// Episode/EpisodeScene(SwiftData)로 매핑한다. (매핑은 저장 레이어 소관)
struct EpisodeDraft: Decodable, Equatable {
    let title: String
    let synopsis: String
    let viewerRating: Double
    let scenes: [SceneDraft]
    let viewerComments: [String]

    struct SceneDraft: Decodable, Equatable {
        let narration: String
    }

    enum ParseError: Error { case noJSONObject }

    /// LLM 출력에서 JSON 객체를 관대하게 추출해 디코드한다.
    /// LLM이 지시를 어기고 ```json 펜스나 머리말을 붙이는 실제 실패 모드를 흡수한다.
    static func parse(from raw: String) throws -> EpisodeDraft {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"), start < end else {
            throw ParseError.noJSONObject
        }
        let json = String(raw[start...end])
        return try JSONDecoder().decode(EpisodeDraft.self, from: Data(json.utf8))
    }
}
