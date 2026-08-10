class_name StageClock
extends RefCounted

# =============================================================================
# 스테이지 클럭 — 낮/밤 · dwell(체류) · 스테이지 · 총 일수의 단일 소유자
# =============================================================================
# V4 (설계 GAME_DESIGN_V3.md §2 · §6). v2 `DeadlineClock`(7일 하드 기한)의 재작성이다.
#
# ── v2에서 사라진 것 ─────────────────────────────────────────────────────────
#   * 7일 하드 기한. `day_number`는 **상한 없는 기록 전용 카운터**가 됐다(§2.5).
#   * 강림 스케줄(7일차 밤 끝 = 마왕 강림). v3의 강림은 **dwell 안전 밸브**이고
#     트리거 판정만 여기서 하고 **발화는 하지 않는다**(V5가 배선한다).
#   * 3개 클램프(v2 `:86-94` 일수 상한 · `:197` set_day_raw · `:214` from_snapshot).
#     `--stage-test`가 100주기 무한 진행으로 클램프 0을 단언한다.
#
# ── v3에서 생긴 것 ───────────────────────────────────────────────────────────
#   * `stage` 1..5 · `dwell`(현 스테이지에서 완료한 낮/밤 주기 수) · `stages_cleared`
#   * 낮/밤 길이가 스테이지별 배열(§6.3 표 · GameTuning.STAGE_DAY/NIGHT_DURATION)
#   * §6.2 dwell 곡선 전체를 **static 순수 함수**로 소유한다. 게임 노드를 안 읽으므로
#     `balance_probe`와 `--stage-test`가 트리 밖에서 그대로 호출한다.
#
# ── 계약(반드시 지킬 것) ─────────────────────────────────────────────────────
#   **v2 공개 메서드명·프로퍼티명을 하나도 지우지 않았다.** game.gd에 이 클럭을 읽는
#   호출부가 62개 있고 그 배선 교체는 V5 몫이기 때문이다. 의미가 사라진 v2 API는
#   삭제 대신 "호환 스텁"으로 남기고 각 함수 머리에 v3에서 무엇을 돌려주는지 적었다.
#   호환 스텁 목록: total_days() / days_left() / run_total() / run_remaining() /
#                   is_final_day() / is_final_phase() / milestone_for() / milestones_up_to()
#   시그널 `milestone_reached` · `descent_triggered`는 **선언만 살아 있고 발화하지 않는다**
#   (설계 부록 B V4 ①). game.gd의 connect() 4줄이 그대로 컴파일되게 하려는 것이다.
#
# 씬 트리에 붙지 않는 RefCounted다. 시간은 game.gd `_process`의 tick(delta) 한 줄로만 흐른다.
#
# 불변식
#   * `run_elapsed()`는 절대 되감기지 않는다. raw 세터도 양의 델타만 누적한다.
#   * `dwell`은 tick/advance_phase로는 절대 감소하지 않는다. 줄어드는 경로는
#     `advance_stage()`(×0.5 감쇠)와 계약자 NPC의 `add_dwell(-1)` 둘뿐이다.
#   * 물량 식은 `mini(MAX_ENEMIES, ...)`를 절대 벗어나지 않는다.

## 낮이 시작됐다(=주기가 하나 끝났다). day_number는 이미 증가한 뒤다.
signal day_started(day: int)
## 밤이 시작됐다.
signal night_started(day: int)
## v2 호환 선언. **v3에서는 발화하지 않는다** — 이정표가 일수에서 dwell로 옮겨갔고
## 배너·균열·잠식 배선은 V5가 dwell 조회 API로 다시 붙인다.
signal milestone_reached(id: String, day: int)
## v2 호환 선언. **v3에서는 발화하지 않는다** — 강림은 스케줄이 아니라 안전 밸브다.
## V5가 `descent_valve_ready()`를 폴링해 스테이지 보스를 필드로 내린다(§6.6).
signal descent_triggered()
## v3 신설: 주기가 하나 끝나 dwell이 올랐다. 체류 압박 HUD·잠식·전조의 트리거.
signal dwell_advanced(stage: int, dwell: int)
## v3 신설: 새 스테이지가 시작됐다(dwell은 이미 감쇠된 값).
signal stage_started(stage: int, dwell: int)

# dwell 이정표 id. v2의 일수 이정표(rift_1 … final_day)를 §2.4 표대로 dwell에 재키잉했다.
# **이름을 새로 지었다** — v2 id를 재사용하면 game.gd `_on_clock_milestone`의 배너 문구
# ("5일차 월식")가 dwell 사건에 붙어 거짓말이 된다.
const MILESTONE_RIFT := "stage_rift_%d"
const MILESTONE_OMEN := "stage_omen"
const MILESTONE_BLIGHT := "stage_blight"
const MILESTONE_DESCENT := "stage_descent_valve"

# 낮 동시 개체 상한의 기저. v2는 `combat_resolver.gd:194`에 리터럴 27로 박혀 있다.
# 설계가 낮 기저를 새로 주지 않았으므로 값을 그대로 승계하고 위치만 여기로 모았다
# (밤 기저는 GameTuning.NIGHT_ENEMY_LIMIT_BASE에 이미 있다).
const DAY_ENEMY_LIMIT_BASE := 27
const DAY_SPAWN_INTERVAL_BASE := 1.15
const DAY_SPAWN_INTERVAL_STEP := 0.06
const DAY_SPAWN_INTERVAL_FLOOR := 0.62

# -----------------------------------------------------------------------------
# 상태
# -----------------------------------------------------------------------------

## 현재 스테이지 1..GameTuning.STAGE_COUNT. 5스테이지를 깬 뒤에도 5에 머문다
## (그 다음은 필드가 아니라 마왕전이다 — 부록 A-1 ③).
var stage := 1
## 현재 스테이지에서 **완료한** 낮/밤 전체 주기 수. 0부터. 이 값이 난이도의 전부다(§6.1).
var dwell := 0
## 격파한 스테이지 보스 수 0..5. 마왕 HP 배율의 두 번째 축이다(§6.4).
var stages_cleared := 0
## 총 일수. **기록 전용 · 상한 없음**(§2.5). 승리 등급만 이 값을 본다.
var day_number := 1
var is_night := false
var phase_elapsed := 0.0
## 강림 안전 밸브를 한 번이라도 밟았는가. **등급 C 고정 플래그**(§6.6 · V3-C).
## v2와 달리 이 값이 true여도 **클럭은 멈추지 않는다.**
var descended := false
## 이번 스테이지에서 밸브를 이미 소모했는가. advance_stage()가 푼다.
var descent_used_this_stage := false

## 단조 증가 총 경과 초. 파생이 아니라 누적이다 — 스테이지마다 주기 길이가 달라
## day_number에서 역산할 수 없다.
var _elapsed_total := 0.0


func reset() -> void:
	stage = 1
	dwell = 0
	stages_cleared = 0
	day_number = 1
	is_night = false
	phase_elapsed = 0.0
	descended = false
	descent_used_this_stage = false
	_elapsed_total = 0.0


# =============================================================================
# 시간 진행
# =============================================================================

## game.gd `_process`가 부르는 유일한 진행 함수. v2와 마찬가지로 한 프레임에 최대
## 한 번만 페이즈를 넘긴다. **v2와 달리 멈추는 조건이 없다** — 무한 반복이 v3의 요구다.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	phase_elapsed += delta
	_elapsed_total += delta
	if phase_elapsed >= phase_duration():
		advance_phase()


## 페이즈 전환의 단일 지점. 낮→밤→(주기 완료)→낮.
## 주기 완료 = 밤의 끝. 여기서만 `dwell`과 `day_number`가 오른다.
func advance_phase() -> void:
	# 일찍 넘긴 만큼(force_phase_end·계약 NPC)도 경과에 포함시켜 단조성을 지킨다.
	_elapsed_total += maxf(0.0, phase_duration() - phase_elapsed)
	phase_elapsed = 0.0
	if not is_night:
		is_night = true
		night_started.emit(day_number)
		return
	is_night = false
	dwell += 1
	day_number += 1
	day_started.emit(day_number)
	dwell_advanced.emit(stage, dwell)


## 남은 시간을 0으로 만들어 다음 tick에서 반드시 넘어가게 한다(테스트·계약 NPC용).
func force_phase_end() -> void:
	phase_elapsed = phase_duration()


## 스테이지 보스를 격파했다. 월드 재생성은 V5(game.gd) 몫이고 여기서는 시계만 넘긴다.
##   * dwell은 **floor(dwell × 0.5)**로 감쇠한다(§6.3 채택안).
##   * day_number(총 일수)는 이월된다 — 등급의 기준이므로 리셋하면 안 된다.
##   * descended(등급 C 고정)는 남고 밸브만 재무장한다.
func advance_stage() -> void:
	stages_cleared += 1
	stage = mini(stage + 1, GameTuning.STAGE_COUNT)
	dwell = int(floor(float(dwell) * GameTuning.DWELL_STAGE_CARRYOVER))
	is_night = false
	phase_elapsed = 0.0
	descent_used_this_stage = false
	stage_started.emit(stage, dwell)


## 계약자 NPC(§6.5)와 탐욕/정비 거래가 쓰는 유일한 dwell 조정 창구. 0 아래로 안 내려간다.
func add_dwell(delta_dwell: int) -> int:
	dwell = maxi(0, dwell + delta_dwell)
	return dwell


## 강림 밸브를 소모했다(V5가 스테이지 보스를 필드로 내릴 때 부른다).
func mark_descended() -> void:
	descended = true
	descent_used_this_stage = true


# =============================================================================
# 조회 — 페이즈 · 스테이지
# =============================================================================

func stage_index() -> int:
	return clampi(stage - 1, 0, GameTuning.STAGE_COUNT - 1)


func day_duration() -> float:
	return GameTuning.STAGE_DAY_DURATION[stage_index()]


func night_duration() -> float:
	return GameTuning.STAGE_NIGHT_DURATION[stage_index()]


func phase_duration() -> float:
	return night_duration() if is_night else day_duration()


func phase_remaining() -> float:
	return maxf(0.0, phase_duration() - phase_elapsed)


func phase_ratio() -> float:
	return clampf(phase_elapsed / maxf(phase_duration(), 0.001), 0.0, 1.0)


func phase_label() -> String:
	return "밤" if is_night else "낮"


## "3일차 밤" — v2와 동일 표기. HUD·배너가 쓴다.
func day_label() -> String:
	return "%d일차 %s" % [day_number, phase_label()]


## "2스테이지 시든 숲 · 머문 시간 3" — v3 HUD가 쓸 표기(V5가 붙인다).
## 「체류」는 사용자 피드백 ㉓으로 화면에서 퇴출된 낱말이다. 내부 이름(`dwell`)은
## 그대로 두고 **사람이 읽는 문자열만** 풀어 썼다.
func stage_label() -> String:
	return "%d스테이지 %s · 머문 시간 %d" % [stage, stage_name(), dwell]


func stage_name() -> String:
	return GameTuning.STAGE_NAMES[stage_index()]


## 한 주기(낮+밤)의 길이. 스테이지마다 다르다.
func day_length() -> float:
	return day_duration() + night_duration()


## 1스테이지 낮 0초부터 지금까지 흐른 총 시간. 단조 증가한다.
func run_elapsed() -> float:
	return _elapsed_total


## 5스테이지 전부를 깼는가. V5의 "필드 복귀 없이 즉시 마왕전" 판정.
func is_run_complete() -> bool:
	return stages_cleared >= GameTuning.STAGE_COUNT


# =============================================================================
# 조회 — dwell 곡선 (설계 §6.2) · **static 순수 함수**
# =============================================================================
# 인자 없는 인스턴스 메서드는 현재 dwell을 쓰고, static 쪽은 임의의 d를 받는다.
# balance_probe와 --stage-test가 게임 없이 이 static 함수만으로 표를 만든다.

## H(d) = 1 + 0.14d + 0.012d². 2차항이 "초반 관대 · 후반 무한"을 만든다.
static func dwell_hp(d: int) -> float:
	var f := float(maxi(d, 0))
	return 1.0 + GameTuning.DWELL_HP_LINEAR * f + GameTuning.DWELL_HP_QUAD * f * f


## A(d) = 1 + 0.07d + 0.004d². HP의 절반 기울기.
static func dwell_damage(d: int) -> float:
	var f := float(maxi(d, 0))
	return 1.0 + GameTuning.DWELL_DAMAGE_LINEAR * f + GameTuning.DWELL_DAMAGE_QUAD * f * f


## min(1.30, 1 + 0.012d). **상한 필수** — 속도가 무한이면 회피가 불가능해진다.
static func dwell_speed(d: int) -> float:
	return minf(GameTuning.DWELL_SPEED_CAP, 1.0 + GameTuning.DWELL_SPEED_STEP * float(maxi(d, 0)))


## +3 × min(d, 6). **d=6에서 포화**한다. 그 뒤로는 수가 아니라 질만 는다.
static func dwell_count_bonus(d: int) -> int:
	return GameTuning.DWELL_COUNT_STEP * mini(maxi(d, 0), GameTuning.DWELL_COUNT_SATURATION)


## min(0.35, 0.03d). 개체 수를 안 늘리고 난도를 올리는 유일한 축.
static func dwell_elite_ratio(d: int) -> float:
	return minf(GameTuning.DWELL_ELITE_CAP, GameTuning.DWELL_ELITE_STEP * float(maxi(d, 0)))


## **XP = H(d)^0.5.** 이 한 줄이 체류 압박의 실체다(§6.2).
static func dwell_xp(d: int) -> float:
	return pow(dwell_hp(d), GameTuning.DWELL_XP_EXPONENT)


## 골드 = H(d)^0.4.
static func dwell_gold(d: int) -> float:
	return pow(dwell_hp(d), GameTuning.DWELL_GOLD_EXPONENT)


## 킬당 효율 = XP× / HP×. d=0에서 1.00, d=12에서 0.48. 이 곡선이 v3의 성패다.
static func dwell_kill_efficiency(d: int) -> float:
	return dwell_xp(d) / maxf(dwell_hp(d), 0.0001)


## 밤 동시 개체 상한. **MAX_ENEMIES를 절대 넘지 않는다.**
static func night_enemy_limit_at(d: int) -> int:
	return mini(GameTuning.MAX_ENEMIES, GameTuning.NIGHT_ENEMY_LIMIT_BASE + dwell_count_bonus(d))


## 낮 동시 개체 상한.
static func day_enemy_limit_at(d: int) -> int:
	return mini(GameTuning.MAX_ENEMIES, DAY_ENEMY_LIMIT_BASE + dwell_count_bonus(d))


## 밤 전환 순간의 즉시 소환 수. v2 식을 dwell로 재키잉하고 포화를 씌웠다.
static func night_raid_burst_at(d: int) -> int:
	var saturated := mini(maxi(d, 0), GameTuning.DWELL_COUNT_SATURATION)
	return mini(
		GameTuning.NIGHT_RAID_BURST_CAP,
		GameTuning.NIGHT_RAID_BURST_BASE + GameTuning.NIGHT_RAID_BURST_STEP * saturated
	)


## 스폰 간격(초). v2 식의 `cycle_number`를 dwell로 갈아끼우고 포화를 씌웠다.
static func spawn_interval_at(d: int, night: bool) -> float:
	var saturated := float(mini(maxi(d, 0), GameTuning.DWELL_COUNT_SATURATION))
	if night:
		return clampf(
			GameTuning.NIGHT_SPAWN_INTERVAL_BASE - GameTuning.NIGHT_SPAWN_INTERVAL_STEP * saturated,
			GameTuning.NIGHT_SPAWN_INTERVAL_FLOOR,
			GameTuning.NIGHT_SPAWN_INTERVAL_BASE
		)
	return clampf(
		DAY_SPAWN_INTERVAL_BASE - DAY_SPAWN_INTERVAL_STEP * saturated,
		DAY_SPAWN_INTERVAL_FLOOR,
		DAY_SPAWN_INTERVAL_BASE
	)


# --- 인스턴스 창구 (현재 스테이지의 기저 배율을 함께 곱해 준다) ------------------

func stage_hp_base() -> float:
	return GameTuning.STAGE_HP_BASE[stage_index()]


func stage_damage_base() -> float:
	return GameTuning.STAGE_DAMAGE_BASE[stage_index()]


## 최종 몹 HP 배율 = stage_base × H(dwell). 5스테이지 dwell 4 → ×5.61(§6.3).
func enemy_hp_multiplier() -> float:
	return stage_hp_base() * dwell_hp(dwell)


func enemy_damage_multiplier() -> float:
	return stage_damage_base() * dwell_damage(dwell)


func enemy_speed_multiplier() -> float:
	return dwell_speed(dwell)


func elite_ratio() -> float:
	return dwell_elite_ratio(dwell)


func xp_multiplier() -> float:
	return dwell_xp(dwell)


func gold_multiplier() -> float:
	return dwell_gold(dwell)


func kill_efficiency() -> float:
	return dwell_kill_efficiency(dwell)


func night_enemy_limit() -> int:
	return night_enemy_limit_at(dwell)


func day_enemy_limit() -> int:
	return day_enemy_limit_at(dwell)


func enemy_limit() -> int:
	return night_enemy_limit() if is_night else day_enemy_limit()


func night_raid_burst() -> int:
	return night_raid_burst_at(dwell)


func spawn_interval() -> float:
	return spawn_interval_at(dwell, is_night)


## 스테이지 보스 HP의 dwell 항(§V3-G). 몹(0.14 + 0.012d²)보다 완만한 이유는
## 오래 머문 플레이어를 두 번 벌하지 않기 위해서다.
func boss_hp_dwell_multiplier() -> float:
	return 1.0 + GameTuning.STAGE_BOSS_HP_DWELL_STEP * float(dwell)


# =============================================================================
# 조회 — 균열 · 전조 · 잠식 · 강림 밸브 (설계 §2.4 · §6.6 재키잉)
# =============================================================================
# **데이터·조회 계층까지만이다.** 실제 스폰·개설·필드 물들이기 배선은 V5/V7 몫이다.

## 이번 스테이지에서 dwell d까지 왔을 때 열려 있어야 할 균열 누적 개수.
## v2 `game.rifts_due(day)`의 dwell 판본이며 스테이지 예산 2를 넘지 않는다.
func rifts_due(d: int = -1) -> int:
	var value := _resolve_dwell(d)
	var due := 0
	for scheduled: int in GameTuning.RIFT_DWELL_SCHEDULE:
		if value >= scheduled:
			due += 1
	return mini(due, GameTuning.RIFT_STAGE_BUDGET)


## 정확히 이 dwell에서 균열이 하나 열리는가.
func rift_opens_at(d: int) -> bool:
	return d in GameTuning.RIFT_DWELL_SCHEDULE


## 밤의 전조(前兆) 게이트. v2 "3일차 밤~"이 v3에서 "dwell ≥ 2 · 전 스테이지"가 됐다(§2.4).
## 5스테이지면 마왕에게 넘기는 카드가 v2의 4~5배라 **각인을 뜯을 기회**가 그만큼 늘어야
## 마왕전이 성립한다 — 전조는 v3에서 오히려 더 중요해졌다.
func omen_should_spawn(d: int = -1) -> bool:
	return _resolve_dwell(d) >= GameTuning.OMEN_START_DWELL


## 잠식(蠶食 · 구 월식) 임계. 스테이지별 [4,4,3,3,2](§6.3 표 — V0이 §2.4 유도식 대신 채택).
func blight_threshold(at_stage: int = -1) -> int:
	var index := stage_index() if at_stage < 1 else clampi(at_stage - 1, 0, GameTuning.STAGE_COUNT - 1)
	return GameTuning.STAGE_BLIGHT_DWELL[index]


## 지금 dwell이 잠식 임계를 넘었는가. 스테이지 클리어 시 해제는 advance_stage()의
## dwell 감쇠가 자동으로 만든다(감쇠 후 임계 아래로 떨어진다). V5가 필드 연출을 붙인다.
func blight_active(d: int = -1) -> bool:
	return _resolve_dwell(d) >= blight_threshold()


## 강림 안전 밸브 임계 [14,13,12,11,10](§6.6). dwell 14 = 스테이지 하나에 약 28분이라
## 정상 플레이는 절대 닿지 않는다.
func descent_threshold(at_stage: int = -1) -> int:
	var index := stage_index() if at_stage < 1 else clampi(at_stage - 1, 0, GameTuning.STAGE_COUNT - 1)
	return GameTuning.DWELL_DESCENT[index]


## 밸브까지 남은 주기 수.
func dwell_remaining() -> int:
	return maxi(0, descent_threshold() - dwell)


## 밸브가 지금 당겨져야 하는가. **여기서 시그널을 쏘지 않는다** — V5가 폴링해서
## `_trigger_descent()` 경로로 스테이지 보스를 필드에 내린다(§6.6).
func descent_valve_ready() -> bool:
	if not GameTuning.DESCENT_SAFETY_VALVE_ENABLED:
		return false
	if descent_used_this_stage:
		return false
	return dwell >= descent_threshold()


## 체류 압박 게이지의 0..1 채움값. HUD가 "임계선까지 얼마나 왔는가"를 그린다(§10 리스크 #1:
## **명명된 임계선을 반드시 노출할 것**).
func dwell_ratio() -> float:
	return clampf(float(dwell) / maxf(float(descent_threshold()), 1.0), 0.0, 1.0)


## 잠식 임계까지의 0..1. 게이지 위에 그릴 첫 번째 눈금.
func blight_ratio() -> float:
	return clampf(float(dwell) / maxf(float(blight_threshold()), 1.0), 0.0, 1.0)


## 정확히 이 dwell에서 일어나는 사건 하나. 우선순위: 강림 > 잠식 > 전조 > 균열.
func milestone_for_dwell(d: int, at_stage: int = -1) -> String:
	if d < 0:
		return ""
	if GameTuning.DESCENT_SAFETY_VALVE_ENABLED and d == descent_threshold(at_stage):
		return MILESTONE_DESCENT
	if d == blight_threshold(at_stage):
		return MILESTONE_BLIGHT
	if d == GameTuning.OMEN_START_DWELL:
		return MILESTONE_OMEN
	for index in GameTuning.RIFT_DWELL_SCHEDULE.size():
		if d == GameTuning.RIFT_DWELL_SCHEDULE[index]:
			return MILESTONE_RIFT % (index + 1)
	return ""


## dwell d까지 이미 지난 사건 전부(이어하기 복원·HUD 예고가 쓴다).
func dwell_milestones_up_to(d: int, at_stage: int = -1) -> Array[String]:
	var ids: Array[String] = []
	for step in range(0, maxi(d, 0) + 1):
		var id := milestone_for_dwell(step, at_stage)
		if not id.is_empty():
			ids.append(id)
	return ids


## 다음에 올 사건과 남은 주기 수. `{"id": String, "dwell": int, "in": int}` · 없으면 빈 사전.
func next_dwell_milestone() -> Dictionary:
	var limit := descent_threshold()
	for step in range(dwell + 1, limit + 1):
		var id := milestone_for_dwell(step)
		if not id.is_empty():
			return {"id": id, "dwell": step, "in": step - dwell}
	return {}


# =============================================================================
# v2 호환 스텁 — **V5가 전부 걷어냈다** (2026-08-09)
# =============================================================================
# V4가 game.gd의 62개 호출부를 살려 두려고 남겨 둔 8개(`total_days` `days_left`
# `run_total` `run_remaining` `is_final_day` `is_final_phase` `milestone_for`
# `milestones_up_to`)는 이제 **하나도 없다.** V5가 호출부를 정식 API로 옮겼다:
#
#   total_days()      → 결과 화면·온보딩이 `GameTuning.GRADE_*_MAX_DAYS`를 직접 읽는다
#   days_left()       → `dwell_remaining()` / HUD 체류 압박 게이지 `dwell_ratio()`
#   run_remaining()   → 폐기. v3의 압박 단위는 초가 아니라 주기(dwell)다
#   run_total()       → 폐기(호출부 0)
#   is_final_day()    → `stage >= GameTuning.STAGE_COUNT` 직접 비교
#   is_final_phase()  → 폐기. "마지막 밤" 배너는 잠식/강림 경고가 대신한다
#   milestone_for()   → `milestone_for_dwell()`
#   milestones_up_to()→ `dwell_milestones_up_to()`
#
# 발화하지 않는 시그널 2개(`milestone_reached` `descent_triggered`)는 **남겨 둔다** —
# `--stage-test`의 `infinite` 항목이 "발화 0회"를 단언하는 관측점이기 때문이다.
# game.gd의 connect()는 V5가 지웠다.

# =============================================================================
# 원시 설정 (game.gd 프로퍼티 위임 · 스냅샷 복원 · 테스트 하네스 전용)
# =============================================================================
# 시그널을 발화하지 않는다. 게임 사건이 아니라 "상태를 그 값으로 두라"는 지시다.
# **v2의 `clampi(value, 1, TOTAL_DAYS)` 클램프가 여기서 사라졌다**(설계 부록 B V4 ②).

func set_night_raw(value: bool) -> void:
	is_night = value


func set_day_raw(value: int) -> void:
	day_number = maxi(1, value)


func set_phase_elapsed_raw(value: float) -> void:
	var next := maxf(0.0, value)
	# 되감기지 않는 총 경과: 앞으로 간 만큼만 더한다.
	_elapsed_total += maxf(0.0, next - phase_elapsed)
	phase_elapsed = next


func set_descended_raw(value: bool) -> void:
	descended = value


func set_stage_raw(value: int) -> void:
	stage = clampi(value, 1, GameTuning.STAGE_COUNT)


func set_dwell_raw(value: int) -> void:
	dwell = maxi(0, value)


func set_stages_cleared_raw(value: int) -> void:
	stages_cleared = clampi(value, 0, GameTuning.STAGE_COUNT)


# -----------------------------------------------------------------------------
# 스냅샷 (저장 schema 3 — V9가 game.gd 쪽 버전을 올린다)
# -----------------------------------------------------------------------------
# v2 키(day/night/elapsed/descended)를 그대로 두고 v3 키만 더했다. v2 세이브는
# `RUN_SCHEMA_VERSION` 게이트가 어차피 버리지만, 여기서 죽지는 않게 기본값을 준다.

func to_snapshot() -> Dictionary:
	return {
		"day": day_number,
		"night": is_night,
		"elapsed": phase_elapsed,
		"descended": descended,
		"stage": stage,
		"dwell": dwell,
		"stages_cleared": stages_cleared,
		"descent_used": descent_used_this_stage,
		"run_elapsed": _elapsed_total
	}


func from_snapshot(data: Dictionary) -> void:
	day_number = maxi(1, int(data.get("day", 1)))
	is_night = bool(data.get("night", false))
	phase_elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	descended = bool(data.get("descended", false))
	stage = clampi(int(data.get("stage", 1)), 1, GameTuning.STAGE_COUNT)
	dwell = maxi(0, int(data.get("dwell", 0)))
	stages_cleared = clampi(int(data.get("stages_cleared", 0)), 0, GameTuning.STAGE_COUNT)
	descent_used_this_stage = bool(data.get("descent_used", false))
	_elapsed_total = maxf(0.0, float(data.get("run_elapsed", 0.0)))


func _resolve_dwell(d: int) -> int:
	return dwell if d < 0 else d
