import Foundation
import Photos
import CoreLocation
import UIKit

/// 하루치 사진 한 장의 메타데이터. 원본 이미지는 저장하지 않고 asset 식별자만 들고 다닌다.
struct DayPhoto: Identifiable, Equatable {
    var id: String { assetID }
    let assetID: String            // PHAsset.localIdentifier
    let capturedAt: Date
    let coordinate: CLLocationCoordinate2D?

    static func == (lhs: DayPhoto, rhs: DayPhoto) -> Bool { lhs.assetID == rhs.assetID }
}

/// PhotoKit으로 특정 날짜의 사진을 수집한다.
/// 촬영 시각·좌표는 PHAsset이 이미 EXIF에서 뽑아 노출하므로 원본 이미지를 열어 파싱할 필요가 없다.
enum PhotoCollector {

    // MARK: 권한

    static var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// 사진 읽기 권한 요청. (PhotoKit에서 읽기는 .readWrite 레벨을 요구한다 — .addOnly는 쓰기 전용)
    @discardableResult
    static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }
    }

    // MARK: 수집

    /// 특정 날짜(로컬 캘린더 기준)에 촬영된 사진을 시간순으로 수집.
    static func photos(on date: Date, calendar: Calendar = .current) -> [DayPhoto] {
        let bounds = dayBounds(for: date, calendar: calendar)
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                        bounds.start as NSDate, bounds.end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var photos: [DayPhoto] = []
        PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
            guard let created = asset.creationDate else { return }
            photos.append(DayPhoto(assetID: asset.localIdentifier,
                                   capturedAt: created,
                                   coordinate: asset.location?.coordinate))
        }
        return photos
    }

    /// 하루 경계 [자정, 다음날 자정). 순수 로직 — 테스트 대상.
    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    // MARK: 픽셀 로드 (캡셔닝/UI용, 저장 안 함)

    /// asset 식별자로 이미지를 로드. 캡셔닝(Vision)·썸네일 표시에 쓰고 결과는 저장하지 않는다.
    static func image(for assetID: String,
                      targetSize: CGSize = PHImageManagerMaximumSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
        else { return nil }
        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat   // 콜백 1회 보장 (degraded 중간 콜백 없음)
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize,
                                                  contentMode: .aspectFill, options: opts) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}
