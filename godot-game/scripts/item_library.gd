class_name ItemLibrary
extends RefCounted

const RARITY_ORDER := ["common", "rare", "unique", "hero"]
# YZ: 표시명을 영어 음차에서 우리말로 바꿨다(game.gd의 각인 등급 일반/희귀/영웅과 통일).
# 키(common/rare/unique/hero)와 RARITY_ORDER는 그대로다.
const RARITY_NAMES := {"common":"일반", "rare":"희귀", "unique":"특별", "hero":"영웅"}
const RARITY_COLORS := {"common":"9299a6", "rare":"4da3ff", "unique":"b66cff", "hero":"ef4444"}
const RARITY_WEIGHTS := {"common":62, "rare":25, "unique":10, "hero":3}
const RARITY_PRICES := {"common":28, "rare":58, "unique":118, "hero":235}

# =============================================================================
# V2 — 아이템 57종 (v3 전면 판타지 개명)
# =============================================================================
# 기준: docs/GAME_DESIGN_V3.md §5.4 · 부록 A-1 ⑦ · 부록 A-2 ⑲
#
# **"직장 풍자 잔재 약 30종"의 실체가 이 파일이었다.** 스킬 카드 표시명은 W7이 이미
# 판타지로 통일했고 남은 풍자는 id에만 있었다(그리고 id는 §5.2 때문에 못 바꾼다).
# 실제 사용자에게 보이는 풍자는 전부 여기 있었다 —
#   무거운 야근검 · 회의종결 대검 · 잔업용 쌍칼 한쪽 · 납기 반지 · 경험 많은 척 반지 ·
#   대시 출석 팔찌 · 주말 반납 대검 · 재장전 감독관 목걸이 · 두 번째 서명 반지 ·
#   보랏빛 공장장 목걸이 · 보라색 경력 반지 · 마감파괴 대검 아포칼립스 ·
#   영웅의 납기 조작기 · 불사 야근 반지 · 빨간 칼퇴 팔찌 · … 36종을 개명했다.
#
# **바꾼 것은 `name` 키뿐이다.**
#   * `id`      — 무변경. 세이브·상점 오퍼·`equipped_weapon_id`·테스트가 전부 id로 문다.
#   * `effects` — 무변경. 효과 어휘(`damage_next` 등)는 v2 §5.4의 "바늘 기준 재해석"을
#                 그대로 유지한다. v3는 어휘를 건드리지 않는다.
#   * `desc`    — 무변경. 수치 설명문이라 개명과 무관하다.
#   * `rarity` / `slot` / `weapon_type` / `classes` / `symbol` — 무변경.
#
# ⚠️ `game.gd:6786`이 상점 오퍼에 **이름을 복사 저장**한다 → v2 세이브에는 옛 이름이
#    남는다. v3는 저장 schema 3(§9)으로 v2 스냅샷을 폐기하므로 자동 해결된다(V9 소유).
#
# 57종: 커먼 21 · 레어 15 · 유니크 12 · 히어로 9.
# 아이템 카드는 공격 스킬과 완전히 별개입니다. 딜싸이클의 한 칸을 사용하지만 직접 공격하지 않고,
# effects만 앞·뒤·동시 칸 또는 전체 레일에 적용합니다.
const ITEMS: Array[Dictionary] = [
	# COMMON 21
	{"id":"c_rapier_01","name":"성급한 견습 세검","symbol":"r","rarity":"common","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"다음 스킬 지속시간 -8%, 전체 RELOAD -1%.","effects":{"duration_next":-0.08,"reload_all":-0.01}},
	{"id":"c_rapier_02","name":"찰나의 세검","symbol":"r","rarity":"common","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"앞뒤 스킬 지속시간 -4%, 전체 RELOAD -1%.","effects":{"duration_adjacent":-0.04,"reload_all":-0.01}},
	{"id":"c_rapier_03","name":"가벼운 은빛 침검","symbol":"r","rarity":"common","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"다음 스킬 RELOAD -7%.","effects":{"reload_next":-0.07}},
	{"id":"c_greatsword_01","name":"무거운 파수검","symbol":"G","rarity":"common","slot":"weapon","weapon_type":"greatsword","classes":["swordsman"],"desc":"다음 스킬 피해 +18%, 지속시간 +7%.","effects":{"damage_next":0.18,"duration_next":0.07}},
	{"id":"c_greatsword_02","name":"무쇠판 대검","symbol":"G","rarity":"common","slot":"weapon","weapon_type":"greatsword","classes":["swordsman"],"desc":"이전 스킬 피해 +16%.","effects":{"damage_previous":0.16}},
	{"id":"c_dagger_01","name":"잔상의 단검","symbol":"d","rarity":"common","slot":"weapon","weapon_type":"dagger","classes":["swordsman"],"desc":"다음 다단 스킬 피해 +10%.","effects":{"damage_next":0.1,"hits_next":1}},
	{"id":"c_dagger_02","name":"짝 잃은 쌍검","symbol":"d","rarity":"common","slot":"weapon","weapon_type":"dagger","classes":["swordsman"],"desc":"앞뒤 스킬 RELOAD -4%.","effects":{"reload_adjacent":-0.04}},
	{"id":"c_longsword_01","name":"왕국 보급 장검","symbol":"l","rarity":"common","slot":"weapon","weapon_type":"longsword","classes":["swordsman"],"desc":"앞뒤 스킬 피해 +8%.","effects":{"damage_adjacent":0.08}},
	{"id":"c_spear_01","name":"길쭉한 사냥창","symbol":"s","rarity":"common","slot":"weapon","weapon_type":"spear","classes":["swordsman"],"desc":"다음 스킬 범위 +14%.","effects":{"range_next":0.14}},
	{"id":"c_neck_01","name":"견습의 모래시계 목걸이","symbol":"n","rarity":"common","slot":"necklace","desc":"전체 지속시간 -2%.","effects":{"duration_all":-0.02}},
	{"id":"c_neck_02","name":"값싼 톱니 부적","symbol":"n","rarity":"common","slot":"necklace","desc":"전체 RELOAD -4%.","effects":{"reload_all":-0.04}},
	{"id":"c_neck_03","name":"한 줌 행운의 펜던트","symbol":"n","rarity":"common","slot":"necklace","desc":"치명타 확률 +3%.","effects":{"crit_all":0.03}},
	{"id":"c_neck_04","name":"풀잎 호루라기","symbol":"n","rarity":"common","slot":"necklace","desc":"이동 속도 +4%.","effects":{"move_speed":0.04}},
	{"id":"c_ring_01","name":"약속의 반지","symbol":"o","rarity":"common","slot":"ring","desc":"다음 스킬 피해 +7%, 전체 RELOAD -1%.","effects":{"damage_next":0.07,"reload_all":-0.01}},
	{"id":"c_ring_02","name":"은은한 회복 반지","symbol":"o","rarity":"common","slot":"ring","desc":"사이클 시작마다 체력 1 회복.","effects":{"heal_cycle":1.0}},
	{"id":"c_ring_03","name":"허풍쟁이의 반지","symbol":"o","rarity":"common","slot":"ring","desc":"경험치 획득 +5%.","effects":{"xp_all":0.05}},
	{"id":"c_ring_04","name":"넓게 보는 반지","symbol":"o","rarity":"common","slot":"ring","desc":"앞뒤 스킬 범위 +6%.","effects":{"range_adjacent":0.06}},
	{"id":"c_brace_01","name":"질주의 팔찌","symbol":"b","rarity":"common","slot":"bracelet","desc":"대시 대기 -4%.","effects":{"dash_reload":-0.04}},
	{"id":"c_brace_02","name":"얇은 수호 팔찌","symbol":"b","rarity":"common","slot":"bracelet","desc":"사이클 시작마다 8% 확률로 수호막 +1.","effects":{"shield_cycle_chance":0.08}},
	{"id":"c_brace_03","name":"손목 숫돌","symbol":"b","rarity":"common","slot":"bracelet","desc":"같은 칸의 스킬 피해 +9%.","effects":{"damage_paired":0.09}},
	{"id":"c_brace_04","name":"급조한 사슬 팔찌","symbol":"b","rarity":"common","slot":"bracelet","desc":"앞뒤 스킬 지속시간 -3%, 전체 RELOAD -1%.","effects":{"duration_adjacent":-0.03,"reload_all":-0.01}},

	# RARE 15
	{"id":"r_rapier_01","name":"시간을 베는 세검","symbol":"R","rarity":"rare","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"다음 스킬 지속시간 -16%, RELOAD -8%, 전체 RELOAD -3%.","effects":{"duration_next":-0.16,"reload_next":-0.08,"reload_all":-0.03}},
	{"id":"r_rapier_02","name":"푸른 잔상검","symbol":"R","rarity":"rare","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"앞뒤 스킬 지속시간 -10%, 피해 +6%, 전체 RELOAD -3%.","effects":{"duration_adjacent":-0.1,"damage_adjacent":0.06,"reload_all":-0.03}},
	{"id":"r_greatsword_01","name":"불면의 대검","symbol":"K","rarity":"rare","slot":"weapon","weapon_type":"greatsword","classes":["swordsman"],"desc":"다음 스킬 피해 +38%, 지속시간 +12%.","effects":{"damage_next":0.38,"duration_next":0.12}},
	{"id":"r_greatsword_02","name":"파란 철성검","symbol":"K","rarity":"rare","slot":"weapon","weapon_type":"greatsword","classes":["swordsman"],"desc":"앞뒤 스킬 피해 +22%.","effects":{"damage_adjacent":0.22}},
	{"id":"r_dagger_01","name":"복제자의 단검","symbol":"D","rarity":"rare","slot":"weapon","weapon_type":"dagger","classes":["swordsman"],"desc":"다음 스킬 타격 +1, 피해 -8%.","effects":{"hits_next":1,"damage_next":-0.08}},
	{"id":"r_spear_01","name":"청풍 장창","symbol":"S","rarity":"rare","slot":"weapon","weapon_type":"spear","classes":["swordsman"],"desc":"다음 스킬 범위 +28%, 피해 +10%.","effects":{"range_next":0.28,"damage_next":0.1}},
	{"id":"r_neck_01","name":"금 간 회중시계","symbol":"N","rarity":"rare","slot":"necklace","desc":"전체 지속시간 -5%.","effects":{"duration_all":-0.05}},
	{"id":"r_neck_02","name":"속결 술사의 목걸이","symbol":"N","rarity":"rare","slot":"necklace","desc":"전체 RELOAD -8%.","effects":{"reload_all":-0.08}},
	{"id":"r_neck_03","name":"푸른 별의 인장","symbol":"N","rarity":"rare","slot":"necklace","desc":"전체 피해 +7%, 경험치 +8%.","effects":{"damage_all":0.07,"xp_all":0.08}},
	{"id":"r_ring_01","name":"메아리 서약의 반지","symbol":"O","rarity":"rare","slot":"ring","desc":"이전 스킬 피해 +24%.","effects":{"damage_previous":0.24}},
	{"id":"r_ring_02","name":"연쇄 각인 반지","symbol":"O","rarity":"rare","slot":"ring","desc":"같은 칸의 스킬 타격 +1.","effects":{"hits_paired":1}},
	{"id":"r_ring_03","name":"파란 생존 반지","symbol":"O","rarity":"rare","slot":"ring","desc":"사이클 시작마다 체력 3 회복.","effects":{"heal_cycle":3.0}},
	{"id":"r_brace_01","name":"설익은 도약의 팔찌","symbol":"B","rarity":"rare","slot":"bracelet","desc":"대시 대기 -10%, 이동 속도 +5%, 전체 RELOAD -3%.","effects":{"dash_reload":-0.1,"move_speed":0.05,"reload_all":-0.03}},
	{"id":"r_brace_02","name":"동시 일격 팔찌","symbol":"B","rarity":"rare","slot":"bracelet","desc":"같은 칸의 스킬 피해 +18%.","effects":{"damage_paired":0.18}},
	{"id":"r_brace_03","name":"푸른 방벽 팔찌","symbol":"B","rarity":"rare","slot":"bracelet","desc":"사이클 시작마다 20% 확률로 수호막 +1.","effects":{"shield_cycle_chance":0.2}},

	# UNIQUE 12
	{"id":"u_rapier_01","name":"시간을 훔치는 세검","symbol":"UR","rarity":"unique","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"앞뒤 스킬 지속시간 -18%, 전체 RELOAD -8%.","effects":{"duration_adjacent":-0.18,"reload_all":-0.08}},
	{"id":"u_greatsword_01","name":"결단의 대검","symbol":"UG","rarity":"unique","slot":"weapon","weapon_type":"greatsword","classes":["swordsman"],"desc":"다음 스킬 피해 +72%, 지속시간 +24%.","effects":{"damage_next":0.72,"duration_next":0.24}},
	{"id":"u_dagger_01","name":"세 번 벼린 단검","symbol":"UD","rarity":"unique","slot":"weapon","weapon_type":"dagger","classes":["swordsman"],"desc":"다음 스킬 타격 +2, RELOAD +12%.","effects":{"hits_next":2,"reload_next":0.12}},
	{"id":"u_longsword_01","name":"왕가의 맹세 장검","symbol":"UL","rarity":"unique","slot":"weapon","weapon_type":"longsword","classes":["swordsman"],"desc":"앞뒤 스킬 피해 +32%, 수호막 카드 RELOAD -20%.","effects":{"damage_adjacent":0.32,"shield_reload":-0.2}},
	{"id":"u_spear_01","name":"용의 척추창","symbol":"US","rarity":"unique","slot":"weapon","weapon_type":"spear","classes":["swordsman"],"desc":"다음 스킬 범위 +52%, 관통 +3.","effects":{"range_next":0.52,"pierce_next":3}},
	{"id":"u_neck_01","name":"보랏빛 대장장의 목걸이","symbol":"UN","rarity":"unique","slot":"necklace","desc":"전체 지속시간 -8%, 전체 RELOAD -12%.","effects":{"duration_all":-0.08,"reload_all":-0.12}},
	{"id":"u_neck_02","name":"마나 톱니 펜던트","symbol":"UN","rarity":"unique","slot":"necklace","desc":"전체 피해 +15%, 전체 RELOAD -4%.","effects":{"damage_all":0.15,"reload_all":-0.04}},
	{"id":"u_ring_01","name":"운명 복제 반지","symbol":"UO","rarity":"unique","slot":"ring","desc":"같은 칸의 스킬 타격 +2, 피해 -12%, 전체 RELOAD -6%.","effects":{"hits_paired":2,"damage_paired":-0.12,"reload_all":-0.06}},
	{"id":"u_ring_02","name":"피의 공물 반지","symbol":"UO","rarity":"unique","slot":"ring","desc":"전체 흡혈 +4%, 체력 회복 +2.","effects":{"lifesteal_all":0.04,"heal_cycle":2.0}},
	{"id":"u_ring_03","name":"보라색 연륜의 반지","symbol":"UO","rarity":"unique","slot":"ring","desc":"경험치 +18%, 전체 범위 +8%.","effects":{"xp_all":0.18,"range_all":0.08}},
	{"id":"u_brace_01","name":"찰나 무적의 팔찌","symbol":"UB","rarity":"unique","slot":"bracelet","desc":"대시 대기 -20%, 이동 속도 +8%.","effects":{"dash_reload":-0.2,"move_speed":0.08}},
	{"id":"u_brace_02","name":"보라 방벽 팔찌","symbol":"UB","rarity":"unique","slot":"bracelet","desc":"사이클 시작마다 45% 확률로 수호막 +1.","effects":{"shield_cycle_chance":0.45}},

	# HERO 9
	{"id":"h_rapier_01","name":"시간을 찢는 바늘","symbol":"HR","rarity":"hero","slot":"weapon","weapon_type":"rapier","classes":["swordsman"],"desc":"앞뒤 지속시간 -30%, RELOAD -15%, 전체 RELOAD -12%, 피해 -8%.","effects":{"duration_adjacent":-0.3,"reload_adjacent":-0.15,"reload_all":-0.12,"damage_adjacent":-0.08}},
	{"id":"h_greatsword_01","name":"종말을 부르는 대검","symbol":"HG","rarity":"hero","slot":"weapon","weapon_type":"greatsword","classes":["swordsman"],"desc":"다음 스킬 피해 +130%, 지속시간 +45%, RELOAD +30%, 전체 RELOAD -5%.","effects":{"damage_next":1.3,"duration_next":0.45,"reload_next":0.3,"reload_all":-0.05}},
	{"id":"h_dagger_01","name":"천 갈래 분신 단검","symbol":"HD","rarity":"hero","slot":"weapon","weapon_type":"dagger","classes":["swordsman"],"desc":"다음 스킬 타격 +4, 피해 -20%, 전체 RELOAD -8%.","effects":{"hits_next":4,"damage_next":-0.2,"reload_all":-0.08}},
	{"id":"h_spear_01","name":"하늘을 꿰는 천공용창","symbol":"HS","rarity":"hero","slot":"weapon","weapon_type":"spear","classes":["swordsman"],"desc":"다음 스킬 범위 +90%, 피해 +35%, 관통 +6, 전체 RELOAD -6%.","effects":{"range_next":0.9,"damage_next":0.35,"pierce_next":6,"reload_all":-0.06}},
	{"id":"h_neck_01","name":"영웅의 시간 왜곡석","symbol":"HN","rarity":"hero","slot":"necklace","desc":"전체 지속시간 -14%, 전체 RELOAD -20%.","effects":{"duration_all":-0.14,"reload_all":-0.20}},
	{"id":"h_neck_02","name":"붉은 태엽 심장","symbol":"HN","rarity":"hero","slot":"necklace","desc":"전체 피해 +28%, 이동 속도 +10%, 전체 RELOAD -10%.","effects":{"damage_all":0.28,"move_speed":0.1,"reload_all":-0.10}},
	{"id":"h_ring_01","name":"두 번 울리는 왕의 반지","symbol":"HO","rarity":"hero","slot":"ring","desc":"같은 칸의 스킬 타격 +3, 피해 +10%, 전체 RELOAD -8%.","effects":{"hits_paired":3,"damage_paired":0.1,"reload_all":-0.08}},
	{"id":"h_ring_02","name":"죽지 않는 자의 반지","symbol":"HO","rarity":"hero","slot":"ring","desc":"사이클마다 체력 6 회복, 수호막 35%, 전체 RELOAD -10%.","effects":{"heal_cycle":6.0,"shield_cycle_chance":0.35,"reload_all":-0.10}},
	{"id":"h_brace_01","name":"붉은 질풍 팔찌","symbol":"HB","rarity":"hero","slot":"bracelet","desc":"대시 대기 -35%, 전체 RELOAD -12%.","effects":{"dash_reload":-0.35,"reload_all":-0.12}}
]

static func all() -> Array[Dictionary]:
	return ITEMS.duplicate(true)

static func by_id(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item["id"] == id:
			return item.duplicate(true)
	return {}

static func instance(id: String) -> Dictionary:
	return {"kind":"item", "id":id, "rank":1}

static func rarity_name(rarity: String) -> String:
	return String(RARITY_NAMES.get(rarity, "일반"))

static func rarity_color(rarity: String) -> Color:
	return Color(String(RARITY_COLORS.get(rarity, RARITY_COLORS["common"])))

static func part_name(slot_id: String) -> String:
	match slot_id:
		"weapon": return "무기"
		"necklace": return "목걸이"
		"ring": return "반지"
		"bracelet": return "팔찌"
		_: return "아이템"

static func effect_scope(item: Dictionary) -> String:
	var effects: Dictionary = item.get("effects", {})
	var scopes: Array[String] = []
	for key in effects.keys():
		if String(key).ends_with("_all") or key in ["move_speed", "xp_all", "dash_reload", "heal_cycle", "shield_cycle_chance"]:
			if not scopes.has("전체 레일"):
				scopes.append("전체 레일")
	for key in effects.keys():
		if String(key).ends_with("_adjacent"):
			if not scopes.has("앞·뒤 스킬"):
				scopes.append("앞·뒤 스킬")
	for key in effects.keys():
		if String(key).ends_with("_next"):
			if not scopes.has("다음 스킬"):
				scopes.append("다음 스킬")
	for key in effects.keys():
		if String(key).ends_with("_previous"):
			if not scopes.has("이전 스킬"):
				scopes.append("이전 스킬")
	for key in effects.keys():
		if String(key).ends_with("_paired"):
			if not scopes.has("같은 칸의 동시 스킬"):
				scopes.append("같은 칸의 동시 스킬")
	return " + ".join(scopes) if not scopes.is_empty() else "전체 레일"

static func global_reload_reduction(item: Dictionary) -> float:
	var effects: Dictionary = item.get("effects", {})
	return -float(effects.get("reload_all", 0.0))

static func compact_effect(item: Dictionary, max_parts: int = 2) -> String:
	var effects: Dictionary = item.get("effects", {})
	var parts: Array[String] = []
	for key_value in effects.keys():
		var key := String(key_value)
		var value := float(effects[key_value])
		var scope := ""
		if key.ends_with("_all"): scope = "전체 "
		elif key.ends_with("_adjacent"): scope = "앞뒤 "
		elif key.ends_with("_next"): scope = "다음 "
		elif key.ends_with("_previous"): scope = "이전 "
		elif key.ends_with("_paired"): scope = "동시 "
		var sign := "+" if value >= 0.0 else "-"
		var percent := "%s%d%%" % [sign, absi(int(round(value * 100.0)))]
		if key.begins_with("damage_"): parts.append("%s피해 %s" % [scope, percent])
		elif key.begins_with("duration_"): parts.append("%s지속 %s" % [scope, percent])
		elif key.begins_with("reload_"): parts.append("%sR %s" % [scope, percent])
		elif key.begins_with("range_"): parts.append("%s범위 %s" % [scope, percent])
		elif key.begins_with("hits_"): parts.append("%s타격 +%d" % [scope, int(value)])
		elif key.begins_with("pierce_"): parts.append("%s관통 +%d" % [scope, int(value)])
		elif key == "move_speed": parts.append("이동 속도 %s" % percent)
		elif key == "xp_all": parts.append("경험치 %s" % percent)
		elif key == "dash_reload": parts.append("대시 대기 %s" % percent)
		elif key == "heal_cycle": parts.append("사이클 회복 +%d" % int(value))
		elif key == "shield_cycle_chance": parts.append("수호막 %d%%" % int(round(value * 100.0)))
		elif key == "crit_all": parts.append("치명타 %s" % percent)
		elif key == "lifesteal_all": parts.append("흡혈 %s" % percent)
		# YZ: 「방어 R」은 RELOAD인지 RANK인지 읽히지 않아 RELOAD로 풀어 썼다.
		elif key == "shield_reload": parts.append("방어 RELOAD %s" % percent)
		if parts.size() >= max_parts:
			break
	return " · ".join(parts) if not parts.is_empty() else String(item.get("desc", "효과 없음"))

static func price_for(item: Dictionary) -> int:
	return int(RARITY_PRICES.get(String(item.get("rarity", "common")), 28))

static func random_item(rng: RandomNumberGenerator, slot: String = "", character_id: String = "", luck: float = 0.0) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for item: Dictionary in ITEMS:
		if not slot.is_empty() and String(item["slot"]) != slot:
			continue
		if String(item["slot"]) == "weapon" and not character_id.is_empty():
			var classes: Array = item.get("classes", [])
			if not classes.has(character_id):
				continue
		var rarity := String(item.get("rarity", "common"))
		var base_weight := float(RARITY_WEIGHTS.get(rarity, 1))
		var rarity_index := RARITY_ORDER.find(rarity)
		var weight := base_weight * (1.0 + luck * float(rarity_index))
		var copy := item.duplicate(true)
		copy["_weight"] = weight
		candidates.append(copy)
		total_weight += weight
	if candidates.is_empty():
		return {}
	var roll := rng.randf() * total_weight
	for candidate: Dictionary in candidates:
		roll -= float(candidate["_weight"])
		if roll <= 0.0:
			candidate.erase("_weight")
			return candidate
	var fallback: Dictionary = candidates.back()
	fallback.erase("_weight")
	return fallback

static func rarity_counts() -> Dictionary:
	var counts := {"common":0, "rare":0, "unique":0, "hero":0}
	for item: Dictionary in ITEMS:
		var rarity := String(item.get("rarity", "common"))
		counts[rarity] = int(counts.get(rarity, 0)) + 1
	return counts
