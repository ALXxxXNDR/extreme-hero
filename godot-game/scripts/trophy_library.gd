class_name TrophyLibrary
extends RefCounted

# =============================================================================
# V2 — 보스 트로피 (v3 · `class_library.gd`를 대체한다)
# =============================================================================
# 기준: docs/GAME_DESIGN_V3.md §5.5 · 부록 A-1 ⑥ · 부록 A-2 ⑳ · 부록 B V2 ⑤
#
# v2의 계보(BRANCHES 3종)와 각성 2단계는 **폐기됐다**(사용자 요구, 부록 A-1 ⑥).
# 그러나 그 아래 있던 자산은 하나도 버리지 않는다:
#   * SPECIALS 12종            → **보스 트로피 카드**로 살아남는다(계보 색만 지웠다).
#   * `advancement_choice` 상태 → **트로피 2택1 UI**로 그대로 재사용.
#   * `player._apply_class_effect()` → 함수 본문 무변경. **입력 딕셔너리만** 여기서 온다.
# 폐기했다면 전부 다시 만들어야 하는 것들이다.
#
# ── 보스 트로피의 규칙 (§5.5) ────────────────────────────────────────────────
#   보스를 격파하면 플레이어는 두 가지를 한꺼번에 받는다.
#     ① **중립 스탯 보너스 1개 — 고정.** 선택지가 아니다. 스테이지가 정한다.
#     ② **특별 카드 2택1.** 고른 쪽은 내 레일에, **버린 쪽은 마왕에게** 간다.
#        (미선택은 전부 마왕에게 — v2부터 이어지는 불변 원칙, 부록 A-1 ⑨)
#   5회 × 2장 = 10장이 쓰이고 12종 중 2장이 예비로 남는다(§5.5의 "거의 다 소진").
#
# ── 소유권 경계 ──────────────────────────────────────────────────────────────
#   * `class_library.gd`는 **삭제됐다**(V10 · 2026-08-09). V8이 데이터를 전부 걷어내고
#     `by_id()` 한 함수짜리 shim만 남겨 뒀는데, 그 shim의 유일한 소비자였던
#     `core/combat_resolver.gd`의 검격 색 두 줄이 V10에서 `TrophyLibrary.by_id()`를
#     직접 부르게 되면서 참조가 0이 됐다. 원본 3판은 `docs/v1-archive/`에 있다.
#   * 카드 데이터 자체는 `deal_card_library.SPECIALS`가 소유한다. 이 파일은 **id만** 든다.
#     preload로 묶지 않은 이유도 같다 — 배분표가 카드 데이터를 끌고 들어오면
#     standalone 데이터 테스트가 무거워진다. 교차 검증은 data_test가 한다.
#   * 보스 패턴·스프라이트는 `boss_library.gd`, 로테이션은 `GameTuning.STAGE_BOSS_*`.

## 트로피를 주는 횟수 = 스테이지 수. 5회 전부 지급되면 배분표가 소진된다.
const TROPHY_COUNT := 5
## 한 번에 제시하는 선택지 수. v2 `advancement_choice`의 2택1을 그대로 쓴다.
const CHOICES_PER_TROPHY := 2

# -----------------------------------------------------------------------------
# 스테이지별 트로피 5종
# -----------------------------------------------------------------------------
# `effect`는 `player._apply_class_effect()`가 읽는 것과 **정확히 같은 스키마**다
# (damage / damage_mul / range / speed / health / pickup / crit / pierce / ricochet /
#  shield / rollback / projectile / orbit / life_on_kill / interval_mul / holy_pulse).
# v2의 `tier1_effect` / `tier2_effect`가 쓰던 키 집합 그대로이고, 값만 계보 색을 지우고
# 스테이지 곡선으로 다시 깔았다. **5개가 전부 누적된다**는 전제로 크기를 잡았다.
#
# `choices` 2장은 언제나 **서로 다른 원소**다. 그래야 2택1이 "어느 쪽이 세냐"가 아니라
# "내 5칸이 지금 어느 원소를 원하냐"라는 질문이 된다(§3.8 결속·공명과 맞물린다).
#
# `grade`: "greater" = SPECIALS의 1차 각성분(6종) / "legend" = 2차 각성분(`tier2`, 6종).
# 스테이지 1~3이 greater, 4~5가 legend다. 보스 로테이션의 강화형(B+·C+) 등장 시점과
# 정확히 겹친다 — 강화 보스는 전설 트로피를 떨군다.
const TROPHIES: Array[Dictionary] = [
	{
		"stage": 1, "id": "trophy_frost_eye", "name": "서릿발 외눈의 뿔",
		"boss_design": "A", "grade": "greater", "color": "67c7d4",
		"desc": "얼어붙은 외눈에서 뽑아낸 뿔. 쥐고 있으면 살갗이 차갑게 단단해진다.",
		"effect": {"health": 24.0, "shield": 1},
		"effect_desc": "최대 체력 +24 · 수호막 +1",
		"choices": ["holy_verdict", "crimson_loop"]
	},
	{
		"stage": 2, "id": "trophy_plague_core", "name": "역병 점액왕의 핵",
		"boss_design": "B", "grade": "greater", "color": "83c65c",
		"desc": "분열해도 끝내 하나로 남던 핵. 벤 자리에서 힘을 되돌려 받는다.",
		"effect": {"damage": 6.0, "life_on_kill": 1.5},
		"effect_desc": "피해 +6 · 처치마다 체력 +1.5",
		"choices": ["dragon_pierce", "pain_compiler"]
	},
	{
		"stage": 3, "id": "trophy_crimson_plume", "name": "홍염 천구의 깃",
		"boss_design": "C", "grade": "greater", "color": "e78a45",
		"desc": "타고도 재가 되지 않은 깃털. 검이 닿는 거리가 늘어난다.",
		"effect": {"damage_mul": 1.12, "range": 34.0},
		"effect_desc": "전체 피해 ×1.12 · 사거리 +34",
		"choices": ["echo_thrust", "aegis_process"]
	},
	{
		# YZ: 표시명만 「응결핵」 → 「굳은 핵」. id는 trophy_black_nucleus 그대로다.
		"stage": 4, "id": "trophy_black_nucleus", "name": "흑점액의 굳은 핵",
		"boss_design": "B+", "grade": "legend", "color": "bd6ac8",
		"desc": "두 번 변이한 점액이 마지막에 남긴 굳은 핵. 급소를 보는 눈이 밝아진다.",
		"effect": {"health": 34.0, "crit": 0.08, "pierce": 1},
		"effect_desc": "최대 체력 +34 · 치명타 +8% · 관통 +1",
		"choices": ["red_moon_execution", "sky_dragon_array"]
	},
	{
		"stage": 5, "id": "trophy_black_tengu_heart", "name": "흑천구의 심장",
		"boss_design": "C+", "grade": "legend", "color": "d95763",
		"desc": "다섯 관문의 마지막 파수꾼이 품고 있던 심장. 마왕의 문 앞에서 뛴다.",
		"effect": {"damage": 12.0, "damage_mul": 1.15, "projectile": 1, "shield": 1},
		"effect_desc": "피해 +12 · 전체 피해 ×1.15 · 투사체 +1 · 수호막 +1",
		"choices": ["heavens_gate", "immortal_frenzy"]
	}
]

# -----------------------------------------------------------------------------
# 예비 트로피 카드 2종
# -----------------------------------------------------------------------------
# SPECIALS 12종 중 배분표가 쓰지 않는 2장이다. **버리지 않는 이유**: 플레이어가
# 이미 가진 카드가 선택지에 다시 뜨면 2택1이 1택이 된다(전조 회수·마왕 탈환 경로로
# 특별 카드가 손에 들어올 수 있다). 그때 이 둘로 갈아끼운다.
# 배분 규칙 자체는 V8이 배선할 때 확정한다 — 여기서는 후보만 못 박아 둔다.
const RESERVE_CHOICES: Array[String] = ["zero_damage_oath", "infinite_recursion"]

# -----------------------------------------------------------------------------
# 조회
# -----------------------------------------------------------------------------

static func all() -> Array[Dictionary]:
	return TROPHIES.duplicate(true)

## 스테이지(1~5) → 트로피 1건. 범위 밖이면 빈 딕셔너리.
static func for_stage(stage: int) -> Dictionary:
	for trophy: Dictionary in TROPHIES:
		if int(trophy["stage"]) == stage:
			return trophy.duplicate(true)
	return {}

static func by_id(id: String) -> Dictionary:
	for trophy: Dictionary in TROPHIES:
		if String(trophy["id"]) == id:
			return trophy.duplicate(true)
	return {}

## 이 스테이지의 2택1 카드 id. `advancement_choice` 모달이 이걸 그대로 편다.
static func choices_for(stage: int) -> Array[String]:
	var ids: Array[String] = []
	var trophy := for_stage(stage)
	for entry in (trophy.get("choices", []) as Array):
		ids.append(String(entry))
	return ids

## 이 스테이지의 **고정** 중립 스탯 보너스. `player._apply_class_effect()`에 그대로 넘긴다.
static func effect_for(stage: int) -> Dictionary:
	return (for_stage(stage).get("effect", {}) as Dictionary).duplicate(true)

## 지금까지 획득한 트로피 효과를 하나로 합친 딕셔너리.
## 곱연산 키(`damage_mul` / `interval_mul`)는 곱하고 나머지는 더한다.
## 저장 키 `trophy_effects`(§9)를 복원할 때 이 함수 하나로 스탯을 다시 세운다.
static func merge_effects(stages: Array) -> Dictionary:
	var merged: Dictionary = {}
	for entry in stages:
		var effect := effect_for(int(entry))
		for key_value in effect.keys():
			var key := String(key_value)
			var value: Variant = effect[key_value]
			if key == "damage_mul" or key == "interval_mul":
				merged[key] = float(merged.get(key, 1.0)) * float(value)
			elif value is bool:
				merged[key] = bool(merged.get(key, false)) or bool(value)
			elif value is int:
				merged[key] = int(merged.get(key, 0)) + int(value)
			else:
				merged[key] = float(merged.get(key, 0.0)) + float(value)
	return merged

## 배분표가 쓰는 특별 카드 id 10종(순서 = 스테이지 순 · 선택지 순).
static func used_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for trophy: Dictionary in TROPHIES:
		for entry in (trophy["choices"] as Array):
			ids.append(String(entry))
	return ids

## 배분표 + 예비 = 특별 카드 12종 전량이어야 한다.
static func all_card_ids() -> Array[String]:
	var ids := used_card_ids()
	ids.append_array(RESERVE_CHOICES)
	return ids

static func grade_name(grade: String) -> String:
	match grade:
		"legend": return "전설 트로피"
		"greater": return "상급 트로피"
		_: return "트로피"

## 배분표 자체의 정합성. data_test가 매 실행마다 단언한다.
##   ① 트로피가 정확히 TROPHY_COUNT개, stage가 1~5 중복 없이 전부
##   ② 선택지가 트로피마다 정확히 CHOICES_PER_TROPHY장
##   ③ 배분 + 예비 = 12장이고 **id 중복 0**
##   ④ effect가 비어 있지 않다(고정 보너스가 없는 트로피는 없다)
static func table_ok() -> bool:
	if TROPHIES.size() != TROPHY_COUNT:
		return false
	var seen_stage: Dictionary = {}
	for trophy: Dictionary in TROPHIES:
		var stage := int(trophy["stage"])
		if stage < 1 or stage > TROPHY_COUNT or seen_stage.has(stage):
			return false
		seen_stage[stage] = true
		if (trophy["choices"] as Array).size() != CHOICES_PER_TROPHY:
			return false
		if (trophy["effect"] as Dictionary).is_empty():
			return false
	var seen_card: Dictionary = {}
	for id: String in all_card_ids():
		if seen_card.has(id):
			return false
		seen_card[id] = true
	return seen_card.size() == 12
