class_name WFCChunkGenerator
extends RefCounted

# 논문의 Simple Tiled WFC를 무한 월드에 맞게 청크 단위로 확장한 생성기입니다.
# 각 칸은 가능한 타일 후보 집합으로 시작하고(MRV/최소 엔트로피), 하나를 확정한
# 뒤 인접 소켓 규칙을 주변으로 전파합니다. 전역 격자를 한 번에 풀지 않고 카메라가
# 방문한 청크만 만듭니다.
#
# 2026-08-04 (3차 피드백 ⑱ "맵이 깨진다") 근본 수정:
# 이전 버전은 물·물가 타일까지 확률 풀에 섞어 WFC가 자유롭게 뽑게 했습니다.
# 그런데 terrain-atlas-wfc-v2 아틀라스에는 물 모양에 꼭 필요한 두 종류의 그림이
# 아예 없습니다 — ①안쪽(오목) 모서리: 네 방향 중 한쪽만 물인 칸 ②1칸 폭 수로:
# 서로 마주보는 두 방향만 물인 칸. 소켓(변 라벨)만으로는 이 결핍을 표현할 수
# 없으므로 규칙상 "허용"되지만 그림이 전혀 이어지지 않는 조합이 계속 뽑혔고,
# 그 결과 호수가 조각난 픽셀 덩어리처럼 보였습니다.
#
# 그래서 물은 이제 확률로 뽑지 않고, 전역 좌표만으로 결정되는 호수 레이어가
# 먼저 확정합니다. 호수는 항상 **2x2 블록의 합집합**으로 만듭니다. 이 형태는
# 다음이 보장됩니다: 젖은 칸은 자기 2x2 블록 안에 가로 이웃 1개와 세로 이웃
# 1개를 반드시 가지므로, 마른 이웃은 최대 2개이며 절대 서로 마주보지 않는다.
# 즉 필요한 물 타일은 (안 물 / 한 변 물가 4종 / 인접한 두 변 물가 4종) 9종뿐이고
# 이 9종은 모두 아틀라스에 실제로 그려져 있습니다. 그래서 어떤 호수도 그림이
# 끊기지 않습니다. WFC는 나머지 육지 칸을 가중치로 확정합니다(육지 타일은 모두
# 잔디 소켓이라 서로 자유롭게 이어집니다).

const CHUNK_TILES := 14
const CELL_COUNT := CHUNK_TILES * CHUNK_TILES
# V5(2026-08-09): `const WORLD_SEED` -> `var world_seed`. **알고리즘은 한 줄도 안 바뀐다.**
# 스테이지마다 월드를 통째로 재생성하므로(설계 §2.2) 생성기마다 다른 시드를 심어야
# 5스테이지가 서로 다른 지형이 된다. 기본값은 v2와 같아 시드를 안 주면 회귀가 0이다.
const WORLD_SEED_DEFAULT := 20260804
const MAX_RETRIES := 6
const MAX_CACHED_CHUNKS := 72
const CACHE_RADIUS := 5

const UP := 0
const RIGHT := 1
const DOWN := 2
const LEFT := 3
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OPPOSITE := [DOWN, LEFT, UP, RIGHT]

const LAND := 0
const WATER := 1
const SOCKET_COUNT := 2

# 논리 타일 id. atlas는 terrain-atlas-wfc-v2-runtime.png의 5x4 셀 번호,
# turn은 그릴 때 적용할 90도 시계방향 회전 횟수입니다. 회전을 쓰는 이유는
# 아틀라스에 호수의 남동/남서 모서리 그림만 있고 북서/북동 모서리가 없기
# 때문입니다. 같은 셀을 180/270도 돌려 나머지 두 모서리를 만듭니다.
const T_GRASS := 0
const T_GRASS_TUFT := 1
const T_GRASS_FLOWER := 2
const T_FOREST := 3
const T_ROCKS := 4
const T_WATER := 5
const T_SHORE_N := 6
const T_SHORE_E := 7
const T_SHORE_S := 8
const T_SHORE_W := 9
const T_SHORE_NW := 10
const T_SHORE_NE := 11
const T_SHORE_SE := 12
const T_SHORE_SW := 13
const T_BRIDGE := 14
const T_RUINS := 15
const T_COURTYARD := 16
const T_CAMP := 17
const TILE_COUNT := 18

# sockets 순서: 위, 오른쪽, 아래, 왼쪽. 같은 소켓끼리만 연결됩니다.
# weight가 0인 타일은 확률 풀에서 제외되며 호수 레이어나 랜드마크 레이어가
# 직접 지정할 때만 쓰입니다.
const TILE_RULES: Array[Dictionary] = [
	{"name":"grass", "atlas":0, "turn":0, "weight":70.0, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"grass_tuft", "atlas":1, "turn":0, "weight":13.0, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"grass_flower", "atlas":2, "turn":0, "weight":3.2, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"forest", "atlas":15, "turn":0, "weight":2.9, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"rocks", "atlas":16, "turn":0, "weight":1.6, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"water", "atlas":5, "turn":0, "weight":0.0, "water":true, "sockets":[WATER, WATER, WATER, WATER]},
	{"name":"shore_north", "atlas":6, "turn":0, "weight":0.0, "water":true, "sockets":[LAND, WATER, WATER, WATER]},
	{"name":"shore_east", "atlas":6, "turn":1, "weight":0.0, "water":true, "sockets":[WATER, LAND, WATER, WATER]},
	{"name":"shore_south", "atlas":6, "turn":2, "weight":0.0, "water":true, "sockets":[WATER, WATER, LAND, WATER]},
	{"name":"shore_west", "atlas":6, "turn":3, "weight":0.0, "water":true, "sockets":[WATER, WATER, WATER, LAND]},
	{"name":"shore_north_west", "atlas":12, "turn":2, "weight":0.0, "water":true, "sockets":[LAND, WATER, WATER, LAND]},
	{"name":"shore_north_east", "atlas":12, "turn":3, "weight":0.0, "water":true, "sockets":[LAND, LAND, WATER, WATER]},
	{"name":"shore_south_east", "atlas":12, "turn":0, "weight":0.0, "water":true, "sockets":[WATER, LAND, LAND, WATER]},
	{"name":"shore_south_west", "atlas":12, "turn":1, "weight":0.0, "water":true, "sockets":[WATER, WATER, LAND, LAND]},
	{"name":"bridge", "atlas":14, "turn":0, "weight":0.0, "water":true, "sockets":[WATER, WATER, WATER, WATER]},
	{"name":"ruins", "atlas":17, "turn":0, "weight":0.0, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"courtyard", "atlas":18, "turn":0, "weight":0.0, "water":false, "sockets":[LAND, LAND, LAND, LAND]},
	{"name":"camp", "atlas":19, "turn":0, "weight":0.0, "water":false, "sockets":[LAND, LAND, LAND, LAND]}
]

# 마른 이웃 방향 비트마스크(UP=1, RIGHT=2, DOWN=4, LEFT=8) → 물 타일.
# -1은 이 아틀라스에 그림이 없는 조합이며 2x2 블록 합집합에서는 발생하지 않습니다.
const WATER_TILE_BY_DRY: Array[int] = [
	T_WATER, T_SHORE_N, T_SHORE_E, T_SHORE_NE,
	T_SHORE_S, -1, T_SHORE_SE, -1,
	T_SHORE_W, T_SHORE_NW, -1, -1,
	T_SHORE_SW, -1, -1, -1
]

# 호수 레이어. 호수는 LAKE_CELL 타일 간격의 결정적 격자 위에 하나씩 놓이고,
# 2칸 단위로 정렬된 격자 위에 둥근 덩어리(반지름 + 해시 요동)를 찍어 만듭니다.
# 조각이 모두 2x2이고 짝수 좌표에 정렬돼 빈틈 없이 맞물리므로 결과는 항상
# "2x2 블록의 합집합"이며, 따라서 젖은 칸은 가로 이웃 1개와 세로 이웃 1개를
# 반드시 가집니다. 즉 마른 이웃이 서로 마주보거나 3면 이상이 되는 조합(그림이
# 없는 조합)이 생길 수 없습니다.
#
# Y5(2026-08-10) 물 증량 — FEEDBACK_Y §5.1 "젖은 칸 12~20%" · 사용자 피드백 ⑥ "바다 증량".
#
#   격자 간격 LAKE_CELL   18 -> 13
#   호수 확률 LAKE_CHANCE  9 -> 19
#   반지름 표             [1,1,2,2,2,3] -> [2,3,3,3,3,4]
#
# 실측: 젖은 칸 **총합 15.7%** · 300 표본(시드 20 × 스테이지 5 × 지점 3) 최소 12.6% 최대 20.0%로
# 전부 계약 창 안. 재는 자는 `scripts/test/terrain_probe.gd`이고 `--world-test`가 같은 계약을
# 게임 안에서 다시 문다. **2x2 블록 합집합 규칙과 짝수 정렬은 한 줄도 손대지 않았습니다**
# (그것이 3차 피드백 "맵이 깨진다"의 근본 수정이었고, 프로브가 매번 다시 확인합니다).
#
# ⚠️ **비율만 맞추면 되는 것이 아닙니다 — 세 상수는 같이 움직여야 합니다.**
#    Y5가 실제로 버린 후보 둘을 남겨 둡니다(다음에 같은 자리를 헤매지 않도록):
#      · `LAKE_CHANCE 41` + 반지름 `[1,2,2,2,2,2]` → 총합 16%인데 화면에는 **물웅덩이 노이즈**만.
#      · `LAKE_CHANCE 9`  + 반지름 `[4,4,4,5,5,5]` → 호수는 커졌지만 13칸 격자에 9%면
#        한 화면(38×23칸)에 호수가 **0.46개**라 **화면 절반에 물이 아예 없었습니다.**
#    지금 값은 한 화면에 호수 약 1개 · 지름 10~18칸(400~720px)입니다.
#
# ⚠️ 반지름 상한: `_is_wet()`이 자기 셀 ±1 셀만 뒤지므로 호수가 두 칸 건너 셀까지
#    뻗으면 먼 타일이 누락돼 호수가 잘립니다. 안전선은 `2r <= LAKE_CELL`(r <= 6)입니다.
# ⚠️ `LAKE_CELL - 5`가 중심 뽑기의 상한이라 LAKE_CELL은 10 미만으로 내릴 수 없습니다
#    (`randi_range(4, LAKE_CELL - 5)`의 하한이 상한을 넘어갑니다). 13은 여유가 있습니다.
const LAKE_CELL := 13
const LAKE_CHANCE := 19
const LAKE_RADIUS_TABLE: Array[int] = [2, 3, 3, 3, 3, 4]
const LAKE_SALT := 6151
const LAKE_CACHE_LIMIT := 512

var adjacency: Array[PackedInt32Array] = []
var socket_masks: Array[PackedInt32Array] = []
var pool_mask := 0
var chunk_cache: Dictionary = {}
var chunk_last_used: Dictionary = {}
var lake_cache: Dictionary = {}
var dry_zones: Array[Rect2] = []
var world_seed := WORLD_SEED_DEFAULT
var access_tick := 0
var generated_chunks := 0
var contradiction_retries := 0
var fallback_chunks := 0

func _init() -> void:
	_build_rules()

# 성·마왕성·시련 캠프처럼 바닥을 안전 타일로 덮는 지점과, 손으로 얹은 고정
# 물길처럼 WFC 호수가 겹치면 안 되는 구역입니다. 좌표는 모두 타일 단위입니다.
# 호수를 사각형 조각 단위로 걸러내므로 "변 길이 2 이상 사각형의 합집합" 성질이
# 깨지지 않습니다(칸 단위로 지웠다면 1칸 폭 물줄기가 남아 다시 그림이 끊깁니다).
## V5: 스테이지 시드 주입. 생성 **전에** 부른다(월드 재생성 직후 1회). 캐시를 비우므로
## 필드 도중에 불러도 안전하지만 지형이 통째로 바뀌므로 그렇게 쓰지 말 것.
func set_world_seed(value: int) -> void:
	if world_seed == value:
		return
	world_seed = value
	lake_cache.clear()
	chunk_cache.clear()
	chunk_last_used.clear()


func add_dry_zone(center_tile: Vector2, radius_tiles: float) -> void:
	var reach := radius_tiles + 2.0
	add_dry_rect(Rect2(center_tile - Vector2(reach, reach), Vector2(reach, reach) * 2.0))

func add_dry_rect(rect_tiles: Rect2) -> void:
	dry_zones.append(rect_tiles)
	lake_cache.clear()
	chunk_cache.clear()
	chunk_last_used.clear()

func tile_id_at(tile_coord: Vector2i) -> int:
	var chunk := chunk_for_tile(tile_coord)
	var local := tile_coord - chunk * CHUNK_TILES
	var tiles := _get_chunk(chunk)
	return int(tiles[local.y * CHUNK_TILES + local.x])

func chunk_for_tile(tile_coord: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(tile_coord.x) / float(CHUNK_TILES)),
		floori(float(tile_coord.y) / float(CHUNK_TILES))
	)

func is_water_tile(tile_id: int) -> bool:
	if tile_id < 0 or tile_id >= TILE_COUNT:
		return false
	return bool(TILE_RULES[tile_id]["water"])

func is_bridge_tile(tile_id: int) -> bool:
	return tile_id == T_BRIDGE

## Y5: 돌은 이제 못 지나가는 칸입니다(FEEDBACK_Y §5.1). 물과 달리 한 칸짜리 단독
## 장애물이라 판정도 한 줄이면 됩니다. 이름을 따로 둔 이유는 호출부가
## `== T_ROCKS`를 여기저기 베껴 쓰지 않게 하려는 것입니다.
func is_rock_tile(tile_id: int) -> bool:
	return tile_id == T_ROCKS

## 타일의 이름표("grass" "forest" "rocks" "water" "shore_north" …).
## 지형에 따라 몹 습성 가중을 바꾸는 스폰 쪽이 이 이름만 보고 판단합니다.
## 범위 밖 id는 "grass"로 답합니다 — 지형 조회가 게임을 멈추게 하면 안 되고,
## 잔디는 가중을 바꾸지 않는 가장 무난한 기본값이기 때문입니다.
func tile_name(tile_id: int) -> String:
	if tile_id < 0 or tile_id >= TILE_COUNT:
		return "grass"
	return String(TILE_RULES[tile_id]["name"])

func tile_atlas_cell(tile_id: int) -> int:
	if tile_id < 0 or tile_id >= TILE_COUNT:
		return 0
	return int(TILE_RULES[tile_id]["atlas"])

func tile_turn(tile_id: int) -> int:
	if tile_id < 0 or tile_id >= TILE_COUNT:
		return 0
	return int(TILE_RULES[tile_id]["turn"])

# 젖은 칸 패턴에서 정확한 물 타일을 고릅니다. 물길·호수를 코드로 직접 얹는
# 랜드마크 레이어(world_grid)도 이 함수를 써서 같은 규칙으로 그립니다.
func water_tile_for_pattern(dry_up: bool, dry_right: bool, dry_down: bool, dry_left: bool) -> int:
	var mask := 0
	if dry_up:
		mask |= 1
	if dry_right:
		mask |= 2
	if dry_down:
		mask |= 4
	if dry_left:
		mask |= 8
	var tile: int = WATER_TILE_BY_DRY[mask]
	return T_WATER if tile < 0 else tile

func is_wet_tile(tile_coord: Vector2i) -> bool:
	return _is_wet(tile_coord)

func trim_cache(center_chunk: Vector2i) -> void:
	for key_variant in chunk_cache.keys():
		var key: Vector2i = key_variant
		var distance := maxi(absi(key.x - center_chunk.x), absi(key.y - center_chunk.y))
		if distance > CACHE_RADIUS:
			chunk_cache.erase(key)
			chunk_last_used.erase(key)
	while chunk_cache.size() > MAX_CACHED_CHUNKS:
		var oldest_key: Vector2i = chunk_cache.keys()[0]
		var oldest_tick := int(chunk_last_used.get(oldest_key, 0))
		for key_variant in chunk_cache.keys():
			var key: Vector2i = key_variant
			var used := int(chunk_last_used.get(key, 0))
			if used < oldest_tick:
				oldest_tick = used
				oldest_key = key
		chunk_cache.erase(oldest_key)
		chunk_last_used.erase(oldest_key)
	if lake_cache.size() > LAKE_CACHE_LIMIT:
		lake_cache.clear()

func validate_chunk(chunk: Vector2i) -> bool:
	var tiles := _get_chunk(chunk)
	for y in CHUNK_TILES:
		for x in CHUNK_TILES:
			var tile_id := int(tiles[y * CHUNK_TILES + x])
			if x + 1 < CHUNK_TILES:
				var right_id := int(tiles[y * CHUNK_TILES + x + 1])
				if _socket(tile_id, RIGHT) != _socket(right_id, LEFT):
					return false
			if y + 1 < CHUNK_TILES:
				var down_id := int(tiles[(y + 1) * CHUNK_TILES + x])
				if _socket(tile_id, DOWN) != _socket(down_id, UP):
					return false
			if x == 0 and _socket(tile_id, LEFT) != _seam_socket(chunk, LEFT, y):
				return false
			if x == CHUNK_TILES - 1 and _socket(tile_id, RIGHT) != _seam_socket(chunk, RIGHT, y):
				return false
			if y == 0 and _socket(tile_id, UP) != _seam_socket(chunk, UP, x):
				return false
			if y == CHUNK_TILES - 1 and _socket(tile_id, DOWN) != _seam_socket(chunk, DOWN, x):
				return false
	return true

func validate_neighbor_seam(first: Vector2i, second: Vector2i) -> bool:
	var delta := second - first
	if absi(delta.x) + absi(delta.y) != 1:
		return false
	var a := _get_chunk(first)
	var b := _get_chunk(second)
	if delta == Vector2i.RIGHT:
		for offset in CHUNK_TILES:
			var a_id := int(a[offset * CHUNK_TILES + CHUNK_TILES - 1])
			var b_id := int(b[offset * CHUNK_TILES])
			if _socket(a_id, RIGHT) != _socket(b_id, LEFT):
				return false
	elif delta == Vector2i.LEFT:
		return validate_neighbor_seam(second, first)
	elif delta == Vector2i.DOWN:
		for offset in CHUNK_TILES:
			var a_id := int(a[(CHUNK_TILES - 1) * CHUNK_TILES + offset])
			var b_id := int(b[offset])
			if _socket(a_id, DOWN) != _socket(b_id, UP):
				return false
	else:
		return validate_neighbor_seam(second, first)
	return true

func stats() -> Dictionary:
	return {
		"algorithm":"streaming_simple_tiled_wfc",
		"cached_chunks":chunk_cache.size(),
		"generated_chunks":generated_chunks,
		"contradiction_retries":contradiction_retries,
		"fallback_chunks":fallback_chunks
	}

func _get_chunk(chunk: Vector2i) -> PackedInt32Array:
	access_tick += 1
	chunk_last_used[chunk] = access_tick
	if chunk_cache.has(chunk):
		return chunk_cache[chunk]
	var tiles := _generate_chunk(chunk)
	chunk_cache[chunk] = tiles
	generated_chunks += 1
	if chunk_cache.size() > MAX_CACHED_CHUNKS:
		trim_cache(chunk)
	return tiles

func _generate_chunk(chunk: Vector2i) -> PackedInt32Array:
	var water := _chunk_water_layer(chunk)
	for attempt in MAX_RETRIES:
		var domains := PackedInt32Array()
		domains.resize(CELL_COUNT)
		var preset: Array[int] = []
		for index in CELL_COUNT:
			var forced := int(water[index])
			if forced >= 0:
				domains[index] = 1 << forced
				preset.append(index)
			else:
				domains[index] = pool_mask
		if not _apply_boundary_constraints(domains, chunk, preset):
			contradiction_retries += 1
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(_stable_hash(chunk.x, chunk.y, world_seed + attempt * 7919))
		var solved := true
		while true:
			var target := _minimum_entropy_cell(domains, rng)
			if target == -1:
				break
			var picked := _weighted_pick(int(domains[target]), rng)
			domains[target] = 1 << picked
			if not _propagate(domains, [target]):
				solved = false
				break
		if solved:
			var output := PackedInt32Array()
			output.resize(CELL_COUNT)
			for index in CELL_COUNT:
				output[index] = _first_tile(int(domains[index]))
			return output
		contradiction_retries += 1
	fallback_chunks += 1
	return _safe_fallback(chunk, water)

# 청크의 물 레이어를 먼저 확정합니다. -1은 육지(WFC가 채움)입니다.
func _chunk_water_layer(chunk: Vector2i) -> PackedInt32Array:
	var layer := PackedInt32Array()
	layer.resize(CELL_COUNT)
	var origin := chunk * CHUNK_TILES
	# 청크 + 1칸 여유의 젖음 격자를 한 번만 계산합니다.
	var span := CHUNK_TILES + 2
	var wet := []
	wet.resize(span * span)
	for y in span:
		for x in span:
			wet[y * span + x] = _is_wet(origin + Vector2i(x - 1, y - 1))
	for y in CHUNK_TILES:
		for x in CHUNK_TILES:
			var here := (y + 1) * span + x + 1
			if not bool(wet[here]):
				layer[y * CHUNK_TILES + x] = -1
				continue
			layer[y * CHUNK_TILES + x] = water_tile_for_pattern(
				not bool(wet[here - span]),
				not bool(wet[here + 1]),
				not bool(wet[here + span]),
				not bool(wet[here - 1])
			)
	return layer

func _is_wet(tile_coord: Vector2i) -> bool:
	var cell := Vector2i(
		floori(float(tile_coord.x) / float(LAKE_CELL)),
		floori(float(tile_coord.y) / float(LAKE_CELL))
	)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _lake_covers(cell + Vector2i(dx, dy), tile_coord):
				return true
	return false

func _lake_covers(cell: Vector2i, tile_coord: Vector2i) -> bool:
	var lake: Dictionary = _lake_at(cell)
	if lake.is_empty():
		return false
	var bounds: Rect2i = lake["bounds"]
	if not bounds.has_point(tile_coord):
		return false
	var center: Vector2i = lake["center"]
	var radius: int = int(lake["radius"])
	var block_x := floori(float(tile_coord.x - center.x) / 2.0)
	var block_y := floori(float(tile_coord.y - center.y) / 2.0)
	if absi(block_x) > radius or absi(block_y) > radius:
		return false
	var mask: PackedByteArray = lake["mask"]
	return mask[(block_y + radius) * (radius * 2 + 1) + block_x + radius] != 0

func _lake_at(cell: Vector2i) -> Dictionary:
	if lake_cache.has(cell):
		var cached: Dictionary = lake_cache[cell]
		return cached
	var lake: Dictionary = {}
	var value := absi(_stable_hash(cell.x, cell.y, world_seed + LAKE_SALT))
	if value % 100 < LAKE_CHANCE:
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var radius: int = LAKE_RADIUS_TABLE[rng.randi_range(0, LAKE_RADIUS_TABLE.size() - 1)]
		var center := cell * LAKE_CELL + Vector2i(
			rng.randi_range(4, LAKE_CELL - 5),
			rng.randi_range(4, LAKE_CELL - 5)
		)
		# 2칸 격자 정렬. 모든 조각의 원점이 짝수라 조각들이 빈틈 없이 맞물립니다.
		center -= Vector2i(posmod(center.x, 2), posmod(center.y, 2))
		var side := radius * 2 + 1
		var mask := PackedByteArray()
		mask.resize(side * side)
		var filled := 0
		for block_y in range(-radius, radius + 1):
			for block_x in range(-radius, radius + 1):
				var wobble := absi(_stable_hash(center.x + block_x, center.y + block_y, world_seed + LAKE_SALT * 3)) % 3
				if block_x * block_x + block_y * block_y > radius * radius + wobble:
					continue
				if not _part_allowed(Rect2i(center + Vector2i(block_x * 2, block_y * 2), Vector2i(2, 2))):
					continue
				mask[(block_y + radius) * side + block_x + radius] = 1
				filled += 1
		if filled > 0:
			lake = {
				"center":center,
				"radius":radius,
				"mask":mask,
				"bounds":Rect2i(center - Vector2i(radius * 2, radius * 2), Vector2i(radius * 4 + 2, radius * 4 + 2))
			}
	lake_cache[cell] = lake
	return lake

func _part_allowed(part: Rect2i) -> bool:
	if dry_zones.is_empty():
		return true
	var area := Rect2(Vector2(part.position), Vector2(part.size))
	for zone: Rect2 in dry_zones:
		if area.intersects(zone):
			return false
	return true

func _apply_boundary_constraints(domains: PackedInt32Array, chunk: Vector2i, preset: Array[int]) -> bool:
	var changed: Array[int] = preset.duplicate()
	for offset in CHUNK_TILES:
		var entries := [
			[offset, UP, _seam_socket(chunk, UP, offset)],
			[(CHUNK_TILES - 1) * CHUNK_TILES + offset, DOWN, _seam_socket(chunk, DOWN, offset)],
			[offset * CHUNK_TILES, LEFT, _seam_socket(chunk, LEFT, offset)],
			[offset * CHUNK_TILES + CHUNK_TILES - 1, RIGHT, _seam_socket(chunk, RIGHT, offset)]
		]
		for entry in entries:
			var index := int(entry[0])
			var constrained := int(domains[index]) & int(socket_masks[int(entry[1])][int(entry[2])])
			if constrained == 0:
				return false
			if constrained != int(domains[index]):
				domains[index] = constrained
				changed.append(index)
	return _propagate(domains, changed)

func _propagate(domains: PackedInt32Array, initial: Array[int]) -> bool:
	var queue: Array[int] = initial.duplicate()
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var x: int = index % CHUNK_TILES
		var y: int = index / CHUNK_TILES
		var current_mask := int(domains[index])
		for direction in 4:
			var neighbor_position: Vector2i = Vector2i(x, y) + Vector2i(DIRECTIONS[direction])
			if neighbor_position.x < 0 or neighbor_position.y < 0 or neighbor_position.x >= CHUNK_TILES or neighbor_position.y >= CHUNK_TILES:
				continue
			var neighbor_index: int = neighbor_position.y * CHUNK_TILES + neighbor_position.x
			var allowed := 0
			for tile_id in TILE_COUNT:
				if current_mask & (1 << tile_id):
					allowed |= int(adjacency[tile_id][direction])
			var old_mask := int(domains[neighbor_index])
			var new_mask := old_mask & allowed
			if new_mask == 0:
				return false
			if new_mask != old_mask:
				domains[neighbor_index] = new_mask
				queue.append(neighbor_index)
	return true

func _minimum_entropy_cell(domains: PackedInt32Array, rng: RandomNumberGenerator) -> int:
	var best_index := -1
	var best_entropy := TILE_COUNT + 1
	var ties := 0
	for index in CELL_COUNT:
		var entropy := _bit_count(int(domains[index]))
		if entropy <= 1:
			continue
		if entropy < best_entropy:
			best_entropy = entropy
			best_index = index
			ties = 1
		elif entropy == best_entropy:
			ties += 1
			if rng.randi_range(1, ties) == 1:
				best_index = index
	return best_index

func _weighted_pick(mask: int, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for tile_id in TILE_COUNT:
		if mask & (1 << tile_id):
			total += float(TILE_RULES[tile_id]["weight"])
	if total <= 0.0:
		return _first_tile(mask)
	var roll := rng.randf() * total
	for tile_id in TILE_COUNT:
		if not mask & (1 << tile_id):
			continue
		roll -= float(TILE_RULES[tile_id]["weight"])
		if roll <= 0.0:
			return tile_id
	return _first_tile(mask)

# 도달 불가능한 안전망입니다. 물 레이어는 그대로 유지하므로 이 경로로
# 떨어져도 이웃 청크와의 이음새는 깨지지 않습니다.
func _safe_fallback(chunk: Vector2i, water: PackedInt32Array) -> PackedInt32Array:
	var output := PackedInt32Array()
	output.resize(CELL_COUNT)
	for y in CHUNK_TILES:
		for x in CHUNK_TILES:
			var index := y * CHUNK_TILES + x
			var forced := int(water[index])
			if forced >= 0:
				output[index] = forced
				continue
			var value := absi(_stable_hash(chunk.x * CHUNK_TILES + x, chunk.y * CHUNK_TILES + y, world_seed))
			output[index] = 1 if value % 7 == 0 else 2 if value % 19 == 0 else 0
	return output

# 청크 경계 소켓입니다. 경계 양쪽 칸이 모두 호수일 때만 물이며, 판정이 전역
# 좌표만으로 결정되므로 두 청크가 어떤 순서로 생성돼도 같은 값을 얻습니다.
func _seam_socket(chunk: Vector2i, direction: int, offset: int) -> int:
	var inside := _boundary_tile(chunk, direction, offset)
	var outside: Vector2i = inside + Vector2i(DIRECTIONS[direction])
	if _is_wet(inside) and _is_wet(outside):
		return WATER
	return LAND

func _boundary_tile(chunk: Vector2i, direction: int, offset: int) -> Vector2i:
	var origin := chunk * CHUNK_TILES
	match direction:
		UP:
			return origin + Vector2i(offset, 0)
		DOWN:
			return origin + Vector2i(offset, CHUNK_TILES - 1)
		LEFT:
			return origin + Vector2i(0, offset)
		_:
			return origin + Vector2i(CHUNK_TILES - 1, offset)

func _build_rules() -> void:
	adjacency.clear()
	socket_masks = [PackedInt32Array([0, 0]), PackedInt32Array([0, 0]), PackedInt32Array([0, 0]), PackedInt32Array([0, 0])]
	for direction in 4:
		for socket in SOCKET_COUNT:
			var mask := 0
			for tile_id in TILE_COUNT:
				if _socket(tile_id, direction) == socket:
					mask |= 1 << tile_id
			socket_masks[direction][socket] = mask
	pool_mask = 0
	for tile_id in TILE_COUNT:
		if float(TILE_RULES[tile_id]["weight"]) > 0.0:
			pool_mask |= 1 << tile_id
	for tile_id in TILE_COUNT:
		var by_direction := PackedInt32Array([0, 0, 0, 0])
		for direction in 4:
			var mask := 0
			for neighbor_id in TILE_COUNT:
				if _socket(tile_id, direction) == _socket(neighbor_id, OPPOSITE[direction]):
					mask |= 1 << neighbor_id
			by_direction[direction] = mask
		adjacency.append(by_direction)

func _socket(tile_id: int, direction: int) -> int:
	return int((TILE_RULES[tile_id]["sockets"] as Array)[direction])

func _first_tile(mask: int) -> int:
	for tile_id in TILE_COUNT:
		if mask & (1 << tile_id):
			return tile_id
	return T_GRASS

func _bit_count(mask: int) -> int:
	var value := mask
	var count := 0
	while value != 0:
		value &= value - 1
		count += 1
	return count

func _stable_hash(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 1442695041
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)
