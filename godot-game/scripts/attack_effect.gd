class_name PixelAttackEffect
extends Node2D

var effect_kind := "slash"
var effect_color := GamePalette.TEXT
var direction := Vector2.RIGHT
var size := 100.0
var duration := 0.18
var elapsed := 0.0

# =============================================================================
# Y7: 충격 버스트 (`vfx-burst.png` 배선 · handoff-y4 §9-C가 Y7에 넘긴 항목)
# =============================================================================
# 규격: 384×64 · **6프레임** · 셀 64 · 중립색이라 modulate가 필수(handoff-ya §5).
# 이 시트가 서는 자리는 `combat_resolver`에서 걷어낸 **카메라 흔들림의 자리**다 —
# 화면을 흔드는 대신 터진 지점이 6프레임 동안 핀다(§7.1 원칙 1·2).
# 새 노드 종류를 만들지 않고 이 파일의 `kind` 축에 한 종을 더한다. 그러면
# 전역 연출 예산(`MAX_TRANSIENT_EFFECTS`)과 `tree_exiting` 반납이 그대로 따라온다.
const IMPACT_BURST_SHEET := preload("res://art/v2/vfx-burst.png")
const IMPACT_BURST_CELL := 64.0
const IMPACT_BURST_FRAMES := 6

func setup(kind: String, color: Color, attack_direction: Vector2, attack_size: float, effect_duration: float = 0.18) -> void:
	effect_kind = kind
	effect_color = color
	direction = attack_direction.normalized()
	size = attack_size
	duration = effect_duration
	# 버스트는 방사형이라 방향이 없다. 회전을 걸면 프레임마다 격자가 어긋나 뭉갠다.
	rotation = 0.0 if kind == "impact" else direction.angle()

func _ready() -> void:
	z_index = 8
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var alpha := 1.0 - progress
	var color := effect_color
	color.a = alpha
	if effect_kind == "impact":
		# 6칸을 진행도에 나눠 담는다 — 시간으로 순환시키지 않는다(1회 재생 후 소멸).
		var frame := clampi(int(progress * float(IMPACT_BURST_FRAMES)), 0, IMPACT_BURST_FRAMES - 1)
		var half := size * 0.5
		draw_texture_rect_region(IMPACT_BURST_SHEET,
			Rect2(Vector2(-half, -half), Vector2(size, size)),
			Rect2(Vector2(float(frame) * IMPACT_BURST_CELL, 0.0),
				Vector2(IMPACT_BURST_CELL, IMPACT_BURST_CELL)),
			Color(effect_color, minf(1.0, alpha + 0.35)))
		return
	if effect_kind == "dash":
		var trail_length := size * (0.65 + progress * 0.45)
		draw_line(Vector2.ZERO, Vector2(trail_length, 0.0), Color(effect_color, alpha * 0.32), 20.0)
		draw_line(Vector2.ZERO, Vector2(trail_length, 0.0), Color(1.0, 1.0, 1.0, alpha), 3.0)
		for index in 4:
			var offset := Vector2(trail_length * (0.18 + index * 0.2), (index - 1.5) * 9.0)
			draw_rect(Rect2(offset - Vector2(4.0, 2.0), Vector2(8.0, 4.0)), Color(effect_color, alpha), true)
	elif effect_kind == "magic":
		var radius := size * (0.45 + progress * 0.55)
		draw_arc(Vector2(size * 0.55, 0.0), radius, 0.0, TAU, 24, color, 6.0)
		for index in 8:
			var point := Vector2(size * 0.55, 0.0) + Vector2.from_angle(TAU * index / 8.0) * radius
			draw_rect(Rect2(point - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), color, true)
	elif effect_kind == "bow":
		draw_line(Vector2(10.0, 0.0), Vector2(size * 0.78, 0.0), color, 3.0)
	else:
		var sweep := lerpf(-0.8, 0.8, progress)
		var start := Vector2.from_angle(sweep - 0.55) * size * 0.42
		var finish := Vector2.from_angle(sweep) * size
		draw_line(start, finish, color, 9.0)
		draw_line(start, finish, Color(1.0, 1.0, 1.0, alpha), 3.0)
		draw_rect(Rect2(finish - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), color, true)
