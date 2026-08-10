# handoff-y3 — 각인 UI 3종 + 밀정 (`game.gd` 직렬 체인 2/6)

2026-08-10 · 웨이브 **Y3** · 근거 `docs/FEEDBACK_Y.md` §8 ②③⑨⑩⑪ · §9.3 Y3 ·
`docs/handoff-y1.md` §9-B · `docs/handoff-y2.md` §8-A · `docs/handoff-ya.md` §5

수정 파일 3개 — `scripts/game.gd` · `scripts/test/test_runner.gd` · `docs/handoff-y3.md`(이 문서)
(`run_all.sh`는 **손대지 않았다** — 목록·판정 규약이 그대로 맞았다)

**한 줄도 안 건드린 것**: `core/rune_engine.gd` · `core/tuning.gd` · `core/status_engine.gd` ·
`core/demon_lord.gd` · `core/combat_resolver.gd` · `deal_card_library.gd` · `monster_library.gd` ·
`factory_deck.gd` · `boss_library.gd` · `deal_cycle_controller.gd` · `cycle_skill_effect.gd` ·
`enemy.gd` · `player.gd` · `world_grid.gd` · `castle_interior.gd` · `ui/ui_kit.gd` ·
`skill_icon.gd` · `pixel_portrait.gd` · `chest_open_effect.gd` · `test/rune_test.gd` ·
`test/data_test.gd` · `test/status_test.gd` · `test/balance_probe.gd` · `art/` 전부 · `AGENTS.md`.
git 커밋 0건. 파괴적 재작성 전 원본 보존은 **불필요**했다 — 지운 것이 파일이 아니라
한 파일 안의 함수 3개뿐이고 그 이력은 아래 §2~§5에 전부 적혀 있다.

---

## 0. 한 문장

**각인을 만지는 화면 네 개에서 글자를 지우고 그림을 세웠다 — 부착 2단계의 40줄이 0줄이 되어
전부 호버로 내려갔고(정보 손실 0), 편집 화면의 색 사각 핍이 각인 그림 기호가 됐고,
세공사는 하단 4버튼을 「닫기」 하나로 줄이고 칸/레일 배지를 크게 달았고,
밀정은 열람이 공짜가 되면서 마왕의 5칸을 내 딜싸이클과 같은 그림으로 보여 준다.
`run_all.sh` 15/15 PASS · 음성 대조 9건 전부 정확히 그 플래그만 문다.**

---

## 1. 검증 결과 (전부 이 웨이브가 직접 실행)

| 검사 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | **오류 0 · 종료 코드 0** |
| `bash godot-game/scripts/test/run_all.sh` | **15 / 15 PASS**(compile 포함 16행 전부 PASS · 84초) |
| 음성 대조 9건 | **9 / 9** 정확히 그 플래그만 빨개짐 · 부수 피해 0(§7) |
| `--capture-castle` `--capture-draft` `--capture-rail` (비headless 17컷) | 육안 확인 · 지문 고유 **16 / 17**(§8) |

### 1.1 `run_all.sh` 15종 현황표

| 검사 | 이전(Y2 직후) | **지금** | 비고 |
|---|---|---|---|
| compile | PASS | **PASS** | |
| `--world-test` | PASS | **PASS** | 무접촉 |
| `--v4-test` | PASS | **PASS** | `edit_minimal`에 각인 글리프 3묶음 신설(§6.1) |
| `--castle-test` | PASS | **PASS** | 세공사 3묶음 · 밀정 **전면 재작성**(§6.2) |
| `--rift-test` | PASS | **PASS** | 무접촉 |
| `--stress-test` | PASS | **PASS** | 무접촉 |
| `--smoke-test` | PASS | **PASS** | 무접촉 |
| `--combat-test` | PASS | **PASS** | 무접촉 |
| `--stage-test` | PASS | **PASS** | 무접촉 |
| `--status-test` | PASS | **PASS** | 무접촉 |
| `--cycle-test` | PASS | **PASS** | 무접촉 |
| `--draft-test` | PASS | **PASS** | `stage_two` **전면 재작성** + 계측 2축 신설(§6.3) |
| `--boss-test` | PASS | **PASS** | 무접촉(마왕 프리뷰의 `spy_revealed` 분기 소멸만 흡수) |
| `--save-test` | PASS | **PASS** | 지문 축 `spy` 의미 교체 · `axes=68 mismatch=0` 유지 |
| `--guide-test` | PASS | **PASS** | 무접촉 |

**남은 실패 0건.** 내 범위 밖 실패도 0건이다.

### 1.2 계측값

```
V4_TEST_COMPLETE   … edit_minimal=true  edit_labels=9 edit_prose=0
DRAFT_TEST_COMPLETE … stage_two=true    target_labels=8 target_prose=1~2 slot_labels=5 slot_prose=0
CASTLE_TEST_COMPLETE … rune_shop=true spy_remove=true price_scale=true stage5_price=151
SAVE_TEST_COMPLETE  … schema=3 keys=48 axes=68 mismatch=0
```

- `edit_labels` 7 → **9**. 글리프 교체가 만든 라벨은 **0개**다(글리프는 `TextureRect`다).
  늘어난 둘은 **테스트가 새로 심은 각인 덱** 때문이다 — 과밀 칸의 「+1」 표기와
  흐름 각인이 생기면서 붙는 아크 표기. 상한 계약 `≤ 16` · 문장 `0`은 그대로다.
- **`slot_labels=5 slot_prose=0`이 이번 웨이브의 핵심 숫자다.** 구 2단계는 칸 하나마다
  여덟 줄을 세워 5칸에서 **40줄**이었다. 지금 칸 안에 남은 글자는 **카드 이름 하나씩**뿐이고
  설명 문장은 **0줄**이다(번호·원소 마크는 한 글자라 세지 않는다).
- 패널 전체로는 `target_labels=8`(손에 든 각인 2 + 칸 이름 5 + 조작 힌트 1).
  20자 이상은 **둘까지** 허용한다(`target_prose=1~2`) — 조작 힌트 한 줄과
  손에 든 각인의 효과 한 문장이고, 후자는 각인마다 길이가 달라 판마다 1~2로 흔들린다.
  둘 다 **패널의 줄이라 5칸에 곱해지지 않는다**는 것이 계약의 핵심이다.

---

## 2. (피드백 ②) 부착 2단계 전면 재작성 — 40줄 → 0줄

`_show_rune_target()` · `_build_rune_target_rail()` · `_rune_target_slot_tooltip()` ·
`_rune_target_held_tooltip()` (`game.gd`).

### 2.1 무엇이 사라졌나

| 구 화면 요소 | 어디로 갔나 |
|---|---|
| 칸당 「각인 N / 5」 | 칸 툴팁 `body` |
| 칸당 상태 한 줄(가득/같은 각인 상한/과밀 ×N) | 칸 툴팁 「붙이면」 행 · 화면에는 **함몰 베벨 + × 기호** |
| 칸당 「여기 붙이면」 머리말 | 삭제(툴팁 제목이 대신한다) |
| 칸당 Δ 4줄(평균 스텝·피해·RELOAD·밟은 칸) | 칸 툴팁 4행 |
| 칸당 「과부하율 A% → B%」 | 칸 툴팁 「바퀴 상한 도달」 행(**어휘도 교체** — §5.3) |
| 칸당 「SPACE 부착」 | 화면 아래 조작 힌트 한 줄로 통합 |
| 패널 「현재 기준선 …」 1줄 | 손에 든 각인 툴팁 「지금 기준선」 행 |
| 패널 「스택 규칙 …」 1줄 | 손에 든 각인 툴팁 「한 칸 상한」·「과밀」 2행 |
| 패널 「드래프트 풀 상태」 상자 3줄(`_build_draft_pool_status`) | 손에 든 각인 툴팁 「흐름 억제」·「마왕의 각인」 2행 · **함수 삭제** |
| 제목 「각인 드래프트 · 2 / 2 단계」 + 「강화할 칸을 고르세요」 2줄 | 리본 한 줄 **「어느 칸에 붙일까요?」** |

**정보 손실 0**이 계약이고 `--draft-test`가 그것을 문다(§6.3).

### 2.2 기하 — 편집 화면과 **픽셀 단위로 같은 칸**

```
폐기: RUNE_TARGET_SLOT_SIZE (196 × 300)
신설: RUNE_TARGET_PANEL_RECT  Rect2(40, 150, 1200, 420)
      RUNE_TARGET_RAIL_ORIGIN Vector2(42, 116)
사용: EDIT_SLOT_SIZE(196×204) · EDIT_RAIL_PITCH(240) · EDIT_CONNECTOR_W(44)
      EDIT_SLOT_HANDLE_RECT(14,14,168,28) · EDIT_SLOT_BODY_RECT(14,46,168,112)
      EDIT_SLOT_METER_Y(162) · EDIT_SLOT_PIP_Y(174) · EDIT_SLOT_ICON(80)
```

칸 하나가 편집 화면과 **같은 상수를 읽는다** — 손잡이 띠(번호 + 원소 마크) ·
카드 몸통(아이콘 80px + 이름) · 지속/RELOAD 막대 두 개 · 각인 글리프 줄.
칸 사이 선과 `▶`도 `_build_edit_rail`과 같은 그림이다.

> ⚠️ **읽기 전용 레일(`EDIT_CARD_SIZE` 계열)과는 다른 상수다**(FEEDBACK_Y 리스크 ⑨).
> 그쪽은 마왕 프리뷰·결과 화면이 공유하므로 합치면 두 화면이 같이 늘어난다.
> Y3은 **편집 전용 `EDIT_SLOT_*`만** 재사용했고 `EDIT_CARD_SIZE`는 한 값도 안 바꿨다.

### 2.3 `_build_rune_mini_rail()` 삭제 — 죽은 분기 정리(handoff-y2 §8-A)

이 함수는 `interactive` 인자로 두 화면을 겸했다. 2단계가 전면 재작성되면서
`interactive=true` 절반이 통째로 죽었고, 남은 절반(1단계의 읽기 전용 문맥 레일)은
**이미 게임에 있는 공용 렌더러 `_build_preview_slot()`이 하는 일과 같았다.**

→ 함수를 지우고 1단계는 `_build_preview_slot(panel, factory, i, Vector2(22, 418), CYAN, true)`
5회 호출로 바꿨다. 자리(22, 418)와 크기(196×150)가 구판과 **같아서 화면은 안 움직인다.**
덤으로 1단계 문맥 레일 · 마왕 프리뷰 · 결과 화면이 이제 **한 그림**이다.

---

## 3. (피드백 ③) ESC 편집의 각인 글리프

### 3.1 칸 각인 — `_build_edit_rune_pips()`

색 사각 핍 3개 → **각인 그림 기호 12×12 3개.** 빈 자리는 그대로 유령 사각형이다
(그림이 없어야 "비었다"가 즉시 읽힌다). **위치 `EDIT_SLOT_PIP_Y` 174 · 간격 14 ·
`+N` 규칙은 한 픽셀도 안 바뀌었다.**

### 3.2 레일 각인 — `_build_edit_bond_band()`

Y2가 `EDIT_BOND_RECT` 자리에 깔아 둔 22×8 색 칩 3개도 같은 **12×12 그림 기호**로 갈았다.
칸 각인과 레일 각인이 이제 **자리로만** 갈린다(칸 안 / 레일 아래).
간격 30 → 18(글리프 폭에 맞춤) · 되돌이 선(`EDIT_LOOP_RECT` y 356)과 겹치지 않게
342~354 안에서 끝난다.

### 3.3 ⚠️ 글리프 시트 — **설계와 다르게 갔다 (에셋 미납)**

§2.5는 전용 시트 `art/v2/ui-kit-rune.png`(16px × 15칸 5×3)를 예고했는데
**YA가 굽지 않았다** — `docs/handoff-ya.md` §1 산출물 15장에 그 시트가 없다.
새 시트를 굽는 것은 에셋 웨이브 몫이고 Y3은 `scripts/`만 소유하므로,
**이미 있는 두 시트에서 15종을 겹치지 않게 배정**했다.

```gdscript
# game.gd — const RUNE_GLYPH: id -> [시트, 이름]
칸  twice→glyph/plus · back_one→pointer/pointer_left · jump_one→pointer/double_right
    strong→pointer/chevron_up · wide→pointer/ellipsis · quick→glyph/hourglass
    first_hit→pointer/caret · twin_cast→pointer/double_left
    trade_skip→pointer/pointer_right · finisher→glyph/cross
레일 rail_fast→pointer/chevron_right · rail_power→glyph/star · rail_rest→glyph/minus
    rail_color→glyph/gem · rail_loop→pointer/chevron_left
```

- 흐름 각인은 **방향 시트**(`POINTER_INDEX`), 강화·조건 각인은 **상징 시트**(`GLYPH_INDEX`).
  두 시트가 그대로 "바늘을 움직이는가 / 칸을 세게 하는가"의 두 계열이 된다.
- **`UIKit.GLYPH_INDEX`를 한 줄도 고치지 않았다**(§2.5 명시 함정). 읽기만 한다.
- 유일성은 데이터가 아니라 **이 표**에 걸리므로 `--v4-test`가 표를 직접 문다(§6.1 ⓗ).
- 미지 id(폐기 각인이 저장에서 되살아난 경우)는 `pointer/bullet` 하나로 떨어진다.

> **후속 웨이브(YA 또는 YZ)가 전용 시트를 구우면** `RUNE_GLYPH`의 값만 갈아끼우면 된다 —
> `_rune_glyph()` 호출부 4곳은 그대로다. 지금 배정이 임시라는 뜻이 아니라,
> **전용 시트가 없어도 15종이 서로 다른 그림으로 읽힌다**는 뜻이다.

---

## 4. (피드백 ⑨⑩) 각인 세공사 — 한 창구는 한 가지만 판다

| 항목 | 구 | **신** |
|---|---|---|
| 하단 버튼 | 새로고침 · 합성 · 칸 배율 · 나가기 **4개** | **「공방을 나선다」 하나** |
| 새로고침 | 하단 4열 첫 칸 | **진열대 자리**(카드 위 · 왼쪽 위) |
| 「카드 합성」 | 세공사 | **카드상으로 이사** |
| 「칸 배율 강화」 | 세공사 | **카드상으로 이사** |
| 보유 골드 | 「보유 999 G · 각인 7개」 작은 칩 | **코인 + 「999 G」** 큰 칩 하나(병기 삭제) |
| 소속 표기 | 계열 옆 작은 글자 「레일 각인 · 템포…」 | **글리프 + 큰 글자 배지**(칸=하늘 / 레일=자주) |
| 흐름 경고 | 「**과부하** 주의 — 흐름 각인이 몰린 칸이 있습니다」 | 「흐름 각인이 몰린 칸이 있습니다」(금지 어휘 제거) |

- 「카드 합성」·「칸 배율 강화」가 간 곳은 **카드상**(`_show_card_shop`)이다. 근거:
  둘 다 각인이 아니라 **덱을 만지는 골드 거래**다. 성 NPC 4종 구성(`castle_interior.gd`)은
  **한 줄도 안 바꿨다** — 두 화면은 원래도 NPC가 아니라 다른 화면에서 열리는 하위 창구였다.
  카드상 하단이 4열(260 + 240 + 260 + 240 + 간격 24×3 = 1,072 ⊂ 1,156)이 됐다.
- 카드 세로 배치가 배지 34px만큼 밀렸다: 소속 배지 92~126 · 확률 132~164 ·
  효과 170~228 · 보유 234~252 · 흐름 경고 256~282(카드 292).

### 4.1 레일 할증 배선 (handoff-y2 §8-A · 설계 §2.6)

```gdscript
# _rune_offer_price()
if RuneEngine.rune_scope(rune_id) == "rail":
    base *= GameTuning.RUNE_SHOP_RAIL_PREMIUM      # 1.20
```

Y1이 상수를 넣어 뒀지만 **소비자가 0이었다.** Y2가 "가격 판단은 Y3 소유"라고 남긴 항이다.
`--castle-test`가 **같은 희귀도 · 확정 · 비흐름** 탐침 둘(`strong` vs `rail_fast`)로
다른 항을 전부 같게 만들고 이 한 항만 잰다(§6.2 ⓑ').

> ⚠️ **정규 사다리 총액이 오른다.** 설계 §2.6이 "레일 할증으로 약 +6% · 재측정 대상"이라고
> 적어 둔 그 값이다. **Y8이 `balance_probe`로 재측정할 것.** 1스테이지 실측
> `stage5_price=151`(기준가 45의 5스테이지 값)은 무변화다 — 할증은 레일 각인에만 붙는다.

---

## 5. (피드백 ⑪) 밀정 리뉴얼

| 항목 | 구 | **신** |
|---|---|---|
| 열람 | `SPY_REVEAL_COST 35 G` · `spy_revealed` 플래그 | **무료 · 기본 공개**(상수·플래그·`_spy_reveal()` 삭제) |
| 5칸 표시 | 글자 5줄(`칸 01  카드명  각인 …`) | **`_build_preview_slot` 5칸** + 흐름 아크 + ABYSS 무대 창 |
| 초상 | 없음 | **`art/v2/portrait-demon-lord-96.png`** 96×96 `TextureRect` |
| 지우기 대상 | 각인이 **가장 많은 칸의 마지막 1개**(결정적) | **각인이 있는 칸 중 무작위 1칸을 통째로** |
| 지우기 값 | 85 G | **120 G**(`SPY_WIPE_COST`) |
| 지우기 횟수 | 무제한(골드만 있으면) | **스테이지당 1회**(`spy_wipe_stage`) |
| 버튼 | 훔쳐보기 · 지우기 · 닫기 3개 | 지우기 · 닫기 **2개** |

### 5.1 상태·저장 키 교체

```
삭제: var spy_revealed: bool     · const SPY_REVEAL_COST · const SPY_REMOVE_COST
      func spy_reveal_cost()     · func spy_remove_cost() · func _spy_reveal()
      func _spy_remove_rune()
신설: var spy_wipe_stage: int    · const SPY_WIPE_COST(120)
      func spy_wipe_cost()       · func spy_wipe_available() · func _spy_wipe_slot()
      func _build_spy_preview_deck()
저장: "spy_revealed"(bool) → "spy_wipe_stage"(int)   ← schema는 **3 그대로**
```

`spy_wipe_stage`는 "마지막으로 지우기를 쓴 스테이지 번호"다(0 = 미사용).
스테이지가 넘어가면 값이 달라지므로 **자동으로 다시 열린다** — 별도 리셋 코드가 없다.
옛 스냅샷은 키가 없어 0으로 떨어지고 그것이 곧 "아직 안 씀"이라 하위 호환이 성립한다.
**schema 4는 Y6가 다른 신설 키들과 함께 올린다**(handoff-y2 §6과 같은 판단).

### 5.2 `_build_spy_preview_deck()` — 런의 난수열을 건드리지 않는다

`_build_boss_factory()`와 같은 조립이지만 **`rng`가 아니라 고정 씨앗
(`run_cycle_seed + 5701`)의 지역 RNG**를 쓴다. 화면을 여닫을 때마다 `roll_rune()`이
런의 난수열을 흘려보내면 같은 런이 다르게 굴러간다. 씨앗이 고정이라 같은 상태에서
몇 번을 열어도 같은 확률이 보인다.

### 5.3 마왕 프리뷰의 `spy_revealed` 분기 소멸

`_build_boss_preview_rails()`가 각인 이름을 **항상** 연다(구 `reveal_runes=spy_revealed`).
「· 밀정 열람」 꼬리표도 사라졌다 — 살 것이 없으므로 표시할 것도 없다.

---

## 6. 테스트 재작성

### 6.1 `--v4-test` `edit_minimal` — 각인 글리프 3묶음 신설

| 묶음 | 무엇을 재나 |
|---|---|
| ⓖ | 칸마다 **붙은 수만큼 `TextureRect`**(글리프) + 나머지 `ColorRect`(유령) · 합이 `RUNE_SLOTS_PER_SLOT` |
| ⓗ | **15종이 서로 다른 그림**을 쓴다(`RUNE_GLYPH` 표의 `[시트, 이름]` 쌍이 전부 고유) |
| ⓘ | 레일 각인 줄도 같은 그림 언어(`EditRailRune{i}`가 붙은 자리면 `TextureRect`, 빈 자리면 `ColorRect`) |

> ⚠️ **음성 대조가 잡아낸 공허한 통과.** ⓖ와 기존 ⓔ(툴팁 줄 수 ≥ 각인 수)는
> **각인이 하나도 없으면 `0 == 0` / `0 >= 0`으로 그냥 통과한다.** 실제로 글리프 코드를
> 통째로 지워도 `edit_minimal=true`였다. 편집 화면을 열기 직전에 **칸 각인 7개
> (슬롯 3은 4개 = 과밀 `+N` 경로) + 레일 각인 2개**를 심어 두고 재도록 고쳤다.
> **다른 검사에 "개수를 세는" 단언을 넣을 때 같은 함정을 확인할 것.**

### 6.2 `--castle-test` — 세공사 2묶음 + 밀정 전면 재작성

세공사에 더한 것:
- **ⓑ' 레일 할증** — 같은 희귀도 · 확정 · 비흐름 탐침 둘로 항 하나만 격리해 잰다.
- **ⓑ'' 버튼 구성** — 패널이 든 `Button`이 `RUNE_SHOP_OFFER_COUNT + 2`개(진열 3 + 새로고침 + 닫기)이고
  `RuneShopReroll` · `RuneShopClose` 두 노드가 실재한다.

밀정은 통째로 새로 썼다 — ⓐ 여는 데 골드 0 · ⓑ `PreviewSlot` 5칸 + 「미열람」 문자열 0건 ·
ⓒ `SpyPortrait` 실재 · ⓓ **정확히 한 칸이 0이 되고 나머지 칸은 안 움직인다** ·
ⓔ 두 번째 호출은 골드·각인 무변화 · ⓕ 스테이지가 넘어가면 다시 열린다.

> ⚠️ **잠복 함정 하나를 같이 잡았다(이번 웨이브가 실제로 밟았다).**
> 세공사 진열 3장이 **전부 레일 각인**일 수 있다(레일 5종 중 3종을 아직 안 가졌으면 성립).
> 구 검사는 `buy_index`가 0으로 남아 레일 각인을 사 버렸고, 레일은 2단계가 없으므로
> `state == "rune_target"`이 깨지면서 **뒤따르는 계약 검사(`pact_buy_day`)까지 연쇄로
> 빨개졌다** — 각인이 안 붙어 "탐욕"이 낼 대가가 없어지기 때문이다.
> 시드가 고정이 아니라 **몇 판에 한 번만** 나타난다. 칸 각인이 들 때까지 골드 없이
> 진열만 다시 까는 루프(`_ensure_rune_shop_offers(true)` 최대 16회)를 넣었다.
> Y2가 `_first_slot_offer_index()`·`_open_slot_rune_draft()`를 만든 이유가 이것이고,
> **castle 쪽 한 군데가 그 헬퍼를 안 쓰고 있었다.**
> 밀정 검사도 같은 이유로 마왕 카드를 6장 → 24장으로 늘렸다 —
> 카드가 6장이면 마왕 각인이 **1개**뿐이라 한 칸을 비우면 각인이 0개가 되어
> ⓕ("다음 스테이지에 다시 열린다")를 아예 잴 수 없었다.

### 6.3 `--draft-test` `stage_two` 전면 재작성 + 계측 2축

```
DRAFT_TEST_COMPLETE … stage_two=true target_labels=8 target_prose=1 …
```

| 축 | 계약 |
|---|---|
| **칸 안 글자** | 5칸 버튼 안의 2자 이상 Label ≤ **7**(이름 5 + 과밀 여유 2) · **14자 이상 0개** ← 40줄 → 0줄의 직접 단언 |
| 패널 글자 | `RuneTargetPanel` 안의 2자 이상 Label ≤ **12** · 20자 이상 ≤ **2**(조작 힌트 + 각인 효과) |
| 기하 | `draft_slot_buttons` 5개 전부 크기 == `EDIT_SLOT_SIZE`(196×204) |
| 툴팁 | `target_slot{0..4}` 5개 + `held` 1개가 등록 · 칸 툴팁 줄 수 ≥ 그 칸 각인 수 |
| 배선 | `_force_modal_tooltip("target_slot0")`이 실제로 뜬다(사람 호버와 같은 경로) |

기존 `cap_ok`(상한 칸 비활성 · `blocked` meta · `choice_buttons` 제외)는 **무변경으로 통과**한다 —
새 렌더러가 `draft_slot_buttons`·`slot_index`·`blocked` 계약을 그대로 지킨다.

### 6.4 `--save-test` 지문 축 의미 교체

`"spy": game.spy_revealed`(bool) → `"spy": game.spy_wipe_stage`(int).
스냅샷 키 목록도 `"spy_revealed"` → `"spy_wipe_stage"`.
`axes=68 mismatch=0`은 그대로다(축 수는 안 늘었다 — handoff-y2 §9-10의 지적 그대로
축 개수를 계약으로 쓰지 말 것).

---

## 7. 음성 대조 9건 (새 단언이 실제로 무는가)

되돌린 곳은 전부 `game.gd` 한 곳씩이고, 잰 뒤 즉시 원복했다.

| # | 되돌린 것 | 빨개진 플래그 | 부수 피해 |
|---|---|---|---|
| 1 | 칸 각인 글리프 → 색 핍 복귀 | `--v4-test edit_minimal=false` | 없음 |
| 2 | 레일 각인 글리프 → 색 칩 복귀 | `--v4-test edit_minimal=false` | 없음 |
| 3 | 글리프 유일성 깨기(`rail_power` → `plus`) | `--v4-test edit_minimal=false` | 없음 |
| 4 | 2단계 칸 툴팁 제거 | `--draft-test stage_two=false` | 없음 |
| 5 | 2단계에 설명 문장 4줄 복귀 | `--draft-test stage_two=false` | 없음 |
| 6 | 레일 할증 항 제거 | `--castle-test rune_shop=false` | 없음(`spy_remove=true`) |
| 7 | 세공사 하단 버튼 부활 | `--castle-test rune_shop=false` | 없음(`spy_remove=true`) |
| 8 | 밀정 지우기 = 각인 1개만 | `--castle-test spy_remove=false` | 없음(`rune_shop=true`) |
| 9 | 밀정 열람 재유료화(「미열람」 표시) | `--castle-test spy_remove=false` | 없음(`rune_shop=true`) |

**#1은 처음에 `true`가 나왔다** — 그게 §6.1의 "공허한 통과"를 발견한 경로다.
각인을 심어 두고 다시 재서 `false`를 확인했다. **음성 대조를 안 돌렸으면 그 구멍은
초록색으로 남았을 것이다.**

---

## 8. 캡처 검수 — 그리고 리스크 ⑧이 실제로 터졌다

### 8.1 밟은 함정: 17컷 중 고유 지문이 **5장**이었다

FEEDBACK_Y 리스크 ⑧("`--capture-*` 컷이 프레임을 흘린다 · macOS 비headless")이
이번에 정면으로 터졌다. 첫 실행에서 `castle` 7컷 중 6컷, `draft` 5컷 전부,
`rail` 5컷 중 4컷이 **서로 완전히 같은 파일**이었다 — 각 루틴의 첫 컷 이후
뷰포트 텍스처가 갱신되지 않았다.

원인 둘을 다 제거했다.

1. **떠 있던 다른 Godot 인스턴스**(`godot --path godot-game`, 3시간 전 시작 · 이전 웨이브의
   실창 관찰 잔여로 보인다)를 종료했다.
2. `_save_capture_png()`와 대표 컷 저장 두 곳에 **`RenderingServer.force_draw()`**를 넣었다.
   창 포커스 상태와 무관하게 "지금 화면"이 남는다.

결과 **17컷 중 고유 16장.** 남은 중복 1쌍은 `rail-minimal-v2.png`(대표 컷) ==
`rail-x2-overview.png`로, **의도된 것**이다 — `_run_rail_capture()`의 꼬리가 편집 화면을
컷 1과 같은 기본 상태로 되돌린 뒤 대표 컷을 찍는다고 그 함수 주석이 명시한다.
(`force_draw()` 전에는 대표 컷이 **마지막 컷**과 같았다 — 한 상태 뒤처져 있었다는 증거다.)

> **다음 웨이브에게**: `run_all.sh --captures` 뒤에
> `shasum art/screenshots/qa/*.png | awk '{print $1}' | sort -u | wc -l`을 **매번** 세라.
> 컷 수와 다르면 그림을 보기 전에 원인부터 잡아라. `force_draw()`가 들어갔으니
> 이제는 "다른 Godot 창이 떠 있는가"만 보면 된다.

### 8.2 육안 검수 결과

| 컷 | 확인한 것 |
|---|---|
| `draft-minimal-v2-p2.png` | **2단계에 글자가 8줄뿐이다.** 리본 한 줄 + 손에 든 각인 띠 + 5칸 그림 + 조작 힌트. 칸 사이 `▶`·손잡이 번호·원소 마크·각인 글리프가 편집 화면과 같은 자리에 있다 |
| `draft-y3-tip-slot.png` | 걷어낸 여덟 줄이 **툴팁 한 장에 전부** 있다(각인 목록 · 붙이면 · Δ 4 · 바퀴 상한 · 각인 N/5). Δ 부호 색이 맞다 — 「평균 RELOAD −0.11초」가 초록, 「평균 스텝 −0.19」가 빨강 |
| `draft-minimal-v2-p3.png` | 상한 칸이 **함몰 베벨 + × 기호**로 갈린다(문장 2줄 소멸) · 지속/RELOAD 막대 두 개가 편집 화면과 같은 자리(162)에 있다 |
| `castle-minimal-v2-rune-shop.png` | 하단 버튼 **하나** · 새로고침이 진열대 위 · 「999 G」가 오른쪽 위에 크게 · 카드마다 「칸 각인」 배지 |
| `castle-minimal-v2-spy.png` | 마왕 초상 · 5칸이 **내 딜싸이클과 같은 그림** · 각인 이름이 처음부터 보인다 · 버튼 두 개(「칸 하나를 통째로 지운다 · 120 G」 / 닫기) |
| `rail-x2-overview.png` | 칸마다 각인 **그림 기호** 줄 · 과밀 칸의 「+1」 · 레일 아래 레일 각인 글리프 줄 |
| 나머지 11컷 | 회귀 없음(온보딩·계약자·트로피·편집 호버 2종 등) |

**남은 육안 지적 1건(범위 밖)**: 편집 화면·2단계 칸 손잡이의 원소 마크가 아직
**한자 「화 빙 뇌 유」**다. `RAIL_ELEMENT_MARK` 교체는 **Y4**다(handoff-y1 §9-C).

---

## 9. 후속 웨이브 수정 목록 (이번에 고치지 않은 것)

### A. Y4 — 색·어휘·아이콘 (전부 무접촉)

- `game.gd` `ELEMENT_COLOR` → `fire e2452f` · `oil 7a5230` · `_factory_card_color()` 폴백
- `RAIL_ELEMENT_MARK` 한자 7자 → `불얼번독기타정` — **Y3이 새로 만든 두 화면
  (2단계 칸 손잡이 · 밀정)도 이 상수를 읽으므로 함께 낫는다.** 별도 작업 0.
- `skill_icon.gd GENERATED_SKILL_INDEX` → 실루엣 인덱스
- **골드 칩 헬퍼 `_gold_chip()`(§8 ⑯)** — Y3은 일부러 만들지 않았다. 세공사·밀정의
  「코인 글리프 + 큰 숫자」 조합이 **그 헬퍼가 될 모양 그대로**다. Y4가 승격할 때
  `_show_rune_shop()`의 `money_rect` 블록과 `_show_spy_service()`의 `purse_rect` 블록을
  같이 걷어 가면 된다(두 곳 다 4줄짜리 같은 코드다).
- YA 에셋 중 **아직 미배선**: `ui-coin-{small,large,spin,pile}.png` · `chest-open.png` ·
  `ui-slot-silhouettes.png` · `ui-slot-badges.png` · `vfx-*` 3종 ·
  `boss-demon-king-v2.png`(`enemy.gd` 한 줄) · `portrait-demon-lord-48.png`(토스트).
  Y3이 배선한 것은 **`portrait-demon-lord-96.png` 하나**(밀정 상단)뿐이다.

### B. YA 또는 YZ — 각인 글리프 전용 시트

`art/v2/ui-kit-rune.png`(16px × 15칸 5×3 ×2)가 **아직 없다**(§3.3).
구우면 `game.gd`의 `const RUNE_GLYPH` 값만 갈아끼우면 되고 `_rune_glyph()` 호출부
4곳(`_build_edit_rune_pips` · `_build_edit_bond_band` · `_build_rune_target_rail` ·
2단계 손에 든 각인 띠)은 무변경이다. **`UIKit.GLYPH_INDEX`는 그때도 건드리지 말 것.**

### C. Y6 — 저장 schema 4

Y3이 키 하나를 **교체**했다(`spy_revealed` → `spy_wipe_stage`). schema는 3 그대로다.
Y6가 4로 올릴 때 이 키는 이미 있으므로 새로 만들 필요가 없고,
`--save-test`의 `spy` 지문 축도 그대로 쓴다.

### D. Y8 — 밸런스

- **`RUNE_SHOP_RAIL_PREMIUM`(1.20)이 이번에 살아났다.** 설계 §2.6이 예고한
  "정규 사다리 총액 약 +6%"가 실제로 생겼다 — `balance_probe`의 가격 프로브를 재측정할 것.
- **밀정 경제가 통째로 바뀌었다**: 열람 35 G 수입 소멸 + 지우기 85 → 120 G +
  스테이지당 1회 상한. 런 전체 골드 지출 곡선과 "마왕 성장 밸브"의 세기가 함께 움직인다.
  구판은 골드만 있으면 각인을 무한히 뜯을 수 있었다 — **상한이 생긴 쪽이 더 크다.**

### E. YZ — 한글 스윕

Y3이 자기 화면에서 걷어낸 금지 어휘 4건(아래 표) 외에 `game.gd`에 남은 것은
**주석뿐**이다(사용자 노출 문자열 0건 — `grep "과열\|과부하\|잔열\|열기"`로 전수 확인).

> ⚠️ **오탐 하나를 미리 적어 둔다.** `game.gd:8710`의 「보물상자 **열기**」는 금지 어휘
> 「열기(구 `heat_gate` 각인)」가 아니라 **동사 「열다」**다. 그 줄은 건드리지 말 것.

| 고친 문자열 | 구 | 신 |
|---|---|---|
| 세공사·드래프트 카드 배지 | 「**과부하** 주의 — 흐름 각인이 몰린 칸이 있습니다」 | 「흐름 각인이 몰린 칸이 있습니다」 |
| 마왕 프리뷰 대조표 열 이름 | 「**과부하**율」 | 「바퀴 상한」 |
| 필드 HUD 스트립 툴팁 상태 | 「**과부하**」 | 「바퀴 상한」 |
| 각인 계열 이름(`RUNE_FAMILY_NAME`) | 「조건 · **칸이 서로를 본다**」(의인화 금지어) | 「조건 · 상황을 보고 세진다」 |

### F. 소유자가 없어 남은 잔재 (Y2 §8-E 그대로)

`scripts/boss_library.gd:412`의 `"uses_heat": false`. Y3 소유 파일이 아니라 두었다.

---

## 10. 밟은 함정 · 다음 웨이브가 알아야 할 것

1. **개수를 세는 단언은 "0개일 때 공허하게 통과"한다.** 각인 글리프를 통째로 지워도
   `--v4-test`가 초록이었다(§6.1). 새 단언을 넣을 때는 **음성 대조를 반드시 돌리고**,
   0이 나올 수 있는 축이면 테스트가 먼저 값을 심어라.
2. **세공사 진열 3장이 전부 레일 각인일 수 있다.** 그러면 "칸 각인을 산다" 경로가
   통째로 안 돌고 **뒤따르는 다른 묶음까지 연쇄로 빨개진다**(§6.2). 각인을 사거나 고르는
   검사는 반드시 `_first_slot_offer_index()` / `_open_slot_rune_draft()`를 쓸 것.
   `--capture-draft`도 같은 이유로 고쳤다 — 안 고치면 2단계 컷이 1단계를 다시 찍는다.
3. **`--capture-*`는 `force_draw()` 없이는 프레임을 흘린다**(§8.1). 그리고 다른 Godot 창이
   떠 있으면 더 잘 흘린다. 캡처 전에 `ps aux | grep godot`으로 잔여 인스턴스를 확인할 것.
4. **모달 툴팁 층은 반드시 마지막에 붙인다.** `_bind_modal_tooltips()`를 카드·버튼보다
   먼저 부르면 툴팁이 그 아래로 깔려 안 보인다(UIKit §6의 규약 그대로).
   층은 `overlay`의 자식이라 `_clear_overlay()`가 같이 죽인다 — 정리 코드 0줄이지만,
   **닫힌 뒤 참조는 `null`이 아니라 무효**라 `is_instance_valid()`로 걸러야 한다.
5. **밀정 화면이 `rng`를 흘리면 안 된다.** 마왕 덱을 조립하려면 `roll_rune()`이 필요한데
   런의 `rng`를 쓰면 화면을 여닫을 때마다 난수열이 밀린다. 고정 씨앗 지역 RNG를 쓴다(§5.2).
6. **`demon_lord.strip_rune()`은 그 칸이 비면 아무 칸에서나 하나를 뜯는 폴백이 있다.**
   "칸 하나를 통째로" 지우려면 **미리 센 개수만큼만** 돌아야 다른 칸을 안 건드린다.
7. **`sync_runes()`는 칸을 비운 뒤에도 안전하다.** `rune_count()`가
   `capacity − stripped.size()`라 뜯은 만큼 목표치도 같이 내려간다 — 지운 각인이
   다음 프레임에 되살아나지 않는다(실제로 확인했다).
8. **`_build_preview_slot()`은 이제 소비자가 5곳이다**(마왕 프리뷰 · 스테이지 보스 프리뷰 ·
   결과 화면 · **각인 드래프트 1단계** · **밀정**). `EDIT_CARD_SIZE` 계열 5상수를 만지면
   다섯 화면이 같이 움직인다. FEEDBACK_Y 리스크 ⑨의 경고가 이제 더 무거워졌다.
9. **`_build_edit_flow_arcs()`도 소비자가 4곳이 됐다**(편집 · 마왕 프리뷰 ×2 · 밀정).
   시그니처는 안 바꿨다. 밀정은 `minimal=false`로 부른다 — 아크 이름표가 있어야
   "마왕 레일에 어떤 흐름 각인이 있나"가 읽히기 때문이고, 흐름 각인이 없으면
   「흐름 각인 없음 — 바늘은 1 → 2 → 3 → 4 → 5 순서로만 흐릅니다」 한 줄이 뜬다(의도).
10. **`RUNE_TARGET_SLOT_SIZE`는 사라졌다.** 그 이름을 다시 쓰지 말고 `EDIT_SLOT_SIZE`를 읽어라.
    2단계 패널도 `RUNE_DRAFT_PANEL_RECT`가 아니라 **`RUNE_TARGET_PANEL_RECT`**를 쓴다
    (1단계는 632px, 2단계는 420px — 두 화면의 높이가 갈렸다).

---

## 11. 이 웨이브가 하지 않은 것

- `game.gd` Y4~Y7 구역 전부(색·어휘·아이콘 · 필드 생태 · 발견/이벤트 · 타격감)
- YA 에셋 배선 중 Y3 소유가 아닌 12건(§9-A) · 각인 글리프 전용 시트 제작(§9-B)
- 저장 schema 4(Y6) · `balance_probe.gd` 재작성과 가격 재측정(Y8)
- 온보딩·한글 전수 스윕(YZ) · `docs/FEEDBACK_Y.md` 자체 수정
- **`AGENTS.md` §1 체크포인트 갱신** — 이번 웨이브는 `AGENTS.md` 수정이 **금지**됐다.
  §9.1의 "매 웨이브 끝에 체크포인트 갱신" 규약과 어긋나므로 **오케스트레이터가
  Y3 완료를 그 블록에 반영해야 한다.** 반영할 내용은 이 문서 §0 · §1.1 · §1.2다.
