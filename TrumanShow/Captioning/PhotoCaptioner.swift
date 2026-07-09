import Foundation
import CoreGraphics

/// 사진 → 텍스트 캡션. 이 텍스트만 기기 밖으로 나갈 수 있다 (원본 이미지 금지).
/// 구현체: VisionCaptioner(전 기기, 온디바이스) / 이후 생생 모드(옵트인 클라우드) 추가.
/// 참고: iOS 26 SDK의 FoundationModels는 이미지 입력이 없어 캡셔닝 엔진이 될 수 없음 (SDK 확인).
protocol PhotoCaptioner {
    func caption(_ image: CGImage) async throws -> String
}

enum CaptionerFactory {
    /// 생생 모드(옵트인) + 키 존재 시에만 클라우드. 기본값은 항상 온디바이스 Vision.
    static var vividModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "vividMode") && Secrets.nvidiaKey != nil
    }

    static func make() -> PhotoCaptioner {
        if vividModeEnabled, let key = Secrets.nvidiaKey {
            return NvidiaCaptioner(apiKey: key)
        }
        return VisionCaptioner()
    }
}
