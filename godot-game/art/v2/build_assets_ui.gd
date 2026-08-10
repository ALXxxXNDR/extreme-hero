extends SceneTree
# =============================================================================
# U0 — UI 재스킨 킷 빌더 (Ninja Adventure 테마 · v3 필드와 같은 픽셀 밀도)
# =============================================================================
# `build_assets.gd`(W11)와 `build_assets_v3.gd`(v3)는 **손대지 않는다.**
# 이 파일은 UI 킷 산출물만 굽고, 앞선 두 빌더의 파일명과 절대 겹치지 않는다
# (전부 `ui-kit-` 접두사).
#
#   godot --headless --path godot-game --script res://art/v2/build_assets_ui.gd
#   godot --headless --path godot-game --editor --quit        # 새 PNG 임포트
#
# 앞선 두 빌더에서 그대로 이어받은 규칙:
#   1. 확대는 오직 nearest 정수배. UI 킷은 전부 **×2** — 필드 스프라이트(16px×2)와
#      같은 픽셀 밀도다. 화면에 세 번째 픽셀 크기를 만들지 않는다.
#   2. 합성은 원본 좌표계(16px 격자)에서 끝내고, 마지막에 한 번만 ×2로 올린다.
#   3. 난수·시각을 쓰지 않는다. 연속 2회 실행 시 전 산출물 SHA-256 동일.
#
# U0가 새로 정한 규칙 3가지:
#   4. **패널 계열 9-slice 여백은 전부 5(원본) = 10(굽고 나서)로 통일한다.**
#      U1~U3가 시트마다 여백을 찾아볼 필요가 없게 하려는 것이다. 카드(8/16)와
#      리본(8·9·8·9)만 예외이고, 이 셋이 프로젝트 전체의 여백 상수다.
#   5. 색은 **NA `Palette.png`(10×9 · 52색)와 `Ui/Theme/Theme Wood`에서만** 고른다.
#      톤 7종은 전부 그 팔레트 안의 색을 골라 만든 램프이고, hover/pressed/
#      disabled 파생색만 `lightened`/`darkened`/HSV로 계산한다(결정적 함수).
#   6. 스포트라이트 마스크 2장만 **×1 · LINEAR**다. `overlay-vignette.png`와
#      같은 논리 — 순수 알파 감쇠판이라 nearest로 늘리면 계단이 보인다.
#      픽셀아트 실루엣이 없으므로 스타일을 해치지 않는다.
# =============================================================================

const NA := "res://art/external/ninja-adventure/"
const OUT := "res://art/v2/"
const SCALE := 2

var _cache: Dictionary = {}
var _written: Array[String] = []

# =============================================================================
# 1. 톤 램프 7종 (docs/ui-style-v3.md §2)
# =============================================================================
# 슬롯 7개는 전부 "베벨의 한 고리"에 대응한다. 램프만 갈아 끼우면 같은 구조의
# 패널이 다른 톤으로 나온다 — 이게 이 킷의 유일한 색 결정 지점이다.
#
#   outline  1px 바깥 테두리 (전 톤 공통 #141b1b — NA 팔레트 (0,8))
#   hi       윗면 하이라이트 (빛은 위에서 온다)
#   mid      좌우 측면
#   lo       아랫면 그림자
#   edge     안쪽 오목선 (표면과 well을 가르는 1px)
#   shade    well 안쪽 좌·상 그림자
#   fill     well 바탕
#
# 전 색상은 NA Palette.png 좌표를 주석에 남긴다(r,c = 행,열 0-based).
const TONES := {
	# 밝은 양피지 — 필드가 안 보이는 전면 화면(로비·온보딩·결과)의 본문.
	"parchment": {
		"outline": Color("141b1b"),  # (8,0)
		"hi":      Color("ffe18d"),  # (0,7)
		"mid":     Color("eecf9b"),  # (0,6)
		"lo":      Color("c8966b"),  # (1,5)
		"edge":    Color("965340"),  # (1,0)
		"shade":   Color("d2b37d"),  # (0,3)
		"fill":    Color("fce2ca"),  # (0,8)
	},
	# 황금 — 트로피·보상·등급. parchment보다 한 단 진하고 채도가 높다.
	"gold": {
		"outline": Color("141b1b"),
		"hi":      Color("ffe18d"),  # (0,7)
		"mid":     Color("f1c471"),  # (0,4)
		"lo":      Color("d78b4a"),  # (0,0)
		"edge":    Color("965340"),  # (1,0)
		"shade":   Color("d2b37d"),  # (0,3)
		"fill":    Color("ffcb8d"),  # (0,5)
	},
	# 나무 — NA Theme Wood 원본 색 그대로. 기본 모달 껍데기·기본 버튼.
	"wood": {
		"outline": Color("141b1b"),
		"hi":      Color("ffad5d"),  # (0,1)
		"mid":     Color("f06733"),  # Theme Wood 고유색
		"lo":      Color("9b513c"),  # Theme Wood 고유색
		"edge":    Color("46402e"),  # Theme Wood 고유색
		"shade":   Color("a3754e"),  # (1,2)
		"fill":    Color("f38c4c"),  # Theme Wood 고유색
	},
	# 초록 — 획득·성공·치유. GamePalette.GREEN(#83c65c) 자리를 NA 쪽으로 옮긴 것.
	"verdant": {
		"outline": Color("141b1b"),
		"hi":      Color("adbc3a"),  # (5,3)
		"mid":     Color("a8a129"),  # (5,2)
		"lo":      Color("56864c"),  # (5,0)
		"edge":    Color("345a52"),  # (7,0)
		"shade":   Color("56864c"),  # (5,0)
		"fill":    Color("74a334"),  # (5,1)
	},
	# 석판 — **필드 위에 얹히는 것 전부**(HUD 패널·레일 밴드·배너).
	# 어두운 청록이라 5단 톤 어디에 얹혀도 지형과 안 섞이고 글자가 산다.
	"slate": {
		"outline": Color("141b1b"),
		"hi":      Color("abc2bc"),  # (7,3)
		"mid":     Color("8d977f"),  # (7,2)
		"lo":      Color("5f7160"),  # (7,1)
		"edge":    Color("141b1b"),  # (8,0)
		"shade":   Color("2d697b"),  # (4,1)
		"fill":    Color("345a52"),  # (7,0)
	},
	# 심연 — 마왕·5스테이지·고스트 레일·잠식. 필드 abyss 바이옴과 같은 계열.
	"abyss": {
		"outline": Color("141b1b"),
		"hi":      Color("d3a2c0"),  # (6,4)
		"mid":     Color("a5608b"),  # (6,3)
		"lo":      Color("8f3e56"),  # (6,2)
		"edge":    Color("141b1b"),  # (8,0)
		"shade":   Color("543c52"),  # (6,1)
		"fill":    Color("3b3643"),  # (6,0)
	},
	# 불씨 — 위험·보스·과부하·파기 확인. 넓은 면에 쓰지 말 것(문서 §2 경고).
	# fill을 벽돌빛 #d14b34로 잡아 wood(#f38c4c)와 **한눈에 갈리게** 했다.
	# 둘 다 주황 계열이라 명도만 다르면 스킬 카드와 보스 카드가 안 구분된다(실측).
	"ember": {
		"outline": Color("141b1b"),
		"hi":      Color("ff9554"),  # (2,3)
		"mid":     Color("e46d3a"),  # (2,1)
		"lo":      Color("8f3e56"),  # (6,2)
		"edge":    Color("543c52"),  # (6,1)
		"shade":   Color("9c6546"),  # (1,1)
		"fill":    Color("d14b34"),  # (2,0)
	},
}
# 아틀라스 열 순서 = 밝기 사다리. 문서·헬퍼의 enum 순서와 **반드시** 같아야 한다.
const TONE_ORDER: Array[String] = ["parchment", "gold", "wood", "verdant", "slate", "abyss", "ember"]

# 잉크(글자색) 2종 — NA 팔레트 (4,7)과 (8,0).
const INK_LIGHT := Color("f2eaf1")
const INK_DARK := Color("141b1b")

# =============================================================================
# 2. 격자 규격 (docs/ui-style-v3.md §1 표와 1:1)
# =============================================================================
const PANEL_CELL := 16      # 패널·버튼 원본 셀. 9-slice 여백 5.
const PANEL_MARGIN := 5
const CARD_CELL := 24       # 카드 원본 셀. 9-slice 여백 8.
const CARD_MARGIN := 8
const RIBBON_W := 24        # 리본 원본 셀 24×20. 여백 L8 T9 R8 B9(대칭).
# 16이었는데 20으로 올렸다 — 구운 뒤 32px 리본에 FONT_TITLE(26)을 얹으면 글자
# 아랫변이 아래쪽 베벨에 올라탄다(실측: 위 여유 7px · 아래 2px). 40px면 넉넉하고
# 위아래 여백이 대칭이라 시각 중심도 맞는다.
const RIBBON_H := 20
const KEYCAP_W := 36        # 키캡 원본 셀(NA 최대 KeySpace 33×13, Mouse 15×20 수용)
const KEYCAP_H := 20
const GLYPH_CELL := 16
const BAR_CELL := 8         # 게이지 9-slice 원본 셀. 여백 2.
const BAR_MARGIN := 2

const PANEL_ROLES: Array[String] = ["panel", "inset", "chip", "cell", "focus"]

# 버튼 — 열 = 변종, 행 = 상태. focus 링은 패널 시트의 `focus` 행을 공용으로 쓴다.
const BUTTON_VARIANTS := {
	"primary": "wood",      # 주 행동(시작·확정·구매)
	"neutral": "slate",     # 보조 행동(닫기·뒤로)
	"danger": "ember",      # 파괴적 행동(파기·포기)
	"quiet": "gold",        # 밝은 화면의 저강조 행동 — parchment 패널 위에서
	                        # parchment 버튼은 대비 1.02:1이라 구멍처럼 보였다(실측)
}
const BUTTON_VARIANT_ORDER: Array[String] = ["primary", "neutral", "danger", "quiet"]
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]

# 카드 — 톤 + 좌상단 모서리 문양으로 종류를 가른다.
# 9-slice의 모서리 블록(8×8)은 **늘어나지 않으므로** 문양이 살아남는다.
const CARD_KINDS := {
	"skill":  {"tone": "wood",      "motif": "diamond"},
	"item":   {"tone": "slate",     "motif": "chest"},
	"rune":   {"tone": "abyss",     "motif": "star"},
	"trophy": {"tone": "gold",      "motif": "crown"},
	"boss":   {"tone": "ember",     "motif": "horn"},
}
const CARD_KIND_ORDER: Array[String] = ["skill", "item", "rune", "trophy", "boss"]
const CARD_STATES: Array[String] = ["normal", "selected", "disabled"]

const CARD_MOTIFS := {
	"diamond": [
		"  #  ",
		" ### ",
		"#####",
		" ### ",
		"  #  ",
	],
	"chest": [
		"#####",
		"#   #",
		"# # #",
		"#   #",
		"#####",
	],
	"star": [
		"# # #",
		" ### ",
		"#####",
		" ### ",
		"# # #",
	],
	"crown": [
		"# # #",
		"#####",
		"#####",
		" ### ",
		"  #  ",
	],
	"horn": [
		"#   #",
		"## ##",
		"#####",
		" ### ",
		"  #  ",
	],
}

# 리본도 **톤 7종 전부** 굽는다. verdant/slate 리본을 실제로 쓸 일은 드물지만,
# 열 순서가 TONE_ORDER와 어긋나면 `UIKit.Tone.SLATE`를 넘겼을 때 조용히 다른 색이
# 나온다(int enum이라 타입 오류가 안 난다). 96px 더 굽고 그 함정을 없애는 쪽이 싸다.
const RIBBON_SHAPES: Array[String] = ["plaque", "notched"]

# 키캡 — NA `Ui/Input/`에서 그대로 잘라 온다(원본이 이미 완성된 픽셀아트다).
# 배열 순서 = 아틀라스 좌→우, 위→아래. 5열.
const KEYCAP_KEYS: Array = [
	["w", "Keyboard/KeyW.png"], ["a", "Keyboard/KeyA.png"], ["s", "Keyboard/KeyS.png"],
	["d", "Keyboard/KeyD.png"], ["e", "Keyboard/KeyE.png"],
	["q", "Keyboard/KeyQ.png"], ["r", "Keyboard/KeyR.png"], ["f", "Keyboard/KeyF.png"],
	["i", "Keyboard/KeyI.png"], ["m", "Keyboard/KeyM.png"],
	["1", "Keyboard/Key1.png"], ["2", "Keyboard/Key2.png"], ["3", "Keyboard/Key3.png"],
	["4", "Keyboard/Key4.png"], ["5", "Keyboard/Key5.png"],
	["up", "Keyboard/KeyUp.png"], ["down", "Keyboard/KeyDown.png"],
	["left", "Keyboard/KeyLeft.png"], ["right", "Keyboard/KeyRight.png"],
	["esc", "Keyboard/KeyEscape.png"],
	["space", "Keyboard/KeySpace.png"], ["enter", "Keyboard/KeyEnter.png"],
	["tab", "Keyboard/KeyTab.png"], ["shift", "Keyboard/KeyShift.png"],
	["mouse_left", "Mouse/MouseButtonLeft.png"],
	["mouse_right", "Mouse/MouseButtonRight.png"],
]
const KEYCAP_COLUMNS := 5

# 포인터 — 8열 × 2행. 앞 4개는 NA 원본 회전, 나머지는 절차적.
const POINTER_ORDER: Array[String] = [
	"chevron_left", "chevron_right", "chevron_up", "chevron_down",
	"pointer_left", "pointer_right", "pointer_up", "pointer_down",
	"needle", "caret", "bullet", "close",
	"double_left", "double_right", "ellipsis", "grip",
]
const POINTER_COLUMNS := 8

# 글리프 — 8열 × 2행. 두 번째 열이 빈 문자열이면 `GLYPH_BITS`로 그리고,
# 경로면 NA 원본을 셀 중앙에 놓는다. **배열 순서 = `UIKit.GLYPH_INDEX` 계약.**
#
# 절차적 글리프는 전부 흰색(INK_LIGHT)이다 — 호출부가 `modulate`로 아무 색이나
# 입힐 수 있게 하려는 것. 원본에서 가져온 6종만 고유 색을 갖는다.
const GLYPH_ORDER: Array = [
	["check", ""], ["cross", ""], ["plus", ""], ["minus", ""],
	["star", ""], ["diamond", ""], ["warn", ""], ["info", ""],
	# 동전·열쇠는 원본(`Treasure/GoldCoin` 7×7 · `GoldKey` 12×8)이 너무 작아
	# 32px 셀 안에서 다른 글리프(26~30px)와 무게가 안 맞았다 — 배치가 아니라
	# 그림 자체가 작다. 같은 14px 규격으로 새로 그렸다.
	["coin", ""], ["key", ""],
	["gem", "Items/Resource/GemPurple.png"],
	["hourglass", "Items/Object/Hourglass.png"],
	["scroll", "Items/Scroll/Scroll.png"],
	["book", "Items/Object/Book.png"],
	["heart", "Ui/Receptacle/IconHeart.png"],   # Items/Potion/Heart는 항아리로 읽힌다
	["bag", "Items/Object/Bag.png"],
]
const GLYPH_COLUMNS := 8

const BAR_ORDER: Array[String] = ["track_dark", "track_light", "fill", "fill_gloss"]

# 스포트라이트(U3) — 이 둘만 ×1 · LINEAR.
const SPOT_RECT := 96       # 여백 32. 안쪽 32×32가 완전 투명.
const SPOT_RECT_MARGIN := 32
const SPOT_OVAL := 256
const SPOT_INK := Color(0.02, 0.02, 0.05)   # overlay-vignette와 같은 근사흑

# 절차적 글리프 비트맵(16×16). ' '=투명 · '#'=잉크 · '+'=밝은 잉크 · '.'=테두리
const GLYPH_BITS := {
	"check": [
		"                ",
		"                ",
		"            ..  ",
		"           .##. ",
		"          .##+. ",
		"  ..     .##+.  ",
		" .##.   .##+.   ",
		" .###. .##+.    ",
		"  .###.##+.     ",
		"   .#####.      ",
		"    .###.       ",
		"     ...        ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	"cross": [
		"                ",
		"                ",
		"  ..        ..  ",
		" .##.      .##. ",
		" .###.    .###. ",
		"  .###.  .###.  ",
		"   .###..###.   ",
		"    .######.    ",
		"    .######.    ",
		"   .###..###.   ",
		"  .###.  .###.  ",
		" .###.    .###. ",
		" .##.      .##. ",
		"  ..        ..  ",
		"                ",
		"                ",
	],
	"plus": [
		"                ",
		"                ",
		"      ....      ",
		"     .####.     ",
		"     .#++#.     ",
		"  ....#++#....  ",
		" .############. ",
		" .#++++++++++#. ",
		" .############. ",
		"  ....#++#....  ",
		"     .#++#.     ",
		"     .####.     ",
		"      ....      ",
		"                ",
		"                ",
		"                ",
	],
	"minus": [
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"  ............  ",
		" .############. ",
		" .#++++++++++#. ",
		" .############. ",
		"  ............  ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	"star": [
		"                ",
		"       ..       ",
		"      .##.      ",
		"      .##.      ",
		"     .####.     ",
		" .....#++#..... ",
		" .############. ",
		"  .##++++++##.  ",
		"  .####++####.  ",
		"   .###..###.   ",
		"  .###.  .###.  ",
		" .###.    .###. ",
		" .#.        .#. ",
		"  .          .  ",
		"                ",
		"                ",
	],
	"diamond": [
		"                ",
		"       ..       ",
		"      .##.      ",
		"     .####.     ",
		"    .##++##.    ",
		"   .##++++##.   ",
		"  .##++++++##.  ",
		" .############. ",
		"  .##++++++##.  ",
		"   .##++++##.   ",
		"    .######.    ",
		"     .####.     ",
		"      .##.      ",
		"       ..       ",
		"                ",
		"                ",
	],
	# 경고 — 삼각형(잉크)에 느낌표를 **테두리색으로 파낸다.** 흰 삼각형 위의
	# 검은 느낌표라 배경이 밝든 어둡든 같은 그림으로 읽힌다.
	"warn": [
		"                ",
		"       ..       ",
		"      .##.      ",
		"      .##.      ",
		"     .#..#.     ",
		"     .#..#.     ",
		"    .##..##.    ",
		"    .##..##.    ",
		"   .###..###.   ",
		"   .###..###.   ",
		"  .##########.  ",
		" .#####..#####. ",
		" .############. ",
		"  ............  ",
		"                ",
		"                ",
	],
	# 동전 — 원판 + 안쪽 링. 흰색이라 `modulate`로 금·은 어느 쪽이든 된다.
	"coin": [
		"                ",
		"      ....      ",
		"    ..####..    ",
		"   .##++++##.   ",
		"  .##+....+##.  ",
		"  .#+.####.+#.  ",
		" .##+.####.+##. ",
		" .##+.####.+##. ",
		" .##+.####.+##. ",
		" .##+.####.+##. ",
		"  .#+.####.+#.  ",
		"  .##+....+##.  ",
		"   .##++++##.   ",
		"    ..####..    ",
		"      ....      ",
		"                ",
	],
	# 열쇠 — 고리 + 자루 + 이빨 2개. 가로로 눕혀야 14px 안에서 형태가 산다.
	"key": [
		"                ",
		"                ",
		"   ......       ",
		"  .######.      ",
		"  .##++##.      ",
		"  .#+..+#.......",
		"  .#+..+#++++++.",
		"  .##++##.#..#..",
		"   ......  .. ..",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	# 정보 — 원판(잉크)에 i를 파낸다. y5 한 줄이 점과 세로획 사이의 틈이다.
	"info": [
		"                ",
		"     ......     ",
		"   ..######..   ",
		"  .####..####.  ",
		" .#####..#####. ",
		" .############. ",
		" .#####..#####. ",
		" .#####..#####. ",
		" .#####..#####. ",
		" .#####..#####. ",
		"  .####..####.  ",
		"   ..######..   ",
		"     ......     ",
		"                ",
		"                ",
		"                ",
	],
}

# 포인터 절차적 비트맵(16×16).
const POINTER_BITS := {
	"needle": [
		"                ",
		"                ",
		"                ",
		" .............. ",
		" .############. ",
		" .#++++++++++#. ",
		"  .##########.  ",
		"   .########.   ",
		"    .######.    ",
		"     .####.     ",
		"      .##.      ",
		"       ..       ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	"caret": [
		"                ",
		"                ",
		"    ..          ",
		"    .#.         ",
		"    .##.        ",
		"    .###.       ",
		"    .####.      ",
		"    .#####.     ",
		"    .####.      ",
		"    .###.       ",
		"    .##.        ",
		"    .#.         ",
		"    ..          ",
		"                ",
		"                ",
		"                ",
	],
	"bullet": [
		"                ",
		"                ",
		"                ",
		"                ",
		"      ....      ",
		"     .####.     ",
		"    .##++##.    ",
		"    .#++++#.    ",
		"    .#++++#.    ",
		"    .##++##.    ",
		"     .####.     ",
		"      ....      ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	"close": [
		"                ",
		"                ",
		"   ..      ..   ",
		"  .##.    .##.  ",
		"   .##.  .##.   ",
		"    .##..##.    ",
		"     .####.     ",
		"      .##.      ",
		"     .####.     ",
		"    .##..##.    ",
		"   .##.  .##.   ",
		"  .##.    .##.  ",
		"   ..      ..   ",
		"                ",
		"                ",
		"                ",
	],
	"double_left": [
		"                ",
		"                ",
		"       ..    .. ",
		"      .#.   .#. ",
		"     .#.   .#.  ",
		"    .#.   .#.   ",
		"   .#.   .#.    ",
		"  .#.   .#.     ",
		"  .#.   .#.     ",
		"   .#.   .#.    ",
		"    .#.   .#.   ",
		"     .#.   .#.  ",
		"      .#.   .#. ",
		"       ..    .. ",
		"                ",
		"                ",
	],
	"double_right": [
		"                ",
		"                ",
		" ..    ..       ",
		" .#.   .#.      ",
		"  .#.   .#.     ",
		"   .#.   .#.    ",
		"    .#.   .#.   ",
		"     .#.   .#.  ",
		"     .#.   .#.  ",
		"    .#.   .#.   ",
		"   .#.   .#.    ",
		"  .#.   .#.     ",
		" .#.   .#.      ",
		" ..    ..       ",
		"                ",
		"                ",
	],
	"ellipsis": [
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		" ...  ...  ...  ",
		" .#.  .#.  .#.  ",
		" .#.  .#.  .#.  ",
		" ...  ...  ...  ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	"grip": [
		"                ",
		"                ",
		"  ...      ...  ",
		"  .#.      .#.  ",
		"  ...      ...  ",
		"                ",
		"  ...      ...  ",
		"  .#.      .#.  ",
		"  ...      ...  ",
		"                ",
		"  ...      ...  ",
		"  .#.      .#.  ",
		"  ...      ...  ",
		"                ",
		"                ",
		"                ",
	],
}

func _init() -> void:
	var started := Time.get_ticks_msec()
	_build_panels()
	_build_buttons()
	_build_cards()
	_build_ribbons()
	_build_keycaps()
	_build_pointers()
	_build_glyphs()
	_build_bars()
	_build_spotlights()
	print("BUILD_ASSETS_UI_COMPLETE files=%d ms=%d" % [_written.size(), Time.get_ticks_msec() - started])
	for path: String in _written:
		print("  ", path)
	quit()

# =========================================================================== 유틸
func _src(path: String) -> Image:
	if _cache.has(path):
		return _cache[path]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(img != null, "원본을 못 읽었습니다: " + path)
	img.convert(Image.FORMAT_RGBA8)
	_cache[path] = img
	return img

func _canvas(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _save(img: Image, name: String, scale: int = SCALE) -> void:
	var scaled := img.duplicate() as Image
	if scale != 1:
		scaled.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var path := OUT + name
	var error := scaled.save_png(ProjectSettings.globalize_path(path))
	assert(error == OK, "저장 실패: " + path)
	_written.append("%s  %dx%d" % [path, scaled.get_width(), scaled.get_height()])

# HSV 회전(build_assets_v3 §4와 같은 기법 — disabled 파생색에만 쓴다).
func _hsv_shift(c: Color, sat_mul: float, val_mul: float) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * sat_mul, 0.0, 1.0), clampf(c.v * val_mul, 0.0, 1.0), c.a)

# 톤 램프 파생. hover/pressed/disabled는 **계산으로만** 만든다(색 결정 지점 1개 유지).
func _ramp(tone: String, mode: String = "normal") -> Dictionary:
	var base: Dictionary = TONES[tone]
	var out := {}
	for key: String in base:
		var c: Color = base[key]
		if key == "outline":
			out[key] = c
			continue
		match mode:
			# fill만 한 단 더 올린다. `lightened`는 남은 거리의 비율이라 밝은 톤에서
			# 거의 안 움직인다 — parchment fill은 채널당 4밖에 안 바뀌어서 hover가
			# 보이지 않았다(실측). fill을 두 번 올려 어느 톤에서나 체감이 남게 한다.
			"hover":    out[key] = c.lightened(0.26 if key == "fill" else 0.16)
			"pressed":  out[key] = c.darkened(0.14)
			"disabled": out[key] = _hsv_shift(c, 0.20, 0.74)
			_:          out[key] = c
	out["fill_hi"] = (out["fill"] as Color).lightened(0.14)
	# well/well2는 `darkened`가 아니라 **edge 쪽으로 lerp**한다. darkened는 검정으로
	# 끌고 가서 parchment의 크림빛이 갈색 진흙이 되어 버린다(실측). edge로 섞으면
	# 톤의 색상 성격이 3단 배경 계층 내내 유지된다.
	out["well"] = (out["fill"] as Color).lerp(out["edge"], 0.42)
	out["well2"] = (out["fill"] as Color).lerp(out["edge"], 0.68)
	return out

# ---------------------------------------------------------------------------
# 베벨 생성기 — 이 킷의 심장. 사각형을 바깥에서 안으로 "고리"로 나누고
# 고리마다 색을 준다. 고리 k의 색은 `bands[k]`이며 배열이면 [상,하,좌,우]다.
# bands 길이를 넘는 고리는 마지막 항목을 쓴다(= 중앙 채움).
# `null`은 투명(포커스 링처럼 속이 빈 프레임용).
#
# 모서리는 45° 마이터로 상 > 하 > 좌 > 우 우선순위를 준다. 위가 이기므로
# "빛은 위에서 온다"가 어떤 톤에서도 흔들리지 않는다.
# ---------------------------------------------------------------------------
func _bevel(w: int, h: int, radius: int, bands: Array) -> Image:
	var img := _canvas(w, h)
	for y in h:
		for x in w:
			var cx: int = mini(x, w - 1 - x)
			var cy: int = mini(y, h - 1 - y)
			if cx + cy < radius:
				continue   # 둥근 모서리 컷
			var dt := y
			var db := h - 1 - y
			var dl := x
			var dr := w - 1 - x
			var k: int = mini(mini(dt, db), mini(dl, dr))
			var entry: Variant = bands[mini(k, bands.size() - 1)]
			if entry == null:
				continue
			var color: Color
			if entry is Array:
				var side := 3
				if dt == k: side = 0
				elif db == k: side = 1
				elif dl == k: side = 2
				color = entry[side]
			else:
				color = entry
			if color.a <= 0.0:
				continue
			img.set_pixel(x, y, color)
	return img

# 역할별 고리 배치. **전 역할이 여백 5에서 균일한 중앙을 갖도록** 짰다.
func _role_bands(r: Dictionary, role: String) -> Array:
	match role:
		"panel":
			# 융기. 0 테두리 / 1·2 립(상하좌우) / 3 오목선 / 4 안쪽 베벨 / 5+ 바탕
			return [
				r["outline"],
				[r["hi"], r["lo"], r["mid"], r["mid"]],
				[r["hi"], r["lo"], r["mid"], r["mid"]],
				r["edge"],
				[r["shade"], r["fill_hi"], r["shade"], r["fill_hi"]],
				r["fill"],
			]
		"inset":
			# 함몰. 위·왼쪽이 어둡다. 바탕은 panel보다 40% 어둡다.
			return [
				r["outline"],
				[r["shade"], r["fill_hi"], r["shade"], r["fill_hi"]],
				r["well"],
			]
		"chip":
			# 평면. 트랙·태그·칩. 가장 어둡다. 테두리(#141b1b) 안쪽에 `lo` 링을
			# 한 겹 넣는다 — abyss/slate처럼 어두운 톤에서는 검은 테두리가 검은
			# 바탕에 묻혀 칩 경계가 아예 사라졌다(실측).
			return [r["outline"], r["lo"], r["well2"]]
		"cell":
			# 슬롯 칸. 테두리 → 오목선 → 측면 → 바탕. 아이콘이 들어갈 자리.
			return [r["outline"], r["edge"], r["mid"], r["fill"]]
		"focus":
			# 속이 빈 흰 링. 어떤 것 위에도 겹쳐 그린다.
			return [r["outline"], INK_LIGHT, null]
	assert(false, "알 수 없는 역할: " + role)
	return []

# =========================================================================== 패널
func _build_panels() -> void:
	var sheet := _canvas(TONE_ORDER.size() * PANEL_CELL, PANEL_ROLES.size() * PANEL_CELL)
	for row in PANEL_ROLES.size():
		for col in TONE_ORDER.size():
			var r := _ramp(TONE_ORDER[col])
			var cell := _bevel(PANEL_CELL, PANEL_CELL, 2, _role_bands(r, PANEL_ROLES[row]))
			sheet.blit_rect(cell, Rect2i(0, 0, PANEL_CELL, PANEL_CELL),
				Vector2i(col * PANEL_CELL, row * PANEL_CELL))
	_save(sheet, "ui-kit-panels.png")

# =========================================================================== 버튼
func _build_buttons() -> void:
	var sheet := _canvas(BUTTON_VARIANT_ORDER.size() * PANEL_CELL, BUTTON_STATES.size() * PANEL_CELL)
	for row in BUTTON_STATES.size():
		var state := BUTTON_STATES[row]
		for col in BUTTON_VARIANT_ORDER.size():
			var tone: String = BUTTON_VARIANTS[BUTTON_VARIANT_ORDER[col]]
			var r := _ramp(tone, state if state != "normal" else "normal")
			# pressed만 함몰 베벨을 쓴다 — 눌린 느낌은 색이 아니라 **구조**로 낸다.
			var role := "inset" if state == "pressed" else "panel"
			var bands := _role_bands(r, role)
			if role == "inset":
				# 눌린 버튼은 바탕이 well까지 어두워지면 글자가 죽는다. fill로 되돌린다.
				bands = [
					r["outline"],
					[r["shade"], r["fill_hi"], r["shade"], r["fill_hi"]],
					r["fill"],
				]
			var cell := _bevel(PANEL_CELL, PANEL_CELL, 2, bands)
			sheet.blit_rect(cell, Rect2i(0, 0, PANEL_CELL, PANEL_CELL),
				Vector2i(col * PANEL_CELL, row * PANEL_CELL))
	_save(sheet, "ui-kit-buttons.png")

# =========================================================================== 카드
func _build_cards() -> void:
	var sheet := _canvas(CARD_KIND_ORDER.size() * CARD_CELL, CARD_STATES.size() * CARD_CELL)
	for row in CARD_STATES.size():
		var state := CARD_STATES[row]
		for col in CARD_KIND_ORDER.size():
			var kind: String = CARD_KIND_ORDER[col]
			var spec: Dictionary = CARD_KINDS[kind]
			var mode := "disabled" if state == "disabled" else "normal"
			var r := _ramp(spec["tone"], mode)
			# 비활성은 **함몰 베벨**을 쓴다. 탈색만 하면 흐려진 립이 선택 상태의 흰
			# 링과 기하가 같아서, 5스테이지 어두운 배경에서 "약하게 선택된 카드"로
			# 오독된다. 융기(보통) · 흰 이중 링(선택) · 함몰(비활성) 세 기하가
			# 색을 안 보고도 갈린다.
			var bands := _role_bands(r, "inset" if state == "disabled" else "panel")
			if state == "selected":
				# 선택 = 립이 흰빛으로 바뀌고 바탕이 한 단 밝아진다.
				# 테두리 두께는 그대로다 — 두께가 변하면 레이아웃이 1px 흔들린다.
				# 흰 링을 **두 겹**으로 하고 바깥(outline)과 안쪽(edge) 양쪽에
				# 어두운 선을 붙인다. 한 겹이면 gold/parchment처럼 밝은 톤에서
				# 링이 바탕에 묻혀 선택이 안 보인다(실측: trophy만 약했다).
				# 고리 개수는 그대로라 내용 영역이 1px도 안 흔들린다.
				bands = [
					r["outline"],
					INK_LIGHT,
					INK_LIGHT,
					r["edge"],
					[r["shade"], r["fill_hi"], r["shade"], r["fill_hi"]],
					(r["fill"] as Color).lightened(0.10),
				]
			var cell := _bevel(CARD_CELL, CARD_CELL, 2, bands)
			var motif_ink: Color = INK_LIGHT if state == "selected" else r["hi"]
			if state == "disabled":
				motif_ink = r["mid"]
			_stamp_motif(cell, CARD_MOTIFS[spec["motif"]], motif_ink, r["outline"])
			sheet.blit_rect(cell, Rect2i(0, 0, CARD_CELL, CARD_CELL),
				Vector2i(col * CARD_CELL, row * CARD_CELL))
	_save(sheet, "ui-kit-cards.png")

# 문양은 좌상단 8×8 모서리 블록 안에만 찍는다(2,2)~(6,6) + 테두리 1px 여유.
# 9-slice 모서리는 늘어나지 않으므로 카드가 190×142든 320×220이든 모양이 같다.
func _stamp_motif(dst: Image, rows: Array, ink: Color, outline: Color) -> void:
	var ox := 2
	var oy := 2
	for j in rows.size():
		var line: String = rows[j]
		for i in line.length():
			if line[i] != "#":
				continue
			# 1px 테두리 후광 먼저(문양이 립 위에 얹혀도 안 묻히게).
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var hx: int = ox + i + dx
					var hy: int = oy + j + dy
					if hx < 0 or hy < 0 or hx >= dst.get_width() or hy >= dst.get_height():
						continue
					if dst.get_pixel(hx, hy).a <= 0.0:
						continue
					dst.set_pixel(hx, hy, outline)
	for j in rows.size():
		var line2: String = rows[j]
		for i in line2.length():
			if line2[i] == "#":
				dst.set_pixel(ox + i, oy + j, ink)

# =========================================================================== 리본
func _build_ribbons() -> void:
	var sheet := _canvas(TONE_ORDER.size() * RIBBON_W, RIBBON_SHAPES.size() * RIBBON_H)
	for row in RIBBON_SHAPES.size():
		for col in TONE_ORDER.size():
			var r := _ramp(TONE_ORDER[col])
			# 리본은 얇으므로 고리를 3단으로 줄인다(여백 T7/B8 안에 다 들어간다).
			var bands: Array = [
				r["outline"],
				[r["hi"], r["lo"], r["mid"], r["mid"]],
				[r["hi"], r["lo"], r["mid"], r["mid"]],
				r["fill"],
			]
			var cell := _bevel(RIBBON_W, RIBBON_H, 2, bands)
			if RIBBON_SHAPES[row] == "notched":
				_notch_ends(cell, r["outline"])
			sheet.blit_rect(cell, Rect2i(0, 0, RIBBON_W, RIBBON_H),
				Vector2i(col * RIBBON_W, row * RIBBON_H))
	_save(sheet, "ui-kit-ribbon.png")

# 좌우 끝에 V 홈을 판다. 홈은 전부 여백(L8 / R8) 안에 있어 가로로 늘어나지 않는다.
func _notch_ends(img: Image, outline: Color) -> void:
	var h := img.get_height()
	var w := img.get_width()
	var mid := (h - 1) * 0.5
	for y in h:
		for x in 5:
			var depth := (4.0 - float(x)) * 1.7 + 0.5
			if absf(float(y) - mid) <= depth:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				img.set_pixel(w - 1 - x, y, Color(0, 0, 0, 0))
	# 잘린 단면에 테두리를 두른다(4-이웃).
	var cuts: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.0:
				continue
			if x > 8 and x < w - 9:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if img.get_pixel(nx, ny).a <= 0.0:
					cuts.append(Vector2i(x, y))
					break
	for p: Vector2i in cuts:
		img.set_pixel(p.x, p.y, outline)

# =========================================================================== 키캡
func _build_keycaps() -> void:
	var rows: int = int(ceil(float(KEYCAP_KEYS.size()) / float(KEYCAP_COLUMNS)))
	var sheet := _canvas(KEYCAP_COLUMNS * KEYCAP_W, rows * KEYCAP_H)
	for i in KEYCAP_KEYS.size():
		var entry: Array = KEYCAP_KEYS[i]
		var src := _src(NA + "Ui/Input/" + entry[1])
		var cw := src.get_width()
		var ch := src.get_height()
		assert(cw <= KEYCAP_W and ch <= KEYCAP_H, "키캡이 셀보다 큽니다: " + entry[1])
		var col := i % KEYCAP_COLUMNS
		var row := i / KEYCAP_COLUMNS
		# 셀 중앙 정렬. 홀수 차이는 왼쪽/위로 내림 — 어느 키에서나 같은 규칙이라
		# U1~U3가 AtlasTexture 하나로 전 키를 뽑을 수 있다.
		var at := Vector2i(
			col * KEYCAP_W + (KEYCAP_W - cw) / 2,
			row * KEYCAP_H + (KEYCAP_H - ch) / 2
		)
		sheet.blit_rect(src, Rect2i(0, 0, cw, ch), at)
	_save(sheet, "ui-kit-keycaps.png")

# ========================================================================= 포인터
func _build_pointers() -> void:
	var rows: int = int(ceil(float(POINTER_ORDER.size()) / float(POINTER_COLUMNS)))
	var sheet := _canvas(POINTER_COLUMNS * GLYPH_CELL, rows * GLYPH_CELL)
	var chev_l := _src(NA + "Ui/Theme/Theme Wood/arrow_left.png")
	var chev_r := _src(NA + "Ui/Theme/Theme Wood/arrow_right.png")
	var arrow := _src(NA + "Ui/Arrow.png")   # 13×13 · 아래를 가리킨다
	for i in POINTER_ORDER.size():
		var name: String = POINTER_ORDER[i]
		var cell := _canvas(GLYPH_CELL, GLYPH_CELL)
		match name:
			"chevron_left":  cell.blit_rect(chev_l, Rect2i(0, 0, 16, 16), Vector2i.ZERO)
			"chevron_right": cell.blit_rect(chev_r, Rect2i(0, 0, 16, 16), Vector2i.ZERO)
			"chevron_up":    cell = _rotate90(_rotate90(_rotate90(_crop(chev_r, 16))))
			"chevron_down":  cell = _rotate90(_crop(chev_r, 16))
			"pointer_down":  cell.blit_rect(arrow, Rect2i(0, 0, 13, 13), Vector2i(1, 1))
			"pointer_left":  cell = _place(_rotate90(_crop(arrow, 13)), GLYPH_CELL)
			"pointer_up":    cell = _place(_rotate90(_rotate90(_crop(arrow, 13))), GLYPH_CELL)
			"pointer_right": cell = _place(_rotate90(_rotate90(_rotate90(_crop(arrow, 13)))), GLYPH_CELL)
			_:
				cell = _from_bits(POINTER_BITS[name], INK_LIGHT, INK_DARK)
		var col := i % POINTER_COLUMNS
		var row := i / POINTER_COLUMNS
		sheet.blit_rect(cell, Rect2i(0, 0, GLYPH_CELL, GLYPH_CELL),
			Vector2i(col * GLYPH_CELL, row * GLYPH_CELL))
	_save(sheet, "ui-kit-pointers.png")

# ========================================================================= 글리프
func _build_glyphs() -> void:
	var rows: int = int(ceil(float(GLYPH_ORDER.size()) / float(GLYPH_COLUMNS)))
	var sheet := _canvas(GLYPH_COLUMNS * GLYPH_CELL, rows * GLYPH_CELL)
	for i in GLYPH_ORDER.size():
		var entry: Array = GLYPH_ORDER[i]
		var ox := (i % GLYPH_COLUMNS) * GLYPH_CELL
		var oy := (i / GLYPH_COLUMNS) * GLYPH_CELL
		if entry[1] == "":
			var cell := _from_bits(GLYPH_BITS[entry[0]], INK_LIGHT, INK_DARK)
			sheet.blit_rect(cell, Rect2i(0, 0, GLYPH_CELL, GLYPH_CELL), Vector2i(ox, oy))
			continue
		var src := _src(NA + entry[1])
		var cw: int = mini(src.get_width(), GLYPH_CELL)
		var ch: int = mini(src.get_height(), GLYPH_CELL)
		sheet.blit_rect(src, Rect2i(0, 0, cw, ch),
			Vector2i(ox + (GLYPH_CELL - cw) / 2, oy + (GLYPH_CELL - ch) / 2))
	_save(sheet, "ui-kit-glyphs.png")

# ========================================================================== 게이지
func _build_bars() -> void:
	# 게이지는 9-slice 여백 2(=굽고 나서 4)다. 높이 12px 이상에서만 써야 한다.
	# HUD의 4px 게이지(W5 레일 슬롯 바닥)는 **여전히 ColorRect다** — 문서 §8 참조.
	var sheet := _canvas(BAR_ORDER.size() * BAR_CELL, BAR_CELL)
	var slate := _ramp("slate")
	var parch := _ramp("parchment")
	for i in BAR_ORDER.size():
		var bands: Array = []
		match BAR_ORDER[i]:
			"track_dark":  bands = [slate["outline"], slate["well2"]]
			"track_light": bands = [parch["outline"], parch["well"]]
			"fill":        bands = [Color(1, 1, 1, 1)]
			"fill_gloss":  bands = [Color(1, 1, 1, 1), Color(1, 1, 1, 0.72)]
		var cell := _bevel(BAR_CELL, BAR_CELL, 1, bands)
		sheet.blit_rect(cell, Rect2i(0, 0, BAR_CELL, BAR_CELL), Vector2i(i * BAR_CELL, 0))
	_save(sheet, "ui-kit-bars.png")

# ===================================================================== 스포트라이트
func _build_spotlights() -> void:
	# ① 사각 구멍 + 부드러운 가장자리. **9-slice(여백 32)** 라 어떤 크기의
	#    직사각형에도 정확히 맞는다 — 카드 한 장, 레일 한 칸, 버튼 하나.
	#    바깥으로 갈수록 알파가 1로 올라가고, 안쪽 32×32는 완전 투명이다.
	#    9-slice에서 가장자리 띠는 늘어나지만 선형 램프는 늘려도 선형이라
	#    이음매가 안 보인다(이게 원형 대신 이 방식을 고른 이유다).
	var rect := _canvas(SPOT_RECT, SPOT_RECT)
	var m := float(SPOT_RECT_MARGIN)
	for y in SPOT_RECT:
		for x in SPOT_RECT:
			var dx: float = maxf(0.0, maxf(m - float(x), float(x) - float(SPOT_RECT - 1 - SPOT_RECT_MARGIN)))
			var dy: float = maxf(0.0, maxf(m - float(y), float(y) - float(SPOT_RECT - 1 - SPOT_RECT_MARGIN)))
			var d: float = clampf(sqrt(dx * dx + dy * dy) / m, 0.0, 1.0)
			rect.set_pixel(x, y, Color(SPOT_INK.r, SPOT_INK.g, SPOT_INK.b, d * d))
	_save(rect, "ui-kit-spotlight-rect.png", 1)

	# ② 원형(타원) 구멍. 인물·랜드마크처럼 둥근 대상용.
	#    overlay-vignette와 같은 제곱 램프 — 중심 30%는 완전 투명.
	var oval := _canvas(SPOT_OVAL, SPOT_OVAL)
	var center := Vector2(float(SPOT_OVAL - 1) * 0.5, float(SPOT_OVAL - 1) * 0.5)
	var longest := center.length()
	for y in SPOT_OVAL:
		for x in SPOT_OVAL:
			var ratio: float = Vector2(float(x), float(y)).distance_to(center) / longest
			var alpha: float = clampf((ratio - 0.30) / 0.70, 0.0, 1.0)
			oval.set_pixel(x, y, Color(SPOT_INK.r, SPOT_INK.g, SPOT_INK.b, alpha * alpha))
	_save(oval, "ui-kit-spotlight-oval.png", 1)

# ==================================================================== 작은 유틸들
func _crop(src: Image, size: int) -> Image:
	var out := _canvas(size, size)
	out.blit_rect(src, Rect2i(0, 0, mini(size, src.get_width()), mini(size, src.get_height())), Vector2i.ZERO)
	return out

# 시계 방향 90°. 정사각 이미지만 받는다.
func _rotate90(src: Image) -> Image:
	var n := src.get_width()
	var out := _canvas(n, n)
	for y in n:
		for x in n:
			out.set_pixel(n - 1 - y, x, src.get_pixel(x, y))
	return out

func _place(src: Image, size: int) -> Image:
	var out := _canvas(size, size)
	var at := Vector2i((size - src.get_width()) / 2, (size - src.get_height()) / 2)
	out.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), at)
	return out

func _from_bits(rows: Array, ink: Color, outline: Color) -> Image:
	var img := _canvas(GLYPH_CELL, GLYPH_CELL)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			match line[x]:
				"#": img.set_pixel(x, y, ink)
				"+": img.set_pixel(x, y, ink.lightened(0.35))
				".": img.set_pixel(x, y, outline)
	return img
