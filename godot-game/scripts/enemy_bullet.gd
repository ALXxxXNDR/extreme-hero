class_name EnemyBullet
extends Node2D

# W11: 마름모 도형 탄을 Ninja Adventure 화염구 스프라이트로 교체했습니다.
# 시트는 빌드 단계에서 +X를 향하도록 돌려 구웠으므로(art/v2/build_assets.gd)
# 노드 rotation을 진행 방향 각도로 두면 꼬리가 뒤로 흐릅니다. v1은 매 프레임
# 자전시켰지만 스프라이트에는 앞뒤가 있으므로 자전 대신 방향 정렬로 바꿉니다.
const BULLET_SHEET := preload("res://art/v2/vfx-projectile.png")

var game: Node
var player: Node2D
var direction := Vector2.DOWN
var speed := 235.0
var damage := 9.0
var homing := false
var lifetime := 6.0
var bullet_color := GamePalette.RED
var radius := 8.0
# 스프라이트 프레임 전용 누적 시간입니다. 판정에는 쓰이지 않습니다.
var visual_time := 0.0

func setup(game_node: Node, player_node: Node2D, start_direction: Vector2, is_homing: bool = false, bullet_damage: float = 9.0, bullet_speed: float = 235.0) -> void:
	game = game_node
	player = player_node
	direction = start_direction.normalized()
	homing = is_homing
	damage = bullet_damage
	speed = bullet_speed
	bullet_color = GamePalette.ORANGE if is_homing else GamePalette.RED

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	queue_redraw()

func _physics_process(delta: float) -> void:
	visual_time += delta
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(player):
		queue_free()
		return
	if homing:
		var desired := global_position.direction_to(player.global_position)
		direction = direction.lerp(desired, clampf(1.35 * delta, 0.0, 1.0)).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()
	if global_position.distance_to(player.global_position) < radius + 15.0:
		player.take_damage(damage, global_position)
		if is_instance_valid(game):
			game.spawn_burst(global_position, bullet_color, 8, 120.0, 0.28)
		queue_free()

func _draw() -> void:
	var frame := wrapi(int(visual_time * 15.0), 0, 4)
	draw_texture_rect_region(
		BULLET_SHEET,
		Rect2(-16.0, -16.0, 32.0, 32.0),
		Rect2(frame * 32.0, 0.0, 32.0, 32.0),
		bullet_color.lightened(0.32)
	)
