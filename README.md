# 관찰카메라 (The Truman Show 앱)

"나도 몰랐던 내 삶을 누군가 방송 중이다." 하루 데이터(사진·위치)를 자동 수집해
매일 밤 3인칭 방송 내레이션 형식의 에피소드(S01E01…)를 생성하는 iOS 앱.

컨셉·톤·아키텍처 전문은 [`truman-show-kickoff.md`](./truman-show-kickoff.md) 참고.

## 빌드

프로젝트 파일(`.xcodeproj`)은 [XcodeGen](https://github.com/yonaskolb/XcodeGen)이
`project.yml`에서 생성한다 (git에는 커밋하지 않음).

```sh
brew install xcodegen   # 최초 1회
xcodegen generate       # project.yml → TrumanShow.xcodeproj
open TrumanShow.xcodeproj
```

파일을 추가/삭제한 뒤에는 `xcodegen generate`를 다시 실행한다.

- **최소 배포 타깃:** iOS 17.0
- **현재 툴체인:** Xcode 16.4 (iOS 18 SDK)

## 툴체인 참고 — Foundation Models

킥오프의 온디바이스 LLM(`FoundationModels`, 이미지 입력)은 **Xcode 26+ / iOS 26+** 필요.
현재 Xcode 16.4에서는 컴파일 불가. MVP 캡셔닝은 **Vision 프레임워크**(전 기기)로 시작하고,
FoundationModels는 프로토콜 뒤에 격리해 Xcode 26 전환 시 연결한다.

## 진행 상황

- [x] 1. SwiftUI 프로젝트 구조 + SwiftData 모델 (Episode, EpisodeScene, CastMember) — 시뮬레이터 빌드 검증
- [~] 2. PhotoKit 수집 + EXIF 파싱 — 코드 작성 완료(`Services/`), `dayBounds` 로직 검증. **iOS 빌드 검증은 Xcode 재설치 후**
- [ ] 3. 온디바이스 캡셔닝 (Vision, FoundationModels 폴백)
- [x] 4. 에피소드 생성 프롬프트 템플릿 (`Generation/EpisodePrompt.swift`) — CLI 자가 검증 통과 (normal + 방송사고)
- [ ] 5. 에피소드 뷰 UI

> ⚠️ 현재 이 머신에 **Xcode.app이 없다**(CommandLineTools만). iOS 타깃 빌드/시뮬레이터 불가.
> 순수 Foundation 로직(프롬프트 빌더 등)은 `swift` CLI로 검증 가능. Xcode 재설치 후 step 2·3·5 빌드 검증.
