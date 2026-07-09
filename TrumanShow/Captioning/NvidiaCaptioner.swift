import Foundation
import CoreGraphics
import UIKit

/// 생생 모드 캡셔너 — 축소된 사진을 NVIDIA Build VLM(Gemma 4)으로 보내 풍부한 한국어 캡션을 받는다.
/// 킥오프의 옵트인 예외: 이 경로에서만 (원본이 아닌) 축소 이미지가 기기 밖으로 나간다.
/// 프로덕션은 키를 프록시로 옮길 것 (현재는 로컬 Secrets 키 직접 호출 = 실험용).
struct NvidiaCaptioner: PhotoCaptioner {
    let apiKey: String
    var model = "google/gemma-4-31b-it"
    var endpoint = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!

    struct CaptionError: Error { let message: String }

    func caption(_ image: CGImage) async throws -> String {
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.6) else {
            throw CaptionError(message: "jpeg 인코딩 실패")
        }
        let b64 = jpeg.base64EncodedString()
        let prompt = """
        이 사진에 보이는 것을 한국어로 1~2문장으로 구체적으로 묘사해줘. \
        장소·음식·사물·분위기 위주로. 추측성 이름이나 감정은 쓰지 말고 보이는 사실만. \
        사람이 있으면 마지막에 '인물 N명'을 덧붙여.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
                ] as [Any]
            ]],
            "max_tokens": 200,
            "temperature": 0.2
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CaptionError(message: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw CaptionError(message: "응답 파싱 실패")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
