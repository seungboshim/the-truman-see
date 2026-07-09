import Foundation

/// 파일 로그 — devicectl 콘솔이 붙어있지 않아도 사후 수거 가능.
/// 수거: xcrun devicectl device copy from --domain-type appDataContainer ... Documents/composer.log
enum DebugLog {
    static let url = URL.documentsDirectory.appendingPathComponent("composer.log")

    static func log(_ msg: String) {
        print(msg)
        let stamp = Date().formatted(date: .omitted, time: .standard)
        let line = "\(stamp) \(msg)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
