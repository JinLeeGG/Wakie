# Phase 0 실행 계획 — 엔진 코어 (`packages/core`)

| | |
| --- | --- |
| **작성일** | 2026-07-01 |
| **관련** | [PRD.md](PRD.md) §7.2, §7.3, §10, §14, §15 |
| **Phase 0 게이트 (PRD §15)** | 기존 로그인 계정들이 대시보드에 **정확** 표시 · 파서 골든테스트 통과 |

## 현재 상태 (What exists)

- ✅ **UI 껍데기 완성** — 글래스 대시보드, 네이티브 투명/블러 메뉴바 창, 트레이, 골든/스모크 테스트.
- ❌ **엔진 없음** — `packages/core`는 `lib/`·`test/`·`example/` 디렉토리만 있고 파일 0개.
- ❌ **전부 목데이터** — 대시보드는 [`mockAccounts`](../apps/mac/lib/models.dart#L62) 7행을 그대로 렌더링. 실계정/실사용량 0.

> **결론:** UI는 있으나 Phase 0 게이트("실계정 정확 표시")를 아직 하나도 못 넘김. 다음 일 = 엔진 코어 구축 + 실데이터 연결.

## 전략

- **수직 슬라이스 방식.** 한 프로바이더를 감지→스크랩→파싱→대시보드 표시까지 끝까지 뚫고, 같은 인터페이스로 나머지를 확장.
- **Claude 우선.** R0 신호등에서 유일한 🟢(공식 바이너리·토큰 미추출 = §3.7 허용 예외), Appx C에서 가장 검증됨.
- **골든 픽스처가 회귀 방패 (PRD §14, NFR-08).** 스크랩 파서는 실제 pty 캡처 원문을 `packages/core/test/fixtures/`에 고정하고 그걸로 테스트.
- **읽기 먼저, 시작 나중.** 상태 읽기(`readStatus`)가 안정된 뒤에 세션 시작(`startSession`)·절전 기상은 Phase 1로.

## 작업 분해 (WBS)

### S1 — `packages/core` 부트스트랩
- `pubspec.yaml`(순수 Dart 패키지, Flutter 의존 없음), `analysis_options.yaml`.
- 모델: `Account { id, provider, label, configHome, deviceId, addedAt }`, `Status { accountId, sessionPct?, sessionResetAt?, weeklyPct?, weeklyResetAt?, lastStartedAt?, lastOutcome, lastCheckedAt }`, `Preflight`, `RunOutcome`, `ProviderStatus` (PRD §10.1, §10.3).
- 인터페이스: `abstract class ProviderAdapter` — `id`, `envFor`, `detect`, `startSession`, `readStatus` (PRD §10.3).
- **verify:** `dart analyze` 무경고 · 빈 conformance 테스트 스켈레톤 실행 통과.

### S2 — Claude 어댑터: 감지 + 상태 읽기
- `detect(Account)` — `~/.claude`(또는 `CLAUDE_CONFIG_DIR`) 로그인 여부 → `ok / not_installed / not_logged_in / outdated` (PRD §7.5 FR-OB-02).
- `readStatus(Account)` — `claude` pty로 `/usage`(+`/stats`) 스크랩 → 세션·주간 %+리셋 파싱 → `ProviderStatus`(nullable, 실패 시 "알 수 없음"). (FR-PA-01)
- 파서를 순수 함수로 분리(String in → ProviderStatus out)해서 pty 없이 단위 테스트 가능하게.
- **verify:** Appx C의 실제 `/usage` 캡처를 `test/fixtures/claude_usage_*.txt` 골든으로 파싱 통과.

### S3 — 멀티계정 감지 + env 격리 순회
- 기본 홈 스캔으로 로그인된 계정 자동 등록 (FR-RN-01).
- `envFor` — 계정별 `CLAUDE_CONFIG_DIR` 주입 후 CLI 실행, 무개입 순회 (FR-RN-02).
- 로컬 store에 계정별 Status 기록 (FR-RN-07).
- **verify:** env 격리 계약 테스트(계정 A·B가 서로 다른 configHome로 격리) 통과.

### S4 — 대시보드를 실데이터에 연결
- `mockAccounts` → core의 실 Account/Status 스트림으로 교체.
- **Refresh all**(상태만 갱신) 액션을 `readStatus` 순회에 배선 (FR-UI-03).
- 파싱 실패·미로그인 상태를 카드에 행동 가능하게 표시 (FR-ER, `dashboard-error.html`/`dashboard-empty.html` 참고).
- **verify:** 실제 로그인된 Claude 계정이 카드에 정확히 표시(Phase 0 게이트 1차 충족).

### S5 진행 로그 (2026-07-02) — 부분 착수, 스크랩은 후속 과제로 분리

- **성능 최적화 완료** — `captureClaudeUsagePanel` 고정 sleep → **신호 감지 폴링**(프롬프트 준비/패널 렌더 감지 + Enter 재전송 안전장치). 실측 **~20s → 5.0s**. 엔진 `watch()`로 **멀티계정 병렬 + 2단계 로딩**(detect 먼저 카드 표시 → readStatus 병렬 채움). VT 에뮬레이터에 **CHA(`G`)·DECSC/DECRC(ESC 7/8)** 추가(일반적 개선, Claude 골든 유지).
- **⚠️ Codex/Antigravity 스크랩 난이도 = 높음 (실측):**
  - Codex TUI는 **동기화 출력 모드(`?2026`)·대체 화면 버퍼·타이핑 애니메이션** 사용 → 단순 pty 캡처로 `/status` 패널이 안 잡힘(캡처엔 부팅 시퀀스만). 견고 스크랩엔 훨씬 완전한 터미널 에뮬레이터 + 상호작용 모델 필요.
  - `codex login status`("Logged in using ChatGPT")로 **detect는 가능**. 하지만 사용량 패널 스크랩이 미해결.
  - **Antigravity(`agy`)**: 상위 help에 `login/status/auth/usage` 서브커맨드 없음 → detect조차 config 파일 탐색 필요. 사용량도 별도 TUI.
  - **결정:** 각 CLI가 Claude보다 detect·usage 양쪽으로 실질적으로 어려움 → **전용 후속 작업으로 분리**. thin/fragile 코드로 반쪽 출하하지 않음(CLAUDE.md §1·§2). 다음 착수 시: (a) codex 상호작용 모델 파악(/status가 rate limit을 실제 노출하는지 재확인, `codex exec`/앱서버 API 대안 조사) (b) VT에 alt-screen(`?1049`)·동기화출력 처리 추가 (c) agy 자격증명 위치·usage 경로 탐색.

### (후속) Codex · Antigravity 어댑터 확장
- 동일 `ProviderAdapter` 구현. Codex: `CODEX_HOME`/`--profile` + `/status`·`/usage daily` + **최소버전 체크**(0.142.5, PRD §12 버전 스큐). Antigravity: `HOME` 샌드박스 + `/usage` + 첫실행 온보딩 감지. (FR-PA-02/03)
- 각자 골든 픽스처 추가.
- **verify:** 3 프로바이더 conformance 테스트 통과 · 대시보드에 3종 실계정 표시.

- **라이브 GUI 검증 완료 (2026-07-01)** — Flutter macOS 앱 빌드·실행 → 대시보드가 실 Claude 계정을 정확히 표시. 로그 확증: `discovered=1`, `Claude: session=48% left (2:30am) weekly=94% left`. **Phase 0 게이트("실 로그인 계정 정확 표시") 충족.**
  - **⚠️ 중요 발견 (App Sandbox 블로커):** Flutter macOS 앱은 기본 `com.apple.security.app-sandbox=true`. 샌드박스 상태에선 엔진이 `claude`/`script` 프로세스 실행·`~/.claude`/Keychain 접근 불가 → discovery=0(대시보드 "ACCOUNTS 0"). 제품 전제(공식 CLI 구동+Keychain)가 샌드박스와 근본 비호환. **Debug/Release 엔타이틀먼트에서 sandbox=false로 전환**(로컬 DMG MVP). PRD §9.2/§16 정합. **결정 필요(D-SANDBOX):** App Store 배포 시엔 비샌드박스 LaunchAgent 헬퍼로 엔진 분리 필요(Phase 1+).
  - 참고: 엔진 파이프라인 자체는 비샌드박스(터미널)에서 이미 검증됐었음 — 샌드박스는 오직 패키징된 `.app`에만 적용.

## Phase 0 완료 정의 (Definition of Done)

- [x] `packages/core`에 `ProviderAdapter` + 3개 어댑터 구현. (Claude·Codex·Antigravity)
- [x] 스크랩 파서 골든테스트 3종 통과 (PRD §14, M1 ≥ 99%). (claude/codex/antigravity 파서 골든)
- [x] 멀티계정 env 격리 계약 테스트 통과. (CLAUDE_CONFIG_DIR·CODEX_HOME·HOME)
- [x] 대시보드가 목데이터가 아닌 **실 로그인 계정**을 정확 표시. (Claude·Codex GUI 확증; Antigravity는 Engine 배선+CLI 스모크 확증, 패키지드 `.app` GUI 재확인은 후속)
- [x] `dart analyze` / `flutter test` 그린. (core 32 · app 6, 양쪽 analyze 클린)

## 범위 밖 (Phase 1 이후)

세션 시작 UX 플로우(O1/D1 오픈 이슈) · 절전 기상(pmset+LaunchAgent) · 스케줄 · 알림 · 계정 추가 UX · Supabase 릴레이 · iPhone 앱.

## 진행 로그 (2026-07-01)

- **S1 완료** — `packages/core` 부트스트랩. 모델(`Account`/`Status`/`UsageWindow`/`Preflight`/`RunOutcome`) + `ProviderAdapter` 인터페이스. `dart analyze` 클린.
- **S2 완료(Claude)** — `detect()`는 `claude auth status --json`으로 확정(로그인·플랜까지 구조화 반환, pty 불필요). 순수 파서 `parseClaudeUsage` + 실제 `/usage` 캡처 골든 픽스처(`test/fixtures/claude_usage.txt`, 세션 19%/2:30am·주간 2%/Jul 7) 테스트 통과. pty→텍스트 캡처는 주입형 `UsageCapture` seam으로 분리.
- **S3 완료** — 앰비언트 기본 계정 자동감지(`discoverDefaultAccounts`) + env 격리(`envFor`). 실 CLI 스모크로 `claude-default: ok, plan=pro` 확인. 테스트 11개 통과.
  - **⚠️ 중요 발견 (env 격리 모델 교정):** Claude 기본 계정 토큰은 **macOS Keychain(`Claude Code-credentials`)**에 있고 `~/.claude`엔 자격증명 파일이 없음. `CLAUDE_CONFIG_DIR`를 **기본 경로와 동일하게** 세팅해도 파일 기반 네임스페이스로 전환돼 로그인이 `false`로 뜸. → **기본 계정은 env 오버라이드 없이(앰비언트) 실행**해야 하고, 추가 계정만 각자 `CLAUDE_CONFIG_DIR`(자기 `.credentials.json`)로 격리. 이를 `Account.configHome`을 nullable(`null`=앰비언트)로 모델링해 반영. PRD §9.3의 "CLAUDE_CONFIG_DIR 격리" 서술은 이 뉘앙스(기본=Keychain)를 반영해 보정 필요.

- **D-VT 결정됨 → VT 그리드 에뮬레이터 채택 (2026-07-01).** 실측: claude TUI는 커서 위치지정(CUF 등)으로 렌더 → 단순 ANSI 제거 시 글자 붙음/누락으로 파싱 불가. **자체 최소 VT 에뮬레이터(`lib/src/vt.dart`)를 직접 구현**(상대/절대 커서 이동·erase만, SGR/OSC 무시). pty 바이트 → 그리드 텍스트 → 기존 파서. 외부 의존성 0.

- **S4 완료** — pty 캡처(`captureClaudeUsagePanel`, macOS `script`) → VT 렌더 → 파서 파이프라인 라이브 검증(`session=36%, weekly=4%`). Flutter 앱을 `packages/core`에 path 의존 연결. `Engine`(core→UI 매핑: used%→remaining%·tone·리셋 라벨 정리) 추가. 대시보드에 주입형 `loader`(null이면 목데이터→골든 결정성 유지) + Refresh all 재로딩 + 로딩 상태. 앱 테스트 5개 그린(골든 2·위젯 스모크 1·엔진 매핑 2). **부수 수정:** 기존 위젯 스모크 테스트가 폰트 미로드로 이미 깨져 있던 것(footer 오버플로) 폰트 로딩 추가해 복구.
  - **⚠️ VT/그리드 검증 골든:** 실제 raw pty 캡처(`test/fixtures/claude_usage_raw.ansi`)를 VT→파서에 통과시켜 19%/2:30am·2%/Jul 7 확인하는 엔드투엔드 골든 포함.

- **S6 완료(Codex) — TUI 스크랩 없이 app-server JSON-RPC로 전환 (2026-07-02).** S5에서 "높은 난이도"로 막혔던 Codex `/status` TUI 스크랩(동기화출력·alt-screen)을 **완전히 우회**. `codex app-server`(stdio) JSON-RPC에 `initialize` → `account/rateLimits/read` 두 호출이면 **구조화된 rate-limit JSON**을 직접 받음(pty·VT·골든 스크랩 불필요). 실측 응답: `rateLimits.primary`=5h 세션창(`usedPercent`·`windowDurationMins:300`·`resetsAt` epoch)·`secondary`=주간창(`10080`)·`planType`. 라이브 검증: `detect: ok(ChatGPT) · session 99% left · weekly 56% left`(실제 리셋시각).
  - **구현:** 순수 파서 `parseCodexRateLimits`(JSON→`ProviderStatus`) + 라이브 seam `readCodexRateLimits`(app-server 구동, 주입형) + `CodexAdapter`(detect=`codex login status`, `envFor`=`CODEX_HOME`). 골든 픽스처 `test/fixtures/codex_rate_limits.json`. Engine에 Codex 어댑터 배선 → 대시보드 자동 표시. 테스트: core 25 · app 6 그린.
  - **⚠️ 발견:** ① `codex login status`는 로그인 메시지를 **stderr**로 출력(stdout 빈값) → detect가 두 스트림 합쳐 판정. ② **Q4 해결:** Codex `resetsAt`가 epoch 정수라 `UsageWindow`에 nullable `resetAt`(DateTime) 필드 추가(Claude 경로는 `resetLabel` 문자열 그대로 유지). Engine이 세션창→시각·주간창→날짜로 포맷.
  - **Antigravity는 여전히 후속 과제:** `agy`(1.0.14)엔 usage/status/account/app-server/mcp 서브커맨드가 **전무**(모르는 서브커맨드=top-level help). 사용량은 대화형 TUI `/usage`에만 있음 → PRD 🟠 유지. 착수 시: agy TUI 스크랩(alt-screen 처리) 또는 config 파일 탐색으로 detect부터.

- **S7 완료(Antigravity) — 네이티브 pty로 `/usage` TUI 스크랩 (2026-07-02). Phase 0 3어댑터 완성.** 후속 과제였던 Antigravity 착수. 조사 결과: `agy`엔 구조화 usage 표면이 **정말로 없음** — `-p`(print) 모드의 `/usage`는 클라이언트 슬래시커맨드가 아니라 **LLM 프롬프트로 오인식**(usage 가이드 문서를 생성), `bin/agentapi`는 conversation 전용, config/캐시엔 quota 없음. 유일한 구조화 소스는 auth 토큰 재사용이 필요한 서버 API뿐 → **R0 위반이라 배제**. 남은 경로는 TUI `/usage` 스크랩.
  - **⚠️ 핵심 블로커 = pty 크기:** `agy`는 Claude와 달리 **진짜 크기 있는 인터랙티브 터미널**이 아니면 부팅 직후 alt-screen(`?1049h→l`)을 닫고 TUI를 끔. 기존 Claude용 `script`(0×0 pty) 하네스로는 실패. **해결:** `dart:ffi`로 `openpty`(40×120 winsize) 할당 후 **`posix_spawnp`**(+`POSIX_SPAWN_SETSID`)로 `agy` 구동 — Dart VM을 `fork()`하지 않아 멀티스레드 fork 데드락 회피. 정상 렌더 시엔 alt-screen을 안 쓰고 상대커서+erase만 써서 **기존 `vt.dart` 그대로 재사용**(VT 변경 0). **외부 의존성 0**(package:ffi도 안 씀, libSystem 심볼 직접 lookup).
  - **⚠️ FFI 함정 2건(실측 디버깅):** ① **`fcntl`은 가변인자** → arm64에서 고정 시그니처로 선언하면 3번째 인자(O_NONBLOCK)가 유실돼 blocking read로 **영구 hang**. `VarArgs<(Int32,)>`로 선언해 해결. ② `_promptReady`를 배너 "Antigravity CLI"에 매칭하면 **로그인 완료 전**에 `/usage`를 보내 유실 → 실제 준비 신호 "for shortcuts"를 대기하도록 교정.
  - **데이터 모델 매핑:** `agy /usage`는 **2그룹(GEMINI / CLAUDE·GPT) × 2창(Weekly/Five-Hour)** = 4미터. session/weekly 2창 모델엔 창별로 **가장 여유 없는(remaining 최소) 그룹**을 취함 — 잔량을 과대표시하지 않는 정직한 단일 수치. 리셋은 절대시각이 아니라 상대("Refreshes in 4h 25m") → `resetLabel` 문자열로 보존(파서 순수성/골든 결정성 유지).
  - **구현:** 순수 파서 `parseAntigravityUsage`(스크린텍스트→`ProviderStatus`, 최소-잔량 축약) + FFI 캡처 seam `captureAntigravityUsagePanel`(주입형) + `AntigravityAdapter`(detect=`agy --version` + `~/.gemini/oauth_creds.json` **존재만** 확인·토큰 미독취, detail=`google_accounts.json`의 `active` 이메일, `envFor`=`HOME` 샌드박스). 골든 픽스처 `test/fixtures/antigravity_usage.txt`. Engine 배선 → 3어댑터. 테스트: core 32 · app 6 그린.
  - **라이브 검증:** `detect: ok(wakieDemo1@gmail.com) 88ms · readStatus 2.6s · session 2% used(4h 25m) · weekly 1% used(124h 57m)`(=가장 여유 없는 Gemini 그룹). dispose(SIGTERM)로 프로세스 누수 0 확인. TUI 개편 취약성은 스크랩 특성상 불가피(Claude와 동일 리스크).

## 남은 오픈 질문

- **Q3.** 로컬 store 백엔드 — 단순 JSON 파일 vs `sqlite`/`hive`? 인디 규모라 JSON으로 충분해 보임(YAGNI).
- **Q4. (해결됨 2026-07-02)** 리셋을 절대 `DateTime`으로 파싱할지 — Codex가 epoch를 직접 주므로 `UsageWindow.resetAt`(nullable DateTime) 추가로 확정. Claude는 아직 문자열 라벨(`resetLabel`) 유지; 알림(Phase 1) 착수 시 Claude 라벨도 절대시각 파싱 검토.
