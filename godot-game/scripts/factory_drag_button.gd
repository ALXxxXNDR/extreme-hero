class_name FactoryDragButton
extends Button

signal factory_card_dropped(source: Dictionary, target: Dictionary)

const GHOST_ALPHA := 0.86
const SOURCE_DIM := Color(0.44, 0.48, 0.56, 0.45)

var drag_payload: Dictionary = {}
# X2: 집는 순간 고스트가 **"카드만"인지 "칸 전체"인지** 보여야 두 조작이 모드 없이
# 갈린다. 칸 손잡이는 자기 자신(얇은 띠)이 아니라 칸 전체를 복제해 끌고 간다.
var ghost_source: Control = null
# X2: 드래그가 시작된 순간 "여기에 놓을 수 있는가"를 판정하는 술어.
# `game.gd`가 존(rail/inventory/equipment) 규칙을 담아 넘긴다. 비어 있으면 강조하지 않는다.
var drop_hint: Callable = Callable()
# 강조를 입힐 노드(보통 카드를 감싼 칸). 없으면 자기 자신을 쓴다.
var drop_hint_host: Control = null

const DROP_OK_TINT := Color(1.0, 1.0, 1.0, 1.0)
const DROP_NO_TINT := Color(0.46, 0.49, 0.58, 0.72)

var _dragging := false
var _modulate_before_drag := Color.WHITE
var _hinting := false
var _modulate_before_hint := Color.WHITE

func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty() or not bool(drag_payload.get("has_card", false)):
		return null
	set_drag_preview(_build_drag_preview())
	# 원본 슬롯은 흐리게 비워 둬서 지금 어떤 카드를 들고 있는지 바로 보이게 합니다.
	_modulate_before_drag = modulate
	_dragging = true
	modulate = SOURCE_DIM
	return drag_payload.duplicate(true)

func _build_drag_preview() -> Control:
	# 카드 버튼을 그대로 복제해 아이콘·이름·테두리까지 같은 모습이 마우스를 따라오게 합니다.
	# `ghost_source`가 있으면 그쪽을 복제한다 — 칸 손잡이를 집으면 칸 전체가 따라온다.
	var model: Control = ghost_source if is_instance_valid(ghost_source) else self
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghost: Control = null
	var copy: Node = model.duplicate(DUPLICATE_SCRIPTS)
	if copy is Control:
		ghost = copy as Control
		ghost.set("drag_payload", {})
		ghost.focus_mode = Control.FOCUS_NONE
		ghost.custom_minimum_size = model.size
		_resync_preview_icons(model, ghost)
	else:
		if copy != null:
			copy.free()
		ghost = _fallback_preview()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	wrapper.add_child(ghost)
	ghost.size = model.size
	ghost.position = -model.size * 0.5
	return wrapper

func _resync_preview_icons(source: Node, clone: Node) -> void:
	# 아이콘 노드는 setup()으로 잡은 상태를 @export 없이 들고 있어 duplicate()로 복사되지 않습니다.
	# 원본과 복제본의 자식 순서가 같으므로 짝을 맞춰 다시 setup()을 호출해 같은 그림을 그리게 합니다.
	var source_children := source.get_children()
	var clone_children := clone.get_children()
	for index in mini(source_children.size(), clone_children.size()):
		var original := source_children[index]
		var copy := clone_children[index]
		if original is PixelSkillIcon and copy is PixelSkillIcon:
			var skill_source := original as PixelSkillIcon
			(copy as PixelSkillIcon).setup(skill_source.skill_id, skill_source.icon_color, skill_source.framed)
		elif original is GeneratedUIIcon and copy is GeneratedUIIcon:
			(copy as GeneratedUIIcon).setup((original as GeneratedUIIcon).icon_key)
		_resync_preview_icons(original, copy)

func _fallback_preview() -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(180.0, 56.0)
	var label := Label.new()
	label.text = String(drag_payload.get("name", "카드 이동"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("fff3d0"))
	preview.add_child(label)
	return preview

func _notification(what: int) -> void:
	# X2: 드롭 가능 지점 하이라이트. 드래그가 시작되는 순간 화면의 모든 드롭 후보가
	# 스스로 "나는 받을 수 있다/없다"를 밝기로 답한다 — 안내 문장 없이 규칙이 보인다.
	if what == NOTIFICATION_DRAG_BEGIN:
		if _dragging or not drop_hint.is_valid():
			return
		var data: Variant = get_viewport().gui_get_drag_data()
		if not (data is Dictionary):
			return
		var node := _hint_node()
		if node == null:
			return
		_modulate_before_hint = node.modulate
		_hinting = true
		node.modulate = DROP_OK_TINT if bool(drop_hint.call(data as Dictionary)) else DROP_NO_TINT
		return
	if what != NOTIFICATION_DRAG_END:
		return
	if _dragging:
		_dragging = false
		modulate = _modulate_before_drag
	if _hinting:
		_hinting = false
		var node := _hint_node()
		if node != null:
			node.modulate = _modulate_before_hint

func _hint_node() -> Control:
	return drop_hint_host if is_instance_valid(drop_hint_host) else self

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not drag_payload.is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		factory_card_dropped.emit((data as Dictionary).duplicate(true), drag_payload.duplicate(true))
