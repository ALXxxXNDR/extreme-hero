extends SceneTree
# Y5 임시 검증 도구. 습성 5종의 낮 규칙을 노드 트리 없이 직접 두드린다.
# **검증이 끝나면 삭제한다** — 저장소에 남을 파일이 아니다.

class StubClock extends RefCounted:
	var stage := 1

class StubGame extends Node:
	var clock := StubClock.new()
	var rng := RandomNumberGenerator.new()
	var is_night := false


func _make(kind: String, behavior: int, stage: int) -> DebtEnemy:
	var stub := StubGame.new()
	stub.clock.stage = stage
	var enemy := DebtEnemy.new()
	enemy.setup(stub, null, kind, behavior, 1.0, [])
	return enemy


func _initialize() -> void:
	var lines: Array[String] = []

	# ① 습성 배정 (§5.2 표)
	var expected := {
		"mossling": "herd", "imp": "herd", "boar": "guard", "skeleton": "guard",
		"ogre": "guard", "wolf": "hunt", "hellhound": "hunt",
		"shade": "stalk", "cultist": "stalk", "wisp": "shy"
	}
	var habit_ok := true
	for id: String in expected.keys():
		var monster := MonsterLibrary.by_id(id)
		var enemy := _make(id, int(monster["behavior"]), 1)
		if enemy.habit != String(expected[id]):
			habit_ok = false
			lines.append("  MISMATCH %s -> %s (기대 %s)" % [id, enemy.habit, expected[id]])
	lines.append("habit_assign=%s" % habit_ok)

	# ② shy — 낮에는 맞아도 도망간다
	var wisp := _make("wisp", 3, 3)
	wisp.aggro = true                      # provoke()가 켠 상태를 흉내낸다
	wisp.was_hit = true
	wisp._update_field_aggro(0.016, 200.0)
	lines.append("shy_near aggro=%s flee=%.2f (기대 false / >=0.6)" % [wisp.aggro, wisp.flee_timer])
	var wisp_far := _make("wisp", 3, 3)
	wisp_far.aggro = true
	wisp_far._update_field_aggro(0.016, 400.0)
	lines.append("shy_far aggro=%s (기대 true — 260px 밖은 안 도망간다)" % wisp_far.aggro)

	# ③ stalk — 210px 안에서만 급습. 300px에서는 서 있는다(behavior 4의 310px 무효화)
	var shade_far := _make("shade", 4, 3)
	shade_far._update_field_aggro(0.016, 300.0)
	lines.append("stalk_300 aggro=%s (기대 false)" % shade_far.aggro)
	var shade_near := _make("shade", 4, 3)
	shade_near._update_field_aggro(0.016, 200.0)
	lines.append("stalk_200 aggro=%s (기대 true)" % shade_near.aggro)
	# 걸린 뒤 560px 밖으로 달아나면 3초 뒤 풀린다
	var shade_lost := _make("shade", 4, 3)
	shade_lost._update_field_aggro(0.016, 200.0)
	for _frame in 200:
		shade_lost._update_field_aggro(0.016, 700.0)
	lines.append("stalk_release aggro=%s (기대 false — 3.2초 이탈)" % shade_lost.aggro)

	# ④ guard — 165px 안에서 반격. 밖에서는 안 켜진다
	var boar_far := _make("boar", 2, 1)
	boar_far._update_field_aggro(0.016, 300.0)
	var boar_near := _make("boar", 2, 1)
	boar_near._update_field_aggro(0.016, 150.0)
	lines.append("guard_300 aggro=%s / guard_150 aggro=%s (기대 false / true)" % [boar_far.aggro, boar_near.aggro])
	# 텃세는 추격이 풀려도 자기 자리를 새로 잡지 않는다
	var boar_home := _make("boar", 2, 1)
	boar_home.home_position = Vector2(500.0, 500.0)
	boar_home.aggro = true
	boar_home.aggro_lost_timer = 4.0
	for _frame in 300:
		boar_home._update_field_aggro(0.016, 900.0)
	lines.append("guard_home aggro=%s home=%s (기대 false / (500,500) 유지)" % [boar_home.aggro, boar_home.home_position])

	# ⑤ hunt — 1·2스테이지 낮 선공 0 · 3스테이지부터 열린다
	var wolf_s1 := _make("wolf", 4, 1)
	wolf_s1._update_field_aggro(0.016, 200.0)
	var wolf_s2 := _make("wolf", 4, 2)
	wolf_s2._update_field_aggro(0.016, 200.0)
	var wolf_s3 := _make("wolf", 4, 3)
	wolf_s3._update_field_aggro(0.016, 200.0)
	lines.append("hunt_day s1=%s s2=%s s3=%s (기대 false false true)" % [wolf_s1.aggro, wolf_s2.aggro, wolf_s3.aggro])
	# 밤에 태어나 아침을 맞은 늑대 — set_night_raid(false)가 끄는가
	var wolf_dawn := _make("wolf", 4, 2)
	wolf_dawn.raid_mode = true
	wolf_dawn.aggro = true
	wolf_dawn._update_field_aggro(0.016, 200.0)
	var night_aggro := wolf_dawn.aggro
	wolf_dawn._update_field_aggro(0.016, 200.0)
	wolf_dawn.raid_mode = false
	wolf_dawn._update_field_aggro(0.016, 200.0)
	lines.append("hunt_dawn night=%s day=%s (기대 true false)" % [night_aggro, wolf_dawn.aggro])

	# ⑥ herd — 무리 중심 세터
	var mossling := _make("mossling", 1, 1)
	mossling.set_herd_center(Vector2(120.0, -40.0))
	lines.append("herd_center center=%s home=%s (기대 둘 다 (120,-40))" % [mossling.herd_center, mossling.home_position])

	# ⑦ 밤 매복 속도 배율 상수가 실제로 읽히는가
	lines.append("stalk_night_speed=%.2f herd_radius=%.0f shy_range=%.0f ambush=%.0f guard=%.0f" % [
		MonsterLibrary.HABIT_STALK_NIGHT_SPEED, MonsterLibrary.HABIT_HERD_RADIUS,
		MonsterLibrary.HABIT_SHY_FLEE_RANGE, DebtEnemy.HABIT_STALK_AMBUSH_RANGE,
		DebtEnemy.HABIT_GUARD_RANGE])

	# ⑧ 지형 × 습성 스폰 굴림 — **진짜 함수를 부른다**(CombatResolver.roll_archetype_for_terrain)
	var stub := StubGame.new()
	stub.clock.stage = 5
	stub.rng.seed = 20260810
	var resolver := CombatResolver.new()
	resolver.game = stub
	for tile: String in ["grass", "forest", "rocks", "shore_north", "ruins"]:
		var counts: Dictionary = {}
		for _draw in 20000:
			var picked := resolver.roll_archetype_for_terrain(tile)
			var h := MonsterLibrary.habit_of(picked)
			counts[h] = int(counts.get(h, 0)) + 1
		var parts: Array[String] = []
		for h: String in MonsterLibrary.HABITS:
			parts.append("%s=%.1f%%" % [h, float(int(counts.get(h, 0))) / 200.0])
		lines.append("terrain %-12s %s" % [tile, " ".join(parts)])

	print("Y5_PROBE_BEGIN")
	for line: String in lines:
		print(line)
	print("Y5_PROBE_END")
	quit()
