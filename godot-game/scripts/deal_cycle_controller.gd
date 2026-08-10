class_name DealCycleController
extends Node

# =============================================================================
# W2 — 바늘(playhead) 사이클 런타임 (Y2 개정)
# =============================================================================
# 설계 근거: docs/FEEDBACK_Y.md §1.2(칸당 실행 2회 상한) §1.4(과열이 하던 일의 재배치)
#            §2.2(레일 각인) · docs/GAME_DESIGN_V2.md §3.2(바늘 알고리즘)
#            §3.7(빚 RELOAD) §6.2(마왕 RELOAD ×0.6) · handoff-w1.md §3.6/§8.
# v1 원본은 docs/v1-archive/deal_cycle_controller.gd.txt 에 보존.
#
# ## Y2가 걷어낸 것 (§1.4)
# 과열 스택 · 과열 피해 보너스 · 과열 RELOAD 페널티 · 잔열(carry) · 재진입 감쇠가
# 전부 사라졌다. 그 자리를 **한 칸은 한 바퀴에 두 번까지**(`SLOT_EXEC_CAP`)가 산다.
# 컨트롤러가 바깥에 내놓는 진행 지표도 「과열 N/8」에서 **칸별 밟은 횟수**로 갈렸다.
# 죽은 각인(echo/chorus/overlap/link) 동시 발사 경로도 함께 삭제하고, 살아 있는
# 동시 각인은 `twin_cast` 하나만 남았다 — 엔진의 `damage_total`과 실전 피해가
# 어긋나 있던 구멍(handoff-y1 §9-A)이 여기서 막힌다.
#
# ## 단일 진실 원천
# 실전 궤적은 **전부** `RuneEngine.simulate_cycle()`에서 나온다. 이 파일은 궤적을
# 프레임에 펼치기만 한다. 스텝 도중에 다시 굴리지 않는다 — W6의 편집 미리보기가
# 같은 함수를 부르므로, 여기서 자체 근사식을 쓰면 미리보기와 실전이 어긋난다.
#
#   사이클 시작 → rune_deck() + rune_opts()(레일 각인) → simulate_cycle → steps[]
#   스텝마다   → steps[i]를 읽어 카드 재컴파일(바늘 문맥 flow 주입) + 이펙트 생성
#   사이클 끝  → steps 소진(complete / all_used) → 빚 RELOAD 대기 → 다음 시드로 재계획
#
# ⚠️ **레일 각인은 `opts`로만 들어온다.** `rune_deck()`에는 없다(칸이 아니라 레일이
#    소유하기 때문). `_plan_cycle()`이 `factory.rune_opts()`를 병합하지 않으면
#    빨리 감기·모두 힘주기·되돌이가 실전에서 통째로 무동작이 된다.
#
# ## 결정성
# 시드는 `cycle_seed_base + completed_cycles * SEED_STRIDE`로 명시 주입한다.
# 엔진은 randf()/Time을 쓰지 않으므로 같은 (덱, 시드, opts)면 궤적이 100% 같다.
# `cycle_seed_base`를 세이브에 넣으면 리플레이가 공짜다(W12).
#
# ## 설계 대비 조정점 (handoff-w2.md §2에 정리)
#   K-1 처치 주입: `kill_repeat`은 "이 칸으로 적을 처치하면"이 조건인데 처치 여부는
#       카드 실행 **후**에야 확정된다. 계획을 스텝마다 다시 굴리면 결정성과 단일
#       진실 원천이 동시에 깨지므로, **직전 사이클에서 관측한 스텝별 처치 여부**를
#       다음 사이클의 `opts.kills`로 넘긴다. 첫 사이클은 처치 없음으로 계획된다.
#   K-2 아이템 스코프: `*_next`/`*_previous`는 바늘 문맥이 필요한데 계획 시점에는
#       아직 궤적이 없다. 계획은 flow 없이 하고, **실행 시점에** 그 스텝의 flow로
#       카드를 다시 컴파일한다. duration은 계획된 배율(haste 등)을 곱해 유지한다.

const EFFECT_SCRIPT := preload("res://scripts/cycle_skill_effect.gd")

# 사이클마다 시드를 이만큼 띄운다. 소수라 인접 사이클의 궤적이 상관되지 않는다.
const SEED_STRIDE := 7919
# 스텝 최소 표시 시간. 0에 가까운 duration이 프레임을 통째로 건너뛰지 않게 한다.
const MIN_STEP_DURATION := 0.06

# --- 시그널 (W5 HUD · W10 보스전이 붙는 곳) ---
signal slot_entered(index: int, reentry: int)
signal rune_fired(rune_id: String, slot_index: int)
## Y2: `heat_changed` 폐기 → 칸별 밟은 횟수가 바뀔 때 알린다(HUD 미니 스트립의 점).
signal exec_changed(slot_index: int, executed: int)
signal debt_changed(debt: float)
## Y2: 두 번째 인자가 「최고 과열」에서 **한 칸을 최대 몇 번 밟았나**(1~2)로 갈렸다.
signal cycle_completed(steps: int, exec_peak: int)
## 방어 단언(STEP_CAP 도달)에만 발화한다. Y0 이후 실측 도달 0건이다(§1.3).
signal overloaded()

var game: Node
var actor: Node2D
var factory: FactoryDeck
var boss_mode := false
var reload_enabled := true
# 보스전은 RELOAD ×0.6 (§6.2). 전조·플레이어는 1.0.
var reload_scale := 1.0
var cycle_seed_base := 0

# --- 바늘 상태 ---
var current_index := 0          # 지금 실행 중인 칸 (HUD 호환 이름)
var current_reentry := 0        # 이번 사이클에 이 칸을 몇 번째로 실행 중인가 (0 = 첫 실행)
var reload_debt := 0.0          # 누적 RELOAD 빚 (§3.7)
# Y2 신설: 이번 바퀴에 칸을 몇 번 밟았는가. 0~SLOT_EXEC_CAP(2). HUD 미니 스트립의 점.
var exec_counts: Array[int] = []
var peak_exec := 0
var last_step_count := 0
var last_end_reason := ""
var was_overloaded := false

# --- 프레임 진행 상태 (HUD 호환) ---
var group_elapsed := 0.0
var group_duration := 0.0
var reload_duration := 0.0
var reload_remaining := 0.0
var reloading := false
var running := false
var completed_cycles := 0
var active_effects: Array[Node] = []

# --- 계획 ---
var plan: Dictionary = {}
var plan_deck: Array = []
var plan_steps: Array = []
var step_pointer := 0
# K-1: 이번 사이클의 스텝별 처치 관측 → 다음 사이클 계획에 주입
var observed_kills: Array = []
var pending_kills: Array = []
var _kill_baseline := 0

func setup(game_node: Node, actor_node: Node2D, deck: FactoryDeck, is_boss: bool = false, uses_reload: bool = true, seed_base: int = 0) -> void:
	game = game_node
	actor = actor_node
	factory = deck
	boss_mode = is_boss
	reload_enabled = uses_reload
	reload_scale = GameTuning.BOSS_RELOAD_MUL if is_boss else 1.0
	cycle_seed_base = seed_base if seed_base != 0 else _derive_seed_base()
	reset_cycle()

func _derive_seed_base() -> int:
	# 런 전체에 걸쳐 결정적이면서 액터마다 다른 값. 세이브에 넣으면 리플레이가 된다.
	var salt := 0
	if is_instance_valid(actor):
		salt = int(actor.get_instance_id()) & 0xFFFF
	if is_instance_valid(game) and game.get("rng") != null:
		salt += int(game.rng.seed) & 0xFFFF
	return 1000003 + salt * 31 + (7 if boss_mode else 0)

func reset_cycle() -> void:
	for effect: Node in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()
	plan.clear()
	plan_deck.clear()
	plan_steps.clear()
	step_pointer = 0
	current_index = 0
	current_reentry = 0
	reload_debt = 0.0
	_reset_exec_counts()
	peak_exec = 0
	observed_kills.clear()
	pending_kills.clear()
	group_elapsed = 0.0
	group_duration = 0.0
	reload_duration = 0.0
	reload_remaining = 0.0
	reloading = false
	running = false
	was_overloaded = false
	last_end_reason = ""

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(actor) or factory == null:
		return
	if not game.can_cycle_run(boss_mode):
		return
	_cleanup_effects()
	if reloading:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			reloading = false
			running = false
			current_index = 0
		return
	if not running:
		_start_current_step()
		return
	group_elapsed += delta
	if group_elapsed < group_duration:
		return
	_observe_step_kill()
	running = false
	step_pointer += 1
	if step_pointer >= plan_steps.size():
		_finish_cycle()

# -----------------------------------------------------------------------------
# 계획 — RuneEngine.simulate_cycle 한 번
# -----------------------------------------------------------------------------

func _plan_cycle() -> void:
	plan_deck = factory.rune_deck()
	var opts: Dictionary = {"reload_scale": reload_scale}
	# ★ Y2 수리 ①: 레일 각인 주입. `rune_opts()`는 `{"rail_runes": [...]}`를 **참조로**
	#    돌려주고 엔진은 읽기만 한다(handoff-y1 §4). 이 한 줄이 없으면 레일 각인 5종이
	#    실전에서 전부 무동작이고, 편집 미리보기(같은 opts를 쓰는)와도 답이 갈린다.
	opts.merge(factory.rune_opts())
	if not pending_kills.is_empty():
		opts["kills"] = pending_kills
	plan = RuneEngine.simulate_cycle(plan_deck, cycle_seed(), opts)
	plan_steps = plan.get("steps", [])
	step_pointer = 0
	reload_debt = 0.0
	observed_kills.clear()
	_reset_exec_counts()
	emit_signal("debt_changed", reload_debt)

## 칸 수가 런 도중 늘어나므로(레일 개방) 매 사이클 덱 길이에 맞춰 다시 깐다.
func _reset_exec_counts() -> void:
	var slot_count := 0
	if factory != null:
		slot_count = factory.slots.size()
	exec_counts.resize(slot_count)
	for index in slot_count:
		exec_counts[index] = 0

## 이번 바퀴에 이 칸을 몇 번 밟았는가(0~2). HUD 미니 스트립의 「밟은 횟수 점」이 읽는다.
func exec_count(index: int) -> int:
	if index < 0 or index >= exec_counts.size():
		return 0
	return exec_counts[index]

func cycle_seed() -> int:
	return cycle_seed_base + completed_cycles * SEED_STRIDE

## 이번 사이클의 예정 궤적(칸 번호 배열). W5의 레일 고스트 화살표용.
func planned_route() -> Array:
	var route: Array = []
	for entry in plan_steps:
		route.append(int((entry as Dictionary).get("slot", 0)))
	return route

# -----------------------------------------------------------------------------
# 스텝 실행
# -----------------------------------------------------------------------------

func _start_current_step() -> void:
	if factory.slots.is_empty():
		return
	if plan_steps.is_empty():
		_plan_cycle()
		if plan_steps.is_empty():
			return
	if step_pointer == 0:
		game.on_factory_cycle_started(actor, factory, boss_mode)
	step_pointer = clampi(step_pointer, 0, plan_steps.size() - 1)
	var step: Dictionary = plan_steps[step_pointer]

	current_index = clampi(int(step.get("slot", 0)), 0, factory.slots.size() - 1)
	current_reentry = int(step.get("reentry", 0))
	# 밟은 횟수는 엔진이 준 reentry에서 그대로 나온다(reentry 0 = 첫 실행 = 1회째).
	if current_index < exec_counts.size():
		var executed := current_reentry + 1
		if exec_counts[current_index] != executed:
			exec_counts[current_index] = executed
			emit_signal("exec_changed", current_index, executed)
		peak_exec = maxi(peak_exec, executed)
	var step_debt := float(step.get("debt", 0.0))
	if not is_equal_approx(step_debt, reload_debt):
		reload_debt = step_debt
		emit_signal("debt_changed", reload_debt)
	emit_signal("slot_entered", current_index, current_reentry)
	for rune_id in (step.get("fired", []) as Array):
		emit_signal("rune_fired", String(rune_id), current_index)

	var damage_mul := float(step.get("damage_mul", 1.0))
	var flow := _flow_for(step_pointer)
	group_elapsed = 0.0
	group_duration = MIN_STEP_DURATION
	_kill_baseline = _current_kill_count()

	_launch_card(current_index, flow, damage_mul, step, true)
	# ★ Y2 수리 ②: 쌍둥이(twin_cast) 발사 경로 복구.
	#    Y0 이전에는 폐기 id `"echo"`를 찾고 있어 **영원히 false**였다. 엔진의
	#    `damage_total`에는 쌍둥이 피해가 이미 들어 있었으므로 계획 피해 > 실제 피해
	#    괴리가 매 바퀴 쌓였다(handoff-y1 §9-A 최우선 ②).
	#    위력은 엔진과 **같은 식**으로 뽑는다 — `merged_magnitude(twin_cast 사본들)`.
	#    `RuneEngine.TWIN_POWER`(0.5)를 직접 쓰면 사본 2개일 때 엔진이 0.80,
	#    여기가 0.50이 되어 다시 어긋난다.
	var prev_slot := _previous_step_slot(step_pointer)
	if prev_slot >= 0 and _rolled(step, "twin_cast"):
		var twin_power := RuneEngine.passive_magnitude(factory.slots[current_index], "twin_cast")
		if twin_power > 0.0:
			_launch_card(prev_slot, flow, damage_mul * twin_power, step, false)
	running = true

## 이번 스텝에 그 각인이 실제로 터졌는가. 확률 각인만 step.fired에 남는다.
func _rolled(step: Dictionary, rune_id: String) -> bool:
	return (step.get("fired", []) as Array).has(rune_id)

func _launch_card(slot_index: int, flow: Dictionary, damage_mul: float, step: Dictionary, is_lead: bool) -> void:
	var card := factory.compile_slot(slot_index, flow)
	if card.is_empty():
		return
	# 계획 시점 duration 대비 배율(haste 등)을 그대로 옮긴다 (K-2).
	if is_lead:
		card["duration"] = maxf(0.12, float(card.get("duration", 0.5)) * _duration_scale(step, slot_index))
		group_duration = maxf(group_duration, float(card["duration"]))
	card["range"] = float(card.get("range", 0.0)) * maxf(0.25, 1.0 + float(step.get("range_bonus", 0.0)))
	card["pierce"] = maxi(0, int(card.get("pierce", 0)) + int(step.get("pierce_bonus", 0)))
	game.on_cycle_card_started(actor, card, boss_mode)
	var effect := EFFECT_SCRIPT.new()
	effect.setup(game, actor, card, boss_mode, damage_mul)
	gameplay_parent().add_child(effect)
	active_effects.append(effect)

func _duration_scale(step: Dictionary, slot_index: int) -> float:
	if slot_index < 0 or slot_index >= plan_deck.size():
		return 1.0
	var planned_base := float((plan_deck[slot_index] as Dictionary).get("card", {}).get("duration", 0.0))
	if planned_base <= 0.001:
		return 1.0
	return float(step.get("duration", planned_base)) / planned_base

## §5.4 아이템 스코프 재해석용 바늘 문맥.
func _flow_for(pointer: int) -> Dictionary:
	var here := int((plan_steps[pointer] as Dictionary).get("slot", 0))
	var previous := _previous_step_slot(pointer)
	var upcoming := -1
	if pointer + 1 < plan_steps.size():
		upcoming = int((plan_steps[pointer + 1] as Dictionary).get("slot", 0))
	return {"current": here, "next": upcoming, "prev": previous}

func _previous_step_slot(pointer: int) -> int:
	if pointer <= 0:
		return -1
	return int((plan_steps[pointer - 1] as Dictionary).get("slot", 0))

# -----------------------------------------------------------------------------
# 사이클 종료 — 빚 RELOAD (§3.7)
# -----------------------------------------------------------------------------

func _finish_cycle() -> void:
	completed_cycles += 1
	last_step_count = int(plan.get("step_count", plan_steps.size()))
	last_end_reason = String(plan.get("end_reason", "complete"))
	was_overloaded = bool(plan.get("overloaded", false))
	# 엔진이 최종 집계한 칸별 실행 횟수로 봉우리를 확정한다(폴링이 놓친 스텝까지 담긴다).
	for used in (plan.get("slot_exec", []) as Array):
		peak_exec = maxi(peak_exec, int(used))
	reload_debt = float(plan.get("reload_debt", 0.0))
	emit_signal("debt_changed", reload_debt)
	emit_signal("cycle_completed", last_step_count, peak_exec)
	if was_overloaded:
		emit_signal("overloaded")
	pending_kills = observed_kills.duplicate()

	var reload := float(plan.get("reload", 0.0))
	reload_duration = reload
	if reload_enabled and reload > 0.01:
		reload_remaining = reload
		reloading = true
	else:
		reload_remaining = 0.0
		reloading = false

	plan.clear()
	plan_steps.clear()
	plan_deck.clear()
	step_pointer = 0
	peak_exec = 0
	_reset_exec_counts()
	running = false
	current_index = 0
	current_reentry = 0

# -----------------------------------------------------------------------------
# 처치 관측 (K-1)
# -----------------------------------------------------------------------------

func _current_kill_count() -> int:
	if not is_instance_valid(game):
		return 0
	if boss_mode:
		# 마왕·전조는 플레이어를 때린다. 처치 개념이 없으므로 항상 false로 남는다.
		return 0
	return int(game.kills)

func _observe_step_kill() -> void:
	observed_kills.append(_current_kill_count() > _kill_baseline)

# -----------------------------------------------------------------------------
# 조회 (HUD)
# -----------------------------------------------------------------------------

func gameplay_parent() -> Node:
	if is_instance_valid(game) and is_instance_valid(game.gameplay_root):
		return game.gameplay_root
	return get_parent()

func _cleanup_effects() -> void:
	for index in range(active_effects.size() - 1, -1, -1):
		if not is_instance_valid(active_effects[index]):
			active_effects.remove_at(index)

func progress_ratio() -> float:
	if reloading:
		return 1.0 - reload_remaining / maxf(reload_duration, 0.01)
	return clampf(group_elapsed / maxf(group_duration, 0.01), 0.0, 1.0)

func previous_index() -> int:
	if factory == null or factory.slots.is_empty():
		return 0
	var previous := _previous_step_slot(step_pointer)
	if previous >= 0:
		return clampi(previous, 0, factory.slots.size() - 1)
	return wrapi(current_index - 1, 0, factory.slots.size())

func next_index() -> int:
	if factory == null or factory.slots.is_empty():
		return 0
	if step_pointer + 1 < plan_steps.size():
		return clampi(int((plan_steps[step_pointer + 1] as Dictionary).get("slot", 0)), 0, factory.slots.size() - 1)
	return wrapi(current_index + 1, 0, factory.slots.size())

## 이번 바퀴에 지금까지 **한 번이라도 밟은 칸** 수. HUD 툴팁의 "몇 칸을 밟았나".
func executed_slot_count() -> int:
	var used := 0
	for value in exec_counts:
		if value > 0:
			used += 1
	return used

## 지금 빚을 그대로 청산하면 나올 RELOAD(초). HUD의 "빚 게이지"가 쓴다.
## Y2: 과열 항(`1 + 과열 × 0.18`)이 소멸해 빚에 **선형**이다(§1.4).
## 레일 각인 `rail_rest`의 할인은 사이클이 끝날 때 엔진이 확정하므로 여기 예고에는
## 들어오지 않는다 — 예고는 항상 할인 전 상한값이고, 실제 RELOAD는 그보다 짧거나 같다.
func projected_reload() -> float:
	return clampf(reload_debt * reload_scale, 0.0, RuneEngine.RELOAD_CAP)
