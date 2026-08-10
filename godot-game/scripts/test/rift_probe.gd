extends SceneTree

# =============================================================================
# 동적 균열(Rift) 배치 자체 검증 — W8 작성 · V10 전면 재작성
# =============================================================================
#   godot --headless --path godot-game -s res://scripts/test/rift_probe.gd
#
# WorldGrid를 트리 밖에서 직접 만들어 배치 규칙만 본다(렌더·게임 상태 불필요).
#
# --- V10이 이 파일을 다시 쓴 이유 --------------------------------------------
# 이 프로브는 run_all.sh 목록에 없는 단독 검사다. 그래서 v3 전환기 내내 아무도
# 돌리지 않았고, 밑에서 규칙이 바뀌는 동안 v2 가정 3개가 그대로 굳어 4연속 FAIL이
# 됐다. **게임은 멀쩡했다** — `run_all.sh --rift-test`가 v3 동작(rifts=2 ·
# run_budget=10 · stage_reset)을 계속 통과시키고 있었다. 틀린 쪽은 프로브였다.
# 갈아엎은 v2 가정 3개:
#
#   ① 예산       v2 "런당 3회" → v3 **스테이지당 GameTuning.RIFT_STAGE_BUDGET(2)회**,
#                런 합계 GameTuning.RIFT_RUN_BUDGET(10 = 5스테이지 × 2). 그래서 옛
#                프로브의 3번째 요청은 이제 *정당하게* 거절돼 `(nan, nan)`이 되고,
#                그 nan이 ①②③번 검사로 번져 4연속 FAIL을 만들고 있었다.
#   ② 랜드마크   v2의 마왕성 고정 좌표·시작 성 고정 좌표·시련 캠프 4곳 →
#                v3 **스테이지 랜드마크 3종**(성 · 캠프 · 보스문). 마왕성은 v3에서
#                삭제됐고, 시작 성은 스테이지마다 시드로 자리가 정해지는 랜드마크가
#                됐으며, 시련 캠프는 W12에서 없어졌다(`get_trial_camps()`가 늘 빈
#                사전 → 옛 출력의 `camp_gap=inf`가 그 증거였다. 아무것도 안 재고
#                통과하고 있었다).
#   ③ 월드 구성  v2는 `begin_run_rifts()`만 불러 월드를 세웠다. v3의 랜드마크는
#                `begin_stage()`가 놓으므로(world_grid.gd:177) 그 구성으로는
#                랜드마크가 0개고, `_rift_site_clear_of_landmarks()`도
#                `stage_landmarks.is_empty()`에서 통째로 빠져나간다. 즉 ③번 검사가
#                **공허하게** 통과하고 있었다. 이제 `begin_stage()`를 먼저 부르고,
#                랜드마크가 실제로 있는지를 검사 안에서 먼저 확인한 뒤 없으면 크게
#                실패시킨다 — 다시는 조용히 공허해지지 않게.
#
# 확인 항목 5가지:
#   ① 시드 결정성   — 같은 스테이지 시드·같은 요청 순번이면 같은 좌표. 다른 시드면 다른 좌표.
#   ② 거리 준수     — 플레이어로부터 RIFT_MIN_DISTANCE~RIFT_MAX_DISTANCE(900~1,400px).
#   ③ 겹침 없음     — 발판 사각형 전체가 마른 땅이고, 아레나 전체가 이동 가능하며,
#                     스테이지 랜드마크 3종(성·캠프·보스문)과 각자의 안전 반경 +
#                     SAFE_ZONE_RIFT + RIFT_CLEARANCE만큼 떨어져 있다.
#   ④ 예산          — 예산만큼은 나가고, 그 **다음** 요청은 budget_exhausted로 거절되며
#                     잔량은 0에서 더 늘지 않는다.
#   ⑤ 시드 견고성   — Y5 신설. 시드 100개 × 스테이지 순환에서 균열 배치 실패 0건,
#                     랜드마크 3종이 전부 놓이고 셋 다 걸을 수 있으며, 균열 중심도
#                     전부 걸을 수 있다. 물 비율은 10 시드만 표본으로 함께 찍는다.
#
# 숫자는 전부 GameTuning·WorldGrid 상수에서 읽는다. 하드코딩된 "3"이 이 파일을
# 썩게 만든 원인이었으므로, 다음 리튜닝(2→3 등)에는 이 파일이 알아서 따라간다.
#
# run_all.sh 규약상 출력에 `=false`가 들어가면 안 되므로 판정은 pass=1 / pass=0으로 쓴다.

const WORLD_SCRIPT := preload("res://scripts/world_grid.gd")

const RUN_SEED_A := 20260807
const RUN_SEED_B := 991177
## 프로브가 세우는 스테이지. 랜드마크만 있으면 되므로 1이면 충분하다.
const PROBE_STAGE := 1
# V10: v2 주석은 "2·4·6일차"였다. v3의 균열 트리거는 스테이지 안의 체류
# (GameTuning.RIFT_DWELL_SCHEDULE = [1, 3])로 바뀌었다. 좌표 자체는 "서로 멀리
# 떨어진 서로 다른 지점"이면 되는 값이라 3곳을 그대로 둔다 — 예산이 이 개수를
# 넘어가게 리튜닝되면 `_player_point()`가 순환시킨다.
const PLAYER_POINTS: Array[Vector2] = [
	Vector2(180.0, -120.0),
	Vector2(1650.0, 900.0),
	Vector2(-2400.0, 1800.0)
]

# --- ⑤ 시드 100개 배치 견고성 (Y5 신설 · FEEDBACK_Y 리스크 4) -----------------
# Y5가 물을 크게 늘렸다(젖은 칸 약 2% → 15.7% · LAKE_CELL 18→13 · LAKE_CHANCE 9→19 ·
# LAKE_RADIUS_TABLE [1,1,2,2,2,3]→[2,3,3,3,3,4]). 물이 늘면 두 군데가 자리를 못 찾을 수 있다:
#   * `_rift_site_dry()` = `_area_dry(후보, SAFE_ZONE_RIFT)` — 13×13타일이 **전부** 마른 땅일 것
#   * 랜드마크의 `_nearest_dry_spot()` — 못 찾으면 원래 자리를 그냥 쓴다(조용히 물 위)
# 그래서 계약이 「물 12~20%」와 **함께** 「rift_probe가 시드 100개에서 배치 실패 0건」을
# 요구한다. ①~④는 시드 2개만 본다 — 운 좋은 시드 2개는 아무것도 증명하지 못하므로
# 표본을 100개로 넓히는 이 검사가 계약의 본체다.
const ROBUST_SEED_COUNT := 100
const ROBUST_SEED_BASE := 20260810
## 서로 이웃하지 않는 시드를 만들기 위한 소수 간격. 결정적이라 재현된다.
const ROBUST_SEED_STEP := 7919
## 물 비율은 청크를 잔뜩 만들어 비싸다. 100 시드는 **계약이라 줄일 수 없지만**
## 물 비율은 표본이면 충분하므로 10 시드에 한 번만 잰다(= 10 표본).
const ROBUST_MIX_EVERY := 10
const ROBUST_MIX_SPAN := 120
const ROBUST_MIX_STRIDE := 3
## 물 비율 계약 창(FEEDBACK_Y §5.1). 여기서는 판정하지 않고 눈금으로만 찍는다 —
## 비율 자체의 판정은 terrain_probe.gd가 300 표본으로 한다.
const WET_BAND_MIN := 0.12
const WET_BAND_MAX := 0.20

var failures: Array[String] = []
## v3 예산. 스테이지 단위이며 스테이지 전환마다 다시 채워진다.
var stage_budget := int(GameTuning.RIFT_STAGE_BUDGET)

func _initialize() -> void:
	print("RIFT_PROBE_BEGIN godot=%s" % Engine.get_version_info()["string"])
	print("    tuning stage_budget=%d run_budget=%d stage_count=%d ring=%.0f~%.0fpx" % [
		stage_budget, int(GameTuning.RIFT_RUN_BUDGET), int(GameTuning.STAGE_COUNT),
		float(WORLD_SCRIPT.RIFT_MIN_DISTANCE), float(WORLD_SCRIPT.RIFT_MAX_DISTANCE)
	])
	var run_a := _place_run(RUN_SEED_A)
	var run_a_again := _place_run(RUN_SEED_A)
	var run_b := _place_run(RUN_SEED_B)

	_check_determinism(run_a, run_a_again, run_b)
	_check_distance(run_a)
	_check_overlap(RUN_SEED_A, run_a)
	_check_budget(RUN_SEED_A)
	_check_seed_robustness()

	print("RIFT_PROBE_COMPLETE failures=%d %s" % [failures.size(), "verdict=PASS" if failures.is_empty() else "verdict=FAIL"])
	for reason: String in failures:
		print("  - %s" % reason)
	quit(0 if failures.is_empty() else 1)

## v3의 월드 구성 순서. 실제 게임은 `game._rebuild_stage_world()`에서
## `world.begin_stage(stage, seed)` **하나만** 부르고, `begin_stage()`가 마지막에
## `begin_run_rifts(stage_seed)`까지 직접 끝낸다(world_grid.gd:203).
## 여기서 `begin_run_rifts()`를 한 번 더 부르는 것은 같은 시드로 덮는 멱등 호출이며,
## 두 가지를 이 파일에 남기려는 의도다 — ⑴ "균열 시드 = 스테이지 시드"라는 v3 계약,
## ⑵ v2처럼 `begin_run_rifts()`만 부르면 랜드마크가 없다는 사실(순서가 뒤집히거나
## `begin_stage()`가 빠지면 ③번 검사가 즉시 크게 실패한다).
func _new_world(run_seed: int) -> Node2D:
	var world: Node2D = WORLD_SCRIPT.new()
	world.begin_stage(PROBE_STAGE, run_seed)
	world.begin_run_rifts(run_seed)
	return world

## 요청 순번 → 플레이어 위치. 예산이 PLAYER_POINTS 개수를 넘으면 순환한다.
## v2 프로브는 "요청 수 = PLAYER_POINTS.size() = 3"을 같은 것으로 취급했고,
## 그 결합이 예산이 2로 바뀐 순간 3번째 요청을 nan으로 만들었다. 이제 둘을 끊는다.
func _player_point(index: int) -> Vector2:
	return PLAYER_POINTS[index % PLAYER_POINTS.size()]

## 한 스테이지에서 **예산만큼** 요청한 결과를 그대로 돌려준다(v2: 고정 3회).
func _place_run(run_seed: int) -> Array[Dictionary]:
	var world := _new_world(run_seed)
	var placed: Array[Dictionary] = []
	for index in stage_budget:
		placed.append(world.spawn_rift_near(_player_point(index)))
	world.free()
	return placed

func _check_determinism(a: Array[Dictionary], a2: Array[Dictionary], b: Array[Dictionary]) -> void:
	var same_seed_match := true
	var other_seed_differs := false
	for index in a.size():
		if a[index].is_empty() or a2[index].is_empty():
			same_seed_match = false
			continue
		if a[index]["position"] != a2[index]["position"]:
			same_seed_match = false
		if b[index].is_empty() or b[index]["position"] != a[index]["position"]:
			other_seed_differs = true
	var ok := same_seed_match and other_seed_differs
	print("[1] determinism same_seed_identical=%d other_seed_differs=%d pass=%d" % [
		int(same_seed_match), int(other_seed_differs), int(ok)
	])
	for index in a.size():
		var here: Dictionary = a[index]
		var twin: Dictionary = a2[index]
		print("    req#%d seedA=(%.2f, %.2f) seedA_rerun=(%.2f, %.2f) seedB=(%.2f, %.2f)" % [
			index,
			here["position"].x if not here.is_empty() else NAN, here["position"].y if not here.is_empty() else NAN,
			twin["position"].x if not twin.is_empty() else NAN, twin["position"].y if not twin.is_empty() else NAN,
			b[index]["position"].x if not b[index].is_empty() else NAN, b[index]["position"].y if not b[index].is_empty() else NAN
		])
	if not same_seed_match:
		failures.append("같은 시드·같은 요청 순번인데 좌표가 달랐다")
	if not other_seed_differs:
		failures.append("다른 시드인데 좌표가 전부 같았다")

func _check_distance(placed: Array[Dictionary]) -> void:
	# 링의 경계도 상수에서 읽는다(v2 프로브는 900/1400을 리터럴로 박아 뒀다).
	var ring_min: float = float(WORLD_SCRIPT.RIFT_MIN_DISTANCE)
	var ring_max: float = float(WORLD_SCRIPT.RIFT_MAX_DISTANCE)
	var all_ok := true
	for index in placed.size():
		if placed[index].is_empty():
			# 예산 안쪽 요청은 전부 성공해야 한다. v3에서 실패하면 그건 프로브가 아니라
			# 배치 규칙이 링 위에서 자리를 못 찾았다는 뜻이므로 그대로 실패로 센다.
			all_ok = false
			print("    req#%d 배치 실패 reason=no_site" % index)
			continue
		var measured: float = _player_point(index).distance_to(placed[index]["position"])
		var inside := measured >= ring_min and measured <= ring_max
		all_ok = all_ok and inside
		print("    req#%d distance=%.1fpx bound=%.0f~%.0f attempts=%d inside=%d" % [
			index, measured, ring_min, ring_max, int(placed[index]["attempts"]), int(inside)
		])
	print("[2] distance pass=%d" % int(all_ok))
	if not all_ok:
		failures.append("%.0f~%.0fpx 링을 벗어나거나 자리를 못 잡은 균열이 있다" % [ring_min, ring_max])

func _check_overlap(run_seed: int, placed: Array[Dictionary]) -> void:
	# 실제 지형 판정은 새 월드에서 같은 좌표를 다시 만들어 확인한다.
	var world := _new_world(run_seed)
	for index in stage_budget:
		world.spawn_rift_near(_player_point(index))

	# --- v3 랜드마크 3종 확보 ------------------------------------------------
	# v2 프로브는 `DEMON_CASTLE_POSITION` / `STARTER_CASTLE_POSITION` 고정 좌표와
	# `get_trial_camps()`를 읽었다. 셋 다 v3에는 실체가 없다(마왕성 삭제 · 성은
	# 스테이지 랜드마크로 이전 · 시련 캠프는 W12에서 제거되어 빈 사전). 이제 진짜
	# 랜드마크 3종을 읽고, **비어 있으면 여기서 크게 실패한다** — 랜드마크가 없으면
	# world_grid의 `_rift_site_clear_of_landmarks()`도 통째로 건너뛰므로 아래
	# 거리 단언이 전부 무의미해진다. v2 프로브가 정확히 그 상태로 통과하고 있었다.
	var castle: Dictionary = world.get_landmark("castle")
	var camp: Dictionary = world.get_landmark("camp")
	var boss_gate: Dictionary = world.get_landmark("boss_gate")
	var landmarks_ok := not castle.is_empty() and not camp.is_empty() and not boss_gate.is_empty()
	print("    landmarks castle=%d camp=%d boss_gate=%d present=%d" % [
		int(not castle.is_empty()), int(not camp.is_empty()), int(not boss_gate.is_empty()), int(landmarks_ok)
	])
	if not landmarks_ok:
		print("    STOP 스테이지 랜드마크가 비었다 — begin_stage()가 빠졌다는 뜻이고,")
		print("         이 상태의 안전 반경 검사는 아무것도 재지 않으므로 통과시키지 않는다.")
		print("[3] no_overlap pass=0")
		world.free()
		failures.append("스테이지 랜드마크가 비어 안전 반경 검사가 공허해졌다")
		return

	var generator: Variant = world.terrain_generator
	var tile: int = int(world.TILE)
	var reach := int(ceil(world.SAFE_ZONE_RIFT / float(tile) + 2.0))
	var castle_position: Vector2 = castle["position"]
	var camp_position: Vector2 = camp["position"]
	var gate_position: Vector2 = boss_gate["position"]
	var min_castle: float = world.SAFE_ZONE_CASTLE + world.SAFE_ZONE_RIFT + world.RIFT_CLEARANCE
	var min_camp: float = world.SAFE_ZONE_CAMP + world.SAFE_ZONE_RIFT + world.RIFT_CLEARANCE
	# 보스문만 반경이 상수가 아니라 런타임 값이다(SAFE_ZONE_RIFT × BOSS_ARENA_RADIUS_MUL).
	# world_grid가 실제로 거는 조건과 같은 식을 쓴다 — 캠프 반경으로 대충 맞추면
	# 아레나가 커졌을 때 프로브만 통과하는 사각이 생긴다.
	var min_gate: float = world.boss_gate_radius + world.SAFE_ZONE_RIFT + world.RIFT_CLEARANCE
	var all_ok := true
	for index in placed.size():
		if placed[index].is_empty():
			all_ok = false
			continue
		var center: Vector2 = placed[index]["position"]
		var center_tile := Vector2i(floori(center.x / float(tile)), floori(center.y / float(tile)))
		var wet_tiles := 0
		var scanned := 0
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				scanned += 1
				if generator.is_wet_tile(center_tile + Vector2i(dx, dy)):
					wet_tiles += 1
		# 아레나 전체(중심 + 반지름 위 24점 × 3링)가 이동 가능한지.
		var blocked := 0
		for ring in [0.0, world.SAFE_ZONE_RIFT * 0.5, world.SAFE_ZONE_RIFT * 0.95]:
			for step in 24:
				var sample: Vector2 = center + Vector2.from_angle(TAU * float(step) / 24.0) * float(ring)
				if not world.is_walkable(sample):
					blocked += 1
		# v2의 demon_gap은 여기서 사라졌다 — v3에 마왕성이 없으므로 잴 대상이 없다.
		var castle_gap: float = center.distance_to(castle_position)
		var camp_gap: float = center.distance_to(camp_position)
		var gate_gap: float = center.distance_to(gate_position)
		var floor_ok: bool = int(world.get_tile_id(center)) == int(generator.T_CAMP)
		var ok := wet_tiles == 0 and blocked == 0 and floor_ok \
			and castle_gap >= min_castle and camp_gap >= min_camp and gate_gap >= min_gate
		all_ok = all_ok and ok
		print("    req#%d wet_tiles=%d/%d blocked_samples=%d/72 floor_is_safe_tile=%d castle_gap=%.0f(min %.0f) camp_gap=%.0f(min %.0f) gate_gap=%.0f(min %.0f) ok=%d" % [
			index, wet_tiles, scanned, blocked, int(floor_ok),
			castle_gap, min_castle, camp_gap, min_camp, gate_gap, min_gate, int(ok)
		])
	print("[3] no_overlap pass=%d" % int(all_ok))
	world.free()
	if not all_ok:
		failures.append("물 위 또는 스테이지 랜드마크(성/캠프/보스문) 안전 반경과 겹친 균열이 있다")

func _check_budget(run_seed: int) -> void:
	var world := _new_world(run_seed)
	var granted := 0
	for index in stage_budget:
		if not world.spawn_rift_near(_player_point(index)).is_empty():
			granted += 1
	var remaining_before: int = int(world.rift_budget_remaining())
	# v2는 여기가 "4번째 요청"이었다. v3에서는 **예산 + 1번째** 요청이다 — 예산이
	# 리튜닝되면 이 한 줄이 알아서 따라간다.
	var overflow: Dictionary = world.spawn_rift_near(_player_point(stage_budget))
	var reason: String = String(world.get_last_rift_result())
	var remaining_after: int = int(world.rift_budget_remaining())
	# WorldGrid는 v2 이름 `RIFT_MAX_PER_RUN`을 유지하되 값을 스테이지 예산으로
	# 별칭 처리했다(--save-test가 그 이름을 읽는다). 이름과 값이 어긋나면 이 프로브가
	# 먼저 잡도록 별칭 자체를 단언한다.
	var alias_ok: bool = int(world.RIFT_MAX_PER_RUN) == stage_budget
	# 런 합계 예산은 "스테이지 예산 × 스테이지 수"라는 정의가 살아 있어야 한다.
	var run_budget_ok: bool = int(GameTuning.RIFT_RUN_BUDGET) == stage_budget * int(GameTuning.STAGE_COUNT)
	var ok := granted == stage_budget and overflow.is_empty() and reason == "budget_exhausted" \
		and remaining_before == 0 and remaining_after == 0 and alias_ok and run_budget_ok
	print("    granted=%d/%d overflow_rejected=%d reason=%s remaining_before=%d remaining_after=%d" % [
		granted, stage_budget, int(overflow.is_empty()), reason, remaining_before, remaining_after
	])
	print("    run_budget=%d expected=%d(=%d스테이지×%d) world_alias=%d alias_matches=%d" % [
		int(GameTuning.RIFT_RUN_BUDGET), stage_budget * int(GameTuning.STAGE_COUNT),
		int(GameTuning.STAGE_COUNT), stage_budget, int(world.RIFT_MAX_PER_RUN), int(alias_ok)
	])
	print("[4] budget pass=%d" % int(ok))
	world.free()
	if not ok:
		failures.append("스테이지당 %d회 예산 규칙이 지켜지지 않았다" % stage_budget)

# =============================================================================
# ⑤ 시드 100개 배치 견고성 — Y5 신설
# =============================================================================
## 시드 100개 × 스테이지 1~STAGE_COUNT 순환. 시드마다 월드를 새로 세우고 예산만큼
## 균열을 요청한 뒤 세 가지를 단언한다.
##
##   ⑴ 균열 배치 실패 0건
##      빈 사전이 하나라도 나오면 안 된다. `_find_rift_site()`는 후보를
##      RIFT_CANDIDATES(96)개 굴려 보고 전부 물에 걸리면 포기한다 — 즉 이 단언이
##      깨진다는 것은 "물이 너무 많아 링 위에 마른 13×13 칸이 없다"는 뜻이고,
##      게임 안에서는 균열이 영영 안 열리는(= 스테이지 보상 경로가 끊기는) 버그가 된다.
##
##   ⑵ 랜드마크 3종이 전부 놓였고 셋 다 걸을 수 있다
##      `_nearest_dry_spot()`은 48번 굴려도 마른 자리를 못 찾으면 **원래 자리를 그냥
##      돌려준다**(world_grid.gd:294). 즉 실패해도 조용하다. 그래서 존재 여부만이 아니라
##      `is_walkable()`까지 본다 — 바닥 덮개(`_resolved_tile_id()`의 T_COURTYARD/T_CAMP)가
##      살아 있으면 참이어야 하고, 거짓이면 랜드마크가 물이나 돌 위에 앉았다는 뜻이다.
##
##   ⑶ 모든 균열 중심이 걸을 수 있다
##      균열 바닥도 같은 덮개 규칙으로 T_CAMP가 깔린다(world_grid.gd:777). 중심이
##      걷지 못하는 칸이면 덮개가 안 깔렸다는 것이고, 플레이어가 아레나 안으로
##      들어가지 못한다.
##
## 실패한 시드는 번호와 이유를 **전부** 출력한다. 개수만 세면 다음 사람이 재현할 수
## 없고, 이 파일이 v2에서 썩은 이유가 정확히 "조용히 통과/실패"였다.
func _check_seed_robustness() -> void:
	var stage_count := int(GameTuning.STAGE_COUNT)
	var placement_failures: Array[String] = []
	var landmark_failures: Array[String] = []
	var center_failures: Array[String] = []
	var wet_values: Array[float] = []
	var wet_lines: Array[String] = []
	var requested := 0
	var placed := 0
	var started_ms := Time.get_ticks_msec()
	for index in ROBUST_SEED_COUNT:
		var seed_value := ROBUST_SEED_BASE + index * ROBUST_SEED_STEP
		# 스테이지마다 지형 아틀라스·채도가 다르므로 1~5를 골고루 돈다.
		var stage := 1 + (index % stage_count)
		var world: Node2D = WORLD_SCRIPT.new()
		# 실제 게임(`game._rebuild_stage_world()`)과 같은 한 줄 구성. `begin_stage()`가
		# 끝에서 `begin_run_rifts(stage_seed)`까지 부른다(world_grid.gd:215).
		world.begin_stage(stage, seed_value)
		for request in stage_budget:
			requested += 1
			var rift: Dictionary = world.spawn_rift_near(_player_point(request))
			if rift.is_empty():
				placement_failures.append("seed=%d stage=%d req#%d reason=%s" % [
					seed_value, stage, request, String(world.get_last_rift_result())
				])
				continue
			placed += 1
			var center: Vector2 = rift["position"]
			if not world.is_walkable(center):
				center_failures.append("seed=%d stage=%d req#%d center=(%.0f, %.0f) tile=%s" % [
					seed_value, stage, request, center.x, center.y, String(world.tile_kind_at(center))
				])
		for key: String in ["castle", "camp", "boss_gate"]:
			var landmark: Dictionary = world.get_landmark(key)
			if landmark.is_empty():
				landmark_failures.append("seed=%d stage=%d %s=missing" % [seed_value, stage, key])
				continue
			var spot: Vector2 = landmark["position"]
			if not world.is_walkable(spot):
				landmark_failures.append("seed=%d stage=%d %s=(%.0f, %.0f) tile=%s 걸을 수 없음" % [
					seed_value, stage, key, spot.x, spot.y, String(world.tile_kind_at(spot))
				])
		# 10개마다 하나를 고르되 **10의 배수를 고르지 않는다**. 스테이지가
		# `1 + index % STAGE_COUNT`(5주기)라서 0,10,20…은 전부 스테이지 1이 되고,
		# 물 표본이 스테이지 1만 재는 공허한 계측이 된다. 대각선(0,11,22,…,99)으로
		# 뽑으면 10 표본이 스테이지 1~5를 두 번씩 고르게 훑는다.
		if index % ROBUST_MIX_EVERY == (index / ROBUST_MIX_EVERY) % ROBUST_MIX_EVERY:
			var mix: Dictionary = world.measure_terrain_mix(Vector2.ZERO, ROBUST_MIX_SPAN, ROBUST_MIX_STRIDE)
			var wet := float(mix["wet"])
			wet_values.append(wet)
			wet_lines.append("      seed=%d stage=%d wet=%.3f rock=%.3f walkable=%.3f samples=%d" % [
				seed_value, stage, wet, float(mix["rock"]), float(mix["walkable"]), int(mix["samples"])
			])
		# 월드 하나가 청크 캐시를 통째로 들고 있다. 100개를 쌓으면 메모리가 터지므로
		# 시드마다 반드시 놓아준다.
		world.free()
	var elapsed_ms := Time.get_ticks_msec() - started_ms

	print("    seeds=%d stages=1~%d seed=%d+i*%d requests=%d placed=%d elapsed=%dms" % [
		ROBUST_SEED_COUNT, stage_count, ROBUST_SEED_BASE, ROBUST_SEED_STEP, requested, placed, elapsed_ms
	])
	print("    물 비율 표본(%d 시드 · span=%d stride=%d · 원점 기준):" % [
		wet_values.size(), ROBUST_MIX_SPAN, ROBUST_MIX_STRIDE
	])
	for line: String in wet_lines:
		print(line)
	print("    wet_sample min=%.3f avg=%.3f max=%.3f band=%.2f~%.2f in_band=%d/%d" % [
		_min_of(wet_values), _avg_of(wet_values), _max_of(wet_values),
		WET_BAND_MIN, WET_BAND_MAX, _in_band_count(wet_values), wet_values.size()
	])
	_print_seed_failures("균열 배치 실패", placement_failures)
	_print_seed_failures("랜드마크 실패", landmark_failures)
	_print_seed_failures("균열 중심 통행 실패", center_failures)

	var ok := placement_failures.is_empty() and landmark_failures.is_empty() and center_failures.is_empty()
	print("[5] seed_robustness placement_failures=%d landmark_failures=%d rift_center_failures=%d pass=%d" % [
		placement_failures.size(), landmark_failures.size(), center_failures.size(), int(ok)
	])
	if not placement_failures.is_empty():
		failures.append("시드 %d개 중 %d건의 균열 배치가 실패했다(계약: 0건)" % [
			ROBUST_SEED_COUNT, placement_failures.size()
		])
	if not landmark_failures.is_empty():
		failures.append("랜드마크 3종이 없거나 걸을 수 없는 자리에 앉은 시드가 %d건이다" % landmark_failures.size())
	if not center_failures.is_empty():
		failures.append("균열 중심이 걸을 수 없는 시드가 %d건이다(아레나 바닥 덮개가 빠졌다)" % center_failures.size())

## 실패 목록을 하나도 빠짐없이 찍는다. 100줄이 나와도 그대로 찍는 게 낫다 —
## 개수만 남기면 상위에서 어느 시드를 파야 하는지 알 수 없다.
func _print_seed_failures(label: String, entries: Array[String]) -> void:
	print("    %s count=%d" % [label, entries.size()])
	for entry: String in entries:
		print("      !! %s" % entry)

func _min_of(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result := values[0]
	for value: float in values:
		result = minf(result, value)
	return result

func _max_of(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result := values[0]
	for value: float in values:
		result = maxf(result, value)
	return result

func _avg_of(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())

func _in_band_count(values: Array[float]) -> int:
	var inside := 0
	for value: float in values:
		if value >= WET_BAND_MIN and value <= WET_BAND_MAX:
			inside += 1
	return inside
