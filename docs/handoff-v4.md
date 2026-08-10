# handoff-v4 — 스테이지 클럭 · 체류 압박 곡선 · 마왕 재보정

> 웨이브 V4 (설계 `docs/GAME_DESIGN_V3.md` §2 · §6 · 부록 B). 2026-08-09.
> **읽는 사람: V5(game.gd 배선) · V6(combat_resolver/enemy) · V7(보스) · V10(정리).**
> 한 줄 요약: **클럭의 알맹이를 스테이지·dwell로 갈아끼웠고 game.gd는 한 글자도 안 건드렸다.**

---

## 0. 이 웨이브가 실제로 한 것

| # | 항목 | 결과 |
|---|---|---|
| ① | `core/stage_clock.gd` 신설 (`StageClock`) | 7일 기한·강림 스케줄·클램프 3개 삭제, dwell/스테이지/총일수 신설 |
| ② | `core/deadline_clock.gd` → **3줄짜리 호환 껍데기** (`class_name DeadlineClock extends StageClock`) | game.gd 62개 호출부 **무수정** |
| ③ | `core/tuning.gd` V3_ 접두사 정리 | 마왕 재보정 5개 + 부채 상한이 정본 이름을 가져갔고 v2 선언은 삭제 |
| ④ | `core/demon_lord.gd` §6.4 재보정 소비 | 각인 4장/개·상한 16 · HP 배율 v3 공식 · 부채 상한 45 · 등급 v3 |
| ⑤ | `test_runner.gd` `--stage-test` 본문 (19항목) + `--deadline-test` 삭제 | 승계 7 · 신설 12 |
| ⑥ | `test/run_all.sh` `--deadline-test` 삭제 | 14종 → 13종 |
| ⑦ | `test/balance_probe.gd` ⑧⑨ 신설 + ③④⑤⑦ v3 재키잉 | **dwell 킬당 효율 실측 확정** |

**game.gd · enemy.gd · combat_resolver.gd · world_grid.gd · status_engine.gd ·
rune_engine.gd · 에셋은 한 줄도 건드리지 않았다.**

---

## 1. StageClock 최종 API

파일 `godot-game/scripts/core/stage_clock.gd` · `class_name StageClock extends RefCounted`.
`DeadlineClock`은 이 클래스를 상속만 하는 빈 껍데기다(로직 0줄).

### 1.1 유지한 v2 계약 — **의미 그대로**

이름도 동작도 v2와 같다. game.gd가 지금 부르는 그대로 계속 부르면 된다.

| 종류 | 이름 | 비고 |
|---|---|---|
| 프로퍼티 | `day_number` | **상한이 사라졌다.** 총 일수 기록 카운터(§2.5) |
| 프로퍼티 | `is_night` `phase_elapsed` `descended` | `descended`의 의미만 "강림 밸브를 밟았다 = 등급 C 고정"으로 바뀌었다 |
| 시그널 | `day_started(day)` `night_started(day)` | 발화 지점·순서 v2와 동일 |
| 진행 | `tick(delta)` `advance_phase()` `force_phase_end()` `reset()` | **`tick`이 멈추는 조건이 없어졌다** |
| 조회 | `phase_duration()` `phase_remaining()` `phase_ratio()` `phase_label()` `day_label()` `day_length()` `run_elapsed()` | 길이는 이제 스테이지별 배열에서 온다 |
| raw | `set_night_raw` `set_day_raw` `set_phase_elapsed_raw` `set_descended_raw` | `set_day_raw`의 `clampi(1, TOTAL_DAYS)`가 `maxi(1, …)`로 바뀌었다 |
| 저장 | `to_snapshot()` `from_snapshot()` | v2 키 4개(`day`/`night`/`elapsed`/`descended`) 유지 + v3 키 5개 추가 |

### 1.2 유지했지만 **의미를 바꾼** 호환 스텁 — V5가 걷어낼 것

game.gd 호출부를 살리려고 남긴 것뿐이다. 각 함수 머리에 `⚠️`로 표시해 두었다.

| 이름 | v3에서 돌려주는 것 | game.gd 호출부 |
|---|---|---|
| `total_days()` | `GameTuning.GRADE_B_MAX_DAYS`(23). v3에 총 일수 예산은 없다 | `:4449` 출발 배너 · `:5724` 낮 배너 · `:8413/8459` 결과 타임라인 · `:8609` 이정표 루프 · `:7122` 계약 NPC 클램프 |
| `days_left()` | **강림 밸브까지 남은 주기 수** | `:7034` 계약 게이트 · `:7069` 계약 패널 · `:8592` HUD "잔여 N일" |
| `run_remaining()` | 강림 밸브까지 남은 **초** | `:6206` `deadline_remaining()` · `:8408` · `:8460` · `:8605` |
| `run_total()` | `run_elapsed() + run_remaining()` (셋이 서로 모순되지 않게) | 직접 호출 없음 |
| `is_final_day()` | **마지막 스테이지**인가 | 없음 |
| `is_final_phase()` | 마지막 스테이지의 밤 + 밸브 1주기 전 | `:5712` "마지막 밤" 배너 |
| `milestone_for(day)` | **항상 `""`** (일수 이정표 폐기) | `:8420` `:8610` |
| `milestones_up_to(day)` | **항상 `[]`** | 없음 |

### 1.3 선언만 남기고 **발화하지 않는** 시그널 2개

```gdscript
signal milestone_reached(id: String, day: int)   # 발화 0회
signal descent_triggered()                       # 발화 0회
```

game.gd `:366` `:367`의 `connect()`가 컴파일되게 하려고 남겼다(설계 부록 B V4 ①).
**부작용**: `_on_clock_milestone`이 안 불려 **월식(`_begin_eclipse`)이 실기에서 꺼졌다.**
의도된 것이다 — 월식은 v3에서 잠식(dwell 임계)으로 대체되고 배선은 V5 몫이다.
균열 개설과 각성 게이트는 `_on_day_started`의 `_maintain_rift_schedule()` /
`_check_first_advancement()`가 매일 부르므로 **살아 있다.**

### 1.4 v3 신설 API

```gdscript
# 상태
var stage: int                    # 1..5 (5스테이지를 깬 뒤에도 5)
var dwell: int                    # 현 스테이지에서 완료한 낮/밤 주기 수
var stages_cleared: int           # 0..5
var descent_used_this_stage: bool

# 시그널
signal dwell_advanced(stage: int, dwell: int)   # 주기가 하나 끝났다
signal stage_started(stage: int, dwell: int)    # 새 스테이지 개시(dwell은 감쇠 후)

# 진행
func advance_stage() -> void              # 보스 격파. dwell = floor(dwell × 0.5)
func add_dwell(delta: int) -> int         # 계약자 NPC 전용 (§6.5). 0 아래로 안 감
func mark_descended() -> void             # 밸브 소모 + 등급 C 고정

# 스테이지 조회
func stage_index() / stage_name() / stage_label() -> …
func day_duration() / night_duration() -> float      # STAGE_DAY/NIGHT_DURATION[stage-1]
func stage_hp_base() / stage_damage_base() -> float
func is_run_complete() -> bool                        # stages_cleared >= 5

# §6.2 dwell 곡선 — **전부 static 순수 함수** (게임 없이 호출 가능)
static func dwell_hp(d) / dwell_damage(d) / dwell_speed(d) -> float
static func dwell_count_bonus(d) -> int
static func dwell_elite_ratio(d) / dwell_xp(d) / dwell_gold(d) -> float
static func dwell_kill_efficiency(d) -> float          # = XP× / HP×
static func night_enemy_limit_at(d) / day_enemy_limit_at(d) / night_raid_burst_at(d) -> int
static func spawn_interval_at(d, night) -> float

# 인스턴스 창구 (현재 dwell + 스테이지 기저 배율을 함께 곱한다)
func enemy_hp_multiplier() -> float        # stage_base × H(dwell)  ← 최종 배율
func enemy_damage_multiplier() / enemy_speed_multiplier() / elite_ratio() -> float
func xp_multiplier() / gold_multiplier() / kill_efficiency() -> float
func enemy_limit() / night_enemy_limit() / day_enemy_limit() / night_raid_burst() -> int
func spawn_interval() -> float
func boss_hp_dwell_multiplier() -> float   # 1 + 0.08 × dwell (§V3-G)

# 균열 · 전조 · 잠식 · 강림 밸브 (조회 계층만. 스폰·연출은 V5/V7)
func rifts_due(d := -1) -> int             # dwell 1·3 · 스테이지 예산 2
func rift_opens_at(d) -> bool
func omen_should_spawn(d := -1) -> bool    # dwell >= 2
func blight_threshold(at_stage := -1) -> int   # [4,4,3,3,2]
func blight_active(d := -1) -> bool
func descent_threshold(at_stage := -1) -> int  # [14,13,12,11,10]
func dwell_remaining() -> int
func descent_valve_ready() -> bool         # ← V5가 폴링할 것. 시그널 없음
func dwell_ratio() / blight_ratio() -> float   # HUD 체류 압박 게이지 0..1
func milestone_for_dwell(d, at_stage := -1) -> String
func dwell_milestones_up_to(d, at_stage := -1) -> Array[String]
func next_dwell_milestone() -> Dictionary  # {"id","dwell","in"} 또는 {}

# raw / 스냅샷
func set_stage_raw(v) / set_dwell_raw(v) / set_stages_cleared_raw(v) -> void
```

`to_snapshot()` 키: `day` `night` `elapsed` `descended` **`stage` `dwell` `stages_cleared`
`descent_used` `run_elapsed`**. game.gd는 이걸 `"deadline_clock"` 키에 넣고 있다 —
V9가 schema 3으로 올릴 때 키 이름을 `"stage_clock"`으로 바꾸면 된다.

---

## 2. V5가 배선할 훅 — 지점별 목록

> 우선순위 순. ①~④는 안 하면 v3가 성립하지 않는다.

| # | game.gd 지점 | 지금 상태 | 붙일 것 |
|---|---|---|---|
| ① | `_process` `:405` `clock.tick(delta)` | 그대로 동작 | 뒤에 `if clock.descent_valve_ready(): _trigger_stage_descent()` 폴링 추가. **클럭은 시그널을 안 쏜다** |
| ② | `_begin_run` `:4408` `clock.reset()` | 그대로 동작 | `_begin_stage(n)` 추출 시 스테이지 2~5는 `clock.advance_stage()`를 부르고 `reset()`을 부르지 **말 것**(총 일수가 날아간다) |
| ③ | `combat_resolver.current_enemy_limit()` `:191` / `current_spawn_interval()` `:185` / `night_raid_burst_count()` `:198` | `game.cycle_number`(=일수)를 곱한다 | `clock.enemy_limit()` / `clock.spawn_interval()` / `clock.night_raid_burst()`로 교체. **일수를 소비하는 물량 식 전멸이 §6.2의 명시 요구** |
| ④ | 몹 체력·피해·속도·XP·골드 스케일 | 일수 기반 | `clock.enemy_hp_multiplier()` / `_damage_` / `_speed_` / `xp_multiplier()` / `gold_multiplier()`. **XP는 반드시 `H^0.5`** — 이게 빠지면 체류 압박 자체가 사라진다 |
| ⑤ | `_spawn_night_omen(day)` / `omen_should_spawn(day)` `game.gd` | `OMEN_START_DAY`(3일차) | `clock.omen_should_spawn()`(dwell ≥ 2)로 교체. `GameTuning.OMEN_START_DAY`는 그때 삭제 |
| ⑥ | `rifts_due(day)` `:4535` · `RIFT_SCHEDULE_DAYS` `:4525` | 2·4·6일차 · 런당 3 | `clock.rifts_due()` · 스테이지당 2 · 런 10. `RIFT_DWELL_SCHEDULE` |
| ⑦ | `_on_clock_milestone` `:5739` · `_begin_eclipse()` | **더 이상 안 불린다** | 잠식으로 재작성: `clock.blight_active()`가 참이 된 순간 켜고 `stage_started`에서 끈다 |
| ⑧ | `_on_descent_triggered` `:5760` → `_trigger_descent()` | **더 이상 안 불린다** | 스테이지 보스를 필드로 내리는 경로로 재사용(칸 +1 · HP ×1.15 · 프리뷰 없음) + `clock.mark_descended()` |
| ⑨ | HUD 기한 패널 `:8579-8613` · 7핍 `:770` | 스텁 값으로 그려진다 | 스테이지/체류 패널로 교체. **체류 압박 게이지 + 명명된 임계선**을 반드시 노출할 것(설계 §10 리스크 #1이 명시). `dwell_ratio()` `blight_ratio()` `next_dwell_milestone()` |
| ⑩ | 온보딩 타임라인 `:4219-4236` · `for index in TOTAL_DAYS` | 남아 있다 | 스테이지 5칸으로 교체. 완료 기준은 `grep "TOTAL_DAYS"` 0건 |
| ⑪ | 계약자 NPC `_pact_shift_day` `:7122` | 일수 ±1 (스텁 클램프에 걸린다) | `clock.add_dwell(±1)` (§6.5 · `PACT_*` 상수) |
| ⑫ | 결과 화면 `:8332` `:7912` `demon_lord.victory_grade(day, descended)` | **이미 v3 등급으로 동작한다** | 문구만 "총 N일 · 등급 X"로 |

---

## 3. dwell 곡선 실측 — 설계 §6.2 확정

`godot --headless --path godot-game -s res://scripts/test/balance_probe.gd` 섹션 ⑧⑨.

### 3.1 킬당 효율 (설계 표 대조 · 허용 편차 0.006)

| d | HP× | 피해× | 속도× | 물량+ | 정예% | XP× | **효율(XP/HP)** | 설계예측 | 편차 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 1.000 | 1.000 | 1.000 | 0 | 0.0 | 1.000 | **1.000** | 1.00 | +0.0000 |
| 1 | 1.152 | 1.074 | 1.012 | 3 | 3.0 | 1.073 | 0.932 | 0.93 | +0.0017 |
| 2 | 1.328 | 1.156 | 1.024 | 6 | 6.0 | 1.152 | 0.868 | 0.87 | −0.0022 |
| 3 | 1.528 | 1.246 | 1.036 | 9 | 9.0 | 1.236 | 0.809 | 0.81 | −0.0010 |
| 4 | 1.752 | 1.344 | 1.048 | 12 | 12.0 | 1.324 | **0.755** | 0.76 | −0.0045 |
| 6 | 2.272 | 1.564 | 1.072 | 18 | 18.0 | 1.507 | 0.663 | 0.66 | +0.0034 |
| 8 | 2.888 | 1.816 | 1.096 | 18 | 24.0 | 1.699 | 0.588 | 0.59 | −0.0016 |
| 10 | 3.600 | 2.100 | 1.120 | 18 | 30.0 | 1.897 | 0.527 | 0.53 | −0.0030 |
| 12 | 4.408 | 2.416 | 1.144 | 18 | 35.0 | 2.100 | **0.476** | 0.48 | −0.0037 |

**판정: 9행 전부 일치.** 설계 §6.2 표는 실측과 소수 둘째 자리에서 같다 —
표는 반올림본이고 식이 정본이다. **설계 문서를 고칠 필요가 없다.**

### 3.2 "레벨 15 도달까지" 역산 (설계 §10 리스크 #1이 지시한 실측)

표준 몹 HP 102.3 · XP 2.00 · 실효 DPS 168.6 · 레벨 15 누적 경험치 619.

| d | 몹HP | 킬시간(초) | 킬당XP | 초당XP | 필요 킬수 | **필요 시간(초)** | 시간 배율 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 102.3 | 0.61 | 2.000 | 3.296 | 310 | **188** | 1.000 |
| 4 | 179.2 | 1.06 | 2.647 | 2.490 | 234 | **249** | 1.324 |
| 8 | 295.5 | 1.75 | 3.399 | 1.939 | 182 | **319** | 1.699 |
| 12 | 451.0 | 2.68 | 4.199 | 1.570 | 147 | **394** | 2.100 |

**판정: 설계 주장 "d=12에서 시간을 두 배 써야 한다"는 ×2.10으로 성립한다.**
시간 배율은 킬당 효율의 정확한 역수다(프로브가 오차 0.001로 단언한다).

### 3.3 이 표에서 나온 판단 3개

1. **체류 압박은 "물러서" 문제가 아니라 "천천히 온다" 문제다.** d=4에서 −24%,
   d=8에서 −41%. 잠식 임계가 스테이지 1에서 d=4인데 그 시점 효율이 0.755로 아직
   부드럽다. **잠식 연출이 세지 않으면 플레이어는 압박을 못 읽는다** — HUD 게이지와
   임계선 라벨(V5 훅 ⑨)이 곡선보다 중요하다.
2. **강림 밸브 d=14의 효율은 0.434.** 정상 플레이가 절대 못 닿는다는 설계 전제는
   맞지만, 그 전에 효율이 반토막 나므로 밸브는 사실상 "이론적 안전망"이다. 삭제해도
   게임은 성립한다(설계 §6.6이 스스로 말한 대로).
3. **물량은 이제 절대 안전하다.** dwell 200에서도 밤 동시 상한 48 (`MAX_ENEMIES` 78).
   v2의 `base + 4×일수`는 12일차에 78을 치받았다. `--stage-test`가 d=0..200을 전수 단언한다.

---

## 4. 마왕 재보정 적용 상태 (설계 §6.4)

| 상수 | v2 | v3 | 적용 | 소비자 |
|---|---:|---:|---|---|
| `BOSS_CARDS_PER_RUNE` | 2 | **4** | ✅ 접두사 제거 · v2 선언 삭제 | `demon_lord.rune_capacity()` |
| `BOSS_RUNE_CAP` | 12 | **16** | ✅ | 〃 |
| `BOSS_HP_PER_DEBT` | 70.0 | **22.0** | ✅ | `demon_lord.boss_base_health()` · **`enemy.gd:119`(값만 반영, 상한은 미적용)** |
| `BOSS_DEBT_CAP` | — | **45** | ⚠️ **절반** | `demon_lord.boss_base_health()`에만 걸렸다 |
| `hp_multiplier` | `1+0.22(day−1)` | **`(1+0.05·총일수)(1+0.15·격파스테이지)`** | ✅ 시그니처 보존(`hp_multiplier(days, stages := -1)`) | `game.gd:7913` `:8677` · `preview()` |
| 승리 등급 | 3/5일 | **13/17/23일 + 밸브=C** | ✅ | `game.gd:7912` `:8332` |
| `BOSS_HP_DAY_STEP` | 0.22 | — | ⚠️ **선언만 생존** | `test_runner.gd --boss-test:1687`만 참조. V7이 지울 것 |

### 남은 한 곳 — **V6/V7이 반드시 처리할 것**

```gdscript
# enemy.gd:119  (현재)
max_health = GameTuning.BOSS_BASE_HP \
    + debts.size() * GameTuning.BOSS_HP_PER_DEBT \
    + boss_items.size() * GameTuning.BOSS_HP_PER_ITEM \
    + power_level * GameTuning.BOSS_HP_PER_POWER
# ↓ 바꿀 것 (단일 진실 원천)
max_health = DemonLord.boss_base_health(debts.size(), boss_items.size(), power_level)
```

`enemy.gd`는 V6/V7 소유라 V4가 열 수 없었다. **그때까지 실기 마왕은 부채 상한 없이
22/장으로 계산된다** — 폭주는 이미 ×3.2 줄었으므로 치명적이지 않지만, 5스테이지
82장 시나리오에서 프로브(4,052)와 실기(4,865)가 813만큼 어긋난다.

### 프로브 ③④가 낸 경고 — V10 밸런스 패스로

| 시나리오 | 실체력 | 목표 창(60~120초) | 판정 |
|---|---:|---|---|
| 1st 직행 (4일) | 1,730 | 1,888 ~ 3,775 | **너무 약하다** (55초) |
| 3st 도달 (11일) | 5,200 | 2,854 ~ 5,709 | 창 안 (109초) |
| 5st 표준 (18일) | 10,450 | 4,422 ~ 8,844 | **너무 세다** (142초) |
| 5st 과파밍 (26일) | 14,913 | 4,422 ~ 8,844 | **너무 세다** (202초) |

DPS 표본이 v2 덱(3종)이라 v3의 7원소 시너지(V2·V6)가 얹히면 위쪽 두 줄은 저절로
창 안으로 들어올 가능성이 크다. **V10이 v3 덱으로 프로브를 다시 돌린 뒤 판단할 것.**
지금 상수를 더 만지면 두 번 만지게 된다.

---

## 5. 테스트 — 삭제 / 승계 표

### `--deadline-test` (삭제됨)

| v2 검사 항목 | 처리 | 근거 |
|---|---|---|
| `early_challenge` 1일차 조기 도전 | **승계** → `--stage-test` | v3에도 유효 |
| `rune_formula` 각인 수 공식 | **승계** (계수 2→4 · 상한 12→16, 표본 10개로 확대) | 〃 |
| `slot_layout` 상위 5장·잔재·정렬 결정성 | **승계** (무변경) | 〃 |
| `omen_gate` 전조 게이트 | **승계 + 강화** — dwell 게이트 0..12 전수 + 균열 dwell 스케줄 + v2 일수 게이트 회귀 | 재키잉(§2.4) |
| `omen_spawn` 실제 밤 스폰 | **승계** (마왕 카드 2장→8장. 재보정으로 2장이면 각인 0개) | 〃 |
| `omen_reward` 격파 → 각인 뜯기 | **승계** (무변경) | 〃 |
| `monotonic` run_elapsed 단조 | **승계** | 〃 |
| `clock_days` "7일에서 멈춘다" | **삭제** → `infinite`가 **정반대**를 단언 | 부록 A-1 ④ |
| `milestones` 일수 이정표 6종 순서 | **삭제** → dwell 이정표 조회로 대체 | §2.4 |
| `descent` 강림 정확히 1회 + 클럭 정지 | **삭제** | 강림 스케줄 폐기 |
| `descent_game` 7일차 밤 끝 = 마왕전 | **삭제** | 〃 |

### `--stage-test` 19항목 (전부 true · exit 0)

```
game_clock  early_challenge  rune_formula  slot_layout  omen_gate  omen_spawn
omen_reward  infinite  dwell_monotone  monotonic  curve  reward_decay  volume
blight  descent_valve  carryover  total_days  phase_len  demon_recal
```

- `infinite` — 100주기 tick, dwell 100 / 총일수 101(>7) / 경과 11,700초 오차 1초 이내 /
  폐기 시그널 2종 발화 0회 / 밸브를 밟은 뒤에도 클럭이 계속 돈다
- `curve` `reward_decay` — 설계 §6.2 표 9행 전수 대조 + 단조 감소 + 상한 3개
- `volume` — d=0..200 전수, `MAX_ENEMIES` 불가침 · d≥6 포화
- `descent_valve` — 스테이지 5개 전부: 임계 −1에서 false, 임계에서 true, 소모 후 false,
  다음 스테이지에서 재무장
- `carryover` — dwell 8종 × `floor(d × 0.5)` + 총일수 이월 + 페이즈 리셋
- `demon_recal` — HP 배율 ×3.5(20일·5스테이지) · v2식보다 작다 · 강림 곱 · 부채 상한 45

**음성 대조 완료**: `DWELL_XP_EXPONENT` 0.5 → 1.0 으로 바꾸면
`curve=false reward_decay=false` + exit 1. 원복 확인.

---

## 6. 알려진 collateral (V4가 만든 것 / 아닌 것)

| 테스트 | 상태 | 원인 | 담당 |
|---|---|---|---|
| `--boss-test` | **하드 실패 + 무한 대기 (실측 확인)** | ⑥⑦ 강림 E2E가 "7일차 밤 끝 = 마왕전"을 단언한다. v3가 그 스케줄을 삭제해 `game.boss_cycle`이 `null`로 남고 `:1512 game.boss_cycle.reset_cycle()`에서 `SCRIPT ERROR: Nonexistent function 'reset_cycle' in base 'Nil'` → `_quit_test_cleanly`에 도달하지 못해 **타임아웃(exit 124)까지 매달린다.** `:1687`의 `expected_scale == (1+0.22×6)×1.15`도 v2 공식 하드코딩 | **V4가 만든 것.** 설계 §8 표가 `--boss-test`를 V7 재작성 대상으로 이미 지정 |

> ⚠️ **`run_all.sh` 전체 실행 시 `--boss-test`가 180초를 통째로 태운다.** 급하면
> `ALL_TESTS`에서 그 줄을 잠시 주석 처리하고 V7이 재작성할 때 되살리는 편이 낫다.
| `--castle-test` | FAIL (`awakening_day6=false tags=0`) | `rune_engine.ELEMENTS`가 v3 7원소로 바뀌어 `_lineage_rune_tag_count("light")`가 0 | **V2가 만든 것.** 설계 §8 표: "`--castle-test` 수정 — **각성 단언 삭제**"(V5) |
| `--v4-test` `--rift-test` `--world-test` `--save-test` `--cycle-test` | PASS | — | — |

`--boss-test`를 지금 초록으로 되돌리려면 `_run_boss_test`의 두 곳을 고쳐야 한다.
V4는 `test_runner.gd`를 V1과 동시 편집 중이라 자기 함수 밖을 건드리지 않았다.
고칠 내용은 이것뿐이다:

1. `:1661-1665`의 "7일차 밤 끝 → 강림" 트리거 → `game._trigger_descent()` 직접 호출로 교체
2. `:1687`의 `(1.0 + GameTuning.BOSS_HP_DAY_STEP * float(GameTuning.TOTAL_DAYS - 1)) * GameTuning.DESCENT_HP_MUL`
   → `game.demon_lord.hp_multiplier(game.clock.day_number)` 와 같은 값인지만 보게 완화
   (그 뒤 `GameTuning.BOSS_HP_DAY_STEP` 선언도 삭제 가능)

---

## 7. 판단 기록 (왜 그렇게 했는가)

| 갈림길 | 선택 | 근거 |
|---|---|---|
| `deadline_clock.gd` 파일명·클래스명 | **유지**(빈 상속 껍데기) + 알맹이를 `stage_clock.gd`로 | game.gd 62개 호출부 무수정이 최우선. 설계가 요구한 파일명 `core/stage_clock.gd`도 동시에 만족. 개명은 V5/V10 |
| 의미 잃은 v2 메서드 | **삭제하지 않고 스텁** | 하나라도 지우면 game.gd가 파스 에러 → 13종 테스트 전부 죽는다 |
| `total_days()` 반환값 | `GRADE_B_MAX_DAYS`(23) | 0/음수를 주면 결과 타임라인의 `cell_w` 나눗셈과 계약 NPC 클램프가 깨진다. 23은 v3에 **실재하는** 유일한 일수 상한(§2.5) |
| `milestone_reached` / `descent_triggered` | **발화 금지** | 일수 이정표 문구가 dwell 사건에 붙으면 배너가 거짓말을 한다. 조회 API만 주고 배선은 V5 |
| 잠식 임계 | `[4,4,3,3,2]` (§6.3 표) | V0의 판단을 재확인함. §2.4 유도식 `max(2,5−stage)`는 3~5스테이지를 전부 2로 뭉갠다 |
| `BOSS_HP_DAY_STEP` | 선언만 남김 | 지우면 `test_runner.gd`가 컴파일 안 된다(§6 참조) |
| 물량 식 이식 위치 | `combat_resolver`가 아니라 **StageClock의 static 함수** | `combat_resolver.gd`는 이번 웨이브 수정 금지. 곡선을 클럭이 소유하면 V5는 호출부 3줄만 바꾸면 된다 |
| dwell 곡선 값 | **착수 초기값 그대로 확정** | 실측이 설계 예측과 오차 0.005 이내. 바꿀 이유가 없다 |

---

## 8. 검증 재현

```bash
godot --headless --path godot-game --editor --quit                 # 오류 0
godot --headless --path godot-game -- --stage-test                 # 19항목 true · exit 0
godot --headless --path godot-game -s res://scripts/test/balance_probe.gd
#   → BALANCE_PROBE_COMPLETE pass=1 dwell_curve=1 dwell_pressure=1
```
