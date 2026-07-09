import Foundation

/// NVIDIA Build (OpenAI 호환) 채팅 완성 공용 클라이언트. 캡셔너·내레이터가 공유.
/// 프로덕션은 이 호출을 프록시(무로깅)로 옮긴다.
enum NvidiaClient {
    static let endpoint = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!
    struct APIError: Error { let message: String }

    /// messages는 OpenAI 형식 배열([{role, content}]). content는 문자열 또는 멀티모달 파트 배열.
    static func chat(apiKey: String, model: String, messages: [Any],
                     maxTokens: Int, temperature: Double) async throws -> String {
        let body: [String: Any] = ["model": model, "messages": messages,
                                   "max_tokens": maxTokens, "temperature": temperature]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError(message: "HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw APIError(message: "응답 파싱 실패")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
