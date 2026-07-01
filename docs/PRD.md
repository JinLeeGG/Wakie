# WakieAI — Product Requirements Document (PRD)

| | |
| --- | --- |
| **Status** | Draft v1.2 (production, engineering-focused) |
| **Owner** | John (wakieDemo1@gmail.com) |
| **Last updated** | 2026-07-01 |
| **Audience** | Engineering 실행 중심 · 인디/개인 제품 · 소규모 시작→성장 대비 |
| **Related** | [CLAUDE.md](../CLAUDE.md) |

### Changelog
- **v1.2 (2026-07-01)** — 브랜드/디자인 확정: 이름 **WakieAI**, 오빗 로고(네이비+앰버), 다크 글래스 대시보드, Update/Refresh 액션 정의(§9.4).
- **v1.1 (2026-07-01)** — 결정 패스 반영: 가치 재정의(멀티계정 효율 오케스트레이션), 멀티계정=핵심 단위(4↓3종 검증), Mac 메뉴바 앱 우선(폰 Phase 2), 절전 기상 MVP, Supabase 릴레이(Phase 2), 알림 전략.
- v1.0 — production 재작성(요구사항 ID·수용기준·데이터모델·보안·테스트).
- v0.x — 검증·프로바이더 매트릭스·피벗.

---

## 0. TL;DR

AI 파워유저는 월 $200 최고 티어 하나 대신, **여러 개의 더 저렴한 구독/계정**으로 더 많은 사용량을 확보한다. 문제는 그걸 **효율적으로 굴리기가 번거롭다**는 것 — 어느 계정이 남았는지, 언제 창이 리셋되는지, 언제 갈아타야 하는지 매번 확인해야 한다.

**WakieAI = 멀티계정 AI 사용량 효율 오케스트레이터.** Mac에서 도는 앱이 로그인된 여러 AI CLI(Claude/Codex/Antigravity)를 **백그라운드로 순회**하며 각 계정의 사용량/리셋을 읽어 **통합 대시보드**로 보여주고, **절전 상태에서 깨어나** 세션을 시작하며, **언제 무엇을 쓸지 알림**으로 알려준다.

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
- **관리 계정(managed account):** WakieAI의 **핵심 단위**. `{provider, 라벨, configHome, device}`. 한 프로바이더에 계정 여러 개 가능.
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
| **Must (MVP=Mac 앱)** | 멀티계정 자동 감지·순회 · `/usage` 상태 읽기 · **메뉴바 대시보드** · 절전 기상(로그인된 절전) · 세션 시작(온디맨드) · 알림(전부 on/커스텀) · Claude/Codex/Antigravity |
| **Should** | 스케줄 기반 세션 시작 · 계정 추가 UX · 실패 상태 UX · 임계값 튜닝 |
| **Could (Phase 2)** | Supabase 릴레이 · **iPhone 앱**(원격 대시보드/제어) · 폰 푸시 알림 |
| **Won't (now)** | Grok(주간 풀·CLI 상태 미노출) · 다기기 러너 · 완전 로그아웃(root 데몬) · 팀/조직 · **세션 시작 상세 UX 플로우(다음 결정)** |

---

## 6. 사용자 여정

1. **온보딩("앱 2개"):** ① Mac에 WakieAI 앱 설치 → 열기 → WakieAI 소셜 로그인 → **기존 AI 로그인 자동 감지·등록** → (Phase 2) ② iPhone 앱 설치 → 같은 계정 로그인 → 대시보드.
2. **계정 추가:** Mac 앱에서 [계정 추가] → 프로바이더·라벨 → **기기에서 로그인**(새 config 홈) → 등록.
3. **관제(핵심):** 대시보드가 모든 계정의 세션/주간 %+리셋을 표시 → "거의 소진/방금 리셋" 알림 → 유저가 어느 계정 쓸지 판단.
4. **세션 시작:** 대시보드에서 계정 선택 → 지금 시작(온디맨드). (예약/자동 시작 플로우 = 다음 결정.)
5. **절전 자동:** Mac이 예약 기상(다크 웨이크) → 상태 갱신/예약 세션 → 다시 절전.

---

## 7. 기능 요구사항

우선순위 M/S/C/W · 각 요구 수용기준(AC) 포함.

### 7.1 Mac 앱 — 대시보드/GUI (FR-UI)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-UI-01 | M | 메뉴바 아이콘 + 상태 요약(도는지/에러/로그인) | 아이콘으로 러너 상태 즉시 식별 |
| FR-UI-02 | M | 계정별 카드(세션%·리셋, 주간%·리셋, 마지막 결과) | 각 계정 최신 상태 표시; 데이터 없으면 "알 수 없음" |
| FR-UI-03 | M | 계정별 **Update**(세션 시작+상태 갱신) · 전역 **Refresh all**(상태만) | Update=프롬프트로 새 세션 시작 + 그 계정 상태 갱신; Refresh all=세션 시작 없이 전 계정 상태만 갱신 |
| FR-UI-04 | S | 계정 추가/제거, 라벨 편집 | 추가 시 기기 로그인 유도→등록 |
| FR-UI-05 | M | 권한 안내(pmset admin 등) GUI | 최초 1회 admin 요청을 GUI로 |

### 7.2 Mac 앱 — 엔진/헬퍼 (FR-RN)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-RN-01 | M | **멀티계정 자동 감지** | 기본 홈(`~/.claude`,`~/.codex`,`~/.gemini`) 로그인 감지→계정 등록 |
| FR-RN-02 | M | **계정 백그라운드 순회** | 계정마다 env(`CLAUDE_CONFIG_DIR`/`CODEX_HOME`/`HOME`) 설정 후 CLI 실행, 무개입 |
| FR-RN-03 | M | 상태 읽기(어댑터) | 프로바이더별 TUI 슬래시 pty 스크랩 → 세션·주간 %+리셋 파싱 |
| FR-RN-04 | M | 세션 시작(어댑터) | 최저가 모델+최소 프롬프트, 성공/실패·타임스탬프 |
| FR-RN-05 | M | 절전 기상 | `pmset` 타이머 + LaunchAgent 헬퍼가 **다크 웨이크**에 실행, `caffeinate` 유지 |
| FR-RN-06 | M | 로그인된 절전 커버 | 로그인 세션 유지 상태에서 기상·작업(화면 잠금 무관); 키체인 unlock 유지 전제 |
| FR-RN-07 | M | 로컬 상태 저장 | 계정별 상태를 로컬 store에 기록(Phase 2에서 릴레이 push) |
| FR-RN-08 | M | 로컬 전용 경계 | 자격증명·프롬프트·응답을 앱 밖으로 내보내지 않음 |

### 7.3 프로바이더 어댑터 (FR-PA)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-PA-01 | M | Claude | `claude -p` 시작; `/usage`+`/stats`; 멀티계정 `CLAUDE_CONFIG_DIR` |
| FR-PA-02 | M | Codex | 번들 `codex exec`; `/status`+`/usage daily`; `CODEX_HOME`/`--profile`; 최소버전 체크 |
| FR-PA-03 | M | Antigravity | `agy -p`; `/usage`(주간·5h); 멀티계정 `HOME` 샌드박스; 첫실행 온보딩 감지 |

### 7.4 알림 (FR-NT)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-NT-01 | M | **기본 전부 on** | 리셋 임박/완료·거의 소진·막힘 해제 등 기본 활성 |
| FR-NT-02 | M | 계정별·유형별 커스텀 on/off | 설정에서 개별 토글 |
| FR-NT-03 | M | 임계값 조정 | "거의 소진" 임계(기본 80% 등) 사용자 조정 |
| FR-NT-04 | M | 그룹핑(스팸 방지) | 동시 다발 시 묶어서 1개 |
| FR-NT-05 | M | 실패 알림 항상 on | 러너 오류/로그인 만료 = 상태변화당 1회 |
| FR-NT-06 | M | 채널 | Phase 0-1: Mac 알림 / Phase 2: 폰 푸시 |

### 7.5 온보딩/프리플라이트 (FR-OB)
| ID | Pri | 요구 | AC |
| --- | --- | --- | --- |
| FR-OB-01 | M | WakieAI 계정 = 소셜 로그인(Apple/Google) | 최초 1회, 비번 관리 없음 |
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
| NFR-09 | i18n/접근성 | **기본 언어 = 영어(en)**, 한국어(ko) 로케일 지원. 모든 UI 문자열 **외부화**(하드코딩 금지). 동적 타입·대비 준수. |

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

---

### 9.4 디자인 & 브랜드 (2026-07-01 확정)
- **이름:** WakieAI ("wake" = 세션/기기를 깨움).
- **로고:** "오빗(orbit)" 마크 — 네이비 필드 + 흰 궤도 링 + **앰버 코어**(깨어난 태양/별). protostar에서 유래, 대칭·큰 코어·풀프레임. 단색·앱아이콘(네이비 타일) 대응. 에셋: `docs/design/`.
- **미감:** 다크 프로스티드 글래스(Cluely 계열) — 반투명 플로팅 패널, 얇은 헤어라인, **탭ular 모노 숫자**, 앰버 단일 액센트 + 의미색(초록/앰버/레드).
- **메인 화면:** 메뉴바 아이콘 → 클릭 시 **전체 창(대시보드)**. 계정 카드 목록(세션·주간 %+리셋, 상태 pill, 실제 프로바이더 로고). 참고 목업: `docs/design/dashboard-mockup.html`.
- **핵심 액션:** 계정별 **Update**(세션 시작+상태 갱신) · 전역 **Refresh all**(상태만) · **Add account**.

## 10. 데이터 모델 & 계약

### 10.1 로컬 store (Phase 0-1, Mac)
```
Account { id, provider, label, configHome, deviceId, addedAt }
Status  { accountId, sessionPct?, sessionResetAt?, weeklyPct?, weeklyResetAt?,
          lastStartedAt?, lastOutcome, lastCheckedAt }
Schedule{ enabled, intervalHours(3..8), anchorHour, anchorMinute }
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
| Codex (`codex`, 번들) | ✅ `exec` | ✅ `/status`+`/usage daily` | ✅ `CODEX_HOME`/`--profile` | ChatGPT | 🟢 |
| Gemini=Antigravity (`agy`) | ✅ `-p` | ✅ `/usage`(주간·5h) | ✅ `HOME` 샌드박스 | Google/Antigravity | 🟢 |

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
| **1** | 절전 기상(pmset+LaunchAgent 다크웨이크) + 스케줄 + 알림(Mac) + 계정 추가 UX | Mac 절전→기상→상태 갱신/세션 E2E ≥ 95% |
| **2** | Supabase 릴레이 + iPhone 앱(원격 대시보드/제어) + 폰 푸시 | 폰에서 실시간 상태·원격 세션 시작; RLS 격리 |
| **3** | 하드닝·다계정 스케일·자동로그인 안내·Win/Android 확장 검토 | 실사용 신뢰성·회귀 안정 |

> **보류(다음 결정):** 세션 시작 상세 UX 플로우 + 정기 리프레시 동작(상태만 읽기 vs 세션 시작; D1).

---

## 16. 운영 / 패키징
- **Mac:** Flutter macOS 메뉴바 앱 + 번들 LaunchAgent 헬퍼(`KeepAlive`). **코드사이닝·공증**(오너 Apple 개발자 계정 보유) → DMG/App Store. `pmset` admin 1회 GUI 요청. **자동 로그인 권장** 안내로 로그아웃 엣지 커버.
- **iOS(P2):** App Store/TestFlight(동일 개발자 계정).
- **업데이트:** 앱 자체 업데이트 + CLI 최소버전 안내. 스크랩 파서 골든테스트로 안전 배포.

---

## 17. 리스크 · 가정 · 의존성 · 오픈 이슈
### 가정
- A1. 상태 읽기가 **비공식 TUI 스크랩** 의존 → CLI UI 변경 시 취약(완화: 골든테스트·버전 핀·"세션 시작만" 강등).
- A2. 각 CLI가 구독 로그인 + 헤드리스 + **계정별 config 홈 격리** 지속 지원.
- A3. 자동·주기 프롬프트가 프로바이더 ToS에 부합(본인 기기·로그인).
- A4. 세션 시작은 사용량을 **소모**한다(아끼는 게 아님) → 최저가 모델·빈도 제어.
### 리스크→완화
TUI 스크랩 취약→골든/버전핀/강등 · 절전 기상 신뢰성→pmset+LaunchAgent(다크웨이크)+전원권장 · 키체인 잠금 설정→안내 · ToS 변화→모니터·어댑터 중단 · 코드사이닝/공증 마찰→개발자 계정 보유 · (P2)릴레이 탈취→명령 화이트리스트·RLS.
### 오픈 이슈
O1. **세션 시작 UX 플로우 + 정기 리프레시 동작(D1)** — 다음 결정. O2. 알림 임계 기본값 튜닝. O3. 다기기 러너(성장).
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
