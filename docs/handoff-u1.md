# handoff-u1 — 로비 · 캐릭터 선택 · 설정 · 온보딩 v3 재스킨

작성: U1 · 2026-08-09 · 대상: U2(모달/편집) · U3(스포트라이트 길잡이) · 다음 웨이브

사용자 요구는 한 줄이었다 — "새 필드 디자인이 마음에 들어. 그 테마로 로비 Scene·
온보딩 UI 모두 바꿔줘. 기존 UI를 새로운 센세이셔널한 UI로, 디자인 180도 변경."

바꾼 것은 **표면과 로비의 배경 자체**다. 정보 구조·화면 흐름·페이지 수·상태 문자열·
저장 스키마는 한 글자도 안 바뀌었다.

---

## 0. 30초 요약

| 화면 | v1 | v3 |
|---|---|---|
| 로비 배경 | AI 생성 야경 1장(`lobby-minimal-v2.png`) | **게임 아틀라스로 그린 필드 디오라마**(정적) |
| 로비 메뉴 | 남색 사각 패널 + 색 테두리 버튼 4개 | PARCHMENT 껍데기 + WOOD 리본 + 킷 버튼 4개 |
| 캐릭터 선택 | ◀▶ 카루셀 1장 + AI 생성 초상 | **킷 카드 3장 동시** + NA 스프라이트 실물 |
| 설정 | Godot 기본 `CheckButton` 3 + 기본 `HSlider` 2 | 킷 토글 3(함몰=켜짐) + 킷 게이지 슬라이더 2 |
| 온보딩 | 어두운 남색 전면 패널 | PARCHMENT 껍데기 + WOOD 리본 + **SLATE 무대** |

검증: `--editor --quit` 오류 0 · `run_all.sh` **14/14 PASS** · 캡처 5컷 육안 확인.

---

## 1. 로비 — 신구 구성 비교

### v1이 무엇이 문제였나

`lobby-minimal-v2.png`는 1672×941 AI 생성 야경(달·구름·먼 성·망토 두른 기사)이었다.
필드가 Ninja Adventure 픽셀 세계로 바뀐 뒤로 **로비와 게임이 서로 다른 두 게임**처럼
보였다. 게임을 시작하는 순간 어두운 유화에서 밝은 16px 잔디밭으로 떨어지는 것이
가장 큰 톤 붕괴 지점이었다.

### v3 구성

```
┌────────────────────────────────────────────────────────────────┐
│                              [잔디 · 흙길 · 덤불 · 바위]          │
│                                          🏰 성(256×176)          │
│   ╭─ WOOD 리본 「딜싸이클 용사」 ─╮        │                      │
│   │ PARCHMENT 껍데기            │        흙길                   │
│   │  5칸 딜싸이클 · 다섯 관문…   │         │  🧍 용사(32px ×2)    │
│   │  [게임 시작]      PRIMARY   │         │       📦 상자         │
│   │  [이어하기]       NEUTRAL   │        흙길                   │
│   │  ▸ 칩: 3스테이지 잿빛 벌판…  │             ⛩ 보스문(192×128) │
│   │  [설정]           NEUTRAL   │                               │
│   │  [게임 종료]      NEUTRAL   │                               │
│   │  SPACE · ENTER …            │                               │
│   ╰─────────────────────────────╯                               │
└────────────────────────────────────────────────────────────────┘
```

배경은 `class LobbyDiorama extends Control`의 `_draw()` **한 번**이다. 재료는 전부
게임이 실제로 쓰는 파일이다.

| 요소 | 파일 | 규격 |
|---|---|---|
| 지형 | `terrain-atlas-verdant.png` | 40px 타일 · `world_grid.TILE`과 동일 |
| 성 | `landmark-castle.png` | 256×176 · 밑변 기준 1:1 |
| 보스문 | `landmark-boss-gate.png` | 192×128 · 밑변 기준 1:1 |
| 나무 5 · 상자 | `landmark-tree/chest.png` | 1:1 |
| 용사 | `SurvivorPlayer.PLAYER_SHEETS["swordsman"]` | 32px 셀 · 행4(대기) 열3(오른쪽) · **정수 2배** |

세 가지 설계 판단:

1. **타일 선택은 좌표 해시**다. 난수를 쓰면 캡처가 매번 달라져 육안 회귀 검수가
   불가능하다. `_tile_hash(col, row)`가 결정적 정수를 뱉는다.
2. **가중치를 필드와 맞췄다.** 처음엔 덤불·바위를 각 8%씩 뿌렸더니 자갈밭이 됐고,
   무엇보다 필드와 밀도가 달라 "같은 세계"가 깨졌다. 지금은 잔디 76 / 풀 14 /
   꽃 4 / 덤불 4 / 바위 2로 `TILE_RULES`의 실제 비율을 따른다.
3. **용사만 정수 2배**다. 1배(필드와 완전 동일)로 구웠더니 1280×720 안에서 32px
   인물이 흙길의 얼룩처럼 보여 주인공으로 안 읽혔다. 2배면 성과의 크기 관계는
   그럴듯하게 남으면서 시선이 걸린다. **비정수 배율은 쓰지 않았다** — 픽셀 격자가
   흔들린다.

배경 스택은 `디오라마 → overlay-vignette(LINEAR) → 스크림`이다. 스크림 색은
`UIKit.SPOTLIGHT_INK`이고 알파만 화면마다 다르다 — **U3 길잡이가 그 위에 겹쳐도
색이 안 튄다.**

| 화면 | 스크림 α | 이유 |
|---|---:|---|
| 로비 | 0.20 | 필드가 주인공. 패널이 왼쪽에만 있어 얕게 깔아도 대비가 난다 |
| 캐릭터 선택 | 0.44 | 큰 모달이 앞에 선다 |
| 설정 | 0.44 | 동상 |
| 온보딩 | 0.62 | 껍데기가 화면을 거의 다 덮는다 |

### 로비에서 내린 판단 2가지

- **제목 60px → `FONT_TITLE`(26).** ui-style-v3 §3이 U1에게 넘긴 판단이다. 5단 밖
  크기를 새로 만들지 않고, 존재감은 **WOOD 리본 명판**이 낸다. 리본은 껍데기 위쪽
  가장자리에 10px 걸쳐 V홈이 밖으로 나온다(§7-3).
- **"게임 종료"는 DANGER가 아니라 NEUTRAL이다.** 먼저 EMBER로 구웠는데 §6이 경고한
  대로 WOOD(`#f38c4c`)와 EMBER(`#d14b34`)가 둘 다 주황 계열이라 "게임 시작"과 같은
  무게로 읽혔다(캡처 실측). 첫 화면에서 가장 튀는 것이 종료 버튼이면 안 되고,
  종료는 저장을 지우지 않으므로 파괴적 행동도 아니다.

### 이어하기 표기 — 정보는 유지, 자리만 이동

`_saved_run_label()`은 **한 글자도 안 건드렸다.** `--save-test`의 `lobby` 묶음이
문구를 통째로 대조하기 때문이다(`3스테이지` / `잿빛 벌판` / `11일차` / `08:32`).

버튼 라벨로는 그 30자가 `FONT_HEADING`(17)에서 400px 안에 안 들어간다. 그래서
버튼은 "이어하기"만 들고, 스테이지·일차·플레이타임은 **바로 아래 칩(계층 3)**이
받는다. 칩 본문은 신설한 `_saved_run_detail()`이 만든다(접두어 "이어하기 · "만 뺀 형태).

> **U2·U3 주의:** 이어하기 표기를 다시 만질 일이 생기면 **두 함수를 같이** 고쳐야 한다.

---

## 2. 화면별 킷 적용 내역 (톤 · 역할)

### 2.1 로비 (`_show_menu`)

| 요소 | 킷 호출 | 톤 / 역할 |
|---|---|---|
| 껍데기 | `panel_box` | PARCHMENT / PANEL |
| 헤더 | `ribbon_box(…, NOTCHED)` | WOOD |
| 게임 시작 | `style_button` | `Btn.PRIMARY` (WOOD) |
| 이어하기 · 설정 · 게임 종료 | `style_button` | `Btn.NEUTRAL` (SLATE) |
| 이어하기 표기 칩 | `panel_box` | PARCHMENT / CHIP |
| 부제 · 키 안내 | `style_label` | PARCHMENT / PANEL · muted |

### 2.2 캐릭터 선택 (`_show_character_select`)

v1의 ◀▶ 카루셀(한 번에 한 장)을 버리고 **세 장을 한 번에** 편다. 킷 카드 상태 3종이
"고를 수 있음 · 고른 것 · 잠김"과 1:1로 맞아떨어져서, 셋을 나란히 놓으면 규칙이
그림만으로 읽힌다.

| 요소 | 킷 호출 | 상태 |
|---|---|---|
| 껍데기 | `panel_box(PARCHMENT)` | — |
| 헤더 | `ribbon_box(WOOD, NOTCHED)` | — |
| 카드 프레임 | `card_box(Card.TROPHY, …)` | 검사=SELECTED(흰 이중 링) · 궁사/마법사=DISABLED(함몰) |
| 초상 칸 | `panel_box(GOLD, CELL)` | — |
| 상태 칩 | `panel_box(GOLD, CHIP)` + `glyph("check"/"key")` | — |
| 보고 있는 카드 | `focus_box()` 링 **별개 층** | — |
| 키 안내 | `keycap("left"/"right"/"enter"/"esc")` 실물 | — |
| 푸터 | `Btn.NEUTRAL`(로비로) · `Btn.PRIMARY`(시작, 오른쪽 끝) | — |

**카드 종류를 TROPHY(GOLD·왕관 문양)로 고른 이유:** "이 판을 끝까지 끌고 갈 챔피언"이
이 화면의 의미다. SKILL(WOOD)은 딜싸이클 카드 전용이고 ITEM(SLATE)은 장비 전용이라
의미가 겹친다.

**흰 링을 카드 상태와 분리한 이유:** 잠긴 캐릭터도 "지금 보고 있다"를 알려야 하는데,
그 신호를 카드 상태(=기하)에 섞으면 §6이 경고한 "약하게 선택된 카드"로 오독된다.
그래서 링은 카드 위에 얹히는 **별개 층**이고, 잠김은 언제나 함몰이다.

**초상 판단 — v1 AI 생성 원화를 버리고 NA 스프라이트로 갔다.** 스타일 일관 우선이
지시였고 실제로 그게 맞다. 다만 정직하게 적어 둔다: NA 탑다운 스프라이트는
머리가 지배적이라 "전신 초상"이 아니라 "흉상"처럼 읽힌다. 대신 **화면에서 실제로
조종할 그 그림**을 보여 주므로 기대와 실물이 어긋나지 않는다. 32px 셀을 **정수
5배(160px)**로만 키운다.

### 2.3 설정 (`_show_settings`)

| 요소 | 킷 호출 | 비고 |
|---|---|---|
| 껍데기 / 헤더 | `panel_box(PARCHMENT)` / `ribbon_box(WOOD, NOTCHED)` | |
| 줄 바닥판 | `panel_box(PARCHMENT, INSET)` | 줄과 줄이 저절로 갈린다 |
| 슬라이더 홈 | `bar_box(Bar.TRACK_DARK)` 복제본 | 여백 8 → 높이 16(§4 하한) |
| 슬라이더 채움 | `bar_box(Bar.FILL)` 복제본 + `modulate_color = GamePalette.YELLOW` | |
| 슬라이더 손잡이 | `glyph("diamond")` 아이콘 | |
| 토글 3종 | 토글 모드 `Button` + `Btn.NEUTRAL` | **함몰=켜짐 · 융기=꺼짐** |
| 토글 표식 | `glyph("check"/"cross")` | 텍스트 "켜짐/꺼짐"과 이중 표기 |
| 온보딩 다시 표시 | `Btn.QUIET` | 밝은 패널 **안**에만 둔다(§5) |
| 로비로 돌아가기 | `Btn.PRIMARY`, 오른쪽 끝 | |

**Godot 기본 `CheckButton` 3종을 토글 모드 버튼으로 바꾼 이유:** 기본 CheckButton은
둥근 스위치 + 시스템 폰트라 이 킷과 재질이 아예 달랐다. 토글 모드 버튼은 켜졌을 때
`pressed` 스타일박스(**함몰 베벨**)가 나오므로 "눌려 들어가 있다 = 켜져 있다"가
색 없이 기하로 읽힌다. 음량 % 라벨은 그대로 유지했다.

### 2.4 온보딩 (`_show_onboarding` 외)

**4페이지 · 정적 도식 · 트윈 0 원칙은 그대로다.** 이 화면은 여전히 트윈을 하나도
만들지 않는다.

```
┌─ 필드 디오라마 + 스크림 α0.62
│  ╭─ WOOD NOTCHED 리본(700×40) · 껍데기 위 12px 걸침 ─╮
│  ┌─ PARCHMENT 껍데기 (12, 18, 1256, 696) ────────────────────┐
│  │ [info 칩 「게임 안내」]      부제 한 줄       [「2 / 4」 칩] │
│  │ ┌─ SLATE 함몰 무대 (28, 84, 1200, 494) ─────────────────┐  │
│  │ │   정적 도식 (킷 CHIP/CELL 박스 + 의미색 글자·색판)      │  │
│  │ │   ── 구분선 ──                                        │  │
│  │ │   ■ 규칙 2~3줄 (FONT_HEADING)                         │  │
│  │ └───────────────────────────────────────────────────────┘  │
│  │ [◀ 이전 NEUTRAL]   [1][2][3][4] 스텝   [다음 ▶ PRIMARY]   │
│  │ [캐릭터 선택]  [✓ 오늘은 그만 보기 QUIET]     키 안내 2줄  │
│  └────────────────────────────────────────────────────────────┘
```

**무대만 SLATE로 갈랐다 — 이게 이 화면의 유일한 톤 일탈이고 의도적이다.**
도식이 나르는 색(회귀 CYAN · 도약 GREEN · 재실행 ORANGE · 과열 8단 램프 · 관문 5색)은
필드 HUD와 같은 **의미색**이라 §2에 따라 재스킨 대상이 아니다. 그런데 그 색들은
전부 어두운 배경 기준으로 고른 값이라 크림빛 parchment 위에서 대비가 무너진다.
어두운 slate 함몰판 위에 두면 필드에서 배운 색이 그대로 읽힌다 —
**무대는 "모달 안에 뚫린 필드 창"이다.**

프레임과 의미색의 역할을 갈랐다. §6이 카드 희귀도에 대해 정한 규칙과 같은 결이다.

| 예전 | 지금 |
|---|---|
| `_onboarding_box(…, bg, border_color, width)` | `_onboarding_box(…, role, tint)` — 프레임은 킷, 의미색은 안쪽 색판 |
| 색 테두리로 종류 표시 | **글자색 + 안쪽 색판**으로 표시. 테두리에 강조색 안 씀 |
| 자작 키캡(반투명 색판+테두리+텍스트) | `UIKit.keycap()` **실물 26종** |
| 바늘 `▼` 텍스트 | `UIKit.pointer("needle")` (§8이 지목한 부품) |
| 활성 레일 칸 = 3px 색 테두리 | `Role.CELL` + `focus_box()` 흰 링 (기하로 갈림) |
| 각인 3택 박스 | `card_box(Card.RUNE, SELECTED/NORMAL)` — 실전 드래프트와 같은 그림 |
| `☑ ☒` 텍스트 | `glyph("check") / glyph("cross")` |
| 페이지 스텝 = 색 3단 | `Btn.PRIMARY`(현재) / `NEUTRAL`(지나옴) / `QUIET`(남음) |
| 폰트 10·14·16·18·19·20·22 | 5단(26/17/13/12/11) 안으로 전부 스냅 |

`ONBOARDING_PANEL_RECT`의 y를 **6 → 18**로 내렸다(높이 708 → 696). 리본이 껍데기 위로
12px 걸쳐야 V홈이 밖으로 나오는데(§7-3) 껍데기가 y=6이면 걸칠 자리가 화면 밖이다.
**안쪽 좌표계는 그대로**라 4페이지 도식은 한 픽셀도 안 움직였다.

---

## 3. 온보딩 1페이지 처리 판단 (U3가 읽을 것)

**결론: 규칙 3줄 → 2줄로 줄이고, 남은 자리를 U3 길잡이 예고로 바꿨다. 키 도식은 유지.**

| 항목 | 변화 |
|---|---|
| 제목 · 부제 | 그대로 (`조작은 네 가지뿐` / `이동 · 대시 · 상호작용 · ESC 편집 화면`) |
| WASD 십자 + SHIFT/E/ESC 3줄 도식 | **유지.** 킷 키캡 실물로만 교체 |
| 규칙 ①「이동하면 가장 짧은 방향으로 돌아 공격」 | **삭제** — 필드에서 1초면 체감된다. U3가 짚어 줄 첫 항목 |
| 규칙 ②「공격 버튼은 없습니다」 | **유지** — 이 게임의 정체성이고 도식이 못 말하는 유일한 문장 |
| 규칙 ③「ESC는 언제든 열립니다」 | **삭제** — 오른쪽 ESC 도식과 같은 말 |
| 신설 | 「외울 필요는 없습니다 — 필드에 들어가면 길잡이가 하나씩 짚어 줍니다.」 |
| 신설(왼쪽 아래 칩) | 「필드에서 직접 알려 줍니다 / 첫 낮에 길잡이가 한 칸씩 짚어 준다」 |

근거: 글로 외운 조작은 어차피 필드에서 다시 배운다. U3가 스포트라이트로 실습을
전담하는 이상 1페이지가 같은 말을 세 번 하면 **온보딩이 길다는 인상만 남는다.**
지금 1페이지는 "무엇을 누르는지 훑고 → 나머지는 현장에서"로 역할이 좁아졌다.

> **U3에게:** 이 페이지가 사용자에게 **약속**을 했다. "첫 낮에 길잡이가 한 칸씩
> 짚어 준다"고 문자로 써 뒀으니, 스포트라이트가 **첫 낮에** 그리고 **하나씩**
> 나오는 순서를 지켜야 문구가 거짓말이 안 된다. 최소 이동(WASD) · 대시(SHIFT) ·
> 상호작용(E) · 편집 화면(ESC) 네 가지를 다루면 페이지와 앞뒤가 맞는다.
> 문구를 바꿀 거면 `_onboarding_pages()` 1페이지 `rules`와 `_onboarding_diagram_controls`
> 의 칩 두 줄을 같이 고칠 것.

---

## 4. 검증 결과

| 검사 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | 오류 0 · Parse Error 0 |
| `bash godot-game/scripts/test/run_all.sh` | **14/14 PASS** (compile + 기능 13종 · 79초) |
| `--save-test` `lobby` 묶음 | PASS — `_saved_run_label()` 문구 무손상 |
| `--capture-lobby` | 육안 OK |
| `--capture-character` | 육안 OK |
| `--capture-settings` (**신설**) | 육안 OK |
| `--capture-onboarding` 4페이지 | 육안 OK |

### ui-style-v3 §12 체크리스트 자가 점검

- [x] `StyleBoxFlat.new()` 신규 0건 — U1 범위에서 `_panel_style()` 호출 **0회**
- [x] hex 색 리터럴 신규 0건 (U1 범위 `Color("…")` 0건)
- [x] 칩·함몰 층 글자에 전부 `role` 전달
- [x] `heading_color`는 리본(패널 층)에서만
- [x] 폰트 26/17/13/12/11 다섯 단 — U1 범위에 `UI_*_SIZE` 참조 **0건**
- [x] `corner_radius` 0건
- [x] 9-slice 최소 크기: 칩 34↑ · 버튼 34↑ · 카드 240×96↑ · 리본 40 고정 · 게이지 16
- [x] 새 `TextureRect` 전부 NEAREST (예외: 비네트 = LINEAR, 규격대로)
- [x] `set_loops()` 신규 0건 (남은 1건은 `game.gd:3313` = **U2 몫**, §11 기지 위반)
- [x] 한글 라벨에 마크다운 0건
- [x] `run_all.sh` 종합 PASS
- [x] 12px 미만 게이지는 ColorRect 유지 (온보딩 과열 8단 17px·흐름 선 3px 그대로)
- [x] 레일 5칸 폭 증명 · 상단 HUD 폭 증명 — 손대지 않음(`--cycle-test` PASS)

**스테이지 1 낮 / 5 밤 대비 점검은 해당 없음.** U1 화면 4종은 전부
`CanvasModulate` 바깥의 전면 화면이고 로비 디오라마는 스테이지 색을 타지 않는
고정 장면이다. 필드 위에 얹히는 요소는 하나도 추가하지 않았다.

### 알려진 잔여 사항 2건 (버그 아님 · 기록용)

1. **NA 탑다운 스프라이트는 머리가 지배적**이라 캐릭터 카드가 흉상처럼 읽힌다.
   스타일 일관 우선 지시에 따른 의도적 선택이다. 뒤집으려면 초상 전용 아트를
   새로 그려야 하고, 그러면 다시 "두 게임" 문제로 돌아간다.
2. `art/generated/backgrounds/lobby-minimal-v2.png`와 `CHARACTER_CARD_TEXTURES` 3장은
   **파일로 남아 있다.** 전자는 `preload`에서 빠졌고, 후자는 상수 선언만 남고
   참조가 0건이다. 지우지 않은 이유는 v1 자료 보존이다 —
   되살릴 코드는 `docs/v1-archive/game_lobby_v3.gd.txt`에 있다.

---

## 5. U2 · U3가 알아야 할 것

### 5.1 공유 헬퍼 — 시그니처 변경 0건

U2/U3 몫 화면이 쓰는 함수는 **하나도 안 건드렸다.**

| 함수 | 상태 |
|---|---|
| `_label()` `_button()` `_style_button()` `_panel_style()` `_animate_modal()` `_hud_panel()` | **무변경** |
| `_saved_run_label()` | **무변경**(save-test 계약) |
| `scripts/ui/ui_kit.gd` | **무변경** — 버그 0건. 소비만 했다 |

`_add_lobby_background()`만 두 번째 인자 `dim`이 붙었는데 **기본값이 있어** 기존
호출 형태가 그대로 통한다.

### 5.2 새로 생긴 U1 공용 헬퍼 — 써도 된다

`game.gd`에 킷을 얇게 감싼 헬퍼 6개를 뒀다. U2·U3가 그대로 쓰면 화면끼리 안 어긋난다.

| 함수 | 하는 일 |
|---|---|
| `_kit_panel(parent, rect, tone, role)` | 킷 패널 1장. **`MOUSE_FILTER_IGNORE`가 기본**이라 안에 버튼을 놓아도 클릭이 막히지 않는다 |
| `_kit_ribbon(parent, rect, text, tone)` | 리본 명판 + 제목. 높이는 항상 40으로 강제, 제목색은 `heading_color` |
| `_kit_label(parent, rect, text, tone, size, muted, role, align)` | 킷 글자 1줄. **외곽선 off**(불투명 패널 안 전용) |
| `_kit_button(parent, rect, text, variant, size)` | 킷 버튼 1개 |
| `_kit_keycap(parent, at, key)` | 키캡 실물 72×40. 모르는 키면 텍스트 폴백 |
| `_kit_glyph(parent, at, name, tint, box)` | 글리프 1장 |

**리본은 껍데기가 아니라 껍데기의 `parent`에 붙일 것.** 껍데기 안에 넣으면 V홈이
밖으로 못 나가 리본으로 안 읽힌다.

### 5.3 다치기 쉬운 함정 3개 (내가 밟은 것들)

1. **`TextureRect`는 `expand_mode`를 먼저 주고 `size`를 나중에 준다.**
   순서가 바뀌면 그 시점 최소 크기가 텍스처 원본(글리프 32×32)이라 `size = 18`이
   **32로 되올려 고정**된다. 체크 글리프가 칩 글자를 덮는 형태로 나타났다.
   `_kit_glyph()`는 이미 올바른 순서로 짜여 있다 — 직접 만들 때만 조심하면 된다.

2. **글리프는 앞 10종(`check`~`key`)에서만 고를 것.** NA 원본 6종
   (`gem` `hourglass` `scroll` `book` `heart` `bag`)은 고유 색을 갖고 있어서
   어두운 잉크로 `modulate` 하면 **검은 덩어리**가 된다. `book`으로 구웠다가
   칩 글자를 통째로 덮었다. 선화 10종은 어느 색으로든 물든다.

3. **킷 포인터(`pointer()`)는 흰 선화가 아니다.** 셰브론은 금색, 화살표는 청록
   외곽선이라 임의의 의미색으로 `modulate` 하면 탁해진다. 흰 것은 `needle` 정도다.
   온보딩의 색 있는 흐름 화살표(회귀 CYAN / 도약 GREEN)를 텍스트 `▲▼▶`로 남긴 이유다.

### 5.4 캡처 창구가 하나 늘었다

`--capture-settings` 신설(`test_runner.gd` ROUTINES + `run_all.sh` ALL_CAPTURES).
설정 화면은 Godot 기본 위젯이 v1부터 그대로 남아 있던 마지막 자리였고, 육안 검수
창구가 없어 회귀를 캡처로 잡을 수 없었다. 컷은 토글 3종이 **켜짐 2 / 꺼짐 1**인
상태로 찍혀 함몰·융기 기하가 한 장에서 갈린다.

```
bash godot-game/scripts/test/run_all.sh --captures --capture-settings
```

시각 캡처는 **12종 → 13종**이 됐다. PASS/FAIL 집계에는 여전히 들어가지 않는다.
`AGENTS.md` §11 "시각 캡처 12종(40컷)"은 다음 문서 갱신 웨이브가 13종으로 고쳐야 한다
(U1은 AGENTS.md 수정 금지).

### 5.5 U1 소유 범위 (겹치지 말 것)

`game.gd`에서 U1이 손댄 구간은 **로비 상수 블록(22~46행 근처)과 3899~5120행**뿐이다.
그 밖의 함수는 한 줄도 안 바뀌었다. 아래는 U1 소유다.

```
LOBBY_TERRAIN_ATLAS / LOBBY_CASTLE_SPRITE / LOBBY_BOSS_GATE_SPRITE
LOBBY_TREE_SPRITE / LOBBY_CHEST_SPRITE
LOBBY_MENU_RECT / CHARACTER_SHELL_RECT / CHARACTER_CARD_SIZE
CHARACTER_CARD_GAP / SETTINGS_SHELL_RECT
class LobbyDiorama
_add_lobby_background / _kit_ribbon / _kit_panel / _kit_label / _kit_button
_kit_keycap / _kit_glyph
_show_menu / _saved_run_detail
_show_character_select / _character_portrait_texture / _select_lobby_character
_show_settings / _settings_row / _add_settings_slider / _add_settings_toggle
_onboarding_* 전부 / _build_onboarding_steps
```

`--capture-settings` 관련 `test_runner.gd` 2곳과 `run_all.sh` 1곳도 U1이 넣었다.

---

## 6. 보존

재작성 전 원본은 `docs/v1-archive/game_lobby_v3.gd.txt`(789행)에 있다.
`game.gd:3899-4681`을 그대로 뜬 것이다 — 로비 배경 · 로비 메뉴 · 캐릭터 선택 ·
설정 · 온보딩 4페이지 전체와 도식 프리미티브가 다 들어 있다.
