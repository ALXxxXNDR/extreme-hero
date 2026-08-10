class_name RuneEngine
extends RefCounted

# =============================================================================
# Y0 — 순수 각인 규칙 엔진 (극딜 용사 v4)
# =============================================================================
# 설계 정본: docs/FEEDBACK_Y.md §1 전체 · §2 전체.
# v3(각인 24종 + 과열) 원본은 docs/v1-archive/rune_engine_v3_24.gd.txt 에 보존.
#
# 이 파일의 계약
#   * **순수하다.** 노드·씬·시그널·전역 상태·시간(`Time`, `randf()`)을 만지지 않는다.
#     모든 무작위성은 호출자가 주입한 시드에서 나온다 → 같은 입력이면 같은 궤적.
#   * **엔진은 게임을 모른다.** 카드는 Dictionary 한 장으로만 본다
#     (`damage`/`reload`/`duration`/`element`/`form`).
#   * `simulate_cycle()`은 런타임(DealCycleController)과 편집 미리보기가 **같은 함수**를 쓴다.
#
# ## Y0에서 바뀐 것 (§0 결정 ①·②)
#   * **과열 폐기.** 확률 감쇠·피해 보너스·RELOAD 페널티·재진입 감쇠·잔열이 전부 사라졌다.
#     그 자리를 규칙 한 줄이 대신한다 — **"한 칸은 한 바퀴에 두 번까지만 밟는다."**
#   * **각인 24종 → 15종** (칸 10 + 레일 5). `scope` 키가 둘을 가른다.
#   * 종료성이 확률이 아니라 **산수로** 증명된다. 아래 증명을 참조.
#
# ## 종료성 증명 (§1.3)
#   E = Σᵢ executed[i] 라 두자.
#   ① 메인 루프 한 바퀴는 executed[cursor]를 정확히 1 올린다 → E는 매 반복 정확히 1 증가.
#   ② 루프 진입 시점의 불변식: `executed[cursor] < SLOT_EXEC_CAP`.
#      - 최초 진입: executed[0] = 0 < 2.
#      - 앙코르 경로(`continue`): 분기 조건 자체가 `executed[cursor] < SLOT_EXEC_CAP`이다.
#      - 이동 경로(`cursor = raw`): 건너뛰기 스캔이 `executed[raw] < SLOT_EXEC_CAP`을 보장한다.
#      따라서 항상 executed[i] ≤ SLOT_EXEC_CAP.
#   ③ 그러므로 E ≤ SLOT_EXEC_CAP × n = 2n 이고, ①에 의해 **반복 횟수 ≤ 2n**. ∎
#   5칸이면 최대 10스텝. STEP_CAP(12)은 이제 게임 규칙이 아니라 **방어 단언**이고
#   `end_reason == "overload"`는 몬테카를로에서 **0건**이어야 한다(새 회귀 계약).
#
# ## 구 API 셔틀 — **Y8(2026-08-10)에 전부 은퇴했다**
# Y0는 game.gd 컴파일을 살리려고 과열 심볼을 값만 중립으로 만들어 남겼다. Y2가
# 게임 코드 소비자 0을 전수 확인했고(handoff-y2 §7), Y8이 `balance_probe` 재작성과
# **한 커밋에서** 실제로 지웠다. 자세한 목록과 남긴 둘의 이유는 아래 블록에 있다.

# ------------------------------------------------------------------ 흐름 상수
const SLOT_COUNT := 5                 # 칸 수 상한. 실제 덱 길이는 deck.size()를 따른다
const START_SLOTS := 3                # 시작 개방 칸 수
const RUNE_SLOTS_PER_SLOT := 3        # "과밀 없이" 담기는 각인 수
const SLOT_EXEC_CAP := 2              # ★ 새 핵심 규칙 — 한 칸은 한 바퀴에 두 번까지
const STEP_CAP := 2 * SLOT_COUNT + 2  # = 12. 게임 규칙이 아니라 **방어 단언**(도달 0건)
const RELOAD_CAP := 6.0               # RELOAD 상한(초)
const P_CAP := 0.75                   # 최종 발동 확률 상한 (확정 발동 금지)
const RAIL_RUNE_CAP := 3              # 레일에 붙는 각인 총 개수
const RAIL_SAME_ID_CAP := 1           # 레일 각인은 중복 불가

# --------------------------------------------------- 부록 C-1: 한 칸 중복 강화
# 칸 감쇠 4겹은 **값 그대로 유지**한다(§2.4). 실행 상한이 무한 루프를 막고,
# 이 넷이 한 칸 몰빵을 막는다 — 역할이 겹치지 않는다.
#   ① RUNE_STACK_CAP     : 한 칸에 붙는 각인 총 개수 하드 상한
#   ② SAME_ID_STACK_CAP  : 같은 id 사본 개수 하드 상한
#   ③ DUP_P_FALLOFF      : 같은 id k번째 사본의 확률 기여가 0.55^(k-1)로 감쇠
#   ④ CONGESTION_FALLOFF : RUNE_SLOTS_PER_SLOT(3)을 넘긴 칸은 그 칸의 **모든** 확률에
#                          0.80^(초과수) 페널티
# DUP_MAG_FALLOFF가 수치형 각인의 중복 이득을 0.60^(k-1)로 깎고, 이동형 각인(delta)은
# **중복해도 delta가 커지지 않는다**(확률만 오른다).
const RUNE_STACK_CAP := 5
const SAME_ID_STACK_CAP := 3
const DUP_P_FALLOFF := 0.55
const DUP_MAG_FALLOFF := 0.60
const CONGESTION_FALLOFF := 0.80

# --------------------------------------------------------- 배치 규칙 · 반응 수치
const RESONANCE_DAMAGE := 0.15        # 인접 두 칸 같은 원소 → 두 칸 모두 피해 +15% (§1.4 유지)
const TWIN_POWER := 0.5               # 쌍둥이(twin_cast): 앞 칸 기술을 절반 세기로
const OVERCHARGE_POTENCY_MULT := 1.3  # 화→뇌 과충전: **의미 교체** — 상태 위력 ×1.3 (§1.4)
const STEAM_RANGE_BONUS := 0.5        # 화→빙 증기: 범위 +50%
const SHOCK_SPLASH := 0.35            # 빙→뇌 감전: 광역 추가타 위력
const IGNITE_POTENCY_MULT := 1.5      # 유→화 인화: 이 칸의 상태 위력 ×1.5
const PLAGUE_POTENCY_MULT := 1.3      # 독→화 역병 발화 준비: 상태 위력 ×1.3
const SHATTER_PREP_STUN := 0.2        # 빙→타 쇄빙 준비: 경직 +0.2초
const RESONANT_DRAIN_RELOAD := 0.15   # *→초 공명 흡수: RELOAD −0.15초(빚에서 차감)

# ------------------------------------------------------------- 레일 각인 수치
const RAIL_FAST_DURATION := 0.15      # 빨리 감기: 모든 칸 duration ×(1 − 0.15)
const RAIL_POWER_DAMAGE := 0.12       # 모두 힘주기: 모든 칸 피해 +12%
const RAIL_REST_RELOAD := 0.20        # 짧은 휴식: 한 바퀴 RELOAD ×(1 − 0.20)
const RAIL_COLOR_DAMAGE := 0.25       # 같은 색 보너스: 공명이 성립한 칸에 +25% **가산**

# =============================================================================
# 과열 셔틀 — **Y8(2026-08-10)이 전부 삭제했다**
# =============================================================================
# Y0가 남긴 15개 상수(`HEAT_MAX`·`HEAT_DECAY`·`HEAT_DAMAGE`·`HEAT_RELOAD`·
# `REENTRY_FALLOFF`·`HEAT_GATE_MIN`·`BOND_MIN_RUN`·`BOND_FIRE_COST`·
# `TRIANGLE_RELOAD_DISCOUNT`·`OVERCHARGE_HEAT_BONUS`·`REPEAT_CAP`·`ECHO_POWER`·
# `CHORUS_POWER`·`OVERLAP_POWER`·`LINK_POWER`)와 함수 4개(`heat_from_load()`·
# `damage_multiplier()`·`bond_mask()`·`triangle_ok()`), 결과 셔틀 키 5종
# (`heat_curve`·`peak_heat`·`end_heat`·`carry_heat`·`deviation_load`)이 함께 사라졌다.
#
# 삭제 근거는 handoff-y2 §7의 전수 조사다 — **게임 코드 소비자가 0**이었고, 남은
# 참조는 `rune_test`의 `heat_neutral` 묶음 · `data_test`의 `rune_heat_neutral` 묶음 ·
# `balance_probe`의 echo/chorus/link 재현 코드 셋뿐이었다. y2가 "Y8이 balance_probe를
# 재작성할 때 한 커밋에서 같이 지우라"고 적었고, 이 파일이 그 커밋이다.
#
# **되살아나면 안 되는 것을 지금 무엇이 지키는가**: 셔틀이 사라졌으므로 "중립인지"를
# 재는 검사도 함께 은퇴했다. 대신 종료성 계약(`SLOT_EXEC_CAP` 2 · `STEP_CAP` 12 ·
# 몬테카를로 `overload` 0건)이 `rune_test`·`data_test`에 그대로 남아 있고, 과열이
# 뒷문으로 돌아오려면 그 계약을 먼저 깨야 한다.
#
# ⚠️ 남긴 것 둘 — 이유가 있다.
#   * `effective_probability(base_p, deviation_load, congestion)`의 **두 번째 인자**.
#     `game.gd:3045`가 3인자로 부른다. 시그니처를 줄이면 그 파일이 컴파일 단계에서
#     깨지고 game.gd는 Y8 소유가 아니다. 인자는 여전히 무시되고, 그 사실을
#     `rune_test`의 `p_cap` 묶음이 문다(구 `heat_neutral`에서 옮겨 왔다).
#   * 결과 키 `overloaded`. 이것은 과열이 아니라 **STEP_CAP 방어 단언의 결과**이고
#     `game.gd:3004`·`deal_cycle_controller.gd:324`가 실제로 읽는다(도달 0건이 계약).

# 방어적 무한 루프 가드. 위 종료성 증명이 step_count ≤ 2n을 보장하므로 이 값에
# 걸리는 것은 **엔진 버그**다. 걸리면 end_reason="guard"로 남아 테스트가 잡는다.
const HARD_LOOP_GUARD := STEP_CAP * 8

# ------------------------------------------------------------------- 태그 어휘
# v3 원소 7계. **배열 순서에 의미가 있다.** 앞 5개 = 생산자, 뒤 2개 = 소비자.
# 이 순서는 `deal_card_library.ELEMENTS`와 **배열 동등**해야 하며 data_test가 대조한다.
const ELEMENTS: Array[String] = ["fire", "ice", "thunder", "poison", "oil", "strike", "psi"]
# `form` 데이터는 남긴다 — 저장·아이콘·미래 대비(§1.4). **게임 규칙 소비자만 0이다.**
const FORMS: Array[String] = ["slash", "pierce", "wave", "trap", "guard"]

# L1 덱 레벨 원소 반응 7쌍. key = "이전원소>현재원소".
# **L1은 직접 피해를 주지 않는다** — 범위·RELOAD·상태 위력(potency)·경직뿐이다.
const REACTIONS: Dictionary = {
	"ice>thunder": "shock",         # 감전 — 광역 추가타 +35%
	"fire>ice": "steam",            # 증기 — 범위 +50%
	"fire>thunder": "overcharge",   # 과충전 — Y0에서 의미 교체: 상태 위력 ×1.3
	"oil>fire": "ignite",           # 인화 — 이 칸의 상태 위력 ×1.5
	"poison>fire": "plague_prime",  # 역병 발화 준비 — 상태 위력 ×1.3
	"ice>strike": "shatter_prep",   # 쇄빙 준비 — 경직 +0.2초
	"*>psi": "resonant_drain"       # 공명 흡수 — RELOAD −0.15초
}

## `*>원소` 와일드카드 키의 접두사. `reaction_of()`가 정확 일치 다음에 이걸 찾는다.
const REACTION_WILDCARD := "*"

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"

# =============================================================================
# 각인 카탈로그 — 15종 (§2.1 칸 10 + §2.2 레일 5)
# =============================================================================
# 필드
#   scope  : "slot" | "rail"   ← Y0 신설. 레일 각인은 칸이 아니라 레일 전체가 소유한다.
#   family : flow | parallel | conditional | tempo | combat
#   roll   : true면 확률 각인. false면 확정/패시브.
#   p_min/p_max : 드래프트 시 이 범위에서 굴려 인스턴스 확률을 정한다.
#                 **p를 코드에 직접 박지 않는다**(§2.1 도입부). 확정 각인은 둘 다 1.0.
#   mag_min/mag_max : 효과 크기 범위. 고정인 각인은 둘 다 같은 값.
#   cond   : always | first | reentry | kill | prev_slot | prev_same_element
#            (Y8: `heat_gate` 분기 삭제 — 그 cond를 쓰는 각인이 15종에 하나도 없다)
#            조건 불충족이면 **굴리지도 않는다**.
#
# 계약 3개 (테스트가 대조한다)
#   ① 정확히 15개 키.
#   ② 레어리티 분포 일반 6 · 희귀 6 · 영웅 3.
#   ③ family == "flow"는 정확히 twice·back_one·jump_one·trade_skip·finisher·rail_loop
#      6종 — §2.6 흐름 할증(RUNE_SHOP_FLOW_PREMIUM 1.25) 대상과 일치해야 한다.
const RUNES: Dictionary = {
	# ================= 칸 각인 10종 (§2.1) =================================
	"twice": {
		"id": "twice", "name": "두 번 치기", "scope": "slot",
		"family": "flow", "cond": "always",
		"effect": "이 칸이 한 번 더 터진다.", "roll": true,
		"p_min": 0.35, "p_max": 0.60, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_COMMON
	},
	"back_one": {
		"id": "back_one", "name": "한 칸 뒤로", "scope": "slot",
		"family": "flow", "cond": "always",
		"effect": "이 칸 다음에 한 칸 되돌아간다.", "roll": true,
		"p_min": 0.30, "p_max": 0.55, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_COMMON
	},
	"jump_one": {
		"id": "jump_one", "name": "한 칸 건너뛰기", "scope": "slot",
		"family": "flow", "cond": "always",
		"effect": "다음 칸을 건너뛰고 그다음 칸으로 간다.", "roll": true,
		"p_min": 0.35, "p_max": 0.60, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_COMMON
	},
	"strong": {
		"id": "strong", "name": "힘주기", "scope": "slot",
		"family": "combat", "cond": "always",
		"effect": "이 칸 피해가 늘어난다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0, "mag_min": 0.25, "mag_max": 0.40,
		"rarity": RARITY_COMMON
	},
	"wide": {
		"id": "wide", "name": "넓히기", "scope": "slot",
		"family": "combat", "cond": "always",
		"effect": "이 칸 범위가 넓어진다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0, "mag_min": 0.20, "mag_max": 0.35,
		"rarity": RARITY_COMMON
	},
	"quick": {
		"id": "quick", "name": "서두르기", "scope": "slot",
		"family": "tempo", "cond": "always",
		"effect": "이 칸은 쉬는 시간을 만들지 않는다.", "roll": true,
		"p_min": 0.40, "p_max": 0.65, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_RARE
	},
	"first_hit": {
		"id": "first_hit", "name": "첫 칸 힘", "scope": "slot",
		"family": "conditional", "cond": "first",
		"effect": "이번 바퀴에 처음 밟는 칸이면 피해가 크게 는다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0, "mag_min": 0.50, "mag_max": 0.80,
		"rarity": RARITY_RARE
	},
	"twin_cast": {
		"id": "twin_cast", "name": "쌍둥이", "scope": "slot",
		"family": "parallel", "cond": "prev_slot",
		"effect": "앞 칸 기술도 절반 힘으로 같이 터진다.", "roll": true,
		"p_min": 0.40, "p_max": 0.65, "mag_min": TWIN_POWER, "mag_max": TWIN_POWER,
		"rarity": RARITY_RARE
	},
	"trade_skip": {
		"id": "trade_skip", "name": "두 번 치고 건너뛰기", "scope": "slot",
		"family": "flow", "cond": "always",
		"effect": "이 칸이 두 번 터지고, 대신 다음 칸을 건너뛴다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_EPIC
	},
	"finisher": {
		"id": "finisher", "name": "마무리", "scope": "slot",
		"family": "flow", "cond": "kill",
		"effect": "이 칸으로 적을 쓰러뜨리면 한 번 더 터진다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_EPIC
	},

	# ================= 레일 각인 5종 (§2.2) =================================
	# 레일 각인은 칸이 아니라 **레일 전체**가 소유한다. 칸을 교환해도 따라가지 않고,
	# 붙일 칸을 고르지 않는다. `simulate_cycle(opts["rail_runes"])`로 주입된다.
	"rail_fast": {
		"id": "rail_fast", "name": "빨리 감기", "scope": "rail",
		"family": "tempo", "cond": "always",
		"effect": "모든 칸이 조금 빨리 끝난다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0,
		"mag_min": RAIL_FAST_DURATION, "mag_max": RAIL_FAST_DURATION,
		"rarity": RARITY_COMMON
	},
	"rail_power": {
		"id": "rail_power", "name": "모두 힘주기", "scope": "rail",
		"family": "combat", "cond": "always",
		"effect": "모든 칸 피해가 조금 는다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0,
		"mag_min": RAIL_POWER_DAMAGE, "mag_max": RAIL_POWER_DAMAGE,
		"rarity": RARITY_RARE
	},
	"rail_rest": {
		"id": "rail_rest", "name": "짧은 휴식", "scope": "rail",
		"family": "tempo", "cond": "always",
		"effect": "한 바퀴의 쉬는 시간이 줄어든다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0,
		"mag_min": RAIL_REST_RELOAD, "mag_max": RAIL_REST_RELOAD,
		"rarity": RARITY_RARE
	},
	"rail_color": {
		# YZ: 표시 이름만 「같은 색 보너스」 → 「같은 색 덤」. id는 rail_color 그대로다.
		"id": "rail_color", "name": "같은 색 덤", "scope": "rail",
		"family": "combat", "cond": "always",
		"effect": "같은 색이 옆에 붙어 있는 칸은 피해가 는다.", "roll": false,
		"p_min": 1.0, "p_max": 1.0,
		"mag_min": RAIL_COLOR_DAMAGE, "mag_max": RAIL_COLOR_DAMAGE,
		"rarity": RARITY_RARE
	},
	"rail_loop": {
		"id": "rail_loop", "name": "되돌이", "scope": "rail",
		"family": "flow", "cond": "always",
		"effect": "마지막 칸을 지나면 거꾸로 한 바퀴 더 돈다.", "roll": true,
		"p_min": 0.45, "p_max": 0.65, "mag_min": 1.0, "mag_max": 1.0,
		"rarity": RARITY_EPIC
	}
}

# 이동(delta)을 만드는 각인. **"정상 다음 칸 대비 오프셋"**으로 재정의했다(Y0).
# 이동식이 `move = 1 + delta`라서
#   back_one  → move = -1 → cursor - 1  = "바로 앞 칸"      (§2.1 3번 문구와 일치)
#   jump_one  → move = +2 → cursor + 2  = "다음 칸을 건너뜀" (§2.1 4번 문구와 일치)
# 중복해도 delta가 커지지 않는 대상이기도 하다(확률만 오른다).
const FLOW_DELTA: Dictionary = {"back_one": -2, "jump_one": 1}

# =============================================================================
# 카드 / 칸 / 덱 — 부록 C-1의 데이터 모델
# =============================================================================
# **칸(slot) 객체가 각인 스택을 소유한다.** 칸 위치 교환은 배열 원소를 통째로 바꾸는
# 것이므로 각인이 칸과 함께 따라간다. 카드만 옮기는 조작(move_card)은 `card` 필드만
# 교환하므로 각인은 제자리에 남는다.
#
# slot := {"card": Dictionary, "runes": Array[Dictionary]}
# rune instance := {"id": String, "p": float, "mag": float}
# rail rune instance := 같은 모양. 덱이 아니라 opts["rail_runes"]로 들어온다.

const DEFAULT_CARD: Dictionary = {
	"id": "basic", "damage": 1.0, "reload": 0.18, "duration": 0.72,
	"element": "", "form": ""
}

static func make_slot(card: Dictionary = {}, runes: Array = []) -> Dictionary:
	var resolved: Dictionary = DEFAULT_CARD.duplicate(true)
	for key in card.keys():
		resolved[key] = card[key]
	var stack: Array = []
	for inst in runes:
		stack.append((inst as Dictionary).duplicate(true))
	return {"card": resolved, "runes": stack}

static func make_deck(slots: Array) -> Array:
	var deck: Array = []
	for entry in slots:
		var slot: Dictionary = entry
		deck.append(make_slot(slot.get("card", {}), slot.get("runes", [])))
	return deck

## 칸 위치 교환 — 각인이 칸과 함께 이동한다 (부록 C-1).
static func swap_slots(deck: Array, a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= deck.size() or b >= deck.size() or a == b:
		return false
	var tmp: Variant = deck[a]
	deck[a] = deck[b]
	deck[b] = tmp
	return true

## 카드만 교환 — 각인은 원래 칸에 남는다 (부록 C-1의 [카드 이동]).
static func move_card(deck: Array, a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= deck.size() or b >= deck.size() or a == b:
		return false
	var slot_a: Dictionary = deck[a]
	var slot_b: Dictionary = deck[b]
	var tmp: Variant = slot_a["card"]
	slot_a["card"] = slot_b["card"]
	slot_b["card"] = tmp
	return true

static func same_id_count(slot: Dictionary, id: String) -> int:
	var n := 0
	for inst in (slot.get("runes", []) as Array):
		if String((inst as Dictionary).get("id", "")) == id:
			n += 1
	return n

## 각인의 소유 범위. 정의에 없으면 "slot"으로 본다(구 저장 호환).
static func rune_scope(id: String) -> String:
	if not RUNES.has(id):
		return ""
	return String((RUNES[id] as Dictionary).get("scope", "slot"))

## 칸 각인 부착. 상한(총 개수·같은 id 개수)을 넘거나 **레일 각인**이면 false.
static func attach_rune(slot: Dictionary, inst: Dictionary) -> bool:
	var id := String(inst.get("id", ""))
	if not RUNES.has(id):
		return false
	if rune_scope(id) != "slot":
		return false           # 레일 각인은 칸에 붙지 않는다(§2.2)
	var stack: Array = slot.get("runes", [])
	if stack.size() >= RUNE_STACK_CAP:
		return false
	if same_id_count(slot, id) >= SAME_ID_STACK_CAP:
		return false
	stack.append(inst.duplicate(true))
	slot["runes"] = stack
	return true

## 드래프트: 확률·크기를 범위 안에서 굴려 각인 **인스턴스**를 만든다.
static func roll_rune(id: String, rng: RandomNumberGenerator) -> Dictionary:
	if not RUNES.has(id):
		return {}
	var def: Dictionary = RUNES[id]
	var p: float = float(def["p_min"])
	if float(def["p_max"]) > float(def["p_min"]):
		p = rng.randf_range(float(def["p_min"]), float(def["p_max"]))
	var mag: float = float(def["mag_min"])
	if float(def["mag_max"]) > float(def["mag_min"]):
		mag = rng.randf_range(float(def["mag_min"]), float(def["mag_max"]))
	return {"id": id, "p": p, "mag": mag}

static func all_rune_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in RUNES.keys():
		ids.append(id)
	return ids

static func ids_by_rarity(rarity: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in RUNES.keys():
		if String((RUNES[id] as Dictionary)["rarity"]) == rarity:
			ids.append(id)
	return ids

static func ids_by_family(family: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in RUNES.keys():
		if String((RUNES[id] as Dictionary)["family"]) == family:
			ids.append(id)
	return ids

## Y0 신설. `scope`로 카탈로그를 가른다(세공사 3택·레일 부착 화면이 쓴다).
static func ids_by_scope(scope: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in RUNES.keys():
		if rune_scope(id) == scope:
			ids.append(id)
	return ids

# =============================================================================
# 확률 규칙 — 전부 순수 함수. 편집 미리보기가 그대로 호출한다.
# =============================================================================

## 같은 id 사본들의 합성 확률. 여집합 곱 + k번째 사본 DUP_P_FALLOFF^(k-1) 감쇠.
static func merged_probability(instances: Array) -> float:
	var complement := 1.0
	for i in instances.size():
		var inst: Dictionary = instances[i]
		var p: float = clampf(float(inst.get("p", 0.0)) * pow(DUP_P_FALLOFF, i), 0.0, 1.0)
		complement *= (1.0 - p)
	return 1.0 - complement

## 같은 id 사본들의 합성 크기. k번째 사본은 DUP_MAG_FALLOFF^(k-1)만 기여한다.
static func merged_magnitude(instances: Array) -> float:
	var total := 0.0
	for i in instances.size():
		var inst: Dictionary = instances[i]
		total += float(inst.get("mag", 0.0)) * pow(DUP_MAG_FALLOFF, i)
	return total

## 과밀 페널티. 한 칸에 RUNE_SLOTS_PER_SLOT을 넘겨 담으면 그 칸 전체 확률이 깎인다.
static func congestion_scale(rune_count: int) -> float:
	return pow(CONGESTION_FALLOFF, float(maxi(0, rune_count - RUNE_SLOTS_PER_SLOT)))

## 최종 발동 확률. 순서: 합성 → 과밀 → P_CAP 클램프.
## `deviation_load`는 **무시된다**(과열 감쇠 폐기). 인자만 남은 이유는 파일 상단 ⚠️ 참조.
static func effective_probability(base_p: float, deviation_load: float, congestion: float) -> float:
	var _load_ignored := deviation_load
	return clampf(base_p * congestion, 0.0, P_CAP)

## 조건 각인의 조건 판정. false면 굴리지도 않는다.
static func condition_ok(cond: String, ctx: Dictionary) -> bool:
	match cond:
		"always":
			return true
		"first":
			# 이번 바퀴에 **처음 밟는 칸**이다(§2.1 first_hit).
			return int(ctx.get("reentry", 0)) == 0
		"reentry":
			return int(ctx.get("reentry", 0)) > 0
		"kill":
			return bool(ctx.get("killed", false))
		"prev_slot":
			return int(ctx.get("prev_index", -1)) >= 0
		"prev_same_element":
			var prev := String(ctx.get("prev_element", ""))
			var here := String(ctx.get("element", ""))
			return prev != "" and prev == here
		_:
			return true

# =============================================================================
# 태그 상호작용 — 순수 판정
# =============================================================================

static func slot_element(slot: Dictionary) -> String:
	return String((slot.get("card", {}) as Dictionary).get("element", ""))

static func slot_form(slot: Dictionary) -> String:
	return String((slot.get("card", {}) as Dictionary).get("form", ""))

## 인접 공명: 이웃한 칸이 같은 원소면 이 칸의 피해 +15%.
## §1.4에서 **유일하게 유지된** 배치 규칙 — 색이 나란히 보이므로 눈으로 계획할 수 있다.
static func resonance_bonus(deck: Array, index: int) -> float:
	var here := slot_element(deck[index])
	if here == "":
		return 0.0
	if index > 0 and slot_element(deck[index - 1]) == here:
		return RESONANCE_DAMAGE
	if index < deck.size() - 1 and slot_element(deck[index + 1]) == here:
		return RESONANCE_DAMAGE
	return 0.0

## 원소 반응 7쌍. 직전 실행 칸의 원소 → 이번 칸의 원소.
## 정확 일치를 먼저 보고, 없으면 `*>현재원소` 와일드카드를 본다(공명 흡수 전용).
static func reaction_of(prev_element: String, element: String) -> String:
	if prev_element == "" or element == "":
		return ""
	var key := "%s>%s" % [prev_element, element]
	if REACTIONS.has(key):
		return String(REACTIONS[key])
	return String(REACTIONS.get("%s>%s" % [REACTION_WILDCARD, element], ""))

## L1 반응의 한글 표기.
static func reaction_name(reaction: String) -> String:
	match reaction:
		"shock": return "감전"
		"steam": return "증기"
		# YZ: 표기만 우리말로 풀었다. 반응 키(overcharge…)는 그대로다.
		"overcharge": return "전기 넘침"
		"ignite": return "불붙음"
		"plague_prime": return "역병에 불붙기 직전"
		"shatter_prep": return "얼음 깨지기 직전"
		"resonant_drain": return "울림 빨아들이기"
		_: return ""

## 이 반응이 상태 위력(potency)에 곱하는 배율. 나머지 반응은 1.0이다.
## Y0: `overcharge`가 과열 +1을 잃고 **위력 ×1.3**으로 의미를 갈아탔다(§1.4 · 새 코드 0줄).
static func reaction_potency(reaction: String) -> float:
	match reaction:
		"ignite": return IGNITE_POTENCY_MULT
		"plague_prime": return PLAGUE_POTENCY_MULT
		"overcharge": return OVERCHARGE_POTENCY_MULT
		_: return 1.0

# =============================================================================
# 레일 각인 해석 — 사이클 시작에 **한 번**
# =============================================================================
# `rail_loop`의 확률 굴림은 사이클 시작 시 정확히 한 번이다. 바퀴 도중에 다시 굴리면
# 결정성(같은 시드 → 같은 궤적)이 깨지고, 편집 미리보기와 실전이 어긋난다.
#
# 반환
#   duration_mul : rail_fast → ×(1 − 0.15). 모든 칸 duration에 곱한다
#   damage_bonus : rail_power → +0.12. 모든 칸에 가산
#   reload_mul   : rail_rest → ×(1 − 0.20). 사이클 최종 RELOAD에 곱한다
#   color_bonus  : rail_color → +0.25. **공명이 성립한 칸에만** 가산
#   loop         : rail_loop의 p 굴림 결과. 이번 바퀴에 되돌이가 켜졌는가
#   fired        : 실제로 적용된 레일 각인 id 목록(rail_loop는 성공했을 때만 들어간다)
static func resolve_rail(rail_runes: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {
		"duration_mul": 1.0, "damage_bonus": 0.0, "reload_mul": 1.0,
		"color_bonus": 0.0, "loop": false, "fired": []
	}
	if rail_runes.is_empty():
		return out
	var seen: Dictionary = {}
	for entry in rail_runes:
		if not entry is Dictionary:
			continue
		var inst: Dictionary = entry
		var id := String(inst.get("id", ""))
		if not RUNES.has(id) or rune_scope(id) != "rail":
			continue
		if seen.has(id):
			continue                     # RAIL_SAME_ID_CAP = 1 (중복 불가)
		if seen.size() >= RAIL_RUNE_CAP:
			break
		seen[id] = true
		var def: Dictionary = RUNES[id]
		var mag := float(inst.get("mag", float(def["mag_min"])))
		match id:
			"rail_fast":
				out["duration_mul"] = float(out["duration_mul"]) * maxf(0.1, 1.0 - mag)
				(out["fired"] as Array).append(id)
			"rail_power":
				out["damage_bonus"] = float(out["damage_bonus"]) + mag
				(out["fired"] as Array).append(id)
			"rail_rest":
				out["reload_mul"] = float(out["reload_mul"]) * maxf(0.0, 1.0 - mag)
				(out["fired"] as Array).append(id)
			"rail_color":
				out["color_bonus"] = float(out["color_bonus"]) + mag
				(out["fired"] as Array).append(id)
			"rail_loop":
				var p := clampf(float(inst.get("p", float(def["p_min"]))), 0.0, P_CAP)
				if rng.randf() < p:
					out["loop"] = true
					(out["fired"] as Array).append(id)
	return out

# =============================================================================
# 각인 판정 — 순수 함수
# =============================================================================
# resolve(slot_runes, ctx, rng) -> {repeat, delta, damage_bonus, ...}
#
# ctx 필수 키: reentry(int) · element · prev_element · prev_index ·
#              killed(bool) · slot_index(int)
# (Y8: 과열 셔틀 4키 `deviation_load`·`heat`·`bond`·`bookmark`가 여기서 사라졌다.
#  호출자가 더 넣어 보내도 무시된다 — `resolve()`는 위 여섯 개만 읽는다.)
#
# 굴림 순서 = slot_runes의 부착 순서. 과열이 사라졌으므로 **칸 안 감쇠는 없다** —
# 한 칸 몰빵은 DUP_P_FALLOFF·CONGESTION_FALLOFF·SAME_ID_STACK_CAP이 막는다(§2.4).
static func resolve(slot_runes: Array, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {
		"repeat": 0, "delta": 0, "trade_skip": false,
		"fired": [], "fire_cost": 0.0, "fire_count": 0,
		"damage_bonus": 0.0, "damage_mult": 1.0, "range_bonus": 0.0,
		"pierce_bonus": 0, "duration_mult": 1.0, "debt_delta": 0.0,
		"free_reload": false, "twin_power": 0.0
	}
	if slot_runes.is_empty():
		return out

	var groups := _group_runes(slot_runes)
	var congestion := congestion_scale(slot_runes.size())

	for group: Dictionary in groups:
		var id := String(group["id"])
		var def: Dictionary = RUNES[id]
		var instances: Array = group["instances"]

		if not condition_ok(String(def["cond"]), ctx):
			continue

		var magnitude := merged_magnitude(instances)

		# 확정(패시브) 각인: 굴리지 않고 항상 적용.
		if not bool(def["roll"]):
			_apply_rune(out, id, magnitude, instances.size(), ctx)
			continue

		var base_p := merged_probability(instances)
		var p := effective_probability(base_p, 0.0, congestion)
		if rng.randf() >= p:
			continue

		out["fire_count"] = int(out["fire_count"]) + 1
		(out["fired"] as Array).append(id)
		_apply_rune(out, id, magnitude, instances.size(), ctx)

	return out

## 부착 순서를 유지하면서 같은 id를 묶는다. Dictionary가 삽입 순서를 보존하므로 결정적.
## 레일 각인이 칸 스택에 섞여 들어와도 여기서 걸러진다(방어).
static func _group_runes(slot_runes: Array) -> Array:
	var order: Array[String] = []
	var buckets: Dictionary = {}
	for entry in slot_runes:
		var inst: Dictionary = entry
		var id := String(inst.get("id", ""))
		if not RUNES.has(id) or rune_scope(id) != "slot":
			continue
		if not buckets.has(id):
			buckets[id] = []
			order.append(id)
		var bucket: Array = buckets[id]
		if bucket.size() >= SAME_ID_STACK_CAP:
			continue
		bucket.append(inst)
	var groups: Array = []
	for id in order:
		groups.append({"id": id, "instances": buckets[id]})
	return groups

static func _apply_rune(out: Dictionary, id: String, magnitude: float, copies: int, ctx: Dictionary) -> void:
	var _unused := copies + int(ctx.get("slot_index", 0))
	match id:
		# --- 흐름 ---
		"back_one", "jump_one":
			# 중복해도 delta는 커지지 않는다. 확률만 오른다(부록 C-1 감쇠 설계).
			out["delta"] = int(out["delta"]) + int(FLOW_DELTA[id])
		"twice", "finisher":
			out["repeat"] = int(out["repeat"]) + 1
		"trade_skip":
			# 앙코르 1회 + "다음 칸 건너뛰기" 1칸. **건너뛰기는 앙코르가 실제로
			# 소비될 때 한 번만** 발생한다(simulate_cycle의 이동 결정 1번 참조).
			# trade_skip은 확정 각인이라 두 번째 실행에서도 다시 적용되는데, 여기서
			# delta에 +1을 넣어 버리면 두 번째 실행의 move가 1 커져 **두 칸**을
			# 건너뛴다 — §2.1의 "다음 칸을 건너뛴다"와 어긋난다. 그래서 delta가
			# 아니라 플래그로 넘긴다.
			out["repeat"] = int(out["repeat"]) + 1
			out["trade_skip"] = true
		# --- 전투 / 조건 ---
		"strong", "first_hit":
			out["damage_bonus"] = float(out["damage_bonus"]) + magnitude
		"wide":
			out["range_bonus"] = float(out["range_bonus"]) + magnitude
		# --- 동시 ---
		"twin_cast":
			out["twin_power"] = float(out["twin_power"]) + magnitude
		# --- 템포 ---
		"quick":
			out["free_reload"] = true

## 칸에 붙은 확정(패시브) 각인 중 특정 id가 있으면 합성 크기를 돌려준다. 없으면 0.
static func passive_magnitude(slot: Dictionary, id: String) -> float:
	var instances: Array = []
	for entry in (slot.get("runes", []) as Array):
		var inst: Dictionary = entry
		if String(inst.get("id", "")) == id and instances.size() < SAME_ID_STACK_CAP:
			instances.append(inst)
	if instances.is_empty():
		return 0.0
	return merged_magnitude(instances)

# =============================================================================
# 한 사이클 시뮬레이션 — 런타임 · 편집 미리보기 공용
# =============================================================================
# simulate_cycle(deck, seed, opts) -> 실행 궤적 + 총피해 + RELOAD
#
# opts (전부 선택)
#   rail_runes   : Array[Dictionary]  레일 각인 인스턴스. 없으면 빈 배열 (Y0 신설)
#   kill_chance  : float  마무리(finisher) 조건 모델링용. 0이면 처치 없음
#   kills        : Array[bool]  결정적으로 처치 여부를 주고 싶을 때(런타임이 실제 값 주입)
#   reload_scale : float  보스전 등 외부 배율. 기본 1.0
#   direction    : int    시작 방향. 기본 +1
#   start_load   : float  DEPRECATED (Y0) — 잔열 폐기. 읽지 않는다
#
# ## 이동 결정 (§1.2 · Y0의 핵심)
#   1. 앙코르(twice 확률 / finisher 처치 / trade_skip 확정)를 먼저 소비한다.
#      **상한(SLOT_EXEC_CAP)에 걸린 칸의 앙코르는 조용히 버린다** — 커서를 그 칸에
#      묶어 두면 무한 루프가 되고, §1.2 규칙 3이 "발동 낭비가 눈에 보이면 안 된다"고 못박는다.
#   2~4. move = 1 + delta + carried_delta → raw = cursor + direction × move → 역방향 클램프
#   5. 진행 방향 이탈 → 되돌이(rail_loop) 1회 또는 종료
#   6. **건너뛰기 스캔** — 이미 두 번 밟은 칸은 진행 방향으로 건너뛴다(§1.2 규칙 1).
#      back_one/jump_one의 목적지가 이미 상한이어도 각인 발동 자체를 막을 필요가 없다.
#      스캔이 낭비를 흡수해 다음 가능 칸으로 보내기 때문이다.
#   7. 스캔이 범위를 벗어나면 되돌이 1회 또는 `all_used` 종료(§1.2 규칙 2)
static func simulate_cycle(deck: Array, cycle_seed: int, opts: Dictionary = {}) -> Dictionary:
	var n := deck.size()
	var result: Dictionary = {
		"steps": [], "step_count": 0, "damage_total": 0.0, "damage_mul_sum": 0.0,
		"fired": [], "fire_count": 0, "reload_debt": 0.0, "reload": 0.0,
		"end_reason": "empty", "visited": [], "reactions": [],
		"slot_exec": [], "rail_loop_armed": false, "rail_fired": [],
		# `overloaded`는 과열이 아니라 **STEP_CAP 방어 단언의 결과**다(도달 0건이 계약).
		# `game.gd:3004` · `deal_cycle_controller.gd:324`가 실제로 읽는다.
		"overloaded": false
	}
	if n <= 0:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = cycle_seed

	# 레일 각인은 **사이클 시작에 한 번**만 해석한다(결정성 보존).
	var rail := resolve_rail(opts.get("rail_runes", []) as Array, rng)
	var rail_duration_mul := float(rail["duration_mul"])
	var rail_damage_bonus := float(rail["damage_bonus"])
	var rail_color_bonus := float(rail["color_bonus"])
	var rail_loop := bool(rail["loop"])
	result["rail_loop_armed"] = rail_loop
	result["rail_fired"] = (rail["fired"] as Array).duplicate()

	var cursor := 0
	var direction := int(opts.get("direction", 1))
	if direction == 0:
		direction = 1
	var debt := 0.0
	var step_count := 0
	var repeats_left := 0
	var carried_delta := 0
	var prev_index := -1
	var loop_used := false
	var kill_chance := float(opts.get("kill_chance", 0.0))
	var kills: Array = opts.get("kills", [])
	var guard := 0

	var executed: Array[int] = []
	for _i in n:
		executed.append(0)

	while true:
		guard += 1
		if guard > HARD_LOOP_GUARD:
			result["end_reason"] = "guard"
			break

		# ---------------------------------------------------------- 스텝 실행
		# 불변식: 여기 도달했을 때 executed[cursor] < SLOT_EXEC_CAP 이다(파일 상단 증명 ②).
		var reentry := executed[cursor]
		executed[cursor] += 1
		step_count += 1

		var slot: Dictionary = deck[cursor]
		var card: Dictionary = slot.get("card", DEFAULT_CARD)
		var element := slot_element(slot)
		var prev_element := (slot_element(deck[prev_index]) if prev_index >= 0 else "")
		var reaction := reaction_of(prev_element, element)

		var killed := false
		if kills.size() > step_count - 1:
			killed = bool(kills[step_count - 1])
		elif kill_chance > 0.0:
			killed = rng.randf() < kill_chance

		var ctx: Dictionary = {
			"reentry": reentry, "element": element, "prev_element": prev_element,
			"prev_index": prev_index, "killed": killed, "slot_index": cursor
		}
		var r := resolve(slot.get("runes", []), ctx, rng)

		# ------------------------------------------------------------ 피해 계산
		# 과열 보너스와 재진입 감쇠가 **둘 다 사라졌다**(§1.4). 기저 배율은 1.0이다 —
		# "두 번 발동한다"가 약속인데 두 번째가 약하면 거짓말이 되기 때문.
		var resonance := resonance_bonus(deck, cursor)
		var damage_mul := 1.0
		if resonance > 0.0:
			# rail_color(같은 색 보너스)는 **공명이 성립한 칸에만** 가산된다(§2.2).
			damage_mul *= (1.0 + resonance + rail_color_bonus)
		if rail_damage_bonus != 0.0:
			# rail_power(모두 힘주기)는 모든 칸에 가산된다.
			damage_mul *= (1.0 + rail_damage_bonus)
		damage_mul *= (1.0 + float(r["damage_bonus"]))
		damage_mul *= float(r["damage_mult"])

		var base_damage := float(card.get("damage", 1.0))
		var step_damage := base_damage * damage_mul

		# 쌍둥이(twin_cast): 앞 칸 기술도 절반 세기로 같이 터진다.
		if float(r["twin_power"]) > 0.0 and prev_index >= 0:
			var twin_card: Dictionary = (deck[prev_index] as Dictionary).get("card", DEFAULT_CARD)
			step_damage += float(twin_card.get("damage", 1.0)) * damage_mul * float(r["twin_power"])
		if reaction == "shock":
			step_damage += base_damage * damage_mul * SHOCK_SPLASH

		# ------------------------------------------------------------ 빚 누적
		# 서두르기(quick)가 켜진 칸은 그 칸의 reload를 빚에 더하지 않는다.
		if not bool(r["free_reload"]):
			debt += float(card.get("reload", 0.0))
		debt += float(r["debt_delta"])
		if reaction == "resonant_drain":
			debt -= RESONANT_DRAIN_RELOAD
		debt = maxf(0.0, debt)

		var range_bonus := float(r["range_bonus"])
		if reaction == "steam":
			range_bonus += STEAM_RANGE_BONUS

		# 상태 위력(potency) — combat_resolver가 상태를 부여할 때 곱한다.
		# **여기서 피해를 만들지 않는다.**
		var potency := reaction_potency(reaction)
		var stun_bonus := (SHATTER_PREP_STUN if reaction == "shatter_prep" else 0.0)

		# ------------------------------------------------------------ 궤적 기록
		# Y8: 과열 셔틀 키 4종(`heat`·`bond`·`reverse`·`link`)이 여기서 사라졌다.
		# 넷 다 리포지토리 전체에서 소비자가 0이었다(handoff-y2 §7 전수 조사).
		var step_record: Dictionary = {
			"index": step_count - 1, "slot": cursor, "card_id": String(card.get("id", "")),
			"reentry": reentry, "damage_mul": damage_mul,
			"damage": step_damage, "direction": direction,
			"duration": float(card.get("duration", 0.0)) * float(r["duration_mult"]) * rail_duration_mul,
			"fired": (r["fired"] as Array).duplicate(),
			"delta": int(r["delta"]), "repeat": int(r["repeat"]),
			"range_bonus": range_bonus, "pierce_bonus": int(r["pierce_bonus"]),
			"reaction": reaction, "debt": debt,
			"element": element, "prev_element": prev_element,
			"potency": potency, "stun_bonus": stun_bonus
		}
		(result["steps"] as Array).append(step_record)
		(result["visited"] as Array).append(cursor)
		if reaction != "":
			(result["reactions"] as Array).append(reaction)
		for id in (r["fired"] as Array):
			(result["fired"] as Array).append(id)
		result["damage_total"] = float(result["damage_total"]) + step_damage
		result["damage_mul_sum"] = float(result["damage_mul_sum"]) + damage_mul
		result["fire_count"] = int(result["fire_count"]) + int(r["fire_count"])

		prev_index = cursor

		# 방어 단언. 위 종료성 증명이 step_count ≤ 2n = 10을 보장하므로 STEP_CAP(12)
		# 도달은 **엔진 버그**다. 몬테카를로 도달 0건이 새 회귀 계약이다(§1.3).
		if step_count >= STEP_CAP:
			result["end_reason"] = "overload"
			result["overloaded"] = true
			break

		# ---------------------------------------------------------- 이동 결정
		# 1) 앙코르
		# Y8: 구 `REPEAT_CAP`(2) 자리에 `SLOT_EXEC_CAP`(같은 값 2)을 넣었다.
		# 관측 동등이다 — 아래 `executed[cursor] < SLOT_EXEC_CAP` 게이트가 어차피
		# 앙코르를 한 번으로 자르므로 이 클램프의 값이 2든 3이든 궤적이 같다.
		if repeats_left == 0 and int(r["repeat"]) > 0:
			repeats_left = mini(int(r["repeat"]), SLOT_EXEC_CAP)
		if repeats_left > 0:
			if executed[cursor] < SLOT_EXEC_CAP:
				repeats_left -= 1
				carried_delta += int(r["delta"])   # 흐름 각인의 이동분은 이월된다
				if bool(r["trade_skip"]):
					carried_delta += 1             # "대신 다음 칸을 건너뛴다"
				continue                            # 커서 유지 → 같은 칸을 한 번 더
			repeats_left = 0                        # 상한 도달 → 조용히 버린다(§1.2 규칙 3)

		# 2)
		var move := 1 + int(r["delta"]) + carried_delta
		carried_delta = 0
		# 3)
		var raw := cursor + direction * move
		# 4) 역방향 클램프 — 진행 방향의 반대편으로 넘친 것은 끝이 아니라 벽이다
		if direction > 0 and raw < 0:
			raw = 0
		elif direction < 0 and raw > n - 1:
			raw = n - 1

		# 5) 진행 방향 이탈
		var ended := false
		if direction > 0 and raw > n - 1:
			if rail_loop and not loop_used:
				loop_used = true
				direction = -1
				raw = n - 1
			else:
				result["end_reason"] = "complete"
				ended = true
		elif direction < 0 and raw < 0:
			result["end_reason"] = "complete"
			ended = true
		if ended:
			break

		# 6·7) 건너뛰기 스캔 (+ 되돌이 재시도는 loop_used가 최대 1회로 묶는다)
		while true:
			while raw >= 0 and raw < n and executed[raw] >= SLOT_EXEC_CAP:
				raw += direction
			if raw >= 0 and raw < n:
				break
			if direction > 0 and rail_loop and not loop_used:
				loop_used = true
				direction = -1
				raw = n - 1
				continue
			result["end_reason"] = "all_used"
			ended = true
			break
		if ended:
			break

		# 8)
		cursor = raw

	# ------------------------------------------------------------- 사이클 종료
	# RELOAD 최종식 — 과열 항이 소멸했다. 빚은 밟은 칸 수에 **선형**이다(§1.4).
	# 과부하 시 RELOAD를 상한으로 올리던 벌칙은 삭제했다 — 상한이 규칙이 됐으므로
	# 도달은 벌칙이 아니다(§1.4). RELOAD_CAP은 "긴 바퀴의 벌칙 상한"으로 유지된다.
	var reload := debt * float(rail["reload_mul"]) * float(opts.get("reload_scale", 1.0))
	reload = clampf(reload, 0.0, RELOAD_CAP)

	result["step_count"] = step_count
	result["reload_debt"] = debt
	result["reload"] = reload
	result["slot_exec"] = executed.duplicate()
	if String(result["end_reason"]) == "empty":
		result["end_reason"] = "complete"
	return result

## 궤적 지문. 시드 결정성 검증과 편집 미리보기 캐시 키에 쓴다.
static func trace_signature(cycle: Dictionary) -> String:
	var parts: Array[String] = []
	for entry in (cycle.get("steps", []) as Array):
		var step: Dictionary = entry
		parts.append("%d:%d:%.4f:%s" % [
			int(step["slot"]), int(step["reentry"]),
			float(step["damage_mul"]), ",".join(step["fired"] as Array)
		])
	parts.append("R%.4f" % float(cycle.get("reload", 0.0)))
	return "|".join(parts)

## 편집 화면 요약. 칸을 옮길 때마다 이걸 다시 부르면 된다.
## `mean_exec_slots` = 한 바퀴에 **한 번이라도 밟은 칸의 평균 개수**(Y0 신설).
## `mean_steps`(총 실행 횟수)와 짝을 이뤄 "몇 칸을 / 몇 번" 밟았는지 갈라 보여 준다.
static func preview(deck: Array, cycle_seed: int, samples: int = 64, opts: Dictionary = {}) -> Dictionary:
	var steps_sum := 0.0
	var damage_sum := 0.0
	var reload_sum := 0.0
	var exec_slots_sum := 0.0
	var count := maxi(1, samples)
	for i in count:
		var cycle := simulate_cycle(deck, cycle_seed + i, opts)
		steps_sum += float(cycle["step_count"])
		damage_sum += float(cycle["damage_total"])
		reload_sum += float(cycle["reload"])
		for used in (cycle["slot_exec"] as Array):
			if int(used) > 0:
				exec_slots_sum += 1.0
	return {
		"samples": count,
		"mean_steps": steps_sum / float(count),
		"mean_damage": damage_sum / float(count),
		"mean_reload": reload_sum / float(count),
		"mean_exec_slots": exec_slots_sum / float(count)
	}
