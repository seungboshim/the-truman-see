import SwiftUI
import Photos
import PhotosUI

/// 온보딩: 캐스팅(이름) → 프로필 촬영(셀카, 스킵 가능) → 카메라 계약(사진 권한 프리퍼미션).
/// 시스템 팝업 전 커스텀 프리퍼미션 화면에만 PD 톤 카피 사용 (Info.plist는 건조체).
struct OnboardingView: View {
    @AppStorage("protagonistName") private var protagonistName = ""
    @AppStorage("onboarded") private var onboarded = false
    @State private var step: Step = .casting
    @State private var selfieItem: PhotosPickerItem?
    @State private var selfieError: String?
    @FocusState private var nameFocused: Bool

    enum Step { case casting, selfie, cameraContract, splash }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Group {
                switch step {
                case .casting: casting
                case .selfie: selfie
                case .cameraContract: cameraContract
                case .splash: splash
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
            축하드립니다. 당신은 이제부터 '트루먼씨'입니다.
            이번 시즌의 주인공으로 캐스팅됐고,
            방송은 이미 시작됐고, 당신만 모르고 있었습니다.

            크레딧에 올릴 이름을 알려주세요.
            """)
            .foregroundStyle(.secondary)

            TextField("주인공 이름", text: $protagonistName)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onAppear { nameFocused = true }

            Button {
                step = .selfie
            } label: {
                Text("계약서에 서명").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(protagonistName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .foregroundStyle(.white)
    }

    // MARK: 2. 프로필 촬영 (셀카 등록, 스킵 가능)

    private var selfie: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("프로필 촬영 📸")
                .font(.largeTitle.bold())
            Text("""
            제작진이 화면 속에서 주인공을 알아볼 수 있도록,
            얼굴이 잘 나온 사진 한 장을 등록해 주세요.

            사진과 얼굴 정보는 기기 밖으로 나가지 않습니다.
            건너뛰면 '주인공은 늘 카메라 뒤'라는 설정으로 진행합니다.
            """)
            .foregroundStyle(.secondary)

            if let selfieError {
                Text(selfieError).font(.footnote).foregroundStyle(.orange)
            }

            PhotosPicker(selection: $selfieItem, matching: .images) {
                Text("사진 고르기").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("건너뛰기 (주인공은 늘 카메라 뒤)") {
                step = .cameraContract
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .onChange(of: selfieItem) { _, item in
            guard let item else { return }
            Task {
                // UIImage 재드로잉으로 EXIF 회전 정규화 (회전된 셀카에서 얼굴 감지 실패 방지)
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data),
                   let cg = normalized(ui),
                   FaceMatcher.registerReference(from: cg) {
                    step = .cameraContract
                } else {
                    selfieError = "제작진 메모: 이 사진에서는 얼굴을 찾지 못했습니다. 다른 사진으로 부탁드려요."
                    selfieItem = nil
                }
            }
        }
    }

    private func normalized(_ ui: UIImage) -> CGImage? {
        UIGraphicsImageRenderer(size: ui.size).image { _ in ui.draw(at: .zero) }.cgImage
    }

    // MARK: 3. 카메라 계약 (사진 프리퍼미션)

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
                    step = .splash
                }
            } label: {
                Text("카메라 켜기").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("나중에 (오늘은 촬영 없이)") {
                Task {
                    await NotificationScheduler.scheduleNightly()
                    step = .splash
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
    }

    // MARK: 4. 방송 시작 스플래시 (트루먼쇼 명대사)

    private var splash: some View {
        VStack(spacing: 20) {
            Text("🎬")
                .font(.system(size: 60))
            Text("이제부터\n\(protagonistName)님의 삶은\n드라마가 됩니다.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("굿모닝.\n그리고 혹시 못 볼까 봐 미리 —\n굿애프터눈, 굿나잇.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onboarded = true
            } label: {
                Text("방송 시작").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
        .foregroundStyle(.white)
    }
}

#Preview { OnboardingView() }
