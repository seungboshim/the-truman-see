import SwiftUI
import Photos

/// 온보딩: 캐스팅(이름) → 카메라 계약(사진 권한 프리퍼미션) → 방송 시작.
/// 시스템 팝업 전 커스텀 프리퍼미션 화면에만 PD 톤 카피 사용 (Info.plist는 건조체).
struct OnboardingView: View {
    @AppStorage("protagonistName") private var protagonistName = ""
    @AppStorage("onboarded") private var onboarded = false
    @State private var step: Step = .casting
    @FocusState private var nameFocused: Bool

    enum Step { case casting, cameraContract }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Group {
                switch step {
                case .casting: casting
                case .cameraContract: cameraContract
                }
            }
            .transition(.push(from: .trailing))
            Spacer()
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .padding(28)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: 1. 캐스팅

    private var casting: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("캐스팅 확정 📋")
                .font(.largeTitle.bold())
            Text("""
            축하드립니다. 당신이 이번 시즌의 주인공으로 캐스팅됐습니다.
            방송은 이미 시작됐고, 당신만 모르고 있었습니다.

            크레딧에 올릴 이름을 알려주세요.
            """)
            .foregroundStyle(.secondary)

            TextField("주인공 이름", text: $protagonistName)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onAppear { nameFocused = true }

            Button {
                step = .cameraContract
            } label: {
                Text("계약서에 서명").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(protagonistName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .foregroundStyle(.white)
    }

    // MARK: 2. 카메라 계약 (사진 프리퍼미션)

    private var cameraContract: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("제작진 요청 📋")
                .font(.largeTitle.bold())
            Text("""
            \(protagonistName) 님, 촬영을 시작하려면 카메라(사진첩)가 필요합니다.

            사진 원본은 기기 밖으로 나가지 않습니다.
            제작진은 기기 안에서 분석된 텍스트만 봅니다.
            에피소드마다 '제작진이 본 것'에서 전부 확인할 수 있습니다.

            — 담당 PD 드림
            """)
            .foregroundStyle(.secondary)

            Button {
                Task {
                    // 거절해도 진행 — 결측은 방송사고 에피소드로 소화 (권한 거절 대응)
                    await PhotoCollector.requestAuthorization()
                    await NotificationScheduler.scheduleNightly()
                    onboarded = true
                }
            } label: {
                Text("카메라 켜기").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("나중에 (오늘은 촬영 없이)") {
                Task {
                    await NotificationScheduler.scheduleNightly()
                    onboarded = true
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
    }
}

#Preview { OnboardingView() }
