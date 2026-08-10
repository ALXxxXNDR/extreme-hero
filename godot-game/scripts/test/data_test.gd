extends SceneTree

# =============================================================================
# 콘텐츠 데이터 단독 테스트 (standalone) — W7 신설 · V2가 v3로 갱신
# =============================================================================
# 실행:
#   godot --headless --path godot-game -s res://scripts/test/data_test.gd
#
# 게임 코드(game.gd·test_runner.gd·run_all.sh)를 한 줄도 건드리지 않는다. SceneTree를
# 직접 확장해 메인 씬 없이 돌고, 데이터 파일만 preload한다.
#
# 출력 규약(run_all.sh와 동일):
#   * 합격 → `DATA_TEST_COMPLETE <판정>=true ... <수치>=<숫자>` 한 줄 + 종료 코드 0
#   * 불합격 → `DATA_TEST_DETAIL ...` 여러 줄 + `DATA_TEST_FAILED failed=...` + 종료 코드 1
#   * 판정은 전부 `=true`로만 나온다. 정보성 값은 숫자로 낸다(=false 문자열 금지).
#
# ── v3에서 추가된 판정 (설계 부록 B V2 완료 기준) ────────────────────────────
#   `element_exact`   원소당 **정확히** 4장 (28 = 7 × 4)
#   `range_coverage`  원소당 근접(<200) ≥1 · 원거리(≥260) ≥1
#   `tag_playable`    형태당 ≥5 (v2는 ≥3이었다 — 기준을 **올렸다**)
#   `legacy_zero`     legacy 0장 + 구 legacy 8종 id가 전부 by_id로 살아 있다(세이브 호환)
#   `monster_stages`  스테이지 티어 T1~T4 · 누적 종 수 4·6·8·9·10
#   `trophy_table`    트로피 5종 × 2택1 = 10장 + 예비 2장 = SPECIALS 12종 정확히 소진
#   `boss_table`      보스 3종 × 4패턴 · 스키마 · 강화형 파생 · 리그 5벌
#
# ── Y 라운드에서 추가된 판정 (FEEDBACK_Y §2~§7) ──────────────────────────────
#   `card_text_limits`          desc 16자 · combo 18자 상한 (§4.2)
#   `card_shape_vocab`          silhouette ∈ SILHOUETTES(14) · impact ∈ IMPACTS(8)
#   `silhouette_unique`         (element, silhouette) 28쌍 전부 고유 (§4.4 유일성 계약)
#   `card_color_matches_element` 40장의 color가 §3.2 색표와 일치 — 스테일 color 회귀 방지
#   `no_banned_words`           폐기 어휘(과열·한자 마크 등)가 유저에게 보이는 문구에 0건
#   `rune_catalog_15`           RUNES가 정확히 15키이고 id 집합이 §2.1·§2.2와 일치
#   `rune_rarity_split`         일반 6 · 희귀 6 · 영웅 3
#   `rune_scope_split`          slot 10 · rail 5 · 전 정의가 scope 키를 갖는다
#   `rune_flow_family`          family=="flow"가 정확히 6종 (§2.6 흐름 할증 대상)
#   `rune_no_legacy`            폐기 24종 id가 한 개도 남아 있지 않다
#   `rune_exec_cap`             SLOT_EXEC_CAP 2 · STEP_CAP 12 · 과열 셔틀 키가 되살아나지 않았는가(Y8)
#   `monster_habits`            habit 5종 어휘 + 5종 전부 최소 1마리 (§5.2)
#   `monster_reactions`         kb/stun/slow 민감도가 전부 양수·합리 범위 (§7.2)
#   `monster_terrain_weight`    지형×습성 가중표 어휘·값 + 미등록 타일 폴백 1.0 (§5.3)
#   `aggro_gate_stage3`         1·2스테이지 낮 선공 0 — 게이트 하한 2 → 3 (§5.4)

const Cards = preload("res://scripts/deal_card_library.gd")
const Monsters = preload("res://scripts/monster_library.gd")
const Rune = preload("res://scripts/core/rune_engine.gd")
const Trophies = preload("res://scripts/trophy_library.gd")
const Items = preload("res://scripts/item_library.gd")
const Bosses = preload("res://scripts/boss_library.gd")

# 상태이상 5종(§4.3). 정본은 StatusEngine(V1)이지만 보스 패턴의 `status` 키를
# 검사하려면 이 테스트도 어휘를 알아야 한다. V1이 상수를 노출하면 그쪽을 참조할 것.
const STATUS_IDS: Array[String] = ["poison", "burn", "chill", "oil", "shock"]

# ③ RELOAD 재기준 판정 밴드
#
# ⚠️ **Y 라운드에서 밴드를 다시 잡았다.** 이전 값은 3.0 ± 1.0(부록 C-6의 "≈3초")였다.
#
# 왜 바꿨나 — **RELOAD 식에서 과열 항이 사라졌다.**
#   구식: reload = 빚 × (1 + 과열 × HEAT_RELOAD 0.18)
#   신식: reload = 빚 × 레일배율 × reload_scale            (rune_engine.gd:946)
# 과열이 폐기되면서(§1.4) 곱해지던 1.0~2.4배 항이 통째로 1.0이 됐다. 빚은 밟은 칸 수에
# **선형**이고 SLOT_EXEC_CAP 2가 스텝을 12로 묶으므로, 평균 RELOAD는 구조적으로 내려간다.
# 옛 밴드를 그대로 두면 데이터가 옳아도 테스트가 FAIL한다 — 그건 테스트 쪽 버그다.
#
# 실측(대표 덱 5종 × RELOAD_SAMPLES 사이클, 시드 4100 고정 · 아래 판정이 매 실행 재측정):
#   bare 2.39 · mid 2.29 · rewind 2.40 · tempo 0.51 · heavy 3.85 → 전체 평균 **2.29초**
# 새 밴드는 이 실측을 가운데 두고 잡았다. 폭(±1.0)은 유지한다 — 폭을 좁히면 각인
# 인스턴스 굴림(roll_rune) 하나만 흔들려도 깨지는 취성 테스트가 된다.
const RELOAD_TARGET := 2.3
const RELOAD_TOLERANCE := 1.0
const RELOAD_SAMPLES := 400          # 대표 덱 1개당 시뮬레이션 사이클 수

# 무각인 기준선(bare)의 상한. **이전에는 RELOAD_TARGET을 그대로 재사용했다.**
# 그 재사용은 "각인은 RELOAD를 올리기만 한다"는 옛 전제 위에 서 있었다 — 과열 시절에는
# 참이었다. 지금은 `quick`이 칸의 쉬는 시간을 지우고 `rail_rest`가 바퀴 전체를 깎아서
# **각인이 RELOAD를 내리는 방향으로도 움직인다**(실측 tempo 0.51 < bare 2.39).
# 그래서 무각인 기준선이 전체 평균보다 낮으리라는 보장이 사라졌고, 두 숫자를 같은
# 상수로 묶어 두면 데이터가 옳아도 FAIL한다. 기준선의 진짜 계약은 하나다 —
# **카드 무게만으로 RELOAD 상한의 절반을 먹으면 안 된다.** 6.0의 절반이 3.0이다.
const RELOAD_BARE_MAX := 3.0

# 카드가 반드시 가져야 하는 키. 하나라도 빠지면 v1 딜싸이클 컨트롤러가 기본값으로
# 조용히 대체해 버려서 밸런스가 눈에 안 띄게 무너진다.
# Y3: `combo` · `impact` · `silhouette` 3키를 추가했다(§4.2 · §7.3 · §4.4).
const CARD_REQUIRED_KEYS: Array[String] = [
	"id", "name", "symbol", "kind", "element", "form", "desc",
	"damage", "duration", "action_ratio", "reload", "range", "arc", "hits",
	"color", "debt_desc",
	"combo", "impact", "silhouette"
]
# BASIC(빈 칸 기본 공격)만 면제되는 키. BASIC은 드래프트에도 트로피에도 안 나오고
# 카드 UI가 아니라 안내 문구로만 쓰이므로 콤보 줄·아이콘 실루엣·충격 프로필이 없다.
# 속성이 없어서(§3.2 대상 밖) 실루엣 유일성·색 정합의 대상도 아니다.
const BASIC_EXEMPT_KEYS: Array[String] = ["combo", "impact", "silhouette"]

# §4.2 두 줄 형식의 길이 상한. 한글 1음절 = 1자다(String.length()가 그렇게 센다).
# desc가 넘치면 레벨업 카드 한 줄이 감기고, combo가 넘치면 속성색 줄이 잘린다.
const DESC_MAX_CHARS := 16
const COMBO_MAX_CHARS := 18

# §3.2 재배색표. **`game.gd`의 ELEMENT_COLOR가 런타임 단일 진실 원천이고, 이 표는
# 그 값을 카드 데이터가 스테일하게 들고 있지 않은지 대조하는 독립 사본이다.**
# 여기를 라이브러리에서 읽어 오면 "데이터가 데이터를 자기 자신과 비교"하게 되어
# 검사가 사라진다 — 그래서 일부러 하드코딩한다.
#   fire  주황 e78a45 → **빨강 e2452f** (기름 갈색·번개 노랑과 붙어 흐려졌다)
#   oil   보라 7563a8 → **갈색 7a5230** (정신 자주와 보라 두 개가 겹치던 원인)
#   나머지 5색은 유지.
const ELEMENT_COLOR_HEX: Dictionary = {
	"fire": "e2452f", "ice": "67c7d4", "thunder": "f4d35e", "poison": "83c65c",
	"oil": "7a5230", "strike": "c3bda4", "psi": "bd6ac8"
}

# 유저에게 보이는 문구에서 완전히 사라져야 하는 어휘.
#   과열 · 과부하 · 잔열   폐기된 열 시스템(§1.4)
#   나침반                 폐기된 내비 장치(§6.1 "안개는 쓰지 않는다")
#   체류                   용어 개편: "한 곳에 오래 머물면"으로 풀어 쓴다 → 「머문 시간」
#   RELOAD · 리로드        용어 개편: → 「쿨타임」 (쌓인 몫은 「쌓인 쿨타임」)
#   (火)…(超)              폐기된 한자 마크(§3.2 재작명)
# 아래 넷은 여기 없다 — 부분일치 오탐이 나서 전용 판정 함수가 따로 본다.
#   열기(폐기 각인 이름) · 각인 → 보석 · 레일 → 덱 · 밟(딜싸이클 비유)
const BANNED_WORDS: Array[String] = [
	"과열", "과부하", "잔열", "나침반", "체류", "RELOAD", "리로드",
	"(火)", "(氷)", "(雷)", "(毒)", "(油)", "(打)", "(超)"
]
## 폐기된 각인 `heat_gate`의 이름. 두 글자짜리라 부분일치가 위험하다(아래 주석 참조).
const BANNED_WORD_HEAT_GATE := "열기"
## `열기` 바로 뒤에 붙어도 여전히 **명사 「열기」**인 조사. 뒤 글자가 이 밖의 한글이면
## 「열기구」 같은 합성 명사로 보고 통과시킨다.
const HEAT_WORD_TRAILING_JOSA: Array[String] = ["가", "를", "는", "도", "만", "와", "로", "에", "의", "나"]
## 앞 토큰이 이 목적격 조사로 끝나면 동사 '열다'의 명사형이다(「하늘문을 열기 전에」).
const HEAT_WORD_OBJECT_PARTICLES: Array[String] = ["을", "를"]

# --- 용어 개편(2026-08-10) 3종. 전부 부분일치가 위험해서 낱말 경계를 따로 본다 -----
## 「각인」 → 「보석」. 「조각인」(조각 + 이다)과 동사 「각인하다/각인되다」가 오탐이다.
const BANNED_WORD_RUNE := "각인"
## 「각인」 뒤에 이어지면 **동사**다(각인되다 · 각인하다 · 각인시키다). 명사가 아니므로 통과.
const RUNE_WORD_VERB_TAILS: Array[String] = ["되", "돼", "하", "시"]
## 「레일」 → 「덱」. 「모노레일」·「트레일러」처럼 더 긴 낱말 안에 들어가면 통과.
const BANNED_WORD_RAIL := "레일"
## 「레일」 바로 뒤에 붙어도 여전히 명사 「레일」인 조사. 그 밖의 한글이면 합성어로 본다.
const RAIL_WORD_TRAILING_JOSA: Array[String] = ["을", "를", "이", "가", "은", "는", "도", "만", "과", "와", "로", "에", "의", "나"]
## 「밟」 → 딜싸이클 비유는 폐기. 「기름을 밟은 적」처럼 **진짜 발로 밟는** 쓰임은 통과.
const BANNED_WORD_STEP := "밟"
## 밟은 자리 뒤에 이 낱말이 나오면 딜싸이클 비유다(밟은 칸 · 밟은 횟수 · 밟은 바퀴).
const STEP_WORD_RAIL_CONTEXT: Array[String] = ["칸", "횟수", "바퀴", "사이클", "레일", "덱", "슬롯"]
## 밟기 직전에 이 낱말이 있으면 바닥을 밟는 물리적 서술이다(오탐 방지).
const STEP_WORD_GROUND_NOUNS: Array[String] = [
	"기름", "독", "불", "가시", "함정", "웅덩이", "장판", "땅", "바닥",
	"눈", "물", "얼음", "지뢰", "발판", "그림자", "재", "피"
]
## 위 두 문맥 창의 크기(글자 수). 한 절 안쪽만 본다 — 넓히면 문장 두 개가 섞인다.
const STEP_WORD_WINDOW := 12

# 폐기된 각인 24종 id (§2.3의 승계 11 + 폐기 13). **하드코딩이 목적이다** —
# RuneEngine에서 지웠다는 사실을 이 목록이 밖에서 증언해야 부활을 잡을 수 있다.
const LEGACY_RUNE_IDS: Array[String] = [
	# 승계된 것들 — 역할은 새 id가 잇고 **옛 id는 죽었다**
	"repeat", "rewind_1", "skip_1", "edge", "reach", "free_reload",
	"first_strike", "echo", "kill_repeat", "reverse", "haste",
	# 완전 폐기
	"rewind_2", "bookmark", "link_next", "chorus", "overlap", "tag_chain",
	"heat_gate", "last_call", "odd_even", "refund", "toll", "afterburn", "barb"
]
# §2.1 칸 10종 + §2.2 레일 5종. 순서까지 표와 같게 적었다(읽는 사람이 표와 대조한다).
const EXPECTED_RUNE_IDS: Array[String] = [
	"twice", "back_one", "jump_one", "strong", "wide",
	"quick", "first_hit", "twin_cast", "trade_skip", "finisher",
	"rail_fast", "rail_power", "rail_rest", "rail_color", "rail_loop"
]
const EXPECTED_RARITY_SPLIT: Dictionary = {"common": 6, "rare": 6, "epic": 3}
const EXPECTED_SCOPE_SPLIT: Dictionary = {"slot": 10, "rail": 5}
## §2.6 흐름 할증(RUNE_SHOP_FLOW_PREMIUM 1.25)의 대상과 정확히 같아야 한다.
const EXPECTED_FLOW_RUNES: Array[String] = [
	"twice", "back_one", "jump_one", "trade_skip", "finisher", "rail_loop"
]

# §3.2 재작명 — 한자를 버린 7계 이름.
const EXPECTED_ELEMENT_NAMES: Dictionary = {
	"fire": "불", "ice": "얼음", "thunder": "번개", "poison": "독",
	"oil": "기름", "strike": "타격", "psi": "정신"
}

const MONSTER_REQUIRED_KEYS: Array[String] = [
	"id", "name", "behavior", "unlock", "weight", "growth",
	"night_mul", "visual", "slash_hits", "speed", "damage", "xp",
	# Y5 신설 — 습성(§5.2)과 피격 반응 프로필(§7.2)
	"habit", "kb_sens", "stun_sens", "slow_sens", "hit_flavor"
]

# v4-test(test_runner.gd `skill_variety_ok`)가 모든 카드에 요구하는 duration 하한.
# 여기서도 같이 지켜 두면 데이터만 고쳐도 하네스가 깨지는 일이 없다.
const DURATION_FLOOR := 0.8

var _checks: Dictionary = {}
var _metrics: Dictionary = {}
var _failures: Array[String] = []


func _initialize() -> void:
	_check_card_schema()
	_check_tags()
	_check_runes()
	_check_rank_formula()
	_check_reload_baseline()
	_check_monsters()
	_check_monster_stages()
	_check_trophies()
	_check_bosses()
	_check_unique_ids()
	_report()


func _fail(check: String, reason: String) -> void:
	_checks[check] = false
	_failures.append("%s: %s" % [check, reason])


func _pass(check: String) -> void:
	if not _checks.has(check):
		_checks[check] = true


# -----------------------------------------------------------------------------
# 금지 어휘 스캐너 — `열기` 오탐 처리 포함
# -----------------------------------------------------------------------------
# 12개 금지어는 전부 세 글자 이상이거나 괄호를 끼고 있어서 부분일치가 안전하다.
# **`열기`만 다르다.** 두 글자짜리 한글이라 정상 문구를 물어뜯는다. 이 두 글자는
# 폐기된 각인 heat_gate의 이름이지만, 한국어에서 두 갈래로 정당하게 더 나온다.
#   ① 합성 명사의 앞머리 — 「열기구」「열기공」  → 뒤에 한글(조사 아님)이 이어진다
#   ② 동사 '열다'의 명사형 — 「하늘문을 열기 전에」 → 앞 토큰이 '을/를'로 끝난다
# 그래서 **낱말 경계**로 좁혔다.
#   * 앞 글자가 한글이면 더 긴 낱말의 꼬리다 → 통과
#   * 뒤 글자가 한글이고 조사가 아니면 합성 명사다 → 통과 (①)
#   * 앞 토큰이 목적격 조사로 끝나면 동사 명사형이다 → 통과 (②)
#   * 그 밖에 홀로 선 「열기」(+조사)만 각인 이름으로 보고 잡는다
# 남는 위험은 「회의를 열기로 했다」 같은 ②의 변형뿐이고, 그건 앞 토큰 규칙이 흡수한다.
# **현재 정본 데이터에서 이 함수가 잡는 건도, ①·②로 통과시키는 건도 0건이다** —
# 규칙은 회귀 방지용 안전망이지 지금 무언가를 봐주고 있는 게 아니다.
func _is_hangul_at(text: String, index: int) -> bool:
	if index < 0 or index >= text.length():
		return false
	var code := text.unicode_at(index)
	# 한글 음절 + 호환 자모. 여기 밖이면 공백·문장부호·라틴 문자다.
	return (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3130 and code <= 0x318F)


func _prev_token_ends_with_object_particle(text: String, at: int) -> bool:
	var index := at - 1
	while index >= 0 and text[index] == " ":
		index -= 1
	if index < 0:
		return false
	return HEAT_WORD_OBJECT_PARTICLES.has(text[index])


func _has_heat_gate_word(text: String) -> bool:
	var from := 0
	while true:
		var at := text.find(BANNED_WORD_HEAT_GATE, from)
		if at < 0:
			return false
		from = at + BANNED_WORD_HEAT_GATE.length()
		if _is_hangul_at(text, at - 1):
			continue                                        # 더 긴 낱말의 꼬리
		var after := at + BANNED_WORD_HEAT_GATE.length()
		if _is_hangul_at(text, after) and not HEAT_WORD_TRAILING_JOSA.has(text[after]):
			continue                                        # ① 「열기구」
		if _prev_token_ends_with_object_particle(text, at):
			continue                                        # ② 「…을 열기」
		return true
	return false


# --- 용어 개편 3종의 낱말 경계 판정 ------------------------------------------
# 셋 다 `_has_heat_gate_word()`와 같은 뼈대다: 등장 위치를 하나씩 훑으면서
# **오탐 경로에 걸리면 continue**, 남으면 진짜 금지어로 본다. 상한을 낮추는 대신
# 판정을 정교하게 만든다는 원칙을 그대로 따른다.

## 「각인」 → 「보석」. 오탐 두 갈래를 통과시킨다.
##   ① 더 긴 낱말의 꼬리 — 「조각인」(조각 + 서술격 조사). 앞 글자가 한글이면 통과.
##   ② 동사 「각인되다/각인하다/각인시키다」 — 뒤 글자가 되·돼·하·시면 통과.
## 남는 것은 홀로 선 명사 「각인」뿐이고, 그것이 「보석」으로 바뀌어야 하는 그 낱말이다.
func _has_rune_word(text: String) -> bool:
	var from := 0
	while true:
		var at := text.find(BANNED_WORD_RUNE, from)
		if at < 0:
			return false
		from = at + BANNED_WORD_RUNE.length()
		if _is_hangul_at(text, at - 1):
			continue                                        # ① 「조각인」
		var after := at + BANNED_WORD_RUNE.length()
		if after < text.length() and RUNE_WORD_VERB_TAILS.has(text[after]):
			continue                                        # ② 「각인되다」
		return true
	return false


## 「레일」 → 「덱」. 「모노레일」·「트레일러」·「레일건」 같은 합성어는 통과시킨다.
##   앞 글자가 한글이면 더 긴 낱말의 꼬리 · 뒤 글자가 조사 아닌 한글이면 합성 명사.
func _has_rail_word(text: String) -> bool:
	var from := 0
	while true:
		var at := text.find(BANNED_WORD_RAIL, from)
		if at < 0:
			return false
		from = at + BANNED_WORD_RAIL.length()
		if _is_hangul_at(text, at - 1):
			continue                                        # 「모노레일」
		var after := at + BANNED_WORD_RAIL.length()
		if _is_hangul_at(text, after) and not RAIL_WORD_TRAILING_JOSA.has(text[after]):
			continue                                        # 「레일건」
		return true
	return false


## 「밟」. **낱말이 아니라 문맥으로** 가른다 — 어간 한 글자라 형태만으로는 못 가른다.
##   * 뒤쪽 창에 칸·횟수·바퀴가 있으면 딜싸이클 비유다 → 잡는다(「두 번 밟은 칸」).
##   * 앞쪽 창에 기름·독·함정 같은 바닥 명사가 있으면 진짜 발로 밟는 것이다 → 통과.
##   * 둘 다 아니면 비유로 본다. 지금 정본에 그런 문장은 없고, 새로 생긴다면
##     그것도 십중팔구 딜싸이클 비유의 부활이다.
func _has_step_word(text: String) -> bool:
	var from := 0
	while true:
		var at := text.find(BANNED_WORD_STEP, from)
		if at < 0:
			return false
		from = at + BANNED_WORD_STEP.length()
		var tail := text.substr(at, STEP_WORD_WINDOW)
		var rail_context := false
		for token: String in STEP_WORD_RAIL_CONTEXT:
			if tail.contains(token):
				rail_context = true
				break
		if rail_context:
			return true
		var head_from := maxi(0, at - STEP_WORD_WINDOW)
		var head := text.substr(head_from, at - head_from)
		var ground := false
		for noun: String in STEP_WORD_GROUND_NOUNS:
			if head.contains(noun):
				ground = true
				break
		if ground:
			continue                                        # 「기름을 밟은 적」
		return true
	return false


## 이 문구가 물고 있는 금지 어휘. 없으면 빈 문자열.
func _banned_word_in(text: String) -> String:
	for word: String in BANNED_WORDS:
		if text.contains(word):
			return word
	if _has_heat_gate_word(text):
		return BANNED_WORD_HEAT_GATE
	if _has_rune_word(text):
		return BANNED_WORD_RUNE
	if _has_rail_word(text):
		return BANNED_WORD_RAIL
	if _has_step_word(text):
		return BANNED_WORD_STEP
	return ""


# v2의 legacy 8종. v3는 이 여덟 장을 **드래프트 풀로 승격**했다(§5.2).
# 승격했다는 것은 곧 "id가 살아 있다"는 뜻이고, id가 살아 있어야 아이콘 아틀라스
# 28칸·세이브·`skill_icon.GENERATED_SKILL_INDEX`가 전부 무변경으로 산다.
const PROMOTED_LEGACY_IDS: Array[String] = [
	"aura", "cross_cut", "lion_roar", "phantom_step",
	"sword_rain", "boomerang_blade", "battle_trance", "blade_fan"
]

# -----------------------------------------------------------------------------
# ① 스킬 28종 + 특별(트로피) 12종 스키마 완결성
# -----------------------------------------------------------------------------
func _check_card_schema() -> void:
	_pass("card_schema")
	_pass("draft_pool")
	_pass("legacy_zero")
	_pass("card_text_limits")
	_pass("card_shape_vocab")
	_pass("silhouette_unique")
	_pass("card_color_matches_element")
	_pass("no_banned_words")

	var draft: Array = Cards.draft_pool()
	var legacy_count := Cards.SKILLS.size() - draft.size()
	_metrics["skills_total"] = Cards.SKILLS.size()
	_metrics["skills_draft"] = draft.size()
	_metrics["skills_legacy"] = legacy_count
	_metrics["specials"] = Cards.SPECIALS.size()

	if draft.size() != Cards.DRAFT_POOL_SIZE:
		_fail("draft_pool", "드래프트 풀이 %d종 (기대 %d종)" % [draft.size(), Cards.DRAFT_POOL_SIZE])
	# 28 = 7원소 × 4장. 두 상수가 어긋나면 아이콘 아틀라스 7×4가 깨진다.
	if Cards.DRAFT_POOL_SIZE != Cards.ELEMENTS.size() * Cards.CARDS_PER_ELEMENT:
		_fail("draft_pool", "DRAFT_POOL_SIZE %d ≠ 원소 %d × %d" % [
			Cards.DRAFT_POOL_SIZE, Cards.ELEMENTS.size(), Cards.CARDS_PER_ELEMENT])
	if Cards.SKILLS.size() != Cards.DRAFT_POOL_SIZE:
		_fail("draft_pool", "SKILLS가 %d종인데 드래프트 풀이 %d종" % [Cards.SKILLS.size(), Cards.DRAFT_POOL_SIZE])
	if Cards.SPECIALS.size() != 12:
		_fail("card_schema", "특별 스킬이 %d종 (기대 12종)" % Cards.SPECIALS.size())

	# v3: legacy는 0장이어야 한다(전부 승격).
	if legacy_count != 0:
		_fail("legacy_zero", "legacy 카드가 %d장 남아 있다 (v3는 0장)" % legacy_count)
	# 그러나 구 legacy 8종의 **id는 하나도 사라지면 안 된다** — 세이브·아이콘 호환.
	var draft_ids: Array[String] = Cards.draft_ids()
	for id: String in PROMOTED_LEGACY_IDS:
		if Cards.by_id(id).is_empty():
			_fail("legacy_zero", "구 legacy 카드 %s가 by_id에서 사라졌다" % id)
		if not draft_ids.has(id):
			_fail("legacy_zero", "구 legacy 카드 %s가 드래프트 풀로 승격되지 않았다" % id)
		if Cards.is_legacy(id):
			_fail("legacy_zero", "%s가 아직 legacy로 표시돼 있다" % id)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260807
	var drawn: Dictionary = {}
	for _draw in 300:
		for card: Dictionary in Cards.random_two(rng):
			var drawn_id := String(card.get("id", ""))
			drawn[drawn_id] = true
			if not draft_ids.has(drawn_id):
				_fail("draft_pool", "random_two가 풀 밖 카드 %s를 냈다" % drawn_id)
	# 600회 뽑아서 28장 전부가 한 번씩은 나와야 한다 — 승격이 실제로 유효한지의 증거다.
	if drawn.size() != Cards.DRAFT_POOL_SIZE:
		_fail("draft_pool", "600회 드래프트에서 %d종만 등장 (기대 %d종)" % [drawn.size(), Cards.DRAFT_POOL_SIZE])

	var every: Array[Dictionary] = Cards.all_with_specials()
	every.append(Cards.BASIC.duplicate(true))
	for card: Dictionary in every:
		var id := String(card.get("id", "?"))
		var is_basic := id == "basic"
		for key: String in CARD_REQUIRED_KEYS:
			# BASIC은 콤보 줄·실루엣·충격 프로필이 없다(카드 UI에 안 실린다).
			if is_basic and BASIC_EXEMPT_KEYS.has(key):
				continue
			if not card.has(key):
				_fail("card_schema", "%s에 필수 키 '%s'가 없다" % [id, key])
		if float(card.get("damage", -1.0)) < 0.0:
			_fail("card_schema", "%s의 damage가 음수" % id)
		if float(card.get("reload", -1.0)) < 0.0:
			_fail("card_schema", "%s의 reload가 음수" % id)
		if int(card.get("hits", 0)) < 1:
			_fail("card_schema", "%s의 hits가 1 미만" % id)
		# BASIC은 빈 칸 대체용이라 duration 하한 검사에서 제외한다(v4-test도 제외한다).
		if id != "basic" and float(card.get("duration", 0.0)) < DURATION_FLOOR:
			_fail("card_schema", "%s의 duration %.2f가 하한 %.2f 미만" % [id, float(card.get("duration", 0.0)), DURATION_FLOOR])
		# 피해를 주는 카드는 사거리와 경직이 있어야 한다(v4-test combat_profiles와 같은 규칙).
		if float(card.get("damage", 0.0)) > 0.0:
			if float(card.get("range", 0.0)) <= 0.0:
				_fail("card_schema", "%s가 피해를 주는데 range가 0" % id)
			if float(Cards.knockback_profile(card).get("stun", 0.0)) <= 0.0:
				_fail("card_schema", "%s가 피해를 주는데 경직이 0" % id)

	# --- Y3 ①: 두 줄 형식의 길이 상한 (§4.2) -----------------------------------
	# 넘치면 레벨업 카드 5줄 레이아웃이 감긴다. BASIC은 카드 UI에 안 실리므로 제외한다.
	var authored: Array[Dictionary] = Cards.all_with_specials()
	var desc_max := 0
	var combo_max := 0
	for card: Dictionary in authored:
		var id := String(card.get("id", "?"))
		var desc := String(card.get("desc", ""))
		var combo := String(card.get("combo", ""))
		desc_max = maxi(desc_max, desc.length())
		combo_max = maxi(combo_max, combo.length())
		if desc.is_empty():
			_fail("card_text_limits", "%s의 desc가 비었다" % id)
		if combo.is_empty():
			_fail("card_text_limits", "%s의 combo가 비었다" % id)
		if desc.length() > DESC_MAX_CHARS:
			_fail("card_text_limits", "%s의 desc가 %d자 (상한 %d자) — \"%s\"" % [
				id, desc.length(), DESC_MAX_CHARS, desc])
		if combo.length() > COMBO_MAX_CHARS:
			_fail("card_text_limits", "%s의 combo가 %d자 (상한 %d자) — \"%s\"" % [
				id, combo.length(), COMBO_MAX_CHARS, combo])
	_metrics["desc_max_chars"] = desc_max
	_metrics["combo_max_chars"] = combo_max

	# --- Y3 ②: 실루엣·충격 어휘 (§4.4 · §7.3) ----------------------------------
	# 오타 하나면 skill_icon이 아틀라스 밖을 읽고 knockback_profile이 kind 폴백으로
	# 조용히 되돌아간다 — 둘 다 눈에 안 띄는 종류의 회귀다.
	for card: Dictionary in authored:
		var id := String(card.get("id", "?"))
		var silhouette := String(card.get("silhouette", ""))
		var impact := String(card.get("impact", ""))
		if not Cards.SILHOUETTES.has(silhouette):
			_fail("card_shape_vocab", "%s의 실루엣 '%s'가 SILHOUETTES(%d종) 밖" % [
				id, silhouette, Cards.SILHOUETTES.size()])
		if not Cards.IMPACTS.has(impact):
			_fail("card_shape_vocab", "%s의 충격 '%s'가 IMPACTS(%d종) 밖" % [
				id, impact, Cards.IMPACTS.size()])
	if Cards.SILHOUETTES.size() != 14:
		_fail("card_shape_vocab", "SILHOUETTES가 %d종 (§4.4 표는 14종)" % Cards.SILHOUETTES.size())
	if Cards.IMPACTS.size() != 8:
		_fail("card_shape_vocab", "IMPACTS가 %d종 (§7.3 표는 8종)" % Cards.IMPACTS.size())
	_metrics["silhouettes"] = Cards.SILHOUETTES.size()
	_metrics["impacts"] = Cards.IMPACTS.size()

	# --- Y3 ③: 실루엣 유일성 계약 (§4.4) ---------------------------------------
	# 같은 속성 안에서 실루엣이 겹치면 두 카드가 **완전히 같은 아이콘**이 된다
	# (실루엣 흰색 단색 × 속성색 틴트가 아이콘의 전부이기 때문이다).
	# 드래프트 28장의 (element, silhouette) 28쌍이 전부 달라야 한다. SPECIALS는
	# 속성당 4장 집계 밖이라 이 계약의 대상이 아니다.
	var pair_seen: Dictionary = {}
	for card: Dictionary in Cards.SKILLS:
		var id := String(card.get("id", "?"))
		var pair := "%s/%s" % [String(card.get("element", "")), String(card.get("silhouette", ""))]
		if pair_seen.has(pair):
			_fail("silhouette_unique", "%s가 %s와 (속성,실루엣) 쌍 '%s'를 공유한다 — 아이콘이 같아진다" % [
				id, pair_seen[pair], pair])
		pair_seen[pair] = id
	if pair_seen.size() != Cards.SKILLS.size():
		_fail("silhouette_unique", "고유 쌍이 %d개 (SKILLS %d장)" % [pair_seen.size(), Cards.SKILLS.size()])
	# 라이브러리의 계약 함수와 이 테스트의 독립 집계가 같은 답을 내야 한다.
	if not Cards.silhouette_pairs_unique():
		_fail("silhouette_unique", "silhouette_pairs_unique()가 false")
	_metrics["silhouette_pairs"] = pair_seen.size()

	# --- Y3 ④: 카드 color가 그 카드 원소의 색인가 (§3.2) -----------------------
	# 스테일 `color` 회귀 방지가 목적이다. v2에서는 이 키가 원소와 무관했다
	# (`thunder` 카드가 청록 67c7d4, `whirlwind` 독 카드가 붉은색 d95763).
	# 그 값이 `_factory_card_color()`를 타고 아이콘·프레임 색 10곳 이상으로 흘러
	# "화·초 색 구별이 안 간다"는 피드백의 진짜 원인이었다. BASIC은 속성이 없어 제외.
	for card: Dictionary in authored:
		var id := String(card.get("id", "?"))
		var element := String(card.get("element", ""))
		var color := String(card.get("color", "")).to_lower().lstrip("#")
		if not ELEMENT_COLOR_HEX.has(element):
			_fail("card_color_matches_element", "%s의 원소 '%s'가 색표에 없다" % [id, element])
			continue
		var expected := String(ELEMENT_COLOR_HEX[element])
		if color != expected:
			_fail("card_color_matches_element", "%s(%s)의 color가 %s — 기대 %s" % [
				id, element, color, expected])
	# 색 7개가 서로 달라야 한다. 두 원소가 같은 색을 받으면 재배색의 목적이 사라진다.
	var color_seen: Dictionary = {}
	for element: String in ELEMENT_COLOR_HEX.keys():
		var hex := String(ELEMENT_COLOR_HEX[element])
		if color_seen.has(hex):
			_fail("card_color_matches_element", "색 %s를 %s와 %s가 공유한다" % [hex, color_seen[hex], element])
		color_seen[hex] = element
	_metrics["element_colors"] = color_seen.size()

	# --- Y3 ⑤: 폐기 어휘가 유저 눈에 보이는 문구에 남아 있지 않다 --------------
	# 검사 대상은 "화면에 그대로 찍히는 문자열" 전부다 — 카드 4줄 × 40장 +
	# 속성 이름 7 + 속성 역할 7. 시스템이 사라졌는데 문구만 남는 회귀를 잡는다.
	var banned_scanned := 0
	for card: Dictionary in authored:
		var id := String(card.get("id", "?"))
		for key: String in ["name", "desc", "combo", "debt_desc"]:
			var text := String(card.get(key, ""))
			banned_scanned += 1
			var hit := _banned_word_in(text)
			if hit != "":
				_fail("no_banned_words", "%s.%s에 폐기 어휘 '%s' — \"%s\"" % [id, key, hit, text])
	for element: String in Cards.ELEMENTS:
		for text in [Cards.element_name(element), Cards.element_role(element)]:
			banned_scanned += 1
			var hit := _banned_word_in(String(text))
			if hit != "":
				_fail("no_banned_words", "%s의 표기 \"%s\"에 폐기 어휘 '%s'" % [element, text, hit])
	# 2026-08-10 용어 개편: 카드 40장만으로는 「각인·레일·RELOAD」의 회귀를 못 막는다.
	# 그 세 낱말이 실제로 살던 곳은 **보석 15종 · 아이템 57종 · 트로피 5종**이다.
	# 스캔 범위를 거기까지 넓혀 둬야 데이터만 되돌려도 테스트가 먼저 운다.
	for rune_id_value in Rune.RUNES.keys():
		var rune_def: Dictionary = Rune.RUNES[rune_id_value]
		for key: String in ["name", "effect"]:
			var text := String(rune_def.get(key, ""))
			banned_scanned += 1
			var hit := _banned_word_in(text)
			if hit != "":
				_fail("no_banned_words", "보석 %s.%s에 폐기 어휘 '%s' — \"%s\"" % [rune_id_value, key, hit, text])
	for item: Dictionary in Items.ITEMS:
		for key: String in ["name", "desc"]:
			var text := String(item.get(key, ""))
			banned_scanned += 1
			var hit := _banned_word_in(text)
			if hit != "":
				_fail("no_banned_words", "아이템 %s.%s에 폐기 어휘 '%s' — \"%s\"" % [item.get("id", "?"), key, hit, text])
	for trophy: Dictionary in Trophies.TROPHIES:
		for key: String in ["name", "desc", "effect_desc"]:
			var text := String(trophy.get(key, ""))
			banned_scanned += 1
			var hit := _banned_word_in(text)
			if hit != "":
				_fail("no_banned_words", "트로피 %s.%s에 폐기 어휘 '%s' — \"%s\"" % [trophy.get("id", "?"), key, hit, text])
	_metrics["banned_scan_strings"] = banned_scanned


# -----------------------------------------------------------------------------
# ② 태그가 전부 유효 집합에 속하는가 (§4.2 · §5.1 · §5.3)
# -----------------------------------------------------------------------------
func _check_tags() -> void:
	_pass("tag_vocabulary")
	_pass("tag_coverage")
	_pass("tag_playable")
	_pass("element_exact")
	_pass("range_coverage")

	# 카드 파일과 각인 엔진이 같은 어휘를 쓰는지부터 확인한다. 여기가 어긋나면
	# 공명·결속·삼각·반응이 조용히 전부 꺼진다(오타 1글자로 시스템이 사라진다).
	if Array(Cards.ELEMENTS) != Array(Rune.ELEMENTS):
		_fail("tag_vocabulary", "ELEMENTS 불일치 카드%s vs 엔진%s" % [Cards.ELEMENTS, Rune.ELEMENTS])
	if Array(Cards.FORMS) != Array(Rune.FORMS):
		_fail("tag_vocabulary", "FORMS 불일치 카드%s vs 엔진%s" % [Cards.FORMS, Rune.FORMS])

	# --- Y3: 속성 재작명 (§3.2) — 한자를 버린 7계 이름 --------------------------
	# `element_name()`은 카드 툴팁·레일 배지·온보딩이 전부 읽는 표기의 단일 지점이다.
	# 한 줄이라도 옛 한자 표기로 되돌아가면 여기서 잡힌다(금지 어휘 검사와 이중 방어).
	for element: String in Cards.ELEMENTS:
		var expected := String(EXPECTED_ELEMENT_NAMES[element])
		var actual := Cards.element_name(element)
		if actual != expected:
			_fail("tag_vocabulary", "element_name(%s)가 '%s' (기대 '%s')" % [element, actual, expected])
		# 역할 한 줄도 비어 있으면 안 된다 — 온보딩이 이 줄로 속성을 가르친다.
		if Cards.element_role(element).is_empty():
			_fail("tag_vocabulary", "element_role(%s)가 비었다" % element)

	var element_counts: Dictionary = {}
	var form_counts: Dictionary = {}
	for element: String in Cards.ELEMENTS:
		element_counts[element] = 0
	for form: String in Cards.FORMS:
		form_counts[form] = 0

	for card: Dictionary in Cards.all_with_specials():
		var id := String(card.get("id", "?"))
		var element := String(card.get("element", ""))
		var form := String(card.get("form", ""))
		if not Cards.ELEMENTS.has(element):
			_fail("tag_coverage", "%s의 원소 '%s'가 유효 집합 밖" % [id, element])
			continue
		if not Cards.FORMS.has(form):
			_fail("tag_coverage", "%s의 형태 '%s'가 유효 집합 밖" % [id, form])
			continue
		if not bool(card.get("legacy", false)) and not bool(card.get("special", false)):
			element_counts[element] = int(element_counts[element]) + 1
			form_counts[form] = int(form_counts[form]) + 1

	# BASIC은 태그가 비어 있어야 한다. 빈 칸이 원소를 가지면 카드 0장짜리 1일차 레일이
	# 공짜로 5칸 결속 + 삼각 배열을 얻는다(RuneEngine.BASIC_CARD도 같은 이유로 비어 있다).
	if String(Cards.BASIC.get("element", "x")) != "" or String(Cards.BASIC.get("form", "x")) != "":
		_fail("tag_coverage", "BASIC에 태그가 붙어 있다 — 빈 칸이 결속/삼각을 공짜로 얻는다")

	# 드래프트 풀만으로 §3.8의 세 규칙이 전부 성립 가능해야 한다.
	#   결속(같은 원소 3칸 연속) → 원소마다 3장 이상
	#   삼각 배열(1·3·5칸 같은 형태) → 형태마다 **5장 이상** (v2는 3이었다. v3에서 올렸다 —
	#     §5.1이 "형태당 ≥5"를 완료 기준으로 못박았다.)
	for element: String in Cards.ELEMENTS:
		if int(element_counts[element]) < 3:
			_fail("tag_playable", "원소 %s가 %d장뿐 — 3칸 결속을 만들 수 없다" % [element, int(element_counts[element])])
	for form: String in Cards.FORMS:
		if int(form_counts[form]) < 5:
			_fail("tag_playable", "형태 %s가 %d장뿐 — 형태당 ≥5 미달" % [form, int(form_counts[form])])

	# 라이브러리의 집계 함수와 이 테스트의 독립 집계가 같은 값을 내야 한다.
	# (두 곳이 어긋나면 라이브러리를 믿는 UI와 테스트가 다른 세계를 보게 된다.)
	var lib_elements: Dictionary = Cards.element_counts()
	var lib_forms: Dictionary = Cards.form_counts()
	for element: String in Cards.ELEMENTS:
		if int(lib_elements.get(element, -1)) != int(element_counts[element]):
			_fail("tag_coverage", "element_counts()가 %s에서 어긋난다 (%d vs %d)" % [
				element, int(lib_elements.get(element, -1)), int(element_counts[element])])
	for form: String in Cards.FORMS:
		if int(lib_forms.get(form, -1)) != int(form_counts[form]):
			_fail("tag_coverage", "form_counts()가 %s에서 어긋난다" % form)

	# --- v3 ①: 원소당 **정확히** 4장 (28 = 7 × 4) ------------------------------
	# 아이콘 아틀라스가 7행 × 4열이다. 한 원소가 5장이 되는 순간 아틀라스가 깨진다.
	for element: String in Cards.ELEMENTS:
		if int(element_counts[element]) != Cards.CARDS_PER_ELEMENT:
			_fail("element_exact", "원소 %s가 %d장 (기대 정확히 %d장)" % [
				element, int(element_counts[element]), Cards.CARDS_PER_ELEMENT])

	# --- v3 ②: 원소당 근접 ≥1 · 원거리 ≥1 --------------------------------------
	# "근접 + 원거리 혼합 단일 스킬 풀"(부록 A-1 ⑥)이 **원소를 골라도** 성립해야 한다.
	# 한 원소만 골라 5칸을 채운 플레이어가 원거리 수단을 못 갖는 일이 없어야 한다.
	var profile: Dictionary = Cards.element_range_profile()
	for element: String in Cards.ELEMENTS:
		var bucket: Dictionary = profile[element]
		if int(bucket["melee"]) < 1:
			_fail("range_coverage", "원소 %s에 근접 카드(range < %.0f)가 없다" % [element, Cards.MELEE_RANGE_MAX])
		if int(bucket["ranged"]) < 1:
			_fail("range_coverage", "원소 %s에 원거리 카드(range ≥ %.0f)가 없다" % [element, Cards.RANGED_RANGE_MIN])
		_metrics["rc_%s_melee" % element] = int(bucket["melee"])
		_metrics["rc_%s_ranged" % element] = int(bucket["ranged"])

	for element: String in Cards.ELEMENTS:
		_metrics["el_" + element] = int(element_counts[element])
	for form: String in Cards.FORMS:
		_metrics["fm_" + form] = int(form_counts[form])


# -----------------------------------------------------------------------------
# ②-b 각인 카탈로그 15종 (§2.1 칸 10 + §2.2 레일 5) — Y2 신설
# -----------------------------------------------------------------------------
# 24종 → 15종 전면 교체가 실제로 끝났는지, 그리고 **과열이 정말 죽었는지**를 본다.
# 각인은 세공사 가격표(§2.6)·글리프 시트 15칸(§2.5)·저장 schema 4가 전부 물고 있어서
# 개수 하나만 어긋나도 세 곳이 조용히 어긋난다.
func _check_runes() -> void:
	_pass("rune_catalog_15")
	_pass("rune_rarity_split")
	_pass("rune_scope_split")
	_pass("rune_flow_family")
	_pass("rune_no_legacy")
	_pass("rune_exec_cap")

	# --- ① 정확히 15키 · id 집합 일치 -----------------------------------------
	var ids: Array[String] = Rune.all_rune_ids()
	_metrics["runes"] = ids.size()
	if Rune.RUNES.size() != EXPECTED_RUNE_IDS.size():
		_fail("rune_catalog_15", "각인이 %d종 (§2.1+§2.2는 %d종)" % [
			Rune.RUNES.size(), EXPECTED_RUNE_IDS.size()])
	for id: String in EXPECTED_RUNE_IDS:
		if not Rune.RUNES.has(id):
			_fail("rune_catalog_15", "기대 각인 %s가 카탈로그에 없다" % id)
	for id: String in ids:
		if not EXPECTED_RUNE_IDS.has(id):
			_fail("rune_catalog_15", "기대 집합 밖 각인 %s가 카탈로그에 있다" % id)
		# 정의가 자기 키와 같은 id를 들고 있어야 한다(복사·붙여넣기 사고 방지).
		var def: Dictionary = Rune.RUNES[id]
		if String(def.get("id", "")) != id:
			_fail("rune_catalog_15", "각인 키 %s의 정의 id가 '%s'" % [id, def.get("id", "")])
		if String(def.get("name", "")).is_empty():
			_fail("rune_catalog_15", "각인 %s에 이름이 없다" % id)
		if String(def.get("effect", "")).is_empty():
			_fail("rune_catalog_15", "각인 %s에 효과 한 문장이 없다" % id)

	# --- ② 레어리티 분포 일반 6 · 희귀 6 · 영웅 3 ------------------------------
	# 세공사 3택의 기대 가격(45/80/135)이 이 분포 위에 서 있다(§2.6).
	for rarity: String in EXPECTED_RARITY_SPLIT.keys():
		var got: Array[String] = Rune.ids_by_rarity(rarity)
		var expected := int(EXPECTED_RARITY_SPLIT[rarity])
		if got.size() != expected:
			_fail("rune_rarity_split", "%s 각인이 %d종 (기대 %d종)" % [rarity, got.size(), expected])
		_metrics["rune_%s" % rarity] = got.size()
	var rarity_total := 0
	for rarity: String in EXPECTED_RARITY_SPLIT.keys():
		rarity_total += Rune.ids_by_rarity(rarity).size()
	if rarity_total != Rune.RUNES.size():
		_fail("rune_rarity_split", "레어리티 합계 %d ≠ 각인 %d종 — 미지의 레어리티가 있다" % [
			rarity_total, Rune.RUNES.size()])

	# --- ③ scope 분포 slot 10 · rail 5 -----------------------------------------
	# 레일 각인은 칸에 붙지 않는다(attach_rune이 거부한다). scope 키가 빠지면
	# rune_scope()가 "slot"으로 폴백해서 레일 각인이 칸에 붙어 버린다.
	for scope: String in EXPECTED_SCOPE_SPLIT.keys():
		var got: Array[String] = Rune.ids_by_scope(scope)
		var expected := int(EXPECTED_SCOPE_SPLIT[scope])
		if got.size() != expected:
			_fail("rune_scope_split", "scope '%s' 각인이 %d종 (기대 %d종)" % [scope, got.size(), expected])
		_metrics["rune_scope_%s" % scope] = got.size()
	for id: String in ids:
		var def: Dictionary = Rune.RUNES[id]
		if not def.has("scope"):
			_fail("rune_scope_split", "각인 %s에 scope 키가 없다 — rune_scope()가 slot으로 폴백한다" % id)
			continue
		if not EXPECTED_SCOPE_SPLIT.has(String(def["scope"])):
			_fail("rune_scope_split", "각인 %s의 scope '%s'가 slot/rail 밖" % [id, def["scope"]])
	# 레일 각인은 칸에 붙으면 안 된다 — 계약을 실제로 실행해서 확인한다.
	for id: String in Rune.ids_by_scope("rail"):
		var slot: Dictionary = Rune.make_slot({}, [])
		if Rune.attach_rune(slot, {"id": id, "p": 1.0, "mag": 1.0}):
			_fail("rune_scope_split", "레일 각인 %s가 칸에 붙었다 (§2.2 위반)" % id)

	# --- ④ family == "flow"가 정확히 6종 ---------------------------------------
	# §2.6 흐름 할증(×1.25)의 대상 목록과 **같은 집합**이어야 한다. 어긋나면
	# 세공사가 값을 잘못 매기고, 그건 정규 사다리 총액 재측정을 통째로 무효로 만든다.
	var flow: Array[String] = Rune.ids_by_family("flow")
	_metrics["rune_flow"] = flow.size()
	if flow.size() != EXPECTED_FLOW_RUNES.size():
		_fail("rune_flow_family", "flow 각인이 %d종 (§2.6 할증 대상은 %d종)" % [
			flow.size(), EXPECTED_FLOW_RUNES.size()])
	for id: String in EXPECTED_FLOW_RUNES:
		if not flow.has(id):
			_fail("rune_flow_family", "%s가 flow가 아니다 — 흐름 할증 대상에서 빠진다" % id)
	for id: String in flow:
		if not EXPECTED_FLOW_RUNES.has(id):
			_fail("rune_flow_family", "%s가 flow인데 §2.6 할증 대상 목록에 없다" % id)

	# --- ⑤ 폐기 24종이 한 개도 남아 있지 않다 ----------------------------------
	# 옛 id를 여기 하드코딩해 두는 것이 요점이다. RuneEngine을 읽어서 만든 목록으로는
	# "지웠다"를 증명할 수 없다(지운 것은 거기 없으니까).
	var revived := 0
	for id: String in LEGACY_RUNE_IDS:
		if Rune.RUNES.has(id):
			revived += 1
			_fail("rune_no_legacy", "폐기된 각인 %s가 카탈로그에 살아 있다" % id)
		if Rune.rune_scope(id) != "":
			_fail("rune_no_legacy", "폐기된 각인 %s에 scope가 답한다" % id)
		if not Rune.roll_rune(id, RandomNumberGenerator.new()).is_empty():
			_fail("rune_no_legacy", "폐기된 각인 %s를 roll_rune이 굴린다" % id)
	# 옛 id와 새 id가 겹치면 위 검사가 무력해진다(예: haste를 다시 쓰면 조용히 통과).
	for id: String in EXPECTED_RUNE_IDS:
		if LEGACY_RUNE_IDS.has(id):
			_fail("rune_no_legacy", "새 각인 %s가 폐기 목록과 이름이 겹친다" % id)
	_metrics["rune_legacy_checked"] = LEGACY_RUNE_IDS.size()
	_metrics["rune_legacy_revived"] = revived

	# --- ⑥ 종료성 계약 2줄 (§1.2) -----------------------------------------------
	# Y8: 이 묶음의 이름이 `rune_heat_neutral` → **`rune_exec_cap`**으로 바뀌었다.
	# 과열 셔틀 상수 4개(`HEAT_DAMAGE`·`HEAT_RELOAD`·`REENTRY_FALLOFF`·
	# `TRIANGLE_RELOAD_DISCOUNT`)를 재던 네 줄은 삭제했다 — 그 상수들을
	# `rune_engine.gd`에서 **실제로 지웠기 때문이다**(handoff-y2 §7의 삭제 목록).
	# 남은 두 줄이 과열을 대체한 새 규칙이고, 종료성의 전부다.
	if Rune.SLOT_EXEC_CAP != 2:
		_fail("rune_exec_cap", "SLOT_EXEC_CAP이 %d (§1.2는 2)" % Rune.SLOT_EXEC_CAP)
	if Rune.STEP_CAP != 12:
		_fail("rune_exec_cap", "STEP_CAP이 %d (2 × 5칸 + 2 = 12)" % Rune.STEP_CAP)
	# 음성 축 — 셔틀이 되살아나면 이 두 줄이 먼저 빨개진다.
	# `simulate_cycle`의 결과 사전에 과열 키가 다시 생기는 순간 잡힌다.
	var probe_cycle: Dictionary = Rune.simulate_cycle(
		[Rune.make_slot({"damage": 1.0, "reload": 0.2, "duration": 0.5}, [])], 4242)
	for dead_key: String in ["heat_curve", "peak_heat", "end_heat", "carry_heat", "deviation_load"]:
		if probe_cycle.has(dead_key):
			_fail("rune_exec_cap", "사이클 결과에 과열 셔틀 키 %s가 되살아났다" % dead_key)
	var probe_steps: Array = probe_cycle.get("steps", [])
	if not probe_steps.is_empty() and (probe_steps[0] as Dictionary).has("heat"):
		_fail("rune_exec_cap", "스텝 궤적에 과열 셔틀 키 heat가 되살아났다")
	_metrics["slot_exec_cap"] = Rune.SLOT_EXEC_CAP
	_metrics["step_cap"] = Rune.STEP_CAP


# -----------------------------------------------------------------------------
# 랭크 공식 단조성 (§5.2 · §9.3) — 상한 R3에서 포화하는지까지 본다
# -----------------------------------------------------------------------------
func _check_rank_formula() -> void:
	_pass("rank_formula")
	var previous_damage := 0.0
	var previous_duration := 999.0
	var previous_reload := 999.0
	for rank in range(1, Cards.MAX_RANK + 1):
		var f: Dictionary = Cards.rank_formula(rank)
		if float(f["damage_mul"]) <= previous_damage:
			_fail("rank_formula", "R%d 피해 배율이 증가하지 않는다" % rank)
		if float(f["duration_mul"]) > previous_duration:
			_fail("rank_formula", "R%d duration 배율이 감소하지 않는다" % rank)
		if float(f["reload_mul"]) > previous_reload:
			_fail("rank_formula", "R%d reload 배율이 감소하지 않는다" % rank)
		previous_damage = float(f["damage_mul"])
		previous_duration = float(f["duration_mul"])
		previous_reload = float(f["reload_mul"])
	# 상한 초과는 포화한다(R4·R5는 저장 랭크로만 남고 수치는 R3와 같다).
	var capped: Dictionary = Cards.rank_formula(Cards.MAX_RANK + 2)
	var top: Dictionary = Cards.rank_formula(Cards.MAX_RANK)
	if not is_equal_approx(float(capped["damage_mul"]), float(top["damage_mul"])):
		_fail("rank_formula", "MAX_RANK 초과가 포화하지 않는다")
	# §9.3: R3 = 피해 ×2.1
	if not is_equal_approx(float(top["damage_mul"]), 2.1):
		_fail("rank_formula", "R3 피해 배율이 %.3f (설계 2.10)" % float(top["damage_mul"]))
	# ranked()가 표시 랭크는 보존하고 수치만 포화시키는지.
	var r5: Dictionary = Cards.ranked(Cards.instance("cleave", 5))
	var r3: Dictionary = Cards.ranked(Cards.instance("cleave", 3))
	if int(r5.get("rank", 0)) != 5:
		_fail("rank_formula", "ranked()가 저장 랭크 5를 보존하지 않는다")
	if not is_equal_approx(float(r5.get("damage", 0.0)), float(r3.get("damage", 0.0))):
		_fail("rank_formula", "R5 수치가 R3에서 포화하지 않는다")
	_metrics["rank_max"] = Cards.MAX_RANK
	_metrics["rank3_damage_mul"] = float(top["damage_mul"])


# -----------------------------------------------------------------------------
# ③ RELOAD 재기준 검증 (부록 C-6)
# 대표 5칸 덱 5종을 rune_engine.simulate_cycle에 넣어 평균 RELOAD를 실측한다.
# -----------------------------------------------------------------------------
func _card(id: String) -> Dictionary:
	var card: Dictionary = Cards.by_id(id)
	# 엔진이 실제로 읽는 네 키만 넘긴다(handoff-w1 §2의 카드 계약).
	return {
		"id": card.get("id", id),
		"damage": float(card.get("damage", 1.0)),
		"reload": float(card.get("reload", 0.2)),
		"duration": float(card.get("duration", 1.0)),
		"element": String(card.get("element", "")),
		"form": String(card.get("form", ""))
	}


func _deck(ids: Array, rune_plan: Array, rng: RandomNumberGenerator) -> Array:
	# rune_plan[i] = 그 칸에 붙일 **칸 각인** id 배열
	var slots: Array = []
	for index in range(ids.size()):
		var slot: Dictionary = Rune.make_slot(_card(String(ids[index])), [])
		var plan: Array = rune_plan[index] if index < rune_plan.size() else []
		for rune_id in plan:
			var inst: Dictionary = Rune.roll_rune(String(rune_id), rng)
			# ⚠️ 스테일 각인 id를 **조용히 넘기지 않는다.** 이 파일의 rune_plan이 폐기된
			# 옛 24종 id로 가득했던 적이 있는데, roll_rune이 {}를 돌려주고 make_slot이
			# 그걸 그대로 담는 바람에 네 덱이 전부 무각인으로 돌았다. 테스트는 통과했고
			# RELOAD 기준선은 아무것도 재고 있지 않았다. 그 실패 방식을 여기서 막는다.
			if inst.is_empty():
				_fail("reload_baseline", "칸 각인 id '%s'가 카탈로그에 없다 (%d번 칸)" % [rune_id, index])
				continue
			if not Rune.attach_rune(slot, inst):
				_fail("reload_baseline", "각인 '%s'를 %d번 칸에 붙이지 못했다 (스택 상한 또는 scope)" % [rune_id, index])
		slots.append(slot)
	return Rune.make_deck(slots)


## 레일 각인 인스턴스 배열. `simulate_cycle(opts["rail_runes"])`로 들어간다(§2.4).
func _rail(ids: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for rune_id in ids:
		var id := String(rune_id)
		if Rune.rune_scope(id) != "rail":
			_fail("reload_baseline", "'%s'는 레일 각인이 아니다 — rail_runes에 넣을 수 없다" % id)
			continue
		var inst: Dictionary = Rune.roll_rune(id, rng)
		if inst.is_empty():
			_fail("reload_baseline", "레일 각인 id '%s'가 카탈로그에 없다" % id)
			continue
		out.append(inst)
	return out


func _mean_reload(deck: Array, base_seed: int, opts: Dictionary = {}) -> float:
	var total := 0.0
	for i in RELOAD_SAMPLES:
		var cycle: Dictionary = Rune.simulate_cycle(deck, base_seed + i, opts)
		total += float(cycle["reload"])
	return total / float(RELOAD_SAMPLES)


func _check_reload_baseline() -> void:
	_pass("reload_baseline")
	var rng := RandomNumberGenerator.new()
	rng.seed = 771107

	# 대표 덱 5종. 성격은 Y 라운드에서도 그대로 유지하고 **각인만 새 15종으로 갈았다.**
	#   순수(bare) / 조건(mid) / 흐름(rewind) / 템포(tempo) / 중장(heavy)
	# 각인 보유량은 §5.1의 "런당 12~13개"를 5칸에 편 수준을 유지했다.
	# 레일 각인은 rewind·tempo 두 덱이 든다 — `opts["rail_runes"]` 경로가 데이터
	# 테스트에서도 실제로 돌아야 §2.4 신설 배선이 검증된다.
	var decks: Dictionary = {
		# ㉠ 무각인 기준선 — 카드 reload만의 무게. 각인도 레일도 없다
		"bare": {
			"deck": _deck(
				["cleave", "frost_ring", "thunder", "blood_pact", "flame_field"],
				[[], [], [], [], []], rng),
			"opts": {}
		},
		# ㉡ 조건 위주 — 굴리지 않고 조건으로 켜지는 각인 중심(first_hit·twin_cast·finisher).
		#    `kill_chance`를 줘야 finisher(cond "kill")가 실제로 조건을 만난다.
		"mid": {
			"deck": _deck(
				["cleave", "thrust", "thunder", "holy_pulse", "whirlwind"],
				[["first_hit", "strong"], ["twin_cast"], ["strong", "wide"],
				 ["finisher"], ["wide", "first_hit"]], rng),
			"opts": {"kill_chance": 0.25}
		},
		# ㉢ 흐름 위주(옛 "되감기 엔진") — 스텝이 늘어 빚이 가장 크게 붙는 축.
		#    `rewind_1` 되감기의 역할은 §2.3대로 `back_one`이 잇는다.
		#    레일 `rail_loop`가 되돌이 바퀴를 켜서 SLOT_EXEC_CAP 상한까지 밀어붙인다.
		"rewind": {
			"deck": _deck(
				["cleave", "rapid_slash", "time_cut", "blood_pact", "execution"],
				[["back_one", "strong"], ["back_one", "twice"], ["twice"],
				 ["trade_skip"], ["first_hit", "strong"]], rng),
			"opts": {"rail_runes": _rail(["rail_loop"], rng)}
		},
		# ㉣ 템포 위주 — 빚 최소화 축. `quick`이 칸의 쉬는 시간을 지우고 레일
		#    `rail_fast`·`rail_rest`가 바퀴 전체를 줄인다. 삼각 참격 1·3·5는 유지.
		"tempo": {
			"deck": _deck(
				["time_cut", "targeting", "dash_blade", "thrust", "cleave"],
				[["quick", "jump_one"], ["quick"], ["quick", "wide"],
				 ["jump_one"], ["quick"]], rng),
			"opts": {"rail_runes": _rail(["rail_fast", "rail_rest"], rng)}
		},
		# ㉤ 중장 덱 — 카드 reload 상위권만 모은 최악 조건. 각인은 스텝을 늘리지 않는
		#    전투 각인 위주로 얹어 "카드 무게 그 자체"를 재는 성격을 지킨다
		"heavy": {
			"deck": _deck(
				["meteor_blade", "execution", "gravity_well", "earth_splitter", "holy_pulse"],
				[["strong"], ["twice"], ["wide"], ["strong"], ["wide"]], rng),
			"opts": {}
		}
	}

	var sum := 0.0
	var worst := 0.0
	var deck_names: Array = decks.keys()
	deck_names.sort()
	var rail_paths := 0
	for name: String in deck_names:
		var entry: Dictionary = decks[name]
		var opts: Dictionary = entry["opts"]
		if not (opts.get("rail_runes", []) as Array).is_empty():
			rail_paths += 1
		var mean := _mean_reload(entry["deck"], 4100, opts)
		_metrics["reload_" + name] = mean
		sum += mean
		worst = maxf(worst, mean)
		if mean > Rune.RELOAD_CAP:
			_fail("reload_baseline", "%s 덱 평균 RELOAD %.2f초가 상한 %.2f초 초과" % [name, mean, Rune.RELOAD_CAP])
	# 레일 각인 경로가 최소 한 덱에서 실제로 돌았는가(§2.4 신설 배선).
	if rail_paths < 1:
		_fail("reload_baseline", "rail_runes 경로를 도는 덱이 하나도 없다")
	_metrics["reload_rail_decks"] = rail_paths
	var overall := sum / float(deck_names.size())
	_metrics["reload_mean"] = overall
	_metrics["reload_worst"] = worst
	if absf(overall - RELOAD_TARGET) > RELOAD_TOLERANCE:
		_fail("reload_baseline", "대표 덱 평균 RELOAD %.2f초가 목표 %.1f±%.1f초 밖" % [overall, RELOAD_TARGET, RELOAD_TOLERANCE])
	# 무각인 기준선이 상한의 절반을 넘으면 카드 reload 자체가 무겁다는 뜻이다.
	if float(_metrics["reload_bare"]) > RELOAD_BARE_MAX:
		_fail("reload_baseline", "무각인 기준선이 %.2f초 (상한 %.2f초) — 카드 reload가 구조적으로 무겁다" % [
			float(_metrics["reload_bare"]), RELOAD_BARE_MAX])


# -----------------------------------------------------------------------------
# ④ 몬스터 10종 스키마 · 해금 곡선 단조성
# -----------------------------------------------------------------------------
func _check_monsters() -> void:
	_pass("monster_schema")
	_pass("monster_curve")
	_pass("monster_gates")
	_pass("monster_habits")
	_pass("monster_reactions")
	_pass("monster_terrain_weight")

	_metrics["monsters"] = Monsters.MONSTERS.size()
	if Monsters.MONSTERS.size() != 10:
		_fail("monster_schema", "몬스터가 %d종 (기대 10종)" % Monsters.MONSTERS.size())

	var max_slash := 0.0
	var aggro_species := 0
	for monster: Dictionary in Monsters.MONSTERS:
		var id := String(monster.get("id", "?"))
		for key: String in MONSTER_REQUIRED_KEYS:
			if not monster.has(key):
				_fail("monster_schema", "%s에 필수 키 '%s'가 없다" % [id, key])
		var unlock := int(monster.get("unlock", 0))
		if unlock < 1 or unlock > Monsters.MAX_UNLOCK_CYCLE:
			_fail("monster_schema", "%s의 unlock %d가 1~%d 범위 밖" % [id, unlock, Monsters.MAX_UNLOCK_CYCLE])
		if int(monster.get("behavior", 0)) < 1 or int(monster.get("behavior", 0)) > 4:
			_fail("monster_schema", "%s의 behavior가 1~4 밖" % id)
		if float(monster.get("slash_hits", 0.0)) <= 0.0:
			_fail("monster_schema", "%s의 slash_hits가 0 이하" % id)
		if float(monster.get("weight", 0.0)) <= 0.0:
			_fail("monster_schema", "%s의 weight가 0 이하" % id)
		max_slash = maxf(max_slash, float(monster.get("slash_hits", 0.0)))
		if int(monster.get("behavior", 0)) == Monsters.AGGRO_BEHAVIOR:
			aggro_species += 1
	_metrics["max_slash_hits"] = max_slash
	_metrics["aggro_species"] = aggro_species
	# §9.5: 최상위 몹 slash_hits 상한 10.
	if max_slash > 10.0:
		_fail("monster_schema", "최상위 slash_hits %.1f이 §9.5 상한 10을 넘는다" % max_slash)
	# v4-test(early_day_peace)가 요구하는 최소 선공몹 종 수.
	if aggro_species < 3:
		_fail("monster_schema", "선공몹이 %d종뿐 (하네스 요구 3종 이상)" % aggro_species)
	if not Monsters.unlock_table_ok():
		_fail("monster_schema", "unlock_table_ok() 실패 — 해금 표가 7일 곡선 밖")

	# --- Y5 ①: 습성 5종 (§5.2) -------------------------------------------------
	# `behavior`(1~4) 위에 얹는 직교 축이다. 표에만 있고 필드에 안 나오는 습성이
	# 있으면 §5.3 지형 가중치가 죽은 행을 들고 있게 된다.
	var habit_used: Dictionary = {}
	for monster: Dictionary in Monsters.MONSTERS:
		var id := String(monster.get("id", "?"))
		var habit := String(monster.get("habit", ""))
		if not Monsters.HABITS.has(habit):
			_fail("monster_habits", "%s의 습성 '%s'가 HABITS(%d종) 밖" % [id, habit, Monsters.HABITS.size()])
			continue
		# habit_of()의 기본값 폴백에 기대지 않는다 — 키가 실제로 있어야 한다.
		if Monsters.habit_of(monster) != habit:
			_fail("monster_habits", "%s의 habit_of()가 '%s' (데이터는 '%s')" % [
				id, Monsters.habit_of(monster), habit])
		habit_used[habit] = int(habit_used.get(habit, 0)) + 1
	for habit: String in Monsters.HABITS:
		if int(habit_used.get(habit, 0)) < 1:
			_fail("monster_habits", "습성 %s를 쓰는 몹이 하나도 없다" % habit)
		if Monsters.habit_name(habit).is_empty():
			_fail("monster_habits", "습성 %s에 표시명이 없다" % habit)
		# habit_ids()와 독립 집계가 같아야 한다.
		if Monsters.habit_ids(habit).size() != int(habit_used.get(habit, 0)):
			_fail("monster_habits", "habit_ids(%s)가 %d마리 (독립 집계 %d마리)" % [
				habit, Monsters.habit_ids(habit).size(), int(habit_used.get(habit, 0))])
		_metrics["habit_" + habit] = int(habit_used.get(habit, 0))
	if Monsters.HABITS.size() != 5:
		_fail("monster_habits", "HABITS가 %d종 (§5.2 표는 5종)" % Monsters.HABITS.size())
	if not Monsters.habit_table_ok():
		_fail("monster_habits", "habit_table_ok()가 false")

	# --- Y5 ②: 피격 반응 프로필 (§7.2) -----------------------------------------
	# 세 민감도는 `enemy.apply_hit_reaction()`의 resistance에 곱해진다. 0이나 음수면
	# 넉백·경직·둔화가 뒤집히거나 사라진다 — 타격감이 통째로 죽는 종류의 값이다.
	for monster: Dictionary in Monsters.MONSTERS:
		var id := String(monster.get("id", "?"))
		for key: String in Monsters.REACTION_SENS_KEYS:
			if not monster.has(key):
				_fail("monster_reactions", "%s에 %s가 없다" % [id, key])
				continue
			var value := float(monster[key])
			if value <= 0.0:
				_fail("monster_reactions", "%s의 %s가 %.2f — 양수여야 한다" % [id, key, value])
			elif value < Monsters.REACTION_SENS_MIN or value > Monsters.REACTION_SENS_MAX:
				_fail("monster_reactions", "%s의 %s %.2f가 합리 범위 %.1f~%.1f 밖" % [
					id, key, value, Monsters.REACTION_SENS_MIN, Monsters.REACTION_SENS_MAX])
		if String(monster.get("hit_flavor", "")).is_empty():
			_fail("monster_reactions", "%s에 피격 연출 문구가 없다" % id)
		# reaction_profile()이 데이터와 같은 값을 내는지(기본값 폴백에 가려지지 않는지).
		var profile: Dictionary = Monsters.reaction_profile(monster)
		for key: String in Monsters.REACTION_SENS_KEYS:
			if not is_equal_approx(float(profile[key]), float(monster.get(key, -1.0))):
				_fail("monster_reactions", "%s의 reaction_profile()이 %s에서 어긋난다" % [id, key])
	if not Monsters.reaction_table_ok():
		_fail("monster_reactions", "reaction_table_ok()가 false")
	if not is_equal_approx(Monsters.REACTION_SENS_MIN, 0.1) or not is_equal_approx(Monsters.REACTION_SENS_MAX, 3.0):
		_fail("monster_reactions", "민감도 허용 범위가 %.2f~%.2f (§7.2 검토 범위 0.1~3.0)" % [
			Monsters.REACTION_SENS_MIN, Monsters.REACTION_SENS_MAX])

	# --- Y5 ③: 지형 × 습성 스폰 가중 (§5.3) ------------------------------------
	# 가중치가 1.0 이하면 "이 지형에서 더 잘 나온다"가 성립하지 않는다 — 표가 있으나
	# 마나 같은 상태가 된다. 미등록 타일은 반드시 1.0(중립)으로 떨어져야 한다.
	for tile_kind in Monsters.HABIT_TERRAIN_WEIGHT.keys():
		var row: Dictionary = Monsters.HABIT_TERRAIN_WEIGHT[tile_kind]
		if row.is_empty():
			_fail("monster_terrain_weight", "타일 '%s'의 가중 행이 비었다" % tile_kind)
		for habit_key in row.keys():
			var habit := String(habit_key)
			if not Monsters.HABITS.has(habit):
				_fail("monster_terrain_weight", "타일 '%s'가 미지의 습성 '%s'에 가중을 준다" % [tile_kind, habit])
				continue
			var weight := float(row[habit_key])
			if weight <= 1.0:
				_fail("monster_terrain_weight", "타일 '%s'의 %s 가중이 %.2f — 1.0을 넘어야 의미가 있다" % [
					tile_kind, habit, weight])
			# 조회 함수가 표와 같은 값을 내는가.
			if not is_equal_approx(Monsters.habit_terrain_scale(String(tile_kind), habit), weight):
				_fail("monster_terrain_weight", "habit_terrain_scale('%s','%s')가 표와 다르다" % [tile_kind, habit])
	# 미등록 타일·미등록 습성은 중립 1.0이다. 여기가 무너지면 스폰이 조용히 편향된다.
	for probe in ["water", "sand", "", "grass_unknown_variant"]:
		for habit: String in Monsters.HABITS:
			if not is_equal_approx(Monsters.habit_terrain_scale(String(probe), habit), 1.0):
				_fail("monster_terrain_weight", "미등록 타일 '%s'가 %s에 1.0이 아닌 값을 준다" % [probe, habit])
	if not is_equal_approx(Monsters.habit_terrain_scale("grass", "hunt"), 1.0):
		_fail("monster_terrain_weight", "표에 없는 (grass, hunt) 조합이 1.0이 아니다")
	# 타일 이름 두 갈래 흡수(§5.3 주석): shore_* → shore · grass_tuft → tuft.
	if not is_equal_approx(Monsters.habit_terrain_scale("shore_north", "shy"),
			Monsters.habit_terrain_scale("shore", "shy")):
		_fail("monster_terrain_weight", "shore_* 방향 타일이 shore로 접히지 않는다")
	if not is_equal_approx(Monsters.habit_terrain_scale("grass_tuft", "herd"),
			Monsters.habit_terrain_scale("tuft", "herd")):
		_fail("monster_terrain_weight", "grass_tuft가 tuft로 접히지 않는다")
	_metrics["terrain_rows"] = Monsters.HABIT_TERRAIN_WEIGHT.size()

	# 해금 곡선 단조성: 일수가 오를수록 ①등장 가능 종 수 ②최대 slash_hits
	# ③기대 체력이 절대 줄지 않아야 한다.
	var previous_species := 0
	var previous_top := 0.0
	var previous_health := 0.0
	for day in range(1, Monsters.TOTAL_DAYS_REF + 1):
		var rows: Array[Dictionary] = Monsters.spawn_table(day, true)
		if rows.is_empty():
			_fail("monster_curve", "%d일차 밤 스폰 표가 비었다" % day)
			continue
		var top := 0.0
		var weighted := 0.0
		for row: Dictionary in rows:
			var archetype: Dictionary = Monsters.by_id(String(row["id"]))
			var hits := float(archetype.get("slash_hits", 0.0))
			top = maxf(top, hits)
			weighted += hits * float(row["share"])
		var health: float = Monsters.health_for({"slash_hits": weighted}, float(day - 1))
		if rows.size() < previous_species:
			_fail("monster_curve", "%d일차 등장 종 수가 줄었다 (%d < %d)" % [day, rows.size(), previous_species])
		if top < previous_top:
			_fail("monster_curve", "%d일차 최대 slash_hits가 줄었다 (%.1f < %.1f)" % [day, top, previous_top])
		if day > 1 and health <= previous_health:
			_fail("monster_curve", "%d일차 기대 체력이 늘지 않았다 (%.1f <= %.1f)" % [day, health, previous_health])
		previous_species = rows.size()
		previous_top = top
		previous_health = health
		_metrics["hp_d%d" % day] = health
		_metrics["species_d%d" % day] = rows.size()

	# 게이트: 1일차 낮은 선공몹 0줄, 1일차 밤은 선공몹 존재, 원거리는 해금일 전 0줄.
	for row: Dictionary in Monsters.spawn_table(1, false):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			_fail("monster_gates", "1일차 낮 스폰 표에 선공몹 %s이 있다" % row["id"])
	var night_aggro := 0
	for row: Dictionary in Monsters.spawn_table(1, true):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			night_aggro += 1
	if night_aggro <= 0:
		_fail("monster_gates", "1일차 밤에 선공몹이 하나도 없다")
	if not Monsters.ranged_table_ok():
		_fail("monster_gates", "ranged_table_ok() 실패 — 원거리 몹이 해금 하한보다 이르다")
	if Monsters.ranged_gate_ok(1):
		_fail("monster_gates", "1일차에 원거리 게이트가 열려 있다")
	for day in range(1, Monsters.ranged_unlock_cycle()):
		for row: Dictionary in Monsters.spawn_table(day, true):
			if bool(row.get("ranged", false)):
				_fail("monster_gates", "%d일차에 원거리 몹 %s이 등장한다" % [day, row["id"]])
	# 낮 선공몹은 해금일부터 등장하고 비중이 커져야 한다(v4-test와 같은 규칙).
	var unlock_share := 0.0
	var later_share := 0.0
	for row: Dictionary in Monsters.spawn_table(Monsters.AGGRO_DAY_UNLOCK_CYCLE, false):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			unlock_share += float(row["share"])
	for row: Dictionary in Monsters.spawn_table(Monsters.AGGRO_DAY_UNLOCK_CYCLE + 2, false):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			later_share += float(row["share"])
	if unlock_share <= 0.0:
		_fail("monster_gates", "해금일 낮에 선공몹 비중이 0")
	if later_share <= unlock_share:
		_fail("monster_gates", "선공몹 비중이 램프업하지 않는다 (%.3f -> %.3f)" % [unlock_share, later_share])
	_metrics["aggro_unlock_day"] = Monsters.AGGRO_DAY_UNLOCK_CYCLE
	_metrics["ranged_unlock_day"] = Monsters.ranged_unlock_cycle()
	_metrics["aggro_share_unlock"] = unlock_share
	_metrics["aggro_share_later"] = later_share


# -----------------------------------------------------------------------------
# ⑤ v3 몹 스테이지 티어 (설계 §6.3)
# -----------------------------------------------------------------------------
# v2의 일수 게이팅(`unlock`)은 **건드리지 않았다.** 아래는 스테이지 축의 가산분이고,
# 두 축이 동시에 유효해야 V4/V5가 안전하게 갈아끼울 수 있다.
func _check_monster_stages() -> void:
	_pass("monster_stages")
	_pass("aggro_gate_stage3")

	# --- Y5: 1·2스테이지 낮 선공 0 (§5.4) --------------------------------------
	# 게이트 하한이 2 → 3으로 올랐다. 진리표를 통째로 박아 둔다 — 한 줄짜리 함수라
	# 되돌리기가 너무 쉽고, 되돌아가면 피드백 ⑥이 조용히 원상복구된다.
	var gate_cases: Array = [
		[1, false, false], [2, false, false], [3, false, true],
		[4, false, true], [5, false, true],
		# 밤은 전 스테이지 통과한다. 1스테이지 밤에도 늑대가 있어야 밤의 의미가 산다.
		[1, true, true], [2, true, true], [3, true, true]
	]
	for entry in gate_cases:
		var case: Array = entry
		var stage := int(case[0])
		var night := bool(case[1])
		var expected := bool(case[2])
		if Monsters.stage_aggro_gate_ok(stage, night) != expected:
			_fail("aggro_gate_stage3", "stage_aggro_gate_ok(%d, %s)가 %s (기대 %s)" % [
				stage, night, not expected, expected])
	# 진리표만으로는 부족하다 — 실제 스폰 표에 behavior 4가 한 마리도 없어야 한다.
	for stage in [1, 2]:
		for row: Dictionary in Monsters.stage_spawn_table(stage, false):
			if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
				_fail("aggro_gate_stage3", "%d스테이지 낮 스폰 표에 선공몹 %s이 있다" % [stage, row["id"]])
	# 3스테이지 낮에는 반대로 **있어야** 한다. 없으면 게이트가 아니라 봉인이다.
	var day3_aggro := 0
	for row: Dictionary in Monsters.stage_spawn_table(3, false):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			day3_aggro += 1
	if day3_aggro <= 0:
		_fail("aggro_gate_stage3", "3스테이지 낮에 선공몹이 하나도 없다 — 게이트가 열리지 않았다")
	_metrics["stage3_day_aggro"] = day3_aggro
	if Monsters.HABIT_HUNT_DAY_STAGE != 3:
		_fail("aggro_gate_stage3", "HABIT_HUNT_DAY_STAGE가 %d (§5.2 사냥꾼은 3스테이지 낮부터)" % Monsters.HABIT_HUNT_DAY_STAGE)

	if not Monsters.stage_table_ok():
		_fail("monster_stages", "stage_table_ok() 실패 — 스테이지 티어 표가 §6.3 밖")

	# 누적 종 수가 설계 표(4·6·8·9·10)와 정확히 같아야 한다.
	for index in range(Monsters.STAGE_SPECIES_COUNT.size()):
		var stage := index + 1
		var pool: Array = Monsters.stage_pool(stage)
		var expected: int = Monsters.STAGE_SPECIES_COUNT[index]
		if pool.size() != expected:
			_fail("monster_stages", "%d스테이지 몹 풀이 %d종 (설계 %d종)" % [stage, pool.size(), expected])
		_metrics["stage%d_species" % stage] = pool.size()

	# 티어 4계가 전부 존재하고 비어 있지 않다.
	var tier_total := 0
	for tier in range(1, 5):
		var ids: Array[String] = Monsters.tier_ids(tier)
		if ids.is_empty():
			_fail("monster_stages", "티어 T%d에 몬스터가 하나도 없다" % tier)
		tier_total += ids.size()
		_metrics["tier%d_count" % tier] = ids.size()
	if tier_total != Monsters.MONSTERS.size():
		_fail("monster_stages", "티어 합계 %d ≠ 몬스터 %d종" % [tier_total, Monsters.MONSTERS.size()])

	# 스테이지 곡선 단조성: 종 수 · 최대 slash_hits · 기대 체력이 절대 줄지 않는다.
	var previous_species := 0
	var previous_top := 0.0
	var previous_weighted := 0.0
	for stage in range(1, Monsters.STAGE_COUNT_REF + 1):
		var rows: Array[Dictionary] = Monsters.stage_spawn_table(stage, true)
		if rows.is_empty():
			_fail("monster_stages", "%d스테이지 밤 스폰 표가 비었다" % stage)
			continue
		var top := 0.0
		var weighted := 0.0
		for row: Dictionary in rows:
			var archetype: Dictionary = Monsters.by_id(String(row["id"]))
			var hits := float(archetype.get("slash_hits", 0.0))
			top = maxf(top, hits)
			weighted += hits * float(row["share"])
		if rows.size() < previous_species:
			_fail("monster_stages", "%d스테이지 등장 종 수가 줄었다" % stage)
		if top < previous_top:
			_fail("monster_stages", "%d스테이지 최대 slash_hits가 줄었다" % stage)
		if stage > 1 and weighted <= previous_weighted:
			_fail("monster_stages", "%d스테이지 가중 평균 체급이 늘지 않았다 (%.2f <= %.2f)" % [stage, weighted, previous_weighted])
		previous_species = rows.size()
		previous_top = top
		previous_weighted = weighted
		_metrics["stage%d_weighted_hits" % stage] = weighted

	# 게이트: 1스테이지 낮은 선공몹 0줄, 1스테이지 밤은 선공몹 존재.
	for row: Dictionary in Monsters.stage_spawn_table(1, false):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			_fail("monster_stages", "1스테이지 낮 스폰 표에 선공몹 %s이 있다" % row["id"])
	var night_aggro := 0
	for row: Dictionary in Monsters.stage_spawn_table(1, true):
		if int(row["behavior"]) == Monsters.AGGRO_BEHAVIOR:
			night_aggro += 1
	if night_aggro <= 0:
		_fail("monster_stages", "1스테이지 밤에 선공몹이 하나도 없다")
	# 원거리는 RANGED_MIN_STAGE 전에 나오면 안 된다.
	for stage in range(1, Monsters.RANGED_MIN_STAGE):
		for row: Dictionary in Monsters.stage_spawn_table(stage, true):
			if bool(row.get("ranged", false)):
				_fail("monster_stages", "%d스테이지에 원거리 몹 %s이 등장한다" % [stage, row["id"]])

	# roll_for_stage()가 풀 밖 몬스터를 절대 내지 않는다.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809
	for stage in range(1, Monsters.STAGE_COUNT_REF + 1):
		var allowed: Dictionary = {}
		for monster: Dictionary in Monsters.stage_pool(stage):
			allowed[String(monster["id"])] = true
		for _draw in 200:
			var picked: Dictionary = Monsters.roll_for_stage(rng, stage, _draw % 2 == 0)
			if not allowed.has(String(picked.get("id", "?"))):
				_fail("monster_stages", "%d스테이지 roll이 풀 밖 몹 %s를 냈다" % [stage, picked.get("id", "?")])

	# v2 일수 축이 여전히 살아 있어야 한다(V4/V5가 갈아끼우기 전까지 game.gd가 쓴다).
	if not Monsters.unlock_table_ok() or not Monsters.ranged_table_ok():
		_fail("monster_stages", "v2 일수 게이팅이 스테이지 가산으로 깨졌다")


# -----------------------------------------------------------------------------
# ⑥ 보스 트로피 배분 (설계 §5.5)
# -----------------------------------------------------------------------------
func _check_trophies() -> void:
	_pass("trophy_table")

	if not Trophies.table_ok():
		_fail("trophy_table", "table_ok() 실패 — 트로피 배분표가 §5.5 밖")
	_metrics["trophies"] = Trophies.TROPHIES.size()

	# 5회 × 2택1 = 10장 + 예비 2장 = SPECIALS 12종을 **정확히** 소진한다.
	var special_ids: Dictionary = {}
	for card: Dictionary in Cards.SPECIALS:
		special_ids[String(card["id"])] = true
	var referenced: Array[String] = Trophies.all_card_ids()
	if referenced.size() != Cards.SPECIALS.size():
		_fail("trophy_table", "트로피가 참조하는 카드 %d장 ≠ SPECIALS %d종" % [referenced.size(), Cards.SPECIALS.size()])
	for id: String in referenced:
		if not special_ids.has(id):
			_fail("trophy_table", "트로피가 참조하는 %s가 SPECIALS에 없다" % id)
		if Cards.by_id(id).is_empty():
			_fail("trophy_table", "트로피 카드 %s를 by_id가 못 찾는다" % id)
	var used: Dictionary = {}
	for id: String in referenced:
		used[id] = true
	for id in special_ids.keys():
		if not used.has(String(id)):
			_fail("trophy_table", "SPECIALS %s가 배분표 어디에도 없다" % id)
	_metrics["trophy_cards_used"] = Trophies.used_card_ids().size()
	_metrics["trophy_cards_reserve"] = Trophies.RESERVE_CHOICES.size()

	# 스테이지 1~5가 빠짐없이 있고, 2택1 두 장의 **원소가 서로 다르다**.
	# 같으면 선택이 "어느 쪽이 세냐"로 퇴화한다 — 결속·공명 판단이 사라진다.
	for stage in range(1, Trophies.TROPHY_COUNT + 1):
		var trophy: Dictionary = Trophies.for_stage(stage)
		if trophy.is_empty():
			_fail("trophy_table", "%d스테이지 트로피가 없다" % stage)
			continue
		var choices: Array[String] = Trophies.choices_for(stage)
		if choices.size() != Trophies.CHOICES_PER_TROPHY:
			_fail("trophy_table", "%d스테이지 선택지가 %d장" % [stage, choices.size()])
			continue
		var first := String(Cards.by_id(choices[0]).get("element", ""))
		var second := String(Cards.by_id(choices[1]).get("element", ""))
		if first == "" or second == "":
			_fail("trophy_table", "%d스테이지 선택지에 원소가 없다" % stage)
		if first == second:
			_fail("trophy_table", "%d스테이지 2택1이 같은 원소(%s)다" % [stage, first])
		# 고정 스탯 보너스는 비어 있으면 안 되고, 키가 전부 _apply_class_effect 어휘여야 한다.
		var effect: Dictionary = Trophies.effect_for(stage)
		if effect.is_empty():
			_fail("trophy_table", "%d스테이지에 고정 스탯 보너스가 없다" % stage)
		for key_value in effect.keys():
			if not CLASS_EFFECT_KEYS.has(String(key_value)):
				_fail("trophy_table", "%d스테이지 effect에 미지의 키 '%s' — player._apply_class_effect가 조용히 무시한다" % [stage, key_value])

	# 누적 병합이 단조롭게 커지는지(5스테이지 전부 받은 상태가 1스테이지보다 세다).
	var one: Dictionary = Trophies.merge_effects([1])
	var all_five: Dictionary = Trophies.merge_effects([1, 2, 3, 4, 5])
	if float(all_five.get("health", 0.0)) <= float(one.get("health", 0.0)):
		_fail("trophy_table", "트로피 누적이 체력을 늘리지 않는다")
	if float(all_five.get("damage_mul", 1.0)) < 1.0:
		_fail("trophy_table", "damage_mul 병합이 1.0 아래로 떨어졌다 (곱연산 키를 더했다는 뜻)")
	_metrics["trophy_sum_health"] = float(all_five.get("health", 0.0))
	_metrics["trophy_sum_damage_mul"] = float(all_five.get("damage_mul", 1.0))


# -----------------------------------------------------------------------------
# ⑦ 보스 3종 패턴 (설계 §3.1 · §3.3 · §3.4)
# -----------------------------------------------------------------------------
func _check_bosses() -> void:
	_pass("boss_table")

	if not Bosses.table_ok(Cards.ELEMENTS, Cards.FORMS, STATUS_IDS):
		_fail("boss_table", "table_ok() 실패 — 보스 패턴 표가 §3.3 밖")
	_metrics["boss_designs"] = Bosses.designs().size()

	var pattern_total := 0
	for design: String in Bosses.designs():
		var raw: Array = Bosses.patterns_raw(design)
		pattern_total += raw.size()
		if raw.size() != Bosses.ENHANCED_PATTERN_COUNT:
			_fail("boss_table", "보스 %s의 패턴이 %d개 (기대 %d개)" % [design, raw.size(), Bosses.ENHANCED_PATTERN_COUNT])
		# 패턴 id 중복 없음 + 카드 id와도 충돌하지 않는다(같은 스키마를 쓰므로 섞이면 위험하다).
		for entry in raw:
			var pattern: Dictionary = entry
			if not Cards.by_id(String(pattern["id"])).is_empty():
				_fail("boss_table", "보스 패턴 id %s가 카드 id와 충돌한다" % pattern["id"])

		# --- 기본형: 3칸 / 앞 3패턴 -------------------------------------------
		var base: Array = Bosses.patterns(design, false)
		if base.size() != Bosses.BASE_PATTERN_COUNT:
			_fail("boss_table", "보스 %s 기본형이 %d칸 (기대 %d칸)" % [design, base.size(), Bosses.BASE_PATTERN_COUNT])
		# --- 강화형: 4칸 / telegraph ×0.85 / 보조 상태 1종 추가 ----------------
		var plus: Array = Bosses.patterns(design, true)
		if plus.size() != Bosses.ENHANCED_PATTERN_COUNT:
			_fail("boss_table", "보스 %s 강화형이 %d칸 (기대 %d칸)" % [design, plus.size(), Bosses.ENHANCED_PATTERN_COUNT])
		for index in range(base.size()):
			var b: Dictionary = base[index]
			var p: Dictionary = plus[index]
			var expected := float(b["telegraph"]) * GameTuning.STAGE_BOSS_TELEGRAPH_MUL_ENHANCED
			if absf(float(p["telegraph"]) - expected) > 1e-6:
				_fail("boss_table", "%s 강화형 %d번 telegraph %.3f (기대 %.3f)" % [design, index, float(p["telegraph"]), expected])
			if float(p["telegraph"]) >= float(b["telegraph"]):
				_fail("boss_table", "%s 강화형 telegraph가 줄지 않았다" % design)
		var secondary := Bosses.secondary_status(design)
		if secondary == "" or not STATUS_IDS.has(secondary):
			_fail("boss_table", "보스 %s의 보조 상태 '%s'가 유효하지 않다" % [design, secondary])

		# 강림(§6.6)은 칸을 하나 더 준다 — A도 4칸이 되어야 한다. A의 4번 패턴이
		# 없으면 강림한 A가 빈 칸을 실행한다.
		var descended: Array = Bosses.patterns(design, false, true)
		if descended.size() != Bosses.BASE_PATTERN_COUNT + GameTuning.STAGE_DESCENT_SLOT_BONUS:
			_fail("boss_table", "보스 %s 강림형이 %d칸 (기대 %d칸)" % [
				design, descended.size(), Bosses.BASE_PATTERN_COUNT + GameTuning.STAGE_DESCENT_SLOT_BONUS])
	_metrics["boss_patterns"] = pattern_total

	# RELOAD: 기본 0.75 / 강화 0.55. **마왕(0.60)보다 강화형이 더 좁다** — 의도된 순서다.
	if not is_equal_approx(Bosses.reload_scale(false), GameTuning.STAGE_BOSS_RELOAD_MUL):
		_fail("boss_table", "기본형 RELOAD 배율이 GameTuning과 다르다")
	if Bosses.reload_scale(true) >= Bosses.reload_scale(false):
		_fail("boss_table", "강화형 RELOAD 배율이 좁아지지 않았다")
	# 페이즈: 기본 1회 / 강화 2회, 그리고 내림차순.
	if Bosses.phase_thresholds(false).size() != 1 or Bosses.phase_thresholds(true).size() != 2:
		_fail("boss_table", "페이즈 전환 횟수가 §3.2 표와 다르다")
	var phases: Array = Bosses.phase_thresholds(true)
	if float(phases[0]) <= float(phases[1]):
		_fail("boss_table", "강화형 페이즈 임계가 내림차순이 아니다")

	# resolve(): 스테이지 보스는 각인을 갖지 않는다. 이게 마왕과의 유일성 경계다.
	# Y8: 짝이던 `uses_heat` 키는 `boss_library`에서 **삭제**했다(과열 규칙 자체가 없다).
	#     그래서 단언이 "false인가"에서 **"키가 없는가"**로 바뀌었다 — 되살아나면 빨개진다.
	for design: String in Bosses.designs():
		for enhanced in [false, true]:
			var resolved: Dictionary = Bosses.resolve(design, enhanced)
			if bool(resolved["uses_runes"]) or resolved.has("uses_heat"):
				_fail("boss_table", "%s(강화=%s)가 각인/과열 키를 가진다 — 5칸+각인은 마왕만" % [design, enhanced])
			if not bool(resolved["uses_reload"]):
				_fail("boss_table", "%s가 RELOAD를 쓰지 않는다 — 반격 창은 전 보스가 공유한다" % design)
			if int(resolved["slot_count"]) >= 5:
				_fail("boss_table", "%s가 %d칸 — 스테이지 보스는 5칸 미만이어야 한다" % [design, int(resolved["slot_count"])])
			if (resolved["patterns"] as Array).size() != int(resolved["slot_count"]):
				_fail("boss_table", "%s의 패턴 수와 칸 수가 다르다" % design)

	# HP 식(§3.4): dwell과 스테이지 기저에 대해 단조 증가.
	var hp_low := Bosses.hp_for("A", GameTuning.STAGE_HP_BASE[0], 0)
	var hp_dwell := Bosses.hp_for("A", GameTuning.STAGE_HP_BASE[0], 4)
	var hp_stage := Bosses.hp_for("A", GameTuning.STAGE_HP_BASE[4], 0)
	if hp_dwell <= hp_low or hp_stage <= hp_low:
		_fail("boss_table", "보스 HP 식이 dwell/스테이지에 단조 증가하지 않는다")
	# dwell 곡선이 몹(§6.2 H(d))보다 완만해야 한다 — "두 번 벌하지 않는다".
	var mob_curve := 1.0 + GameTuning.DWELL_HP_LINEAR * 4.0 + GameTuning.DWELL_HP_QUAD * 16.0
	if (hp_dwell / hp_low) >= mob_curve:
		_fail("boss_table", "보스 dwell 곡선(×%.3f)이 몹 곡선(×%.3f)보다 가파르다" % [hp_dwell / hp_low, mob_curve])
	_metrics["boss_hp_dwell4_mul"] = hp_dwell / hp_low

	# 리그 5벌: 강화형은 기본형과 같은 셀 크기 + 틴트 또는 등장 연출을 반드시 갖는다.
	for key: String in ["B+", "C+"]:
		var rig: Dictionary = Bosses.rig(key)
		if rig.is_empty():
			_fail("boss_table", "리그 %s가 없다" % key)
			continue
		if String(rig.get("tint", "")) == "" and String(rig.get("intro_anim", "")) == "":
			_fail("boss_table", "강화형 %s가 기본형과 시각적으로 구분되지 않는다" % key)


# -----------------------------------------------------------------------------
# ⑧ id 중복 없음
# -----------------------------------------------------------------------------
# `player._apply_class_effect()`가 실제로 읽는 키 전량. 트로피 효과가 이 밖의 키를
# 쓰면 **조용히 무시된다** — 오타 하나로 보스 보상이 사라지는 종류의 버그다.
const CLASS_EFFECT_KEYS: Array[String] = [
	"damage", "damage_mul", "range", "speed", "health", "pickup", "crit",
	"pierce", "ricochet", "shield", "rollback", "projectile", "orbit",
	"life_on_kill", "interval_mul", "holy_pulse"
]

func _check_unique_ids() -> void:
	_pass("unique_ids")
	var seen: Dictionary = {}
	seen[String(Cards.BASIC["id"])] = true
	for card: Dictionary in Cards.all_with_specials():
		var id := String(card.get("id", ""))
		if id == "":
			_fail("unique_ids", "id가 빈 카드가 있다")
			continue
		if seen.has(id):
			_fail("unique_ids", "카드 id 중복: %s" % id)
		seen[id] = true
	var monster_seen: Dictionary = {}
	for monster: Dictionary in Monsters.MONSTERS:
		var id := String(monster.get("id", ""))
		if monster_seen.has(id):
			_fail("unique_ids", "몬스터 id 중복: %s" % id)
		monster_seen[id] = true
	# 보스 패턴 id도 같은 이름 공간을 쓴다(카드와 같은 스키마이므로).
	for design: String in Bosses.designs():
		for entry in Bosses.patterns_raw(design):
			var pattern: Dictionary = entry
			var pattern_id := String(pattern.get("id", ""))
			if pattern_id == "":
				_fail("unique_ids", "id가 빈 보스 패턴이 있다")
				continue
			if seen.has(pattern_id):
				_fail("unique_ids", "보스 패턴 id가 카드와 중복: %s" % pattern_id)
			seen[pattern_id] = true
	# 트로피 id도 중복이 없어야 한다.
	var trophy_seen: Dictionary = {}
	for trophy: Dictionary in Trophies.TROPHIES:
		var trophy_id := String(trophy.get("id", ""))
		if trophy_id == "" or trophy_seen.has(trophy_id):
			_fail("unique_ids", "트로피 id 중복 또는 빈 값: %s" % trophy_id)
		trophy_seen[trophy_id] = true

	# **v3 세이브·아이콘 호환의 핵심 단언.** §5.2가 "신규 id 0개"를 약속했으므로
	# v2가 알던 id 40종(일반 28 + 특별 12)이 전부 by_id로 살아 있어야 한다.
	# 하나라도 빠지면 아이콘 아틀라스 인덱스와 `GENERATED_SKILL_INDEX`가 어긋난다.
	var draft_ids: Array[String] = Cards.draft_ids()
	for required in PROMOTED_LEGACY_IDS:
		if not draft_ids.has(String(required)):
			_fail("unique_ids", "구 legacy 카드 %s가 드래프트 풀에 없다" % required)
	for required in ["cleave", "rapid_slash", "thrust", "recursion", "dash_blade", "frost_ring",
			"gravity_well", "guardian_blade", "thunder", "time_cut", "targeting",
			"shield_bash", "moon_barrier", "holy_pulse", "whirlwind", "blood_pact",
			"execution", "flame_field", "meteor_blade", "earth_splitter"]:
		if not draft_ids.has(String(required)):
			_fail("unique_ids", "v2 드래프트 카드 %s가 사라졌다 — 신규 id 0개 원칙 위반" % required)
	_metrics["known_ids"] = seen.size()


# -----------------------------------------------------------------------------
func _report() -> void:
	# ⚠️ 신설 판정을 여기 안 넣으면 **검사가 조용히 사라진다** (_report가 이 배열만 본다).
	var order: Array[String] = [
		"card_schema", "draft_pool", "legacy_zero",
		"card_text_limits", "card_shape_vocab", "silhouette_unique",
		"card_color_matches_element", "no_banned_words",
		"tag_vocabulary", "tag_coverage", "tag_playable", "element_exact", "range_coverage",
		"rune_catalog_15", "rune_rarity_split", "rune_scope_split", "rune_flow_family",
		"rune_no_legacy", "rune_exec_cap",
		"rank_formula", "reload_baseline", "monster_schema", "monster_curve",
		"monster_gates", "monster_habits", "monster_reactions", "monster_terrain_weight",
		"monster_stages", "aggro_gate_stage3", "trophy_table", "boss_table", "unique_ids"
	]
	var failed: Array[String] = []
	for name: String in order:
		if not bool(_checks.get(name, false)):
			failed.append(name)

	if not failed.is_empty():
		for reason: String in _failures:
			print("DATA_TEST_DETAIL %s" % reason)
		print("DATA_TEST_FAILED failed=%s" % ",".join(failed))
		quit(1)
		return

	var parts: Array[String] = []
	for name: String in order:
		parts.append("%s=true" % name)
	var metric_keys: Array = _metrics.keys()
	metric_keys.sort()
	for key: String in metric_keys:
		var value: Variant = _metrics[key]
		if value is int:
			parts.append("%s=%d" % [key, int(value)])
		else:
			parts.append("%s=%.4f" % [key, float(value)])
	print("DATA_TEST_COMPLETE %s" % " ".join(parts))
	quit(0)
