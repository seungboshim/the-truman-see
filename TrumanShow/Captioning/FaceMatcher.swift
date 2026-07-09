import Foundation
import CoreGraphics
import Vision

/// 주인공 얼굴 매칭. 셀카 1장을 레퍼런스로 등록하고, 사진 속 얼굴들과 feature print 거리 비교.
/// Vision엔 얼굴 식별 API가 없어 얼굴 크롭 + VNGenerateImageFeaturePrintRequest로 근사.
/// 오탐은 세계관으로 소화한다 ("제작진이 주인공을 잘못 알아봤다").
enum FaceMatcher {
    private static let referenceKey = "protagonistFacePrint"
    /// ponytail: 초기 임계값. [Face] distance 로그 보고 실측 튜닝
    static var threshold: Float = 0.75

    static var hasReference: Bool {
        UserDefaults.standard.data(forKey: referenceKey) != nil
    }

    /// 셀카에서 가장 큰 얼굴을 레퍼런스로 등록. 얼굴 없으면 false.
    @discardableResult
    static func registerReference(from image: CGImage) -> Bool {
        guard let fp = facePrints(in: image, largestOnly: true).first,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: fp, requiringSecureCoding: true)
        else { return false }
        UserDefaults.standard.set(data, forKey: referenceKey)
        return true
    }

    /// 사진 속 얼굴 중 주인공이 있는지. 레퍼런스 없으면 false (= 카메라 뒤 가정 유지).
    static func containsProtagonist(_ image: CGImage) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: referenceKey),
              let ref = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self, from: data)
        else { return false }
        for fp in facePrints(in: image, largestOnly: false) {
            var distance: Float = .infinity
            try? fp.computeDistance(&distance, to: ref)
            DebugLog.log("[Face] distance \(distance) (threshold \(threshold))")
            if distance < threshold { return true }
        }
        return false
    }

    // MARK: - 내부

    /// 얼굴 감지 → 여백 30% 크롭 → feature print
    private static func facePrints(in image: CGImage, largestOnly: Bool) -> [VNFeaturePrintObservation] {
        let detect = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: image).perform([detect])
        var faces = detect.results ?? []
        if largestOnly {
            faces = faces.sorted {
                $0.boundingBox.width * $0.boundingBox.height >
                $1.boundingBox.width * $1.boundingBox.height
            }.prefix(1).map { $0 }
        }
        return faces.compactMap { face in
            guard let crop = cropFace(image, normalizedRect: face.boundingBox) else { return nil }
            let request = VNGenerateImageFeaturePrintRequest()
            try? VNImageRequestHandler(cgImage: crop).perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        }
    }

    private static func cropFace(_ image: CGImage, normalizedRect: CGRect) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        // Vision 좌표(좌하단 원점) → CG 좌표(좌상단 원점), 여백 30%
        let margin: CGFloat = 0.3
        var rect = CGRect(x: normalizedRect.minX * w,
                          y: (1 - normalizedRect.maxY) * h,
                          width: normalizedRect.width * w,
                          height: normalizedRect.height * h)
        rect = rect.insetBy(dx: -rect.width * margin, dy: -rect.height * margin)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        return image.cropping(to: rect)
    }
}
