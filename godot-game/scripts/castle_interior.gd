class_name CastleInterior
extends Node2D

# =============================================================================
# 성 내부 — **1.45배 확장 + 대전실 재설계** (사용자 피드백 ⑳·㉑ · 2026-08-10)
# =============================================================================
# 구판은 960×570짜리 체커 바닥 한 장에 NPC 넷을 세운 방이었다. 사용자 지적 두 가지:
#   ⑳ "성이 좁다" — 화면(1,280×720) 하나에 방이 통째로 들어와 걸어다닐 이유가 없었다.
#   ㉑ "디자인이 성 같지 않다" — 바닥 격자 + 벽 사각형 + 문간 판자가 전부였다.
#
# ── 무엇을 바꿨나 ────────────────────────────────────────────────────────────
#   ① 방을 **1,400×840**으로 넓혔다(면적 2.15배). 카메라가 플레이어를 따라가므로
#      한 화면에 다 안 들어오고, NPC 사이를 실제로 걸어야 한다.
#   ② 바닥 타일이 **벽 안쪽으로만** 깔린다. 구판은 40px 타일을 -460…460에 깔아
#      오른쪽 20px · 아래 5px이 **벽 밖으로 삐져나와** 있었다(실측 스크린샷 확인).
#      이제 안뜰 사각형을 먼저 정하고 그 안에서만 돈다.
#   ③ 대전실 구성물이 생겼다 — 붉은 융단 · 벽기둥 6개 · 벽걸이 깃발 4장 ·
#      옥좌 단상 · 화로 4개. 전부 정적 도형이라 무한 애니메이션 0개 규칙을 지킨다.
#   ④ 출구가 아래 벽 한가운데의 **아치 문**이 됐다(판자 한 장 → 문틀 + 계단).
const ROOM_BOUNDS := Rect2(-700.0, -420.0, 1400.0, 840.0)
## 벽 두께. 바닥·구성물은 전부 이 안쪽(=`INNER_BOUNDS`)에만 그린다.
const WALL_THICKNESS := 40.0
## 걸을 수 있는 안뜰. 바닥 타일이 여기를 벗어나면 벽 위에 얹힌다(구판의 결함).
const INNER_BOUNDS := Rect2(-660.0, -380.0, 1320.0, 760.0)
const EXIT_POSITION := Vector2(0.0, 372.0)

# 성 바닥 한 장(32×32). world_grid의 안뜰 셀과 같은 원본이라 성 안팎이 이어져
# 보인다. 필드와 똑같이 32→40으로 늘려 깔아야 픽셀 크기가 어긋나지 않는다.
const FLOOR_TILE := preload("res://art/v2/castle-floor.png")
# NPC 시트(192×64). 위 절반이 그림, 아래 절반이 흰 실루엣 마스크다. 마스크는
# 플레이어가 가까이 왔을 때 강조하는 용도인데 이 노드는 플레이어 위치를 모르므로
# 지금은 위 절반만 쓴다. 아래 절반을 쓰려면 game.gd가 거리를 넘겨줘야 한다.
const NPC_SHEET := preload("res://art/v2/castle-npcs.png")
const NPC_CELL := 32.0

# 서비스 → NPC 시트 열. 여기 없는 서비스(v1 잔존 7종 포함)는 전부 4번(노인)으로
# 떨어진다. 시트 열 5(공주)는 예비 칸이라 아직 아무도 쓰지 않는다.
# 열 2는 계약자가 쓰던 자리다. 계약 3종이 폐기되면서 비었고, 신설 NPC인
# 대장간 장인(`forge`)이 그 자리를 이어받는다(시트를 다시 굽지 않기 위해서다).
const SERVICE_SPRITE_COLUMN := {
	"card_shop": 0,
	"rune_shop": 1,
	"forge": 2,
	"spy": 3
}
const SERVICE_SPRITE_FALLBACK := 4

var castle_id := ""
var services: Array[String] = []
var npcs: Array[Dictionary] = []

func _ready() -> void:
	# setup()은 노드가 트리에 들어가기 전에 불릴 수도 있어서 여기서 건다.
	# 이게 없으면 32→40 확대가 뭉개져 도트가 흐려진다.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(service_ids: Array[String], feature_id: String) -> void:
	services = service_ids.duplicate()
	castle_id = feature_id
	# 넓어진 방에 맞춘 네 자리. 두 명만 서는 성도 있으므로(랜덤 2~4) **어느 두 자리를
	# 뽑아도 서로 멀지 않게** 안쪽으로 모아 배치한다 — 둘뿐인데 대각선 끝에 서면
	# 방이 비어 보인다.
	var positions: Array[Vector2] = [
		Vector2(-430.0, -120.0), Vector2(-150.0, -250.0),
		Vector2(150.0, -250.0), Vector2(430.0, -120.0)
	]
	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = absi(feature_id.hash()) + 991
	for index in range(positions.size() - 1, 0, -1):
		var swap_index := seeded_rng.randi_range(0, index)
		var temporary := positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = temporary
	for index in services.size():
		npcs.append({"service":services[index], "position":positions[index]})
	z_index = -8
	queue_redraw()

func get_spawn_position() -> Vector2:
	# 문 바로 안쪽. 들어오면 등 뒤가 출구라 "어디로 나가나"를 묻지 않아도 된다.
	return Vector2(0.0, 296.0)

func is_walkable(point: Vector2) -> bool:
	# 벽 두께 + 스프라이트 반폭. 안뜰(INNER_BOUNDS)이 곧 걸을 수 있는 면이다.
	return INNER_BOUNDS.grow(-16.0).has_point(point)

func get_nearest_interactable(point: Vector2, radius: float = 74.0) -> Dictionary:
	if point.distance_to(EXIT_POSITION) <= radius:
		return {"type":"castle_exit", "position":EXIT_POSITION}
	for npc: Dictionary in npcs:
		if point.distance_to(npc["position"]) <= radius:
			return {"type":"castle_npc", "service":npc["service"], "position":npc["position"]}
	return {}

## 융단 폭. 문에서 옥좌까지 방을 세로로 가른다 — 넓어진 방의 "가운데"를 만든다.
const CARPET_WIDTH := 240.0
## 벽기둥 한 짝의 x 좌표(좌우 대칭으로 그린다).
const PILLAR_X: Array[float] = [-500.0, -180.0, 180.0, 500.0]
## 문틀 안쪽 폭. 이보다 좁으면 스프라이트가 문에 끼어 보인다.
const DOOR_WIDTH := 170.0

func _draw() -> void:
	# ── ① 방 바탕 + 벽 ────────────────────────────────────────────────────
	# 바탕을 먼저 통째로 깔고 그 위에 안뜰을 얹는다. 이렇게 하면 벽은 "남은 테두리"가
	# 되어 **바닥이 벽 밖으로 새는 일이 구조적으로 불가능**하다(구판의 결함을 닫는다).
	draw_rect(ROOM_BOUNDS, GamePalette.STONE_DARK.darkened(0.35), true)
	# ── ② 안뜰 바닥 — 타일을 INNER_BOUNDS 안에서만 돈다 ────────────────────
	var tile := 40.0
	var columns := int(INNER_BOUNDS.size.x / tile)
	var rows := int(INNER_BOUNDS.size.y / tile)
	for column in columns:
		for row in rows:
			var at := INNER_BOUNDS.position + Vector2(float(column) * tile, float(row) * tile)
			# 격자 자체는 남긴다. 같은 타일만 깔면 넓은 홀이 평평해져서 이동 거리가
			# 안 읽히므로, 홀짝 칸에 옅은 명암을 준다.
			# ★ 피드백 ㉑: 방이 2배가 되면서 밝은 복숭아색 바닥이 화면을 통째로 덮어
			#   "실내"로 안 읽혔다. 전체를 한 단계 어둡게 깔고(0.86), **벽에 붙은 두 줄**은
			#   더 어둡게(0.62) 해 안뜰 가장자리가 스스로 테두리를 만들게 한다.
			var edge := column <= 1 or row <= 1 or column >= columns - 2 or row >= rows - 2
			var shade := 0.62 if edge else (0.86 if (column + row) % 2 == 0 else 0.79)
			draw_texture_rect_region(FLOOR_TILE, Rect2(at, Vector2(tile, tile)),
				Rect2(0.0, 0.0, 32.0, 32.0), Color(shade, shade, shade * 1.04))
	# ── ③ 붉은 융단 — 문에서 옥좌 단상까지 ────────────────────────────────
	# 넓은 방은 "어디로 가야 하나"를 스스로 말해야 한다. 융단이 그 답이다.
	draw_rect(Rect2(-CARPET_WIDTH * 0.5, -330.0, CARPET_WIDTH, 700.0), Color("6d2230"), true)
	draw_rect(Rect2(-CARPET_WIDTH * 0.5 + 14.0, -330.0, CARPET_WIDTH - 28.0, 700.0), Color("8a2c3c"), true)
	for stripe in range(-320, 370, 80):
		draw_rect(Rect2(-CARPET_WIDTH * 0.5 + 22.0, float(stripe), CARPET_WIDTH - 44.0, 4.0),
			GamePalette.YELLOW.darkened(0.45), true)
	# ── ④ 옥좌 단상 — 방의 북쪽 끝 ────────────────────────────────────────
	draw_rect(Rect2(-260.0, -380.0, 520.0, 96.0), Color("2c2338"), true)
	draw_rect(Rect2(-230.0, -380.0, 460.0, 76.0), Color("402945"), true)
	draw_rect(Rect2(-200.0, -368.0, 400.0, 52.0), GamePalette.RED.darkened(0.36), true)
	# 옥좌 — 앉은 사람은 없다. 빈 왕좌가 "왕은 이미 떠났다"를 말한다.
	draw_rect(Rect2(-46.0, -372.0, 92.0, 74.0), Color("241d2e"), true)
	draw_rect(Rect2(-36.0, -360.0, 72.0, 56.0), GamePalette.WOOD.darkened(0.25), true)
	draw_rect(Rect2(-30.0, -352.0, 60.0, 26.0), GamePalette.YELLOW.darkened(0.35), true)
	# ── ⑤ 벽기둥 — 좌우 벽에 붙은 세로 기둥 6개 ───────────────────────────
	for pillar_x: float in PILLAR_X:
		_draw_pillar(Vector2(pillar_x, -380.0))
		_draw_pillar(Vector2(pillar_x, 300.0))
	# ── ⑥ 벽걸이 깃발 — 위쪽 벽에 네 장 ──────────────────────────────────
	# 옥좌 단상(가로 −260…260) 바깥에만 건다. 단상 위에 겹치면 왕좌가 안 읽힌다.
	var banner_colors: Array[Color] = [GamePalette.BLUE, GamePalette.MAGENTA,
		GamePalette.CYAN, GamePalette.GREEN]
	var banner_x_list: Array[float] = [-580.0, -340.0, 340.0, 580.0]
	for index in banner_x_list.size():
		_draw_banner(Vector2(banner_x_list[index], -376.0), banner_colors[index])
	# ── ⑦ 화로 넷 — 방 네 귀퉁이 안쪽. 정적이다(깜빡임 없음) ──────────────
	for corner_x: float in [-590.0, 590.0]:
		for corner_y: float in [-300.0, 240.0]:
			_draw_brazier(Vector2(corner_x, corner_y))
	# ── ⑧ 아치 문 — 아래 벽 한가운데 ─────────────────────────────────────
	var door_left := -DOOR_WIDTH * 0.5
	draw_rect(Rect2(door_left - 18.0, 352.0, DOOR_WIDTH + 36.0, 68.0), GamePalette.WOOD.darkened(0.45), true)
	draw_rect(Rect2(door_left, 358.0, DOOR_WIDTH, 62.0), Color("0d1018"), true)
	# 문지방 계단 두 단 — 문이 "밖으로 내려가는 곳"으로 읽힌다.
	draw_rect(Rect2(door_left - 34.0, 336.0, DOOR_WIDTH + 68.0, 12.0), GamePalette.STONE_LIGHT.darkened(0.30), true)
	draw_rect(Rect2(door_left - 22.0, 324.0, DOOR_WIDTH + 44.0, 12.0), GamePalette.STONE_LIGHT.darkened(0.16), true)
	for npc: Dictionary in npcs:
		_draw_npc(npc["position"], npc["service"])
	var font := ThemeDB.fallback_font
	# V11 시각 QA: 이 안내는 성·캠프에서 **밖으로 나가는 유일한 문구**인데 읽히지 않았다.
	# 노란 글자가 연한 복숭아색 체커 바닥 위에 맨몸으로 얹혀 대비가 거의 없었고, 베이스라인
	# 220은 바로 위에서 그린 문간 나무판(y 226~275)에 아랫부분이 물려 있었다.
	#   ① 외곽선 — game.gd의 레일 흐름 배너가 풀밭 위 글자에 쓰는 것과 같은 값
	#      (두께 6 · 거의 검정 0.92)을 그대로 쓴다. draw_string보다 **먼저** 깔아야
	#      본문이 그 위에 얹힌다. 순서를 뒤집으면 글자가 외곽선에 먹힌다.
	#   ② 베이스라인 220 → 212 — 15px 글자의 내림(약 4px)에 외곽선 6px이 더 붙으므로
	#      220에 두면 아래끝이 226을 넘어 나무판과 겹친다. 8px 올리면 문 바로 위에
	#      떠 있으면서, 출구에 선 플레이어 스프라이트(발밑 +21 기준 머리 y≈221)와도
	#      겹치지 않는다.
	# 문틀이 y 352에서 시작하므로 안내는 그 위 계단(324~348)보다 더 위에 띄운다.
	draw_string_outline(font, Vector2(-62.0, 312.0), "E  필드로", HORIZONTAL_ALIGNMENT_CENTER, 124.0, 15, 6, Color(0.03, 0.05, 0.09, 0.92))
	draw_string(font, Vector2(-62.0, 312.0), "E  필드로", HORIZONTAL_ALIGNMENT_CENTER, 124.0, 15, GamePalette.YELLOW)

## 벽기둥 한 개(폭 44 · 높이 80). 밑동만 밝게 두어 바닥과 닿는 면이 읽히게 한다.
func _draw_pillar(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-22.0, 0.0), Vector2(44.0, 80.0)), Color("353b45"), true)
	draw_rect(Rect2(at + Vector2(-16.0, 6.0), Vector2(32.0, 68.0)), GamePalette.STONE.darkened(0.30), true)
	draw_rect(Rect2(at + Vector2(-26.0, 72.0), Vector2(52.0, 12.0)), GamePalette.STONE_LIGHT.darkened(0.34), true)

## 벽걸이 깃발 한 장. 아래끝을 뾰족하게 깎아 천처럼 보이게 한다.
func _draw_banner(at: Vector2, tint: Color) -> void:
	draw_rect(Rect2(at + Vector2(-34.0, 0.0), Vector2(68.0, 10.0)), GamePalette.WOOD.darkened(0.35), true)
	draw_rect(Rect2(at + Vector2(-28.0, 10.0), Vector2(56.0, 84.0)), tint.darkened(0.45), true)
	draw_rect(Rect2(at + Vector2(-20.0, 18.0), Vector2(40.0, 62.0)), tint.darkened(0.20), true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-28.0, 94.0), at + Vector2(28.0, 94.0), at + Vector2(0.0, 118.0)
	]), tint.darkened(0.45))

## 화로. 불꽃은 **정지 도형**이다 — 이 프로젝트에는 무한 애니메이션을 두지 않는다.
func _draw_brazier(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-8.0, 6.0), Vector2(16.0, 26.0)), Color("2a2b33"), true)
	draw_rect(Rect2(at + Vector2(-20.0, 30.0), Vector2(40.0, 8.0)), Color("353b45"), true)
	draw_circle(at, 30.0, Color(GamePalette.ORANGE, 0.10))
	draw_rect(Rect2(at + Vector2(-16.0, -8.0), Vector2(32.0, 16.0)), Color("4a3a2c"), true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-10.0, -8.0), at + Vector2(10.0, -8.0), at + Vector2(0.0, -30.0)
	]), GamePalette.ORANGE)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-5.0, -8.0), at + Vector2(5.0, -8.0), at + Vector2(0.0, -21.0)
	]), GamePalette.YELLOW)

func _draw_npc(position: Vector2, service: String) -> void:
	var info := service_visual(service)
	var color: Color = info["color"]
	draw_circle(position + Vector2(0.0, 18.0), 31.0, Color(color, 0.08))
	# 스프라이트는 발밑이 +12에 오도록 올려 그린다. 그래야 바로 아래 색띠가
	# 발판처럼 보이고, 서 있는 위치(= 상호작용 판정 중심)와 어긋나지 않는다.
	var column: int = SERVICE_SPRITE_COLUMN.get(service, SERVICE_SPRITE_FALLBACK)
	draw_texture_rect_region(
		NPC_SHEET,
		Rect2(position + Vector2(-16.0, -20.0), Vector2(NPC_CELL, NPC_CELL)),
		Rect2(column * NPC_CELL, 0.0, NPC_CELL, NPC_CELL)
	)
	# 색띠는 서비스 색을 유지하는 유일한 면이라 남긴다. 스프라이트만으로는
	# 누가 무슨 상점인지 색으로 구분되지 않는다.
	draw_rect(Rect2(position + Vector2(-27.0,32.0),Vector2(54.0,4.0)),color,true)
	var font := ThemeDB.fallback_font
	# V10 시각 QA: NPC 이름표에도 출구 프롬프트와 **같은 외곽선**을 깐다.
	# 서비스 색(분홍 계약자 · 강청 밀정 · 연어색 세공사)이 연한 복숭아색 체커 바닥과
	# 명도가 비슷해 이름이 읽히지 않았다. 색은 정보(어느 상점인가)라 바꿀 수 없으므로
	# 바닥과의 대비를 외곽선으로 만든다 — 색은 그대로 두고 판독만 얻는 유일한 방법이다.
	draw_string_outline(font, position + Vector2(-75.0,-48.0), String(info["name"]),
		HORIZONTAL_ALIGNMENT_CENTER, 150.0, 16, 6, Color(0.03, 0.05, 0.09, 0.92))
	draw_string(font, position + Vector2(-75.0,-48.0), String(info["name"]), HORIZONTAL_ALIGNMENT_CENTER, 150.0, 16, color)

# =============================================================================
# 서비스 → NPC 외형 (2026-08-10: 계약자 삭제 · 대장간 장인 신설)
# =============================================================================
# 성에는 아래 네 종류 중 **2~4명**만 선다. 누가 서는지도, 몇 명이 서는지도 성 id
# 해시가 정한다(`game.gd::_castle_services()`). 좌표 셔플은 setup()이 같은 방식으로
# 처리하므로 같은 성에 다시 들어가면 같은 자리에 같은 NPC가 있다.
#
#   card_shop  딜싸이클 카드상  — 스킬 카드(드래프트 풀) + 장비
#   rune_shop  보석 세공사      — 스킬 칸에 박는 보석 3택 판매
#   forge      대장간 장인      — 카드 합성(구 카드상 하단 버튼)
#   spy        밀정             — 마왕의 보석을 훔쳐보거나 한 칸을 지운다
#
# 아래 v1 항목들은 NPC로는 더 이상 배치되지 않지만, `game.gd::_use_service()`의
# 회귀 경로(--castle-test의 npc_remove / npc_swap)와 저장 복원 호환을 위해
# 이름·색 매핑만 남겨 둔다. 지워도 게임은 돌지만 테스트 라벨이 빈칸이 된다.
static func service_visual(service: String) -> Dictionary:
	match service:
		# --- 성 NPC 4종 ---
		"card_shop": return {"name":"딜싸이클 카드상", "color":GamePalette.CYAN}
		"rune_shop": return {"name":"보석 세공사", "color":GamePalette.ORANGE}
		"forge": return {"name":"대장간 장인", "color":GamePalette.YELLOW}
		"spy": return {"name":"밀정", "color":GamePalette.BLUE}
		# --- v1 잔존(배치되지 않음 · 호출 경로만 유지) ---
		"card_fusion": return {"name":"카드 합성 장인", "color":GamePalette.MAGENTA}
		"merchant": return {"name":"약초 상인", "color":GamePalette.GREEN}
		"skill_remove": return {"name":"망각의 사제", "color":GamePalette.MAGENTA}
		"boss_remove": return {"name":"퇴마사", "color":GamePalette.BLUE}
		"skill_swap": return {"name":"운명의 직조사", "color":GamePalette.CYAN}
		"armorer": return {"name":"왕실 대장장이", "color":GamePalette.ORANGE}
		_: return {"name":"여관 주인", "color":GamePalette.TEXT}
