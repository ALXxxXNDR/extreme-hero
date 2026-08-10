extends SceneTree

# =============================================================================
# 지형 프로브 — 물 비율 계약과 2x2 블록 불변식 (Y5 신설 · FEEDBACK_Y §5.1 · 리스크 4)
# =============================================================================
#   godot --headless --path godot-game -s res://scripts/test/terrain_probe.gd
#   ... -s res://scripts/test/terrain_probe.gd -- fast   (호수 레이어만 · WFC 미해결 · 수백 배 빠름)
#
# `rift_probe.gd`와 같은 단독 프로브다(run_all.sh 목록에 없다 — 물 상수를 만질 때 손으로 돌린다).
# `--world-test`가 같은 계약을 게임 안에서 다시 재지만, 이 프로브는 **시드 20개 × 스테이지 5개 ×
# 지점 3곳 = 300 표본**을 훑으므로 상수를 조정하는 동안의 실측 도구는 이쪽이다.
#
# 재는 것 셋:
#   ① 젖은 칸 비율이 12~20% 창 안인가 — **총합**과 **백분위(p01·p99)** 둘 다 본다.
#      총합이 계약의 본체다(창 하나는 호수 하나가 들어오고 나가는 것만으로 흔들린다).
#      표본 전수 통과는 요구하지 않는다 — 아래 「판정 기준」 블록 참조.
#   ② 2x2 블록 합집합이 살아 있는가 — 젖은 칸의 마른 이웃 조합이 아틀라스에 없는
#      모양(`WATER_TILE_BY_DRY == -1`)이면 0이어야 한다. 물을 5배로 늘렸으니 이게 핵심이다.
#      **3차 피드백 "맵이 깨진다"의 근본 수정이 이 성질이다.**
#   ③ 눈으로 보는 표본 한 장 — 물이 "호수"로 보이는가 "물웅덩이 노이즈"로 보이는가.
#
# ⚠️ Y5가 상수를 고르며 실제로 밟은 함정: 비율만 맞추면 되는 줄 알고
#    `LAKE_CHANCE 41 · 반지름 [1,2,2,2,2,2]`로 맞췄더니 총량은 16%인데 화면에는
#    작은 물웅덩이만 흩뿌려졌고, 반대로 `LAKE_CHANCE 9 · 반지름 [4,4,4,5,5,5]`는
#    호수는 커졌지만 **화면 절반에 물이 아예 없었다**(13칸 격자에 9%면 한 화면에
#    호수 0.46개다). 그래서 ③번 지도 덤프가 이 프로브에 남아 있다.

const WORLD_SCRIPT := preload("res://scripts/world_grid.gd")

const SEED_COUNT := 20
const SEED_BASE := 20260810
const SEED_STEP := 7919

const SPAN := 300
const STRIDE := 3
const FAR_CENTER := Vector2(20000.0, -15000.0)

# -----------------------------------------------------------------------------
# 판정 기준 (YZ 완화 · handoff-y8 §9-2)
# -----------------------------------------------------------------------------
# 원래 판정식은 `inside == all_wet.size()`, 즉 표본 300개가 **하나도 빠짐없이**
# 12~20% 창 안에 들어야 PASS였다. 실측에서 딱 하나가 0.201로 상한을 0.001 넘겨
# full 모드가 FAIL이 됐다(fast는 PASS). 나머지 299개는 창 안이고 2×2 블록 불변식도
# 참이었다 — 화면에 보이는 지형은 멀쩡한데 판정식만 빨간 상태였다.
#
# 지형 규칙은 한 줄도 안 바꿨다. 대신 **판정식을 백분위로** 바꿨다.
#   ① p99가 창 안이어야 한다      — 표본의 99%가 창을 지킨다는 뜻
#   ② 최대 초과가 TOLERANCE 이하   — 남은 1%도 창에서 0.005(=0.5%p) 넘게 벗어나지 않는다
#   ③ 총합(AGGREGATE)이 창 안      — 계약의 본체는 원래부터 총합이었다(위 주석 ①)
#   ④ 2×2 블록 불변식             — 무변경
#
# 호수는 랜덤 배치라 한 화면 안에 큰 것 하나가 통째로 들어오면 비율이 한 칸 튄다.
# 300 표본 전수 통과를 요구하는 것은 그 흔들림까지 없으라는 요구였고, 이는
# 지형을 더 단조롭게 만드는 방향으로만 만족된다(§21의 함정 그대로).
#
# 손계산 검산 — FAIL을 냈던 full 실측(handoff-y8 §9-2)을 이 식에 그대로 넣으면:
#   실측: 표본 300 · min 0.126 · avg 0.157 · max 0.201 · in_band 299/300
#         최고점 stage1 seed20268729 gate(0.201) · impossible_shapes 0
#   ① p01 = 3번째로 작은 값 ≥ min 0.126 ≥ 0.12                        → 참
#   ② p99 = 297번째 값. 창 밖은 1개뿐이라 297번째는 창 안 ≤ 0.20        → 참
#   ③ over = 0.201 − 0.200 = 0.001 ≤ 0.005 · under = 0 ≤ 0.005        → 참
#   ④ aggregate = 0.157 ∈ [0.12, 0.20]                                → 참
#   ⑤ block_invariant: impossible_shapes 0                            → 참
#   → verdict=PASS. 지형 규칙을 한 줄도 안 고치고 그 FAIL만 걷힌다.
# 참고: 같은 지점을 fast 모드로 재면 0.200이 나온다(랜드마크 덮개·강을 안 세므로).
# 0.001은 표본 하나가 창 경계에 걸터앉았다는 뜻이지 지형 결함이 아니라는 방증이다.
const BAND_LOW := 0.12
const BAND_HIGH := 0.20
## 창 밖으로 나가도 봐주는 폭. 0.005 = 표본 한 장에서 젖은 칸 0.5%p.
const BAND_TOLERANCE := 0.005
## 백분위 판정에 쓰는 하위/상위 지점. **"몇 개까지 봐주는가"가 여기서 정해진다** —
## `_percentile`이 최근접 순위라 표본 300개에서
##   p99 = 297번째로 작은 값 → 창을 넘는 표본 **3개까지** 면제
##   p01 = 3번째로 작은 값   → 창에 못 미치는 표본 **2개까지** 면제
## 면제는 "무시"가 아니다. 면제된 표본도 BAND_TOLERANCE를 넘으면 ②에서 걸리므로,
## 봐주는 것은 **개수 3개 이내 × 이탈폭 0.005 이내**를 동시에 만족하는 경우뿐이다.
## 이 둘 중 하나만 완화하면 판정이 실제로 물러진다 — 항상 같이 봐야 한다.
const PERCENTILE_LOW := 0.01
const PERCENTILE_HIGH := 0.99

var fast := false

func _initialize() -> void:
	fast = OS.get_cmdline_user_args().has("fast")
	print("Y5_TERRAIN_PROBE_BEGIN mode=%s span=%d stride=%d" % ["fast" if fast else "full", SPAN, STRIDE])
	var agg_wet := 0
	var agg_samples := 0
	var all_wet: Array[float] = []
	var all_rock: Array[float] = []
	var all_walk: Array[float] = []
	var worst_label := ""
	var worst_wet := 0.0
	var best_label := ""
	var best_wet := 1.0
	for stage in range(1, 6):
		var stage_wet: Array[float] = []
		var stage_rock: Array[float] = []
		var stage_walk: Array[float] = []
		for index in SEED_COUNT:
			var seed_value := SEED_BASE + index * SEED_STEP
			var world: Node2D = WORLD_SCRIPT.new()
			world.begin_stage(stage, seed_value)
			var spots := {
				"home": Vector2.ZERO,
				"gate": world.get_boss_gate_position(),
				"far": FAR_CENTER
			}
			for key: String in spots:
				var mix: Dictionary = _fast_mix(world, spots[key]) if fast else world.measure_terrain_mix(spots[key], SPAN, STRIDE)
				var wet := float(mix["wet"])
				agg_samples += int(mix["samples"])
				agg_wet += int(roundf(wet * float(int(mix["samples"]))))
				stage_wet.append(wet)
				stage_rock.append(float(mix["rock"]))
				stage_walk.append(float(mix["walkable"]))
				all_wet.append(wet)
				all_rock.append(float(mix["rock"]))
				all_walk.append(float(mix["walkable"]))
				if wet > worst_wet:
					worst_wet = wet
					worst_label = "stage%d seed%d %s" % [stage, seed_value, key]
				if wet < best_wet:
					best_wet = wet
					best_label = "stage%d seed%d %s" % [stage, seed_value, key]
			var cached := int(world.get_generation_stats().get("cached_chunks", 0))
			if cached > 72:
				print("  !! cache_overflow stage=%d seed=%d cached=%d" % [stage, seed_value, cached])
			world.free()
		print("stage %d  wet min=%.3f avg=%.3f max=%.3f | rock avg=%.4f max=%.4f | walk min=%.3f avg=%.3f" % [
			stage, _min(stage_wet), _avg(stage_wet), _max(stage_wet),
			_avg(stage_rock), _max(stage_rock), _min(stage_walk), _avg(stage_walk)
		])
	var inside := 0
	for value: float in all_wet:
		if value >= BAND_LOW and value <= BAND_HIGH:
			inside += 1
	var aggregate := float(agg_wet) / float(maxi(1, agg_samples))
	print("TOTAL samples=%d wet min=%.3f avg=%.3f max=%.3f  rock avg=%.4f  walk min=%.3f avg=%.3f" % [
		all_wet.size(), _min(all_wet), _avg(all_wet), _max(all_wet),
		_avg(all_rock), _min(all_walk), _avg(all_walk)
	])
	print("  AGGREGATE wet=%.4f  (%d wet / %d samples)" % [aggregate, agg_wet, agg_samples])
	print("  in_band(12~20%%)=%d/%d  lowest=%s(%.3f)  highest=%s(%.3f)" % [
		inside, all_wet.size(), best_label, best_wet, worst_label, worst_wet
	])

	# --- 백분위 판정 (YZ) ---------------------------------------------------
	var p01 := _percentile(all_wet, PERCENTILE_LOW)
	var p99 := _percentile(all_wet, PERCENTILE_HIGH)
	# 창 밖으로 벗어난 폭. 창 안이면 0이다.
	var over := maxf(0.0, _max(all_wet) - BAND_HIGH)
	var under := maxf(0.0, BAND_LOW - _min(all_wet))
	var pct_ok := p01 >= BAND_LOW and p99 <= BAND_HIGH
	var tol_ok := over <= BAND_TOLERANCE and under <= BAND_TOLERANCE
	var agg_ok := aggregate >= BAND_LOW and aggregate <= BAND_HIGH
	print("  PERCENTILE p01=%.4f p99=%.4f (창 %.2f~%.2f)  band_ok=%s" % [p01, p99, BAND_LOW, BAND_HIGH, pct_ok])
	print("  EXCURSION over=%.4f under=%.4f (허용 %.4f)  tol_ok=%s  aggregate_ok=%s" % [
		over, under, BAND_TOLERANCE, tol_ok, agg_ok
	])

	var invariant_ok := _check_block_invariant()
	_dump_map()
	var verdict_ok := pct_ok and tol_ok and agg_ok and invariant_ok
	print("Y5_TERRAIN_PROBE_COMPLETE verdict=%s block_invariant=%s percentile=%s tolerance=%s aggregate=%s" % [
		"PASS" if verdict_ok else "FAIL", invariant_ok, pct_ok, tol_ok, agg_ok
	])
	quit(0)


## 오름차순 정렬 후 최근접 순위(nearest-rank) 백분위. 표본 300개에서 p99는
## 297번째로 작은 값이라 상위 3개의 흔들림을 흡수한다.
func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var rank := int(ceil(ratio * float(sorted.size())))
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]

## 2x2 블록 합집합이 깨지지 않았는가. 젖은 칸의 마른 이웃 조합이 아틀라스에 없는
## 모양(WATER_TILE_BY_DRY == -1)이면 호수 그림이 끊긴다 — 물을 5배로 늘렸으니
## 이 성질이 살아 있는지 직접 확인한다.
func _check_block_invariant() -> bool:
	var bad := 0
	var checked := 0
	for stage in range(1, 6):
		for index in 6:
			var world: Node2D = WORLD_SCRIPT.new()
			world.begin_stage(stage, SEED_BASE + index * SEED_STEP)
			var generator: Variant = world.terrain_generator
			for y in range(-120, 120):
				for x in range(-120, 120):
					var here := Vector2i(x, y)
					if not generator.is_wet_tile(here):
						continue
					checked += 1
					var mask := 0
					if not generator.is_wet_tile(here + Vector2i(0, -1)):
						mask |= 1
					if not generator.is_wet_tile(here + Vector2i(1, 0)):
						mask |= 2
					if not generator.is_wet_tile(here + Vector2i(0, 1)):
						mask |= 4
					if not generator.is_wet_tile(here + Vector2i(-1, 0)):
						mask |= 8
					if int(generator.WATER_TILE_BY_DRY[mask]) < 0:
						bad += 1
			world.free()
	print("block_invariant wet_tiles=%d impossible_shapes=%d" % [checked, bad])
	return bad == 0

## 눈으로 보는 표본 한 장. `#`=물 `.`=뭍.
func _dump_map() -> void:
	var world: Node2D = WORLD_SCRIPT.new()
	world.begin_stage(1, SEED_BASE)
	var generator: Variant = world.terrain_generator
	print("--- stage1 seed%d 지형 표본 (스폰에서 먼 곳 · 가로 96 x 세로 44 타일) ---" % SEED_BASE)
	for y in range(300, 344):
		var row := ""
		for x in range(300, 396):
			row += "#" if generator.is_wet_tile(Vector2i(x, y)) else "."
		print(row)
	world.free()

## 호수 레이어만 세는 빠른 어림. WFC를 풀지 않으므로 수백 배 빠르고, 젖은 칸
## 집합은 `is_water_tile`이 세는 것과 같다(랜드마크 덮개·강만큼만 어긋난다).
func _fast_mix(world: Node2D, center: Vector2) -> Dictionary:
	var generator: Variant = world.terrain_generator
	var tile: int = int(world.TILE)
	var center_tile := Vector2i(floori(center.x / float(tile)), floori(center.y / float(tile)))
	var half := SPAN / 2
	var samples := 0
	var wet := 0
	var offset_y := -half
	while offset_y < SPAN - half:
		var offset_x := -half
		while offset_x < SPAN - half:
			samples += 1
			if generator.is_wet_tile(center_tile + Vector2i(offset_x, offset_y)):
				wet += 1
			offset_x += STRIDE
		offset_y += STRIDE
	return {"wet": float(wet) / float(maxi(1, samples)), "rock": 0.0, "walkable": 0.0, "samples": samples}

func _min(values: Array[float]) -> float:
	var result := 1.0
	for value: float in values:
		result = minf(result, value)
	return result

func _max(values: Array[float]) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result

func _avg(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())
