# handoff-y2 — 과열 제거 + 각인 15종 런타임 완결 (`game.gd` 직렬 체인 1/6)

2026-08-09 · 웨이브 **Y2** · 근거 `docs/FEEDBACK_Y.md` §1.2·§1.4·§2.2·§2.5·§9.3 ·
`docs/handoff-y1.md` §9-A(최우선 3건)·§9-D

수정 파일 6개 — `scripts/game.gd` · `scripts/deal_cycle_controller.gd` ·
`scripts/cycle_skill_effect.gd` · `scripts/test/test_runner.gd` · `docs/handoff-y2.md`(이 문서)
(`run_all.sh`는 **손대지 않았다** — 목록·판정 규약이 그대로 맞았다)

**한 줄도 안 건드린 것**: `core/rune_engine.gd` · `core/tuning.gd` · `core/status_engine.gd` ·
`core/combat_resolver.gd` · `core/demon_lord.gd` · `deal_card_library.gd` · `monster_library.gd` ·
`factory_deck.gd` · `boss_library.gd` · `enemy.gd` · `world_grid.gd` · `player.gd` · `ui/ui_kit.gd` ·
`test/rune_test.gd` · `test/data_test.gd` · `test/status_test.gd` · `test/balance_probe.gd` ·
`art/` 전부 · `AGENTS.md`. git 커밋 0건. `docs/v1-archive/deal_cycle_controller.gd.txt` 보존.

---

## 0. 한 문장

**과열의 마지막 소비자 60지점을 게임 코드에서 걷어내고 그 자리에 「한 칸은 한 바퀴에
두 번까지」를 그림으로 세웠다. 그리고 Y1이 남긴 최우선 3건 — 레일 각인 미주입 ·
`twin_cast` 미발사 · 레일 각인이 칸 3택1에 죽은 선택지로 등장 — 을 전부 막고
계획 = 실제 등가를 테스트로 못 박았다. `run_all.sh` 15/15 PASS.**

---

## 1. 검증 결과 (전부 이 웨이브가 직접 실행)

| 검사 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | **오류 0 · 종료 코드 0** |
| `bash godot-game/scripts/test/run_all.sh` | **15 / 15 PASS**(compile 포함 16행 전부 PASS) |
| `-s res://scripts/test/rune_test.gd` | **PASS** · 35판정 전건 `=true` · 무접촉 |
| `-s res://scripts/test/data_test.gd` | **PASS** · 32판정 전건 `=true` · 무접촉 |
| `--status-test` | **PASS** · 무접촉 |
| `--capture-hud` (비headless 6컷) | 밟은 횟수 점 육안 확인 · 과열 8핍 소멸 · 지문 6컷 전부 상이 |
| `--capture-rail` (4컷) | 레일 각인 글리프 줄 육안 확인(노랑=일반 · 자주=영웅 · 유령 1칸) |
| `--capture-boss` `--capture-draft` `--capture-result` `--capture-onboarding` | 과열 잔재 0 육안 확인 |
| 음성 대조 3건 | §5 참조 — 세 수리를 되돌리면 각각 정확히 그 플래그만 빨개진다 |

### 1.1 `run_all.sh` 15종 현황표

| 검사 | 이전(Y1 직후) | **지금** | 비고 |
|---|---|---|---|
| compile | PASS | **PASS** | |
| `--world-test` | PASS | **PASS** | 무접촉 |
| `--v4-test` | FAIL(`slot_swap` `rune_stack` `two_gesture`) | **PASS** | 폐기 각인 id 3곳 → 신 id · 레일 거부 계약 2줄 신설 |
| `--castle-test` | FAIL(`rune_shop`) | **PASS** | 흐름 할증 탐침 재작성(§4.3) · 칸 각인 진열분 구매 |
| `--rift-test` | FAIL(`reward`) | **PASS** | 각인 보상 3택의 칸/레일 분기 |
| `--stress-test` | PASS | **PASS** | 무접촉 |
| `--smoke-test` | PASS | **PASS** | 무접촉 |
| `--combat-test` | PASS | **PASS** | 무접촉 |
| `--stage-test` | FAIL(`curve` `reward_decay`) | **PASS** | dwell 곡선 9행 신값 · 효율 9행 신값 · **DWELL 불변식 교체**(§4.2) |
| `--status-test` | PASS | **PASS** | 무접촉 |
| `--cycle-test` | FAIL(5플래그) | **PASS** | **전면 재작성**(§3) |
| `--draft-test` | FAIL(`stack_cap` `flow_suppress`) | **PASS** | 폐기 id + 칸/레일 분기 헬퍼 3종 신설 |
| `--boss-test` | PASS | **PASS** | `carry_load` 참조 1곳 → 레일 opts · 과열 사다리 단언 2곳 → 머리말 문구 |
| `--save-test` | PASS | **PASS** | **지문 축 `rail_runes` 신설** · `peak_heat` → `peak_steps` |
| `--guide-test` | PASS | **PASS** | 온보딩 `diet` 계약(페이지 ≤360자 · 줄 ≤32자) 유지 확인 |

**남은 실패 0건.**

---

## 2. 과열 소비자 제거 — 60지점

「`heat`·`과열` grep 0건」 계약을 **주석을 제외한 전 코드 줄**에서 달성했다:

```
game.gd                    비주석 매치 0줄 (주석 15줄 — 전부 "무엇이 왜 사라졌나" 이력)
deal_cycle_controller.gd   비주석 매치 0줄 (주석 6줄)
cycle_skill_effect.gd      비주석 매치 0줄 (주석 1줄)
```

### 2.1 `deal_cycle_controller.gd` — 13지점

| # | 제거·교체 | 후임 |
|---|---|---|
| 1 | `signal heat_changed(heat)` | **`signal exec_changed(slot_index, executed)`** |
| 2 | `signal cycle_completed(steps, max_heat)` | 2번째 인자 의미 교체 → `exec_peak`(1~2) |
| 3 | `var heat` | 삭제 |
| 4 | `var carry_load`(잔열) | 삭제 |
| 5 | `var peak_heat` | **`var peak_exec`** |
| 6 | — | **신설 `var exec_counts: Array[int]`** (칸별 밟은 횟수) |
| 7 | `_plan_cycle()` `opts["start_load"]` | 삭제 + **`opts.merge(factory.rune_opts())`**(수리 ①) |
| 8 | `_start_current_step()` `step["heat"]` 읽기·emit·peak | `exec_counts[cursor] = reentry + 1` + `exec_changed` |
| 9 | `_launch_card()` `card["heat"] = heat` | 삭제(카드 사전에서 키 소멸) |
| 10 | `_finish_cycle()` `peak_heat`·`carry_heat`·heat emit | `plan["slot_exec"]`로 `peak_exec` 확정 |
| 11 | `heat_damage_bonus()` | 삭제 |
| 12 | `heat_reload_bonus()` | 삭제 |
| 13 | `projected_reload()`의 `(1 + heat × HEAT_RELOAD)` | **`빚 × reload_scale`**(선형 · §1.4) |

**신설 조회 2종**: `exec_count(index) -> int` · `executed_slot_count() -> int`.

### 2.2 `game.gd` — 43지점 (묶음별)

| 묶음 | 지점 | 무엇 |
|---|---|---|
| 마왕 레일 밴드 | 11 | `boss_rail_heat_cells`·`BOSS_RAIL_HEAT_RECT` 삭제 · 8단 사다리 빌드/갱신 루프 삭제 · `boss_rail_heat_text` → **`boss_rail_meter_text`**(「밟은 칸 N / 5 · 한 칸 최대 N번」) · 바늘·칸 강조색 `_heat_color` → 되밟기색 · RELOAD 창 색 기준 · `boss_peak_heat` → `boss_peak_steps` · `_on_boss_cycle_completed` 시그니처 |
| 미니 스트립 | 9 | `rail_heat_segments`·`RAIL_HEAT_RECT`·`RAIL_HEAT_SEGMENT_*` 삭제 · `_build_rail_heat_column()` 삭제 · `_update_rail_text()` 8핍 루프 삭제 · `HEAT_GATE_MIN` 기반 바늘/진행바 색 → 되밟기 · `_heat_color()` **함수 삭제** · 스트립 폭 380 → **358**(§2.3) |
| 편집 미리보기 | 6 | `mean_heat`·`heat_histogram`·`peak_heat`·`overloaded` 소비 → **`mean_exec_slots`·`step_histogram`** · 지표 툴팁 「평균 최고 과열」·「과열 분포」 → 「밟은 칸」·「한 바퀴 분포」 · `_factory_deck_signature()`에 레일 각인 축 가산 |
| 결속·삼각 | 3 | `bond_mask()`·`triangle_ok()`·`BOND_FIRE_COST`·`TRIANGLE_RELOAD_DISCOUNT` 소비 전량 삭제 → `EDIT_BOND_RECT` 자리를 **레일 각인 글리프 줄**로(§2.4) |
| 각인 화면 | 3 | 「확정 발동 · 과열을 올리지 않음」 → 「굴리지 않는다」 · 2단계 Δ 「최고 과열」 → 「밟은 칸」 · 1단계 꼬리말 |
| 런 기록·결과 | 5 | `run_peak_heat` → **`run_peak_steps`** · `_track_run_peak_heat` 개명 · `_on_run_cycle_completed` · 결과 칩 「최고 과열」 → **「한 바퀴 최다 칸」 `%d / 10`** · 마왕 프리뷰 대조표 |
| HUD 툴팁 | 3 | `rail_heat` 대상 등록 삭제 · `_rail_heat_tooltip_spec()` **함수 삭제** · 스트립 툴팁 「과열」 행 → 「밟은 칸」+「이 칸 N / 2번」 |
| 문구(사용자 노출) | 8 | 보스 체력바 리듬 줄 · 스테이지 보스 프리뷰 부제 2곳 · 마왕 프리뷰 헤더·부제 · 마왕 개전 배너 · 길잡이 스텝 「과열과 빚을 봅니다」 · 온보딩 2p 제목 |
| 온보딩 | 4 | 2p 과열 8단 온도계 → **밟은 횟수 2단**(§2.5) · 「과열이 높으면 더 길어집니다」 · 흐름 캡션 3줄 신 각인 이름 · 3p 「잔열」 각인 → 「빨리 감기」 |
| 저장 | 1 | 스냅샷 키 `run_peak_heat` → `run_peak_steps`(저장·복원 양쪽) |

### 2.3 스트립 폭 380 → 358 (「HUD 과열 자리 처리」)

과열 8핍이 쓰던 좌측 20px(`RAIL_HEAT_RECT = (2,14,20,48)`)를 **빈 자리로 남기지 않고
스트립을 통째로 22px 좁혔다.** X3의 탈블록 방향과 같은 처방이다 — 필드를 그만큼 덜 가린다.

```
구: RAIL_BAND_RECT (450, 636, 380, 74)   2 |20 과열| 8 |30 … 330| 2 |44 다이얼| 4
신: RAIL_BAND_RECT (461, 636, 358, 74)   8 |8 … 308 (52×5 + 10×4)| 2 |44 다이얼| 4
    RAIL_SLOT_ORIGIN (8,12) · RAIL_DIAL_RECT (310,14,44,44) · RAIL_DEBT_TRACK (8,66,300,4)
```
가로 중심은 640 그대로다(461 + 179 = 640). 세로 74는 **무변경**(`strip_h=74` 계약 유지).
`_guide_target_rect("rail_gauges")`가 병합하던 heat 사각형은 **칸 5개 사각형**으로 갈아끼웠다.

### 2.4 편집 화면 — 결속 띠 → 레일 각인 글리프 줄 (§2.5)

`EDIT_BOND_RECT (42,342,1156,8)` 자리에 **22×8 칩 3개**(= `RAIL_RUNE_CAP`)를 깐다.
붙은 각인은 희귀도 색, 빈 자리는 유령. 호버 툴팁이 이름·효과·공명 규칙·「한 칸 두 번」을 말한다.
`RuneEngine.bond_mask()`·`triangle_ok()` 호출은 게임 코드에서 **0건**이 됐다.

### 2.5 온보딩 2페이지 — 과열 8단 → 밟은 횟수 2단

같은 자리·같은 상자에 2단 막대(1=노랑 / 2=주황)와 캡션 「두 번이면 건너뜁니다」.
흐름 캡션 3줄은 폐기 각인 이름(되감기/도약/재실행)에서 실제 각인 이름으로 갈았다:
**「한 칸 뒤로 −1칸」 · 「한 칸 건너뛰기 +2칸」 · 「두 번 치기 같은 칸 한 번 더」**.
`--guide-test`의 `diet` 계약(페이지 ≤360자 · 한 줄 ≤32자 · 규칙 ≤2줄)은 그대로 통과한다
— 새 문구가 전부 옛 문구보다 짧거나 같다.

---

## 3. 각인 런타임 수리 3건 — 계획 = 실제

### ① 레일 각인 주입 (`deal_cycle_controller.gd:_plan_cycle`)

```gdscript
var opts: Dictionary = {"reload_scale": reload_scale}
opts.merge(factory.rune_opts())      # ← 이 한 줄이 레일 각인 5종을 살린다
```
같은 배선을 **미리보기 3경로**에도 넣었다(안 넣으면 "미리보기 = 실전"이 깨진다):
`_refresh_factory_preview()` · `_rune_target_projection()` · `_factory_deck_signature()`
(지문에 레일 각인을 안 넣으면 각인을 붙여도 미리보기가 **캐시에 걸려 갱신되지 않는다**).

**등가 수치** — 같은 덱·같은 시드(`--cycle-test ④ rail_rune`):

| 대조 | 결과 |
|---|---|
| 런타임 `plan`의 궤적 지문 vs `rune_opts()`를 실은 시뮬레이션 | **완전 일치** |
| 레일 각인 있음 vs 없음 궤적 지문 | **불일치**(= 실제로 궤적을 바꾼다) · `damage_total` 증가 |
| `rail_rest` RELOAD | 빚 2.42초 → **1.936초 = 2.42 × (1 − 0.20)** 정확 일치 |
| 5종 축 개별 발동 | `rail_fast` 지속↓ · `rail_power` 피해↑ · `rail_rest` RELOAD↓ · `rail_color` 레일 해석 진입 · `rail_loop` 무장 시 스텝↑ — **5/5** |

> `rail_color`만 판정이 다르다. 공명이 없는 덱에서는 가산되지 않는 것이 **정상 계약**이라
> (§2.2 "공명이 성립한 칸에만") "붙어도 안 터진다"가 아니라 "레일 해석에 들어왔다"를 본다.

### ② `twin_cast` 발사 경로 복구 (`:234` 구 `"echo"`)

```gdscript
var prev_slot := _previous_step_slot(step_pointer)
if prev_slot >= 0 and _rolled(step, "twin_cast"):
    var twin_power := RuneEngine.passive_magnitude(factory.slots[current_index], "twin_cast")
    if twin_power > 0.0:
        _launch_card(prev_slot, flow, damage_mul * twin_power, step, false)
```

⚠️ **`RuneEngine.TWIN_POWER`(0.5)를 직접 쓰면 안 된다.** 엔진은 `merged_magnitude()`로
사본 감쇠(`DUP_MAG_FALLOFF 0.60`)를 먹인 값을 쓰므로 사본 2개면 0.80이다. 상수를 박으면
사본이 늘어난 순간 다시 계획 > 실제가 된다. `passive_magnitude()`가 **엔진과 같은 식**이다
(이름은 "passive"지만 구현은 roll 여부를 안 보고 그 id의 합성 크기만 돌려준다).

**등가 수치**(`--cycle-test ⑩ twin_cast`):

| 대조 | 결과 |
|---|---|
| 엔진 스텝 피해 vs `여기 기저 × 배율 + 앞칸 기저 × 배율 × twin_power` | 400시드 · **twin 발동 299스텝 전건** 오차 < 0.0005 |
| 컨트롤러 실전 발사 수 vs 계획 | 60시드 × 전 스텝 · **불일치 0건** · twin 스텝 44건이 전부 카드 **2장** |

함께 삭제한 죽은 동시 발사 3경로: `link`(항상 −1) · `chorus`(폐기 id) ·
`overlap`(`passive_magnitude` 항상 0.0).

### ③ 칸/레일 부착 대상 분기 — 죽은 선택지 제거 (`game.gd:7303`)

두 겹으로 막았다.

1. **후보에서 배제** — `_roll_rune_draft()`가 `_rail_rune_attachable(id)`로 거른다.
   레일이 꽉 찼거나(`RAIL_RUNE_CAP 3`) 같은 레일 각인을 이미 가졌으면(`RAIL_SAME_ID_CAP 1`)
   후보에 넣지 않는다. 칸 각인은 **거르지 않는다** — 2단계 화면이 칸별로 이미 막고,
   전부 막혔을 때의 출구(`_forfeit_rune_draft`)가 따로 있다.
2. **고른 뒤 즉시 적용** — `_select_draft_rune()`이 `rune_scope == "rail"`이면
   2단계를 건너뛰고 `_commit_rail_rune_draft()`로 간다(미선택분 → 마왕 조각 ·
   사이클 재계획 · 미리보기 갱신 · 배너까지 칸 각인과 **같은 뒷정리**).
   같은 분기를 **세공사 구매**(`_buy_rune_shop_offer`)에도 넣었다.

부수 수리 2건:
- `demon_lord.set_rune_catalog(all_rune_ids())` **2곳**(`:561` `_ready` · `_build_boss_factory`)
  → `ids_by_scope("slot")`. 마왕이 레일 각인을 뽑아 `attach_rune`이 조용히 거부하던
  구멍(handoff-y1 §9-B)이 막혔다. 전조 덱(`:8143`)은 `demon_lord.runes_on_slot()`을 쓰므로
  카탈로그가 고쳐진 순간 함께 낫는다.
- 3택 카드에 **소속 배지**를 넣었다 — 「칸 각인 · 전투」 / 「레일 각인 · 전투」(자주색).
  보유 줄도 레일 각인이면 레일 기준으로 센다(「레일 각인 최대 3개 · 같은 것 1개」).

### ④ 표시 매핑 2종 — 구 id 8종 → 신 id (`game.gd:1845` `:2612`)

```gdscript
const RAIL_FLOW_KIND := {"back_one": "back", "jump_one": "jump", "twice": "again"}
const EDIT_ARC_RUNES := {"back_one": -1, "jump_one": 2, "twice": 0, "trade_skip": 0, "finisher": 0}
```

⚠️ **`EDIT_ARC_RUNES`의 단위는 `RuneEngine.FLOW_DELTA`와 다르다.** 엔진은
`move = 1 + delta`이므로 delta를 그대로 쓰면 아크가 한 칸씩 어긋난다.
변환은 `착지 = 1 + delta`다 — `back_one` delta −2 → **−1칸**, `jump_one` delta +1 → **+2칸**.
확정 각인(`trade_skip`·`finisher`)은 `step.fired`에 안 남으므로 `RAIL_FLOW_KIND`에는
**일부러 없고**, 아크 표에는 앙코르 고리(0)로 들어간다. `rail_loop`는 레일 소유라 둘 다에 없다.

---

## 4. 테스트 재작성

### 4.1 `--cycle-test` 전면 재작성

플래그 이름이 두 개 갈렸다 — `heat_damage` → **`exec_cap`**, `reentry` → **`rail_rune`**,
그리고 **`twin_cast` 신설**. 출력 줄도 새 계측을 싣는다:

```
CYCLE_TEST_COMPLETE five_slot=true flow_rune=true exec_cap=true rail_rune=true
  debt_reload=true slot_swap=true omen=true boss=true bounded=true runtime=true twin_cast=true
  hud_rail=true hud_mini=true hud_nav=true hud_ghost=true strip_h=74
  hud_block_pct=3.28 hud_ink_pct=6.80 cycles=2 steps_seen=20 runes_fired=17
  max_steps=10 max_exec=2 overload_hits=0 twin_seen=299 twin_pairs=44 twin_miss=0 debt=2.42
```

| 묶음 | 무엇을 재나 |
|---|---|
| `exec_cap` | ⓐ 배율이 실제 피해에 실린다(단일 지점 계약 유지) ⓑ 2,000사이클에서 `slot_exec > 2` **0건** · `step_count > 2n` **0건** · `end_reason == "overload"` **0건**(구 「과부하율 0.70%」 대체) · `max_exec == 2` tight ⓒ **두 번째 실행이 첫 실행보다 약하지 않다**(재진입 감쇠 부활 감지) |
| `rail_rune` | §3-① 표 그대로 |
| `debt_reload` | 과열 항 소멸 + 마왕 ×0.6 + `rail_rest` 할인 정확 일치 |
| `bounded` | 최악 덱을 **신 15종**으로 재구성(확정 앙코르 2 + 확률 흐름 3 + 되돌이 레일 · `kill_chance 1.0`). 부착 수를 먼저 세어 "폐기 id로 각인 0개 덱이 되어 통과"를 차단. `max_steps == 10` tight |
| `runtime` | `exec_changed`가 1을 낸다(사이클 리셋) · 실전 봉우리 `== SLOT_EXEC_CAP` |
| `twin_cast` | §3-② 표 그대로 |
| `hud_rail` | 칸마다 `Exec{N}` 점이 정확히 `SLOT_EXEC_CAP`개 · **켜진 개수 == `exec_count()`** |
| `hud_mini` | `rail_heat` 툴팁이 **없다** · 스트립 툴팁 필수 행 「밟은 칸」·「이 칸」 · **금지 어휘 「과열」이 제목·행·본문 어디에도 없다** |

### 4.2 DWELL 불변식 — 오케스트레이터 결정 반영 (`test_runner.gd:3969`)

`DWELL_DAMAGE_LINEAR`는 **0.07 유지**. 단언을 등식에서 **부등식 2개**로 갈았다:

```gdscript
curve_ok = curve_ok and GameTuning.DWELL_DAMAGE_LINEAR < GameTuning.DWELL_HP_LINEAR
curve_ok = curve_ok and GameTuning.DWELL_DAMAGE_LINEAR * 2.0 > GameTuning.DWELL_HP_LINEAR
```
= "피해 기울기는 HP 기울기보다 작지만 절반보다는 크다" → dwell이 깊어질수록 몹이
**상대적으로 더 아파진다**. 체류 압박이 HP 벽이 아닌 형태로 남는다(§5.5 방향과 일치).

dwell 곡선 대조표 9행과 킬 효율 9행을 Y1 신상수로 재계산했다(계산값 · 실측 아님 · Y8 재확정):

| d | HP | 피해 | 속도 | 물량+ | 정예 | XP× | 효율 |
|---|---|---|---|---|---|---|---|
| 0 | 1.00 | 1.00 | 1.00 | 0 | 0.00 | 1.00 | 1.00 |
| 4 | 1.51 | 1.34 | 1.05 | 16 | 0.16 | 1.23 | 0.81 |
| 8 | 2.25 | 1.82 | 1.10 | 32 | 0.32 | 1.50 | 0.67 |
| 12 | **3.21** | 2.42 | 1.14 | 32 | **0.45**(상한) | 1.79 | **0.56** |

⚠️ **`1 / 효율(12)`이 2.10 → 1.79로 내려갔다.** §6.2의 「d=12에서 레벨업 속도가 정확히
절반」이라는 주장은 **더 이상 성립하지 않는다.** 단언은 1.79로 갱신했고 주석에
"목표치는 Y8이 balance_probe로 다시 정한다"를 박아 뒀다.

### 4.3 `--castle-test` 흐름 할증 탐침 (`rune_shop`)

구판은 「일반 + 비흐름 + **굴림**」 각인을 대조군으로 찾았는데 **신 15종에 그런 각인이
하나도 없다**(일반 6종 = 흐름 3 + 확정 3). 탐침이 빈손이 되어 이 묶음이 영원히 false였다.

가격식은 흐름(×1.25)과 확정(×1.15)을 **곱해서** 얹는다. 그래서 흐름 탐침을 **`p_max`**로
잡아 굴림 프리미엄을 `ROLL_PREMIUM_MAX`(1.15)로 고정하면 확정 탐침의
`PASSIVE_PREMIUM`(1.15)과 **같아지고**, 남는 차이가 흐름 할증 하나뿐이 된다.
(`p_min`으로 잡으면 굴림 하한 0.85가 걸려 **흐름 쪽이 오히려 싸다** — 48 vs 52.)
두 상수가 같다는 전제 자체도 단언에 넣었다.

### 4.4 폐기 각인 id 전수 이관 (test_runner 24지점)

`roll_rune("…")` 호출부를 정규식으로 훑어 신 id로 옮겼다. **슬롯 강화 이름 `"repeat"`
(`_buy_factory_upgrade`)는 각인이 아니므로 건드리지 않았다.**

| 구 | 신 | | 구 | 신 |
|---|---|---|---|---|
| `rewind_1` `rewind_2` | `back_one` | | `edge` `chorus` | `strong` |
| `skip_1` `bookmark` | `jump_one` | | `reach` `barb` | `wide` |
| `repeat` | `twice` | | `heat_gate` | `first_hit` |
| `kill_repeat` | `finisher` | | `afterburn` | `quick` |
| `echo` `overlap` `link_next` | `twin_cast` | | | |

캡처 루틴 2곳의 `player_cycle.heat = N` 직접 대입은 `exec_counts.assign([...])`로 갈았다.

### 4.5 칸/레일 분기 테스트 헬퍼 3종 (신설)

3택에 레일 각인이 섞이므로 "2단계에서 칸을 고른다"를 재는 검사는 **칸 각인 제시분**을
집어야 한다. `test_runner.gd`에 3종을 넣고 draft/castle/rift 세 검사가 공유한다:

```gdscript
func _first_slot_offer_index() -> int          # 3택 중 첫 칸 각인. 없으면 −1
func _first_rail_offer_index() -> int          # 3택 중 첫 레일 각인. 없으면 −1
func _open_slot_rune_draft(src, ret) -> int    # 칸 각인이 들 때까지 최대 16회 재개봉
```
`--draft-test entry` 묶음에는 **레일 각인 즉시 적용**도 함께 단언한다
(고르면 state가 바로 `"playing"` · `rail_rune_count()` +1 · `total_rune_count()` 무변화).

### 4.6 `--save-test` 지문 축 `rail_runes` 신설

`,`.join(`rail_rune_ids()`)를 지문에 넣었다 — **개수만 맞고 내용이 다른 복원**을 잡는다.
음성 대조로 확인: 저장 키를 지우면 `fields=false mismatch=1 불일치 rail_runes(rail_fast,rail_power→)`.

---

## 5. 음성 대조 3건 (새 단언이 실제로 무는가)

| 되돌린 것 | 빨개진 플래그 |
|---|---|
| `_plan_cycle()`의 `opts.merge(factory.rune_opts())` 삭제 | `rail_rune=false` |
| `_rolled(step, "twin_cast")` → `"echo"` | `twin_cast=false` · `twin_pairs=0 twin_miss=44` |
| 위 둘 동시 | 추가로 `runtime=false`(실전 봉우리가 2에 못 닿는다) |
| 스냅샷 키 `factory_rail_runes` 삭제 | `--save-test fields=false mismatch=1` |

세 경우 모두 **다른 플래그는 그대로 true**였다 — 단언이 정확히 그 축만 문다.

---

## 6. 저장 — `rail_runes` (§9.3 Y2 항목)

```gdscript
"factory_rail_runes": factory.rail_runes.duplicate(true),      # 저장
factory.rail_runes.clear()                                      # 복원
for rail_value in (_snapshot_value(snapshot, "factory_rail_runes", []) as Array):
    if rail_value is Dictionary:
        factory.attach_rail_rune(rail_value as Dictionary)      # 상한은 접근자가 스스로 건다
```

**schema는 올리지 않았다(3 그대로).** 키가 없는 옛 스냅샷은 빈 배열로 떨어지고 그것이
곧 옛 상태와 같다(레일 각인이 없던 런). 키 하나 추가는 하위 호환이므로 폐기 이유가 없다 —
**schema 4는 Y6가 다른 신설 키들과 함께 올린다**(handoff-y1 §9-F). `assign`이 아니라
`attach_rail_rune()`으로 넣는 이유는 상한을 넘긴 저장이 들어와도 접근자가 거르게 하기 위해서다.

---

## 7. rune_engine deprecated 셔틀 — **확인 완료 · 삭제는 보류**

지시대로 소비자 수를 전수 확인했다. **게임 코드 소비자는 0이다.**

| 심볼 | 게임 코드 | 남은 참조 |
|---|---|---|
| `HEAT_MAX` `HEAT_GATE_MIN` `BOND_MIN_RUN` `BOND_FIRE_COST` `REPEAT_CAP` `OVERLAP_POWER` `mean_peak_heat` | **0** | **없음 — 즉시 삭제 가능** |
| `HEAT_DECAY` `HEAT_DAMAGE` `HEAT_RELOAD` `REENTRY_FALLOFF` `TRIANGLE_RELOAD_DISCOUNT` `OVERCHARGE_HEAT_BONUS` `heat_from_load()` `damage_multiplier()` `bond_mask()` `triangle_ok()` · 결과 키 `heat_curve`/`peak_heat`/`end_heat`/`carry_heat`/`deviation_load` | **0** | `test/rune_test.gd:1197-1244`(`heat_neutral`) · `test/data_test.gd:675-682`(`rune_heat_neutral`) |
| `ECHO_POWER` `CHORUS_POWER` `LINK_POWER` | **0** | `test/balance_probe.gd:278-336` |

**왜 지금 지우지 않았나** — 위 두 그룹을 지우면 `rune_test.gd`·`data_test.gd`가 **파스 에러로
죽는다.** 두 파일은 Y1 확정 소유이고 이 웨이브의 완료 기준이 "rune_test·data_test standalone
PASS 유지"다. 셔틀을 지우려면 그 두 파일의 `heat_neutral` 묶음을 함께 지워야 하는데,
그 묶음의 존재 이유가 바로 "셔틀이 실수로 되살아나면 잡는다"이므로 **셔틀과 함께 은퇴하는
것이 맞다.** 셔틀은 중립값이라 해롭지 않고, 세 번째 그룹은 `balance_probe.gd` 재작성이
Y8 몫이다.

> **권고: Y8이 `balance_probe.gd`를 재작성할 때 셔틀 3그룹을 한 번에 삭제한다.**
> 그 커밋 하나에서 `rune_engine.gd`(셔틀 28곳) · `rune_test.gd`(`heat_neutral` 1묶음) ·
> `data_test.gd`(`rune_heat_neutral` 1묶음) · `balance_probe.gd`(echo/chorus/link 재현 코드)를
> 같이 지우면 어느 시점에도 빨간 상태가 안 생긴다. 위 표가 그 삭제 목록 전부다.

---

## 8. 후속 웨이브 수정 목록 (이번에 고치지 않은 것)

### A. Y3 — 각인 UI 3종 + 세공사

| 위치 | 무엇 | 상태 |
|---|---|---|
| `game.gd:9930` `_rune_offer_price()` | **`GameTuning.RUNE_SHOP_RAIL_PREMIUM`(1.20)이 아직 소비자 0이다.** 항 하나 추가하면 산다: `if RuneEngine.rune_scope(rune_id) == "rail": base *= GameTuning.RUNE_SHOP_RAIL_PREMIUM` | 일부러 안 넣었다 — 가격 밸런스 판단이 Y3 소유고, 넣으면 `--castle-test`의 가격 단언 3종을 함께 옮겨야 한다 |
| 부착 2단계 전면 재작성(§8 ②) | Y2는 **분기만** 넣었다. 레일 각인은 확인 화면 없이 즉시 붙고 배너로만 알린다 — §8 ②가 요구하는 "레일 부착 전용 화면"은 없다 | Y3 |
| `_build_rune_mini_rail()` | 2단계 전용. 레일 각인은 여기 도달하지 않는다(분기가 앞에서 잘린다) | Y3가 재작성할 때 죽은 분기 정리 |
| 밀정 리뉴얼(§8 ⑪) | 무접촉 | Y3 |

### B. Y4 — 색·어휘 (전부 무접촉)

- `game.gd:1888` `ELEMENT_COLOR` → `fire e2452f` · `oil 7a5230`
  (**지금 카드 `color`와 HUD가 불·기름 두 원소에서 다른 색을 그린다** — handoff-y1 §5 ⚠️)
- `_factory_card_color()` → `_element_color()` 폴백 · `RAIL_ELEMENT_MARK` 한자 7자
- **온보딩 2p 모조 레일의 가짜 태그 `"화 참격"` / `"뇌 파동"` / `"빙 수호"`가 그대로다**
  (`game.gd:5786-5790`). Y2는 그 페이지의 **과열 열만** 걷었다 — 태그는 Y4의 어휘 몫이다.
- `skill_icon.gd GENERATED_SKILL_INDEX` → 실루엣 인덱스

### C. Y6 — 저장 schema 4

Y2가 `factory_rail_runes`를 schema 3에 **하위 호환으로** 얹었다. Y6가 schema 4를 올릴 때
이 키는 이미 있으므로 새로 만들 필요가 없다 — `--save-test`의 `rail_runes` 지문 축도 그대로 쓴다.

### D. Y8 — 밸런스

- `balance_probe.gd` 재작성 + §7의 셔틀 삭제 동반
- `1 / 효율(12) = 1.79`가 옳은 목표인지 재확정(§4.2)
- `DWELL_*` 6상수 · `STAGE_HP_BASE` · `BOSS_RELOAD_MUL 0.42` 전부 "착수값"이다
- `--cycle-test`의 `debt=2.42`(무각인 5칸 빚)가 기준선으로 로그에 남는다

### E. 소유자가 없어 남은 잔재 1건

`scripts/boss_library.gd:412`의 데이터 키 **`"uses_heat": false`**. 게임 코드는 읽지 않고
`test_runner.gd:952 · 2708`의 단언 2곳만 읽는다(둘 다 "false여야 한다"라 지금도 참).
Y2 소유 파일이 아니라 두지 않았다 — `boss_library.gd`를 여는 웨이브가 키 이름을 지우면
`test_runner`의 그 두 줄도 함께 지울 것.

---

## 9. 밟은 함정 · 다음 웨이브가 알아야 할 것

1. **`RuneEngine.TWIN_POWER`를 컨트롤러에 박으면 안 된다.** 사본 2개에서 엔진은 0.80,
   상수는 0.50이라 계획 > 실제가 **조용히** 돌아온다. `passive_magnitude()`가 엔진과 같은 식이다.
2. **`EDIT_ARC_RUNES`는 `FLOW_DELTA`가 아니다.** 단위가 "착지 오프셋"(= `1 + delta`)이다.
   그대로 복사하면 아크가 한 칸씩 어긋난다(§3-④).
3. **`_factory_deck_signature()`에 레일 각인을 안 넣으면 미리보기가 캐시에 걸린다.**
   레일 각인은 `factory.slots`에 없으므로 기존 루프에 안 잡힌다. 각인을 붙여도 화면 숫자가
   안 바뀌는 "고장 아닌 고장"이 된다.
4. **`--capture-*`로 캡처 루틴을 고칠 때 `_setup_rail_capture_deck()`도 같이 본다.**
   Y2가 여기에 레일 각인 2개를 얹었다 — 편집 화면의 글리프 줄이 **빈 유령으로만** 찍히면
   검수자가 "줄이 안 붙었다"로 오독한다.
5. **폐기 각인 id는 여전히 조용히 사라진다**(handoff-y1 §10-2 그대로). Y2는 `--cycle-test`와
   `--v4-test`에 **부착 수 단언**을 넣어 "각인 0개 덱으로 통과"를 막았다. 다른 검사에
   각인을 심을 때 같은 방어를 넣을 것.
6. **`--cycle-test`의 twin 판정은 물리 틱을 끄고 돈다**(`set_physics_process(false)` +
   `_start_current_step()` 직접 호출). 프레임 타이밍이 개입하면 "한 스텝에 카드 몇 장이
   떴는가"가 흔들려 이 계약을 아예 못 잰다. 비슷한 계측을 새로 만들 때 같은 수법을 쓸 것.
7. **`overloaded` 시그널·`end_reason == "overload"`는 지우지 않았다.** 규칙이 아니라
   **엔진 버그 탐지기**로 남았다(§1.3). 배너 문구만 「과부하」 → 「바퀴 상한 도달」로 갈았고,
   `--cycle-test`가 몬테카를로 5,000사이클에서 도달 0건을 계약으로 못 박는다.
8. **스트립 폭이 380 → 358로 줄었다.** `RAIL_BAND_RECT`를 좌표로 쓰는 곳(`_guide_target_rect`
   3분기 · `--capture-hud` 검수 · `hud_block_pct`)이 전부 상수를 읽으므로 자동으로 따라왔지만,
   **하드코딩된 380/450을 새로 넣지 말 것.**
9. **`cycle_completed`의 두 번째 인자 의미가 바뀌었다**(최고 과열 → 이번 바퀴 최다 실행 횟수 1~2).
   결과 화면 지표는 **첫 번째 인자**(`steps`)를 쓴다 — 「한 바퀴 최다 칸」은 스텝 수다.
10. **`--save-test`의 `axes` 수는 68 그대로다.** Y2가 축 하나(`rail_runes`)를 더했는데도
    숫자가 안 늘었다 — handoff-v9의 "68축"이 이미 실제 dict 크기와 어긋나 있었다는 뜻이다.
    축 개수를 계약으로 쓰지 말고 `mismatch=0`만 볼 것.

---

## 10. 이 웨이브가 하지 않은 것

- `game.gd` Y3~Y7 구역 전부(각인 UI · 색·어휘 · 필드 생태 · 발견/이벤트 · 타격감)
- `rune_engine.gd` 셔틀 삭제(§7 — 확인만 하고 보류. 삭제 목록은 §7 표가 전부다)
- `balance_probe.gd` 재작성과 밸런스 재측정(Y8)
- 저장 schema 4(Y6) · 온보딩 전면 재작성과 한글 전수 스윕(YZ)
- `docs/FEEDBACK_Y.md` 자체 수정 — §6.2의 「d=12에서 정확히 절반」이 이제 1.79배라는 것과
  §5.5의 산수 오류 2건(handoff-y1 §8)은 **보고만 하고 문서는 건드리지 않았다.**
