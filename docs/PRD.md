# Wakie — Product Requirements Document (PRD)

| | |
| --- | --- |
| **Status** | Draft v1.4 (production, engineering-focused) |
| **Owner** | John (wakieDemo1@gmail.com) |
| **Last updated** | 2026-07-02 |
| **Audience** | Engineering 실행 중심 · 인디/개인 제품 · 소규모 시작→성장 대비 |
| **Related** | [CLAUDE.md](../CLAUDE.md) |

### Changelog
- **v1.4 (2026-07-02)** — 계획 리뷰 반영. **D1 확정:** 세션 시작 = 리셋 시각 자동 체이닝(token maxxing), Update/Refresh = 읽기 전용, 절전 기상 = 다음 리셋들+아침 앵커(§6·§7·§15). **D-SANDBOX 확정:** 앱스토어 불가 → Developer ID DMG(§16). **O2 확정:** 사용 80%·리셋 10분 전(§7.4). 어댑터 서술을 실구현으로 정정(Codex=app-server JSON-RPC, agy=네이티브 pty, 기본 계정=Keychain 앰비언트). FR-OB-01(소셜 로그인)→Phase 2. §15에 Phase 1 실행 순서 추가.
- **v1.3 (2026-07-01)** — ToS/약관 리스크를 §17 **R0(최우선)**로 격상: 프로바이더별 신호등(Claude🟢/Codex🟡/agy🟠), "공식 바이너리·토큰 미추출" 아키텍처 불변식, 포지셔닝·빈도·kill-switch 완화책, 근거 출처.
- **v1.2 (2026-07-01)** — 브랜드/디자인 확정: 이름 **Wakie**, 오빗 로고(네이비+앰버), 다크 글래스 대시보드, Update/Refresh 액션 정의(§9.4).
- **v1.1 (2026-07-01)** — 결정 패스 반영: 가치 재정의(멀티계정 효율 오케스트레이션), 멀티계정=핵심 단위(4↓3종 검증), Mac 메뉴바 앱 우선(폰 Phase 2), 절전 기상 MVP, Supabase 릴레이(Phase 2), 알림 전략.
- v1.0 — production 재작성(요구사항 ID·수용기준·데이터모델·보안·테스트).
- v0.x — 검증·프로바이더 매트릭스·피벗.

---

## 0. TL;DR

AI 파워유저는 월 $200 최고 티어 하나 대신, **여러 개의 더 저렴한 구독/계정**으로 더 많은 사용량을 확보한다. 문제는 그걸 **효율적으로 굴리기가 번거롭다**는 것 — 어느 계정이 남았는지, 언제 창이 리셋되는지, 언제 갈아타야 하는지 매번 확인해야 한다.

**Wakie = 멀티계정 AI 사용량 효율 오케스트레이터.** Mac에서 도는 앱이 로그인된 여러 AI CLI(Claude/Codex/Antigravity)를 **백그라운드로 순회**하며 각 계정의 사용량/리셋을 읽어 **통합 대시보드**로 보여주고, **절전 상태에서 깨어나** 세션을 시작하며, **언제 무엇을 쓸지 알림**으로 알려준다.

- **핵심 가치:** ① 여러 계정의 사용량/리셋 통합 관제 ② 절전에서도 세션 준비 ③ "지금 뭘 써야 하나" 알림 → **한 티어 값으로 여러 구독을 최대로.**
- **검증됨(2026-07-01):** 세션 시작·상태 스크랩·멀티계정 자동 전환·절전 기상 전부 실증(§Appx C).
- **패키징:** Mac **메뉴바 앱**(엔진 내장) + iPhone 앱. "앱 2개 깔면 끝."
- **순서:** **Phase 0-1 = Mac 앱 단독**(로컬, 클라우드/폰 없음) → **Phase 2 = Supabase 릴레이 + iPhone.**
- **스택:** Flutter(폰 + Mac 데스크톱) + 공유 Dart core + Supabase.

---

## 1. 문제 정의 & 배경

구독제 AI(Claude Pro/Max, ChatGPT/Codex, Antigravity)는 **롤링 세션 윈도우**(예: 5시간 한도 + 주간 한도)로 사용량을 관리한다. 파워유저는 **여러 계정**을 병행해 비용 대비 사용량을 극대화하려 하지만:

1. **어느 계정이 얼마 남았는지** 각 CLI/웹을 일일이 열어봐야 안다.
2. **언제 갈아타야** 효율적인지(한 계정 소진 → 다른 계정)를 수동 판단.
3. **PC 상시 가동 부담** — 정해진 시각 세션 준비를 자동화하려면 컴퓨터를 켜둬야 함.
4. **세션 타이밍 수동** — 업무 시작에 맞춰 세션을 미리 열려면 직접 프롬프트.

**핵심 통찰(검증됨):** 주요 구독 AI의 **공식 CLI**는 (a) 구독 로그인 (b) 헤드리스 세션 시작(`-p`/`exec`) (c) `/usage`류 사용량/리셋 조회 (d) **계정별 config 홈 격리**를 지원한다. Mac에서 이 CLI들을 백그라운드로 굴리면 위 문제를 해결한다.

> **문제 검증:** 현재 근거는 오너(설계 파트너)의 직접 니즈. 초기 사용자 인터뷰로 "멀티계정 효율" 페인을 확증하는 것을 권장(가정, §17).

---

## 2. 목표 · 비목표 · 성공 지표

### 2.1 목표
- G1. 여러 계정의 세션/주간 사용량 % + 리셋을 **통합 대시보드**로 관제.
- G2. 데스크톱이 **절전 중이어도** 예약/온디맨드로 세션 시작.
- G3. "지금 어느 계정을 쓸지/곧 리셋됨/막힘 해제/거의 소진" 을 **알림**으로 안내 — 효율 오케스트레이션 **+ 작업 시작 넛지**("세션 리셋됨 → 일하자"는 행동 트리거).
- G4. 자격증명·프롬프트·응답은 로컬 전용, (Phase 2) 클라우드엔 명령·상태 메타데이터만.

### 2.2 비목표
- N1. 쿼터를 "리셋/우회"하지 않음(창을 **시작**할 뿐).
- N2. 구독 자격증명을 프록시/대리 호출하지 않음(각 CLI 공식 로그인에만 얹힘).
- N3. 프롬프트·응답 본문 저장/전송 안 함.
- N4. (MVP) 팀/조직/SSO; 완전 로그아웃 상태 지원(→ 자동 로그인 권장); Grok(§12).

### 2.3 성공 지표 (인디 규모)
| ID | 지표 | 목표(MVP) |
| --- | --- | --- |
| M1 | 멀티계정 상태 스크랩 성공률 | ≥ 99% (골든 테스트 + 실사용) |
| M2 | 절전→기상→세션 시작 E2E 성공률 | ≥ 95% (로그인된 절전 기준) |
| M3 | 예약 기상 실행 성공률(전원·절전 전제) | ≥ 98% |
| M4 | 온디맨드 세션 시작 지연 p50/p95 (Mac 로컬) | ≤ 15s / ≤ 30s |
| M5 | 활성화(설치→모든 기존계정 대시보드 표시) | 5분 내, 재로그인 0 |
| M6 | 앱/헬퍼 주간 크래시 | 0 |

---

## 3. 페르소나 & JTBD
- **P1 — 멀티계정 비용 최적화 파워유저 (MVP 코어):** Mac + 여러 AI 구독(Claude 개인/회사, Codex 등). "$200 한 방 대신 여러 계정으로 최대 사용량을 뽑고 싶다. 뭐가 남았고 언제 갈아탈지 자동으로 알고 싶다."
- P2 — 단일 계정 + 절전 자동화 유저(확장).
- P3 — 폰으로 어디서든 관제(Phase 2).

JTBD: *"내 여러 AI 구독을 한 화면에서 보고, 컴퓨터를 안 켜둬도 세션이 준비되고, 지금 뭘 써야 효율적인지 알고 싶다."*

---

## 4. 핵심 개념
- **세션 윈도우:** 구독의 롤링 한도(5h + 주간). 첫 프롬프트로 창이 열리고 타이머가 돎.
- **관리 계정(managed account):** Wakie의 **핵심 단위**. `{provider, 라벨, configHome, device}`. 한 프로바이더에 계정 여러 개 가능.
- **Mac 앱 = 엔진 + 대시보드:** 메뉴바 GUI + 백그라운드 헬퍼(LaunchAgent). 실제 일(감지·기상·스크랩·세션시작)을 수행.
- **폰 앱 = 원격 리모컨(Phase 2):** 상태 표시 + 명령 전달. Mac 없이는 동작 안 함.
- **릴레이(Phase 2):** Supabase. 명령·상태 메타데이터·페어링만.

```
Phase 0-1:  [Mac 메뉴바 앱] ── 로컬 CLI 순회 ──▶ [claude/codex/agy × 계정들]
              엔진+대시보드                        자격증명·프롬프트 = 로컬 전용
Phase 2:    [iPhone 앱] ◀── Supabase 릴레이 ──▶ [Mac 앱]   (명령·상태만)
```

---

## 5. 범위 (MoSCoW)

| 우선 | 범위 |
| --- | --- |
| **Must (MVP=Mac 앱)** | 멀티계정 자동 감지·순회 · `/usage` 상태 읽기 · **메뉴바 대시보드** · 절전 기상(로그인된 절전) · **세션 자동 시작(리셋 체이닝 = token maxxing)** · 알림(전부 on/커스텀) · Claude/Codex/Antigravity |
| **Should** | 스케줄 기반 세션 시작 · 계정 추가 UX · 실패 상태 UX · 임계값 튜닝 |
| **Could (Phase 2)** | Supabase 릴레이 · **iPhone 앱**(원격 대시보드/제어) · 폰 푸시 알림 |
| **Won't (now)** | Grok(주간 풀·CLI 상태 미노출) · 다기기 러너 · 완전 로그아웃(root 데몬) · 팀/조직 · Wakie 소셜 로그인(→Phase 2) |

---

## 6. 사용자 여정

1. **온보딩:** ① Mac에 Wakie 앱 설치 → 열기 → **기존 AI 로그인 자동 감지·등록**(로그인 절차 없음). (Phase 2) ② iPhone 앱 설치 → 소셜 로그인·페어링 → 원격 대시보드.
2. **계정 추가:** Mac 앱에서 [계정 추가] → 프로바이더·라벨 → **기기에서 로그인**(새 config 홈) → 등록.
3. **관제(핵심):** 대시보드가 모든 계정의 세션/주간 %+리셋을 표시 → "거의 소진/방금 리셋" 알림 → 유저가 어느 계정 쓸지 판단.
4. **세션 자동 시작(token maxxing):** 각 계정의 **리셋 시각 도달 시** 엔진이 최저가 모델 프롬프트 1개로 새 창을 엶(리셋당 1회, 계정별 토글). 수동 Update/Refresh는 상태만 갱신.
5. **절전 자동:** **다음 리셋 시각들 + 아침 앵커 시각**에 예약 기상(다크 웨이크) → 자동 시작/상태 갱신 → 다시 절전. 창이 하나도 안 열려 있으면 아침 앵커가 체인을 시동.

---

## 7. 기능 요구사항

우선순위 M/S/C/W · 각 요구 수용기준(AC) 포함.

### 7.1 Mac 앱 — 대시보드/GUI (FR-UI)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-UI-01 | M | 메뉴바 아이콘 + 상태 요약(도는지/에러/로그인) | 아이콘으로 러너 상태 즉시 식별 |
| FR-UI-02 | M | 계정별 카드(세션%·리셋, 주간%·리셋, 마지막 결과) | 각 계정 최신 상태 표시; 데이터 없으면 "알 수 없음" |
| FR-UI-03 | M | 계정별 **Update**(그 계정 상태 갱신) · 전역 **Refresh all**(전 계정 상태 갱신) — **둘 다 읽기 전용** | 어떤 버튼도 세션을 시작하지 않음(쿼터 0); 세션 시작은 FR-RN-04 자동 체이닝 전용 |
| FR-UI-04 | S | 계정 추가/제거, 라벨 편집 | 추가 시 기기 로그인 유도→등록 |
| FR-UI-05 | M | 권한 안내(pmset admin 등) GUI | 최초 1회 admin 요청을 GUI로 |

### 7.2 Mac 앱 — 엔진/헬퍼 (FR-RN)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-RN-01 | M | **멀티계정 자동 감지** | 기본 홈(`~/.claude`,`~/.codex`,`~/.gemini`) 로그인 감지→계정 등록 |
| FR-RN-02 | M | **계정 백그라운드 순회** | 계정마다 env(`CLAUDE_CONFIG_DIR`/`CODEX_HOME`/`HOME`) 설정 후 CLI 실행, 무개입 |
| FR-RN-03 | M | 상태 읽기(어댑터) | 프로바이더별 TUI 슬래시 pty 스크랩 → 세션·주간 %+리셋 파싱 |
| FR-RN-04 | M | **세션 자동 시작(리셋 체이닝)** | 계정별 리셋 시각 도달 시 최저가 모델+최소 프롬프트 1개로 새 창(**리셋당 1회**); 계정별 토글(권장 기본: Claude on·Codex off — R0 🟡); 성공/실패·타임스탬프 기록 |
| FR-RN-05 | M | 절전 기상 | `pmset` 타이머 + LaunchAgent 헬퍼가 **다크 웨이크**에 실행, `caffeinate` 유지; 기상 스케줄 = **다음 리셋 시각들 + 아침 앵커**(파생) |
| FR-RN-06 | M | 로그인된 절전 커버 | 로그인 세션 유지 상태에서 기상·작업(화면 잠금 무관); 키체인 unlock 유지 전제 |
| FR-RN-07 | M | 로컬 상태 저장 | 계정별 상태를 로컬 store에 기록(Phase 2에서 릴레이 push) |
| FR-RN-08 | M | 로컬 전용 경계 | 자격증명·프롬프트·응답을 앱 밖으로 내보내지 않음 |

### 7.3 프로바이더 어댑터 (FR-PA)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-PA-01 | M | Claude | `claude -p` 시작; `/usage`+`/stats`; 멀티계정 `CLAUDE_CONFIG_DIR` |
| FR-PA-02 | M | Codex | 시작=`codex exec`; 상태=**`codex app-server` JSON-RPC**(`account/rateLimits/read`·`account/read` — 스크랩 불필요, 구조화 JSON); detect=`login status`; `CODEX_HOME`; 최소버전 체크 |
| FR-PA-03 | M | Antigravity | 시작=`agy -p`; 상태=**네이티브 pty**(openpty+posix_spawnp) TUI `/usage` 스크랩(`-p`는 `/usage`를 LLM 프롬프트로 오인식); detect=`--version`+`oauth_creds.json` **존재만** 확인(토큰 미독취); `HOME` 샌드박스 |

### 7.4 알림 (FR-NT)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-NT-01 | M | **기본 전부 on** | 리셋 임박/완료·거의 소진·막힘 해제 등 기본 활성 |
| FR-NT-02 | M | 계정별·유형별 커스텀 on/off | 설정에서 개별 토글 |
| FR-NT-03 | M | 임계값 | **확정(O2, 2026-07-02): 사용 80% · 리셋 10분 전** — 하드코드 우선, 조정 UI는 실사용 후 |
| FR-NT-04 | C | 그룹핑(스팸 방지) | 계정 수 개 규모에선 연기; 실사용에서 시끄러워지면 도입 |
| FR-NT-05 | M | 실패 알림 항상 on | 러너 오류/로그인 만료 = 상태변화당 1회 |
| FR-NT-06 | M | 채널 | Phase 0-1: Mac 알림 / Phase 2: 폰 푸시 |

### 7.5 온보딩/프리플라이트 (FR-OB)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-OB-01 | C | Wakie 계정 = 소셜 로그인(Apple/Google) | **Phase 2로 이동** — 릴레이 페어링용. 로컬 단독 Phase 0-1엔 불필요(설치 즉시 사용) |
| FR-OB-02 | M | CLI 감지(설치/버전/로그인) | 프로바이더별 `ok/not_installed/not_logged_in/outdated/needs_onboarding` |
| FR-OB-03 | M | 결핍 안내 | 설치/로그인/업데이트 액션(데스크톱에서 수행) |
| FR-OB-04 | C | 자동 로그인 권장 안내 | 완전 로그아웃 엣지 대비 설정 가이드 |

### 7.6 실패·관측 (FR-ER)
`not_logged_in`(재로그인) · 러너/헬퍼 이상 · 기상 실패(전원·절전 안내) · CLI 에러(재시도) · 스크랩 파싱 실패("알 수 없음" + 세션 시작은 계속). 각 상태는 대시보드에 행동 가능한 형태로 표시.

### 7.7 폰 앱 (Phase 2, FR-PH)
원격 대시보드(상태 표시) · 세션 시작/상태 갱신 명령 전달 · 스케줄 설정 · 푸시 알림. **로그인·계정추가·엔진은 없음**(Mac 전용). Mac 미도달 시 오프라인 표시.

---

## 8. 비기능 요구사항 (NFR)
| ID | 범주 | 목표 |
| --- | --- | --- |
| NFR-01 | 지연 | Mac 로컬 세션시작 p50 ≤ 15s/p95 ≤ 30s. (Phase 2) 폰 온디맨드 p95 ≤ 120s(기상 포함). |
| NFR-02 | 신뢰성 | E2E ≥ 95%, 파싱 ≥ 99%. 헬퍼 크래시 시 launchd 재기동. |
| NFR-03 | 보안/프라이버시 | 자격증명·본문 로컬 전용. (Phase 2) 릴레이=메타데이터+RLS+TLS. §11. |
| NFR-04 | 확장성 | 사용자당 계정 N개(설계 무제한, 실사용 수 개~십수 개). 러너 1대(모델은 N대 대비). |
| NFR-05 | 이식성 | Flutter(폰+Mac 데스크톱) + Dart core. 러너 로직은 `Process`로 OS 도구 호출. |
| NFR-06 | 관측성 | 구조화 로그, 스크랩 성공/실패 카운터, 계정별 상태 히스토리. |
| NFR-07 | 비용 | 상태 읽기=스크랩(쿼터 0). 세션 시작만 소량→최저가 모델. |
| NFR-08 | 업데이트/회귀 | CLI 최소버전 핀 + 스크랩 파서 골든테스트(NFR 회귀 방지). |
| NFR-09 | i18n/접근성 | MVP = **영어 단일**(문자열 외부화·ko 로케일은 Phase 3로 연기 — 1인 MVP 속도 우선). 동적 타입·대비 준수. |

---

## 9. 아키텍처

### 9.1 컴포넌트/스택
| 컴포넌트 | 역할 | 스택 |
| --- | --- | --- |
| Mac 앱 | 엔진(감지·기상·스크랩·세션·알림) + 메뉴바 GUI | **Flutter macOS(메뉴바) + LaunchAgent 헬퍼** |
| 공유 core | 계정 모델·어댑터·상태 로직·(P2)릴레이 클라이언트 | **Dart package** |
| 폰 앱 (P2) | 원격 대시보드/제어 | Flutter(iOS/Android) |
| 릴레이 (P2) | 명령·상태·페어링·인증 | Supabase(Postgres+Realtime+Auth+RLS) |

리포: `packages/core` · `apps/mac`(Flutter desktop) · `apps/phone`(P2).

### 9.2 절전 기상
`pmset schedule/repeat wake`(admin 1회) → Mac 하드웨어 타이머 기상(다크 웨이크) → **LaunchAgent 헬퍼**가 실행(GUI 앱은 다크웨이크 런타임 제약) → `caffeinate`로 유지 → 계정 순회 → 다시 절전. "로그인된 절전"에선 세션·키체인 유지 → 화면 잠금과 무관하게 동작.

### 9.3 멀티계정 자동 순회
```
for 각 계정:  env(CLAUDE_CONFIG_DIR/CODEX_HOME/HOME) 설정
             → claude -p / codex exec / agy -p (비대화)
             → /usage·/status pty 스크랩 → 상태 파싱 → 저장
```
> **기본 계정 = 앰비언트(2026-07-01 실측):** 기본 계정 자격증명은 macOS **Keychain**에 있어 `CLAUDE_CONFIG_DIR`를 지정하면 파일 네임스페이스로 전환돼 로그인이 풀림 → 기본 계정은 **env 오버라이드 없이** 실행(`Account.configHome=null`), **추가 계정만** config 홈으로 격리.

---

### 9.4 디자인 & 브랜드 (2026-07-01 확정)
- **이름:** Wakie ("wake" = 세션/기기를 깨움).
- **로고:** "오빗(orbit)" 마크 — 네이비 필드 + 흰 궤도 링 + **앰버 코어**(깨어난 태양/별). protostar에서 유래, 대칭·큰 코어·풀프레임. 단색·앱아이콘(네이비 타일) 대응. 에셋: `docs/design/`.
- **미감:** 다크 프로스티드 글래스(Cluely 계열) — 반투명 플로팅 패널, 얇은 헤어라인, **탭ular 모노 숫자**, 앰버 단일 액센트 + 의미색(초록/앰버/레드).
- **메인 화면:** 메뉴바 아이콘 → 클릭 시 **전체 창(대시보드)**. 계정 카드 목록(세션·주간 %+리셋, 상태 pill, 실제 프로바이더 로고). 참고 목업: `docs/design/dashboard-mockup.html`.
- **핵심 액션:** 계정별 **Update** · 전역 **Refresh all**(둘 다 **상태만, 읽기 전용**) · **Add account**. 세션 시작은 엔진 자동 체이닝(FR-RN-04) 전용 — 버튼 없음.

## 10. 데이터 모델 & 계약

### 10.1 로컬 store (Phase 0-1, Mac)
```
Account { id, provider, label, configHome, deviceId, addedAt }
Status  { accountId, sessionPct?, sessionResetAt?, weeklyPct?, weeklyResetAt?,
          lastStartedAt?, lastOutcome, lastCheckedAt }
Schedule{ morningAnchorHour, morningAnchorMinute, autoStart{accountId: on/off} }
          // 기상 시각 = 다음 리셋 시각들 + 아침 앵커 (별도 인터벌 설정 없음 — 파생)
AlertPrefs { perAccount/type on/off, thresholds{ nearLimitPct=80, ... } }
```
- **핵심 단위 = Account**(멀티계정). Status는 accountId 키. deviceId는 1대여도 유지(N대 성장 대비).

### 10.2 릴레이 스키마 (Phase 2, Supabase, RLS)
```sql
devices(id, user_id, kind, name, os, app_version, online, power_state, last_seen)
accounts(id, user_id, device_id, provider, label, added_at)   -- configHome은 로컬 전용, 릴레이 미저장
statuses(id, user_id, account_id, session_pct, session_reset_at,
         weekly_pct, weekly_reset_at, last_started_at, last_outcome, last_checked_at)
commands(id, user_id, target_device, type∈{startNow,checkStatus,setSchedule,wakeNow},
         account_id?, schedule?, status, created_at, expires_at)
-- 자격증명·프롬프트·응답 필드 없음. RLS: user_id = auth.uid()
```

### 10.3 어댑터 인터페이스 (Dart)
```dart
abstract class ProviderAdapter {
  String get id;
   Map<String,String> envFor(Account a);         // 계정 격리 env
  Future<Preflight> detect(Account a);
  Future<RunOutcome> startSession(Account a, {String? model});
  Future<ProviderStatus> readStatus(Account a);  // pty scrape → nullable
}
```

---

## 11. 보안 & 프라이버시
- **로컬 전용:** CLI OAuth 토큰·프롬프트·응답은 Mac에만(각 CLI config 홈/키체인). 릴레이·폰으로 안 감.
- **데이터 분류:** Secret(자격증명·본문, 로컬) / Restricted(사용량·리셋·명령, Phase2 릴레이 RLS) / Public(없음).
- **(Phase 2) 릴레이 위협:** 계정 탈취→명령 큐잉→Mac 실행. 완화: 명령 **고정 enum**(임의 exec 불가, 폭발반경={세션시작·기상·상태읽기}), 페어링+RLS, TTL·레이트리밋, TLS.
- **키체인/절전:** "로그인된 절전"은 키체인 unlock 유지(기본) → agy 포함 동작. "잠들 때 키체인 잠금" 설정(비기본)만 예외.
- **프로바이더 ToS(가정·리스크):** 본인 기기·본인 로그인으로 CLI 구동(프록시 아님). 자동·주기 프롬프트의 약관 부합은 명시 가정(§17).

---

## 12. 지원 프로바이더 (검증)
| 프로바이더 (CLI) | 세션 시작 | 사용량/리셋 | 멀티계정 | 인증 | 종합 |
| --- | --- | --- | --- | --- | --- |
| Claude (`claude`) | ✅ `-p` | ✅ `/usage`+`/stats` | ✅ `CLAUDE_CONFIG_DIR` | claude.ai | 🟢 |
| Codex (`codex`, 번들) | ✅ `exec` | ✅ **app-server JSON-RPC**(구조화, 스크랩 불필요) | ✅ `CODEX_HOME` | ChatGPT | 🟢 |
| Gemini=Antigravity (`agy`) | ✅ `-p` | ✅ TUI `/usage` **네이티브 pty 스크랩** | ✅ `HOME` 샌드박스 | Google/Antigravity | 🟢 |

- **Grok 제외:** 주간 공용 풀(5h 창 없음) + CLI로 주간 사용량 미노출(`/usage`=크레딧→웹) → 제품 핵심과 불일치.
- **버전 스큐:** Codex 0.125.0 실패→0.142.5 필요 → 최소버전 체크·번들 경로 폴백.

---

## 13. 관측성 (경량, 로컬 우선)
구조화 로그(레벨/JSON), 스크랩 성공/실패 카운터, 계정별 상태 히스토리. 원격 텔레메트리는 옵트인. 지표 M1~M6를 로컬 집계로 산출.

---

## 14. 테스트 & QA
- **단위:** 스크랩 파서를 **골든 픽스처**로(검증 캡처: Claude/Codex/agy `/usage`,`/status`, §Appx C). UI 변경 시 실패로 회귀 감지.
- **계약:** `ProviderAdapter` conformance(어댑터별) + 멀티계정 env 격리 테스트.
- **통합/E2E:** 절전→기상→계정 순회→상태 갱신; 세션 시작.
- **보안:** 로컬 경계(자격증명·본문 미유출) 단정 테스트; (P2) RLS 격리.
- **회귀:** CLI 최소버전 미만 감지(Codex 스큐 재현).

---

## 15. 릴리스 계획 (Mac 우선)
| Phase | 산출물 | 게이트 |
| --- | --- | --- |
| **0** | Mac 앱 코어: 멀티계정 자동감지 + `/usage` 스크랩 + 메뉴바 대시보드 + 세션 시작(온디맨드) | 기존 로그인 계정들이 대시보드에 정확 표시; 파서 골든테스트 통과 |
| **1** | 로컬 store + **세션 자동 시작(리셋 체이닝)** + 절전 기상(pmset+LaunchAgent, 리셋들+아침 앵커) + 알림(Mac) + 계정 추가 UX | Mac 절전→기상→자동 시작/상태 갱신 E2E ≥ 95% |
| **2** | Supabase 릴레이 + iPhone 앱(원격 대시보드/제어) + 폰 푸시 | 폰에서 실시간 상태·원격 세션 시작; RLS 격리 |
| **3** | 하드닝·다계정 스케일·자동로그인 안내·Win/Android 확장 검토 | 실사용 신뢰성·회귀 안정 |

> **확정(D1, 2026-07-02):** 정기 동작 = **읽기 전용 상태 갱신**(쿼터 0). 세션 시작 = **리셋 시각 자동 체이닝**(token maxxing) — 리셋당 1회·최저가 모델·계정별 토글(권장 기본: Claude on·Codex off, R0 🟡). 수동 시작 버튼 없음. 절전 기상 스케줄 = 다음 리셋 시각들 + 아침 앵커(창이 없으면 아침 앵커가 체인 시동).

### Phase 1 실행 순서 (의존성순, 2026-07-02 계획 리뷰)

| # | 작업 | 게이트 |
| --- | --- | --- |
| P1-1 | **로컬 store(JSON)** — Status·Schedule·AlertPrefs + 계정 추가/제거 영속화(현재 제거한 계정이 재스캔 시 부활하는 버그 해소) | 앱 재시작 후 상태 유지 · 제거 계정 부활 없음 |
| P1-2 | **리셋 절대시각을 core로** — Claude 라벨("2:30am") 파싱 + duration 변환을 표시 계층에서 core로 이관 | 3어댑터 모두 `resetAt` 골든 통과 |
| P1-3 | **headless 러너**(`core/bin/`) — 순회→store 기록 원샷 (다크웨이크는 GUI 앱 제약 → 헬퍼 분리 필수) | 터미널 1회 실행 → store 갱신 → GUI 반영 |
| P1-4 | **세션 자동 시작 체이닝**(awake 상태) — 리셋 도달 감지→startSession, 계정별 토글 | 리셋 도달 → 새 창 열림 실확인(리셋당 1회) |
| P1-5 | **pmset+LaunchAgent 다크웨이크** — 기상 스케줄(리셋들+아침 앵커) + admin 1회 GUI(FR-UI-05) | 절전→기상→자동 시작/갱신 E2E ≥ 95% (M2/M3) |
| P1-6 | **Mac 알림** — 80%·리셋 10분 전·실패 알림 | 임계 통과 시 정확히 1회 발화 |
| P1-7 | **계정 추가 UX**(Should) | 두 번째 계정 등록·표시 |

---

## 16. 운영 / 패키징
- **Mac:** Flutter macOS 메뉴바 앱 + 번들 LaunchAgent 헬퍼(`KeepAlive`). **코드사이닝·공증**(오너 Apple 개발자 계정 보유) → **DMG**(Developer ID). `pmset` admin 1회 GUI 요청. **자동 로그인 권장** 안내로 로그아웃 엣지 커버.
- **D-SANDBOX(확정 2026-07-02): App Store 배포 불가.** MAS는 번들 내 **모든 실행파일**의 App Sandbox를 의무화하는데, 제품 핵심 셋(공식 CLI 구동+그 키체인 로그인 사용 · `~/.claude` 등 홈 읽기 · `pmset` admin)이 전부 샌드박스 금지 항목 — "비샌드박스 헬퍼만 분리" 우회도 MAS에선 금지라 구조적 비호환. **배포 = Developer ID 서명+공증 DMG**(게이트키퍼 경고 없는 공식 외부 배포 경로; Raycast·Bartender류 메뉴바 앱과 동일). 뷰어 전용 MAS 컴패니언 앱은 Phase 3+에서 검토.
- **iOS(P2):** App Store/TestFlight(동일 개발자 계정).
- **업데이트:** 앱 자체 업데이트 + CLI 최소버전 안내. 스크랩 파서 골든테스트로 안전 배포.

---

## 17. 리스크 · 가정 · 의존성 · 오픈 이슈

### R0. ToS/약관 준수 (최우선 리스크)
제품 가치가 프로바이더 약관이 능동적으로 조이는 패턴(자동화·멀티계정 효율화)과 맞닿아 있어 **가장 존재론적인 리스크**. 단, 아키텍처 선택으로 방어 가능한 위치에 있음.

**방어의 핵심 = "공식 바이너리만, 토큰 절대 추출 안 함" (아키텍처 불변식, 협상 불가).**
- Anthropic Consumer Terms §3.7은 "API Key 또는 **명시적 허용**을 제외한 자동/비인간 접근"을 금지하나, 공식 `claude` CLI의 스크립트·스케줄 자동화는 **명시적 허용 범주**(Anthropic이 GitHub Actions scheduled workflow·자동 리뷰를 직접 문서화). 2026 초 단속("OpenClaw ban")은 **OAuth 토큰 추출→제3자 클라이언트**가 대상이었고, 공식 바이너리 실행은 여기 해당 없음 → N2·A2가 이미 안전한 쪽.

**프로바이더별 신호등:**
| 프로바이더 | 위치 | 근거 |
| --- | --- | --- |
| Claude | 🟢 방어 가능 | 공식 바이너리 실행 = §3.7 허용 예외, 토큰 추출 아님 |
| Codex | 🟡 회색 | "rate limit 우회·Output 프로그램적 추출" 금지 조항, 스케줄 자동화 미축복 |
| Antigravity | 🟠 불투명 | 자동화 조항 공개 안 됨 → 예측 리스크 최대 |

**완화:**
1. 아키텍처 불변식(공식 바이너리·토큰 미추출·본문 미저장) = ToS 방패 — 격상 유지.
2. **포지셔닝을 "회피"에서 "관리"로.** *"one tier's price, every subscription at full usage"* 류 회피 프레이밍 → *"이미 결제한 계정들을 한눈에 관리·오케스트레이션"* 로.
3. **인간 케이던스 빈도.** 기계식 폴링은 "우회"로 읽힘 → warm 유지를 정상 사용 패턴 범위로 제한.
4. **어댑터 kill-switch를 ToS 모니터링에 연결** — CLI UI 변경뿐 아니라 약관 변경 트리거에도(특히 Anthropic 잦은 개정).
> 근거: The Register(2026-02-20, §3.7 & OpenClaw), autonomee.ai(§3.7 해설), OpenAI Terms of Use, openai/codex Discussion #8338.

### 가정
- A1. 상태 읽기가 **비공식 TUI 스크랩** 의존 → CLI UI 변경 시 취약(완화: 골든테스트·버전 핀·"세션 시작만" 강등).
- A2. 각 CLI가 구독 로그인 + 헤드리스 + **계정별 config 홈 격리** 지속 지원.
- A3. 자동·주기 프롬프트가 프로바이더 ToS에 부합(본인 기기·로그인) → **R0 참조**(단순 가정 아님, 능동 관리 대상).
- A4. 세션 시작은 사용량을 **소모**한다(아끼는 게 아님) → 최저가 모델·빈도 제어.
### 리스크→완화
**ToS 준수→R0(신호등·불변식·포지셔닝·kill-switch)** · TUI 스크랩 취약→골든/버전핀/강등 · 절전 기상 신뢰성→pmset+LaunchAgent(다크웨이크)+전원권장 · 키체인 잠금 설정→안내 · 코드사이닝/공증 마찰→개발자 계정 보유 · (P2)릴레이 탈취→명령 화이트리스트·RLS.
### 오픈 이슈
O1(D1)·O2 **해결(2026-07-02)** — §15 확정 블록·FR-NT-03 참조. O3. 다기기 러너(성장).
### 의존성
Flutter/Dart · 각 프로바이더 CLI(설치·로그인·최소버전) · (P2) Supabase.

---

## 18. 범위 밖
팀/조직·SSO · 완전 로그아웃(root 데몬; 자동로그인으로 대체) · Grok · 프로바이더 API 키 트랙 · 프롬프트/응답 로깅.

---

## Appendix A — 용어집
세션 윈도우 · 관리 계정 · Mac 앱(엔진+메뉴바) · LaunchAgent 헬퍼 · 다크 웨이크 · 강등(스크랩 실패 시 세션 시작만 유지).

## Appendix B — 참고/출처
Anthropic Claude Code(`-p`·`/usage`·`/stats`) · OpenAI Codex(`exec`·`/status`) · [Antigravity — GCP Blog](https://cloud.google.com/blog/topics/developers-practitioners/choosing-your-surface-antigravity-20-antigravity-cli-antigravity-ide-or-antigravity-sdk)·[agy GitHub](https://github.com/google-antigravity/antigravity-cli) · (제외)xAI Grok — 주간 풀([Docs](https://docs.x.ai/grok/faq)).

## Appendix C — 검증 로그 (2026-07-01, macOS)
| 항목 | 결과 |
| --- | --- |
| Claude `-p` / `/usage` 스크랩 | ✅ "ok" / 세션·주간 %+리셋 |
| Codex `exec`(번들 0.142.5) / `/status` | ✅ / 5h·주간 %+리셋 |
| Antigravity `agy -p` / `/usage` | ✅ / Gemini·Claude·GPT 그룹별 주간·5h |
| 멀티계정 자동 전환 | ✅ Claude `CLAUDE_CONFIG_DIR`·Codex `CODEX_HOME`·Grok `GROK_HOME`·agy `HOME` — 비대화 전환 실증 |
| 절전 기상/유지 | ✅ `pmset` 스케줄·`caffeinate` |
| 비용 | haiku ~$0.008 vs opus ~$0.038/회 |

> 골든 픽스처: pty 캡처 원문을 `packages/core/test/fixtures/`에 보관.
