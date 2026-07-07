import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Episode.airDate, order: .reverse) private var episodes: [Episode]

    var body: some View {
        NavigationStack {
            Group {
                if episodes.isEmpty {
                    ContentUnavailableView {
                        Label("아직 방송 전", systemImage: "tv")
                    } description: {
                        Text("제작진이 첫 에피소드를 준비하고 있습니다.\n오늘 하루가 끝나면 방송을 시작합니다.")
                    }
                } else {
                    List(episodes) { episode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.code)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(episode.title).font(.headline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("관찰카메라")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self, EpisodeScene.self, CastMember.self], inMemory: true)
}
