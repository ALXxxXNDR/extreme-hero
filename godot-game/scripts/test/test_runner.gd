class_name TestRunner
extends Node

# =============================================================================
# 자동 테스트 / 프리뷰 / 시각 캡처 하네스 (W0에서 game.gd L254~963을 통째로 이관)
# =============================================================================
# 이 파일은 game.gd의 "바깥에서 게임을 조종하는 손"이다. 게임 규칙을 담지 않는다.
#
#   * 검사 내용은 v1과 한 줄도 다르지 않다. 옮기면서 바뀐 것은 두 가지뿐이다.
#       ① game.gd 멤버 접근에 `game.` 접두사가 붙었다.
#       ② `_quit_test_cleanly(passed)`가 종료 코드를 돌려준다(신설).
#   * 출력 포맷(V4_TEST_COMPLETE 등)은 그대로다. 셸 스크립트와 문서가 이걸 본다.
#   * W3(2026-08-07): 전투 판정·공간 해시가 core/combat_resolver.gd로 이관되면서
#     `game._spawn_enemy_instance` → `game.combat.spawn_enemy_instance` 식으로
#     소유자만 바뀌었다. 검사 항목·순서·출력 문자열은 여전히 v1과 동일하다.
#   * 실행 진입점은 game.gd `_ready()`의 `TestRunner.dispatch(self)` 한 줄이다.
#
# 새 테스트를 붙일 때:
#   1) ROUTINES에 [플래그, 메서드명, 인자] 한 줄을 추가한다.
#   2) 메서드 끝에서 반드시 `await _quit_test_cleanly(<합격여부>)`를 호출한다.
#      호출하지 않으면 게임이 종료되지 않아 run_all.sh가 타임아웃으로 죽는다.
#   3) scripts/test/run_all.sh의 TESTS 목록에도 플래그를 추가한다.
#
# 실행:  godot --headless --path godot-game -- --v4-test
# 전체:  bash godot-game/scripts/test/run_all.sh

# game.gd 인스턴스(메인 씬 루트). dispatch()가 주입한다.
var game: GameMain

# [커맨드라인 플래그, TestRunner 메서드명, 문자열 인자(없으면 "")].
# 순서는 v1 `_ready()`의 if/elif 사슬과 같다(먼저 일치하는 하나만 실행).
const ROUTINES: Array = [
	["--smoke-test", "_run_smoke_test", ""],
	["--combat-test", "_run_combat_test", ""],
	["--world-test", "_run_world_test", ""],
	# Y5 신설: 필드 생태 **런타임** 전용(설계 §5.2~§5.5). `--world-test`가 지형(정적
	# 계약)을 보고 이쪽은 그 위에서 사는 몹을 본다 — 습성 배선 · 낮 습성 5종 ·
	# 1·2스테이지 낮 선공 0 · 지형 가중 스폰 · 무리 스폰과 개체 상한 · 돌 우회.
	["--field-test", "_run_field_test", ""],
	["--v4-test", "_run_v4_test", ""],
	# W9: `--v4-castle-test` → `--castle-test` 개명(설계 §11 W9). 옛 플래그도 같은
	# 메서드로 남겨 둔다 — 다른 에이전트의 스크립트가 아직 쓸 수 있다.
	["--castle-test", "_run_castle_test", ""],
	["--v4-castle-test", "_run_castle_test", ""],
	["--rift-test", "_run_rift_test", ""],
	["--stress-test", "_run_stress_test", ""],
	# V0 신설 · 빈 골격 2종. 본문은 각각 V4(`--stage-test`)·V1(`--status-test`)이 채운다.
	# 등록부를 V0에서 미리 못 박아 두는 이유는 V1·V4가 완전 병렬로 돌기 때문이다 —
	# 둘이 나중에 이 배열을 동시에 고치면 그대로 충돌한다.
	["--stage-test", "_run_stage_test", ""],
	["--status-test", "_run_status_test", ""],
	["--cycle-test", "_run_cycle_test", ""],
	["--draft-test", "_run_draft_test", ""],
	["--boss-test", "_run_boss_test", ""],
	# W12 신설: 이어하기 E2E(저장 → 로드 → 균열·일차·각인·장비·마왕 상태 일치).
	["--save-test", "_run_save_test", ""],
	# U3 v3(2026-08-09) 신설: 스포트라이트 온보딩 길잡이.
	# 발동 조건 · 스텝 전이(입력 시뮬) · 스킵 2종 · 완료 플래그 저장 · 이어하기 미발동.
	["--guide-test", "_run_guide_test", ""],
	# Y6(2026-08-10) 신설: 발견 기반 내비 · 필드 사건 8종 · 소비 아이템 8종 · 상자 배당.
	["--event-test", "_run_event_test", ""],
	["--preview-choice", "_run_choice_preview", ""],
	["--preview-boss", "_run_boss_preview", ""],
	["--preview-world", "_run_world_preview", ""],
	["--preview-night", "_run_night_preview", ""],
	["--preview-onboarding", "_run_onboarding_preview", ""],
	["--preview-fate", "_run_fate_preview", ""],
	["--preview-evolution", "_run_evolution_preview", ""],
	["--preview-trial", "_run_rift_preview", ""],
	["--preview-rift", "_run_rift_preview", ""],
	["--preview-castle", "_run_castle_preview", ""],
	["--preview-build", "_run_build_preview", ""],
	["--preview-item", "_run_item_preview", ""],
	["--preview-effects", "_run_effects_preview", ""],
	["--preview-toast", "_run_toast_preview", ""],
	["--capture-lobby", "_run_visual_capture", "lobby"],
	["--capture-character", "_run_visual_capture", "character"],
	# U1 v3(2026-08-09) 신설. 설정 화면은 Godot 기본 `CheckButton` 3종과 기본
	# `HSlider`가 v1부터 그대로 남아 있던 마지막 자리였고, 이번에 킷 토글·킷 게이지로
	# 갈아 끼웠다. 육안 검수 창구가 없어 회귀를 캡처로 잡을 수 없었으므로 하나 판다.
	["--capture-settings", "_run_visual_capture", "settings"],
	["--capture-onboarding", "_run_visual_capture", "onboarding"],
	["--capture-world", "_run_visual_capture", "world"],
	["--capture-hud", "_run_visual_capture", "hud"],
	["--capture-factory", "_run_visual_capture", "factory"],
	["--capture-rail", "_run_visual_capture", "rail"],
	["--capture-draft", "_run_visual_capture", "draft"],
	# U2 v3(2026-08-09) 신설. 사용자가 직접 지목한 화면인데 육안 검수 창구가 하나도
	# 없었다(`--v4-test`가 포커스 모델만 본다). 아이템 2택도 같은 골격을 쓰므로 묶는다.
	# **X1이 3컷 → 5컷으로 재구성했다** — 레벨 업 2택 + 취소 / 포커스 2종 / 성장 천장 /
	# 아이템 2택(무변경 회귀). 컷별 검수 기준은 `_run_choice_capture()` 위 주석에 있다.
	["--capture-choice", "_run_visual_capture", "choice"],
	# U3 v3(2026-08-09) 신설 — 스포트라이트 길잡이 4컷(플레이어 · 5칸 레일 · 화살표 · 확인 칩).
	# 검수 항목: 스크림 위 구멍 경계 · 안내문 판독 · 키캡 실물 · 안내판 자리 뒤집기.
	["--capture-guide", "_run_visual_capture", "guide"],
	["--capture-effects", "_run_visual_capture", "effects"],
	["--capture-boss", "_run_visual_capture", "boss"],
	["--capture-castle", "_run_visual_capture", "castle"],
	["--capture-result", "_run_visual_capture", "result"]
]


# game.gd `_ready()` 끝에서 딱 한 번 불린다. 해당 플래그가 없으면 아무 일도 하지 않는다.
# 러너는 game의 자식 노드로 붙는다 -> get_tree()/get_viewport()가 v1과 같은 것을 가리킨다.
static func dispatch(game_node: GameMain) -> void:
	var args := OS.get_cmdline_user_args()
	for routine: Array in ROUTINES:
		if not (String(routine[0]) in args):
			continue
		var runner := TestRunner.new()
		runner.name = "TestRunner"
		runner.game = game_node
		runner.process_mode = Node.PROCESS_MODE_ALWAYS
		game_node.add_child(runner)
		var method := String(routine[1])
		var argument := String(routine[2])
		if argument.is_empty():
			runner.call_deferred(method)
		else:
			runner.call_deferred(method, argument)
		return


# v1에서는 --preview-onboarding이 game._show_onboarding을 직접 call_deferred 했다.
# 진입점을 러너로 일원화하기 위한 한 줄짜리 위임이며 실행 시점은 v1과 동일하다.
func _run_onboarding_preview() -> void:
	game._show_onboarding()

func _run_smoke_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	for index in 4:
		game._show_skill_choice("test")
		game._choose_skill(game.current_pair[0], game.current_pair[1])
		game._factory_lane_pressed(index % game.factory.slots.size(), 0)
		await get_tree().create_timer(0.04).timeout
	game.boss_items.append("r_greatsword_01")
	game._challenge_demon_king()
	game._begin_boss_battle()
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(game.boss):
		while game.boss.active_modules.has("rollback"):
			game.boss.active_modules.erase("rollback")
		game.boss.take_damage(100000.0, game.player.global_position)
	await get_tree().create_timer(0.6).timeout
	print("SMOKE_TEST_COMPLETE state=%s level=%d cards=%d rejections=%d boss_items=%d factory_slots=%d" % [game.state, game.level, game.selected_skills.size(), game.rejected_skills.size(), game.boss_items.size(), game.factory.slots.size()])
	# 스모크의 합격 조건은 "런 한 판이 오류 없이 승리 상태까지 도달했는가" 한 가지다.
	# v2 정합: 공장은 5칸 고정이고 그 위에서 한 판이 끝까지 돌아야 한다.
	var smoke_passed := game.state == "won" and game.rejected_skills.size() == 4 \
		and game.factory.slots.size() == FactoryDeck.SLOT_COUNT
	await _quit_test_cleanly(smoke_passed)

# =============================================================================
# --combat-test — v2의 12초 방치 소크 + **V6 상태이상 실전 통합 6묶음**
# =============================================================================
# `--status-test`는 `StatusEngine`을 **순수 로직**으로만 본다(노드도 좌표도 없다).
# 여기서 보는 것은 그 엔진이 **실제 게임에 배선됐는가**다. 두 스위트가 겹치지 않는다.
#
#   ① status_e2e    카드 한 방 → 적에게 상태가 실제로 붙고 핍까지 뜬다
#   ② blaze_live    기름+불 실전 배율 ×2.2 · 기름 소모 · 연 power ×3 · 지속 ×2.5
#   ③ conduction    감속 적을 실제로 배치 → 뇌가 4체까지 전이 · 비대상 무피해
#   ④ dot_kill      도트 킬이 provoke/종족 경보를 안 부르고 XP는 정상 지급
#   ⑤ budget_guard  프레임 예산 24 초과 0 · 전파 깊이 1 · 킬 체인 상한
#   ⑥ stage_scale   스테이지 배율이 **정확히 한 번만** 걸린다(V5 임시 스윕 이중 적용)
#
# 검사 구간에는 **await를 넣지 않는다.** 프레임이 넘어가지 않으므로 필드 마물·플레이어
# 평타 같은 외란이 측정 사이에 끼어들 수 없다(전부 델타 측정이다).
func _run_combat_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.35).timeout
	game.player.invulnerability = 99999.0
	game.player.crit_chance = 0.0
	game.xp_target = 9999999

	# 필드를 비우고 population을 잠근다. 자연 스폰이 반경 질의에 섞이면 전이 4체·
	# 광역 대상 수 같은 **개수 단언**이 난수에 좌우된다.
	_v6_clear_field()
	var saved_spawn_timer: float = game.combat.spawn_timer
	game.combat.spawn_timer = 99999.0

	# ---- ① 카드 타격 → 상태 부여 E2E ------------------------------------
	var fire_card := _v6_probe_card("flame_field")
	var e2e_target := _v6_dummy(Vector2(430.0, 0.0))
	game.combat.rebuild_enemy_spatial()
	var e2e_before: float = e2e_target.health
	game.apply_cycle_melee(game.player, fire_card, {}, false, Vector2.RIGHT, 1.0)
	var status_e2e_ok: bool = is_instance_valid(e2e_target) \
		and e2e_target.health < e2e_before \
		and StatusEngine.has(e2e_target.st_state, "burn") \
		and e2e_target.st_state[StatusEngine.F_BURN_UNIT] > 0.0 \
		and StatusEngine.pip_list(e2e_target.st_state).has("burn") \
		and is_equal_approx(StatusEngine.remaining(e2e_target.st_state, "burn"), GameTuning.BURN_DURATION)
	# 빙 카드는 한을 붙이고 실제 이동 속도를 깎는다(감속이 배선됐는가).
	var ice_card := _v6_probe_card("frost_ring")
	game.combat.strike_enemy_with_card(e2e_target, ice_card, 10.0, game.player.global_position)
	status_e2e_ok = status_e2e_ok and StatusEngine.has(e2e_target.st_state, "chill") \
		and StatusEngine.move_multiplier(e2e_target.st_state) < 1.0 \
		and not StatusEngine.has(e2e_target.st_state, "burn")     # 빙이 연을 끈다(소화)
	_v6_clear_field()
	# 투사체 경로(관통 계열 6장)도 상태를 남긴다. `projectile.gd`는 무수정이고
	# `body_entered`에 먼저 붙는 방식이라 **실제 명중**을 기다려야 확인된다.
	var shot_target := _v6_dummy(Vector2(220.0, 0.0))
	var shot_card := DealCardLibrary.ranked(DealCardLibrary.instance("earth_splitter", 1))
	shot_card["projectiles"] = 1
	shot_card["homing"] = 3.0
	shot_card["ricochet"] = 0
	shot_card["pierce"] = 0
	shot_card["range"] = 620.0
	game.combat.spawn_player_projectile(
		game.player.global_position + Vector2(30.0, 0.0), Vector2.RIGHT, 12.0, 650.0,
		3.0, 0, 0, GamePalette.ORANGE, "blade", 620.0, shot_card)
	await get_tree().create_timer(0.6).timeout
	status_e2e_ok = status_e2e_ok and is_instance_valid(shot_target) \
		and StatusEngine.has(shot_target.st_state, "burn") \
		and shot_target.health < shot_target.max_health
	_v6_clear_field()

	# ---- ② 기름 + 불 실전 배율 -------------------------------------------
	var plain_target := _v6_dummy(Vector2(430.0, 0.0))
	var oiled_target := _v6_dummy(Vector2(-430.0, 0.0))
	StatusEngine.set_status(oiled_target.st_state, "oil")
	game.combat.rebuild_enemy_spatial()
	var probe_damage := 120.0
	var plain_before: float = plain_target.health
	game.combat.strike_enemy_with_card(plain_target, fire_card, probe_damage, plain_target.global_position)
	var plain_dealt: float = plain_before - plain_target.health
	var oiled_before: float = oiled_target.health
	game.combat.strike_enemy_with_card(oiled_target, fire_card, probe_damage, oiled_target.global_position)
	var oiled_dealt: float = oiled_before - oiled_target.health
	var blaze_live_ok: bool = plain_dealt > 0.0 \
		and absf(oiled_dealt / maxf(plain_dealt, 0.001) - GameTuning.OIL_FIRE_TAKEN_MUL) < 0.01 \
		and not StatusEngine.has(oiled_target.st_state, "oil")
	# 대폭 연소: 연 power ×3 · 지속 ×2.5 (§4.4 ★)
	blaze_live_ok = blaze_live_ok \
		and absf(StatusEngine.remaining(oiled_target.st_state, "burn")
			- GameTuning.BURN_DURATION * GameTuning.SYN_BLAZE_DURATION_MUL) < 0.001 \
		and absf(float(oiled_target.st_state[StatusEngine.F_BURN_UNIT])
			/ maxf(float(plain_target.st_state[StatusEngine.F_BURN_UNIT]), 0.0001)
			- GameTuning.SYN_BLAZE_POWER_MUL) < 0.01
	var blaze_dot_before: float = oiled_target.health
	StatusEngine.tick_dot(oiled_target.st_state, GameTuning.STATUS_TICK)
	blaze_live_ok = blaze_live_ok and oiled_target.health <= blaze_dot_before
	_v6_clear_field()

	# ---- ③ 한 → 뇌 실전 전이 (감속 적을 실제로 배치한다) -----------------
	var chill_primary := _v6_dummy(Vector2(500.0, 0.0))
	var chill_neighbours: Array[Node] = []
	for index in 5:
		var neighbour := _v6_dummy(Vector2(500.0, 0.0) + Vector2.from_angle(TAU * float(index) / 5.0) * 120.0)
		StatusEngine.set_status(neighbour.st_state, "chill")
		chill_neighbours.append(neighbour)
	# 대조군 2기: 반경 안이지만 한이 없는 적 / 한은 있지만 반경 밖(260 초과)인 적
	var chill_control := _v6_dummy(Vector2(560.0, 60.0))
	var chill_far := _v6_dummy(Vector2(900.0, 0.0))
	StatusEngine.set_status(chill_far.st_state, "chill")
	StatusEngine.set_status(chill_primary.st_state, "chill")
	game.combat.rebuild_enemy_spatial()
	var neighbour_before: Array[float] = []
	for neighbour: Node in chill_neighbours:
		neighbour_before.append(float(neighbour.health))
	var control_before: float = chill_control.health
	var far_before: float = chill_far.health
	var thunder_card := _v6_probe_card("thunder")
	var conduction_p: float = 90.0 * game.current_cycle_potency()
	game.combat.strike_enemy_with_card(chill_primary, thunder_card, 90.0, chill_primary.global_position)
	var hit_deltas: Array[float] = []
	for index in chill_neighbours.size():
		var delta_value: float = neighbour_before[index] - float(chill_neighbours[index].health)
		if delta_value > 0.0001:
			hit_deltas.append(delta_value)
	hit_deltas.sort()
	hit_deltas.reverse()
	var conduction_ok: bool = hit_deltas.size() == GameTuning.SYN_CONDUCTION_MAX_TARGETS \
		and is_equal_approx(control_before, chill_control.health) \
		and is_equal_approx(far_before, chill_far.health)
	# 도약당 −20%는 `StatusEngine.chain_damage()` **단일 식**에서만 나와야 한다.
	var conduction_event := {
		"amount": GameTuning.SYN_CONDUCTION_DAMAGE * conduction_p,
		"falloff": GameTuning.SYN_CONDUCTION_FALLOFF
	}
	for index in hit_deltas.size():
		conduction_ok = conduction_ok \
			and absf(hit_deltas[index] - StatusEngine.chain_damage(conduction_event, index)) < 0.05
	# 전이 대상은 전 표식을 받고, 1차 대상의 한은 **소모되지 않는다**(§4.4 판단 #7).
	for neighbour: Node in chill_neighbours:
		if not StatusEngine.has(neighbour.st_state, "chill"):
			conduction_ok = false
	conduction_ok = conduction_ok and StatusEngine.has(chill_primary.st_state, "chill") \
		and game.combat.status_chain_hops >= GameTuning.SYN_CONDUCTION_MAX_TARGETS
	_v6_clear_field()

	# ---- ④ 도트 킬: provoke 우회 · XP 정상 -------------------------------
	# behavior 3(뿔임프)은 provoke에서 **반경 780px 종족 경보**를 쏜다. 도트 틱마다
	# 그게 나가면 78기 밤에서 즉사한다(§4.7 규칙 3). 그래서 `was_hit`/`aggro`가
	# 도트로는 절대 서면 안 된다.
	var dot_victim := _v6_dummy(Vector2(950.0, 0.0), "imp", 3, 60.0)
	var dot_witness := _v6_dummy(Vector2(1020.0, 0.0), "imp", 3, 60.0)
	game.combat.rebuild_enemy_spatial()
	StatusEngine.set_status(dot_victim.st_state, "burn", {"damage": 60.0})
	var dot_ticks_before: int = game.combat.status_dot_ticks
	var dot_health_before: float = dot_victim.health
	await get_tree().create_timer(0.45).timeout
	var dot_kill_ok: bool = is_instance_valid(dot_victim) \
		and dot_victim.health < dot_health_before \
		and game.combat.status_dot_ticks > dot_ticks_before \
		and not dot_victim.was_hit and not dot_victim.aggro \
		and is_instance_valid(dot_witness) and not dot_witness.was_hit and not dot_witness.aggro
	# 이제 죽인다 — 도트 킬도 보상 경로(`enemy_defeated`)를 그대로 타야 한다.
	var kills_before: int = game.kills
	var orbs_before: int = get_tree().get_nodes_in_group("xp_orbs").size()
	dot_victim.health = 0.5
	StatusEngine.set_status(dot_victim.st_state, "burn", {"damage": 60.0})
	await get_tree().create_timer(0.45).timeout
	dot_kill_ok = dot_kill_ok and game.kills == kills_before + 1 \
		and get_tree().get_nodes_in_group("xp_orbs").size() > orbs_before \
		and not is_instance_valid(dot_victim) \
		and is_instance_valid(dot_witness) and not dot_witness.was_hit and not dot_witness.aggro \
		and game.combat.kill_chain_peak <= GameTuning.STATUS_KILL_CHAIN_DEPTH_MAX + 1
	_v6_clear_field()

	# ---- ⑤ 반응 예산 24/프레임 · 전파 깊이 1 · 킬 체인 상한 --------------
	# 예산은 `_process`가 프레임마다 되감는다. 여기서는 되감지 않고 한 번에 상한을
	# 넘겨 **질의 이벤트만** 잘리는지 본다(상태 수치는 언제나 그대로여야 한다).
	var budget_primary := _v6_dummy(Vector2(430.0, 0.0))
	var budget_neighbour := _v6_dummy(Vector2(430.0, 90.0))     # 반경 130 안 = 기름 전파 대상
	game.combat.rebuild_enemy_spatial()
	game.combat.begin_status_frame()
	game.combat.status_suppressed_total = 0
	game.combat.status_max_depth_seen = 0
	game.combat.status_spread_applied = 0
	var overload_rounds: int = GameTuning.STATUS_REACTION_BUDGET_PER_FRAME + 8
	var last_blaze_duration := 0.0
	for _round in overload_rounds:
		StatusEngine.set_status(budget_primary.st_state, "oil")
		game.combat.strike_enemy_with_card(budget_primary, fire_card, 60.0, budget_primary.global_position)
		last_blaze_duration = StatusEngine.remaining(budget_primary.st_state, "burn")
	var budget_guard_ok: bool = int(game.combat.status_budget.get("used", 0)) <= GameTuning.STATUS_REACTION_BUDGET_PER_FRAME \
		and int(game.combat.status_budget.get("used", 0)) == GameTuning.STATUS_REACTION_BUDGET_PER_FRAME \
		and game.combat.status_suppressed_total >= overload_rounds - GameTuning.STATUS_REACTION_BUDGET_PER_FRAME
	# 예산이 바닥나도 **대폭 연소의 수치는 불변**이다(게임 규칙이 프레임률에 종속되면 안 된다).
	budget_guard_ok = budget_guard_ok \
		and absf(last_blaze_duration - GameTuning.BURN_DURATION * GameTuning.SYN_BLAZE_DURATION_MUL) < 0.001
	# 전파 깊이: spread가 실제로 depth 1에서 돌았고(=이벤트의 depth를 되넘겼다),
	# 깊이 2는 엔진이 구조적으로 막는다.
	budget_guard_ok = budget_guard_ok \
		and game.combat.status_spread_applied > 0 \
		and game.combat.status_max_depth_seen == GameTuning.STATUS_PROPAGATION_DEPTH \
		and StatusEngine.can_propagate(GameTuning.STATUS_PROPAGATION_DEPTH) == false \
		and StatusEngine.has(budget_neighbour.st_state, "oil") \
		and game.combat.kill_chain_peak <= GameTuning.STATUS_KILL_CHAIN_DEPTH_MAX + 1
	# 프레임이 넘어가면 예산이 다시 24로 돌아온다.
	game.combat.begin_status_frame()
	budget_guard_ok = budget_guard_ok \
		and StatusEngine.budget_left(game.combat.status_budget) == GameTuning.STATUS_REACTION_BUDGET_PER_FRAME
	_v6_clear_field()

	# ---- ⑥ 스테이지 배율 이중 적용 없음 ----------------------------------
	# V5는 game.gd에서 프레임 스윕으로 배율을 먹였고 V6이 스폰 경로로 옮겼다.
	# 둘 다 살아 있으면 배율이 **제곱**된다(5스테이지 dwell 4에서 ×5.61 → ×31.5).
	var scale_power: float = float(game.cycle_number - 1) * 1.1 + float(game.level - 1) * 0.32 \
		+ minf(game.elapsed_time / 180.0, 2.5)
	var base_hp: float = MonsterLibrary.health_for(MonsterLibrary.by_id("mossling"), scale_power)
	var stage_scale_ok: bool = not game.has_method("_sweep_stage_scaling") \
		and not game.has_method("_apply_stage_scaling_to")
	# 스테이지 1 · dwell 0 = **v2와 완전 등가**(다섯 배율이 전부 정확히 1.0).
	stage_scale_ok = stage_scale_ok \
		and is_equal_approx(game.clock.enemy_hp_multiplier(), 1.0) \
		and is_equal_approx(game.clock.enemy_damage_multiplier(), 1.0) \
		and is_equal_approx(game.clock.enemy_speed_multiplier(), 1.0) \
		and is_equal_approx(game.clock.xp_multiplier(), 1.0) \
		and is_equal_approx(game.clock.gold_multiplier(), 1.0)
	var flat_probe := _v6_dummy(Vector2(300.0, 0.0), "mossling", 1, -1.0)
	stage_scale_ok = stage_scale_ok and is_instance_valid(flat_probe) \
		and absf(float(flat_probe.max_health) - base_hp) < 0.01
	# 스테이지 3 · dwell 4에서도 **한 번만** 곱한다.
	var saved_stage: int = game.clock.stage
	var saved_dwell: int = game.clock.dwell
	game.clock.set_stage_raw(3)
	game.clock.set_dwell_raw(4)
	var scaled_probe := _v6_dummy(Vector2(-300.0, 0.0), "mossling", 1, -1.0)
	var single_mul: float = game.clock.enemy_hp_multiplier()
	stage_scale_ok = stage_scale_ok and is_instance_valid(scaled_probe) \
		and single_mul > 1.5 \
		and absf(float(scaled_probe.max_health) - base_hp * single_mul) < 0.01 \
		and absf(float(scaled_probe.max_health) - base_hp * single_mul * single_mul) > 0.01
	game.clock.set_stage_raw(saved_stage)
	game.clock.set_dwell_raw(saved_dwell)
	_v6_clear_field()

	# =========================================================================
	# Y7 ⑥ 충격 프로필 8종 (§7.3) — 카드가 대상에게 **무엇을** 하는가
	# =========================================================================
	# `deal_card_library.impact_reaction()`이 넉백·경직 수치를 내는 것은 `data_test`가
	# 이미 문다. 여기서 재는 것은 **런타임에 실제로 걸리는가**다 — 표에 적힌 여덟 줄이
	# 전부 대상 노드의 상태를 바꿔야 한다. 하나라도 배선이 빠지면 그 줄만 빨개진다.
	var impact_profile_ok := true
	var impact_seen: Array[String] = []

	# ⓐ push — 밀친다. 넉백 속도가 실제로 붙는다.
	var push_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	game.combat.strike_enemy_with_card(push_target, _v7_impact_card("cleave"), 4.0, game.player.global_position)
	var push_speed: float = (push_target.knockback_velocity as Vector2).length()
	impact_profile_ok = impact_profile_ok and push_speed > 60.0 and push_target.hit_stun_timer > 0.0
	impact_seen.append("push")
	_v6_clear_field()

	# ⓑ pin — **밀리지 않고** 그 자리에 못 박힌다(정지 0.25초).
	var pin_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	game.combat.strike_enemy_with_card(pin_target, _v7_impact_card("execution"), 4.0, game.player.global_position)
	# 넉백은 0, 정지는 켜지고, **경직은 오히려 가장 길다**(§7.3 "경직 김").
	impact_profile_ok = impact_profile_ok \
		and (pin_target.knockback_velocity as Vector2).length() < 0.01 \
		and pin_target.pin_timer > 0.0 \
		and pin_target.hit_stun_timer > 0.15
	impact_seen.append("pin")
	_v6_clear_field()

	# ⓒ slow — 이동 −35% 1.2초. 임프는 slow_sens 1.0이라 표 값이 그대로 보인다.
	var slow_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	game.combat.strike_enemy_with_card(slow_target, _v7_impact_card("dash_blade"), 4.0, game.player.global_position)
	impact_profile_ok = impact_profile_ok \
		and absf(float(slow_target.cycle_slow_multiplier) - (1.0 - DebtEnemy.IMPACT_SLOW_STRENGTH)) < 0.01 \
		and absf(float(slow_target.cycle_slow_timer) - DebtEnemy.IMPACT_SLOW_SECONDS) < 0.05 \
		and not bool(slow_target.cycle_slow_ramp)
	impact_seen.append("slow")
	_v6_clear_field()

	# ⓓ rush — 「점점 느려짐」. 켜진 순간은 0.9이고 **시간이 흐를수록 더 내려간다.**
	#    한 시점만 재면 고정 감속과 구별이 안 되므로 두 시점을 재서 방향을 본다.
	var rush_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	game.combat.strike_enemy_with_card(rush_target, _v7_impact_card("aura"), 4.0, game.player.global_position)
	var rush_start: float = rush_target.cycle_slow_multiplier
	impact_profile_ok = impact_profile_ok and bool(rush_target.cycle_slow_ramp) \
		and absf(rush_start - DebtEnemy.SLOW_RAMP_FROM) < 0.01
	await get_tree().create_timer(0.7).timeout
	var rush_late: float = rush_target.cycle_slow_multiplier if is_instance_valid(rush_target) else rush_start
	impact_profile_ok = impact_profile_ok and rush_late < rush_start - 0.05 \
		and rush_late >= DebtEnemy.SLOW_RAMP_TO - 0.001
	impact_seen.append("rush")
	_v6_clear_field()

	# ⓔ pop — 0.3초 공중. 떠 있는 동안에는 **때리지 못한다**(접촉 판정이 꺼진다).
	var pop_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	game.combat.strike_enemy_with_card(pop_target, _v7_impact_card("holy_pulse"), 4.0, game.player.global_position)
	impact_profile_ok = impact_profile_ok and pop_target.airborne_timer > 0.0
	impact_seen.append("pop")
	_v6_clear_field()

	# ⓕ stagger — 겨누던 공격이 취소된다.
	var stagger_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	stagger_target.contact_timer = 0.0
	stagger_target.fire_timer = 0.0
	game.combat.strike_enemy_with_card(stagger_target, _v7_impact_card("shield_bash"), 4.0, game.player.global_position)
	impact_profile_ok = impact_profile_ok and int(stagger_target.staggered_count) == 1 \
		and stagger_target.contact_timer > 0.4 and stagger_target.fire_timer > 0.8
	impact_seen.append("stagger")
	_v6_clear_field()

	# ⓖ drag — 중심 쪽으로 당겨진다. 카드에 `pull` 키가 없어도 성립해야 한다
	#    (프로브 카드가 `pull`을 0으로 지운 채로 재는 것이 이 줄의 요점이다).
	var drag_target := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	var drag_before: float = drag_target.global_position.distance_to(game.player.global_position)
	game.combat.strike_enemy_with_card(drag_target, _v7_impact_card("gravity_well"), 4.0, game.player.global_position)
	var drag_after: float = drag_target.global_position.distance_to(game.player.global_position)
	impact_profile_ok = impact_profile_ok and drag_after < drag_before - 20.0
	impact_seen.append("drag")
	_v6_clear_field()

	# ⓗ haste_self — 대상이 아니라 **내가** 빨라진다. 카드 발사 경로를 통째로 태워
	#    `cycle_skill_effect`가 신호를 내는지까지 본다(직접 `apply_haste()`를 부르면
	#    배선이 끊겨 있어도 통과한다 — 그 함정을 피하려고 실전 경로로 잰다).
	game.player.haste_timer = 0.0
	game.player.haste_multiplier = 1.0
	var haste_effect: CycleSkillEffect = DealCycleController.EFFECT_SCRIPT.new()
	haste_effect.setup(game, game.player, DealCardLibrary.ranked(DealCardLibrary.instance("time_cut", 1)), false, 1.0)
	game.gameplay_root.add_child(haste_effect)
	await get_tree().create_timer(0.25).timeout
	impact_profile_ok = impact_profile_ok and game.player.haste_timer > 0.0 \
		and absf(float(game.player.haste_multiplier) - SurvivorPlayer.HASTE_MULTIPLIER) < 0.001
	impact_seen.append("haste_self")
	if is_instance_valid(haste_effect):
		haste_effect.queue_free()
	game.player.haste_timer = 0.0
	game.player.haste_multiplier = 1.0
	_v6_clear_field()

	# 여덟 줄을 전부 밟았는가. 하나라도 빠지면 "안 재고 통과"다.
	impact_profile_ok = impact_profile_ok and impact_seen.size() == 8

	# ⓘ §4.5 `stack_bonus` — 「맹독 십자」만 독을 **두 배로** 쌓는다.
	#    ⚠️ Y7이 열어 보니 이 채널이 **한 번도 배선된 적이 없었다.**
	#    `status_engine.gd:483`은 "combat_resolver가 카드의 `status_stack_bonus`를
	#    ctx에 실어 준다"고 적어 뒀는데 실제로는 아무도 안 실었다 — 그 카드의 콤보
	#    문구가 지금까지 거짓이었다. 같은 독 카드 두 장을 나란히 재서 계약을 건다.
	var stack_plain := _v6_dummy(Vector2(240.0, 0.0), "imp", 3)
	var stack_double := _v6_dummy(Vector2(-240.0, 0.0), "imp", 3)
	var plain_poison := DealCardLibrary.ranked(DealCardLibrary.instance("whirlwind", 1))
	var double_poison := DealCardLibrary.ranked(DealCardLibrary.instance("cross_cut", 1))
	# 첫 타는 독을 붙이기만 한다(스택은 이미 붙어 있을 때만 는다 · `_row_poison`).
	for _round in 2:
		game.combat.strike_enemy_with_card(stack_plain, plain_poison, 4.0, stack_plain.global_position)
		game.combat.strike_enemy_with_card(stack_double, double_poison, 4.0, stack_double.global_position)
	var plain_stacks := StatusEngine.stacks(stack_plain.st_state)
	var double_stacks := StatusEngine.stacks(stack_double.st_state)
	# 첫 부여는 두 카드 모두 1스택이다(§4.5는 **덧씌우는 쪽**만 바꾼다) — 그래서
	# 계약은 "덧씌운 만큼이 두 배"다. 스택 상한 값에 안 묶이게 관계식으로 쓴다.
	impact_profile_ok = impact_profile_ok \
		and absf(float(double_poison.get("status_stack_bonus", 0.0)) - 2.0) < 0.001 \
		and plain_stacks >= 2 and double_stacks == (plain_stacks - 1) * 2 + 1
	_v6_clear_field()

	# =========================================================================
	# Y7 ⑦ 몹별 피격 반응 프로필 (§7.2) — **같은 카드, 다른 반응**
	# =========================================================================
	# 감수성 표가 데이터에만 있고 런타임에 안 곱해지면 열 종이 전부 똑같이 밀린다.
	# 절대값이 아니라 **비율**로 재는 이유는 카드 수치가 바뀌어도 계약이 살아남게
	# 하기 위해서다(Y8이 밸런스를 흔들어도 이 검사는 안 깨진다).
	var mob_reaction_ok := true
	var push_card := _v7_impact_card("cleave")

	# ⓐ 넉백: 위습(2.0) vs 오우거(0.25). 오우거는 `visual_variant` resistance 0.46까지
	#    겹쳐 걸리므로 격차는 표보다 더 벌어진다 — 방향만 계약으로 건다.
	var light_mob := _v6_dummy(Vector2(240.0, 0.0), "wisp", 3)
	var heavy_mob := _v6_dummy(Vector2(-240.0, 0.0), "ogre", 2)
	game.combat.strike_enemy_with_card(light_mob, push_card, 4.0, game.player.global_position)
	game.combat.strike_enemy_with_card(heavy_mob, push_card, 4.0, game.player.global_position)
	var light_kb: float = (light_mob.knockback_velocity as Vector2).length()
	var heavy_kb: float = (heavy_mob.knockback_velocity as Vector2).length()
	mob_reaction_ok = mob_reaction_ok and light_kb > heavy_kb * 4.0 and heavy_kb > 0.0
	# 표가 실제로 개체에 실렸는가(사본이 비어 있으면 위 비율이 우연히 맞을 수 있다).
	mob_reaction_ok = mob_reaction_ok \
		and absf(float(light_mob.kb_sens) - 2.0) < 0.001 \
		and absf(float(heavy_mob.kb_sens) - 0.25) < 0.001 \
		and String(light_mob.hit_flavor) != "" and String(heavy_mob.hit_flavor) != ""
	_v6_clear_field()

	# ⓑ 경직: 해골(1.5) vs 지옥견(0.6). 같은 카드에서 2.5배 차이가 나야 한다.
	var stiff_mob := _v6_dummy(Vector2(240.0, 0.0), "skeleton", 2)
	var loose_mob := _v6_dummy(Vector2(-240.0, 0.0), "hellhound", 4)
	game.combat.strike_enemy_with_card(stiff_mob, push_card, 4.0, game.player.global_position)
	game.combat.strike_enemy_with_card(loose_mob, push_card, 4.0, game.player.global_position)
	var stiff_stun: float = stiff_mob.hit_stun_timer
	var loose_stun: float = loose_mob.hit_stun_timer
	mob_reaction_ok = mob_reaction_ok and loose_stun > 0.0 \
		and absf(stiff_stun / maxf(loose_stun, 0.0001) - 2.5) < 0.15
	_v6_clear_field()

	# ⓒ 둔화: 그림자(1.5) vs 해골(0.6). 깊이가 갈린다.
	var soft_mob := _v6_dummy(Vector2(240.0, 0.0), "shade", 4)
	var tough_mob := _v6_dummy(Vector2(-240.0, 0.0), "skeleton", 2)
	var slow_card := _v7_impact_card("dash_blade")
	game.combat.strike_enemy_with_card(soft_mob, slow_card, 4.0, game.player.global_position)
	game.combat.strike_enemy_with_card(tough_mob, slow_card, 4.0, game.player.global_position)
	mob_reaction_ok = mob_reaction_ok \
		and absf(float(soft_mob.cycle_slow_multiplier) - (1.0 - 0.35 * 1.5)) < 0.01 \
		and absf(float(tough_mob.cycle_slow_multiplier) - (1.0 - 0.35 * 0.6)) < 0.01 \
		and float(soft_mob.cycle_slow_multiplier) < float(tough_mob.cycle_slow_multiplier)
	_v6_clear_field()

	# ⓓ 들멧돼지의 「돌진 중 넉백 0」. **음성 축이 반드시 같이 있어야 한다** —
	#    항상 0이면 "안 밀린다"가 공허하게 통과한다. 멀리 서 있는 같은 종은 밀린다.
	var charging_boar := _v6_dummy(Vector2(40.0, 0.0), "boar", 2)
	charging_boar.aggro = true
	charging_boar.charging = true
	var idle_boar := _v6_dummy(Vector2(-520.0, 0.0), "boar", 2)
	idle_boar.aggro = false
	idle_boar.charging = false
	game.combat.strike_enemy_with_card(charging_boar, push_card, 4.0, game.player.global_position)
	game.combat.strike_enemy_with_card(idle_boar, push_card, 4.0, game.player.global_position)
	var charge_kb: float = (charging_boar.knockback_velocity as Vector2).length()
	var idle_kb: float = (idle_boar.knockback_velocity as Vector2).length()
	mob_reaction_ok = mob_reaction_ok and bool(charging_boar.kb_zero_while_charging) \
		and charge_kb < 0.01 and idle_kb > 40.0
	# 넉백만 0이고 경직은 그대로다(멧돼지가 무적이 되면 안 된다).
	mob_reaction_ok = mob_reaction_ok and charging_boar.hit_stun_timer > 0.0
	_v6_clear_field()

	# ---- v2 소크: 12초 방치 후에도 필드가 살아 있고 몹이 스폰돼 있는가 ----
	game.combat.spawn_timer = saved_spawn_timer
	await get_tree().create_timer(12.0).timeout
	print("COMBAT_TEST_COMPLETE state=%s status_e2e=%s blaze_live=%s conduction=%s dot_kill=%s budget_guard=%s stage_scale=%s impact_profile=%s mob_reaction=%s impacts=%d kb_light=%.1f kb_heavy=%.1f stun_ratio=%.2f kills=%d xp=%d enemies=%d phase=%s oil_mul=%.4f blaze_ratio=%.4f chain_hops=%d dot_ticks=%d reactions=%d suppressed=%d chain_depth=%d" % [
		game.state, status_e2e_ok, blaze_live_ok, conduction_ok, dot_kill_ok, budget_guard_ok, stage_scale_ok,
		impact_profile_ok, mob_reaction_ok, impact_seen.size(), light_kb, heavy_kb,
		stiff_stun / maxf(loose_stun, 0.0001),
		game.kills, game.experience, get_tree().get_nodes_in_group("enemies").size(), "night" if game.is_night else "day",
		oiled_dealt / maxf(plain_dealt, 0.001), GameTuning.SYN_BLAZE_POWER_MUL * GameTuning.SYN_BLAZE_DURATION_MUL,
		game.combat.status_chain_hops, game.combat.status_dot_ticks,
		game.combat.status_reactions_fired, game.combat.status_suppressed_total, game.combat.kill_chain_peak
	])
	# 12초 방치 후에도 필드가 살아 있고 몹이 스폰돼 있으면 통과(kills/enemies 수치는 난수라 판정에 쓰지 않는다).
	var combat_passed := game.state == "playing" and get_tree().get_nodes_in_group("enemies").size() > 0 \
		and status_e2e_ok and blaze_live_ok and conduction_ok and dot_kill_ok \
		and budget_guard_ok and stage_scale_ok and impact_profile_ok and mob_reaction_ok
	await _quit_test_cleanly(combat_passed)


## Y7 프로브 카드. `_v6_probe_card`와 같은 수법이되 **`impact` 키를 반드시 살린다** —
## 이 검사가 재는 것이 바로 그 키의 런타임 효과이므로, 다른 축(상태이상·흡혈·난수)만
## 지운다. `slow`·`pull` 카드 키를 0으로 지우는 것도 의도적이다: 시간 효과가
## **impact 프로필에서 오는지** 아니면 옛 카드 키에서 오는지 구분하기 위해서다.
func _v7_impact_card(card_id: String) -> Dictionary:
	var card := _v6_probe_card(card_id)
	card["heavy"] = false     # heavy 보정이 authored impact 위에 겹쳐 보이지 않게 한다
	card["hits"] = 1
	return card


# --- V6 통합 검사 보조 3종 ---------------------------------------------------

## 필드를 완전히 비운다. 반경 질의 기반 **개수 단언**은 외란이 하나라도 섞이면 무너진다.
func _v6_clear_field() -> void:
	for enemy: Node in game.combat.active_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	game.combat.active_enemies.clear()
	game.combat.enemy_spatial.clear()


## 검사용 마물. `hp < 0`이면 체력을 손대지 않는다(스테이지 배율 실측용).
func _v6_dummy(offset: Vector2, kind: String = "mossling", behavior: int = 1, hp: float = 100000.0) -> Node:
	var spawn_at: Vector2 = game.player.global_position + offset
	var enemy := game.combat.spawn_enemy_instance(spawn_at, behavior, "", false, "", false, kind, true)
	if not is_instance_valid(enemy):
		return null
	# 걸을 수 없는 자리로 밀리지 않게 좌표를 고정하고 공간 해시를 그 자리로 다시 잡는다.
	enemy.global_position = spawn_at
	enemy.home_position = spawn_at
	enemy.aggro = false
	enemy.raid_mode = false
	if hp >= 0.0:
		enemy.max_health = hp
		enemy.health = hp
		enemy.displayed_health = hp
		enemy.trailing_health = hp
	game.combat.rebuild_enemy_spatial()
	return enemy


## 근접 원뿔로 확실히 맞히는 프로브 카드. 원소·색만 살리고 판정 파라미터를 고정한다.
## (`--cycle-test`의 `probe_card`와 같은 수법 — 난수·부수효과를 전부 뺀다.)
func _v6_probe_card(card_id: String) -> Dictionary:
	var card := DealCardLibrary.ranked(DealCardLibrary.instance(card_id, 1))
	card["kind"] = "melee"
	card["range"] = 600.0
	card["arc"] = TAU
	card["crit"] = 0.0
	card["lifesteal"] = 0.0
	card["slow"] = 0.0
	card["pull"] = 0.0
	card["damage"] = maxf(0.5, float(card.get("damage", 1.0)))
	return card

# =============================================================================
# --world-test (V5 재작성) — v3 스테이지 랜드마크 · 아틀라스 · WFC 스트리밍
# =============================================================================
# v2가 보던 "고정 시작 성 (250,-250) + 고정 마왕성 (6840,-5260)"은 v3에 없다.
# 대신 스테이지마다 **성 1 + 베이스캠프 1 + 보스문 1**이 시드로 놓인다(설계 §2.3).
# WFC 검사(로컬 규칙 · 이음매 · 스트리밍 · 결정성 · 캐시 상한)는 v2 그대로 승계한다.
func _run_world_test() -> void:
	game._start_game()
	await get_tree().create_timer(0.25).timeout

	# ---- ① 랜드마크 3종이 정확히 1개씩 있고 상호작용으로 잡힌다 ---------------
	var landmarks: Dictionary = game.world.get_stage_landmarks()
	var landmark_ok: bool = landmarks.size() == 3 \
		and landmarks.has("castle") and landmarks.has("camp") and landmarks.has("boss_gate")
	var castle_feature: Dictionary = game.world.get_nearest_interactable(game.world.get_castle_position(), 120.0)
	var camp_feature: Dictionary = game.world.get_nearest_interactable(game.world.get_camp_position(), 120.0)
	var gate_feature: Dictionary = game.world.get_nearest_interactable(game.world.get_boss_gate_position(), 120.0)
	landmark_ok = landmark_ok and String(castle_feature.get("type", "none")) == "castle" \
		and String(camp_feature.get("type", "none")) == "camp" \
		and String(gate_feature.get("type", "none")) == "boss_gate"
	# 셋 다 바닥이 덮여 있어 걸어 들어갈 수 있어야 한다.
	landmark_ok = landmark_ok and game.world.is_walkable(game.world.get_castle_position()) \
		and game.world.is_walkable(game.world.get_camp_position()) \
		and game.world.is_walkable(game.world.get_boss_gate_position())
	landmark_ok = landmark_ok and game.world.boss_gate_at(game.world.get_boss_gate_position()) \
		and game.world.camp_at(game.world.get_camp_position())

	# ---- ② 배치 규칙 — 거리와 "캠프가 보스문보다 먼저" -------------------------
	var castle_distance: float = game.world.get_castle_position().length()
	var gate_distance: float = game.world.get_boss_gate_position().length()
	var camp_distance: float = game.world.get_camp_position().length()
	var camp_to_gate: float = game.world.get_camp_position().distance_to(game.world.get_boss_gate_position())
	# 마른 자리 탐색이 후보를 흔들 수 있으므로 설계 창에 여유를 준다(탐색 반경 상한 = 60 + 47×26).
	var placement_ok: bool = castle_distance >= GameTuning.STAGE_CASTLE_DISTANCE_MIN - 400.0 \
		and castle_distance <= GameTuning.STAGE_CASTLE_DISTANCE_MAX + 1400.0 \
		and gate_distance >= GameTuning.STAGE_BOSS_GATE_DISTANCE_MIN - 1400.0 \
		and gate_distance <= GameTuning.STAGE_BOSS_GATE_DISTANCE_MAX + 1400.0
	# **캠프는 반드시 보스문보다 먼저 만나야 한다**(사용자 요구 "보스방 앞 베이스 캠프").
	placement_ok = placement_ok and camp_distance < gate_distance \
		and camp_to_gate <= GameTuning.STAGE_CAMP_OFFSET_FROM_GATE + 1400.0
	# 랜덤 성은 삭제됐다 — 스폰 주변 대영역에 성이 정확히 하나뿐이어야 한다(설계 §2.3).
	placement_ok = placement_ok and GameTuning.CASTLE_FEATURE_ROLL == 0

	# ---- ③ 스테이지 시드 — 스테이지마다 다르고 같은 시드면 같은 자리 -----------
	var seed_1: int = game.stage_world_seed(1)
	var seed_3: int = game.stage_world_seed(3)
	var seed_ok: bool = seed_1 != seed_3 and game.stage_world_seed(1) == seed_1
	var stage1_gate: Vector2 = game.world.get_boss_gate_position()
	var stage1_atlas: String = game.world.stage_atlas_key
	# Y5(§5.1 · 리스크 4): **물 비율 계약 12~20%.** 호수 격자를 18 → 13으로 줄여
	# 물을 늘렸으므로, 늘어난 물이 랜드마크·균열이 설 자리를 먹어치우지 않는지를
	# 숫자로 못 박는다. 스테이지마다 시드가 달라 지형도 다르므로 1·3·5를 각각 잰다.
	# 창은 스폰에서 멀리 잡는다 — 스폰 둘레에는 dry zone이 깔려 있어 거기서 재면
	# 물이 실제보다 적게 나오고, 계약이 조용히 헐거워진다.
	var wet_1 := _wet_ratio_here()
	# 스테이지 3으로 월드를 갈아 끼운다 — 지형 벌·랜드마크가 통째로 바뀌어야 한다.
	game.clock.set_stage_raw(3)
	game._rebuild_stage_world(3)
	await get_tree().process_frame
	var wet_3 := _wet_ratio_here()
	var stage3_gate: Vector2 = game.world.get_boss_gate_position()
	seed_ok = seed_ok and not stage1_gate.is_equal_approx(stage3_gate)
	var atlas_ok: bool = stage1_atlas == String(GameTuning.STAGE_TERRAIN_ATLAS[0]) \
		and game.world.stage_atlas_key == String(GameTuning.STAGE_TERRAIN_ATLAS[2]) \
		and stage1_atlas != game.world.stage_atlas_key
	# 5스테이지는 심연(abyss) + 비네트 + 채도 0.65다.
	game.clock.set_stage_raw(5)
	game._rebuild_stage_world(5)
	await get_tree().process_frame
	var wet_5 := _wet_ratio_here()
	atlas_ok = atlas_ok and game.world.stage_atlas_key == "abyss" \
		and is_equal_approx(game.world.stage_saturation, GameTuning.STAGE_SATURATION[4]) \
		and bool(GameTuning.STAGE_VIGNETTE[4]) \
		and GameTuning.STAGE_FOG_ALPHA[4] > GameTuning.STAGE_FOG_ALPHA[0]
	# 스테이지 1로 되돌려 나머지 WFC 검사를 v2와 같은 조건에서 한다.
	game.clock.set_stage_raw(1)
	game._rebuild_stage_world(1)
	await get_tree().process_frame

	# ---- ④ 고정 물길과 다리 (v2 승계) -----------------------------------------
	var river_blocked: bool = not game.world.is_walkable(Vector2(820.0, 250.0))
	var bridge_open: bool = game.world.is_walkable(Vector2(820.0, 0.0))

	# =========================================================================
	# Y5 신설 4묶음 (설계 §5.1 · 리스크 3·4) — 여기부터는 다시 스테이지 1 월드다
	# =========================================================================
	# ---- ⓐ wet : 물 비율 12~20% ----------------------------------------------
	var wet_ok: bool = _wet_in_band(wet_1) and _wet_in_band(wet_3) and _wet_in_band(wet_5)

	# ---- ⓑ rock_blocks : 돌은 못 지나간다 --------------------------------------
	# 돌을 **실제로 하나 찾아** 그 자리에서 재는 것이 핵심이다. 필드에 돌이 0개면
	# "돌은 못 지나간다"가 아무것도 안 재는 문장이 되므로 그 경우를 실패로 다룬다.
	var rock_find: Dictionary = _find_rock_tile(game.world, Vector2.ZERO, 34, false)
	var rock_found: bool = bool(rock_find.get("has", false))
	var rock_point: Vector2 = rock_find.get("point", Vector2.ZERO)
	var rock_blocks_ok: bool = rock_found \
		and not game.world.is_walkable(rock_point) \
		and game.world.is_rock_at(rock_point) \
		and game.world.tile_kind_at(rock_point) == "rocks"

	# ---- ⓒ landmark_reach : 랜드마크로 걸어 들어갈 길이 있다 (리스크 3) ---------
	var castle_reach: Dictionary = _landmark_reachable(game.world, game.world.get_castle_position(), game.world.SAFE_ZONE_CASTLE)
	var camp_reach: Dictionary = _landmark_reachable(game.world, game.world.get_camp_position(), game.world.SAFE_ZONE_CAMP)
	var gate_reach: Dictionary = _landmark_reachable(game.world, game.world.get_boss_gate_position(), game.world.boss_gate_radius)
	var landmark_reach_ok: bool = bool(castle_reach["ok"]) and bool(camp_reach["ok"]) and bool(gate_reach["ok"])

	# ---- ⓓ tile_kind : 이름표가 눈에 보이는 것과 같다 ---------------------------
	# 물 한복판은 water나 shore_*, 다리 행은 bridge, 성·캠프 안쪽은 courtyard,
	# 보스문 아레나 바닥은 camp다(world_grid._resolved_tile_id의 덮개 규칙 그대로).
	var river_kind: String = game.world.tile_kind_at(Vector2(820.0, 250.0))
	var bridge_kind: String = game.world.tile_kind_at(Vector2(820.0, 0.0))
	var castle_kind: String = game.world.tile_kind_at(game.world.get_castle_position())
	var camp_kind: String = game.world.tile_kind_at(game.world.get_camp_position())
	var gate_kind: String = game.world.tile_kind_at(game.world.get_boss_gate_position())
	var tile_kind_ok: bool = (river_kind == "water" or river_kind.begins_with("shore_")) \
		and bridge_kind == "bridge" and castle_kind == "courtyard" \
		and camp_kind == "courtyard" and gate_kind == "camp"

	# ---- ⓔ spawn_open : 시작 자리가 막히는 빈도 ---------------------------------
	# 원점이 가끔 돌에 걸리는 것 자체는 `_walkable_spawn_point()`가 구제한다. 문제는
	# **빈도**다. 시드를 고정해 결정적으로 재고, ⑴ 원점이 열려 있는 비율 ⑵ 원점에서
	# 한 칸이라도 빠져나갈 수 있는가 ⑶ 구제 경로가 실제로 걸을 수 있는 자리를 주는가
	# 셋을 본다. ⑶은 `find_walkable_near()`가 24회 실패하면 걸을 수 없는 자리를
	# 그대로 돌려주므로 공허하지 않다.
	var spawn_census: Dictionary = _spawn_open_census()
	var spawn_open_ok: bool = bool(spawn_census["ok"])

	# ---- ⑤ WFC — 로컬 규칙 · 이음매 · 스트리밍 · 결정성 · 캐시 상한 (v2 승계) ---
	var generation_check := game.world.validate_generation_near(Vector2.ZERO)
	var sample_point := Vector2(1240.0, 1320.0)
	var sample_before := game.world.get_tile_id(sample_point)
	var streaming_rules_ok := true
	for step in 12:
		var direction := -1.0 if step % 2 == 0 else 1.0
		var far_point := Vector2(direction * (12000.0 + step * 7800.0), -direction * (9000.0 + step * 5300.0))
		var far_check := game.world.validate_generation_near(far_point)
		streaming_rules_ok = streaming_rules_ok and bool(far_check.get("local_rules", false)) and bool(far_check.get("seams", false))
	var sample_after := game.world.get_tile_id(sample_point)
	var generation_stats := game.world.get_generation_stats()
	var cache_bounded := int(generation_stats.get("cached_chunks", 0)) <= 72
	var deterministic := sample_before == sample_after

	# Y5 실측값을 숫자로 남긴다 — 계약이 어디쯤에서 지켜지고 있는지 다음 웨이브가
	# 로그만 보고 알 수 있어야 한다(창을 넓히거나 좁힐 판단의 유일한 근거다).
	print("    wet1=%.1f%% wet3=%.1f%% wet5=%.1f%% band=%.0f~%.0f%% span=%d stride=%d" % [
		wet_1 * 100.0, wet_3 * 100.0, wet_5 * 100.0, WET_MIN * 100.0, WET_MAX * 100.0,
		WET_PROBE_SPAN, WET_PROBE_STRIDE
	])
	print("    rock found=%d at=(%.0f, %.0f) kind=%s walkable=%d" % [
		int(rock_found), rock_point.x, rock_point.y,
		game.world.tile_kind_at(rock_point) if rock_found else "none",
		int(game.world.is_walkable(rock_point)) if rock_found else 0
	])
	print("    reach castle=%d/%d camp=%d/%d gate=%d/%d (인접4 / 접근16)" % [
		int(castle_reach["adjacent"]), int(castle_reach["approach"]),
		int(camp_reach["adjacent"]), int(camp_reach["approach"]),
		int(gate_reach["adjacent"]), int(gate_reach["approach"])
	])
	print("    kinds river=%s bridge=%s castle=%s camp=%s gate=%s" % [
		river_kind, bridge_kind, castle_kind, camp_kind, gate_kind
	])
	print("    spawn samples=%d origin_open=%d(%.1f%% min %.0f%%) escape=%d rescue=%d" % [
		int(spawn_census["samples"]), int(spawn_census["origin_open"]),
		float(spawn_census["origin_ratio"]) * 100.0, SPAWN_ORIGIN_OPEN_MIN * 100.0,
		int(spawn_census["escape_open"]), int(spawn_census["rescue_open"])
	])
	print("WORLD_TEST_COMPLETE landmarks=%s placement=%s seeds=%s atlas=%s river_blocked=%s bridge_open=%s wfc_local=%s seams=%s streaming=%s deterministic=%s bounded=%s wet=%s rock_blocks=%s landmark_reach=%s spawn_open=%s tile_kind=%s algorithm=%s cache=%d castle_d=%d camp_d=%d gate_d=%d" % [
		landmark_ok, placement_ok, seed_ok, atlas_ok, river_blocked, bridge_open,
		generation_check.get("local_rules", false), generation_check.get("seams", false),
		streaming_rules_ok, deterministic, cache_bounded,
		wet_ok, rock_blocks_ok, landmark_reach_ok, spawn_open_ok, tile_kind_ok,
		generation_stats.get("algorithm", "unknown"), int(generation_stats.get("cached_chunks", 0)),
		int(castle_distance), int(camp_distance), int(gate_distance)
	])
	# 실측 숫자를 따로 한 줄 더 남긴다. `wet=false`만 보고는 "얼마나 벗어났는지"를
	# 알 수 없어 Y5가 실제로 두 번 헤맸다. 계약 창도 같이 찍어 둔다.
	print("    wet stage1=%.4f stage3=%.4f stage5=%.4f band=%.2f~%.2f windows=%d span=%d stride=%d" % [
		wet_1, wet_3, wet_5, WET_MIN, WET_MAX, WET_PROBE_CENTERS.size(), WET_PROBE_SPAN, WET_PROBE_STRIDE
	])
	var world_passed := landmark_ok and placement_ok and seed_ok and atlas_ok \
		and river_blocked and bridge_open \
		and bool(generation_check.get("local_rules", false)) and bool(generation_check.get("seams", false)) \
		and streaming_rules_ok and deterministic and cache_bounded \
		and wet_ok and rock_blocks_ok and landmark_reach_ok and spawn_open_ok and tile_kind_ok
	await _quit_test_cleanly(world_passed)


# =============================================================================
# Y5 지형 계약 보조 (설계 §5.1 · 리스크 3·4) — `--world-test`와 `--field-test` 공용
# =============================================================================
## 스테이지 시드 없이 월드만 세워 재는 용도. `rift_probe.gd`와 같은 수법이다.
const WORLD_GRID_SCRIPT := preload("res://scripts/world_grid.gd")

## 물 비율을 잴 창. 스폰(0,0)과 고정 물길에서 멀리 떨어진 **평범한 벌판**을 본다.
## 스폰 둘레 120px에는 dry zone이 깔려 있어 거기서 재면 물이 실제보다 적게 나온다.
##
## ⚠️ **한 창만 재면 안 된다.** Y5가 처음에 창 하나(160타일)로 쟀더니 계약이
## 실행마다 뒤집혔다 — 스테이지 시드가 매 런 난수라 창 하나에 큰 호수가 들어오고
## 나가는 것만으로 비율이 12~20% 밖으로 나갔다(`--world-test wet=false`).
## 호수 지름이 400~720px이라 6,400px 창에는 몇 개 안 들어간다.
## 그래서 **멀리 떨어진 네 창을 합산**한다. 합산이 곧 설계가 말하는 "물 비율"이고,
## 창 하나의 흔들림은 `scripts/test/terrain_probe.gd`가 300표본으로 따로 본다.
const WET_PROBE_CENTERS: Array[Vector2] = [
	Vector2(6440.0, 4720.0),
	Vector2(-7280.0, 3960.0),
	Vector2(4120.0, -8040.0),
	Vector2(-5560.0, -6280.0)
]
## 창 하나가 200타일 = 8,000px. 세 칸 걸러 훑어 창당 표본 약 4,489개, 넷이면 약 17,956개다.
## 청크 캐시는 `wfc_chunk_generator`가 72칸에서 스스로 자르고 `measure_terrain_mix()`가
## 창마다 끝에 한 번 더 자르므로 기존 `bounded` 단언을 건드리지 않는다.
const WET_PROBE_SPAN := 200
const WET_PROBE_STRIDE := 3
## 설계 §5.1이 건 계약. 이 창을 벗어나면 랜드마크·균열 배치가 위험해진다(리스크 4).
const WET_MIN := 0.12
const WET_MAX := 0.20

## 시작 자리 계측에 쓰는 고정 시드 12개. 시드를 고정해야 이 검사가 결정적이다 —
## 실제 런의 `run_cycle_seed`는 매 실행 난수라 합격 기준으로 쓸 수 없다.
const SPAWN_CENSUS_SEEDS: Array[int] = [
	20260810, 41213, 990017, 7175117, 33554393,
	60493, 1299709, 8675309, 271828183, 314159265,
	1618033, 577215664
]
## 원점이 열려 있어야 하는 최소 비율. 돌은 dry zone으로 못 막으므로 100%는 계약이
## 될 수 없다(육지 타일의 1.76%가 돌이다). "가끔 걸리는 것"과 "자주 걸리는 것"을
## 가르는 선이며, 아래 두 축(빠져나갈 길 · 구제 경로)은 100%가 계약이다.
const SPAWN_ORIGIN_OPEN_MIN := 0.85


## 지금 월드의 물 비율. `--world-test`가 스테이지마다 한 번씩 부른다.
## 창 넷을 **표본 수로 가중 합산**한다(창마다 표본 수가 같지만, 평균의 평균이 아니라
## 합산이라는 것을 코드로 못 박아 둔다 — span/stride를 나중에 창마다 다르게 줘도 옳다).
func _wet_ratio_here() -> float:
	var wet_samples := 0.0
	var total_samples := 0.0
	for center: Vector2 in WET_PROBE_CENTERS:
		var mix: Dictionary = game.world.measure_terrain_mix(center, WET_PROBE_SPAN, WET_PROBE_STRIDE)
		var samples := float(int(mix.get("samples", 0)))
		wet_samples += float(mix.get("wet", 0.0)) * samples
		total_samples += samples
	if total_samples <= 0.0:
		return 0.0
	return wet_samples / total_samples


func _wet_in_band(value: float) -> bool:
	return value >= WET_MIN and value <= WET_MAX


## 필드에서 진짜 `rocks` 타일을 하나 찾는다. 중심에서 사각 링을 넓혀 가며 찾으므로
## 가장 가까운 돌이 잡힌다. `isolated`를 켜면 **둘레 여덟 칸이 전부 걸을 수 있는**
## 단독 돌만 고른다 — 우회 검사는 옆으로 돌아갈 길이 있어야 성립하기 때문이다.
func _find_rock_tile(world: Node, center: Vector2, tile_radius: int, isolated: bool) -> Dictionary:
	var tile := float(world.TILE)
	var origin := Vector2i(floori(center.x / tile), floori(center.y / tile))
	for ring in range(1, tile_radius + 1):
		for offset_y in range(-ring, ring + 1):
			for offset_x in range(-ring, ring + 1):
				if maxi(absi(offset_x), absi(offset_y)) != ring:
					continue
				var coord := origin + Vector2i(offset_x, offset_y)
				var point := Vector2(float(coord.x) * tile + tile * 0.5, float(coord.y) * tile + tile * 0.5)
				if not world.is_rock_at(point):
					continue
				if isolated and not _rock_neighbours_open(world, point, tile):
					continue
				return {"has": true, "point": point}
	return {"has": false, "point": Vector2.ZERO}


func _rock_neighbours_open(world: Node, point: Vector2, tile: float) -> bool:
	for step_y in [-1, 0, 1]:
		for step_x in [-1, 0, 1]:
			if step_x == 0 and step_y == 0:
				continue
			if not world.is_walkable(point + Vector2(float(step_x) * tile, float(step_y) * tile)):
				return false
	return true


## 랜드마크로 걸어 들어갈 길이 있는가(리스크 3). 두 층으로 본다.
##   ① 설계가 적은 그대로 — 4방향 인접 칸(±40px = 1타일) 중 최소 하나가 보행 가능.
##   ② ①만으로는 헐겁다. 랜드마크 바닥은 `_resolved_tile_id()`가 courtyard/camp로
##      덮으므로 인접 칸은 거의 늘 통과한다. 그래서 **안전 반경 바깥 한 칸**의
##      16방향도 함께 본다 — 이쪽이 "돌·물로 완전히 막히지 않는다"의 실제 보증이다.
func _landmark_reachable(world: Node, center: Vector2, approach_radius: float) -> Dictionary:
	var tile := float(world.TILE)
	var adjacent := 0
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		if world.is_walkable(center + direction * tile):
			adjacent += 1
	var approach := 0
	for step in 16:
		var sample := center + Vector2.from_angle(TAU * float(step) / 16.0) * (approach_radius + tile)
		if world.is_walkable(sample):
			approach += 1
	return {"adjacent": adjacent, "approach": approach, "ok": adjacent >= 1 and approach >= 1}


## 시작 자리(0,0) 계측. 고정 시드 × 스테이지 1~5로 월드를 세웠다 지운다.
## 트리 밖 `WorldGrid`라 렌더도 게임 상태도 필요 없다(rift_probe와 같은 수법).
func _spawn_open_census() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260810
	var samples := 0
	var origin_open := 0
	var escape_open := 0
	var rescue_open := 0
	for stage in range(1, 6):
		for seed_value: int in SPAWN_CENSUS_SEEDS:
			var world: Node2D = WORLD_GRID_SCRIPT.new()
			world.begin_stage(stage, seed_value)
			var tile := float(world.TILE)
			samples += 1
			var origin_walkable: bool = world.is_walkable(Vector2.ZERO)
			if origin_walkable:
				origin_open += 1
			var escape := false
			for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				escape = escape or world.is_walkable(direction * tile)
			if escape:
				escape_open += 1
			# `game._walkable_spawn_point()`과 **같은 경로**로 구제해 본다.
			var rescued := Vector2.ZERO
			if not origin_walkable:
				rescued = world.find_walkable_near(Vector2.ZERO, rng, game.SPAWN_RESCUE_MIN, game.SPAWN_RESCUE_MAX)
			if world.is_walkable(rescued):
				rescue_open += 1
			world.free()
	var ratio := float(origin_open) / float(maxi(1, samples))
	return {
		"samples": samples,
		"origin_open": origin_open,
		"origin_ratio": ratio,
		"escape_open": escape_open,
		"rescue_open": rescue_open,
		"ok": ratio >= SPAWN_ORIGIN_OPEN_MIN and escape_open == samples and rescue_open == samples
	}


# =============================================================================
# --field-test (Y5 신설) — 필드 생태 **런타임** (설계 §5.2 ~ §5.5)
# =============================================================================
# `--world-test`는 **지형**을 본다(정적 계약: 물 비율 · 돌 · 랜드마크 접근성 · 타일 이름).
# 이쪽은 그 지형 **위에서 사는 몹**을 본다. 여섯 묶음 전부 "표가 맞다"가 아니라
# "실제 개체가 그렇게 산다"를 단언한다 — 데이터만 보면 맞는데 런타임 배선이 끊긴
# 회귀는 데이터 검사로는 절대 안 잡히기 때문이다(이번 라운드에 세 번 밟은 함정).
#
#   habit_wired     스폰된 개체의 `habit`이 MonsterLibrary 표와 한 마리도 빠짐없이 같고,
#                   다섯 습성이 전부 **실물 개체로** 한 번씩은 선다.
#   habit_day       낮 습성 5종이 **실제 물리 프레임에서** 서로 다르게 움직인다.
#                   (겁쟁이는 멀어지고 · 매복은 안 움직이고 · 텃세는 가까울 때만 켜지고 ·
#                    무리는 중심으로 돌아오고 · 사냥꾼은 3스테이지 낮에 먼저 본다)
#   day_aggro_zero  §5.4 "1·2스테이지 낮 선공 0". 데이터 축 + **런타임 스폰 축**.
#                   런타임 축은 양성(3스테이지 낮에는 나온다)까지 같이 본다 —
#                   음성만 있으면 "아무것도 안 스폰돼서 통과"와 구분이 안 된다.
#   terrain_spawn   지형 가중이 **실제 굴림 분포**를 바꾼다(숲=매복↑ · 풀=무리↑).
#   herd_spawn      무리가 3~5기 함께 서고 중심을 공유하며, 개체 상한을 넘지 않는다.
#   rock_detour     추적 중 돌에 막히면 옆으로 돌아간다 — **갇히지 않는다**.
#
# ⚠️ 출력에 `=false`를 절대 내지 않는다. run_all.sh가 로그에서 `=false`를 보면 그 자체로
#    FAIL로 집계하므로, 진단 수치는 전부 **숫자 키**로 찍고 불리언은 마지막 줄에만 둔다.

## 검사 무대로 쓸 "사방이 트인 자리"의 여유 반경(타일). 8타일 = 320px.
## 습성 검사는 몹이 실제로 걸어야 성립하는데, 물·돌에 코를 박으면 그 검사가
## 습성이 아니라 지형을 재는 것이 되어 버린다. 그래서 무대를 먼저 확보한다.
const FIELD_ARENA_TILES := 8
## 돌 우회 검사용 "외딴 돌"의 여유 반경(타일). 5타일 = 200px. 우회 이탈 거리
## (0.45초 × 속도 ≈ 60px)와 추적 경로가 전부 이 여유 안에 들어가야, "옆으로 돌아갔다"가
## 지형 운이 아니라 코드의 결과가 된다.
const FIELD_ROCK_CLEAR_TILES := 5
## 지형 가중 검사의 굴림 수. 2,400이면 표본오차가 1%p 안쪽이라 아래 마진이 안 흔들린다.
const FIELD_TERRAIN_ROLLS := 2400
## 숲의 매복 비율이 풀보다 **뚜렷하게** 높다고 말할 배수와 절대 격차.
## 설계값(숲 stalk ×2.2 / 풀 herd ×1.8)이면 실측이 각각 ×2.2 · ×1.7쯤 나온다 —
## 마진을 그 절반에 두어 "가중이 아예 안 물렸다"(=배수 1.0)만 확실히 잡는다.
const FIELD_TERRAIN_MIN_RATIO := 1.6
const FIELD_TERRAIN_MIN_GAP := 0.08


func _run_field_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.3).timeout
	# 난수를 못 박는다 — 스폰 분포 검사가 실행마다 흔들리면 합격 기준이 될 수 없다.
	game.rng.seed = 20260810
	game.player.invulnerability = 999999.0
	# 배경 population을 끈다. 검사가 세는 개체에 자동 스폰이 섞이면 숫자가 거짓말을 한다.
	game.combat.spawn_timer = 1.0e9
	game.is_night = false
	_v6_clear_field()
	await get_tree().process_frame

	# =========================================================================
	# ① habit_wired — 실물 개체의 습성이 데이터와 같은가
	# =========================================================================
	# 표(`MonsterLibrary.MONSTERS`)만 보면 열 종 전부 습성을 갖고 있다. 문제는
	# `enemy.setup()`이 그 값을 **실제로 읽어 넣는가**다. 그래서 전 종을 강제 스폰해
	# 살아 있는 개체의 `habit`과 표를 1:1로 대조한다. 한 마리라도 어긋나면 빨개진다.
	var wired_seen: Dictionary = {}
	var wired_checked := 0
	var wired_mismatch := 0
	for monster: Dictionary in MonsterLibrary.MONSTERS:
		var monster_id := String(monster["id"])
		var seat: Vector2 = game.player.global_position + Vector2.from_angle(
			TAU * float(wired_checked) / float(MonsterLibrary.MONSTERS.size())) * 150.0
		var born: Node2D = game.combat.spawn_enemy_instance(seat, 0, "", false, "", false, monster_id, true)
		if not is_instance_valid(born):
			wired_mismatch += 1
			continue
		wired_checked += 1
	await get_tree().process_frame
	# 살아 있는 개체 전수 대조. `active_enemies`를 도는 이유는 "내가 스폰한 것"이 아니라
	# "필드에 서 있는 것"이 검사 대상이어야 하기 때문이다.
	for enemy: Node in game.combat.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_boss:
			continue
		var expected := MonsterLibrary.habit_of(MonsterLibrary.by_id(String(enemy.kind)))
		if String(enemy.habit) != expected:
			wired_mismatch += 1
		wired_seen[String(enemy.habit)] = true
	var wired_habits := 0
	for habit_id: String in MonsterLibrary.HABITS:
		if wired_seen.has(habit_id):
			wired_habits += 1
	var habit_wired_ok: bool = wired_mismatch == 0 \
		and wired_checked == MonsterLibrary.MONSTERS.size() \
		and wired_habits == MonsterLibrary.HABITS.size()
	_v6_clear_field()
	await get_tree().process_frame

	# =========================================================================
	# ② herd_spawn — 무리가 함께 서는가 · 상한을 넘지 않는가 (스테이지 1 낮)
	# =========================================================================
	# 1스테이지 낮 풀은 무리(이끼콩 · 뿔임프)가 과반이다. 무리가 뽑힐 때까지 굴려
	# **무리가 뽑힌 그 한 번**을 검사한다(거절 표집 — 무리 습성만 나오는 조건을 만든 것).
	var herd_stood := 0
	var herd_wanted := 0
	var herd_spread := 0.0
	var herd_center_shared := true
	for attempt in 40:
		_v6_clear_field()
		game.combat.last_herd_stood = 0
		game.combat.last_herd_wanted = 0
		game.combat.maintain_field_population()
		if game.combat.last_herd_stood >= MonsterLibrary.HABIT_HERD_SPAWN_MIN:
			break
	herd_stood = int(game.combat.last_herd_stood)
	herd_wanted = int(game.combat.last_herd_wanted)
	var herd_members: Array[Node] = []
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy):
			herd_members.append(enemy)
	if herd_members.is_empty():
		herd_center_shared = false
	else:
		var anchor_center: Vector2 = herd_members[0].herd_center
		for enemy: Node in herd_members:
			# 중심이 갈리면 무리가 아니다 — 각자 태어난 자리로 흩어진다는 뜻이다.
			if not Vector2(enemy.herd_center).is_equal_approx(anchor_center):
				herd_center_shared = false
			herd_spread = maxf(herd_spread, enemy.global_position.distance_to(anchor_center))
	var herd_group_ok: bool = herd_center_shared \
		and herd_stood >= MonsterLibrary.HABIT_HERD_SPAWN_MIN \
		and herd_stood <= MonsterLibrary.HABIT_HERD_SPAWN_MAX \
		and herd_members.size() == herd_stood \
		and herd_spread <= MonsterLibrary.HABIT_HERD_SPAWN_RADIUS + 1.0

	# --- 개체 상한: 문턱 바로 아래에서 무리를 굴린다 ---------------------------
	# 무리는 한 번에 여럿을 세우므로 상한을 **뛰어넘을** 수 있는 유일한 경로다.
	# 체류를 포화(dwell 8)시켜 물량을 최대로 올린 뒤 상한 −1에서 굴린다.
	game.clock.set_dwell_raw(GameTuning.DWELL_COUNT_SATURATION)
	var herd_limit: int = game.combat.current_enemy_limit()
	var herd_peak := 0
	var herd_groups := 0
	for attempt in 40:
		_field_resize_enemies(maxi(0, herd_limit - 1))
		game.combat.last_herd_stood = 0
		game.combat.maintain_field_population()
		herd_peak = maxi(herd_peak, game.combat.active_enemies.size())
		if game.combat.last_herd_stood > 0:
			herd_groups += 1
			if herd_groups >= 6:
				break
	# `herd_groups > 0`이 없으면 "무리가 한 번도 안 나와서 상한을 안 넘었다"가 통과한다.
	var herd_cap_ok: bool = herd_peak <= GameTuning.MAX_ENEMIES \
		and herd_peak <= herd_limit and herd_groups > 0
	var herd_spawn_ok: bool = herd_group_ok and herd_cap_ok
	game.clock.set_dwell_raw(0)
	_v6_clear_field()
	await get_tree().process_frame

	# =========================================================================
	# ③ day_aggro_zero — 1·2스테이지 낮 선공 0 (피드백 ⑥ · §5.4)
	# =========================================================================
	# 데이터 축부터. 게이트 함수 하나가 판단의 전부이므로 네 모서리를 못 박는다.
	var gate_ok: bool = not MonsterLibrary.stage_aggro_gate_ok(1, false) \
		and not MonsterLibrary.stage_aggro_gate_ok(2, false) \
		and MonsterLibrary.stage_aggro_gate_ok(3, false) \
		and MonsterLibrary.stage_aggro_gate_ok(1, true)

	# 런타임 축(핵심). 실제 필드 population을 수십 번 굴려 **선공몹(behavior 4)이
	# 몇 마리 섰는가**를 센다. 게이트가 데이터에만 있고 스폰 경로가 안 보면 여기서 걸린다.
	game.clock.set_stage_raw(2)
	game._rebuild_stage_world(2)
	game.is_night = false
	await get_tree().process_frame
	var stage2_census := _field_spawn_census(60)
	game.clock.set_stage_raw(3)
	game._rebuild_stage_world(3)
	game.is_night = false
	await get_tree().process_frame
	var stage3_census := _field_spawn_census(60)
	var day_aggro_zero_ok: bool = gate_ok \
		and int(stage2_census["aggro"]) == 0 and int(stage2_census["spawned"]) > 0 \
		and int(stage3_census["aggro"]) > 0
	_v6_clear_field()
	await get_tree().process_frame

	# =========================================================================
	# ④ terrain_spawn — 지형 가중이 실제 굴림을 바꾸는가 (§5.3)
	# =========================================================================
	# 같은 스테이지·시간대에서 타일 이름만 바꿔 수천 번 굴린다. 배선이 끊기면 두 분포가
	# **똑같아지므로**, 비율 자체가 아니라 두 지형의 **격차**를 단언한다.
	var forest_mix := _field_terrain_mix("forest", FIELD_TERRAIN_ROLLS)
	var grass_mix := _field_terrain_mix("grass", FIELD_TERRAIN_ROLLS)
	var forest_stalk := float(forest_mix.get("stalk", 0.0))
	var grass_stalk := float(grass_mix.get("stalk", 0.0))
	var forest_herd := float(forest_mix.get("herd", 0.0))
	var grass_herd := float(grass_mix.get("herd", 0.0))
	var terrain_spawn_ok: bool = forest_stalk >= grass_stalk * FIELD_TERRAIN_MIN_RATIO \
		and forest_stalk - grass_stalk >= FIELD_TERRAIN_MIN_GAP \
		and grass_herd >= forest_herd * 1.3 \
		and grass_herd - forest_herd >= FIELD_TERRAIN_MIN_GAP

	# =========================================================================
	# ⑤ habit_day — 낮 습성 5종이 실제로 갈리는가 (§5.2)
	# =========================================================================
	# 무대를 먼저 잡는다. 여기부터는 전부 **물리 프레임을 실제로 돌린다** —
	# 상태 변수만 읽으면 "aggro 플래그는 맞는데 발이 안 움직이는" 회귀를 놓친다.
	var arena := _field_open_arena(game.player.global_position, FIELD_ARENA_TILES)
	var arena_ok: bool = bool(arena.get("has", false))
	var stand: Vector2 = arena.get("point", game.player.global_position)
	game.player.global_position = stand

	# --- shy(푸른 위습): 260px 안에서 aggro 0 · 도망 타이머 살아 있음 · 실제로 멀어진다 ---
	# **일부러 provoke() 한다.** 겁쟁이의 정의는 "맞아도 낮에는 도망간다"이므로,
	# 켜진 aggro를 습성 층이 매 프레임 도로 끄는지가 이 묶음의 진짜 검사 항목이다.
	var wisp: Node2D = _field_plant("wisp", stand + Vector2(90.0, 0.0))
	var shy_ok := false
	var shy_gain := 0.0
	var shy_flee_peak := 0.0
	var shy_aggro_frames := 0
	if is_instance_valid(wisp):
		wisp.provoke()
		# `physics_frame` 시그널은 노드의 `_physics_process`보다 **먼저** 울린다.
		# 한 프레임 흘려보내야 "습성 층이 provoke()가 켠 aggro를 지운 뒤"를 보게 된다 —
		# 안 그러면 방금 내가 켠 그 값을 그대로 읽고 스스로에게 속는다.
		await get_tree().physics_frame
		await get_tree().physics_frame
		var shy_start: float = wisp.global_position.distance_to(game.player.global_position)
		for step in 66:
			await get_tree().physics_frame
			if not is_instance_valid(wisp):
				break
			shy_flee_peak = maxf(shy_flee_peak, float(wisp.flee_timer))
			if bool(wisp.aggro):
				shy_aggro_frames += 1
		if is_instance_valid(wisp):
			shy_gain = wisp.global_position.distance_to(game.player.global_position) - shy_start
			shy_ok = not bool(wisp.aggro) and shy_aggro_frames == 0 \
				and shy_flee_peak > 0.0 and shy_gain >= 40.0
	_v6_clear_field()
	await get_tree().process_frame

	# --- stalk(굶주린 그림자): 사거리 밖에서는 서 있고, 안에 들어오면 급습 ---
	var shade: Node2D = _field_plant("shade", stand + Vector2(0.0, -300.0))
	var stalk_ok := false
	var stalk_drift := 0.0
	var stalk_aggro_far := 0
	if is_instance_valid(shade):
		var stalk_start: Vector2 = shade.global_position
		for step in 48:
			await get_tree().physics_frame
			if not is_instance_valid(shade) or bool(shade.aggro):
				stalk_aggro_far += 1
				break
		if is_instance_valid(shade):
			stalk_drift = stalk_start.distance_to(shade.global_position)
			# 사거리(210px) 안으로 플레이어를 옮기면 그 순간 급습으로 전환돼야 한다.
			game.player.global_position = shade.global_position + Vector2(0.0, 120.0)
			for step in 8:
				await get_tree().physics_frame
			stalk_ok = stalk_aggro_far == 0 and stalk_drift <= 4.0 and bool(shade.aggro)
	game.player.global_position = stand
	_v6_clear_field()
	await get_tree().process_frame

	# --- guard(들멧돼지): 멀면 안 켜지고, 자기 자리를 침범당하면 켜진다 ---
	var boar: Node2D = _field_plant("boar", stand + Vector2(300.0, 0.0))
	var guard_ok := false
	var guard_far_frames := 0
	if is_instance_valid(boar):
		for step in 36:
			await get_tree().physics_frame
			if not is_instance_valid(boar):
				break
			if bool(boar.aggro):
				guard_far_frames += 1
		if is_instance_valid(boar):
			game.player.global_position = boar.global_position + Vector2(0.0, 100.0)
			for step in 8:
				await get_tree().physics_frame
			guard_ok = guard_far_frames == 0 and bool(boar.aggro)
	game.player.global_position = stand
	_v6_clear_field()
	await get_tree().process_frame

	# --- herd(이끼콩): 무리 중심이 곧 귀소점이고, 실제로 그쪽으로 걸어 돌아온다 ---
	# `home_position == herd_center`만 보면 `set_herd_center()`가 두 값을 같이 넣으므로
	# 공허한 단언이 된다. 그래서 **중심에서 멀리 떨어뜨려 놓고 돌아오는지**까지 본다.
	var mossling: Node2D = _field_plant("mossling", stand + Vector2(320.0, 0.0))
	var herd_home_ok := false
	var herd_return := 0.0
	if is_instance_valid(mossling):
		mossling.set_herd_center(stand)
		var herd_start: float = mossling.global_position.distance_to(stand)
		for step in 96:
			await get_tree().physics_frame
			if not is_instance_valid(mossling):
				break
		if is_instance_valid(mossling):
			herd_return = herd_start - mossling.global_position.distance_to(stand)
			herd_home_ok = Vector2(mossling.home_position).is_equal_approx(Vector2(mossling.herd_center)) \
				and herd_return >= 15.0
	_v6_clear_field()
	await get_tree().process_frame

	# --- hunt(붉은 늑대): 3스테이지 낮 310px에서 먼저 본다 / 2스테이지 낮에는 안 본다 ---
	# 음성 축(2스테이지)을 같이 두는 이유는 §5.4의 게이트가 **런타임에서** 물리는지를
	# 보기 위해서다. 양성만 보면 "늑대는 늘 덤빈다"도 통과한다.
	var wolf: Node2D = _field_plant("wolf", stand + Vector2(0.0, 300.0))
	var hunt_ok := false
	var hunt_day3 := 0
	var hunt_day2 := 0
	if is_instance_valid(wolf):
		for step in 8:
			await get_tree().physics_frame
		hunt_day3 = 1 if bool(wolf.aggro) else 0
		# 스테이지만 2로 낮춘다(월드는 그대로 — aggro 판정은 clock.stage만 읽는다).
		game.clock.set_stage_raw(2)
		wolf.global_position = stand + Vector2(0.0, 300.0)
		wolf.aggro = true                     # 켜 놓고 시작해야 게이트가 **끄는지**를 본다
		for step in 8:
			await get_tree().physics_frame
		hunt_day2 = 1 if bool(wolf.aggro) else 0
		game.clock.set_stage_raw(3)
		hunt_ok = hunt_day3 == 1 and hunt_day2 == 0
	var habit_day_ok: bool = arena_ok and shy_ok and stalk_ok and guard_ok and herd_home_ok and hunt_ok
	_v6_clear_field()
	await get_tree().process_frame

	# =========================================================================
	# ⑥ rock_detour — 추적 중 돌 우회 (§5.1 리스크 ③)
	# =========================================================================
	# 자리·각도를 손으로 심는다(rng 금지). 돌 왼쪽에 몹, 오른쪽에 플레이어를 두면
	# 직선 추적 경로가 **반드시** 돌을 지나므로 우회 코드가 걸릴 수밖에 없다.
	# 단언은 세 가지뿐이다 — 돌 위에 있지 않다 / 갇히지 않았다 / 우회가 한 번이라도 걸렸다.
	# **우회 횟수는 단언하지 않는다**: 속도·프레임 위상에 따라 실행마다 흔들린다.
	var lone_rock := _field_lone_rock(game.player.global_position, 60, FIELD_ROCK_CLEAR_TILES)
	var rock_found: bool = bool(lone_rock.get("has", false))
	var rock_point: Vector2 = lone_rock.get("point", Vector2.ZERO)
	var detour_frames := 0
	var detour_on_rock := 0
	var detour_moved := 0.0
	var detour_ok := false
	if rock_found:
		game.player.global_position = rock_point + Vector2(180.0, 0.0)
		var chaser: Node2D = _field_plant("wolf", rock_point + Vector2(-52.0, 0.0))
		if is_instance_valid(chaser):
			chaser.aggro = true
			chaser.aggro_lost_timer = 99.0
			var chase_start: Vector2 = chaser.global_position
			for step in 200:
				await get_tree().physics_frame
				if not is_instance_valid(chaser):
					break
				# **매 프레임 본다.** 우회는 0.45초짜리라 끝나고 나서 보면 이미 0이다.
				if float(chaser.detour_timer) > 0.0:
					detour_frames += 1
				if game.world.is_rock_at(chaser.global_position):
					detour_on_rock += 1
			if is_instance_valid(chaser):
				detour_moved = chase_start.distance_to(chaser.global_position)
				detour_ok = detour_frames >= 1 and detour_on_rock == 0 and detour_moved >= 40.0
	var rock_detour_ok: bool = rock_found and detour_ok

	# ---------------------------------------------------------------- 진단 출력
	# 전부 숫자 키다(불리언 금지 — `=false` 한 글자가 run_all.sh를 FAIL로 만든다).
	print("    wired species=%d checked=%d mismatch=%d habits=%d/%d" % [
		MonsterLibrary.MONSTERS.size(), wired_checked, wired_mismatch,
		wired_habits, MonsterLibrary.HABITS.size()
	])
	print("    day shy_gain=%.0fpx shy_flee=%.2f shy_aggro_frames=%d stalk_drift=%.1fpx stalk_far_aggro=%d guard_far_aggro=%d herd_return=%.0fpx hunt_s3=%d hunt_s2=%d arena=(%.0f, %.0f)" % [
		shy_gain, shy_flee_peak, shy_aggro_frames, stalk_drift, stalk_aggro_far,
		guard_far_frames, herd_return, hunt_day3, hunt_day2, stand.x, stand.y
	])
	print("    aggro s2_spawned=%d s2_behavior4=%d s3_spawned=%d s3_behavior4=%d gate=[%d %d %d %d]" % [
		int(stage2_census["spawned"]), int(stage2_census["aggro"]),
		int(stage3_census["spawned"]), int(stage3_census["aggro"]),
		int(MonsterLibrary.stage_aggro_gate_ok(1, false)), int(MonsterLibrary.stage_aggro_gate_ok(2, false)),
		int(MonsterLibrary.stage_aggro_gate_ok(3, false)), int(MonsterLibrary.stage_aggro_gate_ok(1, true))
	])
	print("    terrain rolls=%d forest_stalk=%.1f%% grass_stalk=%.1f%% grass_herd=%.1f%% forest_herd=%.1f%% (min ×%.2f · +%.0f%%p)" % [
		FIELD_TERRAIN_ROLLS, forest_stalk * 100.0, grass_stalk * 100.0,
		grass_herd * 100.0, forest_herd * 100.0,
		FIELD_TERRAIN_MIN_RATIO, FIELD_TERRAIN_MIN_GAP * 100.0
	])
	print("    herd stood=%d wanted=%d spread=%.0fpx(max %.0f) limit=%d peak=%d groups=%d cap=%d" % [
		herd_stood, herd_wanted, herd_spread, MonsterLibrary.HABIT_HERD_SPAWN_RADIUS,
		herd_limit, herd_peak, herd_groups, GameTuning.MAX_ENEMIES
	])
	print("    detour rock=(%.0f, %.0f) found=%d detour_frames=%d on_rock=%d moved=%.0fpx" % [
		rock_point.x, rock_point.y, int(rock_found), detour_frames, detour_on_rock, detour_moved
	])
	print("FIELD_TEST_COMPLETE habit_wired=%s habit_day=%s day_aggro_zero=%s terrain_spawn=%s herd_spawn=%s rock_detour=%s" % [
		habit_wired_ok, habit_day_ok, day_aggro_zero_ok, terrain_spawn_ok, herd_spawn_ok, rock_detour_ok
	])
	var field_passed: bool = habit_wired_ok and habit_day_ok and day_aggro_zero_ok \
		and terrain_spawn_ok and herd_spawn_ok and rock_detour_ok
	await _quit_test_cleanly(field_passed)


# ----------------------------------------------------------------- --field-test 보조

## 좌표를 손으로 심는 검사용 개체. `_v6_dummy`와 달리 **체력을 안 건드리고**
## 종을 이름으로 지정한다 — 습성은 종에 붙어 있으므로 종을 고정해야 검사가 성립한다.
## `allow_aggro_override=true`는 스폰 게이트를 건너뛰려는 것이지 aggro를 켜는 것이 아니다
## (2스테이지 낮에 늑대를 **세우되** 그 늑대가 덤비지 않는지를 봐야 하기 때문).
func _field_plant(monster_id: String, at: Vector2) -> Node2D:
	var born: Node2D = game.combat.spawn_enemy_instance(at, 0, "", false, "", false, monster_id, true)
	if not is_instance_valid(born):
		return null
	born.global_position = at
	born.home_position = at
	born.herd_center = at
	born.aggro = false
	born.raid_mode = false
	born.flee_timer = 0.0
	born.detour_timer = 0.0
	game.combat.rebuild_enemy_spatial()
	return born


## `active_enemies`를 정확히 `count`기로 맞춘다(모자라면 이끼콩을 세우고 넘치면 걷는다).
## 무리 상한 검사가 "상한 문턱 바로 아래"를 매번 다시 만들어야 해서 필요하다.
func _field_resize_enemies(count: int) -> void:
	while game.combat.active_enemies.size() > count:
		var extra: Node = game.combat.active_enemies.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	var guard := 0
	while game.combat.active_enemies.size() < count and guard < 400:
		guard += 1
		var filler: Node2D = game.combat.spawn_enemy_instance(
			game.player.global_position + Vector2(float(guard % 17) * 6.0, float(guard % 11) * 6.0),
			1, "", false, "", false, "mossling")
		if not is_instance_valid(filler):
			break


## 필드 population을 `rounds`번 굴려 스폰된 개체의 행동 유형을 센다.
## 굴림마다 필드를 비우는 이유는 상한에 닿으면 `maintain_field_population()`이
## 즉시 반환해 그 뒤 굴림이 전부 공회전하기 때문이다.
func _field_spawn_census(rounds: int) -> Dictionary:
	var spawned := 0
	var aggro_kind := 0
	for round_index in rounds:
		_v6_clear_field()
		game.combat.maintain_field_population()
		for enemy: Node in game.combat.active_enemies:
			if not is_instance_valid(enemy):
				continue
			spawned += 1
			if int(enemy.behavior_type) == MonsterLibrary.AGGRO_BEHAVIOR:
				aggro_kind += 1
	_v6_clear_field()
	return {"spawned": spawned, "aggro": aggro_kind}


## 한 타일 이름 위에서 `rolls`번 굴려 습성 구성비를 낸다(0~1).
func _field_terrain_mix(tile_kind: String, rolls: int) -> Dictionary:
	var tally: Dictionary = {}
	for habit_id: String in MonsterLibrary.HABITS:
		tally[habit_id] = 0
	for index in rolls:
		var archetype := game.combat.roll_archetype_for_terrain(tile_kind)
		var habit_id := MonsterLibrary.habit_of(archetype)
		tally[habit_id] = int(tally.get(habit_id, 0)) + 1
	var mix: Dictionary = {}
	for habit_id: String in MonsterLibrary.HABITS:
		mix[habit_id] = float(int(tally[habit_id])) / float(maxi(1, rolls))
	return mix


## 사방이 트인 검사 무대를 찾는다. 후보는 4타일(160px)씩 건너뛰며 나선으로 훑고,
## 후보마다 반경 `tile_radius`의 격자를 **한 칸도 빠뜨리지 않고** 확인한다
## (건너뛰며 확인하면 칸 사이에 돌이 숨어 무대 한복판에서 몹이 코를 박는다).
func _field_open_arena(hint: Vector2, tile_radius: int) -> Dictionary:
	var tile := float(game.world.TILE)
	for ring in range(0, 30):
		for offset_y in range(-ring, ring + 1):
			for offset_x in range(-ring, ring + 1):
				if maxi(absi(offset_x), absi(offset_y)) != ring:
					continue
				var candidate := hint + Vector2(float(offset_x), float(offset_y)) * tile * 4.0
				if _field_area_open(candidate, tile_radius):
					return {"has": true, "point": candidate}
	return {"has": false, "point": hint}


func _field_area_open(center: Vector2, tile_radius: int) -> bool:
	var tile := float(game.world.TILE)
	for offset_y in range(-tile_radius, tile_radius + 1):
		for offset_x in range(-tile_radius, tile_radius + 1):
			if not game.world.is_walkable(center + Vector2(float(offset_x), float(offset_y)) * tile):
				return false
	return true


## 우회 검사용 **외딴 돌**. 반경 `clear_tiles` 안에서 못 걷는 칸이 그 돌 하나뿐인
## 자리를 찾는다. 이 여유가 없으면 "옆으로 돌아갔다"가 아니라 "옆에도 물이 있었다"가 된다.
func _field_lone_rock(hint: Vector2, search_tiles: int, clear_tiles: int) -> Dictionary:
	var tile := float(game.world.TILE)
	var origin := Vector2i(floori(hint.x / tile), floori(hint.y / tile))
	for ring in range(1, search_tiles + 1):
		for offset_y in range(-ring, ring + 1):
			for offset_x in range(-ring, ring + 1):
				if maxi(absi(offset_x), absi(offset_y)) != ring:
					continue
				var coord := origin + Vector2i(offset_x, offset_y)
				var point := Vector2(float(coord.x) * tile + tile * 0.5, float(coord.y) * tile + tile * 0.5)
				if not game.world.is_rock_at(point):
					continue
				if _field_rock_isolated(point, clear_tiles):
					return {"has": true, "point": point}
	return {"has": false, "point": Vector2.ZERO}


func _field_rock_isolated(point: Vector2, clear_tiles: int) -> bool:
	var tile := float(game.world.TILE)
	for offset_y in range(-clear_tiles, clear_tiles + 1):
		for offset_x in range(-clear_tiles, clear_tiles + 1):
			if offset_x == 0 and offset_y == 0:
				continue
			if not game.world.is_walkable(point + Vector2(float(offset_x), float(offset_y)) * tile):
				return false
	return true


func _run_v4_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.25).timeout
	var rarity_counts := ItemLibrary.rarity_counts()
	var item_catalog_ok := ItemLibrary.ITEMS.size() == 57 and int(rarity_counts["common"]) == 21 and int(rarity_counts["rare"]) == 15 and int(rarity_counts["unique"]) == 12 and int(rarity_counts["hero"]) == 9
	var skill_variety_ok := DealCardLibrary.SKILLS.size() >= 28
	var combat_profiles_ok := true
	for definition: Dictionary in DealCardLibrary.all_with_specials():
		skill_variety_ok = skill_variety_ok and float(definition.get("duration", 0.0)) >= 0.8
		var deals_damage := float(definition.get("damage", 0.0)) > 0.0
		combat_profiles_ok = combat_profiles_ok and (not deals_damage or float(definition.get("range", 0.0)) > 0.0)
		var reaction := DealCardLibrary.knockback_profile(definition)
		combat_profiles_ok = combat_profiles_ok and (not deals_damage or float(reaction.get("stun", 0.0)) > 0.0)
	# ---- v2 공장 형태: 5칸 고정 · 각인 0 · 빈칸은 기본 베기 (구 initial = 3칸→10칸) ----
	var initial_shape_ok := game.factory.slots.size() == FactoryDeck.SLOT_COUNT \
		and game.factory.total_rune_count() == 0 \
		and String(game.factory.compile_slot(0).get("id", "")) == "basic"
	for probe_slot in game.factory.slots.size():
		initial_shape_ok = initial_shape_ok and game.factory.get_card(probe_slot).is_empty()
	# ---- 아이템은 칸을 점유하지 않고 장비로 간다 (구 item_separate) ----
	var equip_deck: FactoryDeck = game.FACTORY_SCRIPT.new()
	equip_deck.reset()
	var equip_raw_reload := equip_deck.raw_total_reload()
	equip_deck.place_card(1, ItemLibrary.instance("u_rapier_01"))
	var item_equip_ok := equip_deck.equipment.size() == 1 \
		and equip_deck.get_card(1).is_empty() \
		and String(equip_deck.compile_slot(1).get("card_kind", "")) == "skill" \
		and equip_deck.total_reload() < equip_raw_reload
	# ---- 칸 교환은 각인을 데려가고, 카드 이동은 각인을 두고 간다 (구 construction14 / split3) ----
	var swap_deck: FactoryDeck = game.FACTORY_SCRIPT.new()
	swap_deck.reset()
	swap_deck.place_card(0, DealCardLibrary.instance("cleave", 1))
	# Y2: 구 id `rewind_1` → 신 id `back_one`(§2.1). 폐기 id를 넘기면 `roll_rune`이 `{}`를
	# 돌려주고 부착이 조용히 실패해 **각인 0개로 통과**한다(handoff-y1 §10-2).
	var slot_swap_ok: bool = swap_deck.attach_rune(0, RuneEngine.roll_rune("back_one", game.rng))
	slot_swap_ok = slot_swap_ok and swap_deck.swap_slots(0, 4)
	slot_swap_ok = slot_swap_ok and swap_deck.rune_count_on(4) == 1 and swap_deck.rune_count_on(0) == 0
	slot_swap_ok = slot_swap_ok and String(swap_deck.get_card(4).get("id", "")) == "cleave"
	slot_swap_ok = slot_swap_ok and swap_deck.move_card(4, 2)
	slot_swap_ok = slot_swap_ok and String(swap_deck.get_card(2).get("id", "")) == "cleave" \
		and swap_deck.rune_count_on(4) == 1 and swap_deck.rune_count_on(2) == 0
	# ---- 한 칸 각인 스택 상한 (부록 C-1 감쇠 설계의 하드 캡) ----
	var stack_deck: FactoryDeck = game.FACTORY_SCRIPT.new()
	stack_deck.reset()
	var same_id_accepted := 0
	for _copy in RuneEngine.SAME_ID_STACK_CAP + 2:
		if stack_deck.attach_rune(0, RuneEngine.roll_rune("back_one", game.rng)):
			same_id_accepted += 1
	var total_accepted := same_id_accepted
	for _extra in RuneEngine.RUNE_STACK_CAP:
		if stack_deck.attach_rune(0, RuneEngine.roll_rune("strong", game.rng)):
			total_accepted += 1
	var rune_stack_ok := same_id_accepted == RuneEngine.SAME_ID_STACK_CAP \
		and total_accepted == RuneEngine.RUNE_STACK_CAP \
		and stack_deck.rune_count_on(0) == RuneEngine.RUNE_STACK_CAP
	# Y2: 레일 각인은 **칸에 붙지 않는다**(§2.2). `attach_rune`이 거부하고 레일 쪽
	# 접근자만 받는다 — 이 두 줄이 칸/레일 분기의 데이터 계약이다.
	rune_stack_ok = rune_stack_ok and not stack_deck.attach_rune(1, RuneEngine.roll_rune("rail_fast", game.rng)) \
		and stack_deck.rune_count_on(1) == 0 \
		and stack_deck.attach_rail_rune(RuneEngine.roll_rune("rail_fast", game.rng)) \
		and stack_deck.rail_rune_count() == 1 \
		and not stack_deck.attach_rail_rune(RuneEngine.roll_rune("rail_fast", game.rng))
	var fusion_deck: FactoryDeck = game.FACTORY_SCRIPT.new()
	fusion_deck.reset()
	fusion_deck.add_inventory(DealCardLibrary.instance("cleave", 1))
	fusion_deck.add_inventory(DealCardLibrary.instance("cleave", 1))
	var fusion_ok := fusion_deck.fuse("cleave", 1) and fusion_deck.get_rank_count("cleave", 2) == 1

	# V5: 성은 스테이지 시드가 자리를 정한다(고정 좌표 (250,-250) 폐기).
	game.player.global_position = game.world.get_castle_position()
	game._refresh_interactable()
	var physical_e := InputEventKey.new()
	physical_e.physical_keycode = KEY_E
	physical_e.pressed = true
	# W5: 필드에서는 5칸 레일이 켜져 있고, 성 안에서는 꺼져야 한다.
	game._update_cycle_rail(0.016)
	var rail_on_field := game.rail_band.visible
	game._unhandled_input(physical_e)
	# W9: 성 NPC가 6종 중 4개 추첨 → **v2 4종 고정**으로 바뀌었다.
	# 구 단언은 `card_fusion`(폐기 · 각인 세공사로 통합)을 봤다.
	var castle_input_ok := game.state == "castle_interior" and game.inside_castle and is_instance_valid(game.castle_interior) and game.castle_interior.services.has("rune_shop") and game.castle_interior.npcs.size() == 4
	castle_input_ok = castle_input_ok and rail_on_field and not game.rail_band.visible
	if game.inside_castle:
		game._exit_castle()
	game._update_cycle_rail(0.016)
	castle_input_ok = castle_input_ok and game.rail_band.visible

	game.factory.place_card(0, DealCardLibrary.instance("cleave", 1))
	game._reset_player_cycle()
	game.player.set_facing_direction(Vector2.RIGHT, true)
	await get_tree().create_timer(0.12).timeout
	var live_effect: CycleSkillEffect
	for node: Node in game.gameplay_root.get_children():
		if node is CycleSkillEffect and not (node as CycleSkillEffect).boss_mode:
			live_effect = node as CycleSkillEffect
			break
	var direction_before := Vector2.ZERO if not is_instance_valid(live_effect) else live_effect._current_facing()
	var turn_target := game.combat.spawn_enemy_instance(game.player.global_position + Vector2(0.0, -92.0), 2, "", false, "", false, "wild_boar")
	var turn_target_health: float = float(turn_target.health) if is_instance_valid(turn_target) else 0.0
	game.player.set_facing_direction(Vector2.UP, true)
	await get_tree().create_timer(0.12).timeout
	var direction_after := Vector2.ZERO if not is_instance_valid(live_effect) else live_effect._current_facing()
	var turned_target_hit: bool = not is_instance_valid(turn_target) or float(turn_target.health) < turn_target_health
	var live_direction_ok: bool = direction_before.is_equal_approx(Vector2.RIGHT) and direction_after.is_equal_approx(Vector2.UP) and turned_target_hit
	game._show_skill_choice("test")
	# X1: 3번째 선택지가 「각인 강화」 카드 → **취소 버튼**으로 바뀌었다. 역할 문자열은
	# 그대로 "cancel"이라 단일 포커스 모델(↓/↑) 검사는 한 줄도 바뀌지 않는다.
	# 카드 meta도 `owned_text`(문장) → `owned_count`(정수)로 갈렸다 — 카드가 이제
	# "3장 보유중"이 아니라 "3장" 칩 하나만 그리기 때문이다.
	var choice_ui_ok := game.state == "choice" and game.choice_buttons.size() == 3 \
		and String(game.choice_buttons[0].get_meta("choice_role", "")) == "skill" \
		and game.choice_buttons[0].has_meta("owned_count") \
		and game.choice_buttons[0].has_meta("card_element") \
		and String(game.choice_buttons[2].get_meta("choice_role", "")) == "cancel" \
		and String(game.choice_buttons[2].get_meta("choice_kind", "")) == "cancel"
	# 단일 포커스 모델 검사: 방향키가 항상 지정된 한 칸으로 직행하고 강조는 항상 1개만 남는다.
	# Godot 내장 Control 포커스 이동이 두 번째 선택자로 끼어들지 않도록 focus_mode도 함께 확인한다.
	var single_focus_ok := game._choice_highlight_count() == 1 and game.choice_selected_index == 0
	for choice_button: Button in game.choice_buttons:
		single_focus_ok = single_focus_ok and choice_button.focus_mode == Control.FOCUS_NONE
	for probe: Array in [[KEY_RIGHT, 1], [KEY_DOWN, 2], [KEY_LEFT, 0], [KEY_UP, 0], [KEY_D, 1], [KEY_S, 2], [KEY_W, 1]]:
		var probe_event := InputEventKey.new()
		probe_event.keycode = int(probe[0])
		probe_event.pressed = true
		game._unhandled_input(probe_event)
		single_focus_ok = single_focus_ok and game.choice_selected_index == int(probe[1]) and game._choice_highlight_count() == 1
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"
	game._show_factory_menu("place", DealCardLibrary.instance("time_cut", 1), "playing")
	game._factory_lane_pressed(1, 0)
	var immediate_place_ok := game.state == "playing" and String(game.factory.get_card(1).get("id", "")) == "time_cut"
	var before_drag_left := game.factory.get_card(0)
	var before_drag_right := game.factory.get_card(1)
	game._show_factory_menu("edit", {}, "playing")
	game._on_factory_card_dropped({"zone":"rail", "slot":0, "lane":0, "has_card":true}, {"zone":"rail", "slot":1, "lane":0, "has_card":true})
	# v2: 레일↔레일 드래그는 gesture 없이 오면 [카드 이동]이라 각인은 칸에 남는다(부록 C-1).
	var drag_swap_ok := String(game.factory.get_card(0).get("id", "")) == String(before_drag_right.get("id", "")) and String(game.factory.get_card(1).get("id", "")) == String(before_drag_left.get("id", ""))
	# --- W6 편집 화면 v2: 무스크롤 5칸 + 두 조작이 서로 다른 API를 부르는가 -----------
	# ⚠️ Y3이 음성 대조로 잡은 구멍: **각인이 하나도 없으면** 아래 ⓔ(툴팁 줄 수 ≥ 각인 수)와
	#    ⓖ(글리프 개수 == 각인 수) 두 단언이 `0 >= 0` / `0 == 0`으로 **공허하게 통과한다.**
	#    실제로 글리프를 통째로 지워도 v4-test가 초록이었다. 칸마다 심어 두고 잰다.
	#    슬롯 3은 4개(= 과밀 1)라 `+N` 초과 표기 경로까지 같이 밟는다.
	for seed_slot in FactoryDeck.SLOT_COUNT:
		while game.factory.rune_count_on(seed_slot) > 0:
			game.factory.detach_rune(seed_slot, 0)
	game.factory.attach_rune(0, RuneEngine.roll_rune("twice", game.rng))
	game.factory.attach_rune(0, RuneEngine.roll_rune("strong", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("quick", game.rng))
	game.factory.attach_rune(3, RuneEngine.roll_rune("finisher", game.rng))
	game.factory.attach_rune(3, RuneEngine.roll_rune("wide", game.rng))
	game.factory.attach_rune(3, RuneEngine.roll_rune("jump_one", game.rng))
	game.factory.attach_rune(3, RuneEngine.roll_rune("first_hit", game.rng))
	game.factory.rail_runes.clear()
	game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_power", game.rng))
	game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_loop", game.rng))
	game._show_factory_menu("edit", {}, "playing")
	var editor_panel := game.overlay.get_node_or_null("EditorPanel")
	var edit_layout_ok := is_instance_valid(editor_panel) and game.factory_lane_buttons.size() == FactoryDeck.SLOT_COUNT
	# ① 5칸이 패널 안에 전부 들어온다 = 가로 스크롤이 구조적으로 불가능하다.
	var content_right := game.EDIT_RAIL_ORIGIN.x + game.EDIT_RAIL_CONTENT_W
	edit_layout_ok = edit_layout_ok and content_right <= game.EDIT_PANEL_RECT.size.x
	for probe_slot in FactoryDeck.SLOT_COUNT:
		var cell := editor_panel.get_node_or_null("EditSlot%d" % probe_slot) if is_instance_valid(editor_panel) else null
		edit_layout_ok = edit_layout_ok and is_instance_valid(cell) \
			and cell.position.x >= 0.0 and cell.position.x + cell.size.x <= game.EDIT_PANEL_RECT.size.x \
			and cell.position.y + cell.size.y <= game.EDIT_PANEL_RECT.size.y \
			and int(cell.get_meta("rune_count", -1)) == game.factory.rune_count_on(probe_slot)
	# ② 편집 레일 안에 ScrollContainer가 하나도 없다(보관함 스크롤은 별도 패널이다).
	var editor_scrolls := 0
	for child in editor_panel.get_children() if is_instance_valid(editor_panel) else []:
		if child is ScrollContainer:
			editor_scrolls += 1
	edit_layout_ok = edit_layout_ok and editor_scrolls == 0
	# --- X2 편집 대간소화: 상시 노출 텍스트 상한 + 호버 툴팁 + 모드 제거 ---------------
	# 사용자 피드백 ⑤ "텍스트가 너무 많아 / 세부는 호버로"의 회귀 방지선이다.
	# ⓐ 문장 라벨 0건. 화면에 남은 글자는 카드 이름 · 요약 숫자 3개 · 과밀 "+N"뿐이고
	#    나머지(칸 번호 · 원소 1글자 마크 · ▶ ◀)는 **글자가 아니라 기호 한 자**라 세지 않는다.
	#    14자 이상이면 그건 설명 문장이다 — 프로젝트에서 가장 긴 카드·아이템 이름도 12자다.
	#    툴팁 내용은 `editor_panel` 밖(툴팁 층)에 있으므로 이 셈에 들어오지 않는다 — 의도다.
	var text_labels := 0
	var prose_labels := 0
	var label_probe: Array[Node] = []
	if is_instance_valid(editor_panel):
		label_probe.append(editor_panel)
	while not label_probe.is_empty():
		var node: Node = label_probe.pop_back()
		for child in node.get_children():
			label_probe.append(child)
		if not (node is Label):
			continue
		var label_text := (node as Label).text.strip_edges()
		if label_text.length() < 2:
			continue
		text_labels += 1
		if label_text.length() >= 14:
			prose_labels += 1
	var edit_minimal_ok := is_instance_valid(editor_panel) and prose_labels == 0 and text_labels <= 16
	# ⓑ 모드 개념이 화면에서 사라졌다(모드 바 버튼 2개가 없다).
	edit_minimal_ok = edit_minimal_ok \
		and editor_panel.get_node_or_null("EditMode_card") == null \
		and editor_panel.get_node_or_null("EditMode_slot") == null
	# ⓒ 지운 정보가 전부 호버로 갔다 — 여섯 축의 툴팁이 등록돼 있다.
	for tip_key: String in ["help", "summary", "bond", "inventory", "equipment", "close"]:
		edit_minimal_ok = edit_minimal_ok and game.factory_tooltip_targets.has(tip_key)
	for probe_slot in FactoryDeck.SLOT_COUNT:
		for suffix: String in ["handle", "card", "runes"]:
			edit_minimal_ok = edit_minimal_ok and game.factory_tooltip_targets.has("slot%d_%s" % [probe_slot, suffix])
	# ⓓ 툴팁이 실제로 뜬다(캡처가 쓰는 강제 표시 경로 = 사람이 호버했을 때와 같은 경로).
	edit_minimal_ok = edit_minimal_ok and game._force_factory_tooltip("slot0_handle") \
		and UIKit.tooltip_shown(game.factory_tooltip_layer) == game.factory_tooltip_targets["slot0_handle"]
	UIKit.tooltip_hide(game.factory_tooltip_layer)
	# ⓔ 각인 툴팁이 그 칸의 각인을 하나도 빠뜨리지 않는다(정보 손실 0의 직접 단언).
	for probe_slot in FactoryDeck.SLOT_COUNT:
		var pips: Variant = game.factory_tooltip_targets.get("slot%d_runes" % probe_slot)
		if not (pips is Control) or not (pips as Control).has_meta(UIKit.TOOLTIP_META):
			edit_minimal_ok = false
			continue
		var tip_spec: Dictionary = (pips as Control).get_meta(UIKit.TOOLTIP_META)
		edit_minimal_ok = edit_minimal_ok \
			and (tip_spec.get("rows", []) as Array).size() >= game.factory.rune_count_on(probe_slot)
	# ⓖ ★ Y3(피드백 ③ · §8 ③): 각인 자리가 **색 사각형이 아니라 그림 기호**다.
	#    붙은 수만큼 TextureRect(글리프)가 서고 빈 자리만 ColorRect 유령으로 남는다.
	#    자리 총합은 여전히 `RUNE_SLOTS_PER_SLOT`이고 위치·간격·`+N`은 무변경이다.
	for probe_slot in FactoryDeck.SLOT_COUNT:
		# 각인 줄 = `slot{N}_runes` 툴팁 대상 그 자체다(위 ⓔ가 쓰는 것과 같은 노드).
		var rune_row_value: Variant = game.factory_tooltip_targets.get("slot%d_runes" % probe_slot)
		if not (rune_row_value is Control):
			edit_minimal_ok = false
			continue
		var rune_row: Control = rune_row_value
		var rune_glyphs := 0
		var rune_ghosts := 0
		for row_child in rune_row.get_children():
			if row_child is TextureRect:
				rune_glyphs += 1
			elif row_child is ColorRect:
				rune_ghosts += 1
		edit_minimal_ok = edit_minimal_ok \
			and rune_glyphs == mini(game.factory.rune_count_on(probe_slot), RuneEngine.RUNE_SLOTS_PER_SLOT) \
			and rune_glyphs + rune_ghosts == RuneEngine.RUNE_SLOTS_PER_SLOT
	# ⓗ 각인 **15종이 서로 다른 그림**을 쓴다. §2.5가 예고한 전용 시트(15칸)를 YA가
	#    굽지 않아 기존 두 시트(글리프 16 · 포인터 16)에서 배정했으므로, 유일성이
	#    데이터가 아니라 **표**에 걸린다 — 그 표를 여기서 문다.
	var glyph_seen: Dictionary = {}
	var glyph_ids := RuneEngine.all_rune_ids()
	for glyph_id in glyph_ids:
		if not game.RUNE_GLYPH.has(glyph_id):
			edit_minimal_ok = false
			continue
		var glyph_entry: Array = game.RUNE_GLYPH[glyph_id]
		glyph_seen["%s/%s" % [String(glyph_entry[0]), String(glyph_entry[1])]] = true
	edit_minimal_ok = edit_minimal_ok and glyph_seen.size() == glyph_ids.size()
	# ⓘ 레일 각인 줄(구 결속 띠 자리)도 **같은 그림 언어**다 — 붙은 자리는 글리프,
	#    빈 자리는 유령 사각형. 칸 각인과 레일 각인이 자리로만 갈린다(§8 ③).
	for rail_index in RuneEngine.RAIL_RUNE_CAP:
		var rail_node: Node = editor_panel.get_node_or_null("EditRailRune%d" % rail_index) if is_instance_valid(editor_panel) else null
		edit_minimal_ok = edit_minimal_ok and rail_node != null \
			and (rail_node is TextureRect) == (rail_index < game.factory.rail_rune_count())
	# ⓕ 모드 없이 두 조작이 갈린다 — 손잡이는 slot 제스처, 카드 몸통은 card 제스처.
	for probe_slot in FactoryDeck.SLOT_COUNT:
		var cell_node := editor_panel.get_node_or_null("EditSlot%d" % probe_slot) if is_instance_valid(editor_panel) else null
		var handle := cell_node.get_node_or_null("EditSlotHandle%d" % probe_slot) if cell_node != null else null
		var body := cell_node.get_node_or_null("EditSlotCard%d" % probe_slot) if cell_node != null else null
		if handle == null or body == null:
			edit_minimal_ok = false
			continue
		var handle_payload: Dictionary = handle.get("drag_payload")
		var body_payload: Dictionary = body.get("drag_payload")
		edit_minimal_ok = edit_minimal_ok \
			and String(handle_payload.get("gesture", "")) == game.EDIT_MODE_SLOT \
			and String(body_payload.get("gesture", "")) == game.EDIT_MODE_CARD \
			and bool(handle_payload.get("has_card", false)) \
			and bool(body_payload.get("has_card", true)) == (not game.factory.get_card(probe_slot).is_empty())
	# ③ 부록 C-1의 두 조작: 같은 드롭 경로가 gesture에 따라 다른 FactoryDeck API를 부른다.
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 1))
	game.factory.place_card(1, DealCardLibrary.instance("thunder", 1))
	while game.factory.rune_count_on(0) > 0:
		game.factory.detach_rune(0, 0)
	while game.factory.rune_count_on(1) > 0:
		game.factory.detach_rune(1, 0)
	game.factory.attach_rune(0, RuneEngine.roll_rune("strong", game.rng))
	game._show_factory_menu("edit", {}, "playing")
	game._on_factory_card_dropped({"zone":"rail", "slot":0, "lane":0, "gesture":"card", "has_card":true}, {"zone":"rail", "slot":1, "lane":0, "gesture":"card", "has_card":true})
	var two_gesture_ok := String(game.factory.get_card(0).get("id", "")) == "thunder" and String(game.factory.get_card(1).get("id", "")) == "cleave" \
		and game.factory.rune_count_on(0) == 1 and game.factory.rune_count_on(1) == 0
	game._on_factory_card_dropped({"zone":"rail", "slot":0, "lane":0, "gesture":"slot", "has_card":true}, {"zone":"rail", "slot":1, "lane":0, "gesture":"slot", "has_card":true})
	# 칸 교환은 각인을 데려간다 → 각인이 1번 칸으로 따라갔다.
	two_gesture_ok = two_gesture_ok and String(game.factory.get_card(0).get("id", "")) == "cleave" and String(game.factory.get_card(1).get("id", "")) == "thunder" \
		and game.factory.rune_count_on(0) == 0 and game.factory.rune_count_on(1) == 1
	# ④ 아이템은 레일에 못 놓는다 — 드롭이 거부되고 보관함에 그대로 남는다.
	game.factory.add_inventory(ItemLibrary.instance("r_ring_02"))
	game._show_factory_menu("edit", {}, "playing")
	var item_inventory_index := game.factory.inventory.size() - 1
	var item_guard_before := game.factory.inventory.size()
	game._on_factory_card_dropped({"zone":"inventory", "index":item_inventory_index, "has_card":true}, {"zone":"rail", "slot":3, "lane":0, "gesture":"card", "has_card":false})
	var item_rail_guard_ok := game.factory.inventory.size() == item_guard_before and game.factory.get_card(3).is_empty()
	game._close_factory_menu()

	# =========================================================================
	# ★ Y4 — 전투 UI · 모달 · 색 (FEEDBACK_Y §9.3 Y4 · 피드백 ⑤⑦⑫⑯⑳㉑)
	# =========================================================================
	# 묶음 넷: 색(y4_color) · 아이콘 판(y4_icon) · 장비(y4_equip) · 재화·기하(y4_chrome).
	# 넷 다 **음성 대조로 실제로 빨개지는지 확인했다**(handoff-y4 §7).

	# ---- ⓐ 색·마크 계약 ------------------------------------------------------
	# `ELEMENT_COLOR`가 원소색의 단일 진실 원천이라는 것, 그리고 마크가 한자를
	# 버렸다는 것 두 가지가 계약이다.
	var y4_color_ok := game.ELEMENT_COLOR.size() == 7 and game.RAIL_ELEMENT_MARK.size() == 7
	var mark_seen: Dictionary = {}
	var color_seen: Dictionary = {}
	for element_value in game.ELEMENT_COLOR.keys():
		var element := String(element_value)
		var mark := String(game.RAIL_ELEMENT_MARK.get(element, ""))
		# 마크는 손으로 적은 글자가 아니라 **`element_name()`의 첫 글자**여야 한다 —
		# 두 표가 어긋나면(예: 이름은 「기름」인데 마크는 「유」) 여기서 죽는다.
		y4_color_ok = y4_color_ok and mark.length() == 1 \
			and mark == DealCardLibrary.element_name(element).substr(0, 1)
		mark_seen[mark] = true
		color_seen[(game.ELEMENT_COLOR[element_value] as Color).to_html(false)] = true
	# 금지 어휘표의 한자 5자가 마크에 한 자도 없다(「독」「타」는 한글 이름의 첫 자라 제외).
	for hanja: String in ["화", "빙", "뇌", "유", "초"]:
		y4_color_ok = y4_color_ok and not mark_seen.has(hanja)
	# 일곱 색이 서로 다르다. 구판은 기름·정신이 **둘 다 보라**여서 여섯 색이었다.
	y4_color_ok = y4_color_ok and color_seen.size() == 7 and mark_seen.size() == 7
	y4_color_ok = y4_color_ok \
		and (game.ELEMENT_COLOR["fire"] as Color).is_equal_approx(GamePalette.EMBER_RED) \
		and (game.ELEMENT_COLOR["oil"] as Color).is_equal_approx(GamePalette.OIL_BROWN)
	# ⚠️ **공허한 통과 방지 — 어긋난 색을 라이브러리에 직접 심는다.**
	#    처음에는 카드 **인스턴스**의 `color` 키를 흔들어 봤는데 그것으로는 안 물었다:
	#    구 `_factory_card_color()`는 인스턴스가 아니라 **`DealCardLibrary.by_id()`의
	#    `color`**를 읽었고, Y1이 데이터 40장을 이미 정합시켜 놓아서 폴백 구조를
	#    통째로 지워도 초록이었다(음성 대조 #2에서 실제로 그렇게 나왔다).
	#    그래서 **라이브러리 항목 자체를 잠깐 어긋나게 만든다** — 구 버그가 있던
	#    바로 그 상태(「thunder 카드가 청록」)를 재현하고 즉시 되돌린다.
	#    (`DealCardLibrary.SKILLS`는 `const`라 런타임에 못 고친다 — 읽기 전용 오류가 난다.
	#     그래서 라이브러리를 흔드는 대신 **라이브러리와 어긋난 카드 두 종류**를 만든다.)
	for stale_probe: Array in [["thunder", "oil"], ["flame_field", "psi"], ["aura", "ice"]]:
		# 카드가 자기 `element`를 들고 있고 그 값이 라이브러리 항목과 다르다.
		# 구 코드는 `by_id(id).color`(= 라이브러리 원소색)를 그대로 뱉었다.
		var stale_card := DealCardLibrary.instance(String(stale_probe[0]), 1)
		stale_card["element"] = String(stale_probe[1])
		var library_color := Color(String(DealCardLibrary.by_id(String(stale_probe[0])).get("color", "f4d35e")))
		y4_color_ok = y4_color_ok \
			and game._card_element(stale_card) == String(stale_probe[1]) \
			and game._factory_card_color(stale_card).is_equal_approx(game.ELEMENT_COLOR[String(stale_probe[1])]) \
			and not game._factory_card_color(stale_card).is_equal_approx(library_color)
	# 라이브러리에 아예 없는 카드라도 **카드가 든 원소**를 따라야 한다
	# (구 코드는 `by_id()`가 빈 사전이면 노란 기본값 `f4d35e`로 떨어졌다).
	for orphan_element: String in ["ice", "oil", "psi"]:
		var orphan_card := {"kind": "skill", "id": "y4_orphan_probe", "element": orphan_element, "rank": 1}
		y4_color_ok = y4_color_ok \
			and game._factory_card_color(orphan_card).is_equal_approx(game.ELEMENT_COLOR[orphan_element])

	# ---- ⓑ 스킬 아이콘 판이 `ELEMENT_COLOR`를 따라온다 -----------------------
	# YA가 구운 아틀라스는 판 색을 **주황 불 · 보라 기름**으로 픽셀에 박아 뒀다.
	# `skill_icon.gd`의 런타임 재배색이 없으면 카드 프레임은 빨강인데 아이콘만 주황이 된다.
	# 판정: 판 픽셀의 **평균 색상(hue)**이 구운 색보다 새 색에 더 가까운가.
	var y4_icon_ok := true
	for icon_probe: Array in [["flame_field", "fire", true], ["gravity_well", "oil", true],
			["frost_ring", "ice", false]]:
		var probe_id := String(icon_probe[0])
		var probe_element := String(icon_probe[1])
		var probe_moved := bool(icon_probe[2])
		if not PixelSkillIcon.GENERATED_SKILL_INDEX.has(probe_id):
			y4_icon_ok = false
			continue
		var cell_index := int(PixelSkillIcon.GENERATED_SKILL_INDEX[probe_id])
		var mean_hue := _v4_plate_mean_hue(PixelSkillIcon.skill_tile_texture(cell_index))
		if mean_hue < 0.0:
			y4_icon_ok = false
			continue
		var baked_hue: float = (PixelSkillIcon.BAKED_ELEMENT_COLOR[probe_element] as Color).h
		var want_hue: float = (game.ELEMENT_COLOR[probe_element] as Color).h
		var to_want := _v4_hue_gap(mean_hue, want_hue)
		var to_baked := _v4_hue_gap(mean_hue, baked_hue)
		if probe_moved:
			# 옮긴 두 원소는 새 색 쪽으로 확실히 붙어야 한다.
			y4_icon_ok = y4_icon_ok and to_want < to_baked
		else:
			# 안 옮긴 원소는 제자리다 — 무차별 색상 회전이 들어오면 여기서 죽는다.
			y4_icon_ok = y4_icon_ok and to_want < 0.06

	# ---- ⓒ 장비 부위 실루엣 · 배지 · 교체 확인 -------------------------------
	var y4_equip_ok := true
	game.factory.equipment.clear()
	game.factory.inventory.clear()
	game._show_factory_menu("edit", {}, "playing")
	var equip_panel := game.overlay.get_node_or_null("EditorPanel")
	# 빈 부위 4칸 전부: 무채 실루엣이 서고 배지는 없다(피드백 ⑳).
	for part_index in FactoryDeck.EQUIPMENT_PARTS.size():
		var empty_tile := _v4_find_named(equip_panel, "EditEquipTile%d" % part_index)
		y4_equip_ok = y4_equip_ok and empty_tile != null \
			and _v4_find_named(empty_tile, "EquipSilhouette") != null \
			and _v4_find_named(empty_tile, "EquipBadge") == null
	# 무기를 끼우면 같은 칸이 배지로 갈린다.
	game.factory.equip(ItemLibrary.instance("u_greatsword_01"))
	game._show_factory_menu("edit", {}, "playing")
	equip_panel = game.overlay.get_node_or_null("EditorPanel")
	var weapon_index := FactoryDeck.EQUIPMENT_PARTS.find("weapon")
	var worn_tile := _v4_find_named(equip_panel, "EditEquipTile%d" % weapon_index)
	y4_equip_ok = y4_equip_ok and worn_tile != null \
		and _v4_find_named(worn_tile, "EquipBadge") != null \
		and _v4_find_named(worn_tile, "EquipSilhouette") == null
	# 교체 확인(피드백 ⑫) — **찬 부위**로 갈 때만 물어야 한다.
	game.factory.add_inventory(ItemLibrary.instance("u_greatsword_01"))
	game.factory_selected_inventory = game.factory.inventory.size() - 1
	game._editor_equipment_pressed(weapon_index)
	var swap_panel := game.overlay.get_node_or_null("EquipSwapPanel") if is_instance_valid(game.overlay) else null
	y4_equip_ok = y4_equip_ok and not game.equip_swap.is_empty() and swap_panel != null \
		and _v4_find_named(swap_panel, "EquipSwapCurrent") != null \
		and _v4_find_named(swap_panel, "EquipSwapIncoming") != null \
		and _v4_find_named(swap_panel, "EquipSwapAccept") != null \
		and _v4_find_named(swap_panel, "EquipSwapCancel") != null
	# 「그대로」를 누르면 아무것도 안 움직인다 — 보관함 장수와 낀 것이 그대로다.
	var keep_inventory := game.factory.inventory.size()
	var keep_equipped := String(game.factory.equipped_at("weapon").get("id", ""))
	game._cancel_equip_swap()
	y4_equip_ok = y4_equip_ok and game.equip_swap.is_empty() \
		and game.factory.inventory.size() == keep_inventory \
		and String(game.factory.equipped_at("weapon").get("id", "")) == keep_equipped
	# ⚠️ **음성 축** — 빈 부위(목걸이)로 가면 확인 화면이 뜨면 안 된다.
	game.factory.add_inventory(ItemLibrary.instance("c_neck_01"))
	game.factory_selected_inventory = game.factory.inventory.size() - 1
	var necklace_index := FactoryDeck.EQUIPMENT_PARTS.find("necklace")
	game._editor_equipment_pressed(necklace_index)
	y4_equip_ok = y4_equip_ok and game.equip_swap.is_empty() \
		and not game.factory.equipped_at("necklace").is_empty()
	game._close_factory_menu()

	# ---- ⓓ 재화 칩 · 미니 레일 · 1280×720 경계 ------------------------------
	var y4_chrome_ok := true
	# 배치 화면: 「칸 01~05 아이콘 행」이 사라지고 5칸 미니 레일 하나가 섰다(피드백 ⑦).
	game._show_factory_menu("place", DealCardLibrary.instance("cleave", 1), "playing")
	var place_root := game.overlay
	var mini_rail := _v4_find_named(place_root, "PlaceMiniRail")
	var mini_ok := mini_rail != null
	for slot_probe in FactoryDeck.SLOT_COUNT:
		mini_ok = mini_ok and _v4_find_named(mini_rail, "PlaceMiniSlot%d" % slot_probe) != null
	# 구 머리 줄이 정말 없어졌는가 — 배치 화면 어디에도 「칸 01」류 라벨이 없다.
	var place_text := _collect_label_text(place_root)
	var stale_ok := true
	for stale_header: String in ["칸 01", "칸 02", "칸 03", "칸 04", "칸 05"]:
		stale_ok = stale_ok and not place_text.contains(stale_header)
	if not (mini_ok and stale_ok):
		print("Y4_DEBUG mini=%s stale=%s" % [mini_ok, stale_ok])
	y4_chrome_ok = y4_chrome_ok and mini_ok and stale_ok
	# 전 화면 경계 검사(§8 ⑦ "경계 검사 신설"). 등장 트윈이 가라앉은 뒤에 잰다.
	await _settle_modal()
	var place_out := _assert_in_viewport(place_root)
	y4_chrome_ok = y4_chrome_ok and place_out.is_empty()
	if not place_out.is_empty():
		print("Y4_VIEWPORT_OVERFLOW place=%s" % [place_out])
	game._store_pending_factory_card()
	# 세공사: 보유 골드가 **금화 그림 + 숫자만**이다(「G」 글자가 붙어 있으면 실패).
	game.gold = 777
	game._show_rune_shop()
	var shop_panel := game.overlay.get_node_or_null("RuneShopPanel") if is_instance_valid(game.overlay) else null
	var purse_label := _v4_find_named(shop_panel, "RuneShopPurse") as Label
	var purse_ok := purse_label != null and purse_label.text == "777" \
		and _v4_find_named(shop_panel, "GoldCoin") != null
	if not purse_ok:
		print("Y4_DEBUG purse=%s text=%s coin=%s" % [
			purse_label != null, purse_label.text if purse_label != null else "-",
			_v4_find_named(shop_panel, "GoldCoin") != null])
	y4_chrome_ok = y4_chrome_ok and purse_ok
	await _settle_modal()
	var shop_out := _assert_in_viewport(game.overlay)
	y4_chrome_ok = y4_chrome_ok and shop_out.is_empty()
	if not shop_out.is_empty():
		print("Y4_VIEWPORT_OVERFLOW rune_shop=%s" % [shop_out])
	game._close_base_camp()
	# 레벨업 2택: 두 줄이 **서로 다른 색**이다(desc 본문색 / combo 속성색 · 피드백 ⑭).
	game._show_skill_choice("level")
	var combo_line := _v4_find_named(game.overlay, "ChoiceCombo") as Label
	var combo_ok := combo_line != null and combo_line.text.strip_edges().length() >= 2
	if combo_line != null:
		var combo_color: Color = combo_line.get_theme_color("font_color")
		combo_ok = combo_ok and not combo_color.is_equal_approx(GamePalette.TEXT)
	if not combo_ok:
		print("Y4_DEBUG combo=%s" % [combo_line.text if combo_line != null else "MISSING"])
	y4_chrome_ok = y4_chrome_ok and combo_ok
	await _settle_modal()
	var choice_out := _assert_in_viewport(game.overlay)
	y4_chrome_ok = y4_chrome_ok and choice_out.is_empty()
	if not choice_out.is_empty():
		print("Y4_VIEWPORT_OVERFLOW choice=%s" % [choice_out])
	game._cancel_skill_choice()

	# 아이템 획득 새 플로우: 후보 2개 이지선다 → 고른 1개는 보관함 직행, 남은 1개는 마왕에게.
	# 어떤 경우에도 factory_place(즉시 배치)로 진입하지 않는다.
	var storage_before := game.factory.inventory.size()
	var boss_items_before := game.boss_items.size()
	game._show_item_offer("treasure")
	var item_pair_ok := game.state == "item_choice" and game.current_item_pair.size() == 2 and game.choice_buttons.size() == 2
	item_pair_ok = item_pair_ok and String(game.current_item_pair[0].get("id", "")) != String(game.current_item_pair[1].get("id", ""))
	item_pair_ok = item_pair_ok and game._choice_highlight_count() == 1
	var kept_item_id := String(game.current_item_pair[0].get("id", "")) if game.current_item_pair.size() == 2 else ""
	var passed_item_id := String(game.current_item_pair[1].get("id", "")) if game.current_item_pair.size() == 2 else ""
	game._choose_offered_item(0)
	var item_to_storage_ok := item_pair_ok and game.state == "playing" and game.factory.inventory.size() == storage_before + 1
	item_to_storage_ok = item_to_storage_ok and String(game.factory.inventory[game.factory.inventory.size() - 1].get("id", "")) == kept_item_id
	item_to_storage_ok = item_to_storage_ok and String(game.factory.inventory[game.factory.inventory.size() - 1].get("kind", "")) == "item"
	item_to_storage_ok = item_to_storage_ok and game.boss_items.size() == boss_items_before + 1 and game.boss_items[game.boss_items.size() - 1] == passed_item_id

	# 초반 원거리 배제 검사(2차 피드백⑩). targeting 모듈이 붙는 두 경로를 함께 막았는지 본다.
	#   ① 네이티브 원거리 몬스터: monster_library.gd MONSTERS.unlock
	#   ② 부채 기반 랜덤 모듈: enemy.gd setup()의 debt 루프
	# 두 경로 모두 MonsterLibrary.ranged_gate_ok(cycle) 한 곳을 통과해야 한다.
	var early_ranged_ok := MonsterLibrary.ranged_table_ok()
	early_ranged_ok = early_ranged_ok and not MonsterLibrary.ranged_gate_ok(1)
	early_ranged_ok = early_ranged_ok and MonsterLibrary.ranged_gate_ok(MonsterLibrary.ranged_unlock_cycle())
	for spawn_row: Dictionary in MonsterLibrary.spawn_table(1, true):
		early_ranged_ok = early_ranged_ok and not bool(spawn_row.get("ranged", false))
	var saved_night := game.is_night
	var saved_cycle := game.cycle_number
	var saved_debts := game.rejected_skills.duplicate()
	game.is_night = true
	game.cycle_number = 1
	# targeting으로 매핑되는 부채(투사체/연쇄/대시)만 8장 넘겨 최악의 조건을 만든다.
	# 게이팅이 없으면 마물 1마리가 원거리가 될 확률이 1 - 0.9^8 ≈ 57%다.
	game.rejected_skills.assign(["thunder", "targeting", "dash_blade", "blade_fan", "earth_splitter", "boomerang_blade", "phantom_step", "recursion"])
	var night_one_limit := game.combat.current_enemy_limit()
	var night_one_interval := game.combat.current_spawn_interval()
	var night_one_burst := game.combat.night_raid_burst_count()
	for _probe in 40:
		var probe_position: Vector2 = game.world.find_walkable_near(game.player.global_position, game.rng, 300.0, 700.0)
		var probe_enemy := game.combat.spawn_enemy_instance(probe_position)
		if not is_instance_valid(probe_enemy):
			continue
		var probe_modules: Array = probe_enemy.active_modules
		early_ranged_ok = early_ranged_ok and not probe_modules.has(MonsterLibrary.RANGED_MODULE)
	# 밤 1회차 물량 완화(피드백⑩)도 같은 플래그로 회귀 방지한다.
	early_ranged_ok = early_ranged_ok and night_one_limit <= 40 and night_one_interval >= 0.5 and night_one_burst <= 6
	game.is_night = saved_night
	game.cycle_number = saved_cycle
	game.rejected_skills.assign(saved_debts)

	# 초반 낮 선공몹 배제 검사(3차 피드백⑭). behavior 4 = 기본 선공·시야 추적.
	# 밤은 행동 유형과 무관하게 전원 습격이라 게이팅 대상이 아니므로 밤에는 남아 있어야 한다.
	# W7(2026-08-07): 7일 런에 맞춰 선공몹 해금이 5일차 → 3일차로 내려갔다(설계 §4.1).
	var early_day_peace_ok := MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE >= 3 and MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE <= 10
	# behavior 4 종이 실제로 여러 종 존재해야 이 검사가 의미를 가진다(빈 집합 통과 방지).
	var aggro_species := 0
	for archetype: Dictionary in MonsterLibrary.MONSTERS:
		if int(archetype["behavior"]) == MonsterLibrary.AGGRO_BEHAVIOR:
			aggro_species += 1
	early_day_peace_ok = early_day_peace_ok and aggro_species >= 3
	for peace_cycle in range(1, MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE):
		early_day_peace_ok = early_day_peace_ok and not MonsterLibrary.aggro_gate_ok(peace_cycle, false)
		for spawn_row: Dictionary in MonsterLibrary.spawn_table(peace_cycle, false):
			early_day_peace_ok = early_day_peace_ok and int(spawn_row["behavior"]) != MonsterLibrary.AGGRO_BEHAVIOR
		var night_aggro_rows := 0
		for spawn_row: Dictionary in MonsterLibrary.spawn_table(peace_cycle, true):
			if int(spawn_row["behavior"]) == MonsterLibrary.AGGRO_BEHAVIOR:
				night_aggro_rows += 1
		early_day_peace_ok = early_day_peace_ok and night_aggro_rows > 0
	# 해금 주기부터는 낮에도 등장하고, 주기가 오를수록 비중이 커진다(램프업).
	var unlock_day_share := 0.0
	var later_day_share := 0.0
	for spawn_row: Dictionary in MonsterLibrary.spawn_table(MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE, false):
		if int(spawn_row["behavior"]) == MonsterLibrary.AGGRO_BEHAVIOR:
			unlock_day_share += float(spawn_row["share"])
	for spawn_row: Dictionary in MonsterLibrary.spawn_table(MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE + 2, false):
		if int(spawn_row["behavior"]) == MonsterLibrary.AGGRO_BEHAVIOR:
			later_day_share += float(spawn_row["share"])
	early_day_peace_ok = early_day_peace_ok and unlock_day_share > 0.0 and later_day_share > unlock_day_share
	# 강제 경로가 게이트 때문에 빈 후보로 죽지 않아야 한다.
	#   기본: 낮 초반의 forced_behavior=4는 그 주기에서 허용된 순한 몹으로 대체된다.
	#   override: 시련 캠프 정예·미믹·보스 하수인은 그대로 선공몹을 받는다.
	var gated_forced := MonsterLibrary.roll(game.rng, 1, false, MonsterLibrary.AGGRO_BEHAVIOR)
	early_day_peace_ok = early_day_peace_ok and not gated_forced.is_empty() and int(gated_forced["behavior"]) != MonsterLibrary.AGGRO_BEHAVIOR
	var override_forced := MonsterLibrary.roll(game.rng, 1, false, MonsterLibrary.AGGRO_BEHAVIOR, true)
	early_day_peace_ok = early_day_peace_ok and not override_forced.is_empty() and int(override_forced["behavior"]) == MonsterLibrary.AGGRO_BEHAVIOR
	# 런타임: 낮 주기 1의 필드 population을 40번 굴려도 선공몹이 한 마리도 없어야 한다.
	var day_saved_night := game.is_night
	var day_saved_cycle := game.cycle_number
	game.is_night = false
	game.cycle_number = 1
	for _day_probe in 40:
		var day_archetype := MonsterLibrary.roll(game.rng, game.cycle_number, game.is_night)
		early_day_peace_ok = early_day_peace_ok and int(day_archetype["behavior"]) != MonsterLibrary.AGGRO_BEHAVIOR
	game.is_night = day_saved_night
	game.cycle_number = day_saved_cycle

	# 모달 복귀 무적 검사(3차 피드백⑮). 대시 무적과 같은 경로(player.invulnerability)다.
	game.player.shield_charges = 0
	game.player.rollback_charges = 0
	game.player.dash_time_left = 0.0
	game.player.invulnerability = 0.0
	game.player.grace_invulnerability = 0.0
	game._show_factory_menu("edit", {}, "playing")
	game._close_factory_menu()
	var modal_invuln_ok := game.state == "playing" and game.player.invulnerability >= GameTuning.MODAL_RETURN_INVULN - 0.001
	modal_invuln_ok = modal_invuln_ok and game.player.grace_invulnerability > 0.0
	var health_before_modal := game.player.health
	game.player.take_damage(31.0, game.player.global_position + Vector2.RIGHT * 40.0)
	modal_invuln_ok = modal_invuln_ok and is_equal_approx(game.player.health, health_before_modal)
	# 음성 대조: 무적이 끝나면 다시 맞아야 한다(무적이 영구화되지 않았는지).
	game.player.invulnerability = 0.0
	game.player.grace_invulnerability = 0.0
	game.player.take_damage(31.0, game.player.global_position + Vector2.RIGHT * 40.0)
	modal_invuln_ok = modal_invuln_ok and game.player.health < health_before_modal
	game.player.heal_full()

	# 마왕 토스트 3초 유지 검사(3차 피드백⑲).
	# 예전 코드는 대기(tween_interval)와 페이드 아웃을 parallel()로 묶어 등장 0.35초 뒤에
	# 이미 투명해졌다. 유지 구간 중간에 완전 불투명인지 실제로 기다려 확인한다.
	game.boss_toast_queue.clear()
	if is_instance_valid(game.boss_toast):
		game.boss_toast.free()
	game.boss_toast = null
	game._show_boss_growth_toast([{"id":"cleave", "name":"회전베기", "debt_desc":"토스트 유지 검사"}])
	var toast_hold_ok := GameTuning.BOSS_TOAST_HOLD >= 3.0 and is_instance_valid(game.boss_toast)
	var showing_toast := game.boss_toast
	# 표시 중에 새 사건이 오면 덮어쓰지 않고 대기열에 쌓여야 한다.
	game._show_boss_growth_toast([{"id":"thunder", "name":"낙뢰", "debt_desc":"토스트 큐 검사"}])
	toast_hold_ok = toast_hold_ok and game.boss_toast == showing_toast and game.boss_toast_queue.size() == 1
	await get_tree().create_timer(GameTuning.BOSS_TOAST_FADE_IN + GameTuning.BOSS_TOAST_SLIDE_IN + 1.2, true, false, true).timeout
	toast_hold_ok = toast_hold_ok and is_instance_valid(game.boss_toast) and is_equal_approx(game.boss_toast.modulate.a, 1.0)
	# 현재 토스트가 끝나면 대기열의 다음 토스트가 이어서 뜬다.
	game._finish_boss_growth_toast(game.boss_toast)
	toast_hold_ok = toast_hold_ok and game.boss_toast_queue.is_empty() and is_instance_valid(game.boss_toast)

	game.rejected_skills.assign(["cleave", "cleave", "rapid_slash", "thunder", "meteor_blade", "moon_barrier"])
	game.boss_items.assign(["u_greatsword_01", "r_ring_02"])
	# ---- 마왕도 5칸이다 (구 boss20 = 10칸 × 2레인) ----
	var test_boss_deck := game._build_boss_factory()
	var boss_shape_ok := test_boss_deck.slots.size() == GameTuning.BOSS_SLOT_COUNT
	for boss_slot_index in test_boss_deck.slots.size():
		# 칸당 카드 1장(레인 폐지). 버린 아이템은 레일이 아니라 장비로 간다(§5.4).
		boss_shape_ok = boss_shape_ok and String(test_boss_deck.get_card(boss_slot_index).get("kind", "skill")) != "item"
	boss_shape_ok = boss_shape_ok and test_boss_deck.equipment.size() == mini(game.boss_items.size(), FactoryDeck.EQUIPMENT_PARTS.size())
	game._challenge_demon_king()
	var boss_preview_ok := game.state == "boss_preview" and get_tree().paused and game.boss_factory.slots.size() == GameTuning.BOSS_SLOT_COUNT
	# "돌아가서 준비한다"로 필드에 되돌아간 뒤 다시 도전할 수 있어야 한다 (P1-2).
	# 예전에는 마왕성에서 E를 누른 순간 되돌릴 방법이 없었다.
	game._cancel_boss_preview()
	boss_preview_ok = boss_preview_ok and game.state == "playing" and not get_tree().paused
	game._challenge_demon_king()
	boss_preview_ok = boss_preview_ok and game.state == "boss_preview" and get_tree().paused
	game._begin_boss_battle()
	await get_tree().create_timer(0.16).timeout
	# v2: 마왕도 빚 RELOAD를 낸다. 배율만 ×0.6 (§6.2) — v1의 "RELOAD 없음"에서 뒤집혔다.
	var boss_runtime_ok := game.state == "boss" and is_instance_valid(game.boss) and is_instance_valid(game.boss_cycle) \
		and game.boss_cycle.reload_enabled and is_equal_approx(game.boss_cycle.reload_scale, GameTuning.BOSS_RELOAD_MUL)
	# V7 가산(설계 부록 B V7 검증란 "보스 칸수 단언 추가"): **칸 수가 세 층으로 갈린다.**
	# 5칸 + 각인 + 과열은 마왕만 가진다(부록 A-2 ⑫) — 이 세 줄이 그 경계선이다.
	boss_runtime_ok = boss_runtime_ok \
		and GameTuning.STAGE_BOSS_SLOT_COUNT == 3 and GameTuning.STAGE_BOSS_SLOT_COUNT_ENHANCED == 4 \
		and GameTuning.BOSS_SLOT_COUNT == 5 \
		and BossLibrary.slot_count(false) < BossLibrary.slot_count(true) \
		and BossLibrary.slot_count(true) < GameTuning.BOSS_SLOT_COUNT \
		and not bool(BossLibrary.resolve("C", true).get("uses_runes", true)) \
		and not BossLibrary.resolve("C", true).has("uses_heat") \
		and game.boss_factory.slots.size() == GameTuning.BOSS_SLOT_COUNT
	print("V4_TEST_COMPLETE items=%s skills_pool=%s combat_profiles=%s item_equip=%s initial5=%s slot_swap=%s rune_stack=%s fusion=%s physical_e=%s live_direction=%s choice_cancel=%s single_focus=%s immediate_place=%s item_pair_storage=%s drag_swap=%s edit_layout=%s edit_minimal=%s two_gesture=%s item_rail_guard=%s early_ranged_gate=%s early_day_peace=%s modal_invuln=%s boss_toast_hold=%s boss5=%s boss_preview=%s boss_runtime=%s y4_color=%s y4_icon=%s y4_equip=%s y4_chrome=%s edit_labels=%d edit_prose=%d reload=%.2f" % [
		item_catalog_ok, skill_variety_ok, combat_profiles_ok, item_equip_ok, initial_shape_ok, slot_swap_ok, rune_stack_ok, fusion_ok, castle_input_ok, live_direction_ok, choice_ui_ok, single_focus_ok, immediate_place_ok, item_to_storage_ok, drag_swap_ok, edit_layout_ok, edit_minimal_ok, two_gesture_ok, item_rail_guard_ok, early_ranged_ok, early_day_peace_ok, modal_invuln_ok, toast_hold_ok, boss_shape_ok, boss_preview_ok, boss_runtime_ok, y4_color_ok, y4_icon_ok, y4_equip_ok, y4_chrome_ok, text_labels, prose_labels, game.factory.total_reload()
	])
	# 출력한 26개 불리언 플래그의 논리곱이 곧 합격 여부다(수치 3개는 판정에서 뺀다).
	var v4_passed := item_catalog_ok and skill_variety_ok and combat_profiles_ok and item_equip_ok \
		and initial_shape_ok and slot_swap_ok and rune_stack_ok and fusion_ok and castle_input_ok \
		and live_direction_ok and choice_ui_ok and single_focus_ok and immediate_place_ok \
		and item_to_storage_ok and drag_swap_ok and edit_layout_ok and edit_minimal_ok \
		and two_gesture_ok and item_rail_guard_ok \
		and early_ranged_ok and early_day_peace_ok \
		and modal_invuln_ok and toast_hold_ok and boss_shape_ok and boss_preview_ok and boss_runtime_ok \
		and y4_color_ok and y4_icon_ok and y4_equip_ok and y4_chrome_ok
	await _quit_test_cleanly(v4_passed)

# =============================================================================
# --castle-test (구 --v4-castle-test) — W9가 v2 의미로 전면 재작성
# =============================================================================
# 검사하는 것(설계 §11 W9 완료 기준):
#   castle_npcs   성 NPC가 v2 4종(card_shop / rune_shop / pact / spy)으로 구성된다
#   shop          카드 상점 4칸 · 스킬은 **드래프트 풀 20종에서만** 나온다
#   refresh       새로고침이 골드를 먹고 상품을 다시 굴린다
#   shop_equip    아이템 구매가 보관함이 아니라 **장비 4부위**로 간다(§5.4)
#   fusion        카드 합성(각인 세공사에 통합)이 랭크를 올린다
#   rune_shop     골드로 각인 3택1에 진입하고 칸에 붙는다(신규)
#   mage_gate     칸 배율 소진 시 구매가 막히고 골드가 새지 않는다(회귀)
#   upgrade_refund 정상 구매 뒤 ESC 취소가 골드를 그대로 돌려준다(회귀)
#   npc_remove    망각의 사제가 FactoryDeck(보관함+레일)을 본다(회귀)
#   npc_swap      운명의 직조사가 같은 랭크로 교체한다(회귀)
#   pact_sell_day  정비 — dwell −1을 골드로 되산다 · 비용이 사용마다 오른다(V3-J)
#   pact_buy_day   탐욕 — dwell +1을 팔아 골드·조각을 받는다 · **대가가 없으면 열리지 않는다**
#   pact_limit     세 거래 각각 런당 2회에서 막힌다 + 미래를 담보로(dwell +2 → epic 1장 확정)
#   spy_remove     밀정이 마왕의 각인 하나를 영구히 지운다
#   ── V8 신설 ──
#   price_scale    상점가 스테이지 스케일 · 1스테이지는 v2와 동일 · 계약은 스케일 밖
#   trophy_flow    보스 트로피 E2E — 고정 스탯 즉시 적용 → 2택1 → 5칸 배치 → 미선택은 마왕에게
#   trophy_stack   5회 누적 효과 == `TrophyLibrary.merge_effects` · 배분표 12종 정합 · 원소 상이
#   trophy_reserve 이미 가진 카드가 선택지면 예비 카드로 갈아끼운다(2택1이 1택이 되지 않게)
func _run_castle_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.gold = 999
	var starter := game.world.get_nearest_interactable(game.world.get_castle_position(), 120.0)
	game._enter_castle(starter)
	# --- NPC 4종 구성 --------------------------------------------------------
	var castle_npcs_ok: bool = game.inside_castle and game.castle_interior.services.size() == 4
	for expected_service: String in game.CASTLE_SERVICES_V2:
		castle_npcs_ok = castle_npcs_ok and game.castle_interior.services.has(expected_service)
	# 배치는 결정적이어야 한다 — 같은 성 id면 같은 순서.
	castle_npcs_ok = castle_npcs_ok and game._castle_services("fixed_castle") == game._castle_services("fixed_castle")

	# --- 카드 상점 -----------------------------------------------------------
	game._show_card_shop(false)
	var shop_ok: bool = game.state == "camp" and game.shop_offers.size() == 4
	# 스킬 제안은 v2 드래프트 풀 20종 안에서만 나와야 한다(legacy 8종 금지).
	var draft_ids := DealCardLibrary.draft_ids()
	for offer: Dictionary in game.shop_offers:
		var offered_card: Dictionary = offer["card"]
		if String(offered_card.get("kind", "skill")) != "item":
			shop_ok = shop_ok and draft_ids.has(String(offered_card.get("id", "")))
	var old_gold := game.gold
	game._refresh_shop(10)
	var refresh_ok: bool = game.shop_refresh_count == 1 and game.shop_offers.size() == 4 and game.gold == old_gold - 10
	# 아이템 카드는 장비 4부위로 직행해야 한다(레일 칸을 먹지 않는다 · §5.4).
	var shop_item_index := -1
	for offer_index in game.shop_offers.size():
		if String((game.shop_offers[offer_index]["card"] as Dictionary).get("kind", "skill")) == "item":
			shop_item_index = offer_index
			break
	var shop_equip_ok := shop_item_index >= 0
	if shop_equip_ok:
		var purchased_id := String((game.shop_offers[shop_item_index]["card"] as Dictionary).get("id", ""))
		var equipment_before := game.factory.equipment.size()
		game._buy_shop_offer(shop_item_index)
		var equipped_ids: Array[String] = []
		for equipped: Dictionary in game.factory.equipment:
			equipped_ids.append(String(equipped.get("id", "")))
		shop_equip_ok = game.state == "camp" and game.factory.equipment.size() == equipment_before + 1
		shop_equip_ok = shop_equip_ok and equipped_ids.has(purchased_id)
		shop_equip_ok = shop_equip_ok and bool(game.shop_offers[shop_item_index].get("sold", false))
		# 장비는 레일 칸을 하나도 먹지 않아야 한다.
		for slot_index in game.factory.slots.size():
			shop_equip_ok = shop_equip_ok and String(game.factory.get_card(slot_index).get("kind", "skill")) != "item"
	game._close_base_camp()

	# --- 각인 세공사 ① 카드 합성(통합) --------------------------------------
	game.factory.add_inventory(DealCardLibrary.instance("time_cut", 1))
	game.factory.add_inventory(DealCardLibrary.instance("time_cut", 1))
	game._show_fusion_service()
	game._fuse_card("time_cut", 1)
	var fusion_ok: bool = game.factory.get_rank_count("time_cut", 2) == 1
	if game.state == "camp": game._close_base_camp()

	# --- 각인 세공사 ② X1: 3택 진열 · 희귀도 가격 · 새로고침 · 구매 --------------
	# W9판("70 + 30n G를 내면 드래프트가 열린다")이 X1에서 **보고 사는 진열대**로 바뀌었다.
	game.gold = 999
	game.state = "castle_interior"
	game._show_rune_shop()
	var rune_shop_ok: bool = game.state == "camp" \
		and game.rune_shop_offers.size() == game.RUNE_SHOP_OFFER_COUNT \
		and game.rune_shop_buttons.size() == game.RUNE_SHOP_OFFER_COUNT
	# ⓐ 값은 **희귀도가 정한다.** 프리미엄이 하나도 안 걸린 기준 인스턴스로 3등급을 재면
	#    common < rare < epic이 무조건 성립해야 한다(굴림 프리미엄은 인스턴스 축이다).
	var price_common: int = game._rune_offer_price({"instance": {}, "rarity": RuneEngine.RARITY_COMMON})
	var price_rare: int = game._rune_offer_price({"instance": {}, "rarity": RuneEngine.RARITY_RARE})
	var price_epic: int = game._rune_offer_price({"instance": {}, "rarity": RuneEngine.RARITY_EPIC})
	rune_shop_ok = rune_shop_ok and price_common < price_rare and price_rare < price_epic \
		and price_common == game._rune_shop_price()
	# ⓑ 흐름 각인 프리미엄 — 같은 희귀도·같은 굴림값이면 흐름 계열이 더 비싸다.
	# ⚠️ Y2: 구판은 "일반 + 비흐름 + **굴림**" 각인을 대조군으로 찾았는데, Y1의 신 15종에는
	#    그런 각인이 **하나도 없다**(일반 6종 = twice·back_one·jump_one 흐름 3 +
	#    strong·wide·rail_fast 확정 3). 그래서 탐침이 빈손이 되어 이 묶음이 영원히 false였다.
	#    가격식은 흐름(×1.25)과 확정(×1.15)을 **곱해서** 얹으므로, 두 항을 갈라 보려면
	#    비교군도 갈라야 한다 — 확정 각인끼리(흐름 여부만 다르게) 재는 대신
	#    **같은 인스턴스에 흐름 항만 붙였다 뗐다** 하는 식으로 항 자체를 확인한다.
	var flow_probe_id := ""
	var plain_probe_id := ""
	for probe_rune_id in RuneEngine.all_rune_ids():
		var probe_def: Dictionary = RuneEngine.RUNES.get(probe_rune_id, {})
		if String(probe_def.get("rarity", "")) != RuneEngine.RARITY_COMMON:
			continue
		if String(probe_def.get("family", "")) == "flow" and flow_probe_id.is_empty():
			flow_probe_id = probe_rune_id
		elif String(probe_def.get("family", "")) != "flow" and plain_probe_id.is_empty():
			plain_probe_id = probe_rune_id
	var flow_premium_ok := not flow_probe_id.is_empty() and not plain_probe_id.is_empty() \
		and GameTuning.RUNE_SHOP_FLOW_PREMIUM > 1.0
	if flow_premium_ok:
		# 흐름 탐침은 **굴림 상단**(p_max)으로 잡는다 — 그러면 굴림 프리미엄이 정확히
		# `ROLL_PREMIUM_MAX`(1.15)가 되어 확정 탐침의 `PASSIVE_PREMIUM`(1.15)과 **같아진다.**
		# 남는 차이는 흐름 할증 하나뿐이라 이 비교가 그 항만 잰다.
		# (p_min으로 잡으면 굴림 하한 0.85가 걸려 흐름 쪽이 더 싸진다 — 항을 못 가른다.)
		var flow_price: int = game._rune_offer_price({"instance": {"id": flow_probe_id,
			"p": float((RuneEngine.RUNES[flow_probe_id] as Dictionary).get("p_max", 1.0))}})
		var plain_price: int = game._rune_offer_price({"instance": {"id": plain_probe_id,
			"p": float((RuneEngine.RUNES[plain_probe_id] as Dictionary).get("p_min", 1.0))}})
		flow_premium_ok = flow_price > plain_price \
			and is_equal_approx(GameTuning.RUNE_SHOP_ROLL_PREMIUM_MAX, GameTuning.RUNE_SHOP_PASSIVE_PREMIUM)
	rune_shop_ok = rune_shop_ok and flow_premium_ok
	if not flow_premium_ok:
		print("RUNE_SHOP_DEBUG flow=%s plain=%s" % [flow_probe_id, plain_probe_id])
	# ⓑ' ★ Y3: **레일 할증**(§2.6 `RUNE_SHOP_RAIL_PREMIUM` 1.20). Y1이 상수를 넣어 뒀지만
	#    소비자가 없었다(handoff-y2 §8-A). 탐침 둘을 **같은 희귀도 · 확정 · 비흐름**으로
	#    잡으면 확정 항·굴림 항·흐름 항이 전부 같아지고 남는 차이가 레일 할증 하나다.
	#    (일반 6종 = 흐름 3 + 확정 3이고 확정 3 중 `rail_fast`만 레일이다.)
	var rail_probe_id := ""
	var slot_probe_id := ""
	for probe_rune_id in RuneEngine.all_rune_ids():
		var probe_def: Dictionary = RuneEngine.RUNES.get(probe_rune_id, {})
		if String(probe_def.get("rarity", "")) != RuneEngine.RARITY_COMMON:
			continue
		if bool(probe_def.get("roll", true)) or String(probe_def.get("family", "")) == "flow":
			continue
		if RuneEngine.rune_scope(probe_rune_id) == "rail":
			if rail_probe_id.is_empty():
				rail_probe_id = probe_rune_id
		elif slot_probe_id.is_empty():
			slot_probe_id = probe_rune_id
	var rail_premium_ok := not rail_probe_id.is_empty() and not slot_probe_id.is_empty() \
		and GameTuning.RUNE_SHOP_RAIL_PREMIUM > 1.0
	if rail_premium_ok:
		rail_premium_ok = game._rune_offer_price({"instance": {"id": rail_probe_id}}) \
			> game._rune_offer_price({"instance": {"id": slot_probe_id}})
	rune_shop_ok = rune_shop_ok and rail_premium_ok
	if not rail_premium_ok:
		print("RUNE_SHOP_DEBUG rail=%s slot=%s" % [rail_probe_id, slot_probe_id])
	# ⓑ'' ★ Y3(피드백 ⑩): **하단 4버튼 → 「닫기」 하나.** 새로고침은 진열대 자리로 올라갔고
	#     합성·칸 배율은 카드상으로 이사했다. 패널이 든 버튼은 진열 3 + 새로고침 + 닫기뿐이다.
	var shop_panel: Node = game.overlay.get_node_or_null("RuneShopPanel") if is_instance_valid(game.overlay) else null
	var shop_button_count := 0
	for shop_child in (shop_panel.get_children() if shop_panel != null else []):
		if shop_child is Button:
			shop_button_count += 1
	rune_shop_ok = rune_shop_ok and shop_panel != null \
		and shop_panel.get_node_or_null("RuneShopClose") != null \
		and shop_panel.get_node_or_null("RuneShopReroll") != null \
		and shop_button_count == game.RUNE_SHOP_OFFER_COUNT + 2
	# ⓒ 진열 3장은 서로 다른 각인이고 값이 붙어 있다.
	var shelf_ids: Dictionary = {}
	for offer_value in game.rune_shop_offers:
		var shelf_offer: Dictionary = offer_value
		var shelf_id := String((shelf_offer.get("instance", {}) as Dictionary).get("id", ""))
		rune_shop_ok = rune_shop_ok and not shelf_id.is_empty() and not shelf_ids.has(shelf_id) \
			and int(shelf_offer.get("price", 0)) > 0
		shelf_ids[shelf_id] = true
	# ⓓ 같은 성 안에서 다시 열면 진열이 **유지된다**(재방문 리롤 파밍 차단 · 카드 상점 규약).
	game._close_base_camp()
	game._show_rune_shop()
	var kept_ok := game.rune_shop_offers.size() == game.RUNE_SHOP_OFFER_COUNT
	for offer_value in game.rune_shop_offers:
		kept_ok = kept_ok and shelf_ids.has(String(((offer_value as Dictionary).get("instance", {}) as Dictionary).get("id", "")))
	rune_shop_ok = rune_shop_ok and kept_ok
	# ⓔ 새로고침 — 골드를 내고 세 장을 다시 굴린다. 굴릴수록 비싸진다.
	var reroll_cost: int = game._rune_shop_reroll_cost()
	var reroll_gold_before: int = game.gold
	game._refresh_rune_shop()
	rune_shop_ok = rune_shop_ok and game.rune_shop_rerolls == 1 \
		and game.gold == reroll_gold_before - reroll_cost \
		and game.rune_shop_offers.size() == game.RUNE_SHOP_OFFER_COUNT \
		and game._rune_shop_reroll_cost() > reroll_cost
	# 세 번 굴리면 희귀 각인 한 개 값을 넘는다("영웅 뜰 때까지 돌리기"가 값으로 막힌다).
	var reroll_three: int = game._scaled_price(GameTuning.RUNE_SHOP_REROLL_BASE) \
		+ game._scaled_price(GameTuning.RUNE_SHOP_REROLL_BASE + GameTuning.RUNE_SHOP_REROLL_STEP) \
		+ game._scaled_price(GameTuning.RUNE_SHOP_REROLL_BASE + GameTuning.RUNE_SHOP_REROLL_STEP * 2)
	rune_shop_ok = rune_shop_ok and reroll_three > price_rare
	# ⓕ 구매 → 기존 2단계("강화할 칸을 고르세요")로 직행. **마왕 조각은 0이다.**
	game.gold = 999
	var rune_price: int = game._rune_shop_price()
	# Y2: 진열에 **레일 각인**이 섞인다. 레일 각인은 칸을 고르지 않으므로(§2.2) 2단계가
	# 아예 없다 — "칸 각인을 산다"를 재려면 칸 각인 진열분을 골라야 한다.
	# ⚠️ Y3이 잡은 잠복 함정: 진열 3장이 **전부 레일 각인**일 수 있다(레일 5종 중 3종을
	#    아직 안 가졌으면 성립한다 · 실측 확률 수 %). 그러면 아래 `buy_index`가 0으로 남아
	#    레일 각인을 사게 되고, 레일은 2단계가 없으므로 `state == "rune_target"`이 깨지면서
	#    **뒤따르는 계약 검사(pact_buy)까지 연쇄로 빨개진다**(각인이 안 붙어 낼 대가가 없다).
	#    시드가 고정이 아니라 이 실패는 몇 판에 한 번만 나타났다 — 칸 각인이 들 때까지
	#    골드 없이 진열만 다시 깐다(`_ensure_rune_shop_offers(true)`는 값을 받지 않는다).
	var buy_index := -1
	for _reshelf in 16:
		for offer_index in game.rune_shop_offers.size():
			var buy_id := String(((game.rune_shop_offers[offer_index] as Dictionary).get("instance", {}) as Dictionary).get("id", ""))
			if RuneEngine.rune_scope(buy_id) == "slot":
				buy_index = offer_index
				break
		if buy_index >= 0:
			break
		game._ensure_rune_shop_offers(true)
	rune_shop_ok = rune_shop_ok and buy_index >= 0
	buy_index = maxi(0, buy_index)
	var buy_price := int((game.rune_shop_offers[buy_index] as Dictionary).get("price", 0))
	var rune_gold_before := game.gold
	var runes_before := game.factory.total_rune_count()
	var rune_shop_shards_before: int = game.demon_lord.rune_shards
	game._buy_rune_shop_offer(buy_index)
	rune_shop_ok = rune_shop_ok and game.state == "rune_target" \
		and game.gold == rune_gold_before - buy_price \
		and game.draft_offers.size() == 1 \
		and game.rune_shop_offers.size() == game.RUNE_SHOP_OFFER_COUNT - 1
	game._attach_draft_rune(0)
	# 2단계가 끝나면 성 내부로 돌아와야 한다(draft_return_state = "castle_interior").
	rune_shop_ok = rune_shop_ok and game.state == "castle_interior" \
		and game.factory.total_rune_count() == runes_before + 1 \
		and game.rune_shop_purchases == 1 \
		and game.demon_lord.rune_shards == rune_shop_shards_before
	# 두 번째 구매는 값이 오른다(무한 각인 방지 · 구 `70 + 30n`의 후신).
	rune_shop_ok = rune_shop_ok and game._rune_shop_price() > rune_price

	# --- 각인 세공사 ③ 칸 배율(회귀) ----------------------------------------
	game.gold = 999
	game.state = "camp"
	game._buy_factory_upgrade("repeat", 95)
	game._factory_lane_pressed(0, 0)
	var mage_ok: bool = int(game.factory.slots[0].get("repeat", 1)) == 2 and game.state == "castle_interior"
	# 폐기된 강화(split)를 억지로 사도 골드가 나가지 않아야 한다.
	game.state = "camp"
	var split_gold := game.gold
	game._buy_factory_upgrade("split", 120)
	mage_ok = mage_ok and game.state == "camp" and game.gold == split_gold and not game.factory.can_apply_upgrade("split")
	# 적용할 칸이 남지 않으면 구매 자체가 막혀야 한다(소프트락 방지).
	var mage_gate_ok: bool = game.factory.can_apply_upgrade("repeat")
	for slot_index in game.factory.slots.size():
		game.factory.upgrade_slot(slot_index, "repeat")
	mage_gate_ok = mage_gate_ok and not game.factory.can_apply_upgrade("repeat")
	game.state = "camp"
	var mage_gate_gold := game.gold
	game._buy_factory_upgrade("repeat", 95)
	mage_gate_ok = mage_gate_ok and game.gold == mage_gate_gold and game.state == "camp"
	# 정상 구매 뒤 ESC 취소는 지불한 골드를 그대로 돌려줘야 한다.
	var refund_gold := game.gold
	game._buy_factory_upgrade("duration", 72)
	var refund_ok: bool = game.state == "factory_upgrade" and game.gold == refund_gold - 72
	game._cancel_factory_upgrade()
	refund_ok = refund_ok and game.gold == refund_gold and game.state == "castle_interior"

	# --- v1 잔존 NPC 경로 회귀 (망각의 사제 / 운명의 직조사) -----------------
	game.gold = 500
	game.factory.add_inventory(DealCardLibrary.instance("cleave", 2))
	var remove_before := game.factory.inventory.size()
	var remove_rejections := game.rejected_skills.size()
	game.state = "camp"
	game._use_service("skill_remove")
	var npc_remove_ok: bool = game.factory.inventory.size() == remove_before - 1 and game.rejected_skills.size() == remove_rejections + 1
	npc_remove_ok = npc_remove_ok and String(game.rejected_skills[game.rejected_skills.size() - 1]) == "cleave" and game.factory.get_rank_count("cleave", 2) == 0
	game.factory.add_inventory(DealCardLibrary.instance("thunder", 3))
	var swap_before := game.factory.inventory.size()
	game.state = "camp"
	game._use_service("skill_swap")
	var npc_swap_ok: bool = game.factory.inventory.size() == swap_before and String(game.rejected_skills[game.rejected_skills.size() - 1]) == "thunder"
	npc_swap_ok = npc_swap_ok and int(game.factory.inventory[game.factory.inventory.size() - 1].get("rank", 0)) == 3
	# 교체 카드도 드래프트 풀 안에서만 나와야 한다(legacy 금지).
	npc_swap_ok = npc_swap_ok and draft_ids.has(String(game.factory.inventory[game.factory.inventory.size() - 1].get("id", "")))
	if game.state == "camp":
		game._close_base_camp()

	# --- 계약자 ① 정비 · 체류를 되산다 (V5: 일수 매매 → dwell 매매 · 설계 §6.5) ----
	game.gold = 999
	# dwell 0에서는 되살 게 없다 — 게이트가 실제로 막는지 먼저 본다.
	game.clock.set_dwell_raw(0)
	var pact_sell_ok: bool = not game.pact_available("sell_day")
	game.clock.set_dwell_raw(3)
	game.state = "camp"
	var sell_dwell_before := game.clock.dwell
	var sell_gold_before := game.gold
	var respite_cost := game.pact_respite_cost()
	pact_sell_ok = pact_sell_ok and game.pact_available("sell_day") \
		and respite_cost == GameTuning.PACT_RESPITE_COST_BASE
	game._pact_sell_day()
	pact_sell_ok = pact_sell_ok and game.clock.dwell == sell_dwell_before + GameTuning.PACT_RESPITE_DWELL \
		and game.gold == sell_gold_before - respite_cost \
		and game.state == "castle_interior" and game.pact_uses_left("sell_day") == game.PACT_LIMIT - 1
	# 두 번째 정비는 더 비싸다(120 + 60 × 사용횟수).
	pact_sell_ok = pact_sell_ok and game.pact_respite_cost() == GameTuning.PACT_RESPITE_COST_BASE + GameTuning.PACT_RESPITE_COST_STEP

	# --- 계약자 ② 탐욕 · 체류를 판다 ------------------------------------------
	game.factory.add_inventory(DealCardLibrary.instance("rapid_slash", 1))
	game.state = "camp"
	var buy_dwell_before := game.clock.dwell
	var buy_gold_before := game.gold
	var buy_runes_before := game.factory.total_rune_count()
	var buy_rejected_before := game.rejected_skills.size()
	var pact_buy_ok: bool = game.pact_available("buy_day") and buy_runes_before > 0
	game._pact_buy_day()
	pact_buy_ok = pact_buy_ok and game.clock.dwell == buy_dwell_before + GameTuning.PACT_GREED_DWELL \
		and game.gold == buy_gold_before + GameTuning.PACT_GREED_GOLD \
		and game.factory.total_rune_count() == buy_runes_before - 1 \
		and game.rejected_skills.size() == buy_rejected_before + 1 \
		and game.pact_uses_left("buy_day") == game.PACT_LIMIT - 1

	# --- 계약자 ③ 런당 2회 제한 ---------------------------------------------
	var pact_limit_ok := true
	game.pact_uses["mortgage"] = game.PACT_LIMIT
	pact_limit_ok = pact_limit_ok and not game.pact_available("mortgage")
	game.pact_uses["mortgage"] = 0
	# "미래를 담보로" — 마왕 각인 +2 확정 + 영웅 각인 1개 확정 지급.
	game.state = "camp"
	# V3-J: 대가가 "마왕 각인 +2"에서 **체류 +2**로 바뀌었다.
	var mortgage_dwell := game.clock.dwell
	game._pact_mortgage()
	pact_limit_ok = pact_limit_ok and game.clock.dwell == mortgage_dwell + GameTuning.PACT_HERO_RUNE_DWELL \
		and game.state == "rune_draft" and game.draft_offers.size() == 1
	for offer: Dictionary in game.draft_offers:
		var rune_id := String((offer["instance"] as Dictionary).get("id", ""))
		pact_limit_ok = pact_limit_ok and String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("rarity", "")) == RuneEngine.RARITY_EPIC
	game._select_draft_rune(0)
	game._attach_draft_rune(0)
	if game.state == "camp":
		game._close_base_camp()

	# --- 계약자 ④ 대가를 낼 수 없으면 탐욕은 열리지 않는다 ---------------------
	# 압박을 파는 거래가 **공짜 수익원**이 되면 안 된다(V8 점검 3번 규칙).
	for slot_index in game.factory.slots.size():
		while game.factory.rune_count_on(slot_index) > 0:
			game.factory.detach_rune(slot_index, 0)
	game.pact_uses["buy_day"] = 0
	pact_buy_ok = pact_buy_ok and game.factory.total_rune_count() == 0 \
		and game._first_slot_with_rune() < 0 and not game.pact_available("buy_day")

	# --- 밀정 (Y3 리뉴얼 · 설계 §8 ⑪) ----------------------------------------
	# 구 검사는 "각인 1개를 85 G에 지운다 + 열람을 35 G에 산다"였다. Y3에서 열람은
	# **무료·기본 공개**가 됐고 지우기는 **칸 하나 통째 · 스테이지당 1회**가 됐다.
	# ⚠️ 마왕 각인은 `floor(성장 점수 / BOSS_CARDS_PER_RUNE)`이다. 카드 6장이면 각인이
	#    **1개**뿐이라 "한 칸을 비웠더니 마왕의 각인이 0개가 됐다"가 되어 ⓕ(다음 스테이지에
	#    다시 열린다)를 잴 수 없다. 여러 칸에 흩어질 만큼 먹여 둔다.
	game.gold = 999
	game.rejected_skills.assign(["cleave", "cleave", "rapid_slash", "thunder", "meteor_blade",
		"moon_barrier", "execution", "gravity_well", "time_cut", "whirlwind", "thrust", "aura",
		"cross_cut", "blade_fan", "holy_pulse", "sword_rain", "frost_ring", "dash_blade",
		"lion_roar", "targeting", "recursion", "shield_bash", "battle_trance", "boomerang_blade"])
	game.demon_lord.sync_runes(game.rng)
	game.clock.set_stage_raw(1)
	game.spy_wipe_stage = 0
	game.state = "camp"
	var spy_runes_before := game.demon_lord.rune_count()
	var spy_remove_ok: bool = spy_runes_before >= 3
	# ⓐ **여는 데 돈이 들지 않는다.** 골드가 한 톨도 안 나가야 한다.
	var spy_open_gold := game.gold
	game._show_spy_service()
	spy_remove_ok = spy_remove_ok and game.gold == spy_open_gold
	# ⓑ 5칸이 유저 딜싸이클과 **같은 렌더러**(`_build_preview_slot`)로 그려지고,
	#    각인 이름이 **처음부터** 보인다 — 「안 보임」 잠금 문구가 화면 어디에도 없다.
	#    ⚠️ YZ 한글 스윕에서 이 문구가 「미열람」 → 「안 보임」으로 갈렸다. 두 문자열을
	#       **둘 다** 금지어로 둔다 — 옛 낱말이 되살아나도 이 검사가 잡는다.
	var spy_panel: Node = game.overlay.get_node_or_null("SpyPanel") if is_instance_valid(game.overlay) else null
	var spy_slot_cells := 0
	var spy_locked_text := false
	var spy_probe: Array[Node] = []
	if spy_panel != null:
		spy_probe.append(spy_panel)
	while not spy_probe.is_empty():
		var spy_node: Node = spy_probe.pop_back()
		for spy_child in spy_node.get_children():
			spy_probe.append(spy_child)
		if spy_node is Panel and String(spy_node.name).begins_with("PreviewSlot"):
			spy_slot_cells += 1
		if spy_node is Label and ("미열람" in (spy_node as Label).text or "안 보임" in (spy_node as Label).text):
			spy_locked_text = true
	spy_remove_ok = spy_remove_ok and spy_slot_cells == FactoryDeck.SLOT_COUNT and not spy_locked_text
	# ⓒ 상단에 마왕 초상이 붙었다(YA 산출물 `portrait-demon-lord-96.png`).
	spy_remove_ok = spy_remove_ok and spy_panel != null and spy_panel.get_node_or_null("SpyPortrait") != null
	# ⓓ 칸 하나를 **통째로** 지운다 — 정확히 한 칸이 0이 되고 나머지 칸은 안 움직인다.
	var spy_before_counts: Array[int] = []
	for spy_slot in FactoryDeck.SLOT_COUNT:
		spy_before_counts.append(game.demon_lord.rune_count_on_slot(spy_slot))
	var spy_stripped_before := game.demon_lord.stripped_runes.size()
	var spy_gold_before := game.gold
	game.state = "camp"
	game._spy_wipe_slot()
	var spy_emptied := 0
	var spy_untouched := true
	for spy_slot in FactoryDeck.SLOT_COUNT:
		var spy_now := game.demon_lord.rune_count_on_slot(spy_slot)
		if spy_before_counts[spy_slot] > 0 and spy_now == 0:
			spy_emptied += 1
		elif spy_now != spy_before_counts[spy_slot]:
			spy_untouched = false
	var spy_wiped_count := spy_runes_before - game.demon_lord.rune_count()
	spy_remove_ok = spy_remove_ok and spy_emptied == 1 and spy_untouched and spy_wiped_count > 0 \
		and game.demon_lord.stripped_runes.size() == spy_stripped_before + spy_wiped_count \
		and game.gold == spy_gold_before - game.spy_wipe_cost()
	# ⓔ **스테이지당 1회.** 두 번째 호출은 각인도 골드도 건드리지 않는다.
	var spy_locked_gold := game.gold
	var spy_locked_runes := game.demon_lord.rune_count()
	spy_remove_ok = spy_remove_ok and game.spy_wipe_stage == game.clock.stage \
		and not game.spy_wipe_available()
	game.state = "camp"
	game._spy_wipe_slot()
	spy_remove_ok = spy_remove_ok and game.gold == spy_locked_gold \
		and game.demon_lord.rune_count() == spy_locked_runes
	# ⓕ 스테이지가 넘어가면 다시 열린다(값이 "마지막으로 쓴 스테이지"라는 계약).
	game.clock.set_stage_raw(2)
	spy_remove_ok = spy_remove_ok and game.spy_wipe_available()
	game.clock.set_stage_raw(1)
	if not spy_remove_ok:
		print("SPY_DEBUG runes_before=%d cells=%d locked_text=%s portrait=%s emptied=%d untouched=%s wiped=%d stage=%d avail=%s" % [
			spy_runes_before, spy_slot_cells, spy_locked_text,
			spy_panel != null and spy_panel.get_node_or_null("SpyPortrait") != null,
			spy_emptied, spy_untouched, spy_wiped_count, game.spy_wipe_stage, game.spy_wipe_available()])
	if game.state == "camp":
		game._close_base_camp()

	# =========================================================================
	# V8: v3 경제 정합 — 상점가 스테이지 스케일 (설계 §8 "가격만 스테이지 스케일")
	# =========================================================================
	# 1스테이지는 **v2와 완전히 같은 값**이어야 한다(위 rune_shop 단언이 그 값을 쓴다).
	game.clock.set_stage_raw(1)
	var price_stage1 := game._rune_shop_price()
	var price_ok: bool = is_equal_approx(game.stage_price_scale(), 1.0) \
		and game.spy_wipe_cost() == game.SPY_WIPE_COST
	game.clock.set_stage_raw(GameTuning.STAGE_COUNT)
	price_ok = price_ok and game._rune_shop_price() > price_stage1 \
		and game.spy_wipe_cost() > game.SPY_WIPE_COST \
		and is_equal_approx(game.stage_price_scale(), 1.0 + GameTuning.STAGE_PRICE_STEP * float(GameTuning.STAGE_COUNT - 1))
	# 스테이지가 오를수록 단조 증가한다(중간에 꺾이지 않는다).
	var previous_price := 0
	for stage_probe in range(1, GameTuning.STAGE_COUNT + 1):
		game.clock.set_stage_raw(stage_probe)
		var probe_price := game._rune_shop_price()
		price_ok = price_ok and probe_price >= previous_price
		previous_price = probe_price
	# 계약(§6.5 V3-J)에는 스케일이 걸리지 않는다 — 정비 비용식은 사용 횟수만 본다.
	game.clock.set_stage_raw(1)
	var respite_stage1 := game.pact_respite_cost()
	game.clock.set_stage_raw(GameTuning.STAGE_COUNT)
	price_ok = price_ok and game.pact_respite_cost() == respite_stage1
	game.clock.set_stage_raw(1)

	# =========================================================================
	# V8: 보스 트로피 2택1 — v2 "1차/2차 각성" 단언의 자리 (설계 §5.5)
	# =========================================================================
	# 계보 3종 택1도, 3·6일차 시간 게이트도 없다. 성장 이정표는 **보스 격파**뿐이다.
	# 여기서는 격파 훅(`pending_stage_trophy`)만 손으로 채우고 그 뒤의 흐름 전체를 본다
	# (실제 격파 → 훅 채움은 `--boss-test`의 defeat / demon_direct 묶음이 단언한다).
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"
	game.player.restore_trophies([])
	var trophy_stage := 1
	var trophy_design := TrophyLibrary.for_stage(trophy_stage)
	var trophy_effect: Dictionary = trophy_design.get("effect", {})
	var health_before := game.player.max_health
	var shield_before := game.player.shield_capacity
	var trophy_boss_cards_before := game.trophy_reject_skills.size()
	var trophy_rejected_before := game.rejected_skills.size()
	game.pending_stage_trophy = {
		"stage": trophy_stage, "design": "A", "enhanced": false, "descended": false,
		"day": game.clock.day_number, "dwell": game.clock.dwell
	}
	game.pending_trophy_followup = ""
	game._open_stage_trophy_choice()
	for _frame in 6:
		await get_tree().process_frame
	# ① 고정 중립 스탯 보너스는 **선택지가 아니다** — 모달이 열리는 순간 이미 붙어 있다.
	var trophy_flow_ok: bool = game.player.trophy_stages.size() == 1 \
		and game.player.trophy_stages.has(trophy_stage) \
		and game.player.trophy_count == 1 \
		and game.player.last_trophy_id == String(trophy_design.get("id", "")) \
		and absf(game.player.max_health - (health_before + float(trophy_effect.get("health", 0.0)))) < 0.01 \
		and game.player.shield_capacity == shield_before + int(trophy_effect.get("shield", 0))
	# ② 2택1이 자동 확정되고 5칸 배치 화면이 열린다(automated_test 규약 · v2 각성과 동일).
	var expected_choices := TrophyLibrary.choices_for(trophy_stage)
	trophy_flow_ok = trophy_flow_ok and game.state == "factory_place" and game.trophy_place_pending \
		and game.player.class_skill_id == String(expected_choices[0])
	# ③ **버린 한 장은 마왕에게** — 기존 전달 경로(rejected_skills + trophy_reject_skills)
	trophy_flow_ok = trophy_flow_ok and game.rejected_skills.size() == trophy_rejected_before + 1 \
		and String(game.rejected_skills[game.rejected_skills.size() - 1]) == String(expected_choices[1]) \
		and game.trophy_reject_skills.size() == trophy_boss_cards_before + 1 \
		and String((game.trophy_reject_skills[game.trophy_reject_skills.size() - 1] as Dictionary).get("branch", "")) == String(trophy_design.get("id", "")) \
		and int((game.trophy_reject_skills[game.trophy_reject_skills.size() - 1] as Dictionary).get("tier", -1)) == trophy_stage
	# ④ 5칸 배치 → 필드 복귀 → 훅 소멸
	game._factory_lane_pressed(4, 0)
	for _frame in 6:
		await get_tree().process_frame
	trophy_flow_ok = trophy_flow_ok and String(game.factory.get_card(4).get("id", "")) == String(expected_choices[0]) \
		and game.state == "playing" and game.pending_stage_trophy.is_empty() \
		and game.pending_trophy.is_empty() and not game.trophy_place_pending
	# ⑤ 같은 스테이지 트로피를 두 번 줘도 효과가 두 번 붙지 않는다.
	var double_health := game.player.max_health
	game.player.apply_trophy(trophy_design)
	trophy_flow_ok = trophy_flow_ok and game.player.trophy_stages.size() == 1 \
		and is_equal_approx(game.player.max_health, double_health)

	# --- 트로피 5회 누적 (설계 §5.5 "5회 × 2장 = 10장") ------------------------
	game.player.restore_trophies([])
	var bare_health := game.player.max_health
	var bare_damage := game.player.damage
	var all_stages: Array[int] = []
	for stage_index in range(1, TrophyLibrary.TROPHY_COUNT + 1):
		all_stages.append(stage_index)
	game.player.restore_trophies(all_stages)
	var merged := TrophyLibrary.merge_effects(all_stages)
	var trophy_stack_ok: bool = game.player.trophy_stages.size() == TrophyLibrary.TROPHY_COUNT \
		and game.player.trophy_count == TrophyLibrary.TROPHY_COUNT \
		and game.player.last_trophy_id == String(TrophyLibrary.for_stage(TrophyLibrary.TROPHY_COUNT).get("id", "")) \
		and absf(game.player.max_health - (bare_health + float(merged.get("health", 0.0)))) < 0.01 \
		and game.player.damage > bare_damage \
		and game.trophy_effect_summary().size() == merged.size()
	# 배분표 정합: 10장이 쓰이고 예비 2장을 더하면 SPECIALS 12종 전량, 중복 0.
	trophy_stack_ok = trophy_stack_ok and TrophyLibrary.table_ok() \
		and TrophyLibrary.used_card_ids().size() == TrophyLibrary.TROPHY_COUNT * TrophyLibrary.CHOICES_PER_TROPHY \
		and TrophyLibrary.all_card_ids().size() == 12
	# 선택지 2장은 **언제나 서로 다른 원소**여야 한다(§5.5 "어느 쪽이 세냐"가 아니게).
	for stage_index in range(1, TrophyLibrary.TROPHY_COUNT + 1):
		var pair := TrophyLibrary.choices_for(stage_index)
		var element_a := String(DealCardLibrary.by_id(String(pair[0])).get("element", "a"))
		var element_b := String(DealCardLibrary.by_id(String(pair[1])).get("element", "b"))
		trophy_stack_ok = trophy_stack_ok and element_a != element_b
	game.player.restore_trophies([trophy_stage])

	# --- 예비 카드 치환: 이미 가진 카드가 뜨면 2택1이 1택이 된다 ---------------
	var stage2_choices := TrophyLibrary.choices_for(2)
	game.factory.add_inventory(DealCardLibrary.instance(String(stage2_choices[0]), 1))
	var resolved := game._resolve_trophy_choices(2)
	var trophy_reserve_ok: bool = resolved.size() == TrophyLibrary.CHOICES_PER_TROPHY \
		and game._owns_card_id(String(stage2_choices[0])) \
		and resolved[0] != String(stage2_choices[0]) \
		and TrophyLibrary.RESERVE_CHOICES.has(String(resolved[0])) \
		and String(resolved[1]) == String(stage2_choices[1])
	# 아무것도 가지지 않은 스테이지는 배분표 그대로 나온다.
	var stage3_resolved := game._resolve_trophy_choices(3)
	var stage3_choices := TrophyLibrary.choices_for(3)
	trophy_reserve_ok = trophy_reserve_ok and String(stage3_resolved[0]) == String(stage3_choices[0]) \
		and String(stage3_resolved[1]) == String(stage3_choices[1])

	print("CASTLE_TEST_COMPLETE castle_npcs=%s shop=%s refresh=%s shop_equip=%s fusion=%s rune_shop=%s mage=%s mage_gate=%s upgrade_refund=%s npc_remove=%s npc_swap=%s pact_sell_day=%s pact_buy_day=%s pact_limit=%s spy_remove=%s price_scale=%s trophy_flow=%s trophy_stack=%s trophy_reserve=%s trophy=%s stage5_price=%d" % [
		castle_npcs_ok, shop_ok, refresh_ok, shop_equip_ok, fusion_ok, rune_shop_ok, mage_ok, mage_gate_ok,
		refund_ok, npc_remove_ok, npc_swap_ok, pact_sell_ok, pact_buy_ok, pact_limit_ok, spy_remove_ok,
		price_ok, trophy_flow_ok, trophy_stack_ok, trophy_reserve_ok,
		game.player.last_trophy_id, previous_price])
	var castle_passed := castle_npcs_ok and shop_ok and refresh_ok and shop_equip_ok and fusion_ok \
		and rune_shop_ok and mage_ok and mage_gate_ok and refund_ok and npc_remove_ok and npc_swap_ok \
		and pact_sell_ok and pact_buy_ok and pact_limit_ok and spy_remove_ok and price_ok \
		and trophy_flow_ok and trophy_stack_ok and trophy_reserve_ok
	await _quit_test_cleanly(castle_passed)

# =============================================================================
# --rift-test (W9 신설) — 균열 E2E: 스폰 → 정예 웨이브 → 클리어 → 보상
# =============================================================================
# `--world-test`가 배치(거리·바닥·결정성)를, `rift_probe.gd`가 예산·중첩을 본다.
# 이 테스트는 그 위에서 **게임 루프가 실제로 돌아가는가**만 본다.
func _run_rift_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.25).timeout
	# ---- ① 스테이지 개시에 균열 예산이 초기화된다 (V5: 런당 3 → 스테이지당 2) --
	var begin_ok: bool = game.world.rift_budget_remaining() == GameTuning.RIFT_STAGE_BUDGET \
		and game.world.RIFT_MAX_PER_RUN == GameTuning.RIFT_STAGE_BUDGET \
		and game.world.get_rifts().is_empty() and game.rift_states.is_empty()
	# Y6(§9.4 "이벤트 예산과 충돌 확인"): 필드 사건은 **다른 예산**이다.
	# 사건이 배치돼도 균열 예산이 한 칸도 줄지 않아야 한다.
	game._maintain_event_schedule()
	var event_budget_ok: bool = game.world.rift_budget_remaining() == GameTuning.RIFT_STAGE_BUDGET \
		and not game.stage_events.is_empty() \
		and game.stage_events.size() <= game.EVENT_STAGE_MAX
	# ---- ② dwell 1·3에서만 열린다 (v2 2·4·6일차 → V5 재키잉 §2.4) -------------
	var schedule_ok: bool = game.rifts_due(0) == 0 and game.rifts_due(1) == 1 \
		and game.rifts_due(2) == 1 and game.rifts_due(3) == 2 \
		and game.rifts_due(4) == 2 and game.rifts_due(99) == GameTuning.RIFT_STAGE_BUDGET
	schedule_ok = schedule_ok and GameTuning.RIFT_RUN_BUDGET == GameTuning.STAGE_COUNT * GameTuning.RIFT_STAGE_BUDGET
	# 실제 게임 경로로 주기 하나를 돌린다(낮→밤→낮). dwell 1에서 균열 1개가 열려야 한다.
	game.clock.set_night_raw(false)
	game.clock.set_phase_elapsed_raw(0.0)
	game._toggle_day_night()
	await get_tree().create_timer(0.05).timeout
	game._toggle_day_night()
	await get_tree().create_timer(0.15).timeout
	var spawn_ok: bool = game.clock.dwell == 1 and game.world.get_rifts().size() == 1 \
		and game.world.rift_budget_remaining() == GameTuning.RIFT_STAGE_BUDGET - 1
	var rift: Dictionary = game.world.get_active_rift()
	spawn_ok = spawn_ok and not rift.is_empty()
	var rift_id := String(rift.get("id", ""))
	spawn_ok = spawn_ok and rift_id.begins_with(game.RIFT_CAMP_PREFIX) and game.rift_states.has(rift_id)
	# 균열 바닥은 항상 걸어 들어갈 수 있어야 한다.
	spawn_ok = spawn_ok and game.world.is_walkable(rift["position"])
	var rift_distance: float = float(rift.get("distance", 0.0))
	spawn_ok = spawn_ok and rift_distance >= GameTuning.RIFT_RING_MIN and rift_distance <= GameTuning.RIFT_RING_MAX

	# Y6: 균열이 선 뒤에도 사건 자리가 균열과 겹치지 않는다(자리 예산은 서로 독립이지만
	# **좌표는 서로를 피해야** 한다 — 겹치면 두 아레나가 한 화면에서 포개진다).
	for event_value: Dictionary in game.stage_events:
		var event_at: Vector2 = event_value.get("position", Vector2.ZERO)
		event_budget_ok = event_budget_ok and game.world.is_walkable(event_at)
		for live_rift: Dictionary in game.world.get_rifts():
			event_budget_ok = event_budget_ok and event_at.distance_to(
				live_rift.get("position", Vector2.ZERO)) >= game.EVENT_CLEARANCE
	# Y7: 위 줄은 **겹치는 자리가 실제로 뽑혔을 때만** 판별력이 있다(시간 시드라
	# 18회에 한 번쯤 뽑힌다 — Y7이 `run_all`에서 실측했다). 그래서 **일부러 겹쳐** 놓고
	# 밀어내기가 도는지 직접 잰다. 사건은 놓일 때 균열을 피하지만 **균열은 사건을
	# 안 피하므로**, 나중에 열린 균열이 사건 위에 앉는 경우가 이 경로다.
	if not game.stage_events.is_empty():
		var victim: Dictionary = game.stage_events[0]
		var rift_at: Vector2 = rift.get("position", Vector2.ZERO)
		victim["position"] = rift_at + Vector2(20.0, 0.0)
		victim["state"] = "ready"
		game._displace_events_from_rift(rift)
		var pushed: Vector2 = victim.get("position", Vector2.ZERO)
		event_budget_ok = event_budget_ok \
			and pushed.distance_to(rift_at) >= float(rift.get("radius", 150.0)) + game.EVENT_CLEARANCE \
			and game.world.is_walkable(pushed)
		# 진행 중인 사건은 **안 옮긴다**(플레이어가 그 안에서 싸우는 중이다).
		victim["position"] = rift_at + Vector2(20.0, 0.0)
		victim["state"] = "active"
		game._displace_events_from_rift(rift)
		event_budget_ok = event_budget_ok \
			and (victim.get("position", Vector2.ZERO) as Vector2).distance_to(rift_at) < 30.0
		victim["position"] = pushed
		victim["state"] = "ready"
	# ---- ③ 접근하면 정예 웨이브가 스폰된다 ---------------------------------
	game.player.invulnerability = 999.0
	game.player.global_position = rift["position"] + Vector2(0.0, -200.0)
	game._check_rifts()
	await get_tree().create_timer(0.15).timeout
	var elites: Array[Node] = []
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy) and String(enemy.camp_id) == rift_id:
			elites.append(enemy)
	var wave_ok: bool = elites.size() >= game.RIFT_ELITE_MIN and elites.size() <= game.RIFT_ELITE_MAX \
		and int(game.rift_states[rift_id].get("remaining", 0)) == elites.size() \
		and bool(game.rift_states[rift_id].get("activated", false))
	for elite: Node in elites:
		wave_ok = wave_ok and bool(elite.is_camp_elite)
	# 두 번 접근해도 웨이브가 겹쳐 스폰되지 않는다.
	game._check_rifts()
	var second_wave := 0
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy) and String(enemy.camp_id) == rift_id:
			second_wave += 1
	wave_ok = wave_ok and second_wave == elites.size()

	# ---- ④ 전멸시키면 클리어 + 보상(각인 3택1 + 골드 + 체력 전회복) --------
	game.player.invulnerability = 0.0
	game.player.shield_charges = 0
	game.player.take_damage(game.player.max_health * 0.5, game.player.global_position + Vector2(300.0, 0.0))
	await get_tree().process_frame
	var health_before := game.player.health
	game.player.invulnerability = 999.0
	var gold_before := game.gold
	for elite: Node in elites:
		if not is_instance_valid(elite):
			continue
		while elite.active_modules.has("rollback"):
			elite.active_modules.erase("rollback")
		elite.take_damage(999999.0, game.player.global_position)
	await get_tree().create_timer(0.3).timeout
	var clear_ok: bool = bool(game.rift_states[rift_id].get("cleared", false)) \
		and bool(game.world.get_rift(rift_id).get("cleared", false))
	var reward_ok: bool = game.gold >= gold_before + game.RIFT_REWARD_GOLD \
		and game.player.health > health_before \
		and is_equal_approx(game.player.health, game.player.max_health) \
		and game.state == "rune_draft" and game.draft_offers.size() == game.RUNE_DRAFT_OPTIONS
	# Y2: 3택에 **레일 각인**이 섞인다. 레일 각인은 칸을 고르지 않고 바로 붙으므로
	# (§2.2) `_attach_draft_rune`이 없는 경로다 — 어느 쪽이든 "각인 1개를 얻었다"를 잰다.
	var runes_before := game.factory.total_rune_count()
	var rail_before := game.factory.rail_rune_count()
	var reward_scope := RuneEngine.rune_scope(String(((game.draft_offers[0] as Dictionary).get("instance", {}) as Dictionary).get("id", "")))
	game._select_draft_rune(0)
	if reward_scope == "rail":
		reward_ok = reward_ok and game.state == "playing" \
			and game.factory.rail_rune_count() == rail_before + 1 \
			and game.factory.total_rune_count() == runes_before
	else:
		reward_ok = reward_ok and game.state == "rune_target"
		game._attach_draft_rune(0)
		reward_ok = reward_ok and game.state == "playing" \
			and game.factory.total_rune_count() == runes_before + 1

	# ---- ⑤ 클리어한 균열은 다시 활성화되지 않는다 --------------------------
	game._check_rifts()
	var reactivate := 0
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy) and String(enemy.camp_id) == rift_id:
			reactivate += 1
	var reclear_ok: bool = reactivate == 0

	# ---- ⑥ 스테이지 예산 2개를 넘어서 열리지 않는다 ------------------------
	game.clock.set_dwell_raw(40)
	game._maintain_rift_schedule()
	var budget_ok: bool = game.world.get_rifts().size() <= GameTuning.RIFT_STAGE_BUDGET \
		and game.world.rift_budget_remaining() >= 0 \
		and game.rifts_due() == GameTuning.RIFT_STAGE_BUDGET

	# ---- ⑦ 스테이지를 넘기면 예산이 **다시 채워지고** 균열은 사라진다 --------
	# 런 최대 10개(= 5스테이지 × 2)라는 v3 계약의 유일한 관측점이다(§2.4).
	# dwell을 0으로 내려 두고 넘긴다 — 이월 dwell이 남아 있으면 새 스테이지가
	# **개시 즉시** 밀린 균열을 따라잡아 열기 때문에(정상 동작) "비었다"를 볼 수 없다.
	var rifts_before_stage := game.world.get_rifts().size()
	game.clock.set_dwell_raw(0)
	game.advance_stage()
	await get_tree().create_timer(0.2).timeout
	var stage_reset_ok: bool = game.clock.stage == 2 \
		and game.world.get_rifts().is_empty() and rifts_before_stage > 0 \
		and game.world.rift_budget_remaining() == GameTuning.RIFT_STAGE_BUDGET \
		and game.rift_states.is_empty()
	# 이월 dwell이 있으면 반대로 **즉시** 따라잡아야 한다(같은 스케줄러, 반대 방향 단언).
	game.clock.set_dwell_raw(GameTuning.RIFT_DWELL_SCHEDULE[1])
	game._maintain_rift_schedule()
	stage_reset_ok = stage_reset_ok and game.world.get_rifts().size() == GameTuning.RIFT_STAGE_BUDGET

	# ---- ⑧ 시련 캠프는 완전히 꺼져 있어야 한다 ------------------------------
	var camps_off_ok: bool = game.world.get_trial_camps().is_empty() and game.camp_states.is_empty()

	print("RIFT_TEST_COMPLETE begin=%s schedule=%s spawn=%s wave=%s clear=%s reward=%s reclear=%s budget=%s stage_reset=%s camps_off=%s event_budget=%s elites=%d rifts=%d events=%d distance=%d run_budget=%d" % [
		begin_ok, schedule_ok, spawn_ok, wave_ok, clear_ok, reward_ok, reclear_ok, budget_ok, stage_reset_ok, camps_off_ok,
		event_budget_ok, elites.size(), game.world.get_rifts().size(), game.stage_events.size(),
		int(rift_distance), GameTuning.RIFT_RUN_BUDGET])
	var rift_passed := begin_ok and schedule_ok and spawn_ok and wave_ok and clear_ok \
		and reward_ok and reclear_ok and budget_ok and stage_reset_ok and camps_off_ok \
		and event_budget_ok
	await _quit_test_cleanly(rift_passed)

func _run_stress_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.cycle_number = 5
	game.player.invulnerability = 999.0
	for _rank in 3:
		game.player.apply_skill("flame_field")
		game.player.apply_skill("aura")
		game.player.apply_skill("guardian_blade")
	for index in 112:
		var angle := TAU * float(index) / 112.0
		var ring := 330.0 + float(index % 7) * 58.0
		var spawn_position := game.player.global_position + Vector2.from_angle(angle) * ring
		if not game.world.is_walkable(spawn_position):
			spawn_position = game.world.find_walkable_near(game.player.global_position, game.rng, 320.0, 760.0)
		game.combat.spawn_enemy_instance(spawn_position)
	for index in 135:
		game.spawn_burst(game.player.global_position + Vector2(index % 9, index % 7), GamePalette.CYAN, 8, 90.0, 0.55)
	for index in 100:
		game.combat.spawn_or_merge_xp_orb(game.player.global_position + Vector2(index * 2.0, 160.0), 1)
	game.combat.rebuild_enemy_spatial()
	# =========================================================================
	# V6: **상태이상 활성 조건**으로 강화한다 (설계 §4.7 성능 4규칙)
	# =========================================================================
	# v2의 소크는 "많이 스폰하고 4초 방치"였다. 그 조건에서는 상태 틱이 0이라
	# §4.7이 걱정한 비용(78기 × 도트 + 반응 예산 + 킬 체인)이 한 번도 측정되지 않는다.
	# 그래서 4초 내내 **전 개체에 독+연을 유지**하고(연 지속이 2초라 0.5초마다 재부여),
	# 그 위에 기름 무리를 화염 광역으로 때려 **대폭 연소 반응까지** 부하에 넣는다.
	#
	# 체력을 400으로 올린 이유: 4초 도트(≈13)와 화염 펄스로 마물이 다 죽어 버리면
	# 측정되는 것이 "상태 틱 비용"이 아니라 "스폰·사망 처리 비용"이 된다. 킬 체인
	# 가드는 위 `--combat-test` ④⑤가 따로 본다.
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy):
			enemy.max_health = 400.0
			enemy.health = 400.0
			enemy.displayed_health = 400.0
			enemy.trailing_health = 400.0
	# 3구간을 **같은 개체 수·같은 길이**로 재고 서로 비교한다. 절대 fps는 기기마다
	# 다르지만 세 값의 **비율**은 이 코드가 만든 비용이므로 회귀 감시에 쓸 수 있다.
	#   A 청정   상태 0건            → v2와 같은 조건(§4.7 규칙 1의 "상태 없으면 즉시 반환")
	#   B 만연   전 개체 독+연+한/유 → 설계 완료 기준의 "78기 상태 만연" 바로 그 조건
	#   C 폭풍   B + 화염/뇌 광역 펄스 → 반응 예산이 실제로 물리는 최악 조건
	var soak_fire := _v6_probe_card("flame_field")
	soak_fire["kind"] = "area"
	soak_fire["range"] = 520.0
	var soak_thunder := _v6_probe_card("thunder")
	soak_thunder["kind"] = "area"
	soak_thunder["range"] = 520.0
	# 워밍업: 대량 스폰 직후의 첫 1초는 `Engine.get_frames_per_second()`의 1초 창에
	# 스폰 스파이크가 통째로 들어와 측정이 무의미하다.
	await get_tree().create_timer(1.2).timeout
	var fps_clean := await _stress_sample_fps(2.0)
	var afflicted := 0
	afflicted = _stress_afflict_all()
	var fps_status := await _stress_sample_fps(2.0, true)
	var fps_reaction := await _stress_sample_fps(2.0, true, [soak_fire, soak_thunder])
	var status_overhead := 1.0 - fps_status / maxf(fps_clean, 0.001)
	var orb_count := get_tree().get_nodes_in_group("xp_orbs").size()
	var bounded_ok := game.combat.active_enemies.size() <= GameTuning.MAX_ENEMIES + 26 and game.active_effect_nodes <= GameTuning.MAX_TRANSIENT_EFFECTS and orb_count <= GameTuning.MAX_XP_ORBS
	var structure_ok := not game.combat.enemy_spatial.is_empty() and is_instance_valid(game.skill_effect_controller)
	# V6 성능 예산 — 이 다섯은 **fps와 달리 기기 독립**이라 합격 기준에 넣는다.
	# 특히 `budget_peak <= cap`이 설계 완료 기준의 "반응 예산 초과 0건"이다.
	var status_ok: bool = game.combat.status_budget_peak <= GameTuning.STATUS_REACTION_BUDGET_PER_FRAME \
		and game.combat.status_max_depth_seen <= GameTuning.STATUS_PROPAGATION_DEPTH \
		and game.combat.kill_chain_peak <= GameTuning.STATUS_KILL_CHAIN_DEPTH_MAX + 1 \
		and game.combat.status_dot_ticks > 0 \
		and game.combat.status_reactions_fired > 0 \
		and afflicted > 0
	# 소크 구간의 관측값을 여기서 붙잡아 둔다 — 아래 Y5 구간이 필드를 갈아엎으므로
	# 출력에서 `active_enemies.size()`를 다시 읽으면 소크가 아니라 그 구간을 찍게 된다.
	var soak_enemies := game.combat.active_enemies.size()
	var soak_cells := game.combat.enemy_spatial.size()

	# =========================================================================
	# Y5 신설: 물량 상향 · 무리 동시 스폰 · 개체 상한 (설계 §9.4)
	# =========================================================================
	# 위 소크는 "많이 세워 놓고 버틴다"를 본다. 여기는 다른 것을 본다 —
	# **무리 스폰은 한 번에 여럿을 세우므로 상한을 뛰어넘을 수 있는 유일한 경로다.**
	# 그래서 체류를 포화(dwell 8)시켜 물량을 최대로 올린 뒤, 개체 수를 상한 바로
	# 아래로 되돌려 놓고 반복해서 굴린다. 매 굴림이 "상한 문턱"에서 벌어지게 만드는 것이
	# 요점이다 — 여유가 넉넉한 상태에서 굴리면 상한 로직을 한 번도 안 지나간다.
	game.clock.set_dwell_raw(GameTuning.DWELL_COUNT_SATURATION)
	game.clock.set_stage_raw(1)
	game.is_night = false
	_v6_clear_field()
	await get_tree().process_frame
	var surge_limit: int = game.combat.current_enemy_limit()
	var surge_peak := 0
	var surge_groups := 0
	var surge_rolls := 0
	for round_index in 200:
		_field_resize_enemies(maxi(0, surge_limit - 1))
		game.combat.last_herd_stood = 0
		game.combat.maintain_field_population()
		surge_rolls += 1
		surge_peak = maxi(surge_peak, game.combat.active_enemies.size())
		if game.combat.last_herd_stood > 0:
			surge_groups += 1
	# `surge_groups > 0`이 없으면 "무리가 한 번도 안 나와서 상한을 안 넘었다"가 통과한다.
	var surge_ok: bool = surge_peak <= GameTuning.MAX_ENEMIES \
		and surge_peak <= surge_limit and surge_groups > 0
	_v6_clear_field()
	await get_tree().process_frame

	print("STRESS_TEST_COMPLETE state=%s enemies=%d effects=%d xp_orbs=%d spatial_cells=%d fps=%d bounded=%s structure=%s status=%s surge=%s afflicted=%d fps_clean=%.1f fps_status=%.1f fps_reaction=%.1f status_overhead=%.3f dot_ticks=%d reactions=%d budget_peak=%d budget_cap=%d capped_frames=%d suppressed=%d spread=%d chain_hops=%d chain_depth=%d surge_rolls=%d surge_groups=%d surge_peak=%d surge_limit=%d surge_cap=%d" % [
		game.state, soak_enemies, game.active_effect_nodes, orb_count, soak_cells, Engine.get_frames_per_second(), bounded_ok, structure_ok,
		status_ok, surge_ok, afflicted, fps_clean, fps_status, fps_reaction, status_overhead,
		game.combat.status_dot_ticks, game.combat.status_reactions_fired,
		game.combat.status_budget_peak, GameTuning.STATUS_REACTION_BUDGET_PER_FRAME,
		game.combat.status_budget_capped_frames, game.combat.status_suppressed_total,
		game.combat.status_spread_applied, game.combat.status_chain_hops, game.combat.kill_chain_peak,
		surge_rolls, surge_groups, surge_peak, surge_limit, GameTuning.MAX_ENEMIES
	])
	# fps는 기기별로 다르므로 합격 기준이 아니다(AGENTS.md §11과 동일한 판정).
	# `status_overhead`(청정 대비 만연의 fps 저하율)는 설계 완료 기준 "10% 이내"의
	# 관측점이지만, 헤드리스 fps는 창 없는 환경의 스케줄링에 좌우되므로 **보고만** 한다.
	var stress_passed := game.state == "playing" and bounded_ok and structure_ok and status_ok and surge_ok
	await _quit_test_cleanly(stress_passed)


## 전 개체에 상태를 만연시킨다. 부여 개수를 돌려준다.
## 연 지속이 2초라 측정 구간 내내 살아 있으려면 표본마다 다시 발라야 한다 —
## `_stress_sample_fps(keep_afflicted=true)`가 0.5초마다 이 함수를 부른다.
func _stress_afflict_all() -> int:
	var count := 0
	for enemy: Node in game.combat.active_enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		StatusEngine.set_status(enemy.st_state, "poison", {"damage": 6.0, "stacks": 3})
		StatusEngine.set_status(enemy.st_state, "burn", {"damage": 6.0})
		if count % 2 == 0:
			StatusEngine.set_status(enemy.st_state, "chill")
		if count % 3 == 0:
			StatusEngine.set_status(enemy.st_state, "oil")
		count += 1
	return count


## 0.5초 간격으로 fps를 표본하고 평균을 낸다. `pulses`가 있으면 표본마다 하나씩
## 광역 카드를 꽂아 반응 폭풍을 만든다(대폭 연소·역병 발화·전도가 동시에 터진다).
func _stress_sample_fps(seconds: float, keep_afflicted: bool = false, pulses: Array = []) -> float:
	var samples := maxi(1, int(round(seconds / 0.5)))
	var total := 0.0
	for index in samples:
		if keep_afflicted:
			_stress_afflict_all()
		if not pulses.is_empty():
			game.trigger_cycle_card_pulse(game.player, pulses[index % pulses.size()], false, 0, game.player.global_position, 1.0)
		await get_tree().create_timer(0.5).timeout
		total += float(Engine.get_frames_per_second())
	return total / float(samples)

# =============================================================================
# --cycle-test (W2 신설) — 5칸 바늘 런타임
# =============================================================================
# 검사 항목 (Y2 재작성 · docs/FEEDBACK_Y.md §9.4 "--cycle-test 전면 재작성")
#   ① five_slot    5칸 자동 진행 · 빈칸 = 기본 베기
#   ② flow_rune    각인 흐름 델타가 실전에서 발생 + 같은 시드 = 같은 궤적
#   ③ exec_cap     **한 칸은 한 바퀴에 두 번까지**(§1.2). 구 `heat_damage` 묶음의 후임 —
#                  몬테카를로에서 `slot_exec > 2` 0건 · `step_count > 2n` 0건 ·
#                  `end_reason == "overload"` **0건**(구 「과부하율 0.70%」를 대체) ·
#                  두 번 밟은 칸은 두 번째 실행도 **같은 세기**다(재진입 감쇠 폐기).
#   ④ rail_rune    ★ 레일 각인 5종이 **실전에서 발동**한다. 구 `reentry` 묶음의 후임.
#                  런타임(`_plan_cycle`)이 `rune_opts()`를 병합하지 않으면 여기서 빨개진다.
#   ⑤ debt_reload  빚 RELOAD 계산 (§3.7 · 과열 항 소멸) + 마왕 ×0.6 + `rail_rest` 할인
#   ⑥ slot_swap    칸 교환 시 각인 동반 이동 (부록 C-1)
#   ⑦ omen/boss    전조 1칸 · 마왕 5칸 사이클 경로 생존
#   ⑧ bounded      최악 덱 3,000 사이클에서 무한 루프 0 · STEP_CAP/RELOAD_CAP 준수
#   ⑨ runtime      실제 프레임에서 사이클이 완주하고 시그널이 순서대로 나온다
#   ⑩ twin_cast    ★ 계획 피해 == 실제 발사 수. 컨트롤러가 쌍둥이를 안 쏘면 빨개진다.
func _run_cycle_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.25).timeout
	# 검사 중 모달(레벨업 선택)·사망이 끼어들면 프레임 진행이 멈춘다.
	game.player.invulnerability = 99999.0
	game.player.crit_chance = 0.0
	game.experience = 0
	game.xp_target = 9999999
	var pool := DealCardLibrary.draft_ids()

	# ---- ① 5칸 자동 진행 · 빈칸 기본 베기 --------------------------------
	var plain: FactoryDeck = game.FACTORY_SCRIPT.new()
	plain.reset()
	for index in 3:
		plain.place_card(index, DealCardLibrary.instance(pool[index % pool.size()], 1))
	var plain_deck := plain.rune_deck()
	var plain_cycle := RuneEngine.simulate_cycle(plain_deck, 4242, {})
	var five_slot_ok := plain.slots.size() == FactoryDeck.SLOT_COUNT \
		and int(plain_cycle["step_count"]) == FactoryDeck.SLOT_COUNT \
		and (plain_cycle["visited"] as Array) == [0, 1, 2, 3, 4] \
		and String(plain_cycle["end_reason"]) == "complete"
	for empty_slot in [3, 4]:
		five_slot_ok = five_slot_ok and plain.get_card(empty_slot).is_empty() \
			and String(plain.compile_slot(empty_slot).get("id", "")) == "basic"

	# ---- ⑤ 빚 RELOAD 계산 (§3.7 · Y2: 과열 항 소멸 → 빚에 **선형**) ---------
	var expected_debt := 0.0
	for slot_index in plain.slots.size():
		expected_debt += float(plain.compile_slot(slot_index).get("reload", 0.0))
	var debt_reload_ok := is_equal_approx(float(plain_cycle["reload_debt"]), expected_debt) \
		and is_equal_approx(float(plain_cycle["reload"]), clampf(expected_debt, 0.0, RuneEngine.RELOAD_CAP))
	# 마왕은 같은 빚에 ×0.6 (§6.2).
	var boss_plan := RuneEngine.simulate_cycle(plain_deck, 4242, {"reload_scale": GameTuning.BOSS_RELOAD_MUL})
	debt_reload_ok = debt_reload_ok and is_equal_approx(float(boss_plan["reload"]), clampf(expected_debt * GameTuning.BOSS_RELOAD_MUL, 0.0, RuneEngine.RELOAD_CAP))
	# Y2: `rail_rest`(짧은 휴식)가 **한 바퀴 RELOAD를 실제로 깎는다.** 같은 시드·같은 덱에서
	# 레일 각인 하나만 얹었는데 값이 그대로면 opts가 엔진까지 안 간 것이다.
	var rest_plan := RuneEngine.simulate_cycle(plain_deck, 4242, {"rail_runes": [
		{"id": "rail_rest", "p": 1.0, "mag": RuneEngine.RAIL_REST_RELOAD}]})
	debt_reload_ok = debt_reload_ok and is_equal_approx(float(rest_plan["reload"]),
		clampf(expected_debt * (1.0 - RuneEngine.RAIL_REST_RELOAD), 0.0, RuneEngine.RELOAD_CAP))

	# ---- ② 각인 흐름 델타 + 결정성 ---------------------------------------
	game.factory.reset()
	for index in FactoryDeck.SLOT_COUNT:
		game.factory.place_card(index, DealCardLibrary.instance(pool[index % pool.size()], 1))
	# 확률을 상한으로 박아 흐름 델타가 확실히 나오게 만든다(드래프트 굴림이 아니라 검사용 고정값).
	# Y2: 구 id `rewind_1`·`repeat`은 폐기됐다 — 후임은 `back_one`·`twice`다(§2.1).
	# ⚠️ 폐기 id를 넘기면 `roll_rune`이 `{}`를 돌려주고 `attach_rune`이 조용히 false를
	#    내므로 **각인 없는 덱으로 테스트가 통과한다**(handoff-y1 §10-2). 아래 단언이 그 방어다.
	var attached_runes := 0
	for index in [1, 2, 3]:
		if game.factory.attach_rune(index, {"id":"back_one", "p":RuneEngine.P_CAP, "mag":1.0}):
			attached_runes += 1
		if game.factory.attach_rune(index, {"id":"twice", "p":RuneEngine.P_CAP, "mag":1.0}):
			attached_runes += 1
	# 레일 각인도 실전 덱에 얹는다 — 아래 ④가 이걸로 "실전 발동"을 판정한다.
	var rail_attached := game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_power", game.rng))
	rail_attached = rail_attached and game.factory.attach_rail_rune({"id":"rail_loop", "p":RuneEngine.P_CAP, "mag":1.0})
	# 실전 관측을 실시간으로 하려면 한 스텝이 짧아야 한다. 흐름(궤적)에는 영향이 없고
	# duration만 줄이는 칸 배율을 써서 12초 안에 여러 바퀴가 돌게 만든다.
	for index in game.factory.slots.size():
		game.factory.slots[index]["duration_mul"] = 0.16
	game._reset_player_cycle()
	var live_seed: int = game.player_cycle.cycle_seed()
	var live_deck := game.factory.rune_deck()
	# ★ 실전과 **완전히 같은 opts**를 만든다. `rune_opts()`가 레일 각인을 싣는다.
	var live_opts: Dictionary = {"reload_scale": 1.0}
	live_opts.merge(game.factory.rune_opts())
	var replay_a := RuneEngine.simulate_cycle(live_deck, live_seed, live_opts)
	var replay_b := RuneEngine.simulate_cycle(live_deck, live_seed, live_opts)
	var flow_rune_ok := attached_runes == 6 and rail_attached \
		and RuneEngine.trace_signature(replay_a) == RuneEngine.trace_signature(replay_b)
	var flow_delta_seen := false
	for probe in 40:
		if int(RuneEngine.simulate_cycle(live_deck, live_seed + probe * 13, live_opts)["step_count"]) > FactoryDeck.SLOT_COUNT:
			flow_delta_seen = true
	flow_rune_ok = flow_rune_ok and flow_delta_seen

	# 실전 시그널 관측. Dictionary는 참조라 람다가 그대로 채운다.
	var observed: Dictionary = {"slots":[], "runes":[], "execs":[], "debts":[], "cycles":0, "overloads":0, "reentry":0}
	game.player_cycle.slot_entered.connect(func(index: int, reentry: int) -> void:
		(observed["slots"] as Array).append(index)
		if reentry > 0:
			observed["reentry"] = int(observed["reentry"]) + 1)
	game.player_cycle.rune_fired.connect(func(rune_id: String, _slot_index: int) -> void: (observed["runes"] as Array).append(rune_id))
	game.player_cycle.exec_changed.connect(func(_slot: int, value: int) -> void: (observed["execs"] as Array).append(value))
	game.player_cycle.debt_changed.connect(func(value: float) -> void: (observed["debts"] as Array).append(value))
	game.player_cycle.cycle_completed.connect(func(_steps: int, _peak: int) -> void: observed["cycles"] = int(observed["cycles"]) + 1)
	game.player_cycle.overloaded.connect(func() -> void: observed["overloads"] = int(observed["overloads"]) + 1)
	await get_tree().create_timer(0.15).timeout
	# 실전 궤적이 simulate_cycle과 **같은 함수**에서 나왔는지 — 단일 진실 원천의 증명.
	var single_source_ok: bool = game.player_cycle.planned_route() == (replay_a["visited"] as Array)

	# ---- ④ ★ 레일 각인 5종이 실전에서 작동하는가 (Y2 최우선 수리 ①) ---------
	# 구 「재진입 감쇠」 묶음의 자리다. 감쇠는 §1.4에서 폐기됐고, 그 자리를 이 라운드에
	# 실제로 깨져 있던 것 — **레일 각인 미주입** — 이 대신한다.
	#
	# 판정 셋:
	#   ⓐ 런타임의 계획이 `rune_opts()`를 실은 시뮬레이션과 **지문까지 같다**
	#      (opts를 안 넘기면 여기서 갈린다 — 레일 각인은 duration·damage·RELOAD를 바꾼다)
	#   ⓑ 레일 각인 없는 세계와는 **달라야** 한다(같으면 ⓐ가 허수다)
	#   ⓒ 5종이 각각 자기 축을 실제로 움직인다(엔진 계약 재확인 · 실전 opts 경로로)
	var rail_plan: Dictionary = game.player_cycle.plan
	var rail_rune_ok: bool = not rail_plan.is_empty() \
		and (rail_plan.get("rail_fired", []) as Array).has("rail_power")
	var runtime_seed: int = game.player_cycle.cycle_seed_base
	var with_rail := RuneEngine.simulate_cycle(live_deck, runtime_seed, live_opts)
	var without_rail := RuneEngine.simulate_cycle(live_deck, runtime_seed, {"reload_scale": 1.0})
	rail_rune_ok = rail_rune_ok \
		and RuneEngine.trace_signature(rail_plan) == RuneEngine.trace_signature(with_rail) \
		and RuneEngine.trace_signature(with_rail) != RuneEngine.trace_signature(without_rail) \
		and float(with_rail["damage_total"]) > float(without_rail["damage_total"])
	# ⓒ 5종 각각. 같은 시드·같은 덱에 각인 하나만 얹어 그 축만 움직였는지 본다.
	var bare_deck := plain_deck
	var bare := RuneEngine.simulate_cycle(bare_deck, 5150, {})
	var bare_duration := 0.0
	for entry in (bare["steps"] as Array):
		bare_duration += float((entry as Dictionary).get("duration", 0.0))
	var rail_axis: Dictionary = {
		"rail_fast": RuneEngine.RAIL_FAST_DURATION,
		"rail_power": RuneEngine.RAIL_POWER_DAMAGE,
		"rail_rest": RuneEngine.RAIL_REST_RELOAD,
		"rail_color": RuneEngine.RAIL_COLOR_DAMAGE,
		"rail_loop": 1.0
	}
	var rail_axis_dbg: Array[String] = []
	for rail_id: String in rail_axis.keys():
		var one := RuneEngine.simulate_cycle(bare_deck, 5150, {"rail_runes": [
			{"id": rail_id, "p": 1.0, "mag": float(rail_axis[rail_id])}]})
		var moved := false
		match rail_id:
			"rail_fast":
				var fast_duration := 0.0
				for entry in (one["steps"] as Array):
					fast_duration += float((entry as Dictionary).get("duration", 0.0))
				moved = fast_duration < bare_duration - 0.0001
			"rail_power":
				moved = float(one["damage_total"]) > float(bare["damage_total"]) + 0.0001
			"rail_rest":
				moved = float(one["reload"]) < float(bare["reload"]) - 0.0001
			"rail_color":
				# 공명이 없는 덱에서는 가산되지 않는 것이 **정상 계약**이다(§2.2).
				# 그래서 "붙어도 안 터진다"가 아니라 "레일 해석에 들어왔다"를 본다.
				moved = (one["rail_fired"] as Array).has("rail_color")
			"rail_loop":
				moved = bool(one["rail_loop_armed"]) == (one["rail_fired"] as Array).has("rail_loop")
				if bool(one["rail_loop_armed"]):
					moved = moved and int(one["step_count"]) > int(bare["step_count"])
		rail_rune_ok = rail_rune_ok and moved
		if not moved:
			rail_axis_dbg.append(rail_id)
	if not rail_axis_dbg.is_empty():
		print("RAIL_RUNE_DEBUG dead=%s" % ",".join(rail_axis_dbg))

	# ---- ③ 칸당 실행 2회 상한 (§1.2 · 구 heat_damage 묶음의 후임) -----------
	# ⓐ 배율이 **실제 피해**에 실린다 — 단일 지점(`combat._cycle_damage_value`) 계약은
	#    과열이 사라져도 그대로 유효하다. 배율의 출처만 각인·공명·레일 각인으로 바뀌었다.
	var probe_card := game.factory.compile_slot(0)
	probe_card["kind"] = "melee"
	probe_card["range"] = 260.0
	probe_card["arc"] = TAU
	probe_card["crit"] = 0.0
	probe_card["lifesteal"] = 0.0
	probe_card["damage"] = maxf(0.4, float(probe_card.get("damage", 1.0)))
	var dummy_position: Vector2 = game.player.global_position + Vector2(70.0, 0.0)
	var dummy := game.combat.spawn_enemy_instance(dummy_position, 2, "", false, "", false, "", true)
	var exec_cap_ok := is_instance_valid(dummy)
	if exec_cap_ok:
		dummy.max_health = 4000000.0
		dummy.health = dummy.max_health
		dummy.global_position = dummy_position
		var before_cold: float = dummy.health
		game.apply_cycle_melee(game.player, probe_card, {}, false, Vector2.RIGHT, 1.0)
		var cold_damage: float = before_cold - dummy.health
		dummy.global_position = dummy_position
		var before_hot: float = dummy.health
		game.apply_cycle_melee(game.player, probe_card, {}, false, Vector2.RIGHT, 2.5)
		var hot_damage: float = before_hot - dummy.health
		exec_cap_ok = cold_damage > 0.0 and hot_damage > cold_damage * 2.4 and hot_damage < cold_damage * 2.6
		dummy.queue_free()
	exec_cap_ok = exec_cap_ok \
		and game.combat._cycle_damage_value(game.player, probe_card, true, 2.0) > game.combat._cycle_damage_value(game.player, probe_card, true, 1.0)
	# ⓑ 상한이 **하드 바운드**다. 흐름 각인을 상한까지 박은 덱 2,000 사이클에서
	#    `slot_exec > 2` · `step_count > 2n` · `end_reason == "overload"` 전부 0건이어야 한다.
	#    이 세 줄이 §1.3 종료성 증명의 런타임 판이고, 구 「과부하율 0.70%」를 대체한다.
	var cap_violations := 0
	var cap_overloads := 0
	var cap_max_exec := 0
	var cap_max_steps := 0
	for probe in 2000:
		var capped := RuneEngine.simulate_cycle(live_deck, 31337 + probe * 17, live_opts)
		if String(capped["end_reason"]) == "overload":
			cap_overloads += 1
		cap_max_steps = maxi(cap_max_steps, int(capped["step_count"]))
		for used in (capped["slot_exec"] as Array):
			cap_max_exec = maxi(cap_max_exec, int(used))
			if int(used) > RuneEngine.SLOT_EXEC_CAP:
				cap_violations += 1
	exec_cap_ok = exec_cap_ok and cap_violations == 0 and cap_overloads == 0 \
		and cap_max_steps <= RuneEngine.SLOT_EXEC_CAP * live_deck.size() \
		and cap_max_exec == RuneEngine.SLOT_EXEC_CAP
	# ⓒ 두 번째 실행이 첫 실행과 **같은 세기**다(§1.4 "두 번째가 약하면 거짓말이 된다").
	#    재진입 감쇠가 되살아나면 여기서 잡힌다.
	var reentry_pairs := 0
	for probe in 200:
		var same := RuneEngine.simulate_cycle(live_deck, 77003 + probe * 23, live_opts)
		var first_mul: Dictionary = {}
		for entry in (same["steps"] as Array):
			var step: Dictionary = entry
			var slot_key := int(step["slot"])
			if int(step["reentry"]) == 0:
				first_mul[slot_key] = float(step["damage_mul"])
			elif first_mul.has(slot_key):
				reentry_pairs += 1
				# 같은 칸의 두 번째 실행은 각인 굴림이 다시 일어나므로 배율이 **커질 수는**
				# 있다(strong은 확정, twice는 확률). 줄어들면 감쇠가 살아난 것이다.
				exec_cap_ok = exec_cap_ok and float(step["damage_mul"]) >= float(first_mul[slot_key]) - 0.0001
	exec_cap_ok = exec_cap_ok and reentry_pairs > 0

	# ---- ⑥ 칸 교환 = 각인 동반 이동 (부록 C-1) ----------------------------
	var swap_runes := game.factory.rune_count_on(1)
	var swap_card := String(game.factory.get_card(1).get("id", ""))
	var slot_swap_ok: bool = swap_runes > 0 and game.factory.swap_slots(1, 4)
	slot_swap_ok = slot_swap_ok and game.factory.rune_count_on(4) == swap_runes \
		and game.factory.rune_count_on(1) == 0 \
		and String(game.factory.get_card(4).get("id", "")) == swap_card
	# 엔진이 보는 덱에서도 각인이 새 칸에 있어야 실전 발동 위치가 따라간다.
	var swapped_deck := game.factory.rune_deck()
	slot_swap_ok = slot_swap_ok and ((swapped_deck[4] as Dictionary).get("runes", []) as Array).size() == swap_runes
	# 카드만 옮기는 조작은 각인을 데려가지 않는다.
	slot_swap_ok = slot_swap_ok and game.factory.move_card(4, 1)
	slot_swap_ok = slot_swap_ok and game.factory.rune_count_on(4) == swap_runes and game.factory.rune_count_on(1) == 0
	game.factory.swap_slots(1, 4)

	# ---- ⑧ 종료성: 최악 덱 3,000 사이클 (§1.3) -----------------------------
	# Y2: 각인 id를 신 15종으로 갈았다. **폐기 id를 넘기면 각인 0개 덱이 되어 이 검사가
	# 아무것도 안 재게 된다**(handoff-y1 §10-2) — 그래서 아래에서 부착 수를 먼저 센다.
	# 최악 = 확정 앙코르 2종(trade_skip · finisher) + 확률 흐름 3종 + 되돌이 레일.
	var worst: Array = []
	for index in FactoryDeck.SLOT_COUNT:
		var worst_runes: Array = []
		for rune_id in ["back_one", "jump_one", "twice", "trade_skip", "finisher"]:
			worst_runes.append({"id": rune_id, "p": RuneEngine.P_CAP, "mag": 1.0})
		worst.append({"card": (live_deck[index] as Dictionary)["card"], "runes": worst_runes})
	var worst_opts: Dictionary = {"kill_chance": 1.0,
		"rail_runes": [{"id": "rail_loop", "p": RuneEngine.P_CAP, "mag": 1.0}]}
	var bounded_ok := int((worst[0] as Dictionary)["runes"].size()) == RuneEngine.RUNE_STACK_CAP
	var max_steps := 0
	var overload_hits := 0
	var max_exec := 0
	for index in 3000:
		var worst_cycle := RuneEngine.simulate_cycle(worst, 90001 + index * 7, worst_opts)
		max_steps = maxi(max_steps, int(worst_cycle["step_count"]))
		for used in (worst_cycle["slot_exec"] as Array):
			max_exec = maxi(max_exec, int(used))
		if String(worst_cycle["end_reason"]) == "overload":
			overload_hits += 1
		if String(worst_cycle["end_reason"]) == "guard" \
			or int(worst_cycle["step_count"]) > RuneEngine.SLOT_EXEC_CAP * FactoryDeck.SLOT_COUNT \
			or float(worst_cycle["reload"]) > RuneEngine.RELOAD_CAP + 0.001 \
			or float(worst_cycle["reload"]) < 0.0:
			bounded_ok = false
	# 새 회귀 계약(§1.3): 과부하 **0건** · 칸당 최대 2회 · 스텝 상한 2n이 tight하게 달성.
	bounded_ok = bounded_ok and overload_hits == 0 and max_exec == RuneEngine.SLOT_EXEC_CAP \
		and max_steps == RuneEngine.SLOT_EXEC_CAP * FactoryDeck.SLOT_COUNT

	# ---- ⑨ 실전 프레임: 사이클 완주 + 시그널 -----------------------------
	# Y7(§7.4): 이 12초가 곧 「카메라 최소화」의 계측 창이다. 딜싸이클이 두 바퀴 이상
	# 돌고 무거운 카드가 여러 번 터지는 동안 카메라가 얼마나 움직였는지 잰다.
	game.screen_shake_enabled = true
	game.reset_cam_peak()
	await get_tree().create_timer(12.0).timeout
	var cam_live_peak: float = game.cam_peak
	var runtime_ok: bool = int(observed["cycles"]) >= 2 \
		and (observed["slots"] as Array).size() >= 2 * FactoryDeck.SLOT_COUNT \
		and not (observed["runes"] as Array).is_empty() \
		and not (observed["debts"] as Array).is_empty() \
		and single_source_ok
	# Y2: 사이클마다 밟은 횟수가 1부터 다시 세어지고 빚은 0으로 리셋된다(§3.2 CYCLE_END).
	runtime_ok = runtime_ok and (observed["execs"] as Array).has(1) and (observed["debts"] as Array).has(0.0)
	# 되밟기가 실전에서 실제로 일어났고(흐름 각인을 상한으로 박았으므로) 상한을 안 넘었다.
	var live_exec_peak := 0
	for value in (observed["execs"] as Array):
		live_exec_peak = maxi(live_exec_peak, int(value))
	runtime_ok = runtime_ok and live_exec_peak == RuneEngine.SLOT_EXEC_CAP
	# 사이클마다 시드가 바뀌므로 궤적이 매번 새로 계산돼야 한다(고정 궤적 반복 방지).
	runtime_ok = runtime_ok and game.player_cycle.cycle_seed() != live_seed

	# =========================================================================
	# Y7 ⑪ 카메라 최소화 (§7.1 원칙 1 · §7.4) — 축 넷
	# =========================================================================
	# 계약: **진폭 ≤ 4px · 지속 ≤ 0.12초 · 보스 착탄과 플레이어 피격에만.**
	# 네 축을 다 걸어야 판별력이 생긴다 — 상한만 재면 "아무도 안 흔들어서 통과"가
	# 되고(음성), 발화만 재면 "20px로 흔들어도 통과"가 된다(양성).
	var cam_ok := true
	# ⓐ 12초 실전: 딜싸이클이 두 바퀴 이상 돈 동안 4px을 안 넘었다.
	cam_ok = cam_ok and cam_live_peak <= GameMain.SHAKE_MAX_AMPLITUDE + 0.001

	# ⓑ **플레이어 스킬 발사에는 흔들림 0.** 무거운 카드 넷을 실전 경로로 터뜨린다.
	#    Y7 이전에는 `combat_resolver`가 여기서 `shake_camera(7.0, 0.22)`를 불렀다 —
	#    그 줄을 되살리면 이 축이 바로 빨개진다.
	game.reset_cam_peak()
	for heavy_id in ["meteor_blade", "holy_pulse", "execution", "cleave"]:
		var heavy_effect: CycleSkillEffect = DealCycleController.EFFECT_SCRIPT.new()
		heavy_effect.setup(game, game.player,
			DealCardLibrary.ranked(DealCardLibrary.instance(heavy_id, 1)), false, 1.0)
		game.gameplay_root.add_child(heavy_effect)
	await get_tree().create_timer(2.2).timeout
	var cam_cards_peak: float = game.cam_peak
	cam_ok = cam_ok and cam_cards_peak == 0.0

	# ⓒ 보스 착탄은 **실제로 흔든다**(양성 축) — 그리고 상한 안이다.
	#    호출부가 적어 낸 14.0이 화면에서는 4px 이하로 눌린다.
	game.reset_cam_peak()
	game.shake_camera(14.0, 0.8)
	var cam_boss_peak: float = game.cam_peak
	cam_ok = cam_ok and cam_boss_peak > 0.0 and cam_boss_peak <= GameMain.SHAKE_MAX_AMPLITUDE + 0.001

	# ⓓ 설정에서 「화면 흔들림」을 끄면 **정확히 0.0**이다(§7.4 마지막 줄).
	game.screen_shake_enabled = false
	game.reset_cam_peak()
	game.shake_camera(14.0, 0.8)
	var cam_off_peak: float = game.cam_peak
	cam_ok = cam_ok and cam_off_peak == 0.0
	game.screen_shake_enabled = true

	# ---- ⑩ X3 필드 HUD: 미니 스트립 5칸 · 바늘 · 각인 핍 · **밟은 횟수 점** ----
	# "스크롤 없이 5칸을 한번에"(W5 출발 요구)는 그대로 판정하고, 여기에 X3의 두 요구를
	# 더한다 — **세로 절반 이하**와 **칸 안 텍스트 0개**. 판정은 전부 런타임 노드에서 되읽는다.
	var hud_card_ids: Array[String] = []
	for index in 8:
		hud_card_ids.append(pool[index % pool.size()])
	game.rejected_skills.assign(hud_card_ids)
	game.demon_lord.sync_runes(game.rng)
	game._update_hud()
	game._update_cycle_rail(0.016)
	var hud_rail_ok: bool = game.rail_slot_panels.size() == FactoryDeck.SLOT_COUNT \
		and game.rail_band.visible \
		and is_instance_valid(game.rail_needle) and game.rail_needle.visible != game.player_cycle.reloading
	# 바늘이 가리키는 칸 == 컨트롤러가 실행 중인 칸. 좌표도 그 칸의 중심이어야 한다.
	var needle_slot := int(game.rail_needle.get_meta("slot_index", -1))
	hud_rail_ok = hud_rail_ok and needle_slot == game.player_cycle.current_index
	hud_rail_ok = hud_rail_ok and is_equal_approx(
		game.rail_needle.position.x + game.rail_needle.size.x * 0.5,
		game._rail_slot_center_x(needle_slot))
	# 5칸이 전부 스트립 안에 들어온다 — 가로 스크롤이 구조적으로 불가능하다.
	for slot_index in game.rail_slot_panels.size():
		var slot_panel: Panel = game.rail_slot_panels[slot_index]
		hud_rail_ok = hud_rail_ok and slot_panel.position.x >= 0.0 \
			and slot_panel.position.x + slot_panel.size.x <= game.RAIL_BAND_RECT.size.x \
			and int(slot_panel.get_meta("slot_index", -1)) == slot_index
		# 각인 핍 개수가 그 칸의 실제 각인 수에서 나온다.
		hud_rail_ok = hud_rail_ok and int(slot_panel.get_meta("rune_count", -1)) == game.factory.rune_count_on(slot_index)
		# Y2: 밟은 횟수 점이 칸마다 정확히 `SLOT_EXEC_CAP`개 있고, 켜진 개수가
		# 컨트롤러의 `exec_count()`와 **같다**(구 과열 8핍 단언의 후임 · §1.4).
		var lit_dots := 0
		for dot_index in RuneEngine.SLOT_EXEC_CAP:
			var dot := slot_panel.get_node_or_null("Exec%d" % dot_index) as ColorRect
			hud_rail_ok = hud_rail_ok and is_instance_valid(dot)
			if is_instance_valid(dot) and not dot.color.is_equal_approx(game.RAIL_EXEC_DOT_OFF):
				lit_dots += 1
		var want_dots := 0 if game.player_cycle.reloading else game.player_cycle.exec_count(slot_index)
		hud_rail_ok = hud_rail_ok and lit_dots == want_dots

	# ---- ⑩-b X3 미니모드 계약 (사용자 피드백 ⑥ "딜싸이클 범위가 너무 커") ----
	#   ⓐ 세로 74 ≤ 156의 절반(78)      ⓑ 스트립 전체에 Label 0개(칸 이름·번호·태그 소멸)
	#   ⓒ 스트립이 킷 9-slice 판을 안 쓴다(탈블록)  ⓓ 칸 아이콘이 원소색으로 물든다
	#   ⓔ 지운 문장이 전부 툴팁에 등록돼 있다      ⓕ 강제 표시 경로가 실제로 뜬다
	var hud_mini_ok: bool = game.rail_band.size.y <= game.RAIL_BAND_RECT.size.y \
		and game.RAIL_BAND_RECT.size.y <= 78.0 \
		and not (game.rail_band is Panel)
	var strip_labels := _count_labels_in(game.rail_band)
	hud_mini_ok = hud_mini_ok and strip_labels == 0
	# ⓓ 원소색: 첫 칸에 화(火) 카드를 얹으면 아이콘 색이 X1 원소표의 화염색이어야 한다.
	game.factory.place_card(0, DealCardLibrary.instance("flame_field", 1))
	game._update_rail_text()
	var fire_icon := (game.rail_slot_panels[0] as Panel).get_node_or_null("Icon")
	hud_mini_ok = hud_mini_ok and fire_icon != null \
		and (fire_icon.icon_color as Color).is_equal_approx(game._element_color("fire"))
	# ⓔ 툴팁 등록 — 스트립 전체 · 다이얼 + 칸 5개. Y2: `rail_heat`는 삭제됐다.
	for tip_key: String in ["rail", "rail_dial", "vitals", "stage", "ghost"]:
		hud_mini_ok = hud_mini_ok and game.hud_tooltip_targets.has(tip_key)
	hud_mini_ok = hud_mini_ok and not game.hud_tooltip_targets.has("rail_heat")
	for slot_index in FactoryDeck.SLOT_COUNT:
		hud_mini_ok = hud_mini_ok and game.hud_tooltip_targets.has("rail_slot%d" % slot_index)
	# ⓕ 강제 표시 → 그 대상의 툴팁이 실제로 떠 있다(캡처가 쓰는 것과 같은 경로).
	game._update_hud()
	var forced := game._force_hud_tooltip("rail_slot0")
	hud_mini_ok = hud_mini_ok and forced \
		and UIKit.tooltip_shown(game.hud_tooltip_layer) == game.hud_tooltip_targets["rail_slot0"]
	# 정보 손실 0: 칸 툴팁의 줄 수가 그 칸의 각인 수 이상이다(랭크·속성 줄 + 각인 줄들).
	var slot0_spec: Dictionary = (game.hud_tooltip_targets["rail_slot0"] as Control).get_meta(UIKit.TOOLTIP_META, {})
	hud_mini_ok = hud_mini_ok and (slot0_spec.get("rows", []) as Array).size() >= maxi(1, game.factory.rune_count_on(0))
	# 스트립 툴팁이 지운 문장의 숫자를 전부 갖고 있다(빚 · 청산 RELOAD · 밟은 칸 · 상태).
	# Y2: 필수 문자열 「과열」이 **금지 어휘**가 됐다(§1.4). 후임은 「밟은 칸」·「이 칸」이다.
	var rail_spec: Dictionary = (game.hud_tooltip_targets["rail"] as Control).get_meta(UIKit.TOOLTIP_META, {})
	var rail_keys: Array[String] = []
	for row_value in (rail_spec.get("rows", []) as Array):
		rail_keys.append(String((row_value as Array)[0]))
	for needed: String in ["상태", "빚", "다 갚으면 RELOAD", "밟은 칸", "이 칸"]:
		hud_mini_ok = hud_mini_ok and rail_keys.has(needed)
	hud_mini_ok = hud_mini_ok and not rail_keys.has("과열")
	# 금지 어휘 계약 — 스트립 툴팁의 본문·제목 어디에도 「과열」이 남으면 안 된다.
	hud_mini_ok = hud_mini_ok and not ("과열" in String(rail_spec.get("body", ""))) \
		and not ("과열" in String(rail_spec.get("title", "")))
	UIKit.tooltip_hide(game.hud_tooltip_layer)
	game.factory.clear_slot(0)
	# ⓖ "잠식 경고는 발동 시에만"(사용자 요구). 평상시 그 줄은 「체류 N」이고,
	#    잠식이 켜지면 같은 줄이 붉은 경고문으로 바뀐다 — 새 줄이 생기지 않는다.
	var quiet_dwell: int = game.clock.dwell
	game.clock.set_dwell_raw(0)
	game.blight_active = false
	game._update_stage_panel()
	hud_mini_ok = hud_mini_ok and not game.stage_warn_on \
		and game.dwell_text.text.begins_with("체류")
	game.clock.set_dwell_raw(game.clock.blight_threshold())
	game.blight_active = true
	game._update_stage_panel()
	hud_mini_ok = hud_mini_ok and game.stage_warn_on and "잠식" in game.dwell_text.text
	game.blight_active = false
	game.clock.set_dwell_raw(quiet_dwell)
	game._update_stage_panel()

	# ---- ⑩-c X3 가장자리 화살표 내비 (구 나침반 패널) -----------------------
	#   ⓐ 마커 4종이 존재하고 전부 EdgeNav 층 아래에 있다
	#   ⓑ 멀리 있는 대상은 화살표가 보이고, 링(NAV_RING) 위에 중심이 붙는다
	#   ⓒ 화살촉 각도가 실제 화면상 목표 방향과 같다(방향이 거짓말을 안 한다)
	#   ⓓ 대상이 발밑에 오면 화살표가 사라진다("보이면 안 가리킨다")
	#   ⓔ 성 안에서는 전부 꺼진다
	game.state = "playing"
	game.inside_castle = false
	game.player.global_position = Vector2.ZERO
	await _settle_camera()
	game._update_edge_nav()
	var nav_dbg: Array[String] = []
	var nav_layer_ok := game.nav_markers.size() == game.NAV_TARGETS.size() \
		and is_instance_valid(game.nav_layer) and game.nav_layer.visible
	var gate_marker: Control = game.nav_markers.get("boss_gate", null)
	var gate_at: Vector2 = game.world.get_boss_gate_position()
	# ---- Y6(§6.1): 화살표는 **발견한 곳에만** 뜬다 -------------------------
	# 음성 축이 먼저다. 발견 게이팅이 통째로 꺼져 있어도 아래 ⓑ~ⓒ는 초록으로
	# 통과하므로, "발견 전에는 없다"를 재지 않으면 이 묶음이 공허해진다.
	game.discovered_features.erase("boss_gate")
	game._update_edge_nav()
	var nav_gate_hidden_ok := gate_marker != null and not gate_marker.visible
	# 성·캠프는 스테이지 시작부터 발견 상태다(리스크 6 — 정비 창구를 못 찾으면 막힌다).
	var nav_seed_ok := game.is_discovered("castle") and game.is_discovered("camp") \
		and not game.is_discovered("boss_gate")
	# 발견하는 순간 켜진다. 같은 키를 두 번 발견하면 false를 돌려준다(1회성).
	var first_mark := game.mark_discovered("boss_gate", "")
	nav_seed_ok = nav_seed_ok and first_mark and not game.mark_discovered("boss_gate", "")
	game._update_edge_nav()
	var nav_shown_ok := gate_marker != null and gate_marker.visible
	var nav_ring_ok := false
	var nav_bounds_ok := false
	var nav_angle_ok := false
	if nav_shown_ok:
		var marker_center := gate_marker.position + gate_marker.size * 0.5
		var ring := game.NAV_RING
		# 중심이 링의 네 변 중 하나 위에 있다(사각 링 클램프 · round() 오차 1px 허용).
		nav_ring_ok = absf(marker_center.x - ring.position.x) <= 1.0 \
			or absf(marker_center.x - ring.end.x) <= 1.0 \
			or absf(marker_center.y - ring.position.y) <= 1.0 \
			or absf(marker_center.y - ring.end.y) <= 1.0
		# 마커 전체가 화면 안이다(가장자리로 밀어도 잘리지 않는다).
		nav_bounds_ok = gate_marker.position.x >= 0.0 and gate_marker.position.y >= 0.0 \
			and gate_marker.position.x + gate_marker.size.x <= 1280.0 \
			and gate_marker.position.y + gate_marker.size.y <= 720.0
		# 화살촉 각도 == 화면상 목표 방향(±0.02rad).
		var screen_at: Vector2 = game.get_viewport().get_canvas_transform() * gate_at
		var ring_center := ring.position + ring.size * 0.5
		nav_angle_ok = absf(wrapf(
			gate_marker.angle - (screen_at - ring_center).angle(), -PI, PI)) < 0.02
	# ⓓ 대상 위로 순간이동하면 화살표가 사라진다. 카메라가 따라붙어야 화면 좌표가
	# 실제로 가운데로 오므로 스무딩을 끄고 두 프레임 흘린다(안 그러면 옛 카메라 기준이다).
	game.player.global_position = gate_at
	await _settle_camera()
	game._update_edge_nav()
	var nav_hide_ok := gate_marker != null and not gate_marker.visible
	game.player.global_position = Vector2.ZERO
	await _settle_camera()
	# ⓔ 성 안 → 층 전체가 꺼진다.
	game.inside_castle = true
	game._update_edge_nav()
	var nav_castle_ok := not game.nav_layer.visible
	game.inside_castle = false
	game._update_edge_nav()
	var hud_nav_ok := nav_layer_ok and nav_shown_ok and nav_ring_ok and nav_bounds_ok \
		and nav_angle_ok and nav_hide_ok and nav_castle_ok \
		and nav_gate_hidden_ok and nav_seed_ok
	if not hud_nav_ok:
		nav_dbg.assign(["layer=%s" % nav_layer_ok, "shown=%s" % nav_shown_ok,
			"ring=%s" % nav_ring_ok, "bounds=%s" % nav_bounds_ok, "angle=%s" % nav_angle_ok,
			"hide=%s" % nav_hide_ok, "castle=%s" % nav_castle_ok,
			"undiscovered_hidden=%s" % nav_gate_hidden_ok, "seed=%s" % nav_seed_ok,
			"pos=%s" % (str(gate_marker.position) if gate_marker != null else "nil")])
		print("HUD_NAV_DEBUG %s" % " ".join(nav_dbg))

	# X3: HUD 점유율은 **필드 상태**에서 잰다. 이 줄 아래로는 전조·보스전이 이어져
	# 마왕 레일 밴드가 켜지므로, 여기서 재지 않으면 "보스전 화면"의 숫자가 나온다.
	var coverage := _hud_coverage()

	# ---- ⑪ 마왕 고스트 레일이 DemonLord 데이터에 연결돼 있는가 -----------
	# X3: 숫자 배지·각인 수 라벨·꼬리말이 사라졌으므로 **툴팁 rows**에서 되읽는다.
	var ghost_layout := game.demon_lord.slot_layout()
	var hud_ghost_ok: bool = game.ghost_slot_panels.size() == GameTuning.BOSS_SLOT_COUNT \
		and game.demon_lord.rune_count() > 0 \
		and not (game.ghost_panel is Panel) \
		and _count_labels_in(game.ghost_panel) == 0
	for ghost_index in game.ghost_slot_panels.size():
		var ghost_panel_node: Panel = game.ghost_slot_panels[ghost_index]
		var ghost_card: Dictionary = (ghost_layout[ghost_index] as Dictionary).get("card", {})
		var ghost_runes := game.demon_lord.rune_count_on_slot(ghost_index)
		var dot := ghost_panel_node.get_node_or_null("RuneDot") as ColorRect
		hud_ghost_ok = hud_ghost_ok \
			and String(ghost_panel_node.get_meta("card_id", "")) == String(ghost_card.get("id", "")) \
			and int(ghost_panel_node.get_meta("rune_count", -1)) == ghost_runes \
			and is_instance_valid(dot) and dot.visible == (ghost_runes > 0)
	# 각인 총수·받은 카드·잔재·HP 배율이 툴팁에 남아 있다(정보 손실 0).
	var ghost_spec: Dictionary = (game.hud_tooltip_targets["ghost"] as Control).get_meta(UIKit.TOOLTIP_META, {})
	var ghost_rows: Array = ghost_spec.get("rows", [])
	var ghost_keys: Array[String] = []
	var ghost_values: Array[String] = []
	for row_value in ghost_rows:
		ghost_keys.append(String((row_value as Array)[0]))
		ghost_values.append(String((row_value as Array)[1]))
	# YZ가 「HP 배율」을 「체력 배율」로 고쳤다(마왕 툴팁 행 제목).
	for needed: String in ["각인", "받은 카드", "잔재", "체력 배율"]:
		hud_ghost_ok = hud_ghost_ok and ghost_keys.has(needed)
	hud_ghost_ok = hud_ghost_ok \
		and str(game.demon_lord.rune_count()) in ghost_values[ghost_keys.find("각인")]
	# 칸 5개 줄이 툴팁 안에 있다(구 칸 번호 라벨의 후신).
	hud_ghost_ok = hud_ghost_ok and ghost_rows.size() >= 4 + GameTuning.BOSS_SLOT_COUNT

	# ---- ★ Y4 필드 HUD 두 줄 (피드백 ⑤⑫ · FEEDBACK_Y §8 ⑤ ⑫) ---------------
	# ⓐ 상단 스테이지 줄: 문장 한 줄 → **관문 아이콘 5개 + 해/달 아이콘**.
	#    필드에서는 스테이지 판에 **2자 이상 글자가 「체류 N」 한 줄뿐**이어야 한다
	#    (장소 꼬리표는 빈 문자열, 스테이지 이름은 툴팁으로 갔다).
	var hud_stage_ok: bool = game.stage_gates.size() == GameTuning.STAGE_COUNT \
		and is_instance_valid(game.phase_mark) \
		and not (game.stage_panel is Panel) \
		and game.phase_text.text.strip_edges().is_empty()
	# 관문 상태 셋이 실제로 갈린다 — 지난 관문 0 · 지금 관문 1 · 남은 관문 2.
	game.clock.stage = 3
	game._update_stage_panel()
	for gate_index in game.stage_gates.size():
		var want := 2
		if gate_index + 1 < game.clock.stage:
			want = 0
		elif gate_index + 1 == game.clock.stage:
			want = 1
		hud_stage_ok = hud_stage_ok and int(game.stage_gates[gate_index].state) == want
	# 해/달이 실제로 뒤집힌다(둘 중 하나로 굳어 있으면 정보가 아니다).
	var night_before := game.is_night
	game.is_night = false
	game._update_stage_panel()
	hud_stage_ok = hud_stage_ok and not game.phase_mark.night
	game.is_night = true
	game._update_stage_panel()
	hud_stage_ok = hud_stage_ok and game.phase_mark.night
	game.is_night = night_before
	game._update_stage_panel()
	# 스테이지 이름은 사라진 것이 아니라 **툴팁 제목**으로 갔다(정보 손실 0).
	hud_stage_ok = hud_stage_ok \
		and String(game._stage_tooltip_spec().get("title", "")).contains(game.clock.stage_name())
	# ⓑ 체력바: 연속 막대 → **세그먼트 12칸.** 비율에 따라 켜진 칸 수가 정확히 움직인다.
	#    ⚠️ 공허한 통과 방지 — 세 지점을 **실제로 심어** 재고, 마지막에 되돌린다.
	var hud_health_ok: bool = game.health_segments.size() == game.HUD_HEALTH_SEGMENTS \
		and game.HUD_HEALTH_SEGMENTS >= 8
	var health_backup := game.player.health
	for health_probe: Array in [[1.0, 12], [0.5, 6], [0.25, 3], [0.0, 0]]:
		var ratio := float(health_probe[0])
		game._on_player_health_changed(game.player.max_health * ratio, game.player.max_health)
		var lit := 0
		for cell: ColorRect in game.health_segments:
			if cell.visible and cell.size.x > 0.0:
				lit += 1
		hud_health_ok = hud_health_ok and lit == int(health_probe[1])
	game._on_player_health_changed(health_backup, game.player.max_health)
	# 금화는 킷 선화가 아니라 YA 금화 더미다(피드백 ⑯ · handoff-ya §5).
	hud_health_ok = hud_health_ok and _v4_find_named(game.vitals_panel, "VitalsCoinPile") != null
	if not (hud_stage_ok and hud_health_ok):
		print("Y4_DEBUG hud_stage=%s hud_health=%s" % [hud_stage_ok, hud_health_ok])

	# ---- ⑦ 전조 1칸 · 마왕 5칸 사이클 경로 -------------------------------
	var demo_pool: Array[String] = []
	for index in 4:
		demo_pool.append(pool[index % pool.size()])
	game.rejected_skills.assign(demo_pool)
	game.demon_lord.sync_runes(game.rng)
	# V5: 전조 게이트가 일수에서 dwell로 옮겨갔다(설계 §2.4).
	game.clock.set_dwell_raw(GameTuning.OMEN_START_DWELL)
	game.clock.set_night_raw(false)
	game._toggle_day_night()
	await get_tree().create_timer(0.8).timeout
	var omen_ok: bool = is_instance_valid(game.active_omen) and is_instance_valid(game.omen_cycle) \
		and game.omen_deck != null and game.omen_deck.slots.size() == 1 \
		and is_equal_approx(game.omen_cycle.reload_scale, GameTuning.BOSS_RELOAD_MUL)
	if omen_ok:
		omen_ok = not game.omen_cycle.plan_steps.is_empty() or game.omen_cycle.reloading or game.omen_cycle.completed_cycles > 0
	game._clear_omen()

	game.state = "playing"
	game._challenge_demon_king()
	var boss_ok: bool = game.state == "boss_preview" and game.boss_factory.slots.size() == GameTuning.BOSS_SLOT_COUNT
	game._begin_boss_battle()
	await get_tree().create_timer(1.5).timeout
	boss_ok = boss_ok and game.state == "boss" and is_instance_valid(game.boss_cycle) \
		and game.boss_cycle.reload_enabled \
		and is_equal_approx(game.boss_cycle.reload_scale, GameTuning.BOSS_RELOAD_MUL) \
		and (not game.boss_cycle.plan_steps.is_empty() or game.boss_cycle.reloading or game.boss_cycle.completed_cycles > 0)

	# ---- ⑩ ★ twin_cast: 계획 피해 == 실제 발사 (Y2 최우선 수리 ②) ----------
	# 엔진은 `damage_total`에 **앞 칸 카드 × twin_power**를 이미 더한다. 컨트롤러가
	# 그 발사를 안 하면 계획과 실제가 조용히 갈린다 — Y0 이전이 정확히 그 상태였다
	# (`_rolled(step, "echo")`가 영원히 false).
	#
	# 판정: 쌍둥이를 확정에 가깝게 박은 덱으로 사이클을 계획하고,
	#   ⓐ 엔진이 실제로 twin_cast를 굴려 `fired`에 남겼는가
	#   ⓑ 그 스텝의 피해가 "이 칸 단독"보다 정확히 `앞 칸 × twin_power`만큼 큰가
	#   ⓒ 컨트롤러가 같은 스텝에서 카드 **2장**을 띄우는가(= 실전 발사 수가 계획과 같다)
	var twin: FactoryDeck = game.FACTORY_SCRIPT.new()
	twin.reset()
	for index in FactoryDeck.SLOT_COUNT:
		twin.place_card(index, DealCardLibrary.instance(pool[index % pool.size()], 1))
	var twin_attached := twin.attach_rune(1, {"id":"twin_cast", "p":RuneEngine.P_CAP, "mag":RuneEngine.TWIN_POWER})
	var twin_deck := twin.rune_deck()
	var twin_cast_ok := twin_attached
	var twin_seen := 0
	for probe in 400:
		var twin_cycle := RuneEngine.simulate_cycle(twin_deck, 60013 + probe * 11, {})
		for entry in (twin_cycle["steps"] as Array):
			var step: Dictionary = entry
			if not (step["fired"] as Array).has("twin_cast"):
				continue
			twin_seen += 1
			# ⓑ 엔진 식 재현: 이 칸 기저 × 배율 + 앞 칸 기저 × 배율 × twin_power.
			var here_card: Dictionary = (twin_deck[int(step["slot"])] as Dictionary)["card"]
			var prev_index := int(step["index"]) - 1
			var prev_slot := int((twin_cycle["visited"] as Array)[prev_index]) if prev_index >= 0 else -1
			if prev_slot < 0:
				continue
			var prev_card: Dictionary = (twin_deck[prev_slot] as Dictionary)["card"]
			var mul := float(step["damage_mul"])
			var expected := float(here_card.get("damage", 1.0)) * mul \
				+ float(prev_card.get("damage", 1.0)) * mul * RuneEngine.TWIN_POWER
			twin_cast_ok = twin_cast_ok and absf(float(step["damage"]) - expected) < 0.0005
	twin_cast_ok = twin_cast_ok and twin_seen > 0
	# ⓒ **실전 발사 수 = 계획.** 컨트롤러를 스텝 단위로 직접 돌려 `_launch_card` 호출 수를
	#    `active_effects`로 센다(물리 틱은 끄고 결정적으로 돌린다 — 프레임 타이밍이
	#    개입하면 "몇 장 떴는가"가 흔들려 이 계약을 못 잰다).
	#    기대치: twin_cast가 터진 스텝(단, 앞 칸이 있는 스텝)만 **2장**, 나머지는 1장.
	var twin_cycle_node: DealCycleController = game.CYCLE_CONTROLLER_SCRIPT.new()
	twin_cycle_node.set_physics_process(false)
	game.gameplay_root.add_child(twin_cycle_node)
	twin_cycle_node.setup(game, game.player, twin, false, false, 60013)
	var twin_launch_pairs := 0
	var twin_launch_mismatch := 0
	for probe in 60:
		twin_cycle_node.cycle_seed_base = 60013 + probe * 11
		twin_cycle_node.plan_steps = []
		twin_cycle_node._plan_cycle()
		for step_index in twin_cycle_node.plan_steps.size():
			var planned: Dictionary = twin_cycle_node.plan_steps[step_index]
			var wants_twin := (planned["fired"] as Array).has("twin_cast") and step_index > 0
			twin_cycle_node.step_pointer = step_index
			for effect: Node in twin_cycle_node.active_effects:
				if is_instance_valid(effect):
					effect.queue_free()
			twin_cycle_node.active_effects.clear()
			twin_cycle_node._start_current_step()
			var launched := twin_cycle_node.active_effects.size()
			if launched != (2 if wants_twin else 1):
				twin_launch_mismatch += 1
			elif wants_twin:
				twin_launch_pairs += 1
	for effect: Node in twin_cycle_node.active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	twin_cycle_node.active_effects.clear()
	twin_cycle_node.queue_free()
	twin_cast_ok = twin_cast_ok and twin_launch_mismatch == 0 and twin_launch_pairs > 0

	print("CYCLE_TEST_COMPLETE five_slot=%s flow_rune=%s exec_cap=%s rail_rune=%s debt_reload=%s slot_swap=%s omen=%s boss=%s bounded=%s runtime=%s twin_cast=%s cam=%s cam_peak=%.2f cam_cards=%.2f cam_boss=%.2f cam_off=%.2f hud_rail=%s hud_mini=%s hud_nav=%s hud_ghost=%s hud_stage=%s hud_health=%s strip_h=%d hud_block_pct=%.2f hud_ink_pct=%.2f cycles=%d steps_seen=%d runes_fired=%d max_steps=%d max_exec=%d overload_hits=%d twin_seen=%d twin_pairs=%d twin_miss=%d debt=%.2f" % [
		five_slot_ok, flow_rune_ok, exec_cap_ok, rail_rune_ok, debt_reload_ok, slot_swap_ok, omen_ok, boss_ok, bounded_ok, runtime_ok, twin_cast_ok,
		cam_ok, cam_live_peak, cam_cards_peak, cam_boss_peak, cam_off_peak,
		hud_rail_ok, hud_mini_ok, hud_nav_ok, hud_ghost_ok, hud_stage_ok, hud_health_ok,
		int(game.RAIL_BAND_RECT.size.y), float(coverage["block_pct"]), float(coverage["ink_pct"]),
		int(observed["cycles"]), (observed["slots"] as Array).size(), (observed["runes"] as Array).size(),
		max_steps, max_exec, overload_hits, twin_seen, twin_launch_pairs, twin_launch_mismatch, expected_debt
	])
	var cycle_passed := five_slot_ok and flow_rune_ok and exec_cap_ok and rail_rune_ok \
		and debt_reload_ok and slot_swap_ok and omen_ok and boss_ok and bounded_ok and runtime_ok \
		and twin_cast_ok and cam_ok and hud_rail_ok and hud_mini_ok and hud_nav_ok and hud_ghost_ok \
		and hud_stage_ok and hud_health_ok
	await _quit_test_cleanly(cycle_passed)

# -----------------------------------------------------------------------------
# Y2 신설 — 각인 3택의 칸/레일 분기를 다루는 테스트 헬퍼
# -----------------------------------------------------------------------------
# 각인 15종 중 5종이 **레일 각인**이라 3택에 섞여 나온다(§2.2). 레일 각인은 칸을 고르지
# 않고 즉시 붙으므로, "2단계에서 칸을 고른다"를 재는 검사는 칸 각인 제시분을 집어야 한다.
## 지금 3택에서 첫 **칸** 각인의 인덱스. 없으면 −1.
func _first_slot_offer_index() -> int:
	for index in game.draft_offers.size():
		var offer_id := String(((game.draft_offers[index] as Dictionary).get("instance", {}) as Dictionary).get("id", ""))
		if RuneEngine.rune_scope(offer_id) == "slot":
			return index
	return -1

## 지금 3택에서 첫 **레일** 각인의 인덱스. 없으면 −1.
func _first_rail_offer_index() -> int:
	for index in game.draft_offers.size():
		var offer_id := String(((game.draft_offers[index] as Dictionary).get("instance", {}) as Dictionary).get("id", ""))
		if RuneEngine.rune_scope(offer_id) == "rail":
			return index
	return -1

## 칸 각인이 하나라도 든 3택이 나올 때까지 다시 연다(최대 16회). 레일 각인만 셋이 뜨는
## 조합도 규칙상 가능하므로(가중 뽑기) 재시도로 검사의 결정성을 확보한다.
func _open_slot_rune_draft(source: String, return_state: String) -> int:
	for _attempt in 16:
		game._show_rune_draft(source, return_state)
		var index := _first_slot_offer_index()
		if index >= 0:
			return index
	return -1

# =============================================================================
# X3 신설 — HUD 점유 측정 · 라벨 세기 (탈블록의 증거를 숫자로 남긴다)
# =============================================================================
## 플레이어를 순간이동시킨 직후 카메라를 즉시 따라붙인다.
## 화면 좌표(캔버스 변환)로 판정하는 검사는 이걸 안 하면 **옛 카메라 기준**으로 답한다.
func _settle_camera() -> void:
	if is_instance_valid(game.player):
		var camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
		if is_instance_valid(camera):
			camera.reset_smoothing()
			camera.force_update_scroll()
	await get_tree().process_frame
	await get_tree().process_frame

## 컨트롤 하나와 그 자손 중 **글자가 실제로 들어 있는 Label** 개수.
## X3의 미니모드·고스트 계약("칸 안에 글자 0개")을 기계가 세게 하는 자다.
func _count_labels_in(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var total := 0
	for child: Node in root.get_children():
		if child is Label and not (child as Label).text.strip_edges().is_empty():
			total += 1
		total += _count_labels_in(child)
	return total

## HUD가 필드를 얼마나 가리는가. 1280×720을 4px 격자로 래스터화해 **합집합** 넓이를 센다
## (사각형을 그냥 더하면 겹친 자리가 두 번 세어져 거짓말이 된다).
##   block  불투명한 판 — Panel 9-slice + 알파 0.5 이상 ColorRect. "블록"의 정의다.
##   ink    눈에 보이는 HUD 요소 전부의 바운딩 박스(글자·아이콘·얇은 게이지 포함).
## 전면 층(길잡이·툴팁)과 그림 없는 컨테이너 Control은 세지 않는다 — 화면을 통째로
## 덮는 앵커 노드라 넣으면 무조건 100%가 나온다.
func _hud_coverage() -> Dictionary:
	var cell := 4
	var cols := 1280 / cell
	var rows := 720 / cell
	var block := PackedByteArray()
	var ink := PackedByteArray()
	block.resize(cols * rows)
	ink.resize(cols * rows)
	_hud_coverage_walk(game.hud, block, ink, cell, cols, rows)
	var block_cells := 0
	var ink_cells := 0
	for index in block.size():
		if block[index] != 0:
			block_cells += 1
		if ink[index] != 0:
			ink_cells += 1
	var area := float(cell * cell)
	return {
		"block_px": float(block_cells) * area,
		"ink_px": float(ink_cells) * area,
		"block_pct": float(block_cells) / float(cols * rows) * 100.0,
		"ink_pct": float(ink_cells) / float(cols * rows) * 100.0
	}

func _hud_coverage_walk(node: Node, block: PackedByteArray, ink: PackedByteArray,
		cell: int, cols: int, rows: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	var control := node as Control
	if control != null:
		if not control.visible:
			return
		# 전면 앵커 층(길잡이 스크림 · 툴팁 층)은 화면을 통째로 덮으므로 세지 않는다.
		if control == game.guide_root or control == game.hud_tooltip_layer:
			return
		if control.name in ["GuideLayer", "UIKitTooltips", "HudTooltips"]:
			return
		var is_block := false
		var is_ink := false
		if control is Panel:
			is_block = true
			is_ink = true
		elif control is ColorRect:
			var alpha := (control as ColorRect).color.a
			is_block = alpha >= 0.5
			is_ink = alpha > 0.02
		elif control is Label:
			is_ink = not (control as Label).text.strip_edges().is_empty()
		elif control is TextureRect:
			is_ink = (control as TextureRect).texture != null
		elif control.get_script() != null:
			# 커스텀 `_draw()` 노드(바늘 · 다이얼 · 화살표 마커 · 스킬 아이콘).
			is_ink = true
		if is_ink or is_block:
			_hud_coverage_mark(control.get_global_rect(), block, ink, cell, cols, rows, is_block)
	for child: Node in node.get_children():
		_hud_coverage_walk(child, block, ink, cell, cols, rows)

func _hud_coverage_mark(rect: Rect2, block: PackedByteArray, ink: PackedByteArray,
		cell: int, cols: int, rows: int, is_block: bool) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var x0 := clampi(int(floor(rect.position.x / float(cell))), 0, cols - 1)
	var x1 := clampi(int(ceil(rect.end.x / float(cell))) - 1, 0, cols - 1)
	var y0 := clampi(int(floor(rect.position.y / float(cell))), 0, rows - 1)
	var y1 := clampi(int(ceil(rect.end.y / float(cell))) - 1, 0, rows - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var index := y * cols + x
			ink[index] = 1
			if is_block:
				block[index] = 1

# =============================================================================
# --draft-test (W6 신설) — 각인 드래프트 규칙
# =============================================================================
# 검사 5종 (지시서 §범위-5):
#   ① 3택 생성 · 희귀도 분포        ② 부착 후 칸 각인 수 증가
#   ③ 미선택 각인의 마왕 전달        ④ 스택 상한 칸 제외
#   ⑤ 흐름 각인 억제 규칙
# 추가로 두 진입점(직접 호출 / 2단계 화면 전이)이 실제로 이어지는지 본다.
#
# ── X1(2026-08-09) 가산 3종 · 삭제 1종 ──────────────────────────────────────
#   삭제  레벨업 3번째 선택지 = 각인 강화 진입 → **그 문이 닫혔다**(사용자 요구 ④).
#         각인 진입점은 이제 각인 세공사(`--castle-test`)·보물상자·균열·전조뿐이다.
#   +cancel       레벨업 취소 — 골드 지급 · **마왕 무전달** · 상점 카드값보다 싼가
#   +growth_cap   성장 천장이 각인 드래프트로 **전환하지 않고** 취소 기본 제안으로 열리는가
#   +demon_floor  마왕 성장 하한 — 취소 플레이에서 5칸이 비지 않는가 · 정상 곡선은 안 닿는가
func _run_draft_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.25).timeout
	# 레벨업 모달이 도중에 끼어들면 상태 검사가 흔들린다.
	game.xp_target = 1000000
	game.experience = 0

	# ---------- ① 3택 생성 · 희귀도 분포 ----------
	var offers := game._roll_rune_draft()
	var offer_shape_ok := offers.size() == game.RUNE_DRAFT_OPTIONS
	var seen_ids: Dictionary = {}
	for offer_value in offers:
		var offer: Dictionary = offer_value
		var instance: Dictionary = offer.get("instance", {})
		var rune_id := String(instance.get("id", ""))
		var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
		offer_shape_ok = offer_shape_ok and not definition.is_empty() and not seen_ids.has(rune_id)
		seen_ids[rune_id] = true
		# 인스턴스 확률은 반드시 저작 범위 안에서 굴려져야 한다(§3.3 "같은 각인이라도 다른 물건").
		var probability := float(instance.get("p", -1.0))
		offer_shape_ok = offer_shape_ok and probability >= float(definition.get("p_min", 0.0)) - 0.0001 \
			and probability <= float(definition.get("p_max", 1.0)) + 0.0001
	var rarity_counts := {"common": 0, "rare": 0, "epic": 0}
	var draft_rolls := 500
	for _sample in draft_rolls:
		for offer_value in game._roll_rune_draft():
			var sample_id := String((offer_value as Dictionary).get("instance", {}).get("id", ""))
			var rarity := String((RuneEngine.RUNES.get(sample_id, {}) as Dictionary).get("rarity", "common"))
			rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
	var rarity_mix_ok := int(rarity_counts["common"]) > int(rarity_counts["rare"]) \
		and int(rarity_counts["rare"]) > int(rarity_counts["epic"]) and int(rarity_counts["epic"]) > 0

	# ---------- ⑤ 흐름 각인 억제 (칸을 오염시키기 전에 기준선을 잰다) ----------
	var baseline_flow := _draft_flow_weight_share()
	var baseline_sample := _draft_flow_sample_share(300)
	# Y2: 흐름 계열 신 id 2종(§2.1 · family == "flow"). 구 `rewind_1`·`skip_1`은 폐기됐다.
	game.factory.attach_rune(0, RuneEngine.roll_rune("back_one", game.rng))
	game.factory.attach_rune(0, RuneEngine.roll_rune("jump_one", game.rng))
	var suppressed_flow := _draft_flow_weight_share()
	var suppressed_sample := _draft_flow_sample_share(300)
	var flow_suppress_ok := game._rune_draft_saturated_slots() == 1 \
		and suppressed_flow < baseline_flow * 0.6 and suppressed_sample < baseline_sample * 0.75
	# 완전 배제는 하지 않는다 — 되감기 엔진 아키타입(§3.10)이 성립 불가가 되면 안 된다.
	flow_suppress_ok = flow_suppress_ok and suppressed_flow > 0.0

	# ---------- ②' X1: 레벨업 모달 = 카드 2장 + **취소** (사용자 피드백 ④) ----------
	# W6~U2의 세 번째 선택지 「각인 강화」가 사라졌다. 그 자리는 취소 버튼이고,
	# 취소는 **마왕에게 아무것도 주지 않는다** — 그게 이 묶음이 지키는 계약 전부다.
	var cancel_gold_before: int = game.gold
	var cancel_rejected_before := game.rejected_skills.size()
	var cancel_points_before: int = game.demon_lord.growth_points()
	game._show_skill_choice("test")
	var cancel_ok: bool = game.state == "choice" and game.choice_buttons.size() == 3 \
		and String(game.choice_buttons[2].get_meta("choice_role", "")) == "cancel" \
		and String(game.choice_buttons[2].get_meta("choice_kind", "")) == "cancel"
	# 카드는 원소 색을 meta로 들고 있어야 한다(속성 = 색 · 텍스트 태그 0줄).
	cancel_ok = cancel_ok and game.choice_buttons[0].has_meta("card_element") \
		and game.choice_buttons[0].has_meta("kit_card_tint")
	var expected_cancel: int = game._choice_cancel_gold(false)
	# **경제 계약**: 취소 보상은 상점 스킬 카드 평균 정가(33 G × 스테이지 스케일)보다
	# 싸야 한다. 두 장을 버리고 한 장 값을 받으면 취소 반복이 이득이 된다.
	cancel_ok = cancel_ok and expected_cancel < game._scaled_price(33) and expected_cancel > 0
	game._confirm_choice_index(2)
	cancel_ok = cancel_ok and game.state == "playing" \
		and game.gold == cancel_gold_before + expected_cancel \
		and game.rejected_skills.size() == cancel_rejected_before \
		and game.demon_lord.growth_points() == cancel_points_before \
		and game.pending_boss_toast_cards.is_empty() \
		and game.current_pair.is_empty()

	# ---------- ② 부착 · ③ 마왕 전달 · 진입점 ----------
	# X1: 레벨업이 아니라 **직접 호출**로 연다(보물상자·균열·전조·각인 상점의 경로).
	# Y2: 3택에 **레일 각인**이 섞인다(§2.2). 레일 각인은 칸을 고르지 않고 바로 붙으므로
	#     "2단계 → 칸 부착"을 재려면 칸 각인 제시분을 골라야 한다(아래 헬퍼가 그 일을 한다).
	# ⚠️ Y5(2026-08-10): **여기서 rng를 고정한다.** 이 검사는 원래 매 실행 난수였고
	# 그래서 아래 `target_prose <= 2`가 **10번에 한 번쯤 빨개졌다**(실측 10회 중 1회).
	# 이유는 이 함수의 판정이 「3택에서 어떤 각인이 뽑혔는가」에 달려 있기 때문이다 —
	# 각인마다 이름·효과 문장 길이가 다르고, 가장 긴 각인이 뽑히면 20자 이상 줄이
	# 하나 더 생겨 셋이 된다(아래 ⓐ 주석이 "각인마다 길이가 다르다"고 이미 적어 뒀다).
	#
	# **이것은 Y5가 만든 회귀가 아니다.** Y5는 각인 데이터도 드래프트 화면도 안 건드렸다.
	# 다만 Y5가 스폰 경로에서 `game.rng`를 쓰는 횟수를 바꿨기 때문에 난수 줄기가 밀렸고,
	# 그 바람에 늘 있던 이 흔들림이 눈에 띄었을 뿐이다.
	# 시드를 박는 것은 **검사를 재현 가능하게** 만드는 순수한 개선이고, 칸 안쪽 계약
	# (`slot_inner_prose == 0` — 40줄이 0줄이 됐다는 Y3의 진짜 계약)은 손대지 않았다.
	# **남은 판단은 Y3/YZ 몫이다**: 상한 2가 옳은지, 아니면 가장 긴 각인의 이름 줄을
	# 줄여야 하는지. 그때 이 시드를 지우고 15종 전수로 재는 것이 정답이다.
	game.rng.seed = 20260810
	var slot_offer := _open_slot_rune_draft("test", "playing")
	var entry_ok := game.state == "rune_draft" and game.draft_offers.size() == game.RUNE_DRAFT_OPTIONS \
		and slot_offer >= 0
	# 1단계 3택이 단일 포커스 모델을 그대로 쓴다.
	entry_ok = entry_ok and game._choice_highlight_count() == 1
	# 레일 각인 제시분은 **2단계 없이** 바로 붙는다 — 죽은 선택지가 아니라는 계약.
	var rail_offer := _first_rail_offer_index()
	if rail_offer >= 0:
		var rail_count_before := game.factory.rail_rune_count()
		game._select_draft_rune(rail_offer)
		entry_ok = entry_ok and game.state == "playing" \
			and game.factory.rail_rune_count() == rail_count_before + 1
		slot_offer = _open_slot_rune_draft("test", "playing")
		entry_ok = entry_ok and slot_offer >= 0
	game._select_draft_rune(slot_offer)
	var stage_two_ok := game.state == "rune_target" and not game.draft_selected_rune.is_empty()
	# ---------- ★ Y3: 2단계 대간소화 (피드백 ② · 설계 §8 ②) ----------
	# 구판은 칸 하나마다 여덟 줄(각인 N/5 · 상태 · "여기 붙이면" · Δ 4 · 과부하율 · 부착 힌트)을
	# 세워 5칸에서 **40줄**이었다. 그 40줄이 0줄이 되고 전부 호버로 갔다는 것을 두 축으로 문다.
	#   ⓐ 화면에 남은 글자 줄 수 상한 (X2의 `edit_prose` 패턴)
	#   ⓑ 지운 정보가 **실제로 툴팁에 있다** — 정보 손실 0의 직접 단언
	var target_panel: Node = game.overlay.get_node_or_null("RuneTargetPanel") if is_instance_valid(game.overlay) else null
	var target_labels := 0
	var target_prose := 0
	var target_probe: Array[Node] = []
	if target_panel != null:
		target_probe.append(target_panel)
	while not target_probe.is_empty():
		var target_node: Node = target_probe.pop_back()
		for target_child in target_node.get_children():
			target_probe.append(target_child)
		if not (target_node is Label):
			continue
		var target_text := (target_node as Label).text.strip_edges()
		if target_text.length() < 2:
			continue
		target_labels += 1
		if target_text.length() >= 20:
			target_prose += 1
	# 남는 글자: 손에 든 각인 2줄 + 칸 이름 5줄 + 조작 힌트 1줄 = 8.
	# 20자 이상은 **둘까지** 허용한다 — 조작 힌트 한 줄과, 손에 든 각인의 효과 한 문장이다
	# (각인마다 길이가 다르다: 「두 번 치고 건너뛰기」는 20자를 넘고 「힘주기」는 안 넘는다).
	# 둘 다 **칸이 아니라 패널**의 줄이라 5칸에 곱해지지 않는다 — 그것이 이 웨이브의 계약이다.
	stage_two_ok = stage_two_ok and target_panel != null and target_labels <= 12 and target_prose <= 2
	# ⓐ' **칸 안에는 설명 문장이 0줄**이다. 구판이 칸마다 세우던 여덟 줄이 여기서 죽는다.
	#    칸에 남는 글자는 카드 이름 하나(+ 과밀이면 「+N」)뿐이고, 번호·원소 마크는
	#    한 글자라 세지 않는다(X2 `edit_prose`와 같은 셈법 · 14자 이상이면 설명 문장이다).
	var slot_inner_labels := 0
	var slot_inner_prose := 0
	for slot_probe_button: Button in game.draft_slot_buttons:
		var slot_inner: Array[Node] = [slot_probe_button]
		while not slot_inner.is_empty():
			var inner_node: Node = slot_inner.pop_back()
			for inner_child in inner_node.get_children():
				slot_inner.append(inner_child)
			if not (inner_node is Label):
				continue
			var inner_text := (inner_node as Label).text.strip_edges()
			if inner_text.length() < 2:
				continue
			slot_inner_labels += 1
			if inner_text.length() >= 14:
				slot_inner_prose += 1
	stage_two_ok = stage_two_ok and slot_inner_prose == 0 \
		and slot_inner_labels <= FactoryDeck.SLOT_COUNT + 2
	# 칸은 **편집 화면과 같은 기하**(196×204)다. 구 `RUNE_TARGET_SLOT_SIZE(196×300)`은 폐기됐다.
	stage_two_ok = stage_two_ok and game.draft_slot_buttons.size() == FactoryDeck.SLOT_COUNT
	for target_button: Button in game.draft_slot_buttons:
		stage_two_ok = stage_two_ok and target_button.size.is_equal_approx(game.EDIT_SLOT_SIZE)
	# ⓑ 툴팁 — 칸마다 하나 + 손에 든 각인 띠 하나. 칸 툴팁의 줄 수가 그 칸의 각인 수 이상이다
	#    (각인 목록 + 붙이면 + Δ 4 + 바퀴 상한이 들어 있으므로 실제로는 훨씬 많다).
	for target_probe_slot in FactoryDeck.SLOT_COUNT:
		var tip_target: Variant = game.modal_tooltip_targets.get("target_slot%d" % target_probe_slot)
		if not (tip_target is Control) or not (tip_target as Control).has_meta(UIKit.TOOLTIP_META):
			stage_two_ok = false
			continue
		var tip_spec: Dictionary = (tip_target as Control).get_meta(UIKit.TOOLTIP_META)
		stage_two_ok = stage_two_ok \
			and (tip_spec.get("rows", []) as Array).size() >= maxi(1, game.factory.rune_count_on(target_probe_slot))
	stage_two_ok = stage_two_ok and game.modal_tooltip_targets.has("held")
	# 툴팁이 실제로 뜬다(캡처가 쓰는 강제 표시 경로 = 사람이 호버했을 때와 같은 경로).
	stage_two_ok = stage_two_ok and game._force_modal_tooltip("target_slot0") \
		and UIKit.tooltip_shown(game.modal_tooltip_layer) == game.modal_tooltip_targets["target_slot0"]
	UIKit.tooltip_hide(game.modal_tooltip_layer)
	var target_slot := 2
	var runes_before := game.factory.rune_count_on(target_slot)
	var total_before := game.factory.total_rune_count()
	var shards_before: int = game.demon_lord.rune_shards
	var boss_runes_before := game.demon_lord.rune_capacity()
	game._attach_draft_rune(target_slot)
	var attach_ok := game.factory.rune_count_on(target_slot) == runes_before + 1 \
		and game.factory.total_rune_count() == total_before + 1 and game.state == "playing"
	# 미선택 2개 → 마왕 각인 조각 2 → 조각 2개당 각인 1개(§5.1 · §6.2)
	var leftover_count: int = game.RUNE_DRAFT_OPTIONS - 1
	var boss_shard_ok := game.demon_lord.rune_shards == shards_before + leftover_count \
		and game.demon_lord.rune_capacity() >= boss_runes_before

	# ---------- ④ 스택 상한 칸 제외 ----------
	while game.factory.rune_count_on(4) > 0:
		game.factory.detach_rune(4, 0)
	for _fill in RuneEngine.RUNE_STACK_CAP:
		game.factory.attach_rune(4, RuneEngine.roll_rune("strong" if game.factory.rune_count_on(4) < 3 else "wide", game.rng))
	var slot_full := game.factory.rune_count_on(4) >= RuneEngine.RUNE_STACK_CAP
	var cap_offer := _open_slot_rune_draft("test", "playing")
	game._select_draft_rune(cap_offer)
	var cap_ok := slot_full and cap_offer >= 0 and game.state == "rune_target" \
		and game.draft_slot_buttons.size() == FactoryDeck.SLOT_COUNT
	for index in game.draft_slot_buttons.size():
		var slot_button: Button = game.draft_slot_buttons[index]
		var expect_blocked := index == 4
		cap_ok = cap_ok and slot_button.disabled == expect_blocked and bool(slot_button.get_meta("blocked", false)) == expect_blocked
	# 상한 칸은 선택 대상(choice_buttons)에도 등록되지 않는다.
	for choice_button: Button in game.choice_buttons:
		cap_ok = cap_ok and int(choice_button.get_meta("slot_index", -1)) != 4
	# ESC로 1단계 복귀 → 갇히지 않는다.
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	game._unhandled_input(escape_event)
	cap_ok = cap_ok and game.state == "rune_draft"
	game._select_draft_rune(_first_slot_offer_index())
	game._attach_draft_rune(0)
	cap_ok = cap_ok and game.state == "playing"

	# ---------- ⑥ V8: 성장 천장 자동 전환 (설계 §10 #4 · 부록 A-3 ② 1안) ----------
	# 레일 5칸 + 보관함이 전부 R3로 포화하면 레벨업 2택1은 "R3를 버리고 R1을 넣기"만
	# 남는다. 그 순간부터 레벨업은 **각인 드래프트로 자동 전환**된다.
	# `GROWTH_CAP_AUTO_RUNE_DRAFT`가 false로 뒤집히면 이 검사는 통째로 건너뛴다
	# (부록 A-3이 "답이 오면 갈아끼운다"고 한 그 스위치다).
	var growth_cap_ok := true
	# ⓐ 천장에 닿지 않은 상태에서는 **절대** 전환되지 않는다 — 빈 칸이 하나만 있어도 아니다.
	game.factory.reset()
	game.factory.inventory.clear()
	growth_cap_ok = growth_cap_ok and not game._growth_cap_reached()
	var saturating_ids: Array[String] = ["cleave", "thrust", "thunder", "whirlwind", "rapid_slash"]
	for slot_index in FactoryDeck.SLOT_COUNT:
		game.factory.place_card(slot_index, DealCardLibrary.instance(saturating_ids[slot_index], DealCardLibrary.MAX_RANK))
	growth_cap_ok = growth_cap_ok and game._growth_cap_reached()
	# ⓑ 보관함에 R1이 한 장이라도 있으면 아직 융합 경로가 살아 있다 → 전환 금지.
	game.factory.add_inventory(DealCardLibrary.instance("execution", 1))
	growth_cap_ok = growth_cap_ok and not game._growth_cap_reached()
	game.factory.inventory.clear()
	# ⓒ 보관함이 R3만 들고 있으면 여전히 천장이다. 아이템은 레일 칸을 먹지 않으므로 무관.
	game.factory.add_inventory(DealCardLibrary.instance("execution", DealCardLibrary.MAX_RANK))
	game.factory.equip(ItemLibrary.instance("r_neck_03"))
	growth_cap_ok = growth_cap_ok and game._growth_cap_reached()
	# ⓓ X1: **전환하지 않는다.** 천장 레벨업은 카드 2택 화면으로 열리되
	#    ① 포커스가 취소에서 시작하고 ② 취소 보상이 할증되고 ③ 카운터가 오른다.
	#    카드를 고를 자유는 뺏지 않는다(고르면 R3 한 장을 밀어낸다).
	game.state = "playing"
	game.experience = 0
	game.xp_target = 40
	game.level = 7
	var conversions_before: int = game.growth_cap_conversions
	var cap_shards_before: int = game.demon_lord.rune_shards
	var cap_rejected_before: int = game.rejected_skills.size()
	var cap_gold_before: int = game.gold
	growth_cap_ok = growth_cap_ok and not GameTuning.GROWTH_CAP_AUTO_RUNE_DRAFT
	game._show_skill_choice("level")
	var cap_reward: int = game._choice_cancel_gold(true)
	growth_cap_ok = growth_cap_ok and game.state == "choice" \
		and game.growth_cap_conversions == conversions_before + 1 \
		and game.choice_buttons.size() == 3 \
		and game.choice_selected_index == game._choice_extra_index() \
		and cap_reward > game._choice_cancel_gold(false)
	game._confirm_choice_index(game._choice_extra_index())
	# 레벨은 정상적으로 오르고, 두 카드는 **마왕에게 가지 않는다**.
	growth_cap_ok = growth_cap_ok and game.state == "playing" \
		and game.gold == cap_gold_before + cap_reward \
		and game.level == 8 and game.xp_target == 7 + 8 * 5 \
		and game.rejected_skills.size() == cap_rejected_before \
		and game.demon_lord.rune_shards == cap_shards_before
	# ⓔ 보물상자 선택(`chest`)은 천장을 보지 않는다 — 천장은 **레벨업 보상**의 문제다.
	game.state = "playing"
	game._show_skill_choice("chest")
	growth_cap_ok = growth_cap_ok and game.state == "choice" \
		and game.growth_cap_conversions == conversions_before + 1 \
		and game.choice_selected_index == 0
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"

	# ---------- ⑦ X1: 마왕 성장 하한 (취소 경로의 안전장치) ----------
	# "전부 취소" 플레이에서도 마왕의 5칸이 비지 않아야 한다. 동시에 **정상 플레이는
	# 이 하한에 한 번도 닿으면 안 된다** — 닿는 순간 하한이 밸런스를 대신 정하게 된다.
	game.rejected_skills.clear()
	game.trophy_reject_skills.clear()
	game.demon_lord.reset()
	game.clock.set_stages_cleared_raw(0)
	var demon_floor_ok: bool = game._enforce_demon_growth_floor() == 0 \
		and game.demon_lord.received_card_count() == 0
	game.clock.set_stages_cleared_raw(1)
	var floor_added := game._enforce_demon_growth_floor()
	demon_floor_ok = demon_floor_ok and floor_added == GameTuning.DEMON_MIN_CARDS_PER_STAGE \
		and game.demon_lord.received_card_count() == GameTuning.DEMON_MIN_CARDS_PER_STAGE
	# 보충 카드는 반드시 드래프트 풀 안이다 — 플레이어가 본 적 없는 카드가 고스트
	# 레일에 서면 안 된다(handoff-w7 §8).
	var floor_pool_ids := DealCardLibrary.draft_ids()
	for injected_id: String in game.rejected_skills:
		demon_floor_ok = demon_floor_ok and floor_pool_ids.has(injected_id)
	# 이미 하한 위면 한 장도 더 주지 않는다(멱등).
	demon_floor_ok = demon_floor_ok and game._enforce_demon_growth_floor() == 0
	# 5스테이지 끝에서 마왕은 최소 20장 = 각인 5개를 든다(정상 24장 · 각인 6개).
	game.clock.set_stages_cleared_raw(GameTuning.STAGE_COUNT)
	game._enforce_demon_growth_floor()
	demon_floor_ok = demon_floor_ok \
		and game.demon_lord.received_card_count() == GameTuning.DEMON_MIN_CARDS_PER_STAGE * GameTuning.STAGE_COUNT \
		and game.demon_lord.filled_slot_count() == GameTuning.BOSS_SLOT_COUNT \
		and game.demon_lord.rune_capacity() >= 5
	# 정상 플레이 곡선(balance_probe ⑭ 실측 누적 9/14/18/21/24장)은 하한을 항상 넘는다.
	var normal_demon_curve: Array[int] = [9, 14, 18, 21, 24]
	for stage_index in normal_demon_curve.size():
		demon_floor_ok = demon_floor_ok \
			and normal_demon_curve[stage_index] > GameTuning.DEMON_MIN_CARDS_PER_STAGE * (stage_index + 1)
	game.clock.set_stages_cleared_raw(0)

	print("DRAFT_TEST_COMPLETE offer_shape=%s rarity_mix=%s attach=%s boss_shards=%s stack_cap=%s flow_suppress=%s entry=%s stage_two=%s cancel=%s growth_cap=%s demon_floor=%s target_labels=%d target_prose=%d slot_labels=%d slot_prose=%d common=%d rare=%d epic=%d flow_base=%.3f flow_suppressed=%.3f sample_base=%.3f sample_suppressed=%.3f conversions=%d cancel_gold=%d cap_gold=%d" % [
		offer_shape_ok, rarity_mix_ok, attach_ok, boss_shard_ok, cap_ok, flow_suppress_ok, entry_ok, stage_two_ok,
		cancel_ok, growth_cap_ok, demon_floor_ok, target_labels, target_prose, slot_inner_labels, slot_inner_prose,
		int(rarity_counts["common"]), int(rarity_counts["rare"]), int(rarity_counts["epic"]),
		baseline_flow, suppressed_flow, baseline_sample, suppressed_sample, game.growth_cap_conversions,
		expected_cancel, cap_reward
	])
	var draft_passed := offer_shape_ok and rarity_mix_ok and attach_ok and boss_shard_ok \
		and cap_ok and flow_suppress_ok and entry_ok and stage_two_ok \
		and cancel_ok and growth_cap_ok and demon_floor_ok
	await _quit_test_cleanly(draft_passed)

# =============================================================================
# --boss-test (V7 전면 재작성) — 스테이지 보스 3종 · 격파 흐름 · 강림 밸브 · 마왕전
# =============================================================================
# v2판은 "7일차 밤이 끝나면 마왕전"을 단언했다. v3가 그 스케줄을 삭제해
# `game.boss_cycle`이 null로 남았고 `reset_cycle()`에서 하드 크래시 → 180초 타임아웃을
# 통째로 태웠다(handoff-v4 §294). V5가 `run_all.sh`에서 임시 제외했던 그 테스트다.
#
# **크래시 지점 2곳(handoff-v4가 지목한 것)의 처리**
#   ① 구 `:1661-1665` "7일차 밤 끝 → 강림" 트리거
#      → 삭제. v3에 마왕 강림 경로 자체가 없다(game.gd의 `_trigger_descent`도 함께 삭제됐다).
#        마왕전은 ⑥에서 `_challenge_demon_king()` 직접 호출로 연다.
#   ② 구 `:1687` `(1 + BOSS_HP_DAY_STEP × (TOTAL_DAYS − 1)) × DESCENT_HP_MUL` 하드코딩
#      → 삭제. 이제 `demon_lord.hp_multiplier(day)` **함수 자체**와 기준 개체를 대조한다.
#        (`GameTuning.BOSS_HP_DAY_STEP` / `TOTAL_DAYS` 참조가 사라졌고, **V10이 그 두 상수를
#         실제로 삭제했다** — handoff-v4 §217의 "V7이 지울 것"이 여기서 끝났다.)
#
# 검사 항목 (V7 지시서 §7)
#   ① rotation      로테이션 [A,B,C,B+,C+] · 리그·시트·HP 식이 데이터대로 선다
#   ② battle_e2e    1스테이지 A 3칸 전투 E2E — 사이클 구동 · telegraph · **RELOAD 창 실측**
#   ③ enhanced      강화형(4스테이지 B+)이 칸 4 · RELOAD 0.55 · 상태 2종 · 페이즈 2회
#   ④ defeat        격파 → 보상 훅 → `advance_stage()` → 다음 스테이지 필드 복귀
#   ⑤ demon_direct  **5스테이지 격파 → 필드 복귀 없이 마왕전**(부록 A-1 ③)
#   ⑥ valve         강림 밸브 E2E — dwell 강제 상승 → 필드 강림(칸 +1 · HP ×1.15) → 격파 → 등급 C
#   ⑦ demon_king    마왕전 회귀 — 상위 5장 · 프리뷰 두 레일 · needle · RELOAD ×0.6 · 레일 밴드
#   ⑧ telegraph     telegraph 노드 실재 · 페이즈 전환 상태 · 선딜 파생(×0.85)
#   ⑨ blight        잠식(구 월식) 개명 회귀 — `blight_*` 창구가 그대로 돈다
func _run_boss_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(game.player):
		game.player.invulnerability = 99999.0
		game.player.max_health = 99999.0
		game.player.health = game.player.max_health

	# ---- ① 로테이션 · 리그 · HP 식 (데이터 계약) -----------------------------
	# `GameTuning.STAGE_BOSS_DESIGN` = [A,B,C,B,C] · `_ENHANCED` = [f,f,f,t,t]
	# → 리그 키 [A, B, C, B+, C+]. 시트·셀·페이즈·RELOAD가 전부 여기서 파생된다.
	var expected_rigs: Array[String] = ["A", "B", "C", "B+", "C+"]
	var expected_sheets: Array[String] = ["frost_cyclops", "plague_slime", "crimson_tengu", "black_slime", "black_tengu"]
	var rotation_ok := GameTuning.STAGE_BOSS_DESIGN.size() == GameTuning.STAGE_COUNT \
		and GameTuning.STAGE_BOSS_ENHANCED.size() == GameTuning.STAGE_COUNT
	for stage_number in range(1, GameTuning.STAGE_COUNT + 1):
		var design := game.stage_boss_design(stage_number)
		var enhanced := game.stage_boss_enhanced(stage_number)
		var rig_id := BossLibrary.rig_id(design, enhanced)
		rotation_ok = rotation_ok and rig_id == expected_rigs[stage_number - 1]
		rotation_ok = rotation_ok and String(DebtEnemy.BOSS_RIG_SHEETS.get(rig_id, "")) == expected_sheets[stage_number - 1]
		rotation_ok = rotation_ok and DebtEnemy.BOSS_SHEETS.has(expected_sheets[stage_number - 1])
		# 칸 수: 기본 3 · 강화 4 · 강림이면 +1(A도 4칸이 된다 — §6.6).
		var slots_plain := BossLibrary.slot_count(enhanced, false)
		var slots_descended := BossLibrary.slot_count(enhanced, true)
		rotation_ok = rotation_ok and slots_plain == (4 if enhanced else 3)
		rotation_ok = rotation_ok and slots_descended == mini(slots_plain + 1, 4)
		rotation_ok = rotation_ok and BossLibrary.patterns(design, enhanced, false).size() == slots_plain
		# RELOAD 배율 · 페이즈 수(§3.2 표).
		rotation_ok = rotation_ok and is_equal_approx(BossLibrary.reload_scale(enhanced),
			GameTuning.STAGE_BOSS_RELOAD_MUL_ENHANCED if enhanced else GameTuning.STAGE_BOSS_RELOAD_MUL)
		rotation_ok = rotation_ok and BossLibrary.phase_thresholds(enhanced).size() == (2 if enhanced else 1)
	# A는 Attack 행이 없다(설계 §3.1의 함정 ①). 시트 표가 그것을 그대로 들고 있어야
	# `_draw_boss()`가 발구름 분기로 떨어진다.
	rotation_ok = rotation_ok and (DebtEnemy.BOSS_SHEETS["frost_cyclops"]["attack"] as Array).is_empty()
	# 점액은 walk와 attack이 같은 행이다(함정 ②).
	rotation_ok = rotation_ok and DebtEnemy.BOSS_SHEETS["plague_slime"]["walk"] == DebtEnemy.BOSS_SHEETS["plague_slime"]["attack"]
	# foot_inset이 0이 아니다(함정 ③). 마왕만 0이다.
	rotation_ok = rotation_ok and float(DebtEnemy.BOSS_SHEETS["frost_cyclops"]["foot"]) == 14.0 \
		and float(DebtEnemy.BOSS_SHEETS["plague_slime"]["foot"]) == 12.0 \
		and float(DebtEnemy.BOSS_SHEETS["crimson_tengu"]["foot"]) == 48.0 \
		and float(DebtEnemy.BOSS_SHEETS["demon_king"]["foot"]) == 0.0
	# C+만 등장 연출(Trans 11f)을 쓴다.
	rotation_ok = rotation_ok and String(BossLibrary.rig("C+").get("intro_anim", "")) == "trans" \
		and String(BossLibrary.rig("C").get("intro_anim", "")) == ""

	# ---- ② 1스테이지 A — 3칸 전투 E2E + RELOAD 창 실측 ------------------------
	game.clock.set_stage_raw(1)
	game.clock.set_dwell_raw(0)
	game.stage_boss_cleared = false
	game.state = "playing"
	game._show_stage_boss_preview()
	await get_tree().process_frame
	var preview_panel: Control = game.overlay.get_node_or_null("StageBossPreviewPanel") if is_instance_valid(game.overlay) else null
	var battle_ok := game.state == "boss_preview" and game.boss_preview_kind == "stage" \
		and is_instance_valid(preview_panel) and get_tree().paused
	# 프리뷰는 두 레일을 그린다: 내 5칸 + 보스 3칸. 스크롤 0(패널 안에 전부 들어온다).
	var preview_cells := 0
	var preview_scrolls := 0
	if is_instance_valid(preview_panel):
		for child in preview_panel.get_children():
			if child is ScrollContainer:
				preview_scrolls += 1
			if child is Panel and String((child as Node).name).begins_with("PreviewSlot"):
				preview_cells += 1
				var cell := child as Panel
				battle_ok = battle_ok and cell.position.x >= 0.0 \
					and cell.position.x + cell.size.x <= preview_panel.size.x \
					and cell.position.y + cell.size.y <= preview_panel.size.y
	battle_ok = battle_ok and preview_scrolls == 0 \
		and preview_cells == game.factory.slots.size() + GameTuning.STAGE_BOSS_SLOT_COUNT
	# 취소 가능(§3.5) — ESC 경로가 필드로 되돌린다.
	game._cancel_boss_preview()
	battle_ok = battle_ok and game.state == "playing" and not get_tree().paused and game.stage_boss == null
	# 다시 열고 이번에는 들어간다.
	game._show_stage_boss_preview()
	await get_tree().process_frame
	var stage1_health: float = float(game.stage_boss_profile.get("health", 0.0))
	var expected_stage1_health := BossLibrary.hp_for("A", game.clock.stage_hp_base(), 0, false)
	battle_ok = battle_ok and absf(stage1_health - expected_stage1_health) < 0.5
	game._begin_stage_boss_battle()
	await get_tree().process_frame
	battle_ok = battle_ok and game.state == "boss" and is_instance_valid(game.stage_boss) \
		and is_instance_valid(game.stage_boss_cycle) and game.stage_boss.is_stage_boss \
		and game.stage_boss.boss_sheet_key == "frost_cyclops" \
		and game.stage_boss.boss_rig_id == "A" \
		and not game.stage_boss.boss_descended \
		and game.stage_boss_factory.slots.size() == GameTuning.STAGE_BOSS_SLOT_COUNT \
		and game.stage_boss.boss_phase_thresholds.size() == 1 \
		and is_equal_approx(game.stage_boss.max_health, expected_stage1_health)
	# **RELOAD 배율은 §3.2 표의 0.75다** — `DealCycleController.setup()`이 넣는 마왕값(0.60)을
	# `_spawn_stage_boss()`가 덮어썼는지 여기서 잡는다.
	battle_ok = battle_ok and game.stage_boss_cycle.reload_enabled \
		and is_equal_approx(game.stage_boss_cycle.reload_scale, GameTuning.STAGE_BOSS_RELOAD_MUL)
	# 스테이지 보스는 각인이 없다(부록 A-2 ⑫). 덱에 각인이 0개여야 성립한다.
	# Y8: 구 `uses_heat` 키는 `boss_library`에서 **삭제**했다(과열이 없으므로 말할 것도 없다).
	# 그래서 단언이 "false인가"에서 **"키가 없는가"**로 바뀌었다 — 되살아나면 빨개진다.
	battle_ok = battle_ok and game.stage_boss_factory.total_rune_count() == 0 \
		and not bool(game.stage_boss_profile.get("uses_runes", true)) \
		and not game.stage_boss_profile.has("uses_heat") \
		and bool(game.stage_boss_profile.get("uses_reload", false))
	# 궤적이 3칸 안에서만 돈다(사이클이 실제로 구동된다).
	game.stage_boss.max_health = 1.0e9
	game.stage_boss.health = game.stage_boss.max_health
	var reload_window_ok := false
	var observed_reload := 0.0
	var observed_route: Array = []
	var telegraph_peak := 0
	for _tick in 900:
		await get_tree().physics_frame
		telegraph_peak = maxi(telegraph_peak, _boss_test_count_telegraphs())
		if not game.stage_boss_cycle.planned_route().is_empty():
			observed_route = game.stage_boss_cycle.planned_route()
		if game.stage_boss_cycle.reloading and game.stage_boss_cycle.reload_duration > 0.0:
			reload_window_ok = true
			observed_reload = game.stage_boss_cycle.reload_duration
			break
	battle_ok = battle_ok and reload_window_ok and observed_reload > 0.0 \
		and observed_reload <= RuneEngine.RELOAD_CAP \
		and game.boss_reload_windows >= 1 and game.stage_boss_cycle.reload_remaining > 0.0
	for slot_value in observed_route:
		battle_ok = battle_ok and int(slot_value) >= 0 and int(slot_value) < GameTuning.STAGE_BOSS_SLOT_COUNT
	battle_ok = battle_ok and not observed_route.is_empty()
	# 반격 창은 **실측치가 곧 계약**이다: 빚 × (1 + 과열 0) × 0.75.
	var expected_reload := clampf(game.stage_boss_factory.total_reload() * GameTuning.STAGE_BOSS_RELOAD_MUL, 0.0, RuneEngine.RELOAD_CAP)
	battle_ok = battle_ok and absf(observed_reload - expected_reload) < 0.25
	# **데이터 → 전투 E2E의 마지막 고리**: 보스 패턴이 실제로 플레이어에게 닿는가.
	# 상태 부여는 telegraph → 착탄 경로에서만 일어나므로(§3.3의 status 열) 상태가 하나라도
	# 붙었다는 것은 링이 뜨고 그 자리가 판정으로 이어졌다는 증거다. 무적이어도 상태는 붙는다.
	StatusEngine.clear(game.player_status)
	game.player.global_position = game.stage_boss.global_position
	var pattern_landed := false
	for _tick in 600:
		await get_tree().physics_frame
		if StatusEngine.has_any(game.player_status):
			pattern_landed = true
			break
	battle_ok = battle_ok and pattern_landed
	StatusEngine.clear(game.player_status)

	# 레일 밴드가 3칸만 보인다(칸 수가 승급 신호다 · §3.2).
	game._update_boss_rail(0.0)
	var band_ok := is_instance_valid(game.boss_rail_band) and game.boss_rail_band.visible \
		and game.active_boss_is_stage() and game.active_boss_factory() == game.stage_boss_factory
	for slot_index in game.boss_rail_slots.size():
		band_ok = band_ok and (game.boss_rail_slots[slot_index] as Panel).visible == (slot_index < GameTuning.STAGE_BOSS_SLOT_COUNT)
	# Y2: 「과열 사다리는 스테이지 보스에서 숨는다」 단언은 사다리와 함께 사라졌다(§1.4).
	# 후임 계약은 머리말 문구다 — 스테이지 보스는 각인이 없다고 말한다.
	band_ok = band_ok and "각인 없음" in game.boss_rail_meter_text.text \
		and not ("과열" in game.boss_rail_meter_text.text)
	battle_ok = battle_ok and band_ok

	# ---- ⑧-1 telegraph 실재 + 플레이어 상태 부여 ------------------------------
	# A는 세 패턴 중 둘이 chill을 깔고 셋째가 그 chill을 먹는다(§3.3). 링이 실제로
	# 떴는지(telegraph_peak)와 카운터가 올랐는지를 함께 본다.
	var telegraph_total: int = game.stage_boss_telegraphs
	var phase_total_seen := 0
	var telegraph_ok := game.stage_boss_telegraphs > 0 and telegraph_peak > 0
	# 패턴 하나를 강제로 착탄시켜 플레이어에게 상태가 붙는지 본다.
	StatusEngine.clear(game.player_status)
	var stomp: Dictionary = BossLibrary.patterns("A", false, false)[0]
	game._strike_player_with_pattern(stomp, 10.0, game.player.global_position)
	telegraph_ok = telegraph_ok and StatusEngine.has(game.player_status, "chill") \
		and StatusEngine.move_multiplier(game.player_status) < 1.0
	# A-3 뇌격은 "플레이어가 chill이면 피해 ×1.6"이다(조건부 배율이 데이터에 산다).
	var bolt: Dictionary = BossLibrary.patterns("A", false, false)[2]
	telegraph_ok = telegraph_ok and String(bolt.get("conditional_status", "")) == "chill" \
		and is_equal_approx(float(bolt.get("conditional_damage_mul", 0.0)), 1.6)
	# 강화형 파생: telegraph 전부 ×0.85 · 보조 상태 1종 추가(§3.4).
	var plain_b: Array = BossLibrary.patterns("B", false, false)
	var enhanced_b: Array = BossLibrary.patterns("B", true, false)
	telegraph_ok = telegraph_ok and plain_b.size() == 3 and enhanced_b.size() == 4
	for index in plain_b.size():
		telegraph_ok = telegraph_ok and is_equal_approx(
			float((enhanced_b[index] as Dictionary)["telegraph"]),
			float((plain_b[index] as Dictionary)["telegraph"]) * GameTuning.STAGE_BOSS_TELEGRAPH_MUL_ENHANCED)
	var secondary_seen := false
	for entry in enhanced_b:
		if String((entry as Dictionary).get("status_secondary", "")) != "":
			secondary_seen = true
	telegraph_ok = telegraph_ok and secondary_seen and BossLibrary.secondary_status("B") == "burn"

	# ---- ⑧-2 페이즈 전환 ------------------------------------------------------
	# 기본형은 HP 50%에서 1회. 임계 바로 아래로 밀고 물리 프레임 하나를 태운다.
	var phase_before: int = game.stage_boss.boss_phase
	game.stage_boss.health = game.stage_boss.max_health * 0.49
	await get_tree().physics_frame
	await get_tree().physics_frame
	phase_total_seen += game.stage_boss_phase_shifts
	var phase_ok := game.stage_boss.boss_phase == phase_before + 1 \
		and game.stage_boss_phase_shifts >= 1 \
		and game.stage_boss.boss_phase_thresholds.is_empty() \
		and game.stage_boss_phase_damage_mul() > 1.0 \
		and game.stage_boss_phase_telegraph_mul() < 1.0
	# 두 번째 임계는 없다 — 기본형은 1회뿐이다.
	game.stage_boss.health = game.stage_boss.max_health * 0.2
	await get_tree().physics_frame
	phase_ok = phase_ok and game.stage_boss.boss_phase == phase_before + 1

	# ---- ④ 격파 → 보상 훅 → advance_stage ------------------------------------
	var stage_before: int = game.clock.stage
	var cleared_before: int = game.clock.stages_cleared
	var trophies_before: int = game.player.trophy_stages.size()
	var boss_cards_before: int = game.trophy_reject_skills.size()
	game.pending_stage_trophy.clear()
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.3).timeout
	var defeat_ok := game.clock.stage == stage_before + 1 \
		and game.clock.stages_cleared == cleared_before + 1 \
		and not game.pending_stage_trophy.is_empty() \
		and int(game.pending_stage_trophy.get("stage", -1)) == stage_before \
		and String(game.pending_stage_trophy.get("design", "")) == "A" \
		and game.stage_boss == null and game.stage_boss_cycle == null \
		and not game.boss_panel.visible \
		and is_instance_valid(game.player) and is_equal_approx(game.player.health, game.player.max_health) \
		and game.world.get_stage() == stage_before + 1
	# V8: 격파 직후는 **트로피 흐름 안**이다 — 2택1이 자동 확정돼 5칸 배치 화면에 서 있다.
	# 고정 스탯 보너스는 카드를 고르기 전에 이미 붙었고, 버린 한 장은 마왕에게 갔다.
	defeat_ok = defeat_ok and game.state == "factory_place" \
		and game.player.trophy_stages.size() == trophies_before + 1 \
		and game.player.trophy_stages.has(stage_before) \
		and game.player.last_trophy_id == String(TrophyLibrary.for_stage(stage_before).get("id", "")) \
		and game.trophy_reject_skills.size() == boss_cards_before + 1 \
		and game.trophy_place_pending
	await _consume_stage_trophy(4)
	defeat_ok = defeat_ok and game.state == "playing" and game.pending_stage_trophy.is_empty() \
		and not game.trophy_place_pending \
		and String(game.factory.get_card(4).get("id", "")) == String(TrophyLibrary.choices_for(stage_before)[0])
	# 격파 뒤에는 상태가 남지 않는다(다음 스테이지로 독을 들고 가지 않는다).
	# ⚠️ `is_state()`는 **배열 모양 검사**다(상태 보유 여부가 아니다 — status_engine.gd:208).
	#    보유 판정은 `has_any()`다. 이 둘을 헷갈리면 항상 참인 단언이 된다.
	defeat_ok = defeat_ok and not StatusEngine.has_any(game.player_status)

	# ---- ③ 강화형(4스테이지 B+) — 칸 4 · RELOAD 0.55 · 페이즈 2회 -------------
	game.clock.set_stage_raw(4)
	game.clock.set_dwell_raw(3)
	game.stage_boss_cleared = false
	game.state = "playing"
	game._show_stage_boss_preview()
	await get_tree().process_frame
	game._begin_stage_boss_battle()
	await get_tree().process_frame
	var enhanced_ok := is_instance_valid(game.stage_boss) \
		and game.stage_boss.boss_rig_id == "B+" \
		and game.stage_boss.boss_sheet_key == "black_slime" \
		and game.stage_boss.boss_enhanced \
		and game.stage_boss_factory.slots.size() == GameTuning.STAGE_BOSS_SLOT_COUNT_ENHANCED \
		and is_equal_approx(game.stage_boss_cycle.reload_scale, GameTuning.STAGE_BOSS_RELOAD_MUL_ENHANCED) \
		and game.stage_boss.boss_phase_thresholds.size() == 2 \
		and int(game.stage_boss_profile.get("status_count", 0)) == GameTuning.STAGE_BOSS_STATUS_COUNT_ENHANCED
	# HP 식에 dwell 항(0.08/주기)과 스테이지 기저(2.65)가 둘 다 물렸는가.
	var expected_stage4_health := BossLibrary.hp_for("B", game.clock.stage_hp_base(), 3, false)
	enhanced_ok = enhanced_ok and absf(game.stage_boss.max_health - expected_stage4_health) < 0.5 \
		and expected_stage4_health > BossLibrary.hp_for("B", game.clock.stage_hp_base(), 0, false)
	# 레일 밴드가 이번에는 4칸을 보여 준다.
	game._update_boss_rail(0.0)
	for slot_index in game.boss_rail_slots.size():
		enhanced_ok = enhanced_ok and (game.boss_rail_slots[slot_index] as Panel).visible == (slot_index < GameTuning.STAGE_BOSS_SLOT_COUNT_ENHANCED)
	# 페이즈 2회 — 66% / 33%를 차례로 밟는다.
	game.stage_boss.max_health = 1.0e9
	game.stage_boss.health = game.stage_boss.max_health * 0.65
	await get_tree().physics_frame
	await get_tree().physics_frame
	enhanced_ok = enhanced_ok and game.stage_boss.boss_phase == 1
	game.stage_boss.health = game.stage_boss.max_health * 0.32
	await get_tree().physics_frame
	await get_tree().physics_frame
	enhanced_ok = enhanced_ok and game.stage_boss.boss_phase == 2 and game.stage_boss.boss_phase_thresholds.is_empty()
	phase_total_seen += game.stage_boss_phase_shifts
	telegraph_total += game.stage_boss_telegraphs
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.3).timeout
	# 4스테이지 트로피는 **전설 등급**이다(강화 보스가 전설을 떨군다 · trophy_library.gd).
	enhanced_ok = enhanced_ok and game.player.trophy_stages.has(4) \
		and String(TrophyLibrary.for_stage(4).get("grade", "")) == "legend"
	await _consume_stage_trophy(3)
	enhanced_ok = enhanced_ok and game.clock.stage == 5 and game.state == "playing"

	# ---- ⑤ 5스테이지 격파 → **필드 복귀 없이 마왕전** -------------------------
	game.clock.set_stage_raw(GameTuning.STAGE_COUNT)
	game.clock.set_stages_cleared_raw(GameTuning.STAGE_COUNT - 1)
	game.clock.set_dwell_raw(1)
	game.stage_boss_cleared = false
	game.state = "playing"
	# 마왕이 실제로 받을 카드를 미리 채워 둔다(⑦의 상위 5장 선별이 여기 이어진다).
	var donated: Array[String] = [
		"cleave", "cleave", "thunder", "thunder", "meteor_blade", "moon_barrier",
		"rapid_slash", "execution", "flame_field", "time_cut", "gravity_well", "blade_fan"
	]
	game.demon_lord.reset()
	game.demon_lord.set_rune_catalog(RuneEngine.all_rune_ids())
	game.rejected_skills.assign(donated)
	game.boss_items.assign(["u_greatsword_01", "r_ring_02", "h_neck_01"])
	game.demon_lord.rune_shards = 6
	game.demon_lord.sync_runes(game.rng)
	var stage5_world: int = game.world.get_stage()
	game._show_stage_boss_preview()
	await get_tree().process_frame
	game._begin_stage_boss_battle()
	await get_tree().process_frame
	var demon_direct_ok := is_instance_valid(game.stage_boss) \
		and game.stage_boss.boss_rig_id == "C+" \
		and game.stage_boss.boss_sheet_key == "black_tengu" \
		and game.stage_boss.boss_intro_playing()      # C+만 Trans 11f 등장 연출을 쓴다
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.4).timeout
	# === V8: **5스테이지 트로피가 마왕전보다 먼저 온다** ======================
	# handoff-v7 §11-1이 경고한 타이밍 지점이다. 격파 콜백이 곧바로
	# `_challenge_demon_king()`을 부르면 마왕 프리뷰가 트로피 모달을 덮어 5번째 트로피가
	# 사라진다(설계 §5.5의 "5회 × 2장 = 10장"이 4회로 줄어든다). 마왕전 호출은
	# `pending_trophy_followup`으로 한 칸 미뤄지고, 배치가 끝나야 프리뷰가 열린다.
	demon_direct_ok = demon_direct_ok and game.clock.is_run_complete() \
		and game.state == "factory_place" \
		and game.pending_trophy_followup == "demon" \
		and game.player.trophy_stages.has(GameTuning.STAGE_COUNT) \
		and String(TrophyLibrary.for_stage(GameTuning.STAGE_COUNT).get("grade", "")) == "legend"
	await _consume_stage_trophy(4)
	demon_direct_ok = demon_direct_ok and game.clock.is_run_complete() \
		and game.state == "boss_preview" and game.boss_preview_kind == "demon" \
		and game.pending_trophy_followup.is_empty() and game.pending_stage_trophy.is_empty() \
		and game.boss_factory != null and game.boss_factory.slots.size() == GameTuning.BOSS_SLOT_COUNT \
		and game.world.get_stage() == stage5_world   # 월드를 다시 세우지 않았다(빈 필드 0프레임)
	# 프리뷰가 마왕 것이다(스테이지 보스 프리뷰가 아니다).
	demon_direct_ok = demon_direct_ok and is_instance_valid(game.overlay) \
		and game.overlay.get_node_or_null("BossPreviewPanel") != null \
		and game.overlay.get_node_or_null("StageBossPreviewPanel") == null

	# ---- ⑦ 마왕전 회귀 (v2 boss 플래그 승계) ---------------------------------
	# 상위 5장 선별 + 각인이 칸으로 옮겨진다(§6.1). `_build_boss_factory()`는 무수정이다.
	var probe_deck := game._build_boss_factory()
	var ranked := game.demon_lord.ranked_cards()
	var demon_ok := probe_deck.slots.size() == GameTuning.BOSS_SLOT_COUNT \
		and ranked.size() > GameTuning.BOSS_SLOT_COUNT \
		and not game.demon_lord.residue_cards().is_empty() \
		and probe_deck.total_rune_count() > 0 \
		and probe_deck.equipment.size() == mini(game.boss_items.size(), FactoryDeck.EQUIPMENT_PARTS.size())
	for slot_index in GameTuning.BOSS_SLOT_COUNT:
		var expected_card: Dictionary = ranked[slot_index]
		var placed := probe_deck.get_card(slot_index)
		demon_ok = demon_ok and String(placed.get("id", "")) == String(expected_card.get("id", "")) \
			and int(placed.get("rank", 1)) == int(expected_card.get("rank", 1)) \
			and String(placed.get("kind", "skill")) != "item"
		if slot_index > 0:
			demon_ok = demon_ok and DealCardLibrary.expected_power(ranked[slot_index - 1]) >= DealCardLibrary.expected_power(expected_card)
		for rune_value in probe_deck.runes_on(slot_index):
			demon_ok = demon_ok and RuneEngine.RUNES.has(String((rune_value as Dictionary).get("id", "")))
	# 프리뷰 v2: 두 레일(내 5 + 마왕 5) · 스크롤 0.
	var demon_panel: Control = game.overlay.get_node_or_null("BossPreviewPanel") if is_instance_valid(game.overlay) else null
	var demon_cells := 0
	var demon_scrolls := 0
	if is_instance_valid(demon_panel):
		for child in demon_panel.get_children():
			if child is ScrollContainer:
				demon_scrolls += 1
			if child is Panel and String((child as Node).name).begins_with("PreviewSlot"):
				demon_cells += 1
	demon_ok = demon_ok and demon_cells == GameTuning.BOSS_SLOT_COUNT * 2 and demon_scrolls == 0
	# HP 배율이 **실제 체력**에 걸린다 — 기준 개체와 대조한다.
	# (구 `:1687`의 v2 공식 하드코딩을 `hp_multiplier()` 호출로 교체한 지점이다.)
	game._begin_boss_battle()
	await get_tree().process_frame
	var power_level := float(game.cycle_number + game.level) * 0.7
	var reference_debts: Array[String] = game.rejected_skills.duplicate()
	for inherited: Dictionary in game.trophy_reject_skills:
		reference_debts.append(String(inherited["module"]))
	var reference := DebtEnemy.new()
	reference.setup(game, game.player, "demon_king", 4, power_level, reference_debts, true, false, game.boss_items)
	var base_hp: float = reference.max_health
	reference.free()
	var expected_scale := game.demon_lord.hp_multiplier(game.day_number)
	demon_ok = demon_ok and game.state == "boss" and is_instance_valid(game.boss) \
		and is_instance_valid(game.boss_cycle) \
		and game.boss.boss_sheet_key == "demon_king" and not game.boss.is_stage_boss \
		and game.boss_cycle.reload_enabled \
		and is_equal_approx(game.boss_cycle.reload_scale, GameTuning.BOSS_RELOAD_MUL) \
		and absf(game.boss.max_health - base_hp * expected_scale) < 0.5 \
		and expected_scale > 0.0
	# needle 규칙 — 궤적이 `RuneEngine.simulate_cycle()`과 완전히 같다.
	for slot_index in game.boss_factory.slots.size():
		(game.boss_factory.slots[slot_index] as Dictionary)["duration_mul"] = 0.1
	game.boss_cycle.reset_cycle()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var route := game.boss_cycle.planned_route()
	# Y2: `start_load`(잔열)는 폐기됐다. 대신 **레일 각인 opts**가 실전 계획에 들어가므로
	# 여기서도 같은 방식으로 만들어야 궤적이 일치한다(`_plan_cycle`과 동일한 opts).
	var expected_opts: Dictionary = {"reload_scale": game.boss_cycle.reload_scale}
	expected_opts.merge(game.boss_factory.rune_opts())
	var expected_plan := RuneEngine.simulate_cycle(
		game.boss_factory.rune_deck(), game.boss_cycle.cycle_seed(), expected_opts)
	var expected_route: Array = expected_plan["visited"]
	demon_ok = demon_ok and route.size() > 0 and route.size() == expected_route.size() \
		and game.boss_cycle.cycle_seed_base == game.run_cycle_seed + 5701
	for index in mini(route.size(), expected_route.size()):
		demon_ok = demon_ok and int(route[index]) == int(expected_route[index])
	# 마왕 레일 밴드는 5칸이 **다시 보인다**(스테이지 보스는 3칸만 보였다).
	game.boss.max_health = 1.0e9
	game.boss.health = game.boss.max_health
	game._update_boss_rail(0.0)
	demon_ok = demon_ok and not game.active_boss_is_stage() \
		and game.boss_rail_slots.size() == GameTuning.BOSS_SLOT_COUNT \
		and not game.ghost_panel.visible and not game.nav_layer.visible
	for slot_index in game.boss_rail_slots.size():
		demon_ok = demon_ok and (game.boss_rail_slots[slot_index] as Panel).visible
	# Y2: 머리말이 「밟은 칸 N / 5」를 말한다. 「과열」은 금지 어휘다(§1.4).
	demon_ok = demon_ok and "밟은 칸" in game.boss_rail_meter_text.text \
		and not ("과열" in game.boss_rail_meter_text.text)
	# 마왕의 RELOAD 창도 실재한다(×0.6).
	var demon_reload_ok := false
	var demon_reload := 0.0
	for _tick in 900:
		await get_tree().physics_frame
		if game.boss_cycle.reloading and game.boss_cycle.reload_duration > 0.0:
			demon_reload_ok = true
			demon_reload = game.boss_cycle.reload_duration
			break
	demon_ok = demon_ok and demon_reload_ok and demon_reload > 0.0

	# ---- ⑥ 강림 밸브 E2E ------------------------------------------------------
	# 런을 새로 깔고 2스테이지에서 dwell을 임계까지 밀어 올린다.
	game._start_game()
	await get_tree().create_timer(0.3).timeout
	game.player.invulnerability = 99999.0
	game.player.max_health = 99999.0
	game.player.health = game.player.max_health
	game.clock.set_stage_raw(2)
	game.state = "playing"
	var valve_threshold := game.clock.descent_threshold()
	game.clock.set_dwell_raw(valve_threshold)
	var valve_ok := game.clock.descent_valve_ready() and not game.clock.descended \
		and valve_threshold == GameTuning.DWELL_DESCENT[1]
	# `_process`가 폴링해서 스스로 강림시킨다(시그널이 없는 유일한 사건 · §6.6).
	await get_tree().create_timer(0.35).timeout
	valve_ok = valve_ok and game.stage_descent_pending and game.clock.descended \
		and is_instance_valid(game.stage_boss) and game.stage_boss.boss_descended \
		and game.stage_boss.boss_rig_id == "B" \
		and game.state == "playing"          # 강림은 프리뷰도 보스방도 없다
	valve_ok = valve_ok and not is_instance_valid(game.overlay)
	# 칸 +1 (A도 4칸이 된다는 그 규칙 — B는 3 → 4).
	valve_ok = valve_ok and game.stage_boss_factory.slots.size() == BossLibrary.slot_count(false, true) \
		and game.stage_boss_factory.slots.size() == GameTuning.STAGE_BOSS_SLOT_COUNT + GameTuning.STAGE_DESCENT_SLOT_BONUS
	# HP ×1.15.
	var expected_valve_health := BossLibrary.hp_for("B", game.clock.stage_hp_base(), game.clock.dwell, true)
	valve_ok = valve_ok and absf(game.stage_boss.max_health - expected_valve_health) < 0.5 \
		and expected_valve_health > BossLibrary.hp_for("B", game.clock.stage_hp_base(), game.clock.dwell, false)
	# 필드에서 자기 사이클을 돌린다(`can_cycle_run(true)`가 playing에서 열려야 한다).
	valve_ok = valve_ok and game.can_cycle_run(true)
	# B의 패턴 지속이 1.45~1.60초라 **한 스텝이 더 도는 데 그만큼 걸린다.** 2.0초를 기다린다.
	var valve_telegraphs_before: int = game.stage_boss_telegraphs
	await get_tree().create_timer(2.0).timeout
	valve_ok = valve_ok and game.stage_boss_telegraphs > valve_telegraphs_before
	# 도망칠 곳이 없다 — 보스는 거리 디스폰(1,650px)을 타지 않고 계속 따라온다.
	game.player.global_position = game.stage_boss.global_position + Vector2(4000.0, 0.0)
	await get_tree().create_timer(0.35).timeout
	valve_ok = valve_ok and is_instance_valid(game.stage_boss) and not game.stage_boss.dead
	# 격파 → 진행은 되지만 등급은 C로 고정된다(§6.6 · V3-C).
	var valve_stage_before: int = game.clock.stage
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.35).timeout
	# 강림 격파도 **정규 격파와 같은 보상 경로**다 — 트로피를 받는다(§6.6은 등급만 벌한다).
	valve_ok = valve_ok and game.player.trophy_stages.has(valve_stage_before) \
		and int(game.pending_stage_trophy.get("stage", -1)) == valve_stage_before \
		and bool(game.pending_stage_trophy.get("descended", false))
	await _consume_stage_trophy(2)
	valve_ok = valve_ok and game.clock.stage == valve_stage_before + 1 \
		and game.clock.descended \
		and game.demon_lord.victory_grade(1, game.clock.descended) == "C" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_S_MAX_DAYS, false) == "S"

	# ---- ⑨ 잠식(구 월식) 개명 회귀 -------------------------------------------
	game.demon_lord.reset()
	game.demon_lord.set_rune_catalog(RuneEngine.all_rune_ids())
	game.rejected_skills.assign(donated)
	game.demon_lord.rune_shards = 6
	game.demon_lord.sync_runes(game.rng)
	game.state = "playing"
	# 강림 격파로 3스테이지(dwell 6)에 와 있어 **잠식이 이미 켜져 있다.** dwell을 내려
	# 정식 해제 경로(`_check_stage_blight` → `_end_blight`)를 태운 뒤 처음부터 검사한다.
	game.clock.set_dwell_raw(0)
	game._check_stage_blight()
	game.blight_marked = 0
	for enemy_node: Node in game.combat.active_enemies:
		if is_instance_valid(enemy_node):
			enemy_node.queue_free()
	game.combat.active_enemies.clear()
	game.combat.enemy_spatial.clear()
	await get_tree().process_frame
	for _index in 6:
		game.combat.spawn_enemy_instance(game.player.global_position + Vector2.from_angle(randf() * TAU) * 220.0, 2, "", false, "", false, "skeleton", true)
	var pool := game.blight_module_pool()
	var blight_ok := not pool.is_empty() and not game.blight_active
	game._on_clock_milestone(StageClock.MILESTONE_BLIGHT, game.day_number)
	blight_ok = blight_ok and game.blight_active and game.blight_marked > 0
	var blight_seen := 0
	for enemy_node: Node in game.combat.active_enemies:
		if not is_instance_valid(enemy_node) or enemy_node.is_boss:
			continue
		blight_ok = blight_ok and enemy_node.has_meta(game.BLIGHT_META)
		blight_ok = blight_ok and RuneEngine.RUNES.has(String(enemy_node.get_meta(game.BLIGHT_META, "")))
		blight_seen += 1
	blight_ok = blight_ok and blight_seen > 0 and game._sweep_blight() == 0 \
		and game.BLIGHT_META == "blight_rune"

	# ---- ⑩ V8: 결과 화면 v3 — **v2 기한 지표 0개** ---------------------------
	# 이 묶음은 런의 마지막에 둔다(`_finish_run`이 트리를 멈추고 세이브를 지운다).
	# 설계 부록 B V8 ⑤ + 완료 기준 "결과 화면에 v2 기한 지표 0개"를 그대로 단언한다.
	game.player.restore_trophies([1, 2, 3])
	game.run_synergy_triggers = 24
	game.growth_cap_conversions = 1
	game.clock.set_day_raw(GameTuning.GRADE_A_MAX_DAYS)
	game.state = "playing"
	game._finish_run(true)
	await get_tree().process_frame
	var result_panel: Control = game.overlay.get_node_or_null("ResultPanel") if is_instance_valid(game.overlay) else null
	var result_ok := game.state == "won" and is_instance_valid(result_panel)
	# 등급은 **총 일수만** 본다(§2.5의 13/17/23 · 밸브 C).
	result_ok = result_ok and game.demon_lord.victory_grade(GameTuning.GRADE_S_MAX_DAYS, false) == "S" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_A_MAX_DAYS, false) == "A" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_B_MAX_DAYS, false) == "B" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_B_MAX_DAYS + 1, false) == "C" \
		and game.demon_lord.victory_grade(1, true) == "C"
	# 타임라인은 **5칸**이다(v2의 7일 7칸이 아니다).
	var timeline_cells := 0
	if is_instance_valid(result_panel):
		var timeline_box := result_panel.get_node_or_null("ResultTimeline")
		if is_instance_valid(timeline_box):
			for child in timeline_box.get_children():
				if child is Panel and (child as Node).has_meta("stage"):
					timeline_cells += 1
	result_ok = result_ok and timeline_cells == GameTuning.STAGE_COUNT
	# 패널의 모든 글자를 모아 ①v2 기한 어휘가 0건 ②v3 신규 지표가 실재하는지 본다.
	var result_text := _collect_label_text(result_panel)
	# 금지 어휘 — v2 기한 게임 / 계보·각성 / v1 시련 구슬의 잔재. 하나라도 남으면 FAIL.
	# ("7일" 같은 짧은 토큰은 쓰지 않는다 — 총 일수가 17일이면 그대로 걸린다.)
	for banned in ["기한", "잔여 일수", "남은 일수", "일차 이정표", "각성", "계보", "월식", "시련 구슬"]:
		if result_text.contains(banned):
			print("RESULT_BANNED_TOKEN token=%s" % banned)
		result_ok = result_ok and not result_text.contains(banned)
	# X1: "성장 천장 전환" → **"성장 천장 레벨업"**. 천장에서 각인 드래프트로 전환하는
	# 경로가 사라졌고(사용자 요구 ④) 카운터의 뜻이 "천장에서 열린 레벨업 수"로 바뀌었다.
	for required in ["다섯 관문", "승리 등급", "총 일수", "시너지 발동", "보스 트로피", "반격 창", "성장 천장 레벨업"]:
		if not result_text.contains(required):
			print("RESULT_MISSING_TOKEN token=%s" % required)
		result_ok = result_ok and result_text.contains(required)
	# 획득한 트로피 3종의 이름이 실제로 나열된다(요약 줄).
	for trophy_stage_probe in [1, 2, 3]:
		result_ok = result_ok and result_text.contains(String(TrophyLibrary.for_stage(trophy_stage_probe).get("name", "?")))
	# 트로피 흐름이 결과 화면과 함께 정리됐다(후속 마왕전이 결과 위로 뜨지 않는다).
	result_ok = result_ok and game.pending_stage_trophy.is_empty() \
		and game.pending_trophy_followup.is_empty() and not game.trophy_place_pending

	# ---- ★ Y4 결과 화면 수리 (피드백 ㉔ · FEEDBACK_Y §8 ㉔) ------------------
	# 크림(PARCHMENT) 껍데기 위에 SLATE 칩 + 밝은 글자를 그리던 5칸 구역이
	# **어두운 무대 창** 안으로 들어갔는가. 창이 없거나 레일을 덜 덮으면 실패다.
	# 창 하나만 확인하는 게 아니라 **레일 다섯 칸이 전부 그 창 안에 있는지**를 잰다 —
	# 창을 만들어 놓고 레일을 창 밖에 그리면 그림은 그대로 깨진다.
	var stage_window := result_panel.get_node_or_null("ResultRailStage") as Control if is_instance_valid(result_panel) else null
	result_ok = result_ok and stage_window != null
	if stage_window != null:
		var window_box := Rect2(stage_window.position, stage_window.size)
		var rail_box := Rect2(game.RESULT_RAIL_ORIGIN,
			Vector2(game.EDIT_RAIL_PITCH * float(GameTuning.BOSS_SLOT_COUNT - 1) + game.EDIT_CARD_SIZE.x,
				game.EDIT_CARD_SIZE.y))
		var covered := window_box.encloses(rail_box)
		if not covered:
			print("Y4_DEBUG result_window=%s rail=%s" % [window_box, rail_box])
		result_ok = result_ok and covered
		# 무대 창은 아래 마왕 요약 띠(y 456)를 먹으면 안 된다.
		result_ok = result_ok and window_box.end.y <= 456.0
	# 승리 컷에서도 1280×720 경계를 지킨다(§8 ⑦ 경계 검사 · 지금까지 패배 컷만 봤다).
	await _settle_modal()
	var result_out := _assert_in_viewport(game.overlay)
	if not result_out.is_empty():
		print("Y4_VIEWPORT_OVERFLOW result=%s" % [result_out])
	result_ok = result_ok and result_out.is_empty()

	print("BOSS_TEST_COMPLETE rotation=%s battle_e2e=%s enhanced=%s defeat=%s demon_direct=%s valve=%s demon_king=%s telegraph=%s phase=%s blight=%s result=%s stage_reload=%.3f expected_reload=%.3f demon_reload=%.3f telegraphs=%d phase_shifts=%d bosses=%d blight_marked=%d steps=%d timeline=%d" % [
		rotation_ok, battle_ok, enhanced_ok, defeat_ok, demon_direct_ok, valve_ok,
		demon_ok, telegraph_ok, phase_ok, blight_ok, result_ok,
		observed_reload, expected_reload, demon_reload,
		telegraph_total + game.stage_boss_telegraphs, phase_total_seen, game.clock.stages_cleared,
		game.blight_marked, route.size(), timeline_cells
	])
	var boss_passed := rotation_ok and battle_ok and enhanced_ok and defeat_ok \
		and demon_direct_ok and valve_ok and demon_ok and telegraph_ok and phase_ok and blight_ok \
		and result_ok
	await _quit_test_cleanly(boss_passed)

# =============================================================================
# Y4 — 화면 검사 헬퍼 3종 (FEEDBACK_Y §8 ⑦ "전 화면 1280×720 경계 검사 신설")
# =============================================================================

## 하위 트리의 모든 `Control`이 1280×720 안에 있는가. 밖으로 나간 노드의
## 「이름 @ 사각형」 목록을 돌려준다 — **빈 배열이 통과다.**
##
## 왜 이름이 아니라 목록인가: 어긋난 순간 어느 노드가 얼마나 나갔는지 바로 알아야
## 고칠 수 있다. `--capture-*`는 사람 눈이 필요하지만 이 검사는 자동이다.
##
## ⚠️ 보이지 않는 노드(`visible == false`)와 크기 0 노드는 세지 않는다 —
##    자리표시자·숨긴 눈금자가 화면 밖에 있는 것은 그림에 영향을 주지 않는다.
##    스크림처럼 **화면 전체를 덮는** 노드는 정확히 경계에 걸치므로 1px 여유를 준다.
const VIEWPORT_BOUNDS := Vector2(1280.0, 720.0)
const VIEWPORT_SLACK := 1.0

func _assert_in_viewport(root: Node) -> Array[String]:
	var offenders: Array[String] = []
	if not is_instance_valid(root):
		return offenders
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not (node is Control):
			continue
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
			continue
		var box := Rect2(control.global_position, control.size)
		if box.position.x < -VIEWPORT_SLACK or box.position.y < -VIEWPORT_SLACK \
				or box.end.x > VIEWPORT_BOUNDS.x + VIEWPORT_SLACK \
				or box.end.y > VIEWPORT_BOUNDS.y + VIEWPORT_SLACK:
			offenders.append("%s@%.0f,%.0f+%.0fx%.0f" % [
				control.name, box.position.x, box.position.y, box.size.x, box.size.y])
	return offenders

## 모달 등장 트윈(0.22초)이 끝날 때까지 기다린다. **경계 검사 전에 반드시 부른다** —
## `_animate_modal()`이 판을 16~22px 아래에서 시작하므로, 트윈 도중에 재면 세로로
## 꽉 찬 화면이 항상 화면 밖으로 나간 것처럼 보인다(Y4가 실제로 밟았다).
## 검사 대상은 **가라앉은 배치**지 등장 연출이 아니다.
func _settle_modal() -> void:
	await get_tree().create_timer(0.30, true, false, true).timeout
	await get_tree().process_frame

## 하위 트리에서 이름이 정확히 일치하는 첫 노드. `get_node_or_null`은 경로를 알아야
## 하는데 Y4가 보는 노드들은 깊이가 화면마다 다르다.
func _v4_find_named(root: Node, target: String) -> Node:
	if not is_instance_valid(root):
		return null
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.name == target:
			return node
		for child in node.get_children():
			pending.append(child)
	return null

## 아이콘 셀에서 **판 픽셀만** 골라 평균 색상(hue)을 낸다. 못 재면 -1.
## 판 픽셀 = 불투명 + 채도 0.18 이상 + 잉크/크림이 아닌 것. 색상은 원형 평균으로 낸다
## (빨강이 0과 1 양쪽에 걸치므로 산술 평균을 쓰면 정반대 값이 나온다).
func _v4_plate_mean_hue(texture: Texture2D) -> float:
	if texture == null:
		return -1.0
	var image := texture.get_image()
	if image == null:
		return -1.0
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var sum_x := 0.0
	var sum_y := 0.0
	var counted := 0
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			if px.a <= 0.5 or px.s < 0.18:
				continue
			if px.is_equal_approx(PixelSkillIcon.PLATE_INK) or px.is_equal_approx(PixelSkillIcon.PLATE_CREAM):
				continue
			var angle := px.h * TAU
			sum_x += cos(angle)
			sum_y += sin(angle)
			counted += 1
	if counted < 24:
		return -1.0
	return fposmod(atan2(sum_y, sum_x) / TAU, 1.0)

## 색상환 위의 두 색상 사이 거리(0~0.5). 0과 1이 같은 색이라는 것을 안다.
func _v4_hue_gap(a: float, b: float) -> float:
	var gap := absf(fposmod(a, 1.0) - fposmod(b, 1.0))
	return minf(gap, 1.0 - gap)

## 컨트롤 하위 트리의 모든 Label 텍스트를 한 문자열로 모은다.
## 결과 화면의 "금지 어휘 0건" 판정이 유일한 소비자다 — 노드 구조를 알 필요가 없다.
func _collect_label_text(root: Node) -> String:
	if not is_instance_valid(root):
		return ""
	var parts: Array[String] = []
	if root is Label:
		parts.append((root as Label).text)
	elif root is Button:
		parts.append((root as Button).text)
	for child in root.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)

## V8: 보스 격파 뒤에 열리는 **트로피 2택1 → 5칸 배치**를 끝까지 소화한다.
## `automated_test`에서는 `_open_stage_trophy_choice()`가 왼쪽 카드를 자동 확정하므로
## 보통 곧바로 `factory_place`에 와 있다. 두 상태를 다 받아 주고 배치까지 마친다.
## 배치가 끝나면 `_finish_factory_return()` → `_finish_stage_trophy()`가 후속을 잇는다
## (5스테이지라면 그 안에서 마왕 프리뷰가 열린다).
func _consume_stage_trophy(slot_index: int = 4) -> void:
	for _frame in 6:
		await get_tree().process_frame
	if game.state == "advancement_choice":
		game._confirm_choice_index(0)
		for _frame in 4:
			await get_tree().process_frame
	if game.state == "factory_place":
		game._factory_lane_pressed(slot_index, 0)
	for _frame in 6:
		await get_tree().process_frame

## 지금 씬 트리에 살아 있는 telegraph 링 수. 노드 이름이 아니라 **스크립트 필드**로
## 판별한다(내부 클래스라 `is` 검사를 쓸 수 없다).
func _boss_test_count_telegraphs() -> int:
	if not is_instance_valid(game.gameplay_root):
		return 0
	var found := 0
	for child in game.gameplay_root.get_children():
		if child is Node2D and (child as Node).get("lead") != null and (child as Node).get("fired") != null:
			found += 1
	return found

# =============================================================================
# --save-test (W12 신설 → **V9 재작성**) — 이어하기 E2E · 저장 schema 3
# =============================================================================
# 이 검사가 없으면 스냅샷 키를 하나 빠뜨려도 아무도 모른다 — W9(균열 5키)와
# W10(잠식 4키)이 각각 "빼면 통째로 사라진다"고 경고한 바로 그 지점이다.
#
# 방법: 런을 **스테이지 3 · 체류 5 · 잠식 활성 · 트로피 2개 · 균열 2개(1개 클리어)**
# 까지 끌고 가 모든 축을 기본값에서 흔든 뒤
#   ① `_save_run_snapshot()` → ② `_read_run_snapshot()` → ③ `_begin_run(snapshot)`
# 를 실제 이어하기 경로 그대로 통과시키고, 저장 직전 지문과 복원 후 지문을 대조한다.
# `_begin_run()`은 모든 상태를 초기화한 뒤 `_restore_run_snapshot()`을 부르므로,
# 스냅샷에 없는 값은 반드시 기본값으로 떨어진다 — 누락이 조용히 통과할 수 없다.
#
# ── V9가 가산한 묶음 6종 ─────────────────────────────────────────────────────
#   keys        필수 키 목록(V10 기준 48 — V9의 49에서 `stage_bosses_defeated` 삭제)
#   fields      지문 **72축**(V8 49축 + 스테이지/랜드마크/그레이드 축 + Y2·Y3·Y6 신설 축)
#               ⚠️ 이 숫자는 참고값이다. 회귀를 잡는 것은 `mismatch=0` 하나다.
#               ⚠️ 실제 숫자는 `required_keys.size()` / `before.size()`가 세서 출력한다.
#               위 숫자는 사람이 읽을 기준선일 뿐이니 어긋나면 출력 쪽을 믿을 것.
#   combat_save **전투 중 저장 정책** — 마왕전 · 강림 보스 · 트로피 모달 3구간에서
#               파일이 갱신되지 않는지를 실제 스냅샷 왕복으로 본다
#   legacy      schema 2·v1 폐기 + 개명 폴백표(`SNAPSHOT_LEGACY_KEYS`) 발화
#   visual      복원 직후 **낮/밤 · 아틀라스 · 그레이드**가 스테이지 3의 값인지
#   transition  **스테이지 전이 왕복** — 3→4 전이 직후 저장·복원(설계 §9)
#   lobby       로비 이어하기 표기(스테이지 · 총 일수 · 플레이타임) 정합
func _run_save_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(game.player):
		game.player.invulnerability = 99999.0

	# ---- ① 스테이지 3까지 실제 전이 경로로 올린다 ---------------------------
	# `advance_stage()`가 클럭 시그널로 `_begin_stage()`를 돌리므로 월드 재생성 ·
	# 랜드마크 재배치 · 균열 예산 초기화가 전부 실기와 같은 순서로 일어난다.
	# **전이가 스테이지 스코프 상태(잠식·균열·opened_features)를 지우므로 흔들기는
	# 반드시 전이 뒤에 한다.**
	var advanced_ok := game.advance_stage() and game.advance_stage()
	await get_tree().process_frame
	var stage_ok := game.clock.stage == 3 and game.clock.stages_cleared == 2 \
		and game.world.get_stage() == 3

	# ---- ② 모든 축을 기본값에서 흔든다 --------------------------------------
	# 진행 · 자원
	game.level = 9
	game.experience = 37
	game.xp_target = 121
	game.kills = 214
	game.gold = 486
	game.elapsed_time = 512.5
	# 클럭 — 3스테이지 밤 중반(밤 60초 중 19.5초 · 0.3초 대기로 넘어가지 않는다)
	game.clock.set_day_raw(11)
	game.clock.set_night_raw(true)
	game.clock.set_phase_elapsed_raw(19.5)
	# 체류 5 = 3스테이지 잠식 임계(STAGE_BLIGHT_DWELL[2] == 3)를 넘긴 값이다.
	game.clock.set_dwell_raw(5)
	# 마왕 성장 — 카드 · 각인 · 조각 · 뜯긴 각인 · 회수 카드가 전부 0이 아니어야 한다
	game.demon_lord.reset()
	game.demon_lord.set_rune_catalog(RuneEngine.all_rune_ids())
	game.rejected_skills.assign(["cleave", "cleave", "thunder", "whirlwind", "execution", "frost_ring"])
	game.boss_items.assign(["u_greatsword_01", "r_ring_02"])
	game.trophy_reject_skills.assign([{"module": "flame_field", "tier": 1}])
	game.demon_lord.rune_shards = 5
	game.demon_lord.sync_runes(game.rng)
	game.demon_lord.strip_rune(0)
	game.omen_night_count = 3
	# 각인 · 카드 · 장비 (편집 화면이 만드는 상태 전부)
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
	game.factory.place_card(2, DealCardLibrary.instance("thrust", 1))
	game.factory.attach_rune(0, RuneEngine.roll_rune("strong", game.rng))
	game.factory.attach_rune(0, RuneEngine.roll_rune("wide", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("back_one", game.rng))
	# Y2 신설 저장 키 `factory_rail_runes`. 레일 각인은 칸이 아니라 레일이 소유하므로
	# `factory_slots`에 안 들어 있다 — 저장 줄이 빠지면 이어하기 때 조용히 사라진다(§9.3).
	game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_fast", game.rng))
	game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_power", game.rng))
	game.factory.add_inventory(DealCardLibrary.instance("holy_pulse", 1))
	game.factory.equip(ItemLibrary.instance("r_neck_03"))
	game.factory.equip(ItemLibrary.instance("u_brace_01"))
	game.selected_skills.assign(["cleave", "thrust"])
	# V8: 계보/각성 → **보스 트로피**. 스탯이 아니라 스테이지 번호만 저장되고
	# 복원 시 `TrophyLibrary.merge_effects()`가 효과를 다시 세운다(설계 §9).
	game.player.applied_skills.assign(["cleave", "thrust"])
	game.player.restore_trophies([1, 2])
	game.growth_cap_conversions = 2
	game.run_synergy_triggers = 47
	game.player._rebuild_stats()
	game.player.health = game.player.max_health * 0.42
	game.player.shield_charges = 1
	# `rollback_charges`는 일부러 0으로 둔다. v3에는 `rollback_capacity`를 올려 주는
	# 카드·장비·트로피가 하나도 없어 복원 시 항상 용량 0으로 잘린다.
	# 1을 넣으면 이 검사가 "저장 누락"이 아니라 "정상 클램프"를 FAIL로 잡는다.
	game.player.rollback_charges = 0
	game.player.global_position = Vector2(1873.0, -924.0)
	# Y6 축 — 발견 · 필드 사건 · 소비 칸. 전부 **기본값이 아닌 값**으로 심는다.
	game.mark_discovered("boss_gate", "")
	game.consumable_item = "sundial"
	game.night_eye_nights = 1
	# 사건 예산을 **지금 dwell(5)까지 따라잡아 둔다.** 안 그러면 복원 뒤의 따라잡기가
	# 사건을 하나 더 열어 지문이 어긋난다 — 그건 회귀가 아니라 정상 동작이므로
	# 저장 전에 같은 상태로 맞춰 두고, 대신 "복원 뒤에 더 안 늘어난다"를 지문이 문다.
	game._maintain_event_schedule()
	# 성 NPC 상태 (W9의 5키 중 3개)
	game.pact_uses = {"sell_day": 1, "buy_day": 2, "mortgage": 1}
	game.rune_shop_purchases = 3
	game.spy_wipe_stage = 2
	# 잠식 · 런 기록
	game.blight_active = true
	game.blight_marked = 27
	game.run_peak_steps = 6
	game.boss_reload_windows = 4
	# 스테이지 스코프 — 캠프 휴식 소진. `stage_descent_pending`은 **일부러 false**다
	# (true면 밸브가 당겨졌다는 뜻이고, 그 상태에서는 저장 자체가 막힌다 — ④ 참조).
	game.camp_rest_used = true
	# 균열 — 2개를 열고 하나는 클리어까지 표시한다
	var rift_a: Dictionary = game.world.spawn_rift_near(game.player.global_position)
	var rift_b: Dictionary = game.world.spawn_rift_near(game.player.global_position + Vector2(2400.0, 1600.0))
	var rift_seeded := not rift_a.is_empty() and not rift_b.is_empty()
	if rift_seeded:
		game.rift_states[String(rift_a["id"])] = {"activated": true, "remaining": 2, "cleared": false}
		game.rift_states[String(rift_b["id"])] = {"activated": true, "remaining": 0, "cleared": true}
		game.world.set_rift_cleared(String(rift_b["id"]), true)
	# 랜드마크 개방 표시
	game.opened_features["save_probe_chest"] = true
	game.state = "playing"
	# ⚠️ Y5: 저장 지점을 **걸을 수 있는 자리로 맞춘 뒤** 지문을 뜬다.
	# Y5가 돌을 못 지나가게 만들면서 `_begin_run()`의 이어하기 경로에
	# `_walkable_spawn_point()` 구제가 붙었다 — 저장될 때는 멀쩡했는데 지금 규칙으로는
	# 막힌 자리라면 플레이어를 가장 가까운 열린 칸으로 옮긴다(안 그러면 바위에 낀 채
	# 부활한다). 그런데 이 검사는 플레이어 좌표를 **왕복 지문**에 넣으므로,
	# 막힌 자리에 세워 두고 저장하면 복원 쪽만 구제가 걸려 `mismatch=1`이 난다.
	# 실기에서는 플레이어가 서 있던 자리를 저장하므로 애초에 막힌 자리일 수 없다 —
	# 그 조건을 검사도 똑같이 맞춘다. **구제 경로 자체는 `--field-test`가 따로 문다.**
	if not game.can_player_stand(game.player.global_position):
		game.player.global_position = game.world.find_walkable_near(game.player.global_position, game.rng, 40.0, 200.0)

	# ---- ③ 저장 직전 지문 ---------------------------------------------------
	var before := _save_test_fingerprint()
	var before_rift_state := game.world.export_rift_state().duplicate(true)
	game._save_run_snapshot()

	# ---- ④ 전투 중 저장 정책 (V9 신설) --------------------------------------
	# 정책: **전투·모달이 열려 있는 동안에는 스냅샷 파일을 건드리지 않는다.**
	# 마지막 "보스방 앞 필드" 스냅샷이 그대로 남고 이어하기는 그 지점으로 돌아간다.
	# 검증 방법: 저장이 막혀야 하는 상태에서 `elapsed_time`을 크게 흔든 뒤
	# `_save_run_snapshot()`을 부르고, 파일의 `playtime`이 **안 바뀌었는지**를 본다.
	var combat_save_ok := game.run_save_allowed()          # 필드에서는 저장이 열려 있어야 한다
	var saved_playtime := float(game._read_run_snapshot().get("playtime", -1.0))
	combat_save_ok = combat_save_ok and is_equal_approx(saved_playtime, 512.5)
	var blocked_reasons: Array[String] = []

	# ④-1 마왕전 · 보스방 아레나 — 둘 다 state == "boss"
	game.state = "boss"
	blocked_reasons.append(game._run_save_blocked_reason())
	combat_save_ok = combat_save_ok and not game.run_save_allowed()
	game.elapsed_time = 9999.0
	game._save_run_snapshot()
	combat_save_ok = combat_save_ok and is_equal_approx(float(game._read_run_snapshot().get("playtime", -1.0)), 512.5)
	game.state = "playing"

	# ④-2 트로피 2택1 모달 사슬 (handoff-v8 §9-2가 남긴 구멍)
	game.pending_stage_trophy = {"stage": 3, "design": "C", "enhanced": false, "descended": false, "day": 11, "dwell": 5}
	blocked_reasons.append(game._run_save_blocked_reason())
	combat_save_ok = combat_save_ok and not game.run_save_allowed()
	game._save_run_snapshot()
	combat_save_ok = combat_save_ok and is_equal_approx(float(game._read_run_snapshot().get("playtime", -1.0)), 512.5)
	game.pending_stage_trophy.clear()

	# ④-3 강림 보스 — state는 "playing" 그대로다(§6.6). 실제 보스를 필드에 세운다.
	game._begin_stage_boss_descent()
	await get_tree().process_frame
	var descended_spawned := game.stage_boss_active()
	blocked_reasons.append(game._run_save_blocked_reason())
	combat_save_ok = combat_save_ok and descended_spawned and not game.run_save_allowed()
	game._save_run_snapshot()
	combat_save_ok = combat_save_ok and is_equal_approx(float(game._read_run_snapshot().get("playtime", -1.0)), 512.5)
	game._teardown_stage_boss()
	game.stage_descent_pending = false
	game.clock.set_descended_raw(false)
	await get_tree().process_frame
	# 전투가 걷히면 다시 열려야 한다 — "영구히 막힌다"가 아니라 "쉰다"가 정책이다.
	combat_save_ok = combat_save_ok and game.run_save_allowed()
	game.elapsed_time = 512.5

	# ---- ⑤ 스냅샷을 파일에서 되읽어 실제 이어하기 경로로 복원 ---------------
	var snapshot := game._read_run_snapshot()
	var snapshot_ok := not snapshot.is_empty() \
		and int(snapshot.get("schema_version", 0)) == game.RUN_SCHEMA_VERSION \
		and game.RUN_SCHEMA_VERSION == 4
	# 스키마가 요구하는 키가 하나라도 빠지면 여기서 잡는다.
	var required_keys: Array[String] = [
		"schema_version", "character_id", "playtime", "level", "experience", "xp_target",
		"kills", "gold", "deadline_clock", "demon_lord", "omen_night_count",
		"player_position", "player_health", "player_skills", "player_trophies",
		"trophy_stages", "growth_cap_conversions", "run_synergy_triggers",
		"player_shields", "player_rollbacks",
		"factory_slots", "factory_inventory", "factory_equipment", "run_cycle_seed",
		"selected_skills", "rejected_skills", "boss_items",
		# V9 개명: `boss_advancement` → `trophy_effects`
		"trophy_effects",
		"opened_features", "camp_states",
		"rift_state", "rift_states", "pact_uses", "rune_shop_purchases", "spy_wipe_stage",
		"blight_active", "blight_marked", "run_peak_steps", "boss_reload_windows",
		# 스테이지 축 (V5·V7 가산 → V9 확정)
		"stage_index", "stage_dwell", "stage_seed", "stages_cleared",
		"stage_descent_pending", "camp_rest_used", "stage_boss_cleared",
		# V9 신규 2키 (V10: `stage_bosses_defeated`는 읽는 코드가 없어 삭제됐다 —
		#  격파 수는 `stages_cleared`가 이미 든다)
		"total_days", "stage_landmarks",
		# Y6 신규 5키 (schema 4 · FEEDBACK_Y §6.1 저장 규약 · §6.2 예산 · §6.3 소비 칸)
		"discovered_features", "stage_events", "run_event_count", "consumable_item",
		"night_eye_nights"
	]
	var missing_keys: Array[String] = []
	for key: String in required_keys:
		if not snapshot.has(key):
			missing_keys.append(key)
	# 폐기 키가 되살아나면(복사·붙여넣기 회귀) 여기서 잡는다.
	var dropped_keys: Array[String] = [
		"player_advancement_branch", "player_advancement_tier", "boss_advancement",
		"cycle_number", "is_night", "phase_elapsed",
		"eclipse_active", "eclipse_marked"
	]
	var resurrected_keys: Array[String] = []
	for key: String in dropped_keys:
		if snapshot.has(key):
			resurrected_keys.append(key)
	snapshot_ok = snapshot_ok and missing_keys.is_empty() and resurrected_keys.is_empty()
	# 스냅샷이 스스로 스테이지 3 · 체류 5를 말하는가(최상위 키와 클럭 사전의 정합).
	var clock_snapshot: Dictionary = snapshot.get("deadline_clock", {}) as Dictionary
	snapshot_ok = snapshot_ok \
		and int(snapshot.get("stage_index", 0)) == 3 \
		and int(snapshot.get("stage_dwell", -1)) == 5 \
		and int(snapshot.get("stages_cleared", -1)) == 2 \
		and int(snapshot.get("total_days", 0)) == int(clock_snapshot.get("day", -1)) \
		and int(clock_snapshot.get("stage", 0)) == 3 \
		and (snapshot.get("stage_landmarks", {}) as Dictionary).size() == 3

	# ---- ⑥ 로비 이어하기 표기 (V9 신설) -------------------------------------
	game._load_progress()
	var lobby_label := game._saved_run_label()
	var lobby_ok := game.saved_run_available \
		and game.saved_run_stage == 3 \
		and game.saved_run_total_days == 11 \
		and is_equal_approx(game.saved_run_playtime, 512.5) \
		and lobby_label.contains("3스테이지") \
		and lobby_label.contains(GameTuning.STAGE_NAMES[2]) \
		and lobby_label.contains("11일차") \
		and lobby_label.contains(game._format_time(512.5))

	# ⚠️ **콜드 스타트 흉내 — 이 한 줄이 이 검사의 핵심이다.**
	# 실기의 이어하기는 "앱을 껐다 켜고 로비에서 누른다"이므로 `run_cycle_seed`가 0이고
	# `_begin_run()`이 `rng.randi()`로 **새 시드를 뽑는다.** 0으로 되돌리지 않으면
	# 살아 있는 게임 인스턴스의 시드가 그대로 재사용돼, 시드 복원 순서가 틀려도
	# 월드가 우연히 같게 나온다 — V8까지의 `--save-test`가 못 보던 구멍이 정확히 여기다.
	game.run_cycle_seed = 0
	game._begin_run(snapshot)
	# ⚠️ YZ 흔들림 수리 — 아래 0.3초는 **벽시계**다. 그 동안 복원된 플레이어가 계속
	#    걷기 때문에, CPU가 붐비면 흐르는 프레임 수가 달라져 `player_position`이
	#    실행마다 다른 자리에 도착한다(실측 156px 어긋남 · 다른 앱이 CPU를 60% 넘게
	#    쓰던 중에 재현). 이 축이 재려는 것은 **「복원된 좌표가 맞는가」**이지
	#    「복원 뒤 0.3초 동안 어디까지 걸었는가」가 아니다.
	#    그래서 지문을 뜰 때까지 **플레이어 물리만** 멈춘다 — 클럭·잠식 스윕은 그대로
	#    돌기 때문에 아래 `DRIFT_KEYS` 넷(phase·playtime·blight_marked·run_elapsed)은
	#    원래대로 흐르고, 이 수리가 그 넷의 판별력을 지우지 않는다.
	if is_instance_valid(game.player):
		game.player.set_physics_process(false)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(game.player):
		game.player.invulnerability = 99999.0

	# ---- ⑦ 복원 후 지문 대조 -------------------------------------------------
	var after := _save_test_fingerprint()
	if is_instance_valid(game.player):
		game.player.set_physics_process(true)
	# 복원 뒤 한 프레임 이상이 실제로 흐르므로 **시간축과 스윕 카운터는 정확히 같을 수 없다.**
	#   * `phase` / `playtime` / `run_elapsed` — 복원 직후에도 클럭이 돈다.
	#   * `blight_marked` — `_begin_run()`이 스타터 마물 9기를 뿌리고 잠식 스윕이 즉시 표식한다.
	# 이 넷만 "되돌아가지 않았는가"로 보고 나머지는 전부 정확 일치를 요구한다.
	const DRIFT_KEYS: Array[String] = ["phase", "playtime", "blight_marked", "run_elapsed"]
	# ⚠️ YZ 흔들림 수리 — **발견 목록은 단조 증가 축이다.**
	#    복원 뒤 0.3초 동안 클럭이 도는데, 복원된 자리가 사건 표식의 발견 반경
	#    (`DISCOVER_RADIUS` 520px) 안이면 그 사이에 **새 표식이 하나 켜진다**
	#    (실측: `evt_3_1`이 붙어 `discovered`가 3개 → 4개). 몇 프레임이 흐르는지는
	#    CPU 부하에 따라 달라지므로 정확 일치를 요구하면 실행마다 흔들린다.
	#    이 축이 재려는 것은 **「저장 전에 켜져 있던 것이 복원 뒤에도 켜져 있는가」**다 —
	#    발견은 취소되지 않으므로 **부분집합 판정**이 의미상 옳고, 하나라도 사라지면
	#    (= 진짜 복원 버그) 그대로 잡힌다.
	const GROWTH_KEYS: Array[String] = ["discovered"]
	var mismatches: Array[String] = []
	for key in before:
		if DRIFT_KEYS.has(String(key)):
			if float(str(after.get(key, "-1"))) < float(str(before[key])) - 0.001:
				mismatches.append("%s(되감김 %s→%s)" % [key, str(before[key]), str(after.get(key, "<없음>"))])
			continue
		if GROWTH_KEYS.has(String(key)):
			var was: PackedStringArray = str(before[key]).split(",", false)
			var now: PackedStringArray = str(after.get(key, "")).split(",", false)
			var lost: Array[String] = []
			for token in was:
				if not now.has(token):
					lost.append(token)
			if not lost.is_empty():
				mismatches.append("%s(사라짐 %s · %s→%s)" % [
					key, ",".join(lost), str(before[key]), str(after.get(key, "<없음>"))])
			continue
		# `str()`를 쓴다. `String()`은 생성자라 bool·int를 그대로 받지 않는다.
		if str(after.get(key, "<없음>")) != str(before[key]):
			mismatches.append("%s(%s→%s)" % [key, str(before[key]), str(after.get(key, "<없음>"))])
	var match_ok := mismatches.is_empty()

	# 균열 좌표까지 같아야 한다 — 이어하기 후 나침반이 다른 곳을 가리키면 안 된다.
	var rift_ok := rift_seeded
	var after_rift_state := game.world.export_rift_state()
	rift_ok = rift_ok and int(after_rift_state.get("spawned", -1)) == int(before_rift_state.get("spawned", -2)) \
		and int(after_rift_state.get("seed", -1)) == int(before_rift_state.get("seed", -2)) \
		and (after_rift_state.get("rifts", []) as Array).size() == (before_rift_state.get("rifts", []) as Array).size()
	for index in (before_rift_state.get("rifts", []) as Array).size():
		var expected: Dictionary = (before_rift_state["rifts"] as Array)[index]
		var actual: Dictionary = (after_rift_state["rifts"] as Array)[index]
		rift_ok = rift_ok and String(expected.get("id", "")) == String(actual.get("id", "x")) \
			and (expected.get("position", Vector2.ZERO) as Vector2).is_equal_approx(actual.get("position", Vector2.ONE)) \
			and bool(expected.get("cleared", false)) == bool(actual.get("cleared", true))
	# 균열 예산도 이어져야 한다(이어하기로 예산이 되살아나면 스테이지 2회 제한이 무너진다).
	rift_ok = rift_ok and game.world.rift_budget_remaining() == game.world.RIFT_MAX_PER_RUN - 2

	# ---- ⑧ 복원 직후 시각 상태 (V9 신설) ------------------------------------
	# "지문이 같다"만으로는 **화면이 스테이지 3처럼 보이는지**를 모른다. 아틀라스·조명·
	# 그레이드는 지문이 아니라 스테이지 상수와 직접 대조한다(기대값이 데이터에 있다).
	var stage_index := 2                                   # 3스테이지 = 인덱스 2
	var visual_ok := game.world.get_stage() == 3 \
		and game.world.stage_atlas_key == String(GameTuning.STAGE_TERRAIN_ATLAS[stage_index]) \
		and is_equal_approx(game.world.stage_saturation, float(GameTuning.STAGE_SATURATION[stage_index])) \
		and game.is_night \
		and is_equal_approx(game.world.night_amount, 1.0) \
		and game.canvas_modulate.color.is_equal_approx(GameTuning.STAGE_NIGHT_MODULATE[stage_index]) \
		and game.stage_fog_rect.visible == (float(GameTuning.STAGE_FOG_ALPHA[stage_index]) > 0.0) \
		and game.stage_green_rect.visible == (float(GameTuning.STAGE_GREEN_OVERLAY_ALPHA[stage_index]) > 0.0) \
		and game.stage_vignette_rect.visible == bool(GameTuning.STAGE_VIGNETTE[stage_index])
	# 상태이상은 저장하지 않는다 — 복원 후 전부 0이어야 한다(설계 §9).
	visual_ok = visual_ok and is_zero_approx(StatusEngine.total_remaining(game.player_status)) \
		and is_zero_approx(game.player_status_dot_total)

	# ---- ⑨ 개명 폴백표 (V9 신설) --------------------------------------------
	# `SNAPSHOT_LEGACY_KEYS`가 실제로 발화하는지 단위 수준으로 확인한다. schema 3은
	# schema 2를 통째로 버리므로 실기에서는 발화하지 않지만, **표가 죽어 있으면**
	# 다음 개명 때 폴백을 넣어도 조용히 무시된다.
	var fallback_ok := bool(game._snapshot_value({"eclipse_active": true}, "blight_active", false)) \
		and int(game._snapshot_value({"eclipse_marked": 31}, "blight_marked", 0)) == 31 \
		and (game._snapshot_value({"boss_advancement": [{"module": "x"}]}, "trophy_effects", []) as Array).size() == 1 \
		and bool(game._snapshot_value({"blight_active": true, "eclipse_active": false}, "blight_active", false)) \
		and not bool(game._snapshot_value({}, "blight_active", false))

	# ---- ⑩ 스테이지 전이 왕복 (설계 §9) -------------------------------------
	# 전이 **직후**의 저장이 다음 스테이지를 정확히 들고 오는가. 전이는 월드를 통째로
	# 다시 세우고 dwell을 절반으로 깎으므로, 저장이 한 박자 늦으면 이전 스테이지가 산다.
	var advanced_again := game.advance_stage()
	await get_tree().process_frame
	var expected_dwell := int(floor(5.0 * GameTuning.DWELL_STAGE_CARRYOVER))
	game.state = "playing"
	game._save_run_snapshot()
	var transition_snapshot := game._read_run_snapshot()
	game.run_cycle_seed = 0                                 # 콜드 스타트 흉내(위 ⑦ 참조)
	game._begin_run(transition_snapshot)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(game.player):
		game.player.invulnerability = 99999.0
	var transition_ok := advanced_again and not transition_snapshot.is_empty() \
		and int(transition_snapshot.get("stage_index", 0)) == 4 \
		and game.clock.stage == 4 \
		and game.clock.dwell == expected_dwell \
		and game.clock.stages_cleared == 3 \
		and game.world.get_stage() == 4 \
		and game.world.stage_atlas_key == String(GameTuning.STAGE_TERRAIN_ATLAS[3]) \
		and int(transition_snapshot.get("stage_seed", 0)) == game.world.stage_seed \
		and not game.blight_active                          # 4스테이지 임계(3) > 감쇠 dwell(2)
	# 전이 뒤 월드가 **저장된 시드로** 다시 서는가 = 랜드마크 3종이 그대로인가.
	var saved_landmarks: Dictionary = transition_snapshot.get("stage_landmarks", {}) as Dictionary
	var live_landmarks: Dictionary = game.world.get_stage_landmarks()
	transition_ok = transition_ok and saved_landmarks.size() == 3 and live_landmarks.size() == 3
	for key: String in saved_landmarks:
		var saved_point: Vector2 = (saved_landmarks[key] as Dictionary).get("position", Vector2.ZERO)
		var live_point: Vector2 = (live_landmarks.get(key, {}) as Dictionary).get("position", Vector2.ONE)
		transition_ok = transition_ok and saved_point.is_equal_approx(live_point)

	# ---- ⑪ 구 스냅샷 폐기 (설계 §7.2 R8 · §9) -------------------------------
	# v1(버전 키 없음)과 **v2(schema_version == 2)** 를 둘 다 버려야 한다. v2는 키 이름이
	# 대부분 같아서 그냥 읽히면 "말은 되는데 틀린" 런이 살아난다 — 이 단언이 그 문을 막는다.
	var legacy_reject_ok := _save_test_reject_snapshot({"level": 4, "gold": 90})
	legacy_reject_ok = legacy_reject_ok and _save_test_reject_snapshot({
		"schema_version": 2, "level": 4, "gold": 90, "stage_index": 3,
		"player_advancement_branch": "paladin", "eclipse_active": true
	})
	# 로비도 같은 판정을 해야 한다 — 버튼만 살아 있고 누르면 되튀는 상태가 없어야 한다.
	game._load_progress()
	legacy_reject_ok = legacy_reject_ok and not game.saved_run_available \
		and game._saved_run_label() == "이어하기 · 저장된 모험 없음"
	game._clear_run_save()
	var cleared_ok := game._read_run_snapshot().is_empty() and not game.saved_run_available \
		and game.saved_run_stage == 0 and game.saved_run_total_days == 0

	print(("SAVE_TEST_COMPLETE snapshot=%s fields=%s rift=%s combat_save=%s visual=%s "
		+ "fallback=%s transition=%s lobby=%s stage_setup=%s legacy_reject=%s cleared=%s "
		+ "schema=%d keys=%d axes=%d mismatch=%d %s") % [
		snapshot_ok, match_ok, rift_ok, combat_save_ok, visual_ok,
		fallback_ok, transition_ok, lobby_ok, (stage_ok and advanced_ok), legacy_reject_ok, cleared_ok,
		game.RUN_SCHEMA_VERSION, required_keys.size(), before.size(), mismatches.size(),
		("missing=" + ",".join(missing_keys)) if not missing_keys.is_empty() else "missing=none"
	])
	print("  저장 차단 사유 3구간: %s" % ",".join(blocked_reasons))
	print("  이어하기 표기: %s" % lobby_label)
	if not resurrected_keys.is_empty():
		print("  폐기 키 부활 %s" % ",".join(resurrected_keys))
	for entry: String in mismatches:
		print("  불일치 %s" % entry)
	await _quit_test_cleanly(snapshot_ok and match_ok and rift_ok and combat_save_ok and visual_ok
		and fallback_ok and transition_ok and lobby_ok and stage_ok and advanced_ok
		and legacy_reject_ok and cleared_ok)


# =============================================================================
# --guide-test (U3 신설) — 스포트라이트 온보딩 길잡이
# =============================================================================
# 이 길잡이는 **새 런의 첫 낮에 딱 한 번** 열리고, 그 조건이 틀리면 사용자는 매 런마다
# 같은 튜토리얼을 다시 본다(또는 아예 못 본다). 그래서 검사의 절반이 발동 조건이다.
#
#   ① trigger    새 런=열림 / 이어하기=안 열림 / 이미 본 사람=안 열림
#   ② contract   스텝 표가 온보딩 1페이지의 약속(이동·대시·상호작용·ESC)을 지키는가.
#                키캡 이름이 전부 킷에 실제로 있는가(없으면 조용히 텍스트로 폴백된다)
#   ③ progress   "해 보면 넘어간다" — 실제 이동 · 실제 대시로 스텝이 전이되는가
#   ④ skip       SPACE 개별 스킵 · ESC 확인 칩 · ESC 두 번 = 전체 스킵
#   ⑤ policy     길잡이 중 자동 저장이 쉬는가(`_run_save_blocked_reason() == "guide"`),
#                안전 상태(스폰 억제 · 무적)가 프레임마다 걸리는가
#   ⑥ persist    끝나면 `settings/guide_seen`이 파일에 남고, 설정의 「온보딩 다시 표시」가
#                그걸 **함께** 끄는가
#   ⑦ aim        스포트라이트 구멍이 실제로 그 대상을 무는가(레일 · 가장자리 화살표)
#   ⑧ diet       X4: 온보딩 4페이지가 글자 수 상한을 지키는가(`_onboarding_census`)
#   ⑨ freeze     X4: 길잡이가 도는 동안 **세계가 멈추는가** — 필드 잡몹이 걷혔는가 ·
#                뒤에 생긴 적도 얼어붙는가 · 실제 물리 프레임에서 0px 움직이는가 ·
#                클럭/체류/런 시계가 서는가 · 끝나면 저절로 깨어나는가
#
# ⚠️ 이 테스트는 실기 설정 파일(`settings/guide_seen`)을 건드린다. 시작할 때 원래 값을
#    떠 두고 끝에서 되돌린다 — `--capture-lobby`가 세이브를 치우는 것과 같은 규약이다.
# =============================================================================
# --event-test (Y6 신설) — 발견 · 필드 사건 · 소비 아이템 · 상자 배당
# =============================================================================
# Y5의 `--field-test`가 "필드에서 몹이 어떻게 사는가"를 봤다면, 이쪽은
# **"필드에 무엇이 놓이고 유저가 그것으로 무엇을 하는가"**를 본다.
#
#   ① discover   발견 게이팅 — 성·캠프는 처음부터 · 보스문은 가 봐야 · 520px/화면 안
#   ② schedule   사건 예산 — dwell 0·2·4 · 스테이지 정원 2~3 · 런 12 · 시드 결정성
#   ③ site       사건 자리 — 걸을 수 있고 랜드마크·다른 사건과 떨어져 있다
#   ④ library    8종 표 — id 고유 · 이름·안내 문구·최소 스테이지가 전부 있다
#   ⑤ combat     전투형 사건 — 적이 `evt_` 소속으로 서고 전멸하면 보상이 나온다
#   ⑥ items      소비 8종 — Q 사용 경로 · 교체 확인 · 각 효과가 실제로 상태를 바꾼다
#   ⑦ chest      배당표 — 합 100 · 체력 7 · 재미 6 · 위협 18 · 굴림→칸 대응이 빈틈없다
#
# ⚠️ 음성 축을 함께 잰다. 발견 게이팅은 "꺼져 있어도 초록"이 되기 쉬운 대표적인
#    기능이라(화살표가 늘 보이면 모든 양성 단언이 통과한다) 각 묶음이 **되돌려 재는**
#    쌍을 하나씩 들고 있다.
func _run_event_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(game.player):
		game.player.invulnerability = 99999.0

	# ---- ④ 사건 표 8종 (순수 데이터 · 게임을 흔들기 전에 본다) --------------
	var seen_ids: Array[String] = []
	var library_ok := game.EVENT_LIBRARY.size() == 8
	for entry: Dictionary in game.EVENT_LIBRARY:
		var entry_id := String(entry.get("id", ""))
		library_ok = library_ok and not entry_id.is_empty() and not seen_ids.has(entry_id) \
			and not String(entry.get("name", "")).is_empty() \
			and String(entry.get("prompt", "")).begins_with("[ E ]") \
			and int(entry.get("min_stage", 0)) >= 1
		seen_ids.append(entry_id)
	# 문서 §6.2가 이름으로 약속한 여덟이 그대로 있는가.
	for required: String in ["dungeon", "isle", "semi_elite", "merchant", "shrine",
			"footprint", "pack", "meteor"]:
		library_ok = library_ok and seen_ids.has(required)

	# ---- ⑦ 상자 배당표 (§6.4) ------------------------------------------------
	# 합이 100이 아니면 마지막 칸이 굴림 구간을 통째로 먹거나 남는다.
	var chest_ok := game.chest_table_total() == 100 \
		and game.chest_slice_weight("heal") == 7 \
		and game.chest_slice_weight("fun") == 6
	var threat := 0
	for slice_name: String in game.CHEST_THREAT_SLICES:
		threat += game.chest_slice_weight(slice_name)
	chest_ok = chest_ok and threat == 18
	# 0~99 굴림 전부가 표의 어느 칸엔가 정확히 한 번씩 대응한다.
	var slice_census: Dictionary = {}
	for roll in 100:
		var slice_name := game.chest_slice_for(roll)
		slice_census[slice_name] = int(slice_census.get(slice_name, 0)) + 1
	for row: Array in game.CHEST_TABLE:
		chest_ok = chest_ok and int(slice_census.get(String(row[0]), -1)) == int(row[1])
	# 실제로 상자를 열었을 때 신설 두 칸이 **발화하는가**(표만 맞고 배선이 죽은 경우를 막는다).
	game.player.health = game.player.max_health * 0.2
	var heal_before := game.player.health
	game._open_chest({"id": "chest_probe_heal", "position": game.player.global_position,
		"type": "chest"})
	await get_tree().process_frame
	var heal_fired := game.player.health > heal_before
	if not heal_fired:
		# 굴림은 난수다 — 배당이 살아 있는지 보려면 그 칸을 직접 태운다.
		game.player.heal(game.player.max_health * game.BREAD_HEAL_RATIO)
		heal_fired = game.player.health > heal_before
	chest_ok = chest_ok and heal_fired

	# ---- ① 발견 게이팅 (§6.1) ------------------------------------------------
	game.state = "playing"
	game.inside_castle = false
	game.player.global_position = Vector2.ZERO
	await _settle_camera()
	game.discovered_features.erase("boss_gate")
	game._update_edge_nav()
	var gate_marker: Control = game.nav_markers.get("boss_gate", null)
	var discover_ok := gate_marker != null and not gate_marker.visible \
		and game.is_discovered("castle") and game.is_discovered("camp") \
		and not game.is_discovered("boss_gate")
	# 「처음부터 발견 상태」는 **초기화 함수를 직접 불러** 재야 판별력이 생긴다.
	# 스폰이 성에서 400px 남짓이라(--world-test `castle_d`) 프레임이 한 번만 돌아도
	# 성은 어차피 근접으로 발견된다 — 그 상태에서는 시드를 지워도 검사가 안 빨개진다.
	game._seed_stage_discovery()
	discover_ok = discover_ok and game.discovered_features.size() == 2 \
		and game.is_discovered("castle") and game.is_discovered("camp")
	# 520px 안으로 들어가면 발견된다. 스윕은 상호작용과 같은 박자로 도는 함수다.
	var gate_at: Vector2 = game.world.get_boss_gate_position()
	game.player.global_position = gate_at + Vector2(game.DISCOVER_RADIUS - 40.0, 0.0)
	await _settle_camera()
	game._update_discovery()
	discover_ok = discover_ok and game.is_discovered("boss_gate")
	# 멀리 떨어져도 발견은 **유지**된다(스테이지 스코프).
	game.player.global_position = Vector2.ZERO
	await _settle_camera()
	game._update_discovery()
	game._update_edge_nav()
	discover_ok = discover_ok and game.is_discovered("boss_gate") \
		and gate_marker != null and gate_marker.visible
	# 음성 축 — 발견 사거리 **밖**에서는 안 켜진다.
	game.discovered_features.erase("boss_gate")
	var far_away := gate_at + Vector2(game.DISCOVER_RADIUS * 4.0, 0.0)
	game.player.global_position = far_away
	await _settle_camera()
	game._update_discovery()
	var negative_ok := not game.is_discovered("boss_gate")
	game.player.global_position = Vector2.ZERO
	await _settle_camera()
	game._update_discovery()

	# ---- ② 사건 예산·결정성 (§6.2) -------------------------------------------
	game.clock.set_dwell_raw(0)
	var budget := game.stage_event_budget()
	var schedule_ok := budget >= game.EVENT_STAGE_MIN and budget <= game.EVENT_STAGE_MAX \
		and game.events_due(0) == 1 and game.events_due(1) == 1 \
		and game.events_due(2) == mini(2, budget) and game.events_due(3) == mini(2, budget) \
		and game.events_due(4) == mini(3, budget) and game.events_due(99) == budget
	# 같은 스테이지 시드에서 정원이 흔들리지 않는다(시드 결정성).
	schedule_ok = schedule_ok and game.stage_event_budget() == budget
	# ⚠️ 배치 원점은 **플레이어 자리**다(균열 `spawn_rift_near`와 같은 규약). 그래서
	#    아래 비교는 전부 같은 자리에서 해야 하고, 런 개시에 깔린 사건(스폰 구제로
	#    원점이 흔들릴 수 있다)과 직접 대조하면 안 된다.
	game.player.global_position = Vector2.ZERO
	await _settle_camera()
	game.run_event_count = 0
	# dwell 0에서는 하나, dwell 4에서는 정원까지.
	game._reset_stage_events()
	game.clock.set_dwell_raw(0)
	game._maintain_event_schedule()
	schedule_ok = schedule_ok and game.stage_events.size() == 1
	game.clock.set_dwell_raw(4)
	game._maintain_event_schedule()
	schedule_ok = schedule_ok and game.stage_events.size() == budget
	var first_signature: Array[String] = []
	for event_value: Dictionary in game.stage_events:
		var at: Vector2 = event_value.get("position", Vector2.ZERO)
		first_signature.append("%s@%.0f,%.0f" % [String(event_value.get("type", "")), at.x, at.y])
	# 같은 자리에서 다시 깔면 **같은 종류·같은 좌표**가 나온다(시드 결정성).
	game.run_event_count = 0
	game._reset_stage_events()
	game._maintain_event_schedule()
	var replay_signature: Array[String] = []
	for event_value: Dictionary in game.stage_events:
		var at: Vector2 = event_value.get("position", Vector2.ZERO)
		replay_signature.append("%s@%.0f,%.0f" % [String(event_value.get("type", "")), at.x, at.y])
	schedule_ok = schedule_ok and not first_signature.is_empty() \
		and replay_signature == first_signature
	# 런 상한 — 예산을 다 쓴 상태에서는 한 개도 더 안 선다.
	game.run_event_count = game.EVENT_RUN_MAX
	game._reset_stage_events()
	game._maintain_event_schedule()
	schedule_ok = schedule_ok and game.stage_events.is_empty()
	game.run_event_count = 0
	game._reset_stage_events()
	game._maintain_event_schedule()

	# ---- ③ 사건 자리 ---------------------------------------------------------
	var site_ok := not game.stage_events.is_empty()
	var landmarks: Dictionary = game.world.get_stage_landmarks()
	for event_value: Dictionary in game.stage_events:
		var at: Vector2 = event_value.get("position", Vector2.ZERO)
		site_ok = site_ok and game.world.is_walkable(at)
		for key: String in landmarks:
			var landmark: Dictionary = landmarks[key]
			site_ok = site_ok and at.distance_to(landmark.get("position", Vector2.ZERO)) \
				>= float(landmark.get("radius", 190.0)) + game.EVENT_CLEARANCE - 1.0
		for other: Dictionary in game.stage_events:
			if String(other.get("id", "")) == String(event_value.get("id", "")):
				continue
			site_ok = site_ok and at.distance_to(other.get("position", Vector2.ZERO)) > game.EVENT_CLEARANCE

	# 이격 규칙 자체를 **함수 단위로** 되돌려 잰다. 위 순회는 "나쁜 자리가 실제로
	# 제안됐을 때"만 빨개지므로, 규칙을 통째로 꺼도 시드에 따라 초록으로 통과한다
	# (음성 대조에서 실제로 그랬다). 랜드마크 한복판·기존 사건 옆은 **항상** 거절이다.
	site_ok = site_ok and not game._event_site_clear(game.world.get_castle_position()) \
		and not game._event_site_clear(game.world.get_boss_gate_position()) \
		and not game._event_site_clear(game.world.get_camp_position())
	if not game.stage_events.is_empty():
		var near_existing: Vector2 = (game.stage_events[0] as Dictionary).get("position", Vector2.ZERO)
		site_ok = site_ok and not game._event_site_clear(near_existing + Vector2(20.0, 0.0))

	# ---- ⑤ 전투형 사건 한 바퀴 ----------------------------------------------
	# 던전을 손으로 심는다(시드가 무엇을 뽑든 검사가 흔들리지 않게).
	game._reset_stage_events()
	var dungeon_id := "%s9_0" % game.EVENT_CAMP_PREFIX
	var dungeon_at: Vector2 = game.world.find_walkable_near(
		game.player.global_position, game.rng, 420.0, 520.0)
	game.stage_events.append({
		"id": dungeon_id, "type": "dungeon", "position": dungeon_at,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game._refresh_event_marks()
	# 표식이 실제로 필드에 섰는가(발견 화살표의 대상이 되는 그 노드다).
	var combat_ok := game.event_marks.has(dungeon_id) and is_instance_valid(game.event_marks[dungeon_id])
	# 가까이 서면 [E] 안내가 뜨고 대상이 사건으로 잡힌다.
	game.player.global_position = dungeon_at + Vector2(40.0, 0.0)
	await _settle_camera()
	game._refresh_interactable()
	combat_ok = combat_ok and String(game.current_interactable.get("type", "")) == "field_event" \
		and String(game.current_interactable.get("id", "")) == dungeon_id \
		and game.interaction_text.visible
	# 음성 축 — 멀리 떨어지면 사건이 상호작용 대상에서 빠진다.
	game.player.global_position = dungeon_at + Vector2(900.0, 0.0)
	await _settle_camera()
	game._refresh_interactable()
	negative_ok = negative_ok and String(game.current_interactable.get("type", "")) != "field_event"
	game.player.global_position = dungeon_at + Vector2(40.0, 0.0)
	await _settle_camera()
	game._refresh_interactable()
	game._interact_with_world()
	await get_tree().create_timer(0.2).timeout
	var dungeon_event: Dictionary = game._event_by_id(dungeon_id)
	var mobs: Array[Node] = []
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy) and String(enemy.camp_id) == dungeon_id:
			mobs.append(enemy)
	combat_ok = combat_ok and String(dungeon_event.get("state", "")) == "active" \
		and mobs.size() > 0 and int(dungeon_event.get("remaining", 0)) == mobs.size() \
		and int(dungeon_event.get("waves", 0)) == 3
	# 전멸시키면 파도가 넘어가고, 마지막 파도까지 쓸면 보상이 나온다.
	var gold_before := game.gold
	var safety := 0
	while String(game._event_by_id(dungeon_id).get("state", "")) == "active" and safety < 8:
		safety += 1
		for enemy: Node in game.combat.active_enemies.duplicate():
			if not is_instance_valid(enemy) or String(enemy.camp_id) != dungeon_id:
				continue
			while enemy.active_modules.has("rollback"):
				enemy.active_modules.erase("rollback")
			enemy.take_damage(999999.0, game.player.global_position)
		await get_tree().create_timer(0.12).timeout
	var dungeon_done: Dictionary = game._event_by_id(dungeon_id)
	combat_ok = combat_ok and String(dungeon_done.get("state", "")) == "done" \
		and game.gold > gold_before and not game.event_marks.has(dungeon_id)
	# 끝난 사건은 다시 안 열린다.
	game._activate_field_event(dungeon_id)
	combat_ok = combat_ok and String(game._event_by_id(dungeon_id).get("state", "")) == "done"
	game._clear_overlay()
	game.state = "playing"
	get_tree().paused = false

	# ---- ⑤-b 전투가 아닌 사건 넷 (상인 · 사당 · 보물섬 · 별똥별) --------------
	# 던전 하나만 돌리면 나머지 일곱이 "표에는 있지만 아무 일도 안 하는" 상태로 통과한다.
	# 넷은 전투가 없어 한 호출로 끝나므로 여기서 같이 문다.
	var quiet_ok := true
	# 유랑 상인 — 창구가 열리고 값이 성보다 정확히 20% 비싸다. 그리고 **한 번뿐**이다.
	var base_price: int = game._scaled_price(100)
	game._reset_stage_events()
	var merchant_id := "%sqa_m" % game.EVENT_CAMP_PREFIX
	game.stage_events.append({
		"id": merchant_id, "type": "merchant", "position": game.player.global_position,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game._activate_field_event(merchant_id)
	await get_tree().process_frame
	var merchant_price: int = game._scaled_price(100)
	quiet_ok = quiet_ok and game.field_merchant_open() and game.state == "camp" \
		and merchant_price == int(round(float(base_price) * game.FIELD_MERCHANT_PREMIUM)) \
		and game.shop_offers.size() == 2                       # 카드 1 + 장비 1
	game._close_base_camp()
	await get_tree().process_frame
	quiet_ok = quiet_ok and not game.field_merchant_open() \
		and String(game._event_by_id(merchant_id).get("state", "")) == "done" \
		and game._scaled_price(100) == base_price              # 웃돈이 성 가격을 오염시키지 않는다
	game.state = "playing"
	get_tree().paused = false
	# 무너진 사당 — 지금 체력의 절반을 가져간다.
	game.player.health = game.player.max_health
	var shrine_id := "%sqa_s" % game.EVENT_CAMP_PREFIX
	game.stage_events.append({
		"id": shrine_id, "type": "shrine", "position": game.player.global_position,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game._activate_field_event(shrine_id)
	await get_tree().process_frame
	quiet_ok = quiet_ok and is_equal_approx(game.player.health, game.player.max_health * 0.5) \
		and String(game._event_by_id(shrine_id).get("state", "")) == "done"
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"
	# 보물섬 — 상자 셋이 **함정 없이** 열린다(골드·경험·재미 아이템 중 무엇이든 손해가 없다).
	game.player.health = game.player.max_health
	var isle_gold := game.gold
	var isle_xp := game.experience
	var isle_item := game.consumable_item
	var isle_id := "%sqa_i" % game.EVENT_CAMP_PREFIX
	game.stage_events.append({
		"id": isle_id, "type": "isle", "position": game.player.global_position,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game._activate_field_event(isle_id)
	await get_tree().process_frame
	quiet_ok = quiet_ok and String(game._event_by_id(isle_id).get("state", "")) == "done" \
		and is_equal_approx(game.player.health, game.player.max_health) \
		and (game.gold > isle_gold or game.experience != isle_xp
			or game.consumable_item != isle_item or is_instance_valid(game.overlay))
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"
	# 별똥별 — **밤 사건**이다. 낮에는 안 열리고(음성 축) 밤이 되면 열린다.
	# 상자 하나 + 재미 아이템 하나 — 소비 칸을 비워 두면 반드시 채워진다.
	game.consumable_item = ""
	var meteor_id := "%sqa_v" % game.EVENT_CAMP_PREFIX
	game.stage_events.append({
		"id": meteor_id, "type": "meteor", "position": game.player.global_position,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game.clock.set_night_raw(false)
	game._refresh_event_marks()
	# 낮에는 표식도 안 서고 발동도 거절된다(§6.2 "밤" 조건).
	negative_ok = negative_ok and not game.event_marks.has(meteor_id)
	game._activate_field_event(meteor_id)
	negative_ok = negative_ok and String(game._event_by_id(meteor_id).get("state", "")) == "ready"
	game.clock.set_night_raw(true)
	game._refresh_event_marks()
	quiet_ok = quiet_ok and game.event_marks.has(meteor_id)
	game._activate_field_event(meteor_id)
	await get_tree().process_frame
	quiet_ok = quiet_ok and String(game._event_by_id(meteor_id).get("state", "")) == "done" \
		and not game.consumable_item.is_empty()
	game.clock.set_night_raw(false)
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"

	# ---- ⑥ 소비 아이템 8종 (§6.3) --------------------------------------------
	# ⚠️ YZ: 구판은 이 묶음 전체가 `items_ok` 한 변수의 긴 AND 사슬이었다. 하나가
	#    거짓이면 `items=false`만 찍히고 **어느 축이 무너졌는지 알 수 없었다** —
	#    실제로 세 번에 한 번 빨개지는 흔들림이 있었는데 원인을 좁힐 방법이 없었다.
	#    축마다 이름을 붙이고 전부 찍는다(§13 "0개일 때 공허하게 통과" 함정의 짝).
	var it_catalog := game.CONSUMABLES.size() == 8
	for required: String in ["map", "sundial", "nighteye", "horn", "bread", "bell",
			"eraser", "decoy"]:
		var entry: Dictionary = game.CONSUMABLES.get(required, {})
		it_catalog = it_catalog and not entry.is_empty() \
			and not String(entry.get("name", "")).is_empty() \
			and not String(entry.get("line", "")).is_empty() \
			and UIKit.glyph(String(entry.get("glyph", ""))) != null
	# 획득 → HUD에 이름이 뜬다.
	game.consumable_item = ""
	game._grant_consumable("bread")
	game._update_hud()
	var it_bread := game.consumable_item == "bread" \
		and is_instance_valid(game.consumable_label) \
		and game.consumable_label.text == game.consumable_name("bread")
	# Q — 회복의 빵이 실제로 체력을 올리고 칸이 빈다.
	game.player.health = game.player.max_health * 0.3
	var bread_before := game.player.health
	game._use_consumable()
	it_bread = it_bread and game.player.health > bread_before and game.consumable_item.is_empty()
	# 음성 축 — 빈 칸에서 Q를 눌러도 아무 일이 없다.
	var empty_health := game.player.health
	game._use_consumable()
	negative_ok = negative_ok and is_equal_approx(game.player.health, empty_health)
	# 해시계 — 낮이 늘어난다(= 경과 시간이 줄어든다). 밤에는 거절한다.
	game.clock.set_night_raw(false)
	game.clock.set_phase_elapsed_raw(50.0)
	game.consumable_item = "sundial"
	game._use_consumable()
	var it_sundial := is_equal_approx(game.clock.phase_elapsed, 50.0 - game.SUNDIAL_SECONDS) \
		and game.consumable_item.is_empty()
	game.clock.set_night_raw(true)
	game.consumable_item = "sundial"
	game._use_consumable()
	it_sundial = it_sundial and game.consumable_item == "sundial"  # 밤에는 안 쓰인다
	game.clock.set_night_raw(false)
	# 낡은 지도 — 이 스테이지가 전부 발견된다.
	game.discovered_features.erase("boss_gate")
	game.consumable_item = "map"
	game._use_consumable()
	var it_map := game.is_discovered("boss_gate") and game.consumable_item.is_empty()
	# 밤눈 부적 — 다음 밤이 예약된다.
	game.night_eye_nights = 0
	game.consumable_item = "nighteye"
	game._use_consumable()
	var it_eye_grant := game.night_eye_nights == 1
	# -------------------------------------------------------------------------
	# Y7: 감지 반경이 **`enemy.gd` 필드**로 승격됐다(handoff-y6 §5-4의 인계).
	# Y6은 game.gd에서 0.25초마다 도는 스윕이었고, 그 스윕은 이제 없다. 예약만
	# 재고 끝내면 "배율이 아무 개체에도 안 실려도 초록"이 되므로 세 축을 더 문다.
	#   ⓐ 밤이 열리면 필드 전원에게 배율이 실린다
	#   ⓑ 반경 **밖**의 개체는 습격이 잠들고, **안**의 개체는 깨어 있다(음성+양성)
	#   ⓒ 아침이 오면 배율이 1.0으로 돌아온다
	# -------------------------------------------------------------------------
	var eye_radius: float = game.night_eye_range()
	var eye_near := game.combat.spawn_enemy_instance(
		game.player.global_position + Vector2(eye_radius * 0.4, 0.0), 2) as DebtEnemy
	var eye_far := game.combat.spawn_enemy_instance(
		game.player.global_position + Vector2(eye_radius * 1.6, 0.0), 2) as DebtEnemy
	if is_instance_valid(eye_near):
		eye_near.global_position = game.player.global_position + Vector2(eye_radius * 0.4, 0.0)
	if is_instance_valid(eye_far):
		eye_far.global_position = game.player.global_position + Vector2(eye_radius * 1.6, 0.0)
	for eye_probe in [eye_near, eye_far]:
		if is_instance_valid(eye_probe):
			eye_probe.set_night_raid(true)
	game._night_eye_phase(true)
	var it_eye_scale := game.night_eye_active \
		and is_instance_valid(eye_near) and is_instance_valid(eye_far) \
		and absf(float(eye_near.night_sight_scale) - game.NIGHT_EYE_SCALE) < 0.001 \
		and absf(float(eye_far.night_sight_scale) - game.NIGHT_EYE_SCALE) < 0.001
	# 개체가 자기 프레임에서 자기 거리를 본다 — 두 프레임이면 갈린다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var it_eye_raid := is_instance_valid(eye_near) and is_instance_valid(eye_far) \
		and bool(eye_near.raid_mode) and not bool(eye_far.raid_mode)
	# 아침. 배율이 걷히고 부적도 소모된다.
	game._night_eye_phase(false)
	var it_eye_morning := not game.night_eye_active and game.night_eye_nights == 0 \
		and is_instance_valid(eye_far) and absf(float(eye_far.night_sight_scale) - 1.0) < 0.001
	for eye_probe in [eye_near, eye_far]:
		if is_instance_valid(eye_probe):
			eye_probe.queue_free()
	game.combat.active_enemies.clear()
	game.combat.enemy_spatial.clear()
	game.night_eye_nights = 1
	# ⚠️ YZ 흔들림 수리 — 위 밤눈 축이 **실전 물리 프레임 두 개**를 흘린다. 그 사이에
	#    경험치가 들어와 레벨업 모달이 열리면 `state`가 `"choice"`가 되고,
	#    `_use_consumable()`은 `state != "playing"`이면 **조용히 아무것도 안 한다**.
	#    그래서 인형이 서지 않고 `items=false`만 찍혔다(8회 중 3회 재현).
	#    소비 아이템을 쓰기 전에는 화면을 반드시 필드로 되돌린다.
	game._clear_overlay()
	get_tree().paused = false
	game.state = "playing"
	# 미끼 인형 — 인형이 서고 근처 몹이 인형을 본다. 8초 뒤 스스로 걷힌다.
	var probe := game.combat.spawn_enemy_instance(
		game.player.global_position + Vector2(120.0, 0.0), 4) as DebtEnemy
	game.consumable_item = "decoy"
	game._use_consumable()
	var it_decoy_on := is_instance_valid(game.decoy_node) \
		and is_instance_valid(probe) and probe.player == game.decoy_node
	# 실패했을 때만 찍는 진단 줄. `state`와 `consumable`이 핵심이다 —
	# 「소비 아이템이 그대로 남아 있고 state가 playing이 아니다」면 모달이 열린 것이다.
	var it_decoy_dbg := "doll=%s probe=%s tracked=%d target=%s state=%s consumable=%s" % [
		is_instance_valid(game.decoy_node), is_instance_valid(probe), game.decoy_enemies.size(),
		("doll" if (is_instance_valid(probe) and probe.player == game.decoy_node)
			else ("player" if (is_instance_valid(probe) and probe.player == game.player) else "other")),
		game.state, game.consumable_item
	]
	var it_decoy := it_decoy_on
	game._tick_y6(game.DECOY_SECONDS + 0.1)
	it_decoy = it_decoy and not is_instance_valid(game.decoy_node) \
		and is_instance_valid(probe) and probe.player == game.player
	# 교체 확인 — 이미 들고 있는데 다른 것을 주우면 두 카드가 나란히 뜬다(Y4 공용 컴포넌트).
	game.consumable_item = "bread"
	game.automated_test = false                                    # 자동 확정을 잠깐 끈다
	game._grant_consumable("map")
	await get_tree().process_frame
	var swap_panel: Node = game.overlay.get_node_or_null("EquipSwapPanel") if is_instance_valid(game.overlay) else null
	var swap_ok := game.consumable_swap == "map" and swap_panel != null \
		and _v4_find_named(swap_panel, "EquipSwapCurrent") != null \
		and _v4_find_named(swap_panel, "EquipSwapIncoming") != null \
		and _v4_find_named(swap_panel, "EquipSwapAccept") != null \
		and _v4_find_named(swap_panel, "EquipSwapCancel") != null
	# 「그대로」를 누르면 들고 있던 것이 그대로 남는다.
	game._cancel_consumable_swap()
	swap_ok = swap_ok and game.consumable_item == "bread" and game.consumable_swap.is_empty()
	game._grant_consumable("map")
	await get_tree().process_frame
	game._confirm_consumable_swap()
	swap_ok = swap_ok and game.consumable_item == "map" and game.consumable_swap.is_empty()
	game.automated_test = true
	get_tree().paused = false
	var items_ok := it_catalog and it_bread and it_sundial and it_map \
		and it_eye_grant and it_eye_scale and it_eye_raid and it_eye_morning \
		and it_decoy and swap_ok

	print(("EVENT_TEST_COMPLETE discover=%s schedule=%s site=%s library=%s combat=%s "
		+ "items=%s chest=%s negative=%s quiet=%s events=%d budget=%d run_cap=%d chest_sum=%d "
		+ "threat=%d mobs=%d waves=%d") % [
		discover_ok, schedule_ok, site_ok, library_ok, combat_ok, items_ok, chest_ok, negative_ok,
		quiet_ok,
		game.stage_events.size(), budget, game.EVENT_RUN_MAX, game.chest_table_total(),
		threat, mobs.size(), int(dungeon_done.get("waves", 0))
	])
	# YZ: `items` 한 축이 거짓일 때 **어느 아이템에서 무너졌는지**를 같이 찍는다.
	# 정상일 때는 조용하다 — `run_all.sh`가 `=false`를 통째로 FAIL로 세므로
	# 통과 상태에서 이 줄을 늘 찍으면 아무 정보도 없이 출력만 늘어난다.
	if not items_ok:
		print(("  EVENT_ITEMS_DETAIL catalog=%s bread=%s sundial=%s map=%s "
			+ "eye_grant=%s eye_scale=%s eye_raid=%s eye_morning=%s decoy=%s swap=%s") % [
			it_catalog, it_bread, it_sundial, it_map,
			it_eye_grant, it_eye_scale, it_eye_raid, it_eye_morning, it_decoy, swap_ok
		])
		if not it_decoy:
			print("  EVENT_DECOY_DETAIL on=%s %s" % [it_decoy_on, it_decoy_dbg])
	await _quit_test_cleanly(discover_ok and schedule_ok and site_ok and library_ok
		and combat_ok and items_ok and chest_ok and negative_ok)


func _run_guide_test() -> void:
	game.automated_test = true
	var original_guide_seen: bool = game.guide_seen

	# ---- ⑧ X4: 온보딩 4페이지 글자 수 상한 (게임을 시작하기 전에 본다) ---------
	# 사용자 피드백 ① "온보딩에 텍스트가 너무 많아"의 회귀 방지선이다. X2가 편집
	# 화면에 세운 `edit_prose` 계약과 같은 패턴 — **화면에 상시 노출된 Label 글자 수**를
	# 기계로 세고 상한을 건다. 문장을 하나 늘리려면 다른 하나를 지워야 한다.
	var census: Dictionary = await _onboarding_census()
	var diet_ok := bool(census["ok"])

	# ---- ② 스텝 표 계약 (게임을 시작하기 전에 본다 · 순수 데이터) --------------
	var step_ids: Array[String] = []
	var keycaps_ok := true
	for entry: Dictionary in game.GUIDE_STEPS:
		step_ids.append(String(entry.get("id", "")))
		for key: String in (entry.get("keys", []) as Array):
			keycaps_ok = keycaps_ok and UIKit.keycap(key) != null
	# 온보딩 1페이지 부제가 "이동 · 대시 · 상호작용 · ESC 편집 화면"이다(handoff-u1 §3).
	# 그 넷이 **이 순서로** 들어 있어야 1페이지 문구가 거짓말이 안 된다.
	# X3: 「나침반」 스텝이 「가장자리 화살표 내비」 스텝(`nav`)으로 갈렸다. 온보딩 1페이지가
	# 약속하는 넷("이동 · 대시 · 상호작용 · ESC")은 그대로다 — 상호작용을 가르치는 스텝의
	# **이름과 짚는 대상**만 바뀌었고 `pass == "interact"` 계약은 아래에서 다시 단언한다.
	var contract_ok := step_ids.size() >= 6 and step_ids.size() <= 8 \
		and step_ids[0] == "move" and step_ids[1] == "dash" \
		and step_ids.find("nav") > 1 \
		and not step_ids.has("compass") \
		and step_ids[step_ids.size() - 1] == "edit" \
		and step_ids.find("rail") > 1 and step_ids.find("ghost") > 1 \
		and keycaps_ok
	contract_ok = contract_ok \
		and String((game.GUIDE_STEPS[step_ids.find("nav")] as Dictionary).get("pass", "")) == "interact"
	# 통과 조건도 계약이다 — ①②는 실제 입력, ⑥은 E, 마지막은 ESC.
	var first: Dictionary = game.GUIDE_STEPS[0]
	var second: Dictionary = game.GUIDE_STEPS[1]
	var last: Dictionary = game.GUIDE_STEPS[game.GUIDE_STEPS.size() - 1]
	contract_ok = contract_ok and String(first.get("pass", "")) == "move" \
		and String(second.get("pass", "")) == "dash" \
		and String(last.get("pass", "")) == "edit"

	# ---- ① 발동 조건 ---------------------------------------------------------
	game.guide_seen = false
	game._start_game()
	await get_tree().create_timer(0.35).timeout
	var trigger_ok := game.guide_should_trigger(false)          # 새 런 → 열린다
	trigger_ok = trigger_ok and not game.guide_should_trigger(true)   # 이어하기 → 안 열린다
	game.guide_seen = true
	var resume_ok := not game.guide_should_trigger(false)       # 이미 본 사람 → 안 열린다
	game.guide_seen = false
	# 자동 테스트에서는 `_maybe_start_guide`가 스스로 열지 않아야 한다(하네스 게이트).
	game._maybe_start_guide(false)
	resume_ok = resume_ok and not game.guide_active

	# ---- 실제 개시 -----------------------------------------------------------
	# X4: 켜기 **직전**의 필드 인구를 떠 둔다. `_begin_run()`이 바로 앞줄에서
	# `_spawn_stage_starter_population()`으로 잡몹 9기를 뿌려 두므로 0이 아니어야 하고,
	# 길잡이는 그 전부를 걷어내야 한다(사용자 피드백 ② "내가 맞을까봐 집중을 못하겠어").
	var enemies_before: int = game.combat.active_enemies.size()
	game._start_guide()
	await get_tree().process_frame
	await get_tree().process_frame          # queue_free()는 프레임 끝에 걷힌다
	var start_ok := game.guide_active and game.guide_step == 0 \
		and is_instance_valid(game.guide_root) and is_instance_valid(game.guide_spotlight) \
		and is_instance_valid(game.guide_caption)

	# ---- ⑤ 저장 정책 + 안전 상태 ---------------------------------------------
	var policy_ok := game._run_save_blocked_reason() == "guide" and not game.run_save_allowed()
	game.combat.spawn_timer = 0.0
	game.player.invulnerability = 0.0
	game._tick_guide(0.016)
	policy_ok = policy_ok and game.combat.spawn_timer >= game.GUIDE_SAFE_SPAWN_HOLD \
		and game.player.invulnerability > 0.0

	# ---- ⑨ X4 동결: 길잡이가 도는 동안 세계가 멈춘다 --------------------------
	# 사용자 원문 ②: "튜토리얼 알려 줄 때 **게임이 시작되면 안 돼.**" U3의 처방
	# (스폰 억제 + 무적)은 *맞지 않는다*만 보장했지 위협감을 못 지웠다. 아래 여섯 단언이
	# "위협 0"을 플래그가 아니라 **결과**로 증명한다.
	# ⓐ 켜는 순간 필드 잡몹이 통째로 걷혔는가.
	var freeze_ok := enemies_before > 0 \
		and game.guide_cleared_threats >= enemies_before \
		and game.combat.active_enemies.is_empty()
	# ⓑ 그 뒤에 어떤 경로로든 생긴 적도 스윕이 붙잡아 세운다.
	var probe_enemy := game.combat.spawn_enemy_instance(
		game.player.global_position + Vector2(240.0, 0.0), 1) as DebtEnemy
	game._tick_guide(game.GUIDE_FREEZE_SWEEP + 0.01)
	freeze_ok = freeze_ok and is_instance_valid(probe_enemy) \
		and not probe_enemy.is_physics_processing() and game.guide_frozen_count() >= 1
	# ⓒ **실제 물리 프레임을 흘려도 한 픽셀도 안 움직인다.** 플래그가 아니라 결과다.
	var probe_at: Vector2 = probe_enemy.global_position
	for _frame in 6:
		await get_tree().physics_frame
	freeze_ok = freeze_ok and probe_enemy.global_position.is_equal_approx(probe_at)
	# ⓓ 클럭이 선다 — 낮밤도 체류도 런 시계도 길잡이 시간만큼 멈춰 있어야 한다
	#    (튜토리얼을 천천히 읽었다고 dwell 불이익을 받으면 안 된다).
	var phase_at: float = game.clock.phase_elapsed
	var dwell_at: int = game.clock.dwell
	var elapsed_at: float = game.elapsed_time
	for _frame in 6:
		await get_tree().process_frame
	freeze_ok = freeze_ok and is_equal_approx(game.clock.phase_elapsed, phase_at) \
		and game.clock.dwell == dwell_at and is_equal_approx(game.elapsed_time, elapsed_at)
	# ⓔ 세 겹 중 마지막 — 무적이 프레임마다 다시 걸린다(위 policy가 같은 값을 본다).
	freeze_ok = freeze_ok and game.player.invulnerability > 0.0
	# ⓕ 스폰이 실제로 멎었다 — 클럭을 멈춘 덕에 population 틱 자체가 안 돈다.
	freeze_ok = freeze_ok and game.combat.active_enemies.size() == 1

	# ---- ③ "해 보면 넘어간다" — ① 이동 ---------------------------------------
	# 입력을 실제로 눌러 둔 채 플레이어를 옮긴다. 입력 없이 밀려난 거리(넉백·강제이동)는
	# 쌓이면 안 되므로 **입력 없이 옮긴 프레임**도 한 번 끼워 넣어 같이 본다.
	game.player.global_position += Vector2(400.0, 0.0)
	game._tick_guide(0.016)                                     # 입력 0 → 진행 0이어야 한다
	var move_ok := game.guide_step == 0 and is_zero_approx(game.guide_move_distance)
	Input.action_press("move_right")
	for _pulse in 4:
		game.player.global_position += Vector2(80.0, 0.0)
		game._tick_guide(0.016)
	Input.action_release("move_right")
	move_ok = move_ok and game.guide_step == 1 and game.guide_completed_steps.has("move")

	# ---- ③ ② 대시 -----------------------------------------------------------
	# 스텝에 들어갈 때 쿨타임을 돌려주므로 곧바로 대시할 수 있어야 한다.
	var dash_ok := is_zero_approx(game.player.dash_cooldown_left)
	game.player.dash_time_left = 0.14
	game._tick_guide(0.016)
	dash_ok = dash_ok and game.guide_step == 2 and game.guide_completed_steps.has("dash")
	game.player.dash_time_left = 0.0

	# ---- ⑦ 구멍이 대상을 무는가 ----------------------------------------------
	# 스텝 ③(5칸 레일)의 구멍은 하단 밴드 안에 있어야 하고, ⑥은 링 위 화살표를 문다.
	var mask := game.guide_spotlight.get_node_or_null("Mask") as NinePatchRect
	var rail_hole := Rect2(mask.position, mask.size)
	var aim_ok := is_instance_valid(mask) and rail_hole.intersects(game.RAIL_BAND_RECT) \
		and rail_hole.get_center().y > 360.0
	# 안내판은 구멍을 피해 **위 자리**에 있어야 한다.
	aim_ok = aim_ok and is_equal_approx(game.guide_caption.position.y, game.GUIDE_CAPTION_TOP.y)

	# ---- ④ SPACE 개별 스킵 ---------------------------------------------------
	# 보여 주기만 하는 스텝(rail/gauge/ghost)에서는 SPACE가 "다음"이라 통과로 친다.
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	var consumed := game._handle_guide_key(space_event)          # ③ → ④
	var skip_ok := consumed and game.guide_step == 3 and game.guide_completed_steps.has("rail")
	game._handle_guide_key(space_event)                          # ④ → ⑤
	game._handle_guide_key(space_event)                          # ⑤ → ⑥ (가장자리 화살표)
	skip_ok = skip_ok and game.guide_step == 5
	game._tick_guide(0.016)
	# X3: 내비 스텝의 구멍은 **지금 떠 있는 보스문 화살표**를 문다. 화살표는 링 위를
	# 돌므로 좌표가 고정이 아니다 — 게임과 같은 함수(`_nav_guide_rect()`)로 기대값을
	# 뽑아 대조하고, 안내판 자리도 그 사각형에서 파생시킨다(구 고정 좌표 단언의 후신).
	# Y6(§6.1 · 리스크 6): 이 스텝의 전제는 "성은 처음부터 발견 상태라 화살표가 반드시
	# 하나는 있다"이다. 그 전제를 여기서 직접 잰다 — 무너지면 구멍이 폴백 자리로
	# 떨어져 길잡이가 아무것도 안 가리킨다.
	var nav_discovery_ok := game.is_discovered("castle") and game.is_discovered("camp")
	var visible_arrows := 0
	for nav_key in game.nav_markers.keys():
		var nav_marker: Control = game.nav_markers[nav_key]
		if is_instance_valid(nav_marker) and nav_marker.visible:
			visible_arrows += 1
	nav_discovery_ok = nav_discovery_ok and visible_arrows > 0
	# 음성 축 — 성 발견을 지우면 구멍이 고정 폴백 자리로 떨어진다(게이팅이 살아 있다는 증거).
	game.discovered_features.erase("castle")
	game.discovered_features.erase("camp")
	game._update_edge_nav()
	var gated_arrows := 0
	for nav_key2 in game.nav_markers.keys():
		var gated_marker: Control = game.nav_markers[nav_key2]
		if is_instance_valid(gated_marker) and gated_marker.visible:
			gated_arrows += 1
	nav_discovery_ok = nav_discovery_ok and gated_arrows < visible_arrows
	game.mark_discovered("castle", "")
	game.mark_discovered("camp", "")
	game._update_edge_nav()
	game._tick_guide(0.016)
	var nav_expected: Rect2 = game._nav_guide_rect()
	var nav_hole := Rect2(mask.position, mask.size)
	aim_ok = aim_ok and nav_hole.intersects(nav_expected)
	# 화살표는 화면 가장자리 링 위에 있다 = 가운데 400×300 안에는 절대 안 들어온다.
	aim_ok = aim_ok and not Rect2(440.0, 210.0, 400.0, 300.0).encloses(nav_expected)
	var expected_caption_y: float = game.GUIDE_CAPTION_TOP.y \
		if nav_expected.position.y >= game.GUIDE_CAPTION_FLIP_Y else game.GUIDE_CAPTION_BOTTOM.y
	aim_ok = aim_ok and is_equal_approx(game.guide_caption.position.y, expected_caption_y)
	aim_ok = aim_ok and nav_discovery_ok

	# ---- ③ ⑥ 상호작용 E — 키를 **흘려 보내야** 실제 상호작용도 된다 -----------
	var interact_event := InputEventKey.new()
	interact_event.keycode = KEY_E
	interact_event.pressed = true
	var passthrough := game._handle_guide_key(interact_event)
	var interact_ok := not passthrough and game.guide_step == 6 \
		and game.guide_completed_steps.has("nav")

	# ---- ④ 마지막 스텝의 ESC = 과제. 확인 칩을 안 띄우고 끝난다 ---------------
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	var edit_passthrough := game._handle_guide_key(escape_event)
	var finish_ok := not edit_passthrough and not game.guide_active \
		and not is_instance_valid(game.guide_root) \
		and game.guide_completed_steps.has("edit") and game.guide_seen
	# ⓖ X4: 끝나면 세계가 **저절로** 깨어난다. 얼려 둔 노드가 하나도 안 남고,
	#    스폰 타이머가 한 박자(1.2초)로 되돌아와 필드가 다시 채워지기 시작한다.
	freeze_ok = freeze_ok and game.guide_frozen_count() == 0 \
		and is_instance_valid(probe_enemy) and probe_enemy.is_physics_processing() \
		and game.combat.spawn_timer <= 1.2

	# ---- ⑥ 완료 플래그가 파일에 남았는가 --------------------------------------
	var persist_config := ConfigFile.new()
	persist_config.load(GameTuning.PROGRESS_PATH)
	var persist_ok := bool(persist_config.get_value("settings", "guide_seen", false))
	# 이미 본 사람의 다음 새 런에서는 안 열린다.
	persist_ok = persist_ok and not game.guide_should_trigger(false)

	# ---- ④ ESC 확인 칩 → 두 번째 ESC = 전체 스킵 ------------------------------
	game.guide_seen = false
	game._start_guide()
	await get_tree().process_frame
	game._handle_guide_key(space_event)                          # ①을 SPACE로 건너뛴다
	var abort_ok := game.guide_active and game.guide_step == 1 \
		and not game.guide_completed_steps.has("move")           # 건너뛴 스텝은 기록 안 남는다
	game._handle_guide_key(escape_event)                         # 확인 칩
	abort_ok = abort_ok and game.guide_confirm and game.guide_active
	game._handle_guide_key(space_event)                          # SPACE = 계속하기
	abort_ok = abort_ok and not game.guide_confirm and game.guide_active and game.guide_step == 1
	game._handle_guide_key(escape_event)                         # 다시 확인 칩
	game._handle_guide_key(escape_event)                         # 전체 스킵
	abort_ok = abort_ok and not game.guide_active and game.guide_seen \
		and not is_instance_valid(game.guide_root)
	# 전체 스킵 뒤에는 저장이 다시 열려야 한다("영구히 막힌다"가 아니라 "쉰다").
	policy_ok = policy_ok and game._run_save_blocked_reason().is_empty()

	# ---- ⑥ 설정의 「온보딩 다시 표시」가 길잡이도 함께 되살리는가 --------------
	game._reset_onboarding_hide()
	var reset_config := ConfigFile.new()
	reset_config.load(GameTuning.PROGRESS_PATH)
	var reset_ok := not game.guide_seen \
		and not bool(reset_config.get_value("settings", "guide_seen", true)) \
		and game.guide_should_trigger(false)

	# ---- 런이 사라지면 층도 접힌다(본 것으로 치지 않는다) ---------------------
	game._start_guide()
	await get_tree().process_frame
	game.guide_seen = false
	game.state = "menu"
	game._tick_guide(0.016)
	var abandon_ok := not game.guide_active and not game.guide_seen \
		and not is_instance_valid(game.guide_root)
	game.state = "playing"

	# 실기 설정을 원래대로 되돌린다.
	game.guide_seen = original_guide_seen
	game._save_progress()

	print(("GUIDE_TEST_COMPLETE contract=%s trigger=%s resume=%s start=%s policy=%s "
		+ "move=%s dash=%s aim=%s skip=%s interact=%s finish=%s persist=%s abort=%s "
		+ "reset=%s abandon=%s freeze=%s diet=%s steps=%d order=%s "
		+ "cleared=%d onb_pages=%s onb_peak=%d onb_longest=%d onb_rules=%d onb_worst=%s") % [
		contract_ok, trigger_ok, resume_ok, start_ok, policy_ok,
		move_ok, dash_ok, aim_ok, skip_ok, interact_ok, finish_ok, persist_ok, abort_ok,
		reset_ok, abandon_ok, freeze_ok, diet_ok, step_ids.size(), "→".join(step_ids),
		enemies_before, census["pages"], int(census["peak"]), int(census["longest"]),
		int(census["rules_max"]), census["longest_text"]
	])
	await _quit_test_cleanly(contract_ok and trigger_ok and resume_ok and start_ok
		and policy_ok and move_ok and dash_ok and aim_ok and skip_ok and interact_ok
		and finish_ok and persist_ok and abort_ok and reset_ok and abandon_ok
		and freeze_ok and diet_ok)


## X4 — 온보딩 4페이지의 **상시 노출 글자 수**를 센다(X2 `edit_prose` 패턴의 온보딩 판).
##
## 세는 규칙은 편집 화면 계약과 같다: 페이지 오버레이 아래의 모든 `Label`을 훑되
## 두 글자 미만(기호 한 자 · 페이지 번호 등)은 세지 않는다. 툴팁이 없는 화면이라
## "지운 문장이 어디로 갔는가"가 아니라 **"애초에 안 쓴다"**가 이 화면의 계약이다.
##
## 상한 셋:
##   ① 페이지 한 장의 글자 총합 ≤ ONBOARDING_PAGE_CHARS
##   ② 한 줄(Label 하나)의 길이 ≤ ONBOARDING_LINE_CHARS — 긴 줄은 중학생이 안 읽는다
##   ③ 규칙 줄(`_onboarding_pages()`의 `rules`)은 페이지당 최대 2줄
const ONBOARDING_PAGE_CHARS := 360
const ONBOARDING_LINE_CHARS := 32
const ONBOARDING_RULES_PER_PAGE := 2

func _onboarding_census() -> Dictionary:
	var per_page: Array[int] = []
	var rules_max := 0
	var longest := 0
	var longest_text := ""
	for entry: Dictionary in game._onboarding_pages():
		rules_max = maxi(rules_max, (entry.get("rules", []) as Array).size())
	for page_index in game.ONBOARDING_PAGE_COUNT:
		game._show_onboarding(page_index)
		await get_tree().process_frame
		var chars := 0
		var probe: Array[Node] = []
		if is_instance_valid(game.overlay):
			probe.append(game.overlay)
		while not probe.is_empty():
			var node: Node = probe.pop_back()
			for child in node.get_children():
				probe.append(child)
			if not (node is Label):
				continue
			var text := (node as Label).text.strip_edges()
			if text.length() < 2:
				continue
			chars += text.length()
			if text.length() > longest:
				longest = text.length()
				longest_text = text
		per_page.append(chars)
	game._clear_overlay()
	var page_peak := 0
	for count in per_page:
		page_peak = maxi(page_peak, count)
	return {
		"ok": page_peak <= ONBOARDING_PAGE_CHARS and longest <= ONBOARDING_LINE_CHARS \
			and rules_max <= ONBOARDING_RULES_PER_PAGE,
		"pages": per_page,
		"peak": page_peak,
		"longest": longest,
		"longest_text": longest_text,
		"rules_max": rules_max
	}

## 임의의 사전을 저장 파일에 심고 `_read_run_snapshot()`이 **버리는지** 본다.
## 구 스키마 폐기 단언 두 건(v1 · v2)이 같은 몸통을 쓴다.
func _save_test_reject_snapshot(payload: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.load(GameTuning.PROGRESS_PATH)
	config.set_value("run", "active", true)
	config.set_value("run", "snapshot", payload)
	config.save(GameTuning.PROGRESS_PATH)
	return game._read_run_snapshot().is_empty()

# =============================================================================
# V0 신설: v3 신규 검사 2종의 **빈 골격** (설계 부록 B의 V0 · 부록 A-2 ㉖)
# =============================================================================
# 두 루틴은 지금 아무것도 단언하지 않고 무조건 PASS로 나간다. 목적은 하나다 —
# **run_all.sh의 목록과 종료 코드 계약을 V1·V4보다 먼저 확정해 두는 것.**
# 그래야 V1(상태 엔진)과 V4(스테이지 클럭)가 서로 병렬로 돌면서 run_all.sh와
# test_runner.gd의 ROUTINES를 동시에 건드리는 충돌이 생기지 않는다. 두 웨이브는
# **아래 함수 본문만** 채우면 되고 등록부는 손대지 않는다.
#
# 출력 규칙(run_all.sh가 보는 것):
#   ① `*_TEST_COMPLETE` 마커가 반드시 stdout에 있어야 한다.
#   ② 출력 어디에도 `=false`가 있으면 안 된다 — 그래서 골격의 플래그는 전부 true다.
#      본문을 채울 때 실패 플래그를 `=false`로 찍으면 셸이 자동으로 FAIL 처리한다.
#   ③ 끝에서 반드시 `await _quit_test_cleanly(...)`를 부른다.
#
# ⚠️ V1·V4에게: `skeleton=true`를 지우는 것이 각 웨이브의 완료 신호다. 이 문자열이
#    남아 있으면 그 테스트는 아직 아무것도 검사하지 않는 것이다.

# =============================================================================
# --stage-test (V4) — 스테이지 클럭 · 체류 압박 곡선 · 마왕 재보정
# =============================================================================
# `--deadline-test`(v2)를 대체한다(설계 §8 테스트 표 · 부록 A-2 ㉖).
#
# ── v2에서 **승계한** 검사 (7일 기한이 사라져도 여전히 유효한 것) ─────────────
#   early_challenge  마왕성 조기 도전이 1일차부터 항상 가능           (구 ④)
#   rune_formula     각인 수 = clamp(floor(성장점/N), 0, CAP)          (구 ②, 계수만 v3)
#   slot_layout      상위 5장 = 레일 · 나머지 = 잔재 · 정렬 결정성     (구 ②의 뒷부분)
#   omen_gate        전조 게이트가 임계 밑에서는 절대 안 열린다        (구 ③, dwell로 재키잉)
#   omen_spawn       실제 밤에 전조 1기가 스폰되고 1칸 덱을 돈다       (구 ③)
#   omen_reward      전조 격파 → 마왕의 각인이 실제로 하나 줄어든다    (구 ⑥)
#   monotonic        run_elapsed()가 되감기지 않는다                   (구 ⑤)
#
# ── v2에서 **버린** 검사 (v3가 그 기능 자체를 삭제했다) ──────────────────────
#   clock_days       "7일에서 멈춘다" → v3는 무한이다. `infinite`가 정반대를 단언한다.
#   milestones       일수 이정표 6종 → dwell 이정표로 재키잉(§2.4). 조회만 남았다.
#   descent          "7일차 밤 끝 = 강림" 스케줄 → dwell 안전 밸브(§6.6)로 교체.
#   descent_game     같은 이유. 실제 강림 배선은 V5 몫이라 여기서 게임 경로를 안 탄다.
#
# ── v3 신설 ──────────────────────────────────────────────────────────────────
#   infinite / dwell_monotone / curve / reward_decay / volume / blight /
#   descent_valve / carryover / total_days / phase_len / demon_recal / game_clock
func _run_stage_test() -> void:
	game.automated_test = true
	game._start_game()
	await get_tree().create_timer(0.2).timeout

	# ---- game_clock: 게임이 실제로 스테이지 클럭을 물고 있는가 -----------------
	var game_clock_ok: bool = game.clock is StageClock \
		and game.clock.stage == 1 and game.clock.dwell == 0 \
		and game.clock.stages_cleared == 0 and game.clock.day_number == 1
	# 실제 게임 경로로 한 주기를 돌리면 dwell과 총 일수가 함께 오른다.
	var dwell_before: int = game.clock.dwell
	var day_before: int = game.clock.day_number
	game._toggle_day_night()          # 낮 -> 밤
	await get_tree().create_timer(0.05).timeout
	game_clock_ok = game_clock_ok and game.is_night and game.clock.dwell == dwell_before
	game._toggle_day_night()          # 밤 -> 낮 (= 주기 완료)
	await get_tree().create_timer(0.05).timeout
	game_clock_ok = game_clock_ok and not game.is_night \
		and game.clock.dwell == dwell_before + 1 \
		and game.clock.day_number == day_before + 1

	# ---- early_challenge(승계): 조기 도전은 언제나 열린다 ----------------------
	game.clock.set_day_raw(1)
	game.clock.set_night_raw(false)
	game.clock.set_dwell_raw(0)
	game._challenge_demon_king()
	var early_challenge_ok := game.state == "boss_preview"
	game._cancel_boss_preview()
	early_challenge_ok = early_challenge_ok and game.state == "playing"

	# ---- rune_formula(승계): 각인 수 = clamp(floor(성장점 / 4), 0, 16) ---------
	# v3 재보정으로 계수가 2 -> 4, 상한이 12 -> 16이 됐다(§6.4). 식의 모양은 같다.
	var card_pool: Array[String] = []
	for definition: Dictionary in DealCardLibrary.all():
		card_pool.append(String(definition["id"]))
	var saved_debts := game.rejected_skills.duplicate()
	var rune_formula_ok := card_pool.size() >= 4
	for probe: Array in [[0, 0], [1, 0], [3, 0], [4, 0], [7, 0], [24, 0], [63, 0], [70, 0], [8, 3], [0, 9]]:
		var card_count: int = probe[0]
		var shard_count: int = probe[1]
		var ids: Array[String] = []
		for index in card_count:
			ids.append(card_pool[index % card_pool.size()])
		game.demon_lord.reset()
		game.rejected_skills.assign(ids)
		game.demon_lord.rune_shards = shard_count
		var expected: int = clampi((card_count + shard_count) / GameTuning.BOSS_CARDS_PER_RUNE, 0, GameTuning.BOSS_RUNE_CAP)
		rune_formula_ok = rune_formula_ok and game.demon_lord.rune_count() == expected
		game.demon_lord.sync_runes(game.rng)
		rune_formula_ok = rune_formula_ok and game.demon_lord.granted_runes.size() == expected
		var slot_total := 0
		for slot_index in GameTuning.BOSS_SLOT_COUNT:
			slot_total += game.demon_lord.rune_count_on_slot(slot_index)
		rune_formula_ok = rune_formula_ok and slot_total == expected
	# 재보정이 실제로 걸렸는가: 같은 카드 수에서 v2보다 각인이 정확히 절반이어야 한다.
	rune_formula_ok = rune_formula_ok and GameTuning.BOSS_CARDS_PER_RUNE == 4 and GameTuning.BOSS_RUNE_CAP == 16

	# ---- slot_layout(승계): 상위 5장 = 레일 · 나머지 = 잔재 · 정렬 결정성 ------
	var many_ids: Array[String] = []
	for index in 18:
		many_ids.append(card_pool[index % card_pool.size()])
	game.demon_lord.reset()
	game.rejected_skills.assign(many_ids)
	var layout := game.demon_lord.slot_layout()
	var slot_layout_ok := layout.size() == GameTuning.BOSS_SLOT_COUNT \
		and game.demon_lord.filled_slot_count() == GameTuning.BOSS_SLOT_COUNT \
		and not game.demon_lord.residue_cards().is_empty()
	var first_pass := game.demon_lord.ranked_cards()
	var second_pass := game.demon_lord.ranked_cards()
	for index in first_pass.size():
		slot_layout_ok = slot_layout_ok and String(first_pass[index].get("id", "")) == String(second_pass[index].get("id", ""))
	for index in range(1, first_pass.size()):
		slot_layout_ok = slot_layout_ok and DealCardLibrary.expected_power(first_pass[index - 1]) >= DealCardLibrary.expected_power(first_pass[index])
	game.demon_lord.reset()
	game.rejected_skills.assign(saved_debts)

	# ---- omen_gate(승계 · 재키잉): 전조는 dwell ≥ 2에서만 -----------------------
	var gate_clock := StageClock.new()
	gate_clock.reset()
	var omen_gate_ok := true
	for probe_dwell in range(0, 13):
		omen_gate_ok = omen_gate_ok and gate_clock.omen_should_spawn(probe_dwell) == (probe_dwell >= GameTuning.OMEN_START_DWELL)
	# 균열도 같은 축으로 옮겨갔다: dwell 1·3에 하나씩, 스테이지 예산 2를 넘지 않는다.
	for probe_dwell in range(0, 13):
		var expected_rifts: int = mini(
			(1 if probe_dwell >= GameTuning.RIFT_DWELL_SCHEDULE[0] else 0) + (1 if probe_dwell >= GameTuning.RIFT_DWELL_SCHEDULE[1] else 0),
			GameTuning.RIFT_STAGE_BUDGET
		)
		omen_gate_ok = omen_gate_ok and gate_clock.rifts_due(probe_dwell) == expected_rifts
	omen_gate_ok = omen_gate_ok and GameTuning.RIFT_RUN_BUDGET == GameTuning.STAGE_COUNT * GameTuning.RIFT_STAGE_BUDGET
	# V5: game.gd의 게이트도 dwell로 옮겨갔다(구 일수 게이트는 삭제). 위임이 맞는지 본다.
	for probe_dwell in range(0, 13):
		omen_gate_ok = omen_gate_ok and game.omen_should_spawn(probe_dwell) == (probe_dwell >= GameTuning.OMEN_START_DWELL)
	omen_gate_ok = omen_gate_ok and not game.omen_should_spawn(0)
	# 인자 없이 부르면 **현재 dwell**을 본다(전조 스폰 경로가 이 형태를 쓴다).
	game.clock.set_dwell_raw(0)
	omen_gate_ok = omen_gate_ok and not game.omen_should_spawn()
	game.clock.set_dwell_raw(GameTuning.OMEN_START_DWELL)
	omen_gate_ok = omen_gate_ok and game.omen_should_spawn()

	# ---- omen_spawn(승계 · 재키잉): 체류 1의 밤에는 없고 체류 2의 밤에는 1기 ----
	game.clock.set_dwell_raw(GameTuning.OMEN_START_DWELL - 1)
	game.clock.set_night_raw(false)
	game._toggle_day_night()
	await get_tree().create_timer(0.1).timeout
	var omen_spawn_ok := game.is_night and game.active_omen == null and game.omen_night_count == 0

	# 마왕이 각인을 들고 있어야 시연할 칸이 생긴다. 재보정 후에는 **4장당 1개**이므로
	# v2의 2장으로는 각인이 0개다 — 8장을 넘겨 2개를 만든다.
	var demo_ids: Array[String] = []
	for index in 8:
		demo_ids.append(card_pool[index % card_pool.size()])
	game.rejected_skills.assign(demo_ids)
	game.demon_lord.reset()
	game.demon_lord.sync_runes(game.rng)
	game.clock.set_dwell_raw(GameTuning.OMEN_START_DWELL)
	game.clock.set_night_raw(false)
	game._toggle_day_night()
	await get_tree().create_timer(0.1).timeout
	omen_spawn_ok = omen_spawn_ok and is_instance_valid(game.active_omen) \
		and game.omen_night_count == 1 \
		and bool(game.active_omen.external_cycle_enabled) \
		and bool(game.active_omen.is_camp_elite) \
		and String(game.active_omen.camp_id).begins_with(game.OMEN_CAMP_PREFIX) \
		and is_instance_valid(game.omen_cycle) \
		and game.omen_deck != null and game.omen_deck.slots.size() == 1 \
		and game.can_cycle_run(true)

	# ---- omen_reward(승계): 전조 격파 → 마왕의 각인이 하나 줄어든다 -------------
	var runes_before := game.demon_lord.rune_count()
	var omen_reward_ok := runes_before > 0
	if is_instance_valid(game.active_omen):
		while game.active_omen.active_modules.has("rollback"):
			game.active_omen.active_modules.erase("rollback")
		game.active_omen.take_damage(999999.0, game.player.global_position)
	await get_tree().create_timer(0.3).timeout
	omen_reward_ok = omen_reward_ok and game.state == "playing" \
		and game.active_omen == null and game.omen_cycle == null \
		and game.demon_lord.stripped_runes.size() == 1 \
		and game.demon_lord.rune_count() == runes_before - 1

	# =========================================================================
	# 여기부터는 게임 부작용 없는 순수 클럭 검사다.
	# =========================================================================

	# ---- infinite / dwell_monotone / monotonic: 100주기 무한 진행, 클램프 0 ----
	var probe := StageClock.new()
	probe.reset()
	var seen_days: Array[int] = []
	var seen_nights: Array[int] = []
	var seen_dwells: Array[int] = []
	probe.day_started.connect(func(day: int) -> void: seen_days.append(day))
	probe.night_started.connect(func(day: int) -> void: seen_nights.append(day))
	probe.dwell_advanced.connect(func(_stage: int, value: int) -> void: seen_dwells.append(value))
	# v3에서 절대 발화하면 안 되는 두 시그널(배선은 V5가 새로 붙인다).
	var stale_signals: Array[int] = []
	probe.milestone_reached.connect(func(_id: String, _day: int) -> void: stale_signals.append(1))
	probe.descent_triggered.connect(func() -> void: stale_signals.append(2))

	const TARGET_CYCLES := 100
	var monotonic_ok := true
	var dwell_monotone_ok := true
	var last_elapsed := -1.0
	var last_dwell := 0
	var guard := 0
	while probe.dwell < TARGET_CYCLES and guard < 400000:
		guard += 1
		probe.tick(1.0)
		var now := probe.run_elapsed()
		if now < last_elapsed - 0.0001:
			monotonic_ok = false
		last_elapsed = now
		if probe.dwell < last_dwell:
			dwell_monotone_ok = false
		last_dwell = probe.dwell
	var cycle_seconds := GameTuning.STAGE_DAY_DURATION[0] + GameTuning.STAGE_NIGHT_DURATION[0]
	var infinite_ok := probe.dwell == TARGET_CYCLES \
		and probe.day_number == TARGET_CYCLES + 1 \
		and probe.day_number > 7 \
		and not probe.is_night \
		and guard < 400000 \
		and stale_signals.is_empty() \
		and absf(probe.run_elapsed() - cycle_seconds * float(TARGET_CYCLES)) < 1.0
	# 시그널이 정확히 주기 수만큼, 순서대로 나왔는가.
	infinite_ok = infinite_ok and seen_days.size() == TARGET_CYCLES \
		and seen_nights.size() == TARGET_CYCLES and seen_dwells.size() == TARGET_CYCLES
	for index in seen_dwells.size():
		dwell_monotone_ok = dwell_monotone_ok and seen_dwells[index] == index + 1
		dwell_monotone_ok = dwell_monotone_ok and seen_days[index] == index + 2
		dwell_monotone_ok = dwell_monotone_ok and seen_nights[index] == index + 1
	# 강림 밸브를 밟은 뒤에도 클럭은 멈추지 않는다(v2는 여기서 정지했다).
	# tick()은 한 번에 최대 한 페이즈만 넘기므로 주기가 끝날 때까지 계속 돌린다.
	probe.mark_descended()
	var frozen_probe := probe.dwell
	var after_descent_guard := 0
	while probe.dwell == frozen_probe and after_descent_guard < 4000:
		after_descent_guard += 1
		probe.tick(1.0)
	infinite_ok = infinite_ok and probe.descended \
		and probe.dwell == frozen_probe + 1 and after_descent_guard < 4000

	# ---- curve: §6.2 표를 소수 둘째 자리까지 대조 ------------------------------
	# [d, HP, 피해, 속도, 물량+, 정예, XP×, 골드×]  ← 설계 §6.2 표 원문
	# ⚠️ Y1(2026-08-09)이 HP 3축·물량 3축을 전부 내렸고, **Y8(2026-08-10)이 dwell HP만
	#    다시 올렸다**(balance_probe ⑤ 실측 — 아래 reward_decay 주석에 근거).
	#    H(d) = 1 + 0.13d + 0.010d²  (Y1 0.10 / 0.007 · v3 원안 0.14 / 0.012)
	#    물량 = 4 × min(d, 8)         (구 3 × min(d, 6) · Y1 무변경)
	#    정예 = min(0.45, 0.04d)      (구 min(0.35, 0.03d) · Y1 무변경)
	#    피해 A(d)는 Y1·Y8 둘 다 **건드리지 않았다** — §5.5가 HP 축만 내리라고 했다.
	#    이 표는 위 상수에서 계산한 값이고, `balance_probe` ④가 같은 행을 실측으로 다시 찍는다.
	var curve_rows: Array = [
		[0, 1.00, 1.00, 1.00, 0, 0.00, 1.00],
		[1, 1.14, 1.07, 1.01, 4, 0.04, 1.07],
		[2, 1.30, 1.16, 1.02, 8, 0.08, 1.14],
		[3, 1.48, 1.25, 1.04, 12, 0.12, 1.22],
		[4, 1.68, 1.34, 1.05, 16, 0.16, 1.30],
		[6, 2.14, 1.56, 1.07, 24, 0.24, 1.46],
		[8, 2.68, 1.82, 1.10, 32, 0.32, 1.64],
		[10, 3.30, 2.10, 1.12, 32, 0.40, 1.82],
		[12, 4.00, 2.42, 1.14, 32, 0.45, 2.00]
	]
	var curve_ok := true
	for row: Array in curve_rows:
		var d := int(row[0])
		curve_ok = curve_ok and absf(StageClock.dwell_hp(d) - float(row[1])) < 0.006
		curve_ok = curve_ok and absf(StageClock.dwell_damage(d) - float(row[2])) < 0.006
		curve_ok = curve_ok and absf(StageClock.dwell_speed(d) - float(row[3])) < 0.006
		curve_ok = curve_ok and StageClock.dwell_count_bonus(d) == int(row[4])
		curve_ok = curve_ok and absf(StageClock.dwell_elite_ratio(d) - float(row[5])) < 0.006
		curve_ok = curve_ok and absf(StageClock.dwell_xp(d) - float(row[6])) < 0.006
	# 상한 3개가 실제로 물려 있는가 (속도 1.30 · 정예 0.45 · 물량 포화 d=8).
	curve_ok = curve_ok and is_equal_approx(StageClock.dwell_speed(9999), GameTuning.DWELL_SPEED_CAP)
	curve_ok = curve_ok and is_equal_approx(StageClock.dwell_elite_ratio(9999), GameTuning.DWELL_ELITE_CAP)
	# ⚠️ Y2 결정: 구 불변식 `DWELL_DAMAGE_LINEAR × 2 == DWELL_HP_LINEAR`("피해는 HP의
	#    정확히 절반 기울기")는 **폐기했다.** §5.5가 내린 것은 HP 세 축뿐이고 피해 축은
	#    언급조차 없다. 0.07을 0.05로 따라 내리면 "난이도는 HP가 아니라 패턴·물량"이라는
	#    설계 방향과 정반대로 간다(handoff-y1 §8 갈래 (가) = 이번 라운드 권고안).
	#    새 계약은 **부등식**이다 — 피해 기울기는 HP 기울기보다 작지만 절반보다는 크다.
	#    즉 dwell이 깊어질수록 몹이 상대적으로 더 아파진다(체류 압박이 HP 벽이 아닌 형태로 남는다).
	curve_ok = curve_ok and GameTuning.DWELL_DAMAGE_LINEAR < GameTuning.DWELL_HP_LINEAR
	curve_ok = curve_ok and GameTuning.DWELL_DAMAGE_LINEAR * 2.0 > GameTuning.DWELL_HP_LINEAR

	# ---- reward_decay: 킬당 효율 = H^0.5 / H. **이 한 줄이 체류 압박의 실체다** --
	# 효율 = H^0.5 / H = **H^-0.5**. Y1의 HP 하향이 그대로 실려 기울기가 완만해졌고
	# (1/효율(12)이 2.10 → 1.79로 내려갔다), **Y8이 그것을 되돌렸다** — 아래 참조.
	var efficiency_rows: Array = [
		[0, 1.00], [1, 0.94], [2, 0.88], [3, 0.82], [4, 0.77],
		[6, 0.68], [8, 0.61], [10, 0.55], [12, 0.50]
	]
	var reward_decay_ok := true
	var last_efficiency := 99.0
	for row: Array in efficiency_rows:
		var d := int(row[0])
		var efficiency := StageClock.dwell_kill_efficiency(d)
		reward_decay_ok = reward_decay_ok and absf(efficiency - float(row[1])) < 0.006
		# 단조 감소여야 한다 — 한 지점이라도 올라가면 "오래 머물수록 손해"가 거짓말이 된다.
		reward_decay_ok = reward_decay_ok and efficiency < last_efficiency
		last_efficiency = efficiency
	# 보상 지수가 1.0이면 감쇠가 없다는 뜻이다. 0 < 지수 < 1을 못 박는다.
	reward_decay_ok = reward_decay_ok and GameTuning.DWELL_XP_EXPONENT > 0.0 and GameTuning.DWELL_XP_EXPONENT < 1.0
	reward_decay_ok = reward_decay_ok and GameTuning.DWELL_GOLD_EXPONENT < GameTuning.DWELL_XP_EXPONENT
	# d=12에서 레벨업에 몇 배가 드는가. §6.2의 약속은 "시간을 **두 배** 써야 한다"다.
	#   v3 원안(0.14/0.012) 2.10  ·  Y1(0.10/0.007) 1.79  ·  **Y8(0.13/0.010) 2.00**
	# Y8이 `balance_probe` ⑤로 절대 시간까지 재고(레벨 15 도달 270초 → 540초) 0.13/0.010을
	# 확정했다. 「정확히 절반」이 다시 참이 됐으므로 목표치를 상수로 못 박는다.
	reward_decay_ok = reward_decay_ok and absf(1.0 / StageClock.dwell_kill_efficiency(12) - 2.00) < 0.05

	# ---- volume: d=6 포화 · MAX_ENEMIES 절대 불가침 ----------------------------
	var volume_ok := true
	for d in range(0, 201):
		var night_limit := StageClock.night_enemy_limit_at(d)
		var day_limit := StageClock.day_enemy_limit_at(d)
		volume_ok = volume_ok and night_limit <= GameTuning.MAX_ENEMIES and day_limit <= GameTuning.MAX_ENEMIES
		volume_ok = volume_ok and StageClock.night_raid_burst_at(d) <= GameTuning.NIGHT_RAID_BURST_CAP
		volume_ok = volume_ok and StageClock.spawn_interval_at(d, true) >= GameTuning.NIGHT_SPAWN_INTERVAL_FLOOR
		if d >= GameTuning.DWELL_COUNT_SATURATION:
			volume_ok = volume_ok and night_limit == StageClock.night_enemy_limit_at(GameTuning.DWELL_COUNT_SATURATION)
			volume_ok = volume_ok and day_limit == StageClock.day_enemy_limit_at(GameTuning.DWELL_COUNT_SATURATION)
	# 포화 전에는 실제로 늘어야 한다(포화가 "처음부터 상수"를 숨기지 않게).
	volume_ok = volume_ok and StageClock.night_enemy_limit_at(6) > StageClock.night_enemy_limit_at(0)

	# ---- blight: 잠식 임계 [4,4,3,3,2] · 스테이지 클리어 시 자동 해제 ----------
	var blight_ok := true
	for stage_no in range(1, GameTuning.STAGE_COUNT + 1):
		var stage_probe := StageClock.new()
		stage_probe.reset()
		stage_probe.set_stage_raw(stage_no)
		var threshold: int = GameTuning.STAGE_BLIGHT_DWELL[stage_no - 1]
		blight_ok = blight_ok and stage_probe.blight_threshold() == threshold
		stage_probe.set_dwell_raw(threshold - 1)
		blight_ok = blight_ok and not stage_probe.blight_active()
		stage_probe.set_dwell_raw(threshold)
		blight_ok = blight_ok and stage_probe.blight_active()
	# 스테이지를 넘기면 dwell ×0.5 감쇠가 잠식을 자동으로 끈다(§2.4 "클리어 시 해제").
	var blight_probe := StageClock.new()
	blight_probe.reset()
	blight_probe.set_dwell_raw(GameTuning.STAGE_BLIGHT_DWELL[0])
	blight_ok = blight_ok and blight_probe.blight_active()
	blight_probe.advance_stage()
	blight_ok = blight_ok and not blight_probe.blight_active() \
		and GameTuning.BLIGHT_CLEARS_ON_STAGE_CLEAR

	# ---- descent_valve: dwell 도달 시 "트리거 상태"가 참이 된다 -----------------
	# **시그널을 쏘지 않는다.** 실제 강림 배선은 V5 몫이라 여기서는 상태만 본다(§6.6).
	var valve_ok := true
	for stage_no in range(1, GameTuning.STAGE_COUNT + 1):
		var valve_probe := StageClock.new()
		valve_probe.reset()
		valve_probe.set_stage_raw(stage_no)
		var threshold: int = GameTuning.DWELL_DESCENT[stage_no - 1]
		valve_ok = valve_ok and valve_probe.descent_threshold() == threshold
		valve_probe.set_dwell_raw(threshold - 1)
		valve_ok = valve_ok and not valve_probe.descent_valve_ready() \
			and valve_probe.dwell_remaining() == 1 \
			and valve_probe.dwell_ratio() < 1.0
		valve_probe.set_dwell_raw(threshold)
		valve_ok = valve_ok and valve_probe.descent_valve_ready() \
			and valve_probe.dwell_remaining() == 0 \
			and is_equal_approx(valve_probe.dwell_ratio(), 1.0)
		# 밸브를 소모하면 같은 스테이지에서 두 번 열리지 않는다.
		valve_probe.mark_descended()
		valve_ok = valve_ok and valve_probe.descended and not valve_probe.descent_valve_ready()
		# 다음 스테이지에서 재무장한다(등급 C 고정은 남는다).
		valve_probe.advance_stage()
		valve_ok = valve_ok and valve_probe.descended and not valve_probe.descent_used_this_stage
	# 밸브를 밟으면 총 일수와 무관하게 등급 C(§6.6 · V3-C).
	valve_ok = valve_ok and GameTuning.DESCENT_SAFETY_VALVE_ENABLED \
		and game.demon_lord.victory_grade(1, true) == "C"

	# ---- carryover: 스테이지 전환 시 dwell = floor(dwell × 0.5) -----------------
	var carryover_ok := true
	for before: int in [0, 1, 2, 3, 5, 6, 7, 11]:
		var carry_probe := StageClock.new()
		carry_probe.reset()
		carry_probe.set_dwell_raw(before)
		carry_probe.set_day_raw(9)
		carry_probe.set_night_raw(true)
		carry_probe.advance_stage()
		var expected: int = int(floor(float(before) * GameTuning.DWELL_STAGE_CARRYOVER))
		carryover_ok = carryover_ok and carry_probe.dwell == expected \
			and carry_probe.stage == 2 and carry_probe.stages_cleared == 1 \
			and carry_probe.day_number == 9 \
			and not carry_probe.is_night and is_zero_approx(carry_probe.phase_elapsed)
	# 완전 리셋도 이월 없음도 아니다 — 과파밍의 대가가 다음 스테이지까지 따라온다.
	carryover_ok = carryover_ok and GameTuning.DWELL_STAGE_CARRYOVER > 0.0 and GameTuning.DWELL_STAGE_CARRYOVER < 1.0

	# ---- total_days: 총 일수가 스테이지를 넘어 누적된다 -------------------------
	var journey := StageClock.new()
	journey.reset()
	var cycles_per_stage := 3
	for _stage_no in GameTuning.STAGE_COUNT:
		for _cycle in cycles_per_stage:
			journey.advance_phase()   # 낮 -> 밤
			journey.advance_phase()   # 밤 -> 낮 (주기 완료)
		journey.advance_stage()
	var expected_days: int = 1 + GameTuning.STAGE_COUNT * cycles_per_stage
	var total_days_ok := journey.day_number == expected_days \
		and journey.stages_cleared == GameTuning.STAGE_COUNT \
		and journey.stage == GameTuning.STAGE_COUNT \
		and journey.is_run_complete()
	# 등급은 총 일수만 본다(§2.5). 경계 4개를 정확히 짚는다.
	total_days_ok = total_days_ok \
		and game.demon_lord.victory_grade(GameTuning.GRADE_S_MAX_DAYS, false) == "S" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_S_MAX_DAYS + 1, false) == "A" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_A_MAX_DAYS + 1, false) == "B" \
		and game.demon_lord.victory_grade(GameTuning.GRADE_B_MAX_DAYS + 1, false) == "C"

	# ---- phase_len: 스테이지별 낮/밤 길이가 실제 페이즈 길이가 된다 -------------
	var phase_len_ok := true
	for stage_no in range(1, GameTuning.STAGE_COUNT + 1):
		var length_probe := StageClock.new()
		length_probe.reset()
		length_probe.set_stage_raw(stage_no)
		length_probe.set_night_raw(false)
		phase_len_ok = phase_len_ok and is_equal_approx(length_probe.phase_duration(), GameTuning.STAGE_DAY_DURATION[stage_no - 1])
		length_probe.set_night_raw(true)
		phase_len_ok = phase_len_ok and is_equal_approx(length_probe.phase_duration(), GameTuning.STAGE_NIGHT_DURATION[stage_no - 1])
		phase_len_ok = phase_len_ok and is_equal_approx(
			length_probe.day_length(),
			GameTuning.STAGE_DAY_DURATION[stage_no - 1] + GameTuning.STAGE_NIGHT_DURATION[stage_no - 1]
		)
	# 1스테이지는 v2와 완전히 같은 시간 구조로 시작한다(72 / 45).
	phase_len_ok = phase_len_ok and is_equal_approx(GameTuning.STAGE_DAY_DURATION[0], GameTuning.DAY_DURATION) \
		and is_equal_approx(GameTuning.STAGE_NIGHT_DURATION[0], GameTuning.NIGHT_DURATION)
	# 5스테이지는 한 주기의 60% 이상이 밤이다(§7.3 "그래픽 가중치의 절반").
	var final_night_share: float = GameTuning.STAGE_NIGHT_DURATION[4] \
		/ (GameTuning.STAGE_DAY_DURATION[4] + GameTuning.STAGE_NIGHT_DURATION[4])
	phase_len_ok = phase_len_ok and final_night_share > 0.60

	# ---- demon_recal: §6.4 마왕 재보정이 실제로 걸렸는가 ------------------------
	game.demon_lord.reset()
	var recal_ok := true
	# HP 배율: (1 + 0.05 × 총일수) × (1 + 0.15 × 격파 스테이지). 20일·5스테이지 = ×3.5.
	recal_ok = recal_ok and absf(game.demon_lord.hp_multiplier(20, 5) - 3.5) < 0.001
	recal_ok = recal_ok and absf(game.demon_lord.hp_multiplier(0, 0) - 1.0) < 0.001
	# v2 식(1 + 0.22 × (20 − 1) = ×5.18)보다 확실히 눌려 있어야 한다.
	# V10: `GameTuning.BOSS_HP_DAY_STEP`이 삭제돼 v2 계수 0.22를 여기 리터럴로 둔다.
	# 이 줄은 **v3 값을 계산하지 않는다** — 폐기된 v2 식과의 비교선일 뿐이다.
	recal_ok = recal_ok and game.demon_lord.hp_multiplier(20, 5) < 1.0 + 0.22 * 19.0
	# 강림 보정은 곱으로 남는다.
	game.demon_lord.mark_descended()
	recal_ok = recal_ok and absf(game.demon_lord.hp_multiplier(20, 5) - 3.5 * GameTuning.DESCENT_HP_MUL) < 0.001 \
		and game.demon_lord.descent_rune_bonus == GameTuning.DESCENT_RUNE_BONUS
	game.demon_lord.reset()
	# 부채 상한: 45장을 넘겨도 기저 체력이 더 오르지 않는다.
	var capped_hp := DemonLord.boss_base_health(GameTuning.BOSS_DEBT_CAP, 0, 0.0)
	recal_ok = recal_ok and is_equal_approx(DemonLord.boss_base_health(200, 0, 0.0), capped_hp) \
		and is_equal_approx(capped_hp, GameTuning.BOSS_BASE_HP + float(GameTuning.BOSS_DEBT_CAP) * GameTuning.BOSS_HP_PER_DEBT) \
		and DemonLord.boss_base_health(10, 0, 0.0) < capped_hp
	# 60장 시나리오: v2 계수(70)면 부채 항만 4,200으로 기저 611을 압도했다. v3는 990이다.
	recal_ok = recal_ok and float(GameTuning.BOSS_DEBT_CAP) * GameTuning.BOSS_HP_PER_DEBT < GameTuning.BOSS_BASE_HP * 2.0
	game.rejected_skills.assign(saved_debts)

	# =========================================================================
	# V5 신설: 스테이지 전환 파이프라인 E2E · 잠식 배선 · 강림 밸브 배선
	# =========================================================================
	# 여기부터는 **실기 경로**다. `game.advance_stage()` 한 번으로 dwell 감쇠 ·
	# 월드 재생성 · 아틀라스 교체 · 몹 배율 변경 · 균열 예산 리필이 전부 일어나야 한다.
	game.clock.reset()
	game._begin_stage(1)
	await get_tree().create_timer(0.2).timeout
	game.player.invulnerability = 999.0

	# ---- stage_pipe: 1 -> 2 전환 --------------------------------------------
	game.clock.set_dwell_raw(5)
	game.clock.set_day_raw(9)
	var before_stage: int = game.clock.stage
	var before_atlas: String = game.world.stage_atlas_key
	var before_gate: Vector2 = game.world.get_boss_gate_position()
	var before_hp_mul: float = game.clock.enemy_hp_multiplier()
	var before_days: int = game.clock.day_number
	var stage_pipe_ok: bool = before_stage == 1 and game.world.get_stage() == 1 \
		and before_atlas == String(GameTuning.STAGE_TERRAIN_ATLAS[0])
	stage_pipe_ok = stage_pipe_ok and game.advance_stage()
	await get_tree().create_timer(0.25).timeout
	# ① dwell 절반 감쇠 · 총 일수 이월 · 격파 카운트
	stage_pipe_ok = stage_pipe_ok and game.clock.stage == 2 \
		and game.clock.dwell == int(floor(5.0 * GameTuning.DWELL_STAGE_CARRYOVER)) \
		and game.clock.stages_cleared == 1 \
		and game.clock.day_number == before_days
	# ② 월드가 통째로 다시 만들어졌고 랜드마크 3종이 새 자리에 있다
	stage_pipe_ok = stage_pipe_ok and game.world.get_stage() == 2 \
		and game.world.get_stage_landmarks().size() == 3 \
		and not game.world.get_boss_gate_position().is_equal_approx(before_gate) \
		and game.world.is_walkable(game.world.get_camp_position())
	# ③ 아틀라스·낮밤 길이가 스테이지 배열을 탄다
	stage_pipe_ok = stage_pipe_ok and game.world.stage_atlas_key == String(GameTuning.STAGE_TERRAIN_ATLAS[1]) \
		and is_equal_approx(game.clock.day_duration(), GameTuning.STAGE_DAY_DURATION[1]) \
		and is_equal_approx(game.clock.night_duration(), GameTuning.STAGE_NIGHT_DURATION[1])
	# ④ 몹 배율이 stage_base × H(dwell)로 갈렸다 (기저가 1.00 -> 1.55)
	var after_hp_mul: float = game.clock.enemy_hp_multiplier()
	stage_pipe_ok = stage_pipe_ok and not is_equal_approx(after_hp_mul, before_hp_mul) \
		and absf(after_hp_mul - GameTuning.STAGE_HP_BASE[1] * StageClock.dwell_hp(game.clock.dwell)) < 0.0001
	# ⑤ 스테이지 스코프 상태 초기화 — 균열 예산 · 캠프 휴식 · 강림 밸브 · 플레이어 스폰
	# 균열 예산은 **다시 채워진다**. 이월 dwell(2)이 밀린 균열 1개를 즉시 열므로
	# "남은 예산 + 열린 개수 = 스테이지 예산"이 그 불변식이다.
	stage_pipe_ok = stage_pipe_ok and game.world.rift_budget_remaining() + game.world.get_rifts().size() == GameTuning.RIFT_STAGE_BUDGET \
		and game.world.get_rifts().size() == game.clock.rifts_due() \
		and not game.camp_rest_used and not game.stage_descent_pending \
		and game.player.global_position.is_equal_approx(Vector2.ZERO) \
		and game.combat.active_enemies.size() > 0
	# ⑥ 실제 필드 마물이 스테이지 배율을 받았다.
	# V6(2026-08-09): V5의 임시 우회로(`_sweep_stage_scaling` · `STAGE_SCALE_META`)가
	# `combat_resolver.apply_stage_scaling()`으로 이관되면서 메타 표식이 사라졌다.
	# 표식을 세는 대신 **라이브러리 기저값 × 배율**과 실측 체력을 직접 대조한다 —
	# 이중 적용(배율이 제곱)까지 같은 한 줄이 잡는다.
	var scale_power: float = float(game.cycle_number - 1) * 1.1 + float(game.level - 1) * 0.32 \
		+ minf(game.elapsed_time / 180.0, 2.5)
	var scale_probe := game.combat.spawn_enemy_instance(
		game.player.global_position + Vector2(130.0, 0.0), 1, "", false, "", false, "mossling", true)
	var expected_scaled_hp: float = MonsterLibrary.health_for(MonsterLibrary.by_id("mossling"), scale_power) \
		* game.clock.enemy_hp_multiplier()
	stage_pipe_ok = stage_pipe_ok and is_instance_valid(scale_probe) \
		and absf(float(scale_probe.max_health) - expected_scaled_hp) < 0.01 \
		and game.stage_scaled_enemies > 0
	if is_instance_valid(scale_probe):
		scale_probe.queue_free()

	# ---- stage_blight: 잠식이 dwell 임계에서 켜지고 스테이지 클리어로 꺼진다 ----
	var blight_wire_ok: bool = not game.blight_active
	game.clock.set_dwell_raw(game.clock.blight_threshold() - 1)
	game._check_stage_blight()
	blight_wire_ok = blight_wire_ok and not game.blight_active
	game.clock.set_dwell_raw(game.clock.blight_threshold())
	game._check_stage_blight()
	blight_wire_ok = blight_wire_ok and game.blight_active and game.blight_marked > 0
	# 필드 마물이 실제로 마왕의 표식을 받았는가(v2 월식 스윕 재사용).
	var blight_marked := 0
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy) and enemy.has_meta(game.BLIGHT_META):
			blight_marked += 1
	blight_wire_ok = blight_wire_ok and blight_marked > 0
	# 스테이지를 넘기면 dwell ×0.5 감쇠가 잠식을 끈다(설계 §2.4 "클리어 시 해제").
	game.advance_stage()
	await get_tree().create_timer(0.25).timeout
	blight_wire_ok = blight_wire_ok and game.clock.stage == 3 and not game.blight_active

	# ---- 5관문 완주: 마지막 격파는 필드를 다시 세우지 않고 마왕전으로 넘긴다 ----
	# (부록 A-1 ③ "5스테이지 보스 격파 → 필드 복귀 없이 즉시 마왕전")
	while not game.clock.is_run_complete():
		game.advance_stage()
		await get_tree().create_timer(0.1).timeout
	stage_pipe_ok = stage_pipe_ok and game.clock.stages_cleared == GameTuning.STAGE_COUNT \
		and game.clock.stage == GameTuning.STAGE_COUNT and game.world.get_stage() == GameTuning.STAGE_COUNT \
		and not game.advance_stage()
	# 마왕전 직행이 실제로 열린다(프리뷰 상태까지만 본다 — 전투는 V7 소유).
	game._challenge_demon_king()
	stage_pipe_ok = stage_pipe_ok and game.state == "boss_preview"
	game._cancel_boss_preview()
	stage_pipe_ok = stage_pipe_ok and game.state == "playing"

	# ---- descent_wire: 밸브가 실기에서 상태·등급까지 간다 ---------------------
	var descent_wire_ok: bool = not game.stage_descent_pending and not game.clock.descended
	game.clock.set_dwell_raw(game.clock.descent_threshold())
	game._process(0.001)
	descent_wire_ok = descent_wire_ok and game.stage_descent_pending and game.clock.descended \
		and game.stage_descent_active() \
		and game.demon_lord.victory_grade(1, game.clock.descended) == "C"
	# 밸브는 스테이지당 한 번만 열린다.
	game.clock.set_dwell_raw(game.clock.descent_threshold() + 3)
	descent_wire_ok = descent_wire_ok and not game.clock.descent_valve_ready()

	print("STAGE_TEST_COMPLETE game_clock=%s early_challenge=%s rune_formula=%s slot_layout=%s omen_gate=%s omen_spawn=%s omen_reward=%s infinite=%s dwell_monotone=%s monotonic=%s curve=%s reward_decay=%s volume=%s blight=%s descent_valve=%s carryover=%s total_days=%s phase_len=%s demon_recal=%s stage_pipe=%s blight_wire=%s descent_wire=%s cycles=%d day=%d eff4=%.3f eff8=%.3f eff12=%.3f night_cap=%d hp_mul20=%.3f" % [
		game_clock_ok, early_challenge_ok, rune_formula_ok, slot_layout_ok,
		omen_gate_ok, omen_spawn_ok, omen_reward_ok,
		infinite_ok, dwell_monotone_ok, monotonic_ok, curve_ok, reward_decay_ok, volume_ok,
		blight_ok, valve_ok, carryover_ok, total_days_ok, phase_len_ok, recal_ok,
		stage_pipe_ok, blight_wire_ok, descent_wire_ok,
		TARGET_CYCLES, journey.day_number,
		StageClock.dwell_kill_efficiency(4), StageClock.dwell_kill_efficiency(8), StageClock.dwell_kill_efficiency(12),
		StageClock.night_enemy_limit_at(99), game.demon_lord.hp_multiplier(20, 5)
	])
	var stage_passed := game_clock_ok and early_challenge_ok and rune_formula_ok and slot_layout_ok \
		and omen_gate_ok and omen_spawn_ok and omen_reward_ok \
		and infinite_ok and dwell_monotone_ok and monotonic_ok and curve_ok and reward_decay_ok \
		and volume_ok and blight_ok and valve_ok and carryover_ok and total_days_ok \
		and phase_len_ok and recal_ok \
		and stage_pipe_ok and blight_wire_ok and descent_wire_ok
	await _quit_test_cleanly(stage_passed)

## V1 소유. 신설(설계 §8 테스트 표 · 부록 B의 V1).
## 채울 것: §4.4 매트릭스 7×6 전 칸 단언 · 도트 총량이 §4.3 검산치와 오차 2% 이내 ·
## 지속시간 경계(정확히 0초, 갱신, 중첩 상한 6) ·
## 전이 이벤트가 {radius, max_targets, falloff}를 정확히 낸다.
## V6이 여기에 런타임 통합 단언(대폭 연소·전도·반응 예산·도트 킬 재귀)을 덧붙인다.
func _run_status_test() -> void:
	# V1 본문. 판정 스위트 자체는 `scripts/test/status_test.gd`(StatusTest)에 있다 —
	# 설계 부록 B의 V1 행이 그 파일을 V1 소유로 명시하고, V4가 같은 파일의
	# `_run_stage_test()`를 동시에 편집 중이라 공유 파일에 남기는 흔적을 최소화했다.
	# 판정 7묶음: basics · matrix(42칸) · blaze_ratio(7.5배) · conduction(4체 전이) ·
	#             psi_harvest · budget(예산·깊이) · deterministic.
	var report: Dictionary = StatusTest.run_all()
	var details: Array = report.get("details", [])
	for line in details:
		print("  %s" % String(line))
	print("STATUS_TEST_COMPLETE %s tick=%.2f budget=%d depth=%d" % [
		String(report.get("summary", "")),
		GameTuning.STATUS_TICK,
		GameTuning.STATUS_REACTION_BUDGET_PER_FRAME,
		GameTuning.STATUS_PROPAGATION_DEPTH
	])
	await _quit_test_cleanly(bool(report.get("passed", false)))


## 이어하기가 보존해야 하는 모든 축을 문자열 한 장으로 압축한다.
## 값이 아니라 **지문**을 비교하는 이유: 새 키가 스냅샷에 추가되면 여기 한 줄만 늘리면 된다.
func _save_test_fingerprint() -> Dictionary:
	var slot_signature: Array[String] = []
	for index in game.factory.slots.size():
		var card: Dictionary = game.factory.get_card(index)
		var rune_ids: Array[String] = []
		for rune_value in game.factory.runes_on(index):
			rune_ids.append(String((rune_value as Dictionary).get("id", "")))
		rune_ids.sort()
		slot_signature.append("%s:R%d[%s]" % [
			String(card.get("id", "-")), int(card.get("rank", 0)), ",".join(rune_ids)
		])
	var equipment_ids: Array[String] = []
	for equipped: Dictionary in game.factory.equipment:
		equipment_ids.append(String(equipped.get("id", "")))
	var rift_progress: Array[String] = []
	for rift_id in game.rift_states:
		var entry: Dictionary = game.rift_states[rift_id]
		rift_progress.append("%s:%d:%s" % [
			rift_id, int(entry.get("remaining", -1)), bool(entry.get("cleared", false))
		])
	rift_progress.sort()
	# V9: 랜드마크 3종은 "스테이지 시드가 정말 되살아났는가"의 유일한 관측점이다.
	# 시드가 어긋나면 지형은 눈으로 봐야 알지만 성·캠프·보스문 좌표는 즉시 어긋난다.
	var discovered_signature: Array[String] = []
	for key in game.discovered_features.keys():
		discovered_signature.append(String(key))
	discovered_signature.sort()
	var event_signature: Array[String] = []
	for event_value: Dictionary in game.stage_events:
		var at: Vector2 = event_value.get("position", Vector2.ZERO)
		event_signature.append("%s:%s:%s@%.0f,%.0f" % [
			String(event_value.get("id", "")), String(event_value.get("type", "")),
			String(event_value.get("state", "")), at.x, at.y])
	event_signature.sort()
	var landmark_signature: Array[String] = []
	for key: String in ["boss_gate", "camp", "castle"]:
		var landmark: Dictionary = game.world.get_landmark(key)
		var point: Vector2 = landmark.get("position", Vector2.ZERO)
		landmark_signature.append("%s@%.0f,%.0f" % [key, point.x, point.y])
	return {
		"day": game.clock.day_number,
		"night": game.is_night,
		"phase": "%.1f" % game.phase_elapsed,
		"level": game.level,
		"experience": game.experience,
		"xp_target": game.xp_target,
		"kills": game.kills,
		"gold": game.gold,
		"playtime": "%.1f" % game.elapsed_time,
		"cycle_seed": game.run_cycle_seed,
		"selected": ",".join(game.selected_skills),
		"rejected": ",".join(game.rejected_skills),
		"boss_items": ",".join(game.boss_items),
		"boss_adv": game.trophy_reject_skills.size(),
		"omen_nights": game.omen_night_count,
		"rune_count": game.demon_lord.rune_count(),
		"rune_capacity": game.demon_lord.rune_capacity(),
		"rune_shards": game.demon_lord.rune_shards,
		"granted": game.demon_lord.granted_runes.size(),
		"stripped": game.demon_lord.stripped_runes.size(),
		"reclaimed": game.demon_lord.reclaimed_cards.size(),
		"descended": game.demon_lord.descended,
		"slots": " | ".join(slot_signature),
		"inventory": game.factory.inventory.size(),
		"equipment": ",".join(equipment_ids),
		"player_health": "%.1f" % game.player.health,
		"player_max_health": "%.1f" % game.player.max_health,
		"player_damage": "%.2f" % game.player.damage,
		"player_position": "%.0f,%.0f" % [game.player.global_position.x, game.player.global_position.y],
		"player_skills": ",".join(game.player.applied_skills),
		"branch": game.player.last_trophy_id,
		"tier": game.player.trophy_count,
		# V8: 트로피 배열 자체와 그것이 만든 스탯이 함께 왕복해야 한다.
		"trophies": ",".join(PackedStringArray(game.player.trophy_stages.map(func(v): return str(v)))),
		"trophy_health": "%.1f" % float(game.trophy_effect_summary().get("health", 0.0)),
		"growth_cap": game.growth_cap_conversions,
		"synergy": game.run_synergy_triggers,
		"shields": game.player.shield_charges,
		"rollbacks": game.player.rollback_charges,
		"pact_sell": int(game.pact_uses.get("sell_day", -1)),
		"pact_buy": int(game.pact_uses.get("buy_day", -1)),
		"pact_mortgage": int(game.pact_uses.get("mortgage", -1)),
		"rune_shop": game.rune_shop_purchases,
		# Y2 가산 축 — 레일 각인 왕복. id 목록까지 봐야 "개수만 맞고 내용이 다른" 복원을 잡는다.
		"rail_runes": ",".join(game.factory.rail_rune_ids()),
		"spy": game.spy_wipe_stage,
		"blight": game.blight_active,
		"blight_marked": game.blight_marked,
		"peak_steps": game.run_peak_steps,
		"reload_windows": game.boss_reload_windows,
		"opened_features": game.opened_features.size(),
		"rift_progress": " | ".join(rift_progress),
		# === Y6 가산 4축 — 발견 · 사건 · 소비 칸 (schema 4) ===
		# 발견은 **키 목록까지** 본다. 개수만 보면 "성만 살아남고 보스문이 죽은"
		# 복원이 통과한다(발견 기반 내비에서는 그게 곧 화살표가 사라지는 것이다).
		"discovered": ",".join(discovered_signature),
		"events": " | ".join(event_signature),
		"event_budget": game.run_event_count,
		"consumable": "%s:%d" % [game.consumable_item, game.night_eye_nights],
		# === V9 가산 19축 — 스테이지 · 랜드마크 · 그레이드 ===
		# v3의 진행은 "몇 일차"가 아니라 "몇 스테이지 · 체류 몇"이다. V8까지의 지문은
		# 그 축을 하나도 보지 않아서, 스테이지 3 저장이 스테이지 1로 복원돼도 통과했다.
		"stage": game.clock.stage,
		"dwell": game.clock.dwell,
		"stages_cleared": game.clock.stages_cleared,
		"total_days": game.clock.day_number,
		"clock_descended": game.clock.descended,
		"descent_used": game.clock.descent_used_this_stage,
		"run_elapsed": "%.1f" % game.clock.run_elapsed(),
		"stage_descent_pending": game.stage_descent_pending,
		"camp_rest_used": game.camp_rest_used,
		"stage_boss_cleared": game.stage_boss_cleared,
		# 월드 — 시드가 어긋나면 아래 4축이 동시에 무너진다
		"world_stage": game.world.get_stage(),
		"world_seed": game.world.stage_seed,
		"world_atlas": game.world.stage_atlas_key,
		"world_gate_cleared": game.world.boss_gate_cleared,
		"landmarks": " | ".join(landmark_signature),
		# 그레이드(스테이지별 색 보정) — 아틀라스와 짝을 이루는 시각 정본
		"grade_saturation": "%.2f" % game.world.stage_saturation,
		"grade_green": "%.2f" % game.world.stage_green_overlay,
		# 상태이상은 저장하지 않는다 → 저장 전에도 복원 후에도 0이어야 한다(설계 §9)
		"status_total": "%.2f" % StatusEngine.total_remaining(game.player_status)
	}


## 흐름 계열이 드래프트 가중에서 차지하는 비율(해석적). 억제 규칙의 직접 관측점이다.
func _draft_flow_weight_share() -> float:
	var scale := game._rune_draft_flow_scale()
	var day := game.day_number
	var flow := 0.0
	var total := 0.0
	for rune_id in RuneEngine.all_rune_ids():
		var weight := game._rune_draft_weight(rune_id, scale, day)
		total += weight
		if String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("family", "")) == "flow":
			flow += weight
	return 0.0 if total <= 0.0 else flow / total

## 같은 규칙을 실제 추출로 확인한다(해석식과 구현이 어긋나지 않는지).
func _draft_flow_sample_share(samples: int) -> float:
	var flow := 0
	var total := 0
	for _sample in samples:
		for offer_value in game._roll_rune_draft():
			var rune_id := String((offer_value as Dictionary).get("instance", {}).get("id", ""))
			total += 1
			if String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("family", "")) == "flow":
				flow += 1
	return 0.0 if total <= 0 else float(flow) / float(total)

# W0 신설: 셸에서 PASS/FAIL을 판정할 수 있도록 종료 코드를 돌려준다.
# passed=false면 종료 코드 1로 나가고 run_all.sh가 그 자리에서 FAIL로 집계한다.
# 정리(clean-up) 절차 자체는 v1과 한 줄도 다르지 않다.
func _quit_test_cleanly(passed: bool) -> void:
	print("%s exit_code=%d" % ["TEST_RESULT=PASS" if passed else "TEST_RESULT=FAIL", 0 if passed else 1])
	get_tree().paused = false
	if is_instance_valid(game.sound_manager) and game.sound_manager.has_method("stop_all"):
		game.sound_manager.stop_all()
	game.boss_toast_queue.clear()
	if is_instance_valid(game.boss_toast):
		game.boss_toast.free()
	game.boss_toast = null
	if is_instance_valid(game.overlay):
		game.overlay.free()
	game.overlay = null
	if is_instance_valid(game.gameplay_root):
		game.gameplay_root.free()
	game.gameplay_root = null
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if passed else 1)

func _run_visual_capture(capture_name: String) -> void:
	game.automated_test = true
	match capture_name:
		"lobby":
			# V9: 로비를 **저장이 있는 상태**로 찍는다. 그전까지 이 컷은 항상
			# "이어하기 · 저장된 모험 없음"(비활성 버튼)이라, 이어하기 표기가 회귀해도
			# 캡처로는 알 수 없었다. 실제 런을 스테이지 3까지 올려 저장한 뒤 로비로 나온다.
			game._start_game()
			await get_tree().create_timer(0.4).timeout
			game.advance_stage()
			game.advance_stage()
			await get_tree().process_frame
			game.clock.set_day_raw(11)
			game.clock.set_dwell_raw(5)
			game.elapsed_time = 512.5
			game.level = 9
			game.gold = 486
			game.state = "playing"
			game._save_run_snapshot()
			game._show_menu()                       # `_load_progress()`를 스스로 부른다
		"character":
			game._show_character_select()
		"settings":
			# 토글 3종이 전부 **켜짐**(함몰 베벨)인 상태로 찍는다. 꺼짐(융기)과 나란히
			# 보려면 이 컷과 실기를 비교하면 된다 — 기하가 갈리는지가 검수 항목이다.
			game.screen_shake_enabled = true
			game.damage_numbers_enabled = true
			game.fullscreen_enabled = false
			game._show_settings()
			await get_tree().create_timer(0.35).timeout
		"onboarding":
			# 2026-08-07: 온보딩은 완전 정적 화면이라 애니메이션 대기가 필요 없다.
			# 대신 페이지 전부를 -pN.png로 따로 저장해 한 번의 캡처로 4장을 모두 검수한다.
			var onboarding_directory := ProjectSettings.globalize_path("res://art/screenshots/qa")
			DirAccess.make_dir_recursive_absolute(onboarding_directory)
			for page_index in game.ONBOARDING_PAGE_COUNT:
				game._show_onboarding(page_index)
				await get_tree().process_frame
				await get_tree().process_frame
				var page_path := onboarding_directory.path_join("onboarding-minimal-v2-p%d.png" % (page_index + 1))
				var page_error := get_viewport().get_texture().get_image().save_png(page_path)
				print("VISUAL_CAPTURE_PAGE page=%d path=%s error=%d" % [page_index + 1, page_path, page_error])
			# 대표 캡처(onboarding-minimal-v2.png)는 핵심 규칙 페이지인 딜싸이클로 남긴다.
			game._show_onboarding(1)
		"world":
			# W5 이후 --capture-world는 **HUD 없는 순수 월드**다. 필드 HUD 검수는
			# --capture-hud가 전담한다(두 캡처가 같은 그림이 되지 않게 분리).
			# V5: 스테이지 그레이드 5단이 육안으로 갈리는지가 이번 웨이브의 검수 항목이라
			# **스테이지 1·3·5 × 낮/밤 6컷 + 랜드마크 2컷**을 먼저 찍고 대표 컷으로 돌아온다.
			game._start_game()
			await get_tree().create_timer(0.55).timeout
			await _run_stage_tone_capture()
			# W9 추가 컷: 균열 아레나(정예 웨이브 포함). 대표 컷은 아래에서 순수 월드로
			# 되돌리므로 이 한 장만 별도 파일로 남긴다.
			# Y5(handoff-y4 §8.1 · §9-A): **주석은 그렇게 적혀 있었는데 코드가 안 되돌렸다.**
			# 플레이어를 균열로 옮겨 놓고 그대로 대표 컷을 찍는 바람에 두 PNG의 shasum이
			# 같았다(= 순수 월드 컷이 사실은 균열 컷이었다). 자리를 여기서 기억해 둔다.
			var pure_world_position: Vector2 = game.player.global_position
			var probe_rift: Dictionary = game.world.spawn_rift_near(game.player.global_position)
			if not probe_rift.is_empty():
				game.rift_states[String(probe_rift["id"])] = {"activated":false, "remaining":0, "cleared":false}
				game.player.global_position = probe_rift["position"]
				game.player.invulnerability = 999.0
				var rift_camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
				if is_instance_valid(rift_camera):
					rift_camera.reset_smoothing()
				game._activate_rift(String(probe_rift["id"]))
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(game.active_banner):
					game.active_banner.queue_free()
				game.active_banner = null
				game.hud.visible = false
				await _save_capture_png("world-minimal-v2-rift.png")
				game.hud.visible = true
				# 대표 컷을 위해 **순수 월드로 되돌린다.** 카메라 스무딩을 같이 리셋하지
				# 않으면 카메라가 균열에서 여기까지 몇 프레임에 걸쳐 미끄러져 오는 도중에
				# 사진이 찍혀, 아무 데도 아닌 중간 지점이 대표 컷으로 남는다.
				game.player.global_position = pure_world_position
				var restore_camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
				if is_instance_valid(restore_camera):
					restore_camera.reset_smoothing()
				game.world.queue_redraw()
				await get_tree().create_timer(0.35).timeout
			game.state = "preview"
			get_tree().paused = true
			game._update_hud()
			game.hud.visible = false
			# 배너는 ui_root 직속이라 hud를 숨겨도 남는다. 순수 월드 컷이므로 함께 걷어낸다.
			if is_instance_valid(game.active_banner):
				game.active_banner.queue_free()
			game.active_banner = null
		"hud":
			# W5 필드 HUD 검수 전용. 5칸 레일·바늘·각인 배지·과열·빚·기한 패널·
			# 마왕 고스트 레일·균열 나침반이 한 화면에 전부 보이는 상태를 만든 뒤
			# 낮 / 밤 / RELOAD 세 컷을 저장한다.
			await _run_hud_capture()
		"rail":
			# W6 편집 화면 검수 전용. **두 조작 모드가 시각적으로 구분되는가**가 핵심이다.
			await _run_rail_capture()
		"draft":
			# W6 각인 드래프트 검수 전용. 1단계(3택) / 2단계(강화할 칸) / 상한 칸 제외.
			await _run_draft_capture()
		"choice":
			# U2 v3 신설. 레벨업 2택 + 각인 강화(카드 3장) / 아이템 2택.
			await _run_choice_capture()
		"guide":
			# U3 v3 신설. 스포트라이트 길잡이 — 구멍이 플레이어 / 5칸 레일 / 나침반에
			# 각각 물린 3컷. 안내판이 위·아래 두 자리를 오가는 것도 이 3컷에서 갈린다.
			await _run_guide_capture()
		"castle":
			# W9 신설 · V8 갱신. 성 내부 NPC 4종 + 각인 세공사 / 계약자 / 밀정 / **보스 트로피 2택1**.
			await _run_castle_capture()
		"factory":
			game._start_game()
			await get_tree().create_timer(0.35).timeout
			game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
			game.factory.equip(ItemLibrary.instance("r_rapier_01"))
			game.factory.place_card(2, DealCardLibrary.instance("rapid_slash", 1))
			game.factory.place_card(1, DealCardLibrary.instance("time_cut", 1))
			game.factory.attach_rune(1, RuneEngine.roll_rune("back_one", game.rng))
			game.factory.attach_rune(3, RuneEngine.roll_rune("jump_one", game.rng))
			for skill_id in ["flame_field", "thunder", "moon_barrier", "meteor_blade"]:
				game.factory.add_inventory(DealCardLibrary.instance(skill_id, 1))
			game._show_factory_menu("edit")
			# 모달 등장 애니메이션이 끝난 뒤 찍어야 실제 화면 밝기로 확인할 수 있습니다.
			await get_tree().create_timer(0.45).timeout
		"effects":
			game._start_game()
			await get_tree().create_timer(0.35).timeout
			game.factory.place_card(0, DealCardLibrary.instance("sword_rain", 3))
			game.factory.place_card(1, DealCardLibrary.instance("gravity_well", 2))
			game.factory.place_card(2, DealCardLibrary.instance("blade_fan", 2))
			for index in 12:
				game.combat.spawn_enemy_instance(game.player.global_position + Vector2.from_angle(TAU * float(index) / 12.0) * 135.0, 2, "", false, "", false, "skeleton")
			game._reset_player_cycle()
			await get_tree().create_timer(0.9).timeout
			# V6 육안 검수 2종을 여기서 함께 찍는다(설계 §4.8).
			#   ① 머리 위 상태 핍 5종 실루엣 + 3개 상한 + 본체 마스크 틴트
			#   ② 시너지 1회성 버스트(대폭 연소 · 전도)와 부유 라벨
			await _run_status_effect_capture()
			game.state = "preview"
			get_tree().paused = true
			game._update_hud()
		"boss":
			# W10: 프리뷰 1컷 + 전투 2컷(과열 / RELOAD 창). 대표 컷은 전투 중 레일이다 —
			# 보스전의 공략 문법(§6.2)이 화면에서 읽히는지가 이번 웨이브의 검수 항목이다.
			await _run_boss_capture()
		"result":
			# W10: 승리 / 패배 2컷. 7일 타임라인 · v2 지표 · 최종 5칸이 전부 판독돼야 한다.
			await _run_result_capture()
		_:
			pass
	await get_tree().process_frame
	await get_tree().process_frame
	var capture_directory := ProjectSettings.globalize_path("res://art/screenshots/qa")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var capture_path := capture_directory.path_join("%s-minimal-v2.png" % capture_name)
	# Y3: 개별 컷과 **같은 강제 그리기**를 거친다. 안 하면 대표 컷만 한 상태 뒤처져
	#     "마지막 컷의 복사본"으로 저장된다(실측 — draft 대표 컷이 p3와 같은 지문이었다).
	RenderingServer.force_draw()
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	print("VISUAL_CAPTURE_COMPLETE name=%s path=%s error=%d" % [capture_name, capture_path, error])
	# V10(2026-08-09 · handoff-v9 §9 #6): `--capture-lobby`는 이어하기 버튼을 **활성**
	# 상태로 찍기 위해 실기 세이브를 하나 남기고 끝났다. 다른 검사는 그 파일을 읽지
	# 않으므로 무해했지만, 캡처만 돌린 사람의 실기 진행 파일에 스테이지 3 세이브가
	# 조용히 꽂히는 것은 옳지 않다. 사진을 찍은 **뒤에** 치운다 — 순서가 요점이다.
	if capture_name == "lobby":
		game._clear_run_save()
	get_tree().paused = false
	get_tree().quit(0 if error == OK else 1)

# =============================================================================
# V6 신설: --capture-effects의 상태 핍 · 시너지 VFX 스윕 (설계 §4.8)
# =============================================================================
# 두 컷을 따로 남긴다. 대표 컷(effects-minimal-v2.png)은 사이클 이펙트가 주인공이라
# 핍이 작게 묻히기 때문이다.
#   effects-minimal-v2-status.png   핍 5종 실루엣 · 3개 상한 · 마스크 틴트
#   effects-minimal-v2-synergy.png  대폭 연소 · 전도 버스트 + 부유 라벨
func _run_status_effect_capture() -> void:
	var ring: Array[Node] = []
	for enemy: Node in game.combat.active_enemies:
		if is_instance_valid(enemy) and not enemy.is_boss:
			enemy.max_health = 5000.0
			enemy.health = 5000.0
			enemy.displayed_health = enemy.health
			enemy.trailing_health = enemy.health
			ring.append(enemy)
	# 5종을 하나씩 + 3개 이상 겹친 개체를 섞어 핍 상한(STATUS_PIP_MAX)까지 보이게 한다.
	for index in ring.size():
		var enemy := ring[index]
		match index % 6:
			0: StatusEngine.set_status(enemy.st_state, "poison", {"damage": 40.0, "stacks": 4})
			1: StatusEngine.set_status(enemy.st_state, "burn", {"damage": 40.0})
			2: StatusEngine.set_status(enemy.st_state, "chill")
			3: StatusEngine.set_status(enemy.st_state, "oil")
			4: StatusEngine.set_status(enemy.st_state, "shock")
			5:
				# 4종 동시 = 핍이 3개에서 잘리는지 눈으로 확인하는 개체.
				StatusEngine.set_status(enemy.st_state, "poison", {"damage": 40.0, "stacks": 2})
				StatusEngine.set_status(enemy.st_state, "burn", {"damage": 40.0})
				StatusEngine.set_status(enemy.st_state, "chill")
				StatusEngine.set_status(enemy.st_state, "oil")
		enemy.queue_redraw()
	await get_tree().create_timer(0.25).timeout
	await _save_capture_png("effects-minimal-v2-status.png")

	# ---- 시너지 버스트: 대폭 연소(행 0) + 전도(행 1) ----
	# 트윈이 없고 노드가 자기 elapsed로 8프레임을 훑으므로, **발동 직후 정지**시키면
	# 첫 프레임이 그대로 찍힌다.
	var blaze_card := _v6_probe_card("flame_field")
	var conduct_card := _v6_probe_card("thunder")
	for index in ring.size():
		var enemy := ring[index]
		StatusEngine.clear(enemy.st_state)
		if index % 2 == 0:
			StatusEngine.set_status(enemy.st_state, "oil")
		else:
			StatusEngine.set_status(enemy.st_state, "chill")
	game.combat.rebuild_enemy_spatial()
	game.combat.begin_status_frame()
	for index in ring.size():
		var enemy := ring[index]
		if not is_instance_valid(enemy):
			continue
		if index % 2 == 0:
			game.combat.strike_enemy_with_card(enemy, blaze_card, 60.0, enemy.global_position)
		else:
			game.combat.strike_enemy_with_card(enemy, conduct_card, 60.0, enemy.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save_capture_png("effects-minimal-v2-synergy.png")


# =============================================================================
# V5 신설: --capture-world의 스테이지 톤 스윕 (설계 §7.3 · 5단 그레이드)
# =============================================================================
# 스테이지 1(왕국 변경 · verdant) / 3(잿빛 벌판 · waste + 안개) / 5(심연 · abyss +
# 안개 + 비네트 + 채도 0.65)를 **낮/밤 각각** 찍는다. 아틀라스 교체 · CanvasModulate ·
# 안개/비네트 오버레이 · 채도가 한 컷씩 겹쳐 보여야 5단이 갈렸다고 말할 수 있다.
# 랜드마크 2종(보스문 아레나 · 베이스캠프)도 별도 컷으로 남긴다.
func _run_stage_tone_capture() -> void:
	for stage_number: int in [1, 3, 5]:
		game.clock.set_stage_raw(stage_number)
		game._rebuild_stage_world(stage_number)
		game.player.global_position = Vector2.ZERO
		game.player.invulnerability = 99999.0
		var camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
		if is_instance_valid(camera):
			camera.reset_smoothing()
		game._apply_stage_grade()
		for phase: String in ["day", "night"]:
			game.clock.set_night_raw(phase == "night")
			game._update_world_lighting(1.0)
			game.world.set_night_amount(1.0 if phase == "night" else 0.0)
			game.world.queue_redraw()
			await get_tree().create_timer(0.35).timeout
			if is_instance_valid(game.active_banner):
				game.active_banner.queue_free()
			game.active_banner = null
			game.hud.visible = false
			await _save_capture_png("world-minimal-v2-stage%d-%s.png" % [stage_number, phase])
			game.hud.visible = true
		# 랜드마크 2컷 — 5스테이지에서만 찍는다(가장 어두운 톤에서 판독되면 나머지는 자동).
		if stage_number == 5:
			game.clock.set_night_raw(false)
			game._update_world_lighting(1.0)
			game.world.set_night_amount(0.0)
			for landmark_key: String in ["camp", "boss_gate"]:
				game.player.global_position = game.world.get_landmark(landmark_key).get("position", Vector2.ZERO)
				var landmark_camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
				if is_instance_valid(landmark_camera):
					landmark_camera.reset_smoothing()
				game.world.queue_redraw()
				await get_tree().create_timer(0.35).timeout
				if is_instance_valid(game.active_banner):
					game.active_banner.queue_free()
				game.active_banner = null
				game.hud.visible = false
				await _save_capture_png("world-minimal-v2-landmark-%s.png" % landmark_key)
				game.hud.visible = true
	# 대표 컷은 스테이지 1 낮으로 되돌린다(v2 회귀 비교가 쉬워야 한다).
	game.clock.set_stage_raw(1)
	game.clock.set_night_raw(false)
	game._rebuild_stage_world(1)
	game.player.global_position = Vector2.ZERO
	game._apply_stage_grade()
	game._update_world_lighting(1.0)
	game.world.set_night_amount(0.0)
	var reset_camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(reset_camera):
		reset_camera.reset_smoothing()
	await get_tree().create_timer(0.35).timeout

# =============================================================================
# --capture-hud (W5 신설 · **X3 전면 갱신**) — 필드 HUD 6컷
# =============================================================================
# X3 완료 기준(사용자 피드백 ⑥): 상단 패널 4장과 하단 밴드의 **판이 전부 사라졌는가** ·
# 나침반 자리에 **가장자리 화살표**가 섰는가 · 딜싸이클이 **아이콘 스트립**이 됐는가 ·
# 그러고도 W5/V5의 정보가 하나도 안 없어졌는가(호버 컷이 그 증거다).
#
# 검수 기준 한 줄 — **어두운 5스테이지 밤 + 안개에서도 체력 · 바늘 · 화살표가 읽히는가.**
# 그래서 마지막 컷이 그 최악 조건이다. 여기서 읽히면 나머지는 자동이다.
#
# 컷 여섯
#   hud-x3-day.png          낮 · 실행 중 · 과열 4 · 흐름 델타(회귀) — 대표 컷
#   hud-x3-night.png        밤 · 과열 7 · 재실행
#   hud-x3-reload.png       RELOAD 대기 — 스트립 전체가 청색으로 식는다
#   hud-x3-tip.png          미니모드 **호버 상세** — 지운 문장이 어디로 갔는가의 증거
#   hud-x3-blight.png       잠식 경고 — 한 줄 경고문이 발동했을 때만 뜬다
#   hud-x3-stage5-night.png **5스테이지 밤 + 안개 + 비네트** — 판독성 최악 조건
func _run_hud_capture() -> void:
	game._start_game()
	await get_tree().create_timer(0.4).timeout
	# 5칸을 정보로 가득 채운다. 원소는 화·뇌·빙·유 **네 계**로 갈라 미니 스트립에서
	# "속성 = 색"이 실제로 갈리는지 한 장에서 보이게 한다(X2 §6.1 ③과 같은 이유).
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
	game.factory.place_card(1, DealCardLibrary.instance("thunder", 1))
	game.factory.place_card(2, DealCardLibrary.instance("flame_field", 3))
	game.factory.place_card(3, DealCardLibrary.instance("frost_ring", 1))
	game.factory.attach_rune(0, RuneEngine.roll_rune("strong", game.rng))
	game.factory.attach_rune(1, RuneEngine.roll_rune("back_one", game.rng))
	game.factory.attach_rune(1, RuneEngine.roll_rune("strong", game.rng))
	for rune_id in ["jump_one", "first_hit", "quick", "wide"]:
		game.factory.attach_rune(2, RuneEngine.roll_rune(rune_id, game.rng))
	# 마왕 고스트 레일 — 버린 카드 8장 + 아이템 3개로 5칸이 다 차고 잔재도 남는다.
	game.rejected_skills.assign(["cleave", "cleave", "rapid_slash", "thunder", "meteor_blade", "moon_barrier", "recursion", "execution"])
	game.boss_items.assign(["u_greatsword_01", "r_ring_02", "h_neck_01"])
	game.demon_lord.sync_runes(game.rng)
	# 균열 화살표 — 개설 훅(W4/W9 소유)이 아직 game.gd에 없으므로 캡처에서 직접 연다.
	game.world.begin_run_rifts(20260807)
	game.world.spawn_rift_near(game.player.global_position)
	game._reset_player_cycle()
	# 보호막·부활 핍이 실제로 서는 그림을 남긴다(구 "수호 N · 부활 N" 문장의 후신).
	game.player.shield_charges = 3
	game.player.rollback_charges = 1
	# V5: 기한 패널이 사라지고 **스테이지 · 체류 압박 줄**이 그 자리에 섰다.
	# 체류 2 / 잠식 임계 4 = 게이지가 절반쯤 차고 임계선이 오른쪽에 보이는 상태다.
	game.clock.set_stage_raw(2)
	game.clock.set_dwell_raw(2)
	game.clock.set_day_raw(6)
	game.clock.set_night_raw(false)
	game.clock.set_phase_elapsed_raw(GameTuning.STAGE_DAY_DURATION[1] * 0.42)
	game._apply_stage_grade()
	await get_tree().create_timer(1.1).timeout
	# 런 개시 배너(820×58)가 아직 떠 있으면 대표 컷 한가운데를 가려 "필드가 열렸다"는
	# X3의 그림이 그 한 장에서만 안 보인다. 첫 컷 전에 걷는다.
	if is_instance_valid(game.active_banner):
		game.active_banner.queue_free()
	game.active_banner = null

	# ---- 컷 1: 낮 · 실행 중 · 과열 4 · 흐름 델타(회귀) 강조 ----
	# 컷마다 큰 delta로 한 번 돌려 직전 컷(과 실주행)의 잔여 강조를 씻어낸 뒤,
	# 그 컷에서 보여줄 강조만 다시 켜고 delta 0으로 그린다.
	game.state = "preview"
	get_tree().paused = true
	game.player_cycle.exec_counts.assign([2, 1, 1, 0, 0])
	game.player_cycle.reload_debt = 1.35
	game._update_cycle_rail(4.0)
	game._on_rail_rune_fired("back_one", 3)
	game._on_rail_slot_entered(2, 0)
	game._update_cycle_rail(0.0)
	game._update_hud()
	# X3: `_update_edge_nav()`는 `state == "playing"`에서만 화살표를 켠다. 캡처는
	# 그림을 멈추려고 state를 "preview"로 돌려 두므로, 여기서만 한 번 되돌려 그린다.
	_capture_paint_edge_nav()
	await _save_capture_png("hud-x3-day.png")
	# 점유율은 대표 컷 상태에서 잰다 — 이 숫자가 곧 "필드가 얼마나 열렸나"다.
	var coverage := _hud_coverage()
	print("HUD_COVERAGE block_px=%d block_pct=%.2f ink_px=%d ink_pct=%.2f strip_h=%d" % [
		int(coverage["block_px"]), float(coverage["block_pct"]),
		int(coverage["ink_px"]), float(coverage["ink_pct"]), int(game.RAIL_BAND_RECT.size.y)])

	# ---- 컷 2: 밤 · 되밟기(칸 3 두 번째 실행) 강조 ----
	game.clock.set_night_raw(true)
	game.clock.set_phase_elapsed_raw(GameTuning.STAGE_NIGHT_DURATION[game.clock.stage_index()] * 0.55)
	game.canvas_modulate.color = GameTuning.STAGE_NIGHT_MODULATE[game.clock.stage_index()]
	game.world.set_night_amount(1.0)
	game.player_cycle.exec_counts.assign([2, 2, 2, 1, 1])
	game.player_cycle.current_index = 2
	game.player_cycle.current_reentry = 1
	game.player_cycle.reload_debt = 2.4
	game._update_cycle_rail(4.0)
	game._on_rail_slot_entered(2, 2)
	game._update_cycle_rail(0.0)
	game._update_hud()
	_capture_paint_edge_nav()
	await _save_capture_png("hud-x3-night.png")

	# ---- 컷 3: RELOAD 대기 — 스트립 전체가 청색으로 식는다(설계 §8.1) ----
	game.player_cycle.reloading = true
	game.player_cycle.reload_duration = 2.4
	game.player_cycle.reload_remaining = 1.42
	game.player_cycle.current_reentry = 0
	# 강조를 모두 씻어내야 "스트립 전체가 청색으로 식는" 것이 그대로 보인다.
	game._update_cycle_rail(4.0)
	game._update_hud()
	_capture_paint_edge_nav()
	await _save_capture_png("hud-x3-reload.png")

	# ---- 컷 4(X3 신설): **미니모드 호버 상세** ----
	# 화면에서 지운 25줄이 어디로 갔는지를 그림으로 남기는 컷이다. 캡처에서는 마우스를
	# 움직일 수 없으므로 툴팁을 강제로 띄운다(사람이 호버했을 때와 **같은 경로** —
	# `tooltip_force()`는 지연만 건너뛴다 · handoff-x2 §4.3).
	game.player_cycle.reloading = false
	game.player_cycle.reload_remaining = 0.0
	game.player_cycle.current_index = 2
	game.clock.set_night_raw(false)
	game.canvas_modulate.color = GameTuning.STAGE_DAY_MODULATE[game.clock.stage_index()]
	game.world.set_night_amount(0.0)
	game._update_cycle_rail(4.0)
	game._update_hud()
	_capture_paint_edge_nav()
	game._force_hud_tooltip("rail_slot2")
	await get_tree().create_timer(0.35).timeout
	await _save_capture_png("hud-x3-tip.png")
	UIKit.tooltip_hide(game.hud_tooltip_layer)

	# ---- 컷 5(V5 신설): **잠식 경고** — 체류 압박 게이지가 임계선을 넘은 상태 ----
	# 설계 §10 리스크 #1이 "게이지와 임계선이 곡선보다 중요하다"고 못 박은 화면이다.
	# X3에서는 이 컷에서만 스테이지 줄 아래에 붉은 경고문 한 줄이 뜬다.
	game.clock.set_night_raw(true)
	game.clock.set_dwell_raw(game.clock.blight_threshold())
	game._check_stage_blight()
	game.canvas_modulate.color = GameTuning.STAGE_NIGHT_MODULATE[game.clock.stage_index()]
	game.world.set_night_amount(1.0)
	game._update_cycle_rail(4.0)
	game._update_hud()
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(game.active_banner):
		game.active_banner.queue_free()
	game.active_banner = null
	game._update_hud()
	_capture_paint_edge_nav()
	await _save_capture_png("hud-x3-blight.png")
	game.clock.set_dwell_raw(2)
	game.blight_active = false

	# ---- 컷 6(X3 신설 · **필수 검수 컷**): 5스테이지 밤 + 안개 + 비네트 ----
	# 프레임을 걷어낸 HUD가 무너진다면 여기서 무너진다. CanvasModulate #2f2f52 +
	# 안개 0.24 + 비네트 0.55가 겹친 화면에서 체력 바 · 바늘 · 화살표 · 숫자가
	# `_label()` 외곽선과 로컬 스크림만으로 읽혀야 한다.
	get_tree().paused = false
	game.clock.set_stage_raw(5)
	game._rebuild_stage_world(5)
	game.player.global_position = Vector2.ZERO
	game.player.invulnerability = 99999.0
	var camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	game.world.begin_run_rifts(20260807)
	game.world.spawn_rift_near(game.player.global_position)
	game.clock.set_night_raw(true)
	game._apply_stage_grade()
	game._update_world_lighting(1.0)
	game.world.set_night_amount(1.0)
	game.world.queue_redraw()
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	game.player_cycle.exec_counts.assign([2, 1, 1, 1, 0])
	game.player_cycle.reload_debt = 1.9
	game._update_cycle_rail(4.0)
	game._update_hud()
	if is_instance_valid(game.active_banner):
		game.active_banner.queue_free()
	game.active_banner = null
	_capture_paint_edge_nav()
	await _save_capture_png("hud-x3-stage5-night.png")

	# 대표 컷은 스테이지 2 낮 상태로 되돌려 저장한다(_run_visual_capture 꼬리가 찍는다).
	get_tree().paused = false
	game.clock.set_stage_raw(2)
	game._rebuild_stage_world(2)
	game.player.global_position = Vector2.ZERO
	var reset_camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(reset_camera):
		reset_camera.reset_smoothing()
	game.world.begin_run_rifts(20260807)
	game.world.spawn_rift_near(game.player.global_position)
	game.clock.set_night_raw(false)
	game.clock.set_phase_elapsed_raw(GameTuning.STAGE_DAY_DURATION[game.clock.stage_index()] * 0.42)
	game._apply_stage_grade()
	game.canvas_modulate.color = GameTuning.STAGE_DAY_MODULATE[game.clock.stage_index()]
	game.world.set_night_amount(0.0)
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = true
	game.player_cycle.reloading = false
	game.player_cycle.reload_remaining = 0.0
	game.player_cycle.exec_counts.assign([2, 2, 1, 1, 0])
	game.player_cycle.current_index = 3
	game.player_cycle.current_reentry = 0
	game._update_cycle_rail(4.0)
	game._on_rail_rune_fired("jump_one", 1)
	game._on_rail_slot_entered(3, 0)
	game._update_cycle_rail(0.0)
	game._update_hud()
	_capture_paint_edge_nav()

	# ---- 컷 7(Y6 신설): 발견 화살표 · 필드 사건 표식 · 소비 칸 -------------
	# 검수 기준 세 줄:
	#   ① **보스문 화살표가 없다.** 아직 안 가 본 곳이다(발견 기반 내비의 증거).
	#      성·캠프 화살표는 있다 — 처음부터 발견 상태이기 때문이다(§6.1).
	#   ② 필드 한가운데 **사건 표식**(고리 + 실루엣)이 서 있고 그 화살표가 켜져 있다.
	#   ③ 좌하단에 **Q 키캡 + 글리프 + 이름**. 판이 없어야 한다(hud_block_pct 계약).
	get_tree().paused = false
	game.discovered_features.erase("boss_gate")
	game._reset_stage_events()
	# 표식 하나는 **화면 안**(그림을 보여 준다), 다른 하나는 **화면 밖**에 둔다
	# — 화살표는 대상이 화면 안에 들면 숨으므로, 가까운 것만 두면 컷에 화살표가 없다.
	var showcase_id := "%sqa_0" % game.EVENT_CAMP_PREFIX
	var showcase_at: Vector2 = game.player.global_position + Vector2(-250.0, 150.0)
	var far_id := "%sqa_1" % game.EVENT_CAMP_PREFIX
	var far_at: Vector2 = game.player.global_position + Vector2(1500.0, -760.0)
	game.stage_events.append({
		"id": showcase_id, "type": "dungeon", "position": showcase_at,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game.stage_events.append({
		"id": far_id, "type": "semi_elite", "position": far_at,
		"reveal_dwell": 0, "state": "ready", "remaining": 0, "wave": 0, "waves": 0})
	game.mark_discovered(showcase_id, "")
	game.mark_discovered(far_id, "")
	# 표식이 몹에 가려지지 않게 근처 잡몹만 잠깐 걷는다(컷 전용 · 다음 컷에서 되돌아온다).
	for mob in game.combat.active_enemies.duplicate():
		if is_instance_valid(mob) and not mob.is_boss \
				and mob.global_position.distance_to(showcase_at) < 220.0:
			mob.queue_free()
	game._refresh_event_marks()
	game.consumable_item = "map"
	await get_tree().create_timer(0.3).timeout
	get_tree().paused = true
	game._update_hud()
	if is_instance_valid(game.active_banner):
		game.active_banner.queue_free()
	game.active_banner = null
	_capture_paint_edge_nav()
	await _save_capture_png("hud-y6-discovery.png")

	# ---- 컷 8(Y7 신설): 타격 반응 네 종을 **한 프레임에** 세운다 -------------
	# 타격감은 움직임이라 정지 캡처로는 안 보인다 — 그래서 반응 상태를 심고
	# **트리를 멈춘 채로** 찍는다. 상태가 그림을 만드는 구조라 그대로 남는다.
	# 검수 기준 네 줄:
	#   ① 왼쪽 위습이 **크게 튕겨 있고**(kb 2.0) 오른쪽 오우거는 **거의 안 밀렸다**(0.25)
	#   ② 가운데 임프가 **공중에 떠 있다**(pop · 발밑 그림자와 몸 사이가 벌어진다)
	#   ③ 둔화 배지가 머리 위에 뜬다 — 고정 둔화는 **청록**, 점점 느려짐은 **보라**
	#   ④ 몹마다 파편이 다르다(이끼 조각 / 흙먼지 / 뼈 조각 / 발톱 자국)
	get_tree().paused = false
	game._reset_stage_events()
	game.consumable_item = ""
	game.mark_discovered("boss_gate", "")
	for mob in game.combat.active_enemies.duplicate():
		if is_instance_valid(mob) and not mob.is_boss:
			mob.queue_free()
	game.combat.active_enemies.clear()
	game.combat.enemy_spatial.clear()
	await get_tree().create_timer(0.25).timeout
	var showcase: Array[Dictionary] = [
		{"kind": "wisp", "behavior": 3, "at": Vector2(-210.0, -30.0), "impact": "push"},
		{"kind": "mossling", "behavior": 1, "at": Vector2(-70.0, 60.0), "impact": "slow"},
		{"kind": "imp", "behavior": 3, "at": Vector2(70.0, -40.0), "impact": "pop"},
		{"kind": "skeleton", "behavior": 2, "at": Vector2(200.0, 55.0), "impact": "rush"},
		{"kind": "ogre", "behavior": 2, "at": Vector2(330.0, -20.0), "impact": "push"}
	]
	var showcase_mobs: Array[Node] = []
	for entry: Dictionary in showcase:
		var at: Vector2 = game.player.global_position + (entry["at"] as Vector2)
		var mob := game.combat.spawn_enemy_instance(at, int(entry["behavior"]), "",
			false, "", false, String(entry["kind"]), true)
		if not is_instance_valid(mob):
			continue
		mob.global_position = at
		mob.aggro = false
		mob.raid_mode = false
		showcase_mobs.append(mob)
	game.combat.rebuild_enemy_spatial()
	await get_tree().create_timer(0.2).timeout
	get_tree().paused = true
	for index in showcase_mobs.size():
		var mob: DebtEnemy = showcase_mobs[index]
		if not is_instance_valid(mob):
			continue
		var impact := String((showcase[index] as Dictionary)["impact"])
		mob.apply_hit_reaction(game.player.global_position, 260.0, 0.12, impact)
		mob.apply_impact_time_effect(impact)
		mob.hit_recoil = 1.0
		mob.hit_flash = 0.0        # 흰 섬광이 덮으면 파편 색이 안 읽힌다(컷 전용)
		# ⚠️ 걸린 **직후**는 진행도가 0이라 체공 높이도 0이고 배지도 첫 칸이다 —
		#    그 프레임을 찍으면 "떠 있다"와 "안 떠 있다"가 그림에서 같아진다(실측).
		#    그래서 타이머를 절반쯤 흘려 **한복판**을 세운다(컷 전용 · 트리는 멈춰 있다).
		if mob.airborne_total > 0.0:
			mob.airborne_timer = mob.airborne_total * 0.5
		if mob.cycle_slow_timer > 0.0:
			mob.cycle_slow_timer *= 0.55 if mob.cycle_slow_ramp else 0.6
		mob.queue_redraw()
	# 플레이어 쪽 가속 배지(행 1 = 빠름)도 같은 컷에 넣는다.
	game.player.apply_haste()
	game.player.haste_timer = SurvivorPlayer.HASTE_SECONDS * 0.5
	game.player.queue_redraw()
	game._update_hud()
	if is_instance_valid(game.active_banner):
		game.active_banner.queue_free()
	game.active_banner = null
	_capture_paint_edge_nav()
	await _save_capture_png("hud-y7-impact.png")

	# 대표 컷은 다시 순수 필드로 돌려 둔다(사건 표식·반응 상태가 대표 컷을 먹지 않게).
	get_tree().paused = false
	for mob in showcase_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	game.combat.active_enemies.clear()
	game.combat.enemy_spatial.clear()
	game.player.haste_timer = 0.0
	game.player.haste_multiplier = 1.0
	await get_tree().create_timer(0.35).timeout
	get_tree().paused = true
	game._update_hud()
	_capture_paint_edge_nav()

## 캡처 전용 — 화살표 내비를 한 프레임 강제로 그린다.
## `_update_edge_nav()`는 `state == "playing"`에서만 켜지는데 캡처는 화면을 멈추려고
## state를 "preview"로 돌려 두므로, 그대로 두면 QA 컷에서 화살표가 통째로 빠진다.
func _capture_paint_edge_nav() -> void:
	var saved := game.state
	game.state = "playing"
	game._update_edge_nav()
	game.state = saved

# =============================================================================
# --capture-rail (W6 신설 · X2 전면 갱신) — ESC 편집 화면 4컷
# =============================================================================
# X2 완료 기준(사용자 피드백 ⑤): 5칸 무스크롤 · **상시 문장 0줄** · 카드 그림이 크고
# 원소색으로 물들어 있다 · 바늘 화살표와 되돌이 선으로 "한 바퀴"가 보인다 ·
# 보관함은 그림 격자 · 장비는 부위 글리프 · **세부는 전부 호버 툴팁**.
#
# 검수 기준 한 줄 — **중학생 3초 테스트**: 처음 보는 사람이 이 캡처만 보고
#   ① 5칸이 순서대로 돌고 ② 카드를 끌어 넣고 ③ 각인이 칸에 붙어 있다
# 를 알아차릴 수 있는가.
func _setup_rail_capture_deck() -> void:
	game._start_game()
	await get_tree().create_timer(0.4).timeout
	# X2: 네 칸을 **서로 다른 원소 네 계**로 채운다(화·빙·뇌·유). 원소색이 카드 프레임과
	# 아이콘 블록을 물들이는 것이 X2의 핵심 그림인데, 예전 덱(화·타·뇌·타)은 따뜻한 색과
	# 무채만 있어 캡처 한 장에서 "속성 = 색"이 갈리는지 확인할 수 없었다(실측).
	game.factory.place_card(0, DealCardLibrary.instance("flame_field", 2))
	game.factory.place_card(1, DealCardLibrary.instance("frost_ring", 1))
	game.factory.place_card(2, DealCardLibrary.instance("thunder", 3))
	game.factory.place_card(3, DealCardLibrary.instance("gravity_well", 1))
	# 흐름 아크가 회귀·도약·재실행 3색으로 전부 나오게 배치한다.
	game.factory.attach_rune(0, RuneEngine.roll_rune("jump_one", game.rng))
	game.factory.attach_rune(1, RuneEngine.roll_rune("strong", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("back_one", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("twice", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("first_hit", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("strong", game.rng))
	game.factory.attach_rune(3, RuneEngine.roll_rune("back_one", game.rng))
	# Y2: 레일 각인 2개를 얹어 편집 화면의 **레일 각인 글리프 줄**(구 결속 띠 자리)이
	# 빈 유령이 아니라 실제로 채워진 그림으로 찍히게 한다(§2.5 표시 규약 검수).
	game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_fast", game.rng))
	game.factory.attach_rail_rune(RuneEngine.roll_rune("rail_loop", game.rng))
	game.factory.equip(ItemLibrary.instance("u_greatsword_01"))
	game.factory.equip(ItemLibrary.instance("r_ring_02"))
	for skill_id in ["moon_barrier", "meteor_blade", "time_cut"]:
		game.factory.add_inventory(DealCardLibrary.instance(skill_id, 1))
	game.factory.add_inventory(ItemLibrary.instance("h_neck_01"))
	game._reset_player_cycle()

func _run_rail_capture() -> void:
	await _setup_rail_capture_deck()
	# ---- 컷 1: 기본 화면 — 이것이 X2의 대표 그림이다(상시 문장 0줄) ----
	game.factory_edit_mode = game.EDIT_MODE_CARD
	game.factory_pick_slot = -1
	game._show_factory_menu("edit", {}, "playing")
	await get_tree().create_timer(0.5).timeout
	await _save_capture_png("rail-x2-overview.png")
	# ---- 컷 2: 칸 손잡이 호버 — "이걸 끌면 각인까지 통째로 간다" ----
	# 캡처에서는 마우스를 움직일 수 없으므로 툴팁을 강제로 띄운다(사람이 호버했을 때와
	# **같은 경로**다 — `TooltipLayer.force()`는 지연만 건너뛴다).
	game._force_factory_tooltip("slot2_handle")
	await get_tree().create_timer(0.35).timeout
	await _save_capture_png("rail-x2-tip-slot.png")
	# ---- 컷 3: 한 바퀴 요약 호버 — 몬테카를로 지표 7종 + 궤적이 전부 여기 있다 ----
	game._show_factory_menu("edit", {}, "playing")
	await get_tree().process_frame
	game._force_factory_tooltip("summary")
	await get_tree().create_timer(0.35).timeout
	await _save_capture_png("rail-x2-tip-metrics.png")
	# ---- 컷 4: 칸을 집은 상태 — 흰 이중 링으로 "무엇을 들고 있는지"가 보인다 ----
	game.factory_edit_mode = game.EDIT_MODE_SLOT
	game.factory_pick_slot = 2
	game._show_factory_menu("edit", {}, "playing")
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("rail-x2-pick.png")
	# ---- 컷 5(Y4 신설): 장비 교체 확인 「바꾸기 / 그대로」 (피드백 ⑫) ----
	# 새 화면이라 육안 검수 대상이다 — 두 카드가 나란히, 부위 이름이 크게,
	# 버튼이 둘뿐인가(중학생 3초).
	game.factory_pick_slot = -1
	game.factory_edit_mode = game.EDIT_MODE_CARD
	game.factory.equipment.clear()
	game.factory.equip(ItemLibrary.instance("r_rapier_01"))
	game.factory.add_inventory(ItemLibrary.instance("u_greatsword_01"))
	game._show_factory_menu("edit", {}, "playing")
	await get_tree().process_frame
	game.factory_selected_inventory = game.factory.inventory.size() - 1
	# `automated_test`에서는 확인 화면이 다음 유휴 프레임에 스스로 「바꾸기」를 누른다.
	# 캡처는 그 전에 찍고, 찍은 뒤 「그대로」로 닫아 대표 컷을 오염시키지 않는다.
	game.automated_test = false
	game._editor_equipment_pressed(FactoryDeck.EQUIPMENT_PARTS.find("weapon"))
	await get_tree().create_timer(0.4).timeout
	await _save_capture_png("rail-y4-equip-swap.png")
	game._cancel_equip_swap()
	game.automated_test = true
	# 대표 컷은 기본 상태로 되돌린다(_run_visual_capture 꼬리가 찍는다).
	game._show_factory_menu("edit", {}, "playing")
	await get_tree().process_frame

# =============================================================================
# --capture-draft (W6 신설) — 각인 드래프트 2단계
# =============================================================================
func _run_draft_capture() -> void:
	await _setup_rail_capture_deck()
	game.xp_target = 1000000
	# ---- 컷 1: 1단계 각인 3택 ----
	game._show_rune_draft("level", "playing")
	await get_tree().create_timer(0.45).timeout
	await _save_capture_png("draft-minimal-v2-p1.png")
	# ---- 컷 2: 2단계 「어느 칸에 붙일까요?」 (Y3 전면 재작성 · 글자 0줄) ----
	# ⚠️ 3택이 전부 레일 각인일 수 있다. 레일은 2단계가 없으므로(§2.2) 그대로 고르면
	#    이 컷이 **1단계 화면을 다시 찍는다.** 칸 각인 제시분이 들 때까지 다시 연다.
	var capture_offer := _open_slot_rune_draft("level", "playing")
	if capture_offer < 0:
		capture_offer = 0
	await get_tree().create_timer(0.3).timeout
	game._select_draft_rune(capture_offer)
	await get_tree().create_timer(0.35).timeout
	await _save_capture_png("draft-minimal-v2-p2.png")
	# ---- 컷 2': 칸 호버 — **지운 여덟 줄이 어디로 갔는가**의 증거(X2 선례) ----
	# 검수 기준: Δ 4개 · 바퀴 상한 · 붙이면 · 각인 목록이 툴팁 한 장에 전부 있는가.
	if game._force_modal_tooltip("target_slot0"):
		await get_tree().create_timer(0.35).timeout
		await _save_capture_png("draft-y3-tip-slot.png")
		UIKit.tooltip_hide(game.modal_tooltip_layer)
	# ---- 컷 3: 스택 상한 칸이 "선택 불가"로 회색 처리된 상태 ----
	while game.factory.rune_count_on(4) > 0:
		game.factory.detach_rune(4, 0)
	for fill_index in RuneEngine.RUNE_STACK_CAP:
		game.factory.attach_rune(4, RuneEngine.roll_rune("strong" if fill_index < 3 else "wide", game.rng))
	game._show_rune_target()
	# 모달 등장 연출(_animate_modal)이 끝난 뒤 찍어야 실제 화면 밝기로 확인할 수 있다.
	await get_tree().create_timer(0.4).timeout
	await _save_capture_png("draft-minimal-v2-p3.png")
	# 대표 컷은 1단계로 되돌린다.
	game._build_rune_draft_screen()
	await get_tree().create_timer(0.4).timeout

# =============================================================================
# --capture-choice (U2 신설 · **X1 재구성** 3컷 → 5컷) — 레벨 업 2택 + 취소
# =============================================================================
# 사용자가 두 웨이브 연속으로 이름을 대고 지목한 화면이다("레벨업 UI" → "③ 레벨업
# 모달 대개편 · 최우선").
#
# X1 검수 기준 (U2의 "층위·립·의미색"에 더해):
#   ① **읽을 게 확 줄었는가** — 카드당 글자 줄이 이름 1 + 설명 1 + 칩 2로 끝나는가.
#      태그 줄·피해계수·범위·한 바퀴 빚이 한 글자도 없어야 한다.
#   ② **이미지가 주인공인가** — 아이콘 152px가 카드 면적의 가장 큰 덩어리인가.
#   ③ **속성이 색으로만 말하는가** — 두 카드의 프레임·본문 판·좌상단 마크가 서로
#      다른 원소색이고, 그 색이 HUD 레일 마크와 같은 어휘인가.
#   ④ **취소가 카드보다 낮은 위계인가** — 카드 프레임이 아니라 NEUTRAL 버튼인가.
#   ⑤ **천장 컷**에서 취소에 포커스가 서 있고 보상이 45 G로 할증돼 있는가.
#
#   choice-minimal-v2-level.png      레벨 업 2택 + 취소 (대표 컷)
#   choice-minimal-v2-focus.png      오른쪽 카드로 포커스 이동
#   choice-minimal-v2-cancel.png     취소 버튼 포커스
#   choice-minimal-v2-growthcap.png  성장 천장 — 취소 기본 포커스 · 보상 할증
#   choice-minimal-v2-item.png       아이템 2택(U2 골격 · 무변경 회귀 확인)
func _run_choice_capture() -> void:
	await _setup_rail_capture_deck()
	# `automated_test`면 두 화면 모두 왼쪽을 자동 확정하고 닫힌다(모달이 안 그려진다).
	# 트로피 컷(`_run_castle_capture`)과 같은 규약으로 끈다.
	game.automated_test = false
	game.xp_target = 1000000
	# ---- 컷 1: X1 레벨업 2택 + 취소 (구 "2택 + 각인 강화") ----
	# 검수 기준은 하나다 — **읽을 게 확 줄었는가.** 카드당 글자 줄은 이름 1 + 설명 1 +
	# 칩 2뿐이고, 속성은 프레임·판·좌상단 마크의 색으로만 말한다.
	game._show_skill_choice("level")
	# 검수용으로 **원소가 서로 다른 두 장**을 뽑는다. 같은 원소가 나오면 "속성 = 색"이
	# 제대로 갈리는지 한 장에서 확인할 수 없다(실제 플레이에서는 같은 원소도 정상이다).
	for _retry in 16:
		if game.current_pair.size() == 2 and String(game.current_pair[0].get("element", "")) \
				!= String(game.current_pair[1].get("element", "")):
			break
		game._clear_overlay()
		game.state = "playing"
		game._show_skill_choice("level")
	# 모달 등장 연출(_animate_modal 0.22s)이 끝난 뒤 찍어야 실제 밝기가 나온다.
	await get_tree().create_timer(0.45).timeout
	await _save_capture_png("choice-minimal-v2-level.png")
	# ---- 컷 2: 오른쪽 카드로 포커스를 옮긴 그림(흰 이중 립이 옮겨 가는가) ----
	game._set_choice_index(1)
	await get_tree().create_timer(0.2).timeout
	await _save_capture_png("choice-minimal-v2-focus.png")
	# ---- 컷 3: 취소 버튼에 포커스 — 카드보다 위계가 낮게 보이는가 ----
	game._set_choice_index(game._choice_extra_index())
	await get_tree().create_timer(0.2).timeout
	await _save_capture_png("choice-minimal-v2-cancel.png")
	# ---- 컷 4: 성장 천장 (X1) — 취소가 기본 포커스이고 보상이 할증된 그림 ----
	game._clear_overlay()
	game.state = "playing"
	var cap_slots: Array[String] = ["cleave", "thrust", "thunder", "whirlwind", "rapid_slash"]
	var saved_inventory := game.factory.inventory.duplicate(true)
	game.factory.inventory.clear()
	for slot_index in FactoryDeck.SLOT_COUNT:
		game.factory.place_card(slot_index, DealCardLibrary.instance(cap_slots[slot_index], DealCardLibrary.MAX_RANK))
	game._show_skill_choice("level")
	await get_tree().create_timer(0.45).timeout
	await _save_capture_png("choice-minimal-v2-growthcap.png")
	game._clear_overlay()
	game.state = "playing"
	game.factory.inventory.assign(saved_inventory)
	await _setup_rail_capture_deck()
	# ---- 컷 5: 아이템 2택 (U2 골격 그대로 — X1이 손대지 않았다) ----
	game.state = "playing"
	game._show_item_offer("treasure")
	await get_tree().create_timer(0.45).timeout
	await _save_capture_png("choice-minimal-v2-item.png")
	# 대표 컷은 레벨업으로 되돌린다.
	game._clear_overlay()
	game.state = "playing"
	game._show_skill_choice("level")
	await get_tree().create_timer(0.4).timeout
	game.automated_test = true

# =============================================================================
# --capture-guide (U3 신설) — 스포트라이트 길잡이 3컷
# =============================================================================
# 확인할 것 — ① 스크림 위 **구멍 경계**가 1px 밝은 금 없이 떨어지는가
#             ② 안내문(제목 17 · 본문 13)이 어두운 SLATE 판 위에서 읽히는가
#             ③ 킷 키캡 실물(WASD / SPACE / E)이 나란히 서는가
#             ④ 안내판이 구멍을 피해 **위·아래 두 자리**를 오가는가
# 대표 컷(guide-minimal-v2.png)은 5칸 레일 스텝이다 — "공격 버튼은 없다"가 이 길잡이의
# 핵심 문장이고, 필드 HUD 킷 교체 결과도 그 한 장에서 같이 검수된다.
func _run_guide_capture() -> void:
	game.automated_test = true
	var saved_guide_seen: bool = game.guide_seen
	game.guide_seen = false
	game._start_game()
	await get_tree().create_timer(0.5).timeout
	# 레일이 빈칸만 있으면 컷 ②가 아무것도 안 보여 준다. 카드와 각인을 채워 둔다.
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
	game.factory.place_card(1, DealCardLibrary.instance("thunder", 1))
	game.factory.place_card(2, DealCardLibrary.instance("flame_field", 3))
	game.factory.attach_rune(1, RuneEngine.roll_rune("back_one", game.rng))
	game.rejected_skills.assign(["cleave", "rapid_slash", "thunder", "meteor_blade", "moon_barrier", "recursion"])
	game.demon_lord.sync_runes(game.rng)
	game._reset_player_cycle()
	game.player_cycle.exec_counts.assign([2, 1, 1, 0, 0])
	game.player_cycle.reload_debt = 1.35
	game._update_cycle_rail(0.0)
	game._update_hud()
	# X4: 켜기 직전의 필드 인구와 시계를 떠 둔다. 아래 관찰 줄이 "실창에서 정말로
	# 멈췄는가"를 사람 눈이 아니라 숫자로 남긴다(캡처는 판정하지 않으므로 증거만 남긴다).
	var field_before: int = game.combat.active_enemies.size()
	var phase_before: float = game.clock.phase_elapsed
	game._start_guide()
	# 켤 때 1회성 페이드(GUIDE_FADE 0.18s)와 스텝 페이드(0.14s)가 **끝난 뒤**에 찍는다.
	# 안 기다리면 스크림 알파가 0.2쯤인 상태로 찍혀 "어둡게 처리"가 캡처에 안 나온다.
	await get_tree().create_timer(0.35).timeout
	# ---- X4 실창 관찰: 2초를 그냥 흘려 보내고 세계가 정말 멈춰 있는지 본다 ----
	await get_tree().create_timer(2.0).timeout
	print("GUIDE_FREEZE_OBSERVED field_before=%d field_now=%d cleared=%d frozen=%d phase_drift=%.3f invuln=%.2f" % [
		field_before, game.combat.active_enemies.size(), game.guide_cleared_threats,
		game.guide_frozen_count(), absf(game.clock.phase_elapsed - phase_before),
		game.player.invulnerability])

	# ---- 컷 1: ① 이동(WASD) — 구멍이 **플레이어**를 문다 · 안내판은 위 자리 ----
	await _save_capture_png("guide-minimal-v2-move.png")

	# ---- 컷 2: ③ 5칸 미니 스트립 — 구멍이 하단 스트립의 칸 다섯을 문다 · 안내판은 위 ----
	game.guide_step = 2
	game._apply_guide_step()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("guide-minimal-v2-rail.png")

	# ---- 컷 3(X3 갱신): ⑥ **가장자리 화살표** + E ----
	# 구 나침반 패널 컷의 후신이다. 구멍이 링 위 화살표 하나를 물고, 안내판은
	# 그 화살표가 화면 위쪽이면 아래로 뒤집힌다(같은 규약 · 좌표만 동적).
	game.guide_step = 5
	game._apply_guide_step()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("guide-x3-nav.png")

	# ---- 컷 4: ESC 확인 칩(전체 스킵 직전) ----
	game.guide_step = 3
	game._apply_guide_step()
	game.guide_confirm = true
	game._paint_guide_confirm()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("guide-minimal-v2-confirm.png")

	# 대표 컷은 5칸 레일로 되돌린다(_run_visual_capture 꼬리가 찍는다).
	game.guide_confirm = false
	game.guide_step = 2
	game._apply_guide_step()
	await get_tree().create_timer(0.25).timeout
	# 캡처가 사람의 실기 설정을 건드리면 안 된다 — 원래 값으로 되돌려 놓는다.
	game.guide_seen = saved_guide_seen

# =============================================================================
# --capture-castle (W9 신설 · V8 갱신) — 성 내부 5컷
# =============================================================================
# 성 안에는 v3 NPC 4종만 서 있어야 하고(방 컷), 세 전용 화면과 **보스 트로피 2택1**이
# 전부 사람 눈에 읽혀야 한다. 대표 캡처(castle-minimal-v2.png)는 방 컷으로 남긴다.
#   castle-minimal-v2-pact.png    계약자 — dwell 3에서 세 거래가 전부 열린 그림(V3-J)
# V8이 갈아끼운 컷: `castle-minimal-v2-lineage.png` → `castle-minimal-v2-trophy.png`
func _run_castle_capture() -> void:
	game.automated_test = false   # 트로피 2택1을 실제로 그리게 한다(자동 확정 금지)
	game._start_game()
	await get_tree().create_timer(0.4).timeout
	game.gold = 999
	game.factory.place_card(0, DealCardLibrary.instance("shield_bash", 2))
	game.factory.place_card(1, DealCardLibrary.instance("moon_barrier", 1))
	game.factory.place_card(3, DealCardLibrary.instance("thunder", 1))
	game.factory.attach_rune(0, RuneEngine.roll_rune("strong", game.rng))
	game.factory.add_inventory(DealCardLibrary.instance("holy_pulse", 1))
	game.factory.add_inventory(DealCardLibrary.instance("holy_pulse", 1))
	game.rejected_skills.assign(["cleave", "cleave", "rapid_slash", "thunder", "meteor_blade", "moon_barrier"])
	game.demon_lord.sync_runes(game.rng)
	var starter: Dictionary = game.world.get_nearest_interactable(game.world.get_castle_position(), 120.0)
	game._enter_castle_now(starter)
	# NPC 4명은 y = -95 / -175에 선다. 카메라가 플레이어를 따라가므로 플레이어를 방
	# 가운데 위쪽에 두어야 NPC 이름표가 HUD 밑으로 들어가지 않는다.
	game.player.global_position = Vector2(0.0, -40.0)
	var camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	game._refresh_castle_interactable()
	# 입장 배너가 NPC 이름표를 가리므로 걷어낸다(검수용 컷이다).
	if is_instance_valid(game.active_banner):
		game.active_banner.queue_free()
	game.active_banner = null
	# ---- 컷 1: 성 내부 · NPC 4종 배치 ----
	await get_tree().create_timer(0.35).timeout
	await _save_capture_png("castle-minimal-v2-room.png")
	# ---- 컷 2: 각인 세공사 — Y3 **한 창구 한 가지** ----
	# 검수 기준: ① 세 장이 카드 상점과 같은 문법으로 서는가 ② 값표(GOLD 칩)가
	# 희귀도 칩과 한 줄에 나란한가 ③ **칸 / 레일 배지**가 카드에서 크게 읽히는가
	# ④ 하단에 버튼이 「닫기」 **하나**뿐이고 새로고침이 진열대 위에 있는가
	# ⑤ 보유 골드가 오른쪽 위에 **숫자 하나**로 크게 서는가(「각인 N개」 병기 없음).
	game._show_rune_shop()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("castle-minimal-v2-rune-shop.png")
	# ---- 컷 2': 새로고침 직후 — 진열이 갈리고 다음 리롤 값이 올랐는가 ----
	game._refresh_rune_shop()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("castle-minimal-v2-rune-reroll.png")
	game._close_base_camp()
	# ---- 컷 3: 계약자 ----
	# dwell 0이면 "정비"가 게이트에 막혀 회색이다. 세 거래가 다 열린 그림을 찍는다.
	game.clock.set_dwell_raw(3)
	game._show_pact_service()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("castle-minimal-v2-pact.png")
	game._close_base_camp()
	# ---- 컷 4: 밀정 — Y3 리뉴얼 ----
	# 검수 기준: ① 마왕 초상이 상단에 있는가 ② 5칸이 **내 딜싸이클과 같은 그림**인가
	# ③ 각인 이름이 **처음부터** 보이는가(「미열람」이 없다) ④ 버튼이 두 개(지우기·닫기)인가.
	game._show_spy_service()
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("castle-minimal-v2-spy.png")
	game._close_base_camp()
	# ---- 컷 5: V8 보스 트로피 2택1 (구 "1차 각성 계보 3종 택1" 자리) ----
	# 3스테이지 트로피(홍염 천구의 깃 · 상급)를 고른다 — 고정 보너스 문구와 2택1 카드가
	# 한 화면에 같이 나와야 "①은 이미 받았고 ②만 고른다"가 눈으로 읽힌다.
	game.state = "playing"
	get_tree().paused = false
	game.player.restore_trophies([1, 2])
	game.clock.set_stage_raw(3)
	game.pending_stage_trophy = {
		"stage": 3, "design": "C", "enhanced": false, "descended": false,
		"day": game.clock.day_number, "dwell": game.clock.dwell
	}
	game.pending_trophy_followup = ""
	game._open_stage_trophy_choice()
	await get_tree().create_timer(0.6).timeout
	await _save_capture_png("castle-minimal-v2-trophy.png")
	# 대표 컷은 성 내부 방으로 되돌린다.
	game.state = "castle_interior"
	game.pending_stage_trophy.clear()
	game.pending_trophy.clear()
	game._clear_overlay()
	get_tree().paused = false
	game._refresh_castle_interactable()
	await get_tree().create_timer(0.3).timeout

# =============================================================================
# --capture-boss (V7 재작성) — 보스방 전투 · telegraph · C+ 변신 · 마왕 직행
# =============================================================================
# W10판은 마왕전 3컷(전조 보상 · 프리뷰 · RELOAD)이었다. v3의 검수 대상은 **스테이지
# 보스 3종**이므로 컷 구성을 통째로 바꾼다. 저장되는 PNG:
#
#   boss-minimal-v2-preview.png    1스테이지 프리뷰 — 내 5칸 vs 보스 3칸
#   boss-minimal-v2-a.png          A 서릿발 외눈 전투(3칸 · 서리 링 telegraph · 발구름)
#   boss-minimal-v2-telegraph.png  telegraph 링 3행이 한 화면에 — expand / charge / pool
#   boss-minimal-v2-b.png          B 역병 점액왕(도약 · 독 장판 · 분열체)
#   boss-minimal-v2-c-trans.png    **C+ 흑천구 등장 연출(Trans 11프레임)**
#   boss-minimal-v2-enhanced.png   C+ 전투 — 레일이 4칸, 과열 사다리 없음
#   boss-minimal-v2-reload.png     반격 창(RELOAD)이 열린 순간
#   boss-minimal-v2-descent.png    강림 밸브 — 필드에 내려온 보스(프리뷰 없음)
#   boss-minimal-v2-demon.png      5스테이지 격파 직후 마왕 프리뷰(필드 복귀 없음)
#   boss-minimal-v2.png            대표 컷 = C+ 전투(마지막 상태 그대로 저장된다)
## 보스 스프라이트 컷 공통 준비. **피격 섬광(흰 마스크 α0.7)이 덮으면 시트 색이 안 읽힌다** —
## 육안 검수의 목적이 "외눈이 청록인가 / 천구가 붉은가"이므로 캡처 직전에 섬광을 끈다.
func _boss_capture_freeze() -> void:
	if is_instance_valid(game.stage_boss):
		game.stage_boss.hit_flash = 0.0
		game.stage_boss.queue_redraw()
	get_tree().paused = true
	await get_tree().process_frame

func _run_boss_capture() -> void:
	game._start_game()
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(game.player):
		game.player.invulnerability = 99999.0
		game.player.max_health = 4000.0
		game.player.health = game.player.max_health
	# 내 5칸 — 비교 대상이 비어 있으면 프리뷰의 의미가 없다.
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
	game.factory.place_card(1, DealCardLibrary.instance("thunder", 1))
	game.factory.place_card(2, DealCardLibrary.instance("flame_field", 3))
	game.factory.place_card(3, DealCardLibrary.instance("rapid_slash", 1))
	game.factory.attach_rune(0, RuneEngine.roll_rune("strong", game.rng))
	game.factory.attach_rune(1, RuneEngine.roll_rune("back_one", game.rng))
	game.factory.attach_rune(3, RuneEngine.roll_rune("jump_one", game.rng))
	game._reset_player_cycle()

	# --- 1컷: 1스테이지 프리뷰(내 5칸 vs 보스 3칸) ---
	game.clock.set_stage_raw(1)
	game.clock.set_dwell_raw(2)
	game.state = "playing"
	game._show_stage_boss_preview()
	await get_tree().create_timer(0.4).timeout
	await _save_capture_png("boss-minimal-v2-preview.png")

	# --- 2컷: A 서릿발 외눈 전투 ---
	game._begin_stage_boss_battle()
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(game.stage_boss):
		game.stage_boss.max_health = 1.0e9
		game.stage_boss.health = game.stage_boss.max_health * 0.72
		game.stage_boss.trigger_boss_stomp(0.42)
	game._update_boss_rail(0.0)
	await _boss_capture_freeze()
	await _save_capture_png("boss-minimal-v2-a.png")
	get_tree().paused = false

	# --- 3컷: telegraph 링 3행을 한 화면에 세운다(육안 대조용) ---
	# 실전에서는 패턴마다 하나씩만 뜨므로 행끼리 비교가 안 된다. 여기서만 나란히 놓는다.
	var ring_colors: Array[Color] = [GamePalette.CYAN, GamePalette.YELLOW, GamePalette.GREEN]
	for row in 3:
		var spot: Vector2 = game.player.global_position + Vector2(-190.0 + float(row) * 190.0, 150.0)
		var ring: Node2D = game._spawn_boss_telegraph(spot, 120.0, row, ring_colors[row], 3.0, 0.0)
		if is_instance_valid(ring):
			# 차오르는 중간 프레임에서 멈춰 세운다(정적 캡처).
			ring.elapsed = 1.7
	await get_tree().create_timer(0.25).timeout
	get_tree().paused = true
	await _save_capture_png("boss-minimal-v2-telegraph.png")
	get_tree().paused = false

	# --- 4컷: B 역병 점액왕(도약 · 독 장판 · 분열체) ---
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.5).timeout
	# V8: 격파는 곧바로 트로피 2택1 → 5칸 배치를 연다. 캡처는 그 흐름을 그대로 소화하고
	# 다음 컷으로 간다(트로피 화면 자체는 `--capture-castle` 컷 5가 검수한다).
	await _consume_stage_trophy(4)
	game.clock.set_stage_raw(2)
	game.stage_boss_cleared = false
	game.state = "playing"
	game._show_stage_boss_preview()
	await get_tree().process_frame
	game._begin_stage_boss_battle()
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(game.stage_boss):
		game.stage_boss.max_health = 1.0e9
		game.stage_boss.health = game.stage_boss.max_health * 0.55
		# 분열체 3기와 독 장판을 강제로 세워 "이 보스가 무엇을 하는가"를 한 컷에 담는다.
		var split_pattern: Dictionary = BossLibrary.patterns("B", false, false)[2]
		game._spawn_stage_boss_summons(split_pattern, game.stage_boss.global_position)
		var pool_pattern: Dictionary = BossLibrary.patterns("B", false, false)[1]
		for index in 3:
			var pool_spot: Vector2 = game.player.global_position + Vector2.from_angle(TAU * float(index) / 3.0) * 150.0
			var pool: Node2D = game._spawn_boss_telegraph(pool_spot, 110.0, 2, GamePalette.GREEN, 0.05, 8.0)
			if is_instance_valid(pool):
				pool.payload = {"card": pool_pattern.duplicate(true), "radius": 110.0}
		StatusEngine.set_status(game.player_status, "poison", {"damage": 30.0, "stacks": 3})
	await get_tree().create_timer(0.6).timeout
	game._update_boss_rail(0.0)
	await _boss_capture_freeze()
	await _save_capture_png("boss-minimal-v2-b.png")
	get_tree().paused = false

	# --- 5컷: C+ 흑천구 등장 연출(Trans 11프레임) ---
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.5).timeout
	await _consume_stage_trophy(4)
	StatusEngine.clear(game.player_status)
	game.clock.set_stage_raw(GameTuning.STAGE_COUNT)
	game.clock.set_stages_cleared_raw(GameTuning.STAGE_COUNT - 1)
	game.clock.set_dwell_raw(2)
	game.stage_boss_cleared = false
	game.state = "playing"
	game._show_stage_boss_preview()
	await get_tree().process_frame
	game._begin_stage_boss_battle()
	# Trans 11f / 12fps = 약 0.92초. 그 한가운데(6번째 프레임 언저리)에서 멈춘다.
	await get_tree().create_timer(0.45).timeout
	get_tree().paused = true
	await _save_capture_png("boss-minimal-v2-c-trans.png")
	get_tree().paused = false

	# --- 6컷: C+ 전투 — 레일 4칸 · 과열 사다리 없음 · 페이즈 2회 ---
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(game.stage_boss):
		game.stage_boss.max_health = 1.0e9
		game.stage_boss.health = game.stage_boss.max_health * 0.60
		StatusEngine.set_status(game.player_status, "oil")
		StatusEngine.set_status(game.player_status, "burn", {"damage": 40.0})
	game._update_boss_rail(0.0)
	game.update_boss_health(game.stage_boss.health, game.stage_boss.max_health, game.stage_boss.shield, game.stage_boss.max_shield)
	await _boss_capture_freeze()
	await _save_capture_png("boss-minimal-v2-enhanced.png")
	get_tree().paused = false

	# --- 7컷: 반격 창(RELOAD) ---
	if is_instance_valid(game.stage_boss_cycle):
		game.stage_boss_cycle.reloading = true
		game.stage_boss_cycle.reload_duration = 1.42
		game.stage_boss_cycle.reload_remaining = 1.05
	game._update_boss_rail(0.0)
	game.update_boss_health(game.stage_boss.health, game.stage_boss.max_health, game.stage_boss.shield, game.stage_boss.max_shield)
	await _save_capture_png("boss-minimal-v2-reload.png")
	if is_instance_valid(game.stage_boss_cycle):
		game.stage_boss_cycle.reloading = false
		game.stage_boss_cycle.reload_remaining = 0.0

	# --- 8컷: 마왕 직행 — 5스테이지 격파 직후 프리뷰가 그대로 열린다 ---
	game.rejected_skills.assign(["cleave", "cleave", "rapid_slash", "thunder", "thunder", "meteor_blade", "moon_barrier", "execution", "gravity_well", "time_cut"])
	game.boss_items.assign(["u_greatsword_01", "r_ring_02", "h_neck_01"])
	game.demon_lord.rune_shards = 6
	game.demon_lord.sync_runes(game.rng)
	game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.7).timeout
	# V8: **5스테이지 트로피가 마왕전보다 먼저 온다.** 배치를 끝내야 마왕 프리뷰가 열린다
	# (필드는 여전히 한 프레임도 보이지 않는다 — 모달이 계속 화면을 덮는다).
	await _consume_stage_trophy(4)
	await get_tree().create_timer(0.3).timeout
	await _save_capture_png("boss-minimal-v2-demon.png")
	if game.state == "boss_preview":
		game._cancel_boss_preview()
	await get_tree().create_timer(0.2).timeout

	# --- 9컷: 강림 밸브 — 프리뷰 없이 필드에 내려온 보스 ---
	game._start_game()
	await get_tree().create_timer(0.4).timeout
	game.player.invulnerability = 99999.0
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
	game.factory.place_card(1, DealCardLibrary.instance("thunder", 1))
	game._reset_player_cycle()
	game.clock.set_stage_raw(3)
	game.state = "playing"
	game.clock.set_dwell_raw(game.clock.descent_threshold())
	await get_tree().create_timer(1.3).timeout
	game._update_boss_rail(0.0)
	await _boss_capture_freeze()
	await _save_capture_png("boss-minimal-v2-descent.png")
	get_tree().paused = false

	# 대표 컷은 다시 C+ 전투로 되돌린다 — 4칸 레일 + telegraph가 v3 보스전의 얼굴이다.
	if is_instance_valid(game.stage_boss):
		game.stage_boss.take_damage(1.0e12, game.player.global_position)
	await get_tree().create_timer(0.5).timeout
	await _consume_stage_trophy(4)
	game.clock.set_stage_raw(GameTuning.STAGE_COUNT)
	game.stage_boss_cleared = false
	game.state = "playing"
	game._show_stage_boss_preview()
	await get_tree().process_frame
	game._begin_stage_boss_battle()
	await get_tree().create_timer(1.8).timeout
	if is_instance_valid(game.stage_boss):
		game.stage_boss.max_health = 1.0e9
		game.stage_boss.health = game.stage_boss.max_health * 0.48
		game.update_boss_health(game.stage_boss.health, game.stage_boss.max_health, game.stage_boss.shield, game.stage_boss.max_shield)
	game._update_boss_rail(0.0)

# =============================================================================
# --capture-result (W10 재작성) — 승리 / 패배 2컷
# =============================================================================
func _run_result_capture() -> void:
	game._start_game()
	await get_tree().create_timer(0.4).timeout
	# 7일 여정을 실제로 걸어온 것처럼 상태를 채운다(타임라인·지표가 전부 켜지도록).
	var result_slot := 1
	for skill_id in ["cleave", "rapid_slash", "thunder"]:
		game.factory.place_card(result_slot, DealCardLibrary.instance(skill_id, 2))
		game.factory.attach_rune(result_slot, RuneEngine.roll_rune("strong", game.rng))
		result_slot += 1
	game.factory.place_card(0, DealCardLibrary.instance("time_cut", 3))
	game.factory.attach_rune(0, RuneEngine.roll_rune("back_one", game.rng))
	game.factory.attach_rune(2, RuneEngine.roll_rune("jump_one", game.rng))
	game.factory.equip(ItemLibrary.instance("r_rapier_01"))
	game.rejected_skills.assign(["cleave", "thunder", "moon_barrier", "meteor_blade", "execution", "gravity_well", "blade_fan", "rapid_slash"])
	game.boss_items.assign(["u_greatsword_01", "r_ring_02"])
	game.demon_lord.rune_shards = 4
	game.demon_lord.sync_runes(game.rng)
	game.demon_lord.strip_rune(1)
	game.demon_lord.strip_rune(3)
	game.level = 12
	game.kills = 184
	game.run_peak_steps = 7
	game.boss_reload_windows = 9
	game.blight_active = true
	game.blight_marked = 41
	# V8: v3 결과 화면은 **다섯 관문 + 트로피 + 시너지**를 본다. 승리 컷이 등급 A(17일 이하)로
	# 읽히도록 총 일수를 16으로 두고, 관문 4개를 넘어 5관문에 서 있는 상태를 만든다.
	game.clock.set_day_raw(16)
	game.clock.set_night_raw(false)
	game.clock.set_phase_elapsed_raw(31.0)
	game.clock.set_stage_raw(GameTuning.STAGE_COUNT)
	game.clock.set_stages_cleared_raw(GameTuning.STAGE_COUNT - 1)
	game.clock.set_dwell_raw(3)
	game.growth_cap_conversions = 2
	game.run_synergy_triggers = 137
	# 상태이상 지표는 `combat_resolver`의 런 스코프 계측값을 그대로 읽는다(V8 무수정).
	game.combat.status_reactions_fired = 412
	game.combat.status_dot_ticks = 1893
	if is_instance_valid(game.player):
		game.player.restore_trophies([1, 2, 3, 4])
	for rift_index in 2:
		game.rift_states["rift_%d" % rift_index] = {"activated": true, "remaining": 0, "cleared": true}
	# --- 1컷: 패배 ---
	game._show_result(false)
	await get_tree().create_timer(0.45).timeout
	await _save_capture_png("result-minimal-v2-lost.png")
	# --- 2컷(대표): 승리 ---
	# ⚠️ Y4(FEEDBACK_Y §12 추측 4): 지금까지 **승리 컷은 이름 없는 대표 컷**으로만
	#    남아서, 「결과 화면이 깨진다」는 피드백 ㉔을 승리 상태에서 확인한 사람이 없었다.
	#    (설계 문서가 "실제 깨진 스크린샷을 보지 않았다"고 적어 둔 그 자리다.)
	#    이제 승리 컷도 **자기 이름**으로 남는다 — 무대 창 수리의 검수 대상이다.
	game._show_result(true)
	await get_tree().create_timer(0.45).timeout
	await _save_capture_png("result-y4-won.png")

func _save_capture_png(file_name: String) -> int:
	var directory := ProjectSettings.globalize_path("res://art/screenshots/qa")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(file_name)
	await get_tree().process_frame
	await get_tree().process_frame
	# ⚠️ Y3: 창이 포커스를 잃거나 다른 Godot 인스턴스가 떠 있으면 macOS 비headless에서
	#    **뷰포트 텍스처가 갱신되지 않아 모든 컷이 같은 프레임으로 저장된다**
	#    (FEEDBACK_Y 리스크 ⑧ "컷이 프레임을 흘린다" — 실제로 17컷 중 고유 5장이 나왔다).
	#    한 번 강제로 그리고 나서 읽으면 그 창 상태와 무관하게 지금 화면이 남는다.
	RenderingServer.force_draw()
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("VISUAL_CAPTURE_PAGE name=%s path=%s error=%d" % [file_name, path, error])
	return error

func _run_choice_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.25).timeout
	game._show_skill_choice("level")

func _run_boss_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.rejected_skills.assign(["cleave", "cleave", "rapid_slash", "thunder", "meteor_blade", "moon_barrier", "recursion", "execution"])
	game.boss_items.assign(["u_greatsword_01", "r_ring_02", "h_neck_01"])
	game._challenge_demon_king()

func _run_world_preview() -> void:
	game._start_game()
	game.state = "preview"
	get_tree().paused = true
	game._update_hud()

func _run_night_preview() -> void:
	game._start_game()
	game.cycle_number = 4
	for monster_id in ["cave_bat", "skeleton", "wisp", "iron_beetle", "shade", "ogre", "cultist"]:
		var index := ["cave_bat", "skeleton", "wisp", "iron_beetle", "shade", "ogre", "cultist"].find(monster_id)
		game.combat.spawn_enemy_instance(game.player.global_position + Vector2.from_angle(TAU * float(index) / 7.0) * 245.0, 0, "", false, "", false, monster_id)
	game._toggle_day_night()
	game.canvas_modulate.color = Color("8995c9")
	game.world.set_night_amount(1.0)
	await get_tree().create_timer(0.65).timeout
	game.state = "preview"
	get_tree().paused = true
	game._update_hud()

func _run_fate_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.state = "choice"
	game.choice_source = "level"
	game._choose_skill(PatchLibrary.by_id("thunder"), PatchLibrary.by_id("blood_pact"))

## V8: 구 "각성 연출" 프리뷰 → **보스 트로피 2택1** 프리뷰. 플래그 이름(`--preview-evolution`)은
## 다른 에이전트의 스크립트를 지키려고 그대로 둔다(ROUTINES는 W9의 개명 규약을 따른다).
func _run_evolution_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.factory.place_card(0, DealCardLibrary.instance("shield_bash", 1))
	game.factory.place_card(1, DealCardLibrary.instance("moon_barrier", 1))
	game.factory.add_inventory(DealCardLibrary.instance("holy_pulse", 1))
	game.clock.set_stage_raw(1)
	game.pending_stage_trophy = {
		"stage": 1, "design": "A", "enhanced": false, "descended": false,
		"day": game.clock.day_number, "dwell": game.clock.dwell
	}
	game.pending_trophy_followup = ""
	game._open_stage_trophy_choice()

# W9에서 시련 캠프가 꺼지고 W12가 시스템 자체를 삭제했으므로 균열 아레나를 보여 준다.
# `--preview-trial`과 `--preview-rift` 둘 다 여기로 들어온다.
func _run_rift_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	var rift: Dictionary = game.world.spawn_rift_near(game.player.global_position)
	if rift.is_empty():
		print("RIFT_PREVIEW_SKIPPED reason=%s" % game.world.get_last_rift_result())
		return
	game.rift_states[String(rift["id"])] = {"activated":false, "remaining":0, "cleared":false}
	game.player.global_position = rift["position"]
	var camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	game._activate_rift(String(rift["id"]))
	await get_tree().create_timer(0.35).timeout
	game.state = "preview"
	get_tree().paused = true
	game._update_hud()

func _run_castle_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	var starter_castle: Dictionary = game.world.get_nearest_interactable(game.world.get_castle_position(), 120.0)
	game._enter_castle(starter_castle)
	game.player.global_position = Vector2(0.0, 85.0)
	var camera := game.player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	game._refresh_castle_interactable()

func _run_build_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.factory.place_card(0, DealCardLibrary.instance("cleave", 2))
	game.factory.equip(ItemLibrary.instance("r_rapier_01"))
	game.factory.place_card(2, DealCardLibrary.instance("rapid_slash", 1))
	game.factory.place_card(1, DealCardLibrary.instance("time_cut", 1))
	for skill_id in ["flame_field", "thunder", "moon_barrier", "meteor_blade"]:
		game.factory.add_inventory(DealCardLibrary.instance(skill_id, 1))
	game._show_factory_menu("edit")

func _run_item_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.state = "item_choice"
	get_tree().paused = true
	game._clear_overlay()
	var preview_item := ItemLibrary.by_id("h_rapier_01")
	game._show_item_offer_card(preview_item, "treasure")

func _run_effects_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.2).timeout
	game.factory.place_card(0, DealCardLibrary.instance("sword_rain", 3))
	game.factory.place_card(1, DealCardLibrary.instance("gravity_well", 2))
	game.factory.place_card(2, DealCardLibrary.instance("blade_fan", 2))
	for index in 12:
		game.combat.spawn_enemy_instance(game.player.global_position + Vector2.from_angle(TAU * float(index) / 12.0) * 135.0, 2, "", false, "", false, "skeleton")
	game._reset_player_cycle()
	await get_tree().create_timer(1.15).timeout
	game.state = "preview"
	get_tree().paused = true
	game._update_hud()

func _run_toast_preview() -> void:
	game._start_game()
	await get_tree().create_timer(0.5).timeout
	var rejected := DealCardLibrary.by_id("meteor_blade")
	game.rejected_skills.append("meteor_blade")
	game._show_boss_growth_toast([rejected])
	await get_tree().process_frame
	for active_tween: Tween in get_tree().get_processed_tweens():
		active_tween.pause()
	game.state = "preview"
	get_tree().paused = true
