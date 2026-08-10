extends SceneTree
# =============================================================================
# YA — 피드백 라운드 에셋 빌더 (마왕 초상 · 스킬 아이콘 28종 · VFX · 상자 · 장비 · 재화)
# =============================================================================
# 형제 빌더 `build_assets.gd`(W11) · `build_assets_v3.gd`(v3) · `build_assets_ui.gd`(U0)
# 는 **한 글자도 손대지 않는다.** 이 파일이 굽는 파일명은 앞선 셋과 하나도 겹치지 않는다.
#
#   godot --headless --path godot-game --script res://art/v2/build_assets_y.gd
#   godot --headless --path godot-game --editor --quit        # 새 PNG 임포트
#
# 앞선 세 빌더에서 그대로 이어받은 규칙:
#   1. 확대는 오직 nearest 정수배. YA 산출물은 **전부 ×2** 예외 없음.
#   2. 합성은 원본 좌표계에서 끝내고, 마지막에 한 번만 ×2로 올린다(`_save`).
#   3. 난수·시각을 쓰지 않는다. 연속 2회 실행 시 전 산출물 SHA-256 동일.
#   4. 색은 NA 원본 픽셀 · `GamePalette` · U0의 톤 램프에서만 고른다.
#
# YA가 새로 정한 규칙 2가지:
#   5. **스킬 아이콘 28칸은 전부 26×26(원본) 정사각 경계상자를 채운다.**
#      `skill_icon.gd`의 `_build_trimmed()`가 셀마다 내용 경계상자를 잘라 내고
#      `_draw_contained()`가 그것을 칸에 맞춰 늘리기 때문에, 경계상자가 칸마다
#      다르면 **아이콘마다 화면 크기가 달라진다.** 판 모양이 원·팔각·방패·화살촉
#      어느 것이든 26×26을 꽉 채우도록 만드는 이유가 이것 하나다.
#   6. 그 26×26 판 바깥으로 **사방 3px(구운 뒤 6px) 완전 투명 여백**을 남긴다.
#      `_build_trimmed()`는 셀 바깥 4px 링(`TILE_RING`)에 나타난 색만 "타일 색"으로
#      보고 테두리에서 flood fill 한다. 여백이 6px면 그 링은 전부 투명이라
#      판 색이 "타일 색"으로 오인돼 파먹히는 사고가 원천 봉쇄된다.
# =============================================================================

const NA := "res://art/external/ninja-adventure/"
const OUT := "res://art/v2/"
const SCALE := 2

# 스킬 아이콘 아틀라스는 **기존 런타임 경로에 그대로 덮어쓴다**(드롭인).
# `skill_icon.gd`가 `res://art/generated/ui/skill-atlas-minimal-v2-runtime.png` 를
# preload 하고 있고, 이 임무는 게임 .gd 로직 무수정이 조건이기 때문이다.
# 규격(448×256 · 7열×4행 · 셀 64)과 셀 순서(`GENERATED_SKILL_INDEX`)를
# 한 칸도 어기지 않으므로 코드 변경 없이 그대로 교체된다.
# 원본은 빌드 전에 `tmp/ya-backup/skill-atlas-minimal-v2-runtime.orig.png`로 떠 뒀다.
const LEGACY_SKILL_ATLAS := "res://art/generated/ui/skill-atlas-minimal-v2-runtime.png"

var _cache: Dictionary = {}
var _written: Array[String] = []

# =============================================================================
# 0. 색
# =============================================================================
# 원소 7색의 **정본은 `game.gd`의 `ELEMENT_COLOR`**다(handoff-x1 §3).
# 여기 옮겨 적은 것은 빌더가 게임 스크립트를 로드하지 않게 하려는 것뿐이고,
# 값은 `GamePalette` 상수를 그대로 참조하므로 팔레트가 바뀌면 같이 따라간다.
#   fire ORANGE / ice CYAN / thunder YELLOW / poison GREEN /
#   oil PURPLE / strike STONE_LIGHT(무채 = 비원소) / psi MAGENTA
const ELEMENT_COLOR := {
	"fire": Color("e78a45"),
	"ice": Color("67c7d4"),
	"thunder": Color("f4d35e"),
	"poison": Color("83c65c"),
	"oil": Color("7563a8"),
	"strike": Color("c3bda4"),
	"psi": Color("bd6ac8")
}
const INK := Color("141b1b")        # NA Palette (8,0) — 전 산출물 공통 외곽선
const CREAM := Color("fff3d0")      # GamePalette.TEXT — 하이라이트
const GOLD := Color("f4d35e")       # GamePalette.YELLOW
const GOLD_DARK := Color("c8963c")
const GOLD_HI := Color("ffe18d")    # NA Palette (0,7)

# U0 `TONES`의 abyss 램프 — 마왕 초상 액자에 그대로 쓴다(문서 §17-4).
const ABYSS := {
	"hi": Color("d3a2c0"), "mid": Color("a5608b"),
	"lo": Color("8f3e56"), "fill": Color("3b3643")
}
# 무채 램프 — 빈 장비 슬롯 실루엣 전용. 채도 0이라 어떤 카드 위에서도 "예시"로 읽힌다.
const GREY := {
	"dark": Color("2b3038"), "mid": Color("545b66"),
	"light": Color("7d8592"), "hi": Color("a6adb8")
}

# =============================================================================
# 1. 스킬 아이콘 28종 — 셀 순서 계약
# =============================================================================
# **정본은 `scripts/skill_icon.gd`의 `GENERATED_SKILL_INDEX`다.** 아래 배열의
# 인덱스가 그 사전의 값과 하나라도 어긋나면 카드와 그림이 뒤바뀐다.
# 7열 × 4행이므로 배열 순서 = 왼쪽→오른쪽, 위→아래.
const SKILL_ORDER: Array[String] = [
	"cleave", "rapid_slash", "flame_field", "whirlwind",
	"thunder", "meteor_blade", "guardian_blade", "moon_barrier",
	"dash_blade", "targeting", "time_cut", "blood_pact",
	"aura", "shield_bash", "execution", "recursion",
	"cross_cut", "blade_fan", "gravity_well", "lion_roar",
	"phantom_step", "sword_rain", "boomerang_blade", "battle_trance",
	"holy_pulse", "earth_splitter", "thrust", "frost_ring"
]
const ATLAS_COLUMNS := 7
const ATLAS_ROWS := 4
const ICON_CELL := 32       # 원본 셀. ×2 = 64 → 아틀라스 448×256 (기존과 동일)
const ICON_PLATE := 26      # 판 한 변. 28칸 전부 이 크기의 경계상자를 갖는다(규칙 5)
const ICON_MARGIN := 3      # 판 바깥 투명 여백. ×2 = 6 > TILE_RING(4) (규칙 6)
const ICON_GLYPH := 20      # 글리프 격자
const GLYPH_AT := ICON_MARGIN + (ICON_PLATE - ICON_GLYPH) / 2   # = 6

# 카드 → 원소 / 형태. `deal_card_library.gd`의 SKILLS 28장에서 옮겨 적었고
# `_verify_cards()`가 빌드 때마다 원본과 대조한다(어긋나면 assert로 죽는다).
const CARD_ELEMENT := {
	"flame_field": "fire", "meteor_blade": "fire", "earth_splitter": "fire", "lion_roar": "fire",
	"dash_blade": "ice", "frost_ring": "ice", "guardian_blade": "ice", "moon_barrier": "ice",
	"thunder": "thunder", "time_cut": "thunder", "targeting": "thunder", "phantom_step": "thunder",
	"whirlwind": "poison", "blood_pact": "poison", "execution": "poison", "cross_cut": "poison",
	"gravity_well": "oil", "sword_rain": "oil", "aura": "oil", "boomerang_blade": "oil",
	"cleave": "strike", "rapid_slash": "strike", "thrust": "strike", "recursion": "strike",
	"shield_bash": "psi", "holy_pulse": "psi", "battle_trance": "psi", "blade_fan": "psi"
}
const CARD_FORM := {
	"flame_field": "trap", "meteor_blade": "trap", "earth_splitter": "pierce", "lion_roar": "wave",
	"dash_blade": "slash", "frost_ring": "wave", "guardian_blade": "guard", "moon_barrier": "guard",
	"thunder": "wave", "time_cut": "slash", "targeting": "pierce", "phantom_step": "guard",
	"whirlwind": "wave", "blood_pact": "slash", "execution": "slash", "cross_cut": "slash",
	"gravity_well": "trap", "sword_rain": "trap", "aura": "trap", "boomerang_blade": "pierce",
	"cleave": "slash", "rapid_slash": "slash", "thrust": "pierce", "recursion": "pierce",
	"shield_bash": "guard", "holy_pulse": "wave", "battle_trance": "guard", "blade_fan": "pierce"
}

# 형태 5종 = 판 실루엣 5종. **색(원소)과 모양(형태)이 서로 다른 축을 나른다** —
# 색약이거나 아이콘이 22px로 줄어들어 글리프가 뭉개져도 최소한 형태는 남는다.
#   slash  … 우상·좌하 모서리를 크게 베어 낸 사각 (칼자국)
#   pierce … 오른쪽이 뾰족한 화살촉
#   wave   … 원
#   trap   … 모서리를 조금 깎은 팔각(네모에 가깝다 — 바닥에 놓는 것)
#   guard  … 위는 각지고 아래로 좁아지는 방패
const GLYPH_INK := "#"
const GLYPH_LIGHT := "o"
const GLYPH_MID := "+"

# 28칸 글리프. 20×20 · 문자 4종("." 투명 / "#" 잉크 / "o" 크림 / "+" 중간톤).
# 판독성 기준(직접 렌더해서 22px·32px·64px로 눈으로 확인했다):
#   * 모든 획은 2px 이상. 1px 선은 22px에서 사라진다.
#   * 시각 요소는 3개 이하. "7회 타격"이어도 3개만 그린다.
#   * 0행·19행·0열·19열은 비운다(판 테두리와 붙으면 형태가 뭉개진다).
const SKILL_GLYPHS := {
	"cleave": [
		"....................",
		"....................",
		"....................",
		"....................",
		".............###....",
		".............###....",
		".............####...",
		"..............###...",
		".............#####..",
		"............#o####..",
		"...........#o#####..",
		"..........#o######..",
		".........#o######...",
		"....###.#o#######...",
		"....############....",
		"....###########.....",
		"......########......",
		"........####........",
		"....................",
		"....................",
	],
	"rapid_slash": [
		"....................",
		"....................",
		".###..###..###......",
		".###..###..###......",
		".###..###..###......",
		"..###..###..###.....",
		"..###..###..###.....",
		"..###..###..###.....",
		"...###..###..###....",
		"...###..###..###....",
		"...###..###..###....",
		"....###..###..###...",
		"....###..###..###...",
		"....###..###..###...",
		".....###..###..###..",
		".....###..###..###..",
		".....###..###..###..",
		"......###..###..###.",
		"....................",
		"....................",
	],
	"flame_field": [
		"....................",
		"....................",
		"....................",
		".......##...........",
		"......###...........",
		".....###............",
		"....####............",
		"...#####........##..",
		"..######.......###..",
		"..##oo##......###...",
		"..##oo##.....####...",
		"..##oo##....#oo##...",
		"...#oo##....#oo##...",
		"...####.....#oo##...",
		"....###......###....",
		"..################..",
		"..###oooooooooo###..",
		"..################..",
		"....................",
		"....................",
	],
	"whirlwind": [
		"....................",
		"....................",
		"..################..",
		"..###ooooooooo####..",
		"...#########........",
		"...#########....#...",
		"....############....",
		"....##ooooooo###....",
		".....##########.....",
		".....#....#####.....",
		"..........####......",
		"......########......",
		".......#oooo#.......",
		".......######.......",
		"........##..........",
		"........####........",
		".........##.........",
		".........##.........",
		"....................",
		"....................",
	],
	"thunder": [
		"....................",
		"....................",
		"..###.....#####.....",
		".#oo##...###o#......",
		".#oo##..###o#.......",
		"..###..###o#........",
		"......###o#.........",
		".....###o#..........",
		"....####oooo##......",
		".....#########......",
		".........###o#......",
		"........###o#.......",
		".......###o#........",
		"......###o#....###..",
		".....###o#....#oo##.",
		"....#####.....#oo##.",
		"....###........###..",
		"....##..............",
		"....................",
		"....................",
	],
	"meteor_blade": [
		"....................",
		"............###.....",
		"...###......####....",
		"...####......#o##...",
		"...#####......#o##..",
		"....##o###.....#o#..",
		".....##o###.....##..",
		"......##o###........",
		".......##o###.......",
		"........##o###......",
		"..........#####.....",
		"...........####.....",
		"............###.....",
		"....................",
		"....................",
		"............##......",
		"..........######....",
		"........###oooo###..",
		"........##########..",
		"....................",
	],
	"guardian_blade": [
		"....................",
		".........##.........",
		".........##.........",
		"........####........",
		"........####........",
		"......########......",
		".....###....###.....",
		".....##......##.....",
		"...###..####..###...",
		".#####..#oo#..#####.",
		".#####..#oo#..#####.",
		"...###..####..###...",
		".....##......##.....",
		".....###....###.....",
		"......########......",
		"........####........",
		"....................",
		"....................",
		"....................",
		"....................",
	],
	"moon_barrier": [
		"....................",
		"....................",
		"..################..",
		"..################..",
		"..################..",
		"..###..........###..",
		"..###..oo......###..",
		"..###..oo......###..",
		"..###.ooo......###..",
		"..###.ooo......###..",
		"..###.ooo......###..",
		"...###oooo....###...",
		"...###.oooooo.###...",
		"....###.oooo.###....",
		"....####....####....",
		".....##########.....",
		".......######.......",
		"........####........",
		"....................",
		"....................",
	],
	"dash_blade": [
		"....................",
		"....................",
		"....................",
		"....................",
		"......#####.........",
		".####..###o#........",
		".####...###o#.......",
		".####....###o#......",
		"..........###o#.....",
		"...........###o#....",
		".########...###o#...",
		".########....###o#..",
		".########.....###o#.",
		"................#o#.",
		".................##.",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
	],
	"targeting": [
		"....................",
		"....................",
		"............##......",
		"............##......",
		"............##......",
		"...........#####....",
		"....##....#######...",
		"....##...###...###..",
		"....####.##.....##..",
		".##########.oo..##..",
		".##########.oo..##..",
		"....####.##.....##..",
		"....##...###...###..",
		"....##....#######...",
		"...........#####....",
		"............##......",
		"............##......",
		"............##......",
		"....................",
		"....................",
	],
	"time_cut": [
		"....................",
		"....................",
		"....................",
		"....................",
		"...##..........##...",
		"...####......####...",
		"....#o##....##o#....",
		".....#o##..##o#.....",
		"......#o####o#......",
		".......#o##o#.......",
		"........#oo#........",
		".......##oo##.......",
		"......##o##o##......",
		".....##o#..#o##.....",
		"....####....####....",
		"....##........##....",
		"....................",
		"....................",
		"....................",
		"....................",
	],
	"blood_pact": [
		"....................",
		"....................",
		"....................",
		".........####.......",
		"........##o#........",
		".......##o#.........",
		"......##o#..........",
		".....##o#...........",
		"....##o#......##....",
		"...##o#......####...",
		"..##o#......######..",
		".##o#.......#oo###..",
		".###.......##oo####.",
		".##........########.",
		"...........########.",
		"............######..",
		".............####...",
		"..............##....",
		"....................",
		"....................",
	],
	"aura": [
		"....................",
		"....................",
		".....####..####.....",
		"....############....",
		"....############....",
		"....############....",
		"....############....",
		"...#####....#####...",
		"..#####.####.#####..",
		".#####..#oo#..#####.",
		".#####..#oo#..#####.",
		".######.####.######.",
		"..#####......#####..",
		"....#####..#####....",
		"....############....",
		"....############....",
		"....############....",
		".....####..####.....",
		"....................",
		"....................",
	],
	"shield_bash": [
		"....................",
		"....................",
		"....................",
		".##########.....###.",
		".##########...#####.",
		".##########..######.",
		".##########..####...",
		".####oo####..##.....",
		".###oooo###.........",
		".###oooo###.#######.",
		".####oo####.#######.",
		".##########.........",
		".##########.........",
		"..########...##.....",
		"..########...####...",
		"...######....######.",
		"....####......#####.",
		".....##.........###.",
		"....................",
		"....................",
	],
	"execution": [
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"....###.............",
		".#####..###.........",
		".#####..#######.....",
		".################...",
		".################...",
		"....#############...",
		"....ooo##########...",
		"....ooooooo######...",
		"......##oooooooo#...",
		"..........##oooo#...",
		"..............###...",
		"....................",
		"....................",
		"....................",
		"....................",
	],
	"recursion": [
		"....................",
		"....................",
		"....................",
		"..###############...",
		"..###############...",
		"..###############...",
		"..............###...",
		"..............###...",
		"..............###...",
		"..............###...",
		"..............###...",
		"......##......###...",
		".....###......###...",
		"...##############...",
		"..###############...",
		"...##############...",
		".....###............",
		".......#............",
		"....................",
		"....................",
	],
	"cross_cut": [
		"....................",
		"....................",
		".........##.........",
		".........##.........",
		"........####........",
		"........####........",
		"........#o##........",
		"........#o##........",
		"....#####o######....",
		"..####oooooooo####..",
		"..#######o########..",
		"....#####o######....",
		"........#o##........",
		"........#o##........",
		"........####........",
		"........####........",
		".........##.........",
		".........##.........",
		"....................",
		"....................",
	],
	"blade_fan": [
		"....................",
		"....................",
		".............##.....",
		"............###.....",
		"..........#####.....",
		".........#####......",
		".......#####........",
		"......#####.........",
		"...#######..........",
		"..##o##############.",
		"..#oo##############.",
		"..################..",
		".....#####..........",
		"......#####.........",
		"........#####.......",
		".........#####......",
		"...........####.....",
		"............###.....",
		"....................",
		"....................",
	],
	"gravity_well": [
		"....................",
		"........####........",
		"........#oo#........",
		"........#oo#........",
		"........#oo#........",
		"........#oo#........",
		"........#oo#........",
		"........#oo#........",
		"........####........",
		".###..########..###.",
		".###...######...###.",
		".###....####....###.",
		".####...####...####.",
		"..###....##....###..",
		"..####........####..",
		"...#####....#####...",
		"....############....",
		".....##########.....",
		"........####........",
		"....................",
	],
	"lion_roar": [
		"....................",
		"....................",
		"....................",
		".......##.....###...",
		"......####.##..##...",
		".....#####.##..###..",
		"....#####..###..##..",
		"...#####....##..##..",
		"..#####.....##..##..",
		".##oo#......##..##..",
		".##oo#......##..##..",
		"..#####.....##..##..",
		"...#####....##..##..",
		"....#####..###..##..",
		".....#####.##..###..",
		"......####.##..##...",
		".......##.....###...",
		"....................",
		"....................",
		"....................",
	],
	"phantom_step": [
		"....................",
		"....................",
		"....................",
		"..###...............",
		"..###...###.........",
		"..###...#+#...+++...",
		".#####..#+#...+++...",
		".#####.#+++#..+++...",
		".#####.#+++#.+++++..",
		".#####.#+++#.+++++..",
		".#####.#+++#.+++++..",
		".#####.#+++#.+++++..",
		".#####.#+++#.+++++..",
		"..###...#+#...+++...",
		"..###...#+#...+++...",
		"..###...#+#...+++...",
		"..###...###...+++...",
		"....................",
		"....................",
		"....................",
	],
	"sword_rain": [
		"....................",
		"...###..###..###....",
		"...#o#..###..#o#....",
		"...#o#..#o#..#o#....",
		"...#o#..#o#..#o#....",
		"...#o#..#o#..#o#....",
		"...#o#..#o#..#o#....",
		"...#o#..#o#..#o#....",
		"...#o#..#o#..#o#....",
		"...###..#o#..###....",
		"...###..#o#..###....",
		"...###..###..###....",
		"...###..###..###....",
		"...###..###..###....",
		"...##############...",
		"..################..",
		"..################..",
		"..################..",
		"...##############...",
		"....................",
	],
	"boomerang_blade": [
		"....................",
		"....................",
		".........#####......",
		"..........#####.....",
		"...........#####....",
		"...........o#####...",
		"............o####...",
		"............o####...",
		"............o####...",
		"............o####...",
		"...........oo####...",
		"...........o####....",
		"......#...#####.....",
		".....##..#####......",
		"...####..###........",
		"..#####.............",
		"..###########.......",
		"....##########......",
		"......########......",
		"....................",
	],
	"battle_trance": [
		"....................",
		"....................",
		".........##.........",
		".....##########.....",
		"....############....",
		"....#####..#####....",
		"....##........##....",
		"....................",
		".........##.........",
		"........####........",
		"........####........",
		"........####........",
		"........####........",
		"......###oo###......",
		".....##oooooo##.....",
		"....###oooooo###....",
		"....#####oo#####....",
		"....#####oo#####....",
		"...##############...",
		"....................",
	],
	"holy_pulse": [
		"....................",
		"......########......",
		".....##########.....",
		"...####......####...",
		"...##..######..##...",
		"..##.##########.##..",
		".###.##......##.###.",
		".##.##...##...##.##.",
		".##.##..####..##.##.",
		".##.##.##oo##.##.##.",
		".##.##.##oo##.##.##.",
		".##.##..####..##.##.",
		".##.##...##...##.##.",
		".###.##......##.###.",
		"..##.##########.##..",
		"...##..######..##...",
		"...####......####...",
		".....##########.....",
		"......########......",
		"....................",
	],
	"earth_splitter": [
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"............##......",
		"......##....##......",
		"......##....####....",
		"....############....",
		"..##ooooooooooo###..",
		"..################..",
		"....############....",
		"........##..####....",
		"........##..##......",
		"............##......",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
	],
	"thrust": [
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"....##....##........",
		"....##....###.......",
		"....##....#####.....",
		".################...",
		".###########ooo###..",
		".################...",
		"....##....#####.....",
		"....##....###.......",
		"....##....##........",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
	],
	"frost_ring": [
		"....................",
		"......########......",
		"....############....",
		"...####......####...",
		"..###....##....###..",
		"..##...######...##..",
		".###..###..###..###.",
		".##..##......##..##.",
		".##..##..##..##..##.",
		".##.##..#oo#..##.##.",
		".##.##..#oo#..##.##.",
		".##..##..##..##..##.",
		".##..##......##..##.",
		".###..###..###..###.",
		"..##...######...##..",
		"..###....##....###..",
		"...####......####...",
		"....############....",
		"......########......",
		"....................",
	],
}

# =============================================================================
# 2. 진입점
# =============================================================================
func _init() -> void:
	var started := Time.get_ticks_msec()
	_verify_cards()
	_build_demon_portraits()
	_build_demon_king_sheet()
	_build_skill_atlas()
	_build_slot_art()
	_build_currency()
	_build_chest()
	_build_status_vfx()
	print("BUILD_ASSETS_Y_COMPLETE files=%d ms=%d" % [_written.size(), Time.get_ticks_msec() - started])
	for path: String in _written:
		print("  ", path)
	quit()

# 카드 데이터와 이 파일의 표가 어긋나면 즉시 죽는다. 아이콘이 엉뚱한 카드에
# 붙는 것은 조용히 지나가면 안 되는 종류의 사고다.
func _verify_cards() -> void:
	assert(SKILL_ORDER.size() == ATLAS_COLUMNS * ATLAS_ROWS, "셀 수가 28이 아닙니다")
	var seen := {}
	for id: String in SKILL_ORDER:
		assert(not seen.has(id), "중복 id: " + id)
		seen[id] = true
		var card: Dictionary = DealCardLibrary.by_id(id)
		assert(not card.is_empty(), "카드를 못 찾았습니다: " + id)
		assert(String(card["element"]) == String(CARD_ELEMENT[id]),
			"원소 불일치 %s: %s vs %s" % [id, card["element"], CARD_ELEMENT[id]])
		assert(String(card["form"]) == String(CARD_FORM[id]),
			"형태 불일치 %s: %s vs %s" % [id, card["form"], CARD_FORM[id]])
		assert(SKILL_GLYPHS.has(id), "글리프가 없습니다: " + id)
		var rows: Array = SKILL_GLYPHS[id]
		assert(rows.size() == ICON_GLYPH, "%s 글리프 행 수 %d" % [id, rows.size()])
		for row: String in rows:
			assert(row.length() == ICON_GLYPH, "%s 글리프 열 수 %d" % [id, row.length()])

# =============================================================================
# 3. 마왕 초상 2종
# =============================================================================
# 사용자 피드백 ①: 필드 토스트·밀정 화면이 아직 구버전 마왕(검은 사각형 + 뿔,
# `pixel_portrait.gd`의 벡터 드로잉)을 쓴다. 새 마왕은 `Actor/Boss/GiantRedSamurai`
# — 초승달 투구를 쓴 붉은 오니 사무라이다(§4 필드 스프라이트와 같은 원본).
#
# 큰 것과 작은 것의 **원본이 다르다.** 일부러 그렇게 했다.
#   대형(96) ← `Faceset.png` 38×38. NA가 대화창용으로 따로 그린 초상이라
#             주름·송곳니·투구 문양까지 살아 있다.
#   소형(48) ← `Idle.png` 프레임 0의 머리 20×20. Faceset을 줄이면 픽셀이
#             깨지므로 **줄이지 않고**, 애초에 작게 그려진 필드 스프라이트의
#             머리를 그대로 쓴다. 16px 밀도로 그려진 그림이라 48px에서
#             "금색 초승달 + 붉은 얼굴 + 흰 송곳니"가 그대로 읽힌다.
# 둘 다 ×2라 화면 픽셀 크기는 완전히 같다.
const BOSS_DIR := NA + "Actor/Boss/GiantRedSamurai/"
## Idle.png는 **576×48 = 96×48 프레임 6장**이다(빈 열 실측: 0-12 / 83-108 / …).
## 48×48 12장이 아니다 — 사무라이가 쌍검을 들어 폭이 70px이기 때문이다.
const BOSS_IDLE_FRAME := Vector2i(96, 48)
## 프레임 0 안에서 머리(초승달 위 끝 ~ 송곳니 아래)를 감싸는 20×20.
const BOSS_HEAD_SRC := Rect2i(38, 6, 20, 20)

func _build_demon_portraits() -> void:
	# 대형 96×96 — 액자 여백 3 + 얼굴 38 + 여백 3 = 48(원본)
	var faceset := _src(BOSS_DIR + "Faceset.png")
	var large := _portrait_frame(48, 2)
	large.blend_rect(faceset, Rect2i(0, 0, 38, 38), Vector2i(5, 5))
	_save(large, "portrait-demon-lord-96.png")

	# 소형 48×48 — 액자 여백 2 + 머리 20 + 여백 2 = 24(원본)
	var idle := _src(BOSS_DIR + "Idle.png")
	var small := _portrait_frame(24, 1)
	small.blend_rect(idle, BOSS_HEAD_SRC, Vector2i(2, 2))
	_save(small, "portrait-demon-lord-48.png")

## abyss 톤 액자. 1px 잉크 테두리 + `bevel`px 베벨(위 밝고 아래 어둡다) + 심연색 바탕.
func _portrait_frame(size: int, bevel: int) -> Image:
	var img := _canvas(size, size)
	for y in size:
		for x in size:
			var depth: int = mini(mini(x, y), mini(size - 1 - x, size - 1 - y))
			var c: Color
			if depth == 0:
				c = INK
			elif depth <= bevel:
				if y < x and y < size - 1 - x:
					c = ABYSS["hi"]
				elif y > x and y > size - 1 - x:
					c = ABYSS["lo"]
				else:
					c = ABYSS["mid"]
			else:
				c = ABYSS["fill"]
			img.set_pixel(x, y, c)
	return img

# =============================================================================
# 3b. 마왕 필드 시트 재슬라이스 — `boss-demon-king-v2.png`
# =============================================================================
# **실측으로 찾은 버그다.** `Actor/Boss/GiantRedSamurai/Idle.png`는 576×48이고
# ASSET_MAP §4는 이걸 "48×48 프레임 12장"으로 적고 있다. 그런데 빈 열을 실측하면
# 내용 덩어리가 **6개**이고(0-12 / 83-108 / 179-204 / … 비어 있음) 폭이 70px다 —
# 쌍검을 벌린 사무라이가 48px에 들어갈 리 없다. **실제 규격은 96×48 6프레임**이다.
#
# 그 결과 현재 `boss-demon-king.png`(셀 144×288)는 사무라이 하나가 셀 두 칸에
# 걸쳐 구워져 있고, `enemy.gd`가 셀 하나를 그리면 **마왕의 절반만** 나온다.
# 구워진 시트의 행 0 내용 덩어리는 x 39-248 / 327-536 / … 로 폭 210 · 간격 288 —
# 셀 경계(144의 배수)와 어긋난다.
#
# 여기서는 **원본을 안 건드리고** 같은 계약(1728×2880 · 셀 144×288 · mask_y 1440 ·
# foot 0 · 행별 프레임 수 12/12/8/8/8)을 그대로 지키는 교체본을 따로 굽는다.
#   * 배율을 ×3 → **×2**로 낮춘다. 프레임 실폭 70을 ×3 하면 210 > 144라 애초에
#     못 담는다. 72×2 = 144 = 셀 폭이 정확히 맞는다.
#   * 실프레임 6/6/4/4/4장을 **한 장씩 두 번** 넣어 12/12/8/8/8을 채운다.
#     같은 그림을 두 프레임 유지하는 것뿐이라 애니메이션은 절반 속도로 정상 재생된다.
#   * 파일명이 다르므로 `build_assets.gd`의 산출물을 덮지 않는다. 쓰려면
#     `enemy.gd`의 `"tex": preload(...)` **한 줄만** 바꾸면 되고 상수는 그대로다.
const BOSS_V2_SOURCE := [
	# [파일, 실프레임 수, 프레임 폭, 프레임 높이, 목표 행, 목표 칸 수]
	["Idle.png", 6, 96, 48, 0, 12],
	["Walk.png", 6, 96, 48, 1, 12],
	["Hit.png", 4, 96, 48, 2, 8],
	["AttackRight.png", 4, 96, 96, 3, 8],
	["AttackLeft.png", 4, 96, 96, 4, 8]
]
const BOSS_V2_CELL := Vector2i(72, 144)     # ×2 하면 144×288 = 기존 계약
const BOSS_V2_WINDOW_X := 12                # 96px 프레임에서 잘라 낼 72px 창의 왼쪽
const BOSS_V2_COLUMNS := 12
const BOSS_V2_ROWS := 5

func _build_demon_king_sheet() -> void:
	var art := _canvas(BOSS_V2_COLUMNS * BOSS_V2_CELL.x, BOSS_V2_ROWS * BOSS_V2_CELL.y)
	for entry: Array in BOSS_V2_SOURCE:
		var source := _src(BOSS_DIR + String(entry[0]))
		var real: int = int(entry[1])
		var frame_w: int = int(entry[2])
		var frame_h: int = int(entry[3])
		var row: int = int(entry[4])
		var slots: int = int(entry[5])
		for slot in slots:
			var frame: int = mini(real - 1, slot * real / slots)
			var region := Rect2i(frame * frame_w + BOSS_V2_WINDOW_X, 0, BOSS_V2_CELL.x, frame_h)
			# 바닥 정렬. 대기(48)와 공격(96)의 접지선이 같아야 전환에서 안 튄다.
			var at := Vector2i(slot * BOSS_V2_CELL.x, row * BOSS_V2_CELL.y + BOSS_V2_CELL.y - frame_h)
			art.blend_rect(source, region, at)
	_save(_with_mask(art), "boss-demon-king-v2.png")

## 캐릭터 시트는 아래쪽에 흰 실루엣 마스크를 한 벌 더 붙인다(형제 빌더와 같은 규약).
func _with_mask(img: Image) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var out := _canvas(width, height * 2)
	out.blit_rect(img, Rect2i(0, 0, width, height), Vector2i.ZERO)
	for y in height:
		for x in width:
			var alpha := img.get_pixel(x, y).a
			if alpha > 0.0:
				out.set_pixel(x, y + height, Color(1.0, 1.0, 1.0, alpha))
	return out

# =============================================================================
# 4. 스킬 아이콘 아틀라스 28칸
# =============================================================================
func _build_skill_atlas() -> void:
	var sheet := _canvas(ATLAS_COLUMNS * ICON_CELL, ATLAS_ROWS * ICON_CELL)
	for index in SKILL_ORDER.size():
		var id: String = SKILL_ORDER[index]
		var cell := _skill_cell(id)
		var at := Vector2i((index % ATLAS_COLUMNS) * ICON_CELL, (index / ATLAS_COLUMNS) * ICON_CELL)
		sheet.blit_rect(cell, Rect2i(0, 0, ICON_CELL, ICON_CELL), at)
	_save(sheet, "ui-skill-icons.png")
	_save(sheet, LEGACY_SKILL_ATLAS, SCALE, true)

func _skill_cell(id: String) -> Image:
	var element: String = CARD_ELEMENT[id]
	var form: String = CARD_FORM[id]
	var base: Color = ELEMENT_COLOR[element]
	var img := _canvas(ICON_CELL, ICON_CELL)
	var mask := _plate_mask(form)
	var hi := base.lerp(Color.WHITE, 0.34)
	var lo := base.lerp(INK, 0.34)
	for y in ICON_PLATE:
		for x in ICON_PLATE:
			if not mask[y * ICON_PLATE + x]:
				continue
			var edge := false
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + step.x
				var ny := y + step.y
				if nx < 0 or ny < 0 or nx >= ICON_PLATE or ny >= ICON_PLATE or not mask[ny * ICON_PLATE + nx]:
					edge = true
			var c: Color
			if edge:
				c = INK
			else:
				var top_open: bool = true if y == 0 else not mask[(y - 1) * ICON_PLATE + x]
				if y <= 2 or top_open:
					c = hi
				else:
					c = base.lerp(lo, float(y) / float(ICON_PLATE - 1))
			img.set_pixel(ICON_MARGIN + x, ICON_MARGIN + y, c)
	var rows: Array = SKILL_GLYPHS[id]
	for gy in rows.size():
		var line: String = rows[gy]
		for gx in line.length():
			var ch := line[gx]
			if ch == "." or ch == " ":
				continue
			var px := GLYPH_AT + gx
			var py := GLYPH_AT + gy
			var under := img.get_pixel(px, py)
			if under.a <= 0.0:
				continue    # 판 바깥으로 삐져나온 글리프 픽셀은 버린다
			match ch:
				GLYPH_INK: img.set_pixel(px, py, INK)
				GLYPH_LIGHT: img.set_pixel(px, py, CREAM)
				GLYPH_MID: img.set_pixel(px, py, under.lerp(INK, 0.55))
	return img

## 형태 5종의 26×26 판 마스크. **어느 형태든 경계상자가 정확히 26×26이다**(규칙 5).
func _plate_mask(form: String) -> PackedByteArray:
	var n := ICON_PLATE
	var mask := PackedByteArray()
	mask.resize(n * n)
	var half := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var cx := float(x) - half
			var cy := float(y) - half
			var keep := true
			match form:
				"wave":
					keep = (cx * cx + cy * cy) <= float(n * n) * 0.25 - 0.5
				"trap":
					keep = absf(cx) + absf(cy) <= float(n) * 0.84
				"guard":
					if float(y) <= float(n) * 0.55:
						keep = true
					else:
						var t := (float(y) - float(n) * 0.55) / (float(n) * 0.45)
						keep = absf(cx) <= (float(n) * 0.5) * (1.0 - 0.72 * t * t)
				"pierce":
					if float(x) <= float(n) * 0.62:
						keep = true
					else:
						var t := (float(x) - float(n) * 0.62) / (float(n) * 0.38)
						keep = absf(cy) <= (float(n) * 0.5) * (1.0 - 0.88 * t)
				"slash":
					keep = float(x + (n - 1 - y)) <= float(n) * 1.50 \
						and float((n - 1 - x) + y) <= float(n) * 1.50
			mask[y * n + x] = 1 if keep else 0
	# 경계상자를 26×26으로 못 박는다(원·화살촉이라도 사방 끝 픽셀은 남긴다).
	for i in [0, n - 1]:
		mask[i * n + n / 2] = 1
		mask[i * n + n / 2 - 1] = 1
		mask[(n / 2) * n + i] = 1
		mask[(n / 2 - 1) * n + i] = 1
	return mask
# =============================================================================
# 5. 장비 부위 4종 — 빈 슬롯 실루엣 + 부위 배지
# =============================================================================
# 사용자 피드백 ⑤. 부위는 `item_library.gd`의 slot 키와 같은 4종이고 순서도 같다.
#   0 weapon(무기) / 1 necklace(목걸이) / 2 ring(반지) / 3 bracelet(팔찌)
# 두 시트는 **같은 픽토그램**을 쓴다.
#   실루엣 = 무채(GREY 램프). 빈 칸에 "여기엔 이런 게 들어간다"만 말하고 물러난다.
#   배지   = 같은 그림을 금색 판 위에 잉크로. 장비 카드가 부위를 크게 알린다.
# NA에는 팔찌가 없고, 있는 것(Ui/Skill Icon/Amulet·Ring)도 24×24 배경 사각에
# 갇혀 있어 넷의 굵기·시선 높이가 안 맞는다. 그래서 **넷 다 여기서 도형으로 그린다** —
# 원·타원·사각 몇 개라 결정적이고, 굵기를 한 곳에서 맞출 수 있다.
const SLOT_ORDER: Array[String] = ["weapon", "necklace", "ring", "bracelet"]
const SLOT_CELL := 20

func _build_slot_art() -> void:
	# ① 빈 슬롯 실루엣 — 무채·저대비.
	var silhouettes := _canvas(SLOT_ORDER.size() * SLOT_CELL, SLOT_CELL)
	for index in SLOT_ORDER.size():
		var cell := _slot_shape(SLOT_ORDER[index])
		_recolor(cell, GREY["mid"])
		_outline(cell, GREY["dark"])
		silhouettes.blend_rect(cell, Rect2i(0, 0, SLOT_CELL, SLOT_CELL), Vector2i(index * SLOT_CELL, 0))
	_save(silhouettes, "ui-slot-silhouettes.png")

	# ② 부위 배지 — 금판 + 잉크 픽토그램 + 크림 후광 1px(금색 위에서 형태가 뜨게).
	var badges := _canvas(SLOT_ORDER.size() * SLOT_CELL, SLOT_CELL)
	for index in SLOT_ORDER.size():
		var plate := _badge_plate(SLOT_CELL)
		var glyph := _slot_shape(SLOT_ORDER[index])
		_recolor(glyph, INK)
		_outline(glyph, GOLD_HI)
		plate.blend_rect(glyph, Rect2i(0, 0, SLOT_CELL, SLOT_CELL), Vector2i.ZERO)
		badges.blend_rect(plate, Rect2i(0, 0, SLOT_CELL, SLOT_CELL), Vector2i(index * SLOT_CELL, 0))
	_save(badges, "ui-slot-badges.png")

## 부위 픽토그램 한 장(흰 실루엣). 색은 부르는 쪽이 정한다.
## 사방 1px는 비워 둔다 — `_outline()`이 그 자리에 테두리를 그리기 때문이다.
func _slot_shape(kind: String) -> Image:
	var img := _canvas(SLOT_CELL, SLOT_CELL)
	var white := Color(1, 1, 1, 1)
	match kind:
		"weapon":
			# 위를 향한 장검. 날 4 · 날밑 10 · 자루 4 · 손잡이끝 6.
			_fill(img, Rect2i(8, 1, 4, 9), white)     # 날
			_fill(img, Rect2i(5, 10, 10, 2), white)   # 날밑
			_fill(img, Rect2i(8, 12, 4, 4), white)    # 자루
			_fill(img, Rect2i(7, 16, 6, 2), white)    # 손잡이끝
		"necklace":
			# 사슬 두 가닥이 V자로 모이고 그 끝에 보석이 달린다. 타원 고리로 그렸더니
			# 전구·돋보기로 읽혀서(실측) 목에 걸린 **모양** 자체로 바꿨다.
			for step in 10:
				var y: int = 2 + step
				var spread: int = 7 - step * 7 / 10
				_fill(img, Rect2i(9 - spread, y, 2, 1), white)
				_fill(img, Rect2i(9 + spread, y, 2, 1), white)
			_fill(img, Rect2i(8, 11, 4, 2), white)
			_disc(img, Vector2(9.5, 15.5), 3.2, white)
		"ring":
			# 두께 3의 밴드 + 위에 박힌 마름모 보석. 사이를 1px 띄워 둘이 안 붙게 한다.
			_ellipse_ring(img, Vector2(9.5, 12.5), 6.0, 6.0, 3, white)
			var gem := [2, 4, 6, 4]
			for row in gem.size():
				var w: int = gem[row]
				_fill(img, Rect2i(10 - w / 2, 1 + row, w, 1), white)
		"bracelet":
			# 구슬 팔찌. 매끈한 타원 밴드로 그리면 반지와 실루엣이 겹쳐서(실측)
			# **구슬 8개를 타원으로 꿴** 모양으로 바꿨다 — 반지와 절대 안 헷갈린다.
			for bead in 8:
				var angle := TAU * float(bead) / 8.0
				_disc(img, Vector2(9.5, 10.0) + Vector2(cos(angle) * 7.2, sin(angle) * 5.4), 2.1, white)
	return img

func _badge_plate(size: int) -> Image:
	var img := _canvas(size, size)
	var cut := 3
	for y in size:
		for x in size:
			var corner: int = mini(x, size - 1 - x) + mini(y, size - 1 - y)
			if corner < cut:
				continue
			var edge: bool = x == 0 or y == 0 or x == size - 1 or y == size - 1 or corner == cut
			var c: Color = INK if edge else (GOLD_HI if y <= 3 else GOLD.lerp(GOLD_DARK, float(y) / float(size)))
			img.set_pixel(x, y, c)
	return img

# =============================================================================
# 6. 재화 — 금화 소·대·회전·더미
# =============================================================================
# 사용자 피드백 ⑥. 상점 가격표(글자 높이)·지불 버튼·보상 팝업이 요구하는 픽셀 크기가
# 서로 다르다. 픽셀아트는 **줄이면 깨지므로 크기별로 따로 굽는다** — 한 장을 늘렸다
# 줄였다 하지 않는 것이 이 파이프라인 전체의 원칙이다.
#   ui-coin-small 16×16  가격 문자열 옆 인라인
#   ui-coin-large 40×40  지불 버튼·상점 헤더
#   ui-coin-spin  80×20  4프레임 회전(원본 `Coin2.png` 그대로 — 보상 팝업)
#   ui-coin-pile  48×32  총액·정산 요약
# 회전 4프레임만 NA 원본이고, 정지 금화 3종은 여기서 도형으로 그린다.
# 원본 `GoldCoin.png`는 7×7 **납작한 사각형**이라 크게 키우면 동전으로 안 보인다(실측).
const COIN_SRC := NA + "Items/Treasure/Coin2.png"
const COIN_8 := [
	"..####..",
	".#OOoo#.",
	"#OOoooo#",
	"#Ooooo+#",
	"#oooo++#",
	"#ooo+++#",
	".#++++#.",
	"..####.."
]

func _build_currency() -> void:
	# 8px에서는 원 판정이 사각형으로 뭉개진다(실측). 소형만 손으로 찍었다.
	_save(_bitmap(COIN_8, 8, {"#": INK, "O": CREAM, "o": GOLD, "+": GOLD_DARK}), "ui-coin-small.png")
	_save(_coin(20), "ui-coin-large.png")

	# 회전 4프레임(10×10 ×4) — 원본을 그대로 옮긴다.
	var spin := _canvas(40, 10)
	spin.blend_rect(_src(COIN_SRC), Rect2i(0, 0, 40, 10), Vector2i.ZERO)
	_save(spin, "ui-coin-spin.png")

	# 더미 — 뒤 2개 · 앞 2개 · 꼭대기 1개. 겹치는 순서가 곧 깊이다.
	var pile := _canvas(24, 16)
	var coin := _coin(12)
	# 뒤(아래 두 개) 먼저, 앞(꼭대기 한 개)을 나중에. 겹치는 순서가 곧 깊이다.
	for at: Vector2i in [Vector2i(0, 4), Vector2i(12, 4), Vector2i(6, 0)]:
		pile.blend_rect(coin, Rect2i(0, 0, 12, 12), at)
	_save(pile, "ui-coin-pile.png")

## 지름 `d`의 금화 한 장. 1px 잉크 테두리 + 안쪽 림 + 위→아래 금색 그라데이션 +
## 좌상단 하이라이트. `d`가 12 이상이면 안쪽에 각인 링을 하나 더 두른다.
func _coin(d: int) -> Image:
	var img := _canvas(d, d)
	var center := Vector2(float(d - 1) * 0.5, float(d - 1) * 0.5)
	var radius := float(d) * 0.5
	for y in d:
		for x in d:
			var distance := Vector2(float(x), float(y)).distance_to(center)
			if distance > radius - 0.5:
				continue
			var c: Color
			if distance > radius - 1.5:
				c = INK
			elif distance > radius - 2.5 and d >= 12:
				c = GOLD_DARK
			elif d >= 12 and absf(distance - (radius - 4.0)) <= 0.7:
				c = GOLD_DARK                       # 안쪽 각인 링 — 동전다움은 여기서 나온다
			else:
				c = GOLD_HI.lerp(GOLD_DARK, float(y) / float(d - 1))
				if float(x) + float(y) < float(d) * 0.55:
					c = CREAM
			img.set_pixel(x, y, c)
	return img

# =============================================================================
# 7. 상자 열기 애니메이션
# =============================================================================
# 사용자 피드백 ④. 현재 `chest_open_effect.gd`가 `draw_rect` 세 개로 상자를 흉내 내고
# 뚜껑을 위로 밀어 올린다. NA `Items/Treasure/LittleTreasureChest.png`(32×16)에는
# **닫힘·열림 두 프레임이 이미 있다.** 그 둘 사이를 6프레임으로 채운다.
#   0 닫힘 · 1 들썩(1px) · 2 열림 + 빛 트임 · 3 빛기둥 최대 + 반짝이
#   4 빛 잦아듦 + 반짝이 퍼짐 · 5 열림 유지
# 셀 32×32(×2 = 64) — 16px 상자 위로 빛이 뻗을 자리를 남긴 크기다.
const CHEST_SRC := NA + "Items/Treasure/LittleTreasureChest.png"
const CHEST_FRAMES := 6
const CHEST_CELL := 32
const CHEST_AT := Vector2i(8, 14)   # 상자 16×16의 좌상단. 바닥에서 2px 띄운다.

func _build_chest() -> void:
	var sheet := _canvas(CHEST_FRAMES * CHEST_CELL, CHEST_CELL)
	# [열림, 상자 y오프셋, 빛기둥 높이, 빛기둥 최대폭, 반짝이 반경, 반짝이 개수]
	var script := [
		[false, 0, 0, 0, 0.0, 0],
		[false, -1, 0, 0, 0.0, 0],
		[true, -1, 5, 9, 6.0, 4],
		[true, 0, 8, 13, 9.0, 6],
		[true, 0, 6, 11, 12.0, 6],
		[true, 0, 3, 7, 14.0, 3]
	]
	var center_x: int = CHEST_AT.x + 8
	for frame in CHEST_FRAMES:
		var step: Array = script[frame]
		var cell := _canvas(CHEST_CELL, CHEST_CELL)
		var top: int = CHEST_AT.y + int(step[1])
		# 바닥 그림자 — 상자가 공중에 뜨지 않게.
		for x in 14:
			cell.set_pixel(CHEST_AT.x + 1 + x, CHEST_AT.y + 16, Color(0.0, 0.0, 0.0, 0.28))
		# 빛기둥 — 뚜껑 안쪽에서 위로. 위로 갈수록 좁아지고 흐려진다.
		var beam: int = int(step[2])
		var beam_width: int = int(step[3])
		for y in beam:
			var t := float(y) / float(maxi(1, beam))
			# 위로 갈수록 **넓어진다**. 좁아지게 그렸더니 굴뚝 연기로 읽혔다(실측) —
			# 뚜껑 틈에서 빛이 새어 퍼지는 그림이어야 한다.
			var width: int = maxi(2, int(round(float(beam_width) * (0.35 + t * 0.65))))
			var alpha: float = 0.92 - t * 0.72
			for x in width:
				var px: int = center_x - width / 2 + x
				var py: int = top + 3 - y
				if px >= 0 and py >= 0 and px < CHEST_CELL and py < CHEST_CELL:
					cell.set_pixel(px, py, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, alpha))
		cell.blend_rect(_src(CHEST_SRC), Rect2i(16 if bool(step[0]) else 0, 0, 16, 16), Vector2i(CHEST_AT.x, top))
		# 반짝이 — 결정적 배치. 난수 대신 index로 각도를 만든다(빌더 규칙 3).
		var radius: float = float(step[4])
		var sparks: int = int(step[5])
		for index in sparks:
			var angle := TAU * float(index) / float(maxi(1, sparks)) - PI * 0.5 + float(frame) * 0.21
			var at := Vector2(float(center_x), float(top) + 5.0) + Vector2.from_angle(angle) * radius
			var size: int = 2 if index % 2 == 0 else 1
			var tint: Color = GOLD_HI if index % 2 == 0 else CREAM
			for dy in size:
				for dx in size:
					var px := int(at.x) + dx
					var py := int(at.y) + dy
					if px >= 0 and py >= 0 and px < CHEST_CELL and py < CHEST_CELL:
						cell.set_pixel(px, py, tint)
		sheet.blit_rect(cell, Rect2i(0, 0, CHEST_CELL, CHEST_CELL), Vector2i(frame * CHEST_CELL, 0))
	_save(sheet, "chest-open.png")

# =============================================================================
# 8. VFX 보강 — 스택 배지 · 터뜨림 버스트 · 시간 흐름
# =============================================================================
# 사용자 피드백 ③. 기존 NA + Kenney에 **없는 것 세 가지**만 만든다.
#   ① 스택 수 표시   — 독·저주가 몇 겹 쌓였는지. 기존 `vfx-status-pips.png`는
#                      상태의 **종류**만 말하고 **개수**를 말하지 못한다.
#   ② 터뜨림 버스트  — 타(打)가 쌓인 상태를 터뜨리는 순간. 불 폭발과 달라야 한다.
#   ③ 시간 느려짐/빨라짐 — 빙(氷) 둔화·가속. 두 팩 어디에도 없다.
# ①②는 **흰색 단색**으로 굽는다. 런타임 `modulate`로 상태색을 입히면 상태 5종에
# 시트 한 장으로 대응된다(색깔별로 굽지 않는 이유). ③만 색을 갖는다 — 느림은
# 청록(빙), 빠름은 노랑(뇌)이고, 그 두 색 자체가 정보라서 중립으로 두면 뜻이 준다.
const STACK_MAX := 5
const STACK_CELL := 16

func _build_status_vfx() -> void:
	_build_stack_badges()
	_build_burst()
	_build_timeflow()

## 스택 1~5. 주사위 눈 배치 — 세는 게 아니라 **모양으로 읽는다**.
func _build_stack_badges() -> void:
	var sheet := _canvas(STACK_MAX * STACK_CELL, STACK_CELL)
	var dots := [
		[Vector2i(6, 6)],
		[Vector2i(3, 3), Vector2i(9, 9)],
		[Vector2i(3, 3), Vector2i(6, 6), Vector2i(9, 9)],
		[Vector2i(3, 3), Vector2i(9, 3), Vector2i(3, 9), Vector2i(9, 9)],
		[Vector2i(3, 3), Vector2i(9, 3), Vector2i(6, 6), Vector2i(3, 9), Vector2i(9, 9)]
	]
	for count in STACK_MAX:
		var cell := _canvas(STACK_CELL, STACK_CELL)
		# 어두운 둥근 판 — 어떤 몹 색 위에서도 흰 점이 산다.
		for y in 14:
			for x in 14:
				var corner: int = mini(x, 13 - x) + mini(y, 13 - y)
				if corner < 2:
					continue
				cell.set_pixel(x + 1, y + 1, INK if corner == 2 else Color(0.08, 0.10, 0.13, 0.92))
		for dot: Vector2i in dots[count]:
			for dy in 3:
				for dx in 3:
					cell.set_pixel(dot.x + dx, dot.y + dy, CREAM)
		sheet.blit_rect(cell, Rect2i(0, 0, STACK_CELL, STACK_CELL), Vector2i(count * STACK_CELL, 0))
	_save(sheet, "vfx-stack-badge.png")

## 상태를 **터뜨리는** 순간. 불 폭발(`vfx-explosion.png`)과 구분되게 불꽃이 아니라
## **고리 + 파편**으로 만들었다 — 타(打)가 쌓인 것을 깨뜨리는 그림이다.
const BURST_FRAMES := 6
const BURST_CELL := 32

func _build_burst() -> void:
	var sheet := _canvas(BURST_FRAMES * BURST_CELL, BURST_CELL)
	var center := Vector2(15.5, 15.5)
	for frame in BURST_FRAMES:
		var cell := _canvas(BURST_CELL, BURST_CELL)
		var t := float(frame) / float(BURST_FRAMES - 1)
		var radius: float = 3.0 + t * 12.0
		var alpha: float = 1.0 - t * 0.72
		var thickness: int = 3 if frame <= 1 else (2 if frame <= 3 else 1)
		for ring_step in thickness:
			_ring(cell, center, radius - float(ring_step), Color(CREAM.r, CREAM.g, CREAM.b, alpha))
		if frame <= 1:
			_disc(cell, center, 4.5 - float(frame), CREAM)
		# 파편 8개 — 고리보다 앞서 나가고 늦게 사라진다.
		for index in 8:
			var angle := TAU * float(index) / 8.0 + PI * 0.125
			var at := center + Vector2.from_angle(angle) * (radius + 2.0 + t * 3.0)
			var shard: int = 2 if index % 2 == 0 else 1
			for dy in shard:
				for dx in shard:
					var px := int(at.x) + dx
					var py := int(at.y) + dy
					if px >= 0 and py >= 0 and px < BURST_CELL and py < BURST_CELL:
						cell.set_pixel(px, py, Color(CREAM.r, CREAM.g, CREAM.b, alpha))
		sheet.blit_rect(cell, Rect2i(0, 0, BURST_CELL, BURST_CELL), Vector2i(frame * BURST_CELL, 0))
	_save(sheet, "vfx-burst.png")

## 시간 흐름. 행 0 = 느려짐(모래 한 알 · 아래를 가리키는 청록 화살표),
## 행 1 = 빨라짐(모래 줄기 · 위를 가리키는 노랑 갈매기표 2겹).
## 몸통은 NA `Items/Object/Hourglass.png` 16×16 그대로다.
const TIME_FRAMES := 4
const TIME_CELL := 24
const HOURGLASS_SRC := NA + "Items/Object/Hourglass.png"
const TIME_SLOW := Color("67c7d4")   # GamePalette.CYAN — 빙(氷) 둔화
const TIME_FAST := Color("f4d35e")   # GamePalette.YELLOW — 뇌(雷) 가속

func _build_timeflow() -> void:
	var sheet := _canvas(TIME_FRAMES * TIME_CELL, 2 * TIME_CELL)
	for row in 2:
		var fast := row == 1
		var tint: Color = TIME_FAST if fast else TIME_SLOW
		for frame in TIME_FRAMES:
			var cell := _canvas(TIME_CELL, TIME_CELL)
			# 모래시계는 왼쪽에 붙인다. 오른쪽 8px가 화살표 자리다.
			cell.blend_rect(_src(HOURGLASS_SRC), Rect2i(0, 0, 16, 16), Vector2i(0, 4))
			# 목을 지나 떨어지는 모래. 느림은 한 알이 굼뜨게, 빠름은 세 알이 줄기로.
			var grains: int = 3 if fast else 1
			var phase: int = frame * (2 if fast else 1)
			for g in grains:
				var y: int = 13 + (phase + g * 2) % 5
				cell.set_pixel(7, y, GOLD_HI)
				if fast:
					cell.set_pixel(8, y, GOLD)
			# 방향 화살표. 느림 = 아래로 1개, 빠름 = 위로 2개. 프레임마다 1px 흐른다.
			var drift: int = frame % 2
			var arrows := _canvas(TIME_CELL, TIME_CELL)
			if fast:
				_arrow(arrows, 19, 2 - drift, true)
				_arrow(arrows, 19, 12 - drift, true)
			else:
				_arrow(arrows, 19, 8 + drift, false)
			_recolor(arrows, tint)
			_outline(arrows, INK)
			cell.blend_rect(arrows, Rect2i(0, 0, TIME_CELL, TIME_CELL), Vector2i.ZERO)
			sheet.blit_rect(cell, Rect2i(0, 0, TIME_CELL, TIME_CELL),
				Vector2i(frame * TIME_CELL, row * TIME_CELL))
	_save(sheet, "vfx-timeflow.png")

## 중심 x=`cx`, 위 끝 y=`top`인 5×8 화살표(머리 4행 + 자루 4행). 흰색으로 찍는다 —
## 색과 테두리는 부르는 쪽이 `_recolor`/`_outline`으로 입힌다.
func _arrow(img: Image, cx: int, top: int, up: bool) -> void:
	var head := [1, 3, 5, 5]
	var white := Color(1, 1, 1, 1)
	for step in 8:
		var width: int = head[step] if step < 4 else 3
		var y: int = top + (step if up else 7 - step)
		_fill(img, Rect2i(cx - width / 2, y, width, 1), white)

# =============================================================================
# 9. 유틸 — 형제 빌더와 같은 이름·같은 계약
# =============================================================================
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

## ASCII 비트맵 한 장. `palette`에 없는 문자는 투명으로 둔다.
func _bitmap(rows: Array, size: int, palette: Dictionary) -> Image:
	var img := _canvas(size, size)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if x >= size or y >= size:
				continue
			if palette.has(line[x]):
				img.set_pixel(x, y, palette[line[x]])
	return img

func _fill(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			img.set_pixel(x, y, color)

func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(float(x), float(y)).distance_to(center) <= radius:
				img.set_pixel(x, y, color)

## 반지름 `radius`의 1px 원 테두리. 각도 대신 픽셀 거리로 판정해 구멍이 안 생긴다.
func _ring(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if absf(Vector2(float(x), float(y)).distance_to(center) - radius) <= 0.5:
				img.set_pixel(x, y, color)

## 두께 `thickness`의 타원 테두리. 정규화 반지름으로 판정해 어느 비율에서도 끊기지 않는다.
func _ellipse_ring(img: Image, center: Vector2, rx: float, ry: float, thickness: int, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var nx := (float(x) - center.x) / rx
			var ny := (float(y) - center.y) / ry
			var outer := nx * nx + ny * ny
			if outer > 1.0:
				continue
			var ix := (float(x) - center.x) / maxf(0.5, rx - float(thickness))
			var iy := (float(y) - center.y) / maxf(0.5, ry - float(thickness))
			if ix * ix + iy * iy < 1.0:
				continue
			img.set_pixel(x, y, color)

## 불투명한 픽셀을 전부 `color`로 바꾼다(실루엣 재색).
func _recolor(img: Image, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, color)

## 불투명 덩어리 바깥에 1px 테두리를 두른다(8방향). 도형을 사방 1px 안쪽에
## 그려 두면 캔버스 밖으로 잘리지 않는다.
func _outline(img: Image, color: Color) -> void:
	var source := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if source.get_pixel(x, y).a > 0.0:
				continue
			var touching := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= img.get_width() or ny >= img.get_height():
						continue
					if source.get_pixel(nx, ny).a > 0.0:
						touching = true
			if touching:
				img.set_pixel(x, y, color)

## 합성은 전부 원본 좌표계에서 끝났다. 여기서 딱 한 번 정수배 nearest로 올린다.
## `absolute`가 true면 `name`을 res:// 전체 경로로 본다(스킬 아틀라스 드롭인 전용).
func _save(img: Image, name: String, scale: int = SCALE, absolute: bool = false) -> void:
	var scaled := img.duplicate() as Image
	scaled.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var path: String = name if absolute else OUT + name
	var error := scaled.save_png(ProjectSettings.globalize_path(path))
	assert(error == OK, "저장 실패: " + path)
	_written.append("%s  %d×%d" % [path, scaled.get_width(), scaled.get_height()])
