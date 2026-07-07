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
            guard SystemLanguageModel.default.availability == .available else {
                throw NarratorError.onDeviceModelUnavailable
            }
            let session = LanguageModelSession(instructions: prompt.system)
            let response = try await session.respond(to: prompt.user)
            return try EpisodeDraft.parse(from: response.content)
        }
        #endif
        throw NarratorError.onDeviceModelUnavailable
    }
}
