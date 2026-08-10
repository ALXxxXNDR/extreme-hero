class_name GameMain
extends Node2D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const ENEMY_BULLET_SCRIPT := preload("res://scripts/enemy_bullet.gd")
const XP_ORB_SCRIPT := preload("res://scripts/xp_orb.gd")
const BURST_SCRIPT := preload("res://scripts/burst_effect.gd")
const ATTACK_EFFECT_SCRIPT := preload("res://scripts/attack_effect.gd")
const WORLD_GRID_SCRIPT := preload("res://scripts/world_grid.gd")
const SOUND_SCRIPT := preload("res://scripts/sound_manager.gd")
const SKILL_ICON_SCRIPT := preload("res://scripts/skill_icon.gd")
## ⚠️ **Y4가 `PORTRAIT_SCRIPT`(`pixel_portrait.gd`)를 삭제했다.** 소비자는 마왕 성장
## 토스트 한 곳뿐이었고 그 자리가 YA의 `portrait-demon-lord-48.png`로 갈렸다.
## 그 파일은 프로젝트에 남은 **마지막 무한 애니메이션**(`sin(elapsed * 8.0)` 상시 점멸)
## 이었으므로 이 삭제로 트윈/무한 루프 잔재가 0이 됐다.
## 원본은 `docs/v1-archive/pixel_portrait_y4.gd.txt`.
const BOSS_TOAST_PORTRAIT := preload("res://art/v2/portrait-demon-lord-48.png")
const SKILL_EFFECT_SCRIPT := preload("res://scripts/skill_effect_controller.gd")
const CASTLE_INTERIOR_SCRIPT := preload("res://scripts/castle_interior.gd")
const FACTORY_SCRIPT := preload("res://scripts/factory_deck.gd")
const CYCLE_CONTROLLER_SCRIPT := preload("res://scripts/deal_cycle_controller.gd")
const GENERATED_UI_ICON_SCRIPT := preload("res://scripts/generated_ui_icon.gd")
const FACTORY_DRAG_BUTTON_SCRIPT := preload("res://scripts/factory_drag_button.gd")
const CHEST_OPEN_EFFECT_SCRIPT := preload("res://scripts/chest_open_effect.gd")
# U1 v3(2026-08-09): 로비 배경이 **AI 생성 야경 → 게임 아틀라스 필드 디오라마**로
# 바뀌었다. 아래 5장이 그 재료다. 전부 필드가 실제로 쓰는 그 파일이라, 로비에서 본
# 잔디·성·보스문·용사가 게임에 들어가면 픽셀 하나까지 같은 것으로 다시 나온다.
# `lobby-minimal-v2.png`는 preload에서 빠졌다(파일은 v1-archive 겸 자료로 남는다).
const LOBBY_TERRAIN_ATLAS := preload("res://art/v2/terrain-atlas-verdant.png")
const LOBBY_CASTLE_SPRITE := preload("res://art/v2/landmark-castle.png")
const LOBBY_BOSS_GATE_SPRITE := preload("res://art/v2/landmark-boss-gate.png")
const LOBBY_TREE_SPRITE := preload("res://art/v2/landmark-tree.png")
const LOBBY_CHEST_SPRITE := preload("res://art/v2/landmark-chest.png")
# V5: 스테이지 그래픽 가중치(설계 §7.3) — **정적 전면 쿼드 2장.** 흐르게 하지 않는다
# (트윈 루프 금지 규칙 인접 판단). 비네트만 LINEAR 필터다(handoff-v3-assets §2 주의사항).
const STAGE_FOG_TEXTURE := preload("res://art/v2/overlay-fog.png")
const STAGE_VIGNETTE_TEXTURE := preload("res://art/v2/overlay-vignette.png")

# 2026-08-07: 온보딩은 AI 생성 그림 4장 대신 UI 프리미티브 정적 도식으로 다시 그렸다.
# art/generated/onboarding/minimal-v2/page-*.png 파일 자체는 남아 있지만 더는 preload 하지 않는다.
const CHARACTER_CARD_TEXTURES := {
	"swordsman":preload("res://art/generated/characters/swordsman-card-minimal-v2.png"),
	"archer":preload("res://art/generated/characters/archer-card-minimal-v2.png"),
	"mage":preload("res://art/generated/characters/mage-card-minimal-v2.png")
}

# 튜닝 상수는 W0에서 core/tuning.gd(class_name GameTuning)로 전량 이관했다.
# 밸런스 숫자를 고칠 일이 있으면 여기가 아니라 scripts/core/tuning.gd를 고친다.
# 아래 UI 디자인 토큰은 W5가 ui/tokens.gd로 가져갈 몫이라 아직 여기 남아 있다.

# -----------------------------------------------------------------------------
# UI 디자인 토큰 (2026-08-04 3차 피드백 ⑰ "전체적인 UI를 세련되게")
# -----------------------------------------------------------------------------
# 픽셀 레트로 정체성은 유지하되 다음 세 가지만 전역 규칙으로 고정한다.
#   ① 테두리 두께: 모달 껍데기 2 / 내부 프레임·칩 1 / 카드·버튼 2 / 포커스 2(흰색)
#   ② 배경 계층: 모달(UI_MODAL_BG) > 내부 프레임(UI_PANEL_BG) > 칩·트랙(UI_CHIP_BG) 3단
#   ③ 테두리 색: 강조색을 테두리에 쓰지 않고 중립 색 2종으로만 두르고,
#      강조는 헤딩 글자색과 3px 액센트 바로만 표현한다(강조색 남용 정리).
const UI_BORDER_MODAL := 2
const UI_BORDER_FRAME := 1
const UI_BORDER_CARD := 2
const UI_BORDER_FOCUS := 2
const UI_MODAL_BG := Color("111826")
const UI_PANEL_BG := Color("0c1320")
const UI_CHIP_BG := Color("0a111c")
const UI_EDGE := Color("48546b")
const UI_EDGE_SOFT := Color("2c3648")
# 타이포 위계. 이 5단 밖의 크기는 쓰지 않는다.
const UI_TITLE_SIZE := 26
const UI_HEADING_SIZE := 17
const UI_BODY_SIZE := 13
const UI_LABEL_SIZE := 12
const UI_CAPTION_SIZE := 11
# 2지선다 카드 한 장의 크기. 표준 카드 블록(190×142) + 오른쪽 정보 열 + 아래 설명이
# 딱 들어가는 높이라 예전(340)처럼 빈 공간이 남지 않는다 (⑳ + ⑰).
# 레벨업 3번째 선택지(v1 "레일 부품 건설")의 v2 대체 보상. W6가 각인 드래프트로 교체한다.
const CHOICE_FORFEIT_GOLD := 45
const CHOICE_CARD_SIZE := Vector2(510.0, 252.0)
const CHOICE_MODAL_RECT := Rect2(45.0, 112.0, 1190.0, 496.0)

var state := "menu"
var gameplay_root: Node2D
var world: WorldGrid
var player: SurvivorPlayer
var boss: DebtEnemy
var canvas_modulate: CanvasModulate
var sound_manager: Node
var ui_layer: CanvasLayer
var ui_root: Control
var hud: Control
var overlay: Control
var boss_toast: Control
var active_banner: Panel

var health_fill: ColorRect
## Y4(피드백 ⑫) — 체력 세그먼트 12칸. 마지막 칸만 부분 폭으로 줄어든다.
var health_segments: Array[ColorRect] = []
var health_text: Label
var class_text: Label
var phase_text: Label
var gold_text: Label
var xp_fill: ColorRect
var cycle_fill: ColorRect
var interaction_text: Label
var boss_panel: Control
var boss_fill: ColorRect
var boss_shield_fill: ColorRect
var boss_text: Label
var skill_effect_controller: SkillEffectController
var castle_interior: CastleInterior
var factory: FactoryDeck
var player_cycle: DealCycleController
# W2: 바늘 궤적 시드의 뿌리. 런마다 한 번 굴리고 세이브에 넣으면 리플레이가 된다(§W2 결정성).
var run_cycle_seed := 0
var boss_factory: FactoryDeck
var boss_cycle: DealCycleController

# -----------------------------------------------------------------------------
# W10 마왕전 — 보스 레일 밴드 / 월식 / 런 기록 (설계 §6.2 · §4.1 · §8.4)
# -----------------------------------------------------------------------------
# 보스전의 문법(§6.2)은 "칸을 되밟으며 몰아치고, 사이클이 끝나면 RELOAD 동안 무방비"다.
# 그 리듬이 **화면에서 읽혀야** 성립하므로 플레이어의 하단 레일과 같은 시각 언어로
# 마왕의 5칸·바늘·RELOAD 창을 상단에 그린다.
# Y2: 과열 8단 사다리(`boss_rail_heat_cells`)는 삭제됐다 — 규칙이 사라졌기 때문이다(§1.4).
# 그 자리를 「이번 바퀴에 밟은 칸 수」 한 줄이 대신한다.
var boss_rail_band: Panel
var boss_rail_slots: Array[Panel] = []
var boss_rail_needle: RailMarker
var boss_rail_head: Label
var boss_rail_meter_text: Label
var boss_rail_state_text: Label
var boss_rail_window_track: ColorRect
var boss_rail_window_fill: ColorRect
var boss_rail_slot_flash: Array[float] = []
var boss_rail_bound_cycle: DealCycleController = null
## 마왕이 RELOAD(무방비 창)에 들어간 횟수 — 결과 화면과 `--boss-test`의 관측점.
var boss_reload_windows := 0
var boss_reload_open := false

# =============================================================================
# V7: 스테이지 보스 3종 (설계 §3 전체 · 부록 B V7)
# =============================================================================
# 마왕과 **부품을 전부 공유하되 세 축이 다르다**(§3.2 표):
#   칸 3(강화 4 · 강림 +1) / 각인 없음 / RELOAD 배율 0.75·0.55(마왕은 0.60)
# 그래서 새 런타임을 만들지 않는다 — `FactoryDeck` + `DealCycleController(is_boss=true)` +
# 마왕 레일 밴드 HUD를 그대로 쓰고, 칸 수와 `reload_scale`만 갈아끼운다.
# 데이터는 전부 `boss_library.gd`(V2)와 `GameTuning` V3-G/V3-H가 소유한다.
var stage_boss: DebtEnemy = null
var stage_boss_factory: FactoryDeck = null
var stage_boss_cycle: DealCycleController = null
## `BossLibrary.resolve()` 결과 + game.gd가 얹은 HP·좌표. 프리뷰·전투·테스트가 같이 읽는다.
var stage_boss_profile: Dictionary = {}
## 이 스테이지 보스를 이미 잡았는가(보스문 재입장 차단 · 저장 키).
var stage_boss_cleared := false
## 강림 밸브(§6.6)로 필드에 내려온 보스인가. true면 프리뷰가 없고 state가 "playing"이다.
var stage_boss_from_valve := false
## 격파 처리가 두 번 돌지 않게 하는 빗장(도트와 직격이 같은 프레임에 죽일 수 있다).
var stage_boss_defeat_handled := false
## 보스방 아레나 중심. 강림이면 강림 지점이 곧 중심이다.
var stage_boss_arena_center := Vector2.ZERO
## 지금 보스 프리뷰가 누구 것인가 — "demon"(마왕) / "stage"(스테이지 보스).
## `_unhandled_input`의 SPACE가 어느 전투를 여는지 이 한 값이 정한다.
var boss_preview_kind := "demon"
## 격파 보상 훅(V7 신설 · **V8이 소비한다**). `_open_stage_trophy_choice()`가 이 사전을
## 읽어 2택1 모달을 띄우고, 카드 배치까지 끝나면 `_finish_stage_trophy()`가 비운다.
##   {"stage":int, "design":"A"/"B"/"C", "enhanced":bool, "descended":bool, "day":int, "dwell":int}
var pending_stage_trophy: Dictionary = {}
## 트로피 배치가 끝난 뒤 실행할 후속 동작. "" = 없음 · "demon" = 마왕전 직행(5스테이지).
## 격파 콜백에서 즉시 `_challenge_demon_king()`을 부르면 트로피 모달이 마왕 프리뷰에
## 덮여 5스테이지 트로피(§5.5의 "5회 지급")를 통째로 잃는다. 그래서 한 칸 미룬다.
var pending_trophy_followup := ""
## 트로피 카드가 `factory_place` 모달에 들어가 있는 동안만 참. `_finish_factory_return()`이
## 이 깃발을 보고 후속 동작을 잇는다(다른 place 흐름과 섞이지 않게 하는 유일한 구분자).
var trophy_place_pending := false
## 이번 런의 성장 천장 자동 전환 횟수(설계 §10 #4 1안). 결과 화면·`--draft-test` 관측점.
var growth_cap_conversions := 0
## 이번 런에서 발동한 **이름 붙은 원소 시너지** 수(대폭 연소·전도·쇄빙 …).
## `spawn_synergy_effect()`가 game.gd의 유일한 관문이라 여기서 한 번만 센다.
var run_synergy_triggers := 0
# ⚠️ V10(2026-08-09): `stage_bosses_defeated`를 **삭제했다**(handoff-v9 §9 #2 · #8).
#    V9가 "결과 화면 지표"로 저장 키까지 만들었지만 **읽는 코드가 한 줄도 없었다** —
#    증가·리셋·저장·복원만 있는 write-only 상태였다. 값은 `clock.stages_cleared`와
#    항상 같고(둘 다 격파 콜백에서 오른다) 결과 화면의 "관문" 칩이 이미 그쪽을 쓴다.
#    같은 사실을 두 변수에 적으면 어긋날 자리만 생긴다. 저장 키도 49 → 48이 됐다.
## 이번 전투에서 실제로 뜬 telegraph 수 / 통과한 페이즈 수. `--boss-test`가 단언한다.
var stage_boss_telegraphs := 0
var stage_boss_phase_shifts := 0
## 보스가 깔아 둔 잔류 장판(독장판 · 기름 · 흑염). 아레나 밖으로 새지 않게 목록으로 든다.
var stage_boss_pools: Array[Node] = []

# =============================================================================
# V7: 플레이어에게 걸리는 상태이상 (설계 §3.3 "상태이상은 나에게도 쌓인다")
# =============================================================================
# `player.gd`는 V7 소유가 아니므로 상태 묶음을 **game.gd가 대신 들고** 있는다.
# 규칙은 전부 `StatusEngine`(V1 확정)이고 여기서는 ①틱 ②이동 배율 ③핍 표기만 한다.
# 이동 배율은 `player.gd`가 이미 매 프레임 묻는 `get_player_speed_multiplier()`로
# 들어가므로 플레이어 파일을 한 줄도 고치지 않는다.
var player_status: Array = StatusEngine.make_state()
## 도트 누적 표시용(HUD). 실제 피해는 `StatusEngine.tick_dot()`이 정한다.
var player_status_dot_total := 0.0

# =============================================================================
# V5: 잠식(蠶食) — 구 월식(月蝕)의 재해석 (설계 §2.4 · §6.3)
# =============================================================================
# v2 월식: "5일차 낮에 켜지고 런이 끝날 때까지 안 꺼진다".
# v3 잠식: "**dwell이 STAGE_BLIGHT_DWELL[stage]에 닿으면 켜지고 스테이지 클리어 시 해제**".
# 스윕 코드(마왕 잔재 모듈 100% + 각인 1개 → 체력·피해·속도 환산)는 v2 그대로 재사용한다.
#
# V7(2026-08-09): V5가 미뤄 둔 `eclipse_* → blight_*` 개명을 **일괄 처리했다.**
#    V5가 이름을 못 지운 이유는 `test_runner.gd::_run_boss_test`가 구 이름을 참조하는데
#    그 테스트가 V7 소유라 고칠 수 없었기 때문이다. 이번 웨이브가 `--boss-test`를
#    전면 재작성하면서 참조 6곳을 함께 갈았다.
# V10(2026-08-09): 마지막으로 남아 있던 `GameTuning.ECLIPSE_*` 상수 6개도 개명했다
#    (`BLIGHT_SWEEP_INTERVAL` / `_HEALTH_MUL` / `_DAMAGE_MUL` / `_SPEED_MUL` 4개로 축소 —
#     트리거 2개는 v3에서 소비자가 0이라 삭제). **구 어휘는 저장 폴백 표에만 남는다.**
const BLIGHT_META := "blight_rune"
var blight_active := false
var blight_marked := 0
var blight_sweep_timer := 0.0

# =============================================================================
# V5: 스테이지 진행 상태 (설계 §2.1 · §2.2 · §6.6)
# =============================================================================
## 이번 스테이지에서 강림 안전 밸브가 당겨졌는가. **상태·경고 UI까지가 V5의 몫**이고
## 실제 스테이지 보스를 필드로 내리는 배선은 V7이다(설계 부록 B V7 ⑧).
var stage_descent_pending := false
## 베이스캠프의 여관 역할 — 스테이지당 완전 회복 1회(§3.6 "추가 1건"). 저장 키 camp_rest_used.
var camp_rest_used := false
## 지금 들어와 있는 정비 공간이 캠프인가(성인가). 같은 castle_interior를 재사용하므로
## 구분은 이 플래그 하나뿐이다 — 사용자 요구 원문이 "성이랑 똑같아"다.
var inside_camp := false
## 스테이지 기저 배율을 이미 받은 마물 수. 결과 화면·테스트 관측점.
var stage_scaled_enemies := 0

# Y2: 런 전체의 **한 바퀴 최다 칸 수**. 결과 화면의 지표가 「최고 과열」에서 이걸로
# 갈렸다(§1.4 — 과열이 사라졌으므로 "얼마나 길게 돌았나"가 그 자리를 산다).
var run_peak_steps := 0
var boss_peak_steps := 0
var peak_bound_cycle: DealCycleController = null

# -----------------------------------------------------------------------------
# X3 필드 HUD — 프레임리스 오버레이 (2026-08-09 사용자 피드백 ⑥ "블록을 제거")
# -----------------------------------------------------------------------------
# W5/V5가 세운 **정보 구조는 그대로**다. 바뀐 것은 껍데기와 자리뿐이다.
#   * 패널 4장(신상 · 스테이지 · 나침반 · 고스트)의 킷 9-slice 판을 전부 걷었다.
#     남은 것은 아이콘 · 얇은 게이지 · 숫자뿐이고 판독성은 `_label()`의 외곽선이 진다.
#   * **나침반 패널은 사라졌다.** 성 · 캠프 · 보스문 · 균열은 화면 가장자리를 도는
#     소형 화살표(`EdgeMarker`)가 말한다 — 대상이 화면 안에 들면 화살표가 숨는다.
#   * 하단 레일 밴드(1048×156)는 **미니 스트립**(380×74)이 됐다. 카드 이름 · 랭크 ·
#     칸 번호 · 태그 문자열은 전부 지우고 아이콘 + 원소색 + 진행만 남겼다.
#   * 지운 문장은 하나도 버리지 않고 **HUD 호버 툴팁**으로 옮겼다(X2 공용 컴포넌트).
# 원본 블록판은 docs/v1-archive/field_hud_v1.gd.txt + docs/handoff-x3.md §2 표에 있다.
var rail_band: Control                     # 하단 미니 스트립(프레임 없음). 필드에서 항상 보인다
var rail_slot_panels: Array[Panel] = []    # 칸 5개. meta: slot_index / rune_count / card_id / active
var rail_needle: RailMarker                # 바늘 — 실행 중인 칸 위 삼각 마커. meta: slot_index
var rail_debt_track: ColorRect
var rail_debt_fill: ColorRect
var rail_flow_banner: Label                # 흐름 델타 1회성 강조 (회귀 / 도약 / 재실행)
var rail_dial: CycleSweepGauge             # 스텝 진행 / RELOAD 잔여 겸용 다이얼
# V5 스테이지 · 체류 압박 줄 (구 7일 기한 패널 · 설계 §6.2 · §10 리스크 #1).
# X3: 판을 걷고 한 줄 텍스트 + 5핍 + 얇은 게이지 두 줄만 남겼다. 잠식/강림 경고는
# **발동했을 때만** 아래 한 줄로 뜬다(평상시 그 자리는 비어 있다).
var vitals_panel: Control
var vitals_pips: Array[ColorRect] = []     # 앞 HUD_PIP_MAX = 보호막(청) · 뒤 HUD_PIP_MAX = 부활(초)
var stage_panel: Control
var stage_warn_on := false                 # 잠식/강림 경고가 지금 떠 있는가(테스트가 읽는다)
var stage_pips: Array[ColorRect] = []
## Y4(피드백 ⑤) — 관문 아이콘 5개 + 해/달 아이콘 하나. 구 5핍 막대의 후임이다.
var stage_gates: Array[StageGateMark] = []
var phase_mark: DayNightMark
var dwell_text: Label
var dwell_track: ColorRect
var dwell_fill: ColorRect
var dwell_blight_mark: ColorRect
# X3: 화면 가장자리 화살표 내비 — 구 나침반 패널의 후신.
var nav_layer: Control
var nav_markers: Dictionary = {}           # key -> EdgeMarker
# V5 스테이지 그레이드 오버레이(전면 정적 쿼드). ui_root의 hud **앞**에 깔린다.
var stage_overlay: Control
var stage_fog_rect: TextureRect
var stage_green_rect: ColorRect
var stage_vignette_rect: TextureRect
# 마왕 고스트 레일 (§6.3). meta: card_id / rune_count
var ghost_panel: Control
var ghost_slot_panels: Array[Panel] = []
# X3: HUD 호버 툴팁(X2가 신설한 UIKit 공용 컴포넌트). 지운 문장이 전부 여기로 왔다.
var hud_tooltip_layer: Control = null
var hud_tooltip_targets: Dictionary = {}   # key -> Control. 캡처가 _force_hud_tooltip(key)로 부른다

# --- 1회성 강조 타이머 --------------------------------------------------------
# 전부 delta로 감쇠하는 float다. Tween 루프 애니메이션은 쓰지 않는다(사용자 요구:
# "온보딩 애니메이션이 싫다" → 위치 점프 + 짧은 강조까지만).
var rail_slot_flash: Array[float] = []
var rail_slot_flash_color: Array[Color] = []
var rail_flow_flash := 0.0
var rail_overload_flash := 0.0
var ghost_slot_flash: Array[float] = []
var ghost_slot_ids: Array[String] = []
var rail_bound_cycle: DealCycleController = null
var rail_pending_flow: Dictionary = {}

var selected_character_id := "swordsman"
var unlocked_character_count := 1
var selected_skills: Array[String] = []
var rejected_skills: Array[String] = []
var boss_items: Array[String] = []
var trophy_reject_skills: Array[Dictionary] = []
var camp_states: Dictionary = {}
# === W9 소유: 균열 진행 상태 =================================================
# 균열의 **위치·클리어 표시**는 world_grid가 소유한다(handoff-w8 §1). game.gd는
# "이 균열의 정예가 몇 마리 남았나"라는 진행 카운터만 따로 든다.
#   rift_states[rift_id] = {"activated":bool, "remaining":int, "cleared":bool}
var rift_states: Dictionary = {}
# === W9 소유: 성 NPC 상태 ====================================================
var pact_uses: Dictionary = {"sell_day":0, "buy_day":0, "mortgage":0}
var rune_shop_purchases := 0
# === X1 소유: 각인 세공사 3택 진열 ============================================
## 지금 진열대에 서 있는 각인 3장. `_roll_rune_draft()` 산출물 + `price`·`rarity` 두 키.
## **저장하지 않는다** — 카드 상점의 `shop_offers`와 같은 "성 방문 스코프" 상태다.
var rune_shop_offers: Array[Dictionary] = []
## 이번 성에서 진열을 몇 번 굴렸나. 새로고침 값이 이 수로 오른다.
var rune_shop_rerolls := 0
## 진열이 깔린 성의 id. 다른 성으로 가면 새로 깐다(리롤 파밍 차단 · 카드 상점과 동일).
var rune_shop_castle_id := ""
## 진열 카드 버튼. `choice_buttons`가 **아니다** — 상점은 단일 포커스 모델을 쓰지 않는다.
var rune_shop_buttons: Array[Button] = []
## Y3(§8 ⑪): 밀정 열람이 **무료·기본 공개**가 되면서 `spy_revealed` 플래그와
## `spy_reveal_cost()`가 함께 사라졌다. 남은 유료 서비스는 「칸 하나 통째로 지우기」
## 하나뿐이고 그것이 **스테이지당 1회**다. 이 값은 마지막으로 쓴 스테이지 번호다(0 = 미사용).
var spy_wipe_stage := 0
# V8: `pending_lineage_branches` / `lineage_buttons` / `lineage_choice_index` **삭제**.
# 계보 3종 택1 화면이 사라졌다(설계 §5.5 · 부록 B V8 ①). 그 자리는 보스 트로피 2택1이다.
var current_pair: Array[Dictionary] = []
var choice_source := "level"
var opened_features: Dictionary = {}
var current_interactable: Dictionary = {}
var choice_selected_index := 0
var choice_last_card_index := 0
var choice_buttons: Array[Button] = []
var current_item_pair: Array[Dictionary] = []
var menu_resume_state := "playing"
var inside_castle := false
var field_return_position := Vector2.ZERO
var current_castle: Dictionary = {}
var item_return_state := "playing"
## 트로피 2택1이 끝나고 돌아갈 상태. v2 각성이 쓰던 이름을 그대로 쓴다.
var advancement_return_state := "playing"
var factory_return_state := "playing"
var factory_mode := "edit"
var pending_factory_card: Dictionary = {}
var pending_factory_upgrade := ""
var factory_upgrade_refund := 0
var factory_lane_buttons: Array[Button] = []
var factory_lane_coordinates: Array[Vector2i] = []
var factory_inventory_buttons: Array[Button] = []
var factory_inventory_indices: Array[int] = []
var factory_focus_zone := "rail"
var factory_focus_index := 0
var factory_selected_inventory := -1
var factory_rail_scroll: ScrollContainer = null

# --- W6 → X2: ESC 편집 화면 (부록 C-1의 두 조작 · 미리보기) -------------------
# factory_edit_mode 는 "지금 집은 것을 어떻게 옮기는가"의 단일 진실 원천이다.
#   "card" = [카드 이동/교체] — 각인은 칸에 남는다  (factory.move_card)
#   "slot" = [칸 위치 교환]   — 각인이 함께 따라간다 (factory.swap_slots)
# **X2에서 이것은 더 이상 화면 모드가 아니다.** 모드 바·M 키·모드별 프레임 뒤집기가
# 전부 사라졌고, 제스처는 **무엇을 집었는가**가 정한다(카드 그림 = card / 칸 손잡이 =
# slot). 이 변수는 키보드 집기가 어느 쪽이었는지만 기억한다(SPACE = card /
# SHIFT+SPACE = slot). 드래그 경로는 페이로드의 `gesture`를 그대로 쓰므로 무관하다.
var factory_edit_mode := "card"
var factory_pick_slot := -1                       # 키보드 2단계 조작의 1단계(집은 칸)
var factory_equipment_buttons: Array[Button] = []
var factory_rune_focus_slot := 0                  # 각인 툴팁이 따라가는 칸
# X2 — 호버 툴팁(ui_kit §6). 층은 편집 화면을 열 때 만들고 닫을 때 오버레이와 함께 죽는다.
var factory_tooltip_layer: Control = null
# 키 → 툴팁 대상 Control. 캡처가 `_force_factory_tooltip("slot2_handle")`로 부른다.
var factory_tooltip_targets: Dictionary = {}
var factory_editor_open := false                  # 등장 연출을 처음 열 때만 주기 위한 플래그
# --- Y3: 모달 공용 호버 툴팁 층 --------------------------------------------
# X2가 편집 화면에만 깔았던 층(`factory_tooltip_layer`)의 **모달 판**이다.
# 각인 부착 2단계가 칸당 8줄을 0줄로 내리려면(§8 ②) 그 8줄이 갈 곳이 필요하고,
# 편집 층은 편집 화면 수명에 묶여 있어 다른 모달에서 쓸 수 없다.
# 층은 `_clear_overlay()`가 오버레이와 함께 죽인다 — 별도 정리 코드가 없다.
var modal_tooltip_layer: Control = null
## 키 → 툴팁 대상 Control. 캡처·테스트가 `_force_modal_tooltip("target_slot2")`로 부른다.
var modal_tooltip_targets: Dictionary = {}
var factory_preview: Dictionary = {}              # _factory_preview_summary() 결과 캐시
var factory_preview_ms := 0.0                     # 실측 계산 시간(ms) — 프레임 예산 근거

# --- W6: 각인 드래프트 (설계 §8.3) -------------------------------------------
var draft_return_state := "playing"
var draft_source := "level"
var draft_offers: Array[Dictionary] = []
var draft_selected_rune: Dictionary = {}
var draft_baseline: Dictionary = {}     # 2단계 Δ의 짝비교 기준선(같은 시드·같은 표본 수)
var draft_selected_index := -1
var draft_slot_buttons: Array[Button] = []
var pending_boss_toast_cards: Array[Dictionary] = []
# 표시 중인 토스트가 끝난 뒤 차례로 보여줄 대기열(항목 하나 = 토스트 하나의 카드 목록).
var boss_toast_queue: Array[Array] = []
## V8: 지금 제시 중인 트로피 한 건. v2 `pending_advancement`(계보+tier)의 자리다.
##   {"trophy":Dictionary, "choices":Array[String]}
var pending_trophy: Dictionary = {}
var shop_offers: Array[Dictionary] = []
var shop_refresh_count := 0
var shop_castle_id := ""

# 전투 판정·적 공간 해시·필드 population은 W3에서 core/combat_resolver.gd로 통째 이관했다.
# 적 등록부(active_enemies)·공간 해시(enemy_spatial)·스폰 타이머의 소유자는 이제 이 객체다.
# game.gd에는 다른 스크립트(enemy/player/projectile/cycle_skill_effect)가 부르는
# 공개 API의 얇은 위임 래퍼만 남는다 — 시그니처는 v1과 한 글자도 다르지 않다.
# 전역 클래스명으로만 생성한다(preload 하면 game.gd <-> combat_resolver 순환 참조).
var combat: CombatResolver
var hud_refresh_timer := 0.0
var active_effect_nodes := 0
var xp_fraction := 0.0

var level := 1
var experience := 0
var xp_target := 8
var kills := 0
var gold := 20
var elapsed_time := 0.0

# =============================================================================
# W4: 스테이지 클럭 · 마왕 성장 — 상태의 단일 소유자는 아래 두 객체다
# =============================================================================
# 낮/밤·일수·체류(dwell)는 이제 game.gd의 변수가 아니라 StageClock의 것이다.
# ⚠️ V10(2026-08-09): `DeadlineClock`(v2 이름 호환 껍데기)을 **삭제하고** 여기서
#    `StageClock`을 직접 세운다. 그 껍데기에는 V4 이후 로직이 한 줄도 없었고,
#    삭제 시점을 V10으로 지정해 둔 것도 그 파일 자신의 주석이다.
#    원본 v2 구현은 `docs/v1-archive/deadline_clock_v2.gd.txt`에 있다.
# 아래 세 프로퍼티는 **위임 창구**다. 진짜 값은 clock 안에 있다.
#
# 프로퍼티로 남겨 둔 이유는 하나다: `game.is_night = true` / `game.cycle_number = 5`로
# 몬스터 해금 게이트를 흔드는 기존 쓰기 경로(test_runner.gd의 early_ranged_gate·
# early_day_peace·stress, combat_resolver의 읽기, enemy.gd의 `"cycle_number" in game`)를
# 한 줄도 고치지 않고 살리기 위해서다. 접근자 프로퍼티도 get_property_list()에 나오므로
# `in` 연산자와 스냅샷 직렬화가 v1과 똑같이 동작한다(4.7.1에서 실측 확인).
var clock := StageClock.new()
var demon_lord := DemonLord.new()

## 런 스냅샷 스키마 버전. 이 값보다 낮거나 없는 저장은 읽지 않고 새 런으로 떨어뜨린다.
## v1(=버전 키 없음) · v2(=2)는 **둘 다 폐기**된다. 크래시가 아니라 "새 런"으로 떨어진다.
##
## V9가 2 → 3으로 올린 이유(설계 §9): v3는 **기존 키의 의미가 바뀐다.**
##   `cycle_number`/`day_number`(7일 상한 소멸) · `eclipse_active`(트리거가 일수→dwell) ·
##   `pact_uses`(하루 매매 → 체류 압박 매매) · `player_advancement_*`(계보 폐기).
## 마이그레이션 코드보다 폐기가 안전하고, 플레이테스트 전이라 실사용 세이브가 없다.
## Y6: 3 → **4**(§9.3 · handoff-y1 §9-F · y2 §8-C · y3 §9-C). 신설 키 넷이 한꺼번에
## 올라간다 — `discovered_features`(발견) · `stage_events`(필드 사건) ·
## `consumable_item`(소비 칸) · `run_event_count`(사건 예산). 발견·사건이 없는 옛
## 스냅샷을 그대로 읽으면 **화살표가 하나도 없는 런**이 되살아나므로 폐기가 맞다.
const RUN_SCHEMA_VERSION := 4

## 스냅샷 키 개명 폴백표 — `새 키: [구 키 …]`.
##
## schema 3은 schema < 3을 통째로 버리므로 **이 표는 지금 한 건도 발화하지 않는다.**
## 그래도 남기는 이유는 두 가지다.
##   ① 개명은 v3에서 실제로 일어났고(`eclipse_*` → `blight_*`, `boss_advancement` →
##      `trophy_effects`), 폴백을 지운 사실을 코드가 아니라 표로 남겨야 다음 개명 때
##      "어디에 폴백을 넣어야 하는지"를 다시 찾지 않는다.
##   ② `_snapshot_value()` 한 곳만 지나가므로 지우려면 **이 표만 비우면 된다**
##      (호출부는 한 줄도 안 바뀐다).
##
## ✅ **V10 판정(2026-08-09 · handoff-v9 §9 #4): 남긴다.** 근거 셋.
##   ① 값이 0인 자산이 아니다 — 플레이테스트 뒤 실사용 세이브가 생기면 다음 개명은
##      schema를 올리지 않고 이 표 한 줄로 처리하는 것이 가장 싸다. 그때 표가 없으면
##      "폴백을 어디에 끼우는가"부터 다시 설계해야 한다.
##   ② 죽은 코드가 아니다 — `--save-test`의 `fallback` 묶음이 세 항목이 실제로
##      발화하는지(구 키만 있을 때 읽히는가 · 새 키가 이기는가 · 둘 다 없으면 기본값)
##      매 실행 단위 수준으로 검사한다. 회귀하면 즉시 빨간불이 켜진다.
##   ③ 비용이 사전 3줄 + 조회 1회다. 지워서 얻는 것이 이 세 줄뿐이다.
## ⚠️ 새 개명을 할 때는 반드시 여기에 한 줄을 더하고 `_restore_run_snapshot()`은
##    `_snapshot_value()`로만 읽을 것. `snapshot.get()` 직접 호출은 폴백을 건너뛴다.
## 표에는 **실제로 일어난 개명만** 적는다(가공의 구 키를 넣으면 다음 사람이 없는
## 역사를 찾게 된다). 지금 세 건은 V7·V9의 개명 그대로다.
const SNAPSHOT_LEGACY_KEYS: Dictionary = {
	"blight_active": ["eclipse_active"],    # V7: 월식 → 잠식
	"blight_marked": ["eclipse_marked"],    # V7: 〃
	"trophy_effects": ["boss_advancement"]  # V9: 계보 카드 → 트로피 미선택 카드
}

## 현재 페이즈(낮 또는 밤)가 시작된 뒤 흐른 시간(초).
var phase_elapsed: float:
	get: return clock.phase_elapsed
	set(value): clock.set_phase_elapsed_raw(value)

## v1의 "무한 라운드 번호". v2에서는 의미가 **일수(1~7)** 로 바뀌었다.
## monster_library.gd의 unlock / aggro_gate_ok / ranged_gate_ok가 이 값을 그대로 읽는다.
var cycle_number: int:
	get: return clock.day_number
	set(value): clock.set_day_raw(value)

## `cycle_number`의 v2 이름. 신규 코드는 이쪽을 쓴다(같은 값이다).
var day_number: int:
	get: return clock.day_number
	set(value): clock.set_day_raw(value)

var is_night: bool:
	get: return clock.is_night
	set(value): clock.set_night_raw(value)

## 지금 필드에 떠 있는 전조(前兆) 1기와 그 몹이 시연하는 마왕의 칸.
var active_omen: Node2D = null
var omen_deck: FactoryDeck = null
var omen_cycle: DealCycleController = null
var omen_slot_index := -1
var omen_night_count := 0
## 전조 격파 후 2택1이 열려 있는 동안의 보상 후보. state == "omen_reward"에서만 유효.
var pending_omen_reward: Dictionary = {}
var omen_reward_index := 0
var omen_reward_buttons: Array[Button] = []
var omen_return_state := "playing"

var interaction_timer := 0.0
var collect_sound_counter := 0
var automated_test := false
var onboarding_seen_session := false
var onboarding_page := 0
var onboarding_skip_today := false
# --- U3: 스포트라이트 길잡이 (playing 서브모드 · 파일 끝 U3 절) -------------------
## 길잡이가 도는 중인가. **이 한 값이 서브모드의 전부다** — `state`는 `"playing"` 그대로다.
var guide_active := false
## 지금 스텝(0..GUIDE_STEPS.size()-1).
var guide_step := 0
## ESC를 한 번 눌러 "그만 볼까요?" 확인 칩이 떠 있는가.
var guide_confirm := false
## 이 런에서 실제로 **해내서** 통과한 스텝 id 목록(SPACE로 건너뛴 것은 안 들어간다).
var guide_completed_steps: Array[String] = []
## ① 이동 스텝의 누적 이동 거리. 입력이 들어와 있는 프레임에서만 쌓인다.
var guide_move_distance := 0.0
var guide_last_player_position := Vector2.ZERO
## 저장·설정에 남는 단 하나의 플래그. 설정의 「온보딩 다시 표시」가 이것도 같이 끈다.
var guide_seen := false
var guide_root: GuideLayer = null
var guide_spotlight: Control = null
var guide_caption: Panel = null
var guide_count_label: Label = null
var guide_title_label: Label = null
var guide_body_label: Label = null
var guide_keycap_row: Control = null
var guide_hint_label: Label = null
## X4: 길잡이가 물리 처리를 꺼 둔 노드들(적 · 적 탄환). 종료할 때 **정확히 이 목록만**
## 되돌린다 — 전수 조회로 일괄 복구하면 다른 이유로 꺼져 있던 노드까지 켜 버린다.
var guide_frozen_nodes: Array[Node] = []
## 동결 재적용 주기 카운터. 매 프레임 전수 조회를 하지 않으려고 둔다.
var guide_freeze_timer := 0.0
## 길잡이를 켜면서 걷어낸 잡몹 수. `--guide-test`가 읽는 계측값이다.
var guide_cleared_threats := 0
var lobby_character_index := 0
var saved_run_available := false
## Y6(리스크 5): schema 4로 올라오면서 옛 스냅샷을 버렸는가. 로비가 한 번 읽고 끈다.
var saved_run_dropped := false
var saved_run_playtime := 0.0
## V9: 로비 이어하기 버튼 표기용. 스냅샷 최상위 `stage_index` / `total_days`를 그대로
## 옮겨 담는다 — 로비는 클럭도 월드도 만들지 않으므로 사전만 읽어야 한다.
var saved_run_stage := 0
var saved_run_total_days := 0
var run_save_timer := 0.0
var master_volume_db := -4.0
var effects_volume_db := 0.0
var screen_shake_enabled := true
var damage_numbers_enabled := true
var fullscreen_enabled := false
var transition_active := false
var rng := RandomNumberGenerator.new()

const BOSS_QUIPS: Array[String] = [
	"이걸 준다고?", "둘 다? 용사 맞아?", "무료 배송 감사합니다.",
	"내 공장에 딱 맞는 부품이군.", "그 선택, 환불은 없다.",
	"아, 이 조합은 못 참지.", "내 딜싸이클이 또 예뻐졌군.",
	"계속 고민해. 나는 계속 강해질 테니.", "이런 걸 버리면 내가 줍지.",
	"용사야, 잘 키워 줘서 고맙다."
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	# Y4: 스킬 아이콘 아틀라스는 **구운 시점의 원소색**을 픽셀에 들고 있다. 표를 넘겨
	# 런타임에서 판 색을 다시 맞춘다 — 표 자체는 여전히 `ELEMENT_COLOR` 한 곳뿐이다.
	SKILL_ICON_SCRIPT.set_element_palette(ELEMENT_COLOR)
	# 전투 판정 계층(W3). 씬 트리에 붙이지 않는 순수 객체라 프레임 순서에 끼어들지 않는다.
	combat = CombatResolver.new()
	combat.setup(self)
	# 기한 클럭과 마왕 성장 계층(W4). 둘 다 씬 트리 밖 RefCounted라 프레임 순서에
	# 끼어들지 않는다. 시그널은 런과 무관하게 한 번만 잇는다(연결 중복 방지).
	demon_lord.setup(self)
	# W2: 마왕의 각인 id를 자리표시자에서 실제 각인으로 바꾼다(handoff-w4 §3).
	# Y2: **칸 각인만** 준다. 마왕은 각인을 칸에 붙이므로(`_build_boss_factory`) 레일
	# 각인을 뽑으면 `attach_rune`이 조용히 거부해 그 각인이 증발했다(handoff-y1 §9-B).
	demon_lord.set_rune_catalog(RuneEngine.ids_by_scope("slot"))
	clock.day_started.connect(_on_day_started)
	clock.night_started.connect(_on_night_started)
	# V5: v2의 `milestone_reached` / `descent_triggered` 연결 2줄은 **삭제됐다.**
	# 두 시그널은 v3에서 발화하지 않고(handoff-v4 §1.3) 그 자리를 dwell 사건 2개가 맡는다.
	#   dwell_advanced → 균열 개설 따라잡기 · 잠식 점검 · HUD
	#   stage_started  → 잠식 해제 · 랜드마크 갱신
	# 강림 안전 밸브만은 시그널이 없어 `_process`가 `descent_valve_ready()`를 폴링한다(§6.6).
	clock.dwell_advanced.connect(_on_dwell_advanced)
	clock.stage_started.connect(_on_stage_started)
	_load_progress()
	_ensure_input_actions()
	sound_manager = SOUND_SCRIPT.new()
	add_child(sound_manager)
	_build_ui()
	_show_menu()
	# 자동 테스트·프리뷰·시각 캡처 진입점은 W0에서 scripts/test/test_runner.gd로 전량 이관했다.
	# game.gd는 더 이상 커맨드라인 플래그를 해석하지 않는다. 플래그 목록은 TestRunner.ROUTINES에 있다.
	TestRunner.dispatch(self)

# =============================================================================
# _process — 웨이브별 소유 구역 (W0이 나눠 둠, §7.3)
# =============================================================================
# 각 웨이브는 아래 `=== Wn 소유 ===` 주석 사이의 줄만 고친다. 남의 구역을 고쳐야
# 하면 작업을 멈추고 오케스트레이터에 보고한다. 구역을 옮기거나 새 구역을 만들
# 때도 마찬가지다(프레임 순서가 곧 게임 느낌이라 자유 재배치는 회귀를 만든다).
func _process(delta: float) -> void:
	# === W9 소유: 성 내부 상호작용 폴링 ===
	if state == "castle_interior":
		interaction_timer -= delta
		if interaction_timer <= 0.0:
			interaction_timer = 0.1
			_refresh_castle_interactable()
		return
	if state not in ["playing", "boss"]:
		return
	# === X4 소유: 길잡이 동결 게이트 (사용자 피드백 ② "길잡이 중에 게임이 시작되면 안 돼") ===
	# 길잡이가 도는 동안 **세계의 시간이 멈춘다.** 무엇이 멈추는지는 `world_running`
	# 하나가 정하고, 적·적 탄환의 이동은 노드 단위로 `_guide_freeze_sweep()`이 끈다.
	# 멈추지 않는 것은 셋뿐이다 — ① 플레이어(스텝 ①②가 실제로 걷고 대시해야 한다)
	# ② 딜싸이클(스텝 ③④가 "공격 버튼이 없다"를 눈으로 증명하는 유일한 수단)
	# ③ HUD 갱신. 적이 하나도 없으므로 ②가 돌아도 맞을 위험은 0이다(파일 끝 X4 절).
	# 게이트는 **필드(`playing`)에만** 건다. 길잡이는 `playing` 서브모드라 보스방
	# (`state == "boss"`)에서는 그림도 판정도 이미 꺼져 있는데, 여기까지 얼리면
	# 보스 패턴이 붙인 도트가 안 도는 유령 상태가 만들어진다.
	var world_running := not (guide_active and state == "playing")
	if world_running:
		elapsed_time += delta
	# === Y7 소유: 카메라 오프셋 계측 (§7.4) ===
	# 흔들림은 트윈이 되돌리므로 발화 시점 값만으로는 실제 최고점을 놓칠 수 있다.
	# 매 프레임 O(1)로 읽어 최댓값만 남긴다. `--cycle-test cam_peak ≤ 4.0`.
	_sample_camera_peak()
	# === W12 소유: 자동 저장 틱 ===
	if not automated_test and OS.get_cmdline_user_args().is_empty():
		run_save_timer -= delta
		if run_save_timer <= 0.0:
			run_save_timer = 5.0
			_save_run_snapshot()
	if state == "playing":
		# === V5 소유: 스테이지 클럭 (구 W4 7일 기한 클럭) ===
		# 페이즈 전환·일수·dwell은 클럭이 시그널로 알려 준다. 프레임당 최대 한 번.
		# X4: 길잡이 중에는 **틱을 아예 거른다** — 낮밤도 체류도 길잡이 시간만큼
		# 멈춰 있어야 한다(튜토리얼을 읽었다고 dwell 불이익을 받으면 안 된다).
		if world_running:
			clock.tick(delta)
			# 강림 안전 밸브(§6.6)만은 **시그널이 없다** — 클럭이 판정만 하고 발화하지 않으므로
			# 여기서 폴링한다(handoff-v4 훅 ①). 밟으면 등급 C 고정이다.
			if not stage_descent_pending and clock.descent_valve_ready():
				_trigger_stage_descent()
			# === W3 소유: 필드 population 유지 ===
			combat.tick_population(delta)
		# === W8 소유: 월드 상호작용 대상 갱신 ===
		# X4: 상호작용 갱신은 **길잡이 중에도 돈다** — 스텝 ⑥이 E를 시키기 때문이다.
		# 균열 접근 판정만 쉰다(길잡이 도중에 균열 아레나가 열리면 안 된다).
		interaction_timer -= delta
		if interaction_timer <= 0.0:
			interaction_timer = 0.12
			_refresh_interactable()
			# === Y6 소유: 발견 판정 (§6.1) ===
			# 길잡이 중에도 돈다 — 스텝 ⑥이 "성 쪽으로 걸어가 화살표를 켜 보라"이고,
			# 성은 처음부터 발견 상태라 이 스윕이 없어도 화살표는 뜬다.
			_update_discovery()
			# === W9 소유: 균열 접근 판정 (구 _check_trial_camps 자리) ===
			if world_running:
				_check_rifts()
				# === Y6 소유: 필드 사건 표식 (밤·잠식 조건이 바뀌면 뜨고 진다) ===
				_refresh_event_marks()
		# V6(2026-08-09): V5의 `_sweep_stage_scaling()` 임시 우회로는 **삭제됐다.**
		# 스테이지 기저 배율은 이제 `combat.apply_stage_scaling()`이 스폰 경로에서
		# 딱 한 번 먹인다(설계가 지정한 자리). `grep STAGE_SCALE_META` = 0건.
		# === V5 소유: 잠식 — 새로 나온 마물에게 마왕의 잔재·각인을 붙인다 (구 월식 §4.1) ===
		if world_running and blight_active:
			blight_sweep_timer -= delta
			if blight_sweep_timer <= 0.0:
				blight_sweep_timer = GameTuning.BLIGHT_SWEEP_INTERVAL
				_sweep_blight()
	# === V7 소유: 플레이어 상태이상 틱 (보스 패턴이 붙인 독·연·한·유·전) ===
	# 필드(강림)와 보스방 양쪽에서 돌아야 한다 — `playing`/`boss` 둘 다 여기에 닿는다.
	# X4: 길잡이 중에는 도트도 쉰다("맞을 위험 0"은 무적뿐 아니라 시간 정지로도 건다).
	if world_running:
		_tick_player_status(delta)
	# === W4 소유: 조명 보간 ===
	_update_world_lighting(delta)
	# === V6 소유: 상태이상 반응 예산·킬 체인 깊이를 프레임마다 되감는다 (§4.7 규칙 4) ===
	# 상태가 걸릴 수 있는 상태(playing/boss) 밖에서도 부르는 이유는, 프레임이 끊긴
	# 채로 모달에 들어갔다 나왔을 때 예산이 고갈된 채 남아 있지 않게 하기 위해서다.
	combat.begin_status_frame()
	# === W3 소유: 적 공간해시 재구축 ===
	combat.tick_spatial(delta)
	# === W5 소유: HUD 텍스트 갱신 (10Hz) ===
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		hud_refresh_timer = 0.1
		_update_hud()
	# === W5 소유: 5칸 상시 레일 (매 프레임) ===
	# 바늘 위치·진행 게이지·1회성 강조 감쇠만 만진다. 스타일박스는 값이 실제로
	# 바뀔 때만 새로 만든다. 트윈 루프는 쓰지 않는다(정적 표기 · 위치 점프).
	_update_cycle_rail(delta)
	# === X3 소유: 가장자리 화살표 내비 (매 프레임) ===
	# 10Hz로 돌리면 이동 중에 화살표가 화면 테두리에서 눈에 띄게 끊긴다. 마커 4개의
	# 좌표 변환뿐이라 프레임당 비용이 무시할 수준이고, `_update_hud`가 10Hz로 한 번 더
	# 부르는 것은 거리 문자열까지 확실히 맞추기 위한 이중 갱신이다(멱등).
	_update_edge_nav()
	# === W10 소유: 마왕 레일 밴드 (보스전에서만 보인다 · 같은 규약, 트윈 0) ===
	_update_boss_rail(delta)
	# === Y6 소유: 미끼 인형 · 밤눈 부적 (§6.3) ===
	if world_running:
		_tick_y6(delta)

# =============================================================================
# _unhandled_input — 웨이브별 소유 구역 (W0이 나눠 둠, §7.3)
# =============================================================================
# 상태 문자열별로 갈라지는 구조라 소유 경계도 상태 단위다. 새 상태를 추가하는
# 웨이브는 자기 구역 안에 `if state == "<새 상태>":` 블록을 넣고 반드시 return 한다.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	# === Y6 소유: 소비 아이템 교체 확인 (필드 위 모달 · 새 state 없음) ===
	if not consumable_swap.is_empty():
		if key_event.keycode in [KEY_SPACE, KEY_ENTER]:
			_confirm_consumable_swap()
		elif key_event.keycode == KEY_ESCAPE:
			_cancel_consumable_swap()
		return
	# === W6b 소유: 온보딩 / 캐릭터 선택 / 설정 ===
	if state == "onboarding":
		if key_event.keycode in [KEY_LEFT, KEY_A]:
			_show_onboarding(maxi(0, onboarding_page - 1))
		elif key_event.keycode in [KEY_RIGHT, KEY_D] and onboarding_page < ONBOARDING_PAGE_COUNT - 1:
			_show_onboarding(onboarding_page + 1)
		elif key_event.keycode in [KEY_SPACE, KEY_ENTER]:
			if onboarding_page >= ONBOARDING_PAGE_COUNT - 1:
				_finish_onboarding()
			else:
				_show_onboarding(onboarding_page + 1)
		elif key_event.keycode == KEY_ESCAPE:
			_show_character_select()
		return
	if state == "character_select":
		if key_event.keycode in [KEY_LEFT, KEY_A]:
			_cycle_character(-1)
		elif key_event.keycode in [KEY_RIGHT, KEY_D]:
			_cycle_character(1)
		elif key_event.keycode in [KEY_SPACE, KEY_ENTER] and lobby_character_index == 0:
			_confirm_character_selection("swordsman")
		elif key_event.keycode == KEY_ESCAPE:
			_show_menu()
		return
	if state == "settings":
		if key_event.keycode == KEY_ESCAPE:
			_show_menu()
		return
	# === W4 소유: 전조 격파 보상 2택1 ===
	# 자체 포커스 이동을 쓴다(W6의 _handle_choice_keyboard는 그쪽 소유라 건드리지 않는다).
	if state == "omen_reward":
		if key_event.keycode in [KEY_LEFT, KEY_A]:
			_set_omen_reward_index(omen_reward_index - 1)
		elif key_event.keycode in [KEY_RIGHT, KEY_D]:
			_set_omen_reward_index(omen_reward_index + 1)
		elif key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_resolve_omen_reward(omen_reward_index)
		return
	# V8: `lineage_choice` 분기 **삭제**(계보 3종 택1 폐기 · 설계 §5.5 · 부록 B V8 ①).
	# 보스 트로피 2택1은 바로 아래 `advancement_choice` 한 줄이 그대로 받는다 —
	# 신설 state 0개 · 신설 키보드 경로 0개(단일 포커스 모델 유지).
	# === W6 소유: 선택 모달 / 각인 드래프트 / 편집 화면 키보드 ===
	if state in ["choice", "advancement_choice", "item_choice"]:
		_handle_choice_keyboard(key_event)
		return
	if state in ["rune_draft", "rune_target"]:
		_handle_draft_keyboard(key_event)
		return
	if state in ["factory_menu", "factory_place", "factory_upgrade"]:
		_handle_factory_keyboard(key_event)
		return
	# 마우스 없이도 빠져나올 수 있어야 하는 모달들 (P1-5).
	# === W9 소유: 성 상점 모달 ===
	if state == "camp":
		if key_event.keycode == KEY_ESCAPE:
			_close_base_camp()
		return
	# V8: `evolution`(각성 연출) 분기 **삭제**. 연출 자산(18줄 광선 + 초상)은 버리지 않고
	# 트로피 2택1 모달의 배경으로 이사했다 — 화면이 하나 줄었고 state도 하나 줄었다.
	# === W10 소유: 마왕 프리뷰 / V7 가산: 스테이지 보스 프리뷰 ===
	# 같은 `boss_preview` 상태를 공유하고(설계 §3.5 "새 state 문자열을 만들지 않는다")
	# SPACE가 어느 전투를 여는지는 `boss_preview_kind` 한 값이 정한다.
	if state == "boss_preview":
		if key_event.keycode == KEY_ESCAPE:
			_cancel_boss_preview()
		elif key_event.keycode in [KEY_SPACE, KEY_ENTER]:
			if boss_preview_kind == "stage":
				_begin_stage_boss_battle()
			else:
				_begin_boss_battle()
		return
	# === U3 소유: 스포트라이트 길잡이 (playing 서브모드) ===
	# 모달 상태는 위에서 전부 return 했으므로 여기 닿는 것은 필드뿐이다.
	# `_handle_guide_key`가 true를 주면 키를 먹고, false면 아래 기존 처리로 흘려 보낸다
	# (마지막 스텝의 ESC = 편집 화면 열기 · 상호작용 스텝의 E = 실제 상호작용).
	if guide_active and state == "playing":
		if _handle_guide_key(key_event):
			return
	# === W6 소유: ESC → 5칸 편집 화면 진입 ===
	if key_event.keycode == KEY_ESCAPE:
		if state == "factory_menu":
			_close_factory_menu()
		elif state in ["won", "lost"]:
			_show_menu()
		elif state in ["playing", "boss", "castle_interior"]:
			_show_factory_menu("edit")
		return
	# === W6b 소유: 로비 / W8 소유: 필드 상호작용(E) / W10 소유: 결과 화면 재시작 ===
	if state == "menu" and key_event.keycode in [KEY_SPACE, KEY_ENTER]:
		_show_character_select()
	elif state in ["playing", "castle_interior"] and (event.is_action_pressed("interact") or key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E):
		if state == "castle_interior":
			_refresh_castle_interactable()
		else:
			_refresh_interactable()
		_interact_with_world()
	elif state == "playing" and (key_event.keycode == KEY_Q or key_event.physical_keycode == KEY_Q):
		# === Y6 소유: 소비 슬롯 1칸 (§6.3) ===
		_use_consumable()
	elif state in ["won", "lost"] and key_event.keycode == KEY_R:
		_start_game()
	elif state in ["won", "lost"] and key_event.keycode == KEY_L:
		_show_menu()

func _ensure_input_actions() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SHIFT],
		"interact": [KEY_E]
	}
	for action_name: String in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key_code: int in actions[action_name]:
			var input_event := InputEventKey.new()
			input_event.keycode = key_code
			if not InputMap.action_has_event(action_name, input_event):
				InputMap.action_add_event(action_name, input_event)
			if action_name == "interact":
				var physical_event := InputEventKey.new()
				physical_event.physical_keycode = key_code
				if not InputMap.action_has_event(action_name, physical_event):
					InputMap.action_add_event(action_name, physical_event)

# =============================================================================
# X3 필드 HUD 레이아웃 — 1280×720 절대 좌표 (사용자 피드백 ⑥ · 구 W5 §8.1 대체)
# =============================================================================
# 사용자 원문: "모든 정보들이 **블록으로 나뉘어져** 있어. 블록을 제거하고 다시 디자인해줘.
# … 딜싸이클 범위가 너무 커 … 블록 범위 없애서 **필드가 더 잘 보이게**."
#
# 그래서 이 표의 사각형은 **판이 아니라 자리**다. 여기 적힌 Rect2 중 실제로 불투명한
# 그림이 깔리는 것은 하나도 없다(예외: 보스전 전용 마왕 레일 밴드 · 조건부 상호작용
# 안내). 나머지는 아이콘·게이지·숫자를 어디에 놓을지와 **툴팁 히트박스**를 정한다.
#
#   상단 왼쪽  x  16~272 · y  8~ 64   신상(체력·경험·자금·보호막 핍)
#   상단 가운데 x 440~840 · y  2~ 64   스테이지 한 줄 + 5핍 + 게이지 2줄 (+ 조건부 경고)
#   상단 오른쪽 x1094~1264 · y  8~ 42   마왕 고스트 5칸(아이콘만)
#   보스전만   x 806~1264 · y 10~142   마왕 레일 밴드(W10 소유 · 유일한 상시 판)
#   보스 체력  x 370~ 800 · y 66~106   프레임 없는 이름 줄 + 12px 게이지
#   가장자리   NAV_RING 링 위          성·캠프·보스문·균열 소형 화살표
#   하단 가운데 x 450~830 · y636~710   미니 딜싸이클 스트립
#
# 겹침 증명(보스전 포함):
#   스테이지 줄 오른쪽 끝 840 < 마왕 레일 밴드 왼쪽 806? **아니다** — 그래서
#   실제 그림(텍스트·게이지)은 전부 x ≤ 800 안에 들어가고 840은 툴팁 히트박스의
#   끝이다. 히트박스는 그림이 없으므로 겹쳐도 화면이 더러워지지 않고, 밴드가 뜬
#   동안에는 밴드가 마우스를 안 받으므로(IGNORE) 호버도 안 뺏긴다.
#   보스 체력 줄 아래끝 106 < 배너 위끝 148 ✓ · 고스트 5칸은 보스전에서 숨는다 ✓
# 이 블록만 고치면 _build_ui / _update_hud 의 계산이 전부 따라 움직인다.

# --- ① 좌상단 신상 (프레임리스) ----------------------------------------------
# 판이 사라졌으므로 "패널 안의 층"을 나누던 1px 구분선 두 줄도 같이 사라졌다.
# 남은 것은 ♥ + 체력 바 + 숫자 / 얇은 경험 바 / ◎ + 자금 / 보호막·부활 핍뿐이다.
# ⚠️ `HUD_*_RECT`만 화면 절대 좌표다. 그 아래 자식 상수는 전부 **컨테이너 로컬**이다
#    (컨테이너 = 그림 없는 Control. visible 토글 한 곳과 툴팁 히트박스를 겸한다).
const HUD_VITALS_RECT := Rect2(16.0, 8.0, 256.0, 56.0)
const HUD_HEALTH_TRACK := Rect2(26.0, 4.0, 186.0, 12.0)   # 절대 42,12
const HUD_XP_TRACK := Rect2(26.0, 19.0, 186.0, 4.0)       # 절대 42,27
const HUD_VITALS_HEART := Vector2(0.0, 2.0)
const HUD_VITALS_LEVEL := Rect2(214.0, 1.0, 42.0, 18.0)
const HUD_VITALS_COIN := Vector2(0.0, 32.0)               # Y4: 금화 더미 24×16
const HUD_VITALS_GOLD := Rect2(28.0, 28.0, 62.0, 22.0)
## ⚠️ `_label()`은 `clip_text = true`다. 상자 높이가 글꼴 줄 높이보다 낮으면 말줄임이
## 아니라 **글자가 위아래로 썰린다**(V11이 나침반에서 같은 함정을 밟았다 · 구 §HUD_COMPASS).
## 그래서 이 파일의 라벨 상자는 전부 폰트 크기 + 5px 이상으로 잡혀 있다.
const HUD_HEALTH_TEXT := Rect2(26.0, 1.0, 186.0, 18.0)    # 12px 트랙(4~16) 위에 세로 중앙
## Y4(피드백 ⑫) — 세그먼트 게이지. 12칸 × (13.5 + 2 간격) = 182 = 트랙 안쪽 폭.
## 12를 고른 이유: 8칸은 한 칸이 12.5%라 잔체력 경고가 늦고, 16칸은 한 칸이 9px라
## 1280×720에서 칸 사이 간격이 안 보여 그냥 막대로 돌아간다(실측).
const HUD_HEALTH_SEGMENTS := 12
const HUD_HEALTH_SEG_GAP := 2.0
const HUD_VITALS_PIPS := Vector2(98.0, 36.0)              # 보호막(청)·부활(초) 핍 줄 시작점
const HUD_PIP_SIZE := Vector2(8.0, 8.0)
const HUD_PIP_GAP := 3.0
const HUD_PIP_MAX := 6                                    # 초과분은 툴팁이 정확한 수를 말한다

# --- ② 상단 중앙 스테이지 줄 (프레임리스) ------------------------------------
const HUD_STAGE_RECT := Rect2(440.0, 2.0, 400.0, 62.0)
## ⚠️ Y4가 `HUD_STAGE_TEXT`(17px 한 문장 자리)와 `HUD_STAGE_PIP*`(5핍 막대)를 **삭제했다.**
## 그 두 줄이 「관문 아이콘 5개 + 해/달 아이콘」 한 줄로 합쳐졌다(피드백 ⑤).
## 세로 예산은 그대로다 — 구판도 텍스트 1~24 + 핍 27~31을 썼고, 신판은 3~27 한 줄이다.
const HUD_STAGE_GATE := Vector2(22.0, 24.0)               # 관문 아이콘 한 개
const HUD_STAGE_GATE_GAP := 8.0
const HUD_STAGE_GATE_Y := 3.0                             # 절대 445,5
const HUD_STAGE_PHASE_MARK := Vector2(96.0, 3.0)          # 해/달 — 관문 왼쪽
const HUD_STAGE_TAG := Rect2(276.0, 6.0, 120.0, 18.0)     # 성·캠프·결전에서만 켜지는 꼬리표
const HUD_PHASE_BAR := Rect2(60.0, 34.0, 280.0, 4.0)      # 절대 500,36 — 낮/밤 진행
const HUD_DWELL_BAR := Rect2(60.0, 40.0, 280.0, 4.0)      # 절대 500,42 — 체류 압박 + 잠식 임계선
const HUD_DWELL_TEXT := Rect2(40.0, 45.0, 320.0, 17.0)    # 절대 480,47 — "체류 2" / 발동 시 경고문

# --- ③ 우상단 마왕 고스트 (프레임리스 · 아이콘 5개만) ------------------------
const HUD_GHOST_RECT := Rect2(1094.0, 8.0, 170.0, 34.0)  # 5×30 + 4×5 = 170 ⊂ 170 (우여백 16)
const HUD_GHOST_SLOT := Vector2(30.0, 30.0)
const HUD_GHOST_ORIGIN := Vector2(0.0, 2.0)              # ghost_panel 로컬
const HUD_GHOST_PITCH := 35.0

# --- ④ 보스 체력 (프레임리스 · 보스전에서만 보인다) --------------------------
# V11이 폭 444로 좁혀 마왕 레일 밴드를 피했던 자리다. 판이 사라졌으므로 밴드와의
# 충돌 조건은 "그림이 x 800을 안 넘는가" 하나로 줄었다.
const HUD_BOSS_PANEL := Rect2(370.0, 66.0, 430.0, 40.0)
const HUD_BOSS_BAR := Rect2(0.0, 24.0, 430.0, 12.0)      # boss_panel 로컬
const HUD_INTERACT_RECT := Rect2(340.0, 470.0, 600.0, 30.0)
const HUD_FLOW_BANNER := Rect2(340.0, 606.0, 600.0, 22.0)

# --- ⑤ 화면 가장자리 화살표 내비 (구 나침반 패널) ----------------------------
# 마커는 링 위의 한 점에 **중심**이 놓인다. 링을 화면 안쪽으로 충분히 들여야
# 52×26 마커가 화면 밖으로 새지 않는다 — x 18~1262 · y 79~625가 실제 점유다.
# 위쪽 92는 상단 HUD 아래끝(64)보다 낮고, 아래쪽 612는 미니 스트립 위끝(636)보다 높다.
const NAV_RING := Rect2(44.0, 96.0, 1192.0, 508.0)
const NAV_MARKER_SIZE := Vector2(80.0, 52.0)   # 마커 중심이 링 위 → 실점유 x 4~1276 · y 70~630
## 대상이 화면 안 이 여백보다 안쪽에 들어오면 화살표를 숨긴다("보이면 안 가리킨다").
const NAV_HIDE_MARGIN := 56.0
## 길잡이가 화살표를 짚을 때의 폴백 자리(어떤 화살표도 안 보이는 순간용).
const HUD_NAV_HINT_RECT := Rect2(1046.0, 300.0, 200.0, 140.0)
## 화살표 5종의 색·글리프·이름. `EdgeMarker.kind`가 이 키다.
## ⚠️ Y6: 화살표는 이제 **발견한 대상에만** 뜬다(§6.1). 성·캠프는 스테이지 시작부터
##    발견 상태이므로 화살표가 항상 있고, 보스문·균열·사건은 가 보기 전에는 없다.
const NAV_TARGETS: Array = [
	{"key": "castle", "name": "성", "glyph": "castle", "color": GamePalette.YELLOW},
	{"key": "camp", "name": "캠프", "glyph": "tent", "color": GamePalette.GREEN},
	{"key": "boss_gate", "name": "보스문", "glyph": "skull", "color": GamePalette.RED},
	{"key": "rift", "name": "균열", "glyph": "rift", "color": GamePalette.MAGENTA},
	{"key": "event", "name": "사건", "glyph": "spark", "color": GamePalette.CYAN}
]

# --- U3: 필드 HUD 칸 틴트 (킷 9-slice는 `modulate_color` 곱연산으로만 색이 실린다) ---
# v1은 칸의 상태를 `bg_color` + `border_color` 두 색으로 말했다. 킷 칸은 그림이 하나라
# 색 자리가 곱 틴트뿐이므로, **같은 의미를 밝기 차이로** 옮겼다.
#   비활성  ≈ 0.68 회색 틴트  → 칸 그림이 어둡게 가라앉는다
#   활성    ≈ 흰색에 의미색 0.34~0.40 → 눈에 띄게 밝고 색이 실린다 (밝기 차 약 1.5배)
# 흰 포커스 링(`focus_box`)을 쓰지 않은 이유는 handoff-u2 §5.5다 — 링과 스포트라이트를
# 한 화면에 같이 두면 초점이 둘이 된다. 길잡이가 이 레일을 짚는 순간이 정확히 그 경우다.
const RAIL_SLOT_TINT_IDLE := Color(0.66, 0.70, 0.70)
# X3: 0.22 → **0.42**. 미니모드 칸은 152×104 → 52×52로 줄었는데 원소색을 나르는 면적은
# 프레임 테두리뿐이다. 옛 값으로는 화·빙·뇌·유 네 장이 캡처에서 전부 같은 어두운 회녹으로
# 뭉쳤다(실측). 활성/비활성은 **밝기**로 갈리므로(활성은 흰색 기준) 채도를 올려도 안 섞인다.
const RAIL_SLOT_TINT_MIX_IDLE := 0.42
const RAIL_SLOT_TINT_MIX_ACTIVE := 0.34
const GHOST_SLOT_TINT_EMPTY := Color(0.70, 0.68, 0.74)
const GHOST_SLOT_TINT_MIX := 0.42
const BOSS_SLOT_TINT_IDLE := Color(0.68, 0.66, 0.72)
const BOSS_SLOT_TINT_MIX_ACTIVE := 0.38

# --- W10: 마왕 레일 밴드 (보스전 전용) ---------------------------------------
# 자리는 **나침반 + 마왕 고스트 레일의 합집합**(x 806~1264)이다. 보스전에서는
# 마왕성 나침반도, "마왕이 얼마나 자랐나" 요약도 의미가 없다 — 마왕이 이미 여기 있다.
# 그래서 두 패널을 끄고 그 자리에 실시간 레일을 켠다. 필드는 한 픽셀도 더 가리지 않는다.
#   가로 증명: 10 + 72×5 + 8×4 = 402 → 밴드 폭 458 (Y2가 414~448의 과열 사다리를 걷었다)
#   세로     : 4~20 머리말 / 22~32 바늘 / 34~86 칸 5개 / 90~102 RELOAD 창 / 104~126 상태
const BOSS_RAIL_BAND := Rect2(806.0, 10.0, 458.0, 132.0)
const BOSS_RAIL_SLOT := Vector2(72.0, 52.0)
const BOSS_RAIL_GAP := 8.0
const BOSS_RAIL_ORIGIN := Vector2(10.0, 34.0)
const BOSS_RAIL_NEEDLE_Y := 21.0
const BOSS_RAIL_NEEDLE_SIZE := Vector2(16.0, 10.0)
const BOSS_RAIL_WINDOW_TRACK := Rect2(10.0, 90.0, 438.0, 12.0)
const BOSS_RAIL_FLASH_TIME := 0.42

# V5: 일수 이정표 6종을 **dwell 이정표 4종**으로 갈아끼웠다(설계 §2.4 재키잉).
# 키는 `StageClock.MILESTONE_*` 상수와 1:1이다 — 클럭이 id를 소유하고 여기는 표기만 갖는다.
const MILESTONE_SHORT: Dictionary = {
	"stage_rift_1": "균열 개방",
	"stage_rift_2": "두 번째 균열",
	"stage_omen": "밤의 전조",
	"stage_blight": "잠식",
	"stage_descent_valve": "보스 강림"
}
## 배너 원문. `_on_dwell_advanced()`가 dwell 사건마다 하나씩 띄운다.
const MILESTONE_BANNER: Dictionary = {
	# X4: 「나침반」은 X3에서 사라진 패널이다. 지금 규약은 **화면 가장자리 화살표**이고,
	# 그 화살표는 목적지가 화면에 들어오면 스스로 사라진다(handoff-x3 §11.1).
	"stage_rift_1": "균열이 열렸습니다 · 가장자리 화살표를 따라가 정예를 쓸어 각인을 얻으세요",
	"stage_rift_2": "두 번째 균열 · 이 스테이지의 마지막 균열입니다",
	"stage_omen": "밤의 전조 · 이제 매 밤 마왕의 한 칸이 필드에 내려옵니다",
	"stage_blight": "잠식 · 당신이 오래 머문 걸 세계가 눈치챘습니다 · 모든 마물이 마왕의 잔재를 듭니다",
	"stage_descent_valve": "강림 임박 · 더 머물면 스테이지 보스가 직접 내려옵니다 (등급 C 고정)"
}

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.theme = _build_ui_theme()
	ui_layer.add_child(ui_root)
	# V5: 스테이지 그레이드 오버레이는 HUD **밑**에 깔린다 — 필드는 물들이되 글자는 안 가린다.
	_build_stage_overlay()
	hud = Control.new()
	hud.name = "HUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(hud)

	# X3: 화살표 내비는 **HUD의 첫 자식**이다. 상단/하단 클러스터보다 뒤에 그려지면
	# 링 위 마커가 스테이지 줄·미니 스트립을 덮을 수 있다(링을 아무리 들여도 툴팁
	# 히트박스와는 겹친다). 맨 아래 층에 두면 항상 HUD 정보가 이긴다.
	_build_edge_nav()
	_build_consumable_slot()
	_build_vitals_panel()
	_build_stage_panel()
	_build_ghost_rail()
	_build_cycle_rail()
	# W10: 보스전 전용 마왕 레일. 만들어만 두고 state == "boss"에서만 보인다.
	_build_boss_rail_band()

	interaction_text = _label("", 16, GamePalette.TEXT)
	interaction_text.position = HUD_INTERACT_RECT.position
	interaction_text.size = HUD_INTERACT_RECT.size
	interaction_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# X3: 킷 SLATE 칩(600×42의 불투명 판)을 걷었다. 화면 한복판에 상시로 뜨는 판이라
	# "블록을 제거하라"는 요구에 정면으로 걸린다. 대신 흐름 배너와 같은 처방을 쓴다 —
	# 좌표는 그대로 두고 **글자 외곽선만 6px**로 키워 낮·밤·성 어느 배경에서도 읽힌다.
	interaction_text.add_theme_constant_override("outline_size", 6)
	interaction_text.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.92))
	hud.add_child(interaction_text)

	# X3: 보스 체력도 판을 걷었다. 정체는 붉은 이름과 붉은 채움이 이미 말한다.
	boss_panel = Control.new()
	boss_panel.name = "BossVitals"
	boss_panel.position = HUD_BOSS_PANEL.position
	boss_panel.size = HUD_BOSS_PANEL.size
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false
	hud.add_child(boss_panel)
	boss_text = _label("버려진 마왕", 15, _hud_ink(GamePalette.RED))
	boss_text.position = Vector2(0.0, 0.0)
	boss_text.size = Vector2(HUD_BOSS_PANEL.size.x, 22.0)
	boss_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# V11: 트랙이 414px로 좁아졌다. 실사용 문자열(이름 + HP% + 칸 수 + 페이즈)은
	# 15px에서 250~354px라 그대로 들어가지만, 여기에 상태이상 5종이 전부 붙는 극단
	# ("… · 내 상태 독 · 연 · 한 · 유 · 전" ≈ 516px)은 넘친다. `_label()`이 clip_text를
	# 켜 두므로 그냥 두면 **글자가 반쪽으로 썰린다** — 말줄임으로 끊는다. 앞쪽이 곧
	# 이름·HP·칸 수라 잘려 나가는 것은 항상 덜 중요한 꼬리다.
	boss_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	boss_panel.add_child(boss_text)
	# 12px 게이지 = ColorRect 유지(ui-style-v3 §13 하한). 트랙만 어둡게 깔고 판은 없다.
	var boss_back := ColorRect.new()
	boss_back.position = HUD_BOSS_BAR.position
	boss_back.size = HUD_BOSS_BAR.size
	boss_back.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.82)
	boss_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(boss_back)
	boss_fill = ColorRect.new()
	boss_fill.position = Vector2(2.0, 2.0)
	boss_fill.size = Vector2(HUD_BOSS_BAR.size.x - 4.0, HUD_BOSS_BAR.size.y - 4.0)
	boss_fill.color = GamePalette.RED
	boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_back.add_child(boss_fill)
	boss_shield_fill = ColorRect.new()
	boss_shield_fill.position = Vector2(2.0, 2.0)
	boss_shield_fill.size = Vector2.ZERO
	boss_shield_fill.color = GamePalette.BLUE
	boss_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_back.add_child(boss_shield_fill)

	# X3: 툴팁 층은 **반드시 맨 마지막**이다(handoff-x2 §8 #3). 앞서 만든 대상들은
	# `_hud_tip_target()`으로 이름표만 달아 뒀고, 여기서 한 번에 배선한다.
	_build_hud_tooltip_layer()

# 얇은 구분선. HUD 패널 안의 층을 나누는 1px 규칙(UI 토큰 ③)을 한 곳으로 모은다.
# =============================================================================
# V5: 스테이지 그레이드 오버레이 (설계 §7.3) — 안개 · 늪 녹조 · 비네트
# =============================================================================
# 셋 다 **정적 전면 쿼드**다. 흐르게 하지 않는다(설계 §7.3 마지막 줄 · 트윈 루프 금지).
# 스테이지 색 자체는 CanvasModulate가, 채도·녹조는 world_grid의 타일 틴트가 갖는다.
# 여기 있는 것은 "필터 한 겹"이라 셋을 곱해도 한 계층에서만 곱해진다.
#   * 안개    `overlay-fog.png` · nearest · 타일링 · α = STAGE_FOG_ALPHA
#   * 녹조    단색 쿼드 · α = STAGE_GREEN_OVERLAY_ALPHA (4스테이지만)
#   * 비네트  `overlay-vignette.png` · **이 한 장만 LINEAR 필터** (handoff-v3-assets §2)
func _build_stage_overlay() -> void:
	stage_overlay = Control.new()
	stage_overlay.name = "StageOverlay"
	stage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(stage_overlay)
	stage_fog_rect = TextureRect.new()
	stage_fog_rect.texture = STAGE_FOG_TEXTURE
	# ASSET_MAP §14가 "**타일러블 아님**"이라고 못 박았다 — 320×180 한 장을 화면 전체로
	# 늘려 쓴다(1280×720 = 정확히 ×4라 nearest에서 픽셀이 안 밀린다).
	# TILE로 깔면 같은 구름 덩어리가 반복돼 안개가 아니라 물방울 무늬로 읽힌다(실측).
	stage_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	stage_fog_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_fog_rect.visible = false
	stage_overlay.add_child(stage_fog_rect)
	stage_green_rect = ColorRect.new()
	stage_green_rect.color = Color(0.34, 0.62, 0.24, 0.0)
	stage_green_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_green_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_green_rect.visible = false
	stage_overlay.add_child(stage_green_rect)
	stage_vignette_rect = TextureRect.new()
	stage_vignette_rect.texture = STAGE_VIGNETTE_TEXTURE
	stage_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# 유일하게 LINEAR인 노드다. nearest로 늘리면 비네트 경계에 계단이 생긴다.
	stage_vignette_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	stage_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_vignette_rect.visible = false
	stage_overlay.add_child(stage_vignette_rect)

## 스테이지 개시·복원마다 한 번. 필드 밖(메뉴·결과)에서는 전부 끈다.
func _apply_stage_grade() -> void:
	if not is_instance_valid(stage_overlay):
		return
	var index := clock.stage_index()
	var visible_now := state in ["playing", "boss", "castle_interior", "preview"]
	var fog_alpha := float(GameTuning.STAGE_FOG_ALPHA[index])
	stage_fog_rect.visible = visible_now and fog_alpha > 0.0
	# 색은 `_update_world_lighting()`이 매 프레임 조명과 맞춘다(아래 주석 참조).
	_tint_stage_fog()
	var green_alpha := float(GameTuning.STAGE_GREEN_OVERLAY_ALPHA[index])
	stage_green_rect.visible = visible_now and green_alpha > 0.0
	stage_green_rect.color = Color(0.34, 0.62, 0.24, green_alpha)
	stage_vignette_rect.visible = visible_now and bool(GameTuning.STAGE_VIGNETTE[index])
	_tint_stage_fog()
	# 0.72로 시작했다가 0.55로 내렸다 — 5스테이지 밤은 CanvasModulate #2f2f52 + 안개 0.24가
	# 이미 얹혀 있어 비네트까지 원본 세기로 두면 몹 실루엣이 화면 가장자리에서 사라진다(캡처 실측).
	stage_vignette_rect.modulate = Color(1.0, 1.0, 1.0, 0.55)

## 안개는 화면 공간 쿼드라 CanvasModulate 밖에 있다. 흰 구름을 그대로 두면 밤에
## **하얀 띠**로 읽힌다(캡처 실측). 조명색을 직접 곱해 "빛을 먹은 안개"로 만든다.
func _tint_stage_fog() -> void:
	if not is_instance_valid(stage_fog_rect) or not stage_fog_rect.visible:
		return
	var alpha := float(GameTuning.STAGE_FOG_ALPHA[clock.stage_index()])
	var light := canvas_modulate.color if is_instance_valid(canvas_modulate) else Color.WHITE
	stage_fog_rect.modulate = Color(light.r, light.g, light.b, alpha)

# =============================================================================
# X3 — HUD 호버 툴팁 (X2가 신설한 UIKit 공용 컴포넌트를 필드에서 처음 쓴다)
# =============================================================================
# X3가 화면에서 지운 문장은 **하나도 버려지지 않았다**. 전부 이 층으로 왔다.
# 층은 `hud`의 마지막 자식이어야 하고(안 그러면 HUD 그림이 툴팁을 덮는다),
# `process_mode = ALWAYS`라 일시정지 여부와 무관하게 같은 지연이 나온다
# (handoff-x2 §9 "필드에서 툴팁을 쓰려면").
#
# ⚠️ 길잡이 층(`GuideLayer`)은 런이 시작될 때 `hud`에 **나중에** 붙으므로 툴팁보다
#    위다. 길잡이 중에는 마우스를 안 쓰므로 문제가 되지 않는다.
func _build_hud_tooltip_layer() -> void:
	hud_tooltip_layer = UIKit.make_tooltip_layer(hud)
	hud_tooltip_layer.name = "HudTooltips"
	for key: String in hud_tooltip_targets.keys():
		var target: Variant = hud_tooltip_targets[key]
		if target is Control and is_instance_valid(target):
			# 빈 spec으로 배선만 해 둔다 — `_present()`가 빈 spec을 무시하므로
			# 첫 `_update_hud_tooltips()` 전에는 아무것도 안 뜬다.
			UIKit.attach_tooltip(target as Control, hud_tooltip_layer, {})

## 툴팁을 걸 대상을 등록한다(내용은 `_update_hud_tooltips()`가 10Hz로 채운다).
func _hud_tip_target(key: String, target: Control) -> void:
	hud_tooltip_targets[key] = target

## 캡처 전용 — 지연을 건너뛰고 즉시 띄운다. 나머지 경로는 사람이 호버했을 때와 같다.
func _force_hud_tooltip(key: String) -> bool:
	if hud_tooltip_layer == null or not hud_tooltip_targets.has(key):
		return false
	var target: Variant = hud_tooltip_targets[key]
	if not (target is Control) or not is_instance_valid(target):
		return false
	UIKit.tooltip_force(hud_tooltip_layer, target as Control)
	return true

# =============================================================================
# X3 — 좌상단 신상 (프레임리스)
# =============================================================================
# W5는 체력·보호막·자금·전과·경험을 330×132 판 하나에 1px 구분선 두 줄로 쌓았다.
# X3는 판과 구분선을 걷고 **아이콘 + 바 + 숫자**만 남긴다.
#
#   ♥ ▬▬▬▬▬▬▬▬▬ 100 / 100            LV 7
#     ▬▬▬(경험 4px)
#   ◎ 020        ◆◆  ✦✦              ← 보호막(청)·부활(초) 핍. 0이면 아예 없다
#
# 화면에서 사라진 문장은 전부 `vitals` 툴팁으로 갔다(정보 손실 0):
#   "수호 N · 부활 N" · "필드 마물 NNN · 처치 NNN" · "경험 N / N · 다음 선택" ·
#   캐릭터 이름("왕국 검사").
func _build_vitals_panel() -> void:
	vitals_panel = Control.new()
	vitals_panel.name = "Vitals"
	vitals_panel.position = HUD_VITALS_RECT.position
	vitals_panel.size = HUD_VITALS_RECT.size
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vitals_panel)

	# ⚠️ 킷 글리프 16종 중 `heart`는 절차적 선화가 아니라 NA 원본(`Ui/Receptacle/IconHeart`)
	# 이라 **자기 색을 갖는다**. `modulate`는 곱연산이므로 붉은 틴트를 얹으면 두 번 곱해져
	# 밤에 새까매진다 — 흰색(= 원본 그대로)으로 둔다. `coin`은 절차적 흰 선화라 틴트가 먹는다.
	# Y4(피드백 ⑫ · FEEDBACK_Y §8 ⑫): **두꺼운 심장 + 세그먼트 게이지.**
	# 판은 여전히 없다(X3의 프레임리스 계약 · `hud_block_pct`). 바뀐 것은 둘이다 —
	# 심장이 20 → 26px로 굵어졌고, 한 덩어리로 줄어들던 막대가 **칸으로 끊겼다.**
	# 연속 막대는 "얼마나 남았나"를 길이로만 말해서 전투 중 곁눈질로는 안 읽힌다.
	# 칸이 하나씩 꺼지면 **개수를 세지 않아도** 남은 양이 형태로 읽힌다.
	_kit_glyph(vitals_panel, HUD_VITALS_HEART, "heart", Color.WHITE, 26.0)
	# 12px 게이지 = ColorRect 유지(ui-style-v3 §13). 트랙은 반투명이라 필드가 비친다.
	var health_track := ColorRect.new()
	health_track.position = HUD_HEALTH_TRACK.position
	health_track.size = HUD_HEALTH_TRACK.size
	health_track.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.80)
	health_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_child(health_track)
	# `health_fill`은 **폭 계약을 지키는 눈금자**로 남는다 — 보이지는 않지만
	# `--cycle-test`와 툴팁이 "지금 몇 % 인가"를 이 노드의 폭에서 읽는다.
	health_fill = ColorRect.new()
	health_fill.name = "HealthFill"
	health_fill.position = Vector2(2.0, 2.0)
	health_fill.size = Vector2(HUD_HEALTH_TRACK.size.x - 4.0, HUD_HEALTH_TRACK.size.y - 4.0)
	health_fill.color = GamePalette.GREEN
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_fill.visible = false
	health_track.add_child(health_fill)
	health_segments.clear()
	var seg_span := HUD_HEALTH_TRACK.size.x - 4.0
	var seg_width := (seg_span - HUD_HEALTH_SEG_GAP * float(HUD_HEALTH_SEGMENTS - 1)) \
		/ float(HUD_HEALTH_SEGMENTS)
	for index in HUD_HEALTH_SEGMENTS:
		var cell := ColorRect.new()
		cell.name = "HealthSeg%d" % index
		cell.position = Vector2(2.0 + float(index) * (seg_width + HUD_HEALTH_SEG_GAP), 2.0)
		cell.size = Vector2(seg_width, HUD_HEALTH_TRACK.size.y - 4.0)
		cell.color = GamePalette.GREEN
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_track.add_child(cell)
		health_segments.append(cell)
	health_text = _label("100 / 100", UI_CAPTION_SIZE, GamePalette.TEXT)
	health_text.position = HUD_HEALTH_TEXT.position
	health_text.size = HUD_HEALTH_TEXT.size
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vitals_panel.add_child(health_text)

	# 경험 4px — 숫자는 없다. "다음 선택까지 얼마"는 길이로만 말한다.
	var xp_track := ColorRect.new()
	xp_track.position = HUD_XP_TRACK.position
	xp_track.size = HUD_XP_TRACK.size
	xp_track.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.72)
	xp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_child(xp_track)
	xp_fill = ColorRect.new()
	xp_fill.position = Vector2.ZERO
	xp_fill.size = Vector2(0.0, HUD_XP_TRACK.size.y)
	xp_fill.color = GamePalette.CYAN
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_track.add_child(xp_fill)

	# 레벨은 숫자 두 글자다. 직업 이름("왕국 검사")은 툴팁으로 내려갔다.
	class_text = _label("LV 1", UI_LABEL_SIZE, GamePalette.YELLOW)
	class_text.position = HUD_VITALS_LEVEL.position
	class_text.size = HUD_VITALS_LEVEL.size
	class_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	class_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vitals_panel.add_child(class_text)

	# Y4(피드백 ⑯ · handoff-ya §5): 킷 선화 `coin` 한 장 → **YA가 구운 금화 더미**
	# (`ui-coin-pile.png` 48×32). HUD의 이 숫자는 "지금 가진 돈 총액"이라 더미 그림이
	# 가장 정확한 그릇이다. 상점·세공사의 낱개 금화(`_gold_chip`)와 그림이 갈리는 것도
	# 의도다 — 낱개는 "이번에 낼 값", 더미는 "가진 전부"다.
	var purse := TextureRect.new()
	purse.name = "VitalsCoinPile"
	purse.texture = COIN_TEXTURE_PILE
	purse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	purse.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	purse.custom_minimum_size = Vector2.ZERO
	purse.position = HUD_VITALS_COIN
	purse.size = Vector2(24.0, 16.0)
	purse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	purse.modulate = GamePalette.YELLOW
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_child(purse)
	gold_text = _label("020", UI_HEADING_SIZE, GamePalette.YELLOW)
	gold_text.position = HUD_VITALS_GOLD.position
	gold_text.size = HUD_VITALS_GOLD.size
	gold_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vitals_panel.add_child(gold_text)

	# 보호막·부활 핍. 앞 6칸이 보호막(청 마름모), 뒤 6칸이 부활(초 마름모)이고
	# 둘 다 0이면 줄 전체가 사라진다 — 없는 자원은 자리도 안 차지한다.
	vitals_pips.clear()
	for index in HUD_PIP_MAX * 2:
		var pip := ColorRect.new()
		pip.position = HUD_VITALS_PIPS + Vector2(float(index) * (HUD_PIP_SIZE.x + HUD_PIP_GAP), 0.0)
		pip.size = HUD_PIP_SIZE
		pip.color = GamePalette.BLUE if index < HUD_PIP_MAX else GamePalette.GREEN
		pip.visible = false
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vitals_panel.add_child(pip)
		vitals_pips.append(pip)

	_hud_tip_target("vitals", vitals_panel)

# =============================================================================
# X3 — 상단 중앙 스테이지 줄 (구 V5 기한 패널 · 설계 §6.2 · §10 리스크 #1)
# =============================================================================
# **정보는 V5 그대로다**: 스테이지 5핍 · 낮/밤 진행 · 체류 압박 게이지 + 명명된
# 잠식 임계선. 바뀐 것은 440×96 판이 사라지고 세로 96 → 62로 줄었다는 것뿐이다.
#
#   「2스테이지 잿빛 벌판 · 낮」        ← 한 줄 텍스트
#   ▪▪▪▫▫                              ← 스테이지 5핍 (4px)
#   ▬▬▬▬▬▬▬▬▬▬                        ← 낮/밤 진행 (4px)
#   ▬▬▬▬▬│▬▬▬▬                        ← 체류 압박 + 잠식 임계선 (4px)
#   「체류 2」                          ← 평상시. 잠식·강림에서만 붉은 경고문이 된다
#
# 설계 §10 리스크 #1("게이지와 임계선을 반드시 노출한다")은 여전히 지켜진다 —
# 게이지 두 줄과 임계선 눈금은 두께만 10 → 4로 얇아졌고 하나도 안 사라졌다.
# 툴팁으로 내려간 문장: "낮 NN초 · 총 N일차 · 잠식 N / 강림 N" · "다음 체류 N(+N) · 균열 개방"
# · "이 스테이지 균열 N / N"(구 나침반 4줄째).
func _build_stage_panel() -> void:
	stage_panel = Control.new()
	stage_panel.name = "StageLine"
	stage_panel.position = HUD_STAGE_RECT.position
	stage_panel.size = HUD_STAGE_RECT.size
	stage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stage_panel)

	# =========================================================================
	# Y4 — 상단 스테이지 줄 (피드백 ⑤ · FEEDBACK_Y §8 ⑤)
	# =========================================================================
	# 구판 첫 줄은 「1스테이지 왕국 변경 · 낮」이라는 **17px 한 문장**이었다.
	# 세 가지(어디 · 무슨 곳 · 언제)를 글자로 나르는데, 셋 다 필드에서 1초 안에
	# 답이 나와야 하는 것들이라 문장이 가장 나쁜 그릇이다.
	#   어디  → **관문 아이콘 5개**(지난 관문은 채움 · 지금 관문은 열린 문 · 남은 관문은 윤곽)
	#   언제  → **해/달 아이콘 하나**
	#   무슨 곳 → 스테이지 이름은 `stage` 툴팁으로 내려갔다(정보 손실 0)
	# **판(Panel)은 여전히 한 장도 안 깐다** — `hud_block_pct 3.35%` 계약 그대로다.
	# 세련됨은 판이 아니라 아이콘 · 외곽선 · 두 줄 게이지가 만든다.
	phase_mark = DayNightMark.new()
	phase_mark.name = "StagePhaseMark"
	phase_mark.position = HUD_STAGE_PHASE_MARK
	phase_mark.size = Vector2(HUD_STAGE_GATE.y, HUD_STAGE_GATE.y)
	phase_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_panel.add_child(phase_mark)

	# 관문 5개. 구 5핍(20×4 막대)이 이 자리를 대신하고 있었다 — 같은 정보, 다른 그릇.
	stage_pips.clear()
	stage_gates.clear()
	var gate_span := HUD_STAGE_GATE.x * float(GameTuning.STAGE_COUNT) \
		+ HUD_STAGE_GATE_GAP * float(GameTuning.STAGE_COUNT - 1)
	var gate_left := floorf((HUD_STAGE_RECT.size.x - gate_span) * 0.5)
	for index in GameTuning.STAGE_COUNT:
		var gate := StageGateMark.new()
		gate.name = "StageGate%d" % index
		gate.position = Vector2(gate_left + float(index) * (HUD_STAGE_GATE.x + HUD_STAGE_GATE_GAP),
			HUD_STAGE_GATE_Y)
		gate.size = HUD_STAGE_GATE
		gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_panel.add_child(gate)
		stage_gates.append(gate)

	# 장소 꼬리표. **필드에서는 빈 문자열이라 아무것도 안 보인다** — 성·캠프·결전처럼
	# 관문 아이콘만으로는 못 읽는 상황에서만 한 낱말이 켜진다.
	phase_text = _label("", UI_CAPTION_SIZE, GamePalette.YELLOW)
	phase_text.name = "StagePlaceTag"
	phase_text.position = HUD_STAGE_TAG.position
	phase_text.size = HUD_STAGE_TAG.size
	phase_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phase_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_panel.add_child(phase_text)

	# 위 줄 = 낮/밤. 아래 줄 = 체류 압박. 4px 게이지라 안쪽 여백 없이 통째로 채운다.
	var phase_back := ColorRect.new()
	phase_back.position = HUD_PHASE_BAR.position
	phase_back.size = HUD_PHASE_BAR.size
	phase_back.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.72)
	phase_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_panel.add_child(phase_back)
	cycle_fill = ColorRect.new()
	cycle_fill.position = Vector2.ZERO
	cycle_fill.size = Vector2(0.0, HUD_PHASE_BAR.size.y)
	cycle_fill.color = GamePalette.YELLOW
	cycle_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_back.add_child(cycle_fill)

	dwell_track = ColorRect.new()
	dwell_track.position = HUD_DWELL_BAR.position
	dwell_track.size = HUD_DWELL_BAR.size
	dwell_track.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.72)
	dwell_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_panel.add_child(dwell_track)
	dwell_fill = ColorRect.new()
	dwell_fill.position = Vector2.ZERO
	dwell_fill.size = Vector2(0.0, HUD_DWELL_BAR.size.y)
	dwell_fill.color = GamePalette.MAGENTA
	dwell_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dwell_track.add_child(dwell_fill)
	# **명명된 임계선.** 이름은 아래 줄(경고문)이, 자리는 이 2px 눈금이 말한다.
	dwell_blight_mark = ColorRect.new()
	dwell_blight_mark.position = Vector2.ZERO
	dwell_blight_mark.size = Vector2(2.0, HUD_DWELL_BAR.size.y)
	dwell_blight_mark.color = GamePalette.RED
	dwell_blight_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dwell_track.add_child(dwell_blight_mark)

	dwell_text = _label("체류 0", UI_CAPTION_SIZE, GamePalette.TEXT)
	dwell_text.position = HUD_DWELL_TEXT.position
	dwell_text.size = HUD_DWELL_TEXT.size
	dwell_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dwell_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_panel.add_child(dwell_text)

	_hud_tip_target("stage", stage_panel)

# =============================================================================
# X3 — 화면 가장자리 화살표 내비 (구 나침반 패널 198×96을 대체한다)
# =============================================================================
# 사용자 원문: "위치 알려주는 편의성은 아예 섹터를 지우고, 화면에서 **화살표로 작게
# navigation**으로 만들어줘."
#
# 규약 다섯 줄
#   ① 대상이 화면 안(여백 NAV_HIDE_MARGIN 안쪽)에 들어오면 **화살표가 사라진다**.
#      눈에 보이는 것을 또 가리키지 않는다.
#   ② 대상 방향으로 화면 테두리 링(NAV_RING) 위 한 점에 마커 중심이 붙는다.
#   ③ 마커는 화살촉 + 대상 글리프 + 거리(m) 세 조각뿐이고 **전부 정적**이다.
#      깜빡이지 않는다(설계 §7.3 · ui-style-v3 §11 트윈 루프 금지와 같은 이유).
#   ④ 색과 글리프가 대상을 구분한다 — 성=금 집 / 캠프=초 천막 / 보스문=적 해골 /
#      균열=자주 균열. 색은 구 나침반 세 줄이 쓰던 색을 그대로 승계한다.
#   ⑤ 성·캠프 내부와 보스전에서는 전부 숨는다(길 안내가 의미를 잃는 상태다).
#
# 글리프를 킷 아틀라스에서 안 가져오고 절차적으로 그리는 이유는 둘이다.
#   * 킷 글리프 16종에 집·천막·해골·균열이 없다. 넷을 넣으려면 시트 행이 늘어
#     `ui-kit-glyphs.png`를 다시 굽고 `UIKit.GLYPH_INDEX` 계약을 건드려야 한다 —
#     X3 범위 밖(다른 화면 전부가 그 시트를 쓴다).
#   * **화살촉은 임의 각도로 돌아야 한다.** 킷 포인터 아틀라스는 4방향뿐이라
#     대각선에서 방향이 거짓말을 한다.
class EdgeMarker:
	extends Control

	var kind := ""
	var tint := Color.WHITE
	var angle := 0.0            # 대상 방향(라디안). 화살촉이 이쪽을 가리킨다
	var distance_text := ""

	const SCRIM := Color(0.03, 0.05, 0.09, 0.72)   # 로컬 스크림 — 글리프 뒤에만 최소로
	const INK := Color(0.03, 0.05, 0.09, 0.92)

	func _draw() -> void:
		var center := size * 0.5
		var dir := Vector2.from_angle(angle)
		# --- 화살촉: 링 바깥쪽 반지름 22 자리. 어두운 겹을 먼저 깔아 밤에도 산다 ---
		var tip := center + dir * 26.0
		var back := center + dir * 12.0
		var side := dir.orthogonal() * 8.0
		var head := PackedVector2Array([tip, back + side, back - side])
		var head_ink := PackedVector2Array([
			tip + dir * 2.0, back + side * 1.34 - dir * 1.6, back - side * 1.34 - dir * 1.6])
		draw_colored_polygon(head_ink, INK)
		draw_colored_polygon(head, tint)
		# --- 글리프: 마커 한가운데. 뒤에 작은 원형 스크림 한 장만 깐다 ---
		draw_circle(center, 12.0, SCRIM)
		_draw_glyph(center)
		# --- 거리: 링 안쪽. 외곽선을 먼저 그려 잔디·안개 위에서도 읽힌다 ---
		if distance_text.is_empty():
			return
		var font := get_theme_default_font()
		if font == null:
			return
		var at := center - dir * 22.0 + Vector2(-24.0, 4.0)
		draw_string_outline(font, at, distance_text, HORIZONTAL_ALIGNMENT_CENTER,
			48.0, 10, 4, INK)
		draw_string(font, at, distance_text, HORIZONTAL_ALIGNMENT_CENTER,
			48.0, 10, tint)

	## 18×18 안에 들어가는 실루엣 넷. 선이 아니라 덩어리로 그린다 — 12px 밑에서
	## 1px 선화는 안개·야간 모듈레이트에서 먼저 사라진다(V5 비네트 실측과 같은 이유).
	func _draw_glyph(at: Vector2) -> void:
		match kind:
			"castle":
				# 집 = 성. 몸통 + 총안 3개 + 어두운 문.
				draw_rect(Rect2(at + Vector2(-7.0, -2.0), Vector2(14.0, 10.0)), tint, true)
				for offset: float in [-7.0, -2.0, 3.0]:
					draw_rect(Rect2(at + Vector2(offset, -8.0), Vector2(4.0, 6.0)), tint, true)
				draw_rect(Rect2(at + Vector2(-2.0, 2.0), Vector2(4.0, 6.0)), INK, true)
			"tent":
				# 천막 = 캠프. 이등변 삼각형 + 어두운 입구.
				draw_colored_polygon(PackedVector2Array([
					at + Vector2(0.0, -9.0), at + Vector2(-9.0, 8.0), at + Vector2(9.0, 8.0)]), tint)
				draw_colored_polygon(PackedVector2Array([
					at + Vector2(0.0, -1.0), at + Vector2(-3.5, 8.0), at + Vector2(3.5, 8.0)]), INK)
			"skull":
				# 해골 = 보스문. 두개골 + 턱 + 눈구멍 두 개.
				draw_circle(at + Vector2(0.0, -2.0), 7.5, tint)
				draw_rect(Rect2(at + Vector2(-4.0, 3.0), Vector2(8.0, 5.0)), tint, true)
				draw_rect(Rect2(at + Vector2(-4.5, -4.0), Vector2(3.5, 4.0)), INK, true)
				draw_rect(Rect2(at + Vector2(1.0, -4.0), Vector2(3.5, 4.0)), INK, true)
				draw_rect(Rect2(at + Vector2(-1.0, 4.0), Vector2(2.0, 4.0)), INK, true)
			"rift":
				# 균열 = 갈라진 금. 두꺼운 지그재그 한 줄.
				var crack := PackedVector2Array([
					at + Vector2(1.0, -9.0), at + Vector2(-3.0, -2.0),
					at + Vector2(2.0, 1.0), at + Vector2(-2.0, 5.0), at + Vector2(2.0, 9.0)])
				draw_polyline(crack, tint, 3.4)
			"spark":
				# 네 갈래 별 = 필드 사건(Y6). 균열의 지그재그와 실루엣이 안 겹친다.
				draw_colored_polygon(PackedVector2Array([
					at + Vector2(0.0, -10.0), at + Vector2(3.0, -3.0), at + Vector2(10.0, 0.0),
					at + Vector2(3.0, 3.0), at + Vector2(0.0, 10.0), at + Vector2(-3.0, 3.0),
					at + Vector2(-10.0, 0.0), at + Vector2(-3.0, -3.0)]), tint)
			_:
				draw_circle(at, 6.0, tint)

func _build_edge_nav() -> void:
	nav_layer = Control.new()
	nav_layer.name = "EdgeNav"
	nav_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(nav_layer)
	nav_markers.clear()
	for entry: Dictionary in NAV_TARGETS:
		var marker := EdgeMarker.new()
		marker.name = "Nav_%s" % String(entry["key"])
		marker.kind = String(entry["glyph"])
		marker.tint = _hud_ink(entry["color"])
		marker.size = NAV_MARKER_SIZE
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.visible = false
		marker.set_meta("nav_key", String(entry["key"]))
		marker.set_meta("distance", 0.0)
		nav_layer.add_child(marker)
		nav_markers[String(entry["key"])] = marker
		_hud_tip_target("nav_%s" % String(entry["key"]), marker)

# =============================================================================
# X3 — 마왕 고스트 레일 (설계 §6.3) — 프레임리스 · 아이콘 5개
# =============================================================================
# W5는 252×96 ABYSS 판에 제목("마왕의 5칸") · 각인 수 · 칸 번호 · 각인 배지 숫자 ·
# 꼬리말 세 지표를 넣었다. X3는 **30px 실루엣 다섯 개**만 남긴다.
#   * 각인이 붙은 칸에는 우상단에 자주색 점 하나(숫자 없음).
#   * 카드 구성이 바뀌면 그 칸이 1회 강조된다(GHOST_FLASH_TIME) — 이벤트 표시는 유지.
#   * 제목·각인 수·꼬리말·칸 번호는 전부 `ghost` 툴팁으로 갔다.
# ABYSS 톤은 유지한다. 판이 없어도 칸 그림 자체가 자줏빛이라 "저기는 마왕의 것"이
# 색으로 읽힌다(ui-style-v3 §2 톤 표).
func _build_ghost_rail() -> void:
	ghost_panel = Control.new()
	ghost_panel.name = "GhostRail"
	ghost_panel.position = HUD_GHOST_RECT.position
	ghost_panel.size = HUD_GHOST_RECT.size
	ghost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ghost_panel)
	ghost_slot_panels.clear()
	ghost_slot_flash.clear()
	ghost_slot_ids.clear()
	for index in GameTuning.BOSS_SLOT_COUNT:
		var slot := Panel.new()
		slot.position = HUD_GHOST_ORIGIN + Vector2(float(index) * HUD_GHOST_PITCH, 0.0)
		slot.size = HUD_GHOST_SLOT
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", _kit_cell_style(UIKit.Tone.ABYSS, GHOST_SLOT_TINT_EMPTY))
		slot.set_meta("card_id", "")
		slot.set_meta("rune_count", 0)
		ghost_panel.add_child(slot)
		var icon := SKILL_ICON_SCRIPT.new()
		icon.name = "Icon"
		icon.position = Vector2(4.0, 4.0)
		icon.size = Vector2(22.0, 22.0)
		icon.setup("basic", GamePalette.PURPLE, false)
		icon.visible = false
		slot.add_child(icon)
		# 각인 유무 점 하나. 몇 개인지는 툴팁이 말한다(숫자 배지 삭제).
		var mark := ColorRect.new()
		mark.name = "RuneDot"
		mark.position = Vector2(HUD_GHOST_SLOT.x - 7.0, 3.0)
		mark.size = Vector2(4.0, 4.0)
		mark.color = GamePalette.MAGENTA
		mark.visible = false
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(mark)
		ghost_slot_panels.append(slot)
		ghost_slot_flash.append(0.0)
		ghost_slot_ids.append("")
	_hud_tip_target("ghost", ghost_panel)

# =============================================================================
# W10: 마왕 레일 밴드 — 보스전의 공략 문법을 화면에 올린다 (설계 §6.2)
# =============================================================================
# "마왕의 바퀴가 화면에 보인다 → '지금 네 칸째, 피하고 버텨라 → RELOAD 왔다,
#  지금 때려라'. **이것이 보스전의 문법이다.**"
#
# 그래서 이 밴드는 세 가지를 동시에 말한다.
#   ① 지금 어느 칸이 실행 중인가 (바늘 + 칸 강조 — 다음 공격의 예고)
#   ② 이번 바퀴가 얼마나 긴가   (밟은 칸 수 / 상한 — 위험 지속 시간)
#   ③ 반격 창이 언제 오는가     (RELOAD 창 게이지 — 평상시엔 "청산 시 N초" 예고,
#                                RELOAD 중엔 남은 시간이 **초록**으로 줄어든다)
# 색 언어는 플레이어 레일(W5)과 같고 RELOAD 냉각은 청색이다.
# 다른 점은 하나뿐 — 마왕의 RELOAD는 **내 기회**이므로 초록으로 뒤집는다.
#
# Y2: 과열 8단 온도계(구 ②)는 통째로 사라졌다. 「한 칸은 한 바퀴에 두 번까지」가
# 규칙이 된 뒤로 위험도는 온도가 아니라 **바퀴 길이**가 말한다(§1.2 · §1.4).
func _build_boss_rail_band() -> void:
	boss_rail_band = Panel.new()
	boss_rail_band.name = "BossRailBand"
	boss_rail_band.position = BOSS_RAIL_BAND.position
	boss_rail_band.size = BOSS_RAIL_BAND.size
	boss_rail_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# U3 v3: 마왕 레일 밴드 = **ABYSS**(§2 톤 표 "마왕"). 고스트 레일과 같은 소속이고,
	# 이 밴드는 고스트 레일 자리를 그대로 넘겨받으므로 톤이 이어져야 화면이 안 튄다.
	UIKit.style_panel(boss_rail_band, UIKit.Tone.ABYSS, UIKit.Role.PANEL)
	boss_rail_band.visible = false
	hud.add_child(boss_rail_band)

	boss_rail_head = _label("마왕의 딜싸이클  ·  칸 01 / 05", 11, GamePalette.RED.lightened(0.22))
	boss_rail_head.position = Vector2(10.0, 3.0)
	boss_rail_head.size = Vector2(250.0, 18.0)
	boss_rail_band.add_child(boss_rail_head)
	boss_rail_meter_text = _label("밟은 칸 0 / 5  ·  한 칸 최대 2번", 11, GamePalette.YELLOW)
	boss_rail_meter_text.position = Vector2(258.0, 3.0)
	boss_rail_meter_text.size = Vector2(190.0, 18.0)
	boss_rail_meter_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_rail_band.add_child(boss_rail_meter_text)

	boss_rail_slots.clear()
	boss_rail_slot_flash.clear()
	for index in GameTuning.BOSS_SLOT_COUNT:
		var slot := Panel.new()
		slot.name = "BossRailSlot%d" % index
		slot.position = BOSS_RAIL_ORIGIN + Vector2(float(index) * (BOSS_RAIL_SLOT.x + BOSS_RAIL_GAP), 0.0)
		slot.size = BOSS_RAIL_SLOT
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", _kit_cell_style(UIKit.Tone.ABYSS, BOSS_SLOT_TINT_IDLE))
		slot.set_meta("slot_index", index)
		slot.set_meta("card_id", "")
		slot.set_meta("rune_count", 0)
		slot.set_meta("style_key", "")
		boss_rail_band.add_child(slot)
		var icon := SKILL_ICON_SCRIPT.new()
		icon.name = "Icon"
		icon.position = Vector2(4.0, 4.0)
		icon.size = Vector2(24.0, 24.0)
		icon.setup("basic", GamePalette.PURPLE, false)
		icon.visible = false
		slot.add_child(icon)
		var number := _label("%d" % (index + 1), 9, UI_EDGE)
		number.name = "Number"
		number.position = Vector2(slot.size.x - 18.0, 2.0)
		number.size = Vector2(14.0, 13.0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.add_child(number)
		var name_label := _label("빈칸", 9, GamePalette.MUTED)
		name_label.name = "Name"
		name_label.position = Vector2(4.0, 30.0)
		name_label.size = Vector2(slot.size.x - 8.0, 12.0)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot.add_child(name_label)
		# 각인 배지 — 플레이어 레일과 같은 3핍 + "+N" 공식(handoff-w5 §6).
		for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
			var pip := ColorRect.new()
			pip.name = "Pip%d" % pip_index
			pip.position = Vector2(4.0 + float(pip_index) * 11.0, 43.0)
			pip.size = Vector2(8.0, 7.0)
			pip.color = UI_CHIP_BG
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(pip)
		var overflow := _label("", 9, GamePalette.YELLOW)
		overflow.name = "Overflow"
		overflow.position = Vector2(38.0, 40.0)
		overflow.size = Vector2(30.0, 12.0)
		overflow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.add_child(overflow)
		boss_rail_slots.append(slot)
		boss_rail_slot_flash.append(0.0)

	boss_rail_needle = RailMarker.new()
	boss_rail_needle.name = "BossNeedle"
	boss_rail_needle.size = BOSS_RAIL_NEEDLE_SIZE
	boss_rail_needle.position = Vector2(_boss_rail_slot_center_x(0) - BOSS_RAIL_NEEDLE_SIZE.x * 0.5, BOSS_RAIL_NEEDLE_Y)
	boss_rail_needle.color = GamePalette.RED
	boss_rail_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_rail_needle.set_meta("slot_index", 0)
	boss_rail_band.add_child(boss_rail_needle)

	# RELOAD 창 — 이 게이지가 보스전 공략의 심장이다.
	boss_rail_window_track = ColorRect.new()
	boss_rail_window_track.position = BOSS_RAIL_WINDOW_TRACK.position
	boss_rail_window_track.size = BOSS_RAIL_WINDOW_TRACK.size
	boss_rail_window_track.color = UI_CHIP_BG
	boss_rail_window_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_rail_band.add_child(boss_rail_window_track)
	boss_rail_window_fill = ColorRect.new()
	boss_rail_window_fill.position = Vector2(2.0, 2.0)
	boss_rail_window_fill.size = Vector2(0.0, BOSS_RAIL_WINDOW_TRACK.size.y - 4.0)
	boss_rail_window_fill.color = GamePalette.ORANGE
	boss_rail_window_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_rail_window_track.add_child(boss_rail_window_fill)

	boss_rail_state_text = _label("빚 0.00초  ·  다 갚으면 RELOAD 0.00초", 11, GamePalette.ORANGE)
	boss_rail_state_text.position = Vector2(10.0, 105.0)
	boss_rail_state_text.size = Vector2(438.0, 20.0)
	boss_rail_state_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_rail_band.add_child(boss_rail_state_text)

func _boss_rail_slot_center_x(index: int) -> float:
	return BOSS_RAIL_ORIGIN.x + float(index) * (BOSS_RAIL_SLOT.x + BOSS_RAIL_GAP) + BOSS_RAIL_SLOT.x * 0.5

# =============================================================================
# V7: 레일 밴드를 **마왕과 스테이지 보스가 공유한다** (설계 §3.2 "구현 비용 0에 가깝다")
# =============================================================================
# 밴드는 5칸으로 지어 두고 남는 칸을 숨긴다. Y2가 과열 사다리를 통째로 걷었으므로
# 「마왕만 가지는 게이지」라는 분기 자체가 사라졌다 — 스테이지 보스는 머리말 문구만
# 다르다(각인 없음 · 페이즈). 지금 누구 밴드인가는 아래 두 창구가 정한다.
func active_boss_cycle() -> DealCycleController:
	if is_instance_valid(stage_boss) and is_instance_valid(stage_boss_cycle):
		return stage_boss_cycle
	return boss_cycle

func active_boss_factory() -> FactoryDeck:
	if is_instance_valid(stage_boss) and is_instance_valid(stage_boss_cycle):
		return stage_boss_factory
	return boss_factory

## 지금 밴드가 그리는 보스가 스테이지 보스인가(= 각인 없음).
func active_boss_is_stage() -> bool:
	return is_instance_valid(stage_boss) and is_instance_valid(stage_boss_cycle)

# 마왕 사이클 시그널은 W5의 레일 바인더와 같은 "지연 연결" 규약을 쓴다 —
# _begin_boss_battle이 아무것도 하지 않아도 밴드가 알아서 붙는다.
func _bind_boss_rail_signals() -> void:
	var live_cycle := active_boss_cycle()
	if boss_rail_bound_cycle == live_cycle:
		return
	boss_rail_bound_cycle = live_cycle
	for index in boss_rail_slot_flash.size():
		boss_rail_slot_flash[index] = 0.0
	if not is_instance_valid(live_cycle):
		return
	if not live_cycle.slot_entered.is_connected(_on_boss_rail_slot_entered):
		live_cycle.slot_entered.connect(_on_boss_rail_slot_entered)
	if not live_cycle.cycle_completed.is_connected(_on_boss_cycle_completed):
		live_cycle.cycle_completed.connect(_on_boss_cycle_completed)

func _on_boss_rail_slot_entered(index: int, _reentry: int) -> void:
	if index >= 0 and index < boss_rail_slot_flash.size():
		boss_rail_slot_flash[index] = BOSS_RAIL_FLASH_TIME

func _on_boss_cycle_completed(steps: int, _exec_peak: int) -> void:
	boss_peak_steps = maxi(boss_peak_steps, steps)
	# ⚠️ 반격 창(RELOAD)을 여기서 세면 안 된다 — `_finish_cycle()`은 `cycle_completed`를
	# **`reload_duration`을 채우기 전에** 발화한다(deal_cycle_controller.gd). 창의 개수는
	# `_update_boss_rail`에서 `reloading`의 false→true 전이로 센다.

func _update_boss_rail(delta: float) -> void:
	if not is_instance_valid(boss_rail_band):
		return
	var live_cycle := active_boss_cycle()
	var live_factory := active_boss_factory()
	var is_stage := active_boss_is_stage()
	# 강림한 스테이지 보스는 state가 "playing"이지만 밴드는 떠 있어야 한다(§6.6).
	var live := is_instance_valid(live_cycle) and live_factory != null \
		and (state == "boss" or (is_stage and state == "playing"))
	boss_rail_band.visible = live
	# 보스전에서는 길 안내(보스문 방향)와 고스트 레일(성장 요약)이 의미를 잃는다.
	# X3: 나침반 패널이 화살표 내비로 갈렸으므로 끄는 대상도 그쪽으로 옮겼다
	# (`_update_edge_nav()`의 `state == "playing"` 조건과 이중 안전장치다 — 강림한
	#  스테이지 보스는 state가 "playing"인 채로 밴드를 띄우므로 여기서도 꺼야 한다).
	if is_instance_valid(nav_layer):
		nav_layer.visible = nav_layer.visible and not live
	if is_instance_valid(ghost_panel):
		ghost_panel.visible = not live
	if not live:
		return
	_bind_boss_rail_signals()
	var slot_count := maxi(1, live_factory.slots.size())
	var boss_label := String(stage_boss_profile.get("name", "보스")) if is_stage else "마왕"
	if not is_stage:
		boss_peak_steps = maxi(boss_peak_steps, live_cycle.executed_slot_count())
	var reloading: bool = live_cycle.reloading
	# 반격 창의 개폐 — 이 전이가 §3.2/§6.2 공략 문법의 신호다. 열릴 때 한 번만 알린다.
	if reloading and not boss_reload_open:
		boss_reload_open = true
		boss_reload_windows += 1
		_show_banner("%s RELOAD %.2f초 — 지금 때려라" % [boss_label, live_cycle.reload_duration], GamePalette.GREEN, 1.4)
	elif not reloading:
		boss_reload_open = false
	var active_index := clampi(live_cycle.current_index, 0, slot_count - 1)
	for index in boss_rail_slots.size():
		# V7: 3칸/4칸 보스는 남는 칸을 숨긴다. 칸 수가 곧 승급 신호다(§3.2 "레일에 칸이 하나 더").
		var slot_panel: Panel = boss_rail_slots[index]
		slot_panel.visible = index < slot_count
		if not slot_panel.visible:
			continue
		boss_rail_slot_flash[index] = maxf(0.0, boss_rail_slot_flash[index] - delta)
		_apply_boss_rail_slot(index, active_index, reloading)
	boss_rail_needle.visible = not reloading
	boss_rail_needle.position.x = _boss_rail_slot_center_x(active_index) - BOSS_RAIL_NEEDLE_SIZE.x * 0.5
	boss_rail_needle.set_meta("slot_index", active_index)
	boss_rail_needle.color = GamePalette.RED if is_stage else GamePalette.ORANGE
	boss_rail_needle.queue_redraw()
	boss_rail_head.text = "%s의 딜싸이클  ·  칸 %02d / %02d%s" % [
		boss_label, active_index + 1, slot_count,
		"  ↺%d" % live_cycle.current_reentry if live_cycle.current_reentry > 0 else ""
	]
	if is_stage:
		var phase_total: int = (stage_boss_profile.get("phases", []) as Array).size()
		var phase_now: int = int(stage_boss.boss_phase) if is_instance_valid(stage_boss) else 0
		boss_rail_meter_text.text = "각인 없음  ·  페이즈 %d / %d" % [phase_now, phase_total]
		boss_rail_meter_text.add_theme_color_override("font_color", GamePalette.RED.lightened(0.2))
	else:
		# Y2: 「과열 N / 8 · 피해 ×N」이 「밟은 칸 N / 5 · 한 칸 최대 N번」으로 갈렸다.
		# 밟은 칸이 늘수록 바퀴가 길다 = 반격 창까지 더 버텨야 한다는 뜻이다(§1.5).
		boss_rail_meter_text.text = "밟은 칸 %d / %d  ·  한 칸 최대 %d번" % [
			live_cycle.executed_slot_count(), slot_count, live_cycle.exec_count(active_index)]
		boss_rail_meter_text.add_theme_color_override("font_color", GamePalette.YELLOW)
	var track_width := BOSS_RAIL_WINDOW_TRACK.size.x - 4.0
	if reloading:
		# 반격 창: 남은 시간이 초록으로 줄어든다. "지금 때려라"가 글자로도 나온다.
		var remain_ratio := clampf(live_cycle.reload_remaining / maxf(live_cycle.reload_duration, 0.001), 0.0, 1.0)
		boss_rail_window_fill.size.x = track_width * remain_ratio
		boss_rail_window_fill.color = GamePalette.GREEN
		boss_rail_state_text.text = "▼ 무방비 · RELOAD %.2f초 남음 — 지금 때려라" % live_cycle.reload_remaining
		boss_rail_state_text.add_theme_color_override("font_color", GamePalette.GREEN)
	else:
		# 평상시: "지금 청산하면 반격 창이 몇 초인가"의 예고. 길수록 내게 유리하다.
		var projected := live_cycle.projected_reload()
		boss_rail_window_fill.size.x = track_width * clampf(projected / RuneEngine.RELOAD_CAP, 0.0, 1.0)
		boss_rail_window_fill.color = GamePalette.ORANGE if projected < RuneEngine.RELOAD_CAP * 0.5 else GamePalette.RED
		boss_rail_state_text.text = "빚 %.2f초  ·  한 바퀴가 끝나면 반격 창 %.2f초 (×%.2f)" % [
			live_cycle.reload_debt, projected, live_cycle.reload_scale]
		boss_rail_state_text.add_theme_color_override("font_color", GamePalette.ORANGE)

func _apply_boss_rail_slot(index: int, active_index: int, reloading: bool) -> void:
	var slot := boss_rail_slots[index]
	var deck := active_boss_factory()
	var card: Dictionary = deck.get_card(index) if deck != null else {}
	var card_id := String(card.get("id", ""))
	var runes: Array = deck.runes_on(index) if deck != null else []
	if String(slot.get_meta("card_id", "")) != card_id or int(slot.get_meta("rune_count", -1)) != runes.size():
		slot.set_meta("card_id", card_id)
		slot.set_meta("rune_count", runes.size())
		var icon := slot.get_node_or_null("Icon") as PixelSkillIcon
		if is_instance_valid(icon):
			icon.visible = true
			icon.setup(card_id if not card_id.is_empty() else "basic", _factory_card_color(card), false)
		var name_label := slot.get_node_or_null("Name") as Label
		if is_instance_valid(name_label):
			name_label.text = _factory_card_name(card)
		for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
			var pip := slot.get_node_or_null("Pip%d" % pip_index) as ColorRect
			if is_instance_valid(pip):
				pip.color = _rune_rarity_color(String((runes[pip_index] as Dictionary).get("id", ""))) if pip_index < runes.size() else UI_CHIP_BG
		var overflow := slot.get_node_or_null("Overflow") as Label
		if is_instance_valid(overflow):
			overflow.text = "+%d" % (runes.size() - RuneEngine.RUNE_SLOTS_PER_SLOT) if runes.size() > RuneEngine.RUNE_SLOTS_PER_SLOT else ""
	var active := index == active_index and not reloading
	# U3 v3: 색 두 개(테두리·배경) → 틴트 하나. 의미는 그대로다(§8.1의 색 언어 유지).
	var tint := BOSS_SLOT_TINT_IDLE
	if reloading:
		# RELOAD 중에는 5칸 전부가 청색으로 식는다 — 플레이어 레일과 같은 규칙(§8.1).
		tint = Color(0.84, 0.88, 0.92).lerp(GamePalette.CYAN, 0.45)
	elif active:
		# Y2: 활성 칸 강조색이 과열 램프에서 **되밟기 색**으로 갈렸다. 두 번째 실행은
		# 적색 — 같은 칸이 연달아 터지는 순간이 눈에 보여야 회피 타이밍이 잡힌다.
		var live_cycle := active_boss_cycle()
		var repeated: bool = is_instance_valid(live_cycle) and live_cycle.exec_count(index) >= 2
		var accent := GamePalette.RED if (active_boss_is_stage() or repeated) else GamePalette.ORANGE
		tint = Color.WHITE.lerp(accent, BOSS_SLOT_TINT_MIX_ACTIVE)
	var flash := boss_rail_slot_flash[index]
	if flash > 0.0:
		var t := flash / BOSS_RAIL_FLASH_TIME
		tint = tint.lerp(Color.WHITE.lerp(GamePalette.RED, 0.34), t)
	var key := "%s|%d" % [tint.to_html(false), 1 if active else 0]
	if String(slot.get_meta("style_key", "")) != key:
		slot.set_meta("style_key", key)
		slot.add_theme_stylebox_override("panel", _kit_cell_style(UIKit.Tone.ABYSS, tint))

# =============================================================================
# X3 미니 딜싸이클 스트립 (구 W5 5칸 상시 레일 밴드 · 설계 §8.1)
# =============================================================================
# 사용자 요구 원문 두 개가 여기서 만난다.
#   (W5) "스크롤 없이 딜싸이클 칸 5개를 한번에 보고 진행 상황을 알 수 있어야 해."
#   (X3) "딜싸이클 범위가 너무 커 — 최대한 아이콘으로 **미니모드**로 만들어주고,
#         블록 범위 없애서 **필드가 더 잘 보이게** 해줘."
# 둘은 모순이 아니다. 5칸을 한 번에 보여 주는 데 필요한 것은 **아이콘 다섯 개와
# 바늘 하나**뿐이고, 1048×156을 먹던 것은 칸마다 붙어 있던 글자였다.
#
# 지운 것 (칸당 4줄 × 5칸 = 20줄 + 밴드 머리말 2줄 + 정보 열 3줄 = 25줄 → **0줄**)
#   칸 이름("화염장") · 랭크·원소 줄("R2 화") · 칸 번호("칸 1") · 태그("각인 3" /
#   "재실행 ↺2") · 머리말("딜싸이클 · 칸 03 / 05 ↺1") · 빚 줄("빚 1.35초 · 청산 시
#   RELOAD 2.40초") · 상태 줄("3바퀴 · 2.42초").
#   전부 `rail`·`rail_slot{N}`·`rail_dial`
#   툴팁으로 갔다 — 정보 손실 0.
#
# 남긴 것 (그림뿐)
#   ▲ 바늘 · 아이콘 5개(36px) · 칸 프레임의 **원소색 틴트** · 칸당 진행 3px 바 ·
#   각인 핍 3개(+과밀 점) · **밟은 횟수 점 2개** · RELOAD 다이얼 · 빚 4px 바.
#
# ⚠️ Y2(2026-08-09) — 과열 8핍 세로 줄(20×48)이 **삭제됐다.** 규칙에서 과열이
#    사라졌으므로(§1.4) 8단 온도계는 아무것도 안 가리키는 그림이 된다. 그 자리를
#    §1.4가 지정한 후임이 대신한다: **칸마다 밟은 횟수 점 1~2개.**
#    핍은 칸 안(우측 여백 44~52)으로 들어갔고, 비게 된 좌측 20px는 남겨 두지 않고
#    스트립 전체를 22px 좁혔다 — 필드를 그만큼 덜 가린다(X3의 탈블록 방향과 같다).
#
# 스트립 내부 좌표(로컬) — 세로 74 (구 156의 **47.4%**)
#   y   1~ 10  바늘 마커 (14×9)
#   y  12~ 64  칸 5개 (52×52, 간격 10) | RELOAD 다이얼 44
#   y  66~ 70  빚 게이지
# 가로 증명: 8 |8 … 308 (52×5 + 10×4 = 300)| 2 |44| 4 = 358 (구 380)
#
# 그리기 함수 분리는 W11 계약 그대로다: _build_rail_slot(칸 골격) /
# _apply_rail_slot_content(데이터→노드) / _apply_rail_slot_styles(색·강조) /
# RailMarker(바늘) / CycleSweepGauge(다이얼).
const RAIL_BAND_RECT := Rect2(461.0, 636.0, 358.0, 74.0)
const RAIL_SLOT_SIZE := Vector2(52.0, 52.0)
const RAIL_SLOT_GAP := 10.0
const RAIL_SLOT_ORIGIN := Vector2(8.0, 12.0)
const RAIL_NEEDLE_SIZE := Vector2(14.0, 9.0)
const RAIL_NEEDLE_Y := 1.0
const RAIL_DIAL_RECT := Rect2(310.0, 14.0, 44.0, 44.0)
const RAIL_DEBT_TRACK := Rect2(8.0, 66.0, 300.0, 4.0)
# 칸 안쪽(52×52 로컬)
const RAIL_SLOT_ICON := Rect2(8.0, 4.0, 36.0, 36.0)
const RAIL_SLOT_TRACK := Rect2(4.0, 42.0, 44.0, 3.0)
const RAIL_SLOT_PIP_Y := 46.0
const RAIL_SLOT_PIP := Vector2(6.0, 4.0)
const RAIL_SLOT_PIP_GAP := 3.0
# Y2: 밟은 횟수 점(§1.4). 아이콘 오른쪽 여백 44~52에 세로 2개 — `SLOT_EXEC_CAP`과
# 개수가 **같아야** 한다. 한 개 켜짐 = 한 번 밟음 / 두 개 = 이 바퀴에 더는 못 들어온다.
const RAIL_SLOT_EXEC_DOT := Vector2(5.0, 5.0)
const RAIL_SLOT_EXEC_X := 45.0
const RAIL_SLOT_EXEC_Y := 6.0
const RAIL_SLOT_EXEC_PITCH := 8.0
## 안 켜진 점. 자리를 항상 보여 줘야 "두 칸 중 하나가 찼다"가 읽힌다(구 8핍 유령 규약).
const RAIL_EXEC_DOT_OFF := Color(0.04, 0.07, 0.11, 0.72)
# 1회성 강조 지속(초). 짧게 번쩍이고 끝난다 — 루프 애니메이션이 아니다.
const RAIL_FLASH_TIME := 0.45
const RAIL_FLOW_FLASH_TIME := 0.9
const GHOST_FLASH_TIME := 1.1

# 흐름 각인 3계열. 회귀 / 도약 / 재실행이 서로 다른 색·문구로 구분된다(W5 완료 기준).
# 확정(패시브) 각인은 step.fired에 남지 않으므로(handoff-w2 §9-2) 여기 없다 —
# 그쪽은 칸의 각인 배지가 상시로 보여 준다. 그래서 `trade_skip`·`finisher`(둘 다 확정)와
# `rail_loop`(레일 소유 · 사이클 시작에 한 번 굴린다)는 이 표에 **일부러** 없다.
# Y2: 구 id 8종(rewind_1 · skip_1 · repeat …)이 전부 폐기돼 이 표가 영원히 빈손이었다.
const RAIL_FLOW_KIND: Dictionary = {
	"back_one": "back",
	"jump_one": "jump",
	"twice": "again"
}

# 원소 태그 1글자 표기 (§3.8). 카드 데이터의 element 값을 그대로 읽는다.
# V6(2026-08-09): **v3 7계로 재편했다**(설계 §4.2 · §4.8 "원소 마크 6종 → 7종").
# v2의 `light/blood/iron`은 v3에서 `psi/poison/strike`로 **역할 승계**됐고(V2 웨이브),
# 이 표만 v2 어휘로 남아 있어 독·유·타·초 카드 16장의 레일 마크가 **빈 문자열**로
# 나왔다(`_card_element()`는 이미 v3 값을 돌려주고 있었다). 실측으로 잡은 회귀다.
# Y4(FEEDBACK_Y §3.2 · handoff-y3 §8.2 육안 지적): **한자를 버렸다.**
# 유저 원문은 "초가 무슨 말인지 모름"이었다. 「초(超)」·「유(油)」·「타(打)」는
# 한자를 아는 사람에게만 읽히는 글자였고, 그 셋이 금지 어휘표에 올랐다.
# 새 마크는 `DealCardLibrary.element_name()` 7개(불·얼음·번개·독·기름·타격·정신)의
# **첫 글자**다 — 두 표가 어긋날 수 없게 이름에서 기계적으로 딴다.
#   불 얼 번 독 기 타 정
# 「독」·「타」는 글자가 그대로 남았지만 근거가 바뀌었다(毒/打의 음이 아니라 독/타격의 첫 자).
const RAIL_ELEMENT_MARK: Dictionary = {
	"fire": "불", "ice": "얼", "thunder": "번",
	"poison": "독", "oil": "기", "strike": "타", "psi": "정"
}

# =============================================================================
# X1 — 원소 7계 의미색 (2026-08-09 사용자 피드백 ③ "속성은 텍스트가 아니라 색")
# =============================================================================
# 사용자 원문: "카드의 속성 — 단 속성은 텍스트가 아니라 스킬 배경색 또는 블록색
# 통일로." 그러려면 **원소 → 색**이 프로젝트에 하나만 있어야 하는데, X1 이전에는
# 그런 표가 없었다. 카드마다 `color` 키가 따로 있었고 그 값이 원소와 무관했다 —
# 같은 빙(氷)인데 `dash_blade`·`frost_ring`·`moon_barrier`는 청록(67c7d4)이고
# `guardian_blade`만 초록(83c65c)이었다(실측). 색이 정보를 나르려면 그럴 수 없다.
#
# **네 색은 지어낸 것이 아니다** — 설계 §4.8이 상태 핍·몹 마스크 틴트로 이미 못 박은
# "독 녹 / 연 주 / 한 청 / 전 황"을 그대로 승계한다(`enemy.gd:STATUS_TINTS`가 정본).
# 필드에서 불에 탄 몹이 주황이면 화(火) 카드도 주황이어야 한다.
#   fire   ← burn  `e78a45` = GamePalette.ORANGE
#   ice    ← chill `67c7d4` = GamePalette.CYAN
#   thunder← shock `f4d35e` = GamePalette.YELLOW
#   poison ← poison`83c65c` = GamePalette.GREEN
# 나머지 셋은 §4.8이 색을 주지 않아 X1이 정했고, 근거는 각각 한 줄이다.
#   oil    §4.8의 유(油)는 **흑**(`1b1622`)이다. 그 값을 카드 틴트로 쓰면 카드가
#          통째로 까매져 아이콘이 죽는다. 팔레트에서 가장 어두운 유채색인
#          PURPLE(`7563a8`)을 "흑의 읽히는 대역"으로 쓴다.
#   strike 비원소다(§4.2 "상태를 터뜨린다"). 원소색을 주면 안 되므로 **무채**
#          STONE_LIGHT(`c3bda4`). 7색 중 유일하게 채도가 없다 = 한눈에 비원소다.
#   psi    비원소이면서 초자연이다. 무채 하나는 이미 타(打)가 썼으므로 남은 축인
#          자주 MAGENTA(`bd6ac8`).
#
# ⚠️ **이 표가 원소색의 단일 진실 원천이다.** X2(편집 화면)·X3(HUD)·X4(온보딩)는
#    새 표를 만들지 말고 `_element_color()`를 부를 것. `RAIL_ELEMENT_MARK`와 키가
#    같아야 하고(둘 다 7키), 색약 대비용 1글자 마크는 그 표에서 온다.
#
# ▸ **Y4(FEEDBACK_Y §3.2) — 불과 기름 두 색을 갈아끼웠다.** 나머지 다섯은 그대로다.
#   fire  ORANGE(`e78a45`) → **EMBER_RED(`e2452f`)**
#         주황이 기름 갈색·번개 노랑과 색상환에서 붙어 흐려진다. 불은 빨강이 직관이다.
#   oil   PURPLE(`7563a8`) → **OIL_BROWN(`7a5230`)**
#         **보라 두 개(기름·정신)가 겹치던 원인이다.** 기름은 갈색이 직관이고
#         명도가 48이라 빨강(89)·노랑(93)과도 명도로 갈린다.
#   경계 쌍 둘(빨강↔갈색 · 노랑↔갈색)은 색상이 아니라 **명도로** 갈리므로
#   5스테이지 밤 + 안개 0.24 + 비네트 조건의 캡처 육안 검수가 유일한 판정 수단이다.
# ⚠️ `GamePalette.ORANGE`·`PURPLE` 자체는 **한 값도 안 바꿨다** — 필드 VFX·게이지·
#    임계선이 그 둘을 원소와 무관하게 쓴다. 신설 상수 2개만 여기서 소비한다.
const ELEMENT_COLOR: Dictionary = {
	"fire": GamePalette.EMBER_RED,
	"ice": GamePalette.CYAN,
	"thunder": GamePalette.YELLOW,
	"poison": GamePalette.GREEN,
	"oil": GamePalette.OIL_BROWN,
	"strike": GamePalette.STONE_LIGHT,
	"psi": GamePalette.MAGENTA
}

## 원소 1개의 의미색. 태그가 없는 카드(기본 베기·보스 패턴)는 무채로 떨어진다.
func _element_color(element: String) -> Color:
	if ELEMENT_COLOR.has(element):
		return ELEMENT_COLOR[element]
	return GamePalette.STONE

# =============================================================================
# Y4 — 상단 스테이지 줄의 그림 두 종 (피드백 ⑤)
# =============================================================================
# 둘 다 **정적이다.** `_process`가 없고 값이 바뀔 때만 `queue_redraw()`를 받는다
# (ui-style-v3 §11 트윈 루프 금지와 같은 이유 — HUD에서 깜빡이는 것은 위협뿐이다).
# 킷 글리프 16종에 해·달·문이 없어서 절차적으로 그린다. 시트를 굽는 것은 에셋 몫이고
# 이 셋은 원·선·다각형 몇 개라 절차적으로도 22px에서 또렷하다.

## 낮이면 채운 해 + 광선 8줄, 밤이면 오른쪽이 열린 초승달.
class DayNightMark:
	extends Control

	var night := false
	var tint := Color.WHITE

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.30
		if night:
			# 두꺼운 호 하나 = 초승달. 중심을 오른쪽으로 밀고 오른쪽 60°를 비운다.
			draw_arc(center + Vector2(radius * 0.30, 0.0), radius, 0.62, TAU - 0.62, 20,
				tint, maxf(2.0, radius * 0.62))
		else:
			draw_circle(center, radius * 0.74, tint)
			for index in 8:
				var angle := TAU * float(index) / 8.0
				draw_line(center + Vector2.from_angle(angle) * radius * 1.00,
					center + Vector2.from_angle(angle) * radius * 1.42, tint, 2.0)

## 관문 하나. 아치문 실루엣이고 **채움**이 상태 셋을 가른다.
##   0 = 지난 관문(꽉 참) · 1 = 지금 관문(문이 열려 있다) · 2 = 아직(윤곽선만)
class StageGateMark:
	extends Control

	var state := 2
	var tint := Color.WHITE

	func _arch() -> PackedVector2Array:
		var radius := size.x * 0.5
		var foot := size.y - 1.0
		var points := PackedVector2Array()
		points.append(Vector2(0.0, foot))
		for step in 9:
			var angle := PI + PI * float(step) / 8.0
			points.append(Vector2(radius + cos(angle) * radius, radius + sin(angle) * radius))
		points.append(Vector2(size.x, foot))
		return points

	func _draw() -> void:
		var points := _arch()
		var closed := PackedVector2Array(Array(points) + [points[0]])
		if state == 2:
			draw_polyline(closed, Color(tint, 0.5), 2.0)
			return
		draw_colored_polygon(points, tint if state == 0 else Color(tint, 0.42))
		draw_polyline(closed, tint, 2.0)
		if state == 1:
			# 지금 서 있는 관문만 문이 열려 있다 — 안쪽을 파낸다.
			var radius := size.x * 0.5
			var mouth := PackedVector2Array()
			mouth.append(Vector2(radius * 0.62, size.y - 1.0))
			for step in 9:
				var angle := PI + PI * float(step) / 8.0
				mouth.append(Vector2(radius + cos(angle) * radius * 0.52,
					radius * 1.06 + sin(angle) * radius * 0.52))
			mouth.append(Vector2(size.x - radius * 0.62, size.y - 1.0))
			draw_colored_polygon(mouth, Color(0.04, 0.06, 0.10, 0.82))

# 바늘 마커. 트윈 없이 position만 바뀐다 — 흐름 델타가 "튀는" 것 자체가 정보다.
class RailMarker:
	extends Control

	var color := Color.WHITE

	func _draw() -> void:
		var points := PackedVector2Array()
		points.append(Vector2(size.x * 0.5, size.y))
		points.append(Vector2(0.0, 0.0))
		points.append(Vector2(size.x, 0.0))
		draw_colored_polygon(points, color)
		draw_rect(Rect2(Vector2(size.x * 0.5 - 1.0, 0.0), Vector2(2.0, size.y)), Color(color, 0.5), true)

# 원형 스윕 게이지. 남은 비율만 링 + 옅은 부채꼴로 그린다.
# v1의 RELOAD 되감기 릴에서 이 위젯 하나만 살려 레일 정보 열의 다이얼로 승격했다.
class CycleSweepGauge:
	extends Control

	var ratio := 1.0
	var radius := 25.0
	var thickness := 5.0
	var ring_color := Color("e78a45")
	var track_color := Color("232c3d")

	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center, radius, 0.0, TAU, 48, track_color, thickness, false)
		var visible_ratio := clampf(ratio, 0.0, 1.0)
		if visible_ratio <= 0.004 or radius <= 1.0:
			return
		var start := -PI * 0.5
		var end := start + TAU * visible_ratio
		# 부채꼴은 0.998까지만 채운다. 1.0이면 첫 점과 끝 점이 겹쳐 삼각분할이 실패한다
		# (v1 되감기 릴에서는 ratio가 1.0에 머무는 프레임이 없어 드러나지 않던 잠복 버그).
		var fan_ratio := minf(visible_ratio, 0.998)
		var fan_end := start + TAU * fan_ratio
		var steps := maxi(3, int(ceil(48.0 * fan_ratio)))
		var sector := PackedVector2Array()
		sector.append(center)
		for step in steps + 1:
			sector.append(center + Vector2.from_angle(lerpf(start, fan_end, float(step) / float(steps))) * radius)
		draw_colored_polygon(sector, Color(ring_color, 0.08))
		draw_arc(center, radius, start, end, 48, Color(ring_color, 0.9), thickness, false)
		draw_rect(Rect2(center + Vector2(-1.0, -radius - thickness), Vector2(2.0, thickness * 2.0)), ring_color, true)

func _build_cycle_rail() -> void:
	# X3: 킷 SLATE 판(1048×156)을 걷었다. 스트립은 **그림 없는 Control**이고
	# 눈에 보이는 것은 아이콘·게이지·핍뿐이다 — 필드가 스트립 사이로 그대로 비친다.
	rail_band = Control.new()
	rail_band.name = "CycleStrip"
	rail_band.position = RAIL_BAND_RECT.position
	rail_band.size = RAIL_BAND_RECT.size
	rail_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(rail_band)

	rail_slot_panels.clear()
	rail_slot_flash.clear()
	rail_slot_flash_color.clear()
	for index in FactoryDeck.SLOT_COUNT:
		rail_slot_panels.append(_build_rail_slot(index))
		rail_slot_flash.append(0.0)
		rail_slot_flash_color.append(GamePalette.YELLOW)

	rail_needle = RailMarker.new()
	rail_needle.name = "Needle"
	rail_needle.size = RAIL_NEEDLE_SIZE
	rail_needle.position = Vector2(_rail_slot_center_x(0) - RAIL_NEEDLE_SIZE.x * 0.5, RAIL_NEEDLE_Y)
	rail_needle.color = GamePalette.YELLOW
	rail_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_needle.set_meta("slot_index", 0)
	rail_band.add_child(rail_needle)

	# 빚 게이지 — "지금 청산하면 나올 RELOAD"의 예고. RELOAD 중에는 잔여 시간으로 바뀐다.
	# 4px이라 안쪽 여백 없이 통째로 채운다(12px 미만 게이지 = ColorRect · §13).
	rail_debt_track = ColorRect.new()
	rail_debt_track.name = "DebtTrack"
	rail_debt_track.position = RAIL_DEBT_TRACK.position
	rail_debt_track.size = RAIL_DEBT_TRACK.size
	rail_debt_track.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.78)
	rail_debt_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_band.add_child(rail_debt_track)
	rail_debt_fill = ColorRect.new()
	rail_debt_fill.position = Vector2.ZERO
	rail_debt_fill.size = Vector2(0.0, RAIL_DEBT_TRACK.size.y)
	rail_debt_fill.color = GamePalette.ORANGE
	rail_debt_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_debt_track.add_child(rail_debt_fill)

	_build_rail_dial()

	# 흐름 델타 배너는 스트립 위쪽(y 606~628)에 따로 놓아 스트립을 가리지 않는다.
	rail_flow_banner = _label("", UI_BODY_SIZE, GamePalette.CYAN)
	rail_flow_banner.position = HUD_FLOW_BANNER.position
	rail_flow_banner.size = HUD_FLOW_BANNER.size
	rail_flow_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# W12 시각 QA: 이 라벨만 **패널 없이 잔디 위에 맨글자**로 떠 있어 낮 화면에서
	# 초록 글자(도약 GREEN)가 잔디에 묻혀 사실상 안 보였다. 딜싸이클이 왜 튀었는지
	# 알려 주는 유일한 문장이라 판독 실패가 곧 학습 실패다.
	# X3에서는 HUD 전체가 이 처방(글자 외곽선)을 쓴다 — 이 줄이 그 원형이었다.
	rail_flow_banner.add_theme_constant_override("outline_size", 6)
	rail_flow_banner.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.92))
	rail_flow_banner.visible = false
	rail_flow_banner.set_meta("kind", "")
	hud.add_child(rail_flow_banner)

	# 스트립 전체 = "한 바퀴"의 툴팁 히트박스. 칸/다이얼은 각자 더 좁은 대상을 갖는다.
	_hud_tip_target("rail", rail_band)

func _rail_slot_center_x(index: int) -> float:
	return RAIL_SLOT_ORIGIN.x + float(index) * (RAIL_SLOT_SIZE.x + RAIL_SLOT_GAP) + RAIL_SLOT_SIZE.x * 0.5

# 칸 하나의 골격 (52×52). X3에서 **Label이 한 개도 없다** — 아이콘 · 진행 바 · 핍뿐이다.
# W11은 Icon 노드만 스프라이트로 갈아끼우면 된다(계약 유지).
func _build_rail_slot(index: int) -> Panel:
	var slot := Panel.new()
	slot.name = "Slot%d" % index
	slot.position = RAIL_SLOT_ORIGIN + Vector2(float(index) * (RAIL_SLOT_SIZE.x + RAIL_SLOT_GAP), 0.0)
	slot.size = RAIL_SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _kit_cell_style(UIKit.Tone.SLATE, RAIL_SLOT_TINT_IDLE))
	slot.set_meta("slot_index", index)
	slot.set_meta("card_id", "")
	slot.set_meta("rune_count", -1)
	slot.set_meta("active", false)
	slot.set_meta("style_key", "")
	rail_band.add_child(slot)

	var icon := SKILL_ICON_SCRIPT.new()
	icon.name = "Icon"
	icon.position = RAIL_SLOT_ICON.position
	icon.size = RAIL_SLOT_ICON.size
	icon.setup("basic", GamePalette.STONE_LIGHT, false)
	slot.add_child(icon)

	# 진행 3px — 이 칸이 실행 중일 때만 찬다. 숫자는 없다(구 "칸 N" 라벨 자리).
	var track := ColorRect.new()
	track.name = "Track"
	track.position = RAIL_SLOT_TRACK.position
	track.size = RAIL_SLOT_TRACK.size
	track.color = Color(UI_CHIP_BG.r, UI_CHIP_BG.g, UI_CHIP_BG.b, 0.72)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(track)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.position = Vector2.ZERO
	fill.size = Vector2(0.0, track.size.y)
	fill.color = GamePalette.CYAN
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

	# 각인 핍 — 3핍(희귀도 색) + 과밀 점 1개. 구 "+N" 글자는 사라졌고 정확한 수는 툴팁이 말한다.
	var pip_span := RAIL_SLOT_PIP.x * float(RuneEngine.RUNE_SLOTS_PER_SLOT) \
		+ RAIL_SLOT_PIP_GAP * float(RuneEngine.RUNE_SLOTS_PER_SLOT - 1)
	var pip_left := (RAIL_SLOT_SIZE.x - pip_span) * 0.5
	for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
		var pip := ColorRect.new()
		pip.name = "Pip%d" % pip_index
		pip.position = Vector2(pip_left + float(pip_index) * (RAIL_SLOT_PIP.x + RAIL_SLOT_PIP_GAP), RAIL_SLOT_PIP_Y)
		pip.size = RAIL_SLOT_PIP
		pip.color = UI_CHIP_BG
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(pip)
	var overflow := ColorRect.new()
	overflow.name = "Overflow"
	overflow.position = Vector2(pip_left + pip_span + RAIL_SLOT_PIP_GAP, RAIL_SLOT_PIP_Y)
	overflow.size = Vector2(3.0, RAIL_SLOT_PIP.y)
	overflow.color = GamePalette.TEXT
	overflow.visible = false
	overflow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overflow)

	# Y2: 밟은 횟수 점 — 구 과열 8핍의 후임(§1.4). 개수는 `SLOT_EXEC_CAP`에서 온다.
	for dot_index in RuneEngine.SLOT_EXEC_CAP:
		var dot := ColorRect.new()
		dot.name = "Exec%d" % dot_index
		dot.position = Vector2(RAIL_SLOT_EXEC_X, RAIL_SLOT_EXEC_Y + float(dot_index) * RAIL_SLOT_EXEC_PITCH)
		dot.size = RAIL_SLOT_EXEC_DOT
		dot.color = RAIL_EXEC_DOT_OFF
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(dot)

	_hud_tip_target("rail_slot%d" % index, slot)
	return slot

# RELOAD 다이얼 — 유지하되 반지름 25 → 17로 소형화. 평상시 = 이 스텝의 진행,
# RELOAD 중 = 남은 대기(주황). 구 정보 열의 글자 세 줄은 툴팁으로 갔다.
func _build_rail_dial() -> void:
	rail_dial = CycleSweepGauge.new()
	rail_dial.name = "Dial"
	rail_dial.position = RAIL_DIAL_RECT.position
	rail_dial.size = RAIL_DIAL_RECT.size
	rail_dial.radius = 17.0
	rail_dial.thickness = 4.0
	rail_dial.ring_color = GamePalette.CYAN
	rail_dial.track_color = UI_EDGE_SOFT
	rail_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_band.add_child(rail_dial)
	_hud_tip_target("rail_dial", rail_dial)

# -----------------------------------------------------------------------------
# 레일 실시간 갱신 (_process W5 구역이 매 프레임 부른다)
# -----------------------------------------------------------------------------
func _update_cycle_rail(delta: float) -> void:
	if not is_instance_valid(rail_band):
		return
	_bind_rail_signals()
	_decay_rail_flashes(delta)
	var live := hud.visible and not inside_castle and is_instance_valid(player_cycle) \
		and factory != null and not factory.slots.is_empty()
	rail_band.visible = live
	if is_instance_valid(rail_flow_banner):
		rail_flow_banner.visible = live and rail_flow_flash > 0.0
	if not live:
		return
	var reloading: bool = player_cycle.reloading
	var active_index := clampi(player_cycle.current_index, 0, rail_slot_panels.size() - 1)
	# 바늘은 보간하지 않는다. 회귀·도약이 일어나면 그 자리에서 튄다(설계 §8.1 "위치 점프").
	rail_needle.position = Vector2(_rail_slot_center_x(active_index) - RAIL_NEEDLE_SIZE.x * 0.5, RAIL_NEEDLE_Y)
	rail_needle.visible = not reloading
	rail_needle.set_meta("slot_index", active_index)
	# X3: 바늘은 미니모드에서 **가장 작은 조각인데 가장 중요한 정보**다. 평상시 노랑을
	# 유지하되, Y2부터는 **되밟는 순간**(이 칸 두 번째 실행)에 주황으로 갈아입는다 —
	# 「한 칸 두 번」이 이 게임의 유일한 폭발 구간이므로 그것만 색으로 말한다(§1.5).
	var repeated_now := player_cycle.exec_count(active_index) >= RuneEngine.SLOT_EXEC_CAP
	var needle_color: Color = _rail_flow_color() if rail_flow_flash > 0.0 \
		else (GamePalette.ORANGE if repeated_now else GamePalette.YELLOW)
	if not rail_needle.color.is_equal_approx(needle_color):
		rail_needle.color = needle_color
		rail_needle.queue_redraw()
	var step_ratio := clampf(player_cycle.group_elapsed / maxf(player_cycle.group_duration, 0.01), 0.0, 1.0)
	for index in rail_slot_panels.size():
		var track := rail_slot_panels[index].get_node_or_null("Track") as ColorRect
		if not is_instance_valid(track):
			continue
		var fill := track.get_node_or_null("Fill") as ColorRect
		if not is_instance_valid(fill):
			continue
		var ratio := step_ratio if (not reloading and index == active_index) else 0.0
		fill.size.x = track.size.x * ratio
		fill.color = GamePalette.ORANGE if repeated_now else GamePalette.CYAN
	_apply_rail_slot_styles(active_index, reloading)
	# 다이얼: 평상시 = 이 스텝의 진행, RELOAD 중 = 남은 대기 시간.
	if reloading:
		rail_dial.ratio = clampf(player_cycle.reload_remaining / maxf(player_cycle.reload_duration, 0.01), 0.0, 1.0)
		rail_dial.ring_color = GamePalette.ORANGE
	else:
		rail_dial.ratio = step_ratio
		rail_dial.ring_color = GamePalette.CYAN
	rail_dial.queue_redraw()
	var span := RAIL_DEBT_TRACK.size.x
	if reloading:
		rail_debt_fill.size.x = span * clampf(player_cycle.reload_remaining / maxf(player_cycle.reload_duration, 0.01), 0.0, 1.0)
		rail_debt_fill.color = GamePalette.ORANGE
	else:
		var projected := player_cycle.projected_reload()
		rail_debt_fill.size.x = span * clampf(projected / RuneEngine.RELOAD_CAP, 0.0, 1.0)
		rail_debt_fill.color = GamePalette.RED if projected > RuneEngine.RELOAD_CAP * 0.6 else GamePalette.ORANGE.darkened(0.2)
	# Y2: 밟은 횟수 점 — 매 프레임 칸별로 갱신한다(사이클이 끝나면 전부 꺼진다).
	_update_rail_exec_dots(reloading)

## 칸마다 「이번 바퀴에 몇 번 밟았나」를 점 1~2개로 그린다. 구 과열 8핍의 후임(§1.4).
## 두 번째 점이 켜진 칸은 **이 바퀴에 더 들어올 수 없다** — 바늘이 그 칸을 건너뛴다.
func _update_rail_exec_dots(reloading: bool) -> void:
	for index in rail_slot_panels.size():
		var executed := 0 if reloading else player_cycle.exec_count(index)
		for dot_index in RuneEngine.SLOT_EXEC_CAP:
			var dot := rail_slot_panels[index].get_node_or_null("Exec%d" % dot_index) as ColorRect
			if not is_instance_valid(dot):
				continue
			var lit := dot_index < executed
			var want := (GamePalette.ORANGE if dot_index >= 1 else GamePalette.YELLOW) if lit else RAIL_EXEC_DOT_OFF
			if not dot.color.is_equal_approx(want):
				dot.color = want

## 미니 칸 하나의 의미색. **X1 원소 7계 표가 유일한 출처다**(handoff-x1 §3 · handoff-x2 §9).
## v1은 `_factory_card_color()`(카드마다 따로 박힌 색)를 썼는데 그 값은 원소와 무관해서
## 같은 빙(氷) 카드 넷이 서로 다른 색으로 나왔다. HUD까지 원소색으로 갈아 끼우면
## 필드 · ESC 편집 · 레벨업 세 화면에서 "속성 = 색"이 **한 언어**가 된다.
func _rail_slot_color(card: Dictionary) -> Color:
	if card.is_empty():
		return GamePalette.STONE_LIGHT
	return _element_color(_card_element(card))

# 칸의 색·강조. RELOAD 중에는 스트립 전체가 청색으로 식는다(설계 §8.1).
func _apply_rail_slot_styles(active_index: int, reloading: bool) -> void:
	for index in rail_slot_panels.size():
		var slot := rail_slot_panels[index]
		var card := factory.get_card(index)
		var base := _rail_slot_color(card)
		var accent := GamePalette.BLUE if reloading else base
		var is_active := index == active_index and not reloading
		# U3 v3: 색 두 개 → 틴트 하나(곱연산). 원소색 · RELOAD 청색 · 1회성 강조색이
		# 전부 그대로 실리고, 활성 칸은 "밝다"로 갈린다(v1은 "테두리가 두껍다"였다).
		# X3: 미니모드라 칸이 52px밖에 안 된다 — 비활성 틴트를 0.22 → 0.30으로 올려
		# 빈칸과 카드 칸이 작게 봐도 갈리게 했다(캡처 실측).
		var tint := Color.WHITE.lerp(accent, RAIL_SLOT_TINT_MIX_ACTIVE) if is_active \
			else RAIL_SLOT_TINT_IDLE.lerp(accent, RAIL_SLOT_TINT_MIX_IDLE)
		var flash := rail_slot_flash[index]
		if flash > 0.0:
			tint = tint.lerp(Color.WHITE.lerp(rail_slot_flash_color[index], 0.42), flash)
		var key := "%s|%d" % [tint.to_html(false), 1 if is_active else 0]
		if String(slot.get_meta("style_key", "")) == key:
			continue
		slot.set_meta("style_key", key)
		slot.set_meta("active", is_active)
		slot.add_theme_stylebox_override("panel", _kit_cell_style(UIKit.Tone.SLATE, tint))

# -----------------------------------------------------------------------------
# 스트립 데이터 갱신 (_update_hud가 10Hz로 부른다)
# -----------------------------------------------------------------------------
# X3: 이름이 `_update_rail_text`인데 **글자를 한 개도 안 쓴다**. 이 함수가 하던 다섯
# 문장(머리말 · 빚 줄 · 밟은 칸 · 상태)은 `_update_hud_tooltips()`로 갔고,
# 여기 남은 것은 아이콘·각인 핍처럼 "그림으로 말하는" 갱신뿐이다. 호출부 계약을
# 지키려고 이름은 유지했다(`--cycle-test` · `--capture-hud`가 이 이름을 부른다).
func _update_rail_text() -> void:
	if not is_instance_valid(rail_band) or not rail_band.visible or factory == null or not is_instance_valid(player_cycle):
		return
	for index in rail_slot_panels.size():
		_apply_rail_slot_content(index)

func _apply_rail_slot_content(index: int) -> void:
	var slot := rail_slot_panels[index]
	var card := factory.get_card(index)
	var card_id := "basic" if card.is_empty() else String(card.get("id", "basic"))
	var color := _rail_slot_color(card)
	var icon := slot.get_node_or_null("Icon") as PixelSkillIcon
	if is_instance_valid(icon) and (icon.skill_id != card_id or icon.icon_color != color):
		icon.setup(card_id, color, false)
	if String(slot.get_meta("card_id", "")) != card_id:
		slot.set_meta("card_id", card_id)
	# 각인 핍 — 개수가 바뀔 때만 다시 칠한다. 구 "+N" 글자는 과밀 점 하나로 바뀌었다.
	var rune_count := factory.rune_count_on(index)
	if int(slot.get_meta("rune_count", -1)) != rune_count:
		slot.set_meta("rune_count", rune_count)
		var runes := factory.runes_on(index)
		for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
			var pip := slot.get_node_or_null("Pip%d" % pip_index) as ColorRect
			if not is_instance_valid(pip):
				continue
			if pip_index < runes.size():
				pip.color = _rune_rarity_color(String((runes[pip_index] as Dictionary).get("id", "")))
			else:
				pip.color = UI_CHIP_BG
		var overflow := slot.get_node_or_null("Overflow") as ColorRect
		if is_instance_valid(overflow):
			overflow.visible = rune_count > RuneEngine.RUNE_SLOTS_PER_SLOT

func _rail_element_mark(index: int) -> String:
	if factory == null or index < 0 or index >= factory.slots.size():
		return ""
	# W9 경계 접촉 1줄(W5 소유 구역 · 레이아웃 무변경): `factory.slots[i]["card"]`는
	# `{kind,id,rank}` 원시 인스턴스라 element 키가 없다. 그대로 넘기면 원소 마크가
	# **항상 빈칸**이 된다. 정의를 통해 해석하는 `_card_element()`로 바꿨다.
	return String(RAIL_ELEMENT_MARK.get(_card_element(factory.get_card(index)), ""))

func _rune_rarity_color(rune_id: String) -> Color:
	var rarity := String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("rarity", RuneEngine.RARITY_COMMON))
	if rarity == RuneEngine.RARITY_EPIC:
		return GamePalette.MAGENTA
	if rarity == RuneEngine.RARITY_RARE:
		return GamePalette.CYAN
	return GamePalette.YELLOW

# -----------------------------------------------------------------------------
# Y3 — 각인 글리프 (피드백 ③ · 설계 §2.5)
# -----------------------------------------------------------------------------
# §2.5는 전용 시트 `art/v2/ui-kit-rune.png`(15칸)를 예고했지만 **YA가 굽지 않았다**
# (handoff-ya §1 산출물 15장에 없다). 새 시트를 굽는 것은 에셋 웨이브 몫이므로
# 이미 있는 두 시트에서 15종을 **겹치지 않게** 배정했다:
#   `UIKit.GLYPH_INDEX`(16종 · 상징) + `UIKit.POINTER_INDEX`(16종 · 방향).
# 흐름 각인은 방향 시트, 강화·조건 각인은 상징 시트를 쓴다 — 두 시트가 그대로
# "바늘을 움직이는가 / 칸을 세게 하는가"의 두 계열이 된다.
#
# ⚠️ **`UIKit.GLYPH_INDEX`를 한 줄도 고치지 않았다**(§2.5 명시 함정). 읽기만 한다.
#     행이 늘면 그 시트를 쓰는 다른 화면 전부의 좌표 계약이 깨진다.
# ⚠️ 유일성은 `data_test`가 아니라 `--v4-test`가 단언한다(15종 전부 다른 그림 · §Y3 테스트).
const RUNE_GLYPH: Dictionary = {
	# 칸 각인 10종
	"twice":      ["glyph", "plus"],            # 한 번 더 더한다
	"back_one":   ["pointer", "pointer_left"],  # 뒤로
	"jump_one":   ["pointer", "double_right"],  # 두 칸 앞으로
	"strong":     ["pointer", "chevron_up"],    # 피해가 올라간다
	"wide":       ["pointer", "ellipsis"],      # 옆으로 넓어진다
	"quick":      ["glyph", "hourglass"],       # 쉬는 시간을 만들지 않는다
	"first_hit":  ["pointer", "caret"],         # 처음 밟는 칸
	"twin_cast":  ["pointer", "double_left"],   # 앞 칸도 같이
	"trade_skip": ["pointer", "pointer_right"], # 두 번 치고 다음 칸을 건너뛴다
	"finisher":   ["glyph", "cross"],           # 쓰러뜨리면 한 번 더
	# 레일 각인 5종
	"rail_fast":  ["pointer", "chevron_right"], # 빨리 감기
	"rail_power": ["glyph", "star"],            # 모두 힘주기
	"rail_rest":  ["glyph", "minus"],           # 쉬는 시간이 줄어든다
	"rail_color": ["glyph", "gem"],             # 같은 색이 붙으면
	"rail_loop":  ["pointer", "chevron_left"]   # 되돌이
}

## 각인 글리프 한 장. 시트가 둘이라 이름만으로는 못 고른다 — 표가 시트까지 정한다.
## 미지 id(폐기 각인이 저장에서 되살아난 경우)는 `bullet` 하나로 떨어진다.
func _rune_glyph(parent: Control, at: Vector2, rune_id: String, tint: Color,
		box: float = 12.0) -> TextureRect:
	var entry: Array = RUNE_GLYPH.get(rune_id, ["pointer", "bullet"])
	if String(entry[0]) == "glyph":
		return _kit_glyph(parent, at, String(entry[1]), tint, box)
	return _kit_pointer(parent, at, String(entry[1]), tint, box)

# -----------------------------------------------------------------------------
# 사이클 시그널 → 1회성 강조
# -----------------------------------------------------------------------------
# 컨트롤러가 아니라 HUD 쪽에서 지연 연결한다. _begin_run / _reset_player_cycle 은
# W4·W6 구역이라 손대지 않고, 매 프레임 "지금 붙은 컨트롤러가 바뀌었나"만 본다.
func _bind_rail_signals() -> void:
	if rail_bound_cycle == player_cycle:
		return
	rail_bound_cycle = player_cycle
	rail_pending_flow.clear()
	rail_flow_flash = 0.0
	rail_overload_flash = 0.0
	if not is_instance_valid(player_cycle):
		return
	if not player_cycle.slot_entered.is_connected(_on_rail_slot_entered):
		player_cycle.slot_entered.connect(_on_rail_slot_entered)
	if not player_cycle.rune_fired.is_connected(_on_rail_rune_fired):
		player_cycle.rune_fired.connect(_on_rail_rune_fired)
	if not player_cycle.overloaded.is_connected(_on_rail_overloaded):
		player_cycle.overloaded.connect(_on_rail_overloaded)

# 흐름 각인은 **다음 스텝**의 바늘 위치를 바꾼다. 그래서 여기서는 예약만 하고,
# 실제 문구는 바늘이 옮겨간 순간(_on_rail_slot_entered)에 확정한다.
func _on_rail_rune_fired(rune_id: String, slot_index: int) -> void:
	var kind := String(RAIL_FLOW_KIND.get(rune_id, ""))
	if kind.is_empty():
		_flash_rail_slot(slot_index, GamePalette.YELLOW)
		return
	rail_pending_flow = {"kind": kind, "rune": rune_id, "from": slot_index}
	_flash_rail_slot(slot_index, _rail_kind_color(kind))

func _on_rail_slot_entered(index: int, reentry: int) -> void:
	if not rail_pending_flow.is_empty():
		var kind := String(rail_pending_flow.get("kind", ""))
		var from_slot := int(rail_pending_flow.get("from", index))
		var rune_name := String((RuneEngine.RUNES.get(String(rail_pending_flow.get("rune", "")), {}) as Dictionary).get("name", "흐름"))
		var label := _rail_kind_label(kind) if rune_name == _rail_kind_label(kind) else "%s · %s" % [_rail_kind_label(kind), rune_name]
		_raise_flow_banner(kind, "%s   칸 %d → 칸 %d" % [label, from_slot + 1, index + 1])
		_flash_rail_slot(index, _rail_kind_color(kind))
		rail_pending_flow.clear()
	elif reentry > 0:
		_raise_flow_banner("again", "재실행 · %d번 칸을 %d번째로" % [index + 1, reentry + 1])
		_flash_rail_slot(index, _rail_kind_color("again"))

func _on_rail_overloaded() -> void:
	rail_overload_flash = RAIL_FLOW_FLASH_TIME
	_raise_flow_banner("back", "한 바퀴 최대치 · 바늘이 멈췄습니다")
	for index in rail_slot_flash.size():
		_flash_rail_slot(index, GamePalette.RED)

func _rail_kind_color(kind: String) -> Color:
	if kind == "back":
		return GamePalette.CYAN
	if kind == "jump":
		return GamePalette.GREEN
	if kind == "again":
		return GamePalette.ORANGE
	return GamePalette.YELLOW

func _rail_kind_label(kind: String) -> String:
	if kind == "back":
		return "회귀"
	if kind == "jump":
		return "도약"
	if kind == "again":
		return "재실행"
	return "흐름"

func _rail_flow_color() -> Color:
	if not is_instance_valid(rail_flow_banner):
		return GamePalette.YELLOW
	return _rail_kind_color(String(rail_flow_banner.get_meta("kind", "")))

func _raise_flow_banner(kind: String, text: String) -> void:
	if not is_instance_valid(rail_flow_banner):
		return
	rail_flow_flash = RAIL_FLOW_FLASH_TIME
	rail_flow_banner.text = text
	rail_flow_banner.set_meta("kind", kind)
	rail_flow_banner.add_theme_color_override("font_color", _rail_kind_color(kind))
	rail_flow_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	rail_flow_banner.visible = true

func _flash_rail_slot(index: int, color: Color) -> void:
	if index < 0 or index >= rail_slot_flash.size():
		return
	rail_slot_flash[index] = 1.0
	rail_slot_flash_color[index] = color

# 감쇠는 전부 여기 한 곳. Tween을 만들지 않으므로 모달·일시정지에서 새는 트윈이 없다.
func _decay_rail_flashes(delta: float) -> void:
	for index in rail_slot_flash.size():
		if rail_slot_flash[index] > 0.0:
			rail_slot_flash[index] = maxf(0.0, rail_slot_flash[index] - delta / RAIL_FLASH_TIME)
	if rail_flow_flash > 0.0:
		rail_flow_flash = maxf(0.0, rail_flow_flash - delta)
		if is_instance_valid(rail_flow_banner):
			rail_flow_banner.modulate = Color(1.0, 1.0, 1.0, clampf(rail_flow_flash / 0.3, 0.0, 1.0))
	if rail_overload_flash > 0.0:
		rail_overload_flash = maxf(0.0, rail_overload_flash - delta)
	for index in ghost_slot_flash.size():
		if ghost_slot_flash[index] > 0.0:
			ghost_slot_flash[index] = maxf(0.0, ghost_slot_flash[index] - delta / GHOST_FLASH_TIME)

# =============================================================================
# U2 — v3 재스킨 공통 부품 (ui-style-v3 §7 모달 골격 · §6 카드 · §4 패널 3단)
# =============================================================================
# U1이 로비·온보딩에서 굳힌 `_kit_ribbon/_kit_panel/_kit_label/_kit_button/
# _kit_keycap/_kit_glyph`(4100행대)를 그대로 쓰고, 모달·편집 쪽에만 필요한 부품
# 다섯 개를 여기에 더한다. 이 블록 아래의 모달·편집 화면은 `_panel_style()`
# (v1 StyleBoxFlat)을 **한 번도 부르지 않는다** — 남은 호출부는 필드 HUD뿐이었다.
# **U3(2026-08-09)가 그 12곳까지 킷으로 옮기고 `_panel_style()`을 삭제했다.**
# 이제 `StyleBoxFlat.new()`는 프로젝트 전체에서 0건이다.
#
# 정보 구조는 한 글자도 안 바꾼다. 바뀌는 것은 프레임·톤·기하뿐이다.
const KIT_SCRIM_MODAL := 0.62      # §7-5 표준 스크림 (필드가 비쳐야 하는 모달)
const KIT_SCRIM_DEEP := 0.82       # 필드를 지우는 전면 화면(결과·프리뷰·트로피)
const KIT_RIBBON_OVERHANG := 10.0  # U1이 확정한 리본 걸침(§7-3)
const KIT_RIBBON_MIN_W := 320.0

## 스크림 한 장. 색은 킷 스포트라이트 잉크라 U3 길잡이가 겹쳐도 색이 안 튄다(§7-5).
func _kit_scrim(parent: Control, alpha: float = KIT_SCRIM_MODAL) -> ColorRect:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(UIKit.SPOTLIGHT_INK, clampf(alpha, 0.0, 1.0))
	parent.add_child(scrim)
	return scrim

## 모달 껍데기 1장 + 헤더 리본. 리본은 껍데기가 아니라 **껍데기의 부모**에 붙여야
## V홈이 밖으로 나와 리본으로 읽힌다(§7-3 · handoff-u1 §5.2).
## 반환값은 껍데기다. `_animate_modal()`이 meta로 리본을 같이 끌고 간다.
func _kit_shell(parent: Control, rect: Rect2, title: String,
		tone: UIKit.Tone = UIKit.Tone.SLATE,
		ribbon_tone: UIKit.Tone = UIKit.Tone.WOOD,
		ribbon_width: float = 0.0) -> Panel:
	var shell := Panel.new()
	shell.position = rect.position
	shell.size = rect.size
	UIKit.style_panel(shell, tone, UIKit.Role.PANEL)
	parent.add_child(shell)
	if title.is_empty():
		return shell
	# =========================================================================
	# Y4 — 리본 폭을 제목 길이에 맞춘다 (피드백 ⑤ · FEEDBACK_Y §8 ⑤ "모달 전체 톤")
	# =========================================================================
	# 구판은 호출부 20곳이 저마다 360 / 400 / 420 / 520 / 560을 손으로 넘겼고,
	# 그 숫자는 제목 길이와 아무 관계가 없었다 — 「봉인 해제」(4글자)가 360px 리본
	# 한가운데에 떠 있고 양옆으로 빈 나무판이 130px씩 남는다. 판이 클수록 무거워
	# 보이는데 그 무게가 아무 정보도 안 나른다.
	# 이제 **글자에 맞춘 폭이 진실**이고 호출부가 넘긴 값은 **상한**으로만 쓴다.
	# 상한으로 두는 이유: 어느 모달도 예전보다 넓어지지 않으므로 껍데기 밖으로
	# 삐져나가는 회귀가 구조적으로 불가능하다(피드백 ⑦ 경계 검사와 같은 방향).
	var cap := rect.size.x - 120.0
	if ribbon_width > 0.0:
		cap = minf(cap, ribbon_width)
	var width := clampf(float(title.length()) * 24.0 + 140.0, KIT_RIBBON_MIN_W, maxf(cap, KIT_RIBBON_MIN_W))
	var ribbon := _kit_ribbon(parent, Rect2(
		rect.position + Vector2((rect.size.x - width) * 0.5, -KIT_RIBBON_OVERHANG),
		Vector2(width, UIKit.RIBBON_H)), title, ribbon_tone)
	shell.set_meta("kit_ribbon", ribbon)
	return shell

## 킷 카드 프레임을 버튼 5상태에 한 번에 입힌다(§6). 상태는 색이 아니라 **기하**로
## 갈린다 — 융기(보통) · 흰 이중 링(선택) · 함몰(비활성).
func _kit_card_skin(button: Button, kind: int, state: int = 0) -> void:
	button.set_meta("kit_card_kind", kind)
	var box := _kit_card_box(kind, state)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", _kit_card_box(kind, 1) if state == 0 else box)
	button.add_theme_stylebox_override("pressed", _kit_card_box(kind, 1))
	button.add_theme_stylebox_override("focus", UIKit.focus_box())
	button.add_theme_stylebox_override("disabled", _kit_card_box(kind, 2))

## enum 인자는 GDScript에서 int로 캐스팅할 수 없어(`as`는 클래스 전용) 여기서 푼다.
## 값 순서는 `UIKit.Card` / `UIKit.CardState`와 1:1이다(ui-style-v3 §13 "짝을 같이 고칠 것").
func _kit_card_box(kind: int, state: int) -> StyleBoxTexture:
	var card_kind := UIKit.Card.SKILL
	match kind:
		1: card_kind = UIKit.Card.ITEM
		2: card_kind = UIKit.Card.RUNE
		3: card_kind = UIKit.Card.TROPHY
		4: card_kind = UIKit.Card.BOSS
	var card_state := UIKit.CardState.NORMAL
	match state:
		1: card_state = UIKit.CardState.SELECTED
		2: card_state = UIKit.CardState.DISABLED
	return UIKit.card_box(card_kind, card_state)

## X1 — 카드 프레임에 **원소 의미색**을 입힌 변종. 프레임 자체가 속성을 말한다.
##
## ⚠️ `UIKit.card_box()`는 **한 벌만 구워 전 화면이 공유하는** 리소스다(ui-style-v3 §13).
##    거기에 `modulate_color`를 그대로 박으면 편집 화면·상점·트로피 카드까지 전부
##    같이 물든다. 반드시 `UIKit.variant()`로 복제본을 떠서 칠한다. 복제 비용이
##    포커스 이동마다 붙지 않도록 (종류·상태·색) 3키 캐시를 둔다.
var _tinted_card_cache: Dictionary = {}

func _kit_card_box_tinted(kind: int, state: int, tint: Color) -> StyleBoxTexture:
	var key := "%d_%d_%s" % [kind, state, tint.to_html(false)]
	if _tinted_card_cache.has(key):
		return _tinted_card_cache[key]
	var box := UIKit.variant(_kit_card_box(kind, state)) as StyleBoxTexture
	box.modulate_color = tint
	_tinted_card_cache[key] = box
	return box

## 킷 카드 프레임 + 원소 틴트를 한 번에. 틴트는 meta로 남겨 두어야
## `_refresh_choice_highlight()`가 포커스를 옮길 때 색을 잃지 않는다.
func _kit_card_skin_tinted(button: Button, kind: int, tint: Color) -> void:
	button.set_meta("kit_card_kind", kind)
	button.set_meta("kit_card_tint", tint)
	button.add_theme_stylebox_override("normal", _kit_card_box_tinted(kind, 0, tint))
	button.add_theme_stylebox_override("hover", _kit_card_box_tinted(kind, 1, tint))
	button.add_theme_stylebox_override("pressed", _kit_card_box_tinted(kind, 1, tint))
	button.add_theme_stylebox_override("focus", UIKit.focus_box())
	button.add_theme_stylebox_override("disabled", _kit_card_box_tinted(kind, 2, tint))

func _kit_button_box(variant: int, state: int) -> StyleBoxTexture:
	var btn := UIKit.Btn.PRIMARY
	match variant:
		1: btn = UIKit.Btn.NEUTRAL
		2: btn = UIKit.Btn.DANGER
		3: btn = UIKit.Btn.QUIET
	var btn_state := UIKit.BtnState.NORMAL
	match state:
		1: btn_state = UIKit.BtnState.HOVER
		2: btn_state = UIKit.BtnState.PRESSED
		3: btn_state = UIKit.BtnState.DISABLED
	return UIKit.button_box(btn, btn_state)

## v1 의미색 → 킷 버튼 변종. `_button()`이 전 화면에서 색으로 성격을 말해 왔으므로
## 그 색을 그대로 읽어 변종을 고른다(호출부를 60군데 고치지 않기 위한 다리다).
func _kit_btn_variant(color: Color) -> int:
	if color.is_equal_approx(GamePalette.RED) or color.is_equal_approx(GamePalette.MAGENTA) \
			or color.is_equal_approx(GamePalette.PURPLE):
		return 2   # DANGER (EMBER)
	if color.is_equal_approx(GamePalette.MUTED) or color.is_equal_approx(GamePalette.CYAN) \
			or color.is_equal_approx(GamePalette.BLUE) or color.is_equal_approx(GamePalette.NIGHT) \
			or color.is_equal_approx(GamePalette.STONE) or color.is_equal_approx(GamePalette.STONE_DARK) \
			or color.is_equal_approx(GamePalette.STONE_LIGHT):
		return 1   # NEUTRAL (SLATE)
	return 0       # PRIMARY (WOOD) — YELLOW · ORANGE · GREEN · 카드색

## 흰 포커스 링 한 겹. 카드·칸 위에 **별개 층**으로 얹는다(handoff-u1 §2.2의 규약).
func _kit_focus_ring(parent: Control, rect: Rect2) -> Panel:
	var ring := Panel.new()
	ring.position = rect.position
	ring.size = rect.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", UIKit.focus_box())
	parent.add_child(ring)
	return ring

# -----------------------------------------------------------------------------
# 딜싸이클 공장 UI
# -----------------------------------------------------------------------------
# 전체 레일은 항상 최대 10칸 자리를 그립니다. 건설된 칸만 색이 채워지고
# 나머지는 무채색 자리표시자로 남아 앞으로 몇 칸을 더 열 수 있는지 보여줍니다.
# 모든 셀은 같은 높이(FACTORY_RAIL_ROW_H)를 쓰고 다리는 카드 세로 중앙선
# (FACTORY_RAIL_LINE_Y)에 인라인으로 놓여 레일이 한 줄로 이어져 보입니다.
const FACTORY_RAIL_CARD_W := 200.0
const FACTORY_RAIL_CARD_INSET := 5.0
# v2: 5칸이 한눈에 들어와야 한다(설계 §6.1). 200×5 + 34×4 = 1,136px 로 레일 뷰포트
# (1,160px)·마왕 프리뷰(1,140px)·결과 화면(1,176px) 어디서도 가로 스크롤이 걸리지 않는다.
const FACTORY_RAIL_BRIDGE_W := 34.0
const FACTORY_RAIL_SPINE_BUILT := Color("46707f")
const FACTORY_RAIL_SPINE_GHOST := Color("242b37")
const FACTORY_RAIL_HEADER_TOP := 4.0
const FACTORY_RAIL_HEADER_H := 26.0
const FACTORY_RAIL_LANE_TOP := 34.0
const FACTORY_RAIL_LANE_AREA := 266.0
const FACTORY_RAIL_LANE_GAP := 8.0
const FACTORY_RAIL_ROW_H := 302.0
const FACTORY_RAIL_LINE_Y := 167.0
const FACTORY_RAIL_PANEL_TOP := 173.0
const FACTORY_RAIL_PANEL_H := 342.0
# 공장 레일 카드 = 선택 모달·요약에서 재사용하는 표준 카드 블록 크기 (3차 피드백 ⑳).
const FACTORY_CARD_BLOCK_SIZE := Vector2(FACTORY_RAIL_CARD_W - FACTORY_RAIL_CARD_INSET * 2.0, 142.0)
# 다리 스프라이트를 스파인 위에 얹을 때 쓰는 사각형. 아틀라스 프레임을 벗긴 뒤의
# 실제 다리 비율(약 2:1)에 맞춘 크기라 세로로 눌리지 않습니다 (3차 피드백 ⑫).
const FACTORY_RAIL_BRIDGE_SPRITE := Vector2(30.0, 16.0)

# =============================================================================
# W6 → X2: ESC 편집 화면 — 5칸 무스크롤 레일 + 흐름 아크 + 드래그 한 갈래
# =============================================================================
# 가로 증명(X2도 한 픽셀 안 바꿨다): 카드 196 × 5 + 커넥터 44 × 4 = 1,156px.
#   패널 1,240px 안에서 좌우 여백 42px. 레일에 ScrollContainer를 **아예 만들지 않으므로**
#   가로 스크롤이 구조적으로 불가능하다.
# 세로 증명(패널 로컬): 리본 −10~30 / 요약 36~72 / 흐름 아크 76~130 /
#   레일 134~338 / 결속 342~352 / 보관함·장비 360~604 / 닫기 614~668 ⊂ 688.
#
# 위 좌표는 `_run_v4_test`의 `edit_layout` 플래그가 자동 검증한다(겹침·초과 0).
const EDIT_PANEL_RECT := Rect2(20.0, 16.0, 1240.0, 688.0)
const EDIT_CONNECTOR_W := 44.0
const EDIT_RAIL_PITCH := 240.0                     # 196 + 44
const EDIT_RAIL_CONTENT_W := 1156.0                # 196×5 + 44×4
const EDIT_RAIL_ORIGIN := Vector2(42.0, 134.0)
const EDIT_ARC_RECT := Rect2(42.0, 76.0, 1156.0, 54.0)
const EDIT_SUMMARY_RECT := Rect2(392.0, 36.0, 496.0, 36.0)
const EDIT_HELP_RECT := Rect2(1148.0, 36.0, 36.0, 36.0)
const EDIT_BOND_RECT := Rect2(42.0, 342.0, 1156.0, 8.0)
# 되돌이 선 — "5번 칸을 지나면 1번으로 돌아온다". 한 바퀴를 말하는 유일한 그림이다.
const EDIT_LOOP_RECT := Rect2(42.0, 356.0, 1156.0, 16.0)
const EDIT_INVENTORY_RECT := Rect2(28.0, 380.0, 820.0, 224.0)
const EDIT_EQUIP_RECT := Rect2(860.0, 380.0, 352.0, 224.0)
const EDIT_CLOSE_RECT := Rect2(998.0, 614.0, 214.0, 54.0)

# ⚠️ 아래 다섯 상수는 **읽기 전용 레일**(`_build_preview_slot` — 마왕 프리뷰·결과 화면,
#    W10 소유)이 같이 쓴다. X2는 편집 화면만 고치므로 값을 건드리지 않고, 편집 전용
#    기하는 `EDIT_SLOT_*`(아래 블록)로 따로 뒀다. 둘을 합치면 프리뷰가 같이 늘어난다.
const EDIT_CARD_SIZE := Vector2(196.0, 150.0)
const EDIT_SLOT_HEADER_H := 20.0
const EDIT_SLOT_PAD := 18.0
const EDIT_SLOT_CARD_RECT := Rect2(18.0, 38.0, 160.0, 78.0)
const EDIT_SLOT_RUNE_Y := 118.0

# --- X2: 편집 화면 칸 기하 ----------------------------------------------------
# 칸이 150 → 204로 자랐다. 늘어난 54px는 **전부 그림 몫**이다 — 아이콘 44 → 80
# (면적 3.3배) + 칸 손잡이 띠 28px. 글자는 오히려 칸당 4줄 → 1줄(카드 이름)로 줄었다.
# 칸(196×204)이 카드 프레임(9-slice 여백 16)을 쓰므로 안쪽 가용은 x·y 16~180 / 16~188.
#   손잡이 띠 14~42 · 카드 몸통 46~158 · 지속/RELOAD 막대 162~172 · 각인 핍 174~186
const EDIT_SLOT_SIZE := Vector2(196.0, 204.0)
const EDIT_SLOT_HANDLE_RECT := Rect2(14.0, 14.0, 168.0, 28.0)
const EDIT_SLOT_BODY_RECT := Rect2(14.0, 46.0, 168.0, 112.0)
const EDIT_SLOT_METER_Y := 162.0
const EDIT_SLOT_PIP_Y := 174.0
const EDIT_SLOT_ICON := 80.0
const EDIT_INV_TILE := Vector2(88.0, 88.0)
const EDIT_INV_COLUMNS := 8           # 8×88 + 7×8 = 760 ⊂ 보관함 안쪽 796
const EDIT_INV_MIN_TILES := 16        # 빈 자리도 **자리표시 타일**로 깐다(빈 상태 문장 대체)
const EDIT_EQUIP_TILE := Vector2(160.0, 88.0)
## ⚠️ **Y4가 `EDIT_EQUIP_GLYPH`를 삭제했다.** 그 표는 킷 글리프 4종
## (`diamond / gem / coin / key`)을 부위 4종에 빌려 붙인 것이었고, 유저 피드백 ⑳이
## 정확히 그 대응을 지목했다 — 「열쇠 = 팔찌」는 안 읽힌다. 이제 부위 그림은
## `_equip_part_art()` 하나가 낸다(`ui-slot-silhouettes` 실루엣 / `ui-slot-badges` 배지).

# 부록 C-1의 두 조작. 이 문자열이 "지금 무엇을 집는가"의 단일 진실 원천이다.
# X2에서 **모드는 사라졌고 제스처만 남았다** — 무엇을 집었는지가 조작을 정한다:
#   카드 몸통을 집으면 "card"(각인은 칸에 남는다) / 칸 손잡이를 집으면 "slot"(각인 동반).
# `factory_edit_mode`는 이제 화면 상태가 아니라 **키보드 집기의 제스처**만 기억한다.
const EDIT_MODE_CARD := "card"
const EDIT_MODE_SLOT := "slot"

# 흐름 아크로 그릴 각인과 그 **바늘이 실제로 도착하는 칸의 오프셋**. 0 = 제자리(고리).
# ⚠️ 이 표의 단위는 `RuneEngine.FLOW_DELTA`와 다르다. 엔진은 `move = 1 + delta`이므로
#    delta를 그대로 쓰면 아크가 한 칸씩 어긋난다. 변환은 `착지 = move = 1 + delta`다:
#      back_one  delta −2 → move −1 → **−1칸**(바로 앞 칸)
#      jump_one  delta +1 → move +2 → **+2칸**(다음 칸을 건너뛴다)
#    앙코르 3종(twice · trade_skip · finisher)은 같은 칸을 한 번 더 밟으므로 0(고리)이다.
const EDIT_ARC_RUNES: Dictionary = {
	"back_one": -1, "jump_one": 2,
	"twice": 0, "trade_skip": 0, "finisher": 0
}
const EDIT_ARC_MAX := 6

# 미리보기 표본 수. 설계 §8.2는 "실시간 몬테카를로 200회"였다. 실측 결과는
# handoff-w6 §미리보기 성능에 있다 — 편집 확정 시 1회 계산 방식으로 96 표본을 채택했다.
const EDIT_PREVIEW_SAMPLES := 96
const EDIT_PREVIEW_TRACES := 3

# 흐름 아크 오버레이 (§8.2). 각인이 만드는 바늘 이동을 카드 위 아치로 그린다.
# 설계는 `draw_arc`를 지목했지만 draw_arc는 **정원**만 그린다 — 60px 밴드에 240px
# 스팬(2칸 이동)을 담으려면 반지름 240이 필요해 화면 밖으로 나간다. 같은 그림을
# 납작한 아치(polyline)로 그리고, 제자리 각인(재실행 고리)만 draw_arc를 쓴다.
class FlowArcOverlay:
	extends Control

	var arcs: Array = []

	func _draw() -> void:
		for entry in arcs:
			var arc: Dictionary = entry
			var color: Color = arc.get("color", Color.WHITE)
			var x1 := float(arc.get("x1", 0.0))
			var x2 := float(arc.get("x2", 0.0))
			var base := float(arc.get("base", size.y))
			var height := maxf(8.0, float(arc.get("height", 24.0)))
			if bool(arc.get("loop", false)):
				var center := Vector2(x1, base - height)
				var radius := height * 0.42
				draw_arc(center, radius, 0.0, TAU, 24, color, 2.0)
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(radius + 4.0, 0.0),
					center + Vector2(radius - 4.0, -5.0),
					center + Vector2(radius - 4.0, 5.0)
				]), color)
				continue
			var points := PackedVector2Array()
			for step in 25:
				var t := float(step) / 24.0
				points.append(Vector2(lerpf(x1, x2, t), base - height * sin(PI * t)))
			draw_polyline(points, color, 2.0, true)
			var tip := points[points.size() - 1]
			var before := points[points.size() - 3]
			var forward := (tip - before).normalized()
			var side := Vector2(-forward.y, forward.x)
			draw_colored_polygon(PackedVector2Array([
				tip, tip - forward * 11.0 + side * 5.0, tip - forward * 11.0 - side * 5.0
			]), color)

## 두 제스처의 색 언어. 카드 = 청록(HUD의 "카드" 색) / 칸 = 자주(각인 희귀도 epic 색).
## X2에서 모드 UI는 사라졌지만 이 색은 **집은 것을 알리는 배너**가 그대로 쓴다.
func _edit_mode_color(mode: String) -> Color:
	return GamePalette.MAGENTA if mode == EDIT_MODE_SLOT else GamePalette.CYAN

# -----------------------------------------------------------------------------
# 미리보기 — RuneEngine.simulate_cycle 을 W2 런타임과 **공유**한다 (handoff-w1 §3.6)
# -----------------------------------------------------------------------------
# 자체 근사식을 쓰면 미리보기와 실제 궤적이 어긋난다. 여기서는 같은 순수 함수를
# 표본 수만큼 돌리고 요약만 만든다. 덱 지문이 같으면 다시 돌지 않는다(포커스 이동 등).
func _factory_deck_signature() -> String:
	if factory == null:
		return ""
	var parts: Array[String] = []
	for slot_index in factory.slots.size():
		var slot: Dictionary = factory.slots[slot_index]
		var card: Dictionary = slot.get("card", {})
		var rune_parts: Array[String] = []
		for rune_value in (slot.get("runes", []) as Array):
			var rune: Dictionary = rune_value
			rune_parts.append("%s@%.3f" % [String(rune.get("id", "")), float(rune.get("p", 0.0))])
		parts.append("%s/R%d/%s/%.3f" % [
			String(card.get("id", "-")), int(card.get("rank", 0)),
			",".join(rune_parts), float(slot.get("duration_mul", 1.0))
		])
	for item: Dictionary in factory.equipment:
		parts.append("E:%s" % String(item.get("id", "")))
	# Y2: 레일 각인은 덱이 아니라 레일이 소유하므로 위 루프에 안 잡힌다. 지문에 안 넣으면
	# 레일 각인을 붙여도 지문이 그대로라 미리보기가 **캐시에 걸려 갱신되지 않는다.**
	for rail_inst: Dictionary in factory.rail_runes:
		parts.append("L:%s@%.3f" % [String(rail_inst.get("id", "")), float(rail_inst.get("p", 0.0))])
	return "|".join(parts)

func _refresh_factory_preview(force: bool = false) -> void:
	if factory == null:
		factory_preview = {}
		return
	var signature := _factory_deck_signature()
	if not force and String(factory_preview.get("signature", "")) == signature:
		return
	# ★ Y2 수리 ①-b: 미리보기에도 레일 각인을 넘긴다. 런타임(`_plan_cycle`)과 **같은
	#    opts**여야 "미리보기 = 실전"이 성립한다(handoff-y1 §9-A `game.gd:2717`).
	factory_preview = _factory_preview_summary(factory.rune_deck(), run_cycle_seed + 104729,
		EDIT_PREVIEW_SAMPLES, factory.rune_opts())
	factory_preview["signature"] = signature

# W10: 선택 인자 `opts`는 마왕 프리뷰가 같은 요약기로 `reload_scale: 0.6`을 반영하기 위한 것이다.
# 기본값 {}이라 편집 화면 호출부는 무변경이다.
func _factory_preview_summary(deck: Array, preview_seed: int, samples: int, opts: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	var count := maxi(1, samples)
	var steps_sum := 0.0
	var damage_sum := 0.0
	var reload_sum := 0.0
	var exec_slots_sum := 0.0
	var time_sum := 0.0
	var overload := 0
	# Y2: 구 「과열 분포」(0~8단) 자리를 **한 바퀴 스텝 분포**(0~2n)가 이어받는다.
	# 이제 이 히스토그램이 "내 덱이 몇 스텝짜리 바퀴를 도는가"를 그대로 보여 준다.
	var histogram: Array[int] = []
	for _bucket in RuneEngine.STEP_CAP + 1:
		histogram.append(0)
	var traces: Array[String] = []
	for index in count:
		var cycle := RuneEngine.simulate_cycle(deck, preview_seed + index * 7919, opts)
		steps_sum += float(cycle["step_count"])
		damage_sum += float(cycle["damage_total"])
		reload_sum += float(cycle["reload"])
		histogram[clampi(int(cycle["step_count"]), 0, RuneEngine.STEP_CAP)] += 1
		for used in (cycle["slot_exec"] as Array):
			if int(used) > 0:
				exec_slots_sum += 1.0
		var duration := 0.0
		for step_value in (cycle["steps"] as Array):
			duration += float((step_value as Dictionary).get("duration", 0.0))
		time_sum += duration + float(cycle["reload"])
		if bool(cycle["overloaded"]):
			overload += 1
		if traces.size() < EDIT_PREVIEW_TRACES:
			var parts: Array[String] = []
			for visited in (cycle["visited"] as Array):
				parts.append("%d" % (int(visited) + 1))
			traces.append("→".join(parts))
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	factory_preview_ms = elapsed
	return {
		"samples": count,
		"mean_steps": steps_sum / float(count),
		"mean_damage": damage_sum / float(count),
		"mean_reload": reload_sum / float(count),
		"mean_exec_slots": exec_slots_sum / float(count),
		"mean_time": time_sum / float(count),
		"overload_rate": float(overload) / float(count),
		"step_histogram": histogram,
		"traces": traces,
		"ms": elapsed
	}

# 한 칸에서 그 각인이 실제로 터질 확률(중복 합성 + 과밀 페널티 반영, P_CAP 클램프).
# handoff-w1 §8 "각인 툴팁의 실효 확률" 공식 그대로다.
# W10: 선택 인자 `deck`은 마왕 프리뷰가 같은 공식을 boss_factory에 쓰기 위한 것이다
# (handoff-w6 §8 "factory 대신 boss_factory를 받도록 인자 1개만 열면 된다").
# 기본값이 null이라 기존 호출부는 한 곳도 바뀌지 않는다.
func _slot_rune_probability(slot_index: int, rune_id: String, deck: FactoryDeck = null) -> float:
	var source: FactoryDeck = deck if deck != null else factory
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	if definition.is_empty() or source == null:
		return 0.0
	if not bool(definition.get("roll", true)):
		return 1.0
	var copies: Array = []
	for rune_value in source.runes_on(slot_index):
		var rune: Dictionary = rune_value
		if String(rune.get("id", "")) == rune_id:
			copies.append(rune)
	if copies.is_empty():
		return 0.0
	return RuneEngine.effective_probability(
		RuneEngine.merged_probability(copies), 0.0,
		RuneEngine.congestion_scale(source.rune_count_on(slot_index)))

# -----------------------------------------------------------------------------
# 편집 화면 조립
# -----------------------------------------------------------------------------
## X2 — 사용자 원문: "텍스트가 너무 많아. 훨씬 더 간단하게. 필요한 정보는 최대한
## 마우스 호버로. ESC를 눌렀을 때 이게 어떤 구조인지 중학생이 봐도 알아차릴 수 있어야."
##
## 화면에 남는 것은 **일곱 개**뿐이다:
##   ① 제목 리본 「딜싸이클」 ② 5칸 레일(아이콘 크게 + 원소색) ③ 바늘 화살표·흐름 아크
##   ④ 보관함 격자(그림만) ⑤ 장비 4부위(글리프만) ⑥ 한 바퀴 요약 1줄 ⑦ 닫기
## 나머지 문장은 **하나도 지우지 않고** `UIKit` 툴팁 층(ui_kit §6)으로 옮겼다.
## 지운 것은 정보가 아니라 "정보가 상시로 화면을 차지하던 자리"다.
func _build_deck_editor() -> void:
	var already_open := factory_editor_open
	state = "factory_menu"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "DeckEditor"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 필드 위에 뜨는 편집 화면 = SLATE 껍데기 + WOOD 리본(§7-1 · §7-2).
	# 제목은 네 글자다. "편집 · 5칸 레일"은 화면 자체가 이미 말한다.
	var panel := _kit_shell(overlay, EDIT_PANEL_RECT, "딜싸이클",
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 360.0)
	panel.name = "EditorPanel"
	factory_tooltip_layer = null
	factory_tooltip_targets.clear()
	_refresh_factory_preview()
	_build_edit_summary(panel)
	_build_edit_rail(panel)
	_build_edit_bond_band(panel)
	_build_edit_inventory(panel)
	_build_edit_equipment(panel)
	_build_edit_close(panel)
	# 툴팁 층은 **가장 마지막**에 붙는다. 먼저 붙이면 카드·칸이 툴팁을 덮는다.
	factory_tooltip_layer = UIKit.make_tooltip_layer(overlay)
	_bind_edit_tooltips()
	factory_editor_open = true
	# 화면 안에서 일어난 갱신(배치·교환)까지 매번 슬라이드 인 하면 눈이 아프다.
	# 처음 열 때만 등장 연출을 준다. 루프 트윈은 여전히 하나도 없다.
	if not already_open:
		_animate_modal(panel, Vector2(0.0, 16.0))
	_clamp_factory_focus()
	_update_factory_focus()

## 툴팁 내용을 대상에 매달고 키로 기억해 둔다. 배선(마우스 시그널)은 층이 생긴 뒤
## `_bind_edit_tooltips()`가 한 번에 한다 — 층은 화면 맨 위에 있어야 해서 맨 나중에 생긴다.
func _edit_tip(target: Control, key: String, spec: Dictionary) -> void:
	if target == null:
		return
	target.set_meta(UIKit.TOOLTIP_META, spec)
	factory_tooltip_targets[key] = target

func _bind_edit_tooltips() -> void:
	if factory_tooltip_layer == null:
		return
	for key_value in factory_tooltip_targets:
		var target: Variant = factory_tooltip_targets[key_value]
		if not (target is Control) or not is_instance_valid(target):
			continue
		var control: Control = target
		# handoff-u2 §5.3 #1: 이 빌드의 `get_meta(name, default)`는 기본값을 줘도
		# ERROR 줄을 찍는다. 반드시 `has_meta`로 먼저 거른다.
		if control.has_meta(UIKit.TOOLTIP_META):
			UIKit.attach_tooltip(control, factory_tooltip_layer, control.get_meta(UIKit.TOOLTIP_META))

## 캡처 전용 — 호버 상태를 그림으로 남기는 유일한 방법이다(QA는 마우스를 못 움직인다).
## 키는 `factory_tooltip_targets`의 것: help / summary / bond / inventory / inventory_empty /
## slot{N}_handle / slot{N}_card / slot{N}_runes / arc{N} / equip{N} / close.
func _force_factory_tooltip(key: String) -> bool:
	if factory_tooltip_layer == null or not factory_tooltip_targets.has(key):
		return false
	var target: Variant = factory_tooltip_targets[key]
	if not (target is Control) or not is_instance_valid(target):
		return false
	UIKit.tooltip_force(factory_tooltip_layer, target)
	return true

# -----------------------------------------------------------------------------
# Y3 — 모달 공용 호버 툴팁 (편집 화면 층의 모달 판)
# -----------------------------------------------------------------------------
# 편집 화면의 `_edit_tip` / `_bind_edit_tooltips` / `_force_factory_tooltip` 3종과
# **같은 규약**이다. 다른 것은 층의 수명뿐이다 — 이쪽은 `overlay`에 붙으므로
# `_clear_overlay()`가 오버레이를 지울 때 함께 죽는다(별도 정리 코드 0줄).
#
# ⚠️ 층은 반드시 **가장 마지막에** 만든다(UIKit §6). 카드·버튼보다 먼저 붙이면
#    툴팁이 그 아래로 깔려 안 보인다.
func _begin_modal_tooltips() -> void:
	modal_tooltip_layer = null
	modal_tooltip_targets.clear()

## 툴팁 내용을 대상에 매달고 키로 기억한다. 배선은 `_bind_modal_tooltips()`가 한 번에 한다.
func _modal_tip(target: Control, key: String, spec: Dictionary) -> void:
	if target == null:
		return
	target.set_meta(UIKit.TOOLTIP_META, spec)
	modal_tooltip_targets[key] = target

func _bind_modal_tooltips() -> void:
	if not is_instance_valid(overlay):
		return
	modal_tooltip_layer = UIKit.make_tooltip_layer(overlay)
	modal_tooltip_layer.name = "ModalTooltips"
	for key_value in modal_tooltip_targets:
		var target: Variant = modal_tooltip_targets[key_value]
		if not (target is Control) or not is_instance_valid(target):
			continue
		var control: Control = target
		# handoff-u2 §5.3 #1: 이 빌드의 `get_meta(name, default)`는 기본값을 줘도
		# ERROR 줄을 찍는다. `has_meta`로 먼저 거른다.
		if control.has_meta(UIKit.TOOLTIP_META):
			UIKit.attach_tooltip(control, modal_tooltip_layer, control.get_meta(UIKit.TOOLTIP_META))

## 캡처·테스트 전용 강제 표시. 사람이 호버했을 때와 **같은 경로**다.
func _force_modal_tooltip(key: String) -> bool:
	# 층은 오버레이와 함께 죽는다 — 화면을 닫은 뒤에도 참조는 null이 아니라 **무효**다.
	if not is_instance_valid(modal_tooltip_layer) or not modal_tooltip_targets.has(key):
		return false
	var target: Variant = modal_tooltip_targets[key]
	if not (target is Control) or not is_instance_valid(target):
		return false
	UIKit.tooltip_force(modal_tooltip_layer, target)
	return true

## ⑥ 한 바퀴 요약 1줄 + "?" 도움말. 화면에 남는 **유일한 숫자 줄**이다.
## 아이콘 + 숫자만 있고 단어가 없다 — 무슨 숫자인지는 호버가 말한다.
func _build_edit_summary(panel: Control) -> void:
	var chip := _kit_panel(panel, EDIT_SUMMARY_RECT, UIKit.Tone.SLATE, UIKit.Role.CHIP)
	chip.name = "EditSummary"
	var cells := [
		{"glyph": "hourglass", "text": "%.2f초" % float(factory_preview.get("mean_time", 0.0)), "color": GamePalette.CYAN},
		{"glyph": "diamond", "text": "%.2f초" % factory.total_reload(), "color": GamePalette.ORANGE},
		{"glyph": "star", "text": "%.0f" % float(factory_preview.get("mean_damage", 0.0)), "color": GamePalette.YELLOW}
	]
	var cell_w := EDIT_SUMMARY_RECT.size.x / float(cells.size())
	for index in cells.size():
		var cell: Dictionary = cells[index]
		var left := EDIT_SUMMARY_RECT.position.x + float(index) * cell_w
		_kit_glyph(panel, Vector2(left + 20.0, EDIT_SUMMARY_RECT.position.y + 8.0),
			String(cell["glyph"]), cell["color"], 20.0)
		var value := _label(String(cell["text"]), UI_HEADING_SIZE, cell["color"])
		value.position = Vector2(left + 46.0, EDIT_SUMMARY_RECT.position.y + 6.0)
		value.size = Vector2(cell_w - 54.0, 24.0)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(value)
	_edit_tip(chip, "summary", _edit_metrics_tooltip())
	# "?" — 이 화면의 규칙 전부가 여기 한 곳에 있다. 상시 안내문 여섯 줄의 후임이다.
	var help := _kit_panel(panel, EDIT_HELP_RECT, UIKit.Tone.SLATE, UIKit.Role.CHIP)
	help.name = "EditHelp"
	_kit_glyph(help, Vector2(6.0, 6.0), "info", GamePalette.CYAN, 24.0)
	_edit_tip(help, "help", _edit_help_tooltip())

## 상시 노출에서 뺀 몬테카를로 지표 7종이 통째로 여기 있다(계산은 한 줄도 안 바뀌었다).
func _edit_metrics_tooltip() -> Dictionary:
	var samples := maxi(1, int(factory_preview.get("samples", 1)))
	var histogram: Array = factory_preview.get("step_histogram", [])
	var spread: Array[String] = []
	for step in histogram.size():
		var hits := int(histogram[step])
		if hits > 0:
			spread.append("%d스텝 %d%%" % [step, int(round(float(hits) / float(samples) * 100.0))])
	var rows: Array = [
		["한 바퀴", "%.2f초" % float(factory_preview.get("mean_time", 0.0)), GamePalette.CYAN],
		["RELOAD 빚", "%.2f초" % factory.total_reload(), GamePalette.ORANGE],
		["평균 피해", "%.1f" % float(factory_preview.get("mean_damage", 0.0)), GamePalette.YELLOW],
		["평균 스텝", "%.2f / %d" % [float(factory_preview.get("mean_steps", 0.0)),
			RuneEngine.SLOT_EXEC_CAP * FactoryDeck.SLOT_COUNT]],
		["평균 RELOAD", "%.2f초" % float(factory_preview.get("mean_reload", 0.0))],
		["밟은 칸", "%.2f칸" % float(factory_preview.get("mean_exec_slots", 0.0)), GamePalette.MAGENTA],
		["한 바퀴 분포", " · ".join(spread) if not spread.is_empty() else "없음"]
	]
	var traces: Array = factory_preview.get("traces", [])
	for index in mini(traces.size(), EDIT_PREVIEW_TRACES):
		rows.append(["%d번째 굴림" % (index + 1), String(traces[index])])
	return {
		"title": "한 바퀴 예상",
		"accent": GamePalette.CYAN,
		"rows": rows,
		"body": "%d번 굴려 나온 평균입니다 (%.1f ms). 각인은 바퀴마다 다시 굴리므로 실제 값은 이 언저리에서 흔들립니다. 한 칸은 한 바퀴에 두 번까지만 터지므로 스텝은 %d회를 넘지 않습니다." % [samples, float(factory_preview.get("ms", 0.0)), RuneEngine.SLOT_EXEC_CAP * FactoryDeck.SLOT_COUNT]
	}

## 상시 노출에서 뺀 규칙 문장·모드 설명·하단 키 안내 여섯 개가 통째로 여기 있다.
func _edit_help_tooltip() -> Dictionary:
	return {
		"title": "딜싸이클 읽는 법",
		"accent": GamePalette.YELLOW,
		"rows": [
			["레일", "%d칸 고정" % FactoryDeck.SLOT_COUNT],
			["각인", "%d개" % factory.total_rune_count()],
			["장비", "%d/%d" % [factory.equipment.size(), FactoryDeck.EQUIPMENT_PARTS.size()]],
			["보관함", "%d장" % factory.inventory.size()],
			["카드만 옮기기", "카드 그림을 끌기"],
			["칸 통째 옮기기", "칸 위 손잡이를 끌기"],
			["키보드", "TAB 영역 · ←→ 이동 · SPACE 집기"],
			["키보드 · 칸 통째", "SHIFT + SPACE"],
			["닫기", "ESC"]
		],
		"body": "바늘은 1번 칸부터 오른쪽으로 돌고 마지막 칸을 지나면 1번으로 되돌아옵니다. 각인은 카드가 아니라 칸에 붙습니다 — 카드만 끌면 각인은 그 칸에 남고, 손잡이를 끌면 각인까지 함께 갑니다. 빈칸은 기본 베기를 씁니다. 아이템은 레일이 아니라 장비 4부위에만 들어갑니다."
	}

## 드롭 판정 한 곳. `_on_factory_card_dropped`의 분기와 **같은 규칙**이라 하이라이트가
## 켜진 자리에 놓으면 반드시 성립하고, 꺼진 자리에 놓으면 아무것도 안 옮기고 배너가 뜬다.
func _edit_drop_allowed(source: Dictionary, target: Dictionary) -> bool:
	if factory == null:
		return false
	var from_zone := String(source.get("zone", ""))
	var to_zone := String(target.get("zone", ""))
	if from_zone.is_empty() or to_zone.is_empty():
		return false
	if from_zone == "rail":
		if to_zone == "rail":
			return int(source.get("slot", -1)) != int(target.get("slot", -2))
		return to_zone == "inventory"
	if from_zone != "inventory":
		return false
	var index := int(source.get("index", -1))
	if index < 0 or index >= factory.inventory.size():
		return false
	var is_item := String((factory.inventory[index] as Dictionary).get("kind", "skill")) == "item"
	if to_zone == "rail":
		return not is_item
	if to_zone == "equipment":
		return is_item
	if to_zone == "inventory":
		var target_index := int(target.get("index", -1))
		return target_index >= 0 and target_index != index
	return false

## ② 5칸 레일 + ③ 바늘 방향. 칸 사이 선과 ▶ 하나가 "오른쪽으로 돈다"를 말한다.
func _build_edit_rail(panel: Control) -> void:
	for index in maxi(0, factory.slots.size() - 1):
		var spine := ColorRect.new()
		spine.position = Vector2(EDIT_RAIL_ORIGIN.x + float(index) * EDIT_RAIL_PITCH + EDIT_SLOT_SIZE.x,
			EDIT_RAIL_ORIGIN.y + EDIT_SLOT_SIZE.y * 0.5 - 2.0)
		spine.size = Vector2(EDIT_CONNECTOR_W, 4.0)
		spine.color = FACTORY_RAIL_SPINE_BUILT
		spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(spine)
		var arrow := _label("▶", 17, FACTORY_RAIL_SPINE_BUILT.lightened(0.52))
		arrow.position = Vector2(spine.position.x, spine.position.y - 12.0)
		arrow.size = Vector2(EDIT_CONNECTOR_W, 24.0)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(arrow)
	for slot_index in factory.slots.size():
		_build_edit_slot(panel, slot_index)
	_build_edit_flow_arcs(panel, null, EDIT_ARC_RECT, EDIT_RAIL_ORIGIN.x, 16.0, true)

## 칸 한 개. 위쪽 **손잡이 띠**와 아래쪽 **카드 그림**이 물리적으로 갈려 있고,
## 그 갈라짐 자체가 두 조작이다 — 모드 버튼도, 모드 안내문도 필요 없다.
##   카드 그림을 집는다 → 카드만 간다(각인은 칸에 남는다 · factory.move_card)
##   손잡이를 집는다   → 칸이 통째로 간다(각인 동반 · factory.swap_slots)
## 집는 순간 고스트가 "카드 한 장"인지 "칸 전체"인지로 뜨므로 무엇을 들었는지 눈에 보인다.
func _build_edit_slot(panel: Control, slot_index: int) -> void:
	var slot: Dictionary = factory.slots[slot_index]
	var slot_card: Dictionary = slot.get("card", {})
	var runes: Array = slot.get("runes", [])
	var picked := factory_pick_slot == slot_index
	var is_item := String(slot_card.get("kind", "skill")) == "item"
	var element := _card_element(slot_card)
	var element_color := _element_color(element)
	var cell := Panel.new()
	cell.name = "EditSlot%d" % slot_index
	cell.position = Vector2(EDIT_RAIL_ORIGIN.x + float(slot_index) * EDIT_RAIL_PITCH, EDIT_RAIL_ORIGIN.y)
	cell.size = EDIT_SLOT_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.set_meta("slot_index", slot_index)
	cell.set_meta("rune_count", runes.size())
	# X2: 프레임은 이제 모드가 아니라 **그 칸의 카드**를 말한다(SKILL·마름모 / ITEM·상자).
	# 거기에 X1의 원소 의미색을 입힌다 — 5칸이 무슨 속성으로 짜였는지가 글자 없이 보인다.
	# `_element_color()`가 원소색의 단일 진실 원천이다(handoff-x1 §3 · 새 표를 만들지 않았다).
	if slot_card.is_empty():
		UIKit.style_panel(cell, UIKit.Tone.SLATE, UIKit.Role.CELL)
	elif element.is_empty():
		cell.add_theme_stylebox_override("panel", _kit_card_box(1 if is_item else 0, 0))
	else:
		cell.add_theme_stylebox_override("panel",
			_kit_card_box_tinted(1 if is_item else 0, 0, Color.WHITE.lerp(element_color, 0.55)))
	panel.add_child(cell)
	# 곱셈 틴트만으로는 찬 원소(빙·유·초)가 탁한 갈색이 된다(handoff-x1 §3.1).
	# 알파 덧칠 한 겹을 더 얹어야 색상이 그대로 올라온다.
	# ⚠️ 손잡이 띠와 카드 몸통은 **불투명한 칩**이라 이 층을 통째로 덮는다(첫 캡처 실측 —
	#    화·타·뇌 넉 장이 전부 프레임 주황으로 뭉쳐 나왔다). 그래서 두 조각 **안쪽에**
	#    각각 한 겹씩 더 깐다. 여기 것은 칩 사이 틈과 막대·핍 구역 몫이다.
	if not slot_card.is_empty() and not element.is_empty():
		_element_wash(cell, Rect2(14.0, 14.0, 168.0, 172.0), element_color, 0.16)
	if picked:
		# 집은 칸 — 흰 이중 링 한 겹. 빈칸에서도 똑같이 보인다(프레임 상태에 안 기댄다).
		_kit_focus_ring(panel, Rect2(cell.position, cell.size))
	_build_edit_slot_handle(cell, slot_index, element_color, slot_card)
	_build_edit_slot_body(cell, slot_index, slot_card, is_item)
	# 지속/RELOAD — X1이 지킨 "기존 시각화 유지". 숫자는 뺐고 **막대 두 개**만 남았다.
	if not slot_card.is_empty() and not is_item:
		var ranked := DealCardLibrary.ranked(slot_card)
		var half := (EDIT_SLOT_HANDLE_RECT.size.x - 6.0) * 0.5
		_edit_meter(cell, Vector2(14.0, EDIT_SLOT_METER_Y), Vector2(half, 8.0),
			float(ranked.get("duration", 0.0)), 2.8, GamePalette.CYAN)
		_edit_meter(cell, Vector2(14.0 + half + 6.0, EDIT_SLOT_METER_Y), Vector2(half, 8.0),
			float(ranked.get("reload", 0.0)), 1.8, GamePalette.ORANGE)
	_build_edit_rune_pips(cell, slot_index)

## 칸 손잡이 — 번호 · 잡이 표식 · 원소 마크 세 그림만 있는 28px 띠.
func _build_edit_slot_handle(cell: Control, slot_index: int, element_color: Color, slot_card: Dictionary) -> void:
	var handle: Button = FACTORY_DRAG_BUTTON_SCRIPT.new()
	handle.name = "EditSlotHandle%d" % slot_index
	handle.text = ""
	handle.position = EDIT_SLOT_HANDLE_RECT.position
	handle.size = EDIT_SLOT_HANDLE_RECT.size
	handle.custom_minimum_size = EDIT_SLOT_HANDLE_RECT.size
	handle.focus_mode = Control.FOCUS_NONE
	var rest := UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CHIP)
	handle.add_theme_stylebox_override("normal", rest)
	handle.add_theme_stylebox_override("hover", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CELL))
	handle.add_theme_stylebox_override("pressed", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
	handle.add_theme_stylebox_override("disabled", rest)
	handle.add_theme_stylebox_override("focus", UIKit.focus_box())
	handle.set("drag_payload", {
		"zone": "rail", "slot": slot_index, "lane": 0, "gesture": EDIT_MODE_SLOT,
		"has_card": true, "name": "칸 %02d" % (slot_index + 1)
	})
	# 고스트가 **칸 전체**로 뜬다 = "지금 드는 건 칸이다"가 집는 순간 보인다.
	handle.set("ghost_source", cell)
	handle.set("drop_hint_host", cell)
	handle.set("drop_hint", func(data: Dictionary) -> bool:
		return _edit_drop_allowed(data, {"zone": "rail", "slot": slot_index}))
	handle.connect("factory_card_dropped", _on_factory_card_dropped)
	handle.pressed.connect(_editor_slot_pressed.bind(slot_index, EDIT_MODE_SLOT))
	cell.add_child(handle)
	# 불투명 칩 위의 원소 덧칠(§ 위 경고). 번호·잡이·마크보다 **먼저** 넣어야 밑에 깔린다.
	if not slot_card.is_empty() and not _card_element(slot_card).is_empty():
		_element_wash(handle, Rect2(2.0, 2.0, EDIT_SLOT_HANDLE_RECT.size.x - 4.0,
			EDIT_SLOT_HANDLE_RECT.size.y - 4.0), element_color, 0.20)
	var numeral := _label("%d" % (slot_index + 1), UI_HEADING_SIZE,
		element_color.lightened(0.34) if not slot_card.is_empty() else GamePalette.MUTED)
	numeral.position = Vector2(4.0, 2.0)
	numeral.size = Vector2(24.0, 24.0)
	numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	handle.add_child(numeral)
	_kit_pointer(handle, Vector2(EDIT_SLOT_HANDLE_RECT.size.x * 0.5 - 11.0, 3.0), "grip",
		Color(UIKit.muted_on(UIKit.Tone.SLATE, UIKit.Role.CHIP), 0.85), 22.0)
	# 색약 대비 1글자 마크. HUD 레일·레벨업 모달과 **같은 글자**다(RAIL_ELEMENT_MARK).
	var mark := String(RAIL_ELEMENT_MARK.get(_card_element(slot_card), ""))
	if not mark.is_empty():
		var mark_label := _label(mark, UI_LABEL_SIZE, element_color.lightened(0.34))
		mark_label.position = Vector2(EDIT_SLOT_HANDLE_RECT.size.x - 28.0, 2.0)
		mark_label.size = Vector2(24.0, 24.0)
		mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		handle.add_child(mark_label)
	_edit_tip(handle, "slot%d_handle" % slot_index, _edit_slot_tooltip(slot_index))

## 카드 몸통 — **그림 하나 + 이름 한 줄**. 랭크·태그·계수는 전부 호버로 갔다.
func _build_edit_slot_body(cell: Control, slot_index: int, slot_card: Dictionary, is_item: bool) -> void:
	var card_color := GamePalette.STONE_LIGHT if slot_card.is_empty() else _factory_card_color(slot_card)
	var body: Button = FACTORY_DRAG_BUTTON_SCRIPT.new()
	body.name = "EditSlotCard%d" % slot_index
	body.text = ""
	body.position = EDIT_SLOT_BODY_RECT.position
	body.size = EDIT_SLOT_BODY_RECT.size
	body.custom_minimum_size = EDIT_SLOT_BODY_RECT.size
	body.focus_mode = Control.FOCUS_NONE
	# 칸이 이미 카드 프레임이라 안쪽은 평면 칩이다(프레임 두 겹은 196px에서 안 산다).
	var chip := UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CHIP)
	body.add_theme_stylebox_override("normal", chip)
	body.add_theme_stylebox_override("hover", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CELL))
	body.add_theme_stylebox_override("pressed", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
	body.add_theme_stylebox_override("disabled", chip)
	body.add_theme_stylebox_override("focus", UIKit.focus_box())
	body.set("drag_payload", {
		"zone": "rail", "slot": slot_index, "lane": 0, "gesture": EDIT_MODE_CARD,
		"has_card": not slot_card.is_empty(), "name": _factory_card_name(slot_card)
	})
	body.set("drop_hint_host", cell)
	body.set("drop_hint", func(data: Dictionary) -> bool:
		return _edit_drop_allowed(data, {"zone": "rail", "slot": slot_index}))
	body.connect("factory_card_dropped", _on_factory_card_dropped)
	body.pressed.connect(_factory_lane_pressed.bind(slot_index, 0))
	# 포커스 강조는 칸 전체에 준다(안쪽 칩만 밝히면 5칸에서 어디가 켜졌는지 안 보인다).
	body.set_meta("edit_cell", cell)
	cell.add_child(body)
	factory_lane_buttons.append(body)
	factory_lane_coordinates.append(Vector2i(slot_index, 0))
	# 사용자 원문(X1 승계): "속성은 텍스트가 아니라 스킬 배경색 또는 **블록색** 통일로."
	# 여기가 그 블록이다 — **아이콘이 앉는 사각형만** 물들인다(X1의 0.34 대역).
	# 몸통 전체를 칠하면 이름 줄까지 뿌예져 글자가 죽는다(2차 캡처 실측 — 무채 원소인
	# 타(打) 카드에서 특히 심했다). 색은 블록이 나르고 글자 자리는 어두운 채로 둔다.
	var element := _card_element(slot_card)
	if not slot_card.is_empty() and not element.is_empty():
		_element_wash(body, Rect2((EDIT_SLOT_BODY_RECT.size.x - EDIT_SLOT_ICON) * 0.5 - 8.0, 1.0,
			EDIT_SLOT_ICON + 16.0, EDIT_SLOT_ICON + 4.0), _element_color(element), 0.34)
	# ⑤ 빈 상태 — 문장 대신 **흐릿한 자리표시 그림**. 빈칸이 쓰는 기본 베기 아이콘이다.
	var icon := SKILL_ICON_SCRIPT.new()
	icon.position = Vector2((EDIT_SLOT_BODY_RECT.size.x - EDIT_SLOT_ICON) * 0.5, 2.0)
	icon.size = Vector2(EDIT_SLOT_ICON, EDIT_SLOT_ICON)
	icon.setup(String(slot_card.get("id", "basic")) if not slot_card.is_empty() else "basic", card_color)
	if slot_card.is_empty():
		icon.modulate = Color(1.0, 1.0, 1.0, 0.30)
	body.add_child(icon)
	var name_label := _label(_factory_card_name(slot_card), UI_BODY_SIZE,
		GamePalette.TEXT if not slot_card.is_empty() else Color(GamePalette.MUTED, 0.72))
	name_label.position = Vector2(4.0, EDIT_SLOT_ICON + 4.0)
	name_label.size = Vector2(EDIT_SLOT_BODY_RECT.size.x - 8.0, 22.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(name_label)
	if is_item:
		# 아이템이 레일에 앉아 있으면 규칙 위반이다. 상자 프레임이 이미 말하지만
		# 경고 글리프 하나로 못 박는다(글자 0개).
		_kit_glyph(body, Vector2(EDIT_SLOT_BODY_RECT.size.x - 26.0, 4.0), "warn", GamePalette.MAGENTA, 18.0)
	_edit_tip(body, "slot%d_card" % slot_index, _edit_card_tooltip(slot_index))

## 글자 없는 게이지 막대 하나. 지속(청)·RELOAD(주)는 게임 전체에서 같은 두 색이다.
## 10px 막대는 §4 9-slice 하한(24)에 못 미치므로 여기는 ColorRect가 정답이다(§13).
func _edit_meter(parent: Control, at: Vector2, bar_size: Vector2, value: float,
		visual_max: float, color: Color) -> void:
	var track := ColorRect.new()
	track.position = at
	track.size = bar_size
	track.color = Color(UI_CHIP_BG, 0.88)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.position = Vector2(1.0, 1.0)
	fill.size = Vector2(maxf(1.0, (bar_size.x - 2.0) * clampf(value / maxf(visual_max, 0.01), 0.0, 1.0)),
		maxf(1.0, bar_size.y - 2.0))
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

func _build_edit_rune_pips(cell: Control, slot_index: int) -> void:
	# W5 필드 HUD와 **같은 공식**: 자리 3개 + 초과 "+N", 색은 희귀도(common 금 / rare 청 / epic 자주).
	# 두 화면의 "각인이 몇 개 박혀 있나"가 다르게 보이면 안 된다(handoff-w5 §6).
	# X2: "각인 잔류 / 각인 동반" 캡션은 사라졌다 — 이 줄 전체가 호버 대상이고
	# 각인 스택 패널(구 EditRuneDetail)의 내용이 통째로 그 툴팁으로 왔다.
	#
	# ★ Y3(피드백 ③ · §8 ③): 붙은 자리는 **색 사각 핍 → 각인 그림 기호 12×12**로 갈았다.
	#   색만 있으면 "각인 3개"까지만 읽히고 **무슨 각인인지**는 호버해야 알 수 있었다.
	#   빈 자리는 그대로 유령 핍이다 — 그림이 없어야 "비었다"가 즉시 읽힌다.
	#   위치(`EDIT_SLOT_PIP_Y` 174) · 간격 14 · `+N` 규칙은 **한 픽셀도 안 바뀌었다.**
	var runes: Array = factory.runes_on(slot_index)
	var row := Control.new()
	row.name = "EditSlotRunes%d" % slot_index
	row.position = Vector2(14.0, EDIT_SLOT_PIP_Y)
	row.size = Vector2(EDIT_SLOT_HANDLE_RECT.size.x, 12.0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_child(row)
	var shown := mini(runes.size(), RuneEngine.RUNE_SLOTS_PER_SLOT)
	for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
		if pip_index < shown:
			var rune_id := String((runes[pip_index] as Dictionary).get("id", ""))
			_rune_glyph(row, Vector2(float(pip_index) * 14.0, 0.0), rune_id,
				_rune_rarity_color(rune_id), 12.0)
			continue
		var pip := ColorRect.new()
		pip.position = Vector2(float(pip_index) * 14.0, 1.0)
		pip.size = Vector2(10.0, 10.0)
		pip.color = Color(UI_EDGE_SOFT, 0.55)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	var overflow := runes.size() - RuneEngine.RUNE_SLOTS_PER_SLOT
	if overflow > 0:
		# 과밀은 페널티다 — 숫자 두 글자는 남긴다(색만으로는 "몇 개 넘쳤나"가 안 나온다).
		var extra := _label("+%d" % overflow, UI_CAPTION_SIZE, GamePalette.ORANGE)
		extra.position = Vector2(46.0, -2.0)
		extra.size = Vector2(30.0, 16.0)
		row.add_child(extra)
	_edit_tip(row, "slot%d_runes" % slot_index, _edit_rune_tooltip(slot_index))

# W10: `deck` / `arc_rect` / `rail_origin_x` 세 선택 인자는 마왕 프리뷰가 **같은 렌더러**로
# 두 레일(내 5칸 · 마왕 5칸)의 흐름 아크를 그리기 위한 것이다(설계 §8.4 "픽셀 동일한 레일 렌더러").
# 기본값이 편집 화면 값이라 W6 호출부는 무변경이다.
##
## X2가 더한 선택 인자 `minimal`은 **편집 화면 전용**이다. true면 아크 위의 글자 라벨
## (`이름 42%`)과 "흐름 각인 없음 —" 안내 한 줄을 그리지 않고, 대신 아크 꼭대기마다
## 색 핍 하나를 놓아 **호버로** 같은 정보를 준다. 기본값 false라 마왕 프리뷰·결과 화면의
## 그림은 한 픽셀도 안 바뀐다(그 두 화면은 X2 범위 밖이다).
func _build_edit_flow_arcs(panel: Control, deck: FactoryDeck = null, arc_rect: Rect2 = EDIT_ARC_RECT, rail_origin_x: float = EDIT_RAIL_ORIGIN.x, lane_step: float = 18.0, minimal: bool = false) -> void:
	var arc_layer := FlowArcOverlay.new()
	arc_layer.name = "FlowArcs"
	arc_layer.position = arc_rect.position
	arc_layer.size = arc_rect.size
	arc_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(arc_layer)
	var entries := _edit_flow_entries(deck)
	var slot_center := func(index: int) -> float:
		return rail_origin_x + float(index) * EDIT_RAIL_PITCH + EDIT_CARD_SIZE.x * 0.5
	var arcs: Array = []
	# 라벨 3줄을 x구간 그리디 패킹으로 배치한다. 같은 줄에서 겹치지 않는 첫 줄에 넣고,
	# 세 줄 어디에도 자리가 없으면 **호만 그리고 라벨은 생략한다**(겹쳐 읽히느니 없는 게 낫다).
	var lane_spans: Array = [[], [], []]
	var label_width := 116.0 if not minimal else 22.0
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var from_x: float = slot_center.call(int(entry["from"])) - arc_rect.position.x
		var to_x: float = slot_center.call(int(entry["to"])) - arc_rect.position.x
		var is_loop := bool(entry["loop"])
		# 제자리 고리(앙코르 등)는 라벨을 원 옆으로 비켜 놓는다. 원 위에 얹으면 글자가 선에 묻힌다.
		var apex_x := (from_x + 68.0) if is_loop else (from_x + to_x) * 0.5
		var left := clampf(apex_x - label_width * 0.5, 0.0, arc_rect.size.x - label_width)
		var right := left + label_width
		var lane := -1
		for candidate in lane_spans.size():
			var free := true
			for span_value in (lane_spans[candidate] as Array):
				var span: Vector2 = span_value
				if right > span.x and left < span.y:
					free = false
					break
			if free:
				lane = candidate
				(lane_spans[candidate] as Array).append(Vector2(left, right))
				break
		var height := 10.0 + float(maxi(0, lane) % 3) * lane_step
		arcs.append({
			"x1": from_x, "x2": to_x, "base": arc_rect.size.y,
			"height": height, "color": entry["color"], "loop": is_loop
		})
		if lane < 0:
			continue
		if minimal:
			# 아크 꼭대기의 색 핍. 글자 0개 — 각인 이름·확률·효과는 호버가 말한다.
			var pip := ColorRect.new()
			pip.position = (arc_rect.position + Vector2(left + 5.0, arc_rect.size.y - height - 6.0)).floor()
			pip.size = Vector2(12.0, 12.0)
			pip.color = entry["color"]
			pip.mouse_filter = Control.MOUSE_FILTER_PASS
			panel.add_child(pip)
			_edit_tip(pip, "arc%d" % index, _edit_arc_tooltip(entry))
			continue
		# 라벨 뒤에 킷 칩을 깔아 아크 선이 글자를 관통해도 판독된다.
		# 칩 9-slice 하한은 24×24 → 16px 띠는 여백이 눌리므로 26으로 올렸다(§4).
		var label_y := arc_rect.size.y - height - 22.0
		var chip := _kit_panel(panel, Rect2(arc_rect.position + Vector2(left, label_y),
			Vector2(label_width, 26.0)), UIKit.Tone.SLATE, UIKit.Role.CHIP)
		var label := _label("%s %d%%" % [String(entry["name"]), int(round(float(entry["p"]) * 100.0))], UI_CAPTION_SIZE, entry["color"])
		label.position = chip.position
		label.size = Vector2(label_width, 26.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
	arc_layer.arcs = arcs
	arc_layer.queue_redraw()
	if entries.is_empty() and not minimal:
		var empty := _label("흐름 각인 없음 — 바늘은 1 → 2 → 3 → 4 → 5 순서로만 흐릅니다", UI_BODY_SIZE, GamePalette.MUTED.darkened(0.2))
		empty.position = arc_rect.position + Vector2(0.0, arc_rect.size.y - 22.0)
		empty.size = Vector2(arc_rect.size.x, 20.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(empty)

## 아크 핍 하나의 호버 내용. 구 라벨 `이름 42%`가 여기로 왔고 효과 문장이 더 붙었다.
func _edit_arc_tooltip(entry: Dictionary) -> Dictionary:
	var from_slot := int(entry["from"]) + 1
	var to_slot := int(entry["to"]) + 1
	var jump := "%d번 칸에서 다시" % from_slot if bool(entry["loop"]) else "칸 %d → 칸 %d" % [from_slot, to_slot]
	return {
		"title": String(entry["name"]),
		"accent": entry["color"],
		"rows": [
			["발동", "%d%%" % int(round(float(entry["p"]) * 100.0))],
			["바늘", jump]
		],
		"body": "흐름 각인은 바늘이 다음에 갈 칸을 바꿉니다. 발동하지 않으면 바늘은 그냥 오른쪽 칸으로 갑니다."
	}

func _edit_flow_entries(deck: FactoryDeck = null) -> Array:
	var entries: Array = []
	var source: FactoryDeck = deck if deck != null else factory
	if source == null:
		return entries
	var last := source.slots.size() - 1
	for slot_index in source.slots.size():
		var counted: Dictionary = {}
		for rune_value in source.runes_on(slot_index):
			var rune: Dictionary = rune_value
			var rune_id := String(rune.get("id", ""))
			if not EDIT_ARC_RUNES.has(rune_id) or counted.has(rune_id):
				continue
			counted[rune_id] = true
			var offset := int(EDIT_ARC_RUNES[rune_id])
			var target := clampi(slot_index + offset, 0, maxi(0, last))
			entries.append({
				"from": slot_index,
				"to": target,
				"p": _slot_rune_probability(slot_index, rune_id, source),
				"name": String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("name", rune_id)),
				"color": _rail_kind_color(String(RAIL_FLOW_KIND.get(rune_id, ""))),
				"loop": offset == 0 or target == slot_index
			})
	entries.sort_custom(func(a, b): return float(a["p"]) > float(b["p"]))
	if entries.size() > EDIT_ARC_MAX:
		entries.resize(EDIT_ARC_MAX)
	return entries

## **레일 각인 줄** + 되돌이 선. Y2가 구 「결속 색 띠」를 여기서 갈아끼웠다.
## 결속·삼각은 과열과 함께 폐기됐고(§1.4) 그 자리를 §2.5가 지정한 대로
## **레일 전체가 소유한 각인**이 산다 — 칸에 붙지 않으므로 보여 줄 자리가 여기뿐이다.
## 되돌이 선은 "5번 칸을 지나면 1번으로 돌아온다"를 말하는 유일한 그림이고,
## 중학생 3초 테스트 ①("5칸이 순서대로 돈다")이 통과하는지가 여기 달려 있다.
func _build_edit_bond_band(panel: Control) -> void:
	var rail_runes: Array = factory.rail_runes
	var track := ColorRect.new()
	track.position = EDIT_BOND_RECT.position
	track.size = Vector2(EDIT_BOND_RECT.size.x, 2.0)
	track.color = UI_EDGE_SOFT
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)
	# 레일 각인 줄 — 왼쪽부터 붙은 순서대로. 빈 자리는 상한(3개)까지 유령으로 깐다.
	# ★ Y3(§8 ③): Y2의 22×8 색 칩을 **각인 그림 기호 12×12**로 갈았다. 칸 각인 핍과
	#   같은 그림 언어라 "이 각인이 칸에 붙었나 레일에 붙었나"만 자리로 갈린다.
	#   되돌이 선(`EDIT_LOOP_RECT` y 356)과 겹치지 않게 12px 안에서 끝난다(342~354).
	for index in RuneEngine.RAIL_RUNE_CAP:
		var owned: Dictionary = rail_runes[index] if index < rail_runes.size() else {}
		var rail_id := String(owned.get("id", ""))
		var chip_x := EDIT_RAIL_ORIGIN.x + float(index) * 18.0
		if rail_id.is_empty():
			var ghost := ColorRect.new()
			ghost.name = "EditRailRune%d" % index
			ghost.position = Vector2(chip_x, EDIT_BOND_RECT.position.y + 1.0)
			ghost.size = Vector2(10.0, 10.0)
			ghost.color = Color(UI_EDGE_SOFT, 0.55)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(ghost)
			continue
		var mark := _rune_glyph(panel, Vector2(chip_x, EDIT_BOND_RECT.position.y),
			rail_id, _rune_rarity_color(rail_id), 12.0)
		if mark != null:
			mark.name = "EditRailRune%d" % index
	# 되돌이 선은 레일 본선보다 밝다 — 첫 캡처에서 너무 옅어 배경선으로 읽혔다(실측).
	var spine_color := FACTORY_RAIL_SPINE_BUILT.lightened(0.34)
	var line_y := EDIT_LOOP_RECT.position.y + 10.0
	var line := ColorRect.new()
	line.position = Vector2(EDIT_LOOP_RECT.position.x, line_y)
	line.size = Vector2(EDIT_LOOP_RECT.size.x, 3.0)
	line.color = spine_color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	for tick_x: float in [EDIT_LOOP_RECT.position.x, EDIT_LOOP_RECT.end.x - 3.0]:
		var tick := ColorRect.new()
		tick.position = Vector2(tick_x, EDIT_LOOP_RECT.position.y)
		tick.size = Vector2(3.0, 11.0)
		tick.color = spine_color
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tick)
	var head := _label("◀", 15, spine_color.lightened(0.42))
	head.position = Vector2(EDIT_LOOP_RECT.position.x + 14.0, line_y - 11.0)
	head.size = Vector2(24.0, 22.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(head)
	# 이 띠 전체가 호버 대상 하나다 — 레일 각인 · 공명 · 한 바퀴 규칙이 전부 여기.
	var strip := Control.new()
	strip.name = "EditBondStrip"
	strip.position = Vector2(EDIT_BOND_RECT.position.x, EDIT_BOND_RECT.position.y - 2.0)
	strip.size = Vector2(EDIT_BOND_RECT.size.x, EDIT_LOOP_RECT.end.y - EDIT_BOND_RECT.position.y + 2.0)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(strip)
	var rows: Array = [
		["레일 각인", "%d / %d" % [rail_runes.size(), RuneEngine.RAIL_RUNE_CAP],
			GamePalette.MAGENTA if not rail_runes.is_empty() else GamePalette.MUTED]
	]
	for rail_value in rail_runes:
		var rail_inst: Dictionary = rail_value
		var rail_id := String(rail_inst.get("id", ""))
		var rail_def: Dictionary = RuneEngine.RUNES.get(rail_id, {})
		rows.append([String(rail_def.get("name", rail_id)),
			String(rail_def.get("effect", "")), _rune_rarity_color(rail_id)])
	if rail_runes.is_empty():
		rows.append(["없음", "각인 세공사 · 상자 · 균열에서 얻습니다", GamePalette.MUTED])
	rows.append(["같은 색", "옆 칸과 속성이 같으면 두 칸 모두 피해 +%d%%" % int(round(RuneEngine.RESONANCE_DAMAGE * 100.0)), GamePalette.GREEN])
	_edit_tip(strip, "bond", {
		"title": "한 바퀴 · 레일 각인",
		"accent": GamePalette.MAGENTA if not rail_runes.is_empty() else GamePalette.CYAN,
		"rows": rows,
		"body": "바늘은 %d번 칸을 지나면 다시 1번 칸으로 돌아옵니다 — 이 되돌이 선 한 바퀴가 「딜싸이클」입니다. 한 칸은 한 바퀴에 %d번까지만 터지고, 두 번 밟은 칸은 바늘이 건너뜁니다. 레일 각인은 칸이 아니라 이 줄 전체가 가지므로 칸을 옮겨도 따라가지 않습니다." % [FactoryDeck.SLOT_COUNT, RuneEngine.SLOT_EXEC_CAP]
	})

## ④ 보관함 — **카드 그림만** 있는 격자. 이름·수치는 호버가 말한다.
## 빈 상태 두 문장("보관한 카드가 없습니다…")은 **흐릿한 자리표시 타일**로 갈렸다.
func _build_edit_inventory(panel: Control) -> void:
	var box := Panel.new()
	box.name = "EditInventory"
	box.position = EDIT_INVENTORY_RECT.position
	box.size = EDIT_INVENTORY_RECT.size
	UIKit.style_panel(box, UIKit.Tone.SLATE, UIKit.Role.INSET)
	panel.add_child(box)
	# TAB 포커스가 온 영역은 테두리 색이 아니라 **흰 포커스 링**이 알린다(§4).
	if factory_focus_zone == "inventory":
		_kit_focus_ring(panel, EDIT_INVENTORY_RECT)
	var tab := _kit_panel(box, Rect2(10.0, 6.0, 40.0, 24.0), UIKit.Tone.SLATE, UIKit.Role.CHIP)
	tab.name = "EditInventoryTab"
	_kit_glyph(tab, Vector2(9.0, 2.0), "bag", GamePalette.CYAN, 20.0)
	_edit_tip(tab, "inventory", {
		"title": "보관함",
		"accent": GamePalette.CYAN,
		"rows": [
			["보유", "%d장" % factory.inventory.size()],
			["레일로", "스킬 카드를 칸에 끌어 놓기"],
			["장비로", "아이템 카드를 오른쪽 부위에 끌기"],
			["빼기", "레일 카드를 보관함으로 끌기"]
		],
		"body": "카드는 레벨업 · 성 상점 · 보물상자에서 들어옵니다. 아이템 카드는 레일에 놓을 수 없고 장비 4부위로만 갑니다."
	})
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12.0, 32.0)
	scroll.size = Vector2(EDIT_INVENTORY_RECT.size.x - 24.0, EDIT_INVENTORY_RECT.size.y - 44.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	factory_rail_scroll = null
	var grid := GridContainer.new()
	grid.columns = EDIT_INV_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for index in factory.inventory.size():
		var tile := _edit_inventory_tile(factory.inventory[index], index)
		grid.add_child(tile)
		factory_inventory_buttons.append(tile)
		factory_inventory_indices.append(index)
	for spare in maxi(EDIT_INV_MIN_TILES - factory.inventory.size(), 0):
		grid.add_child(_edit_inventory_placeholder(spare))

## 카드 한 장 = 타일 하나. 프레임(스킬 마름모 / 아이템 상자)과 원소색이 정체를 말한다.
func _edit_inventory_tile(card: Dictionary, index: int) -> Button:
	var is_item := String(card.get("kind", "skill")) == "item"
	var element := _card_element(card)
	var element_color := _element_color(element)
	var card_color := _factory_card_color(card)
	var tile: Button = FACTORY_DRAG_BUTTON_SCRIPT.new()
	tile.name = "EditInvTile%d" % index
	tile.text = ""
	tile.custom_minimum_size = EDIT_INV_TILE
	tile.size = EDIT_INV_TILE
	tile.focus_mode = Control.FOCUS_NONE
	# 아이템은 원소가 없다 — 희귀도 색이 그 자리를 대신한다(레벨업 모달과 같은 규약).
	_kit_card_skin_tinted(tile, 1 if is_item else 0,
		Color.WHITE.lerp(card_color if is_item or element.is_empty() else element_color, 0.55))
	tile.set_meta("kit_frame_pad", CARD_BLOCK_PAD_FRAMED)
	tile.set("drag_payload", {"zone": "inventory", "index": index, "has_card": true,
		"kind": card.get("kind", "skill"), "name": _factory_card_name(card)})
	tile.set("drop_hint", func(data: Dictionary) -> bool:
		return _edit_drop_allowed(data, {"zone": "inventory", "index": index}))
	tile.connect("factory_card_dropped", _on_factory_card_dropped)
	tile.pressed.connect(_factory_inventory_pressed.bind(index))
	var icon := SKILL_ICON_SCRIPT.new()
	icon.position = Vector2(20.0, 16.0)
	icon.size = Vector2(48.0, 48.0)
	icon.setup(String(card.get("id", "basic")), card_color)
	tile.add_child(icon)
	var mark := String(RAIL_ELEMENT_MARK.get(element, ""))
	if not mark.is_empty():
		var mark_label := _label(mark, UI_CAPTION_SIZE, element_color.lightened(0.34))
		mark_label.position = Vector2(EDIT_INV_TILE.x - 30.0, 14.0)
		mark_label.size = Vector2(18.0, 16.0)
		mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(mark_label)
	_edit_tip(tile, "inv%d" % index, _edit_inventory_tooltip(card))
	return tile

## ⑤ 빈 상태 — 문장이 아니라 흐릿한 자리표시 타일. 레일 카드를 여기로 끌어 뺄 수도 있다.
func _edit_inventory_placeholder(order: int) -> Button:
	var tile: Button = FACTORY_DRAG_BUTTON_SCRIPT.new()
	tile.name = "EditInvEmpty%d" % order
	tile.text = ""
	tile.custom_minimum_size = EDIT_INV_TILE
	tile.size = EDIT_INV_TILE
	tile.focus_mode = Control.FOCUS_NONE
	var rest := UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CELL)
	tile.add_theme_stylebox_override("normal", rest)
	tile.add_theme_stylebox_override("hover", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
	tile.add_theme_stylebox_override("pressed", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
	tile.add_theme_stylebox_override("disabled", rest)
	tile.add_theme_stylebox_override("focus", UIKit.focus_box())
	# 자리표시는 끌 수 없고(has_card false) 받기만 한다 — 레일 → 보관함 경로의 착지점이다.
	tile.set("drag_payload", {"zone": "inventory", "index": -1, "has_card": false})
	tile.set("drop_hint", func(data: Dictionary) -> bool:
		return String(data.get("zone", "")) == "rail")
	tile.connect("factory_card_dropped", _on_factory_card_dropped)
	_kit_glyph(tile, Vector2(EDIT_INV_TILE.x * 0.5 - 11.0, EDIT_INV_TILE.y * 0.5 - 11.0),
		"plus", Color(GamePalette.MUTED, 0.34), 22.0)
	if order == 0:
		_edit_tip(tile, "inventory_empty", {
			"title": "빈 자리",
			"accent": GamePalette.MUTED,
			"rows": [["채우는 법", "레벨업 · 성 상점 · 보물상자"], ["빼는 법", "레일 카드를 여기로 끌기"]],
			"body": "보관함의 빈 칸입니다. 레일에서 카드를 빼려면 그 카드를 여기로 끌어 놓으세요."
		})
	return tile

func _edit_inventory_tooltip(card: Dictionary) -> Dictionary:
	if String(card.get("kind", "skill")) == "item":
		var item := ItemLibrary.by_id(String(card.get("id", "")))
		return {
			"title": _factory_card_name(card),
			"accent": _factory_card_color(card),
			"rows": [
				["종류", "아이템 · 공격 없음", GamePalette.MAGENTA],
				["부위", ItemLibrary.part_name(String(item.get("slot", "")))],
				["적용", ItemLibrary.effect_scope(item)],
				["효과", ItemLibrary.compact_effect(item)]
			],
			"body": "아이템은 레일에 놓을 수 없습니다 — 오른쪽 장비 4부위로 끌어 놓으세요. %s" % String(item.get("desc", ""))
		}
	var ranked := DealCardLibrary.ranked(card)
	var element := _card_element(card)
	var rows: Array = [
		["등급", "R%d" % int(card.get("rank", 1))],
		["지속", "%.2f초" % float(ranked.get("duration", 0.0)), GamePalette.CYAN],
		["RELOAD", "%.2f초" % float(ranked.get("reload", 0.0)), GamePalette.ORANGE],
		["피해 배수", "%.2f" % float(ranked.get("damage", 0.0))]
	]
	var tag := _card_tag_compact(ranked)
	if not tag.is_empty():
		rows.append(["속성 · 형태", tag, _element_color(element)])
	return {
		"title": _factory_card_name(card),
		"accent": _element_color(element),
		"rows": rows,
		"body": String(ranked.get("desc", ""))
	}

## ⑤ 장비 4부위 — 부위 글리프만. 어떤 아이템이 끼워졌는지는 그 아이템의 그림이 말한다.
func _build_edit_equipment(panel: Control) -> void:
	var box := Panel.new()
	box.name = "EditEquipment"
	box.position = EDIT_EQUIP_RECT.position
	box.size = EDIT_EQUIP_RECT.size
	var item_selected := factory_selected_inventory >= 0 and factory_selected_inventory < factory.inventory.size() \
		and String((factory.inventory[factory_selected_inventory] as Dictionary).get("kind", "skill")) == "item"
	UIKit.style_panel(box, UIKit.Tone.SLATE, UIKit.Role.INSET)
	panel.add_child(box)
	# "지금 여기에 넣을 수 있다" · "지금 여기에 포커스가 있다" 둘 다 흰 링으로 말한다.
	if item_selected or factory_focus_zone == "equipment":
		_kit_focus_ring(panel, EDIT_EQUIP_RECT)
	var tab := _kit_panel(box, Rect2(10.0, 6.0, 40.0, 24.0), UIKit.Tone.SLATE, UIKit.Role.CHIP)
	tab.name = "EditEquipmentTab"
	_kit_glyph(tab, Vector2(9.0, 2.0), "key", GamePalette.MAGENTA, 20.0)
	_edit_tip(tab, "equipment", {
		"title": "장비 %d/%d" % [factory.equipment.size(), FactoryDeck.EQUIPMENT_PARTS.size()],
		"accent": GamePalette.MAGENTA,
		"rows": [["넣기", "보관함 아이템을 부위로 끌기"], ["빼기", "낀 부위를 누르면 보관함으로"]],
		"body": "아이템은 레일 밖입니다 — 바늘이 지나가지 않고 대신 레일 전체나 이웃 칸에 늘 효과를 겁니다."
	})
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(12.0, 32.0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for part_index in FactoryDeck.EQUIPMENT_PARTS.size():
		var tile := _edit_equipment_tile(part_index)
		grid.add_child(tile)
		factory_equipment_buttons.append(tile)

# =============================================================================
# Y4 — 장비 부위 그림 2종 (피드백 ⑫⑳ · FEEDBACK_Y §8 ⑫ ⑳)
# =============================================================================
# 유저 원문 요지: "장비 빈칸에 무채색 실루엣." X2까지 빈 부위는 킷 글리프
# `diamond / gem / coin / key`를 빌려 썼는데, **「열쇠 = 팔찌」는 아무도 못 읽는다** —
# §8 ⑳이 "글리프 시트의 대체가 아니라 부위 모양 실루엣 4종"이라고 못 박은 이유다.
# YA가 그 넷을 구웠다(`ui-slot-silhouettes.png` 무채 실루엣 · `ui-slot-badges.png` 배지).
# 두 시트 모두 160×40 · 셀 40 · 4칸이고 칸 순서는 `EQUIPMENT_PARTS`와 **같다**.
const EQUIP_SILHOUETTE_SHEET := preload("res://art/v2/ui-slot-silhouettes.png")
const EQUIP_BADGE_SHEET := preload("res://art/v2/ui-slot-badges.png")
const EQUIP_ART_CELL := 40.0

func _equip_part_art(parent: Control, at: Vector2, part: String, box: float,
		badge: bool, tint: Color) -> TextureRect:
	var index := FactoryDeck.EQUIPMENT_PARTS.find(part)
	if index < 0:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = EQUIP_BADGE_SHEET if badge else EQUIP_SILHOUETTE_SHEET
	atlas.region = Rect2(float(index) * EQUIP_ART_CELL, 0.0, EQUIP_ART_CELL, EQUIP_ART_CELL)
	var art := TextureRect.new()
	art.name = "EquipBadge" if badge else "EquipSilhouette"
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2.ZERO
	art.position = at
	art.size = Vector2(box, box)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = tint
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _edit_equipment_tile(part_index: int) -> Button:
	var part := String(FactoryDeck.EQUIPMENT_PARTS[part_index])
	var equipped := factory.equipped_at(part)
	var empty := equipped.is_empty()
	var color := GamePalette.MUTED if empty else _factory_card_color(equipped)
	var tile: Button = FACTORY_DRAG_BUTTON_SCRIPT.new()
	tile.name = "EditEquipTile%d" % part_index
	tile.text = ""
	tile.custom_minimum_size = EDIT_EQUIP_TILE
	tile.size = EDIT_EQUIP_TILE
	tile.focus_mode = Control.FOCUS_NONE
	var rest := UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CELL) if empty else _kit_card_box(1, 0)
	tile.add_theme_stylebox_override("normal", rest)
	tile.add_theme_stylebox_override("hover", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET) if empty else _kit_card_box(1, 1))
	tile.add_theme_stylebox_override("pressed", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
	tile.add_theme_stylebox_override("disabled", rest)
	tile.add_theme_stylebox_override("focus", UIKit.focus_box())
	tile.set_meta("equipment_part", part)
	# X2 신설: 편집 화면에서도 장비가 **드롭 지점**이다(예전에는 클릭 배치만 됐다).
	tile.set("drag_payload", {"zone": "equipment", "part": part, "index": part_index, "has_card": false})
	tile.set("drop_hint", func(data: Dictionary) -> bool:
		return _edit_drop_allowed(data, {"zone": "equipment", "part": part}))
	tile.connect("factory_card_dropped", _on_factory_card_dropped)
	tile.pressed.connect(_editor_equipment_pressed.bind(part_index))
	# Y4 — 부위 그림. 빈 부위면 **무채 실루엣**이 가운데 크게(자리표시),
	# 끼워져 있으면 **부위 배지**가 왼쪽 위에 작게 선다. 킷 글리프 빌려 쓰기는 끝났다.
	if empty:
		_equip_part_art(tile, Vector2(EDIT_EQUIP_TILE.x * 0.5 - 21.0, 14.0), part, 42.0,
			false, Color(GamePalette.MUTED, 0.46))
		# 실루엣만으로는 「무기인가 팔찌인가」가 안 갈리는 크기다 — 이름을 한 줄 붙인다.
		var empty_name := _label(ItemLibrary.part_name(part), UI_CAPTION_SIZE, Color(GamePalette.MUTED, 0.9))
		empty_name.position = Vector2(0.0, EDIT_EQUIP_TILE.y - 24.0)
		empty_name.size = Vector2(EDIT_EQUIP_TILE.x, 18.0)
		empty_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(empty_name)
	else:
		_equip_part_art(tile, Vector2(10.0, 8.0), part, 26.0, true, Color(GamePalette.MAGENTA, 0.95))
		var icon := SKILL_ICON_SCRIPT.new()
		icon.position = Vector2(EDIT_EQUIP_TILE.x * 0.5 - 22.0, 20.0)
		icon.size = Vector2(44.0, 44.0)
		icon.setup(String(equipped.get("id", "basic")), color)
		tile.add_child(icon)
	_edit_tip(tile, "equip%d" % part_index, _edit_equipment_tooltip(part, equipped))
	return tile

func _edit_equipment_tooltip(part: String, equipped: Dictionary) -> Dictionary:
	if equipped.is_empty():
		return {
			"title": "%s · 비어 있음" % ItemLibrary.part_name(part),
			"accent": GamePalette.MUTED,
			"rows": [["넣는 법", "보관함 아이템을 여기로 끌기"]],
			"body": "장비는 레일 밖에서 늘 붙어 있는 효과입니다. 스킬 카드는 여기에 들어가지 않습니다."
		}
	var item := ItemLibrary.by_id(String(equipped.get("id", "")))
	return {
		"title": _factory_card_name(equipped),
		"accent": _factory_card_color(equipped),
		"rows": [
			["부위", ItemLibrary.part_name(part)],
			["등급", ItemLibrary.rarity_name(String(item.get("rarity", "common")))],
			["적용", ItemLibrary.effect_scope(item)],
			["효과", ItemLibrary.compact_effect(item)],
			["빼기", "이 부위를 누르면 보관함으로"]
		],
		"body": String(item.get("desc", ""))
	}

## ⑦ 닫기. 옆의 ESC 키캡은 글자가 아니라 **킷 스프라이트**다(U1 규약).
func _build_edit_close(panel: Control) -> void:
	_kit_keycap(panel, Vector2(EDIT_CLOSE_RECT.position.x - 88.0, EDIT_CLOSE_RECT.position.y + 7.0), "esc")
	var close := _button("닫기", GamePalette.YELLOW, EDIT_CLOSE_RECT.size)
	close.name = "EditClose"
	close.position = EDIT_CLOSE_RECT.position
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_factory_menu)
	panel.add_child(close)
	_edit_tip(close, "close", {
		"title": "닫기",
		"accent": GamePalette.YELLOW,
		"rows": [["단축키", "ESC"]],
		"body": "고친 것은 바로 반영되고 바늘은 1번 칸부터 다시 돕니다."
	})

## 칸 손잡이의 호버 내용 — "이걸 끌면 무슨 일이 일어나는가"가 첫 줄이다.
func _edit_slot_tooltip(slot_index: int) -> Dictionary:
	var card := factory.get_card(slot_index)
	var runes: Array = factory.runes_on(slot_index)
	var element := _card_element(card)
	var rows: Array = [
		["카드", _factory_card_name(card)],
		["각인", "%d/%d" % [runes.size(), RuneEngine.RUNE_STACK_CAP]]
	]
	var mark := String(RAIL_ELEMENT_MARK.get(element, ""))
	if not mark.is_empty():
		rows.append(["속성", mark, _element_color(element)])
	rows.append(["끌기", "칸 통째 (각인도 같이)"])
	rows.append(["키보드", "SHIFT + SPACE"])
	return {
		"title": "칸 %02d 손잡이" % (slot_index + 1),
		"accent": GamePalette.MAGENTA,
		"rows": rows,
		"body": "손잡이를 끌면 칸이 통째로 자리를 바꿉니다 — 붙어 있는 각인 %d개가 함께 따라갑니다. 카드만 옮기려면 아래 카드 그림을 끄세요." % runes.size()
	}

## 카드 몸통의 호버 내용 — 랭크·지속·RELOAD·계수·태그가 전부 여기 있다.
func _edit_card_tooltip(slot_index: int) -> Dictionary:
	var card := factory.get_card(slot_index)
	if card.is_empty():
		return {
			"title": "칸 %02d · 빈칸" % (slot_index + 1),
			"accent": GamePalette.MUTED,
			"rows": [["실행", "기본 베기"], ["채우기", "보관함 카드를 끌어 놓기"]],
			"body": "빈칸도 바늘이 지나갑니다 — 카드가 없으면 기본 베기를 한 번 씁니다. 이 칸에 붙은 각인은 빈칸에서도 그대로 굴립니다."
		}
	if String(card.get("kind", "skill")) == "item":
		var tooltip := _edit_inventory_tooltip(card)
		tooltip["body"] = "아이템이 레일에 앉아 있습니다 — 바늘이 지나가도 아무것도 하지 않습니다. 오른쪽 장비 부위로 옮기세요."
		return tooltip
	var ranked := DealCardLibrary.ranked(card)
	var element := _card_element(card)
	var rows: Array = [
		["등급", "R%d" % int(card.get("rank", 1))],
		["지속", "%.2f초" % float(ranked.get("duration", 0.0)), GamePalette.CYAN],
		["RELOAD", "%.2f초" % float(ranked.get("reload", 0.0)), GamePalette.ORANGE],
		["피해 배수", "%.2f" % float(ranked.get("damage", 0.0))]
	]
	var tag := _card_tag_compact(ranked)
	if not tag.is_empty():
		rows.append(["속성 · 형태", tag, _element_color(element)])
	rows.append(["끌기", "카드만 (각인은 칸에 남음)"])
	return {
		"title": _factory_card_name(card),
		"accent": _element_color(element),
		"rows": rows,
		"body": String(ranked.get("desc", ""))
	}

## 각인 핍 줄의 호버 내용 — 구 「각인 스택 상세」 패널이 통째로 여기로 왔다.
func _edit_rune_tooltip(slot_index: int) -> Dictionary:
	var runes: Array = factory.runes_on(slot_index)
	if runes.is_empty():
		return {
			"title": "칸 %02d · 각인 없음" % (slot_index + 1),
			"accent": GamePalette.MUTED,
			"rows": [["얻는 곳", "성의 각인 세공사"], ["", "보물상자 · 균열"]],
			"body": "각인은 카드가 아니라 칸에 붙습니다. 붙으면 바늘이 그 칸을 지날 때마다 확률로 발동해 바늘을 되돌리거나 카드를 한 번 더 실행합니다."
		}
	var rows: Array = []
	var effects: Array[String] = []
	for rune_value in runes:
		var rune: Dictionary = rune_value
		var rune_id := String(rune.get("id", ""))
		var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
		var probability := "확정" if not bool(definition.get("roll", true)) \
			else "%d%%" % int(round(_slot_rune_probability(slot_index, rune_id) * 100.0))
		rows.append([String(definition.get("name", rune_id)), probability, _rune_rarity_color(rune_id)])
		var effect := String(definition.get("effect", ""))
		if not effect.is_empty() and not effects.has(effect):
			effects.append(effect)
	var body := "각인은 카드가 아니라 이 칸에 붙어 있습니다 — 카드만 옮기면 여기 남고, 손잡이로 칸을 옮기면 함께 갑니다."
	if runes.size() > RuneEngine.RUNE_SLOTS_PER_SLOT:
		rows.append(["빽빽함", "모든 확률 ×%.2f" % RuneEngine.congestion_scale(runes.size()), GamePalette.ORANGE])
		body += " 한 칸 %d개를 넘겨 담아 이 칸의 모든 각인 확률이 깎였습니다." % RuneEngine.RUNE_SLOTS_PER_SLOT
	if not effects.is_empty():
		body += "\n" + " · ".join(effects)
	return {
		"title": "칸 %02d 각인 %d/%d" % [slot_index + 1, runes.size(), RuneEngine.RUNE_STACK_CAP],
		"accent": GamePalette.MAGENTA,
		"rows": rows,
		"body": body
	}

# -----------------------------------------------------------------------------
# 편집 조작 — 부록 C-1의 두 제스처가 여기 한 곳으로 모인다
# -----------------------------------------------------------------------------
## X2: `gesture`는 **집은 대상**이 정한다 — 카드 그림을 누르면 "card", 칸 손잡이를
## 누르면 "slot". 빈 문자열이면 지금 기억하고 있는 제스처를 그대로 쓴다(키보드 경로).
## 조작의 의미(move_card / swap_slots)는 한 줄도 안 바뀌었다.
func _editor_slot_pressed(slot_index: int, gesture: String = "") -> void:
	if factory == null or slot_index < 0 or slot_index >= factory.slots.size():
		return
	if not gesture.is_empty():
		factory_edit_mode = gesture
	factory_focus_zone = "rail"
	factory_focus_index = slot_index
	factory_rune_focus_slot = slot_index
	# ① 보관함에서 카드를 골라 둔 상태 → 그 칸에 배치(각인은 그대로 남는다).
	if factory_selected_inventory >= 0 and factory_selected_inventory < factory.inventory.size():
		var picked_card: Dictionary = factory.inventory[factory_selected_inventory]
		if String(picked_card.get("kind", "skill")) == "item":
			_show_banner("아이템은 레일에 놓을 수 없습니다 · 오른쪽 장비 칸으로 보내세요", GamePalette.MAGENTA, 2.2)
			factory_focus_zone = "equipment"
			factory_focus_index = 0
			_show_factory_menu("edit", {}, factory_return_state)
			return
		var selected := factory.remove_inventory_at(factory_selected_inventory)
		var replaced := factory.place_card(slot_index, selected)
		factory.add_inventory(replaced)
		factory_selected_inventory = -1
		_apply_editor_change()
		return
	# ② 두 조작의 2단계 모델. 집기 → 놓기. 같은 칸이면 취소.
	if factory_pick_slot < 0:
		factory_pick_slot = slot_index
		play_sound("choice", -8.0)
		# 상시 안내문("집은 칸 없음 · TAB 영역 전환 · M 조작 모드")을 지운 자리다.
		# 집은 순간에만 뜨는 배너 한 줄 + 칸에 씌워지는 흰 링이 그 몫을 대신한다.
		_show_banner("칸 %02d %s — 놓을 칸을 고르세요 (같은 칸이면 취소)" % [slot_index + 1,
			"통째로 집었습니다 · 각인도 같이" if factory_edit_mode == EDIT_MODE_SLOT else "카드를 집었습니다 · 각인은 칸에"],
			_edit_mode_color(factory_edit_mode), 2.2)
		_show_factory_menu("edit", {}, factory_return_state)
		return
	if factory_pick_slot == slot_index:
		factory_pick_slot = -1
		_show_factory_menu("edit", {}, factory_return_state)
		return
	var source := factory_pick_slot
	factory_pick_slot = -1
	_apply_editor_gesture(source, slot_index)

func _apply_editor_gesture(source_slot: int, target_slot: int) -> void:
	if factory == null or source_slot == target_slot:
		return
	if factory_edit_mode == EDIT_MODE_SLOT:
		# [칸 위치 교환] — 각인이 함께 따라간다 (부록 C-1)
		if factory.swap_slots(source_slot, target_slot):
			_show_banner("칸 %02d ⇄ 칸 %02d · 각인까지 함께 이동" % [source_slot + 1, target_slot + 1], GamePalette.MAGENTA, 1.8)
	else:
		# [카드 이동/교체] — 각인은 원래 칸에 남는다 (부록 C-1)
		if factory.move_card(source_slot, target_slot):
			_show_banner("카드 %02d ↔ %02d · 각인은 칸에 그대로" % [source_slot + 1, target_slot + 1], GamePalette.CYAN, 1.8)
	_apply_editor_change()

func _editor_equipment_pressed(part_index: int) -> void:
	if factory == null or part_index < 0 or part_index >= FactoryDeck.EQUIPMENT_PARTS.size():
		return
	factory_focus_zone = "equipment"
	factory_focus_index = part_index
	var part := FactoryDeck.EQUIPMENT_PARTS[part_index]
	if factory_selected_inventory >= 0 and factory_selected_inventory < factory.inventory.size():
		var candidate: Dictionary = factory.inventory[factory_selected_inventory]
		if String(candidate.get("kind", "skill")) != "item":
			_show_banner("스킬 카드는 장비 칸에 넣을 수 없습니다 · 레일 칸으로 보내세요", GamePalette.YELLOW, 2.0)
			_show_factory_menu("edit", {}, factory_return_state)
			return
		# Y4(피드백 ⑫): 이미 낀 것이 있으면 **묻고 나서** 바꾼다.
		if not _request_equip_swap(factory_selected_inventory):
			return
		var moving := factory.remove_inventory_at(factory_selected_inventory)
		factory_selected_inventory = -1
		var displaced := factory.equip(moving)
		factory.add_inventory(displaced)
		_apply_editor_change()
		return
	var equipped := factory.equipped_at(part)
	if equipped.is_empty():
		_show_banner("%s 칸이 비어 있습니다 · 보관함의 ▤ 아이템을 골라 넣으세요" % ItemLibrary.part_name(part), GamePalette.MUTED, 2.0)
		_show_factory_menu("edit", {}, factory_return_state)
		return
	for index in factory.equipment.size():
		if String(FactoryDeck.equipment_part(factory.equipment[index])) == part:
			factory.add_inventory(factory.unequip(index))
			break
	_apply_editor_change()

# =============================================================================
# Y4 — 장비 교체 확인 「바꾸기 / 그대로」 (피드백 ⑫ · FEEDBACK_Y §8 ⑫)
# =============================================================================
# 사용자 원문 요지: "이미 착용 중이면 착용 카드와 새 카드를 나란히 보여 주고
# 바꿀지 물어봐 줘." 지금까지는 부위를 누르거나 끌어 놓는 순간 **조용히** 덮어썼고,
# 밀려난 장비가 보관함 어딘가로 들어가 무엇이 사라졌는지 알 방법이 없었다.
#
# ▸ **새 state를 만들지 않았다.** 화면은 여전히 `factory_menu`이고 `equip_swap`
#   한 값이 열고 닫는다 — 새 state를 만들면 편집 화면 복귀 경로(`factory_return_state`)와
#   포커스 복원까지 전부 두 벌이 된다. `_handle_factory_keyboard`가 맨 앞에서
#   이 값을 보고 키를 가로챈다.
# ▸ **아무것도 미리 옮기지 않는다.** 확인을 누른 뒤에야 `remove_inventory_at`이 돈다 —
#   취소했을 때 보관함 순서가 흔들리지 않아야 "그대로"가 진짜 그대로가 된다.
# ▸ §6.3의 소비 아이템 교체(Y6)가 **이 함수를 그대로 쓴다.** 그때는 `part` 자리에
#   소비 슬롯 이름이 들어갈 것이고 카드 두 장을 나란히 놓는 기하는 손댈 필요가 없다.
## ⚠️ 카드는 **`CHOICE_CARD_SIZE` 그대로**여야 한다. 처음에 400×268로 줄여 봤더니
## `_build_choice_card_body()`의 자리값(정보 열 시작 228 · 요약 줄 폭)이 510 기준이라
## 부위 배지와 요약 줄이 카드 밖으로 잘려 나갔다(캡처 실측). 공유 렌더러를 쓰는 값은
## 공유 크기로 쓴다 — 판을 넓히는 쪽이 옳다.
const EQUIP_SWAP_RECT := Rect2(80.0, 110.0, 1120.0, 500.0)
const EQUIP_SWAP_CARD := CHOICE_CARD_SIZE

var equip_swap: Dictionary = {}

## 끼우려는 아이템이 이미 찬 부위로 간다면 확인 화면을 띄우고 **false**를 돌려준다
## (호출부는 즉시 멈춘다). 빈 부위면 물을 것이 없으므로 true.
func _request_equip_swap(inventory_index: int) -> bool:
	if factory == null or inventory_index < 0 or inventory_index >= factory.inventory.size():
		return true
	var incoming: Dictionary = factory.inventory[inventory_index]
	if String(incoming.get("kind", "skill")) != "item":
		return true
	var part := FactoryDeck.equipment_part(incoming)
	var current := factory.equipped_at(part)
	if current.is_empty():
		return true
	_show_equip_swap_confirm(part, current, incoming, inventory_index)
	return false

## Y6: 껍데기·머리말·화살표·두 버튼·꼬리말은 **소비 아이템 교체와 공유한다**(§6.3).
## 카드 두 장을 어떤 렌더러로 그리느냐만 호출부가 정한다 — 노드 이름은 두 화면이
## 같아야 한다(`--v4-test`가 `EquipSwapPanel`/`Accept`/`Cancel`을 이름으로 문다).
func _build_swap_confirm_shell(title: String, left_title: String, right_title: String,
		footer: String, accept_action: Callable, cancel_action: Callable,
		overlay_name: String = "EquipSwap") -> Panel:
	_clear_overlay()
	overlay = Control.new()
	overlay.name = overlay_name
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	var panel := _kit_shell(overlay, EQUIP_SWAP_RECT, title,
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 420.0)
	panel.name = "EquipSwapPanel"
	_kit_label(panel, Rect2(24.0, 64.0, EQUIP_SWAP_CARD.x, 26.0), left_title,
		UIKit.Tone.SLATE, UIKit.FONT_HEADING, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_kit_label(panel, Rect2(EQUIP_SWAP_RECT.size.x - 24.0 - EQUIP_SWAP_CARD.x, 64.0, EQUIP_SWAP_CARD.x, 26.0),
		right_title, UIKit.Tone.SLATE, UIKit.FONT_HEADING, false, UIKit.Role.PANEL,
		HORIZONTAL_ALIGNMENT_CENTER)
	# 화살표 한 글자가 "왼쪽이 오른쪽으로 바뀐다"를 말한다. 문장을 쓰지 않는다.
	var arrow := _label("▶", UI_TITLE_SIZE, GamePalette.MAGENTA)
	arrow.position = Vector2(EQUIP_SWAP_RECT.size.x * 0.5 - 30.0, 202.0)
	arrow.size = Vector2(60.0, 40.0)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(arrow)
	var swap_button := _button("바꾸기", GamePalette.MAGENTA, Vector2(240.0, 52.0))
	swap_button.name = "EquipSwapAccept"
	swap_button.position = Vector2(EQUIP_SWAP_RECT.size.x * 0.5 - 260.0, 386.0)
	swap_button.pressed.connect(accept_action)
	panel.add_child(swap_button)
	var keep := _button("그대로", GamePalette.MUTED, Vector2(240.0, 52.0))
	keep.name = "EquipSwapCancel"
	keep.position = Vector2(EQUIP_SWAP_RECT.size.x * 0.5 + 20.0, 386.0)
	keep.pressed.connect(cancel_action)
	panel.add_child(keep)
	_kit_label(panel, Rect2(0.0, EQUIP_SWAP_RECT.size.y - 46.0, EQUIP_SWAP_RECT.size.x, 22.0),
		footer, UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 16.0))
	swap_button.grab_focus()
	return panel

func _show_equip_swap_confirm(part: String, current: Dictionary, incoming: Dictionary,
		inventory_index: int) -> void:
	equip_swap = {"part": part, "index": inventory_index}
	factory_selected_inventory = -1
	# YZ: 부위 이름 넷(무기 · 목걸이 · 반지 · 팔찌)이 **전부 받침 없이 끝난다** —
	#     조사는 언제나 「를」이라 하드코딩이 안전하다. 부위를 늘리면 여기를 다시 볼 것.
	var panel := _build_swap_confirm_shell("%s를 바꿀까요?" % ItemLibrary.part_name(part),
		"지금 낀 것", "새로 끼울 것",
		"밀려난 장비는 보관함으로 돌아갑니다   ·   SPACE 바꾸기   ·   ESC 그대로",
		_confirm_equip_swap, _cancel_equip_swap, "EquipSwap")
	# 두 카드는 **같은 렌더러 · 같은 크기**여야 비교가 성립한다.
	var left := _item_choice_button(ItemLibrary.by_id(String(current.get("id", ""))), EQUIP_SWAP_CARD)
	left.name = "EquipSwapCurrent"
	left.position = Vector2(24.0, 96.0)
	left.disabled = true
	panel.add_child(left)
	var right := _item_choice_button(ItemLibrary.by_id(String(incoming.get("id", ""))), EQUIP_SWAP_CARD)
	right.name = "EquipSwapIncoming"
	right.position = Vector2(EQUIP_SWAP_RECT.size.x - 24.0 - EQUIP_SWAP_CARD.x, 96.0)
	right.disabled = true
	panel.add_child(right)
	if automated_test:
		call_deferred("_confirm_equip_swap")

func _confirm_equip_swap() -> void:
	if equip_swap.is_empty() or factory == null:
		return
	var index := int(equip_swap.get("index", -1))
	equip_swap = {}
	if index < 0 or index >= factory.inventory.size():
		_show_factory_menu("edit", {}, factory_return_state)
		return
	var moving := factory.remove_inventory_at(index)
	factory.add_inventory(factory.equip(moving))
	_apply_editor_change()

func _cancel_equip_swap() -> void:
	if equip_swap.is_empty():
		return
	equip_swap = {}
	_show_factory_menu("edit", {}, factory_return_state)

# 편집이 확정된 순간 = 미리보기를 다시 계산할 유일한 시점.
func _apply_editor_change() -> void:
	_reset_player_cycle()
	play_sound("choice", -5.0)
	_refresh_factory_preview(true)
	_show_factory_menu("edit", {}, factory_return_state)

func _clamp_factory_focus() -> void:
	if factory_focus_zone == "inventory" and factory_inventory_buttons.is_empty():
		factory_focus_zone = "rail"
	if factory_focus_zone == "equipment" and factory_equipment_buttons.is_empty():
		factory_focus_zone = "rail"
	var limit := factory_lane_buttons.size()
	if factory_focus_zone == "inventory":
		limit = factory_inventory_buttons.size()
	elif factory_focus_zone == "equipment":
		limit = factory_equipment_buttons.size()
	factory_focus_index = clampi(factory_focus_index, 0, maxi(0, limit - 1))
	if factory_focus_zone == "rail" and factory_focus_index < factory_lane_coordinates.size():
		factory_rune_focus_slot = factory_lane_coordinates[factory_focus_index].x

func _show_factory_menu(mode: String = "edit", acquired_card: Dictionary = {}, return_state_override: String = "") -> void:
	if not is_instance_valid(player) or factory == null:
		return
	equip_swap = {}      # Y4: 교체 확인은 이 화면이 다시 그려지는 순간 끝난다
	if mode == "edit":
		if not return_state_override.is_empty():
			factory_return_state = return_state_override
		elif state != "factory_menu":
			factory_return_state = state
	elif not return_state_override.is_empty():
		factory_return_state = return_state_override
	factory_mode = mode
	pending_factory_card = acquired_card.duplicate(true)
	factory_lane_buttons.clear()
	factory_lane_coordinates.clear()
	factory_inventory_buttons.clear()
	factory_inventory_indices.clear()
	factory_equipment_buttons.clear()
	factory_tooltip_layer = null
	factory_tooltip_targets.clear()
	# W6: edit 모드는 v2 편집 화면(5칸 무스크롤 레일 + 흐름 아크 + 두 조작)으로 간다.
	# 나머지 3모드(place / upgrade / build)는 v1 레이아웃을 그대로 쓴다 — 마왕 프리뷰·
	# 결과 화면과 렌더러(_build_factory_rail_slot)를 공유하므로 건드리지 않는다(W10 소유).
	if mode == "edit":
		_build_deck_editor()
		return
	factory_editor_open = false
	factory_pick_slot = -1
	factory_focus_zone = "rail"
	factory_focus_index = 0
	factory_selected_inventory = -1
	state = "factory_place" if mode == "place" else "factory_upgrade" if mode.begins_with("upgrade") else "factory_build"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "DealCycleFactory"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)

	var title_text := "딜싸이클 공장 · 전체 레일"
	var subtitle_text := "카드를 끌어 놓아 교체 · 빈칸은 기본 베기 · 각인은 칸에 붙고 칸을 옮기면 함께 이동 · 아이템은 레일 밖 장비"
	if mode == "place":
		title_text = "새 카드 · 바꿀 칸을 고르세요"
		subtitle_text = "%s 카드를 배치하면 즉시 필드로 돌아갑니다." % _factory_card_name(acquired_card)
	elif mode == "build":
		title_text = "칸이 하나 늘었습니다"
		subtitle_text = "딜싸이클 업그레이드로 레일 부품을 한 조각 추가했습니다."
	elif mode.begins_with("upgrade"):
		title_text = "칸 강화 · 어느 칸에 걸까요"
		subtitle_text = _factory_upgrade_description(pending_factory_upgrade)
	# U2 v3: 편집 화면과 같은 골격 — SLATE 껍데기 + WOOD 리본 + 함몰 머리말 띠.
	var panel := _kit_shell(overlay, Rect2(20.0, 16.0, 1240.0, 688.0), title_text,
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 520.0)
	_kit_panel(panel, Rect2(28.0, 40.0, 1184.0, 44.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	var status := _label("칸 %d/%d · 각인 %d개 · 장비 %d/%d" % [factory.slots.size(), FactoryDeck.SLOT_COUNT, factory.total_rune_count(), factory.equipment.size(), FactoryDeck.EQUIPMENT_PARTS.size()], UI_LABEL_SIZE, GamePalette.CYAN)
	status.position = Vector2(44.0, 43.0)
	status.size = Vector2(620.0, 20.0)
	panel.add_child(status)
	# 레일 끝 마감 패널은 3차 피드백⑬으로 제거했습니다. 총 RELOAD는 이 머리말 표기가 유일한 자리입니다.
	var reload_readout := _label("한 바퀴 RELOAD 빚 %.2f초" % factory.total_reload(), UI_HEADING_SIZE, GamePalette.ORANGE)
	reload_readout.position = Vector2(676.0, 42.0)
	reload_readout.size = Vector2(520.0, 22.0)
	reload_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(reload_readout)
	var subtitle := _label(subtitle_text, UI_BODY_SIZE, GamePalette.YELLOW if mode != "edit" else GamePalette.MUTED)
	subtitle.position = Vector2(44.0, 62.0)
	subtitle.size = Vector2(1152.0, 20.0)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(subtitle)
	if mode != "place":
		var rail_guide := _label("5칸 고정 레일 · 각인은 칸에 붙습니다 · 빈칸은 기본 베기", UI_CAPTION_SIZE, GamePalette.MUTED.darkened(0.22))
		rail_guide.position = Vector2(28.0, 126.0)
		rail_guide.size = Vector2(1184.0, 24.0)
		rail_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(rail_guide)

	# 레일 패널은 1280×720 화면의 세로·가로 정중앙에 놓입니다.
	var rail_panel := Panel.new()
	rail_panel.position = Vector2(28.0, FACTORY_RAIL_PANEL_TOP)
	rail_panel.size = Vector2(1184.0, FACTORY_RAIL_PANEL_H)
	UIKit.style_panel(rail_panel, UIKit.Tone.SLATE, UIKit.Role.INSET)
	panel.add_child(rail_panel)
	# Y4(피드백 ⑦): 칸마다 있던 머리 줄이 사라진 자리에 **5칸 미니 레일 하나**가 선다.
	# 5칸 고정이라 가로 스크롤이 발생하지 않으므로(내용 1,000px ⊂ 1,160px) 이 띠가
	# 스크롤 영역 위를 덮어도 카드와 겹치지 않는다.
	_build_place_mini_rail(rail_panel, Rect2(12.0, 6.0, 1160.0, 24.0))
	var rail_scroll := ScrollContainer.new()
	rail_scroll.position = Vector2(12.0, 12.0)
	rail_scroll.size = Vector2(1160.0, FACTORY_RAIL_PANEL_H - 24.0)
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_panel.add_child(rail_scroll)
	factory_rail_scroll = rail_scroll
	var rail := HBoxContainer.new()
	var rail_slots := factory.slots.size()
	var content_width := float(rail_slots) * FACTORY_RAIL_CARD_W + float(maxi(0, rail_slots - 1)) * FACTORY_RAIL_BRIDGE_W
	rail.custom_minimum_size = Vector2(maxf(content_width, rail_scroll.size.x), FACTORY_RAIL_ROW_H)
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_theme_constant_override("separation", 0)
	rail_scroll.add_child(rail)
	# v2는 5칸 고정이라 미건설 자리표시자·건설 중 다리가 없다. 다리는 칸 사이 연결선뿐이다.
	for slot_index in rail_slots:
		_build_factory_rail_slot(rail, slot_index)
		if slot_index < rail_slots - 1:
			_build_factory_rail_bridge(rail, "built")

	if mode == "place":
		var pending_panel := Panel.new()
		pending_panel.position = Vector2(28.0, 92.0)
		pending_panel.size = Vector2(1184.0, 74.0)
		UIKit.style_panel(pending_panel, UIKit.Tone.SLATE, UIKit.Role.INSET)
		panel.add_child(pending_panel)
		_build_pending_card_summary(pending_panel, acquired_card)
		var place_hint := _label("방향키로 칸 선택 · SPACE로 배치 · 교체된 카드는 보관함으로 이동", UI_HEADING_SIZE - 2, GamePalette.YELLOW)
		place_hint.position = Vector2(180.0, 560.0)
		place_hint.size = Vector2(870.0, 30.0)
		place_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(place_hint)
		# 아이템 카드는 보관함 직행인데 스킬 카드만 레일에 강제 배치되던 규칙 차이를 없앱니다.
		var store := _button("ESC · 보관함에 넣기", GamePalette.CYAN, Vector2(214.0, 36.0))
		store.position = Vector2(992.0, 650.0)
		store.pressed.connect(_store_pending_factory_card)
		panel.add_child(store)
	elif mode == "build":
		var built_piece := String(acquired_card.get("piece", "bridge"))
		var built_name := "연결 다리" if built_piece == "bridge" else "새 딜싸이클 칸"
		var build_icon := GENERATED_UI_ICON_SCRIPT.new()
		build_icon.position = Vector2(566.0, 528.0)
		build_icon.size = Vector2(108.0, 108.0)
		build_icon.pivot_offset = build_icon.size * 0.5
		build_icon.scale = Vector2(0.18, 0.18)
		build_icon.modulate = Color(1.0, 0.66, 0.18, 0.0)
		build_icon.setup("bridge" if built_piece == "bridge" else "slot_active")
		panel.add_child(build_icon)
		var build_result := _label("%s! 딜싸이클 끝에 붙이는 중…" % built_name, 20, GamePalette.ORANGE)
		build_result.position = Vector2(180.0, 640.0)
		build_result.size = Vector2(870.0, 40.0)
		build_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(build_result)
		var build_tween := build_icon.create_tween()
		build_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		build_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		build_tween.parallel().tween_property(build_icon, "scale", Vector2.ONE, 0.52)
		build_tween.parallel().tween_property(build_icon, "modulate", Color.WHITE, 0.28)
		build_tween.tween_property(build_icon, "scale", Vector2(1.08, 1.08), 0.16)
		build_tween.tween_property(build_icon, "scale", Vector2.ONE, 0.16)
		call_deferred("_auto_close_factory_build")
	else:
		var upgrade_hint := _label("강화할 칸을 선택하세요 · 같은 칸을 두 번 분열하면 카드 3장이 동시에 실행됩니다.", UI_HEADING_SIZE, GamePalette.ORANGE)
		upgrade_hint.position = Vector2(145.0, 548.0)
		upgrade_hint.size = Vector2(940.0, 52.0)
		upgrade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(upgrade_hint)
		if mode.begins_with("upgrade"):
			# 적용 가능한 칸이 없을 때 갇히지 않도록 항상 환불 취소 경로를 둡니다.
			var cancel := _button("ESC · 강화 취소 (%d G 환불)" % factory_upgrade_refund, GamePalette.MUTED, Vector2(214.0, 36.0))
			cancel.position = Vector2(992.0, 650.0)
			cancel.pressed.connect(_cancel_factory_upgrade)
			panel.add_child(cancel)
	_animate_modal(panel, Vector2(0.0, 16.0))
	_update_factory_focus()

## Y4(피드백 ⑦) — 배치·강화 화면 상단의 5칸 미니 레일.
## HUD 미니 스트립과 같은 그림이다: 칸마다 원소색 칩 하나 + 사이를 잇는 실선.
## 글자는 **칸 번호 한 자리**뿐이고, 각인은 칩 아래 점으로만 센다.
func _build_place_mini_rail(parent: Control, rect: Rect2) -> void:
	if factory == null or factory.slots.is_empty():
		return
	var strip := Control.new()
	strip.name = "PlaceMiniRail"
	strip.position = rect.position
	strip.size = rect.size
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(strip)
	var count := factory.slots.size()
	var cell_w := 40.0
	var gap := 10.0
	var span := cell_w * float(count) + gap * float(count - 1)
	var left := floorf((rect.size.x - span) * 0.5)
	# 칸 사이를 잇는 실선 하나 — "이것들이 한 바퀴 도는 순서다"를 선이 말한다.
	var spine := ColorRect.new()
	spine.position = Vector2(left + cell_w * 0.5, 10.0)
	spine.size = Vector2(span - cell_w, 2.0)
	spine.color = FACTORY_RAIL_SPINE_BUILT
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(spine)
	for index in count:
		var card := factory.get_card(index)
		var at := Vector2(left + float(index) * (cell_w + gap), 0.0)
		var chip := ColorRect.new()
		chip.name = "PlaceMiniSlot%d" % index
		chip.position = at
		chip.size = Vector2(cell_w, 20.0)
		chip.color = Color(_rail_slot_color(card), 0.34 if card.is_empty() else 0.62)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(chip)
		var number := _label("%d" % (index + 1), UI_CAPTION_SIZE, GamePalette.TEXT)
		number.position = at
		number.size = Vector2(cell_w, 20.0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		strip.add_child(number)
		# 각인 수는 칩 아래 2px 점으로만 센다(카드 위 핍과 같은 규칙).
		var runes: int = factory.runes_on(index).size()
		for pip_index in runes:
			var pip := ColorRect.new()
			pip.position = at + Vector2(6.0 + float(pip_index) * 6.0, 21.0)
			pip.size = Vector2(4.0, 3.0)
			pip.color = GamePalette.MAGENTA
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.add_child(pip)

func _factory_rail_cell(width: float, spine_color: Color) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(width, FACTORY_RAIL_ROW_H)
	cell.size = Vector2(width, FACTORY_RAIL_ROW_H)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	# 모든 셀을 가로지르는 레일 본선입니다. 카드 사이 틈으로 이어져 보이게 가장 먼저 깔립니다.
	var spine := ColorRect.new()
	spine.position = Vector2(0.0, FACTORY_RAIL_LINE_Y - 3.0)
	spine.size = Vector2(width, 6.0)
	spine.color = spine_color
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(spine)
	return cell

func _factory_lane_card_height(lane_count: int) -> float:
	if lane_count <= 1:
		return 142.0
	var usable := FACTORY_RAIL_LANE_AREA - FACTORY_RAIL_LANE_GAP * float(lane_count - 1)
	return floorf(usable / float(lane_count))

func _build_factory_rail_slot(rail: HBoxContainer, slot_index: int, interactive: bool = true, deck: FactoryDeck = null) -> void:
	# interactive=false는 결과 모달·마왕 딜싸이클 미리보기처럼 읽기 전용으로 같은 레일을 그릴 때
	# 사용합니다. 이 경우 포커스 배열 등록·클릭·드래그를 모두 건너뛰어 공장 화면의 상태를 오염시키지
	# 않습니다. deck을 주면 플레이어 공장 대신 그 덱(예: boss_factory)을 그립니다.
	var source_deck: FactoryDeck = deck if deck != null else factory
	var slot: Dictionary = source_deck.slots[slot_index]
	var slot_card: Dictionary = slot.get("card", {})
	var slot_runes: Array = slot.get("runes", [])
	var cell := _factory_rail_cell(FACTORY_RAIL_CARD_W, FACTORY_RAIL_SPINE_BUILT)
	rail.add_child(cell)
	var upgrade_marks: Array[String] = []
	if not slot_runes.is_empty(): upgrade_marks.append("각인 %d" % slot_runes.size())
	if int(slot.get("repeat", 1)) > 1: upgrade_marks.append("×2")
	if float(slot.get("duration_mul", 1.0)) < 0.99: upgrade_marks.append("속도")
	if float(slot.get("reload_mul", 1.0)) < 0.99: upgrade_marks.append("RELOAD")
	# =========================================================================
	# Y4 — 「칸 01~05 아이콘 행」 삭제 (피드백 ⑦ · FEEDBACK_Y §8 ⑦)
	# =========================================================================
	# 구판은 칸마다 머리 줄(24px 아이콘 + 「칸 01 · 각인 2 · ×2 · 속도」)을 세웠다.
	# 5칸이 나란히 서면 화면 위쪽에 **같은 아이콘 다섯 개가 한 줄**로 늘어서는데,
	# 그 다섯은 서로 아무것도 구분해 주지 않는다(전부 `slot_active` 한 장이다).
	# 줄은 통째로 사라지고 그 자리를 패널 상단의 **5칸 미니 레일**이 대신한다
	# (`_build_place_mini_rail` — HUD 미니 스트립과 같은 그림 언어).
	# 강화 표기(각인 N · ×2 · 속도)는 카드 자체가 이미 각인 핍으로 말하고 있어
	# 여기서만 두 번 적히던 것이다. 미니 레일 칸에 점으로 남는다.
	cell.set_meta("upgrade_marks", upgrade_marks)
	# v2: 칸 1개 = 카드 1장. lane_index는 항상 0이며 시그니처 호환으로만 남아 있다.
	var card_height := _factory_lane_card_height(1)
	var card_y := FACTORY_RAIL_LANE_TOP + (FACTORY_RAIL_LANE_AREA - card_height) * 0.5
	var button := _factory_lane_button(slot_card, 0, 1)
	button.position = Vector2(FACTORY_RAIL_CARD_INSET, card_y)
	if interactive:
		button.pressed.connect(_factory_lane_pressed.bind(slot_index, 0))
		if factory_mode == "edit":
			button.set("drag_payload", {"zone":"rail", "slot":slot_index, "lane":0, "has_card":not slot_card.is_empty(), "name":_factory_card_name(slot_card)})
			button.connect("factory_card_dropped", _on_factory_card_dropped)
	else:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
	cell.add_child(button)
	if interactive:
		factory_lane_buttons.append(button)
		factory_lane_coordinates.append(Vector2i(slot_index, 0))

func _build_factory_rail_ghost_slot(rail: HBoxContainer, slot_index: int) -> void:
	# 미건설 자리표시자입니다. 포커스·드래그 대상이 아니며 클릭할 수 없습니다.
	var cell := _factory_rail_cell(FACTORY_RAIL_CARD_W, FACTORY_RAIL_SPINE_GHOST)
	rail.add_child(cell)
	var header := _label("칸 %02d" % [slot_index + 1], UI_LABEL_SIZE, Color("5a6472"))
	header.position = Vector2(0.0, FACTORY_RAIL_HEADER_TOP)
	header.size = Vector2(FACTORY_RAIL_CARD_W, FACTORY_RAIL_HEADER_H)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(header)
	var ghost_height := _factory_lane_card_height(1)
	var ghost_top := FACTORY_RAIL_LANE_TOP + (FACTORY_RAIL_LANE_AREA - ghost_height) * 0.5
	var ghost_width := FACTORY_RAIL_CARD_W - FACTORY_RAIL_CARD_INSET * 2.0
	var ghost := Panel.new()
	ghost.position = Vector2(FACTORY_RAIL_CARD_INSET, ghost_top)
	ghost.size = Vector2(ghost_width, ghost_height)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_panel(ghost, UIKit.Tone.SLATE, UIKit.Role.CELL)
	cell.add_child(ghost)
	var ghost_icon := GENERATED_UI_ICON_SCRIPT.new()
	ghost_icon.position = Vector2((FACTORY_RAIL_CARD_W - 42.0) * 0.5, ghost_top + 20.0)
	ghost_icon.size = Vector2(42.0, 42.0)
	ghost_icon.modulate = Color(1.0, 1.0, 1.0, 0.24)
	ghost_icon.setup("slot_empty")
	cell.add_child(ghost_icon)
	var note := _label("아직 없음", UI_BODY_SIZE, Color("6b7684"))
	note.position = Vector2(FACTORY_RAIL_CARD_INSET, ghost_top + 72.0)
	note.size = Vector2(ghost_width, 22.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(note)
	var unlock := _label("공장 부품으로 엽니다", 10, Color("515b69"))
	unlock.position = Vector2(FACTORY_RAIL_CARD_INSET, ghost_top + 98.0)
	unlock.size = Vector2(ghost_width, 18.0)
	unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(unlock)

func _build_factory_rail_bridge(rail: HBoxContainer, bridge_state: String) -> void:
	var line_color := FACTORY_RAIL_SPINE_GHOST
	if bridge_state == "built":
		line_color = FACTORY_RAIL_SPINE_BUILT
	elif bridge_state == "building":
		line_color = GamePalette.ORANGE.darkened(0.2)
	var cell := _factory_rail_cell(FACTORY_RAIL_BRIDGE_W, line_color)
	rail.add_child(cell)
	# 3차 피드백⑫: 다리는 어두운 사각 패널 없이 스프라이트만 스파인 위에 얹습니다.
	# 프레임 제거는 generated_ui_icon.gd의 런타임 트리밍이 담당하고, 여기서는
	# 다리의 실제 가로:세로 비율에 맞는 사각형만 잡아 줍니다. 고스트는 딤 처리만 다릅니다.
	var icon := GENERATED_UI_ICON_SCRIPT.new()
	icon.position = Vector2((FACTORY_RAIL_BRIDGE_W - FACTORY_RAIL_BRIDGE_SPRITE.x) * 0.5, FACTORY_RAIL_LINE_Y - FACTORY_RAIL_BRIDGE_SPRITE.y * 0.5)
	icon.size = FACTORY_RAIL_BRIDGE_SPRITE
	icon.setup("bridge")
	if bridge_state == "built":
		icon.modulate = Color.WHITE
	elif bridge_state == "building":
		icon.modulate = GamePalette.ORANGE
	else:
		icon.modulate = Color(1.0, 1.0, 1.0, 0.22)
	cell.add_child(icon)
	if bridge_state != "building":
		return
	var under_construction := _label("연결 다리", 10, GamePalette.ORANGE)
	under_construction.position = Vector2(-10.0, FACTORY_RAIL_LINE_Y + 26.0)
	under_construction.size = Vector2(FACTORY_RAIL_BRIDGE_W + 20.0, 18.0)
	under_construction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(under_construction)
	# ✅ U2가 삭제한 루프 트윈 1건 (ui-style-v3 §11 "알려진 위반" · AGENTS.md §3-9 · §13-8).
	# `create_tween().set_loops()`로 다리 아이콘을 0.45초마다 깜빡이게 하던 코드가
	# 프로젝트에 남은 마지막 무한 반복 트윈이었다. 이식하지 않고 **삭제**했다.
	# "건설 중"은 어차피 1.8초 뒤 `_auto_close_factory_build()`가 닫는 정지 화면이라
	# 상태 자체가 이미 한시적이다 — 반복 연출 없이 1회성 등장 페이드로 충분하다.
	icon.modulate.a = 0.0
	var appear := icon.create_tween()
	appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	appear.tween_property(icon, "modulate:a", 1.0, 0.24)

func _build_factory_inventory(panel: Control) -> void:
	var inventory_panel := Panel.new()
	inventory_panel.position = Vector2(28.0, 517.0)
	inventory_panel.size = Vector2(1184.0, 130.0)
	UIKit.style_panel(inventory_panel, UIKit.Tone.SLATE, UIKit.Role.INSET)
	panel.add_child(inventory_panel)
	_kit_glyph(inventory_panel, Vector2(12.0, 7.0), "bag", Color.WHITE, 18.0)
	var heading := _label("카드 보관함 · %d장" % factory.inventory.size(), UI_BODY_SIZE, GamePalette.CYAN)
	heading.position = Vector2(36.0, 6.0)
	heading.size = Vector2(1100.0, 21.0)
	inventory_panel.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10.0, 30.0)
	scroll.size = Vector2(1164.0, 94.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_panel.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	scroll.add_child(row)
	if factory.inventory.is_empty():
		var empty := _label("아직 보관한 카드가 없습니다. 레벨업·상점·보물상자에서 카드를 얻으세요.", 15, GamePalette.MUTED)
		empty.custom_minimum_size = Vector2(900.0, 76.0)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(empty)
		return
	for index in factory.inventory.size():
		var card: Dictionary = factory.inventory[index]
		var button := _factory_card_button(card, Vector2(190.0, 92.0))
		button.pressed.connect(_factory_inventory_pressed.bind(index))
		button.set("drag_payload", {"zone":"inventory", "index":index, "has_card":true, "name":_factory_card_name(card)})
		button.connect("factory_card_dropped", _on_factory_card_dropped)
		row.add_child(button)
		factory_inventory_buttons.append(button)
		factory_inventory_indices.append(index)

func _factory_lane_button(card: Dictionary, lane_index: int, lane_count: int) -> Button:
	var prefix := "" if lane_count == 1 else String.chr(65 + lane_index)
	return _factory_card_button(card, Vector2(FACTORY_RAIL_CARD_W - FACTORY_RAIL_CARD_INSET * 2.0, _factory_lane_card_height(lane_count)), prefix)

## U2 v3: 레일·보관함 카드는 **킷 카드 프레임**을 입는다(§6). 스킬 = SKILL(WOOD·마름모),
## 아이템 = ITEM(SLATE·상자). 빈칸은 카드가 아니라 **칸**이므로 CELL 패널로 남긴다 —
## "카드가 없다"와 "약한 카드가 있다"가 색이 아니라 기하로 갈려야 한다.
##
## `inner = true`는 **이미 카드 프레임 안에** 앉는 버튼용이다(편집 화면 5칸 — 거기서는
## 칸 자체가 카드 프레임을 쓴다). 프레임을 두 겹 쌓으면 196×150 안에서 내용이 안 산다.
func _factory_card_button(card: Dictionary, card_size: Vector2, lane_prefix: String = "",
		inner: bool = false) -> Button:
	var color := GamePalette.STONE_LIGHT if card.is_empty() else _factory_card_color(card)
	var button: Button = FACTORY_DRAG_BUTTON_SCRIPT.new()
	_style_button(button, "", color, card_size)
	if inner:
		var chip_box := UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CHIP)
		button.add_theme_stylebox_override("normal", chip_box)
		button.add_theme_stylebox_override("hover", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CELL))
		button.add_theme_stylebox_override("pressed", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
		button.add_theme_stylebox_override("disabled", chip_box)
		button.add_theme_stylebox_override("focus", UIKit.focus_box())
	elif card.is_empty():
		var empty_box := UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.CELL)
		button.add_theme_stylebox_override("normal", empty_box)
		button.add_theme_stylebox_override("hover", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
		button.add_theme_stylebox_override("pressed", UIKit.panel_box(UIKit.Tone.SLATE, UIKit.Role.INSET))
		button.add_theme_stylebox_override("disabled", empty_box)
		button.add_theme_stylebox_override("focus", UIKit.focus_box())
	else:
		_kit_card_skin(button, 1 if String(card.get("kind", "skill")) == "item" else 0)
		button.set_meta("kit_frame_pad", CARD_BLOCK_PAD_FRAMED)
	button.tooltip_text = _factory_card_detail(card)
	_paint_card_block(button, card, card_size, lane_prefix)
	return button

# -----------------------------------------------------------------------------
# 표준 카드 블록 (2026-08-04 3차 피드백 ⑳)
# -----------------------------------------------------------------------------
# 사용자 요구 원문: "새로 얻은 카드와 기존 카드의 형태가 달라서 지속시간하고 RELOAD 비교가
# 힘들어. 같은 형태의 블록으로 만들어줘."
# 공장 레일 카드·보관함 카드·선택 모달 카드가 모두 이 함수 하나로 그려지므로
# 아이콘 위치, 이름·랭크 줄, 지속/R 칩의 크기·글꼴·색이 픽셀 단위로 같다.
# 선택 모달은 이 블록을 그대로 얹고 설명·보유 장수 같은 부가 정보만 바깥에 붙인다.
## U2 v3: 안쪽 여백이 하드코딩 8에서 **호스트의 프레임 두께**를 따라가게 바뀌었다.
## 킷 9-slice 여백은 칩·칸 10 · 카드 **16**이라 예전 8px 자리에 그리면 아이콘과
## 게이지가 프레임 위에 얹힌다. 호스트가 `kit_frame_pad` meta를 들고 있으면 그 값을,
## 없으면 칸·칩용 기본값(11)을 쓴다. 크기·글꼴·줄 수·세 단계 밀도는 그대로다
## (⑳ 규약 유지 — 레일·보관함·선택 모달의 카드가 여전히 같은 그림이다).
const CARD_BLOCK_PAD := 11.0
const CARD_BLOCK_PAD_FRAMED := 18.0   # 카드 프레임(여백 16) 위에 그릴 때

func _paint_card_block(host: Control, card: Dictionary, card_size: Vector2, lane_prefix: String = "") -> void:
	var pad := float(host.get_meta("kit_frame_pad")) if host.has_meta("kit_frame_pad") else CARD_BLOCK_PAD
	var color := GamePalette.STONE_LIGHT if card.is_empty() else _factory_card_color(card)
	var is_item := not card.is_empty() and String(card.get("kind", "skill")) == "item"
	var visual_card := card.duplicate(true)
	if visual_card.is_empty():
		visual_card = DealCardLibrary.basic_instance()
	var icon_id := String(visual_card.get("id", "basic"))
	# 카드 높이에 따라 세 단계 밀도로 배치합니다. 어느 단계에서도 글자가 겹치지 않습니다.
	var tight := card_size.y < 90.0
	var wide := card_size.y >= 132.0
	var icon_size := 34.0 if tight else (48.0 if wide else 44.0)
	var text_left := pad + icon_size + 10.0
	var text_width := card_size.x - text_left - pad
	var name_height := 20.0 if tight else (44.0 if wide else 38.0)
	var meter_height := 14.0 if tight else 18.0
	var meter_y := card_size.y - meter_height - pad
	var icon := SKILL_ICON_SCRIPT.new()
	icon.position = Vector2(pad, pad)
	icon.size = Vector2(icon_size, icon_size)
	icon.setup(icon_id, color)
	host.add_child(icon)

	var name_text := _factory_card_name(card)
	if not lane_prefix.is_empty():
		name_text = "%s · %s" % [lane_prefix, name_text]
	var name_label := _label(name_text, 11 if tight else (14 if wide else 13), GamePalette.TEXT)
	name_label.position = Vector2(text_left, pad - 3.0)
	name_label.size = Vector2(text_width, name_height)
	if tight:
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(name_label)

	if is_item:
		var item := ItemLibrary.by_id(String(card.get("id", "")))
		var item_tag := _label("아이템 · 공격 없음", 9 if tight else UI_CAPTION_SIZE, color.lightened(0.18))
		item_tag.position = Vector2(text_left, pad - 3.0 + name_height)
		item_tag.size = Vector2(text_width, 18.0)
		host.add_child(item_tag)
		if not tight:
			var scope := _label(ItemLibrary.effect_scope(item), 10, GamePalette.CYAN)
			scope.position = Vector2(pad, meter_y - 19.0)
			scope.size = Vector2(card_size.x - pad * 2.0, 17.0)
			scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			host.add_child(scope)
		var item_effect := _label(ItemLibrary.compact_effect(item), 9 if tight else 10, GamePalette.MUTED)
		item_effect.position = Vector2(pad, meter_y)
		item_effect.size = Vector2(card_size.x - pad * 2.0, meter_height + 2.0)
		item_effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		host.add_child(item_effect)
	else:
		# V7: 보스 패턴은 라이브러리에 없다 — 되읽으면 세 칸이 전부 **기본 베기 수치**로
		# 표시된다(프리뷰에서 실제로 그랬다). 사전이 자기 수치를 들고 있으므로 그대로 쓴다.
		var ranked := visual_card if visual_card.has("telegraph") else DealCardLibrary.ranked(visual_card)
		# W6: 원소·형태 태그(§3.8)를 카드 블록에 상시 노출한다. 결속·공명·삼각·반응이
		# 전부 이 두 값에서 나오므로 "이 카드가 무슨 속성인가"가 안 보이면 편집이 도박이 된다.
		var compact_tag := _card_tag_compact(visual_card)
		var rank_text := "빈칸 · 기본 공격" if card.is_empty() else "스킬 · R%d" % int(card.get("rank", 1))
		if not card.is_empty() and not compact_tag.is_empty():
			rank_text = "R%d · %s" % [int(card.get("rank", 1)), compact_tag]
		# V7: 보스 패턴에는 랭크가 없다. 그 자리에 **선딜**을 적는다 — 스테이지 보스전의
		# 공략 정보 중 플레이어가 프리뷰에서 미리 알아야 할 유일한 값이다(§3.3 telegraph 열).
		if card.has("telegraph"):
			rank_text = "예비 동작 %.2f초%s" % [float(card.get("telegraph", 0.0)), "" if compact_tag.is_empty() else " · %s" % compact_tag]
		var rank_label := _label(rank_text, 9 if tight else UI_CAPTION_SIZE, color.lightened(0.18))
		rank_label.position = Vector2(text_left, pad - 3.0 + name_height)
		rank_label.size = Vector2(text_width, 18.0)
		rank_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		host.add_child(rank_label)
		var half_width := (card_size.x - pad * 2.0 - 6.0) * 0.5
		var meter_font := 8 if tight else 10
		_add_metric_bar(host, Vector2(pad, meter_y), Vector2(half_width, meter_height), "지속 %.2f" % float(ranked.get("duration", 0.0)), float(ranked.get("duration", 0.0)), 2.8, GamePalette.CYAN, meter_font)
		_add_metric_bar(host, Vector2(pad + 6.0 + half_width, meter_y), Vector2(half_width, meter_height), "R %.2f" % float(ranked.get("reload", 0.0)), float(ranked.get("reload", 0.0)), 1.8, GamePalette.ORANGE, meter_font)

## 클릭·드래그가 없는 화면(선택 모달 안쪽 블록)에서 쓰는 읽기 전용 카드 블록.
## U2 v3: 카드 프레임이 아니라 **슬롯 칸**(`Role.CELL`)이다. 이 블록은 언제나 카드
## 프레임(선택 모달 카드) **안에** 앉으므로 카드 위에 카드를 겹치면 프레임이 두 겹으로
## 읽힌다. 레일에서 이 블록이 앉는 자리도 칸이므로 의미도 이쪽이 맞다.
func _card_block_panel(card: Dictionary) -> Panel:
	var block := Panel.new()
	block.size = FACTORY_CARD_BLOCK_SIZE
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_panel(block, UIKit.Tone.SLATE, UIKit.Role.CELL)
	_paint_card_block(block, card, FACTORY_CARD_BLOCK_SIZE)
	return block

func _on_factory_card_dropped(source: Dictionary, target: Dictionary) -> void:
	if state != "factory_menu" or factory_mode != "edit" or factory == null or source == target:
		return
	var source_zone := String(source.get("zone", ""))
	var target_zone := String(target.get("zone", ""))
	if source_zone == "rail" and target_zone == "rail":
		# 부록 C-1의 두 조작이 갈리는 유일한 지점이다. 드래그를 시작한 칸의 페이로드에
		# 실린 gesture(= 그때의 편집 모드)를 따른다.
		#   "card" → factory.move_card  : 카드만 교환, 각인은 제자리
		#   "slot" → factory.swap_slots : 칸 통째 교환, 각인이 함께 이동
		var source_slot := int(source.get("slot", -1))
		var target_slot := int(target.get("slot", -1))
		var gesture := String(source.get("gesture", EDIT_MODE_CARD))
		factory_pick_slot = -1
		if gesture == EDIT_MODE_SLOT:
			if not factory.swap_slots(source_slot, target_slot):
				return
			_show_banner("칸 %02d ⇄ 칸 %02d · 각인까지 함께 이동" % [source_slot + 1, target_slot + 1], GamePalette.MAGENTA, 1.8)
		else:
			if not factory.move_card(source_slot, target_slot):
				return
			_show_banner("카드 %02d ↔ %02d · 각인은 칸에 그대로" % [source_slot + 1, target_slot + 1], GamePalette.CYAN, 1.8)
	elif source_zone == "inventory" and target_zone == "rail":
		var inventory_index := int(source.get("index", -1))
		if inventory_index < 0 or inventory_index >= factory.inventory.size():
			return
		# 아이템은 레일에 못 놓는다(§5.4). 규칙을 말로 알리고 아무것도 옮기지 않는다.
		if String((factory.inventory[inventory_index] as Dictionary).get("kind", "skill")) == "item":
			_show_banner("아이템은 레일에 놓을 수 없습니다 · 오른쪽 장비 4부위로 끌어 놓으세요", GamePalette.MAGENTA, 2.4)
			play_sound("debt", -8.0)
			_show_factory_menu("edit", {}, factory_return_state)
			return
		var moving := factory.remove_inventory_at(inventory_index)
		if moving.is_empty():
			return
		var replaced := factory.place_card(int(target.get("slot", -1)), moving)
		factory.add_inventory(replaced)
	elif source_zone == "inventory" and target_zone == "equipment":
		var equip_index := int(source.get("index", -1))
		if equip_index < 0 or equip_index >= factory.inventory.size():
			return
		if String((factory.inventory[equip_index] as Dictionary).get("kind", "skill")) != "item":
			_show_banner("스킬 카드는 장비 칸에 넣을 수 없습니다 · 레일 칸으로 옮기세요", GamePalette.YELLOW, 2.2)
			_show_factory_menu("edit", {}, factory_return_state)
			return
		# Y4(피드백 ⑫): 드래그로 끼울 때도 같은 확인을 지난다 — 마우스와 키보드가
		# 같은 규칙을 따르지 않으면 "실수로 좋은 걸 덮어썼다"가 한쪽에서만 남는다.
		if not _request_equip_swap(equip_index):
			return
		var equipping := factory.remove_inventory_at(equip_index)
		factory.add_inventory(factory.equip(equipping))
	elif source_zone == "rail" and target_zone == "inventory":
		var removed := factory.clear_slot(int(source.get("slot", -1)))
		factory.add_inventory(removed)
	elif source_zone == "inventory" and target_zone == "inventory":
		var from_index := int(source.get("index", -1))
		var to_index := int(target.get("index", -1))
		if from_index < 0 or to_index < 0 or from_index >= factory.inventory.size() or to_index >= factory.inventory.size():
			return
		var held: Dictionary = factory.inventory[from_index]
		factory.inventory[from_index] = factory.inventory[to_index]
		factory.inventory[to_index] = held
	else:
		return
	_reset_player_cycle()
	play_sound("choice", -5.0)
	_show_factory_menu("edit", {}, factory_return_state)

func _build_pending_card_summary(parent: Control, card: Dictionary) -> void:
	# 레일이 화면 중앙을 차지하므로 입고 카드 요약은 제목 아래 가로 스트립으로 놓습니다.
	var color := _factory_card_color(card)
	var icon := SKILL_ICON_SCRIPT.new()
	icon.position = Vector2(14.0, 8.0)
	icon.size = Vector2(58.0, 58.0)
	icon.setup(String(card.get("id", "basic")), color)
	parent.add_child(icon)
	var is_item := String(card.get("kind", "skill")) == "item"
	if is_item:
		var item := ItemLibrary.by_id(String(card.get("id", "")))
		var item_type := _label("아이템 카드 · %s · %s" % [ItemLibrary.rarity_name(String(item.get("rarity", "common"))), ItemLibrary.part_name(String(item.get("slot", "")))], UI_CAPTION_SIZE, color)
		item_type.position = Vector2(84.0, 9.0)
		item_type.size = Vector2(420.0, 18.0)
		parent.add_child(item_type)
		var item_name := _label(String(item.get("name", "아이템")), 20, GamePalette.TEXT)
		item_name.position = Vector2(84.0, 28.0)
		item_name.size = Vector2(420.0, 32.0)
		item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		parent.add_child(item_name)
		var attack_notice := _label("공격 없음 · 놓인 칸은 즉시 통과", UI_CAPTION_SIZE, GamePalette.YELLOW)
		attack_notice.position = Vector2(520.0, 9.0)
		attack_notice.size = Vector2(340.0, 18.0)
		parent.add_child(attack_notice)
		var effect := _label("걸리는 곳 %s · %s" % [ItemLibrary.effect_scope(item), item.get("desc", "")], UI_CAPTION_SIZE, GamePalette.CYAN)
		effect.position = Vector2(520.0, 28.0)
		effect.size = Vector2(640.0, 38.0)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(effect)
	else:
		var ranked := DealCardLibrary.ranked(card)
		var skill_type := _label("스킬 카드 · %s · R%d" % [DealCardLibrary.combat_tags(ranked), int(card.get("rank", 1))], UI_CAPTION_SIZE, color)
		skill_type.position = Vector2(84.0, 9.0)
		skill_type.size = Vector2(420.0, 18.0)
		skill_type.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		parent.add_child(skill_type)
		var skill_name := _label(String(ranked.get("name", "기술")), 20, GamePalette.TEXT)
		skill_name.position = Vector2(84.0, 28.0)
		skill_name.size = Vector2(420.0, 32.0)
		skill_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		parent.add_child(skill_name)
		var description := _label(String(ranked.get("desc", "")), UI_CAPTION_SIZE, GamePalette.MUTED)
		description.position = Vector2(516.0, 8.0)
		description.size = Vector2(346.0, 38.0)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(description)
		var damage := _label("피해 배수 %.2f" % float(ranked.get("damage", 0.0)), UI_CAPTION_SIZE, GamePalette.YELLOW)
		damage.position = Vector2(516.0, 46.0)
		damage.size = Vector2(346.0, 20.0)
		parent.add_child(damage)
		_add_metric_bar(parent, Vector2(880.0, 11.0), Vector2(280.0, 22.0), "지속시간  %.2f초" % float(ranked.get("duration", 0.0)), float(ranked.get("duration", 0.0)), 2.8, GamePalette.CYAN, UI_CAPTION_SIZE)
		_add_metric_bar(parent, Vector2(880.0, 41.0), Vector2(280.0, 22.0), "RELOAD  %.2f초" % float(ranked.get("reload", 0.0)), float(ranked.get("reload", 0.0)), 1.8, GamePalette.ORANGE, UI_CAPTION_SIZE)

func _add_metric_bar(parent: Control, bar_position: Vector2, bar_size: Vector2, title: String, value: float, visual_max: float, color: Color, font_size: int = 10) -> void:
	var track := ColorRect.new()
	track.position = bar_position
	track.size = bar_size
	track.color = Color(UI_CHIP_BG, 0.88)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.position = Vector2(2.0, 2.0)
	fill.size = Vector2((bar_size.x - 4.0) * clampf(value / maxf(visual_max, 0.01), 0.0, 1.0), maxf(1.0, bar_size.y - 4.0))
	# 채움 밴드 위에 아이콘·숫자를 얹으므로 한 단계 어둡고 옅게 깔아 글자가 먼저 읽히게 합니다 (⑰).
	fill.color = Color(color.darkened(0.32), 0.62)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	# 아이콘은 프레임을 벗긴 뒤 글리프가 칸을 꽉 채우므로 예전보다 작게 잡아야
	# 글자와 겹치지 않습니다 (⑫ 트리밍 + ⑰ 간격 리듬).
	var metric_icon := GENERATED_UI_ICON_SCRIPT.new()
	var metric_size := minf(bar_size.y - 4.0, 14.0)
	metric_icon.position = Vector2(3.0, (bar_size.y - metric_size) * 0.5)
	metric_icon.size = Vector2(metric_size, metric_size)
	metric_icon.setup("reload" if title.to_upper().contains("RELOAD") or title.begins_with("R ") else "duration")
	track.add_child(metric_icon)
	# 가운데 정렬이면 짧은 칩에서 글자 시작점이 아이콘 쪽으로 밀려 "지" 글자가 아이콘에
	# 파묻혔습니다. 아이콘 오른쪽에서 왼쪽 정렬로 시작해 항상 2px 이상 띄웁니다 (P1-14).
	var text_label := _label(title, font_size, GamePalette.TEXT)
	text_label.position = Vector2(metric_size + 9.0, -2.0 if bar_size.y <= 15.0 else 0.0)
	text_label.size = Vector2(maxf(1.0, bar_size.x - metric_size - 12.0), bar_size.y)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	track.add_child(text_label)

# 원소 1글자 마크 + 형태 이름. HUD 레일(RAIL_ELEMENT_MARK)과 같은 어휘를 쓴다.
func _card_tag_compact(card: Dictionary) -> String:
	var mark := String(RAIL_ELEMENT_MARK.get(String(card.get("element", "")), ""))
	var form := String(card.get("form", ""))
	var form_text := DealCardLibrary.form_name(form) if not form.is_empty() else ""
	if mark.is_empty() and form_text.is_empty():
		return ""
	if mark.is_empty():
		return form_text
	if form_text.is_empty():
		return mark
	return "%s %s" % [mark, form_text]

func _factory_card_name(card: Dictionary) -> String:
	if card.is_empty():
		return "기본 베기"
	# V7: 보스 패턴은 `DealCardLibrary`에 없다(`boss_library.gd`가 소유한다).
	# 사전이 자기 이름·색을 이미 들고 있으므로 되읽지 않고 그대로 쓴다.
	if card.has("telegraph"):
		return String(card.get("name", "패턴"))
	if String(card.get("kind", "skill")) == "item":
		return String(ItemLibrary.by_id(String(card.get("id", ""))).get("name", "아이템"))
	return String(DealCardLibrary.by_id(String(card.get("id", ""))).get("name", "기술"))

## Y4 — 카드 한 장의 의미색. **원소가 1순위다**(FEEDBACK_Y §3.3 · 리스크 ⑩).
##
## v1~Y1은 이 함수가 카드별 `color` 키를 그대로 읽었고 그 값은 **원소와 무관**했다 —
## `thunder`(번개) 카드가 청록 `67c7d4` · `whirlwind`(독) 카드가 붉은 `d95763` ·
## `cross_cut`(독) 카드가 크림색이었다(실측). 이 함수가 아이콘 색·프레임 색·툴팁
## 강조색으로 흘러드는 자리가 11곳이라, 유저가 말한 "화·초 색 구별 안 감"의
## **진짜 원인이 여기**였을 가능성이 높다.
##
## Y1이 데이터 40장의 `color`를 원소색으로 정합시켰지만 그것만으로는 부족하다 —
## 데이터는 언제든 다시 어긋나고, 어긋나도 아무도 안 죽는다. 런타임이
## `_element_color()`를 **먼저** 보게 만들어 어긋날 자리 자체를 없앤다.
## 그래서 이 파일에서 카드 `color` 키를 읽는 자리는 이제 아래 두 폴백뿐이고,
## 그 키의 정규 소비자는 VFX(`cycle_skill_effect.gd:52`) 하나로 좁혀졌다.
func _factory_card_color(card: Dictionary) -> Color:
	if card.is_empty():
		return GamePalette.STONE_LIGHT
	# 보스 패턴은 원소를 갖지 않는다 — `boss_library.gd`가 자기 색을 들고 있다.
	if card.has("telegraph"):
		return Color(String(card.get("color", "f4d35e")))
	# 아이템은 원소가 아니라 **등급**이 색을 정한다(보관함·장비 타일과 한 언어).
	if String(card.get("kind", "skill")) == "item":
		var item := ItemLibrary.by_id(String(card.get("id", "")))
		return ItemLibrary.rarity_color(String(item.get("rarity", "common")))
	var element := _card_element(card)
	if ELEMENT_COLOR.has(element):
		return ELEMENT_COLOR[element]
	# 여기까지 오는 것은 원소가 없는 스킬(기본 베기 · BASIC 계열)뿐이다.
	var definition := DealCardLibrary.by_id(String(card.get("id", "")))
	return Color(String(definition.get("color", "f4d35e")))

func _factory_card_detail(card: Dictionary) -> String:
	if String(card.get("kind", "skill")) == "item":
		var item := ItemLibrary.by_id(String(card.get("id", "")))
		return "%s · %s · 아이템 카드\n공격 없음 · %s\n%s" % [ItemLibrary.rarity_name(String(item.get("rarity", "common"))), _item_slot_korean(String(item.get("slot", ""))), ItemLibrary.effect_scope(item), item.get("desc", "")]
	var definition := DealCardLibrary.ranked(card)
	return "%s  R%d\n%s\n지속시간 %.2f초 · RELOAD %.2f초 · 피해 배수 %.2f" % [definition.get("name", "기술"), int(card.get("rank", 1)), definition.get("desc", ""), float(definition.get("duration", 0.0)), float(definition.get("reload", 0.0)), float(definition.get("damage", 0.0))]

func _decorate_shop_offer(button: Button, card: Dictionary, offer: Dictionary) -> void:
	var color := _factory_card_color(card)
	# 선택 모달 카드와 같은 이유로 본문을 어두운 칩 판 위에 올린다(§6 · _build_choice_card_body).
	_kit_panel(button, Rect2(15.0, 15.0, 222.0, 330.0), UIKit.Tone.SLATE, UIKit.Role.CHIP)
	var icon := SKILL_ICON_SCRIPT.new()
	icon.position = Vector2(86.0, 18.0)
	icon.size = Vector2(80.0, 80.0)
	icon.setup(String(card.get("id", "basic")), color)
	button.add_child(icon)
	var is_item := String(card.get("kind", "skill")) == "item"
	var type_text := "아이템 카드 · 공격 없음" if is_item else "스킬 카드 · R%d" % int(card.get("rank", 1))
	var type_label := _label(type_text, UI_CAPTION_SIZE, color.lightened(0.18))
	type_label.position = Vector2(12.0, 106.0)
	type_label.size = Vector2(228.0, 20.0)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(type_label)
	var name_label := _label(String(offer.get("name", _factory_card_name(card))), UI_HEADING_SIZE, GamePalette.TEXT)
	name_label.position = Vector2(14.0, 130.0)
	name_label.size = Vector2(224.0, 48.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(name_label)
	var description := _label(String(offer.get("desc", "")), UI_LABEL_SIZE, GamePalette.MUTED)
	description.position = Vector2(15.0, 180.0)
	description.size = Vector2(222.0, 66.0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(description)
	if is_item:
		var item := ItemLibrary.by_id(String(card.get("id", "")))
		var scope := _label("걸리는 곳  %s" % ItemLibrary.effect_scope(item), UI_CAPTION_SIZE, GamePalette.CYAN)
		scope.position = Vector2(14.0, 256.0)
		scope.size = Vector2(224.0, 42.0)
		scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_child(scope)
	else:
		var ranked := DealCardLibrary.ranked(card)
		_add_metric_bar(button, Vector2(16.0, 252.0), Vector2(220.0, 21.0), "지속시간  %.2f초" % float(ranked.get("duration", 0.0)), float(ranked.get("duration", 0.0)), 2.8, GamePalette.CYAN, 10)
		_add_metric_bar(button, Vector2(16.0, 280.0), Vector2(220.0, 21.0), "RELOAD  %.2f초" % float(ranked.get("reload", 0.0)), float(ranked.get("reload", 0.0)), 1.8, GamePalette.ORANGE, 10)
	# Y4(피드백 ⑯): 「48 G」 노란 글자 → 금화 칩(세공사 진열의 값표와 같은 위젯).
	_gold_chip(button, Rect2(56.0, 316.0, 140.0, 30.0), int(offer.get("price", 0)), UIKit.FONT_HEADING)

func _item_slot_korean(slot_id: String) -> String:
	return ItemLibrary.part_name(slot_id)

func _factory_inventory_pressed(inventory_index: int) -> void:
	if state != "factory_menu" or inventory_index < 0 or inventory_index >= factory.inventory.size():
		return
	factory_selected_inventory = inventory_index
	factory_focus_zone = "inventory"
	factory_focus_index = factory_inventory_indices.find(inventory_index)
	_update_factory_focus()

# lane_index는 v1 레인 잔재이며 항상 0이다(버튼 bind·테스트 시그니처 호환용).
func _factory_lane_pressed(slot_index: int, lane_index: int = 0) -> void:
	if factory == null:
		return
	if factory_mode == "place":
		var previous := factory.place_card(slot_index, pending_factory_card)
		factory.add_inventory(previous)
		var placed_name := _factory_card_name(pending_factory_card)
		pending_factory_card.clear()
		_reset_player_cycle()
		_finish_factory_return()
		_show_banner("%s 놓기 완료 · 바늘이 다시 돕니다" % placed_name, GamePalette.GREEN, 2.4)
		return
	if factory_mode.begins_with("upgrade"):
		# v2에서 분열(split)은 폐기됐다. upgrade_slot이 알아서 거부한다.
		var success := factory.upgrade_slot(slot_index, pending_factory_upgrade)
		if success:
			_reset_player_cycle()
			_finish_factory_return()
			_show_banner("%d번 칸을 강화했습니다 · %s" % [slot_index + 1, _factory_upgrade_description(pending_factory_upgrade)], GamePalette.ORANGE, 2.8)
		else:
			_show_banner("이 칸에는 더 적용할 수 없습니다", GamePalette.RED, 1.8)
		return
	if factory_mode != "edit":
		return
	# 카드 그림을 눌렀다 = 카드 제스처. 칸 손잡이는 `_editor_slot_pressed`를 직접 부른다.
	_editor_slot_pressed(slot_index, EDIT_MODE_CARD)

# TAB 순환 순서. 비어 있는 영역은 _clamp_factory_focus가 걸러 낸다.
const EDIT_FOCUS_ZONES: Array[String] = ["rail", "inventory", "equipment"]

func _handle_factory_keyboard(key_event: InputEventKey) -> void:
	# Y4: 장비 교체 확인이 떠 있으면 키는 전부 그 화면 것이다(피드백 ⑫).
	if not equip_swap.is_empty():
		if key_event.keycode == KEY_ESCAPE:
			_cancel_equip_swap()
		elif key_event.keycode in [KEY_SPACE, KEY_ENTER]:
			_confirm_equip_swap()
		return
	if key_event.keycode == KEY_ESCAPE:
		# 예전에는 edit 모드에만 ESC 탈출구가 있었습니다. upgrade 모드에서 적용 가능한 칸이
		# 하나도 없으면 화면을 빠져나갈 방법이 전혀 없어 강제 종료뿐이었습니다.
		if factory_mode == "edit":
			if factory_pick_slot >= 0:
				factory_pick_slot = -1
				_show_factory_menu("edit", {}, factory_return_state)
				return
			_close_factory_menu()
		elif factory_mode.begins_with("upgrade"):
			_cancel_factory_upgrade()
		elif factory_mode == "place":
			_store_pending_factory_card()
		return
	# X2: **모드 키(M / 1 / 2)는 삭제됐다.** 모드가 없어졌으므로 전환할 것도 없다.
	# 두 조작은 이제 "무엇을 집었나"가 가른다 — 마우스는 카드 그림 대 칸 손잡이,
	# 키보드는 SPACE(카드) 대 SHIFT+SPACE(칸 통째). 아래 SPACE 분기가 그것을 읽는다.
	if key_event.keycode == KEY_TAB and factory_mode == "edit":
		var order := EDIT_FOCUS_ZONES.duplicate()
		var at := maxi(0, order.find(factory_focus_zone))
		for step in order.size():
			var candidate := String(order[wrapi(at + step + 1, 0, order.size())])
			if candidate == "inventory" and factory_inventory_buttons.is_empty():
				continue
			if candidate == "equipment" and factory_equipment_buttons.is_empty():
				continue
			factory_focus_zone = candidate
			break
		factory_focus_index = 0
		_clamp_factory_focus()
		_update_factory_focus()
		return
	var direction := 0
	if key_event.keycode in [KEY_LEFT, KEY_UP, KEY_A, KEY_W]: direction = -1
	if key_event.keycode in [KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S]: direction = 1
	if direction != 0:
		var size := factory_lane_buttons.size()
		if factory_focus_zone == "inventory":
			size = factory_inventory_buttons.size()
		elif factory_focus_zone == "equipment":
			size = factory_equipment_buttons.size()
		if size > 0:
			factory_focus_index = wrapi(factory_focus_index + direction, 0, size)
			_clamp_factory_focus()
			_update_factory_focus(true)
		return
	if key_event.keycode not in [KEY_SPACE, KEY_ENTER]:
		return
	if factory_focus_zone == "inventory" and not factory_inventory_indices.is_empty():
		_factory_inventory_pressed(factory_inventory_indices[clampi(factory_focus_index, 0, factory_inventory_indices.size() - 1)])
	elif factory_focus_zone == "equipment" and not factory_equipment_buttons.is_empty():
		_editor_equipment_pressed(clampi(factory_focus_index, 0, factory_equipment_buttons.size() - 1))
	elif not factory_lane_coordinates.is_empty():
		var coordinate := factory_lane_coordinates[clampi(factory_focus_index, 0, factory_lane_coordinates.size() - 1)]
		if factory_mode == "edit":
			# SHIFT를 누른 채 집으면 **칸 통째**(각인 동반), 그냥 누르면 카드만.
			# 모드 키가 사라진 자리를 이 수식 키 하나가 대신한다.
			_editor_slot_pressed(coordinate.x, EDIT_MODE_SLOT if key_event.shift_pressed else EDIT_MODE_CARD)
			return
		_factory_lane_pressed(coordinate.x, coordinate.y)

## X2: `keyboard = true`면 지금 포커스가 온 대상의 툴팁을 같은 지연으로 띄운다.
## 마우스와 키보드가 **같은 정보**를 봐야 단일 포커스 모델이 반쪽이 안 된다.
## 화면을 다시 조립할 때(false)는 띄우지 않는다 — 열자마자 툴팁이 뜨면 그림을 가린다.
func _update_factory_focus(keyboard: bool = false) -> void:
	for index in factory_lane_buttons.size():
		var focused := factory_focus_zone == "rail" and index == factory_focus_index
		var picked := factory_pick_slot >= 0 and index < factory_lane_coordinates.size() and factory_lane_coordinates[index].x == factory_pick_slot
		var tint := Color(1.0, 0.94, 0.6, 1.0) if picked else (Color.WHITE if focused else Color(0.78, 0.80, 0.86, 0.94))
		# U2 v3: 편집 화면에서는 **칸 전체**를 밝힌다. 안쪽 칩만 밝히면 5칸 중 어디에
		# 포커스가 있는지 캡처에서 안 보였다(칸이 카드 프레임을 들고 있기 때문이다).
		var host_value: Variant = factory_lane_buttons[index].get_meta("edit_cell") if factory_lane_buttons[index].has_meta("edit_cell") else null
		if host_value is CanvasItem and is_instance_valid(host_value):
			var host_cell: CanvasItem = host_value
			host_cell.modulate = tint
			factory_lane_buttons[index].modulate = Color.WHITE
		else:
			factory_lane_buttons[index].modulate = tint
	for index in factory_inventory_buttons.size():
		var selected := factory_selected_inventory == factory_inventory_indices[index]
		factory_inventory_buttons[index].modulate = Color.WHITE if selected or (factory_focus_zone == "inventory" and index == factory_focus_index) else Color(0.68, 0.7, 0.78, 0.9)
	for index in factory_equipment_buttons.size():
		factory_equipment_buttons[index].modulate = Color.WHITE if factory_focus_zone == "equipment" and index == factory_focus_index else Color(0.7, 0.72, 0.8, 0.92)
	if factory_focus_zone == "rail" and factory_focus_index < factory_lane_coordinates.size():
		factory_rune_focus_slot = factory_lane_coordinates[factory_focus_index].x
	if keyboard and factory_tooltip_layer != null:
		UIKit.tooltip_focus(factory_tooltip_layer, _focused_factory_control())
	# 편집 화면은 무스크롤이지만 place/upgrade 모드의 v1 레일은 여전히 스크롤을 쓴다.
	if factory_focus_zone != "rail" or not is_instance_valid(factory_rail_scroll):
		return
	if factory_focus_index < 0 or factory_focus_index >= factory_lane_buttons.size():
		return
	factory_rail_scroll.ensure_control_visible(factory_lane_buttons[factory_focus_index])

## 지금 키보드 포커스가 앉아 있는 컨트롤(툴팁을 띄울 대상). 영역마다 배열이 다르다.
func _focused_factory_control() -> Control:
	var pool: Array[Button] = factory_lane_buttons
	if factory_focus_zone == "inventory":
		pool = factory_inventory_buttons
	elif factory_focus_zone == "equipment":
		pool = factory_equipment_buttons
	if pool.is_empty() or factory_focus_index < 0 or factory_focus_index >= pool.size():
		return null
	return pool[factory_focus_index]

func _factory_upgrade_description(upgrade_type: String) -> String:
	match upgrade_type:
		"split": return "폐기된 강화입니다 (v2는 5칸 고정)"
		"repeat": return "선택한 칸의 내용을 2번 실행"
		"duration": return "선택한 칸의 지속시간 14% 단축"
		"reload": return "선택한 칸의 RELOAD 18% 단축"
		_: return "레일 부품 강화"

func _factory_shape_text() -> String:
	# 예전에는 "칸-줄-칸-줄-칸" 같은 내부 표현이 그대로 버튼에 노출됐습니다.
	if factory == null:
		return "공장 없음"
	return "%d칸 고정 · 각인 %d개" % [factory.slots.size(), factory.total_rune_count()]

func _auto_close_factory_build() -> void:
	await get_tree().create_timer(1.8, true, false, true).timeout
	if state == "factory_build":
		_finish_factory_return()

func _close_factory_menu() -> void:
	if state != "factory_menu":
		return
	_finish_factory_return()

func _cancel_factory_upgrade() -> void:
	# 강화술사에게 이미 지불한 골드를 되돌려 주고 성 안으로 복귀합니다.
	if state != "factory_upgrade":
		return
	var refund := factory_upgrade_refund
	pending_factory_upgrade = ""
	if refund > 0:
		gold += refund
	_finish_factory_return()
	if refund > 0:
		_show_banner("강화를 취소했습니다 · %d G 환불" % refund, GamePalette.YELLOW, 2.4)
	else:
		_show_banner("강화를 취소했습니다", GamePalette.MUTED, 2.0)

func _store_pending_factory_card() -> void:
	# 레일에 놓지 않고 보관함으로 보냅니다. 아이템 카드 획득 흐름과 규칙이 같아집니다.
	if state != "factory_place" or factory == null:
		return
	var stored_name := _factory_card_name(pending_factory_card)
	factory.add_inventory(pending_factory_card)
	pending_factory_card.clear()
	_finish_factory_return()
	_show_banner("%s → 카드 보관함에 보관 · ESC 공장에서 배치" % stored_name, GamePalette.CYAN, 2.6)

func _finish_factory_return() -> void:
	_clear_overlay()
	get_tree().paused = false
	state = factory_return_state
	factory_upgrade_refund = 0
	factory_editor_open = false
	factory_pick_slot = -1
	# 툴팁 층은 오버레이의 자식이라 화면과 함께 죽는다. 참조만 끊는다.
	factory_tooltip_layer = null
	factory_tooltip_targets.clear()
	# 스킬 확정 → 즉시 배치 → 필드 복귀(factory_place), ESC 공장(factory_menu),
	# 슬롯 강화(factory_upgrade), 다리/슬롯 건설 연출(factory_build) 모두 이 경로로 나온다.
	_grant_modal_return_invulnerability()
	_update_hud()
	if not pending_boss_toast_cards.is_empty():
		var cards := pending_boss_toast_cards.duplicate(true)
		pending_boss_toast_cards.clear()
		_show_boss_growth_toast(cards)
	# === V8: 트로피 카드 배치가 끝났다 → 후속 동작(5스테이지면 마왕전) ===
	# `trophy_place_pending`이 이 경로를 다른 place 흐름(레벨업·상점·상자)과 가른다.
	if trophy_place_pending:
		trophy_place_pending = false
		call_deferred("_finish_stage_trophy")
		return
	if state == "playing" and experience >= xp_target:
		call_deferred("_show_skill_choice", "level")

func _reset_player_cycle() -> void:
	if is_instance_valid(player_cycle):
		player_cycle.reset_cycle()

# =============================================================================
# U1 v3 — 로비 필드 디오라마 (docs/ui-style-v3.md · handoff-v3-assets §2)
# =============================================================================
# v1 로비 배경은 AI 생성 야경 한 장(`lobby-minimal-v2.png`)이었다. 필드가 Ninja
# Adventure 픽셀 세계로 바뀐 뒤로는 로비와 게임이 **서로 다른 두 게임**처럼 보였다.
# 그래서 배경을 실제 게임이 쓰는 아틀라스 그대로 그린 정적 디오라마로 갈아 끼운다.
#   · 지형   `terrain-atlas-verdant.png` — 1스테이지가 쓰는 바로 그 벌
#   · 스케일 타일 40px · 랜드마크/캐릭터 1:1 — `world_grid.gd`와 완전히 같은 규격
#   · 결정적 난수를 쓰지 않고 좌표 해시로 타일을 고른다(캡처가 매번 같다)
#   · 정적   `_draw()` 한 번으로 끝난다. 트윈 0개(AGENTS.md §3-9)
#
# 화면 배치 계약(1280×720): 메뉴 기둥은 **왼쪽**, 디오라마의 이야기(성 → 흙길 →
# 용사 → 보스문)는 **오른쪽**에 둔다. 둘이 겹치지 않으므로 스크림을 얕게 깔 수 있고,
# 첫 화면에서 "게임의 한 판"이 통째로 보인다.
const LOBBY_MENU_RECT := Rect2(104.0, 176.0, 472.0, 416.0)
# 캐릭터 선택: v1의 ◀▶ 카루셀(한 번에 한 장)을 버리고 **세 장을 한 번에** 편다.
# 킷 카드 상태 3종(융기 / 흰 이중 링 / 함몰)이 "고를 수 있음 · 고른 것 · 잠김"과
# 1:1로 맞아떨어져서, 한 화면에 셋을 놓으면 규칙이 그림만으로 읽힌다.
# 푸터 2버튼도 껍데기 **안**에 넣는다. 처음엔 화면 바닥에 따로 놓았는데, 배경이
# 단색이 아니라 디오라마라 "이 캐릭터로 시작"이 보스문 랜드마크 위에 겹쳐 앉았다.
const CHARACTER_SHELL_RECT := Rect2(136.0, 96.0, 1008.0, 552.0)
const CHARACTER_CARD_SIZE := Vector2(296.0, 348.0)
const CHARACTER_CARD_GAP := 32.0
# 설정: 껍데기 하나에 음량 2줄 + 토글 3줄 + 푸터 2버튼.
const SETTINGS_SHELL_RECT := Rect2(340.0, 112.0, 600.0, 452.0)

class LobbyDiorama:
	extends Control

	const TILE := 40.0
	const ATLAS_COLUMNS := 5
	const ATLAS_ROWS := 4
	# `wfc_chunk_generator.TILE_RULES`의 atlas 번호를 그대로 쓴다.
	# 0 잔디 · 1 잔디풀 · 2 꽃 · 15 덤불 · 16 바위.
	# 반복 횟수 = 가중치다. **필드의 실제 가중치 비율**(잔디 77 / 풀 14 / 꽃 3.5 /
	# 덤불 3.2 / 바위 1.8)에 맞췄다 — 처음엔 덤불·바위를 각 8%씩 뿌렸더니 로비가
	# 자갈밭처럼 보였고, 무엇보다 **필드와 다른 밀도**라 "같은 세계"가 깨졌다.
	const GRASS_CELLS: Array[int] = [
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		1, 1, 1, 1, 1, 1, 1, 2, 2, 15, 15, 16,
	]
	const COURTYARD_CELL := 18      # 성 앞 흙 포장

	var terrain: Texture2D
	## Rect2 목록(화면 좌표). 이 안의 타일은 잔디 대신 흙 포장이 된다.
	var courtyards: Array[Rect2] = []
	## {texture, base(밑변 중심), modulate} — 랜드마크는 밑변 기준으로 세운다.
	var props: Array = []
	## {texture, region, center, modulate} — 캐릭터 시트에서 한 칸만 오려 붙인다.
	var actors: Array = []

	func _draw() -> void:
		if terrain == null:
			return
		var columns := int(ceil(size.x / TILE))
		var rows := int(ceil(size.y / TILE))
		for row in rows:
			for column in columns:
				var cell := COURTYARD_CELL if _is_courtyard(column, row) \
					else GRASS_CELLS[_tile_hash(column, row) % GRASS_CELLS.size()]
				draw_texture_rect_region(terrain,
					Rect2(float(column) * TILE, float(row) * TILE, TILE, TILE),
					_cell_region(cell), Color.WHITE)
		for entry in props:
			var prop: Dictionary = entry
			var texture: Texture2D = prop["texture"]
			var base: Vector2 = prop["base"]
			var prop_size := Vector2(texture.get_width(), texture.get_height())
			draw_texture_rect(texture,
				Rect2(base - Vector2(prop_size.x * 0.5, prop_size.y), prop_size),
				false, prop.get("modulate", Color.WHITE))
		for entry in actors:
			var actor: Dictionary = entry
			var region: Rect2 = actor["region"]
			var center: Vector2 = actor["center"]
			# 32px 셀을 정수 배율로만 키운다. 비정수 배율은 픽셀 격자를 흔든다.
			var actor_size := region.size * float(actor.get("scale", 1.0))
			# 시트에 그림자가 없어서 이게 빠지면 인물이 지면에서 떠 보인다
			# (`player.gd._draw()`가 필드에서 하는 것과 같은 처리다).
			draw_rect(Rect2(center + Vector2(-actor_size.x * 0.32, actor_size.y * 0.34),
				Vector2(actor_size.x * 0.64, actor_size.y * 0.16)),
				Color(0.04, 0.05, 0.08, 0.42), true)
			draw_texture_rect_region(actor["texture"],
				Rect2(center - actor_size * 0.5, actor_size), region,
				actor.get("modulate", Color.WHITE))

	func _cell_region(cell: int) -> Rect2:
		var cell_width := float(terrain.get_width()) / float(ATLAS_COLUMNS)
		var cell_height := float(terrain.get_height()) / float(ATLAS_ROWS)
		return Rect2(float(cell % ATLAS_COLUMNS) * cell_width,
			float(cell / ATLAS_COLUMNS) * cell_height, cell_width, cell_height)

	func _is_courtyard(column: int, row: int) -> bool:
		var center := Vector2((float(column) + 0.5) * TILE, (float(row) + 0.5) * TILE)
		for area in courtyards:
			if area.has_point(center):
				return true
		return false

	# 결정적 정수 해시. 난수를 쓰면 캡처가 매번 달라져 육안 회귀 검수가 불가능하다.
	func _tile_hash(column: int, row: int) -> int:
		var value := column * 374761393 + row * 668265263
		value = (value ^ (value >> 13)) * 1274126177
		return absi(value ^ (value >> 16))

## 로비·캐릭터 선택·온보딩이 공유하는 배경. `dim`은 그 위에 얹힐 UI의 무게에 맞춘다
## (로비는 얕게, 모달이 큰 화면은 깊게). 비네트는 필드와 같은 오버레이 한 장이다.
func _add_lobby_background(parent: Control, dim: float = 0.22) -> void:
	var diorama := LobbyDiorama.new()
	diorama.name = "FieldDiorama"
	diorama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	diorama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diorama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diorama.terrain = LOBBY_TERRAIN_ATLAS
	# 성 앞 광장 → 남동쪽 길 → 보스문 앞마당. 필드에서 성과 보스문이 흙길로
	# 이어지는 문법(`world_grid._draw_castle` / `_draw_boss_gate`)을 그대로 옮긴 것이다.
	diorama.courtyards = [
		Rect2(756.0, 268.0, 216.0, 84.0),
		Rect2(836.0, 344.0, 96.0, 168.0),
		Rect2(836.0, 496.0, 344.0, 96.0),
		Rect2(1048.0, 552.0, 200.0, 80.0)
	]
	diorama.props = [
		{"texture":LOBBY_CASTLE_SPRITE, "base":Vector2(864.0, 308.0)},
		{"texture":LOBBY_BOSS_GATE_SPRITE, "base":Vector2(1148.0, 604.0)},
		{"texture":LOBBY_TREE_SPRITE, "base":Vector2(668.0, 214.0)},
		{"texture":LOBBY_TREE_SPRITE, "base":Vector2(716.0, 470.0)},
		{"texture":LOBBY_TREE_SPRITE, "base":Vector2(1096.0, 262.0)},
		{"texture":LOBBY_TREE_SPRITE, "base":Vector2(1220.0, 386.0)},
		{"texture":LOBBY_TREE_SPRITE, "base":Vector2(636.0, 664.0)},
		{"texture":LOBBY_CHEST_SPRITE, "base":Vector2(1012.0, 424.0)}
	]
	# 용사는 성에서 나와 보스문 쪽(오른쪽 아래)을 바라보고 서 있다.
	# 시트 규격은 `player.gd`와 같다 — 32px 셀 · 행 4 = 대기 · 열 3 = 오른쪽.
	# 배율은 **정수 2배**다. 1배(필드와 완전 동일)로 두면 1280×720 안에서 32px 인물이
	# 흙길의 얼룩처럼 보여 주인공으로 안 읽혔다(첫 캡처 실측). 2배면 성(256×176)과의
	# 크기 관계가 여전히 그럴듯하면서 시선이 인물에 걸린다.
	diorama.actors = [{
		"texture":SurvivorPlayer.PLAYER_SHEETS["swordsman"],
		"region":Rect2(3.0 * 32.0, 4.0 * 32.0, 32.0, 32.0),
		"center":Vector2(890.0, 452.0),
		"scale":2.0
	}]
	parent.add_child(diorama)
	# 비네트는 필드가 쓰는 그 장이다(순수 알파 감쇠판이라 LINEAR — ui-style-v3 §10).
	var vignette := TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.texture = STAGE_VIGNETTE_TEXTURE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vignette.modulate = Color(1.0, 1.0, 1.0, 0.55)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vignette)
	# 스크림 색은 킷의 스포트라이트 잉크와 같다 — U3 길잡이가 겹쳐도 색이 안 튄다.
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(UIKit.SPOTLIGHT_INK, clampf(dim, 0.0, 1.0))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)

## 킷 리본 명판. 껍데기 위쪽 가장자리에 걸치게 두는 것이 규격이라(ui-style-v3 §7-3)
## 껍데기가 아니라 **껍데기의 부모**에 붙인다 — 그래야 V홈이 밖으로 나온다.
func _kit_ribbon(parent: Control, rect: Rect2, text: String,
		tone: UIKit.Tone = UIKit.Tone.WOOD) -> Panel:
	var ribbon := Panel.new()
	ribbon.position = rect.position
	ribbon.size = Vector2(rect.size.x, UIKit.RIBBON_H)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_theme_stylebox_override("panel",
		UIKit.ribbon_box(tone, UIKit.RibbonShape.NOTCHED))
	parent.add_child(ribbon)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2.ZERO
	label.size = ribbon.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(label, tone, UIKit.FONT_TITLE, false, false)
	label.add_theme_color_override("font_color", UIKit.heading_color(tone))
	ribbon.add_child(label)
	return ribbon

## 킷 패널 한 장 + 그 안에 절대 좌표로 글자를 놓기 위한 단축형.
func _kit_panel(parent: Control, rect: Rect2, tone: UIKit.Tone,
		role: UIKit.Role = UIKit.Role.PANEL) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	# 킷 패널은 장식이다. 마우스를 먹으면 안에 놓인 버튼·카드가 클릭을 못 받는다.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_panel(panel, tone, role)
	parent.add_child(panel)
	return panel

## 킷 라벨 한 줄. `_label()`(v1 토큰)은 U2 몫 화면이 그대로 쓰므로 건드리지 않고,
## U1 화면은 전부 이 함수를 지난다.
func _kit_label(parent: Control, rect: Rect2, text: String, tone: UIKit.Tone,
		size: int = UIKit.FONT_BODY, muted: bool = false,
		role: UIKit.Role = UIKit.Role.PANEL,
		alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 불투명한 킷 패널 안이라 외곽선을 끈다(ui-style-v3 §3 "패널 안에서는 아예 끈다").
	UIKit.style_label(label, tone, size, muted, false, role)
	parent.add_child(label)
	return label

## 킷 버튼 한 개. 폰트는 5단 안에서만 고른다.
func _kit_button(parent: Control, rect: Rect2, text: String,
		variant: UIKit.Btn = UIKit.Btn.PRIMARY,
		size: int = UIKit.FONT_HEADING) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.custom_minimum_size = rect.size
	UIKit.style_button(button, variant, size)
	parent.add_child(button)
	return button

## 킷 키캡 스프라이트 한 장(72×40). 모르는 키면 null이라 텍스트로 폴백한다.
func _kit_keycap(parent: Control, at: Vector2, key: String) -> Control:
	var texture := UIKit.keycap(key)
	if texture == null:
		return _kit_label(parent, Rect2(at, Vector2(UIKit.KEYCAP_W, UIKit.KEYCAP_H)),
			key.to_upper(), UIKit.Tone.SLATE, UIKit.FONT_LABEL, false,
			UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	var cap := TextureRect.new()
	cap.texture = texture
	cap.position = at
	cap.size = Vector2(UIKit.KEYCAP_W, UIKit.KEYCAP_H)
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cap)
	return cap

## 킷 글리프 한 장(32×32). 앞 10종은 흰 선화라 `modulate`로 아무 색이나 입는다.
func _kit_glyph(parent: Control, at: Vector2, name: String, tint: Color,
		box: float = 24.0) -> TextureRect:
	var texture := UIKit.glyph(name)
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.texture = texture
	# ⚠️ 순서가 중요하다. `expand_mode`를 나중에 주면 그 전까지 최소 크기가 텍스처
	# 원본(32×32)이라 `size = 18`이 32로 **되올려 고정**된다. 실제로 그렇게 굽혀서
	# 체크 글리프가 칩 글자를 덮었다(실측). 확장 모드를 먼저 끄고 크기를 준다.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.position = at
	icon.size = Vector2(box, box)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

# =============================================================================
# Y4 — 재화 표기의 단일 창구 `_gold_chip()` (피드백 ⑯ · FEEDBACK_Y §8 ⑯)
# =============================================================================
# 사용자 원문 요지: "재화 표기를 골드 아이콘으로." 지금까지 화면에 뜨는 돈은
# `"%d G"` 문자열이었고, 세공사·밀정·카드상 세 곳만 각자 「코인 글리프 + 숫자」를
# **네 줄씩 손으로** 조립하고 있었다(handoff-y3 §9-A가 "그 헬퍼가 될 모양 그대로"라고
# 지목한 자리다). 같은 모양을 세 번 적어 두면 한 곳만 고쳐지고 나머지는 남는다.
#
# 이 함수가 그 조립을 흡수한다. 코인은 킷 글리프가 아니라 **YA가 구운 전용 금화**
# (`ui-coin-small` 16px / `ui-coin-large` 40px)이고, 칩 높이가 큰 자리는 큰 금화를
# 쓴다 — 작은 금화를 늘리면 픽셀이 뭉개진다.
#
# ⚠️ 「G」 글자는 **안 붙인다.** 금화 그림이 곧 단위다. 글자를 같이 두면 같은 말을
#    두 번 하는 셈이고, 이 라운드의 규칙(텍스트 최소)과 정면으로 어긋난다.
# ⚠️ 배너·토스트·툴팁 행처럼 **문자열 한 줄만 받는 자리**는 여전히 `"%d G"`다.
#    거기에는 자식 노드를 붙일 부모가 없다 — 그 목록은 handoff-y4 §5에 있다.
const COIN_TEXTURE_SMALL := preload("res://art/v2/ui-coin-small.png")
const COIN_TEXTURE_LARGE := preload("res://art/v2/ui-coin-large.png")
## 필드 HUD의 「가진 전부」. 낱개 금화와 그림을 일부러 다르게 쓴다.
const COIN_TEXTURE_PILE := preload("res://art/v2/ui-coin-pile.png")

func _gold_chip(parent: Control, rect: Rect2, amount: int,
		font_size: int = UIKit.FONT_TITLE, with_plate: bool = true) -> Label:
	if with_plate:
		_kit_panel(parent, rect, UIKit.Tone.GOLD, UIKit.Role.CHIP)
	var coin_box := clampf(rect.size.y - 16.0, 14.0, 28.0)
	var coin := TextureRect.new()
	coin.name = "GoldCoin"
	coin.texture = COIN_TEXTURE_LARGE if coin_box >= 22.0 else COIN_TEXTURE_SMALL
	# `_kit_glyph`와 같은 순서 함정을 피한다 — 확장 모드를 먼저 끄고 크기를 준다.
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2.ZERO
	coin.position = rect.position + Vector2(12.0, (rect.size.y - coin_box) * 0.5).floor()
	coin.size = Vector2(coin_box, coin_box)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(coin)
	var text_left := 20.0 + coin_box
	var label := _kit_label(parent,
		Rect2(rect.position + Vector2(text_left, 0.0),
			Vector2(maxf(24.0, rect.size.x - text_left - 12.0), rect.size.y)),
		"%d" % amount, UIKit.Tone.GOLD, font_size, false, UIKit.Role.CHIP,
		HORIZONTAL_ALIGNMENT_RIGHT)
	label.name = "GoldChip"
	return label

## 킷 포인터 스프라이트 한 장(32×32). `_kit_glyph`와 같은 규약이고 아틀라스만 다르다
## (`ui-kit-pointers.png` — 셰브런·바늘·잡이·닫기). X2의 칸 손잡이가 `grip`을 쓴다.
func _kit_pointer(parent: Control, at: Vector2, name: String, tint: Color,
		box: float = 24.0) -> TextureRect:
	var texture := UIKit.pointer(name)
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.texture = texture
	# `_kit_glyph`와 같은 함정 — 확장 모드를 먼저 끄지 않으면 크기가 32로 되올려 고정된다.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.position = at
	icon.size = Vector2(box, box)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _show_menu() -> void:
	get_tree().paused = false
	state = "menu"
	if is_instance_valid(gameplay_root):
		gameplay_root.free()
	gameplay_root = null
	world = null
	player = null
	boss = null
	hud.visible = false
	_load_progress()
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "LobbyScene"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	# 로비는 필드가 배경으로 살아 있어야 하는 화면이라 스크림을 얕게 깐다.
	_add_lobby_background(overlay, 0.20)
	# ---- 메뉴 기둥: PARCHMENT 껍데기 + WOOD 리본 (ui-style-v3 §7 골격) -------------
	# 껍데기 톤이 PARCHMENT인 이유는 §7-1이다 — 로비는 "필드가 안 보이는 전면 화면"
	# 범주다. 초록 벌판 위의 크림색 명판은 채도를 유지한 채 별개의 층으로 떨어져 보이고
	# (§2 마지막 문단), 그게 "숲 한가운데 세워 둔 나무 간판"이라는 이 화면의 그림이다.
	var menu_panel := _kit_panel(overlay, LOBBY_MENU_RECT, UIKit.Tone.PARCHMENT)
	# 리본 아래 한 줄 — 이 게임이 무엇인지 3어절로. 리본(패널 기준 -10..30)과
	# 첫 버튼 사이의 유일한 빈 줄이라 y를 34로 잡으면 버튼과 겹친다(첫 캡처 실측).
	_kit_label(menu_panel, Rect2(0.0, 36.0, LOBBY_MENU_RECT.size.x, 22.0),
		"5칸 딜싸이클 · 다섯 관문 · 마왕", UIKit.Tone.PARCHMENT,
		UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	var new_game := _kit_button(menu_panel,
		Rect2(32.0, 68.0, 408.0, 54.0), "게임 시작", UIKit.Btn.PRIMARY)
	new_game.pressed.connect(_show_character_select)
	# V9: 표기에 **스테이지**를 넣었다. 플레이타임만 있으면 "12:40"이 1스테이지 초반인지
	# 4스테이지 한복판인지 구분되지 않아, 이어할지 새로 시작할지 판단할 근거가 없었다.
	# U1 v3: 그 표기가 17px 버튼 라벨로는 400px 안에 안 들어간다. 버튼은 "이어하기"만
	# 들고, 스테이지·일차·플레이타임은 바로 아래 칩(계층 3)이 받는다. 정보는 그대로다.
	var continue_button := _kit_button(menu_panel,
		Rect2(32.0, 138.0, 408.0, 50.0), "이어하기", UIKit.Btn.NEUTRAL)
	continue_button.disabled = not saved_run_available
	continue_button.pressed.connect(_continue_saved_run)
	_kit_panel(menu_panel, Rect2(32.0, 190.0, 408.0, 34.0),
		UIKit.Tone.PARCHMENT, UIKit.Role.CHIP)
	_kit_label(menu_panel, Rect2(32.0, 190.0, 408.0, 34.0), _lobby_run_chip_text(),
		UIKit.Tone.PARCHMENT, UIKit.FONT_LABEL, not saved_run_available,
		UIKit.Role.CHIP, HORIZONTAL_ALIGNMENT_CENTER)
	var settings := _kit_button(menu_panel,
		Rect2(32.0, 244.0, 408.0, 50.0), "설정", UIKit.Btn.NEUTRAL)
	settings.pressed.connect(_show_settings)
	# 전체 화면에서는 창 닫기 버튼이 없고 ESC는 공장을 여는 키라, 로비에 종료 수단이
	# 없으면 Cmd+Q 말고는 게임을 끌 방법이 없습니다 (P1-10).
	# 톤 판단: DANGER(EMBER)로 먼저 구워 봤는데 §6이 경고한 대로 **WOOD(#f38c4c)와
	# EMBER(#d14b34)가 둘 다 주황 계열**이라, 로비 기둥에서 "게임 시작"과 "게임 종료"가
	# 같은 무게로 읽혔다(실측 캡처). 첫 화면에서 가장 튀는 것이 종료 버튼이면 안 된다.
	# 게다가 종료는 저장을 지우지 않으므로 파괴적 행동도 아니다 → NEUTRAL로 되돌렸다.
	var quit_button := _kit_button(menu_panel,
		Rect2(32.0, 308.0, 408.0, 50.0), "게임 종료", UIKit.Btn.NEUTRAL)
	quit_button.pressed.connect(get_tree().quit)
	_kit_label(menu_panel, Rect2(32.0, 370.0, 408.0, 20.0),
		"SPACE · ENTER 를 눌러도 바로 시작합니다", UIKit.Tone.PARCHMENT,
		UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	# 리본은 껍데기 **부모**에 붙여 위쪽 가장자리에 10px 걸치게 둔다(§7-3).
	# 제목 크기는 5단 안의 FONT_TITLE(26)이다 — v1의 60px는 5단 밖이라 버렸고,
	# 존재감은 글자 크기가 아니라 리본 명판이 낸다(§3 U1 판단 요청분).
	_kit_ribbon(overlay, Rect2(LOBBY_MENU_RECT.position.x + 36.0,
		LOBBY_MENU_RECT.position.y - 10.0, LOBBY_MENU_RECT.size.x - 72.0, 0.0),
		"딜싸이클 용사")
	# 1회성 등장 전환(§11 허용 ①). 루프가 아니라 반드시 끝난다.
	_animate_modal(menu_panel, Vector2(-20.0, 0.0))
	new_game.grab_focus()

func _show_character_select() -> void:
	state = "character_select"
	hud.visible = false
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "CharacterSelect"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	# 큰 모달이 앞에 서므로 스크림을 로비보다 깊게 판다.
	_add_lobby_background(overlay, 0.44)
	var ids := ["swordsman", "archer", "mage"]
	lobby_character_index = wrapi(lobby_character_index, 0, ids.size())
	var character_id := String(ids[lobby_character_index])
	var available := character_id == "swordsman"
	var names := {"swordsman":"왕국 검사", "archer":"방랑 궁사", "mage":"별빛 마법사"}
	var taglines := {
		"swordsman":"근거리 참격 · 5칸 딜싸이클의 기본형",
		"archer":"원거리 관통 · 사거리로 버티는 형",
		"mage":"광역 속성 · 콤보로 터뜨리는 형"
	}
	# ---- PARCHMENT 껍데기 + WOOD 리본 + 킷 카드 3장 -------------------------------
	var shell := _kit_panel(overlay, CHARACTER_SHELL_RECT, UIKit.Tone.PARCHMENT)
	var card_rect := Rect2(0.0, 0.0, CHARACTER_CARD_SIZE.x, CHARACTER_CARD_SIZE.y)
	for index in ids.size():
		var id := String(ids[index])
		var playable := id == "swordsman"
		var focused := index == lobby_character_index
		card_rect.position = Vector2(
			28.0 + float(index) * (CHARACTER_CARD_SIZE.x + CHARACTER_CARD_GAP), 54.0)
		# **세 상태가 색이 아니라 기하로 갈린다**(§6): 융기=고를 수 있음 ·
		# 흰 이중 링=지금 고른 것 · 함몰=잠김. 카드 종류는 TROPHY(GOLD·왕관 문양)다 —
		# "이 판을 끝까지 끌고 갈 챔피언"이 이 화면의 의미라 트로피 계열을 골랐다.
		var card_state := UIKit.CardState.DISABLED
		if playable:
			card_state = UIKit.CardState.SELECTED if focused else UIKit.CardState.NORMAL
		var card := Button.new()
		card.position = card_rect.position
		card.size = card_rect.size
		card.custom_minimum_size = card_rect.size
		card.focus_mode = Control.FOCUS_NONE
		var card_box := UIKit.card_box(UIKit.Card.TROPHY, card_state)
		var hover_box := UIKit.card_box(UIKit.Card.TROPHY,
			UIKit.CardState.SELECTED if playable else UIKit.CardState.DISABLED)
		for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			card.add_theme_stylebox_override(slot,
				hover_box if slot == "hover" else card_box)
		card.pressed.connect(_select_lobby_character.bind(index))
		shell.add_child(card)
		# 초상은 v1 AI 생성 원화를 버리고 **필드에서 실제로 움직이는 그 스프라이트**로
		# 바꾼다(스타일 일관 우선). 32px 셀을 정수 4배(128px)로만 키운다 — 비정수
		# 배율을 쓰면 킷·필드와 픽셀 격자가 어긋난다.
		_kit_panel(card, Rect2(44.0, 24.0, 208.0, 208.0),
			UIKit.Tone.GOLD, UIKit.Role.CELL)
		var portrait := TextureRect.new()
		portrait.position = Vector2(68.0, 48.0)
		portrait.size = Vector2(160.0, 160.0)
		portrait.texture = _character_portrait_texture(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 잠긴 캐릭터는 카드 기하(함몰)와 같은 방향으로 죽인다 — 채도를 빼고 어둡게.
		portrait.modulate = Color.WHITE if playable else Color(0.42, 0.42, 0.46, 0.85)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		_kit_label(card, Rect2(16.0, 242.0, CHARACTER_CARD_SIZE.x - 32.0, 32.0),
			String(names[id]), UIKit.Tone.GOLD, UIKit.FONT_TITLE, false,
			UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
		_kit_label(card, Rect2(16.0, 276.0, CHARACTER_CARD_SIZE.x - 32.0, 20.0),
			String(taglines[id]), UIKit.Tone.GOLD, UIKit.FONT_CAPTION, true,
			UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
		_kit_panel(card, Rect2(44.0, 302.0, 208.0, 34.0),
			UIKit.Tone.GOLD, UIKit.Role.CHIP)
		_kit_glyph(card, Vector2(56.0, 310.0), "check" if playable else "key",
			UIKit.text_on(UIKit.Tone.GOLD, UIKit.Role.CHIP), 18.0)
		# 글리프는 칩 왼쪽 끝에 고정하고 글자는 남은 칸 안에서 가운데 정렬한다 —
		# 문구 길이가 달라져도 둘이 겹칠 수 없는 배치다.
		_kit_label(card, Rect2(80.0, 302.0, 164.0, 34.0),
			"지금 할 수 있음" if playable else "준비 중",
			UIKit.Tone.GOLD, UIKit.FONT_LABEL, not playable, UIKit.Role.CHIP,
			HORIZONTAL_ALIGNMENT_CENTER)
	# 지금 보고 있는 카드에는 흰 포커스 링을 한 겹 더 얹는다. 잠긴 카드도 "지금
	# 보고 있다"는 것은 알려야 하는데, 그 신호를 카드 상태(=기하)에 섞으면
	# "약하게 선택된 카드"로 오독된다(§6). 그래서 링은 별개 층이다.
	var ring := Panel.new()
	ring.position = Vector2(
		28.0 + float(lobby_character_index) * (CHARACTER_CARD_SIZE.x + CHARACTER_CARD_GAP) - 6.0,
		48.0)
	ring.size = CHARACTER_CARD_SIZE + Vector2(12.0, 12.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", UIKit.focus_box())
	shell.add_child(ring)
	# ---- 키 안내 (킷 키캡 실물) ----------------------------------------------------
	var hint_y := 414.0
	var hints := [
		{"caps":["left", "right"], "text":"캐릭터 보기", "width":124.0},
		{"caps":["enter"], "text":"이 캐릭터로 시작", "width":146.0},
		{"caps":["esc"], "text":"로비로", "width":82.0}
	]
	var hint_x := 40.0
	for entry in hints:
		var hint: Dictionary = entry
		for key in hint["caps"]:
			_kit_keycap(shell, Vector2(hint_x, hint_y), String(key))
			hint_x += UIKit.KEYCAP_W + 6.0
		var hint_width := float(hint["width"])
		_kit_label(shell, Rect2(hint_x + 4.0, hint_y, hint_width, UIKit.KEYCAP_H),
			String(hint["text"]), UIKit.Tone.PARCHMENT, UIKit.FONT_LABEL, true)
		hint_x += hint_width + 44.0
	# ---- 푸터: 주 행동이 오른쪽 끝(§7-4) -------------------------------------------
	_kit_ribbon(overlay, Rect2(CHARACTER_SHELL_RECT.position.x + 294.0,
		CHARACTER_SHELL_RECT.position.y - 12.0, 420.0, 0.0), "캐릭터 선택")
	var back := _kit_button(shell, Rect2(28.0, 470.0, 180.0, 54.0),
		"로비로", UIKit.Btn.NEUTRAL)
	back.pressed.connect(_show_menu)
	var start := _kit_button(shell,
		Rect2(CHARACTER_SHELL_RECT.size.x - 348.0, 470.0, 320.0, 54.0),
		"이 캐릭터로 시작", UIKit.Btn.PRIMARY)
	start.disabled = not available
	start.pressed.connect(_confirm_character_selection.bind(character_id))
	_animate_modal(shell, Vector2(0.0, 22.0))

## 캐릭터 카드 초상. NA 시트에서 **대기 프레임 · 정면(아래)** 한 칸만 오린다.
## `player.gd`의 시트 규격(32px 셀 · 행 4 = 대기 · 열 0 = 아래)과 같은 계약이다.
func _character_portrait_texture(character_id: String) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = SurvivorPlayer.PLAYER_SHEETS.get(
		character_id, SurvivorPlayer.PLAYER_SHEETS["swordsman"])
	portrait.region = Rect2(0.0, 4.0 * 32.0, 32.0, 32.0)
	portrait.filter_clip = true
	return portrait

## 카드를 눌러 보고 있는 캐릭터를 바꾼다. 잠긴 캐릭터도 **볼 수는 있다** —
## 시작 버튼이 비활성으로 갈릴 뿐이라 화면 상태가 하나로 유지된다.
func _select_lobby_character(index: int) -> void:
	lobby_character_index = wrapi(index, 0, 3)
	_show_character_select()

func _cycle_character(direction: int) -> void:
	lobby_character_index = wrapi(lobby_character_index + direction, 0, 3)
	_show_character_select()

func _confirm_character_selection(character_id: String) -> void:
	if character_id != "swordsman":
		return
	selected_character_id = character_id
	_start_game()

func _start_game() -> void:
	var args := OS.get_cmdline_user_args()
	var should_skip := automated_test or not args.is_empty() or onboarding_seen_session or _onboarding_hidden_today()
	if should_skip:
		_begin_run()
	else:
		onboarding_page = 0
		onboarding_skip_today = false
		_show_onboarding(0)

func _show_settings() -> void:
	state = "settings"
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "Settings"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_add_lobby_background(overlay, 0.44)
	var panel := _kit_panel(overlay, SETTINGS_SHELL_RECT, UIKit.Tone.PARCHMENT)
	var first_slider := _add_settings_slider(panel, "전체 음량", 48.0, master_volume_db, _set_master_volume)
	_add_settings_slider(panel, "효과음", 124.0, effects_volume_db, _set_effects_volume)
	# 오래 남아 있던 Godot 기본 CheckButton 3종을 킷 토글로 교체한다. 상태는 색이
	# 아니라 **기하**로 갈린다 — 켜짐은 함몰(toggle_mode의 pressed 스타일박스),
	# 꺼짐은 융기다. 버튼이 언제나 불투명한 9-slice 위에 앉으므로 외곽선은 0이다(§5).
	_add_settings_toggle(panel, "피격 시 카메라 흔들림", 200.0, screen_shake_enabled, _set_screen_shake)
	_add_settings_toggle(panel, "피해 숫자 표시", 256.0, damage_numbers_enabled, _set_damage_numbers)
	_add_settings_toggle(panel, "전체 화면", 312.0, fullscreen_enabled, _set_fullscreen)
	# QUIET은 밝은 화면의 저강조 행동이고 **반드시 밝은 패널 안**에 둔다(§5 마지막 문단).
	var reset_guide := _kit_button(panel, Rect2(28.0, 380.0, 240.0, 44.0),
		"온보딩 다시 표시", UIKit.Btn.QUIET, UIKit.FONT_BODY)
	reset_guide.pressed.connect(_reset_onboarding_hide)
	# 주 행동은 오른쪽 끝(§7-4).
	var back := _kit_button(panel,
		Rect2(SETTINGS_SHELL_RECT.size.x - 288.0, 380.0, 260.0, 44.0),
		"로비로 돌아가기 · ESC", UIKit.Btn.PRIMARY, UIKit.FONT_BODY)
	back.pressed.connect(_show_menu)
	_kit_ribbon(overlay, Rect2(SETTINGS_SHELL_RECT.position.x + 150.0,
		SETTINGS_SHELL_RECT.position.y - 12.0, 300.0, 0.0), "설정")
	_animate_modal(panel, Vector2(0.0, 20.0))
	if is_instance_valid(first_slider):
		first_slider.grab_focus()

func _volume_percent_text(volume_db: float) -> String:
	return "%d%%" % int(round(db_to_linear(volume_db) * 100.0))

## 설정 한 줄의 공통 바닥판. 계층 2(함몰)라 줄과 줄이 저절로 갈린다.
func _settings_row(parent: Control, y: float, height: float, title: String) -> Panel:
	var row := _kit_panel(parent, Rect2(28.0, y, SETTINGS_SHELL_RECT.size.x - 56.0, height),
		UIKit.Tone.PARCHMENT, UIKit.Role.INSET)
	_kit_label(row, Rect2(16.0, 0.0, 194.0, height), title,
		UIKit.Tone.PARCHMENT, UIKit.FONT_HEADING, false, UIKit.Role.INSET)
	return row

func _add_settings_slider(parent: Control, title: String, y: float, value: float, callback: Callable) -> HSlider:
	var row := _settings_row(parent, y, 64.0, title)
	var slider := HSlider.new()
	slider.position = Vector2(214.0, 16.0)
	slider.size = Vector2(250.0, 32.0)
	slider.custom_minimum_size = Vector2(250.0, 32.0)
	# 원시 데시벨은 플레이어에게 아무 의미가 없어 오른쪽에 % 값을 함께 보여 줍니다.
	# 하한도 -40 → -60으로 낮춰 왼쪽 끝이 실질 무음(0%)이 되게 했습니다 (P1-12).
	slider.min_value = -60.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = value
	# 홈은 게이지 트랙, 채움은 순백 게이지에 `modulate_color`를 먹인 **복제본**이다.
	# 공유 인스턴스를 그 자리에서 고치면 같은 박스를 쓰는 다른 화면까지 바뀐다(§4 주의).
	# 홈 높이는 스타일박스의 최소 크기에서 나온다. 게이지 기본값(여백 4)이면 8px라
	# §4의 게이지 하한(16)에 못 미쳐 둥근 끝이 뭉개진다. 복제본에 여백을 8로 준다.
	var groove := UIKit.variant(UIKit.bar_box(UIKit.Bar.TRACK_DARK)) as StyleBoxTexture
	groove.content_margin_top = 8.0
	groove.content_margin_bottom = 8.0
	slider.add_theme_stylebox_override("slider", groove)
	var fill_box := UIKit.variant(UIKit.bar_box(UIKit.Bar.FILL)) as StyleBoxTexture
	fill_box.modulate_color = GamePalette.YELLOW
	slider.add_theme_stylebox_override("grabber_area", fill_box)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_box)
	var knob := UIKit.glyph("diamond")
	if knob != null:
		for slot: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(slot, knob)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	var value_label := _kit_label(row, Rect2(470.0, 0.0, 58.0, 64.0),
		_volume_percent_text(value), UIKit.Tone.PARCHMENT, UIKit.FONT_BODY, false,
		UIKit.Role.INSET, HORIZONTAL_ALIGNMENT_RIGHT)
	slider.value_changed.connect(func(changed: float) -> void: value_label.text = _volume_percent_text(changed))
	return slider

## 킷 토글 한 줄. Godot 기본 `CheckButton`(둥근 스위치 + 시스템 폰트)은 이 킷과
## 재질이 아예 달라서 설정 화면 혼자 다른 게임처럼 보였다. 대체물은 **토글 모드
## 버튼**이다 — 켜짐이면 `pressed` 스타일박스(함몰 베벨)가 나오므로 "눌려 들어가
## 있다 = 켜져 있다"가 색 없이 기하로 읽힌다. 라벨과 글리프가 그것을 한 번 더 말한다.
func _add_settings_toggle(parent: Control, title: String, y: float,
		enabled: bool, callback: Callable) -> Button:
	var row := _settings_row(parent, y, 48.0, title)
	var mark_tint := UIKit.text_on(UIKit.Tone.PARCHMENT, UIKit.Role.INSET)
	var mark := _kit_glyph(row, Vector2(376.0, 12.0),
		"check" if enabled else "cross", mark_tint)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.text = "켜짐" if enabled else "꺼짐"
	toggle.position = Vector2(410.0, 6.0)
	toggle.size = Vector2(118.0, 36.0)
	toggle.custom_minimum_size = toggle.size
	UIKit.style_button(toggle, UIKit.Btn.NEUTRAL, UIKit.FONT_BODY)
	toggle.toggled.connect(func(on: bool) -> void:
		toggle.text = "켜짐" if on else "꺼짐"
		if is_instance_valid(mark):
			mark.texture = UIKit.glyph("check" if on else "cross")
		callback.call(on))
	row.add_child(toggle)
	return toggle

func _set_master_volume(value: float) -> void:
	master_volume_db = value
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, master_volume_db)
	_save_progress()

func _set_effects_volume(value: float) -> void:
	effects_volume_db = value
	_save_progress()

func _set_screen_shake(enabled: bool) -> void:
	screen_shake_enabled = enabled
	_save_progress()

func _set_damage_numbers(enabled: bool) -> void:
	damage_numbers_enabled = enabled
	_save_progress()

func _set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_progress()

## 설정의 「온보딩 다시 표시」. U3 이후로는 **두 가지를 함께** 되돌린다 —
## 온보딩 4페이지(`onboarding_hide_date`)와 필드 스포트라이트 길잡이(`guide_seen`).
## 둘은 사용자에게 한 덩어리("게임 설명")라 하나만 되살아나면 약속이 반쪽이 된다.
func _reset_onboarding_hide() -> void:
	onboarding_seen_session = false
	onboarding_skip_today = false
	guide_seen = false
	var config := ConfigFile.new()
	config.load(GameTuning.PROGRESS_PATH)
	config.set_value("settings", "onboarding_hide_date", "")
	config.set_value("settings", "guide_seen", false)
	config.save(GameTuning.PROGRESS_PATH)
	_show_banner("다음에 새로 시작하면 안내와 길잡이를 다시 보여 줍니다", GamePalette.CYAN, 2.2)

# -----------------------------------------------------------------------------
# 온보딩 4페이지 (2026-08-07 정적 도식 재설계)
# -----------------------------------------------------------------------------
# 사용자 요청 원문 요지: "온보딩 모달의 애니메이션이 엉망이야. 애니메이션을 빼주고,
# 간단한 텍스트와 도식화된 디자인으로 처리해줘. 기존 테마 다 부셔도 돼."
# 그래서 이 화면에서는 트윈을 단 하나도 만들지 않는다.
#   - 삭제: _add_onboarding_motion() — 그림 위에 반투명 마커를 얹어 무한 루프로 돌리던 트윈
#   - 삭제: 패널 등장 _animate_modal() 호출 (다른 화면의 _animate_modal은 그대로 둔다)
#   - 삭제: AI 생성 그림 4장(ONBOARDING_TEXTURES) 의존. 전부 Panel/ColorRect/Label 도식으로 대체
# 골격: 헤더(액센트 바 + 26px 타이틀 + 우측 상태 2줄) → 한 줄 부제 →
#       도식 무대(위 = 그림 없는 정적 도식 / 아래 = 규칙 2~3줄) →
#       스파인 라인 위 페이지 인디케이터 + 이전/다음 → 하단 보조 버튼.
#
# U1 v3(2026-08-09) 재스킨 — **정보 구조·4페이지·정적 도식 원칙은 한 글자도 안 바꿨다.**
# 바뀐 것은 표면뿐이다(docs/ui-style-v3.md).
#   껍데기  PARCHMENT PANEL   — 전면 화면이므로 §7-1대로 parchment
#   헤더    WOOD NOTCHED 리본 — 껍데기 위쪽 가장자리에 12px 걸친다(§7-3)
#   무대    **SLATE INSET**   — 여기만 톤을 갈랐다. 도식이 나르는 색(회귀 CYAN ·
#           도약 GREEN · 재실행 ORANGE · 되밟기 ORANGE · 관문 색)은 필드 HUD와 같은
#           **의미색**이라 재스킨 대상이 아니고(§2), 그 색들은 크림빛 위에서 전부
#           대비가 무너진다. 어두운 slate 판 위에 두면 필드에서 배운 색이 그대로
#           읽힌다 — 무대는 "모달 안에 뚫린 필드 창"이다.
#   키캡    `UIKit.keycap()` 실물 26종 — 자작 키캡 박스는 삭제됐다
#   버튼    PRIMARY / NEUTRAL / QUIET. 페이지 스텝은 현재 칸만 PRIMARY
const ONBOARDING_PAGE_COUNT := 4
# y를 6 → 18로 내렸다. 리본이 껍데기 위로 12px 걸쳐야 V홈이 밖으로 나오는데(§7-3)
# 껍데기가 y=6이면 걸칠 자리가 화면 밖이다. 안쪽 좌표계는 그대로라 도식은 안 흔들린다.
const ONBOARDING_PANEL_RECT := Rect2(12.0, 18.0, 1256.0, 696.0)
const ONBOARDING_RIBBON_WIDTH := 700.0
const ONBOARDING_STAGE_RECT := Rect2(28.0, 84.0, 1200.0, 494.0)
const ONBOARDING_STAGE_RULE_TOP := 336.0
const ONBOARDING_NAV_Y := 594.0
const ONBOARDING_NAV_SIZE := Vector2(152.0, 44.0)
const ONBOARDING_FOOTER_Y := 654.0
const ONBOARDING_STEP_PITCH := 96.0
const ONBOARDING_STEP_SIZE := Vector2(74.0, 38.0)

func _onboarding_pages() -> Array:
	# =========================================================================
	# X4(2026-08-09) 텍스트 다이어트 — 사용자 원문 ① "온보딩에 텍스트가 너무 많아.
	# 조금 더 쉽게 설명해줘."
	# =========================================================================
	# 규칙은 넷이고 `--guide-test`가 셋을 기계로 단언한다(`diet=true`).
	#   ① 규칙 줄은 **페이지당 최대 2줄**   (구 2·3·3·3 → 2·2·2·2)
	#   ② 한 줄은 **32자 이하**             (구 최장 59자 · 4페이지 등급 줄)
	#   ③ 페이지 한 장의 글자 총합 상한     (`ONBOARDING_PAGE_CHARS`)
	#   ④ 어려운 말을 안 쓴다 — 숫자·조건·목록은 **도식**이 말한다.
	#
	# 「빚」만은 남겼다. 지우면 HUD 툴팁의 「빚 N.NN초」가 처음 보는 낱말이 된다.
	# 대신 2페이지 도식이 **「쉬는 시간」이라는 쉬운 말로 먼저 가르치고** 이름을
	# 뒤에 붙인다("쌓인 쉬는 시간을 「빚」이라고 부릅니다").
	#
	# 4페이지 규칙 ②가 X3가 넘긴 새 규약이다 — "화살표는 목적지가 안 보일 때만 뜬다"
	# (handoff-x3 §11.2 ②). 나머지 하나("자세한 숫자는 마우스를 올리면")는 규칙 줄이
	# 아니라 **1페이지 키 목록의 네 번째 줄**로 들어갔다 — 그것은 규칙이 아니라 조작이고,
	# 필드 HUD(X3)와 ESC 편집 화면(X2) 두 화면을 한 번에 여는 문장이다.
	return [
		# U1 v3: 1페이지는 **가벼운 예고**로 내렸다. 조작 실습은 곧 필드에서 U3의
		# 스포트라이트 길잡이가 손을 잡고 시킨다 — 여기서 세 줄을 더 읽히면 같은 말을
		# 두 번 하는 셈이고, 글로 외운 조작은 어차피 필드에서 다시 배운다.
		{
			"title":"조작은 네 가지뿐",
			"subtitle":"이동 · 대시 · 말 걸기 · ESC 편집 화면",
			"color":GamePalette.GREEN,
			"rules":[
				"공격 버튼이 없습니다. 카드가 알아서 나갑니다.",
				"지금 외우지 마세요. 필드에서 다시 알려 줍니다."
			]
		},
		{
			"title":"5칸 딜싸이클 — 바늘이 도는 법",
			"subtitle":"전투 규칙 — 바늘은 한 번에 한 칸만 쓴다",
			"color":GamePalette.CYAN,
			"rules":[
				"바늘이 선 칸의 카드가 저절로 나갑니다.",
				"한 바퀴를 돌면 쌓인 만큼 쉬었다 다시 돕니다."
			]
		},
		{
			"title":"각인 셋 중 하나 — 안 고른 것은 마왕에게",
			"subtitle":"성장 규칙 — 각인은 카드가 아니라 「칸」에 붙는다",
			"color":GamePalette.MAGENTA,
			"rules":[
				"각인을 고르고, 넣을 「칸」을 고릅니다.",
				"고르지 않은 2개는 마왕이 가져갑니다."
			]
		},
		{
			"title":"다섯 관문 — 머물수록 세계가 강해진다",
			"subtitle":"목표 — 관문 다섯을 넘어 마왕에게. 기한은 없다",
			"color":GamePalette.YELLOW,
			"rules":[
				"오래 머물면 「체류」가 올라 세계가 강해집니다.",
				"목적지가 화면 밖일 때만 화살표가 뜹니다."
			]
		}
	]

func _show_onboarding(page: int = 0) -> void:
	onboarding_page = clampi(page, 0, ONBOARDING_PAGE_COUNT - 1)
	state = "onboarding"
	hud.visible = false
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "OnboardingPage%d" % (onboarding_page + 1)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	# 온보딩도 로비·캐릭터 선택과 **같은 세계** 위에 뜬다. 껍데기가 화면을 거의 다
	# 덮으므로 필드는 테두리 한 뼘만 보이지만, 그 한 뼘이 "게임 안에서 열린 안내문"과
	# "게임 밖의 설명 화면"을 가른다.
	_add_lobby_background(overlay, 0.62)
	var data: Dictionary = _onboarding_pages()[onboarding_page]
	var page_color: Color = data["color"]
	var panel := _kit_panel(overlay, ONBOARDING_PANEL_RECT, UIKit.Tone.PARCHMENT)
	# 좌: 화면 이름 칩 · 우: 페이지 카운터 칩. 가운데는 리본이 차지한다.
	_kit_panel(panel, Rect2(24.0, 6.0, 160.0, 32.0), UIKit.Tone.PARCHMENT, UIKit.Role.CHIP)
	# 글리프는 **앞 10종(흰 선화)에서만** 고른다. NA 원본 6종(gem~bag)은 고유 색을
	# 갖고 있어 어두운 잉크로 modulate 하면 검은 덩어리가 된다 — `book`으로 구웠다가
	# 칩 글자를 덮어 버렸다(실측). `info`는 선화라 어느 색으로든 물든다.
	_kit_glyph(panel, Vector2(38.0, 11.0), "info",
		UIKit.text_on(UIKit.Tone.PARCHMENT, UIKit.Role.CHIP), 18.0)
	_kit_label(panel, Rect2(62.0, 6.0, 112.0, 32.0), "게임 안내",
		UIKit.Tone.PARCHMENT, UIKit.FONT_LABEL, true, UIKit.Role.CHIP,
		HORIZONTAL_ALIGNMENT_CENTER)
	_kit_panel(panel, Rect2(1082.0, 6.0, 150.0, 32.0), UIKit.Tone.PARCHMENT, UIKit.Role.CHIP)
	_kit_label(panel, Rect2(1082.0, 6.0, 150.0, 32.0),
		"%d / %d" % [onboarding_page + 1, ONBOARDING_PAGE_COUNT],
		UIKit.Tone.PARCHMENT, UIKit.FONT_LABEL, false, UIKit.Role.CHIP,
		HORIZONTAL_ALIGNMENT_CENTER)
	_kit_label(panel, Rect2(0.0, 44.0, ONBOARDING_PANEL_RECT.size.x, 24.0),
		String(data["subtitle"]), UIKit.Tone.PARCHMENT, UIKit.FONT_BODY, true,
		UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)

	# 무대는 SLATE 함몰판이다(§2 "필드 위에 얹히는 것 전부"의 색 언어를 그대로 쓴다).
	var stage := _kit_panel(panel, ONBOARDING_STAGE_RECT, UIKit.Tone.SLATE, UIKit.Role.INSET)
	stage.clip_contents = true
	match onboarding_page:
		0:
			_onboarding_diagram_controls(stage, page_color)
		1:
			_onboarding_diagram_cycle(stage, page_color)
		2:
			_onboarding_diagram_fate(stage, page_color)
		_:
			_onboarding_diagram_journey(stage, page_color)
	_onboarding_rules(stage, data.get("rules", []), page_color)

	_build_onboarding_steps(panel, page_color)
	var previous := _kit_button(panel,
		Rect2(ONBOARDING_STAGE_RECT.position.x, ONBOARDING_NAV_Y,
			ONBOARDING_NAV_SIZE.x, ONBOARDING_NAV_SIZE.y),
		"◀  이전", UIKit.Btn.NEUTRAL)
	previous.disabled = onboarding_page == 0
	previous.focus_mode = Control.FOCUS_NONE
	previous.pressed.connect(_show_onboarding.bind(onboarding_page - 1))
	var last_page := onboarding_page == ONBOARDING_PAGE_COUNT - 1
	var next := _kit_button(panel,
		Rect2(ONBOARDING_STAGE_RECT.end.x - ONBOARDING_NAV_SIZE.x, ONBOARDING_NAV_Y,
			ONBOARDING_NAV_SIZE.x, ONBOARDING_NAV_SIZE.y),
		"게임 시작  ▶" if last_page else "다음  ▶", UIKit.Btn.PRIMARY)
	next.focus_mode = Control.FOCUS_NONE
	if last_page:
		next.pressed.connect(_finish_onboarding)
	else:
		next.pressed.connect(_show_onboarding.bind(onboarding_page + 1))

	var back := _kit_button(panel,
		Rect2(ONBOARDING_STAGE_RECT.position.x, ONBOARDING_FOOTER_Y, 152.0, 34.0),
		"캐릭터 선택", UIKit.Btn.NEUTRAL, UIKit.FONT_BODY)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_show_character_select)
	# 기본 CheckBox는 이 킷과 재질이 달라 쓰지 않는다. 토글 모드 버튼의 함몰 베벨이
	# "켜져 있다"를 기하로 말하고, 킷 글리프(체크/가위표)가 한 번 더 말한다.
	var hide_today := _kit_button(panel,
		Rect2((ONBOARDING_PANEL_RECT.size.x - 258.0) * 0.5, ONBOARDING_FOOTER_Y,
			258.0, 34.0),
		"오늘은 그만 보기", UIKit.Btn.QUIET, UIKit.FONT_BODY)
	hide_today.toggle_mode = true
	hide_today.button_pressed = onboarding_skip_today
	hide_today.focus_mode = Control.FOCUS_NONE
	hide_today.pressed.connect(_toggle_onboarding_skip_today)
	_kit_glyph(panel,
		Vector2((ONBOARDING_PANEL_RECT.size.x - 258.0) * 0.5 + 18.0,
			ONBOARDING_FOOTER_Y + 9.0),
		"check" if onboarding_skip_today else "cross",
		UIKit.text_color(UIKit.Tone.GOLD), 16.0)
	# X4: 두 줄이던 조작 안내를 **한 줄**로 접었다. "숫자 칸을 눌러 원하는 페이지로"는
	# 지웠다 — 스파인 위의 숫자 버튼 넷이 이미 눌러 보라고 말하는 기하이고, 이 줄은
	# 네 페이지 전부에 붙어 있어 22자 × 4장을 그냥 깎을 수 있는 자리였다.
	_kit_label(panel, Rect2(858.0, ONBOARDING_FOOTER_Y + 6.0, 374.0, 20.0),
		"← → 페이지 · SPACE 다음 · ESC 나가기", UIKit.Tone.PARCHMENT,
		UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_RIGHT)
	# 리본은 껍데기 부모에 — V홈이 껍데기 밖으로 나와야 리본으로 읽힌다(§7-3).
	_kit_ribbon(overlay, Rect2(
		ONBOARDING_PANEL_RECT.position.x
			+ (ONBOARDING_PANEL_RECT.size.x - ONBOARDING_RIBBON_WIDTH) * 0.5,
		ONBOARDING_PANEL_RECT.position.y - 12.0, ONBOARDING_RIBBON_WIDTH, 0.0),
		String(data["title"]))

# -----------------------------------------------------------------------------
# 온보딩 도식 프리미티브 (정적 전용 — 여기서 트윈을 만들지 않는다)
# -----------------------------------------------------------------------------
# U1 v3: 테두리 색 인자를 없앴다. 프레임은 전부 킷에서 오고(§4 3단 배경 계층),
# 도식이 나르는 **의미색**은 테두리가 아니라 안쪽 색판(`tint`)과 글자색이 맡는다 —
# §6이 카드 희귀도에 대해 정한 규칙("테두리가 아니라 이름 글자색으로")과 같은 결이다.
# 무대가 SLATE라 CHIP(well2)·CELL(밝은 안쪽)·INSET(well) 세 단으로 깊이를 만든다.
func _onboarding_box(parent: Control, rect: Rect2,
		role: UIKit.Role = UIKit.Role.CHIP, tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Panel:
	var box := Panel.new()
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_panel(box, UIKit.Tone.SLATE, role)
	if tint.a > 0.0:
		# 9-slice 테두리(10px) 안쪽에만 색판을 깐다. 테두리를 덮으면 베벨이 죽는다.
		var wash := ColorRect.new()
		wash.position = Vector2(UIKit.PANEL_MARGIN, UIKit.PANEL_MARGIN)
		wash.size = (rect.size - Vector2(UIKit.PANEL_MARGIN, UIKit.PANEL_MARGIN) * 2.0).max(Vector2.ZERO)
		wash.color = tint
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(wash)
	parent.add_child(box)
	return box

func _onboarding_bar(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func _onboarding_text(parent: Control, rect: Rect2, text: String, font_size: int, color: Color) -> Label:
	# U1 v3: `_label()`(v1 토큰 · 3~4px 외곽선)을 쓰지 않는다. 무대가 불투명한 SLATE
	# 판이라 헤일로가 필요 없고, 11~13px 한글에 3px 외곽선을 두르면 획 사이 1px
	# 속공간이 메워져 글자가 덩어리로 뭉친다(ui-style-v3 §3).
	# 색은 인자를 그대로 쓴다 — 도식이 나르는 **의미색**이라 재스킨 대상이 아니다.
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 0)
	parent.add_child(label)
	return label

func _onboarding_center_text(parent: Control, rect: Rect2, text: String, font_size: int, color: Color) -> Label:
	var label := _onboarding_text(parent, rect, text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _onboarding_glyph(parent: Control, center: Vector2, glyph: String, font_size: int, color: Color) -> void:
	# 화살표는 선(ColorRect) + 글리프 라벨 조합이다. 회전이나 이동은 쓰지 않는다.
	_onboarding_center_text(parent, Rect2(center.x - 24.0, center.y - 16.0, 48.0, 32.0), glyph, font_size, color)

## U1 v3: 자작 키캡 박스(반투명 색판 + 테두리 + 텍스트) → **킷 키캡 실물 26종**.
## 셀 72×40 안에 중앙 정렬돼 있어 크기가 제각각인 키를 나란히 놓아도 가운데가 맞는다.
## 모르는 키는 `null`이 오므로 예전 도형 키캡으로 폴백한다(§9 계약).
func _onboarding_keycap(parent: Control, at: Vector2, key: String) -> Control:
	var texture := UIKit.keycap(key)
	if texture == null:
		var fallback := _onboarding_box(parent,
			Rect2(at, Vector2(UIKit.KEYCAP_W, UIKit.KEYCAP_H)), UIKit.Role.CELL)
		_onboarding_center_text(parent,
			Rect2(at, Vector2(UIKit.KEYCAP_W, UIKit.KEYCAP_H)), key.to_upper(),
			UIKit.FONT_LABEL, GamePalette.TEXT)
		return fallback
	var cap := TextureRect.new()
	cap.texture = texture
	cap.position = at
	cap.size = Vector2(UIKit.KEYCAP_W, UIKit.KEYCAP_H)
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cap)
	return cap

func _onboarding_rules(stage: Control, rules: Array, page_color: Color) -> void:
	# 무대 아래쪽 고정 위치의 규칙 목록. 도식이 그림, 이 줄들이 확정 문장이다.
	# 구분선 색은 무대 글자색에서 파생한다(새 hex 리터럴 금지 — §12 체크리스트).
	var ink := UIKit.text_on(UIKit.Tone.SLATE, UIKit.Role.INSET)
	_onboarding_bar(stage, Rect2(40.0, ONBOARDING_STAGE_RULE_TOP, ONBOARDING_STAGE_RECT.size.x - 80.0, 2.0), Color(ink, 0.26))
	for index in rules.size():
		var top := ONBOARDING_STAGE_RULE_TOP + 26.0 + float(index) * 40.0
		_onboarding_bar(stage, Rect2(44.0, top + 10.0, 10.0, 10.0), page_color)
		var line := _onboarding_text(stage, Rect2(70.0, top, ONBOARDING_STAGE_RECT.size.x - 120.0, 30.0), String(rules[index]), UIKit.FONT_HEADING, ink)
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _onboarding_diagram_controls(stage: Control, page_color: Color) -> void:
	# 왼쪽: WASD 키캡 십자. 오른쪽: 나머지 3키를 한 줄씩. 전부 킷 키캡 실물이다.
	var ink := UIKit.text_on(UIKit.Tone.SLATE, UIKit.Role.INSET)
	var cap_w := float(UIKit.KEYCAP_W)
	var cross_center := 250.0
	_onboarding_keycap(stage, Vector2(cross_center - cap_w * 0.5, 56.0), "w")
	_onboarding_keycap(stage, Vector2(cross_center - cap_w * 1.5 - 8.0, 104.0), "a")
	_onboarding_keycap(stage, Vector2(cross_center - cap_w * 0.5, 104.0), "s")
	_onboarding_keycap(stage, Vector2(cross_center + cap_w * 0.5 + 8.0, 104.0), "d")
	_onboarding_center_text(stage, Rect2(70.0, 168.0, 360.0, 28.0), "이동 · 보는 방향", UIKit.FONT_HEADING, ink)
	_onboarding_center_text(stage, Rect2(70.0, 198.0, 360.0, 24.0), "방향키도 똑같습니다", UIKit.FONT_BODY, page_color)
	# 왼쪽 아래: U3 길잡이 예고. 이 페이지가 "외우는 화면"이 아니라는 것을 못 박는다.
	_onboarding_box(stage, Rect2(70.0, 236.0, 360.0, 74.0), UIKit.Role.CHIP)
	_onboarding_center_text(stage, Rect2(70.0, 248.0, 360.0, 26.0), "필드에서 직접 알려 줍니다", UIKit.FONT_HEADING, page_color)
	_onboarding_center_text(stage, Rect2(82.0, 276.0, 336.0, 22.0), "첫 낮에 하나씩 짚어 줍니다", UIKit.FONT_CAPTION, Color(ink, 0.78))
	_onboarding_bar(stage, Rect2(470.0, 40.0, 2.0, 272.0), Color(ink, 0.26))
	# X4: 줄이 셋 → **넷**이 됐다. 늘어난 한 줄이 X3가 넘긴 규약이다 —
	# "자세한 숫자는 마우스를 올리면 나온다"(handoff-x3 §11.2 ①). 이 한 문장이
	# 필드 HUD 툴팁 13종과 ESC 편집 화면 툴팁을 **동시에 연다**.
	# 설명 문구는 전부 짧게 갈았다. 「카드 이동 모드 / 칸 교환 모드」는 X2가 편집
	# 화면에서 통째로 지운 개념이라(모드 없음 · 드래그 자동 판별) 여기서도 지웠다.
	# 줄 간격은 84 → 68로 좁혀 네 줄이 규칙 구분선(y 336) 위에 들어온다.
	var rows := [
		{"key":"shift", "title":"대시", "desc":"잠깐 무적 · 10초에 한 번", "color":GamePalette.CYAN},
		{"key":"e", "title":"말 걸기", "desc":"성 · 상자 · 균열 앞에서", "color":GamePalette.YELLOW},
		{"key":"esc", "title":"5칸 편집 화면", "desc":"카드를 끌어 옮기고 각인을 봅니다", "color":GamePalette.MAGENTA},
		{"key":"mouse_left", "title":"자세히 보기", "desc":"숫자 위에 올리면 설명이 뜹니다", "color":GamePalette.CYAN}
	]
	for index in rows.size():
		var row: Dictionary = rows[index]
		var row_color: Color = row["color"]
		var top := 52.0 + float(index) * 68.0
		_onboarding_keycap(stage, Vector2(524.0, top), String(row["key"]))
		_onboarding_text(stage, Rect2(624.0, top - 2.0, 540.0, 26.0), String(row["title"]), UIKit.FONT_HEADING, row_color)
		_onboarding_text(stage, Rect2(624.0, top + 22.0, 540.0, 24.0), String(row["desc"]), UIKit.FONT_BODY, Color(ink, 0.82))
		if index < rows.size() - 1:
			_onboarding_bar(stage, Rect2(524.0, top + 52.0, 620.0, 1.0), Color(ink, 0.14))

# -----------------------------------------------------------------------------
# W6b 온보딩 2페이지 — 5칸 딜싸이클 · 바늘 · 흐름 델타 · 한 칸 두 번
# -----------------------------------------------------------------------------
# v1의 3칸 하드코딩을 5칸으로 바꾸고, 필드 HUD가 쓰는 색 언어를 그대로 복제한다.
# 회귀 CYAN / 도약 GREEN / 재실행 ORANGE — 여기서 배운 색이 실전에서 그대로 나온다.
const ONBOARDING_RAIL_SLOT := Vector2(168.0, 104.0)
const ONBOARDING_RAIL_GAP := 26.0
const ONBOARDING_RAIL_X := 68.0
const ONBOARDING_RAIL_TOP := 46.0

func _onboarding_rail_center(index: int) -> float:
	return ONBOARDING_RAIL_X + float(index) * (ONBOARDING_RAIL_SLOT.x + ONBOARDING_RAIL_GAP) + ONBOARDING_RAIL_SLOT.x * 0.5

func _onboarding_diagram_cycle(stage: Control, page_color: Color) -> void:
	# Y4: 이 다섯 칸은 **가짜 카드**였다 — 「회전베기」「벼락」「서리 방벽」은 게임에 없는
	# 이름이었고 태그도 한자 「화 참격」「뇌 파동」「빙 수호」를 손으로 적어 뒀다.
	# 온보딩에서 배운 이름과 실전에서 만나는 이름이 다르면 그 배움은 헛것이 된다.
	# 이제 **실재하는 카드 id 3장**을 라이브러리에서 읽는다 — 이름·원소 마크·형태·색이
	# 전부 실전 카드와 같은 창구(`_factory_card_name` · `_card_tag_compact` ·
	# `_factory_card_color`)에서 온다. 원소 표가 바뀌면 이 그림도 같이 따라온다.
	var slots: Array[Dictionary] = []
	for entry: Array in [["flame_field", 1], ["", 0], ["thunder", 3], ["moon_barrier", 1], ["", 0]]:
		var demo_id := String(entry[0])
		if demo_id.is_empty():
			slots.append({"name":"빈칸", "tag":"기본 베기", "color":GamePalette.STONE, "runes":0})
			continue
		var demo_card := DealCardLibrary.instance(demo_id, 1)
		slots.append({
			"name": _factory_card_name(demo_card),
			"tag": _card_tag_compact(DealCardLibrary.by_id(demo_id)),
			"color": _factory_card_color(demo_card),
			"runes": int(entry[1])
		})
	var ink := UIKit.text_on(UIKit.Tone.SLATE, UIKit.Role.INSET)
	var rail_w := ONBOARDING_RAIL_SLOT.x * 5.0 + ONBOARDING_RAIL_GAP * 4.0
	var line_y := ONBOARDING_RAIL_TOP + ONBOARDING_RAIL_SLOT.y * 0.5 - 2.0
	_onboarding_bar(stage, Rect2(ONBOARDING_RAIL_X + 16.0, line_y, rail_w - 32.0, 4.0), FACTORY_RAIL_SPINE_BUILT)
	# 바늘 — 지금 실행 중인 칸. 정지 마커다(깜빡이지 않는다).
	# 킷 포인터 `needle`(흰 선화 32×32 · 아래를 가리킨다)로 교체했다 — §8이 지목한 그 부품.
	var needle_x := _onboarding_rail_center(2)
	# X4: X1이 넘긴 정의 하나("지속시간 = 카드가 행동하는 시간")를 **새 줄을 만들지 않고**
	# 이 캡션 안에 넣었다. 바늘이 활성 칸 위에 서 있으므로 위치가 곧 설명이다.
	_onboarding_center_text(stage, Rect2(needle_x - 100.0, 2.0, 200.0, 22.0), "바늘 · 지속시간 동안 나간다", UIKit.FONT_BODY, page_color)
	var needle_texture := UIKit.pointer("needle")
	if needle_texture == null:
		_onboarding_glyph(stage, Vector2(needle_x, 32.0), "▼", UIKit.FONT_HEADING, page_color)
	else:
		var needle := TextureRect.new()
		needle.texture = needle_texture
		needle.position = Vector2(needle_x - 16.0, 18.0)
		needle.size = Vector2(32.0, 32.0)
		needle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		needle.modulate = page_color
		needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(needle)
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var slot_color: Color = slot["color"]
		var slot_x := ONBOARDING_RAIL_X + float(index) * (ONBOARDING_RAIL_SLOT.x + ONBOARDING_RAIL_GAP)
		var active := index == 2
		# 활성 칸은 색이 아니라 **기하**로 갈린다 — 슬롯칸(CELL · 안쪽이 밝다) + 흰 포커스 링.
		var slot_rect := Rect2(slot_x, ONBOARDING_RAIL_TOP, ONBOARDING_RAIL_SLOT.x, ONBOARDING_RAIL_SLOT.y)
		_onboarding_box(stage, slot_rect,
			UIKit.Role.CELL if active else UIKit.Role.CHIP,
			Color(slot_color, 0.16) if active else Color(0.0, 0.0, 0.0, 0.0))
		if active:
			var ring := Panel.new()
			ring.position = slot_rect.position - Vector2(4.0, 4.0)
			ring.size = slot_rect.size + Vector2(8.0, 8.0)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.add_theme_stylebox_override("panel", UIKit.focus_box())
			stage.add_child(ring)
		_onboarding_bar(stage, Rect2(slot_x + 12.0, ONBOARDING_RAIL_TOP + 12.0, ONBOARDING_RAIL_SLOT.x - 24.0, 20.0), Color(slot_color, 0.30))
		_onboarding_center_text(stage, Rect2(slot_x + 12.0, ONBOARDING_RAIL_TOP + 12.0, ONBOARDING_RAIL_SLOT.x - 24.0, 20.0), "칸 %d" % (index + 1), UIKit.FONT_LABEL, slot_color)
		_onboarding_center_text(stage, Rect2(slot_x, ONBOARDING_RAIL_TOP + 36.0, ONBOARDING_RAIL_SLOT.x, 24.0), String(slot["name"]), UIKit.FONT_HEADING, ink)
		_onboarding_center_text(stage, Rect2(slot_x, ONBOARDING_RAIL_TOP + 58.0, ONBOARDING_RAIL_SLOT.x, 20.0), String(slot["tag"]), UIKit.FONT_CAPTION, Color(ink, 0.78))
		# 각인 배지 — 필드 HUD와 같은 핍 3개 공식.
		for pip_index in 3:
			var filled := pip_index < int(slot["runes"])
			_onboarding_bar(stage, Rect2(slot_x + ONBOARDING_RAIL_SLOT.x * 0.5 - 20.0 + float(pip_index) * 14.0, ONBOARDING_RAIL_TOP + 80.0, 10.0, 10.0), GamePalette.YELLOW if filled else Color(ink, 0.24))
		if index < slots.size() - 1:
			_onboarding_glyph(stage, Vector2(slot_x + ONBOARDING_RAIL_SLOT.x + ONBOARDING_RAIL_GAP * 0.5, line_y + 2.0), "▶", UIKit.FONT_HEADING, FACTORY_RAIL_SPINE_BUILT.lightened(0.4))
	# --- 흐름 델타 두 종: 회귀(CYAN)와 도약(GREEN). 레일 아래 정적 꺾은선으로 그린다. ---
	var rail_bottom := ONBOARDING_RAIL_TOP + ONBOARDING_RAIL_SLOT.y
	var back_y := rail_bottom + 22.0
	var back_from := _onboarding_rail_center(3)
	var back_to := _onboarding_rail_center(2)
	_onboarding_bar(stage, Rect2(back_from - 1.5, rail_bottom + 4.0, 3.0, back_y - rail_bottom - 4.0), GamePalette.CYAN)
	_onboarding_bar(stage, Rect2(back_to, back_y, back_from - back_to, 3.0), GamePalette.CYAN)
	_onboarding_bar(stage, Rect2(back_to - 1.5, rail_bottom + 14.0, 3.0, back_y - rail_bottom - 14.0), GamePalette.CYAN)
	_onboarding_glyph(stage, Vector2(back_to, rail_bottom + 10.0), "▲", UIKit.FONT_HEADING, GamePalette.CYAN)
	_onboarding_text(stage, Rect2(back_from + 18.0, back_y - 12.0, 300.0, 24.0), "한 칸 뒤로  −1칸", UIKit.FONT_BODY, GamePalette.CYAN)
	var jump_y := rail_bottom + 54.0
	var jump_from := _onboarding_rail_center(0)
	var jump_to := _onboarding_rail_center(2)
	_onboarding_bar(stage, Rect2(jump_from - 1.5, rail_bottom + 4.0, 3.0, jump_y - rail_bottom - 4.0), GamePalette.GREEN)
	_onboarding_bar(stage, Rect2(jump_from, jump_y, jump_to - jump_from, 3.0), GamePalette.GREEN)
	_onboarding_bar(stage, Rect2(jump_to - 1.5, rail_bottom + 14.0, 3.0, jump_y - rail_bottom - 14.0), GamePalette.GREEN)
	_onboarding_glyph(stage, Vector2(jump_to, rail_bottom + 10.0), "▲", UIKit.FONT_HEADING, GamePalette.GREEN)
	_onboarding_text(stage, Rect2(jump_to + 18.0, jump_y - 12.0, 300.0, 24.0), "한 칸 건너뛰기  +2칸", UIKit.FONT_BODY, GamePalette.GREEN)
	var again_y := rail_bottom + 86.0
	_onboarding_glyph(stage, Vector2(_onboarding_rail_center(2), again_y), "↻", UIKit.FONT_HEADING, GamePalette.ORANGE)
	_onboarding_text(stage, Rect2(_onboarding_rail_center(2) + 18.0, again_y - 12.0, 320.0, 24.0), "두 번 치기  같은 칸 한 번 더", UIKit.FONT_BODY, GamePalette.ORANGE)
	# --- 한 칸 두 번 (필드 HUD 미니 스트립의 「밟은 횟수 점」과 같은 그림) ---
	# Y2: 구 과열 8단 온도계 자리다(§1.4). 규칙이 사라졌으니 그림도 사라져야 한다.
	# 여기서 배우는 것은 단 하나 — **두 번째 점이 켜지면 그 칸은 이 바퀴에 끝났다.**
	var cap_x := ONBOARDING_RAIL_X + rail_w + 30.0
	var cap_w := 74.0
	_onboarding_box(stage, Rect2(cap_x - 12.0, 30.0, cap_w + 56.0, 188.0), UIKit.Role.CHIP)
	_onboarding_center_text(stage, Rect2(cap_x, 6.0, cap_w, 22.0), "밟은 횟수", UIKit.FONT_BODY, GamePalette.ORANGE)
	for step in RuneEngine.SLOT_EXEC_CAP:
		_onboarding_bar(stage, Rect2(cap_x, 52.0 + float(step) * 64.0, cap_w, 48.0),
			GamePalette.YELLOW if step == 0 else GamePalette.ORANGE)
		_onboarding_text(stage, Rect2(cap_x + cap_w + 8.0, 66.0 + float(step) * 64.0, 30.0, 20.0), "%d" % (step + 1), UIKit.FONT_CAPTION, Color(ink, 0.72))
	_onboarding_center_text(stage, Rect2(cap_x - 20.0, 224.0, cap_w + 40.0, 22.0), "두 번이면 건너뜁니다", UIKit.FONT_CAPTION, GamePalette.ORANGE)
	# --- 한 바퀴 끝 = RELOAD 빚 청산 ---
	# X4: 「빚」을 **쉬운 말로 먼저 가르치고 이름을 뒤에 붙인다.** 이 낱말은 HUD 툴팁
	# (「빚 N.NN초」)이 쓰기 때문에 지울 수 없고, 처음 보는 사람에게는 뜻이 안 보인다.
	_onboarding_box(stage, Rect2(ONBOARDING_RAIL_X, 258.0, rail_w, 62.0), UIKit.Role.CHIP, Color(GamePalette.ORANGE, 0.10))
	_onboarding_center_text(stage, Rect2(ONBOARDING_RAIL_X, 266.0, rail_w, 26.0), "한 바퀴를 다 돌면 쉬는 시간 = RELOAD", UIKit.FONT_HEADING, GamePalette.ORANGE)
	_onboarding_center_text(stage, Rect2(ONBOARDING_RAIL_X, 292.0, rail_w, 22.0), "쌓인 쉬는 시간이 「빚」 · 많이 밟을수록 깁니다", UIKit.FONT_BODY, Color(ink, 0.80))

# -----------------------------------------------------------------------------
# W6b 온보딩 3페이지 — 각인 드래프트와 "미선택은 마왕에게"
# -----------------------------------------------------------------------------
# v1의 분기 도식(카드 2택)을 그대로 유지하되 내용을 v2의 각인 3택으로 바꾼다.
func _onboarding_diagram_fate(stage: Control, page_color: Color) -> void:
	var ink := UIKit.text_on(UIKit.Tone.SLATE, UIKit.Role.INSET)
	_onboarding_center_text(stage, Rect2(0.0, 4.0, ONBOARDING_STAGE_RECT.size.x, 24.0), "각인 세공사 · 보물상자 — 각인 3개 중 1개만 고른다", UIKit.FONT_HEADING, Color(ink, 0.82))
	var card := Vector2(240.0, 96.0)
	var gap := 30.0
	var card_top := 34.0
	var total := card.x * 3.0 + gap * 2.0
	var start_x := (ONBOARDING_STAGE_RECT.size.x - total) * 0.5
	var offers := [
		{"name":"한 칸 뒤로", "detail":"앞 칸으로 · 34%", "picked":false, "color":GamePalette.CYAN},
		{"name":"두 번 치기", "detail":"이 칸 한 번 더 · 41%", "picked":true, "color":GamePalette.GREEN},
		{"name":"빨리 감기", "detail":"레일 전체 · 확정", "picked":false, "color":GamePalette.MAGENTA}
	]
	# 여기 세 장은 진짜 각인 카드다 — 킷 카드 프레임 `Card.RUNE`(ABYSS · 별 문양)를
	# 그대로 쓴다. 고른 것은 SELECTED(흰 이중 링), 나머지 둘은 NORMAL이다.
	# 실전 각인 드래프트(U2 몫)와 같은 그림이라 여기서 배운 기하가 그대로 통한다.
	var card_ink := UIKit.text_on(UIKit.Tone.ABYSS, UIKit.Role.PANEL)
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var picked := bool(offer["picked"])
		var offer_x := start_x + float(index) * (card.x + gap)
		var frame := Panel.new()
		frame.position = Vector2(offer_x, card_top)
		frame.size = card
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.Card.RUNE,
			UIKit.CardState.SELECTED if picked else UIKit.CardState.NORMAL))
		stage.add_child(frame)
		_onboarding_center_text(stage, Rect2(offer_x, card_top + 10.0, card.x, 28.0), String(offer["name"]), UIKit.FONT_HEADING, card_ink)
		_onboarding_center_text(stage, Rect2(offer_x, card_top + 38.0, card.x, 22.0), String(offer["detail"]), UIKit.FONT_CAPTION, Color(card_ink, 0.78))
		_kit_glyph(stage, Vector2(offer_x + 32.0, card_top + 64.0),
			"check" if picked else "cross",
			GamePalette.GREEN if picked else GamePalette.RED, 20.0)
		_onboarding_center_text(stage, Rect2(offer_x + 20.0, card_top + 62.0, card.x - 20.0, 24.0), "내가 고른 각인" if picked else "마왕에게", UIKit.FONT_BODY, GamePalette.GREEN if picked else GamePalette.RED)
	var card_bottom := card_top + card.y
	var junction_y := 172.0
	var target := Vector2(330.0, 100.0)
	var target_top := 202.0
	var mine_x := 110.0
	var demon_x := 760.0
	var mine_center := mine_x + target.x * 0.5
	var demon_center := demon_x + target.x * 0.5
	var picked_center := start_x + card.x + gap + card.x * 0.5
	_onboarding_bar(stage, Rect2(picked_center - 1.5, card_bottom, 3.0, junction_y - card_bottom), GamePalette.GREEN)
	_onboarding_bar(stage, Rect2(mine_center - 1.5, junction_y, picked_center - mine_center + 3.0, 3.0), GamePalette.GREEN)
	_onboarding_bar(stage, Rect2(mine_center - 1.5, junction_y, 3.0, 12.0), GamePalette.GREEN)
	_onboarding_glyph(stage, Vector2(mine_center, junction_y + 20.0), "▼", UIKit.FONT_HEADING, GamePalette.GREEN)
	for side in [0, 2]:
		var side_center := start_x + float(side) * (card.x + gap) + card.x * 0.5
		_onboarding_bar(stage, Rect2(side_center - 1.5, card_bottom, 3.0, junction_y + 14.0 - card_bottom), GamePalette.RED)
		_onboarding_bar(stage, Rect2(minf(side_center, demon_center) - 1.5, junction_y + 14.0, absf(demon_center - side_center) + 3.0, 3.0), GamePalette.RED)
	_onboarding_bar(stage, Rect2(demon_center - 1.5, junction_y + 14.0, 3.0, 12.0), GamePalette.RED)
	_onboarding_glyph(stage, Vector2(demon_center, junction_y + 34.0), "▼", UIKit.FONT_HEADING, GamePalette.RED)
	# X4: 왼쪽 상자는 **글 대신 그림**으로 "각인 = 칸에 박히는 보석"을 말한다.
	# X2 §7.4 ③이 지목한 가장 약한 고리다 — 편집 화면·HUD의 각인 핍(6×4px)이
	# 무엇인지 어디서도 안 가르쳤다. 여기 미니 칸 하나가 그 그림을 준다.
	_onboarding_box(stage, Rect2(mine_x, target_top, target.x, target.y), UIKit.Role.CELL, Color(GamePalette.GREEN, 0.12))
	_onboarding_center_text(stage, Rect2(mine_x, target_top + 10.0, target.x, 26.0), "강화할 칸을 고른다", UIKit.FONT_HEADING, GamePalette.GREEN)
	# 미니 칸(칸 3) — 아래쪽에 각인 핍 3개가 박힌 필드 HUD·편집 화면과 같은 그림.
	var gem_slot := Rect2(mine_x + target.x * 0.5 - 46.0, target_top + 40.0, 92.0, 34.0)
	_onboarding_box(stage, gem_slot, UIKit.Role.CHIP, Color(GamePalette.CYAN, 0.18))
	_onboarding_center_text(stage, Rect2(gem_slot.position.x, gem_slot.position.y + 2.0, gem_slot.size.x, 18.0), "칸 3", UIKit.FONT_CAPTION, ink)
	for gem_index in 3:
		_onboarding_bar(stage,
			Rect2(gem_slot.position.x + gem_slot.size.x * 0.5 - 20.0 + float(gem_index) * 14.0,
				gem_slot.position.y + 22.0, 10.0, 8.0),
			GamePalette.YELLOW if gem_index < 2 else Color(ink, 0.24))
	_onboarding_center_text(stage, Rect2(mine_x, target_top + 76.0, target.x, 20.0), "카드를 옮겨도 각인은 칸에 남는다", UIKit.FONT_CAPTION, Color(ink, 0.78))
	_onboarding_box(stage, Rect2(demon_x, target_top, target.x, target.y), UIKit.Role.CELL, Color(GamePalette.RED, 0.14))
	_onboarding_center_text(stage, Rect2(demon_x, target_top + 14.0, target.x, 28.0), "마왕의 각인 조각", UIKit.FONT_HEADING, GamePalette.RED)
	_onboarding_center_text(stage, Rect2(demon_x, target_top + 46.0, target.x, 24.0), "조각 2개 = 마왕 각인 1개", UIKit.FONT_BODY, ink)
	_onboarding_center_text(stage, Rect2(demon_x, target_top + 70.0, target.x, 22.0), "오른쪽 위에 쌓입니다", UIKit.FONT_CAPTION, Color(ink, 0.78))
	# X4: 같은 말을 세 번 하던 가운데 칩을 두 줄로 줄였다(구 3줄째 "내가 안 쓰면
	# 마왕이 쓴다"는 오른쪽 빨간 상자가 그림으로 이미 말한다).
	_onboarding_box(stage, Rect2(470.0, target_top + 14.0, 260.0, 70.0), UIKit.Role.CHIP)
	_onboarding_center_text(stage, Rect2(470.0, target_top + 22.0, 260.0, 26.0), "고르지 않은 각인은", UIKit.FONT_BODY, page_color)
	_onboarding_center_text(stage, Rect2(470.0, target_top + 48.0, 260.0, 26.0), "사라지지 않는다", UIKit.FONT_HEADING, page_color)

# -----------------------------------------------------------------------------
# W6b 온보딩 4페이지 — V5에서 **5관문 · 체류 압박**으로 갈아끼웠다(기한 문구 철거)
# -----------------------------------------------------------------------------
func _onboarding_diagram_journey(stage: Control, page_color: Color) -> void:
	# 위: 하루의 낮/밤 비율 띠. 가운데: 5관문 타임라인. 아래: 전조와 강림.
	var ink := UIKit.text_on(UIKit.Tone.SLATE, UIKit.Role.INSET)
	var band_x := 108.0
	var band_w := 984.0
	var band_top := 16.0
	var band_h := 62.0
	var day_w := band_w * GameTuning.STAGE_DAY_DURATION[0] / (GameTuning.STAGE_DAY_DURATION[0] + GameTuning.STAGE_NIGHT_DURATION[0])
	_onboarding_box(stage, Rect2(band_x, band_top, day_w, band_h), UIKit.Role.CELL, Color(GamePalette.YELLOW, 0.14))
	_onboarding_center_text(stage, Rect2(band_x, band_top + 8.0, day_w, 26.0), "낮  %d초" % int(GameTuning.STAGE_DAY_DURATION[0]), UIKit.FONT_HEADING, GamePalette.YELLOW)
	_onboarding_center_text(stage, Rect2(band_x, band_top + 34.0, day_w, 22.0), "마물 · 균열 · 성에서 준비", UIKit.FONT_BODY, ink)
	_onboarding_box(stage, Rect2(band_x + day_w, band_top, band_w - day_w, band_h), UIKit.Role.CHIP, Color(GamePalette.NIGHT, 0.30))
	_onboarding_center_text(stage, Rect2(band_x + day_w, band_top + 8.0, band_w - day_w, 26.0), "밤  %d초" % int(GameTuning.STAGE_NIGHT_DURATION[0]), UIKit.FONT_HEADING, GamePalette.CYAN)
	_onboarding_center_text(stage, Rect2(band_x + day_w, band_top + 34.0, band_w - day_w, 22.0), "습격을 버틴다", UIKit.FONT_BODY, ink)
	# V5: 7일 타임라인 → **5관문 타임라인**. 필드 HUD의 스테이지 핍과 같은 언어다.
	var pip_top := 106.0
	var pip_gap := 22.0
	var pip_w := (118.0 * 7.0 + 22.0 * 6.0 - pip_gap * float(GameTuning.STAGE_COUNT - 1)) / float(GameTuning.STAGE_COUNT)
	var timeline_w := pip_w * float(GameTuning.STAGE_COUNT) + pip_gap * float(GameTuning.STAGE_COUNT - 1)
	var timeline_x := (ONBOARDING_STAGE_RECT.size.x - timeline_w) * 0.5
	for stage_index in GameTuning.STAGE_COUNT:
		var stage_number := stage_index + 1
		var pip_x := timeline_x + float(stage_index) * (pip_w + pip_gap)
		var pip_color := GamePalette.YELLOW
		if stage_number >= GameTuning.STAGE_COUNT:
			pip_color = GamePalette.RED
		elif stage_number >= 3:
			pip_color = GamePalette.MAGENTA
		_onboarding_box(stage, Rect2(pip_x, pip_top, pip_w, 54.0), UIKit.Role.CHIP, Color(pip_color, 0.14))
		_onboarding_center_text(stage, Rect2(pip_x, pip_top + 6.0, pip_w, 24.0), "%d관문" % stage_number, UIKit.FONT_HEADING, ink)
		_onboarding_center_text(stage, Rect2(pip_x, pip_top + 30.0, pip_w, 20.0), String(GameTuning.STAGE_NAMES[stage_index]), UIKit.FONT_CAPTION, pip_color)
		if stage_index < GameTuning.STAGE_COUNT - 1:
			_onboarding_glyph(stage, Vector2(pip_x + pip_w + pip_gap * 0.5, pip_top + 27.0), "▶", UIKit.FONT_HEADING, page_color.darkened(0.1))
	# X4: 프로젝트에서 가장 길던 한 줄(59자)이다. 등급표는 **숫자만 남기고** 문장을
	# 걷었다 — "빨리 넘을수록 높습니다"는 S < A < B 순서가 이미 말한다.
	_onboarding_center_text(stage, Rect2(0.0, pip_top + 62.0, ONBOARDING_STAGE_RECT.size.x, 22.0), "기한 없음 · %d일 S · %d일 A · %d일 B" % [GameTuning.GRADE_S_MAX_DAYS, GameTuning.GRADE_A_MAX_DAYS, GameTuning.GRADE_B_MAX_DAYS], UIKit.FONT_BODY, Color(ink, 0.82))
	# 아래 3칸: 전조 → 마왕 프리뷰 → 강림
	var chip := Vector2(330.0, 96.0)
	var chip_gap := 44.0
	var chain_w := chip.x * 3.0 + chip_gap * 2.0
	var chain_x := (ONBOARDING_STAGE_RECT.size.x - chain_w) * 0.5
	var chain_top := 206.0
	# X4: 세 칩의 설명을 각각 두 문장 → **한 줄**로 줄였다. 셋 다 "체류가 오르면
	# 이런 일이 생긴다"는 같은 이야기의 예시라, 자세한 조건은 필드에서 배너와
	# HUD 툴팁이 그때그때 말한다.
	var chain := [
		{"title":"밤의 전조", "desc":"밤마다 마왕의 한 칸이 내려온다", "color":GamePalette.MAGENTA},
		{"title":"베이스 캠프", "desc":"보스문 앞 · 성과 같은 상인 넷", "color":page_color},
		{"title":"잠식과 강림", "desc":"더 버티면 보스가 직접 내려온다", "color":GamePalette.RED}
	]
	for index in chain.size():
		var entry: Dictionary = chain[index]
		var entry_color: Color = entry["color"]
		var chip_x := chain_x + float(index) * (chip.x + chip_gap)
		_onboarding_box(stage, Rect2(chip_x, chain_top, chip.x, chip.y), UIKit.Role.CHIP)
		_onboarding_center_text(stage, Rect2(chip_x, chain_top + 8.0, chip.x, 26.0), String(entry["title"]), UIKit.FONT_HEADING, entry_color)
		_onboarding_center_text(stage, Rect2(chip_x + 10.0, chain_top + 34.0, chip.x - 20.0, 56.0), String(entry["desc"]), UIKit.FONT_CAPTION, Color(ink, 0.80))
		if index < chain.size() - 1:
			_onboarding_glyph(stage, Vector2(chip_x + chip.x + chip_gap * 0.5, chain_top + chip.y * 0.5), "▶", UIKit.FONT_HEADING, page_color)

func _build_onboarding_steps(panel: Control, page_color: Color) -> void:
	# 공장 레일과 같은 언어: 연속 스파인 라인 위에 페이지 칸이 인라인으로 올라가고
	# 지나온 구간만 밝은 색으로 이어진다. (정적 — 트윈 없음)
	var strip_width := ONBOARDING_STEP_PITCH * float(ONBOARDING_PAGE_COUNT - 1) + ONBOARDING_STEP_SIZE.x
	var strip := Control.new()
	strip.position = Vector2((ONBOARDING_PANEL_RECT.size.x - strip_width) * 0.5, ONBOARDING_NAV_Y)
	strip.size = Vector2(strip_width, ONBOARDING_NAV_SIZE.y)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(strip)
	var line_y := (strip.size.y - 4.0) * 0.5
	var spine := ColorRect.new()
	spine.position = Vector2(0.0, line_y)
	spine.size = Vector2(strip_width, 4.0)
	spine.color = FACTORY_RAIL_SPINE_GHOST
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(spine)
	var travelled := ColorRect.new()
	travelled.position = Vector2(0.0, line_y)
	travelled.size = Vector2(float(onboarding_page) * ONBOARDING_STEP_PITCH + ONBOARDING_STEP_SIZE.x * 0.5, 4.0)
	travelled.color = FACTORY_RAIL_SPINE_BUILT
	travelled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(travelled)
	for index in ONBOARDING_PAGE_COUNT:
		# U1 v3: 칸의 상태는 색이 아니라 **버튼 변종**으로 갈린다.
		#   지금 칸 = PRIMARY(WOOD 융기) · 지나온 칸 = NEUTRAL(SLATE) · 남은 칸 = QUIET(GOLD).
		# QUIET은 밝은 parchment 껍데기 안에 있으므로 §5의 사용 조건을 지킨다.
		var variant := UIKit.Btn.QUIET
		if index == onboarding_page:
			variant = UIKit.Btn.PRIMARY
		elif index < onboarding_page:
			variant = UIKit.Btn.NEUTRAL
		var step := _kit_button(strip,
			Rect2(Vector2(float(index) * ONBOARDING_STEP_PITCH,
				(strip.size.y - ONBOARDING_STEP_SIZE.y) * 0.5), ONBOARDING_STEP_SIZE),
			"%d" % (index + 1), variant, UIKit.FONT_BODY)
		step.focus_mode = Control.FOCUS_NONE
		step.pressed.connect(_show_onboarding.bind(index))

func _set_onboarding_skip_today(enabled: bool) -> void:
	onboarding_skip_today = enabled

func _toggle_onboarding_skip_today() -> void:
	_set_onboarding_skip_today(not onboarding_skip_today)
	_show_onboarding(onboarding_page)

func _onboarding_hidden_today() -> bool:
	var config := ConfigFile.new()
	if config.load(GameTuning.PROGRESS_PATH) != OK:
		return false
	return String(config.get_value("settings", "onboarding_hide_date", "")) == Time.get_date_string_from_system()

func _finish_onboarding() -> void:
	onboarding_seen_session = true
	if onboarding_skip_today:
		var config := ConfigFile.new()
		config.load(GameTuning.PROGRESS_PATH)
		config.set_value("settings", "onboarding_hide_date", Time.get_date_string_from_system())
		config.save(GameTuning.PROGRESS_PATH)
	_begin_run()

func _continue_saved_run() -> void:
	var snapshot := _read_run_snapshot()
	if snapshot.is_empty():
		saved_run_available = false
		saved_run_playtime = 0.0
		saved_run_stage = 0
		saved_run_total_days = 0
		_show_menu()
		return
	selected_character_id = String(snapshot.get("character_id", "swordsman"))
	_begin_run(snapshot)

func _begin_run(snapshot: Dictionary = {}) -> void:
	var resuming := not snapshot.is_empty()
	onboarding_seen_session = true
	if not resuming:
		selected_character_id = "swordsman"
		if not automated_test and OS.get_cmdline_user_args().is_empty():
			_clear_run_save()
	get_tree().paused = false
	_clear_overlay()
	if is_instance_valid(gameplay_root):
		gameplay_root.free()
	gameplay_root = Node2D.new()
	gameplay_root.name = "Gameplay"
	gameplay_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gameplay_root)

	player = PLAYER_SCRIPT.new()
	player.setup(self, selected_character_id)
	player.position = Vector2.ZERO
	player.health_changed.connect(_on_player_health_changed)
	player.shield_changed.connect(_on_player_shield_changed)
	player.died.connect(_on_player_died)
	gameplay_root.add_child(player)
	factory = FACTORY_SCRIPT.new()
	factory.reset()
	if run_cycle_seed == 0:
		run_cycle_seed = rng.randi() | 1
	# V5: 월드 생성은 `_rebuild_stage_world()`가 소유한다(설계 §2.2). 여기서는 만들지 않고
	# 아래 `clock.reset()` 뒤에 스테이지 1로 세운다 — 그레이드가 클럭의 스테이지를 읽기 때문이다.
	# 균열 시드도 그때 `world.begin_stage()`가 스테이지 시드로 깐다(구 begin_run_rifts 자리).
	player_cycle = CYCLE_CONTROLLER_SCRIPT.new()
	player_cycle.setup(self, player, factory, false, true, run_cycle_seed)
	gameplay_root.add_child(player_cycle)
	skill_effect_controller = SKILL_EFFECT_SCRIPT.new()
	skill_effect_controller.setup(self, player)
	gameplay_root.add_child(skill_effect_controller)
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color.WHITE
	gameplay_root.add_child(canvas_modulate)

	selected_skills.clear()
	rejected_skills.clear()
	boss_items.clear()
	trophy_reject_skills.clear()
	camp_states.clear()
	rift_states.clear()
	# === Y6: 런 스코프 초기화 (§6.2 예산 · §6.3 소비 칸) ===
	run_event_count = 0
	consumable_item = ""
	consumable_swap = ""
	night_eye_nights = 0
	night_eye_active = false
	_clear_decoy()
	pact_uses = {"sell_day":0, "buy_day":0, "mortgage":0}
	rune_shop_purchases = 0
	rune_shop_offers.clear()
	rune_shop_rerolls = 0
	rune_shop_castle_id = ""
	rune_shop_buttons.clear()
	spy_wipe_stage = 0
	# === W10: 월식 · 런 기록 초기화 ===
	blight_active = false
	blight_marked = 0
	blight_sweep_timer = 0.0
	run_peak_steps = 0
	boss_peak_steps = 0
	boss_reload_windows = 0
	boss_reload_open = false
	peak_bound_cycle = null
	boss_rail_bound_cycle = null
	# === V8: 트로피 · 성장 천장 · 시너지 계측 런 스코프 초기화 ===
	pending_trophy.clear()
	pending_trophy_followup = ""
	trophy_place_pending = false
	growth_cap_conversions = 0
	run_synergy_triggers = 0
	if is_instance_valid(player):
		player.restore_trophies([])
	current_pair.clear()
	opened_features.clear()
	current_interactable.clear()
	# v1의 active_enemies/enemy_spatial/spawn_timer/spatial_refresh_timer/
	# hotfix_burst_running 초기화 5줄을 그대로 모은 것이다(값 동일).
	combat.reset()
	active_effect_nodes = 0
	xp_fraction = 0.0
	inside_castle = false
	current_castle.clear()
	castle_interior = null
	level = 1
	experience = 0
	xp_target = 8
	kills = 0
	gold = 20
	elapsed_time = 0.0
	# === V5: 스테이지 클럭 · 마왕 성장 초기화 ===
	clock.reset()
	demon_lord.reset()
	stage_descent_pending = false
	camp_rest_used = false
	inside_camp = false
	stage_scaled_enemies = 0
	# === V7: 스테이지 보스 런 스코프 초기화 ===
	_teardown_stage_boss()
	stage_boss_factory = null
	stage_boss_profile.clear()
	stage_boss_cleared = false
	stage_boss_defeat_handled = false
	stage_boss_telegraphs = 0
	stage_boss_phase_shifts = 0
	pending_stage_trophy.clear()
	boss_preview_kind = "demon"
	player_status_dot_total = 0.0
	player_dot_flush_timer = 0.0
	# 클럭이 스테이지 1로 돌아온 뒤에야 월드를 세운다(그레이드·아틀라스가 스테이지를 읽는다).
	_rebuild_stage_world(1)
	_clear_omen()
	omen_night_count = 0
	pending_omen_reward.clear()
	omen_reward_buttons.clear()
	interaction_timer = 0.0
	hud_refresh_timer = 0.0
	collect_sound_counter = 0
	boss = null
	boss_factory = null
	boss_cycle = null
	pending_boss_toast_cards.clear()
	boss_toast_queue.clear()
	if is_instance_valid(boss_toast):
		boss_toast.queue_free()
	boss_toast = null
	shop_offers.clear()
	shop_refresh_count = 0
	shop_castle_id = ""
	# X1: 각인 진열도 카드 상점과 같은 방문 스코프다 — 새 런/이어하기에서 비워 둔다.
	rune_shop_offers.clear()
	rune_shop_rerolls = 0
	rune_shop_castle_id = ""
	rune_shop_buttons.clear()
	if resuming:
		_restore_run_snapshot(snapshot)
	# Y5: 시작 자리가 물이나 돌에 막혀 있으면 가장 가까운 걸을 수 있는 칸으로 옮긴다.
	# 이어하기 복원 **뒤**에 두는 이유는 두 경로를 한 줄로 덮기 위해서다 —
	# 새 런은 원점을, 이어하기는 저장된 자리를 각자 검사받는다.
	if is_instance_valid(player):
		player.global_position = _walkable_spawn_point(player.global_position)
	state = "playing"
	hud.visible = true
	boss_panel.visible = false
	interaction_text.visible = false
	_apply_stage_grade()
	_spawn_stage_starter_population()
	# === Y6: dwell 0의 사건 한 개를 지금 배치한다(§6.2) ===
	_maintain_event_schedule()
	_update_hud()
	# V8: 런 시작 각성 폴링(`_check_first_advancement`) **삭제**. v3의 성장 이정표는
	# 시간이 아니라 **보스 격파**라 폴링할 대상 자체가 없다(설계 §5.5).
	run_save_timer = 5.0
	_show_banner(
		"모험을 이어갑니다 · %s" % clock.stage_label() if resuming else "1스테이지 %s · 머무는 밤마다 세계가 강해진다" % clock.stage_name(),
		GamePalette.CYAN if resuming else GamePalette.YELLOW, 2.6)
	# === U3: 스포트라이트 길잡이 — 새 런의 첫 낮에만 (파일 끝 U3 절) ===
	# 이어하기·자동 테스트·프리뷰에서는 열리지 않는다. 열리면 아래 저장은 스스로 쉰다
	# (`_run_save_blocked_reason() == "guide"`) — 길잡이가 끝날 때 한 번 저장한다.
	_abandon_guide()
	_maybe_start_guide(resuming)
	if not automated_test and OS.get_cmdline_user_args().is_empty():
		_save_run_snapshot()

# =============================================================================
# V5: 스테이지 전환 파이프라인 (설계 §2.1 · §2.2 · 부록 A-2 ⑩)
# =============================================================================
# 진입점은 정확히 셋이다.
#   ① `_begin_run()`          런 시작 → `_rebuild_stage_world(1)`
#   ② `advance_stage()`       **스테이지 N 클리어 이벤트.** V7의 보스 격파 처리가 부른다.
#                             임시 트리거로 테스트(`--stage-test`)도 이걸 그대로 쓴다.
#   ③ `clock.stage_started`   ②가 만든 시그널 → `_on_stage_started()` → `_begin_stage()`
#
# 클럭이 시그널을 쏘고 game.gd가 월드를 다시 세우는 구조라, 저장 복원(V9)이
# `clock.from_snapshot()`만 해도 같은 경로를 탈 수 있다.
#
# 스테이지를 넘어 **유지되는 것**: 레벨/경험치/스탯 · 5칸 덱과 각인 · 보관함 · 장비 ·
#   골드 · rejected_skills(마왕 성장) · run_cycle_seed · 총 일수 · dwell(절반 감쇠).
# **초기화되는 것**: 월드 · 랜드마크 · 균열 예산 · opened_features · 잠식 · 캠프 휴식 ·
#   강림 밸브 · 필드 마물.

## 스테이지 월드 시드. 같은 런에서 스테이지마다 다른 지형이 나오고, 같은 런 시드면
## 언제 다시 만들어도 같은 지형이 나온다(저장·리플레이·테스트 계약).
func stage_world_seed(stage_number: int) -> int:
	return absi(run_cycle_seed ^ (stage_number * 2654435761)) | 1

## 월드를 통째로 새로 만든다(설계 §2.2가 검토하고 버린 대안 2개의 결론).
## 이전 월드를 `queue_free()`하므로 `wfc_chunk_generator`의 `dry_zones` 누적과
## `opened_features`·`rifts` 잔재가 스테이지를 넘어오지 않는다.
## `seed_override`가 0이 아니면 그 시드로 세운다 — **이어하기 전용 경로**다(V9).
## 저장된 `stage_seed`를 그대로 먹여야 `stage_world_seed()` 식이 나중에 바뀌어도
## 이미 저장된 런의 지형·랜드마크·균열 후보가 흔들리지 않는다(설계 §9의 결정성 보험).
func _rebuild_stage_world(stage_number: int, seed_override: int = 0) -> void:
	if not is_instance_valid(gameplay_root):
		return
	if is_instance_valid(world):
		world.queue_free()
	world = WORLD_GRID_SCRIPT.new()
	world.setup(player)
	gameplay_root.add_child(world)
	gameplay_root.move_child(world, 0)
	world.begin_stage(stage_number, seed_override if seed_override != 0 else stage_world_seed(stage_number))
	opened_features.clear()
	world.set_opened_features(opened_features)
	world.set_cleared_trial_camps({})
	rift_states.clear()
	# === Y6: 발견·필드 사건은 스테이지 스코프다(§6.1 · §6.2) ===
	_reset_stage_events()
	_seed_stage_discovery()
	current_interactable.clear()

## =============================================================================
## Y5: 스테이지 시작 자리 — 원점이 막혀 있으면 가장 가까운 걸을 수 있는 칸으로 옮긴다
## =============================================================================
## 스테이지 시작 자리는 v2부터 늘 원점(0,0)이었고, 원점에는 랜드마크 덮개도
## dry zone도 없었다. Y5가 두 가지를 바꾸면서 이 자리가 처음으로 위험해졌다:
##   ① 물을 늘렸다(호수 격자 18 → 13칸) — 원점이 호수에 잠길 확률이 올라간다
##   ② 돌을 못 지나가게 했다 — 원점 타일이 `rocks`면 플레이어가 태어나자마자 낀다
## ①은 `world_grid.begin_stage()`가 스폰 둘레에 dry zone을 깔아 막지만, 돌은
## dry zone으로 못 막는다(호수 레이어가 아니라 WFC가 뽑는다). 그래서 여기서 한 번 더 본다.
##
## **막히지 않았으면 원래 자리를 그대로 쓴다** — 시드가 같으면 시작 자리도 같아야 하고
## (저장·리플레이·테스트 계약), 실제로 걸리는 경우는 드물다. 이어하기 복원 뒤에도
## 한 번 부른다: 저장될 때는 멀쩡했던 자리가 새 지형 규칙(돌 충돌)에서는 막힐 수 있다.
const SPAWN_RESCUE_MIN := 48.0
const SPAWN_RESCUE_MAX := 220.0

func _walkable_spawn_point(origin: Vector2) -> Vector2:
	if not is_instance_valid(world):
		return origin
	if world.is_walkable(origin):
		return origin
	# `find_walkable_near`가 물과 돌을 같은 `is_walkable`로 함께 거른다.
	# 가까운 고리부터 찾으므로 시작 자리가 필드 저편으로 튀지 않는다.
	return world.find_walkable_near(origin, rng, SPAWN_RESCUE_MIN, SPAWN_RESCUE_MAX)

## 런 시작·스테이지 개시의 공통 필드 population. v2 `_begin_run`의 9기 그대로다.
func _spawn_stage_starter_population() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	var starter_behaviors: Array[int] = [1, 1, 1, 2, 2, 2, 3, 3, 4]
	for behavior: int in starter_behaviors:
		var spawn_position: Vector2 = world.find_walkable_near(player.global_position, rng, 260.0, 720.0)
		combat.spawn_enemy_instance(spawn_position, behavior)

## **스테이지 N 클리어.** V7의 보스 격파 처리 끝에서 부르면 전환이 통째로 돈다.
## 클럭이 dwell을 ×0.5 감쇠하고 총 일수를 이월한 뒤 `stage_started`를 쏜다.
func advance_stage() -> bool:
	if not is_instance_valid(player) or clock.is_run_complete():
		return false
	if is_instance_valid(world):
		world.set_boss_gate_cleared(true)
	# 격파 보상의 고정 항목 — 완전 회복(설계 §2.1 "격파 → 트로피 → 완전 회복 → 다음 스테이지").
	# 트로피 2택1은 V8 몫이라 여기서는 회복만 한다.
	player.health = player.max_health
	player.displayed_health = player.health
	player.trailing_health = player.health
	clock.advance_stage()
	# X1: 마왕 성장 하한. 스테이지 정산은 마왕이 자라는 유일한 정기 시점이다.
	_enforce_demon_growth_floor()
	return true

# =============================================================================
# X1 — 마왕 성장 하한 (사용자 피드백 ④ "취소는 마왕에게도 이득이 안 가게"의 대가)
# =============================================================================
# 마왕이 받는 카드의 최대 원천은 **레벨업에서 버린 한 장**이다. balance_probe ⑭ 실측
# 기준 런 전체 레벨업 19회 = 트로피 5장의 네 배다. 취소가 그 경로를 끊으므로
# "전부 취소" 플레이에서는 마왕이 트로피 5장 + 저주 상자 몇 장으로 끝나 5칸을 못 채운다.
# 마지막 전투가 빈 레일과 싸우는 일이 되면 취소는 이득이 아니라 **게임을 지우는 버튼**이다.
#
# 그래서 스테이지를 넘길 때마다 하한을 본다: 총 받은 카드 수 < 4 × 격파 스테이지면
# **모자란 만큼만** 드래프트 풀에서 보충한다. 세 가지를 지킨다.
#   ① 정상 플레이는 절대 닿지 않는다. 실측 누적(레벨업 8/12/15/17/19 + 트로피 1~5)이
#      9 / 14 / 18 / 21 / 24장이고 하한은 4 / 8 / 12 / 16 / 20이다 — 항상 위에 있다.
#   ② 취소 플레이의 마왕은 5스테이지에 20장으로 끝난다(정상 24장의 83%).
#      `rune_capacity()`는 20/4 = 5개(정상 6개)라 각인도 한 개만 적다.
#   ③ 보충 카드는 **드래프트 풀에서만** 뽑는다(handoff-w7 §8 규칙). 플레이어가 본 적
#      없는 카드가 고스트 레일에 서면 안 된다.
func _enforce_demon_growth_floor() -> int:
	if demon_lord == null or clock == null:
		return 0
	var target := GameTuning.DEMON_MIN_CARDS_PER_STAGE * maxi(0, clock.stages_cleared)
	var added := 0
	var pool := DealCardLibrary.draft_pool()
	while demon_lord.received_card_count() < target and not pool.is_empty():
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		rejected_skills.append(String(pick["id"]))
		added += 1
	if added > 0:
		demon_lord.sync_runes(rng)
		_show_banner("마왕이 스스로 세력을 불렸습니다 · 카드 %d장" % added, GamePalette.MAGENTA, 2.6)
	return added

func _on_stage_started(stage_number: int, _dwell_value: int) -> void:
	if state in ["won", "lost"]:
		return
	# 5스테이지 보스를 깬 뒤에는 **필드로 돌아가지 않는다**(부록 A-1 ③ · 즉시 마왕전).
	# 월드를 다시 세우면 마왕전 직전에 빈 필드가 한 프레임 보인다.
	if clock.is_run_complete():
		return
	_begin_stage(stage_number)

## 새 스테이지 개시. 월드 재생성 + 스테이지 스코프 상태 초기화 + 스폰 + 배너.
func _begin_stage(stage_number: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(gameplay_root):
		return
	_clear_omen()
	for enemy: Node in combat.active_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	combat.reset()
	for orb: Node in get_tree().get_nodes_in_group("xp_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	_rebuild_stage_world(stage_number)
	# 스테이지 스코프 상태 — 잠식·강림 밸브·캠프 휴식은 스테이지마다 다시 채워진다(§2.2).
	blight_active = false
	blight_marked = 0
	blight_sweep_timer = 0.0
	stage_descent_pending = false
	camp_rest_used = false
	stage_scaled_enemies = 0
	# === V7: 스테이지 스코프 — 새 스테이지에는 새 관문과 새 보스가 선다 ===
	_teardown_stage_boss()
	stage_boss_factory = null
	stage_boss_profile.clear()
	stage_boss_cleared = false
	stage_boss_defeat_handled = false
	stage_boss_telegraphs = 0
	stage_boss_phase_shifts = 0
	boss_preview_kind = "demon"
	player_status_dot_total = 0.0
	player_dot_flush_timer = 0.0
	interaction_text.visible = false
	player.global_position = _walkable_spawn_point(Vector2.ZERO)
	player.velocity = Vector2.ZERO
	player.dash_time_left = 0.0
	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	player.grant_invulnerability(GameTuning.STAGE_SPAWN_INVULN)
	_spawn_stage_starter_population()
	_apply_stage_grade()
	_update_world_lighting(1.0)
	# dwell 감쇠 뒤에도 임계 위에 있으면 잠식이 즉시 다시 켜진다(정상 — 과파밍의 대가).
	_check_stage_blight()
	_maintain_rift_schedule()
	_maintain_event_schedule()
	_update_hud()
	_show_banner("%d스테이지 · %s · 체류 %d에서 시작 · 총 %d일차" % [
		clock.stage, clock.stage_name(), clock.dwell, clock.day_number
	], GamePalette.CYAN, 3.4)
	play_sound("camp", -2.0)

# =============================================================================
# V5 → V6: 스테이지 기저 배율 스윕은 **삭제됐다** (설계 §6.2 · §6.3)
# =============================================================================
# V5는 `combat_resolver.gd`를 열 수 없어 `STAGE_SCALE_META` 메타 + `_sweep_stage_scaling()`
# + `_apply_stage_scaling_to()` 3종을 여기 두고 매 프레임 폴링으로 배율을 먹였다
# (handoff-v5 §6). V6이 설계가 지정한 자리 —
# **`combat_resolver.apply_stage_scaling()` (스폰 경로, 마물 1기당 정확히 1회)** —
# 로 옮기면서 셋과 `_process`의 호출 한 줄을 함께 지웠다.
# 두 곳에 두면 배율이 제곱된다. 회귀 감시는 `--combat-test`의 `stage_scale` 판정이 한다.

# =============================================================================
# V5: 강림 안전 밸브 (설계 §6.6 · 부록 A-3 ① = 채택)
# =============================================================================
# dwell이 `DWELL_DESCENT[stage]`(=14/13/12/11/10)에 닿으면 스테이지 보스가 필드로
# 내려온다. dwell 14 = 스테이지 하나에 약 28분이라 정상 플레이는 절대 닿지 않는다.
# **V7이 실체화했다** — V5는 상태와 경고까지였고 여기서 실제 보스를 필드에 세운다.
#
# 강림 보스가 정상 보스와 다른 것은 정확히 넷이다(설계 §6.6):
#   ① 프리뷰 없음  ② 칸 +1 (`STAGE_DESCENT_SLOT_BONUS` — **A도 4칸이 된다**)
#   ③ HP ×1.15     ④ 이 경로를 밟으면 승리 등급이 C로 고정(`clock.mark_descended()`)
# **도망칠 곳은 없다.** 보스는 `is_boss`라 거리 디스폰(1,650px)을 타지 않고 항상
# 플레이어를 향해 움직인다(enemy.gd `_physics_process`). 필드도 비우지 않으므로
# 잡몹과 보스를 동시에 상대하게 된다 — 그게 밸브의 압박이다.
func _trigger_stage_descent() -> void:
	if state != "playing" or stage_descent_pending or stage_boss_cleared:
		return
	if is_instance_valid(stage_boss):
		return
	stage_descent_pending = true
	clock.mark_descended()
	_show_banner("강림 · %d스테이지 보스가 필드로 내려옵니다 · 미리 볼 수 없음 · 승리 등급 C 고정" % clock.stage, GamePalette.RED, 4.4)
	shake_camera(14.0, 0.8)
	play_sound("boss", -2.0)
	_begin_stage_boss_descent()
	_update_hud()

## V7 조회 창구 — "지금 이 스테이지에서 밸브가 당겨졌는가".
func stage_descent_active() -> bool:
	return stage_descent_pending

func uses_factory_combat() -> bool:
	return true

func can_cycle_run(is_boss_cycle: bool = false) -> bool:
	if is_boss_cycle:
		# W4 추가절: 전조(前兆)는 필드(playing)에서 마왕의 한 칸을 시연하므로
		# 보스 사이클이 필드에서도 돌아야 한다. 마왕 본체 전투는 종전대로 state=="boss".
		# (이 함수는 §7.3 표에서 W2 소유다 — 전조를 붙이려면 이 한 줄이 반드시 필요해
		#  가산 절만 추가했다. **W2가 이 규칙을 그대로 유지했다** — 지우지 말 것.)
		if state == "playing" and not inside_castle and is_instance_valid(active_omen):
			return true
		# V7 추가절: **강림한 스테이지 보스는 필드(playing)에서 자기 사이클을 돌린다**(§6.6).
		# 보스방 전투는 종전대로 state == "boss"다.
		if state == "playing" and not inside_castle and stage_boss_active():
			return true
		return state == "boss"
	return state in ["playing", "boss"] and not inside_castle

func get_factory_dash_multiplier() -> float:
	if factory == null:
		return 1.0
	return clampf(1.0 + float(factory.global_effects().get("dash_reload", 0.0)), 0.45, 1.5)

func can_player_attack() -> bool:
	return state in ["playing", "boss"]

func can_player_dash() -> bool:
	return state in ["playing", "boss"]

# 일시정지 모달(스킬 확정·공장 배치/편집/강화/건설·아이템 2지선다·운명 전달·NPC 서비스·
# 전직 특별 카드)에서 필드로 돌아올 때 0.5초 유예 무적을 준다.
# 성 내부에서 필드로 나올 때도 같은 무적을 준다(페이드 전환 후 위치 복귀 직후).
# 필드 전투가 없는 상태(castle_interior·menu 등)에서는 부여하지 않는다.
func _grant_modal_return_invulnerability() -> void:
	if state not in ["playing", "boss"] or not is_instance_valid(player):
		return
	player.grant_invulnerability(GameTuning.MODAL_RETURN_INVULN)

func on_player_dash_started(attacker: Node2D) -> void:
	spawn_burst(attacker.global_position, GamePalette.CYAN, 10, 125.0, 0.24)
	spawn_attack_effect(attacker.global_position, "dash", GamePalette.CYAN, -attacker.dash_direction, 82.0, 0.18)
	play_sound("shoot", -7.0)

func process_dash_damage(hit_ids: Dictionary) -> void:
	combat.process_dash_damage(hit_ids)

func can_player_stand(point: Vector2) -> bool:
	if inside_castle and is_instance_valid(castle_interior):
		return castle_interior.is_walkable(point)
	return is_instance_valid(world) and world.is_walkable(point)

func can_enemy_stand(point: Vector2) -> bool:
	return is_instance_valid(world) and world.is_walkable(point)

# =============================================================================
# W3 이관 알림 — 필드 population과 적 인스턴스 생성
# =============================================================================
# `_current_spawn_interval` `_current_enemy_limit` `_night_raid_burst_count`
# `_maintain_field_population` `_roll_field_behavior` `_spawn_enemy_instance`는
# core/combat_resolver.gd로 이동했다. 호출부는 `combat.<밑줄 없는 같은 이름>()`이다.

# =============================================================================
# W9: 균열(Rift) — 설계 §5.5 (시련 캠프 대체)
# =============================================================================
# 구 시련 캠프 3함수를 균열판으로 복제한 것이다(handoff-w8 §3.2 대응표 그대로).
# 바뀐 것은 네 가지뿐이다:
#   ① 상태 소유자  camp_states(4방향 고정) → world.get_rifts()(동적 3개) + rift_states
#   ② 정예 수      9 → 3~5 (균열 index로 결정)
#   ③ 정예 배율    ×5 → ×3 (설계 §5.5)
#   ④ 보상        시련 구슬(폐기) → 각인 3택1 + 골드 + 체력 전회복
#
# V5 재키잉(설계 §2.4): v2 "2·4·6일차 낮 · 런당 3"에서
# **"dwell 1·3 · 스테이지당 2 · 런 최대 10"**으로 옮겼다. 스케줄 유지 방식은 v2 그대로
# "지금까지 몇 개가 열렸어야 하는가"를 세는 것이라 ①자리를 못 찾아 실패한
# 개설(`no_site`)의 재시도와 ②계약 NPC가 dwell을 건너뛴 경우를 자동으로 흡수한다.
const RIFT_CAMP_PREFIX := "rift_"
const RIFT_ELITE_MIN := 3
const RIFT_ELITE_MAX := 5
## 설계 §5.5의 정예 배율 하향 ×5 → ×3은 W12가 `GameTuning.TRIAL_ELITE_HEALTH_MUL`로
## 옮겼다(W9의 사후 ×0.6 우회로는 삭제). 여기에는 더 이상 배율 상수가 없다.
const RIFT_REWARD_GOLD := 60
## 균열 접근 판정 반경. 구 `_check_trial_camps()`의 520px을 그대로 쓴다.
const RIFT_APPROACH_RADIUS := 520.0

## 이번 스테이지에서 이 dwell까지 열려 있어야 하는 균열 수. 인자가 음수면 현재 dwell.
## 스테이지 예산(2)을 절대 넘지 않는다 — 계산은 StageClock이 소유한다.
func rifts_due(dwell_value: int = -1) -> int:
	return clock.rifts_due(dwell_value)

## 개설이 밀렸으면 따라잡는다. 이정표 도달 시와 매일 낮 시작에 부른다.
func _maintain_rift_schedule() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	var due := rifts_due()
	var opened := world.get_rifts().size()
	while opened < due and world.rift_budget_remaining() > 0:
		if not _spawn_scheduled_rift():
			# "no_site"는 예산을 먹지 않는다 → 다음 낮에 다시 시도한다.
			# "budget_exhausted"면 rift_budget_remaining()이 0이라 루프가 끝난다.
			return
		opened += 1

func _spawn_scheduled_rift() -> bool:
	# 성 안에서는 player.global_position이 성 내부 로컬 좌표라 월드 기준이 아니다.
	# 계약으로 성 안에서 일수가 넘어간 경우를 위해 필드 복귀 좌표를 쓴다.
	var origin: Vector2 = field_return_position if inside_castle else player.global_position
	var rift: Dictionary = world.spawn_rift_near(origin)
	if rift.is_empty():
		return false
	var rift_id := String(rift["id"])
	rift_states[rift_id] = {"activated":false, "remaining":0, "cleared":false}
	# ⚠️ Y7이 잡은 구멍: **사건은 균열을 피하지만 균열은 사건을 안 피한다.**
	# `_event_site_clear()`가 놓일 때 균열을 거르는데(§6.2 규약), 자리 예산이 서로
	# 독립이라 **나중에 열린 균열이 이미 선 사건 위에 앉을 수 있다.** 그러면 표식과
	# 정예 아레나가 한 화면에 포개져 둘 다 안 읽힌다.
	# `--rift-test event_budget`이 그 겹침을 재는데 좌표가 시간 시드라 **가끔만**
	# 빨개졌다(Y7이 `run_all` 1회차에서 실측 · 18회 중 1회). 여기서 밀어 준다.
	_displace_events_from_rift(rift)
	# X4: 위 `MILESTONE_BANNER["stage_rift_1"]`과 같은 정정 — 나침반 패널은 없다.
	_show_banner("균열이 열렸습니다 · 가장자리 화살표를 따라가 정예를 쓸어 각인을 얻으세요", GamePalette.MAGENTA, 3.4)
	play_sound("night", -3.0)
	_update_hud()
	return true

func _check_rifts() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world):
		return
	var near: Dictionary = world.get_nearest_rift(player.global_position, RIFT_APPROACH_RADIUS)
	if near.is_empty():
		return
	_activate_rift(String(near.get("id", "")))

func _activate_rift(rift_id: String) -> void:
	if rift_id.is_empty() or not is_instance_valid(world) or not is_instance_valid(player):
		return
	var rift: Dictionary = world.get_rift(rift_id)
	if rift.is_empty() or bool(rift.get("cleared", false)):
		return
	var progress: Dictionary = rift_states.get(rift_id, {"activated":false, "remaining":0, "cleared":false})
	if bool(progress.get("activated", false)) or bool(progress.get("cleared", false)):
		return
	# 정예 3~5기. 균열 순번으로 정하므로 결정적이다(첫 균열이 가장 순하다).
	var elite_count := clampi(RIFT_ELITE_MIN + int(rift.get("index", 0)), RIFT_ELITE_MIN, RIFT_ELITE_MAX)
	progress["activated"] = true
	progress["remaining"] = elite_count
	rift_states[rift_id] = progress
	var center: Vector2 = rift["position"]
	for index in elite_count:
		var angle := TAU * float(index) / float(elite_count)
		var distance := 96.0 + float(index % 2) * 40.0
		var spawn_position := center + Vector2.from_angle(angle) * distance
		if not world.is_walkable(spawn_position):
			spawn_position = world.find_walkable_near(center, rng, 60.0, 145.0)
		# 균열은 플레이어가 스스로 걸어 들어가는 도전 콘텐츠이고 정예는 behavior 4를
		# 강제하므로 낮 선공몹 게이트를 건너뛴다(allow_aggro_override=true).
		var elite := combat.spawn_enemy_instance(spawn_position, 4, "", false, rift_id, true, "", true)
		if not is_instance_valid(elite):
			continue
		# W12: W9의 사후 ×0.6 보정을 삭제했다. 정예 배율은 이제
		# `GameTuning.TRIAL_ELITE_HEALTH_MUL`(=3.0)이 단독으로 소유한다.
		elite.displayed_health = elite.health
		elite.trailing_health = elite.health
		elite.set_night_raid(true)
	_show_banner("균열 안 · 정예 %d마리를 전멸시키면 각인 상자가 열립니다" % elite_count, GamePalette.MAGENTA, 3.2)
	spawn_burst(center, GamePalette.MAGENTA, 30, 290.0, 0.8)
	play_sound("night", -3.0)

func _rift_enemy_defeated(rift_id: String) -> void:
	var progress: Dictionary = rift_states.get(rift_id, {})
	if progress.is_empty() or bool(progress.get("cleared", false)):
		return
	progress["remaining"] = maxi(0, int(progress.get("remaining", 0)) - 1)
	rift_states[rift_id] = progress
	if int(progress["remaining"]) > 0:
		if int(progress["remaining"]) <= 2 and is_instance_valid(player):
			show_world_text(player.global_position - Vector2(0.0, 70.0), "균열 정예 %d 남음" % int(progress["remaining"]), GamePalette.MAGENTA, 16)
		return
	progress["cleared"] = true
	rift_states[rift_id] = progress
	if is_instance_valid(world):
		world.set_rift_cleared(rift_id)
	_grant_rift_reward(rift_id)

## 균열 클리어 보상 — 각인 3택1 + 골드 + 체력 전회복 (설계 §5.5).
## 각인 3택1은 W6의 드래프트를 **그대로 재사용**한다(새 화면을 만들지 않는다).
func _grant_rift_reward(rift_id: String) -> void:
	gold += RIFT_REWARD_GOLD
	if is_instance_valid(player):
		player.heal_full()
		spawn_burst(player.global_position, GamePalette.MAGENTA, 46, 350.0, 1.0)
	play_sound("choice", 0.0)
	_update_hud()
	if state != "playing":
		# 성 안이나 모달 중이면 화면을 뺏지 않는다(골드·회복은 이미 지급됐다).
		_show_banner("균열 %s 정화 · +%d G · 체력 전회복" % [rift_id, RIFT_REWARD_GOLD], GamePalette.MAGENTA, 3.0)
		return
	_show_banner("균열 정화 · +%d G · 체력 전회복 · 각인 상자가 열립니다" % RIFT_REWARD_GOLD, GamePalette.MAGENTA, 3.2)
	_show_rune_draft("rift", "playing")

# =============================================================================
# 구 시련 캠프 3함수 — W9에서 철거 (설계 §5.5 · 부록 C-3)
# =============================================================================
# `_check_trial_camps()` / `_activate_trial_camp()`와 구슬(trophy) 보상 경로는
# world_grid의 시련 캠프 시스템(W12가 완전 삭제)과 함께 걷어냈다. 원본은
# `docs/v1-archive/game.gd.txt`에 남아 있다(부록 C-2 규약 · preload 대상 아님).
#
# `_trial_enemy_defeated()`는 **이름을 유지한다** — `combat_resolver.enemy_defeated()`가
# `camp_id`를 달고 죽은 적을 여기로 보낸다. 지금은 순수 디스패처이며 두 종류만 받는다:
#   "omen_<일차>" → 밤의 전조 (W4)
#   "rift_<n>"    → 균열 정예 (W9)
# `camp_states`(항상 빈 사전)와 `player.trophy_orbs`(항상 빈 배열)는 저장 스키마
# 호환을 위해 남겨 뒀다. 실제 제거는 W12 스키마 정리 때 함께 판단할 것.
func _trial_enemy_defeated(camp_id: String) -> void:
	if camp_id.begins_with(OMEN_CAMP_PREFIX):
		_omen_defeated(camp_id)
		return
	if camp_id.begins_with(EVENT_CAMP_PREFIX):
		# Y6: 필드 사건 소속. `evt_`가 `rift_`보다 먼저다 — 두 접두어는 안 겹치지만
		# 순서를 명시해 두면 나중에 접두어가 늘어도 분배가 흔들리지 않는다.
		_event_enemy_defeated(camp_id)
		return
	if camp_id.begins_with(RIFT_CAMP_PREFIX):
		_rift_enemy_defeated(camp_id)
		return

# === W3 위임 래퍼: player.gd가 부른다 ===
func perform_character_attack(attacker: Node2D) -> void:
	combat.perform_character_attack(attacker)

# === W3 위임 래퍼: 현재 호출부는 없지만 공개 API라 시그니처를 남긴다 ===
func process_orbit_blades(attacker: Node2D) -> void:
	combat.process_orbit_blades(attacker)

func on_factory_cycle_started(actor: Node2D, deck: FactoryDeck, is_boss_cycle: bool) -> void:
	if is_boss_cycle or not is_instance_valid(actor):
		return
	var effects := deck.global_effects()
	var heal_amount := float(effects.get("heal_cycle", 0.0))
	if heal_amount > 0.0 and actor.has_method("heal"):
		actor.heal(heal_amount)
	var shield_chance := clampf(float(effects.get("shield_cycle_chance", 0.0)), 0.0, 0.9)
	if rng.randf() < shield_chance and actor.has_method("grant_cycle_shield"):
		actor.grant_cycle_shield(1)

func on_cycle_card_started(actor: Node2D, card: Dictionary, is_boss_cycle: bool) -> void:
	# === V7 소유: 스테이지 보스 패턴은 여기서 telegraph → 착탄으로 실행된다 ===
	# 카드의 `kind`가 `boss_pattern`이라 v2의 보스 피해 경로(`_trigger_boss_cycle_pulse`)는
	# 아무 분기도 안 타고 no-op이 된다. 판정·상태·소환은 전부 아래 한 줄이 소유한다.
	if is_boss_cycle and String(card.get("kind", "")) == STAGE_BOSS_PATTERN_KIND:
		_launch_stage_boss_pattern(actor, card)
		return
	var shield_amount := int(card.get("shield", 0))
	if shield_amount <= 0:
		return
	if is_boss_cycle:
		if is_instance_valid(actor) and actor.get("shield") != null:
			actor.max_shield = maxf(actor.max_shield, actor.max_health * 0.18)
			actor.shield = minf(actor.max_shield, actor.shield + actor.max_health * 0.04 * shield_amount)
	elif actor.has_method("grant_cycle_shield"):
		actor.grant_cycle_shield(shield_amount)

# === W3 위임 래퍼: cycle_skill_effect.gd가 부른다 (시그니처 보존) ===
func apply_cycle_melee(actor: Node2D, card: Dictionary, hit_ids: Dictionary, is_boss_cycle: bool, facing: Vector2, damage_mul: float = 1.0) -> void:
	combat.apply_cycle_melee(actor, card, hit_ids, is_boss_cycle, facing, damage_mul)

# === W3 위임 래퍼: cycle_skill_effect.gd가 부른다 (시그니처 보존) ===
func trigger_cycle_card_pulse(actor: Node2D, card: Dictionary, is_boss_cycle: bool, pulse_index: int, action_origin: Vector2, damage_mul: float = 1.0) -> void:
	combat.trigger_cycle_card_pulse(actor, card, is_boss_cycle, pulse_index, action_origin, damage_mul)

# === W3 위임 래퍼: cycle_skill_effect.gd가 그리기 좌표로 쓴다 (시그니처 보존) ===
func cycle_pulse_center(actor: Node2D, card: Dictionary, pulse_index: int, action_origin: Vector2) -> Vector2:
	return combat.cycle_pulse_center(actor, card, pulse_index, action_origin)

# === W3 위임 래퍼: cycle_skill_effect.gd가 그리기 반지름으로 쓴다 (시그니처 보존) ===
func cycle_pulse_radius(card: Dictionary) -> float:
	return combat.cycle_pulse_radius(card)

# === W3 위임 래퍼 ===
func spawn_player_projectile(world_position: Vector2, direction: Vector2, damage: float, speed: float, homing: float, ricochets: int, pierces: int, color: Color, visual_kind: String = "arrow", travel_range: float = 0.0, card: Dictionary = {}) -> void:
	combat.spawn_player_projectile(world_position, direction, damage, speed, homing, ricochets, pierces, color, visual_kind, travel_range, card)

# === W3 위임 래퍼: enemy.gd가 부른다 (시그니처 보존) ===
func spawn_enemy_bullet(world_position: Vector2, direction: Vector2, homing: bool, damage: float, speed: float) -> void:
	combat.spawn_enemy_bullet(world_position, direction, homing, damage, speed)

func spawn_attack_effect(world_position: Vector2, kind: String, color: Color, direction: Vector2, size: float, duration: float = 0.18) -> void:
	if not is_instance_valid(gameplay_root) or active_effect_nodes >= GameTuning.MAX_TRANSIENT_EFFECTS:
		return
	var effect := ATTACK_EFFECT_SCRIPT.new()
	effect.setup(kind, color, direction, size, duration)
	effect.position = world_position
	effect.tree_exiting.connect(_on_transient_effect_exiting)
	active_effect_nodes += 1
	gameplay_root.add_child(effect)

# === W3 위임 래퍼: enemy.gd `_ready`가 부른다 (시그니처 보존) ===
func register_enemy(enemy: Node) -> void:
	combat.register_enemy(enemy)
	# Y7: 「밤눈 부적」이 켜진 밤에 태어난 개체도 같은 감지 반경을 갖는다.
	# 스폰 경로가 여기 하나로 모이므로 **새 훅을 만들지 않고** 여기서 심는다.
	if night_eye_active and enemy.has_method("set_night_sight_scale"):
		enemy.set_night_sight_scale(NIGHT_EYE_SCALE)

# === W3 위임 래퍼: enemy.gd `_exit_tree`가 부른다 (시그니처 보존) ===
func unregister_enemy(enemy: Node) -> void:
	combat.unregister_enemy(enemy)

# === W3 위임 래퍼: skill_effect_controller.gd가 부른다 (시그니처 보존) ===
func query_enemies(center: Vector2, radius: float) -> Array[Node]:
	return combat.query_enemies(center, radius)

# === W3 위임 래퍼: projectile.gd가 부른다 (시그니처 보존) ===
func find_nearest_enemy(origin: Vector2, excluded: Dictionary = {}, maximum_distance: float = INF) -> Node2D:
	return combat.find_nearest_enemy(origin, excluded, maximum_distance)

# === W3 위임 래퍼: enemy.gd `provoke`가 부른다 (시그니처 보존) ===
func alert_same_species(species: String, origin: Vector2) -> void:
	combat.alert_same_species(species, origin)

# =============================================================================
# V6: L1(덱 레벨) → L2(대상 레벨)를 잇는 유일한 통로 (설계 §4.1 · §4.5)
# =============================================================================
# `RuneEngine.simulate_cycle()`이 스텝마다 만드는 `step_record["potency"]`(인화 ×1.5 ·
# 역병 발화 준비 ×1.3)와 `["stun_bonus"]`(쇄빙 준비 +0.2초)를 실행 중인 스텝에서 읽는다.
# **L1은 직접 피해를 주지 않고 이 두 채널로만 L2에 개입한다** — 그래서
# `_cycle_damage_value()`가 사이클 피해의 유일한 계산 지점이라는 v2 계약이 안 깨진다.
#
# 왜 컨트롤러가 밀어 주지 않고 여기서 되읽는가: `deal_cycle_controller.gd`는 V6 소유가
# 아니다(부록 B). 궤적을 소유한 쪽에서 값을 꺼내 오는 편이 파일 경계를 넘지 않는다.
# 상태를 부여하는 경로는 **플레이어 사이클 하나뿐**이다 — 보스·전조 사이클은
# `is_boss_cycle=true`라 `strike_enemy_with_card()`에 아예 도달하지 않는다.
func current_cycle_step() -> Dictionary:
	if not is_instance_valid(player_cycle):
		return {}
	var steps: Array = player_cycle.plan_steps
	if steps.is_empty():
		return {}
	return steps[clampi(player_cycle.step_pointer, 0, steps.size() - 1)] as Dictionary

func current_cycle_potency() -> float:
	return maxf(0.0, float(current_cycle_step().get("potency", 1.0)))

func current_cycle_stun_bonus() -> float:
	return maxf(0.0, float(current_cycle_step().get("stun_bonus", 0.0)))

# =============================================================================
# V6: 시너지 1회성 강조 (설계 §4.8 · 에셋은 ASSET_MAP §13-2)
# =============================================================================
# 시트는 768×480 · 셀 96×96 · 8열 × 5행이고 **행 순서가 곧 반응 키**다:
#   0 대폭 연소 / 1 전도 / 2 역병 발화 / 3 쇄빙 / 4 정신 붕괴.
# 나머지 시너지 3종(증기·감전 유막·터뜨리기)은 전용 행이 없다 — 부유 라벨만 뜬다.
#
# **트윈을 쓰지 않는다.** 노드가 자기 `elapsed`로 8프레임을 한 번 훑고 스스로
# `queue_free()` 한다(§4.8 "1회성 정적 강조", burst_effect.gd와 같은 규약).
# 기존 이펙트 예산(`MAX_TRANSIENT_EFFECTS`)을 그대로 나눠 쓴다.
const SYNERGY_SHEET := preload("res://art/v2/vfx-synergy.png")
const SYNERGY_CELL := 96.0
const SYNERGY_ROWS: Dictionary = {
	StatusEngine.R_BLAZE: 0,
	StatusEngine.R_CONDUCTION: 1,
	StatusEngine.R_PLAGUE_IGNITION: 2,
	StatusEngine.R_SHATTER: 3,
	StatusEngine.R_PSI_COLLAPSE: 4
}
# 부유 라벨 색. 전용 행이 없는 3종까지 포함해 반응마다 색을 갖는다.
const SYNERGY_LABEL_COLORS: Dictionary = {
	StatusEngine.R_BLAZE: Color("ff852a"),
	StatusEngine.R_CONDUCTION: Color("94dbff"),
	StatusEngine.R_PLAGUE_IGNITION: Color("85f252"),
	StatusEngine.R_SHATTER: Color("b8edff"),
	StatusEngine.R_PSI_COLLAPSE: Color("c799ff"),
	StatusEngine.R_STEAM: Color("e0e6ef"),
	StatusEngine.R_OILED_SHOCK: Color("f4d35e"),
	StatusEngine.R_GREASED_FLAME: Color("e78a45"),
	StatusEngine.R_DETONATE: Color("83c65c"),
	StatusEngine.R_QUENCH: Color("9fd6dd"),
	StatusEngine.R_FROZEN_VENOM: Color("67c7d4")
}

class SynergyBurst:
	extends Node2D

	var sheet: Texture2D
	var row := 0
	var cell := 96.0
	var glow := Color.WHITE
	var lifetime := 0.34
	var elapsed := 0.0

	func setup(texture: Texture2D, sheet_row: int, cell_size: float, tint: Color) -> void:
		sheet = texture
		row = sheet_row
		cell = cell_size
		glow = tint

	func _ready() -> void:
		z_index = 9
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		queue_redraw()

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= lifetime:
			queue_free()

	func _draw() -> void:
		if sheet == null:
			return
		var progress := clampf(elapsed / lifetime, 0.0, 1.0)
		var frame := clampi(floori(progress * 8.0), 0, 7)
		var source := Rect2(float(frame) * cell, float(row) * cell, cell, cell)
		var box := Vector2.ONE * cell
		draw_texture_rect_region(sheet, Rect2(-box * 0.5, box), source,
			Color(glow, clampf(1.0 - progress * 0.35, 0.0, 1.0)))

## 반응 키의 부유 라벨 색. 모르는 키는 흰색으로 떨어뜨린다.
func synergy_label_color(reaction: String) -> Color:
	return SYNERGY_LABEL_COLORS.get(reaction, GamePalette.TEXT)

## 시너지 버스트 1회. 전용 행이 없는 반응은 아무것도 만들지 않는다(라벨만 뜬다).
##
## V8: **결과 화면의 시너지 발동 횟수를 여기서 센다.** `combat_resolver`(수정 금지)의
## `_announce_reactions()`와 `_run_status_chain()`이 game.gd로 나오는 유일한 관문이라,
## 이름 붙은 반응(대폭 연소·전도·쇄빙 …)은 전부 이 줄을 지나간다. 이펙트 예산이 꽉
## 차서 노드를 못 만드는 순간에도 **세기는 센다** — 지표는 연출이 아니라 사건이다.
func spawn_synergy_effect(world_position: Vector2, reaction: String) -> void:
	run_synergy_triggers += 1
	if not is_instance_valid(gameplay_root) or active_effect_nodes >= GameTuning.MAX_TRANSIENT_EFFECTS:
		return
	if not SYNERGY_ROWS.has(reaction):
		return
	var burst := SynergyBurst.new()
	burst.setup(SYNERGY_SHEET, int(SYNERGY_ROWS[reaction]), SYNERGY_CELL, synergy_label_color(reaction))
	burst.position = world_position
	burst.tree_exiting.connect(_on_transient_effect_exiting)
	active_effect_nodes += 1
	gameplay_root.add_child(burst)

func collect_xp(value: int) -> void:
	if state not in ["playing", "boss"]:
		return
	var factory_xp := 0.0 if factory == null else float(factory.global_effects().get("xp_all", 0.0))
	var adjusted_xp := float(value) * player.xp_multiplier * maxf(0.1, 1.0 + factory_xp) + xp_fraction
	var gained_xp := floori(adjusted_xp)
	xp_fraction = adjusted_xp - float(gained_xp)
	experience += gained_xp
	collect_sound_counter += 1
	if collect_sound_counter % 3 == 0:
		play_sound("collect", -10.0)
	_update_hud()
	if state == "playing" and experience >= xp_target:
		call_deferred("_show_skill_choice", "level")

# === W3 위임 래퍼: enemy.gd `_die`가 부른다 (시그니처 보존) ===
func enemy_defeated(enemy: Node) -> void:
	combat.enemy_defeated(enemy)

# === W3 위임 래퍼: enemy.gd가 call_deferred로 부른다 (이름·시그니처 보존) ===
func spawn_split_enemies(origin: Vector2, count: int) -> void:
	combat.spawn_split_enemies(origin, count)

# === W3 위임 래퍼: enemy.gd가 부른다 (시그니처 보존) ===
func spawn_boss_minions(origin: Vector2, count: int) -> void:
	combat.spawn_boss_minions(origin, count)

func get_player_speed_multiplier(point: Vector2) -> float:
	if inside_castle:
		return 1.0
	var item_speed := 0.0 if factory == null else float(factory.global_effects().get("move_speed", 0.0))
	# V7: 한(chill)이 플레이어에게도 걸린다(§3.3 A "얼리고 감전시킨다"). `player.gd`는
	# 이 함수 하나만 묻고 있으므로 플레이어 파일을 건드리지 않고 감속이 들어간다.
	var status_speed := StatusEngine.move_multiplier(player_status)
	for enemy: Node in combat.query_enemies(point, 250.0):
		if is_instance_valid(enemy) and enemy.has_method("slows_player") and enemy.slows_player(point):
			return (0.6 if enemy.is_boss else 0.74) * maxf(0.5, 1.0 + item_speed) * status_speed
	return maxf(0.5, 1.0 + item_speed) * status_speed

# =============================================================================
# V8: 성장 천장 — 1안 "배치할 곳이 없는 레벨업은 각인 드래프트로" (설계 §10 #4 · 부록 A-3 ②)
# =============================================================================
# v3는 v2보다 런이 3배 길다(5스테이지). 5칸 · R3 상한 · 장비 4부위는 그대로라
# 3스테이지쯤이면 **카드로는 더 강해질 수 없는** 상태가 온다. 그때부터 레벨업 2택1은
# "R3 카드를 밀어내고 R1을 넣으시겠습니까"라는 손해 선택지만 남는다.
#
# 설계가 고른 1안은 `MAX_RANK`를 건드리지 않는다(2안은 R4 개방인데 `data_test`의 포화
# 단언과 융합 경제를 함께 손봐야 한다). V8은 잉여 레벨업을 각인 드래프트로 돌렸다.
#
# ⚠️ **X1이 그 출구를 바꿨다.** 레벨업→각인 경로가 사용자 요구 ④로 사라졌으므로
#    천장에 닿은 레벨업은 이제 "취소(골드)가 기본 제안"인 화면으로 열린다
#    (`_show_skill_choice()`의 `at_growth_cap`). **판정 함수 자체는 무수정**이다 —
#    무엇이 천장인가는 안 바뀌었고 그 뒤에 무엇을 주는가만 바뀌었다.
#
# "배치할 곳이 없다"의 정의 — 아래 셋이 **전부** 참일 때다:
#   ① 레일 5칸이 전부 스킬 카드로 차 있다(빈칸 = 기본 베기가 하나도 없다)
#   ② 그 다섯 장이 전부 R3(`DealCardLibrary.MAX_RANK`) 포화다
#   ③ 보관함의 스킬 카드도 전부 R3다 — 즉 새 R1이 융합으로 합쳐질 상대가 없다
# 셋이 다 참이면 새 카드가 갈 수 있는 자리는 "R3를 버리고 그 칸"뿐이다. 그게 천장이다.
# ③을 뺄 수 없는 이유: 보관함에 R1이 한 장이라도 있으면 새 R1과 합쳐 R2 → R3 경로가
# 살아 있어 카드가 여전히 성장 수단이다. 그때 자동 전환하면 플레이어의 선택을 뺏는다.
#
# 아이템 카드는 세지 않는다 — 아이템은 레일 칸을 점유하지 않고 장비 4부위로 간다(§5.4).
func _growth_cap_reached() -> bool:
	if factory == null:
		return false
	for slot_index in factory.slots.size():
		var card: Dictionary = factory.get_card(slot_index)
		if card.is_empty() or String(card.get("kind", "skill")) == "item":
			return false
		if int(card.get("rank", 1)) < DealCardLibrary.MAX_RANK:
			return false
	for stored: Dictionary in factory.inventory:
		if String(stored.get("kind", "skill")) == "item":
			continue
		if int(stored.get("rank", 1)) < DealCardLibrary.MAX_RANK:
			return false
	return true

# =============================================================================
# X1 — 레벨업 모달 대개편 (2026-08-09 사용자 피드백 ③④ · 최우선)
# =============================================================================
# 사용자 원문 ③: "텍스트가 너무 많아. 모달 이름은 '레벨 업'으로 간단하게. 가장
# 부각되어야 할 건 스킬의 이미지 — 사람들은 스킬의 이름과 이미지로 스킬을 판별해.
# '3회 타격' 같은 태그는 모두 지우고 … '한 바퀴 빚'·'피해계수'도 지워 … 속성은
# 텍스트가 아니라 스킬 배경색 또는 블록색 통일로."
# 사용자 원문 ④: "레벨업 2택에서 각인 강화를 제거해. 대신 취소 — 취소하면 스킬
# 획득을 취소하고 골드를 일정량 얻고, 마왕에게도 이득이 안 가게."
#
# ── 지운 것 (U2판 대비) ──────────────────────────────────────────────────────
#   부제 밴드 "이번 레벨의 스킬 카드를 고르세요"      → 리본 제목이 이미 말한다
#   규칙 밴드 "지속시간 = … · RELOAD = …"             → 온보딩·툴팁 몫(X4)
#   태그 줄   "화(火) · 참격 · 근접 검격 · 3회 타격 …" → 색 + 설명 문장이 대신한다
#   "피해계수 x.xx · 범위 nnn"                         → 삭제(수치는 편집 화면에서)
#   "한 바퀴 빚 n.nn초 → +n.nn초"                      → 삭제(RELOAD 칩이 이미 시각화)
#   세 번째 카드 「각인 강화 · 각인 3택 1」            → 각인 세공사로 이전(④)
#   푸터 "↓ 각인 강화 · ↑ 스킬 카드로 복귀"            → 취소 한 줄로 축약
# 카드 한 장의 정보 항목이 **9개 → 6개**(이미지·이름·설명·지속·RELOAD·보유수)로 줄고,
# 그중 이미지가 면적의 절반을 가진다.
#
# ── 단일 포커스 모델은 그대로다 ────────────────────────────────────────────
# 취소 버튼의 `choice_role`이 U2의 각인 강화 카드와 **같은 "cancel"**이라 ↓/↑
# 키 경로(`_choice_extra_index()`)가 한 줄도 바뀌지 않았다. 다만 취소는 카드가
# 아니라 **버튼**이다 — 시각적 위계를 카드보다 낮추라는 요구가 곧 "카드 프레임을
# 주지 말라"는 뜻이기 때문이다(NEUTRAL 버튼 = ui-style-v3 §6의 최하위 어포던스).
const CHOICE_CARD_HERO_SIZE := Vector2(520.0, 356.0)
const CHOICE_CARD_HERO_Y := 30.0
const CHOICE_CANCEL_RECT := Rect2(415.0, 398.0, 360.0, 52.0)

func _show_skill_choice(source: String = "level") -> void:
	if state != "playing":
		return
	choice_source = source
	state = "choice"
	get_tree().paused = true
	current_pair = DealCardLibrary.random_two(rng)
	_reset_choice_focus()
	_clear_overlay()
	# === X1: 성장 천장 (V8 자동 전환의 후신 · 부록 A-3 ②) ======================
	# 각인 드래프트로 **전환하지 않는다**(그 경로 자체가 ④로 사라졌다). 대신 천장에
	# 닿은 레벨업은 "취소가 기본 제안"인 화면으로 연다 — 포커스가 취소에서 시작하고
	# 취소 보상이 할증된다. 카드를 고르는 자유는 뺏지 않는다(고르면 R3를 갈아끼운다).
	# 보물상자(`chest`)·테스트 진입은 천장을 보지 않는다 — 천장은 레벨업의 문제다.
	var at_growth_cap := source == "level" and _growth_cap_reached()
	if at_growth_cap:
		growth_cap_conversions += 1
	overlay = Control.new()
	overlay.name = "SkillChoice"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 필드 위에 뜨는 모달 = SLATE 껍데기 + WOOD 리본(ui-style-v3 §7-1 · §7-2).
	# 제목은 두 글자다. 부제 밴드가 사라졌으므로 리본이 유일한 제목이다.
	var panel := _kit_shell(overlay, CHOICE_MODAL_RECT,
		"봉인 해제" if source == "chest" else "레벨 업",
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 360.0)
	var left := _deal_choice_button(current_pair[0], CHOICE_CARD_HERO_SIZE)
	left.position = Vector2(50.0, CHOICE_CARD_HERO_Y)
	panel.add_child(left)
	_register_choice_button(left, "skill", _choose_skill.bind(current_pair[0], current_pair[1]))
	var right := _deal_choice_button(current_pair[1], CHOICE_CARD_HERO_SIZE)
	right.position = Vector2(620.0, CHOICE_CARD_HERO_Y)
	panel.add_child(right)
	_register_choice_button(right, "skill", _choose_skill.bind(current_pair[1], current_pair[0]))
	# 취소 = 카드보다 낮은 위계. NEUTRAL(SLATE) 버튼 한 개 · 카드 폭의 70%.
	var reward := _choice_cancel_gold(at_growth_cap)
	var cancel_button := _button("취소   ·   + %d G" % reward, GamePalette.MUTED, CHOICE_CANCEL_RECT.size)
	cancel_button.position = CHOICE_CANCEL_RECT.position
	cancel_button.set_meta("choice_kind", "cancel")
	cancel_button.set_meta("cancel_gold", reward)
	panel.add_child(cancel_button)
	_register_choice_button(cancel_button, "cancel", _cancel_skill_choice)
	var footer := "← 왼쪽   ·   → 오른쪽   ·   ↓ 취소   ·   SPACE 결정   ·   취소하면 두 카드 모두 사라지고 마왕도 얻지 못합니다"
	if at_growth_cap:
		footer = "레일 5칸이 전부 R%d입니다 — 새 카드는 R%d 한 장을 밀어냅니다.  그냥 넘기는 편이 낫습니다" % [
			DealCardLibrary.MAX_RANK, DealCardLibrary.MAX_RANK]
	_kit_label(panel, Rect2(0.0, 458.0, CHOICE_MODAL_RECT.size.x, 22.0), footer,
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 18.0))
	# 천장이면 취소에 포커스를 두고 연다(`GROWTH_CAP_DEFAULT_CANCEL`).
	if at_growth_cap and GameTuning.GROWTH_CAP_DEFAULT_CANCEL:
		_set_choice_index(_choice_extra_index())
	else:
		_set_choice_index(0)
	play_sound("choice", -2.0)

## 취소 보상. 상점가 스테이지 스케일을 그대로 타므로 **구매력이 런 내내 일정**하다
## (1스테이지 30 G = 5스테이지 72 G = 언제나 상점 카드 0.91장 값).
## 천장에서는 `GROWTH_CAP_CANCEL_BONUS`만큼 할증된다 — 고를 게 없는 레벨업이
## 카드 한 장 값은 하게 만드는 보정이다.
func _choice_cancel_gold(at_growth_cap: bool = false) -> int:
	var base := float(GameTuning.CHOICE_CANCEL_GOLD)
	if at_growth_cap:
		base *= GameTuning.GROWTH_CAP_CANCEL_BONUS
	return _scaled_price(int(round(base)))

# 2지선다 계열 화면(choice / advancement_choice / item_choice)의 단일 포커스 모델.
# 포커스 상태는 choice_selected_index 하나뿐이며 키보드·마우스·자동 테스트가 모두 이 경로만 사용합니다.
# Godot 내장 Control 포커스 이동(ui_left/ui_right/ui_accept)이 두 번째 선택자로 끼어들지 않도록
# 등록된 버튼은 focus_mode를 FOCUS_NONE으로 강제합니다.
func _reset_choice_focus() -> void:
	choice_buttons.clear()
	choice_selected_index = 0
	choice_last_card_index = 0
	# 직전 화면의 Control이 키 포커스를 들고 있으면 Godot 내장 포커스 이동이
	# 두 번째 선택자로 되살아나므로 2지선다에 들어가기 전에 반드시 풀어줍니다.
	if is_instance_valid(ui_root):
		var viewport := ui_root.get_viewport()
		if is_instance_valid(viewport):
			var focus_owner := viewport.gui_get_focus_owner()
			if is_instance_valid(focus_owner):
				focus_owner.release_focus()

func _register_choice_button(button: Button, role: String, confirm: Callable) -> void:
	if not is_instance_valid(button):
		return
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("choice_role", role)
	button.set_meta("choice_confirm", confirm)
	var index := choice_buttons.size()
	button.mouse_entered.connect(_set_choice_index.bind(index))
	button.pressed.connect(_confirm_choice_index.bind(index))
	choice_buttons.append(button)

func _choice_extra_index() -> int:
	for index in choice_buttons.size():
		if is_instance_valid(choice_buttons[index]) and String(choice_buttons[index].get_meta("choice_role", "")) == "cancel":
			return index
	return choice_selected_index

func _handle_choice_keyboard(key_event: InputEventKey) -> void:
	if choice_buttons.is_empty():
		return
	if key_event.keycode in [KEY_LEFT, KEY_A]:
		_set_choice_index(0)
	elif key_event.keycode in [KEY_RIGHT, KEY_D]:
		_set_choice_index(1)
	elif key_event.keycode in [KEY_UP, KEY_W]:
		_set_choice_index(choice_last_card_index)
	elif key_event.keycode in [KEY_DOWN, KEY_S]:
		_set_choice_index(_choice_extra_index())
	elif key_event.keycode in [KEY_SPACE, KEY_ENTER]:
		_confirm_choice_index(choice_selected_index)

func _set_choice_index(index: int) -> void:
	if choice_buttons.is_empty():
		return
	var target := clampi(index, 0, choice_buttons.size() - 1)
	var button := choice_buttons[target]
	if not is_instance_valid(button) or button.disabled:
		return
	choice_selected_index = target
	if String(button.get_meta("choice_role", "")) != "cancel":
		choice_last_card_index = target
	_refresh_choice_highlight()

## U2 v3: 포커스 표시가 "흰 2px 테두리"에서 **킷 카드 상태**로 바뀌었다.
## 카드 = 흰 이중 립(SELECTED) / 버튼 = 융기 hover 베벨. 단일 포커스 모델(FOCUS_NONE +
## `choice_selected_index` 하나)과 `_choice_highlight_count() == 1` 계약은 그대로다 —
## 강조된 버튼만 `modulate == WHITE`다.
func _refresh_choice_highlight() -> void:
	for button_index in choice_buttons.size():
		var button := choice_buttons[button_index]
		if not is_instance_valid(button):
			continue
		var focused := button_index == choice_selected_index
		button.modulate = Color.WHITE if focused else Color(0.76, 0.78, 0.84, 0.94)
		if button.has_meta("kit_card_kind"):
			var kind := int(button.get_meta("kit_card_kind"))
			var state := 2 if button.disabled else (1 if focused else 0)
			# X1: 원소 틴트가 걸린 카드는 **틴트를 유지한 채** 상태만 바꾼다.
			# 여기서 무채 원본을 다시 씌우면 포커스를 옮기는 순간 속성색이 날아간다.
			if button.has_meta("kit_card_tint"):
				var tint: Variant = button.get_meta("kit_card_tint")
				var tint_color: Color = tint if tint is Color else Color.WHITE
				var tinted := _kit_card_box_tinted(kind, state, tint_color)
				button.add_theme_stylebox_override("normal", tinted)
				button.add_theme_stylebox_override("hover",
					tinted if button.disabled else _kit_card_box_tinted(kind, 1, tint_color))
				button.add_theme_stylebox_override("pressed", _kit_card_box_tinted(kind, 1, tint_color))
				continue
			var box := _kit_card_box(kind, state)
			button.add_theme_stylebox_override("normal", box)
			button.add_theme_stylebox_override("hover", box if button.disabled else _kit_card_box(kind, 1))
			button.add_theme_stylebox_override("pressed", _kit_card_box(kind, 1))
			continue
		var variant := int(button.get_meta("kit_btn_variant")) if button.has_meta("kit_btn_variant") else 0
		button.add_theme_stylebox_override("normal", _kit_button_box(variant, 1 if focused else 0))

func _choice_highlight_count() -> int:
	var count := 0
	for button: Button in choice_buttons:
		if is_instance_valid(button) and button.modulate.is_equal_approx(Color.WHITE):
			count += 1
	return count

func _confirm_choice_index(index: int) -> void:
	if choice_buttons.is_empty():
		return
	var target := clampi(index, 0, choice_buttons.size() - 1)
	var button := choice_buttons[target]
	if not is_instance_valid(button) or button.disabled:
		return
	choice_selected_index = target
	_refresh_choice_highlight()
	var confirm = button.get_meta("choice_confirm", Callable())
	if confirm is Callable and (confirm as Callable).is_valid():
		(confirm as Callable).call()

func _choose_skill(selected: Dictionary, rejected: Dictionary) -> void:
	if state != "choice":
		return
	selected_skills.append(selected["id"])
	rejected_skills.append(rejected["id"])
	if choice_source == "level":
		experience = maxi(0, experience - xp_target)
		level += 1
		xp_target = 7 + level * 5
	pending_boss_toast_cards = [rejected.duplicate(true)]
	_clear_overlay()
	_show_factory_menu("place", DealCardLibrary.instance(String(selected["id"]), 1), "playing")
	play_sound("choice", -2.0)

# v1: "레일 부품 건설" → W2: "카드 포기 + 45 G" → W6: "각인 드래프트" → **X1: 취소**.
#
# ⚠️ **`_choose_rune_draft()`는 X1에서 삭제됐다.** 레벨업에서 각인으로 가는 문이
#    사용자 요구 ④로 닫혔기 때문이다(각인은 각인 세공사·보물상자·균열·전조에서만).
#    `_convert_level_choice_to_rune_draft()`(성장 천장 자동 전환)도 같은 이유로 함께
#    사라졌다 — 원본은 `docs/handoff-x1.md`에 인용해 뒀다.
#
# 취소의 계약 3줄 (사용자 요구 ④를 그대로 옮긴 것):
#   ① 두 카드 모두 **소멸**한다. `rejected_skills`에도 `trophy_reject_skills`에도
#      들어가지 않고 `pending_boss_toast_cards`도 비운다 — 마왕 전달 경로를
#      **한 줄도 지나지 않는다.** `demon_lord.growth_points()`가 그대로다.
#   ② 골드를 준다(`_choice_cancel_gold()`). 스테이지 가격 스케일을 탄다.
#   ③ 레벨은 **정상적으로 오른다.** 취소는 "레벨업을 미루기"가 아니라 "이번 보상을
#      골드로 받기"다. 미루기로 만들면 경험치가 넘친 채 모달이 무한히 다시 뜬다.
func _cancel_skill_choice() -> void:
	if state != "choice" or current_pair.size() != 2:
		return
	var at_growth_cap := choice_source == "level" and _growth_cap_reached()
	var reward := _choice_cancel_gold(at_growth_cap)
	gold += reward
	if choice_source == "level":
		experience = maxi(0, experience - xp_target)
		level += 1
		xp_target = 7 + level * 5
	# 두 카드는 여기서 끝난다. 마왕 토스트 큐도 비워 둔다(전달할 것이 없다).
	current_pair.clear()
	pending_boss_toast_cards.clear()
	choice_buttons.clear()
	_clear_overlay()
	get_tree().paused = false
	state = "playing"
	_grant_modal_return_invulnerability()
	_update_hud()
	_show_banner("스킬 안 받기 · +%d G   ·   두 카드는 사라졌습니다 (마왕도 얻지 못합니다)" % reward,
		GamePalette.YELLOW, 2.8)
	play_sound("choice", -4.0)
	# 연속 레벨업 — 경험치가 아직 문턱을 넘고 있으면 다음 레벨업을 바로 잇는다
	# (`_finish_rune_draft()`와 완전히 같은 규약).
	if experience >= xp_target:
		call_deferred("_show_skill_choice", "level")

# =============================================================================
# W6: 각인 드래프트 (설계 §8.3 · §5.1 · 부록 C-1)
# =============================================================================
# 2단계다. ①각인 3택1(희귀도 가중) → ②"강화할 칸을 고르세요"(5칸 미니 레일).
# 미선택 각인은 사라지지 않고 **마왕의 각인 재료**가 된다(§5.1 "2개당 1").
#
# 드래프트 풀 규칙 (W2 밸런스 신호 §8.1 반영):
#   * 희귀도 가중 common 62 / rare 30 / epic 8. 날이 갈수록 rare·epic이 조금씩 오른다.
#   * **흐름 각인 억제** — 한 칸에 흐름 계열이 RUNE_DRAFT_FLOW_SATURATION개 이상 쌓이면
#     그 칸 하나당 흐름 계열 전체 가중이 ×RUNE_DRAFT_FLOW_SUPPRESS 된다(하한 FLOOR).
#     완전히 배제하지는 않는다 — 되감기 엔진 아키타입(§3.10)이 성립 불가가 되면 안 된다.
#   * 제시된 흐름 각인에는 「흐름 각인이 몰린 칸이 있습니다」 배지가 붙는다.
#   * 2단계에서 스택 상한(총 5 / 같은 id 3) 도달 칸은 **선택 불가**로 표시된다.
const RUNE_DRAFT_OPTIONS := 3
const RUNE_DRAFT_RARITY_WEIGHT: Dictionary = {"common": 62.0, "rare": 30.0, "epic": 8.0}
const RUNE_DRAFT_DAY_RARE := 2.0
const RUNE_DRAFT_DAY_EPIC := 1.2
const RUNE_DRAFT_FLOW_SATURATION := 2
const RUNE_DRAFT_FLOW_SUPPRESS := 0.45
const RUNE_DRAFT_FLOW_FLOOR := 0.12
const RUNE_DRAFT_PANEL_RECT := Rect2(40.0, 44.0, 1200.0, 632.0)
const RUNE_DRAFT_CARD_SIZE := Vector2(360.0, 292.0)
# Y3: `RUNE_TARGET_SLOT_SIZE(196×300)`은 폐기됐다(§8 ②). 2단계 칸은 편집 화면과
# 같은 `EDIT_SLOT_SIZE(196×204)`를 쓴다 — 상수와 근거는 아래 2단계 블록에 있다.

const RUNE_FAMILY_NAME: Dictionary = {
	"flow": "흐름 · 바늘을 움직인다",
	"parallel": "동시 · 칸을 묶는다",
	"conditional": "조건 · 상황을 보고 세진다",
	"tempo": "속도 · 시간을 만진다",
	"combat": "전투 · 이 칸을 강화한다"
}
const RUNE_RARITY_NAME: Dictionary = {"common": "일반", "rare": "희귀", "epic": "영웅"}

func _rune_family_of(rune_id: String) -> String:
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	return String(definition.get("family", ""))

## 흐름 각인이 이미 몰려 있는 칸의 수. 드래프트 억제의 유일한 입력이다.
func _rune_draft_saturated_slots() -> int:
	if factory == null:
		return 0
	var saturated := 0
	for slot_index in factory.slots.size():
		var flow := 0
		for rune_value in factory.runes_on(slot_index):
			if _rune_family_of(String((rune_value as Dictionary).get("id", ""))) == "flow":
				flow += 1
		if flow >= RUNE_DRAFT_FLOW_SATURATION:
			saturated += 1
	return saturated

func _rune_draft_flow_scale() -> float:
	var saturated := _rune_draft_saturated_slots()
	if saturated <= 0:
		return 1.0
	return maxf(RUNE_DRAFT_FLOW_FLOOR, pow(RUNE_DRAFT_FLOW_SUPPRESS, float(saturated)))

func _rune_draft_weight(rune_id: String, flow_scale: float, day: int) -> float:
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	if definition.is_empty():
		return 0.0
	var rarity := String(definition.get("rarity", RuneEngine.RARITY_COMMON))
	var weight := float(RUNE_DRAFT_RARITY_WEIGHT.get(rarity, 1.0))
	var elapsed := float(maxi(0, day - 1))
	if rarity == RuneEngine.RARITY_RARE:
		weight += RUNE_DRAFT_DAY_RARE * elapsed
	elif rarity == RuneEngine.RARITY_EPIC:
		weight += RUNE_DRAFT_DAY_EPIC * elapsed
	if String(definition.get("family", "")) == "flow":
		weight *= flow_scale
	return maxf(0.0, weight)

## 레일 각인 id가 지금 레일에 붙을 수 있는가. 칸 각인이면 항상 true(여기 대상이 아니다).
## `RAIL_RUNE_CAP = 3` · `RAIL_SAME_ID_CAP = 1`이 계약이다(rune_engine §2.2).
func _rail_rune_attachable(rune_id: String) -> bool:
	if RuneEngine.rune_scope(rune_id) != "rail":
		return true
	if factory == null:
		return false
	if factory.rail_rune_count() >= RuneEngine.RAIL_RUNE_CAP:
		return false
	return not factory.rail_rune_ids().has(rune_id)

## 레일 각인은 **칸을 고르지 않는다**(§2.2). 고른 순간 레일에 붙고 드래프트가 끝난다.
## 2단계("강화할 칸을 고르세요")로 보내면 5칸 전부가 거부하는 죽은 화면이 된다.
## 붙었으면 true. 상한에 걸려 못 붙였으면 false(호출부가 알리고 골드로 환산한다).
func _apply_rail_rune(instance: Dictionary) -> bool:
	if factory == null:
		return false
	return factory.attach_rail_rune(instance.duplicate(true))

## 3택 생성. 인스턴스는 반드시 roll_rune으로 만든다 — 같은 각인이라도 확률이 다른
## 물건이라는 감각이 §3.3의 핵심이다(handoff-w1 §8).
## `rarity_filter`(W9 신설, 선택 인자)를 주면 그 희귀도만 후보에 남긴다.
## 계약 NPC의 "미래를 담보로"(영웅 각인 1개 확정)가 쓰는 유일한 경로다.
func _roll_rune_draft(count: int = RUNE_DRAFT_OPTIONS, rarity_filter: String = "") -> Array[Dictionary]:
	var flow_scale := _rune_draft_flow_scale()
	var day := day_number
	var pool: Array[String] = []
	var weights: Array[float] = []
	for rune_id in RuneEngine.all_rune_ids():
		if not rarity_filter.is_empty():
			var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
			if String(definition.get("rarity", RuneEngine.RARITY_COMMON)) != rarity_filter:
				continue
		# ★ Y2 수리 ③: 붙일 수 없는 레일 각인은 후보에서 뺀다. 레일이 꽉 찼거나
		#    같은 레일 각인을 이미 갖고 있으면(`RAIL_SAME_ID_CAP = 1`) 고르는 순간
		#    거부돼 **죽은 선택지**가 된다(handoff-y1 §9-A `game.gd:7303`).
		#    칸 각인은 여기서 거르지 않는다 — 2단계 화면이 칸별로 이미 막고 있고,
		#    전부 막혔을 때의 출구(`_forfeit_rune_draft`)도 따로 있다.
		if not _rail_rune_attachable(rune_id):
			continue
		var weight := _rune_draft_weight(rune_id, flow_scale, day)
		if weight <= 0.0:
			continue
		pool.append(rune_id)
		weights.append(weight)
	var offers: Array[Dictionary] = []
	for _pick in count:
		if pool.is_empty():
			break
		var total := 0.0
		for weight in weights:
			total += weight
		var roll := rng.randf() * total
		var chosen := pool.size() - 1
		for index in pool.size():
			roll -= weights[index]
			if roll <= 0.0:
				chosen = index
				break
		var rune_id := pool[chosen]
		pool.remove_at(chosen)
		weights.remove_at(chosen)
		offers.append({
			"instance": RuneEngine.roll_rune(rune_id, rng),
			"flow_warning": flow_scale < 1.0 and _rune_family_of(rune_id) == "flow"
		})
	return offers

# -----------------------------------------------------------------------------
# 1단계 — 각인 3택1
# -----------------------------------------------------------------------------
## W9가 인자 2개를 추가했다(전부 기본값 있음 — 기존 호출부 무변경):
##   `rarity_filter` : 그 희귀도만 후보에 남긴다 (계약 "미래를 담보로" = epic 확정)
##   `option_count`  : 제시 장수. 1로 주면 확정 지급이 되고 미선택 조각도 0이 된다.
func _show_rune_draft(source: String = "level", return_state_override: String = "", rarity_filter: String = "", option_count: int = RUNE_DRAFT_OPTIONS) -> void:
	if factory == null:
		return
	draft_source = source
	if not return_state_override.is_empty():
		draft_return_state = return_state_override
	elif state not in ["rune_draft", "rune_target"]:
		draft_return_state = "playing"
	draft_offers = _roll_rune_draft(option_count, rarity_filter)
	draft_selected_rune = {}
	draft_selected_index = -1
	if draft_offers.is_empty():
		_finish_rune_draft()
		return
	_build_rune_draft_screen()

func _build_rune_draft_screen() -> void:
	state = "rune_draft"
	get_tree().paused = true
	_reset_choice_focus()
	draft_slot_buttons.clear()
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "RuneDraft"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 각인은 마왕/심연 소속 화폐지만 껍데기까지 ABYSS로 가면 3택 카드(RUNE = ABYSS)가
	# 배경에 잠긴다(§7-2). 껍데기 SLATE · 리본 ABYSS · 카드 ABYSS 순으로 층을 갈랐다.
	# YZ(피드백 ① · ⑤): 리본 아래 **부제 밴드를 걷었다.** 리본이 「각인 드래프트 · 1/2 단계」,
	# 바로 아래 밴드가 「각인 하나를 고르세요」로 같은 말을 두 번 하고 있었다. 리본이
	# 할 일을 직접 말하게 하고 밴드는 지운다. 덤으로 영문 조어 「드래프트」도 사라진다.
	var panel := _kit_shell(overlay, RUNE_DRAFT_PANEL_RECT,
		"각인 고르기  ·  1 / 2 단계" if draft_source != "chest" else "봉인된 각인 고르기  ·  1 / 2 단계",
		UIKit.Tone.SLATE, UIKit.Tone.ABYSS, 480.0)
	panel.name = "RuneDraftPanel"
	_kit_panel(panel, Rect2(140.0, 74.0, 920.0, 30.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	_kit_label(panel, Rect2(140.0, 74.0, 920.0, 30.0),
		"고르지 않은 각인 %d개는 마왕의 각인 조각이 됩니다 (2개당 각인 1)   ·   각인은 카드가 아니라 「칸」에 붙습니다" % maxi(0, draft_offers.size() - 1),
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.INSET, HORIZONTAL_ALIGNMENT_CENTER)
	var gap := 30.0
	var total_width := RUNE_DRAFT_CARD_SIZE.x * float(draft_offers.size()) + gap * float(maxi(0, draft_offers.size() - 1))
	var start_x := (RUNE_DRAFT_PANEL_RECT.size.x - total_width) * 0.5
	for index in draft_offers.size():
		var button := _rune_offer_button(draft_offers[index])
		button.position = Vector2(start_x + float(index) * (RUNE_DRAFT_CARD_SIZE.x + gap), 110.0)
		panel.add_child(button)
		_register_choice_button(button, "rune", _select_draft_rune.bind(index))
	# 1단계의 문맥 레일 = **읽기 전용 공용 렌더러**(마왕 프리뷰·결과 화면과 같은 것).
	# Y2까지는 `_build_rune_mini_rail(interactive=false)` 분기가 이 자리를 그렸는데,
	# 그 함수의 절반이 2단계 전용이었고 2단계가 전면 재작성되면서 죽은 분기가 됐다.
	# 공용 렌더러를 쓰면 "내 5칸"이 게임 전체에서 같은 그림 하나가 된다.
	for context_index in factory.slots.size():
		_build_preview_slot(panel, factory, context_index, Vector2(22.0, 418.0), GamePalette.CYAN, true)
	_kit_label(panel, Rect2(0.0, RUNE_DRAFT_PANEL_RECT.size.y - 32.0, RUNE_DRAFT_PANEL_RECT.size.x, 22.0),
		"← → 각인 선택   ·   SPACE 결정   ·   칸 각인은 붙일 칸을 고르고, 레일 각인은 바로 붙습니다",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 18.0))
	_set_choice_index(0)
	play_sound("choice", -2.0)

func _rune_offer_button(offer: Dictionary) -> Button:
	var instance: Dictionary = offer.get("instance", {})
	var rune_id := String(instance.get("id", ""))
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	var color := _rune_rarity_color(rune_id)
	var button := _button("", color, RUNE_DRAFT_CARD_SIZE)
	# U2 v3: 킷 RUNE 프레임(ABYSS · 별 문양). 희귀도는 §6대로 테두리가 아니라
	# **칩과 이름 글자색**이 나른다 — 프레임에 강조색을 쓰지 않는다.
	_kit_card_skin(button, 2)
	button.set_meta("choice_role", "rune")
	button.set_meta("rune_id", rune_id)
	var inner_w := RUNE_DRAFT_CARD_SIZE.x - 48.0
	var rarity := String(definition.get("rarity", RuneEngine.RARITY_COMMON))
	# 희귀도 칩 — 계층 3(CHIP). 별 글리프 + 희귀도 색 글자.
	_kit_panel(button, Rect2(24.0, 20.0, 168.0, 28.0), UIKit.Tone.ABYSS, UIKit.Role.CHIP)
	_kit_glyph(button, Vector2(32.0, 24.0), "star", color, 20.0)
	var rarity_chip := _label("%s 각인" % String(RUNE_RARITY_NAME.get(rarity, rarity)), UI_LABEL_SIZE, color)
	rarity_chip.position = Vector2(58.0, 20.0)
	rarity_chip.size = Vector2(126.0, 28.0)
	rarity_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(rarity_chip)
	var name_label := _label(String(definition.get("name", rune_id)), UI_TITLE_SIZE, GamePalette.TEXT)
	name_label.position = Vector2(24.0, 56.0)
	name_label.size = Vector2(inner_w, 38.0)
	button.add_child(name_label)
	# ★ Y3(피드백 ⑨ · §8 ⑨): **소속 배지를 크게.** Y2는 계열 옆에 작은 글자로 붙였는데,
	#   칸 각인과 레일 각인은 "다음에 무슨 화면이 오는가"가 통째로 다른 물건이다.
	#   글리프 + 큰 글자 배지 하나로 카드에서 두 번째로 큰 요소가 됐다(이름 다음).
	var scope_rail := RuneEngine.rune_scope(rune_id) == "rail"
	var scope_color := GamePalette.MAGENTA if scope_rail else GamePalette.CYAN
	_kit_panel(button, Rect2(24.0, 92.0, 176.0, 34.0), UIKit.Tone.ABYSS, UIKit.Role.CHIP)
	_kit_glyph(button, Vector2(32.0, 98.0), "diamond" if scope_rail else "bag", scope_color, 22.0)
	var scope_label := _label("레일 각인" if scope_rail else "칸 각인", UI_HEADING_SIZE, scope_color)
	scope_label.position = Vector2(62.0, 92.0)
	scope_label.size = Vector2(130.0, 34.0)
	scope_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(scope_label)
	var family := _label(String(RUNE_FAMILY_NAME.get(String(definition.get("family", "")), "각인")),
		UI_CAPTION_SIZE, UIKit.muted_on(UIKit.Tone.ABYSS))
	family.position = Vector2(208.0, 92.0)
	family.size = Vector2(RUNE_DRAFT_CARD_SIZE.x - 232.0, 34.0)
	family.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	family.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(family)
	var rolls := bool(definition.get("roll", true))
	var probability_text := "발동 확률  %d%%" % int(round(float(instance.get("p", 0.0)) * 100.0))
	if not rolls:
		probability_text = "확정 발동  ·  굴리지 않는다"
	# 확률 한 줄은 이 카드의 결정 근거다 — 함몰판(계층 2) 위에 올려 다른 줄과 층을 가른다.
	_kit_panel(button, Rect2(24.0, 132.0, inner_w, 32.0), UIKit.Tone.ABYSS, UIKit.Role.INSET)
	var probability := _label(probability_text, UI_HEADING_SIZE, GamePalette.YELLOW if rolls else GamePalette.GREEN)
	probability.position = Vector2(36.0, 132.0)
	probability.size = Vector2(inner_w - 24.0, 32.0)
	probability.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(probability)
	var effect := _label(String(definition.get("effect", "")), UI_BODY_SIZE + 1, UIKit.text_on(UIKit.Tone.ABYSS))
	effect.position = Vector2(24.0, 170.0)
	effect.size = Vector2(inner_w, 58.0)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(effect)
	var owned := 0
	var owned_rule := "한 칸 같은 각인 최대 %d개" % RuneEngine.SAME_ID_STACK_CAP
	if factory != null:
		if scope_rail:
			owned = factory.rail_rune_ids().count(rune_id)
			owned_rule = "레일 각인 최대 %d개 · 같은 것 1개" % RuneEngine.RAIL_RUNE_CAP
		else:
			for slot_index in factory.slots.size():
				for rune_value in factory.runes_on(slot_index):
					if String((rune_value as Dictionary).get("id", "")) == rune_id:
						owned += 1
	var owned_label := _label("보유 %d개  ·  %s" % [owned, owned_rule], UI_CAPTION_SIZE, GamePalette.GREEN if owned > 0 else UIKit.muted_on(UIKit.Tone.ABYSS))
	owned_label.position = Vector2(24.0, 234.0)
	owned_label.size = Vector2(inner_w, 18.0)
	button.add_child(owned_label)
	if bool(offer.get("flow_warning", false)):
		# 흐름 몰림 배지 — EMBER 칩 + warn 글리프. 텍스트 `⚠`를 킷 글리프로 갈았다.
		# Y3: 「과부하」는 금지 어휘가 됐다(§8 금지 어휘표) — 사실만 적는다.
		_kit_panel(button, Rect2(24.0, 256.0, inner_w, 26.0), UIKit.Tone.EMBER, UIKit.Role.CHIP)
		_kit_glyph(button, Vector2(32.0, 260.0), "warn", GamePalette.YELLOW, 18.0)
		var warn := _label("흐름 각인이 몰린 칸이 있습니다", UI_CAPTION_SIZE, UIKit.text_on(UIKit.Tone.EMBER, UIKit.Role.CHIP))
		warn.position = Vector2(56.0, 256.0)
		warn.size = Vector2(inner_w - 40.0, 26.0)
		warn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(warn)
		button.set_meta("flow_warning", true)
	return button

func _select_draft_rune(index: int) -> void:
	if state != "rune_draft" or index < 0 or index >= draft_offers.size():
		return
	draft_selected_index = index
	draft_selected_rune = draft_offers[index]
	play_sound("choice", -2.0)
	# ★ Y2 수리 ③-b: 칸/레일 분기. 레일 각인은 2단계를 건너뛰고 바로 레일에 붙는다.
	var chosen_id := String((draft_selected_rune.get("instance", {}) as Dictionary).get("id", ""))
	if RuneEngine.rune_scope(chosen_id) == "rail":
		_commit_rail_rune_draft()
		return
	_show_rune_target()

## 레일 각인 드래프트의 종착점. 칸 각인의 `_attach_draft_rune()`과 같은 뒷정리를 한다
## (미선택분 → 마왕 조각 · 사이클 재계획 · 미리보기 갱신 · 배너).
func _commit_rail_rune_draft() -> void:
	var instance: Dictionary = draft_selected_rune.get("instance", {})
	var rune_id := String(instance.get("id", ""))
	var rune_name := String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("name", rune_id))
	if not _apply_rail_rune(instance):
		# 후보 생성기가 이미 걸렀으므로 정상 경로에서는 도달하지 않는다. 그래도 갇히지
		# 않게 골드로 환산하고 끝낸다 — 「죽은 선택지」를 다시 만들지 않기 위한 안전망이다.
		gold += CHOICE_FORFEIT_GOLD
		_finish_rune_draft()
		_show_banner("레일에 %s 각인을 더 붙일 수 없습니다 · +%d G" % [rune_name, CHOICE_FORFEIT_GOLD], GamePalette.ORANGE, 2.6)
		return
	var leftovers := _grant_draft_leftovers()
	_reset_player_cycle()
	_refresh_factory_preview(true)
	_finish_rune_draft()
	_show_banner("레일에 %s 각인 · 안 고른 각인 %d개는 마왕에게" % [rune_name, leftovers], GamePalette.MAGENTA, 2.8)
	play_sound("choice", -1.0)

# -----------------------------------------------------------------------------
# 2단계 — "어느 칸에 붙일까요?"  (Y3 전면 재작성 · 피드백 ② · 설계 §8 ②)
# -----------------------------------------------------------------------------
# 무엇이 문제였나 — 이 화면은 칸 하나마다 여덟 줄을 세웠다:
#   각인 N/5 · 상태 한 줄 · "여기 붙이면" · Δ 4줄 · 과부하율 · SPACE 부착.
#   × 5칸 = **40줄.** 거기에 기준선 1줄 · 스택 규칙 1줄 · 드래프트 풀 3줄이 더 붙었다.
#   사용자 피드백 ②가 "각인 부착 화면을 간소화"라고 말한 그 화면이다.
#
# 무엇으로 갈았나 — **글자를 지운 것이 아니라 층을 옮겼다**(정보 손실 0).
#   화면에는 「어느 칸에 붙일까요?」 한 줄 + ESC 편집 화면과 **같은 5칸 그림**만 남는다.
#   Δ 5개 · 스택 규칙 · 기준선 · 드래프트 풀은 전부 **호버 툴팁**으로 내려갔다.
#   X2가 편집 화면에서 쓴 수법 그대로다(상시 문장 60+ → 7).
#
# 기하 — `RUNE_TARGET_SLOT_SIZE(196×300)`은 **폐기**했다. 칸은 `EDIT_SLOT_SIZE(196×204)`,
#   간격은 `EDIT_RAIL_PITCH(240)`, 각인 줄은 `EDIT_SLOT_PIP_Y(174)`다 — 편집 화면과
#   같은 상수를 읽으므로 두 화면의 칸이 **픽셀 단위로 같다.**
#   ⚠️ 읽기 전용 레일(`EDIT_CARD_SIZE` 계열 · 마왕 프리뷰·결과 화면 공유)과는 다른
#      상수다. 합치면 그 두 화면이 같이 늘어난다(FEEDBACK_Y 리스크 ⑨).
const RUNE_TARGET_PANEL_RECT := Rect2(40.0, 150.0, 1200.0, 420.0)
const RUNE_TARGET_RAIL_ORIGIN := Vector2(42.0, 116.0)
const RUNE_TARGET_SAMPLES := 48

func _show_rune_target() -> void:
	if factory == null or draft_selected_rune.is_empty():
		return
	state = "rune_target"
	get_tree().paused = true
	_reset_choice_focus()
	draft_slot_buttons.clear()
	_begin_modal_tooltips()
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "RuneTarget"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 제목은 **리본 하나**다. 안쪽에 같은 말을 다시 쓰지 않는다.
	var panel := _kit_shell(overlay, RUNE_TARGET_PANEL_RECT, "어느 칸에 붙일까요?",
		UIKit.Tone.SLATE, UIKit.Tone.ABYSS, 420.0)
	panel.name = "RuneTargetPanel"
	var instance: Dictionary = draft_selected_rune.get("instance", {})
	var rune_id := String(instance.get("id", ""))
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	var color := _rune_rarity_color(rune_id)
	# 지금 손에 든 각인 — 그림 기호 + 이름 + 효과 한 문장. 규칙·기준선은 호버가 말한다.
	var held := _kit_panel(panel, Rect2(210.0, 48.0, 780.0, 52.0), UIKit.Tone.ABYSS, UIKit.Role.INSET)
	held.name = "RuneTargetHeld"
	_rune_glyph(held, Vector2(16.0, 14.0), rune_id, color, 24.0)
	var rolls := bool(definition.get("roll", true))
	var chosen := _label("%s  ·  %s" % [String(definition.get("name", rune_id)),
		"확정 발동" if not rolls else "발동 %d%%" % int(round(float(instance.get("p", 0.0)) * 100.0))],
		UI_HEADING_SIZE, color)
	chosen.position = Vector2(50.0, 5.0)
	chosen.size = Vector2(714.0, 24.0)
	held.add_child(chosen)
	var effect := _label(String(definition.get("effect", "")), UI_BODY_SIZE, GamePalette.MUTED)
	effect.position = Vector2(50.0, 28.0)
	effect.size = Vector2(714.0, 20.0)
	held.add_child(effect)
	# 기준선을 **각 칸의 투영과 똑같은 표본 수·시드로** 먼저 잰다. 표본이 다르면
	# Δ가 각인 효과가 아니라 표본 노이즈를 보여 준다(짝지은 비교여야 부호가 신뢰된다).
	draft_baseline = _rune_target_projection(-1, {})
	_modal_tip(held, "held", _rune_target_held_tooltip(rune_id, color))
	var selectable := _build_rune_target_rail(panel)
	var footer_y := RUNE_TARGET_PANEL_RECT.size.y - 32.0
	if selectable <= 0:
		# 모든 칸이 상한이면 갇히지 않게 한다. 각인은 마왕에게 가고 자금으로 환산한다.
		var stuck := _button("칸이 모두 가득 찼습니다 · 마왕에게 넘기고 +%d G" % CHOICE_FORFEIT_GOLD,
			GamePalette.ORANGE, Vector2(620.0, 44.0))
		stuck.position = Vector2((RUNE_TARGET_PANEL_RECT.size.x - 620.0) * 0.5, 332.0)
		panel.add_child(stuck)
		_register_choice_button(stuck, "cancel", _forfeit_rune_draft)
	_kit_label(panel, Rect2(0.0, footer_y, RUNE_TARGET_PANEL_RECT.size.x, 22.0),
		"← → 칸 고르기   ·   SPACE 붙이기   ·   ESC 다시 고르기",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	# 툴팁 층은 **가장 마지막**에. 카드·버튼보다 먼저 붙이면 그 아래로 깔린다.
	_bind_modal_tooltips()
	_animate_modal(panel, Vector2(0.0, 18.0))
	_focus_first_selectable_slot()
	play_sound("choice", -4.0)

## 손에 든 각인 띠의 호버 — 스택 규칙 · 기준선 · 드래프트 풀 세 덩어리가 여기 모였다.
## 세 덩어리 전부 "지금 무엇을 고르는가"의 배경 지식이지 칸별 정보가 아니다.
func _rune_target_held_tooltip(rune_id: String, color: Color) -> Dictionary:
	var scope_rail := RuneEngine.rune_scope(rune_id) == "rail"
	var rows: Array = [
		["한 칸 상한", "총 %d개 · 같은 각인 %d개" % [RuneEngine.RUNE_STACK_CAP, RuneEngine.SAME_ID_STACK_CAP], GamePalette.YELLOW],
		["빽빽함", "%d개째부터 그 칸의 모든 확률 ×%.2f" % [RuneEngine.RUNE_SLOTS_PER_SLOT + 1, RuneEngine.CONGESTION_FALLOFF], GamePalette.ORANGE],
		["지금 값", "스텝 %.2f · 피해 %.1f · RELOAD %.2f초" % [
			float(draft_baseline.get("mean_steps", 0.0)), float(draft_baseline.get("mean_damage", 0.0)),
			float(draft_baseline.get("mean_reload", 0.0))], GamePalette.CYAN]
	]
	var saturated := _rune_draft_saturated_slots()
	if saturated > 0:
		rows.append(["흐름 억제", "흐름 각인 %d개 이상인 칸 %d개 → 나올 확률 ×%.2f" % [
			RUNE_DRAFT_FLOW_SATURATION, saturated, _rune_draft_flow_scale()], GamePalette.ORANGE])
	rows.append(["마왕의 각인", "%d / %d · 조각 %d" % [
		demon_lord.rune_count(), demon_lord.rune_capacity(), demon_lord.rune_shards], GamePalette.RED.lightened(0.15)])
	return {
		"title": "붙이기 규칙",
		"accent": color,
		"rows": rows,
		"body": "칸마다 「여기 붙이면 얼마나 달라지는가」가 그 칸 위에 뜹니다. 같은 시드 %d표본으로 짝지어 비교한 값입니다.%s" % [
			int(draft_baseline.get("samples", RUNE_TARGET_SAMPLES)),
			" 이 각인은 레일 전체가 가지므로 칸을 고르지 않습니다." if scope_rail else ""]
	}

## 5칸 — **ESC 편집 화면과 같은 그림**. 다른 것은 드래그가 아니라 선택이라는 점뿐이다.
## 반환값은 고를 수 있는 칸 수(0이면 출구 버튼이 뜬다).
func _build_rune_target_rail(panel: Control) -> int:
	var instance: Dictionary = draft_selected_rune.get("instance", {})
	var rune_id := String(instance.get("id", ""))
	var origin := RUNE_TARGET_RAIL_ORIGIN
	# 칸 사이 선과 ▶ 하나 — 편집 화면의 `_build_edit_rail`과 같은 그림이다.
	for index in maxi(0, factory.slots.size() - 1):
		var spine := ColorRect.new()
		spine.position = Vector2(origin.x + float(index) * EDIT_RAIL_PITCH + EDIT_SLOT_SIZE.x,
			origin.y + EDIT_SLOT_SIZE.y * 0.5 - 2.0)
		spine.size = Vector2(EDIT_CONNECTOR_W, 4.0)
		spine.color = FACTORY_RAIL_SPINE_BUILT
		spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(spine)
		var arrow := _label("▶", 17, FACTORY_RAIL_SPINE_BUILT.lightened(0.52))
		arrow.position = Vector2(spine.position.x, spine.position.y - 12.0)
		arrow.size = Vector2(EDIT_CONNECTOR_W, 24.0)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(arrow)
	var selectable := 0
	for slot_index in factory.slots.size():
		var runes: Array = factory.runes_on(slot_index)
		var same_id := 0
		for rune_value in runes:
			if String((rune_value as Dictionary).get("id", "")) == rune_id:
				same_id += 1
		var full := runes.size() >= RuneEngine.RUNE_STACK_CAP
		var same_full := same_id >= RuneEngine.SAME_ID_STACK_CAP
		var blocked := full or same_full
		var slot_card: Dictionary = factory.get_card(slot_index)
		var element := _card_element(slot_card)
		var element_color := _element_color(element)
		var button := _button("", GamePalette.STONE_DARK if blocked else GamePalette.MAGENTA, EDIT_SLOT_SIZE)
		button.name = "RuneTargetSlot%d" % slot_index
		button.position = origin + Vector2(float(slot_index) * EDIT_RAIL_PITCH, 0.0)
		# 상한 도달 칸은 회색 테두리가 아니라 **함몰 베벨**(DISABLED)이라 기하만으로 읽힌다.
		_kit_card_skin(button, 2, 2 if blocked else 0)
		button.disabled = blocked
		button.set_meta("slot_index", slot_index)
		button.set_meta("blocked", blocked)
		panel.add_child(button)
		draft_slot_buttons.append(button)
		if not blocked:
			selectable += 1
			_register_choice_button(button, "slot", _attach_draft_rune.bind(slot_index))
		if not slot_card.is_empty() and not element.is_empty():
			_element_wash(button, Rect2(14.0, 14.0, 168.0, 172.0), element_color, 0.16)
		# ① 손잡이 띠 자리 — 편집 화면과 같은 28px 띠. 번호와 원소 마크만 있다.
		var head := _kit_panel(button, EDIT_SLOT_HANDLE_RECT, UIKit.Tone.SLATE, UIKit.Role.CHIP)
		if not slot_card.is_empty() and not element.is_empty():
			_element_wash(head, Rect2(2.0, 2.0, EDIT_SLOT_HANDLE_RECT.size.x - 4.0,
				EDIT_SLOT_HANDLE_RECT.size.y - 4.0), element_color, 0.20)
		var numeral := _label("%d" % (slot_index + 1), UI_HEADING_SIZE,
			GamePalette.STONE if blocked else (element_color.lightened(0.34) if not slot_card.is_empty() else GamePalette.MUTED))
		numeral.position = Vector2(EDIT_SLOT_HANDLE_RECT.position.x + 4.0, EDIT_SLOT_HANDLE_RECT.position.y + 2.0)
		numeral.size = Vector2(24.0, 24.0)
		numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(numeral)
		var mark := String(RAIL_ELEMENT_MARK.get(element, ""))
		if not mark.is_empty():
			var mark_label := _label(mark, UI_LABEL_SIZE, element_color.lightened(0.34))
			mark_label.position = Vector2(EDIT_SLOT_HANDLE_RECT.end.x - 28.0, EDIT_SLOT_HANDLE_RECT.position.y + 2.0)
			mark_label.size = Vector2(24.0, 24.0)
			mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			button.add_child(mark_label)
		# ② 카드 몸통 — 그림 하나 + 이름 한 줄. 편집 화면과 같은 기하다.
		var body := _kit_panel(button, EDIT_SLOT_BODY_RECT, UIKit.Tone.SLATE, UIKit.Role.CHIP)
		if not slot_card.is_empty() and not element.is_empty():
			_element_wash(body, Rect2((EDIT_SLOT_BODY_RECT.size.x - EDIT_SLOT_ICON) * 0.5 - 8.0, 1.0,
				EDIT_SLOT_ICON + 16.0, EDIT_SLOT_ICON + 4.0), element_color, 0.34)
		var icon := SKILL_ICON_SCRIPT.new()
		icon.position = Vector2((EDIT_SLOT_BODY_RECT.size.x - EDIT_SLOT_ICON) * 0.5, 2.0)
		icon.size = Vector2(EDIT_SLOT_ICON, EDIT_SLOT_ICON)
		icon.setup(String(slot_card.get("id", "basic")) if not slot_card.is_empty() else "basic",
			GamePalette.STONE_LIGHT if slot_card.is_empty() else _factory_card_color(slot_card))
		if slot_card.is_empty():
			icon.modulate = Color(1.0, 1.0, 1.0, 0.30)
		body.add_child(icon)
		var name_label := _label(_factory_card_name(slot_card), UI_BODY_SIZE,
			GamePalette.MUTED if (slot_card.is_empty() or blocked) else GamePalette.TEXT)
		name_label.position = Vector2(4.0, EDIT_SLOT_ICON + 4.0)
		name_label.size = Vector2(EDIT_SLOT_BODY_RECT.size.x - 8.0, 22.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body.add_child(name_label)
		# ③ 지속 / RELOAD 막대 두 개 — 편집 화면과 같은 자리(162)·같은 두 색.
		#    "어느 칸에 붙일까"의 근거이기도 하다(느린 칸에 앙코르를 붙이면 바퀴가 늘어진다).
		if not slot_card.is_empty() and String(slot_card.get("kind", "skill")) != "item":
			var ranked := DealCardLibrary.ranked(slot_card)
			var half := (EDIT_SLOT_HANDLE_RECT.size.x - 6.0) * 0.5
			_edit_meter(button, Vector2(14.0, EDIT_SLOT_METER_Y), Vector2(half, 8.0),
				float(ranked.get("duration", 0.0)), 2.8, GamePalette.CYAN)
			_edit_meter(button, Vector2(14.0 + half + 6.0, EDIT_SLOT_METER_Y), Vector2(half, 8.0),
				float(ranked.get("reload", 0.0)), 1.8, GamePalette.ORANGE)
		# ④ 각인 줄 — 편집 화면과 **같은 자리·같은 그림 기호**(174 · 간격 14 · +N).
		#    붙일 자리 하나가 유령으로 비어 있으면 "여기 들어간다"가 그림으로 읽힌다.
		var pip_row := Control.new()
		pip_row.position = Vector2(14.0, EDIT_SLOT_PIP_Y)
		pip_row.size = Vector2(EDIT_SLOT_HANDLE_RECT.size.x, 12.0)
		pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(pip_row)
		var shown := mini(runes.size(), RuneEngine.RUNE_SLOTS_PER_SLOT)
		for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
			if pip_index < shown:
				var owned_id := String((runes[pip_index] as Dictionary).get("id", ""))
				_rune_glyph(pip_row, Vector2(float(pip_index) * 14.0, 0.0), owned_id,
					_rune_rarity_color(owned_id), 12.0)
				continue
			var pip := ColorRect.new()
			pip.position = Vector2(float(pip_index) * 14.0, 1.0)
			pip.size = Vector2(10.0, 10.0)
			pip.color = Color(UI_EDGE_SOFT, 0.55)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip_row.add_child(pip)
		var overflow := runes.size() - RuneEngine.RUNE_SLOTS_PER_SLOT
		if overflow > 0:
			var extra := _label("+%d" % overflow, UI_CAPTION_SIZE, GamePalette.ORANGE)
			extra.position = Vector2(60.0, EDIT_SLOT_PIP_Y - 2.0)
			extra.size = Vector2(30.0, 16.0)
			button.add_child(extra)
		# ⑤ 고를 수 없는 칸은 **기호 하나**로 말한다(문장 2줄 → 0줄).
		if blocked:
			_kit_glyph(button, Vector2(EDIT_SLOT_SIZE.x - 40.0, EDIT_SLOT_PIP_Y - 6.0),
				"cross", GamePalette.RED, 22.0)
		_modal_tip(button, "target_slot%d" % slot_index,
			_rune_target_slot_tooltip(slot_index, instance, full, same_full))
	return selectable

## 칸 하나의 호버 — 화면에서 걷어낸 여덟 줄이 전부 여기 있다(정보 손실 0).
## Δ는 `_rune_target_projection()`이 기준선과 **같은 시드·같은 표본 수**로 잰 값이다.
func _rune_target_slot_tooltip(slot_index: int, instance: Dictionary,
		full: bool, same_full: bool) -> Dictionary:
	var runes: Array = factory.runes_on(slot_index)
	var rows: Array = []
	for rune_value in runes:
		var owned: Dictionary = rune_value
		var owned_id := String(owned.get("id", ""))
		var owned_def: Dictionary = RuneEngine.RUNES.get(owned_id, {})
		rows.append([String(owned_def.get("name", owned_id)),
			"확정" if not bool(owned_def.get("roll", true)) else "%d%%" % int(round(_slot_rune_probability(slot_index, owned_id) * 100.0)),
			_rune_rarity_color(owned_id)])
	if runes.is_empty():
		rows.append(["붙은 각인", "없음", GamePalette.MUTED])
	if full:
		rows.append(["고를 수 없음", "각인 %d개로 가득" % RuneEngine.RUNE_STACK_CAP, GamePalette.RED])
	elif same_full:
		rows.append(["고를 수 없음", "같은 각인 %d개 상한" % RuneEngine.SAME_ID_STACK_CAP, GamePalette.RED])
	else:
		var crowded := runes.size() >= RuneEngine.RUNE_SLOTS_PER_SLOT
		rows.append(["붙이면", "%s · 확률 ×%.2f" % ["빽빽함" if crowded else "여유",
			RuneEngine.congestion_scale(runes.size() + 1)],
			GamePalette.ORANGE if crowded else GamePalette.GREEN])
		# 실시간 투영 — 런타임과 같은 `simulate_cycle`로 "붙였을 때"를 돌린다.
		var projection := _rune_target_projection(slot_index, instance)
		for entry: Dictionary in [
			{"caption": "평균 스텝", "key": "mean_steps", "unit": "", "good_up": true},
			{"caption": "평균 피해", "key": "mean_damage", "unit": "", "good_up": true},
			{"caption": "평균 RELOAD", "key": "mean_reload", "unit": "초", "good_up": false},
			{"caption": "밟은 칸", "key": "mean_exec_slots", "unit": "칸", "good_up": true}
		]:
			var value := float(projection.get(String(entry["key"]), 0.0)) - float(draft_baseline.get(String(entry["key"]), 0.0))
			var improves := (value >= 0.0) == bool(entry["good_up"])
			var delta_color := GamePalette.GREEN if improves else GamePalette.RED
			if absf(value) < 0.005:
				delta_color = GamePalette.MUTED
			rows.append([String(entry["caption"]), "%s%.2f%s" % [
				"+" if value >= 0.0 else "−", absf(value), String(entry["unit"])], delta_color])
		var overload_now := float(projection.get("overload_rate", 0.0))
		var overload_was := float(draft_baseline.get("overload_rate", 0.0))
		rows.append(["바퀴 상한 도달", "%.1f%% → %.1f%%" % [overload_was * 100.0, overload_now * 100.0],
			GamePalette.RED if overload_now > overload_was else GamePalette.MUTED])
	return {
		"title": "칸 %02d — %s" % [slot_index + 1, _factory_card_name(factory.get_card(slot_index))],
		"accent": GamePalette.STONE if (full or same_full) else GamePalette.MAGENTA,
		"rows": rows,
		"body": "각인 %d / %d개." % [runes.size(), RuneEngine.RUNE_STACK_CAP]
	}

## "이 칸에 붙이면 어떻게 되는가". 원본 덱을 깊은 복사해 시뮬레이션만 돌린다.
## rune_deck()의 runes는 **참조**이므로(handoff-w2 §2.2) 복사를 빼먹으면 실제 덱이 오염된다.
func _rune_target_projection(slot_index: int, instance: Dictionary) -> Dictionary:
	var trial: Array = []
	for entry in factory.rune_deck():
		trial.append((entry as Dictionary).duplicate(true))
	if slot_index >= 0 and slot_index < trial.size():
		RuneEngine.attach_rune(trial[slot_index], instance.duplicate(true))
	# Y2: 지금 레일에 붙어 있는 각인도 함께 넘긴다 — 안 넘기면 기준선과 투영이 **둘 다**
	# 레일 각인 없는 세계를 재고 Δ가 실전과 어긋난다.
	return _factory_preview_summary(trial, run_cycle_seed + 104729, RUNE_TARGET_SAMPLES, factory.rune_opts())

func _focus_first_selectable_slot() -> void:
	for index in choice_buttons.size():
		var button := choice_buttons[index]
		if is_instance_valid(button) and not button.disabled:
			_set_choice_index(index)
			return

func _attach_draft_rune(slot_index: int) -> void:
	if state != "rune_target" or factory == null or draft_selected_rune.is_empty():
		return
	var instance: Dictionary = (draft_selected_rune.get("instance", {}) as Dictionary).duplicate(true)
	var rune_id := String(instance.get("id", ""))
	if not factory.attach_rune(slot_index, instance):
		_show_banner("이 칸에는 더 붙일 수 없습니다 (총 %d개 / 같은 각인 %d개)" % [RuneEngine.RUNE_STACK_CAP, RuneEngine.SAME_ID_STACK_CAP], GamePalette.RED, 2.0)
		return
	var rune_name := String((RuneEngine.RUNES.get(rune_id, {}) as Dictionary).get("name", rune_id))
	var leftovers := _grant_draft_leftovers()
	_reset_player_cycle()
	_refresh_factory_preview(true)
	_finish_rune_draft()
	_show_banner("%02d번 칸에 %s 각인 · 안 고른 각인 %d개는 마왕에게" % [slot_index + 1, rune_name, leftovers], GamePalette.MAGENTA, 2.8)
	play_sound("choice", -1.0)

func _forfeit_rune_draft() -> void:
	if state != "rune_target":
		return
	gold += CHOICE_FORFEIT_GOLD
	var leftovers := draft_offers.size()
	if leftovers > 0:
		grant_boss_rune_shards(leftovers)
	_finish_rune_draft()
	_show_banner("각인 %d개를 전부 마왕에게 넘겼습니다 · +%d G" % [leftovers, CHOICE_FORFEIT_GOLD], GamePalette.ORANGE, 2.6)
	play_sound("debt", -2.0)

## 미선택 각인 → 마왕의 각인 재료(§5.1 · §6.2). 조각 2개당 마왕 각인 1개가 늘어난다.
func _grant_draft_leftovers() -> int:
	var leftovers := maxi(0, draft_offers.size() - 1)
	if leftovers > 0:
		grant_boss_rune_shards(leftovers)
	return leftovers

func _finish_rune_draft() -> void:
	draft_offers.clear()
	draft_selected_rune = {}
	draft_selected_index = -1
	draft_slot_buttons.clear()
	choice_buttons.clear()
	_clear_overlay()
	get_tree().paused = false
	state = draft_return_state
	_grant_modal_return_invulnerability()
	_update_hud()
	if not pending_boss_toast_cards.is_empty():
		var forfeited := pending_boss_toast_cards.duplicate(true)
		pending_boss_toast_cards.clear()
		_show_boss_growth_toast(forfeited)
	# V8: "각인이 붙은 직후 2차 각성 조건을 다시 본다"는 W9 경계 접촉 1줄이 사라졌다 —
	# 각성 자체가 폐기됐고 트로피는 각인 수를 조건으로 삼지 않는다(설계 §5.5).
	if state == "playing" and experience >= xp_target:
		call_deferred("_show_skill_choice", "level")

## 드래프트 전용 키보드. 단일 포커스 모델(choice_buttons)을 그대로 쓰되
## 3개 이상·비활성 섞임을 다루기 위해 좌우 순환만 자체 처리한다.
func _handle_draft_keyboard(key_event: InputEventKey) -> void:
	if key_event.keycode == KEY_ESCAPE:
		if state == "rune_target":
			_build_rune_draft_screen()
		return
	if choice_buttons.is_empty():
		return
	if key_event.keycode in [KEY_LEFT, KEY_A, KEY_UP, KEY_W]:
		_advance_choice_index(-1)
	elif key_event.keycode in [KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S]:
		_advance_choice_index(1)
	elif key_event.keycode in [KEY_SPACE, KEY_ENTER]:
		_confirm_choice_index(choice_selected_index)

func _advance_choice_index(direction: int) -> void:
	var count := choice_buttons.size()
	if count <= 0:
		return
	for step in count:
		var candidate := wrapi(choice_selected_index + direction * (step + 1), 0, count)
		var button := choice_buttons[candidate]
		if is_instance_valid(button) and not button.disabled:
			_set_choice_index(candidate)
			return

# 마왕 카드 획득 토스트의 공개 진입점.
# 카드 2장을 한 번에 넘기면(딜싸이클 업그레이드 등) 한 토스트가 두 줄로 함께 알린다.
# 서로 다른 사건이 3초 안에 연달아 발생하면(연속 레벨업 등) 예전에는 먼저 뜬 토스트를
# 즉시 free해서 읽기 전에 사라졌다. 이제 큐에 넣어 순서대로 3초씩 보여준다.
func _show_boss_growth_toast(rejected_value) -> void:
	# W4: 마왕이 무언가를 받은 순간이다. 각인 부여 기록을 즉시 새 카드 수에 맞춘다
	# (각인 수 = clamp(floor(받은 카드 수 / 2), 0, 12) — 설계 §6.2).
	demon_lord.sync_runes(rng)
	var cards: Array[Dictionary] = []
	if rejected_value is Dictionary:
		cards.append((rejected_value as Dictionary).duplicate(true))
	elif rejected_value is Array:
		for entry in rejected_value:
			if entry is Dictionary:
				cards.append((entry as Dictionary).duplicate(true))
	if cards.is_empty():
		return
	if is_instance_valid(boss_toast):
		if boss_toast_queue.size() < GameTuning.BOSS_TOAST_QUEUE_MAX:
			boss_toast_queue.append(cards)
		else:
			# 큐가 가득 찰 정도로 몰리면 마지막 대기 항목에 합쳐 한 토스트로 알린다.
			var tail: Array[Dictionary] = boss_toast_queue[boss_toast_queue.size() - 1]
			tail.append_array(cards)
			boss_toast_queue[boss_toast_queue.size() - 1] = tail
		return
	_build_boss_growth_toast(cards)

func _finish_boss_growth_toast(finished_toast: Control) -> void:
	if is_instance_valid(finished_toast):
		finished_toast.queue_free()
	if boss_toast == finished_toast:
		boss_toast = null
	if boss_toast_queue.is_empty():
		return
	var next_cards: Array[Dictionary] = boss_toast_queue.pop_front()
	_build_boss_growth_toast(next_cards)

func _build_boss_growth_toast(cards: Array[Dictionary]) -> void:
	if cards.is_empty() or not is_instance_valid(ui_root):
		return
	if is_instance_valid(boss_toast):
		boss_toast.free()
	boss_toast = Control.new()
	boss_toast.name = "BossGrowthToast"
	boss_toast.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_toast.position = Vector2(940.0, 410.0)
	boss_toast.size = Vector2(315.0, 142.0)
	boss_toast.modulate.a = 0.0
	ui_root.add_child(boss_toast)
	var accent := ColorRect.new()
	accent.position = Vector2(0.0, 8.0)
	accent.size = Vector2(4.0, 126.0)
	accent.color = GamePalette.RED
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_toast.add_child(accent)
	# =========================================================================
	# Y4 — 마왕 초상 교체 (피드백 ⑧ · FEEDBACK_Y §8 ⑧ · handoff-ya §5)
	# =========================================================================
	# 구판은 `pixel_portrait.gd`가 `_draw()`로 찍던 **검은 사각형 + 뿔**이었고,
	# `sin(elapsed * 8.0)`으로 **상시 점멸**했다 — 프로젝트에 남아 있던 마지막
	# 무한 애니메이션이다(ui-style-v3 §11 트윈 루프 금지의 예외였다).
	# 이 한 줄이 그 파일의 유일한 소비자였으므로, 교체와 함께 점멸도 같이 사라진다.
	#
	# ⚠️ **48px 원본을 정확히 2배로 쓴다**(96×96). 74×104 슬롯에 맞추면 1.54배라
	#    픽셀이 불규칙하게 늘어난다 — 초상만 커지고 글자 열이 x 94 → 114로 밀렸다.
	#    폭 합계는 그대로다(10 + 96 + 8 + 195 = 309 ⊂ 315).
	var portrait := TextureRect.new()
	portrait.name = "BossToastPortrait"
	portrait.texture = BOSS_TOAST_PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.position = Vector2(10.0, 22.0)
	portrait.size = Vector2(96.0, 96.0)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_toast.add_child(portrait)
	var laugh := _label(BOSS_QUIPS[rng.randi_range(0, BOSS_QUIPS.size() - 1)], 18, GamePalette.RED.lightened(0.18))
	laugh.position = Vector2(114.0, 10.0)
	laugh.size = Vector2(195.0, 30.0)
	boss_toast.add_child(laugh)
	var detail_lines: Array[String] = []
	for rejected: Dictionary in cards:
		var rejected_id := String(rejected["id"])
		var boss_rank := maxi(rejected_skills.count(rejected_id), boss_items.count(rejected_id))
		detail_lines.append("%s ×%d" % [rejected.get("name", "카드"), boss_rank])
	if cards.size() == 1:
		detail_lines.append(String(cards[0].get("debt_desc", "마왕의 공장이 강해졌습니다.")))
	else:
		detail_lines.append("두 카드 모두 마왕에게 갔습니다")
	var detail := _label("\n".join(detail_lines), 13, GamePalette.TEXT)
	detail.position = Vector2(114.0, 43.0)
	detail.size = Vector2(195.0, 92.0)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_toast.add_child(detail)
	# 3차 피드백 ⑲: 예전 코드는 대기(tween_interval)와 페이드 아웃을 parallel()로 묶어
	# 실제로는 등장 직후 0.35초 만에 사라지고 남은 3.1초는 투명한 상태로 흘렀다.
	# 이제 등장 → BOSS_TOAST_HOLD(3.0초) 완전 표시 → 페이드 아웃 순서로 확실히 분리한다.
	var tween := boss_toast.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_toast, "modulate:a", 1.0, GameTuning.BOSS_TOAST_FADE_IN)
	tween.parallel().tween_property(boss_toast, "position:x", 905.0, GameTuning.BOSS_TOAST_SLIDE_IN)
	tween.tween_interval(GameTuning.BOSS_TOAST_HOLD)
	tween.tween_property(boss_toast, "modulate:a", 0.0, GameTuning.BOSS_TOAST_FADE_OUT)
	tween.parallel().tween_property(boss_toast, "position:x", 930.0, GameTuning.BOSS_TOAST_FADE_OUT)
	tween.tween_callback(_finish_boss_growth_toast.bind(boss_toast))

# v1의 진입점 이름을 유지한다(호출부·테스트가 이걸 부른다). 실제 상태 변경은
# 클럭이 하고, 그 결과를 아래 `_on_*` 핸들러가 받는다.
func _toggle_day_night() -> void:
	clock.advance_phase()

# --- 클럭 시그널 핸들러 (W4 소유) -------------------------------------------

func _on_night_started(day: int) -> void:
	# Y6: 「밤눈 부적」이 걸려 있으면 이 밤 동안 감지 반경이 −40%가 된다(§6.3).
	_night_eye_phase(true)
	for enemy: Node in combat.active_enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_boss:
			enemy.set_night_raid(true)
	for _index in combat.night_raid_burst_count():
		var spawn_position: Vector2 = world.find_walkable_near(player.global_position, rng, 570.0, 790.0)
		combat.spawn_enemy_instance(spawn_position)
	# V5: 전조 게이트가 "3일차부터"에서 "**dwell ≥ 2**"로 옮겨갔다(설계 §2.4 재키잉).
	# 5스테이지면 마왕에게 넘기는 카드가 v2의 4~5배라 각인을 뜯을 기회가 그만큼 늘어야 한다.
	var omen_spawned := _spawn_night_omen(day)
	if omen_spawned:
		_show_banner("%s 밤 · 마왕의 전조가 내려왔습니다 · 격파하면 그의 한 칸을 뜯을 수 있습니다" % clock.stage_name(), GamePalette.MAGENTA, 3.6)
	elif stage_descent_pending:
		_show_banner("강림한 보스가 필드를 배회합니다 · 이 밤은 도망칠 곳이 없습니다", GamePalette.RED, 3.6)
	elif blight_active:
		_show_banner("잠식된 밤 · 모든 마물이 마왕의 잔재를 들고 습격합니다", GamePalette.RED, 3.4)
	else:
		_show_banner("%d스테이지 밤 · 마물이 흉측하게 변합니다" % clock.stage, GamePalette.RED, 3.2)
	play_sound("night", -1.0)
	_update_hud()

func _on_day_started(day: int) -> void:
	_clear_omen()
	_night_eye_phase(false)
	for enemy: Node in combat.active_enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_boss:
			enemy.set_night_raid(false)
	# V5: "남은 기한 N일"은 사라졌다. 그 자리에 **체류 압박**이 들어간다(설계 §2.5 · §6.2).
	var pressure := " · 체류 %d" % clock.dwell
	var to_blight := clock.blight_threshold() - clock.dwell
	if blight_active:
		pressure += " · 잠식 진행 중"
	elif to_blight > 0:
		pressure += " · 잠식까지 %d주기" % to_blight
	_show_banner("총 %d일차 낮 · %d스테이지 %s%s" % [day, clock.stage, clock.stage_name(), pressure], GamePalette.YELLOW, 3.0)
	# === W9: 균열 개설 따라잡기 (V8: 각성 게이트는 함께 삭제됐다) ===
	# 이정표가 이미 처리했으면 즉시 no-op다. 여기 있는 이유는 ①자리를 못 찾아
	# 실패한 개설의 재시도 ②계약 NPC가 dwell을 건너뛴 경우의 복구, 두 가지다.
	_maintain_rift_schedule()
	# === Y6: 필드 사건 개설 따라잡기 (균열과 같은 자리 · §6.2) ===
	_maintain_event_schedule()
	_update_hud()

# =============================================================================
# V5: dwell 사건 — v2 일수 이정표의 자리를 통째로 이어받는다 (설계 §2.4)
# =============================================================================
# 클럭이 주기 하나를 마칠 때마다 `dwell_advanced(stage, dwell)`을 쏜다. 여기서
# ①균열 개설 따라잡기 ②잠식 점검 ③이정표 배너 ④HUD 갱신을 한다.
# 강림 밸브만은 `_process`가 폴링한다(클럭이 시그널을 안 쏜다 · handoff-v4 §1.3).
func _on_dwell_advanced(_stage_number: int, dwell_value: int) -> void:
	_maintain_rift_schedule()
	_maintain_event_schedule()
	_check_stage_blight()
	var id := clock.milestone_for_dwell(dwell_value)
	if not id.is_empty() and MILESTONE_BANNER.has(id) and id != StageClock.MILESTONE_BLIGHT:
		# 잠식 배너만은 `_begin_blight()`가 직접 띄운다(부여 마릿수를 함께 말해야 한다).
		var color := GamePalette.RED if id == StageClock.MILESTONE_DESCENT else GamePalette.MAGENTA
		_show_banner("체류 %d · %s" % [dwell_value, MILESTONE_BANNER[id]], color, 3.6)
	_update_hud()

## 잠식 점검. dwell이 임계에 닿으면 켜고, 스테이지 전환의 ×0.5 감쇠로 임계 아래로
## 떨어지면 끈다(설계 §2.4 "스테이지 클리어 시 해제").
func _check_stage_blight() -> void:
	if clock.blight_active():
		_begin_blight()
	elif blight_active:
		_end_blight()

func _end_blight() -> void:
	if not blight_active:
		return
	blight_active = false
	blight_sweep_timer = 0.0
	_show_banner("잠식이 걷혔습니다 · 세계가 잠시 당신을 잊었습니다", GamePalette.GREEN, 3.0)

## ⚠️ 테스트 하네스 전용 문. `test_runner.gd`가
## `game._on_clock_milestone(StageClock.MILESTONE_BLIGHT, day)`로 잠식을 강제로 켠다.
## 클럭은 이 시그널을 더 이상 쏘지 않으므로 실기에서는 절대 불리지 않는다.
func _on_clock_milestone(id: String, _day: int) -> void:
	if id == StageClock.MILESTONE_BLIGHT:
		_begin_blight()

# =============================================================================
# V5: 잠식(蠶食) — 구 월식(Eclipse) · 설계 §2.4 재키잉 / §6.4
# =============================================================================
# **트리거만 바뀌었다.** 5일차 → dwell ≥ STAGE_BLIGHT_DWELL[stage](=[4,4,3,3,2]).
# 해제도 생겼다 — 스테이지 클리어의 dwell ×0.5 감쇠가 임계 아래로 내리면 꺼진다.
# (V0의 §6.3 표 채택 판단을 V5가 재확인했다: §2.4의 유도식 `max(2, 5−stage)`는
#  3~5스테이지를 전부 2로 뭉개 후반 곡선이 계단이 된다. 표 쪽이 매끄럽다.)
# 아래 스윕·부여 코드는 v2 월식 그대로다(식별자 유지 이유는 파일 상단 주석 참조).
# W9까지 이 이정표는 **배너만** 있었다(handoff-w9 §6 "미구현 이정표 1건").
#
# 규칙 최종본
#   * **dwell이 스테이지 임계(`STAGE_BLIGHT_DWELL` = 4,4,3,3,2)에 닿는 순간** 켜지고
#     스테이지를 클리어하면 꺼진다(`BLIGHT_CLEARS_ON_STAGE_CLEAR`). v2는 "5일차에 켜져
#     런이 끝날 때까지 유지"였다 — 기한이 사라졌으므로 트리거도 체류로 옮겨왔다.
#   * 켜져 있는 동안 **필드에 나오는 모든 마물**이 한 번씩 스윕을 받아
#       ① 마왕의 잔재 카드 모듈 1개를 확정으로 얻고 (§6.4 "부여율 100%")
#       ② 마왕의 각인 1개를 나눠 받는다 (§4.1) — 체력·피해·속도 보정으로 환산
#     받았다는 표시는 `BLIGHT_META`(각인 id 문자열)로 마물에 남는다.
#   * 마왕이 잔재를 하나도 안 남겼으면 레일 5칸의 카드를 모듈로 환산해 대신 쓴다.
#     "버린 카드가 하나도 낭비되지 않는다"(§6.4)가 월식에서 가장 세게 나와야 한다.
#
# 구현 위치가 game.gd인 이유: `enemy.gd`의 부여 확률표(8~24%)와
# `combat_resolver.spawn_enemy_instance`는 둘 다 W10 소유가 아니다(무수정 원칙).
# 스폰 직후를 폴링으로 훑는 쪽이 라이브러리를 한 줄도 건드리지 않는 유일한 길이다.
func _begin_blight() -> void:
	if blight_active:
		return
	blight_active = true
	blight_sweep_timer = 0.0
	demon_lord.sync_runes(rng)
	var granted := _sweep_blight()
	_show_banner("잠식 · 체류 %d · 마왕의 각인이 필드 마물에게 흩어집니다 (지금 %d마리)" % [clock.dwell, granted], GamePalette.RED, 3.8)
	play_sound("night", -1.0)
	# Y7(§7.1): 흔들림은 **보스 착탄과 플레이어 피격에만.** 잠식은 둘 다 아니다 —
	# 배너·소리·붉은 물듦으로 충분히 읽힌다(흔들림 제거).

## 아직 표식이 없는 필드 마물 전부에게 월식을 적용한다. 적용한 마리 수를 돌려준다.
func _sweep_blight() -> int:
	if not blight_active or combat == null:
		return 0
	var applied := 0
	for enemy: Node in combat.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_boss or enemy.has_meta(BLIGHT_META):
			continue
		_apply_blight_to(enemy)
		applied += 1
	return applied

## 월식이 쓸 모듈 풀. 잔재가 우선이고, 없으면 마왕의 레일 5칸을 모듈로 환산한다.
func blight_module_pool() -> Array[String]:
	var modules := demon_lord.residue_modules()
	if not modules.is_empty():
		return modules
	for entry: Dictionary in demon_lord.slot_layout():
		var card: Dictionary = entry.get("card", {})
		if card.is_empty():
			continue
		var module := DealCardLibrary.debt_module(String(card.get("id", "")))
		if not module.is_empty() and not modules.has(module):
			modules.append(module)
	return modules

func _apply_blight_to(enemy: Node) -> void:
	# ① 잔재 모듈 100% 부여. 원거리 모듈만은 몬스터 게이트를 그대로 존중한다
	#    (enemy.gd L152의 규칙 — 초반 일차에 원거리가 터지는 회귀를 만들지 않는다).
	var pool := blight_module_pool()
	if not pool.is_empty():
		var module_id := String(pool[rng.randi_range(0, pool.size() - 1)])
		var ranged_blocked := module_id == MonsterLibrary.RANGED_MODULE and not MonsterLibrary.ranged_gate_ok(day_number)
		if not ranged_blocked and not enemy.active_modules.has(module_id):
			enemy.force_module(module_id)
	# ② 마왕의 각인 1개. 필드 마물에게는 5칸이 없으므로 각인을 "몸에 지닌 조각"으로
	#    환산한다 — 어떤 각인을 받았는지는 meta에 남겨 테스트·툴팁이 읽을 수 있게 한다.
	var rune_id := ""
	if not demon_lord.granted_runes.is_empty():
		var picked: Dictionary = demon_lord.granted_runes[rng.randi_range(0, demon_lord.granted_runes.size() - 1)]
		rune_id = String(picked.get("rune_id", ""))
	enemy.set_meta(BLIGHT_META, rune_id)
	blight_marked += 1
	if rune_id.is_empty():
		return
	enemy.max_health *= GameTuning.BLIGHT_HEALTH_MUL
	enemy.health = enemy.max_health
	enemy.displayed_health = enemy.health
	enemy.trailing_health = enemy.health
	enemy.contact_damage *= GameTuning.BLIGHT_DAMAGE_MUL
	enemy.speed *= GameTuning.BLIGHT_SPEED_MUL

# =============================================================================
# W4: 밤의 전조(前兆) — 설계 §4.5
# =============================================================================
# 3일차부터 매 밤 1기. 마왕의 5칸 중 한 칸을 그대로 실행하는 중형 마물이다.
# 신규 시스템이 아니라 기존 부품 세 개의 조합이다:
#   ① combat.spawn_enemy_instance(..., allow_aggro_override=true)  — 선공몹 게이트 통과
#   ② enemy.use_external_deal_cycle(true)                          — 네이티브 공격 끄기
#   ③ 1칸짜리 FactoryDeck + DealCycleController(is_boss=true)      — 마왕의 칸을 시연
# camp_id를 달아 두면 멀어져도 디스폰하지 않고, 격파 시 combat.enemy_defeated가
# game._trial_enemy_defeated(camp_id)를 불러 주므로 별도 사망 훅이 필요 없다.
const OMEN_CAMP_PREFIX := "omen_"

## V5: v2 "3일차 밤~ 7일차"에서 **"dwell ≥ 2 · 전 스테이지"**로 재키잉(설계 §2.4).
## 인자는 호환을 위해 남겨 두지만 더 이상 일수가 아니다 — 음수면 현재 dwell을 쓴다.
func omen_should_spawn(dwell_value: int = -1) -> bool:
	return clock.omen_should_spawn(dwell_value)

func _spawn_night_omen(day: int) -> bool:
	if not omen_should_spawn():
		return false
	if not is_instance_valid(player) or not is_instance_valid(world):
		return false
	_clear_omen()
	demon_lord.sync_runes(rng)
	var slot_index := demon_lord.demo_slot_index(rng)
	var demo_card: Dictionary = demon_lord.slot_card(slot_index) if slot_index >= 0 else {}
	if demo_card.is_empty():
		# 마왕이 아직 아무 카드도 못 받았으면 기본 일격을 시연한다. 전조 자체는
		# 등장해야 한다 — 밤의 리듬이 일차마다 바뀌는 것이 이 시스템의 목적이다.
		demo_card = DealCardLibrary.basic_instance()
		slot_index = maxi(slot_index, 0)
	var spawn_position: Vector2 = world.find_walkable_near(player.global_position, rng, GameTuning.OMEN_SPAWN_MIN, GameTuning.OMEN_SPAWN_MAX)
	var camp_id := "%s%d" % [OMEN_CAMP_PREFIX, day]
	# camp_elite=false로 스폰한다. 정예 배율(체력 ×5)을 받지 않고 camp_id만 얻기 위해서다.
	# 체력은 바로 아래에서 설계값(일반 몹 ×6)으로 정확히 다시 잡는다.
	var omen := combat.spawn_enemy_instance(spawn_position, 4, "", false, camp_id, false, "", true)
	if not is_instance_valid(omen):
		return false
	omen.max_health *= GameTuning.OMEN_HEALTH_MUL
	omen.health = omen.max_health
	omen.displayed_health = omen.health
	omen.trailing_health = omen.health
	# 넉백·경직 저항 0.24와 굵은 체력바를 정예 경로에서 그대로 빌려 온다(설계 §4.5).
	omen.is_camp_elite = true
	omen.xp_value *= 4
	omen.gold_value *= 4
	omen.set_night_raid(true)
	omen.use_external_deal_cycle(true)
	omen_deck = FACTORY_SCRIPT.new()
	omen_deck.reset(1)
	omen_deck.place_card(0, demo_card.duplicate(true))
	# 시연하는 칸의 각인도 함께 들고 나온다 — 전조가 "마왕의 그 칸"인 이유가 여기다.
	for entry: Dictionary in demon_lord.runes_on_slot(slot_index):
		omen_deck.attach_rune(0, RuneEngine.roll_rune(String(entry.get("rune_id", "")), rng))
	omen_cycle = CYCLE_CONTROLLER_SCRIPT.new()
	omen_cycle.setup(self, omen, omen_deck, true, true, run_cycle_seed + 977 + day)
	gameplay_root.add_child(omen_cycle)
	active_omen = omen
	omen_slot_index = slot_index
	omen_night_count += 1
	spawn_burst(spawn_position, GamePalette.MAGENTA, 34, 300.0, 0.9)
	return true

func _clear_omen() -> void:
	if is_instance_valid(omen_cycle):
		omen_cycle.queue_free()
	omen_cycle = null
	omen_deck = null
	if is_instance_valid(active_omen) and not active_omen.dead:
		# 밤이 끝나면 전조는 사라진다(놓쳐도 다음 밤에 다시 온다).
		active_omen.queue_free()
	active_omen = null
	omen_slot_index = -1

# combat.enemy_defeated -> game._trial_enemy_defeated(camp_id) 경로로 들어온다.
func _omen_defeated(camp_id: String) -> void:
	var slot_index := omen_slot_index
	if is_instance_valid(omen_cycle):
		omen_cycle.queue_free()
	omen_cycle = null
	omen_deck = null
	active_omen = null
	omen_slot_index = -1
	gold += 12
	if state != "playing":
		_update_hud()
		return
	var can_strip := demon_lord.can_strip_rune()
	var can_reclaim := demon_lord.can_reclaim_card(slot_index)
	if not can_strip and not can_reclaim:
		_show_banner("전조 격파 · %s일차 · 아직 마왕에게서 뜯을 것이 없습니다" % camp_id.replace(OMEN_CAMP_PREFIX, ""), GamePalette.GREEN, 2.8)
		_update_hud()
		return
	pending_omen_reward = {
		"slot": slot_index,
		"can_strip": can_strip,
		"can_reclaim": can_reclaim,
		"card": demon_lord.slot_card(slot_index),
		"day": day_number
	}
	_show_omen_reward()

# W10: 전조 보상 2택1 화면을 W6 선택 카드 골격으로 재작성했다.
# handoff-w4 §4가 "UI는 최소 구현이다 · W6가 각인 드래프트와 같은 골격으로 재작성할 것.
# 상태 처리(`_resolve_omen_reward`)는 그대로 재사용 가능"이라고 남긴 자리다.
# **상태 처리는 한 줄도 고치지 않았다** — 화면만 `_build_choice_card_body`로 바꿨다.
const OMEN_REWARD_PANEL_RECT := Rect2(126.0, 118.0, 1028.0, 484.0)
const OMEN_REWARD_CARD_SIZE := Vector2(452.0, 252.0)

func _show_omen_reward() -> void:
	omen_return_state = state
	state = "omen_reward"
	get_tree().paused = true
	omen_reward_buttons.clear()
	omen_reward_index = 0
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "OmenReward"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	var panel := _kit_shell(overlay, OMEN_REWARD_PANEL_RECT,
		"전조 격파 · %d일차 밤" % int(pending_omen_reward.get("day", day_number)),
		UIKit.Tone.SLATE, UIKit.Tone.ABYSS, 420.0)
	# YZ(피드백 ① · ⑤): 부제 밴드 「마왕에게서 무엇을 뜯어낼까요」를 걷었다.
	# 아래 두 카드가 각각 「각인 뜯기 · 마왕 −1」 「카드 되찾기 · 보관함 +1」이라
	# 무엇을 고르는 화면인지 카드가 이미 말한다.
	var slot_index := int(pending_omen_reward.get("slot", 0))
	var demo_card: Dictionary = pending_omen_reward.get("card", {})
	# ⚠️ 카드 인스턴스에는 `name`이 없다(handoff-w9 §2.4). 정의를 통해 해석해야 한다.
	var card_name := _factory_card_name(demo_card)
	var note := _label("보여 준 칸: %d번 · %s   ·   마왕 각인 %d / %d 보유   ·   이미 뜯어낸 각인 %d" % [
		slot_index + 1, card_name, demon_lord.rune_count(), demon_lord.rune_capacity(), demon_lord.stripped_runes.size()
	], UI_BODY_SIZE, GamePalette.MUTED)
	note.position = Vector2(0.0, 84.0)
	note.size = Vector2(OMEN_REWARD_PANEL_RECT.size.x, 24.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(note)
	# 뜯길 각인이 무엇인지 미리 보여 준다 — DemonLord.strip_rune()이 "그 칸의 가장 최근"을
	# 고르므로 여기서도 같은 순서로 읽어 화면과 실제가 어긋나지 않게 한다.
	var slot_runes := demon_lord.runes_on_slot(slot_index)
	var target_rune := String((slot_runes[slot_runes.size() - 1] as Dictionary).get("rune_id", "")) if not slot_runes.is_empty() else ""
	if target_rune.is_empty() and not demon_lord.granted_runes.is_empty():
		# 그 칸에 각인이 없으면 strip_rune()은 아무 칸에서나 하나를 뜯는다(마지막 것).
		target_rune = String((demon_lord.granted_runes[demon_lord.granted_runes.size() - 1] as Dictionary).get("rune_id", ""))
	var can_strip := bool(pending_omen_reward.get("can_strip", false))
	var can_reclaim := bool(pending_omen_reward.get("can_reclaim", false))
	var card_gap := (OMEN_REWARD_PANEL_RECT.size.x - OMEN_REWARD_CARD_SIZE.x * 2.0) / 3.0
	# 왼쪽 = 각인(드래프트 각인 카드와 같은 언어) / 오른쪽 = 카드(선택 모달 카드와 같은 언어).
	# 두 보상은 성격이 다르므로 카드 골격도 각자의 화면에서 배운 것을 그대로 쓴다.
	var strip_accent: Color = _rune_rarity_color(target_rune) if can_strip else GamePalette.MUTED
	var strip_button := _button("", strip_accent, OMEN_REWARD_CARD_SIZE)
	_kit_card_skin(strip_button, 2)
	strip_button.position = Vector2(card_gap, 118.0)
	strip_button.disabled = not can_strip
	strip_button.set_meta("reward_index", 0)
	_omen_card_backdrop(strip_button)
	_paint_omen_rune_card(strip_button, target_rune, slot_index, can_strip)
	strip_button.pressed.connect(_resolve_omen_reward.bind(0))
	panel.add_child(strip_button)
	omen_reward_buttons.append(strip_button)

	var reclaim_accent: Color = GamePalette.GREEN if can_reclaim else GamePalette.MUTED
	var reclaim_button := _button("", reclaim_accent, OMEN_REWARD_CARD_SIZE)
	_kit_card_skin(reclaim_button, 0)
	reclaim_button.position = Vector2(card_gap * 2.0 + OMEN_REWARD_CARD_SIZE.x, 118.0)
	reclaim_button.disabled = not can_reclaim
	reclaim_button.set_meta("reward_index", 1)
	_omen_card_backdrop(reclaim_button)
	_build_choice_card_body(reclaim_button, demo_card, OMEN_REWARD_CARD_SIZE,
		card_name, "그 칸의 카드를 내 보관함으로 되찾습니다. 마왕의 레일에서 사라지고, 그 자리는 아래 순위 카드가 올라옵니다.",
		[
			{"text": "대상 칸  %d번" % (slot_index + 1), "color": GamePalette.TEXT},
			{"text": "마왕 받은 카드  %d → %d" % [demon_lord.received_card_count(), maxi(0, demon_lord.received_card_count() - 1)], "color": GamePalette.GREEN},
			{"text": "합성 카드는 원본 1장만 돌아옵니다", "color": GamePalette.MUTED}
		], "카드 회수  ·  내 보관함 +1", reclaim_accent)
	if not can_reclaim:
		_paint_omen_blocked(reclaim_button)
	reclaim_button.pressed.connect(_resolve_omen_reward.bind(1))
	panel.add_child(reclaim_button)
	omen_reward_buttons.append(reclaim_button)
	_kit_label(panel, Rect2(0.0, OMEN_REWARD_PANEL_RECT.size.y - 42.0, OMEN_REWARD_PANEL_RECT.size.x, 22.0),
		"← 왼쪽   ·   → 오른쪽   ·   SPACE 결정",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 18.0))
	_set_omen_reward_index(0)
	play_sound("choice", -2.0)
	if automated_test:
		call_deferred("_resolve_omen_reward", omen_reward_index)

# 포커스 스타일박스는 버튼 전체에 액센트 색을 깐다(공용 `_style_button`). 밝은 색
# (일반 각인 = 금색) 카드에서 본문이 묻히므로 handoff-w9 §7-7의 패턴을 그대로 쓴다 —
# 안쪽에 불투명 판을 하나 깔고 그 위에 글자를 올린다. `_style_button`은 공용이라 손대지 않는다.
## U2 v3: 킷 카드 프레임이 이미 불투명한 바탕을 들고 오므로 v1의 "안쪽 불투명 판"
## 우회는 필요 없어졌다. 대신 본문이 프레임 위로 올라타지 않게 여백만 잡아 준다.
func _omen_card_backdrop(button: Button) -> void:
	button.set_meta("kit_frame_pad", CARD_BLOCK_PAD_FRAMED)

# "각인 뜯기" 카드 — W6 각인 드래프트의 `_rune_offer_button`과 같은 시각 언어다
# (희귀도 칩 · 색 바 · 큰 이름 · 계열 · 확률 · 효과 문장). 크기만 이 화면에 맞췄다.
func _paint_omen_rune_card(button: Button, rune_id: String, slot_index: int, enabled: bool) -> void:
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	var color := _rune_rarity_color(rune_id) if enabled else GamePalette.MUTED
	var width := OMEN_REWARD_CARD_SIZE.x - 36.0
	var badge := _label("각인 뜯기  ·  마왕 −1", UI_LABEL_SIZE, color)
	badge.position = Vector2(18.0, 14.0)
	badge.size = Vector2(width, 20.0)
	button.add_child(badge)
	var bar := ColorRect.new()
	bar.position = Vector2(18.0, 38.0)
	bar.size = Vector2(width, 3.0)
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(bar)
	var name_label := _label(String(definition.get("name", "뜯을 각인 없음")), 26, GamePalette.TEXT if enabled else GamePalette.MUTED)
	name_label.position = Vector2(18.0, 48.0)
	name_label.size = Vector2(width, 34.0)
	button.add_child(name_label)
	var rarity := String(definition.get("rarity", RuneEngine.RARITY_COMMON))
	var family_text := "%s 각인  ·  %s" % [
		String(RUNE_RARITY_NAME.get(rarity, rarity)),
		String(RUNE_FAMILY_NAME.get(String(definition.get("family", "")), "각인"))
	]
	var family := _label(family_text, UI_LABEL_SIZE, GamePalette.CYAN if enabled else GamePalette.MUTED)
	family.position = Vector2(18.0, 84.0)
	family.size = Vector2(width, 20.0)
	button.add_child(family)
	var lines := [
		"대상 칸  %d번  ·  마왕 각인  %d → %d" % [slot_index + 1, demon_lord.rune_count(), maxi(0, demon_lord.rune_count() - 1)],
		String(definition.get("effect", "")),
		"이 각인을 마왕에게서 영영 지웁니다 — 마왕이 커지는 걸 막는 손잡이입니다."
	]
	for index in lines.size():
		var line := _label(String(lines[index]), UI_BODY_SIZE + 1, GamePalette.TEXT if index == 0 else GamePalette.MUTED)
		line.position = Vector2(18.0, 110.0 + float(index) * 44.0)
		line.size = Vector2(width, 42.0)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_child(line)
	if not enabled:
		_paint_omen_blocked(button)

func _paint_omen_blocked(button: Button) -> void:
	var blocked := _label("고를 수 없음", UI_LABEL_SIZE, GamePalette.RED)
	blocked.position = Vector2(OMEN_REWARD_CARD_SIZE.x - 112.0, 14.0)
	blocked.size = Vector2(94.0, 20.0)
	blocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(blocked)

func _set_omen_reward_index(index: int) -> void:
	if omen_reward_buttons.is_empty():
		return
	var wanted := clampi(index, 0, omen_reward_buttons.size() - 1)
	# 불가능한 선택지는 건너뛴다(각인이 없거나 회수할 카드가 없을 때).
	for step in omen_reward_buttons.size():
		var candidate := (wanted + step) % omen_reward_buttons.size()
		if not omen_reward_buttons[candidate].disabled:
			omen_reward_index = candidate
			omen_reward_buttons[candidate].grab_focus()
			return
	omen_reward_index = wanted

func _resolve_omen_reward(index: int) -> void:
	if state != "omen_reward" or pending_omen_reward.is_empty():
		return
	var slot_index := int(pending_omen_reward.get("slot", 0))
	var picked := clampi(index, 0, 1)
	if picked == 0 and not bool(pending_omen_reward.get("can_strip", false)):
		picked = 1
	elif picked == 1 and not bool(pending_omen_reward.get("can_reclaim", false)):
		picked = 0
	var message := ""
	if picked == 0:
		var stripped := demon_lord.strip_rune(slot_index)
		message = "각인 뜯기 · 마왕의 %d번 칸에서 각인 하나가 사라졌습니다 (남은 각인 %d)" % [slot_index + 1, demon_lord.rune_count()] if not stripped.is_empty() else "뜯어낼 각인이 없었습니다"
	else:
		var reclaimed := demon_lord.reclaim_card(slot_index)
		if reclaimed.is_empty():
			message = "회수할 카드가 없었습니다"
		else:
			if factory != null:
				factory.add_inventory(reclaimed)
			message = "카드 회수 · %s → 내 보관함 (마왕의 레일에서 사라졌습니다)" % String(reclaimed.get("name", "카드"))
	pending_omen_reward.clear()
	omen_reward_buttons.clear()
	demon_lord.sync_runes(rng)
	_clear_overlay()
	get_tree().paused = false
	state = omen_return_state
	_grant_modal_return_invulnerability()
	_show_banner(message, GamePalette.GREEN, 3.2)
	_update_hud()

# =============================================================================
# V7: v2 마왕 강림(`_trigger_descent`)은 **삭제됐다** — 설계 §2.1 · 부록 A-1 ③
# =============================================================================
# v2는 "7일차 밤이 끝나는 순간 마왕이 내려온다"는 두 번째 진입 경로를 갖고 있었다.
# v3에는 7일 기한이 없다. V4가 `StageClock`에서 그 스케줄을 지웠고 V5가
# `clock.descent_triggered` 연결을 끊어, 이 함수는 **호출부 0인 죽은 경로**로 남아 있었다
# (`grep _trigger_descent` = 선언 1줄 + 주석뿐이었다).
#
# 강림이라는 말은 v3에서 다른 것을 가리킨다 — **스테이지 보스**를 필드로 내리는
# 안전 밸브(§6.6)이고, 그 구현은 `_trigger_stage_descent()` / `_begin_stage_boss_descent()`다.
# 마왕전 진입은 이제 `_challenge_demon_king()` 하나이고 그 유일한 호출자는
# `on_stage_boss_defeated()`의 5스테이지 분기다.

# =============================================================================
# W4 공개 API — W2 / W5 / W10이 읽는 창구
# =============================================================================

## 마왕 성장 현황 한 덩어리. HUD 고스트 레일·프리뷰·결과 화면이 이것만 보면 된다.
func boss_growth_preview() -> Dictionary:
	demon_lord.sync_runes(rng)
	return demon_lord.preview(day_number)

## 짝수 레벨업에서 고르지 않은 각인이 마왕의 각인 재료가 된다(설계 §5.1, 2개당 1).
## W6의 각인 드래프트가 미선택 개수만큼 부른다.
func grant_boss_rune_shards(count: int) -> void:
	if count <= 0:
		return
	demon_lord.rune_shards += count
	demon_lord.sync_runes(rng)
	_update_hud()

## V5: `deadline_remaining()`은 **삭제됐다**(호출부 0). v3에는 기한이 없다 —
## 체류 압박은 초가 아니라 주기(dwell)로 센다. HUD는 `clock.dwell_ratio()`를 본다.

# =============================================================================
# W10: 런 기록 — 한 바퀴 최다 칸 수 (Y2: 구 「최고 과열」 지표의 후임 · §1.4)
# =============================================================================
# W5의 레일 바인더와 같은 "지연 연결" 규약이다. `_begin_run` / `_reset_player_cycle`
# (W4·W6 구역)을 건드리지 않고 "지금 붙은 컨트롤러가 바뀌었나"만 본다.
func _track_run_peak_steps() -> void:
	if peak_bound_cycle != player_cycle:
		peak_bound_cycle = player_cycle
		if is_instance_valid(player_cycle) and not player_cycle.cycle_completed.is_connected(_on_run_cycle_completed):
			player_cycle.cycle_completed.connect(_on_run_cycle_completed)
	if is_instance_valid(player_cycle):
		run_peak_steps = maxi(run_peak_steps, player_cycle.executed_slot_count())

func _on_run_cycle_completed(steps: int, _exec_peak: int) -> void:
	run_peak_steps = maxi(run_peak_steps, steps)

func _update_world_lighting(delta: float) -> void:
	if not is_instance_valid(canvas_modulate) or not is_instance_valid(world):
		return
	# V5 §7.3: 낮/밤 목표색이 스테이지 배열에서 온다. 1스테이지는 v2와 같은 값(WHITE / #8995c9)이라
	# 회귀가 0이고, 5스테이지는 #8a7794 / #2f2f52로 "거의 항상 밤"이 된다.
	var stage_index := clock.stage_index()
	var target_color: Color = GameTuning.STAGE_NIGHT_MODULATE[stage_index] if is_night else GameTuning.STAGE_DAY_MODULATE[stage_index]
	canvas_modulate.color = canvas_modulate.color.lerp(target_color, clampf(delta * 2.0, 0.0, 1.0))
	var target_night := 1.0 if is_night else 0.0
	world.set_night_amount(lerpf(world.night_amount, target_night, clampf(delta * 2.0, 0.0, 1.0)))
	_tint_stage_fog()

func _refresh_interactable() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	# Y6: 필드 사건을 **먼저** 본다(§6.2). 사건 자리는 랜드마크·균열과는 떼지만
	# 청크 상자와는 드물게 겹칠 수 있고, 그때 열려야 하는 것은 사건 쪽이다.
	var field_event := _nearest_field_event(player.global_position, EVENT_INTERACT_RADIUS)
	if not field_event.is_empty():
		current_interactable = {"type":"field_event", "id":String(field_event.get("id", "")),
			"position":field_event.get("position", Vector2.ZERO)}
		interaction_text.visible = true
		interaction_text.text = field_event_prompt(field_event)
		return
	current_interactable = world.get_nearest_interactable(player.global_position, 105.0)
	if current_interactable.is_empty():
		interaction_text.visible = false
		return
	interaction_text.visible = true
	match current_interactable["type"]:
		"castle": interaction_text.text = "[ E ]  성에 들어가기 · 상인 넷에게 들르기"
		"camp":
			var rest := "푹 쉴 수 있음" if not camp_rest_used else "이미 쉬었음"
			interaction_text.text = "[ E ]  베이스 캠프 · 성과 같은 상인 넷 · %s" % rest
		"boss_gate":
			# V7: 5스테이지 보스문만 "격파 = 곧 마왕전"을 예고한다(부록 A-1 ③).
			if stage_boss_cleared:
				interaction_text.text = "[ - ]  이 관문은 이미 열렸습니다"
			elif clock.stage >= GameTuning.STAGE_COUNT:
				interaction_text.text = "[ E ]  마지막 관문 · %s · 격파하면 그대로 마왕전입니다" % String(BossLibrary.rig(BossLibrary.rig_id(stage_boss_design(), stage_boss_enhanced())).get("name", "보스"))
			else:
				interaction_text.text = "[ E ]  %d스테이지 보스방 진입 · %s · 체류 %d에서 도전" % [
					clock.stage, String(BossLibrary.rig(BossLibrary.rig_id(stage_boss_design(), stage_boss_enhanced())).get("name", "보스")), clock.dwell]
		"chest": interaction_text.text = "[ E ]  보물상자 열기 · 보상 또는 함정"
		_: interaction_text.visible = false

func _refresh_castle_interactable() -> void:
	if not is_instance_valid(castle_interior) or not is_instance_valid(player):
		return
	current_interactable = castle_interior.get_nearest_interactable(player.global_position, 82.0)
	if current_interactable.is_empty():
		interaction_text.visible = false
		return
	interaction_text.visible = true
	match current_interactable["type"]:
		"castle_exit":
			interaction_text.text = "[ E ]  성 밖으로 나가기"
		"castle_npc":
			var service: String = current_interactable["service"]
			var info := _service_info(service)
			# 비용 0은 "무료"라고 말합니다. 그대로 "0 G"를 찍으면 고장처럼 보입니다.
			var service_cost := int(info["cost"])
			var payment := "무료" if service_cost <= 0 else "%d G" % service_cost
			var npc_name := String(info["name"])
			interaction_text.text = "[ E ]  %s%s 대화 · %s" % [npc_name, _particle_wa(npc_name), payment]
		_:
			interaction_text.visible = false

func _interact_with_world() -> void:
	if current_interactable.is_empty():
		return
	match current_interactable["type"]:
		"castle": _enter_castle(current_interactable)
		"camp": _enter_castle(current_interactable)
		"boss_gate": _enter_boss_gate()
		"castle_exit": _exit_castle()
		"castle_npc": _show_single_npc_service(String(current_interactable["service"]))
		# V7: `demon_castle` 분기는 **삭제됐다.** v3에는 마왕성 랜드마크가 없고
		# (`world_grid`가 `boss_gate`만 만든다) 마왕전은 5스테이지 격파로만 열린다.
		"chest": _open_chest(current_interactable)
		# === Y6 소유: 필드 사건 (§6.2 · 새 state를 만들지 않는다) ===
		"field_event": _activate_field_event(String(current_interactable.get("id", "")))

# =============================================================================
# V7: 보스방 진입 (설계 §3.5 · 부록 B V7)
# =============================================================================
# V5가 세운 파이프라인의 ②③이 여기서 채워진다:
#   ① 아레나·문 랜드마크·상호작용 타입 `boss_gate`  (V5)
#   ② 보스 프리뷰(취소 가능) → 3/4칸 보스전         (**V7 = 여기**)
#   ③ 격파 → 보상 훅 → `advance_stage()`            (**V7 = `on_stage_boss_defeated`**)
#   ④ 전환 파이프라인                                (V5 · 무수정 재사용)
# **`advance_stage()` 호출은 이 함수에서 사라졌다** — V5의 "진입 = 클리어" 임시 배선은
# 격파 콜백으로 이전됐다(부록 B V7 ⑥).
#
# 새 `state` 문자열을 만들지 않는다(설계 §3.5). 프리뷰는 기존 `boss_preview`,
# 전투는 기존 `boss`다. 누구의 프리뷰인지는 `boss_preview_kind`가 구분한다.
func _enter_boss_gate() -> void:
	if state != "playing" or clock.is_run_complete():
		return
	if stage_boss_cleared:
		_show_banner("이 관문은 이미 열렸습니다", GamePalette.MUTED, 2.0)
		return
	if is_instance_valid(stage_boss):
		return
	_show_stage_boss_preview()

# -----------------------------------------------------------------------------
# 보스 서술 만들기 — 로테이션 · HP · 패턴을 한 사전으로
# -----------------------------------------------------------------------------
## 이 스테이지의 보스 설계 문자(A/B/C)와 강화 여부. 로테이션 정본은 GameTuning이다.
func stage_boss_design(stage_number: int = -1) -> String:
	var index := clampi((clock.stage if stage_number < 1 else stage_number) - 1, 0, GameTuning.STAGE_BOSS_DESIGN.size() - 1)
	return GameTuning.STAGE_BOSS_DESIGN[index]

func stage_boss_enhanced(stage_number: int = -1) -> bool:
	var index := clampi((clock.stage if stage_number < 1 else stage_number) - 1, 0, GameTuning.STAGE_BOSS_ENHANCED.size() - 1)
	return GameTuning.STAGE_BOSS_ENHANCED[index]

## `BossLibrary.resolve()` + 이 런의 수치. 프리뷰와 전투가 **같은 사전**을 본다.
## `descended`면 칸 +1 · HP ×1.15 · 프리뷰 없음(§6.6).
func build_stage_boss_profile(descended: bool = false) -> Dictionary:
	var design := stage_boss_design()
	var enhanced := stage_boss_enhanced()
	var profile := BossLibrary.resolve(design, enhanced, descended)
	profile["stage"] = clock.stage
	profile["dwell"] = clock.dwell
	# §3.4의 HP 식. dwell 항(0.08)이 몹(0.14 + 0.012d²)보다 완만한 이유는
	# **오래 머문 플레이어를 두 번 벌하지 않기 위해서**다(boss_library.hp_for 주석).
	profile["health"] = BossLibrary.hp_for(design, clock.stage_hp_base(), clock.dwell, descended)
	profile["speed"] = GameTuning.STAGE_BOSS_SPEED_BASE + float(clock.stage - 1) * GameTuning.STAGE_BOSS_SPEED_STEP
	profile["contact_damage"] = (GameTuning.STAGE_BOSS_CONTACT_BASE + float(clock.stage - 1) * GameTuning.STAGE_BOSS_CONTACT_STEP) * clock.stage_damage_base()
	return profile

# -----------------------------------------------------------------------------
# 보스 딜싸이클 덱 — `FactoryDeck`을 상속해 **패턴을 카드처럼** 먹인다
# -----------------------------------------------------------------------------
# `FactoryDeck.compile_slot()`은 `DealCardLibrary.ranked()`로 카드 정의를 되읽는데
# 보스 패턴 id(`boss_a_stomp` …)는 그 라이브러리에 없다 — 그대로 두면 3칸 전부가
# **기본 베기**로 컴파일된다. 라이브러리도 `factory_deck.gd`도 V7 소유가 아니므로
# **덱 쪽에서 한 함수만 재정의**한다. GDScript 메서드는 기본이 가상이라
# `rune_deck()` / `total_reload()`(둘 다 `compile_slot`을 부른다)도 함께 올바르게 돈다.
class StageBossDeck:
	extends FactoryDeck

	## 강화·강림 파생까지 끝난 패턴 배열(`BossLibrary.patterns()`의 반환값).
	var patterns: Array = []

	func compile_slot(slot_index: int, _flow: Dictionary = {}) -> Dictionary:
		if slot_index < 0 or slot_index >= patterns.size():
			return {}
		var card: Dictionary = (patterns[slot_index] as Dictionary).duplicate(true)
		card["slot_index"] = slot_index
		card["casts"] = 1
		card["card_kind"] = "boss_pattern"
		# 실행 형태를 패턴 데이터가 아닌 **런타임 표식**으로 바꾼다.
		# `pattern_kind`가 원본이고 `kind`는 `combat_resolver._trigger_boss_cycle_pulse()`의
		# `match`에 **없는 문자열**이라 v2 보스 피해 경로에 절대 도달하지 않는다.
		# 판정·상태·소환은 전부 game.gd의 `_launch_stage_boss_pattern()`이 telegraph 뒤에
		# 실행한다 — 그래야 "선딜을 보고 피한다"가 성립한다(§3.3의 telegraph 열).
		card["pattern_kind"] = String(card.get("kind", "area"))
		card["kind"] = GameMain.STAGE_BOSS_PATTERN_KIND
		card["pattern_id"] = String(card.get("id", ""))
		return card

## 보스 패턴 카드의 `kind`. **의도적으로 기존 어느 분기에도 안 맞는 값**이다(위 주석).
## 이건 밸런스 숫자가 아니라 런타임 프로토콜 문자열이라 `tuning.gd`로 가지 않는다.
const STAGE_BOSS_PATTERN_KIND := "boss_pattern"
# ⚠️ V10(2026-08-09): 스테이지 보스 밸런스 손잡이 8개가 여기서 **`core/tuning.gd`로
#    이관됐다**(handoff-v9 §9 #12). V7이 그 파일을 열 수 없어 임시로 game.gd 상단에
#    두었던 것이고, 값은 1비트도 바뀌지 않았다. 새 이름은 `GameTuning.STAGE_BOSS_*`로
#    같다 — 이 파일 안의 참조 6곳만 `GameTuning.` 접두사를 달았다.

func _build_stage_boss_deck(profile: Dictionary) -> FactoryDeck:
	var deck := StageBossDeck.new()
	var patterns: Array = (profile.get("patterns", []) as Array)
	deck.reset(maxi(1, patterns.size()))
	deck.patterns = patterns.duplicate(true)
	# `slots[i]["card"]`도 채워 둔다 — 레일 밴드·프리뷰가 `get_card()`로 읽는다.
	for index in mini(deck.slots.size(), patterns.size()):
		(deck.slots[index] as Dictionary)["card"] = (patterns[index] as Dictionary).duplicate(true)
	return deck

# -----------------------------------------------------------------------------
# 프리뷰 — 내 5칸 vs 보스 3/4칸 (설계 §3.5 "취소 가능")
# -----------------------------------------------------------------------------
func _show_stage_boss_preview() -> void:
	stage_boss_profile = build_stage_boss_profile(false)
	stage_boss_factory = _build_stage_boss_deck(stage_boss_profile)
	boss_preview_kind = "stage"
	state = "boss_preview"
	get_tree().paused = true
	current_interactable.clear()
	interaction_text.visible = false
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "StageBossPreview"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_DEEP)
	# 보스·마왕 소속 화면 = ABYSS 껍데기 + EMBER 리본(§2 · §7-1).
	var panel := _kit_shell(overlay, BOSS_PREVIEW_PANEL_RECT,
		"%d스테이지 관문 — %s" % [clock.stage, String(stage_boss_profile.get("name", "보스"))],
		UIKit.Tone.ABYSS, UIKit.Tone.EMBER, 600.0)
	# 이름을 마왕 프리뷰와 같게 두면 `--boss-test`가 둘을 구분하지 못한다.
	panel.name = "StageBossPreviewPanel"
	_build_stage_boss_preview_header(panel)
	_build_stage_boss_preview_rails(panel)

	var challenge := _button("문을 연다 · SPACE", GamePalette.RED, Vector2(330.0, 52.0))
	challenge.position = Vector2(BOSS_PREVIEW_PANEL_RECT.size.x * 0.5 - 344.0, 574.0)
	challenge.pressed.connect(_begin_stage_boss_battle)
	panel.add_child(challenge)
	var retreat := _button("돌아가서 준비한다 · ESC", GamePalette.MUTED, Vector2(330.0, 52.0))
	retreat.position = Vector2(BOSS_PREVIEW_PANEL_RECT.size.x * 0.5 + 14.0, 574.0)
	retreat.pressed.connect(_cancel_boss_preview)
	panel.add_child(retreat)
	# 한글 라벨에 마크다운을 쓰지 않는다(§3) — 별표를 지운 문장을 그대로 둔다.
	_kit_label(panel, Rect2(BOSS_PREVIEW_BODY_X, 632.0, BOSS_PREVIEW_BODY_W, 20.0),
		"각인이 없는 대신 예비 동작이 있습니다 — 바닥에 링이 뜨면 그 자리를 벗어나고, RELOAD가 열리면 때리세요.",
		UIKit.Tone.ABYSS, UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	challenge.grab_focus()

func _build_stage_boss_preview_header(panel: Control) -> void:
	# 제목은 리본이 가져갔다. 머리말 두 줄은 함몰 띠(계층 2) 안으로 모은다.
	_kit_panel(panel, Rect2(BOSS_PREVIEW_BODY_X, 32.0, BOSS_PREVIEW_BODY_W, 38.0),
		UIKit.Tone.ABYSS, UIKit.Role.INSET)
	var phases: Array = stage_boss_profile.get("phases", [])
	var status_line := _label("체류 %d · 체력 %d · RELOAD ×%.2f · 페이즈 %d회%s" % [
		clock.dwell, int(round(float(stage_boss_profile.get("health", 0.0)))),
		float(stage_boss_profile.get("reload_scale", 0.75)), phases.size(),
		" · 강화형" if bool(stage_boss_profile.get("enhanced", false)) else ""
	], UI_LABEL_SIZE, GamePalette.RED.lightened(0.16))
	status_line.position = Vector2(BOSS_PREVIEW_BODY_X + BOSS_PREVIEW_BODY_W - 532.0, 34.0)
	status_line.size = Vector2(520.0, 18.0)
	status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(status_line)
	# YZ(피드백 ① · ⑤): 설명 띠를 한 줄로 줄였다. 「마왕만이 5칸과 각인을 가진다」는
	# 이 화면에서 당장 쓸 정보가 아니라 세계관 설명이라 뺐다 — 지금 필요한 것은
	# 「칸이 몇 개인가」와 「언제 때리는가」 둘뿐이다.
	var subtitle := _label("칸 %d개 · 각인 없음 — 한 바퀴가 끝나면 반드시 무방비해집니다." % int(stage_boss_profile.get("slot_count", 3)), UI_BODY_SIZE, GamePalette.MUTED)
	subtitle.position = Vector2(BOSS_PREVIEW_BODY_X + 14.0, 50.0)
	subtitle.size = Vector2(BOSS_PREVIEW_BODY_W - 28.0, 18.0)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(subtitle)

func _build_stage_boss_preview_rails(panel: Control) -> void:
	var my_runes := factory.total_rune_count() if factory != null else 0
	_build_preview_section_label(panel, PREVIEW_MY_LABEL_Y, "내 5칸", GamePalette.CYAN,
		"각인 %d개  ·  한 바퀴 RELOAD 빚 %.2f초  ·  장비 %d / %d" % [
			my_runes, factory.total_reload() if factory != null else 0.0,
			factory.equipment.size() if factory != null else 0, FactoryDeck.EQUIPMENT_PARTS.size()])
	_build_edit_flow_arcs(panel, factory, PREVIEW_MY_ARC, PREVIEW_RAIL_ORIGIN_X, 11.0)
	for index in (factory.slots.size() if factory != null else 0):
		_build_preview_slot(panel, factory, index, Vector2(PREVIEW_RAIL_ORIGIN_X, PREVIEW_MY_RAIL_Y), GamePalette.CYAN, true)
	var telegraph_sum := 0.0
	for entry in (stage_boss_profile.get("patterns", []) as Array):
		telegraph_sum += float((entry as Dictionary).get("telegraph", 0.0))
	_build_preview_section_label(panel, PREVIEW_BOSS_LABEL_Y, "보스의 %d칸" % int(stage_boss_profile.get("slot_count", 3)), GamePalette.RED,
		"각인 0개(스테이지 보스는 각인이 없습니다)  ·  예비 동작 합계 %.2f초  ·  한 바퀴 RELOAD 빚 %.2f초" % [
			telegraph_sum, stage_boss_factory.total_reload()])
	for index in stage_boss_factory.slots.size():
		_build_preview_slot(panel, stage_boss_factory, index, Vector2(PREVIEW_RAIL_ORIGIN_X, PREVIEW_BOSS_RAIL_Y), GamePalette.RED, true)

# -----------------------------------------------------------------------------
# 전투 개시
# -----------------------------------------------------------------------------
## 보스방 아레나 전투. 필드 위 제자리에서 싸운다(설계 §3.5 — 신규 씬 0개).
func _begin_stage_boss_battle() -> void:
	if state != "boss_preview" or boss_preview_kind != "stage":
		return
	_clear_overlay()
	get_tree().paused = false
	state = "boss"
	current_interactable.clear()
	interaction_text.visible = false
	stage_boss_arena_center = world.get_boss_gate_position() if is_instance_valid(world) else player.global_position
	# 아레나 안으로 끌어들인다 — 문 앞에서 멀찍이 활만 쏘는 전투가 되지 않게.
	if is_instance_valid(world):
		var offset: Vector2 = player.global_position - stage_boss_arena_center
		if offset.length() > world.boss_gate_radius * 0.62:
			var entry_point := stage_boss_arena_center + offset.normalized() * (world.boss_gate_radius * 0.58)
			if world.is_walkable(entry_point):
				player.global_position = entry_point
				var camera := player.get_node_or_null("PlayerCamera") as Camera2D
				if is_instance_valid(camera):
					camera.reset_smoothing()
	_spawn_stage_boss(stage_boss_profile, stage_boss_arena_center, true)

## 강림 밸브 경로(§6.6). 프리뷰 없음 · 필드 한복판 · state는 "playing" 그대로다.
func _begin_stage_boss_descent() -> void:
	stage_boss_profile = build_stage_boss_profile(true)
	stage_boss_factory = _build_stage_boss_deck(stage_boss_profile)
	stage_boss_arena_center = player.global_position
	var spawn_point := player.global_position + Vector2.from_angle(rng.randf() * TAU) * 210.0
	if not world.is_walkable(spawn_point):
		spawn_point = world.find_walkable_near(player.global_position, rng, 180.0, 320.0)
	_spawn_stage_boss(stage_boss_profile, spawn_point, false)

## 두 경로의 공통 몸통. `previewed`가 false면 강림이다.
func _spawn_stage_boss(profile: Dictionary, spawn_point: Vector2, previewed: bool) -> void:
	if not is_instance_valid(player) or not is_instance_valid(gameplay_root):
		return
	stage_boss_from_valve = not previewed
	stage_boss_defeat_handled = false
	stage_boss_telegraphs = 0
	stage_boss_phase_shifts = 0
	_clear_stage_boss_pools()
	StatusEngine.clear(player_status)
	if previewed:
		# 아레나 전투는 필드를 비운다(마왕전과 같은 규약). 강림은 **비우지 않는다** —
		# 필드에서 벌어지는 사건이고 잡몹도 같이 덤빈다는 것이 밸브의 압박이다.
		for enemy: Node in combat.active_enemies.duplicate():
			if is_instance_valid(enemy):
				enemy.queue_free()
		combat.active_enemies.clear()
		combat.enemy_spatial.clear()
		for orb: Node in get_tree().get_nodes_in_group("xp_orbs"):
			if is_instance_valid(orb):
				orb.queue_free()
	stage_boss = ENEMY_SCRIPT.new()
	var power_level := float(clock.day_number + level) * 0.7
	var empty_debts: Array[String] = []
	stage_boss.setup(self, player, "stage_boss", 4, power_level, empty_debts, true, false, [])
	# ⚠️ `configure_stage_boss()`는 **`add_child()` 전에** 불러야 한다 —
	#    `_ready()`가 `radius`로 CollisionShape2D를 만든다(enemy.gd 주석의 계약).
	stage_boss.configure_stage_boss(profile)
	stage_boss.position = spawn_point
	stage_boss.use_external_deal_cycle(true)
	gameplay_root.add_child(stage_boss)
	stage_boss_cycle = CYCLE_CONTROLLER_SCRIPT.new()
	stage_boss_cycle.setup(self, stage_boss, stage_boss_factory, true, true, run_cycle_seed + 6203 + clock.stage * 97)
	# **여기가 §3.2 표의 RELOAD 열이다.** `setup()`은 마왕값(0.60)을 넣으므로 덮어쓴다.
	# 기본형 0.75 / 강화형 0.55 — 강화형은 반격 창이 좁아진다.
	stage_boss_cycle.reload_scale = float(profile.get("reload_scale", GameTuning.STAGE_BOSS_RELOAD_MUL))
	gameplay_root.add_child(stage_boss_cycle)
	boss_reload_windows = 0
	boss_reload_open = false
	boss_rail_bound_cycle = null
	boss_panel.visible = true
	if is_instance_valid(boss_rail_band):
		boss_rail_band.visible = true
	_update_boss_rail(0.0)
	update_boss_health(stage_boss.health, stage_boss.max_health, stage_boss.shield, stage_boss.max_shield)
	spawn_burst(spawn_point, GamePalette.RED, 46, 340.0, 1.1)
	play_sound("boss", 0.0)
	shake_camera(12.0, 0.55)
	var intro := " · 변신" if stage_boss.boss_intro_playing() else ""
	if previewed:
		_show_banner("%s · %d칸 / RELOAD ×%.2f / 페이즈 %d회%s — 예비 동작을 보고 피하고 RELOAD에 때려라" % [
			String(profile.get("name", "보스")), int(profile.get("slot_count", 3)),
			float(profile.get("reload_scale", 0.75)), (profile.get("phases", []) as Array).size(), intro
		], GamePalette.RED, 4.0)
	else:
		var descend_name := String(profile.get("name", "보스"))
		_show_banner("강림 · %s%s 필드에 내려섰습니다 · %d칸 / 체력 ×%.2f · 등급 C 고정%s" % [
			descend_name, _particle_i(descend_name), int(profile.get("slot_count", 3)),
			GameTuning.STAGE_DESCENT_HP_MUL, intro
		], GamePalette.RED, 4.4)
	_update_hud()

# -----------------------------------------------------------------------------
# 페이즈 (설계 §3.2 표 · 기본 HP 50% 1회 / 강화 66%·33% 2회)
# -----------------------------------------------------------------------------
## `enemy._process_boss()`가 매 프레임 부른다. 판정은 enemy가, 연출·수치는 여기가 한다.
func on_stage_boss_tick(boss_node: Node, _delta: float) -> void:
	if not is_instance_valid(boss_node) or boss_node != stage_boss:
		return
	if boss_node.consume_boss_phase_step():
		_on_stage_boss_phase_shift(boss_node)

## 페이즈 전환의 효과는 **설계가 지정하지 않았다.** V7이 정한 것(근거는 handoff §4):
##   ① 패턴 피해 ×1.12 ② 선딜 ×0.86 ③ 그 자리에서 링 파동 1회 + 화면 흔들림
## 새 패턴을 열지 않는 이유 — 칸 수(3/4)가 §3.2 표의 확정값이라 페이즈로 늘리면
## "강화형만 4칸"이라는 시각적 승급 신호가 무너진다.
func _on_stage_boss_phase_shift(boss_node: Node) -> void:
	stage_boss_phase_shifts += 1
	var phase: int = int(boss_node.boss_phase)
	boss_node.trigger_boss_stomp(0.5)
	spawn_burst(boss_node.global_position, GamePalette.RED, 34, 300.0, 0.9)
	_spawn_boss_telegraph(boss_node.global_position, float(boss_node.radius) * 3.2, 0, GamePalette.RED, 0.55, 0.0)
	shake_camera(11.0, 0.5)
	play_sound("boss", -3.0)
	_show_banner("페이즈 %d — %s의 움직임이 빨라집니다 (예비 동작 ×%.2f · 피해 ×%.2f)" % [
		phase, String(stage_boss_profile.get("name", "보스")),
		pow(GameTuning.STAGE_BOSS_PHASE_TELEGRAPH_MUL, float(phase)), pow(GameTuning.STAGE_BOSS_PHASE_DAMAGE_MUL, float(phase))
	], GamePalette.RED, 2.6)

func stage_boss_phase_damage_mul() -> float:
	if not is_instance_valid(stage_boss):
		return 1.0
	return pow(GameTuning.STAGE_BOSS_PHASE_DAMAGE_MUL, float(stage_boss.boss_phase))

func stage_boss_phase_telegraph_mul() -> float:
	if not is_instance_valid(stage_boss):
		return 1.0
	return pow(GameTuning.STAGE_BOSS_PHASE_TELEGRAPH_MUL, float(stage_boss.boss_phase))

# -----------------------------------------------------------------------------
# 격파 → 보상 훅 → 스테이지 전환 → (5스테이지면) 마왕 직행
# -----------------------------------------------------------------------------
# `enemy._die()`가 여기로 갈라 준다. `combat_resolver._enemy_defeated_body()`는
# `is_boss`면 무조건 `_finish_run(true)`를 부르는데(마왕 기준 v2 코드) 그 파일이
# V6 확정이라, **스테이지 보스만 enemy 쪽에서 분기**시켰다(enemy.gd `_die()` 주석).
func on_stage_boss_defeated(boss_node: Node) -> void:
	if stage_boss_defeat_handled:
		return
	stage_boss_defeat_handled = true
	var boss_position: Vector2 = boss_node.global_position if is_instance_valid(boss_node) else player.global_position
	var boss_name := String(stage_boss_profile.get("name", "보스"))
	var was_valve := stage_boss_from_valve
	spawn_burst(boss_position, GamePalette.YELLOW, 52, 380.0, 1.2)
	# Y7(§7.1): 격파는 착탄이 아니다. 52조각 버스트와 승리 소리가 남는다(흔들림 제거).
	play_sound("win", -3.0)
	stage_boss_cleared = true
	_teardown_stage_boss()
	# --- 보상 훅 → **V8: 트로피 2택1**(설계 §5.5 · 부록 B V8 ②) --------------
	pending_stage_trophy = {
		"stage": clock.stage,
		"design": String(stage_boss_profile.get("design", "")),
		"enhanced": bool(stage_boss_profile.get("enhanced", false)),
		"descended": was_valve,
		"day": clock.day_number,
		"dwell": clock.dwell
	}
	_show_banner("%s 격파 · 트로피 둘 중 하나 · 완전 회복 후 다음 관문" % boss_name, GamePalette.YELLOW, 3.2)
	# --- 전환 --------------------------------------------------------------
	# V5의 `advance_stage()`가 여기서 불린다(진입=클리어 임시 배선의 정식 자리).
	# 완전 회복·보스문 표시·dwell ×0.5 감쇠·총 일수 이월은 전부 그 함수가 한다.
	#
	# 트로피 모달을 **전환 뒤에** 여는 이유: `advance_stage()`가 클럭 시그널로
	# 월드 재생성까지 동기 실행하는 한 덩어리라, 그 사이에 모달을 끼우면 재생성이
	# 모달 위에서 일어난다. 전환을 먼저 끝내고 다음 프레임에 모달을 덮으면 순서가
	# 눈에 보이지 않는다(모달 dim이 α0.96이다).
	state = "playing"
	var advanced := advance_stage()
	# **5스테이지 격파 → 필드 복귀 없이 마왕전**(부록 A-1 ③). 단, 트로피(§5.5의 5회
	# 지급)를 먼저 받는다 — 마왕 프리뷰를 여기서 열면 트로피 모달이 통째로 덮인다.
	pending_trophy_followup = "demon" if (advanced and clock.is_run_complete()) else ""
	call_deferred("_open_stage_trophy_choice")

## 보스 전투에 딸린 노드·HUD·상태를 전부 되돌린다. 격파와 스테이지 개시가 함께 쓴다.
func _teardown_stage_boss() -> void:
	if is_instance_valid(stage_boss_cycle):
		stage_boss_cycle.reset_cycle()
		stage_boss_cycle.queue_free()
	stage_boss_cycle = null
	if is_instance_valid(stage_boss):
		stage_boss.queue_free()
	stage_boss = null
	stage_boss_from_valve = false
	_clear_stage_boss_pools()
	StatusEngine.clear(player_status)
	boss_rail_bound_cycle = null
	boss_reload_open = false
	if is_instance_valid(boss_panel):
		boss_panel.visible = false
	if is_instance_valid(boss_rail_band):
		boss_rail_band.visible = false

func _clear_stage_boss_pools() -> void:
	for pool: Node in stage_boss_pools:
		if is_instance_valid(pool):
			pool.queue_free()
	stage_boss_pools.clear()

## 지금 스테이지 보스와 싸우는 중인가. HUD·입력·사이클 게이트가 묻는다.
func stage_boss_active() -> bool:
	return is_instance_valid(stage_boss) and not stage_boss.dead

# =============================================================================
# V7: telegraph(선딜) 표시 — V3 링 시트 3행 (설계 §3.3 · handoff-v3-assets §13-3)
# =============================================================================
# **정적 확장 / 충전 / 장판**을 프레임 애니로 훑는 1회성 노드다. 트윈을 쓰지 않는다
# (설계 §4.8의 "1회성 정적 강조" 규칙 · 프레임 애니는 허용).
#   행 0 `expand`  파동형 — A 서리 발구름, B 도약 압살, B+ 역병 파열
#   행 1 `charge`  선딜 진행도 — A 빙주 낙하 ×3, C 화염 강하, B 분열
#   행 2 `pool`    잔류 장판 — B 산성 분비(8초), C 기름 도포, C+ 흑염 회오리(3초)
#
# 노드가 `lead`초 동안 차오르고 **그 순간에** `impact`를 한 번 부른다. 잔류 장판이면
# 이어서 `tick_interval`마다 `pool_tick`을 부르며 `linger`초를 산다.
# 판정과 표시가 **같은 노드의 같은 좌표·같은 반경**을 쓰므로 "링이 뜬 자리가 곧 착탄점"이다.
class BossTelegraph:
	extends Node2D

	const SHEET := preload("res://art/v2/vfx-telegraph-ring.png")
	const CELL := 128.0

	var row := 0
	var tint := Color.WHITE
	var radius := 120.0
	var lead := 0.5
	var linger := 0.0
	var tick_interval := 0.5
	var elapsed := 0.0
	var fired := false
	var tick_accum := 0.0
	var payload: Dictionary = {}
	var impact: Callable = Callable()
	var pool_tick: Callable = Callable()
	## 0이 아니면 선형(관통·활공) 표시를 함께 그린다. 로컬 좌표계의 끝점이다.
	var line_end := Vector2.ZERO

	func _ready() -> void:
		# 바닥 표시라 캐릭터(마물 3 · 보스 7 · 플레이어 10)보다 아래에 깐다.
		# 보스가 링을 가리면 선딜을 보고도 피할 수 없다 — 이 z가 telegraph의 전제다.
		z_index = 2
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		queue_redraw()

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if not fired:
			if elapsed < lead:
				return
			fired = true
			if impact.is_valid():
				impact.call(self)
			if linger <= 0.0:
				# 착탄 잔상 0.22초. 링이 판정과 같은 프레임에 사라지면 뭐에 맞았는지 안 보인다.
				linger = 0.22
				pool_tick = Callable()
			return
		if pool_tick.is_valid():
			tick_accum += delta
			if tick_accum >= tick_interval:
				tick_accum = 0.0
				pool_tick.call(self)
		if elapsed >= lead + linger:
			queue_free()

	func _draw() -> void:
		var progress := 1.0 if fired else clampf(elapsed / maxf(lead, 0.001), 0.0, 1.0)
		var frame := 7 if fired else clampi(int(progress * 8.0), 0, 7)
		var box := Vector2.ONE * radius
		draw_texture_rect_region(SHEET, Rect2(-box, box * 2.0),
			Rect2(float(frame) * CELL, float(row) * CELL, CELL, CELL),
			Color(tint, 0.85 if not fired else 0.5))
		if line_end != Vector2.ZERO:
			draw_line(Vector2.ZERO, line_end, Color(tint, 0.30 + progress * 0.28), 12.0)

func _spawn_boss_telegraph(center: Vector2, radius: float, row: int, tint: Color,
		lead: float, linger: float = 0.0) -> Node2D:
	if not is_instance_valid(gameplay_root):
		return null
	var node := BossTelegraph.new()
	node.radius = maxf(24.0, radius)
	node.row = row
	node.tint = tint
	node.lead = maxf(0.05, lead)
	node.linger = maxf(0.0, linger)
	node.position = center
	gameplay_root.add_child(node)
	stage_boss_telegraphs += 1
	return node

# =============================================================================
# V7: 보스 패턴 실행 (설계 §3.3 표 · boss_library.PATTERNS)
# =============================================================================
# **왜 game.gd가 직접 실행하는가.** `CycleSkillEffect`는 스텝이 시작하는 순간(elapsed≈0)에
# 판정을 낸다 — 그 구조에서는 telegraph(선딜)가 물리적으로 불가능하다. 설계 §3.3은
# 패턴마다 0.35~1.20초의 선딜을 명시했고 그것이 보스전 공략 문법의 절반이므로,
# 스테이지 보스 카드는 `kind`를 `boss_pattern`으로 바꿔 v2 보스 피해 경로를 **비우고**
# (`_trigger_boss_cycle_pulse()`의 `match`에 없는 값 → no-op) 여기서 telegraph → 착탄
# 순서로 다시 낸다. 사이클·레일·RELOAD는 그대로 `DealCycleController`가 돌린다.
func _launch_stage_boss_pattern(actor: Node2D, card: Dictionary) -> void:
	if not is_instance_valid(actor) or actor != stage_boss or not is_instance_valid(player):
		return
	if stage_boss.boss_intro_playing():
		return
	var lead := maxf(0.12, float(card.get("telegraph", 0.5)) * stage_boss_phase_telegraph_mul())
	var tint := Color(String(card.get("color", "f4d35e")))
	var form := String(card.get("form", "wave"))
	var linger := float(card.get("lingering", 0.0))
	var radius := _stage_boss_pattern_radius(card)
	stage_boss.trigger_boss_attack_anim(lead + 0.2)
	if form == "wave" and String(card.get("element", "")) == "ice":
		# A의 공격은 팔이 아니라 **발구름**이다(설계 §3.1 — Attack 행이 없는 리그).
		stage_boss.trigger_boss_stomp(lead)
	# 행 선택: 잔류·도포는 `pool`, 예고 원과 돌진은 `charge`, 나머지 파동은 `expand`.
	var row := 0
	if linger > 0.0 or bool(card.get("paints_ground", false)):
		row = 2
	elif form in ["trap", "pierce", "slash", "guard"]:
		row = 1
	for center: Vector2 in _stage_boss_pattern_points(card, actor):
		var node := _spawn_boss_telegraph(center, radius, row, tint, lead, linger)
		if node == null:
			continue
		node.payload = {"card": card.duplicate(true), "radius": radius}
		node.impact = _on_stage_boss_impact
		if form in ["pierce", "slash"]:
			node.line_end = actor.global_position.direction_to(player.global_position) * float(card.get("range", 320.0))
			node.position = actor.global_position

func _stage_boss_pattern_radius(card: Dictionary) -> float:
	var radius := float(card.get("range", 200.0))
	if bool(card.get("arena_wide", false)) and is_instance_valid(world):
		radius = maxf(radius, world.boss_gate_radius * 0.92)
	if String(card.get("form", "")) in ["trap", "pierce", "slash"]:
		# 예고 원·선형은 반경이 아니라 **폭**이다. 전체 사거리를 원으로 깔면 회피가 불가능해진다.
		radius = clampf(radius * 0.42, 70.0, 240.0)
	return radius

## 착탄점 목록. `random_impacts`면 시전 시점의 플레이어 주변에 `hits`개를 흩뿌린다.
## **시전 시점에 고정된다** — telegraph 동안 플레이어를 따라다니면 선딜이 무의미해진다.
func _stage_boss_pattern_points(card: Dictionary, actor: Node2D) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var form := String(card.get("form", "wave"))
	if bool(card.get("arena_wide", false)) or form in ["wave", "guard"]:
		points.append(actor.global_position)
		if bool(card.get("paints_ground", false)):
			# C1 기름 날개: 부채꼴로 바닥을 칠한다. 링 하나로는 "도포"가 안 읽힌다.
			var facing := actor.global_position.direction_to(player.global_position)
			var arc := float(card.get("arc", 2.2))
			for index in 3:
				var angle := (float(index) - 1.0) * arc * 0.34
				points.append(actor.global_position + facing.rotated(angle) * float(card.get("range", 300.0)) * 0.62)
		return points
	if form in ["pierce", "slash"]:
		points.append(actor.global_position)
		return points
	var spots := maxi(1, int(card.get("hits", 1))) if bool(card.get("random_impacts", false)) else 1
	for index in spots:
		var offset := Vector2.ZERO
		if index > 0:
			offset = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(90.0, 215.0)
		var candidate: Vector2 = player.global_position + offset
		points.append(candidate)
	return points

func _on_stage_boss_impact(node: Node) -> void:
	if not is_instance_valid(node) or not is_instance_valid(player):
		return
	# 보스가 telegraph 도중에 죽으면 착탄은 취소된다. **격파 후 1초 사이에 유령
	# 패턴이 플레이어를 죽이는 것**이 이 가드가 막는 유일한 사고다(링은 잔상만 남는다).
	if not stage_boss_active():
		return
	var card: Dictionary = (node.payload as Dictionary).get("card", {})
	var radius := float((node.payload as Dictionary).get("radius", 160.0))
	var center: Vector2 = node.global_position
	spawn_burst(center, Color(String(card.get("color", "f4d35e"))), 10, 130.0, 0.3)
	# --- 분열(B3): 원소도 상태도 없는 유일한 패턴. 소환 자체가 효과다 -----------
	var summon_count := int(card.get("summon_count", 0))
	if summon_count > 0:
		_spawn_stage_boss_summons(card, center)
	# --- 흑염 회오리(C4): 남은 기름 장판을 전부 인화시킨다 ----------------------
	var ignition_bonus := 0.0
	if bool(card.get("ignites_ground_oil", false)):
		ignition_bonus = _ignite_stage_boss_oil(center, radius)
	# --- 기름 도포(C1) · 잔류 장판(B2/C4)은 노드가 pool 모드로 남아 스스로 틱한다 --
	if float(card.get("lingering", 0.0)) > 0.0 or bool(card.get("paints_ground", false)):
		node.pool_tick = _on_stage_boss_pool_tick
		# 수명이 다한 장판 참조를 여기서 걷어낸다. 8초 장판 ×3을 60초 동안 깔면 배열이
		# 100칸 넘게 늘어나는데, 인화(C4)가 그걸 매번 훑는다.
		for index in range(stage_boss_pools.size() - 1, -1, -1):
			if not is_instance_valid(stage_boss_pools[index]):
				stage_boss_pools.remove_at(index)
		if not stage_boss_pools.has(node):
			stage_boss_pools.append(node)
	var reaches: bool = bool(card.get("arena_wide", false)) \
		or player.global_position.distance_to(center) <= radius + 18.0
	if String(card.get("form", "")) in ["pierce", "slash"]:
		# 선형은 원이 아니라 선분 판정이다. 노드 원점에서 `line_end`까지의 최단거리를 본다.
		var segment_end: Vector2 = center + (node.line_end as Vector2)
		reaches = _point_to_segment_distance(player.global_position, center, segment_end) <= radius * 0.6 + 20.0
	if not reaches and ignition_bonus <= 0.0:
		return
	var damage := stage_boss_pattern_damage(card) + ignition_bonus
	# 조건부 배율(§3.3 A-3: "플레이어가 chill 상태면 피해 ×1.6").
	var conditional := String(card.get("conditional_status", ""))
	if conditional != "" and StatusEngine.has(player_status, conditional):
		damage *= float(card.get("conditional_damage_mul", 1.0))
		show_world_text(player.global_position - Vector2(0.0, 62.0), "얼어붙은 곳에 벼락", GamePalette.YELLOW, 17)
	# 스택 보너스(§3.3 B-4: "몸에 쌓인 독 스택만큼 더 아프다").
	var per_stack := float(card.get("bonus_per_player_stack", 0.0))
	if per_stack > 0.0:
		damage *= 1.0 + per_stack * float(StatusEngine.stacks(player_status))
	_strike_player_with_pattern(card, damage, center)

## 패턴 damage 1.0이 실제로 만드는 피해. 마왕 식과 자릿수를 맞춘 **뼈대**다(V10 확정).
## dwell 항을 넣지 않은 이유는 HP와 같다 — 오래 머문 플레이어를 두 번 벌하지 않는다.
func stage_boss_pattern_damage(card: Dictionary) -> float:
	var base := maxf(0.0, float(card.get("damage", 1.0)))
	var scale := GameTuning.STAGE_BOSS_DAMAGE_PER_POINT + float(clock.day_number) * GameTuning.STAGE_BOSS_DAMAGE_DAY_STEP
	return base * scale * clock.stage_damage_base() * stage_boss_phase_damage_mul()

## 보스 → 플레이어 한 방. `strike_enemy_with_card()`와 **같은 순서**를 쓴다(§4.4):
## ① 직격 보정(기름 증폭 · 전 소모)  ② 매트릭스  ③ 직격 피해
func _strike_player_with_pattern(card: Dictionary, damage: float, origin: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var element := String(card.get("element", ""))
	var dealt := damage
	var result: Dictionary = {}
	if not element.is_empty():
		dealt *= StatusEngine.incoming_multiplier(player_status, element)
	dealt *= StatusEngine.consume_shock(player_status)
	if not element.is_empty():
		result = StatusEngine.apply(player_status, element, 1.0, {
			"damage": damage, "potency": 1.0, "depth": 0,
			"budget": combat.status_budget if combat != null else {}
		})
	# 패턴 데이터가 명시한 상태(`status` · `status_stacks` · `status_power`)를 보장한다.
	# 매트릭스가 이미 같은 상태를 붙였으면 겹쳐 쓰지 않는다(지속만 갱신되면 충분하다).
	var status_id := String(card.get("status", ""))
	if status_id != "" and not StatusEngine.has(player_status, status_id):
		StatusEngine.set_status(player_status, status_id, {
			"damage": damage, "power": float(card.get("status_power", 1.0)),
			"stacks": int(card.get("status_stacks", 1))
		})
	# §3.4 강화형: "부여 상태이상 1종 → 2종 동시". 보조 상태는 절반 세기로 얹는다.
	var secondary := String(card.get("status_secondary", ""))
	if secondary != "":
		StatusEngine.set_status(player_status, secondary, {"damage": damage * 0.5})
	# 매트릭스가 낸 광역 피해(역병 발화 등)는 대상이 플레이어 자신이다.
	for entry in (result.get("events", []) as Array):
		var event: Dictionary = entry
		if String(event.get("kind", "")) == StatusEngine.E_AOE_DAMAGE:
			dealt += float(event.get("damage", 0.0))
	if not (result.get("reactions", []) as Array).is_empty():
		spawn_synergy_effect(player.global_position, String((result["reactions"] as Array)[0]))
	if dealt > 0.0:
		player.take_damage(dealt, origin)
	_update_hud()

## 잔류 장판 1틱(0.5초). 독장판·흑염은 피해 + 상태, 기름 도포는 상태만 남긴다.
func _on_stage_boss_pool_tick(node: Node) -> void:
	if not is_instance_valid(node) or not is_instance_valid(player):
		return
	var card: Dictionary = (node.payload as Dictionary).get("card", {})
	var radius := float((node.payload as Dictionary).get("radius", 160.0))
	if player.global_position.distance_to(node.global_position) > radius + 12.0:
		return
	var tick_damage := stage_boss_pattern_damage(card) * 0.28
	_strike_player_with_pattern(card, tick_damage, node.global_position)

## C4가 남은 기름 장판을 태운다. 태운 장판 하나당 추가 피해를 돌려주고 노드를 정리한다.
func _ignite_stage_boss_oil(center: Vector2, radius: float) -> float:
	var bonus := 0.0
	for index in range(stage_boss_pools.size() - 1, -1, -1):
		var pool: Node = stage_boss_pools[index]
		if not is_instance_valid(pool):
			stage_boss_pools.remove_at(index)
			continue
		var pool_card: Dictionary = (pool.payload as Dictionary).get("card", {})
		if not bool(pool_card.get("paints_ground", false)):
			continue
		if pool.global_position.distance_to(center) > radius + float(pool.radius):
			continue
		bonus += stage_boss_pattern_damage(pool_card) * 2.0
		spawn_burst(pool.global_position, GamePalette.ORANGE, 14, 180.0, 0.4)
		stage_boss_pools.remove_at(index)
		pool.queue_free()
	if bonus > 0.0:
		show_world_text(center - Vector2(0.0, 70.0), "남은 기름이 인화됐다", GamePalette.ORANGE, 18)
	return bonus

## B3 분열: 소형 점액 `summon_count`기. `summon_hp_ratio`는 **보스 최대 체력** 기준이다.
func _spawn_stage_boss_summons(card: Dictionary, center: Vector2) -> void:
	if combat == null or not is_instance_valid(stage_boss):
		return
	var count := clampi(int(card.get("summon_count", 3)), 1, 6)
	var ratio := clampf(float(card.get("summon_hp_ratio", 0.12)), 0.01, 0.5)
	var summon_status := String(card.get("summon_status", ""))
	for index in count:
		var angle := TAU * float(index) / float(count) + rng.randf() * 0.4
		var spawn_point := center + Vector2.from_angle(angle) * 96.0
		if not world.is_walkable(spawn_point):
			spawn_point = world.find_walkable_near(center, rng, 80.0, 170.0)
		var minion: Node2D = combat.spawn_enemy_instance(spawn_point, 2, "", true)
		if not is_instance_valid(minion):
			continue
		minion.max_health = maxf(6.0, stage_boss.max_health * ratio)
		minion.health = minion.max_health
		minion.displayed_health = minion.health
		minion.trailing_health = minion.health
		minion.visual_variant = "ooze"
		minion.display_name = "점액 조각"
		minion.aggro = true
		if summon_status != "":
			# 소환된 개체가 **독을 지니고 나온다**(설계 §3.3 B-3).
			StatusEngine.set_status(minion.st_state, summon_status, {"damage": minion.max_health * 0.02})
		minion.queue_redraw()
	show_world_text(center - Vector2(0.0, 74.0), "분열", GamePalette.MAGENTA, 19)

func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var length_squared := span.length_squared()
	if length_squared < 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
	return point.distance_to(a + span * t)

# =============================================================================
# V7: 플레이어 상태이상 틱 (설계 §3.3 "상태이상은 나에게도 쌓인다")
# =============================================================================
# ⚠️ **도트를 `player.take_damage()`로 그냥 흘리면 안 된다.** 그 함수는 피격마다
#    0.68초 무적을 준다 — 초당 4회 도트를 그대로 태우면 **불붙은 플레이어가 보스
#    패턴에 거의 무적이 된다.** 그래서 ①0.6초로 모아서 한 번에 내고 ②호출 전후로
#    무적 시간을 원래 값으로 되돌린다. 대시·스폰 무적은 그대로 도트를 막는다
#    (StatusEngine이 도트를 별도 source로 두는 설계와 같은 판단).
# ⚠️ V10(2026-08-09 · handoff-v7 §12-2 판정): 같은 이유로 **수호막도 건너뛴다.**
#    V7까지는 도트 플러시가 `shield_charges`를 먹었다 — 6초 독 하나가 플러시 10번이라
#    수호막 상한(6)을 통째로 태웠고, 하필 독이 주 무기인 B·B+ 보스전에서만
#    "수호막 +1" 트로피 2종이 무의미해졌다. `ignore_shield=true` 한 인자로 닫았다.
const PLAYER_DOT_FLUSH_INTERVAL := 0.6
var player_dot_flush_timer := 0.0

func _tick_player_status(delta: float) -> void:
	if not StatusEngine.is_state(player_status):
		player_dot_flush_timer = 0.0
		return
	player_status_dot_total += StatusEngine.tick_dot(player_status, delta)
	player_dot_flush_timer += delta
	if player_dot_flush_timer < PLAYER_DOT_FLUSH_INTERVAL:
		return
	player_dot_flush_timer = 0.0
	var pending := player_status_dot_total
	player_status_dot_total = 0.0
	if pending <= 0.0 or not is_instance_valid(player):
		return
	var invulnerability_before: float = player.invulnerability
	if invulnerability_before > 0.0:
		return
	player.take_damage(pending, Vector2.ZERO, true)
	player.invulnerability = invulnerability_before

## 플레이어에게 걸린 상태의 한글 요약. 보스 패널이 한 줄로 보여 준다.
func player_status_label() -> String:
	var active := StatusEngine.active_list(player_status)
	if active.is_empty():
		return ""
	var names: Array[String] = []
	for status: String in active:
		names.append(_status_short_name(status))
	return " · ".join(names)

func _status_short_name(status: String) -> String:
	match status:
		"poison": return "독"
		"burn": return "연"
		"chill": return "한"
		"oil": return "유"
		"shock": return "전"
	return status

func _open_chest(feature: Dictionary) -> void:
	var feature_id: String = feature["id"]
	var feature_position: Vector2 = feature["position"]
	if opened_features.has(feature_id):
		return
	opened_features[feature_id] = true
	world.set_opened_features(opened_features)
	current_interactable.clear()
	interaction_text.visible = false
	var opening_effect := CHEST_OPEN_EFFECT_SCRIPT.new()
	opening_effect.position = feature_position
	gameplay_root.add_child(opening_effect)
	play_sound("chest", -1.0)
	if not automated_test:
		await get_tree().create_timer(0.34).timeout
	spawn_burst(feature_position, GamePalette.YELLOW, 18, 170.0, 0.45)
	# === Y6: 배당 재조정 (§6.4 · 피드백 ㉓ "상자에서 체력도 회복되게") ============
	# 신설 두 칸 — **체력 회복 7** · **재미 아이템 6**. 위협 총량은 21% → **18%**로
	# 내린다(저주 7→6 · 함정 8→7 · 미믹 6→5). 상자가 "열면 손해일 수도"라는 인상을
	# 주면 발견 기반 내비의 동기가 약해진다는 것이 §6.4의 논지다.
	#
	# ⚠️ **문서 §6.4의 새 열은 합이 100이 아니라 106이다**(14+13+16+15+14+7+6+6+7+5+3).
	#    구 열은 정확히 100이었으므로 신설 두 칸을 더하면서 다른 칸을 그만큼 못 뺀
	#    산수 착오다. 여기서는 문서가 **명시적으로 주장한 것**을 전부 지키고
	#    (위협 18% · 체력 7 · 재미 6 · 각인 14는 X1이 정한 값) 남은 6%p를
	#    보상 네 칸에서 고르게 뺐다: 골드 14→13 · 경험 13→12 · 스킬 16→14 · 아이템 15→13.
	#   골드 13 · 경험 12 · 스킬 14 · 아이템 13 · 각인 14 · **체력 7** · **재미 6** ·
	#   저주 6 · 함정 7 · 미믹 5 · 빈 3 = **100**
	# 배당표는 **`CHEST_TABLE` 하나가 정본**이다(아래 Y6 절). 임계값을 여기서 다시
	# 손으로 적으면 표와 코드가 갈라진다 — `--event-test`가 표의 합 100을 문다.
	#
	# ── YZ(2026-08-10): 골드 두 칸에 스테이지 스케일을 붙였다 (handoff-y8 §9 ④) ──
	# Y8이 "의도인지 누락인지 모르겠다"로 남긴 건이다. **누락으로 판정했다.**
	#   * 사건 보상(`_finish_event()`) · 안전 상자(`_grant_safe_chests()`) · 상점가
	#     (`_scaled_price()`)가 전부 `stage_price_scale()`을 탄다. 필드 상자만 안 탔다.
	#   * 그래서 **같은 게임 안에서 상자 둘이 다르게 굴렀다** — 「보물섬」이 깔아 주는
	#     상자는 5스테이지에서 2배를 주는데 바로 옆 필드 상자는 1스테이지 값을 줬다.
	# 유입 재산정(STAGE_PRICE_STEP 0.25 · 스케일 합 1.00+1.25+1.50+1.75+2.00 = 7.50):
	#   상자 1개 기대 골드 = 0.13×30 + 0.06×53 = **7.08 G** (balance_probe와 같은 식)
	#   8개/st × 5st 평탄 283 G → 스케일 425 G → **+142 G**
	#   총수입 2,834 → 2,976 G · 완전지출 2,271 G · 여유 19.9% → **23.7%** (목표 15~30%)
	# ⚠️ `balance_probe.gd`의 `FIELD_CHEST_GOLD` 주석·⑧ 합산은 아직 "안 곱한다"로 적혀
	#    있다. 프로브를 소유한 웨이브가 그 두 자리(972~973 · 999~1000)를 갱신해야
	#    리포트가 다시 코드와 맞는다. 판정 게이트는 아니라 지금 빨개지지는 않는다.
	var chest_scale := stage_price_scale()
	match chest_slice_for(rng.randi_range(0, 99)):
		"gold":
			var reward := int(round(float(rng.randi_range(18, 42)) * chest_scale))
			gold += reward
			# Y6: `ui-coin-spin.png` 배선(handoff-y4 §9-C). 4프레임 1회 재생 후 사라진다.
			_spawn_coin_spin(feature_position)
			_show_banner("보물상자 · %d G 획득" % reward, GamePalette.YELLOW, 2.3)
		"xp":
			var xp_reward := rng.randi_range(5, 11)
			_show_banner("보물상자 · 경험의 수정 %d" % xp_reward, GamePalette.CYAN, 2.3)
			collect_xp(xp_reward)
		"skill":
			_show_banner("보물상자 · 봉인된 기술", GamePalette.MAGENTA, 1.3)
			call_deferred("_show_skill_choice", "chest")
		"item":
			call_deferred("_show_item_offer", "treasure")
		"rune":
			# v1은 레일 부품, W2는 45 G 환전이었다. W6부터는 **각인 상자**다(§8.3).
			_show_banner("보물상자 · 봉인된 각인", GamePalette.MAGENTA, 1.3)
			call_deferred("_show_rune_draft", "chest", "playing")
		"heal":
			# Y6 신설(피드백 ㉓) — 상자에서 체력이 나온다. 「회복의 빵」과 같은 40%다.
			player.heal(player.max_health * BREAD_HEAL_RATIO)
			spawn_burst(feature_position, GamePalette.GREEN, 22, 210.0, 0.55)
			_show_banner("보물상자 · 체력 %d%% 회복" % int(BREAD_HEAL_RATIO * 100.0), GamePalette.GREEN, 2.3)
		"fun":
			# Y6 신설 — 재미 아이템 한 개(§6.3). 칸이 차 있으면 바꿀지 묻는다.
			_grant_consumable(_roll_consumable())
		"curse":
			var cursed_reward := int(round(float(rng.randi_range(38, 68)) * chest_scale))
			gold += cursed_reward
			# W12: `SKILLS` 28종(legacy 8종 포함)에서 뽑고 있었다. 저주 상자는 마왕에게
			# 카드를 **주는** 경로이므로 handoff-w7 §8의 규칙("새 카드를 주는 모든 경로는
			# draft_pool()")이 그대로 적용된다.
			var curse_pool := DealCardLibrary.draft_pool()
			var curse: Dictionary = curse_pool[rng.randi_range(0, curse_pool.size() - 1)]
			rejected_skills.append(curse["id"])
			_show_banner("저주받은 보물 +%d G · 마왕이 가져간 것 · %s" % [cursed_reward, curse["name"]], GamePalette.RED, 3.0)
		"trap":
			_show_banner("함정! 체력 24 피해", GamePalette.RED, 2.2)
			player.take_damage(24.0, feature_position)
		"mimic":
			_show_banner("가짜 상자! 마물이 튀어나왔습니다", GamePalette.RED, 2.4)
			# 미믹은 플레이어가 상자를 열어서 발동시킨 함정이므로 낮 선공몹 게이트를 건너뛴다.
			var mimic := combat.spawn_enemy_instance(feature_position, 4, "overclock", false, "", false, "", true)
			if is_instance_valid(mimic):
				mimic.set_night_raid(true)
		_:
			_show_banner("빈 상자 · 누군가 먼저 다녀갔습니다", GamePalette.MUTED, 2.3)
	_update_hud()

func _show_item_offer(source: String = "treasure") -> void:
	if state not in ["playing", "castle_interior"]:
		return
	item_return_state = state
	current_item_pair.assign(_roll_item_pair())
	if current_item_pair.size() != 2:
		return
	state = "item_choice"
	get_tree().paused = true
	_clear_overlay()
	_show_item_offer_pair(current_item_pair, source)

func _roll_item_pair() -> Array[Dictionary]:
	var character_id := player.character_id if is_instance_valid(player) else "swordsman"
	var first := ItemLibrary.random_item(rng, "", character_id)
	var second := first
	for _attempt in 16:
		second = ItemLibrary.random_item(rng, "", character_id)
		if String(second.get("id", "")) != String(first.get("id", "")):
			break
	var pair: Array[Dictionary] = [first.duplicate(true), second.duplicate(true)]
	return pair

func _show_item_offer_card(item: Dictionary, source: String) -> void:
	# 구버전 진입점(단일 아이템 제안). 새 규칙에 맞춰 짝을 뽑아 이지선다로 표시합니다.
	var partner := item
	var character_id := player.character_id if is_instance_valid(player) else "swordsman"
	for _attempt in 16:
		partner = ItemLibrary.random_item(rng, "", character_id)
		if String(partner.get("id", "")) != String(item.get("id", "")):
			break
	current_item_pair.assign([item.duplicate(true), partner.duplicate(true)])
	_show_item_offer_pair(current_item_pair, source)

func _show_item_offer_pair(pair: Array[Dictionary], source: String) -> void:
	_reset_choice_focus()
	overlay = Control.new()
	overlay.name = "ItemChoice"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 레벨업 모달과 **같은 골격**이다(§7). 톤·리본·본문 띠 위치가 픽셀 단위로 같아서
	# 두 2택 화면이 한 화면의 두 변주로 읽힌다.
	# YZ(피드백 ① · ⑤): 부제 밴드 「가져갈 아이템 카드를 고르세요」를 걷고 그 말을
	# 리본에 붙였다. 아래 규칙 띠는 남긴다 — 「안 고른 카드가 마왕에게 간다」는
	# 카드만 봐서는 알 수 없는 유일한 규칙이라 상시로 보여야 한다.
	var panel := _kit_shell(overlay, CHOICE_MODAL_RECT,
		"성의 대장장이 · 하나 고르기" if source == "armorer" else "보물상자의 전리품 · 하나 고르기",
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 520.0)
	_kit_panel(panel, Rect2(158.0, 74.0, 874.0, 32.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	_kit_label(panel, Rect2(158.0, 74.0, 874.0, 32.0),
		"고른 카드는 보관함으로   ·   안 고른 카드는 마왕에게",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.INSET, HORIZONTAL_ALIGNMENT_CENTER)
	for index in 2:
		var button := _item_choice_button(pair[index])
		button.position = Vector2(55.0 + index * 570.0, 120.0)
		panel.add_child(button)
		_register_choice_button(button, "item", _choose_offered_item.bind(index))
	# 카드 아래(y 372)와 푸터(y 462) 사이에 42px 빈 띠가 남아 skill choice와 리듬이 달랐습니다 (P2-6).
	_kit_panel(panel, Rect2(335.0, 400.0, 520.0, 34.0), UIKit.Tone.SLATE, UIKit.Role.CHIP)
	var storage_note := _label("보관함 %d장 보유   ·   배치는 ESC 딜싸이클 공장에서" % (0 if factory == null else factory.inventory.size()), UI_BODY_SIZE, GamePalette.GREEN)
	storage_note.position = Vector2(335.0, 400.0)
	storage_note.size = Vector2(520.0, 34.0)
	storage_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(storage_note)
	_kit_label(panel, Rect2(0.0, 458.0, CHOICE_MODAL_RECT.size.x, 22.0),
		"← 왼쪽 아이템   ·   → 오른쪽 아이템   ·   SPACE 결정",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 18.0))
	_set_choice_index(0)
	play_sound("choice", -2.0)
	if automated_test:
		call_deferred("_choose_offered_item", 0)

func _item_choice_button(item: Dictionary, card_size: Vector2 = CHOICE_CARD_SIZE) -> Button:
	# ⑳ 아이템 2지선다도 스킬과 같은 골격 · 같은 카드 블록을 쓴다.
	var rarity := String(item.get("rarity", "common"))
	var rarity_color := ItemLibrary.rarity_color(rarity)
	var slot_name := _item_slot_korean(String(item.get("slot", "weapon")))
	# Y4: `item["id"]`를 그대로 읽으면 **사전에 없는 id 하나가 모달 전체를 죽인다.**
	# 교체 확인 화면이 낀 장비를 되읽으면서 이 경로에 처음으로 임의 id가 들어왔다 —
	# 함수 하나가 죽으면 `null`이 반환되고 호출부의 `.name =`이 연쇄로 터진다(실측).
	var item_id := String(item.get("id", ""))
	var owned := 0 if factory == null else factory.get_total_count(item_id)
	var button := _button("", rarity_color, card_size)
	# U2 v3: 아이템은 킷 ITEM 프레임(SLATE · 상자 문양). 희귀도는 §6의 규칙대로
	# 테두리가 아니라 **이름·태그 글자색**으로만 나른다.
	_kit_card_skin(button, 1)
	button.set_meta("owned_text", "%d장 보유중" % owned)
	var reload_cut := ItemLibrary.global_reload_reduction(item)
	var reload_text := "지속시간 없음 · 칸을 즉시 통과"
	if reload_cut > 0.0:
		reload_text = "전체 RELOAD  -%d%%" % int(round(reload_cut * 100.0))
	# Y4(피드백 ⑫): 부위 이름은 태그 줄에서 뺐다 — **카드 폭 절반짜리 머리 배지**가 됐다.
	# 아이템 카드를 보고 유저가 가장 먼저 답해야 하는 질문이 "어디에 끼는가"인데,
	# 그 답이 「고급 · 팔찌」처럼 등급과 같은 줄에 작게 붙어 있었다.
	var tag_text := "%s\n걸리는 곳  %s" % [ItemLibrary.rarity_name(rarity), ItemLibrary.effect_scope(item)]
	_build_choice_card_body(button, ItemLibrary.instance(item_id), card_size, tag_text, String(item.get("desc", "")), [
		{"text":reload_text, "color":GamePalette.ORANGE if reload_cut > 0.0 else GamePalette.MUTED},
		{"text":"상점 가치 %d G" % ItemLibrary.price_for(item), "color":GamePalette.YELLOW},
		{"text":String(button.get_meta("owned_text", "")), "color":GamePalette.GREEN if owned > 0 else GamePalette.MUTED}
	], "", GamePalette.MAGENTA, String(item.get("slot", "weapon")))
	return button

func _store_item_card(item: Dictionary) -> bool:
	if factory == null or item.is_empty():
		return false
	var before := factory.inventory.size()
	factory.add_inventory(ItemLibrary.instance(String(item["id"])))
	return factory.inventory.size() > before

func _choose_offered_item(index: int) -> void:
	if state != "item_choice" or current_item_pair.size() != 2:
		return
	var picked := clampi(index, 0, 1)
	var chosen: Dictionary = (current_item_pair[picked] as Dictionary).duplicate(true)
	var passed: Dictionary = (current_item_pair[1 - picked] as Dictionary).duplicate(true)
	current_item_pair.clear()
	var stored := _store_item_card(chosen)
	boss_items.append(String(passed["id"]))
	_clear_overlay()
	get_tree().paused = false
	state = item_return_state
	_grant_modal_return_invulnerability()
	var passed_name := String(passed.get("name", "아이템"))
	if stored:
		_show_banner("%s → 카드 보관함에 추가 · %s%s 마왕에게" % [chosen.get("name", "아이템"), passed_name, _particle_eun(passed_name)], GamePalette.GREEN, 3.0)
	else:
		_show_banner("보관함에 넣지 못했습니다 · %s%s 마왕에게" % [passed_name, _particle_eun(passed_name)], GamePalette.RED, 3.0)
	_show_boss_growth_toast([{"id":passed["id"], "name":passed.get("name", "아이템"), "debt_desc":"고르지 않은 아이템 카드가 마왕의 최적 딜싸이클에 추가됩니다."}])
	_update_hud()

func _resolve_item_offer(item: Dictionary, keep: bool) -> void:
	# 구버전 진입점. keep=true는 보관함 직행, keep=false는 마왕 전달입니다.
	# 새 규칙에서는 아이템 획득이 즉시 배치(factory_place)로 이어지지 않습니다.
	if state != "item_choice" or item.is_empty():
		return
	current_item_pair.clear()
	_clear_overlay()
	get_tree().paused = false
	state = item_return_state
	_grant_modal_return_invulnerability()
	if keep:
		if _store_item_card(item):
			_show_banner("%s → 카드 보관함에 추가 · ESC 공장에서 배치" % item.get("name", "아이템"), GamePalette.GREEN, 2.8)
		else:
			_show_banner("보관함에 넣지 못했습니다", GamePalette.RED, 2.4)
	else:
		boss_items.append(String(item["id"]))
		var discarded_name := String(item.get("name", "아이템"))
		_show_banner("%s%s 버림 · 마왕이 가져갔습니다" % [discarded_name, _particle_eul(discarded_name)], GamePalette.RED, 3.0)
		_show_boss_growth_toast([{"id":item["id"], "name":item.get("name", "아이템"), "debt_desc":"아이템 카드가 마왕의 최적 딜싸이클에 추가됩니다."}])
	_update_hud()

func _show_base_camp(castle: Dictionary) -> void:
	# Kept as a compatibility entry point for automated checks and older calls.
	_enter_castle(castle)

# =============================================================================
# W9: 성 NPC 4종 (설계 §7.2 "6종 → 4종")
# =============================================================================
#   card_shop  딜싸이클 카드상 — 드래프트 풀 스킬 카드 + 장비(§5.4)
#   rune_shop  각인 세공사     — 각인 구매(3택1) · 카드 합성(통합) · 칸 배율 강화
#   pact       계약자          — 기한을 사고판다 (§4.4, 각 거래 런당 2회)
#   spy        밀정            — 마왕의 각인을 훔쳐보거나 하나를 지운다
#
# **네 명이 모든 성에 전부 선다.** v1은 6종 중 4개를 뽑았지만, v2는 종류가 정확히 4개라
# 뽑을 것이 없다. 대신 순서를 성 id로 결정적으로 회전시켜 성마다 자리가 달라 보이게 하고,
# 실제 좌표 셔플은 v1 그대로 `castle_interior.setup()`이 같은 해시로 처리한다.
# (v1의 `world_grid.get_castle_services()`는 호출부가 0이 되어 W12가 삭제했다.
#  성 서비스 구성의 단일 소유자는 이제 아래 상수 하나뿐이다.)
const CASTLE_SERVICES_V2: Array[String] = ["card_shop", "rune_shop", "pact", "spy"]

func _castle_services(feature_id: String) -> Array[String]:
	var rotation: int = absi(feature_id.hash()) % CASTLE_SERVICES_V2.size()
	var result: Array[String] = []
	for index in CASTLE_SERVICES_V2.size():
		result.append(CASTLE_SERVICES_V2[(index + rotation) % CASTLE_SERVICES_V2.size()])
	return result

func _enter_castle(castle: Dictionary) -> void:
	if state != "playing" or inside_castle or not is_instance_valid(player):
		return
	_play_scene_transition(_enter_castle_now.bind(castle.duplicate(true)), Color("090d1a"))

func _enter_castle_now(castle: Dictionary) -> void:
	if state != "playing" or inside_castle or not is_instance_valid(player):
		return
	# current_interactable과 같은 Dictionary가 전달될 수 있으므로 먼저 독립 복사합니다.
	# 복사 전에 current_interactable을 clear하면 실제 E 입력 경로에서 성 id가 사라집니다.
	var castle_data := castle.duplicate(true)
	field_return_position = player.global_position
	current_castle = castle_data.duplicate(true)
	inside_castle = true
	# V5: 베이스 캠프는 **성과 완전히 같은 정비 공간**이다(사용자 요구 원문 "성이랑 똑같아").
	# 같은 `castle_interior`를 재사용하고 서비스 4종도 같다 — 다른 것은 입장 문구와
	# 스테이지당 1회 완전 회복(여관 역할 · 설계 §3.6 "추가 1건")뿐이다.
	inside_camp = String(castle_data.get("type", "castle")) == "camp"
	state = "castle_interior"
	current_interactable.clear()
	interaction_text.visible = false
	castle_interior = CASTLE_INTERIOR_SCRIPT.new()
	castle_interior.setup(_castle_services(String(castle_data["id"])), String(castle_data["id"]))
	gameplay_root.add_child(castle_interior)
	_set_field_suspended(true)
	player.global_position = castle_interior.get_spawn_position()
	player.velocity = Vector2.ZERO
	player.dash_time_left = 0.0
	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	canvas_modulate.color = Color.WHITE
	# W5 경계 접촉 1줄: 성에 들어온 프레임에 HUD를 한 번 갱신해 5칸 레일을 끈다.
	# (_process의 castle_interior 분기가 먼저 return하므로 이 호출이 없으면 필드 레일이
	#  성 내부 위에 그대로 남는다 — v1 3칩 HUD가 갖고 있던 같은 결함이다.)
	_update_hud()
	if inside_camp:
		# Y4: 꼬리표는 한 낱말이다 — 「· 보스방 앞」은 `_update_stage_panel()`이 곧바로
		# 덮어쓰던 죽은 문자열이었고, 관문 아이콘이 그 자리를 대신한다(피드백 ⑤).
		phase_text.text = "베이스 캠프"
		phase_text.add_theme_color_override("font_color", GamePalette.GREEN)
		if not camp_rest_used and is_instance_valid(player):
			camp_rest_used = true
			player.health = player.max_health
			player.displayed_health = player.health
			player.trailing_health = player.health
			_on_player_health_changed(player.health, player.max_health)
			_show_banner("베이스 캠프 · 완전 회복(스테이지당 1회) · 상인 넷은 성과 같습니다", GamePalette.GREEN, 3.0)
		else:
			_show_banner("베이스 캠프 · 이번 스테이지의 휴식은 이미 썼습니다 · 정비만 가능", GamePalette.YELLOW, 2.6)
	else:
		phase_text.text = "여행자의 성"
		phase_text.add_theme_color_override("font_color", GamePalette.YELLOW)
		_show_banner("성 안으로 들어왔습니다 · 상인에게 다가가 E", GamePalette.YELLOW, 2.5)
	# X3: 나침반 3줄이 사라졌다. 성·캠프 안에서는 화살표 내비가 통째로 꺼지고
	# (`_update_edge_nav()`의 `not inside_castle`), 그 사실 자체가 "지금은 안이다"를 말한다.
	play_sound("camp", -1.0)

func _set_field_suspended(suspended: bool) -> void:
	if not is_instance_valid(gameplay_root):
		return
	for child: Node in gameplay_root.get_children():
		if child == player or child == castle_interior or child == canvas_modulate:
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT
		if child is CanvasItem:
			(child as CanvasItem).visible = not suspended

func _exit_castle() -> void:
	if not inside_castle or not is_instance_valid(player):
		return
	_play_scene_transition(_exit_castle_now, Color("090d1a"))

func _exit_castle_now() -> void:
	if not inside_castle or not is_instance_valid(player):
		return
	current_interactable.clear()
	interaction_text.visible = false
	_set_field_suspended(false)
	if is_instance_valid(castle_interior):
		castle_interior.queue_free()
	castle_interior = null
	inside_castle = false
	inside_camp = false
	state = "playing"
	player.global_position = field_return_position
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	# 성에서 필드로 나올 때도 모달 복귀와 같은 유예 무적을 준다. 이 함수는 커튼이 완전히
	# 닫힌 순간에 실행되므로 커튼이 다시 열릴 때까지의 시간을 더해 보이는 0.5초를 확보한다.
	player.grant_invulnerability(GameTuning.MODAL_RETURN_INVULN + (GameTuning.SCENE_TRANSITION_TAIL if transition_active else 0.0))
	_update_world_lighting(1.0)
	_update_hud()
	_show_banner("필드로 복귀했습니다", GamePalette.GREEN, 1.8)
	# ── V10(2026-08-09): 성을 나갈 때 1회 저장 (handoff-v9 §3.4 · §9 #7) ────────
	# 성 내부(`castle_interior`)에서는 `_process()`가 맨 위에서 return하므로 5초 주기
	# 자동 저장이 **한 번도 돌지 않는다.** v2부터 있던 구멍이라 카드를 사고 각인을 붙인
	# 뒤 성 안에서 앱이 죽으면 그 거래가 통째로 사라졌다.
	# 여기 한 줄이면 닫힌다 — 이 시점은 `state`가 이미 `"playing"`이고 전투도 열려
	# 있지 않으므로 `run_save_allowed()`가 참이다. 자동 저장 타이머(≤5초)를 기다리지
	# 않고 즉시 쓰는 것이 요점이다.
	_save_run_snapshot()

func _show_single_npc_service(service: String) -> void:
	if state != "castle_interior":
		return
	# v2 4종은 전용 화면을 갖는다. 나머지(v1 잔존)는 아래의 일반 대화 모달을 탄다.
	match service:
		"card_fusion":
			_show_fusion_service()
			return
		"card_shop":
			_show_card_shop(false)
			return
		"factory_mage":
			_show_factory_mage()
			return
		"rune_shop":
			_show_rune_shop()
			return
		"pact":
			_show_pact_service()
			return
		"spy":
			_show_spy_service()
			return
	var info := _service_info(service)
	state = "camp"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "CastleNPCService"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	var panel := _kit_shell(overlay, Rect2(340.0, 120.0, 600.0, 465.0), String(info["name"]),
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 400.0)
	# 대사는 함몰 무대 안에 — 성 NPC 4종이 전부 같은 골격을 쓴다.
	_kit_panel(panel, Rect2(36.0, 52.0, 528.0, 200.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	var dialogue := _label("어서 오게, 여행자.\n%s" % String(info["desc"]), UI_HEADING_SIZE, GamePalette.TEXT)
	dialogue.position = Vector2(55.0, 100.0)
	dialogue.size = Vector2(490.0, 130.0)
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(dialogue)
	var payment := "비용 %d G · 현재 %d G" % [int(info["cost"]), gold]
	var cost_label := _label(payment, UI_BODY_SIZE, GamePalette.YELLOW)
	cost_label.position = Vector2(40.0, 245.0)
	cost_label.size = Vector2(520.0, 32.0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(cost_label)
	var use_button := _button("부탁한다", info["color"], Vector2(220.0, 58.0))
	use_button.position = Vector2(65.0, 320.0)
	use_button.pressed.connect(_use_service.bind(service))
	panel.add_child(use_button)
	var close := _button("대화를 마친다 · ESC", GamePalette.MUTED, Vector2(220.0, 58.0))
	close.position = Vector2(315.0, 320.0)
	close.pressed.connect(_close_base_camp)
	panel.add_child(close)
	_kit_label(panel, Rect2(30.0, 410.0, 540.0, 24.0), "대화를 마치면 성 안으로 돌아갑니다.",
		UIKit.Tone.SLATE, UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	use_button.grab_focus()
	play_sound("choice", -4.0)

func _service_info(service: String) -> Dictionary:
	match service:
		# --- v2 4종 ---
		"card_shop": return {"name":"딜싸이클 카드상", "desc":"스킬 카드와 장비를 팔고\n상품을 새로고침합니다.", "cost":0, "color":GamePalette.CYAN}
		"rune_shop": return {"name":"각인 세공사", "desc":"각인을 팔고, 같은 카드를 합성하고,\n칸 배율을 강화합니다.", "cost":0, "color":GamePalette.ORANGE}
		"pact": return {"name":"계약자", "desc":"머문 밤을 사고팝니다.\n밤이 곧 돈입니다.", "cost":0, "color":GamePalette.MAGENTA}
		"spy": return {"name":"밀정", "desc":"마왕의 각인을 훔쳐보거나\n하나를 지웁니다.", "cost":0, "color":GamePalette.BLUE}
		# --- v1 잔존(NPC로 배치되지 않음 · _use_service 경로만 유지) ---
		"card_fusion": return {"name":"카드 합성 장인", "desc":"같은 카드 같은 등급 두 장을 다음 등급으로 합칩니다.", "cost":0, "color":GamePalette.MAGENTA}
		"factory_mage": return {"name":"레일 강화술사", "desc":"칸 배율 강화 3종을 판매합니다.", "cost":0, "color":GamePalette.ORANGE}
		"merchant": return {"name":"약초 상인", "desc":"체력을 45 회복합니다.", "cost":25, "color":GamePalette.GREEN}
		"skill_remove": return {"name":"망각의 사제", "desc":"가장 최근 기술을 지웁니다.\n지운 힘은 마왕에게 갑니다.", "cost":35, "color":GamePalette.MAGENTA}
		"boss_remove": return {"name":"퇴마사", "desc":"마왕의 최근 기술 하나를\n완전히 봉인합니다.", "cost":60, "color":GamePalette.BLUE}
		"skill_swap": return {"name":"운명의 직조사", "desc":"최근 기술을 무작위 기술로\n교체합니다.", "cost":45, "color":GamePalette.CYAN}
		"armorer": return {"name":"왕실 대장장이", "desc":"장비 아이템 카드를 제안합니다.", "cost":50, "color":GamePalette.ORANGE}
		_: return {"name":"여관 주인", "desc":"체력을 모두 회복합니다.", "cost":30, "color":GamePalette.YELLOW}

func _show_fusion_service() -> void:
	state = "camp"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "CardFusion"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	var panel := _kit_shell(overlay, Rect2(170.0, 60.0, 940.0, 600.0), "카드 합성소 · 두 장을 한 장으로",
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 540.0)
	# 저장 랭크는 1~5를 유지하되 **수치는 R3에서 포화**한다(handoff-w7 §4의 2층 구조).
	_kit_panel(panel, Rect2(34.0, 44.0, 872.0, 34.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	_kit_label(panel, Rect2(46.0, 44.0, 848.0, 34.0),
		"같은 등급 2장 → 다음 등급 1장 · 수치는 R%d부터 더 오르지 않습니다 · 레일에 놓인 카드도 재료에 포함" % DealCardLibrary.MAX_RANK,
		UIKit.Tone.SLATE, UIKit.FONT_BODY, true, UIKit.Role.INSET)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(35.0, 120.0)
	scroll.size = Vector2(870.0, 380.0)
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var candidates := factory.fusion_candidates()
	if candidates.is_empty():
		var empty := _label("지금 합칠 수 있는 카드가 없습니다.\n같은 카드가 두 장 모이면 제가 야무지게 눌러드립니다.", UI_HEADING_SIZE, GamePalette.MUTED)
		empty.custom_minimum_size = Vector2(840.0, 150.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list.add_child(empty)
	for candidate: Dictionary in candidates:
		var definition := DealCardLibrary.by_id(String(candidate["id"]))
		var fusion_color := Color(String(definition.get("color", "f4d35e")))
		var button := _button("", fusion_color, Vector2(840.0, 66.0))
		_kit_card_skin(button, 0)
		var fusion_icon := SKILL_ICON_SCRIPT.new()
		fusion_icon.position = Vector2(18.0, 7.0)
		fusion_icon.size = Vector2(52.0, 52.0)
		fusion_icon.setup(String(candidate["id"]), fusion_color)
		button.add_child(fusion_icon)
		var fusion_text := _label("%s    R%d ×2  →  R%d    ·    현재 %d장" % [definition.get("name", "기술"), int(candidate["rank"]), int(candidate["rank"]) + 1, int(candidate["count"])], UI_HEADING_SIZE, GamePalette.TEXT)
		fusion_text.position = Vector2(82.0, 8.0)
		fusion_text.size = Vector2(730.0, 50.0)
		fusion_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(fusion_text)
		button.pressed.connect(_fuse_card.bind(String(candidate["id"]), int(candidate["rank"])))
		list.add_child(button)
	var close := _button("합성소 나가기 · ESC", GamePalette.MUTED, Vector2(260.0, 48.0))
	close.position = Vector2(340.0, 530.0)
	close.pressed.connect(_close_base_camp)
	panel.add_child(close)
	close.grab_focus()

func _fuse_card(card_id: String, rank: int) -> void:
	if state != "camp" or not factory.fuse(card_id, rank):
		return
	var definition := DealCardLibrary.by_id(card_id)
	_reset_player_cycle()
	_show_banner("합성 완료 · %s R%d" % [definition.get("name", "기술"), rank + 1], GamePalette.MAGENTA, 2.4)
	if state == "camp":
		_show_fusion_service()

func _show_card_shop(refresh: bool = false) -> void:
	var active_castle_id := String(current_castle.get("id", "field_shop"))
	if not refresh and shop_castle_id != active_castle_id:
		shop_refresh_count = 0
		shop_offers.clear()
		shop_castle_id = active_castle_id
	var merchant := active_castle_id.begins_with(FIELD_MERCHANT_CASTLE_PREFIX)
	# Y6: 유랑 상인의 진열은 **카드 1 + 장비 1**이다(§6.2). 성의 2+2와 다른 것은
	# 이 수 하나뿐이고 렌더러·구매 경로는 한 줄도 안 갈린다.
	var lot := 1 if merchant else 2
	if shop_offers.is_empty() or refresh:
		shop_offers.clear()
		# W9: v2 드래프트 풀 20종에서만 뽑는다. `SKILLS` 28종을 쓰면 W7이 내린
		# legacy 카드 8종이 상점에 나온다(handoff-w7 §8).
		var skill_pool := DealCardLibrary.draft_pool()
		for _index in lot:
			if skill_pool.is_empty():
				break
			var definition: Dictionary = skill_pool.pop_at(rng.randi_range(0, skill_pool.size() - 1))
			# V8: 가격에 스테이지 스케일이 걸린다(1스테이지는 v2와 동일한 24~42 G).
			shop_offers.append({"card":DealCardLibrary.instance(String(definition["id"]), 1), "name":definition["name"], "desc":definition["desc"], "price":_scaled_price(rng.randi_range(24, 42)), "sold":false})
		# 아이템은 레일이 아니라 **장비 4부위**로 간다(§5.4). 데이터 57종은 무수정이다.
		for _index in lot:
			var item := ItemLibrary.random_item(rng, "", "swordsman", 0.25)
			shop_offers.append({"card":ItemLibrary.instance(String(item["id"])), "name":item["name"], "desc":item["desc"], "price":_scaled_price(ItemLibrary.price_for(item)), "sold":false})
	state = "camp"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "CardShop"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	var panel := _kit_shell(overlay, Rect2(62.0, 55.0, 1156.0, 610.0), "딜싸이클 카드상",
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 400.0)
	# Y4: 「보유 999 G · 새로고침 3회」 → **금화 + 숫자 하나**(세공사·밀정과 한 언어).
	# 새로고침 횟수는 지웠다 — 그 수가 하는 일은 값을 올리는 것뿐이고,
	# 오른 값은 하단 「상품 새로고침 · N G」 버튼에 이미 그대로 적혀 있다.
	_gold_chip(panel, Rect2(884.0, 38.0, 244.0, 38.0), gold)
	for index in shop_offers.size():
		var offer: Dictionary = shop_offers[index]
		var card: Dictionary = offer["card"]
		var color := _factory_card_color(card)
		var sold := bool(offer.get("sold", false))
		var button := _button("", color, Vector2(252.0, 360.0))
		_kit_card_skin(button, 1 if String(card.get("kind", "skill")) == "item" else 0, 2 if sold else 0)
		button.position = Vector2(42.0 + index * 273.0, 95.0)
		button.disabled = sold
		# 판매 완료 카드도 같은 카드 렌더러를 타게 두고 딤 + 띠로만 구분합니다.
		# 예전에는 아이콘·이름 없이 텅 빈 어두운 상자만 남아 무엇이 팔렸는지 알 수 없었습니다 (P2-5).
		_decorate_shop_offer(button, card, offer)
		if sold:
			button.modulate = Color(0.46, 0.46, 0.53)
			var sold_band := Panel.new()
			# 띠는 이름·설명·지표를 가리지 않도록 가격 자리에 얹습니다.
			sold_band.position = Vector2(0.0, 308.0)
			sold_band.size = Vector2(252.0, 46.0)
			sold_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UIKit.style_panel(sold_band, UIKit.Tone.SLATE, UIKit.Role.CHIP)
			button.add_child(sold_band)
			var sold_label := _label("팔렸습니다", UI_HEADING_SIZE, GamePalette.TEXT)
			sold_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sold_band.add_child(sold_label)
		button.pressed.connect(_buy_shop_offer.bind(index))
		panel.add_child(button)
	# ★ Y3(§8 ⑨⑩): 「카드 합성」·「칸 배율 강화」가 각인 세공사에서 **여기로 이사했다.**
	#   세공사는 이제 각인만 판다(하단 버튼이 「닫기」 하나가 됐다). 두 거래는 각인이
	#   아니라 **덱을 만지는** 거래이므로 카드상이 맞는 창구다.
	#   폭 260 + 240 + 260 + 240 + 간격 24×3 = 1,072 ⊂ 패널 안쪽 1,156.
	var refresh_cost := 10 + shop_refresh_count * 6
	var fusion_count: int = 0 if factory == null else factory.fusion_candidates().size()
	var shop_actions: Array[Dictionary] = [
		{"label":"카드 합성 · 무료 (%d조합)" % fusion_count, "color":GamePalette.CYAN,
			"width":260.0, "enabled":fusion_count > 0, "action":_show_fusion_service},
		{"label":"칸 배율 강화", "color":GamePalette.YELLOW,
			"width":240.0, "enabled":factory != null, "action":_show_factory_mage},
		{"label":"상품 새로고침 · %d G" % refresh_cost, "color":GamePalette.ORANGE,
			"width":260.0, "enabled":true, "action":_refresh_shop.bind(refresh_cost)},
		{"label":"상점 나가기 · ESC", "color":GamePalette.MUTED,
			"width":240.0, "enabled":true, "action":_close_base_camp}
	]
	if merchant:
		# 떠돌이라 창구가 하나뿐이다 — 합성·배율·새로고침은 성의 것이다.
		shop_actions = [shop_actions[shop_actions.size() - 1]]
	var action_x := 42.0
	var close: Button = null
	for action_value: Dictionary in shop_actions:
		var action_button := _button(String(action_value["label"]), action_value["color"],
			Vector2(float(action_value["width"]), 52.0))
		action_button.position = Vector2(action_x, 500.0)
		action_button.disabled = not bool(action_value["enabled"])
		action_button.pressed.connect(action_value["action"] as Callable)
		panel.add_child(action_button)
		action_x += float(action_value["width"]) + 24.0
		close = action_button
	close.grab_focus()

func _refresh_shop(cost: int) -> void:
	if state != "camp": return
	if gold < cost:
		_show_banner("새로고침 비용이 부족합니다", GamePalette.RED, 1.8)
		return
	gold -= cost
	shop_refresh_count += 1
	_show_card_shop(true)

func _buy_shop_offer(index: int) -> void:
	if state != "camp" or index < 0 or index >= shop_offers.size(): return
	var offer: Dictionary = shop_offers[index]
	if bool(offer.get("sold", false)): return
	var cost := int(offer["price"])
	if gold < cost:
		_show_banner("골드가 부족합니다 · 필요 %d G" % cost, GamePalette.RED, 1.8)
		return
	gold -= cost
	offer["sold"] = true
	shop_offers[index] = offer
	var purchased: Dictionary = (offer["card"] as Dictionary).duplicate(true)
	if String(purchased.get("kind", "skill")) == "item":
		# W9(§5.4): 아이템은 레일 칸을 먹지 않는다. 사는 즉시 **장비 4부위**에 착용되고,
		# 같은 부위에 있던 장비는 카드 보관함으로 밀려난다.
		if factory != null:
			var part := FactoryDeck.equipment_part(purchased)
			var displaced := factory.equip(purchased)
			if not displaced.is_empty():
				factory.add_inventory(displaced)
			_reset_player_cycle()
			_show_card_shop(false)
			var displaced_tail := " · %s%s 보관함으로" % [displaced.get("name", ""), _particle_eun(String(displaced.get("name", "")))] if not displaced.is_empty() else ""
			_show_banner("%s 장착 (%s)%s" % [offer.get("name", "장비"), part, displaced_tail], GamePalette.GREEN, 2.8)
		_update_hud()
		return
	_clear_overlay()
	_show_factory_menu("place", purchased, "castle_interior")

# =============================================================================
# W9 신설 ① — 각인 세공사 (설계 §7.2 "각인 상점(합성 통합)")
# X1 개편 — **3택 진열 + 개별 가격 + 새로고침** (2026-08-09 사용자 피드백 ④)
# =============================================================================
# 구 "레일 강화술사"(W2가 골드 환산으로 안전화해 둔 자리)를 v2 의미로 교체한 NPC다.
# 세 가지를 한 창구로 모았다:
#   ① 각인 구매      — 골드로 W6의 각인 3택1 드래프트에 진입한다 (신규)
#   ② 카드 합성      — 구 `card_fusion` NPC를 여기로 통합 (설계 §7.2 명시)
#   ③ 칸 배율 강화   — repeat / duration / reload 3종 (W2가 5칸에서도 유효하다고 남긴 것)
#
# ── X1이 ①을 바꾼 이유와 방식 ───────────────────────────────────────────────
# 사용자 원문 ④: "각인은 각인 NPC가: 스킬 카드처럼 3개 선택지, 효과가 좋을수록
# 골드를 더 내야 하고, 새로고침하면 새 각인들로 리프레시."
#
# W9판은 "70 + 30×n G를 내면 드래프트가 **열린다**"였다. 즉 값은 하나이고 무엇을
# 사는지는 돈을 낸 **뒤에** 알았다. X1은 그 순서를 뒤집는다 — 세 장이 값표를 달고
# 미리 서 있고, 플레이어는 **보고** 산다. 카드 상점(`_show_card_shop`)과 완전히
# 같은 문법이라 성 안의 두 창구가 한 언어를 쓴다.
#
#   진열 규칙 : `_roll_rune_draft()` 그대로 재사용 — 희귀도 가중도, **흐름 과부하
#               억제도** 상점에서 똑같이 걸린다(같은 함수를 부르므로 어긋날 수 없다).
#   가격      : `GameTuning.RUNE_SHOP_PRICE_*` 3등급 × 흐름/확정/굴림 프리미엄
#               × 구매 계단 × 상점가 스테이지 스케일 (근거는 tuning.gd 주석)
#   새로고침  : `RUNE_SHOP_REROLL_BASE + STEP × 굴린 횟수`, 역시 스테이지 스케일
#   진열 유지 : 카드 상점과 **같은 규약** — 같은 성 안에서는 유지, 다른 성으로 가면
#               새로 깐다(`rune_shop_castle_id`). 재방문 리롤 파밍을 막는다.
#   구매 뒤   : 기존 2단계(`_show_rune_target()` "강화할 칸을 고르세요")를 무수정 재사용.
#               `draft_offers`에 **산 것 하나만** 넣으므로 미선택 조각이 0이 된다 —
#               돈을 내고 산 물건의 나머지 두 장은 진열대에 남지 마왕에게 가지 않는다.
# ⚠️ 구 `RUNE_SHOP_BASE_PRICE(70)` / `RUNE_SHOP_PRICE_STEP(30)` 두 상수는 X1에서
#    **삭제됐다.** 값이 하나였을 때만 성립하던 식이라 3택 진열과 양립하지 않는다.
#    후신은 `GameTuning.RUNE_SHOP_PRICE_COMMON/RARE/EPIC` + `RUNE_SHOP_PURCHASE_STEP`이다.
## 진열 장수. 스킬 카드 2택과 달리 각인은 **3택**이다(사용자 요구 ④ "3개 선택지").
const RUNE_SHOP_OFFER_COUNT := 3

# =============================================================================
# V8: 성·캠프 NPC의 v3 경제 정합 — 상점가 스테이지 스케일 (설계 §8 표 "가격만 스테이지 스케일")
# =============================================================================
# NPC 4종(카드상 · 각인 세공사 · 계약자 · 밀정)의 **기능**은 v3에서 그대로 맞다.
# 어긋나는 것은 가격 하나다 — 런이 v2의 3배(5스테이지)라 골드 총량도 3배가 되는데
# 상점가가 v2 그대로면 4~5스테이지 상점은 "보이는 대로 다 사기"가 된다.
# §6.2의 보상 감쇠는 **dwell**에만 걸린다. 전진해서 스테이지를 넘기는 플레이는
# 감쇠를 피해 가므로 스테이지 축의 물가 상승이 따로 필요하다.
#
# 계약(§6.5 V3-J)에는 걸지 않는다. 정비 비용은 설계가 `120 + 60×사용횟수`로 못 박았고
# 그 식은 "되살수록 비싸진다"는 다른 축(사용 횟수)을 이미 쓰고 있다.
#
# ⚠️ V10(2026-08-09): 계수 자체는 **`GameTuning.STAGE_PRICE_STEP`으로 이관**됐다
#    (handoff-v9 §9 #13). V8이 그 파일을 열 수 없어 여기 두었던 것이다.
#    값 0.35는 balance_probe ⑩ 실측으로 **유지 확정**했다 — 근거는 tuning.gd 주석.
func stage_price_scale() -> float:
	return 1.0 + GameTuning.STAGE_PRICE_STEP * float(maxi(0, clock.stage - 1))

func _scaled_price(base_price: int) -> int:
	var scale := stage_price_scale()
	# Y6: 유랑 상인은 성보다 20% 비싸다(§6.2). 창구가 열려 있는 동안에만 걸리고
	# 값은 진열을 굴리는 순간 한 번 박히므로, 닫은 뒤 성 가격이 오염되지 않는다.
	if String(current_castle.get("id", "")).begins_with(FIELD_MERCHANT_CASTLE_PREFIX):
		scale *= FIELD_MERCHANT_PREMIUM
	return maxi(1, int(round(float(base_price) * scale)))
const RUNE_SHOP_PANEL_RECT := Rect2(40.0, 76.0, 1200.0, 540.0)
const RUNE_SHOP_CARD_Y := 104.0
const RUNE_SHOP_ACTION_Y := 414.0

## 기준가(common 1개). 구 `_rune_shop_price()`의 자리를 그대로 지킨다 — 다른 창구와
## 테스트가 "각인 값이 스테이지·구매횟수로 오르는가"를 이 함수 하나로 묻기 때문이다.
func _rune_shop_price() -> int:
	return _rune_offer_price({"instance": {}, "rarity": RuneEngine.RARITY_COMMON})

## 진열 한 장의 값. 인자는 `_roll_rune_draft()`가 만든 offer 사전 그대로다.
##   (희귀도 기본가 + 구매 계단) × 흐름 × 확정 × 굴림 × 스테이지 스케일
func _rune_offer_price(offer: Dictionary) -> int:
	var instance: Dictionary = offer.get("instance", {})
	var rune_id := String(instance.get("id", ""))
	var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
	var rarity := String(offer.get("rarity", definition.get("rarity", RuneEngine.RARITY_COMMON)))
	var base := float(GameTuning.RUNE_SHOP_PRICE_COMMON)
	if rarity == RuneEngine.RARITY_RARE:
		base = float(GameTuning.RUNE_SHOP_PRICE_RARE)
	elif rarity == RuneEngine.RARITY_EPIC:
		base = float(GameTuning.RUNE_SHOP_PRICE_EPIC)
	base += float(GameTuning.RUNE_SHOP_PURCHASE_STEP * rune_shop_purchases)
	if String(definition.get("family", "")) == "flow":
		base *= GameTuning.RUNE_SHOP_FLOW_PREMIUM
	if not bool(definition.get("roll", true)):
		base *= GameTuning.RUNE_SHOP_PASSIVE_PREMIUM
	# ★ Y3(§2.6 "레일 각인 할증 신설"): 레일 각인은 붙일 칸을 고르지 않고 즉시 붙으며
	#   칸 교환·카드 이동에 흔들리지 않는다. 그 편의에 값을 매긴다.
	#   Y1이 `RUNE_SHOP_RAIL_PREMIUM`을 tuning에 넣어 뒀지만 소비자가 없었다
	#   (handoff-y2 §8-A — 가격 판단이 Y3 소유라 일부러 남겨 둔 항이다).
	if RuneEngine.rune_scope(rune_id) == "rail":
		base *= GameTuning.RUNE_SHOP_RAIL_PREMIUM
	# 굴림 프리미엄 — 같은 각인이라도 확률이 저작 범위의 위쪽에서 굴려졌으면 더 비싸다.
	var p_min := float(definition.get("p_min", 0.0))
	var p_max := float(definition.get("p_max", 0.0))
	if p_max > p_min:
		var t := clampf((float(instance.get("p", p_min)) - p_min) / (p_max - p_min), 0.0, 1.0)
		base *= lerpf(GameTuning.RUNE_SHOP_ROLL_PREMIUM_MIN, GameTuning.RUNE_SHOP_ROLL_PREMIUM_MAX, t)
	return _scaled_price(int(round(base)))

## 새로고침 비용. 굴릴수록 오른다 — 세 번이면 희귀 각인 한 개 값을 넘는다.
func _rune_shop_reroll_cost() -> int:
	return _scaled_price(GameTuning.RUNE_SHOP_REROLL_BASE
		+ GameTuning.RUNE_SHOP_REROLL_STEP * rune_shop_rerolls)

## 진열을 (다시) 깐다. 카드 상점과 같은 규약이다 — 같은 성 안에서는 유지된다.
func _ensure_rune_shop_offers(force: bool = false) -> void:
	var active_castle_id := String(current_castle.get("id", "field_shop"))
	if not force and rune_shop_castle_id != active_castle_id:
		rune_shop_rerolls = 0
		rune_shop_offers.clear()
		rune_shop_castle_id = active_castle_id
	if rune_shop_offers.is_empty() or force:
		# 드래프트와 **같은 생성기**를 쓴다 — 희귀도 가중도 흐름 과부하 억제도 그대로다.
		rune_shop_offers.assign(_roll_rune_draft(RUNE_SHOP_OFFER_COUNT))
		for index in rune_shop_offers.size():
			var offer: Dictionary = rune_shop_offers[index]
			var rune_id := String((offer.get("instance", {}) as Dictionary).get("id", ""))
			var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
			offer["rarity"] = String(definition.get("rarity", RuneEngine.RARITY_COMMON))
			offer["price"] = _rune_offer_price(offer)
			rune_shop_offers[index] = offer

## Y3 재작성(피드백 ⑨⑩ · 설계 §8 ⑨⑩) — **한 창구는 한 가지만 판다.**
##   ① 하단 4버튼 → **「닫기」 하나.** 「카드 합성」·「칸 배율 강화」는 카드상으로 옮겼다.
##   ② 「진열 새로고침」은 하단이 아니라 **진열대 자리**(카드 위)로 올라왔다 —
##      새로고침은 나가는 행동이 아니라 진열을 만지는 행동이다.
##   ③ 보유 골드는 **숫자 하나만** 크게. 「각인 N개」 병기는 삭제했다(살 때 안 쓰는 수다).
##   ④ 카드마다 **칸 / 레일 배지**가 크게 붙는다 — 다음 화면이 무엇인지가 사기 전에 보인다.
func _show_rune_shop() -> void:
	state = "camp"
	get_tree().paused = true
	_ensure_rune_shop_offers()
	# 진열 카드는 **`choice_buttons`에 등록하지 않는다.** 여기는 `camp`이지
	# 2지선다 화면이 아니다 — 단일 포커스 모델은 choice/draft/item 세 상태의 계약이고
	# 상점은 카드 상점과 같은 "마우스 + ESC" 규약을 쓴다(`_show_card_shop` 무회귀).
	rune_shop_buttons.clear()
	_begin_modal_tooltips()
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "RuneShop"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 각인을 파는 자리라 리본만 ABYSS다 — 카드상(WOOD)·계약자(EMBER)와 창구가 갈린다.
	var panel := _kit_shell(overlay, RUNE_SHOP_PANEL_RECT, "각인 세공사",
		UIKit.Tone.SLATE, UIKit.Tone.ABYSS, 360.0)
	panel.name = "RuneShopPanel"
	# 보유 골드 — 코인 하나 + 숫자 하나. 이 화면에서 가장 큰 숫자다.
	var money_rect := Rect2(RUNE_SHOP_PANEL_RECT.size.x - 244.0, 34.0, 204.0, 46.0)
	# 진열 카드마다 값표 칩이 또 하나씩 붙으므로 **보유 골드만** 이름으로 구분해 둔다
	# (같은 이름이 여럿이면 검사가 엉뚱한 칩을 집는다 — 실제로 밟았다).
	_gold_chip(panel, money_rect, gold).name = "RuneShopPurse"
	# 진열대 — 새로고침 버튼이 여기 산다(카드 위 · 값은 굴릴수록 오른다).
	var reroll_cost := _rune_shop_reroll_cost()
	var reroll := _button("진열 새로고침 · %d G" % reroll_cost, GamePalette.ORANGE, Vector2(260.0, 42.0))
	reroll.name = "RuneShopReroll"
	reroll.position = Vector2(40.0, 36.0)
	reroll.disabled = gold < reroll_cost
	reroll.pressed.connect(_refresh_rune_shop)
	panel.add_child(reroll)
	_modal_tip(reroll, "shop_reroll", {
		"title": "진열 새로고침",
		"accent": GamePalette.ORANGE,
		"rows": [
			["지금 값", "%d G" % reroll_cost, GamePalette.YELLOW],
			["다음 값", "%d G" % _scaled_price(GameTuning.RUNE_SHOP_REROLL_BASE
				+ GameTuning.RUNE_SHOP_REROLL_STEP * (rune_shop_rerolls + 1)), GamePalette.MUTED],
			["진열 유지", "같은 성 안에서는 그대로", GamePalette.CYAN]
		],
		"body": "굴릴수록 비싸집니다. 세 번 굴리면 희귀 각인 한 개 값을 넘습니다."
	})
	var gap := 30.0
	var total_width := RUNE_DRAFT_CARD_SIZE.x * float(rune_shop_offers.size()) \
		+ gap * float(maxi(0, rune_shop_offers.size() - 1))
	var start_x := (RUNE_SHOP_PANEL_RECT.size.x - total_width) * 0.5
	for index in rune_shop_offers.size():
		var offer: Dictionary = rune_shop_offers[index]
		var price := int(offer.get("price", 0))
		var button := _rune_offer_button(offer)
		button.position = Vector2(start_x + float(index) * (RUNE_DRAFT_CARD_SIZE.x + gap), RUNE_SHOP_CARD_Y)
		# 값표는 카드 **오른쪽 위** GOLD 칩. 아래쪽은 이미 확률·효과·보유가 쓰고 있어
		# 값이 들어갈 자리가 없다 — 희귀도 칩 옆이 유일한 빈 줄이다.
		# 살 수 없으면 카드가 통째로 비활성이 된다(킷 카드 DISABLED = 함몰 기하 · §6).
		var price_rect := Rect2(200.0, 20.0, 136.0, 28.0)
		_gold_chip(button, price_rect, price, UIKit.FONT_HEADING)
		button.set_meta("rune_price", price)
		button.disabled = gold < price
		button.pressed.connect(_buy_rune_shop_offer.bind(index))
		panel.add_child(button)
		rune_shop_buttons.append(button)
	var close := _button("공방을 나선다 · ESC", GamePalette.MUTED, Vector2(360.0, 54.0))
	close.name = "RuneShopClose"
	close.position = Vector2((RUNE_SHOP_PANEL_RECT.size.x - 360.0) * 0.5, RUNE_SHOP_ACTION_Y)
	close.pressed.connect(_close_base_camp)
	panel.add_child(close)
	_kit_label(panel, Rect2(0.0, RUNE_SHOP_PANEL_RECT.size.y - 58.0, RUNE_SHOP_PANEL_RECT.size.x, 22.0),
		"셋 중 하나를 삽니다. 사지 않은 둘은 진열대에 남습니다 — 마왕에게 가지 않습니다.",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_bind_modal_tooltips()
	_animate_modal(panel, Vector2(0.0, 18.0))
	close.grab_focus()
	play_sound("choice", -4.0)

## 새로고침 — 골드를 내고 세 장을 통째로 다시 굴린다.
func _refresh_rune_shop() -> void:
	if state != "camp":
		return
	var cost := _rune_shop_reroll_cost()
	if gold < cost:
		_show_banner("새로고침 비용이 부족합니다 · 필요 %d G" % cost, GamePalette.RED, 1.8)
		return
	gold -= cost
	rune_shop_rerolls += 1
	_ensure_rune_shop_offers(true)
	_show_rune_shop()

## 진열 한 장 구매 → 기존 2단계("강화할 칸을 고르세요")로 그대로 넘어간다.
## `draft_offers`에 **산 것 하나만** 담기 때문에 `_grant_draft_leftovers()`가 0을
## 돌려주고, 마왕은 이 거래에서 아무것도 얻지 못한다(돈을 내고 산 물건이므로).
func _buy_rune_shop_offer(index: int) -> void:
	if state != "camp" or factory == null:
		return
	if index < 0 or index >= rune_shop_offers.size():
		return
	var offer: Dictionary = rune_shop_offers[index]
	var cost := int(offer.get("price", 0))
	if gold < cost:
		_show_banner("골드가 부족합니다 · 필요 %d G" % cost, GamePalette.RED, 1.8)
		return
	gold -= cost
	rune_shop_purchases += 1
	rune_shop_offers.remove_at(index)
	# 남은 진열의 값은 구매 계단(`RUNE_SHOP_PURCHASE_STEP`)이 올라간 만큼 다시 매긴다.
	for other_index in rune_shop_offers.size():
		var other: Dictionary = rune_shop_offers[other_index]
		other["price"] = _rune_offer_price(other)
		rune_shop_offers[other_index] = other
	draft_source = "rune_shop"
	draft_return_state = "castle_interior"
	draft_offers.assign([offer])
	draft_selected_index = 0
	draft_selected_rune = offer
	rune_shop_buttons.clear()
	_clear_overlay()
	# Y2: 산 것이 레일 각인이면 2단계가 아니라 레일로 직행한다(§2.2 · 드래프트와 같은 규칙).
	if RuneEngine.rune_scope(String((offer.get("instance", {}) as Dictionary).get("id", ""))) == "rail":
		_commit_rail_rune_draft()
		return
	_show_rune_target()

# =============================================================================
# W9 신설 ② — 계약자 (V5: 설계 §6.5 "계약(Pact) — **체류 압박**을 화폐로")
# =============================================================================
# 거래 3종 · 각 방향 런당 2회. 시간 제한 게임에서 시간이 거래 가능해지는 순간
# 타이머는 압박기에서 자원으로 격상된다.
#
#   V5 재배치(설계 §6.5 · V3-J) — 저장 키(`sell_day`/`buy_day`/`mortgage`)는 그대로 둔다:
#   sell_day = **정비(Respite)**: 120 + 60×사용횟수 G → dwell −1
#   buy_day  = **탐욕(Greed)**: dwell +1 · 각인 1 파괴 + 마왕에게 카드 1장 → 200 G + 각인 조각 1
#   mortgage = **미래를 담보로**: dwell +2 → 영웅(epic) 등급 각인 1개 확정
#
# ── V8 점검 결과 (지시 항목 ④ "계약 NPC 거래 로직") ──────────────────────────
# V5가 V3-J 계수 7개를 이미 배선해 뒀고, 설계 §6.5 표와 **한 줄도 어긋나지 않는다**.
# V8이 확인·확정한 규칙은 다음 다섯이다(전부 `--castle-test`가 단언한다):
#   1. 거래 3종 × **각 2회**(`PACT_LIMIT`). 세 카운터는 서로 독립이다.
#   2. 정비는 `dwell > 0` **그리고** 골드가 충분할 때만 열린다 — dwell 0에서 살 게 없다.
#   3. 탐욕은 **낼 대가가 있을 때만** 열린다(붙은 각인 1개 + 레일에서 뺄 카드 1장).
#      대가가 없는데 골드를 주면 "체류를 파는" 거래가 공짜 수익원이 된다.
#   4. 미래를 담보로는 조건이 없다 — 대가가 dwell이고 dwell에는 상한이 없기 때문이다.
#      단 **1장만 제시**해 확정 지급이 되고, 미선택 조각(= 마왕 성장)이 생기지 않는다.
#   5. dwell을 옮긴 뒤에는 반드시 `_pact_shift_dwell()`을 지난다 — 잠식(내려가면 꺼질 수
#      있다)과 균열 스케줄(올라가면 밀릴 수 있다)을 그 자리에서 따라잡는다.
# 세 거래가 모두 **압박(dwell)과 다른 자원(골드·각인·카드)을 맞바꾼다**는 축을 지킨다.
#
# 구현은 `clock.add_dwell()` 정수 증감 + 기존 부여 함수 호출뿐이다. 클럭이 시그널을
# 내지 않으므로 이정표가 두 번 울리지 않고, 건너뛴 균열은 `_maintain_rift_schedule()`이
# 바로 아래에서 따라잡는다. (V8: 각성 게이트 폴링은 함께 삭제됐다.)
const PACT_LIMIT := 2
const PACT_SELL_GOLD := 90
const PACT_PANEL_RECT := Rect2(232.0, 78.0, 816.0, 566.0)

func pact_uses_left(kind: String) -> int:
	return maxi(0, PACT_LIMIT - int(pact_uses.get(kind, 0)))

## 계약 재료 — "하루를 산다"가 부술 각인이 붙어 있는 첫 칸. 없으면 -1.
func _first_slot_with_rune() -> int:
	if factory == null:
		return -1
	for slot_index in factory.slots.size():
		if factory.rune_count_on(slot_index) > 0:
			return slot_index
	return -1

func pact_available(kind: String) -> bool:
	if pact_uses_left(kind) <= 0:
		return false
	match kind:
		# 정비(Respite): 체류를 골드로 되산다. dwell 0에서는 살 게 없다.
		"sell_day":
			return clock.dwell > 0 and gold >= pact_respite_cost()
		# 탐욕(Greed): 체류를 판다. 대가(각인 1개 + 카드 1장)를 낼 수 있어야 한다.
		"buy_day":
			return _first_slot_with_rune() >= 0 and not _last_factory_skill_location().is_empty()
		"mortgage":
			return true
	return false

## 정비 비용 = 120 + 60 × 사용 횟수 (V3-J). 되살수록 비싸진다.
func pact_respite_cost() -> int:
	return GameTuning.PACT_RESPITE_COST_BASE + GameTuning.PACT_RESPITE_COST_STEP * int(pact_uses.get("sell_day", 0))

func _show_pact_service() -> void:
	state = "camp"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "PactService"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 대가를 치르는 창구 = EMBER 리본(§2 "위험·과부하·파기 확인").
	var panel := _kit_shell(overlay, PACT_PANEL_RECT, "계약자 · 머문 밤을 사고판다",
		UIKit.Tone.SLATE, UIKit.Tone.EMBER, 560.0)
	_kit_panel(panel, Rect2(44.0, 42.0, PACT_PANEL_RECT.size.x - 88.0, 34.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	var clock_line := _label("%s · 현재 체류 %d · 잠식까지 %d · 보유 %d G" % [
		clock.stage_label(), clock.dwell, clock.blight_threshold(), gold], UI_BODY_SIZE, GamePalette.YELLOW)
	clock_line.position = Vector2(58.0, 42.0)
	clock_line.size = Vector2(PACT_PANEL_RECT.size.x - 116.0, 34.0)
	clock_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(clock_line)
	var trades: Array[Dictionary] = [
		{
			"kind":"sell_day",
			"label":"되돌리기 · 머문 밤을 되산다",
			"cost":"%d G (쓸수록 +%d)" % [pact_respite_cost(), GameTuning.PACT_RESPITE_COST_STEP],
			"gain":"체류 −1 · 몹이 약해지고 보상이 다시 좋아진다",
			"color":GamePalette.ORANGE,
			"action":_pact_sell_day
		},
		{
			"kind":"buy_day",
			"label":"탐욕 · 머문 밤을 판다",
			"cost":"체류 +1 · 각인 1개 파괴 + 마왕에게 카드 1장",
			"gain":"즉시 %d G + 각인 조각 %d" % [GameTuning.PACT_GREED_GOLD, GameTuning.PACT_GREED_RUNE_SHARDS],
			"color":GamePalette.CYAN,
			"action":_pact_buy_day
		},
		{
			"kind":"mortgage",
			"label":"미래를 담보로",
			"cost":"체류 +%d" % GameTuning.PACT_HERO_RUNE_DWELL,
			"gain":"지금 즉시 영웅 등급 각인 1개 확정",
			"color":GamePalette.RED,
			"action":_pact_mortgage
		}
	]
	for index in trades.size():
		var trade: Dictionary = trades[index]
		var kind := String(trade["kind"])
		var left := pact_uses_left(kind)
		var available := pact_available(kind)
		var button := _button("%s   (남은 횟수 %d / %d)\n대가 · %s\n얻는 것 · %s" % [trade["label"], left, PACT_LIMIT, trade["cost"], trade["gain"]], trade["color"], Vector2(PACT_PANEL_RECT.size.x - 100.0, 108.0))
		button.position = Vector2(50.0, 100.0 + index * 118.0)
		button.disabled = not available
		button.pressed.connect(trade["action"] as Callable)
		panel.add_child(button)
	_kit_label(panel, Rect2(44.0, PACT_PANEL_RECT.size.y - 100.0, PACT_PANEL_RECT.size.x - 88.0, 24.0),
		"거래마다 한 모험에 %d번씩입니다. 체류는 되돌릴 수 있지만 공짜는 아닙니다." % PACT_LIMIT,
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	var close := _button("계약을 미룬다 · ESC", GamePalette.MUTED, Vector2(260.0, 46.0))
	close.position = Vector2((PACT_PANEL_RECT.size.x - 260.0) * 0.5, PACT_PANEL_RECT.size.y - 62.0)
	close.pressed.connect(_close_base_camp)
	panel.add_child(close)
	close.grab_focus()
	play_sound("choice", -4.0)

## V5: 계약으로 **dwell**을 옮긴 뒤의 뒷정리(설계 §6.5). v2의 일수 이동은 폐기됐다.
## dwell이 내려가면 잠식이 꺼질 수 있고, 올라가면 균열이 밀릴 수 있어 둘 다 따라잡는다.
func _pact_shift_dwell(delta_dwell: int) -> void:
	clock.add_dwell(delta_dwell)
	_maintain_rift_schedule()
	_check_stage_blight()
	_update_hud()

## 정비(Respite) — 골드로 체류를 되산다. dwell −1.
func _pact_sell_day() -> void:
	if state != "camp" or not pact_available("sell_day"):
		return
	var cost := pact_respite_cost()
	pact_uses["sell_day"] = int(pact_uses.get("sell_day", 0)) + 1
	gold = maxi(0, gold - cost)
	_pact_shift_dwell(GameTuning.PACT_RESPITE_DWELL)
	_close_base_camp()
	_show_banner("정비를 마쳤습니다 · 체류 %d · −%d G" % [clock.dwell, cost], GamePalette.ORANGE, 3.0)
	play_sound("debt", -2.0)

func _pact_buy_day() -> void:
	if state != "camp" or not pact_available("buy_day"):
		return
	var slot_index := _first_slot_with_rune()
	var destroyed := factory.detach_rune(slot_index, 0)
	var offered := _take_factory_skill_card()
	var offered_id := String(offered.get("id", ""))
	if not offered_id.is_empty():
		selected_skills.erase(offered_id)
		rejected_skills.append(offered_id)
	pact_uses["buy_day"] = int(pact_uses.get("buy_day", 0)) + 1
	gold += GameTuning.PACT_GREED_GOLD
	grant_boss_rune_shards(GameTuning.PACT_GREED_RUNE_SHARDS)
	_pact_shift_dwell(GameTuning.PACT_GREED_DWELL)
	_reset_player_cycle()
	_close_base_camp()
	var rune_name := String((RuneEngine.RUNES.get(String(destroyed.get("id", "")), {}) as Dictionary).get("name", "각인"))
	var card_name := String(DealCardLibrary.by_id(offered_id).get("name", offered_id))
	_show_banner("탐욕의 대가 · 체류 %d · +%d G · %s 파괴 + %s%s 마왕에게" % [clock.dwell, GameTuning.PACT_GREED_GOLD, rune_name, card_name, _particle_eul(card_name)], GamePalette.CYAN, 3.4)
	play_sound("choice", -1.0)
	# 넘긴 카드는 마왕의 레일로 간다 — 기존 토스트 경로를 그대로 쓴다.
	if not offered_id.is_empty():
		_show_boss_growth_toast([DealCardLibrary.by_id(offered_id)])

func _pact_mortgage() -> void:
	if state != "camp" or not pact_available("mortgage"):
		return
	pact_uses["mortgage"] = int(pact_uses.get("mortgage", 0)) + 1
	# V3-J: 대가가 "마왕 각인 +2"에서 **체류 +2**로 바뀌었다(설계 §6.5 표 3행).
	_pact_shift_dwell(GameTuning.PACT_HERO_RUNE_DWELL)
	_clear_overlay()
	_show_banner("미래를 담보로 잡았습니다 · 체류 +%d · 영웅 각인 1개" % GameTuning.PACT_HERO_RUNE_DWELL, GamePalette.RED, 3.4)
	play_sound("debt", -1.0)
	# 1장만 제시한다 → 확정 지급이 되고 미선택 조각(마왕 추가 성장)도 생기지 않는다.
	_show_rune_draft("pact", "castle_interior", RuneEngine.RARITY_EPIC, 1)

# =============================================================================
# W9 신설 ③ — 밀정 (설계 §7.2) · **Y3 리뉴얼**(피드백 ⑪ · 설계 §8 ⑪)
# =============================================================================
# 마왕의 5칸은 HUD 고스트 레일에 상시 보이지만 **각인은 개수만** 보인다(W5).
#
# ── Y3가 바꾼 네 가지 ────────────────────────────────────────────────────────
#   ① 열람이 **무료·기본 공개**가 됐다. 구 `SPY_REVEAL_COST(35 G)`와 `spy_revealed`
#      플래그가 함께 사라졌다. 35 G는 "정보를 살 것인가"라는 선택을 만들지 못했고
#      (안 사면 화면이 그냥 비어 있다) 사고 나면 두 번 다시 결정할 게 없었다.
#      정보는 공짜로 주고, **돈은 개입에만** 받는다.
#   ② 5칸을 유저 딜싸이클과 **같은 레일 렌더러**로 그린다(`_build_preview_slot`).
#      글자 5줄이 그림 5칸이 됐다. 톤만 ABYSS 무대 창이라 "여긴 마왕 쪽"이 읽힌다.
#   ③ 상단에 **마왕 초상**(`art/v2/portrait-demon-lord-96.png` · YA 산출물).
#   ④ 지우기가 **각인 1개 → 칸 1개 통째**가 됐다. 대상은 각인이 있는 칸 중 **무작위**다
#      (구판은 "가장 많은 칸의 마지막 1개" — 결정적이라 도박이 아니었다).
#      값 85 → **120 G** · **스테이지당 1회**.
const SPY_WIPE_COST := 120
# 세로 배치 — 초상 44~156 · 요약 44~88 · 안내 한 줄 100~122 · ABYSS 무대 창 162~384
# (흐름 아크 166~206 · 레일 222~372) · 버튼 404~458 · 패널 바닥 500.
const SPY_PANEL_RECT := Rect2(30.0, 100.0, 1220.0, 500.0)
const SPY_RAIL_ORIGIN := Vector2(32.0, 222.0)
const SPY_PORTRAIT := preload("res://art/v2/portrait-demon-lord-96.png")

## V8: 밀정 서비스도 스테이지 물가를 탄다(위 `stage_price_scale()` 주석 참조).
## 1스테이지에서는 상수와 정확히 같은 값이다.
func spy_wipe_cost() -> int:
	return _scaled_price(SPY_WIPE_COST)

## 이번 스테이지에 이미 칸을 지웠나. 저장되는 값은 "마지막으로 쓴 스테이지 번호"다.
func spy_wipe_available() -> bool:
	return spy_wipe_stage != clock.stage and demon_lord.can_strip_rune()

## 밀정 화면 전용 읽기 전용 덱. `_build_boss_factory()`와 같은 조립이지만 **런의 rng를
## 건드리지 않는다** — 화면을 여닫을 때마다 난수열이 흘러가면 같은 런이 다르게 굴러간다.
## 씨앗이 고정이라 같은 상태에서 몇 번을 열어도 같은 확률이 보인다.
func _build_spy_preview_deck() -> FactoryDeck:
	var deck: FactoryDeck = FACTORY_SCRIPT.new()
	deck.reset(GameTuning.BOSS_SLOT_COUNT)
	var local := RandomNumberGenerator.new()
	local.seed = run_cycle_seed + 5701
	for entry: Dictionary in demon_lord.slot_layout():
		var slot_index := int(entry.get("index", 0))
		var card: Dictionary = entry.get("card", {})
		if not card.is_empty():
			deck.place_card(slot_index, card.duplicate(true))
		for granted: Dictionary in (entry.get("runes", []) as Array):
			deck.attach_rune(slot_index, RuneEngine.roll_rune(String(granted.get("rune_id", "")), local))
	return deck

func _show_spy_service() -> void:
	state = "camp"
	get_tree().paused = true
	if demon_lord.rune_catalog.is_empty():
		demon_lord.set_rune_catalog(RuneEngine.ids_by_scope("slot"))
	demon_lord.sync_runes(rng)
	_begin_modal_tooltips()
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "SpyService"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	# 마왕의 레일을 들여다보는 창구 = ABYSS 리본.
	var panel := _kit_shell(overlay, SPY_PANEL_RECT, "밀정 · 마왕의 레일",
		UIKit.Tone.SLATE, UIKit.Tone.ABYSS, 440.0)
	panel.name = "SpyPanel"
	# --- 초상 + 요약 -------------------------------------------------------
	# 구판의 `PixelPortrait` 벡터 드로잉이 아니라 YA가 구운 96×96 스프라이트다.
	var portrait_frame := _kit_panel(panel, Rect2(32.0, 44.0, 112.0, 112.0), UIKit.Tone.ABYSS, UIKit.Role.INSET)
	portrait_frame.name = "SpyPortrait"
	var portrait := TextureRect.new()
	portrait.texture = SPY_PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(8.0, 8.0)
	portrait.size = Vector2(96.0, 96.0)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	var summary_rect := Rect2(160.0, 44.0, SPY_PANEL_RECT.size.x - 192.0, 44.0)
	_kit_panel(panel, summary_rect, UIKit.Tone.ABYSS, UIKit.Role.INSET)
	var summary := _label("마왕의 각인 %d / %d개  ·  지운 각인 %d개" % [
		demon_lord.rune_count(), demon_lord.rune_capacity(), demon_lord.stripped_runes.size()],
		UI_HEADING_SIZE, GamePalette.RED.lightened(0.16))
	summary.position = summary_rect.position + Vector2(16.0, 0.0)
	summary.size = Vector2(summary_rect.size.x - 200.0, summary_rect.size.y)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(summary)
	# 보유 골드는 **숫자 하나만** 크게(피드백 ⑩과 같은 규칙 · 세공사와 한 언어).
	var purse_rect := Rect2(summary_rect.end.x - 184.0, 44.0, 184.0, 44.0)
	_gold_chip(panel, purse_rect, gold)
	_kit_label(panel, Rect2(160.0, 100.0, SPY_PANEL_RECT.size.x - 192.0, 22.0),
		"마왕도 5칸을 순서대로 돕니다. 각인이 쌓인 칸이 그가 노리는 칸입니다.",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, true)
	# --- 마왕의 5칸 — 유저 딜싸이클과 같은 렌더러 --------------------------
	var stage_rect := Rect2(SPY_RAIL_ORIGIN.x - 12.0, 162.0,
		EDIT_RAIL_CONTENT_W + 24.0, SPY_RAIL_ORIGIN.y + EDIT_CARD_SIZE.y + 12.0 - 162.0)
	_kit_panel(panel, stage_rect, UIKit.Tone.ABYSS, UIKit.Role.INSET)
	var spy_deck := _build_spy_preview_deck()
	_build_edit_flow_arcs(panel, spy_deck, Rect2(SPY_RAIL_ORIGIN.x, SPY_RAIL_ORIGIN.y - 56.0,
		EDIT_RAIL_CONTENT_W, 40.0), SPY_RAIL_ORIGIN.x, 11.0)
	for index in spy_deck.slots.size():
		# 열람은 무료·기본 공개다 — `reveal_runes`는 항상 true.
		_build_preview_slot(panel, spy_deck, index, SPY_RAIL_ORIGIN, GamePalette.RED, true)
	# --- 개입 한 가지 + 닫기 -----------------------------------------------
	var wipe_ready := spy_wipe_available()
	var wipe_cost := spy_wipe_cost()
	var wipe_label := "칸 하나를 통째로 지운다 · %d G" % wipe_cost
	if spy_wipe_stage == clock.stage:
		wipe_label = "이번 스테이지에는 이미 썼습니다"
	elif not demon_lord.can_strip_rune():
		wipe_label = "지울 각인이 없습니다"
	var wipe := _button(wipe_label, GamePalette.RED, Vector2(560.0, 54.0))
	wipe.name = "SpyWipeButton"
	wipe.position = Vector2(60.0, 404.0)
	wipe.disabled = not wipe_ready or gold < wipe_cost
	wipe.pressed.connect(_spy_wipe_slot)
	panel.add_child(wipe)
	_modal_tip(wipe, "spy_wipe", {
		"title": "칸 하나를 통째로 지운다",
		"accent": GamePalette.RED,
		"rows": [
			["값", "%d G" % wipe_cost, GamePalette.YELLOW],
			["횟수", "스테이지당 1회", GamePalette.ORANGE],
			["대상", "각인이 있는 칸 중 무작위 1칸", GamePalette.MUTED]
		],
		"body": "고른 칸의 각인이 전부 영구히 사라집니다. 어느 칸이 걸릴지는 고를 수 없습니다. 전조 격파와 함께 마왕 성장을 늦추는 두 가지 중 하나입니다."
	})
	var close := _button("어둠으로 돌려보낸다 · ESC", GamePalette.MUTED, Vector2(500.0, 54.0))
	close.position = Vector2(SPY_PANEL_RECT.size.x - 560.0, 404.0)
	close.pressed.connect(_close_base_camp)
	panel.add_child(close)
	_bind_modal_tooltips()
	_animate_modal(panel, Vector2(0.0, 18.0))
	close.grab_focus()
	play_sound("choice", -4.0)

## 칸 하나를 통째로 지운다 — 각인이 있는 칸 중 **무작위**로 하나(설계 §8 ⑪).
func _spy_wipe_slot() -> void:
	if state != "camp":
		return
	if spy_wipe_stage == clock.stage:
		_show_banner("이번 스테이지에는 이미 밀정을 썼습니다", GamePalette.MUTED, 2.0)
		return
	if not demon_lord.can_strip_rune():
		_show_banner("지울 마왕의 각인이 없습니다", GamePalette.MUTED, 2.0)
		return
	var cost := spy_wipe_cost()
	if gold < cost:
		_show_banner("골드가 부족합니다 · 필요 %d G" % cost, GamePalette.RED, 1.8)
		return
	var candidates: Array[int] = []
	for index in FactoryDeck.SLOT_COUNT:
		if demon_lord.rune_count_on_slot(index) > 0:
			candidates.append(index)
	if candidates.is_empty():
		_show_banner("지울 마왕의 각인이 없습니다", GamePalette.MUTED, 2.0)
		return
	gold -= cost
	spy_wipe_stage = clock.stage
	var target_slot := candidates[rng.randi_range(0, candidates.size() - 1)]
	var wiped := 0
	# `strip_rune()`은 그 칸에 각인이 없으면 **아무 칸에서나** 하나를 뜯는 폴백이 있다.
	# 칸 수를 먼저 세어 그만큼만 돌아야 다른 칸을 건드리지 않는다.
	for _step in demon_lord.rune_count_on_slot(target_slot):
		if demon_lord.strip_rune(target_slot).is_empty():
			break
		wiped += 1
	_update_hud()
	_show_spy_service()
	_show_banner("마왕의 %02d번 칸을 비웠습니다 · 각인 %d개 소멸" % [target_slot + 1, wiped], GamePalette.BLUE, 3.0)
	play_sound("choice", 0.0)

func _show_factory_mage() -> void:
	state = "camp"
	get_tree().paused = true
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "FactoryMage"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_MODAL)
	var panel := _kit_shell(overlay, Rect2(250.0, 52.0, 780.0, 620.0), "레일 강화술사",
		UIKit.Tone.SLATE, UIKit.Tone.WOOD, 380.0)
	var mage_money := _label("보유 %d G" % gold, UI_BODY_SIZE, GamePalette.YELLOW)
	mage_money.position = Vector2(452.0, 44.0)
	mage_money.size = Vector2(300.0, 24.0)
	mage_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(mage_money)
	# v2 안전화: "레일 부품 건설"·"동시 레일 분열"은 5칸 고정·레인 폐지로 사라졌다.
	# 남은 칸 배율 강화 3종만 판다. 각인 상점으로의 재정의는 W9 소유다(설계 §7.2).
	var can_repeat := factory.can_apply_upgrade("repeat")
	var can_duration := factory.can_apply_upgrade("duration")
	var can_reload := factory.can_apply_upgrade("reload")
	var sold_out_note := " · 모든 칸에 이미 적용됨"
	var offers: Array[Dictionary] = [
		{"id":"repeat","name":"같은 칸 두 번 쓰기","desc":"선택한 칸의 카드를 두 번 실행합니다.%s" % ("" if can_repeat else sold_out_note),"cost":95,"enabled":can_repeat},
		{"id":"duration","name":"모든 칸 빨리","desc":"선택한 칸의 지속시간을 14%% 줄입니다.%s" % ("" if can_duration else sold_out_note),"cost":72,"enabled":can_duration},
		{"id":"reload","name":"RELOAD 줄이기","desc":"선택한 칸이 더하는 RELOAD 빚을 18%% 줄입니다.%s" % ("" if can_reload else sold_out_note),"cost":78,"enabled":can_reload}
	]
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var button := _button("%s · %d G\n%s" % [offer["name"], offer["cost"], offer["desc"]], GamePalette.CYAN, Vector2(680.0, 72.0))
		button.position = Vector2(50.0, 86.0 + index * 83.0)
		button.disabled = not bool(offer["enabled"])
		button.pressed.connect(_buy_factory_upgrade.bind(String(offer["id"]), int(offer["cost"])))
		panel.add_child(button)
	var close := _button("공방을 나선다 · ESC", GamePalette.MUTED, Vector2(260.0, 45.0))
	close.position = Vector2(260.0, 538.0)
	close.pressed.connect(_close_base_camp)
	panel.add_child(close)
	close.grab_focus()

func _buy_factory_upgrade(upgrade_type: String, cost: int) -> void:
	if state != "camp": return
	if gold < cost:
		_show_banner("골드가 부족합니다 · 필요 %d G" % cost, GamePalette.RED, 1.8)
		return
	gold -= cost
	if not factory.can_apply_upgrade(upgrade_type):
		# 버튼 게이트를 우회해 들어온 경우에도 골드를 잃지 않도록 마지막 방어선을 둡니다.
		gold += cost
		_show_banner("이 강화를 적용할 칸이 남아 있지 않습니다", GamePalette.MUTED, 2.2)
		return
	pending_factory_upgrade = upgrade_type
	factory_upgrade_refund = cost
	_show_factory_menu("upgrade_%s" % upgrade_type, {}, "castle_interior")

func _last_factory_skill_location() -> Dictionary:
	# 망각의 사제 / 운명의 직조사가 대상으로 삼는 "가장 최근 스킬 카드"를 찾습니다.
	# 보관함을 뒤에서부터 뒤지고, 비어 있으면 레일의 뒤쪽 칸부터 찾습니다.
	# 아이템 카드와 빈칸(기본 베기)은 대상이 아닙니다.
	if factory == null:
		return {}
	for index in range(factory.inventory.size() - 1, -1, -1):
		var stored: Dictionary = factory.inventory[index]
		if String(stored.get("kind", "skill")) == "item" or String(stored.get("id", "")) == "basic":
			continue
		return {"zone":"inventory", "index":index, "card":stored.duplicate(true)}
	for slot_index in range(factory.slots.size() - 1, -1, -1):
		var slot_card := factory.get_card(slot_index)
		if slot_card.is_empty() or String(slot_card.get("kind", "skill")) == "item":
			continue
		if String(slot_card.get("id", "")) == "basic":
			continue
		return {"zone":"rail", "slot":slot_index, "lane":0, "card":slot_card}
	return {}

func _take_factory_skill_card() -> Dictionary:
	var location := _last_factory_skill_location()
	if location.is_empty():
		return {}
	var removed := {}
	if String(location.get("zone", "")) == "inventory":
		removed = factory.remove_inventory_at(int(location["index"]))
	else:
		removed = factory.clear_slot(int(location["slot"]))
	_reset_player_cycle()
	return removed

func _use_service(service: String) -> void:
	if state != "camp":
		return
	var info := _service_info(service)
	var cost: int = info["cost"]
	if gold < cost:
		_show_banner("골드가 부족합니다 · 필요 %d G" % cost, GamePalette.RED, 2.0)
		return
	# 딜싸이클 개편 이후 스킬은 player.applied_skills가 아니라 FactoryDeck(보관함 + 레일)에
	# 보관됩니다. 예전 게이트는 항상 빈 배열을 봐서 두 NPC가 영구히 작동하지 않았습니다.
	if service in ["skill_remove", "skill_swap"] and _last_factory_skill_location().is_empty():
		_show_banner("지우거나 바꿀 스킬 카드가 없습니다", GamePalette.MUTED, 2.0)
		return
	if service == "boss_remove" and rejected_skills.is_empty():
		_show_banner("봉인할 마왕의 기술이 없습니다", GamePalette.MUTED, 2.0)
		return
	gold -= cost
	match service:
		"merchant":
			player.heal(45.0)
			_close_base_camp()
			_show_banner("약초로 체력 45 회복", GamePalette.GREEN, 2.2)
		"skill_remove":
			var removed_card := _take_factory_skill_card()
			var removed_id := String(removed_card.get("id", ""))
			selected_skills.erase(removed_id)
			rejected_skills.append(removed_id)
			_close_base_camp()
			var removed_name := String(DealCardLibrary.by_id(removed_id).get("name", removed_id))
			_show_banner("%s%s 지움 · 마왕이 가져감" % [removed_name, _particle_eul(removed_name)], GamePalette.RED, 2.7)
		"boss_remove":
			var sealed: String = String(rejected_skills.pop_back())
			_close_base_camp()
			_show_banner("마왕의 %s 봉인" % DealCardLibrary.by_id(sealed).get("name", sealed), GamePalette.BLUE, 2.5)
		"skill_swap":
			var discarded_card := _take_factory_skill_card()
			var discarded_id := String(discarded_card.get("id", ""))
			var discarded_rank := clampi(int(discarded_card.get("rank", 1)), 1, 5)
			selected_skills.erase(discarded_id)
			rejected_skills.append(discarded_id)
			# 같은 RANK로 바꿔 줍니다. 교체이지 강등이 아니기 때문입니다.
			# W9: `SKILLS` 전체(28종, legacy 8종 포함)가 아니라 v2 드래프트 풀 20종에서
			# 뽑는다(handoff-w7 §8 "새 카드를 주는 모든 경로는 draft_pool()").
			var replacement_pool := DealCardLibrary.draft_ids()
			var replacement_id := String(replacement_pool[rng.randi_range(0, replacement_pool.size() - 1)])
			factory.add_inventory(DealCardLibrary.instance(replacement_id, discarded_rank))
			selected_skills.append(replacement_id)
			_close_base_camp()
			_show_banner("%s → %s R%d · 보관함에 넣었습니다" % [
				DealCardLibrary.by_id(discarded_id).get("name", discarded_id),
				DealCardLibrary.by_id(replacement_id).get("name", replacement_id), discarded_rank
			], GamePalette.CYAN, 2.8)
		"armorer":
			_close_base_camp()
			call_deferred("_show_item_offer", "armorer")
		_:
			player.heal_full()
			_close_base_camp()
			_show_banner("여관에서 완전히 회복했습니다", GamePalette.YELLOW, 2.2)
	_update_hud()

# =============================================================================
# 카드 원소 조회 (V6 HUD 레일 마크가 쓴다 · V8이 각성 구역에서 구조해 온 함수)
# =============================================================================
## 카드 인스턴스(`{kind,id,rank}`)의 원소. **인스턴스에는 태그가 없다** —
## 원소·형태는 `DealCardLibrary`의 정의에만 있고 `ranked()`가 합쳐 준다.
## 저장 크기를 위해 일부러 그렇게 둔 것이라, 읽는 쪽이 매번 정의를 본다.
func _card_element(card: Dictionary) -> String:
	if card.is_empty():
		return ""
	var direct := String(card.get("element", ""))
	if not direct.is_empty():
		return direct
	var card_id := String(card.get("id", ""))
	if card_id.is_empty():
		return ""
	return String(DealCardLibrary.by_id(card_id).get("element", ""))

# =============================================================================
# V8: 보스 트로피 2택1 (설계 §5.5 · §2.1 · 부록 A-1 ⑨ · 부록 B V8 ①②③)
# =============================================================================
# v2에는 여기에 **각성 3화면**이 있었다: 계보 3종 택1(`lineage_choice`) → 전직 연출
# (`evolution`) → 특별 카드 2택1(`advancement_choice`). v3는 계보와 각성을 폐기하고
# (사용자 요구 · 부록 A-1 ⑥) 그 자산을 **보스 트로피 한 화면**으로 접었다.
#
#   v2                                v3 (여기)
#   ─────────────────────────────     ────────────────────────────────────────
#   계보 3종 택1 화면                 **삭제** (원소 축은 5칸 편성이 이미 정한다)
#   전직 연출(18줄 광선 + 초상)       트로피 모달의 **배경 연출로 이사**
#   특별 카드 2택1                    **그대로** — 상태 문자열까지 `advancement_choice`
#   `ClassLibrary.BRANCHES`           `TrophyLibrary.TROPHIES` (스테이지 1~5)
#   `tier1_effect`/`tier2_effect`     `TROPHIES[n].effect` (`_apply_class_effect` 무수정)
#
# 흐름 (`on_stage_boss_defeated` → 여기 → `_finish_factory_return` → 여기)
#
#   보스 격파
#     ├─ pending_stage_trophy = {...}          (V7이 채운다)
#     ├─ advance_stage()                        완전 회복 · 월드 재생성 (V5 파이프라인)
#     └─ call_deferred(_open_stage_trophy_choice)
#          ├─ player.apply_trophy(trophy)       ① **고정** 중립 스탯 보너스 (선택지 아님)
#          └─ state = "advancement_choice"      ② 특별 카드 2택1
#               └─ _choose_trophy_card()
#                    ├─ 고른 쪽 → factory_place 5칸 배치 흐름
#                    ├─ 버린 쪽 → 마왕에게 (rejected_skills + trophy_reject_skills
#                    │             + 고스트 레일 토스트 — 기존 전달 경로 그대로)
#                    └─ 배치 완료 → _finish_factory_return() → _finish_stage_trophy()
#                         └─ 5스테이지였다면 여기서 비로소 마왕전이 열린다
#
# ⚠️ **5스테이지 타이밍**(handoff-v7 §11-1의 경고 자리). 격파 콜백에서 곧바로
#    `_challenge_demon_king()`을 부르면 마왕 프리뷰가 트로피 모달을 덮어 5번째 트로피가
#    통째로 사라진다(설계 §5.5의 "5회 × 2장 = 10장"이 4회로 줄어든다). 그래서 마왕전
#    호출을 `pending_trophy_followup`으로 한 칸 미룬다 — **필드로 돌아가지 않는다**는
#    부록 A-1 ③은 그대로다. 모달이 화면을 덮고 있어 빈 필드는 한 프레임도 보이지 않는다.

## 트로피 모달 치수. v2 `advancement_choice`(1070×420)를 세로로 늘려 연출 머리를 넣었다.
## 세로 증명(패널 로컬): 트로피 머리말 18~150 / 카드 2장 162~458 / 안내 470~492 (패널 512)
const TROPHY_PANEL_RECT := Rect2(105.0, 96.0, 1070.0, 512.0)
const TROPHY_CARD_Y := 162.0

## 지금까지 획득한 트로피의 누적 효과. 결과 화면·저장(V9)·테스트의 단일 조회 창구다.
func trophy_effect_summary() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	return TrophyLibrary.merge_effects(player.trophy_stages)

## 이미 손에 있는 카드 id인가. 2택1이 "1택"이 되지 않게 하는 판정(TrophyLibrary 예비 규칙).
## 레일 5칸 · 보관함 · 이번 런에서 고른 적 있는 카드를 전부 본다.
func _owns_card_id(card_id: String) -> bool:
	if card_id.is_empty():
		return true
	if selected_skills.has(card_id):
		return true
	if factory == null:
		return false
	for owned: Dictionary in factory.get_all_owned_cards():
		if String(owned.get("id", "")) == card_id:
			return true
	return false

## 이 스테이지가 낼 2장. 이미 가진 카드는 `TrophyLibrary.RESERVE_CHOICES`로 갈아끼운다.
## (예비 2장까지 다 겹치면 원본을 그대로 낸다 — 빈 화면을 내는 것보다 낫다.)
func _resolve_trophy_choices(stage: int) -> Array[String]:
	var picked: Array[String] = []
	for card_id in TrophyLibrary.choices_for(stage):
		var resolved := card_id
		if _owns_card_id(resolved) or picked.has(resolved):
			for reserve in TrophyLibrary.RESERVE_CHOICES:
				if not _owns_card_id(reserve) and not picked.has(reserve):
					resolved = reserve
					break
		picked.append(resolved)
	return picked

# -----------------------------------------------------------------------------
# ① 트로피 제시 — 고정 스탯 보너스 + 카드 2택1 한 화면
# -----------------------------------------------------------------------------
func _open_stage_trophy_choice() -> void:
	var stage := int(pending_stage_trophy.get("stage", 0))
	var trophy := TrophyLibrary.for_stage(stage)
	if trophy.is_empty() or not is_instance_valid(player) or factory == null:
		# 배분표에 없는 스테이지(있어서는 안 되지만)라도 흐름은 끊지 않는다.
		_finish_stage_trophy()
		return
	# ── ① 고정 중립 스탯 보너스. **선택지가 아니다**(설계 §5.5). ──────────────
	player.apply_trophy(trophy)
	_reset_player_cycle()
	_update_hud()
	var choice_ids := _resolve_trophy_choices(stage)
	if choice_ids.size() != TrophyLibrary.CHOICES_PER_TROPHY:
		_finish_stage_trophy()
		return
	pending_trophy = {"trophy": trophy.duplicate(true), "choices": choice_ids.duplicate()}
	advancement_return_state = "playing"
	var trophy_color := Color(String(trophy.get("color", "f4d35e")))
	state = "advancement_choice"
	get_tree().paused = true
	_reset_choice_focus()
	_clear_overlay()
	spawn_burst(player.global_position, trophy_color, 64, 400.0, 1.2)
	# Y7(§7.1): 트로피 선택은 모달이다. 화면이 멈춘 채로 흔들리는 것은 타격감이
	# 아니라 오작동으로 읽힌다(흔들림 제거).
	play_sound("choice", 1.0)
	if automated_test:
		# 자동 테스트는 화면을 만들지 않고 왼쪽 카드를 확정한다(v2 각성과 같은 규약).
		call_deferred("_choose_trophy_card", String(choice_ids[0]), String(choice_ids[1]))
		return
	overlay = Control.new()
	overlay.name = "StageTrophyChoice"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_DEEP)
	# v2 전직 연출의 18줄 광선은 **남긴다.** 트윈 없는 정지 화면 한 장이라 §11을 어기지
	# 않고, 다섯 관문에서 다섯 번뿐인 보상 순간의 드라마를 프레임 말고는 낼 데가 없다.
	# 스크림이 더 짙어져 광선이 묻히므로 알파만 0.11 → 0.16으로 올렸다.
	for index in 18:
		var ray := ColorRect.new()
		ray.position = Vector2(640.0, 352.0)
		ray.size = Vector2(250.0 + index * 7.0, 3.0 if index % 2 else 6.0)
		ray.rotation = TAU * float(index) / 18.0
		ray.color = Color(trophy_color, 0.16)
		ray.pivot_offset = Vector2.ZERO
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(ray)
	# 보상 화면 = GOLD 껍데기 + WOOD 리본(§2 "트로피·보상·등급·황금 강조").
	var panel := _kit_shell(overlay, TROPHY_PANEL_RECT, "%d관문 격파 · %s" % [
		stage, TrophyLibrary.grade_name(String(trophy.get("grade", "")))
	], UIKit.Tone.GOLD, UIKit.Tone.WOOD, 460.0)
	panel.name = "StageTrophyPanel"
	_kit_label(panel, Rect2(40.0, 34.0, TROPHY_PANEL_RECT.size.x - 80.0, 34.0),
		String(trophy.get("name", "트로피")), UIKit.Tone.GOLD, UIKit.FONT_TITLE)
	var flavor := _kit_label(panel, Rect2(40.0, 68.0, TROPHY_PANEL_RECT.size.x - 460.0, 22.0),
		String(trophy.get("desc", "")), UIKit.Tone.GOLD, UIKit.FONT_BODY, true)
	flavor.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# 고정 보너스는 "이미 받았다"고 말한다 — 고를 수 있는 것처럼 보이면 안 된다.
	# 체크 글리프 + GOLD 칩. 카드(고르는 것)와 칩(이미 받은 것)이 기하로 갈린다.
	var granted_rect := Rect2(TROPHY_PANEL_RECT.size.x - 412.0, 62.0, 372.0, 34.0)
	_kit_panel(panel, granted_rect, UIKit.Tone.GOLD, UIKit.Role.CHIP)
	_kit_glyph(panel, granted_rect.position + Vector2(12.0, 8.0), "check",
		UIKit.text_on(UIKit.Tone.GOLD, UIKit.Role.CHIP), 18.0)
	_kit_label(panel, Rect2(granted_rect.position + Vector2(38.0, 0.0), Vector2(322.0, 34.0)),
		"획득 확정 · %s" % String(trophy.get("effect_desc", "")),
		UIKit.Tone.GOLD, UIKit.FONT_LABEL, false, UIKit.Role.CHIP)
	# 카드 두 장이 앉는 무대는 SLATE 함몰이다 — 밝은 금빛 껍데기 위에 그대로 두면
	# 카드가 나르는 의미색(CYAN 태그 · ORANGE RELOAD · GREEN 보유)이 전부 무너진다.
	# U1이 온보딩에서 쓴 "모달 안에 뚫린 필드 창"과 같은 수법이다(handoff-u1 §2.4).
	_kit_panel(panel, Rect2(16.0, 108.0, TROPHY_PANEL_RECT.size.x - 32.0, 314.0),
		UIKit.Tone.SLATE, UIKit.Role.INSET)
	_kit_label(panel, Rect2(40.0, 114.0, TROPHY_PANEL_RECT.size.x - 80.0, 22.0),
		"이제 특별 카드 한 장을 고릅니다.  버린 한 장은 마왕에게 갑니다 — 고스트 레일에 그대로 들어섭니다.",
		UIKit.Tone.SLATE, UIKit.FONT_LABEL, false, UIKit.Role.INSET)
	for index in TrophyLibrary.CHOICES_PER_TROPHY:
		var selected_id := String(choice_ids[index])
		var rejected_id := String(choice_ids[1 - index])
		var definition := DealCardLibrary.by_id(selected_id)
		# 트로피 2택은 스킬 카드가 아니라 **트로피 카드**다(GOLD · 왕관 문양).
		# X1: 프레임 종류를 인자로 넘긴다 — 넘겨야 원소 틴트가 GOLD 프레임을 덮지 않는다.
		var button := _deal_choice_button(definition, Vector2(494.0, CHOICE_CARD_SIZE.y), 3)
		button.position = Vector2(24.0 + index * 528.0, TROPHY_CARD_Y)
		panel.add_child(button)
		_register_choice_button(button, "skill", _choose_trophy_card.bind(selected_id, rejected_id))
	_kit_label(panel, Rect2(20.0, TROPHY_PANEL_RECT.size.y - 44.0, TROPHY_PANEL_RECT.size.x - 40.0, 24.0),
		"← 왼쪽 카드   ·   → 오른쪽 카드   ·   SPACE 결정   ·   고르지 않고 넘어갈 수 없습니다",
		UIKit.Tone.GOLD, UIKit.FONT_LABEL, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 18.0))
	_set_choice_index(0)

# -----------------------------------------------------------------------------
# ② 카드 확정 — 고른 쪽은 레일로, 버린 쪽은 마왕에게
# -----------------------------------------------------------------------------
func _choose_trophy_card(selected_id: String, rejected_id: String) -> void:
	if state != "advancement_choice" or pending_trophy.is_empty():
		return
	var trophy: Dictionary = pending_trophy.get("trophy", {})
	var stage := int(trophy.get("stage", 0))
	var selected_definition := DealCardLibrary.by_id(selected_id)
	var rejected_definition := DealCardLibrary.by_id(rejected_id)
	selected_skills.append(selected_id)
	rejected_skills.append(rejected_id)
	# 마왕 성장 경로는 v2와 **한 글자도 다르지 않다**(`demon_lord.gd`가 이 배열을 읽는다).
	# `branch` 자리에 트로피 id가, `tier` 자리에 스테이지 번호가 들어간다.
	trophy_reject_skills.append({
		"branch": String(trophy.get("id", "")), "tier": stage,
		"name": rejected_definition.get("name", "트로피 카드"),
		"module": DealCardLibrary.debt_module(rejected_id)
	})
	player.class_skill_id = selected_id
	player.class_skill_name = String(selected_definition.get("name", "트로피 기술"))
	pending_boss_toast_cards = [rejected_definition]
	pending_trophy.clear()
	trophy_place_pending = true
	_clear_overlay()
	# 스킬 카드면 5칸 배치 흐름으로, 아이템이면 `place_card`가 장비로 우회시킨다.
	_show_factory_menu("place", DealCardLibrary.instance(selected_id, 1), advancement_return_state)
	_show_banner("%s · %s 획득 · %s" % [
		String(trophy.get("name", "트로피")), String(selected_definition.get("name", "특별 카드")),
		String(trophy.get("effect_desc", ""))
	], Color(String(trophy.get("color", "f4d35e"))), 4.0)

# -----------------------------------------------------------------------------
# ③ 마무리 — 배치까지 끝난 뒤의 후속(5스테이지면 마왕전)
# -----------------------------------------------------------------------------
## `_finish_factory_return()`이 `trophy_place_pending`을 보고 한 프레임 뒤에 부른다.
## 트로피 없이 흐름만 이어야 하는 예외 경로(배분표 결손)에서도 같은 함수를 쓴다.
func _finish_stage_trophy() -> void:
	pending_stage_trophy.clear()
	pending_trophy.clear()
	trophy_place_pending = false
	var followup := pending_trophy_followup
	pending_trophy_followup = ""
	if followup != "demon":
		return
	# **5스테이지 격파 → 필드 복귀 없이 마왕전**(부록 A-1 ③ · 설계 §2.1).
	# `_on_stage_started()`의 `is_run_complete()` 가드가 월드 재생성을 막아 둔 상태다.
	_show_banner("다섯 관문이 모두 열렸습니다 — 마왕이 당신을 기다립니다", GamePalette.RED, 2.4)
	call_deferred("_challenge_demon_king")

func _close_base_camp() -> void:
	if state != "camp":
		return
	# Y6: 유랑 상인은 **한 번뿐**이다(§6.2). 창구를 닫는 순간 사건이 끝난다.
	_close_field_merchant()
	_clear_overlay()
	get_tree().paused = false
	state = "castle_interior" if inside_castle else "playing"
	# 필드에서 바로 연 NPC/캠프 모달이면 필드 복귀 무적을 준다(성 내부는 전투가 없어 제외).
	_grant_modal_return_invulnerability()
	interaction_timer = 0.0

# =============================================================================
# W10: 마왕 프리뷰 v2 — 내 5칸 vs 마왕 5칸 (설계 §8.4)
# =============================================================================
# 설계 §8.4: "편집 화면과 **픽셀 동일한 레일 렌더러**로 마왕의 5칸 + 각인 + 흐름 아크를
# 그린다. 내 레일과 나란히 비교 가능."
#
# v1 렌더러(`_build_factory_rail_slot` 200×142 + ScrollContainer)를 걷어내고
# W6의 편집 레일 치수(196×150 · pitch 240 · 콘텐츠 1,156px)를 **읽기 전용**으로 재사용한다.
# 두 레일이 같은 크기·같은 카드 블록·같은 각인 핍 공식을 쓰므로 눈이 바로 대조할 수 있다.
#   세로 증명(패널 로컬): 머리말 16~70 / 내 레일 76~288 / 마왕 레일 296~508 /
#                         비교 칩 514~566 / 버튼 574~626 / 안내 632~652  (패널 668)
#   가로 증명: (1,220 − 1,156) / 2 = 32 → 좌우 여백 32px. ScrollContainer 0개.
const BOSS_PREVIEW_PANEL_RECT := Rect2(30.0, 26.0, 1220.0, 668.0)
const BOSS_PREVIEW_BODY_X := 28.0
const BOSS_PREVIEW_BODY_W := 1164.0
const PREVIEW_RAIL_ORIGIN_X := 32.0
const PREVIEW_MY_LABEL_Y := 74.0
const PREVIEW_MY_ARC := Rect2(32.0, 96.0, 1156.0, 40.0)
const PREVIEW_MY_RAIL_Y := 138.0
const PREVIEW_BOSS_LABEL_Y := 294.0
const PREVIEW_BOSS_ARC := Rect2(32.0, 316.0, 1156.0, 40.0)
const PREVIEW_BOSS_RAIL_Y := 358.0
const PREVIEW_CHIP_RECT := Rect2(28.0, 514.0, 1164.0, 52.0)
# 두 덱을 각각 돌리므로 편집 화면(96)의 절반을 쓴다. 실측 ~4ms × 2 = 모달 1회 8ms.
const PREVIEW_SAMPLES := 48

# =============================================================================
# V7: 마왕전 진입 경로는 **정확히 하나다** (부록 A-1 ③ · 설계 §2.1)
# =============================================================================
# v2에는 셋이 있었다: ①마왕성 랜드마크에서 E ②7일차 밤 끝의 강림 ③디버그.
# v3에서 ①은 랜드마크 자체가 없어졌고(`world_grid`가 `demon_castle`을 만들지 않는다)
# ②는 클럭이 `descent_triggered`를 더 이상 쏘지 않는다(V4가 스케줄을 삭제했다).
# **남는 것은 "5스테이지 보스 격파 → 즉시 마왕전" 하나뿐이다.**
# 강림 밸브(§6.6)는 마왕이 아니라 **그 스테이지 보스**를 부르는 장치이고, 5스테이지에서
# 밸브를 밟으면 C+를 잡은 뒤 같은 콜백으로 마왕전에 들어간다 — 즉 밸브는 마왕전의
# 두 번째 경로가 아니라 같은 경로의 다른 입구다.
#
# ⚠️ 격파 콜백은 `state == "boss"`에서 벗어난 직후에 부르므로 `playing` 가드를 유지하되,
#    `--boss-test`·`--v4-test`·`--cycle-test`가 필드에서 직접 부르는 경로도 그대로 산다.
func _challenge_demon_king() -> void:
	if state != "playing" or not is_instance_valid(player):
		return
	boss_factory = _build_boss_factory()
	boss_preview_kind = "demon"
	state = "boss_preview"
	get_tree().paused = true
	current_interactable.clear()
	interaction_text.visible = false
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "BossDealCyclePreview"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_DEEP)
	var panel := _kit_shell(overlay, BOSS_PREVIEW_PANEL_RECT, "마왕의 딜싸이클 — 도전 확인",
		UIKit.Tone.ABYSS, UIKit.Tone.EMBER, 540.0)
	panel.name = "BossPreviewPanel"
	_build_boss_preview_header(panel)
	_build_boss_preview_rails(panel)
	_build_boss_preview_compare(panel)

	var challenge := _button("그래도 들어간다 · SPACE", GamePalette.RED, Vector2(330.0, 52.0))
	challenge.position = Vector2(BOSS_PREVIEW_PANEL_RECT.size.x * 0.5 - 344.0, 574.0)
	challenge.pressed.connect(_begin_boss_battle)
	panel.add_child(challenge)
	var retreat := _button("돌아가서 준비한다 · ESC", GamePalette.MUTED, Vector2(330.0, 52.0))
	retreat.position = Vector2(BOSS_PREVIEW_PANEL_RECT.size.x * 0.5 + 14.0, 574.0)
	retreat.pressed.connect(_cancel_boss_preview)
	panel.add_child(retreat)
	_kit_label(panel, Rect2(BOSS_PREVIEW_BODY_X, 632.0, BOSS_PREVIEW_BODY_W, 20.0),
		"마왕: \"네가 버린 모든 선택이 내 손에서 하나의 고리가 되었다.\"   ·   바퀴가 도는 동안 피하고, RELOAD가 오면 때려라",
		UIKit.Tone.ABYSS, UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	challenge.grab_focus()

func _build_boss_preview_header(panel: Control) -> void:
	var day := day_number
	var summary := boss_growth_preview()
	_kit_panel(panel, Rect2(BOSS_PREVIEW_BODY_X, 32.0, BOSS_PREVIEW_BODY_W, 38.0),
		UIKit.Tone.ABYSS, UIKit.Role.INSET)
	# 지금 들어가면 무엇을 얻고 무엇을 감수하는가 — 기한이 만드는 의사결정(§4.3)을 숫자로 건다.
	var grade := demon_lord.victory_grade(day, clock.descended)
	var status := _label("%d일차 · 승리 시 등급 %s · 마왕 체력 ×%.2f · RELOAD ×%.1f" % [day, grade, float(summary.get("hp_multiplier", 1.0)), GameTuning.BOSS_RELOAD_MUL], UI_LABEL_SIZE, GamePalette.RED.lightened(0.16))
	status.position = Vector2(BOSS_PREVIEW_BODY_X + BOSS_PREVIEW_BODY_W - 532.0, 34.0)
	status.size = Vector2(520.0, 18.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(status)
	# 한글 라벨에 마크다운을 쓰지 않는다(handoff-w6 §9-5: Godot Label은 별표를 그대로 그린다).
	# YZ(피드백 ① · ⑤): 네 문장을 한 문장으로 줄였다. 나머지 셋은 아래 두 레일 그림이
	# 그대로 보여 주는 내용이라 글자로 한 번 더 말할 필요가 없다.
	var subtitle := _label("마왕도 같은 규칙으로 돕니다 — 한 칸 %d번까지. 다른 것은 RELOAD가 당신의 %.0f%%라는 점뿐입니다." % [RuneEngine.SLOT_EXEC_CAP, GameTuning.BOSS_RELOAD_MUL * 100.0], UI_BODY_SIZE, GamePalette.MUTED)
	subtitle.position = Vector2(BOSS_PREVIEW_BODY_X + 14.0, 50.0)
	subtitle.size = Vector2(BOSS_PREVIEW_BODY_W - 28.0, 18.0)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(subtitle)

func _build_boss_preview_rails(panel: Control) -> void:
	var summary := boss_growth_preview()
	# --- 내 5칸 ---
	var my_runes := factory.total_rune_count() if factory != null else 0
	_build_preview_section_label(panel, PREVIEW_MY_LABEL_Y, "내 5칸", GamePalette.CYAN,
		"각인 %d개  ·  한 바퀴 RELOAD 빚 %.2f초  ·  장비 %d / %d" % [
			my_runes, factory.total_reload() if factory != null else 0.0,
			factory.equipment.size() if factory != null else 0, FactoryDeck.EQUIPMENT_PARTS.size()])
	# 프리뷰의 아크 밴드는 편집 화면(62px)보다 낮으므로 레인 간격을 줄인다.
	_build_edit_flow_arcs(panel, factory, PREVIEW_MY_ARC, PREVIEW_RAIL_ORIGIN_X, 11.0)
	for index in (factory.slots.size() if factory != null else 0):
		_build_preview_slot(panel, factory, index, Vector2(PREVIEW_RAIL_ORIGIN_X, PREVIEW_MY_RAIL_Y), GamePalette.CYAN, true)
	# --- 마왕 5칸 ---
	# Y3(§8 ⑪): 각인 이름은 **항상 열려 있다.** 밀정 열람이 무료·기본 공개가 되면서
	# "돈을 냈는가"라는 분기 자체가 사라졌다(구 `spy_revealed`).
	var boss_runes := boss_factory.total_rune_count()
	_build_preview_section_label(panel, PREVIEW_BOSS_LABEL_Y, "마왕의 5칸", GamePalette.RED,
		"각인 %d개  ·  받은 카드 %d장  ·  잔재 %d  ·  뜯어낸 각인 %d  ·  회수한 카드 %d" % [
			boss_runes, int(summary.get("cards_received", 0)), int(summary.get("residue", 0)),
			int(summary.get("stripped", 0)), int(summary.get("reclaimed", 0))])
	_build_edit_flow_arcs(panel, boss_factory, PREVIEW_BOSS_ARC, PREVIEW_RAIL_ORIGIN_X, 11.0)
	for index in boss_factory.slots.size():
		_build_preview_slot(panel, boss_factory, index, Vector2(PREVIEW_RAIL_ORIGIN_X, PREVIEW_BOSS_RAIL_Y), GamePalette.RED, true)

func _build_preview_section_label(panel: Control, y: float, heading: String, color: Color, detail: String) -> void:
	var bar := ColorRect.new()
	bar.position = Vector2(PREVIEW_RAIL_ORIGIN_X, y + 2.0)
	bar.size = Vector2(3.0, 16.0)
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	var title := _label(heading, UI_HEADING_SIZE, color)
	title.position = Vector2(PREVIEW_RAIL_ORIGIN_X + 11.0, y)
	title.size = Vector2(300.0, 20.0)
	panel.add_child(title)
	var info := _label(detail, UI_CAPTION_SIZE, GamePalette.MUTED)
	info.position = Vector2(PREVIEW_RAIL_ORIGIN_X + 320.0, y + 2.0)
	info.size = Vector2(1156.0 - 320.0, 18.0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(info)

# 읽기 전용 레일 칸. `_build_edit_slot`(W6)과 **좌표·크기·계층이 같다** — 다른 것은
# 버튼·드래그·`factory_lane_buttons` 등록이 없다는 점뿐이다(설계 §8.4의 "픽셀 동일").
func _build_preview_slot(panel: Control, deck: FactoryDeck, slot_index: int, origin: Vector2, accent: Color, reveal_runes: bool) -> Panel:
	var slot_card: Dictionary = deck.get_card(slot_index)
	var runes: Array = deck.runes_on(slot_index)
	var cell := Panel.new()
	cell.name = "PreviewSlot%d_%d" % [int(origin.y), slot_index]
	cell.position = origin + Vector2(float(slot_index) * EDIT_RAIL_PITCH, 0.0)
	cell.size = EDIT_CARD_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.set_meta("slot_index", slot_index)
	cell.set_meta("rune_count", runes.size())
	cell.set_meta("card_id", String(slot_card.get("id", "")))
	# U2 v3: 편집 화면 칸과 **같은 킷 기하**다. 내 레일은 카드 프레임(SKILL/ITEM),
	# 마왕·보스 레일은 BOSS 프레임(EMBER·뿔)이라 두 줄이 한눈에 갈린다(§8.4 "픽셀 동일").
	var preview_kind := 4 if accent.is_equal_approx(GamePalette.RED) else \
		(1 if String(slot_card.get("kind", "skill")) == "item" else 0)
	if slot_card.is_empty() and preview_kind != 4:
		UIKit.style_panel(cell, UIKit.Tone.SLATE, UIKit.Role.CELL)
	else:
		cell.add_theme_stylebox_override("panel", _kit_card_box(preview_kind, 0))
	cell.tooltip_text = _preview_slot_tooltip(deck, slot_index)
	panel.add_child(cell)
	var header_label := _label("칸 %02d" % (slot_index + 1), UI_LABEL_SIZE, accent.lightened(0.24))
	header_label.position = Vector2(EDIT_SLOT_PAD, 16.0)
	header_label.size = Vector2(108.0, EDIT_SLOT_HEADER_H)
	cell.add_child(header_label)
	var rune_color := GamePalette.MUTED.darkened(0.2)
	if runes.size() >= RuneEngine.RUNE_STACK_CAP:
		rune_color = GamePalette.RED
	elif runes.size() > RuneEngine.RUNE_SLOTS_PER_SLOT:
		rune_color = GamePalette.ORANGE
	elif runes.size() > 0:
		rune_color = GamePalette.YELLOW
	var rune_tag := _label("각인 %d/%d" % [runes.size(), RuneEngine.RUNE_STACK_CAP], UI_CAPTION_SIZE, rune_color)
	rune_tag.position = Vector2(EDIT_CARD_SIZE.x - EDIT_SLOT_PAD - 74.0, 16.0)
	rune_tag.size = Vector2(74.0, EDIT_SLOT_HEADER_H)
	rune_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell.add_child(rune_tag)
	# 카드 블록 — 전 화면 공용 렌더러. 편집 화면의 안쪽 버튼과 같은 칩 층을 쓴다.
	var block := _kit_panel(cell, EDIT_SLOT_CARD_RECT, UIKit.Tone.SLATE, UIKit.Role.CHIP)
	_paint_card_block(block, slot_card, EDIT_SLOT_CARD_RECT.size)
	# 각인 줄 — W5 필드 HUD·W6 편집 화면과 같은 3핍 + "+N" 공식.
	#
	# ⚠️ YZ 수리 (handoff-y4 §8.4 「공유 렌더러 글자 겹침」의 앞쪽 한 건).
	#    이 줄은 지금까지 **카드 프레임(주황) 위에 맨몸으로** 놓여 있었고, 이름을
	#    전부 「 · 」로 이어 붙였다. 결과 화면 실측에서 두 가지가 같이 터졌다.
	#      ① 11px 한글의 획 사이는 1px인데 외곽선이 2px이라 주황 바탕에서 옆 글자와
	#         **달라붙는다** — 「힘주기 · 한 칸 건너뛰기」가 한 덩어리로 읽혔다.
	#      ② 각인 3개가 붙으면 30자가 넘어 114px 자리를 통째로 넘긴다.
	#    고친 방식 둘:
	#      ① 지속/RELOAD 칩과 **같은 어두운 판**을 깔고 그 위에서 외곽선을 끈다
	#         (ui-style-v3 §3 "패널 안에서는 아예 끈다"). `Panel`이 아니라
	#         `ColorRect`라 판 개수를 세는 검사(`hud_rail`·`hud_ghost`)와 무관하다.
	#      ② 이름은 **하나만** 적고 나머지는 「외 N」으로 접는다. 전체 목록과 확률은
	#         칸 툴팁(`_preview_slot_tooltip`)이 그대로 들고 있다 — 정보 손실 0.
	var rune_plate := ColorRect.new()
	rune_plate.position = Vector2(EDIT_SLOT_PAD, EDIT_SLOT_RUNE_Y - 1.0)
	rune_plate.size = Vector2(EDIT_CARD_SIZE.x - EDIT_SLOT_PAD * 2.0, 17.0)
	rune_plate.color = Color(UI_CHIP_BG, 0.88)
	rune_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(rune_plate)
	var row := Control.new()
	row.position = Vector2(EDIT_SLOT_PAD, EDIT_SLOT_RUNE_Y)
	row.size = Vector2(EDIT_CARD_SIZE.x - EDIT_SLOT_PAD * 2.0, 16.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	var shown := mini(runes.size(), RuneEngine.RUNE_SLOTS_PER_SLOT)
	for pip_index in RuneEngine.RUNE_SLOTS_PER_SLOT:
		var pip := ColorRect.new()
		pip.position = Vector2(4.0 + float(pip_index) * 13.0, 3.0)
		pip.size = Vector2(9.0, 9.0)
		pip.color = _rune_rarity_color(String((runes[pip_index] as Dictionary).get("id", ""))) if pip_index < shown else Color(UI_EDGE_SOFT, 0.55)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	var caption_text := "각인 없음"
	if runes.size() > 0:
		caption_text = _preview_rune_caption(runes) if reveal_runes else "각인 %d개 · 안 보임" % runes.size()
	var caption := _label(caption_text, UI_CAPTION_SIZE, accent.lightened(0.24) if runes.size() > 0 else GamePalette.MUTED)
	# 어두운 판 위라 외곽선을 끈다 — 켜 두면 11px 한글이 서로 붙는다.
	caption.add_theme_constant_override("outline_size", 0)
	caption.position = Vector2(PREVIEW_RUNE_CAPTION_X, 0.0)
	caption.size = Vector2(EDIT_CARD_SIZE.x - EDIT_SLOT_PAD * 2.0 - PREVIEW_RUNE_CAPTION_X - 4.0, 16.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(caption)
	return cell

## 각인 줄 글자 자리. 핍 3개(4 + 13×2 + 9 = 39)가 끝나는 곳에서 6px 띄운다.
const PREVIEW_RUNE_CAPTION_X := 45.0
## 그 자리에 11px 한글이 안 뭉개고 들어가는 글자 수. 115px ÷ 11px ≈ 10자다.
const PREVIEW_RUNE_CAPTION_CHARS := 10

## 각인 줄에 적을 한 줄 — **이름 하나 + 「외 N」**이다.
## 전부 이어 붙이면 3개가 붙은 칸에서 30자가 넘어 글자가 서로 뭉갠다(YZ 수리).
## 붙은 각인 전체와 발동 확률은 칸 툴팁이 그대로 보여 준다.
func _preview_rune_caption(runes: Array) -> String:
	if runes.is_empty():
		return "각인 없음"
	var first_id := String((runes[0] as Dictionary).get("id", ""))
	var first := String((RuneEngine.RUNES.get(first_id, {}) as Dictionary).get("name", "각인"))
	if runes.size() == 1:
		return _trim_to_chars(first, PREVIEW_RUNE_CAPTION_CHARS)
	var tail := " 외 %d" % (runes.size() - 1)
	return "%s%s" % [_trim_to_chars(first, PREVIEW_RUNE_CAPTION_CHARS - tail.length()), tail]

## 글자 수로 자르고 넘치면 말줄임표를 붙인다. 한글 1음절 = 1자다(`String.length()`).
func _trim_to_chars(text: String, limit: int) -> String:
	if limit <= 1 or text.length() <= limit:
		return text
	return text.substr(0, limit - 1) + "…"

func _preview_slot_tooltip(deck: FactoryDeck, slot_index: int) -> String:
	var lines: Array[String] = ["칸 %02d — %s" % [slot_index + 1, _factory_card_name(deck.get_card(slot_index))]]
	var runes: Array = deck.runes_on(slot_index)
	if runes.is_empty():
		lines.append("각인 없음")
	for rune_value in runes:
		var rune: Dictionary = rune_value
		var rune_id := String(rune.get("id", ""))
		var definition: Dictionary = RuneEngine.RUNES.get(rune_id, {})
		var probability := _slot_rune_probability(slot_index, rune_id, deck)
		lines.append("· %s  %s" % [
			String(definition.get("name", rune_id)),
			"확정" if not bool(definition.get("roll", true)) else "%d%%" % int(round(probability * 100.0))
		])
	return "\n".join(lines)

# 두 덱을 같은 표본 수·같은 시드로 돌려 나란히 비교한다. Δ는 "마왕 − 나"다.
func _build_boss_preview_compare(panel: Control) -> void:
	var box := Panel.new()
	box.name = "BossPreviewCompare"
	box.position = PREVIEW_CHIP_RECT.position
	box.size = PREVIEW_CHIP_RECT.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_panel(box, UIKit.Tone.ABYSS, UIKit.Role.INSET)
	panel.add_child(box)
	var compare_seed := run_cycle_seed | 1
	var mine := _factory_preview_summary(factory.rune_deck() if factory != null else [], compare_seed, PREVIEW_SAMPLES)
	var theirs := _factory_preview_summary(boss_factory.rune_deck(), compare_seed, PREVIEW_SAMPLES, {"reload_scale": GameTuning.BOSS_RELOAD_MUL})
	var heading := _label("한 화면 비교 · %d번씩 굴림" % PREVIEW_SAMPLES, UI_CAPTION_SIZE, GamePalette.CYAN)
	heading.position = Vector2(12.0, 3.0)
	heading.size = Vector2(240.0, 16.0)
	box.add_child(heading)
	var rows := [
		{"caption": "평균 스텝", "mine": "%.2f" % float(mine.get("mean_steps", 0.0)), "boss": "%.2f" % float(theirs.get("mean_steps", 0.0))},
		{"caption": "평균 피해", "mine": "%.1f" % float(mine.get("mean_damage", 0.0)), "boss": "%.1f" % float(theirs.get("mean_damage", 0.0))},
		{"caption": "한 바퀴", "mine": "%.2f초" % float(mine.get("mean_time", 0.0)), "boss": "%.2f초" % float(theirs.get("mean_time", 0.0))},
		{"caption": "RELOAD 창", "mine": "%.2f초" % float(mine.get("mean_reload", 0.0)), "boss": "%.2f초" % float(theirs.get("mean_reload", 0.0))},
		{"caption": "평균 밟은 칸", "mine": "%.2f" % float(mine.get("mean_exec_slots", 0.0)), "boss": "%.2f" % float(theirs.get("mean_exec_slots", 0.0))},
		{"caption": "바퀴 상한", "mine": "%.0f%%" % (float(mine.get("overload_rate", 0.0)) * 100.0), "boss": "%.0f%%" % (float(theirs.get("overload_rate", 0.0)) * 100.0)}
	]
	var column_w := (PREVIEW_CHIP_RECT.size.x - 268.0) / float(rows.size())
	for index in rows.size():
		var row: Dictionary = rows[index]
		var x := 260.0 + float(index) * column_w
		var caption := _label(String(row["caption"]), UI_CAPTION_SIZE, GamePalette.MUTED)
		caption.position = Vector2(x, 3.0)
		caption.size = Vector2(column_w - 8.0, 16.0)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(caption)
		var mine_label := _label(String(row["mine"]), UI_LABEL_SIZE, GamePalette.CYAN)
		mine_label.position = Vector2(x, 19.0)
		mine_label.size = Vector2(column_w - 8.0, 17.0)
		mine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(mine_label)
		var boss_label := _label(String(row["boss"]), UI_LABEL_SIZE, GamePalette.RED.lightened(0.16))
		boss_label.position = Vector2(x, 34.0)
		boss_label.size = Vector2(column_w - 8.0, 17.0)
		boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(boss_label)
	var legend_mine := _label("■ 나", UI_CAPTION_SIZE, GamePalette.CYAN)
	legend_mine.position = Vector2(12.0, 20.0)
	legend_mine.size = Vector2(120.0, 16.0)
	box.add_child(legend_mine)
	var legend_boss := _label("■ 마왕", UI_CAPTION_SIZE, GamePalette.RED.lightened(0.16))
	legend_boss.position = Vector2(12.0, 35.0)
	legend_boss.size = Vector2(120.0, 16.0)
	box.add_child(legend_boss)

func _cancel_boss_preview() -> void:
	# 마왕성에서 E를 누른 순간 되돌릴 수 없던 문제(P1-2). 필드로 그대로 되돌리고
	# 다른 모달과 같은 복귀 무적을 줍니다.
	# V7: 스테이지 보스 프리뷰도 같은 함수로 물러난다(설계 §3.5 "취소 가능").
	if state != "boss_preview":
		return
	var was_stage := boss_preview_kind == "stage"
	if was_stage:
		stage_boss_factory = null
		stage_boss_profile.clear()
	boss_preview_kind = "demon"
	_clear_overlay()
	get_tree().paused = false
	state = "playing"
	current_interactable.clear()
	interaction_timer = 0.0
	_grant_modal_return_invulnerability()
	_show_banner(
		"보스문 앞에서 물러났습니다 · 준비가 되면 다시 E" if was_stage else "마왕성 앞에서 물러났습니다 · 준비가 되면 다시 E",
		GamePalette.MUTED, 2.2)

# =============================================================================
# W10: 마왕의 5칸 공장 (설계 §6.1)
# =============================================================================
# 배치 규칙은 전부 `DemonLord`가 소유한다 — 여기서는 옮겨 담기만 한다.
#   ① 같은 id 자동 합성(랭크 상승)        → demon_lord.auto_fused_cards()
#   ② expected_power 상위 5장이 1~5칸     → demon_lord.slot_layout()
#   ③ 나머지는 잔재 → 밤 몹 모듈(§6.4)    → demon_lord.residue_modules() (월식이 100% 부여)
#   ④ 버린 아이템은 레일이 아니라 장비(§5.4)
# handoff-w4 §6이 "W10이 game.gd의 `_boss_auto_fused_cards()`를 지우고 DemonLord로
# 일원화하라"고 지정했다 — 이번 웨이브에서 삭제했다(호출부 0이었다).
func _build_boss_factory() -> FactoryDeck:
	var deck: FactoryDeck = FACTORY_SCRIPT.new()
	deck.reset(GameTuning.BOSS_SLOT_COUNT)
	# 각인 id가 자리표시자로 남지 않게 카탈로그를 한 번 더 확인한다(_ready에서 이미 주입됨).
	if demon_lord.rune_catalog.is_empty():
		demon_lord.set_rune_catalog(RuneEngine.ids_by_scope("slot"))
	demon_lord.sync_runes(rng)
	for entry: Dictionary in demon_lord.slot_layout():
		var slot_index := int(entry.get("index", 0))
		var card: Dictionary = entry.get("card", {})
		if not card.is_empty():
			deck.place_card(slot_index, card.duplicate(true))
		for granted: Dictionary in (entry.get("runes", []) as Array):
			# 한 칸 상한(5개 / 같은 id 3개)을 넘는 각인은 attach_rune이 거부한다.
			# 마왕 각인은 최대 14개라 5칸에 몰리면 넘칠 수 있다 — 거부되면 그 각인은
			# 그냥 붙지 않는다(상한은 플레이어와 마왕에게 똑같이 적용되는 규칙이다).
			deck.attach_rune(slot_index, RuneEngine.roll_rune(String(granted.get("rune_id", "")), rng))
	for item_id: String in boss_items:
		deck.equip(ItemLibrary.instance(item_id))
	return deck

# =============================================================================
# W10: 마왕전 개시 — 자발적 도전 · 강림 공용 경로
# =============================================================================
# 마왕은 플레이어와 **완전히 같은 런타임**을 쓴다(§6.2). 다른 것은 두 가지뿐이다.
#   * `reload_scale = 0.6` — 빚 청산이 빠르다. 그래도 반격 창은 반드시 존재한다.
#   * `hp_multiplier(day)` — 늦게 올수록 두껍다(§4.3 · 강림이면 ×1.15가 이미 포함).
func _begin_boss_battle() -> void:
	if state != "boss_preview":
		return
	_clear_overlay()
	get_tree().paused = false
	state = "boss"
	current_interactable.clear()
	interaction_text.visible = false
	for enemy: Node in combat.active_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	combat.active_enemies.clear()
	combat.enemy_spatial.clear()
	for orb: Node in get_tree().get_nodes_in_group("xp_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	var boss_position: Vector2 = _find_visible_boss_position()
	boss = ENEMY_SCRIPT.new()
	var power_level := float(cycle_number + level) * 0.7
	var boss_debts: Array[String] = rejected_skills.duplicate()
	for inherited_skill: Dictionary in trophy_reject_skills:
		boss_debts.append(String(inherited_skill["module"]))
	boss.setup(self, player, "demon_king", 4, power_level, boss_debts, true, false, boss_items)
	# 설계 §4.3/§9.4의 HP 배율. W9까지 이 숫자는 HUD 고스트 레일에 **표시만** 되고
	# 실제 체력에는 걸리지 않았다. 여기서 한 번만 곱한다.
	# (V7 메모: `hp_multiplier()`가 품고 있는 ×1.15 강림 보정은 **v2 마왕 강림**의 것이고
	#  그 경로는 삭제됐다. `demon_lord.descended`는 이제 아무도 세우지 않으므로 사실상 1.0이다.
	#  v3의 "강림"은 스테이지 보스 밸브(§6.6)이고 그쪽 배율은 `STAGE_DESCENT_HP_MUL`이다.)
	var hp_scale := demon_lord.hp_multiplier(day_number)
	boss.max_health *= hp_scale
	boss.health = boss.max_health
	boss.displayed_health = boss.health
	boss.trailing_health = boss.health
	boss.position = boss_position
	gameplay_root.add_child(boss)
	boss.use_external_deal_cycle(true)
	boss_cycle = CYCLE_CONTROLLER_SCRIPT.new()
	# Y2: 마왕에게도 칸당 실행 상한·빚 RELOAD가 그대로 적용된다. 배율만 ×0.6 (§6.2).
	boss_cycle.setup(self, boss, boss_factory, true, true, run_cycle_seed + 5701)
	gameplay_root.add_child(boss_cycle)
	boss_peak_steps = 0
	boss_reload_windows = 0
	boss_reload_open = false
	boss_rail_bound_cycle = null
	boss_panel.visible = true
	if is_instance_valid(boss_rail_band):
		boss_rail_band.visible = true
	_update_boss_rail(0.0)
	update_boss_health(boss.health, boss.max_health, boss.shield, boss.max_shield)
	_show_banner("딜싸이클 마왕 · %d칸 / 각인 %d개 / 체력 ×%.2f / RELOAD ×%.1f — 바퀴가 도는 동안 피하고 RELOAD에 때려라" % [
		boss_factory.slots.size(), boss_factory.total_rune_count(), hp_scale, GameTuning.BOSS_RELOAD_MUL
	], GamePalette.RED, 4.0)
	spawn_burst(boss_position, GamePalette.RED, 52, 390.0, 1.2)
	play_sound("boss", 0.0)
	shake_camera(12.0, 0.55)

func _find_visible_boss_position() -> Vector2:
	var offsets: Array[Vector2] = [
		Vector2(330.0, 0.0), Vector2(-330.0, 0.0),
		Vector2(0.0, -285.0), Vector2(0.0, 285.0)
	]
	for offset: Vector2 in offsets:
		var candidate := player.global_position + offset
		if world.is_walkable(candidate):
			return candidate
	return world.find_walkable_near(player.global_position, rng, 260.0, 320.0)

func update_boss_health(current: float, maximum: float, shield: float, maximum_shield: float) -> void:
	if not is_instance_valid(boss_fill):
		return
	var health_ratio := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	# V11: 하드코딩 560은 _build_ui가 만든 트랙(패널 폭 -34, 안쪽 여백 -6 = 528)보다 32px
	# 길어서, 만피 게이지가 패널 밖으로 삐져나와 마왕 레일 밴드까지 물들이고 있었다
	# (ColorRect는 부모를 클립하지 않는다). 패널 폭이 줄어든 지금은 그대로 두면 밴드를
	# 다시 침범하므로, 트랙 길이를 상수에서 파생시켜 빌드 시점과 갱신 시점을 묶는다.
	var boss_track_width := HUD_BOSS_BAR.size.x - 4.0
	boss_fill.size.x = boss_track_width * health_ratio
	var shield_ratio := 0.0 if maximum_shield <= 0.0 else clampf(shield / maximum_shield, 0.0, 1.0)
	boss_shield_fill.size = Vector2(boss_track_width * shield_ratio, HUD_BOSS_BAR.size.y - 4.0)
	boss_shield_fill.visible = shield_ratio > 0.0
	# V7: 마왕과 스테이지 보스가 같은 패널을 쓴다. 바퀴 길이는 마왕만 말한다.
	var live_cycle := active_boss_cycle()
	var is_stage := active_boss_is_stage()
	var slot_count := active_boss_factory().slots.size() if active_boss_factory() != null else GameTuning.BOSS_SLOT_COUNT
	var rhythm := ""
	if is_stage:
		var phase_total: int = (stage_boss_profile.get("phases", []) as Array).size()
		var phase_now: int = int(stage_boss.boss_phase) if is_instance_valid(stage_boss) else 0
		rhythm = "페이즈 %d / %d" % [phase_now, phase_total]
	else:
		rhythm = "밟은 칸 %d / %d" % [live_cycle.executed_slot_count() if is_instance_valid(live_cycle) else 0, slot_count]
	if is_instance_valid(live_cycle) and live_cycle.reloading:
		rhythm = "RELOAD %.1f초 · 무방비" % live_cycle.reload_remaining
	var title := String(stage_boss_profile.get("name", "스테이지 보스")) if is_stage else "딜싸이클 마왕"
	var status_line := player_status_label()
	if not status_line.is_empty():
		rhythm += "  ·  내 상태 %s" % status_line
	boss_text.text = "%s  %d%%  ·  %d칸  ·  %s" % [title, int(health_ratio * 100.0), slot_count, rhythm]

func _on_player_health_changed(current: float, maximum: float) -> void:
	if not is_instance_valid(health_fill):
		return
	var ratio := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	health_fill.size.x = (HUD_HEALTH_TRACK.size.x - 4.0) * ratio
	# 게이지 위에 흰 숫자를 얹으므로 채움색은 한 단계 어둡게 씁니다 (⑰ 가독성).
	var tone := GamePalette.GREEN.darkened(0.34) if ratio > 0.52 else GamePalette.YELLOW.darkened(0.3) if ratio > 0.25 else GamePalette.RED.darkened(0.18)
	health_fill.color = tone
	# Y4 — 세그먼트 12칸. 꽉 찬 칸은 그대로, **경계 칸 하나만** 부분 폭으로 줄고,
	# 그 뒤는 전부 꺼진다(보이지 않게 폭 0). 색은 위 세 단계를 그대로 따른다.
	var seg_span := HUD_HEALTH_TRACK.size.x - 4.0
	var seg_width := (seg_span - HUD_HEALTH_SEG_GAP * float(HUD_HEALTH_SEGMENTS - 1)) \
		/ float(HUD_HEALTH_SEGMENTS)
	var filled := ratio * float(HUD_HEALTH_SEGMENTS)
	for index in health_segments.size():
		var cell := health_segments[index]
		if not is_instance_valid(cell):
			continue
		var portion := clampf(filled - float(index), 0.0, 1.0)
		cell.size.x = seg_width * portion
		cell.visible = portion > 0.0
		cell.color = tone
	health_text.text = "%d / %d" % [int(ceil(current)), int(maximum)]

## X3: "수호 N · 부활 N" 문장 → **핍 줄**. 0이면 줄 전체가 사라져 자리도 안 먹는다.
## 상한(HUD_PIP_MAX)을 넘는 수는 마지막 핍을 밝게 해 "더 있다"만 말하고, 정확한 수는
## `vitals` 툴팁이 갖는다(정보 손실 0).
func _on_player_shield_changed(charges: int) -> void:
	if vitals_pips.is_empty():
		return
	var revives := player.rollback_charges if is_instance_valid(player) else 0
	# 보이는 핍만 **연속으로** 다시 눕힌다. 자리를 고정해 두면 수호 3 · 부활 1일 때
	# 가운데 세 칸이 빈 채로 남아 "핍 하나가 멀리 떨어진" 그림이 된다(캡처 실측).
	var pen := HUD_VITALS_PIPS
	for index in vitals_pips.size():
		var is_shield := index < HUD_PIP_MAX
		var rank := index if is_shield else index - HUD_PIP_MAX
		var owned := charges if is_shield else revives
		var pip := vitals_pips[index]
		pip.visible = rank < mini(owned, HUD_PIP_MAX)
		if not pip.visible:
			continue
		# 두 무리 사이에만 한 칸 더 벌린다 — 색이 갈리는 것을 간격이 거든다.
		if not is_shield and rank == 0 and charges > 0:
			pen.x += HUD_PIP_SIZE.x
		pip.position = pen
		pen.x += HUD_PIP_SIZE.x + HUD_PIP_GAP
		var base := GamePalette.BLUE if is_shield else GamePalette.GREEN
		# 마지막 칸이 켜져 있는데 실제로는 더 있다 → 그 칸만 흰빛으로 "넘쳤다"를 말한다.
		var overflowing := owned > HUD_PIP_MAX and rank == HUD_PIP_MAX - 1
		pip.color = base.lightened(0.45) if overflowing else base

func _on_player_died() -> void:
	call_deferred("_finish_run", false)

func _finish_run(won: bool) -> void:
	if state in ["won", "lost"]:
		return
	state = "won" if won else "lost"
	get_tree().paused = true
	# V8(handoff-v7 §12 미결 7): 보스전 도중에 죽으면 스테이지 보스 노드·장판·레일 밴드가
	# 트리에 남아 **결과 화면 뒤로 비쳐 보인다**. 결과를 그리기 전에 전투 잔재를 걷는다.
	# (`_teardown_stage_boss()`는 V7 소유 함수를 호출만 한다 — 본문 무수정.)
	_teardown_stage_boss()
	# 트로피 흐름이 열려 있는 채로 런이 끝나면 후속 마왕전 호출이 결과 화면 위로 뜬다.
	pending_stage_trophy.clear()
	pending_trophy.clear()
	pending_trophy_followup = ""
	trophy_place_pending = false
	_clear_run_save()
	if won:
		play_sound("win", 0.0)
	_show_result(won)

func _unlock_next_character() -> void:
	if automated_test:
		return
	var before := unlocked_character_count
	if selected_character_id == "swordsman":
		unlocked_character_count = maxi(unlocked_character_count, 2)
	elif selected_character_id == "archer":
		unlocked_character_count = maxi(unlocked_character_count, 3)
	if unlocked_character_count != before:
		_save_progress()

# =============================================================================
# 결과 화면 v3 — **다섯 관문 요약** (W10 v2판 → V8 재편 · 설계 부록 B V8 ⑤)
# =============================================================================
# v2판은 7일 기한 게임의 언어였다: 7칸 일차 타임라인 · "잔여 기한" · "각성 N차".
# v3에는 기한도 계보도 없다. **v2 기한 지표는 0개다**(V8 완료 기준).
#
#   v2 지표                       v3 (여기)
#   ────────────────────────      ──────────────────────────────────────────
#   7일 일차 타임라인             **5관문 타임라인**(V5가 축을 갈았다)
#   잔여 일수 / 도달 일차          **총 일수 + 등급(13/17/23 · 밸브 C)** — §2.5
#   각성 N차 · 계보 이름           **보스 트로피 N / 5 + 마지막 트로피 이름** — §5.5
#   (없음)                         **시너지 발동 횟수** — 부록 B V8 ⑤가 지정한 신규 지표
#   (없음)                         상태 반응 · 도트 틱 · 성장 천장 레벨업 횟수(X1 개명)
#   마왕 스노볼 4칩                한 칩으로 압축(카드 수 · 각인) + 아래 마왕 한 줄 유지
#   최종 5칸 + 각인                **그대로** — 마왕 프리뷰와 같은 읽기 전용 레일 렌더러
#
# 등급은 `demon_lord.victory_grade(day, descended)` 하나만 본다(§2.5 · 밸브를 밟으면 C).
#
# 세로 증명(패널 로컬): 머리말 14~78 / 타임라인 84~150 / 칩 2줄 156~266 /
#   레일 274~452 / 마왕 요약 458~482 / **트로피 요약 484~504** / 버튼 540~592 / 안내 606~626
#   (패널 668)
# 가로 증명: 레일 콘텐츠 1,156px, 패널 1,256px → 원점 x=50, 좌우 여백 50px. 스크롤 0.
const RESULT_PANEL_RECT := Rect2(12.0, 26.0, 1256.0, 668.0)
const RESULT_BODY_X := 28.0
const RESULT_BODY_W := 1200.0
const RESULT_TIMELINE_RECT := Rect2(28.0, 84.0, 1200.0, 66.0)
const RESULT_CHIP_ROW1_Y := 156.0
const RESULT_CHIP_ROW2_Y := 212.0
const RESULT_CHIP_H := 50.0
const RESULT_RAIL_ORIGIN := Vector2(50.0, 300.0)
const RESULT_RAIL_HEADING_Y := 274.0
## Y4(피드백 ㉔) — 크림 껍데기에 뚫는 **SLATE 무대 창**. 머리말(274) + 5칸(300~450)이
## 전부 이 안이다. 레일 가로 범위 50~1206이 28~1228 안에 들어간다.
## ⚠️ FEEDBACK_Y §8 ㉔은 높이 **196**을 적어 뒀지만 실측하면 창 아래끝이 464가 되어
## 마왕 요약 띠(`_build_result_boss_line` y 456~506)를 8px 먹는다. 레일 아래끝이
## 450이므로 **186**(→ 454)이면 여백 4px로 충분하고 아래 띠와 겹치지 않는다.
const RESULT_RAIL_STAGE_RECT := Rect2(28.0, 268.0, 1200.0, 186.0)

func _show_result(won: bool) -> void:
	_clear_overlay()
	overlay = Control.new()
	overlay.name = "Result"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	_kit_scrim(overlay, KIT_SCRIM_DEEP)
	var color := GamePalette.YELLOW if won else GamePalette.RED
	# 필드가 안 보이는 전면 화면 = PARCHMENT 껍데기(§7-1). 리본은 승패로 갈린다 —
	# 승리 GOLD · 패배 EMBER. 크림빛 껍데기 위 글자는 전부 **어두운 잉크**다.
	var grade := demon_lord.victory_grade(clock.day_number, clock.descended)
	var panel := _kit_shell(overlay, RESULT_PANEL_RECT,
		"버린 운명을 넘어섰습니다" if won else "마왕에게 도달하지 못했습니다",
		UIKit.Tone.PARCHMENT, UIKit.Tone.GOLD if won else UIKit.Tone.EMBER, 560.0)
	panel.name = "ResultPanel"
	var status_rect := Rect2(RESULT_BODY_X + RESULT_BODY_W - 420.0, 36.0, 420.0, 34.0)
	_kit_panel(panel, status_rect, UIKit.Tone.GOLD if won else UIKit.Tone.EMBER, UIKit.Role.CHIP)
	_kit_label(panel, Rect2(status_rect.position + Vector2(14.0, 0.0), status_rect.size - Vector2(28.0, 0.0)),
		("마왕 토벌 · 등급 %s" % grade) if won else "마왕에게 삼켜졌습니다",
		UIKit.Tone.GOLD if won else UIKit.Tone.EMBER, UIKit.FONT_HEADING, false,
		UIKit.Role.CHIP, HORIZONTAL_ALIGNMENT_RIGHT)
	# 승리 등급은 "몇 일차에 갔는가"만 본다 — 계약(§4.4)으로 하루를 사면 등급이 내려간다.
	# handoff-w9 §6이 "결과 화면 문구가 그 사실을 말해 주는 편이 좋다"고 지목한 자리다.
	# YZ(피드백 ① · ⑤): 두 줄 다 한 문장으로 줄였다. 결과 화면은 툴팁 층을 안 깔기
	# 때문에(`_begin_modal_tooltips()`를 부르지 않는다) 호버로 내릴 곳이 없다 —
	# 그래서 지우는 대신 **가장 짧은 사실 한 줄**만 남겼다. 등급 기준은 바로 오른쪽
	# 「승리 등급」 칩과 아래 타임라인이 이미 숫자로 보여 준다.
	var subtitle_text := "등급은 총 일수만 봅니다 — %d일 S · %d일 A · %d일 B · 강림을 쓰면 C" % [
		GameTuning.GRADE_S_MAX_DAYS, GameTuning.GRADE_A_MAX_DAYS, GameTuning.GRADE_B_MAX_DAYS]
	if not won:
		subtitle_text = "마왕은 당신이 버린 카드로 자랍니다 — 버린 것이 곧 마왕의 5칸입니다."
	var subtitle := _kit_label(panel, Rect2(RESULT_BODY_X + 4.0, 40.0, RESULT_BODY_W - 436.0, 26.0),
		subtitle_text, UIKit.Tone.PARCHMENT, UIKit.FONT_LABEL, true)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_build_result_timeline(panel)
	_build_result_chips(panel, won, grade)

	# =====================================================================
	# Y4 — 결과 화면 수리 (피드백 ㉔ · FEEDBACK_Y §8 ㉔)
	# =====================================================================
	# 유저 원문 요지: "결과 화면이 깨져 보인다." 원인은 겹침이 아니라 **바탕색 충돌**이다 —
	# 껍데기는 PARCHMENT(크림)인데 `_build_preview_slot()`은 마왕 프리뷰·편집 화면과
	# 공유하는 렌더러라 **SLATE 어두운 칩 + 밝은 글자**를 그린다. 크림 위에 밝은 글자가
	# 얹히니 5칸 구역만 통째로 하얗게 뜬다(대비 1.1:1).
	#
	# **렌더러는 한 줄도 안 고친다.** 리스크 ⑨가 경고한 대로 `_build_preview_slot()`은
	# 소비자가 다섯 곳이라, 여기 맞추려고 손대면 나머지 넷이 같이 무너진다.
	# 대신 **레일 구역만 SLATE 무대 창으로 뚫는다** — U1이 온보딩에서 쓴 수법 그대로다.
	# 창 안(머리말 · 5칸)은 SLATE 어휘, 창 밖(칩·타임라인·버튼)은 PARCHMENT 어휘다.
	_kit_panel(panel, RESULT_RAIL_STAGE_RECT, UIKit.Tone.SLATE, UIKit.Role.INSET).name = "ResultRailStage"
	_kit_glyph(panel, Vector2(RESULT_BODY_X + 12.0, RESULT_RAIL_HEADING_Y), "scroll", Color.WHITE, 20.0)
	_kit_label(panel, Rect2(RESULT_BODY_X + 38.0, RESULT_RAIL_HEADING_Y - 2.0, 500.0, 24.0),
		"최종 5칸과 각인", UIKit.Tone.SLATE, UIKit.FONT_HEADING, false, UIKit.Role.INSET)
	_kit_label(panel, Rect2(RESULT_BODY_X + 520.0, RESULT_RAIL_HEADING_Y, RESULT_BODY_W - 532.0, 22.0),
		"칸 %d개 · 각인 %d개 · 한 바퀴 RELOAD 빚 %.2f초 · 장비 %d / %d" % [
			factory.slots.size() if factory != null else 0,
			factory.total_rune_count() if factory != null else 0,
			factory.total_reload() if factory != null else 0.0,
			factory.equipment.size() if factory != null else 0, FactoryDeck.EQUIPMENT_PARTS.size()
		], UIKit.Tone.SLATE, UIKit.FONT_CAPTION, true, UIKit.Role.INSET, HORIZONTAL_ALIGNMENT_RIGHT)
	_build_result_deal_cycle(panel)
	_build_result_boss_line(panel)
	_build_result_trophy_line(panel)

	var retry := _button("다시하기", color, Vector2(300.0, 52.0))
	retry.position = Vector2(RESULT_PANEL_RECT.size.x * 0.5 - 320.0, 540.0)
	retry.pressed.connect(_retry_run)
	panel.add_child(retry)
	var menu := _button("로비로 돌아가기", GamePalette.MUTED, Vector2(300.0, 52.0))
	menu.position = Vector2(RESULT_PANEL_RECT.size.x * 0.5 + 20.0, 540.0)
	menu.pressed.connect(_show_menu)
	panel.add_child(menu)
	_kit_label(panel, Rect2(RESULT_BODY_X, 606.0, RESULT_BODY_W, 20.0),
		"R 다시하기   ·   L 또는 ESC 로비로 돌아가기",
		UIKit.Tone.PARCHMENT, UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_animate_modal(panel, Vector2(0.0, 22.0))
	retry.grab_focus()

# V5: 7일 타임라인 → **5스테이지 타임라인**(설계 부록 B V8 ⑤가 결과 화면의 정본이지만,
# 기한 스텁(`total_days()` / `milestone_for()`)을 걷어내려면 이 함수가 먼저 바뀌어야 한다).
# V5는 축만 갈아끼웠다 — 칩 구성·레이아웃 확장은 V8 몫이다.
func _build_result_timeline(panel: Control) -> void:
	# U1이 온보딩에서 쓴 "모달 안에 뚫린 필드 창"과 같은 수법이다(handoff-u1 §2.4) —
	# 관문 색·되밟기 색 같은 **의미색**은 어두운 함몰판 위에서만 배운 대로 읽힌다.
	var box := _kit_panel(panel, RESULT_TIMELINE_RECT, UIKit.Tone.SLATE, UIKit.Role.INSET)
	box.name = "ResultTimeline"
	var caption := _label("다섯 관문", UI_CAPTION_SIZE, GamePalette.YELLOW)
	caption.position = Vector2(12.0, 4.0)
	caption.size = Vector2(120.0, 16.0)
	box.add_child(caption)
	var tail := _label("총 %d일차 · %s · 최종 체류 %d%s" % [
		clock.day_number, clock.phase_label(), clock.dwell,
		" · 강림 사용" if clock.descended else ""
	], UI_CAPTION_SIZE, GamePalette.MUTED)
	tail.position = Vector2(RESULT_TIMELINE_RECT.size.x - 372.0, 4.0)
	tail.size = Vector2(360.0, 16.0)
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(tail)
	var total := GameTuning.STAGE_COUNT
	var gap := 8.0
	var cell_w := (RESULT_TIMELINE_RECT.size.x - 24.0 - gap * float(total - 1)) / float(total)
	for index in total:
		var stage_number := index + 1
		var done := stage_number <= clock.stages_cleared
		var current := stage_number == clock.stage and not done
		var cell_color := GamePalette.MUTED.darkened(0.35)
		if done:
			cell_color = GamePalette.YELLOW.darkened(0.25)
		elif current:
			cell_color = GamePalette.RED if clock.descended else GamePalette.YELLOW
		var cell := Panel.new()
		cell.position = Vector2(12.0 + float(index) * (cell_w + gap), 24.0)
		cell.size = Vector2(cell_w, 34.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.set_meta("stage", stage_number)
		cell.set_meta("reached", done or current)
		UIKit.style_panel(cell, UIKit.Tone.SLATE, UIKit.Role.CELL)
		box.add_child(cell)
		if current:
			_kit_focus_ring(box, Rect2(cell.position, cell.size))
		var stage_label := _label("%d관문%s" % [stage_number, "  ✓" if done else ("  ▶" if current else "")], UI_CAPTION_SIZE, cell_color.lightened(0.3))
		stage_label.position = Vector2(6.0, 2.0)
		stage_label.size = Vector2(cell_w - 12.0, 15.0)
		cell.add_child(stage_label)
		var name_label := _label(String(GameTuning.STAGE_NAMES[index]), UI_CAPTION_SIZE, GamePalette.TEXT if (done or current) else GamePalette.MUTED.darkened(0.3))
		name_label.position = Vector2(6.0, 16.0)
		name_label.size = Vector2(cell_w - 12.0, 15.0)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(name_label)

# v2 지표 10칩. v1의 "낮 / 밤 N회"(무한 라운드 언어)와 시련 구슬 계열은 전부 뺐다.
func _build_result_chips(panel: Control, won: bool, grade: String) -> void:
	var summary := boss_growth_preview()
	var rifts_cleared := 0
	for value in rift_states.values():
		if bool((value as Dictionary).get("cleared", false)):
			rifts_cleared += 1
	# V8: "각성 N차" 칩 → **트로피 N개**. 이름은 칩에 안 들어가므로(잘린다) 등급만 쓰고,
	# 트로피 이름 전체는 패널 아래 `_build_result_trophy_line()`이 나열한다.
	var trophy_value := "0 / %d" % TrophyLibrary.TROPHY_COUNT
	if is_instance_valid(player) and not player.trophy_stages.is_empty():
		var last_stage: int = player.trophy_stages[player.trophy_stages.size() - 1]
		trophy_value = "%d / %d · %s" % [
			player.trophy_stages.size(), TrophyLibrary.TROPHY_COUNT,
			TrophyLibrary.grade_name(String(TrophyLibrary.for_stage(last_stage).get("grade", "")))]
	# V8 신규 지표(설계 부록 B V8 ⑤ "시너지 발동 횟수"). 원소 상태이상 레이어가 실제로
	# 돌았는지가 여기서 처음 숫자로 읽힌다. `status_reactions_fired`는 부여·갱신까지
	# 포함한 매트릭스 전체 반응 수이고, `run_synergy_triggers`는 **이름 붙은** 것만이다.
	var status_reactions: int = combat.status_reactions_fired if combat != null else 0
	var dot_ticks: int = combat.status_dot_ticks if combat != null else 0
	var row1 := [
		{"caption":"승리 등급", "value":grade if won else "—", "color":GamePalette.YELLOW},
		{"caption":"총 일수 (S≤%d)" % GameTuning.GRADE_S_MAX_DAYS, "value":"%d일" % clock.day_number, "color":GamePalette.CYAN},
		{"caption":"관문 · 최종 체류", "value":"%d / %d · %d" % [clock.stages_cleared, GameTuning.STAGE_COUNT, clock.dwell], "color":GamePalette.CYAN},
		{"caption":"한 바퀴 최다 칸", "value":"%d / %d" % [run_peak_steps, RuneEngine.SLOT_EXEC_CAP * FactoryDeck.SLOT_COUNT], "color":GamePalette.MAGENTA},
		{"caption":"보스 트로피", "value":trophy_value, "color":GamePalette.GREEN}
	]
	var row2 := [
		{"caption":"시너지 발동", "value":"%d회" % run_synergy_triggers, "color":GamePalette.ORANGE},
		{"caption":"상태 반응 · 지속 피해", "value":"%d · %d" % [status_reactions, dot_ticks], "color":GamePalette.GREEN},
		{"caption":"반격 창 · 각인", "value":"%d회 · %d개" % [boss_reload_windows, (factory.total_rune_count() if factory != null else 0)], "color":GamePalette.YELLOW},
		{"caption":"마왕 카드 · 각인", "value":"%d장 · %d / %d" % [
			int(summary.get("cards_received", 0)), int(summary.get("rune_count", 0)), int(summary.get("rune_capacity", 0))
		], "color":GamePalette.RED},
		{"caption":"균열 깸 · 처치", "value":"%d · %d" % [rifts_cleared, kills], "color":GamePalette.ORANGE}
	]
	_build_result_chip_row(panel, row1, RESULT_CHIP_ROW1_Y)
	_build_result_chip_row(panel, row2, RESULT_CHIP_ROW2_Y)

func _build_result_chip_row(panel: Control, chips: Array, y: float) -> void:
	var gap := 12.0
	var width := (RESULT_BODY_W - gap * float(chips.size() - 1)) / float(chips.size())
	for index in chips.size():
		var chip: Dictionary = chips[index]
		_add_result_stat_chip(panel, Vector2(RESULT_BODY_X + float(index) * (width + gap), y), Vector2(width, RESULT_CHIP_H), String(chip["caption"]), String(chip["value"]), chip["color"])

# 마왕 한 줄 요약 — 스노볼(§6.2)과 두 밸브(전조·밀정)가 실제로 작동했는지가 여기서 읽힌다.
func _build_result_boss_line(panel: Control) -> void:
	var summary := boss_growth_preview()
	var text := "마왕의 5칸: 받은 카드 %d장 → 상위 %d장이 레일 · 잔재 %d개가 밤의 마물로  ·  각인 %d개(조각 %d) · 뜯어낸 %d · 회수한 카드 %d  ·  마왕 RELOAD 창 %d회" % [
		int(summary.get("cards_received", 0)), int(summary.get("filled_slots", 0)), int(summary.get("residue", 0)),
		int(summary.get("rune_count", 0)), int(summary.get("rune_shards", 0)),
		int(summary.get("stripped", 0)), int(summary.get("reclaimed", 0)), boss_reload_windows
	]
	if blight_active:
		text += "  ·  잠식 %d마리" % blight_marked
	# 마왕·트로피 두 줄은 의미색(RED / GREEN)을 그대로 쓰므로 함몰 띠 위에 올린다.
	_kit_panel(panel, Rect2(RESULT_BODY_X, 456.0, RESULT_BODY_W, 50.0), UIKit.Tone.SLATE, UIKit.Role.INSET)
	var line := _label(text, UI_CAPTION_SIZE, GamePalette.RED.lightened(0.12))
	line.position = Vector2(RESULT_BODY_X, 462.0)
	line.size = Vector2(RESULT_BODY_W, 20.0)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(line)

# V11 시각 QA: 결과 화면의 누적 효과 줄이 `damage_mul ×1.29` / `life_on_kill +1.5`처럼
# **영문 내부 키를 그대로** 찍고 있었다. 전 화면이 한국어인데 여기만 스키마가 새어 나온
# 셈이라, 플레이어는 이 줄이 앞서 트로피를 받을 때 본 "전체 피해 ×1.12"와 같은 값인지
# 알 수 없다. 표기는 전부 `TrophyLibrary.TROPHIES`의 `effect_desc`가 이미 쓰는 말을
# 그대로 가져왔다 — 획득 화면과 결과 화면이 같은 스탯을 다른 이름으로 부르면 안 된다.
# 키 집합은 배분표 5종의 `effect`가 실제로 내는 9개가 전부다(damage / damage_mul /
# range / health / shield / crit / pierce / projectile / life_on_kill). 배분표가 나중에
# 다른 키를 쓰더라도 아래 조회는 원문 키로 떨어지므로 빈칸이 되거나 죽지 않는다.
const TROPHY_EFFECT_LABEL: Dictionary = {
	"health": "최대 체력",
	"shield": "수호막",
	"damage": "피해",
	"damage_mul": "전체 피해",
	"range": "사거리",
	"crit": "치명타",
	"pierce": "관통",
	"projectile": "투사체",
	"life_on_kill": "처치마다 체력"
}

## V8: 획득한 보스 트로피 한 줄 — 다섯 관문이 실제로 무엇을 남겼는가(설계 §5.5).
## 계보 대신 이 줄이 "이번 런의 성장 이정표"를 요약한다.
func _build_result_trophy_line(panel: Control) -> void:
	var names: Array[String] = []
	var merged: Dictionary = {}
	if is_instance_valid(player):
		for stage_value in player.trophy_stages:
			var trophy := TrophyLibrary.for_stage(int(stage_value))
			names.append("%d관문 %s" % [int(stage_value), String(trophy.get("name", "트로피"))])
		merged = TrophyLibrary.merge_effects(player.trophy_stages)
	var text := ""
	if names.is_empty():
		text = "보스 트로피 0 / %d  ·  관문을 하나도 넘지 못했습니다" % TrophyLibrary.TROPHY_COUNT
	else:
		var effect_bits: Array[String] = []
		for key_value in merged.keys():
			var key := String(key_value)
			var value: Variant = merged[key_value]
			# 표기만 한국어로 바꾼다. 분기 조건은 여전히 **원문 키**(`_mul` 접미사)를 보고
			# 고르므로 아래 숫자 서식 네 갈래의 판정은 한 글자도 달라지지 않는다.
			var label := String(TROPHY_EFFECT_LABEL.get(key, key))
			if key == "crit":
				# 치명타만 **비율**이다. 아래 `< 1.0` 갈래로 흘려보내면 "치명타 +0.08"이
				# 되는데, 그건 트로피 획득 화면이 "치명타 +8%"라고 말한 것과 다른 말이다.
				# 같은 스탯을 두 화면이 다르게 부르면 안 된다(V10 시각 QA).
				effect_bits.append("%s +%d%%" % [label, int(roundf(float(value) * 100.0))])
			elif value is int:
				effect_bits.append("%s +%d" % [label, int(value)])
			elif key.ends_with("_mul"):
				effect_bits.append("%s ×%.2f" % [label, float(value)])
			elif is_equal_approx(float(value), roundf(float(value))):
				# 정수로 떨어지는 값에 소수점을 달면 "체력 +58.0"처럼 지저분해진다.
				effect_bits.append("%s +%d" % [label, int(roundf(float(value)))])
			elif absf(float(value)) < 1.0:
				# `crit 0.08`을 한 자리로 자르면 "+0.1"이 된다 — 두 자리를 준다.
				effect_bits.append("%s +%.2f" % [label, float(value)])
			else:
				# 반대로 반올림해 버리면 `life_on_kill 1.5`가 "+2"라는 **거짓말**이 된다.
				effect_bits.append("%s +%.1f" % [label, float(value)])
		effect_bits.sort()
		text = "보스 트로피 %d / %d — %s  ·  누적 %s" % [
			names.size(), TrophyLibrary.TROPHY_COUNT, "  ·  ".join(names), "  ".join(effect_bits)]
	if growth_cap_conversions > 0:
		text += "  ·  성장 천장 레벨업 %d회" % growth_cap_conversions
	var line := _label(text, UI_CAPTION_SIZE, GamePalette.GREEN.lightened(0.1))
	line.position = Vector2(RESULT_BODY_X, 484.0)
	line.size = Vector2(RESULT_BODY_W, 20.0)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(line)

func _add_result_stat_chip(parent: Control, chip_position: Vector2, chip_size: Vector2, caption: String, value: String, color: Color) -> void:
	var chip := Panel.new()
	chip.position = chip_position
	chip.size = chip_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_panel(chip, UIKit.Tone.SLATE, UIKit.Role.CHIP)
	parent.add_child(chip)
	var caption_label := _label(caption, UI_CAPTION_SIZE, color)
	caption_label.position = Vector2(14.0, 7.0)
	caption_label.size = Vector2(chip_size.x - 26.0, 18.0)
	chip.add_child(caption_label)
	var value_label := _label(value, UI_TITLE_SIZE, UIKit.text_on(UIKit.Tone.SLATE, UIKit.Role.CHIP))
	value_label.position = Vector2(14.0, 24.0)
	value_label.size = Vector2(chip_size.x - 26.0, 30.0)
	chip.add_child(value_label)

func _build_result_deal_cycle(parent: Control) -> void:
	# v1은 `_build_factory_rail_slot`(200×142) + `ScrollContainer`를 썼다. 5칸이 확정된
	# v2에서는 **스크롤이 필요 없다** — 마왕 프리뷰와 같은 읽기 전용 레일(196×150 · pitch 240 ·
	# 콘텐츠 1,156px)을 쓴다. 설계 §8.4의 "스크롤 없음(기존 부채 해소)"이 구조적으로 보장된다.
	if factory == null or factory.slots.is_empty():
		# Y4: 이 문장도 SLATE 무대 창 안이다 — 크림 톤 글자색을 쓰면 안 보인다(피드백 ㉔).
		var empty := _label("딜싸이클 기록이 없습니다.", UI_HEADING_SIZE, UIKit.muted_color(UIKit.Tone.SLATE))
		empty.position = Vector2(RESULT_BODY_X, RESULT_RAIL_ORIGIN.y + 60.0)
		empty.size = Vector2(RESULT_BODY_W, 32.0)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(empty)
		return
	# 칸 사이 커넥터 — 편집 화면과 같은 스파인 + 화살표.
	for index in maxi(0, factory.slots.size() - 1):
		var spine := ColorRect.new()
		spine.position = Vector2(RESULT_RAIL_ORIGIN.x + float(index) * EDIT_RAIL_PITCH + EDIT_CARD_SIZE.x, RESULT_RAIL_ORIGIN.y + 73.0)
		spine.size = Vector2(EDIT_CONNECTOR_W, 4.0)
		spine.color = FACTORY_RAIL_SPINE_BUILT
		spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(spine)
		var arrow := _label("▶", 15, FACTORY_RAIL_SPINE_BUILT.lightened(0.42))
		arrow.position = Vector2(spine.position.x, spine.position.y - 11.0)
		arrow.size = Vector2(EDIT_CONNECTOR_W, 22.0)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(arrow)
	for slot_index in factory.slots.size():
		_build_preview_slot(parent, factory, slot_index, RESULT_RAIL_ORIGIN, GamePalette.YELLOW, true)

func _retry_run() -> void:
	_clear_overlay()
	get_tree().paused = false
	_begin_run()

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	_on_player_health_changed(player.health, player.max_health)
	_on_player_shield_changed(player.shield_charges)
	# 마왕 각인 기록을 현재 카드 수에 맞춰 둔다(변화가 없으면 즉시 빠지는 no-op).
	demon_lord.sync_runes(rng)
	# Y2: 런 전체의 「한 바퀴 최다 칸 수」 — 결과 화면 지표. 폴링(10Hz)만으로는 스텝
	# 사이의 봉우리를 놓칠 수 있어 `cycle_completed(steps, exec_peak)`도 함께 받는다.
	_track_run_peak_steps()
	# X3: 직업 이름("왕국 검사")은 툴팁으로 갔다. 화면에는 레벨 숫자만 남는다.
	class_text.text = "LV %d" % level
	gold_text.text = "%03d" % gold
	var xp_ratio := clampf(float(experience) / float(maxi(xp_target, 1)), 0.0, 1.0)
	xp_fill.size.x = HUD_XP_TRACK.size.x * xp_ratio
	# 성 안에서는 _process가 castle_interior 분기에서 먼저 return하므로 매 프레임 갱신
	# (_update_cycle_rail)이 돌지 않는다. 스트립을 끄는 책임을 여기에 둔다.
	if inside_castle:
		if is_instance_valid(rail_band):
			rail_band.visible = false
		if is_instance_valid(rail_flow_banner):
			rail_flow_banner.visible = false
	_update_stage_panel()
	_update_edge_nav()
	_update_consumable_slot()
	_update_ghost_rail()
	_update_rail_text()
	_update_hud_tooltips()

# =============================================================================
# V5: 스테이지 · 체류 압박 줄 갱신 — 전부 StageClock 조회다
# =============================================================================
# 자체 계산 금지 규칙은 v2 그대로다(handoff-w4 §6). 클럭이 진실 원천이다.
# X3: 계산은 한 줄도 안 바뀌었고 **어디에 쓰는가**만 바뀌었다.
func _update_stage_panel() -> void:
	if not is_instance_valid(stage_panel):
		return
	# Y4(피드백 ⑤): 첫 줄은 이제 그림이다. 글자는 **장소 꼬리표 한 낱말**뿐이고
	# 필드에서는 그마저 빈 문자열이라 아무것도 안 보인다.
	if inside_castle:
		phase_text.text = "베이스 캠프" if inside_camp else "여행자의 성"
		phase_text.add_theme_color_override("font_color", GamePalette.GREEN if inside_camp else GamePalette.YELLOW)
	elif state == "boss":
		phase_text.text = "결전"
		phase_text.add_theme_color_override("font_color", _hud_ink(GamePalette.RED))
	else:
		phase_text.text = ""
	var stage_tint := GamePalette.RED if is_night else GamePalette.YELLOW
	if is_instance_valid(phase_mark):
		if phase_mark.night != is_night or not phase_mark.tint.is_equal_approx(stage_tint):
			phase_mark.night = is_night
			phase_mark.tint = stage_tint
			phase_mark.queue_redraw()
	for index in stage_gates.size():
		var gate := stage_gates[index]
		if not is_instance_valid(gate):
			continue
		var stage_number := index + 1
		var want_state := 2
		if stage_number < clock.stage:
			want_state = 0
		elif stage_number == clock.stage:
			want_state = 1
		var want_tint := GamePalette.YELLOW.darkened(0.42) if want_state == 0 \
			else stage_tint if want_state == 1 else GamePalette.MUTED
		if gate.state != want_state or not gate.tint.is_equal_approx(want_tint):
			gate.state = want_state
			gate.tint = want_tint
			gate.queue_redraw()
	cycle_fill.size.x = HUD_PHASE_BAR.size.x * clock.phase_ratio()
	cycle_fill.color = GamePalette.RED if is_night else GamePalette.YELLOW
	# 체류 압박 게이지 — 0..1이 "강림 밸브까지". 그 위에 잠식 임계선이 이름을 갖고 서 있다.
	var track_width := HUD_DWELL_BAR.size.x
	dwell_fill.size.x = track_width * clock.dwell_ratio()
	dwell_fill.color = GamePalette.RED if clock.blight_active() else GamePalette.MAGENTA
	var blight_at := clampf(float(clock.blight_threshold()) / maxf(float(clock.descent_threshold()), 1.0), 0.0, 1.0)
	dwell_blight_mark.position.x = clampf(track_width * blight_at, 0.0, track_width - 2.0)
	dwell_blight_mark.color = GamePalette.RED if clock.blight_active() else GamePalette.ORANGE
	# X3: 이 한 줄이 평상시에는 "체류 N"이고, **잠식·강림이 발동한 순간에만** 경고문이
	# 된다. 사용자 요구 "잠식 경고는 발동 시에만"이 여기 한 곳에 들어가 있다.
	# 나머지 예고(다음 이정표 · 남은 초 · 총 일차 · 임계 수치)는 `stage` 툴팁이 갖는다.
	var dwell_value := clock.dwell
	var blighted := blight_active or clock.blight_active()
	stage_warn_on = blighted or stage_descent_pending
	if stage_descent_pending:
		dwell_text.text = "강림 진행 중 · 등급 C 고정"
		dwell_text.add_theme_color_override("font_color", _hud_ink(GamePalette.RED))
	elif blighted:
		dwell_text.text = "잠식 · 체류 %d" % dwell_value
		dwell_text.add_theme_color_override("font_color", _hud_ink(GamePalette.RED))
	else:
		dwell_text.text = "체류 %d" % dwell_value
		var soft := dwell_value >= clock.blight_threshold() - 1
		# 11px 글자가 잔디 위에 맨몸으로 있다. MUTED로 두면 낮 화면에서 사실상 안 보인다
		# (첫 캡처 실측) — 평상시에도 TEXT까지는 올린다.
		dwell_text.add_theme_color_override("font_color",
			_hud_ink(GamePalette.ORANGE) if soft else GamePalette.TEXT)

## 다음 dwell 사건 1개. 없으면 강림 예고를 말한다 — 게이지 끝이 무엇인지 항상 밝힌다.
## X3: 상시 라벨에서 `stage` 툴팁의 한 줄로 자리를 옮겼다(문장 자체는 무변경).
func _next_milestone_text() -> String:
	if stage_descent_pending:
		return "강림 진행 중 · 등급 C 고정"
	var upcoming := clock.next_dwell_milestone()
	if upcoming.is_empty():
		return "체류 %d 후 강림" % clock.dwell_remaining()
	var id := String(upcoming.get("id", ""))
	return "체류 %d(+%d) · %s" % [int(upcoming.get("dwell", 0)), int(upcoming.get("in", 0)), MILESTONE_SHORT.get(id, id)]

# =============================================================================
# X3: 화면 가장자리 화살표 내비 갱신 (구 나침반 패널 3줄 · 설계 §2.3 표)
# =============================================================================
# 데이터는 V5 그대로다 — `world.get_stage_compass()` 세 랜드마크 + `get_rift_compass()`.
# 바뀐 것은 그 결과를 "글자 3줄"이 아니라 "가장자리 마커 4개"로 그린다는 것뿐이다.
#
# 좌표 변환은 카메라 하나만 지난다: `get_viewport().get_canvas_transform() * 월드좌표`.
# `hud`는 화면 전체 앵커라 로컬 = 전역이므로 그 결과를 그대로 쓴다(헤드리스도 같다).
func _update_edge_nav() -> void:
	if not is_instance_valid(nav_layer):
		return
	# 성·캠프 안, 보스전, 필드 밖에서는 길 안내가 의미를 잃는다 — 통째로 끈다.
	var live := hud.visible and not inside_castle and state == "playing" \
		and is_instance_valid(world) and is_instance_valid(player) and is_inside_tree()
	nav_layer.visible = live
	if not live:
		return
	var canvas := get_viewport().get_canvas_transform()
	var screen := get_viewport_rect().size
	var compass: Dictionary = world.get_stage_compass(player.global_position)
	var rift_compass: Dictionary = world.get_rift_compass(player.global_position)
	var event_compass: Dictionary = _event_compass(player.global_position)
	for entry: Dictionary in NAV_TARGETS:
		var key := String(entry["key"])
		var marker: EdgeMarker = nav_markers.get(key, null)
		if marker == null:
			continue
		var data: Dictionary = compass.get(key, {}) as Dictionary
		if key == "rift":
			# Y6: 균열 화살표는 **그 균열을 발견한 뒤에만** 뜬다(§6.1). 가장 가까운
			# 균열이 아직 미발견이면 그 다음으로 가까운 **발견한** 균열을 가리킨다 —
			# 미발견 하나 때문에 이미 아는 균열의 화살표까지 꺼지면 거짓말이 된다.
			data = rift_compass if not rift_compass.is_empty() \
				and is_discovered(String(rift_compass.get("id", ""))) else _discovered_rift_compass(player.global_position)
		elif key == "event":
			data = event_compass
		elif not is_discovered(key):
			# 성·캠프는 처음부터 발견 상태다. 보스문은 가 봐야 켜진다.
			data = {}
		if data.is_empty():
			marker.visible = false
			continue
		var at: Vector2 = canvas * Vector2(data.get("position", Vector2.ZERO))
		var distance := float(data.get("distance", 0.0))
		# ① 화면 안에 들어오면 숨는다. 눈에 보이는 것을 또 가리키지 않는다.
		var inside := at.x > NAV_HIDE_MARGIN and at.x < screen.x - NAV_HIDE_MARGIN \
			and at.y > NAV_HIDE_MARGIN and at.y < screen.y - NAV_HIDE_MARGIN
		marker.set_meta("distance", distance)
		marker.set_meta("onscreen", inside)
		if inside:
			marker.visible = false
			continue
		var center := NAV_RING.position + NAV_RING.size * 0.5
		var direction := at - center
		if direction.length_squared() < 1.0:
			direction = Vector2.RIGHT
		var ring_point := _nav_ring_point(direction)
		marker.visible = true
		marker.position = (ring_point - NAV_MARKER_SIZE * 0.5).round()
		var text := "%dm" % int(round(distance * 0.1))
		var angle := direction.angle()
		if not is_equal_approx(marker.angle, angle) or marker.distance_text != text:
			marker.angle = angle
			marker.distance_text = text
			marker.queue_redraw()

## 링 중심에서 `direction` 쪽으로 쏜 반직선이 NAV_RING 테두리와 만나는 점.
## 사각형 링이라 x축·y축 중 먼저 닿는 쪽으로 잘린다(원형 링은 네 귀퉁이를 못 쓴다).
func _nav_ring_point(direction: Vector2) -> Vector2:
	var center := NAV_RING.position + NAV_RING.size * 0.5
	var half := NAV_RING.size * 0.5
	var dx := absf(direction.x)
	var dy := absf(direction.y)
	var scale_x := half.x / dx if dx > 0.0001 else INF
	var scale_y := half.y / dy if dy > 0.0001 else INF
	var scale := minf(scale_x, scale_y)
	if is_inf(scale):
		return center
	return center + direction * scale

# 마왕 고스트 레일 (설계 §6.3). 카드를 버려 칸 구성이 바뀌면 그 칸을 1회 강조한다.
# 어떤 경로로 버렸는지(레벨업·포기·상자)를 알 필요가 없도록 **구성 변화를 관측**한다 —
# 토스트 구역(W6 소유)을 건드리지 않고도 모든 버림 경로를 덮는다.
# X3: 숫자 배지 → 각인 유무 점 하나. 정확한 수·꼬리말 세 지표는 `ghost` 툴팁이 갖는다.
func _update_ghost_rail() -> void:
	if not is_instance_valid(ghost_panel):
		return
	var ranked := demon_lord.ranked_cards()
	for index in ghost_slot_panels.size():
		var slot := ghost_slot_panels[index]
		var card: Dictionary = ranked[index] if index < ranked.size() else {}
		var card_id := "" if card.is_empty() else String(card.get("id", ""))
		var rune_count := demon_lord.rune_count_on_slot(index)
		if ghost_slot_ids[index] != card_id:
			ghost_slot_ids[index] = card_id
			ghost_slot_flash[index] = 1.0
		slot.set_meta("card_id", card_id)
		slot.set_meta("rune_count", rune_count)
		var color := GamePalette.PURPLE if card_id.is_empty() else _element_color(_card_element(card))
		var icon := slot.get_node_or_null("Icon") as PixelSkillIcon
		if is_instance_valid(icon):
			icon.visible = not card_id.is_empty()
			if icon.visible and (icon.skill_id != card_id or icon.icon_color != color):
				icon.setup(card_id, color, false)
		var mark := slot.get_node_or_null("RuneDot") as ColorRect
		if is_instance_valid(mark):
			mark.visible = rune_count > 0
		# U3 v3: 킷 ABYSS 칸 + 곱 틴트. 빈 칸은 가라앉고, 카드가 앉은 칸은 그 원소색으로 뜬다.
		var tint := GHOST_SLOT_TINT_EMPTY if card_id.is_empty() else Color.WHITE.lerp(color, GHOST_SLOT_TINT_MIX)
		var flash := ghost_slot_flash[index]
		if flash > 0.0:
			tint = tint.lerp(Color.WHITE.lerp(GamePalette.MAGENTA, 0.40), flash)
		var key := tint.to_html(false)
		if String(slot.get_meta("style_key", "")) != key:
			slot.set_meta("style_key", key)
			slot.add_theme_stylebox_override("panel", _kit_cell_style(UIKit.Tone.ABYSS, tint))

# =============================================================================
# X3 — HUD 툴팁 내용 갱신 (10Hz · `_update_hud` 꼬리)
# =============================================================================
# **여기가 X3의 "정보 손실 0" 증명이다.** 화면에서 지운 문장이 하나도 빠짐없이
# 이 함수 안에 있다. 새 문장은 만들지 않았다 — 옛 라벨의 서식 문자열을 그대로 옮겼다.
#
# 대상 지도
#   vitals        캐릭터 이름 · 체력 · 수호/부활 · 경험 N/N · 필드 마물/처치 · 자금
#   stage         낮/밤 남은 초 · 총 일차 · 잠식/강림 임계 · 다음 이정표 · 균열 예산
#   ghost         마왕 각인 N/N · 받은 카드 · 잔재 · HP 배율 · 칸별 카드 이름
#   rail          칸 NN / NN(↺N) · 바퀴 · 스텝 시간 · 빚 · 청산 시 RELOAD · 상태
#   rail_slot{N}  카드 이름 · 랭크 · 원소(1글자 마크 포함) · 각인 목록
#   rail_dial     RELOAD 잔여 / 이 스텝 진행
#   nav_{key}     대상 이름 · 방향 · 거리 m (+ 균열이면 이 스테이지 예산)
func _update_hud_tooltips() -> void:
	if hud_tooltip_layer == null:
		return
	_hud_tip("vitals", _vitals_tooltip_spec())
	_hud_tip("stage", _stage_tooltip_spec())
	_hud_tip("ghost", _ghost_tooltip_spec())
	if is_instance_valid(rail_band) and rail_band.visible and is_instance_valid(player_cycle) and factory != null:
		_hud_tip("rail", _rail_tooltip_spec())
		_hud_tip("rail_dial", _rail_dial_tooltip_spec())
		for index in rail_slot_panels.size():
			_hud_tip("rail_slot%d" % index, _rail_slot_tooltip_spec(index))
	for entry: Dictionary in NAV_TARGETS:
		_hud_tip("nav_%s" % String(entry["key"]), _nav_tooltip_spec(entry))
	# Y6: 소비 칸의 효과 한 줄은 화면에 안 적는다 — 이름만 보이고 나머지는 여기다.
	_hud_tip("consumable", _consumable_tooltip_spec())

## 등록된 대상 하나의 내용을 갈아 끼운다. `attach_tooltip`은 두 번 불러도 배선은 한 번이다.
func _hud_tip(key: String, spec: Dictionary) -> void:
	if not hud_tooltip_targets.has(key):
		return
	var target: Variant = hud_tooltip_targets[key]
	if not (target is Control) or not is_instance_valid(target):
		return
	UIKit.attach_tooltip(target as Control, hud_tooltip_layer, spec)

func _vitals_tooltip_spec() -> Dictionary:
	var rows: Array = []
	if is_instance_valid(player):
		rows.append(["체력", "%d / %d" % [int(round(player.health)), int(round(player.max_health))], GamePalette.GREEN])
		rows.append(["수호 · 부활", "%d  ·  %d" % [player.shield_charges, player.rollback_charges], GamePalette.BLUE])
	rows.append(["경험", "%d / %d  ·  다음 선택" % [experience, xp_target], GamePalette.CYAN])
	rows.append(["자금", "%d" % gold, GamePalette.YELLOW])
	if inside_castle:
		rows.append(["지금 상황", "필드 전투 정지 · 상인 찾기"])
	elif combat != null:
		rows.append(["필드 마물 · 처치", "%03d  ·  %03d" % [combat.active_enemies.size(), kills]])
	return {
		"title": "%s  LV %d" % [player.get_character_name() if is_instance_valid(player) else "용사", level],
		"accent": GamePalette.YELLOW,
		"rows": rows
	}

func _stage_tooltip_spec() -> Dictionary:
	var rows: Array = [
		[clock.phase_label(), "%02d초 남음" % int(ceil(clock.phase_remaining()))],
		["총 일차", "%d일차" % clock.day_number],
		["체류", "%d" % clock.dwell],
		["잠식 · 강림", "%d  /  %d" % [clock.blight_threshold(), clock.descent_threshold()],
			GamePalette.RED if clock.blight_active() else GamePalette.ORANGE],
		["다음 사건", _next_milestone_text(), GamePalette.MAGENTA]
	]
	if is_instance_valid(world) and not inside_castle:
		rows.append(["이 스테이지 균열", "%d / %d" % [world.get_rifts().size(), world.RIFT_MAX_PER_RUN]])
	return {
		"title": "%d스테이지 %s" % [clock.stage, clock.stage_name()],
		"accent": _hud_ink(GamePalette.RED) if is_night else GamePalette.YELLOW,
		"rows": rows,
		"body": "위 게이지는 낮/밤 진행, 아래 게이지는 체류 압박입니다. 눈금이 잠식이 시작되는 곳입니다."
	}

func _ghost_tooltip_spec() -> Dictionary:
	var rows: Array = [
		["각인", "%d / %d" % [demon_lord.rune_count(), demon_lord.rune_capacity()], GamePalette.MAGENTA],
		["받은 카드", "%d" % demon_lord.received_card_count()],
		["잔재", "%d" % maxi(0, demon_lord.ranked_cards().size() - GameTuning.BOSS_SLOT_COUNT)],
		["체력 배율", "×%.2f" % demon_lord.hp_multiplier(clock.day_number)]
	]
	var ranked := demon_lord.ranked_cards()
	for index in ghost_slot_panels.size():
		var card: Dictionary = ranked[index] if index < ranked.size() else {}
		var runes := demon_lord.rune_count_on_slot(index)
		var value := "비어 있음" if card.is_empty() else "%s · 각인 %d" % [_factory_card_name(card), runes]
		rows.append(["칸 %d" % (index + 1), value])
	return {
		"title": "마왕의 5칸",
		"accent": GamePalette.MAGENTA,
		"rows": rows,
		"body": "고르지 않은 카드는 전부 마왕에게 갑니다."
	}

func _rail_tooltip_spec() -> Dictionary:
	var slot_count := maxi(1, factory.slots.size())
	var active := clampi(player_cycle.current_index, 0, slot_count - 1)
	var reentry_mark := "  ↺%d" % player_cycle.current_reentry if player_cycle.current_reentry > 0 else ""
	var state_value := "%d바퀴 · %.2f초" % [player_cycle.completed_cycles, player_cycle.group_duration]
	var state_color := GamePalette.TEXT
	if player_cycle.reloading:
		state_value = "RELOAD %.2f초" % player_cycle.reload_remaining
		state_color = GamePalette.ORANGE
	elif rail_overload_flash > 0.0:
		state_value = "바퀴 상한"
		state_color = GamePalette.RED
	return {
		"title": "딜싸이클  ·  칸 %02d / %02d%s" % [active + 1, slot_count, reentry_mark],
		"accent": GamePalette.YELLOW,
		"rows": [
			["상태", state_value, state_color],
			["빚", "%.2f초" % player_cycle.reload_debt, GamePalette.ORANGE],
			["다 갚으면 RELOAD", "%.2f초" % player_cycle.projected_reload(), GamePalette.ORANGE],
			["밟은 칸", "%d / %d" % [player_cycle.executed_slot_count(), slot_count], GamePalette.MAGENTA],
			["이 칸", "%d / %d번" % [player_cycle.exec_count(active), RuneEngine.SLOT_EXEC_CAP], GamePalette.YELLOW]
		],
		"body": "바늘이 멈춘 칸의 카드가 저절로 나갑니다. 한 칸은 한 바퀴에 %d번까지만 터지고, 두 번 밟은 칸은 바늘이 건너뜁니다. 한 바퀴가 끝나면 빚만큼 쉬었다가 다시 돕니다." % RuneEngine.SLOT_EXEC_CAP
	}

func _rail_dial_tooltip_spec() -> Dictionary:
	if player_cycle.reloading:
		return {
			"title": "RELOAD %.2f초" % player_cycle.reload_remaining,
			"accent": GamePalette.ORANGE,
			"rows": [["전체", "%.2f초" % player_cycle.reload_duration]],
			"body": "한 바퀴의 빚을 갚는 중입니다. 이 동안에는 어떤 칸도 나가지 않습니다."
		}
	return {
		"title": "이 칸 진행",
		"accent": GamePalette.CYAN,
		"rows": [
			["지속", "%.2f초" % player_cycle.group_duration],
			["완주", "%d바퀴" % player_cycle.completed_cycles]
		]
	}

func _rail_slot_tooltip_spec(index: int) -> Dictionary:
	var card := factory.get_card(index)
	var color := _rail_slot_color(card)
	if card.is_empty():
		return {
			"title": "칸 %d · 빈칸" % (index + 1),
			"accent": GamePalette.STONE_LIGHT,
			"body": "빈칸에서는 기본 공격이 나갑니다. ESC로 카드를 넣을 수 있습니다."
		}
	var mark := _rail_element_mark(index)
	var rows: Array = [["랭크 · 속성", "R%d  %s" % [int(card.get("rank", 1)), mark], color]]
	var runes := factory.runes_on(index)
	for rune_value in runes:
		var rune: Dictionary = rune_value
		var rune_id := String(rune.get("id", ""))
		var rune_def: Dictionary = RuneEngine.RUNES.get(rune_id, {})
		rows.append(["각인", String(rune_def.get("name", rune_id)), _rune_rarity_color(rune_id)])
	if runes.is_empty():
		rows.append(["각인", "없음"])
	if index == player_cycle.current_index and player_cycle.current_reentry > 0:
		rows.append(["재실행", "↺%d" % player_cycle.current_reentry, GamePalette.ORANGE])
	return {
		"title": "칸 %d · %s" % [index + 1, _factory_card_name(card)],
		"accent": color,
		"rows": rows
	}

func _nav_tooltip_spec(entry: Dictionary) -> Dictionary:
	var key := String(entry["key"])
	var marker: EdgeMarker = nav_markers.get(key, null)
	var distance := float(marker.get_meta("distance", 0.0)) if marker != null else 0.0
	var rows: Array = [["거리", "%dm" % int(round(distance * 0.1))]]
	if key == "rift" and is_instance_valid(world):
		rows.append(["이 스테이지 균열", "%d / %d" % [world.get_rifts().size(), world.RIFT_MAX_PER_RUN]])
	return {
		"title": String(entry["name"]),
		"accent": _hud_ink(entry["color"]),
		"rows": rows,
		"body": "화살표를 따라가면 나옵니다. 화면 안에 들어오면 화살표가 사라집니다."
	}

func spawn_burst(world_position: Vector2, color: Color, count: int, speed: float, duration: float) -> void:
	if not is_instance_valid(gameplay_root) or active_effect_nodes >= GameTuning.MAX_TRANSIENT_EFFECTS:
		return
	if active_effect_nodes >= int(GameTuning.MAX_TRANSIENT_EFFECTS * 0.7):
		count = mini(count, 10)
	var effect := BURST_SCRIPT.new()
	effect.setup(color, count, speed, duration)
	effect.position = world_position
	effect.tree_exiting.connect(_on_transient_effect_exiting)
	active_effect_nodes += 1
	gameplay_root.add_child(effect)

func _on_transient_effect_exiting() -> void:
	active_effect_nodes = maxi(0, active_effect_nodes - 1)

func show_world_text(world_position: Vector2, text: String, color: Color, font_size: int = 17) -> void:
	if not is_instance_valid(gameplay_root) or active_effect_nodes >= GameTuning.MAX_TRANSIENT_EFFECTS:
		return
	var holder := Node2D.new()
	holder.position = world_position
	holder.z_index = 14
	holder.tree_exiting.connect(_on_transient_effect_exiting)
	active_effect_nodes += 1
	gameplay_root.add_child(holder)
	var label := _label(text, font_size, color)
	label.position = Vector2(-130.0, -20.0)
	label.size = Vector2(260.0, 44.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(label)
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(holder, "position:y", holder.position.y - 48.0, 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.82).set_delay(0.24)
	tween.chain().tween_callback(holder.queue_free)

const BANNER_RECT := Rect2(230.0, 148.0, 820.0, 58.0)
const BANNER_BOSS_Y := 192.0

func _show_banner(text: String, color: Color, duration: float) -> void:
	# 예전에는 배너를 만들 때마다 같은 좌표에 새 패널을 얹어, 사건이 연달아 일어나면
	# 반투명 배경이 두 겹으로 깔리고 글자가 서로 위에 찍혔습니다. 마왕 토스트와 같은
	# 규칙으로 직전 배너를 먼저 걷어냅니다 (P1-15).
	if is_instance_valid(active_banner):
		active_banner.queue_free()
	active_banner = null
	var banner := Panel.new()
	banner.process_mode = Node.PROCESS_MODE_ALWAYS
	# 화면 정중앙(y 205)은 플레이어 주변 시야를 크게 가렸습니다. 상단 HUD 아래로 올리되,
	# 마왕 체력 패널(y 112~182)이 떠 있을 때만 그 아래로 비켜 줍니다.
	var banner_y := BANNER_RECT.position.y
	if is_instance_valid(boss_panel) and boss_panel.visible:
		banner_y = BANNER_BOSS_Y
	banner.position = Vector2(BANNER_RECT.position.x, banner_y)
	banner.size = BANNER_RECT.size
	banner.modulate.a = 0.0
	# U3 v3: 배너도 "필드 위에 얹히는 것"이라 SLATE 껍데기다(§2 톤 표).
	# 왼쪽 4px 액센트 바는 사건의 종류를 나르는 의미색이라 그대로 두되, 킷 프레임의
	# 9-slice 여백(10) 안쪽으로 들여놓는다 — x=2는 테두리 그림 위였다.
	UIKit.style_panel(banner, UIKit.Tone.SLATE, UIKit.Role.PANEL)
	ui_root.add_child(banner)
	var accent := ColorRect.new()
	accent.position = Vector2(6.0, 12.0)
	accent.size = Vector2(4.0, BANNER_RECT.size.y - 24.0)
	accent.color = color
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(accent)
	var label := _label(text, UI_HEADING_SIZE, color)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(label)
	active_banner = banner
	var tween := banner.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(banner, "modulate:a", 1.0, 0.15)
	tween.tween_interval(maxf(0.4, duration - 0.45))
	tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_finish_banner.bind(banner))

func _finish_banner(banner: Panel) -> void:
	if active_banner == banner:
		active_banner = null
	if is_instance_valid(banner):
		banner.queue_free()

func _animate_modal(control: Control, offset: Vector2 = Vector2(0.0, 18.0)) -> void:
	if not is_instance_valid(control):
		return
	var target_position := control.position
	control.position += offset
	control.modulate.a = 0.0
	control.scale = Vector2(0.985, 0.985)
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(control, "position", target_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.18)
	tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# U2: 헤더 리본은 껍데기 **밖**(부모)에 붙어 있어서 같이 안 움직이면 등장 0.22초 동안
	# 명판만 제자리에 떠 있는다. 껍데기와 같은 1회성 전환을 리본에도 건다(루프 없음).
	var ribbon: Variant = control.get_meta("kit_ribbon") if control.has_meta("kit_ribbon") else null
	if ribbon is Control and is_instance_valid(ribbon):
		var plate: Control = ribbon
		var ribbon_target := plate.position
		plate.position += offset
		plate.modulate.a = 0.0
		var ribbon_tween := plate.create_tween()
		ribbon_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ribbon_tween.set_parallel(true)
		ribbon_tween.tween_property(plate, "position", ribbon_target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ribbon_tween.tween_property(plate, "modulate:a", 1.0, 0.18)

func _play_scene_transition(midpoint: Callable, tint: Color = Color("070a14")) -> void:
	if transition_active or automated_test:
		midpoint.call()
		return
	transition_active = true
	var curtain := ColorRect.new()
	curtain.name = "SceneTransition"
	curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color(tint, 0.0)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(curtain)
	var tween := curtain.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(curtain, "color:a", 1.0, GameTuning.SCENE_TRANSITION_FADE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(midpoint)
	tween.tween_interval(GameTuning.SCENE_TRANSITION_HOLD)
	tween.tween_property(curtain, "color:a", 0.0, GameTuning.SCENE_TRANSITION_FADE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): transition_active = false; curtain.queue_free())

# =============================================================================
# Y7: 카메라 최소화 (§7.1 원칙 1 · §7.4)
# =============================================================================
# 사용자 피드백은 「카메라 이동은 최소화」였고 설계가 그것을 숫자로 못 박았다 —
# **진폭 ≤ 4px · 지속 ≤ 0.12초**, 그리고 **보스 착탄과 플레이어 피격에만.**
#
# 호출부를 일곱 군데 고치는 대신 **문을 하나로 좁혔다.** 여기서 상한을 걸면
# 앞으로 누가 어디서 `shake_camera(20.0, 1.5)`를 불러도 화면은 4px을 안 넘는다.
# 호출부의 숫자는 "이 사건이 얼마나 센가"의 상대 서열로 남는다(상한 안에서 비례).
#
# ⚠️ **플레이어 스킬 발사의 흔들림은 상한이 아니라 삭제다.** 그 자리는
#    `core/combat_resolver.gd`의 무거운 카드 펄스였고, Y7이 지웠다 —
#    대신 같은 자리에서 `spawn_impact_burst()`가 터진다(§7.1 원칙 2).
#
# 남은 호출부는 **다섯 곳**이고 전부 §7.1이 허락한 둘 중 하나다.
#   보스 착탄 4 — 강림 · 스테이지 보스 등장 · 페이즈 발구름 · 마왕 등장
#   플레이어 피격 1 — `player.gd`의 `take_damage()`
# Y7이 지운 것 넷 — 무거운 카드 펄스(`combat_resolver`) · 잠식 · 보스 격파 · 트로피.
const SHAKE_MAX_AMPLITUDE := 4.0
const SHAKE_MAX_DURATION := 0.12
## 계측: 이번 런에서 관측된 카메라 오프셋 크기의 최댓값(`--cycle-test cam_peak`).
var cam_peak := 0.0

func shake_camera(strength: float, duration: float) -> void:
	if not screen_shake_enabled or not is_instance_valid(player):
		return
	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if not is_instance_valid(camera):
		return
	# 호출부의 세기를 **서열로만** 읽고 4px 안으로 눌러 담는다. 14.0이든 7.0이든
	# 화면에서는 4px과 2px의 차이가 된다.
	var amplitude := clampf(strength * 0.28, 0.0, SHAKE_MAX_AMPLITUDE)
	var span := clampf(duration, 0.0, SHAKE_MAX_DURATION)
	if amplitude <= 0.0 or span <= 0.0:
		return
	# ⚠️ 성분마다 굴리면 **대각선에서 크기가 √2배**가 되어 4px 계약이 5.66px이 된다.
	#    각도를 굴리고 크기를 굴려야 `offset.length() ≤ SHAKE_MAX_AMPLITUDE`가 참이다.
	camera.offset = Vector2.from_angle(rng.randf_range(0.0, TAU)) \
		* rng.randf_range(amplitude * 0.55, amplitude)
	cam_peak = maxf(cam_peak, camera.offset.length())
	var tween := camera.create_tween()
	tween.tween_property(camera, "offset", Vector2.ZERO, span).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## §7.4 계측. `_process`가 매 프레임 부른다 — 카메라 오프셋 하나를 읽는 O(1)이다.
## 흔들림 설정을 끄면 `shake_camera`가 즉시 반환하므로 이 값은 **0.0으로 남는다**
## (그 음성 축을 `--cycle-test`가 문다).
func _sample_camera_peak() -> void:
	if not is_instance_valid(player):
		return
	var camera := player.get_node_or_null("PlayerCamera") as Camera2D
	if not is_instance_valid(camera):
		return
	cam_peak = maxf(cam_peak, camera.offset.length())

func reset_cam_peak() -> void:
	cam_peak = 0.0

func play_sound(sound_name: String, volume_db: float = 0.0) -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play(sound_name, volume_db + effects_volume_db)

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]

# =============================================================================
# V9: 전투 중 저장 정책 (설계 §9 · handoff-v7 §11-5 · handoff-v8 §9-2가 남긴 구멍)
# =============================================================================
# **전투·모달 중에는 스냅샷을 쓰지 않는다.** 마지막으로 쓴 "보스방 진입 전 필드"
# 스냅샷이 그대로 남고, 이어하기는 그 지점으로 돌아간다.
#
# 왜 이 정책인가 — 대안 둘을 실제로 재 보고 고른 결과다.
#   ① 전투 상태를 저장한다 → `stage_boss` / `stage_boss_cycle` / `stage_boss_factory` /
#      `stage_boss_pools`(장판·소환) / `player_status`(도트·중첩) / telegraph 진행도 /
#      마왕 `boss` `boss_cycle` `boss_factory`까지 전부 직렬화해야 한다. 되살릴 때
#      "선딜 0.4초 남은 telegraph"를 복원할 방법이 없어 **반드시 어딘가 어긋난다**.
#   ② 저장하되 보스방 앞 필드로 정규화한다 → 스냅샷을 쓸 때 클럭·좌표·`stage_boss_cleared`
#      를 전투 전 값으로 되돌려 적어야 하는데, 그 "전투 전 값"을 따로 들고 있어야 한다.
#      = 결국 전투 전 스냅샷을 보관하는 것과 같고 코드만 늘어난다.
#   ③ **채택**: 전투가 열려 있는 동안 자동 저장을 쉰다. 5초 주기 틱은 계속 돌지만
#      `_save_run_snapshot()`이 파일을 건드리지 않고 돌아간다. 코드는 이 함수 4줄이다.
#
# 결과적으로 플레이어가 잃는 최대치는 "보스방에 들어간 뒤의 진행"이다. 보스전은
# 45~90초 창이고 도중에 얻는 영구 자원이 없으므로(트로피는 격파 뒤에 나온다)
# 되돌아가도 손해가 정확히 0이다. 반대로 지원했다면 "격파 직후 트로피를 받기 전"에
# 이어하기를 하면 트로피가 증발하거나 두 번 나오는 구멍이 생긴다.
#
# 막는 구간 4종 — `state`만으로는 부족하다(강림 보스는 state가 "playing"이다).
func _run_save_blocked_reason() -> String:
	# ① 마왕전 · ② 보스방 아레나 전투. 둘 다 state == "boss"다.
	if state == "boss":
		return "boss_battle"
	# ③ 강림 밸브로 필드에 내려온 스테이지 보스(state는 "playing" 그대로 — §6.6).
	if stage_boss_active():
		return "stage_boss_descended"
	# ④ 격파 → 트로피 2택1 → 배치까지의 모달 사슬. 이 사이에 저장하면 훅이 통째로
	#    사라져 트로피 하나를 조용히 잃는다(handoff-v8 §9-2가 경고한 그 자리).
	if not pending_stage_trophy.is_empty() or not pending_trophy.is_empty() \
		or pending_trophy_followup != "" or trophy_place_pending:
		return "trophy_modal"
	# ⑤ U3 길잡이가 도는 동안(새 런의 첫 낮 · playing 서브모드). "튜토리얼 절반"이라는
	#    상태를 schema 3에 새로 넣는 값이 안 맞는다 — 잃는 것은 런 시작 40초뿐이고,
	#    길잡이가 끝나는 순간 `_finish_guide()`가 한 번 저장한다.
	if guide_active:
		return "guide"
	return ""

## 지금 자동 저장이 도는가. HUD·테스트·문서가 같은 판정을 보게 하는 공개 창구다.
func run_save_allowed() -> bool:
	return is_instance_valid(player) and factory != null \
		and state == "playing" and _run_save_blocked_reason().is_empty()

func _save_run_snapshot() -> void:
	# V9: state 화이트리스트가 ["playing", "boss"] → **"playing" 하나**로 좁아졌다.
	# 나머지 판정은 전부 `_run_save_blocked_reason()`이 한다(위 정책 주석).
	if not run_save_allowed():
		return
	var snapshot := {
		# 스냅샷 표식. 이 값보다 낮거나 없는 저장은 `_read_run_snapshot()`이 읽지 않고
		# 버린다(설계 §7.2 R8 — 파일명은 불변, 내용만 폐기).
		"schema_version":RUN_SCHEMA_VERSION,
		"character_id":selected_character_id,
		"playtime":elapsed_time,
		"level":level, "experience":experience, "xp_target":xp_target,
		"kills":kills, "gold":gold,
		# V9 폐기 3키: `phase_elapsed` · `cycle_number` · `is_night`.
		# v1 스냅샷에 클럭 사전이 없던 시절의 낱개 폴백이었다. schema 3은 v1·v2를
		# 통째로 버리므로 `deadline_clock` 하나만 남긴다(§9의 "의미가 바뀐 키" 정리).
		"deadline_clock":clock.to_snapshot(),
		"demon_lord":demon_lord.to_snapshot(),
		"omen_night_count":omen_night_count,
		"player_position":player.global_position, "player_health":player.health,
		"player_skills":player.applied_skills.duplicate(),
		"player_trophies":player.trophy_orbs.duplicate(),
		# V8 신규 키. 트로피 효과의 **유일한 진실 원천**이다(스탯을 저장하지 않고
		# 스테이지 번호만 저장해 `TrophyLibrary.merge_effects()`로 다시 세운다 — 설계 §9).
		"trophy_stages":player.trophy_stages.duplicate(),
		"growth_cap_conversions":growth_cap_conversions,
		"run_synergy_triggers":run_synergy_triggers,
		# V9 폐기 2키: `player_advancement_branch` · `player_advancement_tier`.
		# `trophy_stages`가 트로피 효과의 유일한 진실 원천이고 `restore_trophies()`가
		# 두 필드를 다시 세운다 — 저장할 이유가 없다. **필드 자체는 남는다**
		# (`combat_resolver.gd:823`이 `last_trophy_id`를 읽는다 · handoff-v8 §6).
		"player_shields":player.shield_charges, "player_rollbacks":player.rollback_charges,
		"factory_slots":factory.slots.duplicate(true),
		# Y2 신설 키(§9.3 "저장 `rail_runes`"). 레일 각인은 칸이 아니라 레일이 소유하므로
		# `factory_slots`에 들어 있지 않다 — 이 줄이 없으면 이어하기 때 조용히 사라진다.
		# **schema는 올리지 않는다**: 없는 스냅샷은 빈 배열로 떨어지고 그것이 곧 옛 상태와
		# 같다(레일 각인이 없던 런). schema 4는 Y6가 다른 신설 키들과 함께 올린다.
		"factory_rail_runes":factory.rail_runes.duplicate(true),
		"factory_inventory":factory.inventory.duplicate(true),
		"factory_equipment":factory.equipment.duplicate(true),
		"run_cycle_seed":run_cycle_seed,
		"selected_skills":selected_skills.duplicate(),
		"rejected_skills":rejected_skills.duplicate(),
		"boss_items":boss_items.duplicate(),
		# V9 개명: `boss_advancement` → `trophy_effects`(설계 §9 · handoff-v8 §6).
		# 담기는 것은 **트로피 2택1에서 버린 카드**들이다 — 마왕이 가져가는 몫이라
		# "각성 계보"라는 v2 이름이 v3에서는 거짓말이 됐다. 필드명(`trophy_reject_skills`)은
		# `demon_lord.gd:84 :349-351`이 직접 읽으므로 **저장 키만** 갈았다(handoff-v8 §9-7).
		"trophy_effects":trophy_reject_skills.duplicate(true),
		"opened_features":opened_features.duplicate(true),
		"camp_states":camp_states.duplicate(true),
		# === Y6 신설 5키 (schema 4 · §6.1 저장 규약) ===
		# 발견은 **배열**로 적는다(§6.1 "`discovered_features: Array[String]`").
		# 사건은 표식 노드를 빼고 순수 데이터만 적는다 — Node는 직렬화되지 않는다.
		"discovered_features":discovered_features.keys(),
		"stage_events":_serialize_stage_events(),
		"run_event_count":run_event_count,
		"consumable_item":consumable_item,
		"night_eye_nights":night_eye_nights,
		# === W9 경계 접촉 3줄(W12 소유 구역 · 가산만) ===
		# handoff-w8 §3.4가 W12에 지시한 그 스니펫이다. 지금 넣지 않으면 이어하기 후
		# 균열의 위치·클리어 여부·정예 잔여 수가 통째로 사라져 균열이 재활성화된다.
		"rift_state":world.export_rift_state(),
		"rift_states":rift_states.duplicate(true),
		"pact_uses":pact_uses.duplicate(),
		"rune_shop_purchases":rune_shop_purchases,
		"spy_wipe_stage":spy_wipe_stage,
		# === 잠식 · 런 기록 (W10 신설 · V7 개명 · V9 확정) ===
		# 잠식은 dwell 임계에서 다시 켜지므로 복원 후 스스로 되살아나지만,
		# 표식 마릿수는 복원할 방법이 없어 저장한다.
		"blight_active":blight_active,
		"blight_marked":blight_marked,
		# === 스테이지 축 (V5·V7 가산 → V9 확정) ===
		"stage_boss_cleared":stage_boss_cleared,
		"stage_index":clock.stage,
		"stage_dwell":clock.dwell,
		"stage_seed":stage_world_seed(clock.stage),
		"stages_cleared":clock.stages_cleared,
		"stage_descent_pending":stage_descent_pending,
		"camp_rest_used":camp_rest_used,
		"run_peak_steps":run_peak_steps,
		"boss_reload_windows":boss_reload_windows,
		# === V9 신규 3키 ===
		# `total_days`는 `deadline_clock.day`와 같은 값이다. 그래도 최상위에 복사하는
		# 이유는 **로비가 클럭을 만들지 않고 스냅샷 사전만 읽기 때문**이다
		# (`_load_progress()` → 이어하기 버튼 표기 · 설계 §9의 신규 키 목록).
		"total_days":clock.day_number,
		# 랜드마크 3종 좌표. 시드가 같으면 다시 만들어도 같은 자리가 나오지만
		# (`_place_stage_landmarks()`가 `stage_seed`만 본다), 생성식이 바뀌면 이어하기가
		# 성·캠프·보스문을 통째로 옮겨 버린다 — 설계 §9가 말한 "결정성 보험"이다.
		"stage_landmarks":world.get_stage_landmarks() if is_instance_valid(world) else {},
		# ⚠️ V10: `stage_bosses_defeated`가 여기 있었다. 읽는 코드가 없어 삭제했다
		#    (위 선언부 주석 · 격파 수는 `stages_cleared`가 이미 든다).
		# ⚠️ **일부러 저장하지 않는 것** (V9 판정 · 설계 §9 "상태이상은 저장하지 않는다")
		#   `player_status` / `player_status_dot_total`  전투 중 수 초짜리 휘발 상태 → 복원 후 0
		#   `stage_boss*` 일체 · `boss` · `boss_cycle`    전투 중엔 저장 자체를 안 한다(위 정책)
		#   `stage_boss_telegraphs` / `_phase_shifts`     보스 1회전 스코프. 저장 시점엔 항상 0
		#   `shop_offers` / `shop_refresh_count`          상점 1회 방문 스코프(`_open_shop`이 리셋)
		#   `boss_peak_steps` / `active_omen` / `inside_camp` / `stage_scaled_enemies`
	}
	var config := ConfigFile.new()
	config.load(GameTuning.PROGRESS_PATH)
	config.set_value("run", "active", true)
	config.set_value("run", "snapshot", snapshot)
	config.save(GameTuning.PROGRESS_PATH)
	saved_run_available = true
	saved_run_playtime = elapsed_time
	saved_run_stage = clock.stage
	saved_run_total_days = clock.day_number

func _read_run_snapshot() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(GameTuning.PROGRESS_PATH) != OK or not bool(config.get_value("run", "active", false)):
		return {}
	var snapshot = config.get_value("run", "snapshot", {})
	if not snapshot is Dictionary:
		return {}
	# 구 스냅샷은 읽지 않고 버린다 — **크래시 대신 "새 런"**이다(설계 §7.2 R8).
	#   v1 (schema_version 키 없음) : 5칸·각인 이전 구조라 옮길 것이 없다.
	#   v2 (schema_version == 2)    : V9가 폐기. 키 이름은 대부분 같지만 **의미가 다르다**
	#                                 (7일 상한 · 계보 · 일수 트리거 잠식 · 하루 매매 계약).
	#                                 읽으면 "말은 되는데 틀린" 런이 살아나므로 더 위험하다.
	if int((snapshot as Dictionary).get("schema_version", 0)) < RUN_SCHEMA_VERSION:
		return {}
	return (snapshot as Dictionary).duplicate(true)

## 스냅샷 한 값. 새 키가 없으면 `SNAPSHOT_LEGACY_KEYS`의 구 키를 차례로 본다.
## `_restore_run_snapshot()`은 **반드시 이 함수로만** 스냅샷을 읽는다(개명 폴백 단일 통로).
func _snapshot_value(snapshot: Dictionary, key: String, fallback: Variant) -> Variant:
	if snapshot.has(key):
		return snapshot[key]
	for legacy: String in (SNAPSHOT_LEGACY_KEYS.get(key, []) as Array):
		if snapshot.has(legacy):
			return snapshot[legacy]
	return fallback

func _clear_run_save() -> void:
	var config := ConfigFile.new()
	config.load(GameTuning.PROGRESS_PATH)
	config.set_value("run", "active", false)
	if config.has_section_key("run", "snapshot"):
		config.erase_section_key("run", "snapshot")
	config.save(GameTuning.PROGRESS_PATH)
	saved_run_available = false
	saved_run_playtime = 0.0
	saved_run_stage = 0
	saved_run_total_days = 0

# =============================================================================
# V9: 복원 순서 (설계 부록 B V9 — "월드 재생성 → 랜드마크 복원 → 덱 → 플레이어")
# =============================================================================
# ⚠️ **순서가 곧 정확성이다.** V5~V8이 각자 필요한 줄을 뒤에 덧붙이는 동안 순서가
# 어긋났고, V9가 그 회귀 하나를 여기서 잡았다:
#
#   구 순서 : clock → (스테이지가 다르면) 월드 재생성 → … → `run_cycle_seed` 복원
#   문제    : `stage_world_seed(n)`이 `run_cycle_seed`에서 파생되는데, 재생성 시점의
#             `run_cycle_seed`는 **아직 저장된 값이 아니다**(`_begin_run()`이 방금
#             `rng.randi()`로 새로 뽑았거나 이전 런의 값이 남아 있다).
#             → 이어하기를 하면 지형·랜드마크·균열 후보 자리가 통째로 달라졌다.
#             스테이지 1 저장은 `world.get_stage() == 1`이라 재생성조차 건너뛰어
#             **틀린 시드로 만든 월드를 그대로 썼다.**
#   새 순서 : ① 시드 → ② 클럭 → ③ 월드 재생성(저장된 stage_seed로) → ④ 랜드마크 →
#             ⑤ 균열·랜드마크 개방 → ⑥ 덱 → ⑦ 플레이어 → ⑧ 시각 상태 스냅
#
# 스냅샷은 **반드시 `_snapshot_value()`로 읽는다** — 개명 폴백의 단일 통로다.
func _restore_run_snapshot(snapshot: Dictionary) -> void:
	# ---- ① 시드가 가장 먼저다. 월드·균열·바늘이 전부 여기서 파생된다 -----------
	run_cycle_seed = int(_snapshot_value(snapshot, "run_cycle_seed", run_cycle_seed))
	if is_instance_valid(player_cycle):
		player_cycle.cycle_seed_base = run_cycle_seed
	elapsed_time = float(_snapshot_value(snapshot, "playtime", 0.0))
	level = maxi(1, int(_snapshot_value(snapshot, "level", 1)))
	experience = maxi(0, int(_snapshot_value(snapshot, "experience", 0)))
	xp_target = maxi(1, int(_snapshot_value(snapshot, "xp_target", 8)))
	kills = maxi(0, int(_snapshot_value(snapshot, "kills", 0)))
	gold = maxi(0, int(_snapshot_value(snapshot, "gold", 20)))
	# ---- ② 클럭 — 스테이지·dwell·총 일수·등급 플래그의 단일 소유자 -------------
	clock.from_snapshot(_snapshot_value(snapshot, "deadline_clock", {}) as Dictionary)
	# ---- ③ 월드 재생성. **조건 없이 항상 한다** ------------------------------
	# `_begin_run()`이 세워 둔 스테이지 1 월드는 (시드가 아직 안 맞았으므로) 스테이지가
	# 같아도 버려야 한다. 저장된 `stage_seed`를 그대로 먹여 생성식 변화에도 버티게 한다.
	if is_instance_valid(world):
		_rebuild_stage_world(clock.stage, int(_snapshot_value(snapshot, "stage_seed", 0)))
	# ---- ④ 랜드마크 복원(결정성 보험 · 설계 §9) ------------------------------
	_restore_stage_landmarks(_snapshot_value(snapshot, "stage_landmarks", {}) as Dictionary)
	# ---- ⑤ 스테이지 스코프 상태 ----------------------------------------------
	stage_descent_pending = bool(_snapshot_value(snapshot, "stage_descent_pending", false))
	camp_rest_used = bool(_snapshot_value(snapshot, "camp_rest_used", false))
	stage_boss_cleared = bool(_snapshot_value(snapshot, "stage_boss_cleared", false))
	demon_lord.from_snapshot(_snapshot_value(snapshot, "demon_lord", {}) as Dictionary)
	omen_night_count = maxi(0, int(_snapshot_value(snapshot, "omen_night_count", 0)))
	selected_skills.assign(_snapshot_value(snapshot, "selected_skills", []))
	rejected_skills.assign(_snapshot_value(snapshot, "rejected_skills", []))
	boss_items.assign(_snapshot_value(snapshot, "boss_items", []))
	# V9 개명: `boss_advancement` → `trophy_effects`(구 키는 폴백표가 받는다).
	trophy_reject_skills.assign(_snapshot_value(snapshot, "trophy_effects", []))
	opened_features = (_snapshot_value(snapshot, "opened_features", {}) as Dictionary).duplicate(true)
	# === Y6: 발견·사건·소비 칸 (schema 4) ===
	# 순서가 중요하다 — `_rebuild_stage_world()`가 바로 위에서 발견을 초기화했으므로
	# **그 뒤에** 저장된 발견을 얹어야 한다(안 그러면 화살표가 통째로 꺼진 채 이어진다).
	_restore_discovered_features(_snapshot_value(snapshot, "discovered_features", []))
	_restore_stage_events(_snapshot_value(snapshot, "stage_events", []) as Array)
	run_event_count = maxi(0, int(_snapshot_value(snapshot, "run_event_count", 0)))
	consumable_item = String(_snapshot_value(snapshot, "consumable_item", ""))
	if not CONSUMABLES.has(consumable_item):
		consumable_item = ""
	night_eye_nights = clampi(int(_snapshot_value(snapshot, "night_eye_nights", 0)), 0, 1)
	night_eye_active = night_eye_nights > 0 and is_night
	camp_states = (_snapshot_value(snapshot, "camp_states", camp_states) as Dictionary).duplicate(true)
	# 균열 · 성 NPC (W9의 5키 — 저장 쪽과 짝).
	# `_rebuild_stage_world()`가 방금 `begin_stage()`로 스테이지 시드를 깔았으므로
	# 여기서 덮어쓰면 그대로 이어진다(요청 순번까지 복원되어 다음 균열 좌표도 같아진다).
	world.import_rift_state(_snapshot_value(snapshot, "rift_state", {}) as Dictionary)
	rift_states = (_snapshot_value(snapshot, "rift_states", {}) as Dictionary).duplicate(true)
	pact_uses = (_snapshot_value(snapshot, "pact_uses", pact_uses) as Dictionary).duplicate()
	rune_shop_purchases = maxi(0, int(_snapshot_value(snapshot, "rune_shop_purchases", 0)))
	spy_wipe_stage = maxi(0, int(_snapshot_value(snapshot, "spy_wipe_stage", 0)))
	# 잠식 · 런 기록.
	blight_active = bool(_snapshot_value(snapshot, "blight_active", false))
	blight_marked = maxi(0, int(_snapshot_value(snapshot, "blight_marked", 0)))
	run_peak_steps = maxi(0, int(_snapshot_value(snapshot, "run_peak_steps", 0)))
	boss_reload_windows = maxi(0, int(_snapshot_value(snapshot, "boss_reload_windows", 0)))
	# V5: 잠식은 일수가 아니라 dwell 임계에서 켜진다. 저장된 값을 살리되 클럭이
	# 이미 임계를 넘겼으면 켠다(이어하기로 잠식이 조용히 꺼지는 회귀를 막는다).
	blight_active = blight_active or clock.blight_active()
	# ---- ⑥ 덱 — 5칸 · 각인 · 보관함 · 장비 ------------------------------------
	factory.slots.assign(_snapshot_value(snapshot, "factory_slots", []))
	if factory.slots.is_empty():
		factory.reset()
	factory.ensure_slot_count(FactoryDeck.SLOT_COUNT)
	factory.normalize_slots()
	factory.inventory.assign(_snapshot_value(snapshot, "factory_inventory", []))
	factory.equipment.assign(_snapshot_value(snapshot, "factory_equipment", []))
	# Y2: 레일 각인. 옛 스냅샷(키 없음)이면 빈 배열 — 상한을 넘긴 저장이 들어와도
	# `attach_rail_rune()`이 스스로 거른다(직접 assign하지 않는 이유).
	factory.rail_runes.clear()
	for rail_value in (_snapshot_value(snapshot, "factory_rail_runes", []) as Array):
		if rail_value is Dictionary:
			factory.attach_rail_rune(rail_value as Dictionary)
	# ---- ⑦ 플레이어 ----------------------------------------------------------
	player.applied_skills.assign(_snapshot_value(snapshot, "player_skills", []))
	player.trophy_orbs.assign(_snapshot_value(snapshot, "player_trophies", []))
	# V8: 트로피가 효과의 유일한 진실 원천이다 — `restore_trophies()`가
	# `last_trophy_id` / `trophy_count` 두 필드를 다시 세운다.
	# (V9가 그 둘의 **저장 키를 지웠다.** 필드는 combat_resolver가 읽으므로 남는다.)
	player.restore_trophies(_snapshot_value(snapshot, "trophy_stages", []))
	growth_cap_conversions = maxi(0, int(_snapshot_value(snapshot, "growth_cap_conversions", 0)))
	run_synergy_triggers = maxi(0, int(_snapshot_value(snapshot, "run_synergy_triggers", 0)))
	player._rebuild_stats()
	player.health = clampf(float(_snapshot_value(snapshot, "player_health", player.max_health)), 1.0, player.max_health)
	player.displayed_health = player.health
	player.trailing_health = player.health
	player.shield_charges = mini(int(_snapshot_value(snapshot, "player_shields", 0)), player.shield_capacity)
	player.rollback_charges = mini(int(_snapshot_value(snapshot, "player_rollbacks", 0)), player.rollback_capacity)
	player.global_position = _snapshot_value(snapshot, "player_position", Vector2.ZERO)
	# 설계 §9: **상태이상은 저장하지 않는다.** 전투 중 수 초짜리 휘발 상태라 복원 후 0이다.
	StatusEngine.clear(player_status)
	player_status_dot_total = 0.0
	player_dot_flush_timer = 0.0
	# ---- ⑧ 월드 표시 상태 · 시각 상태 스냅 -----------------------------------
	world.set_opened_features(opened_features)
	var cleared := {}
	for direction: String in camp_states:
		cleared[direction] = bool(camp_states[direction].get("cleared", false))
	world.set_cleared_trial_camps(cleared)
	# 관문을 이미 깼으면 보스문이 열린 그림으로 서야 한다(`advance_stage()`와 짝).
	world.set_boss_gate_cleared(stage_boss_cleared)
	_snap_world_lighting()
	_reset_player_cycle()

## 저장된 랜드마크 3종을 월드에 되박는다.
##
## 시드를 먼저 복원했으므로 `_place_stage_landmarks()`가 이미 같은 자리를 만들었다 —
## 이 함수는 보통 **같은 값을 같은 값으로 덮는다**(멱등). 존재 이유는 생성식이 바뀐
## 뒤에 열린 세이브다. 좌표가 달라지면 성·캠프·보스문이 통째로 이사해 `opened_features`
## 와 나침반이 어긋나는데, 그때 저장된 좌표가 이긴다(설계 §9 "재생성 대신 복원").
##
## ⚠️ V10(2026-08-09): V9는 `world._landmark_chunks`(사적 캐시)를 여기서 직접 세웠다 —
## 그 웨이브가 `world_grid.gd`를 열 수 없었기 때문이다(handoff-v9 §9 #5).
## 이제 월드에 **`set_stage_landmarks()` 공개 창구**가 있고 청크 캐시 파생 규칙은
## 그 파일 한 곳에만 산다. 이 함수는 창구를 부르는 한 줄로 줄었다.
func _restore_stage_landmarks(saved: Dictionary) -> void:
	if not is_instance_valid(world) or saved.is_empty():
		return
	world.set_stage_landmarks(saved)

## 조명·안개를 **보간 없이** 지금 페이즈/스테이지 값으로 맞춘다.
##
## `_update_world_lighting()`은 프레임마다 `lerp(delta * 2.0)`로 다가가는 함수라,
## 이어하기 직후에는 흰색(`_begin_run()`이 세운 초기값)에서 목표색까지 약 1초가 걸린다.
## 5스테이지 밤(#2f2f52)으로 이어하면 **화면이 한 번 하얗게 번쩍인 뒤** 어두워졌다.
## 로드는 "전환"이 아니라 "그 순간으로 돌아가기"이므로 즉시 값이다.
## 로비 이어하기 버튼 문구. 저장이 없으면 비활성 버튼의 설명이 된다.
## 스테이지 번호가 0이면(= schema 3 이전 형태로 기록된 진행) 스테이지 절을 뺀다.
func _saved_run_label() -> String:
	if not saved_run_available:
		return "이어하기 · 저장된 모험 없음"
	if saved_run_stage < 1:
		return "이어하기 · 모험 시간 %s" % _format_time(saved_run_playtime)
	var stage_index := clampi(saved_run_stage - 1, 0, GameTuning.STAGE_COUNT - 1)
	return "이어하기 · %d스테이지 %s · %d일차 · %s" % [
		saved_run_stage, GameTuning.STAGE_NAMES[stage_index],
		maxi(1, saved_run_total_days), _format_time(saved_run_playtime)
	]

## 로비 이어하기 **칩**의 본문. U1 v3에서 표기가 버튼 라벨에서 칩으로 내려왔다.
## `_saved_run_label()`은 `--save-test`의 lobby 묶음이 문구를 통째로 대조하므로
## 한 글자도 손대지 않는다 — 이쪽은 접두어 "이어하기 · "만 뺀 짧은 형태다.
func _saved_run_detail() -> String:
	if not saved_run_available:
		return "저장된 모험이 없습니다"
	if saved_run_stage < 1:
		return "모험 시간 %s" % _format_time(saved_run_playtime)
	var stage_index := clampi(saved_run_stage - 1, 0, GameTuning.STAGE_COUNT - 1)
	return "%d스테이지 %s · %d일차 · %s" % [
		saved_run_stage, GameTuning.STAGE_NAMES[stage_index],
		maxi(1, saved_run_total_days), _format_time(saved_run_playtime)
	]

func _snap_world_lighting() -> void:
	if not is_instance_valid(world):
		return
	var index := clock.stage_index()
	if is_instance_valid(canvas_modulate):
		canvas_modulate.color = GameTuning.STAGE_NIGHT_MODULATE[index] if is_night else GameTuning.STAGE_DAY_MODULATE[index]
	world.set_night_amount(1.0 if is_night else 0.0)
	_apply_stage_grade()

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(GameTuning.PROGRESS_PATH) == OK:
		unlocked_character_count = clampi(int(config.get_value("progress", "unlocked_characters", 1)), 1, 3)
		master_volume_db = float(config.get_value("settings", "master_volume_db", -4.0))
		effects_volume_db = float(config.get_value("settings", "effects_volume_db", 0.0))
		screen_shake_enabled = bool(config.get_value("settings", "screen_shake", true))
		damage_numbers_enabled = bool(config.get_value("settings", "damage_numbers", true))
		fullscreen_enabled = bool(config.get_value("settings", "fullscreen", false))
		# U3: 스포트라이트 길잡이를 이미 봤는가. 설정의 「온보딩 다시 표시」가 같이 끈다.
		guide_seen = bool(config.get_value("settings", "guide_seen", false))
		saved_run_available = bool(config.get_value("run", "active", false))
		var snapshot = config.get_value("run", "snapshot", {})
		var run_data: Dictionary = (snapshot as Dictionary) if snapshot is Dictionary else {}
		# V9: 여기서 스키마를 한 번 거른다. 폐기 대상(schema < 3) 스냅샷이 남아 있으면
		# 버튼만 활성인데 누르면 `_continue_saved_run()`이 빈 사전을 받아 로비로 되튄다.
		if int(run_data.get("schema_version", 0)) < RUN_SCHEMA_VERSION:
			# Y6(리스크 5): 버려진 스냅샷이 실제로 있었다면 **조용히 사라지지 않게**
			# 로비에서 한 번 알린다. 플래그는 로비가 한 번 읽고 스스로 끈다.
			if not run_data.is_empty():
				saved_run_dropped = true
			run_data = {}
			saved_run_available = false
		saved_run_playtime = float(run_data.get("playtime", 0.0))
		saved_run_stage = clampi(int(run_data.get("stage_index", 0)), 0, GameTuning.STAGE_COUNT)
		saved_run_total_days = maxi(0, int(run_data.get("total_days", 0)))
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, master_volume_db)
	# 볼륨과 달리 전체 화면은 저장만 되고 복원되지 않아, 다시 켜면 창모드인데 설정
	# 체크박스만 켜짐으로 남아 있었습니다 (P1-10).
	# 자동 테스트·캡처(사용자 인자가 있는 실행)는 창 모드를 강제로 바꾸지 않습니다.
	if OS.get_cmdline_user_args().is_empty():
		var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != target_mode:
			DisplayServer.window_set_mode(target_mode)

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.load(GameTuning.PROGRESS_PATH)
	config.set_value("progress", "unlocked_characters", unlocked_character_count)
	config.set_value("settings", "master_volume_db", master_volume_db)
	config.set_value("settings", "effects_volume_db", effects_volume_db)
	config.set_value("settings", "screen_shake", screen_shake_enabled)
	config.set_value("settings", "damage_numbers", damage_numbers_enabled)
	config.set_value("settings", "fullscreen", fullscreen_enabled)
	config.set_value("settings", "guide_seen", guide_seen)
	config.save(GameTuning.PROGRESS_PATH)

# -----------------------------------------------------------------------------
# 한국어 조사 헬퍼
# -----------------------------------------------------------------------------
# 카드·NPC 이름은 데이터에서 오므로 조사를 문자열에 박아 둘 수 없습니다.
# 마지막 글자의 받침 유무로 조사를 고르고, 한글이 아니면 받침 없는 쪽을 씁니다.
func _has_final_consonant(word: String) -> bool:
	if word.is_empty():
		return false
	var code := word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0

func _particle_wa(word: String) -> String:
	return "과" if _has_final_consonant(word) else "와"

func _particle_eul(word: String) -> String:
	return "을" if _has_final_consonant(word) else "를"

func _particle_eun(word: String) -> String:
	return "은" if _has_final_consonant(word) else "는"

# YZ: 「%s이(가)」 표기를 지우려고 둔 주격 조사 판정. `_particle_eun()`과 같은 받침 검사다.
func _particle_i(word: String) -> String:
	return "이" if _has_final_consonant(word) else "가"

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	# U2 v3: 3/4px → **2/3px**(ui-style-v3 §3). 11~13px 한글은 획 사이가 1px밖에 안 돼
	# 3~4px 외곽선이 속공간을 메운다 — `잔류` `과밀` 같은 글자가 덩어리로 읽혔다(캡처 실측).
	# 필드 위 가독성은 유지되고 획은 산다. 킷 패널 안의 글자는 `_kit_label`이 아예 끈다.
	label.add_theme_constant_override("outline_size", 2 if font_size <= UI_BODY_SIZE else 3)
	return label

# X3(2026-08-09)가 `_hud_panel()`을 **삭제했다.** 이 함수는 "필드 HUD 패널의 단일 골격"
# (킷 9-slice 판 + 왼쪽 액센트 바 3px)이었고 호출부는 신상·스테이지·나침반·고스트 넷뿐이었다.
# 사용자 피드백 ⑥("블록을 제거하고 다시 디자인")이 그 넷을 전부 프레임리스로 만들면서
# 호출부가 0이 됐다. 필드 HUD에 다시 판을 깔고 싶어지면 **먼저 그 요구를 다시 읽을 것** —
# `--cycle-test hud_mini`·`hud_ghost`가 `not (node is Panel)`을 단언한다.
# 원본은 docs/handoff-x3.md §10과 docs/v1-archive/field_hud_v1.gd.txt에 있다.

## 필드 HUD의 "칸"(레일 슬롯 · 고스트 슬롯 · 마왕 레일 슬롯) 스타일박스 한 장.
##
## v1은 칸의 상태(비활성/활성/RELOAD/1회성 강조)를 **배경색 + 테두리색**으로 말했다.
## 킷 칸은 그림이 하나라 색을 얹을 자리가 `modulate_color`(곱연산)뿐이다. 그래서
## 같은 의미색을 **틴트**로 옮겼다 — 정보(되밟기 색 · RELOAD 청 · 카드색)는 그대로 살고
## 프레임만 킷이 된다. 곱연산이라 v1의 `darkened(0.86)` 같은 값을 그대로 쓰면 칸이
## 새까매지므로 `Color.WHITE.lerp(의미색, k)` 형태로 다시 잡았다.
##
## ⚠️ `UIKit`이 주는 박스는 **캐시된 공유 인스턴스**다. 그 자리에서 고치면 같은 박스를
## 쓰는 다른 화면까지 같이 바뀐다(ui-style-v3 §4). 반드시 `variant()`로 복제한다.
func _kit_cell_style(tone: UIKit.Tone, tint: Color) -> StyleBoxTexture:
	var box := UIKit.variant(UIKit.panel_box(tone, UIKit.Role.CELL)) as StyleBoxTexture
	box.modulate_color = tint
	return box

## 필드 HUD 위의 **의미색 글자를 읽히는 밝기까지만** 끌어올린다.
##
## v1 HUD 판은 거의 검정(`#0f1521`)이라 `GamePalette` 원색이 그대로 읽혔다. 킷 SLATE 판은
## 바탕이 `#345a52`(teal)라 어두운 계열이 3:1 밑으로 떨어진다 — 실측 대비:
## RED 2.02 · BLUE **1.71** · MAGENTA 2.21 · PURPLE 1.50. "수호 0 · 부활 0"(BLUE)이
## 첫 캡처에서 사실상 안 보였다.
##
## **색상(hue)은 건드리지 않고 명도만** 올린다 — 정보를 나르는 색을 다른 색으로 바꾸지
## 않는다는 ui-style-v3 §2 규칙의 테두리 안이다. 이미 밝은 색(TEXT · YELLOW · CYAN ·
## GREEN · MUTED)은 문턱을 넘으므로 **한 톨도 안 바뀐다**.
##   `lightened(k)`는 채널마다 `c + (1-c)k`라 휘도도 `L + (1-L)k`로 선형이다.
##   그래서 필요한 k를 반복 없이 한 번에 푼다.
const HUD_INK_MIN_LUMA := 0.66
func _hud_ink(color: Color) -> Color:
	var luma := color.get_luminance()
	if luma >= HUD_INK_MIN_LUMA:
		return color
	return color.lightened(clampf((HUD_INK_MIN_LUMA - luma) / maxf(1.0 - luma, 0.001), 0.0, 0.55))

func _button(text: String, color: Color, minimum_size: Vector2) -> Button:
	var button := Button.new()
	return _style_button(button, text, color, minimum_size)

## U2 v3 재스킨: v1의 "어두운 판 + 색 테두리 2px"를 킷 버튼 4변종 · 4상태로 갈았다.
## 호출부 60여 군데가 색으로 버튼 성격을 말해 왔으므로 그 색을 `_kit_btn_variant()`가
## 읽어 변종을 고른다 — 시그니처·호출부는 한 줄도 안 바뀐다.
## 폰트도 하드코딩 16 → `FONT_HEADING`(17)로 5단 안에 들어왔다(ui-style-v3 §5).
func _style_button(button: Button, text: String, color: Color, minimum_size: Vector2) -> Button:
	button.text = text
	button.custom_minimum_size = minimum_size
	button.size = minimum_size
	var variant := _kit_btn_variant(color)
	var kit_variant := UIKit.Btn.PRIMARY
	match variant:
		1: kit_variant = UIKit.Btn.NEUTRAL
		2: kit_variant = UIKit.Btn.DANGER
		3: kit_variant = UIKit.Btn.QUIET
	UIKit.style_button(button, kit_variant, UIKit.FONT_HEADING)
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("choice_color", color)
	button.set_meta("kit_btn_variant", variant)
	return button

# =============================================================================
# X1 — 스킬 선택 카드 (2026-08-09 사용자 피드백 ③ "가장 부각되어야 할 건 이미지")
# =============================================================================
# 최종 정보는 **여섯 개뿐이다**: 이미지(크게) · 이름 · 설명 한 문장 · 지속 칩 ·
# RELOAD 칩 · 보유 장수(있을 때만). 속성은 **텍스트가 아니라 색**으로 말한다 —
# ① 카드 프레임 틴트 ② 아이콘 뒤 판 틴트 ③ 좌상단 1글자 원소 마크(색약 대비).
#
# ── 두 밀도 ──────────────────────────────────────────────────────────────────
# 같은 함수가 두 화면을 그린다. 가르는 것은 **높이 하나**다:
#   hero(h ≥ 300) : 레벨업 2택. 아이콘 152px를 카드 가운데 세운다(구 48px의 3.2배 ·
#                   면적 10배). 이름·설명이 그 아래 가운데 정렬로 선다.
#   compact(h < 300): 보스 트로피 2택(494×252). 아이콘 104px가 왼쪽, 글이 오른쪽.
#                   패널 높이가 314px로 못 박혀 있어 hero가 안 들어간다.
# 두 밀도 모두 **태그 줄·피해계수·범위·한 바퀴 빚을 그리지 않는다.**
#
# ⚠️ 트로피 카드는 프레임 틴트를 받지 않는다(`frame_kind == 3`). GOLD 왕관 프레임이
#    "이건 트로피다"를 말하는 유일한 신호인데 원소색으로 물들이면 그 말이 지워진다.
#    대신 아이콘 판 틴트와 원소 마크는 그대로 받아 속성은 여전히 읽힌다.
const CHOICE_ICON_HERO := 152.0
const CHOICE_ICON_COMPACT := 104.0

## 원소 덧칠 한 겹. 킷 스타일박스의 `modulate_color`는 **곱셈**이라 어두운 판 위에서
## 찬 색(청록·자주)을 낼 수 없다 — 알파 합성 층이 있어야 색상이 그대로 올라온다.
## 색은 반드시 `_element_color()`에서 온다(hex 리터럴 신규 0건 · ui-style-v3 §12).
func _element_wash(parent: Control, rect: Rect2, tint: Color, alpha: float) -> ColorRect:
	var wash := ColorRect.new()
	wash.position = rect.position
	wash.size = rect.size
	wash.color = Color(tint.r, tint.g, tint.b, alpha)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	return wash

func _deal_choice_button(definition: Dictionary, card_size: Vector2 = CHOICE_CARD_SIZE,
		frame_kind: int = 0) -> Button:
	var card_id := String(definition["id"])
	var instance_data := DealCardLibrary.instance(card_id, 1)
	var ranked := DealCardLibrary.ranked(instance_data)
	var element := String(ranked.get("element", ""))
	var element_color := _element_color(element)
	var owned := 0 if factory == null else factory.get_total_count(card_id)
	var button := _button("", element_color, card_size)
	# 속성 = 프레임 색. 원색을 그대로 곱하면 9-slice 명암이 뭉개지므로 흰색과 섞어
	# 준다(0.55 = 캡처 실측으로 "속성이 보이되 프레임 문양이 살아 있는" 지점).
	if frame_kind == 3:
		_kit_card_skin(button, frame_kind)
	else:
		_kit_card_skin_tinted(button, frame_kind, Color.WHITE.lerp(element_color, 0.55))
	button.set_meta("choice_role", "skill")
	button.set_meta("card_element", element)
	button.set_meta("owned_count", owned)
	var hero := card_size.y >= 300.0
	var icon_box := CHOICE_ICON_HERO if hero else CHOICE_ICON_COMPACT
	# 본문 판 — 밝은 킷 카드 프레임 위에 글자를 바로 얹으면 대비가 무너진다(§6의 짝).
	# 그 어두운 판에 **속성색을 섞어** "블록색 통일"을 만든다.
	_kit_panel(button, Rect2(15.0, 15.0, card_size.x - 30.0, card_size.y - 30.0),
		UIKit.Tone.SLATE, UIKit.Role.CHIP)
	# **곱셈 틴트만으로는 찬 색을 낼 수 없다.** 킷 스타일박스가 주는 조절기는
	# `modulate_color`(곱셈) 하나뿐인데, SKILL 프레임 바탕이 주황(#f38c4c)이라 청록을
	# 곱하면 청록이 아니라 **탁한 갈색**이 나온다(캡처 실측 — 빙 카드가 뇌 카드와
	# 밝기만 다르고 색상은 같았다). 찬 원소 셋(빙·유·초)이 전부 "어두운 갈색"으로
	# 뭉치면 색이 정보를 못 나른다.
	#   → 그래서 **덧칠 층**을 하나 얹는다. 반투명 ColorRect는 곱셈이 아니라 알파
	#     합성이라 어두운 판 위에서도 원래 색상(hue)이 그대로 올라온다.
	#     게이지 핍이 이미 쓰는 층이라 새 어휘가 아니다(ui-style-v3 §12는 `StyleBoxFlat`
	#     신규 생성과 hex 리터럴을 금할 뿐 `ColorRect`를 금하지 않는다 — 색은 여기서도
	#     `GamePalette` 원소 표에서만 온다).
	_element_wash(button, Rect2(15.0, 15.0, card_size.x - 30.0, card_size.y - 30.0),
		element_color, 0.14)
	# 좌상단 1글자 원소 마크. HUD 레일(`RAIL_ELEMENT_MARK`)과 **같은 글자**다.
	# 색만으로는 색약 이용자가 화(주황)와 뇌(노랑)를 못 가른다 — 그 한 글자가 대비다.
	var mark := String(RAIL_ELEMENT_MARK.get(element, ""))
	if not mark.is_empty():
		var mark_rect := Rect2(24.0, 22.0, 46.0, 32.0)
		var mark_chip := _kit_panel(button, mark_rect, UIKit.Tone.SLATE, UIKit.Role.CHIP)
		mark_chip.self_modulate = Color.WHITE.lerp(element_color, 0.62)
		var mark_label := _label(mark, UI_HEADING_SIZE, element_color.lightened(0.42))
		mark_label.position = mark_rect.position
		mark_label.size = mark_rect.size
		mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(mark_label)
	# 보유 장수 — **있을 때만** 그린다. 0장 카드에 "0장"을 적으면 정보가 아니라 잡음이다.
	if owned > 0:
		var owned_rect := Rect2(card_size.x - 100.0, 22.0, 76.0, 32.0)
		_kit_panel(button, owned_rect, UIKit.Tone.SLATE, UIKit.Role.CHIP)
		var owned_label := _label("%d장" % owned, UI_BODY_SIZE + 1, GamePalette.GREEN)
		owned_label.position = owned_rect.position
		owned_label.size = owned_rect.size
		owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owned_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(owned_label)
	var icon := SKILL_ICON_SCRIPT.new()
	icon.size = Vector2(icon_box, icon_box)
	icon.setup(card_id, element_color)
	var name_rect := Rect2()
	var desc_rect := Rect2()
	var combo_rect := Rect2()
	if hero:
		icon.position = Vector2((card_size.x - icon_box) * 0.5, 56.0)
		name_rect = Rect2(28.0, 224.0, card_size.x - 56.0, 28.0)
		desc_rect = Rect2(36.0, 252.0, card_size.x - 72.0, 30.0)
		combo_rect = Rect2(36.0, 282.0, card_size.x - 72.0, 30.0)
	else:
		icon.position = Vector2(30.0, 62.0)
		name_rect = Rect2(154.0, 62.0, card_size.x - 184.0, 32.0)
		desc_rect = Rect2(154.0, 96.0, card_size.x - 184.0, 44.0)
		combo_rect = Rect2(154.0, 140.0, card_size.x - 184.0, 44.0)
	# 아이콘이 앉는 **블록**. 사용자가 말한 "블록색 통일"이 여기다 — 이미지가 주인공이고
	# 그 이미지가 딛고 선 판이 속성색이다. 칸 프레임(CELL) + 진한 덧칠.
	var plate := Rect2(icon.position - Vector2(14.0, 14.0), Vector2(icon_box + 28.0, icon_box + 28.0))
	_kit_panel(button, plate, UIKit.Tone.SLATE, UIKit.Role.CELL)
	_element_wash(button, plate, element_color, 0.34)
	button.add_child(icon)
	var name_label := _label(String(ranked.get("name", "기술")), UI_TITLE_SIZE if hero else 20,
		GamePalette.TEXT)
	name_label.position = name_rect.position
	name_label.size = name_rect.size
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if hero else HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(name_label)
	# Y4(피드백 ⑭ · FEEDBACK_Y §4.2) — **한 줄이 아니라 두 짧은 줄이다.**
	#   `desc`  16자 상한 · 본문색 — 무엇을 하는가(횟수 포함)
	#   `combo` 18자 상한 · **속성색** — 무엇과 어울리는가
	# 유저 요구는 "설명이 성능·콤보를 암시해야 한다"였다. 한 줄에 다 넣으면 길어지므로
	# 줄을 쪼개고 **색으로** 두 줄의 역할을 갈랐다 — 아래 줄이 속성색인 것이 곧
	# "이건 이 속성의 콤보다"라는 신호다. 카드 전체 줄 수는 4 → 5로 늘지만
	# 한 줄이 16/18자로 짧아져 읽는 시간은 오히려 준다(X4가 온보딩에서 검증한 방향).
	var description := _label(String(ranked.get("desc", "")), UI_BODY_SIZE + 1, GamePalette.TEXT)
	description.clip_text = false
	description.position = desc_rect.position
	description.size = desc_rect.size
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if hero else HORIZONTAL_ALIGNMENT_LEFT
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(description)
	var combo_text := String(ranked.get("combo", ""))
	if not combo_text.is_empty():
		# 어두운 칩 판 위라 원색 그대로는 뜨거워 보인다 — 원소색을 살짝 올려 쓴다.
		# 트로피 카드(GOLD 프레임)도 이 줄만은 속성색을 받는다(프레임과 역할이 다르다).
		# 캡처 실측: `lightened(0.34)` · 13px는 어두운 칩 + 원소 덧칠 0.14 위에서
		# 흰 본문줄과 **밝기가 비슷해져** 두 줄이 한 덩어리로 읽혔다.
		# 크기를 본문과 같게 올리고 색을 한 단계 더 띄운다 — 두 줄이 색으로 갈리는 것이
		# 이 화면의 검수 항목이다(§4.2 "두 줄이 서로 다른 색인가").
		var combo := _label(combo_text, UI_BODY_SIZE + 1, element_color.lightened(0.52))
		combo.name = "ChoiceCombo"
		combo.clip_text = false
		combo.position = combo_rect.position
		combo.size = combo_rect.size
		combo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if hero else HORIZONTAL_ALIGNMENT_LEFT
		combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(combo)
	# 지속 / RELOAD 칩 — **U2와 같은 위젯·같은 색**이다(레일 카드 블록과 단일 언어).
	# 사용자가 "RELOAD 시간이 시각화되어 있어서 괜찮다"고 지목한 바로 그 두 칩이다.
	var meter_h := 20.0
	var meter_y := card_size.y - meter_h - 18.0
	var half := (card_size.x - 60.0 - 8.0) * 0.5
	_add_metric_bar(button, Vector2(30.0, meter_y), Vector2(half, meter_h),
		"지속 %.2f초" % float(ranked.get("duration", 0.0)),
		float(ranked.get("duration", 0.0)), 2.8, GamePalette.CYAN, UI_CAPTION_SIZE)
	_add_metric_bar(button, Vector2(38.0 + half, meter_y), Vector2(half, meter_h),
		"RELOAD %.2f초" % float(ranked.get("reload", 0.0)),
		float(ranked.get("reload", 0.0)), 1.8, GamePalette.ORANGE, UI_CAPTION_SIZE)
	return button

func _build_choice_card_body(button: Button, card: Dictionary, card_size: Vector2, tag_text: String, description_text: String, lines: Array, badge_text: String = "", badge_color: Color = GamePalette.CYAN, badge_part: String = "") -> void:
	# 선택 모달 카드의 공통 골격. 왼쪽 위에 표준 카드 블록, 오른쪽에 분류/이름/태그,
	# 아래에 설명과 요약 줄들이 놓인다. 스킬·아이템 카드가 같은 골격을 쓴다.
	# U2 v3: 카드 9-slice 여백이 16이라 예전 16/14 자리는 프레임 위였다. 22/20으로 들여
	# 놓는다 — 블록·배지·설명의 상대 배치와 크기는 그대로다.
	#
	# 본문은 **어두운 칩 판** 위에 올린다. 킷 카드 프레임(SKILL=WOOD 주황 · TROPHY=GOLD
	# 금빛)은 바탕이 밝아서, v1처럼 색 글자를 그 위에 바로 얹으면 태그 CYAN·보유 GREEN·
	# RELOAD ORANGE가 전부 2:1 아래로 떨어진다(트로피 캡처 실측). 프레임은 카드의
	# **정체**를 말하고, 본문은 어두운 판이 읽히게 받친다 — §6이 "테두리에 강조색을
	# 쓰지 않는다"고 정한 것의 반대쪽 짝이다.
	_kit_panel(button, Rect2(15.0, 15.0, card_size.x - 30.0, card_size.y - 30.0),
		UIKit.Tone.SLATE, UIKit.Role.CHIP)
	var block := _card_block_panel(card)
	block.position = Vector2(22.0, 20.0)
	button.add_child(block)
	var info_x := 22.0 + FACTORY_CARD_BLOCK_SIZE.x + 16.0
	var info_width := maxf(120.0, card_size.x - info_x - 24.0)
	var tag_top := 22.0
	var tag_height := 50.0
	# Y4(피드백 ⑫) — 장비 카드의 **부위 머리 배지.** 「어디에 끼는가」가 아이템 카드에서
	# 유저가 가장 먼저 답해야 하는 질문인데, 지금까지는 「고급 · 팔찌」처럼 등급과
	# 같은 줄에 12px로 붙어 있었다. 이제 부위 배지 그림 + 22px 이름이 정보 열의
	# 첫 줄을 통째로 차지한다(칩 폭은 카드 폭의 절반).
	if not badge_part.is_empty():
		var part_rect := Rect2(info_x, 18.0, minf(info_width, card_size.x * 0.5), 36.0)
		var part_plate := _kit_panel(button, part_rect, UIKit.Tone.SLATE, UIKit.Role.CHIP)
		part_plate.self_modulate = Color.WHITE.lerp(badge_color, 0.42)
		_equip_part_art(button, part_rect.position + Vector2(8.0, 4.0), badge_part, 28.0,
			true, Color(badge_color, 0.95))
		var part_label := _label(ItemLibrary.part_name(badge_part), UI_TITLE_SIZE - 4,
			badge_color.lightened(0.36))
		part_label.name = "EquipPartName"
		part_label.position = part_rect.position + Vector2(44.0, 0.0)
		part_label.size = Vector2(maxf(24.0, part_rect.size.x - 56.0), part_rect.size.y)
		part_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(part_label)
		tag_top = 56.0
		# ⚠️ YZ 수리 — 여기가 handoff-y4 §8.4가 「교체 확인 화면의 글자 겹침」이라 적은
		#    자리다. 구판은 `24`였고 그 밑에서 요약 줄이 y 80부터 쌓였다. 그런데 장비
		#    카드의 태그 줄은 「영웅」 + 「전체 레일 + 다음 스킬」 **두 줄로 감긴다**
		#    (`AUTOWRAP_WORD_SMART`). 12px 두 줄은 32px라 24px 자리를 8px 넘고,
		#    넘친 둘째 줄이 첫 요약 줄(주황 「전체 RELOAD −8%」) 위에 그대로 얹혔다.
		#    아이템 2택·교체 확인·상자 전리품 세 화면에서 같이 보였다.
		#    자리를 두 줄만큼 주고, 요약 줄은 **태그가 실제로 끝나는 곳**부터 쌓는다.
		tag_height = 40.0
	if not badge_text.is_empty():
		# 원소·형태 배지. 결속(같은 원소 3연속)·삼각(1·3·5 같은 형태)의 판단 근거라
		# 다른 태그 더미에 섞이면 안 된다. 배지 바탕은 킷 칩(계층 3)으로 갈았다.
		var badge_width := minf(info_width, 200.0)
		var badge_bg := _kit_panel(button, Rect2(info_x, 20.0, badge_width, 26.0),
			UIKit.Tone.SLATE, UIKit.Role.CHIP)
		badge_bg.self_modulate = Color.WHITE.lerp(badge_color, 0.34)
		var badge := _label(badge_text, UI_BODY_SIZE + 1, badge_color.lightened(0.28))
		badge.position = Vector2(info_x + 11.0, 20.0)
		badge.size = Vector2(badge_width - 22.0, 26.0)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_child(badge)
		tag_top = 50.0
		tag_height = 26.0
	var tags := _label(tag_text, UI_LABEL_SIZE, GamePalette.CYAN)
	tags.position = Vector2(info_x, tag_top)
	tags.size = Vector2(info_width, tag_height)
	tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(tags)
	# 부가 정보는 블록 오른쪽 열에 왼쪽 정렬로 쌓아 블록과 같은 시선 흐름을 만든다.
	# YZ: 시작 y를 80으로 박지 않고 **태그 줄이 끝나는 곳**을 따라간다. 세 경로의
	# 태그 높이가 서로 다른데(기본 22+50 / 배지 50+26 / 부위 배지 56+40) 상수 80은
	# 앞의 둘에만 맞았다. 아래 설명 문단은 y 174부터라 마지막 요약 줄(96+2×24=144,
	# 끝 166)과 8px 여유가 있다.
	var lines_top := maxf(80.0, tag_top + tag_height)
	for line_index in lines.size():
		var line: Dictionary = lines[line_index]
		var line_label := _label(String(line.get("text", "")), UI_LABEL_SIZE, line.get("color", GamePalette.MUTED))
		line_label.position = Vector2(info_x, lines_top + float(line_index) * 24.0)
		line_label.size = Vector2(info_width, 22.0)
		button.add_child(line_label)
	var description_top := 20.0 + FACTORY_CARD_BLOCK_SIZE.y + 12.0
	var description := _label(description_text, UI_BODY_SIZE + 1, GamePalette.TEXT)
	description.position = Vector2(24.0, description_top)
	description.size = Vector2(card_size.x - 48.0, maxf(28.0, card_size.y - description_top - 20.0))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(description)

# 전역 스크롤바 테마 (P2-9)
# 공장 레일·보관함·결과 레일·상점이 전부 Godot 기본 스크롤바를 쓰고 있어 픽셀 레트로
# 톤에서 혼자 튀었습니다. ui_root에 한 번만 걸어 모든 ScrollContainer에 적용합니다.
## U2 v3: 전역 스크롤바를 v1 남색 막대에서 **킷 게이지**(ui-kit-bars.png)로 갈았다.
## 보관함·상점·합성소가 전부 이 테마를 타므로 한 곳만 고치면 모든 스크롤바가 따라온다.
## 두께는 여백 8로 16px에 맞췄다 — 게이지 9-slice 하한이 16이라 그보다 얇으면
## 둥근 끝이 뭉개진다(ui-style-v3 §4).
func _kit_scrollbar_style(kind: UIKit.Bar, tint: Color) -> StyleBoxTexture:
	var style := UIKit.variant(UIKit.bar_box(kind)) as StyleBoxTexture
	style.modulate_color = tint
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _build_ui_theme() -> Theme:
	var ui_theme := Theme.new()
	for bar_type: String in ["HScrollBar", "VScrollBar"]:
		ui_theme.set_stylebox("scroll", bar_type, _kit_scrollbar_style(UIKit.Bar.TRACK_DARK, Color.WHITE))
		ui_theme.set_stylebox("scroll_focus", bar_type, _kit_scrollbar_style(UIKit.Bar.TRACK_DARK, Color.WHITE))
		ui_theme.set_stylebox("grabber", bar_type, _kit_scrollbar_style(UIKit.Bar.FILL, UIKit.muted_color(UIKit.Tone.SLATE)))
		ui_theme.set_stylebox("grabber_highlight", bar_type, _kit_scrollbar_style(UIKit.Bar.FILL, UIKit.accent_color(UIKit.Tone.SLATE)))
		ui_theme.set_stylebox("grabber_pressed", bar_type, _kit_scrollbar_style(UIKit.Bar.FILL, Color.WHITE))
	return ui_theme

## ⚠️ **`_panel_style()`은 U3에서 삭제됐다.** U2가 모달·편집·결과·프리뷰를 킷으로
## 옮긴 뒤 남아 있던 마지막 12곳(필드 HUD)까지 U3가 갈아끼우면서 호출부가 0이 됐고,
## 그로써 `StyleBoxFlat.new()`가 **프로젝트 전체에서 0건**이 됐다(ui-style-v3 §12).
## 원본은 `docs/v1-archive/game_field_hud_style_u3.gd.txt`에 12개 호출부와 함께 있다.
## v1 토큰(`UI_MODAL_BG` `UI_PANEL_BG` `UI_CHIP_BG` `UI_EDGE` `UI_EDGE_SOFT` ·
## `UI_BORDER_*`)은 **지우지 않았다** — 12px 미만 게이지·핍의 `ColorRect` 색으로 아직 쓰인다.

# =============================================================================
# U3 — 스포트라이트 온보딩 길잡이 (2026-08-09)
# =============================================================================
# 사용자 요구 원문: "게임 시작했을 때, 어둡게 처리하면서 집중할 곳만 밝게 해서,
# 유저 간단한 조작감이나 필요한 거 온보딩 길잡이 만들어줘."
#
# ▸ **새 state를 만들지 않았다 — `playing` 서브모드다**(AGENTS.md §4가 허용한 두
#   선택지 중 후자). `state`는 `"playing"` 그대로이고 `guide_active` 한 값이 열고 닫는다.
#   이유는 하나다: 길잡이 ①②가 "실제로 걸어 보고 · 실제로 대시해 보고 넘어간다"라
#   **시간이 흘러야 하고 플레이어가 움직여야 한다.** 새 state를 만들면 클럭 틱 ·
#   population · 상호작용 · 대시 허용(`can_player_dash`) · 자동 저장까지 `state ==
#   "playing"` 가드 30여 곳이 한꺼번에 닫혀 길잡이 안에서 아무것도 못 한다.
#
# ▸ **X4(2026-08-09) — 안전 상태로는 모자랐다. 이제 세계를 멈춘다.**
#   사용자 원문: "게임 시작 후 튜토리얼 알려 줄 때 **게임이 시작되면 안 돼.**
#   시작되니까 내가 맞을까봐 집중을 못하겠어." U3의 처방(스폰 억제 + 무적)은
#   *맞지 않는다*는 사실만 보장했지 **위협감**을 지우지 못했다 —
#   `_begin_run()`이 `_maybe_start_guide()` **바로 앞줄**에서
#   `_spawn_stage_starter_population()`으로 잡몹 9기를 260~720px에 뿌리고,
#   그 9기가 길잡이 안내판을 읽는 내내 플레이어에게 걸어온다.
#
#   그래서 X4는 두 겹으로 막는다.
#     ⓐ **걷어낸다** — `_guide_clear_threats()`가 켜는 순간 필드 잡몹과 적 탄환을
#        전부 지운다(보스·캠프 소속은 남긴다). 런 시작이라 잃는 것은 0이고,
#        끝나면 스폰 타이머를 1.2초로 되돌려 세계가 다시 채워진다.
#     ⓑ **얼린다** — 남은 적과 그 뒤에 어떤 경로로든 생기는 적/탄은
#        `_guide_freeze_sweep()`이 `set_physics_process(false)`로 세운다.
#        접촉 피해·원거리 조준·이동이 전부 그 함수 안에 있으므로 한 줄로 멎는다.
#     그 위에 U3의 무적(`GUIDE_SAFE_INVULN`)과 스폰 억제를 **그대로 남겼다** —
#     세 겹 중 하나만 새도 "맞을 위험 0"이 깨진다.
#
#   시간축은 `_process`의 `world_running` 게이트가 멈춘다(클럭 · population ·
#   균열 판정 · 잠식 스윕 · 플레이어 도트 · `elapsed_time`). 클럭이 멈추므로
#   **길잡이를 오래 읽어도 dwell 불이익이 0이다.**
#
# ▸ **왜 `get_tree().paused`가 아닌가.** 두 가지 이유가 있고 둘 다 치명적이다.
#   ① U3의 이유 그대로 — 스텝 ①②는 플레이어가 실제로 걷고 대시해야 넘어간다.
#   ② Godot 4의 트리 일시정지는 **물리 서버까지 멈춘다**(2D physics stopped).
#      플레이어만 `PROCESS_MODE_ALWAYS`로 빼도 `move_and_slide()`가 설 자리가 없다.
#   그래서 "전면 정지"가 아니라 **선택 동결**이다. 딜싸이클만은 일부러 돌려 둔다 —
#   ③ "공격 버튼은 없습니다"를 눈으로 증명하는 유일한 수단이고, 필드에 적이
#   하나도 없으므로 카드가 나가도 아무 일이 일어나지 않는다.
#
# ▸ **저장은 쉰다**(`_run_save_blocked_reason() == "guide"`). "튜토리얼 절반"이라는
#   상태를 schema 3에 새로 넣는 값이 안 맞는다 — 잃는 것은 런 시작 40초뿐이고,
#   길잡이가 끝나는 순간 한 번 저장한다. 보스전 저장 정책(§9)과 같은 판단이다.
#
# ▸ **트윈 루프 0.** 켤 때 층 알파 1회성 페이드(0.18초), 스텝이 바뀔 때 안내판 알파
#   1회성 페이드(0.14초). 그 둘뿐이고 둘 다 반드시 끝난다(ui-style-v3 §11).
#
# ▸ **스텝 순서는 온보딩 1페이지가 사용자에게 한 약속이다**(handoff-u1 §3).
#   1페이지가 "첫 낮에 길잡이가 하나씩 짚어 준다"고 문자로 써 뒀고 부제가
#   "이동 · 대시 · 상호작용 · ESC 편집 화면"이다. 그 넷이 ① ② ⑥ ⑦로 그대로 들어 있고,
#   사이에 W5/V5가 만든 필드 HUD 3부품(레일 · 게이지 · 마왕 고스트 레일)이 들어간다.
#   **순서를 바꾸려면 `_onboarding_pages()` 1페이지 `rules`와
#   `_onboarding_diagram_controls`의 칩 두 줄을 같이 고쳐야 한다.**
# -----------------------------------------------------------------------------

## 안내판 규격. 위/아래 두 자리만 쓴다 — 구멍이 화면 아래쪽에 있으면 위, 위쪽이면 아래.
## 세로 예산: 위 자리 150~268(상단 HUD 아래끝 142 + 8) / 아래 자리 400~518(흐름 배너 532 위).
const GUIDE_CAPTION_SIZE := Vector2(760.0, 118.0)
const GUIDE_CAPTION_TOP := Vector2(260.0, 150.0)
const GUIDE_CAPTION_BOTTOM := Vector2(260.0, 400.0)
## 구멍이 이 y보다 아래에서 시작하면 안내판을 위로 올린다.
const GUIDE_CAPTION_FLIP_Y := 290.0
## 플레이어를 짚을 때의 구멍 크기(스포트라이트가 사방 32px 더 키운다 → 152×160).
const GUIDE_PLAYER_BOX := Vector2(88.0, 96.0)
const GUIDE_DIM := 0.72            # handoff-u2 §5.5 — 모달 스크림 0.62/0.82 사이
const GUIDE_FADE := 0.18
const GUIDE_STEP_FADE := 0.14
const GUIDE_MOVE_GOAL := 220.0     # ① 통과: 입력을 넣은 채 실제로 움직인 누적 거리(px)
const GUIDE_SAFE_SPAWN_HOLD := 4.0 # 안전 상태: 스폰 타이머를 이 값 밑으로 못 내려가게 민다
const GUIDE_SAFE_INVULN := 1.2
## X4: 동결 재적용 주기(초). 길잡이가 켜진 뒤에 어떤 경로로든 적·탄이 새로 생기면
## 이 스윕이 늦어도 이만큼 안에 붙잡는다. 0으로 두면 매 프레임 전수 조회가 된다.
const GUIDE_FREEZE_SWEEP := 0.25

## 스텝 표. `pass`가 통과 조건이고 `aim`이 구멍의 대상이다.
##   pass  move     입력을 넣은 채 GUIDE_MOVE_GOAL만큼 실제로 이동
##         dash     대시가 실제로 나감
##         interact E를 실제로 누름(누른 키는 그대로 흘려 보내 상호작용도 된다)
##         edit     ESC를 실제로 누름 → 편집 화면이 열리고 길잡이가 끝난다
##         space    보여 주기만 하는 스텝. SPACE로 넘어간다
const GUIDE_STEPS: Array = [
	{
		"id": "move", "aim": "player", "pass": "move", "keys": ["w", "a", "s", "d"],
		"title": "먼저 움직여 봅니다",
		"body": "WASD 또는 방향키로 이동합니다. 바라보는 방향은 가장 짧은 쪽으로 저절로 돌아갑니다."
	},
	{
		"id": "dash", "aim": "player", "pass": "dash", "keys": ["shift"],
		"title": "위험하면 대시로 빠집니다",
		"body": "SHIFT로 짧게 파고듭니다. 대시하는 동안은 맞지 않습니다. 기본 쿨타임 10초."
	},
	{
		"id": "rail", "aim": "rail_slots", "pass": "space", "keys": ["space"],
		"title": "공격 버튼은 없습니다",
		"body": "바늘이 멈춘 칸의 카드가 저절로 나갑니다. 다섯 칸은 모험 시작부터 전부 열려 있습니다."
	},
	{
		"id": "gauge", "aim": "rail_gauges", "pass": "space", "keys": ["space"],
		"title": "밟은 횟수와 빚을 봅니다",
		"body": "칸 오른쪽 점이 그 칸을 밟은 횟수(최대 2), 아래 가로 막대가 빚, 오른쪽 원이 RELOAD입니다. 자세한 숫자는 마우스를 올리면 나옵니다."
	},
	{
		"id": "ghost", "aim": "ghost", "pass": "space", "keys": ["space"],
		"title": "버린 카드가 저기 쌓입니다",
		"body": "고르지 않은 카드는 전부 마왕에게 갑니다. 오른쪽 위가 마왕의 다섯 칸입니다."
	},
	{
		"id": "nav", "aim": "nav", "pass": "interact", "keys": ["e"],
		# Y6(§6.1): 화살표는 **발견한 곳에만** 뜬다. 성은 처음부터 발견 상태라
		# 이 스텝에서 화살표가 반드시 하나는 있다(리스크 6의 처방 그대로다).
		"title": "가 본 곳만 화살표가 켜집니다",
		"body": "성 화살표는 처음부터 켜져 있습니다. 그쪽으로 걸어가면 보스문·균열도 하나씩 켜집니다. 앞에 서서 E를 누르면 들어갑니다."
	},
	{
		"id": "edit", "aim": "rail_band", "pass": "edit", "keys": ["esc"],
		"title": "ESC로 다섯 칸을 편집합니다",
		"body": "카드 순서를 바꾸고 각인을 봅니다. 언제든 열립니다 — 지금 눌러 보면 길잡이가 끝납니다."
	}
]

## 길잡이 층. **자기 프레임을 스스로 돈다.**
## `PROCESS_MODE_ALWAYS`라 모달이 떠서 트리가 멈춰도 살아 있고, 그때는 스스로 숨는다
## (모달은 `overlay`로 `ui_root` 직속이라 이 층보다 뒤에 붙어 위로 올라온다 — 그래도
## 스크림이 두 겹으로 겹치면 안 읽히므로 길잡이 쪽이 비켜 준다).
## 이렇게 짠 덕에 `game.gd` `_process`의 웨이브 소유 구역을 **한 줄도 건드리지 않는다**.
class GuideLayer:
	extends Control

	var game: GameMain = null

	func _process(_delta: float) -> void:
		if is_instance_valid(game):
			game._tick_guide(_delta)

# -----------------------------------------------------------------------------
# 발동 · 종료
# -----------------------------------------------------------------------------
## 길잡이를 열어야 하는가. **정책만** 본다(하네스 조건은 `_maybe_start_guide`가 본다).
## 새 런이고, 아직 길잡이를 본 적이 없고, 지금 돌고 있지 않을 때만 참이다.
func guide_should_trigger(resuming: bool) -> bool:
	return not resuming and not guide_seen and not guide_active

## `_begin_run()` 꼬리에서 부른다. 자동 테스트·프리뷰·캡처는 스스로 열지 않는다
## (`--guide-test` / `--capture-guide`는 `_start_guide()`를 직접 부른다).
func _maybe_start_guide(resuming: bool) -> void:
	if automated_test or not OS.get_cmdline_user_args().is_empty():
		return
	if not guide_should_trigger(resuming):
		return
	_start_guide()

func _start_guide() -> void:
	if guide_active or not is_instance_valid(hud):
		return
	guide_active = true
	guide_step = 0
	guide_confirm = false
	guide_completed_steps.clear()
	# 배너는 `ui_root` 직속이라 **스크림 위로 올라온다**(층 순서가 그렇게 짜여 있다).
	# 런 시작 배너와 길잡이는 정확히 같은 프레임에 뜨므로, 그대로 두면 어두워진 화면
	# 한가운데 밝은 띠가 홀로 떠 있어 스포트라이트가 깨져 보인다. 길잡이가 주인공인
	# 동안에는 배너를 걷는다 — 스테이지 이름은 상단 스테이지 패널이 계속 말하고 있다.
	if is_instance_valid(active_banner):
		active_banner.queue_free()
	active_banner = null
	# X4: 세계를 세운다. **안내판을 그리기 전에** 해야 첫 프레임부터 필드가 조용하다.
	_guide_clear_threats()
	guide_freeze_timer = 0.0
	_guide_freeze_sweep()
	_build_guide_layer()
	_apply_guide_step()
	# 1회성 페이드 하나. 루프가 아니다(ui-style-v3 §11 "허용 ①").
	guide_root.modulate.a = 0.0
	var tween := guide_root.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(guide_root, "modulate:a", 1.0, GUIDE_FADE)

## 정상 종료(마지막 스텝 통과) · ESC 전체 스킵 공통 출구.
## 어느 쪽이든 **본 것으로 친다** — 건너뛴 사람에게 다음 런에서 또 띄우면 그건 벌이다.
## 되살리는 창구는 설정의 「온보딩 다시 표시」 하나다.
func _finish_guide(aborted: bool) -> void:
	if not guide_active:
		return
	guide_active = false
	guide_confirm = false
	# X4: 얼렸던 것을 먼저 녹인다. `_clear_guide_layer()`보다 앞이어야 중간에
	# 예외가 나도 세계가 얼어붙은 채로 남지 않는다.
	_guide_unfreeze_all()
	_clear_guide_layer()
	guide_seen = true
	_save_progress()
	if is_instance_valid(player):
		player.grant_invulnerability(GameTuning.MODAL_RETURN_INVULN)
	if combat != null:
		# 안전 상태를 즉시 걷는다 — 다음 스폰까지 한 박자만 남긴다.
		# X4: 길잡이가 필드를 비웠으므로 이 한 박자 뒤부터 세계가 다시 채워진다
		# (`maintain_field_population()`이 상한까지 한 기씩 올린다 — 튜토리얼 직후에
		#  9기가 한꺼번에 서 있는 것보다 이 완만한 복귀가 낫다).
		combat.spawn_timer = minf(combat.spawn_timer, 1.2)
	_show_banner(
		"길잡이를 건너뛰었습니다 · 설정의 「온보딩 다시 표시」로 되살립니다" if aborted
		else "길잡이 끝 · ESC로 언제든 다섯 칸을 편집합니다",
		GamePalette.CYAN, 2.4)
	if not automated_test and OS.get_cmdline_user_args().is_empty():
		_save_run_snapshot()

## 런이 아예 사라진 경우(로비 복귀 · 결과 화면). **본 것으로 치지 않는다** —
## 사용자가 길잡이를 거부한 게 아니라 런을 그만둔 것이다.
func _abandon_guide() -> void:
	if not guide_active:
		return
	guide_active = false
	guide_confirm = false
	_guide_unfreeze_all()
	_clear_guide_layer()

# -----------------------------------------------------------------------------
# X4 — 동결 (사용자 피드백 ② "길잡이 중에 게임이 시작되면 안 돼")
# -----------------------------------------------------------------------------
## 켜는 순간 필드에서 **위협을 걷어낸다.** 잡몹과 날아다니는 적 탄환이 대상이고,
## 보스·캠프 소속 마물은 런의 진행 상태라 지우지 않는다(대신 아래에서 얼린다).
##
## 길잡이는 `_begin_run()` 꼬리에서만 스스로 열리는데, 바로 앞줄이
## `_spawn_stage_starter_population()`(잡몹 9기 · 260~720px)이다. 즉 **여기서 지우는
## 것은 방금 뿌린 시작 인구**이고, 길잡이가 끝나면 같은 경로로 다시 채워진다.
func _guide_clear_threats() -> void:
	guide_cleared_threats = 0
	if combat != null:
		# 순회 중에 `queue_free()`가 `unregister_enemy()`를 태워 배열을 줄이므로
		# **사본을 돌린다**(원본을 돌면 인덱스가 밀려 절반만 지워진다).
		for entry: Node in combat.active_enemies.duplicate():
			var mob := entry as DebtEnemy
			if not is_instance_valid(mob):
				continue
			if mob.is_boss or not mob.camp_id.is_empty():
				continue
			mob.queue_free()
			guide_cleared_threats += 1
	if is_instance_valid(gameplay_root):
		for child in gameplay_root.get_children():
			if child is EnemyBullet:
				child.queue_free()
				guide_cleared_threats += 1

## 노드 하나를 세운다. **이미 꺼져 있으면 목록에 안 넣는다** — 그래야 스윕을 몇 번
## 돌려도 되돌릴 목록이 정확히 "길잡이가 끈 것"으로 남는다(멱등).
func _guide_freeze_node(node: Node) -> void:
	# `queue_free()`는 프레임 끝에야 걷히므로, 방금 `_guide_clear_threats()`가 지운
	# 잡몹이 아직 `active_enemies`에 남아 있다. 그것까지 세면 `guide_frozen_count()`가
	# **유령을 센다** — 죽을 예정인 노드는 얼릴 것도 되돌릴 것도 없다.
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if not node.is_physics_processing():
		return
	node.set_physics_process(false)
	guide_frozen_nodes.append(node)

## 적과 적 탄환의 물리 처리를 끈다. 적의 이동·조준·**접촉 피해**가 전부
## `enemy._physics_process` 안에 있으므로 이 한 줄로 세 가지가 동시에 멎는다.
func _guide_freeze_sweep() -> void:
	if combat != null:
		for enemy: Node in combat.active_enemies:
			_guide_freeze_node(enemy)
	if is_instance_valid(gameplay_root):
		for child in gameplay_root.get_children():
			if child is EnemyBullet:
				_guide_freeze_node(child)

func _guide_unfreeze_all() -> void:
	for node: Node in guide_frozen_nodes:
		if is_instance_valid(node):
			node.set_physics_process(true)
	guide_frozen_nodes.clear()
	guide_freeze_timer = 0.0

## `--guide-test`가 읽는 창구 — 지금 길잡이가 세워 둔 노드 수.
func guide_frozen_count() -> int:
	return guide_frozen_nodes.size()

# -----------------------------------------------------------------------------
# 층 조립
# -----------------------------------------------------------------------------
func _build_guide_layer() -> void:
	_clear_guide_layer()
	guide_root = GuideLayer.new()
	guide_root.name = "GuideLayer"
	guide_root.game = self
	guide_root.process_mode = Node.PROCESS_MODE_ALWAYS
	guide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# **`hud`의 마지막 자식**이다. HUD 패널 위에 그려지고, 모달(`overlay`)은 `ui_root`
	# 직속이라 이 층보다 위로 올라온다 — 레벨업이 떠도 스크림이 겹치지 않는다.
	hud.add_child(guide_root)
	guide_spotlight = UIKit.make_spotlight(guide_root)

	guide_caption = _kit_panel(guide_root, Rect2(GUIDE_CAPTION_TOP, GUIDE_CAPTION_SIZE),
		UIKit.Tone.SLATE, UIKit.Role.PANEL)
	guide_caption.name = "GuideCaption"
	# 스텝 번호 칩(계층 3). 9-slice 하한 24×24 위다.
	_kit_panel(guide_caption, Rect2(18.0, 10.0, 88.0, 24.0), UIKit.Tone.SLATE, UIKit.Role.CHIP)
	guide_count_label = _kit_label(guide_caption, Rect2(18.0, 10.0, 88.0, 24.0), "",
		UIKit.Tone.SLATE, UIKit.FONT_CAPTION, false, UIKit.Role.CHIP, HORIZONTAL_ALIGNMENT_CENTER)
	guide_title_label = _kit_label(guide_caption, Rect2(116.0, 9.0, 620.0, 26.0), "",
		UIKit.Tone.SLATE, UIKit.FONT_HEADING)
	guide_body_label = _kit_label(guide_caption, Rect2(20.0, 40.0, 716.0, 32.0), "",
		UIKit.Tone.SLATE, UIKit.FONT_BODY)
	guide_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# 키캡 줄. 스텝마다 통째로 갈아끼운다(72×40 실물 · 간격 6).
	guide_keycap_row = Control.new()
	guide_keycap_row.name = "GuideKeys"
	guide_keycap_row.position = Vector2(20.0, 76.0)
	guide_keycap_row.size = Vector2(400.0, UIKit.KEYCAP_H)
	guide_keycap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_caption.add_child(guide_keycap_row)
	# X4: 자리를 340까지 넓혔다(키캡 넉 장은 20~332를 쓴다). 늘어난 폭이 나르는 것은
	# **"지금은 안전하다"는 한마디**다 — 사용자가 집중을 못 한 이유가 "맞을까봐"였으므로,
	# 세계가 멈춘 사실을 **글자로도 한 번 말해 준다**(그림만으로는 "적이 안 보인다"와
	# "적이 멈춰 있다"를 구별할 수 없다).
	guide_hint_label = _kit_label(guide_caption, Rect2(340.0, 82.0, 396.0, 28.0), "",
		UIKit.Tone.SLATE, UIKit.FONT_CAPTION, true, UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_RIGHT)

func _clear_guide_layer() -> void:
	if is_instance_valid(guide_root):
		guide_root.queue_free()
	guide_root = null
	guide_spotlight = null
	guide_caption = null
	guide_count_label = null
	guide_title_label = null
	guide_body_label = null
	guide_keycap_row = null
	guide_hint_label = null

# -----------------------------------------------------------------------------
# 스텝 그리기 · 조준
# -----------------------------------------------------------------------------
func guide_step_data() -> Dictionary:
	if GUIDE_STEPS.is_empty():
		return {}
	var data: Dictionary = GUIDE_STEPS[clampi(guide_step, 0, GUIDE_STEPS.size() - 1)]
	return data

## 스텝에 **들어갈 때** 한 번. 진행도를 리셋하고 그림을 갈고 1회성 페이드를 건다.
func _apply_guide_step() -> void:
	if not guide_active or not is_instance_valid(guide_caption):
		return
	guide_move_distance = 0.0
	guide_last_player_position = player.global_position if is_instance_valid(player) else Vector2.ZERO
	var step := guide_step_data()
	if String(step.get("pass", "")) == "dash" and is_instance_valid(player):
		# 대시를 시켜 놓고 쿨타임 때문에 못 하게 두면 안 된다. 한 번은 돌려준다.
		player.dash_cooldown_left = 0.0
	_paint_guide_step()
	guide_caption.modulate.a = 0.0
	var tween := guide_caption.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(guide_caption, "modulate:a", 1.0, GUIDE_STEP_FADE)

## 안내판 내용만 다시 쓴다(진행도는 안 건드린다). 확인 칩에서 돌아올 때도 이걸 쓴다.
func _paint_guide_step() -> void:
	if not is_instance_valid(guide_caption):
		return
	var step := guide_step_data()
	guide_count_label.text = "%d / %d" % [guide_step + 1, GUIDE_STEPS.size()]
	guide_title_label.text = String(step.get("title", ""))
	guide_body_label.text = String(step.get("body", ""))
	guide_hint_label.text = "세계가 멈춰 있습니다  ·  SPACE 건너뛰기  ·  ESC 그만"
	for child in guide_keycap_row.get_children():
		child.queue_free()
	var keys: Array = step.get("keys", []) as Array
	for key_index in keys.size():
		_kit_keycap(guide_keycap_row,
			Vector2(float(key_index) * (UIKit.KEYCAP_W + 6.0), 0.0), String(keys[key_index]))
	_aim_guide(true)

## ESC 확인 칩. 같은 안내판을 문구만 바꿔 쓴다 — 새 모달을 띄우면 층이 하나 더 생긴다.
func _paint_guide_confirm() -> void:
	if not is_instance_valid(guide_caption):
		return
	guide_title_label.text = "길잡이를 그만 볼까요?"
	guide_body_label.text = "ESC를 한 번 더 누르면 길잡이가 끝납니다. 설정 화면의 「온보딩 다시 표시」로 언제든 되살릴 수 있습니다."
	guide_hint_label.text = "ESC 그만두기  ·  SPACE 계속하기"
	for child in guide_keycap_row.get_children():
		child.queue_free()
	_kit_keycap(guide_keycap_row, Vector2.ZERO, "esc")
	_kit_keycap(guide_keycap_row, Vector2(UIKit.KEYCAP_W + 6.0, 0.0), "space")

## 구멍의 대상. **좌표는 W5/V5가 확정한 HUD 상수에서만 가져온다** — `hud`는 화면
## 전체에 앵커된 Control이라 로컬 좌표가 곧 전역 좌표다(헤드리스에서도 같다).
func _guide_target_rect(aim: String) -> Rect2:
	match aim:
		"player":
			var at := Vector2(640.0, 360.0)
			if is_instance_valid(player) and is_inside_tree():
				at = get_viewport().get_canvas_transform() * player.global_position
			return Rect2(at - GUIDE_PLAYER_BOX * 0.5, GUIDE_PLAYER_BOX)
		"rail_slots":
			# 바늘 + 칸 5개. 가로 = 52×5 + 10×4 = 300(X3 미니 스트립 폭 증명 그대로).
			return Rect2(
				RAIL_BAND_RECT.position + Vector2(RAIL_SLOT_ORIGIN.x, RAIL_NEEDLE_Y),
				Vector2(RAIL_SLOT_SIZE.x * 5.0 + RAIL_SLOT_GAP * 4.0,
					RAIL_SLOT_SIZE.y + RAIL_SLOT_ORIGIN.y - RAIL_NEEDLE_Y))
		"rail_gauges":
			var slots := Rect2(RAIL_BAND_RECT.position + RAIL_SLOT_ORIGIN,
				Vector2(RAIL_SLOT_SIZE.x * 5.0 + RAIL_SLOT_GAP * 4.0, RAIL_SLOT_SIZE.y))
			var debt := Rect2(RAIL_BAND_RECT.position + RAIL_DEBT_TRACK.position, RAIL_DEBT_TRACK.size)
			var dial := Rect2(RAIL_BAND_RECT.position + RAIL_DIAL_RECT.position, RAIL_DIAL_RECT.size)
			return slots.merge(debt).merge(dial)
		"ghost":
			return HUD_GHOST_RECT
		"nav":
			# X3: 나침반 패널이 사라졌으므로 **지금 떠 있는 보스문 화살표**를 짚는다.
			# 화살표는 플레이어 위치에 따라 링 위를 돌므로 좌표가 고정이 아니다 —
			# 어떤 화살표도 안 보이는 순간(전부 화면 안)에는 고정 폴백 자리로 떨어진다.
			return _nav_guide_rect()
		"rail_band":
			return RAIL_BAND_RECT
	return Rect2(Vector2(440.0, 260.0), Vector2(400.0, 200.0))

## 길잡이가 짚을 화살표 하나의 사각형. 보스문 → 성 → 캠프 → 균열 순으로 처음 보이는
## 것을 고른다(그 순서가 곧 "지금 이 화면에서 가장 중요한 목적지"다).
## 테스트도 이 함수를 불러 같은 답을 얻으므로 헤드리스에서도 결정적이다.
func _nav_guide_rect() -> Rect2:
	for key: String in ["boss_gate", "castle", "camp", "rift"]:
		var marker: EdgeMarker = nav_markers.get(key, null)
		if marker != null and is_instance_valid(marker) and marker.visible:
			return Rect2(marker.position, marker.size).grow(6.0)
	return HUD_NAV_HINT_RECT

func _aim_guide(reposition_caption: bool) -> void:
	if not guide_active or not is_instance_valid(guide_spotlight):
		return
	var target := _guide_target_rect(String(guide_step_data().get("aim", "")))
	UIKit.aim_spotlight(guide_spotlight, target, GUIDE_DIM)
	if reposition_caption and is_instance_valid(guide_caption):
		# 구멍이 화면 아래쪽이면 안내판은 위로. 한 스텝 안에서는 안 움직인다
		# (플레이어를 따라 구멍이 흔들려도 글자가 같이 떨면 읽을 수 없다).
		guide_caption.position = GUIDE_CAPTION_TOP if target.position.y >= GUIDE_CAPTION_FLIP_Y \
			else GUIDE_CAPTION_BOTTOM

# -----------------------------------------------------------------------------
# 프레임 (GuideLayer._process가 부른다)
# -----------------------------------------------------------------------------
func _tick_guide(delta: float) -> void:
	if not guide_active or not is_instance_valid(guide_root):
		return
	# 런이 통째로 사라졌으면 층도 접는다(로비 복귀 · 결과 화면).
	if state in ["menu", "character_select", "settings", "onboarding", "won", "lost"]:
		_abandon_guide()
		return
	# 모달·성 내부·보스전에서는 스스로 숨는다. 그림은 언제나 하나만 남는다.
	var live := state == "playing" and not inside_castle and is_instance_valid(player)
	guide_root.visible = live
	if not live:
		return
	# ---- 안전 상태 (U3) + 동결 재적용 (X4) -----------------------------------
	# 세 겹이다: ① 스폰 억제 ② 무적 ③ 동결. `_process`의 `world_running` 게이트가
	# 클럭·population을 이미 멈춰 두므로 ①은 이중 잠금이지만, 하네스가
	# `_tick_guide()`만 직접 부르는 경로(`--guide-test`)에서는 ①이 유일한 방어다.
	if combat != null:
		combat.spawn_timer = maxf(combat.spawn_timer, GUIDE_SAFE_SPAWN_HOLD)
	player.invulnerability = maxf(player.invulnerability, GUIDE_SAFE_INVULN)
	guide_freeze_timer -= delta
	if guide_freeze_timer <= 0.0:
		guide_freeze_timer = GUIDE_FREEZE_SWEEP
		_guide_freeze_sweep()
	# ---- 통과 판정 -----------------------------------------------------------
	var pass_kind := String(guide_step_data().get("pass", "space"))
	var travelled := player.global_position.distance_to(guide_last_player_position)
	guide_last_player_position = player.global_position
	if pass_kind == "move":
		if Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.01:
			guide_move_distance += travelled
		if guide_move_distance >= GUIDE_MOVE_GOAL:
			_advance_guide(false)
			return
	elif pass_kind == "dash":
		if player.dash_time_left > 0.0 or player.dash_cooldown_left > 0.0:
			_advance_guide(false)
			return
	_aim_guide(false)
	# delta는 안 쓰지만 시그니처를 맞춰 둔다(감쇠를 붙일 자리 · 트윈 루프 대체 규약).
	if delta < 0.0:
		return

## 다음 스텝으로. `skipped`면 통과 기록에 안 남는다(길잡이가 뭘 가르쳤는지의 진실 원천).
func _advance_guide(skipped: bool) -> void:
	if not guide_active:
		return
	if not skipped:
		guide_completed_steps.append(String(guide_step_data().get("id", "")))
	guide_confirm = false
	guide_step += 1
	if guide_step >= GUIDE_STEPS.size():
		guide_step = GUIDE_STEPS.size() - 1
		_finish_guide(false)
		return
	_apply_guide_step()

# -----------------------------------------------------------------------------
# 키 (`_unhandled_input`의 U3 구역이 부른다)
# -----------------------------------------------------------------------------
## `true`를 돌려주면 키를 먹는다. `false`면 아래 기존 처리로 흘려 보낸다 —
## 마지막 스텝의 ESC(= 편집 화면 열기)와 상호작용 스텝의 E가 그 경우다.
func _handle_guide_key(key_event: InputEventKey) -> bool:
	var pass_kind := String(guide_step_data().get("pass", "space"))
	if key_event.keycode == KEY_ESCAPE:
		# 마지막 스텝은 ESC가 곧 과제다. 확인 칩을 띄우지 않고 길잡이를 끝낸 뒤
		# 키를 흘려 보내 편집 화면이 열리게 한다("열면 완료" 규약).
		if pass_kind == "edit":
			_advance_guide(false)
			return false
		if not guide_confirm:
			guide_confirm = true
			_paint_guide_confirm()
			return true
		_finish_guide(true)
		return true
	if key_event.keycode in [KEY_SPACE, KEY_ENTER]:
		if guide_confirm:
			guide_confirm = false
			_paint_guide_step()
			return true
		# 보여 주기만 하는 스텝에서는 SPACE가 "다음"이라 통과로 친다.
		# 해 보라고 시킨 스텝에서는 같은 키가 "건너뛰기"라 통과로 치지 않는다.
		_advance_guide(pass_kind != "space")
		return true
	if pass_kind == "interact" and (key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E):
		_advance_guide(false)
		return false
	return false


# =============================================================================
# Y6 — 발견 · 필드 사건 · 소비 아이템 (FEEDBACK_Y §6 전체 · 피드백 ⑱ ㉓)
# =============================================================================
# 사용자 원문 요지 셋:
#   ⓐ "처음엔 내비 화살표가 없다가, 오브젝트를 **한 번 발견하면** 표시되게."
#   ⓑ "스테이지마다 던전 · 보물섬 · 세미 엘리트 같은 **랜덤 이벤트**를."
#   ⓒ "맵 전체를 밝혀 내비를 켜는 아이템, 낮을 늘리는 아이템 같은 **재미 아이템**을."
#
# ▸ **안개를 만들지 않는다**(§6.1). X3가 만든 "필드 가시 96.7%"를 되돌리지 않기 위해
#   발견은 **화살표의 유무로만** 말한다. 오브젝트 자체는 시야에 들어오면 늘 보인다.
# ▸ **새 `state`를 만들지 않는다**(§6.2). 사건은 전부 `playing` 안의 필드 사건이다 —
#   균열(W9)·보스방(V7)이 이미 밟은 선례를 그대로 따른다. 사건이 여는 화면은
#   전부 **기존 모달**이다(각인 3택1 · 장비 2택1 · 카드상 · 상자 보상).
# ▸ **배치는 균열과 같은 규약**이다 — 스테이지 시드로 결정적이고, 예산은
#   스테이지당 EVENT_STAGE_MAX · 런 전체 EVENT_RUN_MAX로 이중 상한이다.
#   균열 예산(스테이지 2)과는 **자리만** 겹치지 않게 뗀다(서로 다른 예산이다).
# ▸ 소비 아이템은 **1칸 + `Q`**다(§6.3). 장비 4부위 경쟁에 넣으면 "재미"가 아니라
#   "빌드 결정"이 되고 피드백 ⑫가 요구한 부위 비교 플로우가 더 복잡해진다.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# 보물상자 배당표 (§6.4 · 피드백 ㉓) — **정본은 이 표 하나다**
# -----------------------------------------------------------------------------
## 순서가 곧 굴림 구간이고 합은 반드시 100이다(`--event-test`의 `chest` 묶음이 문다).
## 신설 두 칸: `heal` 7(체력 40% 회복) · `fun` 6(재미 아이템 1개).
## 위협 총량 `curse + trap + mimic` = **18**(구 21에서 내렸다 — §6.4의 논지).
const CHEST_TABLE: Array = [
	["gold", 13], ["xp", 12], ["skill", 14], ["item", 13], ["rune", 14],
	["heal", 7], ["fun", 6], ["curse", 6], ["trap", 7], ["mimic", 5], ["empty", 3]
]
const CHEST_THREAT_SLICES: Array[String] = ["curse", "trap", "mimic"]

func chest_table_total() -> int:
	var total := 0
	for row: Array in CHEST_TABLE:
		total += int(row[1])
	return total

func chest_slice_weight(slice_name: String) -> int:
	for row: Array in CHEST_TABLE:
		if String(row[0]) == slice_name:
			return int(row[1])
	return 0

## 0~99 굴림 하나 → 배당 이름. `_open_chest()`의 유일한 분기 근거다.
func chest_slice_for(roll: int) -> String:
	var cursor := 0
	for row: Array in CHEST_TABLE:
		cursor += int(row[1])
		if roll < cursor:
			return String(row[0])
	return "empty"

## 발견 반경(§6.1). 이 거리 안에 들어오거나 **화면 안(NAV_RING 안쪽)**에 들어오면 발견.
const DISCOVER_RADIUS := 520.0
## 스테이지 스코프 발견 상태. 키는 내비 대상 키(`castle`/`camp`/`boss_gate`) ·
## 균열 id · 사건 id다. 저장은 `discovered_features` 배열(→ schema 4).
var discovered_features: Dictionary = {}

## 사건 예산. 스테이지당 2~3개(시드가 정한다) · 런 전체 12개(§6.2).
const EVENT_STAGE_MIN := 2
const EVENT_STAGE_MAX := 3
const EVENT_RUN_MAX := 12
## 사건이 열리는 체류 값 — `dwell 0`에 1개 · `dwell 2` · `dwell 4`에 각 1개(§6.2).
const EVENT_REVEAL_DWELL: Array[int] = [0, 2, 4]
## 배치 링. 균열(900~1400)보다 조금 안쪽에서 시작해 "걸어가면 만난다"를 만든다.
const EVENT_RING_MIN := 720.0
const EVENT_RING_MAX := 1320.0
## 다른 사건·균열·랜드마크와 떼는 최소 거리.
const EVENT_CLEARANCE := 260.0
const EVENT_SITE_ATTEMPTS := 48
## 상호작용 반경(성·상자와 같은 105px)과 접근 알림 반경.
const EVENT_INTERACT_RADIUS := 112.0
## 사건 소속 적의 `camp_id` 접두어. `_trial_enemy_defeated()`가 이걸 보고 분배한다.
const EVENT_CAMP_PREFIX := "evt_"
## 보상 스케일 — 상점가와 같은 사다리를 탄다(§6.2 "골드·XP가 상점가 스케일을 탄다").
## `stage_price_scale()` = 1 + 0.35 × (스테이지 − 1).

## 사건 8종(§6.2 표). `night`/`blight`는 **조건**이지 최소 스테이지가 아니다 —
## 조건이 안 맞으면 표식이 아예 안 뜬다(그래서 "밤에만 나오는 사건"으로 읽힌다).
const EVENT_LIBRARY: Array = [
	{"id":"dungeon", "name":"작은 던전", "min_stage":1, "color":GamePalette.ORANGE,
		"prompt":"[ E ]  작은 던전 · 정예를 전부 쓸면 나올 수 있습니다"},
	{"id":"isle", "name":"보물섬", "min_stage":2, "color":GamePalette.YELLOW, "wet":true,
		"prompt":"[ E ]  보물섬 · 상자 셋 · 함정 없음"},
	{"id":"semi_elite", "name":"이름 있는 마물", "min_stage":2, "color":GamePalette.RED,
		"prompt":"[ E ]  이름 있는 마물 · 장비를 들고 있습니다"},
	{"id":"merchant", "name":"유랑 상인", "min_stage":1, "color":GamePalette.GREEN,
		"prompt":"[ E ]  유랑 상인 · 성보다 조금 비쌉니다 · 한 번뿐"},
	{"id":"shrine", "name":"무너진 사당", "min_stage":3, "color":GamePalette.MAGENTA,
		"prompt":"[ E ]  무너진 사당 · 지금 체력의 절반을 바치고 각인을 받습니다"},
	{"id":"footprint", "name":"마왕의 발자국", "min_stage":1, "blight":true, "color":GamePalette.PURPLE,
		"prompt":"[ E ]  마왕의 발자국 · 전조 둘이 동시에 옵니다"},
	{"id":"pack", "name":"굶주린 무리", "min_stage":1, "night":true, "color":GamePalette.CYAN,
		"prompt":"[ E ]  굶주린 무리 · 같은 마물 여덟이 몰려옵니다"},
	{"id":"meteor", "name":"별똥별", "min_stage":1, "night":true, "color":GamePalette.YELLOW,
		"prompt":"[ E ]  별똥별이 떨어진 자리 · 상자 하나"}
]

## 이번 스테이지의 사건. 항목: id · type · position · reveal_dwell · state ·
## remaining · wave · waves. `state`는 `hidden` → `ready` → `active` → `done`.
var stage_events: Array[Dictionary] = []
## 사건 id → 필드 표식 노드. **사건 사전 안에 Node를 넣지 않는다** —
## `gameplay_root.free()` 뒤에 그 값을 타입 있는 변수로 받으면 Godot이
## "invalid previously freed instance"로 죽는다(실측). 저장도 이 표를 안 본다.
var event_marks: Dictionary = {}
## 런 전체에서 지금까지 배치된 사건 수(EVENT_RUN_MAX 상한의 소유자).
var run_event_count := 0
## 지금 열려 있는 유랑 상인의 사건 id(빈 문자열이면 안 열려 있다).
var field_merchant_event := ""
const FIELD_MERCHANT_CASTLE_PREFIX := "field_merchant"
## 유랑 상인의 웃돈 — "성보다 20% 비싸다"(§6.2).
const FIELD_MERCHANT_PREMIUM := 1.20

## 소비 슬롯 1칸(§6.3). 값은 `CONSUMABLES`의 키이고 빈 문자열이면 비어 있다.
var consumable_item := ""
## 「밤눈 부적」이 남은 밤 수. 1이면 다음 밤 동안 감지 반경이 줄어든다.
var night_eye_nights := 0
var night_eye_active := false
## 「미끼 인형」 — 남은 시간과 인형 노드, 그리고 인형을 보고 있는 적들.
var decoy_timer := 0.0
var decoy_node: Node2D = null
var decoy_enemies: Array = []
## 소비 아이템 교체 확인이 열려 있으면 들어온 아이템 id가 여기 담긴다(§6.3 · Y4 컴포넌트).
var consumable_swap := ""

## 재미 아이템 8종(§6.3 표). 글리프는 킷 16종 안에서만 고른다 —
## 새 시트를 구우면 `UIKit.GLYPH_INDEX` 계약을 건드린다(YA 금지 사항).
const CONSUMABLES := {
	"map": {"name":"낡은 지도", "glyph":"scroll", "color":GamePalette.CYAN,
		"line":"이 스테이지 지도를 전부 켠다"},
	"sundial": {"name":"해시계", "glyph":"hourglass", "color":GamePalette.YELLOW,
		"line":"지금 낮을 40초 늘린다"},
	"nighteye": {"name":"밤눈 부적", "glyph":"gem", "color":GamePalette.BLUE,
		"line":"다음 밤 동안 마물이 늦게 알아챈다"},
	"horn": {"name":"소환 뿔피리", "glyph":"star", "color":GamePalette.ORANGE,
		"line":"근처 마물을 한 곳으로 모은다"},
	"bread": {"name":"회복의 빵", "glyph":"heart", "color":GamePalette.GREEN,
		"line":"체력 40% 회복"},
	"bell": {"name":"되돌이 종", "glyph":"key", "color":GamePalette.MAGENTA,
		"line":"성 앞으로 즉시 돌아간다"},
	"eraser": {"name":"각인 지우개", "glyph":"cross", "color":GamePalette.MUTED,
		"line":"칸 하나의 각인을 떼고 골드로 판다"},
	"decoy": {"name":"미끼 인형", "glyph":"bag", "color":GamePalette.PURPLE,
		"line":"8초 동안 마물이 인형을 때린다"}
}
## 상자·이벤트가 굴리는 재미 아이템 풀. 「각인 지우개」는 세공사 전용이라 빠진다(§6.3 획득처).
const CONSUMABLE_DROP_POOL: Array[String] = ["map", "sundial", "nighteye", "horn", "bread", "bell", "decoy"]

const SUNDIAL_SECONDS := 40.0
const BREAD_HEAL_RATIO := 0.40
const HORN_GATHER_RADIUS := 640.0
const HORN_GATHER_LEAD := 150.0
const DECOY_SECONDS := 8.0
const DECOY_RADIUS := 520.0
## 밤눈 부적의 감지 반경. 기준 700px에 −40%를 먹인 값이다(§6.3).
## Y7: 기준값은 이제 `enemy.gd`가 소유한다 — 감지 반경은 몹의 성질이지 아이템의
## 성질이 아니다(handoff-y6 §5-4가 넘긴 승격). 여기서는 그 상수를 **읽기만** 한다.
const NIGHT_EYE_BASE_RANGE := DebtEnemy.NIGHT_SIGHT_BASE
const NIGHT_EYE_SCALE := 0.60
## 각인 지우개가 각인 하나를 되사는 값(스테이지 물가를 탄다).
const RUNE_ERASER_REFUND := 22

## 필드 HUD의 소비 슬롯. **판을 깔지 않는다** — 킷 키캡 + 글리프 + 짧은 이름뿐이라
## `hud_block_pct` 3.35% 계약(§8 ⑤)이 그대로 유지된다(측정은 Panel/ColorRect만 센다).
## 자리는 좌하단 — 미니 스트립(x 450~830)과 신상(y 8~64) 어디와도 안 겹친다.
const HUD_CONSUMABLE_RECT := Rect2(16.0, 646.0, 210.0, 46.0)
## 키캡 원본은 72×40이다(`UIKit.KEYCAP_W/H`). 정확히 **절반**으로만 줄인다 —
## 비정수 배율로 줄이면 픽셀 격자가 어긋나 글자 Q가 뭉개진다(킷 규약).
const HUD_CONSUMABLE_KEY := Rect2(0.0, 13.0, 36.0, 20.0)
const HUD_CONSUMABLE_GLYPH := Vector2(44.0, 8.0)
const HUD_CONSUMABLE_TEXT := Rect2(94.0, 10.0, 116.0, 24.0)

var consumable_panel: Control
var consumable_glyph: TextureRect
var consumable_label: Label
var consumable_key_icon: TextureRect

# -----------------------------------------------------------------------------
# 발견 (§6.1)
# -----------------------------------------------------------------------------
func is_discovered(key: String) -> bool:
	return bool(discovered_features.get(key, false))

## 발견 처리. 처음 발견한 순간에만 true를 돌려주고 짧은 월드 글자 하나를 띄운다.
func mark_discovered(key: String, label: String = "") -> bool:
	if key.is_empty() or discovered_features.has(key):
		return false
	discovered_features[key] = true
	if not label.is_empty() and state == "playing" and not guide_active and is_instance_valid(player):
		show_world_text(player.global_position - Vector2(0.0, 96.0), "%s 발견" % label, GamePalette.CYAN, 18)
		play_sound("collect", -7.0)
	return true

## 스테이지 개시 · 런 개시의 발견 초기화. **성·캠프는 처음부터 발견 상태**다 —
## 정비 창구를 못 찾으면 게임이 막힌다(§6.1 · 리스크 6).
func _seed_stage_discovery() -> void:
	discovered_features.clear()
	discovered_features["castle"] = true
	discovered_features["camp"] = true

## 지금 발견 판정을 받아야 하는 대상 전부. 내비 4종 + 사건이 같은 표를 쓴다.
func _discovery_candidates() -> Array:
	var out: Array = []
	if not is_instance_valid(world):
		return out
	var landmarks: Dictionary = world.get_stage_landmarks()
	if landmarks.has("boss_gate"):
		out.append({"key":"boss_gate", "name":"보스문", "position":world.get_boss_gate_position()})
	if landmarks.has("castle"):
		out.append({"key":"castle", "name":"성", "position":world.get_castle_position()})
	if landmarks.has("camp"):
		out.append({"key":"camp", "name":"캠프", "position":world.get_camp_position()})
	for rift: Dictionary in world.get_rifts():
		out.append({"key":String(rift.get("id", "")), "name":"균열", "position":rift.get("position", Vector2.ZERO)})
	for event_value: Dictionary in stage_events:
		if String(event_value.get("state", "hidden")) in ["hidden", "done"]:
			continue
		out.append({"key":String(event_value.get("id", "")), "name":_event_name(event_value),
			"position":event_value.get("position", Vector2.ZERO)})
	return out

## 발견 스윕. 상호작용 갱신과 같은 박자(0.12초)로 돈다 — 프레임마다 돌릴 이유가 없다.
func _update_discovery() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world) or not is_inside_tree():
		return
	var canvas := get_viewport().get_canvas_transform()
	for candidate: Dictionary in _discovery_candidates():
		var key := String(candidate.get("key", ""))
		if key.is_empty() or discovered_features.has(key):
			continue
		var at: Vector2 = candidate.get("position", Vector2.ZERO)
		if player.global_position.distance_to(at) <= DISCOVER_RADIUS:
			mark_discovered(key, String(candidate.get("name", "")))
			continue
		# "화면 안에 들어옴" = 화살표가 놓이는 링(NAV_RING) 안쪽이다. 두 판정이 같은
		# 사각형을 봐야 "보이는데 발견이 안 된" 자리가 안 생긴다.
		var screen_at: Vector2 = canvas * at
		if NAV_RING.has_point(screen_at):
			mark_discovered(key, String(candidate.get("name", "")))

## 가장 가까운 **발견한** 균열의 나침반 한 줄. `world.get_rift_compass()`와 같은 모양이다.
func _discovered_rift_compass(point: Vector2) -> Dictionary:
	if not is_instance_valid(world):
		return {}
	var best: Dictionary = {}
	var best_distance := INF
	for rift: Dictionary in world.get_rifts():
		if bool(rift.get("cleared", false)) or not is_discovered(String(rift.get("id", ""))):
			continue
		var at: Vector2 = rift.get("position", Vector2.ZERO)
		var distance := point.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = {"id":String(rift.get("id", "")), "position":at, "distance":distance,
				"direction":(at - point).normalized()}
	return best

## 가장 가까운 **발견한** 필드 사건의 나침반 한 줄.
func _event_compass(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for event_value: Dictionary in stage_events:
		if String(event_value.get("state", "hidden")) in ["hidden", "done"]:
			continue
		if not _event_condition_ok(event_value):
			continue
		var event_id := String(event_value.get("id", ""))
		if not is_discovered(event_id):
			continue
		var at: Vector2 = event_value.get("position", Vector2.ZERO)
		var distance := point.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = {"id":event_id, "position":at, "distance":distance,
				"direction":(at - point).normalized()}
	return best

## 「낡은 지도」 — 이 스테이지의 모든 대상을 발견 처리한다. 몇 개가 새로 켜졌는지 돌려준다.
func _discover_all_stage_features() -> int:
	var revealed := 0
	for candidate: Dictionary in _discovery_candidates():
		if mark_discovered(String(candidate.get("key", "")), ""):
			revealed += 1
	return revealed

# -----------------------------------------------------------------------------
# 필드 사건 (§6.2)
# -----------------------------------------------------------------------------
func _event_entry(type_id: String) -> Dictionary:
	for entry: Dictionary in EVENT_LIBRARY:
		if String(entry.get("id", "")) == type_id:
			return entry
	return {}

func _event_name(event_value: Dictionary) -> String:
	return String(_event_entry(String(event_value.get("type", ""))).get("name", "사건"))

## 조건이 지금 맞는가. 밤 사건은 밤에만, 잠식 사건은 잠식 중에만 표식이 뜬다.
func _event_condition_ok(event_value: Dictionary) -> bool:
	var entry := _event_entry(String(event_value.get("type", "")))
	if entry.is_empty():
		return false
	if bool(entry.get("night", false)) and not is_night:
		return false
	if bool(entry.get("blight", false)) and not blight_active:
		return false
	return true

## 이 체류 값까지 열려 있어야 하는 사건 수. 균열의 `rifts_due()`와 같은 셈법이다 —
## "지금까지 몇 개가 열렸어야 하는가"를 세면 자리를 못 찾아 밀린 배치가 저절로 따라잡힌다.
func events_due(dwell_value: int = -1) -> int:
	var dwell_now := clock.dwell if dwell_value < 0 else dwell_value
	var due := 0
	for threshold: int in EVENT_REVEAL_DWELL:
		if dwell_now >= threshold:
			due += 1
	return mini(due, stage_event_budget())

## 이번 스테이지의 사건 정원(2~3). 스테이지 시드가 정하므로 재현 가능하다.
func stage_event_budget() -> int:
	var local := RandomNumberGenerator.new()
	local.seed = absi(stage_world_seed(clock.stage) ^ 0x5EED_2026)
	return local.randi_range(EVENT_STAGE_MIN, EVENT_STAGE_MAX)

## 스테이지 개시. 사건 목록을 비우고 표식 노드를 걷는다.
func _reset_stage_events() -> void:
	for key in event_marks.keys():
		if is_instance_valid(event_marks[key]):
			event_marks[key].queue_free()
	event_marks.clear()
	stage_events.clear()
	field_merchant_event = ""

## 개설이 밀렸으면 따라잡는다(균열과 같은 규약). 낮 시작·이정표·스테이지 개시에서 부른다.
func _maintain_event_schedule() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	var due := events_due()
	while stage_events.size() < due and run_event_count < EVENT_RUN_MAX:
		if not _spawn_scheduled_event(stage_events.size()):
			return
	_refresh_event_marks()

func _spawn_scheduled_event(index: int) -> bool:
	var type_id := _roll_event_type(index)
	if type_id.is_empty():
		return false
	var site := _find_event_site(index, type_id)
	if site == Vector2.INF:
		return false
	var event_value := {
		"id":"%s%d_%d" % [EVENT_CAMP_PREFIX, clock.stage, index],
		"type":type_id,
		"position":site,
		"reveal_dwell":int(EVENT_REVEAL_DWELL[mini(index, EVENT_REVEAL_DWELL.size() - 1)]),
		"state":"ready",
		"remaining":0, "wave":0, "waves":0
	}
	stage_events.append(event_value)
	run_event_count += 1
	return true

## 사건 종류는 **스테이지 시드 + 순번**만으로 정한다(균열 좌표와 같은 결정성 규약).
## 최소 스테이지를 못 넘는 종류는 후보에서 빠지고, 같은 스테이지에 같은 종류를 두 번 두지 않는다.
func _roll_event_type(index: int) -> String:
	var used: Array[String] = []
	for event_value: Dictionary in stage_events:
		used.append(String(event_value.get("type", "")))
	var pool: Array[String] = []
	for entry: Dictionary in EVENT_LIBRARY:
		var entry_id := String(entry.get("id", ""))
		if clock.stage < int(entry.get("min_stage", 1)) or used.has(entry_id):
			continue
		pool.append(entry_id)
	if pool.is_empty():
		return ""
	var local := RandomNumberGenerator.new()
	local.seed = absi(stage_world_seed(clock.stage) ^ (0x1EE7 + index * 7919))
	return pool[local.randi_range(0, pool.size() - 1)]

## 배치 규칙은 균열(`world_grid._find_rift_site`)의 것을 그대로 옮겨 왔다.
## 다른 점 하나 — **균열 자리와도 뗀다.** 두 예산은 서로 독립이라 자리가 겹칠 수 있다.
func _find_event_site(index: int, type_id: String) -> Vector2:
	var origin: Vector2 = field_return_position if inside_castle else player.global_position
	var wants_water := bool(_event_entry(type_id).get("wet", false))
	var local := RandomNumberGenerator.new()
	local.seed = absi(stage_world_seed(clock.stage) ^ (0xC0FFEE + index * 104729))
	var fallback := Vector2.INF
	for attempt in EVENT_SITE_ATTEMPTS:
		var angle := local.randf_range(0.0, TAU)
		var distance := local.randf_range(EVENT_RING_MIN, EVENT_RING_MAX)
		var candidate := origin + Vector2.from_angle(angle) * distance
		if not world.is_walkable(candidate):
			continue
		if not _event_site_clear(candidate):
			continue
		if fallback == Vector2.INF:
			fallback = candidate
		# 「보물섬」만 물가를 원한다 — 호수에 붙어야 "섬"으로 읽힌다(§6.2).
		# 지형을 새로 깎지 않는다: `world_grid`는 Y5 소유이고 Y6의 파일이 아니다.
		if wants_water and not _near_water(candidate):
			continue
		return candidate
	return fallback

## Y7: 새로 열린 균열 위에 앉아 있는 **아직 시작 안 한** 사건을 다른 자리로 민다.
## 자리를 고르는 규칙은 `_find_event_site()` 그대로다 — 인덱스에 소금을 쳐서 같은
## 시드에서도 다른 후보를 뽑는다. 세 번 시도해서 못 찾으면 그냥 둔다(자리가 정말
## 없는 스테이지에서 사건을 지우는 것보다 겹치는 편이 낫다).
## **진행 중(`active`)인 사건은 안 옮긴다** — 플레이어가 그 안에서 싸우는 중이다.
const EVENT_RESITE_SALT := 977

func _displace_events_from_rift(rift: Dictionary) -> void:
	if stage_events.is_empty():
		return
	var rift_at: Vector2 = rift.get("position", Vector2.ZERO)
	var clearance := float(rift.get("radius", 150.0)) + EVENT_CLEARANCE
	for index in stage_events.size():
		var event_value: Dictionary = stage_events[index]
		if String(event_value.get("state", "")) != "ready":
			continue
		var at: Vector2 = event_value.get("position", Vector2.ZERO)
		if at.distance_to(rift_at) >= clearance:
			continue
		for retry in 3:
			var moved := _find_event_site(index + EVENT_RESITE_SALT * (retry + 1),
				String(event_value.get("type", "")))
			if moved == Vector2.INF or moved.distance_to(rift_at) < clearance:
				continue
			event_value["position"] = moved
			var mark: Node2D = event_marks.get(String(event_value.get("id", "")))
			if is_instance_valid(mark):
				mark.global_position = moved
			break

## 후보가 랜드마크 3종 · 균열 · 다른 사건과 충분히 떨어져 있는가.
func _event_site_clear(candidate: Vector2) -> bool:
	var landmarks: Dictionary = world.get_stage_landmarks()
	for key: String in landmarks:
		var landmark: Dictionary = landmarks[key]
		var radius := float(landmark.get("radius", 190.0))
		if candidate.distance_to(landmark.get("position", Vector2.ZERO)) < radius + EVENT_CLEARANCE:
			return false
	for rift: Dictionary in world.get_rifts():
		if candidate.distance_to(rift.get("position", Vector2.ZERO)) < float(rift.get("radius", 150.0)) + EVENT_CLEARANCE:
			return false
	for event_value: Dictionary in stage_events:
		if candidate.distance_to(event_value.get("position", Vector2.ZERO)) < EVENT_CLEARANCE * 1.6:
			return false
	return true

## 반경 안에 물 타일이 하나라도 있는가(보물섬 전용). `tile_kind_at`은 Y5가 신설한 API다.
func _near_water(candidate: Vector2) -> bool:
	for step in 8:
		var probe := candidate + Vector2.from_angle(TAU * float(step) / 8.0) * 180.0
		if world.tile_kind_at(probe) == "water":
			return true
	return false

func _event_by_id(event_id: String) -> Dictionary:
	for event_value: Dictionary in stage_events:
		if String(event_value.get("id", "")) == event_id:
			return event_value
	return {}

## 필드에 놓인 사건 표식. 조건이 안 맞거나 끝난 사건은 표식이 사라진다.
func _refresh_event_marks() -> void:
	if not is_instance_valid(gameplay_root):
		return
	for event_value: Dictionary in stage_events:
		var event_id := String(event_value.get("id", ""))
		var visible_now := String(event_value.get("state", "hidden")) in ["ready", "active"] \
			and _event_condition_ok(event_value)
		var has_mark := event_marks.has(event_id) and is_instance_valid(event_marks[event_id])
		if visible_now and not has_mark:
			var entry := _event_entry(String(event_value.get("type", "")))
			var new_mark := FieldEventMark.new()
			new_mark.name = "EventMark_%s" % event_id
			new_mark.kind = String(event_value.get("type", ""))
			new_mark.tint = entry.get("color", GamePalette.CYAN)
			new_mark.position = event_value.get("position", Vector2.ZERO)
			new_mark.z_index = 2
			gameplay_root.add_child(new_mark)
			event_marks[event_id] = new_mark
		elif not visible_now and has_mark:
			_clear_event_mark(event_value)

func _clear_event_mark(event_value: Dictionary) -> void:
	var event_id := String(event_value.get("id", ""))
	if event_marks.has(event_id):
		if is_instance_valid(event_marks[event_id]):
			event_marks[event_id].queue_free()
		event_marks.erase(event_id)

## 지금 서 있는 자리에서 열 수 있는 사건. `_refresh_interactable()`이 월드 오브젝트보다
## **먼저** 이걸 본다 — 같은 자리에 상자와 사건이 겹치는 경우가 드물게 있다.
func _nearest_field_event(point: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := radius
	for event_value: Dictionary in stage_events:
		if String(event_value.get("state", "hidden")) != "ready" or not _event_condition_ok(event_value):
			continue
		var distance := point.distance_to(event_value.get("position", Vector2.ZERO))
		if distance < best_distance:
			best_distance = distance
			best = event_value
	return best

func field_event_prompt(event_value: Dictionary) -> String:
	return String(_event_entry(String(event_value.get("type", ""))).get("prompt", "[ E ]  사건"))

# --- 발동 -------------------------------------------------------------------
func _activate_field_event(event_id: String) -> void:
	var event_value := _event_by_id(event_id)
	if event_value.is_empty() or String(event_value.get("state", "")) != "ready":
		return
	if not _event_condition_ok(event_value):
		return
	var type_id := String(event_value.get("type", ""))
	var center: Vector2 = event_value.get("position", Vector2.ZERO)
	current_interactable.clear()
	interaction_text.visible = false
	match type_id:
		"dungeon": _begin_event_waves(event_value, 3 + clock.stage, 3, "작은 던전")
		"semi_elite": _begin_semi_elite(event_value)
		"footprint": _begin_event_waves(event_value, 2, 1, "마왕의 발자국")
		"pack": _begin_event_waves(event_value, 8, 1, "굶주린 무리")
		"isle":
			event_value["state"] = "done"
			_clear_event_mark(event_value)
			_show_banner("보물섬 · 함정 없는 상자 셋", GamePalette.YELLOW, 2.6)
			spawn_burst(center, GamePalette.YELLOW, 34, 300.0, 0.8)
			_grant_safe_chests(3, center)
		"merchant":
			event_value["state"] = "active"
			field_merchant_event = event_id
			current_castle = {"id":"%s_%s" % [FIELD_MERCHANT_CASTLE_PREFIX, event_id], "name":"유랑 상인"}
			play_sound("camp", -2.0)
			_show_card_shop(true)
		"shrine":
			event_value["state"] = "done"
			_clear_event_mark(event_value)
			if is_instance_valid(player):
				player.health = maxf(1.0, player.health * 0.5)
				player.health_changed.emit(player.health, player.max_health)
			spawn_burst(center, GamePalette.MAGENTA, 30, 280.0, 0.8)
			_show_banner("사당에 체력 절반을 바쳤습니다 · 각인 셋 중 하나", GamePalette.MAGENTA, 2.8)
			_update_hud()
			_show_rune_draft("event", "playing")
		"meteor":
			event_value["state"] = "done"
			_clear_event_mark(event_value)
			spawn_burst(center, GamePalette.YELLOW, 40, 340.0, 0.9)
			_grant_safe_chests(1, center)
			_grant_consumable(_roll_consumable())
	_update_hud()

## 전투형 사건 셋의 공통 골격 — 균열 아레나(`_activate_rift`)를 그대로 복제했다.
## 다른 것은 파도 수뿐이다. `camp_id`가 `evt_`로 시작하므로 격파가 여기로 돌아온다.
func _begin_event_waves(event_value: Dictionary, total: int, waves: int, label: String) -> void:
	event_value["state"] = "active"
	event_value["waves"] = maxi(1, waves)
	event_value["wave"] = 0
	event_value["remaining"] = 0
	_clear_event_mark(event_value)
	_refresh_event_marks()
	_show_banner("%s · 마물 %d마리" % [label, total], GamePalette.ORANGE, 3.0)
	play_sound("night", -3.0)
	_spawn_event_wave(event_value, total)

func _spawn_event_wave(event_value: Dictionary, total: int) -> void:
	var waves := maxi(1, int(event_value.get("waves", 1)))
	var wave_index := int(event_value.get("wave", 0))
	var per_wave := int(ceil(float(total) / float(waves)))
	var spawned_before := wave_index * per_wave
	var count := clampi(total - spawned_before, 0, per_wave)
	if count <= 0:
		_finish_event(event_value)
		return
	event_value["wave"] = wave_index + 1
	event_value["remaining"] = count
	event_value["total"] = total
	var center: Vector2 = event_value.get("position", Vector2.ZERO)
	var event_id := String(event_value.get("id", ""))
	var type_id := String(event_value.get("type", ""))
	# 「굶주린 무리」는 **같은 종 여덟**이다(§6.2). 첫 마리가 뽑은 종을 나머지가 따른다.
	var forced_archetype := ""
	for index in count:
		var angle := TAU * float(index) / float(count) + float(wave_index) * 0.4
		var distance := 110.0 + float(index % 3) * 46.0
		var spawn_position := center + Vector2.from_angle(angle) * distance
		if not world.is_walkable(spawn_position):
			spawn_position = world.find_walkable_near(center, rng, 70.0, 160.0)
		var behavior := 4 if type_id != "pack" else 3
		var module := "overclock" if type_id == "footprint" else ""
		var mob := combat.spawn_enemy_instance(spawn_position, behavior, module, false,
			event_id, type_id != "pack", forced_archetype, true)
		if not is_instance_valid(mob):
			event_value["remaining"] = maxi(0, int(event_value["remaining"]) - 1)
			continue
		if type_id == "pack" and forced_archetype.is_empty():
			forced_archetype = String(mob.kind)
		mob.displayed_health = mob.health
		mob.trailing_health = mob.health
		mob.set_night_raid(true)

## 「세미 엘리트」 — 이름 있는 중형 1기(HP ×4 · 패턴 2종).
func _begin_semi_elite(event_value: Dictionary) -> void:
	event_value["state"] = "active"
	event_value["waves"] = 1
	event_value["wave"] = 1
	event_value["remaining"] = 1
	event_value["total"] = 1
	_clear_event_mark(event_value)
	var center: Vector2 = event_value.get("position", Vector2.ZERO)
	var spawn_position := center + Vector2(0.0, -120.0)
	if not world.is_walkable(spawn_position):
		spawn_position = world.find_walkable_near(center, rng, 70.0, 150.0)
	var elite := combat.spawn_enemy_instance(spawn_position, 4, "overclock", false,
		String(event_value.get("id", "")), true, "", true)
	if not is_instance_valid(elite):
		_finish_event(event_value)
		return
	# 패턴 2종 = 근접 과부하(overclock) + 원거리 조준(targeting). 둘 다 이미 있는 모듈이라
	# 새 전투 코드를 한 줄도 만들지 않는다.
	elite.force_module("targeting")
	elite.max_health *= 4.0
	elite.health = elite.max_health
	elite.displayed_health = elite.health
	elite.trailing_health = elite.health
	elite.display_name = "이름 있는 %s" % elite.display_name
	elite.set_night_raid(true)
	_show_banner("이름 있는 마물 · %s" % elite.display_name, GamePalette.RED, 3.0)
	spawn_burst(center, GamePalette.RED, 34, 300.0, 0.9)
	play_sound("boss", -6.0)

## 사건 소속 적이 죽었다. `_trial_enemy_defeated()`가 `evt_` 접두어를 보고 여기로 보낸다.
func _event_enemy_defeated(event_id: String) -> void:
	var event_value := _event_by_id(event_id)
	if event_value.is_empty() or String(event_value.get("state", "")) != "active":
		return
	event_value["remaining"] = maxi(0, int(event_value.get("remaining", 0)) - 1)
	if int(event_value["remaining"]) > 0:
		return
	var waves := maxi(1, int(event_value.get("waves", 1)))
	if int(event_value.get("wave", 1)) < waves:
		_spawn_event_wave(event_value, int(event_value.get("total", 0)))
		if is_instance_valid(player):
			show_world_text(player.global_position - Vector2(0.0, 76.0),
				"다음 파도 %d / %d" % [int(event_value["wave"]), waves], GamePalette.ORANGE, 16)
		return
	_finish_event(event_value)

## 사건 보상. 골드·XP는 상점가 사다리(`stage_price_scale()`)를 탄다(§6.2).
func _finish_event(event_value: Dictionary) -> void:
	event_value["state"] = "done"
	_clear_event_mark(event_value)
	var type_id := String(event_value.get("type", ""))
	var scale := stage_price_scale()
	match type_id:
		"dungeon":
			var reward := int(round(60.0 * 1.6 * scale))
			gold += reward
			_show_banner("던전 돌파 · %d G · 각인 셋 중 하나" % reward, GamePalette.ORANGE, 3.0)
			play_sound("choice", 0.0)
			_update_hud()
			if state == "playing":
				_show_rune_draft("event", "playing")
		"semi_elite":
			var elite_gold := int(round(70.0 * scale))
			gold += elite_gold
			_show_banner("이름 있는 마물 격파 · %d G · 장비 둘 중 하나" % elite_gold, GamePalette.RED, 3.0)
			play_sound("choice", 0.0)
			_update_hud()
			if state == "playing":
				_show_item_offer("event")
		"footprint":
			var stripped := _strip_demon_runes(2)
			_show_banner("마왕의 발자국을 지웠습니다 · 각인 %d개를 뜯었습니다" % stripped,
				GamePalette.PURPLE, 3.2)
			play_sound("choice", -2.0)
		"pack":
			var pack_xp := int(round(14.0 * 2.2 * scale))
			_show_banner("굶주린 무리를 쓸었습니다 · 경험 %d" % pack_xp, GamePalette.CYAN, 3.0)
			collect_xp(pack_xp)
	_update_hud()

## 마왕의 각인을 `count`개 뜯는다. 밀정의 지우기와 같은 API를 쓴다(가격·상한은 없다 —
## 이쪽은 사건 보상이다).
func _strip_demon_runes(count: int) -> int:
	var stripped := 0
	for _step in count:
		var candidates: Array[int] = []
		for index in FactoryDeck.SLOT_COUNT:
			if demon_lord.rune_count_on_slot(index) > 0:
				candidates.append(index)
		if candidates.is_empty():
			break
		var target := candidates[rng.randi_range(0, candidates.size() - 1)]
		if demon_lord.strip_rune(target).is_empty():
			break
		stripped += 1
	return stripped

## 「보물섬」·「별똥별」의 상자 — **함정·미믹·저주가 없는** 배당이다(§6.2 "함정 없음").
## 상자 하나를 여는 것과 같은 화면을 쓰되 위협 칸만 뺀다.
func _grant_safe_chests(count: int, at: Vector2) -> void:
	var scale := stage_price_scale()
	var pending_modal := ""
	for _step in count:
		var roll := rng.randi_range(0, 99)
		if roll < 34:
			var reward := int(round(float(rng.randi_range(22, 46)) * scale))
			gold += reward
			_spawn_coin_spin(at)
			_show_banner("상자 · %d G" % reward, GamePalette.YELLOW, 2.0)
		elif roll < 62:
			collect_xp(int(round(float(rng.randi_range(6, 12)) * scale)))
		elif roll < 78:
			_grant_consumable(_roll_consumable())
		elif roll < 90:
			pending_modal = "item"
		else:
			pending_modal = "rune"
	_update_hud()
	# 모달은 한 번만 연다 — 셋을 겹쳐 열면 화면이 사슬처럼 쌓인다.
	if pending_modal == "item" and state == "playing":
		call_deferred("_show_item_offer", "treasure")
	elif pending_modal == "rune" and state == "playing":
		call_deferred("_show_rune_draft", "chest", "playing")

## 유랑 상인 창구를 닫는다(`_close_base_camp`이 부른다). 상인은 **한 번뿐**이다.
func _close_field_merchant() -> void:
	if field_merchant_event.is_empty():
		return
	var event_value := _event_by_id(field_merchant_event)
	if not event_value.is_empty():
		event_value["state"] = "done"
		_clear_event_mark(event_value)
	field_merchant_event = ""
	current_castle.clear()
	shop_offers.clear()
	shop_castle_id = ""

func field_merchant_open() -> bool:
	return not field_merchant_event.is_empty()

# -----------------------------------------------------------------------------
# 저장 — schema 4 (§6.1 · handoff-y1 §9-F · y2 §8-C · y3 §9-C)
# -----------------------------------------------------------------------------
## 사건을 스냅샷에 담을 수 있는 모양으로 바꾼다. **표식 노드(`mark`)는 뺀다** —
## Node는 `ConfigFile`이 직렬화하지 못하고, 복원 뒤에 다시 그리면 되는 값이다.
func _serialize_stage_events() -> Array:
	var out: Array = []
	for event_value: Dictionary in stage_events:
		out.append(event_value.duplicate(true))
	return out

func _restore_stage_events(saved: Array) -> void:
	_reset_stage_events()
	for value in saved:
		if not (value is Dictionary):
			continue
		var event_value: Dictionary = (value as Dictionary).duplicate(true)
		event_value.erase("mark")
		# 진행 중이던 전투형 사건은 **다시 열 수 있는 상태로 되돌린다.** 저장 정책상
		# 전투 중에는 스냅샷을 안 쓰지만(§9 V9), 사건 적이 필드에 남은 채 저장될 수는
		# 있다 — 그 적은 복원되지 않으므로 `active`로 두면 영원히 못 끝낸다.
		if String(event_value.get("state", "ready")) == "active":
			event_value["state"] = "ready"
			event_value["remaining"] = 0
			event_value["wave"] = 0
		stage_events.append(event_value)
	_refresh_event_marks()

func _restore_discovered_features(saved: Variant) -> void:
	_seed_stage_discovery()
	if not (saved is Array):
		return
	for key in (saved as Array):
		discovered_features[String(key)] = true

## 로비 「이어하기」 칩의 본문. schema가 올라 런이 버려졌으면 **한 번만** 그 사실을
## 말한다(리스크 5 "조용히 사라지지 않게"). 읽는 순간 플래그가 꺼진다.
func _lobby_run_chip_text() -> String:
	if saved_run_dropped and not saved_run_available:
		saved_run_dropped = false
		return "규칙이 바뀌어 이전 모험은 이어갈 수 없습니다"
	return _saved_run_detail()

# -----------------------------------------------------------------------------
# 소비 아이템 (§6.3)
# -----------------------------------------------------------------------------
func consumable_name(id: String) -> String:
	return String((CONSUMABLES.get(id, {}) as Dictionary).get("name", ""))

func _roll_consumable() -> String:
	return CONSUMABLE_DROP_POOL[rng.randi_range(0, CONSUMABLE_DROP_POOL.size() - 1)]

## 소비 아이템을 준다. 이미 들고 있으면 **바꿀지 묻는다**(§6.3 · Y4의 교체 확인 컴포넌트).
func _grant_consumable(id: String) -> void:
	if id.is_empty() or not CONSUMABLES.has(id):
		return
	if consumable_item.is_empty():
		consumable_item = id
		_show_banner("%s 획득 · Q로 씁니다" % consumable_name(id), GamePalette.CYAN, 2.4)
		_update_hud()
		return
	if consumable_item == id:
		# 같은 것을 또 주우면 물을 것이 없다 — 슬롯이 하나라 버릴 수밖에 없다.
		var held_name := consumable_name(id)
		_show_banner("%s%s 이미 들고 있습니다" % [held_name, _particle_eun(held_name)], GamePalette.MUTED, 2.0)
		return
	_show_consumable_swap_confirm(id)

## Q — 소비 슬롯을 쓴다.
func _use_consumable() -> void:
	if state != "playing" or consumable_item.is_empty() or not is_instance_valid(player):
		return
	var id := consumable_item
	var used := true
	match id:
		"map":
			var revealed := _discover_all_stage_features()
			_show_banner("낡은 지도 · 화살표 %d개가 켜졌습니다" % revealed, GamePalette.CYAN, 2.6)
		"sundial":
			if is_night:
				_show_banner("해시계는 낮에만 씁니다", GamePalette.MUTED, 1.8)
				used = false
			else:
				clock.phase_elapsed = maxf(0.0, clock.phase_elapsed - SUNDIAL_SECONDS)
				_show_banner("해시계 · 낮이 %d초 늘었습니다" % int(SUNDIAL_SECONDS), GamePalette.YELLOW, 2.6)
		"nighteye":
			night_eye_nights = 1
			if is_night:
				night_eye_active = true
			_show_banner("밤눈 부적 · 다음 밤 동안 마물이 늦게 알아챕니다", GamePalette.BLUE, 2.8)
		"horn":
			var gathered := _horn_gather()
			_show_banner("소환 뿔피리 · 마물 %d마리를 모았습니다" % gathered, GamePalette.ORANGE, 2.4)
		"bread":
			player.heal(player.max_health * BREAD_HEAL_RATIO)
			spawn_burst(player.global_position, GamePalette.GREEN, 22, 200.0, 0.5)
			_show_banner("회복의 빵 · 체력 %d%% 회복" % int(BREAD_HEAL_RATIO * 100.0), GamePalette.GREEN, 2.2)
		"bell":
			if not is_instance_valid(world):
				used = false
			else:
				player.global_position = _walkable_spawn_point(world.get_castle_position() + Vector2(0.0, 120.0))
				player.velocity = Vector2.ZERO
				player.grant_invulnerability(GameTuning.STAGE_SPAWN_INVULN)
				var camera := player.get_node_or_null("PlayerCamera") as Camera2D
				if is_instance_valid(camera):
					camera.reset_smoothing()
				_show_banner("되돌이 종 · 성 앞으로 돌아왔습니다", GamePalette.MAGENTA, 2.4)
		"eraser":
			var refund := _erase_slot_runes()
			if refund < 0:
				_show_banner("떼어 낼 각인이 없습니다", GamePalette.MUTED, 1.8)
				used = false
			else:
				_show_banner("각인 지우개 · %d G를 되받았습니다" % refund, GamePalette.MUTED, 2.6)
		"decoy":
			_spawn_decoy()
			_show_banner("미끼 인형 · %d초 동안 마물이 인형을 때립니다" % int(DECOY_SECONDS), GamePalette.PURPLE, 2.2)
		_:
			used = false
	if not used:
		return
	consumable_item = ""
	play_sound("collect", -3.0)
	_update_hud()

## 「소환 뿔피리」 — 근처 마물을 앞쪽 한 점으로 끌어모은다. **한 번에 옮긴다**(트윈 없음).
func _horn_gather() -> int:
	if not is_instance_valid(player) or combat == null:
		return 0
	var facing := player.velocity.normalized()
	if facing.length_squared() < 0.01:
		facing = Vector2.RIGHT
	var focus := player.global_position + facing * HORN_GATHER_LEAD
	if is_instance_valid(world) and not world.is_walkable(focus):
		focus = player.global_position
	var moved := 0
	for enemy in combat.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_boss:
			continue
		if enemy.global_position.distance_to(player.global_position) > HORN_GATHER_RADIUS:
			continue
		var angle := TAU * float(moved) / 8.0
		var seat := focus + Vector2.from_angle(angle) * (48.0 + float(moved % 3) * 22.0)
		if is_instance_valid(world) and not world.is_walkable(seat):
			seat = focus
		enemy.global_position = seat.round()
		enemy.aggro = true
		moved += 1
	spawn_burst(focus, GamePalette.ORANGE, 26, 240.0, 0.6)
	return moved

## 「각인 지우개」 — 각인이 가장 많은 칸을 통째로 떼고 골드로 되판다. 되받은 값을 돌려준다
## (떼어 낼 것이 없으면 −1).
func _erase_slot_runes() -> int:
	if factory == null:
		return -1
	var target := -1
	var best := 0
	for index in factory.slots.size():
		var count := factory.rune_count_on(index)
		if count > best:
			best = count
			target = index
	if target < 0 or best <= 0:
		return -1
	for _step in best:
		if factory.detach_rune(target, factory.rune_count_on(target) - 1).is_empty():
			break
	var refund := best * _scaled_price(RUNE_ERASER_REFUND)
	gold += refund
	_reset_player_cycle()
	return refund

## 「미끼 인형」 — 근처 마물의 시선을 8초 동안 인형으로 옮긴다.
## `DebtEnemy`가 `player`에게 쓰는 것은 `global_position`과 `take_damage()` 둘뿐이라,
## **그 둘만 흉내 내는 노드**로 갈아 끼우면 enemy.gd를 한 줄도 안 고치고 성립한다.
func _spawn_decoy() -> void:
	_clear_decoy()
	if not is_instance_valid(player) or not is_instance_valid(gameplay_root):
		return
	var doll := DecoyDoll.new()
	doll.position = player.global_position + Vector2(0.0, -12.0)
	doll.z_index = 3
	gameplay_root.add_child(doll)
	decoy_node = doll
	decoy_timer = DECOY_SECONDS
	decoy_enemies.clear()
	if combat == null:
		return
	for enemy in combat.active_enemies:
		if not is_instance_valid(enemy) or enemy.is_boss:
			continue
		if enemy.global_position.distance_to(doll.global_position) > DECOY_RADIUS:
			continue
		enemy.player = doll
		enemy.aggro = true
		decoy_enemies.append(enemy)

func _clear_decoy() -> void:
	for enemy in decoy_enemies:
		if is_instance_valid(enemy) and is_instance_valid(player):
			enemy.player = player
	decoy_enemies.clear()
	if is_instance_valid(decoy_node):
		decoy_node.queue_free()
	decoy_node = null
	decoy_timer = 0.0

## 「밤눈 부적」 — 다음 밤 한 번, 감지 반경이 −40%가 된다.
##
## **Y7이 이 구현을 갈아치웠다**(handoff-y6 §5-4가 예고한 승격).
## Y6은 `enemy.gd`를 못 여는 웨이브였기 때문에 game.gd에서 **0.25초마다 전 개체를
## 훑어** 반경 밖 개체를 습격 모드에서 빼는 스윕으로 같은 그림을 만들었다.
## 그 스윕은 밤 내내 도는 O(N) 순회였다 — 78기 예산 규약의 정확히 반대편이다.
## 이제 감지 반경 배율은 `DebtEnemy.night_sight_scale` **필드**이고, 각 개체가
## 자기 `_physics_process` 안에서 자기 거리만 본다(새 순회 0).
## 여기 남은 일은 **배율을 심고 거두는 것** 둘뿐이고, 둘 다 밤낮 전환 시 1회다.
func current_night_sight_scale() -> float:
	return NIGHT_EYE_SCALE if night_eye_active else 1.0

func night_eye_range() -> float:
	return NIGHT_EYE_BASE_RANGE * NIGHT_EYE_SCALE

## 필드에 이미 서 있는 개체 전원에게 지금 배율을 심는다. **밤낮 전환마다 딱 한 번**
## 도는 순회다(스윕이 아니다). 이후에 태어나는 개체는 `register_enemy()`가 챙긴다.
func _apply_night_sight_to_field() -> void:
	if combat == null:
		return
	var scale_value := current_night_sight_scale()
	for enemy in combat.active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_night_sight_scale"):
			enemy.set_night_sight_scale(scale_value)

## 밤이 시작될 때 부적을 켜고, 밤이 끝나면 끈다(`_on_night_started`/`_on_day_started`가 부른다).
func _night_eye_phase(night: bool) -> void:
	if night:
		night_eye_active = night_eye_nights > 0
		_apply_night_sight_to_field()
		return
	if night_eye_active:
		night_eye_nights = maxi(0, night_eye_nights - 1)
		night_eye_active = false
	_apply_night_sight_to_field()

# -----------------------------------------------------------------------------
# Y6 프레임 (`_process`의 Y6 구역이 부른다)
# -----------------------------------------------------------------------------
func _tick_y6(delta: float) -> void:
	if decoy_timer > 0.0:
		decoy_timer -= delta
		if decoy_timer <= 0.0:
			_clear_decoy()
		elif is_instance_valid(decoy_node):
			# 인형은 제자리에 서 있는다. 죽거나 새로 생긴 적은 다음 인형이 챙긴다.
			decoy_node.remaining = decoy_timer
			decoy_node.queue_redraw()
	# Y7: 「밤눈 부적」의 0.25초 스윕은 여기서 **사라졌다.** 감지 반경 배율이
	# `DebtEnemy.night_sight_scale` 필드가 되면서 밤 내내 돌던 O(N) 순회가 없어졌다
	# (handoff-y6 §5-4가 넘긴 승격 · 심는 것은 밤낮 전환 1회로 충분하다).

# -----------------------------------------------------------------------------
# 소비 슬롯 HUD (판 없음 · 키캡 + 글리프 + 이름 한 낱말)
# -----------------------------------------------------------------------------
func _build_consumable_slot() -> void:
	consumable_panel = Control.new()
	consumable_panel.name = "ConsumableSlot"
	consumable_panel.position = HUD_CONSUMABLE_RECT.position
	consumable_panel.size = HUD_CONSUMABLE_RECT.size
	consumable_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(consumable_panel)
	var keycap := UIKit.keycap("q")
	if keycap != null:
		consumable_key_icon = TextureRect.new()
		consumable_key_icon.name = "ConsumableKey"
		consumable_key_icon.texture = keycap
		consumable_key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		consumable_key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		consumable_key_icon.custom_minimum_size = Vector2.ZERO
		consumable_key_icon.position = HUD_CONSUMABLE_KEY.position
		consumable_key_icon.size = HUD_CONSUMABLE_KEY.size
		consumable_key_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		consumable_key_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		consumable_panel.add_child(consumable_key_icon)
	consumable_glyph = _kit_glyph(consumable_panel, HUD_CONSUMABLE_GLYPH, "bag", GamePalette.MUTED, 28.0)
	if is_instance_valid(consumable_glyph):
		consumable_glyph.name = "ConsumableGlyph"
	consumable_label = _label("", UI_LABEL_SIZE, _hud_ink(GamePalette.CYAN))
	consumable_label.name = "ConsumableName"
	consumable_label.position = HUD_CONSUMABLE_TEXT.position
	consumable_label.size = HUD_CONSUMABLE_TEXT.size
	consumable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	consumable_panel.add_child(consumable_label)
	_hud_tip_target("consumable", consumable_panel)

func _update_consumable_slot() -> void:
	if not is_instance_valid(consumable_panel):
		return
	# 성 안에서만 숨는다. `state`로 묶지 않는 이유는 신상·스테이지 줄과 같다 —
	# 캡처·프리뷰(`state == "preview"`)에서 HUD 한 조각만 사라지면 검수가 거짓말을 한다.
	consumable_panel.visible = not inside_castle
	var entry: Dictionary = CONSUMABLES.get(consumable_item, {})
	var empty := entry.is_empty()
	if is_instance_valid(consumable_glyph):
		var glyph_name := "bag" if empty else String(entry.get("glyph", "bag"))
		var texture := UIKit.glyph(glyph_name)
		if texture != null and consumable_glyph.texture != texture:
			consumable_glyph.texture = texture
		consumable_glyph.modulate = _hud_ink(GamePalette.MUTED if empty else entry.get("color", GamePalette.CYAN))
	if is_instance_valid(consumable_label):
		consumable_label.text = "" if empty else String(entry.get("name", ""))
		# 이름 색 = 아이템 색. 글리프와 같은 색을 써야 둘이 한 덩어리로 읽힌다.
		consumable_label.add_theme_color_override("font_color",
			_hud_ink(GamePalette.MUTED if empty else entry.get("color", GamePalette.CYAN)))
	if is_instance_valid(consumable_key_icon):
		consumable_key_icon.modulate = Color(1.0, 1.0, 1.0, 0.42 if empty else 1.0)

## 소비 칸 툴팁. 화면에는 키캡·글리프·이름만 두고 효과와 획득처는 여기서 말한다.
func _consumable_tooltip_spec() -> Dictionary:
	var entry: Dictionary = CONSUMABLES.get(consumable_item, {})
	if entry.is_empty():
		return {
			"title": "소비 칸  ·  비어 있음",
			"accent": _hud_ink(GamePalette.MUTED),
			"rows": [["쓰는 키", "Q"], ["칸", "1개"]],
			"body": "상자 · 상인 · 사건에서 하나씩 나옵니다. 이미 들고 있으면 바꿀지 물어봅니다."
		}
	return {
		"title": String(entry.get("name", "")),
		"accent": _hud_ink(entry.get("color", GamePalette.CYAN)),
		"rows": [["효과", String(entry.get("line", ""))], ["쓰는 키", "Q"]],
		"body": "한 번 쓰면 사라집니다. 새로 주우면 바꿀지 물어봅니다."
	}

# -----------------------------------------------------------------------------
# 소비 아이템 교체 확인 — Y4의 장비 교체 확인과 **같은 컴포넌트**(§6.3)
# -----------------------------------------------------------------------------
func _show_consumable_swap_confirm(incoming: String) -> void:
	consumable_swap = incoming
	# 필드 한복판에서 열리는 유일한 확인 화면이다 — 물어보는 동안 맞으면 안 된다.
	# 새 `state`를 만들지 않고 `consumable_swap` 한 값이 열고 닫는다(Y4와 같은 규약).
	get_tree().paused = true
	var panel := _build_swap_confirm_shell("소비 칸을 바꿀까요?",
		"지금 든 것", "새로 주운 것",
		"버린 것은 사라집니다   ·   SPACE 바꾸기   ·   ESC 그대로",
		_confirm_consumable_swap, _cancel_consumable_swap, "ConsumableSwap")
	if panel == null:
		return
	var left := _consumable_card(panel, consumable_item,
		Vector2(24.0, 96.0))
	left.name = "EquipSwapCurrent"
	var right := _consumable_card(panel, incoming,
		Vector2(EQUIP_SWAP_RECT.size.x - 24.0 - EQUIP_SWAP_CARD.x, 96.0))
	right.name = "EquipSwapIncoming"
	if automated_test:
		call_deferred("_confirm_consumable_swap")

func _confirm_consumable_swap() -> void:
	if consumable_swap.is_empty():
		return
	consumable_item = consumable_swap
	consumable_swap = ""
	_close_swap_confirm()
	_show_banner("%s로 바꿨습니다" % consumable_name(consumable_item), GamePalette.CYAN, 2.0)
	_update_hud()

func _cancel_consumable_swap() -> void:
	if consumable_swap.is_empty():
		return
	consumable_swap = ""
	_close_swap_confirm()
	_update_hud()

func _close_swap_confirm() -> void:
	_clear_overlay()
	if state == "playing":
		get_tree().paused = false
		interaction_timer = 0.0

## 소비 아이템 한 장. 장비 카드와 같은 크기(`EQUIP_SWAP_CARD`)라 두 카드가 나란히 선다.
func _consumable_card(parent: Control, id: String, at: Vector2) -> Control:
	var entry: Dictionary = CONSUMABLES.get(id, {})
	var color: Color = entry.get("color", GamePalette.MUTED)
	var card := _kit_panel(parent, Rect2(at, EQUIP_SWAP_CARD), UIKit.Tone.SLATE, UIKit.Role.PANEL)
	_kit_glyph(card, Vector2(EQUIP_SWAP_CARD.x * 0.5 - 24.0, 52.0),
		String(entry.get("glyph", "bag")), color, 48.0)
	_kit_label(card, Rect2(0.0, 124.0, EQUIP_SWAP_CARD.x, 34.0),
		String(entry.get("name", "")), UIKit.Tone.SLATE, UIKit.FONT_TITLE, false,
		UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	_kit_label(card, Rect2(16.0, 168.0, EQUIP_SWAP_CARD.x - 32.0, 26.0),
		String(entry.get("line", "")), UIKit.Tone.SLATE, UIKit.FONT_LABEL, true,
		UIKit.Role.PANEL, HORIZONTAL_ALIGNMENT_CENTER)
	return card

# -----------------------------------------------------------------------------
# 상자 보상 금화 회전 (`ui-coin-spin.png` 배선 · handoff-y4 §9-C)
# -----------------------------------------------------------------------------
const COIN_SPIN_SHEET := preload("res://art/v2/ui-coin-spin.png")

func _spawn_coin_spin(at: Vector2) -> void:
	if not is_instance_valid(gameplay_root):
		return
	var spin := CoinSpinEffect.new()
	spin.position = at + Vector2(0.0, -26.0)
	spin.z_index = 8
	gameplay_root.add_child(spin)

## 4프레임 1회 재생 후 스스로 사라진다(트윈 루프 금지 규칙 — `chest_open_effect`와 같은 규약).
class CoinSpinEffect:
	extends Node2D

	const CELL := 20.0
	const FRAMES := 4
	const FRAME_TIME := 0.11
	const RISE := 26.0

	var elapsed := 0.0

	func _ready() -> void:
		z_as_relative = false

	func _process(delta: float) -> void:
		elapsed += delta
		var total := FRAME_TIME * float(FRAMES)
		if elapsed >= total:
			queue_free()
			return
		position.y -= RISE * delta / total
		queue_redraw()

	func _draw() -> void:
		var frame := clampi(int(elapsed / FRAME_TIME), 0, FRAMES - 1)
		var progress := clampf(elapsed / (FRAME_TIME * float(FRAMES)), 0.0, 1.0)
		var tint := Color(1.0, 1.0, 1.0, 1.0 - progress * progress)
		draw_texture_rect_region(GameMain.COIN_SPIN_SHEET,
			Rect2(Vector2(-CELL, -CELL), Vector2(CELL * 2.0, CELL * 2.0)),
			Rect2(Vector2(float(frame) * CELL, 0.0), Vector2(CELL, CELL)), tint)

# -----------------------------------------------------------------------------
# Y7: 충격 버스트 (`vfx-burst.png` 배선 · handoff-y4 §9-C가 Y7에 넘긴 항목)
# -----------------------------------------------------------------------------
# handoff-y4는 이 시트의 배선 지점을 「상태 폭발 시점 = §7.3 impact 프로필」이라고
# 적었다. 그 자리가 바로 **카메라 흔들림을 걷어낸 자리**다 — 무거운 카드가 터질 때
# `combat_resolver`가 화면을 흔들던 한 줄을 지우고, 대신 맞은 자리에서 이 버스트가
# 핀다(§7.1 원칙 2 "타격감은 대상 쪽에서 만든다").
#
# 그리기는 `attack_effect.gd`의 `kind == "impact"`가 한다 — 새 노드 종류를 만들지
# 않았으므로 전역 연출 예산과 반납 배선이 그대로 따라온다.
# **카드당 한 개**만 만든다(대상마다가 아니다 — 78기 환경에서 그건 노드 폭탄이다).

## 충격 프로필별 버스트 크기(px). §7.3 표의 「넉백」열 세기를 그대로 옮긴 서열이다.
## 표에 없는 impact(빈 문자열 포함)는 0 — **아무것도 안 그린다.**
## 붙잡기(`pin`)와 가속(`haste_self`)은 터지는 연출이 아니지만 「걸렸다」를 알려야
## 해서 가장 작게 남긴다 — 여덟 줄 중 둘만 화면에서 아무 말도 안 하면 그 둘이
## 고장 난 것으로 읽힌다.
const IMPACT_BURST_SIZE: Dictionary = {
	"push": 96.0,
	"pop": 88.0,
	"rush": 76.0,
	"drag": 70.0,
	"stagger": 66.0,
	"slow": 62.0,
	"pin": 54.0,
	"haste_self": 48.0
}
## 6프레임을 다 보여 주는 재생 시간. 한 바퀴 리듬을 안 끊게 짧게 잡았다.
const IMPACT_BURST_SECONDS := 0.27

func spawn_impact_burst(at: Vector2, tint: Color, impact: String) -> void:
	var burst_size := float(IMPACT_BURST_SIZE.get(impact, 0.0))
	if burst_size <= 0.0:
		return
	spawn_attack_effect(at, "impact", tint, Vector2.RIGHT, burst_size, IMPACT_BURST_SECONDS)

## Y7: 플레이어 가속(§7.3 `haste_self`). `combat_resolver`가 플레이어 내부를 직접
## 만지지 않도록 game.gd가 창구를 연다 — 규칙 계층은 노드를 모른다는 원칙 그대로다.
func apply_player_haste() -> void:
	if is_instance_valid(player) and player.has_method("apply_haste"):
		player.apply_haste()

## 미끼 인형. `DebtEnemy`가 플레이어에게 쓰는 두 가지(`global_position` · `take_damage`)만
## 갖춘 최소 노드다. 맞아도 아무 일이 없고, 남은 시간을 발밑에 게이지 한 줄로 보여 준다.
class DecoyDoll:
	extends Node2D

	var remaining := 8.0

	func take_damage(_amount: float, _source_position: Vector2 = Vector2.ZERO,
			_ignore_shield: bool = false) -> void:
		pass

	func _draw() -> void:
		var ink := Color(0.03, 0.05, 0.09, 0.92)
		var body := GamePalette.PURPLE
		draw_rect(Rect2(Vector2(-9.0, -2.0), Vector2(18.0, 22.0)), ink, true)
		draw_rect(Rect2(Vector2(-7.0, 0.0), Vector2(14.0, 18.0)), body, true)
		draw_circle(Vector2(0.0, -8.0), 8.0, ink)
		draw_circle(Vector2(0.0, -8.0), 6.0, body)
		var ratio := clampf(remaining / 8.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-14.0, 26.0), Vector2(28.0, 4.0)), ink, true)
		draw_rect(Rect2(Vector2(-13.0, 27.0), Vector2(26.0 * ratio, 2.0)), GamePalette.PURPLE, true)

## 필드 사건 표식. 균열처럼 땅에 그린다 — 스프라이트를 새로 굽지 않는다(YA 미납 자산 0).
class FieldEventMark:
	extends Node2D

	var kind := "dungeon"
	var tint := Color.WHITE

	const INK := Color(0.03, 0.05, 0.09, 0.82)
	const RING := 42.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, RING, 0.0, TAU, 30, INK, 6.0, true)
		draw_arc(Vector2.ZERO, RING, 0.0, TAU, 30, tint, 2.6, true)
		match kind:
			"dungeon":
				# 문 = 던전 입구.
				draw_rect(Rect2(Vector2(-11.0, -16.0), Vector2(22.0, 32.0)), INK, true)
				draw_rect(Rect2(Vector2(-8.0, -13.0), Vector2(16.0, 29.0)), tint, true)
				draw_circle(Vector2(4.0, 2.0), 2.4, INK)
			"isle":
				# 야자수 하나 얹은 섬.
				draw_rect(Rect2(Vector2(-16.0, 6.0), Vector2(32.0, 8.0)), tint, true)
				draw_rect(Rect2(Vector2(-2.0, -14.0), Vector2(4.0, 20.0)), INK, true)
				draw_circle(Vector2(0.0, -16.0), 8.0, tint)
			"semi_elite":
				# 뿔 두 개 = 이름 있는 마물.
				draw_circle(Vector2.ZERO, 11.0, INK)
				draw_circle(Vector2.ZERO, 8.5, tint)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-9.0, -6.0), Vector2(-16.0, -20.0), Vector2(-3.0, -12.0)]), tint)
				draw_colored_polygon(PackedVector2Array([
					Vector2(9.0, -6.0), Vector2(16.0, -20.0), Vector2(3.0, -12.0)]), tint)
			"merchant":
				# 짐 보따리.
				draw_rect(Rect2(Vector2(-14.0, -4.0), Vector2(28.0, 20.0)), INK, true)
				draw_rect(Rect2(Vector2(-12.0, -2.0), Vector2(24.0, 16.0)), tint, true)
				draw_rect(Rect2(Vector2(-4.0, -14.0), Vector2(8.0, 10.0)), tint, true)
			"shrine":
				# 무너진 기둥 셋.
				for offset: float in [-12.0, 0.0, 12.0]:
					var height := 24.0 if is_zero_approx(offset) else 15.0
					draw_rect(Rect2(Vector2(offset - 4.0, 14.0 - height), Vector2(8.0, height)), INK, true)
					draw_rect(Rect2(Vector2(offset - 3.0, 15.0 - height), Vector2(6.0, height - 2.0)), tint, true)
			"footprint":
				# 커다란 발자국.
				draw_circle(Vector2(0.0, 4.0), 11.0, INK)
				draw_circle(Vector2(0.0, 4.0), 8.5, tint)
				for index in 3:
					var x := -8.0 + float(index) * 8.0
					draw_circle(Vector2(x, -10.0), 3.6, tint)
			"pack":
				# 이빨 셋.
				for index in 3:
					var base := -14.0 + float(index) * 14.0
					draw_colored_polygon(PackedVector2Array([
						Vector2(base - 5.0, -10.0), Vector2(base + 5.0, -10.0), Vector2(base, 12.0)]), tint)
			"meteor":
				# 꼬리 달린 별.
				draw_polyline(PackedVector2Array([Vector2(-18.0, -16.0), Vector2(6.0, 6.0)]), tint, 4.0)
				draw_circle(Vector2(9.0, 9.0), 7.0, INK)
				draw_circle(Vector2(9.0, 9.0), 5.0, tint)
			_:
				draw_circle(Vector2.ZERO, 8.0, tint)
