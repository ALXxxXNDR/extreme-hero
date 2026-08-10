# handoff-u2 — 모달 · ESC 딜싸이클 편집 v3 재스킨

작성: U2 · 2026-08-09 · 대상: U3(스포트라이트 길잡이) · 다음 웨이브

사용자 요구는 한 줄이었다 — "레벨업 UI, 딜싸이클 UI(ESC 눌렀을 때 딜싸이클 칸) 모두
새 필드 테마의 센세이셔널한 UI로 180도 변경."

바꾼 것은 **표면**이다. 정보 구조 · 좌표 계약 · 화면 흐름 · 조작 · 단일 포커스 모델 ·
저장 스키마는 한 글자도 안 바뀌었다. 필드 HUD는 **무접촉**이다.

---

## 0. 30초 요약

| 화면 | v1 | v3 |
|---|---|---|
| 레벨업 2택 + 각인 강화 | 남색 모달 + 색 테두리 카드 2 + 자주 버튼 | SLATE 껍데기 + WOOD 리본 + **킷 카드 3장**(SKILL·SKILL·RUNE) |
| 각인 드래프트 1단계 | 남색 카드 3 + 색 바 + `⚠` 텍스트 | ABYSS 리본 + **Card.RUNE** 3장 + 희귀도 칩 + EMBER 과부하 배지 |
| 각인 드래프트 2단계 | 회색 테두리 = 선택 불가 | Card.RUNE 5칸 · **함몰 = 상한 도달** · 흰 이중 립 = 선택 |
| 트로피 2택1 | 남색 모달 + 광선 | **GOLD 껍데기** + WOOD 리본 + SLATE 함몰 무대 + Card.TROPHY 2장 |
| ESC 편집 화면 | 3px 색 테두리로 두 모드 구분 | 칸 프레임이 **모드에 따라 통째로 뒤집힌다**(SKILL/ITEM ↔ RUNE) |
| 성 NPC 4종 · 캠프 · 상점 | 남색 모달 + 4px 액센트 바 | SLATE 껍데기 + 창구별 리본(WOOD / ABYSS / EMBER) |
| 결과 화면 | 남색 전면 모달 | **PARCHMENT 껍데기** + GOLD(승)/EMBER(패) 리본 + SLATE 함몰 무대 |
| 마왕·보스 프리뷰 | 남색 모달 | **ABYSS 껍데기** + EMBER 리본 + 내 레일 SKILL / 적 레일 BOSS |
| 전역 스크롤바 | v1 남색 막대 | `ui-kit-bars.png` 게이지 |

검증: `--editor --quit` 오류 0 · `run_all.sh` **14/14 PASS** · 캡처 육안 확인 ·
**`set_loops()` 프로젝트 전체 0건**(U0이 지목한 마지막 1건 삭제).

---

## 1. 새로 생긴 공용 부품 (`game.gd:2060~2170`)

U1의 `_kit_ribbon/_kit_panel/_kit_label/_kit_button/_kit_keycap/_kit_glyph`(4100행대)를
그대로 쓰고, 모달·편집에만 필요한 것 일곱 개를 더했다. **U3도 그대로 쓸 것.**

| 함수 | 하는 일 |
|---|---|
| `_kit_scrim(parent, alpha)` | 스크림 1장. 색은 `UIKit.SPOTLIGHT_INK` — 길잡이가 겹쳐도 색이 안 튄다 |
| `_kit_shell(parent, rect, title, tone, ribbon_tone, ribbon_w)` | 껍데기 + 헤더 리본. 리본은 **부모**에 붙고 `kit_ribbon` meta로 껍데기와 묶인다 |
| `_kit_card_skin(button, kind, state)` | 버튼 5상태에 카드 프레임 일괄. `kit_card_kind` meta를 남긴다 |
| `_kit_card_box(kind, state)` / `_kit_button_box(variant, state)` | int → enum 디스패처(아래 §5.3) |
| `_kit_btn_variant(color)` | v1 의미색 → 킷 버튼 변종. `_style_button`이 쓴다 |
| `_kit_focus_ring(parent, rect)` | 흰 포커스 링 **별개 층** |
| `_kit_scrollbar_style(kind, tint)` (`11457`) | 전역 스크롤바를 킷 게이지로 |

상수: `KIT_SCRIM_MODAL 0.62` · `KIT_SCRIM_DEEP 0.82` · `KIT_RIBBON_OVERHANG 10`.

`_animate_modal()`은 이제 `kit_ribbon` meta를 보고 **리본도 같이** 1회성 전환시킨다.
안 그러면 등장 0.22초 동안 명판만 제자리에 떠 있는다. 루프는 여전히 0건이다.

---

## 2. 한 곳만 고쳐 전 화면이 따라온 세 개

이 셋이 이번 웨이브 효과의 대부분이다. 화면별 코드를 60군데 고치는 대신 관문을 갈았다.

### 2.1 `_style_button()` (`11354`)

호출부 60여 군데가 **색으로 버튼 성격을 말해 왔다.** 그 색을 `_kit_btn_variant()`가
읽어 킷 변종을 고른다 — 시그니처·호출부는 한 줄도 안 바뀌었다.

```
RED · MAGENTA · PURPLE            → Btn.DANGER  (EMBER)
MUTED · CYAN · BLUE · NIGHT · STONE* → Btn.NEUTRAL (SLATE)
그 외 (YELLOW · ORANGE · GREEN · 카드색) → Btn.PRIMARY (WOOD)
```

폰트도 하드코딩 16 → `FONT_HEADING`(17)로 5단 안에 들어왔다(§5가 권한 그대로).
`choice_color` meta는 그대로 남기고 `kit_btn_variant` meta를 추가했다.

### 2.2 `_paint_card_block()` (`3507`)

안쪽 여백이 하드코딩 8에서 **호스트의 프레임 두께**를 따라간다.
호스트가 `kit_frame_pad` meta를 들고 있으면 그 값(카드 프레임 = 18), 없으면 11.

> 킷 9-slice 여백은 칩·칸 **10** · 카드 **16**이다. 예전 8px 자리에 그리면 아이콘과
> 게이지가 프레임 위에 얹힌다. 세 단계 밀도(tight/normal/wide)와 글꼴·줄 수는 그대로다.

### 2.3 카드 프레임 배정

| 렌더러 | v3 프레임 |
|---|---|
| `_factory_card_button` (`3465`) | `Card.SKILL`(WOOD) / `Card.ITEM`(SLATE) · **빈칸은 `Role.CELL`** |
| `_factory_card_button(..., inner = true)` | 평면 칩 — 이미 카드 프레임 **안**에 앉는 버튼용(편집 5칸) |
| `_card_block_panel` (`3588`) | `Role.CELL` — 카드 안의 카드가 되면 프레임이 두 겹으로 읽힌다 |
| `_deal_choice_button` | `Card.SKILL` · 트로피 화면에서만 `Card.TROPHY`로 덮어쓴다 |
| `_item_choice_button` | `Card.ITEM` |
| `_rune_offer_button` · 미니 레일 · 전조 각인 | `Card.RUNE` |
| `_build_preview_slot` | 내 레일 SKILL/ITEM · 적 레일 `Card.BOSS`(accent == RED로 판정) |

**밝은 카드 위의 본문은 어두운 칩 판을 깐다.** `_build_choice_card_body`와
`_decorate_shop_offer`가 `Rect2(15,15,w−30,h−30)`에 `panel_box(SLATE, CHIP)`을 먼저 깐다.
안 깔면 WOOD(주황)·GOLD(금빛) 카드 위에서 태그 CYAN·보유 GREEN·RELOAD ORANGE가
전부 2:1 아래로 떨어진다(트로피 캡처 실측 → 수정 후 재캡처 확인).
**프레임은 카드의 정체를 말하고, 본문은 어두운 판이 받친다.**

---

## 3. 화면별 톤 배정 (§7-1 · §7-2)

| 화면 | 껍데기 | 리본 | 판단 |
|---|---|---|---|
| 레벨업 2택 | SLATE | WOOD | 필드 위 모달 |
| 아이템 2택 | SLATE | WOOD | 레벨업과 **픽셀 단위로 같은 골격** |
| 각인 드래프트 1·2 | SLATE | **ABYSS** | 껍데기까지 ABYSS면 RUNE 카드가 배경에 잠긴다 |
| 트로피 2택1 | **GOLD** | WOOD | 보상 화면. 본문은 SLATE 함몰 무대 |
| ESC 편집 · 공장 place/upgrade | SLATE | WOOD | |
| 성 NPC 대화 · 합성소 · 카드상 · 강화술사 | SLATE | WOOD | |
| 각인 세공사 · 밀정 · 전조 보상 | SLATE | **ABYSS** | 각인·마왕 소속 창구 |
| 계약자 | SLATE | **EMBER** | 대가를 치르는 창구 |
| 스테이지 보스 · 마왕 프리뷰 | **ABYSS** | EMBER | 심연 소속 |
| 결과 | **PARCHMENT** | GOLD(승) / EMBER(패) | 필드가 안 보이는 전면 화면 |

### PARCHMENT / GOLD 화면의 원칙 — "모달 안에 뚫린 필드 창"

크림빛·금빛 껍데기 위에서는 **의미색이 전부 무너진다**(관문 5색 · 과열 램프 ·
회귀 CYAN · 도약 GREEN). U1이 온보딩에서 쓴 수법을 그대로 가져왔다(handoff-u1 §2.4):

- 껍데기 위에 직접 얹는 글자는 **어두운 잉크만**(`_kit_label` + tone=PARCHMENT/GOLD).
- 숫자·데이터·의미색은 **SLATE 함몰판 / SLATE 칩** 안에서만 산다.
- 결과 화면: 타임라인 · 지표 칩 10개 · 마왕/트로피 두 줄 · 5칸 레일이 전부 SLATE 층.
- 트로피 화면: 카드 두 장이 앉는 무대(`16,108,1038,314`)가 SLATE 함몰.

---

## 4. ESC 편집 화면 — 두 조작을 킷 기하로 다시 쓴 방식

**무스크롤 5칸 · 단일 진실 원천 미리보기 · 조작 UX는 불변이다.** 바뀐 것은 오직
"지금 무엇을 집는가"를 말하는 그림이다.

| 상태 | v1 | v3 |
|---|---|---|
| 카드 이동 모드 | 칸 테두리 1px 회색 | **칸 = 그 카드의 프레임**(SKILL=WOOD 마름모 / ITEM=SLATE 상자). 안쪽 카드 버튼은 평면 칩 |
| 칸 교환 모드 | 칸 테두리 3px 자주 | **칸 전체가 RUNE 프레임(ABYSS·별)으로 뒤집힌다.** 안쪽 카드는 함몰 = "지금 집는 대상이 아니다" |
| 집은 칸 | 노란 3px 테두리 | 같은 프레임의 **SELECTED(흰 이중 립)** + 금빛 modulate |
| 빈칸 | 어두운 판 | `Role.CELL` — 카드가 아니라 **칸**이다 |
| 모드 버튼 2종 | 흰 3px 테두리 = 켜짐 | **함몰 = 켜짐 · 융기 = 꺼짐**(U1 설정 토글과 같은 언어) + check/minus 글리프 |
| 보관함·장비 영역 포커스 | 테두리 색 변경 | **흰 포커스 링 별개 층**(`_kit_focus_ring`) |
| 하단 안내 | 텍스트 한 줄 | 킷 키캡 실물 6종(TAB ← → SPACE M ESC) |

### 칸 안쪽 좌표가 바뀌었다

칸(196×150)이 **카드 프레임**(9-slice 여백 16)을 쓰므로 안쪽 가용 영역은 164×118이다.

```
const EDIT_SLOT_PAD       := 18.0                      # 신설
const EDIT_SLOT_HEADER_H  := 20.0                      # 24 → 20
const EDIT_SLOT_CARD_RECT := Rect2(18, 38, 160, 78)    # (5, 26, 186, 98)
const EDIT_SLOT_RUNE_Y    := 118.0                     # 126
```

`EDIT_CARD_SIZE` · `EDIT_RAIL_PITCH`(240) · `EDIT_RAIL_CONTENT_W`(1156) ·
`EDIT_PANEL_RECT` · `EDIT_ARC_RECT` · `EDIT_MODE_BAR_Y`는 **전부 그대로**다 —
5칸 무스크롤 증명(`42 + 1156 = 1198 ⊂ 1240`)과 `--v4-test`의 `edit_layout` 플래그가
그대로 통과한다. `_build_preview_slot`(마왕 프리뷰·결과 레일)도 같은 상수를 쓰므로
세 화면의 칸이 여전히 픽셀 단위로 같다(§8.4 "픽셀 동일한 레일 렌더러").

### 머리말이 리본에 자리를 내줬다

리본이 껍데기 y 0~30을 덮으므로 머리말은 40부터 쓴다.
세로 예산: **리본 −10~30 / 머리말 띠 40~84 / 모드바 86~126 / 아크 128~190 / 레일 192~342**.
아래 절(결속 346 · 미리보기 370 · 3열 448 · 푸터 624)은 손대지 않았다.

### 포커스는 칸 전체를 밝힌다

안쪽 칩만 밝히면 5칸 중 어디에 포커스가 있는지 캡처에서 안 보였다(칸이 프레임을
들고 있기 때문이다). `_build_edit_slot`이 버튼에 `edit_cell` meta로 칸을 매달고
`_update_factory_focus()`가 그 칸을 modulate 한다.

---

## 5. U3가 알아야 할 것

### 5.1 U2 소유 범위 (겹치지 말 것)

```
_kit_scrim / _kit_shell / _kit_card_skin / _kit_card_box / _kit_button_box
_kit_btn_variant / _kit_focus_ring / _kit_scrollbar_style
KIT_SCRIM_MODAL / KIT_SCRIM_DEEP / KIT_RIBBON_OVERHANG / KIT_RIBBON_MIN_W
CARD_BLOCK_PAD / CARD_BLOCK_PAD_FRAMED / EDIT_SLOT_PAD
EDIT_SLOT_HEADER_H / EDIT_SLOT_CARD_RECT / EDIT_SLOT_RUNE_Y
_style_button / _label(외곽선 두께) / _build_ui_theme
_paint_card_block / _card_block_panel / _factory_card_button
_build_deck_editor / _build_edit_*  전부
_show_skill_choice / _refresh_choice_highlight / _build_choice_card_body
_deal_choice_button / _item_choice_button / _show_item_offer_pair
_show_rune_draft / _build_rune_draft_screen / _rune_offer_button
_show_rune_target / _build_rune_mini_rail / _build_draft_pool_status
_open_stage_trophy_choice
_show_single_npc_service / _show_fusion_service / _show_card_shop / _decorate_shop_offer
_show_rune_shop / _show_pact_service / _show_spy_service / _show_factory_mage
_show_omen_reward / _omen_card_backdrop
_show_stage_boss_preview / _build_stage_boss_preview_header
_challenge_demon_king / _build_boss_preview_header / _build_preview_slot
_build_boss_preview_compare
_show_result / _build_result_* / _add_result_stat_chip
_show_factory_menu(place/upgrade/build 경로) / _build_factory_rail_bridge
```

### 5.2 필드 HUD는 **무접촉**이다 — 남은 `_panel_style` 12곳이 U3 몫

`_panel_style()`은 지웠으면 좋겠지만 **아직 못 지운다.** 남은 호출부는 전부
W5/V5가 확정한 필드 HUD다.

| 행 | 대상 |
|---:|---|
| 835 | 상호작용 칩(`interaction_text`) |
| 842 | 보스 HP 패널 |
| 1158 · 1229 · 1207 | 고스트 레일 슬롯 · 마왕 레일 밴드/슬롯 |
| 1488 · 1855 · 10749 | 레일 슬롯 스타일 갱신 3곳(`style_key` 캐시 경로) |
| 1595 · 1666 | 딜싸이클 레일 밴드 · 슬롯 |
| 10821 | 배너 |
| 11344 | `_hud_panel()` |

> **U3 주의:** 1488 · 1855 · 10749는 `style_key` meta로 **프레임마다 비교해 같으면
> 건너뛰는** 캐시 경로다. 킷으로 갈 때 `_panel_style` 호출을 `panel_box()`로만 바꾸면
> 캐시 키가 색 문자열이라 그대로 동작하지만, **`UIKit`이 주는 박스는 공유 인스턴스라**
> 그 자리에서 고치면 다른 화면까지 바뀐다. `UIKit.variant()`로 복제할 것.

### 5.3 다치기 쉬운 함정 4개 (내가 밟은 것들)

1. **`Object.get_meta(name, default)`는 이 Godot 빌드에서 기본값을 줘도 에러 줄을 찍는다.**
   `run_all.sh`가 `SCRIPT ERROR|^ERROR:`를 잡으므로 **테스트가 통째로 FAIL** 난다
   (기능은 멀쩡한데 `flag=true`인 채로 FAIL이 뜬다 — 원인 찾는 데 시간이 든다).
   → 반드시 `has_meta()`로 감쌀 것.

2. **GDScript에서 int를 enum으로 캐스팅할 수 없다.** `x as UIKit.Card`는 문법 오류다
   (`as`는 클래스 전용). meta에 담아 둔 카드 종류를 되꺼내 쓰려면 `_kit_card_box()` /
   `_kit_button_box()`처럼 `match`로 푸는 디스패처가 필요하다.

3. **`var x := node.get_meta(...)`는 "Variant에서 타입 추론" 경고 → 파스 에러다**
   (이 프로젝트는 warnings-as-errors). `var x: Variant = ...`로 명시할 것.

4. **`_label()`의 검은 외곽선이 킷 버튼 위에서 글자를 덩어리로 만든다.**
   융기 베벨(SLATE normal)은 윗면이 밝아서 밝은 잉크 + 3px 검은 헤일로가 검은 얼룩이
   된다(모드 버튼·장비 버튼에서 실제로 그랬다). **불투명한 킷 패널·버튼 안에서는
   `_kit_label`**(외곽선 off)을 쓸 것.

### 5.4 `_label()` 외곽선을 2/3px로 낮췄다 (전역)

ui-style-v3 §3이 지목한 그대로다. 3/4px는 11~13px 한글의 속공간을 메운다.
필드 HUD도 이 함수를 쓰므로 **필드 위 대비가 U3 검수 대상**이다 —
`--capture-hud` 낮/밤 두 컷으로 확인했고 판독에 문제없었다(캡처 첨부).

### 5.5 스포트라이트와의 접점

- 모든 모달 스크림이 `UIKit.SPOTLIGHT_INK`다. 길잡이를 모달 위에 겹쳐도 색이 안 튄다.
- 스크림 알파는 두 단이다: 필드가 비쳐야 하는 모달 **0.62**, 필드를 지우는 전면 화면
  (결과·프리뷰·트로피) **0.82**. 길잡이가 어느 위에 얹히든 `aim_spotlight(dim)`을
  0.72 근처로 두면 층이 어긋나지 않는다.
- 편집 화면에서 짚어 줄 만한 대상의 전역 사각형:
  칸 N = `EditorPanel/EditSlot{N}` · 모드 버튼 = `EditorPanel/EditMode_card|slot` ·
  보관함 = `EditorPanel/EditInventory` · 장비 = `EditorPanel/EditEquipment` ·
  미리보기 = `EditorPanel/EditPreview` · 각인 상세 = `EditorPanel/EditRuneDetail`.
  **이 노드 이름 6종은 U2가 계약으로 유지한다.** 길잡이가 이름으로 찾아도 된다.
- 흰 포커스 링(`_kit_focus_ring`)과 스포트라이트를 **한 화면에서 동시에 쓰지 말 것.**
  둘 다 "여기를 봐라"인데 그림이 달라 두 개의 초점이 생긴다.

---

## 6. 검증 결과

| 검사 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | 오류 0 · Parse Error 0 |
| `bash godot-game/scripts/test/run_all.sh` | **14/14 PASS** (compile + 기능 13종 · 86초) |
| `--v4-test` `single_focus` · `edit_layout` · `two_gesture` | PASS(무회귀) |
| `--draft-test` `stage_two` · `stack_cap` · `growth_cap` | PASS |
| `--cycle-test` `hud_rail` · `hud_ghost` | PASS(필드 HUD 무접촉 확인) |
| `--save-test` 지문 67축 | mismatch=0 |
| 캡처 `--capture-choice`(**신설** 3컷) `--capture-rail`(3컷) `--capture-draft`(3컷) `--capture-castle`(5컷) `--capture-boss`(9컷) `--capture-result` `--capture-factory` `--capture-hud` `--capture-lobby` `--capture-settings` | 육안 OK |

### 캡처 창구가 하나 늘었다 — `--capture-choice` (시각 캡처 13종 → **14종**)

사용자가 이번 웨이브에서 이름을 대고 지목한 **레벨업 UI**에 육안 검수 창구가 하나도
없었다(`--v4-test`는 포커스 모델만 본다). 아이템 2택이 같은 골격을 쓰므로 한 창구에 묶었다.

```
bash godot-game/scripts/test/run_all.sh --captures --capture-choice
  choice-minimal-v2-level.png   레벨업 2택 + 각인 강화(카드 3장)
  choice-minimal-v2-focus.png   포커스를 오른쪽으로 — 흰 이중 립이 한 장에만 걸리는가
  choice-minimal-v2-item.png    아이템 2택(ITEM 프레임 · 같은 골격)
```

`test_runner.gd` ROUTINES 1줄 + 디스패치 1줄 + `_run_choice_capture()` 신설,
`run_all.sh` `ALL_CAPTURES` 1줄. PASS/FAIL 집계에는 여전히 안 들어간다.

> 이 루틴은 `game.automated_test = false`로 시작한다. 켜져 있으면 두 화면 모두
> **왼쪽을 자동 확정하고 닫혀** 모달이 아예 안 그려진다(`_run_castle_capture`의
> 트로피 컷과 같은 규약이다). 끝에서 다시 `true`로 되돌린다.

### ui-style-v3 §12 체크리스트 자가 점검 (U2 범위)

- [x] `StyleBoxFlat.new()` 신규 **0건** — 프로젝트 전체 1건이 `_panel_style`(필드 HUD 전용)
- [x] hex 색 리터럴 신규 0건 (표면색은 `UIKit`, 의미색은 `GamePalette`)
- [x] 칩·함몰 층 글자에 `role` 전달
- [x] `heading_color`/`accent_color`는 패널 층에서만
- [x] 폰트 26/17/13/12/11 — 버튼 하드코딩 16을 `FONT_HEADING`으로 흡수
- [x] `corner_radius` 신규 0건
- [x] 9-slice 최소 크기: 카드 160×78↑ · 칩 26↑(16px 띠는 26으로 올림) · 리본 40 고정 ·
      게이지(스크롤바) 16
- [x] 새 `TextureRect` 전부 NEAREST(`_kit_glyph`/`_kit_keycap` 경유)
- [x] **`set_loops()` 프로젝트 전체 0건**
- [x] 한글 라벨에 마크다운 0건 (보스 프리뷰 안내의 `**선딜**` 잔재도 제거)
- [x] `run_all.sh` 종합 PASS
- [x] 12px 미만은 ColorRect 유지 — 각인 핍 10px · 아크 폴리라인 · 과열 히스토그램 16×27 ·
      결속 띠 4px · 광선 3~6px
- [x] 레일 5칸 폭 증명 · 상단 HUD 폭 증명 — 손대지 않음

**스테이지 1 낮 / 5 밤 대비 점검:** U2가 필드 위에 새로 얹은 요소는 **0개**다.
다만 `_label()` 외곽선을 전역으로 얇게 했으므로 `--capture-hud` 낮/밤 두 컷을 찍어
확인했다 — HUD·배너·상호작용 칩 모두 판독에 문제없다.

---

## 7. 남은 것 · 알려진 사항

1. **필드 HUD 재스킨은 U3 몫이다.** 위 §5.2의 12곳. 지금은 화면에 v1 남색 HUD와
   v3 킷 모달이 공존한다 — 의도된 분업이고, 모달이 뜨면 HUD는 스크림 아래로 간다.
2. **v1-archive 보존 누락.** U1처럼 통째 재작성한 함수는 없고 전부 제자리 수정이라
   블록 단위로 뜰 원본이 없었다. `godot-game/`이 git에 커밋된 적이 없어(`?? godot-game/`)
   되돌릴 스냅샷도 없다. 되살릴 필요가 생기면 ui-style-v3 §2의 v1 토큰 대응표
   (`UI_MODAL_BG` `UI_PANEL_BG` `UI_CHIP_BG` `UI_EDGE` `UI_EDGE_SOFT` +
   `UI_BORDER_MODAL/FRAME/CARD`)가 그대로 남아 있으므로 `_panel_style` 호출로
   기계적으로 복원할 수 있다. **다음 웨이브는 착수 전에 `git add -A && git commit`을
   한 번 할 것.**
3. **AGENTS.md §11 "시각 캡처 12종(40컷)"은 여전히 낡았다.** U1이 13종, U2가
   `--capture-choice`로 **14종**까지 늘렸다. 문서 갱신 웨이브가 14종으로 고쳐야 한다
   (U1·U2 모두 AGENTS.md 수정 금지였다).
4. **`--capture-result`는 패배 컷만 찍는다.** PARCHMENT + **GOLD 리본**(승리) 조합은
   코드로만 확인했고 캡처 육안 검수 창구가 없다. 승리 컷을 추가하면 좋다.
5. **`_edit_mode_color()`의 CYAN/MAGENTA는 남겼다.** 두 모드의 의미색이고 설명 문장 ·
   아크 라벨 · 핍 캡션이 그 색을 공유한다. 프레임에는 안 쓴다(§6 규칙).
6. **트로피 화면의 18줄 광선은 남겼다.** 트윈 없는 정지 화면 한 장이라 §11을 어기지
   않고, 다섯 관문에서 다섯 번뿐인 보상 순간의 드라마를 낼 다른 수단이 없다.
   스크림이 0.82로 짙어져 묻히길래 알파만 0.11 → 0.16으로 올렸다.
