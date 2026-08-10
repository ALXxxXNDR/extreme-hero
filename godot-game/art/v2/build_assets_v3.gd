extends SceneTree
# =============================================================================
# V3 — 스테이지 개편 에셋 빌더 (v3 웨이브 · W11 파이프라인 확장)
# =============================================================================
# `build_assets.gd`(W11)는 **손대지 않는다.** 이 파일은 v3가 새로 필요로 하는
# 산출물만 굽고, v2 산출물 파일명과 절대 겹치지 않는다(원본은
# `docs/v1-archive/build_assets_v2.gd.txt`에 보존돼 있다).
#
#   godot --headless --path godot-game --script res://art/v2/build_assets_v3.gd
#   godot --headless --path godot-game --editor --quit        # 새 PNG 임포트
#
# W11에서 이어받은 규칙 3가지 (전 에셋 공통):
#   1. 확대는 오직 nearest 정수배. v3 신규 에셋은 전부 **×2**,
#      전면 오버레이(fog/vignette)만 ×1 — 마왕 ×3은 v2 그대로 유지.
#   2. 합성은 원본 좌표계(16px 격자)에서 끝내고, 마지막에 한 번만 정수배로 올린다.
#   3. 방향성 VFX는 **빌드 단계에서 +X로 굽는다.** 런타임 보정 금지.
#
# v3에서 추가된 규칙 2가지:
#   4. 색 변종(보스 강화형·원소 틴트)은 곱연산이 아니라 **HSV 회전**으로 만든다.
#      곱연산은 소스에 없는 채널을 올릴 수 없어 청색 점액을 자주로 못 바꾼다
#      (#79b8ce의 R은 0x79 — 곱해서 0xbc까지 올리면 다른 색까지 표백된다).
#      HSV 회전은 명도 대비를 그대로 보존하므로 픽셀아트 리컬러에 가장 안전하다.
#   5. Kenney 소프트 파티클은 **합성 단계에서만** bilinear로 축소한다.
#      최종 정수배는 여전히 nearest라 픽셀 격자는 깨지지 않는다.
# =============================================================================

const NA := "res://art/external/ninja-adventure/"
const KENNEY := "res://art/external/kenney-particle-pack/PNG (Transparent)/"
const OUT := "res://art/v2/"
const SCALE := 2

var _cache: Dictionary = {}
var _written: Array[String] = []

# --- 타일셋 경로 (v2와 동일) ---------------------------------------------------
const TS_WATER := NA + "Backgrounds/Tilesets/TilesetWater.png"
const TS_NATURE := NA + "Backgrounds/Tilesets/TilesetNature.png"
const TS_FLOOR := NA + "Backgrounds/Tilesets/TilesetFloor.png"
const TS_VILLAGE := NA + "Backgrounds/Tilesets/TilesetVillageAbandoned.png"
const TS_TOWERS := NA + "Backgrounds/Tilesets/TilesetTowers.png"
const TS_HOUSE := NA + "Backgrounds/Tilesets/TilesetHouse.png"
const TS_FIELD := NA + "Backgrounds/Tilesets/TilesetField.png"
const TS_CAMP := NA + "Backgrounds/Tilesets/tileset_camp.png"

# =============================================================================
# 1. 지형 바이옴 3벌 (설계 §7.2 · tuning.V3-N `STAGE_TERRAIN_ATLAS`)
# =============================================================================
# 실측(직접 크롭해서 확인):
#   `TilesetWater.png`(448×272) 안에 **동일 레이아웃 3×3 물가 블록이 4벌** 있다 —
#   잔디(0,96) / 모래(0,0) / 설원(208,0) / 자주(208,96).
#   설계가 지적한 대로 **"용암 팔레트"는 존재하지 않는다.** 자주로 대체한다.
#   설원 블록은 v3 스테이지 5단에 배정이 없어 **예비**로 남긴다(표만 기록).
#
# 블록 안의 상대 좌표는 4벌 모두 같다:
#   트인 물 = origin + (16,16) · 위쪽이 뭍인 물가 = origin + (16,0)
#   우하 모서리 = origin + (32,32)
#
# 물가 블록의 **뭍 바탕색**과 `TilesetField`의 밴드 바탕색을 히스토그램으로 맞췄다.
# 이게 어긋나면 호수 가장자리에서 색이 한 칸 튄다(W11이 잔디에서 확인한 함정).
#   잔디 블록 뭍 #adbc3a == Field(16,64) #adbc3a   → 틴트 불필요
#   모래 블록 뭍 #ffad5d == Field(16,16) #ffad5d   → 틴트 불필요
#   자주 블록 뭍 #b3957f != Field(16,160) #ffcba9  → 곱 (0.702, 0.729, 0.749)로
#                                                    **정확히** #b3957f가 된다
const TERRAIN_BIOMES := {
	"verdant": {
		"water_origin": Vector2i(0, 96),
		"grass_src": Rect2i(16, 64, 16, 16),    # Field 밴드1 잔디 #adbc3a
		"base_tint": Color(1.0, 1.0, 1.0),
		"deco_tint": Color(1.0, 1.0, 1.0),
		"outline": Color(0.27, 0.32, 0.13)      # W11 OUTLINE_SOFT 그대로(진한 올리브)
	},
	"waste": {
		"water_origin": Vector2i(0, 0),
		"grass_src": Rect2i(16, 16, 16, 16),    # Field 밴드0 모래 #ffad5d
		"base_tint": Color(1.0, 1.0, 1.0),
		"deco_tint": Color(0.94, 0.84, 0.62),   # 초록 데코를 마른 짚 쪽으로
		"outline": Color(0.35, 0.27, 0.15)      # 어두운 흙갈색
	},
	"abyss": {
		"water_origin": Vector2i(208, 96),
		"grass_src": Rect2i(16, 160, 16, 16),   # Field 밴드3 살구 #ffcba9 → 틴트
		"base_tint": Color(0.702, 0.729, 0.749),
		"deco_tint": Color(0.58, 0.54, 0.70),   # 채도 죽은 보라
		"outline": Color(0.20, 0.16, 0.25)      # 어두운 보라
	}
}

# 예비 팔레트(배정 없음 · 확장용으로만 기록):
#   설원 = water_origin (208, 0) + grass_src Rect2i(16, 208, 16, 16) (#ffffff)

# =============================================================================
# 2. 스테이지 보스 (설계 §3.1)
# =============================================================================
# 실측 프레임 수(파일 폭 ÷ 프레임 한 변):
#   DemonCyclop2 50×50  Idle 5 · Walk 6 · Hit 3            (Attack 없음)
#   GiantSlime2  62×52  Idle 5 · Hit 5 · Jump 13           (Walk/Attack 없음)
#   GiantSlime   62×52  동일 규격(청색 변종)
#   TenguRed     82×82  Idle 6 · Walk 10 · Attack 15 · Hit 8 · Trans 11
#
# **배율 판단 — 스테이지 보스는 전부 ×2, 마왕만 ×3(v2 유지).**
#   불투명 bbox 실측: 마왕 몸통 35×39(48프레임 안) → ×3 = 105×117
#                     외눈 37×33(50) → ×2 = 74×66
#                     점액 40×22(62) → ×2 = 80×44
#                     천구 53×33(82) → ×2 = 106×66 (공격 프레임 65×46 → 130×92)
#   ×3으로 구우면 외눈이 111×99가 되어 마왕(105×117)과 붙어 버린다. 최종 보스의
#   유일성이 배율에서 깨지는 것이 픽셀 크기 통일보다 큰 손해다. ×2가 정답이고,
#   덤으로 몹(32px 셀)과 같은 배율이라 화면에 세 번째 픽셀 크기가 안 생긴다.
#
# 각 보스는 애니마다 프레임 한 변이 **하나로 통일**돼 있어(마왕의 48×48 vs 48×96
# 같은 혼합이 없다) 프레임을 통째로 복사하면 원작자가 맞춰 둔 발밑 정렬이 그대로
# 보존된다. 마왕처럼 셀 아래쪽에 붙이는 보정이 필요 없다.
const BOSS_SHEETS := {
	# A · 서릿발 외눈 (1스테이지 · 빙+뇌)
	"frost-cyclops": {
		"dir": NA + "Actor/Boss/DemonCyclop2/",
		"frame": Vector2i(50, 50),
		"rows": [
			{"file": "Idle.png", "frames": 5},
			{"file": "Walk.png", "frames": 6},
			{"file": "Hit.png", "frames": 3}
		],
		# 원본은 **녹색** 외눈이다. 그런데 `mob-ogre`(Monster/Cyclope2)도 녹색 외눈이라
		# 1스테이지에서 잡몹과 보스의 팔레트·실루엣이 겹친다(실측 확인). 게다가 이름이
		# 서릿발이고 패턴이 빙+뇌다. 그래서 색상만 청록으로 돌린다 — 명도 대비는 HSV
		# 회전이라 그대로다. 되돌리려면 이 배열 한 줄을 [0.0, 1.0, 1.0]로 두면 된다.
		"hsv": [128.0, 0.82, 1.02],
		"hue_keep": [0.0, 40.0]
	},
	# B · 역병 점액왕 (2스테이지 · 독) — 이미 녹색이라 무보정
	"plague-slime": {
		"dir": NA + "Actor/Boss/GiantSlime2/",
		"frame": Vector2i(62, 52),
		"rows": [
			{"file": "Idle.png", "frames": 5},
			{"file": "Jump.png", "frames": 13},
			{"file": "Hit.png", "frames": 5}
		],
		"hsv": [0.0, 1.0, 1.0]
	},
	# B+ · 흑점액 변종 (4스테이지) — GiantSlime(청색)을 자주로 돌리고 한 단계 어둡게
	"black-slime": {
		"dir": NA + "Actor/Boss/GiantSlime/",
		"frame": Vector2i(62, 52),
		"rows": [
			{"file": "Idle.png", "frames": 5},
			{"file": "Jump.png", "frames": 13},
			{"file": "Hit.png", "frames": 5}
		],
		"hsv": [118.0, 1.05, 0.80],
		"hue_keep": [0.0, 40.0]
	},
	# C · 홍염 천구 (3스테이지 · 화+유) — 리그가 가장 풍부하다. Trans 행을 함께 굽는다.
	"crimson-tengu": {
		"dir": NA + "Actor/Boss/TenguRed/",
		"frame": Vector2i(82, 82),
		"rows": [
			{"file": "Idle.png", "frames": 6},
			{"file": "Walk.png", "frames": 10},
			{"file": "Hit.png", "frames": 8},
			{"file": "Attack.png", "frames": 15},
			{"file": "Trans.png", "frames": 11}
		],
		"hsv": [0.0, 1.0, 1.0]
	},
	# C+ · 흑천구 (5스테이지) — 같은 리그를 채도·명도만 눌러 흑화.
	#      Trans 11프레임(소형→대형 변신)을 등장 연출로 그대로 쓴다.
	#      명도를 0.52까지 떨어뜨려 봤더니 스테이지 5의 CanvasModulate(#2f2f52) ·
	#      안개 α0.24 · 비네트를 다 먹고 나면 실루엣이 배경에 묻힌다. 0.60이 하한이다.
	"black-tengu": {
		"dir": NA + "Actor/Boss/TenguRed/",
		"frame": Vector2i(82, 82),
		"rows": [
			{"file": "Idle.png", "frames": 6},
			{"file": "Walk.png", "frames": 10},
			{"file": "Hit.png", "frames": 8},
			{"file": "Attack.png", "frames": 15},
			{"file": "Trans.png", "frames": 11}
		],
		"hsv": [-14.0, 0.58, 0.60]
	}
}

# =============================================================================
# 3. 원소 VFX 5벌 (설계 §4.8 마지막 줄)
# =============================================================================
# 전부 **40×40 정사각 셀**로 통일해 굽는다(저장 후 80×80). 근거:
#   · 기존 `vfx-explosion.png`의 셀이 정확히 80이다 → `cycle_skill_effect.gd`가
#     `VFX_EXPLOSION_CELL := 80.0` 하나로 원소 시트 5벌을 전부 그릴 수 있다.
#   · 40px는 타일 한 칸과 같아 장판 판정과 그림이 어긋나지 않는다.
# 프레임은 **셀 가운데**에 놓는다 — v2 VFX 렌더러가 전부 `origin - box*0.5`로
# 그리기 때문에 중앙 정렬이 아니면 V6가 시트마다 앵커를 기억해야 한다.
const ELEMENT_CELL := 40

const ELEMENT_VFX := {
	# 빙(氷) — chill. 원본이 이미 얼음 파편이라 무보정.
	"ice": {
		"src": NA + "FX/Elemental/Ice/SpriteSheet.png",
		"frame": Vector2i(32, 32), "frames": 10, "hsv": [0.0, 1.0, 1.0]
	},
	# 독(毒) — poison. `Plant`(잎 참격 8프레임)를 독의 산성 초록으로 돌린다.
	# 전용 독 시트는 소스에 없다(실측). 잎이 흩날리는 실루엣이 "오염"으로 읽힌다.
	# 색상을 -14도(황록)로 돌려 봤더니 잎이 그냥 노랗게 떠서 "빛"으로 읽혔다.
	# +26도(에메랄드 쪽)로 돌리고 채도를 올려야 독으로 읽힌다.
	"poison": {
		"src": NA + "FX/Elemental/Plant/SpriteSheet.png",
		"frame": Vector2i(30, 28), "frames": 8, "hsv": [26.0, 1.45, 0.92]
	},
	# 화(火) — burn.
	"flame": {
		"src": NA + "FX/Elemental/Flam/SpriteSheet.png",
		"frame": Vector2i(40, 30), "frames": 5, "hsv": [0.0, 1.0, 1.0]
	},
	# 유(油) — oil. **기름 전용 시트는 없다.** `Water` 11프레임을 흑유로 굽는다.
	# 색상을 -38도로 돌리면 청록 → 올리브가 되어 "진흙"으로 읽혔다. +112도로 돌려
	# 자주 쪽으로 보내고 채도를 0.40만 남기면 검은 유막에 자주 광택이 도는 색이 된다
	# (완전 무채색이면 밤 지형에 붙어 안 보이고, 채도가 높으면 독과 헷갈린다).
	"oil": {
		"src": NA + "FX/Elemental/Water/SpriteSheet.png",
		"frame": Vector2i(40, 33), "frames": 11, "hsv": [112.0, 0.40, 0.30]
	},
	# 뇌(雷) — shock. v2 `vfx-core` 행3은 4프레임만 썼다. **5번째 프레임을 편입**한다
	# (설계 부록 B V3 ④). vfx-core.png는 v2 산출물이라 덮지 않고 별도 시트로 뺀다.
	"thunder": {
		"src": NA + "FX/Elemental/Thunder/SpriteSheet.png",
		"frame": Vector2i(32, 28), "frames": 5, "hsv": [0.0, 1.0, 1.0]
	}
}

# =============================================================================
# 4. 상태이상 핍 5종 (설계 §4.8 "적 머리 위")
# =============================================================================
# 설계는 "8×8 색 사각"이라고만 적었다. 사각 5개는 **색맹·야간 틴트에서 구분이
# 죽는다**(스테이지 5는 주기의 62%가 밤이고 CanvasModulate가 #2f2f52다).
# 그래서 같은 8×8 예산 안에서 **실루엣까지 다르게** 만든다 —
#   독=원 / 연=위로 뾰족 / 한=마름모 / 유=아래로 뾰족 / 전=지그재그.
# 색이 다 죽어도 모양으로 읽힌다. 코드 쪽 비용은 draw_rect → draw_texture_rect_region
# 한 줄 차이뿐이다.
#
# 문자: '.' 투명 · 'o' 외곽선 · 'x' 본색 · 'h' 하이라이트(본색 → 흰색 45%)
const PIP_ORDER: Array[String] = ["poison", "burn", "chill", "oil", "shock"]

const PIP_COLOR := {
	"poison": Color("83c65c"),   # GamePalette.GREEN
	"burn": Color("e78a45"),     # GamePalette.ORANGE
	"chill": Color("67c7d4"),    # GamePalette.CYAN
	"oil": Color("1b1622"),      # 흑유 — 외곽선을 반대로 밝게 준다
	"shock": Color("f4d35e")     # GamePalette.YELLOW
}

const PIP_OUTLINE := {
	"poison": Color("10151f"),
	"burn": Color("10151f"),
	"chill": Color("10151f"),
	"oil": Color("8a7fa3"),      # 검정 방울은 어두운 외곽선을 두르면 사라진다
	"shock": Color("10151f")
}

const PIP_GLYPH := {
	"poison": [
		"..oooo..",
		".ohhxxo.",
		"ohxxxxxo",
		"oxxxxxxo",
		"oxxxxxxo",
		"oxxxxxxo",
		".oxxxxo.",
		"..oooo.."
	],
	"burn": [
		"...oo...",
		"..oxxo..",
		"..ohxo..",
		".oxxxxo.",
		".oxxxxo.",
		"oxxxxxxo",
		".oxxxxo.",
		"..oooo.."
	],
	"chill": [
		"...oo...",
		"..oxxo..",
		".oxhxxo.",
		"oxxxxxxo",
		"oxxxxxxo",
		".oxxxxo.",
		"..oxxo..",
		"...oo..."
	],
	"oil": [
		"..oooo..",
		".oxxxxo.",
		"oxhxxxxo",
		"oxxxxxxo",
		".oxxxxo.",
		"..oxxo..",
		"..oxo...",
		"...o...."
	],
	"shock": [
		"....oo..",
		"...ohxo.",
		"..oxxo..",
		".oxxxoo.",
		".ooxxxo.",
		"..oxxo..",
		".oxxo...",
		".oo....."
	]
}

# =============================================================================
# 5. 시너지 발동 이펙트 5종 (설계 §4.4 ★ 포함 · §4.8 "시너지 발동")
# =============================================================================
# 한 시트 5행 × 8프레임 · 셀 48×48(저장 후 96×96).
# 각 행 = **Kenney 소프트 글로우(팽창·감쇠) 위에 NA 원소 프레임**. 픽셀아트만으로는
# "지금 뭔가 특별한 게 터졌다"가 안 읽히고, Kenney 파티클만 쓰면 스타일이 깨진다.
# 글로우는 아래 깔고 픽셀 프레임을 위에 얹어 **실루엣은 항상 픽셀아트**가 되게 했다.
#
# NA 원본 프레임 수가 행마다 다르므로 `floori(i * n / 8)`으로 8프레임에 리샘플한다
# (보간 없음 — 프레임을 고르기만 한다. 없는 중간 프레임을 지어내지 않는다).
const SYNERGY_CELL := 48
const SYNERGY_FRAMES := 8

const SYNERGY_ROWS: Array[Dictionary] = [
	# 0 ★대폭 연소 (fire × oil) — 이 설계의 간판 콤보
	{
		"key": "blaze", "src": NA + "FX/Elemental/Explosion/SpriteSheet.png",
		"frame": Vector2i(40, 40), "frames": 9, "hsv": [0.0, 1.0, 1.0],
		"kenney": "light_01.png", "glow": Color(1.00, 0.52, 0.16)
	},
	# 1 ★전도 (thunder × chill) — 최대 4체 도약
	{
		"key": "conduct", "src": NA + "FX/Elemental/Thunder/SpriteSheet.png",
		"frame": Vector2i(32, 28), "frames": 5, "hsv": [0.0, 1.0, 1.0],
		"kenney": "light_03.png", "glow": Color(0.58, 0.86, 1.00)
	},
	# 2 역병 발화 (fire × poison) — 스택 전소모 광역
	{
		"key": "plague", "src": NA + "FX/Elemental/Plant/SpriteSheet.png",
		"frame": Vector2i(30, 28), "frames": 8, "hsv": [26.0, 1.45, 0.92],
		"kenney": "smoke_04.png", "glow": Color(0.52, 0.95, 0.32)
	},
	# 3 쇄빙 (strike × chill) — 한 해제 · 넉백 ×2
	{
		"key": "shatter", "src": NA + "FX/Elemental/Ice/SpriteSheet.png",
		"frame": Vector2i(32, 32), "frames": 10, "hsv": [0.0, 1.0, 1.0],
		"kenney": "star_08.png", "glow": Color(0.72, 0.93, 1.00)
	},
	# 4 정신 붕괴 / psi 수확 (psi × 모든 상태) — 남은 지속을 환금한다
	{
		"key": "psi", "src": NA + "FX/Magic/Circle/SpriteSheetWhite.png",
		"frame": Vector2i(32, 32), "frames": 4, "hsv": [0.0, 1.0, 1.0],
		"kenney": "light_02.png", "glow": Color(0.78, 0.60, 1.00)
	}
]

# =============================================================================
# 6. 바닥 텔레그래프 링 (설계 §3.1 "발구름 → 바닥 링" · §3.3 예고 원 / 장판)
# =============================================================================
# 3행 × 8프레임 · 셀 64×64(저장 후 128×128). **전부 흰색 계열로 굽는다** —
# 원소 구분은 스프라이트 교체가 아니라 `effect_color` modulate로 한다는 W11 규약
# 그대로다(NA 참격·마법진이 흰색이라 잘 물드는 것과 같은 이유).
#   행 0 `expand` — 발구름 확산 링. A의 Attack 애니 부재를 메우는 바로 그 링이다.
#   행 1 `charge` — 예고 원. 안쪽이 8프레임에 걸쳐 차오른다(telegraph 진행도).
#   행 2 `pool`   — 잔류 장판. B의 산성 분비, C의 기름 도포, C+의 흑염 회오리.
# 원은 **정원**이다 — 이 게임은 탑다운이고 `enemy._draw`의 오라도 전부 정원이다.
const RING_CELL := 64
const RING_FRAMES := 8

func _init() -> void:
	var started := Time.get_ticks_msec()
	_build_terrain_biomes()
	_build_stage_bosses()
	_build_element_vfx()
	_build_status_pips()
	_build_synergy_vfx()
	_build_telegraph_rings()
	_build_stage_overlays()
	_build_v3_landmarks()
	print("BUILD_ASSETS_V3_COMPLETE files=%d ms=%d" % [_written.size(), Time.get_ticks_msec() - started])
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

func _stamp(dst: Image, path: String, region: Rect2i, at: Vector2i) -> void:
	dst.blend_rect(_src(path), region, at)

func _copy(dst: Image, path: String, region: Rect2i, at: Vector2i) -> void:
	dst.blit_rect(_src(path), region, at)

# 틴트를 먹인 뒤 복사/합성한다. 원본 캐시는 절대 건드리지 않는다(조각을 복제해서 칠한다).
func _tinted_piece(path: String, region: Rect2i, tint: Color) -> Image:
	var piece := _canvas(region.size.x, region.size.y)
	piece.blit_rect(_src(path), region, Vector2i.ZERO)
	_apply_tint(piece, tint)
	return piece

func _copy_tinted(dst: Image, path: String, region: Rect2i, at: Vector2i, tint: Color) -> void:
	if tint.is_equal_approx(Color.WHITE):
		_copy(dst, path, region, at)
		return
	dst.blit_rect(_tinted_piece(path, region, tint), Rect2i(Vector2i.ZERO, region.size), at)

func _stamp_tinted(dst: Image, path: String, region: Rect2i, at: Vector2i, tint: Color) -> void:
	if tint.is_equal_approx(Color.WHITE):
		_stamp(dst, path, region, at)
		return
	dst.blend_rect(_tinted_piece(path, region, tint), Rect2i(Vector2i.ZERO, region.size), at)

func _apply_tint(img: Image, multiply: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			img.set_pixel(x, y, Color(
				clampf(c.r * multiply.r, 0.0, 1.0),
				clampf(c.g * multiply.g, 0.0, 1.0),
				clampf(c.b * multiply.b, 0.0, 1.0),
				c.a
			))

# HSV 회전(규칙 4). 무채색 픽셀(외곽선 #141b1b 등)은 s≈0이라 색상 회전의 영향을
# 거의 안 받는다 — 외곽선을 지키면서 본체 색만 도는 것이 이 방식의 이점이다.
#
# `hue_keep`([lo도, hi도])은 **색상만 그대로 두는 구간**이다. 채도·명도는 그대로 먹인다.
# 쓰는 이유: NA 보스 `Hit.png`의 피격 섬광 프레임이 주황 #ff9554(색상 24도)로
# 구워져 있다. 이걸 같이 돌리면 서릿발 외눈이 **초록으로 번쩍인다**(1차 빌드에서 실제로
# 그랬다 — 3프레임짜리 Hit 행의 첫 프레임이라 피격마다 1/3이 초록이었다).
# 피격 섬광은 원소와 무관한 "맞았다" 신호라 따뜻한 색이 맞다.
func _apply_hsv(img: Image, hue_shift_deg: float, sat_mul: float, val_mul: float, hue_keep: Array = []) -> void:
	if is_zero_approx(hue_shift_deg) and is_equal_approx(sat_mul, 1.0) and is_equal_approx(val_mul, 1.0):
		return
	var hue_shift := hue_shift_deg / 360.0
	var keep_low := float(hue_keep[0]) / 360.0 if hue_keep.size() == 2 else -1.0
	var keep_high := float(hue_keep[1]) / 360.0 if hue_keep.size() == 2 else -1.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var hue := c.h
			if keep_low < 0.0 or hue < keep_low or hue > keep_high:
				hue = fposmod(hue + hue_shift, 1.0)
			img.set_pixel(x, y, Color.from_hsv(
				hue,
				clampf(c.s * sat_mul, 0.0, 1.0),
				clampf(c.v * val_mul, 0.0, 1.0),
				c.a
			))

# 캐릭터·보스 시트는 아래쪽에 흰 실루엣 마스크를 한 벌 더 붙인다(W11과 동일).
# 피격 플래시·상태이상 색조를 셰이더 없이 덧그리기 위한 것이다.
func _with_mask(img: Image) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var out := _canvas(width, height * 2)
	out.blit_rect(img, Rect2i(0, 0, width, height), Vector2i(0, 0))
	for y in height:
		for x in width:
			var alpha := img.get_pixel(x, y).a
			if alpha > 0.0:
				out.set_pixel(x, y + height, Color(1.0, 1.0, 1.0, alpha))
	return out

func _soften_outline(img: Image, region: Rect2i, outline: Color) -> void:
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if maxf(c.r, maxf(c.g, c.b)) < 0.20:
				img.set_pixel(x, y, Color(outline.r, outline.g, outline.b, c.a))

# Kenney 파티클(512×512 소프트 알파)을 목표 크기로 줄여 색을 입힌다.
# 규칙 5: 여기서만 bilinear를 쓴다. 최종 저장 배율은 여전히 nearest다.
func _kenney_glow(file: String, size: int, tint: Color, alpha: float) -> Image:
	var glow := _src(KENNEY + file).duplicate() as Image
	glow.resize(size, size, Image.INTERPOLATE_BILINEAR)
	for y in size:
		for x in size:
			var c := glow.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			glow.set_pixel(x, y, Color(tint.r * c.r, tint.g * c.g, tint.b * c.b, c.a * alpha))
	return glow

func _save(img: Image, name: String, scale: int = SCALE) -> void:
	var scaled := img.duplicate() as Image
	if scale != 1:
		scaled.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var path := OUT + name
	var error := scaled.save_png(ProjectSettings.globalize_path(path))
	assert(error == OK, "저장 실패: " + path)
	_written.append("%s  %dx%d" % [path, scaled.get_width(), scaled.get_height()])

# ======================================================================== 지형
func _build_terrain_biomes() -> void:
	for biome: String in TERRAIN_BIOMES:
		_build_terrain_atlas(biome, TERRAIN_BIOMES[biome])

func _build_terrain_atlas(biome: String, spec: Dictionary) -> void:
	# 셀 16×16 · 5열 4행 = 80×64 (저장 시 ×2 → 160×128).
	# `world_grid.gd`의 ATLAS_COLUMNS=5 / ATLAS_ROWS=4 / ATLAS_CELL_INSET=0 계약은
	# v2 아틀라스와 **완전히 동일**하다. 벌만 늘었지 규격은 한 글자도 안 바뀐다.
	var water: Vector2i = spec["water_origin"]
	var grass: Rect2i = spec["grass_src"]
	var base: Color = spec["base_tint"]
	var deco: Color = spec["deco_tint"]
	var outline: Color = spec["outline"]
	var atlas := _canvas(80, 64)
	for cell in 20:
		var at := Vector2i((cell % 5) * 16, (cell / 5) * 16)
		match cell:
			0, 3, 4:
				# 3·4는 TILE_RULES가 안 쓰는 예비 셀. 잘못 참조돼도 안 깨지게 바탕으로.
				_copy_tinted(atlas, TS_FIELD, grass, at, base)
			1:
				_copy_tinted(atlas, TS_FIELD, grass, at, base)
				_stamp_tinted(atlas, TS_NATURE, Rect2i(64, 160, 16, 16), at, deco)   # 억새 뭉치
			2:
				_copy_tinted(atlas, TS_FIELD, grass, at, base)
				_stamp_tinted(atlas, TS_NATURE, Rect2i(16, 176, 16, 16), at, deco)   # 들꽃
			5:
				_copy(atlas, TS_WATER, Rect2i(water.x + 16, water.y + 16, 16, 16), at)
			6, 7, 8, 9:
				# 6만 실사용. 7~9는 world_grid가 turn 1/2/3 회전으로 만든다.
				_copy(atlas, TS_WATER, Rect2i(water.x + 16, water.y, 16, 16), at)
			10, 11, 12, 13:
				# 12만 실사용. 나머지 세 모서리는 회전으로 만든다.
				_copy(atlas, TS_WATER, Rect2i(water.x + 32, water.y + 32, 16, 16), at)
			14:
				# 나무 데크. 4벌 공용(팔레트 블록 밖에 있는 절대 좌표) — 다리는
				# 바이옴이 바뀌어도 사람이 놓은 나무판이라 같은 게 맞다.
				_copy(atlas, TS_WATER, Rect2i(64, 208, 16, 16), at)
			15:
				_copy_tinted(atlas, TS_FIELD, grass, at, base)
				_stamp_tinted(atlas, TS_NATURE, Rect2i(0, 160, 16, 16), at, deco)    # 덤불
			16:
				_copy_tinted(atlas, TS_FIELD, grass, at, base)
				_stamp_tinted(atlas, TS_NATURE, Rect2i(272, 272, 16, 16), at, deco)  # 바위 2덩이
				_stamp_tinted(atlas, TS_NATURE, Rect2i(304, 272, 16, 16), at, deco)
			17:
				_copy(atlas, TS_FLOOR, Rect2i(16, 16, 16, 16), at)
				_stamp_tinted(atlas, TS_NATURE, Rect2i(272, 272, 16, 16), at, deco)
			18:
				# 성 안뜰 석재. **바이옴별로 물들이지 않는다** — `castle-floor.png`와
				# 같은 원본이어야 성 안팎이 이어진다(v2 ASSET_MAP §6의 계약).
				_copy(atlas, TS_FLOOR, Rect2i(16, 16, 16, 16), at)
			19:
				_copy(atlas, TS_FLOOR, Rect2i(16, 128, 16, 16), at)  # 균열/캠프 흙바닥
	for decorated_cell in [1, 2, 15, 16, 17]:
		_soften_outline(atlas, Rect2i((decorated_cell % 5) * 16, (decorated_cell / 5) * 16, 16, 16), outline)
	_save(atlas, "terrain-atlas-%s.png" % biome)

# ======================================================================== 보스
func _build_stage_bosses() -> void:
	for key: String in BOSS_SHEETS:
		var spec: Dictionary = BOSS_SHEETS[key]
		var frame: Vector2i = spec["frame"]
		var rows: Array = spec["rows"]
		var columns := 0
		for row_spec: Dictionary in rows:
			columns = maxi(columns, int(row_spec["frames"]))
		var sheet := _canvas(columns * frame.x, rows.size() * frame.y)
		for row in rows.size():
			var row_spec: Dictionary = rows[row]
			var count := int(row_spec["frames"])
			# 프레임을 통째로 복사한다. 이 보스들은 애니마다 프레임 한 변이 같아서
			# 원작자가 맞춘 발밑 정렬이 그대로 살아 있다(마왕식 하단 정렬 보정 불필요).
			_copy(
				sheet,
				String(spec["dir"]) + String(row_spec["file"]),
				Rect2i(0, 0, count * frame.x, frame.y),
				Vector2i(0, row * frame.y)
			)
		var hsv: Array = spec["hsv"]
		_apply_hsv(sheet, float(hsv[0]), float(hsv[1]), float(hsv[2]), spec.get("hue_keep", []))
		_save(_with_mask(sheet), "boss-%s.png" % key)

# ==================================================================== 원소 VFX
func _build_element_vfx() -> void:
	for key: String in ELEMENT_VFX:
		var spec: Dictionary = ELEMENT_VFX[key]
		var frame: Vector2i = spec["frame"]
		var count := int(spec["frames"])
		var strip := _canvas(count * ELEMENT_CELL, ELEMENT_CELL)
		var offset := Vector2i((ELEMENT_CELL - frame.x) / 2, (ELEMENT_CELL - frame.y) / 2)
		for index in count:
			_stamp(
				strip, String(spec["src"]),
				Rect2i(index * frame.x, 0, frame.x, frame.y),
				Vector2i(index * ELEMENT_CELL + offset.x, offset.y)
			)
		var hsv: Array = spec["hsv"]
		_apply_hsv(strip, float(hsv[0]), float(hsv[1]), float(hsv[2]))
		_save(strip, "vfx-element-%s.png" % key)

# ==================================================================== 상태 핍
func _build_status_pips() -> void:
	var strip := _canvas(PIP_ORDER.size() * 8, 8)
	for index in PIP_ORDER.size():
		var key: String = PIP_ORDER[index]
		var main: Color = PIP_COLOR[key]
		var edge: Color = PIP_OUTLINE[key]
		var high := main.lerp(Color.WHITE, 0.45)
		var glyph: Array = PIP_GLYPH[key]
		for y in 8:
			var line: String = glyph[y]
			for x in 8:
				match line[x]:
					"o":
						strip.set_pixel(index * 8 + x, y, edge)
					"x":
						strip.set_pixel(index * 8 + x, y, main)
					"h":
						strip.set_pixel(index * 8 + x, y, high)
	# 마스크를 붙여 두면 V6가 "상태 강조 플래시"를 색 없이 흰색으로 덧그릴 수 있다
	# (몹·보스 시트와 완전히 같은 규약이라 렌더 코드가 하나로 통일된다).
	_save(_with_mask(strip), "vfx-status-pips.png")

# ================================================================== 시너지 VFX
func _build_synergy_vfx() -> void:
	var sheet := _canvas(SYNERGY_FRAMES * SYNERGY_CELL, SYNERGY_ROWS.size() * SYNERGY_CELL)
	for row in SYNERGY_ROWS.size():
		var spec: Dictionary = SYNERGY_ROWS[row]
		var frame: Vector2i = spec["frame"]
		var count := int(spec["frames"])
		var glow_tint: Color = spec["glow"]
		var band := _canvas(SYNERGY_FRAMES * SYNERGY_CELL, SYNERGY_CELL)
		for index in SYNERGY_FRAMES:
			var t := float(index) / float(SYNERGY_FRAMES - 1)
			var cell_x := index * SYNERGY_CELL
			# ① Kenney 소프트 글로우 — 0.45배에서 1.15배로 팽창하며 사라진다.
			var glow_size := int(round(SYNERGY_CELL * lerpf(0.45, 1.15, t)))
			var glow_alpha := (1.0 - t) * (1.0 - t) * 0.78
			if glow_alpha > 0.004:
				var glow := _kenney_glow(String(spec["kenney"]), glow_size, glow_tint, glow_alpha)
				band.blend_rect(
					glow, Rect2i(0, 0, glow_size, glow_size),
					Vector2i(cell_x + (SYNERGY_CELL - glow_size) / 2, (SYNERGY_CELL - glow_size) / 2)
				)
			# ② NA 픽셀 프레임 — 실루엣은 항상 픽셀아트가 위에 온다.
			#    원본 프레임 수를 8로 리샘플(고르기만 한다 · 보간 없음).
			var source_index := mini(int(floor(float(index) * float(count) / float(SYNERGY_FRAMES))), count - 1)
			band.blend_rect(
				_src(String(spec["src"])),
				Rect2i(source_index * frame.x, 0, frame.x, frame.y),
				Vector2i(cell_x + (SYNERGY_CELL - frame.x) / 2, (SYNERGY_CELL - frame.y) / 2)
			)
		var hsv: Array = spec["hsv"]
		_apply_hsv(band, float(hsv[0]), float(hsv[1]), float(hsv[2]))
		sheet.blend_rect(band, Rect2i(0, 0, band.get_width(), band.get_height()), Vector2i(0, row * SYNERGY_CELL))
	_save(sheet, "vfx-synergy.png")

# ============================================================ 바닥 텔레그래프 링
func _build_telegraph_rings() -> void:
	var sheet := _canvas(RING_FRAMES * RING_CELL, 3 * RING_CELL)
	for index in RING_FRAMES:
		var t := float(index) / float(RING_FRAMES - 1)
		_draw_expand_ring(sheet, Vector2i(index * RING_CELL, 0), t)
		_draw_charge_ring(sheet, Vector2i(index * RING_CELL, RING_CELL), t)
		_draw_pool(sheet, Vector2i(index * RING_CELL, 2 * RING_CELL), index)
	_save(sheet, "vfx-telegraph-ring.png")

func _ring_center() -> Vector2:
	return Vector2(float(RING_CELL) * 0.5 - 0.5, float(RING_CELL) * 0.5 - 0.5)

# 행 0 — 발구름 확산 링. 반경 8 → 30, 두께 4 → 1, 알파 1.0 → 0.18.
func _draw_expand_ring(dst: Image, origin: Vector2i, t: float) -> void:
	var center := _ring_center()
	var radius := lerpf(8.0, 30.0, t)
	var thickness := lerpf(4.0, 1.0, t)
	var alpha := lerpf(1.0, 0.18, t * t)
	for y in RING_CELL:
		for x in RING_CELL:
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var band := absf(distance - radius)
			if band > thickness * 0.5:
				continue
			# 안쪽 절반은 밝게, 바깥 절반은 반투명하게 — 1px이라도 진행 방향이 읽힌다.
			var inner := distance < radius
			dst.set_pixel(origin.x + x, origin.y + y, Color(1.0, 1.0, 1.0, alpha * (1.0 if inner else 0.62)))
	_draw_ticks(dst, origin, radius, alpha * 0.8)

# 링에 8방향 눈금. 정원만 그리면 크기 변화가 안 읽혀서 확산 속도가 안 보인다.
func _draw_ticks(dst: Image, origin: Vector2i, radius: float, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var center := _ring_center()
	for step in 8:
		var angle := TAU * float(step) / 8.0
		var direction := Vector2.from_angle(angle)
		for offset in range(-3, 4):
			var point := center + direction * (radius + float(offset))
			var px := int(round(point.x))
			var py := int(round(point.y))
			if px < 0 or py < 0 or px >= RING_CELL or py >= RING_CELL:
				continue
			dst.set_pixel(origin.x + px, origin.y + py, Color(1.0, 1.0, 1.0, alpha))

# 행 1 — 예고 원. 바깥 테두리는 고정, 안쪽이 telegraph 진행도만큼 차오른다.
func _draw_charge_ring(dst: Image, origin: Vector2i, t: float) -> void:
	var center := _ring_center()
	var outer := 29.0
	var filled := outer * t
	for y in RING_CELL:
		for x in RING_CELL:
			var distance := Vector2(float(x), float(y)).distance_to(center)
			if absf(distance - outer) <= 1.0:
				dst.set_pixel(origin.x + x, origin.y + y, Color(1.0, 1.0, 1.0, 0.92))
			elif distance <= filled:
				# 가장자리 1.5px만 밝게 남겨 "차오르는 선"이 보이게 한다.
				var lip := filled - distance < 1.6
				dst.set_pixel(origin.x + x, origin.y + y, Color(1.0, 1.0, 1.0, 0.80 if lip else 0.26))

# 행 2 — 잔류 장판. 가장자리를 결정론적 사인 2개로 흔들어 원판처럼 안 보이게 한다.
func _draw_pool(dst: Image, origin: Vector2i, frame: int) -> void:
	var center := _ring_center()
	var phase := float(frame)
	for y in RING_CELL:
		for x in RING_CELL:
			var delta := Vector2(float(x), float(y)) - center
			var distance := delta.length()
			if distance < 0.001:
				dst.set_pixel(origin.x + x, origin.y + y, Color(1.0, 1.0, 1.0, 0.34))
				continue
			var angle := delta.angle()
			var radius := 27.0 * (1.0
				+ 0.075 * sin(3.0 * angle + phase * 0.8)
				+ 0.050 * sin(5.0 * angle - phase * 0.55))
			if distance > radius:
				continue
			var lip := radius - distance < 2.0
			dst.set_pixel(origin.x + x, origin.y + y, Color(1.0, 1.0, 1.0, 0.86 if lip else 0.34))

# ================================================================ 스테이지 오버레이
func _build_stage_overlays() -> void:
	# 안개 — 설계 §7.3이 스테이지 3/4/5에 α0.10/0.16/0.24로 깐다.
	# `FX/Environment/Fog.png`(320×180) 원본을 **그대로** 굽는다(×1).
	# 화면 전체를 덮는 정적 쿼드라 정수배 확대가 의미 없다.
	var fog := _canvas(320, 180)
	_copy(fog, NA + "FX/Environment/Fog.png", Rect2i(0, 0, 320, 180), Vector2i(0, 0))
	_save(fog, "overlay-fog.png", 1)

	# 비네트 — 설계 §7.3 스테이지 5. 중심 투명 → 모서리 알파 0.86의 검정.
	# ⚠️ **이 한 장만 TEXTURE_FILTER_LINEAR로 그릴 것.** 부드러운 전면 감쇠라
	#    nearest로 늘리면 동심원 계단이 보인다. 픽셀아트 실루엣이 없는 순수
	#    감쇠판이므로 스타일을 해치지 않는다(Kenney 글로우와 같은 논리).
	var vignette := _canvas(256, 144)
	var center := Vector2(127.5, 71.5)
	var longest := center.length()
	for y in 144:
		for x in 256:
			var ratio := Vector2(float(x), float(y)).distance_to(center) / longest
			var alpha := clampf((ratio - 0.42) / 0.58, 0.0, 1.0)
			vignette.set_pixel(x, y, Color(0.02, 0.02, 0.05, alpha * alpha * 0.86))
	_save(vignette, "overlay-vignette.png", 1)

# ================================================================ v3 랜드마크 2종
# V5가 스테이지마다 성·캠프·보스문 3종을 배치한다(설계 §2.3). 성은 v2 자산이
# 그대로 쓰이고, **캠프와 보스문 2종이 없다.** `art/v2/`는 V3의 소유이므로 여기서 굽는다.
func _build_v3_landmarks() -> void:
	# 보스문 — 성(밝은 아치 + 석탑) → 보스문(**검은 아치 + 붉은 뿔탑**) →
	# 마왕성(이끼 낀 검은 성채 + 붉은 뿔탑)으로 **같은 부품이 3단계로 험악해진다.**
	# 성보다 작게(96×64 → 192×128) 구워 "성이 아니라 문"으로 읽히게 했다.
	var gate := _canvas(96, 64)
	var arch := _tinted_piece(TS_HOUSE, Rect2i(128, 0, 64, 48), Color.WHITE)
	_apply_hsv(arch, -18.0, 0.34, 0.40)
	gate.blend_rect(arch, Rect2i(0, 0, 64, 48), Vector2i(16, 12))
	_stamp(gate, TS_TOWERS, Rect2i(288, 32, 32, 32), Vector2i(0, 32))
	_stamp(gate, TS_TOWERS, Rect2i(288, 32, 32, 32), Vector2i(64, 32))
	_save(gate, "landmark-boss-gate.png")

	# 베이스 캠프 — `tileset_camp.png`의 천막 + 돌 화덕 + 통나무 울타리.
	# 설계 §3.6 "성이랑 똑같아"는 **내부 서비스** 이야기다. 필드 랜드마크는
	# 성과 달라야 플레이어가 나침반에서 둘을 구분한다.
	var camp := _canvas(96, 64)
	_stamp(camp, TS_CAMP, Rect2i(112, 0, 48, 48), Vector2i(40, 8))    # 천막(온전한 것)
	_stamp(camp, TS_CAMP, Rect2i(192, 48, 32, 32), Vector2i(4, 24))   # 돌 화덕
	_stamp(camp, TS_CAMP, Rect2i(0, 112, 32, 16), Vector2i(6, 46))    # 통나무 울타리
	_save(camp, "landmark-camp.png")
