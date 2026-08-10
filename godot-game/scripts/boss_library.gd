class_name BossLibrary
extends RefCounted

# =============================================================================
# V2 — 스테이지 보스 3종 (신규 · v3)
# =============================================================================
# 기준: docs/GAME_DESIGN_V3.md §3.1(에셋 선정) · §3.2(3칸) · §3.3(패턴) ·
#       §3.4(강화형 파생) · 부록 A-1 ③ · 부록 A-2 ⑫ · 부록 B V2 ⑥
#
# ── 이 파일이 소유하는 것 ────────────────────────────────────────────────────
#   * 보스 3종(A·B·C)의 **딜싸이클 패턴 데이터**. 카드와 **같은 스키마**다 —
#     그래야 `DealCycleController` / `FactoryDeck` / 마왕 레일 밴드 HUD가
#     한 줄도 안 고치고 그대로 먹는다(§3.2 "구현 비용 0에 가깝다").
#     추가 키는 딱 둘이다: `status`(부여할 상태이상 id) · `telegraph`(선딜, 초).
#   * 보스별 스프라이트 리그 명세(디렉터리·셀 크기·보유 애니메이션·틴트).
#     실측표는 §3.1이고 여기 옮겨 적은 것은 **에셋 파이프라인(V3)과 런타임(V7)이
#     같은 표를 보게** 하기 위해서다.
#
# ── 이 파일이 소유하지 **않는** 것 ───────────────────────────────────────────
#   * 로테이션 [A, B, C, B+, C+] → `GameTuning.STAGE_BOSS_DESIGN` / `_ENHANCED`.
#   * 강화형 파생 계수(칸 수·RELOAD·telegraph 배율·상태 종수·페이즈)
#                              → `GameTuning`의 V3-G 블록. **패턴이 아니라 규칙이다.**
#   * 상태이상 5종의 지속·중첩·계수 → `GameTuning`의 V3-K/V3-L 블록(StatusEngine이 읽는다).
#   * 마왕 → `core/demon_lord.gd`. **5칸 + 각인은 마왕만 가진다**(부록 A-2 ⑫).
#     (과열은 Y0에서 규칙째 폐기됐고 Y8이 셔틀 상수까지 지웠다 — 이제 아무도 안 가진다.)
#
# ── 보스 딜싸이클이 3칸인 이유 (§3.2) ────────────────────────────────────────
#   "마왕은 플레이어와 완전히 같은 런타임을 쓴다"가 v2의 핵심 서사다. 스테이지 보스까지
#   5칸 + 각인이면 마왕은 그냥 여섯 번째 보스가 된다. 그래서 스테이지 보스는
#   **3칸(강화형 4칸) · 각인 없음 · RELOAD만 공유**한다.
#   플레이어는 1스테이지에서 "보스가 칸을 도는 동안 피하고 RELOAD에 때린다"를 배우고
#   마왕에서 졸업한다. **그 교육이 성립하려면 RELOAD 창이 충분히 길어야 한다** —
#   Y8이 `STAGE_BOSS_RELOAD_MUL`을 0.75 → 0.90으로 올린 근거가 그것이다(tuning.gd V3-G).
#   Y8: 여기 있던 `RuneEngine.triangle_ok()` 안전성 각주는 지웠다 — 그 함수가 삭제됐다
#   (삼각 배열 규칙은 §1.4에서 폐기됐고 3칸/5칸 어느 쪽에도 남은 분기가 없다).

## 패턴 딕셔너리가 반드시 가져야 하는 키. 카드 스키마 + `status` + `telegraph`.
## `debt_desc`는 없다 — 보스 패턴은 마왕에게 넘어가지 않는다.
const PATTERN_REQUIRED_KEYS: Array[String] = [
	"id", "name", "symbol", "kind", "element", "form", "desc",
	"damage", "duration", "action_ratio", "reload", "range", "arc", "hits",
	"color", "status", "telegraph"
]

## 기본형이 쓰는 패턴 수. 강화형은 여기에 4번 패턴을 하나 더 켠다(§3.4).
const BASE_PATTERN_COUNT := 3
const ENHANCED_PATTERN_COUNT := 4

# -----------------------------------------------------------------------------
# BOSS_DESIGN_HP — **V10(2026-08-09)이 실측으로 확정했다**
# -----------------------------------------------------------------------------
# §3.4는 식만 준다:
#     hp = BOSS_DESIGN_HP[design] × STAGE_HP_BASE[stage] × (1 + 0.08 × dwell)
# `STAGE_HP_BASE`와 `0.08`은 `GameTuning`(V3-E · V3-G)에 있고 왼쪽 항이 비어 있었다.
#
# ── V2~V7의 값은 뼈대였다 ────────────────────────────────────────────────────
# A 2600 / B 3200 / C 3800은 "자릿수만 맞춘 값"이었다(근거는 v2 실측 두 개 —
# 최상위 몹 682 HP · 마왕 기저 611 HP). 목표 전투 길이에서 역산한 것이 **아니었다.**
#
# ── V10이 실제로 잰 것 (`scripts/test/balance_probe.gd` ⑫) ────────────────────
# V7이 스테이지 보스에게 상태이상을 열어 준 뒤로 원소 덱은 피해의 14~43%를 도트·시너지로
# 낸다. 그 레이어를 세지 않은 옛 모델로는 전투 길이를 예측할 수 없었다. 프로브는
# `StatusEngine`을 그대로 돌려 기름+불·독 축적·무상태 세 덱의 실효 DPS를 냈다.
#
#   조정 전 (uptime 0.62 · dwell 3 · 스테이지 표준 덱)
#     1스테이지 A   3,224 HP →  64초   ok
#     2스테이지 B   6,150 HP → 103초   **목표 45~90초 초과**
#     3스테이지 C   9,895 HP → 110초   **초과**
#     4스테이지 B+ 10,515 HP →  88초   ok(상한 턱걸이)
#     5스테이지 C+ 15,078 HP →  87초   ok(상한 턱걸이)
#
#   목표 창 한가운데(67.5초)로 되돌리는 역산 — 한 디자인이 두 스테이지에 나오므로
#   (B는 2·4 · C는 3·5) 두 배수의 **기하평균**을 쓴다:
#     A ×1.06(등장 1회) · B ×0.71(2회) · C ×0.69(2회)
#
#   조정 후 예측 TTK: 68 / 73 / 76 / 62 / 60초. **다섯 관문 전부 창 한가운데**다.
#   덱 축 분산(5스테이지): 기름+불 60초 · 독 축적 75초 · 무상태 77초 — 전부 창 안.
#
# ⚠️ 이 표는 **uptime 0.62 가정**에 걸려 있다(프로브 `BOSS_UPTIME`). 그래서 프로브는
#    0.50 / 0.62 / 0.72 세 값을 함께 찍는다. 0.50에서는 2·3스테이지가 91·94초로 창을
#    조금 넘고, 0.72에서는 다섯 전부 52~65초다. 실기에서 보스전이 지루하면 uptime
#    가정이 높았던 것이니 이 세 숫자를 더 내리면 된다.
# **이전 값(플레이테스트 후 롤백용)**: A 2600 / B 3200 / C 3800
#
# -----------------------------------------------------------------------------
# ── Y8(2026-08-10) 재확정 — **목표 창이 45~90초에서 30~60초로 내려왔다** ──────
# -----------------------------------------------------------------------------
# 두 가지가 동시에 바뀌어 V10 표가 통째로 낡았다.
#   ① **목표 창.** Y8 지시가 스테이지 보스를 **30~60초**로 못 박았다(설계 문서가 아니라
#      플레이 감각 판단이다). V10의 45~90은 이 주석의 이력으로만 남는다.
#   ② **플레이어 DPS 곡선.** 과열이 사라지고 칸당 실행 2회 상한이 들어왔고(§1.2),
#      각인이 신 15종으로 전면 교체됐으며, **레일 각인 3종이 피해·시간에 직접 곱해진다.**
#      V10의 프로브는 폐기된 구 각인 id를 써서 실제로는 **각인 0개짜리 덱**을 재고 있었다
#      (handoff-y8 §2). 즉 V10의 DPS 값은 지금 기준으로 과소평가였다.
#
# ── Y8이 실제로 잰 것 (`scripts/test/balance_probe.gd` ⑨ · uptime 0.62 · dwell 2) ──
#   조정 전 (A 2750 / B 2270 / C 2620)
#     1st A   3,190 HP · raw 88.5  → 58초  ok
#     2st B   3,555 HP · raw 116.3 → 49초  ok
#     3st C   5,167 HP · raw 180.7 → 46초  ok
#     4st B+  5,398 HP · raw 245.2 → 36초  ok
#     5st C+  7,294 HP · raw 394.3 → **30초** 창 하한을 밟는다
#   창 한가운데(45초)로 되돌리는 역산 — 한 디자인이 두 스테이지에 나오므로(B는 2·4 ·
#   C는 3·5) 두 배수의 **기하평균**을 쓴다: A ×0.77 · B ×1.08 · C ×1.21.
#
#   조정 후 예측 TTK: **45 / 53 / 56 / 38 / 36초.** 다섯 관문 전부 30~60 안이다.
#   기울기가 뒤로 갈수록 짧아지는 것은 의도다 — 마지막 관문에서 덱이 완성되는 게임이라
#   5스테이지 보스가 1스테이지 보스보다 오래 버티면 "성장했다"가 안 읽힌다.
#
# ⚠️ 이 표는 **uptime 0.62 가정**에 걸려 있다(프로브 `BOSS_UPTIME`). 프로브는 0.50 /
#    0.62 / 0.72 세 값을 함께 찍는다. 0.50에서는 2·3스테이지가 창 위로 조금 나가고,
#    0.72에서는 다섯 전부 31~48초다. 실기에서 보스전이 지루하면 가정이 높았던 것이다.
# **Y8 이전 값(롤백용)**: A 2750 / B 2270 / C 2620
const DESIGN_HP: Dictionary = {
	"A": 2130.0,   # 이전 2750 (×0.77) — 유일한 1회 등장. 창이 내려온 만큼 그대로 내렸다
	"B": 2440.0,   # 이전 2270 (×1.08) — 분열 소환(본체 12% × 3기)이 실효 체력을 +36% 얹는다
	"C": 3180.0    # 이전 2620 (×1.21) — 기름→불 콤보의 표적이라 상태 피해를 가장 많이 받는다
}
## `hp_for()`가 쓰는 dwell 계수의 폴백. 정본은 `GameTuning.STAGE_BOSS_HP_DWELL_STEP`.
const HP_DWELL_STEP_FALLBACK := 0.08

# -----------------------------------------------------------------------------
# 스프라이트 리그 (§3.1 실측표)
# -----------------------------------------------------------------------------
# 프레임 수는 `sips`로 확인한 실제 픽셀 크기 ÷ 프레임 한 변이다(설계가 직접 쟀다).
# **등장 횟수에 리그 풍부도를 맞췄다** — 로테이션에서 A는 1회, B·C는 각 2회 나온다.
# 그래서 A에 가장 얇은 리그(Attack 없음)를, C에 가장 풍부한 리그를 배치했다.
#
# `tint`가 비어 있지 않으면 `_apply_tint`로 색 변종을 굽는다(V3 에셋 웨이브).
# `intro_anim`이 비어 있지 않으면 등장 연출로 그 애니메이션을 한 번 재생한다.
const RIGS: Dictionary = {
	"A": {
		"design": "A", "name": "서릿발 외눈", "source": "DemonCyclop2",
		"cell": Vector2i(50, 50), "tint": "", "intro_anim": "",
		"anims": {"idle": 5, "walk": 6, "hit": 3},
		# ⚠️ **Attack 애니메이션이 없다.** 설계는 이것을 타협이 아니라 설계로 흡수했다(§3.1):
		#    A의 공격은 팔을 휘두르는 동작이 아니라 **발구름 → 바닥 링 확산**이다.
		#    텔레그래프 = 바닥 원형 VFX + 보스 스케일 펄스(delta 감쇠). 사지 애니메이션이
		#    필요 없다. 플레이테스트에서 시각적으로 밋밋하면 대체 후보는 `GiantBamboo`.
		"no_attack_anim": true,
		"fallback_source": "GiantBamboo"
	},
	"B": {
		"design": "B", "name": "역병 점액왕", "source": "GiantSlime2",
		"cell": Vector2i(62, 52), "tint": "", "intro_anim": "",
		"anims": {"idle": 5, "hit": 5, "jump": 13},
		# Walk/Attack이 없다. 이동과 공격을 **전부 Jump 13f로 처리**한다 — 점액왕이
		# 걷지 않고 튀어 다니는 것이 오히려 종의 성격에 맞는다.
		"no_attack_anim": true, "no_walk_anim": true,
		"fallback_source": ""
	},
	"C": {
		"design": "C", "name": "홍염 천구", "source": "TenguRed",
		"cell": Vector2i(82, 82), "tint": "", "intro_anim": "",
		"anims": {"idle": 6, "walk": 10, "attack": 15, "hit": 8, "trans": 11},
		"no_attack_anim": false,
		"fallback_source": ""
	},
	# --- 강화형 2종: 스프라이트만 다르고 패턴은 기본형에서 파생한다 -------------
	"B+": {
		"design": "B", "name": "흑점액 변종", "source": "GiantSlime",
		"cell": Vector2i(62, 52), "tint": "9a5bb5", "intro_anim": "",
		"anims": {"idle": 5, "hit": 5, "jump": 13},
		"no_attack_anim": true, "no_walk_anim": true,
		"fallback_source": ""
	},
	"C+": {
		"design": "C", "name": "흑천구", "source": "TenguRed",
		"cell": Vector2i(82, 82), "tint": "3b2b46", "intro_anim": "trans",
		# `TenguRed/Trans.png`는 **소형 → 대형 변신 11프레임**이다(실측 확인).
		# C+의 등장 연출로 그대로 쓴다 — 5스테이지 최종 파수꾼의 승급이 눈에 보인다.
		"anims": {"idle": 6, "walk": 10, "attack": 15, "hit": 8, "trans": 11},
		"no_attack_anim": false,
		"fallback_source": ""
	}
}

# -----------------------------------------------------------------------------
# 패턴 데이터 (§3.3)
# -----------------------------------------------------------------------------
# 각 디자인은 패턴 4개를 든다. 기본형은 앞 3개만 쓰고(3칸), 강화형은 4개 전부 쓴다(4칸).
# **§3.3 표가 정본인 것은 `element` · `form` · `telegraph` · 효과 서술 넷이다.**
# 나머지 수치(damage/duration/action_ratio/reload/range/arc/hits)는 설계에 없다 —
# 카드 스케일에 맞춘 **뼈대**이고 V7이 실제로 돌려 보고 V10이 확정한다.
#
#   damage        : 플레이어 카드와 같은 배율 단위(기본 베기 1.0 기준).
#                   **한 번의 시전이 내는 총 피해**다(아래 `hits` 주의 참조).
#   action_ratio  : duration 중 실제 판정이 나가는 구간의 비율(카드와 동일 의미).
#   telegraph     : **v3 신규.** 판정 전 선딜(초). 강화형은 여기에 0.85를 곱한다.
#   status        : **v3 신규.** 맞은 플레이어에게 부여할 상태이상 id.
#                   빈 문자열이면 상태를 부여하지 않는다(B의 분열 패턴).
#   summon / lingering / arena_wide 같은 선택 키는 V7이 실행할 때 읽는 힌트다.
#
# ⚠️ **`hits`와 `pierce`는 카드와 뜻이 다르다** (V10 · handoff-v7 §12-4의 판정).
#   `hits`   : `random_impacts`가 켜진 패턴에서만 **착탄 지점 수**로 소비된다
#              (A2 빙주 3발 · B2 독 장판 3개). 그 밖의 패턴에서는 읽지 않는다 —
#              표적이 플레이어 **한 명뿐**이라 "여러 번 때린다"가 자리 수를 늘리는
#              것 외에는 결국 피해 배수와 같아지고, 그 배수는 이미 `damage`에 들어
#              있다. C2 활공(hits 2)·C3 강하(hits 2)·C4 회오리(hits 5)의 값은
#              **연출 강도의 서술**이지 곱해지는 수가 아니다.
#   `pierce` : 선형 패턴(A3)이 여러 적을 꿰뚫는다는 표시다. 보스의 표적은 플레이어
#              한 명이므로 판정에 영향이 없다. 판정은 "선분 최단거리 ≤ 반경×0.6 + 20"
#              단일 검사다(`game._on_stage_boss_impact`).
#   두 키를 지우지 않은 이유는 **패턴 표가 설계 §3.3의 사본이기 때문**이다. 설계에
#   있는 값을 코드에서 지우면 다음 사람이 표를 대조할 수 없게 된다. 대신 소비 규칙을
#   여기 못 박아 "데이터가 거짓말하지 않게" 했다.
const PATTERNS: Dictionary = {
	# =========================================================================
	# A · 서릿발 외눈 (빙 + 뇌) — "얼리고 감전시킨다" · 1스테이지
	# 교육 목표: **보스도 시너지를 쓴다 / RELOAD가 반격 창이다.**
	# 세 패턴 중 둘이 chill을 깔고 셋째가 그 chill을 먹는다. 가장 느리고 읽기 쉽다.
	# =========================================================================
	"A": [
		{
			"id": "boss_a_stomp", "name": "서리 발구름", "symbol": "A1",
			"kind": "area", "element": "ice", "form": "wave",
			"desc": "발을 구르면 반경 260의 서리 링이 퍼져 나갑니다.",
			"damage": 1.40, "duration": 1.30, "action_ratio": 0.62, "reload": 0.55,
			"range": 260.0, "arc": 6.283, "hits": 1,
			"color": "67c7d4", "status": "chill", "telegraph": 0.55
		},
		{
			"id": "boss_a_icefall", "name": "빙주 낙하", "symbol": "A2",
			"kind": "ground", "element": "ice", "form": "trap",
			"desc": "예고 원 세 개가 떠오른 뒤 얼음 기둥이 떨어집니다. 냉기가 더 깊게 박힙니다.",
			"damage": 1.10, "duration": 1.55, "action_ratio": 0.70, "reload": 0.62,
			"range": 190.0, "arc": 6.283, "hits": 3,
			"random_impacts": true,
			"color": "67c7d4", "status": "chill", "status_power": 1.35, "telegraph": 0.80
		},
		{
			"id": "boss_a_bolt", "name": "뇌격 방출", "symbol": "A3",
			"kind": "projectile", "element": "thunder", "form": "pierce",
			"desc": "직선으로 뇌격을 쏩니다. 얼어붙은 상대에게는 훨씬 아프게 꽂힙니다.",
			"damage": 1.85, "duration": 1.05, "action_ratio": 0.80, "reload": 0.48,
			"range": 560.0, "arc": 0.22, "hits": 1, "projectiles": 1, "pierce": 3,
			# §3.3: "플레이어가 chill 상태면 피해 ×1.6". 조건부 배율은 패턴 데이터로 둔다.
			"conditional_status": "chill", "conditional_damage_mul": 1.6,
			"color": "f4d35e", "status": "shock", "telegraph": 0.45
		},
		{
			# ⚠️ **설계 미지정.** §3.3의 A 표에는 4번 패턴이 없다(A는 로테이션에서
			#    강화되지 않는다). 그런데 §6.6 강림 안전 밸브가 "칸 +1 — 즉 A도 4칸"이라고
			#    못박았으므로 A에도 4번이 **반드시 있어야 한다.** 없으면 강림한 A가
			#    빈 칸을 실행한다. A의 두 축(서리·뇌격)을 합친 뼈대를 둔다.
			#    V7이 실제로 돌려 보고 V10이 확정한다.
			"id": "boss_a_glacier", "name": "빙하 붕괴", "symbol": "A4",
			"kind": "area", "element": "ice", "form": "wave",
			"desc": "싸움터 전체가 얼어붙었다가 한꺼번에 무너집니다.",
			"damage": 2.40, "duration": 1.90, "action_ratio": 0.55, "reload": 0.78,
			"range": 460.0, "arc": 6.283, "hits": 2, "arena_wide": true,
			"color": "67c7d4", "status": "chill", "status_power": 1.6, "telegraph": 1.05
		}
	],
	# =========================================================================
	# B · 역병 점액왕 (독) — "분열하고 오염시킨다" · 2·4스테이지
	# 교육 목표: **상태이상은 나에게도 쌓인다 / 광역이 필요하다.**
	# `enemy._die()`의 기존 `recursion` 분열 로직을 소환에 재사용한다(§3.3).
	# =========================================================================
	"B": [
		{
			"id": "boss_b_leap", "name": "도약 압살", "symbol": "B1",
			"kind": "area", "element": "poison", "form": "wave",
			"desc": "높이 뛰어올라 반경 200에 내리꽂습니다. 착지 자국에 독이 고입니다.",
			"damage": 1.70, "duration": 1.45, "action_ratio": 0.66, "reload": 0.58,
			"range": 200.0, "arc": 6.283, "hits": 1,
			"color": "83c65c", "status": "poison", "status_stacks": 2, "telegraph": 0.70
		},
		{
			# YZ: 표시명만 「산성 분비」 → 「산 뱉기」. id는 boss_b_secretion 그대로다.
			"id": "boss_b_secretion", "name": "산 뱉기", "symbol": "B2",
			"kind": "ground", "element": "poison", "form": "trap",
			"desc": "바닥에 독 장판 세 개를 흘립니다. 8초 동안 남습니다.",
			"damage": 0.70, "duration": 1.50, "action_ratio": 0.86, "reload": 0.52,
			"range": 170.0, "arc": 6.283, "hits": 3, "random_impacts": true,
			"lingering": 8.0,
			"color": "83c65c", "status": "poison", "status_stacks": 1, "telegraph": 0.60
		},
		{
			"id": "boss_b_split", "name": "분열", "symbol": "B3",
			"kind": "area", "element": "", "form": "guard",
			"desc": "몸을 갈라 작은 점액 셋을 떨어뜨립니다. 하나하나가 독을 지녔습니다.",
			# 유일하게 **원소도 상태도 없는** 패턴이다. 소환 자체가 효과이고,
			# 독은 소환된 개체가 들고 나간다. 빈 원소라 L1 반응도 서지 않는다.
			"damage": 0.0, "duration": 1.60, "action_ratio": 0.40, "reload": 0.70,
			"range": 0.0, "arc": 0.0, "hits": 1,
			"summon_count": 3, "summon_hp_ratio": 0.12, "summon_status": "poison",
			"color": "bd6ac8", "status": "", "telegraph": 0.90
		},
		{
			"id": "boss_b_burst", "name": "역병 파열", "symbol": "B4",
			"kind": "area", "element": "poison", "form": "wave",
			# YZ: 「독 스택」의 스택은 프로젝트 전체 화면 문구에서 여기 한 곳뿐인 외래어였다.
			# 「쌓인」이 이미 같은 뜻을 지고 있어 군더더기이기도 해서 뺐다.
			"desc": "싸움터 전체가 터집니다. 몸에 쌓인 독만큼 더 아픕니다.",
			"damage": 2.10, "duration": 1.85, "action_ratio": 0.58, "reload": 0.80,
			"range": 480.0, "arc": 6.283, "hits": 1, "arena_wide": true,
			"bonus_per_player_stack": 0.35,
			"color": "83c65c", "status": "poison", "status_stacks": 2, "telegraph": 1.10
		}
	],
	# =========================================================================
	# C · 홍염 천구 (화 + 기름) — "칠하고 태운다" · 3·5스테이지
	# 교육 목표: **유→화 콤보를 몸으로 배운다.** 플레이어가 3스테이지에서 당한 콤보를
	# 5스테이지에서는 자기 5칸으로 되갚는 구조다(§3.3).
	# =========================================================================
	"C": [
		{
			"id": "boss_c_oilwing", "name": "기름 날개", "symbol": "C1",
			"kind": "area", "element": "oil", "form": "wave",
			"desc": "날개를 부채꼴로 후려 바닥과 상대에게 기름을 끼얹습니다. 그 자체로는 아프지 않습니다.",
			# 기름은 피해가 0이다(§4.3). 이 패턴은 **다음 패턴을 위한 준비**이고,
			# 그것이 C가 자기 콤보를 쓴다는 것의 기계적 실체다.
			"damage": 0.25, "duration": 1.15, "action_ratio": 0.72, "reload": 0.42,
			"range": 300.0, "arc": 2.20, "hits": 1, "paints_ground": true,
			"color": "3b2b46", "status": "oil", "telegraph": 0.50
		},
		{
			"id": "boss_c_glide", "name": "활공 참격", "symbol": "C2",
			"kind": "dash", "element": "strike", "form": "slash",
			"desc": "낮게 활공하며 경로를 벱니다. 가장 빠른 패턴입니다.",
			"damage": 1.55, "duration": 0.95, "action_ratio": 0.88, "reload": 0.38,
			"range": 320.0, "arc": 0.85, "hits": 2,
			"color": "fff3d0", "status": "", "telegraph": 0.35
		},
		{
			"id": "boss_c_firedive", "name": "화염 강하", "symbol": "C3",
			"kind": "ground", "element": "fire", "form": "trap",
			# YZ: 부유 라벨을 「크게 타오름!」으로 바꿨으므로 설명도 같은 말로 맞췄다.
			"desc": "불덩이가 되어 내리꽂힙니다. 기름 위라면 크게 타오릅니다.",
			"damage": 1.95, "duration": 1.60, "action_ratio": 0.68, "reload": 0.66,
			"range": 230.0, "arc": 6.283, "hits": 2,
			"color": "e78a45", "status": "burn", "telegraph": 0.85
		},
		{
			"id": "boss_c_blackfire", "name": "흑염 회오리", "symbol": "C4",
			"kind": "ground", "element": "fire", "form": "wave",
			"desc": "3초 동안 도는 검은 불길이 남은 기름에 전부 불을 붙입니다.",
			"damage": 1.05, "duration": 2.00, "action_ratio": 0.92, "reload": 0.82,
			"range": 340.0, "arc": 6.283, "hits": 5, "lingering": 3.0,
			"ignites_ground_oil": true,
			"color": "d95763", "status": "burn", "telegraph": 1.20
		}
	]
}

# -----------------------------------------------------------------------------
# 조회 · 파생
# -----------------------------------------------------------------------------

static func designs() -> Array[String]:
	return ["A", "B", "C"]

# ⚠️ V10: 패턴 데이터에 있던 `anim` 키 2개(B1 `jump` · C2 `attack`)를 **지웠다**
#    (handoff-v7 §12-3). 소비자가 0이었고, 앞으로도 생기면 안 되는 종류의 데이터다 —
#    어느 시트 행을 재생할지는 `enemy.BOSS_SHEETS`가 소유한다. 실제로 두 값 모두
#    이미 시트가 하던 일과 같았다: `plague_slime`의 `attack` 행이 곧 Jump 13프레임이고
#    (walk == attack == 행 1), C는 `attack` 행 15프레임을 그대로 쓴다. 즉 지운 것은
#    **틀린 데이터가 아니라 두 번 적힌 데이터**다.

## 리그 키(`"A"` / `"B+"` …) → 스프라이트 명세. 강화형 키는 `_변종`을 포함한다.
static func rig(rig_id: String) -> Dictionary:
	return (RIGS.get(rig_id, {}) as Dictionary).duplicate(true)

## 디자인 + 강화 여부 → 리그 키. `"B"`+enhanced → `"B+"`.
static func rig_id(design: String, enhanced: bool) -> String:
	var key := design + ("+" if enhanced else "")
	return key if RIGS.has(key) else design

## 이 디자인의 패턴 원본 4개(강화 파생 전).
static func patterns_raw(design: String) -> Array:
	return (PATTERNS.get(design, []) as Array).duplicate(true)

## 이 보스가 실제로 세우는 딜싸이클 칸 수.
## 기본 3 / 강화 4 / 강림(§6.6)이면 여기에 +1이 더 붙는다 — 그래서 A도 4칸이 된다.
static func slot_count(enhanced: bool, descended: bool = false) -> int:
	var base := GameTuning.STAGE_BOSS_SLOT_COUNT_ENHANCED if enhanced else GameTuning.STAGE_BOSS_SLOT_COUNT
	if descended:
		base += GameTuning.STAGE_DESCENT_SLOT_BONUS
	return mini(base, ENHANCED_PATTERN_COUNT)

## 강화형 파생(§3.4)까지 끝난 완성 패턴 배열. **V7이 이 함수 하나만 부르면 된다.**
##   칸 3 → 4 (4번 패턴을 켠다)
##   telegraph 전부 × 0.85
##   부여 상태이상 1종 → 2종 (기본 원소 + 보조 원소)
## 데이터를 두 벌 저작하지 않는다 — 강화형은 **규칙으로만** 존재한다.
static func patterns(design: String, enhanced: bool, descended: bool = false) -> Array:
	var raw := patterns_raw(design)
	var count := mini(slot_count(enhanced, descended), raw.size())
	var out: Array = []
	for index in range(count):
		var pattern: Dictionary = (raw[index] as Dictionary).duplicate(true)
		if enhanced:
			pattern["telegraph"] = float(pattern["telegraph"]) * GameTuning.STAGE_BOSS_TELEGRAPH_MUL_ENHANCED
			var secondary := secondary_status(design)
			if secondary != "" and String(pattern["status"]) != "" and String(pattern["status"]) != secondary:
				pattern["status_secondary"] = secondary
		pattern["enhanced"] = enhanced
		out.append(pattern)
	return out

## 강화형이 기본 원소 위에 하나 더 얹는 보조 상태(§3.4 "1종 → 2종").
## 각 보스의 두 번째 축을 고른다 — A는 뇌(shock), B는 자기 장판의 연소(burn),
## C는 기름(oil). C는 이미 기름을 쓰지만 강화형은 **모든 패턴이** 기름을 남긴다.
static func secondary_status(design: String) -> String:
	match design:
		"A": return "shock"
		"B": return "burn"
		"C": return "oil"
		_: return ""

## 이 보스가 쓰는 RELOAD 배율. 강화형은 반격 창이 좁아진다(0.75 → 0.55).
static func reload_scale(enhanced: bool) -> float:
	return GameTuning.STAGE_BOSS_RELOAD_MUL_ENHANCED if enhanced else GameTuning.STAGE_BOSS_RELOAD_MUL

## 페이즈 전환 체력 비율. 기본 [0.50] / 강화 [0.66, 0.33].
static func phase_thresholds(enhanced: bool) -> Array:
	var source: Array = GameTuning.STAGE_BOSS_PHASES_ENHANCED if enhanced else GameTuning.STAGE_BOSS_PHASES
	return source.duplicate()

## §3.4의 HP 식. `stage_hp_base`는 `GameTuning.STAGE_HP_BASE[stage - 1]`.
## dwell 항이 몹(§6.2)보다 완만한 이유는 **오래 머문 플레이어를 두 번 벌하지 않기 위해서**다.
static func hp_for(design: String, stage_hp_base: float, dwell: int, descended: bool = false) -> float:
	var base := float(DESIGN_HP.get(design, 3000.0))
	var hp := base * maxf(stage_hp_base, 0.01) * (1.0 + GameTuning.STAGE_BOSS_HP_DWELL_STEP * float(maxi(dwell, 0)))
	if descended:
		hp *= GameTuning.STAGE_DESCENT_HP_MUL
	return hp

## 한 보스의 완성 서술. V7이 `_build_stage_boss_factory()`에서 이걸 그대로 편다.
## 로테이션은 이 파일이 소유하지 않으므로 `design` / `enhanced`를 **받아서** 쓴다
## (정본: `GameTuning.STAGE_BOSS_DESIGN` · `STAGE_BOSS_ENHANCED`).
static func resolve(design: String, enhanced: bool, descended: bool = false) -> Dictionary:
	var key := rig_id(design, enhanced)
	var sprite := rig(key)
	return {
		"design": design,
		"enhanced": enhanced,
		"descended": descended,
		"rig_id": key,
		"name": String(sprite.get("name", design)),
		"sprite": sprite,
		"slot_count": slot_count(enhanced, descended),
		"patterns": patterns(design, enhanced, descended),
		"reload_scale": reload_scale(enhanced),
		"phases": phase_thresholds(enhanced),
		"status_count": GameTuning.STAGE_BOSS_STATUS_COUNT_ENHANCED if enhanced else GameTuning.STAGE_BOSS_STATUS_COUNT,
		# 스테이지 보스는 **각인을 갖지 않는다.** 이 줄이 마왕과의 유일성 경계다.
		# Y8: 짝이던 `uses_heat: false`는 삭제했다 — 과열 규칙 자체가 없어졌으므로
		# "과열을 안 쓴다"는 말이 성립하지 않는다. 검사는 **키가 없는가**로 바뀌었다.
		"uses_runes": false,
		"uses_reload": true
	}

## 패턴 표 자체의 정합성. data_test가 매 실행마다 단언한다.
##   ① 디자인 3종이 각각 정확히 4패턴
##   ② 모든 패턴이 PATTERN_REQUIRED_KEYS를 전부 가진다
##   ③ 원소가 유효 집합 안(빈 문자열 허용 — B의 분열)
##   ④ telegraph > 0, damage ≥ 0, duration > 0, hits ≥ 1
##   ⑤ 리그 5벌(A·B·C·B+·C+)이 전부 있고 강화형은 기본형과 같은 셀 크기다
static func table_ok(valid_elements: Array, valid_forms: Array, valid_statuses: Array) -> bool:
	for design: String in designs():
		var list := patterns_raw(design)
		if list.size() != ENHANCED_PATTERN_COUNT:
			return false
		for entry in list:
			var pattern: Dictionary = entry
			for key: String in PATTERN_REQUIRED_KEYS:
				if not pattern.has(key):
					return false
			var element := String(pattern["element"])
			if element != "" and not valid_elements.has(element):
				return false
			if not valid_forms.has(String(pattern["form"])):
				return false
			var status := String(pattern["status"])
			if status != "" and not valid_statuses.has(status):
				return false
			if float(pattern["telegraph"]) <= 0.0:
				return false
			if float(pattern["damage"]) < 0.0:
				return false
			if float(pattern["duration"]) <= 0.0:
				return false
			if int(pattern["hits"]) < 1:
				return false
	for key: String in ["A", "B", "C", "B+", "C+"]:
		if not RIGS.has(key):
			return false
	for pair in [["B", "B+"], ["C", "C+"]]:
		var base: Dictionary = RIGS[pair[0]]
		var plus: Dictionary = RIGS[pair[1]]
		if base["cell"] != plus["cell"]:
			return false
		if String(plus["design"]) != String(pair[0]):
			return false
	return true
