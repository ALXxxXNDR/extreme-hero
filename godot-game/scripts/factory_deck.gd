class_name FactoryDeck
extends RefCounted

# =============================================================================
# W2 — 5칸 딜싸이클 덱 (v2)
# =============================================================================
# 설계 근거: docs/GAME_DESIGN_V2.md §3(5칸·각인) · §5.4(아이템→장비) · 부록 C-1(확정).
# v1 원본은 docs/v1-archive/factory_deck.gd.txt 에 보존.
#
# v1 → v2 로 사라진 것
#   * `lanes`(분열 3레인) · `split_slot` · `MAX_SPLIT_UPGRADES`
#   * `build_next_piece` / `can_build` / `trailing_bridge` / `construction_count`
#   * `MAX_SLOTS = 10` / `START_SLOTS = 3` (칸 수는 생성 시 고정, 기본 5)
#
# v2 에서 새로 생긴 것
#   * 칸이 **각인 스택을 소유**한다 (`slot["runes"]`). 부록 C-1의 1번 요구.
#   * 칸 **위치 교환**(`swap_slots`)과 **카드만 이동**(`move_card`)이 공존한다.
#     칸을 옮기면 붙어 있던 각인이 함께 간다 — 부록 C-1의 2번 요구.
#   * 아이템은 **레일 밖 장비**(`equipment`, 4부위)다. 칸을 점유하지 않는다(§5.4).
#   * `rune_deck(flow)` 가 RuneEngine이 먹는 덱을 만든다. 런타임(DealCycleController)과
#     편집 미리보기(W6)가 **같은 함수**로 궤적을 구하기 위한 단일 진실 원천의 입구다.
#
# 칸 자료구조
#   slot := {"card": Dictionary, "runes": Array[Dictionary],
#            "repeat": int, "duration_mul": float, "reload_mul": float}
#   빈 카드({})는 **기본 베기**로 컴파일된다(v1과 동일).
#   repeat/duration_mul/reload_mul 은 강화술사(v1 잔존 경로)가 쓰는 칸 배율이다.
#   5칸 모델에서 의미가 남아 있어 유지했고, 다리/분열/증설만 제거했다(W9가 재정의).

const SLOT_COUNT := 5
# 장비 4부위(§5.4). 부위 id는 item_library.gd의 `slot` 값을 그대로 쓴다.
const EQUIPMENT_PARTS: Array[String] = ["weapon", "necklace", "ring", "bracelet"]

var slots: Array[Dictionary] = []
var inventory: Array[Dictionary] = []
# 레일 밖 장비. 부위당 1개, 총 4개. UI는 W6가 붙인다(여기서는 데이터만).
var equipment: Array[Dictionary] = []
# Y0 신설 — **레일 각인**(FEEDBACK_Y §2.2). 칸이 아니라 레일 전체가 소유한다.
# 칸을 교환해도 따라가지 않고, 붙일 칸을 고르지 않는다.
# `rune_opts()`가 이 배열을 그대로 `RuneEngine.simulate_cycle`의 opts로 넘긴다.
# 저장 키 `rail_runes`는 schema 4로 Y6가 붙인다 — 여기서는 데이터 구조만 만든다.
var rail_runes: Array[Dictionary] = []

func reset(slot_count: int = SLOT_COUNT) -> void:
	slots.clear()
	inventory.clear()
	equipment.clear()
	rail_runes.clear()
	for _index in maxi(1, slot_count):
		slots.append(_new_slot())

func _new_slot() -> Dictionary:
	return {"card": {}, "runes": [], "repeat": 1, "duration_mul": 1.0, "reload_mul": 1.0}

## 저장 복원·전조 덱처럼 칸 수가 다른 덱을 만들 때 쓴다.
func ensure_slot_count(slot_count: int) -> void:
	var target := maxi(1, slot_count)
	while slots.size() > target:
		slots.pop_back()
	while slots.size() < target:
		slots.append(_new_slot())

## v1 저장/외부에서 들어온 칸 딕셔너리를 v2 형태로 보정한다(빠진 키 채우기).
func normalize_slots() -> void:
	for index in slots.size():
		var slot: Dictionary = slots[index]
		if not slot.has("card"):
			# v1 `lanes` 배열이 들어왔다면 첫 레인만 카드로 승격한다.
			var lanes: Array = slot.get("lanes", [])
			slot["card"] = (lanes[0] as Dictionary) if not lanes.is_empty() and lanes[0] is Dictionary else {}
		slot.erase("lanes")
		if not slot.has("runes") or not slot["runes"] is Array:
			slot["runes"] = []
		slot["repeat"] = maxi(1, int(slot.get("repeat", 1)))
		slot["duration_mul"] = float(slot.get("duration_mul", 1.0))
		slot["reload_mul"] = float(slot.get("reload_mul", 1.0))
		slots[index] = slot

# -----------------------------------------------------------------------------
# 보관함
# -----------------------------------------------------------------------------

func add_inventory(card: Dictionary) -> void:
	if not card.is_empty() and String(card.get("id", "")) != "basic":
		inventory.append(card.duplicate(true))

func remove_inventory_at(index: int) -> Dictionary:
	if index < 0 or index >= inventory.size():
		return {}
	return inventory.pop_at(index)

# -----------------------------------------------------------------------------
# 카드 배치 (칸 1개 = 카드 1장)
# -----------------------------------------------------------------------------

func has_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()

## 칸에 카드를 놓고 밀려난 카드를 돌려준다.
## 아이템 카드는 **칸을 점유하지 않는다**(§5.4) — 장비로 우회시키고 밀려난 장비를 돌려준다.
func place_card(slot_index: int, card: Dictionary) -> Dictionary:
	if String(card.get("kind", "")) == "item":
		return equip(card)
	if not has_slot(slot_index):
		return {}
	var slot: Dictionary = slots[slot_index]
	var previous: Dictionary = (slot.get("card", {}) as Dictionary).duplicate(true)
	slot["card"] = card.duplicate(true)
	slots[slot_index] = slot
	return previous

func clear_slot(slot_index: int) -> Dictionary:
	return place_card(slot_index, {})

func get_card(slot_index: int) -> Dictionary:
	if not has_slot(slot_index):
		return {}
	return (slots[slot_index].get("card", {}) as Dictionary).duplicate(true)

## 카드만 교환한다. 각인은 제자리에 남는다 (부록 C-1의 [카드 이동]).
func move_card(a: int, b: int) -> bool:
	if not has_slot(a) or not has_slot(b) or a == b:
		return false
	return RuneEngine.move_card(slots, a, b)

## 칸을 통째로 교환한다. 각인이 칸과 **함께** 이동한다 (부록 C-1의 [칸 순서 교환]).
func swap_slots(a: int, b: int) -> bool:
	if not has_slot(a) or not has_slot(b) or a == b:
		return false
	return RuneEngine.swap_slots(slots, a, b)

# -----------------------------------------------------------------------------
# 각인 (칸이 소유한다 — 부록 C-1)
# -----------------------------------------------------------------------------

## 각인 인스턴스는 반드시 `RuneEngine.roll_rune(id, rng)`로 만들어 넘길 것.
## 상한(총 5개 / 같은 id 3개)을 넘으면 false를 돌려주고 아무것도 바꾸지 않는다.
func attach_rune(slot_index: int, instance: Dictionary) -> bool:
	if not has_slot(slot_index):
		return false
	# Y0 방어: 레일 각인은 칸에 붙지 않는다(§2.2). `attach_rail_rune()`로 보낼 것.
	if RuneEngine.rune_scope(String(instance.get("id", ""))) == "rail":
		return false
	return RuneEngine.attach_rune(slots[slot_index], instance)

func detach_rune(slot_index: int, rune_index: int) -> Dictionary:
	if not has_slot(slot_index):
		return {}
	var stack: Array = slots[slot_index].get("runes", [])
	if rune_index < 0 or rune_index >= stack.size():
		return {}
	return stack.pop_at(rune_index)

func runes_on(slot_index: int) -> Array:
	if not has_slot(slot_index):
		return []
	return (slots[slot_index].get("runes", []) as Array).duplicate(true)

func rune_count_on(slot_index: int) -> int:
	if not has_slot(slot_index):
		return 0
	return (slots[slot_index].get("runes", []) as Array).size()

func total_rune_count() -> int:
	var total := 0
	for slot: Dictionary in slots:
		total += (slot.get("runes", []) as Array).size()
	return total

# -----------------------------------------------------------------------------
# 레일 각인 (레일 전체가 소유한다 — Y0 · FEEDBACK_Y §2.2)
# -----------------------------------------------------------------------------
# 상한 2겹: 총 RAIL_RUNE_CAP(3)개 · 같은 id는 RAIL_SAME_ID_CAP(1)개.
# 칸 각인의 4겹 감쇠와 달리 레일은 **개수 상한만** 쓴다 — 중복이 아예 불가능해서
# 확률 감쇠가 개입할 여지가 없기 때문이다.

func attach_rail_rune(instance: Dictionary) -> bool:
	var id := String(instance.get("id", ""))
	if RuneEngine.rune_scope(id) != "rail":
		return false
	if rail_runes.size() >= RuneEngine.RAIL_RUNE_CAP:
		return false
	if rail_same_id_count(id) >= RuneEngine.RAIL_SAME_ID_CAP:
		return false
	rail_runes.append(instance.duplicate(true))
	return true

func detach_rail_rune(index: int) -> Dictionary:
	if index < 0 or index >= rail_runes.size():
		return {}
	return rail_runes.pop_at(index)

func rail_same_id_count(id: String) -> int:
	var count := 0
	for inst: Dictionary in rail_runes:
		if String(inst.get("id", "")) == id:
			count += 1
	return count

func rail_rune_ids() -> Array[String]:
	var ids: Array[String] = []
	for inst: Dictionary in rail_runes:
		ids.append(String(inst.get("id", "")))
	return ids

func rail_rune_count() -> int:
	return rail_runes.size()

# -----------------------------------------------------------------------------
# 장비 (레일 밖 4부위 — §5.4)
# -----------------------------------------------------------------------------

static func equipment_part(card: Dictionary) -> String:
	var part := String(ItemLibrary.by_id(String(card.get("id", ""))).get("slot", ""))
	return part if part in EQUIPMENT_PARTS else "weapon"

## 같은 부위에 이미 장비가 있으면 교체하고 밀려난 장비를 돌려준다.
func equip(card: Dictionary) -> Dictionary:
	if card.is_empty() or String(card.get("kind", "")) != "item":
		return {}
	var part := equipment_part(card)
	for index in equipment.size():
		if equipment_part(equipment[index]) == part:
			var displaced: Dictionary = (equipment[index] as Dictionary).duplicate(true)
			equipment[index] = card.duplicate(true)
			return displaced
	if equipment.size() >= EQUIPMENT_PARTS.size():
		var last: Dictionary = (equipment[equipment.size() - 1] as Dictionary).duplicate(true)
		equipment[equipment.size() - 1] = card.duplicate(true)
		return last
	equipment.append(card.duplicate(true))
	return {}

func unequip(index: int) -> Dictionary:
	if index < 0 or index >= equipment.size():
		return {}
	return equipment.pop_at(index)

func equipped_at(part: String) -> Dictionary:
	for card: Dictionary in equipment:
		if equipment_part(card) == part:
			return card.duplicate(true)
	return {}

# -----------------------------------------------------------------------------
# 컴파일 — 칸 1개 → 실행할 카드 1장
# -----------------------------------------------------------------------------
# `flow`는 §5.4의 스코프 재해석용 바늘 문맥이다(전부 선택).
#   {"current": int, "next": int, "prev": int}
#   *_all      → 항상
#   *_paired   → 지금 실행 중인 칸 자신
#   *_next     → 바늘이 다음에 실행할 칸
#   *_previous → 직전에 실행한 칸
#   *_adjacent → prev 또는 next
# flow가 비면 `*_all`만 적용된다(정적 UI 표기용).
func compile_slot(slot_index: int, flow: Dictionary = {}) -> Dictionary:
	if not has_slot(slot_index):
		return {}
	var slot: Dictionary = slots[slot_index]
	var instance_data: Dictionary = slot.get("card", {})
	if instance_data.is_empty() or String(instance_data.get("kind", "skill")) == "item":
		instance_data = DealCardLibrary.basic_instance()
	var card := DealCardLibrary.ranked(instance_data)
	var cast_count := maxi(1, int(slot.get("repeat", 1)))
	card["casts"] = cast_count
	card["slot_index"] = slot_index
	card["duration"] = maxf(0.12, float(card.get("duration", 0.5)) * float(slot.get("duration_mul", 1.0)) * float(cast_count))
	card["reload"] = maxf(0.0, float(card.get("reload", 0.2)) * float(slot.get("reload_mul", 1.0)) * float(cast_count))
	_apply_item_modifiers(card, slot_index, flow)
	return card

## v1 이름 호환. 항상 1장짜리 배열이다(레인 폐지).
func compile_group(slot_index: int, flow: Dictionary = {}) -> Array[Dictionary]:
	var compiled: Array[Dictionary] = []
	var card := compile_slot(slot_index, flow)
	if not card.is_empty():
		compiled.append(card)
	return compiled

func _apply_item_modifiers(card: Dictionary, target_slot: int, flow: Dictionary) -> void:
	var damage_bonus := 0.0
	var duration_bonus := 0.0
	var reload_bonus := 0.0
	var range_bonus := 0.0
	var extra_hits := 0
	var extra_pierce := 0
	var extra_crit := 0.0
	var extra_lifesteal := 0.0
	var has_flow := flow.has("current") or flow.has("next") or flow.has("prev")
	var is_next := has_flow and target_slot == int(flow.get("next", -1))
	var is_previous := has_flow and target_slot == int(flow.get("prev", -1))
	var is_paired := has_flow and target_slot == int(flow.get("current", -1))
	var is_adjacent := is_next or is_previous
	for equipped: Dictionary in equipment:
		var item := ItemLibrary.by_id(String(equipped.get("id", "")))
		var effects: Dictionary = item.get("effects", {})
		damage_bonus += float(effects.get("damage_all", 0.0))
		duration_bonus += float(effects.get("duration_all", 0.0))
		reload_bonus += float(effects.get("reload_all", 0.0))
		range_bonus += float(effects.get("range_all", 0.0))
		extra_crit += float(effects.get("crit_all", 0.0))
		extra_lifesteal += float(effects.get("lifesteal_all", 0.0))
		if is_adjacent:
			damage_bonus += float(effects.get("damage_adjacent", 0.0))
			duration_bonus += float(effects.get("duration_adjacent", 0.0))
			reload_bonus += float(effects.get("reload_adjacent", 0.0))
			range_bonus += float(effects.get("range_adjacent", 0.0))
		if is_next:
			damage_bonus += float(effects.get("damage_next", 0.0))
			duration_bonus += float(effects.get("duration_next", 0.0))
			reload_bonus += float(effects.get("reload_next", 0.0))
			range_bonus += float(effects.get("range_next", 0.0))
			extra_hits += int(effects.get("hits_next", 0))
			extra_pierce += int(effects.get("pierce_next", 0))
		if is_previous:
			damage_bonus += float(effects.get("damage_previous", 0.0))
		if is_paired:
			damage_bonus += float(effects.get("damage_paired", 0.0))
			extra_hits += int(effects.get("hits_paired", 0))
		if String(card.get("kind", "")) == "shield":
			reload_bonus += float(effects.get("shield_reload", 0.0))
	card["damage"] = maxf(0.0, float(card.get("damage", 0.0)) * maxf(0.1, 1.0 + damage_bonus))
	card["duration"] = maxf(0.12, float(card.get("duration", 0.5)) * maxf(0.25, 1.0 + duration_bonus))
	card["reload"] = maxf(0.0, float(card.get("reload", 0.2)) * maxf(0.15, 1.0 + reload_bonus))
	card["range"] = float(card.get("range", 0.0)) * maxf(0.25, 1.0 + range_bonus)
	card["hits"] = maxi(1, int(card.get("hits", 1)) + extra_hits)
	card["pierce"] = maxi(0, int(card.get("pierce", 0)) + extra_pierce)
	card["crit"] = float(card.get("crit", 0.0)) + extra_crit
	card["lifesteal"] = float(card.get("lifesteal", 0.0)) + extra_lifesteal

# -----------------------------------------------------------------------------
# RuneEngine 다리 — W2 런타임과 W6 미리보기의 단일 진실 원천 입구
# -----------------------------------------------------------------------------
# 반환값을 그대로 `RuneEngine.simulate_cycle(deck, seed, opts)`에 넘긴다.
# `runes` 배열은 **참조로** 넘긴다(엔진은 읽기만 한다) — 복사 비용을 매 사이클 내지 않기 위해서.
func rune_deck(flow: Dictionary = {}) -> Array:
	var deck: Array = []
	for slot_index in slots.size():
		var card := compile_slot(slot_index, flow)
		deck.append({
			"card": {
				"id": String(card.get("id", "basic")),
				"damage": float(card.get("damage", 0.0)),
				"reload": float(card.get("reload", 0.0)),
				"duration": float(card.get("duration", 0.5)),
				"element": String(card.get("element", "")),
				"form": String(card.get("form", ""))
			},
			"runes": slots[slot_index].get("runes", [])
		})
	return deck

## Y0 신설 — `RuneEngine.simulate_cycle(deck, seed, opts)`의 **opts** 쪽 입구.
## 레일 각인은 덱(칸 배열)에 실을 자리가 없어서 opts로 들어간다(§2.4의 데이터 모델).
## `rail_runes`를 **참조로** 넘긴다(엔진은 읽기만 한다) — `rune_deck()`의 `runes`와 같은 규약.
## `rune_deck()`은 시그니처·동작 무변경이다. 호출부를 옮기는 것은 Y2 몫이다.
func rune_opts() -> Dictionary:
	return {"rail_runes": rail_runes}

# -----------------------------------------------------------------------------
# 집계 · 조회
# -----------------------------------------------------------------------------

## v2 의미: **한 바퀴(5칸 1회씩) 실행했을 때 쌓이는 기본 RELOAD 빚**(과열 미포함).
## 실제 RELOAD는 사이클 종료 시 `빚 × rail_rest × reload_scale`로 계산되고 `RELOAD_CAP`에
## 클램프된다(§1.4). 과열 항은 Y0에서 폐기, Y8에서 상수까지 삭제됐다.
func total_reload() -> float:
	var result := 0.0
	for slot_index in slots.size():
		result += float(compile_slot(slot_index).get("reload", 0.0))
	return result

## 장비 효과를 적용하기 전의 합계. UI에서 감소 전·후를 비교할 때만 쓴다.
func raw_total_reload() -> float:
	var result := 0.0
	for slot: Dictionary in slots:
		var instance_data: Dictionary = slot.get("card", {})
		if instance_data.is_empty() or String(instance_data.get("kind", "skill")) == "item":
			instance_data = DealCardLibrary.basic_instance()
		var card := DealCardLibrary.ranked(instance_data)
		var cast_count := maxi(1, int(slot.get("repeat", 1)))
		result += float(card.get("reload", 0.0)) * float(slot.get("reload_mul", 1.0)) * float(cast_count)
	return result

func global_effects() -> Dictionary:
	var result := {
		"move_speed":0.0, "xp_all":0.0, "dash_reload":0.0,
		"heal_cycle":0.0, "shield_cycle_chance":0.0,
		"reload_all":0.0, "duration_all":0.0, "damage_all":0.0,
		"range_all":0.0, "crit_all":0.0, "lifesteal_all":0.0
	}
	for equipped: Dictionary in equipment:
		var item := ItemLibrary.by_id(String(equipped.get("id", "")))
		var effects: Dictionary = item.get("effects", {})
		for key in result:
			result[key] = float(result[key]) + float(effects.get(key, 0.0))
	return result

func get_total_count(card_id: String) -> int:
	var count := 0
	for card: Dictionary in get_all_owned_cards():
		if String(card.get("id", "")) == card_id:
			count += 1
	return count

func get_rank_count(card_id: String, rank: int) -> int:
	var count := 0
	for card: Dictionary in get_all_owned_cards():
		if String(card.get("id", "")) == card_id and int(card.get("rank", 1)) == rank:
			count += 1
	return count

func get_highest_rank(card_id: String) -> int:
	var highest := 0
	for rank in range(1, 6):
		if get_rank_count(card_id, rank) > 0:
			highest = rank
	return highest

func owns_weapon_type(weapon_type: String) -> bool:
	for card: Dictionary in get_all_owned_cards():
		if String(card.get("kind", "")) != "item":
			continue
		if String(ItemLibrary.by_id(String(card.get("id", ""))).get("weapon_type", "")) == weapon_type:
			return true
	return false

func get_all_owned_cards() -> Array[Dictionary]:
	var result := inventory.duplicate(true)
	for slot: Dictionary in slots:
		var card: Dictionary = slot.get("card", {})
		if not card.is_empty():
			result.append(card.duplicate(true))
	for equipped: Dictionary in equipment:
		result.append(equipped.duplicate(true))
	return result

func group_label(slot_index: int) -> String:
	if not has_slot(slot_index):
		return "-"
	var card: Dictionary = slots[slot_index].get("card", {})
	if card.is_empty():
		return "기본 베기"
	if String(card.get("kind", "skill")) == "item":
		return String(ItemLibrary.by_id(String(card.get("id", ""))).get("name", "아이템"))
	var definition := DealCardLibrary.by_id(String(card.get("id", "")))
	return "%s R%d" % [definition.get("name", "기술"), int(card.get("rank", 1))]

# -----------------------------------------------------------------------------
# 합성 · 소모
# -----------------------------------------------------------------------------

func fusion_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in DealCardLibrary.SKILLS:
		var id := String(definition["id"])
		for rank in range(1, 5):
			var count := get_rank_count(id, rank)
			if count >= 2:
				result.append({"id":id, "rank":rank, "count":count})
	return result

func fuse(card_id: String, rank: int) -> bool:
	if rank < 1 or rank >= 5 or get_rank_count(card_id, rank) < 2:
		return false
	if not consume_skill(card_id, rank, 2):
		return false
	add_inventory(DealCardLibrary.instance(card_id, rank + 1))
	return true

func consume_skill(card_id: String, rank: int, amount: int = 1) -> bool:
	if get_rank_count(card_id, rank) < amount:
		return false
	var remaining := amount
	for index in range(inventory.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var card: Dictionary = inventory[index]
		if String(card.get("id", "")) == card_id and int(card.get("rank", 1)) == rank:
			inventory.remove_at(index)
			remaining -= 1
	for slot_index in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: Dictionary = slots[slot_index]
		var card: Dictionary = slot.get("card", {})
		if String(card.get("id", "")) == card_id and int(card.get("rank", 1)) == rank:
			slot["card"] = {}
			slots[slot_index] = slot
			remaining -= 1
	for index in range(equipment.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var card: Dictionary = equipment[index]
		if String(card.get("id", "")) == card_id and int(card.get("rank", 1)) == rank:
			equipment.remove_at(index)
			remaining -= 1
	return remaining == 0

# -----------------------------------------------------------------------------
# 칸 배율 강화 (v1 강화술사의 남은 경로 — W9가 각인 상점으로 재정의한다)
# -----------------------------------------------------------------------------
# `split`·`build`는 5칸 모델에서 의미가 사라져 **항상 거부**한다(안전화만, 폐기는 W9).

func upgrade_slot(slot_index: int, upgrade_type: String) -> bool:
	if not has_slot(slot_index):
		return false
	var slot: Dictionary = slots[slot_index]
	match upgrade_type:
		"repeat":
			if int(slot.get("repeat", 1)) >= 2:
				return false
			slot["repeat"] = 2
		"duration":
			if float(slot.get("duration_mul", 1.0)) <= 0.72:
				return false
			slot["duration_mul"] = float(slot.get("duration_mul", 1.0)) * 0.86
		"reload":
			if float(slot.get("reload_mul", 1.0)) <= 0.62:
				return false
			slot["reload_mul"] = float(slot.get("reload_mul", 1.0)) * 0.82
		_:
			return false
	slots[slot_index] = slot
	return true

func can_apply_upgrade(upgrade_type: String) -> bool:
	if upgrade_type not in ["repeat", "duration", "reload"]:
		return false
	for slot: Dictionary in slots:
		match upgrade_type:
			"repeat":
				if int(slot.get("repeat", 1)) < 2:
					return true
			"duration":
				if float(slot.get("duration_mul", 1.0)) > 0.72:
					return true
			"reload":
				if float(slot.get("reload_mul", 1.0)) > 0.62:
					return true
	return false
