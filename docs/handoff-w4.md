# W4 인수인계 — 7일 클럭 · 마왕 성장 · 전조

> 작성일 2026-08-07 · 대상 웨이브: W2(사이클 런타임) · W5(HUD) · W6(드래프트) · W9(성/각성) · W10(마왕전) · W12(저장)
> 검증 상태: `run_all.sh` 7종 + 컴파일 **전부 PASS**, `--capture-world` 육안 확인 완료.

---

## 1. 최종 규칙 (설계 대비 조정점 포함)

### 1.1 7일 클럭

| 항목 | 값 | 비고 |
|---|---|---|
| 낮 / 밤 | **72초 / 45초** | v1 38/25에서 교체. `GameTuning.DAY_DURATION` / `NIGHT_DURATION` |
| 하루 | 117초 | |
| 총 기한 | **7일 = 819초** | `GameTuning.TOTAL_DAYS` |
| 일수 범위 | **1~7 (하드 클램프)** | 8일차는 존재하지 않는다 |
| 시간이 흐르는 조건 | `state == "playing"` 일 때만 | 성 내부·모달·보스전에서는 멈춘다(v1과 동일) |

이정표는 **하루에 정확히 하나**, 2~7일차 총 6개다(설계 §4.1을 6개로 압축).

| 일차 | 이정표 id | 의미 |
|---|---|---|
| 2 | `rift_1` | 균열 #1 |
| 3 | `demon_castle_open` | 마왕성 개방 + **전조 시작** + 1차 각성 + 선공몹 해금 |
| 4 | `rift_2` | 원거리 몹 해금 + 균열 #2 |
| 5 | `eclipse` | 월식 — 잔재 모듈 부여율 100% |
| 6 | `second_awakening` | 2차 각성 + 균열 #3 |
| 7 | `final_day` | 마지막 낮 |

**W4는 이정표를 알리기만 한다.** 균열 배치(W8)·각성(W9)·월식 부여율(W7/W10)은 각 웨이브가
`clock.milestone_reached`에 붙어 구현한다. 배너 텍스트만 미리 넣어 뒀다.

### 1.2 설계와 다르게 결정한 것 (3건)

| # | 설계 문서 | 실제 구현 | 근거 |
|---|---|---|---|
| **A1** | §4.1 "3일차 **마왕성 개방**" | **마왕성 도전은 1일차부터 항상 가능**. `demon_castle_open`은 서사 이정표(배너)로만 남았다 | 지시서 §범위-2 "마왕성 조기 조전은 항상 가능"이 명시적이고, 기존 `--smoke-test`가 1일차에 `_challenge_demon_king()`을 부른다. 게이팅하면 즉시 회귀 |
| **A2** | §6.2 각인 수 = `min(floor(받은 카드/2), 12)` | 분모에 **미선택 각인 조각(rune_shards)** 을 합산: `clamp(floor((카드 + 조각)/2), 0, 12)` | 같은 §6.2가 "짝수 레벨업의 미선택 각인 2장도 여기에 기여한다"고 못박았다. 두 문장을 하나의 풀로 합쳤다 |
| **A3** | §4.2 강림 보정 "각인 +2" | 상한 12를 **넘어설 수 있다** (`12 + 2 = 14` 가능) | 보정의 의미가 "프리뷰 없는 대신 더 강하다"이므로 캡을 다시 씌우면 보정이 무효가 되는 구간이 생긴다 |

### 1.3 남겨 둔 것 (다음 웨이브 몫)

- **NIGHT_\* 습격 물량 상수는 손대지 않았다.** 밤이 25→45초로 1.8배 길어져 밤당 총 스폰량이
  같은 비율로 는다(동시 개체 상한 `current_enemy_limit()`은 그대로라 화면이 터지지는 않는다).
  설계 §9가 새 NIGHT_* 값을 주지 않았고, `--v4-test`의 `early_ranged_gate`가
  `night_one_limit <= 40 / interval >= 0.5 / burst <= 6`을 단언하고 있어 임의 조정은 회귀를 만든다.
  **밸런스 1차 패스(W12)에서 실기 확인 후 조정할 것.**
- **`MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE`은 5 그대로.** 설계는 5→3을 원하지만 이건 W7 데이터
  웨이브 소유이고, `--v4-test`가 `>= 5`를 단언한다. W7이 상수와 테스트를 함께 옮겨야 한다.
- **각인의 실제 실행은 없다.** W4는 "몇 개가 어느 칸에 붙어 있는가"만 소유한다(§3 참조).

---

## 2. 신규 / 수정 파일

### 신규

| 파일 | class_name | 역할 |
|---|---|---|
| `godot-game/scripts/core/deadline_clock.gd` | `DeadlineClock` | 낮/밤·일수·잔여 기한의 **단일 소유자**. RefCounted(씬 트리 밖) |
| `godot-game/scripts/core/demon_lord.gd` | `DemonLord` | 마왕 성장의 **데이터 계층**. 5칸 구성·각인 부여 기록·전조 보상 상태 |
| `docs/handoff-w4.md` | — | 이 문서 |

### 수정

| 파일 | 내용 |
|---|---|
| `scripts/core/tuning.gd` | `DAY_DURATION` 38→**72**, `NIGHT_DURATION` 25→**45**, 신규 `TOTAL_DAYS` / `OMEN_*` 5개 / `BOSS_*` 5개 / `DESCENT_*` 2개 |
| `scripts/game.gd` | 아래 §2.1 |
| `scripts/test/test_runner.gd` | `ROUTINES`에 `--deadline-test` 추가 + `_run_deadline_test()` 신설 (~120줄). **기존 테스트는 한 줄도 고치지 않았다** |
| `scripts/test/run_all.sh` | `ALL_TESTS`에 `--deadline-test:DEADLINE_TEST_COMPLETE` 추가 |

### 2.1 `game.gd` 변경 상세

| 구역 | 함수 / 심볼 | 변경 |
|---|---|---|
| 상태 선언 | `phase_elapsed` `cycle_number` `is_night` | **변수 → 위임 프로퍼티**(get/set이 `clock`을 읽고 쓴다). 신규 `day_number`(= `cycle_number` 별칭), `clock`, `demon_lord`, `active_omen` 계열 7개, `RUN_SCHEMA_VERSION` |
| `_ready` | | `demon_lord.setup(self)` + 클럭 시그널 4개 연결(런당 재연결 없음) |
| `_process` | W4 구역 | `phase_elapsed += delta; if …: _toggle_day_night()` → **`clock.tick(delta)` 한 줄** |
| 낮/밤 | `_toggle_day_night` | `clock.advance_phase()` 위임으로 축소 |
| 낮/밤 | **신규** `_on_night_started` `_on_day_started` `_on_clock_milestone` `_on_descent_triggered` | 시그널 핸들러. 밤 습격 변이·전조 스폰·배너 |
| 전조 | **신규** `omen_should_spawn` `_spawn_night_omen` `_clear_omen` `_omen_defeated` `_show_omen_reward` `_set_omen_reward_index` `_resolve_omen_reward` | §4 |
| 강림 | **신규** `_trigger_descent` | §5 |
| 공개 API | **신규** `boss_growth_preview` `grant_boss_rune_shards` `deadline_remaining` | §6 |
| 런 시작 | `_begin_run` | `clock.reset()` / `demon_lord.reset()` / `_clear_omen()`. 시작 배너 문구 교체 |
| HUD | `_update_hud` | `phase_text` = `"3일차 낮 · 42초 · 잔여 5일"`, `timer_text` 에 `· 남은 기한 mm:ss` 추가. **W5가 일수 바로 대체할 임시 표시** |
| 입력 | `_unhandled_input` | `# === W4 소유: 전조 격파 보상 2택1 ===` 구역 신설(state `"omen_reward"`) |
| 저장 | `_save_run_snapshot` `_read_run_snapshot` `_restore_run_snapshot` | `schema_version:2` 신설. **v1 스냅샷은 읽지 않고 버린다**(크래시 없이 새 런). `deadline_clock` / `demon_lord` / `omen_night_count` 필드 추가 |
| 토스트 | `_show_boss_growth_toast` | 맨 앞에 `demon_lord.sync_runes(rng)` 한 줄 |

### 2.2 ⚠️ 소유권 경계를 넘은 곳 2건 (검토 요망)

설계 §7.3의 소유권 표 기준으로 **내 구역이 아닌 곳을 건드렸다.** 둘 다 가산(additive)이며 기존 분기는 그대로다.

1. **`can_cycle_run()` (§7.3 표에서 W2 소유)** — 한 절을 추가했다.
   ```gdscript
   if is_boss_cycle:
       # W4 추가절
       if state == "playing" and not inside_castle and is_instance_valid(active_omen):
           return true
       return state == "boss"
   ```
   **이유**: 전조는 필드(`playing`)에서 **보스 사이클**(대상 = 플레이어)을 돌려야 한다.
   `boss_mode=false`로 두면 `CycleSkillEffect`가 몹을 때리게 되어 전조가 성립하지 않는다.
   **W2에게**: `cycle_engine.gd`로 옮길 때 이 규칙을 유지할 것.

2. **`_trial_enemy_defeated()` 머리에 3줄 가드** — `camp_id`가 `"omen_"`으로 시작하면 `_omen_defeated()`로 분기하고 return.
   `camp_states`에 없는 키라 원래도 즉시 return 하던 자리다. `_check_trial_camps`와 같은 계열이라
   W4 소유로 해석했지만, W8(균열)이 이 함수를 재작성하면 이 가드를 남겨야 한다.

---

## 3. 마왕 성장 모델 (`DemonLord`)

```
받은 카드 수 = game.rejected_skills.size() + game.boss_advancement_skills.size()
growth_points = 받은 카드 수 + rune_shards          # 미선택 각인 조각
rune_capacity = clamp(growth_points / 2, 0, 12)
rune_count    = max(0, rune_capacity + 강림보정(0 또는 2) - 뜯긴 각인 수)
hp_multiplier(day) = (1 + 0.22 × (day-1)) × (강림이면 1.15)
```

**저장소는 옮기지 않았다.** 카드 목록은 `game.rejected_skills` / `game.boss_items` /
`game.boss_advancement_skills`에 그대로 있고 `DemonLord`는 **조회**한다. 이중 진실 원천을 만들지
않기 위한 의도적 선택이며, W10이 마왕전을 재작성할 때 흡수하면 된다.

`DemonLord`가 **진짜로 소유**하는 것: `granted_runes`(부여 기록) · `stripped_runes` ·
`reclaimed_cards` · `rune_shards` · `descent_rune_bonus`.

### 각인 id 해석 (W1/W2 연결 지점)

W4는 W1의 `core/rune_engine.gd`를 **참조하지 않는다**(동시 작업 중이라 접촉 금지).
대신 카탈로그를 주입받는다:

```gdscript
game.demon_lord.set_rune_catalog(RuneEngine.all_rune_ids())   # W2/W10이 한 줄 호출
```

주입 전에는 `"rune_slot3_07"` 형태의 자리표시자 id가 들어간다. **수(數)·기록·전조 보상은
자리표시자로도 전부 정확하게 동작한다** — 바뀌는 건 프리뷰에 찍히는 이름뿐이다.

---

## 4. 전조(前兆)

| 항목 | 값 |
|---|---|
| 시작 | **3일차 밤부터** 매 밤 1기 (`GameTuning.OMEN_START_DAY` / `OMEN_PER_NIGHT`) |
| 체력 | 같은 조건 일반 몹 **×6** (`OMEN_HEALTH_MUL`) |
| 저항 | `is_camp_elite = true` 를 사후 부여 → 넉백/경직 저항 0.24, 굵은 체력바 |
| 스폰 거리 | 플레이어 기준 430~660px |
| 디스폰 | 없음(camp_id 보유). 밤이 끝나면 `_clear_omen()`이 정리 |
| 시연 내용 | 마왕의 5칸 중 카드가 있는 칸 1개를 1칸짜리 `FactoryDeck` + `DealCycleController(is_boss=true)`로 실행 |
| 보상 | 2택1 — **각인 뜯기** / **카드 회수** (state `"omen_reward"`) |

- 마왕이 아직 카드를 하나도 못 받았으면 `DealCardLibrary.basic_instance()`를 시연한다.
  전조 자체는 등장해야 밤의 리듬이 일차마다 바뀐다.
- **카드 회수**는 `game.rejected_skills`에서 같은 id 한 장을 실제로 제거하고
  `factory.add_inventory()`로 보관함에 넣는다. 합성으로 랭크가 올랐던 카드는 원본 1장만 돌아온다.
- **UI는 최소 구현이다.** `_label`/`_button`/`_panel_style`(공용 위젯 팩토리)만 써서 만든 2버튼
  모달이고, 자체 좌우 포커스 이동을 쓴다(W6의 `_handle_choice_keyboard`를 건드리지 않으려고).
  **W6가 각인 드래프트와 같은 골격으로 재작성할 것.** 상태 처리(`_resolve_omen_reward`)는 그대로 재사용 가능.

---

## 5. 강림

7일차 밤이 끝나는 순간 `clock.descent_triggered` → `game._trigger_descent()`:

1. 전조 정리 → `demon_lord.mark_descended()` (각인 +2)
2. `boss_factory = _build_boss_factory()` (**W10 함수 그대로 호출, 무수정**)
3. `state = "boss_preview"` 를 한 프레임 빌려 `_begin_boss_battle()` 호출 → **프리뷰 화면 없음**
4. 사후 보정: `boss.max_health *= 1.15`, 마왕을 **플레이어 위치 반경 165px**로 이동
5. 필드 몹 전멸은 `_begin_boss_battle()`이 이미 한다

강림 후 클럭은 **정지**한다(`clock.tick()`이 즉시 return). 8일차도 시간 되감기도 없다.

---

## 6. 다음 웨이브가 쓸 API 요약

### 클럭 (`game.clock`, `DeadlineClock`)

```gdscript
# 시그널 — 자기 웨이브 초기화에서 connect 하면 된다
clock.day_started(day: int)
clock.night_started(day: int)
clock.milestone_reached(id: String, day: int)   # rift_1 / demon_castle_open / rift_2 / eclipse / second_awakening / final_day
clock.descent_triggered()

# 조회
clock.day_number            # 1..7   (game.day_number / game.cycle_number 와 같은 값)
clock.is_night              # game.is_night 과 같은 값
clock.phase_remaining()     # 이 낮/밤의 남은 초
clock.phase_ratio()         # 0..1  — 진행 게이지
clock.phase_label()         # "낮" / "밤"
clock.day_label()           # "3일차 밤"
clock.days_left()           # 오늘 포함 남은 날 수
clock.run_elapsed()         # 1일차 낮 0초부터의 총 경과(단조 증가)
clock.run_remaining()       # 남은 기한(초) — game.deadline_remaining() 과 같다
clock.run_total()           # 819.0
clock.total_days()          # 7
clock.is_final_day() / is_final_phase()
clock.milestone_for(day) / milestones_up_to(day)

# 변경 (게임 사건이 아닌 "상태를 그 값으로 두라")
clock.advance_phase()       # 낮->밤 / 밤->다음날. 시그널 발화
clock.force_phase_end()     # 다음 tick에서 반드시 넘어가게 — 계약(§4.4 하루 매매)이 쓸 자리
clock.set_day_raw(n) / set_night_raw(b) / set_phase_elapsed_raw(f)   # 시그널 없음
clock.to_snapshot() / from_snapshot(d)
```

> **W5에게**: 일수 바(`x 500~780, y 12~44`)는 `day_number` / `total_days()` / `phase_ratio()` /
> `phase_remaining()` / `run_remaining()` 다섯 개면 전부 그릴 수 있다.
> `game.gd`의 `_update_hud` 안 `# === W4 임시 ===` 두 줄을 지우고 가져가면 된다.

### 마왕 (`game.demon_lord`, `DemonLord`)

```gdscript
game.boss_growth_preview() -> Dictionary
#   { day, slots:[{index, card, runes}] × 5, filled_slots, rune_count, rune_capacity,
#     stripped, reclaimed, cards_received, items_received, rune_shards,
#     hp_multiplier, reload_multiplier(0.6), descended, residue }

demon_lord.rune_count() / rune_capacity() / runes_on_slot(i) / rune_count_on_slot(i)
demon_lord.slot_layout() / slot_card(i) / filled_slot_count()
demon_lord.ranked_cards()          # expected_power 내림차순 (동률은 id 사전순 — 결정적)
demon_lord.residue_cards() / residue_modules()     # 상위 5장 밖 = 밤 몹 모듈 (§6.4)
demon_lord.auto_fused_cards()      # 같은 id 2장 -> 랭크+1
demon_lord.hp_multiplier(day) / victory_grade(day, was_descent)  # S/A/B/C
demon_lord.set_rune_catalog(ids)   # W1 각인 id 주입
demon_lord.sync_runes(rng)         # 부여 기록을 rune_count()에 맞춤 (no-op 가드 있음)
demon_lord.strip_rune(slot) / can_strip_rune()
demon_lord.reclaim_card(slot) / can_reclaim_card(slot)
demon_lord.to_snapshot() / from_snapshot(d)

game.grant_boss_rune_shards(n)     # W6: 각인 3택1의 미선택 2개를 넘길 때
```

> **W10에게**: `_build_boss_factory()`를 5칸으로 재작성할 때 `demon_lord.slot_layout()`을 그대로
> 쓰면 된다. `game._boss_auto_fused_cards()`는 `demon_lord.auto_fused_cards()`와 규칙이 동일하니
> 재작성 시 game.gd 쪽을 지우고 DemonLord만 남길 것.
> 결과 화면의 승리 등급은 `victory_grade(clock.day_number, clock.descended)`.

> **W9에게**: 각성 조건 `day >= 3` / `day >= 6`은 `clock.milestone_reached`의
> `demon_castle_open` / `second_awakening`에 붙이면 된다.
> 계약(§4.4) NPC의 "하루를 판다/산다"는 `clock.set_day_raw()` + `clock.force_phase_end()` 조합.

### 전조 (`game`)

```gdscript
game.omen_should_spawn(day) -> bool     # day >= 3
game.active_omen                        # 지금 필드의 전조(없으면 null)
game.omen_slot_index                    # 그가 시연 중인 마왕의 칸
game.omen_night_count                   # 이번 런에서 등장한 총 횟수
game.pending_omen_reward                # state == "omen_reward" 동안만 유효
game._resolve_omen_reward(index)        # 0 = 각인 뜯기, 1 = 카드 회수
```

---

## 7. 테스트 결과

`bash godot-game/scripts/test/run_all.sh` (2026-08-07)

| 결과 | 검사 | 비고 |
|---|---|---|
| PASS | compile | `--editor --quit` 오류 0 |
| PASS | world-test | |
| PASS | v4-test | `early_ranged_gate` / `early_day_peace` 포함 전 항목 true |
| PASS | v4-castle-test | |
| PASS | stress-test | enemies=104 bounded=true |
| PASS | smoke-test | state=won |
| PASS | combat-test | |
| PASS | **deadline-test** | 신설 |

`--deadline-test` 출력:

```
DEADLINE_TEST_COMPLETE early_challenge=true rune_formula=true slot_layout=true
  omen_gate=true omen_spawn=true omen_reward=true clock_days=true milestones=true
  descent=true descent_game=true monotonic=true day=7 night_len=72/45 omen_nights=1 runes=2 grade=C
```

| 플래그 | 검사 내용 |
|---|---|
| `early_challenge` | 1일차 낮에 `_challenge_demon_king()` → `boss_preview` 진입, ESC 취소 후 `playing` 복귀 |
| `rune_formula` | 카드/조각 9조합에서 `rune_count()` == `clamp((카드+조각)/2, 0, 12)`, 부여 기록 수와 칸별 합계도 일치 |
| `slot_layout` | 18장 투입 시 5칸이 다 차고 잔재가 남는다. `ranked_cards()`가 두 번 호출해도 같은 순서(결정성) + 화력 내림차순 |
| `omen_gate` | `omen_should_spawn(day)` == `day >= 3` (0~7 전수) |
| `omen_spawn` | 2일차 밤 = 스폰 없음 / 3일차 밤 = 1기, `external_cycle_enabled` · `is_camp_elite` · 1칸 덱 · `can_cycle_run(true)` |
| `omen_reward` | 전조 격파 → 각인 뜯기 자동 확정 → `rune_count` −1, `stripped_runes` +1, `playing` 복귀 |
| `clock_days` | 순수 클럭 1→7 전이. `day_started` 6회(2..7), `night_started` 7회(1..7) |
| `milestones` | 이정표 6개가 **순서대로 한 번씩** |
| `descent` | 강림 1회 발화 + 그 뒤 클럭 정지(추가 tick/advance_phase가 시간을 못 움직임) |
| `descent_game` | 실제 게임 경로: `state == "boss"` + 보스 생성 + `descent_rune_bonus == 2` + HP 배율 2.668 |
| `monotonic` | 819초 전 구간에서 `run_elapsed()` 되감기 0회, 종료값 == `run_total()` |

시각 검수: `godot --path godot-game -- --capture-world` (비headless)
→ HUD `1일차 낮 · 72초 · 잔여 7일` / `모험 00:00 · 남은 기한 13:38` / 배너 `1일차 낮 · 7일 안에 마왕을 쳐라` 확인.

---

## 8. 알아 둘 함정

1. **`game.is_night` / `game.cycle_number` / `game.phase_elapsed`는 더 이상 변수가 아니다.**
   접근자 프로퍼티이고 진짜 값은 `game.clock` 안에 있다. 읽기·쓰기·`in` 연산자·
   `get_property_list()` 전부 v1과 똑같이 동작하는 것을 Godot 4.7.1에서 실측 확인했다
   (`test_runner`의 `game.is_night = true`, `enemy.gd`의 `"cycle_number" in game`이 그대로 산다).
   **다시 평범한 `var`로 되돌리지 말 것** — 클럭과 어긋난 이중 상태가 된다.
2. `cycle_number`는 **1~7로 클램프**된다. v1처럼 무한히 커지지 않는다.
3. 시간은 `state == "playing"`에서만 흐른다. 성/모달/보스전은 정지다.
4. `_process`의 W4 구역은 `clock.tick(delta)` 한 줄이다. **프레임 순서를 바꾸지 말 것.**
5. v1 저장(스냅샷에 `schema_version` 없음)은 읽지 않고 버린다. 크래시는 없고 새 런으로 떨어진다.
   로비의 "이어하기"가 잠깐 보였다가 메뉴로 돌아오는 UX는 **W12가 다듬을 것**.
