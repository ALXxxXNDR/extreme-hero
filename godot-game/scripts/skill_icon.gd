class_name PixelSkillIcon
extends Control

const GENERATED_SKILL_ATLAS := preload("res://art/generated/ui/skill-atlas-minimal-v2-runtime.png")
const GENERATED_ITEM_ATLAS := preload("res://art/generated/ui/item-atlas-minimal-v2-runtime.png")
const GENERATED_SKILL_INDEX := {
	"cleave":0, "rapid_slash":1, "flame_field":2, "whirlwind":3,
	"thunder":4, "meteor_blade":5, "guardian_blade":6, "moon_barrier":7,
	"dash_blade":8, "targeting":9, "time_cut":10, "blood_pact":11,
	"aura":12, "shield_bash":13, "execution":14, "recursion":15,
	"cross_cut":16, "blade_fan":17, "gravity_well":18, "lion_roar":19,
	"phantom_step":20, "sword_rain":21, "boomerang_blade":22, "battle_trance":23,
	"holy_pulse":24, "earth_splitter":25, "thrust":26, "frost_ring":27
}

# 일반 스킬 28종과 검사 전용 아이템 파츠 모두 생성형 픽셀 아틀라스를 사용합니다.
# 아이템의 앞·뒤·동시·전체 적용 범위 표시는 하단의 작은 레일 표시로 계속 구분합니다.

# 두 아틀라스(스킬 7x4, 아이템 4x4) 모두 셀마다 어두운 사각 타일(테두리 + 배경)이
# 그림과 함께 구워져 있어, 카드 위에 얹으면 아이콘마다 검은 상자가 보입니다.
# `generated_ui_icon.gd`가 HUD 아이콘에 쓴 것과 같은 런타임 제거 기법을 그대로 씁니다.
#   1) 셀 바깥 4px 링에 등장하는 색만 "타일 색"으로 본다.
#   2) 셀 테두리에서 시작해 그 색들만 타고 flood fill 해 투명 처리한다.
#      (스프라이트 내부에 같은 색이 있어도 테두리와 연결돼 있지 않으므로 남는다)
#   3) 남은 스프라이트의 경계 상자로 잘라, 그릴 때 비율을 유지해 중앙 정렬한다.
# 결과 텍스처는 셀 번호당 한 번만 계산해 정적 캐시에 담으므로, 카드가 수십 장 그려져도
# 비용은 셀당 한 번(스킬 28 + 아이템 16 = 최대 44회)만 듭니다.
const SKILL_ATLAS_COLUMNS := 7
const SKILL_ATLAS_ROWS := 4
const ITEM_ATLAS_COLUMNS := 4
const ITEM_ATLAS_ROWS := 4
const TILE_RING := 4
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

static var _skill_trimmed_cache: Dictionary = {}
static var _item_trimmed_cache: Dictionary = {}

var skill_id := ""
var icon_color := GamePalette.TEXT
var framed := true

func setup(id: String, color: Color, show_frame: bool = true) -> void:
	skill_id = id
	icon_color = color
	framed = show_frame
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	var center := size * 0.5
	var unit := minf(size.x, size.y) / 8.0
	var item := ItemLibrary.by_id(skill_id)
	if not item.is_empty():
		_draw_generated_item(bounds, _generated_item_index(item))
		if framed:
			draw_rect(bounds.grow(-1.0), icon_color, false, maxf(2.0, unit * 0.24))
		_draw_item_scope(unit, item)
		return
	if item.is_empty() and GENERATED_SKILL_INDEX.has(skill_id):
		_draw_generated_skill(bounds, int(GENERATED_SKILL_INDEX[skill_id]))
		return
	if framed:
		draw_rect(bounds, Color("0b1020f2"), true)
		draw_rect(bounds.grow(-1.0), icon_color.darkened(0.18), false, maxf(2.0, unit * 0.22))
		draw_rect(Rect2(Vector2(unit * 0.45, unit * 0.45), Vector2(unit * 0.7, unit * 0.7)), Color(icon_color, 0.55), true)
		draw_rect(Rect2(size - Vector2(unit * 1.15, unit * 1.15), Vector2(unit * 0.7, unit * 0.7)), Color(icon_color, 0.55), true)

	if not item.is_empty():
		_draw_item(center, unit, item)
		_draw_item_scope(unit, item)
		return

	match skill_id:
		"basic":
			_draw_blade(center, unit, -0.78, 5.4, 0.62, icon_color)
		"cleave":
			draw_arc(center + Vector2(-unit * 0.3, unit * 0.4), unit * 2.65, -2.35, 0.45, 18, icon_color, unit * 0.72)
			draw_arc(center, unit * 1.85, -2.2, 0.25, 14, Color.WHITE, unit * 0.25)
		"rapid_slash":
			for index in 3:
				var offset := (float(index) - 1.0) * unit * 0.95
				draw_line(center + Vector2(-unit * 2.4, unit * 1.8 + offset), center + Vector2(unit * 2.2, -unit * 1.8 + offset), icon_color.lightened(index * 0.1), unit * 0.48)
		"thrust":
			for offset in [-0.72, 0.72]:
				draw_line(center + Vector2(-unit * 2.6, unit * offset), center + Vector2(unit * 2.1, unit * offset), icon_color, unit * 0.42)
				_draw_arrow_head(center + Vector2(unit * 2.4, unit * offset), unit, icon_color)
		"whirlwind":
			for radius in [unit * 1.25, unit * 2.35]:
				draw_arc(center, radius, -2.7, 2.35, 22, icon_color, unit * 0.48)
			draw_line(center + Vector2(-unit * 2.2, -unit * 0.8), center + Vector2(-unit * 2.75, -unit * 1.7), icon_color, unit * 0.48)
		"execution":
			_draw_blade(center, unit, -0.82, 6.2, 1.25, icon_color)
			draw_line(center + Vector2(-unit * 2.0, -unit * 2.0), center + Vector2(unit * 2.0, unit * 2.0), GamePalette.RED, unit * 0.52)
		"shield_bash":
			_draw_shield(center - Vector2(unit * 0.55, 0.0), unit * 0.9, icon_color)
			for index in 2:
				draw_line(center + Vector2(unit * (0.75 + index * 0.55), -unit), center + Vector2(unit * (1.35 + index * 0.55), 0.0), Color.WHITE, unit * 0.34)
		"flame_field":
			draw_circle(center, unit * 2.45, Color(icon_color, 0.18))
			_draw_flame(center, unit, icon_color)
		"frost_ring":
			draw_arc(center, unit * 2.45, 0.0, TAU, 24, icon_color, unit * 0.42)
			for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
				draw_line(center + Vector2.from_angle(angle) * unit * 2.15, center - Vector2.from_angle(angle) * unit * 2.15, Color.WHITE, unit * 0.32)
		"thunder":
			_draw_bolt(center, unit, icon_color)
			for index in 3:
				draw_circle(center + Vector2(-unit * 2.4 + index * unit * 2.35, unit * 2.2), unit * 0.25, Color.WHITE)
		"guardian_blade":
			draw_arc(center, unit * 2.45, 0.0, TAU, 22, Color(icon_color, 0.78), unit * 0.34)
			for angle in [-0.9, 1.2, 3.2]:
				_draw_blade(center + Vector2.from_angle(angle) * unit * 2.1, unit * 0.64, angle + PI * 0.5, 3.0, 0.55, icon_color)
		"aura":
			for ring in 3:
				draw_arc(center, unit * (0.75 + ring * 0.75), 0.0, TAU, 20, Color(icon_color, 1.0 - ring * 0.23), unit * 0.32)
			draw_circle(center, unit * 0.42, Color.WHITE)
		"moon_barrier":
			_draw_hex(center, unit * 2.45, Color(icon_color, 0.28), icon_color)
			draw_arc(center + Vector2(unit * 0.22, 0.0), unit * 1.18, -PI * 0.5, PI * 0.5, 12, Color.WHITE, unit * 0.38)
		"dash_blade":
			_draw_dash(center, unit, icon_color, 2)
		"blood_pact":
			_draw_drop(center - Vector2(unit * 0.8, 0.0), unit * 0.92, icon_color)
			_draw_blade(center + Vector2(unit * 0.85, 0.0), unit * 0.72, -0.78, 4.5, 0.66, Color.WHITE)
		"targeting":
			_draw_target(center, unit, icon_color)
			_draw_blade(center, unit * 0.58, 0.0, 5.2, 0.56, Color.WHITE)
		"recursion":
			_draw_loop_arrow(center, unit, icon_color)
		"earth_splitter":
			for offset in [-0.72, 0.72]:
				var points := PackedVector2Array([center + Vector2(-unit * 2.8, unit * offset), center + Vector2(-unit * 0.9, unit * (offset - 0.55)), center + Vector2(unit * 0.2, unit * (offset + 0.45)), center + Vector2(unit * 2.8, unit * offset)])
				draw_polyline(points, icon_color, unit * 0.55)
		"holy_pulse":
			_draw_star(center, unit * 2.65, icon_color)
			draw_circle(center, unit * 0.72, Color.WHITE)
		"time_cut":
			for angle in [-0.72, 0.72]:
				draw_line(center - Vector2.from_angle(angle) * unit * 2.5, center + Vector2.from_angle(angle) * unit * 2.5, icon_color, unit * 0.48)
			draw_rect(Rect2(center - Vector2(unit * 0.45, unit * 0.45), Vector2(unit * 0.9, unit * 0.9)), Color.WHITE, true)
		"meteor_blade":
			for index in 3:
				var x := (float(index) - 1.0) * unit * 1.55
				draw_line(center + Vector2(x - unit * 0.65, -unit * 2.6), center + Vector2(x + unit * 0.45, unit * 1.3), icon_color, unit * 0.62)
				draw_circle(center + Vector2(x + unit * 0.55, unit * 2.0), unit * 0.42, GamePalette.RED)
		"cross_cut":
			for angle in [-0.76, 0.76]:
				draw_line(center - Vector2.from_angle(angle) * unit * 2.6, center + Vector2.from_angle(angle) * unit * 2.6, icon_color, unit * 0.7)
		"blade_fan":
			for index in 5:
				var angle := lerpf(-0.85, 0.85, float(index) / 4.0)
				draw_line(center + Vector2(-unit * 1.75, 0.0), center + Vector2.from_angle(angle) * unit * 2.75, icon_color, unit * 0.32)
		"gravity_well":
			for ring in 3:
				draw_arc(center, unit * (0.7 + ring * 0.72), ring * 0.8, ring * 0.8 + PI * 1.45, 15, icon_color.lightened(ring * 0.08), unit * 0.42)
			draw_circle(center, unit * 0.42, Color("080a13"))
		"lion_roar":
			for index in 3:
				draw_arc(center - Vector2(unit * 1.65, 0.0), unit * (0.9 + index * 0.75), -0.75, 0.75, 12, icon_color, unit * 0.38)
			draw_rect(Rect2(center + Vector2(-unit * 2.35, -unit * 0.55), Vector2(unit * 0.75, unit * 1.1)), Color.WHITE, true)
		"phantom_step":
			_draw_dash(center, unit, icon_color, 3)
		"sword_rain":
			for index in 4:
				var x := (float(index) - 1.5) * unit * 1.35
				_draw_blade(center + Vector2(x, (index % 2) * unit * 0.7), unit * 0.54, PI * 0.5, 4.4, 0.5, icon_color.lightened(index * 0.05))
		"boomerang_blade":
			draw_arc(center, unit * 2.15, -2.7, 1.75, 20, icon_color, unit * 0.64)
			_draw_arrow_head(center + Vector2.from_angle(1.75) * unit * 2.15, unit, Color.WHITE)
		"battle_trance":
			_draw_shield(center, unit * 0.82, icon_color)
			for angle in [-1.0, -0.35, 0.35, 1.0]:
				draw_line(center + Vector2.from_angle(angle) * unit * 1.8, center + Vector2.from_angle(angle) * unit * 2.65, Color.WHITE, unit * 0.28)
		"multithread":
			_draw_blade(center - Vector2(unit * 0.65, 0.0), unit * 0.7, -1.15, 5.4, 0.62, icon_color)
			_draw_blade(center + Vector2(unit * 0.65, 0.0), unit * 0.7, -1.15, 5.4, 0.62, icon_color.lightened(0.2))
		"firewall":
			_draw_shield(center, unit, icon_color)
		"overclock":
			_draw_flame(center, unit, icon_color)
		"cache":
			draw_circle(center, unit * 2.15, icon_color)
			draw_rect(Rect2(center + Vector2(-unit * 0.42, -unit * 2.8), Vector2(unit * 0.84, unit * 5.6)), Color("111725"), true)
			draw_rect(Rect2(center + Vector2(-unit * 2.8, -unit * 0.42), Vector2(unit * 5.6, unit * 0.84)), Color("111725"), true)
		"rollback":
			_draw_loop_arrow(center, unit, icon_color)
		"hotfix":
			_draw_star(center, unit * 2.6, icon_color)
		_:
			if skill_id in ["holy_verdict", "aegis_process", "heavens_gate", "zero_damage_oath"]:
				_draw_star(center, unit * 2.65, icon_color)
				_draw_shield(center, unit * 0.55, Color.WHITE)
			elif skill_id in ["crimson_loop", "pain_compiler", "red_moon_execution", "immortal_frenzy"]:
				_draw_drop(center, unit, icon_color)
				draw_arc(center, unit * 2.45, -2.8, 1.8, 18, Color.WHITE, unit * 0.35)
			elif skill_id in ["dragon_pierce", "echo_thrust", "sky_dragon_array", "infinite_recursion"]:
				_draw_blade(center, unit, 0.0, 6.0, 0.42, icon_color)
				_draw_loop_arrow(center, unit * 0.7, Color.WHITE)
			else:
				_draw_star(center, unit * 2.5, icon_color)

func _draw_generated_skill(bounds: Rect2, index: int) -> void:
	var trimmed := skill_tile_texture(index)
	if trimmed != null:
		_draw_contained(bounds, trimmed)
		return
	draw_texture_rect_region(GENERATED_SKILL_ATLAS, bounds, Rect2(_atlas_cell_rect(GENERATED_SKILL_ATLAS, index, SKILL_ATLAS_COLUMNS, SKILL_ATLAS_ROWS)))

func _draw_generated_item(bounds: Rect2, index: int) -> void:
	var trimmed := item_tile_texture(index)
	if trimmed != null:
		# 아이템은 하단에 적용 범위 레일이 겹쳐 그려지므로 그만큼 아래를 비워 둡니다.
		var unit := minf(size.x, size.y) / 8.0
		var inset := maxf(2.0, unit * 0.34)
		var area := Rect2(
			bounds.position + Vector2(inset, inset),
			Vector2(maxf(bounds.size.x - inset * 2.0, 1.0), maxf(bounds.size.y - inset - unit * 1.45, 1.0))
		)
		_draw_contained(area, trimmed)
		return
	draw_texture_rect_region(GENERATED_ITEM_ATLAS, bounds, Rect2(_atlas_cell_rect(GENERATED_ITEM_ATLAS, index, ITEM_ATLAS_COLUMNS, ITEM_ATLAS_ROWS)))

func _draw_contained(area: Rect2, texture: Texture2D) -> void:
	var source_size := Vector2(texture.get_size())
	var factor := minf(area.size.x / maxf(source_size.x, 1.0), area.size.y / maxf(source_size.y, 1.0))
	var target := (source_size * factor).floor()
	var origin := (area.position + (area.size - target) * 0.5).floor()
	draw_texture_rect(texture, Rect2(origin, target), false)

static func skill_tile_texture(index: int) -> ImageTexture:
	if _skill_trimmed_cache.has(index):
		return _skill_trimmed_cache[index]
	var built := _build_trimmed(GENERATED_SKILL_ATLAS, _atlas_cell_rect(GENERATED_SKILL_ATLAS, index, SKILL_ATLAS_COLUMNS, SKILL_ATLAS_ROWS))
	built = _reskin_to_element(built, index)
	_skill_trimmed_cache[index] = built
	return built

# =============================================================================
# Y4 — 아틀라스 판 색을 런타임에서 `ELEMENT_COLOR`에 다시 맞춘다
# =============================================================================
# YA가 구운 `ui-skill-icons.png`는 셀마다 **원소색 판**을 굽고 그 위에 잉크·크림
# 글리프를 얹는다(`build_assets_y.gd:_skill_cell`). 판 색은 굽는 시점의
# `ELEMENT_COLOR`, 즉 **불 주황 · 기름 보라**로 픽셀에 박혀 있다.
#
# Y4가 불을 빨강으로, 기름을 갈색으로 옮기면 같은 카드가 화면에서 두 색을 갖는다 —
# 프레임·마크·덧칠은 빨강인데 아이콘 판만 주황이다. 그러면 유저가 말한
# "속성 구별이 안 간다"를 고치는 대신 **한 카드 안에서 색이 갈리는** 새 문제를 만든다.
#
# 시트를 다시 굽는 것은 에셋 웨이브 몫이고 Y4는 `scripts/`만 소유하므로,
# **이미 있는 트리밍 파이프라인에 색 재배치 한 단계를 얹었다.** 셀당 한 번,
# 트리밍 캐시와 같은 수명이다(28셀 × 1회).
#
# 규약 셋
#   ① 표는 여기 없다. `ELEMENT_COLOR`는 여전히 `game.gd` 한 곳이고, 게임이 시작할 때
#      `set_element_palette()`로 **주입**한다. 표가 안 들어오면 이 단계는 통째로 쉰다.
#   ② 잉크 외곽선(INK)과 크림 하이라이트(CREAM)는 원소와 무관한 **공통 선화**다.
#      그 둘은 손대지 않는다 — 건드리면 28칸의 윤곽이 원소마다 달라진다.
#   ③ 변환은 HSV 상대 이동이다. 판은 `base`·`base→흰색`·`base→잉크` 세 방향의
#      그러데이션이라 색상 하나만 돌리면 명암 구조가 그대로 따라온다.
const BAKED_ELEMENT_COLOR: Dictionary = {
	"fire": GamePalette.ORANGE, "ice": GamePalette.CYAN, "thunder": GamePalette.YELLOW,
	"poison": GamePalette.GREEN, "oil": GamePalette.PURPLE,
	"strike": GamePalette.STONE_LIGHT, "psi": GamePalette.MAGENTA
}
const PLATE_INK := Color("141b1b")     # build_assets_y.gd:61 — 전 산출물 공통 외곽선
const PLATE_CREAM := GamePalette.TEXT  # build_assets_y.gd:62 — 글리프 하이라이트

static var _element_palette: Dictionary = {}
static var _cell_element_cache: Dictionary = {}

## `game.gd`가 부팅 때 자기 `ELEMENT_COLOR`를 넘긴다. 표가 바뀌면 캐시를 버린다.
static func set_element_palette(table: Dictionary) -> void:
	if _element_palette == table:
		return
	_element_palette = table.duplicate(true)
	_skill_trimmed_cache.clear()

## 셀 번호 → 그 카드의 원소. `GENERATED_SKILL_INDEX`의 역방향이고 한 번만 만든다.
static func cell_element(index: int) -> String:
	if _cell_element_cache.is_empty():
		for id_value in GENERATED_SKILL_INDEX.keys():
			var id := String(id_value)
			_cell_element_cache[int(GENERATED_SKILL_INDEX[id_value])] = \
				String(DealCardLibrary.by_id(id).get("element", ""))
	return String(_cell_element_cache.get(index, ""))

static func _reskin_to_element(texture: ImageTexture, index: int) -> ImageTexture:
	if texture == null or _element_palette.is_empty():
		return texture
	var element := cell_element(index)
	if not _element_palette.has(element) or not BAKED_ELEMENT_COLOR.has(element):
		return texture
	var baked: Color = BAKED_ELEMENT_COLOR[element]
	var target: Color = _element_palette[element]
	if baked.is_equal_approx(target):
		return texture      # 다섯 원소는 색이 그대로다 — 픽셀을 한 번도 안 읽는다
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var hue_shift := target.h - baked.h
	var sat_scale := target.s / maxf(baked.s, 0.001)
	var val_scale := target.v / maxf(baked.v, 0.001)
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if px.is_equal_approx(PLATE_INK) or px.is_equal_approx(PLATE_CREAM):
				continue
			image.set_pixel(x, y, Color.from_hsv(
				fposmod(px.h + hue_shift, 1.0),
				clampf(px.s * sat_scale, 0.0, 1.0),
				clampf(px.v * val_scale, 0.0, 1.0), px.a))
	return ImageTexture.create_from_image(image)

static func item_tile_texture(index: int) -> ImageTexture:
	if _item_trimmed_cache.has(index):
		return _item_trimmed_cache[index]
	var built := _build_trimmed(GENERATED_ITEM_ATLAS, _atlas_cell_rect(GENERATED_ITEM_ATLAS, index, ITEM_ATLAS_COLUMNS, ITEM_ATLAS_ROWS))
	_item_trimmed_cache[index] = built
	return built

static func _atlas_cell_rect(atlas: Texture2D, index: int, columns: int, rows: int) -> Rect2i:
	var column := index % columns
	var row := index / columns
	var left := floori(float(atlas.get_width() * column) / float(columns))
	var right := floori(float(atlas.get_width() * (column + 1)) / float(columns))
	var top := floori(float(atlas.get_height() * row) / float(rows))
	var bottom := floori(float(atlas.get_height() * (row + 1)) / float(rows))
	return Rect2i(left, top, right - left, bottom - top)

static func _color_key(color: Color) -> int:
	return (color.r8 << 24) | (color.g8 << 16) | (color.b8 << 8) | color.a8

static func _build_trimmed(atlas: Texture2D, cell: Rect2i) -> ImageTexture:
	if cell.size.x <= 0 or cell.size.y <= 0:
		return null
	var source := atlas.get_image()
	if source == null:
		return null
	var image := source.get_region(cell)
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return null
	var tile_colors := {}
	for y in height:
		for x in width:
			if x >= TILE_RING and y >= TILE_RING and x < width - TILE_RING and y < height - TILE_RING:
				continue
			tile_colors[_color_key(image.get_pixel(x, y))] = true
	var stripped := PackedByteArray()
	stripped.resize(width * height)
	var pending: Array[int] = []
	for y in height:
		for x in width:
			if x > 0 and y > 0 and x < width - 1 and y < height - 1:
				continue
			var seed_index := y * width + x
			if stripped[seed_index] == 1 or not tile_colors.has(_color_key(image.get_pixel(x, y))):
				continue
			stripped[seed_index] = 1
			pending.append(seed_index)
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pending.is_empty():
		var current: int = pending.pop_back()
		var current_x := current % width
		var current_y := current / width
		for step: Vector2i in steps:
			var next_x := current_x + step.x
			var next_y := current_y + step.y
			if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
				continue
			var next_index := next_y * width + next_x
			if stripped[next_index] == 1 or not tile_colors.has(_color_key(image.get_pixel(next_x, next_y))):
				continue
			stripped[next_index] = 1
			pending.append(next_index)
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in height:
		for x in width:
			if stripped[y * width + x] == 1:
				image.set_pixel(x, y, TRANSPARENT)
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return null
	var content := image.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	if content == null:
		return null
	return ImageTexture.create_from_image(content)

func _generated_item_index(item: Dictionary) -> int:
	var slot := String(item.get("slot", ""))
	var rarity := String(item.get("rarity", "common"))
	var weapon_type := String(item.get("weapon_type", ""))
	if rarity == "hero":
		if slot == "weapon": return 13 if weapon_type == "dagger" else 12
		if slot == "necklace": return 14
		if slot == "ring": return 15
		return 11
	if slot == "weapon":
		match weapon_type:
			"rapier": return 0
			"greatsword": return 1
			"dagger": return 2 if rarity != "unique" else 13
			"longsword": return 3
			"spear": return 4
			_: return 5
	if slot == "necklace": return 7 if rarity == "rare" else 6
	if slot == "ring": return 9 if rarity == "unique" else 8
	if slot == "bracelet": return 11 if rarity == "unique" else 10
	return 5

func _draw_item(center: Vector2, unit: float, item: Dictionary) -> void:
	var slot := String(item.get("slot", ""))
	var weapon_type := String(item.get("weapon_type", ""))
	match slot:
		"weapon":
			match weapon_type:
				"rapier":
					_draw_blade(center, unit, -0.82, 6.0, 0.36, icon_color)
					draw_circle(center + Vector2(-unit * 1.05, unit * 1.05), unit * 0.72, Color(icon_color, 0.32))
				"greatsword":
					_draw_blade(center, unit, -0.82, 5.8, 1.18, icon_color)
				"dagger":
					_draw_blade(center - Vector2(unit * 0.48, 0.0), unit * 0.72, -0.68, 4.7, 0.7, icon_color)
					_draw_blade(center + Vector2(unit * 0.48, 0.0), unit * 0.72, -2.46, 4.7, 0.7, icon_color.lightened(0.18))
				"spear":
					draw_line(center + Vector2(-unit * 2.8, unit * 1.7), center + Vector2(unit * 2.0, -unit * 1.25), icon_color, unit * 0.42)
					var tip := center + Vector2(unit * 2.3, -unit * 1.45)
					draw_colored_polygon(PackedVector2Array([tip + Vector2(unit * 0.7, -unit * 0.45), tip + Vector2(-unit * 0.25, -unit * 0.05), tip + Vector2(unit * 0.15, unit * 0.7)]), Color.WHITE)
				_:
					_draw_blade(center, unit, -PI * 0.5, 5.7, 0.72, icon_color)
		"necklace":
			draw_arc(center + Vector2(0.0, -unit * 0.65), unit * 2.15, 0.15, PI - 0.15, 18, icon_color, unit * 0.42)
			var gem := PackedVector2Array([center + Vector2(0.0, -unit * 0.15), center + Vector2(unit * 0.95, unit * 0.9), center + Vector2(0.0, unit * 2.25), center + Vector2(-unit * 0.95, unit * 0.9)])
			draw_colored_polygon(gem, icon_color)
			draw_polyline(PackedVector2Array(Array(gem) + [gem[0]]), Color.WHITE, unit * 0.25)
		"ring":
			draw_arc(center + Vector2(0.0, unit * 0.55), unit * 1.72, 0.0, TAU, 22, icon_color, unit * 0.72)
			var stone := PackedVector2Array([center + Vector2(0.0, -unit * 2.35), center + Vector2(unit * 1.0, -unit * 1.15), center + Vector2(0.0, -unit * 0.35), center + Vector2(-unit * 1.0, -unit * 1.15)])
			draw_colored_polygon(stone, Color.WHITE)
		"bracelet":
			draw_arc(center, unit * 2.05, -2.72, 2.72, 20, icon_color, unit * 0.82)
			for angle in [-2.3, -1.25, -0.2, 0.85, 1.9]:
				draw_rect(Rect2(center + Vector2.from_angle(angle) * unit * 2.05 - Vector2(unit * 0.3, unit * 0.3), Vector2(unit * 0.6, unit * 0.6)), Color.WHITE, true)
		_:
			_draw_star(center, unit * 2.4, icon_color)

	# 같은 파츠 안에서도 각 아이템이 달라 보이도록 ID 기반 픽셀 각인을 더합니다.
	var seed := absi(skill_id.hash())
	for index in 3:
		var x := -1.45 + float((seed >> (index * 3)) & 3) * 0.95
		var y := 1.65 + float(index % 2) * 0.52
		draw_rect(Rect2(center + Vector2(x, y) * unit - Vector2(unit * 0.18, unit * 0.18), Vector2(unit * 0.36, unit * 0.36)), Color.WHITE, true)

func _draw_item_scope(unit: float, item: Dictionary) -> void:
	var effects: Dictionary = item.get("effects", {})
	var y := size.y - unit * 0.82
	var cell := unit * 0.45
	var positions := [size.x * 0.5 - unit * 0.85, size.x * 0.5, size.x * 0.5 + unit * 0.85]
	var previous_on := _has_effect_suffix(effects, "_previous") or _has_effect_suffix(effects, "_adjacent")
	var paired_on := _has_effect_suffix(effects, "_paired")
	var next_on := _has_effect_suffix(effects, "_next") or _has_effect_suffix(effects, "_adjacent")
	var states := [previous_on, paired_on, next_on]
	for index in 3:
		var color := Color.WHITE if states[index] else Color(icon_color, 0.22)
		draw_rect(Rect2(Vector2(positions[index] - cell * 0.5, y - cell * 0.5), Vector2(cell, cell)), color, true)
	if _has_effect_suffix(effects, "_all") or effects.has("move_speed") or effects.has("dash_reload") or effects.has("heal_cycle"):
		draw_arc(Vector2(size.x * 0.5, y), unit * 1.75, PI, TAU, 12, icon_color, unit * 0.18)

func _has_effect_suffix(effects: Dictionary, suffix: String) -> bool:
	for key in effects.keys():
		if String(key).ends_with(suffix):
			return true
	return false

func _draw_blade(center: Vector2, unit: float, angle: float, length: float, width: float, color: Color) -> void:
	var direction := Vector2.from_angle(angle)
	var normal := direction.orthogonal()
	var start := center - direction * unit * length * 0.38
	var finish := center + direction * unit * length * 0.48
	draw_line(start, finish, color, maxf(2.0, unit * width))
	draw_line(start - normal * unit * 0.72, start + normal * unit * 0.72, Color.WHITE, maxf(2.0, unit * 0.28))
	draw_rect(Rect2(start - direction * unit * 0.65 - Vector2(unit * 0.22, unit * 0.22), Vector2(unit * 0.44, unit * 0.44)), color.darkened(0.28), true)

func _draw_arrow_head(point: Vector2, unit: float, color: Color) -> void:
	var head := PackedVector2Array([point + Vector2(unit * 0.72, 0.0), point + Vector2(-unit * 0.35, -unit * 0.6), point + Vector2(-unit * 0.35, unit * 0.6)])
	draw_colored_polygon(head, color)

func _draw_shield(center: Vector2, unit: float, color: Color) -> void:
	var shield := PackedVector2Array([
		center + Vector2(0.0, -unit * 2.4), center + Vector2(unit * 1.9, -unit * 1.1),
		center + Vector2(unit * 1.45, unit * 1.35), center + Vector2(0.0, unit * 2.5),
		center + Vector2(-unit * 1.45, unit * 1.35), center + Vector2(-unit * 1.9, -unit * 1.1)
	])
	draw_colored_polygon(shield, Color(color, 0.38))
	draw_polyline(PackedVector2Array(Array(shield) + [shield[0]]), color, maxf(2.0, unit * 0.42))

func _draw_flame(center: Vector2, unit: float, color: Color) -> void:
	var flame := PackedVector2Array([
		center + Vector2(0.0, -unit * 2.75), center + Vector2(unit * 1.8, -unit * 0.15),
		center + Vector2(unit, unit * 2.2), center + Vector2(0.0, unit * 2.75),
		center + Vector2(-unit * 1.7, unit), center + Vector2(-unit * 1.15, -unit)
	])
	draw_colored_polygon(flame, color)
	draw_rect(Rect2(center + Vector2(-unit * 0.42, unit * 0.25), Vector2(unit * 0.84, unit * 1.4)), Color.WHITE, true)

func _draw_bolt(center: Vector2, unit: float, color: Color) -> void:
	var bolt := PackedVector2Array([
		center + Vector2(unit * 0.3, -unit * 2.8), center + Vector2(-unit * 1.35, unit * 0.05),
		center + Vector2(-unit * 0.1, unit * 0.05), center + Vector2(-unit * 0.7, unit * 2.8),
		center + Vector2(unit * 1.7, -unit * 0.5), center + Vector2(unit * 0.4, -unit * 0.5)
	])
	draw_colored_polygon(bolt, color)

func _draw_hex(center: Vector2, radius: float, fill: Color, line: Color) -> void:
	var points := PackedVector2Array()
	for index in 6:
		points.append(center + Vector2.from_angle(TAU * float(index) / 6.0) * radius)
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array(Array(points) + [points[0]]), line, maxf(2.0, radius * 0.13))

func _draw_drop(center: Vector2, unit: float, color: Color) -> void:
	var drop := PackedVector2Array([
		center + Vector2(0.0, -unit * 2.8), center + Vector2(unit * 1.95, unit * 0.75),
		center + Vector2(unit, unit * 2.35), center + Vector2(-unit, unit * 2.35),
		center + Vector2(-unit * 1.95, unit * 0.75)
	])
	draw_colored_polygon(drop, color)

func _draw_target(center: Vector2, unit: float, color: Color) -> void:
	draw_circle(center, unit * 1.72, Color(color, 0.2))
	draw_arc(center, unit * 1.72, 0.0, TAU, 18, color, unit * 0.38)
	draw_line(center + Vector2(-unit * 2.8, 0.0), center + Vector2(unit * 2.8, 0.0), color, unit * 0.3)
	draw_line(center + Vector2(0.0, -unit * 2.8), center + Vector2(0.0, unit * 2.8), color, unit * 0.3)

func _draw_loop_arrow(center: Vector2, unit: float, color: Color) -> void:
	draw_arc(center, unit * 2.05, -2.72, 2.15, 18, color, unit * 0.58)
	var point := center + Vector2.from_angle(2.15) * unit * 2.05
	var head := PackedVector2Array([point, point + Vector2(-unit * 0.15, -unit * 1.25), point + Vector2(-unit * 1.1, -unit * 0.35)])
	draw_colored_polygon(head, color)

func _draw_dash(center: Vector2, unit: float, color: Color, copies: int) -> void:
	for index in copies:
		var y := (float(index) - float(copies - 1) * 0.5) * unit * 1.15
		draw_line(center + Vector2(-unit * 2.65, y), center + Vector2(unit * 1.45, y), Color(color, 0.58 + index * 0.14), unit * 0.38)
	_draw_arrow_head(center + Vector2(unit * 1.8, 0.0), unit, Color.WHITE)

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 8:
		var current_radius := radius if index % 2 == 0 else radius * 0.38
		points.append(center + Vector2.from_angle(-PI / 2.0 + TAU * float(index) / 8.0) * current_radius)
	draw_colored_polygon(points, color)
