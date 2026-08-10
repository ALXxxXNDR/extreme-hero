# 극딜 용사 — AI 작업 인수인계 원본 (v3)

> 이 파일은 이 프로젝트의 **단일 인수인계 원본(Single Source of Truth)** 이다.
> 사람이나 AI가 작업을 시작할 때 다른 문서보다 먼저 이 파일을 처음부터 끝까지 읽는다.
> 구현·기획·구조·진행 상태가 바뀌면 코드 작업이 끝나기 전에 반드시 이 파일도 갱신한다.
>
> **2026-08-09 v3 스테이지 개편 완료.** 이 문서는 V0~V10 열한 웨이브로 다시 만들어진
> v3 게임을 기준으로 전면 개정됐다. **v2 기준 서술은 남아 있지 않다** — v2에서 사라진
> 규칙(7일 기한 · 계보 각성 · 월식)은 "무엇이 바뀌었는가"를 설명하는 §10에만 나온다.
> 설계 근거는 `docs/GAME_DESIGN_V3.md`(**부록 A = 확정 결정**, 본문보다 우선),
> 웨이브별 상세는 `docs/handoff-v1.md` ~ `handoff-v10.md`에 있다.
>
> **2026-08-09 UI 재스킨 시리즈(U0~U3) 완료.** 로비·온보딩·모달·ESC 편집·필드 HUD가
> 전부 v3 UI 킷으로 갈렸고 필드 첫 낮에 스포트라이트 길잡이 7스텝이 붙었다.
> **UI 스타일의 단일 진실 원천은 `docs/ui-style-v3.md`**이고 상세는
> `docs/handoff-u1.md` ~ `handoff-u3.md`에 있다. **바뀐 것은 표면과 길잡이뿐이다** —
> 정보 구조·HUD 좌표 계약·화면 흐름·상태 문자열·저장 스키마는 그대로였다.
>
> **2026-08-09 플레이테스트 피드백 라운드(X1~X4) 완료.** 사용자 피드백 6건을 네 웨이브로
> 반영했다 — 레벨업 모달 대개편 + 각인 경제 이전(X1) · ESC 편집 대간소화 + 공용 호버 툴팁
> (X2) · 필드 HUD 탈블록 + 가장자리 화살표 내비 + 딜싸이클 미니모드(X3) · 길잡이 중 세계
> 정지 + 온보딩 텍스트 다이어트(X4). **이번에는 표면만 바뀐 것이 아니다** — 각인 획득 경로 ·
> 레벨업 선택지 구성 · HUD 정보 구조 · 편집 화면 조작 모델이 함께 바뀌었다.
> 상세는 `docs/handoff-x1.md` ~ `handoff-x4.md`. **저장 스키마는 schema 3 그대로**이고
> 게임 규칙(전투·상태이상·dwell·보스)은 한 줄도 안 바뀌었다.
> *(두 문장 모두 **X 라운드 시점의 서술**이다. Y 라운드가 저장 스키마를 **schema 4**로 올렸고
> 게임 규칙도 바꿨다 — 바로 아래 문단.)*
>
> **2026-08-10 2차 플레이테스트 피드백 라운드(Y0~Y8 · YA · YZ) 완료.** 사용자 피드백 25건을
> 열한 웨이브로 반영했다. **이번에는 표면이 아니라 게임 규칙이 바뀌었다** —
> **과열 전면 제거**(한 칸은 한 바퀴에 두 번까지) · **각인 24종 → 15종**(칸 10 + 레일 5) ·
> **속성 7계의 한자 폐기**(화·빙·뇌 → 불·얼음·번개) · **저장 schema 3 → 4** ·
> **자동 검사 15종 → 17종**(컴파일 1 + 기능 16) · **밸런스 상수 실측 재확정**(dwell 곡선 ·
> 스테이지 HP 계단 · 보스 `DESIGN_HP` 전량) · **필드 생태/발견/사건/재미 아이템 신설** ·
> **타격감 전면 개편**(몹별 피격 반응 · `impact` 8종 · 카메라 흔들림 계약).
> 웨이브별 상세는 `docs/handoff-y1.md` ~ `handoff-y8.md` + `docs/handoff-ya.md`,
> 설계 근거는 `docs/FEEDBACK_Y.md`다.
>
> **수치의 최종 진실은 코드다**(`scripts/core/tuning.gd` + 라이브러리 7종).
> 설계 문서와 코드가 다르면 코드가 맞다.

---

<!-- BEGIN:engineering-principles -->
## 엔지니어링 원칙

로컬의 모든 `AGENTS.md`에 동일한 내용으로 유지되는 블록이다. 수정은 한 곳에서 하고 전체에 다시 동기화한다.

1. **선례를 먼저 조사한다.** 해결책을 설계하기 전에, 이미 자리 잡은 제품들이 같은 문제를 어떻게 푸는지 살펴본다. 접근 방식을 처음부터 발명하지 말고 검증된 패턴과 관례를 채택한다.
2. **하위 호환을 유지하지 않는다.** 호환 레이어·폴백·마이그레이션을 덧붙이는 대신, 쓰이지 않는 경로를 삭제한다.
3. **가장 단순한 구현을 고른다.** 현재 요구사항을 완전히 충족하는 선에서 멈춘다. 추측에 근거한 추상화, 설정값, 간접 계층을 만들지 않는다.
4. **레이어로 키운다.** 엔드투엔드로 동작하는 최소 버전에서 시작해, 이미 동작하는 결과물 위에 기능을 하나씩 얹는다. 동작하는 코드를 미완성 복잡도와 맞바꾸지 않는다.
5. **모듈로 분리한다.** 컴포넌트를 모듈로 나누고 관심사 경계를 명확히 둔다.
6. **검증된 라이브러리를 쓴다.** 유지보수되는 라이브러리가 전체 복잡도를 낮추거나 안정성을 높인다면 그것을 쓴다. 흔한 기능을 명확한 이유 없이 재구현하지 않는다.
7. **이미 설치된 의존성부터 확인한다.** 직접 구현하거나 패키지를 추가하기 전에 현재 의존성을 확인한다. 문서와 타입을 보지 않은 채 "이 라이브러리엔 그 기능이 없다"고 단정하지 않는다.
8. **아키텍처는 장기 관점으로 결정한다.** 지금만 넘기고 나중에 교체할 임시방편을 받아들이지 않는다.
<!-- END:engineering-principles -->

## 0. 문서 메타데이터

| 항목 | 현재 값 |
|---|---|
| 프로젝트명 | 극딜 용사 |
| 작업 경로 | `/Users/moomi/orca/projects/NHN` |
| 실제 게임 경로 | `/Users/moomi/orca/projects/NHN/godot-game` |
| 현재 엔진 | Godot `4.7.1.stable.official.a13da4feb` |
| 언어 | GDScript |
| 기준 해상도 | 1280×720 |
| 렌더러 | GL Compatibility |
| 현재 플레이 가능 캐릭터 | 왕국 검사 1명 |
| 시각 테마 | Ninja Adventure 픽셀 스프라이트 (Pixel-boy & AAA, CC0) + Kenney Particle Pack |
| UI 테마 | **v3 UI 킷** — `art/v2/ui-kit-*.png` 10장 + `scripts/ui/ui_kit.gd`(**X2가 공용 호버 툴팁 컴포넌트 추가**) + **YA 에셋**(`art/v2/build_assets_y.gd`가 굽는 런타임 PNG 15장 — 마왕 초상 · 상자 6프레임 시트 · 금화 더미 등). 규격 원본은 `docs/ui-style-v3.md`. ⚠️ **미납 2건** — `art/v2/ui-kit-skill-shape.png`(14칸) · `art/v2/ui-kit-rune.png`(15칸) |
| 정보 전달 규약 | **상시 문장은 최소, 상세는 호버 툴팁**(X2·X3). 화면별 글자 수 상한이 테스트 계약이다 — §11 |
| 원소 색 언어 | **단일 진실 원천 = `game.gd`의 `ELEMENT_COLOR` / `_element_color()`**(X1 신설 · Y4가 두 색 교체 — fire `e2452f`(EMBER_RED) · oil `7a5230`(OIL_BROWN)). 레벨업·ESC 편집·필드 HUD·마왕 고스트가 같은 표를 보고, `skill_icon.set_element_palette()`로 아이콘 판까지 배선돼 있다 |
| 저장 스키마 | **schema 4** (스냅샷 54키 · `--save-test` 필수 키 53) · 지문 **72축** · `mismatch=0`. schema 3 이하 스냅샷은 폐기하고 새 런으로 떨어진다 |
| 에셋 라이선스 의무 | `art/external/game-icons/`의 **113 SVG가 CC BY 3.0**이다(작가 9명 — Lorc 68 · Delapouite 31 · Sbed 5 · Skoll 3 · Willdabeast 2 · Felbrigg 1 · DarkZaitzev 1 · Cathelineau 1 · Carl Olsen 1). 크레딧 블록 원본은 `art/external/LICENSES.md` §6. **현재 산출물 중 이 팩에 의존하는 것은 0개다.** ✅ **해소** — `export_presets.cfg`의 `exclude_filter`로 **배포 빌드(pck)에서 제외**했다. 배포하지 않으므로 게임 내 표기 의무가 없다. ⚠️ 저장소 안에는 LICENSES.md 전문과 함께 **보관**한다(보관은 적법) — **파일을 지우지 말 것** |
| 문서 최종 갱신 | 2026-08-10 KST (YZ · 2차 플레이테스트 피드백 라운드 Y0~Y8 · YA · YZ 완료) · **19:10 체크포인트 후속 정정 5자리**(§7.2 · §7.5 · §11 — 상세는 §15 맨 위) |
| 현재 제품 상태 | **v3 + Y 라운드(Y0~Y8 · YA · YZ) 반영 완료 · 3차 플레이테스트 대기 (`ready_for_playtest`)** |
| 단일 실행 진입점 | `godot-game/scenes/main.tscn` → `scripts/game.gd` |

### 가장 중요한 경고

1. **현재 제품은 Godot 프로젝트인 `godot-game/`이다.**
2. 루트의 `src/`, `package.json`, `index.html`은 폐기된 Phaser/Vite 실험본이다. 사용자가 명시적으로 웹 버전을 되살리라고 하지 않는 한 수정하지 않는다.
3. `http://localhost:5173`에서 확인하는 웹게임이 아니다. `godot --path godot-game`으로 별도 게임 창을 연다.
4. Git 저장소에는 빈 초기 커밋만 있고 현재 파일은 사실상 전부 미추적 상태다. Git으로 복구할 수 있다고 가정하지 말고, `reset`, `checkout`, 대량 삭제를 하지 않는다.
5. **파괴적 삭제 전에는 원본을 `docs/v1-archive/`에 복사한다**(설계 부록 A 확정). 이 디렉터리는 코드 복구용이며 `preload` 대상이 아니다. 지우지 않는다.
6. **`godot-game/art/generated/`와 `art/external/`도 지우지 않는다.** 참조만 끊었고 파일은 남겼다. 되돌리려면 `preload` 경로 한 줄이면 된다.
7. **어떤 웨이브도 `git commit`을 하지 않는다.** 사용자가 직접 명령할 때만 커밋한다.

---

## 1. 작업 재개 체크포인트

아래 블록은 **현재 작업 한 건의 상태만** 기록한다. 새로운 작업을 시작하는 AI는 코드 수정 전에 이 블록을 먼저 갱신하고, 작업 도중 의미 있는 단계가 끝날 때마다 다시 갱신한다.

<!-- HANDOFF_CHECKPOINT_START -->

```yaml
status: ready_for_playtest
updated_at: 2026-08-10T19:10:00+09:00
owner: Claude
active_request: "활성 요청 없음. 2026-08-10 2차 플레이테스트 피드백 25건(Y 라운드 · Y0~Y8 + YA + YZ) 반영 완료. 3차 플레이테스트 대기."
last_completed:
  - "Y0(설계 웨이브 · 코드 0줄): 피드백 25건을 docs/FEEDBACK_Y.md 한 문서로 설계 — 과열 폐기와 「한 칸은 한 바퀴에 두 번까지」 대체 규칙 · 각인 15종(칸 10 + 레일 5) 카탈로그 · 속성 한자 폐기와 색 두 개 교체 · 필드 생태/발견/사건/타격감 스펙 · 웨이브 분할표(§9.3)와 리스크 12건"
  - "Y1(데이터 골격 · game.gd 미접촉): rune_engine.gd 전면 재작성 — 과열 심볼 전량 삭제(상수 15 · 함수 4 · 결과 키 다수) · RUNES 24종 → 15종 · SLOT_EXEC_CAP 2 · STEP_CAP 2n+2 · RELOAD 선형화(빚 × reload_scale). deal_card_library.gd 재저작(combo·impact·silhouette 3키 신설 · SILHOUETTES 14 · IMPACTS 8) · monster_library/tuning/status_engine 가산 · rune_test.gd 전면 재작성"
  - "Y2(game.gd 직렬 체인 1/6): 과열 런타임 소비자 제거 + 각인 15종 완결 — 레일 각인 부착 경로(factory_rail_runes 저장 키 신설) · 3택에 레일 각인 혼입 · run_peak_heat → run_peak_steps 개명 · HUD 스트립 380×74 → 358×74(과열 8핍 자리 회수) · RUNE_SHOP_RAIL_PREMIUM 1.20 신설"
  - "Y3(직렬 체인 2/6): 각인 UI 3종 + 밀정 — 각인 부착 2단계 간소화(칸 안 2자+ Label ≤ 7) · ESC 편집에서 각인/스킬 시각 분리 · 밀정 전면 재작성(열람 무료 기본 공개 · 지우기 SPY_WIPE_COST 120 G로 칸 통째 · 스테이지당 1회 spy_wipe_stage) · 캡처에 RenderingServer.force_draw() 삽입(그 전엔 17컷 중 고유 지문 5장뿐이었다)"
  - "Y4(직렬 체인 3/6): 전투 UI · 모달 · 색 — 속성 한자 폐기(RAIL_ELEMENT_MARK 불얼번독기타정) · fire e2452f / oil 7a5230 교체로 일곱 색이 서로 달라짐 · _factory_card_color()가 데이터 color 대신 원소를 봄(스테일 색 11곳 동시 해소) · 마왕 초상 96×96 TextureRect · 결과 화면 SLATE 무대 창 수리 + result-y4-won 신설 · 체력바 세그먼트 12칸 · 금화 그림 · 상자 6프레임 시트 · pixel_portrait.gd 삭제(마지막 무한 애니메이션)"
  - "Y5(직렬 체인 4/6): 필드 생태 — 몹 습성 층(무리·텃세·도망·야행) · 지형 가중 스폰 · 돌 우회 추적 · 물 통행 규칙 · 1·2스테이지 낮 선공 0 · terrain_probe.gd 신설 · --field-test 신설"
  - "Y6(직렬 체인 5/6): 발견 · 사건 · 재미 아이템 — 저장 schema 4 승격(5키 신설: discovered_features · stage_events · run_event_count · consumable_item · night_eye_nights) · 발견 게이팅(DISCOVER_RADIUS 520px 또는 NAV_RING 안) · 랜덤 사건 8종 · 소비 슬롯 Q 1칸 · 보물상자 배당에 체력 7 / 재미 아이템 6 신설(위협 총량 21% → 18%) · --event-test 신설"
  - "Y7(직렬 체인 6/6 · 마지막 콘텐츠 웨이브): 타격감 — 몹별 피격 반응 프로필(enemy.gd 자체 _draw 파편) · impact 8종 + stack_bonus · 카메라 흔들림 계약(SHAKE_MAX_AMPLITUDE 4px · SHAKE_MAX_DURATION 0.12초 · 허용 자리 다섯 · 지운 자리 넷) · --combat-test impact_profile / mob_reaction · --cycle-test cam 4축"
  - "Y8(밸런스 재측정·확정): balance_probe.gd 전면 재작성(12절 · 판정 8축 · pass=1이 회귀 계약) — dwell 곡선(0.13/0.010) · STAGE_HP_BASE [1.00,1.35,1.70,2.05,2.40] · CYCLE_HEALTH_GAIN 0.21 · 물량 4/8/0.04/0.45 · 보스 DESIGN_HP 2,130/2,440/3,180 + BOSS_BASE_HP 1,180 · 목표 창 스테이지 보스 30~60초 / 마왕 60~120초 · 각인 15종 기대 스텝 대조표 · 골드 여유 19.9%(YZ가 필드 상자 스케일을 붙인 뒤 23.7%)"
  - "YA(에셋 수급·제작 · .gd 로직 0줄): art/v2/build_assets_y.gd 신설 · 런타임 PNG 15장(마왕 초상 · 상자 6프레임 · 금화 더미 · 장비 부위 실루엣 등) · 웹 무료 팩 3개 라이선스 정리와 스테이징(game-icons CC BY 크레딧 포함) · 미납 2건(ui-kit-skill-shape 14칸 · ui-kit-rune 15칸)"
  - "YZ(마감 웨이브): 한글 최종 검수 스윕(화면 문자열 1,517개를 훑어 약 180곳 수정 · 금지 어휘 0건 · RELOAD와 G는 고유 이름으로 유지) · 잔여 수리 5건(terrain_probe full 판정식을 전수 통과 → 백분위로 완화 · NIGHT_ENEMY_LIMIT_STEP 삭제 · _build_preview_slot 각인 줄에 어두운 판 + 이름 「하나 + 외 N」 · _build_choice_card_body 장비 태그 줄 겹침 · 필드 상자 골드에 스테이지 스케일) · status_test.gd 실행법 경고 · 모달 부제 밴드 다섯 화면 제거 · 문서 전면 개정(AGENTS.md · README.md · ui-style-v3 §12) · 최종 검증 전종"
  - "X1~X4(2026-08-09 20:40 기준선): 레벨업 모달 대개편 + 각인 경제 이전 · ESC 편집 대간소화와 공용 호버 툴팁 · 필드 HUD 탈블록과 가장자리 화살표 · 길잡이 중 세계 정지와 온보딩 다이어트. 상세는 §15와 docs/handoff-x1..x4.md"
  - "U0~U3(2026-08-09 14:40 기준선): v3 UI 킷 신설 + 로비/온보딩/모달/편집/HUD 재스킨 + 스포트라이트 길잡이 7스텝. 상세는 §15와 docs/handoff-u1..u3.md"
  - "V0~V10(2026-08-09 07:40 기준선): v3 스테이지 개편 전량 — 5스테이지 구조 · 상태이상 5종과 반응 11종 · 보스 3종 로테이션 · 트로피 2택1 · 저장 schema 3 · 밸런스 최종 패스. 상세는 §15와 docs/handoff-v1..v10.md(`v3`은 `handoff-v3-assets.md`)"
in_progress: []
blocked_by: []
next_exact_step:
  - "3차 플레이테스트 피드백 대기 — 관측자가 볼 여덟 가지: ①과열이 사라진 딜싸이클이 이해되는가(「한 칸은 한 바퀴에 두 번까지」 상한이 화면에서 읽히는가) ②각인 15종의 이름과 효과가 한 번에 이해되는가(칸 각인과 레일 각인의 구분이 보이는가) ③속성 일곱 색이 밤·안개에서 서로 갈리는가 ④필드가 살아 있는가(돌 우회 · 물 통행 · 무리 · 도망 · 1·2스테이지 낮 선공 0) ⑤발견 내비와 사건 8종이 갈 길을 만들어 주는가 ⑥타격감이 느껴지는가(몹별 피격 반응 · impact 8종) ⑦스테이지 보스 30~60초 · 마왕 60~120초가 실제 체감과 맞는가 ⑧한글이 전부 자연스럽게 읽히는가"
  - "관측 보조 지표(로그로 바로 나온다): --cycle-test의 hud_block_pct(3.19) · hud_ink_pct(6.39) · cam 4축 / --v4-test의 edit_labels/edit_prose(13 / 0) / --guide-test의 onb_pages·onb_peak·onb_longest / --field-test의 day_aggro_zero · herd_spawn · rock_detour / --event-test의 discover·schedule·items"
  - "피드백을 받으면 active_request를 갱신하고 status를 in_progress로 되돌린다"
  - "밸런스를 다시 만지면 반드시 balance_probe.gd를 먼저 돌린다 — pass=1이 회귀 계약이다(8축). 세 축(STAGE_HP_BASE × H(d) × CYCLE_HEALTH_GAIN)이 곱해지므로 하나만 움직이지 않는다"
  - "롤백 지점은 전부 주석에 있다: boss_library.gd의 DESIGN_HP · tuning.gd의 「이전 값」 주석 3곳 · monster_library.gd의 CYCLE_HEALTH_GAIN"
  - "UI를 다시 만질 때는 docs/ui-style-v3.md §12 체크리스트 + §11의 화면별 글자 수 상한 계약을 먼저 읽는다"
last_verified:
  compile: pass
  world_test: pass
  field_test: pass
  v4_test: pass
  castle_test: pass
  rift_test: pass
  stress_test: pass
  smoke_test: pass
  combat_test: pass
  stage_test: pass
  status_test: pass
  cycle_test: pass
  draft_test: pass
  boss_test: pass
  save_test: pass (schema=4 keys=53 axes=72 mismatch=0 · 스냅샷 자체는 54키다 — 아래 ⚠️)
  guide_test: pass
  event_test: pass
  run_all: pass (17/17 = 컴파일 1 + 기능 16종 · 126초 / 126초 · **2회 연속** · 잔여 Godot 0 확인 후)
  rune_test: pass (catalog_15 · slot_exec_cap · rail_loop_ten · exec_cap_violations=0 · overload_count=0 · cycles=25001)
  data_test: pass (runes=15 · slot_exec_cap=2 · step_cap=12 · no_banned_words · banned_scan_strings=174 · impacts=8)
  rift_probe: pass (failures=0)
  terrain_probe: pass (fast=PASS 40초 / **full=PASS 약 40분** · YZ가 판정식을 백분위로 완화)
  balance_probe: pass=1 (rune_steps·hp_index·dwell_curve·dwell_pressure·volume·gold·boss_ttk·demon_ttk 8축 전부 1)
  captures: pass (전종 재생성 73컷 · shasum 고유 72 = 구조적 중복 1쌍뿐 · 육안 전수)
  live_run_observation: pass (비headless 창 실행 · 13루틴 × 3회 = 39회 · 298초 · SCRIPT ERROR/ERROR/=false 0줄)
```

<!-- HANDOFF_CHECKPOINT_END -->

### 중단된 작업을 이어갈 때

1. 위 체크포인트의 `active_request`, `in_progress`, `next_exact_step`을 읽는다.
2. 체크포인트에 적힌 파일이 실제로 존재하는지 `rg --files`로 확인한다.
3. 마지막으로 실패한 테스트가 있으면 그 테스트부터 다시 실행한다.
4. 이미 완료됐다고 기록된 기능을 처음부터 재작성하지 않는다.
5. 코드와 체크포인트가 다르면 **코드를 사실로 간주**하고 이 문서를 바로잡는다.
6. 사용자 지시가 이전 요청을 대체했다면 기존 작업을 억지로 마무리하지 말고 체크포인트를 새 요청으로 교체한다.

---

## 2. 비개발자를 위한 30초 실행 순서

### 터미널에서 실행

```bash
cd /Users/moomi/orca/projects/NHN
godot --path godot-game
```

Godot 게임 창이 별도로 열리면 성공이다. 브라우저 주소는 사용하지 않는다.

### Godot 편집기에서 실행

1. Godot을 연다.
2. `Import`를 누른다.
3. `/Users/moomi/orca/projects/NHN/godot-game/project.godot`을 선택한다.
4. 오른쪽 위 재생 버튼을 누른다.

### 작업 전 최소 안전 확인

```bash
cd /Users/moomi/orca/projects/NHN
git status --short
godot --headless --path godot-game --editor --quit          # 컴파일·리소스 검사
bash godot-game/scripts/test/run_all.sh                     # 컴파일 1 + 기능 검사 16종
```

`git status`에서 대부분 `??`로 나오는 것이 현재 상태다. 기존 파일은 사용자 작업물이므로 임의로 삭제하지 않는다.

### 특정 화면만 열어 보기

```bash
godot --path godot-game -- --preview-boss        # 마왕 프리뷰
godot --path godot-game -- --preview-build       # ESC 편집 화면
godot --path godot-game -- --preview-rift        # 균열 아레나
godot --path godot-game -- --preview-onboarding  # 온보딩 4페이지
```

`--preview-*`는 창을 띄운 채 그 화면에서 멈춘다(헤드리스 아님). 전체 목록은 §11.

---

## 3. 게임을 한 문장으로 설명하면

**다섯 관문을 차례로 부수고 마왕에게 닿는 실시간 액션 로그라이크다.** 5칸짜리
딜싸이클 레일 위를 바늘이 돌며 카드를 실행하는데, 칸에 붙인 **각인**이 확률로 바늘을
되감고 건너뛰고 재실행시켜 매 사이클의 궤적을 바꾼다. 카드에는 **원소**가 있어서
5칸에 놓는 **순서 자체가 콤보**가 된다(기름을 칠하고 불을 붙인다). 기한은 없지만
한 스테이지에 오래 머물수록 마물이 무한히 강해지고 보상은 제곱근으로만 늘어난다.
성장할 때마다 두 장 중 하나만 고를 수 있고, **고르지 않은 카드는 전부 마왕의 다섯 칸이 된다.**

### 절대 바뀌면 안 되는 현재 핵심 정체성 (사용자 확정)

이 10개는 사용자가 명시적으로 확정했다. 바꾸려면 **사용자에게 먼저 묻는다.**

1. **총 5스테이지.** 스테이지 하나 = 무한 WFC 필드 + **성 1 + 베이스캠프 1 + 보스방 1**.
   파밍하다가 준비됐다고 판단하면 보스방에 들어간다. 캠프는 보스문에서 플레이어 쪽으로
   520px에 있어 **반드시 보스문보다 먼저 만난다**(성과 같은 정비 공간 + 스테이지당 완전회복 1회).
2. **보스 3종 로테이션 `[A, B, C, B+, C+]`.** A 서릿발 외눈(빙+뇌) · B 역병 점액왕(독) ·
   C 홍염 천구(화+유). 4·5스테이지는 B·C의 강화형이다. **5스테이지 보스를 잡으면
   필드를 거치지 않고 그 자리에서 마왕전이 열린다.**
3. **기한이 없다. 대신 체류 압박이 있다.** 총 일수는 **기록용 카운터**이고 승리 등급만
   그 값을 본다. 압박은 dwell(현 스테이지에서 완료한 낮/밤 주기 수) 하나가 만든다 —
   몹 HP는 `1 + 0.13d + 0.010d²`로 무한히 오르는데 경험치는 그 **제곱근**으로만 오른다.
   `d=12`에서 킬당 효율 0.500 = 같은 성장에 시간 두 배다. **이 한 곡선이 v3의 성패다.**
   *(Y8이 계수를 0.14/0.012에서 실측 재확정했다 — §7.5.)*
4. **5칸 고정 · 무스크롤.** 딜싸이클 레일은 5칸이고 **런 시작부터 5칸이 전부 열려 있다.**
   가로 스크롤은 **구조적으로 불가능**해야 한다(`ScrollContainer`를 아예 만들지 않는다).
   `--v4-test`의 `initial5`·`edit_layout`과 `--cycle-test`의 `hud_rail`이 자동 감시한다.
5. **각인은 칸에 붙는다.** 카드가 아니라 칸(slot)이 각인 스택을 소유한다.
   한 칸 중복 강화가 가능하되 4겹 감쇠(스택 상한 5 · 같은 id 3 · 중복 확률 0.55^k ·
   과밀 0.80^초과수)로 몰빵이 유일 정답이 되지 않는다. 칸을 통째로 교환하면 각인이 함께 간다.
   **Y 라운드부터 각인은 15종이고 그중 5종은 칸이 아니라 레일 전체에 붙는다**(§7.3).
6. **미선택 카드는 마왕에게 간다.** 레벨업에서 버린 스킬 카드 1장, 아이템 2택1의 버린 쪽,
   **보스 트로피 2택1의 버린 쪽**, 각인 드래프트의 미선택 조각, 저주 상자 — 전부 마왕을
   키운다. 마왕은 받은 카드를 자동 합성해 화력 상위 5장을 자기 레일에 올리고,
   **나머지는 잔재가 되어 필드 몹의 모듈로 뿌려진다.**
   ⚠️ **예외가 하나 있다(X1 · 사용자 확정).** 레벨업 **취소**는 두 카드를 **소멸**시키고
   마왕에게 **아무것도 주지 않는다**(`rejected_skills` 무접촉). 그 대신 골드를 준다.
   취소 파밍으로 마왕이 5칸을 못 채우는 사고는 `DEMON_MIN_CARDS_PER_STAGE = 4` 하한이 막는다.
7. **원소 시너지가 전투의 문법이다.** 7계(불·얼음·번개·독·기름 + 비원소 타격·정신)와
   상태 5종(독·연·한·유·전). 5칸의 **순서**가 조합기다 — 기름을 칠하고 불을 붙이면
   대폭 연소(맨 불의 7.5배), 얼린 적에게 번개를 꽂으면 전도(최대 4체 전이).
   비원소 2종은 상태를 만들지 않고 **거둬들이므로** 자연히 마무리 칸에 놓인다.
   ⚠️ **표시 이름의 한자는 Y4가 폐기했다** — 화·빙·뇌·유·초로 쓰지 않는다(§7.4).
8. **전면 판타지 어휘.** v2의 직장 풍자 카드명 30여 종은 전부 판타지로 갈았다.
   **`id`는 한 글자도 바꾸지 않았다** — 바꾸는 것은 `name` 키뿐이다(저장 호환).
9. **트윈 루프 애니메이션 금지.** 온보딩·HUD·모달·이펙트 어디에도 무한 반복 트윈을
   넣지 않는다. 모든 강조는 `delta`로 감쇠하는 float다(사용자 명시 요구).
   **1회성 전환 트윈은 허용**된다(U0~U3 확정 · 길잡이 스크림 페이드 2개가 그 예).
   실제 계약은 `set_loops()`가 **프로젝트 전체 0건**이라는 것이다.
10. 전투는 보유 스킬이 동시에 터지는 방식이 아니다. **바늘이 있는 칸만** 실행된다.
    **빈 칸은 빈 행동이 아니라 기본 베기**이되 태그가 없어 **공명**에 기여하지 않는다.
    *(결속·삼각은 Y 라운드가 삭제했다 — 남은 태그 상호작용은 공명 하나뿐이다.)*
    현재는 검사만 고를 수 있고 궁사·마법사 카드는 「준비 중」으로 잠겨 있다.

---

## 4. 사용자 조작과 화면 흐름

### 조작

| 입력 | 동작 |
|---|---|
| `WASD` / 방향키 | 이동 및 바라보는 방향 변경 |
| `Shift` | 대시. 기본 쿨타임 10초, 약 0.14초 동안 빠르게 이동하며 피격 무효 |
| `E` | 성 · 캠프 · 보스문 · 보물상자 · 균열 · **사건 자리** 앞에서 상호작용. 문자 키와 물리 키 위치를 모두 검사 |
| **`Q`** | **소비 아이템 1개 사용**(Y6 신설 · `state == "playing"`에서만 · `_use_consumable()`). 문자 키와 물리 키 위치를 모두 검사 |
| `Esc` | **5칸 편집 화면** 열기/닫기. 길잡이 중에는 뜻이 다르다 — 아래 표 |
| `Tab` | 편집 화면에서 레일 ↔ 보관함 포커스 전환 |
| 방향키 | 모달 선택지 이동, 편집 화면 칸 이동 |
| `Space` / `Enter` | 선택 확정 (보스 프리뷰에서는 전투 시작). 편집 화면에서는 **카드만** 집기. 길잡이 중에는 "다음" — 아래 표 |
| `Shift` + `Space` | 편집 화면에서 **칸 통째**(카드 + 각인) 집기 |
| 마우스 드래그 | 레일·보관함·장비 사이 이동. **모드가 없다** — 카드 몸통을 끌면 카드만(`move_card`), 칸 손잡이를 끌면 칸 통째(`swap_slots`). 페이로드의 `gesture` 키가 둘을 가르고, 집는 순간 고스트 그림이 달라진다 |
| **마우스 호버** | **상세 정보의 기본 창구다**(X2·X3). 필드 HUD 툴팁 16종(Y6이 발견 화살표 1종·소비 슬롯 1종을 더했다) · ESC 편집 화면 호버 대상 27+개. 지연 0.25초. 키보드 포커스에서도 **같은 툴팁이 뜬다** |

⚠️ **편집 화면의 「카드 이동 모드」·「칸 교환 모드」와 `M`·`1`·`2` 키는 X2가 삭제했다.**
개념 자체가 없어졌으므로 문서·온보딩·툴팁 어디에도 다시 쓰지 않는다.
지금 규약은 "무엇을 집었는가가 조작을 정한다" 하나뿐이다.

#### 스포트라이트 길잡이가 도는 동안의 키 계약 (U3 · `guide_active == true`)

| 입력 | 동작 |
|---|---|
| `SPACE` | **다음** — 지금 스텝을 개별 건너뛰기. "보여 주는" 스텝은 통과로 기록하고, "시키는" 스텝(이동·대시)은 기록을 남기지 않는다 |
| `ESC` | **확인 칩**을 띄운다. 여기서 한 번 더 `ESC` = 길잡이 **전체 스킵** / `SPACE` = 계속 |
| `WASD` · `Shift` · `E` | 평소대로 살아 있다. 해당 스텝의 통과 조건이면 그 입력이 스텝을 넘기면서 **키를 그대로 흘려 보낸다**(실제 이동·대시·상호작용이 함께 일어난다) |

⚠️ **길잡이 ①~⑥ 동안에는 `ESC`로 편집 화면을 열 수 없다**(확인 칩이 먼저 잡는다).
마지막 ⑦스텝의 `ESC`만 길잡이를 끝내면서 편집 화면을 연다. 7스텝 약 40초짜리 잠금이다.

#### 길잡이가 도는 동안 **세계는 멈춰 있다** (X4 · 사용자 피드백 ②)

`get_tree().paused`가 **아니다** — 스텝 ①②는 플레이어가 실제로 걷고 대시해야 넘어가고,
Godot 4의 트리 일시정지는 물리 서버까지 세운다. 그래서 **선택 동결**이 두 층으로 있다.

| 층 | 무엇 | 어디 |
|---|---|---|
| **시간축** | `world_running := not (guide_active and state == "playing")` 게이트 하나 | `_process()` |
| **노드축** | 필드 잡몹·적 탄환 **전량 제거** 후, 그 뒤 생기는 적은 `set_physics_process(false)` | `_guide_clear_threats()` · `_guide_freeze_sweep()`(0.25초마다 재적용) |

- **멈추는 것**: `elapsed_time`(런 시계) · `clock.tick()`(낮밤·dwell) · 강림 밸브 폴링 ·
  `combat.tick_population()`(스폰) · `_check_rifts()` · 잠식 스윕 · `_tick_player_status()`(도트).
- **계속 도는 것**: 플레이어 물리(스텝 ①②의 통과 조건) · **딜싸이클**(스텝 ③ "공격 버튼이
  없습니다"를 눈으로 증명하는 유일한 수단 — 필드에 적이 0기라 아무 일도 안 일어난다) ·
  `_refresh_interactable()`(스텝 ⑥이 `E`를 시킨다) · HUD·화살표·조명 보간(그림이다).
- 게이트를 `state == "playing"`으로 좁힌 이유: 보스방에서 `guide_active`만 보고 얼리면
  **보스 패턴이 붙인 도트가 안 도는 유령 상태**가 만들어진다.
- 안내판 힌트 줄이 매 스텝 **「세계가 멈춰 있습니다」**를 말한다. 그림만으로는
  "적이 없다"와 "적이 멈췄다"를 구별할 수 없기 때문이다.
- 끝나면 `_guide_unfreeze_all()`이 **얼린 목록만** 정확히 되돌리고,
  `combat.spawn_timer = min(현재, 1.2)`로 필드가 **한 기씩** 상한까지 다시 찬다.
- ⚠️ **적이 아닌 새 위협(함정·환경 피해·낙하물)을 만들면 `_guide_freeze_sweep()`에 그 노드
  종류를 더해야 한다.** 지금 이 함수가 아는 것은 `DebtEnemy`와 `EnemyBullet` 둘뿐이다.

### 플레이 화면 흐름

```text
로비(menu)
  ├─ 게임 시작 → 캐릭터 선택 → 온보딩 4페이지 → 1스테이지 필드
  │    └─ 첫 낮 스포트라이트 길잡이 7스텝 (**최초 1회** · 설정의 「온보딩 다시 표시」로 초기화 가능)
  │       이동 → 대시 → 5칸 레일 → 게이지 → 고스트 레일 → **가장자리 화살표** → ESC 편집 화면
  │       · 도는 동안 **세계가 멈춘다**(잡몹 0기 · 클럭 정지 · 무적) — 위 표
  │       · 이어하기는 열지 않는다. 로비로 돌아가면 본 것으로 치지 않는다
  ├─ 이어하기 → 저장된 런 복원(schema 4) → 그 스테이지 필드
  │    · 버튼 문구가 "이어하기 · 3스테이지 잿빛 벌판 · 11일차 · 08:32"까지 보여 준다
  └─ 설정 → 음량/화면 흔들림/피해 숫자/전체화면/「온보딩 다시 표시」
       · 「온보딩 다시 표시」는 온보딩 4페이지와 **필드 길잡이를 함께** 되살린다

필드(playing) — 스테이지마다 낮/밤 길이가 다르다(1st 72/45초 … 5st 48/78초)
  ├─ 레벨업 → **카드 2택 + 취소** (choice · X1 개편)
  │    ├─ 스킬 카드 A · B 중 하나 → 즉시 배치(factory_place). 버린 한 장은 마왕에게
  │    └─ 「취소 +N G」 → **두 카드 모두 소멸 · 마왕 무이득** · 골드를 받고 레벨은 정상 상승
  │    · 카드는 그림이 주역이다 — 아이콘 152px · 속성은 색 · 읽을 문장 4줄(이름·설명·칩2)
  │    · 레일 5칸이 전부 R3이고 보관함도 포화해도(**성장 천장**) 화면은 그대로 2택으로
  │      열린다. 기본 포커스만 **취소**이고 보상이 ×1.5 할증된다(자동 전환 폐기 · X1)
  ├─ 보물상자 E → 경험/스킬/아이템/**각인 드래프트 14%**/저주/함정/미믹/**체력 7%**/**재미 아이템 6%**
  ├─ **발견·사건**(Y6) → 발견 반경 520px 또는 화면 링 안에 들면 자리가 열리고,
  │    스테이지마다 사건 8종이 예산 안에서 깔린다. 소비 아이템은 `Q` 슬롯 1칸
  ├─ 성 E → 페이드 → 성 내부(castle_interior) → NPC 4종(camp) → 필드
  │    · 카드 상점 · **각인 세공사(카드 3장 · 칸/레일 랜덤)** · 계약자(**dwell 거래**) · 밀정(마왕 정보)
  │    · 상점가는 스테이지마다 오른다(×1.00 → ×2.00)
  ├─ 베이스캠프 E → 성과 같은 정비 공간 + **스테이지당 완전회복 1회**
  ├─ 균열(dwell 1·3) → 접근 시 정예 3~5기 → 전멸 → 각인 드래프트 + 60 G
  ├─ 밤(dwell 2부터) → 전조 1기 = 마왕의 한 칸을 시연 → 격파 시 각인 뜯기 / 카드 회수
  ├─ 잠식(dwell이 스테이지 임계 4/4/3/3/2에 닿으면) → 모든 필드 몹이 마왕의 잔재 +
  │    각인 1개를 들고 나온다. **스테이지를 클리어하면 풀린다**
  ├─ 강림 밸브(dwell 14/13/12/11/10) → 보스가 **프리뷰 없이** 필드로 내려온다.
  │    칸 +1 · HP ×1.15 · 승리 등급 C 고정. 정상 플레이는 절대 닿지 않는다
  └─ 보스문 E → 보스 프리뷰(boss_preview, ESC로 취소 가능) → 보스방 전투(boss)
       ├─ 격파 → **트로피 2택1**(고정 스탯 1개 + 특별 카드 2택1, 버린 쪽은 마왕에게)
       │    → 배치 → 다음 스테이지(dwell은 절반으로 감쇠해 이월된다)
       └─ 5스테이지 격파 → 필드 복귀 0프레임 → **마왕전 직행** → 결과(won)
```

### `game.gd`의 주요 상태 문자열

| 상태 | 의미 | 일시정지 |
|---|---|---|
| `menu` | 로비 | — |
| `character_select` | 캐릭터 선택 | — |
| `settings` | 설정 | — |
| `onboarding` | 4페이지 게임 설명(정적 도식 · ④가 원소 시너지) | — |
| `playing` | 일반 필드 플레이. **시간이 흐르는 유일한 상태** · 서브모드 `guide_active` ¹ | 아니오 |
| `choice` | 레벨업 스킬 2택1 **+ 취소(골드)** — 각인 강화 선택지는 X1이 삭제했다 | 예 |
| `rune_draft` | 각인 3택1 (1단계). 진입 경로는 **보물상자·균열·전조·각인 세공사 구매**다 | 예 |
| `rune_target` | 각인을 붙일 칸 선택 (2단계) | 예 |
| `factory_menu` | ESC 5칸 편집 화면 (**조작 모드 없음** · 호버 툴팁) | 예 |
| `factory_place` | 새 카드 즉시 배치 | 예 |
| `item_choice` | 아이템 2택1. 선택은 장비/보관함, 미선택은 마왕에게 | 예 |
| `castle_interior` | 성·캠프 내부 이동 | 아니오(시간은 정지) |
| `camp` | NPC 서비스 모달 | 예 |
| `advancement_choice` | **보스 트로피 2택1**(v2 각성 특별 카드 화면을 그대로 재사용) | 예 |
| `omen_reward` | 전조 격파 보상 2택1 | 예 |
| `boss_preview` | 보스 칸 공개 · **취소 가능**(스테이지 보스 · 마왕 공용) | 예 |
| `boss` | 보스방 전투 · 마왕 전투 | 아니오(시간은 정지) |
| `won` / `lost` | 결과 화면. **같은 화면을 두 문자열이 쓴다**(`state = "won" if won else "lost"`) — "결과 화면인가"를 `state == "won"`으로만 묻지 말 것 | 예 |

¹ **`guide_active == true`면 스포트라이트 길잡이 서브모드다**(U3). 새 `state`는 만들지 않았다.
X4부터 이 플래그는 **서브모드이자 시간 정지 스위치**다 — 필드 잡몹이 전량 걷히고, 잔여 적은
물리가 꺼지고, 클럭·체류·스폰·균열·도트·런 시계가 **`world_running` 게이트로 멎는다**.
무적은 그대로 유지되고 **자동 저장은 쉰다**(`_run_save_blocked_reason() == "guide"`).
⚠️ **`_process()`의 `playing` 구역에 새 틱을 넣는 웨이브는 `world_running`을 먼저 볼 것.**
기본값은 "길잡이 중에도 돈다"이므로, 세계 시간에 속하는 것이면 게이트 안에 넣어야 한다.
강림 보스와 **같은 종류의 함정**이니 `state == "playing"`만으로 "평범한 필드"를 판정하지 말 것.

⚠️ **v2의 `lineage_choice` · `evolution` 두 상태는 삭제됐다**(계보 폐기). 되살리지 말 것.

⚠️ **강림한 스테이지 보스는 `state`가 `"playing"` 그대로다.** 필드 사건이기 때문이다.
"지금 보스전인가"를 `state == "boss"`로만 판정하면 강림을 놓친다 —
공개 창구 `stage_boss_active()`를 쓸 것.

새 모달이나 화면을 추가한다면 `state`, 일시정지 여부, 돌아갈 상태, 그리고
**복귀 시 유예 무적**(`GameTuning.MODAL_RETURN_INVULN`)을 함께 정의해야 한다.

---

## 5. 저장소 구조와 무엇을 어디서 수정하는가

### 최상위 구조

```text
NHN/
├─ AGENTS.md                 ← 이 파일. 단일 인수인계 원본
├─ README.md                 ← 사람용 실행 안내
├─ docs/
│  ├─ GAME_DESIGN_V3.md      ← **현행 설계 원본. 부록 A = 확정 결정(본문보다 우선)**
│  ├─ ui-style-v3.md         ← **UI 스타일의 단일 진실 원천(U0). 킷 규격·톤·폰트·체크리스트**
│  ├─ handoff-v1..v10.md(`v3`은 `handoff-v3-assets.md`)     ← v3 웨이브별 상세 인수인계
│  ├─ handoff-u1..u3.md      ← UI 재스킨 시리즈 상세 인수인계
│  ├─ handoff-x1..x4.md      ← 1차 플레이테스트 피드백 라운드 상세(레벨업·편집·HUD·길잡이/온보딩)
│  ├─ FEEDBACK_Y.md          ← **Y 라운드 설계 원본**(2차 플레이테스트 피드백 25건)
│  ├─ handoff-y1..y8.md      ← **Y 라운드 웨이브별 상세**(규칙·각인·UI·색·필드·사건·타격감·밸런스)
│  ├─ handoff-ya.md          ← **Y 라운드 에셋 수급·제작**(빌더 · 라이선스)
│  ├─ GAME_DESIGN_V2.md      ← v2 설계(폐기, 기록 보존)
│  ├─ handoff-w1..w11.md(`w3`은 없다)     ← v2 웨이브 기록(보존)
│  ├─ GAME_DESIGN.md         ← v1 설계(폐기, 기록 보존)
│  └─ v1-archive/            ← 파괴적 재작성 전 원본 보존. preload 대상 아님
├─ godot-game/               ← 현재 실제 제품
│  ├─ project.godot
│  ├─ scenes/main.tscn       ← game.gd 하나를 붙이는 최소 진입 씬
│  ├─ scripts/
│  │  ├─ core/               ← 규칙 계층(게임 노드를 모른다) — 6종
│  │  ├─ ui/                 ← **UI 킷 헬퍼(`ui_kit.gd`) — 스타일박스의 유일한 창구**
│  │  ├─ test/               ← 자동 검사 하네스
│  │  └─ *.gd                ← 게임 노드와 라이브러리
│  └─ art/
│     ├─ v2/                 ← 현재 런타임 스프라이트 + build_assets.gd + ASSET_MAP.md
│     │                        + **`ui-kit-*.png` 10장 + build_assets_ui.gd**(U0)
│     │                        + **build_assets_y.gd + 런타임 PNG 15장**(YA)
│     ├─ generated/          ← v1 생성 에셋(아이콘 아틀라스는 계속 사용)
│     ├─ external/           ← 원본 에셋 팩과 LICENSES.md · INVENTORY.md
│     │                        (**`game-icons/` 113 SVG는 CC BY 3.0** — §0·§12)
│     └─ screenshots/qa/     ← 시각 캡처 산출물 73컷(§11) · 고아 `.import` 10개
└─ src/, package.json, ...   ← 폐기된 Phaser/Vite 프로토타입
```

### 핵심 코드 지도

**계층 규칙**: `scripts/core/`는 규칙만 안다(노드·UI를 모른다). `scripts/*.gd`는 노드다.
`game.gd`는 조립과 화면을 소유한다. 규칙을 `game.gd`에 다시 심지 않는다.
표면(스타일박스·색·폰트)은 `scripts/ui/ui_kit.gd`가 전부 소유한다 — §13을 볼 것.

| 파일 | 줄 | 책임 | 이 파일을 수정할 때 |
|---|---:|---|---|
| `scripts/core/tuning.gd` (`GameTuning`) | 829 | **모든 게임 밸런스 상수의 단일 소유자.** 스테이지 구조·dwell 곡선·상태이상 5종·시너지 계수·보스 계수·그래픽 그레이드 + **X1 경제 블록**(취소 보상·각인 세공사 가격·마왕 카드 하한) + **Y 블록**(레일 각인 할증·밀정·발견/사건·카메라 흔들림) | 밸런스 숫자는 **여기 아니면 라이브러리**에서만 고친다. ⚠️ 「이전 값」 주석 3곳이 Y8의 롤백 지점이다 |
| `scripts/core/rune_engine.gd` (`RuneEngine`) | 970 | **각인 15종 카탈로그(칸 10 + 레일 5)**, `simulate_cycle()`(궤적·**밟은 횟수 `slot_exec`**·빚·L1 반응의 **단일 진실 원천**), 원소 7계 목록. **과열 심볼은 전량 삭제됐다** | 각인 규칙·흐름 상수 변경 시. 게임 노드를 절대 참조하지 않는다 |
| `scripts/core/status_engine.gd` (`StatusEngine`) | 822 | **상태이상 5종 + 반응 매트릭스 11종의 순수 규칙.** 상태는 적 1기당 float 11칸 | 상태·시너지 규칙 변경 시. 숫자는 여기 심지 말고 `tuning.gd`에서 읽는다 |
| `scripts/core/stage_clock.gd` (`StageClock`) | 579 | 스테이지 축(1~5) · dwell · 낮/밤 · 총 일수(상한 없음) · dwell 곡선 static 함수 전량 | 시간·체류 압박 구조 변경 시 |
| `scripts/core/demon_lord.gd` (`DemonLord`) | 422 | 마왕 성장 상태(각인 부여 기록·조각·뜯김·회수), 5칸 구성, HP 배율 공식. ⚠️ `set_rune_catalog()`는 **`ids_by_scope("slot")`만** 받는다 — 마왕은 레일 각인을 갖지 않는다 | 마왕 성장 규칙 변경 시 |
| `scripts/core/combat_resolver.gd` (`CombatResolver`) | 1,237 | 전투 판정, 적 공간 해시, 스폰 물량, 스테이지 배율 적용, **`_cycle_damage_value()` = 딜싸이클 피해의 유일한 계산 지점**, 상태 부여 순서 | 타격 판정·스폰·상태 적용 순서 변경 시 |
| `scripts/factory_deck.gd` (`FactoryDeck`) | 541 | 5칸 덱, 칸별 각인 스택, **레일 각인 목록**, 장비 4부위, `rune_deck()`(엔진 입력 생성), 합성 | 덱 규칙의 단일 핵심 |
| `scripts/deal_cycle_controller.gd` (`DealCycleController`) | 416 | 엔진이 만든 `steps[]`를 프레임에 펼치는 바늘 런타임. 시드 결정성 | 사이클 실행 타이밍 변경 시. **여기서 `randf()`를 부르지 말 것** |
| `scripts/ui/ui_kit.gd` (`UIKit`) | 655 | **v3 UI 킷의 유일한 창구** — 톤 7종·역할 5종의 9-slice 스타일박스(`panel_box`/`button_box`/`card_box`/`ribbon_box`), 글자색, 키캡 26·포인터·글리프·게이지·스포트라이트 마스크 + **§6 공용 호버 툴팁**(`make_tooltip_layer`/`attach_tooltip`/`tooltip_focus`/`tooltip_force`/`tooltip_hide`/`tooltip_shown` · X2 신설) | 표면 규격 변경 시. **규격 원본은 `docs/ui-style-v3.md`** — 킷을 고치면 그 문서를 같이 고친다 |
| `scripts/game.gd` (`GameMain`) | 15,969 | 조립·UI·상태 전환·모달 전부·성/상점/트로피·스테이지 전이·보스방 전투·마왕전·저장·**스포트라이트 길잡이(세계 동결 포함)**·**원소 색표 `ELEMENT_COLOR`**·**가장자리 화살표 내비**·**HUD/편집 툴팁 배선**·**발견/사건/소비 슬롯**·**카메라 흔들림** | 1.6만 줄 중심 파일. 작은 변경도 소유권 표와 테스트를 확인 |
| `scripts/factory_drag_button.gd` | 124 | 편집 화면 드래그 버튼. 페이로드 `gesture` · 고스트 소스 · **드롭 후보 하이라이트**(`drop_hint` · X2) | 편집 화면 드래그 UX 변경 시 |
| `scripts/player.gd` (`SurvivorPlayer`) | 762 | 입력, 이동, 대시, 체력/보호막, 능력치, 트로피 효과, 스프라이트 렌더 | 조작감·체력·대시·스탯 변경 시 |
| `scripts/enemy.gd` (`DebtEnemy`) | 1,471 | 마물 4행동, 밤 변이, 피격/넉백, 정예·전조, 상태 핍, **마왕과 스테이지 보스 6시트** + **Y5 습성 층**(무리·텃세·도망·야행·돌 우회) + **Y7 반응 프로필**(몹별 피격 파편을 자기 `_draw()`에서 그린다) | 마물 AI·타격감·보스 행동 변경 시 |
| `scripts/boss_library.gd` (`BossLibrary`) | 497 | **보스 3종의 패턴 10종 · 스프라이트 리그 5벌 · `DESIGN_HP`(Y8 실측 확정 · 이전 값이 주석에 있다)**. `"uses_heat"` 데이터 키는 삭제됐다 | 보스 패턴·체력 변경 시. 반드시 `balance_probe`를 다시 돌린다 |
| `scripts/trophy_library.gd` (`TrophyLibrary`) | 201 | **보스 트로피 5종 배분 + 특별 카드 12종 2택1 표**(v2 `class_library` 대체) | 트로피 효과·배분 변경 시 |
| `scripts/cycle_skill_effect.gd` | 368 | 실행 중인 카드의 VFX와 타격 펄스 호출 | 스킬 모션·범위·타이밍 변경 시 |
| `scripts/deal_card_library.gd` (`DealCardLibrary`) | 645 | 스킬 **28종**(전부 드래프트 풀 · legacy **0**) + 특별 12종, **원소 7계 배치**, 랭크 공식(R3 상한) + **Y1 신설 키 3종 `combo`·`impact`·`silhouette`** · `SILHOUETTES` 14종 · `IMPACTS` 8종 | 스킬 밸런스·새 카드 |
| `scripts/item_library.gd` (`ItemLibrary`) | 231 | 아이템 57종. **레일이 아니라 장비 4부위**(무기·목걸이·반지·팔찌) | 장비 밸런스·가격 |
| `scripts/monster_library.gd` (`MonsterLibrary`) | 722 | 몬스터 10종, **스테이지 티어 T1~T4**, 낮/밤 가중치, **Y5 습성 데이터**, `CYCLE_HEALTH_GAIN`(이전 값 주석 = 롤백 지점) | 몬스터 구성·체력 곡선 |
| `scripts/world_grid.gd` (`WorldGrid`) | 1,002 | 지형 렌더, 이동 가능 판정, **스테이지 랜드마크 3종**(성·캠프·보스문), 동적 균열, 아틀라스 3벌, **Y5 지형 규칙**(돌·물) | 월드 콘텐츠 |
| `scripts/wfc_chunk_generator.gd` | 632 | Simple Tiled WFC 청크 생성, 결정적 시드, 캐시 | 맵 생성 알고리즘 |
| `scripts/castle_interior.gd` | 153 | 성·캠프 실내, 출구, NPC 4종 배치와 시각화 | 성 내부 동선 |
| `scripts/chest_open_effect.gd` | 51 | 보물상자 열기 연출. **Y4가 6프레임 시트 재생으로 전면 재작성했다**(원본 `docs/v1-archive/chest_open_effect_y4.gd.txt`) | 상자 연출 |
| `scripts/skill_icon.gd` / `generated_ui_icon.gd` | 572 / 141 | 아이콘 아틀라스 표시 + **Y4 `_reskin_to_element`**(아이콘 판 색이 원소색을 따라온다 · 배선은 `game.gd _ready()`의 `SKILL_ICON_SCRIPT.set_element_palette(ELEMENT_COLOR)` 한 줄) | 아이콘 매핑 |
| `scripts/test/test_runner.gd` (`TestRunner`) | 8,382 | **기능 검사 16종** · 프리뷰 14종 · 시각 캡처 15종 하네스 + **화면 계약 자(尺)** — `_hud_coverage()`(점유율) · `_onboarding_census()`(온보딩 글자 수) · 편집 화면 라벨 세기 | 새 검사 추가 시(§11) |
| `scripts/test/run_all.sh` | 336 | 셸 진입점. 종료 코드 0/1로 종합 판정 | 검사 목록 추가 시 |
| `scripts/test/balance_probe.gd` | 1,606 | **밸런스 근거 계산기 — Y8이 전면 재작성했다.** 12절 구성 · 판정 **8축**(`rune_steps` `hp_index` `dwell_curve` `dwell_pressure` `volume` `gold` `boss_ttk` `demon_ttk`) | 밸런스 조정 전에 먼저 돌린다. **`pass=1`이 회귀 계약이다** |
| `scripts/test/rune_test.gd` / `data_test.gd` / `status_test.gd` / `rift_probe.gd` / `terrain_probe.gd` | 1,473 / 1,481 / 749 / 452 / 245 | 독립 실행 프로브(`-s`로 직접 실행). **`terrain_probe.gd`는 Y5 신설** | 규칙/데이터/상태/배치/지형 회귀 |

⚠️ **V10이 삭제한 파일 2개** — 되살리지 말 것.
`scripts/class_library.gd`(계보 3종 → `trophy_library.gd`가 대체) ·
`scripts/core/deadline_clock.gd`(7일 기한 클럭 → `stage_clock.gd`가 대체).
둘 다 마지막에는 로직이 0줄인 호환 껍데기였고 참조가 사라져 지웠다.
원본은 `docs/v1-archive/`에 있다.

⚠️ **Y4가 삭제한 파일 1개** — `scripts/pixel_portrait.gd`(+ `.uid`).
원본은 `docs/v1-archive/pixel_portrait_y4.gd.txt`에 있다.
**`PORTRAIT_SCRIPT`라는 이름을 다시 쓰지 말 것.** 이것이 프로젝트에 남아 있던
**마지막 무한 애니메이션**이었다(`sin(elapsed * 8.0)` 상시 점멸 — 정체성 #9 위반).
마왕 초상은 이제 `portrait-demon-lord-48.png`를 2배(96×96)로 띄우는 `TextureRect`다.

### 데이터 변경의 우선순위

밸런스 값을 바꿀 때 `game.gd`나 `enemy.gd`에 새 숫자를 흩뿌리지 않는다.

1. 전역 밸런스(스테이지 구조·dwell 곡선·상태이상·시너지 계수·보스 계수·상점가
   **+ X1 경제 3축: 취소 보상 · 각인 세공사 가격/새로고침 · 마왕 카드 하한**):
   `scripts/core/tuning.gd` — X1 축은 `# X1 —` 블록 한 곳에 근거와 함께 모여 있고
   **셋이 한 경제라 하나만 움직이지 않는다**
2. 흐름 엔진 상수(밟은 횟수 상한·감쇠·확률 상한): `scripts/core/rune_engine.gd` 상단
3. 스킬: `deal_card_library.gd`
4. 아이템/가격/레어도: `item_library.gd`
5. 몬스터/출현 가중치/체력/스테이지 티어: `monster_library.gd`
6. **보스 패턴·기저 체력**: `boss_library.gd`
7. **트로피 효과·2택1 배분**: `trophy_library.gd`
8. 드래프트 확률·미리보기 표본: `game.gd`의 `RUNE_DRAFT_*` 6상수 + `EDIT_PREVIEW_SAMPLES`

**조정 전에 반드시** `godot --headless --path godot-game -s res://scripts/test/balance_probe.gd`를
돌려 근거 수치를 확보한다. 감으로 고치지 않는다. 마지막 줄의 **`pass=1`이 회귀 계약**이다.

---

## 6. 핵심 런타임 데이터 흐름

### 딜싸이클 한 바퀴가 실행되는 과정

```text
DealCycleController._plan_cycle()
  → factory.rune_deck()                     칸 5개 = {card, runes}
  → RuneEngine.simulate_cycle(deck, seed, opts)
        칸 진입 → 각인 판정(확률·중첩·과밀 감쇠) → 피해 배율 확정
        → 빚 누적 → 밟은 횟수 기록(slot_exec) → 이동 결정 → 다음 칸
        앙코르(twice/finisher/trade_skip)는 executed[cursor] < 2일 때만 소비된다
        종료: 5칸 통과 / 되돌이가 1칸 도달 / STEP_CAP 12(방어 단언)
  → steps[] (전부 순수 데이터)
DealCycleController._start_current_step()   ← steps[i]를 프레임에 펼친다
  → factory.compile_slot(i, flow)           장비 효과를 바늘 문맥으로 재적용
  → CycleSkillEffect                        VFX + 펄스
  → CombatResolver.strike_enemy_with_card() **여기서 원소 레이어가 돈다**
        ① 직격 보정(기름 ×2.2 · 전 표식 +12%)  ← apply()가 소모하기 **전에**
        ② StatusEngine.apply()                 매트릭스를 직격 피해보다 **먼저**
        ③ target.take_damage()
  → _cycle_damage_value()                   **피해가 확정되는 유일한 지점**
사이클 종료
  → reload = 빚 × reload_scale, 상한 6초        ← **선형이다**(과열 항 소멸 · Y1)
```

**결정성 계약**: 시드는 `cycle_seed_base + completed_cycles × 7919`다.
엔진은 `randf()`·`Time`을 전혀 쓰지 않으므로 같은 (덱, 시드, opts)면 궤적이 100% 같다.
`run_cycle_seed`가 세이브에 들어 있어 이어하기 후에도 궤적이 이어진다.
**편집 화면 미리보기와 실전 런타임이 같은 `simulate_cycle`을 부른다.**
어느 쪽이든 자체 근사식을 쓰면 미리보기와 실전이 어긋난다.

### 스테이지 클럭과 체류 압박

```text
game._process → clock.tick(delta)          state == "playing"일 때만
  낮 ↔ 밤 (길이는 스테이지마다 다르다 · STAGE_DAY/NIGHT_DURATION)
  한 주기가 끝나면 dwell += 1, day_number += 1   ← **day_number에 상한이 없다**
  dwell 신호
    dwell 1·3          → world.spawn_rift_near()   균열(스테이지당 2 · 런 최대 10)
    dwell ≥ 2 매 밤    → _spawn_night_omen()       전조 1기
    dwell == 임계      → blight_active = true      잠식(스테이지 클리어 시 해제)
    dwell == DESCENT   → _trigger_stage_descent()  강림 안전 밸브
  스폰될 때마다 combat.apply_stage_scaling(enemy)  ← **마물 1기당 정확히 1회**
    HP    ×= stage_hp_base × H(dwell)      H(d) = 1 + 0.13d + 0.010d²
    피해  ×= stage_damage_base × A(dwell)  A(d) = 1 + 0.07d + 0.004d²
    XP    ×= H(d)^0.5      골드 ×= H(d)^0.4   ← **이 두 줄이 체류 압박의 전부다**
보스 격파 → advance_stage()
  → stages_cleared += 1 · stage += 1 · dwell = floor(dwell × 0.5)
  → 월드 재생성(새 시드) · 랜드마크 재배치 · 스테이지 스코프 상태 초기화
  → 5스테이지였으면 clock.is_run_complete() → 마왕전 직행
```

⚠️ **XP·골드는 스테이지로 스케일하지 않는다.** dwell만 읽는다. 뒤 스테이지의 수입은
상위 티어 몹의 더 큰 `xp` 값 하나로만 오른다 — 실측상 스테이지당 수입이 거의 평평하다
(`balance_probe` ⑩·⑪). 후반 상점은 그 스테이지 수입이 아니라 **모아 둔 돈**으로 산다.

### 마왕이 자라는 과정

```text
플레이어가 카드를 버린다   (**레벨업 「취소」는 여기에 안 들어간다** · X1)
  → game.rejected_skills / trophy_reject_skills / demon_lord.rune_shards
  → DemonLord.growth_points() = 받은 카드 수 + 각인 조각
  → 스테이지 정산: 받은 카드 < DEMON_MIN_CARDS_PER_STAGE(4) × 격파 스테이지면
       모자란 만큼만 draft_pool()에서 보충 (X1 하한 · 정상 플레이는 절대 안 닿는다)
  → rune_capacity = clamp(growth / BOSS_CARDS_PER_RUNE(4), 0, BOSS_RUNE_CAP(16))
  → sync_runes(rng)  각인을 5칸 중 하나에 기록(이미 부여된 것은 다시 굴리지 않는다)
마왕전 개시
  → auto_fused_cards()   같은 id 2장 = 랭크 +1 자동 합성
  → ranked_cards()       expected_power 내림차순
  → 상위 5장 = 마왕의 레일 / 나머지 = 잔재 → 잠식 시 필드 몹 모듈
  → boss.max_health *= hp_multiplier(총일수, 격파스테이지)   **여기 한 곳에서만 곱한다**
       = (1 + 0.05 × 총일수) × (1 + 0.15 × 격파 스테이지)
```

⚠️ **마왕은 상태이상 면역이다**(`combat_resolver`의 `status_eligible`). 스테이지 보스는
면역이 아니다 — 그 차이가 마왕 HP를 정하는 계산의 큰 축이다(면역이 아니었다면
`balance_probe` ⑬ 기준 전투가 67초 → 41초로 줄어든다).

### 스테이지 보스 전투

```text
보스문 E → _show_stage_boss_preview()   state="boss_preview" · ESC 취소 가능
  └─ SPACE → _begin_stage_boss_battle()  state="boss" · 필드 정리 · 아레나 중심으로
       └─ _spawn_stage_boss(profile)
            deck  = StageBossDeck(FactoryDeck 상속 · compile_slot만 재정의)
            칸    = 3 (강화형 4 · 강림 +1) · **각인 없음** · RELOAD만 공유
            패턴  = BossLibrary.patterns(design, enhanced, descended)
            HP    = DESIGN_HP[design] × STAGE_HP_BASE[stage] × (1 + 0.08 × dwell)
칸 진입 → on_cycle_card_started(kind == "boss_pattern")
  └─ _launch_stage_boss_pattern()
       선딜 = telegraph × 0.86^페이즈 → 착탄점 고정 → BossTelegraph 노드
       **링이 뜬 자리가 곧 착탄점이다** (같은 노드의 같은 좌표·반경)
격파 → on_stage_boss_defeated()
  └─ 트로피 2택1 모달 → 배치 → advance_stage()
```

### 무한 맵 생성 흐름

```text
world_grid._resolved_tile_id(cell)
  → 스테이지 랜드마크(성·캠프·보스문) 우선
  → 동적 균열 아레나(스테이지당 2)
  → wfc_chunk_generator.tile_at(cell)     32×32 청크 캐시, 스테이지 시드에서 파생
      Simple Tiled WFC: 엔트로피 최소 셀 붕괴 → 인접 규칙 전파 → 모순 시 청크 재시작
```

`stage_world_seed(n) = absi(run_cycle_seed ^ (n × 2654435761)) | 1`.
**이어하기는 이 식을 쓰지 않고 저장된 `stage_seed`를 그대로 쓴다** — 식이 나중에 바뀌어도
이미 저장된 런의 지형이 흔들리지 않게 하기 위해서다.

### 저장 흐름 (schema 4 · 스냅샷 54키)

```text
저장  _save_run_snapshot()   5초 주기 + 주요 사건. **전투가 열려 있으면 쉰다**
      → ConfigFile user://the_unchosen_progress.cfg  [run] active=true, snapshot={...}
읽기  _read_run_snapshot()   schema_version < 4이면 **읽지 않고 버린다**
      → 버린 사실을 로비가 **한 번 알린다**(`saved_run_dropped` · `_lobby_run_chip_text()`)
복원  _begin_run(snapshot) → 모든 상태 초기화 → _restore_run_snapshot(snapshot)
```

**Y 라운드가 바꾼 키**

| 웨이브 | 무엇 |
|---|---|
| Y2 | `factory_rail_runes` **신설**(레일 각인 목록) · `run_peak_heat` → **`run_peak_steps` 개명** |
| Y3 | `spy_revealed`(bool) → **`spy_wipe_stage`(int)** — 열람이 무료 기본 공개가 되면서 저장할 것이 "지우기를 어느 스테이지에서 썼나"로 바뀌었다 |
| Y6 | **schema 3 → 4 승격** + 5키 신설 — `discovered_features` · `stage_events` · `run_event_count` · `consumable_item` · `night_eye_nights` |

지문 축은 **67 → 72**가 됐다.

⚠️ **`--save-test`의 필수 키 목록(53)이 스냅샷(54)보다 하나 적다.**
빠진 하나는 **`factory_rail_runes`**(Y2 신설)다 — §6이 "없으면 레일 각인이 통째로
사라진다"고 적은 바로 그 키인데 `test_runner.gd`의 `required_keys`에 안 들어 있다.
지문 왕복(`mismatch=0`)은 그 키도 함께 보므로 **회귀가 완전히 뚫려 있지는 않지만**,
필수 키 목록에 추가하는 것이 옳다. 다음에 `--save-test`를 여는 웨이브 몫이다.

⚠️ **축 개수를 계약으로 쓰지 말 것.** 이 숫자는 여러 웨이브에서 이미 실제 dict 크기와
어긋나 있었다(`test_runner.gd:5026`의 「67축」 주석이 그 흔적이다 — 실제로는 72다).
Y2가 축을 하나 더했는데 표기가 안 늘어난 적도 있다. 회귀를 잡는 것은 축 개수가 아니라
**`mismatch=0`** 하나다. 문서의 72도 참고값이지 계약이 아니다.

⚠️ **사전 안에 `Node`를 넣지 말 것.** Y6이 `stage_events[i]["mark"]`에 표식 노드를 넣었다가
`gameplay_root.free()` 뒤 **"Trying to assign invalid previously freed instance"**로 죽었다.
지금 표식은 `event_marks`라는 **별도 사전**이 들고 있고, `stage_events`에는 순수 데이터만 있다.

**복원 순서가 규칙이다**(V9가 여기서 회귀를 하나 잡았다). 시드를 월드보다 **먼저** 복원한다:

```text
① run_cycle_seed  ② clock  ③ _rebuild_stage_world(stage, 저장된 stage_seed) — 조건 없이 항상
④ 랜드마크 write-back  ⑤ 스테이지 스코프·마왕·균열·성 NPC·잠식  ⑥ 덱  ⑦ 플레이어  ⑧ 시각 스냅
```

**전투 중에는 저장하지 않는다.** `_run_save_blocked_reason()`이 막는 5구간:
`boss_battle`(state == "boss") · `stage_boss_descended`(`stage_boss_active()`) ·
`trophy_modal`(pending 4종 중 하나라도 살아 있음) · **`guide`(길잡이 진행 중 ·
`guide_active`)** · 그 밖의 `state != "playing"`.
손실은 0이다 — 보스전 중에는 영구 자원이 생기지 않고(트로피는 격파 **뒤**에 나온다)
스냅샷이 문 앞 필드 상태라 `stage_boss_cleared == false`로 문이 다시 열려 있다.
길잡이 구간도 같다 — "튜토리얼 절반"이라는 상태를 스냅샷에 새로 넣지 않기로 했고,
잃는 것은 런 시작 40초뿐이며 `_finish_guide()`가 끝나는 순간 한 번 저장한다.

빠뜨리기 쉬운 키:

| 키 | 빠지면 벌어지는 일 |
|---|---|
| `run_cycle_seed` | **리플레이 계약이 깨진다.** 월드 시드도 여기서 파생되므로 지형이 통째로 달라진다 |
| `stage_seed` | 생성식이 바뀌면 이어하기가 성·캠프·보스문을 통째로 옮긴다 |
| `stage_landmarks` | 위와 같은 보험. 좌표가 어긋나면 `opened_features`와 **가장자리 화살표 내비**가 거짓말을 한다 |
| `trophy_stages` | **트로피 효과의 유일한 진실 원천.** 번호만 저장하고 효과는 `merge_effects()`가 다시 세운다 |
| `total_days` | 로비가 클럭을 만들지 않고 사전만 읽는다. 없으면 이어하기 문구가 빈다 |
| `rift_state` / `rift_states` | 균열 좌표·예산·진행도. 스테이지 스코프다 |
| `blight_active` / `blight_marked` | 잠식이 통째로 사라진다 |
| `pact_uses` / `rune_shop_purchases` / `spy_wipe_stage` | 성 NPC 제한과 가격 사다리가 리셋된다(밀정 지우기가 스테이지마다 다시 살아난다) |
| `factory_rail_runes` | **레일 각인이 통째로 사라진다.** 칸 각인과 저장 자리가 다르다(Y2 신설) |
| `discovered_features` / `stage_events` | 발견 자리와 사건 배치가 리셋돼 이어하기가 지도를 다시 덮는다(Y6 신설) |

**일부러 저장하지 않는 것**: `player_status`(전투 중 수 초짜리 휘발 상태 · 복원 후 0) ·
`stage_boss*` 일체 · `shop_offers`·`shop_refresh_count`(1회 방문 스코프) ·
**`rune_shop_offers`·`rune_shop_rerolls`·`rune_shop_castle_id`**(X1 신설 · 카드 상점과 같은
"성 방문 스코프"라 저장하지 않는다. 사다리를 만드는 `rune_shop_purchases`만 저장한다) ·
`event_marks`(표식 **노드** 사전 — 위 경고) 등 파생값.

---

## 7. 현재 구현된 게임 규칙

### 7.1 5칸 딜싸이클과 바늘

- 칸은 5개이며 **런 시작부터 전부 열려 있다**(`FactoryDeck.SLOT_COUNT = 5`).
- 각 칸은 카드 1장 + 각인 스택을 가진다. **레인(분열)은 없다.**
- 바늘은 1칸부터 오른쪽으로 이동한다. 칸 각인이 터지면 **한 칸 뒤로**·**한 칸 건너뛰기**·
  **두 번 치기**가 일어나고, 레일 각인 `rail_loop`가 터지면 끝에서 **되돌아온다**.
- 우선순위는 **앙코르 → delta 합 → 방향 반전**. 5칸을 넘어가면 사이클 종료
  (`end_reason == "complete"`)이되, **`rail_loop`가 무장돼 있고 아직 안 썼으면 종료 대신
  방향을 뒤집는다**(한 바퀴에 **최대 1회**). 되돌아오다 1칸을 넘어가면 그때 종료한다.
- 두 번 다 밟은 칸은 건너뛴다. 갈 곳이 하나도 없으면 `end_reason == "all_used"`.
- **무한 루프 안전망**은 아래 표가 정본이다.

#### 무한 루프 안전망 (Y1이 전면 교체)

```text
SLOT_EXEC_CAP = 2                      # 한 칸은 한 바퀴에 두 번까지 (게임 규칙)
STEP_CAP = 2 × SLOT_COUNT + 2 = 12     # 게임 규칙이 아니라 방어 단언
RAIL_RUNE_CAP = 3 · RAIL_SAME_ID_CAP = 1 · P_CAP 0.75 유지
```

⚠️ **폐기된 어휘 — 다시 쓰지 말 것**: 되감기 −1/−2 · 도약 +2 · 재실행 · 역행 · 책갈피 ·
과열 감쇠 `0.62^일탈수` · `STEP_CAP 14`. 각인 id 이관표는 §7.3에 있다.

**새 회귀 계약 3개** (`rune_test.gd`가 문다):

| # | 계약 |
|---|---|
| ① | `end_reason == "overload"`가 **0건** |
| ② | `max(slot_exec) ≤ 2` 위반 **0건** |
| ③ | `step_count ≤ 2n` 위반 **0건** |

**실측 (25,001 사이클 · Y1/Y8)**

| 축 | 값 |
|---|---:|
| 무작위 10,000 사이클 평균 스텝 | **3.86** |
| 무작위 최대 스텝 | **10** |
| 흐름 각인 확정 무장 최대 | 9.10 |
| `rail_loop` + 흐름 확정 최대 | 9.76 |
| 각인 0개 순수 5칸 | 5.00 |
| 평균 RELOAD | **2.26초** |

칸 수별 최대 스텝은 `{1:2, 2:4, 3:6, 4:8, 5:10}` — **2n 상한이 tight하다**(여유가 없다).

`rail_loop`를 무장하면 400시드 중 299건이 **전부 같은 궤적**으로 떨어진다 —
`step_count == 10` · `visited == [0,1,2,3,4,4,3,2,1,0]` · `slot_exec == [2,2,2,2,2]`.
⚠️ 되돌이 바퀴의 `end_reason`은 `"all_used"`가 아니라 **`"complete"`**다.

### 7.2 한 칸은 한 바퀴에 두 번까지 (과열 폐기)

> **과열(Heat)은 Y1이 시스템째 삭제했다.** 사용자 피드백 ⑲다. 그 자리를 대신하는 규칙은
> 「한 칸은 한 바퀴에 **두 번**까지 밟는다」 하나뿐이고, 이것은 방어 장치가 아니라 **게임 규칙**이다.

- 앙코르 각인(`twice` · `finisher` · `trade_skip`)은 `executed[cursor] < 2`일 때만 소비된다.
  **막히면 조용히 버린다**(오류도 로그도 없다 — 궤적에 흔적이 남지 않는다).
- 이동식은 `move = 1 + delta + carried_delta`이고
  `FLOW_DELTA = {"back_one": -2, "jump_one": 1}`이다.
  ⚠️ **단위는 "정상 다음 칸 대비 오프셋"**이다. `back_one`이 −2인 이유는
  `1 + (−2) = −1` = 한 칸 뒤이기 때문이다.
- **RELOAD = `빚 × rail["reload_mul"] × reload_scale`** — 밟은 칸 수에 **선형**이다.
  과열 항이 사라졌다. `rail["reload_mul"]`은 레일 각인 `rail_rest`(−20%)만 건드린다.
  `reload_scale`은 마왕 **×0.42** · 스테이지 보스 **×0.90** · 강화형 **×0.60**.
  상한 `RELOAD_CAP = 6.0`초는 그대로 남았지만 **도달이 벌칙이 아니다** —
  「과부하」가 나면 RELOAD를 상한으로 올리던 **옛 벌칙 항**은 삭제됐다(연혁 서술).
- 무각인 5칸 기준선은 덱마다 다르다. `--cycle-test`의 표준 덱은 `debt = 2.42초`,
  `data_test`의 대표 덱(`reload_baseline`)은 **2.39초**, `balance_probe`의
  `RUNE_BENCH_CARDS` 덱은 **2.45초**다. 셋 다 같은 선형식에서 나오고 **카드 구성만 다르다** —
  비교할 때 어느 덱인지 먼저 볼 것. 밴드는 **2.3 ± 1.0**, `RELOAD_BARE_MAX = 3.0`.

#### 삭제된 심볼 전량 (되살리려 하면 `data_test`가 잡는다)

| 부류 | 개수 | 무엇 |
|---|---:|---|
| 상수 | 15 | `HEAT_MAX` `HEAT_DECAY` `HEAT_DAMAGE` `HEAT_RELOAD` `REENTRY_FALLOFF` `HEAT_GATE_MIN` `BOND_MIN_RUN` `BOND_FIRE_COST` `TRIANGLE_RELOAD_DISCOUNT` `OVERCHARGE_HEAT_BONUS` `REPEAT_CAP` `ECHO_POWER` `CHORUS_POWER` `OVERLAP_POWER` `LINK_POWER` |
| 함수 | 4 | `heat_from_load()` `damage_multiplier()` `bond_mask()` `triangle_ok()` |
| 사이클 결과 키 | 5 | `heat_curve` `peak_heat` `end_heat` `carry_heat` `deviation_load` |
| 스텝 궤적 키 | 4 | `heat` `bond` `reverse` `link` |
| `resolve()` 반환 키 | 9 | 과열 관련 전량 |
| `preview()` 반환 키 | 4 | 과열 관련 전량 |
| `ctx` 키 | 4 | 과열 관련 전량 |
| `condition_ok` 분기 | 1 | `"heat_gate"` |
| 데이터 키 | 1 | `boss_library.gd`의 `"uses_heat"` |

**남긴 둘과 그 이유**

| 남긴 것 | 왜 |
|---|---|
| `effective_probability()`의 **2번째 인자** | **`game.gd:3045`**가 아직 3인자로 부른다. 시그니처를 줄이면 그 파일이 컴파일 단계에서 깨진다. 값은 **무시되고**, 그 사실을 **`rune_test`의 `p_cap` 묶음**이 문다. 호출부를 같이 고칠 웨이브가 지우면 된다 |
| 결과 키 **`overloaded`** | 이름만 과열이고 뜻이 다르다. **`STEP_CAP` 방어 단언에 걸렸다**는 뜻이다(정상 플레이에서는 0). **실소비자 2곳** — `game.gd:3004` · `deal_cycle_controller.gd:324` |

⚠️ **과열을 재던 검사도 함께 은퇴했다**(Y8 · 위 표의 근거를 누가 지키는지가 바뀌었다).
셔틀이 사라져 "중립인지"를 잴 대상이 없어졌으므로 `rune_test`의 **`heat_neutral` 묶음은
은퇴**했고(살아남은 단언은 `p_cap`으로 옮겼다), `data_test`의 **`rune_heat_neutral`은
`rune_exec_cap`으로 개명**됐다. 지금 뒷문을 지키는 것은 그 **`rune_exec_cap`의 음성 축**이다
— `SLOT_EXEC_CAP` 2 · `STEP_CAP` 12 + **위 결과 키·궤적 키가 되살아나지 않았는가**.
과열을 되살리려면 이 계약을 먼저 깨야 한다.

⚠️ **`RuneEngine.trace_signature()`의 문자열 형식이 바뀌었다** —
`slot:reentry:damage_mul:fired`다. 저장 키·캐시 키에 이 문자열을 박지 말 것.

### 7.3 각인 15종 (칸 10 + 레일 5)

> **Y1이 24종을 15종으로 전면 교체했다**(사용자 피드백 ④ — "각인 효과를 한 번에 알아볼 수
> 있게"). 종류가 줄었을 뿐 아니라 **붙는 자리가 둘로 갈렸다** — 칸 각인은 칸이 소유하고
> 칸 교환을 따라가지만, **레일 각인은 레일 전체가 소유하고 붙일 칸을 고르지 않는다.**

같은 각인이라도 `roll_rune(id, rng)`로 뽑을 때마다 확률·크기가 다르다 —
**`p`를 직접 박지 말 것.** 희귀도는 common/rare/epic 그대로다.

#### 칸 각인 10종 (`scope: "slot"`)

| id | 이름 | 계열 | 조건 | 굴림 | 값 | 희귀도 |
|---|---|---|---|---|---|---|
| `twice` | 두 번 치기 | flow | always | roll | p 0.35–0.60 | 일반 |
| `back_one` | 한 칸 뒤로 | flow | always | roll | p 0.30–0.55 | 일반 |
| `jump_one` | 한 칸 건너뛰기 | flow | always | roll | p 0.35–0.60 | 일반 |
| `strong` | 힘주기 | combat | always | 확정 | mag 0.25–0.40 | 일반 |
| `wide` | 넓히기 | combat | always | 확정 | mag 0.20–0.35 | 일반 |
| `quick` | 서두르기 | tempo | always | roll | p 0.40–0.65 | 희귀 |
| `first_hit` | 첫 칸 힘 | conditional | `first` | 확정 | mag 0.50–0.80 | 희귀 |
| `twin_cast` | 쌍둥이 | parallel | `prev_slot` | roll | p 0.40–0.65 · mag 0.5 | 희귀 |
| `trade_skip` | 두 번 치고 건너뛰기 | flow | always | 확정 | — | 영웅 |
| `finisher` | 마무리 | flow | `kill` | 확정 | — | 영웅 |

#### 레일 각인 5종 (`scope: "rail"`)

| id | 이름 | 계열 | 효과 | 희귀도 |
|---|---|---|---|---|
| `rail_fast` | 빨리 감기 | tempo | 모든 칸 지속 **−15%** | 일반 |
| `rail_power` | 모두 힘주기 | combat | 모든 칸 피해 **+12%** | 희귀 |
| `rail_rest` | 짧은 휴식 | tempo | 한 바퀴 쉬는 시간 **−20%** | 희귀 |
| `rail_color` | 같은 색 덤 | combat | 공명이 성립한 칸에 **+25% 가산** | 희귀 |
| `rail_loop` | 되돌이 | flow | roll p **0.45–0.65** · 끝에서 거꾸로 한 바퀴 더 | 영웅 |

⚠️ **이름 몇 개는 YZ 한글 스윕에서 다시 갈릴 수 있다.**
**정본은 `core/rune_engine.gd`의 `RUNES`이고 이 표는 그 사본이다.**
문서에서 이름을 옮겨 적지 말고 **코드에서 확인할 것**(예: `rail_color`는 지금
「같은 색 **덤**」이고 그 전에는 「같은 색 보너스」였다).

#### 테스트로 못 박힌 계약 3개

| # | 계약 | 왜 |
|---|---|---|
| ① | `RUNES`가 **정확히 15키** | 폐기 id가 조용히 되살아나는 것을 막는다 |
| ② | 희귀도 분포 **일반 6 / 희귀 6 / 영웅 3** | 드래프트 가중과 상점 가격표가 이 분포 위에 있다 |
| ③ | `family == "flow"`가 정확히 `{twice, back_one, jump_one, trade_skip, finisher, rail_loop}` **6종**이고, 이 집합이 `RUNE_SHOP_FLOW_PREMIUM` 대상과 **집합 동등** | 상점 가격식이 여기 걸려 있다 |

**칸 감쇠 4겹은 값 그대로다**: `RUNE_STACK_CAP 5` · `SAME_ID_STACK_CAP 3` ·
`DUP_P_FALLOFF 0.55` · `CONGESTION_FALLOFF 0.80`. 공명은 `RESONANCE_DAMAGE 0.15`.
레일 쪽은 `RAIL_RUNE_CAP 3` · `RAIL_SAME_ID_CAP 1`(레일 각인은 중복 불가)이다.

#### 구 → 신 각인 id 이관표

| 폐기된 id | 대체 |
|---|---|
| `rewind_1` · `rewind_2` | `back_one` |
| `skip_1` · `bookmark` | `jump_one` |
| `repeat` | `twice` |
| `kill_repeat` | `finisher` |
| `echo` · `overlap` · `link_next` | `twin_cast` |
| `edge` · `chorus` | `strong` |
| `reach` · `barb` | `wide` |
| `heat_gate` | `first_hit` |
| `afterburn` | `quick` |

⚠️ **슬롯 강화 이름 `"repeat"`(`_buy_factory_upgrade`)은 각인이 아니다 — 건드리지 말 것.**
같은 글자를 쓰지만 칸 자체의 실행 횟수 강화이고 `RUNES`와 아무 관계가 없다.

#### 각인 15종 기대 스텝 대조표 (Y8 실측)

기준 덱 = `balance_probe`의 `RUNE_BENCH_CARDS` 5칸 · 각인 0개 →
`steps 5.00` · **1.69 단위/초** · `RELOAD 2.45`(다른 덱의 기준선은 §7.2를 볼 것).

| 각인 | 기대 스텝 | 초당 단위 | 비고 |
|---|---:|---:|---|
| `rail_loop` | **7.84** | — | 단일 각인 중 최대 |
| `back_one` | 5.87 | — | |
| `twice` | 5.50 | — | |
| `finisher` | 5.35 | — | 처치 조건부라 실전 값은 더 낮다 |
| `jump_one` | 4.50 | — | 밟은 칸도 4.50 |
| `trade_skip` | 5.00 | — | **밟은 칸은 4.00**(스텝은 같은데 칸이 하나 준다) |
| `rail_fast` | — | **1.90** | |
| `rail_power` | — | 1.89 | |
| `first_hit` | — | 1.88 | |
| `twin_cast` | — | 1.82 | |
| `rail_rest` | — | — | `RELOAD` 2.45 → **1.96** |
| `strong` | — | 1.78 | |
| `quick` | — | 1.72 | |
| `wide` · `rail_color` | — | Δ **0.00** | 아래 각주 |

**읽는 법** — `wide`는 **범위** 각인이라 단일 표적 모델에 잡히지 않고, `rail_color`는
**인접 공명이 성립한 칸에만** 붙는데 기준 덱이 원소를 섞어 공명을 끊었다.
**둘의 Δ 0은 버그가 아니다.** 이 둘을 재려면 다표적/동색 덱을 따로 만들어야 한다.

#### 각인 획득 경로 (X1이 재편 · Y2가 레일 각인을 섞었다)

| 경로 | 무엇 | 값 |
|---|---|---|
| **각인 세공사**(성·캠프) | **카드 3장 진열 + 새로고침**. 상시 만나는 유료 창구다 | §7.10 |
| **보물상자** | 각인 드래프트 3택1 | 비중 **14%** |
| **균열**(dwell 1·3) | 정예 전멸 보상 | 3택1 + 60 G |
| **전조**(dwell ≥ 2 밤) | 격파 시 **마왕의 각인 뜯기** | 무료 |
| **계약자**(성·캠프) | 「영웅 각인」 거래 | dwell +2 (골드가 아니라 **시간**으로 산다) |

⚠️ **3택에는 레일 각인이 섞여 나온다**(Y2). 레일 각인을 고르면 **2단계(칸 선택)를
건너뛰고 즉시 부착**된다 — 붙일 칸이 없기 때문이다.
⚠️ **`demon_lord.set_rune_catalog()`는 `ids_by_scope("slot")`만 받는다.**
마왕은 레일 각인을 갖지 않는다.

**보물상자 배당** — 정본은 `CHEST_TABLE`이고 **합은 100**이다.

| 칸 | key | % | 칸 | key | % |
|---|---|---:|---|---|---:|
| 골드 | `gold` | 13 | 저주 | `curse` | 6 |
| 경험 | `xp` | 12 | 함정 | `trap` | 7 |
| 스킬 2택 | `skill` | 14 | 미믹 | `mimic` | 5 |
| 아이템 2택 | `item` | 13 | 빈 상자 | `empty` | 3 |
| 각인 드래프트 | `rune` | 14 | **체력**(Y6 신설 · 40% 회복) | **`heal`** | **7** |
| | | | **재미 아이템**(Y6 신설) | **`fun`** | **6** |

위협 총량(`CHEST_THREAT_SLICES` = 저주 + 함정 + 미믹)은 21% → **18%**로 내려갔다.
`chest_table_total()` == 100과 위협 18은 `--event-test`의 `chest` 묶음이 문다.
⚠️ **`docs/FEEDBACK_Y.md` §6.4의 「새 값」 열은 합이 106이었다**(산수 착오).
Y6이 보상 네 칸에서 6%p를 빼 100을 맞췄다 — 설계 문서를 그대로 옮겨 적지 말 것.

⚠️ **레벨업의 「각인 강화」 선택지는 삭제됐다**(사용자 피드백 ④). `_choose_rune_draft()` ·
`_convert_level_choice_to_rune_draft()` 두 함수가 사라졌고 원본은 `handoff-x1.md` §11에 있다.
문서·온보딩·툴팁·배너 어디에도 "레벨업에서 각인을 얻는다"고 쓰지 않는다 — 거짓이다.
레벨업 → 취소 → **골드** → 각인 세공사가 그 자리를 **경제를 한 바퀴 돌아** 대신한다.

### 7.4 원소와 상태이상 — v3의 새 축

**원소 7계**: 불(fire) · 얼음(ice) · 번개(thunder) · 독(poison) · 기름(oil) +
비원소 2종 타격(strike) · 정신(psi).

⚠️ **Y4가 한자 병기를 폐기했다.** 「화(火)·빙(氷)·뇌(雷)·유(油)·초(超)」로 쓰지 않는다.
표시 이름의 정본은 `DealCardLibrary.element_name()`이고 **내부 키는 한 글자도 안 바뀌었다.**
`--v4-test`가 화면 문자열에서 한자 5자(`화` `빙` `뇌` `유` `초`)가 0건인지 감시한다.
상태이상 5종의 한 글자 약칭(독·연·한·유·전)은 **바뀌지 않았다** — 그건 원소 이름이 아니다.

**상태 5종** (`GameTuning` V3-K 블록이 정본 · `StatusEngine`은 규칙만 갖는다):

| 상태 | 지속 | 효과 | 성격 |
|---|---|---|---|
| 독(poison) | 6.0초 | 스택당 0.045 P/틱 · **유일하게 중첩**(최대 6) · 1.5초마다 −1 | 축적 후 터뜨린다 |
| 연(burn) | 2.0초 | 0.10 P/틱 | 짧고 굵다 |
| 한(chill) | 3.5초 | 이동 ×(1 − 0.35) | 전도의 매개 · 증기·쇄빙의 재료 |
| 유(oil) | 8.0초 | **자체 피해 0** · 화염 피해 ×2.2 | 단독으로는 완전히 무의미하다 |
| 전(shock) | 0.8초 | 다음 타격 +12% | 표식. 가장 짧다 |

**반응 매트릭스 11종** (행 = 지금 꽂는 속성 / 열 = 이미 붙어 있는 상태):

> ⚠️ 이 문서는 오래 「8쌍」이라 적어 왔지만 `status_engine.gd`의 `REACTION_LABELS`는
> **11개**이고 매트릭스 셀은 12칸이다. 아래 표가 11개 전부다.

| 조합 | 반응 키 | 화면에 뜨는 말 | 효과 |
|---|---|---|---|
| ★불 × 유 | `blaze` | **크게 타오름!** | 기름 소모 · 연 power ×3 · 지속 ×2.5(5초) · 반경 130 기름 전파 |
| ★번개 × 한 | `conduction` | **번개 옮음!** | 반경 260의 **chill 상태 적에게만** 전이. 최대 4체 · 도약당 −20% |
| 불 × 독 | `plague_ignition` | 역병에 불! | 스택 전소모 · 반경 90에 1.2 × P × stacks 즉발 |
| 불 × 한 | `steam` | 증기! | 한 해제 · 이번 타격 범위 +50% |
| 번개 × 유 | `oiled_shock` | 기름에 전기! | 기름 소모 · 반경 160에 0.8 × P + 전 표식 |
| 기름 × 연 | `greased_flame` | 불에 기름! | 연 power ×2 |
| 타격 × 독 | `detonate` | 터뜨리기! | 스택 1 소모 · 1.0 × P 즉발 |
| 타격 × 한 | `shatter` | 얼음 깨짐! | 한 해제 · 넉백 ×2 · 경직 0.35초 |
| 정신 × 전상태 | `psi_collapse` | 정신 붕괴! | 모든 상태 남은 지속 30% 소모 → 소모한 초 × 0.5 × P 즉발 |
| 독 × 한 | `frozen_venom` | 언 독! | 한 유지 · 독 지속 **+50%** |
| 얼음 × 독 | `frozen_venom` | 언 독! | 독 유지 · 독 지속 **+50%** |
| 얼음 × 연 | `quench` | 불 꺼짐! | 연 해제 → 한 부여 |

**반응 키는 11개, 매트릭스 셀은 12칸이다**(`frozen_venom`이 두 칸을 쓴다).
화면에 뜨는 말은 YZ 한글 스윕에서 갈렸다 — **정본은 `status_engine.gd`의 `REACTION_LABELS`**다.

★ = 사용자가 명시적으로 요구한 두 조합. **기름+불이 맨 불의 7.5배**라는 것이 숫자로 성립한다.
(행의 첫 낱말 = 지금 꽂는 **원소** · 뒤의 한 글자 = 이미 붙어 있는 **상태**다.)

**성능 규칙 4가지 — 반드시 지킨다** (밤 물량 최대 78기):

1. **새 O(N) 순회를 만들지 않는다.** 상태 감쇠는 `enemy._physics_process`의 기존 타이머 블록에 얹는다.
2. **도트는 0.25초 버퍼.** `st_dot_accum`에 모았다가 틱마다 `take_damage` 1회(15배 감소).
3. **`take_damage`에 `source`.** `SOURCE_DOT`이면 `provoke()`·`alert_same_species()`를 건너뛴다.
   이게 없으면 도트 틱마다 반경 780px 종족 경보가 나가 즉사한다.
4. **반응 예산** 프레임당 24 · 전파 깊이 1 · 킬 체인 깊이 3. `--stress-test`가 감시.

⚠️ **카드 인스턴스에는 `element`/`form`이 없다.** 태그는 정의(`by_id`)에만 있고
`ranked()`가 합쳐 준다. `factory.slots[i]["card"]`에서 직접 읽으면 항상 빈 문자열이다.

**태그 상호작용 — 남은 것은 공명 하나뿐이다.**

| 규칙 | 상태 |
|---|---|
| **공명** — 인접 두 칸이 같은 원소면 두 칸 모두 피해 **+15%**(`RESONANCE_DAMAGE`) | **유지** |
| ~~결속 — 3칸 연속 같은 원소~~ | **삭제**(과열 비용 항이 사라져 정의할 것이 없어졌다) |
| ~~삼각 — 1·3·5칸 같은 형태 → RELOAD −12%~~ | **삭제**(RELOAD가 선형이 되면서 할인 항이 사라졌다) |

판정 함수 `bond_mask()` · `triangle_ok()`도 함께 지워졌다(§7.2 삭제 표).
레일 각인 `rail_color`는 **공명이 성립한 칸에만** +25%를 가산한다 — 공명의 상위 규칙이 아니라
공명에 얹히는 배수다.

#### 스킬 28종이 Y1에서 바뀐 것

| 무변경 | 바뀐 것 |
|---|---|
| `id` 40개(스킬 28 + 특별 12) · 수치 18키 · `element` · `form` · **배열 순서 전부** | `name`·`desc` 교체 + **`combo`·`impact`·`silhouette` 3키 신설** |

- 글자 수 계약: `desc` **≤ 16자** · `combo` **≤ 18자** (`data_test.card_text_limits`).
- `SILHOUETTES` **14종** · `IMPACTS` **8종**.
- **`(element, silhouette)` 28쌍이 전부 고유하다** — 같은 속성 안에서 실루엣이 겹치지 않는다.
- `combo`는 "이 카드를 어디에 놓으면 좋은가"를 한 줄로 암시한다(사용자 피드백 ⑭).

### 7.5 스테이지 5개와 체류 압박

| 스테이지 | 이름 | 아틀라스 | 낮/밤 | 몹 HP× | 잠식 임계 | 보스 |
|---|---|---|---|---|---|---|
| 1 | 왕국 변두리 | verdant | 72 / 45 | **1.00** | dwell 4 | A 서릿발 외눈 |
| 2 | 시든 숲 | verdant | 68 / 52 | **1.35** | dwell 4 | B 역병 점액왕 |
| 3 | 잿빛 벌판 | waste | 62 / 60 | **1.70** | dwell 3 | C 홍염 천구 |
| 4 | 역병의 늪 | waste | 56 / 68 | **2.05** | dwell 3 | B+ 흑점액 변종 |
| 5 | 심연 | abyss | 48 / 78 | **2.40** | dwell 2 | C+ 흑천구 |

#### Y8이 재확정한 곡선 (사용자 피드백 ⑰ — "난이도는 HP가 아니라 패턴·물량")

| 상수 | 이전 | **현재** |
|---|---:|---:|
| `DWELL_HP_LINEAR` | 0.14 | **0.13** |
| `DWELL_HP_QUAD` | 0.012 | **0.010** |
| `H(12)` | 4.408 | **4.000** |
| 체류 압박(**d=12 레벨업 시간 배율** = `1/효율(12)` = `H(12)^0.5`) | ×2.100 | **×2.000** (목표 창 **×2.0 ± 0.15**) |
| `CYCLE_HEALTH_GAIN` | 0.24 | **0.21** |
| `STAGE_HP_BASE` | `[1.00,1.55,2.10,2.65,3.20]` | **`[1.00,1.35,1.70,2.05,2.40]`** |
| `DWELL_COUNT_STEP` | 3 | **4** |
| `DWELL_COUNT_SATURATION` | 6 | **8** |
| `DWELL_ELITE_STEP` | 0.03 | **0.04** |
| `DWELL_ELITE_CAP` | 0.35 | **0.45** |
| `MAX_ENEMIES` | 78 | 78 (유지) |

- **dwell 곡선**: HP `1 + 0.13d + 0.010d²` · 피해 `1 + 0.07d + 0.004d²` ·
  속도 `min(1.30, 1 + 0.012d)` · 물량 `+4 × min(d, 8)` · 정예 `min(0.45, 0.04d)` ·
  XP `H^0.5` · 골드 `H^0.4`.
- **몹 HP 복리 지수는 0.742 = −25.8%**다(Y1 이전 대비 기하평균 · 목표 창 **−25% ± 10%p**).
  극단 좌표(5스테이지 · d12 · power 13.6)에서
  배수 60.1 → **37.0**, hellhound 실체력 @ p13.6 = **617 HP**.
- **킬당 효율 = XP× / HP×** 실측: d=4 **0.772** · d=8 **0.611** · d=12 **0.500**.
  `--stage-test`와 `balance_probe`가 설계표와 소수 2자리까지 대조한다.
- **물량**: 포화 밤 상한이 **62 / 78**이다 — 여유가 16기뿐이고 무리 스폰이 그 여유를 먹는다.
  d = 0~200 전 구간에서 `MAX_ENEMIES` 불가침을 확인했다.

- 스테이지를 넘기면 **dwell이 절반으로 감쇠해 이월된다**(`floor(dwell × 0.5)`).
  완전 리셋도 이월 없음도 아니다 — 과파밍의 대가가 다음 스테이지까지 따라온다.
- **승리 등급은 총 일수만 본다**: S ≤ 13 · A ≤ 17 · B ≤ 23 · 그 뒤 C.
  강림 밸브를 한 번이라도 밟으면 총 일수와 무관하게 **C 고정**.
  기대 플레이는 스테이지당 3~4일 × 5 = 15~20일이다(Y8 실측 **15일 · 레벨 27 · 등급 A**).
- **랜드마크 3종**은 스테이지 시드가 결정한다. 보스문(3,600~4,200px) → 캠프(보스문에서
  플레이어 쪽 520px) → 성(300~420px) 순으로 배치된다.

⚠️ **`NIGHT_ENEMY_LIMIT_STEP`은 YZ가 삭제했다.** 리포지토리 전체 소비자가 0이었고
밤 물량은 전부 `DWELL_COUNT_STEP`에서 온다. 되살리지 말 것.

⚠️ **DWELL 불변식이 등식에서 부등식 2개로 바뀌었다.**
`DWELL_DAMAGE_LINEAR < DWELL_HP_LINEAR` **그리고** `DWELL_DAMAGE_LINEAR × 2 > DWELL_HP_LINEAR`.
현재 값은 `0.07 < 0.13 < 0.14`이고 **위쪽이 빡빡하다** — `DWELL_HP_LINEAR`를 0.14 이상으로
올리면 두 번째 부등식이 깨진다.

⚠️ **세 축이 곱해진다.** `STAGE_HP_BASE` × `H(d)` × `CYCLE_HEALTH_GAIN` 각각을 −25% 안팎으로
내렸는데 **곱이 −59%**였다. 하나라도 만지면 `balance_probe` ③(`dwell_curve`)을 다시 볼 것.

### 7.6 스테이지 보스 3종

**5칸 + 각인은 마왕만 가진다.** 스테이지 보스는 3칸(강화형 4칸) · **각인 없음** ·
RELOAD만 공유한다. 플레이어는 1스테이지에서 "**밟은 칸을 보고 RELOAD에 때린다**"를
배우고 마왕에서 졸업한다.

| 디자인 | 이름 | 원소 | 교육 목표 | 기저 HP |
|---|---|---|---|---|
| A | 서릿발 외눈 | 얼음 + 번개 | 보스도 시너지를 쓴다 / RELOAD가 반격 창이다 | **2,130** |
| B | 역병 점액왕 | 독 | 상태이상은 나에게도 쌓인다 / 광역이 필요하다 | **2,440** |
| C | 홍염 천구 | 불 + 기름 | 기름 → 불 콤보를 몸으로 배운다 | **3,180** |

- 실체력 = `기저 × STAGE_HP_BASE[stage] × (1 + 0.08 × dwell)`.
  dwell 항이 몹(0.13 + 0.010d²)보다 완만한 이유는 **오래 머문 플레이어를 두 번 벌하지
  않기 위해서**다.
- **기저 HP 3개는 Y8이 `balance_probe`로 실측 재확정했다**(이전 값 2,750 / 2,270 / 2,620은
  주석에 남아 있다 = 롤백 지점). ⚠️ 이 값을 바꾸면 반드시 프로브를 다시 돌린다.

#### Y8이 바꾼 보스 계수

| 상수 | 이전 | **현재** |
|---|---:|---:|
| `STAGE_BOSS_RELOAD_MUL` | 0.75 | **0.90** |
| `STAGE_BOSS_RELOAD_MUL_ENHANCED` | 0.55 | **0.60** |
| `BOSS_RELOAD_MUL`(마왕) | 0.42 | 0.42 (유지) |
| `STAGE_BOSS_HP_DWELL_STEP` | 0.08 | 0.08 (유지) |
| `BOSS_BASE_HP`(마왕 기저) | 611 | **1,180** |
| `BOSS_HP_PER_ITEM` | 88 | **170** |
| `BOSS_HP_PER_POWER` | 57 | **110** |

#### 다섯 관문 실측 TTK (Y8 · uptime 0.62)

| 관문 | 실체력 | raw_dps | **TTK** |
|---|---:|---:|---:|
| 1스테이지 A | 2,471 | 88.5 | **45초** |
| 2스테이지 B | 3,821 | 116.3 | **53초** |
| 3스테이지 C | 6,271 | 180.7 | **56초** |
| 4스테이지 B+ | 5,802 | 245.2 | **38초** |
| 5스테이지 C+ | 8,853 | 394.3 | **36초** |
| 마왕(정규 경로) | 19,153 | 415.8 | **85초** (uptime 0.55) |

**목표 창: 스테이지 보스 30~60초 · 마왕 60~120초.**
스테이지 보스 창은 V10의 45~90초에서 내려왔다 — 전투가 길다는 관측이 근거다.

- **telegraph**: 패턴마다 0.35~1.20초 선딜. **링이 뜬 자리가 곧 착탄점이다**(같은 노드의
  같은 좌표·반경). 강화형은 ×0.85, 페이즈 1단마다 ×0.86 누적.
- **페이즈**: 기본 HP 50%에서 1회 / 강화형 66%·33%에서 2회. 피해 ×1.12 누적.
- 강화형(B+·C+)은 칸 4개 · 부여 상태 2종 · RELOAD **×0.60** · 전설 트로피를 떨군다.

#### 반격 창 실측 (목표 1.3~1.9초)

| A | A+ | B | B+ | C | C+ | 마왕 |
|---:|---:|---:|---:|---:|---:|---:|
| 1.49 | 1.46 | 1.62 | 1.56 | 1.31 | 1.37 | 평균 **1.63** · 최대 2.14 |

⚠️ **스테이지 보스는 각인이 0개라 빚이 시드와 무관하게 고정이다**(빚 평균 = 빚 최대).
빚이 2배로 벌어질 수 있는 것은 각인을 `BOSS_RUNE_CAP`(16)까지 갖는 **마왕뿐**이다 —
"보스도 시드에 따라 반격 창이 흔들린다"고 가정하고 계산하지 말 것.

### 7.7 성장 — 두 화폐 + 트로피

> **두 화폐(카드·각인)는 이제 한 화면에 없다**(X1). v2·v3 초기에는 레벨업 한 화면이
> 둘을 나란히 놓았지만, 지금은 **레벨업 → 취소 → 골드 → 각인 세공사**로 **경제를 한 바퀴
> 돌아 다시 만난다.** 둘이 여전히 한 성장 축인 것은 그대로다.

#### 레벨업 카드 한 장의 정보 구조 (X1 · 피드백 ③)

| 자리 | 무엇 | 비고 |
|---|---|---|
| 카드 중앙 | **아이콘 152px** (구 48px · 면적 10배) | 속성색 블록 위에 앉는다. **그림이 주역이다** |
| 좌상단 | 원소 1글자 마크 | 색약 대비. HUD 레일 `RAIL_ELEMENT_MARK`와 **같은 글자** |
| 이름 | 26px · 카드 중앙 | 구 13px·블록 안 |
| 설명 | 14px · 이름 아래 | 횟수·넉백·사거리를 **문장이 다 나른다**(태그 줄이 없어졌으므로) |
| 하단 | 지속 / RELOAD 칩 2개 | **무변경** — 레일 카드와 같은 위젯·같은 색 |
| 우상단 | `N장` 보유 칩 | **보유 ≥ 1일 때만** 그린다 |
| 카드 전체 | 프레임 틴트 + 본문 판 덧칠 + 아이콘 블록 덧칠 **3중** | 속성 = 색 (§9) |

**삭제한 것**: 원소·형태 배지 · 태그 줄(`3회 타격` 등) · `피해계수 · 범위` 줄 ·
`한 바퀴 빚 N초 → +N초` 줄 · `N장 보유중 · 최고 R2` 문장 · 부제 밴드 · 규칙 밴드.
카드 1장의 글자 줄이 **9 → 4줄**, 화면 전체가 **22 → 11줄**이 됐다.
규칙 밴드에 있던 「지속시간·RELOAD 정의」는 **온보딩 몫으로 넘겼고**(사용자 명시)
X4가 2페이지 바늘 캡션과 하단 칩에서 가르친다.

- 레벨업 화면은 **카드 2택 + 취소**다(X1 개편 · 사용자 피드백 ③④).
  - 스킬 카드 A 또는 B — 고른 쪽은 레일에 즉시 배치, **버린 한 장은 마왕에게**.
  - **「취소 +N G」** — 두 카드가 **소멸**하고 마왕은 **아무것도 받지 않는다**.
    보상 = `CHOICE_CANCEL_GOLD(30) × 상점가 스테이지 스케일`(30 / 38 / 45 / 53 / 60 G ·
    `STAGE_PRICE_STEP`이 0.25로 내려가면서 사다리도 함께 완만해졌다).
- **취소가 지키는 계약 3줄** (`--draft-test cancel`이 단언한다):
  ① `rejected_skills`·`trophy_reject_skills`·`pending_boss_toast_cards` 어디에도 안 들어간다
  (`demon_lord.growth_points()`가 그대로다) ② 골드는 스테이지 스케일을 탄다
  ③ **레벨은 정상적으로 오른다**(취소는 "미루기"가 아니다 — 미루기로 만들면 경험치가 넘친 채
  모달이 무한히 다시 뜬다).
- **왜 30인가.** 카드 상점 정가가 `randi(24, 42)` = 평균 33 G × 같은 스케일이라
  **취소 1회 = 상점 카드 0.91장**이다. 카드 축에서 취소는 언제나 9% 손해이므로 파밍이
  성립하지 않고, 그러면서도 "두 장 다 쓸모없을 때의 출구"로는 충분하다. 25는 출구로 약하고
  40이면(1.21장) 파밍이 성립한다.
- **마왕 성장 하한** `DEMON_MIN_CARDS_PER_STAGE = 4` — 스테이지 정산마다 받은 카드 수가
  `4 × 격파 스테이지`에 못 미치면 모자란 만큼만 **`draft_pool()`에서** 보충한다.
  정상 플레이 누적(9/14/18/21/24)은 하한(4/8/12/16/20)에 **한 번도 닿지 않는다** —
  오직 전부 취소 플레이에서만 작동해 마지막 전투가 빈 레일과 싸우는 사고를 막는다.
- 경험치 문턱은 `xp_target = 7 + level × 5`다.
- 랭크는 **R3 상한**(같은 카드 4장). R1 ×1.00 / R2 ×1.55 / R3 ×2.10 피해.
- **성장 천장 — X1이 재정의했다.** 레일 5칸이 전부 R3이고 보관함도 포화해도(실측상
  3스테이지쯤) 화면은 **그대로 카드 2택으로 열린다**. `GROWTH_CAP_AUTO_RUNE_DRAFT`는
  **`false`로 고정**됐다(상수는 `balance_probe` ⑭가 스위치 표기로 읽으므로 남겼다).
  달라지는 것은 둘뿐 — 기본 포커스가 **취소**(`GROWTH_CAP_DEFAULT_CANCEL`)이고,
  보상이 `GROWTH_CAP_CANCEL_BONUS(1.5)`로 할증된다(1스테이지 45 G = 상점 카드 1장 값).
  카운터 `growth_cap_conversions`는 이제 "천장에서 열린 레벨업 수"다(저장 키 무변경).
  결과 화면 문구도 `성장 천장 전환 N회` → **`성장 천장 레벨업 N회`**.
  **판단 근거**: 자동 전환은 "플레이어가 아무것도 안 골랐는데 화면이 바뀐다"는 점에서
  피드백 ③의 방향(읽고 판단할 것을 줄인다 ≠ 판단을 뺏는다)과 어긋난다.
- **보스 트로피 5종**(v2 계보 각성의 대체품). 보스를 잡을 때마다 두 가지를 함께 받는다.
  - ① **중립 스탯 보너스 1개 — 고정.** 스테이지가 정한다(선택지가 아니다).
  - ② **특별 카드 2택1.** 고른 쪽은 내 레일에, **버린 쪽은 마왕에게.**
  - 5회 누적 = 체력 +58 · 피해 +18 · 전체 피해 ×1.288 · 치명타 +8% · 관통 +1 ·
    투사체 +1 · 수호막 +2 · 사거리 +34 · 처치 회복 +1.5.
    이 누적치는 `balance_probe`의 `demon_ttk`가 마왕전 창(60~120초)과 **함께** 검증했다
    (Y8 실측 · 정규 경로 **85초**).
  - 스테이지 1~3은 상급, 4~5는 전설 트로피다(강화 보스가 전설을 떨군다).

### 7.8 아이템 = 장비 4부위

- 57종 전량 유지. **칸을 차지하지 않는다.** 무기·목걸이·반지·팔찌 각 1개.
- 효과는 `_all`(전체) · `_next`/`_previous`(바늘 기준 앞뒤 칸) · `_paired`(현재 칸)
  스코프로 적용된다. 바늘 문맥은 **실행 시점**에 다시 계산된다.

### 7.9 균열

- **dwell 1·3**에 플레이어로부터 900~1,400px 링 안에 열린다.
  **스테이지당 2회 · 런 최대 10회** 예산.
- 접근하면 정예 3~5기. 정예는 체력 ×3 · 넉백 저항 · 비디스폰.
- 전멸시키면 각인 3택1 + 60 G + 체력 전회복.
- 좌표는 스테이지 시드로 결정적이다. 이어하기 후에도 같은 자리에 열린다.

### 7.10 성 · 캠프와 NPC 4종

| NPC | 하는 일 |
|---|---|
| 카드 상점 | 스킬 2 + 장비 2 제안, 새로고침 가능(드래프트 풀에서만) |
| **각인 세공사** | **카드 3장 진열 + 개별 값표 + 새로고침**(X1 신설 · Y3가 레이아웃 재작성). 아래 별도 표 |
| 계약자 | **정비**(dwell −1 · 120 + 60×사용횟수 G) / **탐욕**(dwell +1 → 200 G + 각인 조각) / **영웅 각인**(dwell +2). 거래당 2회 |
| 밀정 | **마왕의 각인 이름 무료 기본 공개** / **각인 있는 칸 중 무작위 1칸을 통째로 지우기**(`SPY_WIPE_COST` **120 G** · **스테이지당 1회**) |

#### 밀정 리뉴얼 (Y3 · 사용자 피드백 ⑪)

| 축 | 이전 | **현재** |
|---|---|---|
| 열람 | `SPY_REVEAL_COST` **35 G** | **삭제 · 무료 기본 공개**(들어가면 이미 보인다) |
| 지우기 값 | 85 G | **`SPY_WIPE_COST` 120 G** |
| 지우는 대상 | 각인 최다 칸의 **마지막 1개** | **각인이 있는 칸 중 무작위 1칸을 통째로** |
| 횟수 제한 | 없음 | **스테이지당 1회**(`spy_wipe_stage` 저장 키) |
| 버튼 | 3개 | **2개** |

#### 각인 세공사 경제 (X1 · 사용자 피드백 ④ · Y2가 레일 할증 가산)

```
값 = (희귀도 기본가 + 18 × 구매횟수) × 흐름 1.25 × 확정 1.15 × 레일 1.20
     × 굴림(0.85~1.15) × 상점가 스테이지 스케일
새로고침 = (20 + 15 × 굴린횟수) × 상점가 스테이지 스케일
```

| 항 | 상수 | 값 | 이유 |
|---|---|---|---|
| 일반 | `RUNE_SHOP_PRICE_COMMON` | 45 | 구 `RUNE_SHOP_BASE_PRICE(70)`를 3등급으로 쪼갠 것 |
| 희귀 | `RUNE_SHOP_PRICE_RARE` | 80 | |
| 영웅 | `RUNE_SHOP_PRICE_EPIC` | 135 | |
| 구매 계단 | `RUNE_SHOP_PURCHASE_STEP` | 18 | 한 방문에 여러 개를 살 수 있어 계단이 없으면 각인 무한 공급 |
| 흐름 할증 | `RUNE_SHOP_FLOW_PREMIUM` | ×1.25 | 흐름 각인은 바늘 자체를 움직여 빌드를 **만든다** |
| 확정 할증 | `RUNE_SHOP_PASSIVE_PREMIUM` | ×1.15 | 확정(`roll == false`) 각인은 **굴리지 않고 항상 켜져 있다** |
| **레일 할증** | **`RUNE_SHOP_RAIL_PREMIUM`** | **×1.20** | 레일 각인은 칸 하나가 아니라 **다섯 칸 전부**에 걸린다(Y2 신설 · `_rune_offer_price()`에 배선 · 실측 사다리 **+6.7%**) |
| 굴림 할증 | `RUNE_SHOP_ROLL_PREMIUM_MIN/MAX` | ×0.85~1.15 | 같은 각인도 `roll_rune()`이 굴린 확률에 따라 값이 다르다 = "효과가 좋을수록 더 낸다"의 인스턴스 축 |
| 새로고침 | `RUNE_SHOP_REROLL_BASE/STEP` | 20 / +15 | 20 → 35 → 50 … **세 번 굴리면 105 G로 희귀 각인 1개(80 G)를 넘는다** — "영웅 뜰 때까지 돌리기"가 값으로 막힌다 |

- 정규 사다리(스테이지마다 1개) 총액은 일반만 **752 G** · 희귀만 1,049 G였다
  (**X1 시점 계산** — 당시 런 예산 가정은 1,552 G였다). 구식 `70 + 30n`(1,210 G)보다
  **오히려 싸다** — 진열이 선택권을 주는 대신 단가를 낮췄다.
  ⚠️ **런 예산의 현재 값은 아래 「골드 수지」의 총수입 2,976 G다**(Y8 실측 2,834 + 상자 스케일 +142).
- **진열 규약** — 생성기는 `_roll_rune_draft()`를 **그대로 재사용**한다(희귀도 가중·흐름
  억제가 드래프트와 어긋날 수 없다). 같은 성 안에서는 재방문해도 진열 유지
  (`rune_shop_castle_id`), 다른 성으로 가면 새로 깐다 — 카드 상점과 **완전히 같은 규약**.
  구매하면 그 장만 빠지고 **남은 두 장은 마왕에게 가지 않는다**(돈 낸 물건의 나머지다).
  구매 후 2단계는 기존 `_show_rune_target()`("강화할 칸을 고르세요")을 그대로 쓴다.
- ⚠️ **진열 카드는 `choice_buttons`에 등록하지 않는다.** 상점은 `camp` 상태이고 단일 포커스
  모델은 `choice`/`rune_draft`/`item_choice` 세 상태의 계약이다. 전용 배열 `rune_shop_buttons`를 쓴다.
- **레이아웃(Y3 · 사용자 피드백 ⑨⑩)** — 하단 버튼 **4개 → 하나**로 줄이고, **새로고침을
  진열대 자리**(카드 옆)로 옮겼다. 「카드 합성」·「칸 배율 강화」는 **카드상으로 이사**했다.
  보유 골드는 **코인 그림 + 큰 칩**으로 크게 띄우고, 카드마다 **칸/레일 배지**가 붙어
  "이건 칸에 붙는다 / 이건 레일 전체에 붙는다"를 값 옆에서 말한다.
- ⚠️ **진열 3장이 전부 레일 각인일 수 있다.** 칸 선택 2단계를 여는 코드는
  `_first_slot_offer_index()` / `_open_slot_rune_draft()`를 쓸 것 — 인덱스 0을 그냥 집으면
  붙일 칸이 없는 각인에서 2단계가 빈 화면으로 열린다.

- **상점가는 스테이지 스케일을 탄다**: `STAGE_PRICE_STEP` **0.25**(구 0.35) →
  `1 + 0.25 × (스테이지 − 1)` → 5스테이지 **×2.00**.
  계약에는 걸지 않는다(정비 비용이 이미 사용 횟수 축을 쓴다).
- ⚠️ **V10의 판정 지표(「5st/1st 누적 구매력 1.5~2.5배」)는 은퇴했다** —
  **이미 쓴 돈을 안 세는** 지표였다. Y8이 그 자리에 아래 「골드 수지」를 놓았다.
- **베이스캠프**는 성과 같은 NPC 공간이고 **스테이지당 완전회복 1회**(`camp_rest_used`)를 더 준다.
- ⚠️ **성 안에서는 5초 자동 저장이 돌지 않는다**(`_process`가 맨 위에서 return한다).
  V10이 `_exit_castle_now()` 끝에 저장 1회를 넣어 그 구멍을 닫았다.

#### 골드 수지 (Y8 실측)

⚠️ **바구니를 정의하지 않으면 아무 값이나 나온다.** 같은 런에서 진행 지출만 세면
여유 51.6%, 완전 지출을 세면 23.7%다. **바구니는 「각인 세공사 1개 + 상점 2점 +
밀정 칸 지우기 1회」로 고정한다.**

| 축 | 값 |
|---|---:|
| 총수입 | **2,976 G** *(Y8 실측 2,834 + 필드 상자 스테이지 스케일 +142)* |
| 사건 유입(스테이지별) | 100 / 132 / 136 / 149 / 163 G — **스테이지 수입의 22~24%** |
| 완전 지출 | **2,271 G** |
| **골드 여유** | **23.7%** (목표 창 **15~30%**) |
| 취소 전량 상한선 | 1,095 G = 총수입의 39% |
| `CHOICE_CANCEL_GOLD` | 30 (유지) |

5스테이지 통과 시점 실측: **레벨 27 · 15일차 · 등급 A**.

### 7.11 밤과 잠식

- 밤 길이는 스테이지마다 다르다(45초 → 78초). **5스테이지는 한 주기의 62%가 밤이다** —
  필터를 씌우는 것보다 "거의 항상 밤"이 훨씬 강한 험악함이다.
- **dwell ≥ 2부터 매 밤 전조 1기** — 마왕의 다섯 칸 중 하나를 실제로 시연하는 중형 마물.
  체력은 일반 몹 ×6. 격파하면 **각인 뜯기**(마왕의 각인 영구 제거) 또는
  **카드 회수**(마왕 레일의 카드 1장을 내 보관함으로) 중 하나를 고른다.
- **잠식(蠶食)** — v2 월식의 후신. dwell이 스테이지 임계(4/4/3/3/2)에 닿으면 켜지고
  **스테이지를 클리어하면 풀린다**(v2는 런 끝까지 유지였다). 켜져 있는 동안 필드에
  나오는 모든 마물이 마왕의 잔재 모듈 1개를 확정으로 받고 각인 1개를 능력치로 환산해
  지닌다(체력 ×1.22 · 피해 ×1.16 · 속도 ×1.05).

### 7.12 마왕

- **플레이어와 완전히 같은 런타임을 쓴다.** 5칸 · **칸 각인** · RELOAD 전부 동일.
  다른 것은 셋뿐 — `reload_scale = 0.42`, `hp_multiplier`, **상태이상 면역**.
  ⚠️ **마왕은 레일 각인을 갖지 않는다**(`set_rune_catalog()`가 `ids_by_scope("slot")`만 받는다).
- HP 배율 = `(1 + 0.05 × 총일수) × (1 + 0.15 × 격파 스테이지)`.
  16일·5스테이지 기준 ×3.6. 기저는 `1180 + min(부채,45)×22 + 아이템×170 + power×110`.
- 공략 문법: **밟은 칸을 보고 RELOAD(반격 창 1.3~1.9초)에 때린다.**
  상단 마왕 레일 밴드가 바늘·밟은 칸·RELOAD를 플레이어 레일과 같은 시각 언어로 보여 준다.
  밴드 표기는 **「밟은 칸 N / 5 · 한 칸 최대 N번」**이다 —
  8단 과열 사다리와 `BOSS_RAIL_HEAT_RECT`는 삭제됐다.
- 초상은 `portrait-demon-lord-48.png`를 **2배(96×96)**로 띄우는 `TextureRect`다(Y4 ·
  피드백 ⑧). 절차 렌더 스크립트는 함께 사라졌다 — §5의 `pixel_portrait.gd` 경고.
- 하수인 소환은 체력 구간(0.72/0.45/0.22)에서 발동.
- **진입은 5스테이지 보스 격파 직후 자동**이다. 필드를 거치지 않는다.

#### 마왕전 시나리오 7종 (Y8 실측)

| 경로 | TTK |
|---|---:|
| 1스테이지 직행 | 36초 |
| 3스테이지 도달 | 78초 |
| **5스테이지 정규** | **85초** |
| 과파밍 | 122초 |
| 강림 밸브 | 96초 |
| 트로피 3/5 | 154초 |
| 트로피 0/5 | 230초 |

⚠️ **일곱을 같은 창에 넣지 말 것.** 트로피 보유 수가 `raw_dps`를 151.7 → 415.8로
**2.7배** 벌린다. 목표 창 60~120초는 **정규 경로 하나만** 판정한다.

### 7.13 결과 화면

**5스테이지 타임라인 5칸** · 총 일수 · 승리 등급 · **「한 바퀴 최다 칸」 `%d / 10`** ·
보스 트로피 수와 등급 · **시너지 발동 횟수**(v3 신규 지표) · 상태 반응/도트 틱 ·
반격 창 · 각인 수 · 마왕 카드/각인 · 균열 클리어 · 처치 수 ·
**`성장 천장 레벨업 N회`**(X1이 `성장 천장 전환 N회`에서 바꿨다 — 자동 전환이 없어졌으므로
"전환"은 거짓이다) · 양쪽 5칸 대조.

**Y4가 고친 것 (사용자 피드백 ㉔ — "결과 화면이 깨져 보인다")**

| 축 | 이전 | **현재** |
|---|---|---|
| 최고치 칩 | 「최고 과열」 | **「한 바퀴 최다 칸」 `%d / 10`**(`run_peak_steps`) |
| 레일 구역 | 판 없이 흩어져 있었다 | **SLATE 무대 창 안**으로 들어갔다 — `ResultRailStage`가 5칸을 전부 감싼다 |
| 겹침 | 창이 마왕 요약 띠를 먹었다 | 창 아래끝이 **y456을 안 먹는다** |
| 캡처 | 패배 컷만 있었다 | **`result-y4-won.png` 신설** — 승리 컷이 자기 이름으로 남는다 |

**v2의 7일 기한 어휘는 하나도 남아 있지 않다** — `--boss-test`의 `result` 묶음이
필수 문자열과 금지 어휘를 함께 감시한다(X1·Y4가 그 필수 문자열도 같이 갱신했다).

---

## 8. 무한 맵과 WFC 구현 상세

### 논문 적용 방식

Simple Tiled WFC(Maxim Gumin)를 32×32 청크 단위로 적용한다.

1. 청크 좌표를 시드로 삼아 결정적 RNG를 만든다(스테이지 시드에서 파생).
2. 각 셀의 후보 집합을 전체 타일로 초기화한다.
3. **엔트로피 최소** 셀을 골라 가중 무작위로 붕괴시킨다.
4. 인접 규칙(`TILE_RULES`)을 이웃으로 전파한다.
5. 모순이 생기면 그 청크만 다른 시드로 재시작한다(전역 롤백 없음).
6. 청크 경계는 이웃 청크의 확정 타일을 제약으로 받아 이음매가 생기지 않는다.

- 청크 캐시 상한이 있어 메모리가 무한히 늘지 않는다(`--world-test`가 `bounded`로 감시).
- 스테이지 랜드마크(성·캠프·보스문)와 동적 균열은 WFC보다 **우선한다**.
- 지형 아틀라스는 **3벌**(`verdant` / `waste` / `abyss`)이고 전부 160×128(5열×4행, 셀 32×32)
  규격이 같아 `TILE_RULES`의 셀 번호 계약이 무변경이다.
  스테이지별 배치는 `GameTuning.STAGE_TERRAIN_ATLAS`.
- ⚠️ **`ATLAS_CELL_INSET`을 0에서 올리지 말 것.** 1px만 깎아도 물가의 흰 포말 선이
  잘려 호수 가장자리가 두 번 끊긴다.

---

## 9. 에셋과 시각 디자인

### 현재 스타일

16px 원본 픽셀 스프라이트를 **nearest 정수배 ×2**로 확대해 쓴다(마왕만 ×3).

**UI도 같은 세계다(U0~U3 재스킨 완료).** v1의 어두운 남색 도형 패널은 사라졌고
모든 표면이 `art/v2/ui-kit-*.png` 10장의 9-slice로 그려진다 — 톤 7종
(PARCHMENT · WOOD · SLATE · ABYSS · EMBER · GOLD · 중립), 역할 5종(패널·함몰·칩·칸·포커스링),
폰트 5단(26/17/13/12/11), `corner_radius` 0. 강조는 **프레임(톤·역할)** 으로 하고
테두리에 강조색을 쓰지 않는다. 의미색(원소·희귀도·각인 계열)은
`GamePalette`가 계속 소유하며 **글자와 안쪽 색판에만** 쓴다.
**규격의 단일 진실 원천은 `docs/ui-style-v3.md`다.**

⚠️ **예외 하나 — 필드 HUD에는 판이 없다**(X3). 위 문장의 "모든 표면"은 로비·온보딩·모달·
편집 화면·성·결과 화면을 말한다. 필드 HUD의 상시 킷 판 5장은 X3가 전부 걷었고
남은 킷 9-slice는 레일 칸 5 + 고스트 칸 5의 CELL뿐이다 — 아래 별도 절.

> 픽셀 밀도는 **UI 2.0 : 필드 2.5**로 다르다(필드는 32px 셀을 40px 타일에 그린다).
> UI만 정수 배율을 지킬 수 있어서 반듯한 쪽을 택한 의도적 차이다 —
> 뒤집으려면 지형을 32px 타일로 옮기는 게 먼저다(`ui-style-v3.md` §1).

### 원소 색 언어 — **단일 진실 원천은 `game.gd`의 `ELEMENT_COLOR`** (X1 신설)

속성은 **텍스트가 아니라 색**으로 말한다(사용자 확정). 새 색표를 만들지 말고
**`_element_color(element)`를 부를 것.** `RAIL_ELEMENT_MARK`(색약 대비용 1글자 마크)와
**키가 같다**(둘 다 7키).

| id(불변) | 표시 이름 | 마크 | 색 hex | 색 이름 | `GamePalette` |
|---|---|---|---|---|---|
| `fire` | 불 | 불 | **`e2452f`** | 빨강 | `EMBER_RED` |
| `ice` | 얼음 | 얼 | `67c7d4` | 하늘 | `CYAN` |
| `thunder` | 번개 | 번 | `f4d35e` | 노랑 | `YELLOW` |
| `poison` | 독 | 독 | `83c65c` | 연두 | `GREEN` |
| `oil` | 기름 | 기 | **`7a5230`** | 갈색 | `OIL_BROWN` |
| `strike` | 타격 | 타 | `c3bda4` | 회색 | `STONE_LIGHT` |
| `psi` | 정신 | 정 | `bd6ac8` | 자주 | `MAGENTA` |

**Y4가 두 색을 교체했다**(사용자 피드백 ㉑ — "속성 구별이 안 된다").
fire `e78a45`(주황) → **`e2452f`(빨강)** · oil `7563a8`(보라) → **`7a5230`(갈색)**.
구판은 oil 보라와 psi 자주가 붙어 **일곱 중 여섯 색으로 읽혔다**.

**새 계약: 일곱 색이 서로 다르다.** 이제 그것이 자동 검사 대상이다.

- `RAIL_ELEMENT_MARK`가 `화빙뇌독유타초` → **`불얼번독기타정`**으로 바뀌었다.
  ⚠️ **손으로 적지 말 것** — 검사가 「마크 == `DealCardLibrary.element_name()`의 첫 글자」를
  문다. 표시 이름을 고치면 마크가 자동으로 따라가야 한다.
- **`_factory_card_color()`가 데이터 `color` 키가 아니라 원소를 본다**(Y4).
  분기는 셋뿐이다 — 보스 패턴은 자기 색 / 아이템은 등급색 / 그 밖은 전부 `ELEMENT_COLOR`.
  카드 데이터의 스테일 `color` 값이 화면으로 흘러들던 **11곳이 한 번에 나았다**.
- **`skill_icon.gd`가 `_reskin_to_element`로 아이콘 판 색을 따라온다.**
  배선은 `game.gd _ready()`의 `SKILL_ICON_SCRIPT.set_element_palette(ELEMENT_COLOR)` **한 줄**이다.

**같은 표를 보는 화면**: 레벨업 모달(X1) · ESC 편집 화면(X2) · 필드 HUD 미니 스트립과
마왕 고스트 레일(X3) · **스킬 아이콘 판**(Y4). v1의 `_factory_card_color()`(카드마다 따로
박힌 `color` 키)는 원소와 무관해서 같은 얼음 카드 넷이 서로 다른 색으로 나왔다 —
그 문제가 여기서 닫혔다.

#### 어두운 판 위에 원소색을 얹는 법 — `_element_wash()`

킷이 주는 색 조절기는 `StyleBoxTexture.modulate_color` **하나뿐이고 곱셈**이다.
카드 프레임 바탕이 주황(`#f38c4c`)이라 **청록을 곱하면 청록이 아니라 탁한 갈색**이 나오고,
찬 원소 셋(얼음·기름·정신)이 전부 "어두운 갈색"으로 뭉친다(X1 캡처 실측).
→ 반투명 `ColorRect` 한 겹(`_element_wash(parent, rect, tint, alpha)`)을 얹는다.
알파 합성이라 어두운 판 위에서도 색상(hue)이 그대로 올라온다.

| 층 | 강도 | 왜 |
|---|---|---|
| 카드/칸 프레임 `modulate_color` | `WHITE.lerp(색, 0.55)` | 따뜻한 원소에서 잘 먹고 프레임 문양이 살아 있다 |
| 본문 판 덧칠 | `0.14` (편집 칸 `0.16` · 손잡이 `0.20`) | 배경이 은은하게 물든다. 글자 대비 손실 없음 |
| **아이콘 블록 덧칠** | **`0.34`** | 사용자가 말한 "블록색". **여기가 색의 주역이다** |
| HUD 미니 칸 틴트 | `RAIL_SLOT_TINT_MIX_IDLE` 0.42(구 0.22) | 칸이 152×104 → 52×52로 줄어 색을 나르는 면적이 프레임 테두리뿐이다. 활성/비활성은 **밝기**로 갈리므로 채도를 올려도 안 섞인다 |

⚠️ **불투명한 칩이 알파 덧칠을 덮는다.** 강도가 아니라 **어느 층 위에 얹는가**가 문제다
(X2 §6.1 — 칸 층에만 깔았더니 손잡이와 카드 몸통이 통째로 덮어 색이 아예 안 나왔다).
그리고 **카드 몸통 전체를 칠하면 글자가 죽는다** — 아이콘이 앉는 사각형만 칠하고
글자 자리는 어두운 채로 둘 것.

### 필드 HUD는 이제 **판이 없다** (X3 · 사용자 피드백 ⑥)

| | 이전(W5/V5/U3) | **현재**(X3 + Y 라운드) |
|---|---:|---:|
| 상시 불투명 판 | 5장 (신상·스테이지·나침반·고스트·레일 밴드) | **0장** |
| block px / % | 292,488 / **31.74 %** | 계약 **≤ 3.35 %** · **현재 실측 3.19 %** |
| ink % | 31.74 % | **현재 실측 6.39 %**(YZ 한글 스윕 뒤 · Y4 시점 5.68) |
| **필드가 보이는 면적** | 68.3 % | **96.8 %** |
| 딜싸이클 | 1048×156 밴드 · 칸당 글자 4줄 | **358×74 아이콘 스트립 · Label 0개** |
| 위치 안내 | 나침반 패널 198×96 | **화면 가장자리 화살표**(`NAV_RING` 링 위) |
| 상시 문장(2자 이상 라벨) | — | **6개**뿐이고 그중 넷이 숫자다. 설명 문장(14자+) **0개** |

#### 딜싸이클 스트립 내부 규격 (Y2)

`RAIL_BAND_RECT` `(450,636) 380×74` → **`(461,636) 358×74`**.
과열 8핍이 쓰던 20px 자리를 빈 채로 두지 않고 스트립을 **22px 좁혔다**.
**가로 중심 640은 유지**되고 **세로 74는 무변경**이다.

| 요소 | 값 |
|---|---|
| `RAIL_SLOT_ORIGIN` | `(8,12)` |
| 칸 | `RAIL_SLOT_SIZE` 52 × 5 + `RAIL_SLOT_GAP` 10 × 4 = **300** |
| `RAIL_DIAL_RECT` | `(310, 14, 44, 44)` |
| `RAIL_DEBT_TRACK` | `(8, 66, 300, 4)` |

가로 증명: `8 | 8…308 (300) | 2 | 44 | 4 = 358`.

⚠️ **삭제된 심볼**: `rail_heat_segments` · `RAIL_HEAT_RECT` · `_heat_color()` ·
`_rail_heat_tooltip_spec()`. **스트립 툴팁에 「과열」이 제목·행·본문 어디에도 없다**가 계약이다.

#### Y 라운드가 바꾼 나머지 HUD

| 요소 | 이전 | **현재** |
|---|---|---|
| 상단 스테이지 줄 | 문장 | **관문 아이콘 5개 + 해/달 아이콘**. 판 신설 0. 스테이지 이름은 **툴팁 제목**이 갖는다 |
| 체력바 | 연속 막대 · 심장 20px | **세그먼트 `HUD_HEALTH_SEGMENTS` 12칸** · 심장 **26px**. 비율 1.0/0.5/0.25/0.0에서 정확히 12/6/3/0칸 |
| 재화 | 「N G」 문자열 | **금화 그림**(`_gold_chip()` + `ui-coin-pile`) |
| 소비 슬롯 | 없음 | **`Q` 1칸** `HUD_CONSUMABLE_RECT = Rect2(16, 646, 210, 46)` · **`Panel` 없음**(Y6) |
| 가장자리 화살표 | 4종 | **5종**(발견 사건 추가) |

판을 걷고도 읽히게 만드는 수단은 **판이 아니라 잉크 쪽 처방**이다:
`_label()` 외곽선 2/3px · 상호작용 안내와 흐름 배너는 **6px** · 화살표 거리는
`draw_string_outline(4px)` · 화살표 글리프 뒤 **로컬 스크림**(원 r=12 · α0.72) ·
게이지 트랙 반투명(α 0.72~0.82) · `_hud_ink()` 명도 하한 0.66.
남은 `block`의 59%는 **레일 칸 5 + 고스트 칸 5의 킷 CELL 9-slice**다 —
아이콘 뒤 배경이 필요한 유일한 자리다.

⚠️ **필드 HUD에 `Panel`을 새로 깔지 말 것.** `--cycle-test`의 `hud_mini`·`hud_ghost`가
`not (node is Panel)`을 단언한다. 배경이 꼭 필요하면 로컬 스크림을 쓴다.
좌표를 고치면 `hud_block_pct`가 로그에 바로 나온다 — 계약값 3.35%를 넘기 시작하면
그것이 곧 "블록이 돌아왔다"는 신호다.

#### 가장자리 화살표 내비 규약 5줄

| # | 규약 |
|---|---|
| ① | 대상이 화면 안 `NAV_HIDE_MARGIN`(56px) **안쪽**에 들어오면 화살표가 **사라진다** |
| ② | 대상 방향으로 링(`NAV_RING` = x 44~1236 · y 96~604) 위 한 점에 마커 **중심**이 붙는다 |
| ③ | 화살촉 + 대상 글리프 + 거리(m) 세 조각. **전부 정적**이다(깜빡임 0 · 트윈 0) |
| ④ | 색과 글리프가 대상을 구분한다 — 성 `YELLOW` 집 · 캠프 `GREEN` 천막 · 보스문 `RED` 해골 · 균열 `MAGENTA` 갈라진 금 · **발견 사건**(Y6 신설) |
| ⑤ | 성·캠프 내부, 보스전, 필드 밖에서는 층 전체가 꺼진다 |

**발견 게이팅(Y6 · 사용자 피드백 ⑱)** — 화살표는 **발견한 자리에만** 뜬다.
발견 조건은 거리 **≤ 520px**(`DISCOVER_RADIUS`) **또는** 대상이 `NAV_RING` 안에 들어옴이다.
**성과 캠프는 개시부터 발견 상태**다(두 곳은 길잡이의 약속이라 감추지 않는다).

링이 **사각형**인 이유는 원형 링이 네 귀퉁이를 못 써서 대각선 목적지 넷이 좁은 호에
몰리기 때문이다. 갱신은 `_process`에서 **매 프레임**이다(10Hz로 돌리면 이동 중
테두리에서 눈에 띄게 끊긴다). 월드 → 화면 변환은 **카메라 하나만** 지난다
(`get_viewport().get_canvas_transform() * 월드좌표`).

#### 카메라 흔들림 계약 (Y7 · 사용자 피드백 ㉕)

```
SHAKE_MAX_AMPLITUDE = 4px
SHAKE_MAX_DURATION  = 0.12초
```

⚠️ **성분마다 굴리면 대각선에서 √2배(5.66px)가 된다.**
`offset.x`와 `offset.y`를 각각 `randf_range(-4, 4)`로 굴리면 최악의 경우 길이가 5.66이다.
**각도를 굴리고 크기를 굴려야** `offset.length() ≤ 4.0`이 참이 된다.

| 허용 자리(다섯) | 지운 자리(넷) |
|---|---|
| 강림 | 무거운 카드 펄스 |
| 스테이지 보스 등장 | 잠식 스윕 |
| 페이즈 발구름 | 보스 격파 |
| 마왕 착탄 | 트로피 선택 |
| 플레이어 피격 | |

**계약 4축** (`--cycle-test cam`):

| # | 단언 |
|---|---|
| ① | 12초 실전에서 `cam_peak ≤ 4.0` |
| ② | **스킬 발사에서는 정확히 0.0**(내가 때릴 때는 화면이 안 흔들린다) |
| ③ | 보스 착탄에서 `0 < peak ≤ 4.0` |
| ④ | 설정에서 흔들림을 끄면 **정확히 0.0** |

#### HUD 좌표가 바뀐 자리 (온보딩 도식이나 길잡이 타깃이 참조한다면 여기를 볼 것)

| 요소 | 이전(W5/V5/U3) | **현재** |
|---|---|---|
| 신상 | `(16,10) 330×132` | `(16,8) 256×56` |
| 스테이지 | `(358,10) 440×96` | `(440,2) 400×62` |
| 나침반 | `(806,10) 198×96` | **없음** → `NAV_RING` 링 |
| 마왕 고스트 | `(1012,10) 252×96` | `(1094,8) 170×34` |
| 보스 체력 | `(356,116) 444×70` | `(370,66) 430×40` |
| 상호작용 안내 | `(340,486) 600×42` | `(340,470) 600×30` |
| 흐름 배너 | `(216,532) 1048×22` | `(340,606) 600×22` |
| 딜싸이클 | `(216,556) 1048×156` | `(450,636) 380×74` → **Y2가 `(461,636) 358×74`로** |
| 소비 슬롯 `Q` | 없음 | **`(16,646) 210×46`**(Y6 신설 · `Panel` 없음) |

길잡이 타깃(`_guide_target_rect`)은 `RAIL_*` · `HUD_GHOST_RECT` · `_nav_guide_rect()`를
참조한다 — HUD 좌표를 옮기면 `--guide-test aim`이 먼저 잡는다.
온보딩 도식은 이 좌표를 참조하지 **않는다**(자기 좌표계를 쓴다 · X4가 확인).

### 스테이지 그레이드 (v3 신규)

**사전 빌드 3벌 + 런타임 그레이드 하이브리드**다. 곱연산 틴트만으로는 잔디가 사막이
되지 않고(채도만 죽는다), 아틀라스 5벌은 과하다 — 실측 결과 소스 팔레트가 4종뿐이었다.

| 축 | 스테이지 1 → 5 |
|---|---|
| 아틀라스 | verdant · verdant · waste · waste · abyss |
| 낮 색조 | `#ffffff` → `#8a7794` |
| 밤 색조 | `#8995c9` → `#2f2f52` |
| 안개 알파 | 0.00 → 0.24 (**정적 타일 쿼드** — 흐르게 하지 않는다) |
| 채도 | 1.00 · 0.88 · 1.00 · 1.00 · 0.65 |
| 비네트 | 5스테이지만 |
| **낮/밤 길이** | 72/45 → 48/78 — **그래픽 가중치의 절반이 이것이다** |

로드 직후에는 `_snap_world_lighting()`이 **보간 없이** 그 스테이지 값으로 맞춘다.
이게 없으면 5스테이지 밤으로 이어하기할 때 화면이 한 번 하얗게 번쩍인다.

### 크레딧

- **Ninja Adventure Asset Pack** — Pixel-boy & AAA · CC0
- **Kenney Particle Pack** — Kenney · CC0

둘 다 CC0라 표기 의무는 없지만 README와 `art/v2/ASSET_MAP.md` §8에 남겼다.

⚠️ **CC BY 의무가 하나 있다(YA).** `art/external/game-icons/`의 **113 SVG**는 CC BY 3.0이고
작가가 아홉 명이다 — Lorc 68 · Delapouite 31 · Sbed 5 · Skoll 3 · Willdabeast 2 ·
Felbrigg 1 · DarkZaitzev 1 · Cathelineau 1 · Carl Olsen 1.
크레딧 블록 원본은 `art/external/LICENSES.md` §6에 있다.
**현재 산출물 중 이 팩에 의존하는 것은 0개다** — 게임 안에 크레딧을 넣든지 팩을 지우든지
둘 중 하나를 골라야 하고, 지우면 의무가 함께 사라진다(§12).

### 에셋 파이프라인

```bash
godot --headless --path godot-game --script res://art/v2/build_assets.gd   # PNG 재생성
godot --headless --path godot-game --editor --quit                         # .import 갱신 (필수)
```

매핑을 바꾸려면 `build_assets.gd` 상단 상수표만 고친다. 전체 좌표표는 `art/v2/ASSET_MAP.md`.

**파이프라인이 지키는 규칙 3가지**

1. 확대는 nearest 정수배 ×2 한 종류(마왕만 ×3).
2. 합성은 16px 원본 좌표계에서 끝내고 **마지막에 딱 한 번** 확대한다.
3. **방향성 VFX는 빌드 단계에서 전부 +X로 돌려 굽는다.** 런타임에서 축을 보정하려
   들지 말 것 — v1이 그러다 이펙트가 180° 뒤집혔다.

### 색 변조는 마스크 덧그리기로 한다 (셰이더 아님)

캐릭터·몹·보스 시트는 아래 절반에 흰 실루엣 마스크가 한 벌 더 붙어 있다.
스프라이트를 그린 뒤 마스크를 원하는 색·알파로 덧그리면 색조가 바뀐다.
ShaderMaterial을 쓰지 않는 이유는 머티리얼이 CanvasItem 단위라 같은 `_draw()` 안의
체력바·상태 핍·왕관까지 전부 물들기 때문이다.

| 표현 | 마스크 색 |
|---|---|
| 피격 플래시 | `Color(1,1,1, 0.85)` |
| 밤 변이 | `Color(0.42, 0.10, 0.20, night_form_amount × 0.55)` |
| 사이클 둔화 | `Color(CYAN, 0.22)` |
| 경직 | `Color(0.78, 0.84, 1.0, 0.30)` |
| 강화형 보스 변종 | `B+` `9a5bb5` · `C+` `3b2b46` (같은 시트를 색만 다시 구워 만든다) |

**상태 핍**은 적 머리 위 최대 3개(8×8 색 사각, y ≈ −radius−32)다.
`enemy._draw_field_monster()`의 기존 if/elif 마커 체인은 배타적이라 끼우지 말고
**별도 루프**로 그린다.

### 교체하지 **않은** 것과 그 이유

| 대상 | 결정 | 근거 |
|---|---|---|
| 스킬 아이콘 아틀라스 | v1 유지 + **Y4가 색만 원소로 재스킨**(`_reskin_to_element`) | NA 아이콘 32종에 딜싸이클의 핵심 개념(밟은 칸·빚)에 대응하는 그림이 없다. ⚠️ **`ui-kit-skill-shape.png`(14칸 실루엣)가 구워지면** `skill_icon.gd`의 `GENERATED_SKILL_INDEX`를 실루엣 인덱스로 다시 쓰면 되고 `_reskin_to_element`는 그대로 둔다 |
| 아이템 아이콘 아틀라스 | v1 유지 | NA 아이콘 12종으로는 장비 57종을 못 덮는다 |
| 트로피 카드 12종(`SPECIALS`) | **벡터 드로잉 유지** | 아틀라스가 **7×4 = 28칸 고정**이라 자리가 없다 |
| HUD 아이콘 아틀라스(`generated_ui_icon.gd`) | v1 유지 | 아이콘 그림 자체는 정보다. U3가 표면만 킷 9-slice로 갈았을 때는 좌표가 무변경이었으나, **X3가 판을 걷으면서 좌표 계약을 다시 짰다**(위 표) |
| 화살표 내비 글리프 4종(집·천막·해골·균열) | **절차적으로 직접 그린다** | 킷 글리프 16종에 넷이 없고, 넣으면 시트가 2행 → 3행이 되어 `UIKit.GLYPH_INDEX` 계약을 건드린다(그 시트는 **다른 화면 전부**가 쓴다). 게다가 화살촉은 **임의 각도로 돌아야** 하는데 킷 포인터는 4방향뿐이라 대각선에서 방향이 거짓말을 한다 |
| 로비 배경 · 캐릭터 카드 | **U1이 교체** | AI 생성 야경 1장 → **게임 아틀라스로 그린 정적 필드 디오라마**, 카드 초상 → NA 스프라이트 실물. 구도(왼쪽 성·오른쪽 마왕성·검을 든 주인공)는 그대로 옮겼다. v1 PNG는 지우지 않고 `preload`만 끊었다 |
| 파티클·균열 렌더 | 절차적 유지 | 색이 곧 정보다(원소·희귀도) |
| 보스 A의 Attack 애니메이션 | **없는 채로 설계에 흡수** | A의 공격은 팔이 아니라 **발구름 → 바닥 링 확산**이다. 사지 애니메이션이 필요 없다 |

### 시각 QA 화면

`godot-game/art/screenshots/qa/`에 캡처가 저장된다(15종). 목록·검수 기준은 §11.

---

## 10. v3 개편이 무엇을 바꿨는가 (v2 → v3 대조)

> 이 표는 **v2 → v3 축만** 다룬다. 그 뒤 UI 재스킨(U0~U3) · 1차 피드백 라운드(X1~X4) ·
> **2차 피드백 라운드(Y0~Y8·YA·YZ)** 가 더 바꾼 것은 §15의 해당 항목과 §4·§7·§9·§11에 있다.
> 특히 **Y 라운드는 게임 규칙 자체를 바꿨다**(과열 폐기 · 각인 15종 · dwell 곡선 ·
> 보스 HP · schema 4). **아래 표의 v3 열을 "현재 값"으로 읽지 말 것 — 역사 기록이다.**

| 항목 | v2 | v3 |
|---|---|---|
| 구조 | 단일 무한 필드 | **5스테이지** — 각각 무한 필드 + 성 1 + 캠프 1 + 보스방 1 |
| 기한 | **7일 = 819초** 하드 기한 | **없음.** 총 일수는 기록용 · 압박은 dwell 곡선이 만든다 |
| 시간 구조 | 낮 72 / 밤 45초 고정 | **스테이지마다 다르다** (72/45 → 48/78) |
| 난도 상승 | 일차 기반 | **dwell 기반** — HP `1+0.14d+0.012d²`, 보상은 `H^0.5` *(당시 값 — Y8이 `1+0.13d+0.010d²`로 재확정했다)* |
| 보스 | 마왕 1체 | **스테이지 보스 3종 로테이션 `[A,B,C,B+,C+]` + 마왕** |
| 보스 진입 | 마왕성 도달 / 7일차 강림 | **보스방 E → 프리뷰 → 전투.** 5스테이지 격파 = 마왕전 직행 |
| 안전 밸브 | 7일차 밤 종료 강림 | **dwell 14/13/12/11/10 강림**(등급 C 고정) |
| 전직/각성 | 계보 3종 + 각성 2단계 | **폐기 → 보스 트로피 5종**(고정 스탯 + 특별 카드 2택1) |
| 전투 레이어 | 원소 태그(공명·결속·삼각)만 | **+ 상태이상 5종 · 반응 매트릭스 11종** *(Y 라운드가 결속·삼각을 삭제해 지금은 공명만 남았다)* |
| 카드 어휘 | 직장 풍자 30여 종 | **전면 판타지**(`id` 무변경) |
| 월식 | 5일차 · 런 끝까지 | **잠식** — dwell 임계 · **스테이지 클리어 시 해제** |
| 균열 | 2·4·6일차 · 런당 3 | **dwell 1·3 · 스테이지당 2 · 런 최대 10** |
| 전조 | 3일차 밤부터 | **dwell ≥ 2부터 · 전 스테이지** |
| 승리 등급 | 3일 S / 5일 A | **총 일수** S≤13 / A≤17 / B≤23 |
| 계약자 | 하루를 사고판다 | **dwell을 사고판다** |
| 상점가 | 고정 | **스테이지 스케일 ×1.00 → ×2.40** *(당시 값 — Y8이 `STAGE_PRICE_STEP` 0.25로 내려 ×2.00이 됐다)* |
| 그래픽 | 단일 톤 | **스테이지 5단 그레이드**(아틀라스 3벌 + 틴트·안개·채도·비네트) |
| 저장 | schema 2 (37키) | **schema 3 (48키)** · v1·v2 폐기 *(당시 값 — Y6이 schema 4 · 53키로 올렸다)* |
| 마왕 HP | `1 + 0.22 × (일수−1)` | `(1 + 0.05 × 총일수) × (1 + 0.15 × 격파 스테이지)` |
| 자동 검사 | 기능 12종 | **기능 14종**(`--stage-test` · `--status-test` · `--guide-test` 신설, `--deadline-test` 삭제) *(당시 값 — Y5·Y6이 `--field-test`·`--event-test`를 더해 16종이 됐다)* |

<details>
<summary>v1 → v2 대조 (기록 보존)</summary>

| 항목 | v1 | v2 |
|---|---|---|
| 칸 수 | 3~10 (가로 스크롤) | **5 고정 · 무스크롤** |
| 레인 | 슬롯당 최대 3 (분열) | **1** — 연결·합주 각인이 대체 *(v2 당시 · 두 각인은 Y1이 `twin_cast`로 합쳤다)* |
| 실행 | 좌→우 1회 | **바늘 + 확률적 흐름 조작** |
| 강화 | 슬롯 repeat/duration/reload | **각인 24종, 칸에 부착** *(v3 당시 · Y 라운드에서 각인 15종으로 바뀌었다)* |
| RELOAD | 한 바퀴 후 합계 | **빚 누적 × 과열 배율** *(v3 당시 · Y 라운드에서 선형 빚으로 바뀌었다)* |
| 아이템 | 칸을 차지 (57종) | **장비 4부위, 레일 밖** |
| 최대 랭크 | 5 (16장) | **3** (4장) |
| 시련 | 동서남북 고정 4곳 | **동적 균열 3회** |
| 마왕 | 10칸×2레인, RELOAD 없음 | **5칸, 각인 보유, RELOAD ×0.6** *(v2 당시 · 현재는 ×0.42)* |
| 시각 | 절차적 도형 렌더 | **Ninja Adventure 픽셀 스프라이트** |

</details>

---

## 11. 자동 테스트와 시각 QA

### 전체 실행

```bash
bash godot-game/scripts/test/run_all.sh          # 컴파일 1 + 기능 검사 16종. 종료 코드 0 = 전부 PASS
bash godot-game/scripts/test/run_all.sh --boss-test   # 지정한 것만
```

**FAIL 판정 조건** (하나라도 걸리면 FAIL): ①종료 코드 ≠ 0 ②기대한 `*_TEST_COMPLETE`
줄이 없음 ③출력에 `=false`가 있음 ④출력에 `SCRIPT ERROR` / `ERROR:`가 있음.
그래서 **새 검사의 출력에 `=false`가 될 수 있는 문자열을 넣지 말 것**
(독립 프로브는 `pass=1`/`pass=0`을 쓴다).

전체 소요는 약 **130초**다(Y5·Y6이 두 종을 더하면서 늘었다. YZ 실측 126초 2회 연속 · Y8 시점 135초).

### 기능 검사 16종 + 컴파일 (요약표는 17행)

| 플래그 | 마커 | 무엇을 지키는가 |
|---|---|---|
| `--editor --quit` | (컴파일) | 파스 에러·리소스 누락 0 |
| `--world-test` | `WORLD_TEST_COMPLETE` | WFC 결정성·이음매·스트리밍·캐시 상한·스테이지 랜드마크 |
| **`--field-test`** | **`FIELD_TEST_COMPLETE`** | **Y5 신설 · 필드 생태 런타임**(`--world-test` 바로 뒤에 돈다). `habit_wired`(습성 배선) · `habit_day`(낮 습성 5종) · `day_aggro_zero`(1·2스테이지 낮 선공 0 — **데이터 축 + 런타임 스폰 축 둘 다**) · `terrain_spawn`(지형 가중) · `herd_spawn`(무리와 개체 상한) · `rock_detour`(추적 중 돌 우회) |
| `--v4-test` | `V4_TEST_COMPLETE` | 5칸 초기화·칸 교환·각인 스택·합성·편집 레이아웃(스크롤 0)·아이템 장비화·모달 무적·보스 칸 수 · **`edit_minimal`**(X2) · **각인 글리프 3묶음**(Y3) · **Y4 4묶음** `y4_color`(원소색 일곱이 서로 다른가 · 한자 0건) `y4_icon` `y4_equip` `y4_chrome` |
| `--castle-test` | `CASTLE_TEST_COMPLETE` | 성 NPC 4종·상점·각인 세공사(진열·희귀도 가격 순서·흐름 할증·**레일 할증**·진열 유지·새로고침 계단 부등식·구매 시 마왕 조각 0)·**버튼 구성**·**dwell 계약 3종**·**밀정 전면 재작성**(무료 공개·120 G·칸 통째·스테이지당 1회)·**트로피 3묶음**·상점가 스테이지 스케일 |
| `--rift-test` | `RIFT_TEST_COMPLETE` | 균열 예산(스테이지 2 · 런 10)·dwell 1·3 스케줄·정예 웨이브·클리어 보상·스테이지 리셋 · **`event_budget` 신설**(Y6) |
| `--stress-test` | `STRESS_TEST_COMPLETE` | 마물 100기 이상에서 fps·개체 상한·공간 해시·**상태 오버헤드·반응 예산** · **`surge` 신설**(Y7 타격감이 붙은 뒤의 물량 폭주) |
| `--smoke-test` | `SMOKE_TEST_COMPLETE` | 런 시작→마왕전→결과까지 상태 전이 |
| `--combat-test` | `COMBAT_TEST_COMPLETE` | 12초 실시간 전투 · **상태 E2E·대폭 연소·전도·도트 킬·스테이지 배율** · **`impact_profile`**(impact 8종 + `stack_bonus`) · **`mob_reaction`**(몹별 피격 반응) |
| `--stage-test` | `STAGE_TEST_COMPLETE` | **스테이지 클럭·dwell 곡선·킬당 효율 설계표 대조·잠식·강림 밸브·이월·마왕 재보정** |
| `--status-test` | `STATUS_TEST_COMPLETE` | **상태 5종 기본값·반응 매트릭스 11종·대폭 연소 7.5배·전도·정신 붕괴·예산·결정성** |
| `--cycle-test` | `CYCLE_TEST_COMPLETE` | 바늘 런타임·흐름 각인·**`exec_cap`**(한 칸 두 번 상한)·**`rail_rune`**(레일 각인 주입)·**`twin_cast`**·빚 RELOAD·HUD 레일(스크롤 0) · `hud_mini`·`hud_nav`·`hud_rail`·`hud_ghost`(X3) · **`cam`**(카메라 흔들림 4축) · **`hud_stage`**(관문 아이콘 줄) · **`hud_health`**(세그먼트 12칸) |
| `--draft-test` | `DRAFT_TEST_COMPLETE` | 각인 드래프트 희귀도 분포·흐름 억제·**`stage_two` 전면 재작성**(레일 각인은 2단계를 건너뛴다)·조각→마왕 · `cancel` · `demon_floor` · `growth_cap` |
| `--boss-test` | `BOSS_TEST_COMPLETE` | **보스 3종 로테이션·보스방 전투 E2E·강화형·격파 전환·마왕 직행·강림 밸브·telegraph·페이즈·트로피 4경로·결과 화면**(「한 바퀴 최다 칸」 칩 · 금지 어휘) |
| `--save-test` | `SAVE_TEST_COMPLETE` | **이어하기 E2E** — 키 **53종**·지문 **72축**·전투 중 저장 차단·시각 복원·개명 폴백·스테이지 전이 왕복·로비 표기·**schema 3 이하 폐기와 로비 1회 고지** |
| `--guide-test` | `GUIDE_TEST_COMPLETE` | **스포트라이트 길잡이 17플래그**(U3 15 + X4 신설 2) — `contract` `trigger` `resume` `start` `policy` `move` `dash` `aim` `skip` `interact` `finish` `persist` `abort` `reset` `abandon` + **`freeze`** + **`diet`**. 스텝 표 계약·발동/이어하기/재방문·층 구성·저장 차단과 스폰 억제·이동/대시 통과·구멍 조준과 안내판 뒤집기·SPACE 개별 스킵·E와 ESC 키 흘려보내기·`guide_seen` 영속·ESC 확인 칩·설정 초기화·로비 복귀 시 미기록 |
| **`--event-test`** | **`EVENT_TEST_COMPLETE`** | **Y6 신설**(`--guide-test` 뒤에 돈다). `discover`(발견 게이팅 · **음성 축 포함**) · `schedule`(사건 예산과 시드 결정성) · `site`(사건 자리 계약) · `library`(사건 8종 데이터) · `combat`(전투형 사건 한 바퀴) · `quiet`(비전투형) · `items`(소비 아이템 8종의 실제 효과) · `chest`(배당표 합 100과 신설 두 칸의 발화) · `negative`(음성 대조) |

> `--guide-test`는 실기 설정 파일(`settings/guide_seen`)을 건드린다. 시작할 때 원래 값을
> 떠 두고 끝에서 되돌린다 — `--capture-lobby`가 세이브를 치우는 것과 같은 규약이다.

**X4가 신설한 두 묶음**

| 묶음 | 단언 |
|---|---|
| `freeze` | ⓐ 켜는 순간 필드 잡몹이 통째로 걷혔다(`cleared ≥ enemies_before` · `active_enemies` 비었다) ⓑ 그 뒤 스폰한 적도 스윕이 세운다(`is_physics_processing() == false`) ⓒ **실제 물리 프레임 6장을 흘려도 0px 움직인다**(플래그가 아니라 결과다) ⓓ `clock.phase_elapsed`·`clock.dwell`·`elapsed_time`이 프레임 6장 뒤에도 그대로다 ⓔ 무적이 프레임마다 다시 걸린다 ⓕ 스폰이 실제로 멎었다 ⓖ 끝나면 얼린 노드 0개 + 물리 복귀 + `spawn_timer ≤ 1.2` |
| `diet` | 온보딩 **페이지당** 글자 수 ≤ **360** · 한 줄 ≤ **32자** · 규칙 ≤ **2줄**. 실패하면 `onb_pages=[…] onb_peak=… onb_longest=… onb_worst="…"`가 **어느 줄이 넘쳤는지 바로 짚는다** |

### 화면별 **글자 수·점유율 상한 계약** (X2·X3·X4가 세우고 Y3·Y7이 늘린 자)

이 상한들은 장식이 아니라 **각 화면이 지켜야 할 계약**이고 매 실행 로그에 회귀 지표로
찍힌다. 상시 문장을 하나 늘리려면 **다른 하나를 호버 툴팁이나 도식으로 내려보내야 한다.**

| 화면 | 계약 | 현재 실측 | 지키는 검사 |
|---|---|---|---|
| ESC 편집 화면 | `text_labels ≤ 16` · **`prose_labels == 0`**(14자 이상 설명 문장) | `edit_labels=13 edit_prose=0` | `--v4-test edit_minimal` |
| 필드 HUD | 상시 판 0장 · `Panel` 아님 · 상시 문장 6개 | `hud_block_pct=3.19` `hud_ink_pct=6.39` `strip_h=74` | `--cycle-test hud_mini`·`hud_ghost` |
| **각인 부착 2단계**(Y3 신설) | **칸 안** 2자 이상 Label **≤ 7** · 14자 이상 **0개** / **패널** 2자 이상 **≤ 12** · 20자 이상 **≤ 2** | — | `--v4-test` 각인 글리프 묶음 |
| 온보딩 4페이지 | 페이지 **≤ 360자** · 한 줄 **≤ 32자** · 규칙 **≤ 2줄** | `onb_pages=[…] onb_peak=… onb_longest=…` | `--guide-test diet` |
| 길잡이 중 세계 | 필드 잡몹 0기 · 클럭 무진행 | `cleared=… phase_drift=0.000` | `--guide-test freeze` |
| 카메라 흔들림 | `cam_peak ≤ 4.0` · 스킬 발사 **정확히 0.0** · 끄면 **정확히 0.0** | — | `--cycle-test cam` |
| 레벨업 모달 | 카드 1장 = 글자 4줄(이름·설명·칩2) · 화면 전체 11줄 | — (수치 계약 없음 · 캡처 육안) | `--capture-choice` |

### 독립 프로브 (`-s`로 직접 실행 · run_all에 포함되지 않음)

```bash
godot --headless --path godot-game -s res://scripts/test/rune_test.gd      # 각인 엔진 몬테카를로
godot --headless --path godot-game -s res://scripts/test/data_test.gd      # 카드·몬스터·트로피·보스 데이터 스키마
godot --headless --path godot-game -s res://scripts/test/rift_probe.gd     # 균열 배치 규칙
godot --headless --path godot-game -s res://scripts/test/terrain_probe.gd -- fast   # 지형 규칙 (Y5 신설)
godot --headless --path godot-game -s res://scripts/test/balance_probe.gd  # 밸런스 근거 계산 (12절 · 판정 8축)
```

**`terrain_probe.gd`** — `-- fast` 약 **40초** / full 약 **40분**.
⚠️ `fast` 분기는 `OS.get_cmdline_user_args().has("fast")`이므로 **`--` 뒤에** 붙여야 한다.
`-s` 앞에 놓으면 Godot이 먹어 버려 조용히 full 모드로 40분을 돈다.
⚠️ **YZ가 full 모드 판정식을 백분위로 완화했다** — 「표본 300개 전수 통과」에서
「**p01·p99가 창 안** + **최대 초과 ≤ 0.005** + **총합이 창 안** + **2×2 블록 불변식**」으로.
**지형 규칙 자체는 한 줄도 안 바꿨다** — 바뀐 것은 판정식뿐이다.

**`balance_probe.gd`의 마지막 줄이 판정이다**(약 90초 · `run_all`에 포함되지 않는다):

```
BALANCE_PROBE_COMPLETE pass=1 rune_steps=1 hp_index=1 dwell_curve=1 dwell_pressure=1 volume=1 gold=1 boss_ttk=1 demon_ttk=1
```

**`pass=1`이 새 회귀 계약이다.** 밸런스 상수를 만지는 웨이브는 이 줄이 `pass=1`로
돌아오는지를 먼저 본다. **8축이 각각 어느 창을 재는지는 흩어져 있다** —
`hp_index`(−25% ± 10%p) · `dwell_pressure`(×2.0 ± 0.15) · `dwell_curve`는 **§7.5**,
`boss_ttk`(30~60초) · `demon_ttk`(60~120초) · 반격 창(1.3~1.9초)은 **§7.6**,
`gold`(여유 15~30%)는 **§7.7**, `rune_steps`는 **§7.1**의 실측표다.

⚠️ **`-s res://scripts/test/status_test.gd`는 영원히 멈춘다.**
그 파일은 `class_name StatusTest / extends RefCounted`라 Godot의 MainLoop 검사에 걸린다.
진짜 진입점은 **`-- --status-test`**다(기능 검사 16종 중 하나).
`rune_test` · `data_test` · `rift_probe` · `terrain_probe` · `balance_probe`는 `SceneTree`라
`-s`가 맞다. YZ가 `status_test.gd` 머리에도 이 경고를 박아 뒀다.

### 시각 캡처 15종

```bash
bash godot-game/scripts/test/run_all.sh --captures                 # 전체
bash godot-game/scripts/test/run_all.sh --captures --capture-hud   # 지정
```

`--capture-hud` `--capture-world` `--capture-factory` `--capture-rail` `--capture-draft`
`--capture-choice` `--capture-guide` `--capture-boss` `--capture-castle` `--capture-result`
`--capture-effects` `--capture-lobby` `--capture-character` `--capture-settings`
`--capture-onboarding`

**캡처는 자동 PASS/FAIL 집계에 넣지 않는다.** macOS 헤드리스에서는 빈 화면이 나오므로
창을 띄워야 하고, 목적이 사람 눈 검수이기 때문이다. PNG는
`godot-game/art/screenshots/qa/`에 저장된다.

⚠️ **컷 수를 셀 때는 대표 컷을 잊지 말 것.** 캡처 하나는 **이름 있는 서브컷 + 대표 컷
1장**(`<이름>-minimal-v2.png`)을 남긴다. 대표 컷은 `_save_capture_png()`를 지나지 않고
`_run_visual_capture()` 끝에서 직접 저장되므로 서브컷 개수만 세면 항상 하나씩 모자란다.

**전종 총 컷 수 — 73컷 · 고유 지문 72** (YZ 2026-08-10 전종 재생성 실측).
중복 1쌍은 **구조적**이다 — `onboarding-minimal-v2.png`가 2페이지에서 찍히므로
`onboarding-minimal-v2-p2.png`와 같은 파일이 된다. 그 밖의 중복은 **프레임 흘림이다.**
(Y4 시점에는 구조적 중복이 2쌍이었다. `world-minimal-v2 == -rift`는 Y5가 대표 컷을
순수 월드로 되돌리면서 사라졌다.)

```bash
cd godot-game/art/screenshots/qa
ls *.png | wc -l                       # 73
shasum *.png | awk '{print $1}' | sort -u | wc -l   # 72 (구조적 중복 1쌍)
```

주요 서브컷과 **검수 기준**(아래 숫자는 **서브컷만** 센 것이다):

| 캡처 | 서브컷 | 검수 기준 |
|---|---:|---|
| `--capture-boss` | 9 | 프리뷰·A·telegraph·B·C 변신·강화형·RELOAD·마왕·강림 |
| `--capture-world` | **9** | 스테이지 1·3·5 × 낮/밤 6 + 랜드마크 2 + 균열 1. ⚠️ 균열 컷을 찍은 뒤 **순수 월드 자리로 되돌리고 카메라 스무딩을 리셋**해야 대표 컷이 균열 컷의 복사본이 되지 않는다(Y5 실측 회귀) |
| `--capture-hud` | **8** (Y6·Y7 +2) | `hud-x3-day/night/reload/tip/blight/stage5-night` + **`hud-y6-discovery`** + **`hud-y7-impact`**. **`stage5-night`가 필수 검수 컷**(밤 + 안개 0.24 + 비네트 0.55에서 체력·바늘·화살표·원소색이 읽히는가) |
| `--capture-castle` | 6 | 방·**각인 세공사 진열 + 값표**·**새로고침 직후(20 G → 35 G)**·계약·**밀정 신판(버튼 2개)**·트로피 2택1 |
| `--capture-choice` | 5 | `level`(대표) · `focus` · `cancel` · `growthcap` · `item`. 컷 1은 **원소가 서로 다른 두 장**이 나올 때까지 최대 16회 다시 뽑는다 — 같은 원소면 "속성 = 색"이 갈리는지 한 장에서 확인할 수 없다(캡처 전용 장치) |
| `--capture-rail` | **5** (Y4 +1) | `overview`(상시 문장 0줄) · `tip-slot` · `tip-metrics` · `pick` + **장비 교체 확인**(`rail-y4-equip-swap` · 피드백 ⑫). 캡처 덱은 **불·얼음·번개·기름 네 계 + 빈칸**이다(한 장에서 원소색이 갈리는지 보려고 X2가 바꿨다) |
| `--capture-draft` | 4 | 1단계(3택 · `p1`) · 2단계(붙일 칸 · `p2`) · **칸 호버 툴팁**(`draft-y3-tip-slot` · Y3 신설) · 상한 칸 제외(`p3`) |
| `--capture-guide` | 4 | 이동 · 5칸 레일 · **`guide-x3-nav`**(구 `guide-minimal-v2-compass`의 후신) · ESC 확인 칩. **검수 항목이 갈렸다 — "필드에 마물이 0기인가"**(컷에 마물이 걸어 다니면 그것이 곧 회귀 신호다) |
| `--capture-onboarding` | 4 | 페이지 4장을 `-p1`~`-p4`로 따로 남긴다. 검수 기준 한 줄: **"한 페이지를 3초 안에 훑는가"** |
| `--capture-result` | **2** | 패배 컷 + **`result-y4-won`**(Y4 신설 — **승리 컷이 자기 이름으로 남는다**) |
| `--capture-effects` | 2 | 상태 핍 · 시너지 VFX |

⚠️ `--capture-castle` `--capture-choice` `--capture-guide` 셋은 `automated_test = false`로
돈다(모달이 자동 확정되면 화면이 아예 안 그려진다). 끝에서 다시 `true`로 되돌린다.

⚠️ **1회성 페이드가 끝난 뒤에 찍을 것.** `--capture-guide`가 처음에 `process_frame` 2회
뒤에 찍어 스크림(0.18초 페이드)이 거의 안 보였다. `create_timer(0.35)`로 고쳤다.
새 캡처를 붙이는 웨이브는 같은 함정을 밟는다.

⚠️ **검수 전에 shasum으로 컷이 서로 다른지 먼저 확인할 것**(X1 §9.4 #1 · X2 · X3 · X4에서
네 웨이브 연속으로 유효했던 함정). macOS 비headless 캡처는 창이 포커스를 못 받으면
`_save_capture_png()`가 **직전 프레임을 그대로 다시 저장한다** — 6컷이 전부 같은 해시로 나온
적이 있다(실측 2회). 화면이 "덜 그려진 것처럼" 흐릿한 것도 같은 원인이다(모달 등장 트윈
중간 프레임이 굳는다).

```bash
shasum godot-game/art/screenshots/qa/hud-x3-*.png | awk '{print $1}' | sort -u | wc -l
# 값이 컷 수와 같아야 한다. 다르면 다시 돌린다.
```

⚠️ **프레임 흘림은 생각보다 훨씬 흔했다.** Y3이 `_save_capture_png()`와 대표 컷 저장 경로에
**`RenderingServer.force_draw()`를 넣기 전에는 17컷 중 고유 지문이 5장뿐이었다.**
그리고 **캡처 전에 `ps aux | grep godot`으로 잔여 인스턴스가 0인지 확인하는 것은 이제
선택이 아니라 필수 절차다** — 이전 실행이 창을 붙들고 있으면 새 창이 포커스를 못 받는다.

⚠️ **고아 `.import` 10개가 남아 있다.** X2·X3가 이름을 바꾼 컷(`rail-minimal-v2-card/pick/slot` ·
`hud-minimal-v2-day/night/reload/blight` · `guide-minimal-v2-compass` ·
`boss-minimal-v2-battle/omen`)의 **PNG는 지워졌고 `.import`만 남았다**(YZ 실측).
Godot이 무시하므로 해롭지 않지만, 컷 수를 셀 때는 **`*.png`만 세라** — `ls *` 로 세면 두 배가 된다.

### 화면을 직접 열어 보는 프리뷰

`--preview-choice` `--preview-boss` `--preview-world` `--preview-night`
`--preview-onboarding` `--preview-fate` `--preview-evolution` `--preview-trial`
`--preview-rift` `--preview-castle` `--preview-build` `--preview-item`
`--preview-effects` `--preview-toast`

### 변경 범위별 필수 검사

| 바꾼 것 | 반드시 돌릴 것 |
|---|---|
| 각인 규칙·흐름 상수 | `rune_test.gd` + `--cycle-test` + `--draft-test` |
| **상태이상·시너지** | `status_test.gd`(⚠️ `-s`가 아니라 `-- --status-test`) + `--status-test` + `--combat-test` + `--stress-test` |
| 카드·몬스터·트로피·보스 데이터 | `data_test.gd` + `--v4-test` |
| 5칸 덱·편집 화면 | `--v4-test`(**`edit_minimal` 상한 포함**) + `--capture-rail` + `--capture-draft` |
| **레벨업 모달·취소 경제·각인 세공사·밀정** | `--draft-test` + `--castle-test` + `--v4-test` + `--capture-choice` + `--capture-castle` |
| **필드 HUD 정보 구조·화살표 내비·미니 스트립** | `--cycle-test` + `--guide-test`(`aim`) + `--capture-hud` 육안(특히 `stage5-night`) |
| **필드 생태·습성·지형** | `--field-test` + `--world-test` + `terrain_probe.gd -- fast` + `rift_probe.gd` + `--capture-world` |
| **발견·랜덤 이벤트·소비 아이템** | `--event-test` + `--cycle-test`(`hud_nav`) + `--rift-test`(`event_budget`) + `--save-test` |
| **타격감·impact·카메라** | `--combat-test` + `--cycle-test`(`cam`) + `--stress-test` + `--capture-hud` |
| **호버 툴팁(어느 화면이든)** | 그 화면의 검사에서 툴팁 등록·강제 표시 경로·행 수를 단언할 것 — "정보 손실 0"이 계약이다 |
| **온보딩 문구·길잡이** | `--guide-test`(17플래그 · `diet` 상한) + `--capture-onboarding` + `--capture-guide` + `--save-test`(차단 5구간) |
| **스테이지·dwell·시간** | `--stage-test` + `--rift-test` + `--capture-world` |
| **보스·트로피·결과** | `--boss-test` + `--castle-test` + `--capture-boss` + `--capture-result` |
| 성·NPC·상점가 | `--castle-test` + `--capture-castle` |
| 월드·지형 | `--world-test` + `rift_probe.gd` + `terrain_probe.gd -- fast` + `--capture-world` |
| 저장 스키마 | **`--save-test`** (필수) |
| **밸런스 상수** | **`balance_probe.gd`가 `pass=1`인지** → 그 다음 관련 기능 검사 |
| **보스 HP·패턴** | `balance_probe.gd`의 **`boss_ttk`·`demon_ttk`를 반드시 다시 읽는다** → `--boss-test` |
| HUD 좌표·렌더 | 캡처 전종 육안 + `--cycle-test`(`hud_block_pct` 회귀) + `--guide-test aim`(길잡이 타깃이 HUD 좌표에서 파생된다) |
| **UI 표면(킷·톤·폰트·스타일박스)** | `docs/ui-style-v3.md` §12 체크리스트 + 해당 화면 캡처 육안 + `--cycle-test`(레일 폭)·`--v4-test`(편집 레이아웃) |
| **스포트라이트 길잡이** | `--guide-test` + `--capture-guide` + `--save-test`(차단 5구간) |
| **`_process()`의 `playing` 구역에 새 틱 추가** | `--guide-test freeze`(그 틱이 길잡이 중에 돌아도 되는지 = `world_running` 게이트 안팎 판정) |
| 무엇이든 | `run_all.sh` 전체 |

### 새 검사를 붙이는 방법

1. `test_runner.gd`의 `ROUTINES`에 `[플래그, 메서드명, 인자]` 한 줄 추가.
2. 메서드 끝에서 반드시 `await _quit_test_cleanly(<합격여부>)` 호출.
   호출하지 않으면 게임이 종료되지 않아 `run_all.sh`가 타임아웃으로 죽는다.
3. `run_all.sh`의 `ALL_TESTS`에 `"--플래그:마커"` 추가.
   (캡처라면 `ALL_CAPTURES`에 플래그 한 줄 — 캡처는 PASS/FAIL 집계에 들어가지 않는다.)

---

## 12. 현재 알려진 한계와 기술 부채

### 우선순위가 높은 것

| # | 내용 | 어디 |
|---|---|---|
| 1 | **밸런스 플레이테스트가 아직 없다.** 두 번의 플레이테스트 피드백(6건 · 25건)은 전부 **UI·정보 구조·체감**이었고 전투 밸런스 관측은 한 줄도 오지 않았다. Y8이 dwell 곡선·스테이지 HP 계단·보스 `DESIGN_HP`를 **실측 재확정**했지만 그 실측은 여전히 **시뮬레이션**이다. 실기에서 보스전이 지루하면 `BossLibrary.DESIGN_HP` 세 줄을 내리면 된다(이전 값이 주석에 있다) | `boss_library.gd` · `balance_probe.gd` |
| 1b | **X1이 만든 경제 축도 미검증이다.** 취소 보상 30 G · 각인 세공사 가격 · 마왕 카드 하한 4는 전부 계산으로만 잡았다. 셋은 **한 경제**이므로 하나만 움직이지 않는다 — 근거는 `tuning.gd`의 `# X1 —` 블록 한 곳에 모여 있다 | `core/tuning.gd` · §7.7 |
| 2 | `game.gd`가 **15,969줄**이다(Y 라운드에서 +2,500줄). UI 계층 분리는 표면(`scripts/ui/ui_kit.gd`)까지만 갔고 화면 조립 코드는 여전히 `game.gd` 안에 있다. X2의 툴팁 컴포넌트처럼 **재사용 가능한 부품은 킷으로 올릴 수 있다**는 것이 확인됐으니, 분리한다면 그 경로다 | `game.gd` · `scripts/ui/ui_kit.gd` |
| 3 | **XP·골드가 스테이지 축으로 스케일하지 않는다.** dwell만 읽는다. 그래서 후반 상점은 그 스테이지 수입이 아니라 모아 둔 돈으로 산다. 의도인지 판정이 필요하고, 고친다면 자리는 `STAGE_PRICE_STEP`이 아니라 `StageClock.gold_multiplier()`다. ⚠️ 취소 보상과 **Y6의 사건 유입**(스테이지 수입의 22~24%)이 둘 다 새 골드 유입원이라 다시 재려면 그 둘을 가정에 넣어야 한다 | `stage_clock.gd` · `balance_probe.gd` |
| 4 | `player.rollback_capacity`를 올려 주는 카드·장비·트로피가 **하나도 없다**. `rollback_charges`는 항상 0이다 | `player.gd` |
| 5 | 독립 프로브 **5종**이 `run_all.sh`에 편입되지 않았다. 출력 규약(`-s` 스크립트)이 달라 별도 블록이 필요하다 | §11에 실행 명령을 적어 뒀다 |
| 6 | **설계 §9.2의 "칸 개방(4칸=L4 / 5칸=L9)"이 구현되지 않았다.** 런 시작부터 5칸이 전부 열려 있다(사용자 확정 정체성 #4와 충돌하므로 되살리려면 먼저 물을 것) | `factory_deck.reset()` |

### 밸런스 축 중 **판정을 미룬 것** (V10이 근거와 함께 보류)

| 항목 | 현재 | 왜 미뤘나 |
|---|---|---|
| `card_status_power()` 카드별 상태 세기 | 항상 1.0 | 계수 없이도 상태가 보스전 피해의 14~43%를 낸다. 지금 축을 넣으면 Y8이 확정한 보스 HP 표가 무효가 된다. **밸런스 플레이테스트 뒤에** 넣고 `balance_probe`를 다시 돌릴 것(두 번의 피드백이 전부 UI·체감 축이라 이 조건이 아직 안 찼다) |
| 한(chill) "강화" 계수 | `max`(사실상 no-op) | 위 항목과 **한 항목이다.** `power`가 1.0인 한 강화가 정의되지 않는다 |
| `STAGE_BOSS_HP_DWELL_STEP` 0.08 | 유지 | 강림 밸브(dwell 10~14)에서 보스 HP가 1.8~2.1배가 된다. 다만 그 표는 dwell 3 플레이어로 잰 값이라 모델이 기울어 있다 — 실제로 그만큼 머문 플레이어는 훨씬 강하다 |
| 독 감쇠 총량 기준값 | 정하지 않음 | 프로브가 스칼라 근사를 버리고 `StatusEngine`을 그대로 적분한다. 고를 필요가 없어졌다(스택 3 = 1.62 P · 스택 4 = 2.70 P는 참고값) |

### 게임/콘텐츠 한계

- 궁사·마법사는 데이터만 있고 잠겨 있다(카드에 「준비 중」 · `UIKit.CardState.DISABLED`).
- `draft_pool()`·`draft_ids()`의 `legacy` 필터는 **아무것도 거르지 않는다.** Y1이 legacy
  8장을 전부 드래프트 풀로 승격하며 `"legacy": true` 키를 데이터에서 지웠기 때문이다
  (`data_test`의 `legacy_zero`가 이 사실을 문다). 필터 코드는 남아 있으니 다시 잠글
  카드가 생기면 키만 붙이면 된다 — **지금은 `draft_pool() == SKILLS`(28장)이다.**
- v1 NPC 서비스 6종이 `_use_service()`에 살아 있지만 **성이 배치하지 않는다**(4종 고정).
  `--castle-test`가 두 개를 직접 호출해 검증하므로 남겼다.
- `camp_states`는 항상 빈 사전, `player.trophy_orbs`는 항상 빈 배열이다(저장 호환용 죽은 필드).
- 편집 화면 미리보기는 96표본이다(설계의 200표본은 프레임 예산 16.6ms를 혼자 다 먹는다).
- 보스 패턴 데이터의 `hits`·`pierce`는 **카드와 뜻이 다르다.** `hits`는 `random_impacts`
  패턴에서만 착탄 지점 수로 소비되고, `pierce`는 표적이 플레이어 한 명이라 판정에
  영향이 없다. 지우지 않은 이유는 그 표가 설계 §3.3의 사본이기 때문이다.
- 강림 중에는 **가장자리 화살표 내비와 고스트 레일이 숨는다.** 보스 레일 밴드가
  구 나침반 + 고스트 레일의 합집합 자리(x 806~1264)를 쓰기 때문이다. 마왕이 이미 여기
  있으므로 "마왕성 방향"도 "마왕이 얼마나 자랐나"도 의미가 없다는 판단이고,
  살리려면 새 좌표가 필요하다.
- 트로피 2택1의 예비 카드 2장까지 전부 겹치면 이론상 2택1이 1택이 될 수 있다
  (특별 카드 12종 중 11종을 이미 쥐어야 해서 사실상 도달 불가).
- 사운드는 런타임 합성음이다. 음악 없음.

### UI 재스킨(U0~U3)이 남긴 것

- ~~**`--capture-result`는 여전히 패배 컷만 찍는다.**~~ → **Y4가 `result-y4-won`을 신설해
  해소했다.** 승리 컷이 자기 이름으로 남는다.
- **길잡이 ①~⑥ 동안에는 ESC로 편집 화면을 못 연다**(ESC가 확인 칩으로 잡힌다).
  7스텝 약 40초짜리 잠금이고 ⑦이 곧 "ESC를 눌러 보라"라 실질 손해는 없다. 뒤집으려면
  전체 스킵 키를 ESC 밖으로 옮겨야 하는데 그건 사용자 지시(ESC 전체 스킵)와 어긋난다.
- **길잡이 도중 레벨업 모달이 뜨면 길잡이 층이 숨는다**(모달이 닫히면 그 스텝에서 이어진다).
  ~~시작 population이 남아 딜싸이클이 잡을 수 있다~~ → **X4가 시작 잡몹을 전량 제거하면서
  사실상 닫혔다**(적이 0기라 경험치가 들어오지 않는다). 층 겹침 사고 방어와 이어짐 처리는
  그대로 살아 있다.
- **`_hud_ink()`의 문턱 0.66은 SLATE(`#345a52`) 기준으로 잡았다.** HUD 톤을 바꾸는 웨이브가
  생기면 이 상수를 다시 계산해야 한다(`ui-style-v3.md` §13의 `_INK_LIGHT_ON`과 같은 짝).
  X3가 이 함수를 **필드 위**(판 없는 배경)로 확장했으므로 재계산 시 그쪽도 함께 본다.
- **픽셀 밀도가 UI 2.0 : 필드 2.5로 다르다.** 의도적 선택이고(§9) 뒤집으려면 지형을
  32px 타일로 옮기는 것이 먼저다.
- **`godot-game/`은 git에 커밋된 적이 없다**(`?? godot-game/`). U2·U3가 착수 전 커밋을
  권고했으나 §0-7이 커밋을 금지하고 있어 **사용자 지시가 있어야 한다.** 되돌릴 원본은
  `docs/v1-archive/game_lobby_v3.gd.txt` · `game_field_hud_style_u3.gd.txt`와
  `ui-style-v3.md` §2의 v1 토큰 대응표에 있다.

### 피드백 라운드(X1~X4)가 남긴 것

**X4 §7.1이 지목한 네 건** (길잡이·온보딩)

| # | 내용 | 고치려면 |
|---|---|---|
| 1 | **온보딩 4페이지의 화살표 규약이 글로만 있다.** 「목적지가 화면 밖일 때만 화살표가 뜹니다」 옆에 그림이 없다 | 4페이지 도식이 이미 꽉 찼다(낮밤 띠 · 5관문 타임라인 · 등급 줄 · 3칩 · 규칙 구분선까지 34px). **화면 테두리에 화살촉이 붙은 미니 픽토그램** 자리를 만들려면 3칩을 두 칩으로 줄여야 한다 |
| 2 | **길잡이가 끝난 뒤 필드가 한동안 비어 있다.** `spawn_timer` 1.2초부터 한 기씩 차므로 상한까지 20초쯤 걸린다 | 튜토리얼 직후로는 오히려 친절하다고 판단했다. "끝나자마자 세계가 살아나는" 연출을 원하면 `_finish_guide()`에서 `_spawn_stage_starter_population()`을 한 번 더 부른다(RNG 스트림을 한 번 더 소비하므로 `--guide-test` 뒤쪽 단언 영향 확인 필요) |
| 3 | **길잡이를 켠 채로 방치하면 세계가 무기한 멈춘다.** 모든 스텝에 SPACE/ESC 탈출이 있어 갇히지는 않지만 "N분 뒤 자동 종료" 같은 안전장치는 없다 | 자동 종료를 넣는다면 `_tick_guide()`에 타이머 한 줄 |
| 4 | **온보딩 도식과 실전 기하가 1:1이 아니다.** 예: 2페이지 5칸은 168×104인데 실전 미니 스트립 칸은 52×52다 | "온보딩에서 본 그림 = 필드에서 보는 그림"을 원하면 도식 기하를 X3 좌표에 맞춰야 한다(도식은 지금 자기 좌표계를 쓴다) |

**X1~X3이 남긴 것**

- ~~**`balance_probe.gd`에 X1 축이 없다.**~~ → **Y8이 프로브를 전면 재작성하면서
  경제 절(`gold`)을 넣어 해소했다**(§7.7의 골드 수지).
- **`DealCardLibrary.combat_tags()`의 마지막 호출부가 하나 남았다** —
  `_build_pending_card_summary()`(공장 place 모드). 그 화면을 손대는 사람이 마지막
  호출부를 지우면 그때 함수를 지우면 된다. `_factory_shape_text()` ·
  `_factory_card_button()`의 4번째 인자 `inner`는 **이미 호출부 0**이다.
- **`BOSS_RAIL_BAND`(마왕 레일 밴드 458×132)가 프로젝트에 남은 유일한 상시 킷 판이다.**
  보스전 전용이라 "필드가 주인공" 원칙과 충돌하지 않아 X3가 남겼다. 접으려면 미니모드로.
- **필드에서 마우스 입력을 아예 안 쓴다는 전제 위에 HUD 툴팁이 서 있다**
  (`InputEventMouseButton` 처리부 프로젝트 0건을 X3가 확인했다). 필드에 마우스 클릭을
  도입하는 웨이브는 `attach_tooltip()`이 대상을 `MOUSE_FILTER_PASS`로 올린다는 점을 볼 것.
- **`EDIT_SLOT_*`와 `EDIT_CARD_SIZE` 계열을 합치지 말 것.** 후자(`EDIT_CARD_SIZE` ·
  `EDIT_SLOT_PAD` · `EDIT_SLOT_CARD_RECT` · `EDIT_SLOT_RUNE_Y` · `EDIT_SLOT_HEADER_H`)는
  `_build_preview_slot()`이 **공유**한다. 지금 그 함수의 소비자는 **일곱 곳**이다 —
  마왕 프리뷰 2 · 스테이지 보스 프리뷰 2 · 밀정 · 결과 화면 · 각인 드래프트.
  X2가 편집 전용 기하를 `EDIT_SLOT_*` 새 이름으로 따로 뗀 이유가 그것이다.
- **`_build_edit_flow_arcs()`도 공유한다** — 지금은 **네 화면**(편집 · 스테이지 보스 프리뷰 ·
  밀정 · 마왕 프리뷰) · 호출부 5곳이다.
  편집 화면만 `minimal: true`를 넘겨 라벨을 지운다 — 기본값을 뒤집지 말 것.

### Y 라운드가 남긴 것

| # | 내용 | 어디 / 고치려면 |
|---|---|---|
| 1 | ✅ **해소** — `terrain_probe` full 모드 FAIL | YZ가 판정식을 백분위로 완화했다(§11). 지형 규칙은 무변경 |
| 2 | ✅ **해소** — `NIGHT_ENEMY_LIMIT_STEP` 소비자 0 | YZ가 삭제했다 |
| 3 | ✅ **해소** — 공유 렌더러 글자 겹침 **2건** | ⓐ `_build_preview_slot()`의 각인 줄에 **어두운 판**(`ColorRect`)을 깔고 외곽선을 끄고 이름을 **「하나 + 외 N」**으로 접었다(소비자 7곳 동시). ⓑ `_build_choice_card_body()`의 장비 태그 줄이 두 줄로 감기는데 자리가 24px뿐이라 요약 줄과 겹쳤다 — 자리를 40px로 늘리고 요약 줄 시작 y를 **`tag_top + tag_height`**로 바꿨다(3화면 동시). 자세한 실측은 §15 YZ |
| 4 | **`DealCardLibrary.impact_name()`은 화면에 안 나간다.** 유일한 소비자가 `balance_probe.gd`의 보고 문자열이다 | 화면 어휘는 같은 파일의 `combat_tags()`가 낸다. 붙이려면 `--draft-test target_prose`와 `--v4-test` 글자 수 계약을 **함께** 옮겨야 한다 |
| 5 | ✅ **해소** — 필드 상자 골드가 스테이지 스케일을 안 타던 건 | YZ가 **누락으로 판정하고 곱했다**(`_open_chest()`의 `gold`·`curse` 두 칸에 `stage_price_scale()`). 근거는 게임 내 일관성이다 — 사건 보상·안전 상자·상점가가 전부 그 스케일을 타는데 필드 상자만 안 타서, 「보물섬」이 깔아 준 상자와 바로 옆 필드 상자가 같은 스테이지에서 다르게 굴렀다. 재산정 결과 골드 여유 19.9% → **23.7%**로 목표 창(15~30%) 안이다 |
| 5b | **`balance_probe.gd`의 상자 골드 주석·합산이 아직 「안 곱한다」로 적혀 있다** | 위 수정을 반영하지 않은 자리가 두 곳(`FIELD_CHEST_GOLD` 주석 · ⑧ 합산)이다. **판정 게이트가 아니라 지금 빨개지지 않는다**(여유가 어느 쪽으로 계산해도 창 안이다). 프로브를 여는 다음 웨이브가 갱신할 것 |
| 6 | **에셋 2건 미납** — `art/v2/ui-kit-skill-shape.png`(16px × **14칸** 흰색 단색) · `art/v2/ui-kit-rune.png`(16px × **15칸**) | 구우면 `skill_icon.gd`의 `GENERATED_SKILL_INDEX`를 실루엣 인덱스로 다시 쓰고 `_reskin_to_element`는 그대로 둔다 / `game.gd`의 `RUNE_GLYPH` **값만** 갈아끼우면 되고 호출부 4곳은 무변경. ⚠️ **`UIKit.GLYPH_INDEX`는 그때도 건드리지 말 것** |
| 7 | **트로피 카드 12종(`SPECIALS`)은 여전히 벡터 드로잉이다** | 아틀라스가 **7×4 = 28칸 고정**이라 자리가 없다 |
| 8 | ✅ **해소** — **`game-icons/` CC BY 크레딧** | **배포 빌드에서 제외**하는 쪽으로 결정했다. `export_presets.cfg`의 `exclude_filter`에 `art/external/game-icons/*`를 넣어 pck에 실리지 않게 했고(런타임 의존 **0**이라 무해), 재배포한 pck에서 `art/external/game-icons/` 경로 **0건**을 확인했다. 배포하지 않으므로 게임 내 크레딧 표기 의무가 사라진다. 저장소 안에는 `art/external/LICENSES.md` §6 전문과 함께 그대로 **보관**한다(보관은 적법 — 지우지 말 것) |
| 9 | 🟡 **대부분 해소** — 모달 부제 밴드 | Y4가 레벨업만 걷었고 YZ가 **다섯 화면을 더** 걷었다(각인 3택 · 전조 보상 · 아이템 2택 · 스테이지 보스 프리뷰 · 마왕 프리뷰 · 결과 화면 — 표는 §15 YZ). **남은 둘은 의도적이다**: 공장/편집 화면의 상황 부제 4분기는 「지금 무엇을 배치하는 중인가」를 말하는 **상황 안내**라 상시로 필요하고, 트로피 3단 설명은 2택1의 근거라 카드 밖에 있어야 한다 |
| 10 | **`shy` 습성은 `wisp` 한 종뿐이고 3스테이지에 해금된다** | 1·2스테이지 낮은 **무리 + 텃세뿐**이라 `docs/FEEDBACK_Y.md` §5.4가 약속한 "도망가는 것들도 남는다"가 아직 성립하지 않는다 |
| 11 | **「보물섬」의 섬·다리 지형이 미구현이다** | 호수에 붙은 마른 자리에 표식만 세웠다. 보상과 "함정 없음"은 스펙대로다 |
| 12 | **보스 `stagger` 잠재 함정** | `cancel_pending_attack()`을 보스에 그대로 걸면 `maxf(boss_attack_timer, 0.7)`이 패턴을 통째로 잠근다. 지금은 마왕이 `external_cycle_enabled`, 스테이지 보스가 `_process_boss` 조기 반환이라 **안 터질 뿐이다** |
| 13 | **롤백 지점이 주석에 있다** | `boss_library.gd`의 `DESIGN_HP` · `tuning.gd`의 「이전 값」 주석 3곳 · `monster_library.gd`의 `CYCLE_HEALTH_GAIN` |
| 14 | **`RELOAD`는 영문 그대로 남겼다** | 「딜싸이클」과 같은 **고유 기계 이름**으로 취급했다. 검사 **94곳**이 이 문자열을 물고 있어 마지막 웨이브에서 바꾸는 것이 더 위험했다. 한글로 바꾸려면 **전용 웨이브**가 필요하다 |

### 파일 개명 미실시 (의도적)

설계 §7.1은 `factory_deck.gd` → `core/cycle_deck.gd`,
`deal_cycle_controller.gd` → `core/cycle_engine.gd` 개명을 지정했다. **하지 않았다.**
두 파일은 `preload` 상수 2개로만 참조되고 `class_name`이 전 코드베이스·테스트·저장
스키마에 박혀 있어, 개명은 위험 대비 이득이 없는 순수 노이즈 diff다.
정말 하려면 `git mv` + preload 2줄 + class_name 2줄이면 끝난다.

---

## 13. AI 작업 규칙

### 작업 시작 전

1. 이 파일을 처음부터 끝까지 읽는다.
2. §1 체크포인트를 읽고 무엇이 끝났는지 확인한다.
3. 규칙을 바꾸는 작업이면 `docs/GAME_DESIGN_V3.md` **부록 A(확정 결정)** 를 먼저 본다.
   본문과 부록 A가 충돌하면 **부록 A가 우선**한다.
4. 해당 시스템을 만든 웨이브의 `docs/handoff-v*.md` · `handoff-u*.md` · `handoff-x*.md` ·
   **`handoff-y*.md`**(+ `handoff-ya.md`) 함정 절을 읽는다.
   **Y 라운드는 게임 규칙을 바꿨으므로 설계 근거인 `docs/FEEDBACK_Y.md`도 함께 본다** —
   단, 그 문서의 수치는 **착수 초기값**이고 실측 확정값은 `handoff-y8.md`와 이 파일에 있다.
5. **UI 표면을 건드리는 작업이면 `docs/ui-style-v3.md`를 먼저 읽는다**(그 문서가 규격 원본).
   **화면의 상시 글자 수를 늘리는 작업이면 §11의 상한 계약 표를 먼저 읽는다.**
6. 컴파일 검사를 한 번 돌려 시작점이 깨끗한지 확인한다.

### 구현 중

1. **밸런스 숫자는 `core/tuning.gd`와 라이브러리에서만 고친다.** `game.gd`·`enemy.gd`에
   새 숫자를 심지 않는다. 큰 폭으로 조정하면 **상수 옆 주석에 이전 값을 남긴다.**
2. **규칙 계층(`scripts/core/`)은 게임 노드를 참조하지 않는다.** 순수 데이터만 주고받는다.
3. **궤적은 `RuneEngine.simulate_cycle()`에서만 나온다.** 런타임에서도 미리보기에서도
   자체 근사식을 쓰지 않는다. `deal_cycle_controller.gd`에서 `randf()`를 부르는 순간
   결정성과 미리보기 정합이 동시에 깨진다.
4. **상태이상 규칙은 `StatusEngine`에서만 나온다.** 숫자는 `tuning.gd`에서 읽고
   엔진에 다시 심지 않는다.
5. **피해 배율은 `_cycle_damage_value()` 한 곳에서만 곱한다.**
6. **HP 배율은 마왕전 개시 한 곳에서만 곱한다.** 다른 경로에서 다시 곱하지 않는다.
7. **스테이지 배율은 `combat_resolver.apply_stage_scaling()` 한 곳에서만 먹인다**
   (스폰 경로, 마물 1기당 정확히 1회). 두 곳에 두면 배율이 제곱된다.
8. **트윈 루프 애니메이션 금지.** 강조는 `delta` 감쇠 float로 한다.
   **1회성 전환 트윈은 허용**된다 — 검증 가능한 계약은 `set_loops()`가 프로젝트 전체 0건.
9. **UI 표면은 `UIKit` 단일 창구로만 만든다.** `StyleBoxFlat.new()`는 **프로젝트 전체 0건**이고
   그 상태를 유지한다. U3가 마지막 1건이던 `game.gd::_panel_style()`을 **함수째 삭제했으니**
   되살리지 말 것. 새 패널·버튼·카드·리본·칩은 `UIKit.panel_box()` / `button_box()` /
   `card_box()` / `ribbon_box()`에서 가져오고, 색은 `UIKit.text_color()` 계열에서만 읽는다
   (의미색만 `GamePalette`). hex 리터럴·`corner_radius`·5단 밖 폰트를 새로 넣지 않는다.
   **UI 스타일의 단일 진실 원천은 `docs/ui-style-v3.md`다** — 킷을 고치면 그 문서를 같이
   고치고, 화면을 끝내기 전에 §12 체크리스트를 자가 점검한다.
10. **한글 라벨에 마크다운을 쓰지 말 것.** Godot `Label`은 `**볼드**`를 그대로 별표로 그린다.
11. **`_process()`의 `playing` 구역에 새 틱을 넣을 때는 `world_running`을 먼저 본다**(X4).
    게이트 밖에 두면 기본값이 "길잡이 중에도 돈다"이다. **세계 시간에 속하는 것**
    (클럭·체류·스폰·균열·잠식·도트·런 시계)이면 게이트 **안**에 넣는다.
    적이 아닌 새 위협 노드를 만들면 `_guide_freeze_sweep()`에 그 종류를 더한다.
12. **금지어 목록**(전부 삭제된 기능이라 쓰면 거짓이 된다).
    코드 주석의 "구 나침반" 같은 **연혁 서술은 예외**다 — 그건 없어진 것을 가리키는 말이다.

    | 금지어 | 대신 |
    |---|---|
    | 「나침반」 | **「화면 가장자리 화살표」**(X3) |
    | 「각인 강화」·「카드 이동 모드」·「칸 교환 모드」·`M` 키 | 개념 자체가 없다(X1·X2) |
    | **「과열」·「과부하」·「열기」·「잔열」·「되감기」·「도약」·「재실행」·「역행」·「책갈피」** | **「한 칸은 한 바퀴에 두 번까지」·「밟은 칸」·「한 칸 뒤로」·「한 칸 건너뛰기」·「두 번 치기」·「되돌이」**(Y1·Y2) |
    | **「결속」·「삼각」** | 남은 태그 상호작용은 **공명** 하나뿐이다(Y1) |
    | **한자 원소 「화(火)·빙(氷)·뇌(雷)·유(油)·초(超)」** | **불·얼음·번개·기름·정신**(Y4 · `element_name()`이 정본) |
    | **영문 조어 전반** — 「드래프트」·「세미 엘리트」·「미믹」·「아레나」·「선딜」·「몬테카를로」·「NPC」·「RANK」·「HP」·「커먼/레어/유니크/히어로」·「도트 틱」·「클리어」 | **각인 고르기 · 이름 있는 마물 · 가짜 상자 · 싸움터 · 예비 동작 · N번 굴림 · 상인 · 등급 · 체력 · 일반/희귀/특별/영웅 · 지속 피해 · 깸**(YZ) |
    | **어려운 한자어** — 「미열람」·「미건설」·「미선택」·「과밀」·「전황」·「임계」·「포화」·「시연」 | **안 보임 · 아직 없음 · 안 고른 · 빽빽함 · 지금 상황 · …까지 · 더 안 오름 · 보여 준**(YZ) |

    > ⚠️ **문서와 코드 심볼은 예외다.** `rune_draft` 상태 문자열 · `--draft-test` ·
    > `draft_offers` · `_build_rune_draft_screen()`처럼 **코드 이름에 남은 영어**는
    > 그대로 둔다. 금지되는 것은 **화면에 나가는 문자열**이다.
    >
    > **`RELOAD`와 `G`만은 화면에서도 유지한다** — 「딜싸이클」과 같은 고유 기계 이름으로
    > 취급했다(검사 94곳이 `RELOAD` 문자열을 물고 있고, `G`는 금화 칩과 같은 토큰이어야
    > 한다). 바꾸려면 전용 웨이브가 필요하다(§12 「Y 라운드가 남긴 것」 14).
13. **툴팁은 `UIKit` 단일 창구로만 만든다**(X2 신설 · 이제 프로젝트 자산이다).
    `make_tooltip_layer` → `attach_tooltip` → (필요하면) `tooltip_focus`/`tooltip_force`.
    엔진 기본 `tooltip_text`는 쓰지 않는다 — 지연이 전역 설정 하나뿐이고, **키보드
    포커스에서 안 뜨며**, 캡처에서 강제로 띄울 수 없다. 층은 **오버레이의 마지막 자식**으로
    만들고(먼저 붙이면 카드·칸이 툴팁을 덮는다), 화면을 다시 조립하면 층 참조를 `null`로 끊는다.
14. **원소색은 `_element_color()` 단일 창구로만 읽는다**(X1 신설 · §9).
    새 색표를 만들지 않는다. 어두운 판 위에서 색을 내야 하면 `_element_wash()`를 쓴다
    (`modulate_color`는 곱셈이라 찬 색을 못 낸다).
15. **화면에서 문장을 지울 때는 먼저 갈 곳을 정한다.** "정보 손실 0"이 X2·X3가 통과한
    기준이고 테스트가 그것을 단언한다(툴팁 rows/body 또는 도식).
16. **파괴적 삭제 전 원본을 `docs/v1-archive/`에 복사한다.**
17. `art/generated/` · `art/external/` · `docs/v1-archive/`는 지우지 않는다.
18. **git commit을 하지 않는다.**
19. 새 PNG를 구운 뒤에는 반드시 `--editor --quit`을 한 번 돌린다.
    `.import`가 없으면 `preload`가 파스 에러로 죽는다.
    UI 킷 PNG는 `art/v2/build_assets_ui.gd`로 굽는다(스프라이트는 `build_assets.gd`).

### 자주 밟는 함정 (전 웨이브 누적)

1. **카드 인스턴스에 `element`/`form`/`name`이 없다.** 정의(`by_id`/`ranked`)에서 읽는다.
2. **확정(패시브) 각인은 `step.fired`에 남지 않는다.** 칸의 `runes`를 직접 읽어야 한다
   (`RuneEngine.passive_magnitude`).
3. **`cycle_completed` 시그널은 `reload_duration`이 채워지기 전에 발화한다.**
4. **`game.is_night` / `cycle_number` / `phase_elapsed`는 변수가 아니라 접근자다.**
   진짜 값은 `game.clock` 안에 있다. 평범한 `var`로 되돌리지 말 것.
5. **잠식 표식(`BLIGHT_META`)이 중복 부여의 유일한 방어선이다.** 지우면 0.28초마다
   체력이 ×1.22씩 곱해진다.
6. **`factory.rune_deck()`의 `runes`는 참조다.** 가상 부착을 시뮬레이션할 때는
   칸 딕셔너리를 깊은 복사해야 실제 덱이 오염되지 않는다.
7. **드래그 페이로드의 `gesture` 키가 카드 이동과 칸 교환을 가른다.**
   X2가 모드를 지운 뒤로 그 키를 정하는 것은 **집은 자리**다(카드 몸통 = `"card"` /
   칸 손잡이 = `"slot"`). `factory_edit_mode` 변수는 남아 있지만 이제 화면 모드가 아니라
   "키보드로 집은 것이 어느 쪽이었나"만 기억한다 — **화면 상태로 되돌리지 말 것.**
8. **새 카드를 주는 모든 경로는 `draft_pool()`을 쓴다.** `SKILLS` 28종을 쓰면
   legacy 카드가 새어 나온다. **⚠️ 지금은 그 필터가 비어 있다** — Y1이 legacy 8장을
   전부 승격해 `draft_pool() == SKILLS`(28장)다. 그래도 관례는 유지한다(다시 잠글 카드가
   생기면 데이터 키 하나로 끝나야 한다).
9. **`_trigger_boss_cycle_pulse()`의 `match`에 `_:` 기본 분기를 추가하지 말 것.**
   보스 패턴(`kind == "boss_pattern"`)이 **두 번** 터져 피해가 이중이 된다.
   분기를 꼭 추가해야 하면 `boss_pattern`을 명시적으로 제외할 것.
10. **`state == "playing"`은 "평범한 필드"를 뜻하지 않는다.** 강림한 스테이지 보스도,
    U3 스포트라이트 길잡이도 `playing`이다. "보스전인가"는 `stage_boss_active()`로,
    "길잡이 중인가"는 `guide_active`로, **"세계 시간이 흐르는가"는 `world_running`으로** 묻는다.
11. **`--save-test`의 `game.run_cycle_seed = 0` 한 줄을 지우지 말 것.**
    콜드 스타트를 흉내 내는 줄이고, 없으면 복원 순서 회귀를 잡지 못한다.
12. **결과 화면 금지 어휘에 짧은 토큰을 넣지 말 것.** `"7일"`이 "총 17일차"에 걸렸다.
13. **`player.rollback_charges`는 저장 흔들기에서 0으로 둔다.** 올려 주는 수단이 없어
    1을 넣으면 정상 클램프가 FAIL로 잡힌다.
14. **방향성 VFX는 +X.** 새 시트의 원본 축이 다르면 빌드 단계에서 돌린다.
15. **`--cycle-test`는 실시간 12초를 기다린다.** 줄일 수 없다.
16. **`Object.get_meta(name, default)`는 이 빌드에서 기본값을 줘도 ERROR 줄을 찍는다.**
    `has_meta`로 먼저 거를 것. **meta를 지울 때는 읽는 쪽을 먼저 grep**한다
    (X1이 `owned_text`를 지우면서 `--v4-test`를 깼다).
17. **`UIKit.card_box()` 같은 킷 스타일박스에 `modulate_color`를 직접 박지 말 것.**
    한 벌만 구워 공유하는 리소스라 **전 화면이 물든다.** `UIKit.variant()`로 복제하고,
    복제본은 포커스 갱신이 다시 씌우므로 색을 meta(`kit_card_tint`)에 남긴다.
18. **`_kit_panel()`은 `MOUSE_FILTER_IGNORE`로 만들어진다.** 툴팁을 걸면
    `attach_tooltip()`이 대상만 `PASS`로 올린다(`STOP`으로 올리면 그 아래 버튼이 클릭을
    못 받는다). `IGNORE` 부모는 자식의 마우스를 막지 않는다.
19. **`Array[Node] = [x] if cond else []`는 런타임 타입 오류다.** 삼항의 결과가 untyped
    `Array`라 대입에서 죽는다. 조건문으로 풀어 쓸 것.
20. **`_label()`은 `clip_text = true`다.** 상자 높이가 글꼴 줄 높이보다 낮으면 말줄임이
    아니라 **글자가 위아래로 썰린다.** 라벨 상자는 **폰트 크기 + 5px 이상**으로 잡는다.
21. **`queue_free()`는 프레임 끝에야 걷힌다.** 방금 지운 적이 아직 `combat.active_enemies`에
    남아 있으므로 세는 코드에는 `is_queued_for_deletion()` 가드가 필요하다. 그리고
    지우면서 순회할 때는 **사본을 돈다**(`_exit_tree` → `unregister_enemy()`가 원본 배열을
    줄여 절반만 지워진다).
22. **점유·라벨 측정에 전면 앵커 층을 섞지 말 것.** 길잡이 층·툴팁 층은 화면 전체
    `Control`이라 그대로 세면 100%가 나온다. **이름과 신원 둘 다로** 걸러야 한다.

#### Y 라운드가 새로 밟은 함정 (14건)

23. ⚠️ **개수를 세는 단언은 "0개일 때 공허하게 통과"한다.**
    각인 글리프를 **통째로 지워도** `--v4-test edit_minimal`이 초록이었고,
    무리가 한 번도 안 나오면 `herd_spawn`이 공허하게 통과했고,
    발견 게이팅이 꺼져 있어도 초록이었다.
    **새 단언에는 반드시 음성 대조를 돌리고, 0이 나올 수 있는 축이면 테스트가
    먼저 값을 심어라.**
24. ⚠️ **데이터가 옳게 만들어 둔 값은 런타임 검사의 판별력을 지운다.**
    카드 40장의 `color`가 이미 정합해서 **런타임 폴백을 통째로 지워도** 초록이었다.
    런타임 구조를 재려면 **데이터와 어긋난 입력**을 만들어야 한다.
25. ⚠️ **`const Dictionary` / `const Array`는 런타임에 읽기 전용이다**(Godot 4).
    상수 사전을 그 자리에서 고치려 들면 죽는다. 사본을 만들 것.
26. ⚠️ **폐기된 각인 id는 조용히 사라진다.**
    `roll_rune()`이 `{}`를 돌려주고 `attach_rune()`이 `false`를 내지만 **아무도 안 본다** →
    덱이 무각인으로 돌면서 테스트는 통과한다. `data_test`의 RELOAD 기준선이 몇 라운드째
    아무것도 재고 있지 않았고 `balance_probe`의 숫자가 통째로 무효였던 원인이 이것이다.
    **각인 id를 갈아끼울 때는 「부착 수」 단언을 같이 넣을 것.**
27. ⚠️ **`RuneEngine.TWIN_POWER`(0.5)를 컨트롤러에 박지 말 것.**
    엔진이 `merged_magnitude()`로 사본 감쇠(`DUP_MAG_FALLOFF 0.60`)를 먹인다 —
    상수를 그대로 쓰면 중복 부착에서 값이 어긋난다.
28. ⚠️ **`EDIT_ARC_RUNES`는 `FLOW_DELTA`가 아니다.**
    전자의 단위는 **"착지 오프셋"**(`1 + delta`)이고 후자는 **"정상 다음 칸 대비 오프셋"**이다.
    한쪽 표를 다른 쪽에 그대로 넣으면 화면 화살표가 실제 궤적과 어긋난다.
29. ⚠️ **`_factory_deck_signature()`에 레일 각인을 안 넣으면 미리보기가 캐시에 걸린다.**
    레일 각인을 붙였는데 미리보기 숫자가 그대로면 이걸 의심할 것.
30. ⚠️ **세공사 진열 3장이 전부 레일 각인일 수 있다.**
    `_first_slot_offer_index()` / `_open_slot_rune_draft()`를 쓸 것(§7.10).
31. ⚠️ **디버그 `print`가 `=false`를 찍으면 `run_all.sh`가 통째로 FAIL이 된다.**
    §11의 FAIL 판정 조건 ③이다. 새 로그 문자열에 `=false`가 들어갈 수 있는지 먼저 볼 것.
32. ⚠️ **몹별 피격 파편에 `spawn_burst()`를 쓰면 안 된다.**
    78기 × 초당 수 타격이 **노드 생성**이 된다. 그 몹의 `_draw()` 안에서 직접 그린다.
33. ⚠️ **`_build_choice_card_body()`의 자리값은 `CHOICE_CARD_SIZE`(510) 기준이다.**
    더 작은 카드에 쓰면 정보 열이 카드 밖으로 나간다.
34. ⚠️ **경계 검사는 모달 등장 트윈이 가라앉은 뒤에 재야 한다**(`_settle_modal()` 0.30초).
    트윈 중간 프레임에서 재면 좌표가 최종값이 아니다.
35. ⚠️ **운에 기대는 줄은 판별력이 없다.** "겹칠 수도 있다"를 재려면 **일부러 겹쳐 놓고** 재라.
36. ⚠️ **Godot 4 `Label`에 `clip_text`/`text_overrun_behavior`를 걸어도
    폰트·외곽선 때문에 11px 한글은 옆 글자와 붙는다.**
    밝은 판 위 11px 한글에는 **어두운 칩을 깔고 외곽선을 끄거나, 글자 수를 코드에서 직접
    잘라라**(YZ가 `_build_preview_slot`에서 실제로 밟았다).
37. ⚠️ **테스트가 실전 물리 프레임을 흘리면 그 사이에 모달이 열린다.**
    `--event-test`의 `items` 묶음이 **8회 중 3회** 빨개지던 원인이 이것이다 —
    밤눈 축이 `await get_tree().physics_frame`을 두 번 하는 동안 경험치가 들어와
    레벨업 모달이 떴고, `state`가 `"choice"`가 되자 그 뒤의 `_use_consumable()`이
    **조용히 아무것도 안 했다**(`state != "playing"`이면 즉시 반환한다).
    **프레임을 흘린 뒤 필드 동작을 부르기 전에는 화면을 되돌려라** —
    `_clear_overlay()` → `get_tree().paused = false` → `state = "playing"`.
    YZ가 그 세 줄로 12회 연속 통과를 만들었다.
38. ⚠️ **긴 AND 사슬 하나로 묶은 묶음은 흔들릴 때 원인을 좁힐 수 없다.**
    위 37번을 찾는 데 걸린 시간의 대부분이 「`items=false` 중 어느 축인가」를 좁히는 데
    들었다. 축마다 이름을 붙이고 **실패했을 때만** 전부 찍어라(통과 상태에서 늘 찍으면
    소음이고, `run_all.sh`가 `=false`를 통째로 세므로 위험하기도 하다).
    본보기는 `--event-test`의 `EVENT_ITEMS_DETAIL` · `EVENT_DECOY_DETAIL` 두 줄이다.

39. ⚠️ **`run_all.sh`를 두 개 동시에 돌리지 말 것.** 로그 디렉터리
    `godot-game/.test-logs/`가 **공유**라 두 인스턴스가 서로의 로그를 덮어쓴다.
    그러면 멀쩡히 통과한 검사가 「출력 없음」으로 FAIL이 되고, 로그를 열어 보면
    엔진 배너 한 줄만 있다. YZ가 실제로 이 유령을 세 번 쫓았다 —
    **매번 `pgrep -f "run_all.sh|godot"`으로 0을 먼저 확인하고 돌려라.**
    캡처 전에 잔여 인스턴스를 세는 것과 같은 이유이고, 같은 명령이다.
40. ⚠️ **CPU가 붐비면 `await` 기반 단언이 가짜로 빨개진다.** 이 머신에서는 다른 앱
    (게임 클라이언트)이 CPU 150%를 쓰는 동안 `--save-test fields` · `--event-test items` ·
    `--field-test habit_day`가 번갈아 실패했다. **판별법**: 그 검사만 단독으로 3회 돌려라 —
    3/3 통과면 경합이고, 재현되면 진짜 버그다. 부하는 `uptime`의 load average와
    `ps -A -o %cpu,comm | sort -rn | head`로 확인한다.
    ⚠️ 다만 **「경합이니까 괜찮다」로 끝내지 말 것.** 위 두 건은 실제로 경합이 드러낸
    **진짜 계약 결함**이었다(벽시계 대기 중 세계가 도는데 정확 일치를 요구했다).
    경합에서만 깨진다면 그 단언은 **시간에 의존하고 있다는 뜻**이고, 시간 의존을
    없앨 수 있으면 없애는 것이 옳다.

### 작업 종료 전

1. `bash godot-game/scripts/test/run_all.sh` 전체 PASS(**17/17**).
2. 화면을 건드렸으면 캡처 육안 검수 — **찍기 전에 `ps aux | grep godot`으로 잔여 인스턴스
   0 확인**, **찍은 뒤 `shasum`으로 컷이 서로 다른지 확인**(§11).
3. 저장 스키마를 건드렸으면 `--save-test` 필수(`mismatch=0`).
4. 밸런스를 건드렸으면 `balance_probe.gd` 재실행 — **`pass=1`** 확인 + 표를 주석에 남긴다.
5. **상시 문장을 늘렸으면 §11의 상한 계약 표를 다시 읽고 로그 지표를 확인한다**
   (`edit_labels` / `edit_prose` / `hud_block_pct` / `onb_peak` / `onb_longest`).
6. §1 체크포인트 갱신.
7. §15 변경 로그에 새 항목 추가(§14 양식).
8. 사용자에게 무엇이 바뀌었는지 한국어로 보고.

### 중단 가능성이 있는 긴 작업

- 한 번에 한 시스템만 건드리고 그때마다 체크포인트를 갱신한다.
- 여러 파일을 동시에 반쯤 고쳐 두지 않는다. 컴파일 가능한 상태를 유지한다.
- 웨이브 작업이라면 소유권 경계를 넘을 때 **가산(additive)** 으로만 넘고,
  넘은 자리를 인수인계 문서의 "소유권 경계 접촉" 표에 반드시 적는다.

---
## 14. 향후 변경 로그 작성 양식

새 기록은 이 섹션 바로 아래, 가장 최근 것이 위로 오도록 추가한다. 아래 필드를 생략하지 않는다.

```markdown
### YYYY-MM-DD HH:MM KST — 변경 제목

- 사용자 요청:
- 상태: completed | in_progress | blocked | ready_for_playtest
- 결정한 내용:
- 변경 파일:
  - `path/to/file`: 무엇을 변경했는지
- 사용자에게 보이는 변화:
- 데이터/저장 호환성:
- 실행한 검증:
  - `정확한 명령` → PASS/FAIL/미실행
- 남은 문제:
- 다음 AI가 시작할 정확한 지점:
```

좋지 않은 기록:

```text
UI 수정함. 테스트 대충 됨. 다음에 계속.
```

좋은 기록:

```text
공장 카드 이름이 2줄에서 잘리던 문제를 game.gd::_factory_card_button()에서 수정.
--capture-factory 통과. 다음 작업은 1280×720에서 히어로 아이템 긴 이름 3개 확인.
```

---

## 15. 누적 변경 로그

### 2026-08-10 19:10 KST — 체크포인트 후속 정정 (문서만 · 게임 코드 0줄)

Y5~Y8이 "오케스트레이터가 반영할 것"으로 넘긴 목록을 `docs/handoff-y5..y8.md`와
**실제 코드**에 대조했다. **대부분은 YZ가 이미 반영해 둔 상태였고**, 남은 다섯 자리만 고쳤다.
검사·캡처 종수(17종 / 15캡처)와 실행 시간, `schema 4`, 카메라 흔들림 계약,
목표 창 30~60 / 60~120초는 **이미 최신이어서 건드리지 않았다.**

| 자리 | 이전 | 이후 · 근거 |
|---|---|---|
| §7.2 삭제 표 | 「사이클 결과 키 5 · 스텝 궤적 키 4 — 과열 관련 전량」 | **키 이름을 박았다** — `heat_curve`·`peak_heat`·`end_heat`·`carry_heat`·`deviation_load` / `heat`·`bond`·`reverse`·`link`. 개수는 그대로다(`rune_engine.gd` 머리 주석 대조) |
| §7.2 남긴 둘 | 호출부가 「`game.gd`」로만 적혀 있었다 | **`game.gd:3045`**(2번째 인자) · **`game.gd:3004`·`deal_cycle_controller.gd:324`**(`overloaded` 실소비자 2곳). 무시된다는 사실을 **`rune_test`의 `p_cap`**이 문다는 것도 명시 |
| §7.2 (신설 문단) | 없었다 | **Y8의 검사 묶음 이동을 적었다** — `rune_test`의 `heat_neutral` **은퇴**(단언은 `p_cap`으로 이관) · `data_test`의 `rune_heat_neutral` → **`rune_exec_cap` 개명**. 과열의 뒷문을 지금 지키는 것이 그 **음성 축**이다 |
| §7.5 표 | 「체류 압박(**HP 증가 배수**) ×2.100 → ×2.000」 | **라벨이 틀렸다.** 이 값은 HP 배수가 아니라 **d=12 레벨업 시간 배율**(`1/효율(12)` = `H(12)^0.5`)이다 — `H(12)`가 4.000이므로 HP 배수라면 4.0이어야 한다(handoff-y8 §7-1). 라벨을 고치고 **목표 창 ×2.0 ± 0.15**를 붙였다 |
| §7.5 · §11 | 판정 8축의 **목표 창이 문서에 없었다**(실측값만 있었다) | `hp_index` **−25% ± 10%p**를 §7.5에 명시하고, §11 `balance_probe` 블록에 **8축 → 목표 창이 어느 절에 있는지** 색인을 달았다 |

- 손대지 않은 낡아 보이는 자리 1건: §11의 실행 시간 「약 130초(YZ 실측 129/128 · **Y8 시점 135초**)」.
  **Y8의 135초가 더 오래된 측정**이므로 YZ 값이 정본이고, 두 값이 이미 연혁으로 함께 남아 있다.

---

### 2026-08-10 18:00 KST — **2차 플레이테스트 피드백 라운드 (Y0~Y8 · YA · YZ 열한 웨이브)**

- 사용자 요청 (2026-08-09 2차 플레이테스트 · **25건** · 원문 요지와 처리 웨이브):

  | # | 원문 요지 | 처리 웨이브 |
  |---|---|---|
  | ① | **어색한 한글 전면 수정** — 화면에 나오는 문장을 사람 말로 | **YZ**(최종 스윕) + 각 웨이브가 자기 화면 |
  | ② | **각인 부착 화면 간소화** — 칸당 8줄 × 5칸이 너무 많다 | **Y3** |
  | ③ | **ESC 편집에서 각인/스킬 구분** — 무엇이 각인인지 안 보인다 | **Y3** |
  | ④ | **각인 15종 전면 교체** — 효과를 한 번에 알아볼 수 있게 | **Y0/Y1 · Y3** |
  | ⑤ | **스테이지 줄 · 모달 톤** — 상단 문장을 그림으로, 모달 띠를 걷어라 | **Y4** |
  | ⑥ | **필드**(돌 충돌 · 바다 · 몹 무리/도망 패턴 · 1·2스테이지 낮 선공 0) | **Y5** |
  | ⑦ | **전 화면 스크린샷 QA** — 화면 밖으로 튀어나가는 것들 | **Y4 · YZ** |
  | ⑧ | **마왕 PFP가 구버전** | **Y4** |
  | ⑨ | **세공사 = 카드 3장 · 칸/레일 랜덤** | **Y3** |
  | ⑩ | **세공사 레이아웃 · 보유 골드만 크게** | **Y3** |
  | ⑪ | **밀정 리뉴얼** | **Y3** |
  | ⑫ | **체력바 · 장비 부위 · 교체 확인** | **Y4** |
  | ⑬ | **스킬 아이콘 교체 · 태그는 속성만** | **Y0/Y1 · Y4 · YA** |
  | ⑭ | **스킬 설명 = 콤보 암시** | **Y0/Y1 · Y4** |
  | ⑮ | **무료 VFX · 에셋 수급** | **YA** |
  | ⑯ | **재화 표기를 골드 아이콘으로** | **Y4** |
  | ⑰ | **난이도 = 패턴·물량**(HP를 올려서 어렵게 만들지 마라) | **Y5 · Y8** |
  | ⑱ | **발견 내비 · 랜덤 이벤트 · 재미 아이템** | **Y6** |
  | ⑲ | **과열 제거** | **Y0/Y1 · Y2** |
  | ⑳ | **장비 빈칸 실루엣** | **Y4 · YA** |
  | ㉑ | **속성 구별 강화 · 이름 재작명** | **Y0/Y1 · Y4** |
  | ㉒ | **상자 애니 최신화** | **Y4 · YA** |
  | ㉓ | **상자에서 체력 회복** | **Y6** |
  | ㉔ | **결과 화면 깨짐** | **Y4** |
  | ㉕ | **타격감 전면 향상** | **Y7** |

- 상태: **ready_for_playtest**
- 결정한 내용: 설계를 **Y0 한 웨이브**(`docs/FEEDBACK_Y.md`)로 먼저 굳히고, 규칙·데이터를
  **Y1**이 `game.gd` 미접촉으로 갈아 끼운 뒤, **Y2~Y7 여섯 웨이브를 `game.gd` 직렬 체인**으로
  돌렸다(동시에 두 웨이브가 `game.gd`를 열지 않는다). **Y8**이 밸런스를 실측 재확정하고,
  **YA**가 에셋을 굽고, **YZ**가 한글·잔여 수리·문서를 마감했다.
  **이번 라운드는 표면이 아니라 게임 규칙을 바꿨다.**

- **웨이브별 한 줄 요약 (열한 웨이브)**

  | 웨이브 | 문서 | 한 줄 |
  |---|---|---|
  | **Y0** | `docs/FEEDBACK_Y.md` | 설계 웨이브. 코드 0줄. 피드백 25건 → 시스템 설계 · 웨이브 분할표(§9.3) · 리스크 12건 |
  | **Y1** | `docs/handoff-y1.md` | 규칙·데이터 골격(설계 문서의 **Y0**에 해당). `rune_engine.gd` 전면 재작성 — 과열 심볼 전량 삭제 · 각인 24 → 15 · `SLOT_EXEC_CAP 2` · RELOAD 선형화. 스킬 28종에 `combo`·`impact`·`silhouette` 신설. **`game.gd` 미접촉** |
  | **Y2** | `docs/handoff-y2.md` | 직렬 체인 1/6 — 과열 런타임 소비자 제거 + 레일 각인 완결(`factory_rail_runes` 저장 키 · 3택 혼입 · `run_peak_steps` 개명 · 스트립 358×74 · `RUNE_SHOP_RAIL_PREMIUM 1.20`) |
  | **Y3** | `docs/handoff-y3.md` | 직렬 체인 2/6 — 각인 UI 3종(부착 2단계 · ESC 편집 글리프 · 세공사 레이아웃) + **밀정 전면 재작성**. 캡처에 `RenderingServer.force_draw()` 삽입 |
  | **Y4** | `docs/handoff-y4.md` | 직렬 체인 3/6 — 전투 UI · 모달 · 색. 한자 폐기 · 색 두 개 교체 · `_factory_card_color()`가 원소를 봄 · 마왕 초상 · 결과 화면 수리 · 체력바 세그먼트 · 금화 그림 · 상자 6프레임 · **`pixel_portrait.gd` 삭제** |
  | **Y5** | `docs/handoff-y5.md` | 직렬 체인 4/6 — 필드 생태(습성 층 · 지형 가중 스폰 · 돌 우회 · 물 통행 · 1·2스테이지 낮 선공 0). `terrain_probe.gd` · `--field-test` 신설 |
  | **Y6** | `docs/handoff-y6.md` | 직렬 체인 5/6 — 발견 · 사건 8종 · 재미 아이템. **저장 schema 4 승격**(5키 신설) · 소비 슬롯 `Q` · 상자 배당 재편. `--event-test` 신설 |
  | **Y7** | `docs/handoff-y7.md` | 직렬 체인 6/6(마지막 콘텐츠 웨이브) — 타격감. 몹별 피격 반응 · `impact` 8종 · **카메라 흔들림 계약**(4px / 0.12초 · 허용 다섯 · 지운 넷) |
  | **Y8** | `docs/handoff-y8.md` | 밸런스 재측정·확정. `balance_probe.gd` 전면 재작성(12절 · 판정 8축 · **`pass=1`이 회귀 계약**). dwell 곡선 · `STAGE_HP_BASE` · `CYCLE_HEALTH_GAIN` · 물량 4축 · 보스 `DESIGN_HP` 전량 · 목표 창 재설정 · 골드 수지 |
  | **YA** | `docs/handoff-ya.md` | 에셋 수급·제작. `art/v2/build_assets_y.gd` 신설 · 런타임 PNG 15장 · 웹 무료 팩 3개 라이선스 정리(`game-icons` CC BY 113 SVG). **`.gd` 로직 0줄** |
  | **YZ** | (이 항목) | 마감 — 한글 최종 검수 · 잔여 수리 7건(검사 흔들림 3건 포함) · 모달 부제 밴드 · 문서 전면 개정 · 최종 검증 |

- **이 라운드가 바꾸지 않은 것**
  - **5칸 딜싸이클 골격**(`SLOT_COUNT = 5` · 무스크롤 · 런 시작부터 전부 열림)
  - **상태이상 5종과 반응 매트릭스 11종**(계수 한 줄도 안 건드렸다)
  - **스테이지 5개 구조**(무한 필드 + 성 1 + 캠프 1 + 보스방 1 · 보스 로테이션 `[A,B,C,B+,C+]`)
  - **트로피 2택1**(고정 스탯 + 특별 카드 · 버린 쪽은 마왕에게)
  - **WFC 무한 맵**(청크 32×32 · 결정적 시드 · `TILE_RULES`)
  - **조작 체계**(`WASD`/`Shift`/`E`/`Esc`/`Tab`/`Space` · 호버가 상세 창구).
    Y6이 `Q`(소비 아이템) 하나를 **더했을 뿐** 기존 키의 뜻은 하나도 안 바뀌었다.

- **핵심 수치**

  | 축 | 이전 | 이후 |
  |---|---:|---:|
  | 각인 종류 | 24 | **15** (칸 10 + 레일 5) |
  | 한 칸 실행 상한 | 과열 8단 사다리 | **2회**(`SLOT_EXEC_CAP`) |
  | `STEP_CAP` | 14 (게임 규칙) | **12 = 2n+2** (방어 단언) |
  | RELOAD 식 | 빚 × (1 + 과열 × 0.18) × 삼각할인 | **빚 × 레일 배수 × `reload_scale`** |
  | 저장 스키마 | schema 3 · 48키 · 지문 67축 | **schema 4 · 53키 · 지문 72축** |
  | 자동 검사 | 15종 (컴파일 1 + 기능 14) · 83초 | **17종 (컴파일 1 + 기능 16) · 약 130초** |
  | `DWELL_HP_LINEAR` / `_QUAD` | 0.14 / 0.012 | **0.13 / 0.010** |
  | `STAGE_HP_BASE` 5스테이지 | 3.20 | **2.40** |
  | 몹 HP 총합(세 축의 곱) | — | **−59 %** |
  | 스테이지 보스 목표 창 | 45~90초 | **30~60초** (실측 45/53/56/38/36) |
  | 보스 `DESIGN_HP` A/B/C | 2,750 / 2,270 / 2,620 | **2,130 / 2,440 / 3,180** |
  | 마왕 기저 HP | 611 | **1,180** |
  | 딜싸이클 스트립 | 380×74 | **358×74** |
  | 필드 HUD block % | 3.32(X 실측 · 계약 상한 3.35) | **3.19** |
  | 보물상자 위협 총량 | 21 % | **18 %** |
  | 상점가 5스테이지 배수 | ×2.40 | **×2.00** |
  | 무한 애니메이션 | 1건(`pixel_portrait.gd`) | **0건** |

- 변경 파일 (Y 라운드 누계 · 줄 수는 **현재 값**이고 §5 코드 지도와 같다):
  - `godot-game/scripts/core/rune_engine.gd`: **970줄로 전면 재작성**(Y1). 각인 15종 ·
    `SLOT_EXEC_CAP`/`STEP_CAP`/`RAIL_*` 신설 · 과열 심볼 전량 삭제 · RELOAD 선형화.
    원본은 `docs/v1-archive/rune_engine_v3_24.gd.txt`
  - `godot-game/scripts/core/tuning.gd`: 686 → **828줄.** dwell 곡선 · `STAGE_HP_BASE` ·
    물량 4축 · 보스 계수 · `STAGE_PRICE_STEP` · `RUNE_SHOP_RAIL_PREMIUM` · 카메라·발견·사건
    상수. **`NIGHT_ENEMY_LIMIT_STEP` 삭제**(YZ). 바꾼 상수 옆에 **「이전 값」 주석**을 남겼다
  - `godot-game/scripts/game.gd`: 13,436 → **15,969줄.** 과열 소비자 제거(Y2) · 각인 UI와
    밀정(Y3) · 색·모달·결과 화면(Y4) · 필드 생태 배선(Y5) · 발견/사건/소비 슬롯(Y6) ·
    타격감과 카메라(Y7)
  - `godot-game/scripts/deal_card_library.gd`: 492 → **645줄.** `combo`·`impact`·`silhouette`
    3키 신설 · `SILHOUETTES` 14 · `IMPACTS` 8 · `element_name()` 한글화.
    원본은 `docs/v1-archive/deal_card_library_v3_x1.gd.txt`
  - `godot-game/scripts/enemy.gd`: 988 → **1,471줄.** Y5 습성 층 + Y7 반응 프로필
  - `godot-game/scripts/monster_library.gd`: 440 → **722줄.** 습성 데이터 + `CYCLE_HEALTH_GAIN`
  - `godot-game/scripts/world_grid.gd`: 899 → **1,002줄.** 지형 규칙(돌·물)
  - `godot-game/scripts/boss_library.gd`: 458 → **495줄.** `DESIGN_HP` 재확정 · `"uses_heat"` 삭제
  - `godot-game/scripts/skill_icon.gd`: 490 → **572줄.** `_reskin_to_element` · `set_element_palette`
  - `godot-game/scripts/chest_open_effect.gd`: **6프레임 시트 재생으로 전면 재작성**(Y4).
    원본은 `docs/v1-archive/chest_open_effect_y4.gd.txt`
  - `godot-game/scripts/pixel_portrait.gd`(+`.uid`): **삭제**(Y4).
    원본은 `docs/v1-archive/pixel_portrait_y4.gd.txt`
  - `godot-game/scripts/test/test_runner.gd`: 5,660 → **8,381줄.** `--field-test`·`--event-test`
    신설 + 기존 12종 갱신
  - `godot-game/scripts/test/balance_probe.gd`: 1,207 → **1,606줄로 전면 재작성**(Y8 · 12절 · 판정 8축)
  - `godot-game/scripts/test/rune_test.gd`: **1,473줄로 전면 재작성**(Y1).
    원본은 `docs/v1-archive/rune_test_w1.gd.txt`
  - `godot-game/scripts/test/data_test.gd`: **1,481줄**(각인 15종 · 카드 3키 · 폐기 심볼 감시)
  - `godot-game/scripts/test/terrain_probe.gd`: **신규 245줄**(Y5 · YZ가 full 판정식 완화)
  - `godot-game/scripts/test/run_all.sh`: 320 → **336줄**(`ALL_TESTS` 2줄 추가)
  - `godot-game/art/v2/build_assets_y.gd` + 런타임 PNG 15장: **신규**(YA)
  - `docs/FEEDBACK_Y.md` · `docs/handoff-y1.md` ~ `handoff-y8.md` · `docs/handoff-ya.md`: **신규**
  - `AGENTS.md`: 이 항목 + 머리말 · §0 · §1 · §2 · §3 · §4 · §5 · §6 · §7 · §9 · §10 · §11 ·
    §12 · §13 전면 개정

- 사용자에게 보이는 변화:
  - **딜싸이클에서 과열 온도계가 사라졌다.** 대신 규칙이 하나뿐이다 —
    **한 칸은 한 바퀴에 두 번까지.** 결과 화면의 「최고 과열」도 **「한 바퀴 최다 칸」**이 됐다.
  - **각인이 15개로 줄고 이름이 쉬워졌다.** 「두 번 치기」·「한 칸 뒤로」·「마무리」처럼
    무슨 일이 일어나는지 이름이 그대로 말한다. 그중 다섯은 **칸이 아니라 레일 전체**에 붙고
    (「되돌이」·「빨리 감기」…) 세공사 카드에 **칸/레일 배지**로 표시된다.
  - **속성이 한글 한 낱말이 되고 일곱 색이 서로 갈린다.** 불은 빨강, 기름은 갈색이다.
    아이콘 판도 속성 색을 따라온다.
  - **필드가 살아 있다.** 돌은 못 지나가고, 몹이 무리 지어 다니고, 겁 많은 것은 도망가며,
    1·2스테이지 낮에는 먼저 덤비는 몹이 없다.
  - **길이 생겼다.** 가까이 가면 자리가 «발견»되고 화살표가 붙는다.
    사건 8종과 소비 아이템(`Q` 한 칸)이 돌아다닐 이유를 만든다.
  - **때리는 느낌이 달라졌다.** 몹마다 맞는 반응이 다르고 스킬마다 밀치기·느리게·꽂기가 갈린다.
    화면 흔들림은 **다섯 자리에서만** 아주 짧게 일어난다.
  - **보스가 짧아졌다.** 다섯 관문이 36~56초, 마왕이 85초다.
  - **상자에서 체력이 나오고 재미 아이템이 나온다.** 위협 칸은 21% → 18%로 줄었다.
  - **마왕 초상·상자 열기·체력바·금화 표기가 최신 그림으로 바뀌었다.**

- 데이터/저장 호환성: **schema 3 → 4.** `schema_version < 4`인 스냅샷은 **읽지 않고 버리고**
  로비가 그 사실을 **한 번 알린다**(`saved_run_dropped`). 신설 5키 ·
  개명 2건(`run_peak_heat` → `run_peak_steps` · `spy_revealed` → `spy_wipe_stage`) ·
  가산 1건(`factory_rail_runes`). 총 **53키 · 지문 72축 · mismatch=0**.
  카드·아이템·트로피·몬스터의 `id`는 Y 라운드 내내 **한 개도 바뀌지 않았다**.
- 남은 문제: **§12 「Y 라운드가 남긴 것」** 14항 참조. 요지는 넷이다 —
  ①밸런스 실기 플레이테스트가 여전히 없다(Y8의 실측은 시뮬레이션이다)
  ②에셋 2건 미납(`ui-kit-skill-shape` 14칸 · `ui-kit-rune` 15칸)
  ③`game-icons` CC BY 크레딧 결정 미완(현재 의존 0)
  ④`RELOAD`가 영문 그대로 남았다(고유 기계 이름으로 취급 — 바꾸려면 전용 웨이브).
- 다음 AI가 시작할 정확한 지점: **3차 플레이테스트 피드백 대기.**
  관측 여덟 가지와 로그 보조 지표는 §1 체크포인트의 `next_exact_step`에 있다.
  피드백이 오면 `active_request`를 갱신하고 `status`를 `in_progress`로 되돌린다.
  **밸런스를 만지기 전에 반드시 `balance_probe.gd`를 돌려 `pass=1`을 확인한다.**

#### YZ — 한글 최종 검수

사용자 피드백 ①의 마무리다. 스윕은 **두 겹**으로 돌았다.
**① 금지 어휘 감사** — 비테스트 `.gd` 41개의 한글 리터럴 **1,659개** 전수 검사, **위반 0건**.
「과열」류 151건은 **전부 주석**이라 유저 노출이 없다(`data_test`의 `no_banned_words`가 상시로 문다).
**② 읽기 검수** — 화면에 실제로 나가는 문자열 **1,517개**를 훑어
(주석 제외 · `scripts/test/` 제외) **약 180곳**을 고쳤다.

| 파일 | 고친 수 | 대표 |
|---|---:|---|
| `game.gd` | ~121 | `사이클이 강제 종료되었습니다` → `한 바퀴 최대치 · 바늘이 멈췄습니다` · `몬테카를로 %d회(%.1f ms)를 돌린 평균입니다` → `%d번 굴려 나온 평균입니다 (%.1f ms)` · `세미 엘리트` → `이름 있는 마물` · `NPC 4종으로 정비` → `상인 넷에게 들르기` · `선딜(telegraph)` → `예비 동작` · `고속 컨베이어` → `모든 칸 빨리` · `미믹!` → `가짜 상자!` · `체류 압박을 사고팝니다 / 머문 밤은 화폐입니다` → `머문 밤을 사고팝니다 / 밤이 곧 돈입니다` |
| 라이브러리 8종 | 56 | `대폭 연소!` → `크게 타오름!` · `감전 유막!` → `기름에 전기!` · `쇄빙!` → `얼음 깨짐!` · `전도!` → `번개 옮음!` · `과충전` → `전기 넘침` · `커먼/레어/유니크/히어로` → `일반/희귀/특별/영웅` · `아레나` → `싸움터` · `산성 분비` → `산 뱉기` · `응결핵` → `굳은 핵` · `왕국 변경` → `왕국 변두리` |

고친 갈래는 넷이다. **① 어려운 한자어**(미열람 · 미건설 · 미선택 · 과밀 · 전황 · 임계 ·
포화 · 시연 · 응결핵 · 인화 · 분비) **② 영문 조어**(각인 드래프트 · 세미 엘리트 · 미믹 ·
아레나 · 몬테카를로 · 선딜 · NPC · RANK · HP · 도트 틱 · 클리어 · 커먼/레어/유니크/히어로 ·
플레이타임 · 스노볼 · 빌드업 · 컨베이어) **③ 과도한 명사화**(배치 완료 · 증설 완료 ·
입고 · 배송 · 회복 가능 · 휴식 소진 · 발견 처리 · 획득 취소) **④ 조사 버그**
(`칸 %02d을` → `%02d번 칸을` · `%s은(는)` → `_particle_eun()` · `%s이(가)` →
새 `_particle_i()` 헬퍼 · `칸 %d 에` 군더더기 공백).

> **남긴 예외 셋과 그 이유**
> * **`RELOAD`** — 「딜싸이클」과 같은 고유 기계 이름으로 취급했다. 검사 94곳이 이
>   문자열을 물고 있어 마지막 웨이브에서 바꾸는 것이 더 위험했다(§12 「Y 라운드가 남긴 것」).
> * **`G`** — 「골드」로 풀지 않았다. 금화 칩과 문자열이 다른 낱말을 쓰면 표기가 갈린다.
> * **`시너지 발동` · `반격 창`** — `--boss-test`의 필수 문자열 목록과 `data_test`가
>   문고 있다. 같은 줄의 `사이클이 끝나면`만 `한 바퀴가 끝나면`으로 고쳤다.
>
> 금지 어휘(과열 · 과부하 · 잔열 · 나침반 · 각인 강화 · 카드 이동 모드 · 칸 교환 모드 ·
> 한자 병기)는 **문자열에서 0건**이다(`data_test`의 `no_banned_words`가 매번 확인한다).

#### YZ — 잔여 수리 7건

1. **`terrain_probe` full 모드 판정식 완화** — 「표본 300개 전수 통과」 →
   「p01·p99가 창 안 + 최대 초과 ≤ 0.005 + 총합이 창 안 + 2×2 블록 불변식」.
   **지형 규칙 자체는 무변경**이다.
2. **`NIGHT_ENEMY_LIMIT_STEP` 삭제** — 리포지토리 전체 소비자 0.
   밤 물량은 전부 `DWELL_COUNT_STEP`에서 온다.
3. **`_build_preview_slot()`의 각인 줄 글자 겹침** — 어두운 판을 깔고 이름을
   **「하나 + 외 N」**으로 접었다(§13 함정 36).
4. **`_build_choice_card_body()`의 장비 태그 줄 겹침** — 두 줄로 감기는 태그에
   24px만 줘 요약 줄과 포개졌다. 자리를 40px로 늘리고 요약 줄 시작 y를
   `tag_top + tag_height`로 바꿨다(§13 함정 33의 짝).

**6·7. `--save-test fields`의 흔들림 두 겹** — `run_all` 2회 연속을 증명하려다 잡았다.
`--save-test`는 복원 뒤 **벽시계 0.3초**를 기다린 다음 지문 72축을 정확 일치로 대조하는데,
그 0.3초 동안 세계가 돈다. 두 축이 그래서 흔들렸다.
* **`player_position`** — 복원된 플레이어가 계속 걸어서 실행마다 다른 자리에 도착했다
  (실측 156px 어긋남). 지문을 뜰 때까지 **플레이어 물리만** 멈췄다. 클럭·잠식 스윕은
  그대로 도므로 `DRIFT_KEYS` 넷의 판별력은 안 지워진다.
* **`discovered`** — 복원 자리가 사건 표식의 발견 반경(520px) 안이면 그 사이에 표식이
  하나 켜져 3개 → 4개가 됐다. **발견은 취소되지 않는 단조 증가 축**이므로 정확 일치가
  애초에 틀린 계약이었다 — `GROWTH_KEYS`를 신설해 **부분집합 판정**(하나라도 사라지면 실패)
  으로 바꿨다. 진짜 복원 버그는 그대로 잡힌다.
고친 뒤 **10회 연속 통과**(League of Legends가 CPU 150%를 쓰는 부하 상태에서 측정).

**덤으로 잡은 것: `--event-test items`의 흔들림**(8회 중 3회 FAIL).
Y6·Y7이 남긴 것으로 YZ 범위 밖이었지만, 「run_all 2회 연속 PASS」를 증명하려면
먼저 흔들림을 없애야 했다. 원인은 실전 물리 프레임 사이에 열린 레벨업 모달이고
(§13 함정 37), 고친 뒤 **12회 연속 통과**를 확인했다.

**실측과 영향 범위**

| 수리 | 손댄 파일 | 실측 |
|---|---|---|
| `terrain_probe` 판정식 | `test/terrain_probe.gd`만 | 구: `in_band=299/300` → **FAIL**. 신: `p01=0.1272 p99=0.1924`(창 0.12~0.20 안) · `over=0.0006`(허용 0.0050) · `AGGREGATE=0.1573` · `impossible_shapes=0` → **PASS**. fast 40초 / full 약 40분 둘 다 PASS |
| `NIGHT_ENEMY_LIMIT_STEP` 삭제 | `core/tuning.gd` · `test/balance_probe.gd`(보고 문장 1줄) | 소비자 0 확인 후 상수 1줄 삭제. `--stress-test` · `--stage-test` · `balance_probe` 물량 축 전부 무변화 |
| 공유 렌더러 글자 겹침 **2건** | `game.gd` 2함수 | ⓐ `_build_preview_slot()` — 각인 줄에 `UI_CHIP_BG` 어두운 판(`ColorRect`, `Panel` 아님)을 깔고 외곽선을 끄고 이름을 「하나 + 외 N」으로 접었다. **소비자 7곳 동시 반영**(각인 드래프트 · 스테이지 보스 프리뷰 2 · 마왕 프리뷰 2 · 밀정 · 결과 화면). ⓑ `_build_choice_card_body()` — 장비 카드 태그 줄이 두 줄로 감기는데 자리가 24px뿐이라 넘친 둘째 줄이 첫 요약 줄 위에 얹혔다. 자리를 40px로 늘리고 요약 줄 시작 y를 상수 80에서 **`tag_top + tag_height`**로 바꿨다. **아이템 2택 · 상자 전리품 · 장비 교체 확인 3화면 동시 반영** |

> ⓑ는 handoff-y4 §8.4가 「`_card_block_panel()`의 아이콘 위 흐린 글자」라고 적은 건이다.
> 실제 원인은 카드 블록이 아니라 **그 오른쪽 정보 열의 y 좌표**였다(캡처 확대로 확인).
> 두 겹침 모두 캡처 전후 대조로 눈으로 확인했다.

**5. 필드 상자 골드에 스테이지 스케일을 붙였다** — Y8이 「의도인지 누락인지 모르겠다」로
남긴 건을 **누락으로 판정했다.** 사건 보상·안전 상자·상점가가 전부 `stage_price_scale()`을
타는데 필드 상자만 안 탔고, 그래서 「보물섬」이 깔아 준 상자와 바로 옆 필드 상자가 같은
스테이지에서 다르게 굴렀다. `_open_chest()`의 `gold`·`curse` 두 칸에 곱했다.
재산정: 상자 1개 기대 7.08 G × 8개 × 5스테이지 = 평탄 283 → 스케일 425 G(**+142**) ·
총수입 2,834 → **2,976 G** · 완전 지출 2,271 G · 골드 여유 19.9% → **23.7%**(창 15~30%).
⚠️ `balance_probe.gd`의 `FIELD_CHEST_GOLD` 주석과 ⑧ 합산은 아직 「안 곱한다」로 적혀 있다 —
판정 게이트가 아니라 지금 빨개지지 않지만, 프로브를 여는 다음 웨이브가 갱신해야 한다(§12 5b).

⚠️ **`status_test.gd` `-s` 단독 실행 멈춤**은 파일 머리에 실행법 경고 블록을 박아
해결했다(정식 경로는 `-- --status-test`). `run_all.sh`도 그 경로로 부른다.

#### YZ — 문서 마감

`AGENTS.md` 전면 개정 — 머리말 · §0 · §1 · §2 · §3 · §4 · §5 · §6 · §7 · §9 · §10 · §11 ·
§12 · §13 · §15.

`README.md` — 조작표(`Q` 소비 슬롯 · 두 제스처) · 각인 15종 표 2개 · 과열 절 →
「RELOAD 빚」 절 · 속성 7계 한글 · dwell 곡선 실측 · 보스 목표 창 · 필드 생태/사건/
소비 아이템 · 검사 16종과 프로브 5종 · 코드 지도 · CC BY 크레딧 의무.

`docs/ui-style-v3.md` §12 — **무효가 된 마지막 두 항을 갈아 끼웠다.**
구판은 「레일 5칸 폭 증명 `20 + 152×5 + 12×4 = 828` ⊂ 밴드 1048」과
「상단 HUD 폭 증명 `16 + 330 + 12 + 440 + 8 + 198 + 8 + 252 + 16 = 1280`」이었는데,
X3가 밴드를 `1048×156 → 380×74`로 줄이고 나침반 패널을 삭제하면서 두 등식이
**존재하지 않는 값들의 합**이 됐다(그 뒤 Y2가 380 → 358로 한 번 더 줄였다).
새 세 항은 `RAIL_BAND_RECT (461,636,358,74)` 증명 · 상수 하드코딩 금지 ·
`hud_block_pct ≤ 3.35%`다. 왜 옛 두 항이 죽었는지도 같이 적어 뒀다.

**모달 부제 밴드(피드백 ⑤의 나머지 절반)** — Y4가 리본 폭까지 맞췄고 레벨업 모달만
밴드를 걷은 상태였다. YZ가 **다섯 화면**을 더 걷었다.

| 화면 | 처리 |
|---|---|
| 각인 3택 | 밴드 「각인 하나를 고르세요」 **삭제** + 리본을 「**각인 고르기** · 1 / 2 단계」로(영문 조어 「드래프트」도 같이 사라졌다) |
| 전조 보상 | 밴드 「마왕에게서 무엇을 뜯어낼까요」 **삭제**. 두 카드가 이미 「각인 뜯기 · 마왕 −1」 「카드 되찾기 · 보관함 +1」이라고 말한다 |
| 아이템 2택 · 상자 전리품 | 밴드 「가져갈 아이템 카드를 고르세요」 **삭제** + 리본을 「… · 하나 고르기」로. 규칙 띠(「안 고른 카드는 마왕에게」)는 **남겼다** — 카드만 봐서는 알 수 없는 유일한 규칙이다 |
| 스테이지 보스 프리뷰 | 설명 두 문장 → **한 문장**(「칸 N개 · 각인 없음 — 한 바퀴가 끝나면 반드시 무방비해집니다」) |
| 마왕 프리뷰 | 설명 네 문장 → **한 문장**. 나머지는 아래 두 레일 그림이 그대로 보여 준다 |
| 결과 화면 | 두 줄 다 **한 문장으로** 줄였다. 이 화면은 `_begin_modal_tooltips()`를 부르지 않아 호버로 내릴 곳이 없으므로 지우는 대신 가장 짧은 사실만 남겼다 |

⚠️ **남은 곳: 공장/편집 화면의 상황 부제 4분기 · 트로피 3단 설명.** 공장 부제는
「지금 무엇을 배치하는 중인가」를 말하는 **상황 안내**라 상시로 필요하고, 트로피는
2택1의 근거라 카드 밖에 있어야 한다. 둘 다 「설명 띠」가 아니라고 판단해 남겼다.

#### YZ — 최종 검증

| 검증 | 결과 |
|---|---|
| `--editor --quit` | **exit 0** · SCRIPT ERROR / Parse Error **0줄** |
| `run_all.sh` 17종 | **2회 연속 PASS** (126초 / 126초 · 잔여 Godot 0 확인 후) |
| `balance_probe.gd` | `BALANCE_PROBE_COMPLETE pass=1 rune_steps=1 hp_index=1 dwell_curve=1 dwell_pressure=1 volume=1 gold=1 boss_ttk=1 demon_ttk=1` |
| `rune_test.gd` | PASS · `exec_cap_violations=0 step_bound_violations=0 overload_count=0 cycles=25001 max_steps_random=10 mean_steps_random=3.86` |
| `data_test.gd` | PASS · `runes=15 slot_exec_cap=2 step_cap=12 no_banned_words=true banned_scan_strings=174 impacts=8 silhouette_pairs=28` |
| `--status-test`(정식 경로) | PASS |
| `rift_probe.gd` | PASS · `failures=0` |
| `terrain_probe.gd` fast | **PASS** · `in_band=300/300` · `p01=0.1269 p99=0.1917` · `impossible_shapes=0` (약 40초) |
| `terrain_probe.gd` full | **PASS** · `AGGREGATE=0.1573` · `p01=0.1272 p99=0.1924` · `over=0.0006`(허용 0.0050) · `impossible_shapes=0` (약 40분 · 판정식 완화 직후 1회 완주) |
| 캡처 전종 재생성 | **73컷 · 고유 지문 72** — 중복 1쌍은 구조적(`onboarding-minimal-v2 == -p2`). **프레임 흘림 0** |
| 캡처 육안 전수 | 73컷 전부 확인 · 잘린 글자 0 · 겹친 글자 0 · 화면 밖 튀어나감 0 |
| 비headless 실기 관찰 | 창 실행 **13루틴 × 3회 = 39회 · 298초** · SCRIPT ERROR / ERROR / `=false` **0줄** |

⚠️ 캡처 직전에 `ps aux | grep godot`으로 잔여 인스턴스 0을 확인했다. 실제로 이번에도
`-s status_test.gd`로 잘못 띄운 인스턴스 하나가 CPU 0%로 매달려 있었고(§13의 함정 그대로)
그것을 죽인 뒤에 찍었다.

---

### 2026-08-09 20:40 KST — **플레이테스트 피드백 라운드 (X1~X4 네 웨이브)**

- 사용자 요청 (2026-08-09 플레이테스트 · 스크린샷 3장 기반 · 6건 원문 요지):
  - ① **"온보딩에 텍스트가 너무 많아. 조금 더 쉽게 설명해 줘."**
  - ② **"튜토리얼 알려 줄 때 게임이 시작되면 안 돼. 시작되니까 내가 맞을까봐 집중을
    못하겠어."**
  - ③ **레벨업 모달 대개편(최우선)** — "모달 이름은 '레벨 업'으로 간단하게 / 가장 부각되어야
    할 건 스킬의 이미지 / '3회 타격' 같은 태그는 모두 지우고 / '한 바퀴 빚'·'피해계수'도 지워
    / RELOAD·쿨타임은 기존 시각화 유지 / 카드 보유 수 / **속성은 텍스트가 아니라 배경색 또는
    블록색 통일로**(색약 대비 글리프 1개까지 허용)". 지속시간·RELOAD 정의는 "온보딩 몫".
  - ④ **"레벨업 2택에서 각인 강화를 제거"** — "취소하면 골드를 얻고 **마왕에게도 이득이 안
    가게** / 각인 NPC가 스킬 카드처럼 **3개 선택지**, 효과가 좋을수록 골드를 더, 새로고침하면
    새 각인들로 리프레시 / 각인은 **보물상자에서도** 나오게".
  - ⑤ **ESC 편집 대간소화** — "텍스트가 너무 많아. 훨씬 더 간단하게 / 필요한 정보는 최대한
    **마우스 호버**로 / ESC를 눌렀을 때 이게 어떤 구조인지 **중학생이 봐도** 알게 /
    마우스 호버·드래그앤드롭 등 편의성을 대폭".
  - ⑥ **HUD 탈블록** — "모든 정보들이 **블록으로 나뉘어져** 있어. 블록을 제거하고 다시
    디자인해 줘 / 위치 알려주는 편의성은 아예 섹터를 지우고 화면에서 **화살표로 작게
    navigation** / 딜싸이클 범위가 너무 커 — 최대한 아이콘으로 **미니모드** /
    블록 범위 없애서 **필드가 더 잘 보이게**".
- 상태: **ready_for_playtest**
- 결정한 내용: 우선순위대로 **X1(③④) → X2(⑤) → X3(⑥) → X4(①②)** 네 웨이브로 나눠
  순차 처리했다. 뒤 웨이브가 앞 웨이브의 자산을 이어받도록 순서를 짰다 —
  X1이 만든 **원소 색표**를 X2·X3가 쓰고, X2가 만든 **공용 툴팁**을 X3가 필드에서 처음 쓰고,
  X1~X3가 화면에서 지운 것들을 X4의 온보딩이 한 번에 가르친다.
  **게임 규칙(전투·상태이상·dwell 곡선·보스·저장 스키마)은 한 줄도 안 바꿨다.**
  바뀐 것은 정보 구조 · 각인 획득 경제 · 조작 모델 · 화면 점유율이다.
- 웨이브별 처리:
  - **X1 — 레벨업 모달 대개편 + 각인 경제 이전**(피드백 ③④).
    카드에서 배지·태그·피해계수·한 바퀴 빚 줄을 전부 지우고 **아이콘을 48 → 152px**로
    키웠다. 속성은 **색**으로 옮기고(`ELEMENT_COLOR` 단일 진실 원천 신설 + 색약 대비
    1글자 마크) 보유 수는 우상단 칩 하나로 줄였다. 세 번째 선택지였던 「각인 강화」를
    삭제하고 그 자리에 **「취소 +N G」**(두 카드 소멸 · 마왕 무이득)를 놓았다.
    성장 천장 자동 전환을 폐기하고(`GROWTH_CAP_AUTO_RUNE_DRAFT = false`) 기본 포커스만
    취소로 돌렸다. 각인은 **성의 각인 세공사 3택 + 새로고침**으로 옮기고 보물상자 비중을
    9% → 14%로 올렸다. 취소 파밍이 마왕을 굶기지 않도록 `DEMON_MIN_CARDS_PER_STAGE = 4`
    하한을 신설했다.
  - **X2 — ESC 편집 대간소화 + 공용 호버 툴팁**(피드백 ⑤).
    상시 문장을 **60+ → 7개**, 설명 문장(14자 이상)을 **9 → 0개**로 줄이고 지운 내용을
    하나도 버리지 않고 **`UIKit` 툴팁 컴포넌트**(신설)로 옮겼다(호버 대상 27+개).
    **조작 모드라는 개념 자체를 삭제**했다 — 카드 몸통을 끌면 카드만, 칸 손잡이를 끌면
    칸 통째. 규칙을 읽는 대신 **든 것을 본다**(집는 순간 고스트 그림이 다르다).
    드롭 가능한 자리만 밝게 남는 하이라이트를 붙이고, 장비 부위도 드롭 대상이 됐다.
  - **X3 — 필드 HUD 탈블록 + 가장자리 화살표 + 딜싸이클 미니모드**(피드백 ⑥).
    상시 불투명 판 **5장을 0장**으로 걷고, 나침반 패널을 **화면 테두리를 도는 화살표
    4종**(성·캠프·보스문·균열)으로 갈았다. 딜싸이클은 **380×74 아이콘 스트립**(Label 0개)이
    됐다*(당시 값 — Y2가 358×74)*. 화면에서 지운 문장 33줄은 **HUD 툴팁 13종**으로 내려갔다.
  - **X4 — 길잡이 중 세계 정지 + 온보딩 다이어트**(피드백 ①②).
    `get_tree().paused`를 쓸 수 없어(스텝 ①②가 실제 이동을 요구하고 Godot 4의 트리
    일시정지는 물리 서버까지 세운다) **선택 동결**을 두 층으로 만들었다 —
    시간축 `world_running` 게이트 + 노드축 제거·동결. 필드 잡몹 10기가 사라지고 뒤에
    생기는 적은 얼어붙는다. 안내판이 매 스텝 **「세계가 멈춰 있습니다」**를 말한다.
    온보딩은 조건·목록·숫자를 전부 도식으로 내려보내고 「빚」을 **「쉬는 시간」**으로 먼저
    가르친 뒤 이름을 붙였다.
- **핵심 수치**:

  | 축 | 이전 | 이후 |
  |---|---:|---:|
  | 레벨업 화면에서 읽을 문장 | 22줄 | **11줄** |
  | 레벨업 카드 아이콘 | 48px | **152px** (면적 **10배**) |
  | 레벨업 카드 1장의 글자 줄 | 9줄 | **4줄** |
  | ESC 편집 상시 문장(2자 이상 라벨) | 60+ | **7** |
  | ESC 편집 설명 문장(14자 이상) | 9 | **0** |
  | 필드 HUD block 점유율 | **31.74 %** | **3.35 %** (9.5× 감소) *(당시 값 — Y2 이후 3.19 %)* |
  | 필드가 보이는 면적 | 68.3 % | **96.7 %** *(당시 값 — Y2 이후 96.8 %)* |
  | 딜싸이클 밴드 | 1048×156 | **380×74** (면적 17.2%) *(당시 값 — Y2가 358×74로 좁혔다)* |
  | 온보딩 총 글자 | 1,798자 | **1,197자** (**−33.4 %**) |
  | 온보딩 최장 한 줄 | 59자 | **31자** |
  | 길잡이 중 필드 마물 / 클럭 | 10기 / 진행 | **0기 / 완전 동결**(`phase_drift=0.000`) |

- 변경 파일:
  - `godot-game/scripts/game.gd`: 12,006 → **13,436줄.** 레벨업 모달·취소 경제·각인 세공사
    3택(X1) · 편집 화면 전면 재작성과 툴팁 배선(X2) · 필드 HUD 탈블록·`EdgeMarker`·미니
    스트립·HUD 툴팁 13종(X3) · 길잡이 동결 5함수와 온보딩 4페이지 재작성(X4).
    신설 상수/함수 주요: `ELEMENT_COLOR` · `_element_color()` · `_element_wash()` ·
    `_cancel_skill_choice()` · `_show_rune_shop()` · `_refresh_rune_shop()` ·
    `EDIT_SLOT_*` · `_build_edit_slot_body()` · `nav_layer`/`_build_edge_nav()`/
    `_update_edge_nav()`/`_nav_ring_point()`/`_nav_guide_rect()` · `_rail_slot_color()` ·
    `_build_rail_dial()` · `hud_tooltip_layer`/`_update_hud_tooltips()`/`_force_hud_tooltip()` ·
    `_guide_clear_threats()`/`_guide_freeze_node()`/`_guide_freeze_sweep()`/
    `_guide_unfreeze_all()`/`guide_frozen_count()`
  - `godot-game/scripts/ui/ui_kit.gd`: 420 → **655줄.** §6 **공용 호버 툴팁 컴포넌트 신설**
    (`make_tooltip_layer`/`attach_tooltip`/`tooltip_focus`/`tooltip_force`/`tooltip_hide`/
    `tooltip_shown` · 지연 0.25s · 1회성 페이드 0.12s · `ABYSS·PANEL` 고정 톤)
  - `godot-game/scripts/core/tuning.gd`: 612 → **686줄.** X1 경제 블록 신설 —
    `CHOICE_CANCEL_GOLD(30)` · `GROWTH_CAP_AUTO_RUNE_DRAFT(false)` ·
    `GROWTH_CAP_DEFAULT_CANCEL` · `GROWTH_CAP_CANCEL_BONUS(1.5)` ·
    `RUNE_SHOP_PRICE_COMMON/RARE/EPIC(45/80/135)` · `RUNE_SHOP_PURCHASE_STEP(18)` ·
    `RUNE_SHOP_FLOW_PREMIUM(1.25)` · `RUNE_SHOP_PASSIVE_PREMIUM(1.15)` ·
    `RUNE_SHOP_ROLL_PREMIUM_MIN/MAX(0.85/1.15)` · `RUNE_SHOP_REROLL_BASE/STEP(20/15)` ·
    `DEMON_MIN_CARDS_PER_STAGE(4)`. 삭제: `RUNE_SHOP_BASE_PRICE` · `RUNE_SHOP_PRICE_STEP`
  - `godot-game/scripts/factory_drag_button.gd`: `drop_hint` · `drop_hint_host` 추가(X2)
  - `godot-game/scripts/deal_card_library.gd`: `desc` 문장만 손봤다(태그 줄이 없어진 만큼
    횟수·넉백·사거리를 문장으로 흡수 · X1)
  - `godot-game/scripts/test/test_runner.gd`: 4,900 → **5,660줄.**
    `--v4-test edit_minimal` · `--draft-test cancel`·`demon_floor` · `--castle-test rune_shop`
    전면 재작성 · `--cycle-test hud_mini`·`hud_nav` 신설과 `hud_rail`·`hud_ghost` 재작성 ·
    `--guide-test freeze`·`diet` 신설 · 계약 측정기 `_hud_coverage()`·`_onboarding_census()`
  - `godot-game/scripts/test/run_all.sh`: 264 → **320줄**
  - `docs/handoff-x1.md` `handoff-x2.md` `handoff-x3.md` `handoff-x4.md`: **신규**
  - `AGENTS.md`: 이 항목 + 머리말 · §0 · §1 · §3 · §4 · §5 · §6 · §7 · §9 · §11 · §12 · §13 갱신
- 사용자에게 보이는 변화:
  - **레벨업 화면이 그림 중심이 됐다.** 큰 아이콘 한 장 + 이름 + 한 문장 + 지속/RELOAD 칩
    둘. 속성은 카드 색으로 말하고(색약 대비 1글자 마크 병기) 태그·계수 줄은 사라졌다.
    세 번째 선택지는 **「취소 +30 G」**다 — 누르면 두 카드가 사라지고 **마왕은 아무것도
    받지 않는다.**
  - **각인은 이제 성의 각인 세공사에게 산다.** 스킬 카드처럼 **3개가 깔리고** 각각 값이
    다르며(좋은 각인일수록 비싸다) 새로고침으로 다시 깔 수 있다(20 → 35 → 50 G).
    보물상자에서 나올 확률도 올랐다.
  - **ESC 편집 화면에 상시 문장이 없다.** 5칸 + 화살표 + 되돌이 선 그림이 구조를 말하고,
    숫자와 설명은 **마우스를 올리면** 나온다. **모드 버튼이 없어졌다** — 카드 그림을 끌면
    카드가, 칸 손잡이를 끌면 칸이 통째로 따라오고, 놓을 수 있는 자리만 밝게 남는다.
  - **필드에서 판이 사라졌다.** 화면의 96.7%가 필드다*(당시 값 — 현재 96.8 %)*. 위치 안내는 화면 테두리를 도는
    작은 화살표 넷이 하고(목적지가 화면에 들어오면 사라진다), 딜싸이클은 화면 아래
    가운데의 작은 아이콘 다섯 개 스트립이 됐다. 자세한 숫자는 전부 호버로 나온다.
  - **튜토리얼이 도는 동안 세계가 멈춘다.** 마물이 한 마리도 없고, 시간도 체류도 흐르지
    않으며, 안내판이 「세계가 멈춰 있습니다」라고 말해 준다.
  - **온보딩이 3분의 1 짧아졌다.** 페이지마다 규칙은 두 줄, 가장 긴 줄도 31자다.
    사라진 조건·숫자는 그림으로 내려갔고, 「빚」은 「쉬는 시간」으로 먼저 설명한 뒤 이름을 준다.
- 데이터/저장 호환성: **schema 3 유지 · 키 48개 무변경**(`--save-test` 지문 67축
  mismatch=0) *(당시 값 — Y6이 schema 4 · 53키 · 지문 72축으로 올렸다)*.
  `rune_shop_purchases`는 기존대로 저장하고 X1이 새로 만든
  `rune_shop_offers`·`rune_shop_rerolls`·`rune_shop_castle_id`는 **저장하지 않는다**
  (카드 상점과 같은 "성 방문 스코프"). `growth_cap_conversions`는 키를 유지한 채 의미만
  "천장에서 열린 레벨업 수"로 바뀌었다. 기존 세이브는 그대로 열린다.
- 실행한 검증:
  - `godot --headless --path godot-game --editor --quit` → **PASS** (오류 0 · Parse Error 0)
  - `bash godot-game/scripts/test/run_all.sh` → **15/15 PASS** (컴파일 + 기능 14종 · 83초)
    *(당시 값 — Y 라운드에서 17/17 = 컴파일 1 + 기능 16종 · 약 130초가 됐다)*
  - `--guide-test` → **PASS · 17플래그 전부 true**(X4 신설 `freeze`·`diet` 포함).
    회귀 지표 `cleared=10 onb_pages=[261,312,318,306] onb_peak=318 onb_longest=31 onb_rules=2`
  - `--v4-test edit_minimal` → **PASS** (`edit_labels=7 edit_prose=0`)
  - `--cycle-test hud_mini`·`hud_nav`·`hud_rail`·`hud_ghost` → **PASS**
    (`strip_h=74 hud_block_pct=3.32 hud_ink_pct=6.88` — **당시 값**)
  - `--draft-test cancel`·`demon_floor`·`growth_cap` / `--castle-test rune_shop` → **PASS**
  - `godot --headless -s res://scripts/test/balance_probe.gd` → **`pass=1`**
    (⑭의 성장 천장 스위치 표기 `on → off` 한 줄만 바뀌었고 나머지 187줄 동일)
  - 비headless 실기 `--guide-test` → 창 실행 · 오류 0줄 · `=false` 0건
  - 캡처 육안 → `--capture-choice` 5컷 · `--capture-castle` 6컷 · `--capture-rail` 4컷 ·
    `--capture-hud` 6컷 · `--capture-guide` 4컷 · `--capture-onboarding` 4컷.
    **전부 `shasum … | sort -u | wc -l`로 컷 수만큼 고유한지 먼저 확인했다.**
    `--capture-guide`는 `GUIDE_FREEZE_OBSERVED phase_drift=0.000 field_now=0`을 함께 남긴다
- 남은 문제:
  - 온보딩 4페이지의 **화살표 규약이 글로만 있다**(픽토그램 자리를 만들려면 3칩을 두 칩으로).
  - 길잡이가 끝난 뒤 **필드가 20초쯤 비어 있다**(친절하다고 판단했으나 연출 선택지다).
  - **길잡이를 켠 채 방치하면 세계가 무기한 멈춘다**(탈출은 항상 가능 · 자동 종료 없음).
  - **온보딩 도식과 실전 기하가 1:1이 아니다**(2페이지 5칸 168×104 vs 실전 52×52).
  - `balance_probe.gd`에 **취소 파밍 대 카드 획득(⑮) 표가 없다** — 계산이 이 문서와
    `tuning.gd` 주석에만 있다.
  - `DealCardLibrary.combat_tags()`의 **마지막 호출부 1개**가 공장 place 모드에 남아 있다.
  - `BOSS_RAIL_BAND`가 **프로젝트에 남은 유일한 상시 킷 판**이다.
  - 상세는 §12 「피드백 라운드(X1~X4)가 남긴 것」.
- 다음 AI가 시작할 정확한 지점: **재플레이테스트 피드백 대기.** 관측 우선순위 네 가지와
  로그 보조 지표는 §1 체크포인트의 `next_exact_step`에 있다. 피드백이 오면
  `active_request`를 갱신하고 `status`를 `in_progress`로 되돌린다.

---

### 2026-08-09 14:40 KST — **UI 재스킨 시리즈 (U0~U3 네 웨이브)**

- 사용자 요청: "새 필드 디자인이 마음에 들어. **그 테마로** 로비 씬 · 온보딩 UI ·
  레벨업 UI · 딜싸이클 UI(ESC 눌렀을 때 딜싸이클 칸)를 **전부 180도 바꿔 줘 —
  기존 UI를 새로운 센세이셔널한 UI로.**" + "게임 시작했을 때 **어둡게 처리하면서
  집중할 곳만 밝게** 해서, 간단한 조작감이나 필요한 걸 알려 주는 **온보딩 길잡이**를
  만들어 줘." 불변으로 못 박은 것: 트윈 루프 금지(1회성 전환은 허용) · 5칸 무스크롤 ·
  미선택 카드 → 마왕.
- 상태: **ready_for_playtest**
- 결정한 내용: **바꾼 것은 표면뿐이다.** 정보 구조 · HUD 좌표 계약 · 화면 흐름 ·
  조작 · 상태 문자열 · 저장 스키마는 한 글자도 안 바꿨다. 규격 원본은
  `docs/ui-style-v3.md`(U0)이고 웨이브별 상세는 `docs/handoff-u1.md` ~ `handoff-u3.md`에 있다.
- 웨이브별 요약:
  - **U0** v3 UI 킷 신설 — `art/v2/ui-kit-*.png` **10장**(패널·버튼·카드·리본·키캡 26종·
    포인터·글리프·게이지·스포트라이트 마스크 2), 빌더 `art/v2/build_assets_ui.gd`,
    헬퍼 `scripts/ui/ui_kit.gd`(420줄). 규격서 `docs/ui-style-v3.md` — 톤 7종 ·
    폰트 5단(26/17/13/12/11) · 9-slice 여백 3숫자(패널 10 · 카드 16 · 스포트라이트 32) ·
    `corner_radius` 금지 · 트윈 루프 금지 · §12 마감 체크리스트
  - **U1** 로비 · 캐릭터 선택 · 설정 · 온보딩 재스킨 — 로비 배경을 AI 생성 야경에서
    **게임 아틀라스로 그린 정적 필드 디오라마**로, 캐릭터 카루셀 1장 → **킷 카드 3장 동시**
    + NA 스프라이트 실물, Godot 기본 위젯 → 킷 토글 3 · 킷 게이지 슬라이더 2,
    온보딩 4페이지 = PARCHMENT 껍데기 + WOOD 리본 + **SLATE 무대**(의미색이 읽히도록 판 자체를
    어둡게 뚫었다). 온보딩 1페이지는 규칙 3줄 → 2줄로 줄이고 "필드에서 길잡이가 짚어 준다"는
    **약속 문구**로 바꿨다(U3가 그 약속을 지킨다). `--capture-settings` 신설
  - **U2** 모달 · ESC 딜싸이클 편집 일관화 — 레벨업 2택 + 각인 강화 · 각인 드래프트 1·2단계 ·
    **트로피 2택1(GOLD 껍데기)** · ESC 편집 화면(칸 프레임이 모드에 따라 통째로 뒤집힌다) ·
    성 NPC 4종과 상점 · 결과 화면 · 마왕/보스 프리뷰 · 전역 스크롤바까지 킷으로.
    `set_loops()` **프로젝트 전체 0건** 달성. `--capture-choice` 신설
    ⚠️ *이 줄의 「각인 강화」 선택지는 **X1이 삭제**했고, 편집 화면의 「모드」는
    **X2가 삭제**했다 — 당시 기록이다.*
  - **U3** **스포트라이트 길잡이 7스텝 신설** + 필드 HUD 킷 마감 — 새 `state`를 만들지 않고
    `playing` 서브모드(`guide_active`)로 넣었다. 화면을 어둡게 깔고 구멍 하나만 밝히며
    이동 → 대시 → 5칸 레일 → 게이지 → 고스트 레일 → 나침반 → ESC 편집 화면을 차례로 짚는다.
    *(⑥스텝의 「나침반」은 **X3에서 「가장자리 화살표」로 갈렸다.** 스텝 수는 7 그대로다.)*
    새 런의 첫 낮에 **최초 1회**만 열리고 설정의 「온보딩 다시 표시」가 되살린다.
    동시에 필드 HUD의 `_panel_style` **12곳을 킷으로 갈고 함수 자체를 삭제** —
    `StyleBoxFlat.new()` 프로젝트 전체 0건. `--guide-test` · `--capture-guide` 신설
- 변경 파일 (**줄 수는 당시 값이다** — 현재 값은 §5 핵심 코드 지도를 볼 것. X1~X4가
  `game.gd` 13,436 · `ui_kit.gd` 655 · `test_runner.gd` 5,660 · `run_all.sh` 320으로 늘렸다):
  - `godot-game/art/v2/build_assets_ui.gd` · `art/v2/ui-kit-*.png` 10장: **신규**(U0)
  - `godot-game/scripts/ui/ui_kit.gd`: **신규 420줄.** 스타일박스·글자색·키캡·글리프·
    포인터·게이지·스포트라이트의 단일 창구
  - `godot-game/scripts/game.gd`: 10,993 → **12,006줄.** 로비/캐릭터/설정/온보딩 재작성(U1) ·
    모달과 편집 화면 전량 킷 전환(U2) · 필드 HUD 12블록 + `_panel_style()` 삭제 ·
    `GuideLayer`와 길잡이 상태·입력·저장 차단 ⑤ 구간 신설(U3)
  - `godot-game/scripts/test/test_runner.gd`: 4,577 → **4,900줄.**
    `--capture-settings` · `--capture-choice` · `--guide-test` · `--capture-guide` 4루틴 추가
  - `godot-game/scripts/test/run_all.sh`: 250 → **264줄.** `ALL_TESTS` 1줄 · `ALL_CAPTURES` 3줄
  - `docs/ui-style-v3.md` **신규** · `docs/handoff-u1.md` `handoff-u2.md` `handoff-u3.md` 신규
  - `docs/v1-archive/game_lobby_v3.gd.txt` · `game_field_hud_style_u3.gd.txt`: 재작성 전 원본 보존
  - `AGENTS.md`: 이 항목 + §0·§1·§2·§4·§5·§6·§9·§10·§11·§12·§13 갱신
- 사용자에게 보이는 변화:
  - **로비부터 필드 HUD까지 한 게임으로 읽힌다.** v1의 어두운 남색 도형 패널이 전부
    사라지고 나무·양피지·석판 9-slice 프레임으로 바뀌었다. 강조는 테두리 색이 아니라
    **프레임 종류**가 낸다.
  - 캐릭터 선택에서 세 캐릭터를 **한 화면에 동시에** 본다(카루셀 좌우 이동이 없어졌다).
  - 설정의 토글·슬라이더가 게임 부품처럼 생겼다(함몰 = 켜짐).
  - 레벨업·각인 드래프트·트로피·ESC 편집 화면이 같은 카드 문법을 쓴다. 편집 화면은
    카드 모드와 각인 모드에서 **칸 프레임이 통째로 바뀌어** 지금 무슨 모드인지 한눈에 보인다.
    *(모드는 **X2가 삭제**했다 — 지금은 "집은 것이 조작을 정한다".)*
  - **새 게임 첫 낮에 화면이 어두워지고 밝은 구멍이 하나씩 옮겨 다니며** 이동 · 대시 ·
    5칸 레일 · 게이지 · 고스트 레일 · 나침반 · ESC 편집 화면을 짚어 준다.
    *(⑥은 지금 **가장자리 화살표**다 · X3. 그리고 **X4부터 도는 동안 세계가 멈춘다**.)*
    `SPACE`로 넘기고 `ESC` 두 번이면 통째로 건너뛴다. 한 번 보면 다시 안 나오고,
    설정의 「온보딩 다시 표시」가 온보딩과 길잡이를 **함께** 되살린다.
- 데이터/저장 호환성: **schema 3 유지 · 키 48개 무변경**(**당시 값** — 지금은 schema 4 · 53키).
  길잡이 시청 여부는 런 스냅샷이
  아니라 설정 파일의 `settings/guide_seen` 플래그 하나로만 남는다(온보딩 숨김과 같은 층).
  기존 세이브는 그대로 열리고, 이어하기는 길잡이를 열지 않는다.
- 실행한 검증:
  - `godot --headless --path godot-game --editor --quit` → PASS (오류 0 · Parse Error 0)
  - `bash godot-game/scripts/test/run_all.sh` → **15/15 PASS** (컴파일 + 기능 14종 · 84초)
    *(당시 값 — 현재는 17/17 · 컴파일 1 + 기능 16종)*
  - `--guide-test`(신설) → PASS · 15플래그 전부 true *(X4가 `freeze`·`diet`를 더해 지금은 17)*
  - `--cycle-test` `hud_rail`·`hud_ghost` / `--v4-test` `edit_layout`·`single_focus`
    / `--draft-test` `stage_two`·`stack_cap`·`growth_cap` → PASS (좌표·포커스 모델 무회귀)
  - `--save-test` 지문 67축 → mismatch=0 (차단 구간 4 → 5로 늘었을 뿐 기존 3구간 무변경 ·
    **당시 값** — 지금은 72축)
  - `run_all.sh --captures` → **15종 64컷** 생성 · 육안 검수
    *(X1~X3이 71컷으로 늘렸고 Y 라운드가 다시 늘렸다 — 현재 값은 §11)*
  - 비headless 실기 관찰 → `godot --path godot-game -- --guide-test` 창 실행 1회,
    길잡이 7스텝 전체 흐름을 실제 렌더 프레임 위에서 통과 · `SCRIPT ERROR`/`ERROR:` 0줄 ·
    `=false` 0건 · exit 0
  - `ui-style-v3.md` §12 체크리스트 U1·U2·U3 각 범위 자가 점검 → 전 항목 [x]
- 남은 문제:
  - **`--capture-result`가 여전히 패배 컷만 찍는다.** PARCHMENT + GOLD 리본(승리) 조합에
    육안 검수 창구가 없다.
  - **git 미커밋 상태를 유지한다(사용자 결정).** `godot-game/`은 아직 한 번도 커밋된 적이
    없어(`?? godot-game/`) 되돌릴 스냅샷이 없다. U2·U3가 착수 전 커밋을 권고했지만
    §0-7이 커밋을 금지하므로 **사용자가 직접 지시해야 한다.** 대신 `docs/v1-archive/`에
    재작성 전 원본을 남겼다.
  - **UI 픽셀 밀도 2.0 vs 필드 2.5.** UI만 정수 배율(×2)을 지킬 수 있어 생긴 1.25배 차이다.
    의도적 선택이고 캡처상 둘 다 "두툼한 픽셀"로 읽히지만, 맞추려면 지형을 32px 타일로
    옮기는 것이 먼저다(`ui-style-v3.md` §1).
  - 그 밖에 §12 참조 — 길잡이 중 ESC 편집 화면 잠금, 레벨업 모달과의 층 겹침 처리,
    `_hud_ink()` 문턱 0.66의 SLATE 의존.
- 다음 AI가 시작할 정확한 지점: **사용자 플레이테스트 피드백 대기.** 새 UI 체감과 길잡이
  흐름을 먼저 듣고 §1 체크포인트의 `active_request`를 갱신한다. UI를 다시 만지기 전에
  `docs/ui-style-v3.md` §12를, 밸런스를 만지기 전에 `balance_probe.gd`를 먼저 돌린다.


### 2026-08-09 07:40 KST — **v3 스테이지 개편 (V0~V10 열한 웨이브)**

- 사용자 요청: 5스테이지 구조 · 보스 3종 로테이션 · 7일 기한 폐지(체류 압박 대체) ·
  계보 폐지 · 원소 상태이상 시너지 · 스테이지별 그래픽 톤 · 카드명 전면 판타지화.
  불변: 5칸 딜싸이클 · 각인 · 미선택 카드 → 마왕.
- 상태: **ready_for_playtest**
- 결정한 내용: 위 §3의 핵심 정체성 10개 · §7의 규칙 전량 · §10의 v2 → v3 대조표.
  설계 원본은 `docs/GAME_DESIGN_V3.md`(부록 A = 확정 결정)이고 웨이브별 상세는
  `docs/handoff-v1.md` ~ `handoff-v10.md`에 있다.
- 웨이브별 요약:
  - **V0** v3 상수 골격(`tuning.gd` V3-A~N 블록 · 소비자 0으로 선언만) · v1-archive 복사 · 신설 검사 2종 등록
  - **V1** `core/status_engine.gd` 신설 — 상태 5종 + 반응 매트릭스 11종의 순수 규칙(적 1기당 float 11칸)
  - **V2** 콘텐츠 재저작 — 스킬 28 판타지 개명(**id 0개 변경**) · 원소 7계 재배치 · 아이템 57 개명 · 몹 스테이지 티어 · `trophy_library.gd` · `boss_library.gd`
  - **V3** 보스 3종 스프라이트 파이프라인(리그 5벌 · 강화형 색 변종 굽기)
  - **V4** `core/stage_clock.gd` — 7일 하드 기한 폐기, dwell 곡선과 상한 없는 총 일수. 마왕 성장 §6.4 재보정
  - **V5** 스테이지 전이 파이프라인 · 랜드마크 3종 · 그래픽 그레이드 5단 · 잠식/강림 상태 배선
  - **V6** 원소 상태이상 런타임 배선 — 도트 0.25초 버퍼 · `SOURCE_DOT` · 반응 예산 24 · 킬 체인 깊이 3 · 상태 핍
  - **V7** 스테이지 보스 전투 실체화 — 보스방 3/4칸 딜싸이클 · telegraph(링 자리 = 착탄점) · 페이즈 · 격파 전환 · 마왕 직행 · 강림 밸브
  - **V8** 계보/각성 폐기 → 보스 트로피 2택1 · 계약자 dwell 거래 · 결과 화면 5스테이지 타임라인 · 성장 천장 자동 전환 *(→ **X1이 폐기**하고 "취소 기본 포커스 + ×1.5 할증"으로 대체)* · 상점가 스테이지 스케일
  - **V9** 저장 schema 3(49키) · 이어하기 E2E 전면 재작성 · **복원 순서 회귀 1건 수정**(시드를 월드보다 먼저) · 전투 중 저장 정책
  - **V10** 통합 스위프 24건 · 밸런스 최종 패스 · 시각 QA 결함 5건 수정 · 문서 전면 개정(이 항목)
- V10이 한 것:
  - **삭제**: `scripts/class_library.gd` · `scripts/core/deadline_clock.gd`(둘 다 로직 0줄 껍데기) ·
    `GameTuning.TOTAL_DAYS` · `BOSS_HP_DAY_STEP` · `ECLIPSE_DAY` · `ECLIPSE_PERSISTS` ·
    `game.stage_bosses_defeated`(write-only 죽은 상태 → 저장 키 49 → 48)
  - **이관**: `STAGE_BOSS_*` 8개 + `STAGE_PRICE_STEP` → `core/tuning.gd`(값 무변경)
  - **개명**: `ECLIPSE_*` → `BLIGHT_*` · `boss_advancement_skills` → `trophy_reject_skills` ·
    `advancement_branch_id` → `last_trophy_id` · `advancement_tier` → `trophy_count`
  - **수정**: 성 퇴장 시 저장 1회(성 안에서 앱이 죽으면 거래가 사라지던 구멍) ·
    도트 플러시가 수호막을 먹던 결함(`ignore_shield`) · 스테이지 보스에게 v2 `slow`가
    걸리지 않던 불일치 · `world_grid.set_stage_landmarks()` 공개 창구 · `--capture-lobby` 세이브 정리
  - **밸런스**: `balance_probe.gd`에 ⑩~⑭ 신설(**상태이상까지 세는 보스 DPS 모델**).
    보스 전투 길이 실측 → `BossLibrary.DESIGN_HP` 확정
- 변경 파일(V10):
  - `godot-game/scripts/core/tuning.gd`: 상수 이관 9개 · 삭제 4개 · `BLIGHT_*` 개명 · 판정 주석
  - `godot-game/scripts/boss_library.gd`: `DESIGN_HP` 확정 · `hits`/`pierce` 의미 명문화 · 죽은 `anim` 키 2개 삭제
  - `godot-game/scripts/game.gd`: 상수 참조 이관 · 성 퇴장 저장 · 랜드마크 복원 단순화 · 죽은 상태 삭제
  - `godot-game/scripts/player.gd` `enemy.gd` `world_grid.gd` `trophy_library.gd`
    `core/combat_resolver.gd` `core/status_engine.gd`: 개명·판정 주석·결함 수정
  - `godot-game/scripts/test/balance_probe.gd`: 368 → 1,207줄
  - `godot-game/scripts/test/test_runner.gd`: 삭제 필드 정리 · 캡처 세이브 정리
  - `docs/GAME_DESIGN_V3.md` §9: 설계-코드 불일치 1건을 문서 쪽에서 정정
  - `AGENTS.md` v3 전면 개정 · `README.md` v3 갱신 · `docs/handoff-v10.md` 신규
- 사용자에게 보이는 변화:
  - **보스 다섯이 전부 목표 전투 길이 안으로 들어왔다.** 조정 전 2·3스테이지 보스가
    103초 · 110초로 늘어졌던 것이 73초 · 76초가 됐다(다섯 관문 67/73/76/62/60초).
    *(당시 값 — Y8이 45/53/56/38/36초로 재확정했고 목표 창도 30~60초로 내려왔다)*
  - 수호막이 독 한 틱에 증발하지 않는다. 특히 B·B+ 보스전(2·4스테이지)에서 체감된다.
  - 성에서 카드를 사고 나온 직후에 앱이 죽어도 그 거래가 남는다.
- 데이터/저장 호환성: **schema 3 유지**(v1·v2는 종전대로 폐기). 키가 49 → 48로 줄었으나
  줄어든 쪽은 아무도 읽지 않던 값이라 기존 schema 3 세이브는 그대로 열린다.
  카드·아이템·트로피 `id`는 v3 내내 한 개도 바뀌지 않았다.
- 실행한 검증 (**당시 값이다** — 검사·캡처 종수의 현재 값은 §11을 볼 것):
  - `godot --headless --path godot-game --editor --quit` → PASS (오류 0)
  - `bash godot-game/scripts/test/run_all.sh` → **컴파일 + 기능 13종 전부 PASS** (78초)
    *(이후 U3가 `--guide-test`를 더해 14종 · 84초가 됐다)*
  - `balance_probe.gd` → `pass=1` (6개 판정 플래그 전부 1)
  - `rune_test.gd` · `data_test.gd` · `rift_probe.gd` → PASS (`rift_probe`는 v2 규칙이 박혀 FAIL이던 것을 v3로 재작성)
  - `run_all.sh --captures` → 12종 40컷 생성 · 육안 검수
    *(이후 U1·U2·U3가 `--capture-settings`·`--capture-choice`·`--capture-guide`를 더해 15종 64컷,
    X1~X3이 71컷으로 늘렸고 Y 라운드가 다시 늘렸다 — 현재 값은 §11)*
  - 비headless 라이브 관찰 **237초** (13루틴 × 3회 · 스테이지 전환 · 보스전 · 상태이상 순회) → 오류 0줄
- 남은 문제: §12 참조. 요지는 셋이다 —
  ①플레이테스트 미실시(보스 HP는 uptime 0.62 가정 위에 있다)
  ②XP·골드가 스테이지 축으로 스케일하지 않는다
  ③`card_status_power` 축과 한 강화 계수는 플레이테스트 뒤로 미뤘다
- 다음 AI가 시작할 정확한 지점: 사용자 플레이테스트 피드백을 받아 §1 체크포인트의
  `active_request`를 갱신한다. 밸런스를 만지기 전에 반드시 `balance_probe.gd`를 먼저 돌린다.


### 2026-08-07 19:30 KST — **v2 전면 리부트 (W0~W12 열세 웨이브)**

- 사용자 요청: "딜싸이클은 유지하되 10칸→5칸 무스크롤. 스킬 강화 시 랜덤 옵션(확률 회귀·2칸 후퇴·재실행 등) 로그라이크. 기한 내 마왕 도전 강제(시한부 RPG). 그래픽은 무료 에셋 기반 신규 테마(몹/배경/VFX 포함). 무한 맵은 기존 WFC 재사용. 버린 카드→마왕 유지. 기존 기획 무시 허용." + 추가 확정 2건: "한 칸에 각인 중복 강화 가능(단 몰빵이 유일 정답이 되지 않게 감쇠)", "칸 자체의 위치 교환 가능".
- 상태: **ready_for_playtest**
- 결정한 내용 (웨이브별 요약):
  - **W0 안전망·골격 분리** — 튜닝 상수를 `core/tuning.gd`로 전량 이관, 테스트 하네스를 `test/test_runner.gd`로 분리, `run_all.sh` 신설(종료 코드 판정).
  - **W1 순수 규칙 엔진** — `core/rune_engine.gd`. 각인 24종 + `simulate_cycle()`. 몬테카를로로 종료성 실측(최악 덱 평균 8.98스텝, STEP_CAP 도달 0.70%). 설계 이탈 7건 보고·승인. *(당시 값 — Y1이 각인 15종으로 갈고 `STEP_CAP`을 2n+2 = 12 방어 단언으로 바꿨다)*
  - **W2 바늘 사이클 런타임** — `deal_cycle_controller.gd` 전면 재작성. 궤적은 100% 엔진에서만 나온다(단일 진실 원천). 시드 결정성 확립. `factory_deck.gd`를 5칸 + 칸별 각인 스택 + 장비 4부위로 교체. `heat_gate` 문턱 3→2(부록 C-7).
  - **W3 전투 판정 추출** — `core/combat_resolver.gd`. 동작 무변경으로 공간 해시·스폰·피해 판정을 game.gd에서 들어냈다.
  - **W4 7일 기한과 마왕 성장** — `core/deadline_clock.gd` · `core/demon_lord.gd`. 낮 72초/밤 45초, 총 7일. 이정표 시그널, 밤의 전조, 강림. 저장 schema 2 도입(v1 스냅샷 폐기).
  - **W5 필드 HUD 재작성** — 5칸 상시 레일 + 바늘 + 과열 온도계 8단 + 빚 게이지 + 7일 기한 패널 + 마왕 고스트 레일. v1 칩 3개·되감기 릴 7칩 전량 삭제. 트윈 0개. *(이 레이아웃은 **X3가 미니 스트립 380×74로 갈았고**, **Y2가 과열 8핍을 없애며 358×74로 좁혔다** — 지금 스트립에 온도계는 없다.)*
  - **W6 편집 화면과 각인 드래프트** — ESC 편집(카드 이동 / 칸 교환 두 제스처, 흐름 아크, 96표본 미리보기), 각인 3택1 → 칸 선택 2단계. 흐름 각인 포화 억제.
  - **W6b 셸·온보딩** — 온보딩 4페이지를 UI 프리미티브 정적 도식으로 재작성.
  - **W7 콘텐츠 데이터 재저작** — 스킬 20종 드래프트 풀(v1 8종은 `legacy: true`로 보존), 몬스터 10종, 원소 6·형태 5 태그 전면 부여, RELOAD 재기준(v1의 약 60%, 표준 덱 3.08초).
  - **W8 월드 재배치** — 고정 시련 캠프 4곳을 폐기하고 동적 균열 API 신설(런당 3회, 900~1,400px 링, 시드 결정적).
  - **W9 성·NPC·각성** — 성 NPC를 v2 4종(카드 상점·각인 세공사·계약자·밀정)으로 교체, 균열 완결(스케줄·정예·보상), 전직을 3·6일차 각성으로 대체. 저장에 균열 5키 추가.
  - **W10 마왕전·결과 화면** — 마왕이 플레이어와 같은 런타임을 쓴다(5칸·각인·과열·RELOAD ×0.6). 상단 마왕 레일 밴드. **HP 배율이 처음으로 실제 체력에 적용됨.** 월식(5일차~) 구현. 결과 화면 v2 지표. 저장에 4키 추가. *(당시 값 — Y 라운드가 과열을 없앴고 `BOSS_RELOAD_MUL`은 지금 0.42다)*
  - **W11 시각 테마 교체** — 절차적 도형 렌더를 Ninja Adventure 픽셀 스프라이트로 전면 교체(런타임 PNG 33장 ≈140 KB). 게임 규칙 무변경, 테스트 단언 수정 0건. v1 에셋은 참조만 끊고 보존.
  - **W12 통합·밸런스·저장 확정·문서 개정** (이번 항목):
    - 저장 schema 2 전수 점검. 가산 키 10종(균열 5 + 월식/기록 4 + `run_cycle_seed`)이 전부 들어 있음을 확인하고 **버전은 2로 확정**했다(키만 늘었고 없는 키는 기본값을 타므로 3으로 올릴 이유가 없다).
    - **`--save-test` 신설** — 이어하기 E2E. 스냅샷 키 37종 존재 검사 + 상태 지문 47축 정확 대조 + 균열 좌표·예산 일치 + v1 스냅샷 폐기 + 저장 삭제까지 한 번에 본다.
    - v1 잔재 정리: 시련 캠프 시스템 완전 삭제(`world_grid.gd` 8곳, `TRIAL_CAMPS`/`_draw_trial_camp`/`TRIAL_CAMPS_ENABLED`), `get_castle_services()` 삭제(호출부 0), 전리품 구슬 렌더 루프 삭제(`player.gd`), 저주 상자의 legacy 카드 유출 차단.
    - 밸런스 1차 패스 — 전부 `scripts/test/balance_probe.gd`의 계산 근거로 결정했다(§표는 아래 "실행한 검증").
  - **하지 않기로 한 것 (전부 사유 기록)**:
    - `factory_deck.gd`/`deal_cycle_controller.gd`의 `core/cycle_*.gd` 개명 — `class_name`이 전 코드베이스·테스트·저장 스키마에 박혀 있어 순수 노이즈 diff다. 위험 대비 이득 없음.
    - legacy 스킬 8종 삭제 — 모든 지급 경로가 이미 `draft_pool()`을 쓰므로 **도달 불가 상태로 충분**하고, 삭제하면 아이콘 인덱스·`cycle_skill_effect`의 id 분기·세이브 호환·테스트 4곳을 동시에 봐야 한다.
    - v1 NPC 서비스 6종 삭제 — `--castle-test`가 `skill_remove`·`skill_swap` 둘을 직접 호출해 검증한다. 성이 배치하지 않으므로 플레이어에게는 이미 없는 것과 같다.
    - 독립 프로브 3종의 `run_all.sh` 편입 — 출력 규약이 달라 별도 블록이 필요하다. §11에 실행 명령과 "언제 돌리는가"를 적어 두는 것으로 대체.
    - **마왕성 거리 8,628px(목표 5,600)와 성 밀도 9%** — 4개 웨이브 연속 미결이었으나 W12가 수치로 확인하고 **유지 결정**했다. 마왕성은 편도 약 36초(기한 819초 대비 무시 가능), 성 조우 기대치는 런당 약 8회로 계약·각인 상점 접근이 막히지 않는다. §12에 계산을 남겼다.
- 변경 파일 (W12분):
  - `godot-game/scripts/core/tuning.gd`: 마왕 기저 HP 4상수 신설(`BOSS_BASE_HP` 외), `NIGHT_*` 6상수 조정, `TRIAL_ELITE_HEALTH_MUL` 신설. **모든 변경 상수 옆에 이전 값을 주석으로 남겼다.**
  - `godot-game/scripts/enemy.gd`: 마왕 체력 식이 GameTuning을 읽도록 이관, 정예 배율 ×5 → `GameTuning.TRIAL_ELITE_HEALTH_MUL`(3.0)
  - `godot-game/scripts/monster_library.gd`: `CYCLE_HEALTH_GAIN` 0.28 → 0.24
  - `godot-game/scripts/game.gd`: 저주 상자 `SKILLS` → `draft_pool()`, `RIFT_ELITE_HEALTH_SCALE` 사후 보정 삭제
  - `godot-game/scripts/world_grid.gd`: 시련 캠프 시스템 삭제(690 → 641줄)
  - `godot-game/scripts/player.gd`: 전리품 구슬 렌더 루프 삭제
  - `godot-game/scripts/test/test_runner.gd`: `--save-test` 신설(약 220줄), `camps_off` 단언 갱신
  - `godot-game/scripts/test/run_all.sh`: `--save-test` 등록 (기능 검사 11종 → 12종)
  - `godot-game/scripts/test/balance_probe.gd`: **신설**. 밸런스 근거 계산기
  - 시각 QA 반영 3건: `game.gd` 흐름 델타 라벨 외곽선 · 온보딩 3페이지 `delta` → `Δ` ·
    `core/rune_engine.gd` 「무상」 각인 설명의 소문자 `reload` → `RELOAD`
  - `AGENTS.md` / `README.md`: v2 전면 개정
  - `docs/GAME_DESIGN_V2.md`: 부록 C에 확정 9번 추가 — "**최종 수치는 GameTuning**"과
    설계 §9 대비 실제 구현이 다른 항목 표(마왕 HP · `CYCLE_HEALTH_GAIN` · 정예 배율 ·
    NIGHT_* · 카드 reload · **칸 개방 미구현** · `xp_target` 식 · 두 화폐 3지선다)
- 사용자에게 보이는 변화:
  - 마왕전이 **약 30초에서 약 90초로** 길어졌다. 조기 도전(3일차)도 이제 70초대로 "전투"가 된다.
  - 밤 습격의 동시 마물 수가 7일차 65 → 58로 줄고 물량이 밤 전체에 걸쳐 완만하게 차오른다.
  - 몹 체력이 후반부에 약 11% 낮아졌다(7일차 최상위 768 → 682).
  - 균열 정예가 절반 가까이 약해졌다(체력 ×5 상당 → ×3).
  - 이어하기가 균열 위치·정예 잔여·계약 횟수·각인 가격·밀정 정보·월식까지 전부 보존한다(자동 검증됨).
  - 저주받은 보물이 플레이어가 본 적 없는 v1 카드를 마왕에게 주지 않는다.
- 데이터/저장 호환성: **schema 2 유지.** W4 이후의 저장은 그대로 읽힌다. v1(schema 없음) 저장은 종전대로 읽지 않고 버린다(크래시 없이 새 런). 밸런스 상수는 스냅샷에 들어가지 않으므로 진행 중인 런에도 즉시 적용된다.
- 실행한 검증:
  - `bash godot-game/scripts/test/run_all.sh` → **PASS 13/13** (컴파일 1 + 기능 12) (compile · world · v4 · castle · rift · stress · smoke · combat · deadline · cycle · draft · boss · **save**), 56초
  - 독립 프로브 3종 전부 PASS — `rune_test`(32,000 사이클 몬테카를로) · `data_test`(카드·몬스터 스키마) · `rift_probe`(균열 배치 4항목)
  - `godot --headless --path godot-game -s res://scripts/test/balance_probe.gd` → 아래 근거 수치

    | 관측 | 조정 전 | 조정 후 |
    |---|---:|---:|
    | 7일차 플레이어 단일표적 raw DPS (사이클 91 + 평타 48) | 138 | 138 |
    | 7일 자발도전 마왕 실체력 | 2,633 | **6,827** |
    | 7일 자발도전 전투 길이 (실효 DPS, UPTIME 0.55) | 35초 | **90초** |
    | 3일 조기도전 전투 길이 | 28초 | **73초** |
    | 5일 도전 전투 길이 | 33초 | **86초** |
    | 7일 강림 전투 길이 | 40초 | **103초** |
    | 밤 노출량(∫마물수 dt) 1일차 / 7일차 | 1,274 / 2,481 | **1,185 / 2,123** |
    | 7일차 최상위 몹 체력 (처치 시간) | 768 (5.6초) | **681 (4.9초)** |
    | 균열 정예 체력 배율 | ×5 → 사후 ×0.6 (= ×3) | **×3** (상수 하나로 일원화) |
    | 표준 덱 3종 과부하율 | 0.000 | 0.000 → 드래프트 억제 상수 **조정 불필요** |
    | 7일 골드 수지 (총수입 ≈1,405 G, 전량 소비 시 ≈1,100 G) | — | 여유 305 G(22%) → **조정 불필요** |

  - `bash godot-game/scripts/test/run_all.sh --captures` 12종(PNG 36장) → `error=0` 전부.
    **36장 전수 육안 검수**에서 판독 불가 1건(필드 흐름 델타 라벨)을 잡아 외곽선으로 고치고 재캡처해
    확인했다. 오탐 2건·의도된 동작 2건·플레이테스트 관찰 3건은 §12에 표로 남겼다.
    빈 캡처 0건 · 1280×720 이탈 0건 · 리터럴 마크다운 0건 · 5칸 레일 가로 스크롤 0건
  - **비headless(창 띄움) 자동 관찰 총 277초** — 자동 플레이 루틴 6종(stress/combat/cycle/smoke/boss/save) 45초 + `--preview-*` 13화면 순회 104초 + 장시간 소크 4종(world·night·boss·build 각 32초) 128초.
    **`SCRIPT ERROR` / `ERROR:` / `Invalid call` 0줄.** 실기 렌더 경로에서만 터지는 누락 텍스처·머티리얼·폰트 문제 없음
- 문서 개정 중 발견한 **설계-코드 불일치 3건** (전부 코드를 기준으로 문서를 고쳤다. 규칙은 건드리지 않았다):
  1. 설계 §9.2의 "3칸 시작 → L4·L9 개방"이 **구현되지 않았다.** 런 시작부터 5칸이 전부 열려 있고 `--v4-test`의 `initial5`가 그 상태를 단언한다. 성장 이정표 하나가 통째로 빠져 있으므로 §12에 최우선 후보로 기록했다.
  2. 성장의 두 화폐는 "홀수=스킬 / 짝수=각인" 교대가 아니라 **매 레벨 3지선다**(스킬 A · 스킬 B · 각인 드래프트)로 구현됐다. 각인을 고르면 두 카드가 모두 마왕에게 간다.
  3. 경험치 문턱은 설계의 `8 + 6n + n^1.6`이 아니라 `7 + level × 5`다.
- 남은 문제 (§12 전체):
  - **플레이테스트 미실시.** 마왕 HP ×2.6은 UPTIME 0.55 가정에 걸려 있다. 실기에서 마왕전이 지루하면 이 가정이 틀린 것이고, `BOSS_BASE_HP` 4상수를 같은 비율로 되돌리면 된다(이전 값이 주석에 있다).
  - 마왕성 거리 8,628px(목표 5,600), 성 밀도 9% — 4개 웨이브 연속 미결.
  - `game.gd` 9,191줄, UI 계층 미분리.
  - `player.rollback_capacity`를 올려 주는 콘텐츠가 없어 `rollback_charges`가 항상 0.
  - 직장 풍자 카드명 약 30종의 톤 통일 여부 미결(사용자 결정 대기).
- 다음 AI가 시작할 정확한 지점: **사용자 실기 플레이테스트 피드백 수령.** 관측 우선순위는 ①마왕전 길이 ②5일차 이후 밤 생존 ③골드 수지. 피드백이 오면 §1 체크포인트의 `active_request`를 갱신하고 `status`를 `in_progress`로 되돌린 뒤, 밸런스 항목이면 반드시 `balance_probe.gd`부터 돌린다.

### 2026-08-07 12:10 KST — 프로덕션 다듬기 패키지 (온보딩 정적 재설계 + 전 화면 감사 32건 반영)

- 사용자 요청: "전체적으로 게임을 프로덕션 형태로 다듬어줘. 온보딩 모달 애니메이션이 엉망 — 빼고 간단한 텍스트와 도식화된 디자인으로. 다른 모든 요소도 체크하고 부족한 부분 수정. 기존 테마 파괴 허용. 불변: 딜싸이클 방식, 미선택 카드→마왕."
- 상태: ready_for_playtest
- 결정한 내용:
  - 온보딩: `_add_onboarding_motion()`(그림 위 반투명 마커 무한 트윈)과 등장 애니메이션, AI 그림 4장 preload를 전부 제거. UI 프리미티브(키캡·미니 레일·분기 화살표·시간 띠) 정적 도식 4페이지로 재설계. 페이지 수 하드코딩을 `ONBOARDING_PAGE_COUNT`로 상수화.
  - 읽기 전용 전 화면 감사(P0 3/P1 17/P2 12) 후 P1-9 전면 개명·P1-17 실기 검증 항목을 제외하고 전부 반영.
  - P0-1 강화술사 소프트락: 골드 선차감 후 탈출 불가 구조 → `factory_deck.gd::can_apply_upgrade()` 게이트 + upgrade 취소·환불 + place "보관함에 넣기" + ESC 모드별 3분기.
  - P0-2 상점 헤더의 "경제 밸런스 임시값" 개발 문구 제거.
  - P0-3 망각의 사제·운명의 직조사가 구 `player.applied_skills`를 봐서 100% 무동작 → FactoryDeck(보관함→레일) 기준 재작성, 제거 카드는 `rejected_skills`로(마왕 전달 규칙 유지), swap은 같은 RANK 지급.
  - 죽은 코드 434줄 삭제: `fate_transfer`(호출 시 크래시)·`build_menu`·`_run_v2/v3/systems_test`(디스패치 0)·사장 함수 3종·비표시 skill/equipment HUD 패널.
  - 필드 HUD: 잔디 위 맨글자 4종(trophy/compass/help/xp)을 패널화·재배치(`fate_hud_panel` 좌표 재활용, help_text는 제거), 낮밤/타이머 겹침 해소, 딜싸이클 칩 등간격(86/216/366), 배너 이전 것 즉시 정리+y148(보스전엔 192).
  - `boss_preview`: `;` 한 줄 서식 정상화, 표준 레일 렌더러로 마왕 20칸 렌더, "돌아가서 준비한다·ESC" 취소 신설(복귀 무적 포함), 마왕 대사 판타지 톤.
  - 구 디자인 8화면(캐릭터 선택/설정/camp/합성소/상점/강화술사/전직/배너)을 디자인 토큰+왼쪽 강조 바로 통일, 원시 폰트 52→19건.
  - 접근성: camp/evolution/boss_preview/won·lost에 키보드 분기, 주요 화면 기본 버튼 `grab_focus()`(단일 포커스 3화면은 불변), 설정 슬라이더 % 라벨+min -60dB, 전체화면 복원, 로비 "게임 종료".
  - 아이콘: `skill_icon.gd`에 셀 배경 런타임 투명화+크롭+셀별 캐시 이식(52셀 사전 시뮬레이션으로 실루엣 소실 0 확인).
  - 카드명: IT·행정결재 용어 24종만 판타지로 개명(`고통 컴파일러`→`고통 연성진` 등, id 전부 불변). 직장 풍자 톤 약 30종은 사용자 결정 대기.
  - 한국어: `딜사이클`→`딜싸이클` 통일, 받침 기반 조사 헬퍼(`_particle_wa/eul/eun`)로 "장인와"류 오류 해소, 무료 서비스 "0 G"→"무료", `STAGE CLEAR` 등 영문 잔재 한글화.
- 변경 파일:
  - `godot-game/scripts/game.gd`: 위 전부 (6,104 → 5,834 → 6,118줄)
  - `godot-game/scripts/factory_deck.gd`: `can_apply_upgrade()` 신설
  - `godot-game/scripts/skill_icon.gd`: 배경 투명화+크롭+캐시
  - `godot-game/scripts/deal_card_library.gd` / `item_library.gd`: 카드명 24종 + desc 2곳, `딜싸이클` 표기
  - `godot-game/scripts/castle_interior.gd` / `class_library.gd`: `딜싸이클` 표기
- 사용자에게 보이는 변화: 온보딩이 움직임 없는 도식+짧은 텍스트로 바뀜. 강화술사에서 갇히지 않고 살 수 없는 강화는 애초에 비활성. 사제·직조사가 실제로 작동. HUD 글자가 전부 패널 위라 읽힘. 마왕 공장 미리보기가 내 공장과 같은 형태로 비교되고 되돌아갈 수 있음. 카드 아이콘의 어두운 사각 배경 소멸. `Ctrl+V`류 이름 소멸. 로비에서 게임 종료 가능.
- 데이터/저장 호환성: 저장 스키마 변경 없음. 카드 id 불변이라 기존 런 저장 그대로 사용 가능.
- 실행한 검증:
  - 최종 결합 상태에서 compile + world/v4/castle/stress/smoke 전 항목 PASS (신규 `mage_gate`/`upgrade_refund`/`npc_remove`/`npc_swap` 포함, `single_focus` 회귀 없음)
  - 캡처 육안: 온보딩 4페이지, lobby/character/world/factory/effects, 신설 boss/result — 잘림·겹침·대비 문제 없음
- 남은 문제: 직장 풍자 카드명 톤 결정 대기(§12), 설정 CheckButton 기본 테마(§12), 결과 모달 5칸+ 스크롤(스크롤바는 표시됨), 성 안뜰 오버레이·되감기 빈 링 실기 확인 대기, 온보딩 구 PNG 4장 고아 에셋 정리 여부.
- 다음 AI가 시작할 정확한 지점: 사용자 재플레이테스트 피드백으로 섹션 1 체크포인트 갱신. 카드명 전면 통일 결정이 오면 `deal_card_library.gd`/`item_library.gd`의 `name` 키만 교체(id 금지).

### 2026-08-04 21:55 KST — 3차 플레이테스트 피드백 패키지 B·C (⑱맵 깨짐 수정 ⑫⑬⑯⑰⑳ UI 세련화)

- 사용자 요청: ⑱"맵이 많이 깨져, 잘 안 깨지게" ⑫다리 아이콘 박스 제거 ⑬RELOAD 레일 끝 패널 제거 ⑯HUD RELOAD 대기를 게이지 타이머+되감기 애니메이션으로 ⑰전체 UI 세련화 ⑳신규/기존 카드 동일 블록 통일.
- 상태: ready_for_playtest
- 결정한 내용 (패키지 B — 맵):
  - "깨짐"의 정체 3건을 37만 타일 프로브와 아틀라스 픽셀 분석으로 규명: ①아틀라스에 없는 물 타일 조합을 WFC 규칙이 허용해 호수가 파편화(소켓 합법·그림 불일치 인접 쌍 75종) ②셀마다 구워진 1px 어두운 테두리가 40px 격자 줄무늬를 만듦 ③잔디 소켓의 길/유적 타일이 외딴 조각으로 흩뿌려짐. WFC 모순 폴백은 1,936청크에서 0회 — 원인이 아니었음.
  - 물을 WFC에서 분리해 2-정렬 2×2 블록 합집합의 결정적 호수 레이어로 재구성(존재하는 물 타일 9종만 필요 → 모순 구조적 불가, 호수가 청크 경계 통과). 셀당 2px 인셋 렌더링으로 격자 제거. 길/유적/안뜰/캠프 타일을 확률 풀에서 제외. 시작 물길 다리를 3×3에서 1열 3타일로(널빤지 사이 물줄기 제거). 깨진 인접 쌍 2.004%→0.132%.
- 결정한 내용 (패키지 C — UI):
  - 다리 박스는 아틀라스에 구워진 배경이 원인 — generated_ui_icon.gd가 테두리 색 플러드필로 런타임 투명화+크롭(전 HUD 아이콘 공통 수혜). RELOAD 마감 패널은 공장·결과 모달 양쪽에서 제거(헤더 상시 표기 유지, 결과 모달 4칸까지 무스크롤).
  - HUD RELOAD 되감기: 릴 스트립이 플레이헤드를 지나며 칸 번호가 역순으로 감기고(감속, 칸01에 정확히 착지), 원형 스윕 게이지+남은 초+역방향 바. 이동 방향은 우측 이동+번호 카운트다운(무이음새 조건) — 반대가 좋으면 CYCLE_REWIND_TRAVEL 상수 하나로 뒤집기 가능.
  - 디자인 토큰(UI_BORDER_*/UI_*_BG/타이포 5단계) 도입, 모달 테두리를 강조색→중립+강조 바로 정리. 필드 HUD에 없던 체력 게이지 신설(선언만 되고 안 그려지던 사장 코드 복구), 마물/처치/골드를 패널로 통합.
  - 카드 블록 통일: 공장 카드 페인터를 _paint_card_block으로 추출해 레벨업/아이템/전직 선택 카드가 공장 카드와 픽셀 동일 블록 사용 + "한 바퀴 n초 → +n초" 비교 라인 추가.
- 변경 파일:
  - `godot-game/scripts/wfc_chunk_generator.gd`: 물 레이어 분리, 소켓 물 인식, 길/유적 확률 풀 제외, 드라이존
  - `godot-game/scripts/world_grid.gd`: 2px 인셋 아틀라스 테이블, 회전 타일 정수 Transform2D, 시작 물길/다리 재구성
  - `godot-game/scripts/generated_ui_icon.gd`: 런타임 배경 투명화+크롭+캐시
  - `godot-game/scripts/game.gd`: RELOAD 도크 제거, 되감기 릴(CycleSweepGauge 등), 디자인 토큰 폴리시, _paint_card_block 통일, HUD 체력 게이지
- 사용자에게 보이는 변화: 호수가 온전한 모양으로 나오고 격자 줄·외딴 길 조각이 사라짐. 다리가 박스 없이 레일에 얹힘. RELOAD 때 딜싸이클이 되감기는 릴 연출. 선택창에서 새 카드와 보유 카드의 지속/RELOAD가 같은 형태로 비교됨. HUD에 체력 게이지.
- 데이터/저장 호환성: 저장 스키마 변경 없음. 지형 생성 규칙이 바뀌어 같은 시드라도 지형 모습은 이전 런과 다르게 보일 수 있음(저장된 진행·랜드마크 위치는 유지).
- 실행한 검증:
  - 최종 결합 상태에서 compile + world/v4/castle/stress/smoke 6종 전체 재실행 → 전부 PASS (`early_day_peace`·`modal_invuln`·`boss_toast_hold` 포함 전 항목 true)
  - 공장/월드/HUD 되감기 2컷/선택 모달/결과 모달 캡처 육안 확인, 프로브 원복 증명(해시 대조)
- 남은 문제: 성 안뜰·시련 캠프 오버레이 경계 계단(§12), 결과 모달 5칸+ 스크롤, 되감기 초반 0.2초 링이 빈 순간, 스킬/아이템 카드 아이콘 자체의 어두운 타일 배경(다리와 같은 기법 적용 가능하나 미요청).
- 다음 AI가 시작할 정확한 지점: 사용자 재플레이테스트 피드백으로 섹션 1 체크포인트 갱신. 되감기 방향이 어색하다는 피드백이 오면 `game.gd`의 `CYCLE_REWIND_TRAVEL`을 -1.0으로.

### 2026-08-04 20:5x KST — 3차 플레이테스트 피드백 패키지 A (⑭낮 선공몹 게이팅 ⑮모달 복귀 무적 ⑲마왕 토스트 3초)

- 사용자 요청: ⑭"초반부터 선공 몹 안 나오게 해줘. 처음에는 순한 몹만 있으면 돼. 최소 5라~10라 사이에 나오게 해줘. 내 말은 낮에 선공몹이라는 거야." ⑮"스킬을 확정했을 때 0.5초 정도 무적 시간을 줘. 바로 몹한테 맞아서 난이도가 너무 높아." ⑲"마왕 팝업이 너무 짧아. 3초 정도 유지되게 해줘."
- 상태: ready_for_playtest (패키지 B·C는 별도)
- 결정한 내용:
  - ⑭ 낮 선공몹은 삭제·약화가 아니라 **게이팅**으로 처리. 원거리 게이팅과 같은 패턴으로 `monster_library.gd` 안에 단일 규칙(`AGGRO_DAY_UNLOCK_CYCLE=5` + `aggro_gate_ok(cycle,is_night)` + `aggro_day_weight_scale(cycle)`)을 두고 `spawn_allowed()`/`spawn_weight()`를 통해 `roll()`·`spawn_table()`이 같은 답을 쓰게 했다. 밤은 원래 전원 어그로인 별개 시스템이라 손대지 않았다. 강제 스폰(시련 캠프 정예·미믹·마왕 하수인·테스트)은 `allow_aggro_override` 인자로 명시 우회하고, 게이트에 막힌 `forced_behavior`는 빈 후보로 죽는 대신 행동 강제를 풀어 순한 몹으로 대체한다.
  - ⑮ 무적은 새 메커니즘을 만들지 않고 대시 무적과 같은 경로(`player.invulnerability`)를 재사용. 부여 지점을 `_grant_modal_return_invulnerability()` 한 곳으로 모으고 모달 복귀 경로 6곳에서 호출. 성 퇴장은 페이드 커튼이 닫힌 순간에 실행되므로 `SCENE_TRANSITION_TAIL`을 더해 보이는 0.5초를 확보.
  - ⑲ 원인은 시간 설정이 아니라 Tween 구성 버그였다. `tween_interval(3.1)` 다음 페이드 아웃에 `parallel()`이 붙어 대기와 페이드가 동시에 돌았고, 실제로는 등장 0.35초 뒤 투명해진 채 3.1초를 흘려보내고 있었다. 순서를 분리하고 `BOSS_TOAST_*` 상수화. 3초로 늘리면 연속 사건이 앞 토스트를 잘라먹으므로 `boss_toast_queue`(최대 3)를 추가해 덮어쓰기 대신 순차 표시로 바꿨다.
- 변경 파일:
  - `godot-game/scripts/monster_library.gd`: `AGGRO_*` 상수 4개, `aggro_gate_ok()`, `aggro_day_weight_scale()`, `spawn_allowed()` 신설. `spawn_weight()`에 낮 선공몹 램프업, `spawn_table()`/`roll()`이 `spawn_allowed()` 사용, `roll()`에 `allow_aggro_override` 인자 + forced_behavior 폴백 재굴림
  - `godot-game/scripts/player.gd`: `grant_invulnerability()` 신설(대시 무적과 동일 경로), 표시 전용 `grace_invulnerability` 타이머와 `_draw()`의 은은한 시안 깜빡임 링
  - `godot-game/scripts/game.gd`: 상단 `MODAL_RETURN_INVULN`·`BOSS_TOAST_*`·`SCENE_TRANSITION_*` 상수, `_grant_modal_return_invulnerability()` 신설 후 `_finish_factory_return`/`_close_fate_transfer`/`_choose_offered_item`/`_resolve_item_offer`/`_close_base_camp`/`_close_build_menu`에서 호출 + `_exit_castle_now`에서 커튼 보정 부여, `_spawn_enemy_instance`에 `allow_aggro_override` 인자(시련 캠프·미믹·마왕 하수인 3곳 우회), 토스트를 `_show_boss_growth_toast`(큐 관리) / `_build_boss_growth_toast`(렌더) / `_finish_boss_growth_toast`(큐 진행)로 분리, `--v4-test`에 `early_day_peace`·`modal_invuln`·`boss_toast_hold` 추가
- 사용자에게 보이는 변화: 낮 주기 1~4에 추적하는 몹이 전혀 없고(선공 비중 12.7%→0%) 주기 5부터 조금씩 섞이다 주기 10에 원래 비중이 된다. 밤 습격은 그대로. 스킬 확정·아이템 선택·공장 편집·성 퇴장 직후 0.5초 동안 맞지 않고 캐릭터에 시안 링이 깜빡인다. 마왕 카드 토스트가 3초 동안 온전히 보이고 연달아 발생하면 순서대로 뜬다.
- 데이터/저장 호환성: 저장 스키마 변경 없음. 이어하기로 주기 5 이상에서 시작하면 그 주기의 게이트가 그대로 적용된다.
- 실행한 검증:
  - `godot --headless --path godot-game --editor --quit` → PASS (스크립트 오류 0)
  - `godot --headless --path godot-game -- --v4-test` → PASS (전 항목 true, `early_day_peace=true modal_invuln=true boss_toast_hold=true`)
  - `godot --headless --path godot-game -- --smoke-test` → PASS (`state=won`)
  - `godot --headless --path godot-game -- --stress-test` → PASS (`enemies=104 fps=145 bounded=true structure=true`)
  - 음성 대조 실험: 게이트를 주기 1로 낮추고 + 무적 부여를 지우고 + 페이드 아웃을 `parallel()`로 되돌린 상태에서 세 신규 플래그가 모두 `false` → 검사 유효성 확인 후 원복
- 남은 문제: 실제 게임 창에서 무적 링의 시각적 세기와 토스트 3초 체감은 육안 확인 미실행(headless). 낮 주기 5~9의 선공몹 체감 비중은 플레이테스트 후 `AGGRO_DAY_WEIGHT_BASE`/`RAMP`로 조정 가능.
- 다음 AI가 시작할 정확한 지점: 패키지 C(UI) 완료 후 `godot --path godot-game`로 실제 플레이하며 ⑮무적 링과 ⑲토스트 3초를 육안 확인. 조정이 필요하면 `game.gd` 상단 `MODAL_RETURN_INVULN` / `BOSS_TOAST_HOLD` / `monster_library.gd`의 `AGGRO_DAY_*` 상수만 손대면 된다.

### 2026-08-04 15:46 KST — 2차 플레이테스트 피드백 반영 (난이도·온보딩·결과 모달·필드 HUD)

- 사용자 요청: ⑨온보딩·결과 모달 UI 업그레이드 ⑩난이도가 너무 어려움 — 초반 원거리몹 금지(최소 중후반) ⑪필드 HUD 딜싸이클을 텍스트가 아닌 디자인 형태로. (밤 1회차·생존 59초·레벨 3 사망 상황)
- 상태: ready_for_playtest
- 결정한 내용:
  - 밤 1회차 원거리의 정체는 wisp(해금 전)가 아니라 부채 기반 targeting 모듈이었음 → 네이티브·부채 두 경로를 `MonsterLibrary.ranged_gate_ok(cycle)` 단일 게이트로 통일(기준: targeting 종 최소 unlock=4주기에서 자동 유도).
  - 난이도 완화는 체력·공격력이 아닌 구성·물량으로: wisp 해금 2→4주기(램프업 조정), royal_ooze 3→2주기, 밤 1~2회차 위험 몹 비중 75→54%/86→62%(night_mul), 밤 물량 상수 신설(NIGHT_*: 밤1회차 상한 61→35·간격 0.355→0.67초·즉시 습격 10→5, 낮 불변).
  - 결과 모달은 공장 레일 렌더러를 `interactive=false` 파라미터로 그대로 재사용해 시각 언어 통일. 온보딩은 스파인 페이지 인디케이터 + 새 플로우 반영 캡션. 필드 HUD는 아이콘 칩 3개(이전44/현재64/다음44) + 진행 바 + RELOAD 주황 상태.
- 변경 파일:
  - `godot-game/scripts/monster_library.gd`: wisp/royal_ooze 해금·가중치·night_mul 조정, ranged_ids()/ranged_gate_ok()/ranged_unlock_cycle()/spawn_table() 헬퍼, 게이팅 규칙 주석
  - `godot-game/scripts/enemy.gd`: 부채 targeting 모듈을 ranged_gate_ok로 게이팅(초반엔 모듈 미부여), _current_cycle_number() 헬퍼
  - `godot-game/scripts/game.gd`: 상단 NIGHT_* 상수 신설(_current_spawn_interval/_current_enemy_limit/_night_raid_burst_count), 온보딩 전면 개편(_onboarding_pages/_build_onboarding_steps), 결과 모달 개편(_show_result/_build_result_deal_cycle/_add_result_stat_chip), 필드 HUD 딜싸이클 칩(_build_cycle_hud/_apply_cycle_chip), _build_factory_rail_slot에 interactive 파라미터, v4-test에 early_ranged_gate 검사 추가
- 사용자에게 보이는 변화: 초반(1~3주기)에 원거리 공격 완전 소멸, 밤 1회차 물량 대폭 감소(후반은 점진 복귀), 온보딩·게임오버/승리 화면이 공장과 같은 디자인, 필드 HUD 딜싸이클이 스킬 아이콘 칩+진행 바로 표시.
- 데이터/저장 호환성: 저장 스키마 변경 없음.
- 실행한 검증 (최종 코드 상태, UI 에이전트가 전체 재실행):
  - compile / `--world-test` / `--v4-test` / `--v4-castle-test` / `--stress-test` / `--smoke-test` → 전부 PASS (신규 early_ranged_gate 포함, 음성 대조 실험으로 검사 유효성 확인)
  - `--capture-onboarding` / `--capture-factory`(회귀 없음 확인) / lost·won·HUD 3상태 임시 프로브 캡처 → 육안 확인 PASS, 프로브 원복 diff 확인
- 남은 문제: 결과 모달 4칸+ RELOAD 패널 스크롤 필요(§12), RELOAD 패널 위치 사용자 결정 대기, 온보딩 인디케이터 현재/지나온 칸 명도 차이 약함, HUD 칩 사이 스파인 여백.
- 다음 AI가 시작할 정확한 지점: 사용자 재플레이테스트 피드백으로 섹션 1 체크포인트 갱신. RELOAD 패널 위치 결정 시 game.gd 공장 레일 루프의 마감 패널 삽입 위치 변경.

### 2026-08-04 14:47 KST — 1차 플레이테스트 피드백 8건 반영

- 사용자 요청: ①레벨업 선택 로직 1개로 통일(←왼쪽/→오른쪽 스킬) ②스킬 이펙트 180° 불일치 수정·범위 가이드 제거·이펙트 위치=피해 위치 ③몹 체력/난이도 상향 ④아이템 획득을 보관함 직행+이지선다로(미선택은 마왕) ⑤드래그 시 카드 에셋이 따라오게 ⑥다리 연결 자연화 ⑦전체 10칸 사전 표시+RELOAD 패널 재설계 ⑧레일 가운데 정렬·확대.
- 상태: ready_for_playtest
- 결정한 내용:
  - 180° 원인은 VFX 아틀라스 참격 스프라이트의 원본 진행축이 -X인 것. `+PI` 땜질 대신 `VFX_SLASH_SOURCE_DIRECTION` 상수로 에셋 규약을 명시하고 회전을 유도.
  - 이중 선택 원인은 Godot 내장 포커스(FOCUS_ALL)가 방향키를 게임 코드보다 먼저 소비한 것. 전 선택 버튼 FOCUS_NONE + 단일 포커스 인덱스로 통일.
  - 몬스터 체력은 배율이 아니라 "기본 베기 방수(slash_hits)"로 정의(초반 3~5방).
  - 공장 레일은 10칸 상시 표시(미건설 회색), 연속 스파인 위 인라인 다리, RELOAD는 레일 끝 마감 패널+헤더 상시 표기, 화면 정중앙 배치·카드 190×142.
  - 상점 구매는 이지선다 대상이 아님(단일 구매 유지, 보관함 직행만 통일).
- 변경 파일:
  - `godot-game/scripts/cycle_skill_effect.gd`: 스프라이트 회전축 통일, 범위 가이드 제거, 판정 중심/반지름 공유(_impact_origin/_impact_radius), chain 전방 직선 제거
  - `godot-game/scripts/game.gd`: cycle_pulse_center/radius 신설, 선택창 단일 포커스 시스템(_register_choice_button 등), 아이템 이지선다(_show_item_offer_pair)·보관함 직행·마왕 전달, 공장 레일 10칸 렌더러·RELOAD 마감 패널·중앙 정렬, 자동 테스트 3종 추가
  - `godot-game/scripts/factory_drag_button.gd`: set_drag_preview 카드 복제 프리뷰(아이콘 재동기화 포함), 원본 딤 처리
  - `godot-game/scripts/monster_library.gd`: slash_hits 기반 체력 재정의, health_for() 신설
  - `godot-game/scripts/enemy.gd`: health_for() 사용으로 전환
- 사용자에게 보이는 변화: 이펙트가 바라보는 방향과 일치, 범위 도형 없음, 몹이 여러 방 버팀, 선택창 강조가 항상 1개, 아이템은 2지선다 후 보관함으로, 공장 레일이 중앙에 크게 10칸 전체 표시, 드래그 시 카드가 따라옴.
- 데이터/저장 호환성: 저장 스키마 변경 없음. 기존 런 저장 그대로 사용 가능.
- 실행한 검증 (마지막 코드 상태 기준, 패키지 3 에이전트가 전체 재실행):
  - `godot --headless --path godot-game --editor --quit` → PASS
  - `--world-test` / `--v4-test` / `--v4-castle-test` / `--stress-test` / `--smoke-test` → 전부 PASS (신규 검사 single_focus·item_pair_storage·shop_item_storage 포함)
  - `--capture-factory`·`--capture-effects` → 캡처 육안 확인 PASS
- 남은 문제:
  - RELOAD 마감 패널이 레일 맨 끝(칸10 뒤)이라 스크롤 전에는 안 보임(헤더 우상단 상시 수치로 보완). 목업처럼 마지막 건설 칸 뒤로 옮길지 사용자 결정 대기.
  - 미건설 자리표시자는 점선이 아니라 딤 처리(StyleBoxFlat에 점선 없음).
  - 시련 캠프 정예(×5)가 기저 체력 상향에 비례해 강해짐 — 과하면 별도 조정.
  - 보관함 카드 지표 바 텍스트 살짝 잘림(기존 문제, 이번 범위 아님).
- 다음 AI가 시작할 정확한 지점: 사용자 재플레이테스트 피드백으로 섹션 1 체크포인트의 `active_request` 갱신. RELOAD 패널 위치 결정이 오면 `game.gd`의 공장 레일 루프에서 마감 패널 삽입 위치 변경.

### 2026-08-04 13:24 KST — 인수인계 체크포인트 재검증

- 사용자 요청: AGENTS.md를 처음부터 끝까지 읽고 섹션 1 체크포인트부터 작업을 이어서 진행.
- 상태: ready_for_playtest
- 결정한 내용:
  - 활성 코딩 요청이 없으므로 새 구현 대신 체크포인트의 `last_verified` 상태를 재검증.
  - 검증 결과 문서와 코드가 일치하므로 status를 `ready_for_playtest`로 유지.
- 변경 파일:
  - `AGENTS.md`: 체크포인트 갱신 시각·재검증 기록, 이 변경 로그 항목 추가. 게임 코드 수정 없음.
- 사용자에게 보이는 변화: 게임 동작 변화 없음.
- 데이터/저장 호환성: 영향 없음.
- 실행한 검증:
  - `godot --headless --path godot-game --editor --quit` → PASS
  - `godot --headless --path godot-game -- --world-test` → PASS (WORLD_TEST_COMPLETE)
  - `godot --headless --path godot-game -- --v4-test` → PASS (V4_TEST_COMPLETE)
  - `godot --headless --path godot-game -- --v4-castle-test` → PASS (V4_CASTLE_TEST_COMPLETE)
  - `godot --headless --path godot-game -- --stress-test` → PASS (STRESS_TEST_COMPLETE)
  - `godot --headless --path godot-game -- --smoke-test` → PASS (SMOKE_TEST_COMPLETE)
  - 코드 지도 스크립트 26종·섹션 9 생성 에셋 11종·QA 캡처 6종 존재 확인 → PASS
- 남은 문제: 기존과 동일 — Git 미추적 상태, 밸런스 임시값, 저장 스키마 버전 없음.
- 다음 AI가 시작할 정확한 지점: 사용자 플레이테스트 피드백을 받아 섹션 1 체크포인트의 `active_request`를 한 문장으로 갱신하고 status를 `in_progress`로 변경한 뒤 구현 시작.

### 2026-08-04 12:42 KST — 단일 AI 인수인계 체계 구축

- 사용자 요청: 지금까지의 업데이트와 구조를 한 파일에 정리하고, 이후 작업도 언제든 중단 지점부터 이어갈 수 있게 만들기.
- 상태: completed
- 결정한 내용:
  - 루트 `AGENTS.md`를 단일 인수인계 원본으로 사용.
  - 현재 체크포인트와 누적 변경 로그를 같은 파일에 유지.
  - 모든 후속 AI가 작업 전/중/후에 체크포인트를 갱신하도록 규칙화.
- 변경 파일:
  - `AGENTS.md`: 구현 현황, 구조, 데이터 흐름, 테스트, 한계, 재개 규칙, 변경 로그 양식 추가.
- 사용자에게 보이는 변화: 게임 동작 변화 없음. 다음 AI가 현재 상태를 바로 파악할 수 있음.
- 데이터/저장 호환성: 영향 없음.
- 실행한 검증:
  - 로컬 코드 경로, Godot 버전, 테스트 플래그, 에셋 preload 대조.
- 남은 문제: 현재 Git에 실제 프로젝트 파일이 추적되지 않음.
- 다음 AI가 시작할 정확한 지점: 섹션 1 체크포인트를 읽고 사용자 플레이테스트 피드백을 새 `active_request`로 기록.

### 2026-08-04 — minimal-v2 시각 시스템과 WFC 무한 맵

- 상태: ready_for_playtest
- 결정한 내용:
  - Simple Tiled WFC를 결정적 무한 청크 스트리밍으로 확장.
  - 로비, 전사 선택, 온보딩, 공장, 아이콘, 지형, VFX를 미니멀 픽셀 방향으로 통일.
  - 물 과다 생성을 낮추고 청크 캐시를 최대 72개로 제한.
- 변경 파일:
  - `wfc_chunk_generator.gd`, `world_grid.gd`, `game.gd`
  - `skill_icon.gd`, `generated_ui_icon.gd`, `cycle_skill_effect.gd`, `projectile.gd`
  - `art/generated/**/*minimal-v2*`
- 검증:
  - world, v4, castle, stress, smoke 테스트 통과.
  - 로비, 캐릭터, 온보딩, 월드, 공장, 효과 캡처 확인.
- 다음 시작점: 실제 플레이 중 첫 UX 또는 밸런스 문제를 한 가지씩 수정.

### 이전 누적 단계 — Godot 플레이어블 프로토타입 완성

- Phaser/벽돌깨기 실험을 버리고 Godot으로 전환.
- 낮 탐험/밤 습격, 네 몬스터 행동, 성/상자/시련/마왕성을 구현.
- 누적 스킬 자동발동 방식을 딜싸이클 공장으로 전면 교체.
- 카드 합성, 아이템 57종, 1·2차 전직, 마왕 20칸 공장을 구현.
- 로비/이어하기/설정, 캐릭터 선택, 4페이지 온보딩, 결과 딜싸이클을 구현.
- 대시, 부드러운 방향 전환, 피격 반응, 공간 해시와 개체 상한을 구현.

---

## 16. 다음 AI를 위한 최종 확인 문장

v3 스테이지 개편(V0~V10) · UI 재스킨 시리즈(U0~U3) · 1차 피드백 라운드(X1~X4) ·
**2차 피드백 라운드(Y0~Y8 · YA · YZ)** 가 모두 끝났다. 중단된 코딩 작업은 없다.
자동 검사 17종(컴파일 1 + 기능 16)이 전부 통과했고 시각 캡처 15종 육안 검수와
비headless 실행 관찰도 마쳤으며, 지금 상태는 **3차 플레이테스트 대기**다.

다음 요청이 들어오면
① `godot-game/`만 현재 제품으로 취급하고,
② §1 체크포인트를 새 요청으로 갱신한 뒤,
③ §3의 "절대 바뀌면 안 되는 핵심 정체성 10개"를 건드리는 요청인지 먼저 확인하고
   (건드린다면 사용자에게 되묻는다),
④ 밸런스 요청이면 `balance_probe.gd`(**`pass=1`이 계약**)로, UI 요청이면
   `docs/ui-style-v3.md`와 **§11의 화면별 상한 계약 표**로 근거·규격부터 확보하고,
⑤ 관련 파일과 테스트부터 이어서 작업한다.

**특히 조심할 것 — 삭제된 기능을 가리키는 말**(§13 규칙 12의 금지어 표가 정본이다):
「나침반」 · 「각인 강화」 · 「카드 이동 모드 / 칸 교환 모드」 · 「레벨업에서 각인을 얻는다」 ·
「성장 천장 자동 전환」 · **「과열」과 그 파생어**(열기·잔열·되감기·도약·재실행·역행·책갈피) ·
**「결속」·「삼각」** · **한자 원소(화·빙·뇌·유·초)**.
화면 문자열·온보딩·툴팁·문서 어디에도 다시 쓰지 않는다.

그리고 **문서가 코드와 다르면 코드가 맞다.** 각인 이름은 `core/rune_engine.gd`의 `RUNES`,
속성 이름은 `DealCardLibrary.element_name()`, 밸런스 숫자는 `core/tuning.gd`가 정본이다.
