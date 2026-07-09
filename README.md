# 트루먼씨 (TrumanSee)

"나도 몰랐던 내 삶을 누군가 방송 중이다." 하루 데이터(사진·위치)를 자동 수집해
매일 밤 3인칭 방송 내레이션 형식의 에피소드(S01E01…)를 생성하는 iOS 앱.
사용자는 밤에 알림을 받고 에피소드를 '시청'만 한다 — 입력 UI 없는 관찰 예능.

컨셉·톤·아키텍처 전문은 [`truman-show-kickoff.md`](./truman-show-kickoff.md) 참고.

## 빌드

프로젝트 파일(`.xcodeproj`)은 [XcodeGen](https://github.com/yonaskolb/XcodeGen)이
`project.yml`에서 생성한다 (git 미커밋).

```sh
brew install xcodegen   # 최초 1회
xcodegen generate       # project.yml → TrumanSee.xcodeproj
open TrumanSee.xcodeproj
```

파일을 추가/삭제한 뒤에는 `xcodegen generate`를 다시 실행한다.

- **최소 배포 타깃:** iOS 17.0 / **툴체인:** Xcode 26.6 (iOS 26.5 SDK)
- **번들 ID:** com.seungboshim.trumansee · 표시명 "트루먼씨"

`TrumanSee/Secrets.swift`(gitignore)에 NVIDIA 키를 넣어야 생생 모드가 빌드된다.
없어도 온디바이스 모드는 동작.

## 아키텍처 요약

- **캡셔닝** (`Captioning/`): `PhotoCaptioner` 프로토콜 → `VisionCaptioner`(온디바이스, 기본)
  / `NvidiaCaptioner`(생생 모드 옵트인, Gemma 4 VLM). 얼굴 매칭은 휴면(v2 얼굴 임베딩 대기).
- **내레이션** (`Generation/`): `EpisodePrompt`(세계관/톤 튜닝 지점) → `FMNarrator`(온디바이스
  FoundationModels) → `EpisodeDraft`(관대 JSON 파서).
- **파이프라인** (`Services/EpisodeComposer`): 사진 수집 → 캡셔닝 → 역지오코딩 → 프롬프트 → 내레이터 → SwiftData.
- **저장**: SwiftData 로컬 전용 (`Models/`: Episode, EpisodeScene, CastMember). 서버·계정 없음.

## 진행 상황

MVP(온보딩·수집·캡셔닝·내레이션·에피소드 뷰·알림) 실기기 동작 확인.
- 온디바이스 FM 내레이션 + Vision/생생 모드 캡셔닝 토글
- 스크린샷 인식, 방송사고(결측일) 에피소드, "제작진이 본 것" 투명성 화면

다음(v2): 밤 자동 생성(BGAppRefreshTask), 클라우드 내레이션 프록시(Cloudflare Workers),
얼굴 임베딩 기반 인물 인식, 공유 카드.
