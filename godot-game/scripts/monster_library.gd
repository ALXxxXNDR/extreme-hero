class_name MonsterLibrary
extends RefCounted

# =============================================================================
# 몬스터 데이터 — W7 재저작(v2 · 7일 클럭) + V2 스테이지 티어 가산(v3)
#                 + Y 웨이브 습성·피격 반응 가산(v4)
# =============================================================================
# **v4(Y 웨이브)가 이 파일에서 한 일은 네 가지다.** 전부 가산이거나 상수 한 줄이다.
#   ① 몬스터마다 `habit` 키를 **추가**했다 — behavior와 직교하는 습성 축(§5.2).
#   ② `kb_sens` · `stun_sens` · `slow_sens` · `hit_flavor`를 **추가**했다 — 피격 반응(§7.2).
#   ③ 지형 × 습성 스폰 가중치 표를 **추가**했다(§5.3).
#   ④ `stage_aggro_gate_ok()`의 하한을 2 → 3으로 올리고 `CYCLE_HEALTH_GAIN`을
#      0.24 → 0.16으로 내렸다(§5.4 · §5.5). 아래 각 자리에 근거를 적어 뒀다.
# **`behavior`(1~4) 값과 10종의 `id`는 한 글자도 바꾸지 않았다** — 호출부가 62곳이다.
# ①②③은 데이터와 조회 함수뿐이고, 실제 동작 연결(enemy.gd · combat_resolver.gd)은
# 다음 웨이브 몫이다. 각 절 머리에 무엇이 남았는지 적어 뒀다.
#
# **v3(V2 웨이브)가 이 파일에서 한 일은 정확히 세 가지다.**
#   ① 몬스터마다 `tier`(1~4) · `stage`(1~5) 키를 **추가**했다(설계 §6.3).
#   ② 스테이지 축 API를 아래쪽 별도 블록으로 **추가**했다(`stage_pool` · `roll_for_stage` …).
#   ③ `cultist`의 표시명을 "월식 주술사"에서 "잠식 주술사"로 바꿨다(시스템 이름 변경 §2.4.
#      id는 그대로다).
# **v2의 일수(`unlock`) 게이팅은 한 줄도 바꾸지 않았다.** game.gd가 아직 그 축으로
# 스폰하고 있고, 스테이지 축으로 갈아끼우는 것은 V4/V5의 일이다. 두 축이 동시에
# 유효해야 그 교체가 안전하다 — `data_test`가 양쪽을 모두 단언한다.
#
# 아래는 v2 W7 당시의 원본 주석이다(일수 축 규칙의 근거).
# =============================================================================
# 기준: docs/GAME_DESIGN_V2.md §4.1(7일 일정) · §9.3(몬스터 10종·체력 계수) ·
#       §9.5(최상위 slash_hits 상한) · §7 W7
#
# v1에서 달라진 점
#   ① 13종 → **10종**(§9.3). id는 전부 v1 그대로라 art/external/INVENTORY.md의
#      에셋 매핑이 그대로 산다(내린 3종은 그 표에서만 빠진다).
#   ② `unlock`이 이제 **일수(1~7)**를 뜻한다. game.gd의 `cycle_number`가 W0/W4에서
#      `clock.day_number`의 별칭이 되었으므로(game.gd L202~208) 게이팅 함수의
#      **시그니처를 하나도 바꾸지 않고** 의미만 재해석했다. §4.1의 "게이팅 코드는
#      손대지 않는다. 상수만 재매핑"을 그대로 따랐다.
#   ③ 해금 곡선을 7일에 맞춰 압축: 최대 unlock 6(§7 W7 완료 기준 "unlock ≤ 6").
#   ④ `CYCLE_HEALTH_GAIN` 0.18 → 0.28(§9.3), 최상위 `slash_hits` 상한 10(§9.5).
#
# **"주기 = 일수"의 단일 대응표** — 이 파일의 모든 cycle 인자는 곧 일수다.
#   1일: 순한 몹만(선공몹 낮 차단)   2일: 신규 1종
#   3일: 선공몹 낮 해금              4일: 원거리 해금
#   5일: 상위 2종                    6일: 최상위 1종      7일: 신규 없음(강림 준비)

# 몬스터 체력의 단일 기준값.
# BASE_SLASH_DAMAGE는 검사 기본 피해(player.gd damage 16.0)와 기본 베기 배율
# (deal_card_library.gd BASIC damage 1.0)을 곱한 값, 즉 "기본 베기 1방"이다.
# 각 몬스터의 slash_hits는 1일차(power_level 0) 기준으로 기본 베기 몇 방을
# 버티는지를 그대로 적는다. 실제 체력은 health_for()가 계산한다.
const BASE_SLASH_DAMAGE := 16.0
# power_level 1당 체력 증가 비율. §9.3에서 0.18 → 0.28.
#
# **주의(W12 밸런스 패스가 반드시 볼 것)**: §9.3의 근거는 "7일차 ×2.68"인데 그 계산은
# power_level == day − 1을 가정한다. 실제 필드 스폰은 core/combat_resolver.gd L245의
# `(day−1)×1.1 + (level−1)×0.32 + min(경과/180, 2.5)`라 7일차·레벨 15에서 ≈13.6이다.
# 즉 실체력 배율은 ×2.68이 아니라 **×4.8**이다(정예·보스 경로는 game.gd L4265의 다른 식).
# §9.5가 이미 "×10.7은 과할 수 있다"며 1차 조정안으로 0.28 → 0.24를 제시해 뒀다.
# W7은 §9.3의 명시값(0.28)을 그대로 넣되 이 사실을 여기 남긴다. 조정은 이 한 줄이다.
#
# **W12 밸런스 1차 패스 (2026-08-07): 0.28 → 0.24로 내렸다. 이전 값 = 0.28.**
# 근거는 위 문단 그대로다 — §9.3의 근거 계산(power_level == day−1)이 실제 스폰식과
# 어긋나 7일차 실체력이 의도한 ×2.68이 아니라 ×4.80이 됐다. §9.5가 예고한 1차 조정안이다.
# 실측(scripts/test/balance_probe.gd): 7일차·레벨 15에서 power_level ≈ 13.6.
#   0.28 → 배율 ×4.80 / 최상위 몹 hellhound 768 HP / 단일표적 처치 5.6초
#   0.24 → 배율 ×4.26 / 최상위 몹 hellhound 682 HP / 단일표적 처치 5.0초
# 광역 카드는 한 번에 여러 기를 때리므로 군집 처리 속도는 이보다 훨씬 빠르다.
#
# **Y 웨이브 밸런스 2차 패스 (2026-08-09): 0.24 → 0.16으로 내렸다. 이전 값 = 0.24.**
# §9.5가 예고하고 §5.5가 확정한 2차 조정이다. 난이도를 체력이 아니라 패턴과 물량으로
# 만들겠다는 방향 전환이라, 내린 만큼 물량·정예 비율·습성 패턴이 올라간다(§5.5 표).
# 7일차·레벨 15(power_level ≈ 13.6)에서 최상위 몹 hellhound의 체력은 이렇게 된다.
#   0.24 → 16.0 × 10.0 × (1 + 0.24 × 13.6) = 682 HP (배율 ×4.264)
#   0.16 → 16.0 × 10.0 × (1 + 0.16 × 13.6) = **508 HP** (배율 ×3.176)
# ⚠️ **508은 계산값이지 실측이 아니다.** 위 식에 숫자를 넣은 결과일 뿐이고, 실제
#    스폰·전투 흐름에서 나오는 값은 Y8이 `scripts/test/balance_probe.gd`로 다시 확정한다.
# ⚠️ §5.5 표는 이 자리를 "682 → 560 HP"로 적었는데, 0.16과 power_level 13.6으로는
#    560이 나오지 않는다. 같은 식으로 계산하면 508이다. 문서 쪽 숫자가 어긋난 것이므로
#    실측 때 함께 고쳐야 한다.
#
# **Y8 밸런스 3차 패스 (2026-08-10): 0.16 → 0.21. 이전 값 = 0.16 (Y1) / 0.24 (W12).**
# ── 왜 되돌렸나 ──────────────────────────────────────────────────────────────
# §5.5는 HP를 **세 축**에서 동시에 내렸는데(`CYCLE_HEALTH_GAIN` · `STAGE_HP_BASE` ·
# dwell `H(d)`) 그 셋이 **곱해진다**. handoff-y1 §8이 이미 경고했다 —
# "`STAGE_HP_BASE` 행만 보면 −25%로 읽히지만 실제는 그 두 배가 넘는다"(−59%).
# Y8이 `balance_probe` ③으로 그 곱을 **런에서 실제로 지나는 다섯 자리마다** 쟀다:
#     0.16 · dwell 0.10/0.007 → 기하평균 지수 **0.580 (−42%)**   목표 −25%를 크게 넘는다
#     0.21 · dwell 0.13/0.010 → 기하평균 지수 **0.75 근처 (−25%)**  ← 의도한 값
# 세 축 중 이 축을 고른 이유:
#   * `STAGE_HP_BASE`의 −25%는 §5.5가 **그 숫자 그대로** 지시했다. 건드리면 문서와 어긋난다.
#   * dwell `H(d)`는 난이도 축이 아니라 **체류 압박** 축이고, 그쪽은 §6.2의 "×2.0"을
#     맞추느라 오히려 올라갔다(`tuning.gd` V3-D 블록).
#   * 남는 것이 이 축이고, 마침 §5.5가 이 축에 대해 **서로 모순된 두 값**을 적었다 —
#     "0.16"과 "hellhound 682 → 560". 0.16으로는 508이 나오고(y1이 지적), 560이 나오려면
#     0.184여야 한다. 어느 쪽도 정본이 아니므로 Y8은 **복리 지수 실측**으로 정했다.
#   0.21 → hellhound @ power 13.6 = 16.0 × 10.0 × (1 + 0.21 × 13.6) = **617 HP**
#   (Y1 이전 682 · Y1 508). 난이도는 여전히 물량·정예·습성이 지고, 이 줄은 후반
#   스테이지가 통째로 물러지는 것만 막는다.
const CYCLE_HEALTH_GAIN := 0.21

# v2 7일 클럭의 총 일수. **해금 게이트 표(`unlock` 1~6)를 검산하기 위한 기준선일 뿐**이고
# 게임의 일수에는 상한이 없다(v3는 `StageClock.day_number`가 무한히 오른다).
# ⚠️ V10(2026-08-09): 짝이었던 `GameTuning.TOTAL_DAYS`는 **삭제됐다.** 이 상수는 남는다 —
#    데이터 파일이 튜닝 파일에 의존하면 standalone 데이터 테스트가 게임 코드를 끌고
#    들어오기 때문에 애초에 독립 선언이었고, 소비자(`data_test`의 해금 곡선 검사)도 살아 있다.
const TOTAL_DAYS_REF := 7
# 신규 몬스터가 마지막으로 등장하는 일수. §7 W7 완료 기준 "몬스터 unlock ≤ 6".
const MAX_UNLOCK_CYCLE := 6

# 원거리(투사체) 몬스터 게이팅 규칙 — 2026-08-04 2차 플레이테스트 피드백 유지.
# enemy.gd에서 일반 마물이 투사체를 쏘는 조건은 active_modules에 "targeting"이
# 들어 있는 경우뿐이다(enemy.gd `if active_modules.has("targeting") and not is_boss`).
# 따라서 아래 표에서 `"module":"targeting"`을 가진 종이 곧 원거리 몬스터다.
# 사용자 요구: 원거리 몬스터는 초반에 등장하지 않고 중후반부터만 나온다.
# v2 규칙 = §4.1의 "4일차 원거리 몹 해금". 7일 중 4일차 = 진행의 57% 지점이다.
#
# targeting이 붙는 경로는 두 개이며 둘 다 아래 ranged_gate_ok(cycle) 한 곳을 통과한다.
#   ① 네이티브 몬스터: 이 표의 module 필드 + roll()의 unlock 필터
#   ② 부채(rejected_skills) 기반 랜덤 모듈: enemy.gd setup()의 debt 루프
const RANGED_MODULE := "targeting"
# 원거리 해금 하한(=§4.1 4일차). 아래 검증 함수와 문서가 같이 참조한다.
const RANGED_MIN_UNLOCK_CYCLE := 4
# 일수가 오를수록 1일차 몬스터 비중을 줄이는 감쇠. 7일 곡선에 맞춰 v1(0.11/0.38)에서
# 조금 가파르게 했다. 3일:0.87 → 5일:0.61 → 7일:0.35(바닥 0.34).
const EARLY_MONSTER_DECAY_STEP := 0.13
const EARLY_MONSTER_DECAY_FLOOR := 0.34

# 낮 선공몹(behavior 4) 게이팅 규칙 — 2026-08-04 3차 플레이테스트 피드백 ⑭ 유지.
# 사용자 요구 원문: "초반부터 선공 몹 안 나오게 해줘. 처음에는 순한 몹만 있으면 돼.
# 난이도가 어려워질수록 나오면 돼." (낮 한정)
#
# behavior 4 = 기본 선공, 시야에 들어오면 추적(enemy.gd `behavior_type == 4`).
# behavior 1~3(도망/반격/집단 반격)은 비선공이라 게이팅 대상이 아니다.
# 밤은 행동 유형과 무관하게 전원 습격 모드(enemy.gd set_night_raid)라 별개 시스템이고
# 사용자도 "낮"이라고 명시했으므로 이 게이트를 적용하지 않는다.
#
# **v2 재매핑: 5 → 3** (§4.1 "3일차 · 선공몹 해금", §7 W7 작업 ③).
# v1의 5는 라운드가 무한이던 시절의 값이라 7일 런에서는 5·6·7일 사흘만 남는다.
# 1·2일차 낮은 여전히 완전히 평화롭고, 밤은 1일차부터 선공몹이 나온다.
const AGGRO_BEHAVIOR := 4
const AGGRO_DAY_UNLOCK_CYCLE := 3
# 해금 직후 낮 선공몹 가중치 배율과 일차당 램프업 폭.
# 3일:0.25 → 4일:0.40 → 5일:0.55 → 6일:0.70 → 7일:0.85
const AGGRO_DAY_WEIGHT_BASE := 0.25
const AGGRO_DAY_WEIGHT_RAMP := 0.15

# -----------------------------------------------------------------------------
# 몬스터 10종 (§9.3). unlock = 처음 등장하는 **일수**.
#
#  일 | 신규            | 비고
#  ---|-----------------|--------------------------------------------------
#   1 | 이끼콩·들멧돼지·뿔임프·붉은 늑대 | 늑대는 밤 전용(낮은 3일차부터)
#   2 | 떠도는 해골      |
#   3 | 굶주린 그림자    | 낮 선공몹 해금일
#   4 | 푸른 위습        | 원거리 해금일(targeting)
#   5 | 황야 오우거·잠식 주술사 | 월식 계열(v3에서 잠식으로 이름을 바꿨다, §4.1)
#   6 | 밤의 지옥견      | 최상위. slash_hits 10 = §9.5의 상한
#
# Y 웨이브가 얹은 키(값의 뜻은 아래 두 절에 적어 뒀다)
#   `habit`                  습성. behavior와 직교하는 축(§5.2)
#   `kb_sens`/`stun_sens`/`slow_sens`  넉백·경직·둔화 민감도. 1.0이 보통(§7.2)
#   `hit_flavor`             맞았을 때 어떻게 보이는가. 연출 담당이 읽는 한 줄(§7.2)
#   `kb_zero_while_charging` 들멧돼지 전용. 돌진 중에는 넉백이 아예 0이다
# -----------------------------------------------------------------------------
const MONSTERS: Array[Dictionary] = [
	{"id":"mossling", "name":"이끼콩", "behavior":1, "habit":"herd", "unlock":1, "tier":1, "stage":1, "weight":24.0, "growth":0.0, "night_mul":1.3, "visual":"blob", "slash_hits":2.6, "speed":1.0, "damage":1.0, "xp":1, "kb_sens":1.6, "stun_sens":1.4, "slow_sens":1.3, "hit_flavor":"튕겨 날아가며 이끼 조각이 흩어진다"},
	{"id":"boar", "name":"들멧돼지", "behavior":2, "habit":"guard", "unlock":1, "tier":1, "stage":1, "weight":21.0, "growth":0.0, "night_mul":0.72, "visual":"boar", "slash_hits":3.6, "speed":1.0, "damage":1.0, "xp":2, "kb_sens":0.5, "stun_sens":0.7, "slow_sens":0.8, "hit_flavor":"버티고 서서 흙먼지를 일으킨다", "kb_zero_while_charging":true},
	{"id":"imp", "name":"뿔임프", "behavior":3, "habit":"herd", "unlock":1, "tier":1, "stage":1, "weight":17.0, "growth":0.0, "night_mul":0.85, "visual":"imp", "slash_hits":3.2, "speed":1.0, "damage":1.0, "xp":2, "kb_sens":1.1, "stun_sens":1.0, "slow_sens":1.0, "hit_flavor":"뒤로 한 바퀴 구른다"},
	# 1일차 밤부터 나오는 유일한 선공몹. 낮에는 3일차까지 aggro_gate_ok()가 막는다.
	# 이 종이 unlock 1을 유지해야 "1·2일차 밤에도 선공몹이 있다"는 기존 규칙이 산다.
	# v3에서도 stage 1이다 — 1스테이지 밤에 선공몹이 하나도 없으면 밤의 의미가 사라진다.
	{"id":"wolf", "name":"붉은 늑대", "behavior":4, "habit":"hunt", "unlock":1, "tier":1, "stage":1, "weight":12.0, "growth":0.6, "night_mul":0.95, "visual":"wolf", "slash_hits":4.2, "speed":1.05, "damage":1.05, "xp":3, "kb_sens":1.3, "stun_sens":0.8, "slow_sens":1.2, "hit_flavor":"옆으로 쭉 미끄러진다"},
	{"id":"skeleton", "name":"떠도는 해골", "behavior":2, "habit":"guard", "unlock":2, "tier":2, "stage":2, "weight":12.0, "growth":1.2, "night_mul":1.1, "visual":"skeleton", "slash_hits":5.0, "speed":0.82, "damage":1.28, "xp":3, "kb_sens":1.0, "stun_sens":1.5, "slow_sens":0.6, "hit_flavor":"뼈 조각이 튀고 한참 굳어 버린다"},
	{"id":"shade", "name":"굶주린 그림자", "behavior":4, "habit":"stalk", "unlock":3, "tier":2, "stage":2, "weight":9.0, "growth":1.8, "night_mul":1.5, "visual":"shade", "slash_hits":6.0, "speed":1.22, "damage":1.45, "xp":4, "kb_sens":1.8, "stun_sens":1.2, "slow_sens":1.5, "hit_flavor":"반쯤 흩어졌다가 다시 뭉친다"},
	# 원거리 1종. v2는 §4.1의 4일차 해금(unlock 4), v3는 3스테이지 해금(stage 3).
	{"id":"wisp", "name":"푸른 위습", "behavior":3, "habit":"shy", "unlock":4, "tier":3, "stage":3, "weight":5.0, "growth":1.4, "night_mul":1.15, "visual":"wisp", "slash_hits":3.6, "speed":1.15, "damage":1.0, "xp":3, "module":"targeting", "kb_sens":2.0, "stun_sens":1.0, "slow_sens":1.4, "hit_flavor":"저 멀리까지 밀려난다"},
	{"id":"ogre", "name":"황야 오우거", "behavior":2, "habit":"guard", "unlock":5, "tier":3, "stage":3, "weight":5.0, "growth":2.0, "night_mul":1.35, "visual":"ogre", "slash_hits":9.0, "speed":0.6, "damage":2.05, "xp":6, "module":"firewall", "kb_sens":0.25, "stun_sens":0.4, "slow_sens":0.7, "hit_flavor":"거의 밀리지 않고 한 걸음만 물러난다"},
	# v3 개명: 월식 → **잠식**. 시스템 이름이 바뀌었으니 종 이름도 따라간다(id는 그대로).
	{"id":"cultist", "name":"잠식 주술사", "behavior":3, "habit":"stalk", "unlock":5, "tier":3, "stage":4, "weight":5.0, "growth":2.0, "night_mul":1.55, "visual":"cultist", "slash_hits":5.6, "speed":0.9, "damage":1.25, "xp":5, "module":"hotfix", "kb_sens":0.9, "stun_sens":1.1, "slow_sens":1.0, "hit_flavor":"두건이 크게 흔들린다"},
	{"id":"hellhound", "name":"밤의 지옥견", "behavior":4, "habit":"hunt", "unlock":6, "tier":4, "stage":5, "weight":4.5, "growth":2.4, "night_mul":2.1, "visual":"hellhound", "slash_hits":10.0, "speed":1.3, "damage":1.85, "xp":7, "module":"overclock", "kb_sens":0.7, "stun_sens":0.6, "slow_sens":1.1, "hit_flavor":"발톱으로 땅을 긁으며 버틴다"}
]

static func by_id(id: String) -> Dictionary:
	for monster: Dictionary in MONSTERS:
		if monster["id"] == id:
			return monster
	return {}


# =============================================================================
# v4 — 습성(habit) 축 (§5.2)
# =============================================================================
# `behavior`(1~4)는 **값을 그대로 둔다.** 호출부가 62곳이라 숫자가 흔들리면 전투 로직이
# 통째로 흔들린다. 대신 직교하는 새 축 `habit`을 얹는다.
# 둘의 역할은 이렇게 갈린다 — behavior는 "맞았을 때 어떻게 반응하는가",
# habit은 "맞기 전에 필드에서 어떻게 사는가"다. 같은 behavior 2라도 들멧돼지와
# 황야 오우거는 같은 텃세지만, 같은 behavior 3인 뿔임프와 푸른 위습은 무리와 겁쟁이로 갈린다.
#
#  습성  | 이름   | 낮                                          | 밤
#  ------|--------|---------------------------------------------|-----------------------
#  herd  | 무리   | 3~5기가 함께 나와 서로 반경 안에 머물며 배회한다 | 함께 몰려온다
#  shy   | 겁쟁이 | 플레이어를 보면 도망간다(감지 260px)          | 돌변해 덤빈다
#  guard | 텃세   | 자기 자리를 지키다 가까이 오면 반격한다        | 추적한다
#  stalk | 매복   | 멈춰 서 있다가 사거리 안에 들면 급습한다       | 매복 + 이동속도 +20%
#  hunt  | 사냥꾼 | 먼저 본다(3스테이지 낮부터)                  | 추적한다
#
#  몹                    | behavior | habit
#  ----------------------|----------|-------
#  이끼콩 mossling       | 1        | herd
#  들멧돼지 boar         | 2        | guard
#  뿔임프 imp            | 3        | herd
#  붉은 늑대 wolf        | 4        | hunt
#  떠도는 해골 skeleton  | 2        | guard
#  굶주린 그림자 shade   | 4        | stalk
#  푸른 위습 wisp        | 3        | shy
#  황야 오우거 ogre      | 2        | guard
#  잠식 주술사 cultist   | 3        | stalk
#  밤의 지옥견 hellhound | 4        | hunt
#
# ⚠️ **이 파일에는 데이터와 조회 함수만 있다.** 실제 동작 연결은 다음 웨이브 몫이다 —
#    enemy.gd에 새 순회를 만들지 않고, 이미 매 프레임 도는 `_update_field_aggro()`
#    (enemy.gd:635)에 habit 분기를 얹는다. herd의 무리 유지는 기존 `home_position`
#    복귀 로직(enemy.gd:599, 230px)을 그대로 쓰되 `home_position`을 개체가 태어난
#    자리가 아니라 **무리 중심**으로 잡는다.
const HABITS: Array[String] = ["herd", "shy", "guard", "stalk", "hunt"]

## 겁쟁이가 플레이어를 알아채고 도망치기 시작하는 거리(§5.2).
const HABIT_SHY_FLEE_RANGE := 260.0
## 무리가 흩어지지 않는 반경. enemy.gd:599의 복귀 거리(230px)와 같은 값이다.
const HABIT_HERD_RADIUS := 230.0
## 무리가 한 번에 나오는 마릿수와 그 무리가 퍼지는 반경(§5.3).
## 스폰 쪽에서 개체 상한 78을 넘지 않게 잘라 써야 한다.
const HABIT_HERD_SPAWN_MIN := 3
const HABIT_HERD_SPAWN_MAX := 5
const HABIT_HERD_SPAWN_RADIUS := 120.0
## 매복 몹의 밤 이동속도 배율(+20%).
const HABIT_STALK_NIGHT_SPEED := 1.20
## 사냥꾼이 낮에도 먼저 보기 시작하는 스테이지. 아래 `stage_aggro_gate_ok()`의 하한과 같다.
const HABIT_HUNT_DAY_STAGE := 3

## 이 몬스터의 습성. 표에 없거나 모르는 값이면 가장 순한 "herd"로 본다.
static func habit_of(monster: Dictionary) -> String:
	var habit := String(monster.get("habit", ""))
	return habit if HABITS.has(habit) else "herd"

## 습성의 표시 이름.
static func habit_name(habit: String) -> String:
	match habit:
		"herd":
			return "무리"
		"shy":
			return "겁쟁이"
		"guard":
			return "텃세"
		"stalk":
			return "매복"
		"hunt":
			return "사냥꾼"
	return "무리"

## 이 습성이 실제로 어떻게 보이는지 한 줄로. 낮과 밤이 다르다.
static func habit_desc(habit: String, night: bool) -> String:
	match habit:
		"herd":
			return "여럿이 함께 몰려온다" if night else "여럿이 무리 지어 어슬렁거린다"
		"shy":
			return "낮과 달리 돌변해 덤빈다" if night else "플레이어를 보면 도망간다"
		"guard":
			return "자리를 버리고 쫓아온다" if night else "자기 자리를 지키다 가까이 오면 덤빈다"
		"stalk":
			return "숨어 있다가 더 빠르게 덮친다" if night else "멈춰 서 있다가 사거리에 들면 급습한다"
		"hunt":
			return "멀리서부터 쫓아온다" if night else "3스테이지 낮부터 먼저 알아본다"
	return ""

## 습성 → 그 습성을 가진 몬스터 id 목록.
static func habit_ids(habit: String) -> Array[String]:
	var ids: Array[String] = []
	for monster: Dictionary in MONSTERS:
		if habit_of(monster) == habit:
			ids.append(String(monster["id"]))
	return ids

## 습성 표가 §5.2를 지키는지 검사한다. data_test가 이걸 단언한다.
##   ① 모든 몬스터가 HABITS 안의 습성을 하나씩 갖는다(habit_of()의 기본값에 기대지 않는다)
##   ② 다섯 습성이 전부 최소 한 마리씩 쓰인다 — 표에만 있고 필드에 안 나오는 습성이 없다
static func habit_table_ok() -> bool:
	var used: Dictionary = {}
	for monster: Dictionary in MONSTERS:
		var habit := String(monster.get("habit", ""))
		if not HABITS.has(habit):
			return false
		used[habit] = true
	for habit: String in HABITS:
		if not used.has(habit):
			return false
	return true


# =============================================================================
# v4 — 지형 × 습성 스폰 가중치 (§5.3)
# =============================================================================
# 3차 피드백 ⑥ "초원엔 약한 몹이 무리지어 배회"를 데이터로 옮긴 것이다.
# 스폰 지점의 WFC 타일이 습성 가중치를 곱한다.
#
#  지형                        | 가중
#  ----------------------------|-----------
#  풀 grass · tuft · flower    | herd ×1.8
#  숲 forest                   | stalk ×2.2
#  바위 rocks                  | guard ×1.8
#  물가 shore_*                | shy ×1.6
#  폐허 ruins                  | hunt ×1.5
#
# ⚠️ **여기도 데이터뿐이다.** 실제 스폰 연결은 다음 웨이브 몫이다 —
#    combat_resolver의 스폰 경로에서 스폰 지점의 타일 종류를 한 번 물어(O(1) 캐시 조회)
#    이 배율을 곱하면 된다. world_grid.gd는 지금 `get_tile_id()`(정수)만 내주므로
#    타일 이름을 돌려주는 조회 함수도 그쪽 웨이브가 같이 만들어야 한다.
#    herd가 뽑히면 HABIT_HERD_SPAWN_MIN~MAX기를 HABIT_HERD_SPAWN_RADIUS 안에 한꺼번에
#    세우되, 개체 상한 78을 넘지 않게 자른다.
const HABIT_TERRAIN_WEIGHT: Dictionary = {
	"grass":  {"herd": 1.8},
	"tuft":   {"herd": 1.8},
	"flower": {"herd": 1.8},
	"forest": {"stalk": 2.2},
	"rocks":  {"guard": 1.8},
	"shore":  {"shy": 1.6},
	"ruins":  {"hunt": 1.5}
}

## 이 타일 위에서 이 습성에 곱할 스폰 배율. 모르는 타일이거나 표에 없는 습성이면 1.0이다.
## 타일 이름 두 갈래를 여기서 흡수한다.
##   ① 물가 타일은 방향별로 아홉 종류다(`shore_north` · `shore_south_west` …) → "shore" 한 칸
##   ② wfc_chunk_generator의 실제 이름은 `grass_tuft` · `grass_flower`다 → §5.3 표의 tuft · flower
static func habit_terrain_scale(tile_kind: String, habit: String) -> float:
	var key := tile_kind
	if key.begins_with("shore_"):
		key = "shore"
	elif key == "grass_tuft":
		key = "tuft"
	elif key == "grass_flower":
		key = "flower"
	if not HABIT_TERRAIN_WEIGHT.has(key):
		return 1.0
	var row: Dictionary = HABIT_TERRAIN_WEIGHT[key]
	return float(row.get(habit, 1.0))


# =============================================================================
# v4 — 몹별 피격 반응 프로필 (§7.2)
# =============================================================================
# 타격감은 카메라가 아니라 **맞는 쪽**에서 만든다(§7.1). 같은 카드로 때려도 이끼콩은
# 튕겨 날아가고 황야 오우거는 한 걸음만 물러나야 무게가 다르게 느껴진다.
# 세 민감도는 전부 배율이다 — 1.0이 보통, 크면 잘 밀리고 잘 굳고 잘 느려진다.
#
#  몹              | 무게      | kb   | stun | slow
#  ----------------|-----------|------|------|-----
#  이끼콩          | 가벼움    | 1.6  | 1.4  | 1.3
#  들멧돼지        | 무거움    | 0.5  | 0.7  | 0.8   ← 돌진 중에는 넉백 0
#  뿔임프          | 보통      | 1.1  | 1.0  | 1.0
#  붉은 늑대       | 가벼움    | 1.3  | 0.8  | 1.2
#  떠도는 해골     | 보통      | 1.0  | 1.5  | 0.6
#  굶주린 그림자   | 아주 가벼움 | 1.8 | 1.2  | 1.5
#  푸른 위습       | 아주 가벼움 | 2.0 | 1.0  | 1.4
#  황야 오우거     | 아주 무거움 | 0.25| 0.4  | 0.7
#  잠식 주술사     | 보통      | 0.9  | 1.1  | 1.0
#  밤의 지옥견     | 보통      | 0.7  | 0.6  | 1.1
#
# ⚠️ **여기도 데이터뿐이다.** 실제 연결은 다음 웨이브 몫이다 —
#    enemy.gd:744 `apply_hit_reaction()`의 `resistance`에 이 값을 곱한다. 새 순회는 없다.
#    `kb_zero_while_charging`은 들멧돼지에만 붙어 있고, 돌진 중에는 넉백을 0으로 만든다.
## 키가 빠진 몬스터를 읽을 때 쓰는 기본 민감도.
const REACTION_DEFAULT_SENS := 1.0
## 민감도가 이 범위를 벗어나면 표가 잘못 적힌 것으로 본다(reaction_table_ok).
const REACTION_SENS_MIN := 0.1
const REACTION_SENS_MAX := 3.0
## 검사와 읽기가 같은 목록을 보게 하는 단일 지점.
const REACTION_SENS_KEYS: Array[String] = ["kb_sens", "stun_sens", "slow_sens"]

## 이 몬스터의 피격 반응 프로필. 키가 없어도 안전한 기본값으로 채워서 돌려준다.
static func reaction_profile(monster: Dictionary) -> Dictionary:
	return {
		"kb_sens": float(monster.get("kb_sens", REACTION_DEFAULT_SENS)),
		"stun_sens": float(monster.get("stun_sens", REACTION_DEFAULT_SENS)),
		"slow_sens": float(monster.get("slow_sens", REACTION_DEFAULT_SENS)),
		"hit_flavor": String(monster.get("hit_flavor", "")),
		"kb_zero_while_charging": bool(monster.get("kb_zero_while_charging", false))
	}

## 피격 반응 표가 §7.2를 지키는지 검사한다. data_test가 이걸 단언한다.
##   ① 모든 몬스터가 세 민감도를 다 갖는다(reaction_profile()의 기본값에 기대지 않는다)
##   ② 세 값이 전부 REACTION_SENS_MIN~MAX 안의 양수다 — 0이나 음수는 연출을 죽인다
##   ③ 피격 연출 문구가 비어 있지 않다
static func reaction_table_ok() -> bool:
	for monster: Dictionary in MONSTERS:
		for key: String in REACTION_SENS_KEYS:
			if not monster.has(key):
				return false
			var value := float(monster[key])
			if value < REACTION_SENS_MIN or value > REACTION_SENS_MAX:
				return false
		if String(monster.get("hit_flavor", "")).is_empty():
			return false
	return true


# =============================================================================
# v3 — 스테이지 티어 (설계 §6.3 · 부록 B V2 ④)
# =============================================================================
# **v2 API는 한 줄도 바꾸지 않았다.** 아래는 전부 가산이다.
# `unlock`(일수)은 game.gd의 62개 호출부가 아직 쓰고 있고 V4/V5가 스테이지 클럭으로
# 갈아끼울 때까지 살아 있어야 한다. 그때 `spawn_allowed()`의 호출부를
# `stage_spawn_allowed()`로 옮기면 되고, 이 파일은 그 시점에 이미 준비돼 있다.
#
# ── 설계 §6.3의 "몹 풀" 열을 어떻게 읽었는가 ────────────────────────────────
# 표는 스테이지별 풀을 `T1 4종 / T1+T2 6종 / T2+T3 8종 / T3 9종 / T3+T4 10종`으로
# 적는다. 티어 이름은 서로 어긋나지만(T2+T3가 8종이려면 T3=6이어야 하는데 그러면
# 총합이 10을 넘는다) **종 수 4·6·8·9·10은 완전히 일관된다.**
# 그래서 종 수를 정본으로 삼고 풀을 **누적**으로 구현했다. 티어 이름은 "그 스테이지에서
# 새로 합류하는 무리의 격"을 가리키는 라벨로 남긴다.
#
#  스테이지 | 새로 합류        | 누적 종 수 | 설계 표기
#  ---------|------------------|-----------|-------------
#   1       | 이끼콩·들멧돼지·뿔임프·붉은 늑대 (T1) | 4  | T1 4종
#   2       | 떠도는 해골·굶주린 그림자 (T2)        | 6  | T1+T2 6종
#   3       | 푸른 위습·황야 오우거 (T3)            | 8  | T2+T3 8종
#   4       | 잠식 주술사 (T3)                      | 9  | T3 9종
#   5       | 밤의 지옥견 (T4)                      | 10 | T3+T4 10종
#
# 누적을 고른 이유: 스테이지 5에서 이끼콩이 사라지면 dwell 물량 곡선(§6.2의
# `base + 3 × min(d,6)`)이 채울 개체가 없어진다. 상위 몹만 78기를 세우면 그건
# 난이도가 아니라 벽이다. 강해지는 것은 종 구성이 아니라 §6.2의 배율이 한다.
const STAGE_COUNT_REF := 5
## 스테이지별 등장 가능 종 수(§6.3). `stage_table_ok()`가 이 배열과 실제 풀을 대조한다.
const STAGE_SPECIES_COUNT: Array[int] = [4, 6, 8, 9, 10]
## 티어 라벨. 값은 표시·검증용이고 게이팅은 `stage` 필드가 한다.
const TIER_NAMES: Dictionary = {1: "T1 들짐승", 2: "T2 망자", 3: "T3 마물", 4: "T4 심연"}
## 원거리 몹이 처음 등장하는 스테이지. v2의 `RANGED_MIN_UNLOCK_CYCLE`(4일차)에 대응한다.
const RANGED_MIN_STAGE := 3

## 이 몬스터가 처음 등장하는 스테이지(1~5).
static func stage_unlock(monster: Dictionary) -> int:
	return int(monster.get("stage", 1))

## 이 몬스터의 티어(1~4).
static func tier_of(monster: Dictionary) -> int:
	return int(monster.get("tier", 1))

## 티어 → 그 티어에 속한 몬스터 id 목록.
static func tier_ids(tier: int) -> Array[String]:
	var ids: Array[String] = []
	for monster: Dictionary in MONSTERS:
		if tier_of(monster) == tier:
			ids.append(String(monster["id"]))
	return ids

## 이 스테이지에서 등장 가능한 몬스터 전량(누적). 스테이지 풀의 단일 정의 지점.
static func stage_pool(stage: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for monster: Dictionary in MONSTERS:
		if stage_unlock(monster) <= stage:
			pool.append(monster)
	return pool

## 스테이지 기반 스폰 게이트. v2 `spawn_allowed()`의 스테이지 판이다.
## 낮 선공몹 게이트는 사용자 요구("처음에는 순한 몹만")를 스테이지 축으로 옮긴 것이다 —
## 일수가 무한해진 이상 일차 기반 게이트는 의미가 없다.
## v3에서는 1스테이지 낮만 막았고, **v4(§5.4)부터 1·2스테이지 낮을 막는다.**
## 판단은 전부 `stage_aggro_gate_ok()` 한 곳에 있다.
static func stage_spawn_allowed(monster: Dictionary, stage: int, night: bool, allow_aggro_override: bool = false) -> bool:
	if stage_unlock(monster) > stage:
		return false
	if int(monster["behavior"]) == AGGRO_BEHAVIOR and not allow_aggro_override and not stage_aggro_gate_ok(stage, night):
		return false
	return true

## 이 스테이지·시간대에 낮 선공몹(behavior 4)을 스폰해도 되는가. 밤은 항상 통과한다
## (밤은 행동 유형과 무관하게 전원 습격 모드라 별개 시스템이다).
##
## **Y 웨이브 §5.4: 하한을 2 → 3으로 올렸다. 이전 값은 `stage >= 2`였다.**
## 효과는 한 줄로 끝난다 — 1·2스테이지 **낮**에는 behavior 4인 세 종
## (붉은 늑대 · 굶주린 그림자 · 밤의 지옥견)이 아예 안 나온다.
## 밤은 그대로 전원 습격이다. 1스테이지 밤에도 늑대가 있어야 밤의 의미가 산다 —
## MONSTERS 표의 wolf 주석이 그 판단을 이미 적어 뒀다.
##
## 여기에 `shy` 습성 몹은 낮에 도망가므로(§5.2), 1·2스테이지 낮 필드에는
## "무리 지어 배회하는 순한 것들 + 도망가는 것들"만 남는다. 피드백 ⑥이 요청한 그림이다.
## 다만 지금 `shy`는 푸른 위습 하나뿐이고 그 종은 3스테이지에 합류하므로, 실제로
## 1·2스테이지 낮에 서는 것은 무리(이끼콩 · 뿔임프)와 텃세(들멧돼지 · 떠도는 해골)뿐이다.
## "도망가는 것들"이 실제로 보이는 것은 3스테이지부터다.
static func stage_aggro_gate_ok(stage: int, night: bool) -> bool:
	return night or stage >= 3

## 스테이지별 등장 가중치. dwell 배율은 combat_resolver(V4 소유)가 따로 곱한다 —
## 이 함수는 **구성비만** 낸다. 밤 배율과 신규 합류 몹의 램프업만 반영한다.
static func stage_spawn_weight(monster: Dictionary, stage: int, night: bool) -> float:
	var age := maxi(0, stage - stage_unlock(monster))
	var weight := float(monster["weight"]) + float(monster["growth"]) * float(age)
	# 스테이지가 오를수록 T1 들짐승의 비중을 줄여 상위 티어에 자리를 넘긴다.
	# v2의 일수 감쇠(EARLY_MONSTER_DECAY_*)와 같은 규칙을 스테이지 축으로 옮긴 것이다.
	if tier_of(monster) == 1 and stage >= 2:
		weight *= maxf(EARLY_MONSTER_DECAY_FLOOR, 1.0 - float(stage - 1) * EARLY_MONSTER_DECAY_STEP * 2.0)
	if night:
		weight *= float(monster["night_mul"])
	return weight

## 스테이지 스폰 표(밸런스 검토·테스트용). v2 `spawn_table()`과 같은 모양을 낸다.
static func stage_spawn_table(stage: int, night: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var total := 0.0
	for monster: Dictionary in MONSTERS:
		if not stage_spawn_allowed(monster, stage, night):
			continue
		var weight := stage_spawn_weight(monster, stage, night)
		rows.append({
			"id": monster["id"], "weight": weight, "behavior": monster["behavior"],
			"tier": tier_of(monster),
			"ranged": String(monster.get("module", "")) == RANGED_MODULE
		})
		total += weight
	for row: Dictionary in rows:
		row["share"] = 0.0 if total <= 0.0 else float(row["weight"]) / total
	return rows

## 스테이지 티어 표가 설계 §6.3을 지키는지 검사한다. data_test가 이걸 단언한다.
##   ① 스테이지 1~5의 누적 종 수가 STAGE_SPECIES_COUNT와 정확히 같다
##   ② 모든 몬스터의 stage가 1~5, tier가 1~4
##   ③ tier와 stage가 단조 정합(상위 티어가 하위 티어보다 먼저 나오지 않는다)
##   ④ 원거리 몹이 RANGED_MIN_STAGE보다 이르게 등장하지 않는다
static func stage_table_ok() -> bool:
	for index in range(STAGE_SPECIES_COUNT.size()):
		if stage_pool(index + 1).size() != STAGE_SPECIES_COUNT[index]:
			return false
	var max_tier_before: Dictionary = {}
	for monster: Dictionary in MONSTERS:
		var stage := stage_unlock(monster)
		var tier := tier_of(monster)
		if stage < 1 or stage > STAGE_COUNT_REF:
			return false
		if tier < 1 or tier > 4:
			return false
		if String(monster.get("module", "")) == RANGED_MODULE and stage < RANGED_MIN_STAGE:
			return false
		var seen: int = int(max_tier_before.get(stage, 0))
		max_tier_before[stage] = maxi(seen, tier)
	# 스테이지가 오를수록 그 스테이지에 합류하는 최고 티어가 줄어들면 안 된다.
	var previous := 0
	for stage in range(1, STAGE_COUNT_REF + 1):
		var here: int = int(max_tier_before.get(stage, previous))
		if here < previous:
			return false
		previous = here
	return true

## 스테이지 기반 스폰 굴림. v2 `roll()`의 스테이지 판이다(구조·폴백 규칙 동일).
static func roll_for_stage(rng: RandomNumberGenerator, stage: int, night: bool, forced_behavior: int = 0, allow_aggro_override: bool = false) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for monster: Dictionary in MONSTERS:
		if not stage_spawn_allowed(monster, stage, night, allow_aggro_override):
			continue
		if forced_behavior > 0 and int(monster["behavior"]) != forced_behavior:
			continue
		var weight := stage_spawn_weight(monster, stage, night)
		var entry := monster.duplicate(true)
		entry["rolled_weight"] = weight
		candidates.append(entry)
		total_weight += weight
	if candidates.is_empty():
		if forced_behavior > 0:
			return roll_for_stage(rng, stage, night, 0, allow_aggro_override)
		return by_id("mossling")
	if total_weight <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll_value := rng.randf_range(0.0, total_weight)
	for candidate: Dictionary in candidates:
		roll_value -= float(candidate["rolled_weight"])
		if roll_value <= 0.0:
			return candidate
	return candidates.back()

## 이 몬스터가 처음 등장하는 일수. `unlock`의 v2 의미를 이름으로 못 박아 둔다.
static func unlock_day(monster: Dictionary) -> int:
	return int(monster.get("unlock", 1))

## 일수 → 그날 새로 등장하는 몬스터 id 목록. 해금 곡선 문서화·검증용.
static func unlock_schedule() -> Dictionary:
	var schedule: Dictionary = {}
	for day in range(1, TOTAL_DAYS_REF + 1):
		schedule[day] = []
	for monster: Dictionary in MONSTERS:
		var day := unlock_day(monster)
		if schedule.has(day):
			(schedule[day] as Array).append(String(monster["id"]))
	return schedule

## 해금 표가 7일 곡선을 지키는지 검사한다(1 ≤ unlock ≤ MAX_UNLOCK_CYCLE, 1일차 존재).
static func unlock_table_ok() -> bool:
	var has_day_one := false
	for monster: Dictionary in MONSTERS:
		var day := unlock_day(monster)
		if day < 1 or day > MAX_UNLOCK_CYCLE:
			return false
		if day == 1:
			has_day_one = true
	return has_day_one

# 원거리(투사체) 몬스터 목록. enemy.gd의 발사 조건과 같은 기준을 쓴다.
static func ranged_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster: Dictionary in MONSTERS:
		if String(monster.get("module", "")) == RANGED_MODULE:
			ids.append(String(monster["id"]))
	return ids

# 원거리 행동이 열리는 최소 일수. MONSTERS 표에서 targeting을 가진 종 중 가장
# 이른 unlock을 그대로 사용하므로 규칙의 출처는 위 표 한 곳뿐이다.
# targeting 종이 하나도 없으면 부채 기반 targeting에만 규칙이 남으므로 하한 상수로 폴백한다.
static func ranged_unlock_cycle() -> int:
	var earliest := -1
	for monster: Dictionary in MONSTERS:
		if String(monster.get("module", "")) != RANGED_MODULE:
			continue
		earliest = int(monster["unlock"]) if earliest < 0 else mini(earliest, int(monster["unlock"]))
	return RANGED_MIN_UNLOCK_CYCLE if earliest < 0 else earliest

# 이 일수에서 원거리(투사체) 공격을 허용해도 되는가. 초반 원거리 배제의 단일 관문.
# 네이티브 몬스터 해금과 enemy.gd의 부채 기반 랜덤 모듈이 같은 답을 쓴다.
static func ranged_gate_ok(cycle: int) -> bool:
	return cycle >= ranged_unlock_cycle()

# MONSTERS 표 자체가 초반 원거리 배제 규칙을 지키는지 검사한다. 밸런스 회귀 방지용.
static func ranged_table_ok() -> bool:
	for monster: Dictionary in MONSTERS:
		if String(monster.get("module", "")) == RANGED_MODULE and int(monster["unlock"]) < RANGED_MIN_UNLOCK_CYCLE:
			return false
	return true

# 이 일수에서 낮 선공몹(behavior 4)을 스폰해도 되는가. 초반 낮 평화의 단일 관문.
# 밤(night=true)은 원래 전원 어그로인 별개 시스템이므로 항상 통과한다.
static func aggro_gate_ok(cycle: int, night: bool) -> bool:
	return night or cycle >= AGGRO_DAY_UNLOCK_CYCLE

# 해금 이후 낮 선공몹에 곱하는 가중치 배율. 일수가 오를수록 1.0까지 램프업한다.
static func aggro_day_weight_scale(cycle: int) -> float:
	var age := maxi(0, cycle - AGGRO_DAY_UNLOCK_CYCLE)
	return clampf(AGGRO_DAY_WEIGHT_BASE + AGGRO_DAY_WEIGHT_RAMP * float(age), 0.0, 1.0)

# 이 몬스터가 이 일수/시간대의 스폰 후보가 될 수 있는가.
# roll()과 spawn_table()이 같은 필터를 쓰게 하는 단일 지점이다.
# allow_aggro_override=true는 강제 스폰 경로(균열 정예·전조·미믹·보스 하수인·테스트)가
# 낮 선공몹 게이트를 의도적으로 건너뛸 때만 쓴다.
static func spawn_allowed(monster: Dictionary, cycle: int, night: bool, allow_aggro_override: bool = false) -> bool:
	if int(monster["unlock"]) > cycle:
		return false
	if int(monster["behavior"]) == AGGRO_BEHAVIOR and not allow_aggro_override and not aggro_gate_ok(cycle, night):
		return false
	return true

# 등장 가중치의 단일 계산 지점. roll()과 spawn_table()이 같은 식을 쓰도록 한다.
static func spawn_weight(monster: Dictionary, cycle: int, night: bool) -> float:
	var age := maxi(0, cycle - int(monster["unlock"]))
	var weight := float(monster["weight"]) + float(monster["growth"]) * age
	# 3일차 이후에는 1일차 몬스터 비중을 서서히 줄여 상위 몬스터에 자리를 넘긴다.
	if int(monster["unlock"]) == 1 and cycle >= 3:
		weight *= maxf(EARLY_MONSTER_DECAY_FLOOR, 1.0 - float(cycle - 2) * EARLY_MONSTER_DECAY_STEP)
	if night:
		weight *= float(monster["night_mul"])
	elif int(monster["behavior"]) == AGGRO_BEHAVIOR:
		# 낮 선공몹은 해금 직후 몰려나오지 않게 눌러두고 일차마다 램프업한다.
		# 해금 전(게이트 차단 구간)은 spawn_allowed()가 후보에서 아예 제외한다.
		weight *= aggro_day_weight_scale(cycle)
	return weight

# 특정 일수/시간대에 등장 가능한 몬스터와 정규화된 등장 확률. 밸런스 검토용.
static func spawn_table(cycle: int, night: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var total := 0.0
	for monster: Dictionary in MONSTERS:
		if not spawn_allowed(monster, cycle, night):
			continue
		var weight := spawn_weight(monster, cycle, night)
		rows.append({"id":monster["id"], "weight":weight, "behavior":monster["behavior"], "ranged":String(monster.get("module", "")) == RANGED_MODULE})
		total += weight
	for row: Dictionary in rows:
		row["share"] = 0.0 if total <= 0.0 else float(row["weight"]) / total
	return rows

# 몬스터 최대 체력의 단일 계산 지점. enemy.gd는 이 값만 사용한다.
static func health_for(archetype: Dictionary, power_level: float) -> float:
	var hits := maxf(0.5, float(archetype.get("slash_hits", 3.0)))
	var scale := 1.0 + CYCLE_HEALTH_GAIN * maxf(power_level, 0.0)
	return BASE_SLASH_DAMAGE * hits * scale

static func roll(rng: RandomNumberGenerator, cycle: int, night: bool, forced_behavior: int = 0, allow_aggro_override: bool = false) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for monster: Dictionary in MONSTERS:
		if not spawn_allowed(monster, cycle, night, allow_aggro_override):
			continue
		if forced_behavior > 0 and int(monster["behavior"]) != forced_behavior:
			continue
		var weight := spawn_weight(monster, cycle, night)
		var entry := monster.duplicate(true)
		entry["rolled_weight"] = weight
		candidates.append(entry)
		total_weight += weight
	if candidates.is_empty():
		# 강제 behavior가 해금/게이트와 충돌하면 행동 강제를 풀고 다시 굴린다.
		# 낮 초반에 behavior 4를 강제한 경로(런 시작 스타터 population 등)는
		# 죽지 않고 그 일수에서 허용된 순한 몹으로 대체된다.
		if forced_behavior > 0:
			return roll(rng, cycle, night, 0, allow_aggro_override)
		return by_id("mossling")
	if total_weight <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll_value := rng.randf_range(0.0, total_weight)
	for candidate: Dictionary in candidates:
		roll_value -= float(candidate["rolled_weight"])
		if roll_value <= 0.0:
			return candidate
	return candidates.back()
