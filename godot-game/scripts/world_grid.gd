class_name WorldGrid
extends Node2D

const WFC_SCRIPT := preload("res://scripts/wfc_chunk_generator.gd")
# =============================================================================
# V5(2026-08-09): 지형 아틀라스 3벌 · 스테이지 랜드마크 3종 (설계 §2.3 · §7.2)
# =============================================================================
# 셀 규격은 v2와 완전히 같다 — 160×128(5열×4행 · 셀 32×32)이라 셀 번호 계약
# (`wfc_chunk_generator.TILE_RULES`)과 `ATLAS_CELL_INSET`은 한 글자도 안 바뀐다.
# `terrain-atlas-verdant.png`는 `terrain-atlas-na.png`와 **바이트 동일**이라
# 1·2스테이지 렌더는 v2와 픽셀 하나 다르지 않다(handoff-v3-assets §2).
const TERRAIN_ATLASES := {
	"verdant": preload("res://art/v2/terrain-atlas-verdant.png"),
	"waste": preload("res://art/v2/terrain-atlas-waste.png"),
	"abyss": preload("res://art/v2/terrain-atlas-abyss.png")
}
const TERRAIN_ATLAS_FALLBACK := "verdant"
# 랜드마크는 도형 그리기에서 NA 타일 합성 스프라이트로 바뀌었습니다.
const CASTLE_SPRITE := preload("res://art/v2/landmark-castle.png")
const DEMON_CASTLE_SPRITE := preload("res://art/v2/landmark-demon-castle.png")
const RUIN_SPRITE := preload("res://art/v2/landmark-ruin.png")
const TREE_SPRITE := preload("res://art/v2/landmark-tree.png")
const CHEST_SPRITE := preload("res://art/v2/landmark-chest.png")
# V5 신규 랜드마크 2종(V3 웨이브 산출 · 192×128 · 밑변 기준).
const BOSS_GATE_SPRITE := preload("res://art/v2/landmark-boss-gate.png")
const CAMP_SPRITE := preload("res://art/v2/landmark-camp.png")

const TILE := 40
const FEATURE_CHUNK := 800
const VIEW_HALF := Vector2(760.0, 460.0)
# v1 아틀라스는 셀마다 어두운 테두리가 구워져 있어 2픽셀을 잘라내야 했습니다
# (안 자르면 화면 전체에 40px 격자 그물이 보였습니다 — 3차 피드백 "맵이 깨져
# 보인다"의 절반). NA 타일셋은 원래 서로 이어 붙이라고 만든 것이라 테두리가
# 없습니다. 그래서 인셋을 0으로 되돌립니다. 1픽셀이라도 깎으면 물가 그림의
# 흰 포말 선이 잘려 호수 가장자리가 두 번 끊겨 보입니다.
const ATLAS_CELL_INSET := 0
const ATLAS_COLUMNS := 5
const ATLAS_ROWS := 4
# 시작 성 동쪽 고정 물길. 다리는 한 줄(가로 3칸)만 놓습니다. 아틀라스의 다리
# 그림은 데크가 좌우로 지나가고 위아래가 물이므로, 여러 줄을 겹치면 물줄기가
# 낀 판자 여러 장으로 보입니다(개편 전 모습).
# V5: 스폰(0,0) 기준 상대 좌표라 스테이지마다 같은 자리에 놓인다 — "다리를 건너는 법"을
# 매 스테이지 첫 낮에 다시 가르칠 필요는 없지만, 지형 문법의 기준점으로는 남겨 둔다.
const RIVER_LEFT := 19
const RIVER_RIGHT := 21
const RIVER_TOP := -9
const RIVER_BOTTOM := 9
const RIVER_BRIDGE_ROW := 0
const SAFE_ZONE_DEMON := 210.0
const SAFE_ZONE_CASTLE := 190.0
# Y5: 플레이어 스폰(항상 원점)을 물에서 지키는 반경. 물이 늘어난 뒤로는 원점에
# 호수가 걸릴 수 있는데, 스폰 자리는 덮개가 없어 그대로 물이 된다. 성보다 작게
# 잡은 이유는 하나다 — 이 자리는 "걸을 수 있으면 충분"하지 랜드마크가 아니라서
# 넓게 말리면 시작 지점만 부자연스럽게 뻥 뚫린 잔디밭이 된다.
# (돌은 마른 구역으로 못 막는다. 스폰 위 돌은 game.gd가 따로 보정한다.)
const SAFE_ZONE_SPAWN := 120.0
# `measure_terrain_mix()`가 한 번에 훑을 수 있는 타일 변 길이 상한. 실수로 큰 값이
# 들어와 청크를 수천 개 만드는 사고를 막는 방어선이다.
const TERRAIN_MIX_SPAN_MAX := 512
# W12: 캠프 자체는 삭제됐지만(아래 W12 주석) 이 반경은 rift_probe.gd가
# "균열이 옛 캠프 반경만큼은 떨어져 있다"를 검증할 때 읽으므로 상수만 남긴다.
# V5: **베이스 캠프가 부활했다.** 같은 값을 v3 캠프의 안전 반경으로 재사용한다.
const SAFE_ZONE_CAMP := 175.0
# ⚠️ V5에서 **폐기된 고정 좌표 2개.** 스테이지 랜드마크가 시드로 자리를 정하므로
#    게임 코드는 더 이상 이 값을 읽지 않는다. 선언만 남긴 이유는 하나다 —
#    `scripts/test/rift_probe.gd:134-135`가 아직 참조해서, 지우면 `--editor --quit`이
#    파스 에러를 뱉고 run_all.sh의 컴파일 검사가 통째로 실패한다. rift_probe를
#    v3 랜드마크로 재작성하는 웨이브가 이 두 줄도 함께 지울 것.
const STARTER_CASTLE_POSITION := Vector2(250.0, -250.0)
const DEMON_CASTLE_POSITION := Vector2(6840.0, -5260.0)
# === W12: 시련 캠프 시스템 삭제 =============================================
# v2 §5.5가 동서남북 고정 시련 캠프 4곳을 동적 균열로 대체했다. W9에서
# `TRIAL_CAMPS_ENABLED`를 false로 뒤집어 죽은 코드가 된 자리를 이번 웨이브에서
# 실제로 걷어냈다(handoff-w8 §6이 예고한 정리). 원본은
# docs/v1-archive/world_grid_v1.gd.txt에 보존돼 있다.
#
# 호출부 호환 껍데기만 남긴다:
#   `get_trial_camps()`      빈 사전 — game.gd의 camp_states 구축 루프와
#                            rift_probe·test_runner의 캠프 순회가 0회로 통과한다.
#   `set_cleared_trial_camps()` 무해한 세터 — game.gd가 아직 두 곳에서 부른다.

# =============================================================================
# V5: 스테이지 랜드마크 3종 (설계 §2.3 · 부록 A-1 ①②)
# =============================================================================
# 한 스테이지 = 무한 WFC 필드 + **성 1 + 베이스캠프 1 + 보스방 1**. 셋 다
# `stage_seed`만으로 결정되므로 같은 시드면 같은 자리다(저장·리플레이·테스트 계약).
#
#   성       스폰(0,0) 반경 300~420px            나침반 2번 줄
#   보스문   스폰 기준 stage_angle · 3,600~4,200px  나침반 1번 줄(상시)
#   캠프     보스문에서 **플레이어 쪽으로** 520px    나침반 1번 줄에 병기
#
# 캠프가 보스문보다 반드시 먼저 나오는 것은 "정비하고 들어간다"(사용자 요구)의
# 기계적 실체다. 캠프는 보스문과 플레이어 스폰을 잇는 선 위에 있으므로
# 보스문으로 걸어가면 물리적으로 캠프를 먼저 지난다.
const LANDMARK_SALT := 4517
const LANDMARK_CANDIDATES := 48
## 보스방 = 균열 아레나 렌더러를 반경 ×2.2로 복제한 필드 위 원형 아레나(설계 §3.5).
## 신규 씬 0개 · 신규 state 0개. `boss_gate_at()`이 아레나 안쪽 판정을 준다.

# --- 동적 균열(Rift) --- v2 §5.5 · V5 재키잉(§2.4) ---------------------------
# v2: 런당 3개(2·4·6일차 낮 시작). v3: **스테이지당 2개**(dwell 1·3), 런 최대 10.
# 배치 규칙(900~1,400px 링·결정성)은 v2 그대로다 — 예산과 트리거만 바뀌었다.
# `RIFT_MAX_PER_RUN`이라는 이름은 유지한다(`--save-test`가 읽는다). 값의 의미만
# "런당"에서 "**스테이지당**"으로 바뀌었고 스테이지 전환마다 다시 채워진다.
const RIFT_MAX_PER_RUN := GameTuning.RIFT_STAGE_BUDGET
const RIFT_MIN_DISTANCE := GameTuning.RIFT_RING_MIN
const RIFT_MAX_DISTANCE := GameTuning.RIFT_RING_MAX
# 균열 바닥을 안전 타일로 덮는 반지름. 성과 같은 오버레이 규칙이다.
const SAFE_ZONE_RIFT := 150.0
# 다른 목적지와의 최소 여유. 균열 아레나와 성 입구가 붙어 보이지 않게 한다.
const RIFT_CLEARANCE := 110.0
const RIFT_RING_RADIUS := 122.0
const RIFT_SALT := 7717
const RIFT_CANDIDATES := 96

var player: Node2D
var night_amount := 0.0
var opened_features: Dictionary = {}
var cleared_trial_camps: Dictionary = {}
var rifts: Array[Dictionary] = []
var rift_spawn_count := 0
var rift_run_seed := 0
var last_rift_result := "none"
var last_draw_center := Vector2(1000000.0, 1000000.0)
var last_draw_night := -1.0
var terrain_generator = WFC_SCRIPT.new()
var tile_sources: Array[Rect2] = []
var tile_turns: PackedInt32Array = PackedInt32Array()

# --- V5 스테이지 상태 ---------------------------------------------------------
var stage := 1
var stage_seed := 0
## `{"castle": {...}, "camp": {...}, "boss_gate": {...}}` — 각 값은 feature 사전과
## 같은 모양이다(`id` / `type` / `position` / `variant`). `_features_near()`가 그대로 흘린다.
var stage_landmarks: Dictionary = {}
var boss_gate_radius := SAFE_ZONE_RIFT * GameTuning.BOSS_ARENA_RADIUS_MUL
var boss_gate_cleared := false
## §7.3 런타임 그레이드. `begin_stage()`가 GameTuning에서 채우고 `_draw_tile()`과
## `_landmark_tint()`가 읽는다. CanvasModulate·안개·비네트는 game.gd 몫이다
## (한 색을 두 계층에서 곱하면 5스테이지가 새까매진다 — 여기서는 채도와 늪 녹조만).
var stage_atlas_key := TERRAIN_ATLAS_FALLBACK
var stage_saturation := 1.0
var stage_green_overlay := 0.0
var _landmark_chunks: Dictionary = {}
var _terrain_atlas: Texture2D = TERRAIN_ATLASES[TERRAIN_ATLAS_FALLBACK]

func _init() -> void:
	_build_tile_atlas_table()

func setup(player_node: Node2D) -> void:
	player = player_node

func _ready() -> void:
	z_index = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _build_tile_atlas_table() -> void:
	tile_sources.clear()
	tile_turns.resize(0)
	var inset := float(ATLAS_CELL_INSET)
	for tile_id in int(terrain_generator.TILE_COUNT):
		var cell: int = int(terrain_generator.tile_atlas_cell(tile_id))
		var column: int = cell % ATLAS_COLUMNS
		var row: int = cell / ATLAS_COLUMNS
		# 아틀라스 크기가 격자 수로 나누어지지 않아도 픽셀이 번지지 않도록
		# 각 셀의 시작·끝을 정수 좌표로 계산한 뒤 안쪽으로 잘라냅니다.
		var left := floori(float(_terrain_atlas.get_width() * column) / float(ATLAS_COLUMNS))
		var right := floori(float(_terrain_atlas.get_width() * (column + 1)) / float(ATLAS_COLUMNS))
		var top := floori(float(_terrain_atlas.get_height() * row) / float(ATLAS_ROWS))
		var bottom := floori(float(_terrain_atlas.get_height() * (row + 1)) / float(ATLAS_ROWS))
		var usable := minf(inset, minf(float(right - left), float(bottom - top)) * 0.25)
		tile_sources.append(Rect2(
			float(left) + usable, float(top) + usable,
			float(right - left) - usable * 2.0, float(bottom - top) - usable * 2.0
		))
		tile_turns.append(int(terrain_generator.tile_turn(tile_id)))

# =============================================================================
# V5: 스테이지 개시 (설계 §2.2 "월드를 통째로 재생성한다")
# =============================================================================
# game.gd `_begin_stage(n)`이 새 WorldGrid를 만든 직후 딱 한 번 부른다.
# 순서가 중요하다: ①시드 주입 → ②랜드마크 결정 → ③마른 구역 등록 → ④균열 초기화.
# 마른 구역 등록이 청크·호수 캐시를 비우므로 랜드마크 좌표 탐색이 만든 캐시는
# 그대로 버려진다(지형 팝이 생기지 않는다).
func begin_stage(stage_number: int, seed_value: int) -> void:
	stage = clampi(stage_number, 1, GameTuning.STAGE_COUNT)
	stage_seed = seed_value
	var index := stage - 1
	stage_atlas_key = String(GameTuning.STAGE_TERRAIN_ATLAS[index])
	if not TERRAIN_ATLASES.has(stage_atlas_key):
		stage_atlas_key = TERRAIN_ATLAS_FALLBACK
	_terrain_atlas = TERRAIN_ATLASES[stage_atlas_key]
	stage_saturation = float(GameTuning.STAGE_SATURATION[index])
	stage_green_overlay = float(GameTuning.STAGE_GREEN_OVERLAY_ALPHA[index])
	_build_tile_atlas_table()
	terrain_generator.set_world_seed(_hash(stage_seed, stage, LANDMARK_SALT))
	_place_stage_landmarks()
	# 목적지 바닥은 안전 타일로 덮이므로 그 자리에는 호수를 만들지 않습니다.
	# 이렇게 하지 않으면 덮개가 호수를 잘라 물 한가운데 사각형 잔디가 생깁니다.
	terrain_generator.add_dry_zone(_landmark_position("castle") / float(TILE), SAFE_ZONE_CASTLE / float(TILE))
	terrain_generator.add_dry_zone(_landmark_position("camp") / float(TILE), SAFE_ZONE_CAMP / float(TILE))
	terrain_generator.add_dry_zone(_landmark_position("boss_gate") / float(TILE), boss_gate_radius / float(TILE))
	# Y5: 플레이어 스폰(원점)도 마른 땅으로 못박는다. 랜드마크와 달리 스폰 자리에는
	# 바닥 덮개가 없어서, 물이 늘어난 뒤로는 여기가 호수 한가운데가 될 수 있다.
	terrain_generator.add_dry_zone(Vector2.ZERO, SAFE_ZONE_SPAWN / float(TILE))
	# 손으로 얹은 시작 물길 자리에는 WFC 호수를 만들지 않습니다. 겹치면 덮개
	# 바깥에서 호수 물가와 물길 물가가 서로 다른 모양으로 맞닿습니다.
	terrain_generator.add_dry_rect(Rect2(
		float(RIVER_LEFT) - 2.0, float(RIVER_TOP) - 2.0,
		float(RIVER_RIGHT - RIVER_LEFT) + 5.0, float(RIVER_BOTTOM - RIVER_TOP) + 5.0
	))
	boss_gate_cleared = false
	opened_features = {}
	begin_run_rifts(stage_seed)
	last_draw_center = Vector2(1000000.0, 1000000.0)
	queue_redraw()

## 스테이지 랜드마크 3종을 시드만으로 결정한다. 순서: 보스문 → 캠프 → 성.
## 보스문이 먼저인 이유는 캠프가 보스문에서 파생되기 때문이다.
func _place_stage_landmarks() -> void:
	stage_landmarks.clear()
	_landmark_chunks.clear()
	var gate_roll := absi(_hash(stage_seed, 11, LANDMARK_SALT))
	var gate_angle := TAU * float(gate_roll % 4096) / 4096.0
	var gate_distance := GameTuning.STAGE_BOSS_GATE_DISTANCE_MIN + \
		(GameTuning.STAGE_BOSS_GATE_DISTANCE_MAX - GameTuning.STAGE_BOSS_GATE_DISTANCE_MIN) * \
		float((gate_roll >> 12) % 1024) / 1023.0
	var gate_position := Vector2.from_angle(gate_angle) * gate_distance
	gate_position = _nearest_dry_spot(gate_position, boss_gate_radius, 23)
	# 캠프는 보스문에서 **플레이어 쪽으로** 520px. 방향이 뒤집히면 "먼저 만난다"가 깨진다.
	var to_spawn := (-gate_position).normalized()
	var camp_position := gate_position + to_spawn * GameTuning.STAGE_CAMP_OFFSET_FROM_GATE
	# ⚠️ Y5: 마른 자리 탐색에 **거리 상한**을 건다. 탐색은 최대 800px까지 아무 방향으로나
	# 흔들어 보는데, Y5가 물을 5배로 늘리면서 그 흔들림이 캠프를 **보스문보다 바깥으로**
	# 밀어내는 일이 실제로 생겼다(`--world-test placement=false` · camp 4190 > gate 4117).
	# 그러면 "정비하고 들어간다"의 기계적 실체 — 보스문으로 걸어가면 캠프를 먼저 지난다 —
	# 가 깨진다. 상한을 걸면 못 찾았을 때 원래 자리(보스문과 스폰을 잇는 선 위)로
	# 떨어지고, 그 자리는 **정의상 보스문보다 가깝다.**
	camp_position = _nearest_dry_spot(camp_position, SAFE_ZONE_CAMP, 29, gate_position.length() - SAFE_ZONE_CAMP)
	var castle_roll := absi(_hash(stage_seed, 37, LANDMARK_SALT))
	var castle_angle := TAU * float(castle_roll % 4096) / 4096.0
	var castle_distance := GameTuning.STAGE_CASTLE_DISTANCE_MIN + \
		(GameTuning.STAGE_CASTLE_DISTANCE_MAX - GameTuning.STAGE_CASTLE_DISTANCE_MIN) * \
		float((castle_roll >> 12) % 1024) / 1023.0
	var castle_position := Vector2.from_angle(castle_angle) * castle_distance
	castle_position = _nearest_dry_spot(castle_position, SAFE_ZONE_CASTLE, 41)
	stage_landmarks = {
		"castle": {"id":"stage%d_castle" % stage, "type":"castle", "position":castle_position, "variant":0},
		"camp": {"id":"stage%d_camp" % stage, "type":"camp", "position":camp_position, "variant":1},
		"boss_gate": {"id":"stage%d_boss_gate" % stage, "type":"boss_gate", "position":gate_position, "variant":0}
	}
	_rebuild_landmark_chunks()

## 저장된 랜드마크 3종을 되박는다 — **이어하기 전용 공개 창구**(V10 신설).
##
## V9의 `game._restore_stage_landmarks()`는 이 파일을 열 수 없어 `_landmark_chunks`
## (사적 캐시)를 game.gd에서 직접 세웠다(handoff-v9 §2.3 · §9 #5). 그 캐시는 좌표에서
## 기계적으로 파생되는 값이라 위험은 없었지만, 파생 규칙이 두 파일에 흩어져 있었다.
## 이제 파생은 여기 한 곳(`_rebuild_landmark_chunks`)에만 있다.
##
## 보통은 **같은 값을 같은 값으로 덮는다**(멱등) — 이어하기가 시드를 먼저 복원하므로
## `_place_stage_landmarks()`가 이미 같은 자리를 만들었기 때문이다. 존재 이유는
## 생성식이 바뀐 뒤에 열린 세이브다. 그때는 저장된 좌표가 이긴다.
func set_stage_landmarks(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	var restored: Dictionary = {}
	for key_value in saved.keys():
		var landmark: Dictionary = (saved[key_value] as Dictionary).duplicate(true)
		if not landmark.has("position"):
			continue
		restored[String(key_value)] = landmark
	if restored.is_empty():
		return
	stage_landmarks = restored
	_rebuild_landmark_chunks()
	queue_redraw()

## 랜드마크가 차지한 청크 표. "여기에는 랜덤 feature를 얹지 않는다"에만 쓰인다.
func _rebuild_landmark_chunks() -> void:
	_landmark_chunks.clear()
	for key: String in stage_landmarks:
		var landmark: Dictionary = stage_landmarks[key]
		_landmark_chunks[_chunk_of(landmark["position"])] = key

## 후보를 결정적인 순서로 흔들어 "덮개 반경 전체가 마른 땅"인 자리를 찾는다.
## 못 찾으면 원래 자리를 그대로 쓴다 — 어차피 `_resolved_tile_id()`가 바닥을 덮으므로
## 최악의 경우에도 랜드마크가 물에 잠기지는 않는다(호수 그림만 한 칸 잘린다).
## `max_from_spawn`이 0보다 크면 **스폰(원점)에서 그 거리 안**인 후보만 받는다.
## 캠프가 이 상한을 쓴다(위 `_place_stage_landmarks` 주석 참고). 0이면 상한 없음이라
## 성·보스문의 호출은 Y5 이전과 한 글자도 다르지 않게 동작한다.
func _nearest_dry_spot(origin: Vector2, radius: float, salt: int, max_from_spawn: float = 0.0) -> Vector2:
	if _area_dry(origin, radius) and (max_from_spawn <= 0.0 or origin.length() < max_from_spawn):
		return origin
	for attempt in LANDMARK_CANDIDATES:
		var roll := absi(_hash(stage_seed + attempt * 7919, salt, LANDMARK_SALT + attempt * 13))
		var angle := TAU * float(roll % 4096) / 4096.0
		var reach := 60.0 + float(attempt) * 26.0
		var candidate := origin + Vector2.from_angle(angle) * reach
		if max_from_spawn > 0.0 and candidate.length() >= max_from_spawn:
			continue
		if _area_dry(candidate, radius):
			return candidate
	return origin

func _area_dry(center: Vector2, radius: float) -> bool:
	var reach := int(ceil(radius / float(TILE) + 2.0))
	var center_tile := _world_to_tile(center)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile_coord := center_tile + Vector2i(dx, dy)
			if terrain_generator.is_wet_tile(tile_coord):
				return false
			if _river_wet(tile_coord):
				return false
	return true

func _chunk_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / FEATURE_CHUNK), floori(point.y / FEATURE_CHUNK))

func _landmark_position(key: String) -> Vector2:
	var landmark: Dictionary = stage_landmarks.get(key, {})
	return landmark.get("position", Vector2.ZERO)

# --- V5 공개 조회 (game.gd 나침반 · 테스트) ----------------------------------

func get_stage() -> int:
	return stage

func get_stage_landmarks() -> Dictionary:
	return stage_landmarks.duplicate(true)

func get_landmark(key: String) -> Dictionary:
	var landmark: Dictionary = stage_landmarks.get(key, {})
	return landmark.duplicate(true) if not landmark.is_empty() else {}

func get_castle_position() -> Vector2:
	return _landmark_position("castle")

func get_camp_position() -> Vector2:
	return _landmark_position("camp")

func get_boss_gate_position() -> Vector2:
	return _landmark_position("boss_gate")

## ⚠️ v2 이름의 호환 창구. v3에는 마왕성 좌표가 없다 — **스테이지 보스문**을 돌려준다.
func get_demon_castle_position() -> Vector2:
	return get_boss_gate_position()

## 이 점이 보스방 아레나 안인가. 아레나 이탈 판정·정예 스폰이 쓴다(균열과 같은 계약).
func boss_gate_at(point: Vector2) -> bool:
	if stage_landmarks.is_empty():
		return false
	return point.distance_to(get_boss_gate_position()) <= boss_gate_radius

func camp_at(point: Vector2) -> bool:
	if stage_landmarks.is_empty():
		return false
	return point.distance_to(get_camp_position()) <= SAFE_ZONE_CAMP

func set_boss_gate_cleared(value: bool) -> void:
	boss_gate_cleared = value
	queue_redraw()

## 나침반 한 덩어리. game.gd `_update_compass_panel()`이 이것만 보면 3줄을 다 그린다.
func get_stage_compass(point: Vector2) -> Dictionary:
	if stage_landmarks.is_empty():
		return {}
	var gate: Vector2 = get_boss_gate_position()
	var camp: Vector2 = get_camp_position()
	var castle: Vector2 = get_castle_position()
	return {
		"boss_gate": {"position":gate, "direction":(gate - point).normalized(), "distance":point.distance_to(gate)},
		"camp": {"position":camp, "direction":(camp - point).normalized(), "distance":point.distance_to(camp)},
		"castle": {"position":castle, "direction":(castle - point).normalized(), "distance":point.distance_to(castle)}
	}

func _process(_delta: float) -> void:
	if is_instance_valid(player) and player.global_position.distance_squared_to(last_draw_center) >= 32.0 * 32.0:
		last_draw_center = player.global_position
		queue_redraw()

func set_night_amount(value: float) -> void:
	night_amount = clampf(value, 0.0, 1.0)
	var reached_endpoint := (is_zero_approx(night_amount) or is_equal_approx(night_amount, 1.0)) and not is_equal_approx(last_draw_night, night_amount)
	if absf(night_amount - last_draw_night) >= 0.025 or reached_endpoint:
		last_draw_night = night_amount
		queue_redraw()

func set_opened_features(features: Dictionary) -> void:
	opened_features = features

func set_cleared_trial_camps(cleared: Dictionary) -> void:
	cleared_trial_camps = cleared.duplicate()
	queue_redraw()

func get_trial_camps() -> Dictionary:
	# W12: 캠프 좌표는 삭제됐다. 항상 빈 사전이다. game.gd의 camp_states 구축 루프와
	# rift_probe·test_runner의 캠프 순회가 0회가 되어 호출부를 한 줄도 고칠 필요가 없다.
	# (V5의 베이스캠프는 이 API와 무관하다 — `get_landmark("camp")`를 쓸 것.)
	return {}

# =============================================================================
# 동적 균열(Rift) API — v2 §5.5 · 예산만 스테이지 단위로 재키잉(V5 · §2.4)
# =============================================================================
# 배치 규칙
#   ① 스테이지당 RIFT_MAX_PER_RUN(2)개까지. 초과 요청은 거절하고 빈 사전을 돌려준다.
#   ② 플레이어로부터 900~1,400px 링 위. 후보 각도·거리는 (스테이지 시드, 요청 순번)만으로
#      결정되는 해시열에서 뽑으므로 재현 가능하다.
#   ③ 후보는 "add_dry_zone(중심, SAFE_ZONE_RIFT)이 덮었을 사각형 전체가 이미 마른
#      땅"인 자리만 통과한다. 그래서 호수 레이어를 런타임에 건드리지 않고도 물 위에
#      균열이 생기지 않는다.
#   ④ 성·캠프·보스문·다른 균열과는 각자의 안전 반경 + RIFT_CLEARANCE만큼 뗀다.
#   ⑤ 통과한 자리의 바닥은 성과 같은 오버레이 규칙으로 안전 타일을 깐다.

func begin_run_rifts(run_seed: int) -> void:
	# 스테이지 개시 시 1회. 시드가 같으면 이후 요청 순번마다 같은 좌표가 나온다.
	rift_run_seed = run_seed
	rifts.clear()
	rift_spawn_count = 0
	last_rift_result = "none"
	queue_redraw()

func spawn_rift_near(player_position: Vector2, run_seed: int = -1) -> Dictionary:
	# 성공하면 균열 사전을, 거절하면 빈 사전을 돌려준다. 거절 사유는
	# get_last_rift_result()로 읽는다("budget_exhausted" / "no_site").
	# 자리를 못 찾은 요청은 예산을 소모하지 않으므로 다음 프레임에 재시도해도 된다.
	if run_seed >= 0:
		rift_run_seed = run_seed
	if rift_spawn_count >= RIFT_MAX_PER_RUN:
		last_rift_result = "budget_exhausted"
		return {}
	var request_index := rift_spawn_count
	var placement := _find_rift_site(player_position, request_index)
	if placement.is_empty():
		last_rift_result = "no_site"
		return {}
	rift_spawn_count += 1
	var rift := {
		"id":"rift_%d_%d" % [stage, request_index],
		"index":request_index,
		"position":placement["position"],
		"radius":SAFE_ZONE_RIFT,
		"ring":RIFT_RING_RADIUS,
		"distance":placement["distance"],
		"attempts":placement["attempts"],
		"cleared":false
	}
	rifts.append(rift)
	last_rift_result = "ok"
	queue_redraw()
	return rift.duplicate()

func despawn_rift(rift_id: String) -> bool:
	# 해제는 월드에서 지우기만 한다. 스테이지당 2회 예산은 돌려주지 않는다 — 그래야
	# "열었다 닫았다"로 균열 보상을 무한히 얻을 수 없다.
	for index in rifts.size():
		if String(rifts[index].get("id", "")) == rift_id:
			rifts.remove_at(index)
			queue_redraw()
			return true
	return false

func set_rift_cleared(rift_id: String, cleared: bool = true) -> bool:
	for rift: Dictionary in rifts:
		if String(rift.get("id", "")) == rift_id:
			rift["cleared"] = cleared
			queue_redraw()
			return true
	return false

func get_rifts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rift: Dictionary in rifts:
		result.append(rift.duplicate())
	return result

func get_rift(rift_id: String) -> Dictionary:
	for rift: Dictionary in rifts:
		if String(rift.get("id", "")) == rift_id:
			return rift.duplicate()
	return {}

func get_active_rift() -> Dictionary:
	# 가장 최근에 열린 미클리어 균열. 나침반·배너가 가리킬 대상이다.
	for index in range(rifts.size() - 1, -1, -1):
		if not bool(rifts[index].get("cleared", false)):
			return rifts[index].duplicate()
	return {}

func get_nearest_rift(point: Vector2, radius: float = 520.0, include_cleared: bool = false) -> Dictionary:
	# game.gd의 _check_trial_camps()가 쓰던 근접 판정(520px)을 그대로 옮겨 쓸 수 있다.
	var nearest: Dictionary = {}
	var nearest_distance := radius
	for rift: Dictionary in rifts:
		if bool(rift.get("cleared", false)) and not include_cleared:
			continue
		var distance: float = point.distance_to(rift["position"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = rift
	return nearest.duplicate() if not nearest.is_empty() else {}

func rift_at(point: Vector2) -> Dictionary:
	# 이 점이 어느 균열의 아레나 안인지. 정예 스폰·아레나 이탈 판정용.
	for rift: Dictionary in rifts:
		if point.distance_to(rift["position"]) <= float(rift.get("radius", SAFE_ZONE_RIFT)):
			return rift.duplicate()
	return {}

func get_rift_compass(point: Vector2) -> Dictionary:
	# HUD 나침반용. 미클리어 균열 중 가장 가까운 것의 방향·거리.
	var target := get_nearest_rift(point, INF)
	if target.is_empty():
		return {}
	var delta: Vector2 = target["position"] - point
	return {
		"id":target["id"],
		"position":target["position"],
		"distance":delta.length(),
		"direction":delta.normalized()
	}

func rift_budget_remaining() -> int:
	return maxi(0, RIFT_MAX_PER_RUN - rift_spawn_count)

func get_last_rift_result() -> String:
	return last_rift_result

func export_rift_state() -> Dictionary:
	# 저장 스냅샷용. ConfigFile 변형 저장이라 Vector2가 그대로 들어간다.
	return {"seed":rift_run_seed, "spawned":rift_spawn_count, "rifts":rifts.duplicate(true)}

func import_rift_state(data: Dictionary) -> void:
	rift_run_seed = int(data.get("seed", 0))
	rift_spawn_count = clampi(int(data.get("spawned", 0)), 0, RIFT_MAX_PER_RUN)
	rifts.clear()
	for entry: Variant in (data.get("rifts", []) as Array):
		rifts.append((entry as Dictionary).duplicate(true))
	last_rift_result = "restored"
	queue_redraw()

func _find_rift_site(origin: Vector2, request_index: int) -> Dictionary:
	var base := absi(_hash(rift_run_seed, request_index, RIFT_SALT))
	for attempt in RIFT_CANDIDATES:
		var roll := absi(_hash(base + attempt * 7919, request_index * 131 + attempt, RIFT_SALT + attempt * 17))
		var angle := TAU * float(roll % 4096) / 4096.0
		var distance := RIFT_MIN_DISTANCE + (RIFT_MAX_DISTANCE - RIFT_MIN_DISTANCE) * float((roll >> 12) % 1024) / 1023.0
		var candidate := origin + Vector2.from_angle(angle) * distance
		# 싼 검사부터. 지형 검사는 청크를 생성시킬 수 있어 마지막에 둔다.
		if not _rift_site_clear_of_landmarks(candidate):
			continue
		if not _rift_site_dry(candidate):
			continue
		if not _rift_site_clear_of_features(candidate):
			continue
		return {"position":candidate, "distance":distance, "attempts":attempt + 1}
	return {}

func _rift_site_clear_of_landmarks(candidate: Vector2) -> bool:
	if not stage_landmarks.is_empty():
		if candidate.distance_to(get_boss_gate_position()) < boss_gate_radius + SAFE_ZONE_RIFT + RIFT_CLEARANCE:
			return false
		if candidate.distance_to(get_castle_position()) < SAFE_ZONE_CASTLE + SAFE_ZONE_RIFT + RIFT_CLEARANCE:
			return false
		if candidate.distance_to(get_camp_position()) < SAFE_ZONE_CAMP + SAFE_ZONE_RIFT + RIFT_CLEARANCE:
			return false
	for rift: Dictionary in rifts:
		if candidate.distance_to(rift["position"]) < SAFE_ZONE_RIFT * 2.0 + RIFT_CLEARANCE:
			return false
	return true

func _rift_site_dry(candidate: Vector2) -> bool:
	# add_dry_zone(중심, SAFE_ZONE_RIFT)이 덮었을 사각형과 같은 범위를 본다.
	return _area_dry(candidate, SAFE_ZONE_RIFT)

func _rift_site_clear_of_features(candidate: Vector2) -> bool:
	for feature: Dictionary in _features_near(candidate, 1):
		var gap: float = candidate.distance_to(feature["position"])
		match String(feature["type"]):
			"castle", "camp", "boss_gate":
				if gap < SAFE_ZONE_RIFT + SAFE_ZONE_CASTLE + RIFT_CLEARANCE:
					return false
			_:
				# 상자·숲·유적은 균열 바닥에 묻히지만 않으면 된다.
				if gap < SAFE_ZONE_RIFT + 40.0:
					return false
	return true

## Y5: 「물이면 못 간다」 -> 「물이거나 **돌**이면 못 간다」(FEEDBACK_Y §5.1).
## 다리는 예외로 계속 통과합니다. 랜드마크·균열 바닥은 `_resolved_tile_id()`가
## 안전 타일로 덮으므로 그 위에는 돌이 얹히지 않습니다.
func is_walkable(point: Vector2) -> bool:
	return _tile_walkable(_resolved_tile_id(_world_to_tile(point)))

## 걸을 수 있는가를 **타일 id 하나**로 답하는 속살. `is_walkable()`과
## `measure_terrain_mix()`가 같은 규칙을 쓰도록 한 곳에만 둡니다 — 두 군데에
## 같은 조건을 베껴 두면 나중에 한쪽만 고쳐져 계측이 거짓말을 합니다.
func _tile_walkable(tile_id: int) -> bool:
	if terrain_generator.is_bridge_tile(tile_id):
		return true
	return not terrain_generator.is_water_tile(tile_id) and not terrain_generator.is_rock_tile(tile_id)

## 이 지점의 지형 이름("grass" "grass_tuft" "grass_flower" "forest" "rocks" "water"
## "shore_north"… "bridge" "ruins" "courtyard" "camp"). 랜드마크·강·균열 덮개가
## 걸리면 그 덮개 타일의 이름을 줍니다(= 눈에 보이는 것과 같은 진실).
func tile_kind_at(point: Vector2) -> String:
	return String(terrain_generator.tile_name(_resolved_tile_id(_world_to_tile(point))))

func is_rock_at(point: Vector2) -> bool:
	return terrain_generator.is_rock_tile(_resolved_tile_id(_world_to_tile(point)))

## 지형 구성비 계측(FEEDBACK_Y §5.1의 「젖은 칸 12~20%」 계약을 재는 자).
## center를 중심으로 tile_span×tile_span 타일 정사각형을 stride 간격으로 훑습니다.
## 반환: "wet"(0~1) "rock"(0~1) "walkable"(0~1) "samples"(개수).
## 랜드마크·강·균열 덮개가 반영된 **해결된 타일**을 봅니다.
##
## ⚠️ 이 함수는 청크를 잔뜩 만들어 냅니다(비쌉니다). 호출부가 span·stride로 비용을
## 조절하세요. 끝날 때 캐시를 중심 근처로 줄여 `--world-test`의 캐시 상한 단언
## (cached_chunks <= 72)을 깨지 않게 합니다.
func measure_terrain_mix(center: Vector2, tile_span: int, stride: int = 1) -> Dictionary:
	var span := clampi(tile_span, 1, TERRAIN_MIX_SPAN_MAX)
	var step := maxi(1, stride)
	var center_tile := _world_to_tile(center)
	var half := span / 2
	var samples := 0
	var wet := 0
	var rock := 0
	var walkable := 0
	var offset_y := -half
	# 가로줄 우선으로 훑습니다. 한 줄이 지나는 청크는 스무 개 남짓이라 캐시(72칸)
	# 안에 들어가고, 줄이 바뀌어도 같은 청크 띠를 다시 쓰므로 재생성이 거의 없습니다.
	while offset_y < span - half:
		var offset_x := -half
		while offset_x < span - half:
			var tile_id := _resolved_tile_id(center_tile + Vector2i(offset_x, offset_y))
			samples += 1
			if terrain_generator.is_water_tile(tile_id):
				wet += 1
			if terrain_generator.is_rock_tile(tile_id):
				rock += 1
			if _tile_walkable(tile_id):
				walkable += 1
			offset_x += step
		offset_y += step
	terrain_generator.trim_cache(terrain_generator.chunk_for_tile(center_tile))
	var total := float(maxi(1, samples))
	return {
		"wet": float(wet) / total,
		"rock": float(rock) / total,
		"walkable": float(walkable) / total,
		"samples": samples
	}

func get_generation_stats() -> Dictionary:
	return terrain_generator.stats()

func get_tile_id(point: Vector2) -> int:
	return _resolved_tile_id(_world_to_tile(point))

func validate_generation_near(point: Vector2) -> Dictionary:
	var chunk: Vector2i = terrain_generator.chunk_for_tile(_world_to_tile(point))
	var local_ok: bool = terrain_generator.validate_chunk(chunk)
	var seams_ok := true
	for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		seams_ok = seams_ok and terrain_generator.validate_neighbor_seam(chunk, chunk + offset)
	return {"chunk":chunk, "local_rules":local_ok, "seams":seams_ok}

func get_nearest_interactable(point: Vector2, radius: float = 92.0) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := radius
	for feature: Dictionary in _features_near(point, 2):
		if feature["type"] == "chest" and opened_features.has(feature["id"]):
			continue
		var distance := point.distance_to(feature["position"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = feature
	return nearest

func find_walkable_near(point: Vector2, rng: RandomNumberGenerator, minimum: float, maximum: float) -> Vector2:
	var gate := get_boss_gate_position()
	for _attempt in 24:
		var candidate := point + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(minimum, maximum)
		if is_walkable(candidate) and (stage_landmarks.is_empty() or candidate.distance_to(gate) > boss_gate_radius + 40.0):
			return candidate
	return point + Vector2(maximum, 0.0)

func _draw() -> void:
	var center := Vector2.ZERO
	if is_instance_valid(player):
		center = player.global_position
	var start_x := int(floor((center.x - VIEW_HALF.x) / TILE)) * TILE
	var end_x := int(ceil((center.x + VIEW_HALF.x) / TILE)) * TILE
	var start_y := int(floor((center.y - VIEW_HALF.y) / TILE)) * TILE
	var end_y := int(ceil((center.y + VIEW_HALF.y) / TILE)) * TILE

	var y := start_y
	while y <= end_y:
		var x := start_x
		while x <= end_x:
			_draw_tile(Vector2(x, y), Vector2i(floori(float(x) / TILE), floori(float(y) / TILE)))
			x += TILE
		y += TILE
	var center_tile := _world_to_tile(center)
	terrain_generator.trim_cache(terrain_generator.chunk_for_tile(center_tile))

	for feature: Dictionary in _features_near(center, 2):
		if feature["position"].distance_to(center) > 1400.0:
			continue
		match feature["type"]:
			"castle": _draw_castle(feature["position"], false)
			"camp": _draw_camp(feature["position"])
			"boss_gate": _draw_boss_gate(feature["position"])
			"chest":
				if not opened_features.has(feature["id"]):
					_draw_chest(feature["position"])
			"grove": _draw_grove(feature["position"], int(feature["variant"]))
			"ruin": _draw_ruin(feature["position"])
	for rift: Dictionary in rifts:
		if rift["position"].distance_to(center) <= 1050.0:
			_draw_rift(rift["position"], int(rift.get("index", 0)), bool(rift.get("cleared", false)))

## §7.3 그레이드 — 채도 감쇠 + 늪 녹조. **CanvasModulate와 색을 나눠 갖는다**
## (스테이지 주간/야간 색은 game.gd의 CanvasModulate가 소유한다).
func _grade(base: Color) -> Color:
	var graded := base
	if stage_saturation < 0.999:
		var luminance := graded.get_luminance()
		graded = Color(luminance, luminance, luminance, graded.a).lerp(graded, stage_saturation)
	if stage_green_overlay > 0.0:
		graded = graded.lerp(Color("6f9a4c"), stage_green_overlay)
	return graded

func _draw_tile(tile_position: Vector2, tile_coord: Vector2i) -> void:
	var tile_id := _resolved_tile_id(tile_coord)
	if tile_id < 0 or tile_id >= tile_sources.size():
		tile_id = 0
	var source: Rect2 = tile_sources[tile_id]
	var night_tint := _grade(Color.WHITE.lerp(Color("7181a4"), night_amount * 0.48))
	var turn := int(tile_turns[tile_id])
	if turn == 0:
		draw_texture_rect_region(_terrain_atlas, Rect2(tile_position, Vector2(TILE, TILE)), source, night_tint)
		return
	# 아틀라스에 호수 남동/남서 모서리 그림만 있으므로 북서/북동 모서리는 같은
	# 셀을 90도 단위로 돌려 만듭니다. 정확히 0/±1 성분만 쓰는 행렬이라
	# nearest 샘플링에서 픽셀이 밀리지 않습니다.
	var center := tile_position + Vector2(TILE, TILE) * 0.5
	var basis_x := Vector2(1.0, 0.0)
	var basis_y := Vector2(0.0, 1.0)
	match turn:
		1:
			basis_x = Vector2(0.0, 1.0)
			basis_y = Vector2(-1.0, 0.0)
		2:
			basis_x = Vector2(-1.0, 0.0)
			basis_y = Vector2(0.0, -1.0)
		3:
			basis_x = Vector2(0.0, -1.0)
			basis_y = Vector2(1.0, 0.0)
	draw_set_transform_matrix(Transform2D(basis_x, basis_y, center))
	draw_texture_rect_region(_terrain_atlas, Rect2(Vector2(TILE, TILE) * -0.5, Vector2(TILE, TILE)), source, night_tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _world_to_tile(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / float(TILE)), floori(point.y / float(TILE)))

## 덮개(성 안뜰·캠프·보스방·균열 바닥)가 이 타일을 먹는가.
##
## ⚠️ **타일 중심이 아니라 타일 전체를 본다.** Y5 이전에는 `중심 거리 < 반지름`이었고,
## 그때는 그래도 됐다 — 덮개 밖으로 삐져나온 칸에 놓이는 것은 잔디나 숲이라
## 걸어 다니는 데 아무 문제가 없었기 때문이다. **Y5가 돌을 못 지나가게 만들면서
## 그 반 칸이 실제로 사람을 막기 시작했다.** 아레나 가장자리(중심에서 142px)를
## 밟았는데 그 칸의 중심은 155px이라 덮개 밖 → 원본 WFC 타일이 그대로 비치고,
## 그게 돌이면 아레나 테두리 한 조각이 통행 불가가 된다.
## (`rift_probe` ③번이 이 회귀를 잡았다 — `blocked_samples=1/72 kind=rocks`.)
##
## 그래서 **원과 조금이라도 겹치는 칸은 전부 덮는다.** 타일 중심에서 원 중심까지의
## 거리가 `반지름 + 반 대각선`보다 작으면 그 칸은 원에 닿는다(보수적 상위집합이라
## 빈틈이 남지 않는다). 호수 dry zone은 이미 `반지름 + 2칸` 여유로 잡혀 있어
## 덮개가 반 칸 넓어져도 호수를 자르지 않는다.
const COVER_TILE_MARGIN := TILE * 0.7072   # 40px 칸의 반 대각선 = 28.3px

func _cover_hits(tile_center: Vector2, cover_center: Vector2, cover_radius: float) -> bool:
	return tile_center.distance_to(cover_center) < cover_radius + COVER_TILE_MARGIN

func _resolved_tile_id(tile_coord: Vector2i) -> int:
	var center := Vector2(tile_coord.x * TILE + TILE * 0.5, tile_coord.y * TILE + TILE * 0.5)
	var starter_landmark := _starter_river_tile(tile_coord)
	if starter_landmark >= 0:
		return starter_landmark
	# 전투 목적지는 WFC 위에 얹는 설계 고정점입니다. 목적지 바닥만 안전한
	# 타일로 덮어 보스문·성 입구가 호수 속에 생기는 상황을 방지합니다.
	# 같은 반지름이 호수 레이어의 dry zone으로도 등록돼 있어 덮개가 호수를
	# 잘라내는 일은 생기지 않습니다.
	if not stage_landmarks.is_empty():
		if _cover_hits(center, get_castle_position(), SAFE_ZONE_CASTLE):
			return int(terrain_generator.T_COURTYARD)
		if _cover_hits(center, get_camp_position(), SAFE_ZONE_CAMP):
			return int(terrain_generator.T_COURTYARD)
		# 보스방 아레나 바닥은 균열과 같은 아레나 타일이다(설계 §3.5 "렌더러 재사용").
		if _cover_hits(center, get_boss_gate_position(), boss_gate_radius):
			return int(terrain_generator.T_CAMP)
	# 균열 바닥도 같은 규칙이다. 배치 단계에서 이 반경 안이 전부 마른 땅임을
	# 보장했으므로 덮개 경계가 물가 그림을 자르는 일이 없다.
	for rift: Dictionary in rifts:
		if _cover_hits(center, rift["position"], float(rift.get("radius", SAFE_ZONE_RIFT))):
			return int(terrain_generator.T_CAMP)
	return terrain_generator.tile_id_at(tile_coord)

func _starter_river_tile(tile_coord: Vector2i) -> int:
	# 첫 모험에서 물길과 다리의 의미를 바로 배울 수 있도록 스폰 동쪽에만
	# 짧은 고정 랜드마크를 둡니다. 이 구간 밖의 모든 지형은 WFC가 생성합니다.
	if not _river_wet(tile_coord):
		return -1
	if tile_coord.y == RIVER_BRIDGE_ROW and tile_coord.x >= RIVER_LEFT and tile_coord.x <= RIVER_RIGHT:
		return int(terrain_generator.T_BRIDGE)
	# 물가 타일은 WFC와 완전히 같은 규칙으로 고릅니다. 그래서 물길 끝과
	# 모서리가 호수와 같은 모양으로 닫힙니다.
	return int(terrain_generator.water_tile_for_pattern(
		not _river_wet(tile_coord + Vector2i(0, -1)),
		not _river_wet(tile_coord + Vector2i(1, 0)),
		not _river_wet(tile_coord + Vector2i(0, 1)),
		not _river_wet(tile_coord + Vector2i(-1, 0))
	))

func _river_wet(tile_coord: Vector2i) -> bool:
	if tile_coord.y < RIVER_TOP or tile_coord.y > RIVER_BOTTOM:
		return false
	return tile_coord.x >= RIVER_LEFT and tile_coord.x <= RIVER_RIGHT

func _is_water(point: Vector2) -> bool:
	var tile_id := _resolved_tile_id(_world_to_tile(point))
	return terrain_generator.is_water_tile(tile_id)

func _is_bridge(point: Vector2) -> bool:
	return terrain_generator.is_bridge_tile(_resolved_tile_id(_world_to_tile(point)))

func _features_near(point: Vector2, chunk_radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center_chunk := _chunk_of(point)
	# V5: 스테이지 랜드마크 3종은 청크 하나를 통째로 차지하는 게 아니라 **먼저** 얹힌다.
	# 캠프와 보스문은 520px 떨어져 있어 같은 청크(800px)에 들어갈 수 있으므로,
	# "청크당 feature 하나" 규칙에 맡기면 둘 중 하나가 사라진다.
	for key: String in stage_landmarks:
		var landmark: Dictionary = stage_landmarks[key]
		var landmark_chunk := _chunk_of(landmark["position"])
		if absi(landmark_chunk.x - center_chunk.x) > chunk_radius or absi(landmark_chunk.y - center_chunk.y) > chunk_radius:
			continue
		# ⚠️ **반드시 복사본을 흘린다.** v2의 feature는 `_feature_for_chunk()`가 매번 새로
		# 만드는 임시 사전이라 호출부가 마음대로 다뤄도 됐지만, v3 랜드마크는 월드가
		# 들고 있는 **영속 객체**다. game.gd `_refresh_interactable()`이 이걸 그대로
		# `current_interactable`에 담고 `current_interactable.clear()`를 부르는 경로가
		# 여러 곳이라, 원본을 흘리면 성이 통째로 빈 사전이 된다(실측으로 잡은 회귀).
		result.append(landmark.duplicate(true))
	for cx in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
		for cy in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
			var chunk := Vector2i(cx, cy)
			if _landmark_chunks.has(chunk):
				continue
			var feature := _feature_for_chunk(chunk)
			if not feature.is_empty():
				result.append(feature)
	return result

func _feature_for_chunk(chunk: Vector2i) -> Dictionary:
	# V5: v2의 "청크 (0,-1) = 시작 성" · "마왕성 청크" 두 고정 분기는 삭제됐다.
	# 성·캠프·보스문은 전부 `stage_landmarks`가 소유하고 `_features_near()`가 얹는다.
	var value: int = absi(_hash(chunk.x, chunk.y, 97))
	var offset: Vector2 = Vector2(float((value >> 3) % 340 - 170), float((value >> 11) % 320 - 160))
	var position: Vector2 = Vector2(chunk.x * FEATURE_CHUNK + FEATURE_CHUNK * 0.5, chunk.y * FEATURE_CHUNK + FEATURE_CHUNK * 0.5) + offset
	if not is_walkable(position):
		# 호수가 조각이 아니라 제대로 된 덩어리가 됐으므로, 물 위에 놓인 목표를
		# 뭍으로 옮길 때 한 단계 반경으로는 부족할 수 있습니다. 결정적인 순서로
		# 반경을 넓혀 가며 찾습니다.
		var directions := [
			Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
			Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)
		]
		var relocated := false
		for reach in [230.0, 340.0, 450.0, 560.0]:
			for direction: Vector2 in directions:
				if is_walkable(position + direction * reach):
					position += direction * reach
					relocated = true
					break
			if relocated:
				break
	var feature_type: String = ""
	var roll: int = value % 100
	# V5(설계 §2.3): **랜덤 성 9%를 삭제하고 그 9%를 상자에 넘겼다.** 되돌리려면
	# `GameTuning.CASTLE_FEATURE_ROLL`을 9로, `CHEST_FEATURE_ROLL`을 49로 되돌리면
	# 끝이다 — 설계가 명시적으로 약속한 되돌림 지점이 이 두 상수다.
	if roll < GameTuning.CASTLE_FEATURE_ROLL:
		feature_type = "castle"
	elif roll < GameTuning.CHEST_FEATURE_ROLL:
		feature_type = "chest"
	elif roll < 76:
		feature_type = "grove"
	elif roll < 90:
		feature_type = "ruin"
	else:
		return {}
	return {
		"id":"%s_%d_%d" % [feature_type, chunk.x, chunk.y],
		"type":feature_type,
		"position":position,
		"variant":value % 4
	}

# 랜드마크도 타일과 같은 밤 색조를 탄다. 지형만 어두워지고 성은 대낮이면
# 밤에 성이 떠 보입니다.
func _landmark_tint() -> Color:
	return _grade(Color.WHITE.lerp(Color("7181a4"), night_amount * 0.48))

# 스프라이트를 밑변 기준으로 놓습니다. 랜드마크는 "발밑"이 지면이라
# 세로 중심이 아니라 아래쪽을 기준점으로 잡아야 지형 위에 서 있어 보입니다.
func _draw_landmark(texture: Texture2D, position: Vector2, base_offset: float) -> void:
	var size := Vector2(texture.get_width(), texture.get_height())
	draw_texture_rect(
		texture,
		Rect2(position + Vector2(-size.x * 0.5, base_offset - size.y), size),
		false,
		_landmark_tint()
	)

func _draw_castle(position: Vector2, demon: bool) -> void:
	# 성 앞 흙길만 절차적으로 남깁니다. 입구가 어디인지 알려 주는 표시라
	# 스프라이트 아래에 깔려 있어야 합니다.
	draw_rect(Rect2(position + Vector2(-104.0, 56.0), Vector2(208.0, 40.0)), Color(GamePalette.DIRT_DARK, 0.72), true)
	_draw_landmark(DEMON_CASTLE_SPRITE if demon else CASTLE_SPRITE, position, 64.0)
	if demon:
		draw_circle(position + Vector2(0.0, 30.0), 13.0, Color(GamePalette.RED, 0.55))

## 베이스 캠프 — 성과 같은 "정비 지점" 언어(흙길 + 밑변 기준 스프라이트)를 쓰되
## 색 링을 하나 둘러 보스문 앞이라는 것을 알린다.
func _draw_camp(position: Vector2) -> void:
	draw_circle(position, SAFE_ZONE_CAMP, Color(GamePalette.GREEN, 0.045))
	draw_arc(position, SAFE_ZONE_CAMP, 0.0, TAU, 40, Color(GamePalette.GREEN, 0.42), 3.0)
	draw_rect(Rect2(position + Vector2(-92.0, 44.0), Vector2(184.0, 34.0)), Color(GamePalette.DIRT_DARK, 0.72), true)
	_draw_landmark(CAMP_SPRITE, position, 52.0)

## 보스방 — 균열 아레나 렌더러를 반경 ×2.2로 복제한 원형 아레나(설계 §3.5).
## 문 스프라이트는 아레나 중심에 세운다(상호작용 판정도 중심 기준이다).
func _draw_boss_gate(position: Vector2) -> void:
	var gate_color: Color = GamePalette.RED if not boss_gate_cleared else GamePalette.MUTED
	draw_circle(position, boss_gate_radius, Color(gate_color, 0.05 if not boss_gate_cleared else 0.02))
	draw_arc(position, boss_gate_radius, 0.0, TAU, 64, Color(gate_color, 0.5), 5.0)
	draw_arc(position, boss_gate_radius * 0.62, 0.0, TAU, 48, Color(gate_color, 0.24), 3.0)
	# 문 앞 흙길 — 성과 같은 언어라 "여기가 입구"가 바로 읽힌다.
	draw_rect(Rect2(position + Vector2(-104.0, 52.0), Vector2(208.0, 40.0)), Color(GamePalette.DIRT_DARK, 0.78), true)
	_draw_landmark(BOSS_GATE_SPRITE, position, 60.0)
	if not boss_gate_cleared:
		draw_circle(position + Vector2(0.0, 22.0), 14.0, Color(gate_color, 0.55))

func _draw_chest(position: Vector2) -> void:
	_draw_landmark(CHEST_SPRITE, position, 16.0)

func _draw_grove(position: Vector2, variant: int) -> void:
	for index in 5:
		var angle := TAU * float(index) / 5.0 + variant * 0.3
		var tree := position + Vector2.from_angle(angle) * (26.0 + index % 2 * 20.0)
		_draw_landmark(TREE_SPRITE, tree, 22.0)

func _draw_ruin(position: Vector2) -> void:
	_draw_landmark(RUIN_SPRITE, position, 22.0)

func _draw_rift(position: Vector2, index: int, cleared: bool) -> void:
	# 바닥 원판·테두리 링·클리어 체크 표시는 구 시련 캠프 오버레이(W12 삭제,
	# docs/v1-archive/world_grid_v1.gd.txt)에서 물려받은 형태다. 가운데 표식만
	# 다르다 — 천막 4개 + 깃발 대신 세로로 찢긴 틈과 파편을 그린다.
	var rift_color: Color = [GamePalette.MAGENTA, GamePalette.CYAN, GamePalette.RED][index % 3]
	draw_circle(position, RIFT_RING_RADIUS, Color(rift_color, 0.055 if not cleared else 0.025))
	draw_arc(position, RIFT_RING_RADIUS, 0.0, TAU, 32, Color(rift_color, 0.55), 4.0)
	if cleared:
		draw_arc(position, 58.0, 0.0, TAU, 16, Color(rift_color, 0.7), 4.0)
		draw_line(position + Vector2(-25.0, 0.0), position + Vector2(-5.0, 22.0), rift_color, 8.0)
		draw_line(position + Vector2(-5.0, 22.0), position + Vector2(34.0, -25.0), rift_color, 8.0)
		return
	var tear := PackedVector2Array([
		position + Vector2(0.0, -74.0), position + Vector2(19.0, -26.0),
		position + Vector2(11.0, 6.0), position + Vector2(24.0, 46.0),
		position + Vector2(0.0, 78.0), position + Vector2(-22.0, 44.0),
		position + Vector2(-10.0, 4.0), position + Vector2(-18.0, -28.0)
	])
	draw_colored_polygon(tear, Color(0.05, 0.03, 0.09, 0.92))
	draw_polyline(PackedVector2Array(Array(tear) + [tear[0]]), rift_color, 3.0)
	draw_line(position + Vector2(0.0, -62.0), position + Vector2(0.0, 66.0), Color(rift_color, 0.85), 2.0)
	for shard in 4:
		var angle := TAU * float(shard) / 4.0 + PI * 0.25
		var shard_center := position + Vector2.from_angle(angle) * 66.0
		var piece := PackedVector2Array([
			shard_center + Vector2(0.0, -13.0), shard_center + Vector2(9.0, 3.0),
			shard_center + Vector2(0.0, 12.0), shard_center + Vector2(-9.0, 2.0)
		])
		draw_colored_polygon(piece, Color(rift_color, 0.75))

func _hash(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 1442695041
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)
