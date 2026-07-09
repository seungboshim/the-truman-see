import SwiftUI
import Photos

/// 에피소드 상세 — TV 프로그램 스타일.
struct EpisodeView: View {
    let episode: Episode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                scenes
                if !episode.viewerComments.isEmpty { comments }
                if let report = episode.productionReport { productionReport(report) }
                transparency
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationTitle(episode.code)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(episode.code)
                    .font(.caption.monospaced().bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.red, in: RoundedRectangle(cornerRadius: 4))
                if episode.isBroadcastAccident {
                    Text("방송 사고")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.yellow.opacity(0.9), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.black)
                }
                Spacer()
                Label(String(format: "%.1f%%", episode.viewerRating), systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text(episode.title).font(.title2.bold())
            if let synopsis = episode.synopsis {
                Text(synopsis).font(.subheadline).foregroundStyle(.secondary).italic()
            }
        }
        .foregroundStyle(.white)
    }

    private var scenes: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(episode.orderedScenes) { scene in
                VStack(alignment: .leading, spacing: 8) {
                    if let assetID = scene.photoAssetID {
                        PhotoThumbnail(assetID: assetID)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    HStack(spacing: 6) {
                        if let t = scene.capturedAt {
                            Text(EpisodeComposer.timeText(t))
                        }
                        if let loc = scene.locationName { Text("· \(loc)") }
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    Text(scene.narration)
                        .font(.body)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var comments: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("시청자 댓글").font(.headline).foregroundStyle(.white)
            ForEach(episode.viewerComments, id: \.self) { comment in
                Text(comment)
                    .font(.subheadline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private func productionReport(_ report: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제작 리포트").font(.headline).foregroundStyle(.white)
            Text(report).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// "제작진이 본 것" — 이번 에피소드 생성에 실제 사용된 텍스트 전문 공개.
    private var transparency: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(episode.orderedScenes.filter { $0.observedText != nil }) { scene in
                    Text(scene.observedText!)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text("사진 원본은 기기 밖으로 나가지 않습니다. 제작진(AI)은 위 텍스트만 봤습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        } label: {
            Label("제작진이 본 것", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .tint(.white)
    }
}

/// PHAsset 썸네일 로더.
struct PhotoThumbnail: View {
    let assetID: String
    @State private var image: UIImage?

    var body: some View {
        // overlay 패턴: 이미지의 고유 크기가 레이아웃에 관여하지 못하게 격리
        // (scaledToFill 이미지가 ScrollView 콘텐츠 폭을 밀어내는 오버플로 방지)
        Color.clear
            .background(.white.opacity(0.06))
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: assetID) {
                image = await PhotoCollector.image(for: assetID,
                                                   targetSize: .init(width: 800, height: 800))
            }
    }
}
