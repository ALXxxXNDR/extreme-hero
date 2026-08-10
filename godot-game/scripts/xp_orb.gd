class_name ExperienceOrb
extends Node2D

var game: Node
var player: Node2D
var value := 1
var velocity := Vector2.ZERO
var age := 0.0
var redraw_timer := 0.0

func setup(game_node: Node, player_node: Node2D, xp_value: int) -> void:
	game = game_node
	player = player_node
	value = xp_value

func add_value(extra_value: int) -> void:
	value += extra_value
	age = 0.0
	queue_redraw()

func _ready() -> void:
	z_index = 1
	add_to_group("xp_orbs")
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	if not is_instance_valid(player):
		queue_free()
		return
	var distance := global_position.distance_to(player.global_position)
	var pickup_radius: float = player.pickup_radius
	if distance < pickup_radius:
		var force := remap(clampf(distance, 0.0, pickup_radius), pickup_radius, 0.0, 260.0, 720.0)
		velocity = velocity.lerp(global_position.direction_to(player.global_position) * force, delta * 7.0)
	else:
		velocity *= pow(0.08, delta)
	global_position += velocity * delta
	rotation += delta * 2.2
	if distance < 24.0:
		game.collect_xp(value)
		queue_free()
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer = 0.05
		queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(age * 6.0) * 0.12
	var size := (6.0 + minf(value, 3) * 1.4) * pulse
	var points := PackedVector2Array([
		Vector2(0.0, -size),
		Vector2(size * 0.72, 0.0),
		Vector2(0.0, size),
		Vector2(-size * 0.72, 0.0)
	])
	draw_colored_polygon(points, GamePalette.CYAN)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color.WHITE, 2.0)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), Color.WHITE, true)
