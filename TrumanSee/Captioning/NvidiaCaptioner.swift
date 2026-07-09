import Foundation
import CoreGraphics
import UIKit

/// 생생 모드 캡셔너 — 축소된 사진을 NVIDIA Build VLM(Gemma 4)으로 보내 풍부한 한국어 캡션을 받는다.
/// 킥오프의 옵트인 예외: 이 경로에서만 (원본이 아닌) 축소 이미지가 기기 밖으로 나간다.
struct NvidiaCaptioner: PhotoCaptioner {
    let apiKey: String
    var model = "google/gemma-4-31b-it"

    func caption(_ image: CGImage, isScreenshot: Bool = false) async throws -> String {
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.6) else {
            throw NvidiaClient.APIError(message: "jpeg 인코딩 실패")
        }
        let b64 = jpeg.base64EncodedString()
        let prompt = isScreenshot ? """
        이 이미지는 휴대폰/컴퓨터 화면 스크린샷이다. 화면에 무엇이 표시되고 있는지 한국어로 1~2문장으로 설명해줘. \
        (예: 축구 중계 화면, 메신저 대화, 쇼핑 앱 등) 촬영자가 그 장소에 있는 게 아니라 화면을 보고 있는 것이다. \
        맨 앞에 '[화면 캡처]'를 붙여라. 화면 속 인물은 세지 마라.
        """ : """
        이 사진에 보이는 것을 한국어로 1~2문장으로 구체적으로 묘사해줘. \
        장소·음식·사물·분위기 위주로. 추측성 이름이나 감정은 쓰지 말고 보이는 사실만. \
        사람이 있으면 마지막에 '인물 N명'을 덧붙여.
        """
        let messages: [Any] = [[
            "role": "user",
            "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]
            ] as [Any]
        ]]
        return try await NvidiaClient.chat(apiKey: apiKey, model: model, messages: messages,
                                           maxTokens: 200, temperature: 0.2)
    }
}
