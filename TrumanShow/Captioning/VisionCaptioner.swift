import Foundation
import CoreGraphics
import Vision

/// Vision 프레임워크 온디바이스 캡셔닝 (전 기기 지원, iOS 13+).
/// 장면 분류 태그 + 얼굴 수 → "food, indoor, restaurant · 인물 2명" 형태의 거친 캡션.
/// 태그가 거칠어도 원칙("사진은 기기 밖으로 안 나감")을 전 기기에서 지킨다.
struct VisionCaptioner: PhotoCaptioner {
    /// 분류 확신도 하한. ponytail: 고정값으로 시작, 실기기 사진으로 튜닝.
    var minConfidence: Float = 0.3
    var maxTags: Int = 5

    func caption(_ image: CGImage) async throws -> String {
        let classify = VNClassifyImageRequest()
        let faces = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([classify, faces])

        let tags = (classify.results ?? [])
            .filter { $0.confidence >= minConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxTags)
            .map(\.identifier)

        let faceCount = faces.results?.count ?? 0

        var parts: [String] = []
        if !tags.isEmpty { parts.append(tags.joined(separator: ", ")) }
        if faceCount > 0 { parts.append("인물 \(faceCount)명") }
        return parts.isEmpty ? "(분석된 장면 정보 없음)" : parts.joined(separator: " · ")
    }
}
