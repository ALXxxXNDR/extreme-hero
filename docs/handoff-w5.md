# W5 인수인계 — 필드 HUD (5칸 상시 레일)

> 작성: W5 구현 웨이브 / 2026-08-07
> 수정한 파일: `godot-game/scripts/game.gd` · `godot-game/scripts/test/test_runner.gd` · `godot-game/scripts/test/run_all.sh`
> 보존: 이전 필드 HUD 전량을 `docs/v1-archive/field_hud_v1.gd.txt`에 복사해 뒀다(부록 C-2).
> 규칙 파일(`core/rune_engine.gd` · `factory_deck.gd` · `deal_cycle_controller.gd` · `core/combat_resolver.gd` ·
> 라이브러리 3종)은 **한 줄도 고치지 않았다**. HUD는 전부 조회·시그널 구독뿐이다.

---

## 1. 최종 레이아웃 (1280×720 절대 좌표, 겹침 0)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ [신상 16,10 330×132] [기한 358,10 440×96] [나침반 806,10 198×96] [마왕 1012,10 252×96] │ y 10~142
│                                                                              │
│              [보스 체력 356,116 568×70]   [배너 230,148 820×58]               │
│                                                                              │
│                            ( 게 임 필 드 )                                   │
│                                                                              │
│                    [상호작용 안내 340,486 600×42]                             │
│                    [흐름 델타 배너 216,532 1048×22]                           │
│ ┌── 레일 밴드 216,556 1048×156 ──────────────────────────────────────────┐    │
│ │ 머리말 / 빚·예상 RELOAD                                                │    │ 로컬 y 2~20
│ │             ▼ 바늘                                                     │    │ 로컬 y 20~32
│ │ [칸1][칸2][칸3][칸4][칸5]        [과열 8단]  [과열 배율·다이얼·상태]     │    │ 로컬 y 34~138
│ │ ━━━━━━━ 빚 게이지 ━━━━━━━                                              │    │ 로컬 y 140~150
│ └────────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

| 요소 | 좌표(전역) | 상수 |
|---|---|---|
| 신상(체력·보호막·자금·전과·**경험**) | `16,10 330×132` | `HUD_VITALS_RECT` |
| 기한 패널 | `358,10 440×96` | `HUD_DEADLINE_RECT` |
| 나침반(마왕성 + 균열) | `806,10 198×96` | `HUD_COMPASS_RECT` |
| 마왕 고스트 레일 | `1012,10 252×96` (칸 44×32, pitch 46) | `HUD_GHOST_RECT` / `HUD_GHOST_SLOT` |
| 보스 체력 | `356,116 568×70` | `HUD_BOSS_PANEL` |
| 상호작용 안내 | `340,486 600×42` | `HUD_INTERACT_RECT` |
| 흐름 델타 배너 | `216,532 1048×22` | `HUD_FLOW_BANNER` |
| **레일 밴드** | `216,556 1048×156` | `RAIL_BAND_RECT` |
| 5칸 | 밴드 로컬 `20,34`부터 `152×104`, 간격 12 → 전역 `236~1044` | `RAIL_SLOT_*` |
| 바늘 | 활성 칸 중앙, 밴드 로컬 y 20, 20×12 삼각 | `RAIL_NEEDLE_*` |
| 과열 온도계 | 밴드 로컬 `846,20 46×118` → 전역 `1062~1108` | `RAIL_HEAT_RECT` |
| 정보 열(과열 배율·다이얼·상태) | 밴드 로컬 `902,20 126×132` → 전역 `1118~1244` | `RAIL_INFO_RECT` |
| 빚 게이지 | 밴드 로컬 `20,140 808×10` | `RAIL_DEBT_TRACK` |

가로 증명: `16 + 330 + 12 + 440 + 8 + 198 + 8 + 252 + 16 = 1280`.
레일 증명: `20 + 152×5 + 12×4 = 828` → 온도계 `846~892` → 정보 열 `902~1028` → 밴드 폭 `1048`.
**5칸이 구조적으로 스크롤 불가**임을 `--cycle-test`의 `hud_rail` 플래그가 자동 검증한다.

---

## 2. 신설 표시 요소

### 2.1 5칸 레일 (칸 152×104)
- 카드 아이콘 40px · 카드 이름(말줄임) · `R랭크 원소마크` · **각인 배지 3핍 + 초과 `+N`**
- 각인 핍 색 = 희귀도(common 금 / rare 청 / epic 자주). `RuneEngine.RUNES[id].rarity`에서 나온다.
- `각인 N` 태그, 재진입 중이면 `재실행 ↺n`으로 바뀐다.
- 칸 하단 4px 진행 게이지 = `group_elapsed / group_duration` (활성 칸만).
- 활성 칸은 테두리 2px + 밝은 배경. **RELOAD 중에는 5칸 전체가 청색으로 식는다**(§8.1).

### 2.2 바늘과 흐름 델타
- 바늘 = 활성 칸 위 삼각 마커. **보간하지 않고 위치만 점프한다**(회귀·도약이 튀는 것이 곧 정보).
- 흐름 각인이 발동하면 다음 스텝 진입 시 배너 1회 + 해당 칸 0.45초 강조. 3계열이 색·문구로 구분된다.

| 계열 | 각인 | 색 | 배너 예 |
|---|---|---|---|
| 회귀 | `rewind_1` `rewind_2` `reverse` | CYAN | `회귀 · 되감기   칸 4 → 칸 3` |
| 도약 | `skip_1` `bookmark` | GREEN | `도약   칸 2 → 칸 4` |
| 재실행 | `repeat` `kill_repeat` `echo` | ORANGE | `재실행 · 앙코르   칸 3 → 칸 3` / `재실행 · 칸 3 를 3번째로` |

- 그 밖의 각인은 배너 없이 해당 칸만 노란 펄스 1회.
- **과부하**(`overloaded()`) 시 5칸 전부 붉은 강조 + 배너 + 정보 열 상태 `과부하`. v1에서 비어 있던 자리다.
- **Tween을 하나도 쓰지 않는다.** 모든 강조는 `_decay_rail_flashes(delta)`의 float 감쇠다
  (사용자가 온보딩 애니메이션을 싫어했다는 기록 반영 · 모달/일시정지에서 새는 트윈이 없다).

### 2.3 과열 · 빚
- 온도계 8단(`RuneEngine.HEAT_MAX`). 아래→위로 채워지고 색은 **청 → 금 → 적**.
  미달 구간도 같은 색의 어두운 유령으로 남겨 8단 전체가 항상 판독된다.
- 정보 열: `과열 4 / 8` · `피해 ×1.48 · R ×1.72`(= `heat_damage_bonus()` / `heat_reload_bonus()`)
- 다이얼(`CycleSweepGauge`): 평상시 = 이 스텝 진행 / RELOAD 중 = 남은 대기(주황).
- 머리말 오른쪽: `빚 1.35초 · 청산 시 RELOAD 2.32초` (`reload_debt` / `projected_reload()`).
- 빚 게이지: `projected_reload() / RuneEngine.RELOAD_CAP`. `RELOAD_CAP × 0.6` 초과면 빨강.
  RELOAD 중에는 잔여 시간 게이지로 전환.

### 2.4 기한 패널 (W4 임시 2줄 → 정식 패널)
`3일차 · 낮` / `잔여 5일` / 7일 핍(지난 날 어두운 금, 오늘 금·밤은 적) / 하루 진행 바 /
`낮 41초 · 기한 09:13` / `다음 4일차 · 두 번째 균열`.
전부 `DeadlineClock` 조회다 — `day_number` `days_left()` `phase_ratio()` `phase_remaining()`
`run_remaining()` `milestone_for(day)`. 이정표 짧은 이름 표는 `game.gd`의 `MILESTONE_SHORT`.

### 2.5 나침반
- `마왕성 ↗ · 아주 희미함` (v1 유지)
- `균열 ↗ · 103m` + `남은 개설 2 / 3` — `world.get_rift_compass(player.global_position)` /
  `world.rift_budget_remaining()`. 균열이 없으면 `균열 없음`으로 떨어진다(크래시 없음).

### 2.6 마왕 고스트 레일 (§6.3)
- 우상단 5칸(44×32) 실루엣 아이콘 + 각인 개수 배지 + 칸 번호.
- `각인 4 / 12` · `받은 카드 8 · 잔재 2 · HP ×1.44`.
- 데이터는 `demon_lord.ranked_cards()` / `rune_count_on_slot(i)` / `rune_count()` / `rune_capacity()` /
  `received_card_count()` / `hp_multiplier(day)`.
- **카드를 버릴 때 해당 칸 1회 강조**: 토스트 경로(W6 소유)에 훅을 박지 않고
  `_update_ghost_rail()`이 **칸 구성 변화를 관측**해 강조한다 → 레벨업·2장 포기·상자·상점 등
  모든 버림 경로를 한 곳에서 덮는다. 강조는 1.1초 감쇠 1회성(루프 없음).

---

## 3. 제거한 v1 잔재

| 제거물 | 대체 |
|---|---|
| 딜싸이클 3칩 HUD(`cycle_chip_previous/current/next`, `_build_cycle_chip`, `_apply_cycle_chip`) | 5칸 레일. **5칸 중 3칸만 보이던 구조가 v2 요구와 정면 충돌** |
| RELOAD 되감기 릴 7칩 스크롤(`_build_cycle_rewind_reel` `_build_cycle_rewind_chip` `_apply_cycle_rewind_chip` `_set_cycle_rewind_visible` `_update_cycle_rewind` `cycle_rewind_streak` 등) | RELOAD 중 **레일 전체 청색 냉각 + 다이얼 카운트다운 + 빚 게이지 역주행**. 스크롤 루프 애니메이션 폐기 |
| `CYCLE_HUD_RECT` `CYCLE_CHIP_*` `CYCLE_REWIND_*` `CYCLE_HUD_BAR_W` 등 상수 12개 | `RAIL_*` / `HUD_*` |
| `_update_deal_cycle_hud()`의 임시 2줄 표기 | `_update_rail_text()` |
| `trophy_text` "시련 구슬 0 / 4" 패널 줄 | 삭제(시련 캠프 폐기 §7.2). `player.trophy_orbs` 자체는 W9 각성 게이트가 아직 쓰므로 **데이터는 그대로** |
| 화면 하단 경험치 패널(`HUD_XP_PANEL` 334,652 612×52) | 신상 패널 하단으로 흡수. **레일이 그 자리를 쓴다** |
| `_cycle_slot_lead_card()` | `factory.get_card(i)` 직접 호출 |

`CycleSweepGauge` 클래스 하나만 살려 레일 정보 열의 다이얼로 승격했다.

---

## 4. 고친 잠복 버그 2건

1. **`CycleSweepGauge` 삼각분할 실패** — `ratio == 1.0`이면 부채꼴 폴리곤의 첫 점과 끝 점이 겹쳐
   `draw_colored_polygon`이 매 프레임 `ERROR: Invalid polygon data`를 뿜었다. v1에서는 다이얼이
   RELOAD 중에만 살아 있어(ratio가 1.0에 머무는 프레임이 없어) 드러나지 않았다.
   → 부채꼴은 0.998까지만 채운다. 링 자체는 전체 비율로 그린다.
2. **성 입장 시 필드 HUD가 남는다** — `_process`의 `castle_interior` 분기가 W5 구역보다 먼저
   `return` 하므로 매 프레임 갱신이 돌지 않는다. v1의 3칩 패널도 같은 결함이 있었다.
   → `_update_hud()`가 `inside_castle`이면 레일을 끄고, `_enter_castle_now()`에 `_update_hud()` 1줄 추가.

---

## 5. ⚠️ 소유권 경계 접촉 (보고 대상)

| 위치 | 소유 | 내용 | 판단 |
|---|---|---|---|
| `_enter_castle_now()` | W9 | `_update_hud()` **1줄 추가** | 위 §4-2. 성 화면 위에 필드 레일이 겹치는 회귀를 막는 최소 수정이며 성 로직은 무변경 |
| `boss_panel` 좌표 `(340,112,600×70)` → `(356,116,568×70)` | HUD 구축 = **W5 소유**(§7.3) | 좌상단 신상 패널이 132px로 커지며 6px 겹쳤다 | 경계 내. W10은 `boss_panel`/`boss_fill`/`boss_text` 이름을 그대로 쓰면 된다 |
| `interaction_text` `(340,518)` → `(340,486)` | W8/W9가 텍스트만 쓴다 | 흐름 배너(y 532~554) 자리 확보 | 경계 내(좌표는 `_build_ui` = W5) |
| `test_runner.gd` `_run_v4_test`의 `castle_input_ok` | W0 | 레일 가시성 단언 3개 추가 | 지시서가 test_runner를 W5에 위임 |

**하지 않은 것**: `_begin_run` / `_reset_player_cycle` / `_show_boss_growth_toast` / 온보딩 /
ESC 편집 화면 / 마왕 프리뷰·결과 화면 / 상점 — 전부 무수정.

---

## 6. 다음 웨이브가 쓸 것

### W6 (편집 화면 · 드래프트)
```gdscript
# 레일 렌더러는 필드 HUD 전용이다. 편집 화면(196×150)은 _paint_card_block을 그대로 쓰면 된다.
# 다만 각인 배지 3핍 + "+N" 규칙은 아래 두 함수의 공식을 그대로 복제할 것 — 두 화면의
# "각인이 몇 개 박혀 있나"가 다르게 보이면 안 된다.
game._rune_rarity_color(rune_id) -> Color     # common 금 / rare 청 / epic 자주
RuneEngine.RUNE_SLOTS_PER_SLOT                # 핍 3개, 초과분은 "+N"
game._heat_color(step) -> Color               # 과열 단계 색 (청→금→적). 흐름 아크 색에도 재사용 가능
game._rail_kind_color(kind) / _rail_kind_label(kind)   # 회귀 CYAN / 도약 GREEN / 재실행 ORANGE
game.RAIL_FLOW_KIND                           # 각인 id → 3계열 매핑
```
- **흐름 아크(§8.2)의 색은 위 3색을 그대로 써라.** 필드에서 배운 색 언어가 편집 화면에서 뒤집히면
  안 된다.
- `interaction_text`가 y 486으로 올라갔고 흐름 배너가 y 532~554를 쓴다. 편집 화면은 전체 모달이라
  영향 없지만, 필드 위에 뭔가 더 얹을 계획이면 **y 486~712는 이미 W5가 쓰고 있다**.
- ESC 편집 화면은 이번 웨이브에서 손대지 않았고 `--capture-factory` 육안 회귀 없음.

### W11 (Ninja Adventure 테마 교체)
스프라이트만 갈아끼울 수 있게 그리기 책임을 분리해 뒀다.

| 함수 / 클래스 | 역할 | W11이 할 일 |
|---|---|---|
| `_build_rail_slot(index)` | 칸 골격(노드 이름 `Icon` `Number` `Name` `Rank` `Pip0~2` `Overflow` `Tag` `Track/Fill`) | `Icon`(PixelSkillIcon 40×40)만 스프라이트로 교체 |
| `_apply_rail_slot_content(index)` | 데이터 → 노드 텍스트/색 | 무수정 |
| `_apply_rail_slot_styles(active, reloading)` | 테두리·배경·강조·RELOAD 냉각 | 9-slice 프레임을 쓰려면 여기 한 곳만 |
| `class RailMarker` | 바늘 삼각 마커 `_draw()` | 스프라이트로 교체 가능(색은 `color` 프로퍼티) |
| `class CycleSweepGauge` | 원형 스윕 다이얼 `_draw()` | 유지 권장(절차적) |
| `_build_ghost_rail()` / `_update_ghost_rail()` | 마왕 5칸 미니(44×32) | `Icon` 24×24 교체 |
| `_heat_color(step)` | 과열 색 램프 | 팔레트 교체 시 여기 한 줄 |

- HUD 좌표는 §1의 `HUD_*` / `RAIL_*` 상수 블록 한 곳에 모여 있다. 스프라이트 크기가 바뀌면
  그 블록만 고치면 `_build_ui` / `_update_hud` 계산이 전부 따라 움직인다.
- 폰트 교체 시 주의할 최소 폭: 칸 이름 88px(말줄임 on) · `과열 4 / 8` 126px ·
  `다음 4일차 · 두 번째 균열` 176px · `빚 1.35초 · 청산 시 RELOAD 2.32초` 380px.

### W4 / W9 — **아직 안 붙은 훅 1건 (오케스트레이터 판단 요망)**
`world.begin_run_rifts()` / `spawn_rift_near()`가 **game.gd 어디에도 호출되지 않는다**
(handoff-w8 §3.1이 W4 몫으로 지정한 2줄). 그래서 실기 플레이에서 나침반은 항상 `균열 없음`이다.
HUD는 조회만 하는 게 맞다고 판단해 **개설 훅을 넣지 않았다.** W4 후속이나 W9가
`_begin_run()`에 `world.begin_run_rifts(run_cycle_seed)` 1줄, 2·4·6일차 낮 진입에
`world.spawn_rift_near(player.global_position)`을 붙이면 나침반이 즉시 살아난다.
(`--capture-hud`는 검수를 위해 캡처 루틴 안에서 직접 균열을 연다.)

### W7 — 원소 태그
칸의 `R2 화` 표기는 `RuneEngine.slot_element(slot)` = 카드의 `element` 키를 읽는다.
현재 카드 데이터에 `element`가 없어 마크가 비어 있다. W7이 태그를 넣으면 자동으로 뜬다
(매핑 표는 `game.gd`의 `RAIL_ELEMENT_MARK`).

### W10 — 마왕전
- 고스트 레일은 **마왕 성장 상태**(`demon_lord`)를 그린다. 보스전 중 마왕의 **실시간 과열·바늘**은
  아직 화면이 없다 — `boss_cycle`의 같은 시그널(`heat_changed` `slot_entered`)에 붙이면 되고,
  `_build_ghost_rail` / `_update_ghost_rail`을 복제해 `boss_factory.rune_count_on(i)`를 읽으면 된다.
- `boss_panel`은 `HUD_BOSS_PANEL` 상수로 옮겼다(좌표 변경). 노드 이름·시그니처는 그대로.
- 결과 화면(`--capture-result`) 회귀 없음.

---

## 7. 테스트 · 캡처

### 7.1 `--cycle-test`에 플래그 2개 추가
```
CYCLE_TEST_COMPLETE ... hud_rail=true hud_ghost=true ...
```

| 플래그 | 검사 내용 |
|---|---|
| `hud_rail` | 레일이 칸 5개를 만들었다 · 온도계가 `HEAT_MAX`(8)단이다 · 바늘의 `slot_index` meta == `player_cycle.current_index` · 바늘 x좌표 == 그 칸의 중심 · **5칸 전부가 밴드 폭 안에 들어온다**(가로 스크롤 구조적 불가) · 칸 패널의 `rune_count` meta == `factory.rune_count_on(i)` |
| `hud_ghost` | 고스트 5칸의 `card_id`/`rune_count` meta == `demon_lord.slot_layout()` / `rune_count_on_slot(i)` · 총 각인 수가 라벨에 반영 |

`--v4-test`의 `physical_e`(castle_input) 플래그에 **레일 가시성 3단**(필드 켜짐 → 성 꺼짐 → 복귀 켜짐)을 추가했다.

### 7.2 `--capture-hud` 신설
```bash
godot --path godot-game -- --capture-hud
bash godot-game/scripts/test/run_all.sh --captures            # 전체 캡처
bash godot-game/scripts/test/run_all.sh --captures --capture-hud
```
한 번에 4장을 저장한다. 5칸을 카드 4장 + 각인 1/2/4개(초과 `+1`)로 채우고, 마왕에게 카드 8장 ·
아이템 3개를 넘기고, 균열 1개를 연 상태다.

| 파일 | 상태 |
|---|---|
| `hud-minimal-v2-day.png` | 3일차 낮 · 실행 중 · 과열 4 · **회귀(CYAN)** 흐름 배너 |
| `hud-minimal-v2-night.png` | 3일차 밤 · 과열 7 · **재실행(ORANGE)** · 빚 게이지 적색 |
| `hud-minimal-v2-reload.png` | RELOAD 1.42초 · **5칸 전체 청색 냉각** · 바늘 숨김 |
| `hud-minimal-v2.png` | 대표 컷(낮) · **도약(GREEN)** 흐름 배너 |

`--capture-world`는 이제 **HUD 없는 순수 월드**다(배너까지 걷어낸다). 두 캡처의 역할이 갈렸다.

### 7.3 결과 (2026-08-07)

| 결과 | 검사 |
|---|---|
| PASS | compile (`--editor --quit`) 오류 0 |
| PASS | world-test · v4-test · v4-castle-test · stress-test · smoke-test · combat-test · deadline-test · **cycle-test(hud_rail·hud_ghost 포함)** |

비headless 육안 검수: 4컷 전부 5칸 레일·바늘·각인 배지·과열 8단·빚 게이지·기한 패널·
균열 나침반·마왕 고스트 레일이 판독 가능하고 1280×720 안에서 겹침·잘림 0.
`--capture-factory` / `--capture-result` / `--capture-boss` 회귀 없음.

---

## 8. 알아 둘 함정

1. **레일은 `_process`의 W5 구역에서 매 프레임 갱신된다.** 텍스트는 `_update_hud`(10Hz),
   위치·게이지·강조 감쇠는 `_update_cycle_rail(delta)`(매 프레임)로 나뉘어 있다. 프레임 순서를 바꾸지 말 것.
2. **스타일박스는 값이 실제로 바뀔 때만 만든다.** `slot.get_meta("style_key")` 비교가 그 방어선이다.
   여기를 지우면 초당 60 × 5개의 `StyleBoxFlat`이 생긴다.
3. **시그널은 지연 연결이다.** `_bind_rail_signals()`가 매 프레임 "지금 붙은 컨트롤러가 바뀌었나"만 본다.
   `_begin_run` / `_reset_player_cycle`(W4·W6 구역)을 건드리지 않으려고 이렇게 했다.
   컨트롤러를 새로 만드는 코드는 아무것도 할 필요가 없다.
4. **흐름 배너 문구는 두 시그널을 조합해 만든다.** `rune_fired`(발동)에서 예약하고
   `slot_entered`(이동 결과)에서 확정한다. 흐름 각인은 **다음 스텝**의 바늘 위치를 바꾸기 때문이다.
5. **확정(패시브) 각인은 `step.fired`에 없다**(handoff-w2 §9-2). 그래서 배너에 뜨지 않는다.
   그쪽은 칸의 각인 배지가 상시로 보여 준다 — 배너에 넣으려 하지 말 것.
6. `--capture-hud`는 `player_cycle.heat` / `reloading` 등을 **표시 확인용으로 직접 대입**한다.
   캡처 하네스 한정이며 게임 규칙 경로가 아니다. 컷 사이에 `_update_cycle_rail(4.0)`을 한 번
   돌려 직전 컷의 강조를 씻어낸다(delta 0으로 그리면 감쇠가 멈추기 때문).
7. `trophy_text`를 지웠다. `player.trophy_orbs` 데이터는 살아 있으니 W9가 각성 조건을
   이정표로 교체할 때 필요하면 새 표시를 만들면 된다.
