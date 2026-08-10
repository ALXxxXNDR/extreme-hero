# W6 인수인계 — ESC 편집 화면 v2 · 각인 드래프트 · 온보딩 v2

> 작성 2026-08-07 · 대상 웨이브: **W9**(성/NPC 각인 상점) · **W10**(마왕 프리뷰·결과) · **W11**(에셋) · **W12**(저장·밸런스)
> 기준 문서: `docs/GAME_DESIGN_V2.md` §3.3 · §5.1 · §8.2 · §8.3 · §7 W6·W6b · **부록 C-1**(본문보다 우선)
> 검증: `run_all.sh` **10종 전부 PASS**(신설 `--draft-test` 포함) · 비headless 캡처 3종 육안 검수 완료

---

## 0. 산출물

| 파일 | 판정 | 내용 |
|---|---|---|
| `scripts/game.gd` | 수정 | 편집 화면 v2 재구축 · 각인 드래프트 2단계 신설 · 레벨업 3번째 선택지 교체 · 온보딩 4페이지 교체 |
| `scripts/test/test_runner.gd` | 수정 + 신설 | `--draft-test` 신설 · `--capture-rail` / `--capture-draft` 신설 · `--v4-test`에 플래그 3개 추가 |
| `scripts/test/run_all.sh` | 수정 | `ALL_TESTS`에 `--draft-test`, `ALL_CAPTURES`에 `--capture-rail` `--capture-draft` |

**규칙 파일은 한 줄도 고치지 않았다.** `core/rune_engine.gd` · `factory_deck.gd` · `deal_cycle_controller.gd` ·
`core/combat_resolver.gd` · `core/demon_lord.gd` · `core/tuning.gd` · 라이브러리 4종 전부 무수정.
드래프트 확률 등 새 데이터는 전부 `game.gd` 상수로 넣었다(§3 참조).

**파괴적 삭제가 없어서 `docs/v1-archive/` 추가 보존은 하지 않았다.**
편집 화면의 v1 렌더러(`_build_factory_rail_slot` / `_build_factory_rail_bridge` / `_factory_rail_cell` /
`_build_factory_rail_ghost_slot`)는 **그대로 살아 있다** — 마왕 프리뷰·결과 화면(W10 소유)이 같은 함수를
쓰기 때문이다. 새 편집 화면은 별도 렌더러(`_build_edit_*`)로 나란히 얹혔다.

---

## 1. ESC 편집 화면 v2 구조

### 1.1 좌표 (1240×688 패널, 패널 로컬 · 겹침 0)

```text
┌─ EDIT_PANEL_RECT (20,16) 1240×688 ──────────────────────────────────────────┐
│ 머리말 · 상태 · 한 바퀴 RELOAD 빚                                    16~80  │
│ [카드 이동/교체] [칸 위치 교환]    지금 집는 것 = … / 집은 칸 …      86~126 │
│           ╭── 흐름 아크 + 확률 라벨 (3레인 그리디 패킹) ──╮          128~190│
│ [칸1 196×150][44][칸2][44][칸3][44][칸4][44][칸5]                   192~342 │
│ ── 결속 밴드 ──────────────────────────────────────────              346~364│
│ 예상 지표 96표본 · 6칩 · 과열 분포 9막대 · 대표 시드 궤적 3줄        370~440 │
│ [보관함 596] [각인 스택 상세 300] [장비 4부위 268]                   448~620│
│ 안내문                                            [ESC · 편집 닫기]  628~678│
└──────────────────────────────────────────────────────────────────────────────┘
```

| 요소 | 상수 |
|---|---|
| 카드 196×150 · 커넥터 44 · pitch 240 | `EDIT_CARD_SIZE` `EDIT_CONNECTOR_W` `EDIT_RAIL_PITCH` |
| 레일 콘텐츠 폭 **1,156px** (196×5 + 44×4) | `EDIT_RAIL_CONTENT_W` |
| 레일 원점 (42,192) → 좌우 여백 42px | `EDIT_RAIL_ORIGIN` |
| 흐름 아크 밴드 | `EDIT_ARC_RECT` |
| 결속 밴드 / 미리보기 / 보관함 / 각인 상세 / 장비 | `EDIT_BOND_RECT` `EDIT_PREVIEW_RECT` `EDIT_INVENTORY_RECT` `EDIT_RUNE_RECT` `EDIT_EQUIP_RECT` |

**가로 스크롤은 구조적으로 불가능하다.** 편집 레일에는 `ScrollContainer`를 **아예 만들지 않는다**
(보관함 안쪽에만 하나 있다). `--v4-test`의 `edit_layout` 플래그가 ①5칸 셀이 전부 패널 안 ②편집 패널의
직계 자식에 `ScrollContainer` 0개 ③각 셀의 `rune_count` meta == `factory.rune_count_on(i)` 를 자동 검증한다.

### 1.2 칸 하나의 구성 (196×150)

```
y   0~ 24  머리말: "칸 03" / 칸 교환 모드에서는 "⇄ 칸 03 손잡이" + 우측 "각인 4/5"
y  26~124  카드 블록 186×98 — **_paint_card_block 그대로**(전 화면 공용 렌더러 보존)
y 126~146  각인 배지: 핍 3개 + 초과 "+N" + 모드 캡션("각인 잔류" / "각인 동반")
```

- 각인 핍 색 = 희귀도(common 금 / rare 청 / epic 자주). **W5 필드 HUD의 `_rune_rarity_color`를 그대로 호출**한다.
  두 화면의 "각인이 몇 개 박혀 있나"가 다르게 보이지 않는다(handoff-w5 §6 요구).
- 툴팁(`_edit_slot_tooltip`)에 각인 스택 전체가 이름·실효 확률·효과 문장으로 들어간다.

### 1.3 두 조작 공존 (부록 C-1) — **이번 웨이브의 핵심**

`factory_edit_mode` 하나가 "지금 무엇을 집는가"의 단일 진실 원천이다.

| 모드 | 값 | 호출 API | 각인 | 색 |
|---|---|---|---|---|
| **카드 이동 / 교체** | `"card"` | `factory.move_card(a,b)` | 원래 칸에 **잔류** | CYAN |
| **칸 위치 교환** | `"slot"` | `factory.swap_slots(a,b)` | 칸을 따라 **동반 이동** | MAGENTA |

모드가 바뀌면 화면의 **다섯 곳이 동시에** 바뀐다 — 헷갈릴 수 없게 만드는 장치다.

1. 모드 바의 활성 버튼: `▣` 표시 + 3px 흰 테두리 + 배경 밝기
2. 칸 테두리: 카드 모드 = 중립 회색 1px / 칸 모드 = **자주 3px**
3. 칸 머리말: `칸 03` → `⇄ 칸 03 손잡이` (칸이 손잡이가 된다는 걸 글자로도 말한다)
4. 각인 배지 행: 카드 모드는 알파 0.7로 흐려지고 `각인 잔류` / 칸 모드는 선명 + `각인 동반`
5. 모드 바 오른쪽 설명문 + `집은 칸` 상태 줄

**마우스**: 드래그 시작 시점의 모드가 페이로드 `gesture`에 실린다.
`_on_factory_card_dropped`가 `gesture`로 갈라 `move_card` / `swap_slots`를 부른다.
gesture 키가 없는 드롭(구 테스트 경로 등)은 `"card"`로 폴백한다.

**키보드**: 2단계 집기/놓기 모델.

| 키 | 동작 |
|---|---|
| `TAB` | 레일 → 보관함 → 장비 → 레일 순환 (비어 있는 영역은 건너뛴다) |
| `← → ↑ ↓` | 영역 안 포커스 이동 (레일 포커스가 움직이면 각인 상세 패널만 다시 그린다) |
| `SPACE` | 레일: 집기 → 놓기 (같은 칸이면 취소) / 보관함: 카드 선택 / 장비: 장착·해제 |
| `M` / `1` / `2` | 조작 모드 전환 (`1`=카드 이동, `2`=칸 교환) |
| `ESC` | 집은 칸이 있으면 집기 취소, 없으면 화면 닫기 |

집은 칸은 노란 3px 테두리 + 버튼 modulate로 표시되고, 모드 바에
`칸 03 을 집었습니다 — 놓을 칸에서 SPACE (같은 칸이면 취소)`가 뜬다.

### 1.4 흐름 아크 오버레이

`class FlowArcOverlay extends Control`. 각인이 만드는 바늘 이동을 카드 위 아치로 그린다.

| 각인 | 이동량 | 색(W5 3계열 그대로) |
|---|---:|---|
| `rewind_1` / `reverse` | −1 | 회귀 CYAN |
| `rewind_2` | −2 | 회귀 CYAN |
| `skip_1` | **+2** | 도약 GREEN |
| `bookmark` | 0(고리) | 도약 GREEN |
| `repeat` / `kill_repeat` | 0(고리) | 재실행 ORANGE |
| `link_next` | +1 | 기타 YELLOW |

> `skip_1`이 +2인 이유: delta +1은 "건너뛴 칸을 실행하지 않는다"이므로 바늘이 **실제로 도착하는** 칸은 i+2다.

- **설계와의 이탈 1건**: §8.2는 `draw_arc`를 지목했지만 `draw_arc`는 **정원만** 그린다.
  60~68px 밴드에 240px 스팬(2칸 이동)을 담으려면 반지름 240이 필요해 화면 밖으로 나간다.
  같은 그림을 **납작한 아치(`draw_polyline` + 화살촉)** 로 그리고, 제자리 고리만 `draw_arc`(정원)를 쓴다.
- 확률 라벨은 실효 확률이다 — `effective_probability(merged_probability(같은 id 사본), 0.0, congestion_scale(n))`.
  (handoff-w1 §8이 지정한 툴팁 공식 그대로)
- 라벨 배치는 **x구간 그리디 패킹 3레인**. 세 레인 어디에도 자리가 없으면 **호만 그리고 라벨은 생략**한다
  (겹쳐 읽히느니 없는 게 낫다). 라벨 뒤에 어두운 칩을 깔아 아크 선이 글자를 관통해도 판독된다.
- 표시 상한 `EDIT_ARC_MAX = 6`, 확률 내림차순.
- 흐름 각인이 하나도 없으면 `흐름 각인 없음 — 바늘은 1 → 2 → 3 → 4 → 5 순서로만 흐릅니다`.

### 1.5 결속 밴드 · 각인 상세 · 장비 4부위

- **결속**: `RuneEngine.bond_mask(deck)`가 true인 칸 아래 녹색 밴드를 잇고,
  `결속 N칸 · 그 구간 각인의 과열 비용 ×0.50` / 삼각 성립 시 `삼각(1·3·5 같은 형태) RELOAD −12%`를 덧붙인다.
- **각인 스택 상세**(`_paint_edit_rune_detail`): 레일 포커스가 가리키는 칸의 각인을 이름 · 실효 확률(확정 각인은 `확정`)로
  최대 5줄. 하단에 과밀 경고 — `과밀! 이 칸의 모든 각인 확률 ×0.80`. 포커스만 움직일 때는 **이 패널만** 다시 그린다.
- **장비 4부위**: `FactoryDeck.EQUIPMENT_PARTS` 순서로 4줄. 보관함에서 아이템을 고른 상태면 패널 테두리가
  자주 2px로 켜지고 각 줄이 `선택한 아이템을 여기 장착`으로 바뀐다. 클릭하면 해제 → 보관함.
- **아이템의 레일 이탈 규칙(§5.4)이 UI에서 세 겹으로 보인다**:
  ① 보관함 아이템 카드에 `▤ 장비 전용` 배지 ② 아이템을 레일에 드롭하면 **거부 + 배너**
  (`아이템은 레일에 놓을 수 없습니다 · 오른쪽 장비 4부위로 끌어 놓으세요`) ③ 아이템 선택 시 장비 패널이 강조된다.
  `--v4-test`의 `item_rail_guard` 플래그가 "드롭해도 보관함 수가 그대로 · 칸은 여전히 빈칸"을 자동 검증한다.

---

## 2. 미리보기 — 프레임 예산 실측과 채택 방식 (**보고 항목**)

### 2.1 실측치

계측 조건: 5칸(카드 4장 + 빈칸 1) · 각인 7개(`skip_1` / `edge` / `rewind_1`+`repeat`+`heat_gate`+`chorus` / `rewind_2`),
`RuneEngine.simulate_cycle` 순수 호출, 각 표본 수당 5회 반복.

| 표본 수 | 최소 | 평균 |
|---:|---:|---:|
| 24 | 1.89 ms | 1.98 ms |
| 48 | 3.57 ms | 3.67 ms |
| 64 | 4.73 ms | 4.79 ms |
| **96 (채택)** | **6.95 ms** | **8.17 ms** |
| 200 (설계값) | 15.14 ms | 16.18 ms |
| 400 | 30.79 ms | 39.00 ms |

**설계 §8.2의 "실시간 몬테카를로 200회(1프레임 내 계산 가능)"는 실측에서 성립하지 않는다.**
200표본은 15~16 ms로 60fps 프레임 예산(16.6 ms)을 **혼자 다 먹는다**. UI 재조립까지 더하면 확실히 프레임을 흘린다.

### 2.2 채택한 방식

> **"편집이 확정될 때만 96표본 재계산"** — 매 프레임 갱신은 하지 않는다.

- 편집 화면은 모달이고 `get_tree().paused = true` 상태다. 프레임 예산의 의미는
  "카드를 놓는 순간 화면이 튀지 않는가"이며, 8 ms는 한 프레임 안에 들어온다(실기 표기 7.4~8.5 ms).
- **덱 지문 캐시**: `_factory_deck_signature()`(칸별 카드 id/랭크 + 각인 id/확률 + duration_mul + 장비 id)가
  같으면 재계산하지 않는다. 그래서 **방향키 포커스 이동·모드 전환은 0 ms**다.
- 실제 재계산 시점은 `_apply_editor_change()`(카드 이동 / 칸 교환 / 배치 / 장착·해제) 한 곳뿐이다.
- 계산 시간은 화면에 그대로 찍힌다 — `예상 지표 · 몬테카를로 96회 (7.6 ms)`. 숨기지 않는다.

### 2.3 미리보기가 보여 주는 것

`_factory_preview_summary(deck, seed, samples)` 한 번의 순회에서 전부 뽑는다.

| 항목 | 근거 |
|---|---|
| 한 바퀴 시간 | Σ`step.duration` + `reload` 평균 |
| 평균 스텝 / 평균 피해 / 평균 RELOAD / 평균 최고 과열 / 과부하율 | `simulate_cycle` 반환값 평균 |
| **최고 과열 분포** 9막대(0~8) | `peak_heat` 히스토그램, 막대 색은 `_heat_color(step)`(HUD와 같은 램프) |
| **대표 시드 궤적** 3줄 | 앞 3개 시드의 `visited` → `1→2→3→4→3→4→5` |

**W2 런타임과 같은 `RuneEngine.simulate_cycle`을 공유한다.** 자체 근사식은 한 줄도 쓰지 않았다
(handoff-w1 §3.6의 단일 진실 원천 요구).

---

## 3. 각인 드래프트 — 규칙 최종본

### 3.1 진입점 2곳

| 위치 | v1 → W2 → **W6** |
|---|---|
| 레벨업 / 보물상자 스킬 2택의 **3번째 선택지** | "레일 부품 건설" → "두 카드 포기 + 45 G" → **각인 강화 · 각인 3택 1** |
| 보물상자 `roll < 75` | 레일 부품 건설 → 45 G 환전 → **각인 상자(드래프트 진입)** |

- 3번째 버튼의 포커스 역할은 **`"cancel"` 그대로**다 — `_choice_extra_index()`(↓/↑ 단일 포커스 모델)가
  회귀 없이 유지된다. 식별용으로 `choice_kind = "rune_draft"` meta를 추가했다.
- 레벨업에서 드래프트를 고르면 **두 스킬 카드는 모두 마왕에게** 간다(기존 토스트 경로 재사용).
- 성 각인상점·균열 보상은 **W9 몫**이다. `_show_rune_draft(source, return_state)` 두 인자만 넘기면 그대로 붙는다.

### 3.2 풀 구성 · 희귀도 가중

```gdscript
RUNE_DRAFT_OPTIONS        = 3                                   # 3택
RUNE_DRAFT_RARITY_WEIGHT  = {common: 62, rare: 30, epic: 8}
RUNE_DRAFT_DAY_RARE       = 2.0     # 하루 지날 때마다 rare  가중 +2.0
RUNE_DRAFT_DAY_EPIC       = 1.2     # 하루 지날 때마다 epic  가중 +1.2
```

- 후보 24종 전부에 가중을 매기고 **비복원 가중 추출** 3회 → 같은 각인이 두 번 나오지 않는다.
- 인스턴스는 반드시 `RuneEngine.roll_rune(id, rng)`로 만든다. 확률은 저작 범위 안에서 굴려진다
  (`--draft-test`의 `offer_shape`가 `p_min ≤ p ≤ p_max`를 검증).
- 7일차 기준 가중: common 62 / rare 42 / epic 15.2 → 후반에 영웅 각인이 눈에 띄게 자주 나온다.
- 실측 분포(1,500회 추출, 1일차): **common 1,104 · rare 359 · epic 37** (약 73.6% / 23.9% / 2.5%).

### 3.3 흐름 각인 억제 (W2 §8.1 밸런스 신호 반영)

W2가 남긴 신호: *"드래프트에서 흐름 각인이 한 칸에 몰리면 과부하가 흔해진다"*(최악 덱 `overload_rate=0.4177`).

```gdscript
RUNE_DRAFT_FLOW_SATURATION = 2      # 한 칸에 흐름 계열 2개 이상 = 포화
RUNE_DRAFT_FLOW_SUPPRESS   = 0.45   # 포화 칸 1개당 흐름 계열 전체 가중 ×0.45
RUNE_DRAFT_FLOW_FLOOR      = 0.12   # 억제 하한 — 완전 배제는 하지 않는다

flow_scale = max(FLOOR, SUPPRESS ^ 포화칸수)
```

| 포화 칸 | 흐름 가중 배율 | 흐름 계열 제시 비율(실측) |
|---:|---:|---:|
| 0 | 1.00 | 27.3% (표본 28.0%) |
| 1 | 0.45 | 14.4% (표본 14.1%) |
| 2 | 0.20 | 약 7% |
| 3+ | 0.12(하한) | 약 4% |

- **완전 배제하지 않는 이유**: §3.10의 대표 아키타입 "되감기 엔진"이 성립 불가가 되면 안 된다.
  하한 0.12는 "여전히 나오지만 흔하지 않다"이다.
- 억제가 걸린 상태에서 제시된 흐름 각인에는 카드에 **`⚠ 과부하 주의 — 흐름 각인이 몰린 칸이 이미 있습니다`** 배지가 붙는다.
- 2단계 하단의 **드래프트 풀 상태** 패널이 규칙을 그대로 말한다 —
  `흐름 각인 2개 이상인 칸 1개 → 흐름 계열 제시 가중 ×0.45 (과부하 방지)`.
  숨기면 "왜 되감기가 안 나오지?"가 버그로 느껴진다.

### 3.4 2단계 — "강화할 칸을 고르세요"

미니 5칸 레일(196×300, **편집 화면과 같은 pitch 240**). 칸마다:

```
칸 03 / 카드 이름 / 원소·형태 태그 / 각인 4 / 5 / 핍 3 + "+1"
과밀 · 모든 확률 ×0.64          ← 붙였을 때의 congestion_scale(n+1)
────────────────────────────
여기 붙이면
  평균 스텝    −0.02
  평균 피해    +0.53
  평균 RELOAD  −0.07초
  최고 과열    −0.17
과부하율 0.0% → 0.0%
SPACE 부착
```

- **Δ는 짝지은 비교다.** 기준선을 `_rune_target_projection(-1, {})`로 **각 칸과 똑같은 표본 수·시드**로 먼저 잰다
  (`RUNE_TARGET_SAMPLES = 48`). 표본이 다르면 Δ가 각인 효과가 아니라 표본 노이즈를 보여 준다.
- 색 규칙: 스텝·피해·과열은 증가가 GREEN, RELOAD는 증가가 RED. |Δ| < 0.005면 회색.
- **선택 불가 조건**: `rune_count_on(i) >= RUNE_STACK_CAP(5)` 또는 `같은 id 사본 >= SAME_ID_STACK_CAP(3)`.
  버튼이 `disabled` + 회색 + `선택 불가` + `각인을 떼거나 / 다른 칸을 고르세요`. `choice_buttons`에 **등록조차 되지 않는다**.
- 화면 하단에 스택 규칙을 상시 노출: `한 칸 총 5개 · 같은 각인 3개 · 4개째부터 그 칸의 모든 확률이 ×0.80씩 깎입니다`
  (handoff-w1 §8이 "반드시 표시할 것"으로 못 박은 항목).
- **모든 칸이 상한**이면 갇히지 않게 `각인을 마왕에게 넘기고 +45 G` 탈출 버튼이 뜬다.
- `ESC`로 1단계 복귀(각인 다시 고르기). 1단계에서 `ESC`는 무동작 — 반드시 하나를 고른다.

### 3.5 미선택 각인 → 마왕 (§5.1 · §6.2)

- 부착이 성사되면 `grant_boss_rune_shards(선택하지 않은 개수 = 2)` 호출.
- `DemonLord.growth_points() = 받은 카드 수 + rune_shards` → `rune_capacity() = floor(growth/2)` 이므로
  **각인 조각 2개당 마왕 각인 1개**가 정확히 성립한다.
- `grant_boss_rune_shards`가 `sync_runes` + `_update_hud`를 부르므로 **W5의 고스트 레일이 칸 구성 변화를 관측해
  자동으로 번쩍인다**(handoff-w5 §2.6). 토스트 경로에 훅을 박지 않았다.

---

## 4. 레벨업 / 보상 화면 정비

- 3번째 버튼을 각인 드래프트로 교체(위 §3.1). 단일 포커스 모델·`choice_buttons` 구조 무변경.
- **원소·형태 태그를 두 곳에 승격**했다(§3.8 전체가 이 두 값 위에 서 있다):
  1. 선택 모달 카드 상단에 **독립 배지**(`화(炎) · 참격`, 카드 색 배경 20%). `_build_choice_card_body`에
     `badge_text` / `badge_color` 선택 인자를 추가했다 — 기존 호출부(아이템 2택)는 무변경.
  2. `_paint_card_block`의 랭크 줄이 `스킬 · R2` → **`R2 · 화 참격`**. 원소 1글자는 HUD의 `RAIL_ELEMENT_MARK`를
     그대로 쓴다(`_card_tag_compact`). 이 함수는 공용이라 **편집 레일·보관함·상점·마왕 프리뷰·결과 화면에 전부 반영**된다.
- 보유 장수(`N장 보유중 · 최고 R2`)·랭크 표시 유지. `owned_text` meta도 그대로라 `--v4-test`의 `choice_cancel` 회귀 없음.

---

## 5. 온보딩 v2 (W6b)

**트윈 0개 유지.** 정적 프리미티브(`_onboarding_box` / `_onboarding_bar` / `_onboarding_text` / `_onboarding_glyph`)만 쓴다.
골격(`_onboarding_pages()` / `_show_onboarding()` / `_build_onboarding_steps()`)은 그대로다.

| # | 제목 | 도식 | 바뀐 것 |
|---|---|---|---|
| 1 | 조작은 네 가지뿐 | WASD 십자 + SHIFT/E/ESC 3행 | ESC 설명을 `딜싸이클 공장` → **`5칸 편집 화면 · 카드 이동 / 칸 교환 · 각인 확인 · 장비 4부위`** |
| 2 | **5칸 딜싸이클 — 바늘과 과열** | **3칸 하드코딩 → 5칸**(168×104, pitch 194) + 바늘 마커 + **흐름 델타 화살표 3종** + **과열 온도계 8단** + RELOAD 박스 | 전면 재작성 |
| 3 | **각인 3택 1 — 고르지 않은 것은 마왕에게** | 분기 도식 **유지**, 내용을 카드 2택 → **각인 3택**으로. 왼쪽 = "강화할 칸을 고른다", 오른쪽 = "마왕의 각인 재료(조각 2개당 1)" | 전면 재작성 |
| 4 | **기한은 7일 — 전조를 지나 마왕에게** | 낮/밤 비율 띠 + **7일 타임라인**(3일 전조 시작 / 5일 월식 / 7일 강림) + 전조·프리뷰·강림 3칸 사슬 | 전면 재작성 |

- 2페이지의 흐름 델타 색은 **필드 HUD와 같은 3색**이다 — 회귀 CYAN / 도약 GREEN / 재실행 ORANGE.
  여기서 배운 색이 실전에서 그대로 나온다.
- 2페이지의 과열 온도계 색은 `_heat_color(step)`을 직접 호출한다(HUD와 같은 램프 함수).
- 낮/밤 길이·7일 수는 `GameTuning`에서 읽는다. 튜닝을 바꾸면 도식이 따라온다.
- **한글 라벨에 `**볼드**` 마크다운을 쓰지 말 것.** Godot `Label`은 그대로 별표를 그린다.
  이번에 4곳을 「」 로 교체했다.

---

## 6. 테스트

### 6.1 `--draft-test` (신설)

```
DRAFT_TEST_COMPLETE offer_shape=.. rarity_mix=.. attach=.. boss_shards=.. stack_cap=..
                    flow_suppress=.. entry=.. stage_two=..
                    common=N rare=N epic=N flow_base=F flow_suppressed=F
                    sample_base=F sample_suppressed=F
```

| 플래그 | 검사 내용 |
|---|---|
| `offer_shape` | 3택이 정확히 3개 · 서로 다른 실제 각인 id · 각 인스턴스 `p`가 `[p_min, p_max]` 안 |
| `rarity_mix` | 1,500회 추출에서 common > rare > epic > 0 |
| `attach` | 부착 후 `rune_count_on(2)` +1 · `total_rune_count()` +1 · 상태가 복귀 상태로 |
| `boss_shards` | 미선택 2개 → `demon_lord.rune_shards` +2 · `rune_capacity()` 비감소 |
| `stack_cap` | 상한 칸이 `disabled` + `blocked` meta true, 나머지는 false · **`choice_buttons`에 미등록** · ESC로 1단계 복귀 가능 |
| `flow_suppress` | 포화 칸 1개 생성 후 흐름 가중 비율이 기준선의 60% 미만(해석식) + 표본 비율이 75% 미만(실추출) · **0은 아님** |
| `entry` | 레벨업 3번째 버튼의 `choice_kind == "rune_draft"` · 확정 시 `rune_draft` 상태 · 단일 포커스 유지 |
| `stage_two` | 1단계 선택이 `rune_target`으로 전이하고 선택 각인이 보존됨 |

### 6.2 `--v4-test`에 추가된 플래그 3개

| 플래그 | 검사 내용 |
|---|---|
| `edit_layout` | 편집 패널 존재 · 레일 버튼 5개 · 콘텐츠 폭 ≤ 패널 폭 · 5칸 셀이 전부 패널 안 · 셀의 `rune_count` meta 일치 · **패널 직계에 `ScrollContainer` 0개** |
| `two_gesture` | 같은 드롭 경로가 `gesture:"card"`면 카드만 교환(각인 제자리), `gesture:"slot"`이면 **`FactoryDeck.swap_slots`가 각인을 데려간다** |
| `item_rail_guard` | 보관함 아이템을 레일에 드롭 → 거부. 보관함 수 불변 · 대상 칸 여전히 빈칸 |

### 6.3 결과 (2026-08-07)

| 결과 | 검사 |
|---|---|
| PASS | compile (`--editor --quit`) 오류 0 |
| PASS | world · v4(25 플래그) · v4-castle · stress · smoke · combat · deadline · cycle · **draft(8 플래그)** |

`bash godot-game/scripts/test/run_all.sh` → **종합 PASS · 51초 · 10/10**.

### 6.4 캡처 (비headless 육안 검수 완료)

| 플래그 | 파일 | 확인 |
|---|---|---|
| `--capture-rail` | `rail-minimal-v2-card.png` | [카드 이동] 모드 — 청록 · 각인 행 흐림 + `각인 잔류` · 흐름 아크 4개(도약/되감기/깊은 되감기/앙코르) 라벨 겹침 0 |
| | `rail-minimal-v2-slot.png` | [칸 위치 교환] 모드 — **자주 3px 테두리 · `⇄ 칸 0N 손잡이` · `각인 동반`** |
| | `rail-minimal-v2-pick.png` | 칸 03을 집은 상태 — 노란 테두리 + 모드 바 안내문 |
| | `rail-minimal-v2.png` | 대표 컷(카드 이동 모드) |
| `--capture-draft` | `draft-minimal-v2-p1.png` | 1단계 각인 3택 + 현재 배치 미니 레일 |
| | `draft-minimal-v2-p2.png` | 2단계 "강화할 칸을 고르세요" + 칸별 Δ + 기준선 + 스택 규칙 + 풀 상태 |
| | `draft-minimal-v2-p3.png` | 칸 05 상한 도달 → **선택 불가** 회색 처리 |
| `--capture-onboarding` | `onboarding-minimal-v2-p1~p4.png` | 4페이지 전부 · 트윈 0 · 겹침·잘림 0 |

기존 캡처 8종(`hud` `world` `factory` `boss` `result` `effects` `lobby` `character`) 회귀 없음.
`--capture-factory`는 이제 새 편집 화면을 찍는다(같은 `_show_factory_menu("edit")` 경로).

---

## 7. ⚠️ 소유권 경계 접촉 (보고 대상)

| 위치 | 소유 | 내용 | 판단 |
|---|---|---|---|
| `_open_chest`의 `roll < 75` 분기 | **W8** | 45 G 환전 → 각인 드래프트 진입 | W2 §6이 "진짜 답 = W8: 각인 상자"라고 지정했고, 지시서 §범위-2가 W6에 이 자리를 명시했다. 상자의 다른 8개 분기는 무수정 |
| `_paint_card_block` | **전 화면 공용** | 랭크 줄에 원소·형태 태그 추가 (1줄 + 말줄임 1줄) | 렌더러 구조·좌표·크기 무변경. 보스 프리뷰·결과 화면도 같은 태그가 뜨는데, 이는 §3.8을 읽히게 하는 방향이라 회귀가 아니라 개선이다. 되돌리려면 `_paint_card_block`의 `compact_tag` 3줄만 지우면 된다 |
| `_build_choice_card_body` | W6 | 선택 인자 2개 추가(`badge_text` `badge_color`) | 기본값이 빈 문자열이라 기존 호출부(아이템 2택) 동작 무변경 |

**하지 않은 것**: 성 NPC 화면(W9) · 보스전/프리뷰/결과(W10) · 필드 HUD(W5) · 전조 보상(W4) · 저장 스키마(W12) ·
`rune_engine.gd` · `factory_deck.gd` · `deal_cycle_controller.gd` · `combat_resolver.gd` · 라이브러리 4종 — 전부 무수정.
AGENTS.md 무수정. git commit 없음.

---

## 8. 남은 것 · 다음 웨이브 체크리스트

**W9 (성 · NPC)**
- `_show_rune_draft(source, return_state)` 두 인자만 넘기면 **각인 상점이 즉시 붙는다**.
  골드 차감 후 `_show_rune_draft("shop", "camp")` 형태. 복귀 상태는 `draft_return_state`가 그대로 처리한다.
- W2 §6의 안전화 목록 중 **레벨업 3번째 선택지와 보물상자 `roll<75`는 이번에 해소**됐다.
  남은 4건(강화술사 `build`/`split` 판매 제거, `upgrade_slot("split")` 항상 false, 설명 문자열)은 그대로다.
- **밀정 NPC**(마왕 각인을 훔쳐본다/지운다)는 `demon_lord.strip_rune` / `can_strip_rune`이 이미 있다.
- 칸 배율 3종(`repeat`/`duration`/`reload`)은 편집 화면 머리말에 표시되지 않는다 — 각인 상세 패널 옆에
  칸 배율 줄을 붙이고 싶으면 `_paint_edit_rune_detail`에 2줄이면 된다.

**W10 (마왕전)**
- 설계 §8.4는 "편집 화면과 **픽셀 동일한 레일 렌더러**"를 요구한다. 지금 마왕 프리뷰·결과 화면은
  **아직 v1 렌더러**(`_build_factory_rail_slot`, 카드 200×142, `ScrollContainer` 사용)를 쓴다.
  W10이 `_build_edit_slot` + `_build_edit_flow_arcs`를 읽기 전용 모드로 재사용하면 된다 —
  `_build_edit_slot`에서 버튼 연결·`factory_lane_buttons` 등록만 걷어내면 그대로 동작한다.
  (이번에 바꾸지 않은 이유: 두 화면 모두 W10 소유이고, 무수정 상태로 캡처 회귀 0을 확보하는 쪽이 안전하다.)
- 마왕 5칸에도 `_edit_flow_entries` 계열을 쓰려면 `factory` 대신 `boss_factory`를 받도록 인자 1개만 열면 된다.

**W11 (에셋)**
- 편집 화면에서 그림을 만지는 곳은 `_paint_card_block`의 `PixelSkillIcon` 하나뿐이다.
- 각인 아이콘 24종이 들어오면 붙일 자리: ①칸의 각인 핍 3개(`_build_edit_rune_pips`, 10×10 → 아이콘 16×16)
  ②각인 상세 패널의 줄머리 핍 ③드래프트 카드 상단(현재 색 바 3px 자리) ④2단계 미니 칸의 핍.
  전부 `ColorRect` → `TextureRect` 교체 한 줄이다.

**W12 (저장 · 밸런스)**
- **새로 저장할 상태는 없다.** `factory_edit_mode` / `factory_pick_slot` / `factory_preview`는 전부 UI 전용이다.
  각인은 이미 `factory.slots[i].runes`에 있고 schema 2가 저장한다.
- 밸런스 손잡이는 `game.gd`의 `RUNE_DRAFT_*` 6상수 + `EDIT_PREVIEW_SAMPLES` 하나다.
  `--draft-test`의 `common/rare/epic` 카운트와 `flow_base/flow_suppressed`가 조정 후 즉시 관측점이 된다.
- W2 §8.1의 `overload_rate` 신호는 이제 **편집 화면에 상시 표시**된다(과부하율 칩 + 과열 분포 막대).
  플레이테스트에서 이 숫자가 20%를 넘는 덱이 흔하면 `RUNE_DRAFT_FLOW_SUPPRESS`를 0.45 → 0.30으로 내리는 것이 첫 손잡이다.

---

## 9. 알아 둘 함정

1. **미리보기는 `_apply_editor_change()`에서만 재계산된다.** 다른 곳에서 덱을 바꾸고 화면만 다시 그리면
   지문 캐시가 옛 값을 돌려준다. 덱을 바꾸는 새 경로를 만들면 `_refresh_factory_preview(true)`를 부를 것.
2. **`factory.rune_deck()`의 `runes`는 참조다**(handoff-w2 §2.2). 가상 부착을 시뮬레이션할 때
   `_rune_target_projection`처럼 **칸 딕셔너리를 깊은 복사**하지 않으면 실제 덱이 오염된다.
3. **드래그 페이로드의 `gesture`가 두 조작을 가른다.** 새 드래그 원본을 만들 때 `gesture` 키를 빠뜨리면
   조용히 `move_card`로 폴백한다(칸 교환이 안 되는데 에러도 안 난다).
4. **편집 화면은 재조립될 때 등장 연출을 주지 않는다.** `factory_editor_open` 플래그가 그 방어선이다.
   지우면 방향키 한 번마다 패널이 슬라이드 인 한다.
5. **한글 라벨에 마크다운을 쓰지 말 것.** `**칸**`이 그대로 별표로 그려진다.
6. **레일 포커스 이동은 화면 전체를 다시 그리지 않는다.** `_update_factory_focus()`가
   `_paint_edit_rune_detail()`만 다시 그린다. 여기에 무거운 계산을 넣으면 방향키가 끊긴다.
7. `_build_factory_inventory()`는 이제 호출부가 없다(편집 모드가 `_build_edit_inventory`를 쓴다).
   v1 레일을 쓰는 화면이 보관함을 다시 필요로 할 수 있어 **지우지 않았다**.
8. **1단계에서 ESC는 무동작**이다. 반드시 하나를 고른다(스킬 2택과 같은 규칙). 2단계 ESC는 1단계로 되돌린다.
