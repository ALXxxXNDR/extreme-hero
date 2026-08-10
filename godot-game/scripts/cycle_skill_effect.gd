class_name CycleSkillEffect
extends Node2D

# W11 시각 테마 교체: v1 생성 아틀라스를 버리고 Ninja Adventure VFX 시트를 쓴다.
# 전부 nearest 2배로 미리 구워둔 파일이라 코드에서 다시 확대 배율을 곱하지 않는다.
const VFX_CORE := preload("res://art/v2/vfx-core.png")
const VFX_EXPLOSION := preload("res://art/v2/vfx-explosion.png")
const VFX_PROJECTILE := preload("res://art/v2/vfx-projectile.png")
const VFX_SHIELD := preload("res://art/v2/vfx-shield.png")
const VFX_SMOKE := preload("res://art/v2/vfx-smoke.png")
# NA 시트의 참격과 화염구는 원본이 +X(오른쪽)를 향해 그려져 있다.
# 코드와 판정의 방향 기준축도 Vector2.RIGHT(각도 0)이므로, 스프라이트 회전은
# 반드시 이 원본 축을 빼서 구해야 바라보는 방향과 일치한다.
# v1은 이 축이 -X여서 한동안 참격이 180도 뒤집혀 나갔다. 시트를 갈면 여기부터 확인할 것.
const VFX_SLASH_SOURCE_DIRECTION := Vector2.RIGHT
# 각 시트의 셀 크기. vfx-core는 256x256 안에 4행 4프레임, 셀 64x64.
const VFX_CORE_CELL := 64.0
const VFX_EXPLOSION_CELL := 80.0
const VFX_PROJECTILE_CELL := 32.0
const VFX_SMOKE_CELL := 64.0
const VFX_SHIELD_CELL := Vector2(48.0, 52.0)

var game: Node
var actor: Node2D
var card: Dictionary = {}
var boss_mode := false
var elapsed := 0.0
var duration := 0.5
var action_duration := 0.35
var total_pulses := 1
var triggered_pulses: Dictionary = {}
var pulse_hits: Dictionary = {}
var effect_color := Color.WHITE
var fixed_position := false
var action_origin := Vector2.ZERO
var redraw_timer := 0.0
# Y2: 각인·공명·레일 각인이 만든 이번 스텝의 피해 배율. 판정과 연출이 같은 값을 본다.
# (과열·재진입 항은 §1.4에서 삭제됐다 — 배율은 이제 각인과 공명에서만 나온다.)
var damage_mul := 1.0
# 강한 스텝 강조용 0~1 값. damage_mul이 1.0을 얼마나 넘겼는지로만 정한다.
var power_glow := 0.0

func setup(game_node: Node, actor_node: Node2D, compiled_card: Dictionary, is_boss: bool = false, step_damage_mul: float = 1.0) -> void:
	game = game_node
	actor = actor_node
	card = compiled_card.duplicate(true)
	boss_mode = is_boss
	damage_mul = maxf(0.0, step_damage_mul)
	power_glow = clampf((damage_mul - 1.0) / 1.2, 0.0, 1.0)
	duration = maxf(0.12, float(card.get("duration", 0.5)))
	action_duration = maxf(0.06, duration * clampf(float(card.get("action_ratio", 0.7)), 0.08, 1.0))
	total_pulses = maxi(1, int(card.get("hits", 1)) * int(card.get("casts", 1)))
	effect_color = Color(String(card.get("color", "f4d35e")))
	# 배율이 클수록 카드 펄스가 금색으로 달아오른다 — 「이 칸이 지금 세다」의 유일한 연출 신호.
	if power_glow > 0.0:
		effect_color = effect_color.lerp(Color("ffb347"), power_glow * 0.55).lightened(power_glow * 0.18)
	fixed_position = String(card.get("kind", "melee")) == "ground"
	if is_instance_valid(actor):
		action_origin = actor.global_position
		if boss_mode and is_instance_valid(game) and is_instance_valid(game.player):
			action_origin = game.player.global_position

func _ready() -> void:
	z_index = 8
	# 도트 원본이라 확대할 때 보간이 끼면 뭉개진다. 이 노드가 그리는 모든 시트에 적용된다.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if fixed_position:
		global_position = action_origin
	elif is_instance_valid(actor):
		global_position = actor.global_position
	if String(card.get("kind", "")) == "shield":
		_trigger_pulse(0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(game):
		queue_free()
		return
	elapsed += delta
	if not fixed_position:
		global_position = actor.global_position
	var kind := String(card.get("kind", "melee"))
	if elapsed <= action_duration:
		if not boss_mode and kind in ["melee", "dash"]:
			var flash_value = actor.get("attack_flash")
			if flash_value != null:
				actor.set("attack_flash", maxf(float(flash_value), 0.06))
		var pulse_index := current_pulse_index()
		if kind in ["melee", "dash"]:
			_process_live_melee(pulse_index)
		elif not triggered_pulses.has(pulse_index):
			_trigger_pulse(pulse_index)
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer = 0.035
		queue_redraw()
	if elapsed >= duration:
		queue_free()

func _process_live_melee(pulse_index: int) -> void:
	if not triggered_pulses.has(pulse_index):
		triggered_pulses[pulse_index] = true
		pulse_hits[pulse_index] = {}
		_fire_impact_signature()
		if String(card.get("kind", "")) == "dash" and not boss_mode and actor.has_method("start_cycle_dash"):
			actor.start_cycle_dash()
	var hit_ids: Dictionary = pulse_hits.get(pulse_index, {})
	var facing := _current_facing()
	game.apply_cycle_melee(actor, card, hit_ids, boss_mode, facing, damage_mul)
	pulse_hits[pulse_index] = hit_ids

func _trigger_pulse(pulse_index: int) -> void:
	if triggered_pulses.has(pulse_index):
		return
	triggered_pulses[pulse_index] = true
	_fire_impact_signature()
	game.trigger_cycle_card_pulse(actor, card, boss_mode, pulse_index, action_origin, damage_mul)

# =============================================================================
# Y7: 충격 프로필의 시전 쪽 신호 (§7.1 원칙 1·2 · §7.3)
# =============================================================================
# 카드 한 장이 처음 터질 때 **딱 한 번** 낸다. 두 가지다.
#   ① 충격 버스트(`vfx-burst.png`) — `combat_resolver`에서 걷어낸 카메라 흔들림의
#      대체물이다. 화면을 흔드는 대신 터진 자리가 6프레임 동안 핀다.
#   ② 「내가 빨라짐」(`haste_self`) — 대상이 아니라 시전자에게 붙는 유일한 프로필.
#
# **여기서 내는 이유**: 근접·돌진 카드 10장은 `trigger_cycle_card_pulse`를 아예
# 타지 않는다(`_process_live_melee`로 갈라진다). 그 함수 안에 넣으면 「반달 베기」·
# 「독의 처형」 같은 대표 카드가 통째로 신호를 빠뜨린다 — 실제로 그렇게 짰다가
# 갈라지는 것을 보고 이리로 옮겼다.
#
# 펄스가 여럿인 카드(최대 9히트)라도 버스트는 하나다. 히트마다 터뜨리면
# 「기름 안개」 한 장이 9노드를 만들어 78기 환경의 연출 예산을 혼자 먹는다.
var impact_signature_fired := false

func _fire_impact_signature() -> void:
	if impact_signature_fired or boss_mode:
		return
	impact_signature_fired = true
	var impact := String(card.get("impact", ""))
	if impact == "" or not is_instance_valid(game) or not is_instance_valid(actor):
		return
	var kind := String(card.get("kind", "melee"))
	var origin: Vector2 = actor.global_position
	if kind in ["area", "orbit", "ground"]:
		origin = game.cycle_pulse_center(actor, card, 0, action_origin)
	game.spawn_impact_burst(origin, effect_color, impact)
	if impact == "haste_self":
		game.apply_player_haste()

func current_pulse_index() -> int:
	var pulse_span := action_duration / float(maxi(total_pulses, 1))
	return clampi(floori(elapsed / maxf(pulse_span, 0.001)), 0, maxi(total_pulses - 1, 0))

func _current_facing() -> Vector2:
	if boss_mode and is_instance_valid(game.player):
		return actor.global_position.direction_to(game.player.global_position)
	var facing := Vector2.DOWN
	var actor_facing = actor.get("last_move_direction")
	if actor_facing is Vector2:
		facing = actor_facing
	if facing.length_squared() < 0.01:
		facing = Vector2.DOWN
	return facing.normalized()

# 이펙트를 그리는 중심과 실제 피해가 들어가는 중심을 game.gd 한 곳에서 받아옵니다.
func _impact_origin(kind: String) -> Vector2:
	if boss_mode or kind not in ["area", "orbit", "ground"]:
		return Vector2.ZERO
	if not is_instance_valid(game) or not is_instance_valid(actor):
		return Vector2.ZERO
	return to_local(game.cycle_pulse_center(actor, card, current_pulse_index(), action_origin))

func _impact_radius(kind: String) -> float:
	if not boss_mode and kind in ["area", "orbit", "ground"] and is_instance_valid(game):
		return game.cycle_pulse_radius(card)
	return float(card.get("range", 120.0))

func _draw() -> void:
	var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var action_progress := clampf(elapsed / maxf(action_duration, 0.01), 0.0, 1.0)
	if elapsed > action_duration:
		# 공격 동작은 끝났지만 지속시간(후딜레이)이 남았다는 작은 정지 표시.
		var delay_alpha := (1.0 - progress) * 0.52
		for index in 3:
			draw_rect(Rect2(-11.0 + index * 8.0, -42.0, 4.0, 4.0), Color(effect_color, delay_alpha), true)
		return
	var facing := _current_facing()
	var angle := facing.angle()
	var kind := String(card.get("kind", "melee"))
	var origin := _impact_origin(kind)
	var radius := _impact_radius(kind)
	var alpha := 0.14 + sin(action_progress * PI) * 0.32
	_draw_generated_vfx(kind, facing, radius, action_progress, origin)
	# Y2 위력 피드백: 배율이 클수록 굵고 밝은 링이 카드 펄스를 감싼다.
	# 본격 온도계·레일 색온도는 W5의 HUD 몫이고, 여기서는 "지금 세게 들어갔다"만 알린다.
	if power_glow > 0.02:
		var glow_radius := radius * (0.34 + power_glow * 0.2) + sin(action_progress * PI) * 10.0
		draw_arc(origin, glow_radius, 0.0, TAU, 26, Color(Color("ffb347"), power_glow * (0.34 + alpha * 0.5)), 2.0 + power_glow * 3.0, false)
	# W11부터 연출의 주인공은 스프라이트다. 아래 절차적 선은 스프라이트가 못 주는
	# 정보(타격 방향, 판정 반경)만 얇게 남기고 나머지는 알파를 눌러 배경으로 물린다.
	match kind:
		"melee", "dash":
			# 칼날 선은 지금 어느 각도로 베고 있는지 읽는 정보라 가늘게 유지한다.
			var arc := float(card.get("arc", 1.8))
			var swing_direction := -1.0 if int(floor(action_progress * float(maxi(total_pulses, 1)))) % 2 == 1 else 1.0
			var local_progress := fmod(action_progress * float(maxi(total_pulses, 1)), 1.0)
			var blade_angle := lerpf(angle - arc * 0.46 * swing_direction, angle + arc * 0.46 * swing_direction, local_progress)
			draw_line(Vector2.from_angle(blade_angle) * 24.0, Vector2.from_angle(blade_angle) * radius, Color(effect_color, 0.35), 2.0)
		"area", "orbit":
			# 판정 반경만 알려주는 얇은 테두리. 원형 참격 스프라이트가 본체를 맡는다.
			draw_arc(origin, radius, action_progress * TAU, action_progress * TAU + PI * 1.55, 28, Color(effect_color, minf(alpha, 0.22)), 2.0)
			for index in 4:
				var rune_angle := TAU * float(index) / 4.0 + action_progress * TAU
				var rune_position := origin + Vector2.from_angle(rune_angle) * radius * 0.86
				draw_rect(Rect2(rune_position - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(effect_color, 0.3), true)
		"ground":
			draw_arc(origin, radius * (0.42 + sin(action_progress * PI) * 0.28), 0.0, TAU, 24, Color(Color.WHITE, 0.2), 1.0)
			for index in 4:
				var rune := origin + Vector2.from_angle(TAU * float(index) / 4.0 + action_progress * 1.8) * radius * 0.7
				draw_rect(Rect2(rune - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(effect_color, 0.3), true)
		"projectile":
			# 궤적선은 화염구가 지나갈 길만 흐리게 깔아준다.
			draw_line(facing * 20.0, facing * minf(radius, 360.0), Color(effect_color, minf(alpha, 0.2)), 2.0)
		"shield":
			draw_arc(Vector2.ZERO, 44.0 + action_progress * 8.0, 0.0, TAU, 24, Color(effect_color, (1.0 - action_progress) * 0.22), 2.0)
	_draw_signature(String(card.get("id", "")), facing, radius, action_progress, alpha, origin)

# 스프라이트 modulate는 곱연산이라 원소색이 어두우면 그림 자체가 죽는다.
# 살짝 밝힌 원소색을 곱해 흰 코어는 원소색으로 물들고 밝은 부분은 살아남게 한다.
# 철·빙·뇌·광·혈·화 20종 스킬을 색만으로 구분하는 것이 이번 웨이브의 핵심이다.
func _vfx_tint(alpha: float) -> Color:
	return Color(effect_color.lightened(0.22), clampf(alpha, 0.0, 1.0))

# 폭발 시트만 다른 물감을 쓴다. modulate는 곱연산이라, 철·혈처럼 어두운 원소색을
# 그대로 곱하면 주황 불덩이가 진흙색으로 죽는다(첫 캡처에서 실제로 그랬다).
# 흰색에서 원소색 쪽으로 살짝만 끌어와 밝기는 지키고 색조만 입힌다.
func _vfx_flame_tint(alpha: float) -> Color:
	return Color(Color.WHITE.lerp(effect_color, 0.45).lightened(0.1), clampf(alpha, 0.0, 1.0))

func _draw_generated_vfx(kind: String, facing: Vector2, radius: float, progress: float, origin: Vector2) -> void:
	# 투사체와 보호막은 전용 시트를 쓰므로 코어 시트 분기를 타지 않는다.
	if kind == "projectile":
		_draw_projectile_vfx(facing, radius, progress)
		return
	if kind == "shield":
		_draw_shield_vfx(progress)
		return
	# vfx-core 행 배정: 0 참격, 1 원형 참격, 2 마법진, 3 낙뢰.
	var card_id := String(card.get("id", ""))
	var row := 1
	if kind in ["melee", "dash"]:
		row = 0
	elif kind == "ground" or card_id == "flame_field":
		row = 2
	elif kind == "chain" or card_id == "thunder":
		row = 3
	var frame := clampi(floori(progress * 4.0), 0, 3)
	var source := Rect2(float(frame) * VFX_CORE_CELL, float(row) * VFX_CORE_CELL, VFX_CORE_CELL, VFX_CORE_CELL)
	var display_extent := clampf(radius * 0.98, 64.0, 270.0)
	if row == 3:
		# 연쇄·낙뢰는 사거리가 400을 넘어서 반경 그대로 키우면 화면을 덮어버린다.
		display_extent = clampf(radius * 0.28, 56.0, 150.0)
	# 행 0만 방향성이 있다. 나머지는 origin 중심에 회전 없이 얹는다.
	var directional := row == 0
	if directional:
		draw_set_transform(origin, facing.angle() - VFX_SLASH_SOURCE_DIRECTION.angle(), Vector2.ONE)
	var destination_center := Vector2.ZERO if directional else origin
	var destination := Rect2(destination_center - Vector2.ONE * display_extent, Vector2.ONE * display_extent * 2.0)
	draw_texture_rect_region(VFX_CORE, destination, source, _vfx_tint(0.8))
	if directional:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == "dash":
		_draw_dash_smoke(facing, progress)
	# 광역·장판·궤도와 묵직한 카드는 착탄 중심에서 폭발이 한 번 터진다.
	if kind in ["area", "ground", "orbit"] or bool(card.get("heavy", false)):
		_draw_explosion_vfx(radius, progress, origin)

# 화염구를 진행 방향으로 회전시켜 원점에서 사거리까지 뻗는 궤적 위에 세 개 늘어놓는다.
# 로컬 +X가 곧 진행 방향이 되도록 변환을 걸어두고 거리만 밀어 넣는다.
func _draw_projectile_vfx(facing: Vector2, radius: float, progress: float) -> void:
	var reach := clampf(radius, 90.0, 360.0)
	var bolt := clampf(reach * 0.16, 34.0, 66.0)
	draw_set_transform(Vector2.ZERO, facing.angle() - VFX_SLASH_SOURCE_DIRECTION.angle(), Vector2.ONE)
	var head := lerpf(reach * 0.22, reach, clampf(progress, 0.0, 1.0))
	for index in 3:
		var travel := head - float(index) * reach * 0.17
		if travel < reach * 0.12:
			continue
		var frame := (floori(progress * 8.0) + index) % 4
		var source := Rect2(float(frame) * VFX_PROJECTILE_CELL, 0.0, VFX_PROJECTILE_CELL, VFX_PROJECTILE_CELL)
		var box := Vector2.ONE * bolt * (1.0 - float(index) * 0.18)
		draw_texture_rect_region(VFX_PROJECTILE, Rect2(Vector2(travel, 0.0) - box * 0.5, box), source, _vfx_tint(0.8 - float(index) * 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# 폭발 9프레임을 진행도로 그대로 재생한다. 반경 전체를 덮지 않고 착탄 중심만 때린다.
func _draw_explosion_vfx(radius: float, progress: float, origin: Vector2) -> void:
	var frame := clampi(floori(progress * 9.0), 0, 8)
	var source := Rect2(float(frame) * VFX_EXPLOSION_CELL, 0.0, VFX_EXPLOSION_CELL, VFX_EXPLOSION_CELL)
	var box := clampf(radius * 1.3, 90.0, 420.0)
	draw_texture_rect_region(VFX_EXPLOSION, Rect2(origin - Vector2.ONE * box * 0.5, Vector2.ONE * box), source, _vfx_flame_tint(0.82))

# 보호막 6프레임은 회전 없이 액터 원점을 감싼다. 셀이 48x52라 세로가 조금 길다.
func _draw_shield_vfx(progress: float) -> void:
	var frame := clampi(floori(progress * 6.0), 0, 5)
	var source := Rect2(float(frame) * VFX_SHIELD_CELL.x, 0.0, VFX_SHIELD_CELL.x, VFX_SHIELD_CELL.y)
	var box := Vector2(96.0, 96.0 * VFX_SHIELD_CELL.y / VFX_SHIELD_CELL.x)
	draw_texture_rect_region(VFX_SHIELD, Rect2(-box * 0.5, box), source, _vfx_tint(0.82))

# 돌진은 지나온 뒤쪽에 연기 한 뭉치를 남겨 이동 방향을 읽게 한다.
func _draw_dash_smoke(facing: Vector2, progress: float) -> void:
	var frame := clampi(floori(progress * 6.0), 0, 5)
	var source := Rect2(float(frame) * VFX_SMOKE_CELL, 0.0, VFX_SMOKE_CELL, VFX_SMOKE_CELL)
	var box := Vector2.ONE * 58.0
	draw_texture_rect_region(VFX_SMOKE, Rect2(-facing * 34.0 - box * 0.5, box), source, _vfx_tint(0.5))

func _draw_signature(card_id: String, facing: Vector2, radius: float, progress: float, alpha: float, origin: Vector2) -> void:
	match card_id:
		"cross_cut", "time_cut":
			var angle := facing.angle()
			for offset in [-0.62, 0.62]:
				var direction := Vector2.from_angle(angle + offset)
				draw_line(origin + direction * 30.0, origin + direction * radius, Color.WHITE, 3.0)
		"flame_field":
			for index in 7:
				var flame_angle := TAU * float(index) / 7.0 + progress * 1.4
				var base := origin + Vector2.from_angle(flame_angle) * radius * 0.58
				var height := 18.0 + sin(progress * TAU + index) * 9.0
				draw_line(base + Vector2(0.0, 8.0), base + Vector2(0.0, -height), Color(effect_color, 0.82), 7.0)
				draw_rect(Rect2(base + Vector2(-3.0, -height - 5.0), Vector2(6.0, 6.0)), Color.WHITE, true)
		"frost_ring":
			for index in 8:
				var ice_angle := TAU * float(index) / 8.0
				var inner := origin + Vector2.from_angle(ice_angle) * radius * 0.72
				var outer := origin + Vector2.from_angle(ice_angle) * radius
				draw_line(inner, outer, Color.WHITE, 3.0)
		"gravity_well":
			for ring in 3:
				draw_arc(origin, radius * (0.25 + ring * 0.2), progress * TAU * (1.0 + ring * 0.2), progress * TAU * (1.0 + ring * 0.2) + PI * 1.35, 22, Color(effect_color, 0.9 - ring * 0.18), 5.0)
			draw_circle(origin, 18.0 + sin(progress * PI) * 12.0, Color("070812d9"))
		"meteor_blade", "sword_rain":
			for index in 5:
				var x := (float(index) - 2.0) * radius * 0.18
				var fall := fmod(progress * 1.7 + float(index) * 0.23, 1.0)
				var start := origin + Vector2(x, -radius * 0.78 + fall * radius * 1.25)
				draw_line(start, start + Vector2(12.0, 34.0), Color(effect_color, 0.78), 6.0)
				draw_line(start + Vector2(3.0, 3.0), start + Vector2(10.0, 27.0), Color.WHITE, 2.0)
		"thunder":
			var points := PackedVector2Array([origin + Vector2(-8.0, -radius * 0.7), origin + Vector2(12.0, -32.0), origin + Vector2(-6.0, -10.0), origin + Vector2(18.0, radius * 0.52)])
			draw_polyline(points, Color.WHITE, 5.0)
			draw_polyline(points, Color(effect_color, 0.55), 12.0)
		"phantom_step":
			for index in 3:
				var side := facing.orthogonal() * (float(index) - 1.0) * 18.0
				draw_line(origin - facing * (36.0 + index * 24.0) + side, origin + facing * radius * 0.72 + side, Color(effect_color, 0.24 + index * 0.12), 10.0)
		"lion_roar":
			for ring in 3:
				var ring_radius := radius * (0.28 + progress * 0.25 + ring * 0.18)
				draw_arc(origin, ring_radius, 0.0, TAU, 32, Color(effect_color, alpha * (0.8 - ring * 0.18)), 4.0)
		"battle_trance":
			for index in 6:
				var ray := Vector2.from_angle(TAU * float(index) / 6.0) * radius * (0.55 + progress * 0.25)
				draw_line(origin + ray * 0.48, origin + ray, Color.WHITE, 3.0)
		_:
			if bool(card.get("heavy", false)):
				for index in 8:
					var ray := Vector2.from_angle(TAU * float(index) / 8.0) * radius * (0.62 + sin(progress * PI) * 0.22)
					draw_line(origin + ray * 0.7, origin + ray, Color(effect_color, alpha), 4.0)
