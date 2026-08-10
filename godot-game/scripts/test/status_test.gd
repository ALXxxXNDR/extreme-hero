class_name StatusTest
extends RefCounted

# =============================================================================
# V1 — 상태이상 엔진 판정 스위트 (`--status-test`의 본체)
# =============================================================================
#
# ⚠️ **실행법 — 이 파일은 `-s`로 직접 돌리지 않는다.**
#     이 스크립트는 `SceneTree`가 아니라 `RefCounted`다. `-s`로 넘기면 Godot이
#     `_initialize()`를 못 찾고 **아무 출력 없이 멈춘 것처럼 보인다**(엔진이
#     계속 돌기 때문에 실패도 아니다). 정식 경로는 하나뿐이다.
#
#       godot --headless --path godot-game -- --status-test
#
#     `-s`로 직접 돌아가는 것은 `SceneTree`를 상속한 단독 프로브뿐이다
#     (`balance_probe.gd` · `rift_probe.gd` · `rune_test.gd` · `data_test.gd` ·
#      `terrain_probe.gd`). `run_all.sh`는 위 정식 경로로 이 파일을 부른다.
#
# 설계 근거: docs/GAME_DESIGN_V3.md §4.3 · §4.4 · §4.7 / 부록 B의 V1 완료 기준.
#
# 왜 test_runner.gd가 아니라 여기인가:
#   부록 B의 V1 행이 `scripts/test/status_test.gd`를 V1 소유로 명시한다. V4가
#   `test_runner.gd`의 `_run_stage_test()`를 **동시에** 편집 중이므로 공유 파일에
#   남기는 흔적을 최소화한다 — test_runner는 `StatusTest.run_all()` 한 줄만 부른다.
#
# 판정 7묶음 (하나라도 거짓이면 그 이름이 `=false`로 찍혀 run_all.sh가 FAIL 처리한다)
#   ① basics        5종 부여·중첩·지속 감쇠 정확성 · 경계(정확히 0초) · 스택 상한 6
#   ② matrix        §4.4 매트릭스 7행 × 6열 = 42칸 전 쌍. 계수는 GameTuning 대조
#   ③ blaze_ratio   oil+fire 총 도트가 맨 불의 **7.5배** · §4.3 검산치 오차 2% 이내
#   ④ conduction    chill→thunder 전이 4체 · {radius, max_targets, falloff} · 도약 감쇠
#   ⑤ psi_harvest   남은 지속 30% 소모 → 소모 초 × 0.5 × P 환산 피해
#   ⑥ budget        반응 예산 상한 준수 · 전파 깊이 1 · 예산 고갈에도 상태 수치는 불변
#   ⑦ deterministic 같은 입력 → 같은 결과 · delta 분할 불변(1.0 == 0.25×4 == 1/60×60)
#
# 출력 규약(run_all.sh): 정보성 값은 **숫자로만** 낸다. `=false` 문자열은 실패 표시
# 전용이다.

# 테스트 P. 1.0으로 두면 모든 기대값이 설계 문서의 "× P" 표기와 글자 그대로 같아진다.
const P := 1.0
const EPS := 1.0e-6

const GROUPS: Array[String] = [
	"basics", "matrix", "blaze_ratio", "conduction", "psi_harvest", "budget", "deterministic"
]

# 매트릭스 42칸의 기대 반응 시퀀스. "행|열" -> 쉼표로 이은 반응 키(순서 포함).
# 빈 문자열 = 반응 없음(타·초가 상태를 만들지 않는 칸).
const MATRIX_EXPECT: Dictionary = {
	"poison|none": "poison_apply",
	"poison|poison": "poison_stack",
	"poison|burn": "poison_apply",
	"poison|chill": "poison_apply,frozen_venom",
	"poison|oil": "poison_apply",
	"poison|shock": "poison_apply",

	"fire|none": "burn_apply",
	"fire|poison": "plague_ignition,burn_apply",
	"fire|burn": "burn_refresh",
	"fire|chill": "steam,burn_apply",
	"fire|oil": "blaze,burn_apply",
	"fire|shock": "burn_apply",

	"ice|none": "chill_apply",
	"ice|poison": "frozen_venom,chill_apply",
	"ice|burn": "quench,chill_apply",
	"ice|chill": "chill_refresh",
	"ice|oil": "chill_apply",
	"ice|shock": "chill_apply",

	"thunder|none": "shock_apply",
	"thunder|poison": "shock_apply",
	"thunder|burn": "shock_apply",
	"thunder|chill": "conduction,shock_apply",
	"thunder|oil": "oiled_shock,shock_apply",
	"thunder|shock": "shock_refresh",

	"oil|none": "oil_apply",
	"oil|poison": "oil_apply",
	"oil|burn": "greased_flame,oil_apply",
	"oil|chill": "oil_apply",
	"oil|oil": "oil_refresh",
	"oil|shock": "oil_apply",

	"strike|none": "",
	"strike|poison": "detonate",
	"strike|burn": "",
	"strike|chill": "shatter",
	"strike|oil": "",
	"strike|shock": "",

	"psi|none": "",
	"psi|poison": "psi_collapse",
	"psi|burn": "psi_collapse",
	"psi|chill": "psi_collapse",
	"psi|oil": "psi_collapse",
	"psi|shock": "psi_collapse"
}

const COLUMNS: Array[String] = ["none", "poison", "burn", "chill", "oil", "shock"]


# =============================================================================
# 진입점
# =============================================================================
static func run_all() -> Dictionary:
	var r: Dictionary = {"groups": {}, "fails": [], "metrics": {}}
	for group: String in GROUPS:
		r["groups"][group] = true
	_check_basics(r)
	_check_matrix(r)
	_check_blaze_ratio(r)
	_check_conduction(r)
	_check_psi(r)
	_check_budget(r)
	_check_determinism(r)

	var passed := true
	var summary_parts: Array[String] = []
	for group: String in GROUPS:
		var ok := bool(r["groups"][group])
		passed = passed and ok
		summary_parts.append("%s=%s" % [group, "true" if ok else "false"])
	var metrics: Dictionary = r["metrics"]
	var metric_keys: Array = metrics.keys()
	metric_keys.sort()
	for key: String in metric_keys:
		summary_parts.append("%s=%s" % [key, metrics[key]])
	return {
		"passed": passed,
		"summary": " ".join(summary_parts),
		"details": r["fails"]
	}


# =============================================================================
# 판정 도구
# =============================================================================
static func _ok(r: Dictionary, group: String, condition: bool, detail: String) -> void:
	if condition:
		return
	r["groups"][group] = false
	r["fails"].append("[%s] %s" % [group, detail])


static func _near(r: Dictionary, group: String, actual: float, expected: float, what: String,
		eps: float = EPS) -> void:
	_ok(r, group, absf(actual - expected) <= eps,
		"%s 기대 %.6f 실제 %.6f" % [what, expected, actual])


static func _within_pct(r: Dictionary, group: String, actual: float, expected: float,
		pct: float, what: String) -> void:
	var tolerance: float = absf(expected) * pct
	_ok(r, group, absf(actual - expected) <= tolerance,
		"%s 기대 %.6f ±%.1f%% 실제 %.6f" % [what, expected, pct * 100.0, actual])


static func _ctx(damage: float = P, potency: float = 1.0, depth: int = 0,
		budget: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"damage": damage, "potency": potency, "depth": depth}
	if not budget.is_empty():
		out["budget"] = budget
	return out


## "열" 상태를 반응 없이 만든다(저수준 set_status를 쓰므로 매트릭스를 타지 않는다).
static func _column(column: String) -> Array:
	var state: Array = StatusEngine.make_state()
	match column:
		"poison": StatusEngine.set_status(state, "poison", {"damage": P, "stacks": 3})
		"burn": StatusEngine.set_status(state, "burn", {"damage": P})
		"chill": StatusEngine.set_status(state, "chill", {"power": 1.0})
		"oil": StatusEngine.set_status(state, "oil", {})
		"shock": StatusEngine.set_status(state, "shock", {})
	return state


static func _joined(result: Dictionary) -> String:
	var reactions: Array = result.get("reactions", [])
	var parts: Array[String] = []
	for reaction in reactions:
		parts.append(String(reaction))
	return ",".join(parts)


static func _event_of(result: Dictionary, kind: String) -> Dictionary:
	for event: Dictionary in result.get("events", []):
		if String(event.get("kind", "")) == kind:
			return event
	return {}


static func _count_events(result: Dictionary, kind: String) -> int:
	var count := 0
	for event: Dictionary in result.get("events", []):
		if String(event.get("kind", "")) == kind:
			count += 1
	return count


## 상태가 완전히 꺼질 때까지 STATUS_TICK 단위로 돌리며 도트 총량과 틱 수를 모은다.
static func _drain(state: Array, limit_seconds: float = 30.0) -> Dictionary:
	var total := 0.0
	var ticks := 0
	var elapsed := 0.0
	while elapsed < limit_seconds and StatusEngine.has_any(state):
		var dot: float = StatusEngine.tick_dot(state, GameTuning.STATUS_TICK)
		elapsed += GameTuning.STATUS_TICK
		if dot > 0.0:
			total += dot
			ticks += 1
	return {"total": total, "ticks": ticks, "elapsed": elapsed}


# =============================================================================
# ① 5종 부여·중첩·지속 감쇠
# =============================================================================
static func _check_basics(r: Dictionary) -> void:
	var g := "basics"

	# --- 부여 직후의 지속·수치가 V3-K 그대로인가 -----------------------------
	var poison: Array = StatusEngine.make_state()
	StatusEngine.apply(poison, "poison", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(poison, "poison"), GameTuning.POISON_DURATION, "독 지속")
	_ok(r, g, StatusEngine.stacks(poison) == 1, "독 첫 부여 스택 %d (기대 1)" % StatusEngine.stacks(poison))
	_near(r, g, poison[StatusEngine.F_POISON_UNIT], GameTuning.POISON_DOT_PER_STACK * P, "독 틱 단위")

	var burn: Array = StatusEngine.make_state()
	StatusEngine.apply(burn, "fire", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(burn, "burn"), GameTuning.BURN_DURATION, "연 지속")
	_near(r, g, burn[StatusEngine.F_BURN_UNIT], GameTuning.BURN_DOT * P, "연 틱 단위")

	var chill: Array = StatusEngine.make_state()
	StatusEngine.apply(chill, "ice", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(chill, "chill"), GameTuning.CHILL_DURATION, "한 지속")
	_near(r, g, StatusEngine.move_multiplier(chill), 1.0 - GameTuning.CHILL_SLOW, "한 이동 배율")

	var oil: Array = StatusEngine.make_state()
	StatusEngine.apply(oil, "oil", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(oil, "oil"), GameTuning.OIL_DURATION, "유 지속")
	_near(r, g, StatusEngine.incoming_multiplier(oil, "fire"), GameTuning.OIL_FIRE_TAKEN_MUL, "유 화염 증폭")
	_near(r, g, StatusEngine.incoming_multiplier(oil, "ice"), 1.0, "유는 화염에만 반응")

	var shock: Array = StatusEngine.make_state()
	StatusEngine.apply(shock, "thunder", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(shock, "shock"), GameTuning.SHOCK_DURATION, "전 지속")
	_near(r, g, StatusEngine.next_hit_multiplier(shock), 1.0 + GameTuning.SHOCK_NEXT_HIT_BONUS, "전 표식 배율")
	_near(r, g, StatusEngine.consume_shock(shock), 1.0 + GameTuning.SHOCK_NEXT_HIT_BONUS, "전 표식 소모값")
	_near(r, g, StatusEngine.consume_shock(shock), 1.0, "전 표식은 1회 소모")

	# --- 유는 자체 피해가 0이다 ---------------------------------------------
	var oil_only: Array = StatusEngine.make_state()
	StatusEngine.apply(oil_only, "oil", 1.0, _ctx())
	var oil_drain := _drain(oil_only)
	_near(r, g, float(oil_drain["total"]), 0.0, "유 자체 도트")
	_ok(r, g, not StatusEngine.has_any(oil_only), "유가 8초 뒤 꺼지지 않았다")

	# --- potency 채널: P = damage × potency ---------------------------------
	var potent: Array = StatusEngine.make_state()
	StatusEngine.apply(potent, "fire", 1.0, _ctx(2.0, 1.5))
	_near(r, g, potent[StatusEngine.F_BURN_UNIT], GameTuning.BURN_DOT * 3.0, "potency 반영 연 틱")

	# --- 중첩 상한 6 ---------------------------------------------------------
	var stacked: Array = StatusEngine.make_state()
	for index in 10:
		StatusEngine.apply(stacked, "poison", 1.0, _ctx())
	_ok(r, g, StatusEngine.stacks(stacked) == GameTuning.POISON_STACK_MAX,
		"독 스택 상한 %d (기대 %d)" % [StatusEngine.stacks(stacked), GameTuning.POISON_STACK_MAX])

	# --- 지속 경계: 정확히 0초에 꺼지고, 그 직전까지는 살아 있다 --------------
	var edge_off: Array = StatusEngine.make_state()
	StatusEngine.apply(edge_off, "fire", 1.0, _ctx())
	StatusEngine.tick_dot(edge_off, GameTuning.BURN_DURATION)
	_ok(r, g, not StatusEngine.has(edge_off, "burn"), "연이 정확히 %.2f초에 꺼지지 않았다" % GameTuning.BURN_DURATION)

	var edge_on: Array = StatusEngine.make_state()
	StatusEngine.apply(edge_on, "fire", 1.0, _ctx())
	StatusEngine.tick_dot(edge_on, GameTuning.BURN_DURATION - 0.01)
	_ok(r, g, StatusEngine.has(edge_on, "burn"), "연이 지속 만료 전에 꺼졌다")

	# --- 스택 감쇠: POISON_STACK_DECAY_INTERVAL마다 −1 ------------------------
	var decaying: Array = StatusEngine.make_state()
	for index in 3:
		StatusEngine.apply(decaying, "poison", 1.0, _ctx())
	_ok(r, g, StatusEngine.stacks(decaying) == 3, "감쇠 시험 초기 스택 %d" % StatusEngine.stacks(decaying))
	StatusEngine.tick_dot(decaying, GameTuning.POISON_STACK_DECAY_INTERVAL)
	_ok(r, g, StatusEngine.stacks(decaying) == 2, "%.1f초 뒤 스택 %d (기대 2)" % [
		GameTuning.POISON_STACK_DECAY_INTERVAL, StatusEngine.stacks(decaying)])
	StatusEngine.tick_dot(decaying, GameTuning.POISON_STACK_DECAY_INTERVAL)
	_ok(r, g, StatusEngine.stacks(decaying) == 1, "2주기 뒤 스택 %d (기대 1)" % StatusEngine.stacks(decaying))
	StatusEngine.tick_dot(decaying, GameTuning.POISON_STACK_DECAY_INTERVAL)
	_ok(r, g, not StatusEngine.has(decaying, "poison"), "스택이 0이 됐는데 독이 남아 있다")

	# --- 갱신은 하향하지 않는다(약한 후속 적용이 강한 상태를 깎으면 안 된다) ---
	var strong: Array = StatusEngine.make_state()
	StatusEngine.apply(strong, "fire", 1.0, _ctx(4.0))
	var strong_unit: float = strong[StatusEngine.F_BURN_UNIT]
	StatusEngine.apply(strong, "fire", 1.0, _ctx(1.0))
	_near(r, g, strong[StatusEngine.F_BURN_UNIT], strong_unit, "약한 재적용이 연 위력을 깎았다")

	# --- HUD 핍은 STATUS_PIP_MAX개까지 -------------------------------------
	var loaded: Array = StatusEngine.make_state()
	for status: String in StatusEngine.STATUSES:
		StatusEngine.set_status(loaded, status, {"damage": P, "power": 1.0})
	_ok(r, g, StatusEngine.active_list(loaded).size() == StatusEngine.STATUSES.size(),
		"5종 동시 부여 실패: %d종" % StatusEngine.active_list(loaded).size())
	_ok(r, g, StatusEngine.pip_list(loaded).size() == GameTuning.STATUS_PIP_MAX,
		"핍 개수 %d (기대 %d)" % [StatusEngine.pip_list(loaded).size(), GameTuning.STATUS_PIP_MAX])


# =============================================================================
# ② 매트릭스 7행 × 6열 = 42칸
# =============================================================================
static func _check_matrix(r: Dictionary) -> void:
	var g := "matrix"
	var cells := 0

	for element: String in StatusEngine.ELEMENTS:
		for column: String in COLUMNS:
			var key := "%s|%s" % [element, column]
			if not MATRIX_EXPECT.has(key):
				_ok(r, g, false, "기대표에 없는 칸 %s" % key)
				continue
			cells += 1
			var state := _column(column)
			var result := StatusEngine.apply(state, element, 1.0, _ctx())
			_ok(r, g, _joined(result) == String(MATRIX_EXPECT[key]),
				"%s 반응 기대 [%s] 실제 [%s]" % [key, MATRIX_EXPECT[key], _joined(result)])

	r["metrics"]["cells"] = cells
	_ok(r, g, cells == StatusEngine.ELEMENTS.size() * COLUMNS.size(),
		"검사한 칸 %d (기대 %d)" % [cells, StatusEngine.ELEMENTS.size() * COLUMNS.size()])

	# ---- 칸별 수치 대조 (전부 GameTuning 대조. 리터럴을 쓰지 않는다) --------

	# 독↓ × 한→ : 독 지속 +50%
	var venom := _column("chill")
	StatusEngine.apply(venom, "poison", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(venom, "poison"),
		GameTuning.POISON_DURATION * (1.0 + GameTuning.SYN_POISON_ON_CHILL_DURATION_BONUS),
		"냉독(독↓×한) 지속")

	# 빙↓ × 독→ : 같은 보너스, 반대 방향
	var venom2 := _column("poison")
	StatusEngine.apply(venom2, "ice", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(venom2, "poison"),
		GameTuning.POISON_DURATION * (1.0 + GameTuning.SYN_POISON_ON_CHILL_DURATION_BONUS),
		"냉독(빙↓×독) 지속")

	# 화↓ × 독→ : 역병 발화. 스택 전소모 + 반경 90에 1.2 × P × stacks
	var plague := _column("poison")
	var plague_stacks := float(StatusEngine.stacks(plague))
	var plague_result := StatusEngine.apply(plague, "fire", 1.0, _ctx())
	var plague_event := _event_of(plague_result, StatusEngine.E_AOE_DAMAGE)
	_ok(r, g, not plague_event.is_empty(), "역병 발화 AoE 이벤트 없음")
	if not plague_event.is_empty():
		_near(r, g, float(plague_event["radius"]), GameTuning.SYN_PLAGUE_IGNITION_RADIUS, "역병 발화 반경")
		_near(r, g, float(plague_event["amount"]),
			GameTuning.SYN_PLAGUE_IGNITION_PER_STACK * P * plague_stacks, "역병 발화 피해")
	_ok(r, g, not StatusEngine.has(plague, "poison"), "역병 발화 후 독이 남아 있다")

	# 화↓ × 한→ : 증기. 한 해제 + 이번 타격 범위 +50%
	var steam := _column("chill")
	var steam_result := StatusEngine.apply(steam, "fire", 1.0, _ctx())
	_near(r, g, float(steam_result["range_bonus"]), GameTuning.SYN_STEAM_RANGE_BONUS, "증기 범위 보정")
	_ok(r, g, not StatusEngine.has(steam, "chill"), "증기 후 한이 남아 있다")

	# 화↓ × 유→ : ★대폭 연소. 연 power ×3 · 지속 ×2.5 · 기름 소모 · oil 전파 깊이 1
	var blaze := _column("oil")
	var blaze_result := StatusEngine.apply(blaze, "fire", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(blaze, "burn"),
		GameTuning.BURN_DURATION * GameTuning.SYN_BLAZE_DURATION_MUL, "대폭 연소 연 지속")
	_near(r, g, blaze[StatusEngine.F_BURN_UNIT],
		GameTuning.BURN_DOT * P * GameTuning.SYN_BLAZE_POWER_MUL, "대폭 연소 연 틱")
	_ok(r, g, not StatusEngine.has(blaze, "oil"), "대폭 연소가 기름을 소모하지 않았다")
	var spread := _event_of(blaze_result, StatusEngine.E_SPREAD_STATUS)
	_ok(r, g, not spread.is_empty(), "대폭 연소 기름 전파 이벤트 없음")
	if not spread.is_empty():
		_near(r, g, float(spread["radius"]), GameTuning.SYN_BLAZE_OIL_SPREAD_RADIUS, "기름 전파 반경")
		_ok(r, g, String(spread["status"]) == "oil", "기름 전파 상태가 oil이 아니다")
		_ok(r, g, int(spread["depth"]) == GameTuning.STATUS_PROPAGATION_DEPTH,
			"기름 전파 깊이 %d (기대 %d)" % [int(spread["depth"]), GameTuning.STATUS_PROPAGATION_DEPTH])

	# 빙↓ × 연→ : 연 해제 후 한 부여
	var quench := _column("burn")
	StatusEngine.apply(quench, "ice", 1.0, _ctx())
	_ok(r, g, not StatusEngine.has(quench, "burn"), "소화 후 연이 남아 있다")
	_ok(r, g, StatusEngine.has(quench, "chill"), "소화 후 한이 붙지 않았다")

	# 뇌↓ × 유→ : 감전 유막. 기름 소모 + 반경 160에 0.8 × P + 전 표식
	var oiled := _column("oil")
	var oiled_result := StatusEngine.apply(oiled, "thunder", 1.0, _ctx())
	var oiled_event := _event_of(oiled_result, StatusEngine.E_AOE_DAMAGE)
	_ok(r, g, not oiled_event.is_empty(), "감전 유막 AoE 이벤트 없음")
	if not oiled_event.is_empty():
		_near(r, g, float(oiled_event["radius"]), GameTuning.SYN_OILED_SHOCK_RADIUS, "감전 유막 반경")
		_near(r, g, float(oiled_event["amount"]), GameTuning.SYN_OILED_SHOCK_DAMAGE * P, "감전 유막 피해")
		_ok(r, g, String(oiled_event.get("apply_status", "")) == "shock", "감전 유막이 전 표식을 안 남긴다")
	_ok(r, g, not StatusEngine.has(oiled, "oil"), "감전 유막이 기름을 소모하지 않았다")

	# 유↓ × 연→ : 불에 기름. 연 power ×2
	var greased := _column("burn")
	var base_unit: float = greased[StatusEngine.F_BURN_UNIT]
	StatusEngine.apply(greased, "oil", 1.0, _ctx())
	_near(r, g, greased[StatusEngine.F_BURN_UNIT], base_unit * GameTuning.SYN_OIL_ON_BURN_POWER_MUL,
		"불에 기름 연 틱")

	# 타↓ × 독→ : 터뜨리기. 스택 1 소모 + 1.0 × P 즉발
	var detonate := _column("poison")
	var before_stacks := StatusEngine.stacks(detonate)
	var detonate_result := StatusEngine.apply(detonate, "strike", 1.0, _ctx())
	_ok(r, g, StatusEngine.stacks(detonate) == before_stacks - GameTuning.SYN_DETONATE_STACKS,
		"터뜨리기 스택 %d → %d (기대 −%d)" % [
			before_stacks, StatusEngine.stacks(detonate), GameTuning.SYN_DETONATE_STACKS])
	var detonate_event := _event_of(detonate_result, StatusEngine.E_DAMAGE)
	_ok(r, g, not detonate_event.is_empty(), "터뜨리기 피해 이벤트 없음")
	if not detonate_event.is_empty():
		_near(r, g, float(detonate_event["amount"]), GameTuning.SYN_DETONATE_DAMAGE * P, "터뜨리기 피해")

	# 타↓ × 한→ : 쇄빙. 한 해제 + 넉백 ×2 · 경직 0.35s
	var shatter := _column("chill")
	var shatter_result := StatusEngine.apply(shatter, "strike", 1.0, _ctx())
	var shatter_event := _event_of(shatter_result, StatusEngine.E_KNOCKBACK)
	_ok(r, g, not shatter_event.is_empty(), "쇄빙 넉백 이벤트 없음")
	if not shatter_event.is_empty():
		_near(r, g, float(shatter_event["knockback_mul"]), GameTuning.SYN_SHATTER_KNOCKBACK_MUL, "쇄빙 넉백")
		_near(r, g, float(shatter_event["stun"]), GameTuning.SYN_SHATTER_STUN, "쇄빙 경직")
	_ok(r, g, not StatusEngine.has(shatter, "chill"), "쇄빙 후 한이 남아 있다")

	# 비원소 2종은 상태를 만들지 않는다(§4.4 설계 의도 1)
	for consumer: String in ["strike", "psi"]:
		var empty_state: Array = StatusEngine.make_state()
		var consumer_result := StatusEngine.apply(empty_state, consumer, 1.0, _ctx())
		_ok(r, g, not StatusEngine.has_any(empty_state), "%s가 상태를 만들었다" % consumer)
		_ok(r, g, String(consumer_result["applied"]).is_empty(), "%s의 applied가 비어 있지 않다" % consumer)

	# 상호작용 없는 칸은 기존 상태를 **건드리지 않는다**
	var untouched := _column("shock")
	StatusEngine.apply(untouched, "fire", 1.0, _ctx())
	_near(r, g, StatusEngine.remaining(untouched, "shock"), GameTuning.SHOCK_DURATION, "화가 전 표식을 건드렸다")
	var untouched2 := _column("poison")
	StatusEngine.apply(untouched2, "thunder", 1.0, _ctx())
	_ok(r, g, StatusEngine.stacks(untouched2) == 3, "뇌가 독 스택을 건드렸다")

	# 여러 열을 동시에 밟는다: 유+독이 붙은 적에게 화 = 대폭 연소 + 역병 발화
	var combo: Array = StatusEngine.make_state()
	StatusEngine.set_status(combo, "oil", {})
	StatusEngine.set_status(combo, "poison", {"damage": P, "stacks": 4})
	var combo_result := StatusEngine.apply(combo, "fire", 1.0, _ctx())
	_ok(r, g, _joined(combo_result) == "blaze,plague_ignition,burn_apply",
		"유+독 동시 반응 [%s]" % _joined(combo_result))


# =============================================================================
# ③ 기름+불 = 맨 불의 7.5배 (§4.3 검산)
# =============================================================================
static func _check_blaze_ratio(r: Dictionary) -> void:
	var g := "blaze_ratio"

	# 맨 불: 2.0초 = 8틱 × 0.10 = 0.8 P
	var plain: Array = StatusEngine.make_state()
	StatusEngine.apply(plain, "fire", 1.0, _ctx())
	var plain_drain := _drain(plain)
	var plain_total := float(plain_drain["total"])
	var plain_ticks := int(plain_drain["ticks"])
	var plain_expected: float = (GameTuning.BURN_DURATION / GameTuning.STATUS_TICK) * GameTuning.BURN_DOT * P
	_ok(r, g, plain_ticks == int(round(GameTuning.BURN_DURATION / GameTuning.STATUS_TICK)),
		"맨 불 틱 수 %d (기대 %d)" % [plain_ticks, int(round(GameTuning.BURN_DURATION / GameTuning.STATUS_TICK))])
	_within_pct(r, g, plain_total, plain_expected, 0.02, "맨 불 총 도트")

	# 기름 위의 불: 5.0초 = 20틱 × 0.30 = 6.0 P
	var blazed := _column("oil")
	StatusEngine.apply(blazed, "fire", 1.0, _ctx())
	var blazed_drain := _drain(blazed)
	var blazed_total := float(blazed_drain["total"])
	var blazed_ticks := int(blazed_drain["ticks"])
	var blazed_expected: float = (GameTuning.BURN_DURATION * GameTuning.SYN_BLAZE_DURATION_MUL
		/ GameTuning.STATUS_TICK) * GameTuning.BURN_DOT * GameTuning.SYN_BLAZE_POWER_MUL * P
	_ok(r, g, blazed_ticks == int(round(GameTuning.BURN_DURATION * GameTuning.SYN_BLAZE_DURATION_MUL
		/ GameTuning.STATUS_TICK)), "대폭 연소 틱 수 %d" % blazed_ticks)
	_within_pct(r, g, blazed_total, blazed_expected, 0.02, "대폭 연소 총 도트")

	# ★ 비율 = SYN_BLAZE_POWER_MUL × SYN_BLAZE_DURATION_MUL = 3 × 2.5 = 7.5
	var ratio: float = blazed_total / maxf(plain_total, EPS)
	var ratio_expected: float = GameTuning.SYN_BLAZE_POWER_MUL * GameTuning.SYN_BLAZE_DURATION_MUL
	_within_pct(r, g, ratio, ratio_expected, 0.02, "기름+불 / 맨 불 배수")
	_within_pct(r, g, ratio, 7.5, 0.02, "설계 §4.3 '7.5배' 검산")

	# 독 6초 검산: 스택 3 고정이면 24틱 × 3 × 0.045 = 3.24 P
	var held: Array = StatusEngine.make_state()
	for index in 3:
		StatusEngine.apply(held, "poison", 1.0, _ctx())
	var held_total := 0.0
	var held_ticks := 0
	var quantum_count := int(round(GameTuning.POISON_DURATION / GameTuning.STATUS_TICK))
	for index in quantum_count:
		held[StatusEngine.F_POISON_STACKS] = 3.0
		held[StatusEngine.F_POISON_DECAY] = GameTuning.POISON_STACK_DECAY_INTERVAL
		var dot: float = StatusEngine.tick_dot(held, GameTuning.STATUS_TICK)
		if dot > 0.0:
			held_total += dot
			held_ticks += 1
	var held_expected: float = float(quantum_count) * 3.0 * GameTuning.POISON_DOT_PER_STACK * P
	_ok(r, g, held_ticks == quantum_count, "독 틱 수 %d (기대 %d)" % [held_ticks, quantum_count])
	_within_pct(r, g, held_total, held_expected, 0.02, "독 6초 총 도트(스택 3 고정)")

	# 감쇠까지 반영한 실제 총량은 정보성 지표로만 남긴다(설계의 "≈2 P"는 근사치다).
	var natural: Array = StatusEngine.make_state()
	for index in 4:
		StatusEngine.apply(natural, "poison", 1.0, _ctx())
	var natural_total := float(_drain(natural)["total"])

	r["metrics"]["burn_p"] = "%.4f" % plain_total
	r["metrics"]["blaze_p"] = "%.4f" % blazed_total
	r["metrics"]["blaze_ratio_x"] = "%.4f" % ratio
	r["metrics"]["poison_held_p"] = "%.4f" % held_total
	r["metrics"]["poison_decay_p"] = "%.4f" % natural_total


# =============================================================================
# ④ chill → thunder 전도 (사용자 명시 요구 2건 중 하나)
# =============================================================================
static func _check_conduction(r: Dictionary) -> void:
	var g := "conduction"

	var state := _column("chill")
	var result := StatusEngine.apply(state, "thunder", 1.0, _ctx())
	var chain := _event_of(result, StatusEngine.E_CHAIN_DAMAGE)
	_ok(r, g, not chain.is_empty(), "전도 전이 이벤트 없음")
	if chain.is_empty():
		return

	# 완료 기준: 전이 이벤트가 {radius, max_targets, falloff}를 정확히 낸다
	for key: String in ["radius", "max_targets", "falloff"]:
		_ok(r, g, chain.has(key), "전이 이벤트에 %s 키가 없다" % key)
	_near(r, g, float(chain["radius"]), GameTuning.SYN_CONDUCTION_RADIUS, "전도 반경")
	_ok(r, g, int(chain["max_targets"]) == GameTuning.SYN_CONDUCTION_MAX_TARGETS,
		"전도 최대 대상 %d (기대 %d)" % [int(chain["max_targets"]), GameTuning.SYN_CONDUCTION_MAX_TARGETS])
	_near(r, g, float(chain["falloff"]), GameTuning.SYN_CONDUCTION_FALLOFF, "전도 도약 감쇠")
	_near(r, g, float(chain["amount"]), GameTuning.SYN_CONDUCTION_DAMAGE * P, "전도 1도약 피해")
	_ok(r, g, String(chain.get("filter", "")) == "chill", "전도가 chill 필터를 걸지 않았다")
	_ok(r, g, String(chain.get("apply_status", "")) == "shock", "전도가 전 표식을 남기지 않는다")

	# 4체 · 도약당 −20%
	var expected: float = GameTuning.SYN_CONDUCTION_DAMAGE * P
	var chain_total := 0.0
	for hop in GameTuning.SYN_CONDUCTION_MAX_TARGETS:
		var value: float = StatusEngine.chain_damage(chain, hop)
		_near(r, g, value, expected, "전도 %d번째 도약 피해" % (hop + 1))
		chain_total += value
		expected *= (1.0 - GameTuning.SYN_CONDUCTION_FALLOFF)
	r["metrics"]["conduction_total_p"] = "%.4f" % chain_total

	# 1차 대상의 한은 소모되지 않는다(전도는 매개를 태우지 않는다)
	_ok(r, g, StatusEngine.has(state, "chill"), "전도가 1차 대상의 한을 소모했다")
	_ok(r, g, StatusEngine.has(state, "shock"), "전도 후 1차 대상에 전 표식이 없다")

	# 전이 대상에 다시 뇌를 꽂아도(깊이 1) 재전도하지 않는다
	var hop_state := _column("chill")
	var hop_result := StatusEngine.apply(hop_state, "thunder", 1.0,
		_ctx(P, 1.0, GameTuning.STATUS_PROPAGATION_DEPTH))
	_ok(r, g, _count_events(hop_result, StatusEngine.E_CHAIN_DAMAGE) == 0,
		"깊이 %d에서 전도가 또 나왔다" % GameTuning.STATUS_PROPAGATION_DEPTH)
	_ok(r, g, int(hop_result["suppressed"]) == 1,
		"깊이 초과 억제 카운트 %d (기대 1)" % int(hop_result["suppressed"]))


# =============================================================================
# ⑤ psi 수확 — 남은 지속 30% 소모 → 환산 피해
# =============================================================================
static func _check_psi(r: Dictionary) -> void:
	var g := "psi_harvest"

	var state: Array = StatusEngine.make_state()
	for status: String in StatusEngine.STATUSES:
		StatusEngine.set_status(state, status, {"damage": P, "power": 1.0})
	var before_total := StatusEngine.total_remaining(state)
	var expected_total: float = GameTuning.POISON_DURATION + GameTuning.BURN_DURATION \
		+ GameTuning.CHILL_DURATION + GameTuning.OIL_DURATION + GameTuning.SHOCK_DURATION
	_near(r, g, before_total, expected_total, "psi 대상의 남은 지속 합", 1.0e-4)

	var per_status: Dictionary = {}
	for status: String in StatusEngine.STATUSES:
		per_status[status] = StatusEngine.remaining(state, status)

	var result := StatusEngine.apply(state, "psi", 1.0, _ctx())
	var event := _event_of(result, StatusEngine.E_DAMAGE)
	_ok(r, g, not event.is_empty(), "정신 붕괴 피해 이벤트 없음")
	if event.is_empty():
		return

	var drained_expected: float = before_total * GameTuning.SYN_PSI_DRAIN_RATIO
	_near(r, g, float(event["drained_seconds"]), drained_expected, "소모한 총 초", 1.0e-4)
	_near(r, g, float(event["amount"]),
		drained_expected * GameTuning.SYN_PSI_DRAIN_DAMAGE_PER_SECOND * P, "정신 붕괴 환산 피해", 1.0e-4)

	# 모든 상태가 정확히 (1 − ratio)배로 남는다
	for status: String in StatusEngine.STATUSES:
		_near(r, g, StatusEngine.remaining(state, status),
			float(per_status[status]) * (1.0 - GameTuning.SYN_PSI_DRAIN_RATIO),
			"%s 남은 지속" % status, 1.0e-4)
	_near(r, g, StatusEngine.total_remaining(state),
		before_total * (1.0 - GameTuning.SYN_PSI_DRAIN_RATIO), "psi 후 지속 합", 1.0e-4)

	# 상태가 없으면 아무 일도 일어나지 않는다
	var bare: Array = StatusEngine.make_state()
	var bare_result := StatusEngine.apply(bare, "psi", 1.0, _ctx())
	_ok(r, g, bare_result["events"].is_empty(), "상태 없는 대상에 psi가 이벤트를 냈다")

	r["metrics"]["psi_p"] = "%.4f" % float(event["amount"])


# =============================================================================
# ⑥ 반응 예산 · 전파 깊이 (§4.7 규칙 4)
# =============================================================================
static func _check_budget(r: Dictionary) -> void:
	var g := "budget"

	# 기본 예산이 튜닝값에서 온다
	var fresh_budget := StatusEngine.make_budget()
	_ok(r, g, int(fresh_budget["cap"]) == GameTuning.STATUS_REACTION_BUDGET_PER_FRAME,
		"기본 예산 상한 %d (기대 %d)" % [
			int(fresh_budget["cap"]), GameTuning.STATUS_REACTION_BUDGET_PER_FRAME])

	# 상한 2로 조인 예산에 5회 반응을 던진다 → 질의 이벤트는 2개만 나온다
	var budget: Dictionary = {"used": 0, "cap": 2}
	var emitted := 0
	var suppressed := 0
	var over_cap := false
	for index in 5:
		var target := _column("oil")
		var result := StatusEngine.apply(target, "fire", 1.0, _ctx(P, 1.0, 0, budget))
		emitted += _count_events(result, StatusEngine.E_SPREAD_STATUS)
		suppressed += int(result["suppressed"])
		if int(budget["used"]) > int(budget["cap"]):
			over_cap = true
		# 예산이 말라도 **상태 수치는 그대로** 계산돼야 한다
		_near(r, g, StatusEngine.remaining(target, "burn"),
			GameTuning.BURN_DURATION * GameTuning.SYN_BLAZE_DURATION_MUL,
			"예산 고갈 %d회차의 대폭 연소 지속" % (index + 1))
	_ok(r, g, not over_cap, "예산 사용량이 상한을 넘었다")
	_ok(r, g, emitted == 2, "예산 2에서 나온 질의 이벤트 %d개 (기대 2)" % emitted)
	_ok(r, g, suppressed == 3, "억제된 이벤트 %d개 (기대 3)" % suppressed)
	_ok(r, g, int(budget["used"]) == 2, "예산 사용량 %d (기대 2)" % int(budget["used"]))

	StatusEngine.budget_reset(budget)
	_ok(r, g, int(budget["used"]) == 0, "예산 초기화 실패")
	_ok(r, g, StatusEngine.budget_left(budget) == 2, "예산 잔량 %d (기대 2)" % StatusEngine.budget_left(budget))

	# 전파 깊이 1: 깊이 0에서는 나오고 깊이 1에서는 안 나온다
	_ok(r, g, StatusEngine.can_propagate(GameTuning.STATUS_PROPAGATION_DEPTH - 1),
		"깊이 %d에서 전파가 막혔다" % (GameTuning.STATUS_PROPAGATION_DEPTH - 1))
	_ok(r, g, not StatusEngine.can_propagate(GameTuning.STATUS_PROPAGATION_DEPTH),
		"깊이 %d에서 전파가 뚫렸다" % GameTuning.STATUS_PROPAGATION_DEPTH)

	var deep := _column("oil")
	var deep_result := StatusEngine.apply(deep, "fire", 1.0, _ctx(P, 1.0, GameTuning.STATUS_PROPAGATION_DEPTH))
	_ok(r, g, _count_events(deep_result, StatusEngine.E_SPREAD_STATUS) == 0,
		"깊이 초과인데 기름이 또 퍼졌다")
	_ok(r, g, int(deep_result["suppressed"]) == 1,
		"깊이 억제 카운트 %d (기대 1)" % int(deep_result["suppressed"]))
	# 깊이로 잘려도 대폭 연소 자체는 성립한다
	_near(r, g, deep[StatusEngine.F_BURN_UNIT],
		GameTuning.BURN_DOT * P * GameTuning.SYN_BLAZE_POWER_MUL, "깊이 억제 시 연 틱")

	# 예산을 넣지 않으면(도구·미리보기 경로) 무제한이다
	var unlimited := _column("oil")
	var unlimited_result := StatusEngine.apply(unlimited, "fire", 1.0, _ctx())
	_ok(r, g, _count_events(unlimited_result, StatusEngine.E_SPREAD_STATUS) == 1,
		"예산 미지정 경로에서 전파 이벤트가 사라졌다")

	# preview()는 상태를 바꾸지 않는다
	var peeked := _column("oil")
	var before_sig := StatusEngine.signature(peeked)
	var peek := StatusEngine.preview(peeked, "fire", 1.0, _ctx())
	_ok(r, g, StatusEngine.signature(peeked) == before_sig, "preview()가 상태를 변경했다")
	var peek_reactions: Array = peek["reactions"]
	_ok(r, g, not peek_reactions.is_empty() and String(peek_reactions[0]) == StatusEngine.R_BLAZE,
		"preview()가 대폭 연소를 예고하지 않았다")
	_near(r, g, float(peek["incoming_mul"]), GameTuning.OIL_FIRE_TAKEN_MUL, "preview 화염 증폭")


# =============================================================================
# ⑦ 결정성
# =============================================================================
static func _check_determinism(r: Dictionary) -> void:
	var g := "deterministic"

	# 같은 대본을 두 번 돌리면 지문과 도트 총량이 완전히 같아야 한다
	var script_a := _run_script()
	var script_b := _run_script()
	_ok(r, g, String(script_a["signature"]) == String(script_b["signature"]),
		"같은 입력의 지문 불일치 [%s] vs [%s]" % [script_a["signature"], script_b["signature"]])
	_near(r, g, float(script_a["dot"]), float(script_b["dot"]), "같은 입력의 도트 총량", 0.0)
	_ok(r, g, String(script_a["reactions"]) == String(script_b["reactions"]),
		"같은 입력의 반응 시퀀스 불일치")
	r["metrics"]["script_dot"] = "%.5f" % float(script_a["dot"])

	# delta 분할 불변: 1회 · 4회 · 60회로 나눠 넣어도 같은 결과
	var one: Array = StatusEngine.make_state()
	StatusEngine.apply(one, "fire", 1.0, _ctx())
	var one_dot: float = StatusEngine.tick_dot(one, GameTuning.BURN_DURATION)

	var quarter: Array = StatusEngine.make_state()
	StatusEngine.apply(quarter, "fire", 1.0, _ctx())
	var quarter_dot := 0.0
	for index in int(round(GameTuning.BURN_DURATION / GameTuning.STATUS_TICK)):
		quarter_dot += StatusEngine.tick_dot(quarter, GameTuning.STATUS_TICK)

	var frame: Array = StatusEngine.make_state()
	StatusEngine.apply(frame, "fire", 1.0, _ctx())
	var frame_dot := 0.0
	var frame_delta := 1.0 / 60.0
	for index in int(round(GameTuning.BURN_DURATION * 60.0)):
		frame_dot += StatusEngine.tick_dot(frame, frame_delta)

	_near(r, g, quarter_dot, one_dot, "0.25초 4분할 도트", 1.0e-6)
	_near(r, g, frame_dot, one_dot, "1/60초 분할 도트", 1.0e-5)
	_ok(r, g, StatusEngine.signature(one) == StatusEngine.signature(quarter),
		"분할에 따라 최종 상태가 달라졌다")

	# 엔진이 시간·난수를 만지지 않는다는 간접 증거: 같은 상태 사본에 같은 적용
	var left := _column("chill")
	var right: Array = left.duplicate()
	var left_result := StatusEngine.apply(left, "thunder", 1.0, _ctx())
	var right_result := StatusEngine.apply(right, "thunder", 1.0, _ctx())
	_ok(r, g, StatusEngine.signature(left) == StatusEngine.signature(right), "동일 사본의 적용 결과가 다르다")
	_near(r, g, float(_event_of(left_result, StatusEngine.E_CHAIN_DAMAGE).get("amount", -1.0)),
		float(_event_of(right_result, StatusEngine.E_CHAIN_DAMAGE).get("amount", -2.0)),
		"동일 사본의 전이 피해", 0.0)


## 7원소 × 상태 혼합 40수를 고정 순서로 두는 대본. 무작위성이 없다.
static func _run_script() -> Dictionary:
	var state: Array = StatusEngine.make_state()
	var budget: Dictionary = {"used": 0, "cap": GameTuning.STATUS_REACTION_BUDGET_PER_FRAME}
	var dot := 0.0
	var reactions: Array[String] = []
	var order: Array[String] = ["oil", "fire", "poison", "ice", "thunder", "strike", "psi", "poison"]
	for round_index in 5:
		for element: String in order:
			var result := StatusEngine.apply(state, element, 1.0,
				{"damage": 1.0 + 0.1 * float(round_index), "potency": 1.0, "depth": 0, "budget": budget})
			for reaction in result["reactions"]:
				reactions.append(String(reaction))
			dot += StatusEngine.tick_dot(state, GameTuning.STATUS_TICK)
		StatusEngine.budget_reset(budget)
		dot += StatusEngine.tick_dot(state, 0.5)
	return {"signature": StatusEngine.signature(state), "dot": dot, "reactions": ",".join(reactions)}
