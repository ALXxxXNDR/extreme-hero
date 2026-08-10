class_name DemonLord
extends RefCounted

# =============================================================================
# 마왕 성장 모델 — 데이터 계층 (W4, 설계 §6)
# =============================================================================
# "당신이 버린 카드는 전부 마왕의 다섯 칸이 된다."
# 이 파일은 그 문장의 **상태**만 소유한다. 실제 전투 실행(5칸 딜싸이클을 돌리고
# 각인을 굴리는 것)은 W2(cycle_engine)와 W10(마왕전)의 몫이다.
#
# 소유하는 것
#   * 각인 부여 기록(granted_runes) — 언제 어느 칸에 무엇이 붙었는가
#   * 전조로 뜯긴 각인(stripped_runes) / 회수당한 카드(reclaimed_cards)
#   * 미선택 각인 조각(rune_shards) — 짝수 레벨업의 미선택 2개가 여기로 온다
#   * 5칸 구성 규칙(자동 합성 → expected_power 상위 5장 → 나머지는 잔재)
#
# 소유하지 않는 것 (일부러)
#   * 받은 카드 목록 그 자체 — `game.rejected_skills` / `game.trophy_reject_skills`가
#     계속 저장소다. 이중 진실 원천을 만들지 않으려고 여기서는 조회만 한다.
#     (W10이 마왕전을 재작성할 때 이 클래스로 흡수하면 된다.)
#   * 각인 카탈로그 — W1의 core/rune_engine.gd 소유다. 이 파일은 카탈로그를
#     **주입받아** 쓰고, 비어 있으면 자리표시자 id를 만든다(§'각인 id 해석' 참조).
#
# 핵심 공식 — **V4(2026-08-09)가 v3 §6.4 재보정으로 갈아끼웠다**
#   각인 수  = clamp(floor(받은 카드 수 / 4), 0, 16) + 강림보정 − 전조로 뜯긴 수
#   HP 배율  = (1 + 0.05 × 총일수) × (1 + 0.15 × 격파 스테이지) × (강림이면 1.15)
#   기저 체력 = BOSS_BASE_HP + min(부채, 45) × 22 + 아이템 × 88 + power_level × 57
#
# 재보정한 이유 하나뿐이다: v3는 스테이지가 5개라 마왕에게 넘어가는 카드가 v2의 4~5배다.
# v2 계수를 그대로 두면 60장 × 70 = 4,200으로 기저 611을 압도하고, 20일 런에서
# 일수 배율만 ×5.18이 된다. 재보정 후 20일·4스테이지 기준 ×3.5로 눌린다(설계 §6.4).
# v2 값(2 / 12 / 70.0 / 0.22)은 `core/tuning.gd`에서 삭제됐다 — 롤백은 그 파일 한 곳이다.

const RUNE_PLACEHOLDER_PREFIX := "rune_slot"

var game: GameMain

## 짝수 레벨업에서 고르지 않은 각인 조각. 카드와 같은 무게로 성장에 기여한다(§6.2).
var rune_shards := 0
## 각인 부여 기록. [{slot:int, rune_id:String, day:int, index:int}] — 추가만 되고
## 다시 굴리지 않는다. "3일차에 2번 칸이 되감기를 얻었다"가 기록으로 남아야
## 프리뷰와 전조 보상이 같은 것을 가리킨다.
var granted_runes: Array[Dictionary] = []
## 전조 격파 보상 "각인 뜯기"로 마왕에게서 영구 제거된 각인.
var stripped_runes: Array[Dictionary] = []
## 전조 격파 보상 "카드 회수"로 내 보관함에 돌아온 카드 id.
var reclaimed_cards: Array[String] = []
## 강림 보정으로 더해지는 각인 수(설계 §4.2: +2). 강림 전에는 0.
var descent_rune_bonus := 0
var descended := false
## W1/W2가 주입하는 각인 id 목록. 비어 있으면 자리표시자를 쓴다.
var rune_catalog: Array[String] = []

var _grant_counter := 0
## sync_runes()의 공회전 방지. 마지막으로 맞춰 둔 목표 각인 수.
var _synced_target := -1


func setup(game_node: GameMain) -> void:
	game = game_node


func reset() -> void:
	rune_shards = 0
	granted_runes.clear()
	stripped_runes.clear()
	reclaimed_cards.clear()
	descent_rune_bonus = 0
	descended = false
	_grant_counter = 0
	_synced_target = -1


# =============================================================================
# 받은 것 — 조회 (저장소는 game.gd에 그대로 둔다)
# =============================================================================

func received_card_ids() -> Array[String]:
	var ids: Array[String] = []
	if not is_instance_valid(game):
		return ids
	for id: String in game.rejected_skills:
		ids.append(id)
	for entry: Dictionary in game.trophy_reject_skills:
		ids.append(String(entry.get("module", "")))
	return ids


func received_card_count() -> int:
	return received_card_ids().size()


func received_item_count() -> int:
	if not is_instance_valid(game):
		return 0
	return game.boss_items.size()


# 카드 + 각인 조각. 설계 §6.2가 "짝수 레벨업의 미선택 각인 2장도 여기에 기여한다"고
# 못박았으므로 둘을 같은 저울에 올린다.
func growth_points() -> int:
	return received_card_count() + rune_shards


# =============================================================================
# 각인 수 공식 (설계 §6.2)
# =============================================================================

# 뜯기기 전의 상한. `floor(받은 카드 수 / BOSS_CARDS_PER_RUNE)`를 BOSS_RUNE_CAP으로 자른다.
# v3 재보정: 4장당 1개 · 상한 16(v2는 2장당 1개 · 상한 12).
func rune_capacity() -> int:
	var raw: int = growth_points() / GameTuning.BOSS_CARDS_PER_RUNE
	return clampi(raw, 0, GameTuning.BOSS_RUNE_CAP)


# 실제로 마왕이 지금 들고 있는 각인 수. 전조로 뜯긴 만큼 줄어든다.
# 강림 보정(+2)은 상한을 넘어설 수 있다 — 보정의 의미가 "프리뷰 없는 대신 더 강하다"이므로
# 캡을 다시 씌우지 않는다.
func rune_count() -> int:
	return maxi(0, rune_capacity() + descent_rune_bonus - stripped_runes.size())


# v3 HP 배율 (설계 §6.4). 축이 둘이다:
#   ① 총 일수 — 오래 끈 만큼 마왕이 자란다 (계수 0.05, v2의 0.22에서 대폭 완화)
#   ② 격파 스테이지 — 진도를 뺀 만큼도 자란다 (계수 0.15)
# 두 번째 축이 필요한 이유: 일수 계수만 남기면 "빨리 5스테이지까지 달린 사람"의 마왕이
# 1스테이지 마왕과 같아진다. 진도는 곧 플레이어의 파워이므로 마왕도 같이 커야 한다.
#
# ⚠️ **시그니처를 바꾸지 않았다.** game.gd `_update_hud`·`preview()`가 `hp_multiplier(day)`
#    한 인자로 부르고 있고 그 배선 교체는 V5 몫이다. 두 번째 인자를 생략하면 클럭에서
#    `stages_cleared`를 읽어 온다(클럭이 없으면 0).
func hp_multiplier(total_days: int, stages_cleared: int = -1) -> float:
	var cleared := stages_cleared if stages_cleared >= 0 else current_stages_cleared()
	var scale := (1.0 + GameTuning.BOSS_HP_PER_TOTAL_DAY * float(maxi(0, total_days))) \
		* (1.0 + GameTuning.BOSS_HP_PER_STAGE_CLEARED * float(maxi(0, cleared)))
	if descended:
		scale *= GameTuning.DESCENT_HP_MUL
	return scale


# 마왕 기저 체력의 **단일 진실 원천**(설계 §6.4). 부채 항에 `min(debts, 45)` 상한이 붙었다 —
# 5스테이지 런은 부채가 60장을 넘어가는데 상한이 없으면 부채 항 하나가 나머지를 압도한다.
# ⚠️ 실기 소비자 `enemy.gd:119`는 아직 이 함수를 부르지 않는다(enemy.gd는 V6/V7 소유).
#    `balance_probe`와 `--stage-test`는 이 함수를 본다.
static func boss_base_health(debt_count: int, item_count: int, power_level: float) -> float:
	var capped := mini(maxi(debt_count, 0), GameTuning.BOSS_DEBT_CAP)
	return GameTuning.BOSS_BASE_HP \
		+ float(capped) * GameTuning.BOSS_HP_PER_DEBT \
		+ float(maxi(item_count, 0)) * GameTuning.BOSS_HP_PER_ITEM \
		+ maxf(power_level, 0.0) * GameTuning.BOSS_HP_PER_POWER


func mark_descended() -> void:
	if descended:
		return
	descended = true
	descent_rune_bonus = GameTuning.DESCENT_RUNE_BONUS


# 설계 §2.5 / V3-C의 승리 등급. **총 일수**로 매긴다(v2는 3/5일 기준이었다).
# 강림 안전 밸브를 한 번이라도 밟았으면 총 일수와 무관하게 C로 고정된다(§6.6).
func victory_grade(total_days: int, was_descent: bool) -> String:
	if was_descent and GameTuning.DESCENT_FORCES_GRADE_C:
		return "C"
	if total_days <= GameTuning.GRADE_S_MAX_DAYS:
		return "S"
	if total_days <= GameTuning.GRADE_A_MAX_DAYS:
		return "A"
	if total_days <= GameTuning.GRADE_B_MAX_DAYS:
		return "B"
	return "C"


# =============================================================================
# 5칸 구성 (설계 §6.1)
# =============================================================================

# 같은 id를 2장씩 자동 합성해 랭크를 올린다. game.gd `_boss_auto_fused_cards()`와
# 규칙이 같다(v1 코드 그대로). W10이 마왕전을 재작성할 때 game.gd 쪽을 지우고
# 이 함수만 남기면 된다 — 그때까지는 두 곳이 같은 답을 낸다.
func auto_fused_cards() -> Array[Dictionary]:
	var counts: Dictionary = {}
	for id: String in received_card_ids():
		if DealCardLibrary.by_id(id).is_empty():
			continue
		counts[id] = int(counts.get(id, 0)) + 1
	var result: Array[Dictionary] = []
	for id in counts:
		var rank_counts := [0, int(counts[id]), 0, 0, 0, 0]
		for rank in range(1, 5):
			rank_counts[rank + 1] += rank_counts[rank] / 2
			rank_counts[rank] %= 2
		for rank in range(1, 6):
			for _copy in rank_counts[rank]:
				result.append(DealCardLibrary.instance(String(id), rank))
	return result


# expected_power 내림차순으로 정렬한 전량. 상위 5장이 레일, 나머지가 잔재다.
func ranked_cards() -> Array[Dictionary]:
	var cards := auto_fused_cards()
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := DealCardLibrary.expected_power(a)
		var pb := DealCardLibrary.expected_power(b)
		if is_equal_approx(pa, pb):
			# 같은 화력이면 id 사전순으로 고정한다. 정렬이 흔들리면 프리뷰와 실제
			# 배치가 프레임마다 달라져 "결정적"이라는 계약이 깨진다.
			return String(a.get("id", "")) < String(b.get("id", ""))
		return pa > pb)
	return cards


# 마왕의 5칸. 카드가 모자라면 빈 칸으로 남는다(v1처럼 순환 채우기를 하지 않는다 —
# 5칸이면 플레이어가 한눈에 읽어야 하는데 같은 카드가 반복되면 읽히지 않는다).
func slot_layout() -> Array[Dictionary]:
	var cards := ranked_cards()
	var layout: Array[Dictionary] = []
	for index in GameTuning.BOSS_SLOT_COUNT:
		var card: Dictionary = cards[index].duplicate(true) if index < cards.size() else {}
		layout.append({"index": index, "card": card, "runes": runes_on_slot(index)})
	return layout


func slot_card(index: int) -> Dictionary:
	var cards := ranked_cards()
	if index < 0 or index >= cards.size() or index >= GameTuning.BOSS_SLOT_COUNT:
		return {}
	return cards[index].duplicate(true)


func filled_slot_count() -> int:
	return mini(ranked_cards().size(), GameTuning.BOSS_SLOT_COUNT)


# 상위 5장에 들지 못한 카드 = 잔재. 밤 필드 몹에게 모듈로 뿌려진다(설계 §6.4).
func residue_cards() -> Array[Dictionary]:
	var cards := ranked_cards()
	if cards.size() <= GameTuning.BOSS_SLOT_COUNT:
		return []
	return cards.slice(GameTuning.BOSS_SLOT_COUNT)


func residue_modules() -> Array[String]:
	var modules: Array[String] = []
	for card: Dictionary in residue_cards():
		var module := DealCardLibrary.debt_module(String(card.get("id", "")))
		if not module.is_empty():
			modules.append(module)
	return modules


# =============================================================================
# 각인 부여 기록
# =============================================================================
# 각인 id 해석: rune_catalog가 주입돼 있으면 거기서 뽑고, 비어 있으면
# "rune_slot3_07" 같은 자리표시자를 만든다. W4는 각인의 **실행**을 하지 않으므로
# 자리표시자로도 수(數)·기록·전조 보상은 전부 정확하게 돌아간다.
# W2/W10은 set_rune_catalog(RuneEngine의 id 목록)를 부르기만 하면 된다.

func set_rune_catalog(ids: Array[String]) -> void:
	rune_catalog = ids.duplicate()


# rune_count()에 맞춰 부여 기록을 채운다. 이미 부여된 각인은 절대 다시 굴리지 않는다.
# 카드를 받을 때마다(=마왕이 자랄 때마다) game.gd가 호출한다.
func sync_runes(rng: RandomNumberGenerator) -> void:
	var target := rune_count()
	# 10Hz HUD 갱신에서도 불리므로 변화가 없으면 즉시 빠진다.
	if target == _synced_target and granted_runes.size() == target:
		return
	_synced_target = target
	while granted_runes.size() > target:
		granted_runes.pop_back()
	while granted_runes.size() < target:
		_grant_counter += 1
		var slot := rng.randi_range(0, GameTuning.BOSS_SLOT_COUNT - 1)
		var rune_id := "%s%d_%02d" % [RUNE_PLACEHOLDER_PREFIX, slot + 1, _grant_counter]
		if not rune_catalog.is_empty():
			rune_id = rune_catalog[rng.randi_range(0, rune_catalog.size() - 1)]
		granted_runes.append({
			"slot": slot,
			"rune_id": rune_id,
			"day": _current_day(),
			"index": _grant_counter
		})


func runes_on_slot(index: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in granted_runes:
		if int(entry.get("slot", -1)) == index:
			found.append(entry.duplicate(true))
	return found


func rune_count_on_slot(index: int) -> int:
	return runes_on_slot(index).size()


# 전조가 시연할 칸을 고른다. 카드가 있는 칸 중에서 고르고, 하나도 없으면 -1.
func demo_slot_index(rng: RandomNumberGenerator) -> int:
	var filled := filled_slot_count()
	if filled <= 0:
		return -1
	return rng.randi_range(0, filled - 1)


# =============================================================================
# 전조 격파 보상 (설계 §4.5)
# =============================================================================

# 각인 뜯기 — 그 칸의 각인 1개를 마왕에게서 영구 제거한다.
# 가장 최근에 붙은 것부터 뜯는다(플레이어가 방금 본 위협을 지우는 게 읽힌다).
func strip_rune(slot_index: int) -> Dictionary:
	for index in range(granted_runes.size() - 1, -1, -1):
		if int(granted_runes[index].get("slot", -1)) != slot_index:
			continue
		var removed: Dictionary = granted_runes[index]
		granted_runes.remove_at(index)
		stripped_runes.append(removed)
		return removed
	# 그 칸에 각인이 없으면 아무 칸에서나 하나 뜯는다(보상이 빈손이 되지 않게).
	if granted_runes.is_empty():
		return {}
	var fallback: Dictionary = granted_runes.pop_back()
	stripped_runes.append(fallback)
	return fallback


func can_strip_rune() -> bool:
	return not granted_runes.is_empty()


# 카드 회수 — 그 칸의 카드를 마왕의 레일에서 지운다.
# `game.rejected_skills`에서 같은 id 한 장을 실제로 뺀다(저장소가 거기이므로).
# 합성으로 랭크가 오른 카드였다면 원본 1장만 돌아온다 — 마왕은 나머지를 계속 쥔다.
func reclaim_card(slot_index: int) -> Dictionary:
	var card := slot_card(slot_index)
	if card.is_empty() or not is_instance_valid(game):
		return {}
	var card_id := String(card.get("id", ""))
	var removed := false
	for index in range(game.rejected_skills.size() - 1, -1, -1):
		if game.rejected_skills[index] == card_id:
			game.rejected_skills.remove_at(index)
			removed = true
			break
	if not removed:
		for index in range(game.trophy_reject_skills.size() - 1, -1, -1):
			if String(game.trophy_reject_skills[index].get("module", "")) == card_id:
				game.trophy_reject_skills.remove_at(index)
				removed = true
				break
	if not removed:
		return {}
	reclaimed_cards.append(card_id)
	return DealCardLibrary.instance(card_id, 1)


func can_reclaim_card(slot_index: int) -> bool:
	return not slot_card(slot_index).is_empty()


# =============================================================================
# 요약 (HUD 고스트 레일 · 프리뷰 · 결과 화면이 읽는 단일 창구)
# =============================================================================

func preview(day: int) -> Dictionary:
	return {
		"day": day,
		"stages_cleared": current_stages_cleared(),
		"slots": slot_layout(),
		"filled_slots": filled_slot_count(),
		"rune_count": rune_count(),
		"rune_capacity": rune_capacity(),
		"stripped": stripped_runes.size(),
		"reclaimed": reclaimed_cards.size(),
		"cards_received": received_card_count(),
		"items_received": received_item_count(),
		"rune_shards": rune_shards,
		"hp_multiplier": hp_multiplier(day),
		"reload_multiplier": GameTuning.BOSS_RELOAD_MUL,
		"descended": descended,
		"residue": residue_modules().size()
	}


func to_snapshot() -> Dictionary:
	return {
		"rune_shards": rune_shards,
		"granted_runes": granted_runes.duplicate(true),
		"stripped_runes": stripped_runes.duplicate(true),
		"reclaimed_cards": reclaimed_cards.duplicate(),
		"descent_rune_bonus": descent_rune_bonus,
		"descended": descended,
		"grant_counter": _grant_counter
	}


func from_snapshot(data: Dictionary) -> void:
	rune_shards = maxi(0, int(data.get("rune_shards", 0)))
	granted_runes.assign(data.get("granted_runes", []))
	stripped_runes.assign(data.get("stripped_runes", []))
	reclaimed_cards.assign(data.get("reclaimed_cards", []))
	descent_rune_bonus = maxi(0, int(data.get("descent_rune_bonus", 0)))
	descended = bool(data.get("descended", false))
	_grant_counter = maxi(0, int(data.get("grant_counter", granted_runes.size())))
	_synced_target = -1


func _current_day() -> int:
	if is_instance_valid(game) and game.clock != null:
		return game.clock.day_number
	return 1


# 격파한 스테이지 수. 클럭이 소유하고 있고(StageClock.stages_cleared) 여기서는 조회만 한다.
# 클럭이 없는 경로(단위 테스트·프로브)는 0으로 본다 = v2와 같은 배율.
func current_stages_cleared() -> int:
	if is_instance_valid(game) and game.clock != null:
		return int(game.clock.stages_cleared)
	return 0
