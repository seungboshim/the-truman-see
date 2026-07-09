import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 내레이션 엔진: EpisodePrompt → LLM → EpisodeDraft.
/// 구현체: FMNarrator(온디바이스, 프라이버시 모드) / NvidiaNarrator(클라우드, 생생 모드).
protocol Narrator {
    func generate(_ prompt: EpisodePrompt) async throws -> EpisodeDraft
}

/// 모드 일관성: 생생 모드는 이미 사진을 클라우드로 보냈으므로 내레이션도 강한 클라우드 모델(Gemma)로,
/// 프라이버시 모드는 아무것도 내보내지 않도록 온디바이스 FM으로. (캡셔너 모드와 동일 기준)
enum NarratorFactory {
    static func make() -> Narrator {
        if CaptionerFactory.vividModeEnabled, let key = Secrets.nvidiaKey {
            return NvidiaNarrator(apiKey: key)
        }
        return FMNarrator()
    }
}

/// 생생 모드 내레이터 — NVIDIA Gemma 4 텍스트 완성. 프롬프트 규칙 준수도가 온디바이스 FM보다 높다.
struct NvidiaNarrator: Narrator {
    let apiKey: String
    var model = "google/gemma-4-31b-it"

    func generate(_ prompt: EpisodePrompt) async throws -> EpisodeDraft {
        let messages: [Any] = [
            ["role": "system", "content": prompt.system],
            ["role": "user", "content": prompt.user]
        ]
        let content = try await NvidiaClient.chat(apiKey: apiKey, model: model, messages: messages,
                                                  maxTokens: 1200, temperature: 0.9)
        return try EpisodeDraft.parse(from: content)
    }
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
