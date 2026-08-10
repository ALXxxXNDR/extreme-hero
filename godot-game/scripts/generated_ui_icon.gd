class_name GeneratedUIIcon
extends Control

const ATLAS := preload("res://art/generated/ui/factory-hud-atlas-minimal-v2-runtime.png")
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 2
const ICON_INDEX := {
	"slot_empty": 0,
	"slot_active": 1,
	"bridge": 2,
	"split": 3,
	"gold": 4,
	"duration": 5,
	"reload": 6,
	"xp": 7
}

# 아틀라스 셀에는 어두운 사각 프레임(테두리 + 배경)이 그림과 함께 구워져 있습니다.
# 3차 피드백⑫ "박스 형태도 제거하고 에셋만 자연스럽게 붙도록" 요구에 따라
# 새 이미지 파일을 만들지 않고 런타임에서 프레임을 벗겨 씁니다.
#   1) 셀 바깥 4px 링에 등장하는 색만 "프레임 색"으로 본다.
#   2) 셀 테두리에서 그 색들만 타고 flood fill 해 투명 처리한다.
#      (스프라이트 내부에 같은 색이 있어도 프레임과 연결돼 있지 않으므로 남는다)
#   3) 남은 스프라이트의 경계 상자로 잘라, 그릴 때 비율을 유지해 중앙 정렬한다.
# 결과는 아이콘 종류당 한 번만 계산해 정적 캐시에 담습니다.
const FRAME_RING := 4
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

static var _trimmed_cache: Dictionary = {}

var icon_key := "gold"
var trim_frame := true

func setup(key: String, trim: bool = true) -> void:
	icon_key = key
	trim_frame = trim
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var index := int(ICON_INDEX.get(icon_key, 4))
	if trim_frame:
		var trimmed := trimmed_texture(index)
		if trimmed != null:
			var source_size := Vector2(trimmed.get_size())
			var factor := minf(size.x / maxf(source_size.x, 1.0), size.y / maxf(source_size.y, 1.0))
			var target := (source_size * factor).floor()
			var origin := ((size - target) * 0.5).floor()
			draw_texture_rect(trimmed, Rect2(origin, target), false)
			return
	draw_texture_rect_region(ATLAS, Rect2(Vector2.ZERO, size), Rect2(_cell_rect(index)))

static func _cell_rect(index: int) -> Rect2i:
	var column := index % ATLAS_COLUMNS
	var row := index / ATLAS_COLUMNS
	var left := floori(float(ATLAS.get_width() * column) / float(ATLAS_COLUMNS))
	var right := floori(float(ATLAS.get_width() * (column + 1)) / float(ATLAS_COLUMNS))
	var top := floori(float(ATLAS.get_height() * row) / float(ATLAS_ROWS))
	var bottom := floori(float(ATLAS.get_height() * (row + 1)) / float(ATLAS_ROWS))
	return Rect2i(left, top, right - left, bottom - top)

static func trimmed_texture(index: int) -> ImageTexture:
	if _trimmed_cache.has(index):
		return _trimmed_cache[index]
	var built: ImageTexture = null
	var atlas_image := ATLAS.get_image()
	if atlas_image != null:
		built = _build_trimmed(atlas_image, index)
	_trimmed_cache[index] = built
	return built

static func _color_key(color: Color) -> int:
	return (color.r8 << 24) | (color.g8 << 16) | (color.b8 << 8) | color.a8

static func _build_trimmed(source: Image, index: int) -> ImageTexture:
	var cell := _cell_rect(index)
	if cell.size.x <= 0 or cell.size.y <= 0:
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
	var frame_colors := {}
	for y in height:
		for x in width:
			if x >= FRAME_RING and y >= FRAME_RING and x < width - FRAME_RING and y < height - FRAME_RING:
				continue
			frame_colors[_color_key(image.get_pixel(x, y))] = true
	var stripped := PackedByteArray()
	stripped.resize(width * height)
	var pending: Array[int] = []
	for y in height:
		for x in width:
			if x > 0 and y > 0 and x < width - 1 and y < height - 1:
				continue
			var seed_index := y * width + x
			if stripped[seed_index] == 1 or not frame_colors.has(_color_key(image.get_pixel(x, y))):
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
			if stripped[next_index] == 1 or not frame_colors.has(_color_key(image.get_pixel(next_x, next_y))):
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
