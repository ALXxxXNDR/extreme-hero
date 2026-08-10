class_name DealCardLibrary
extends RefCounted

# =============================================================================
# V2 — 스킬 카드 데이터 (v3 재저작 · 28장 = 7속성 × 4장)
# =============================================================================
# 기준: docs/GAME_DESIGN_V3.md §4.2(속성 7계) · §5.1~5.4(28장·id 고정·개명) ·
#       부록 A-2 ⑮⑱⑲ · 부록 B V2 / v2 기반은 GAME_DESIGN_V2.md §3.8 · 부록 C-6
#
# v2 → v3에서 달라진 것은 **태그와 이름뿐이다. id는 한 개도 바뀌지 않았다.**
#
#   ① **legacy 8장을 전부 드래프트 풀로 승격했다 → 정확히 28장.**
#      v2는 드래프트 20 + legacy 8이었고, legacy는 `draft_pool()`에서만 빠져 있었을 뿐
#      by_id·아이콘·VFX 분기가 전부 살아 있었다. `"legacy": true` 키를 지웠다.
#      `is_legacy()`는 항상 false를 돌려주지만 **함수는 남겼다**(호출부 보호).
#
#   ② **속성 7계로 재배치**(§4.2 · §5.3). blood→poison / light→psi / iron→strike는
#      개명이 아니라 **역할 승계**이고, `oil`만 신규다. 그래서 28장의 태그를 처음부터
#      다시 붙일 필요가 없었다 — 이번 개편에서 구현 규모를 가장 크게 줄인 판단이다.
#
#   ③ **id를 하나도 바꾸지 않는다.** id 하나당 동기화 지점이 10곳이다
#      (`skill_icon.GENERATED_SKILL_INDEX` · `cycle_skill_effect._draw_signature` ·
#       `player._apply_skill_stats` · `palette.gd` · `patch_library` · `debt_module()` ·
#       `data_test` · `test_runner` 다수 · 아틀라스 PNG 자체).
#      id 고정 = 그 10곳 전부 무변경. 아이콘 아틀라스 7×4 = 28칸도 그대로 맞는다.
#
#   ④ **표시명 개명은 속성이 바뀐 카드에만 했다.** 스킬 표시명은 W7이 이미 판타지로
#      통일해 뒀고(§5.4), 남은 직장 풍자는 **id에만** 있으며 id는 ③ 때문에 못 바꾼다.
#      진짜 풍자 개명 대상은 `item_library.gd`다(같은 웨이브가 처리했다).
#
#   ⑤ `reload` 재기준(v2 부록 C-6)은 그대로 승계한다. 실측(test/data_test.gd,
#      대표 5칸 덱 5종 × 400사이클) 목표는 여전히 "평균 ≈3초 / 상한 6초"다.
#
# 기존 키(kind/damage/duration/action_ratio/reload/range/arc/hits/...)는 하나도
# 지우지 않았다. v1 딜싸이클 컨트롤러가 아직 그 키들을 읽는다.
#
# ── X1(2026-08-09) `desc` 40장 전수 점검 ─────────────────────────────────────
# 사용자 피드백 ③: "'3회 타격' 같은 태그는 모두 지우고, 타격 횟수·넉백 같은 건
# 스킬 설명 문장에 포함시켜." 레벨업 모달이 태그 줄(`combat_tags()`)을 더 이상
# 그리지 않으므로 그 줄이 나르던 정보를 **문장이 흡수해야** 한다.
#   * 손댄 것은 `desc` **문자열뿐**이다. id·name·수치·태그는 한 글자도 안 바뀌었다.
#   * `combat_tags()` 함수는 **지우지 않았다** — 편집 화면·상점 등 다른 화면이
#     아직 쓴다.
#
# ── Y3(2026-08-09) 속성 재작명 · 색 정합 · 콤보 언어 (FEEDBACK_Y.md §3 · §4) ──
# 유저 불만은 두 가지였다. "초가 무슨 말인지 모르겠다" / "속성 색 구별이 안 된다".
#
#   ⓐ **속성 표시명에서 한자 병기를 전부 버렸다**(§3.2).
#      화(火)→불 · 빙(氷)→얼음 · 뇌(雷)→번개 · 독(毒)→독 · 유(油)→기름 ·
#      타(打)→타격 · 초(超)→정신. **내부 element 키는 한 글자도 안 바뀌었다.**
#      `element_role()` 7줄도 §4.1 동사 체계에 맞춰 쉬운 한글 한 줄로 다시 썼다.
#
#   ⓑ **카드별 `color` 값이 속성과 무관했던 버그를 고쳤다**(§3.3 ⚠️ · 리스크 ⑩).
#      `thunder` 카드가 청록(67c7d4), `whirlwind`(독) 카드가 붉은색(d95763)이었다.
#      `_factory_card_color()`(game.gd)가 이 값을 아이콘·프레임 색으로 흘려보내므로
#      **유저가 말한 "색 구별 안 됨"의 진짜 원인이 여기일 가능성이 높다.**
#      SKILLS 28장 + SPECIALS 12장 전부를 속성색으로 맞췄다. 새 색표:
#        불 e2452f(구 e78a45 주황) · 얼음 67c7d4 · 번개 f4d35e · 독 83c65c ·
#        기름 7a5230(구 7563a8/bd6ac8 보라) · 타격 c3bda4 · 정신 bd6ac8
#      BASIC은 속성이 없으므로 f4d35e 그대로 둔다.
#      ⚠️ **`color` 키 자체는 지우지 않았다** — VFX(`cycle_skill_effect.gd:52`)가
#      아직 읽는다. 이 키를 **VFX 전용으로 좁히고** `_factory_card_color()`를
#      `_element_color()` 폴백 구조로 바꾸는 것은 **Y4의 일**이다.
#
#   ⓒ **`desc`(무엇을 하는가)와 `combo`(무엇과 어울리는가)를 쪼갰다**(§4.2).
#      desc 16자 · combo 18자 상한. 40장 전량이 상한 안에 있다.
#      레벨업 카드 글자 줄은 4줄 → 5줄이 되지만 한 줄이 짧아 읽는 시간은 준다.
#
#   ⓓ **`silhouette` 키를 신설했다**(§4.4). 아이콘 축 14종이고 `form`과는 별개다.
#      같은 속성 안에서 실루엣이 겹치면 안 된다 — (element, silhouette) 28쌍이
#      전부 고유하다. `silhouette_pairs_unique()`가 그것을 검사한다.
#
#   ⓔ **`impact` 키를 신설했다**(§7.3). 충격 프로필 8종이고 `knockback_profile()`이
#      **authored `impact`를 kind 기반 값보다 먼저 본다.** 여기 넣은 것은 impact별
#      `{force, stun}` **기본표뿐**이고 실제 넉백 수치 튜닝은 **Y7 몫**이다.
#      기존 kind 기반 분기는 폴백으로 그대로 남겼다.
#
#   ⓕ `cross_cut` 한 장에만 `status_stack_bonus: 2.0`을 넣었다(§4.5).
#      `combat_resolver`가 이 키를 `ctx`로 넘기는 배선은 **후속 웨이브 몫**이다.
#      지금은 데이터만 있고 읽는 쪽이 없다.
#
#   ⓖ 이 파일의 사용자 노출 문자열(name · desc · combo · debt_desc · element_role ·
#      kind_name · combat_tags 조각)을 전부 쉬운 한글로 다시 다듬었다.
#      수치·id·element·form·special·tier2는 한 글자도 안 바꿨다.
#
# ── V2가 손댄 수치 2건 (설계가 강제한 것) ────────────────────────────────────
# §5.1의 완료 기준은 "속성마다 근접(range < 200) ≥1 · 원거리(≥260) ≥1"이다.
# 그런데 28장 중 range ≥ 260인 카드는 **다섯 장뿐이다**
# (earth_splitter 620 · boomerang_blade 540 · targeting 520 · blade_fan 510 · recursion 480).
# 5 < 7이므로 §5.3의 배치를 어떻게 섞어도 두 속성은 원거리 카드를 가질 수 없다 —
# **구조적으로 range 상향 2건이 강제된다.** 배치는 §5.3 표를 한 글자도 바꾸지 않고
# 대신 그 두 속성(얼음·독)의 광역 카드 사거리를 올리고 그만큼 reload/damage로 지불했다.
#   frost_ring  range 205 → 268 · reload 0.53 → 0.60 · damage 1.05 → 0.95
#   whirlwind   range 148 → 262 · reload 0.46 → 0.58 · damage 0.82 → 0.72
# 최종 확정은 V10 balance_probe. 근거는 docs/handoff-v2.md §2에 남겼다.

# -----------------------------------------------------------------------------
# 태그 어휘 (§4.2) — RuneEngine.ELEMENTS / RuneEngine.FORMS와 반드시 같아야 한다.
# **배열 순서까지 같아야 한다**(data_test가 `Array == Array`로 대조한다).
# 여기서 preload로 묶지 않은 이유: 데이터 파일이 엔진에 의존하면 순환 로드가 생긴다.
# -----------------------------------------------------------------------------
const ELEMENTS: Array[String] = ["fire", "ice", "thunder", "poison", "oil", "strike", "psi"]
const FORMS: Array[String] = ["slash", "pierce", "wave", "trap", "guard"]

# -----------------------------------------------------------------------------
# 실루엣 14종 (§4.4) — **아이콘 축이다. 위의 FORMS와는 완전히 다른 축이다.**
# 순서 = §4.4 표 순서 = `skill_icon.gd`가 쓸 아틀라스 인덱스 0~13이다.
# 에셋은 `art/v2/ui-kit-skill-shape.png`(16px 원본 14칸 · 흰색 단색으로 굽는다).
# -----------------------------------------------------------------------------
const SILHOUETTES: Array[String] = [
	"slash", "combo_slash", "heavy_slash", "thrust", "dash", "throw", "homing",
	"chain", "wave", "orbit", "field", "rain", "vortex", "shield"
]

# -----------------------------------------------------------------------------
# 충격 프로필 8종 (§7.3) — 맞은 쪽이 어떻게 반응하는가.
# `knockback_profile()`이 카드의 authored `impact`를 kind 기반 값보다 먼저 본다.
# -----------------------------------------------------------------------------
const IMPACTS: Array[String] = [
	"push", "pin", "slow", "drag", "rush", "haste_self", "stagger", "pop"
]

# 드래프트 풀 크기(§5.1 "7속성 × 4장"). data_test가 이 값으로 검사한다.
# v2의 20에서 28로 올랐다 — legacy 8장 승격분이다. 신규 id는 0개다.
const DRAFT_POOL_SIZE := 28
## 속성 하나가 가져야 하는 카드 수. 28 = 7 × 4의 4다.
const CARDS_PER_ELEMENT := 4
## 근접/원거리 판정선(§5.1). 이 사이(200~260)는 어느 쪽으로도 세지 않는다.
const MELEE_RANGE_MAX := 200.0
const RANGED_RANGE_MIN := 260.0
# 랭크 상한(§5.2 "상한 R3"). 같은 id 4장 = R3.
const MAX_RANK := 3
# 랭크 계수(§9.3): 피해 ×(1+0.55(r−1)) · duration ×0.94^(r−1) · reload ×0.95^(r−1)
const RANK_DAMAGE_STEP := 0.55
const RANK_DURATION_FALLOFF := 0.94
const RANK_RELOAD_FALLOFF := 0.95
# 랭크가 범위를 넓히는 폭(v1 0.055 유지 — §9.3이 언급하지 않은 축이라 건드리지 않았다).
const RANK_RANGE_STEP := 0.055

# 빈 칸이 실행하는 기본 공격.
# **태그가 없다(빈 문자열).** 의도적이다 — 빈 칸까지 속성을 가지면 카드를 한 장도
# 안 얻은 1일차에 5칸 인접 공명이 공짜로 성립한다. RuneEngine.DEFAULT_CARD도 같은
# 이유로 태그가 비어 있고, `resonance_bonus()`는 빈 원소를 건너뛴다.
# (구 결속·삼각 규칙과 그 판정 함수 둘은 §1.4에서 폐기 → Y8이 코드에서 삭제했다.)
# 속성이 없으므로 Y3 색 정합(§3.2) 대상이 아니다 — `color`는 f4d35e 그대로다.
const BASIC: Dictionary = {
	"id":"basic", "name":"기본 베기", "symbol":"/", "kind":"melee",
	"element":"", "form":"",
	"desc":"빈 딜싸이클 칸이 대신 내는 기본 공격입니다.",
	"damage":1.0, "duration":0.72, "action_ratio":0.78, "reload":0.11,
	"range":132.0, "arc":2.18, "hits":1, "projectiles":1,
	"color":"f4d35e", "debt_desc":"마왕의 기본 공격이 더 빨라집니다."
}

# -----------------------------------------------------------------------------
# SKILLS = 드래프트 풀 28장 = **7속성 × 4장** (§5.1 · §5.3). legacy 0장.
# 배열은 속성 블록 7개로 묶여 있고 블록 순서 = ELEMENTS 순서다.
#
# 속성 분포: 불4 · 얼음4 · 번개4 · 독4 · 기름4 · 타격4 · 정신4 → 결속(같은 속성
#            3칸 연속)이 **7속성 전부에서** 가능하다.
# 형태 분포: 참격7 · 관통6 · 파동5 · 설치5 · 수호5      → 삼각(1·3·5 같은 형태)이
#            **5형태 전부에서** 가능하다(형태당 ≥5).
# 근접/원거리: 속성마다 range < 200 이 최소 1장, range ≥ 260 이 최소 1장.
# 실루엣: 같은 속성 안에서 겹치지 않는다(§4.4 유일성 계약 · 28쌍 전부 고유).
#
# ── v2에서 형태를 옮긴 카드 2장 (형태당 ≥5를 맞추기 위한 최소 이동) ──────────
#   `aura`         파동 → **설치**  기름은 바닥에 눌어붙는다. 9틱 지속 장판이라
#                                   원래도 설치에 가까웠다(§5.3 "oil 4장은 설치·파동·투척").
#   `phantom_step` 참격 → **수호**  세 잔상이 대신 맞아 준다. 돌진 회피기의 재해석.
# -----------------------------------------------------------------------------
const SKILLS: Array[Dictionary] = [
	# --- 불 · 붙이고 태운다 · 모든 폭발의 불씨 -----------------------------------
	{"id":"flame_field","name":"불바다","symbol":"F","kind":"ground","element":"fire","form":"trap","silhouette":"field","impact":"rush","desc":"바닥을 여섯 번 태운다","combo":"기름 위에 깔면 두 배로 탄다","damage":0.72,"duration":1.60,"action_ratio":0.86,"reload":0.60,"range":112.0,"arc":6.283,"hits":6,"color":"e2452f","debt_desc":"마왕의 전장이 불타기 시작합니다."},
	{"id":"meteor_blade","name":"불덩이 세 개","symbol":"*","kind":"ground","element":"fire","form":"trap","silhouette":"rain","impact":"push","desc":"세 곳에 떨어져 크게 밀친다","combo":"독이 쌓인 적은 여기서 터진다","damage":2.45,"duration":1.95,"action_ratio":0.70,"reload":0.98,"range":235.0,"arc":6.283,"hits":3,"random_impacts":true,"heavy":true,"color":"e2452f","debt_desc":"마왕이 전장을 뒤엎는 불덩이를 얻습니다."},
	{"id":"earth_splitter","name":"용암 가르기","symbol":"E","kind":"projectile","element":"fire","form":"pierce","silhouette":"thrust","impact":"pop","desc":"아주 멀리 두 줄로 꿰뚫는다","combo":"기름 자국을 한 줄로 태운다","damage":1.62,"duration":1.32,"action_ratio":0.65,"reload":0.62,"range":620.0,"arc":0.18,"hits":2,"projectiles":1,"pierce":5,"heavy":true,"color":"e2452f","debt_desc":"마왕이 땅을 가르는 불줄기를 얻습니다."},
	{"id":"lion_roar","name":"불사자 포효","symbol":"W","kind":"area","element":"fire","form":"wave","silhouette":"wave","impact":"push","desc":"두 겹 불길로 멀리 밀친다","combo":"언 적을 녹이면 범위가 넓어진다","damage":1.05,"duration":1.18,"action_ratio":0.78,"reload":0.42,"range":215.0,"arc":6.283,"hits":2,"knockback":62.0,"heavy":true,"color":"e2452f","debt_desc":"마왕의 포효가 다가서지 못하게 막습니다."},
	# --- 얼음 · 얼리고 늦춘다 · 번개가 지나갈 길을 깐다 --------------------------
	{"id":"dash_blade","name":"서리 돌진","symbol":">","kind":"dash","element":"ice","form":"slash","silhouette":"dash","impact":"slow","desc":"뚫고 지나가며 두 번 벤다","combo":"얼린 적에 번개를 쓰면 퍼진다","damage":1.02,"duration":0.86,"action_ratio":0.90,"reload":0.36,"range":185.0,"arc":0.62,"hits":2,"color":"67c7d4","debt_desc":"마왕이 돌진 공격을 배웁니다."},
	{"id":"frost_ring","name":"얼음 물결","symbol":"Q","kind":"area","element":"ice","form":"wave","silhouette":"wave","impact":"slow","desc":"아주 넓게 세 번 얼린다","combo":"여럿을 얼려 번개 길을 만든다","damage":0.95,"duration":1.28,"action_ratio":0.68,"reload":0.60,"range":268.0,"arc":6.283,"hits":3,"slow":0.32,"color":"67c7d4","debt_desc":"마왕의 넓은 물결이 더 세집니다."},
	{"id":"guardian_blade","name":"얼음 호위검","symbol":"G","kind":"orbit","element":"ice","form":"guard","silhouette":"orbit","impact":"slow","desc":"내 주위를 여덟 번 돈다","combo":"붙는 적을 계속 얼려 둔다","damage":0.54,"duration":1.65,"action_ratio":0.96,"reload":0.48,"range":102.0,"arc":6.283,"hits":8,"color":"67c7d4","debt_desc":"마왕 주위에 검은 칼날이 돕니다."},
	{"id":"moon_barrier","name":"얼음 방패","symbol":"M","kind":"shield","element":"ice","form":"guard","silhouette":"shield","impact":"haste_self","desc":"안 때리고 수호막 두 겹","combo":"위험할 때 한 칸 비워 두는 용도","damage":0.0,"duration":0.94,"action_ratio":0.48,"reload":0.50,"range":0.0,"arc":0.0,"hits":1,"shield":2,"color":"67c7d4","debt_desc":"마왕의 검은 갑옷이 두꺼워집니다."},
	# --- 번개 · 찌릿하게 만들고 옆으로 퍼진다 ------------------------------------
	{"id":"thunder","name":"벼락 심판","symbol":"T","kind":"chain","element":"thunder","form":"wave","silhouette":"chain","impact":"stagger","desc":"멀리까지 네 번 이어 친다","combo":"언 적이 있으면 넷에게 퍼진다","damage":1.02,"duration":1.15,"action_ratio":0.90,"reload":0.50,"range":410.0,"arc":6.283,"hits":4,"ricochet":4,"color":"f4d35e","debt_desc":"마왕의 공격이 끝까지 쫓아옵니다."},
	{"id":"time_cut","name":"번개 교차베기","symbol":"0","kind":"melee","element":"thunder","form":"slash","silhouette":"combo_slash","impact":"haste_self","desc":"눈에 안 보이게 두 번 벤다","combo":"찌릿 표식 — 다음 한 방이 세다","damage":0.58,"duration":0.82,"action_ratio":0.96,"reload":0.12,"range":116.0,"arc":1.7,"hits":2,"color":"f4d35e","debt_desc":"마왕의 딜싸이클이 더 빨라집니다."},
	{"id":"targeting","name":"번개 창","symbol":"+","kind":"projectile","element":"thunder","form":"pierce","silhouette":"homing","impact":"pin","desc":"알아서 쫓아가 두 번 꽂는다","combo":"기름을 밟은 적은 크게 터진다","damage":0.92,"duration":0.84,"action_ratio":0.84,"reload":0.26,"range":520.0,"arc":0.2,"hits":2,"projectiles":1,"pierce":1,"homing":1.8,"color":"f4d35e","debt_desc":"마왕의 검기가 나를 쫓아옵니다."},
	{"id":"phantom_step","name":"번개 잔상","symbol":">>","kind":"dash","element":"thunder","form":"guard","silhouette":"dash","impact":"haste_self","desc":"잔상 셋이 대신 맞아 준다","combo":"얼음 위에서 옆으로 퍼진다","damage":0.82,"duration":1.02,"action_ratio":0.96,"reload":0.38,"range":205.0,"arc":0.78,"hits":3,"color":"f4d35e","debt_desc":"마왕이 잔상과 함께 돌진합니다."},
	# --- 독 · 겹칠수록 세지게 쌓는다 ---------------------------------------------
	{"id":"whirlwind","name":"독바람 회전","symbol":"O","kind":"area","element":"poison","form":"wave","silhouette":"wave","impact":"push","desc":"아주 넓게 네 번 휘두른다","combo":"독을 네 겹까지 쌓는다","damage":0.72,"duration":1.30,"action_ratio":0.94,"reload":0.58,"range":262.0,"arc":6.283,"hits":4,"color":"83c65c","debt_desc":"마왕이 사방으로 휘두르기 시작합니다."},
	{"id":"blood_pact","name":"독의 서약","symbol":"B","kind":"melee","element":"poison","form":"slash","silhouette":"combo_slash","impact":"stagger","desc":"세 번 베고 조금 회복한다","combo":"벨 때마다 독이 한 겹씩 쌓인다","damage":0.92,"duration":1.05,"action_ratio":0.90,"reload":0.38,"range":142.0,"arc":1.92,"hits":3,"lifesteal":0.08,"color":"83c65c","debt_desc":"마왕이 맞으면서 체력을 되찾습니다."},
	{"id":"execution","name":"독의 처형","symbol":"X","kind":"melee","element":"poison","form":"slash","silhouette":"heavy_slash","impact":"pin","desc":"한 방이 아주 세다","combo":"독이 깊게 남고 RELOAD 길다","damage":4.20,"duration":1.62,"action_ratio":0.55,"reload":0.77,"range":158.0,"arc":1.55,"hits":1,"heavy":true,"color":"83c65c","debt_desc":"마왕의 한 방이 아주 세집니다."},
	# `status_stack_bonus`는 §4.5가 지정한 **이 한 장뿐인** 키다. 독을 두 배로 쌓는다.
	# ⚠️ `combat_resolver`가 이 값을 `ctx`로 넘기는 배선은 **후속 웨이브 몫**이다.
	#    지금은 데이터만 있고 읽는 쪽이 없다 — 밸런스 파급도 아직 0이다.
	{"id":"cross_cut","name":"맹독 십자","symbol":"#","kind":"melee","element":"poison","form":"slash","silhouette":"slash","impact":"pop","desc":"두 줄로 교차해 벤다","combo":"이미 독이 있으면 두 배로 쌓는다","damage":1.18,"duration":0.94,"action_ratio":0.92,"reload":0.28,"range":165.0,"arc":2.15,"hits":2,"status_stack_bonus":2.0,"color":"83c65c","debt_desc":"마왕의 칼이 엇갈리며 빈틈을 지웁니다."},
	# --- 기름 · 피해가 거의 없다. 먼저 적셔 두고 나중에 태운다 -------------------
	# 4장이 전부 설치·투척인 것은 의도다(§5.3). 기름은 바닥에 칠하는 속성이어야
	# "먼저 적시고 나중에 태운다"는 **순서**가 자연스러워진다.
	{"id":"gravity_well","name":"기름 늪","symbol":"@","kind":"ground","element":"oil","form":"trap","silhouette":"vortex","impact":"drag","desc":"끌어당겨 일곱 번 짓누른다","combo":"젖은 적은 불에 두 배로 탄다","damage":0.52,"duration":1.70,"action_ratio":0.94,"reload":0.67,"range":175.0,"arc":6.283,"hits":7,"pull":0.24,"color":"7a5230","debt_desc":"마왕이 도망갈 자리를 좁힙니다."},
	{"id":"sword_rain","name":"기름 비","symbol":"|||","kind":"ground","element":"oil","form":"trap","silhouette":"rain","impact":"rush","desc":"여러 곳에 일곱 번 쏟는다","combo":"넓게 적셔 두고 불을 붙인다","damage":0.88,"duration":2.05,"action_ratio":0.96,"reload":0.73,"range":145.0,"arc":6.283,"hits":7,"random_impacts":true,"color":"7a5230","debt_desc":"마왕의 검이 하늘에서 끝없이 내려옵니다."},
	{"id":"aura","name":"기름 안개","symbol":"A","kind":"area","element":"oil","form":"trap","silhouette":"field","impact":"rush","desc":"따라다니며 아홉 번 적신다","combo":"불이 이미 붙었으면 두 배로 탄다","damage":0.45,"duration":1.90,"action_ratio":0.98,"reload":0.37,"range":136.0,"arc":6.283,"hits":9,"color":"7a5230","debt_desc":"마왕이 바짝 붙어 몰아붙입니다."},
	{"id":"boomerang_blade","name":"기름 회귀검","symbol":"U","kind":"projectile","element":"oil","form":"pierce","silhouette":"throw","impact":"slow","desc":"튕겨 다니다 돌아온다","combo":"지나간 적을 전부 적신다","damage":0.88,"duration":1.22,"action_ratio":0.94,"reload":0.43,"range":540.0,"arc":0.3,"hits":2,"projectiles":1,"ricochet":4,"color":"7a5230","debt_desc":"마왕의 검기가 기름을 묻히며 돌아옵니다."},
	# --- 타격 · 속성이 아니다. 쌓인 것을 **터뜨린다** ---------------------------
	{"id":"cleave","name":"반달 베기","symbol":"C","kind":"melee","element":"strike","form":"slash","silhouette":"heavy_slash","impact":"push","desc":"넓게 한 번 쓸어 밀친다","combo":"쌓인 독을 터뜨린다","damage":1.65,"duration":0.98,"action_ratio":0.72,"reload":0.31,"range":176.0,"arc":2.72,"hits":1,"color":"c3bda4","debt_desc":"마왕의 칼이 더 넓고 더 세집니다."},
	{"id":"rapid_slash","name":"삼연참","symbol":"3","kind":"melee","element":"strike","form":"slash","silhouette":"combo_slash","impact":"stagger","desc":"짧게 세 번 빠르게 벤다","combo":"벨 때마다 독을 한 겹씩 터뜨린다","damage":0.62,"duration":1.05,"action_ratio":0.95,"reload":0.26,"range":126.0,"arc":1.74,"hits":3,"color":"c3bda4","debt_desc":"마왕이 연속 공격을 배웁니다."},
	{"id":"thrust","name":"관통 찌르기","symbol":"!","kind":"melee","element":"strike","form":"pierce","silhouette":"thrust","impact":"pin","desc":"좁고 길게 두 번 찌른다","combo":"언 적을 깨뜨려 크게 밀친다","damage":1.28,"duration":0.88,"action_ratio":0.88,"reload":0.29,"range":228.0,"arc":0.48,"hits":2,"color":"c3bda4","debt_desc":"마왕의 찌르기가 더 멀리 닿습니다."},
	{"id":"recursion","name":"되돌이 검기","symbol":"R","kind":"projectile","element":"strike","form":"pierce","silhouette":"throw","impact":"pop","desc":"멀리 갔다 두 번 돌아온다","combo":"오갈 때마다 상태를 터뜨린다","damage":0.90,"duration":1.10,"action_ratio":0.92,"reload":0.46,"range":480.0,"arc":0.24,"hits":2,"projectiles":1,"ricochet":3,"color":"c3bda4","debt_desc":"마왕의 공격이 여러 번 되돌아옵니다."},
	# --- 정신 · 속성이 아니다. 붙은 것을 **거둬 피해로 바꾼다** -----------------
	{"id":"shield_bash","name":"방패 밀치기","symbol":"D","kind":"melee","element":"psi","form":"guard","silhouette":"shield","impact":"stagger","desc":"두 번 밀쳐 수호막 한 겹","combo":"붙은 상태를 거둬 피해로 바꾼다","damage":0.82,"duration":0.90,"action_ratio":0.78,"reload":0.36,"range":122.0,"arc":2.28,"hits":2,"shield":1,"knockback":28.0,"color":"bd6ac8","debt_desc":"마왕이 막으면서 동시에 때립니다."},
	{"id":"holy_pulse","name":"정신 파동","symbol":"H","kind":"area","element":"psi","form":"wave","silhouette":"wave","impact":"pop","desc":"넓게 두 번 터뜨린다","combo":"상태가 많이 붙었을수록 세다","damage":1.55,"duration":1.40,"action_ratio":0.56,"reload":0.65,"range":245.0,"arc":6.283,"hits":2,"heavy":true,"color":"bd6ac8","debt_desc":"마왕의 넓은 공격이 정신을 갉습니다."},
	{"id":"battle_trance","name":"정신 집중","symbol":"I","kind":"area","element":"psi","form":"guard","silhouette":"orbit","impact":"haste_self","desc":"세 번 치며 체력과 수호막","combo":"상태를 거두면서 버틴다","damage":0.42,"duration":1.18,"action_ratio":0.88,"reload":0.46,"range":125.0,"arc":6.283,"hits":3,"heal":2.0,"shield":1,"color":"bd6ac8","debt_desc":"마왕이 싸울수록 회복하는 법을 익힙니다."},
	{"id":"blade_fan","name":"정신 부채","symbol":"V","kind":"projectile","element":"psi","form":"pierce","silhouette":"throw","impact":"push","desc":"다섯 줄기를 멀리 보낸다","combo":"여럿의 상태를 한꺼번에 거둔다","damage":0.64,"duration":1.00,"action_ratio":0.72,"reload":0.41,"range":510.0,"arc":0.9,"hits":1,"projectiles":5,"spread":0.22,"pierce":1,"color":"bd6ac8","debt_desc":"마왕의 검기가 부채처럼 늘어납니다."}
]

# -----------------------------------------------------------------------------
# 특별 스킬 12종 = **보스 트로피 카드** (§5.5 · 부록 A-2 ⑳)
# -----------------------------------------------------------------------------
# v2에서는 계보 3종(성기사/광전사/창기사)의 각성 보상이었다. v3는 계보를 폐기하고
# 이 12장을 **보스 격파 2택1 트로피**로 재해석한다.
#   ① 속성을 역할 승계로 옮겼다(light→psi / blood→poison / iron→strike).
#   ② **계보 색을 지웠다** — 이름과 설명에서 "성기사 전용" 같은 계보 문구를 전부 제거.
#   ③ `tier2` 키는 남긴다. 계보 2차 각성 표식이 아니라 **트로피 등급**으로 재해석되며
#      `trophy_library.gd`가 스테이지 배분에 그대로 읽는다.
# 수치·id·form·element는 한 글자도 바꾸지 않았다. 배분표는 `trophy_library.gd`가 소유한다.
#
# 특별 카드는 data_test의 "속성당 정확히 4장" 집계에서 제외된다(드래프트 풀이
# 아니기 때문). **실루엣 유일성 계약(§4.4)의 대상도 아니다** — 다만 SILHOUETTES에
# 있는 유효한 id여야 한다. 속성·형태 어휘 검사는 일반 카드와 똑같이 받는다.
#
# Y3: `combo` · `silhouette` · `impact`를 붙이고 `name`·`desc`를 쉬운 한글로 다시
# 썼다(트로피 2택1 화면이 이 두 줄을 읽는다). `color`도 속성색으로 맞췄다.
# -----------------------------------------------------------------------------
const SPECIALS: Array[Dictionary] = [
	{"id":"holy_verdict","name":"정신 심판검","symbol":"P1","kind":"melee","element":"psi","form":"slash","silhouette":"combo_slash","impact":"stagger","desc":"넓게 세 번 베고 수호막","combo":"상태를 거두며 수호막까지 챙긴다","damage":2.1,"duration":1.35,"action_ratio":0.94,"reload":0.43,"range":198.0,"arc":2.7,"hits":3,"shield":1,"color":"bd6ac8","special":true,"debt_desc":"마왕이 검은 빛의 검을 배웁니다."},
	{"id":"aegis_process","name":"끝없는 방패 파동","symbol":"P2","kind":"area","element":"psi","form":"guard","silhouette":"shield","impact":"push","desc":"다섯 번 치고 수호막 두 겹","combo":"때리면서 동시에 단단해진다","damage":1.15,"duration":1.18,"action_ratio":0.9,"reload":0.41,"range":184.0,"arc":6.283,"hits":5,"shield":2,"color":"bd6ac8","special":true,"debt_desc":"마왕의 갑옷이 먼저 때리기 시작합니다."},
	{"id":"heavens_gate","name":"열린 하늘문","symbol":"PX","kind":"area","element":"psi","form":"wave","silhouette":"wave","impact":"pop","desc":"화면을 다섯 번 덮는다","combo":"수호막 세 겹으로 버티며 쓸어낸다","damage":3.4,"duration":1.15,"action_ratio":0.96,"reload":0.46,"range":330.0,"arc":6.283,"hits":5,"shield":3,"color":"bd6ac8","special":true,"tier2":true,"debt_desc":"마왕이 검은 하늘문을 엽니다."},
	{"id":"zero_damage_oath","name":"깨지지 않는 서약","symbol":"PZ","kind":"shield","element":"psi","form":"guard","silhouette":"shield","impact":"push","desc":"수호막 다섯 겹과 반격 세 번","combo":"버티는 동안 알아서 되갚는다","damage":2.2,"duration":1.25,"action_ratio":0.92,"reload":0.48,"range":260.0,"arc":6.283,"hits":3,"shield":5,"color":"bd6ac8","special":true,"tier2":true,"debt_desc":"마왕이 무너지지 않는 갑옷을 얻습니다."},
	{"id":"crimson_loop","name":"독의 난무","symbol":"B1","kind":"melee","element":"poison","form":"slash","silhouette":"combo_slash","impact":"stagger","desc":"빠르게 여섯 번 벤다","combo":"벨수록 독이 쌓이고 피가 는다","damage":1.05,"duration":1.32,"action_ratio":0.98,"reload":0.24,"range":155.0,"arc":2.1,"hits":6,"lifesteal":0.06,"color":"83c65c","special":true,"debt_desc":"마왕의 난무가 끝나지 않습니다."},
	{"id":"pain_compiler","name":"고통 되갚기","symbol":"B2","kind":"area","element":"poison","form":"wave","silhouette":"wave","impact":"pop","desc":"주변을 다섯 번 터뜨린다","combo":"터뜨린 만큼 피를 되찾는다","damage":1.3,"duration":1.05,"action_ratio":0.94,"reload":0.43,"range":182.0,"arc":6.283,"hits":5,"lifesteal":0.1,"color":"83c65c","special":true,"debt_desc":"마왕이 아픔을 힘으로 바꿉니다."},
	{"id":"red_moon_execution","name":"붉은 달 마지막 검","symbol":"BX","kind":"melee","element":"poison","form":"slash","silhouette":"combo_slash","impact":"stagger","desc":"아주 빠르게 여덟 번 벤다","combo":"쌓인 독을 여덟 번 헤집는다","damage":1.75,"duration":1.36,"action_ratio":0.99,"reload":0.22,"range":220.0,"arc":2.55,"hits":8,"lifesteal":0.08,"color":"83c65c","special":true,"tier2":true,"debt_desc":"마왕이 붉은 달의 난무를 완성합니다."},
	{"id":"immortal_frenzy","name":"죽지 않는 광란","symbol":"BI","kind":"area","element":"poison","form":"wave","silhouette":"orbit","impact":"push","desc":"아홉 번 몰아치고 수호막","combo":"때릴수록 피가 차서 안 죽는다","damage":1.8,"duration":1.2,"action_ratio":1.0,"reload":0.31,"range":245.0,"arc":6.283,"hits":9,"shield":2,"lifesteal":0.12,"color":"83c65c","special":true,"tier2":true,"debt_desc":"마왕이 죽지 않는 광란에 빠집니다."},
	{"id":"dragon_pierce","name":"용의 창","symbol":"L1","kind":"projectile","element":"strike","form":"pierce","silhouette":"thrust","impact":"pin","desc":"아주 멀리 두 번 꿰뚫는다","combo":"한 줄에 선 적을 전부 뚫는다","damage":2.8,"duration":1.10,"action_ratio":0.84,"reload":0.38,"range":720.0,"arc":0.16,"hits":2,"projectiles":1,"pierce":9,"color":"c3bda4","special":true,"debt_desc":"마왕이 용의 창을 얻습니다."},
	{"id":"echo_thrust","name":"잔상 찌르기","symbol":"L2","kind":"melee","element":"strike","form":"pierce","silhouette":"thrust","impact":"pin","desc":"각도를 바꿔 다섯 번 찌른다","combo":"빈틈 없이 이어 찔러 붙든다","damage":1.65,"duration":1.18,"action_ratio":0.97,"reload":0.30,"range":285.0,"arc":0.62,"hits":5,"color":"c3bda4","special":true,"debt_desc":"마왕의 찌르기가 여러 갈래로 늘어납니다."},
	{"id":"sky_dragon_array","name":"하늘 용 진형","symbol":"LX","kind":"projectile","element":"strike","form":"pierce","silhouette":"rain","impact":"push","desc":"화면 끝까지 다섯 번 뚫는다","combo":"줄지어 선 적을 통째로 지운다","damage":2.55,"duration":1.42,"action_ratio":1.0,"reload":0.26,"range":850.0,"arc":0.72,"hits":5,"projectiles":3,"pierce":12,"color":"c3bda4","special":true,"tier2":true,"debt_desc":"마왕이 하늘 용의 진형을 훔칩니다."},
	{"id":"infinite_recursion","name":"끝없이 도는 창","symbol":"LR","kind":"projectile","element":"strike","form":"pierce","silhouette":"throw","impact":"pop","desc":"튕기고 뚫으며 네 번 돈다","combo":"사방을 오가며 계속 되돌아온다","damage":2.15,"duration":1.50,"action_ratio":1.0,"reload":0.23,"range":780.0,"arc":0.35,"hits":4,"projectiles":2,"pierce":6,"ricochet":7,"color":"c3bda4","special":true,"tier2":true,"debt_desc":"마왕의 창이 멈출 줄을 모릅니다."}
]

# -----------------------------------------------------------------------------
# 조회
# -----------------------------------------------------------------------------

static func all() -> Array[Dictionary]:
	# 28종 전부. v3에서는 draft_pool()과 내용이 같다(legacy 0장).
	return SKILLS.duplicate(true)

static func all_with_specials() -> Array[Dictionary]:
	var result := SKILLS.duplicate(true)
	result.append_array(SPECIALS.duplicate(true))
	return result

## v3 드래프트 풀(§5.1, 28종 = 7속성 × 4장). legacy 승격으로 SKILLS 전량과 같다.
## 레벨업 2택1·성 상점·전조 회수 등 "새 카드를 준다"는 모든 경로는 이 함수를 써야 한다.
## legacy 필터는 **일부러 남겼다** — 앞으로 다시 풀에서 카드를 빼야 할 때
## 데이터 한 키(`"legacy": true`)만 붙이면 되고 호출부는 그대로다.
static func draft_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for card: Dictionary in SKILLS:
		if not bool(card.get("legacy", false)):
			pool.append(card.duplicate(true))
	return pool

static func draft_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in SKILLS:
		if not bool(card.get("legacy", false)):
			ids.append(String(card["id"]))
	return ids

## v3에서는 항상 false다(legacy 0장). 함수는 호출부 보호를 위해 남긴다.
static func is_legacy(id: String) -> bool:
	for card: Dictionary in SKILLS:
		if card["id"] == id:
			return bool(card.get("legacy", false))
	return false

static func by_id(id: String) -> Dictionary:
	if id == "basic":
		return BASIC.duplicate(true)
	for card: Dictionary in SKILLS:
		if card["id"] == id:
			return card.duplicate(true)
	for card: Dictionary in SPECIALS:
		if card["id"] == id:
			return card.duplicate(true)
	return {}

## 속성별 드래프트 풀. W6 편집 화면이 "이 칸에 맞는 카드" 필터로 쓴다.
static func by_element(element: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: Dictionary in draft_pool():
		if String(card.get("element", "")) == element:
			result.append(card)
	return result

## 형태별 드래프트 풀. 삼각 배열(1·3·5칸 같은 형태) 안내에 쓴다.
static func by_form(form: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: Dictionary in draft_pool():
		if String(card.get("form", "")) == form:
			result.append(card)
	return result

## 사거리 등급(§5.1). "melee"(<200) / "mid"(200~260) / "ranged"(≥260).
## 근접+원거리 혼합 단일 풀이라는 요구(부록 A-1 ⑥)가 지켜지는지 여기 한 곳에서 판정한다.
static func range_class(card: Dictionary) -> String:
	var r := float(card.get("range", 0.0))
	if r >= RANGED_RANGE_MIN:
		return "ranged"
	if r < MELEE_RANGE_MAX:
		return "melee"
	return "mid"

## 속성 → 드래프트 장수. 7속성 전부 CARDS_PER_ELEMENT(4)여야 한다.
static func element_counts() -> Dictionary:
	var counts: Dictionary = {}
	for element: String in ELEMENTS:
		counts[element] = 0
	for card: Dictionary in SKILLS:
		if bool(card.get("legacy", false)):
			continue
		var element := String(card.get("element", ""))
		if counts.has(element):
			counts[element] = int(counts[element]) + 1
	return counts

## 속성 → 형태 장수. 형태당 ≥5(삼각 배열이 5형태 전부에서 가능)를 여기서 센다.
static func form_counts() -> Dictionary:
	var counts: Dictionary = {}
	for form: String in FORMS:
		counts[form] = 0
	for card: Dictionary in SKILLS:
		if bool(card.get("legacy", false)):
			continue
		var form := String(card.get("form", ""))
		if counts.has(form):
			counts[form] = int(counts[form]) + 1
	return counts

## 속성 → {"melee":n, "mid":n, "ranged":n}. 근접/원거리 커버리지 단언의 단일 지점.
static func element_range_profile() -> Dictionary:
	var profile: Dictionary = {}
	for element: String in ELEMENTS:
		profile[element] = {"melee": 0, "mid": 0, "ranged": 0}
	for card: Dictionary in SKILLS:
		if bool(card.get("legacy", false)):
			continue
		var element := String(card.get("element", ""))
		if not profile.has(element):
			continue
		var bucket: Dictionary = profile[element]
		var key := range_class(card)
		bucket[key] = int(bucket[key]) + 1
	return profile

static func instance(id: String, rank: int = 1) -> Dictionary:
	# 저장되는 랭크 자체는 v1 그대로 1~5를 허용한다. v1 융합 경제(R5 2장 → 전직)와
	# 세이브가 아직 그 범위를 쓰기 때문이다. **수치 성장만** MAX_RANK에서 멈춘다(ranked()).
	return {"kind":"skill", "id":id, "rank":clampi(rank, 1, 5)}

static func basic_instance() -> Dictionary:
	return {"kind":"skill", "id":"basic", "rank":1, "default":true}

# -----------------------------------------------------------------------------
# 태그 표기 (§4.2 · Y3 §3.2)
# -----------------------------------------------------------------------------

## 속성 표시명. 한자 병기를 버리고 쉬운 한글 한 낱말로 간다(§3.2).
## **내부 키(fire/ice/…)는 바뀌지 않았다 — 바뀐 것은 이 7줄뿐이다.**
static func element_name(element: String) -> String:
	match element:
		"fire": return "불"
		"ice": return "얼음"
		"thunder": return "번개"
		"poison": return "독"
		"oil": return "기름"
		"strike": return "타격"
		"psi": return "정신"
		_: return "속성 없음"

## 속성이 하는 일 한 줄(§4.1 동사 체계). 카드 툴팁·온보딩·편집 화면 안내가 쓴다.
static func element_role(element: String) -> String:
	match element:
		"fire": return "불을 붙이고 태운다"
		"ice": return "얼리고 느리게 만든다"
		"thunder": return "찌릿하게 만들고 옆으로 퍼진다"
		"poison": return "겹칠수록 세지게 쌓는다"
		"oil": return "적셔서 불이 잘 붙게 한다"
		"strike": return "쌓인 것을 터뜨린다"
		"psi": return "붙은 것을 거둬 피해로 바꾼다"
		_: return "속성이 없다"

## 상태를 **만드는** 속성인가(생산자). false면 거둬들이는 쪽이다(§4.4 설계 의도 1).
static func element_is_producer(element: String) -> bool:
	return element in ["fire", "ice", "thunder", "poison", "oil"]

static func form_name(form: String) -> String:
	match form:
		"slash": return "참격"
		"pierce": return "관통"
		"wave": return "파동"
		"trap": return "설치"
		"guard": return "수호"
		_: return "무형"

## 실루엣 표시명(§4.4). `form`과는 **별개 축**이다 — 이쪽은 아이콘 모양이다.
static func silhouette_name(silhouette: String) -> String:
	match silhouette:
		"slash": return "베기"
		"combo_slash": return "연속베기"
		"heavy_slash": return "큰베기"
		"thrust": return "찌르기"
		"dash": return "돌진"
		"throw": return "던지기"
		"homing": return "유도"
		"chain": return "연쇄"
		"wave": return "파동"
		"orbit": return "회전"
		"field": return "장판"
		"rain": return "비"
		"vortex": return "소용돌이"
		"shield": return "방패"
		_: return "모양 없음"

## 충격 프로필 표시명(§7.3).
## ⚠️ **화면에 뜨는 표가 아니다.** 유일한 호출자는 `scripts/test/balance_probe.gd`가
## 찍는 밸런스 리포트 한 줄뿐이고, 실제 카드 UI 어휘는 아래 `combat_tags()`가 만든다.
## 죽은 코드로 보고 지우지 말 것 — 리포트를 읽을 때 필요하다.
## YZ: 같은 개념을 두 함수가 다르게 부르던 것을 `combat_tags()` 쪽 어휘로 맞췄다.
static func impact_name(impact: String) -> String:
	match impact:
		"push": return "밀쳐내기"
		"pin": return "붙잡기"
		"slow": return "느려짐"
		"drag": return "끌어당김"
		"rush": return "몰아붙이기"
		"haste_self": return "내가 빨라짐"
		"stagger": return "잠깐 멈춤"
		"pop": return "띄우기"
		_: return "충격 없음"

## §4.4 유일성 계약 — 같은 속성 안에서 실루엣이 겹치면 안 된다.
## 드래프트 28장의 (element, silhouette) 28쌍이 전부 고유하면 true. data_test가 부른다.
## SPECIALS는 속성당 4장 집계에서 빠지므로 이 계약의 대상이 아니다.
static func silhouette_pairs_unique() -> bool:
	var seen: Dictionary = {}
	for card: Dictionary in SKILLS:
		if bool(card.get("legacy", false)):
			continue
		var pair := "%s/%s" % [String(card.get("element", "")), String(card.get("silhouette", ""))]
		if seen.has(pair):
			return false
		seen[pair] = true
	return true

## "불 · 참격" 한 줄. 카드 툴팁·레일 배지가 그대로 쓴다.
static func tag_label(card: Dictionary) -> String:
	var element := String(card.get("element", ""))
	var form := String(card.get("form", ""))
	if element == "" and form == "":
		return ""
	return "%s · %s" % [element_name(element), form_name(form)]

static func kind_name(kind: String) -> String:
	match kind:
		"melee": return "가까이 베기"
		"dash": return "돌진 베기"
		"projectile": return "멀리 날리기"
		"chain": return "이어 치기"
		"area": return "주변 전체"
		"ground": return "바닥 깔기"
		"orbit": return "돌며 치기"
		"shield": return "막기"
		_: return "특별한 기술"

static func combat_tags(card: Dictionary) -> String:
	var tags: Array[String] = []
	var tag := tag_label(card)
	if tag != "":
		tags.append(tag)
	tags.append(kind_name(String(card.get("kind", ""))))
	var hits := maxi(1, int(card.get("hits", 1)))
	if hits > 1:
		tags.append("%d번 친다" % hits)
	if int(card.get("projectiles", 1)) > 1:
		tags.append("%d발" % int(card.get("projectiles", 1)))
	if int(card.get("shield", 0)) > 0:
		tags.append("수호막 +%d" % int(card.get("shield", 0)))
	if float(card.get("lifesteal", 0.0)) > 0.0:
		tags.append("피 회복")
	if float(card.get("slow", 0.0)) > 0.0:
		tags.append("느려짐")
	if float(card.get("pull", 0.0)) > 0.0:
		tags.append("끌어당김")
	var reaction := knockback_profile(card)
	if float(reaction.get("force", 0.0)) >= 250.0:
		tags.append("강한 밀쳐내기")
	elif float(reaction.get("force", 0.0)) > 0.0:
		tags.append("밀쳐내기")
	elif float(reaction.get("stun", 0.0)) > 0.0:
		tags.append("잠깐 멈춤")
	if bool(card.get("random_impacts", false)):
		tags.append("여러 곳에 떨어짐")
	return " · ".join(tags)

## impact 8종의 authored 기본표(§7.3). 수치는 이동 거리가 아니라 초당 반동 속도다.
## ⚠️ 여기 값은 §7.3 표의 강/중/약·짧/중/김을 기존 kind 기반 눈금(72~305 · 0.045~0.12)에
##    옮겨 적은 **초안**이다. **실제 튜닝은 Y7 몫이다.**
##    "대상 정지 0.25초"(pin) · "이동 −35% 1.2초"(slow) · "점점 느려짐"(rush) ·
##    "내 이동 +20%"(haste_self) · "0.3초 공중"(pop) 같은 시간 효과도 Y7이 붙인다.
static func impact_reaction(impact: String) -> Dictionary:
	match impact:
		"push": return {"force":285.0, "stun":0.09}
		"pin": return {"force":0.0, "stun":0.26}
		"slow": return {"force":95.0, "stun":0.07}
		"drag": return {"force":0.0, "stun":0.075}
		"rush": return {"force":160.0, "stun":0.13}
		# §7.3 표의 haste_self는 넉백·경직이 둘 다 "—"지만 **경직을 0으로 둘 수는 없다** —
		# `data_test.gd:162` / `test_runner.gd:561`이 "피해를 주면 경직이 있어야 한다"를
		# 단언한다. 그래서 기존 눈금의 바닥값(chain·orbit 0.045)보다 낮은 0.04를 준다.
		"haste_self": return {"force":0.0, "stun":0.04}
		"stagger": return {"force":90.0, "stun":0.22}
		"pop": return {"force":175.0, "stun":0.14}
		_: return {}

static func knockback_profile(card: Dictionary) -> Dictionary:
	# 수치는 이동 거리 자체가 아니라 초당 반동 속도입니다. 강한 기술일수록 더 멀고 오래 밀립니다.
	# §7.3: 카드에 authored `impact` 키가 있으면 **그것이 kind 기반 값보다 우선한다.**
	# impact가 이미 세기를 담고 있으므로 heavy/knockback 보정을 겹쳐 걸지 않는다.
	var impact := String(card.get("impact", ""))
	if impact != "":
		var authored := impact_reaction(impact)
		if not authored.is_empty():
			return authored
	# --- 아래는 impact 키가 없는 카드(BASIC 등)를 위한 폴백이다. 지우지 않았다. ---
	var kind := String(card.get("kind", "melee"))
	var force := 0.0
	var stun := 0.0
	match kind:
		"melee": force = 185.0; stun = 0.09
		"dash": force = 305.0; stun = 0.12
		"projectile": force = 118.0; stun = 0.055
		"chain": force = 72.0; stun = 0.045
		"area": force = 158.0; stun = 0.085
		"ground": force = 105.0; stun = 0.065
		"orbit": force = 88.0; stun = 0.045
		"shield": force = 215.0 if float(card.get("damage", 0.0)) > 0.0 else 0.0; stun = 0.1 if force > 0.0 else 0.0
	if float(card.get("pull", 0.0)) > 0.0:
		force = 0.0
		stun = maxf(stun, 0.075)
	var authored_knockback := float(card.get("knockback", 0.0))
	if authored_knockback > 0.0:
		force = maxf(force, 145.0 + authored_knockback * 4.1)
		stun = maxf(stun, 0.12)
	if bool(card.get("heavy", false)):
		force *= 1.32
		stun *= 1.45
	return {"force":force, "stun":stun}

# -----------------------------------------------------------------------------
# 랭크 (§5.2 · §9.3)
# -----------------------------------------------------------------------------

## 랭크 r의 계수 3종. 단일 진실 원천 — UI 미리보기도 이 함수를 쓸 것.
## r은 MAX_RANK(3)에서 포화한다. R1=1.00 / R2=1.55 / R3=2.10배 피해.
static func rank_formula(rank: int) -> Dictionary:
	var effective := clampi(rank, 1, MAX_RANK)
	var step := float(effective - 1)
	return {
		"rank": effective,
		"damage_mul": 1.0 + RANK_DAMAGE_STEP * step,
		"duration_mul": pow(RANK_DURATION_FALLOFF, step),
		"reload_mul": pow(RANK_RELOAD_FALLOFF, step),
		"range_mul": 1.0 + RANK_RANGE_STEP * step
	}

static func ranked(instance_data: Dictionary) -> Dictionary:
	var base := by_id(String(instance_data.get("id", "basic")))
	if base.is_empty():
		base = BASIC.duplicate(true)
	# 표시용 랭크는 저장된 값 그대로(R4·R5 융합 표기가 살아 있어야 한다).
	var stored_rank := clampi(int(instance_data.get("rank", 1)), 1, 5)
	base["rank"] = stored_rank
	base["kind"] = String(base.get("kind", "melee"))
	base["card_kind"] = "skill"
	base["element"] = String(base.get("element", ""))
	base["form"] = String(base.get("form", ""))
	if not bool(base.get("special", false)):
		# 수치 성장은 MAX_RANK에서 멈춘다(§5.2 "상한 R3").
		var f := rank_formula(stored_rank)
		base["effective_rank"] = int(f["rank"])
		base["damage"] = float(base.get("damage", 0.0)) * float(f["damage_mul"])
		base["duration"] = float(base.get("duration", 0.5)) * float(f["duration_mul"])
		base["reload"] = float(base.get("reload", 0.2)) * float(f["reload_mul"])
		base["range"] = float(base.get("range", 0.0)) * float(f["range_mul"])
	else:
		base["effective_rank"] = 1
	return base

# -----------------------------------------------------------------------------
# 드래프트 · 평가
# -----------------------------------------------------------------------------

static func random_two(rng: RandomNumberGenerator) -> Array[Dictionary]:
	# v3 풀(28종 = 7속성 × 4장) 전량에서 뽑는다.
	var pool := draft_pool()
	for index in range(pool.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary: Dictionary = pool[index]
		pool[index] = pool[other]
		pool[other] = temporary
	return [pool[0], pool[1]]

static func expected_power(instance_data: Dictionary) -> float:
	var card := ranked(instance_data)
	var damage := float(card.get("damage", 0.0))
	var hits := maxi(1, int(card.get("hits", 1)))
	var projectiles := maxi(1, int(card.get("projectiles", 1)))
	var duration := maxf(0.12, float(card.get("duration", 0.5)))
	var utility := float(card.get("shield", 0)) * 0.7 + float(card.get("range", 0.0)) / 500.0
	return damage * hits * projectiles / duration + utility

static func debt_module(id: String) -> String:
	var card := by_id(id)
	var kind := String(card.get("kind", "melee"))
	match kind:
		"shield": return "firewall"
		"projectile", "chain": return "targeting"
		"ground", "area": return "overclock"
		"orbit": return "cache"
		"dash": return "targeting"
		_:
			if id in ["blood_pact", "pain_compiler", "immortal_frenzy"]:
				return "hotfix"
			if id in ["recursion", "infinite_recursion"]:
				return "recursion"
			return "overclock"
