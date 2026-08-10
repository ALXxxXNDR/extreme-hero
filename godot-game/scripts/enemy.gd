class_name DebtEnemy
extends CharacterBody2D

# 시트는 이미 nearest x2로 구워져 있어 코드에서 다시 확대하지 않는다.
# 소스 셀 크기가 곧 화면 픽셀 크기다.
# 각 시트는 위 절반이 그림, 아래 절반이 같은 레이아웃의 흰 실루엣 마스크다.
# 피격 플래시·밤 변이 같은 색 변조는 이 마스크를 원하는 색으로 덧그려 만든다.
# ShaderMaterial을 쓰면 같은 _draw() 안의 체력바까지 함께 물들기 때문이다.
const MOB_CELL := 32.0
const MOB_MASK_OFFSET := Vector2(0.0, 128.0)
const MOB_SHEETS := {
	"blob": preload("res://art/v2/mob-blob.png"),
	"boar": preload("res://art/v2/mob-boar.png"),
	"imp": preload("res://art/v2/mob-imp.png"),
	"wolf": preload("res://art/v2/mob-wolf.png"),
	"skeleton": preload("res://art/v2/mob-skeleton.png"),
	"shade": preload("res://art/v2/mob-shade.png"),
	"wisp": preload("res://art/v2/mob-wisp.png"),
	"ogre": preload("res://art/v2/mob-ogre.png"),
	"cultist": preload("res://art/v2/mob-cultist.png"),
	"hellhound": preload("res://art/v2/mob-hellhound.png"),
	"bat": preload("res://art/v2/mob-bat.png"),
	"beetle": preload("res://art/v2/mob-beetle.png"),
	"ooze": preload("res://art/v2/mob-ooze.png"),
}
# =============================================================================
# V7: 보스 시트 테이블 (설계 §3.1 · handoff-v3-assets §2 "시트 규격표")
# =============================================================================
# v2는 마왕 한 마리뿐이라 `BOSS_CELL` / `BOSS_MASK_OFFSET` / `BOSS_SHEET` 세 상수가
# 파일 상단에 박혀 있었다. v3는 보스가 여섯이므로(스테이지 5 + 마왕) **표 하나**로 바꾼다.
# 값의 정본은 `art/v2/ASSET_MAP.md §11`이고 여기 옮겨 적은 것은 런타임이 에셋
# 파이프라인과 같은 표를 보게 하기 위해서다.
#
#   cell      한 프레임의 저장 픽셀 크기(시트가 이미 nearest 정수배로 구워져 있어
#             코드에서 다시 확대하지 않는다 — 소스 셀 크기가 곧 화면 크기다)
#   mask_y    아래 절반 흰 실루엣 마스크의 세로 offset
#   foot      **foot_inset** = 셀 바닥에서 스프라이트 접지선까지의 거리(저장 px).
#             마왕은 48×48 애니를 셀 아래쪽에 붙여 구워서 0이지만, v3 보스는 원본
#             프레임을 통째로 복사해 원작자 정렬을 보존했으므로 값이 있다.
#             그리기 식이 한 항 늘어난다: `foot + FOOT_INSET - cell.y`
#   행 키     [행 index, 프레임 수]. **`attack`이 빈 배열이면 공격 애니가 없다** —
#             A(서릿발 외눈)가 그렇고, 설계 §3.1은 그것을 타협이 아니라 설계로 흡수했다
#             (공격 = 발구름 + 바닥 링. 사지 애니메이션이 필요 없다).
#
# ⚠️ 함정 3건(handoff-v3-assets §2가 명시적으로 경고한 것):
#   ① A는 `attack`이 `[]`다 → `_draw_boss()`가 `stomp_pulse`(발구름 스케일 펄스)로 대신한다.
#   ② 점액 2종은 `walk`와 `attack`이 **같은 행 1(Jump 13f)**이다. 슬라임의 이동이 곧 도약이다.
#   ③ `foot`이 0이 아니다(14 / 12 / 48). 마왕만 0이다.
const BOSS_SHEETS: Dictionary = {
	"demon_king": {
		# Y4(handoff-ya §4 · 에셋 웨이브가 찾아낸 버그): 구 `boss-demon-king.png`는
		# 원본 시트를 **48×48 12프레임**으로 잘못 읽고 구워져 사무라이 하나가 셀 두 칸에
		# 걸쳐 있었다 — 필드의 마왕이 **반쪽만** 그려졌다. 실제 규격은 96×48 6프레임이다.
		# `-v2`는 아래 상수(셀 144×288 · mask_y 1440 · foot 0 · 12/12/8/8/8)를
		# **하나도 안 바꾸고** 그것을 고친다. 그래서 교체가 이 한 줄로 끝난다.
		"tex": preload("res://art/v2/boss-demon-king-v2.png"),
		"cell": Vector2(144.0, 288.0), "mask_y": 1440.0, "foot": 0.0, "radius": 58.0,
		"idle": [0, 12], "walk": [1, 12], "hit": [2, 8], "attack": [3, 8], "attack_left": [4, 8]
	},
	"frost_cyclops": {
		"tex": preload("res://art/v2/boss-frost-cyclops.png"),
		"cell": Vector2(100.0, 100.0), "mask_y": 300.0, "foot": 14.0, "radius": 38.0,
		"idle": [0, 5], "walk": [1, 6], "hit": [2, 3], "attack": []
	},
	"plague_slime": {
		"tex": preload("res://art/v2/boss-plague-slime.png"),
		"cell": Vector2(124.0, 104.0), "mask_y": 312.0, "foot": 12.0, "radius": 40.0,
		"idle": [0, 5], "walk": [1, 13], "hit": [2, 5], "attack": [1, 13]
	},
	"black_slime": {
		"tex": preload("res://art/v2/boss-black-slime.png"),
		"cell": Vector2(124.0, 104.0), "mask_y": 312.0, "foot": 12.0, "radius": 40.0,
		"idle": [0, 5], "walk": [1, 13], "hit": [2, 5], "attack": [1, 13]
	},
	"crimson_tengu": {
		"tex": preload("res://art/v2/boss-crimson-tengu.png"),
		"cell": Vector2(164.0, 164.0), "mask_y": 820.0, "foot": 48.0, "radius": 48.0,
		"idle": [0, 6], "walk": [1, 10], "hit": [2, 8], "attack": [3, 15], "trans": [4, 11]
	},
	"black_tengu": {
		"tex": preload("res://art/v2/boss-black-tengu.png"),
		"cell": Vector2(164.0, 164.0), "mask_y": 820.0, "foot": 48.0, "radius": 48.0,
		"idle": [0, 6], "walk": [1, 10], "hit": [2, 8], "attack": [3, 15], "trans": [4, 11]
	}
}
## `BossLibrary.rig_id()`(A / B / C / B+ / C+) → `BOSS_SHEETS` 키.
## 로테이션은 `GameTuning.STAGE_BOSS_DESIGN`이 소유하고 시트 선택만 여기서 한다.
const BOSS_RIG_SHEETS: Dictionary = {
	"A": "frost_cyclops", "B": "plague_slime", "C": "crimson_tengu",
	"B+": "black_slime", "C+": "black_tengu"
}

# =============================================================================
# V6: 원소 상태이상 (설계 §4.3 · §4.7 · §4.8)
# =============================================================================
# 규칙은 전부 `core/status_engine.gd`(V1 확정)가 갖는다. 이 파일이 하는 일은 셋뿐이다.
#   ① 상태 묶음(float 11칸)을 **1기당 한 번** 만들어 들고 있는다
#   ② `_physics_process`의 **기존 타이머 블록**에 감쇠·도트를 얹는다 (§4.7 규칙 1)
#   ③ 머리 위 핍과 마스크 틴트로 상태를 보여 준다 (§4.8)
# 상태를 **부여**하는 것은 `combat_resolver`다. 여기서 매트릭스를 돌리지 않는다.
#
# 핍 시트 규격은 art/v2/ASSET_MAP.md §13-1이 정본이다.
#   80×32 · 셀 16×16 · 5열 · 열 순서 = StatusEngine.STATUSES = [독,연,한,유,전]
#   아래 절반(offset.y = 16)은 흰 실루엣 마스크로 몹 시트와 같은 규약이다.
const STATUS_PIP_SHEET := preload("res://art/v2/vfx-status-pips.png")
const STATUS_PIP_CELL := 16.0
const STATUS_PIP_GAP := 2.0
# 본체 마스크 틴트 색(§4.8 "독 녹 / 연 주 / 한 청 / 유 흑 / 전 황").
# 핍과 같은 값이며 정본은 ASSET_MAP §13-1 표다.
const STATUS_TINTS: Dictionary = {
	"poison": Color("83c65c"),
	"burn": Color("e78a45"),
	"chill": Color("67c7d4"),
	"oil": Color("1b1622"),
	"shock": Color("f4d35e")
}
const STATUS_TINT_ALPHA := 0.30

# =============================================================================
# Y5: 독 스택 배지 (handoff-ya §5 · ASSET_MAP §13-2)
# =============================================================================
# 핍(`vfx-status-pips.png`)은 "무슨 상태인가"만 말한다. 몇 겹 쌓였는지는 못 말한다 —
# 독은 겹칠수록 아프기 때문에 그 숫자가 읽혀야 한다.
# 규격: 160×32 · 셀 32×32 · 5칸(스택 1~5) · **중립색이라 modulate가 필수다**
# (흰 점 + 어두운 판으로 구워져 있어 그냥 그리면 독인지 화상인지 구분이 안 된다).
const STATUS_STACK_BADGE_SHEET := preload("res://art/v2/vfx-stack-badge.png")
const STATUS_STACK_BADGE_CELL := 32.0
const STATUS_STACK_BADGE_MAX := 5

# =============================================================================
# Y5: 습성(habit) 런타임 상수 (설계 §5.2)
# =============================================================================
# 거리 상수 대부분은 `MonsterLibrary`가 소유한다(데이터 축). 여기 둘만 **런타임 축**이라
# 이 파일이 갖는다 — 둘 다 "얼마나 가까워야 덤비는가"이고 데이터가 아니라 조작감이다.
## 매복(stalk)이 급습으로 전환하는 사거리. 위습·해골이 서 있는 260px 도망 감지보다
## 짧아야 "가만히 있다가 갑자기"라는 그림이 나온다.
const HABIT_STALK_AMBUSH_RANGE := 210.0
## 텃세(guard)가 자기 자리를 침범당했다고 판단하는 거리. 매복보다 더 짧다 —
## 텃세는 쫓아오는 것이 아니라 밀어내는 것이다.
const HABIT_GUARD_RANGE := 165.0
## Y7: 「돌진 중」으로 보는 거리(반지름에 더한다 · §7.2 들멧돼지의 넉백 0 조건).
const CHARGE_RANGE := 170.0

var game: Node
var player: Node2D
var kind := "mossling"
var species := "mossling"
var behavior_type := 1
var is_boss := false
var is_split_child := false
var raid_mode := false
var radius := 17.0
var max_health := 8.0
var health := 8.0
var speed := 70.0
var contact_damage := 7.0
var xp_value := 1
var gold_value := 1
var active_modules: Array[String] = []
var boss_item_ids: Array[String] = []
var camp_id := ""
var is_camp_elite := false
var visual_variant := "blob"
var display_name := "마물"

var home_position := Vector2.ZERO
# Y5: 습성 축(§5.2). `behavior_type`(1~4 · 맞았을 때 어떻게 반응하는가)과 직교한다 —
# 이쪽은 **맞기 전에 필드에서 어떻게 사는가**다. 값의 정본은 monster_library.gd이고
# 보스는 습성이 없다(setup()이 보스 분기에서 먼저 반환하므로 기본값이 남는다).
var habit := "herd"
# 무리(herd)가 흩어지지 않게 붙잡아 두는 중심. 무리 스폰이 `set_herd_center()`로
# 앵커 좌표를 심는다. 그 경로를 안 탄 개체는 자기가 태어난 자리가 곧 중심이다.
var herd_center := Vector2.ZERO
# 추적 중 돌에 막혔을 때 한 번 고른 90° 우회 방향과 그 유효 시간(§5.1 리스크).
var detour_direction := Vector2.ZERO
var detour_timer := 0.0

# =============================================================================
# Y7: 피격 반응 프로필 (§7.2) · 충격 프로필의 시간 효과 (§7.3)
# =============================================================================
# 값의 정본은 `monster_library.gd`다(Y0이 열 종에 세 민감도를 적어 뒀다).
# 여기 있는 것은 **1기당 한 번 복사해 둔 사본**이다 — `apply_hit_reaction()`이
# 매 타격마다 `MonsterLibrary.by_id()`로 사전을 뒤지면 78기 × 초당 수십 타격이
# 문자열 해시 조회가 된다. setup()에서 한 번 읽고 끝낸다(새 순회 0).
var kb_sens := 1.0
var stun_sens := 1.0
var slow_sens := 1.0
## §7.2의 「피격 연출」 한 줄. 툴팁·검사가 읽는다(연출 자체는 아래 recoil 축이 만든다).
var hit_flavor := ""
## 들멧돼지 전용 — 돌진 중이면 넉백 0(§7.2 표 주석).
var kb_zero_while_charging := false
## 지금 플레이어를 향해 몸을 싣고 있는가. `_physics_process`가 매 프레임 갱신한다.
## 새 질의를 만들지 않는다 — 이미 계산해 둔 `player_distance`를 그대로 본다.
var charging := false
## 마지막으로 맞은 충격 프로필(§7.3 8종). 연출 분기와 검사가 읽는다.
var last_impact := ""

## `pin` — 대상 정지 0.25초. 경직과 달리 **넉백이 0이라 밀리지도 않는다.**
var pin_timer := 0.0
## `pop` — 0.3초 공중. 그 동안 이동 불가이고 그림이 위로 떴다 내려온다.
var airborne_timer := 0.0
var airborne_total := 0.0
## `rush` — 「점점 느려짐」. §7.3이 지시한 대로 **새 자원을 만들지 않는다** —
## 기존 `cycle_slow_multiplier`/`cycle_slow_timer`에 이 플래그 하나만 얹고,
## 켜져 있으면 타이머가 흐를수록 배율이 RAMP_FROM → RAMP_TO로 내려간다.
var cycle_slow_ramp := false
var cycle_slow_span := 0.0
## `stagger` — 취소된 공격 수(관측용). 실제 취소는 접촉·발사·발구름 타이머 초기화다.
var staggered_count := 0

## 「점점 느려짐」의 시작·끝 배율과 기본 지속(§7.3 "0.9 → 0.5, 1.5초").
const SLOW_RAMP_FROM := 0.90
const SLOW_RAMP_TO := 0.50
const SLOW_RAMP_SECONDS := 1.5
## `pin`의 정지 시간과 `pop`의 체공 시간(§7.3 표).
const PIN_SECONDS := 0.25
const POP_SECONDS := 0.30
## `slow` 프로필의 「이동 −35% 1.2초」(§7.3 표).
const IMPACT_SLOW_STRENGTH := 0.35
const IMPACT_SLOW_SECONDS := 1.20
## 체공 중 그림이 뜨는 최대 높이(px). 판정 좌표는 그대로다 — 그림만 뜬다.
const POP_HEIGHT := 26.0

# =============================================================================
# Y7: 밤 감지 반경 (handoff-y6 §5-4가 넘긴 항목)
# =============================================================================
# 밤의 습격 모드는 원래 거리를 안 보고 전원 추적이라 "감지 반경"이라는 손잡이가
# 없었다. Y6은 game.gd에서 0.25초마다 전 개체를 훑어 먼 놈만 습격 모드에서 빼는
# 방식으로 같은 결과를 만들었는데(그 웨이브는 이 파일을 못 열었다), 그 스윕은
# **매 0.25초 O(N) 순회**다. Y7이 진짜 필드로 승격해 그 순회를 지운다.
#   1.0 = 무제한(기본) · 0.6 = 밤눈 부적(−40%)
var night_sight_scale := 1.0
## 배율이 1 미만일 때 쓰는 기준 반경. game.gd의 `NIGHT_EYE_BASE_RANGE`와 같은 값이고,
## 두 곳이 갈라지지 않게 `game.night_eye_range()`가 이 상수를 곱해 쓴다.
const NIGHT_SIGHT_BASE := 700.0
var wander_direction := Vector2.ZERO
var wander_timer := 0.0
var aggro := false
var aggro_lost_timer := 0.0
var flee_timer := 0.0
var shield := 0.0
var max_shield := 0.0
var shield_recharge_timer := 0.0
var fire_timer := 2.0
var boss_attack_timer := 1.8
var minion_timer := 4.4
var contact_timer := 0.0
var hit_flash := 0.0
var visual_time := 0.0
var rollback_used := false
var recursion_stage := 0
var dead := false
var was_hit := false
var night_form_amount := 0.0
var night_form_target := 0.0
var visual_redraw_timer := 0.0
var external_cycle_enabled := false
var cycle_slow_timer := 0.0
var cycle_slow_multiplier := 1.0
var hit_stun_timer := 0.0
var knockback_velocity := Vector2.ZERO
var hit_recoil := 0.0
var hit_recoil_direction := Vector2.RIGHT
var displayed_health := -1.0
var trailing_health := -1.0
# V6: 상태이상 묶음. **적 1기당 딱 한 번** 만든다 — 프레임마다 만들면 78기 × 재할당이
# 생겨 §4.7 규칙 1이 무너진다. Array인 이유는 참조 타입이라 제자리 갱신이 되기 때문이다
# (`PackedFloat32Array`는 값 타입이라 못 쓴다 — handoff-v1 §1.1).
var st_state: Array = StatusEngine.make_state()
# 순수 시각용. 이동이 멈춰도 마지막으로 향하던 쪽을 유지해야 스프라이트가
# 정면으로 튀지 않으므로, 실제 velocity 대신 이 값으로 열을 고른다.
var visual_facing := Vector2.DOWN
# 마왕 공격 애니 잔여 시간. 판정과 무관하며 프레임 진행에만 쓴다.
var boss_attack_anim := 0.0

# =============================================================================
# V7: 스테이지 보스 (설계 §3.1 · §3.2 · §3.4 · 부록 B V7 ①④)
# =============================================================================
# 마왕과 **같은 노드**를 쓰되 세 가지가 다르다.
#   ① 시트가 보스마다 다르다 (`boss_sheet_key`)
#   ② 각인·과열·잔재 모듈이 없다 → `_process_boss()`의 마왕 전용 블록을 통째로 건너뛴다
#   ③ 페이즈가 있다 (기본 HP 50% 1회 / 강화 66%·33% 2회)
# 격파도 다르다 — 마왕 격파는 런 종료(`_finish_run`)지만 스테이지 보스 격파는
# 스테이지 전환이다. `_die()`가 `game.on_stage_boss_defeated()`로 갈라 준다.
var is_stage_boss := false
var boss_sheet_key := "demon_king"
var boss_design := ""
var boss_rig_id := ""
var boss_enhanced := false
var boss_descended := false
var boss_display_name := "버려진 마왕"
## 남은 페이즈 임계(체력 비율 내림차순). 하나 지날 때마다 앞에서 뽑아 쓴다.
var boss_phase_thresholds: Array = []
## 지금까지 통과한 페이즈 전환 횟수. HUD·`--boss-test`의 관측점.
var boss_phase := 0
## A(서릿발 외눈)의 **발구름** 잔여 시간. Attack 행이 없는 리그의 공격 표현이다
## (설계 §3.1 — "사지 애니메이션이 필요 없다"). 0.42초 동안 세로로 눌렸다 펴진다.
var boss_stomp_pulse := 0.0
## 등장 연출(C+ = TenguRed/Trans 11f). 1회성 프레임 애니이고 트윈이 아니다.
var boss_intro_anim := ""
var boss_intro_time := 0.0
var boss_intro_duration := 0.0

func setup(
	game_node: Node,
	player_node: Node2D,
	enemy_kind: String,
	field_behavior: int,
	power_level: float,
	debts: Array[String],
	boss_mode: bool = false,
	split_child: bool = false,
	boss_items: Array[String] = []
) -> void:
	game = game_node
	player = player_node
	kind = enemy_kind
	species = enemy_kind
	behavior_type = clampi(field_behavior, 1, 4)
	is_boss = boss_mode
	is_split_child = split_child
	boss_item_ids = boss_items.duplicate()

	if is_boss:
		for debt_id: String in debts:
			active_modules.append(DealCardLibrary.debt_module(debt_id))
		radius = 58.0
		# W12: 숫자 4개를 GameTuning으로 옮겼다(밸런스 손잡이는 튜닝 파일이 소유한다).
		# V6(2026-08-09): 식을 **`DemonLord.boss_base_health()` 한 곳**으로 합쳤다.
		#   V4가 §6.4 재보정을 하면서 부채 상한 `min(debts, BOSS_DEBT_CAP=45)`을 그 함수에
		#   심었는데, 여기가 같은 식을 두 번째로 들고 있어 **실기 마왕만 상한 없이**
		#   22.0/장으로 불어났다(handoff-v4 §V3-I의 미결 ②). 5스테이지면 마왕에게
		#   넘어가는 카드가 v2의 4~5배라 그대로 두면 60장 × 22 = 1,320이 기저 611을 압도한다.
		#   이제 `--boss-test`의 기준 개체(`DebtEnemy.new()` 대조)와 `balance_probe`가
		#   실기와 **같은 함수**를 본다.
		max_health = DemonLord.boss_base_health(debts.size(), boss_items.size(), power_level)
		health = max_health
		speed = 62.0 + minf(power_level * 2.0, 24.0)
		contact_damage = 15.0 + power_level * 0.8
		xp_value = 0
		gold_value = 0
		aggro = true
		_apply_boss_items()
		if active_modules.has("firewall"):
			max_shield = max_health * 0.22
			shield = max_shield
		return

	match behavior_type:
		1:
			species = "mossling"
			radius = 15.0
			max_health = 5.5 + power_level * 1.0
			speed = 82.0 + power_level * 2.0
			contact_damage = 0.0
			xp_value = 1
			gold_value = 1
		2:
			species = "boar"
			radius = 19.0
			max_health = 10.0 + power_level * 1.8
			speed = 73.0 + power_level * 2.3
			contact_damage = 8.0 + power_level * 0.45
			xp_value = 2
			gold_value = 2
		3:
			species = "imp"
			radius = 16.0
			max_health = 8.0 + power_level * 1.45
			speed = 93.0 + power_level * 2.6
			contact_damage = 7.0 + power_level * 0.4
			xp_value = 2
			gold_value = 2
		4:
			species = "wolf"
			radius = 17.0
			max_health = 12.0 + power_level * 2.0
			speed = 126.0 + power_level * 3.2
			contact_damage = 10.0 + power_level * 0.55
			xp_value = 3
			gold_value = 3
	health = max_health
	var archetype := MonsterLibrary.by_id(kind)
	if not archetype.is_empty():
		species = kind
		# Y5: 습성을 데이터에서 읽는다(§5.2). 표에 없는 종이면 `habit_of()`가 가장 순한
		# "herd"로 떨어뜨리므로 미등록 종이 갑자기 사냥꾼이 되는 일은 없다.
		habit = MonsterLibrary.habit_of(archetype)
		# Y7: 피격 반응 프로필(§7.2). 표에 없는 종이면 `reaction_profile()`이 전부
		# 1.0(보통)으로 채워 주므로 미등록 종이 갑자기 안 밀리거나 날아가지 않는다.
		var reaction := MonsterLibrary.reaction_profile(archetype)
		kb_sens = float(reaction["kb_sens"])
		stun_sens = float(reaction["stun_sens"])
		slow_sens = float(reaction["slow_sens"])
		hit_flavor = String(reaction["hit_flavor"])
		kb_zero_while_charging = bool(reaction["kb_zero_while_charging"])
		display_name = String(archetype.get("name", kind))
		visual_variant = String(archetype.get("visual", "blob"))
		# 체력 수치는 monster_library.gd가 단독으로 보유한다(위 behavior 기본값은 미등록 종 대비용).
		max_health = MonsterLibrary.health_for(archetype, power_level)
		health = max_health
		speed *= float(archetype.get("speed", 1.0))
		contact_damage *= float(archetype.get("damage", 1.0))
		xp_value = maxi(xp_value, int(archetype.get("xp", xp_value)))
		gold_value = maxi(gold_value, int(ceil(float(xp_value) * 0.72)))
		var native_module := String(archetype.get("module", ""))
		if not native_module.is_empty():
			active_modules.append(native_module)
		if visual_variant in ["ogre", "beetle"]:
			radius *= 1.25 if visual_variant == "ogre" else 1.12
		elif visual_variant in ["bat", "wisp"]:
			radius *= 0.82

	# 부채(마왕에게 넘긴 카드)가 일반 마물에게 랜덤 모듈을 부여한다.
	# targeting = 원거리 투사체 발사 모듈이므로 네이티브 원거리 몬스터와 동일한 주기
	# 게이팅을 받는다. 규칙은 monster_library.gd가 단독으로 보유한다.
	var ranged_allowed := MonsterLibrary.ranged_gate_ok(_current_cycle_number())
	for debt_id: String in debts:
		var module_id := DealCardLibrary.debt_module(debt_id)
		if module_id == MonsterLibrary.RANGED_MODULE and not ranged_allowed:
			# 초반 주기에는 이 부채가 아무 모듈도 남기지 않는다(다른 모듈로 대체하지 않음).
			continue
		var chance := 0.0
		match module_id:
			"firewall": chance = 0.16
			"overclock": chance = 0.24
			"cache": chance = 0.12
			"recursion": chance = 0.12
			"targeting": chance = 0.10
			"rollback": chance = 0.08
			"hotfix": chance = 0.13
		if randf() < chance:
			active_modules.append(module_id)
	if active_modules.has("firewall"):
		max_shield = maxf(3.0, max_health * 0.28)
		shield = max_shield
	if is_split_child:
		active_modules.erase("recursion")
		active_modules.erase("rollback")
		max_health *= 0.52
		health = max_health
		radius *= 0.74
		speed *= 1.18
		xp_value = 0
		gold_value = 0

# 현재 라운드(낮/밤 주기). game.gd가 단독으로 보유하는 값이며, 아직 game이 없거나
# 필드가 없으면 가장 보수적인 값(주기 1 = 초반)으로 취급해 게이팅이 열리지 않게 한다.
func _current_cycle_number() -> int:
	if is_instance_valid(game) and "cycle_number" in game:
		return maxi(1, int(game.cycle_number))
	return 1

# Y5: 현재 스테이지. `MonsterLibrary.stage_aggro_gate_ok()`에 먹일 값이다.
# game이나 clock이 없으면 **보수적으로 1**로 본다 — 1이면 낮 선공 게이트가 닫힌 쪽이라
# "모르면 선공하지 않는다"가 된다. 반대로 잡았다가는 테스트 환경에서 늑대가 낮에 덤빈다.
func _current_stage() -> int:
	if is_instance_valid(game) and game.get("clock") != null:
		return maxi(1, int(game.clock.stage))
	return 1

# 피드백 ⑰: 지금이 「무도발 정적」 구간인가(= 1스테이지 낮). 판단의 정본은
# `MonsterLibrary.stage_day_peaceful()` 하나이고 여기는 인자만 채운다.
#
# 두 번째 인자에 `raid_mode`가 아니라 `false`를 넣는 것은 게으름이 아니다 —
# 이 함수를 부르는 곳은 `_update_field_aggro()`의 습성 층뿐이고, 그 함수는 맨 위에서
# `if raid_mode: return`으로 밤을 이미 걸러 낸다. 여기까지 온 것은 전부 낮이므로
# `raid_mode`를 다시 읽으면 "밤일 수도 있다"는 거짓 여지가 코드에 남는다.
func _stage_day_peaceful() -> bool:
	return MonsterLibrary.stage_day_peaceful(_current_stage(), false)

# Y5: 무리 중심을 심는다(§5.2 · §5.3). 무리 스폰이 앵커·구성원 **전원**에게 부른다.
# `home_position`까지 같이 옮기는 이유는 배회 복귀 로직이 그 값을 보기 때문이다 —
# 개체가 태어난 자리가 아니라 무리 중심으로 돌아와야 무리가 뭉쳐 있는 그림이 나온다.
func set_herd_center(center: Vector2) -> void:
	herd_center = center
	home_position = center

# =============================================================================
# V7: 스테이지 보스 설정 (설계 §3.2 · §3.4 · 부록 B V7 ①②④)
# =============================================================================
# `setup(..., boss_mode = true, ...)` **직후 · `add_child()` 전에** 부른다.
# `_ready()`가 `radius`로 CollisionShape2D를 만들기 때문에 순서가 계약이다.
#
# `profile`은 `BossLibrary.resolve()`의 반환값에 game.gd가 셋을 얹은 것이다:
#   `health`(HP 식 결과) · `descended`(강림 밸브 경로) · `contact_damage`.
# 데이터 해석은 전부 boss_library / GameTuning이 하고 **여기서는 옮겨 담기만 한다.**
func configure_stage_boss(profile: Dictionary) -> void:
	is_stage_boss = true
	boss_design = String(profile.get("design", "A"))
	boss_enhanced = bool(profile.get("enhanced", false))
	boss_descended = bool(profile.get("descended", false))
	boss_rig_id = String(profile.get("rig_id", boss_design))
	boss_sheet_key = String(BOSS_RIG_SHEETS.get(boss_rig_id, "frost_cyclops"))
	boss_display_name = String(profile.get("name", boss_design))
	display_name = boss_display_name
	kind = "stage_boss_%s" % boss_rig_id
	species = kind
	# 마왕 전용 축을 전부 끈다 — 스테이지 보스는 각인도 과열도 잔재 모듈도 없다.
	active_modules.clear()
	boss_item_ids.clear()
	max_shield = 0.0
	shield = 0.0
	# 히트박스: handoff-v3-assets §2 권장값(A 38 / B·B+ 40 / C·C+ 48). 결정권은 V7이라
	# 시트 표에 함께 실었다 — 셀 크기와 반경이 한 곳에서 같이 읽혀야 어긋나지 않는다.
	var sheet: Dictionary = BOSS_SHEETS.get(boss_sheet_key, {}) as Dictionary
	radius = float(sheet.get("radius", 42.0))
	max_health = maxf(1.0, float(profile.get("health", 2600.0)))
	health = max_health
	displayed_health = health
	trailing_health = health
	speed = float(profile.get("speed", 74.0))
	contact_damage = float(profile.get("contact_damage", 14.0))
	xp_value = 0
	gold_value = 0
	aggro = true
	boss_phase = 0
	boss_phase_thresholds = (profile.get("phases", []) as Array).duplicate()
	# 등장 연출: C+만 `Trans` 11f를 쓴다(설계 §3.1 — 소형→대형 변신이 프레임 안에서 완결).
	var intro := String((profile.get("sprite", {}) as Dictionary).get("intro_anim", ""))
	if intro != "" and sheet.has(intro):
		boss_intro_anim = intro
		boss_intro_duration = float(int((sheet[intro] as Array)[1])) / 12.0
		boss_intro_time = 0.0
	queue_redraw()

## 발구름 1회(A 전용 연출 · 트윈 없음 · `delta` 감쇠). game.gd의 패턴 실행이 부른다.
func trigger_boss_stomp(duration: float = 0.42) -> void:
	boss_stomp_pulse = maxf(boss_stomp_pulse, duration)

## 공격 애니 1회. 리그에 `attack` 행이 없으면(A) 발구름으로 대신한다.
func trigger_boss_attack_anim(duration: float = 0.55) -> void:
	var sheet: Dictionary = BOSS_SHEETS.get(boss_sheet_key, {}) as Dictionary
	if (sheet.get("attack", []) as Array).is_empty():
		trigger_boss_stomp(duration)
		return
	boss_attack_anim = maxf(boss_attack_anim, duration)

## 지금 등장 연출 중인가(그 동안은 무적·정지 취급을 game.gd가 준다).
func boss_intro_playing() -> bool:
	return boss_intro_anim != "" and boss_intro_time < boss_intro_duration

## 체력 비율이 다음 페이즈 임계를 넘겼으면 페이즈를 하나 올리고 true를 돌려준다.
## **판정만 한다** — 연출·수치 변화는 game.gd가 소유한다(파일 경계).
func consume_boss_phase_step() -> bool:
	if boss_phase_thresholds.is_empty() or max_health <= 0.0:
		return false
	if health / max_health > float(boss_phase_thresholds[0]):
		return false
	boss_phase_thresholds.remove_at(0)
	boss_phase += 1
	return true

func mark_trial(trial_id: String, elite: bool = false) -> void:
	camp_id = trial_id
	raid_mode = true
	aggro = true
	if elite:
		is_camp_elite = true
		radius *= 1.45
		# W12: 설계 §5.5의 ×5 → ×3. 배율은 GameTuning이 소유한다.
		max_health *= GameTuning.TRIAL_ELITE_HEALTH_MUL
		health = max_health
		speed *= 0.84
		contact_damage *= 1.65
		xp_value *= 4
		gold_value *= 4

func _ready() -> void:
	# 픽셀 시트가 뭉개지지 않도록 이 CanvasItem의 모든 draw_texture에 nearest를 건다.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 2
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)
	add_to_group("enemies")
	displayed_health = health
	trailing_health = health
	if is_instance_valid(game):
		game.register_enemy(self)
	home_position = global_position
	# Y5: 무리 스폰 경로를 타지 않은 개체는 자기가 태어난 자리가 곧 무리 중심이다.
	# 여기서 안 잡으면 herd 몹이 월드 원점(0,0)으로 끌려간다.
	herd_center = global_position
	wander_timer = randf_range(0.2, 1.4)
	z_index = 3 if not is_boss else 7
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(game):
		game.unregister_enemy(self)

func set_night_raid(enabled: bool) -> void:
	if is_boss:
		return
	if not enabled and not camp_id.is_empty():
		raid_mode = true
		aggro = true
		return
	raid_mode = enabled
	night_form_target = 1.0 if enabled else 0.0
	if enabled:
		aggro = true
	else:
		aggro = behavior_type == 4 and global_position.distance_to(player.global_position) < 320.0
		if behavior_type == 1:
			aggro = false
		# Y5: 새벽의 습성 초기화(§5.2). 밤 규칙으로 살던 개체가 낮 규칙으로 갈아타는
		# 지점이다. 여기서 안 끄면 "밤에 태어나 아침까지 살아남은 늑대"가 낮 게이트를
		# 통째로 우회한다 — §5.4의 "1·2스테이지 낮 선공 0"이 스폰 필터만으로는
		# 지켜지지 않는 이유가 바로 이 개체다.
		match habit:
			"shy":
				# 겁쟁이는 낮에는 무조건 도망부터다. 밤에 덤비던 관성을 지운다.
				aggro = false
			"hunt":
				if not MonsterLibrary.stage_aggro_gate_ok(_current_stage(), false):
					aggro = false
			"herd":
				# 밤 추격으로 흩어진 무리를 원래 중심으로 다시 부른다.
				home_position = herd_center
		detour_timer = 0.0
	queue_redraw()

func provoke() -> void:
	was_hit = true
	match behavior_type:
		1:
			flee_timer = 3.4
			aggro = false
		2:
			aggro = true
			aggro_lost_timer = 4.0
		3:
			aggro = true
			aggro_lost_timer = 5.0
			if is_instance_valid(game):
				game.alert_same_species(species, global_position)
		4:
			aggro = true
			aggro_lost_timer = 4.0

func receive_pack_alert() -> void:
	if behavior_type == 3 and not dead:
		aggro = true
		aggro_lost_timer = 5.0
		queue_redraw()

func force_module(module_id: String) -> void:
	active_modules.append(module_id)
	if module_id == "firewall":
		max_shield = maxf(3.0, max_health * 0.32)
		shield = max_shield
	queue_redraw()

func use_external_deal_cycle(enabled: bool = true) -> void:
	external_cycle_enabled = enabled
	boss_attack_timer = 999999.0 if enabled else 1.8

## v2 `slow` 카드의 감속. **한(chill)과는 다른 자원이다** — 한은 StatusEngine이,
## 이건 `cycle_slow_multiplier`가 든다(둘은 곱으로 합성된다 · handoff-v6 §7 미결 6).
##
## V10(2026-08-09 · handoff-v7 §12-6 판정): 가드를 `is_boss` → **`is_boss and not
## is_stage_boss`** 로 좁혔다. V7이 스테이지 보스에게 상태이상을 열어 준 순간
## (`combat_resolver.strike_enemy_with_card`의 `status_eligible`) 두 감속 자원의
## 취급이 갈렸다 — 한은 걸리는데 v2 slow만 no-op이었다. 같은 술어를 쓰게 맞췄다.
## **마왕은 종전대로 면역이다**(부록 A-2 ⑫의 "5칸은 마왕만" 경계와 같은 자리).
##
## Y7(§7.2 · §7.3): 세기에 **몹별 둔화 감수성**(`slow_sens`)을 곱한다. 해골은 0.6이라
## 같은 카드에도 덜 느려지고 그림자는 1.5라 크게 느려진다 — 새 순회는 없다.
## `ramp`가 켜지면 「점점 느려짐」이다(§7.3 `rush`) — 배율이 고정되지 않고
## 타이머가 흐를수록 0.9에서 0.5로 내려간다. 그 계산은 `_physics_process`의
## 기존 타이머 블록 한 줄이 한다(새 자원 0 · 새 순회 0).
func apply_cycle_slow(strength: float, duration: float = 1.25, ramp: bool = false) -> void:
	if dead or (is_boss and not is_stage_boss):
		return
	if ramp:
		# 「점점 느려짐」은 시작 배율부터 건다. 감수성은 **내려가는 폭**에 곱한다 —
		# 시작점까지 흔들면 "점점"의 출발선이 몹마다 달라져 읽히지 않는다.
		cycle_slow_ramp = true
		cycle_slow_span = maxf(0.05, duration)
		cycle_slow_timer = maxf(cycle_slow_timer, duration)
		cycle_slow_multiplier = minf(cycle_slow_multiplier, SLOW_RAMP_FROM)
		queue_redraw()
		return
	var scaled := clampf(strength * maxf(0.0, slow_sens), 0.0, 0.65)
	cycle_slow_multiplier = minf(cycle_slow_multiplier, clampf(1.0 - scaled, 0.35, 0.95))
	cycle_slow_timer = maxf(cycle_slow_timer, duration)
	queue_redraw()

## Y7(§7.3): 충격 프로필의 **이동 시간 효과** 두 종. 눈금(세기·지속)의 정본이
## 여기라서 규칙 계층은 "어떤 프로필인가"만 넘긴다.
##   `slow` → 이동 −35% 1.2초 (고정 감속)
##   `rush` → 「점점 느려짐」 0.9 → 0.5, 1.5초 (같은 자원에 ramp 플래그만 얹는다)
func apply_impact_time_effect(impact: String) -> void:
	match impact:
		"slow":
			apply_cycle_slow(IMPACT_SLOW_STRENGTH, IMPACT_SLOW_SECONDS)
		"rush":
			apply_cycle_slow(0.0, SLOW_RAMP_SECONDS, true)

## Y7: 「공격 끊기」(§7.3 `stagger`). 지금 겨누고 있던 것을 취소한다 —
## 접촉 재사용 대기와 원거리 발사 대기를 뒤로 민다.
## **새 상태를 만들지 않는다** — 이미 있는 타이머 둘을 미는 것이 전부다.
func cancel_pending_attack() -> void:
	if dead:
		return
	staggered_count += 1
	# ⚠️ **보스는 공격이 안 끊긴다.** `maxf`로 공격 타이머를 계속 뒤로 밀면
	# 「공격 끊기」 카드 7장 중 하나만 덱에 있어도 보스가 **영원히 안 때린다** —
	# 경직을 보스에게 0.025초로 클램프한 것과 정확히 같은 이유다(스턴 락 금지).
	# 보스는 자세만 흐트러진다(공격 애니가 끊긴다).
	if is_boss:
		boss_attack_anim = 0.0
		return
	contact_timer = maxf(contact_timer, 0.55)
	fire_timer = maxf(fire_timer, 0.9)

## Y7: 밤 감지 반경 배율을 건다(handoff-y6 §5-4 · 「밤눈 부적」).
## 1.0이면 밤의 습격 모드가 종전대로 거리를 안 본다. 1 미만이면 그 반경 밖에서는
## 습격이 **일시적으로 잠든다** — 밤 형태(`night_form`)도 같이 풀려서
## "나를 못 봤다"가 눈으로 읽힌다(Y6이 스윕으로 만들던 그림과 같다).
func set_night_sight_scale(scale: float) -> void:
	night_sight_scale = clampf(scale, 0.05, 1.0)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player):
		return
	visual_time += delta
	night_form_amount = move_toward(night_form_amount, night_form_target, delta * 2.5)
	hit_flash = maxf(0.0, hit_flash - delta)
	boss_attack_anim = maxf(0.0, boss_attack_anim - delta)
	# V7: 발구름 감쇠와 등장 연출 진행. 둘 다 기존 타이머 블록에 얹는다(새 순회 0).
	boss_stomp_pulse = maxf(0.0, boss_stomp_pulse - delta)
	if boss_intro_anim != "" and boss_intro_time < boss_intro_duration:
		boss_intro_time += delta
		queue_redraw()
		# 등장 연출 중에는 움직이지도 때리지도 않는다. 11프레임이 다 돌면 전투가 시작된다.
		velocity = Vector2.ZERO
		return
	hit_stun_timer = maxf(0.0, hit_stun_timer - delta)
	hit_recoil = move_toward(hit_recoil, 0.0, delta * 7.5)
	# Y7: 피격 파편이 그려지는 창(약 0.13초) 동안만 매 프레임 다시 그린다. 기본
	# 재도색 주기 0.075초로는 4프레임짜리 연출이 두 컷으로 끊긴다. 창이 짧아
	# 정지 상태의 78기 비용에는 영향이 없다(`--stress-test`가 확인한다).
	if hit_recoil > 0.06:
		queue_redraw()
	displayed_health = move_toward(displayed_health, health, maxf(12.0, max_health * 4.8) * delta)
	trailing_health = move_toward(trailing_health, health, maxf(7.0, max_health * 1.65) * delta)
	contact_timer = maxf(0.0, contact_timer - delta)
	flee_timer = maxf(0.0, flee_timer - delta)
	# Y5: 돌 우회 잔여 시간. **기존 타이머 블록에 한 줄만 얹는다**(새 순회 0).
	detour_timer = maxf(0.0, detour_timer - delta)
	# Y7: 붙잡기·띄우기 잔여 시간. **기존 타이머 블록에 두 줄만 얹는다**(새 순회 0).
	pin_timer = maxf(0.0, pin_timer - delta)
	if airborne_timer > 0.0:
		airborne_timer = maxf(0.0, airborne_timer - delta)
		queue_redraw()
	cycle_slow_timer = maxf(0.0, cycle_slow_timer - delta)
	if cycle_slow_timer <= 0.0:
		cycle_slow_multiplier = 1.0
		cycle_slow_ramp = false
		cycle_slow_span = 0.0
	elif cycle_slow_ramp:
		# Y7 「점점 느려짐」(§7.3 `rush`) — **한 줄이다.** 남은 시간 비율이 1에서 0으로
		# 가는 동안 배율이 0.9에서 0.5로 내려간다. 감수성은 내려가는 폭에만 곱해서
		# 해골(0.6)은 덜 처지고 그림자(1.5)는 바닥까지 처진다.
		var ramp_progress := 1.0 - clampf(cycle_slow_timer / maxf(0.05, cycle_slow_span), 0.0, 1.0)
		var ramp_drop := (SLOW_RAMP_FROM - SLOW_RAMP_TO) * ramp_progress * maxf(0.0, slow_sens)
		cycle_slow_multiplier = clampf(SLOW_RAMP_FROM - ramp_drop, SLOW_RAMP_TO, SLOW_RAMP_FROM)
	# V6: 상태이상 감쇠 + 도트 (§4.7 규칙 1·2). **새 순회를 만들지 않고** 위 타이머
	# 블록에 그대로 얹는다. `tick_dot()`은 상태가 하나도 없으면 즉시 반환하는 제로 할당
	# 경로이고, 0.25초 버퍼를 **자기가** 들고 있다 — 밖에 누적기를 또 두지 말 것.
	# 78기 × 60fps = 4,680회/초가 78 × 4 = 312회/초가 되는 지점이 바로 이 `if`다.
	var status_dot := StatusEngine.tick_dot(st_state, delta)
	if status_dot > 0.0:
		if is_instance_valid(game) and game.combat != null:
			game.combat.status_dot_ticks += 1     # --stress-test 계측(정수 1증가)
		take_damage(status_dot, global_position, 0.0, 0.0, StatusEngine.SOURCE_DOT)
		if dead:
			# 도트가 죽였다. queue_free()가 이미 예약됐으므로 이 프레임의 이동·접촉
			# 판정을 계속하면 죽은 몹이 한 번 더 플레이어를 때린다.
			return
	var player_distance := global_position.distance_to(player.global_position)
	if not is_boss and camp_id.is_empty() and player_distance > 1650.0:
		queue_free()
		return
	# Y7: 「돌진 중」 판정(§7.2 들멧돼지). 새 질의를 만들지 않는다 — 바로 위에서
	# 이미 잰 거리를 그대로 본다. 몸을 실은 상태에서만 넉백이 0이 되므로,
	# 멀리서 활보하는 멧돼지는 종전대로 밀린다.
	charging = (raid_mode or aggro) and player_distance < radius + CHARGE_RANGE
	# Y7: 밤 감지 반경(handoff-y6 §5-4). 배율이 1.0이면 이 줄은 비교 한 번으로 끝난다 —
	# 「밤눈 부적」을 쓴 밤에만 실제로 갈린다. Y6이 game.gd에서 0.25초마다 돌리던
	# **O(N) 스윕이 여기로 흡수됐다**(각 개체가 자기 프레임에서 자기만 본다).
	if night_sight_scale < 1.0 and not is_boss and camp_id.is_empty():
		var within_sight: bool = player_distance <= NIGHT_SIGHT_BASE * night_sight_scale
		if raid_mode != within_sight:
			set_night_raid(within_sight)
	if hit_stun_timer > 0.0:
		velocity = knockback_velocity
		var recoil_previous := global_position
		move_and_slide()
		if is_instance_valid(game) and not game.can_enemy_stand(global_position):
			global_position = recoil_previous
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1450.0 * delta)
		queue_redraw()
		return

	if not is_boss:
		_update_field_aggro(delta, player_distance)

	var current_speed := speed
	current_speed *= cycle_slow_multiplier
	# V6: 한(chill) 감속. v2의 카드 `slow`(cycle_slow_multiplier)와는 **다른 자원**이라
	# `min`이 아니라 **곱**으로 합성한다 — 빙 카드로 얼리고 그 위에 slow 카드를 겹치는
	# 것이 §4.6 빌드 ②의 의도이고, `min`이면 둘 중 하나가 통째로 무의미해진다.
	# 두 배율 모두 하한이 있어(0.35 / 1−CHILL_SLOW=0.65) 곱해도 0.2275 밑으로 안 간다.
	current_speed *= StatusEngine.move_multiplier(st_state)
	if active_modules.has("overclock") and health / max_health < 0.48:
		current_speed *= 1.65 if is_boss else 1.48
	# Y5: 매복은 **밤에만** 빨라진다(§5.2 "매복 + 이동속도 +20%").
	# 낮의 매복은 서 있는 것이 본체라 속도가 아무 의미도 없다.
	if raid_mode and habit == "stalk":
		current_speed *= MonsterLibrary.HABIT_STALK_NIGHT_SPEED
	var move_direction := Vector2.ZERO
	if is_boss or raid_mode or aggro:
		move_direction = global_position.direction_to(player.global_position)
		# 돌에 막혀 우회 중이면 직선 대신 아까 고른 옆길로 간다. 0.45초면 1칸짜리
		# 돌을 지나칠 만큼이고, 지나가면 저절로 직선 추적으로 돌아온다.
		if detour_timer > 0.0:
			move_direction = detour_direction
	elif flee_timer > 0.0:
		move_direction = player.global_position.direction_to(global_position)
		current_speed *= 1.42
	elif habit == "stalk":
		# Y5: 매복 = **움직이지 않는다**(§5.2). 낮 · 아직 사거리 밖 · 도망도 아닌 상태.
		# 배회하는 매복은 매복이 아니라서, 여기서 배회 블록 자체를 타지 않는다.
		move_direction = Vector2.ZERO
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(1.0, 2.6)
			wander_direction = Vector2.from_angle(randf_range(0.0, TAU)) if randf() > 0.28 else Vector2.ZERO
		# Y5: 배회 복귀 목표. 무리는 **자기 자리가 아니라 무리 중심**으로 돌아온다 —
		# 그래야 3~5기가 한 덩어리로 어슬렁거리는 그림이 유지된다(§5.2).
		# 복귀 거리 230px 리터럴은 MonsterLibrary.HABIT_HERD_RADIUS로 옮겼다(같은 값).
		var wander_anchor := herd_center if habit == "herd" else home_position
		if global_position.distance_to(wander_anchor) > MonsterLibrary.HABIT_HERD_RADIUS:
			wander_direction = global_position.direction_to(wander_anchor)
		move_direction = wander_direction
		current_speed *= 0.42

	# Y7(§7.3): 붙잡기(`pin`)와 띄우기(`pop`)는 **한 발짝도 못 가게 한다.**
	# 경직(`hit_stun_timer`)은 위에서 이미 반환했으므로 여기 오는 것은
	# "경직은 풀렸는데 아직 붙잡혀 있거나 떠 있는" 개체다.
	if pin_timer > 0.0 or airborne_timer > 0.0:
		move_direction = Vector2.ZERO
	velocity = move_direction * current_speed
	# 미세한 떨림으로 방향이 뒤집히지 않게 최소 속도 이상일 때만 갱신한다.
	if velocity.length_squared() > 25.0:
		visual_facing = velocity.normalized()
	var previous_position := global_position
	move_and_slide()
	if is_instance_valid(game) and not game.can_enemy_stand(global_position):
		global_position = previous_position
		wander_direction = wander_direction.rotated(PI * 0.5)
		# Y5(§5.1 리스크 ③): 추적 중에는 이동 방향이 **플레이어 직선**이라 위의
		# `wander_direction` 회전이 아무 일도 하지 않는다 — 돌에 코를 박고 그 자리에서
		# 떠는 그림이 된다. 그래서 이동 방향을 좌우 90°로 꺾어 보고 **뚫리는 쪽**을
		# 한 번만 고른 뒤 0.45초 동안 그쪽으로 간다.
		# 무한 루프가 아니다 — 타이머가 끝나면 직선 추적으로 돌아오고, 다시 막히면
		# 그때 다시 (이번엔 우회 방향을 기준으로) 꺾는다.
		if (is_boss or raid_mode or aggro) and move_direction.length_squared() > 0.0001:
			var probe := radius * 1.8
			var turn_right := move_direction.rotated(PI * 0.5)
			var turn_left := move_direction.rotated(-PI * 0.5)
			# 기본은 +90°다. 오른쪽이 막혔는데 왼쪽이 뚫려 있을 때만 왼쪽으로 바꾼다
			# (둘 다 막혔으면 +90°를 그대로 쓴다 — 어차피 이번 프레임은 못 간다).
			var picked := turn_right
			if not game.can_enemy_stand(global_position + turn_right * probe) \
					and game.can_enemy_stand(global_position + turn_left * probe):
				picked = turn_left
			detour_direction = picked
			detour_timer = 0.45
	global_position = global_position.round()

	# Y7: 떠 있는 동안에는 때리지 못한다(§7.3 `pop` "0.3초 공중"). 붙잡기는 제자리에
	# 못 박는 것이지 무력화가 아니므로 접촉 판정을 살려 둔다 — 그래야 "붙잡아 두고
	# 때린다"가 위험한 선택으로 남는다.
	var can_hurt := (is_boss or raid_mode or aggro) and airborne_timer <= 0.0
	if can_hurt and player_distance < radius + 17.0 and contact_timer <= 0.0:
		player.take_damage(contact_damage, global_position)
		contact_timer = 0.82 if not is_boss else 0.58

	if active_modules.has("hotfix"):
		var regeneration := max_health * (0.006 if is_boss else 0.009) * delta
		health = minf(max_health, health + regeneration)
	if active_modules.has("targeting") and not is_boss and (raid_mode or aggro):
		fire_timer -= delta
		if fire_timer <= 0.0 and player_distance < 570.0:
			game.spawn_enemy_bullet(global_position, global_position.direction_to(player.global_position), true, 7.0, 205.0)
			fire_timer = randf_range(3.2, 4.3)
	if is_boss:
		_process_boss(delta)
	visual_redraw_timer -= delta
	if visual_redraw_timer <= 0.0:
		visual_redraw_timer = 0.075
		queue_redraw()

# 필드 aggro 판정. **이 함수는 이미 매 프레임 돈다** — 습성도 여기 얹는다(§5.2).
# 층은 둘이고 순서가 곧 우선순위다.
#   ① 기존 behavior 층 (v2부터의 감지·이탈 거리)
#   ② Y5 습성 층 (그 위에 덮어쓴다)
# `raid_mode`(밤)는 맨 위에서 즉시 반환하므로, ①②는 **전부 낮 규칙**이다.
func _update_field_aggro(delta: float, player_distance: float) -> void:
	if raid_mode:
		aggro = true
		return
	# ---------------------------------------------------------------- ① behavior 층
	# 매복(stalk)만 예외다. 아래 습성 층이 감지 규칙을 **통째로 대신**하므로 여기서
	# 310px 감지를 태우면 안 된다 — 300px에서 달려드는 것은 매복이 아니다.
	if behavior_type == 4 and habit != "stalk":
		if player_distance < 310.0:
			aggro = true
			aggro_lost_timer = 3.0
		elif aggro:
			if player_distance > 610.0:
				aggro_lost_timer -= delta
			else:
				aggro_lost_timer = 3.0
			if aggro_lost_timer <= 0.0:
				aggro = false
				home_position = global_position
	elif behavior_type in [2, 3] and aggro:
		if player_distance > 850.0:
			aggro_lost_timer -= delta
			if aggro_lost_timer <= 0.0:
				aggro = false
				# 텃세(guard)만은 자리를 새로 잡지 않는다. 추격이 끝난 지점을 새 집으로
				# 삼으면 "자기 자리를 지킨다"가 성립하지 않고 텃세가 필드를 떠돌게 된다.
				if habit != "guard":
					home_position = global_position
	# ---------------------------------------------------------------- ② 습성 층 (낮)
	match habit:
		"shy":
			# 겁쟁이는 **맞아도 낮에는 도망간다**. provoke()가 켠 aggro를 매 프레임
			# 도로 끄는 것이 이 한 줄의 목적이다 — 그게 겁쟁이의 정의다.
			if player_distance < MonsterLibrary.HABIT_SHY_FLEE_RANGE:
				aggro = false
				flee_timer = maxf(flee_timer, 0.6)
		"stalk":
			# 매복: 사거리 안에 들어오는 순간 급습. 밖이면 서 있는다(이동 블록이 담당).
			# 피드백 ⑰의 정적 게이트를 텃세와 **같은 모양으로** 얹는다. 지금 매복 두 종
			# (굶주린 그림자 2 · 잠식 주술사 4)은 1스테이지에 없으므로 이 조건은
			# 오늘 한 번도 갈리지 않는다 — 그래도 두는 이유는 "1스테이지 낮에는 먼저
			# 켜지 않는다"가 종 표의 우연이 아니라 **코드의 성질**이어야 하기 때문이다.
			if player_distance < HABIT_STALK_AMBUSH_RANGE and not _stage_day_peaceful():
				aggro = true
				aggro_lost_timer = 3.0
			elif aggro:
				# 한 번 걸린 뒤에는 기존 behavior 4와 같은 방식으로 감쇠해 풀린다.
				if player_distance > 560.0:
					aggro_lost_timer -= delta
					if aggro_lost_timer <= 0.0:
						aggro = false
						home_position = global_position
				else:
					aggro_lost_timer = 3.0
		"guard":
			# 텃세: 자기 자리 근처를 침범당하면 반격한다. 이탈 판정은 위 behavior 2/3
			# 층(850px)이 그대로 맡는다 — 여기서는 켜는 조건만 얹는다.
			#
			# 피드백 ⑰: **이 한 줄이 "1스테이지 낮 선공"의 정체였다.** 스폰 게이트는
			# behavior 4만 보므로 들멧돼지(behavior 2)를 통과시키고, 여기서는 스테이지도
			# 시간대도 안 보고 165px에 켰다. 마릿수 자체는 많지 않다 —
			# `--field-test` 실측으로 27기 필드에 1~2기(서 있는 개체의 3~9%)다.
			# 그런데도 체감이 컸던 이유는 **그 1~2기가 1스테이지 낮 필드에서 유일하게
			# 먼저 달려오는 것**이었기 때문이다. 나머지는 전부 맞아야 반응한다.
			#
			# 거리 비교를 **앞에** 두는 것은 의도다 — 게이트 조회(`_current_stage()`)가
			# 사거리 안에 들어온 프레임에만 돌아, 낮 개체 상한(59기)이 매 프레임
			# 스테이지를 되묻는 일이 없다.
			if player_distance < HABIT_GUARD_RANGE and not _stage_day_peaceful():
				aggro = true
				aggro_lost_timer = 4.0
		"hunt":
			# §5.4 "1·2스테이지 낮 선공 0"의 **런타임 보증**이다.
			# 스폰 필터(`stage_spawn_allowed`)만으로는 밤에 태어나 아침까지 살아남은
			# 늑대를 못 막는다. 그 개체가 여기서 걸린다.
			if not MonsterLibrary.stage_aggro_gate_ok(_current_stage(), false):
				aggro = false
				aggro_lost_timer = 0.0
		# "herd"는 aggro 규칙을 바꾸지 않는다 — 무리는 배회 중심(herd_center)만 다르다.

func _process_boss(delta: float) -> void:
	# V7: 스테이지 보스는 마왕의 모듈 블록(다중 스레드 소환 · 검은 갑주 재생 · 분열의
	# 저주)을 **타지 않는다.** 각인도 잔재도 없으므로 `active_modules`가 늘 비어 있어
	# 실질적으로는 no-op이지만, 의도를 코드로 못 박아 두면 V8·V10이 모듈을 붙였을 때
	# 스테이지 보스가 조용히 마왕의 행동을 물려받는 일이 없다.
	if is_stage_boss:
		if is_instance_valid(game) and game.has_method("on_stage_boss_tick"):
			game.on_stage_boss_tick(self, delta)
		game.update_boss_health(health, max_health, shield, max_shield)
		return
	if not external_cycle_enabled:
		boss_attack_timer -= delta
		if boss_attack_timer <= 0.0:
			_fire_boss_pattern()
			boss_attack_timer = 2.45 if not active_modules.has("overclock") else 1.95
	if active_modules.has("multithread"):
		minion_timer -= delta
		if minion_timer <= 0.0:
			game.spawn_boss_minions(global_position, mini(2 + active_modules.count("multithread"), 6))
			minion_timer = 5.3
	if active_modules.has("firewall") and shield <= 0.0:
		shield_recharge_timer -= delta
		if shield_recharge_timer <= 0.0:
			shield = max_shield
			game.spawn_burst(global_position, GamePalette.BLUE, 24, 220.0, 0.6)
			game.show_world_text(global_position - Vector2(0.0, 82.0), "검은 갑주 재생", GamePalette.BLUE, 18)
	if active_modules.has("recursion"):
		var health_ratio := health / max_health
		if recursion_stage == 0 and health_ratio < 0.68:
			recursion_stage = 1
			game.spawn_boss_minions(global_position, 4)
			game.show_world_text(global_position - Vector2(0.0, 88.0), "분열의 저주", GamePalette.MAGENTA, 21)
		elif recursion_stage == 1 and health_ratio < 0.34:
			recursion_stage = 2
			game.spawn_boss_minions(global_position, 5)
	game.update_boss_health(health, max_health, shield, max_shield)

func _fire_boss_pattern() -> void:
	# 탄막이 나가는 순간부터 공격 애니를 재생한다(발사 판정 자체는 아래 그대로).
	boss_attack_anim = 0.62
	var bullet_count := 8 + mini(active_modules.count("multithread") * 2, 8)
	var offset := visual_time * 0.38
	for index in bullet_count:
		var direction := Vector2.from_angle(TAU * float(index) / float(bullet_count) + offset)
		game.spawn_enemy_bullet(global_position + direction * 54.0, direction, false, 9.0, 238.0)
	if active_modules.has("targeting"):
		var aim := global_position.direction_to(player.global_position)
		for angle in [-0.2, 0.0, 0.2]:
			game.spawn_enemy_bullet(global_position + aim * 58.0, aim.rotated(angle), true, 10.0, 218.0)
	game.spawn_burst(global_position, GamePalette.RED, 12, 110.0, 0.32)

func slows_player(point: Vector2) -> bool:
	if not active_modules.has("cache"):
		return false
	var aura_radius := 225.0 if is_boss else 104.0
	return global_position.distance_to(point) < aura_radius

## V6: 5번째 인자 `source`가 추가됐다 (§4.7 규칙 3 · 어휘는 StatusEngine이 소유).
## **`SOURCE_DOT`이면 `provoke()`를 건너뛴다. 이건 선택이 아니다** — `provoke()`는
## behavior 3(뿔임프)에서 `game.alert_same_species()`로 **반경 780px 종족 경보**를 쏜다.
## 도트는 초당 4회 × 78기이므로 그대로 두면 프레임당 312번의 광역 질의가 생겨 즉사한다.
## 피격 섬광도 같은 이유로 뺀다 — 4회/초로 번쩍이면 상태 핍이 오히려 안 읽힌다.
func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, knockback_force: float = 0.0, stun_duration: float = 0.0, source: int = StatusEngine.SOURCE_NORMAL) -> void:
	if dead:
		return
	if source != StatusEngine.SOURCE_DOT:
		provoke()
		hit_flash = 0.12
	if knockback_force > 0.0 or stun_duration > 0.0:
		apply_hit_reaction(hit_position, knockback_force, stun_duration)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if is_boss and shield <= 0.0:
			shield_recharge_timer = 9.0
		if is_instance_valid(game):
			game.show_world_text(global_position - Vector2(0.0, radius + 15.0), "-%d 갑주" % int(absorbed), GamePalette.BLUE, 14)
	if amount > 0.0:
		health -= amount
		if is_boss:
			game.update_boss_health(health, max_health, shield, max_shield)
	if health <= 0.0:
		_die()
	queue_redraw()

## Y7(§7.2): `resistance`에 **몹별 감수성**을 곱한다. 넉백과 경직은 서로 다른 축이라
## 각자의 배율을 쓴다 — 해골은 안 밀리는 대신 오래 굳고(1.0 / 1.5), 위습은 멀리
## 날아가는 대신 금방 깬다(2.0 / 1.0). 표는 `monster_library.gd`가 소유한다.
##
## 넷째 인자 `impact`는 §7.3의 충격 프로필 8종이다. 넉백·경직 **수치**는 이미
## `DealCardLibrary.impact_reaction()`이 정해서 앞의 두 인자로 들어오고, 여기서는
## 수치로 표현할 수 없는 것(붙잡기 · 띄우기 · 끌어당기기 · 공격 끊기)만 처리한다.
func apply_hit_reaction(hit_position: Vector2, knockback_force: float, stun_duration: float, impact: String = "") -> void:
	if dead:
		return
	var resistance := 1.0
	if is_boss:
		resistance = 0.10
	elif is_camp_elite:
		resistance = 0.24
	elif visual_variant in ["ogre", "beetle"]:
		resistance = 0.46
	var direction := hit_position.direction_to(global_position)
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	hit_recoil_direction = direction
	hit_recoil = 1.0
	if impact != "":
		last_impact = impact
	# Y7: 넉백 감수성. 돌진 중인 들멧돼지는 **한 걸음도 안 밀린다**(§7.2 표 주석) —
	# 몸을 실은 상대를 밀어내려면 카드가 아니라 벽이 필요하다는 그림이다.
	var knock_scale := maxf(0.0, kb_sens)
	if kb_zero_while_charging and charging:
		knock_scale = 0.0
	hit_stun_timer = maxf(hit_stun_timer, stun_duration * resistance * maxf(0.0, stun_sens))
	knockback_velocity += direction * knockback_force * resistance * knock_scale
	match impact:
		"pin":
			# 붙잡기 — 밀리지 않고 **그 자리에 못 박힌다.** 경직과 달리 넉백 속도를
			# 지워서 반동조차 없앤다("대상 정지 0.25초"의 문자 그대로다).
			knockback_velocity = Vector2.ZERO
			pin_timer = maxf(pin_timer, PIN_SECONDS * maxf(0.0, stun_sens))
		"pop":
			# 띄우기 — 0.3초 체공. 판정 좌표는 그대로 두고 그림만 뜬다(§7.1 원칙 2:
			# 타격감은 대상 쪽에서 만든다). 체공 중에는 이동이 잠긴다.
			airborne_total = POP_SECONDS * maxf(0.35, kb_sens)
			airborne_timer = maxf(airborne_timer, airborne_total)
		"stagger":
			cancel_pending_attack()
	if is_boss:
		hit_stun_timer = minf(hit_stun_timer, 0.025)
		pin_timer = 0.0
		airborne_timer = 0.0
	elif is_camp_elite:
		hit_stun_timer = minf(hit_stun_timer, 0.055)
		pin_timer = minf(pin_timer, 0.08)
		airborne_timer = minf(airborne_timer, 0.10)
	queue_redraw()

func _die() -> void:
	if active_modules.has("rollback") and not rollback_used:
		rollback_used = true
		health = max_health * (0.3 if is_boss else 0.42)
		shield = max_shield * 0.5
		game.spawn_burst(global_position, GamePalette.YELLOW, 30 if is_boss else 15, 250.0, 0.72)
		game.show_world_text(global_position - Vector2(0.0, radius + 30.0), "죽음의 거부", GamePalette.YELLOW, 23 if is_boss else 16)
		return
	dead = true
	# V6: 상태 해제. 이 노드는 queue_free 되지만 `st_state`가 이벤트 실행 중인
	# combat_resolver 쪽 배열 참조로 남아 있을 수 있어 여기서 비워 둔다.
	StatusEngine.clear(st_state)
	# V7: **스테이지 보스 격파는 런 종료가 아니다.** `combat_resolver._enemy_defeated_body()`는
	# `is_boss`면 무조건 `game._finish_run(true)`를 부르는데(마왕 기준으로 쓰인 v2 코드),
	# 그 파일은 V6 확정이라 열 수 없다. 그래서 **여기서 갈라 준다** — 스테이지 보스는
	# 격파 처리 전체를 game.gd의 보스 구역이 소유한다(전환·트로피 훅·마왕 직행).
	if is_stage_boss and is_instance_valid(game) and game.has_method("on_stage_boss_defeated"):
		game.on_stage_boss_defeated(self)
		queue_free()
		return
	if active_modules.has("recursion") and not is_boss and not is_split_child:
		game.call_deferred("spawn_split_enemies", global_position, 2)
	game.enemy_defeated(self)
	queue_free()

func _apply_boss_items() -> void:
	for item_id: String in boss_item_ids:
		var item := ItemLibrary.by_id(item_id)
		var effects: Dictionary = item.get("effects", {})
		max_health += maxf(float(effects.get("heal_cycle", 0.0)), 0.0) * 12.0
		contact_damage += maxf(float(effects.get("damage_all", 0.0)), 0.0) * 16.0
		speed += maxf(float(effects.get("move_speed", 0.0)), 0.0) * 65.0
		var slot := String(item.get("slot", ""))
		var weapon_type := String(item.get("weapon_type", ""))
		if slot in ["necklace", "bracelet"]:
			active_modules.append("firewall")
		elif slot == "ring":
			active_modules.append("hotfix")
		match weapon_type:
			"rapier": active_modules.append("overclock")
			"greatsword": active_modules.append("targeting")
			"dagger": active_modules.append("recursion")
			"longsword": active_modules.append("firewall")
			"spear": active_modules.append("targeting")
	health = max_health

## Y7(§7.1 원칙 2 "타격감은 대상 쪽에서 만든다" · §7.2 「피격 연출」열):
## 반동의 **크기가 몹마다 다르다.** 카메라는 한 픽셀도 안 움직이고, 대신 맞은 놈이
## 자기 무게대로 반응한다 — 가벼운 것(위습 2.0 · 그림자 1.8)은 크게 튕겨 날아가고,
## 무거운 것(오우거 0.25 · 멧돼지 0.5)은 제자리에서 납작하게 눌리며 버틴다.
## 새 자원을 만들지 않는다 — 이미 있던 `hit_recoil` 한 값에 `kb_sens`를 곱할 뿐이다.
## 지금 체공 높이(px). 0이면 땅에 있다. `_draw()`는 이 값만큼 그림을 올리고,
## **바닥 그림자는 반대로 그만큼 내려서** 제자리에 남긴다 — 그림자까지 같이 뜨면
## 그냥 "위로 옮겨 그린 것"이 되어 떠 있는 것으로 안 읽힌다(캡처로 확인한 함정).
func airborne_lift() -> float:
	if airborne_timer <= 0.0 or airborne_total <= 0.0:
		return 0.0
	return sin(PI * (1.0 - clampf(airborne_timer / airborne_total, 0.0, 1.0))) * POP_HEIGHT

func _draw() -> void:
	var weight := clampf(kb_sens, 0.2, 2.0)
	var recoil_rotation := hit_recoil_direction.y * hit_recoil * (0.018 + weight * 0.026)
	# 가벼운 것은 맞은 방향으로 늘어나고(튕겨 날아가는 그림), 무거운 것은 세로로
	# 눌린다(버티는 그림). 두 축의 합이 1 근처라 실루엣 면적은 크게 안 흔들린다.
	var stretch := 1.0 + hit_recoil * (0.04 + weight * 0.075)
	var squash := 1.0 - hit_recoil * (0.13 - weight * 0.035)
	var recoil_offset := hit_recoil_direction * hit_recoil * (0.6 + weight * 1.6)
	# 띄우기(`pop`) — 0.3초 동안 포물선으로 떴다 내려온다. 판정 좌표는 안 건드린다.
	recoil_offset.y -= airborne_lift()
	draw_set_transform(recoil_offset, recoil_rotation, Vector2(stretch, squash))
	if is_boss:
		_draw_boss()
	else:
		_draw_field_monster()

# 방향 -> 시트 열. 열 0=아래(정면) 1=위(뒤) 2=왼쪽 3=오른쪽.
# 대각선은 더 큰 축을 따라가야 좌우 실루엣이 우선 보인다.
func _sprite_column(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 3 if facing.x > 0.0 else 2
	return 0 if facing.y > 0.0 else 1

func _draw_field_monster() -> void:
	if is_camp_elite:
		draw_circle(Vector2.ZERO, radius + 12.0, Color(GamePalette.YELLOW, 0.09))
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 20, GamePalette.YELLOW, 3.0)
		var crown := PackedVector2Array([Vector2(-13,-radius-13), Vector2(-9,-radius-25), Vector2(-2,-radius-17), Vector2(4,-radius-28), Vector2(10,-radius-17), Vector2(14,-radius-26), Vector2(15,-radius-10), Vector2(-15,-radius-10)])
		draw_colored_polygon(crown, GamePalette.YELLOW)
	# Y7: 체공 중이면 그림자를 그만큼 **되돌려 놓고** 좁힌다. 위 `draw_set_transform`이
	# 이 몹의 모든 그리기를 올려 놨으므로 여기서 빼야 그림자가 땅에 남는다.
	var shadow_lift := airborne_lift()
	var shadow_shrink := 1.0 - clampf(shadow_lift / POP_HEIGHT, 0.0, 1.0) * 0.34
	draw_rect(Rect2(-radius * shadow_shrink, radius * 0.55 + shadow_lift,
		radius * 2.0 * shadow_shrink, 7.0), Color(0.03, 0.04, 0.06, 0.38), true)
	# 종별 색보정(붉은 늑대·진홍 지옥견 등)은 시트에 이미 구워져 있어 여기서 다시 곱하지 않는다.
	# 미등록 variant는 blob 시트로 떨어뜨려 그리기 자체가 실패하지 않게 한다.
	var sheet: Texture2D = MOB_SHEETS.get(visual_variant, MOB_SHEETS["blob"])
	var frame := wrapi(int(visual_time * 6.0), 0, 4)
	var source := Rect2(float(_sprite_column(visual_facing)) * MOB_CELL, float(frame) * MOB_CELL, MOB_CELL, MOB_CELL)
	# 발이 바닥 그림자 사각형 바로 위에 놓이도록 목적지를 발밑 기준으로 잡는다.
	var foot := radius * 0.55 + 4.0
	var destination := Rect2(-16.0, foot - 32.0, 32.0, 32.0)
	draw_texture_rect_region(sheet, destination, source)
	# 아래 절반의 실루엣 마스크를 같은 자리에 덧그려 상태별 색을 입힌다.
	var mask_source := Rect2(source.position + MOB_MASK_OFFSET, source.size)
	if night_form_amount > 0.01:
		draw_texture_rect_region(sheet, destination, mask_source, Color(0.42, 0.10, 0.20, night_form_amount * 0.55))
	if cycle_slow_timer > 0.0:
		draw_texture_rect_region(sheet, destination, mask_source, Color(GamePalette.CYAN, 0.22))
	if hit_stun_timer > 0.0:
		draw_texture_rect_region(sheet, destination, mask_source, Color(0.78, 0.84, 1.0, 0.30))
	if hit_flash > 0.0:
		draw_texture_rect_region(sheet, destination, mask_source, Color(1.0, 1.0, 1.0, 0.85))
	# V6: 우세 상태 마스크 틴트 1줄(§4.8). 기존 4단계(밤변이/둔화/경직/피격) **뒤**에
	# 붙인다 — 셰이더가 아니라 같은 실루엣 마스크를 한 번 더 덧그리는 것이다.
	# 우세 = StatusEngine의 정규 순서 첫 번째(독 > 연 > 한 > 유 > 전).
	var dominant_status := StatusEngine.active_list(st_state)
	if not dominant_status.is_empty():
		var tint: Color = STATUS_TINTS.get(dominant_status[0], GamePalette.TEXT)
		draw_texture_rect_region(sheet, destination, mask_source, Color(tint, STATUS_TINT_ALPHA))

	if night_form_amount > 0.01:
		var mutation_color := Color(GamePalette.RED, night_form_amount)
		draw_circle(Vector2.ZERO, radius + 11.0 + sin(visual_time * 7.0) * 2.0, Color(GamePalette.RED, 0.055 * night_form_amount))
		var left_horn := PackedVector2Array([Vector2(-7,-radius+2),Vector2(-20,-radius-16*night_form_amount),Vector2(-2,-radius+7)])
		var right_horn := PackedVector2Array([Vector2(7,-radius+2),Vector2(20,-radius-16*night_form_amount),Vector2(2,-radius+7)])
		draw_colored_polygon(left_horn,mutation_color); draw_colored_polygon(right_horn,mutation_color)
		draw_rect(Rect2(-10,-5,7,4),GamePalette.RED.lerp(Color.WHITE,0.2),true); draw_rect(Rect2(4,-5,7,4),GamePalette.RED.lerp(Color.WHITE,0.2),true)
		for fang_x in [-7.0, 0.0, 7.0]:
			var fang := PackedVector2Array([Vector2(fang_x-2,5),Vector2(fang_x+2,5),Vector2(fang_x,5+8*night_form_amount)]); draw_colored_polygon(fang,GamePalette.TEXT)

	if shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 7.0, -2.8, 0.4, 18, GamePalette.BLUE, 3.0)
	if raid_mode:
		draw_rect(Rect2(-5.0, -radius - 12.0, 10.0, 5.0), GamePalette.RED, true)
	elif flee_timer > 0.0:
		draw_rect(Rect2(-3.0, -radius - 12.0, 6.0, 6.0), GamePalette.CYAN, true)
	elif aggro:
		draw_rect(Rect2(-3.0, -radius - 14.0, 6.0, 9.0), GamePalette.ORANGE, true)
	# Every field monster exposes its health from the moment it enters the screen.
	var bar_width := 52.0 if is_camp_elite else 40.0
	draw_rect(Rect2(-bar_width * 0.5, -radius - 23.0, bar_width, 7.0), GamePalette.VOID, true)
	draw_rect(Rect2(-bar_width * 0.5 + 2.0, -radius - 21.0, (bar_width - 4.0) * clampf(trailing_health / max_health, 0.0, 1.0), 3.0), Color("f4e3b2"), true)
	draw_rect(Rect2(-bar_width * 0.5 + 2.0, -radius - 21.0, (bar_width - 4.0) * clampf(displayed_health / max_health, 0.0, 1.0), 3.0), GamePalette.GREEN if displayed_health / max_health > 0.35 else GamePalette.RED, true)
	_draw_hit_flavor()
	_draw_status_pips()

# =============================================================================
# Y7: 몹별 피격 연출 (§7.2 「피격 연출」열)
# =============================================================================
# ⚠️ **노드를 하나도 만들지 않는다.** 열 종에게 저마다 다른 파편을 주려고 타격마다
#    `spawn_burst()`를 부르면 78기 × 초당 수 타격이 그대로 노드 생성이 된다
#    (전역 예산 `MAX_TRANSIENT_EFFECTS`가 막아 주지만, 막히는 순간 카드 광역 연출이
#    같이 죽는다 — 예산을 피격 파편에 다 쓰는 것은 잘못된 배분이다).
#    그래서 파편을 **이 몹의 `_draw()` 안에서** 그린다. 이미 도는 그리기라 새 비용은
#    선 몇 개뿐이고, 개체가 죽으면 파편도 같이 사라진다.
# 진행값은 이미 있는 `hit_recoil`(0.13초쯤에 걸쳐 0으로 감쇠)을 그대로 쓴다 —
# 새 타이머도 새 순회도 없다. 트윈·루프 없음.
func _draw_hit_flavor() -> void:
	if hit_recoil <= 0.06:
		return
	var fade := hit_recoil * 0.9
	var away := hit_recoil_direction
	var side := Vector2(-away.y, away.x)
	match visual_variant:
		"blob":
			# 이끼콩 — 튕겨 날아가며 이끼 조각이 흩어진다.
			for index in 4:
				var chip := away * (radius + 6.0 + index * 7.0) + side * ((index % 2) * 10.0 - 5.0)
				draw_rect(Rect2(chip - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(GamePalette.GREEN, fade), true)
		"boar", "ogre", "beetle":
			# 들멧돼지·오우거 — 버티고 서서 흙먼지를 일으킨다(발밑에서만 난다).
			for index in 3:
				var puff := Vector2((index - 1) * 13.0, radius * 0.55)
				draw_circle(puff, 5.0 + hit_recoil * 4.0, Color(0.44, 0.35, 0.24, fade * 0.7))
		"skeleton":
			# 떠도는 해골 — 뼈 조각이 튄다. 경직이 길어(stun_sens 1.5) 조각도 오래 남는다.
			for index in 4:
				var shard := away.rotated((index - 1.5) * 0.42) * (radius + 9.0 + index * 4.0)
				draw_line(shard, shard + away * 7.0, Color(0.92, 0.90, 0.82, fade), 2.4)
		"shade":
			# 굶주린 그림자 — 반쯤 흩어졌다가 다시 뭉친다.
			for index in 5:
				var mote := Vector2.from_angle(TAU * float(index) / 5.0) * (radius + 14.0) * hit_recoil
				draw_circle(mote, 3.4, Color(GamePalette.PURPLE, fade * 0.65))
		"wisp", "bat":
			# 푸른 위습 — 저 멀리까지 밀려난다. 밀려난 자취를 한 줄로 남긴다.
			draw_line(-away * (radius + 26.0) * hit_recoil, -away * radius * 0.4,
				Color(GamePalette.CYAN, fade * 0.8), 3.0)
		"wolf":
			# 붉은 늑대 — 옆으로 쭉 미끄러진다. 미끄러진 자국은 발밑에 옆으로 눕는다.
			draw_line(Vector2(-18.0, radius * 0.55), Vector2(18.0, radius * 0.55),
				Color(0.62, 0.52, 0.40, fade * 0.8), 3.0)
		"cultist":
			# 잠식 주술사 — 후드가 크게 흔들린다.
			draw_arc(Vector2(0.0, -radius * 0.35), radius * 0.9,
				PI + hit_recoil * 0.5, TAU - hit_recoil * 0.5, 12, Color(GamePalette.MAGENTA, fade), 3.0)
		"hellhound":
			# 밤의 지옥견 — 발톱으로 땅을 긁으며 버틴다.
			for index in 3:
				var claw := Vector2(-12.0 + index * 12.0, radius * 0.5)
				draw_line(claw, claw + Vector2(0.0, 9.0 * hit_recoil), Color(GamePalette.RED, fade * 0.85), 2.2)
		_:
			# 뿔임프와 미등록 종 — 뒤로 한 바퀴 구른다(짧은 호 하나).
			draw_arc(Vector2.ZERO, radius + 6.0, -PI * 0.5, -PI * 0.5 + TAU * hit_recoil,
				10, Color(GamePalette.ORANGE, fade * 0.8), 2.6)

# V6: 머리 위 상태 핍(§4.8 · 최대 GameTuning.STATUS_PIP_MAX개).
# 위쪽 raid/flee/aggro 마커는 `if/elif` 배타 체인이라 거기에 끼우면 한 번에 하나밖에
# 못 뜬다 — 설계가 지시한 대로 **별도 루프**를 둔다. 체력바(-radius-23)보다 위인
# y = -radius-32에 가로 가운데 정렬로 늘어놓는다.
# **정적이다.** 트윈·펄스·시간 함수를 쓰지 않는다(트윈 루프 금지 규칙).
func _draw_status_pips() -> void:
	# Y7: 시간 흐름 배지(`vfx-timeflow.png` 배선 · handoff-y4 §9-C가 Y7에 넘긴 항목).
	# 핍 줄보다 한 층 위(y = -radius-52)에 그린다 — 상태(무엇에 걸렸나)와 시간
	# (얼마나 느려졌나)은 다른 정보라 줄을 섞지 않는다.
	_draw_timeflow_badge()
	var pips := StatusEngine.pip_list(st_state)
	if pips.is_empty():
		return
	var span := float(pips.size()) * (STATUS_PIP_CELL + STATUS_PIP_GAP) - STATUS_PIP_GAP
	var cursor_x := -span * 0.5
	var pip_y := -radius - 32.0
	for status: String in pips:
		var column := StatusEngine.STATUSES.find(status)
		if column < 0:
			continue
		draw_texture_rect_region(
			STATUS_PIP_SHEET,
			Rect2(cursor_x, pip_y, STATUS_PIP_CELL, STATUS_PIP_CELL),
			Rect2(float(column) * STATUS_PIP_CELL, 0.0, STATUS_PIP_CELL, STATUS_PIP_CELL))
		cursor_x += STATUS_PIP_CELL + STATUS_PIP_GAP
	# Y5: 독 스택 배지(handoff-y4 §9-A가 Y5에 넘긴 항목).
	# **2겹부터** 그린다 — 1겹은 위 핍만으로 이미 다 말했고 줄만 길어진다.
	# 자리는 핍 줄 오른쪽에 그대로 이어 붙인다(cursor_x가 마지막 핍 다음을 가리킨다).
	# 그릴 때 크기는 핍과 같은 16×16으로 눌러 머리 위 줄 높이를 흐트러뜨리지 않는다
	# (소스 셀은 32×32라 그리는 쪽에서 목적지만 줄인다).
	# 시트가 중립색이므로 STATUS_TINTS["poison"]을 곱해야 독으로 읽힌다.
	# **정적이다** — 위 핍과 같은 규약으로 트윈·펄스·visual_time을 쓰지 않는다.
	var poison_stacks := StatusEngine.stacks(st_state)
	if poison_stacks >= 2 and StatusEngine.has(st_state, "poison"):
		var badge_column := clampi(poison_stacks, 1, STATUS_STACK_BADGE_MAX) - 1
		draw_texture_rect_region(
			STATUS_STACK_BADGE_SHEET,
			Rect2(cursor_x, pip_y, STATUS_PIP_CELL, STATUS_PIP_CELL),
			Rect2(float(badge_column) * STATUS_STACK_BADGE_CELL, 0.0,
				STATUS_STACK_BADGE_CELL, STATUS_STACK_BADGE_CELL),
			STATUS_TINTS["poison"])

# =============================================================================
# Y7: 시간 흐름 배지 (`vfx-timeflow.png` · handoff-ya §5 · handoff-y4 §9-C)
# =============================================================================
# 규격: 192×96 · 셀 48 · 4프레임 × 2행 · **행 0 = 느림 / 행 1 = 빠름**.
# 몹 쪽에는 행 0만 쓴다(적이 빨라지는 효과는 게임에 없다 — 있는 척하지 않는다).
#
# ⚠️ **프레임은 시간으로 돌리지 않는다.** 4칸을 `visual_time`으로 순환시키면
#    그 자체가 무한 애니메이션이 되어 트윈 루프 금지 규칙의 정신에 어긋나고,
#    무엇보다 **아무 정보도 안 준다.** 대신 남은 시간 비율을 4칸에 나눠 담아
#    "얼마나 남았나"를 읽히게 한다 — 배지가 한 방향으로만 진행하고 끝나면 사라진다.
#    「점점 느려짐」(`rush`)일 때는 그 진행이 곧 "점점 더 느려지는 중"이다.
const TIMEFLOW_SHEET := preload("res://art/v2/vfx-timeflow.png")
const TIMEFLOW_CELL := 48.0
const TIMEFLOW_FRAMES := 4
## 화면에 그리는 크기. 핍(16)보다 크고 스택 배지보다 눈에 띄어야 한다.
const TIMEFLOW_DRAW := 20.0

func _draw_timeflow_badge() -> void:
	if cycle_slow_timer <= 0.0:
		return
	var span := cycle_slow_span if cycle_slow_ramp else 1.35
	var progress := 1.0 - clampf(cycle_slow_timer / maxf(0.05, span), 0.0, 1.0)
	var frame := clampi(int(progress * float(TIMEFLOW_FRAMES)), 0, TIMEFLOW_FRAMES - 1)
	# 「점점 느려짐」은 청록이 아니라 보라로 물들여 평범한 둔화와 구분한다.
	var tint: Color = GamePalette.PURPLE if cycle_slow_ramp else GamePalette.CYAN
	draw_texture_rect_region(
		TIMEFLOW_SHEET,
		Rect2(-TIMEFLOW_DRAW * 0.5, -radius - 52.0, TIMEFLOW_DRAW, TIMEFLOW_DRAW),
		Rect2(float(frame) * TIMEFLOW_CELL, 0.0, TIMEFLOW_CELL, TIMEFLOW_CELL),
		tint)

# V7: 마왕 전용 하드코딩(셀·마스크·행/프레임)을 `BOSS_SHEETS` 표 조회로 바꿨다.
# 우선순위 로직(피격 > 공격 > 이동 > 대기)은 v2 그대로다 — 마왕은 픽셀 하나 안 바뀐다.
func _draw_boss() -> void:
	var sheet: Dictionary = BOSS_SHEETS.get(boss_sheet_key, BOSS_SHEETS["demon_king"]) as Dictionary
	var texture: Texture2D = sheet["tex"]
	var cell: Vector2 = sheet["cell"]
	var foot_inset := float(sheet["foot"])
	if active_modules.has("cache"):
		draw_circle(Vector2.ZERO, 225.0, Color(GamePalette.PURPLE, 0.065))
		draw_arc(Vector2.ZERO, 225.0, 0.0, TAU, 48, Color(GamePalette.PURPLE, 0.48), 3.0)
	# 바닥 그림자: 마왕(-58,42,116,18)과 비례가 맞는 식(handoff-v3-assets §2 권장).
	draw_rect(Rect2(-radius, radius * 0.72, radius * 2.0, radius * 0.31), Color(0.02, 0.02, 0.04, 0.48), true)
	var row := 0
	var frame := 0
	var stomp_scale := Vector2.ONE
	if boss_intro_anim != "" and boss_intro_time < boss_intro_duration:
		# 등장 연출(C+ Trans 11f). **1회성 프레임 애니**이지 트윈 루프가 아니다.
		var intro_rows: Array = sheet[boss_intro_anim]
		row = int(intro_rows[0])
		var intro_frames := int(intro_rows[1])
		frame = clampi(int(boss_intro_time / maxf(boss_intro_duration, 0.001) * float(intro_frames)), 0, intro_frames - 1)
	elif hit_flash > 0.0:
		var hit_rows: Array = sheet["hit"]
		row = int(hit_rows[0])
		frame = wrapi(int(visual_time * 12.0), 0, int(hit_rows[1]))
	elif boss_attack_anim > 0.0 and not (sheet.get("attack", []) as Array).is_empty():
		# 공격 애니만은 경과 시간에 비례해 한 번만 훑는다(루프시키면 헛휘두르는 것처럼 보인다).
		var attack_rows: Array = sheet["attack"]
		if sheet.has("attack_left") and is_instance_valid(player) and player.global_position.x < global_position.x:
			attack_rows = sheet["attack_left"]
		row = int(attack_rows[0])
		var attack_frames := int(attack_rows[1])
		frame = clampi(int((0.62 - minf(boss_attack_anim, 0.62)) / 0.62 * float(attack_frames)), 0, attack_frames - 1)
	elif velocity.length_squared() > 25.0:
		var walk_rows: Array = sheet["walk"]
		row = int(walk_rows[0])
		frame = wrapi(int(visual_time * 9.0), 0, int(walk_rows[1]))
	else:
		var idle_rows: Array = sheet["idle"]
		row = int(idle_rows[0])
		frame = wrapi(int(visual_time * 7.0), 0, int(idle_rows[1]))
	# A(서릿발 외눈)는 Attack 행이 **없다**(설계 §3.1). 공격 = 발구름이므로 세로로
	# 눌렸다 펴지는 스케일 펄스로 표현한다. `delta` 감쇠라 트윈이 아니다.
	if boss_stomp_pulse > 0.0:
		var squash := sin(clampf(1.0 - boss_stomp_pulse / 0.42, 0.0, 1.0) * PI)
		stomp_scale = Vector2(1.0 + squash * 0.14, 1.0 - squash * 0.18)
	# foot_inset: 마왕은 셀 아래쪽 정렬이라 0이고, v3 보스는 원작자 정렬을 보존해 값이 있다.
	# 이 한 항이 빠지면 외눈이 땅에 묻히고 천구가 공중에 뜬다.
	var foot := 46.0 if boss_sheet_key == "demon_king" else radius * 0.72
	var source := Rect2(float(frame) * cell.x, float(row) * cell.y, cell.x, cell.y)
	# 발구름은 목적지 사각을 **접지선에 고정한 채** 눌러 만든다. `draw_set_transform`을
	# 다시 부르면 `_draw()`가 이미 건 피격 반동 변환이 지워지므로 쓰지 않는다.
	var draw_cell := cell * stomp_scale
	var bottom := foot + foot_inset
	var destination := Rect2(-draw_cell.x * 0.5, bottom - draw_cell.y, draw_cell.x, draw_cell.y)
	draw_texture_rect_region(texture, destination, source)
	var mask_source := Rect2(source.position + Vector2(0.0, float(sheet["mask_y"])), source.size)
	if hit_flash > 0.0:
		draw_texture_rect_region(texture, destination, mask_source, Color(1.0, 1.0, 1.0, 0.7))
	# V7 + V6: 보스도 `st_state`를 갖고 `tick_dot`이 돈다. 우세 상태 마스크 틴트를
	# 몹과 **같은 규약**으로 얹는다(handoff-v6 §10 인계 1의 나머지 절반).
	var boss_status := StatusEngine.active_list(st_state)
	if not boss_status.is_empty():
		var tint: Color = STATUS_TINTS.get(boss_status[0], GamePalette.TEXT)
		draw_texture_rect_region(texture, destination, mask_source, Color(tint, STATUS_TINT_ALPHA))
	if shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU, 40, GamePalette.BLUE, 5.0)
	if is_stage_boss:
		# 페이즈가 오를 때마다 발밑 고리가 하나씩 늘어난다. 정적 표기(트윈 0)다.
		for index in boss_phase:
			draw_arc(Vector2.ZERO, radius + 8.0 + float(index) * 6.0, 0.0, TAU, 30,
				Color(GamePalette.RED.lightened(0.2), 0.42), 2.0)
		_draw_status_pips()
	# Every abandoned item remains visibly orbiting the king.
	for index in boss_item_ids.size():
		var angle := TAU * float(index) / float(maxi(boss_item_ids.size(), 1)) - visual_time * 0.35
		var item_position := Vector2.from_angle(angle) * (radius + 34.0)
		draw_rect(Rect2(item_position - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), GamePalette.YELLOW.darkened(0.25), true)
		draw_rect(Rect2(item_position - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), GamePalette.TEXT, false, 2.0)
