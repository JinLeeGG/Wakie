<div align="center">

<img width="1050" height="350" alt="Wakie" src="https://github.com/user-attachments/assets/3db2f5a5-e24b-4f9a-9a69-c61be22bddba" />

<br>

<h4>
  여러 AI 구독을 위한 로컬 사용량 트래킹,<br>
  그리고 수면 중에도 리셋 윈도우를 최적화해 주는 자동화 봇.
</h4>

<br>

[🇺🇸 English](README.md) &nbsp;·&nbsp; 🇰🇷 한국어

<br>

![macOS](https://img.shields.io/badge/macOS-1c2029?style=flat&logo=apple&logoColor=white)
&nbsp;[![License](https://img.shields.io/badge/AGPL--3.0-1c2029?style=flat&logo=gnu&logoColor=white)](LICENSE)
&nbsp;![free forever](https://img.shields.io/badge/free_forever-1c2029?style=flat)

<br>
<br>

[![Download for macOS](https://img.shields.io/badge/Download%20for%20macOS-FFC465?style=for-the-badge&logo=apple&logoColor=11131a)](https://github.com/JinLeeGG/Wakie/releases/latest)

<sub>서명·공증 완료 · 계정 불필요 · 오프라인 동작</sub>

</div>

<br>

## 🎥 데모

<div align="center">
  <video src="https://github.com/user-attachments/assets/1e53bf83-62b1-465a-8b42-5d5fb23c60d8" width="100%" autoplay loop muted playsinline></video>
</div>

<br>

## 📖 왜 만들었냐면

> **한 줄 요약** — Wakie는 Claude의 5시간 리셋 윈도우를 알아서 굴려주고, 돈 내고 쓰는 AI 구독들을 얼마나 갈아넣고 있는지도 추적해준다. 100% 로컬. 계정도, 서버도, 텔레메트리도 없음.

모든 AI 코딩 구독에는 똑같은 함정이 있다: 첫 메시지를 보내는 순간 시작되는 5시간짜리 롤링 윈도우. 오전 10시에 각 잡고 코딩을 시작하면 윈도우가 10시에 박히고, 오후 3시에나 리셋된다. 그리고 꼭 오후 2시 40분쯤 제일 빡센 로직을 풀고 있는 한가운데에서 한도에 걸린다. 리셋 타이머만 쳐다보고 앉아있는 동안 머릿속 코드 흐름은 싹 다 증발한다.

첫 번째 해결책은 무식했다: 그냥 계정을 여러 개 파는 거다. Claude Pro 2개, Codex Plus 1개 — 쌩돈을 내기 싫은 가난한 자의 Max 요금제다. 근데 이번엔 어느 계정에 잔여량이 남았는지 확인하려고 하루 종일 로그인만 뺑뺑이 돌고 있었다.

그래서 꼼수를 쓰기 시작했다. 매일 아침 커피도 마시기 전에 터미널에 `good morning`을 친다. 버리는 메시지 한 방으로 윈도우를 일찍 고정시켜서, 진짜 일할 때는 리셋이 빗겨가게 만드는 거다. 하지만 매일 아침 6시 45분마다 로봇한테 굿모닝 쳐주는 이 멍청한 수작업이야말로 내가 코딩 배운 이유(= 이런 거 안 하려고)랑 정면으로 배치된다. 그래서 대신 해주는 봇을 짰다: 맥을 깨우고, 인사하고, 윈도우 리셋시키고, 다시 재운다. 이름이 여기서 나왔다. Wakie.

그러다 선을 넘었다. Claude, Codex, Antigravity를 동시에 굴리면서 내가 얼마나 쓰고 있는지도 모른 채 진짜 쌩돈을 태우고 있었다 — 대시보드도 없이 그냥 '느낌'으로 쓰다가 갑자기 "한도 초과" 싸대기 맞는 게 일상이었다. 그래서 깨우기 봇에다 사용량 트래킹을 냅다 볼트 체결해버렸다. 그다음 리셋 타이머. 그다음 모든 계정과 윈도우를 한눈에 보여주는 메뉴바 리드아웃.

그게 전부다. 거창한 로드맵 덱 없고, 미션 선언문 없고, "개발자 생산성의 재정의" 같은 개소리도 없다. 그냥 빡쳤고, 주말이 있었고, 그래서 이게 생겼다.

<br>

## 🔒 데이터는 네 맥을 절대 안 떠난다

솔직히 말할게. 내가 안 만들었으면 나도 이 앱 안 깐다.

얘가 뭘 하는지 한번 보자. 네 로컬 AI 로그를 읽는다 — 프롬프트 횟수, 리셋 타임스탬프, 어떤 계정으로 로그인돼 있는지. 이건 딱 수상한 클로즈드 소스 메뉴바 앱이 몰래 쓸어담아서 어디 분석 서버로 쏴버릴 법한 종류의 데이터다. 정체불명 바이너리가 이거 하겠다고 하면 나 같아도 거절이다. 그게 맞고.

그래서 이렇게 만들었다. Wakie는 백엔드가 없다. 서버 자체가 없다. 텔레메트리 없고, 애널리틱스 없고, "익명 사용 통계" 이딴 것도 없고, 서명된 업데이트 확인 말고는 밖으로 나가는 게 아무것도 없다. 디스크에 있는 파일 읽어서, 로컬에서 계산하고, 메뉴바에 숫자 하나 그린다. 이게 전부다. 네트워크 꺼도 추적 기능은 똑같이 돌아간다.

솔직하게 예외 하나는 미리 깔아둘게 — 나중에 발견하는 것보다 내가 먼저 말하는 게 나으니까. 깨우기 봇은 정해진 시간에 **CLI를 통해 버리는 프롬프트 하나를 실제로 쏜다.** 세션 깨우는 게 목적이니 당연한 거고, 그래 토큰 몇 개 나가고. 근데 이게 Wakie가 유발하는 유일한 네트워크 호출이야. 그것도 네 컴퓨터에서 네 계정으로 네 provider한테 가는 거지, 나한테 오는 게 아니고. 애초에 받을 "나"라는 서버가 없다.

그리고 내 말을 믿을 필요도 없어 — 그러라고 AGPL로 오픈소스 한 거니까. `grep`도 말고, `lsof` 한번 걸어보면 그냥 나온다. Little Snitch(또는 `nettop -p wakie`) 걸어보면 앱이 자기 스스로 여는 아웃바운드 연결은 0개인 게 보이고, 잡히는 트래픽은 어차피 내가 이미 돌리고 있는 CLI들 거다. 코드 직접 읽고 싶으면 그것도 다 저기 있고. 혹시라도 얘가 열면 안 되는 소켓 여는 거 잡으면, 내 이름 걸고 이슈 열어줘.

<br>

## 지원하는 AI 툴

| 툴 | Wakie가 읽는 곳 | 상태 |
|----|----------------|------|
| **Claude Code** | 로컬 `/usage` 패널 + 세션 로그 | ✅ 동작 |
| **Codex** | `codex app-server` JSON-RPC (스크래핑 없이 구조화된 데이터) | ✅ 동작 |
| **Antigravity** | 네이티브 pty로 TUI 스크랩 (아직 구조화된 출구가 없어서) | ✅ 동작 |

각 툴은 [`packages/core/lib/src/adapters`](packages/core/lib/src/adapters) 안에 독립된 어댑터로 들어있다. 목록에 없는 툴 쓰면 저 폴더가 추가할 자리다 — 제일 비슷한 거 하나 복붙해서 손보면 된다. 보기보다 안 무섭다.

<br>

## 기술 스택

- **Flutter + Dart** — 앱이랑 추적 엔진 전체 (`packages/core`)
- **Swift** — 네이티브 macOS 부분: 메뉴바 트레이, 윈도우 처리, 예약된 절전-깨우기
- **Sparkle** — 서명된 자동 업데이트. DMG 평생 다시 받는 짓 안 해도 됨
- **Next.js 16 · React 19 · Tailwind v4 · TypeScript** — `apps/web`에 있는 랜딩 사이트
- **Developer ID 서명 + Apple 공증**된 DMG로 배포해서 Gatekeeper가 안 물고 늘어진다

<br>

## 설치

**빠른 방법 (curl):**

```bash
curl -fsSL https://raw.githubusercontent.com/JinLeeGG/Wakie/main/deploy/install.sh | bash
```

그래, `curl | bash` 인 거 안다. 이거 보고 움찔했으면 좋은 감이야. [스크립트 먼저 읽어봐도 돼](deploy/install.sh) — 30줄쯤 되고, 하는 일은 공증된 DMG 받아서 앱을 `/Applications`에 넣는 게 전부다.

**의심 많은 방법:** [Releases](https://github.com/JinLeeGG/Wakie/releases)에서 DMG 받아서 열고, Wakie를 Applications로 드래그. 서명·공증 돼있어서 우클릭-열기 삽질 안 해도 된다.

**소스에서 빌드:**

```bash
git clone https://github.com/JinLeeGG/Wakie.git
cd Wakie/apps/mac
flutter pub get
flutter run -d macos
```

Flutter (Dart SDK 3.12+)랑 Xcode 필요하다. 아직은 macOS 전용.

<br>

## 기여

PR 진심으로 환영한다.

**네가 쓰는 AI 툴을 Wakie가 추적하게 하고 싶어?** 어댑터는 딱 세 가지야:

1. `ProviderAdapter` 인터페이스 구현.
2. `Provider` enum 값 추가.
3. [`packages/core/lib/src/production_adapters.dart`](packages/core/lib/src/production_adapters.dart)에 등록.

이게 계약의 전부야. 모든 provider는 `*_adapter_test.dart` + `*_usage_parser_test.dart` 쌍을 갖고 있으니 — 그 쌍을 복사하고, 네 툴에서 뜬 실제 캡처를 넣고, `cd packages/core && flutter test`로 TDD 돌리면 된다. Xcode도, 앱 빌드도, Mac 앱 지식도 필요 없다.

그 외에 손 보태주면 좋은 거:

- **재현 스텝 있는 버그 리포트.** "안 돼요"는 날 슬프게 하고, "이렇게 했더니 이렇게 됨"은 날 고치게 만든다.
- **맨날 시작한다고 하고 안 하는 Windows/Linux 포팅.**

CLA 없고, 봇 관문 없고, 12칸짜리 이슈 템플릿 없다. 이슈 열고, PR 보내고, 사람답게 얘기해서 풀면 된다.

<br>

---

<div align="center">

**라이선스:** [AGPL-3.0](LICENSE) — 포크하고, 위에 쌓아 올리고, 열려있게만 유지해라.
Copyright © 2026 Gyujin Lee.

로봇한테 아침 6시에 "굿모닝" 치는 게 지겨워져서 만듦.

</div>
