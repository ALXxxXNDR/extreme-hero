class_name BurstEffect
extends Node2D

var effect_color := GamePalette.CYAN
var lifetime := 0.42
var elapsed := 0.0
var particles: Array[Dictionary] = []

func setup(color: Color, count: int = 10, speed: float = 150.0, duration: float = 0.42) -> void:
	effect_color = color
	lifetime = duration
	for index in count:
		var angle := TAU * float(index) / float(count) + randf_range(-0.2, 0.2)
		particles.append({
			"position": Vector2.ZERO,
			"velocity": Vector2.from_angle(angle) * randf_range(speed * 0.55, speed),
			"size": randf_range(2.0, 5.5)
		})
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	for particle: Dictionary in particles:
		particle["position"] += particle["velocity"] * delta
		particle["velocity"] *= 0.93
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()

func _draw() -> void:
	var alpha := clampf(1.0 - elapsed / lifetime, 0.0, 1.0)
	for particle: Dictionary in particles:
		var color := effect_color
		color.a = alpha
		var pixel_size := maxf(2.0, floorf(particle["size"] * alpha))
		var point: Vector2 = particle["position"]
		draw_rect(Rect2(point - Vector2(pixel_size, pixel_size) * 0.5, Vector2(pixel_size, pixel_size)), color, true)
