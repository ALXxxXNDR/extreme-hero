class_name CastleInterior
extends Node2D

const ROOM_BOUNDS := Rect2(-480.0, -295.0, 960.0, 570.0)
const EXIT_POSITION := Vector2(0.0, 245.0)

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
const SERVICE_SPRITE_COLUMN := {
	"card_shop": 0,
	"rune_shop": 1,
	"pact": 2,
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
	var positions: Array[Vector2] = [Vector2(-320.0,-95.0), Vector2(-105.0,-175.0), Vector2(105.0,-175.0), Vector2(320.0,-95.0)]
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
	return Vector2(0.0, 175.0)

func is_walkable(point: Vector2) -> bool:
	return ROOM_BOUNDS.grow(-24.0).has_point(point)

func get_nearest_interactable(point: Vector2, radius: float = 74.0) -> Dictionary:
	if point.distance_to(EXIT_POSITION) <= radius:
		return {"type":"castle_exit", "position":EXIT_POSITION}
	for npc: Dictionary in npcs:
		if point.distance_to(npc["position"]) <= radius:
			return {"type":"castle_npc", "service":npc["service"], "position":npc["position"]}
	return {}

func _draw() -> void:
	# Stone room, tiled floor and a clear doorway.
	draw_rect(ROOM_BOUNDS, Color("171b29"), true)
	for x in range(-460, 461, 40):
		for y in range(-260, 241, 40):
			# 격자 자체는 남긴다. 같은 타일만 깔면 넓은 홀이 평평해져서 이동 거리가
			# 안 읽히므로, 홀짝 칸에 거의 안 보이는 정도의 어두운 modulate만 준다.
			var alternate := ((x / 40) + (y / 40)) as int
			var tint := Color.WHITE if alternate % 2 == 0 else Color(0.92, 0.92, 0.96)
			draw_texture_rect_region(FLOOR_TILE, Rect2(x, y, 40.0, 40.0), Rect2(0.0, 0.0, 32.0, 32.0), tint)
	draw_rect(Rect2(-480.0,-295.0,960.0,34.0), GamePalette.STONE_DARK, true)
	draw_rect(Rect2(-480.0,-295.0,32.0,570.0), GamePalette.STONE_DARK, true)
	draw_rect(Rect2(448.0,-295.0,32.0,570.0), GamePalette.STONE_DARK, true)
	draw_rect(Rect2(-480.0,260.0,400.0,15.0), GamePalette.STONE_DARK, true)
	draw_rect(Rect2(80.0,260.0,400.0,15.0), GamePalette.STONE_DARK, true)
	draw_rect(Rect2(-78.0,226.0,156.0,49.0), GamePalette.WOOD, true)
	draw_rect(Rect2(-58.0,240.0,116.0,35.0), Color("131620"), true)
	draw_rect(Rect2(-125.0,-250.0,250.0,86.0), Color("402945"), true)
	draw_rect(Rect2(-105.0,-230.0,210.0,48.0), GamePalette.RED.darkened(0.3), true)
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
	draw_string_outline(font, Vector2(-62.0, 212.0), "E  필드로", HORIZONTAL_ALIGNMENT_CENTER, 124.0, 15, 6, Color(0.03, 0.05, 0.09, 0.92))
	draw_string(font, Vector2(-62.0, 212.0), "E  필드로", HORIZONTAL_ALIGNMENT_CENTER, 124.0, 15, GamePalette.YELLOW)

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
# 서비스 → NPC 외형 (W9: 6종 → v2 4종)
# =============================================================================
# v2의 성에는 아래 네 명만 선다(설계 §7.2). 배치는 setup()이 성 id 해시로
# 결정적으로 섞으므로 같은 성에 다시 들어가면 같은 자리에 같은 NPC가 있다.
#
#   card_shop  딜싸이클 카드상  — 스킬 카드(드래프트 풀) + 장비
#   rune_shop  각인 세공사      — 각인 구매 · 카드 합성(통합) · 칸 배율 강화
#   pact       계약자           — 기한을 사고판다(설계 §4.4)
#   spy        밀정             — 마왕의 각인을 훔쳐보거나 지운다
#
# 아래 v1 항목들은 NPC로는 더 이상 배치되지 않지만, `game.gd::_use_service()`의
# 회귀 경로(--castle-test의 npc_remove / npc_swap)와 저장 복원 호환을 위해
# 이름·색 매핑만 남겨 둔다. 지워도 게임은 돌지만 테스트 라벨이 빈칸이 된다.
static func service_visual(service: String) -> Dictionary:
	match service:
		# --- v2 4종 ---
		"card_shop": return {"name":"딜싸이클 카드상", "color":GamePalette.CYAN}
		"rune_shop": return {"name":"각인 세공사", "color":GamePalette.ORANGE}
		"pact": return {"name":"계약자", "color":GamePalette.MAGENTA}
		"spy": return {"name":"밀정", "color":GamePalette.BLUE}
		# --- v1 잔존(배치되지 않음 · 호출 경로만 유지) ---
		"card_fusion": return {"name":"카드 합성 장인", "color":GamePalette.MAGENTA}
		"factory_mage": return {"name":"레일 강화술사", "color":GamePalette.ORANGE}
		"merchant": return {"name":"약초 상인", "color":GamePalette.GREEN}
		"skill_remove": return {"name":"망각의 사제", "color":GamePalette.MAGENTA}
		"boss_remove": return {"name":"퇴마사", "color":GamePalette.BLUE}
		"skill_swap": return {"name":"운명의 직조사", "color":GamePalette.CYAN}
		"armorer": return {"name":"왕실 대장장이", "color":GamePalette.ORANGE}
		_: return {"name":"여관 주인", "color":GamePalette.TEXT}
