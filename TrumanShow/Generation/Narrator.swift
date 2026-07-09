import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 내레이션 엔진: EpisodePrompt → LLM → EpisodeDraft.
/// 구현체: FMNarrator(온디바이스, 프라이버시 모드) / 이후 CloudNarrator(프록시 경유 Claude, 화질 모드).
protocol Narrator {
    func generate(_ prompt: EpisodePrompt) async throws -> EpisodeDraft
}

enum NarratorError: Error {
    /// Apple Intelligence 미지원/비활성 기기. 호출부에서 클라우드 폴백 또는 안내.
    case onDeviceModelUnavailable
    /// FM 가드레일 거부. 세계관 표현: 심의 반려.
    case censored
}

/// Foundation Models 온디바이스 내레이터 (iOS 26+, Apple Intelligence 기기).
/// 텍스트 전용 — 캡셔닝(Vision)이 만든 타임라인 텍스트를 받아 에피소드를 창작한다.
struct FMNarrator: Narrator {

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    func generate(_ prompt: EpisodePrompt) async throws -> EpisodeDraft {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // 완화 가드레일: 사용자 본인 데이터의 각색(콘텐츠 변환)이 용도라 기본 가드레일이 과민함
            // (실사례: 축구 세레모니 스샷의 Vision 태그가 기본 가드레일에 거부됨)
            let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            guard model.availability == .available else {
                throw NarratorError.onDeviceModelUnavailable
            }
            let session = LanguageModelSession(model: model, instructions: prompt.system)
            do {
                let response = try await session.respond(to: prompt.user)
                return try EpisodeDraft.parse(from: response.content)
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error { throw NarratorError.censored }
                throw error
            }
        }
        #endif
        throw NarratorError.onDeviceModelUnavailable
    }
}
