extends SceneTree
# =============================================================================
# W11 — Ninja Adventure 런타임 에셋 빌더
# =============================================================================
# 원본(art/external/ninja-adventure, CC0 · Pixel-boy & AAA)에서 필요한 셀만
# 추출·합성해 art/v2/ 아래 런타임 PNG를 만든다. 게임 코드는 art/v2/ 결과물만
# preload 하므로, 매핑을 바꾸고 싶으면 이 파일의 상수표만 고치고 재실행하면 된다.
#
#   godot --headless --path godot-game --script res://art/v2/build_assets.gd
#   godot --headless --path godot-game --editor --quit        # 새 PNG 임포트
#
# 규칙 3가지 (전 에셋 공통):
#   1. 확대는 오직 nearest 정수배. 전 에셋이 **×2** 한 종류만 쓴다.
#      (지형 32px 셀 -> 화면 40px 은 world_grid가 하는 별개의 스트레치다.)
#   2. 합성은 16px 원본 좌표계에서 끝내고, 마지막에 한 번만 ×2로 올린다.
#      그래야 픽셀 격자가 어긋나지 않는다.
#   3. 방향 순서는 원본 시트를 그대로 따른다 — 열 0=아래, 1=위, 2=왼쪽, 3=오른쪽.
# =============================================================================

const NA := "res://art/external/ninja-adventure/"
const OUT := "res://art/v2/"
const SCALE := 2

var _cache: Dictionary = {}
var _written: Array[String] = []

# --- 지형 아틀라스 ------------------------------------------------------------
# 5열 × 4행 · 셀 32×32(원본 16×16 ×2) = 160×128.
# wfc_chunk_generator.TILE_RULES가 실제로 참조하는 셀은
# 0,1,2,5,6,12,14,15,16,17,18,19 뿐이다(나머지는 회전으로 만든다).
const TS_WATER := NA + "Backgrounds/Tilesets/TilesetWater.png"
const TS_NATURE := NA + "Backgrounds/Tilesets/TilesetNature.png"
const TS_FLOOR := NA + "Backgrounds/Tilesets/TilesetFloor.png"
const TS_VILLAGE := NA + "Backgrounds/Tilesets/TilesetVillageAbandoned.png"
const TS_TOWERS := NA + "Backgrounds/Tilesets/TilesetTowers.png"
const TS_HOUSE := NA + "Backgrounds/Tilesets/TilesetHouse.png"
const TS_FIELD := NA + "Backgrounds/Tilesets/TilesetField.png"

# 잔디 바탕. TilesetField(16,64)와 TilesetWater의 물가 잔디는 바탕색이
# **#adbc3a로 완전히 동일**하다(픽셀 히스토그램으로 확인). 그래서 호수
# 가장자리에서 색이 튀지 않는다. Field 쪽을 고른 이유는 잔풀 얼룩이 4픽셀
# 들어 있어 넓은 평원이 단색 판때기로 보이지 않기 때문이다.
const GRASS_SRC := Rect2i(16, 64, 16, 16)

# 몹 시각 변종 -> 원본 시트. 전부 64×64(열 4방향 × 행 4프레임)로 규격이 같다.
const MOB_SHEETS := {
	"blob": NA + "Actor/Monster/Larva/Larva.png",
	"boar": NA + "Actor/Monster/Bear/SpriteSheet.png",
	"imp": NA + "Actor/Monster/Beast/Beast.png",
	"wolf": NA + "Actor/Monster/Racoon/SpriteSheet.png",
	"skeleton": NA + "Actor/Monster/Skull/SpriteSheet.png",
	"shade": NA + "Actor/Monster/Spirit/SpriteSheet.png",
	"wisp": NA + "Actor/Monster/Flam2/SpriteSheet.png",
	"ogre": NA + "Actor/Monster/Cyclope2/SpriteSheet.png",
	"cultist": NA + "Actor/Character/SorcererBlack/SeparateAnim/Walk.png",
	"hellhound": NA + "Actor/Monster/Grey Trex/SpriteSheet.png",
	# v2에서 내려간 3종(royal_ooze·cave_bat·iron_beetle)의 variant도 남겨 둔다.
	# enemy.gd의 variant 분기가 총망라를 유지해야 미등록 종이 들어와도 안 깨진다.
	"bat": NA + "Actor/Monster/BlueBat/SpriteSheet.png",
	"beetle": NA + "Actor/Monster/Mollusc/Mollusc.png",
	"ooze": NA + "Actor/Monster/Slime2/Slime2.png"
}

# 원본 색을 게임의 종 이름에 맞추는 곱연산 보정. 런타임 modulate가 아니라
# 빌드 때 구워 넣는다 — 그래야 밤 변이·피격 플래시가 쓰는 modulate 예산과
# 겹치지 않고, 매 프레임 색 계산도 사라진다.
const MOB_TINT := {
	"wolf": Color(1.30, 0.70, 0.62),      # 너구리 갈색 -> 붉은 늑대
	"hellhound": Color(0.92, 0.40, 0.44), # 회색 야수 -> 지옥견 진홍
	"shade": Color(0.66, 0.58, 0.86),     # 흰 유령 -> 굶주린 그림자(창백한 보라)
	"cultist": Color(0.82, 0.78, 1.00)    # 술사 로브를 월식빛 남보라로
}

const BOSS_DIR := NA + "Actor/Boss/GiantRedSamurai/"
# 캐릭터 3종. 전부 SeparateAnim 규격이 같아 한 함수로 굽는다.
const PLAYER_SHEETS := {
	"swordsman": NA + "Actor/Character/Knight/SeparateAnim/",
	"archer": NA + "Actor/Character/Hunter/SeparateAnim/",
	"mage": NA + "Actor/Character/SorcererOrange/SeparateAnim/"
}

func _init() -> void:
	var started := Time.get_ticks_msec()
	_build_terrain()
	_build_player()
	_build_mobs()
	_build_boss()
	_build_vfx()
	_build_landmarks()
	_build_castle_interior()
	print("BUILD_ASSETS_COMPLETE files=%d ms=%d" % [_written.size(), Time.get_ticks_msec() - started])
	for path: String in _written:
		print("  ", path)
	quit()

# --------------------------------------------------------------------- 유틸
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

# 알파 합성(덮어쓰기가 아니라 위에 얹기).
func _stamp(dst: Image, path: String, region: Rect2i, at: Vector2i) -> void:
	dst.blend_rect(_src(path), region, at)

# 불투명 복사(바닥 타일용).
func _copy(dst: Image, path: String, region: Rect2i, at: Vector2i) -> void:
	dst.blit_rect(_src(path), region, at)

# 캐릭터 시트는 아래쪽에 **흰 실루엣(마스크)**을 한 벌 더 붙여 저장한다.
# 피격 플래시·밤 변이·경직 색조를 셰이더 없이 표현하기 위한 것이다. 스프라이트를
# 한 번 그리고 그 위에 마스크를 원하는 색·알파로 덧그리면 끝난다. 셰이더머티리얼을
# 쓰면 같은 _draw() 안의 체력바·아이콘까지 물들기 때문에 이 방식을 골랐다.
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

# 정사각 프레임을 프레임마다 90도 시계방향으로 돌린다.
# NA의 투사체 시트는 자산마다 기준축이 다르다 — Arrow·BigKunai는 +X를 향하는데
# Fireball·EnergyBall은 -Y(위)를 향한다. v1이 딱 이 불일치 때문에 이펙트가
# 180도 뒤집혔었다. 그래서 **빌드 단계에서 전부 +X로 통일**해 굽는다.
# 런타임에는 "모든 방향성 VFX는 +X를 향한다" 한 문장만 지키면 된다.
func _rotate_square_frames_cw(img: Image, size: int) -> Image:
	var frames := img.get_width() / size
	var out := _canvas(img.get_width(), img.get_height())
	for frame in frames:
		for y in size:
			for x in size:
				var c := img.get_pixel(frame * size + y, size - 1 - x)
				out.set_pixel(frame * size + x, y, c)
	return out

# NA의 데코레이션(잔풀·꽃·덤불·바위)은 거의 검은 외곽선을 두르고 있다. 원작에서는
# 레벨 디자이너가 드문드문 놓기 때문에 문제가 없지만, 우리 WFC는 잔디 타일의 19%를
# 데코로 채운다(tuft 13 + flower 3.2 + forest 2.9 + rocks 1.6 / 총 가중치 90.7).
# 그대로 두면 들판 전체가 검은 낙서처럼 읽힌다. 외곽선만 진한 올리브로 바꿔
# 형태는 남기고 대비만 낮춘다.
const OUTLINE_SOFT := Color(0.27, 0.32, 0.13)

func _soften_outline(img: Image, region: Rect2i) -> void:
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if maxf(c.r, maxf(c.g, c.b)) < 0.20:
				img.set_pixel(x, y, Color(OUTLINE_SOFT.r, OUTLINE_SOFT.g, OUTLINE_SOFT.b, c.a))

func _save(img: Image, name: String, scale: int = SCALE) -> void:
	# 합성은 전부 16px 좌표계에서 끝났다. 여기서 딱 한 번 정수배 nearest로 올린다.
	var scaled := img.duplicate() as Image
	scaled.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var path := OUT + name
	var error := scaled.save_png(ProjectSettings.globalize_path(path))
	assert(error == OK, "저장 실패: " + path)
	_written.append("%s  %dx%d" % [path, scaled.get_width(), scaled.get_height()])

# ------------------------------------------------------------------- 지형
func _build_terrain() -> void:
	# 셀 16×16 · 5열 4행 = 80×64 (저장 시 ×2 -> 160×128)
	var atlas := _canvas(80, 64)
	for cell in 20:
		var at := Vector2i((cell % 5) * 16, (cell / 5) * 16)
		match cell:
			0:
				_copy(atlas, TS_FIELD, GRASS_SRC, at)
			1:
				_copy(atlas, TS_FIELD, GRASS_SRC, at)
				_stamp(atlas, TS_NATURE, Rect2i(64, 160, 16, 16), at)   # 억새 뭉치
			2:
				_copy(atlas, TS_FIELD, GRASS_SRC, at)
				_stamp(atlas, TS_NATURE, Rect2i(16, 176, 16, 16), at)   # 노란 들꽃
			3, 4:
				# 규칙표가 쓰지 않는 예비 셀. 잔디로 채워 잘못 참조돼도 안 깨지게 한다.
				_copy(atlas, TS_FIELD, GRASS_SRC, at)
			5:
				_copy(atlas, TS_WATER, Rect2i(16, 112, 16, 16), at)     # 트인 물(연못 중앙)
			6, 7, 8, 9:
				# 6만 실사용. 7~9는 world_grid가 turn 1/2/3 회전으로 만든다.
				_copy(atlas, TS_WATER, Rect2i(16, 96, 16, 16), at)      # 위쪽이 뭍인 물가
			10, 11, 12, 13:
				# 12만 실사용. 나머지 세 모서리는 회전으로 만든다.
				_copy(atlas, TS_WATER, Rect2i(32, 128, 16, 16), at)     # 오른쪽·아래가 뭍
			14:
				_copy(atlas, TS_WATER, Rect2i(64, 208, 16, 16), at)     # 나무 데크(다리)
			15:
				_copy(atlas, TS_FIELD, GRASS_SRC, at)
				_stamp(atlas, TS_NATURE, Rect2i(0, 160, 16, 16), at)    # 덤불(숲)
			16:
				_copy(atlas, TS_FIELD, GRASS_SRC, at)
				_stamp(atlas, TS_NATURE, Rect2i(272, 272, 16, 16), at)  # 회색 바위 2덩이
				_stamp(atlas, TS_NATURE, Rect2i(304, 272, 16, 16), at)
			17:
				_copy(atlas, TS_FLOOR, Rect2i(16, 16, 16, 16), at)      # 폐허(미사용 셀)
				_stamp(atlas, TS_NATURE, Rect2i(272, 272, 16, 16), at)
			18:
				_copy(atlas, TS_FLOOR, Rect2i(16, 16, 16, 16), at)      # 성 안뜰 석재
			19:
				_copy(atlas, TS_FLOOR, Rect2i(16, 128, 16, 16), at)     # 균열 아레나 흙바닥
	# 데코가 얹힌 셀만 외곽선을 눅인다. 물가·다리·바닥은 원본 그대로 둔다.
	for decorated_cell in [1, 2, 15, 16, 17]:
		_soften_outline(atlas, Rect2i((decorated_cell % 5) * 16, (decorated_cell / 5) * 16, 16, 16))
	_save(atlas, "terrain-atlas-na.png")

# ----------------------------------------------------------------- 플레이어
func _build_player() -> void:
	# 4열(아래/위/왼/오) × 6행. 행 0~3 = 걷기 프레임, 행 4 = 대기, 행 5 = 검 공격.
	# 저장 후 128×192, 셀 32×32.
	for character_id: String in PLAYER_SHEETS:
		var dir: String = PLAYER_SHEETS[character_id]
		var sheet := _canvas(64, 96)
		_copy(sheet, dir + "Walk.png", Rect2i(0, 0, 64, 64), Vector2i(0, 0))
		_copy(sheet, dir + "Idle.png", Rect2i(0, 0, 64, 16), Vector2i(0, 64))
		_copy(sheet, dir + "Attack.png", Rect2i(0, 0, 64, 16), Vector2i(0, 80))
		_save(_with_mask(sheet), "player-%s.png" % character_id)

# --------------------------------------------------------------------- 몹
func _build_mobs() -> void:
	for variant: String in MOB_SHEETS:
		var sheet := _canvas(64, 64)
		_copy(sheet, MOB_SHEETS[variant], Rect2i(0, 0, 64, 64), Vector2i(0, 0))
		if MOB_TINT.has(variant):
			_apply_tint(sheet, MOB_TINT[variant])
		_save(_with_mask(sheet), "mob-%s.png" % variant)

# ------------------------------------------------------------------- 마왕
func _build_boss() -> void:
	# 셀 48×96(원본) · 12열 × 5행. 48×48짜리 애니는 셀 아래쪽에 붙여
	# 발밑 높이를 공격 프레임과 맞춘다(공격 프레임은 검이 위로 48px 더 크다).
	var rows := [
		{"file": "Idle.png", "frames": 12, "tall": false},
		{"file": "Walk.png", "frames": 12, "tall": false},
		{"file": "Hit.png", "frames": 8, "tall": false},
		{"file": "AttackRight.png", "frames": 8, "tall": true},
		{"file": "AttackLeft.png", "frames": 8, "tall": true}
	]
	var sheet := _canvas(12 * 48, rows.size() * 96)
	for row in rows.size():
		var spec: Dictionary = rows[row]
		var tall: bool = bool(spec["tall"])
		var frame_height: int = 96 if tall else 48
		for frame in int(spec["frames"]):
			_copy(
				sheet,
				BOSS_DIR + String(spec["file"]),
				Rect2i(frame * 48, 0, 48, frame_height),
				Vector2i(frame * 48, row * 96 + (0 if tall else 48))
			)
	# 마왕만 ×3이다(전 에셋 유일한 예외). 원본 프레임은 48px지만 사무라이 몸통은
	# 그 안에서 26px밖에 안 차서, ×2로 그리면 반지름 58(지름 116px) 히트박스의
	# 절반도 못 채운다. 최종 보스가 플레이어의 1.7배로 보이는 것이 픽셀 크기
	# 불일치보다 큰 손해라고 판단했다.
	_save(_with_mask(sheet), "boss-demon-king.png", 3)

# -------------------------------------------------------------------- VFX
func _build_vfx() -> void:
	# ① 코어 아틀라스: 4행 × 4프레임, 셀 32×32(저장 후 64×64 · 256×256).
	#    행 0 참격(방향성 · 원본이 +X를 향한다) / 1 원형 참격 / 2 마법진 / 3 낙뢰
	var core := _canvas(128, 128)
	for frame in 4:
		_copy(core, NA + "FX/Attack/SlashCurved/SpriteSheet.png",
			Rect2i(frame * 32, 0, 32, 32), Vector2i(frame * 32, 0))
		_copy(core, NA + "FX/Attack/CircularSlash/SpriteSheet.png",
			Rect2i(frame * 32, 0, 32, 32), Vector2i(frame * 32, 32))
		_copy(core, NA + "FX/Magic/Circle/SpriteSheetWhite.png",
			Rect2i(frame * 32, 0, 32, 32), Vector2i(frame * 32, 64))
		# 낙뢰는 32×28이라 세로 가운데에 맞춰 넣는다.
		_copy(core, NA + "FX/Elemental/Thunder/SpriteSheet.png",
			Rect2i(frame * 32, 0, 32, 28), Vector2i(frame * 32, 96 + 2))
	_save(core, "vfx-core.png")

	# ② 폭발 9프레임 40×40 -> 80×80. 40px 타일 격자와 정확히 맞는 유일한 시트.
	var boom := _canvas(9 * 40, 40)
	_copy(boom, NA + "FX/Elemental/Explosion/SpriteSheet.png", Rect2i(0, 0, 360, 40), Vector2i(0, 0))
	_save(boom, "vfx-explosion.png")

	# ③ 투사체 4프레임 16×16 -> 32×32. 원본이 -Y(위)를 향하므로 +X로 돌려 굽는다.
	var shot := _canvas(64, 16)
	_copy(shot, NA + "FX/Projectile/Fireball.png", Rect2i(0, 0, 64, 16), Vector2i(0, 0))
	_save(_rotate_square_frames_cw(shot, 16), "vfx-projectile.png")

	# ③-b 마법 탄환(EnergyBall) 4프레임 16×16. 역시 +X로 돌린다.
	var orb := _canvas(64, 16)
	_copy(orb, NA + "FX/Projectile/EnergyBall.png", Rect2i(0, 0, 64, 16), Vector2i(0, 0))
	_save(_rotate_square_frames_cw(orb, 16), "vfx-energyball.png")

	# ③-c 화살(13×5)과 던지는 칼(35×9). 둘 다 원본이 이미 +X를 향한다.
	var arrow := _canvas(13, 5)
	_copy(arrow, NA + "FX/Projectile/Arrow.png", Rect2i(0, 0, 13, 5), Vector2i(0, 0))
	_save(arrow, "vfx-arrow.png")
	var blade := _canvas(35, 9)
	_copy(blade, NA + "FX/Projectile/BigKunai.png", Rect2i(0, 0, 35, 9), Vector2i(0, 0))
	_save(blade, "vfx-blade.png")

	# ④ 보호막 6프레임 24×26 -> 48×52.
	var shield := _canvas(144, 26)
	_copy(shield, NA + "FX/Magic/Shield/SpriteSheetBlue.png", Rect2i(0, 0, 144, 26), Vector2i(0, 0))
	_save(shield, "vfx-shield.png")

	# ⑤ 피격 연기 6프레임 32×32 -> 64×64. 마물 사망·피격 파편용.
	var smoke := _canvas(192, 32)
	_copy(smoke, NA + "FX/Smoke/Smoke/SpriteSheet.png", Rect2i(0, 0, 192, 32), Vector2i(0, 0))
	_save(smoke, "vfx-smoke.png")

# --------------------------------------------------------------- 월드 랜드마크
func _build_landmarks() -> void:
	# 성: 가운데 아치 성채 + 좌우 석탑. 원본 128×88 -> 256×176.
	var castle := _canvas(128, 88)
	_stamp(castle, TS_HOUSE, Rect2i(128, 0, 64, 48), Vector2i(32, 40))
	_stamp(castle, TS_TOWERS, Rect2i(0, 64, 32, 32), Vector2i(0, 56))
	_stamp(castle, TS_TOWERS, Rect2i(0, 64, 32, 32), Vector2i(96, 56))
	_save(castle, "landmark-castle.png")

	# 마왕성: 이끼 낀 검은 성채 + 붉은 뿔탑.
	var demon := _canvas(128, 88)
	_stamp(demon, TS_VILLAGE, Rect2i(192, 96, 64, 80), Vector2i(32, 8))
	_stamp(demon, TS_TOWERS, Rect2i(288, 32, 32, 32), Vector2i(0, 56))
	_stamp(demon, TS_TOWERS, Rect2i(288, 32, 32, 32), Vector2i(96, 56))
	_save(demon, "landmark-demon-castle.png")

	# 유적: 무너진 이끼 석벽.
	var ruin := _canvas(64, 48)
	_stamp(ruin, TS_VILLAGE, Rect2i(0, 0, 64, 48), Vector2i(0, 0))
	_save(ruin, "landmark-ruin.png")

	# 숲(작은 나무 1그루). _draw_grove가 5그루를 원형으로 배치한다.
	var tree := _canvas(32, 32)
	_stamp(tree, TS_NATURE, Rect2i(0, 0, 32, 32), Vector2i(0, 0))
	_soften_outline(tree, Rect2i(0, 0, 32, 32))
	_save(tree, "landmark-tree.png")

	# 보물상자(닫힘 프레임).
	var chest := _canvas(16, 16)
	_stamp(chest, NA + "Items/Treasure/LittleTreasureChest.png", Rect2i(0, 0, 16, 16), Vector2i(0, 0))
	_save(chest, "landmark-chest.png")

# --------------------------------------------------------- 성 내부(로비 아님)
# 성 안은 절차적 사각형 방이었다. 바닥 타일과 NPC만 NA로 갈아끼우면
# 나머지 구조(벽·문·이름표)는 그대로 두고도 화면이 통째로 바뀐다.
const CASTLE_NPCS := [
	"Villager",   # 0 card_shop  딜싸이클 카드상
	"Master",     # 1 rune_shop  각인 세공사
	"Noble",      # 2 pact       계약자
	"NinjaDark",  # 3 spy        밀정
	"OldMan",     # 4 그 밖의 서비스(여관 주인 등)
	"Princess"    # 5 예비
]

func _build_castle_interior() -> void:
	# 성 바닥 한 장(32×32). world_grid의 안뜰 셀과 같은 석재라 안팎이 이어진다.
	var floor_tile := _canvas(16, 16)
	_copy(floor_tile, TS_FLOOR, Rect2i(16, 16, 16, 16), Vector2i(0, 0))
	_save(floor_tile, "castle-floor.png")

	# NPC 정면 대기 프레임만 한 줄로 모은다. Idle.png는 64×16(4방향×1프레임)이고
	# 열 0이 정면이다 — 성 안 NPC는 늘 플레이어 쪽(아래)을 본다.
	var npcs := _canvas(CASTLE_NPCS.size() * 16, 16)
	for index in CASTLE_NPCS.size():
		_copy(
			npcs,
			NA + "Actor/Character/%s/SeparateAnim/Idle.png" % CASTLE_NPCS[index],
			Rect2i(0, 0, 16, 16),
			Vector2i(index * 16, 0)
		)
	_save(_with_mask(npcs), "castle-npcs.png")
