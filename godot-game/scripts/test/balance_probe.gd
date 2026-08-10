extends SceneTree

# =============================================================================
# 밸런스 역산 프로브 — **Y8 전면 재작성** (2026-08-10)
# =============================================================================
#   godot --headless --path godot-game -s res://scripts/test/balance_probe.gd
#
# 목적은 하나다: **감이 아니라 계산으로** 보스 HP·마왕 HP·몹 체력·수입을 정한다.
# 게임을 띄우지 않는다. FactoryDeck + RuneEngine.simulate_cycle + StatusEngine을
# 트리 밖에서 돌려 "이 덱이 초당 얼마를 넣는가"를 낸다.
#
# ── 왜 전면 재작성인가 (handoff-y7 §10 항목 1·2) ──────────────────────────────
# 구판은 **v2 유물 위에 서 있었다.**
#   ① 덱 표가 폐기된 각인 id(`edge`·`skip_1`·`barb`·`echo`·`heat_gate`…)를 쓴다.
#      `roll_rune()`이 빈 사전을 돌려주므로 **각인이 한 개도 안 붙은 덱**을 재고 있었다.
#      steps가 어느 행에서나 정확히 5.00이었던 것이 그 증거다(칸당 실행 2회 상한을
#      한 번도 밟지 않았다는 뜻이고, 그건 흐름 각인이 0개일 때만 나오는 값이다).
#   ② `ECHO_POWER`·`CHORUS_POWER`·`LINK_POWER` 셔틀 3그룹을 재현하고 있었다.
#      이 커밋에서 `rune_engine.gd`와 함께 삭제됐다(handoff-y2 §7 삭제 목록).
#   ③ **레일 각인(scope: "rail")을 한 번도 주입하지 않았다.** 5종 중 3종이 피해·시간에
#      직접 곱해지는데 `simulate_cycle(deck, seed, {})`로 불러 전부 빠져 있었다.
#   ④ 일수 축(3·5·7일) v2 표와 스테이지 축 v3 표가 공존해 같은 것을 두 번, 다르게 쟀다.
#
# Y8은 **스테이지 축 하나만** 남기고 v2 표를 걷었다. 각인은 신 15종으로, 레일은
# `deck.rune_opts()`로 주입한다.
#
# ── 이 파일이 지키는 규칙 (구판에서 그대로 승계) ──────────────────────────────
#   * **식을 복제하지 않는다.** HP는 `BossLibrary.hp_for`·`DemonLord.boss_base_health`,
#     dwell 곡선은 `StageClock`의 static, 상태는 `StatusEngine`을 **그대로 부른다.**
#     프로브가 게임과 다른 답을 내는 순간 이 파일은 근거가 아니라 제3의 진실이 된다.
#   * 근사는 전부 **DPS를 과대평가하지 않는 방향**으로 잡는다(= TTK를 짧게 보지 않는다).
#   * `run_all.sh` 규약상 출력에 `=false`가 들어가면 안 되므로 판정은 `pass=1/0`으로 쓴다.
#
# ── Y8이 새로 재는 것 ────────────────────────────────────────────────────────
#   ②  각인 15종 **기대 스텝**(handoff-y7 §10 항목 1의 ⑮)
#   ③  몹 HP **3축 복리 지수** — §5.5가 −25%를 의도했는데 실제는 −59%였다(항목 4·7)
#   ⑦  **골드 여유** — 사건(Y6)·밀정(Y3)·취소(X1) 경제까지 넣은 유입 대 지출(항목 9·10)
#   ⑧  보스 반격 창 `STAGE_BOSS_RELOAD_MUL`의 실효(항목 4)
#   ⑩  충격 프로필 8종의 실전 세기 · pin/pop의 DPS 상승 · haste 4장(항목 13·14·16)
#   ⑪  「맹독 십자」 `status_stack_bonus`(항목 15)

# =============================================================================
# 0. 목표 창 — **오케스트레이터가 Y8에 못 박은 값**
# =============================================================================
# ⚠️ 스테이지 보스 창이 V10의 45~90초에서 **30~60초**로 내려왔다. 근거는 설계 문서가
#    아니라 Y8 지시다(플레이 감각 판단). V10의 45~90은 이 파일의 이력으로만 남긴다.
const BOSS_TTK_MIN := 30.0
const BOSS_TTK_MAX := 60.0
## 마왕 창은 W12 이래 무변경이다.
const DEMON_TTK_MIN := 60.0
const DEMON_TTK_MAX := 120.0
## 몹 HP 3축 복리의 목표 — Y1 이전 대비 **−25% ± 10%p**.
const HP_INDEX_TARGET := 0.75
const HP_INDEX_TOLERANCE := 0.10
## 체류 압박 — d=12에서 레벨업에 드는 시간 배율. 설계 §6.2의 "시간을 두 배 써야 한다".
const DWELL_PRESSURE_TARGET := 2.0
const DWELL_PRESSURE_TOLERANCE := 0.15
## 골드 여유 = (총수입 − 정규지출) / 총수입. 15~30%.
const GOLD_SLACK_MIN := 0.15
const GOLD_SLACK_MAX := 0.30
## 보스 반격 창(초). FEEDBACK_Y §1.6이 "창이 1.3~1.9초"라고 적은 그 창이다.
const RELOAD_WINDOW_MIN := 1.3
const RELOAD_WINDOW_MAX := 1.9

# =============================================================================
# 1. 측정 상수
# =============================================================================
## 사이클 표본 수. 각인 확률(twice·back_one·jump_one·quick·twin_cast·rail_loop)의 평균을 낸다.
const SEEDS := 400
## 상태이상 표본. 도트는 상태를 이월하므로 시드마다 6바퀴를 이어 돌려야 정상 상태가 나온다.
const STATUS_SEEDS := 64
const STATUS_WARMUP_CYCLES := 3
const STATUS_SAMPLE_CYCLES := 3
## 한 스텝이 단일 표적에게 상태를 **몇 번** 부여하는가. `hits`를 그대로 쓰지 않는다 —
## 다타는 대부분 공간적으로 흩어지고(장판 3개 · 운석 3발) 보스는 한 명이라 전부 맞지 않는다.
const STATUS_APPLICATIONS_PER_STEP := 1

## 마왕전에서 실제로 때리고 있는 시간의 비율. 회피·이동·피격 경직을 뭉뚱그린 값이다.
const DEMON_UPTIME := 0.55
## 스테이지 보스전. 마왕(0.55)보다 높다 — 3칸(강화 4칸)·각인 없음이라 겹쳐 오는 패턴이
## 적다. 필드(0.72)보다는 낮다 — 아레나가 좁아 도망칠 공간이 없다.
const BOSS_UPTIME := 0.62
## ⚠️ 위 값은 **가정이다.** 그래서 ⑧은 TTK를 세 값에서 함께 찍는다.
const BOSS_UPTIME_BAND: Array[float] = [0.50, 0.62, 0.72]
## 필드 파밍에서 때리고 있는 시간의 비율.
const FIELD_UPTIME := 0.72
## 필드 킬은 광역이 섞여 단일 표적 DPS를 그대로 쓰면 킬 시간을 과대평가한다.
const FIELD_MULTI_HIT := 1.8
## 기본 공격 주기(초). `player.gd`의 검사 기본값.
const ATTACK_INTERVAL := 0.58
## 레벨 역산의 목표 레벨.
const TARGET_LEVEL := 15
## 스테이지당 낮/밤 주기 수(= dwell 0 → 이 값 − 1). 설계 §2.5 "스테이지당 3~4일"의 아래쪽 끝.
const CYCLES_PER_STAGE := 3
## 상점 카드 1장 정가(1스테이지). ⑦이 구매력 기준으로 쓴다.
const SHOP_ITEM_BASE_PRICE := 45.0

# =============================================================================
# 2. Y1 **이전** 밸런스 상수 — ③ 몹 HP 복리 지수의 대조군
# =============================================================================
# 지어낸 값이 아니라 handoff-y1 §8 표의 「이전」 열 그대로다. 여기 있는 이유는
# "얼마나 물러졌는가"를 재려면 물러지기 전 값이 필요하기 때문이고, 이 세 줄 말고는
# 어떤 옛 상수도 이 파일에 없다.
const PRE_Y1_CYCLE_HEALTH_GAIN := 0.24
const PRE_Y1_STAGE_HP_BASE: Array[float] = [1.00, 1.55, 2.10, 2.65, 3.20]
const PRE_Y1_DWELL_HP_LINEAR := 0.14
const PRE_Y1_DWELL_HP_QUAD := 0.012

# =============================================================================
# 3. v3 스테이지 진행표 — 그 스테이지 보스 앞에 섰을 때의 플레이어
# =============================================================================
# 카드·각인·장비는 "그 스테이지에서 **자연스럽게 갖게 되는** 구성"이다.
#   * 카드 수 = 레벨업 횟수에 걸린다. ⑥이 레벨을 실측하고 그 값과 대조한다.
#   * 칸 각인 = 세공사 구매 + 드래프트(균열·전조·상자·사건). 스테이지당 +1~2가 관측 범위다.
#   * **레일 각인**은 `RAIL_RUNE_CAP`(3)이 상한이라 2·4·5스테이지에서 하나씩 채운다.
#   * 장비 4부위는 상점 의존이라 2·3·4·5에서 하나씩 채운다.
# 트로피는 **직전 스테이지까지** 받은 것이 붙는다(1스테이지 보스 앞에서는 0개).
#
# ⚠️ 각인 id는 전부 **신 15종**이다(§2.1 칸 10 + §2.2 레일 5). 구 id를 다시 쓰면
#    `roll_rune()`이 빈 사전을 돌려주고 그 칸은 조용히 각인 0개가 된다 — 구판이 그랬다.
const V3_STAGES: Array[Dictionary] = [
	{
		"stage": 1,
		"cards": [["cleave", 1], ["flame_field", 1], ["gravity_well", 1]],
		"runes": [[0, "strong"], [1, "twice"]],
		"rail": [], "equipment": [], "trophies": []
	},
	{
		"stage": 2,
		"cards": [["cleave", 1], ["gravity_well", 1], ["flame_field", 2], ["thrust", 1]],
		"runes": [[0, "strong"], [1, "twice"], [2, "wide"]],
		"rail": ["rail_power"],
		"equipment": ["c_greatsword_02"], "trophies": [1]
	},
	{
		"stage": 3,
		"cards": [["cleave", 2], ["gravity_well", 1], ["flame_field", 2], ["whirlwind", 1], ["thrust", 1]],
		"runes": [[0, "strong"], [0, "wide"], [1, "twice"], [2, "twin_cast"]],
		"rail": ["rail_power"],
		"equipment": ["r_greatsword_02", "u_neck_02"], "trophies": [1, 2]
	},
	{
		"stage": 4,
		"cards": [["cleave", 2], ["gravity_well", 2], ["flame_field", 2], ["whirlwind", 2], ["execution", 1]],
		"runes": [[0, "strong"], [0, "wide"], [1, "twice"], [2, "twin_cast"], [3, "back_one"]],
		"rail": ["rail_power", "rail_fast"],
		"equipment": ["r_greatsword_02", "u_neck_02", "r_ring_02"], "trophies": [1, 2, 3]
	},
	{
		"stage": 5,
		"cards": [["cleave", 2], ["gravity_well", 2], ["flame_field", 3], ["whirlwind", 2], ["execution", 2]],
		"runes": [[0, "strong"], [0, "wide"], [1, "twice"], [2, "twin_cast"], [3, "back_one"], [4, "first_hit"], [4, "strong"]],
		"rail": ["rail_power", "rail_fast", "rail_rest"],
		"equipment": ["r_greatsword_02", "u_neck_02", "r_ring_02", "r_brace_02"], "trophies": [1, 2, 3, 4]
	}
]

## 같은 레벨·같은 장비에서 **덱 축만** 바꿔 분산을 본다.
##   oil_fire  기름(gravity_well·sword_rain) → 불(flame_field·meteor_blade) = 대폭 연소
##   poison    독 축적(whirlwind·execution·cross_cut) + 타격 마무리(터뜨리기)
##   no_status 상태를 한 톨도 안 만드는 순수 직격 덱 — 상태 레이어의 값을 재는 대조군
##   flow      흐름 각인 몰빵 — 칸당 실행 2회 상한을 실제로 밟는 덱(§1.2가 만든 새 경제)
const AXIS_DECKS: Array[Dictionary] = [
	{
		"name": "oil_fire",
		"cards": [["gravity_well", 2], ["flame_field", 3], ["sword_rain", 1], ["meteor_blade", 1], ["cleave", 2]],
		"runes": [[0, "strong"], [1, "wide"], [1, "twice"], [2, "twin_cast"], [3, "back_one"], [4, "first_hit"]],
		"rail": ["rail_power", "rail_color", "rail_fast"]
	},
	{
		"name": "poison",
		"cards": [["whirlwind", 2], ["execution", 2], ["cross_cut", 2], ["cleave", 2], ["thrust", 2]],
		"runes": [[0, "wide"], [1, "strong"], [2, "twin_cast"], [3, "twice"], [4, "back_one"], [4, "wide"]],
		"rail": ["rail_power", "rail_fast", "rail_rest"]
	},
	{
		"name": "no_status",
		"cards": [["cleave", 2], ["thrust", 2], ["rapid_slash", 2], ["dragon_pierce", 1], ["echo_thrust", 1]],
		"runes": [[0, "strong"], [0, "wide"], [1, "twice"], [2, "twin_cast"], [3, "back_one"], [4, "strong"]],
		"rail": ["rail_power", "rail_fast", "rail_rest"]
	},
	{
		"name": "flow",
		"cards": [["cleave", 2], ["execution", 2], ["flame_field", 2], ["whirlwind", 2], ["thrust", 2]],
		"runes": [[0, "twice"], [1, "trade_skip"], [2, "back_one"], [3, "jump_one"], [4, "twice"], [4, "quick"]],
		"rail": ["rail_loop", "rail_power", "rail_rest"]
	}
]

## ② 각인 기대 스텝 표의 기준 덱. 원소를 섞어 공명이 **성립하지 않게** 놓았다 —
## 공명이 걸리면 각인 효과와 배치 효과가 섞여 각인 하나의 기여를 못 읽는다.
const RUNE_BENCH_CARDS: Array = [
	["cleave", 1], ["flame_field", 1], ["thrust", 1], ["gravity_well", 1], ["whirlwind", 1]
]
## `finisher`(cond: kill)만 처치가 있어야 굴러간다. 그 행만 이 확률을 준다.
const RUNE_BENCH_KILL_CHANCE := 0.35


func _initialize() -> void:
	print("BALANCE_PROBE_BEGIN godot=%s" % Engine.get_version_info()["string"])

	var stage_rows := _measure_all_stages()

	print("")
	_print_stage_power_table(stage_rows)

	print("")
	var rune_ok := _print_rune_step_table()

	print("")
	var run_curve := _print_run_curve_table(stage_rows)

	print("")
	var hp_ok := _print_hp_index_table(run_curve)

	print("")
	var curve_ok := _print_dwell_curve_table()

	print("")
	var pressure_ok := _print_dwell_pressure_table(stage_rows, run_curve)

	print("")
	var volume_ok := _print_volume_table()

	print("")
	var gold_ok := _print_economy_table(run_curve)

	print("")
	var boss_ok := _print_stage_boss_table(stage_rows)

	print("")
	var demon_ok := _print_demon_table(run_curve)

	print("")
	_print_impact_table(stage_rows)

	print("")
	_print_growth_cap_table(run_curve)

	var all_ok := rune_ok and hp_ok and curve_ok and pressure_ok and volume_ok \
		and gold_ok and boss_ok and demon_ok
	print("")
	print("BALANCE_PROBE_COMPLETE pass=%d rune_steps=%d hp_index=%d dwell_curve=%d dwell_pressure=%d volume=%d gold=%d boss_ttk=%d demon_ttk=%d" % [
		1 if all_ok else 0,
		1 if rune_ok else 0, 1 if hp_ok else 0, 1 if curve_ok else 0,
		1 if pressure_ok else 0, 1 if volume_ok else 0, 1 if gold_ok else 0,
		1 if boss_ok else 0, 1 if demon_ok else 0
	])
	quit(0)


# =============================================================================
# 덱 조립
# =============================================================================
## 카드·칸 각인·**레일 각인**·장비를 붙인 덱 하나. 레일을 빠뜨리면 5종 중 3종이
## 피해·시간에 직접 곱해지는데 그게 통째로 사라진다(구판의 함정 ③).
func _build_deck(spec: Dictionary) -> FactoryDeck:
	var deck := FactoryDeck.new()
	deck.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var cards: Array = spec.get("cards", [])
	for index in cards.size():
		var pair: Array = cards[index]
		deck.place_card(index, DealCardLibrary.instance(String(pair[0]), int(pair[1])))
	for entry in (spec.get("runes", []) as Array):
		var pair: Array = entry
		deck.attach_rune(int(pair[0]), RuneEngine.roll_rune(String(pair[1]), rng))
	for rail_id in (spec.get("rail", []) as Array):
		deck.attach_rail_rune(RuneEngine.roll_rune(String(rail_id), rng))
	for item_id in (spec.get("equipment", []) as Array):
		deck.equip(ItemLibrary.instance(String(item_id)))
	return deck


## 덱이 실제로 몇 개의 각인을 들고 있는가. **구판이 0이었던 것을 잡는 안전망**이다 —
## 구 id를 쓰면 여기가 0으로 떨어지고 ②의 판정이 즉시 빨개진다.
func _rune_census(deck: FactoryDeck) -> Dictionary:
	return {"slot": deck.total_rune_count(), "rail": deck.rail_rune_count()}


# =============================================================================
# 화력 측정 — 직격 + 상태이상 + 평타
# =============================================================================
## `player.gd::_rebuild_stats()`의 **피해 축만** 재현한다.
##   기저 16 → 적용 스킬(피해에 관여하는 3종) → 장비 damage 합 → 트로피(합 뒤 곱)
## ⚠️ 여기서 값을 지어내지 않는다 — 장비는 `ItemLibrary`, 트로피는 `TrophyLibrary`가 준다.
func _player_damage(cards: Array, equipment: Array, trophy_stages: Array) -> float:
	var damage := 16.0
	for entry in cards:
		match String((entry as Array)[0]):
			"cleave": damage *= 1.12
			"overclock": damage *= 1.34
			"blood_pact": damage += 2.0
			_: pass
	for item_id in equipment:
		damage += float(ItemLibrary.by_id(String(item_id)).get("damage", 0.0))
	var merged := TrophyLibrary.merge_effects(trophy_stages)
	damage += float(merged.get("damage", 0.0))
	damage *= float(merged.get("damage_mul", 1.0))
	return damage


## 기대 치명타 배율. 트로피 `crit`까지 반영한다(기본 5% · 배율 1.8).
func _crit_expected(trophy_stages: Array) -> float:
	var merged := TrophyLibrary.merge_effects(trophy_stages)
	var chance := clampf(0.05 + float(merged.get("crit", 0.0)), 0.0, 1.0)
	return 1.0 + chance * 0.8


## 카드 1회 실행이 **단일 표적**에게 넣는 타격 총합(= damage × hits).
## `random_impacts` 카드(운석검 3발 · 검우 7발)는 착탄점이 흩어지므로 1발만 센다.
## 투사체 수(`projectiles`)도 세지 않는다 — 표적 1기에 1발만 맞는다고 본다.
func _card_units(deck: FactoryDeck, slot_index: int) -> float:
	var card := deck.compile_slot(slot_index)
	if card.is_empty():
		return 0.0
	var hits := maxi(1, int(card.get("hits", 1)))
	if bool(card.get("random_impacts", false)):
		hits = 1
	return float(card.get("damage", 0.0)) * float(hits)


## 한 스텝이 단일 표적에게 넣는 "카드 피해 단위"(player.damage를 곱하기 전).
## Y8: 셔틀(link/echo/chorus/overlap) 네 갈래가 **삭제됐다.** 남은 동시 발동은
## `twin_cast` 하나뿐이고, 그 값은 `RuneEngine.TWIN_POWER`(0.5)다.
## 직전 칸은 `steps[i-1]["slot"]`으로 정확히 안다(구판은 `slot-1`로 추측했다).
func _step_units(deck: FactoryDeck, steps: Array, index: int) -> float:
	var step: Dictionary = steps[index]
	var slot_index := int(step.get("slot", 0))
	var damage_mul := float(step.get("damage_mul", 1.0))
	var sum := _card_units(deck, slot_index) * damage_mul
	var fired: Array = step.get("fired", [])
	if fired.has("twin_cast") and index > 0:
		var previous := int((steps[index - 1] as Dictionary).get("slot", 0))
		sum += _card_units(deck, previous) * damage_mul * RuneEngine.TWIN_POWER
	if String(step.get("reaction", "")) == "shock":
		sum += _card_units(deck, slot_index) * damage_mul * RuneEngine.SHOCK_SPLASH
	return sum


## 흐름만 재는 가벼운 측정(상태이상 없음). ②의 각인 기대 스텝 표가 쓴다.
func _measure_flow(deck: FactoryDeck, seeds: int, kill_chance: float = 0.0) -> Dictionary:
	var rune_deck: Array = deck.rune_deck()
	var opts := deck.rune_opts()
	if kill_chance > 0.0:
		opts["kill_chance"] = kill_chance
	var steps_sum := 0.0
	var exec_slots_sum := 0.0
	var units_sum := 0.0
	var time_sum := 0.0
	var reload_sum := 0.0
	var overloads := 0
	var max_steps := 0
	for index in seeds:
		var cycle := RuneEngine.simulate_cycle(rune_deck, 1000003 + index * 7919, opts)
		var steps: Array = cycle.get("steps", [])
		steps_sum += float(steps.size())
		max_steps = maxi(max_steps, steps.size())
		reload_sum += float(cycle.get("reload", 0.0))
		if String(cycle.get("end_reason", "")) == "overload":
			overloads += 1
		for used in (cycle.get("slot_exec", []) as Array):
			if int(used) > 0:
				exec_slots_sum += 1.0
		var cycle_time := float(cycle.get("reload", 0.0))
		for i in steps.size():
			var step: Dictionary = steps[i]
			cycle_time += maxf(DealCycleController.MIN_STEP_DURATION, float(step.get("duration", 0.0)))
			units_sum += _step_units(deck, steps, i)
		time_sum += cycle_time
	var count := float(maxi(seeds, 1))
	return {
		"steps": steps_sum / count,
		"max_steps": max_steps,
		"exec_slots": exec_slots_sum / count,
		"cycle_time": time_sum / count,
		"reload": reload_sum / count,
		"units_per_cycle": units_sum / count,
		"units_per_second": units_sum / maxf(time_sum, 0.01),
		"overload_rate": float(overloads) / count
	}


## 덱 하나가 **단일 표적**에게 넣는 초당 피해를 상태이상까지 포함해 낸다.
##
## 모델(런타임 경로를 그대로 옮긴 것):
##   ① 직격  `_step_units()` × player.damage × 기대치명타
##   ② 상태  스텝의 원소를 `StatusEngine.apply()`에 꽂고
##           ㄱ. 즉발 이벤트(E_DAMAGE / E_AOE_DAMAGE)를 더한다
##           ㄴ. 스텝 duration만큼 `tick_dot()`을 돌려 도트를 걷는다
##           ㄷ. 직격 보정(기름 ×2.2 · 전 표식 +12%)은 `apply()` **전에** 묻는다
##           ㄹ. `status_stack_bonus`(맹독 십자 2.0)를 ctx에 실는다 — Y7이 켠 채널이다
##   ③ 평타  player.damage × 기대치명타 / attack_interval  (사이클과 병행)
##
## 근사(전부 DPS를 과대평가하지 않는 방향):
##   * `E_CHAIN_DAMAGE`(전도)·`E_SPREAD_STATUS`(기름 전파)는 **세지 않는다.**
##     표적이 보스 한 명이라 도약할 곳도 옮겨붙을 곳도 없다.
##   * 스텝당 상태 부여는 `hits`와 무관하게 1회.
## `status_enabled`가 false면 상태 레이어를 통째로 끈다 — **마왕 전용**이다
## (`combat_resolver`의 `status_eligible`가 마왕만 면역으로 둔다).
func _measure_dps(spec: Dictionary, status_enabled: bool = true,
		reload_scale: float = 1.0) -> Dictionary:
	var deck := _build_deck(spec)
	var player_damage := _player_damage(spec.get("cards", []),
		spec.get("equipment", []), spec.get("trophies", []))
	var crit := _crit_expected(spec.get("trophies", []))
	var rune_deck: Array = deck.rune_deck()
	var opts := deck.rune_opts()
	if not is_equal_approx(reload_scale, 1.0):
		opts["reload_scale"] = reload_scale

	var direct_total := 0.0
	var status_total := 0.0
	var time_total := 0.0
	var steps_total := 0.0
	var reload_total := 0.0
	var cycles := 0
	var reaction_names: Dictionary = {}

	for seed_index in STATUS_SEEDS:
		var state := StatusEngine.make_state()
		var budget := StatusEngine.make_budget()
		for cycle_index in (STATUS_WARMUP_CYCLES + STATUS_SAMPLE_CYCLES):
			var counting := cycle_index >= STATUS_WARMUP_CYCLES
			var cycle: Dictionary = RuneEngine.simulate_cycle(
				rune_deck, 1000003 + (seed_index * (cycle_index + 1)) * 7919, opts)
			var steps: Array = cycle.get("steps", [])
			var cycle_direct := 0.0
			var cycle_status := 0.0
			var cycle_time := float(cycle.get("reload", 0.0))
			for i in steps.size():
				var step: Dictionary = steps[i]
				var duration := maxf(DealCycleController.MIN_STEP_DURATION, float(step.get("duration", 0.0)))
				cycle_time += duration
				var slot_index := int(step.get("slot", 0))
				var card := deck.compile_slot(slot_index)
				var units := _step_units(deck, steps, i)
				var damage_mul := float(step.get("damage_mul", 1.0))
				var element := String(card.get("element", ""))
				var potency := maxf(0.0, float(step.get("potency", 1.0)))
				# 카드 1타의 피해(= 런타임 `_cycle_damage_value`). 상태의 P가 이 값이다.
				var per_hit := float(card.get("damage", 0.0)) * damage_mul * player_damage * crit
				var direct := units * player_damage * crit
				if status_enabled and not element.is_empty():
					StatusEngine.budget_reset(budget)
					for _application in STATUS_APPLICATIONS_PER_STEP:
						var incoming := StatusEngine.incoming_multiplier(state, element)
						var shock := StatusEngine.consume_shock(state)
						direct *= incoming * shock
						var result := StatusEngine.apply(state, element, 1.0, {
							"damage": per_hit, "potency": potency, "depth": 0, "budget": budget,
							"stack_bonus": float(card.get("status_stack_bonus", 1.0))
						})
						for event_entry in (result.get("events", []) as Array):
							var event: Dictionary = event_entry
							var kind := String(event.get("kind", ""))
							if kind == StatusEngine.E_DAMAGE or kind == StatusEngine.E_AOE_DAMAGE:
								cycle_status += maxf(0.0, float(event.get("damage", 0.0)))
						for reaction in (result.get("reactions", []) as Array):
							reaction_names[String(reaction)] = true
				cycle_direct += direct
				cycle_status += StatusEngine.tick_dot(state, duration)
			# RELOAD 동안에도 도트는 계속 탄다.
			cycle_status += StatusEngine.tick_dot(state, float(cycle.get("reload", 0.0)))
			if counting:
				direct_total += cycle_direct
				status_total += cycle_status
				time_total += cycle_time
				steps_total += float(steps.size())
				reload_total += float(cycle.get("reload", 0.0))
				cycles += 1

	var samples := maxf(float(cycles), 1.0)
	var cycle_dps := (direct_total + status_total) / maxf(time_total, 0.01)
	var attack_dps := player_damage * crit / ATTACK_INTERVAL
	var census := _rune_census(deck)
	return {
		"player_damage": player_damage,
		"crit": crit,
		"steps": steps_total / samples,
		"cycle_time": time_total / samples,
		"reload": reload_total / samples,
		"direct_dps": direct_total / maxf(time_total, 0.01),
		"status_dps": status_total / maxf(time_total, 0.01),
		"cycle_dps": cycle_dps,
		"attack_dps": attack_dps,
		"raw_dps": cycle_dps + attack_dps,
		"status_share": (status_total / maxf(time_total, 0.01)) / maxf(cycle_dps + attack_dps, 0.01),
		"slot_runes": int(census["slot"]),
		"rail_runes": int(census["rail"]),
		"reactions": reaction_names.keys()
	}


func _measure_all_stages() -> Array:
	var rows: Array = []
	for spec: Dictionary in V3_STAGES:
		var measured := _measure_dps(spec, true)
		measured["stage"] = int(spec["stage"])
		rows.append(measured)
	return rows


# =============================================================================
# ① 스테이지별 플레이어 화력
# =============================================================================
func _print_stage_power_table(stage_rows: Array) -> void:
	print("--- ① 스테이지별 단일표적 화력 (상태 시드 %d × %d바퀴) ---" % [
		STATUS_SEEDS, STATUS_SAMPLE_CYCLES])
	print("    각인은 신 15종만 쓴다. 레일 각인은 `deck.rune_opts()`로 주입한다.")
	print("%-4s %6s %6s %8s %8s %8s %9s %9s %8s %9s %7s" % [
		"st", "칸각인", "레일", "dmg", "steps", "cycle_s", "직격dps", "상태dps", "평타dps", "raw_dps", "상태%"])
	for row_value in stage_rows:
		var row: Dictionary = row_value
		print("%-4d %6d %6d %8.1f %8.2f %8.2f %9.1f %9.1f %8.1f %9.1f %6.0f%%" % [
			int(row["stage"]), int(row["slot_runes"]), int(row["rail_runes"]),
			float(row["player_damage"]), float(row["steps"]), float(row["cycle_time"]),
			float(row["direct_dps"]), float(row["status_dps"]), float(row["attack_dps"]),
			float(row["raw_dps"]), float(row["status_share"]) * 100.0
		])
	print("")
	print("  덱 축별 분산 (5스테이지 장비·트로피 고정 · 덱과 각인만 교체):")
	print("  %-10s %6s %6s %7s %8s %9s %9s %9s   %s" % [
		"deck", "칸", "레일", "steps", "cycle_s", "직격dps", "상태dps", "raw_dps", "발화 시너지"])
	var last: Dictionary = V3_STAGES[V3_STAGES.size() - 1]
	for axis: Dictionary in AXIS_DECKS:
		var spec := axis.duplicate(true)
		spec["equipment"] = last["equipment"]
		spec["trophies"] = last["trophies"]
		var measured := _measure_dps(spec, true)
		var reactions: Array = measured["reactions"]
		reactions.sort()
		print("  %-10s %6d %6d %7.2f %8.2f %9.1f %9.1f %9.1f   %s" % [
			axis["name"], int(measured["slot_runes"]), int(measured["rail_runes"]),
			float(measured["steps"]), float(measured["cycle_time"]),
			float(measured["direct_dps"]), float(measured["status_dps"]), float(measured["raw_dps"]),
			",".join(PackedStringArray(reactions)) if not reactions.is_empty() else "없음"
		])


# =============================================================================
# ② 각인 15종 기대 스텝 (handoff-y7 §10 항목 1의 ⑮)
# =============================================================================
# "이 각인 하나를 붙이면 한 바퀴가 어떻게 달라지는가"를 15줄로 낸다.
# 각인 인스턴스는 **저작 범위의 한가운데**로 고정한다(`roll_rune`의 난수를 쓰지 않는다) —
# 표가 시드마다 흔들리면 대조표로 쓸 수 없다.
#
# 계약 3개(판정에 들어간다)
#   ㄱ. 15종 전부 표에 나온다(카탈로그가 15개다).
#   ㄴ. 어느 각인에서도 `end_reason == "overload"`가 **0건**이다(§1.3 종료성 증명).
#   ㄷ. 어느 각인에서도 한 바퀴 스텝이 `SLOT_EXEC_CAP × 칸수`(=10)를 넘지 않는다.
func _print_rune_step_table() -> bool:
	print("--- ② 각인 15종 기대 스텝 (기준 덱 5칸 · 시드 %d개) ---" % SEEDS)
	var base_spec: Dictionary = {"cards": RUNE_BENCH_CARDS, "runes": [], "rail": [], "equipment": []}
	var base_deck := _build_deck(base_spec)
	var base := _measure_flow(base_deck, SEEDS)
	print("    기준(각인 0개): steps %.2f · 밟은 칸 %.2f · 한 바퀴 %.2fs · RELOAD %.2fs · 초당피해단위 %.2f" % [
		float(base["steps"]), float(base["exec_slots"]), float(base["cycle_time"]),
		float(base["reload"]), float(base["units_per_second"])
	])
	print("%-12s %6s %6s %8s %8s %8s %9s %9s %9s %8s" % [
		"각인", "범위", "등급", "steps", "밟은칸", "cycle_s", "RELOAD", "초당단위", "Δ단위", "최대스텝"])
	var all_ok := true
	var seen := 0
	var ids: Array[String] = RuneEngine.all_rune_ids()
	ids.sort()
	# 범위(칸/레일)로 갈라 읽기 쉽게 둔다 — 표에서 두 계열이 섞이면 비교가 안 된다.
	for scope in ["slot", "rail"]:
		for id in ids:
			var definition: Dictionary = RuneEngine.RUNES[id]
			if RuneEngine.rune_scope(id) != scope:
				continue
			seen += 1
			var instance := _mid_instance(id)
			var spec: Dictionary = {"cards": RUNE_BENCH_CARDS, "runes": [], "rail": [], "equipment": []}
			var deck := _build_deck(spec)
			if scope == "slot":
				deck.attach_rune(2, instance)
			else:
				deck.attach_rail_rune(instance)
			var kill_chance := RUNE_BENCH_KILL_CHANCE if String(definition["cond"]) == "kill" else 0.0
			var measured := _measure_flow(deck, SEEDS, kill_chance)
			var attached := deck.total_rune_count() + deck.rail_rune_count()
			var row_ok := attached == 1 \
				and is_zero_approx(float(measured["overload_rate"])) \
				and int(measured["max_steps"]) <= RuneEngine.SLOT_EXEC_CAP * RuneEngine.SLOT_COUNT
			all_ok = all_ok and row_ok
			var delta := float(measured["units_per_second"]) - float(base["units_per_second"])
			print("%-12s %6s %6s %8.2f %8.2f %8.2f %9.2f %9.2f %+9.2f %8d%s" % [
				id, scope, String(definition["rarity"]).substr(0, 4),
				float(measured["steps"]), float(measured["exec_slots"]), float(measured["cycle_time"]),
				float(measured["reload"]), float(measured["units_per_second"]), delta,
				int(measured["max_steps"]),
				"" if row_ok else "   OUT"
			])
	var catalog_ok := seen == RuneEngine.RUNES.size() and seen == 15
	all_ok = all_ok and catalog_ok
	print("→ 카탈로그 %d종 · 종료성 위반 0건 · 스텝 상한 %d 준수 = %d" % [
		seen, RuneEngine.SLOT_EXEC_CAP * RuneEngine.SLOT_COUNT, 1 if all_ok else 0])
	print("  (`finisher`만 처치 확률 %.2f를 준다 — cond가 kill이라 처치가 없으면 굴러가지 않는다.)" % RUNE_BENCH_KILL_CHANCE)
	return all_ok


## 저작 범위 한가운데의 각인 인스턴스. `roll_rune`의 난수를 쓰지 않는다(표 결정성).
func _mid_instance(id: String) -> Dictionary:
	var definition: Dictionary = RuneEngine.RUNES[id]
	return {
		"id": id,
		"p": (float(definition["p_min"]) + float(definition["p_max"])) * 0.5,
		"mag": (float(definition["mag_min"]) + float(definition["mag_max"])) * 0.5
	}


# =============================================================================
# ③ 몹 HP 3축 복리 지수 — §5.5가 −25%를 의도했는데 실제는 −59%였다
# =============================================================================
# handoff-y1 §8이 남긴 사실: `STAGE_HP_BASE` 행만 보면 −25%인데 세 축이 곱해져
# 5스테이지·dwell 12·power 13.6에서 **−59%**가 됐다.
#
# 이 표는 그 곱을 **런에서 실제로 지나는 자리마다** 다시 잰다. 대조군은 Y1 이전 값이고
# (이 파일 §2), 실측 power_level은 ⑥ 통산 곡선이 낸 일수·레벨에서 온다 —
# 지어낸 숫자가 하나도 없다.
#
#   지수 = Π(축)  /  Π(축, Y1 이전)   ·  스테이지 5개의 **기하평균**
#   (산술평균이 아니라 기하평균인 이유: HP는 곱해지는 양이고, 배수의 중간은 곱의 제곱근이다)
func _print_hp_index_table(run_curve: Array) -> bool:
	print("--- ③ 몹 HP 3축 복리 지수 (Y1 이전 대비 · 목표 %.0f%% ± %.0f%%p) ---" % [
		HP_INDEX_TARGET * 100.0, HP_INDEX_TOLERANCE * 100.0])
	print("    축 3개 = `STAGE_HP_BASE` × `H(dwell)` × `(1 + CYCLE_HEALTH_GAIN × power)`")
	print("    이전 = %.2f / H(d)=1+%.2fd+%.3fd² / gain %.2f" % [
		PRE_Y1_STAGE_HP_BASE[4], PRE_Y1_DWELL_HP_LINEAR, PRE_Y1_DWELL_HP_QUAD, PRE_Y1_CYCLE_HEALTH_GAIN])
	print("    현행 = %.2f / H(d)=1+%.2fd+%.3fd² / gain %.2f" % [
		GameTuning.STAGE_HP_BASE[4], GameTuning.DWELL_HP_LINEAR, GameTuning.DWELL_HP_QUAD,
		MonsterLibrary.CYCLE_HEALTH_GAIN])
	print("%-4s %7s %8s %9s %9s %9s %9s %9s %8s" % [
		"st", "power", "dwell", "stage×", "dwell×", "power×", "이전HP", "현행HP", "지수"])
	var product := 1.0
	var count := 0
	for row_value in run_curve:
		var row: Dictionary = row_value
		var stage := int(row["stage"])
		var power := float(row["power"])
		var dwell := CYCLES_PER_STAGE - 1
		var stage_ratio := GameTuning.STAGE_HP_BASE[stage - 1] / PRE_Y1_STAGE_HP_BASE[stage - 1]
		var dwell_ratio := StageClock.dwell_hp(dwell) / _pre_y1_dwell_hp(dwell)
		var power_ratio := (1.0 + MonsterLibrary.CYCLE_HEALTH_GAIN * power) \
			/ (1.0 + PRE_Y1_CYCLE_HEALTH_GAIN * power)
		# 절대 HP는 그 스테이지 풀의 가중 평균 몹으로 낸다(`MonsterLibrary.stage_pool` 정본).
		var units: float = float(_stage_pool_stats(stage)["health_units"])
		var before := units * PRE_Y1_STAGE_HP_BASE[stage - 1] * _pre_y1_dwell_hp(dwell) \
			* (1.0 + PRE_Y1_CYCLE_HEALTH_GAIN * power)
		var after := units * GameTuning.STAGE_HP_BASE[stage - 1] * StageClock.dwell_hp(dwell) \
			* (1.0 + MonsterLibrary.CYCLE_HEALTH_GAIN * power)
		var index := after / maxf(before, 0.01)
		product *= index
		count += 1
		print("%-4d %7.2f %8d %9.3f %9.3f %9.3f %9.0f %9.0f %8.3f" % [
			stage, power, dwell, stage_ratio, dwell_ratio, power_ratio, before, after, index])
	var geometric := pow(product, 1.0 / maxf(float(count), 1.0))
	# handoff-y1이 남긴 극단 좌표도 함께 찍는다 — 문서의 −59%가 지금 얼마인지 보이게.
	var corner_before := PRE_Y1_STAGE_HP_BASE[4] * _pre_y1_dwell_hp(12) * (1.0 + PRE_Y1_CYCLE_HEALTH_GAIN * 13.6)
	var corner_after := GameTuning.STAGE_HP_BASE[4] * StageClock.dwell_hp(12) * (1.0 + MonsterLibrary.CYCLE_HEALTH_GAIN * 13.6)
	print("→ 기하평균 지수 **%.3f** (= %+.1f%%). 목표 %.2f ± %.2f" % [
		geometric, (geometric - 1.0) * 100.0, HP_INDEX_TARGET, HP_INDEX_TOLERANCE])
	print("→ handoff-y1의 극단 좌표(5st · dwell 12 · power 13.6): %.1f → %.1f = %+.1f%%" % [
		corner_before, corner_after, (corner_after / corner_before - 1.0) * 100.0])
	print("→ hellhound @ power 13.6 = %.0f HP (Y1 이전 %.0f · FEEDBACK_Y §5.5는 560이라 적었다)" % [
		MonsterLibrary.health_for(MonsterLibrary.by_id("hellhound"), 13.6),
		MonsterLibrary.BASE_SLASH_DAMAGE * 10.0 * (1.0 + PRE_Y1_CYCLE_HEALTH_GAIN * 13.6)])
	var ok := absf(geometric - HP_INDEX_TARGET) <= HP_INDEX_TOLERANCE
	print("몹 HP 체감 창 통과 = %d" % (1 if ok else 0))
	return ok


func _pre_y1_dwell_hp(d: int) -> float:
	var f := float(maxi(d, 0))
	return 1.0 + PRE_Y1_DWELL_HP_LINEAR * f + PRE_Y1_DWELL_HP_QUAD * f * f


# =============================================================================
# ④ dwell 곡선 대조표 — **실측** (handoff-y7 §10 항목 5)
# =============================================================================
# 구판은 설계 §6.2 원문 표(구 상수 기준)와 대조해 9행 중 8행이 MISMATCH였다.
# 그 표는 Y1이 상수를 내리면서 낡았다. Y8은 **상수에서 다시 계산한 표**를 싣고
# `--stage-test`의 같은 표(`curve_rows`)와 **행 단위로 같은 값**이 되게 맞춘다.
func _print_dwell_curve_table() -> bool:
	print("--- ④ dwell 곡선 (현행 상수 실측 · `--stage-test` curve_rows와 동일해야 한다) ---")
	print("    H(d) = 1 + %.2fd + %.3fd²  ·  A(d) = 1 + %.2fd + %.3fd²  ·  XP× = H^%.1f  ·  골드× = H^%.1f" % [
		GameTuning.DWELL_HP_LINEAR, GameTuning.DWELL_HP_QUAD,
		GameTuning.DWELL_DAMAGE_LINEAR, GameTuning.DWELL_DAMAGE_QUAD,
		GameTuning.DWELL_XP_EXPONENT, GameTuning.DWELL_GOLD_EXPONENT])
	print("%-4s %8s %8s %8s %8s %8s %8s %8s %11s %9s" % [
		"d", "HP×", "피해×", "속도×", "물량+", "정예%", "XP×", "골드×", "효율(XP/HP)", "1/효율"])
	var all_ok := true
	var last_efficiency := 99.0
	for d in [0, 1, 2, 3, 4, 6, 8, 10, 12]:
		var efficiency := StageClock.dwell_kill_efficiency(d)
		# 단조 감소 — 한 지점이라도 올라가면 "오래 머물수록 손해"가 거짓말이 된다.
		var row_ok := efficiency < last_efficiency
		last_efficiency = efficiency
		all_ok = all_ok and row_ok
		print("%-4d %8.3f %8.3f %8.3f %8d %8.1f %8.3f %8.3f %11.3f %9.3f%s" % [
			d, StageClock.dwell_hp(d), StageClock.dwell_damage(d), StageClock.dwell_speed(d),
			StageClock.dwell_count_bonus(d), StageClock.dwell_elite_ratio(d) * 100.0,
			StageClock.dwell_xp(d), StageClock.dwell_gold(d), efficiency, 1.0 / maxf(efficiency, 0.0001),
			"" if row_ok else "   OUT"
		])
	# 상한 3개가 실제로 물려 있는가.
	var caps_ok := is_equal_approx(StageClock.dwell_speed(9999), GameTuning.DWELL_SPEED_CAP) \
		and is_equal_approx(StageClock.dwell_elite_ratio(9999), GameTuning.DWELL_ELITE_CAP) \
		and StageClock.dwell_count_bonus(9999) == StageClock.dwell_count_bonus(GameTuning.DWELL_COUNT_SATURATION)
	# Y2가 등식에서 부등식으로 갈아 놓은 불변식(handoff-y2 §4.2). 값이 바뀌어도 이 관계는 산다.
	var slope_ok := GameTuning.DWELL_DAMAGE_LINEAR < GameTuning.DWELL_HP_LINEAR \
		and GameTuning.DWELL_DAMAGE_LINEAR * 2.0 > GameTuning.DWELL_HP_LINEAR
	# 보상 지수: 0 < 골드 < XP < 1. 1.0이면 감쇠가 없다는 뜻이다.
	var exponent_ok := GameTuning.DWELL_XP_EXPONENT > 0.0 and GameTuning.DWELL_XP_EXPONENT < 1.0 \
		and GameTuning.DWELL_GOLD_EXPONENT < GameTuning.DWELL_XP_EXPONENT \
		and GameTuning.DWELL_GOLD_EXPONENT > 0.0
	all_ok = all_ok and caps_ok and slope_ok and exponent_ok
	print("→ 상한 3종 %d · 기울기 부등식(%.2f < %.2f < %.2f) %d · 보상 지수 %d" % [
		1 if caps_ok else 0,
		GameTuning.DWELL_DAMAGE_LINEAR, GameTuning.DWELL_HP_LINEAR,
		GameTuning.DWELL_DAMAGE_LINEAR * 2.0,
		1 if slope_ok else 0, 1 if exponent_ok else 0])
	print("dwell 곡선 정합 = %d" % (1 if all_ok else 0))
	return all_ok


# =============================================================================
# ⑤ 체류 압박 실측 (handoff-y7 §10 항목 6)
# =============================================================================
# 효율 비율은 §6.2 식만으로 정해지지만 **체감**은 "몇 분 더 걸리느냐"로 온다.
# 실제 몹 체력·실제 XP·①에서 잰 실제 DPS를 물려 절대 시간을 낸다.
func _print_dwell_pressure_table(stage_rows: Array, run_curve: Array) -> bool:
	print("--- ⑤ 체류 압박 — 레벨 %d 도달 역산 (스테이지 1) ---" % TARGET_LEVEL)
	var first: Dictionary = stage_rows[0]
	var effective_dps := float(first["raw_dps"]) * FIELD_UPTIME * FIELD_MULTI_HIT
	var pool := _stage_pool_stats(1)
	var power := float((run_curve[0] as Dictionary)["power"])
	var base_health := float(pool["health_units"]) * GameTuning.STAGE_HP_BASE[0] \
		* (1.0 + MonsterLibrary.CYCLE_HEALTH_GAIN * power)
	var base_xp := float(pool["xp"])
	var xp_needed := _xp_to_level(TARGET_LEVEL)
	print("    1스테이지 표준 몹 HP %.1f(power %.2f) · XP %.2f · 실효 DPS %.1f (raw %.1f × uptime %.2f × 동시타격 %.1f)" % [
		base_health, power, base_xp, effective_dps, float(first["raw_dps"]), FIELD_UPTIME, FIELD_MULTI_HIT])
	print("    레벨 %d까지 누적 경험치 %d (game.gd: 시작 8, 이후 7 + level × 5)" % [TARGET_LEVEL, xp_needed])
	print("%-5s %9s %10s %9s %9s %11s %11s %9s" % [
		"d", "몹HP", "킬시간초", "킬당XP", "초당XP", "필요킬수", "필요시간초", "시간배율"])
	var baseline_seconds := 0.0
	var ok := true
	for d: int in [0, 4, 8, 12]:
		var health := base_health * StageClock.dwell_hp(d)
		var kill_seconds := health / maxf(effective_dps, 0.01)
		var kill_xp := base_xp * StageClock.dwell_xp(d)
		var kills_needed := float(xp_needed) / maxf(kill_xp, 0.0001)
		var seconds_needed := kills_needed * kill_seconds
		if d == 0:
			baseline_seconds = seconds_needed
		var ratio := seconds_needed / maxf(baseline_seconds, 0.0001)
		# 시간 배율은 효율의 역수와 정확히 같아야 한다(물량·정예는 여기 안 들어간다).
		ok = ok and absf(ratio - 1.0 / StageClock.dwell_kill_efficiency(d)) < 0.001
		print("%-5d %9.1f %10.2f %9.3f %9.3f %11.0f %11.0f %9.3f" % [
			d, health, kill_seconds, kill_xp, kill_xp / maxf(kill_seconds, 0.0001),
			kills_needed, seconds_needed, ratio])
	var slowdown := 1.0 / StageClock.dwell_kill_efficiency(12)
	var pressure_ok := absf(slowdown - DWELL_PRESSURE_TARGET) <= DWELL_PRESSURE_TOLERANCE
	ok = ok and pressure_ok
	print("→ d=12에서 레벨업에 드는 시간 **×%.3f** (목표 %.2f ± %.2f) = %d" % [
		slowdown, DWELL_PRESSURE_TARGET, DWELL_PRESSURE_TOLERANCE, 1 if pressure_ok else 0])
	print("→ 잠식 임계(1st d=%d) 효율 %.3f · 강림 밸브(1st d=%d) 효율 %.3f" % [
		GameTuning.STAGE_BLIGHT_DWELL[0], StageClock.dwell_kill_efficiency(GameTuning.STAGE_BLIGHT_DWELL[0]),
		GameTuning.DWELL_DESCENT[0], StageClock.dwell_kill_efficiency(GameTuning.DWELL_DESCENT[0])])
	print("체류 압박 정합 = %d" % (1 if ok else 0))
	return ok


## 레벨 1에서 target 레벨까지 필요한 누적 경험치. game.gd `_choose_skill`의 식이다.
func _xp_to_level(target: int) -> int:
	var total := 8            # 시작 xp_target
	var level := 1
	while level < target - 1:
		level += 1
		total += 7 + level * 5
	return total


# =============================================================================
# ⑥ 밤 물량 · 상한 78 (handoff-y7 §10 항목 11)
# =============================================================================
func _print_volume_table() -> bool:
	print("--- ⑥ 밤 물량 (dwell 재키잉 · d=%d에서 포화 · 하드 캡 %d) ---" % [
		GameTuning.DWELL_COUNT_SATURATION, GameTuning.MAX_ENEMIES])
	print("스테이지별 밤 길이 %.0f → %.0f초. 물량은 일수가 아니라 **dwell**을 읽는다." % [
		GameTuning.STAGE_NIGHT_DURATION[0], GameTuning.STAGE_NIGHT_DURATION[4]])
	print("%-6s %8s %8s %8s %8s %10s %10s %8s" % [
		"dwell", "간격", "밤상한", "낮상한", "개시소환", "채움_초", "노출량", "여유"])
	var night_length: float = GameTuning.STAGE_NIGHT_DURATION[0]
	var ok := true
	for d in range(0, 13):
		var interval := StageClock.spawn_interval_at(d, true)
		var limit := float(StageClock.night_enemy_limit_at(d))
		var day_limit := float(StageClock.day_enemy_limit_at(d))
		var burst := float(StageClock.night_raid_burst_at(d))
		var fill := minf(night_length, (limit - burst) * interval)
		var exposure := fill * (limit + burst) * 0.5 + (night_length - fill) * limit
		var headroom := float(GameTuning.MAX_ENEMIES) - limit
		ok = ok and limit <= float(GameTuning.MAX_ENEMIES) and day_limit <= float(GameTuning.MAX_ENEMIES)
		print("%-6d %8.2f %8.0f %8.0f %8.0f %10.1f %10.0f %8.0f" % [
			d, interval, limit, day_limit, burst, fill, exposure, headroom])
	# 200까지 훑어 상한이 절대 안 깨지는 것을 확인한다(`--stage-test`의 volume 묶음과 같은 계약).
	for d in range(0, 201):
		ok = ok and StageClock.night_enemy_limit_at(d) <= GameTuning.MAX_ENEMIES
		ok = ok and StageClock.day_enemy_limit_at(d) <= GameTuning.MAX_ENEMIES
		ok = ok and StageClock.night_raid_burst_at(d) <= GameTuning.NIGHT_RAID_BURST_CAP
		ok = ok and StageClock.spawn_interval_at(d, true) >= GameTuning.NIGHT_SPAWN_INTERVAL_FLOOR
	var saturated := StageClock.night_enemy_limit_at(GameTuning.DWELL_COUNT_SATURATION)
	print("→ 포화 밤 상한 %d / MAX_ENEMIES %d · 여유 %d기 (무리 스폰 3~5기가 이 여유를 순간적으로 먹는다)" % [
		saturated, GameTuning.MAX_ENEMIES, GameTuning.MAX_ENEMIES - saturated])
	print("→ 밤 물량의 계단은 `DWELL_COUNT_STEP`(%d) 하나에서 온다. 소비자가 없던 `NIGHT_ENEMY_LIMIT_STEP`은 YZ가 삭제했다(handoff-y1 §8 · y8 §9-9)." % [
		GameTuning.DWELL_COUNT_STEP])
	print("물량 상한 불가침 = %d" % (1 if ok else 0))
	return ok


# =============================================================================
# ⑦ 5스테이지 통산 곡선 — 레벨 · 골드 · XP
# =============================================================================
# ⚠️ **XP는 스테이지로 스케일하지 않는다**(`StageClock.xp_multiplier()`는 dwell만 읽는다).
#    반면 몹 체력은 `stage_hp_base × dwell_hp × power`로 오른다. 그 손실을 메우는 것은
#    상위 티어 몹의 더 큰 xp 값 하나뿐이다(`MonsterLibrary.stage_pool()`이 넓어진다).
#
# Y8 가산: **사건(Y6)** 이 스테이지당 2~3개 늘었다. 유입에 반드시 반영해야 한다
# (handoff-y6 §9 · handoff-y7 §10 항목 9·10).
func _print_run_curve_table(stage_rows: Array) -> Array:
	print("--- ⑦ 5스테이지 통산 곡선 (스테이지당 %d주기 · dwell 0→%d) ---" % [
		CYCLES_PER_STAGE, CYCLES_PER_STAGE - 1])
	print("%-4s %8s %8s %8s %9s %8s %9s %10s %9s %10s %7s" % [
		"st", "power", "덱dps", "킬/주기", "킬제약", "킬XP", "누적XP", "레벨", "사건G", "누적골드", "일수"])
	var rows: Array = []
	var total_xp := 0
	var level := 1
	var xp_target := 8
	var gold := 20.0
	var day := 1
	for index in V3_STAGES.size():
		var spec: Dictionary = V3_STAGES[index]
		var stage := int(spec["stage"])
		var measured: Dictionary = stage_rows[index]
		var field_dps := float(measured["raw_dps"]) * FIELD_UPTIME * FIELD_MULTI_HIT
		var pool := _stage_pool_stats(stage)
		var stage_kills := 0.0
		var stage_gold := 0.0
		var stage_xp := 0
		var last_power := 0.0
		var spawn_bound := 0
		for d in CYCLES_PER_STAGE:
			var power := float(day - 1) * 1.1 + float(level - 1) * 0.32 + 2.5
			last_power = power
			var mob_hp: float = float(pool["health_units"]) \
				* (1.0 + MonsterLibrary.CYCLE_HEALTH_GAIN * power) \
				* GameTuning.STAGE_HP_BASE[stage - 1] * StageClock.dwell_hp(d)
			# 처치 수는 **스폰 한계와 화력 한계 중 작은 쪽**이다. 어느 하나만 보면 거짓말이 된다.
			var cycle_seconds: float = GameTuning.STAGE_DAY_DURATION[stage - 1] \
				+ GameTuning.STAGE_NIGHT_DURATION[stage - 1]
			var spawn_kills := _spawn_limited_kills(stage, d)
			var dps_kills := field_dps * cycle_seconds / maxf(mob_hp, 1.0)
			var kills := minf(spawn_kills, dps_kills)
			if spawn_kills <= dps_kills:
				spawn_bound += 1
			stage_kills += kills
			stage_xp += int(round(kills * float(pool["xp"]) * StageClock.dwell_xp(d)))
			stage_gold += kills * float(pool["gold"]) * StageClock.dwell_gold(d)
			if d in GameTuning.RIFT_DWELL_SCHEDULE:
				stage_gold += float(_RIFT_REWARD_GOLD)
			day += 1
		# --- Y6 사건 · 필드 상자 유입 (구판에 없던 항) ---
		var event_yield := _event_yield(stage)
		stage_gold += float(event_yield["gold"])
		stage_xp += int(round(float(event_yield["xp"])))
		total_xp += stage_xp
		gold += stage_gold
		var pending := stage_xp
		while pending >= xp_target:
			pending -= xp_target
			level += 1
			xp_target = 7 + level * 5
		rows.append({
			"stage": stage, "level": level, "gold": gold, "stage_gold": stage_gold,
			"stage_xp": stage_xp, "kills": stage_kills, "day": day, "power": last_power,
			"raw_dps": float(measured["raw_dps"]), "event_gold": float(event_yield["gold"]),
			"spawn_bound": spawn_bound
		})
		print("%-4d %8.2f %8.1f %9.0f %8s %8.2f %9d %10d %9.0f %10.0f %7d" % [
			stage, last_power, float(measured["raw_dps"]), stage_kills / float(CYCLES_PER_STAGE),
			"스폰" if spawn_bound >= 2 else "화력",
			float(pool["xp"]), total_xp, level, float(event_yield["gold"]), gold, day - 1])
	print("→ 5스테이지 통과 시점: 레벨 %d · 누적 골드 %.0f G · 총 %d일차 (등급 %s)" % [
		level, gold, day - 1, _grade_for_days(day - 1)])
	print("  「킬제약」이 **화력**이면 몹이 단단해 못 잡는 것이고, **스폰**이면 몹이 물러 스폰이 못 따라오는 것이다.")
	print("  다섯 스테이지가 전부 「스폰」이면 몹 체력이 난이도로 기능하지 않는다는 뜻이다(§5.5의 반대편 실패).")
	return rows


## 균열 클리어 보상. `game.gd:7224`의 리터럴과 같은 값이다(그 파일은 Y8 소유가 아니라 복제).
const _RIFT_REWARD_GOLD := 60

## 그 스테이지에 등장 가능한 종의 **가중 평균** xp · gold · 체력 단위.
## `MonsterLibrary.stage_pool()`이 정본이다 — 여기서 종 목록을 다시 적지 않는다.
func _stage_pool_stats(stage: int) -> Dictionary:
	var xp := 0.0
	var gold := 0.0
	var hits := 0.0
	var weight_total := 0.0
	for monster: Dictionary in MonsterLibrary.stage_pool(stage):
		var weight := float(monster.get("weight", 1.0))
		var monster_xp := float(monster.get("xp", 1))
		xp += monster_xp * weight
		# `enemy.gd` — gold_value = ceil(xp × 0.72).
		gold += ceilf(monster_xp * 0.72) * weight
		hits += maxf(0.5, float(monster.get("slash_hits", 3.0))) * weight
		weight_total += weight
	weight_total = maxf(weight_total, 1.0)
	return {
		"xp": xp / weight_total,
		"gold": gold / weight_total,
		# `MonsterLibrary.health_for()`의 `BASE_SLASH_DAMAGE × hits` 부분.
		"health_units": MonsterLibrary.BASE_SLASH_DAMAGE * hits / weight_total
	}


## 한 주기(낮+밤) 동안 **스폰이 허락하는** 처치 수.
func _spawn_limited_kills(stage: int, dwell: int) -> float:
	var night_length: float = GameTuning.STAGE_NIGHT_DURATION[stage - 1]
	var interval := StageClock.spawn_interval_at(dwell, true)
	var limit := float(StageClock.night_enemy_limit_at(dwell))
	var burst := float(StageClock.night_raid_burst_at(dwell))
	var fill_time := minf(night_length, (limit - burst) * interval)
	var night_kills := burst + (night_length - fill_time) / interval
	# 낮은 상한이 낮고 선공몹 게이트가 있어 밤의 40%로 잡는다.
	return night_kills * 1.4


# =============================================================================
# 필드 사건(Y6) 유입 — handoff-y7 §10 항목 9
# =============================================================================
# 보상 계수 5개(60 · 70 · 14 · 1.6 · 2.2)는 `game.gd::_finish_event()`에 리터럴로 있고
# 그 파일은 Y8 소유가 아니다. **여기서 값을 바꾸지 않고 유입만 잰다** — 창을 벗어나면
# 고칠 자리를 이 표가 지목한다.
#
# 스테이지당 사건 수: `EVENT_STAGE_MIN`(2) ~ `EVENT_STAGE_MAX`(3)를 시드가 정하고
# 공개는 dwell 0 / 2 / 4다. 이 표는 dwell 0~%d를 사는 런이므로 **2개**가 열린다.
# 보수적으로 유형은 그 스테이지에 가능한 것들의 **균등 평균**으로 잡는다.
const EVENT_PER_STAGE := 2
## `_finish_event()`의 계수. 값이 아니라 **참조**다 — 바꾸려면 game.gd를 고쳐야 한다.
const EVENT_DUNGEON_GOLD := 60.0
const EVENT_DUNGEON_MUL := 1.6
const EVENT_ELITE_GOLD := 70.0
const EVENT_PACK_XP := 14.0
const EVENT_PACK_MUL := 2.2
## 「보물섬」 3상자 · 「별똥별」 1상자의 안전 배당(`_grant_safe_chests()`).
##   34% 골드 rng(22,46) 평균 34 · 28% XP rng(6,12) 평균 9 · 나머지는 소비품/장비/각인.
const SAFE_CHEST_GOLD_P := 0.34
const SAFE_CHEST_GOLD_AVG := 34.0
const SAFE_CHEST_XP_P := 0.28
const SAFE_CHEST_XP_AVG := 9.0
## 필드 보물상자 — `world_grid`가 특징 청크의 %d%%에 깐다(`CHEST_FEATURE_ROLL`).
## 한 스테이지(3주기 · 보스문까지 3,600~4,200px)에 이만큼 연다고 본다.
const FIELD_CHESTS_PER_STAGE := 8.0
## `game.gd::CHEST_TABLE`의 **직접 골드 칸 둘**만 센다(모달 보상은 0으로).
##   gold 13% × rng(18,42) 평균 30  ·  curse 6% × rng(38,68) 평균 53
## Y8 초판은 여기에 "상자 골드는 스테이지 스케일을 안 탄다"고 적었다 — 당시 `_open_chest()`에
## `scale` 항이 정말 없었기 때문이다. **YZ가 그 누락을 고쳤다**(`chest_scale` 신설).
## 같은 게임 안에서 「보물섬」이 깔아 준 상자(`_grant_safe_chests()`는 원래 곱하고 있었다)와
## 바로 옆 필드 상자가 다르게 굴렀던 것이 근거다. 이제 둘 다 스케일을 탄다.
const FIELD_CHEST_GOLD := 0.13 * 30.0 + 0.06 * 53.0
## xp 12% × rng(5,11) 평균 8.
const FIELD_CHEST_XP := 0.12 * 8.0

func _event_yield(stage: int) -> Dictionary:
	var scale := 1.0 + GameTuning.STAGE_PRICE_STEP * float(stage - 1)
	# 그 스테이지에 열릴 수 있는 유형의 직접 수입(골드/XP). 모달 보상(각인·장비)은 0으로 센다.
	var pool: Array = []
	pool.append({"gold": EVENT_DUNGEON_GOLD * EVENT_DUNGEON_MUL, "xp": 0.0})   # dungeon
	pool.append({"gold": 0.0, "xp": 0.0})                                      # merchant(지출처)
	pool.append({"gold": 0.0, "xp": 0.0})                                      # footprint(각인 뜯기)
	pool.append({"gold": 0.0, "xp": EVENT_PACK_XP * EVENT_PACK_MUL})           # pack
	pool.append(_safe_chest_yield(1.0))                                        # meteor
	if stage >= 2:
		pool.append({"gold": EVENT_ELITE_GOLD, "xp": 0.0})                     # semi_elite
		pool.append(_safe_chest_yield(3.0))                                    # isle
	if stage >= 3:
		pool.append({"gold": 0.0, "xp": 0.0})                                  # shrine(각인 · 체력 지불)
	var gold := 0.0
	var xp := 0.0
	for entry in pool:
		var row: Dictionary = entry
		gold += float(row["gold"])
		xp += float(row["xp"])
	gold = gold / float(pool.size()) * float(EVENT_PER_STAGE) * scale
	xp = xp / float(pool.size()) * float(EVENT_PER_STAGE) * scale
	# 필드 보물상자. **YZ부터 스케일을 탄다**(`_open_chest()`의 `chest_scale`).
	# XP는 `collect_xp()` 경로라 여전히 안 곱한다 — 곱하는 것은 골드 두 칸뿐이다.
	gold += FIELD_CHESTS_PER_STAGE * FIELD_CHEST_GOLD * scale
	xp += FIELD_CHESTS_PER_STAGE * FIELD_CHEST_XP
	return {"gold": gold, "xp": xp}


func _safe_chest_yield(count: float) -> Dictionary:
	return {
		"gold": SAFE_CHEST_GOLD_P * SAFE_CHEST_GOLD_AVG * count,
		"xp": SAFE_CHEST_XP_P * SAFE_CHEST_XP_AVG * count
	}


func _grade_for_days(days: int) -> String:
	if days <= GameTuning.GRADE_S_MAX_DAYS:
		return "S"
	if days <= GameTuning.GRADE_A_MAX_DAYS:
		return "A"
	if days <= GameTuning.GRADE_B_MAX_DAYS:
		return "B"
	return "C"


# =============================================================================
# ⑧ 경제 — 각인 사다리(+레일 할증) · 상점가 스케일 · 골드 여유
# =============================================================================
# handoff-y7 §10 항목 8·10·12. 셋이 한 표에 있는 이유는 **한 지갑**이기 때문이다.
#
# 정규 지출 사다리(스테이지마다 한 번씩)
#   * 각인 세공사 1개  — 희귀도 기본가 + 구매 계단, 흐름/확정/레일/굴림 프리미엄
#   * 상점 2점         — 45 G × 스테이지 스케일
#   * 밀정 칸 지우기 1 — `SPY_WIPE_COST` 120 × 스테이지 스케일 (스테이지당 1회 상한)
# 취소 경제(X1)는 **수입 쪽 상한선**으로만 찍는다 — 정규 경로는 취소를 안 쓴다.
const SHOP_ITEMS_PER_STAGE := 2
const SPY_WIPE_COST := 120.0
const CHOICE_CANCEL_GOLD := 30.0

func _print_economy_table(run_curve: Array) -> bool:
	print("--- ⑧ 경제 (골드 여유 목표 %.0f~%.0f%%) ---" % [GOLD_SLACK_MIN * 100.0, GOLD_SLACK_MAX * 100.0])
	if run_curve.size() < 2:
		print("run_curve 부족 — 건너뜀")
		return false

	# ---- ㄱ. 각인 세공사 사다리 · 레일 할증의 실제 무게 -----------------------
	print("  ㄱ. 각인 세공사 정규 사다리 (스테이지마다 1개 · 구매 계단 %d G)" % GameTuning.RUNE_SHOP_PURCHASE_STEP)
	print("     가격 = (희귀도 기본가 + 계단×구매수) × 흐름 %.2f × 확정 %.2f × **레일 %.2f** × 굴림 × 스테이지" % [
		GameTuning.RUNE_SHOP_FLOW_PREMIUM, GameTuning.RUNE_SHOP_PASSIVE_PREMIUM,
		GameTuning.RUNE_SHOP_RAIL_PREMIUM])
	print("     %-4s %10s %12s %12s %10s" % ["st", "가격×", "일반사다리", "희귀사다리", "레일할증"])
	var common_total := 0.0
	var rare_total := 0.0
	var common_total_no_rail := 0.0
	for row_value in run_curve:
		var row: Dictionary = row_value
		var stage := int(row["stage"])
		var scale := 1.0 + GameTuning.STAGE_PRICE_STEP * float(stage - 1)
		var purchases := stage - 1
		var common := _rune_ladder_price(GameTuning.RUNE_SHOP_PRICE_COMMON, purchases, scale, true)
		var common_flat := _rune_ladder_price(GameTuning.RUNE_SHOP_PRICE_COMMON, purchases, scale, false)
		var rare := _rune_ladder_price(GameTuning.RUNE_SHOP_PRICE_RARE, purchases, scale, true)
		common_total += common
		common_total_no_rail += common_flat
		rare_total += rare
		print("     %-4d %10.2f %12.0f %12.0f %10.0f" % [stage, scale, common, rare, common - common_flat])
	var rail_lift := common_total / maxf(common_total_no_rail, 0.01) - 1.0
	print("     → 일반 사다리 총액 %.0f G · 희귀 %.0f G · **레일 할증이 올린 몫 %+.1f%%**(§2.6의 추정 +6%%)" % [
		common_total, rare_total, rail_lift * 100.0])
	print("     기대 할증 = 1 + (레일 %d종 / 전체 %d종) × %.2f = ×%.4f" % [
		RuneEngine.ids_by_scope("rail").size(), RuneEngine.RUNES.size(),
		GameTuning.RUNE_SHOP_RAIL_PREMIUM - 1.0, _expected_rail_premium()])

	# ---- ㄴ. 상점가 스케일 · 누적 구매력 --------------------------------------
	print("")
	print("  ㄴ. 상점가 스테이지 스케일 `STAGE_PRICE_STEP` %.2f — 누적 구매력" % GameTuning.STAGE_PRICE_STEP)
	print("     %-4s %10s %11s %9s %12s %12s" % ["st", "수입/st", "누적골드", "가격×", "유량구매력", "누적구매력"])
	for row_value in run_curve:
		var row: Dictionary = row_value
		var stage := int(row["stage"])
		var scale := 1.0 + GameTuning.STAGE_PRICE_STEP * float(stage - 1)
		var price := SHOP_ITEM_BASE_PRICE * scale
		print("     %-4d %10.0f %11.0f %9.2f %12.1f %12.1f" % [
			stage, float(row["stage_gold"]), float(row["gold"]), scale,
			float(row["stage_gold"]) / price, float(row["gold"]) / price])

	# ---- ㄷ. 유입 대 지출 · 골드 여유 -----------------------------------------
	# **바구니를 먼저 못 박는다** — 「여유」는 무엇을 사느냐에 통째로 걸려 있어서
	# 바구니를 정하지 않으면 어떤 수도 만들어 낼 수 있다.
	#   한 스테이지의 **완전 지출** = 각인 세공사 1개 + 상점 2점 + 밀정 칸 지우기 1회.
	#   = 성에서 살 수 있는 것을 매 스테이지 **전부** 사는 플레이. 여유는 그 위의 잔고다.
	# 진행에만 필요한 것(각인 + 상점)은 「진행 지출」로 따로 찍는다 — 둘의 차이가
	# "선택 지출에 쓸 수 있는 돈"이고, 그 폭이 있어야 상점이 선택을 강요한다.
	print("")
	print("  ㄷ. 유입 대 지출 (사건 %d개/st · 균열 · 필드 상자 %.0f개/st 포함)" % [
		EVENT_PER_STAGE, FIELD_CHESTS_PER_STAGE])
	print("     %-4s %10s %10s %10s %10s %10s %11s" % [
		"st", "수입/st", "각인", "상점2", "밀정", "완전지출", "잔고"])
	var income_total := 20.0
	var spend_total := 0.0
	var progress_total := 0.0
	for row_value in run_curve:
		var row: Dictionary = row_value
		var stage := int(row["stage"])
		var scale := 1.0 + GameTuning.STAGE_PRICE_STEP * float(stage - 1)
		var rune_cost := _rune_ladder_price(GameTuning.RUNE_SHOP_PRICE_COMMON, stage - 1, scale, true)
		var shop_cost := SHOP_ITEM_BASE_PRICE * scale * float(SHOP_ITEMS_PER_STAGE)
		var spy_cost := SPY_WIPE_COST * scale
		var spend := rune_cost + shop_cost + spy_cost
		income_total += float(row["stage_gold"])
		spend_total += spend
		progress_total += rune_cost + shop_cost
		print("     %-4d %10.0f %10.0f %10.0f %10.0f %10.0f %11.0f" % [
			stage, float(row["stage_gold"]), rune_cost, shop_cost, spy_cost, spend,
			income_total - spend_total])
	var slack := (income_total - spend_total) / maxf(income_total, 1.0)
	var ok := slack >= GOLD_SLACK_MIN and slack <= GOLD_SLACK_MAX
	print("     → 총수입 %.0f G · **완전지출 %.0f G** · 여유 **%.1f%%** (목표 %.0f~%.0f%%)" % [
		income_total, spend_total, slack * 100.0, GOLD_SLACK_MIN * 100.0, GOLD_SLACK_MAX * 100.0])
	print("     → (참고) 진행 지출만(각인+상점) %.0f G · 그때의 여유 %.1f%% — 선택 지출에 쓸 수 있는 폭이다" % [
		progress_total, (income_total - progress_total) / maxf(income_total, 1.0) * 100.0])
	# 취소 경제의 상한선 — 레벨업을 전부 취소하면 얼마인가(X1의 계약 확인).
	var cancel_bound := 0.0
	var previous_level := 1
	for row_value in run_curve:
		var row: Dictionary = row_value
		var stage := int(row["stage"])
		var scale := 1.0 + GameTuning.STAGE_PRICE_STEP * float(stage - 1)
		cancel_bound += float(int(row["level"]) - previous_level) * CHOICE_CANCEL_GOLD * scale
		previous_level = int(row["level"])
	print("     → 취소 상한선: 레벨업 %d회를 **전부** 취소하면 %.0f G. 그 대가로 레일이 안 자란다" % [
		int((run_curve[run_curve.size() - 1] as Dictionary)["level"]) - 1, cancel_bound])
	print("       (총수입의 %.0f%% — 카드 한 장 평균가 33 G 밑이라는 X1의 빗장은 유지된다)" % [
		cancel_bound / maxf(income_total, 1.0) * 100.0])
	print("골드 여유 창 통과 = %d" % (1 if ok else 0))
	return ok


## 각인 한 장의 정규 사다리 값. `game.gd::_rune_offer_price()`의 항 구성을 그대로 따른다.
## 굴림 프리미엄은 저작 범위 한가운데(min·max의 중점)로 고정한다.
## `rail_expected`가 참이면 **레일이 뽑힐 확률만큼** 할증을 기대값으로 얹는다.
func _rune_ladder_price(rarity_base: int, purchases: int, stage_scale: float,
		rail_expected: bool) -> float:
	var base := float(rarity_base) + float(GameTuning.RUNE_SHOP_PURCHASE_STEP * purchases)
	base *= (GameTuning.RUNE_SHOP_ROLL_PREMIUM_MIN + GameTuning.RUNE_SHOP_ROLL_PREMIUM_MAX) * 0.5
	if rail_expected:
		base *= _expected_rail_premium()
	return round(base) * stage_scale


## 카탈로그에서 레일 각인이 뽑힐 비율만큼 할증을 기대값으로 환산한다.
func _expected_rail_premium() -> float:
	var rail_count := float(RuneEngine.ids_by_scope("rail").size())
	var total := maxf(float(RuneEngine.RUNES.size()), 1.0)
	return 1.0 + (rail_count / total) * (GameTuning.RUNE_SHOP_RAIL_PREMIUM - 1.0)


# =============================================================================
# ⑨ 스테이지 보스 전투 길이 (목표 30~60초) + 강화형 + 반격 창
# =============================================================================
# HP 식은 복제하지 않고 `BossLibrary.hp_for()`를 그대로 부른다.
func _print_stage_boss_table(stage_rows: Array) -> bool:
	print("--- ⑨ 스테이지 보스 전투 길이 (목표 %.0f~%.0f초 · uptime %.2f) ---" % [
		BOSS_TTK_MIN, BOSS_TTK_MAX, BOSS_UPTIME])
	print("    HP = DESIGN_HP[design] × STAGE_HP_BASE[stage] × (1 + %.2f × dwell)" % GameTuning.STAGE_BOSS_HP_DWELL_STEP)
	print("    DPS = 사이클 직격 + **상태이상**(도트 + 즉발 시너지) + 평타")
	print("%-4s %5s %5s %6s %9s %8s %8s %9s %8s %8s %8s %6s" % [
		"st", "보스", "강화", "dwell", "HP", "직격dps", "상태dps", "raw_dps", "ttk@.50", "ttk@.62", "ttk@.72", "판정"])
	var all_ok := true
	var recommend: Dictionary = {}
	for index in V3_STAGES.size():
		var spec: Dictionary = V3_STAGES[index]
		var stage := int(spec["stage"])
		var design: String = GameTuning.STAGE_BOSS_DESIGN[stage - 1]
		var enhanced: bool = GameTuning.STAGE_BOSS_ENHANCED[stage - 1]
		var dwell := CYCLES_PER_STAGE - 1
		var hp := BossLibrary.hp_for(design, GameTuning.STAGE_HP_BASE[stage - 1], dwell, false)
		var measured: Dictionary = stage_rows[index]
		var raw: float = float(measured["raw_dps"])
		var ttk: Array[float] = []
		for uptime: float in BOSS_UPTIME_BAND:
			ttk.append(hp / maxf(raw * uptime, 0.01))
		var mid := hp / maxf(raw * BOSS_UPTIME, 0.01)
		var row_ok := mid >= BOSS_TTK_MIN and mid <= BOSS_TTK_MAX
		all_ok = all_ok and row_ok
		# 목표 창 한가운데로 되돌리는 DESIGN_HP를 역산한다. 한 디자인이 두 스테이지에
		# 나오므로(B는 2·4 · C는 3·5) **기하평균**으로 하나로 모은다.
		var target_mid := (BOSS_TTK_MIN + BOSS_TTK_MAX) * 0.5
		var scale := raw * BOSS_UPTIME * target_mid / maxf(hp, 1.0)
		var factors: Array = recommend.get(design, [])
		factors.append(float(BossLibrary.DESIGN_HP.get(design, 3000.0)) * scale)
		recommend[design] = factors
		print("%-4d %5s %5s %6d %9.0f %8.1f %8.1f %9.1f %8.0f %8.0f %8.0f %6s" % [
			stage, design, "+" if enhanced else "-", dwell, hp,
			float(measured["direct_dps"]), float(measured["status_dps"]), raw,
			ttk[0], ttk[1], ttk[2], "ok" if row_ok else "OUT"])
	print("")
	print("  목표 창 한가운데(%.0f초)로 되돌리는 DESIGN_HP 역산 (디자인당 기하평균):" % (
		(BOSS_TTK_MIN + BOSS_TTK_MAX) * 0.5))
	for key_value in recommend.keys():
		var design := String(key_value)
		var factors: Array = recommend[key_value]
		var product := 1.0
		for value in factors:
			product *= float(value)
		var merged_hp: float = pow(product, 1.0 / maxf(float(factors.size()), 1.0))
		var current := float(BossLibrary.DESIGN_HP.get(design, 3000.0))
		print("    %-3s 현행 %7.0f → 권장 %7.0f  (×%.2f · 등장 %d회)" % [
			design, current, merged_hp, merged_hp / maxf(current, 1.0), factors.size()])

	# ---- 반격 창 (handoff-y7 §10 항목 4) --------------------------------------
	print("")
	print("  반격 창 실측 — `STAGE_BOSS_RELOAD_MUL` %.2f / 강화형 %.2f / 마왕 %.2f" % [
		GameTuning.STAGE_BOSS_RELOAD_MUL, GameTuning.STAGE_BOSS_RELOAD_MUL_ENHANCED,
		GameTuning.BOSS_RELOAD_MUL])
	print("  ⚠️ **§1.6이 이 두 값을 재보라고 한 이유가 스테이지 보스에는 성립하지 않는다.**")
	print("     그 근거는 「칸당 실행 2회 상한 때문에 한 바퀴의 빚이 최대 2배가 된다」인데,")
	print("     스테이지 보스는 **각인이 0개다**(부록 A-2 ⑫). 앙코르를 만드는 것이 흐름 각인뿐이므로")
	print("     보스의 빚은 패턴 reload의 **고정 합**이고 시드와 무관하다(아래 빚평균 = 빚최대).")
	print("     빚이 2배가 될 수 있는 것은 각인을 %d개까지 갖는 **마왕뿐**이다." % GameTuning.BOSS_RUNE_CAP)
	print("  %-16s %6s %6s %10s %10s %10s %10s %6s" % [
		"보스", "칸", "각인", "빚평균", "빚최대", "창평균", "창최대", "판정"])
	var window_ok := true
	for design: String in ["A", "B", "C"]:
		for enhanced: bool in [false, true]:
			window_ok = _print_boss_reload_window(design, enhanced) and window_ok
	window_ok = _print_demon_reload_window() and window_ok
	print("  → 설계가 말한 창은 **%.1f~%.1f초**다(FEEDBACK_Y §1.6). 일곱 전부 그 안 = %d" % [
		RELOAD_WINDOW_MIN, RELOAD_WINDOW_MAX, 1 if window_ok else 0])
	all_ok = all_ok and window_ok

	# ---- 강림 밸브 ------------------------------------------------------------
	print("")
	print("  강림 밸브(프리뷰 없음 · 칸 +1 · HP ×%.2f · dwell 임계):" % GameTuning.STAGE_DESCENT_HP_MUL)
	print("  %-4s %6s %9s %9s %8s" % ["st", "dwell", "HP", "raw_dps", "ttk@.62"])
	for index in V3_STAGES.size():
		var spec: Dictionary = V3_STAGES[index]
		var stage := int(spec["stage"])
		var dwell: int = GameTuning.DWELL_DESCENT[stage - 1]
		var hp := BossLibrary.hp_for(GameTuning.STAGE_BOSS_DESIGN[stage - 1],
			GameTuning.STAGE_HP_BASE[stage - 1], dwell, true)
		var raw: float = float((stage_rows[index] as Dictionary)["raw_dps"])
		print("  %-4d %6d %9.0f %9.1f %8.0f" % [stage, dwell, hp, raw, hp / maxf(raw * BOSS_UPTIME, 0.01)])
	print("  ⚠️ 강림 행은 **목표 창을 재는 표가 아니다.** dwell 10~14짜리 보스를 dwell %d짜리" % (CYCLES_PER_STAGE - 1))
	print("     플레이어로 때린 값이라 모델이 한쪽으로 기울어 있다. 이 표가 말하는 것은 절대 시간이")
	print("     아니라 `STAGE_BOSS_HP_DWELL_STEP`(%.2f)이 밸브 지점에서 HP를 몇 배로 만드는가 하나다." % GameTuning.STAGE_BOSS_HP_DWELL_STEP)
	print("보스 전투 길이 창 통과 = %d" % (1 if all_ok else 0))
	return all_ok


## 스테이지 보스의 반격 창. **패턴 데이터를 그대로 쓴다** — `BossLibrary.patterns()`가
## 강화형 파생(칸 3→4 · telegraph ×0.85)까지 끝난 완성 배열을 준다.
## 각인이 0개라 앙코르가 없고, 그래서 빚은 시드와 무관한 **고정 합**이다.
func _print_boss_reload_window(design: String, enhanced: bool) -> bool:
	var patterns := BossLibrary.patterns(design, enhanced)
	var deck: Array = []
	for entry in patterns:
		var pattern: Dictionary = entry
		deck.append(RuneEngine.make_slot({
			"id": String(pattern.get("id", "")),
			"damage": float(pattern.get("damage", 1.0)),
			"reload": float(pattern.get("reload", 0.2)),
			"duration": float(pattern.get("duration", 0.5)),
			"element": String(pattern.get("element", "")),
			"form": String(pattern.get("form", ""))
		}, []))
	return _measure_reload_window("%s%s" % [design, "+" if enhanced else " "],
		deck, BossLibrary.reload_scale(enhanced), 0)


## 마왕의 반격 창. 마왕은 5칸에 **각인을 `BOSS_RUNE_CAP`개까지** 갖는다.
## 정규 경로(미선택 카드 58장 / `BOSS_CARDS_PER_RUNE` 4)면 14개다 — 그 14개를 5칸에
## 고르게 붙여 "빚이 최대 몇 배까지 벌어지는가"를 실측한다. 각인 종류는 흐름 계열을
## 섞어 **앙코르가 실제로 일어나게** 잡는다(§1.6이 걱정한 바로 그 경우다).
func _print_demon_reload_window() -> bool:
	var rune_count := clampi(58 / GameTuning.BOSS_CARDS_PER_RUNE, 0, GameTuning.BOSS_RUNE_CAP)
	var flow_pool: Array[String] = ["twice", "back_one", "jump_one", "trade_skip", "strong"]
	var deck: Array = []
	var cards := ["cleave", "flame_field", "thrust", "whirlwind", "execution"]
	var attached := 0
	for index in GameTuning.BOSS_SLOT_COUNT:
		var card := DealCardLibrary.by_id(cards[index])
		var runes: Array = []
		while attached < rune_count and runes.size() < RuneEngine.RUNE_SLOTS_PER_SLOT:
			runes.append(_mid_instance(flow_pool[attached % flow_pool.size()]))
			attached += 1
		deck.append(RuneEngine.make_slot({
			"id": String(card.get("id", "")),
			"damage": float(card.get("damage", 1.0)),
			"reload": float(card.get("reload", 0.2)),
			"duration": float(card.get("duration", 0.5)),
			"element": String(card.get("element", "")),
			"form": String(card.get("form", ""))
		}, runes))
	return _measure_reload_window("마왕(5칸)", deck, GameTuning.BOSS_RELOAD_MUL, attached)


func _measure_reload_window(label: String, deck: Array,
		reload_mul: float, rune_count: int) -> bool:
	var opts: Dictionary = {"reload_scale": reload_mul}
	var debt_sum := 0.0
	var debt_max := 0.0
	var window_sum := 0.0
	var window_max := 0.0
	for index in SEEDS:
		var cycle := RuneEngine.simulate_cycle(deck, 4242 + index * 7919, opts)
		var debt := float(cycle.get("reload_debt", 0.0))
		var window := float(cycle.get("reload", 0.0))
		debt_sum += debt
		window_sum += window
		debt_max = maxf(debt_max, debt)
		window_max = maxf(window_max, window)
	var window_mean := window_sum / float(SEEDS)
	var ok := window_mean >= RELOAD_WINDOW_MIN and window_mean <= RELOAD_WINDOW_MAX
	print("  %-16s %6d %6d %10.2f %10.2f %10.2f %10.2f %6s" % [
		label, deck.size(), rune_count, debt_sum / float(SEEDS), debt_max,
		window_mean, window_max, "ok" if ok else "OUT"])
	return ok


# =============================================================================
# ⑩ 마왕 전투 길이 (60~120초) + 트로피 5종
# =============================================================================
# ⚠️ **마왕은 상태이상 면역이다** — `combat_resolver.strike_enemy_with_card()`의
#    `status_eligible = (not is_boss) or is_stage_boss`. 그래서 마왕전 DPS는
#    `status_enabled = false`로 잰다. 이걸 틀리면 마왕 HP를 30% 과대 산정하게 된다.
func _print_demon_table(run_curve: Array) -> bool:
	print("--- ⑩ 마왕 전투 길이 (목표 %.0f~%.0f초 · uptime %.2f) ---" % [
		DEMON_TTK_MIN, DEMON_TTK_MAX, DEMON_UPTIME])
	print("    기저 = %.0f + min(부채,%d)×%.0f + 아이템×%.0f + power×%.0f" % [
		GameTuning.BOSS_BASE_HP, GameTuning.BOSS_DEBT_CAP, GameTuning.BOSS_HP_PER_DEBT,
		GameTuning.BOSS_HP_PER_ITEM, GameTuning.BOSS_HP_PER_POWER])
	print("    배율 = (1 + %.2f × 총일수) × (1 + %.2f × 격파스테이지) × (강림 %.2f)" % [
		GameTuning.BOSS_HP_PER_TOTAL_DAY, GameTuning.BOSS_HP_PER_STAGE_CLEARED, GameTuning.DESCENT_HP_MUL])
	var last: Dictionary = run_curve[run_curve.size() - 1]
	var run_days := int(last["day"]) - 1
	var run_level := int(last["level"])
	var last_spec: Dictionary = V3_STAGES[V3_STAGES.size() - 1]
	# 5종 누적 트로피가 붙은 정규 경로의 화력. 마왕은 상태 면역이므로 status_enabled=false.
	var full_spec := last_spec.duplicate(true)
	full_spec["trophies"] = [1, 2, 3, 4, 5]
	var merged := TrophyLibrary.merge_effects([1, 2, 3, 4, 5])
	var keys := merged.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_value in keys:
		parts.append("%s %s" % [String(key_value), str(merged[key_value])])
	print("    트로피 5종 누적: %s" % " · ".join(parts))
	print("%-16s %8s %9s %9s %9s %10s %8s %8s" % [
		"시나리오", "dmg", "직격dps", "상태dps", "raw_dps", "마왕HP", "ttk", "판정"])
	var all_ok := true
	for scenario: Array in _demon_scenarios(run_days, run_level):
		var name := String(scenario[0])
		var days := int(scenario[1])
		var level := int(scenario[2])
		var debts := int(scenario[3])
		var items := int(scenario[4])
		var cleared := int(scenario[5])
		var descended := bool(scenario[6])
		var trophies: Array = scenario[7]
		var judged := bool(scenario[8])
		var spec := last_spec.duplicate(true)
		spec["trophies"] = trophies
		var measured := _measure_dps(spec, false)
		var raw: float = float(measured["raw_dps"])
		var hp := _demon_health(days, level, debts, items, cleared, descended)
		var ttk := hp / maxf(raw * DEMON_UPTIME, 0.01)
		var row_ok := (not judged) or (ttk >= DEMON_TTK_MIN and ttk <= DEMON_TTK_MAX)
		all_ok = all_ok and row_ok
		print("%-16s %8.1f %9.1f %9.1f %9.1f %10.0f %8.0f %8s" % [
			name, float(measured["player_damage"]), float(measured["direct_dps"]),
			float(measured["status_dps"]), raw, hp, ttk,
			("ok" if row_ok else "OUT") if judged else "참고"])
	# 상태 면역이 아니었다면 얼마나 빨리 죽는가 — 면역 규칙의 값을 숫자로 남긴다.
	var vulnerable := _measure_dps(full_spec, true)
	var normal_hp := _demon_health(run_days, run_level, 58, 5, 5, false)
	print("  (참고) 마왕이 상태 면역이 **아니라면** raw_dps %.1f → ttk %.0f초." % [
		float(vulnerable["raw_dps"]), normal_hp / maxf(float(vulnerable["raw_dps"]) * DEMON_UPTIME, 0.01)])
	print("  (참고) 마왕 각인 수 = clamp(floor(받은 카드 / %d), 0, %d) — 정규 경로 58장이면 %d개." % [
		GameTuning.BOSS_CARDS_PER_RUNE, GameTuning.BOSS_RUNE_CAP,
		clampi(58 / GameTuning.BOSS_CARDS_PER_RUNE, 0, GameTuning.BOSS_RUNE_CAP)])
	print("마왕전 창 통과 = %d" % (1 if all_ok else 0))
	return all_ok


## [이름, 총일수, 레벨, 넘긴 카드 수, 아이템 수, 격파 스테이지, 강림, 트로피, 판정대상]
## 판정은 **정규 경로 하나**만 한다 — 조기 도전·과파밍·강림은 비정상 경로이고
## 그 셋까지 같은 창에 넣으면 어떤 HP 값으로도 전부 만족시킬 수 없다.
func _demon_scenarios(run_days: int, run_level: int) -> Array:
	return [
		["1st 직행", 4, 8, 12, 1, 0, false, [], false],
		["3st 도달", 11, 13, 34, 3, 2, false, [1, 2], false],
		["5st 정규", run_days, run_level, 58, 5, 5, false, [1, 2, 3, 4, 5], true],
		["5st 과파밍", run_days + 8, run_level + 3, 82, 7, 5, false, [1, 2, 3, 4, 5], false],
		["강림 밸브", run_days, run_level, 58, 5, 5, true, [1, 2, 3, 4, 5], false],
		["트로피 0/5", run_days, run_level, 58, 5, 5, false, [], false],
		["트로피 3/5", run_days, run_level, 58, 5, 5, false, [1, 2, 3], false]
	]


## 마왕 실체력. **식을 복제하지 않는다** — 기저는 `DemonLord.boss_base_health()`가 정본이다.
func _demon_health(total_days: int, level: int, debts: int, items: int,
		stages_cleared: int, descended: bool) -> float:
	var power_level := float(total_days + level) * 0.7
	var base := DemonLord.boss_base_health(debts, items, power_level)
	var scale := (1.0 + GameTuning.BOSS_HP_PER_TOTAL_DAY * float(maxi(0, total_days))) \
		* (1.0 + GameTuning.BOSS_HP_PER_STAGE_CLEARED * float(maxi(0, stages_cleared)))
	if descended:
		scale *= GameTuning.DESCENT_HP_MUL
	return base * scale


# =============================================================================
# ⑪ 충격 프로필 8종 · pin/pop의 DPS 상승 · haste 4장 (handoff-y7 §10 항목 13·14·16)
# =============================================================================
# Y7이 `impact_reaction()`의 수치를 "kind 눈금에 옮겨 적은 초안"이라고 적어 두고
# 실전 세기를 Y8에 넘겼다. 여기서 재는 것은 세 가지다.
#   ㄱ. 8종이 카드 28장에 어떻게 갈렸는가 · 한 바퀴에 몇 번 발동하는가
#   ㄴ. `pin`(0.25초 정지)·`pop`(0.30초 체공)이 만드는 **필드 DPS 상승**
#   ㄷ. `haste_self` 4장이 한 바퀴에서 차지하는 시간 비율
#
# ⚠️ **가장 큰 발견을 먼저 적는다: pin·pop은 보스에게 걸리지 않는다.**
#    `enemy.gd::apply_hit_reaction()`의 끝에 `if is_boss: pin_timer = 0; airborne_timer = 0`이
#    있다. 그래서 항목 14의 "붙잡기·띄우기가 만든 DPS 상승"은 **보스전 0 · 필드 전용**이다.
#    보스 HP를 이 상승분만큼 올릴 이유가 없다는 뜻이고, ⑨의 TTK 표는 그대로 유효하다.
func _print_impact_table(stage_rows: Array) -> void:
	print("--- ⑪ 충격 프로필 8종 실전 세기 (Y7 초안값의 재측정) ---")
	print("%-12s %8s %8s %8s %8s   %s" % ["impact", "장수", "넉백", "경직", "표시", "특수"])
	var counts: Dictionary = {}
	for card: Dictionary in DealCardLibrary.SKILLS:
		var impact := String(card.get("impact", ""))
		if impact.is_empty():
			continue
		counts[impact] = int(counts.get(impact, 0)) + 1
	for card: Dictionary in DealCardLibrary.SPECIALS:
		var impact := String(card.get("impact", ""))
		if impact.is_empty():
			continue
		counts[impact] = int(counts.get(impact, 0)) + 1
	var impact_ids := counts.keys()
	impact_ids.sort()
	for key_value in impact_ids:
		var impact := String(key_value)
		var profile := DealCardLibrary.impact_reaction(impact)
		var special := ""
		match impact:
			"pin": special = "대상 정지 %.2fs (보스 면제)" % EnemyPinSeconds
			"pop": special = "체공 %.2fs (보스 면제)" % EnemyPopSeconds
			"slow": special = "이동 −%.0f%% %.1fs" % [EnemySlowStrength * 100.0, EnemySlowSeconds]
			"rush": special = "점점 느려짐 %.2f → %.2f · %.1fs" % [EnemySlowRampFrom, EnemySlowRampTo, EnemySlowRampSeconds]
			"haste_self": special = "내 이동 ×%.2f %.1fs" % [PlayerHasteMultiplier, PlayerHasteSeconds]
			"stagger": special = "적 공격 취소"
			_: special = "—"
		print("%-12s %8d %8.0f %8.3f %8s   %s" % [
			impact, int(counts[key_value]), float(profile.get("force", 0.0)),
			float(profile.get("stun", 0.0)), DealCardLibrary.impact_name(impact), special])

	# ---- ㄴ. pin·pop이 만드는 필드 DPS 상승 -----------------------------------
	print("")
	print("  ㄴ. 붙잡기·띄우기의 필드 DPS 상승 (항목 14) — **보스전은 0이다**(위 ⚠️)")
	print("     한 바퀴에서 대상이 못 움직이는 시간 = Σ(pin 0.25 · pop 0.30) / 한 바퀴 길이.")
	print("     그만큼 추적·재접근이 사라지므로 필드 uptime %.2f가 그 비율만큼 오른다." % FIELD_UPTIME)
	print("     %-10s %8s %8s %9s %10s %10s %10s" % [
		"deck", "pin/바퀴", "pop/바퀴", "정지초", "바퀴초", "uptime→", "필드dps→"])
	var last: Dictionary = V3_STAGES[V3_STAGES.size() - 1]
	for axis: Dictionary in AXIS_DECKS:
		var spec := axis.duplicate(true)
		spec["equipment"] = last["equipment"]
		spec["trophies"] = last["trophies"]
		var hold := _measure_impact_hold(spec)
		var base_row: Dictionary = stage_rows[stage_rows.size() - 1]
		var lifted := minf(0.95, FIELD_UPTIME * (1.0 + float(hold["hold_ratio"])))
		print("     %-10s %8.2f %8.2f %9.2f %10.2f %10.3f %10.1f" % [
			axis["name"], float(hold["pin"]), float(hold["pop"]), float(hold["hold_seconds"]),
			float(hold["cycle_time"]), lifted,
			float(base_row["raw_dps"]) * lifted * FIELD_MULTI_HIT])

	# ---- ㄷ. haste_self 4장 ---------------------------------------------------
	print("")
	print("  ㄷ. 「내가 빨라짐」 4장의 회피 가치 (항목 16)")
	var haste_cards: Array[String] = []
	for card: Dictionary in DealCardLibrary.SKILLS:
		if String(card.get("impact", "")) == "haste_self":
			haste_cards.append(String(card.get("id", "")))
	print("     대상 카드 %d장: %s" % [haste_cards.size(), ", ".join(PackedStringArray(haste_cards))])
	print("     한 장이 켜는 시간 %.1fs × 이동 ×%.2f. 5칸 중 %d칸이 그 카드면 한 바퀴의" % [
		PlayerHasteSeconds, PlayerHasteMultiplier, 2])
	print("     %.0f%%를 빨라진 채로 산다(지속이 겹치면 `maxf`로 합쳐지므로 중첩 이득은 없다)." % [
		minf(1.0, PlayerHasteSeconds * 2.0 / 4.0) * 100.0])
	print("     → 체류 압박에 미치는 영향: 피격이 줄어 **죽지 않는다**는 축이지 수입 축이 아니다.")
	print("       ⑤의 시간 배율은 킬 효율만 보므로 이 값에 흔들리지 않는다(실측 확인).")

	# ---- ㄹ. 맹독 십자 stack_bonus (항목 15) ----------------------------------
	print("")
	print("  ㄹ. 「맹독 십자」 `status_stack_bonus` (항목 15) — Y7이 처음 켠 채널")
	var cross := DealCardLibrary.by_id("cross_cut")
	print("     authored 값 %.1f · 이 키를 가진 카드는 전체 %d장 중 %d장이다." % [
		float(cross.get("status_stack_bonus", 1.0)), DealCardLibrary.SKILLS.size(),
		_stack_bonus_card_count()])
	var poison_spec := (AXIS_DECKS[1] as Dictionary).duplicate(true)
	poison_spec["equipment"] = last["equipment"]
	poison_spec["trophies"] = last["trophies"]
	var with_cross := _measure_dps(poison_spec, true)
	var without_spec := poison_spec.duplicate(true)
	# cross_cut 두 장을 같은 원소·같은 자리의 `whirlwind`로 바꿔 stack_bonus만 뗀다.
	var swapped: Array = []
	for entry in (poison_spec["cards"] as Array):
		var pair: Array = entry
		swapped.append(["whirlwind", int(pair[1])] if String(pair[0]) == "cross_cut" else pair)
	without_spec["cards"] = swapped
	var no_cross := _measure_dps(without_spec, true)
	print("     독 축 덱: cross_cut 포함 raw_dps %.1f (상태 %.1f) · 뺀 덱 %.1f (상태 %.1f)" % [
		float(with_cross["raw_dps"]), float(with_cross["status_dps"]),
		float(no_cross["raw_dps"]), float(no_cross["status_dps"])])
	print("     → 상태 피해 기여 %+.1f%% · 총 DPS 기여 %+.1f%%. 독 빌드의 상한이 그만큼 올랐다." % [
		(float(with_cross["status_dps"]) / maxf(float(no_cross["status_dps"]), 0.01) - 1.0) * 100.0,
		(float(with_cross["raw_dps"]) / maxf(float(no_cross["raw_dps"]), 0.01) - 1.0) * 100.0])


## `enemy.gd`·`player.gd`의 Y7 상수. **값을 지어내지 않았다** — 저 파일의 선언과 같다.
## (두 파일은 Y8 소유가 아니라 `const`를 직접 참조할 수 없다. 이름을 다르게 두어
##  "여기가 사본"임을 드러낸다. 값이 갈리면 ⑪의 특수 열이 거짓말이 된다.)
const EnemyPinSeconds := 0.25
const EnemyPopSeconds := 0.30
const EnemySlowStrength := 0.35
const EnemySlowSeconds := 1.20
const EnemySlowRampFrom := 0.90
const EnemySlowRampTo := 0.50
const EnemySlowRampSeconds := 1.5
const PlayerHasteMultiplier := 1.20
const PlayerHasteSeconds := 0.80


## 한 바퀴에서 pin·pop이 대상을 세워 두는 시간.
func _measure_impact_hold(spec: Dictionary) -> Dictionary:
	var deck := _build_deck(spec)
	var rune_deck: Array = deck.rune_deck()
	var opts := deck.rune_opts()
	var pin_total := 0.0
	var pop_total := 0.0
	var time_total := 0.0
	for index in SEEDS:
		var cycle := RuneEngine.simulate_cycle(rune_deck, 1000003 + index * 7919, opts)
		var steps: Array = cycle.get("steps", [])
		var cycle_time := float(cycle.get("reload", 0.0))
		for entry in steps:
			var step: Dictionary = entry
			cycle_time += maxf(DealCycleController.MIN_STEP_DURATION, float(step.get("duration", 0.0)))
			var card := deck.compile_slot(int(step.get("slot", 0)))
			match String(card.get("impact", "")):
				"pin": pin_total += 1.0
				"pop": pop_total += 1.0
		time_total += cycle_time
	var count := float(SEEDS)
	var hold := pin_total / count * EnemyPinSeconds + pop_total / count * EnemyPopSeconds
	var cycle_time_mean := time_total / count
	return {
		"pin": pin_total / count,
		"pop": pop_total / count,
		"hold_seconds": hold,
		"cycle_time": cycle_time_mean,
		"hold_ratio": hold / maxf(cycle_time_mean, 0.01)
	}


func _stack_bonus_card_count() -> int:
	var count := 0
	for card: Dictionary in DealCardLibrary.SKILLS:
		if float(card.get("status_stack_bonus", 1.0)) > 1.0:
			count += 1
	return count


# =============================================================================
# ⑫ 성장 천장 첫 발화 시점
# =============================================================================
# 성장 천장 1안: 레일 5칸이 전부 R3이고 보관함도 포화하면 레벨업이 갈 곳을 잃는다.
# X1이 그 출구를 「각인 드래프트 자동 전환」에서 **「취소가 기본 제안」**으로 뒤집었다.
const GROWTH_CAP_CARDS_NEEDED := 20

func _print_growth_cap_table(run_curve: Array) -> void:
	print("--- ⑫ 성장 천장 첫 발화 시점 (필요 카드 %d장 · 자동전환 %s · 취소기본 %s) ---" % [
		GROWTH_CAP_CARDS_NEEDED,
		"on" if GameTuning.GROWTH_CAP_AUTO_RUNE_DRAFT else "off",
		"on" if GameTuning.GROWTH_CAP_DEFAULT_CANCEL else "off"])
	if run_curve.is_empty():
		return
	print("%-4s %8s %10s %11s %10s %9s" % ["st", "레벨", "레벨업누계", "상점구매가능", "카드누계", "천장"])
	var previous_level := 1
	var reached := 0
	var levelups_total := 0
	for row_value in run_curve:
		var row: Dictionary = row_value
		var stage := int(row["stage"])
		var level := int(row["level"])
		levelups_total += level - previous_level
		previous_level = level
		var price := SHOP_ITEM_BASE_PRICE * (1.0 + GameTuning.STAGE_PRICE_STEP * float(stage - 1))
		var shop_cards := floorf(float(row["stage_gold"]) * 0.25 / maxf(price, 1.0))
		# 트로피 2택1이 스테이지마다 1장씩 더 준다.
		var cards_total := float(levelups_total) + shop_cards * float(stage) + float(stage)
		if reached == 0 and cards_total >= float(GROWTH_CAP_CARDS_NEEDED):
			reached = stage
		print("%-4d %8d %10d %11.0f %10.0f %9s" % [
			stage, level, levelups_total, shop_cards, cards_total,
			"발화" if cards_total >= float(GROWTH_CAP_CARDS_NEEDED) else "—"])
	if reached == 0:
		print("→ 5스테이지 안에서 **천장에 닿지 않는다.** 취소 기본 제안은 과파밍 런에서만 열린다.")
	else:
		print("→ 천장 첫 발화 = **%d스테이지**. 그 뒤 레벨업은 취소가 기본 제안이 된다(X1)." % reached)
