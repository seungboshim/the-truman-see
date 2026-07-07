import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.airDate, order: .reverse) private var episodes: [Episode]
    @AppStorage("protagonistName") private var protagonistName = "주인공"
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if episodes.isEmpty {
                    ContentUnavailableView {
                        Label("아직 방송 전", systemImage: "tv")
                    } description: {
                        Text("제작진이 첫 에피소드를 준비하고 있습니다.\n오늘 하루가 끝나면 방송을 시작합니다.")
                    } actions: {
                        generateButton
                    }
                } else {
                    List {
                        ForEach(episodes) { episode in
                            NavigationLink(value: episode.id) {
                                row(episode)
                            }
                        }
                    }
                }
            }
            .navigationTitle("관찰카메라")
            .navigationDestination(for: UUID.self) { id in
                if let episode = episodes.first(where: { $0.id == id }) {
                    EpisodeView(episode: episode)
                }
            }
            .toolbar {
                if !episodes.isEmpty {
                    ToolbarItem(placement: .primaryAction) { generateButton }
                }
            }
            .alert("방송 사고", isPresented: .constant(errorMessage != nil)) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func row(_ episode: Episode) -> some View {
        HStack(spacing: 12) {
            if let assetID = episode.orderedScenes.first(where: { $0.photoAssetID != nil })?.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "tv").foregroundStyle(.secondary))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(episode.title).font(.headline).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            if isGenerating {
                ProgressView()
            } else {
                Label("오늘 방송 만들기", systemImage: "record.circle")
            }
        }
        .disabled(isGenerating)
    }

    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let status = await PhotoCollector.requestAuthorization()
            guard status == .authorized || status == .limited else {
                errorMessage = "카메라(사진첩) 접근이 없어 촬영분을 확보하지 못했습니다. 설정에서 사진 권한을 허용해 주세요. — 제작진"
                return
            }
            guard FMNarrator.isAvailable else {
                errorMessage = "이 기기에서는 온디바이스 작가(Apple Intelligence)를 사용할 수 없습니다. 클라우드 작가는 곧 합류합니다. — 제작진"
                return
            }
            try await EpisodeComposer.compose(protagonist: protagonistName,
                                              narrator: FMNarrator(),
                                              context: modelContext)
        } catch {
            errorMessage = "편집실에서 문제가 발생했습니다: \(error.localizedDescription) — 제작진"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self, EpisodeScene.self, CastMember.self], inMemory: true)
}
