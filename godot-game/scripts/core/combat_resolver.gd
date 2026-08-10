class_name CombatResolver
extends RefCounted

# =============================================================================
# 전투 판정 · 공간 해시 · 필드 population 단일 소유 파일 (W3에서 game.gd에서 이관)
# =============================================================================
# 설계 근거: docs/GAME_DESIGN_V2.md §7.3 "전투 판정·공간해시" 행 = W3 소유.
#
# 이 파일이 소유하는 것
#   ① 적 공간 해시(active_enemies / enemy_spatial)와 그 위의 모든 조회
#   ② 딜싸이클 카드의 실제 타격 판정(근접·투사체·연쇄·광역·보호막)
#   ③ 캐릭터 평타·대시 피해·궤도 검
#   ④ 필드 population(스폰 간격/상한/야간 습격)과 적 인스턴스 생성
#   ⑤ 처치 처리와 XP 구슬 생성/합산
#
# 이 파일이 소유하지 않는 것 (game.gd가 계속 가진다 — 여기서는 game.xxx()로 부른다)
#   * VFX 예산을 공유하는 연출 헬퍼: spawn_burst / spawn_attack_effect / show_world_text
#     (active_effect_nodes 카운터가 game.gd에 있고 UI·성·전직 코드도 같이 쓴다)
#   * 화면 흔들림·사운드·HUD·배너·시련 캠프 진행·런 종료 판정
#   * collect_xp(레벨업 모달 진입) / get_player_speed_multiplier(이동)
#
# 참조 방향은 한 방향이다: CombatResolver -> game. game.gd는 이 파일을
# preload 하지 않고 전역 클래스명 `CombatResolver`로만 생성한다(순환 참조 방지).
#
# W3의 계약: **동작 무변경**. v1(game.gd)과 판정 순서·난수 소비·부수효과가
# 1비트도 다르지 않다. 옮기면서 바뀐 것은 세 가지뿐이다.
#   ① game.gd 멤버 접근에 `game.` 접두사가 붙었다.
#   ② 오브젝트 경계를 넘는 함수는 밑줄을 뗐다(spawn_enemy_instance 등).
#   ③ unregister_enemy()가 공간 해시 버킷에서도 지운다(§7.3 R11). 죽은/해제된
#      노드는 원래도 query_enemies에서 걸러졌으므로 판정 결과는 같고,
#      0.12초짜리 재구축 주기 사이의 헛 순회만 사라진다.

# game.gd 인스턴스(GameMain). setup()이 주입한다.
# 순환 참조를 피하려고 타입은 Node로 둔다(enemy.gd·player.gd와 같은 관례).
var game: Node

# --- 적 등록부와 공간 해시 -------------------------------------------------
var active_enemies: Array[Node] = []
var enemy_spatial: Dictionary = {}
var spatial_refresh_timer := 0.0

# --- 필드 population ------------------------------------------------------
var spawn_timer := 0.0

# 성스러운 파동이 자기 자신을 재귀 호출하지 않게 막는 빗장.
var hotfix_burst_running := false

# =============================================================================
# V6: 원소 상태이상 통합 (설계 §4.4 매트릭스 · §4.7 성능 4규칙)
# =============================================================================
# 규칙은 `core/status_engine.gd`(V1 확정)가 전부 갖는다. 이 파일은 **집행자**다 —
# 엔진이 낸 이벤트 6종을 세계에 적용하고, 프레임 자원(예산·깊이·킬 체인)을 관리한다.
#
# 한 방의 순서가 곧 밸런스다(handoff-v1 §5.2 · 호출 순서 함정 5건):
#   ① `incoming_multiplier` + `consume_shock` — `apply()`가 기름·전 표식을 **소모하기 전에**
#   ② 보정된 피해로 `take_damage`
#   ③ `apply()` 매트릭스 → 이벤트 실행(전이는 `chain_damage()` 단일 식, 전파는 depth 인자)
#   ④ 넉백은 이벤트의 `knockback_mul`을 곱한 뒤 **한 번만** `apply_hit_reaction`
# 증기의 `range_bonus`만은 ③보다 앞이다 — 이미 때린 뒤에 받으면 한 펄스 늦는다.
# 그래서 `status_range_bonus()`가 타격 **전에** `preview()`로 묻는다.

# 프레임당 반응 예산(§4.7 규칙 4). 엔진은 순수해야 하므로 예산은 호출자가 소유한다.
var status_budget: Dictionary = StatusEngine.make_budget()
# --stress-test가 보는 계측값. `suppressed`는 예산·깊이로 잘려 나간 질의 이벤트 수다.
var status_suppressed_total := 0
var status_events_run := 0
var status_reactions_fired := 0
var status_chain_hops := 0
var status_spread_applied := 0
var status_max_depth_seen := 0
var status_dot_ticks := 0
var status_budget_peak := 0
var status_budget_capped_frames := 0
# 전역 킬 체인 깊이 가드(§4.7 추가 함정). 상한은 GameTuning이 소유한다.
var kill_chain_depth := 0
var kill_chain_peak := 0
var kill_chain_suppressed := 0
# Y5 무리 스폰 관측점. 마지막 `maintain_field_population()`이 무리를 세웠다면
# 몇 기를 원했고(`wanted`) 실제로 몇 기가 섰는지(`stood`)를 남긴다.
# 무리가 아닌 스폰에서는 갱신하지 않는다 — `--field-test herd_spawn`이 이걸 읽는다.
# 값일 뿐이라 게임 로직은 한 줄도 이걸 보지 않는다.
var last_herd_stood := 0
var last_herd_wanted := 0
# 한 프레임에 띄우는 시너지 **부유 라벨** 상한. 밸런스 값이 아니라 가독성 가드라
# GameTuning이 아니라 여기 있다 — 78기 밤에 화염 광역 한 방이면 "역병 발화!"가
# 수십 장 겹쳐 글자가 서로를 지운다. 버스트는 `MAX_TRANSIENT_EFFECTS`가 이미 묶는다.
const MAX_REACTION_LABELS_PER_FRAME := 4
var status_labels_this_frame := 0


func setup(game_node: Node) -> void:
	game = game_node


# _begin_run()이 새 런을 열 때 호출한다. v1에서 game.gd가 흩어서 하던
# 초기화 5줄(active_enemies/enemy_spatial/spawn_timer/spatial_refresh_timer/
# hotfix_burst_running)을 그대로 모은 것이다. 값은 v1과 동일하다.
func reset() -> void:
	active_enemies.clear()
	enemy_spatial.clear()
	spawn_timer = 0.2
	spatial_refresh_timer = 0.0
	hotfix_burst_running = false
	# V6: 상태이상 프레임 자원과 계측값도 런 경계에서 비운다.
	StatusEngine.budget_reset(status_budget)
	status_suppressed_total = 0
	status_events_run = 0
	status_reactions_fired = 0
	status_chain_hops = 0
	status_spread_applied = 0
	status_max_depth_seen = 0
	status_dot_ticks = 0
	status_budget_peak = 0
	status_budget_capped_frames = 0
	kill_chain_depth = 0
	kill_chain_peak = 0
	kill_chain_suppressed = 0


# =============================================================================
# 프레임 훅 — game.gd `_process`의 W3 구역이 이 두 개만 부른다.
# 프레임 순서가 곧 타격감이므로 호출 위치를 옮기지 말 것(§W3 금지사항).
# =============================================================================

# v1: `spawn_timer -= delta; if spawn_timer <= 0.0: _maintain_field_population(); spawn_timer = _current_spawn_interval()`
func tick_population(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		maintain_field_population()
		spawn_timer = current_spawn_interval()


# V6: 프레임 시작. 반응 예산을 0으로 되감고 킬 체인 깊이를 0으로 되돌린다(§4.7 규칙 4).
# 예산은 **프레임 자원**이라 여기 말고 다른 데서 리셋하면 상한이 무의미해진다.
# 깊이 카운터는 정상 흐름이면 이미 0이지만, 재귀 도중 `queue_free`로 프레임이 끊긴
# 경우를 대비해 프레임마다 확실히 되돌린다(가드가 영구히 닫히는 것을 막는다).
func begin_status_frame() -> void:
	# 되감기 전에 지난 프레임의 사용량을 남긴다. `--stress-test`가 "예산 초과 0건"을
	# 단언하려면 **프레임 최대치**가 필요한데, 리셋 뒤에 읽으면 항상 0이 나온다.
	var used := int(status_budget.get("used", 0))
	status_budget_peak = maxi(status_budget_peak, used)
	if used >= int(status_budget.get("cap", GameTuning.STATUS_REACTION_BUDGET_PER_FRAME)):
		status_budget_capped_frames += 1
	StatusEngine.budget_reset(status_budget)
	kill_chain_depth = 0
	status_labels_this_frame = 0


# v1: `spatial_refresh_timer -= delta; if spatial_refresh_timer <= 0.0: spatial_refresh_timer = 0.12; _rebuild_enemy_spatial()`
func tick_spatial(delta: float) -> void:
	spatial_refresh_timer -= delta
	if spatial_refresh_timer <= 0.0:
		spatial_refresh_timer = 0.12
		rebuild_enemy_spatial()


# =============================================================================
# 공간 해시
# =============================================================================

func register_enemy(enemy: Node) -> void:
	if not active_enemies.has(enemy):
		active_enemies.append(enemy)
	_add_enemy_to_spatial(enemy)


# R11: v1은 active_enemies에서만 지워 버킷에 유령 참조가 남았다.
# 다음 재구축(0.12초)까지 query_enemies가 is_instance_valid로 걸러 냈으므로
# 판정 결과는 같았지만, 버킷에서도 지워 헛 순회를 없앤다.
func unregister_enemy(enemy: Node) -> void:
	active_enemies.erase(enemy)
	if not is_instance_valid(enemy):
		return
	var cell := _enemy_cell(enemy.global_position)
	if not enemy_spatial.has(cell):
		return
	var bucket: Array = enemy_spatial[cell]
	bucket.erase(enemy)
	enemy_spatial[cell] = bucket


func _enemy_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / GameTuning.ENEMY_SPATIAL_CELL), floori(point.y / GameTuning.ENEMY_SPATIAL_CELL))


func _add_enemy_to_spatial(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var cell := _enemy_cell(enemy.global_position)
	if not enemy_spatial.has(cell):
		enemy_spatial[cell] = []
	var bucket: Array = enemy_spatial[cell]
	if not bucket.has(enemy):
		bucket.append(enemy)
		enemy_spatial[cell] = bucket


func rebuild_enemy_spatial() -> void:
	enemy_spatial.clear()
	for index in range(active_enemies.size() - 1, -1, -1):
		var enemy := active_enemies[index]
		if not is_instance_valid(enemy):
			active_enemies.remove_at(index)
			continue
		if enemy.dead:
			continue
		_add_enemy_to_spatial(enemy)


func query_enemies(center: Vector2, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	if enemy_spatial.is_empty() and not active_enemies.is_empty():
		rebuild_enemy_spatial()
	var minimum_cell := _enemy_cell(center - Vector2(radius, radius))
	var maximum_cell := _enemy_cell(center + Vector2(radius, radius))
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not enemy_spatial.has(cell):
				continue
			for candidate in enemy_spatial[cell]:
				if not is_instance_valid(candidate):
					continue
				var enemy: Node = candidate
				var reach := radius + float(enemy.radius)
				if not enemy.dead and center.distance_squared_to(enemy.global_position) <= reach * reach:
					result.append(enemy)
	return result


func find_nearest_enemy(origin: Vector2, excluded: Dictionary = {}, maximum_distance: float = INF) -> Node2D:
	var nearest: Node2D
	var nearest_distance := maximum_distance * maximum_distance
	var candidates: Array[Node] = active_enemies if is_inf(maximum_distance) else query_enemies(origin, maximum_distance)
	for candidate: Node in candidates:
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		if excluded.has(candidate.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func alert_same_species(species: String, origin: Vector2) -> void:
	for candidate: Node in query_enemies(origin, 780.0):
		if is_instance_valid(candidate) and not candidate.is_boss and candidate.species == species and candidate.global_position.distance_to(origin) <= 780.0:
			candidate.receive_pack_alert()


# =============================================================================
# 필드 population
# =============================================================================

# =============================================================================
# V6: 물량 3함수를 **dwell 축**으로 갈아끼웠다 (handoff-v5 §6 훅 ③ · 설계 §6.2)
# =============================================================================
# v2 식은 세 함수 모두 `game.cycle_number`(= 총 일수)를 그대로 곱했다. v3는 일수에
# 상한이 없으므로(§2.5의 day_number는 기록 전용 카운터가 됐다) 물량이 스테이지를
# 넘어 단조 증가한다 — 설계 V3-D가 "**day를 소비하는 것이 금지된다**"고 못 박은 바로
# 그 지점이다. dwell은 스테이지 전환마다 절반으로 감쇠하고 `min(d, 6)`에서 포화하므로
# 물량이 유한하게 묶인다. 식 자체는 `StageClock`이 단독으로 소유한다(V4 확정).
#   `game.is_night`을 그대로 읽는 이유: 낮/밤 전환의 진실 원천이 v2부터 여기라
#   `clock.is_night`으로 바꾸면 낮/밤을 손으로 세팅하는 테스트가 전부 어긋난다.
func current_spawn_interval() -> float:
	return StageClock.spawn_interval_at(_dwell(), game.is_night)


func current_enemy_limit() -> int:
	if game.is_night:
		return StageClock.night_enemy_limit_at(_dwell())
	return StageClock.day_enemy_limit_at(_dwell())


# 낮 -> 밤 전환 순간에 즉시 소환하는 습격체 수.
func night_raid_burst_count() -> int:
	return StageClock.night_raid_burst_at(_dwell())


func _dwell() -> int:
	if game == null or game.get("clock") == null:
		return 0
	return maxi(0, int(game.clock.dwell))


func _stage() -> int:
	if game == null or game.get("clock") == null:
		return 1
	return clampi(int(game.clock.stage), 1, MonsterLibrary.STAGE_COUNT_REF)


# =============================================================================
# Y5: 지형 × 습성 스폰 + 무리 스폰 (설계 §5.2 · §5.3)
# =============================================================================
# 순서가 바뀌었다. v3까지는 **종을 먼저 뽑고 자리를 찾았다.** 이제는 반대다 —
# 자리를 먼저 잡고, 그 자리의 지형이 어떤 습성을 부르는지에 따라 종이 정해진다.
# 그래야 피드백 ⑥의 "초원엔 약한 몹이 무리지어 배회"가 데이터가 아니라 그림이 된다.
#
# v3의 임프 무리 블록(`behavior == 3 and not is_night and randf() < 0.45`)은
# **삭제했다.** imp의 습성이 `herd`라 아래 무리 경로와 완전히 겹친다 — 남겨 두면
# 같은 무리가 두 번 서서 개체 상한을 이중으로 먹고, 밤에는 임프만 무리를 못 짓는
# (설계 §5.2 "밤: 함께 몰려온다"에 어긋나는) 낡은 규칙이 그대로 남는다.
func maintain_field_population() -> void:
	if not is_instance_valid(game.player):
		return
	if active_enemies.size() >= current_enemy_limit():
		return
	# ① 자리부터 정한다. `find_walkable_near`가 물·돌을 이미 걸러 준다(같은 is_walkable).
	var minimum: float = 560.0 if game.is_night else 270.0
	var maximum: float = 790.0 if game.is_night else 760.0
	var spawn_position: Vector2 = game.world.find_walkable_near(game.player.global_position, game.rng, minimum, maximum)
	# ② 그 자리의 지형을 한 번만 묻는다(O(1) 캐시 조회 · §5.3).
	var tile_kind: String = game.world.tile_kind_at(spawn_position)
	var archetype := roll_archetype_for_terrain(tile_kind)
	var behavior: int = int(archetype.get("behavior", _roll_field_behavior()))
	var archetype_id := String(archetype.get("id", ""))
	var anchor: DebtEnemy = spawn_enemy_instance(spawn_position, behavior, "", false, "", false, archetype_id) as DebtEnemy
	if not is_instance_valid(anchor):
		return
	# ③ 무리 습성이 아니면 여기서 끝이다(한 기).
	if MonsterLibrary.habit_of(archetype) != "herd":
		return
	# ④ 무리 스폰. 낮이든 밤이든 함께 선다(§5.2 — 밤에는 "함께 몰려온다").
	anchor.set_herd_center(spawn_position)
	# `game`이 Node 타입이라 `game.rng.*`의 반환은 Variant다 — 타입을 손으로 못 박는다.
	var wanted: int = game.rng.randi_range(MonsterLibrary.HABIT_HERD_SPAWN_MIN, MonsterLibrary.HABIT_HERD_SPAWN_MAX)
	# ⚠️ **개체 상한을 절대 넘기지 않는다.** 앵커는 이미 `active_enemies`에 등록됐으므로
	#    (enemy._ready()가 register_enemy를 부른다) 여기서 세는 것은 남은 자리다.
	#    `current_enemy_limit()`은 StageClock이 `mini(GameTuning.MAX_ENEMIES, …)`로
	#    이미 클램프하므로 이 한 줄이 78 상한까지 그대로 지켜 준다.
	var room := maxi(0, current_enemy_limit() - active_enemies.size())
	var extra := mini(wanted - 1, room)
	# `--field-test herd_spawn`이 읽는 관측점. 마지막 무리가 몇 기로 섰는가.
	last_herd_stood = 1
	last_herd_wanted = wanted
	for index in extra:
		var angle: float = game.rng.randf_range(0.0, TAU)
		var member_position: Vector2 = spawn_position + Vector2.from_angle(angle) * game.rng.randf_range(28.0, MonsterLibrary.HABIT_HERD_SPAWN_RADIUS)
		# 돌·물 위에는 세우지 않는다. 자리가 안 나오면 그 한 마리를 포기한다 —
		# 재시도 루프를 돌리면 스폰 한 번의 비용이 지형에 따라 튄다.
		if not game.world.is_walkable(member_position):
			continue
		var member: DebtEnemy = spawn_enemy_instance(member_position, behavior, "", false, "", false, archetype_id) as DebtEnemy
		if is_instance_valid(member):
			# 앵커 좌표를 **전원**에게 심는다. 이게 빠지면 각자 태어난 자리로 흩어진다.
			member.set_herd_center(spawn_position)
			last_herd_stood += 1


## 이 타일 위에서 지금 스테이지·시간대에 설 수 있는 종을 지형 가중을 곱해 하나 뽑는다(§5.3).
##
## `monster_library.gd`는 **한 줄도 고치지 않는다.** 공개 API 셋
## (`stage_pool` · `stage_spawn_allowed` · `stage_spawn_weight`)에
## `habit_terrain_scale()`을 곱하는 조합일 뿐이다. 그래서 밸런스의 정본은
## 여전히 그 파일 하나이고 여기에는 새 숫자가 없다.
##
## 후보가 하나도 없으면(스테이지 게이트가 전부 막았거나 가중 합이 0) 기존
## `roll_for_stage()`로 떨어진다 — 지형 배선이 스폰 자체를 굶기면 안 된다.
func roll_archetype_for_terrain(tile_kind: String) -> Dictionary:
	var stage := _stage()
	var night: bool = game.is_night
	var pool := MonsterLibrary.stage_pool(stage)
	var weights := PackedFloat32Array()
	weights.resize(pool.size())
	var total := 0.0
	for index in pool.size():
		var monster: Dictionary = pool[index]
		var weight := 0.0
		if MonsterLibrary.stage_spawn_allowed(monster, stage, night):
			weight = maxf(0.0, MonsterLibrary.stage_spawn_weight(monster, stage, night)
				* MonsterLibrary.habit_terrain_scale(tile_kind, MonsterLibrary.habit_of(monster)))
		weights[index] = weight
		total += weight
	if total <= 0.0:
		return MonsterLibrary.roll_for_stage(game.rng, stage, night)
	var roll: float = game.rng.randf_range(0.0, total)
	for index in pool.size():
		roll -= weights[index]
		if roll <= 0.0:
			return pool[index]
	return pool[pool.size() - 1]


func _roll_field_behavior() -> int:
	if game.is_night:
		return game.rng.randi_range(1, 4)
	var roll: int = game.rng.randi_range(0, 99)
	if roll < 36: return 1
	if roll < 68: return 2
	if roll < 91: return 3
	return 4


# allow_aggro_override=true는 낮 선공몹 게이트(MonsterLibrary.aggro_gate_ok)를 건너뛰는
# 의도된 강제 스폰 경로에만 쓴다(시련 캠프 정예·미믹 함정·보스 하수인·자동 테스트).
# 일반 필드 population과 런 시작 스타터는 기본값 false로 게이트를 그대로 받는다.
func spawn_enemy_instance(world_position: Vector2, behavior: int = 0, forced_module: String = "", split_child: bool = false, camp_id: String = "", camp_elite: bool = false, archetype_id: String = "", allow_aggro_override: bool = false) -> Node2D:
	if not is_instance_valid(game.gameplay_root) or not is_instance_valid(game.player):
		return null
	if active_enemies.size() >= GameTuning.MAX_ENEMIES + 26:
		return null
	var stage := _stage()
	var archetype := MonsterLibrary.by_id(archetype_id) if not archetype_id.is_empty() else MonsterLibrary.roll_for_stage(game.rng, stage, game.is_night, behavior, allow_aggro_override)
	if archetype.is_empty():
		archetype = MonsterLibrary.roll_for_stage(game.rng, stage, game.is_night, behavior, allow_aggro_override)
	behavior = int(archetype.get("behavior", game.rng.randi_range(1, 4)))
	var kind: String = String(archetype.get("id", "mossling"))
	var enemy := DebtEnemy.new()
	var power_level := float(game.cycle_number - 1) * 1.1 + float(game.level - 1) * 0.32 + minf(game.elapsed_time / 180.0, 2.5)
	enemy.setup(game, game.player, kind, behavior, power_level, game.rejected_skills, false, split_child)
	# V6: 스테이지 기저 배율은 **여기 한 곳에서만** 걸린다(아래 함수 주석 참조).
	apply_stage_scaling(enemy)
	if not forced_module.is_empty():
		enemy.force_module(forced_module)
	if not camp_id.is_empty():
		enemy.mark_trial(camp_id, camp_elite)
	enemy.position = world_position
	game.gameplay_root.add_child(enemy)
	if game.is_night:
		enemy.set_night_raid(true)
	return enemy


# =============================================================================
# V6: 스테이지 기저 배율 — V5의 임시 스윕을 설계가 지정한 자리로 이관 (§6.2 · §6.3)
# =============================================================================
# ⚠️ **이 함수가 유일한 적용 지점이다.** V5는 `combat_resolver.gd`를 열 수 없어
#    `game.gd`에 `_sweep_stage_scaling()` / `_apply_stage_scaling_to()` / `STAGE_SCALE_META`
#    3종 우회로를 두고 매 프레임 폴링으로 먹였다(handoff-v5 §6). **V6이 그 셋과
#    `_process`의 호출 한 줄을 전부 삭제했다** — `grep STAGE_SCALE_META`가 0건이어야 한다.
#    두 곳에 두면 배율이 제곱된다(스테이지 5 dwell 4에서 HP ×5.61이 ×31.5가 된다).
#
# V5가 "체력을 max로 되돌리지 말 것"이라고 경고한 함정은 **여기서는 존재하지 않는다.**
# 그건 스윕이 스폰 **다음 프레임**에 돌아서 이미 들어간 피해를 지웠기 때문이고
# (`--v4-test`의 `live_direction`이 6회 중 1회 실패), 이 함수는 `add_child` 전
# `health == max_health`인 시점에 도므로 지울 피해가 아예 없다.
#
# 호출 위치도 의도적이다 — `setup()` **직후 / `force_module`·`mark_trial` 앞**이라
# 검은 갑주(방패 = max_health 비율)와 정예 ×3이 **배율이 걸린 체력** 위에서 계산된다.
func apply_stage_scaling(enemy: Node) -> void:
	if not is_instance_valid(enemy) or bool(enemy.is_boss) or game == null or game.get("clock") == null:
		return
	var clock: StageClock = game.clock
	enemy.max_health *= clock.enemy_hp_multiplier()
	enemy.health = enemy.max_health
	enemy.displayed_health = enemy.health
	enemy.trailing_health = enemy.health
	enemy.contact_damage *= clock.enemy_damage_multiplier()
	enemy.speed *= clock.enemy_speed_multiplier()
	# **보상은 H(dwell)^0.5 / ^0.4.** 이 두 줄이 빠지면 체류 압박 자체가 사라진다(§6.2).
	# 0인 값(분열체·마왕)은 0으로 남긴다 — V5의 스윕은 `maxi(1, ...)`이라 경험치 0짜리
	# 분열체에 1을 줬다. 무한 분열 파밍을 막는 규칙이라 되살려 두면 안 된다.
	if enemy.xp_value > 0:
		enemy.xp_value = maxi(1, int(round(float(enemy.xp_value) * clock.xp_multiplier())))
	if enemy.gold_value > 0:
		enemy.gold_value = maxi(0, int(round(float(enemy.gold_value) * clock.gold_multiplier())))
	game.stage_scaled_enemies += 1


func spawn_split_enemies(origin: Vector2, count: int) -> void:
	for index in count:
		var offset := Vector2.from_angle(TAU * float(index) / float(count) + randf()) * 34.0
		spawn_enemy_instance(origin + offset, 1, "", true)
	game.spawn_burst(origin, GamePalette.MAGENTA, 16, 195.0, 0.5)


func spawn_boss_minions(origin: Vector2, count: int) -> void:
	for index in count:
		var angle := TAU * float(index) / float(count) + fmod(game.elapsed_time * 0.71, TAU)
		# 마왕 전투 하수인은 낮 선공몹 게이트 대상이 아니다(보스전 전용 강제 스폰).
		var enemy := spawn_enemy_instance(origin + Vector2.from_angle(angle) * 125.0, 4, "", false, "", false, "", true)
		if is_instance_valid(enemy):
			enemy.set_night_raid(true)
	game.spawn_burst(origin, GamePalette.MAGENTA, 18, 160.0, 0.45)


# =============================================================================
# 딜싸이클 카드 타격 판정 (CycleSkillEffect가 game.gd 위임 래퍼를 통해 부른다)
# =============================================================================

func apply_cycle_melee(actor: Node2D, card: Dictionary, hit_ids: Dictionary, is_boss_cycle: bool, facing: Vector2, damage_mul: float = 1.0) -> void:
	if not is_instance_valid(actor):
		return
	var range_value := float(card.get("range", 130.0))
	var arc := float(card.get("arc", 1.8))
	# V6: 증기(§4.4 화↓×한→)는 **이번 타격**의 범위를 늘린다. 사후 `apply()`가 내는
	# range_bonus를 쓰면 한 펄스 늦으므로 타격 전에 `preview()`로 묻는다.
	if not is_boss_cycle:
		range_value *= 1.0 + status_range_bonus(actor.global_position, range_value, card)
	if is_boss_cycle:
		if not is_instance_valid(game.player) or hit_ids.has(game.player.get_instance_id()):
			return
		var offset: Vector2 = game.player.global_position - actor.global_position
		var distance := offset.length()
		var direction := offset.normalized() if distance > 0.01 else facing
		if distance <= range_value + 18.0 and (arc >= TAU - 0.1 or facing.dot(direction) >= cos(arc * 0.5)):
			hit_ids[game.player.get_instance_id()] = true
			game.player.take_damage(_cycle_damage_value(actor, card, true, damage_mul), actor.global_position)
			game.spawn_burst(game.player.global_position, GamePalette.RED, 8, 120.0, 0.22)
		return
	for target: Node in query_enemies(actor.global_position, range_value + 72.0):
		if not is_instance_valid(target) or target.dead or hit_ids.has(target.get_instance_id()):
			continue
		var offset_to_target: Vector2 = target.global_position - actor.global_position
		var distance := offset_to_target.length()
		var to_target := offset_to_target.normalized() if distance > 0.01 else facing
		var in_cone := distance <= range_value + float(target.radius) and (arc >= TAU - 0.1 or facing.dot(to_target) >= cos(arc * 0.5))
		var forward := offset_to_target.dot(facing)
		var lateral := absf(offset_to_target.cross(facing))
		var swept := forward >= 0.0 and forward <= range_value + float(target.radius) and lateral <= 28.0 + float(target.radius)
		if in_cone or swept:
			hit_ids[target.get_instance_id()] = true
			var damage_value := _cycle_damage_value(actor, card, false, damage_mul)
			# V6: 직격 피해 · 상태 부여 · 반응 실행이 한 창구를 탄다.
			# 흡혈은 **실제로 들어간** 피해를 먹는다(기름 위 화염 ×2.2가 흡혈에도 반영).
			var dealt := strike_enemy_with_card(target, card, damage_value, actor.global_position)
			var lifesteal := float(card.get("lifesteal", 0.0))
			if lifesteal > 0.0:
				game.player.heal(dealt * lifesteal)
			var impact_color := Color(String(card.get("color", "f4d35e")))
			game.spawn_burst(target.global_position, impact_color, 10 if bool(card.get("heavy", false)) else 7, 145.0 if bool(card.get("heavy", false)) else 110.0, 0.28)


func trigger_cycle_card_pulse(actor: Node2D, card: Dictionary, is_boss_cycle: bool, pulse_index: int, action_origin: Vector2, damage_mul: float = 1.0) -> void:
	if not is_instance_valid(actor):
		return
	if is_boss_cycle:
		_trigger_boss_cycle_pulse(actor, card, action_origin, damage_mul)
		return
	var kind := String(card.get("kind", "area"))
	var direction: Vector2 = actor.last_move_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var damage_value := _cycle_damage_value(actor, card, false, damage_mul)
	var card_color := Color(String(card.get("color", "f4d35e")))
	match kind:
		"projectile":
			var projectile_count := maxi(1, int(card.get("projectiles", 1)))
			for index in projectile_count:
				var spread_step := float(card.get("spread", 0.18))
				var spread := (float(index) - float(projectile_count - 1) * 0.5) * spread_step
				# V6: 카드를 함께 넘겨 명중 시 상태·반응이 붙는다(관통 계열 6장).
				spawn_player_projectile(actor.global_position + direction * 24.0, direction.rotated(spread), damage_value, 650.0, float(card.get("homing", 0.0)), int(card.get("ricochet", 0)), int(card.get("pierce", 0)), card_color, "blade", float(card.get("range", 520.0)), card)
			game.spawn_attack_effect(actor.global_position, "magic", card_color, direction, 86.0, 0.26)
			game.spawn_burst(actor.global_position + direction * 24.0, card_color, 8 + mini(projectile_count, 5), 120.0, 0.26)
		"chain":
			var excluded := {}
			var chain_origin := actor.global_position
			for _bounce in maxi(1, int(card.get("ricochet", 3))):
				var target := find_nearest_enemy(chain_origin, excluded, float(card.get("range", 410.0)))
				if not is_instance_valid(target): break
				excluded[target.get_instance_id()] = true
				strike_enemy_with_card(target, card, damage_value, chain_origin)
				game.spawn_attack_effect(target.global_position, "magic", card_color, Vector2.UP, 65.0, 0.2)
				game.spawn_burst(target.global_position, card_color, 9, 135.0, 0.26)
				chain_origin = target.global_position
		"area", "orbit", "ground":
			var center := cycle_pulse_center(actor, card, pulse_index, action_origin)
			var radius := cycle_pulse_radius(card)
			# V6: 증기의 범위 +50%는 **이번 펄스**에 붙는다(타격 전 preview).
			radius *= 1.0 + status_range_bonus(center, radius, card)
			for target: Node in query_enemies(center, radius):
				if is_instance_valid(target) and not target.dead:
					strike_enemy_with_card(target, card, damage_value, center)
			var burst_count := 18 if bool(card.get("heavy", false)) else 12 if kind == "ground" else 9
			game.spawn_burst(center, card_color, burst_count, 180.0 if bool(card.get("heavy", false)) else 120.0, 0.38)
			# "magic" 링은 진행 방향으로 0.55×size 밀려 그려지므로 중심 판정형 광역에는 쓰지 않는다.
			# 광역 링과 룬은 CycleSkillEffect가 같은 center/radius로 직접 그린다.
		"shield":
			var shield_radius := float(card.get("range", 0.0))
			if damage_value > 0.0 and shield_radius > 0.0:
				shield_radius *= 1.0 + status_range_bonus(actor.global_position, shield_radius, card)
				for target: Node in query_enemies(actor.global_position, shield_radius):
					if is_instance_valid(target) and not target.dead:
						strike_enemy_with_card(target, card, damage_value, actor.global_position)
			game.spawn_burst(actor.global_position, card_color, 18, 145.0, 0.42)
	var heal_amount := float(card.get("heal", 0.0))
	if heal_amount > 0.0 and pulse_index == 0 and actor.has_method("heal"):
		actor.heal(heal_amount)
		game.show_world_text(actor.global_position - Vector2(0.0, 54.0), "+%.0f 회복" % heal_amount, GamePalette.GREEN, 16)
	# =========================================================================
	# Y7(§7.1 원칙 1): **플레이어 스킬 발사에는 흔들림 0.**
	# =========================================================================
	# 여기 있던 `game.shake_camera(7.0, 0.22)`가 이 프로젝트에서 카메라를 가장 자주
	# 흔들던 줄이었다 — 무거운 카드 8장이 한 바퀴에 여러 번 도니까 사실상 상시였다.
	# 사용자 피드백("카메라 이동은 최소화")의 정면 대상이라 **지웠다.**
	# 그 자리를 대신하는 것이 충격 버스트다 — 화면이 아니라 **맞은 자리**가 터진다.
	# 버스트와 「내가 빨라짐」은 `cycle_skill_effect.gd`가 **카드당 한 번** 낸다
	# (여기서 내면 근접·돌진 카드 10장이 이 함수를 안 타서 빠진다).
	game.play_sound("shoot", -10.0)


# 장판/광역 타격의 중심과 반지름은 여기 한 곳에서만 계산합니다.
# CycleSkillEffect가 같은 값을 그리기에 사용하므로 이펙트 위치와 피해 위치가 어긋날 수 없습니다.
func cycle_pulse_center(actor: Node2D, card: Dictionary, pulse_index: int, action_origin: Vector2) -> Vector2:
	var kind := String(card.get("kind", "area"))
	var center := action_origin
	if kind != "ground" and is_instance_valid(actor):
		center = actor.global_position
	if not bool(card.get("random_impacts", false)):
		return center
	var radius := float(card.get("range", 140.0))
	var hit_count := maxi(1, int(card.get("hits", 1)))
	var angle := TAU * fmod(float(pulse_index) * 0.6180339, 1.0)
	var distance_ratio := 0.2 + 0.62 * float((pulse_index * 7) % hit_count) / float(hit_count)
	return center + Vector2.from_angle(angle) * radius * distance_ratio


func cycle_pulse_radius(card: Dictionary) -> float:
	var radius := float(card.get("range", 140.0))
	if bool(card.get("random_impacts", false)):
		return maxf(64.0, radius * 0.42)
	return radius


# =============================================================================
# V6: 카드 한 방이 적에게 들어가는 유일한 창구 (설계 §4.4 · handoff-v1 §5.2)
# =============================================================================
# 반환값 = **실제로 들어간 직격 피해**(흡혈이 이 값을 쓴다).
#
# 순서에 함정이 다섯 개 있고 전부 여기서 처리한다:
#   ① 기름의 화염 증폭(×2.2)과 전 표식(+12%)은 `apply()`가 그 둘을 **소모하기 전에**
#      물어야 한다. `apply()` 뒤에 물으면 영원히 1.0이 나온다.
#   ② 매트릭스를 **직격 피해보다 먼저** 돌린다. 나중에 돌리면 마지막 일격으로 죽은
#      적에게서는 역병 발화·대폭 연소가 아예 안 터진다. 비원소 2종이 "상태를
#      거둬들이는 마무리 칸"이라는 §4.4 설계 의도 1은 **마무리 일격일수록** 터져야
#      성립하므로, 순서를 뒤집으면 의도가 가장 필요한 순간에만 사라진다.
#   ③ 넉백은 쇄빙(`knockback_mul` ×2)을 곱한 뒤 **한 번만** 호출한다.
#      v2는 여기서 즉시 `apply_hit_reaction`을 불렀는데 그러면 쇄빙이 다음 타격에 붙는다.
#   ④ 전이 피해는 `StatusEngine.chain_damage()` 단일 식으로만 낸다.
#   ⑤ 전파는 이벤트의 `depth`를 **그대로 되넘긴다**(안 넘기면 깊이 가드가 무력화된다).
func strike_enemy_with_card(target: Node, card: Dictionary, damage_value: float, center: Vector2) -> float:
	if not is_instance_valid(target) or bool(target.dead):
		return 0.0
	# V7(2026-08-09) — handoff-v6 §10 인계 1의 "한 곳"이 여기다.
	# V6은 보스에게 상태를 안 붙였다(보스 = 마왕뿐이었고 페이즈·상태는 V7 소유였다).
	# v3에서는 **스테이지 보스에게 상태가 붙어야 설계가 성립한다** — §3.3 C의 교육 목표가
	# "플레이어가 3스테이지에서 당한 유→화 콤보를 5스테이지에서는 자기 5칸으로 되갚는
	# 구조"이고, 되갚을 대상이 바로 C+다. 보스에서만 원소 레이어가 꺼지면 §4 전체가
	# 필드 잡몹 전용 장식이 된다. **마왕은 종전대로 면역이다**(v2 회귀 0).
	var status_eligible := (not bool(target.get("is_boss"))) or bool(target.get("is_stage_boss"))
	var element := card_element(card)
	var dealt := damage_value
	var status_result: Dictionary = {}
	if status_eligible and StatusEngine.is_state(target.st_state):
		# ① 직격 보정 — 반드시 apply()보다 먼저.
		if not element.is_empty():
			dealt *= StatusEngine.incoming_multiplier(target.st_state, element)
		dealt *= StatusEngine.consume_shock(target.st_state)
		# ② 매트릭스. potency는 L1이 만든 이번 스텝의 상태 위력이다(§4.5 · 유일한 통로).
		if not element.is_empty():
			status_result = StatusEngine.apply(target.st_state, element, card_status_power(card), {
				"damage": damage_value,
				"potency": game.current_cycle_potency(),
				"depth": 0,
				"budget": status_budget,
				# Y7(§4.5 · §9.4 "stack_bonus"): 「맹독 십자」의 authored 키를 엔진에 싣는다.
				# `status_engine.gd:483`이 "combat_resolver가 실어 준다"고 적어 뒀지만
				# **아무도 안 싣고 있었다** — 그래서 그 카드의 콤보 문구
				# 「이미 독이 있으면 두 배로 쌓는다」가 지금까지 거짓이었다.
				# 엔진이 하한 1.0으로 자르므로 키가 없는 27장은 종전과 완전히 같다.
				"stack_bonus": float(card.get("status_stack_bonus", 1.0))
			})
	target.take_damage(dealt, center)
	_apply_card_status_to_enemy(target, card, center, status_result, damage_value)
	return dealt


## 카드의 원소(§4.2 7계). 인스턴스에는 태그가 없어 정의를 되읽어야 하는 경우가 있다.
func card_element(card: Dictionary) -> String:
	var element := String(card.get("element", ""))
	if not element.is_empty():
		return element
	var card_id := String(card.get("id", ""))
	if card_id.is_empty():
		return ""
	return String(DealCardLibrary.by_id(card_id).get("element", ""))


## 카드가 정하는 상태 세기(`power`). 한의 감속량과 연·독의 틱 피해를 곱한다.
## (대폭 연소의 ×3은 카드가 아니라 매트릭스가 곱하는 값이라 여기와 무관하다.)
##
## ── V10 판정(2026-08-09): **1.0으로 확정한다. 축을 만들지 않는다.** ──────────
## handoff-v6 §7 미결 1이 "V10이 카드별 계수를 넣을지 판단"으로 남긴 항목이다.
## 넣지 않기로 한 근거는 셋이고 전부 `balance_probe` ⑫ 실측에서 나왔다.
##
##   ① **상태 레이어는 이미 제 몫을 하고 있다.** 계수 없이도 원소 덱은 보스전 피해의
##      14~43%를 도트·시너지로 낸다(1스테이지 14% → 5스테이지 29% · 기름+불 덱 43%).
##      "채널이 뚫려 있는데 아무 일도 안 일어난다"가 아니다.
##   ② **차별화는 이미 다른 축이 하고 있다.** 카드마다 `damage`가 다르고 P = 그 피해다
##      (`StatusEngine.potency_damage`). 즉 센 카드는 이미 센 도트를 남긴다. 여기에
##      계수를 또 곱하면 같은 축을 두 번 곱하는 것이 된다.
##   ③ **지금 넣으면 방금 잰 표가 무효가 된다.** V10이 `BossLibrary.DESIGN_HP` 3개를
##      이 함수가 1.0이라는 전제로 확정했다(⑫). 카드 28종에 계수를 흩뿌리면 보스 다섯의
##      전투 길이를 전부 다시 재야 하고, 그 재측정은 플레이테스트 **뒤에** 하는 것이 맞다.
##
## ⚠️ 이 판정은 "영원히 하지 마라"가 아니라 **"플레이테스트 뒤에 하라"**다.
##    하게 되면 순서는 이렇다: ㄱ. `deal_card_library`에 `status_power` 키를 더한다
##    ㄴ. 여기서 `float(card.get("status_power", 1.0))`을 돌려준다 ㄷ. `balance_probe`
##    ⑫를 다시 돌려 `DESIGN_HP`를 재확정한다. **ㄷ을 건너뛰면 보스가 다섯 다 무너진다.**
##    같은 축에 걸려 있는 항목이 하나 더 있다 — `status_engine._row_ice()`의 "한 강화"
##    계수(handoff-v1 §V10 #1). 그쪽도 `power`가 1.0인 한 성립하지 않는다.
func card_status_power(_card: Dictionary) -> float:
	return 1.0


## 증기(§4.4 화↓×한→)가 내는 **이번 타격**의 범위 보정. 타격 전에 물어야 한다 —
## 사후 `apply()`의 range_bonus를 쓰면 한 펄스 늦는다(handoff-v1 §6 위험 4).
## 화염 카드일 때만 질의하므로 다른 6원소에서는 비용이 `String` 비교 한 번이다.
func status_range_bonus(center: Vector2, base_radius: float, card: Dictionary) -> float:
	if card_element(card) != "fire":
		return 0.0
	for other: Node in query_enemies(center, base_radius):
		if not is_instance_valid(other) or other.dead or bool(other.is_boss):
			continue
		var peek := StatusEngine.preview(other.st_state, "fire", 1.0, {})
		var bonus := float(peek.get("range_bonus", 0.0))
		if bonus > 0.0:
			return bonus
	return 0.0


## Y7(§7.3 `drag`): 「끌어당김」의 최소 세기. 카드가 `pull` 키를 안 들고 있어도
## `impact:"drag"`면 이만큼은 당긴다. 좌표를 움직이는 일은 규칙 계층의 몫이라
## 이 숫자만 여기 있다(나머지 시간 효과 눈금은 전부 `enemy.gd`가 소유한다).
const IMPACT_DRAG_PULL := 0.22

func _apply_card_status_to_enemy(target: Node, card: Dictionary, center: Vector2,
		status_result: Dictionary = {}, damage_value: float = 0.0) -> void:
	if not is_instance_valid(target):
		return
	var reaction := DealCardLibrary.knockback_profile(card)
	var knock_force := float(reaction.get("force", 0.0))
	var knock_stun := float(reaction.get("stun", 0.0))
	# Y7(§7.3): 카드의 authored 충격 프로필. 넉백·경직 **수치**는 이미 위
	# `knockback_profile()`이 이 키를 보고 정했고, 여기서 넘기는 것은 수치로
	# 표현할 수 없는 것(붙잡기 · 띄우기 · 공격 끊기)을 대상이 스스로 처리하게 하기
	# 위해서다. 빈 문자열이면 종전과 완전히 같은 경로다(BASIC 등 impact 없는 카드).
	var impact := String(card.get("impact", ""))
	# V7: 마왕만 상태·반응 경로에서 빠진다(위 `status_eligible`과 같은 판정).
	if bool(target.get("is_boss")) and not bool(target.get("is_stage_boss")):
		if target.has_method("apply_hit_reaction"):
			target.apply_hit_reaction(center, knock_force, knock_stun, impact)
		return
	# L1 `ice>strike` 쇄빙 준비의 경직 +0.2초 (handoff-v2 §3의 stun_bonus 채널).
	knock_stun += game.current_cycle_stun_bonus()
	# ③ 넉백 배율은 이벤트에서 온다. 여기서 한 번만 적용한다.
	var knock_mul := 1.0
	for entry in (status_result.get("events", []) as Array):
		var event: Dictionary = entry
		if String(event.get("kind", "")) != StatusEngine.E_KNOCKBACK:
			continue
		knock_mul *= float(event.get("knockback_mul", 1.0))
		knock_stun = maxf(knock_stun, float(event.get("stun", 0.0)))
	if target.has_method("apply_hit_reaction"):
		target.apply_hit_reaction(center, knock_force * knock_mul, knock_stun, impact)
	_run_status_events(target, center, status_result, damage_value)
	var slow_strength := float(card.get("slow", 0.0))
	# =========================================================================
	# Y7(§7.3): 충격 프로필의 **시간 효과**. 대상 쪽 셋만 여기서 건다.
	# =========================================================================
	# `pin`(정지) · `pop`(체공) · `stagger`(공격 취소)는 `apply_hit_reaction`이 이미
	# 처리했다. 남은 것은 이동 배율을 만지는 둘과 끌어당김이다.
	#   slow → 이동 −35% 1.2초  ·  rush → 「점점 느려짐」 0.9→0.5 1.5초
	# **새 자원을 만들지 않는다** — 둘 다 기존 `apply_cycle_slow()` 창구를 쓴다.
	# 지속 시간과 세기의 정본은 `enemy.gd`가 갖는다 — 규칙 계층이 연출 눈금을
	# 들고 있으면 두 파일이 갈라진다. 여기서는 "어떤 프로필인가"만 넘긴다.
	if impact in ["slow", "rush"] and target.has_method("apply_impact_time_effect"):
		target.apply_impact_time_effect(impact)
	if slow_strength > 0.0 and target.has_method("apply_cycle_slow"):
		target.apply_cycle_slow(slow_strength, 1.35)
	var pull_strength := float(card.get("pull", 0.0))
	# 「끌어당기기」(`drag`)는 카드에 `pull` 키가 없어도 성립해야 한다 — 지금은
	# `gravity_well` 한 장뿐이라 우연히 겹치지만, 그 우연에 기대면 다음에 `drag`가
	# 붙는 카드가 조용히 아무 일도 안 하게 된다.
	if impact == "drag":
		pull_strength = maxf(pull_strength, IMPACT_DRAG_PULL)
	if pull_strength > 0.0 and not target.dead:
		var pulled_position: Vector2 = target.global_position.lerp(center, clampf(pull_strength, 0.0, 0.42))
		if game.can_enemy_stand(pulled_position):
			target.global_position = pulled_position


# =============================================================================
# V6: 이벤트 집행 — 엔진이 "해 달라"고 부탁한 6종을 세계에 적용한다
# =============================================================================
# 엔진은 좌표도 이웃도 모른다. 반경 질의·노드 접근은 전부 여기서만 일어난다.
func _run_status_events(origin: Node, center: Vector2, status_result: Dictionary, damage_value: float) -> void:
	if status_result.is_empty():
		return
	status_suppressed_total += int(status_result.get("suppressed", 0))
	var reactions: Array = status_result.get("reactions", [])
	if not reactions.is_empty():
		status_reactions_fired += reactions.size()
		_announce_reactions(origin, center, reactions)
	for entry in (status_result.get("events", []) as Array):
		var event: Dictionary = entry
		status_events_run += 1
		match String(event.get("kind", "")):
			StatusEngine.E_DAMAGE:
				if is_instance_valid(origin) and not origin.dead:
					origin.take_damage(float(event.get("amount", 0.0)), center, 0.0, 0.0, StatusEngine.SOURCE_REACTION)
			StatusEngine.E_AOE_DAMAGE:
				_run_status_aoe(event, center)
			StatusEngine.E_CHAIN_DAMAGE:
				_run_status_chain(origin, event, center)
			StatusEngine.E_SPREAD_STATUS:
				_run_status_spread(origin, event, center, damage_value)
			StatusEngine.E_KNOCKBACK:
				pass    # 넉백은 호출자가 카드 넉백과 합쳐 한 번만 낸다(이중 적용 금지)
			StatusEngine.E_RANGE_BONUS:
				pass    # 타격 전 status_range_bonus()가 이미 반영했다(이중 적용 금지)


## 역병 발화 · 감전 유막. 반경 내 전원에게 즉발 피해(+선택적 표식).
func _run_status_aoe(event: Dictionary, center: Vector2) -> void:
	var amount := float(event.get("amount", 0.0))
	var radius := float(event.get("radius", 0.0))
	var mark := String(event.get("apply_status", ""))
	for other: Node in query_enemies(center, radius):
		if not is_instance_valid(other) or other.dead or bool(other.is_boss):
			continue
		if amount > 0.0:
			other.take_damage(amount, center, 0.0, 0.0, StatusEngine.SOURCE_REACTION)
		# 표식은 `set_status`로 심는다 — 뇌 행을 다시 돌리면 전도가 재귀한다.
		if not mark.is_empty() and is_instance_valid(other) and not other.dead:
			StatusEngine.set_status(other.st_state, mark)


## ★전도. 반경 내에서 **`filter` 상태를 가진 적만** 골라 `max_targets`까지 도약한다.
## k번째 피해는 반드시 `StatusEngine.chain_damage(event, k)` — 감쇠식을 두 벌 만들면
## `--status-test`가 보는 값과 실기가 갈라진다(handoff-v1 §5.2).
func _run_status_chain(origin: Node, event: Dictionary, center: Vector2) -> void:
	var radius := float(event.get("radius", 0.0))
	var max_targets := maxi(0, int(event.get("max_targets", 0)))
	var filter := String(event.get("filter", ""))
	var mark := String(event.get("apply_status", ""))
	var hop := 0
	for other: Node in query_enemies(center, radius):
		if hop >= max_targets:
			break
		if not is_instance_valid(other) or other.dead or bool(other.is_boss) or other == origin:
			continue
		if not filter.is_empty() and not StatusEngine.has(other.st_state, filter):
			continue
		other.take_damage(StatusEngine.chain_damage(event, hop), center, 0.0, 0.0, StatusEngine.SOURCE_REACTION)
		if not mark.is_empty() and is_instance_valid(other) and not other.dead:
			StatusEngine.set_status(other.st_state, mark)
		game.spawn_synergy_effect(other.global_position, String(event.get("reaction", "")))
		hop += 1
	status_chain_hops += hop


## ★대폭 연소의 기름 전파. **`depth`를 이벤트에서 가져와 그대로 되넘긴다** —
## 안 넘기면 깊이 가드가 무력화되고 기름 웅덩이 연쇄 폭발이 난다(§4.7 규칙 4).
## 유(oil) 행은 질의 이벤트를 내지 않으므로 여기서 재귀 집행은 하지 않는다.
func _run_status_spread(origin: Node, event: Dictionary, center: Vector2, damage_value: float) -> void:
	var status := String(event.get("status", ""))
	if status.is_empty():
		return
	var depth := maxi(0, int(event.get("depth", 0)))
	status_max_depth_seen = maxi(status_max_depth_seen, depth)
	var radius := float(event.get("radius", 0.0))
	var power := float(event.get("power", 1.0))
	var spread_ctx := {
		"damage": damage_value,
		"potency": game.current_cycle_potency(),
		"depth": depth,
		"budget": status_budget
	}
	for other: Node in query_enemies(center, radius):
		# 원점은 뺀다 — 방금 대폭 연소로 그 기름을 태웠는데 같은 프레임에 다시 바르면
		# 소모가 무의미해진다.
		if not is_instance_valid(other) or other.dead or bool(other.is_boss) or other == origin:
			continue
		var spread := StatusEngine.apply(other.st_state, status, power, spread_ctx)
		status_suppressed_total += int(spread.get("suppressed", 0))
		status_spread_applied += 1


## 1회성 정적 강조(§4.8): 시너지 버스트 + 부유 라벨. 트윈 루프를 쓰지 않는다.
## 평범한 부여·갱신은 `REACTION_LABELS`가 빈 문자열이라 아무것도 뜨지 않는다.
func _announce_reactions(origin: Node, center: Vector2, reactions: Array) -> void:
	var at := center
	if is_instance_valid(origin):
		at = origin.global_position
	for value in reactions:
		var key := String(value)
		var label := String(StatusEngine.REACTION_LABELS.get(key, ""))
		if label.is_empty():
			continue
		game.spawn_synergy_effect(at, key)
		if status_labels_this_frame >= MAX_REACTION_LABELS_PER_FRAME:
			continue
		status_labels_this_frame += 1
		game.show_world_text(at - Vector2(0.0, 46.0), label, game.synergy_label_color(key), 18)


func _trigger_boss_cycle_pulse(actor: Node2D, card: Dictionary, action_origin: Vector2, damage_mul: float = 1.0) -> void:
	if not is_instance_valid(game.player):
		return
	var kind := String(card.get("kind", "melee"))
	var direction: Vector2 = actor.global_position.direction_to(game.player.global_position)
	var damage_value := _cycle_damage_value(actor, card, true, damage_mul)
	var range_value := float(card.get("range", 150.0))
	match kind:
		"projectile", "chain":
			var count := clampi(int(card.get("projectiles", 1)) + int(card.get("ricochet", 0)) / 2, 1, 7)
			for index in count:
				var spread := (float(index) - float(count - 1) * 0.5) * 0.22
				spawn_enemy_bullet(actor.global_position + direction * 58.0, direction.rotated(spread), kind == "chain", damage_value, 235.0)
		"area", "orbit":
			if actor.global_position.distance_to(game.player.global_position) <= range_value:
				game.player.take_damage(damage_value, actor.global_position)
			game.spawn_burst(actor.global_position, GamePalette.RED, 10, 100.0, 0.25)
		"ground":
			if action_origin.distance_to(game.player.global_position) <= range_value:
				game.player.take_damage(damage_value, action_origin)
			game.spawn_burst(action_origin, GamePalette.RED, 12, 120.0, 0.28)
		"shield":
			game.spawn_burst(actor.global_position, GamePalette.BLUE, 12, 95.0, 0.28)


# W2: 딜싸이클 피해의 **유일한** 계산 지점이다. 근접·투사체·연쇄·광역·보스 전 경로가
# 여기로 모이므로, 과열(§3.5)·재진입 감쇠(§3.6)·각인 피해 각인이 만든 스텝 배율은
# `damage_mul` 한 인자로만 들어온다. 다른 곳에서 배율을 곱하지 말 것.
func _cycle_damage_value(actor: Node2D, card: Dictionary, is_boss_cycle: bool, damage_mul: float = 1.0) -> float:
	var step_mul := maxf(0.0, damage_mul)
	if is_boss_cycle:
		return maxf(3.0, 2.4 + float(card.get("damage", 1.0)) * step_mul * (2.0 + float(game.cycle_number) * 0.18))
	var base_damage: float = game.player.damage * float(card.get("damage", 1.0)) * step_mul
	var crit_chance: float = game.player.crit_chance + float(card.get("crit", 0.0))
	return base_damage * (game.player.crit_multiplier if game.rng.randf() < crit_chance else 1.0)


# =============================================================================
# 캐릭터 평타 · 대시 피해 · 궤도 검
# =============================================================================

func perform_character_attack(attacker: Node2D) -> void:
	if not is_instance_valid(attacker):
		return
	var facing: Vector2 = attacker.current_attack_direction.normalized()
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	match attacker.character_id:
		"archer": _perform_archer_attack(attacker, facing)
		"mage": _perform_mage_attack(attacker, facing)
		_: _perform_sword_attack(attacker, facing)


func _perform_sword_attack(attacker: Node2D, facing: Vector2) -> void:
	var attack_count: int = maxi(attacker.projectile_count, 1)
	var already_hit: Dictionary = {}
	# 검격 색 = **마지막으로 획득한 보스 트로피의 색**. v2에서는 각성 계보의 색이었고
	# V10(2026-08-09)이 `ClassLibrary` shim을 걷어내면서 `TrophyLibrary`를 직접 부른다
	# (그 shim은 이 두 줄만을 위해 살아 있었다 · handoff-v9 §9 #9).
	var slash_color := GamePalette.YELLOW
	if not attacker.last_trophy_id.is_empty():
		slash_color = Color(String(TrophyLibrary.by_id(attacker.last_trophy_id).get("color", "f4d35e")))
	game.spawn_attack_effect(attacker.global_position, "slash", slash_color, facing, attacker.attack_range, 0.18)
	for strike in attack_count:
		var offset := float(strike) - float(attack_count - 1) * 0.5
		var strike_direction := facing.rotated(offset * 0.22)
		for target: Node in query_enemies(attacker.global_position, attacker.attack_range + 70.0):
			if not is_instance_valid(target) or target.dead:
				continue
			var offset_to_target: Vector2 = target.global_position - attacker.global_position
			var distance := offset_to_target.length()
			var to_target := offset_to_target.normalized() if distance > 0.01 else strike_direction
			var in_visible_cone: bool = distance <= float(attacker.attack_range) + float(target.radius) and strike_direction.dot(to_target) >= cos(float(attacker.attack_arc) * 0.5)
			# Target radius padding prevents the blade from visually clipping an enemy without a hit.
			var forward := offset_to_target.dot(strike_direction)
			var lateral := absf(offset_to_target.cross(strike_direction))
			var swept_blade: bool = forward >= 0.0 and forward <= float(attacker.attack_range) + float(target.radius) and lateral <= 26.0 + float(target.radius)
			if in_visible_cone or swept_blade:
				var hit_damage := _roll_player_damage(attacker)
				target.take_damage(hit_damage, attacker.global_position, 185.0, 0.08)
				already_hit[target.get_instance_id()] = true
				game.spawn_burst(target.global_position, GamePalette.YELLOW, 7, 110.0, 0.22)
	if attacker.ricochet_count > 0 and not already_hit.is_empty():
		_chain_damage(attacker, already_hit)
	game.play_sound("shoot", -8.0)


func process_orbit_blades(attacker: Node2D) -> void:
	if not is_instance_valid(attacker) or attacker.orbit_blade_count <= 0:
		return
	var hits := 0
	for target: Node in query_enemies(attacker.global_position, 115.0):
		if not is_instance_valid(target) or target.dead:
			continue
		var distance := attacker.global_position.distance_to(target.global_position)
		if distance >= 30.0 and distance <= 82.0 + target.radius:
			target.take_damage(attacker.damage * (0.28 + attacker.orbit_blade_count * 0.08), attacker.global_position, 82.0, 0.04)
			game.spawn_burst(target.global_position, GamePalette.CYAN, 5, 90.0, 0.2)
			hits += 1
			if hits >= attacker.orbit_blade_count:
				break


func _perform_archer_attack(attacker: Node2D, facing: Vector2) -> void:
	var count: int = maxi(attacker.projectile_count, 1)
	for index in count:
		var offset := float(index) - float(count - 1) * 0.5
		var direction := facing.rotated(offset * attacker.spread_angle)
		spawn_player_projectile(
			attacker.global_position + direction * 25.0,
			direction,
			_roll_player_damage(attacker),
			attacker.projectile_speed,
			0.0,
			attacker.ricochet_count,
			attacker.pierce_count,
			GamePalette.YELLOW,
			"arrow"
		)
	game.spawn_attack_effect(attacker.global_position, "bow", GamePalette.GREEN, facing, 70.0, 0.12)
	game.play_sound("shoot", -10.0)


func _perform_mage_attack(attacker: Node2D, facing: Vector2) -> void:
	var count: int = maxi(attacker.projectile_count, 1)
	for index in count:
		var offset := float(index) - float(count - 1) * 0.5
		var direction := facing.rotated(offset * 0.32)
		var center: Vector2 = attacker.global_position + direction * attacker.attack_range * 0.58
		game.spawn_attack_effect(attacker.global_position, "magic", GamePalette.MAGENTA, direction, attacker.attack_range, 0.32)
		for target: Node in query_enemies(center, attacker.attack_range * 0.7):
			if is_instance_valid(target) and not target.dead and target.global_position.distance_to(center) < attacker.attack_range * 0.58 + target.radius:
				target.take_damage(_roll_player_damage(attacker), center, 125.0, 0.065)
				game.spawn_burst(target.global_position, GamePalette.MAGENTA, 8, 125.0, 0.28)
	game.play_sound("shoot", -7.0)


func _roll_player_damage(attacker: Node) -> float:
	return attacker.damage * (attacker.crit_multiplier if game.rng.randf() < attacker.crit_chance else 1.0)


func _chain_damage(attacker: Node, excluded: Dictionary) -> void:
	var origin: Vector2 = attacker.global_position
	for _bounce in attacker.ricochet_count:
		var next_target := find_nearest_enemy(origin, excluded, 270.0)
		if not is_instance_valid(next_target):
			break
		excluded[next_target.get_instance_id()] = true
		next_target.take_damage(attacker.damage * 0.62, origin, 70.0, 0.04)
		game.spawn_burst(next_target.global_position, GamePalette.CYAN, 8, 125.0, 0.25)
		origin = next_target.global_position


# W3에서 skill_effect_controller.gd::process_dash_damage를 그대로 흡수했다(§7.3 W3-④).
# skill_effect_controller.gd 자체는 남는다 — 화염 장판·오라(ground_zones/_tick_damage/_draw)가
# 아직 살아 있는 경로이고 --stress-test가 실제로 그 둘을 켜서 돌린다. 파일 삭제는
# 그 두 시스템의 거취가 정해지는 웨이브(§7.1 player.gd `_apply_skill_stats` 폐기 검토)의 몫이다.
func process_dash_damage(hit_ids: Dictionary) -> void:
	if not is_instance_valid(game.player):
		return
	if int(game.player.dash_damage_rank) <= 0:
		return
	for enemy: Node in query_enemies(game.player.global_position, 48.0):
		if not is_instance_valid(enemy) or enemy.dead or hit_ids.has(enemy.get_instance_id()):
			continue
		hit_ids[enemy.get_instance_id()] = true
		enemy.take_damage(game.player.damage * (0.7 + float(game.player.dash_damage_rank) * 0.3), game.player.global_position)
		game.spawn_burst(enemy.global_position, GamePalette.CYAN, 6, 105.0, 0.2)


# =============================================================================
# 투사체 생성
# =============================================================================

## `card`를 넘기면 명중 시 V6 상태 파이프라인이 함께 돈다(투사체 카드 6장 = 관통 계열).
## V7(2026-08-09): V6은 `projectile.gd`를 열 수 없어 `body_entered`에 **먼저 연결**하는
## 우회로를 썼다(handoff-v6 §7 · §11 미결 3 = "시그널 연결 순서에 의존"). V7이
## `projectile.gd`를 소유하면서 **`setup()`의 마지막 인자**로 옮겼다 — 암묵 계약이 사라지고
## 명중 처리 순서가 `TechProjectile._on_body_entered` 안에서 눈에 보인다.
func spawn_player_projectile(world_position: Vector2, direction: Vector2, damage: float, speed: float, homing: float, ricochets: int, pierces: int, color: Color, visual_kind: String = "arrow", travel_range: float = 0.0, card: Dictionary = {}) -> void:
	if not is_instance_valid(game.gameplay_root):
		return
	var projectile := TechProjectile.new()
	var status_card: Dictionary = card if (not card.is_empty() and not card_element(card).is_empty()) else {}
	projectile.setup(game, direction, damage, speed, homing, ricochets, pierces, color, visual_kind, travel_range, status_card)
	projectile.position = world_position
	game.gameplay_root.add_child(projectile)


## 투사체 명중의 V6 처리. **`projectile.gd`가 자기 직격 피해보다 먼저 부른다**(V7 이관).
## 그래서 기름의 화염 증폭·전 표식을 `apply()`가 소모하기 전에 물을 수 있다.
func on_projectile_card_hit(body: Node, projectile: Node, card: Dictionary) -> void:
	if not is_instance_valid(body) or not is_instance_valid(projectile):
		return
	if not body.is_in_group("enemies") or bool(body.get("dead")) or bool(body.get("is_boss")):
		return
	# 투사체 자신의 중복 판정과 같은 규칙을 쓴다(관통·도탄이 같은 적을 두 번 세지 않는다).
	if (projectile.hit_ids as Dictionary).has(body.get_instance_id()):
		return
	if not StatusEngine.is_state(body.st_state):
		return
	var element := card_element(card)
	var base_damage := float(projectile.damage)
	var bonus_mul := StatusEngine.incoming_multiplier(body.st_state, element) * StatusEngine.consume_shock(body.st_state)
	var result := StatusEngine.apply(body.st_state, element, card_status_power(card), {
		"damage": base_damage,
		"potency": game.current_cycle_potency(),
		"depth": 0,
		"budget": status_budget,
		# Y7: 투사체 경로도 같은 채널을 탄다(근접만 두 배로 쌓이면 그게 더 이상하다).
		"stack_bonus": float(card.get("status_stack_bonus", 1.0))
	})
	# ⚠️ 증폭분은 **별도 타격**으로 낸다. `projectile.damage`를 곱해 두면 관통·도탄의
	#    다음 대상까지 그 배율을 끌고 간다(기름 없는 적이 ×2.2를 맞는다).
	if bonus_mul > 1.0:
		body.take_damage(base_damage * (bonus_mul - 1.0), projectile.global_position, 0.0, 0.0, StatusEngine.SOURCE_REACTION)
	# 쇄빙 넉백: 투사체는 자기 `impact_force`를 스스로 내므로 여기서는 **증분만** 낸다.
	# 카드의 넉백 프로필 × (배율 − 1) = 근접 경로의 "프로필 × 배율"과 총량이 같다.
	var knock_profile := DealCardLibrary.knockback_profile(card)
	for entry in (result.get("events", []) as Array):
		var event: Dictionary = entry
		if String(event.get("kind", "")) != StatusEngine.E_KNOCKBACK or bool(body.dead):
			continue
		body.apply_hit_reaction(projectile.global_position,
			float(knock_profile.get("force", 0.0)) * maxf(0.0, float(event.get("knockback_mul", 1.0)) - 1.0),
			float(event.get("stun", 0.0)), String(card.get("impact", "")))
	_run_status_events(body, projectile.global_position, result, base_damage)


func spawn_enemy_bullet(world_position: Vector2, direction: Vector2, homing: bool, damage: float, speed: float) -> void:
	if not is_instance_valid(game.gameplay_root) or not is_instance_valid(game.player):
		return
	var bullet := EnemyBullet.new()
	bullet.setup(game, game.player, direction, homing, damage, speed)
	bullet.position = world_position
	game.gameplay_root.add_child(bullet)


# =============================================================================
# 처치 처리와 보상
# =============================================================================

# =============================================================================
# V6: 전역 킬 체인 깊이 가드 (§4.7 추가 함정)
# =============================================================================
# 도트로 죽은 적도 이 함수를 그대로 탄다. 안에서 성스러운 파동(반경 275 광역)과
# 뇌 연쇄(4~6체)가 터지고 그 피해가 또 적을 죽이면 **재귀로 다시 들어온다.**
# v2에는 파동 자기 자신만 막는 `hotfix_burst_running` 빗장뿐이라 파동→연쇄→파동
# 교차 재귀가 열려 있었고, v3는 도트가 0.25초마다 78기를 동시에 죽일 수 있어
# 그 구멍이 실제로 열린다.
#
# 상한을 넘으면 **보상(경험치·골드·킬 카운트)은 그대로 주고 2차 연출만 끊는다.**
# 보상을 끊으면 프레임률이 게임 규칙을 바꾸게 되는데 그건 성능 보호가 아니다 —
# `StatusEngine._emit()`이 예산 고갈 때 상태 수치는 손대지 않는 것과 같은 판단이다.
func enemy_defeated(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	kill_chain_depth += 1
	kill_chain_peak = maxi(kill_chain_peak, kill_chain_depth)
	_enemy_defeated_body(enemy)
	kill_chain_depth = maxi(0, kill_chain_depth - 1)


func _enemy_defeated_body(enemy: Node) -> void:
	var enemy_position: Vector2 = enemy.global_position
	var enemy_xp: int = enemy.xp_value
	var enemy_gold: int = enemy.gold_value
	var was_boss: bool = enemy.is_boss
	if not was_boss:
		game.kills += 1
		game.gold += int(ceil(float(enemy_gold) * game.player.gold_multiplier))
		if game.player.life_on_kill > 0.0:
			game.player.heal(game.player.life_on_kill)
	game.spawn_burst(enemy_position, GamePalette.RED if not was_boss else GamePalette.YELLOW, 12 if not was_boss else 48, 180.0 if not was_boss else 350.0, 0.4 if not was_boss else 1.1)
	if not was_boss and enemy_xp > 0:
		spawn_or_merge_xp_orb(enemy_position, enemy_xp)
	if was_boss:
		game.call_deferred("_finish_run", true)
		return
	if not String(enemy.camp_id).is_empty():
		game._trial_enemy_defeated(String(enemy.camp_id))
	# 여기부터가 **또 적을 죽일 수 있는** 2차 연출이다. 깊이 상한을 넘으면 끊는다.
	if kill_chain_depth > GameTuning.STATUS_KILL_CHAIN_DEPTH_MAX:
		kill_chain_suppressed += 1
		return
	if is_instance_valid(game.player) and game.player.holy_pulse_enabled and game.kills > 0 and game.kills % 8 == 0 and not hotfix_burst_running:
		_trigger_holy_pulse(enemy_position)
	if is_instance_valid(game.player) and game.player.thunder_rank > 0 and game.kills % maxi(2, 6 - game.player.thunder_rank) == 0:
		_trigger_thunder(enemy_position)
	if game.kills % 3 == 0:
		game.play_sound("hit", -14.0)


func spawn_or_merge_xp_orb(world_position: Vector2, value: int) -> void:
	var orbs: Array[Node] = game.get_tree().get_nodes_in_group("xp_orbs")
	if orbs.size() >= GameTuning.MAX_XP_ORBS:
		var nearest_orb: Node
		var nearest_distance := INF
		for orb: Node in orbs:
			if not is_instance_valid(orb):
				continue
			var distance := world_position.distance_squared_to(orb.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_orb = orb
		if is_instance_valid(nearest_orb) and nearest_orb.has_method("add_value"):
			nearest_orb.add_value(value)
			return
	var orb := ExperienceOrb.new()
	orb.setup(game, game.player, value)
	orb.position = world_position
	game.gameplay_root.add_child(orb)


func _trigger_holy_pulse(origin: Vector2) -> void:
	hotfix_burst_running = true
	game.spawn_burst(origin, GamePalette.YELLOW, 38, 315.0, 0.7)
	game.show_world_text(origin - Vector2(0.0, 40.0), "성스러운 파동", GamePalette.YELLOW, 21)
	for target: Node in query_enemies(origin, 275.0):
		if is_instance_valid(target) and not target.is_boss and origin.distance_to(target.global_position) < 275.0:
			target.take_damage(game.player.damage * 1.65, origin, 255.0, 0.13)
	hotfix_burst_running = false


func _trigger_thunder(origin: Vector2) -> void:
	var excluded := {}
	var lightning_origin := origin
	for _strike in mini(2 + game.player.thunder_rank, 6):
		var target := find_nearest_enemy(lightning_origin, excluded, 420.0)
		if not is_instance_valid(target):
			break
		excluded[target.get_instance_id()] = true
		game.spawn_attack_effect(target.global_position, "magic", GamePalette.CYAN, Vector2.UP, 100.0, 0.28)
		game.spawn_burst(target.global_position, GamePalette.CYAN, 12, 155.0, 0.32)
		target.take_damage(game.player.damage * (0.72 + game.player.thunder_rank * 0.12), lightning_origin, 66.0, 0.04)
		lightning_origin = target.global_position
	game.play_sound("shoot", -4.0)
