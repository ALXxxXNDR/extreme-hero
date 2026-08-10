class_name SurvivorPlayer
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal shield_changed(charges: int)
signal died

# Ninja Adventure 계열 캐릭터 시트입니다. 한 장에 그림과 흰 실루엣 마스크를 위아래로
# 붙여 구웠기 때문에 텍스처를 하나만 들고도 피격 플래시 같은 색 변조를 만들 수 있습니다.
# 같은 _draw() 안에서 체력바와 게이지까지 같이 그리므로 ShaderMaterial로 물들이면
# UI까지 번집니다. 그래서 마스크를 원하는 색으로 덧그리는 방식을 씁니다.
const PLAYER_SHEETS := {
	"swordsman": preload("res://art/v2/player-swordsman.png"),
	"archer": preload("res://art/v2/player-archer.png"),
	"mage": preload("res://art/v2/player-mage.png")
}
# 셀은 32x32이고 마스크는 그림에서 정확히 192px 아래에 같은 배치로 놓여 있습니다.
const SPRITE_CELL := 32.0
const SPRITE_MASK_OFFSET := 192.0
# 행 0~3은 걷기 프레임, 4는 대기, 5는 공격입니다.
const SPRITE_ROW_IDLE := 4
const SPRITE_ROW_ATTACK := 5

var game: Node
var character_id := "swordsman"
var applied_skills: Array[String] = []
var equipped_weapon_id := ""
var equipped_accessory_id := ""
# =============================================================================
# V8: 계보·각성 폐기 → **보스 트로피** (설계 §5.5 · 부록 B V8 ①③)
# =============================================================================
# 계보 3종과 각성 2단계는 삭제됐다. 아래 두 필드는 V8에서 의미가 바뀐 채 v2 이름
# (`advancement_branch_id` / `advancement_tier`)을 달고 있었고, **V10이 개명했다**:
#   `last_trophy_id` = 마지막으로 획득한 트로피 id (`TrophyLibrary.TROPHIES`)
#   `trophy_count`   = 지금까지 획득한 트로피 수 (0~5)
# V8이 개명하지 못한 이유는 `core/combat_resolver.gd`가 V8의 수정 금지 파일이었기
# 때문이다. V10은 전 파일을 열 수 있어 그 제약이 사라졌다(handoff-v9 §9 #16).
# ⚠️ **저장 키가 아니다.** 두 필드는 저장되지 않고 `trophy_stages`에서 파생된다
#    (`restore_trophies()`). schema 3의 폐기 키 `player_advancement_branch`/`_tier`는
#    이 개명과 무관하며 그 이름 그대로 "되살아나지 않는지"를 검사받는다.
var last_trophy_id := ""
var trophy_count := 0
## 획득한 트로피의 **스테이지 번호**(1~5, 오름차순 · 중복 없음). 스탯 계산의 유일한 입력.
## `TrophyLibrary.merge_effects()`가 이 배열 하나로 누적 효과를 다시 세운다.
var trophy_stages: Array[int] = []
## 트로피 2택1에서 **고른** 특별 카드. v2 `class_skill_*`의 자리를 그대로 쓴다.
var class_skill_id := ""
var class_skill_name := ""
# W12: 시련 캠프 폐기로 항상 빈 배열이지만 저장 스키마 호환(game.gd의
# "player_trophies" 스냅샷 필드) 때문에 데이터는 남긴다. 렌더만 지웠다.
var trophy_orbs: Array[String] = []

var move_speed := 238.0

# =============================================================================
# Y7: 「내가 빨라짐」 (§7.3 `haste_self` · 시간 효과 8종 중 유일하게 플레이어 쪽)
# =============================================================================
# 설계가 지시한 그대로 **짧은 부스트 타이머 하나**다. 새 자원도 새 순회도 없고,
# `_physics_process`의 기존 감쇠 줄에 한 줄, 속도 계산에 한 줄이 전부다.
# 쓰는 카드는 `time_cut` · `phantom_step` · `moon_barrier` · `battle_trance`
# (전부 `impact:"haste_self"`). 겹쳐 걸면 **배율은 큰 쪽 · 시간은 긴 쪽**을 남긴다 —
# 곱하면 네 장 덱에서 순간이동이 된다.
var haste_timer := 0.0
var haste_multiplier := 1.0
## §7.3 표의 「내 이동 +20% 0.8초」.
const HASTE_MULTIPLIER := 1.20
const HASTE_SECONDS := 0.80
## 가속 배지 시트(몹 쪽 `enemy.gd`와 같은 파일 · 행 0 느림 / **행 1 빠름**).
const TIMEFLOW_SHEET := preload("res://art/v2/vfx-timeflow.png")
const TIMEFLOW_CELL := 48.0
const TIMEFLOW_FRAMES := 4
const TIMEFLOW_DRAW := 20.0

## Y7: 가속을 건다(§7.3 `haste_self`). 배율은 큰 쪽, 시간은 긴 쪽만 남는다.
func apply_haste(multiplier: float = HASTE_MULTIPLIER, duration: float = HASTE_SECONDS) -> void:
	haste_multiplier = maxf(haste_multiplier if haste_timer > 0.0 else 1.0, maxf(1.0, multiplier))
	haste_timer = maxf(haste_timer, maxf(0.0, duration))
	queue_redraw()

var max_health := 120.0
var health := 120.0
var damage := 16.0
var attack_interval := 0.58
var attack_range := 116.0
var attack_arc := 1.72
var projectile_speed := 680.0
var projectile_count := 1
var spread_angle := 0.16
var ricochet_count := 0
var pierce_count := 0
var crit_chance := 0.05
var crit_multiplier := 1.8
var pickup_radius := 132.0
var shield_capacity := 0
var shield_charges := 0
var rollback_capacity := 0
var rollback_charges := 0
var holy_pulse_enabled := false
var damage_reduction := 0.0
var life_on_kill := 0.0
var gold_multiplier := 1.0
var thunder_rank := 0
var orbit_blade_count := 0
var xp_multiplier := 1.0
var flame_field_rank := 0
var aura_rank := 0
var dash_damage_rank := 0
var shield_regen_enabled := false
var shield_regen_interval := 18.0

var dash_cooldown_max := 10.0
var dash_cooldown_left := 0.0
var dash_duration := 0.14
var dash_time_left := 0.0
var dash_speed_multiplier := 3.8
var dash_direction := Vector2.DOWN
var dash_hit_ids: Dictionary = {}
var shield_regen_timer := 0.0

var attack_cooldown := 0.18
var invulnerability := 0.0
# 유예 무적(모달 복귀 등)의 시각 표시 전용 타이머입니다. 피격 무효 판정은
# invulnerability 한 곳에서만 하고 이 값은 은은한 깜빡임 링만 그립니다.
var grace_invulnerability := 0.0
var hit_flash := 0.0
var attack_flash := 0.0
var last_move_direction := Vector2.DOWN
var visual_time := 0.0
var step_time := 0.0
var orbit_attack_cooldown := 0.0
var current_attack_direction := Vector2.DOWN
var last_dash_cooldown_duration := 10.0
var target_facing_direction := Vector2.DOWN
var facing_angle := PI * 0.5
var target_facing_angle := PI * 0.5
var turn_speed := 16.0
var displayed_health := 120.0
var trailing_health := 120.0

func setup(game_node: Node, selected_character: String = "swordsman") -> void:
	game = game_node
	character_id = selected_character
	_reset_base_stats()
	health = max_health
	displayed_health = health
	trailing_health = health
	target_facing_direction = Vector2.DOWN
	facing_angle = Vector2.DOWN.angle()
	target_facing_angle = facing_angle

func _ready() -> void:
	# 스프라이트는 이미 nearest x2로 구워져 있어 코드에서 더 키우지 않습니다.
	# 그래도 필터가 켜져 있으면 셀 경계에서 이웃 프레임이 번지므로 nearest로 고정합니다.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 1
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	collision.shape = circle
	add_child(collision)

	var camera := Camera2D.new()
	camera.name = "PlayerCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)
	camera.make_current()

	# V11 시각 QA: 5 → 10. `CycleSkillEffect`(z 8)는 액터를 따라다니는 **불투명 스프라이트**라
	# 딜싸이클이 도는 동안 플레이어를 통째로 덮어 버렸다 — HUD 체력바(z 14)만 떠 있고 캐릭터가
	# 어디 서 있는지 보이지 않았다. 이펙트의 알파나 반경을 깎는 대신 플레이어를 위로 올린다:
	# 이펙트 크기는 **카드의 실제 판정 범위**를 말하는 정보라 줄이면 안 되기 때문이다.
	# 새 순서 — 바닥 표시 2 < 마물 3 < 투사체·탄 6 < 보스 7 < 카드 이펙트·참격 8 < 잔상 9 <
	# **플레이어 10** < 월드 텍스트 14 < 상자 18. 플레이어는 이제 필드에서 언제나 읽힌다.
	z_index = 10
	add_to_group("player")
	health_changed.emit(health, max_health)
	shield_changed.emit(shield_charges)
	queue_redraw()

func _physics_process(delta: float) -> void:
	visual_time += delta
	invulnerability = maxf(0.0, invulnerability - delta)
	grace_invulnerability = maxf(0.0, grace_invulnerability - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_flash = maxf(0.0, attack_flash - delta)
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	# Y7: 가속 부스트 감쇠(§7.3 `haste_self`). 기존 타이머 줄에 그대로 얹는다.
	if haste_timer > 0.0:
		haste_timer = maxf(0.0, haste_timer - delta)
		if haste_timer <= 0.0:
			haste_multiplier = 1.0
	if shield_regen_enabled and shield_charges < shield_capacity:
		shield_regen_timer -= delta
		if shield_regen_timer <= 0.0:
			shield_charges += 1
			shield_regen_timer = shield_regen_interval
			shield_changed.emit(shield_charges)
			if is_instance_valid(game):
				game.spawn_burst(global_position, GamePalette.BLUE, 8, 100.0, 0.25)

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 0.01:
		set_facing_direction(input_direction)
		step_time += delta * 9.0
	# 방향은 즉시 끊어 바꾸지 않고 가장 짧은 각도로 빠르게 회전합니다.
	var turn_weight := 1.0 - exp(-turn_speed * delta)
	facing_angle = lerp_angle(facing_angle, target_facing_angle, turn_weight)
	last_move_direction = Vector2.from_angle(facing_angle).normalized()
	current_attack_direction = last_move_direction
	displayed_health = move_toward(displayed_health, health, max_health * delta * 3.2)
	var trail_speed := max_health * delta * (0.82 if trailing_health > health else 2.4)
	trailing_health = move_toward(trailing_health, health, trail_speed)
	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0.0 and is_instance_valid(game) and game.can_player_dash():
		_start_dash(input_direction)
	var speed_multiplier := 1.0
	if is_instance_valid(game):
		speed_multiplier = game.get_player_speed_multiplier(global_position)
	# Y7: 가속은 아이템·상태 배율 **위에** 곱한다. 감속(한)에 걸린 채로 가속 카드를
	# 쓰면 상쇄되는 것이 맞다 — 둘 다 이동 배율이라 같은 축에서 다투게 둔다.
	if haste_timer > 0.0:
		speed_multiplier *= haste_multiplier
	if dash_time_left > 0.0:
		dash_time_left = maxf(0.0, dash_time_left - delta)
		velocity = dash_direction * move_speed * dash_speed_multiplier
		if is_instance_valid(game):
			game.process_dash_damage(dash_hit_ids)
	else:
		velocity = input_direction.normalized() * move_speed * speed_multiplier
	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(game) and not game.can_player_stand(global_position):
		global_position = previous_position
		velocity = Vector2.ZERO
		dash_time_left = 0.0
	global_position = global_position.round()

	# 딜싸이클 공장이 공격을 전담합니다. 구버전 자동공격은 호환 모드에서만 실행합니다.
	attack_cooldown -= delta
	var factory_mode: bool = is_instance_valid(game) and game.has_method("uses_factory_combat") and bool(game.uses_factory_combat())
	if not factory_mode and dash_time_left <= 0.0 and attack_cooldown <= 0.0 and is_instance_valid(game) and game.can_player_attack():
		attack_flash = 0.14
		current_attack_direction = last_move_direction.normalized()
		game.perform_character_attack(self)
		attack_cooldown = attack_interval
	queue_redraw()

func set_facing_direction(direction: Vector2, immediate: bool = false) -> void:
	if direction.length_squared() < 0.01:
		return
	target_facing_direction = direction.normalized()
	target_facing_angle = target_facing_direction.angle()
	if immediate:
		facing_angle = target_facing_angle
		last_move_direction = target_facing_direction
		current_attack_direction = target_facing_direction

func _start_dash(input_direction: Vector2) -> void:
	dash_direction = input_direction.normalized() if input_direction.length_squared() > 0.01 else last_move_direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.DOWN
	set_facing_direction(dash_direction, true)
	dash_time_left = dash_duration
	last_dash_cooldown_duration = dash_cooldown_max
	if is_instance_valid(game) and game.has_method("get_factory_dash_multiplier"):
		last_dash_cooldown_duration *= game.get_factory_dash_multiplier()
	dash_cooldown_left = last_dash_cooldown_duration
	dash_hit_ids.clear()
	if is_instance_valid(game):
		game.on_player_dash_started(self)

func start_cycle_dash() -> void:
	var direction := last_move_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	dash_direction = direction
	dash_time_left = maxf(dash_time_left, 0.12)
	invulnerability = maxf(invulnerability, 0.1)
	dash_hit_ids.clear()
	if is_instance_valid(game):
		game.spawn_burst(global_position, GamePalette.CYAN, 8, 105.0, 0.2)

# 외부(game.gd)에서 짧은 유예 무적을 주는 단일 진입점입니다.
# 대시 무적과 완전히 같은 경로(take_damage의 invulnerability 검사)를 재사용하므로
# 피격 무효 판정 규칙이 두 곳으로 갈라지지 않습니다.
# show_grace=true면 대시 잔상과 구분되는 은은한 깜빡임 링을 함께 표시합니다.
func grant_invulnerability(duration: float, show_grace: bool = true) -> void:
	if duration <= 0.0:
		return
	invulnerability = maxf(invulnerability, duration)
	if show_grace:
		grace_invulnerability = maxf(grace_invulnerability, duration)
	queue_redraw()

func grant_cycle_shield(amount: int) -> void:
	if amount <= 0:
		return
	shield_charges = mini(6, shield_charges + amount)
	shield_changed.emit(shield_charges)
	queue_redraw()

## `ignore_shield`는 **도트 전용**이다(V10 · handoff-v7 §12-2의 판정).
##
## 수호막 1충전의 의미는 "한 방을 막는다"이고, 그 값을 정한 것은 보스 패턴의 크기다
## (트로피 2종이 각각 +1을 주고 상한이 6이다). 도트 플러시는 한 방이 아니라
## 0.6초치 누적 틱이라 같은 자원으로 갚게 두면 **독에 걸리는 순간 수호막이 통째로
## 증발한다** — 6초짜리 독 하나가 플러시 10번이므로 상한 6을 다 먹고도 남는다.
## B·B+ 보스(2·4스테이지)가 독을 주 무기로 쓰므로 "수호막 +1" 트로피가 하필
## 그 두 전투에서만 무의미해지는 구조였다.
##
## 이 함수는 도트를 이미 "한 방이 아닌 것"으로 다루고 있었다 — 호출부(`_tick_player_status`)가
## 무적 시간을 원복해 도트가 i-frame을 **주지 못하게** 막는다. 수호막만 그 판단에서
## 빠져 있었고 V10이 맞췄다. 넉백도 같은 이유로 건너뛴다(도트에는 방향이 없다).
func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, ignore_shield: bool = false) -> void:
	if dash_time_left > 0.0 or invulnerability > 0.0 or health <= 0.0:
		return
	if shield_charges > 0 and not ignore_shield:
		shield_charges -= 1
		shield_changed.emit(shield_charges)
		invulnerability = 0.42
		if is_instance_valid(game):
			game.spawn_burst(global_position, GamePalette.BLUE, 14, 170.0, 0.35)
			game.show_world_text(global_position - Vector2(0.0, 36.0), "막음!", GamePalette.BLUE)
			game.play_sound("hit", -3.0)
		queue_redraw()
		return

	var actual_damage := amount * maxf(0.35, 1.0 - damage_reduction)
	health -= actual_damage
	invulnerability = 0.68
	hit_flash = 0.19
	if source_position != Vector2.ZERO:
		var knockback := source_position.direction_to(global_position) * 26.0
		var candidate := global_position + knockback
		if not is_instance_valid(game) or game.can_player_stand(candidate):
			global_position = candidate
	health_changed.emit(maxf(health, 0.0), max_health)
	if is_instance_valid(game):
		game.spawn_burst(global_position, GamePalette.RED, 14, 185.0, 0.36)
		game.show_world_text(global_position - Vector2(0.0, 40.0), "-%d" % int(actual_damage), GamePalette.RED)
		game.play_sound("hurt", -1.0)
		game.shake_camera(7.0, 0.18)

	if health <= 0.0:
		if rollback_charges > 0:
			rollback_charges -= 1
			health = max_health * 0.52
			invulnerability = 1.8
			health_changed.emit(health, max_health)
			if is_instance_valid(game):
				game.spawn_burst(global_position, GamePalette.YELLOW, 30, 260.0, 0.72)
				game.show_world_text(global_position - Vector2(0.0, 55.0), "불사조의 맹세!", GamePalette.YELLOW, 23)
		else:
			health = 0.0
			died.emit()
	queue_redraw()

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)

func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func apply_skill(skill_id: String) -> void:
	var old_shield_capacity := shield_capacity
	var old_rollback_capacity := rollback_capacity
	applied_skills.append(skill_id)
	_rebuild_stats()
	shield_charges += maxi(shield_capacity - old_shield_capacity, 0)
	rollback_charges += maxi(rollback_capacity - old_rollback_capacity, 0)
	shield_changed.emit(shield_charges)
	if shield_regen_enabled and shield_regen_timer <= 0.0:
		shield_regen_timer = shield_regen_interval
	queue_redraw()

func remove_last_skill() -> String:
	if applied_skills.is_empty():
		return ""
	var removed: String = String(applied_skills.pop_back())
	_rebuild_stats()
	shield_changed.emit(shield_charges)
	return removed

func get_skill_rank(skill_id: String) -> int:
	return applied_skills.count(skill_id)

func get_skill_ranks() -> Dictionary:
	var ranks := {}
	for skill_id: String in applied_skills:
		ranks[skill_id] = int(ranks.get(skill_id, 0)) + 1
	return ranks

func consume_skill(skill_id: String) -> int:
	var removed := applied_skills.count(skill_id)
	while applied_skills.has(skill_id):
		applied_skills.erase(skill_id)
	_rebuild_stats()
	queue_redraw()
	return removed

func add_trophy_orb(direction: String) -> void:
	if not trophy_orbs.has(direction):
		trophy_orbs.append(direction)
		queue_redraw()

func clear_trophy_orbs() -> void:
	trophy_orbs.clear()
	queue_redraw()

# -----------------------------------------------------------------------------
# V8: 보스 트로피 — v2 `apply_advancement(branch, tier)`의 자리
# -----------------------------------------------------------------------------
# 설계 §5.5: "보스를 잡으면 ①중립 스탯 보너스 1개(고정) + ②특별 카드 2택1을 받는다."
# 이 함수가 하는 것은 ①뿐이다. ②는 game.gd의 트로피 2택1 모달이 처리한다.
#
# `tier1_effect`/`tier2_effect`가 쓰던 스키마를 그대로 받으므로 `_apply_class_effect()`
# 본문은 **한 줄도 바뀌지 않았다**(설계 §5.5 "함수는 그대로 재사용하고 입력만 교체").
# 회복은 v2 각성과 같다 — 보스 격파 보상의 완전 회복(§2.1)과 자리가 겹쳐도 무해하다.
func apply_trophy(trophy: Dictionary) -> void:
	var stage := int(trophy.get("stage", 0))
	if stage <= 0 or trophy_stages.has(stage):
		return
	trophy_stages.append(stage)
	trophy_stages.sort()
	last_trophy_id = String(trophy.get("id", ""))
	trophy_count = trophy_stages.size()
	_rebuild_stats()
	shield_charges = shield_capacity
	rollback_charges = rollback_capacity
	shield_changed.emit(shield_charges)
	heal_full()
	queue_redraw()

## 저장 복원(V9) · 테스트 전용. 효과를 처음부터 다시 쌓는다(누적이 아니라 치환).
func restore_trophies(stages: Array) -> void:
	trophy_stages.clear()
	for value in stages:
		var stage := int(value)
		if stage > 0 and not trophy_stages.has(stage):
			trophy_stages.append(stage)
	trophy_stages.sort()
	trophy_count = trophy_stages.size()
	if trophy_stages.is_empty():
		last_trophy_id = ""
	else:
		last_trophy_id = String(TrophyLibrary.for_stage(trophy_stages[trophy_stages.size() - 1]).get("id", ""))
	_rebuild_stats()
	queue_redraw()

## 지금까지 쌓인 트로피 효과 한 덩어리. HUD·결과 화면·테스트가 이것만 보면 된다.
func trophy_effect_summary() -> Dictionary:
	return TrophyLibrary.merge_effects(trophy_stages)

func equip_item(item_id: String) -> String:
	var item := ItemLibrary.by_id(item_id)
	if item.is_empty():
		return ""
	var old_shield_capacity := shield_capacity
	var old_rollback_capacity := rollback_capacity
	var previous := ""
	if item["slot"] == "weapon":
		previous = equipped_weapon_id
		equipped_weapon_id = item_id
	else:
		previous = equipped_accessory_id
		equipped_accessory_id = item_id
	_rebuild_stats()
	shield_charges += maxi(shield_capacity - old_shield_capacity, 0)
	rollback_charges += maxi(rollback_capacity - old_rollback_capacity, 0)
	shield_changed.emit(shield_charges)
	return previous

## V8: 계보 이름(성기사·광전사·창기사)이 사라졌으므로 **기저 직업명 하나뿐**이다.
## 트로피는 이름을 바꾸지 않는다 — 트로피는 직업이 아니라 전리품이다(설계 §5.5).
func get_character_name() -> String:
	match character_id:
		"archer": return "방랑 궁사"
		"mage": return "별빛 마법사"
		_: return "왕국 검사"

func _rebuild_stats() -> void:
	var health_ratio := clampf(health / maxf(max_health, 1.0), 0.05, 1.0)
	_reset_base_stats()
	for skill_id: String in applied_skills:
		_apply_skill_stats(skill_id)
	for item_id: String in [equipped_weapon_id, equipped_accessory_id]:
		if not item_id.is_empty():
			_apply_item_stats(ItemLibrary.by_id(item_id))
	# V8: 계보 tier1/tier2 효과 두 겹 → **보스 트로피 누적 효과 한 겹**(§5.5).
	# 곱연산 키는 `merge_effects`가 이미 곱해 두므로 여기서 한 번만 적용하면 된다.
	if not trophy_stages.is_empty():
		_apply_class_effect(TrophyLibrary.merge_effects(trophy_stages))
	health = clampf(max_health * health_ratio, 1.0, max_health)
	shield_charges = mini(shield_charges, shield_capacity)
	rollback_charges = mini(rollback_charges, rollback_capacity)
	dash_cooldown_left = minf(dash_cooldown_left, dash_cooldown_max)
	health_changed.emit(health, max_health)

func _reset_base_stats() -> void:
	projectile_count = 1
	spread_angle = 0.16
	ricochet_count = 0
	pierce_count = 0
	crit_chance = 0.05
	crit_multiplier = 1.8
	pickup_radius = 132.0
	shield_capacity = 0
	rollback_capacity = 0
	holy_pulse_enabled = false
	damage_reduction = 0.0
	life_on_kill = 0.0
	gold_multiplier = 1.0
	thunder_rank = 0
	orbit_blade_count = 0
	xp_multiplier = 1.0
	flame_field_rank = 0
	aura_rank = 0
	dash_damage_rank = 0
	dash_cooldown_max = 10.0
	dash_duration = 0.14
	dash_speed_multiplier = 3.8
	shield_regen_enabled = false
	shield_regen_interval = 18.0
	match character_id:
		"archer":
			move_speed = 252.0
			max_health = 92.0
			damage = 12.0
			attack_interval = 0.44
			attack_range = 560.0
			attack_arc = 0.0
			projectile_speed = 780.0
		"mage":
			move_speed = 226.0
			max_health = 84.0
			damage = 21.0
			attack_interval = 0.78
			attack_range = 176.0
			attack_arc = TAU
			projectile_speed = 520.0
		_:
			move_speed = 238.0
			max_health = 120.0
			damage = 16.0
			attack_interval = 0.58
			attack_range = 132.0
			attack_arc = 2.18
			projectile_speed = 680.0

func _apply_skill_stats(skill_id: String) -> void:
	match skill_id:
		"multithread":
			projectile_count += 1
			attack_arc += 0.14
		"firewall":
			shield_capacity += 2
		"overclock":
			damage *= 1.34
			attack_interval *= 0.81
			move_speed += 16.0
		"cache":
			pickup_radius += 120.0
			max_health += 24.0
		"recursion":
			ricochet_count += 1
		"targeting":
			crit_chance += 0.22
			pierce_count += 1
		"rollback":
			rollback_capacity += 1
		"hotfix":
			holy_pulse_enabled = true
		"cleave":
			damage *= 1.12
			attack_range += 18.0
			attack_arc += 0.22
		"haste":
			move_speed += 22.0
			attack_interval *= 0.88
		"blood_pact":
			life_on_kill += 1.2
			damage += 2.0
		"frost_armor":
			damage_reduction = minf(0.45, damage_reduction + 0.08)
			max_health += 18.0
		"thunder":
			thunder_rank += 1
		"guardian_blade":
			orbit_blade_count += 1
		"flame_field":
			flame_field_rank += 1
		"aura":
			aura_rank += 1
		"wisdom":
			xp_multiplier += 0.25
		"dash_training":
			dash_cooldown_max *= 0.84
			dash_speed_multiplier += 0.28
		"dash_blade":
			dash_damage_rank += 1
		"moon_barrier":
			shield_capacity += 1
			shield_regen_enabled = true
			shield_regen_interval *= 0.86

func _apply_item_stats(item: Dictionary) -> void:
	if item.is_empty():
		return
	damage += float(item.get("damage", 0.0))
	attack_range += float(item.get("range", 0.0))
	move_speed += float(item.get("speed", 0.0))
	max_health = maxf(45.0, max_health + float(item.get("health", 0.0)))
	pickup_radius += float(item.get("pickup", 0.0))
	crit_chance += float(item.get("crit", 0.0))
	pierce_count += int(item.get("pierce", 0))
	ricochet_count += int(item.get("ricochet", 0))
	shield_capacity += int(item.get("shield", 0))
	rollback_capacity += int(item.get("rollback", 0))
	attack_interval *= float(item.get("interval_mul", 1.0))
	projectile_count += int(item.get("projectile", 0))

func _apply_class_effect(effect: Dictionary) -> void:
	if effect.is_empty():
		return
	damage += float(effect.get("damage", 0.0))
	damage *= float(effect.get("damage_mul", 1.0))
	attack_range += float(effect.get("range", 0.0))
	move_speed += float(effect.get("speed", 0.0))
	max_health += float(effect.get("health", 0.0))
	pickup_radius += float(effect.get("pickup", 0.0))
	crit_chance += float(effect.get("crit", 0.0))
	pierce_count += int(effect.get("pierce", 0))
	ricochet_count += int(effect.get("ricochet", 0))
	shield_capacity += int(effect.get("shield", 0))
	rollback_capacity += int(effect.get("rollback", 0))
	projectile_count += int(effect.get("projectile", 0))
	orbit_blade_count += int(effect.get("orbit", 0))
	life_on_kill += float(effect.get("life_on_kill", 0.0))
	attack_interval *= float(effect.get("interval_mul", 1.0))
	if bool(effect.get("holy_pulse", false)):
		holy_pulse_enabled = true

func _draw() -> void:
	var bob := 0.0 if velocity.length_squared() < 1.0 else sin(step_time) * 2.0
	# trim은 몸통 장식이 아니라 궤도 검과 공격 범위 미리보기가 계속 쓰는 색이라 남깁니다.
	var trim := GamePalette.YELLOW
	# V8: 계보 색 → **마지막 트로피 색**. 전설 트로피(스테이지 4·5)를 쥐면 v2 2차 각성의
	# 후광을 그대로 두른다 — 연출 자산을 버리지 않고 의미만 갈아끼운 자리다(§5.5).
	if not trophy_stages.is_empty():
		var trophy_color := Color(String(TrophyLibrary.by_id(last_trophy_id).get("color", "f4d35e")))
		trim = trophy_color
		if String(TrophyLibrary.by_id(last_trophy_id).get("grade", "")) == "legend":
			draw_circle(Vector2.ZERO, 34.0 + sin(visual_time * 4.0) * 2.0, Color(trophy_color, 0.12))
			draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 24, Color(trophy_color, 0.72), 2.0)
	if character_id == "archer":
		trim = GamePalette.GREEN
	elif character_id == "mage":
		trim = GamePalette.MAGENTA

	# 바닥 그림자는 스프라이트가 아니라 도형으로 남깁니다. 시트에 그림자가 없어서
	# 이게 빠지면 캐릭터가 지면에서 떠 보입니다.
	draw_rect(Rect2(-16.0, 13.0, 32.0, 8.0), Color(0.04, 0.05, 0.08, 0.45), true)

	# 트윈을 새로 만들지 않고 이미 누적되고 있는 step_time에서 걷기 프레임을 뽑습니다.
	# 공격 중이면 공격 행이 우선이고, 사실상 멈춰 있으면 대기 행으로 떨어집니다.
	var sheet: Texture2D = PLAYER_SHEETS.get(character_id, PLAYER_SHEETS["swordsman"])
	var sprite_row := SPRITE_ROW_IDLE
	if attack_flash > 0.0:
		sprite_row = SPRITE_ROW_ATTACK
	elif velocity.length_squared() > 4.0:
		sprite_row = wrapi(int(step_time), 0, 4)
	var sprite_column := _sprite_column(_cardinal_facing())
	# 발밑이 +8, 머리가 -24가 되도록 놓아야 반지름 14인 충돌원과 실루엣이 맞습니다.
	var sprite_dest := Rect2(-16.0, -24.0 + bob, 32.0, 32.0)
	var sprite_source := Rect2(float(sprite_column) * SPRITE_CELL, float(sprite_row) * SPRITE_CELL, SPRITE_CELL, SPRITE_CELL)
	draw_texture_rect_region(sheet, sprite_dest, sprite_source, Color.WHITE)

	# 색 변조는 같은 셀의 흰 실루엣 마스크를 덧그려서 만듭니다. 이렇게 해야
	# 아래에서 그리는 체력바나 대시 게이지까지 같이 물드는 일이 없습니다.
	var mask_source := Rect2(sprite_source.position + Vector2(0.0, SPRITE_MASK_OFFSET), sprite_source.size)
	if hit_flash > 0.0:
		draw_texture_rect_region(sheet, sprite_dest, mask_source, Color(1.0, 1.0, 1.0, clampf(hit_flash / 0.19, 0.0, 1.0) * 0.85))
	if dash_time_left > 0.0:
		draw_texture_rect_region(sheet, sprite_dest, mask_source, Color(GamePalette.CYAN, 0.38))

	if character_id == "swordsman":
		# 공장 모드의 공격 범위·잔상은 CycleSkillEffect 한 곳에서만 그려 중복 이펙트를 막습니다.
		var preview_direction := last_move_direction.normalized()
		var preview_start := preview_direction.angle() - attack_arc * 0.5
		var preview_end := preview_direction.angle() + attack_arc * 0.5
		var factory_mode: bool = is_instance_valid(game) and game.has_method("uses_factory_combat") and bool(game.uses_factory_combat())
		if attack_flash > 0.0 and not factory_mode:
			var preview_points := PackedVector2Array([Vector2.ZERO])
			for preview_index in 13:
				preview_points.append(Vector2.from_angle(lerpf(preview_start, preview_end, float(preview_index) / 12.0)) * attack_range)
			draw_colored_polygon(preview_points, Color(trim, 0.07))
			draw_arc(Vector2.ZERO, attack_range, preview_start, preview_end, 20, Color(trim, 0.55), 2.0)

	# Y7: 가속 배지(`vfx-timeflow.png` **행 1 = 빠름** · handoff-ya §5).
	# 몹 쪽(행 0 = 느림)과 같은 시트, 같은 규약이다 — 4칸을 남은 시간에 나눠 담아
	# 한 방향으로만 진행한다. 시간 함수로 순환시키지 않는다.
	if haste_timer > 0.0:
		var haste_progress := 1.0 - clampf(haste_timer / HASTE_SECONDS, 0.0, 1.0)
		var haste_frame := clampi(int(haste_progress * float(TIMEFLOW_FRAMES)), 0, TIMEFLOW_FRAMES - 1)
		draw_texture_rect_region(
			TIMEFLOW_SHEET,
			Rect2(-10.0, -74.0, TIMEFLOW_DRAW, TIMEFLOW_DRAW),
			Rect2(float(haste_frame) * TIMEFLOW_CELL, TIMEFLOW_CELL, TIMEFLOW_CELL, TIMEFLOW_CELL),
			GamePalette.YELLOW)

	for index in shield_charges:
		draw_rect(Rect2(-20.0 + index * 9.0, -42.0, 7.0, 7.0), GamePalette.BLUE, true)
	for index in rollback_charges:
		draw_rect(Rect2(13.0 - index * 9.0, -42.0, 7.0, 7.0), GamePalette.YELLOW, true)

	# 플레이어 체력은 화면 구석이 아니라 캐릭터 위에서 부드럽게 감소합니다.
	var health_ratio := clampf(displayed_health / maxf(max_health, 1.0), 0.0, 1.0)
	var trail_ratio := clampf(trailing_health / maxf(max_health, 1.0), 0.0, 1.0)
	var health_color := GamePalette.GREEN if health_ratio > 0.52 else GamePalette.YELLOW if health_ratio > 0.25 else GamePalette.RED
	draw_rect(Rect2(-29.0, -55.0, 58.0, 9.0), Color("080c14e8"), true)
	draw_rect(Rect2(-27.0, -53.0, 54.0 * trail_ratio, 5.0), Color("fff3d099"), true)
	draw_rect(Rect2(-27.0, -53.0, 54.0 * health_ratio, 5.0), health_color, true)
	draw_rect(Rect2(-29.0, -55.0, 58.0, 9.0), GamePalette.STONE_LIGHT.darkened(0.35), false, 1.0)

	# 모달 복귀 유예 무적(game.gd MODAL_RETURN_INVULN)의 은은한 시각 피드백입니다.
	# 대시 무적은 아래 잔상으로 이미 읽히므로 대시 중에는 겹쳐 그리지 않습니다.
	if grace_invulnerability > 0.0 and dash_time_left <= 0.0:
		var grace_pulse := 0.26 + 0.2 * absf(sin(visual_time * 17.0))
		draw_circle(Vector2.ZERO, 24.0, Color(GamePalette.CYAN, grace_pulse * 0.34))
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 22, Color(GamePalette.CYAN, grace_pulse), 2.0)
	if dash_time_left > 0.0:
		draw_circle(Vector2.ZERO, 25.0, Color(GamePalette.CYAN, 0.2))
		draw_line(-dash_direction * 18.0, -dash_direction * 48.0, Color(GamePalette.CYAN, 0.75), 6.0)
	if dash_cooldown_left > 0.0:
		var dash_ready_ratio := 1.0 - dash_cooldown_left / maxf(last_dash_cooldown_duration, 0.01)
		draw_rect(Rect2(-24.0, -66.0, 48.0, 7.0), Color("0b1019d9"), true)
		draw_rect(Rect2(-22.0, -64.0, 44.0 * dash_ready_ratio, 3.0), GamePalette.CYAN if dash_ready_ratio > 0.72 else GamePalette.YELLOW, true)

	for index in orbit_blade_count:
		var orbit_angle := visual_time * 2.6 + TAU * float(index) / float(maxi(orbit_blade_count, 1))
		var orbit_position := Vector2.from_angle(orbit_angle) * 58.0
		draw_line(orbit_position - Vector2.from_angle(orbit_angle + 0.8) * 8.0, orbit_position + Vector2.from_angle(orbit_angle + 0.8) * 8.0, trim, 5.0)
		draw_line(orbit_position, orbit_position + Vector2.from_angle(orbit_angle + 0.8) * 12.0, Color.WHITE, 2.0)

	# W12: 시련 구슬 공전 렌더를 삭제했다 — 시련 캠프가 폐기돼(v2 §5.5) `trophy_orbs`가
	# 항상 비어 있으므로 0회 도는 죽은 루프였다. 데이터(`trophy_orbs`·`add_trophy_orb()`·
	# `clear_trophy_orbs()`)는 저장 스키마 호환 때문에 남긴다(handoff-w9 §1.3).
	# 원본 렌더는 docs/v1-archive/player_v1.gd.txt.

func _cardinal_facing() -> Vector2:
	var facing := last_move_direction.normalized()
	return Vector2.DOWN if facing.length_squared() < 0.01 else facing

# 시트의 열 배치는 0=아래(정면) 1=위(뒤) 2=왼쪽 3=오른쪽입니다. 대각선일 때는
# 성분이 더 큰 쪽을 따라가야 옆모습과 정면이 어중간하게 튀지 않습니다.
func _sprite_column(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 3 if facing.x > 0.0 else 2
	return 0 if facing.y > 0.0 else 1
