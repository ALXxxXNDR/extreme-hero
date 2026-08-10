# W2 인수인계 — 5칸 사이클 런타임 (바늘 · 과열 · 빚 RELOAD)

> 작성일 2026-08-07 · 대상 웨이브: **W5**(필드 HUD) · **W6**(편집 화면·드래프트) · **W9**(성/NPC) · **W10**(마왕전) · **W12**(저장·밸런스)
> 기준 문서: `docs/GAME_DESIGN_V2.md` §3 전체 · §5.4 · §6 · §7 W2 정의 · **부록 C**(본문보다 우선)
> 검증 상태: `run_all.sh` **9종 전부 PASS** · `rune_test`/`data_test` standalone PASS · 비headless 캡처 4종 육안 확인 완료.

---

## 0. 산출물

| 파일 | 판정 | 내용 |
|---|---|---|
| `scripts/factory_deck.gd` | **재작성** | 5칸 고정 · 칸이 각인 스택 소유 · 장비 4부위 · `rune_deck()` |
| `scripts/deal_cycle_controller.gd` | **재작성** | 바늘(playhead) 런타임. `RuneEngine.simulate_cycle` 궤적을 프레임에 펼친다 |
| `scripts/cycle_skill_effect.gd` | 수정(S) | `setup()`에 `step_damage_mul` 인자 1개 추가 + 과열 링 연출 |
| `scripts/core/combat_resolver.gd` | 수정(시그니처만) | `damage_mul`을 `_cycle_damage_value` **단 한 곳**까지 배선 |
| `scripts/core/rune_engine.gd` | 수정(상수 1) | `HEAT_GATE_MIN` 3 → **2** (부록 C-7) |
| `scripts/game.gd` | 수정 | 아래 §5 |
| `scripts/test/test_runner.gd` | 수정 + 신설 | v1 공장 단언 재작성 + `--cycle-test` 신설 |
| `scripts/test/run_all.sh` | 수정 | `ALL_TESTS`에 `--cycle-test:CYCLE_TEST_COMPLETE` 추가 |
| `docs/v1-archive/{factory_deck,deal_cycle_controller,cycle_skill_effect}.gd.txt` | 신설 | 파괴적 재작성 전 원본 보존 |

**§7.1은 새 파일명(`core/cycle_deck.gd` / `core/cycle_engine.gd`)을 지정했지만 기존 경로를 유지했다.**
근거: 두 파일은 `game.gd`가 `preload` 상수 2개(`FACTORY_SCRIPT`/`CYCLE_CONTROLLER_SCRIPT`)로만 참조하고
`class_name`(`FactoryDeck`/`DealCycleController`)이 전 코드베이스·테스트·저장 스키마에 박혀 있다.
파일을 옮기면 이번 웨이브의 실제 변경(모델 교체)과 무관한 diff가 수십 곳 생긴다. 내용은 전면 v2다.
옮기고 싶으면 W12에서 `git mv` + preload 2줄 + class_name 2줄로 끝난다.

---

## 1. 바늘 런타임 규칙 최종본

### 1.1 단일 진실 원천 — 이것만은 깨지 마라

```
사이클 시작 → factory.rune_deck() → RuneEngine.simulate_cycle(deck, seed, opts) → steps[]
스텝마다   → steps[i]를 읽어 그 칸의 카드를 재컴파일 + CycleSkillEffect 생성
사이클 끝  → steps 소진 / 과부하 → 빚 RELOAD 대기 → 다음 시드로 재계획
```

**컨트롤러는 각인을 스스로 굴리지 않는다.** 궤적은 100% 엔진이 만든다.
W6의 편집 미리보기(`RuneEngine.preview`)와 실전이 어긋날 수 없는 유일한 구조다.
`--cycle-test`의 `flow_rune` 플래그가 이 등식을 실측으로 잠근다
(`player_cycle.planned_route() == simulate_cycle(같은 덱, 같은 시드).visited`).

### 1.2 결정성 · 시드

| 항목 | 값 |
|---|---|
| 런 시드 | `game.run_cycle_seed` — `_begin_run()`에서 `rng.randi() \| 1` 로 한 번 굴린다 |
| 플레이어 사이클 시드 | `run_cycle_seed + completed_cycles × 7919` |
| 마왕 | `run_cycle_seed + 5701` (+ 같은 stride) |
| 전조 | `run_cycle_seed + 977 + day` |
| 저장 | `run_cycle_seed`가 schema 2에 들어간다 → **리플레이가 공짜** |

`DealCycleController.setup(game, actor, deck, is_boss, uses_reload, seed_base)` 의 6번째 인자가 시드다.
0을 넘기면 액터 instance_id로 파생하지만(테스트 편의), 게임 경로는 전부 명시 주입한다.

### 1.3 설계 대비 조정점 (3건)

| # | 설계 | 실제 구현 | 근거 |
|---|---|---|---|
| **K-1** | `kill_repeat`은 "이 칸으로 처치하면" 조건 | **직전 사이클에서 관측한 스텝별 처치 여부**를 다음 사이클의 `opts.kills`로 주입 | 처치는 카드 실행 **후**에야 확정된다. 스텝마다 다시 굴리면 결정성과 단일 진실 원천이 동시에 깨진다. 첫 사이클은 처치 없음으로 계획된다. handoff-w1 §8이 허용한 두 경로 중 "궤적 보존" 쪽을 골랐다 |
| **K-2** | 아이템 스코프 `*_next`/`*_previous`는 바늘 문맥을 본다(§5.4) | 계획은 flow 없이 하고, **실행 시점에** 그 스텝의 flow(`current`/`next`/`prev`)로 카드를 다시 컴파일한다. duration만 계획된 배율(haste 등)을 곱해 유지 | 계획 시점에는 아직 궤적이 없다(닭-달걀). 궤적은 flow와 무관하므로 이 순서가 안전하다 |
| **K-3** | `rune_fired(rune_id, effect)` (§7 W2 ③) | `rune_fired(rune_id: String, slot_index: int)` | "effect"의 타입이 명시되지 않았다. 소비자(HUD)가 실제로 필요한 것은 "어느 칸에서 터졌나"다 |

### 1.4 동시 발동 각인의 실전 처리

엔진은 `echo`/`chorus`/`overlap`/`link_next`의 피해를 `step.damage`에 **합산**해 둔다.
런타임은 그 합산값을 쓰지 않고 **곁들이 이펙트를 실제로 생성**한다(같은 위력 비율).

| 각인 | 런타임 동작 | 검출 방법 |
|---|---|---|
| `link_next` | `step.link` 칸의 카드를 `damage_mul × LINK_POWER`로 동시 실행 | `step.link >= 0` |
| `echo` | 이전 스텝 칸의 카드를 `× ECHO_POWER`로 추가 실행 | `step.fired`에 있음 |
| `chorus` | 양옆 칸을 `× CHORUS_POWER`로 추가 실행 | `step.fired`에 있음 |
| `overlap` | 이전 스텝 칸을 `× 합성크기`로 추가 실행 | **확정 각인이라 `fired`에 없다** → `RuneEngine.passive_magnitude(slot, "overlap")` |

> **주의**: 확정(패시브) 각인은 `step.fired`에 절대 남지 않는다(엔진이 굴리지 않으므로).
> W5가 "발동한 각인"을 그릴 때 확정 각인을 놓치지 않으려면 칸의 `runes`를 직접 읽어야 한다.

### 1.5 과열 · 재진입 · 빚

- **피해 배율**: `step.damage_mul` (과열 + 재진입 감쇠 + 공명 + 각인 피해가 전부 곱해진 최종값).
  이 값이 `CycleSkillEffect.setup()` → `game.apply_cycle_melee/trigger_cycle_card_pulse` →
  `combat._cycle_damage_value(actor, card, is_boss, damage_mul)` **단 한 곳**으로 흐른다.
  근접·투사체·연쇄·광역·보스 전 경로가 여기 모인다. **다른 곳에서 배율을 곱하지 말 것.**
- **범위/관통**: `step.range_bonus` / `step.pierce_bonus`가 실행 시점에 카드에 실린다.
  `cycle_pulse_center`/`cycle_pulse_radius` 대칭(그리기 = 피해)은 그대로 유지된다 —
  둘 다 같은 카드 딕셔너리를 본다.
- **빚 RELOAD**: `plan.reload`를 그대로 쓴다. 이미 `빚 × (1 + heat × HEAT_RELOAD) × 삼각할인 × reload_scale`
  이 적용되고 `RELOAD_CAP`으로 클램프돼 있다. 과부하 종료면 `RELOAD_CAP × scale`.
- **잔열**: `plan.carry_heat` → 다음 사이클 `opts.start_load`. `afterburn` 각인이 있을 때만 0이 아니다.

---

## 2. FactoryDeck v2 데이터 모델

```gdscript
slot := {
    "card": Dictionary,     # 빈 {} = 기본 베기
    "runes": Array,         # 각인 인스턴스 {id, p, mag} — **칸이 소유**(부록 C-1)
    "repeat": int,          # 강화술사 잔존 배율 (1 또는 2)
    "duration_mul": float,
    "reload_mul": float
}
FactoryDeck.slots     : Array[Dictionary]   # 기본 5칸 (전조는 1칸, 마왕은 5칸)
FactoryDeck.inventory : Array[Dictionary]   # 카드 보관함 (유지)
FactoryDeck.equipment : Array[Dictionary]   # 레일 밖 장비 4부위 (§5.4) — UI는 W6
```

**폐기**: `lanes`(분열 3레인) · `split_slot` · `MAX_SPLIT_UPGRADES` · `build_next_piece` ·
`can_build` · `trailing_bridge` · `construction_count` · `MAX_SLOTS` · `START_SLOTS`.

### 2.1 시그니처가 바뀐 함수 (호출부 전수 갱신 완료)

| v1 | v2 |
|---|---|
| `place_card(slot, lane, card)` | `place_card(slot, card)` — **아이템이면 자동으로 `equip()`으로 우회** |
| `get_card(slot, lane)` | `get_card(slot)` |
| `clear_lane(slot, lane)` | `clear_slot(slot)` |
| `compile_group(slot) -> Array` | `compile_slot(slot, flow := {}) -> Dictionary` (`compile_group`은 1장짜리 배열 별칭으로 남김) |
| `reset()` | `reset(slot_count := 5)` |

### 2.2 신설 API (W6가 쓸 것)

```gdscript
# 각인 — 칸이 소유한다
attach_rune(slot_index, instance) -> bool     # 상한 초과면 false (총 5개 / 같은 id 3개)
detach_rune(slot_index, rune_index) -> Dictionary
runes_on(slot_index) -> Array
rune_count_on(slot_index) -> int
total_rune_count() -> int

# 부록 C-1의 두 조작 — **별개 제스처로 노출할 것**
swap_slots(a, b) -> bool     # 칸 통째 교환. 각인이 함께 이동
move_card(a, b) -> bool      # 카드만 교환. 각인은 제자리

# 장비 (§5.4)
equip(card) -> Dictionary          # 같은 부위 교체 시 밀려난 장비 반환
unequip(index) -> Dictionary
equipped_at(part) -> Dictionary    # part ∈ EQUIPMENT_PARTS
static equipment_part(card) -> String

# 엔진 다리
rune_deck(flow := {}) -> Array     # RuneEngine.simulate_cycle / preview 에 그대로 넘긴다
ensure_slot_count(n) / normalize_slots()   # 저장 복원용
```

### 2.3 `total_reload()`의 의미가 바뀌었다

v1: "한 바퀴 후 대기할 초".
v2: **"5칸을 한 번씩 실행했을 때 쌓이는 기본 빚"**(과열 미포함). 실제 RELOAD는 사이클 종료 시 계산된다.
UI 문구는 전부 "한 바퀴 RELOAD **빚** N초"로 바꿔 뒀다. HUD 라벨을 다시 쓸 때 이 구분을 유지할 것.

---

## 3. 시그널 · 런타임 조회 API (W5 · W10)

```gdscript
# --- 시그널 ---
slot_entered(index: int, reentry: int)      # 바늘이 칸에 진입. reentry>0 = 재진입
rune_fired(rune_id: String, slot_index: int)
heat_changed(heat: int)                     # 0..HEAT_MAX
debt_changed(debt: float)                   # 누적 빚(초)
cycle_completed(steps: int, max_heat: int)
overloaded()                                # STEP_CAP 도달 — "과부하" 플래시 자리

# --- 상태 (매 프레임 읽어도 되는 값) ---
current_index      # 지금 실행 중인 칸 (0-based)
current_reentry    # 이번 사이클에 이 칸을 몇 번째로 실행 중인가
heat               # 표시·피해·RELOAD용 과열 스택
reload_debt        # 누적 빚(초) — "빚 게이지"
reloading / reload_remaining / reload_duration
group_elapsed / group_duration / progress_ratio()
completed_cycles / last_step_count / last_end_reason / was_overloaded
reload_scale       # 마왕 0.6, 그 외 1.0

# --- 조회 ---
planned_route() -> Array        # 이번 사이클의 예정 칸 순서 → 레일 고스트 화살표
previous_index() / next_index() # 계획 기반(단순 ±1이 아니다)
heat_damage_bonus() / heat_reload_bonus()
projected_reload()              # 지금 청산하면 나올 RELOAD(초) — 빚 게이지 상단 눈금
plan_steps                      # 스텝 레코드 원본 (handoff-w1 §3.6의 스텝 스키마)
```

> **W5에게**: §3.5의 "온도계 + 레일 색온도(청→금→적)"는 `heat_changed` + `HEAT_MAX`(8)만 있으면 그린다.
> "빚 게이지"는 `debt_changed` + `projected_reload()` / `RuneEngine.RELOAD_CAP`.
> 되감기 릴(`CYCLE_REWIND_*`)은 `reloading`/`progress_ratio()`로 그대로 살아 있다.
> 각인 되감기 발동 시의 축소판 재사용(§7.2)은 `rune_fired`에서 `rewind_1`/`rewind_2`를 잡으면 된다.
> 현재 `_update_deal_cycle_hud`의 임시 표기는 `"칸 01 / 05 ↺1"` + `"0.72초 · 과열 0 · 빚 0.11"` 두 줄이다.

> **W10에게**: 마왕 HUD 고스트 레일(§6.3)은 `boss_cycle`의 같은 시그널을 쓴다.
> `boss_factory.rune_count_on(i)`가 칸별 각인 배지, `boss_cycle.heat`가 §6.2의 "마왕 과열 게이지"다.
> `_build_boss_factory()`는 이미 5칸 + `demon_lord.slot_layout()` 기반으로 재작성돼 있다(아래 §5).

---

## 4. 각인 · 마왕 연동

- `game._ready()`에서 `demon_lord.set_rune_catalog(RuneEngine.all_rune_ids())`를 호출한다
  → `DemonLord.granted_runes`의 `rune_id`가 자리표시자가 아니라 **실제 각인 id**가 된다(handoff-w4 §3 요구 이행).
- `_build_boss_factory()`가 `demon_lord.slot_layout()`을 그대로 옮겨 담고,
  각 `rune_id`를 `RuneEngine.roll_rune(id, rng)`로 인스턴스화해 칸에 붙인다.
- 버린 아이템(`boss_items`)은 레일이 아니라 `deck.equip()`으로 간다(§5.4 — 칸을 먹지 않는다).
- **마왕 RELOAD ×0.6**: `boss_cycle.setup(..., uses_reload=true)` + `reload_scale = GameTuning.BOSS_RELOAD_MUL`.
  v1의 "RELOAD 없음"에서 뒤집혔다(§6.2). `--v4-test`의 `boss_runtime` 단언도 함께 뒤집었다.
- **전조**: `omen_deck.reset(1)` 1칸 덱 + **그 칸의 각인까지 함께** 들고 나온다
  (`demon_lord.runes_on_slot(slot_index)` → `roll_rune`). 전조가 "마왕의 그 칸"인 이유가 여기 생겼다.
- `can_cycle_run()`의 **W4 전조 가산 절은 그대로 유지**했다(주석으로 못 박아 뒀다).

---

## 5. `game.gd` 변경 상세

| 구역 | 함수 / 심볼 | 변경 |
|---|---|---|
| `_ready` | | `demon_lord.set_rune_catalog(...)` 1줄 |
| 상태 선언 | **신규** `run_cycle_seed` | 궤적 시드의 뿌리 |
| 상수 | `CHOICE_FORFEIT_GOLD := 45` 신규 · `FACTORY_RAIL_BRIDGE_W` 70→**34** · `FACTORY_RAIL_BRIDGE_SPRITE` 축소 | 5칸(200×5 + 34×4 = 1,136px)이 공장·마왕 프리뷰·결과 화면 **전부에서 가로 스크롤 없이** 들어온다 |
| HUD 칩 | `_cycle_slot_lead_card` `_apply_cycle_chip` | 레인 → 카드 1장. 칩 배지가 레인 수 → **각인 개수**(`각N`) |
| 필드 HUD | `_update_deal_cycle_hud` | `칸 NN / 05 ↺r` + `N초 · 과열 H · 빚 D` (W5가 대체할 임시 표기) |
| 공장 화면 | `_show_factory_menu` `_build_factory_rail_slot` | 5칸 고정 루프 · 고스트 칸/건설 중 다리 제거 · 칸 머리말에 `각인 N` |
| 공장 조작 | `_factory_lane_pressed` `_on_factory_card_dropped` | 새 시그니처. 레일↔레일 드래그 = **[카드 이동]**(각인은 제자리) |
| 레벨업 | `_show_skill_choice` `_choose_factory_growth` | "레일 부품 건설" → **카드 2장 포기 + 45 G**. §6 참조 |
| 보물상자 | `_open_chest` | 부품 건설 분기 → 45 G 환전 |
| 강화술사 | `_show_factory_mage` `_buy_factory_upgrade` | `build`·`split` 판매 제거. 칸 배율 3종만 |
| 전조 | `_spawn_night_omen` | `reset(1)` + 각인 동반 |
| 마왕 | `_build_boss_factory` `_begin_boss_battle` `_challenge_demon_king` `update_boss_health` | 5칸 · 각인 · RELOAD ×0.6 |
| 전투 래퍼 | `apply_cycle_melee` `trigger_cycle_card_pulse` | `damage_mul` 인자 추가 |
| 저장 | `_save_run_snapshot` `_restore_run_snapshot` | schema 2에 `factory_equipment` / `run_cycle_seed` 추가, `factory_trailing_bridge`/`factory_split_used`/`factory_construction` 제거. 복원 시 `ensure_slot_count`+`normalize_slots` |

### 5.1 ⚠️ 소유권 경계를 넘은 곳 (보고 대상)

1. **`_build_boss_factory` / `_begin_boss_battle` / `_challenge_demon_king` / `update_boss_health`**
   — §7.3 표에서 **W10 소유**다. 지시서 §범위-5("마왕 5칸·전조 1칸 사이클도 같은 needle/과열 규칙")를
   이행하려면 덱이 5칸이어야 해서 런타임 규칙까지만 손댔다. **UI 레이아웃·프리뷰 구성은 건드리지 않았다.**
   W10이 재작성할 때 `demon_lord.slot_layout()` 기반 배치와 `reload_scale`만 보존하면 된다.
2. **`_show_skill_choice`의 3번째 버튼 / `_open_chest` / `_show_factory_mage`** — 각각 W6·W8·W9 구역이다.
   전부 **v1 전용 경로(레일 건설·분열)의 안전화**이며 §6에 목록화했다.
3. **`FACTORY_RAIL_BRIDGE_W` 축소** — W6 소유의 공장 화면 상수다. 5칸이 한 화면에 들어오게 하는
   상수 2개 변경이며 레이아웃 구조는 그대로다. W6가 레일을 재작성하면 자유롭게 바꿔도 된다.

### 5.2 죽은 코드 (지우지 않았다)

- `_build_factory_rail_ghost_slot()` — 미건설 자리표시자 렌더러. 5칸 고정이라 호출부가 없다.
  W6가 "미개방 칸(4칸=L4, 5칸=L9 · §9.2)"을 구현하면 **그대로 재사용**할 수 있어 남겼다.
- `_show_factory_menu`의 `mode == "build"` 분기와 `_auto_close_factory_build()` — 호출부가 없다.
- `game._boss_auto_fused_cards()` — `demon_lord.auto_fused_cards()`와 같은 답을 낸다.
  handoff-w4 §6이 "W10이 game.gd 쪽을 지워라"라고 했으므로 W10 몫으로 남겼다.

---

## 6. v1 전용 경로 안전화 목록 (W9가 재정의할 것)

5칸 고정으로 **의미가 사라졌지만 크래시 없이 동작하도록** 최소 처리한 것들이다.
전부 "골드로 환산" 또는 "판매 제거"이며, 새 시스템을 만들지 않았다.

| 위치 | v1 | v2 안전화 | 진짜 답 |
|---|---|---|---|
| 레벨업 3번째 선택지 | "딜싸이클 업그레이드 · 다리/칸 건설" | **두 카드 포기 + 45 G**. 버튼·포커스 모델은 그대로 | **W6**: 각인 3택1 드래프트(§8.3) |
| 보물상자 `roll<75` | 레일 부품 건설 | 45 G 환전 | **W8**: 각인 상자 |
| 강화술사 `build` 판매 | 부품 건설 55 G | **판매 목록에서 제거** | **W9**: 각인 상점 |
| 강화술사 `split` 판매 | 분열 120 G | **판매 목록에서 제거**. 억지로 사도 `can_apply_upgrade("split")==false`라 골드가 안 나간다 | **W9** |
| `FactoryDeck.upgrade_slot("split")` | 레인 +1 | **항상 false** | **W9**: 폐기 또는 각인 슬롯 +1로 재해석 |
| `_factory_upgrade_description("split")` | "동시 실행 레일 +1" | "폐기된 강화입니다 (v2는 5칸 고정)" | — |

> **W9에게**: `repeat`/`duration`/`reload` 칸 배율 3종은 5칸에서도 의미가 살아 있어 **유지**했다.
> 각인 상점으로 통합할지, 배율과 각인을 공존시킬지는 W9 판단이다.

---

## 7. 재작성한 테스트 단언 (구 → 신)

### 7.1 `--v4-test`

| 구 플래그 | 신 플래그 | 변경 내용 |
|---|---|---|
| `initial=` (3칸 · `trailing_bridge` false) | **`initial5=`** | `slots.size()==5` · `total_rune_count()==0` · 5칸 전부 빈칸 · `compile_slot(0).id=="basic"` |
| `item_separate=` (아이템이 칸을 먹고 `card_kind=="item"`) | **`item_equip=`** | 아이템 `place_card` → **장비로 우회**. 칸은 비고 `compile_slot`은 skill(기본 베기). `total_reload() < raw_total_reload()` |
| `construction14=` (14회 건설 → 10칸) | **`slot_swap=`** | `swap_slots(0,4)`가 각인을 데려가고 `move_card(4,2)`는 각인을 두고 간다(부록 C-1 두 조작) |
| `split3=` (분열 2회 → 3레인) | **`rune_stack=`** | 같은 id 3개 · 총 5개에서 `attach_rune`이 false로 뒤집힌다 |
| `boss20=` (10칸 × 2레인) | **`boss5=`** | `slots.size()==BOSS_SLOT_COUNT(5)` · 칸에 아이템 없음 · `equipment.size()==min(boss_items,4)` |
| `boss_preview=` | 유지 | `boss_factory.slots.size()==5` |
| `boss_runtime=` (`not reload_enabled`) | 유지(**의미 반전**) | `reload_enabled == true` **and** `reload_scale == 0.6` |
| `skills28=` | **`skills_pool=`** | 이름만 변경(W7의 20종 드래프트 풀과 혼동 방지). 판정 내용은 그대로 |
| `fusion=` | 유지 | 전용 덱으로 분리(구 `construction_deck` 재사용 제거) |
| `drag_swap=` | 유지 | 레일↔레일 드래그가 **[카드 이동]**임을 주석으로 명시 |
| `early_day_peace=` | 유지 | **W7 정합**: `AGGRO_DAY_UNLOCK_CYCLE >= 5` → **`>= 3`** |

### 7.2 `--v4-castle-test`

| 플래그 | 변경 |
|---|---|
| `mage=` | 구: 분열 구매 → 레인 2개. **신**: ①폐기된 `split`을 사도 **골드가 나가지 않는다** ②`repeat` 구매 → 칸 배율 `repeat==2` |
| `mage_gate=` | 그대로. 5칸 전부 `repeat` 적용 후 `can_apply_upgrade` false 전이 (칸 수만 3 → 5) |

### 7.3 `--smoke-test`

`factory_slots=5` 출력 + 합격 조건에 `slots.size() == FactoryDeck.SLOT_COUNT` 추가.

### 7.4 시각 캡처 / 프리뷰

`split_slot` · `build_next_piece` 호출 전량 제거. `--capture-factory`/`--preview-build`는
아이템을 `equip()`으로 넣고 각인 2개를 붙여 v2 화면을 보여 준다.
`--capture-result`는 5칸에 카드 3장 + 각인 3개.

### 7.5 `--cycle-test` (신설)

```
CYCLE_TEST_COMPLETE five_slot=.. flow_rune=.. heat_damage=.. reentry=.. debt_reload=..
                    slot_swap=.. omen=.. boss=.. bounded=.. runtime=..
                    cycles=N steps_seen=N runes_fired=N max_steps=N overload_rate=F debt=F
```

| 플래그 | 검사 내용 |
|---|---|
| `five_slot` | 각인 0 덱이 `[0,1,2,3,4]`를 정확히 5스텝에 순회하고 `end_reason=="complete"`. 빈칸은 `compile_slot`이 `basic` |
| `flow_rune` | 같은 (덱·시드) → 같은 `trace_signature`. 40개 시드 중 흐름 델타가 스텝을 늘린 궤적 존재 |
| `heat_damage` | **실전 근접 판정**으로 `damage_mul` 1.0 vs 2.5의 실제 체력 감소가 2.4~2.6배. 마왕 경로도 같은 함수를 탄다 |
| `reentry` | `damage_multiplier(0,1)==0.82` · 실제 궤적의 재진입 스텝이 `cold × 0.82^n`과 일치 |
| `debt_reload` | 빚 == 5칸 `reload` 합. RELOAD == `빚 × 삼각할인` (과열 0). 마왕은 같은 빚 × 0.6 |
| `slot_swap` | 칸 교환이 각인을 데려가고 `rune_deck()`에도 새 위치로 반영. 카드 이동은 각인을 두고 간다 |
| `omen` | 3일차 밤 전조가 1칸 덱 + `reload_scale==0.6`으로 궤적을 만든다 |
| `boss` | 마왕 5칸 · `reload_enabled` · `reload_scale==0.6` · 궤적 생성 |
| `bounded` | 최악 덱(5칸 × `rewind_1`+`rewind_2`+`repeat` 전부 `P_CAP`) **3,000 사이클**에서 `end_reason=="guard"` 0회 · `step_count ≤ STEP_CAP` · `0 ≤ reload ≤ RELOAD_CAP` |
| `runtime` | 실제 프레임에서 **2바퀴 이상 완주** · 시그널 4종 발화 · 사이클 종료 시 과열 0/빚 0 리셋 · 사이클마다 시드 변경 |

> **관측 트릭**: `runtime` 구간은 칸의 `duration_mul`을 0.16으로 낮춰 12초 안에 여러 바퀴가 돌게 한다.
> duration은 궤적에 영향을 주지 않으므로 흐름 검사와 독립이다.

---

## 8. 검증 결과

| 결과 | 검사 | 비고 |
|---|---|---|
| PASS | compile (`--editor --quit`) | 오류 0 |
| PASS | `rune_test` (standalone) | 16종 규칙 + 32,000 사이클 몬테카를로. `HEAT_GATE_MIN` 2 변경 후에도 전 항목 true |
| PASS | `data_test` (standalone) | W7 산출물. `aggro_unlock_day=3` 확인 |
| PASS | world-test | |
| PASS | v4-test | 재작성 단언 포함 22 플래그 전부 true |
| PASS | v4-castle-test | `mage`/`mage_gate` 재작성 포함 |
| PASS | stress-test | `enemies=104 bounded=true` |
| PASS | smoke-test | `state=won factory_slots=5` |
| PASS | combat-test | |
| PASS | deadline-test | W4 11 플래그 전부 true (전조·강림 경로 무손상) |
| PASS | **cycle-test** | 신설. 10 플래그 전부 true |

비headless 육안 검수 (`godot --path godot-game -- --capture-*`):

| 화면 | 확인 |
|---|---|
| `--capture-factory` | 5칸이 **가로 스크롤 없이** 전부 보인다. 머리말 `칸 5/5 · 각인 2개 · 장비 1/4` · `한 바퀴 RELOAD 빚 0.87초` · 칸 02/04에 `각인 1` 배지 |
| `--capture-world` | 필드 HUD `칸 01 / 05` · `0.72초 · 과열 0 · 빚 0.11` 정상 |
| `--capture-boss` | 마왕 프리뷰 `칸 5 · 각인 4개 · RELOAD ×0.6`, 5칸 전부 표시 |
| `--capture-result` | `칸 5개 · 각인 3개` 5칸 무스크롤 |

### 8.1 밸런스 신호 (W12가 볼 것)

- `--cycle-test`의 `overload_rate=0.4177`은 **의도적으로 만든 최악 덱**(5칸 × 흐름 각인 3개 전부
  `P_CAP=0.75` 고정)의 수치다. W1의 0.70%는 `p_max`로 굴린 현실적 최악 덱이라 대상이 다르다.
  종료성 자체는 무손상(`guard` 0회, `max_steps=14=STEP_CAP`)이지만, **드래프트에서 흐름 각인이
  한 칸에 몰리면 과부하가 흔해진다**는 신호다. W6의 드래프트 풀 설계에서 참고할 것.
- W7의 RELOAD 재기준 이후 표준 덱의 한 바퀴 빚은 **0.76~1.23초**(v4-test/결과 화면 실측),
  과열 4에서 RELOAD ≈ 1.3~2.1초다. §3.7의 목표(평범한 사이클 1.5~2.5초)에 들어와 있다.

---

## 9. 알아 둘 함정

1. **컨트롤러는 각인을 굴리지 않는다.** 새 각인 효과를 런타임에 추가하고 싶으면
   `rune_engine.gd`에 넣고 `step` 레코드로 내려보내라. `deal_cycle_controller.gd`에서
   `rng.randf()`를 부르는 순간 결정성과 W6 미리보기 정합이 동시에 깨진다.
2. **확정(패시브) 각인은 `step.fired`에 없다.** `overlap`/`edge`/`toll`/`afterburn`/`barb`/`reach`가
   그렇다. 발동 여부를 UI에 그리려면 칸의 `runes`를 직접 읽어야 한다(`RuneEngine.passive_magnitude`).
3. **`damage_mul`은 `_cycle_damage_value` 한 곳에서만 곱한다.** 새 공격 유형을 추가할 때
   `trigger_cycle_card_pulse`의 `damage_value` 변수를 반드시 그 함수에서 받아 쓸 것.
4. **`total_reload()`는 이제 "빚"이다.** 대기 시간이 아니다(§2.3).
5. `place_card`에 아이템 카드를 넘기면 **칸이 아니라 장비로 간다.** 반환값은 밀려난 **장비**다.
6. v1 저장(schema 1)은 W4가 이미 버린다. schema 2에 `factory_equipment`/`run_cycle_seed`가 추가됐고
   `factory_trailing_bridge`/`factory_split_used`/`factory_construction`은 사라졌다.
   **W12가 스키마를 확정할 때 `run_cycle_seed`를 지우지 말 것** — 리플레이 계약이 여기 걸려 있다.
7. `--cycle-test`는 실시간 12초를 기다린다(전체 46초 중 약 20초). 프레임 진행이 필요한 검사라
   줄일 수 없다. 모달이 끼어들면 실패하므로 테스트가 `xp_target`을 막아 둔다.

---

## 10. 남겨 둔 것 · 다음 웨이브 체크리스트

**W5 (필드 HUD)**
- `heat_changed`/`debt_changed`로 온도계 + 빚 게이지(§3.5·§3.7 시그니처 화면).
- `planned_route()`로 레일 위 고스트 화살표.
- `_update_deal_cycle_hud`의 임시 2줄 표기를 `ui/hud_root.gd`로 가져가면 된다.
- 과부하(`overloaded()`) 플래시 자리가 비어 있다. 지금은 시그널만 나간다.

**W6 (편집 화면 · 드래프트)**
- `swap_slots` / `move_card`를 **별개 제스처**로 노출(부록 C-1). 현재 드래그는 `move_card`만 연결돼 있다.
- 미리보기는 `RuneEngine.preview(factory.rune_deck(), seed, 64)`.
- 레벨업 3번째 선택지(현재 "카드 포기 +45 G")를 각인 3택1로 교체.
- 장비 4부위 UI(`factory.equipment`)가 아직 없다. 데이터만 있고 화면이 없다.
- `_build_factory_rail_ghost_slot()`이 미개방 칸용으로 남아 있다(§9.2 4칸=L4, 5칸=L9).

**W9 (성·NPC)**
- §6의 안전화 목록 6건을 각인 상점으로 재정의.

**W10 (마왕전)**
- `_build_boss_factory()`는 이미 v2다. UI(§6.3 고스트 레일·프리뷰)만 얹으면 된다.
- `game._boss_auto_fused_cards()` 삭제 + `demon_lord.auto_fused_cards()`로 일원화.

**W12 (저장·밸런스)**
- `run_cycle_seed` 보존 → 리플레이.
- `core/cycle_deck.gd` / `core/cycle_engine.gd` 로의 파일 이동을 원하면 여기서(§0).
- `overload_rate` 신호(§8.1)로 흐름 각인 드래프트 확률 조정.
