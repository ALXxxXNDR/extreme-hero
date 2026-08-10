class_name StatusEngine
extends RefCounted

# =============================================================================
# V1 — 원소 상태이상 규칙 엔진 (극딜 용사 v3 · L2 대상 레벨)
# =============================================================================
# 설계 근거: docs/GAME_DESIGN_V3.md §4 전체.
#   §4.1 2층 구조 · §4.3 상태 5종 데이터 모델 · §4.4 시너지 매트릭스 ·
#   §4.7 성능 4규칙 · 부록 B의 V1 행(완료 기준).
#
# ── 이 파일의 계약 (rune_engine.gd와 같은 계층 규칙) ─────────────────────────
#   * **순수하다.** 노드·씬·시그널·전역 상태·`Time`·`randf()`를 만지지 않는다.
#     같은 입력이면 언제나 같은 출력이다 — `--status-test` ⑦이 이것을 단언한다.
#   * **엔진은 게임을 모른다.** 대상은 float 11칸짜리 `Array` 하나로만 본다.
#     적 노드도, 좌표도, 반경 안에 누가 있는지도 모른다. 그건 전부 **이벤트**로
#     내보내고 실행은 호출자(V6의 `combat_resolver`)가 한다.
#   * **숫자를 갖지 않는다.** 지속·계수·성능 예산은 전부 `GameTuning`
#     (V3-K 14개 · V3-L 19개 · V3-M 3개)이 단일 소유자다. 여기 있는 상수는
#     **배열 레이아웃 · 이벤트 어휘 · 순수성 가드**뿐이며 밸런스 값이 하나도 없다.
#
# ── 2층 구조에서 이 파일의 자리 (§4.1) ───────────────────────────────────────
#   L1 덱 레벨 = `rune_engine.simulate_cycle()` — 직접 피해 0. `potency`만 만든다.
#   L2 대상 레벨 = **이 파일** — 모든 상태 피해. 사이클 피해 배율을 곱하지 않는다.
#   두 층이 서로의 계산 지점을 침범하지 않으므로 이중 계산이 구조적으로 불가능하다.
#
# ── 3개의 곱셈 채널을 헷갈리지 말 것 ─────────────────────────────────────────
#   `damage`  : `_cycle_damage_value()`가 낸 그 칸의 사이클 피해. ctx["damage"].
#   `potency` : L1이 만든 상태 위력 배율(§4.5 인화 ×1.5 등). ctx["potency"].
#   `P`       : = damage × potency. **모든 상태 피해의 기준값**(§4.3 표의 P).
#   `power`   : 상태 자체의 세기 배율(기본 1.0). 한(chill)의 감속량과 연(burn)의
#               틱 피해를 곱한다. 대폭 연소가 ×3 하는 것이 바로 이 값이다.
#
# ── V6 통합 진입점 (자세한 순서는 docs/handoff-v1.md) ───────────────────────
#   부여: `combat_resolver._apply_card_status_to_enemy()` → `StatusEngine.apply()`
#         → 반환된 `events`를 순회 실행(AoE는 query_enemies, 전이는 chill 필터).
#   틱  : `enemy._physics_process`의 기존 타이머 블록 → `StatusEngine.tick_dot()`
#         (Dictionary를 만들지 않는 제로 할당 경로. 반환이 0보다 크면 그때만
#          `take_damage(dot, SOURCE_DOT)` 1회 = §4.7 규칙 2의 0.25초 버퍼).


# =============================================================================
# 1. 상태 묶음 레이아웃 — "고정 크기 float 묶음"(§4.3)
# =============================================================================
# 적 1기가 가지는 상태는 float 11칸이다. Dictionary도 오브젝트도 아니다.
# `Array`를 쓰는 이유는 **참조 타입**이라서다 — 제자리 갱신이 되므로 프레임마다
# 78기 × 재할당이 일어나지 않는다(PackedFloat32Array는 값 타입이라 못 쓴다).
# 인덱스 상수는 공개 API다. 테스트와 V6이 직접 읽고 써도 된다.
const F_POISON_TIME := 0     # 독 남은 지속(초)
const F_POISON_STACKS := 1   # 독 스택 1~POISON_STACK_MAX (float로 담되 정수값)
const F_POISON_UNIT := 2     # 스택 1개가 한 틱에 주는 피해 = POISON_DOT_PER_STACK × P × power
const F_POISON_DECAY := 3    # 다음 스택 감소까지 남은 초
const F_BURN_TIME := 4       # 연 남은 지속(초)
const F_BURN_UNIT := 5       # 연 한 틱 피해 = BURN_DOT × P × power
const F_CHILL_TIME := 6      # 한 남은 지속(초)
const F_CHILL_POWER := 7     # 한 세기 0~1 (이동 ×(1 − CHILL_SLOW × power))
const F_OIL_TIME := 8        # 유 남은 지속(초). 자체 피해 0
const F_SHOCK_TIME := 9      # 전 남은 지속(초). 다음 피격 표식
const F_TICK_ACCUM := 10     # 다음 도트 틱까지 누적된 시간(0 ~ STATUS_TICK)
const FIELD_COUNT := 11

# 상태 5종의 정규 순서. HUD 핍(최대 GameTuning.STATUS_PIP_MAX개)도 이 순서를 따른다.
const STATUSES: Array[String] = ["poison", "burn", "chill", "oil", "shock"]

# 매트릭스의 행(지금 적용하는 원소) 7종. §4.2의 원소 7계와 같은 어휘다.
# ⚠️ V2가 `rune_engine.ELEMENTS`를 이 7종으로 재편한다. 두 배열이 어긋나면
#    L1 반응과 L2 매트릭스가 다른 원소를 보게 된다 — V6이 배선할 때 대조할 것.
const ELEMENTS: Array[String] = ["poison", "fire", "ice", "thunder", "oil", "strike", "psi"]

# 상태 5종 중 도트를 내는 것. 나머지 3종(한·유·전)은 피해가 0이다.
const DOT_STATUSES: Array[String] = ["poison", "burn"]


# =============================================================================
# 2. 시너지 매트릭스 (§4.4) — 이 표가 아래 `apply()`의 정본이다
# =============================================================================
# 행 = 지금 적용하는 원소 / 열 = 대상에 **이미 붙어 있는** 상태.
#
# | ↓적용 \ 기존→ | (없음)   | poison 독        | burn 연        | chill 한        | oil 유          | shock 전       |
# |---------------|----------|------------------|----------------|-----------------|-----------------|----------------|
# | poison 독     | 독 부여  | 스택 +1          | —              | 독 지속 +50%    | —               | —              |
# | fire   화     | 연 부여  | ★역병 발화       | 연 갱신        | 증기(범위+50%)  | ★대폭 연소      | —              |
# | ice    빙     | 한 부여  | 독 지속 +50%     | 연 해제→한     | 한 갱신·강화    | —               | —              |
# | thunder 뇌    | 전 표식  | —                | —              | ★전도(4체 전이) | 감전 유막       | 전 갱신        |
# | oil    유     | 유 부여  | —                | 연 power ×2    | —               | 유 갱신         | —              |
# | strike 타     | (없음)   | 터뜨리기         | —              | 쇄빙            | —               | —              |
# | psi    초     | (없음)   | ← 정신 붕괴: 모든 상태의 남은 지속 30% 소모 → 소모 초 × 0.5 × P 즉발 →         |
#
# 한 번의 `apply()`가 **여러 열을 동시에** 밟을 수 있다(예: 독+유가 붙은 적에게 화 =
# 대폭 연소 + 역병 발화). 각 열이 서로 다른 자원을 소비하므로 배타로 만들 이유가 없다.
# 다만 순서는 결정적이어야 하므로 행마다 아래 순서로 고정했다:
#   화 : 유(대폭 연소) → 독(역병 발화) → 한(증기) → 연 부여/갱신
#   빙 : 독(지속 +50%) → 연(해제) → 한 부여/갱신
#   뇌 : 한(전도) → 유(감전 유막) → 전 부여/갱신
#   타 : 독(터뜨리기) → 한(쇄빙)
# 유(대폭 연소)를 독(역병 발화)보다 먼저 처리하는 이유: 대폭 연소가 **이번에 부여할
# 연의 power·지속을 바꾸므로** 연 부여보다 반드시 앞서야 한다. 역병 발화는 연과
# 독립이라 순서 자유지만 결정성을 위해 고정한다.

# 반응 키 — 이벤트·테스트·HUD가 공유하는 어휘. 값은 §4.8 부유 라벨 문자열이다.
const R_POISON_APPLY := "poison_apply"
const R_POISON_STACK := "poison_stack"
const R_FROZEN_VENOM := "frozen_venom"       # 독 지속 +50% (독↓×한 · 빙↓×독)
const R_BURN_APPLY := "burn_apply"
const R_BURN_REFRESH := "burn_refresh"
const R_PLAGUE_IGNITION := "plague_ignition" # 화↓×독
const R_STEAM := "steam"                     # 화↓×한
const R_BLAZE := "blaze"                     # ★화↓×유
const R_CHILL_APPLY := "chill_apply"
const R_CHILL_REFRESH := "chill_refresh"
const R_QUENCH := "quench"                   # 빙↓×연 (연 해제)
const R_SHOCK_APPLY := "shock_apply"
const R_SHOCK_REFRESH := "shock_refresh"
const R_CONDUCTION := "conduction"           # ★뇌↓×한
const R_OILED_SHOCK := "oiled_shock"         # 뇌↓×유
const R_OIL_APPLY := "oil_apply"
const R_OIL_REFRESH := "oil_refresh"
const R_GREASED_FLAME := "greased_flame"     # 유↓×연 (불에 기름)
const R_DETONATE := "detonate"               # 타↓×독
const R_SHATTER := "shatter"                 # 타↓×한
const R_PSI_COLLAPSE := "psi_collapse"       # 초↓×전상태

# 시너지 발동 시 1회성 부유 라벨(§4.8). 평범한 부여·갱신은 라벨을 내지 않는다("").
const REACTION_LABELS: Dictionary = {
	R_POISON_APPLY: "", R_POISON_STACK: "", R_BURN_APPLY: "", R_BURN_REFRESH: "",
	R_CHILL_APPLY: "", R_CHILL_REFRESH: "", R_SHOCK_APPLY: "", R_SHOCK_REFRESH: "",
	R_OIL_APPLY: "", R_OIL_REFRESH: "",
	# YZ: 2~4자 한자어 압축을 화면에서 바로 읽히는 우리말로 풀었다. 키는 그대로다.
	R_FROZEN_VENOM: "언 독!",
	R_PLAGUE_IGNITION: "역병에 불!",
	R_STEAM: "증기!",
	R_BLAZE: "크게 타오름!",
	R_QUENCH: "불 꺼짐!",
	R_CONDUCTION: "번개 옮음!",
	R_OILED_SHOCK: "기름에 전기!",
	R_GREASED_FLAME: "불에 기름!",
	R_DETONATE: "터뜨리기!",
	R_SHATTER: "얼음 깨짐!",
	R_PSI_COLLAPSE: "정신 붕괴!"
}


# =============================================================================
# 3. 이벤트 어휘 — 엔진이 "해 달라"고 부탁하는 것 전부
# =============================================================================
# `apply()`는 세계를 만지지 않는다. 대신 아래 6종의 이벤트를 리스트로 돌려주고
# V6의 `combat_resolver`가 실행한다. 각 이벤트는 항상 `kind`·`reaction`·`label`을
# 가지며 나머지 키는 종류별이다.
#
#   E_DAMAGE        단일 대상 즉발 피해.        amount
#   E_AOE_DAMAGE    반경 내 전원 즉발 피해.     amount · radius · apply_status(선택)
#   E_CHAIN_DAMAGE  전이. 반경 내 filter 상태를 가진 적에게만.
#                   amount · radius · max_targets · falloff · filter · apply_status
#   E_SPREAD_STATUS 반경 내 전원에게 상태 전파. status · radius · duration · power · depth
#   E_KNOCKBACK     넉백·경직 보정.             knockback_mul · stun
#   E_RANGE_BONUS   **이번 타격**의 범위 보정.  range_bonus
const E_DAMAGE := "damage"
const E_AOE_DAMAGE := "aoe_damage"
const E_CHAIN_DAMAGE := "chain_damage"
const E_SPREAD_STATUS := "spread_status"
const E_KNOCKBACK := "knockback"
const E_RANGE_BONUS := "range_bonus"

# `take_damage(amount, source)`의 source 어휘(§4.7 규칙 3). enemy.gd가 자기 enum을
# 따로 만들면 두 벌이 갈라지므로 **여기 한 벌만 둔다.** SOURCE_DOT이면 enemy.gd가
# `provoke()`·`alert_same_species()`를 건너뛴다 — 이건 선택이 아니라 필수다.
const SOURCE_NORMAL := 0
const SOURCE_DOT := 1
const SOURCE_REACTION := 2

# 세계 질의(반경 순회)를 요구하는 이벤트 = 반응 예산을 먹는 이벤트.
# 나머지(단일 피해·넉백·범위 보정)는 O(1)이라 예산을 먹지 않는다.
const QUERY_EVENTS: Array[String] = [E_AOE_DAMAGE, E_CHAIN_DAMAGE, E_SPREAD_STATUS]
# 호출자가 **다른 대상에게 다시 `apply()`를 들어가게** 만드는 이벤트 = 전파 깊이 대상.
const PROPAGATING_EVENTS: Array[String] = [E_CHAIN_DAMAGE, E_SPREAD_STATUS]


# =============================================================================
# 4. 순수성·수치 가드 (밸런스 값 아님)
# =============================================================================
# 부동소수 비교 여유. 0.25초 틱 경계를 float 오차로 놓치지 않기 위한 값이며
# 10µs라 게임 수치에 영향이 없다.
const TIME_EPS := 1.0e-5
# 한 번의 tick 호출이 처리하는 최대 슬라이스 수. delta가 이보다 크면 잘라낸다
# (로딩 스파이크·일시정지 복귀에서 도트가 한꺼번에 터지는 것을 막는 방어값).
# 16 × 0.25초 = 4초까지는 손실 없이 처리하고, 테스트가 쓰는 6~8초 단발 호출도
# 여유롭게 담기도록 64로 둔다.
const MAX_SLICES_PER_CALL := 64


# =============================================================================
# 5. 상태 묶음 생성·조회
# =============================================================================

## 상태 없음 상태의 새 묶음. V6은 enemy 하나당 **한 번만** 만들고 재사용한다.
static func make_state() -> Array:
	var state: Array = []
	state.resize(FIELD_COUNT)
	state.fill(0.0)
	return state


## 전부 해제. V9 저장 복원("상태이상은 복원 후 전부 0")과 적 재사용 풀이 쓴다.
static func clear(state: Array) -> void:
	if state.size() != FIELD_COUNT:
		return
	state.fill(0.0)


static func is_state(state: Array) -> bool:
	return state.size() == FIELD_COUNT


## 상태 하나라도 붙어 있는가. 핫 패스의 조기 탈출 조건이다.
static func has_any(state: Array) -> bool:
	if state.size() != FIELD_COUNT:
		return false
	return state[F_POISON_TIME] > 0.0 or state[F_BURN_TIME] > 0.0 \
		or state[F_CHILL_TIME] > 0.0 or state[F_OIL_TIME] > 0.0 or state[F_SHOCK_TIME] > 0.0


static func has(state: Array, status: String) -> bool:
	return remaining(state, status) > 0.0


## 남은 지속(초). 없는 상태·모르는 이름이면 0.
static func remaining(state: Array, status: String) -> float:
	if state.size() != FIELD_COUNT:
		return 0.0
	match status:
		"poison": return state[F_POISON_TIME]
		"burn": return state[F_BURN_TIME]
		"chill": return state[F_CHILL_TIME]
		"oil": return state[F_OIL_TIME]
		"shock": return state[F_SHOCK_TIME]
	return 0.0


## 붙어 있는 모든 상태의 남은 지속 합. 정신 붕괴(psi)의 환산 기준이다.
static func total_remaining(state: Array) -> float:
	var total := 0.0
	for status: String in STATUSES:
		total += remaining(state, status)
	return total


static func stacks(state: Array) -> int:
	if state.size() != FIELD_COUNT:
		return 0
	return int(roundf(state[F_POISON_STACKS]))


## 활성 상태 이름 목록(정규 순서). HUD·테스트가 쓴다.
static func active_list(state: Array) -> Array[String]:
	var out: Array[String] = []
	for status: String in STATUSES:
		if remaining(state, status) > 0.0:
			out.append(status)
	return out


## 머리 위 상태 핍(§4.8). 최대 GameTuning.STATUS_PIP_MAX개.
static func pip_list(state: Array) -> Array[String]:
	var out := active_list(state)
	while out.size() > GameTuning.STATUS_PIP_MAX:
		out.remove_at(out.size() - 1)
	return out


## 결정성 지문. 같은 입력 → 같은 문자열이어야 한다(`--status-test` ⑦).
static func signature(state: Array) -> String:
	if state.size() != FIELD_COUNT:
		return "invalid"
	return "%.4f|%.0f|%.5f|%.4f|%.4f|%.5f|%.4f|%.3f|%.4f|%.4f|%.4f" % [
		state[F_POISON_TIME], state[F_POISON_STACKS], state[F_POISON_UNIT], state[F_POISON_DECAY],
		state[F_BURN_TIME], state[F_BURN_UNIT],
		state[F_CHILL_TIME], state[F_CHILL_POWER],
		state[F_OIL_TIME], state[F_SHOCK_TIME], state[F_TICK_ACCUM]
	]


# =============================================================================
# 6. 대상 상태가 만드는 배율 (읽기 전용)
# =============================================================================

## 이동 속도 배율. 한(chill) 감속(§4.3): 이동 ×(1 − CHILL_SLOW × power).
## power는 0~1로 클램프해 두므로 하한은 (1 − CHILL_SLOW)다.
static func move_multiplier(state: Array) -> float:
	if state.size() != FIELD_COUNT or state[F_CHILL_TIME] <= 0.0:
		return 1.0
	return clampf(1.0 - GameTuning.CHILL_SLOW * state[F_CHILL_POWER],
		1.0 - GameTuning.CHILL_SLOW, 1.0)


## 받는 피해 배율 중 **원소 조건부**인 것. 지금은 유(oil)의 화염 증폭 하나다(×2.2).
## ⚠️ 호출 순서: 직격 피해를 계산할 때 `apply()`보다 **먼저** 물어야 한다.
##    화가 유에 닿으면 `apply()`가 기름을 소모해 버리기 때문이다.
static func incoming_multiplier(state: Array, element: String) -> float:
	if state.size() != FIELD_COUNT:
		return 1.0
	if element == "fire" and state[F_OIL_TIME] > 0.0:
		return GameTuning.OIL_FIRE_TAKEN_MUL
	return 1.0


## 전(shock) 표식의 다음 피격 보너스(소모하지 않고 보기만).
static func next_hit_multiplier(state: Array) -> float:
	if state.size() != FIELD_COUNT or state[F_SHOCK_TIME] <= 0.0:
		return 1.0
	return 1.0 + GameTuning.SHOCK_NEXT_HIT_BONUS


## 전(shock) 표식을 **소모하고** 배율을 돌려준다. "다음 피격 +12%"(§4.3)의 실체.
static func consume_shock(state: Array) -> float:
	var mul := next_hit_multiplier(state)
	if mul > 1.0:
		state[F_SHOCK_TIME] = 0.0
	return mul


## 한 틱(STATUS_TICK)이 낼 도트. tick 없이 값만 보고 싶을 때.
static func tick_damage(state: Array) -> float:
	if state.size() != FIELD_COUNT:
		return 0.0
	var dot := 0.0
	if state[F_POISON_TIME] > 0.0:
		dot += state[F_POISON_UNIT] * state[F_POISON_STACKS]
	if state[F_BURN_TIME] > 0.0:
		dot += state[F_BURN_UNIT]
	return dot


## ctx에서 P를 뽑는다. P = damage × potency (§4.3 · §4.5의 potency 채널).
static func potency_damage(ctx: Dictionary) -> float:
	return maxf(0.0, float(ctx.get("damage", 0.0))) * maxf(0.0, float(ctx.get("potency", 1.0)))


# =============================================================================
# 7. 저수준 부여 — 매트릭스를 **거치지 않고** 상태만 심는다
# =============================================================================
# 쓰이는 곳 세 군데:
#   ① `E_AOE_DAMAGE`/`E_CHAIN_DAMAGE`의 `apply_status`(전 표식) 실행 — 표식을 심으려고
#      뇌 행 전체를 다시 도는 것은 낭비이고 연쇄의 원인이 된다.
#   ② 보스 패턴의 `status` 페이로드(V7).
#   ③ 테스트가 반응 없이 특정 열 상태를 만들 때.
# opts: power(1.0) · damage(0.0) · potency(1.0) · duration(-1=기본값) · stacks(1)
static func set_status(state: Array, status: String, opts: Dictionary = {}) -> void:
	if state.size() != FIELD_COUNT:
		return
	var power := maxf(0.0, float(opts.get("power", 1.0)))
	var p := potency_damage(opts)
	var duration := float(opts.get("duration", -1.0))
	match status:
		"poison":
			var want_stacks := clampi(int(opts.get("stacks", 1)), 1, GameTuning.POISON_STACK_MAX)
			state[F_POISON_TIME] = GameTuning.POISON_DURATION if duration < 0.0 else duration
			state[F_POISON_STACKS] = float(want_stacks)
			state[F_POISON_UNIT] = maxf(state[F_POISON_UNIT], GameTuning.POISON_DOT_PER_STACK * p * power)
			state[F_POISON_DECAY] = GameTuning.POISON_STACK_DECAY_INTERVAL
		"burn":
			state[F_BURN_TIME] = GameTuning.BURN_DURATION if duration < 0.0 else duration
			state[F_BURN_UNIT] = maxf(state[F_BURN_UNIT], GameTuning.BURN_DOT * p * power)
		"chill":
			state[F_CHILL_TIME] = GameTuning.CHILL_DURATION if duration < 0.0 else duration
			state[F_CHILL_POWER] = maxf(state[F_CHILL_POWER], clampf(power, 0.0, 1.0))
		"oil":
			state[F_OIL_TIME] = GameTuning.OIL_DURATION if duration < 0.0 else duration
		"shock":
			state[F_SHOCK_TIME] = GameTuning.SHOCK_DURATION if duration < 0.0 else duration


# =============================================================================
# 8. 반응 예산 (§4.7 규칙 4)
# =============================================================================
# 예산은 **프레임 단위 자원**이므로 엔진이 들고 있으면 순수성이 깨진다. 호출자가
# 만들어 매 프레임 초기화하고 ctx["budget"]으로 넣어 준다. ctx에 없으면 무제한이다.
#
# 예산이 막는 것은 **세계 질의 이벤트(QUERY_EVENTS)뿐**이다. 상태 수치 계산과 단일
# 대상 피해는 언제나 그대로 일어난다 — 예산이 바닥났다고 대폭 연소의 연이 안 붙으면
# 그건 성능 보호가 아니라 게임 규칙이 프레임률에 종속되는 것이다.
static func make_budget() -> Dictionary:
	return {"used": 0, "cap": GameTuning.STATUS_REACTION_BUDGET_PER_FRAME}


static func budget_reset(budget: Dictionary) -> void:
	budget["used"] = 0
	budget["cap"] = int(budget.get("cap", GameTuning.STATUS_REACTION_BUDGET_PER_FRAME))


static func budget_left(budget: Dictionary) -> int:
	if budget.is_empty():
		return GameTuning.STATUS_REACTION_BUDGET_PER_FRAME
	return maxi(0, int(budget.get("cap", GameTuning.STATUS_REACTION_BUDGET_PER_FRAME))
		- int(budget.get("used", 0)))


## 전이·전파 이벤트가 이 깊이에서 나올 수 있는가(§4.7 규칙 4: 깊이 1).
static func can_propagate(depth: int) -> bool:
	return depth < GameTuning.STATUS_PROPAGATION_DEPTH


## 전이 k번째 도약의 피해. 호출자와 테스트가 **같은 식**을 쓰게 하려고 여기 둔다.
## hop_index 0 = 첫 전이 대상.
static func chain_damage(event: Dictionary, hop_index: int) -> float:
	var base := float(event.get("amount", 0.0))
	var falloff := clampf(float(event.get("falloff", 0.0)), 0.0, 1.0)
	return base * pow(1.0 - falloff, float(maxi(0, hop_index)))


# =============================================================================
# 9. apply() — 매트릭스 본체
# =============================================================================
# 반환:
#   state       : 인자로 받은 **바로 그 배열**(복사본이 아니다. 제자리 갱신).
#   events      : Array[Dictionary]. 위 이벤트 어휘 참조. 순서대로 실행하면 된다.
#   reactions   : Array[String]. 발동한 반응 키. HUD 라벨은 REACTION_LABELS로 뽑는다.
#   applied     : 이번에 부여/갱신된 상태 이름("" = 없음. strike·psi가 그렇다).
#   range_bonus : 증기가 낸 **이번 타격**의 범위 보정(0.0 또는 SYN_STEAM_RANGE_BONUS).
#   cost        : 이번 호출이 먹은 반응 예산.
#   suppressed  : 예산·깊이로 잘려 나간 질의 이벤트 수(`--stress-test`가 본다).
#
# ctx: damage(0.0) · potency(1.0) · depth(0) · budget({}) · stack_bonus(1.0, 독 행 전용)
static func apply(state: Array, element: String, power: float = 1.0, ctx: Dictionary = {}) -> Dictionary:
	var events: Array[Dictionary] = []
	var reactions: Array[String] = []
	var out: Dictionary = {
		"state": state,
		"events": events,
		"reactions": reactions,
		"applied": "",
		"range_bonus": 0.0,
		"cost": 0,
		"suppressed": 0
	}
	if state.size() != FIELD_COUNT:
		return out
	var p := potency_damage(ctx)
	var strength := maxf(0.0, power)
	var depth := maxi(0, int(ctx.get("depth", 0)))
	var budget: Dictionary = ctx.get("budget", {})
	match element:
		# stack_bonus는 독 행 하나만 읽는 채널이다. 하한이 1.0이라 키가 없으면
		# 지금까지와 똑같이 스택이 1씩 오른다. 한정한 이유는 `_row_poison()` 주석 참조.
		"poison": _row_poison(state, strength, p, maxf(1.0, float(ctx.get("stack_bonus", 1.0))), out)
		"fire": _row_fire(state, strength, p, depth, budget, out)
		"ice": _row_ice(state, strength, p, out)
		"thunder": _row_thunder(state, strength, p, depth, budget, out)
		"oil": _row_oil(state, strength, p, out)
		"strike": _row_strike(state, strength, p, out)
		"psi": _row_psi(state, strength, p, out)
		_: pass
	return out


## 상태를 바꾸지 않고 "지금 이 원소를 꽂으면 무엇이 터지는가"만 본다.
## 5칸 레일의 인접 반응 화살표(§4.8)와 combat_resolver의 선(先)조회가 쓴다.
static func preview(state: Array, element: String, power: float = 1.0, ctx: Dictionary = {}) -> Dictionary:
	var probe := ctx.duplicate()
	probe.erase("budget")
	var result := apply(state.duplicate(), element, power, probe)
	return {
		"reactions": result.get("reactions", []),
		"range_bonus": float(result.get("range_bonus", 0.0)),
		"incoming_mul": incoming_multiplier(state, element),
		"next_hit_mul": next_hit_multiplier(state)
	}


# ------------------------------------------------------------------ 행: 독(毒)
# (없음) 독 부여 / 독 스택 +stack_bonus(기본 1) / 한 독 지속 +50%. 나머지 열은 상호작용 없음.
#
# `stack_bonus`는 이미 독이 붙어 있는 적에게 독을 덧씌울 때 스택이 몇 칸 오르는지다.
# 호출자가 `ctx["stack_bonus"]`로 넣어 주며 `apply()`가 하한 1.0으로 잘라 넘긴다.
# 근거는 FEEDBACK_Y §4.5 — `cross_cut`의 콤보 "독을 두 배로 쌓는다"를 실제로 굴리는
# 통로다. 값을 넣는 카드가 아직 없으므로 지금은 언제나 1.0이고, 그래서 이 채널이
# 생기기 전과 결과가 완전히 같다.
#
# ⚠️ 이건 AGENTS.md §12가 `card_status_power()`를 두고 미뤄 둔 것과 **같은 범주의 축**이다.
#    카드마다 상태 세기를 흩뿌리면 V10이 그 함수가 1.0이라는 전제로 확정한 보스 HP 표를
#    다섯 마리 다 다시 재야 한다. 그래서 여기서는 **카드 1장(`cross_cut`) · 독 한 갈래**로만
#    연다. 움직이는 것이 독 스택 하나뿐이라 파급을 `balance_probe` ⑫로 그대로 잴 수 있다는
#    것이 이 한정의 근거다. 다른 카드나 다른 상태로 넓히려면 ⑫를 먼저 다시 돌릴 것.
#    같은 축에 걸려 있는 **한(chill) 강화 계수는 여전히 열지 않는다**(`_row_ice()` 주석 참조).
#
# 카드 쪽 배선 — `combat_resolver`가 카드의 `status_stack_bonus` 키를 `ctx`에 실어
# 넘기는 일 — 은 **후속 웨이브 몫**이다. 이번 변경은 `combat_resolver.gd`를 건드리지
# 않았고, 그래서 지금 이 채널을 쓰는 호출자가 하나도 없다.
static func _row_poison(state: Array, power: float, p: float, stack_bonus: float,
		out: Dictionary) -> void:
	var unit := GameTuning.POISON_DOT_PER_STACK * p * power
	if state[F_POISON_TIME] > 0.0:
		state[F_POISON_STACKS] = minf(state[F_POISON_STACKS] + stack_bonus,
			float(GameTuning.POISON_STACK_MAX))
		state[F_POISON_UNIT] = maxf(state[F_POISON_UNIT], unit)
		state[F_POISON_TIME] = maxf(state[F_POISON_TIME], GameTuning.POISON_DURATION)
		_note(out, R_POISON_STACK)
	else:
		# 첫 부여는 언제나 1스택이다. §4.5가 바꾸라고 한 것은 덧씌우는 쪽뿐이고,
		# 여기까지 열면 "쌓아서 터뜨린다"의 시작점이 카드마다 달라진다.
		state[F_POISON_TIME] = GameTuning.POISON_DURATION
		state[F_POISON_STACKS] = 1.0
		state[F_POISON_UNIT] = unit
		_note(out, R_POISON_APPLY)
	# 적용할 때마다 감쇠 시계를 되감는다. "축적 → 터뜨린다"(§4.2)가 성립하려면
	# 쌓는 동안에는 줄지 않아야 한다. 지속 상한(6초)이 여전히 전체를 묶는다.
	state[F_POISON_DECAY] = GameTuning.POISON_STACK_DECAY_INTERVAL
	if state[F_CHILL_TIME] > 0.0:
		_extend_poison(state)
		_note(out, R_FROZEN_VENOM)
	out["applied"] = "poison"


# ------------------------------------------------------------------ 행: 화(火)
# 유(대폭 연소★) → 독(역병 발화) → 한(증기) → 연 부여/갱신.
static func _row_fire(state: Array, power: float, p: float, depth: int,
		budget: Dictionary, out: Dictionary) -> void:
	var burn_power := power
	var burn_duration := GameTuning.BURN_DURATION
	# ★ 대폭 연소 — 기름 소모, 연 power ×3 · 지속 ×2.5 · 반경 130에 oil 전파(깊이 1)
	if state[F_OIL_TIME] > 0.0:
		state[F_OIL_TIME] = 0.0
		burn_power *= GameTuning.SYN_BLAZE_POWER_MUL
		burn_duration *= GameTuning.SYN_BLAZE_DURATION_MUL
		_note(out, R_BLAZE)
		_emit(out, budget, depth, {
			"kind": E_SPREAD_STATUS,
			"reaction": R_BLAZE,
			"status": "oil",
			"radius": GameTuning.SYN_BLAZE_OIL_SPREAD_RADIUS,
			"duration": GameTuning.OIL_DURATION,
			"power": power,
			"depth": depth + 1
		})
	# 역병 발화 — 스택 전부 소모, 반경 90에 1.2 × P × stacks 즉발
	if state[F_POISON_TIME] > 0.0 and state[F_POISON_STACKS] > 0.0:
		var burst_stacks: float = state[F_POISON_STACKS]
		_clear_poison(state)
		_note(out, R_PLAGUE_IGNITION)
		_emit(out, budget, depth, {
			"kind": E_AOE_DAMAGE,
			"reaction": R_PLAGUE_IGNITION,
			"amount": GameTuning.SYN_PLAGUE_IGNITION_PER_STACK * p * burst_stacks,
			"radius": GameTuning.SYN_PLAGUE_IGNITION_RADIUS,
			"stacks": burst_stacks
		})
	# 증기 — 한 해제, 이번 타격 범위 +50% (v2 `fire>ice` 계승)
	if state[F_CHILL_TIME] > 0.0:
		_clear_chill(state)
		_note(out, R_STEAM)
		out["range_bonus"] = float(out["range_bonus"]) + GameTuning.SYN_STEAM_RANGE_BONUS
		_emit(out, budget, depth, {
			"kind": E_RANGE_BONUS,
			"reaction": R_STEAM,
			"range_bonus": GameTuning.SYN_STEAM_RANGE_BONUS
		})
	# 연 부여 / 갱신 — 갱신은 절대 하향하지 않는다(대폭 연소가 붙은 연에 맨 불이
	# 겹쳤다고 위력이 떨어지면 순서 보상이 무너진다).
	_note(out, R_BURN_REFRESH if state[F_BURN_TIME] > 0.0 else R_BURN_APPLY)
	state[F_BURN_TIME] = maxf(state[F_BURN_TIME], burn_duration)
	state[F_BURN_UNIT] = maxf(state[F_BURN_UNIT], GameTuning.BURN_DOT * p * burn_power)
	out["applied"] = "burn"


# ------------------------------------------------------------------ 행: 빙(氷)
# 독(지속 +50%) → 연(해제) → 한 부여/갱신.
static func _row_ice(state: Array, power: float, p: float, out: Dictionary) -> void:
	if state[F_POISON_TIME] > 0.0:
		_extend_poison(state)
		_note(out, R_FROZEN_VENOM)
	if state[F_BURN_TIME] > 0.0:
		_clear_burn(state)
		_note(out, R_QUENCH)
	_note(out, R_CHILL_REFRESH if state[F_CHILL_TIME] > 0.0 else R_CHILL_APPLY)
	state[F_CHILL_TIME] = maxf(state[F_CHILL_TIME], GameTuning.CHILL_DURATION)
	# "한 갱신·**강화**"(§4.4). 설계·V3-L 어디에도 강화 계수가 없으므로 숫자를 지어내지
	# 않고 "하향하지 않는 max"로 구현했다. 계수가 정해지면 여기 한 줄만 바뀐다.
	#
	# ── V10 판정(2026-08-09 · handoff-v1 §V10 #1): **계수를 만들지 않는다.** ──
	# 이 줄이 지금 no-op인 진짜 이유는 계수가 없어서가 아니라 **`power`가 언제나 1.0**
	# 이기 때문이다(`combat_resolver.card_status_power()`). `maxf(x, 1.0)`은 첫 부여에서
	# 이미 1.0을 넣으므로 두 번째 한은 지속만 갱신한다. 즉 "한 강화"는 카드별 상태 세기
	# 축이 생기기 전에는 **정의 자체가 불가능하다.** 그 축을 만들지 않기로 한 판정과
	# 근거는 `card_status_power()` 주석에 있다(요지: 상태 레이어는 계수 없이도 보스전
	# 피해의 14~43%를 내고 있고, 지금 축을 넣으면 V10이 확정한 보스 HP 표가 무효가 된다).
	# 둘은 **한 항목**이다. 되살리려면 반드시 같이 되살릴 것.
	state[F_CHILL_POWER] = maxf(state[F_CHILL_POWER], clampf(power, 0.0, 1.0))
	out["applied"] = "chill"


# ------------------------------------------------------------------ 행: 뇌(雷)
# 한(전도★) → 유(감전 유막) → 전 부여/갱신.
static func _row_thunder(state: Array, power: float, p: float, depth: int,
		budget: Dictionary, out: Dictionary) -> void:
	# ★ 전도 — 반경 260 내 **chill 상태 적**에게만 전이. 최대 4체, 도약당 −20%.
	# 1차 대상의 한은 소모하지 않는다(설계가 해제를 지시하지 않았다 — 증기·쇄빙만
	# 해제한다). 그래서 "빙으로 깔고 뇌를 반복"이 성립한다(§4.6 빌드 ②).
	if state[F_CHILL_TIME] > 0.0:
		_note(out, R_CONDUCTION)
		_emit(out, budget, depth, {
			"kind": E_CHAIN_DAMAGE,
			"reaction": R_CONDUCTION,
			"amount": GameTuning.SYN_CONDUCTION_DAMAGE * p,
			"radius": GameTuning.SYN_CONDUCTION_RADIUS,
			"max_targets": GameTuning.SYN_CONDUCTION_MAX_TARGETS,
			"falloff": GameTuning.SYN_CONDUCTION_FALLOFF,
			"filter": "chill",
			"apply_status": "shock",
			"depth": depth + 1
		})
	# 감전 유막 — 기름 소모, 반경 160에 0.8 × P + 전 표식
	if state[F_OIL_TIME] > 0.0:
		state[F_OIL_TIME] = 0.0
		_note(out, R_OILED_SHOCK)
		_emit(out, budget, depth, {
			"kind": E_AOE_DAMAGE,
			"reaction": R_OILED_SHOCK,
			"amount": GameTuning.SYN_OILED_SHOCK_DAMAGE * p,
			"radius": GameTuning.SYN_OILED_SHOCK_RADIUS,
			"apply_status": "shock"
		})
	_note(out, R_SHOCK_REFRESH if state[F_SHOCK_TIME] > 0.0 else R_SHOCK_APPLY)
	state[F_SHOCK_TIME] = maxf(state[F_SHOCK_TIME], GameTuning.SHOCK_DURATION)
	out["applied"] = "shock"


# ------------------------------------------------------------------ 행: 유(油)
# 연(불에 기름 ×2) → 유 부여/갱신. 자체 피해는 0이다.
static func _row_oil(state: Array, power: float, _p: float, out: Dictionary) -> void:
	if state[F_BURN_TIME] > 0.0:
		state[F_BURN_UNIT] *= GameTuning.SYN_OIL_ON_BURN_POWER_MUL
		_note(out, R_GREASED_FLAME)
	_note(out, R_OIL_REFRESH if state[F_OIL_TIME] > 0.0 else R_OIL_APPLY)
	state[F_OIL_TIME] = maxf(state[F_OIL_TIME], GameTuning.OIL_DURATION)
	out["applied"] = "oil"


# ------------------------------------------------------------------ 행: 타(打)
# 상태를 만들지 않고 **거둬들인다**(§4.4 설계 의도 1). 독(터뜨리기) → 한(쇄빙).
static func _row_strike(state: Array, _power: float, p: float, out: Dictionary) -> void:
	if state[F_POISON_TIME] > 0.0 and state[F_POISON_STACKS] > 0.0:
		state[F_POISON_STACKS] = maxf(0.0, state[F_POISON_STACKS] - float(GameTuning.SYN_DETONATE_STACKS))
		if state[F_POISON_STACKS] <= 0.0:
			_clear_poison(state)
		_note(out, R_DETONATE)
		out["events"].append({
			"kind": E_DAMAGE,
			"reaction": R_DETONATE,
			"label": String(REACTION_LABELS.get(R_DETONATE, "")),
			"amount": GameTuning.SYN_DETONATE_DAMAGE * p
		})
	if state[F_CHILL_TIME] > 0.0:
		_clear_chill(state)
		_note(out, R_SHATTER)
		out["events"].append({
			"kind": E_KNOCKBACK,
			"reaction": R_SHATTER,
			"label": String(REACTION_LABELS.get(R_SHATTER, "")),
			"knockback_mul": GameTuning.SYN_SHATTER_KNOCKBACK_MUL,
			"stun": GameTuning.SYN_SHATTER_STUN
		})


# ------------------------------------------------------------------ 행: 초(超)
# 정신 붕괴 — 모든 상태의 남은 지속을 30% 즉시 소모하고, 소모한 총 초 × 0.5 × P를
# 단일 대상 즉발. 스택은 건드리지 않는다(설계가 "남은 지속"만 말한다).
static func _row_psi(state: Array, _power: float, p: float, out: Dictionary) -> void:
	var ratio := clampf(GameTuning.SYN_PSI_DRAIN_RATIO, 0.0, 1.0)
	var drained := 0.0
	for index: int in [F_POISON_TIME, F_BURN_TIME, F_CHILL_TIME, F_OIL_TIME, F_SHOCK_TIME]:
		if state[index] <= 0.0:
			continue
		var taken: float = state[index] * ratio
		state[index] -= taken
		drained += taken
	if drained <= 0.0:
		return
	_note(out, R_PSI_COLLAPSE)
	out["events"].append({
		"kind": E_DAMAGE,
		"reaction": R_PSI_COLLAPSE,
		"label": String(REACTION_LABELS.get(R_PSI_COLLAPSE, "")),
		"amount": drained * GameTuning.SYN_PSI_DRAIN_DAMAGE_PER_SECOND * p,
		"drained_seconds": drained
	})


# ------------------------------------------------------------------- 내부 도구

static func _note(out: Dictionary, reaction: String) -> void:
	out["reactions"].append(reaction)


## 질의 이벤트를 예산·깊이 검사 후 실어 보낸다. 잘리면 suppressed만 오른다.
static func _emit(out: Dictionary, budget: Dictionary, depth: int, event: Dictionary) -> void:
	var kind := String(event.get("kind", ""))
	if kind in PROPAGATING_EVENTS and not can_propagate(depth):
		out["suppressed"] = int(out["suppressed"]) + 1
		return
	if kind in QUERY_EVENTS and not budget.is_empty():
		var used := int(budget.get("used", 0))
		var cap := int(budget.get("cap", GameTuning.STATUS_REACTION_BUDGET_PER_FRAME))
		if used >= cap:
			out["suppressed"] = int(out["suppressed"]) + 1
			return
		budget["used"] = used + 1
	if kind in QUERY_EVENTS:
		out["cost"] = int(out["cost"]) + 1
	event["label"] = String(REACTION_LABELS.get(String(event.get("reaction", "")), ""))
	out["events"].append(event)


## 독 지속 +50%(냉기가 독을 가둔다). 반복 적용으로 무한히 늘지 않게 기본 지속의
## (1 + 보너스)배에서 자른다 — 새 상수를 만들지 않고 상한을 만드는 유일한 방법이다.
static func _extend_poison(state: Array) -> void:
	var bonus := GameTuning.SYN_POISON_ON_CHILL_DURATION_BONUS
	var cap := GameTuning.POISON_DURATION * (1.0 + bonus)
	state[F_POISON_TIME] = minf(state[F_POISON_TIME] * (1.0 + bonus), cap)


static func _clear_poison(state: Array) -> void:
	state[F_POISON_TIME] = 0.0
	state[F_POISON_STACKS] = 0.0
	state[F_POISON_UNIT] = 0.0
	state[F_POISON_DECAY] = 0.0


static func _clear_burn(state: Array) -> void:
	state[F_BURN_TIME] = 0.0
	state[F_BURN_UNIT] = 0.0


static func _clear_chill(state: Array) -> void:
	state[F_CHILL_TIME] = 0.0
	state[F_CHILL_POWER] = 0.0


# =============================================================================
# 10. tick() — 감쇠와 도트 (§4.3 틱 0.25s · §4.7 규칙 1·2)
# =============================================================================
# 시간은 **STATUS_TICK 경계로 잘린 슬라이스**로 흐른다. 슬라이스 길이는
# `min(남은 delta, STATUS_TICK − 누적)`이라 delta를 어떻게 쪼개 넣어도 결과가 같다
# (1.0초 1회 == 0.25초 4회 == 1/60초 60회). 이것이 결정성 요구의 실체다.
#
# 타이머는 슬라이스마다 **정확히 그 길이만큼** 줄어든다(양자화하지 않는다). 반면
# 피해는 0.25초 경계에서만 나온다 = §4.7 규칙 2의 버퍼. 그래서 `tick_dot()`이
# 0보다 큰 값을 돌려주는 순간에만 `take_damage`를 부르면 78기 × 4회/초가 된다.
#
# 경계 규칙: 한 슬라이스 안에서 상태가 만료되어도 **그 슬라이스의 틱은 지급된다.**
# 이게 없으면 독 6초가 24틱이 아니라 23틱이 되어 §4.3 검산이 어긋난다.

## 제로 할당 핫 패스. `enemy._physics_process`가 이걸 부른다.
## 반환 = 이번 호출에서 확정된 도트 총량(0이면 `take_damage`를 부르지 말 것).
static func tick_dot(state: Array, delta: float) -> float:
	if state.size() != FIELD_COUNT:
		return 0.0
	if not has_any(state):
		state[F_TICK_ACCUM] = 0.0
		return 0.0
	var dot := 0.0
	var left := clampf(delta, 0.0, GameTuning.STATUS_TICK * float(MAX_SLICES_PER_CALL))
	var guard := 0
	while left > TIME_EPS:
		guard += 1
		if guard > MAX_SLICES_PER_CALL + 2:
			break
		var room: float = GameTuning.STATUS_TICK - state[F_TICK_ACCUM]
		if room <= TIME_EPS:
			state[F_TICK_ACCUM] = 0.0
			room = GameTuning.STATUS_TICK
		var step: float = minf(left, room)
		left -= step
		# 슬라이스 **시작 시점**의 도트를 기억한다(경계 규칙).
		var poison_before := 0.0
		if state[F_POISON_TIME] > 0.0:
			poison_before = state[F_POISON_UNIT] * state[F_POISON_STACKS]
		var burn_before := 0.0
		if state[F_BURN_TIME] > 0.0:
			burn_before = state[F_BURN_UNIT]
		_decay(state, step)
		state[F_TICK_ACCUM] += step
		if state[F_TICK_ACCUM] >= GameTuning.STATUS_TICK - TIME_EPS:
			state[F_TICK_ACCUM] = 0.0
			dot += poison_before + burn_before
		if not has_any(state):
			break
	return dot


## 도구·테스트용 래퍼. 만료된 상태 목록까지 알려 준다(핍 재그리기 판단에 쓸 수 있다).
## 핫 패스에서는 Dictionary 할당이 아까우므로 `tick_dot()`을 쓸 것.
static func tick(state: Array, delta: float) -> Dictionary:
	var before := active_list(state)
	var dot := tick_dot(state, delta)
	var after := active_list(state)
	var expired: Array[String] = []
	for status: String in before:
		if not after.has(status):
			expired.append(status)
	return {"state": state, "dot": dot, "expired": expired, "active": after}


## 한 슬라이스만큼 모든 타이머를 줄이고 스택 감쇠를 처리한다.
static func _decay(state: Array, step: float) -> void:
	if state[F_POISON_TIME] > 0.0:
		state[F_POISON_TIME] = maxf(0.0, state[F_POISON_TIME] - step)
		state[F_POISON_DECAY] -= step
		while state[F_POISON_DECAY] <= TIME_EPS and state[F_POISON_STACKS] > 0.0:
			state[F_POISON_STACKS] -= 1.0
			state[F_POISON_DECAY] += GameTuning.POISON_STACK_DECAY_INTERVAL
		if state[F_POISON_TIME] <= 0.0 or state[F_POISON_STACKS] <= 0.0:
			_clear_poison(state)
	if state[F_BURN_TIME] > 0.0:
		state[F_BURN_TIME] = maxf(0.0, state[F_BURN_TIME] - step)
		if state[F_BURN_TIME] <= 0.0:
			_clear_burn(state)
	if state[F_CHILL_TIME] > 0.0:
		state[F_CHILL_TIME] = maxf(0.0, state[F_CHILL_TIME] - step)
		if state[F_CHILL_TIME] <= 0.0:
			_clear_chill(state)
	if state[F_OIL_TIME] > 0.0:
		state[F_OIL_TIME] = maxf(0.0, state[F_OIL_TIME] - step)
	if state[F_SHOCK_TIME] > 0.0:
		state[F_SHOCK_TIME] = maxf(0.0, state[F_SHOCK_TIME] - step)
