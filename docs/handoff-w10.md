# W10 인수인계 — 마왕전 v2 · 프리뷰 · 결과 화면 · 월식

> 작성: W10 구현 웨이브 / 2026-08-07
> 대상: **W11**(에셋) · **W12**(통합·저장·밸런스)
> 검증: `--editor --quit` 오류 0 · `run_all.sh` **컴파일 + 12종 전부 PASS**(신설 `--boss-test` 포함) ·
> 캡처 6컷 비headless 육안 검수 완료.

수정한 파일 4개: `game.gd` · `core/tuning.gd` · `test/test_runner.gd` · `test/run_all.sh`

`rune_engine.gd` · `factory_deck.gd` · `deal_cycle_controller.gd` · `combat_resolver.gd` ·
`demon_lord.gd` · `deadline_clock.gd` · 라이브러리 5종 · `enemy.gd` · `player.gd` · `world_grid.gd` ·
`castle_interior.gd` · `class_library.gd` 는 **한 줄도 고치지 않았다.**

원본 보존(부록 C-2): `docs/v1-archive/boss_result_v1.gd.txt`
(마왕 프리뷰 · 결과 화면 · 전조 보상 UI의 재작성 직전 원본 455줄)

---

## 1. 보스전 v2 — 공략 문법을 화면에 올렸다 (설계 §6.2)

### 1.1 규칙 최종본

| 항목 | 값 | 소유 |
|---|---|---|
| 마왕 5칸 구성 | `demon_lord.slot_layout()` (자동 합성 → `expected_power` 상위 5장) | DemonLord |
| 각인 | `demon_lord.granted_runes` → `RuneEngine.roll_rune()` → `deck.attach_rune()` | DemonLord + FactoryDeck |
| 버린 아이템 | `deck.equip()` — 칸을 먹지 않는다(§5.4) | FactoryDeck |
| 런타임 | `DealCycleController(is_boss=true, uses_reload=true, seed=run_cycle_seed+5701)` | W2 |
| RELOAD 배율 | `reload_scale = 0.6` (`GameTuning.BOSS_RELOAD_MUL`) | W2 |
| **HP 배율** | **`boss.max_health *= demon_lord.hp_multiplier(day)`** — §1.4 참조 | W10 신설 |

`_build_boss_factory()`는 W2가 이미 v2로 만들어 둔 것을 유지하되 두 가지를 더했다:
`rune_catalog` 재확인(자리표시자 id 방지)과, 칸 상한(5개 / 같은 id 3개)에 걸려 거부되는
각인에 대한 명시적 주석. **`game._boss_auto_fused_cards()`는 삭제했다**(handoff-w4 §6 지시 이행,
호출부 0이었다). 자동 합성의 단일 창구는 이제 `demon_lord.auto_fused_cards()` 하나다.

### 1.2 마왕 레일 밴드 — 보스전 HUD (신설)

> "마왕의 과열 게이지가 화면에 보인다 → '지금 과열 6, 피하고 버텨라 → RELOAD 왔다, 지금 때려라'.
> **이것이 v2 보스전의 문법이다.**" (설계 §6.2)

**자리는 나침반 + 마왕 고스트 레일의 합집합**이다. 보스전에서는 마왕성 나침반도 "마왕이 얼마나
자랐나" 요약도 의미가 없다 — 마왕이 이미 여기 있다. 두 패널을 끄고 그 자리에 실시간 레일을 켠다.
**필드는 한 픽셀도 더 가리지 않는다.**

```text
BOSS_RAIL_BAND = (806, 10) 458×132        ← HUD_COMPASS_RECT ∪ HUD_GHOST_RECT
  y   3~ 21  머리말 "마왕의 딜싸이클 · 칸 03 / 05 ↺1"  |  "과열 6 / 8 · 피해 ×1.72"
  y  21~ 31  바늘(RailMarker · 색 = _heat_color(heat))
  y  34~ 86  칸 5개 (72×52, 간격 8)  |  과열 온도계 8단 (414~448)
  y  90~102  ▶ RELOAD 창 게이지
  y 105~125  상태 줄
가로 증명: 10 + 72×5 + 8×4 = 402 → 온도계 414~448 → 밴드 폭 458 (우여백 10)
```

| 상태 | 레일 | 게이지 | 상태 줄 |
|---|---|---|---|
| 평상시 | 활성 칸 테두리 = `_heat_color(heat)` · 바늘 표시 | **주황/적** = `projected_reload() / RELOAD_CAP` | `빚 1.42초 · 사이클이 끝나면 반격 창 1.77초` |
| **RELOAD 중** | **5칸 전체 청색 냉각 · 바늘 숨김** | **초록** = `reload_remaining / reload_duration` | `▼ 무방비 · RELOAD 1.32초 남음 — 지금 때려라` |

- 색 언어는 플레이어 레일(W5)과 같다(과열 청→금→적, RELOAD 냉각 청색). **다른 것은 하나뿐** —
  마왕의 RELOAD는 *내 기회*이므로 게이지를 **초록으로 뒤집었다**.
- 보스 체력 패널(`boss_text`)도 같은 리듬을 한 줄로 말한다:
  `딜싸이클 마왕 100% · 5칸 · 과열 6 / 8` ↔ `… · RELOAD 1.3초 · 무방비`.
- 반격 창이 열릴 때 배너 1회: `마왕 RELOAD 1.85초 — 지금 때려라`.
- **트윈 0개.** 강조는 전부 `_update_boss_rail(delta)`의 float 감쇠다(W5 규약 그대로).
- 시그널은 **지연 연결**이다(`_bind_boss_rail_signals()`). `_begin_boss_battle`이 아무것도 하지
  않아도 밴드가 알아서 붙는다.

#### ⚠️ 함정: `cycle_completed`는 `reload_duration`보다 먼저 발화한다

`deal_cycle_controller._finish_cycle()`은 `emit_signal("cycle_completed", …)`를
**`reload_duration`을 채우기 전에** 부른다. 그래서 반격 창의 개수(`boss_reload_windows`)는
시그널이 아니라 `_update_boss_rail`에서 **`reloading`의 false→true 전이**로 센다.
(첫 구현은 시그널로 셌고 `--boss-test`의 `reload_window`가 즉시 이 버그를 잡았다.)

### 1.3 실측 수치 (`--boss-test` / 캡처 기준)

| 항목 | 관측값 |
|---|---|
| 마왕 한 바퀴 RELOAD (반격 창) | **1.32 ~ 1.85초** (5칸 표준 덱, 과열 0~1) |
| 같은 덱을 플레이어가 돌렸을 때 | 2.09 ~ 2.28초 (= 마왕의 1 / 0.6) |
| 마왕 과열 상한 | 8 (`RuneEngine.HEAT_MAX`) · 과열 6에서 피해 **×1.72** |
| 마왕 HP 배율 | 3일차 ×1.44 / 5일차 ×1.88 / 7일 자발 ×2.32 / **7일 강림 ×2.668** |
| 7일 강림 실체력 | 기저 ×2.668 (`--boss-test`의 `hp_scale`이 기준 개체와 대조해 단언) |

### 1.4 ⚠️ HP 배율이 이번에 **처음으로 실제 체력에 걸렸다**

W9까지 `demon_lord.hp_multiplier(day)`는 HUD 고스트 레일에 **표시만** 되고 아무 데도 적용되지
않았다(강림의 ×1.15만 `_trigger_descent`가 사후에 곱했다). 설계 §4.3의 "조기 도전 vs 만기 도전"
의사결정은 이 숫자 위에 서 있으므로 `_begin_boss_battle()`에서 한 번만 곱하도록 했다.

`hp_multiplier()`가 강림 보정을 이미 품고 있으므로 **`_trigger_descent`의 `*= DESCENT_HP_MUL`
한 줄은 제거**했다(§5의 경계 접촉 표 참조). 이중 적용 방지.

> **W12에게**: 이건 실질적인 난이도 상향이다. 7일차 강림 기준 기저 HP 약 1,050 → **약 2,800**
> (설계 §9.4의 `BOSS_BASE_HP` 2,400 추정치와 같은 자릿수). 플레이테스트의 첫 관측점이다.

### 1.5 두 진입 경로 검증

| 경로 | 프리뷰 | 각인 | HP | 검증 |
|---|---|---|---|---|
| 자발 도전 `_challenge_demon_king()` | **있음**(취소 가능) | 기본 | `hp_multiplier(day)` | `--boss-test` `preview` · `--v4-test` `boss_preview` · `--deadline-test` `early_challenge` |
| 강림 `_trigger_descent()` (7일차 밤 종료) | **없음** | +2 | `× 1.15` 포함 | `--boss-test` `descent` `hp_scale` · `--deadline-test` `descent_game` |

`_trigger_descent()`가 `_build_boss_factory()` → `state="boss_preview"` 한 프레임 → `_begin_boss_battle()`을
부르는 W4의 계약은 **그대로 유지**했다.

### 1.6 잔재 → 밤 몹 (경로 확인만)

`enemy.gd`가 `game.rejected_skills`를 받아 모듈을 8~24% 확률로 부여하는 v1 경로는 무수정이다.
`demon_lord.residue_modules()`는 **월식(§3)이 유일한 소비자**다.

---

## 2. 마왕 프리뷰 v2 (설계 §8.4)

> "편집 화면과 **픽셀 동일한 레일 렌더러**로 마왕의 5칸 + 각인 + 흐름 아크를 그린다.
> 내 레일과 나란히 비교 가능. '돌아가서 준비한다(ESC)' 취소 버튼 유지."

```text
┌─ BOSS_PREVIEW_PANEL_RECT (30,26) 1220×668 ────────────────────────────────┐
│ 마왕의 딜싸이클 — 도전 확인      5일차 · 승리 시 등급 A · HP ×1.88 · R×0.6 │ 14~48
│ 마왕도 당신과 같은 규칙으로 돕니다 — 바늘·과열·재진입 감쇠·빚 RELOAD …     │ 48~70
│ ▌내 5칸            각인 4개 · 한 바퀴 RELOAD 빚 1.71초 · 장비 0 / 4        │ 74
│      ╭── 흐름 아크 + 확률 라벨 ──╮                                        │ 96~136
│ [칸1 196×150][44][칸2][44][칸3][44][칸4][44][칸5]                         │ 138~288
│ ▌마왕의 5칸   각인 7개 · 받은 카드 10장 · 잔재 3 · 뜯어낸 1 · 밀정 열람    │ 294
│      ╭── 흐름 아크 ──╮                                                    │ 316~356
│ [칸1][44][칸2][44][칸3][44][칸4][44][칸5]                                 │ 358~508
│ 한 화면 비교 · 몬테카를로 48회씩 — 스텝/피해/한바퀴/RELOAD창/과열/과부하율 │ 514~566
│ [그래도 들어간다 · SPACE]   [돌아가서 준비한다 · ESC]                      │ 574~626
└───────────────────────────────────────────────────────────────────────────┘
가로 증명: (1,220 − 1,156) / 2 = 32 → 좌우 여백 32px. **ScrollContainer 0개.**
```

- **v1 렌더러 잔재 제거 완료**: `_build_factory_rail_slot` + `ScrollContainer`(카드 200×142) 경로를
  프리뷰·결과 화면 양쪽에서 걷어냈다. 두 화면 모두 **W6 편집 레일 치수**(196×150 · pitch 240 ·
  콘텐츠 1,156px)를 읽기 전용으로 쓴다. `_build_preview_slot()`이 `_build_edit_slot`과
  좌표·크기·계층이 같고, 다른 것은 버튼·드래그·`factory_lane_buttons` 등록이 없다는 점뿐이다.
- **비교 지표**: 두 덱을 **같은 시드·같은 표본 수**(48)로 돌린다. 마왕 쪽만
  `{"reload_scale": 0.6}` opts를 넣는다. 모달 1회 계산 ≈ 8ms.
- **밀정(W9) 연동**: `spy_revealed`가 켜져 있으면 마왕 칸의 각인 **이름**이 캡션에 그대로 뜬다
  (`되감기 · 앙코르 · 잔열`). 꺼져 있으면 `각인 N개 · 미열람`. 핍(희귀도 색)은 항상 보인다.
  handoff-w9 §6이 "프리뷰에서도 이름을 보여 주는 게 자연스럽다"고 지목한 자리다.
- **뜯긴 각인 / 회수한 카드 수**를 머리말에 노출했다 — 전조(W4)·밀정(W9) 두 밸브가 실제로
  작동했음이 읽힌다(handoff-w9 §6 요구).
- 취소 버튼 유지. 툴팁에 칸별 각인 스택이 이름·실효 확률로 들어간다.

---

## 3. 월식(Eclipse) — 5일차 (설계 §4.1 / §6.4) **신설**

W9가 "미구현 이정표 1건"으로 남긴 자리다. 배너만 있었다.

### 3.1 설계 문장 두 개를 한 사건으로 합쳤다

| 출처 | 문장 |
|---|---|
| §4.1 | "**마왕이 모든 필드 몹에게 자기 각인 1개를 나눠준다**" |
| §6.4 | "5일차 월식 때는 이 (잔재 모듈) **부여율이 100%**가 된다" |

→ 월식이 켜지면 필드에 나오는 **모든 마물**이
① 마왕의 **잔재 카드 모듈 1개를 확정으로** 받고 (평소 `enemy.gd`의 8~24%)
② 마왕의 **각인 1개를 몸에 지닌 채** 나온다.

필드 몹은 5칸을 돌지 않으므로 각인은 능력치로 환산한다:

```gdscript
GameTuning.ECLIPSE_DAY          = 5
GameTuning.ECLIPSE_PERSISTS     = true     # 켜지면 런 끝까지 유지 (§3.2)
GameTuning.ECLIPSE_SWEEP_INTERVAL = 0.28   # 새 스폰을 훑는 주기(초)
GameTuning.ECLIPSE_HEALTH_MUL   = 1.22
GameTuning.ECLIPSE_DAMAGE_MUL   = 1.16
GameTuning.ECLIPSE_SPEED_MUL    = 1.05
```

받았다는 표시는 마물의 `ECLIPSE_META`(= `"eclipse_rune"`, 값 = 각인 id) 메타다.
이 표식이 **중복 부여를 막는 유일한 방어선**이다.

### 3.2 설계 대비 결정 2건

| # | 내용 | 근거 |
|---|---|---|
| **E-1** | 월식은 5일차에 켜지고 **꺼지지 않는다**(6·7일차에도 유지) | `DeadlineClock`에 "월식 종료" 시그널이 없다. 하루짜리로 만들면 5일차 낮 배너 한 번으로 끝나 읽히지 않는다. 설계 §9.5 "7일차는 위험해야 한다"와 같은 방향 |
| **E-2** | 각인을 **실행**시키지 않고 능력치로 환산 | 필드 몹에게는 5칸도 바늘도 없다. 각인을 실행하려면 몹마다 `FactoryDeck` + `DealCycleController`가 필요한데 밤 물량(최대 78기)에서 성립하지 않는다. 전조(§4.5)가 이미 "각인을 실행하는 몹"을 1기 한정으로 맡고 있다 |

### 3.3 구현 위치가 `game.gd`인 이유

`enemy.gd`의 부여 확률표와 `combat_resolver.spawn_enemy_instance()`는 **둘 다 W10 소유가 아니다**
(무수정 원칙). 스폰 직후를 폴링으로 훑는 `_sweep_eclipse()`가 라이브러리를 한 줄도 건드리지 않는
유일한 길이다. 훅은 두 곳뿐이다:

```gdscript
_on_clock_milestone("eclipse", 5)  → _begin_eclipse()   # 즉시 1회 스윕
_process()의 playing 구역          → 0.28초마다 _sweep_eclipse()
```

`eclipse_module_pool()`은 잔재가 우선이고, 잔재가 없으면 **마왕 레일 5칸의 카드를 모듈로 환산**해
쓴다 — "버린 카드가 하나도 낭비되지 않는다"(§6.4)가 월식에서 가장 세게 나와야 한다.
원거리 모듈(`targeting`)만은 `MonsterLibrary.ranged_gate_ok(day)` 게이트를 그대로 존중한다.

---

## 4. 결과 화면 v2 (설계 §8.4)

v1 지표(생존 시간 / **"낮 / 밤 N회"** / 레벨 / 처치 4칩)는 무한 라운드 게임의 언어였다.
7일 기한 게임의 언어로 전면 교체했다.

```text
┌─ RESULT_PANEL_RECT (12,26) 1256×668 ─────────────────────────────────────┐
│ 버린 운명을 넘어섰습니다                        마왕 토벌 · 등급 A       │ 14~52
│ 등급은 도달 일차만 봅니다 — 계약으로 하루를 사면 그만큼 내려갑니다…      │ 52~74
│ ┌ 7일 여정 ─────────────── 도달 5일차 · 낮 · 잔여 기한 05:19 ──────────┐ │ 84~150
│ │ [1일 ✓ 출발][2일 ✓ 균열 개방][3일 ✓ 마왕성 개방][4일 ✓ 두 번째 균열]  │ │
│ │ [5일 ▶ 월식][6일 2차 각성][7일 마지막 낮]                            │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│ [승리 등급][도달 일차][잔여 기한][최고 과열][각성]                       │ 156~206
│ [마왕에게 준 카드][마왕 각인][뜯어낸 각인][내 각인][균열 클리어 · 처치]  │ 212~262
│ ▌최종 5칸과 각인   칸 5개 · 각인 5개 · 한 바퀴 RELOAD 빚 1.20초 · 장비 1/4│ 274
│ [칸1 196×150]▶[칸2]▶[칸3]▶[칸4]▶[칸5]                                  │ 300~450
│ 마왕의 5칸: 받은 카드 8장 → 상위 5장이 레일 · 잔재 3개가 밤의 마물로 …    │ 462
│ [다시하기]   [로비로 돌아가기]                                           │ 540~592
└──────────────────────────────────────────────────────────────────────────┘
가로 증명: 레일 콘텐츠 1,156px / 패널 1,256px → 원점 x=50. **ScrollContainer 0개.**
```

| 지표 | 출처 |
|---|---|
| 승리 등급 | `demon_lord.victory_grade(clock.day_number, clock.descended)` |
| 도달 일차 / 잔여 기한 | `clock.day_number` / `clock.run_remaining()` |
| **최고 과열** | `run_peak_heat` — `player_cycle.cycle_completed(steps, max_heat)` + 10Hz 폴링 |
| 각성 | `player.advancement_tier` + `ClassLibrary`의 `tier1_name`/`tier2_name` |
| 마왕에게 준 카드 / 마왕 각인 / 뜯어낸 각인 | `boss_growth_preview()` |
| 균열 클리어 | `rift_states`의 `cleared` 수 |
| 마왕 RELOAD 창 / 월식 기수 | `boss_reload_windows` / `eclipse_marked` |

- **7일 타임라인**: 이정표 짧은 이름은 W5의 `MILESTONE_SHORT`를 그대로 쓴다.
  지난 날 `✓`, 오늘 `▶`(강림이면 적색), 못 간 날은 회색.
- **승리 등급 문구**: handoff-w9 §6이 요구한 "계약으로 일수가 움직이면 등급이 내려간다"를
  부제에 명시했다.
- **v1 지표 0개**: `--boss-test`의 `result` 플래그가 결과 패널 전체를 재귀 순회해
  `"낮 / 밤"` · `"시련 구슬"` 문자열이 하나라도 남아 있으면 FAIL 낸다.

---

## 5. 전조 보상 2택1 UI (W4 최소 구현 → W6 골격으로 재작성)

**화면은 이미 있었다.** W4가 `_label`/`_button`만으로 만든 2버튼 모달이었고,
handoff-w4 §4가 "W6가 각인 드래프트와 같은 골격으로 재작성할 것"으로 남긴 자리다.

**상태 처리(`_omen_defeated` / `_set_omen_reward_index` / `_resolve_omen_reward`)는 한 줄도
고치지 않았다.** 화면만 바꿨다.

| 선택지 | 카드 골격 | 근거 |
|---|---|---|
| 각인 뜯기 | W6 각인 드래프트 `_rune_offer_button`과 같은 언어(희귀도 칩 · 색 바 · 큰 이름 · 계열 · 효과 문장) | 보상이 **각인**이다 |
| 카드 회수 | `_build_choice_card_body`(표준 카드 블록 + 배지 + 요약 줄) | 보상이 **카드**다 |

- 패널 980×420 → **1028×484**, 카드 420×190 → **452×252**(표준 카드 블록이 들어가는 최소 높이).
- 뜯길 각인을 **미리 보여 준다** — `DemonLord.strip_rune()`이 "그 칸의 가장 최근"을 고르므로
  화면도 같은 순서로 읽어 예고와 실제가 어긋나지 않는다. 그 칸이 비었으면 폴백(아무 칸의 마지막)도 같다.
- **불투명 안쪽 판**을 깔았다(handoff-w9 §7-7 패턴). 공용 `_style_button`의 focus 스타일박스가
  버튼 전체에 액센트 색을 깔아 밝은 색(일반 각인 = 금색) 카드에서 본문이 묻히기 때문이다.
  `_style_button`은 공용이라 손대지 않았다.
- ⚠️ **카드 인스턴스에 `name`이 없다**(handoff-w9 §2.4). 머리말이 항상 "빈 칸"으로 나오던 버그를
  `_factory_card_name()`으로 고쳤다.

---

## 6. 테스트

### 6.1 `--boss-test` (신설 · 마커 `BOSS_TEST_COMPLETE`)

```
BOSS_TEST_COMPLETE top5=true preview=true omen_strip=true omen_reclaim=true eclipse=true
  descent=true hp_scale=true needle=true reload_window=true boss_hud=true result=true
  runes=11 attached=10 eclipse_marked=16 reload=1.56 heat=1 hp=1000000000 steps=5
```

| 플래그 | 검사 내용 |
|---|---|
| `top5` | 상위 5장이 `ranked_cards()[0..4]`와 id·랭크까지 일치 · 화력 내림차순 · 칸에 아이템 0 · 아이템은 장비로 · 잔재 존재 · 각인이 칸별로 옮겨짐(상한에 걸린 만큼만) · **각인 id가 자리표시자가 아닌 실제 `RuneEngine.RUNES` 키** |
| `preview` | 프리뷰 패널에 칸 셀 **10개**(내 5 + 마왕 5) · **`ScrollContainer` 0개** · 모든 셀이 패널 안 · 마왕 칸의 `rune_count` meta == `boss_factory.rune_count_on(i)` · ESC 취소로 `playing` 복귀 |
| `omen_strip` | 전조 격파 → 각인 뜯기 → `rune_count` −1 · `stripped_runes` +1 |
| `omen_reclaim` | 각인 0인 상태에서 격파 → 포커스가 1번(카드 회수)으로 건너뜀 → `reclaimed_cards` +1 · `rejected_skills` −1 · 보관함 +1 |
| `eclipse` | 이정표 → `eclipse_active` · 필드 마물 **전원**이 표식 보유 · 표식 값이 실제 각인 id · **전원이 잔재 풀의 모듈을 보유**(100% 부여) · 체력이 정확히 `×1.22` · **두 번 훑어도 0기 추가**(중복 방지) |
| `descent` | 7일차 밤 종료 → `state=="boss"` · `descended` · 각인 +2 · boss_factory 5칸 · **오버레이 없음**(프리뷰 없음) |
| `hp_scale` | 같은 인자로 만든 **기준 개체와 대조**해 `boss.max_health == 기저 × hp_multiplier(7)` (오차 0.5 미만) |
| `needle` | `boss_cycle.planned_route()` == `RuneEngine.simulate_cycle(같은 덱, 같은 시드, 같은 opts).visited` · 시드 뿌리 == `run_cycle_seed + 5701` · `reload_scale == 0.6` |
| `reload_window` | 실제 프레임에서 `reloading`을 관측 · `0 < reload_duration ≤ RELOAD_CAP` · `reload_remaining > 0` · `boss_reload_windows ≥ 1` |
| `boss_hud` | 밴드 가시 · 칸 5개 · 과열 셀 8개 · 칸의 `rune_count` meta 일치 · 5칸이 밴드 폭 안 · **RELOAD 중 바늘 숨김 + 창 게이지 채워짐** · 나침반/고스트 꺼짐 |
| `result` | 결과 패널에 칸 셀 5개 · `ScrollContainer` 0 · 타임라인 7칸 · 달성 칸 수 == `clock.day_number` · **v1 지표 문자열 0개**(재귀 검사) |

### 6.2 기존 테스트와의 정합

| 테스트 | 보스 관련 플래그 | 상태 |
|---|---|---|
| `--v4-test` | `boss5` `boss_preview` `boss_runtime` | 전부 그대로 PASS (프리뷰 재작성 후에도 `boss_factory.slots.size()==5` 계약 유지) |
| `--cycle-test` | `boss`(5칸 · `reload_enabled` · `reload_scale==0.6` · 궤적 생성) · `hud_ghost` | 그대로 PASS |
| `--deadline-test` | `early_challenge` `descent` `descent_game` `omen_reward` | 그대로 PASS. `descent_game`은 `hp_multiplier` **공식**을 단언하므로 ×1.15를 `_begin_boss_battle`로 옮겨도 영향 없다 |
| `--smoke-test` | `state=won` | 그대로 PASS |

### 6.3 `run_all.sh`

`ALL_TESTS`에 `--boss-test:BOSS_TEST_COMPLETE` 추가 (총 **12종**).

```
PASS compile / world-test / v4-test / castle-test / rift-test / stress-test /
     smoke-test / combat-test / deadline-test / cycle-test / draft-test / boss-test
==================== 종합 결과: PASS ====================   (52초)
```

### 6.4 캡처 (비headless 육안 검수 완료)

`--capture-boss`는 **4컷**, `--capture-result`는 **2컷**으로 재작성했다.

| 파일 | 확인한 것 |
|---|---|
| `boss-minimal-v2-omen.png` | 전조 보상 2택 — 왼쪽 각인 카드(불투명 판 위 판독 가능) / 오른쪽 카드 회수. 머리말에 시연 칸·카드명 |
| `boss-minimal-v2-preview.png` | 내 5칸 vs 마왕 5칸 · 흐름 아크 + 확률 라벨 · 밀정 열람 시 각인 이름 · 비교 6지표 · **스크롤바 0** |
| `boss-minimal-v2-battle.png` (대표) | 마왕 레일 밴드: 칸 03/05 ↺1 · 과열 6/8 ×1.72 · 바늘 · 온도계 · 적색 창 게이지 · `빚 1.42초 · 사이클이 끝나면 반격 창 1.77초` |
| `boss-minimal-v2-reload.png` | **5칸 청색 냉각 · 바늘 숨김 · 초록 창 게이지 · `▼ 무방비 · RELOAD 1.32초 남음 — 지금 때려라`** · 체력 패널도 `RELOAD 1.3초 · 무방비` |
| `result-minimal-v2.png` (승) | 등급 A · 7일 타임라인(1~4 ✓ · 5 ▶) · 10칩 · 최종 5칸 + 각인 · 마왕 요약 줄 · **스크롤바 0** |
| `result-minimal-v2-lost.png` (패) | 등급 `—` · 같은 골격 · 패배 문구 |

기존 캡처 회귀 없음: `--capture-rail`(흐름 아크 레인 간격 18px 원상 복구 확인) · `--capture-hud`.

---

## 7. ⚠️ 소유권 경계를 넘은 곳 (보고 대상 · 전부 가산)

| # | 위치 | 소유 | 변경 | 이유 |
|---|---|---|---|---|
| 1 | `_trigger_descent()` | W4 | `boss.max_health *= DESCENT_HP_MUL` **1줄 제거** | `_begin_boss_battle()`이 `hp_multiplier(day)`(강림 보정 포함)를 곱하므로 이중 적용이 된다. §1.4 |
| 2 | `_build_edit_flow_arcs()` | W6 | 선택 인자 4개 추가(`deck` `arc_rect` `rail_origin_x` `lane_step`) | 설계 §8.4 "픽셀 동일한 레일 렌더러". handoff-w6 §8이 "인자 1개만 열면 된다"고 지정. **기본값이 편집 화면 값이라 호출부 무변경**, 캡처로 회귀 0 확인 |
| 3 | `_edit_flow_entries()` / `_slot_rune_probability()` | W6 | 선택 인자 `deck` 추가 | 같은 이유. 기본값 `null` → `factory` |
| 4 | `_factory_preview_summary()` | W6 | 선택 인자 `opts` 추가 | 마왕 비교 지표에 `reload_scale: 0.6`을 넣어야 한다. 기본값 `{}` |
| 5 | `_build_compass_panel()` | W5 | `compass_panel = panel` **1줄** | 보스전에서 이 패널을 끄고 그 자리에 마왕 레일 밴드를 켜기 위한 참조. 레이아웃 무변경 |
| 6 | `_build_ui()` / `_process()` / `_update_hud()` / `_begin_run()` | W5·W0 | 각 1~5줄 추가 | 마왕 레일 밴드 구축·갱신, 월식 스윕, 최고 과열 추적, 런 초기화. **전부 자기 구역 주석(`# === W10 소유:`)을 달았다** |
| 7 | `_save_run_snapshot` / `_restore_run_snapshot` | W12 | 키 4개 추가 | `eclipse_active`(빼면 이어하기 후 월식이 통째로 사라진다) · `eclipse_marked` · `run_peak_heat` · `boss_reload_windows` |
| 8 | `core/tuning.gd` | W0 | `ECLIPSE_*` 6상수 추가 | 지시서가 "GameTuning 상수로" 명시 |
| 9 | `_show_omen_reward()` | W4 | 화면 전면 재작성 | handoff-w4 §4가 "W6 골격으로 재작성할 것"으로 남긴 자리. **상태 처리 무수정** |

`schema_version`은 **2 그대로** 뒀다(가산 키만 늘었고 없는 키는 전부 기본값을 탄다).
`_restore_run_snapshot`은 `day_number >= 5`인데 `eclipse_active`가 없으면 켜 준다(구 스냅샷 호환).

---

## 8. 남겨 둔 것 · 다음 웨이브 체크리스트

### W11 (에셋)

| 붙일 자리 | 함수 |
|---|---|
| 마왕 레일 밴드 칸 아이콘 24×24 | `_build_boss_rail_band()`의 `Icon` 노드 하나 |
| 마왕 바늘 | `class RailMarker`(W5 공용) — 색은 `_heat_color` |
| 과열 온도계 8단 | `boss_rail_heat_cells` — `ColorRect` → `TextureRect` 교체 |
| 프리뷰·결과 칸 카드 | `_build_preview_slot()`의 `_paint_card_block` 하나(편집 화면과 완전 공용) |
| 각인 핍 | 프리뷰·결과의 핍은 편집 화면과 같은 10×10 `ColorRect` — handoff-w6 §8의 4곳에 이 2곳이 더해진다 |
| 결과 타임라인 7칸 | `_build_result_timeline()` — 일차별 아이콘 자리(현재 텍스트) |

좌표는 전부 `BOSS_RAIL_*` / `PREVIEW_*` / `RESULT_*` 상수 블록 한 곳에 모여 있다.

### W12 (통합 · 저장 · 밸런스)

- **밸런스 손잡이 (W10이 새로 만든/살린 숫자)**

  | 상수 | 값 | 관측점 |
  |---|---:|---|
  | `demon_lord.hp_multiplier` **실적용** | 3일 ×1.44 → 7일 강림 ×2.668 | **최우선 플레이테스트 항목.** 7일차 강림 실체력 ≈ 2,800 |
  | `BOSS_RELOAD_MUL` | 0.6 | 반격 창 1.3~1.9초. 이 창이 "때릴 수 있는 시간"으로 충분한가 |
  | `ECLIPSE_HEALTH_MUL` / `_DAMAGE_MUL` / `_SPEED_MUL` | 1.22 / 1.16 / 1.05 | 5~7일차 밤 생존률. `--boss-test`의 `eclipse_marked` |
  | `ECLIPSE_PERSISTS` | true | 월식이 6·7일차에도 유지되는 것이 과한가(§3.2 E-1) |
  | `ECLIPSE_SWEEP_INTERVAL` | 0.28초 | 밤 물량 78기에서의 스윕 비용(현재 `has_meta` 체크만이라 무시할 수준) |
  | `PREVIEW_SAMPLES` | 48 | 프리뷰 모달 개방 지연(현재 ≈8ms) |

- **저장 스키마**: `run_cycle_seed`(리플레이 계약) + W9의 5키 + W10의 4키. 버전을 올릴지는 W12 판단.
- **죽은 코드**: `FACTORY_RAIL_*` 렌더러 계열(`_build_factory_rail_slot` / `_build_factory_rail_bridge` /
  `_factory_rail_cell` / `_build_factory_rail_ghost_slot` / `_build_factory_inventory`)은
  **이제 호출부가 거의 없다** — 마왕 프리뷰·결과 화면이 v1 렌더러를 쓰던 마지막 소비자였다.
  `_build_factory_rail_ghost_slot`은 W6가 "미개방 칸"용으로 남겨 둔 것이라 함부로 지우지 말 것.
- **잔재 부여율**: `enemy.gd`의 8~24% 확률표는 여전히 `enemy.gd` 소유다. 월식이 아닌 평시의
  잔재 부여율을 조정하려면 그 파일을 여는 웨이브가 필요하다.
- W8이 남긴 미결 2건(마왕성 거리 8,628 → 5,600, 성 밀도 9% 상향)은 그대로다.

---

## 9. 알아 둘 함정

1. **`cycle_completed`는 `reload_duration`보다 먼저 온다**(§1.2). 사이클 종료 후의 값을 읽어야 하는
   훅은 시그널이 아니라 다음 프레임의 상태를 봐야 한다.
2. **마왕 레일 밴드는 나침반·고스트 레일과 자리를 공유한다.** `state == "boss"`에서 세 패널의
   `visible`을 `_update_boss_rail()` 한 곳이 전담한다. 다른 데서 `ghost_panel.visible`을 켜면 겹친다.
3. **`_build_preview_slot()`은 읽기 전용이다.** `factory_lane_buttons`에 등록하지 않는다.
   여기에 버튼을 붙이면 편집 화면의 포커스 모델이 프리뷰·결과 화면에서 오작동한다.
4. **월식 표식(`ECLIPSE_META`)이 중복 부여의 유일한 방어선이다.** 스윕은 0.28초마다 전체 마물을
   훑으므로 표식을 지우면 매 스윕마다 체력이 ×1.22씩 곱해진다.
5. **월식은 저장된다.** `eclipse_active`를 스냅샷에서 빼면 이어하기 후 5일차 월식이 통째로
   사라진다(이정표는 다시 울리지 않는다).
6. **HP 배율은 `_begin_boss_battle()` 한 곳에서만 곱한다**(§1.4). 강림 경로에서 다시 곱하지 말 것.
7. **프리뷰의 각인 이름 공개는 `spy_revealed`가 게이트다.** 내 레일은 항상 공개(`reveal=true`),
   마왕 레일은 밀정을 산 런에서만 공개된다.
8. **결과 화면의 각성 이름은 `tier1_name` / `tier2_name`이다.** `ClassLibrary`에 `name` 키는 없다.
9. **한글 라벨에 마크다운을 쓰지 말 것**(handoff-w6 §9-5). 이번에도 프리뷰 부제에서 한 번 밟았다.
