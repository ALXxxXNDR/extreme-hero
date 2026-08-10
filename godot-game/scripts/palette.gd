class_name GamePalette
extends RefCounted

# Original 16-bit fantasy palette. All runtime art is drawn from these colors.
const VOID := Color("10151f")
const VOID_SOFT := Color("192234")
const PANEL := Color("171b29")
const PANEL_LIGHT := Color("2b3347")
const TEXT := Color("fff3d0")
const MUTED := Color("b6af9b")

const GRASS := Color("4f813d")
const GRASS_DARK := Color("345f35")
const GRASS_LIGHT := Color("79a94b")
const DIRT := Color("a37b45")
const DIRT_DARK := Color("725638")
const WATER := Color("2c6592")
const WATER_DARK := Color("183e68")
const WATER_LIGHT := Color("62a9c7")
const STONE := Color("85847b")
const STONE_DARK := Color("4b5155")
const STONE_LIGHT := Color("c3bda4")
const WOOD := Color("8b5a31")
const WOOD_LIGHT := Color("c08a46")

const CYAN := Color("67c7d4")
const BLUE := Color("4f78b8")
const GREEN := Color("83c65c")
const YELLOW := Color("f4d35e")
const ORANGE := Color("e78a45")
const RED := Color("d95763")
const MAGENTA := Color("bd6ac8")
const PURPLE := Color("7563a8")
const NIGHT := Color("636f9c")

# Y4 — 원소 재배색 2색 (FEEDBACK_Y §3.2 · §3.3 "팔레트 상수를 바꾸지 말고 두 개를 신설").
# ORANGE·PURPLE은 필드·VFX·게이지가 그대로 쓰므로 **값을 건드리지 않는다.**
#   EMBER_RED  불 — 주황이 기름 갈색·번개 노랑과 붙어 흐려졌다. 불은 빨강이 직관이다.
#   OIL_BROWN  기름 — 보라 두 개(기름·정신)가 겹치던 원인. 갈색은 명도가 낮아 빨강과도 갈린다.
const EMBER_RED := Color("e2452f")
const OIL_BROWN := Color("7a5230")

static func debt_color(id: String) -> Color:
	match id:
		"multithread": return CYAN
		"firewall": return BLUE
		"overclock": return RED
		"cache": return PURPLE
		"recursion": return MAGENTA
		"targeting": return ORANGE
		"rollback": return GREEN
		"hotfix": return YELLOW
		"cleave": return ORANGE
		"haste": return CYAN
		"blood_pact": return RED
		"frost_armor": return BLUE
		"thunder": return YELLOW
		"guardian_blade": return MAGENTA
		"flame_field": return ORANGE
		"aura": return CYAN
		"wisdom": return PURPLE
		"dash_training": return GREEN
		"dash_blade": return YELLOW
		"moon_barrier": return BLUE
		_: return TEXT
