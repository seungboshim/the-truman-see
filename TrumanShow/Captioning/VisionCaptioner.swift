import Foundation
import CoreGraphics
import Vision

/// Vision 프레임워크 온디바이스 캡셔닝 (전 기기 지원).
/// 장면 분류 + 얼굴 수 + OCR + 반려동물 → 거친 태그 캡션.
/// 분류는 고정 분류표라 거칠지만, OCR이 간판·메뉴판·스크린샷의 구체 정보를 채운다.
/// 태그가 거칠어도 원칙("사진은 기기 밖으로 안 나감")을 전 기기에서 지킨다.
struct VisionCaptioner: PhotoCaptioner {
    /// ponytail: 실기기 튜닝 결과 0.3은 food/restaurant급 태그를 잘라냄 → 0.15
    var minConfidence: Float = 0.15
    var maxTags: Int = 7
    var maxOCRLength: Int = 80

    func caption(_ image: CGImage, isScreenshot: Bool = false) async throws -> String {
        let classify = VNClassifyImageRequest()
        let faces = VNDetectFaceRectanglesRequest()
        let animals = VNRecognizeAnimalsRequest()
        let ocr = VNRecognizeTextRequest()
        ocr.recognitionLanguages = ["ko-KR", "en-US"]
        ocr.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([classify, faces, animals, ocr])

        let tags = (classify.results ?? [])
            .filter { $0.confidence >= minConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxTags)
            .map(\.identifier)

        let faceCount = faces.results?.count ?? 0

        let animalNames = (animals.results ?? [])
            .flatMap { $0.labels.map(\.identifier) }
        let animalText: String? = {
            var counts: [String: Int] = [:]
            animalNames.forEach { counts[$0 == "Dog" ? "강아지" : $0 == "Cat" ? "고양이" : $0, default: 0] += 1 }
            guard !counts.isEmpty else { return nil }
            return counts.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        }()

        let ocrText: String? = {
            let joined = (ocr.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
            guard !joined.isEmpty else { return nil }
            return "글자: \"\(String(joined.prefix(maxOCRLength)))\""
        }()

        var parts: [String] = []
        if isScreenshot { parts.append("[화면 캡처]") }
        if !tags.isEmpty { parts.append(tags.joined(separator: ", ")) }
        if faceCount > 0 { parts.append("인물 \(faceCount)명") }
        if let animalText { parts.append(animalText) }
        if let ocrText { parts.append(ocrText) }
        return parts.isEmpty ? "(분석된 장면 정보 없음)" : parts.joined(separator: " · ")
    }
}
