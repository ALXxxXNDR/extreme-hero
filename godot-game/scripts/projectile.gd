class_name TechProjectile
extends Area2D

# W11: 도형 화살·칼날·마법탄을 Ninja Adventure 투사체 스프라이트로 교체했습니다.
# 세 시트 모두 **+X(오른쪽)를 향하도록 빌드 단계에서 통일**해 구웠습니다
# (art/v2/build_assets.gd의 _rotate_square_frames_cw 참조). 노드 rotation이
# 이미 direction.angle()이므로 로컬 좌표에서는 +X로만 그리면 방향이 맞습니다.
const SHOT_ARROW := preload("res://art/v2/vfx-arrow.png")
const SHOT_BLADE := preload("res://art/v2/vfx-blade.png")
const SHOT_ORB := preload("res://art/v2/vfx-energyball.png")

var game: Node
var direction := Vector2.RIGHT
var speed := 760.0
var damage := 4.0
var lifetime := 2.1
var homing_strength := 0.0
var ricochets_remaining := 0
var pierces_remaining := 0
var projectile_color := GamePalette.YELLOW
var projectile_kind := "arrow"
var hit_ids: Dictionary = {}
var trail: Array[Vector2] = []
# 스프라이트 프레임 전용 누적 시간입니다. 판정에는 쓰이지 않습니다.
var visual_time := 0.0
# V7(2026-08-09): V6이 `body_entered`에 **먼저 연결하는** 우회로로 상태이상을 물렸던
# 것을 setup 인자로 옮겼습니다(handoff-v6 §11 미결 3). V6 주석 원문:
#   "지금 구조도 정확하지만 '연결 순서에 의존한다'는 암묵 계약이 하나 늘었다."
# 이제 명중 처리 순서가 `_on_body_entered` 안에 **한눈에 보이는 두 줄**로 남습니다.
# 카드가 비었거나 원소가 없으면 조회 자체를 하지 않습니다(평타·적 탄환 경로 무비용).
var status_card: Dictionary = {}

func setup(
	game_node: Node,
	start_direction: Vector2,
	shot_damage: float,
	shot_speed: float,
	shot_homing: float,
	ricochets: int,
	pierces: int,
	color: Color,
	visual_kind: String = "arrow",
	travel_range: float = 0.0,
	card: Dictionary = {}
) -> void:
	game = game_node
	direction = start_direction.normalized()
	damage = shot_damage
	speed = shot_speed
	homing_strength = shot_homing
	ricochets_remaining = ricochets
	pierces_remaining = pierces
	projectile_color = color
	projectile_kind = visual_kind
	status_card = card
	if travel_range > 0.0:
		# 카드에 적힌 범위가 실제 투사체 이동거리와 일치하도록 수명을 계산합니다.
		lifetime = maxf(0.12, travel_range / maxf(speed, 1.0))

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	z_index = 6

func _physics_process(delta: float) -> void:
	visual_time += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if homing_strength > 0.0 and is_instance_valid(game):
		var target: Node2D = game.find_nearest_enemy(global_position, hit_ids, 380.0)
		if is_instance_valid(target):
			var desired := global_position.direction_to(target.global_position)
			direction = direction.lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
	trail.push_front(global_position)
	if trail.size() > 5:
		trail.pop_back()
	global_position += direction * speed * delta
	rotation = direction.angle()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	var body_id := body.get_instance_id()
	if hit_ids.has(body_id):
		return
	# V7: 상태이상 파이프라인은 **직격 피해보다 먼저** 돈다. 기름의 화염 증폭(×2.2)과
	# 전(shock) 표식을 `StatusEngine.apply()`가 소모하기 전에 물어야 하기 때문이다
	# (handoff-v6 §2.1). `hit_ids` 등록 **전에** 부르는 것도 계약이다 — 창구가 같은
	# 중복 규칙(`projectile.hit_ids`)을 스스로 확인하므로 먼저 등록하면 조기 반환한다.
	if not status_card.is_empty() and is_instance_valid(game) and game.combat != null:
		game.combat.on_projectile_card_hit(body, self, status_card)
	hit_ids[body_id] = true
	# 몬스터 피격음의 구멍 하나. `combat.on_projectile_card_hit()`이 명중음을 내지만
	# 그 창구는 **보스**와 상태 카드가 없는 투사체를 조기 반환한다 — 그래서 보스를
	# 활로 쏘면 지금까지 아무 소리도 안 났다. 창구가 이미 울린 경우에는 내지 않는다
	# (둘 다 울리면 한 발에 두 번 난다). 쿨다운·동시 재생 상한은 SoundManager가 본다.
	if is_instance_valid(game) and not bool(body.get("dead")) \
			and (status_card.is_empty() or bool(body.get("is_boss"))):
		game.play_sound("impact", -12.0)
	var impact_force := 135.0 if projectile_kind == "blade" else 95.0 if projectile_kind == "arrow" else 72.0
	body.take_damage(damage, global_position, impact_force, 0.055)
	if is_instance_valid(game):
		game.spawn_burst(global_position, projectile_color, 6, 90.0, 0.2)
	if ricochets_remaining > 0 and is_instance_valid(game):
		ricochets_remaining -= 1
		var next_target: Node2D = game.find_nearest_enemy(global_position, hit_ids, 330.0)
		if is_instance_valid(next_target):
			direction = global_position.direction_to(next_target.global_position)
			damage *= 0.82
			return
	if pierces_remaining > 0:
		pierces_remaining -= 1
		return
	queue_free()

func _draw() -> void:
	for index in trail.size():
		var alpha := 0.22 * (1.0 - float(index) / float(maxi(trail.size(), 1)))
		var point := to_local(trail[index])
		var color := projectile_color
		color.a = alpha
		draw_rect(Rect2(point - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), color, true)
	match projectile_kind:
		"magic":
			# 마법탄만 4프레임 애니메이션입니다. 원소색은 곱연산이라 한 번 밝힌 뒤 곱합니다.
			var frame := wrapi(int(visual_time * 14.0), 0, 4)
			draw_texture_rect_region(
				SHOT_ORB,
				Rect2(-16.0, -16.0, 32.0, 32.0),
				Rect2(frame * 32.0, 0.0, 32.0, 32.0),
				projectile_color.lightened(0.3)
			)
		"blade":
			draw_texture_rect(SHOT_BLADE, Rect2(-35.0, -9.0, 70.0, 18.0), false, projectile_color.lightened(0.22))
		_:
			# 화살은 원본 색(나무 대·붉은 깃)이 이미 읽히므로 원소색은 살짝만 섞습니다.
			draw_texture_rect(SHOT_ARROW, Rect2(-13.0, -5.0, 26.0, 10.0), false, Color.WHITE.lerp(projectile_color, 0.35))
