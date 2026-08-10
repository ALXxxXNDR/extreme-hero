extends SceneTree

# =============================================================================
# Y0 — 각인 규칙 엔진 단독 테스트 (standalone)
# =============================================================================
# 실행:
#   godot --headless --path godot-game -s res://scripts/test/rune_test.gd
#
# 기존 하네스(test_runner.gd·run_all.sh·game.gd)를 한 줄도 건드리지 않는다. 이 스크립트는
# SceneTree를 직접 확장해 메인 씬 없이 돌기 때문에 게임 코드를 전혀 로드하지 않는다.
#
# 출력 규약(run_all.sh와 동일 — W1에서 승계):
#   * 합격 → `RUNE_TEST_COMPLETE <판정>=true ... <수치>=<숫자>` 한 줄 + 종료 코드 0
#   * 불합격 → `RUNE_TEST_DETAIL ...` 여러 줄 + `RUNE_TEST_FAILED failed=...` + 종료 코드 1
#   * 판정은 전부 `=true`로만 나온다. 정보성 값은 숫자로 낸다(=false 문자열 금지 —
#     run_all.sh가 문자열 "false"를 보면 FAIL로 집계한다).
#
# ## 이번 웨이브(Y0)에서 통째로 갈아엎은 이유
# 과열이 폐기되고 **SLOT_EXEC_CAP = 2**(한 칸은 한 바퀴에 두 번까지)가 그 자리에 들어왔다.
# 각인은 24종 → 15종(칸 10 + 레일 5). 구 테스트는 폐기된 각인 id 16종과 과열 상수를
# 직접 참조하고 있었으므로 살릴 수 있는 부분이 없었다. 감쇠 4겹(§2.4)·결정성·원소 어휘·
# L1 반응 검사는 **취지를 그대로 승계**하고 id만 새것으로 갈아끼웠다.
#
# ## 이 파일이 증명하려는 핵심 계약 (§1.3)
#   ① 모든 사이클에서 max(slot_exec) ≤ 2
#   ② 모든 사이클에서 step_count ≤ 2 × deck.size()
#   ③ end_reason == "overload" 가 **0건** (기존 "과부하율 0.70%"를 대체하는 새 회귀 계약)
# 종료성이 확률이 아니라 산수로 증명되므로, 밴드가 아니라 **하드 단언**으로 잰다.

const Rune = preload("res://scripts/core/rune_engine.gd")

# ------------------------------------------------------------------ 표본 규모
const MC_RANDOM := 10000       # 무작위 인구 (칸 1~5 · 각인 0~5 · 레일 각인 0~3)
const MC_STRESS := 2000        # 극단 인구 각각의 표본 수
const MC_SHAPE := 1200         # edge_shapes: n별 표본 수
const DETERMINISM_RUNS := 100  # 같은 시드 반복 횟수
const ROLL_SAMPLES := 200      # roll_rune 범위 검사 표본 (각인당)

# ---------------------------------------------------------------- 카탈로그 계약
## v3 24종 전부. `docs/v1-archive/rune_engine_v3_24.gd.txt`에서 뽑은 실제 목록이다.
## 이 중 **한 개라도** RUNES에 남아 있으면 폐기가 덜 된 것이다(§2.3).
const DEPRECATED_IDS: Array[String] = [
	"rewind_1", "rewind_2", "repeat", "skip_1", "reverse", "bookmark", "link_next",
	"chorus", "overlap", "tag_chain", "heat_gate", "last_call", "odd_even", "refund",
	"toll", "afterburn", "barb", "edge", "reach", "free_reload", "first_strike",
	"echo", "kill_repeat", "haste"
]
const SLOT_IDS: Array[String] = [
	"twice", "back_one", "jump_one", "strong", "wide",
	"quick", "first_hit", "twin_cast", "trade_skip", "finisher"
]
const RAIL_IDS: Array[String] = [
	"rail_fast", "rail_power", "rail_rest", "rail_color", "rail_loop"
]
## §2.6 흐름 할증(RUNE_SHOP_FLOW_PREMIUM 1.25) 대상과 **정확히** 일치해야 한다.
const FLOW_IDS: Array[String] = [
	"twice", "back_one", "jump_one", "trade_skip", "finisher", "rail_loop"
]
const RUNE_KEYS: Array[String] = [
	"id", "name", "scope", "family", "cond", "effect", "roll",
	"p_min", "p_max", "mag_min", "mag_max", "rarity"
]
## condition_ok()가 아는 어휘. 여기 없는 cond는 조용히 `always`로 떨어져 버그가 숨는다.
## Y8: `heat_gate` 분기를 `rune_engine`에서 지웠으므로 어휘에서도 뺐다 —
## 15종 중 그 cond를 쓰는 각인이 하나도 없다(있었다면 `always`로 떨어져 즉시 터진다).
const COND_VOCABULARY: Array[String] = [
	"always", "first", "reentry", "kill", "prev_slot", "prev_same_element"
]

# 합성 카드 9종. 실제 deal_card_library를 로드하지 않는다(엔진 순수성 검증이 목적이다).
# 인덱스 0~4의 원소는 화·빙·뇌·독·유다. 수치·배열 위치를 바꾸지 말 것 —
# 아래 덱 빌더들이 `CARDS[i] for i in n`으로 앞 n장을 쓰고, 몇몇 단언이
# 그 reload/damage/duration을 직접 계산한다.
const CARDS: Array[Dictionary] = [
	{"id": "c_fire", "damage": 1.6, "reload": 0.48, "duration": 1.2, "element": "fire", "form": "slash"},
	{"id": "c_ice", "damage": 1.05, "reload": 0.86, "duration": 1.6, "element": "ice", "form": "wave"},
	{"id": "c_thunder", "damage": 1.02, "reload": 0.82, "duration": 1.4, "element": "thunder", "form": "pierce"},
	{"id": "c_poison", "damage": 1.55, "reload": 1.05, "duration": 1.8, "element": "poison", "form": "wave"},
	{"id": "c_oil", "damage": 0.92, "reload": 0.62, "duration": 1.28, "element": "oil", "form": "slash"},
	{"id": "c_strike", "damage": 0.82, "reload": 0.55, "duration": 1.02, "element": "strike", "form": "guard"},
	{"id": "c_psi", "damage": 1.10, "reload": 0.60, "duration": 1.10, "element": "psi", "form": "guard"},
	{"id": "c_fast", "damage": 0.58, "reload": 0.14, "duration": 0.82, "element": "thunder", "form": "slash"},
	{"id": "c_heavy", "damage": 4.2, "reload": 1.25, "duration": 2.15, "element": "fire", "form": "trap"}
]

var _checks: Dictionary = {}
var _failures: Array[String] = []
var _metrics: Dictionary = {}

# 종료성 누산기 — 모든 인구가 여기에 관측을 밀어 넣는다.
var _obs_cycles := 0
var _obs_overload := 0
var _obs_guard := 0
var _obs_exec_violation := 0
var _obs_step_violation := 0
var _obs_shape_violation := 0
var _max_steps_by_n: Array[int] = [0, 0, 0, 0, 0, 0]   # index = 칸 수 n (0번은 안 씀)

func _initialize() -> void:
	_check_catalog()
	_check_roll_rune()
	_check_slot_falloff()
	_check_slot_ownership()
	_check_slot_runes()
	_check_rail_scope()
	_check_rail_numbers()
	_check_rail_caps()
	_check_rail_loop_ten()
	_check_determinism()
	_check_purity()
	_check_elements()
	_check_reactions()
	_run_montecarlo()
	_check_edge_shapes()
	_finish_termination_verdicts()
	_report()

func _process(_delta: float) -> bool:
	return true

# -----------------------------------------------------------------------------
# 판정 헬퍼
# -----------------------------------------------------------------------------
func _verdict(name: String, ok: bool, detail: String = "") -> void:
	_checks[name] = bool(_checks.get(name, true)) and ok
	if not ok:
		_failures.append("%s: %s" % [name, detail])

func _near(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) <= eps

## 각인 인스턴스 하나. p·mag를 생략하면 정의의 최대치를 쓴다.
func _inst(id: String, p: float = -1.0, mag: float = -1.0) -> Dictionary:
	var def: Dictionary = Rune.RUNES[id]
	return {
		"id": id,
		"p": (float(def["p_max"]) if p < 0.0 else p),
		"mag": (float(def["mag_max"]) if mag < 0.0 else mag)
	}

func _set_equal(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	var seen: Dictionary = {}
	for v in actual:
		seen[String(v)] = true
	if seen.size() != expected.size():
		return false
	for v in expected:
		if not seen.has(String(v)):
			return false
	return true

func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out

## 원소·형태를 지운 "기계적" 덱. 반응·공명이 전부 꺼지므로 damage_mul이 각인 효과만
## 반영한다 — 개별 각인의 의미를 1e-9 단위로 잴 수 있다.
func _plain_deck(n: int) -> Array:
	var slots: Array = []
	for i in n:
		var card: Dictionary = CARDS[i % CARDS.size()].duplicate(true)
		card["element"] = ""
		card["form"] = ""
		slots.append(Rune.make_slot(card, []))
	return slots

# =============================================================================
# A. 카탈로그 계약 (§2.1 · §2.2 · §2.3)
# =============================================================================
func _check_catalog() -> void:
	# --- catalog_15: 정확히 15키 + 폐기 24종 전건 부재 -------------------------
	_verdict("catalog_15", Rune.RUNES.size() == 15,
		"RUNES가 %d종 (기대 15종)" % Rune.RUNES.size())
	var leftovers: Array[String] = []
	for id in DEPRECATED_IDS:
		if Rune.RUNES.has(id):
			leftovers.append(id)
	_verdict("catalog_15", leftovers.is_empty(),
		"폐기 각인이 아직 카탈로그에 있다: %s" % ",".join(leftovers))
	# 승계 id 15종이 전부 있다(오타로 하나가 사라지면 상점·저장이 조용히 깨진다).
	var expected_all: Array[String] = []
	expected_all.append_array(SLOT_IDS)
	expected_all.append_array(RAIL_IDS)
	_verdict("catalog_15", _set_equal(Rune.RUNES.keys(), expected_all),
		"카탈로그 키 집합 불일치: %s" % [Rune.RUNES.keys()])
	# 각 정의의 "id" 필드가 키와 일치한다(복붙 사고 방지).
	var id_field_ok := true
	for id: String in Rune.RUNES.keys():
		if String((Rune.RUNES[id] as Dictionary).get("id", "")) != id:
			id_field_ok = false
	_verdict("catalog_15", id_field_ok, "정의의 id 필드가 카탈로그 키와 다르다")
	_metrics["rune_count"] = Rune.RUNES.size()

	# --- rarity_split: 일반 6 · 희귀 6 · 영웅 3 --------------------------------
	var common: Array = Rune.ids_by_rarity(Rune.RARITY_COMMON)
	var rare: Array = Rune.ids_by_rarity(Rune.RARITY_RARE)
	var epic: Array = Rune.ids_by_rarity(Rune.RARITY_EPIC)
	_verdict("rarity_split", common.size() == 6, "일반 %d종 (기대 6)" % common.size())
	_verdict("rarity_split", rare.size() == 6, "희귀 %d종 (기대 6)" % rare.size())
	_verdict("rarity_split", epic.size() == 3, "영웅 %d종 (기대 3)" % epic.size())
	_verdict("rarity_split", common.size() + rare.size() + epic.size() == Rune.RUNES.size(),
		"레어리티 3종 밖의 값을 가진 각인이 있다")
	_metrics["rarity_common"] = common.size()
	_metrics["rarity_rare"] = rare.size()
	_metrics["rarity_epic"] = epic.size()

	# --- scope_split: slot 10 · rail 5 -----------------------------------------
	var slot_ids: Array = Rune.ids_by_scope("slot")
	var rail_ids: Array = Rune.ids_by_scope("rail")
	_verdict("scope_split", _set_equal(slot_ids, SLOT_IDS),
		"칸 각인 집합 불일치(%d종): %s" % [slot_ids.size(), slot_ids])
	_verdict("scope_split", _set_equal(rail_ids, RAIL_IDS),
		"레일 각인 집합 불일치(%d종): %s" % [rail_ids.size(), rail_ids])
	# 모든 정의가 scope 키를 **직접** 갖는다. rune_scope()는 없으면 "slot"으로 떨어지므로
	# 키 누락이 조용히 통과할 수 있다 — 그래서 정의를 직접 본다.
	var scope_key_ok := true
	for id: String in Rune.RUNES.keys():
		var def: Dictionary = Rune.RUNES[id]
		if not def.has("scope"):
			scope_key_ok = false
		elif String(def["scope"]) != "slot" and String(def["scope"]) != "rail":
			scope_key_ok = false
	_verdict("scope_split", scope_key_ok, "scope 키가 없거나 slot/rail 밖의 값이다")
	_metrics["scope_slot"] = slot_ids.size()
	_metrics["scope_rail"] = rail_ids.size()

	# --- flow_family: §2.6 흐름 할증 대상과 정확히 일치 -------------------------
	var flow: Array = Rune.ids_by_family("flow")
	_verdict("flow_family", _set_equal(flow, FLOW_IDS),
		"family==flow 집합 불일치(%d종): %s" % [flow.size(), flow])

	# --- rune_schema: 15종 전부의 필수 키와 값 범위 -----------------------------
	var rarities := [Rune.RARITY_COMMON, Rune.RARITY_RARE, Rune.RARITY_EPIC]
	for id: String in Rune.RUNES.keys():
		var def: Dictionary = Rune.RUNES[id]
		for key in RUNE_KEYS:
			_verdict("rune_schema", def.has(key), "%s에 필수 키 %s가 없다" % [id, key])
		if not def.has("p_min") or not def.has("p_max"):
			continue
		var p_min := float(def["p_min"])
		var p_max := float(def["p_max"])
		var mag_min := float(def["mag_min"])
		var mag_max := float(def["mag_max"])
		_verdict("rune_schema", p_min <= p_max, "%s p_min %.2f > p_max %.2f" % [id, p_min, p_max])
		_verdict("rune_schema", mag_min <= mag_max,
			"%s mag_min %.2f > mag_max %.2f" % [id, mag_min, mag_max])
		_verdict("rune_schema", p_min >= 0.0 and p_max <= 1.0,
			"%s 확률 범위가 [0,1] 밖이다 (%.2f~%.2f)" % [id, p_min, p_max])
		# 확정 각인(roll == false)은 확률이 의미가 없으므로 반드시 1.0/1.0이다.
		if not bool(def["roll"]):
			_verdict("rune_schema", _near(p_min, 1.0) and _near(p_max, 1.0),
				"확정 각인 %s의 p가 1.0/1.0이 아니다 (%.2f~%.2f)" % [id, p_min, p_max])
		_verdict("rune_schema", rarities.has(String(def["rarity"])),
			"%s의 rarity가 3종 밖이다: %s" % [id, def["rarity"]])
		_verdict("rune_schema", COND_VOCABULARY.has(String(def["cond"])),
			"%s의 cond가 어휘 밖이다: %s" % [id, def["cond"]])
		_verdict("rune_schema", String(def["name"]) != "" and String(def["effect"]) != "",
			"%s의 이름/문구가 비었다" % id)

func _check_roll_rune() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240707
	var ok := true
	for id: String in Rune.RUNES.keys():
		var def: Dictionary = Rune.RUNES[id]
		for _s in ROLL_SAMPLES:
			var inst: Dictionary = Rune.roll_rune(id, rng)
			if String(inst.get("id", "")) != id:
				ok = false
				break
			var p := float(inst["p"])
			var mag := float(inst["mag"])
			if p < float(def["p_min"]) - 1e-9 or p > float(def["p_max"]) + 1e-9:
				ok = false
				_failures.append("roll_rune_range: %s p=%.4f 범위 밖" % [id, p])
				break
			if mag < float(def["mag_min"]) - 1e-9 or mag > float(def["mag_max"]) + 1e-9:
				ok = false
				_failures.append("roll_rune_range: %s mag=%.4f 범위 밖" % [id, mag])
				break
	_verdict("roll_rune_range", ok, "roll_rune가 정의 범위를 벗어난 인스턴스를 냈다")
	# 없는 id는 빈 사전 — 저장 호환 경로가 죽지 않아야 한다.
	_verdict("roll_rune_range", (Rune.roll_rune("rewind_1", rng) as Dictionary).is_empty(),
		"폐기 id로 roll_rune이 인스턴스를 냈다")
	_metrics["roll_samples"] = ROLL_SAMPLES * Rune.RUNES.size()

# =============================================================================
# F. 칸 감쇠 4겹 — 유지 계약 (§2.4 "그대로 유지"). 구 테스트에서 승계, id만 교체.
# =============================================================================
func _check_slot_falloff() -> void:
	# ① 여집합 곱 + DUP_P_FALLOFF^(k-1) --------------------------------------
	var one: float = Rune.merged_probability([_inst("twice", 0.3)])
	_verdict("merged_probability", _near(one, 0.3), "사본 1개 p=%f" % one)
	var two: float = Rune.merged_probability([_inst("twice", 0.3), _inst("twice", 0.3)])
	var expect2 := 1.0 - (1.0 - 0.3) * (1.0 - 0.3 * Rune.DUP_P_FALLOFF)
	_verdict("merged_probability", _near(two, expect2), "사본 2개 %f (기대 %f)" % [two, expect2])
	var three: float = Rune.merged_probability([_inst("twice", 0.3), _inst("twice", 0.3), _inst("twice", 0.3)])
	var expect3 := 1.0 - (1.0 - 0.3) * (1.0 - 0.3 * Rune.DUP_P_FALLOFF) \
		* (1.0 - 0.3 * pow(Rune.DUP_P_FALLOFF, 2))
	_verdict("merged_probability", _near(three, expect3), "사본 3개 %f (기대 %f)" % [three, expect3])
	_verdict("merged_probability", one < two and two < three and three < 0.9,
		"단조 증가 + 선형합(0.9) 미만이 아니다: %f %f %f" % [one, two, three])
	# 한 칸 몰빵이 유일 정답이 되지 않는다는 수치적 근거.
	var stacked: float = Rune.merged_probability([_inst("jump_one", 0.45), _inst("jump_one", 0.45), _inst("jump_one", 0.45)])
	_verdict("merged_probability", stacked < 0.45 * 3.0,
		"몰빵 %f이 흩어놓기 %f보다 유리하다" % [stacked, 0.45 * 3.0])
	_metrics["stack_p1"] = one
	_metrics["stack_p3"] = three
	_metrics["stack_vs_spread"] = stacked / (0.45 * 3.0)

	# ② DUP_MAG_FALLOFF^(k-1) -------------------------------------------------
	var mag: float = Rune.merged_magnitude([_inst("strong", 1.0, 0.4), _inst("strong", 1.0, 0.4), _inst("strong", 1.0, 0.4)])
	var mag_expect := 0.4 * (1.0 + Rune.DUP_MAG_FALLOFF + pow(Rune.DUP_MAG_FALLOFF, 2))
	_verdict("merged_magnitude", _near(mag, mag_expect), "strong x3 = %f (기대 %f)" % [mag, mag_expect])
	_verdict("merged_magnitude", mag < 0.4 * 3.0, "중복 크기에 감쇠가 없다")
	_verdict("merged_magnitude", _near(Rune.merged_magnitude([]), 0.0), "빈 스택 크기가 0이 아니다")

	# ③ 과밀 0.80^초과 ---------------------------------------------------------
	_verdict("congestion_scale", _near(Rune.congestion_scale(3), 1.0), "각인 3개가 페널티를 받았다")
	_verdict("congestion_scale", _near(Rune.congestion_scale(4), Rune.CONGESTION_FALLOFF), "4개 배율 오류")
	_verdict("congestion_scale", _near(Rune.congestion_scale(5), pow(Rune.CONGESTION_FALLOFF, 2.0)), "5개 배율 오류")
	_verdict("congestion_scale", _near(Rune.congestion_scale(0), 1.0), "0개 배율 오류")

	# ④ RUNE_STACK_CAP 5 · SAME_ID_STACK_CAP 3 ---------------------------------
	_verdict("stack_caps", Rune.RUNE_STACK_CAP == 5, "RUNE_STACK_CAP=%d" % Rune.RUNE_STACK_CAP)
	_verdict("stack_caps", Rune.SAME_ID_STACK_CAP == 3, "SAME_ID_STACK_CAP=%d" % Rune.SAME_ID_STACK_CAP)
	var slot_a: Dictionary = Rune.make_slot(CARDS[0], [])
	var same_ok := 0
	for _i in 10:
		if Rune.attach_rune(slot_a, _inst("twice")):
			same_ok += 1
	_verdict("stack_caps", same_ok == Rune.SAME_ID_STACK_CAP, "같은 id 부착 %d개 허용" % same_ok)
	var slot_b: Dictionary = Rune.make_slot(CARDS[0], [])
	var total_ok := 0
	for id in SLOT_IDS:
		if Rune.attach_rune(slot_b, _inst(id)):
			total_ok += 1
	_verdict("stack_caps", total_ok == Rune.RUNE_STACK_CAP, "총 부착 %d개 허용" % total_ok)
	_verdict("stack_caps", not Rune.attach_rune(slot_b, {"id": "does_not_exist", "p": 1.0, "mag": 1.0}),
		"없는 id가 부착됐다")

	# ⑤ P_CAP 0.75 클램프 -------------------------------------------------------
	_verdict("p_cap", _near(Rune.P_CAP, 0.75), "P_CAP=%f" % Rune.P_CAP)
	var cap_ok := true
	for i in 400:
		var base := float(i) / 100.0
		for load in [0.0, 0.5, 1.0, 3.0, 9.0]:
			var p: float = Rune.effective_probability(base, load, 1.0)
			if p > Rune.P_CAP + 1e-9 or p < 0.0:
				cap_ok = false
	_verdict("p_cap", cap_ok, "effective_probability가 [0, P_CAP]를 벗어났다")
	_verdict("p_cap", _near(Rune.effective_probability(1.0, 0.0, 1.0), Rune.P_CAP),
		"p=1.0에서 상한에 닿지 않는다")
	# 과밀 배율은 클램프 **전에** 곱해진다.
	_verdict("p_cap", _near(Rune.effective_probability(0.5, 0.0, Rune.CONGESTION_FALLOFF), 0.5 * Rune.CONGESTION_FALLOFF),
		"과밀 배율이 반영되지 않는다")
	# Y8: 구 `heat_neutral` 묶음에서 옮겨 왔다. 두 번째 인자(`deviation_load`)는
	# `game.gd:3045`의 3인자 호출 때문에 시그니처에만 남아 있고 **읽히면 안 된다.**
	# 셔틀 상수는 전부 삭제됐지만 이 인자는 남았으므로 계약도 남아야 한다.
	var load_ok := true
	for load in [0.0, 1.0, 3.0, 9.0, 99.0]:
		if not _near(Rune.effective_probability(0.5, float(load), 1.0), 0.5, 1e-9):
			load_ok = false
	_verdict("p_cap", load_ok, "effective_probability가 아직 deviation_load를 읽는다")

# =============================================================================
# G. 결정성 · 순수성 — 구 테스트에서 승계
# =============================================================================
func _check_slot_ownership() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[0], _inst("back_one"))
	Rune.attach_rune(deck[0], _inst("strong"))
	Rune.attach_rune(deck[3], _inst("jump_one"))

	var card0_before := String((deck[0] as Dictionary)["card"]["id"])
	var card3_before := String((deck[3] as Dictionary)["card"]["id"])

	# ① 칸 교환 — 각인이 칸과 **함께** 이동한다.
	Rune.swap_slots(deck, 0, 3)
	var slot0: Dictionary = deck[0]
	var slot3: Dictionary = deck[3]
	var ok_travel := (slot0["runes"] as Array).size() == 1 \
		and String((slot0["runes"] as Array)[0]["id"]) == "jump_one" \
		and (slot3["runes"] as Array).size() == 2 \
		and String(slot0["card"]["id"]) == card3_before \
		and String(slot3["card"]["id"]) == card0_before
	_verdict("slot_ownership", ok_travel, "swap_slots가 각인을 데려가지 않았다")

	# 시뮬레이션 관점에서도 확인: 교환 후 jump_one은 0번 칸에서만 터진다.
	var fired_at_zero := 0
	var fired_elsewhere := 0
	for s in 300:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 9000 + s)
		for entry in (cycle["steps"] as Array):
			var step: Dictionary = entry
			if (step["fired"] as Array).has("jump_one"):
				if int(step["slot"]) == 0:
					fired_at_zero += 1
				else:
					fired_elsewhere += 1
	_verdict("slot_ownership", fired_at_zero > 0 and fired_elsewhere == 0,
		"jump_one 발동 위치 slot0=%d 그외=%d" % [fired_at_zero, fired_elsewhere])
	_metrics["swap_fire_at_slot0"] = fired_at_zero

	# ② 카드만 이동 — 각인은 제자리에 남는다.
	var before_runes: int = (deck[0]["runes"] as Array).size()
	var card_a := String(deck[0]["card"]["id"])
	var card_b := String(deck[2]["card"]["id"])
	Rune.move_card(deck, 0, 2)
	var ok_card := String(deck[0]["card"]["id"]) == card_b \
		and String(deck[2]["card"]["id"]) == card_a \
		and (deck[0]["runes"] as Array).size() == before_runes
	_verdict("slot_ownership", ok_card, "move_card가 각인까지 옮겼다")
	# 경계: 같은 인덱스·범위 밖은 false를 내고 아무것도 바꾸지 않는다.
	_verdict("slot_ownership", not Rune.swap_slots(deck, 1, 1) and not Rune.swap_slots(deck, -1, 2) \
		and not Rune.move_card(deck, 0, 99), "경계 인덱스가 true를 냈다")

func _check_determinism() -> void:
	# ① 칸 각인만 있는 덱.
	var deck := _random_deck(918273)
	var base: Dictionary = Rune.simulate_cycle(deck, 555)
	var signature: String = Rune.trace_signature(base)
	var same := true
	for _i in DETERMINISM_RUNS:
		if Rune.trace_signature(Rune.simulate_cycle(deck, 555)) != signature:
			same = false
	_verdict("determinism", same, "같은 시드가 다른 궤적을 냈다(칸 각인)")

	# ② 레일 각인이 붙은 덱 — rail_loop 굴림이 시드에 묶여야 한다.
	#    rail_loop가 사이클 도중에 다시 굴려지면 여기서 잡힌다.
	var rail_deck := _plain_deck(5)
	for i in 5:
		Rune.attach_rune(rail_deck[i], _inst("twice", 1.0))
	var rail_opts: Dictionary = {
		"rail_runes": [_inst("rail_loop", 1.0), _inst("rail_power"), _inst("rail_fast")]
	}
	var rail_base: Dictionary = Rune.simulate_cycle(rail_deck, 777, rail_opts)
	var rail_sig: String = Rune.trace_signature(rail_base)
	var rail_armed := bool(rail_base["rail_loop_armed"])
	var rail_same := true
	for _i in DETERMINISM_RUNS:
		var again: Dictionary = Rune.simulate_cycle(rail_deck, 777, rail_opts)
		if Rune.trace_signature(again) != rail_sig or bool(again["rail_loop_armed"]) != rail_armed:
			rail_same = false
	_verdict("determinism", rail_same, "같은 시드가 다른 궤적/되돌이 판정을 냈다(레일 각인)")

	# ③ 시드가 실제로 작동한다(전부 같은 궤적이면 위 두 검사가 무의미하다).
	var distinct: Dictionary = {}
	for i in 200:
		distinct[Rune.trace_signature(Rune.simulate_cycle(deck, 900 + i))] = true
	_verdict("determinism", distinct.size() > 5, "시드가 궤적을 바꾸지 않는다(%d종)" % distinct.size())
	# ④ 되돌이 자체도 시드에 따라 갈린다(P_CAP 클램프 때문에 p=1.0도 확정이 아니다).
	var armed := 0
	for i in 400:
		if bool((Rune.simulate_cycle(rail_deck, 4000 + i, rail_opts) as Dictionary)["rail_loop_armed"]):
			armed += 1
	_verdict("determinism", armed > 0 and armed < 400, "rail_loop 굴림이 시드와 무관하다(%d/400)" % armed)
	_metrics["distinct_traces_200"] = distinct.size()
	_metrics["rail_loop_armed_400"] = armed

func _check_purity() -> void:
	# ① 노드를 만들지 않는다. SceneTree 루트의 자식 수가 변하지 않아야 한다.
	var children_before: int = get_root().get_child_count()
	var deck := _random_deck(1357)
	var opts: Dictionary = {"rail_runes": [_inst("rail_loop", 1.0), _inst("rail_rest")]}
	var run_a: Dictionary = Rune.simulate_cycle(deck, 4242, opts)
	var children_after: int = get_root().get_child_count()
	_verdict("purity", children_before == children_after,
		"엔진이 노드를 만들었다 (%d → %d)" % [children_before, children_after])

	# ② 전역 RNG 상태에 의존하지 않는다. randomize() 뒤에도 같은 시드는 같은 궤적이다.
	randomize()
	var run_b: Dictionary = Rune.simulate_cycle(deck, 4242, opts)
	seed(999999)
	var run_c: Dictionary = Rune.simulate_cycle(deck, 4242, opts)
	_verdict("purity", Rune.trace_signature(run_a) == Rune.trace_signature(run_b) \
		and Rune.trace_signature(run_a) == Rune.trace_signature(run_c),
		"엔진이 전역 RNG(randf/randomize)를 읽는다")

	# ③ 입력 덱을 바꾸지 않는다(편집 미리보기가 같은 덱을 반복 호출한다).
	var probe := _plain_deck(4)
	Rune.attach_rune(probe[1], _inst("twice", 1.0))
	Rune.attach_rune(probe[2], _inst("strong"))
	var before := JSON.stringify(probe)
	for s in 50:
		Rune.simulate_cycle(probe, 700 + s, opts)
	_verdict("purity", JSON.stringify(probe) == before, "simulate_cycle이 입력 덱을 변형했다")

# =============================================================================
# D. 칸 각인 개별 의미 검증 (§2.1)
# =============================================================================
func _check_slot_runes() -> void:
	_check_twice()
	_check_back_one()
	_check_jump_one()
	_check_trade_skip()
	_check_first_hit()
	_check_finisher()
	_check_quick()
	_check_twin_cast()
	_check_strong_wide()

## twice: 터진 스텝 다음은 **같은 칸**. 상한(2회)에 걸리면 반복하지 않는다.
## 확정으로 만들 수 없다 — effective_probability가 P_CAP(0.75)로 클램프하므로
## p=1.0을 줘도 4번 중 1번은 안 터진다. 그래서 "터진 경우"만 골라 본다.
func _check_twice() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[2], _inst("twice", 1.0))
	var repeated := 0
	var capped := 0
	var ok := true
	for s in 600:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 12000 + s)
		var steps: Array = cycle["steps"]
		for i in steps.size():
			var step: Dictionary = steps[i]
			if int(step["slot"]) != 2 or not (step["fired"] as Array).has("twice"):
				continue
			var last := (i == steps.size() - 1)
			if int(step["reentry"]) == 0:
				# 이 칸은 아직 1회만 밟았다 → 반드시 같은 칸을 한 번 더 밟는다.
				if last or int((steps[i + 1] as Dictionary)["slot"]) != 2:
					ok = false
				else:
					repeated += 1
					if int((steps[i + 1] as Dictionary)["reentry"]) != 1:
						ok = false
			else:
				# 이미 2회째다 → 상한. 앙코르는 조용히 버려지고 다음 칸으로 간다.
				if not last and int((steps[i + 1] as Dictionary)["slot"]) == 2:
					ok = false
				else:
					capped += 1
	_verdict("twice_repeat", ok, "twice 반복/상한 궤적 위반")
	_verdict("twice_repeat", repeated > 0 and capped > 0,
		"표본 부족 (반복 %d회 · 상한 %d회)" % [repeated, capped])
	_metrics["twice_repeat_hits"] = repeated
	_metrics["twice_capped_hits"] = capped

## back_one: 터지면 다음 스텝이 cursor − 1.
## 2번 칸에만 달아 첫 도착(step index 2, 이때 executed = [1,1,1,0,0])을 본다 —
## 1번 칸이 아직 상한이 아니므로 건너뛰기 스캔이 개입하지 않는 순수한 상황이다.
func _check_back_one() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[2], _inst("back_one", 1.0))
	var hits := 0
	var ok := true
	for s in 600:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 13000 + s)
		var steps: Array = cycle["steps"]
		if steps.size() < 3:
			continue
		var step: Dictionary = steps[2]
		if int(step["slot"]) != 2:
			ok = false
			continue
		if not (step["fired"] as Array).has("back_one"):
			continue
		if int(step["delta"]) != int(Rune.FLOW_DELTA["back_one"]):
			ok = false
		if steps.size() < 4 or int((steps[3] as Dictionary)["slot"]) != 1:
			ok = false
		else:
			hits += 1
	_verdict("back_one_delta", ok, "back_one 다음 스텝이 바로 앞 칸이 아니다")
	_verdict("back_one_delta", hits > 0, "back_one이 한 번도 터지지 않았다")
	_metrics["back_one_hits"] = hits

## jump_one: 터지면 다음 칸을 건너뛴 그다음 칸(cursor + 2).
func _check_jump_one() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[1], _inst("jump_one", 1.0))
	var hits := 0
	var ok := true
	for s in 600:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 14000 + s)
		var steps: Array = cycle["steps"]
		if steps.size() < 2:
			continue
		var step: Dictionary = steps[1]
		if int(step["slot"]) != 1:
			ok = false
			continue
		if not (step["fired"] as Array).has("jump_one"):
			# 안 터졌으면 평범하게 2번 칸으로 간다(음성 대조).
			if steps.size() < 3 or int((steps[2] as Dictionary)["slot"]) != 2:
				ok = false
			continue
		if int(step["delta"]) != int(Rune.FLOW_DELTA["jump_one"]):
			ok = false
		if steps.size() < 3 or int((steps[2] as Dictionary)["slot"]) != 3:
			ok = false
		else:
			hits += 1
	_verdict("jump_one_delta", ok, "jump_one 다음 스텝이 cursor+2가 아니다")
	_verdict("jump_one_delta", hits > 0, "jump_one이 한 번도 터지지 않았다")
	_metrics["jump_one_hits"] = hits

## trade_skip: 확정 각인이라 시드와 무관하게 궤적이 하나다.
## 5칸 0번 → visited [0,0,2,3,4] · slot_exec [2,0,1,1,1]
## (앙코르 1회 + 다음 칸 **한 칸만** 건너뜀).
func _check_trade_skip() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[0], _inst("trade_skip"))
	var expect_visited: Array[int] = [0, 0, 2, 3, 4]
	var expect_exec: Array[int] = [2, 0, 1, 1, 1]
	var ok := true
	for s in 200:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 15000 + s)
		if _ints(cycle["visited"]) != expect_visited or _ints(cycle["slot_exec"]) != expect_exec:
			ok = false
			_failures.append("trade_skip_shape: seed %d visited=%s slot_exec=%s" % [
				15000 + s, cycle["visited"], cycle["slot_exec"]])
			break
		if int(cycle["step_count"]) != 5:
			ok = false
			break
	_verdict("trade_skip_shape", ok, "trade_skip 궤적 불일치")
	# 확정 각인이므로 굴림 목록에 남지 않는다.
	var probe: Dictionary = Rune.simulate_cycle(deck, 15000)
	_verdict("trade_skip_shape", not (probe["fired"] as Array).has("trade_skip"),
		"확정 각인 trade_skip이 fired에 남았다")

## first_hit: reentry == 0에서만 적용되고 확정(굴림 없음)이다.
## trade_skip을 함께 달아 0번 칸을 **결정적으로** 두 번 밟게 만든 뒤
## 1회째와 2회째의 damage_mul을 직접 비교한다.
func _check_first_hit() -> void:
	_verdict("first_hit_cond", Rune.condition_ok("first", {"reentry": 0}), "reentry 0에서 first가 거짓")
	_verdict("first_hit_cond", not Rune.condition_ok("first", {"reentry": 1}), "reentry 1에서 first가 참")
	_verdict("first_hit_cond", not Rune.condition_ok("first", {"reentry": 2}), "reentry 2에서 first가 참")

	var deck := _plain_deck(5)
	var mag := float((Rune.RUNES["first_hit"] as Dictionary)["mag_max"])
	Rune.attach_rune(deck[0], _inst("first_hit", 1.0, mag))
	Rune.attach_rune(deck[0], _inst("trade_skip"))
	var ok := true
	for s in 100:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 16000 + s)
		var steps: Array = cycle["steps"]
		if steps.size() < 2:
			ok = false
			break
		var first: Dictionary = steps[0]
		var second: Dictionary = steps[1]
		if int(first["slot"]) != 0 or int(second["slot"]) != 0:
			ok = false
			break
		if not _near(float(first["damage_mul"]), 1.0 + mag, 1e-9):
			ok = false
			_failures.append("first_hit_cond: 1회째 damage_mul %.6f (기대 %.6f)" % [
				float(first["damage_mul"]), 1.0 + mag])
			break
		if not _near(float(second["damage_mul"]), 1.0, 1e-9):
			ok = false
			_failures.append("first_hit_cond: 2회째 damage_mul %.6f (기대 1.0)" % float(second["damage_mul"]))
			break
		if (cycle["fired"] as Array).has("first_hit"):
			ok = false
			_failures.append("first_hit_cond: 확정 각인이 fired에 남았다")
			break
	_verdict("first_hit_cond", ok, "first_hit 조건/확정성 위반")
	_metrics["first_hit_mag"] = mag

## finisher: kills 배열로 처치를 강제하면 앙코르가 걸리고, 처치가 없으면 안 걸린다.
func _check_finisher() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[0], _inst("finisher"))

	var killed: Dictionary = Rune.simulate_cycle(deck, 17000, {"kills": [true]})
	_verdict("finisher_kill", _ints(killed["visited"]) == [0, 0, 1, 2, 3, 4],
		"처치 시 궤적 %s (기대 [0,0,1,2,3,4])" % [killed["visited"]])
	_verdict("finisher_kill", _ints(killed["slot_exec"]) == [2, 1, 1, 1, 1],
		"처치 시 slot_exec %s" % [killed["slot_exec"]])
	_verdict("finisher_kill", int(killed["step_count"]) == 6,
		"처치 시 스텝 %d (기대 6)" % int(killed["step_count"]))

	var alive: Dictionary = Rune.simulate_cycle(deck, 17000, {"kills": [false]})
	_verdict("finisher_kill", _ints(alive["visited"]) == [0, 1, 2, 3, 4],
		"미처치 시 궤적 %s (기대 [0,1,2,3,4])" % [alive["visited"]])
	_verdict("finisher_kill", int(alive["step_count"]) == 5,
		"미처치 시 스텝 %d (기대 5)" % int(alive["step_count"]))

	# 조건 판정 자체도 직접 본다.
	_verdict("finisher_kill", Rune.condition_ok("kill", {"killed": true}) \
		and not Rune.condition_ok("kill", {"killed": false}), "kill 조건 판정 오류")
	# kill_chance 1.0이면 5칸 전부 앙코르가 걸려도 상한 안에서 끝난다.
	var all_kill := _plain_deck(5)
	for i in 5:
		Rune.attach_rune(all_kill[i], _inst("finisher"))
	var full: Dictionary = Rune.simulate_cycle(all_kill, 17100, {"kill_chance": 1.0})
	_verdict("finisher_kill", int(full["step_count"]) == 10 and _ints(full["slot_exec"]) == [2, 2, 2, 2, 2],
		"전 칸 마무리에서 스텝 %d slot_exec %s" % [int(full["step_count"]), full["slot_exec"]])

## quick: 터진 칸의 reload가 빚에 더해지지 않는다.
func _check_quick() -> void:
	var deck := _plain_deck(5)
	Rune.attach_rune(deck[0], _inst("quick", 1.0))
	var full_debt := 0.0
	for i in 5:
		full_debt += float((deck[i] as Dictionary)["card"]["reload"])
	var slot0_reload := float((deck[0] as Dictionary)["card"]["reload"])
	var free_hits := 0
	var paid_hits := 0
	var ok := true
	for s in 400:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 18000 + s)
		if int(cycle["step_count"]) != 5:
			ok = false
			break
		var debt := float(cycle["reload_debt"])
		if ((cycle["steps"] as Array)[0] as Dictionary)["fired"].has("quick"):
			free_hits += 1
			if not _near(debt, full_debt - slot0_reload, 1e-9):
				ok = false
				_failures.append("quick_free_reload: 발동 시 빚 %.6f (기대 %.6f)" % [debt, full_debt - slot0_reload])
				break
		else:
			paid_hits += 1
			if not _near(debt, full_debt, 1e-9):
				ok = false
				_failures.append("quick_free_reload: 미발동 시 빚 %.6f (기대 %.6f)" % [debt, full_debt])
				break
	_verdict("quick_free_reload", ok, "quick 빚 면제 계산 오류")
	_verdict("quick_free_reload", free_hits > 0 and paid_hits > 0,
		"표본 부족 (면제 %d · 청구 %d)" % [free_hits, paid_hits])
	_metrics["quick_free_hits"] = free_hits

## twin_cast: 첫 칸(prev_index < 0)에서는 조건 불충족으로 굴리지 않는다.
## 두 번째 칸부터 fired에 남고, 그 스텝 피해가 **앞 칸 카드 × 0.5**만큼 늘어난다.
func _check_twin_cast() -> void:
	_verdict("twin_cast_prev", not Rune.condition_ok("prev_slot", {"prev_index": -1}), "prev_index -1에서 참")
	_verdict("twin_cast_prev", Rune.condition_ok("prev_slot", {"prev_index": 0}), "prev_index 0에서 거짓")

	var deck := _plain_deck(5)
	Rune.attach_rune(deck[0], _inst("twin_cast", 1.0))
	Rune.attach_rune(deck[1], _inst("twin_cast", 1.0))
	var dmg0 := float((deck[0] as Dictionary)["card"]["damage"])
	var dmg1 := float((deck[1] as Dictionary)["card"]["damage"])
	var twin_hits := 0
	var plain_hits := 0
	var ok := true
	for s in 400:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 19000 + s)
		var steps: Array = cycle["steps"]
		if steps.size() != 5:
			ok = false
			break
		# 첫 칸: prev_index < 0 이므로 절대 굴리지 않는다.
		if ((steps[0] as Dictionary)["fired"] as Array).has("twin_cast"):
			ok = false
			_failures.append("twin_cast_prev: 첫 칸에서 twin_cast가 굴려졌다")
			break
		if not _near(float((steps[0] as Dictionary)["damage"]), dmg0, 1e-9):
			ok = false
			break
		var second: Dictionary = steps[1]
		if (second["fired"] as Array).has("twin_cast"):
			twin_hits += 1
			if not _near(float(second["damage"]), dmg1 + dmg0 * Rune.TWIN_POWER, 1e-9):
				ok = false
				_failures.append("twin_cast_prev: 피해 %.6f (기대 %.6f)" % [
					float(second["damage"]), dmg1 + dmg0 * Rune.TWIN_POWER])
				break
		else:
			plain_hits += 1
			if not _near(float(second["damage"]), dmg1, 1e-9):
				ok = false
				break
	_verdict("twin_cast_prev", ok, "twin_cast 조건/피해 계산 오류")
	_verdict("twin_cast_prev", twin_hits > 0 and plain_hits > 0,
		"표본 부족 (발동 %d · 미발동 %d)" % [twin_hits, plain_hits])
	_verdict("twin_cast_prev", _near(Rune.TWIN_POWER, 0.5), "TWIN_POWER=%f" % Rune.TWIN_POWER)
	_metrics["twin_cast_hits"] = twin_hits

## strong / wide: 확정이라 fired에 남지 않고(굴림 각인만 남는다) 항상 반영된다.
func _check_strong_wide() -> void:
	var deck := _plain_deck(5)
	var strong_mag := float((Rune.RUNES["strong"] as Dictionary)["mag_max"])
	var wide_mag := float((Rune.RUNES["wide"] as Dictionary)["mag_max"])
	Rune.attach_rune(deck[0], _inst("strong", 1.0, strong_mag))
	Rune.attach_rune(deck[0], _inst("wide", 1.0, wide_mag))
	Rune.attach_rune(deck[0], _inst("twice", 1.0))   # 굴림 각인은 fired에 남는다는 대조군
	var base_damage := float((deck[0] as Dictionary)["card"]["damage"])
	var ok := true
	var roll_seen := 0
	for s in 300:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 20000 + s)
		for entry in (cycle["steps"] as Array):
			var step: Dictionary = entry
			if int(step["slot"]) != 0:
				continue
			var fired: Array = step["fired"]
			if fired.has("strong") or fired.has("wide"):
				ok = false
				_failures.append("strong_wide_passive: 확정 각인이 fired에 남았다: %s" % [fired])
				break
			if fired.has("twice"):
				roll_seen += 1
			# 확정 각인은 굴림 결과와 무관하게 **항상** 적용된다.
			if not _near(float(step["damage_mul"]), 1.0 + strong_mag, 1e-9):
				ok = false
				_failures.append("strong_wide_passive: damage_mul %.6f (기대 %.6f)" % [
					float(step["damage_mul"]), 1.0 + strong_mag])
				break
			if not _near(float(step["damage"]), base_damage * (1.0 + strong_mag), 1e-9):
				ok = false
				break
			if not _near(float(step["range_bonus"]), wide_mag, 1e-9):
				ok = false
				_failures.append("strong_wide_passive: range_bonus %.6f (기대 %.6f)" % [
					float(step["range_bonus"]), wide_mag])
				break
		if not ok:
			break
	_verdict("strong_wide_passive", ok, "strong/wide 확정 적용 오류")
	_verdict("strong_wide_passive", roll_seen > 0, "대조군 굴림 각인(twice)이 한 번도 안 터졌다")
	# 중복 크기 감쇠도 확정 각인에 그대로 걸린다(passive_magnitude 경로).
	var stack_slot: Dictionary = Rune.make_slot(CARDS[0], [])
	for _i in 3:
		Rune.attach_rune(stack_slot, _inst("strong", 1.0, 0.4))
	_verdict("strong_wide_passive",
		_near(Rune.passive_magnitude(stack_slot, "strong"),
			0.4 * (1.0 + Rune.DUP_MAG_FALLOFF + pow(Rune.DUP_MAG_FALLOFF, 2))),
		"passive_magnitude가 중복 감쇠를 안 탄다")
	_verdict("strong_wide_passive", _near(Rune.passive_magnitude(stack_slot, "wide"), 0.0),
		"없는 각인의 passive_magnitude가 0이 아니다")

# =============================================================================
# E. 레일 각인 검증 (§2.2 · §2.4)
# =============================================================================
## attach_rune()이 scope == "rail" 각인을 거부한다(칸에 못 붙는다).
func _check_rail_scope() -> void:
	for id in RAIL_IDS:
		var slot: Dictionary = Rune.make_slot(CARDS[0], [])
		_verdict("rail_scope_guard", not Rune.attach_rune(slot, _inst(id)),
			"레일 각인 %s가 칸에 붙었다" % id)
		_verdict("rail_scope_guard", (slot["runes"] as Array).is_empty(),
			"거부된 레일 각인 %s가 스택에 남았다" % id)
		_verdict("rail_scope_guard", Rune.rune_scope(id) == "rail", "%s의 scope가 rail이 아니다" % id)
	for id in SLOT_IDS:
		var slot2: Dictionary = Rune.make_slot(CARDS[0], [])
		_verdict("rail_scope_guard", Rune.attach_rune(slot2, _inst(id)), "칸 각인 %s가 거부됐다" % id)
		_verdict("rail_scope_guard", Rune.rune_scope(id) == "slot", "%s의 scope가 slot이 아니다" % id)
	_verdict("rail_scope_guard", Rune.rune_scope("does_not_exist") == "", "없는 id의 scope가 비지 않았다")
	# 방어: 레일 각인이 칸 스택에 억지로 섞여 들어와도 resolve가 무시한다.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var ctx: Dictionary = {
		"reentry": 0, "element": "", "prev_element": "", "prev_index": -1,
		"killed": false, "slot_index": 0
	}
	var r: Dictionary = Rune.resolve([_inst("rail_loop", 1.0), _inst("rail_power")], ctx, rng)
	_verdict("rail_scope_guard", (r["fired"] as Array).is_empty() and int(r["repeat"]) == 0 \
		and _near(float(r["damage_bonus"]), 0.0),
		"칸 스택에 섞인 레일 각인이 효과를 냈다: %s" % [r["fired"]])

## rail_fast ×0.85 · rail_power +12% · rail_rest ×0.80 · rail_color는 공명 칸에만 +25%.
func _check_rail_numbers() -> void:
	_verdict("rail_numbers", _near(Rune.RAIL_FAST_DURATION, 0.15), "RAIL_FAST_DURATION=%f" % Rune.RAIL_FAST_DURATION)
	_verdict("rail_numbers", _near(Rune.RAIL_POWER_DAMAGE, 0.12), "RAIL_POWER_DAMAGE=%f" % Rune.RAIL_POWER_DAMAGE)
	_verdict("rail_numbers", _near(Rune.RAIL_REST_RELOAD, 0.20), "RAIL_REST_RELOAD=%f" % Rune.RAIL_REST_RELOAD)
	_verdict("rail_numbers", _near(Rune.RAIL_COLOR_DAMAGE, 0.25), "RAIL_COLOR_DAMAGE=%f" % Rune.RAIL_COLOR_DAMAGE)

	var deck := _plain_deck(5)
	var base: Dictionary = Rune.simulate_cycle(deck, 21000)
	_verdict("rail_numbers", int(base["step_count"]) == 5, "기준 덱이 5스텝이 아니다")

	# ① rail_fast — 모든 칸 duration ×0.85
	var fast: Dictionary = Rune.simulate_cycle(deck, 21000, {"rail_runes": [_inst("rail_fast")]})
	var fast_ok := true
	for i in (fast["steps"] as Array).size():
		var got := float(((fast["steps"] as Array)[i] as Dictionary)["duration"])
		var want := float(((base["steps"] as Array)[i] as Dictionary)["duration"]) * (1.0 - Rune.RAIL_FAST_DURATION)
		if not _near(got, want, 1e-9):
			fast_ok = false
			_failures.append("rail_numbers: rail_fast duration %.6f (기대 %.6f)" % [got, want])
			break
	_verdict("rail_numbers", fast_ok, "rail_fast duration 배율 오류")
	# 피해·빚은 건드리지 않는다.
	_verdict("rail_numbers", _near(float(fast["damage_total"]), float(base["damage_total"]), 1e-9) \
		and _near(float(fast["reload"]), float(base["reload"]), 1e-9), "rail_fast가 피해/빚을 바꿨다")

	# ② rail_power — 모든 칸 피해 +12%
	var power: Dictionary = Rune.simulate_cycle(deck, 21000, {"rail_runes": [_inst("rail_power")]})
	var power_ok := true
	for i in (power["steps"] as Array).size():
		var step: Dictionary = (power["steps"] as Array)[i]
		if not _near(float(step["damage_mul"]), 1.0 + Rune.RAIL_POWER_DAMAGE, 1e-9):
			power_ok = false
			_failures.append("rail_numbers: rail_power damage_mul %.6f" % float(step["damage_mul"]))
			break
	_verdict("rail_numbers", power_ok, "rail_power 피해 배율 오류")
	_verdict("rail_numbers", _near(float(power["damage_total"]),
		float(base["damage_total"]) * (1.0 + Rune.RAIL_POWER_DAMAGE), 1e-9),
		"rail_power 총피해 %.6f" % float(power["damage_total"]))

	# ③ rail_rest — 사이클 RELOAD ×0.80 (빚 자체는 그대로다)
	var rest: Dictionary = Rune.simulate_cycle(deck, 21000, {"rail_runes": [_inst("rail_rest")]})
	_verdict("rail_numbers", _near(float(rest["reload_debt"]), float(base["reload_debt"]), 1e-9),
		"rail_rest가 빚 원장을 바꿨다")
	_verdict("rail_numbers", _near(float(rest["reload"]),
		float(base["reload"]) * (1.0 - Rune.RAIL_REST_RELOAD), 1e-9),
		"rail_rest RELOAD %.6f (기대 %.6f)" % [
			float(rest["reload"]), float(base["reload"]) * (1.0 - Rune.RAIL_REST_RELOAD)])

	# ④ rail_color — **공명이 성립한 칸에만** +25% 가산
	#    0·1번 칸만 같은 원소(fire)라 공명이 서고, 2~4번 칸은 서지 않는다.
	#    (fire>thunder = overcharge는 potency만 건드리고 피해에 손대지 않으므로 안전하다.)
	var color_deck: Array = []
	var color_elements := ["fire", "fire", "thunder", "poison", "strike"]
	for i in 5:
		var card: Dictionary = CARDS[i].duplicate(true)
		card["element"] = color_elements[i]
		color_deck.append(Rune.make_slot(card, []))
	var no_color: Dictionary = Rune.simulate_cycle(color_deck, 21500)
	var with_color: Dictionary = Rune.simulate_cycle(color_deck, 21500, {"rail_runes": [_inst("rail_color")]})
	var color_ok := true
	for i in 5:
		var plain_step: Dictionary = (no_color["steps"] as Array)[i]
		var color_step: Dictionary = (with_color["steps"] as Array)[i]
		var resonant := i <= 1
		var want_plain := (1.0 + Rune.RESONANCE_DAMAGE) if resonant else 1.0
		var want_color := (1.0 + Rune.RESONANCE_DAMAGE + Rune.RAIL_COLOR_DAMAGE) if resonant else 1.0
		if not _near(float(plain_step["damage_mul"]), want_plain, 1e-9):
			color_ok = false
			_failures.append("rail_numbers: 공명 기준 칸%d damage_mul %.6f (기대 %.6f)" % [
				i, float(plain_step["damage_mul"]), want_plain])
			break
		if not _near(float(color_step["damage_mul"]), want_color, 1e-9):
			color_ok = false
			_failures.append("rail_numbers: rail_color 칸%d damage_mul %.6f (기대 %.6f)" % [
				i, float(color_step["damage_mul"]), want_color])
			break
	_verdict("rail_numbers", color_ok, "rail_color 가산 대상이 틀렸다")

	# ⑤ 넷을 동시에 걸 수는 없다(RAIL_RUNE_CAP 3). 앞 3개만 선다 — rail_caps가 잰다.
	_metrics["rail_base_reload"] = float(base["reload"])

## RAIL_RUNE_CAP 3 · RAIL_SAME_ID_CAP 1.
## FactoryDeck을 로드하지 않고 엔진 API(resolve_rail)만으로 검증한다.
func _check_rail_caps() -> void:
	_verdict("rail_caps", Rune.RAIL_RUNE_CAP == 3, "RAIL_RUNE_CAP=%d" % Rune.RAIL_RUNE_CAP)
	_verdict("rail_caps", Rune.RAIL_SAME_ID_CAP == 1, "RAIL_SAME_ID_CAP=%d" % Rune.RAIL_SAME_ID_CAP)
	var rng := RandomNumberGenerator.new()

	# ① 총 3개 상한 — 5종을 다 주면 앞 3종만 선다.
	rng.seed = 4001
	var five: Dictionary = Rune.resolve_rail([
		_inst("rail_fast"), _inst("rail_power"), _inst("rail_rest"),
		_inst("rail_color"), _inst("rail_loop", 1.0)
	], rng)
	_verdict("rail_caps", (five["fired"] as Array).size() == Rune.RAIL_RUNE_CAP,
		"레일 각인 5종 주입 시 %d개 적용 (기대 %d)" % [(five["fired"] as Array).size(), Rune.RAIL_RUNE_CAP])
	_verdict("rail_caps", not (five["fired"] as Array).has("rail_color") and not bool(five["loop"]),
		"상한을 넘긴 레일 각인이 적용됐다: %s" % [five["fired"]])
	_verdict("rail_caps", _near(float(five["color_bonus"]), 0.0), "상한 밖 rail_color가 값을 냈다")

	# ② 같은 id 1개 상한 — 3장을 줘도 한 번만 선다.
	rng.seed = 4002
	var dup: Dictionary = Rune.resolve_rail([
		_inst("rail_power"), _inst("rail_power"), _inst("rail_power")
	], rng)
	_verdict("rail_caps", (dup["fired"] as Array).size() == 1,
		"같은 레일 각인 3장에서 %d개 적용" % (dup["fired"] as Array).size())
	_verdict("rail_caps", _near(float(dup["damage_bonus"]), Rune.RAIL_POWER_DAMAGE, 1e-9),
		"중복 rail_power 보너스 %.4f (기대 %.4f)" % [float(dup["damage_bonus"]), Rune.RAIL_POWER_DAMAGE])

	# ③ 상한이 simulate_cycle 경로에서도 지켜진다.
	var deck := _plain_deck(5)
	var capped: Dictionary = Rune.simulate_cycle(deck, 22000, {"rail_runes": [
		_inst("rail_fast"), _inst("rail_fast"), _inst("rail_power"),
		_inst("rail_rest"), _inst("rail_color")
	]})
	_verdict("rail_caps", (capped["rail_fired"] as Array).size() <= Rune.RAIL_RUNE_CAP,
		"사이클 rail_fired %s가 상한을 넘었다" % [capped["rail_fired"]])

	# ④ 칸 각인·없는 id는 레일에서 조용히 무시된다(저장 호환 경로).
	rng.seed = 4003
	var junk: Dictionary = Rune.resolve_rail([
		_inst("twice", 1.0), {"id": "does_not_exist", "p": 1.0, "mag": 1.0}, "not_a_dict"
	], rng)
	_verdict("rail_caps", (junk["fired"] as Array).is_empty() and not bool(junk["loop"]),
		"레일에 칸 각인/쓰레기가 적용됐다: %s" % [junk["fired"]])
	_verdict("rail_caps", (Rune.resolve_rail([], rng) as Dictionary)["fired"] == [],
		"빈 레일이 각인을 냈다")

# =============================================================================
# C. rail_loop 10스텝 계약 (§2.2 "이번 설계의 상징")
# =============================================================================
# 5칸 덱 + rail_loop p=1.0 · 칸 각인 0개 → 정확히 10스텝.
#
# ⚠️ 두 가지를 명시해 둔다.
#  (1) `end_reason`은 **"complete"와 "all_used" 둘 다 허용한다.** 엔진은 되돌이 바퀴를
#      끝까지 완주하면(0번 칸까지 되밟고 raw가 -1로 이탈) `complete`를 낸다. 설계(§2.2)가
#      요구한 것은 "정확히 10스텝"뿐이므로 종료 사유 문자열은 계약이 아니다.
#  (2) `rail_loop`의 굴림은 resolve_rail에서 **P_CAP(0.75)로 클램프된다.** 따라서 p=1.0
#      인스턴스도 확정이 아니다(약 4번 중 3번). 그래서 시드를 훑어 `rail_loop_armed`가
#      참인 사이클만 골라 10스텝 궤적을 단언하고, 거짓인 사이클은 대조군(5스텝)과
#      같아야 한다고 단언한다 — 양쪽 다 계약이다.
func _check_rail_loop_ten() -> void:
	var deck := _plain_deck(5)
	var opts: Dictionary = {"rail_runes": [_inst("rail_loop", 1.0)]}
	var expect_visited: Array[int] = [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]
	var expect_exec: Array[int] = [2, 2, 2, 2, 2]
	var allowed_reasons := ["complete", "all_used"]
	var looped := 0
	var not_looped := 0
	var ok := true
	for s in 400:
		var cycle: Dictionary = Rune.simulate_cycle(deck, 23000 + s, opts)
		if bool(cycle["rail_loop_armed"]):
			looped += 1
			if int(cycle["step_count"]) != 10:
				ok = false
				_failures.append("rail_loop_ten: 스텝 %d (기대 10) seed=%d" % [int(cycle["step_count"]), 23000 + s])
				break
			if _ints(cycle["visited"]) != expect_visited:
				ok = false
				_failures.append("rail_loop_ten: visited=%s (기대 %s)" % [cycle["visited"], expect_visited])
				break
			if _ints(cycle["slot_exec"]) != expect_exec:
				ok = false
				_failures.append("rail_loop_ten: slot_exec=%s (기대 %s)" % [cycle["slot_exec"], expect_exec])
				break
			if not allowed_reasons.has(String(cycle["end_reason"])):
				ok = false
				_failures.append("rail_loop_ten: end_reason=%s (complete/all_used만 허용)" % cycle["end_reason"])
				break
			if not (cycle["rail_fired"] as Array).has("rail_loop"):
				ok = false
				_failures.append("rail_loop_ten: rail_fired에 rail_loop가 없다")
				break
		else:
			not_looped += 1
			# 되돌이가 안 켜졌으면 대조군과 완전히 같아야 한다.
			if int(cycle["step_count"]) != 5 or _ints(cycle["visited"]) != [0, 1, 2, 3, 4]:
				ok = false
				_failures.append("rail_loop_ten: 미발동 사이클이 %d스텝 %s" % [
					int(cycle["step_count"]), cycle["visited"]])
				break
	_verdict("rail_loop_ten", ok, "되돌이 10스텝 궤적 위반")
	_verdict("rail_loop_ten", looped > 0 and not_looped > 0,
		"표본 부족 (되돌이 %d · 미발동 %d)" % [looped, not_looped])

	# 대조군: rail_loop 없는 같은 덱 → 5스텝 · [0,1,2,3,4] · complete
	var control: Dictionary = Rune.simulate_cycle(deck, 23000)
	_verdict("rail_loop_ten", int(control["step_count"]) == 5,
		"대조군 스텝 %d (기대 5)" % int(control["step_count"]))
	_verdict("rail_loop_ten", _ints(control["visited"]) == [0, 1, 2, 3, 4],
		"대조군 visited=%s" % [control["visited"]])
	_verdict("rail_loop_ten", String(control["end_reason"]) == "complete",
		"대조군 end_reason=%s (기대 complete)" % control["end_reason"])
	_verdict("rail_loop_ten", _ints(control["slot_exec"]) == [1, 1, 1, 1, 1],
		"대조군 slot_exec=%s" % [control["slot_exec"]])
	_verdict("rail_loop_ten", not bool(control["rail_loop_armed"]),
		"레일 각인 없이 되돌이가 켜졌다")
	_metrics["rail_loop_ten_hits"] = looped

# =============================================================================
# H. 원소 어휘 · L1 반응 — 구 테스트에서 승계 (overcharge 의미만 교체)
# =============================================================================
func _check_elements() -> void:
	var expected: Array = ["fire", "ice", "thunder", "poison", "oil", "strike", "psi"]
	_verdict("elements_7", Array(Rune.ELEMENTS) == expected,
		"ELEMENTS=%s (기대 %s)" % [Array(Rune.ELEMENTS), expected])
	_verdict("elements_7", Array(Rune.FORMS) == ["slash", "pierce", "wave", "trap", "guard"],
		"FORMS=%s" % [Array(Rune.FORMS)])
	var seen: Dictionary = {}
	var vocabulary_ok := true
	for element: String in Rune.ELEMENTS:
		if element == "" or seen.has(element):
			vocabulary_ok = false
		seen[element] = true
	_verdict("elements_7", vocabulary_ok, "ELEMENTS에 빈 값 또는 중복이 있다")
	# 앞 5개 = 상태 생산자 / 뒤 2개 = 소비자. 순서 계약이다(§3.1 근거 2).
	_verdict("elements_7", Rune.ELEMENTS[5] == "strike" and Rune.ELEMENTS[6] == "psi",
		"소비자 2종이 배열 끝에 있지 않다")
	_metrics["element_count"] = Rune.ELEMENTS.size()

func _check_reactions() -> void:
	var expected_pairs: Dictionary = {
		"ice>thunder": "shock", "fire>ice": "steam", "fire>thunder": "overcharge",
		"oil>fire": "ignite", "poison>fire": "plague_prime",
		"ice>strike": "shatter_prep", "*>psi": "resonant_drain"
	}
	_verdict("reactions_7", Rune.REACTIONS.size() == expected_pairs.size(),
		"REACTIONS가 %d쌍 (기대 %d쌍)" % [Rune.REACTIONS.size(), expected_pairs.size()])
	for key in expected_pairs.keys():
		_verdict("reactions_7", String(Rune.REACTIONS.get(key, "")) == String(expected_pairs[key]),
			"반응 키 %s 누락 또는 불일치" % key)
	_verdict("reactions_7", Rune.reaction_of("oil", "fire") == "ignite", "oil>fire 조회 실패")
	_verdict("reactions_7", Rune.reaction_of("poison", "fire") == "plague_prime", "poison>fire 조회 실패")
	_verdict("reactions_7", Rune.reaction_of("ice", "strike") == "shatter_prep", "ice>strike 조회 실패")
	_verdict("reactions_7", Rune.reaction_of("ice", "thunder") == "shock", "감전이 사라졌다")
	_verdict("reactions_7", Rune.reaction_of("fire", "thunder") == "overcharge", "과충전이 사라졌다")
	var wildcard_ok := true
	for element: String in Rune.ELEMENTS:
		if Rune.reaction_of(element, "psi") != "resonant_drain":
			wildcard_ok = false
	_verdict("reactions_7", wildcard_ok, "*>psi 와일드카드가 일부 원소에서 안 선다")
	_verdict("reactions_7", Rune.reaction_of("", "psi") == "", "빈 원소에서 공명 흡수가 섰다")
	_verdict("reactions_7", Rune.reaction_of("", "fire") == "" and Rune.reaction_of("fire", "") == "",
		"빈 태그가 반응을 만든다")
	_verdict("reactions_7", Rune.reaction_of("fire", "oil") == "", "fire>oil은 반응이 없어야 한다")
	_verdict("reactions_7", Rune.reaction_of("strike", "strike") == "", "strike>strike는 반응이 없어야 한다")
	_metrics["reaction_count"] = Rune.REACTIONS.size()

	# --- 채널 검증 -------------------------------------------------------------
	# ★ Y0에서 `overcharge`의 의미가 바뀌었다: 과열 +1이 아니라 **상태 위력 ×1.3**.
	_verdict("reaction_channels", _near(Rune.reaction_potency("overcharge"), Rune.OVERCHARGE_POTENCY_MULT),
		"과충전 potency %.3f (기대 %.3f)" % [Rune.reaction_potency("overcharge"), Rune.OVERCHARGE_POTENCY_MULT])
	_verdict("reaction_channels", _near(Rune.OVERCHARGE_POTENCY_MULT, 1.3),
		"OVERCHARGE_POTENCY_MULT=%f (기대 1.3)" % Rune.OVERCHARGE_POTENCY_MULT)
	# Y8: 구 `OVERCHARGE_HEAT_BONUS == 0` 단언이 사라졌다 — 그 상수를 지웠기 때문이다.
	# 과충전이 열 대신 **위력**을 올린다는 §1.4의 의미 교체는 바로 아래 두 줄이 문다.
	_verdict("reaction_channels", _near(Rune.reaction_potency("overcharge"), Rune.OVERCHARGE_POTENCY_MULT),
		"과충전이 위력을 안 올린다")
	_verdict("reaction_channels", _near(Rune.reaction_potency("ignite"), 1.5), "인화 위력 오류")
	_verdict("reaction_channels", _near(Rune.reaction_potency("plague_prime"), 1.3), "역병 위력 오류")
	for neutral in ["shock", "steam", "shatter_prep", "resonant_drain", ""]:
		_verdict("reaction_channels", _near(Rune.reaction_potency(neutral), 1.0),
			"%s의 potency가 1.0이 아니다" % neutral)

	# 사이클로 확인 — 각인 0개짜리 결정적 덱이라 시드와 무관하게 궤적이 하나다.
	var overcharge: Dictionary = Rune.simulate_cycle(_pair_deck("fire", "thunder"), 11)
	var oc_step: Dictionary = (overcharge["steps"] as Array)[1]
	_verdict("reaction_channels", String(oc_step["reaction"]) == "overcharge", "과충전이 서지 않았다")
	_verdict("reaction_channels", _near(float(oc_step["potency"]), Rune.OVERCHARGE_POTENCY_MULT),
		"과충전 스텝 potency %.3f" % float(oc_step["potency"]))
	# Y8: 스텝 궤적에 `heat` 키 자체가 없어야 한다(셔틀 삭제의 음성 축).
	_verdict("reaction_channels", not oc_step.has("heat"), "스텝 궤적에 아직 heat 키가 있다")

	var ignite: Dictionary = Rune.simulate_cycle(_pair_deck("oil", "fire"), 11)
	var ignite_step: Dictionary = (ignite["steps"] as Array)[1]
	_verdict("reaction_channels", String(ignite_step["reaction"]) == "ignite", "인화가 서지 않았다")
	_verdict("reaction_channels", _near(float(ignite_step["potency"]), Rune.IGNITE_POTENCY_MULT),
		"인화 potency %.3f" % float(ignite_step["potency"]))

	var plague: Dictionary = Rune.simulate_cycle(_pair_deck("poison", "fire"), 11)
	_verdict("reaction_channels", _near(float(((plague["steps"] as Array)[1] as Dictionary)["potency"]),
		Rune.PLAGUE_POTENCY_MULT), "역병 발화 준비 potency 오류")

	# steam = 범위 채널 / shatter_prep = 경직 채널
	var steam: Dictionary = Rune.simulate_cycle(_pair_deck("fire", "ice"), 11)
	var steam_step: Dictionary = (steam["steps"] as Array)[1]
	_verdict("reaction_channels", String(steam_step["reaction"]) == "steam" \
		and _near(float(steam_step["range_bonus"]), Rune.STEAM_RANGE_BONUS),
		"증기 범위 %.3f (기대 %.3f)" % [float(steam_step["range_bonus"]), Rune.STEAM_RANGE_BONUS])
	var shatter: Dictionary = Rune.simulate_cycle(_pair_deck("ice", "strike"), 11)
	var shatter_step: Dictionary = (shatter["steps"] as Array)[1]
	_verdict("reaction_channels", _near(float(shatter_step["stun_bonus"]), Rune.SHATTER_PREP_STUN),
		"쇄빙 준비 경직 %.3f" % float(shatter_step["stun_bonus"]))
	_verdict("reaction_channels", _near(float(shatter_step["potency"]), 1.0),
		"쇄빙 준비가 potency를 건드렸다")

	# resonant_drain = 빚 감면 채널. L1은 직접 피해를 주지 않는다.
	var plain: Dictionary = Rune.simulate_cycle(_pair_deck("fire", "strike"), 11)
	var drain: Dictionary = Rune.simulate_cycle(_pair_deck("fire", "psi"), 11)
	var debt_delta := float(plain["reload_debt"]) - float(drain["reload_debt"])
	_verdict("reaction_channels", _near(debt_delta, Rune.RESONANT_DRAIN_RELOAD, 1e-5),
		"공명 흡수 빚 감면 %.4f (기대 %.4f)" % [debt_delta, Rune.RESONANT_DRAIN_RELOAD])
	_verdict("reaction_channels", _near(float(plain["damage_total"]), float(drain["damage_total"]), 1e-5),
		"공명 흡수가 피해를 바꿨다 — L1은 피해를 주지 않는다")
	var base_pair: Dictionary = Rune.simulate_cycle(_pair_deck("strike", "fire"), 11)
	_verdict("reaction_channels", _near(float(base_pair["damage_total"]), float(ignite["damage_total"]), 1e-5),
		"인화가 피해를 바꿨다")
	_verdict("reaction_channels", _near(float(base_pair["damage_total"]), float(plague["damage_total"]), 1e-5),
		"역병 발화 준비가 피해를 바꿨다")
	_verdict("reaction_channels", _near(float(base_pair["damage_total"]), float(overcharge["damage_total"]), 1e-5),
		"과충전이 피해를 바꿨다 — 위력 채널만 건드려야 한다")
	var triple: Dictionary = Rune.simulate_cycle(_triple_psi_deck(), 11)
	_verdict("reaction_channels", float(triple["reload"]) >= 0.0 and float(triple["reload_debt"]) >= 0.0,
		"공명 흡수 연쇄가 음수 RELOAD를 만들었다")
	_metrics["drain_debt_delta"] = debt_delta

## 두 칸짜리 각인 없는 덱. 카드 수치는 두 칸 모두 같은 것을 써서 원소 말고는 아무것도
## 다르지 않게 만든다(형태만 갈라 둔다).
func _pair_deck(first_element: String, second_element: String) -> Array:
	var a: Dictionary = CARDS[0].duplicate(true)
	var b: Dictionary = CARDS[0].duplicate(true)
	a["element"] = first_element
	b["element"] = second_element
	a["form"] = "slash"
	b["form"] = "pierce"
	return Rune.make_deck([Rune.make_slot(a, []), Rune.make_slot(b, [])])

## 2·3칸이 연속으로 psi인 덱. reload를 감면폭(0.15)보다 훨씬 작게 둬서
## **빚이 실제로 0 아래로 내려가려는** 상황을 만든다 — 클램프가 없으면 음수 RELOAD가 난다.
func _triple_psi_deck() -> Array:
	var slots: Array = []
	for i in 3:
		var card: Dictionary = CARDS[7].duplicate(true)
		card["reload"] = 0.02
		card["element"] = ("fire" if i == 0 else "psi")
		slots.append(Rune.make_slot(card, []))
	return Rune.make_deck(slots)

# =============================================================================
# I. 과열 셔틀 중립 검사 — **Y8(2026-08-10)에 은퇴했다**
# =============================================================================
# 이 자리에 `_check_heat_neutral()` 15줄이 있었다. 셔틀 상수·함수·결과 키를
# `rune_engine.gd`에서 **실제로 지웠으므로**(handoff-y2 §7의 삭제 목록) "중립인가"를
# 물을 대상 자체가 없어졌다. 없는 심볼을 재는 검사는 파스 에러이지 회귀 방지선이 아니다.
#
# 그 묶음이 지키던 계약 중 **살아 있는 셋**은 아래로 옮겼거나 이미 다른 데 있다.
#   ① `effective_probability`가 두 번째 인자를 무시한다 → `p_cap` 묶음(F절)
#      — 인자는 `game.gd:3045` 때문에 남아 있으므로 이 계약도 남아야 한다.
#   ② 과열이 뒷문으로 돌아오지 않는다 → `slot_exec_cap` · `step_bound` ·
#      `no_overload`(B절 종료성). 과열을 되살리려면 이 셋을 먼저 깨야 한다.
#   ③ 폐기된 각인 id 24종이 카탈로그에 없다 → `catalog_15`의 `DEPRECATED_IDS` 대조.
#
# =============================================================================
# B. 종료성 — 이번 웨이브의 핵심 계약 (§1.3)
# =============================================================================
## 모든 인구가 여기를 통과한다. 반환값은 step_count.
func _observe(cycle: Dictionary, n: int) -> int:
	_obs_cycles += 1
	var sc := int(cycle["step_count"])
	var exec: Array = cycle["slot_exec"]
	var max_exec := 0
	var exec_sum := 0
	for e in exec:
		max_exec = maxi(max_exec, int(e))
		exec_sum += int(e)
	if max_exec > Rune.SLOT_EXEC_CAP:
		_obs_exec_violation += 1
	if sc > Rune.SLOT_EXEC_CAP * n:
		_obs_step_violation += 1
	if exec.size() != n or exec_sum != sc or (cycle["visited"] as Array).size() != sc \
		or (cycle["steps"] as Array).size() != sc:
		_obs_shape_violation += 1
	if float(cycle["reload"]) < 0.0 or float(cycle["reload"]) > Rune.RELOAD_CAP + 1e-9:
		_obs_shape_violation += 1
	var reason := String(cycle["end_reason"])
	if reason == "overload":
		_obs_overload += 1
	elif reason == "guard":
		_obs_guard += 1
	if n >= 1 and n <= 5:
		_max_steps_by_n[n] = maxi(_max_steps_by_n[n], sc)
	return sc

func _run_montecarlo() -> void:
	# --- ① 무작위 인구 10,000 (칸 1~5 · 각인 0~5 · 레일 각인 0~3) ---------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250101
	var steps_sum := 0.0
	var reload_sum := 0.0
	var max_steps := 0
	for i in MC_RANDOM:
		var n: int = rng.randi_range(1, 5)
		var deck := _random_population_deck(n, rng)
		var opts: Dictionary = {"rail_runes": _random_rail(rng)}
		# 4번에 1번은 처치를 확정으로 줘서 finisher(kill 조건)를 인구에 태운다.
		if rng.randf() < 0.25:
			opts["kill_chance"] = 1.0
		var cycle: Dictionary = Rune.simulate_cycle(deck, 500000 + i, opts)
		var sc := _observe(cycle, n)
		steps_sum += float(sc)
		reload_sum += float(cycle["reload"])
		max_steps = maxi(max_steps, sc)
	_metrics["mean_steps_random"] = steps_sum / float(MC_RANDOM)
	_metrics["max_steps_random"] = max_steps
	_metrics["mean_reload_random"] = reload_sum / float(MC_RANDOM)

	# --- ② 극단 인구 4종 × 2,000 -----------------------------------------------
	# ① 흐름 확정 최대(twice·back_one·jump_one p=1.0 5칸)
	# ② trade_skip + finisher 확정 5칸(kill_chance 1.0)
	# ③ 레일 rail_loop p=1.0 + 칸 흐름 최대
	# ④ 각인 0개 순수 5칸
	var worst_steps_sum := 0.0
	var worst_max := 0
	var worst_count := 0
	var extremes: Array = [
		{"name": "flow_max", "deck": _flow_max_deck(), "opts": {}},
		{"name": "trade_kill", "deck": _trade_kill_deck(), "opts": {"kill_chance": 1.0}},
		{"name": "rail_loop_flow", "deck": _flow_max_deck(),
			"opts": {"rail_runes": [_inst("rail_loop", 1.0), _inst("rail_power"), _inst("rail_fast")]}},
		{"name": "bare", "deck": _plain_deck(5), "opts": {}}
	]
	for entry in extremes:
		var case_dict: Dictionary = entry
		var deck: Array = case_dict["deck"]
		var opts: Dictionary = case_dict["opts"]
		var case_sum := 0.0
		var case_max := 0
		for s in MC_STRESS:
			var cycle: Dictionary = Rune.simulate_cycle(deck, 700000 + s * 13, opts)
			var sc := _observe(cycle, deck.size())
			case_sum += float(sc)
			case_max = maxi(case_max, sc)
		worst_steps_sum += case_sum
		worst_count += MC_STRESS
		worst_max = maxi(worst_max, case_max)
		_metrics["ext_%s_steps" % String(case_dict["name"])] = case_sum / float(MC_STRESS)
		_metrics["ext_%s_max" % String(case_dict["name"])] = case_max
	_metrics["mean_steps_worst"] = worst_steps_sum / float(worst_count)
	_metrics["max_steps_worst"] = worst_max

	# --- ③ 퇴화 입력에도 죽지 않는다 -------------------------------------------
	var empty_cycle: Dictionary = Rune.simulate_cycle([], 1)
	_verdict("step_bound", int(empty_cycle["step_count"]) == 0 and (empty_cycle["slot_exec"] as Array).is_empty(),
		"빈 덱이 스텝을 만들었다")
	var junk: Array = [Rune.make_slot(CARDS[0], [{"id": "does_not_exist", "p": 1.0, "mag": 9.0}])]
	var junk_cycle: Dictionary = Rune.simulate_cycle(junk, 1)
	_observe(junk_cycle, 1)
	_verdict("step_bound", int(junk_cycle["step_count"]) == 1, "없는 각인 id가 궤적을 바꿨다")

## n칸 · 각 칸 각인 0~5개 무작위. attach_rune이 상한을 강제하므로 원하는 만큼 시도한다.
func _random_population_deck(n: int, rng: RandomNumberGenerator) -> Array:
	var deck: Array = []
	for i in n:
		var card: Dictionary = CARDS[rng.randi_range(0, CARDS.size() - 1)]
		var slot: Dictionary = Rune.make_slot(card, [])
		var want: int = rng.randi_range(0, 5)
		for _k in want:
			var id: String = SLOT_IDS[rng.randi_range(0, SLOT_IDS.size() - 1)]
			Rune.attach_rune(slot, Rune.roll_rune(id, rng))
		deck.append(slot)
	return deck

func _random_rail(rng: RandomNumberGenerator) -> Array:
	var rails: Array = []
	var want: int = rng.randi_range(0, 3)
	for _k in want:
		var id: String = RAIL_IDS[rng.randi_range(0, RAIL_IDS.size() - 1)]
		rails.append(Rune.roll_rune(id, rng))
	return rails

## 극단 ①: 스텝을 늘리거나 흔드는 흐름 각인 3종을 5칸 전부에 최대 확률로.
func _flow_max_deck() -> Array:
	var deck := _plain_deck(5)
	for i in 5:
		Rune.attach_rune(deck[i], _inst("twice", 1.0))
		Rune.attach_rune(deck[i], _inst("back_one", 1.0))
		Rune.attach_rune(deck[i], _inst("jump_one", 1.0))
	return deck

## 극단 ②: trade_skip + finisher 확정 5칸. kill_chance 1.0과 함께 쓴다.
func _trade_kill_deck() -> Array:
	var deck := _plain_deck(5)
	for i in 5:
		Rune.attach_rune(deck[i], _inst("trade_skip"))
		Rune.attach_rune(deck[i], _inst("finisher"))
	return deck

## 칸 수 n = 1~5 각각에서 최대 스텝이 정확히 2n을 넘지 않는지.
## 흐름 각인 최대 + 되돌이 + 확정 처치까지 전부 얹은 가장 사나운 형태로 훑는다.
func _check_edge_shapes() -> void:
	var ok := true
	for n in range(1, 6):
		var deck := _plain_deck(n)
		for i in n:
			Rune.attach_rune(deck[i], _inst("twice", 1.0))
			Rune.attach_rune(deck[i], _inst("back_one", 1.0))
			Rune.attach_rune(deck[i], _inst("jump_one", 1.0))
			Rune.attach_rune(deck[i], _inst("trade_skip"))
			Rune.attach_rune(deck[i], _inst("finisher"))
		var opts: Dictionary = {
			"rail_runes": [_inst("rail_loop", 1.0), _inst("rail_fast"), _inst("rail_rest")],
			"kill_chance": 1.0
		}
		for s in MC_SHAPE:
			var cycle: Dictionary = Rune.simulate_cycle(deck, 900000 + n * 7919 + s * 31, opts)
			var sc := _observe(cycle, n)
			if sc > Rune.SLOT_EXEC_CAP * n:
				ok = false
		# 방향(-1) 시작도 같은 상한을 지킨다.
		for s in 200:
			var back: Dictionary = Rune.simulate_cycle(deck, 950000 + n * 131 + s, {"direction": -1})
			var sc2 := _observe(back, n)
			if sc2 > Rune.SLOT_EXEC_CAP * n:
				ok = false
		_metrics["max_steps_n%d" % n] = _max_steps_by_n[n]
		if _max_steps_by_n[n] > Rune.SLOT_EXEC_CAP * n:
			ok = false
			_failures.append("edge_shapes: n=%d 최대 스텝 %d > %d" % [n, _max_steps_by_n[n], 2 * n])
	_verdict("edge_shapes", ok, "칸 수별 최대 스텝이 2n을 넘었다")

## 모든 인구를 다 돌린 뒤 종료성 판정을 확정한다.
func _finish_termination_verdicts() -> void:
	_verdict("slot_exec_cap", _obs_exec_violation == 0,
		"max(slot_exec) > %d 인 사이클 %d건" % [Rune.SLOT_EXEC_CAP, _obs_exec_violation])
	_verdict("slot_exec_cap", Rune.SLOT_EXEC_CAP == 2, "SLOT_EXEC_CAP=%d (기대 2)" % Rune.SLOT_EXEC_CAP)
	_verdict("step_bound", _obs_step_violation == 0,
		"step_count > 2n 인 사이클 %d건" % _obs_step_violation)
	_verdict("step_bound", _obs_shape_violation == 0,
		"궤적 배열 길이/RELOAD 범위가 어긋난 사이클 %d건" % _obs_shape_violation)
	_verdict("step_bound", Rune.STEP_CAP == 2 * Rune.SLOT_COUNT + 2,
		"STEP_CAP=%d (기대 %d)" % [Rune.STEP_CAP, 2 * Rune.SLOT_COUNT + 2])
	_verdict("no_overload", _obs_overload == 0,
		'end_reason=="overload" %d건 — 새 회귀 계약은 0건이다' % _obs_overload)
	_verdict("no_overload", _obs_guard == 0,
		'end_reason=="guard" %d건 — 엔진 버그다' % _obs_guard)
	_metrics["overload_count"] = _obs_overload
	_metrics["guard_count"] = _obs_guard
	_metrics["exec_cap_violations"] = _obs_exec_violation
	_metrics["step_bound_violations"] = _obs_step_violation
	_metrics["cycles"] = _obs_cycles

# -----------------------------------------------------------------------------
# 덱 생성기 (결정성 검사용)
# -----------------------------------------------------------------------------
func _random_deck(deck_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = deck_seed
	var deck: Array = []
	for i in 5:
		var card: Dictionary = CARDS[rng.randi_range(0, CARDS.size() - 1)]
		var slot: Dictionary = Rune.make_slot(card, [])
		var want: int = rng.randi_range(0, 3)
		if rng.randf() < 0.15:
			want = rng.randi_range(4, Rune.RUNE_STACK_CAP)
		for _k in want:
			var id: String = SLOT_IDS[rng.randi_range(0, SLOT_IDS.size() - 1)]
			Rune.attach_rune(slot, Rune.roll_rune(id, rng))
		deck.append(slot)
	return deck

# -----------------------------------------------------------------------------
# 보고
# -----------------------------------------------------------------------------
func _report() -> void:
	var order: Array[String] = [
		# A. 카탈로그 계약
		"catalog_15", "rarity_split", "scope_split", "flow_family", "rune_schema", "roll_rune_range",
		# B. 종료성
		"slot_exec_cap", "step_bound", "no_overload", "edge_shapes",
		# C. rail_loop 10스텝
		"rail_loop_ten",
		# D. 칸 각인 개별 의미
		"twice_repeat", "back_one_delta", "jump_one_delta", "trade_skip_shape",
		"first_hit_cond", "finisher_kill", "quick_free_reload", "twin_cast_prev",
		"strong_wide_passive",
		# E. 레일 각인
		"rail_scope_guard", "rail_numbers", "rail_caps",
		# F. 칸 감쇠 4겹
		"merged_probability", "merged_magnitude", "congestion_scale", "stack_caps", "p_cap",
		# G. 결정성 · 순수성
		"determinism", "slot_ownership", "purity",
		# H. 원소 · L1 반응
		"elements_7", "reactions_7", "reaction_channels"
		# I. 구 `heat_neutral` — Y8이 셔틀을 실제로 지우면서 함께 은퇴했다(위 I절 주석).
	]
	var failed: Array[String] = []
	for name in order:
		if not bool(_checks.get(name, false)):
			failed.append(name)

	if not failed.is_empty():
		for reason in _failures:
			print("RUNE_TEST_DETAIL %s" % reason)
		print("RUNE_TEST_FAILED failed=%s" % ",".join(failed))
		quit(1)
		return

	var parts: Array[String] = []
	for name in order:
		parts.append("%s=true" % name)
	var metric_keys: Array = _metrics.keys()
	metric_keys.sort()
	for key: String in metric_keys:
		var value: Variant = _metrics[key]
		if value is int:
			parts.append("%s=%d" % [key, int(value)])
		else:
			parts.append("%s=%.4f" % [key, float(value)])
	print("RUNE_TEST_COMPLETE %s" % " ".join(parts))
	quit(0)
