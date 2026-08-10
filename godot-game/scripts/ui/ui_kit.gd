class_name UIKit
extends RefCounted
# =============================================================================
# U0 — UI 재스킨 킷 헬퍼 (Ninja Adventure 테마)
# =============================================================================
# `art/v2/build_assets_ui.gd`가 구운 10장의 아틀라스를 Godot 리소스로 바꿔 주는
# **정적 함수 모음**이다. 상태를 갖지 않고, 노드를 만들지 않고(예외: 스포트라이트
# 조립기 2개), 기존 화면에 아무것도 배선하지 않는다.
#
# 규격의 단일 진실 원천은 `docs/ui-style-v3.md`다. 이 파일은 그 문서의 표를
# 코드로 옮긴 것이고, 둘이 어긋나면 **문서가 맞다**.
#
# U1~U3 사용 규칙 3가지
#   1. `StyleBoxFlat`을 새로 만들지 말 것. 패널·버튼·카드·리본은 전부 여기서 온다.
#   2. 색을 직접 쓰지 말 것. 글자색은 `text_color()`·`muted_color()`·
#      `heading_color()`, 강조는 `accent_color()`에서 가져온다.
#   3. **트윈 루프 금지.** 1회성 전환만 허용한다(AGENTS.md §3-9). 이 파일은
#      트윈을 하나도 만들지 않는다 — 상태 변화는 전부 스타일박스 교체다.
# =============================================================================

# --------------------------------------------------------------------- 아틀라스
const TEX_PANELS := preload("res://art/v2/ui-kit-panels.png")
const TEX_BUTTONS := preload("res://art/v2/ui-kit-buttons.png")
const TEX_CARDS := preload("res://art/v2/ui-kit-cards.png")
const TEX_RIBBON := preload("res://art/v2/ui-kit-ribbon.png")
const TEX_KEYCAPS := preload("res://art/v2/ui-kit-keycaps.png")
const TEX_POINTERS := preload("res://art/v2/ui-kit-pointers.png")
const TEX_GLYPHS := preload("res://art/v2/ui-kit-glyphs.png")
const TEX_BARS := preload("res://art/v2/ui-kit-bars.png")
const TEX_SPOTLIGHT_RECT := preload("res://art/v2/ui-kit-spotlight-rect.png")
const TEX_SPOTLIGHT_OVAL := preload("res://art/v2/ui-kit-spotlight-oval.png")

# ------------------------------------------------------------------- 격자 규격
# 전부 **구운 뒤** 픽셀값이다(원본 ×2). 문서 §1 표와 1:1.
const PANEL_CELL := 32
const PANEL_MARGIN := 10
const CARD_CELL := 48
const CARD_MARGIN := 16
const RIBBON_W := 48
const RIBBON_H := 40            # FONT_TITLE(26)이 들어가는 최소 높이
const RIBBON_MARGIN_H := 16     # 좌·우
const RIBBON_MARGIN_V := 18     # 위·아래 (대칭)
const KEYCAP_W := 72
const KEYCAP_H := 40
const KEYCAP_COLUMNS := 5
const GLYPH_CELL := 32
const GLYPH_COLUMNS := 8
const POINTER_COLUMNS := 8
const BAR_CELL := 16
const BAR_MARGIN := 4
const SPOTLIGHT_MARGIN := 32    # ui-kit-spotlight-rect.png의 9-slice 여백

# ------------------------------------------------------------------- 타이포 5단
# 기존 `game.gd` UI_*_SIZE와 **값이 같다.** 재스킨은 정보 구조를 안 바꾼다.
const FONT_TITLE := 26
const FONT_HEADING := 17
const FONT_BODY := 13
const FONT_LABEL := 12
const FONT_CAPTION := 11

# --------------------------------------------------------------------- 열거형
# 값 = 아틀라스 열/행 인덱스. 순서를 바꾸면 그림이 어긋난다.
enum Tone { PARCHMENT, GOLD, WOOD, VERDANT, SLATE, ABYSS, EMBER }
enum Role { PANEL, INSET, CHIP, CELL, FOCUS }
enum Btn { PRIMARY, NEUTRAL, DANGER, QUIET }
enum BtnState { NORMAL, HOVER, PRESSED, DISABLED }
enum Card { SKILL, ITEM, RUNE, TROPHY, BOSS }
enum CardState { NORMAL, SELECTED, DISABLED }
# 리본은 별도 열거형을 두지 않는다 — `Tone`과 열 순서가 같다. 다른 순서를 쓰면
# int enum이라 타입 오류 없이 조용히 다른 색이 나온다.
enum RibbonShape { PLAQUE, NOTCHED }
enum Bar { TRACK_DARK, TRACK_LIGHT, FILL, FILL_GLOSS }

# ------------------------------------------------------------------- 글자색표
# 잉크는 두 개뿐이다. NA 팔레트 (8,0)과 (4,7).
const INK_DARK := Color("141b1b")
const INK_LIGHT := Color("f2eaf1")
const MUTED_ALPHA := 0.78

# **잉크 극성은 톤이 아니라 (톤, 역할) 쌍이 정한다.** 밝은 톤도 칩 층에서는
# 중간 갈색이 되어 어두운 잉크가 무너진다 — wood 칩 `#7d5837` 위의 `#141b1b`는
# 2.76:1이고, 흰 잉크로 뒤집으면 5.36:1이 된다. 아래 표는 **구운 아틀라스의 실제
# 픽셀에서 대비를 계산해** 이긴 잉크를 적은 것이다(true = 밝은 잉크).
# 톤 램프를 바꾸면 이 표도 다시 계산해야 한다.
# 행 = Tone, 열 = Role(PANEL INSET CHIP CELL FOCUS)
const _INK_LIGHT_ON: Array = [
	[false, false, false, false, false],   # PARCHMENT
	[false, false, false, false, false],   # GOLD
	[false, false, true,  false, false],   # WOOD    — 칩에서 뒤집힌다
	[false, false, true,  false, false],   # VERDANT — 칩에서 뒤집힌다
	[true,  true,  true,  true,  true ],   # SLATE
	[true,  true,  true,  true,  true ],   # ABYSS
	[false, true,  true,  false, false],   # EMBER   — 함몰부터 뒤집힌다
]
# 아래 두 표와 `muted_color()`는 전부 **대비 실측**으로 정했다. 톤 바탕색 대비
# 3:1을 못 넘기면 캡처에서 글자가 뭉개져 읽히지 않는다.
#
# `_MUTED` 색표는 없앴다. 톤별로 손으로 고른 부가색은 **패널 층에서만** 맞았고
# 칩 층(`well2`)에서 무너졌다 — parchment 칩은 중간 갈색(#b6806c)이라 밝은 톤인데도
# 잉크 극성이 뒤집힌다. `695953` 부가색이 거기서 1.99:1까지 떨어졌다(실측).
# 지금은 `muted_color()`가 **본문색의 알파 0.68**을 준다. 어느 층 위에 얹혀도
# 극성이 맞고 항상 3.9:1 이상이 나온다(패널·함몰·칩 21조합 전수 확인).
# 제목. wood/verdant는 흰색이 아니라 **어두운 잉크**다 — `f2eaf1`을 주황(#f38c4c)
# 위에 얹으면 2.06:1이라 모달 제목이 읽히지 않았다(실측).
# 제목·강조는 **패널 층 전용**이다. 함몰·칩 층에는 얹지 말 것(대비가 안 나온다).
const _HEADING: Array[Color] = [
	Color("965340"), Color("965340"), Color("46402e"), Color("141b1b"),
	Color("ffe18d"), Color("d3a2c0"), Color("ffe18d"),
]
# 강조. **그 톤 위의 글자로 쓸 수 있는 색**만 넣는다. 게이지 채움처럼 정보를
# 나르는 색은 여기가 아니라 `GamePalette`에서 가져온다.
const _ACCENT: Array[Color] = [
	Color("d14b34"), Color("965340"), Color("543c52"), Color("3b3643"),
	Color("71ddee"), Color("d3a2c0"), Color("ffe18d"),
]

# 본문 여백(패딩). 9-slice 테두리 10px를 **포함한** 값이다.
const _CONTENT_MARGIN := {
	Role.PANEL: Vector2(18, 14),
	Role.INSET: Vector2(14, 10),
	Role.CHIP: Vector2(12, 8),
	Role.CELL: Vector2(12, 12),
	Role.FOCUS: Vector2(0, 0),
}

# 스포트라이트 스크림 색. 마스크 바깥쪽 픽셀과 **정확히 같아야** 이음매가 안 보인다.
const SPOTLIGHT_INK := Color(0.02, 0.02, 0.05, 1.0)

# 스타일박스·아틀라스는 **한 벌만 만들어 돌려 쓴다.** 138개 리소스가 화면 수십
# 개에서 공유되므로 메모리와 임포트 비용이 상수다. 대신 **받은 리소스를 고치면
# 다른 화면까지 같이 바뀐다.** 한 곳에서만 다르게 쓰고 싶으면 `variant()`로
# 복제본을 뜰 것.
static var _cache: Dictionary = {}

# 공유 리소스를 고쳐야 할 때. 복제본은 캐시에 안 들어가므로 마음대로 고쳐도 된다.
#   var wide := UIKit.variant(UIKit.panel_box(UIKit.Tone.SLATE))
#   wide.content_margin_left = 40
static func variant(box: StyleBox) -> StyleBox:
	return box.duplicate() as StyleBox

# =============================================================================
# 1. 패널 · 버튼 · 카드 · 리본 (StyleBoxTexture)
# =============================================================================
static func panel_box(tone: Tone, role: Role = Role.PANEL) -> StyleBoxTexture:
	return _box("p%d_%d" % [tone, role], TEX_PANELS,
		Rect2(int(tone) * PANEL_CELL, int(role) * PANEL_CELL, PANEL_CELL, PANEL_CELL),
		PANEL_MARGIN, PANEL_MARGIN, PANEL_MARGIN, PANEL_MARGIN,
		_CONTENT_MARGIN[role])

static func button_box(variant: Btn, state: BtnState) -> StyleBoxTexture:
	return _box("b%d_%d" % [variant, state], TEX_BUTTONS,
		Rect2(int(variant) * PANEL_CELL, int(state) * PANEL_CELL, PANEL_CELL, PANEL_CELL),
		PANEL_MARGIN, PANEL_MARGIN, PANEL_MARGIN, PANEL_MARGIN,
		Vector2(20, 10))

static func card_box(kind: Card, state: CardState = CardState.NORMAL) -> StyleBoxTexture:
	return _box("c%d_%d" % [kind, state], TEX_CARDS,
		Rect2(int(kind) * CARD_CELL, int(state) * CARD_CELL, CARD_CELL, CARD_CELL),
		CARD_MARGIN, CARD_MARGIN, CARD_MARGIN, CARD_MARGIN,
		Vector2(22, 18))

static func ribbon_box(tone: Tone, shape: RibbonShape = RibbonShape.PLAQUE) -> StyleBoxTexture:
	return _box("r%d_%d" % [tone, shape], TEX_RIBBON,
		Rect2(int(tone) * RIBBON_W, int(shape) * RIBBON_H, RIBBON_W, RIBBON_H),
		RIBBON_MARGIN_H, RIBBON_MARGIN_V, RIBBON_MARGIN_H, RIBBON_MARGIN_V,
		Vector2(24, 6))

# 포커스 링. 어느 톤을 넘겨도 흰 링이 나온다(접근성 — 포커스는 항상 같은 그림).
static func focus_box(tone: Tone = Tone.SLATE) -> StyleBoxTexture:
	return panel_box(tone, Role.FOCUS)

static func bar_box(kind: Bar) -> StyleBoxTexture:
	return _box("g%d" % int(kind), TEX_BARS,
		Rect2(int(kind) * BAR_CELL, 0, BAR_CELL, BAR_CELL),
		BAR_MARGIN, BAR_MARGIN, BAR_MARGIN, BAR_MARGIN,
		Vector2(BAR_MARGIN, BAR_MARGIN))

static func _box(key: String, tex: Texture2D, region: Rect2,
		ml: int, mt: int, mr: int, mb: int, content: Vector2) -> StyleBoxTexture:
	if _cache.has(key):
		return _cache[key]
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.region_rect = region
	box.texture_margin_left = ml
	box.texture_margin_top = mt
	box.texture_margin_right = mr
	box.texture_margin_bottom = mb
	box.content_margin_left = content.x
	box.content_margin_right = content.x
	box.content_margin_top = content.y
	box.content_margin_bottom = content.y
	_cache[key] = box
	return box

# =============================================================================
# 2. 스프라이트 (AtlasTexture)
# =============================================================================
# 키캡. `key`는 build_assets_ui.gd의 KEYCAP_KEYS 첫 열과 같은 문자열이다.
# 없는 키를 부르면 null을 준다 — 호출부가 텍스트 폴백을 고르게 하려는 것이다.
const KEYCAP_INDEX := {
	"w": 0, "a": 1, "s": 2, "d": 3, "e": 4,
	"q": 5, "r": 6, "f": 7, "i": 8, "m": 9,
	"1": 10, "2": 11, "3": 12, "4": 13, "5": 14,
	"up": 15, "down": 16, "left": 17, "right": 18, "esc": 19,
	"space": 20, "enter": 21, "tab": 22, "shift": 23, "mouse_left": 24,
	"mouse_right": 25,
}

static func keycap(key: String) -> AtlasTexture:
	var lower := key.to_lower()
	if not KEYCAP_INDEX.has(lower):
		return null
	var i: int = KEYCAP_INDEX[lower]
	return _atlas("k" + lower, TEX_KEYCAPS, Rect2(
		(i % KEYCAP_COLUMNS) * KEYCAP_W, (i / KEYCAP_COLUMNS) * KEYCAP_H,
		KEYCAP_W, KEYCAP_H))

const GLYPH_INDEX := {
	"check": 0, "cross": 1, "plus": 2, "minus": 3,
	"star": 4, "diamond": 5, "warn": 6, "info": 7,
	"coin": 8, "key": 9, "gem": 10, "hourglass": 11,
	"scroll": 12, "book": 13, "heart": 14, "bag": 15,
}

static func glyph(name: String) -> AtlasTexture:
	if not GLYPH_INDEX.has(name):
		return null
	var i: int = GLYPH_INDEX[name]
	return _atlas("y" + name, TEX_GLYPHS, Rect2(
		(i % GLYPH_COLUMNS) * GLYPH_CELL, (i / GLYPH_COLUMNS) * GLYPH_CELL,
		GLYPH_CELL, GLYPH_CELL))

const POINTER_INDEX := {
	"chevron_left": 0, "chevron_right": 1, "chevron_up": 2, "chevron_down": 3,
	"pointer_left": 4, "pointer_right": 5, "pointer_up": 6, "pointer_down": 7,
	"needle": 8, "caret": 9, "bullet": 10, "close": 11,
	"double_left": 12, "double_right": 13, "ellipsis": 14, "grip": 15,
}

static func pointer(name: String) -> AtlasTexture:
	if not POINTER_INDEX.has(name):
		return null
	var i: int = POINTER_INDEX[name]
	return _atlas("t" + name, TEX_POINTERS, Rect2(
		(i % POINTER_COLUMNS) * GLYPH_CELL, (i / POINTER_COLUMNS) * GLYPH_CELL,
		GLYPH_CELL, GLYPH_CELL))

static func _atlas(key: String, tex: Texture2D, region: Rect2) -> AtlasTexture:
	if _cache.has(key):
		return _cache[key]
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	at.filter_clip = true
	_cache[key] = at
	return at

# =============================================================================
# 3. 색
# =============================================================================
# 본문 글자색. 글자를 **어느 층에 얹는지**까지 넘기면 극성이 자동으로 맞는다.
static func text_on(tone: Tone, role: Role = Role.PANEL) -> Color:
	return INK_LIGHT if _INK_LIGHT_ON[int(tone)][int(role)] else INK_DARK

# 부가 글자색 = 본문색의 알파 0.78. 색표가 아니라 알파인 이유 — 톤별로 손으로
# 고른 부가색은 패널 층에서만 맞고 칩 층에서 무너졌다(parchment 칩 위 1.99:1).
# 알파로 두면 어느 층에서도 3.1:1 아래로 안 간다(21조합 전수 확인).
static func muted_on(tone: Tone, role: Role = Role.PANEL) -> Color:
	var c := text_on(tone, role)
	return Color(c.r, c.g, c.b, MUTED_ALPHA)

static func text_color(tone: Tone) -> Color: return text_on(tone, Role.PANEL)
static func muted_color(tone: Tone) -> Color: return muted_on(tone, Role.PANEL)
static func heading_color(tone: Tone) -> Color: return _HEADING[int(tone)]
static func accent_color(tone: Tone) -> Color: return _ACCENT[int(tone)]

# 이 층의 글자가 밝은 잉크인가? true면 검은 외곽선이 의미를 갖는다.
static func is_dark_tone(tone: Tone, role: Role = Role.PANEL) -> bool:
	return _INK_LIGHT_ON[int(tone)][int(role)]

# 라벨 외곽선. 밝은 잉크에만 두른다 — 어두운 잉크에 검은 헤일로를 두르면
# 글자가 굵어지기만 하고 대비는 안 올라간다.
static func outline_color(tone: Tone, role: Role = Role.PANEL) -> Color:
	return Color(0, 0, 0, 0.88) if is_dark_tone(tone, role) else Color(0, 0, 0, 0)

# 한글은 11~13px에서 획 사이가 1px밖에 안 된다. 기존 `_label()`의 3/4px 외곽선을
# 그대로 쓰면 버튼·잉걸·독 같은 글자의 속공간이 메워져 덩어리로 보인다(실측).
# 2/3px로 낮췄다 — 필드 위 가독성은 유지되고 획은 안 뭉갠다.
static func outline_size(tone: Tone, font_size: int, role: Role = Role.PANEL) -> int:
	if not is_dark_tone(tone, role):
		return 0
	return 2 if font_size <= FONT_BODY else 3

# =============================================================================
# 4. 조립기 — 있는 노드에 스타일만 입힌다(노드를 새로 만들지 않는다)
# =============================================================================
# 버튼 5상태 + 글자색 + 폰트 크기를 한 번에 입힌다. U1~U3는 버튼을 만든 뒤
# 이 함수만 부르면 된다. 반환값 없음 — 부작용 함수임을 이름과 시그니처로 못 박는다.
static func style_button(button: Button, variant: Btn = Btn.PRIMARY,
		font_size: int = FONT_HEADING) -> void:
	button.add_theme_stylebox_override("normal", button_box(variant, BtnState.NORMAL))
	button.add_theme_stylebox_override("hover", button_box(variant, BtnState.HOVER))
	button.add_theme_stylebox_override("pressed", button_box(variant, BtnState.PRESSED))
	button.add_theme_stylebox_override("disabled", button_box(variant, BtnState.DISABLED))
	button.add_theme_stylebox_override("focus", focus_box())
	var tone := _button_tone(variant)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text_color(tone))
	button.add_theme_color_override("font_hover_color", text_color(tone))
	button.add_theme_color_override("font_pressed_color", text_color(tone))
	button.add_theme_color_override("font_focus_color", text_color(tone))
	# 비활성 글자는 **비활성 바탕의 극성**을 따른다. 채도가 빠지면 톤 대부분이
	# 밝은 회색이 되지만 slate/abyss만 여전히 어둡다 — 톤 극성을 그대로 쓰면
	# 회색 위 어두운 글자(1.46:1)가 나온다(실측). 알파 0.62로 죽여 비활성임을
	# 알리되 2.8~4.5:1은 유지한다.
	var dis_ink := INK_LIGHT if (tone == Tone.SLATE or tone == Tone.ABYSS) else INK_DARK
	button.add_theme_color_override("font_disabled_color",
		Color(dis_ink.r, dis_ink.g, dis_ink.b, 0.62))
	# **버튼 라벨에는 외곽선을 두르지 않는다.** 버튼은 언제나 불투명한 9-slice 위에
	# 앉으므로 헤일로가 필요 없고, Godot `Button`은 `outline_size`가 상태별이 아니라
	# 하나뿐이다 — 켜 두면 어두운 잉크인 disabled 라벨이 "어두운 글자 + 검은 3px
	# 헤일로"가 되어 **활성 버튼보다 굵게** 읽힌다(어포던스 역전. 실측: 삭제 라벨
	# 진픽셀 262 vs 활성 77~150). 외곽선 없이도 4변종 전부 3.7:1 이상이다.
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	button.add_theme_constant_override("outline_size", 0)

static func _button_tone(variant: Btn) -> Tone:
	match variant:
		Btn.PRIMARY: return Tone.WOOD
		Btn.NEUTRAL: return Tone.SLATE
		Btn.DANGER: return Tone.EMBER
		_: return Tone.GOLD

# 라벨 한 줄. 톤에 맞는 색·외곽선을 자동으로 고른다.
# `outline`을 false로 주면 외곽선을 끈다. 불투명한 어두운 패널 안에서는
# 검은 외곽선이 배경과 구분이 안 돼 획만 두꺼워진다(abyss 칩이 특히 그렇다).
# 필드 위에 직접 얹히는 글자에서만 기본값(true)을 그대로 둘 것.
static func style_label(label: Label, tone: Tone, font_size: int = FONT_BODY,
		muted: bool = false, outline: bool = true, role: Role = Role.PANEL) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color",
		muted_on(tone, role) if muted else text_on(tone, role))
	label.add_theme_color_override("font_outline_color",
		outline_color(tone, role) if outline else Color(0, 0, 0, 0))
	label.add_theme_constant_override("outline_size",
		outline_size(tone, font_size, role) if outline else 0)

# 패널 한 장. `PanelContainer`든 `Panel`이든 받는다.
static func style_panel(node: Control, tone: Tone, role: Role = Role.PANEL) -> void:
	node.add_theme_stylebox_override("panel", panel_box(tone, role))

# =============================================================================
# 5. 스포트라이트 (U3 길잡이)
# =============================================================================
# 화면 전체를 덮는 Control 하나를 만들어 준다. 안에 구멍 하나가 뚫려 있고
# 나머지는 균일하게 어둡다. **트윈 루프 금지** — 밝기는 한 번 세팅하거나
# `delta` 감쇠로 끌어올리는 것만 허용한다.
#
#   var spot := UIKit.make_spotlight(ui_root)
#   UIKit.aim_spotlight(spot, target_control.get_global_rect(), 0.72)
#
# 조립: 구멍 주변에 9-slice 마스크 1장 + 화면 나머지를 메우는 ColorRect 4장.
# 마스크 바깥 픽셀과 ColorRect 색이 같은 SPOTLIGHT_INK라 이음매가 안 보인다.
static func make_spotlight(parent: Node) -> Control:
	var root := Control.new()
	root.name = "UIKitSpotlight"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 클릭 차단이 길잡이의 목적
	for side: String in ["Top", "Bottom", "Left", "Right"]:
		var quad := ColorRect.new()
		quad.name = "Scrim" + side
		quad.color = SPOTLIGHT_INK
		quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(quad)
	var mask := NinePatchRect.new()
	mask.name = "Mask"
	mask.texture = TEX_SPOTLIGHT_RECT
	mask.patch_margin_left = SPOTLIGHT_MARGIN
	mask.patch_margin_top = SPOTLIGHT_MARGIN
	mask.patch_margin_right = SPOTLIGHT_MARGIN
	mask.patch_margin_bottom = SPOTLIGHT_MARGIN
	mask.draw_center = false      # 가운데는 완전히 뚫려 있어야 한다
	# 이 한 노드만 LINEAR다. overlay-vignette와 같은 이유 —
	# 순수 알파 감쇠판이라 nearest로 늘리면 동심 계단이 보인다.
	mask.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mask)
	parent.add_child(root)
	return root

# 구멍을 `target`(전역 좌표)에 맞춘다. `dim`은 0~1의 전체 어둡기.
static func aim_spotlight(spotlight: Control, target: Rect2, dim: float = 0.72) -> void:
	var screen := spotlight.get_viewport_rect().size
	var hole := target.grow(float(SPOTLIGHT_MARGIN))
	hole = hole.intersection(Rect2(Vector2.ZERO, screen))
	var mask := spotlight.get_node_or_null("Mask") as NinePatchRect
	if mask != null:
		mask.position = hole.position
		mask.size = hole.size
	# 구멍의 상/하/좌/우를 정확히 메운다. 소수점 좌표를 남기면 1px 밝은 금이 간다.
	var rects := {
		"ScrimTop": Rect2(0, 0, screen.x, hole.position.y),
		"ScrimBottom": Rect2(0, hole.end.y, screen.x, screen.y - hole.end.y),
		"ScrimLeft": Rect2(0, hole.position.y, hole.position.x, hole.size.y),
		"ScrimRight": Rect2(hole.end.x, hole.position.y, screen.x - hole.end.x, hole.size.y),
	}
	for key: String in rects:
		var quad := spotlight.get_node_or_null(key) as ColorRect
		if quad == null:
			continue
		var r: Rect2 = rects[key]
		quad.position = r.position.floor()
		quad.size = r.size.ceil().max(Vector2.ZERO)
	spotlight.modulate = Color(1, 1, 1, clampf(dim, 0.0, 1.0))

# 둥근 대상(인물·랜드마크)용 타원 스포트라이트 텍스처. 직접 TextureRect에 물린다.
# 이것도 LINEAR로 그릴 것.
static func spotlight_oval() -> Texture2D:
	return TEX_SPOTLIGHT_OVAL

# =============================================================================
# 6. 호버 툴팁 (X2 신설 · 공용)
# =============================================================================
# 사용자 요구(2026-08-09 피드백 ⑤): "필요한 정보는 최대한 마우스 호버로 볼 수 있게."
# 화면에서 문장을 지우려면 지운 문장이 **갈 곳**이 있어야 한다. 그 자리가 여기다.
#
# Godot 내장 `tooltip_text`를 안 쓰는 이유 세 가지
#   ① 지연이 프로젝트 전역 설정 하나뿐이고 화면별로 못 준다.
#   ② **키보드 포커스에서는 아예 안 뜬다.** 이 게임은 단일 포커스 키보드 경로가
#      마우스와 동급 시민이라(부록 C-1) 두 입력이 같은 정보를 못 보면 반쪽이 된다.
#   ③ 캡처에서 강제로 띄울 방법이 없다 — 호버 상태를 QA 스크린샷으로 남길 수 없다.
#
# 사용법(세 줄)
#   var layer := UIKit.make_tooltip_layer(overlay)          # 화면당 한 장, 맨 위
#   UIKit.attach_tooltip(button, layer, {"title": "화염장", "rows": [["지속","1.20초"]],
#                                        "body": "불바다를 남긴다.", "accent": color})
#   UIKit.tooltip_focus(layer, button)                      # 키보드 포커스가 왔을 때
#
# **트윈 루프 0건.** 등장은 1회성 알파 페이드 하나뿐이고 사라질 때는 즉시 free 한다.
const TOOLTIP_META := "ui_tooltip"          # 내용(Dictionary)을 매다는 meta 키
const TOOLTIP_BOUND_META := "ui_tooltip_bound"
const TOOLTIP_DELAY := 0.25                 # 사용자 지정 지연(초)
const TOOLTIP_FADE := 0.12
const TOOLTIP_GAP := 10.0                   # 대상과 툴팁 사이 틈
const TOOLTIP_EDGE := 8.0                   # 화면 가장자리 여백
const TOOLTIP_MIN_W := 210.0
const TOOLTIP_MAX_W := 330.0                # 본문 문장이 줄바꿈되는 폭

## 툴팁 한 장을 관리하는 층. 화면(모달 오버레이)당 하나만 만든다.
## 지연 타이머만 돌리는 얇은 노드다 — 상태는 "지금 겨눈 대상"과 "지금 떠 있는 대상" 둘.
class TooltipLayer:
	extends Control

	var hover_delay := 0.25
	var _aim: Control = null      # 지연을 기다리는 중인 대상
	var _shown: Control = null    # 지금 떠 있는 툴팁의 주인
	var _wait := 0.0
	var _box: Control = null

	func _init() -> void:
		name = "UIKitTooltips"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 편집·모달 화면은 트리를 멈춘 채 뜬다. 멈춘 트리에서 지연 타이머가 안 돌면
		# 툴팁이 영원히 안 뜬다 — 이 층만 ALWAYS다.
		process_mode = Node.PROCESS_MODE_ALWAYS

	## 지연 뒤에 띄운다. 같은 대상을 다시 겨누면 아무 일도 안 한다.
	func aim(target: Control) -> void:
		if target == null or target == _aim:
			return
		_aim = target
		_wait = hover_delay

	## 그 대상에서 벗어났다. 다른 대상이 이미 겨눠졌다면 건드리지 않는다.
	func release(target: Control) -> void:
		if _aim == target:
			_aim = null

	## 지연 없이 즉시. 캡처와 "첫 진입 1회 안내"가 쓴다.
	func force(target: Control) -> void:
		if target == null:
			return
		_aim = target
		_wait = 0.0
		_present(target)

	func dismiss() -> void:
		_aim = null
		_wait = 0.0
		_close()

	func shown_target() -> Control:
		return _shown

	func _process(delta: float) -> void:
		if _shown != null and (not is_instance_valid(_shown) or _shown != _aim):
			_close()
		if _aim == null:
			return
		if not is_instance_valid(_aim):
			_aim = null
			return
		if _shown == _aim:
			return
		_wait -= delta
		if _wait <= 0.0:
			_present(_aim)

	func _present(target: Control) -> void:
		_close()
		if not is_instance_valid(target) or not target.has_meta(UIKit.TOOLTIP_META):
			return
		var spec: Dictionary = target.get_meta(UIKit.TOOLTIP_META)
		if spec.is_empty():
			return
		_box = UIKit.build_tooltip_box(spec)
		add_child(_box)
		_shown = target
		UIKit.place_tooltip(_box, target.get_global_rect(), get_viewport_rect().size)
		# 1회성 페이드 하나. `set_loops()`는 부르지 않는다(ui-style-v3 §12).
		_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var tween := _box.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_box, "modulate", Color.WHITE, UIKit.TOOLTIP_FADE)

	func _close() -> void:
		if is_instance_valid(_box):
			_box.queue_free()
		_box = null
		_shown = null

## 화면당 한 장. **가장 마지막에** 붙여야 툴팁이 카드·버튼 위로 올라온다.
static func make_tooltip_layer(parent: Node) -> Control:
	var layer := TooltipLayer.new()
	layer.hover_delay = TOOLTIP_DELAY
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(layer)
	return layer

## 대상 하나에 툴팁 내용을 매단다. 두 번 불러도 배선은 한 번만 한다(내용만 갈린다).
##   spec = {"title": String, "body": String, "accent": Color,
##           "rows": [[이름, 값] 또는 [이름, 값, Color], …]}
static func attach_tooltip(target: Control, layer: Control, spec: Dictionary) -> void:
	if target == null or layer == null:
		return
	target.set_meta(TOOLTIP_META, spec)
	# 킷 툴팁이 뜨는 자리에 엔진 기본 툴팁이 겹치면 두 겹으로 읽힌다.
	target.tooltip_text = ""
	if target.has_meta(TOOLTIP_BOUND_META):
		return
	target.set_meta(TOOLTIP_BOUND_META, true)
	# 마우스를 아예 안 받는 장식 노드에는 툴팁을 걸 수 없다. PASS로 올려 준다
	# (STOP으로 올리면 그 아래 카드 버튼이 클릭을 못 받는다).
	if target.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		target.mouse_filter = Control.MOUSE_FILTER_PASS
	var host: TooltipLayer = layer as TooltipLayer
	if host == null:
		return
	target.mouse_entered.connect(func() -> void: host.aim(target))
	target.mouse_exited.connect(func() -> void: host.release(target))

## 키보드 포커스 경로. 마우스와 **같은 지연·같은 그림**이다(접근성 대칭).
static func tooltip_focus(layer: Control, target: Control) -> void:
	var host: TooltipLayer = layer as TooltipLayer
	if host == null:
		return
	if target == null:
		host.dismiss()
		return
	host.aim(target)

## 지연 없이 즉시 표시. QA 캡처가 호버 상태를 그림으로 남기는 유일한 방법이다.
static func tooltip_force(layer: Control, target: Control) -> void:
	var host: TooltipLayer = layer as TooltipLayer
	if host != null:
		host.force(target)

static func tooltip_hide(layer: Control) -> void:
	var host: TooltipLayer = layer as TooltipLayer
	if host != null:
		host.dismiss()

## 지금 툴팁이 떠 있는 대상(없으면 null). 테스트가 이걸로 단언한다.
static func tooltip_shown(layer: Control) -> Control:
	var host: TooltipLayer = layer as TooltipLayer
	return host.shown_target() if host != null else null

## 툴팁 상자 한 장. `PanelContainer` + `VBoxContainer`라 **내용이 크기를 정한다** —
## 좌표를 손으로 잡으면 문장 길이가 바뀔 때마다 상자가 넘치거나 빈다.
static func build_tooltip_box(spec: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.name = "UIKitTooltipBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 툴팁은 어느 화면 위에 떠도 같은 소속이어야 한다 — 심연 판 하나로 고정한다.
	style_panel(box, Tone.ABYSS, Role.PANEL)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	column.custom_minimum_size = Vector2(TOOLTIP_MIN_W, 0.0)
	box.add_child(column)
	var accent: Color = spec.get("accent", accent_color(Tone.ABYSS))
	var title := String(spec.get("title", ""))
	if not title.is_empty():
		var head := Label.new()
		head.text = title
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_label(head, Tone.ABYSS, FONT_HEADING, false, false)
		head.add_theme_color_override("font_color", accent)
		column.add_child(head)
	var rows: Array = spec.get("rows", [])
	if not rows.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 2)
		column.add_child(grid)
		for row_value in rows:
			var row: Array = row_value
			if row.size() < 2:
				continue
			var key := Label.new()
			key.text = String(row[0])
			key.mouse_filter = Control.MOUSE_FILTER_IGNORE
			style_label(key, Tone.ABYSS, FONT_CAPTION, true, false)
			grid.add_child(key)
			var value := Label.new()
			value.text = String(row[1])
			value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			style_label(value, Tone.ABYSS, FONT_LABEL, false, false)
			if row.size() >= 3 and row[2] is Color:
				value.add_theme_color_override("font_color", row[2])
			grid.add_child(value)
	var body := String(spec.get("body", ""))
	if not body.is_empty():
		var text := Label.new()
		text.text = body
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(TOOLTIP_MAX_W, 0.0)
		style_label(text, Tone.ABYSS, FONT_BODY, true, false)
		column.add_child(text)
	return box

## 대상 아래에 붙이되 화면 밖으로 나가면 위로 뒤집는다. 좌우는 항상 화면 안으로 민다.
static func place_tooltip(box: Control, target: Rect2, screen: Vector2) -> void:
	var box_size := box.get_combined_minimum_size()
	box.size = box_size
	var at := Vector2(target.position.x, target.end.y + TOOLTIP_GAP)
	if at.y + box_size.y > screen.y - TOOLTIP_EDGE:
		at.y = target.position.y - box_size.y - TOOLTIP_GAP
	at.x = clampf(at.x, TOOLTIP_EDGE, maxf(TOOLTIP_EDGE, screen.x - box_size.x - TOOLTIP_EDGE))
	at.y = clampf(at.y, TOOLTIP_EDGE, maxf(TOOLTIP_EDGE, screen.y - box_size.y - TOOLTIP_EDGE))
	box.position = at.floor()
