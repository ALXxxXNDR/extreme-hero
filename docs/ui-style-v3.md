# UI 스타일 가이드 v3 — Ninja Adventure 재스킨

작성: U0 · 대상: U1(로비/온보딩) · U2(모달/편집) · U3(스포트라이트 길잡이)

v3 필드는 Ninja Adventure 스프라이트 세계다. UI는 아직 v1 시절의 도형+어두운 남색
패널이라 같은 화면에 두면 두 게임처럼 보인다. 이 문서는 UI를 필드와 **같은 팔레트·
같은 픽셀 밀도**로 옮기기 위한 규격이다. U1~U3는 이 문서만 보고 작업해도 서로
어긋나지 않아야 한다.

**정보 구조는 하나도 바꾸지 않는다.** `docs/handoff-w5.md`의 HUD 좌표 계약, 5칸
무스크롤, 타이포 5단, 화면 흐름은 그대로다. 바뀌는 것은 **표면**뿐이다.

---

## 0. 30초 요약 (이것만 지켜도 어긋나지 않는다)

| 지켜야 할 것 | 값 |
|---|---|
| 픽셀 밀도 | UI 원본 1px = 화면 **2px**. 필드 스프라이트(16px×2)와 같다 |
| 패널 9-slice 여백 | **10** (전 톤·전 역할 공통) |
| 카드 9-slice 여백 | **16** |
| 리본 9-slice 여백 | **18** (좌우 16) · **높이 40 고정** |
| 색 | `UIKit.text_color()` 계열에서만 가져온다. 직접 hex 금지 |
| 스타일박스 | `UIKit.panel_box()` / `button_box()` / `card_box()` / `ribbon_box()`에서만. `StyleBoxFlat.new()` 금지 |
| 폰트 크기 | 26 / 17 / 13 / 12 / 11 다섯 단 밖은 쓰지 않는다 |
| 모서리 둥글기 | 스타일박스에 `corner_radius`를 주지 않는다(그림에 이미 들어 있다) |
| 애니메이션 | **트윈 루프 금지. 1회성 전환만 허용** |
| 필터 | 전 노드 `TEXTURE_FILTER_NEAREST`. 예외는 스포트라이트 마스크 2장(LINEAR) |

산출물은 `godot-game/art/v2/ui-kit-*.png` 10장, 빌더는
`godot-game/art/v2/build_assets_ui.gd`, 헬퍼는 `godot-game/scripts/ui/ui_kit.gd`.

```
godot --headless --path godot-game --script res://art/v2/build_assets_ui.gd
godot --headless --path godot-game --editor --quit
```

---

## 1. 시트 목록과 격자

전부 원본 16px 격자에서 그리고 **마지막에 한 번만 ×2**로 올렸다(스포트라이트 2장만 ×1).
아래 표의 픽셀값은 전부 **구운 뒤** 값이다.

| 파일 | 크기 | 셀 | 격자 | 9-slice 여백 | 내용 |
|---|---|---|---|---|---|
| `ui-kit-panels.png` | 224×160 | 32×32 | 7열(톤) × 5행(역할) | **10** | 패널·함몰·칩·슬롯칸·포커스링 |
| `ui-kit-buttons.png` | 128×128 | 32×32 | 4열(변종) × 4행(상태) | **10** | normal/hover/pressed/disabled |
| `ui-kit-cards.png` | 240×144 | 48×48 | 5열(종류) × 3행(상태) | **16** | 스킬·아이템·각인·트로피·보스 |
| `ui-kit-ribbon.png` | 336×80 | 48×40 | 7열(톤) × 2행(모양) | L16 T18 R16 B18 | 헤더 명판 / V홈 리본 |
| `ui-kit-keycaps.png` | 360×240 | 72×40 | 5열 × 6행 | — (스프라이트) | 키보드 24 + 마우스 2 = **26종** |
| `ui-kit-pointers.png` | 256×64 | 32×32 | 8열 × 2행 | — (스프라이트) | 화살표·바늘·캐럿·닫기 |
| `ui-kit-glyphs.png` | 256×64 | 32×32 | 8열 × 2행 | — (스프라이트) | 체크·경고·정보·동전·열쇠… |
| `ui-kit-bars.png` | 64×16 | 16×16 | 4열 | **4** | 게이지 트랙 2 + 채움 2 |
| `ui-kit-spotlight-rect.png` | 96×96 (×1) | — | — | **32** | 사각 구멍 소프트 마스크 |
| `ui-kit-spotlight-oval.png` | 256×256 (×1) | — | — | — | 원형 구멍 소프트 마스크 |

**여백은 이 세 숫자가 전부다: 패널 10 · 카드 16 · 스포트라이트 32.**
(리본 18과 게이지 4는 각각 하나뿐이라 헬퍼가 알아서 넣는다.)

### 픽셀 밀도 — 정확히 말하면 UI 2.0 : 필드 2.5

정직하게 적어 둔다. 필드는 NA 16px 원본을 ×2로 구워 32px 셀로 만든 뒤 **40px
타일에 그린다**(`world_grid.TILE = 40`). 그래서 필드의 원본 아트 픽셀 1개는
화면 **2.5px**이고, 2.5는 정수가 아니라 실제로는 2px과 3px이 섞여 나온다
(`art/external/INVENTORY.md` §7-3이 이미 지적한 그대로다).

UI는 정수 배율을 지킬 수 있는 유일한 층이라 **정확히 ×2**로 굽고 1:1로 그린다.
따라서 UI 아트 픽셀은 2.0px, 필드는 2.5px — **1.25배 차이가 남는다.**
2.5로 맞추려면 UI를 비정수 배율로 늘려야 하고, 그러면 UI 격자가 필드처럼
울퉁불퉁해진다. 둘 중 하나를 고르는 문제이고, **UI는 반듯한 쪽을 택했다.**
캡처로 보면 둘 다 "두툼한 픽셀"로 읽히고, UI 쪽이 약간 굵어서 오히려 패널이
앞으로 나와 보인다. 이 결정을 뒤집으려면 지형을 32px 타일로 옮기는 게 먼저다.

### 왜 여백이 통일돼 있나

원본 16×16을 바깥에서 안으로 "고리(ring)"로 나누고 고리마다 색을 준다.
어느 역할이든 고리 5개까지만 쓰고 나머지 6×6이 균일한 중앙이 되게 짰다.
그래서 `panel`도 `chip`도 `focus`도 여백이 똑같이 5(원본) = 10(구운 뒤)이다.
U1~U3가 시트마다 여백을 찾아볼 일이 없다.

모서리는 45° 마이터로 **상 > 하 > 좌 > 우** 우선순위를 준다. 위가 항상 이기므로
"빛은 위에서 온다"가 7개 톤 전부에서 흔들리지 않는다.

---

## 2. 팔레트 — 톤 7종

색은 전부 NA `art/external/ninja-adventure/Palette.png`(10×9 · 52색)와
`Ui/Theme/Theme Wood`에서만 골랐다. 톤 하나는 **7슬롯 램프**다.

| 슬롯 | 역할 |
|---|---|
| `outline` | 1px 바깥 테두리 — 전 톤 공통 `#141b1b` |
| `hi` | 윗면 하이라이트 |
| `mid` | 좌·우 측면 |
| `lo` | 아랫면 그림자 |
| `edge` | 안쪽 오목선 |
| `shade` | well 안쪽 좌·상 그림자 |
| `fill` | well 바탕 |

| 톤 | hi | mid | lo | edge | shade | fill | 언제 쓰나 |
|---|---|---|---|---|---|---|---|
| `PARCHMENT` | `ffe18d` | `eecf9b` | `c8966b` | `965340` | `d2b37d` | `fce2ca` | **필드가 안 보이는 전면 화면**의 본문 — 로비·온보딩·결과·도감 |
| `GOLD` | `ffe18d` | `f1c471` | `d78b4a` | `965340` | `d2b37d` | `ffcb8d` | 트로피·보상·등급·황금 강조 |
| `WOOD` | `ffad5d` | `f06733` | `9b513c` | `46402e` | `a3754e` | `f38c4c` | 기본 헤더 리본 · 주 버튼(primary) |
| `VERDANT` | `adbc3a` | `a8a129` | `56864c` | `345a52` | `56864c` | `74a334` | 획득·성공·치유·긍정 |
| `SLATE` | `abc2bc` | `8d977f` | `5f7160` | `141b1b` | `2d697b` | `345a52` | **필드 위에 얹히는 것 전부** — HUD 패널·레일 밴드·배너·보조 버튼 |
| `ABYSS` | `d3a2c0` | `a5608b` | `8f3e56` | `141b1b` | `543c52` | `3b3643` | 마왕·5스테이지·고스트 레일·잠식·페널티 |
| `EMBER` | `ff9554` | `e46d3a` | `8f3e56` | `543c52` | `9c6546` | `d14b34` | 위험·보스·과부하·파기 확인 |

파생색 3종은 **계산으로만** 만든다(색 결정 지점을 7개 램프로 묶어 두려는 것).

```
fill_hi = fill.lightened(0.14)          # 안쪽 베벨의 밝은 쪽
well    = fill.lerp(edge, 0.42)         # 함몰 패널 바탕 (배경 계층 2단)
well2   = fill.lerp(edge, 0.68)         # 칩·트랙 바탕   (배경 계층 3단)
hover    : outline 제외 전 슬롯 lightened(0.16)
pressed  : outline 제외 전 슬롯 darkened(0.14) + 베벨을 함몰로 뒤집는다
disabled : outline 제외 전 슬롯 HSV(sat×0.20, val×0.74)
```

> `well`을 `darkened()`로 만들지 않은 이유: `darkened`는 검정으로 끌고 가서
> parchment의 크림빛이 갈색 진흙이 된다. `edge` 쪽으로 lerp하면 3단 배경 계층
> 내내 톤의 색상 성격이 유지된다.

### 필드 5단 톤과의 관계

`tuning.gd`의 `STAGE_DAY_MODULATE` 사다리와 UI 톤 사다리를 붙여 놓았다.

| 스테이지 | 지형 아틀라스 | 낮 modulate | 이 스테이지에서 HUD가 쓰는 톤 |
|---:|---|---|---|
| 1 왕국 변경 | `verdant` | `#ffffff` | `SLATE` |
| 2 시든 숲 | `verdant` | `#e3ddc8` | `SLATE` |
| 3 잿빛 벌판 | `waste` | `#d9c3a3` | `SLATE` |
| 4 역병의 늪 | `waste` | `#b8b48c` | `SLATE` |
| 5 심연 | `abyss` | `#8a7794` | `SLATE`(+ 보스/마왕 요소만 `ABYSS`) |

**HUD 톤은 스테이지에 따라 바꾸지 않는다.** 필드는 5단으로 어두워지지만 HUD가
같이 어두워지면 5스테이지에서 정보가 안 읽힌다. `SLATE`(`#345a52` 바탕 + `#f2eaf1`
글자 + 검은 외곽선 3px)는 `#ffffff` 낮과 `#2f2f52` 밤 양쪽에서 대비를 유지하도록
고른 값이다. 스테이지 색은 **UI가 아니라 필드가 표현한다.**

단, `ABYSS` 톤은 5스테이지 지형(`b3957f` 바탕 + 자주 물)과 같은 계열이라
마왕·잠식 같은 "심연 소속" 요소에만 쓴다. 5스테이지에서 HUD 전체를 `ABYSS`로
갈면 UI가 배경에 잠긴다.

킷은 `CanvasModulate` **바깥**에 있으므로 5스테이지에서 밝은 parchment 패널은
자주빛 필드 위에 완전히 채도를 유지한 채 얹힌다 — 별개의 층으로 딱 떨어져 보인다.
**의도한 것이다.** 모달은 필드가 아니라 필드 위의 물건이고, 5스테이지에서까지
읽혀야 한다. 그래도 결합이 필요하면 UI 루트를 스테이지 색으로 곱하지 말고
`Color.WHITE.lerp(STAGE_DAY_MODULATE[i], 0.25)` 정도로 **약하게만** 물릴 것 —
원본 세기로 물리면 5스테이지에서 글자가 사라진다(v3가 비네트에서 이미 겪었다).

### 기존 GamePalette와의 대응

의미색(`_rail_kind_color`, `_rune_rarity_color`, `_heat_color`)은 **바꾸지 않는다.**
정보를 나르는 색이라 재스킨 대상이 아니다. 아래는 표면색만의 대응표다.

| 기존 토큰 (`game.gd`) | 값 | 대체 |
|---|---|---|
| `UI_MODAL_BG` | `#111826` | `UIKit.panel_box(tone, Role.PANEL)` |
| `UI_PANEL_BG` | `#0c1320` | `UIKit.panel_box(tone, Role.INSET)` |
| `UI_CHIP_BG` | `#0a111c` | `UIKit.panel_box(tone, Role.CHIP)` |
| `UI_EDGE` | `#48546b` | 프레임 그림에 포함 — 별도 테두리 색 없음 |
| `UI_EDGE_SOFT` | `#2c3648` | 동상 |
| `UI_BORDER_MODAL/FRAME/CARD` | 2 / 1 / 2 | 전부 9-slice 여백 10(카드 16)으로 흡수 |
| `UI_BORDER_FOCUS` (흰 2px) | 2 | `UIKit.focus_box()` (흰 링, 여백 10) |
| `GamePalette.TEXT` | `#fff3d0` | `UIKit.text_color(tone)` |
| `GamePalette.MUTED` | `#b6af9b` | `UIKit.muted_color(tone)` |
| 3px 액센트 바 | — | 리본으로 대체. 그래도 필요하면 `UIKit.accent_color(tone)` |

---

## 3. 글자

### 크기 5단 (바꾸지 않는다)

| `UIKit` 상수 | px | 기존 토큰 | 쓰임 |
|---|---:|---|---|
| `FONT_TITLE` | 26 | `UI_TITLE_SIZE` | 모달 제목 · 리본 |
| `FONT_HEADING` | 17 | `UI_HEADING_SIZE` | 절 제목 · 버튼 |
| `FONT_BODY` | 13 | `UI_BODY_SIZE` | 본문 |
| `FONT_LABEL` | 12 | `UI_LABEL_SIZE` | 라벨 |
| `FONT_CAPTION` | 11 | `UI_CAPTION_SIZE` | 캡션 · 칩 |

> 로비 제목만 60px(`_show_menu`)이라 5단 밖이다. 재스킨 때 `FONT_TITLE`로 내리고
> 리본을 키워서 존재감을 내는 쪽이 이 킷에 맞는다. **판단은 U1 몫.**
> 새로 5단 밖 크기를 만들지는 말 것.
>
> NA `Ui/Font/`는 라틴 전용이라 **한글이 없다.** 폰트는 기존 것을 그대로 쓴다.
> 이 킷은 프레임과 색만 바꾼다.

### 색과 외곽선

`UIKit.style_label(label, tone, size, muted, outline, role)` 한 줄이면 전부 들어간다.

**잉크는 두 개뿐이다** — `INK_DARK #141b1b` / `INK_LIGHT #f2eaf1`. 어느 쪽을 쓰는지는
톤이 아니라 **(톤, 역할) 쌍**이 정한다. 밝은 톤이라도 칩 층에서는 바탕이 중간
갈색이 되어 어두운 잉크가 무너지기 때문이다(wood 칩 `#7d5837` 위 `#141b1b`는
2.76:1, 흰 잉크로 뒤집으면 5.36:1). `text_on(tone, role)`이 알아서 고른다.

| 톤 | PANEL | INSET | CHIP | CELL |
|---|---|---|---|---|
| PARCHMENT | 어두움 | 어두움 | 어두움 | 어두움 |
| GOLD | 어두움 | 어두움 | 어두움 | 어두움 |
| WOOD | 어두움 | 어두움 | **밝음** | 어두움 |
| VERDANT | 어두움 | 어두움 | **밝음** | 어두움 |
| SLATE | 밝음 | 밝음 | 밝음 | 밝음 |
| ABYSS | 밝음 | 밝음 | 밝음 | 밝음 |
| EMBER | 어두움 | **밝음** | **밝음** | 어두움 |

부가 글자(`muted_on`)는 색표가 아니라 **본문색의 알파 0.78**이다. 손으로 고른
부가색은 패널 층에서만 맞고 칩 층에서 무너졌다(parchment 칩 위 1.99:1). 알파로
두면 21조합 전부에서 3.09:1 이상이 나온다(최저 = VERDANT/INSET).

제목·강조는 **패널 층 전용**이다. 함몰·칩 층에 얹지 말 것.

| 톤 | 제목 `heading` | 강조 `accent` |
|---|---|---|
| PARCHMENT | `965340` (4.68) | `d14b34` (3.54) |
| GOLD | `965340` (3.93) | `965340` (3.93) |
| WOOD | `46402e` (4.26) | `543c52` (4.04) |
| VERDANT | `141b1b` (5.85) | `3b3643` (3.92) |
| SLATE | `ffe18d` (6.01) | `71ddee` (4.86) |
| ABYSS | `d3a2c0` (5.40) | `d3a2c0` (5.40) |
| EMBER | `ffe18d` (3.44) | `ffe18d` (3.44) |

괄호 안은 그 층 바탕색 대비 실측치다. **새 색을 넣을 때 3:1을 못 넘기면 쓰지 말 것.**

#### 외곽선

**밝은 잉크일 때만 두른다.** 두께는 `size <= 13`이면 **2**, 아니면 **3**.

> 기존 `_label()`은 3/4px였는데 한글에서 너무 두껍다. 11~13px 한글은 획 사이가
> 1px밖에 안 돼서 3~4px 외곽선이 속공간을 메운다 — `버튼` `잉걸` `독` 같은
> 글자가 덩어리로 뭉친다(캡처 실측). 2/3px면 필드 위 가독성은 유지되고 획은 산다.
>
> **불투명한 패널 안에서는 아예 끄는 게 낫다.** `style_label(..., outline := false)`.
> 외곽선은 필드 위에 **직접** 얹히는 글자(HUD·배너·데미지 숫자)에만 켠다.
>
> **버튼 라벨에는 절대 두르지 않는다** — `style_button`이 이미 0으로 박아 둔다.
> Godot `Button`은 `outline_size`가 상태별이 아니라 하나뿐이라, 켜 두면 어두운
> 잉크인 disabled 라벨이 "어두운 글자 + 검은 3px 헤일로"가 되어 활성 버튼보다
> **굵게** 읽힌다(어포던스 역전. 실측: 진픽셀 262 vs 활성 77~150). 버튼은 언제나
> 불투명한 9-slice 위에 앉으므로 헤일로 없이도 4변종 전부 3.7:1 이상이다.

**한글 라벨에 마크다운을 쓰지 말 것.** Godot `Label`은 `**볼드**`를 별표로 그린다
(AGENTS.md §13-9).

---

## 4. 패널 — 3단 배경 계층

기존 규칙(모달 > 내부 프레임 > 칩)을 그대로 그림으로 옮겼다.

| 계층 | 역할 | 헬퍼 | 그림 |
|---|---|---|---|
| 1 껍데기 | `Role.PANEL` | `UIKit.panel_box(tone)` | 융기 베벨. 위가 밝고 아래가 어둡다 |
| 2 내부 프레임 | `Role.INSET` | `UIKit.panel_box(tone, Role.INSET)` | 함몰. 바탕 = `well` |
| 3 칩·트랙 | `Role.CHIP` | `UIKit.panel_box(tone, Role.CHIP)` | 평면 + `lo` 링 1겹. 바탕 = `well2` |
| — 슬롯 칸 | `Role.CELL` | `UIKit.panel_box(tone, Role.CELL)` | 아이콘이 들어갈 칸. 안쪽이 밝다 |
| — 포커스 | `Role.FOCUS` | `UIKit.focus_box()` | 속이 빈 흰 링. **어느 톤을 넘겨도 흰색** |

포커스 링을 톤별로 바꾸지 않는 이유: 포커스는 접근성 신호라 화면마다 그림이
달라지면 안 된다. `focus_box()`가 톤 인자를 받는 건 호출 편의일 뿐이다.

### Godot에 물리는 법

```gdscript
var shell := PanelContainer.new()
shell.add_theme_stylebox_override("panel", UIKit.panel_box(UIKit.Tone.PARCHMENT))
# 또는
UIKit.style_panel(shell, UIKit.Tone.PARCHMENT, UIKit.Role.INSET)
```

`StyleBoxTexture`는 `region_rect`로 아틀라스 한 칸을 잘라 쓴다. `UIKit`이 만들어
주는 박스에는 이미 다음이 들어 있다 — **덧쓰지 말 것.**

- `texture_margin_*` = 10 (카드 16 · 리본 L16 T18 R16 B18 · 게이지 4)
- `content_margin_*` = PANEL (18,14) · INSET (14,10) · CHIP (12,8) · CELL (12,12) · 버튼 (20,10) · 카드 (22,18) · 리본 (24,6) · 게이지 (4,4)
- `axis_stretch_*` = 기본(STRETCH). 중앙이 균일색이라 늘려도 이음매가 없다

`corner_radius`를 주지 말 것. 둥글기는 그림에 이미 2px 컷으로 들어 있고,
스타일박스에서 또 깎으면 테두리가 잘린다.

> ⚠️ **`UIKit`이 주는 리소스는 캐시된 공유 인스턴스다.** 받은 스타일박스를 그
> 자리에서 고치면 같은 박스를 쓰는 다른 화면까지 같이 바뀐다. 한 곳만 다르게
> 하려면 복제본을 떠서 쓸 것.
>
> ```gdscript
> var wide := UIKit.variant(UIKit.panel_box(UIKit.Tone.SLATE)) as StyleBoxTexture
> wide.content_margin_left = 40
> ```

### 최소 크기

9-slice는 여백 합보다 작아지면 뭉개진다. 지켜야 할 하한:

| 대상 | 최소 |
|---|---|
| 패널·버튼·칩 | **24×24** (여백 10+10 + 중앙 4) |
| 카드 | **40×40** (16+16+8) |
| 리본 | 가로 40 이상 · **세로는 40 고정**(FONT_TITLE 26이 들어가는 최소치) |
| 게이지 | **16×16** (여백 4+4 + 중앙 8 — 16보다 짧으면 둥근 끝이 뭉개진다) |

레일 슬롯 바닥의 4px 게이지처럼 12px보다 얇은 것은 **여전히 `ColorRect`다.**
9-slice로 바꾸지 말 것 — 여백이 눌려 테두리가 사라진다.

---

## 5. 버튼

| 변종 | 톤 | 쓰임 |
|---|---|---|
| `Btn.PRIMARY` | WOOD | 주 행동 — 시작·확정·구매·다음 |
| `Btn.NEUTRAL` | SLATE | 보조 행동 — 닫기·뒤로·건너뛰기 |
| `Btn.DANGER` | EMBER | 파괴적 행동 — 파기·포기·초기화 |
| `Btn.QUIET` | GOLD | 밝은 화면의 저강조 행동. PARCHMENT였는데 parchment 패널 위에서 바탕 대비 1.02:1이라 버튼이 아니라 구멍처럼 보였다(실측) |

상태 4종은 **색이 아니라 구조**로 갈린다.

| 상태 | 그림 |
|---|---|
| `normal` | 융기 베벨 |
| `hover` | 융기 베벨 + 전 슬롯 lightened(0.16), **`fill`만 0.26** |
| `pressed` | **함몰 베벨** — 위가 어둡고 아래가 밝다. 색만 어두워지는 게 아니다 |
| `disabled` | 융기 베벨 + HSV(sat×0.20, val×0.74). 채도가 빠져 회색이 된다. 라벨은 비활성 바탕의 극성을 따르는 잉크 @α0.62(2.8~4.5:1) |
| `focus` | 위 4종 위에 흰 링을 겹친다(`focus_box()`) |

배선은 한 줄이다.

```gdscript
var b := Button.new()
b.text = "출발"
UIKit.style_button(b, UIKit.Btn.PRIMARY, UIKit.FONT_HEADING)
```

`style_button`은 5개 스타일박스 + 글자색 5종 + 외곽선까지 전부 넣는다.
기존 `_style_button()`(`game.gd:10919`)은 버튼 폰트를 **16px로 하드코딩**하고 있어
5단 밖이다. 재스킨하면서 `FONT_HEADING`(17)으로 모으는 것을 권한다.

**`pressed`에서 내용을 1px 내리지 말 것.** 함몰 베벨이 이미 눌린 느낌을 내고,
글자를 움직이면 5칸 레일에서 폭 계약이 흔들린다.

> **QUIET 버튼은 바탕색만으로는 parchment 패널과 안 갈린다**(1.23:1). 분리는
> 근처 2px 검은 테두리(14:1)와 금빛 베벨이 담당한다 — 이건 의도된 저강조다.
> QUIET을 배경 없는 곳에 단독으로 놓지 말 것. 항상 밝은 패널 **안에** 둔다.

---

## 6. 카드

카드는 톤 + **좌상단 모서리 문양**으로 종류를 가른다. 9-slice의 모서리 블록
(16×16)은 늘어나지 않으므로 카드가 190×142든 320×220이든 문양 모양이 같다.

| 종류 | 톤 | 문양 | 대상 |
|---|---|---|---|
| `Card.SKILL` | WOOD | 마름모 | 딜싸이클 카드 |
| `Card.ITEM` | SLATE | 상자 | 아이템·장비 |
| `Card.RUNE` | ABYSS | 별 | 각인 |
| `Card.TROPHY` | GOLD | 왕관 | 보스 트로피 |
| `Card.BOSS` | EMBER | 뿔 | 보스·마왕 |

> WOOD(`#f38c4c` 주황)와 EMBER(`#d14b34` 벽돌)는 둘 다 주황 계열이다.
> 명도만 다르면 스킬 카드와 보스 카드가 안 갈려서 EMBER의 `fill`을 벽돌빛으로
> 내렸다. **새 카드 종류를 추가할 때 이미 있는 5색과 명도만 다른 색을 고르지 말 것.**

상태 3종:

| 상태 | 그림 |
|---|---|
| `NORMAL` | 톤 그대로 |
| `SELECTED` | 바깥 립 **두 겹**이 흰색이 되고(바깥 `outline`·안쪽 `edge`가 감싼다) 바탕이 lightened(0.10) |
| `DISABLED` | **함몰 베벨** + HSV(sat×0.20, val×0.74) + 문양도 같이 죽는다 |

**세 상태가 색이 아니라 기하로 갈린다** — 융기(보통) · 흰 이중 링(선택) ·
함몰(비활성). 비활성을 탈색만 해 두면 흐려진 립이 선택 링과 기하가 같아서
5스테이지 어두운 배경에서 "약하게 선택된 카드"로 오독된다.

**세 상태 모두 테두리 두께(9-slice 여백 16)는 같다.** 두께가 변하면 내용 영역이
좌우로 흔들려서 카드가 들썩인다.

기존 `_paint_card_block()`(190×142)은 크기를 그대로 두고 스타일박스만 갈면 된다.
아이템 희귀도 색(`#9299a6 / #4da3ff / #b66cff / #ef4444`)은 `GamePalette` 밖의
별도 계열인데, 이번 재스킨에서 **카드 테두리가 아니라 이름 글자색으로만** 쓰는
쪽으로 정리하기를 권한다(테두리에 강조색을 쓰지 않는다는 기존 규칙과 일치한다).

---

## 7. 모달 공통 골격

전 모달이 같은 뼈대를 쓴다. U2는 이 순서를 바꾸지 말 것.

```
┌─ 스크림 (ColorRect · #050508 α0.62 · 전체화면 · MOUSE_FILTER_STOP)
│  ┌─ 껍데기  PanelContainer  panel_box(PARCHMENT)          ← 계층 1
│  │  ┌─ 헤더 리본  Panel  ribbon_box(WOOD, NOTCHED)  높이 40
│  │  │    Label  FONT_TITLE  heading_color(WOOD)
│  │  ├─ 본문  PanelContainer  panel_box(PARCHMENT, INSET)   ← 계층 2
│  │  │    Label / 카드 / 칩(CHIP)                           ← 계층 3
│  │  └─ 푸터  HBoxContainer
│  │       Button(NEUTRAL) … Button(PRIMARY)   ← 주 행동이 오른쪽 끝
└──┴──┴───────────────────────────────────────
```

규칙:

1. **껍데기 톤은 화면 종류가 정한다.** 필드가 안 보이는 전면 화면(로비·온보딩·
   결과·도감) = `PARCHMENT`. 필드 위에 뜨는 모달(성·상점·레벨업·딜싸이클 편집) =
   `SLATE`. 마왕/심연 소속 = `ABYSS`.
2. **리본 톤은 껍데기 톤과 다르게** 잡는다. PARCHMENT 껍데기엔 WOOD/GOLD 리본,
   SLATE 껍데기엔 WOOD/EMBER 리본. 같은 톤을 겹치면 헤더가 안 보인다.
   리본은 `Tone` 7종을 그대로 받는다(`ribbon_box(UIKit.Tone.WOOD, UIKit.RibbonShape.NOTCHED)`) —
   전용 열거형을 두지 않은 이유는 §13 마지막 문단에 있다.
3. 리본은 껍데기 위쪽 가장자리에 **걸치게** 둔다(y를 껍데기보다 8~12px 위로).
   `NOTCHED` 모양의 V홈이 껍데기 밖으로 나와야 리본으로 읽힌다.
4. 푸터 버튼은 **오른쪽 끝이 주 행동**. 취소/닫기는 왼쪽.
5. 스크림은 `#050508` α0.62. 스포트라이트 잉크와 같은 색이라 U3 길잡이가
   모달 위에 겹쳐도 색이 안 튄다.
6. 모달 등장은 **1회성 전환만.** 기존 `_animate_modal()`(위치 0.22s QUAD/OUT ·
   알파 0.18s · 스케일 0.22s BACK/OUT)을 그대로 쓴다.

---

## 8. 게이지 · HUD

`docs/handoff-w5.md`의 좌표 계약은 **전부 유지한다.** 바뀌는 것은 이것뿐:

| W5 이음매 | 재스킨 |
|---|---|
| `_hud_panel()` | `panel_box(SLATE)` + 노란 3px 액센트 바 → 리본 또는 accent 글자색 |
| `_apply_rail_slot_styles()` | `panel_box(SLATE, CELL)` / 활성 슬롯 = `focus_box()` 겹치기 |
| `class RailMarker`(바늘) | `pointer("needle")` 스프라이트로 교체 가능 (32×32 · 아래를 가리킨다) |
| `class CycleSweepGauge` | **그대로 절차적으로 둔다.** 원형 스윕은 9-slice로 못 만든다 |
| 레일 슬롯 바닥 4px 게이지 | **`ColorRect` 유지.** 12px 미만은 9-slice 금지 |
| 열 온도계 8단 | `_heat_color()` 그대로. 칸 배경만 `panel_box(SLATE, CHIP)` |
| 빚 게이지 808×10 | 10px라 하한 미달 → `ColorRect` 유지 |

12px 이상인 게이지만 `ui-kit-bars.png`를 쓴다.

```gdscript
var track := Panel.new()          # 240×16
track.add_theme_stylebox_override("panel", UIKit.bar_box(UIKit.Bar.TRACK_DARK))
var fill := Panel.new()
fill.add_theme_stylebox_override("panel", UIKit.bar_box(UIKit.Bar.FILL))
fill.modulate = GamePalette.YELLOW   # 채움색은 modulate로 준다
# 채움을 (0,0)에 그대로 놓으면 트랙의 둥근 왼쪽 끝을 덮는다.
# 트랙 안쪽으로 BAR_MARGIN(4)만큼 들여놓을 것.
var inner := 240 - UIKit.BAR_MARGIN * 2
fill.position = Vector2(UIKit.BAR_MARGIN, UIKit.BAR_MARGIN)
fill.size = Vector2(inner * ratio, 16 - UIKit.BAR_MARGIN * 2)
```

`Container` 안에 넣으면 `bar_box`의 `content_margin`(4)이 알아서 들여 준다.
직접 좌표를 잡을 때만 위처럼 손으로 빼면 된다.

`Bar.FILL`은 순백이라 `modulate`로 어떤 색이든 된다. **채움색은 의미색이므로
톤 팔레트가 아니라 `GamePalette`에서 가져온다** — 회귀 CYAN, 도약 GREEN,
재실행 ORANGE, 과열 램프 등 정보가 실린 색은 재스킨 대상이 아니다.

### 필드 위 대비 점검 (U1~U3 공통 의무)

새 HUD 요소를 얹었으면 **스테이지 1 낮**과 **스테이지 5 밤**(CanvasModulate
`#2f2f52` + 안개 α0.24 + 비네트) 두 조건에서 캡처해 글자가 읽히는지 눈으로 본다.
`bash godot-game/scripts/test/run_all.sh --captures --capture-hud`.

---

## 9. 키캡 · 포인터 · 글리프

전부 `AtlasTexture`다. `TextureRect`에 물리고 `texture_filter`를 NEAREST로.

```gdscript
var cap := TextureRect.new()
cap.texture = UIKit.keycap("esc")          # 72×40
cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

| 함수 | 인자 |
|---|---|
| `UIKit.keycap(k)` | `w a s d e q r f i m 1 2 3 4 5 up down left right esc space enter tab shift mouse_left mouse_right` |
| `UIKit.pointer(k)` | `chevron_{left,right,up,down}` `pointer_{left,right,up,down}` `needle` `caret` `bullet` `close` `double_left` `double_right` `ellipsis` `grip` |
| `UIKit.glyph(k)` | `check cross plus minus star diamond warn info coin key gem hourglass scroll book heart bag` |

앞 10종(`check`~`key`)은 **흰색 선화**라 `modulate`로 아무 색이나 입힐 수 있다.
뒤 6종(`gem`~`bag`)은 NA 원본이라 고유 색을 갖는다 — 색을 바꾸려면 `modulate`가
곱연산이므로 원래 색보다 밝게는 못 만든다.

없는 키를 부르면 `null`을 준다 — 호출부가 텍스트 폴백을 고르라는 뜻이다.
키캡은 셀(72×40) 안에 **중앙 정렬**돼 있어 크기가 제각각이어도 나란히 놓으면
가운데가 맞는다. 글리프도 마찬가지다(NA 원본 6종은 12×12부터 16×16까지 섞여 있다).

**스킬 아이콘은 이 킷에 없다.** NA `Ui/Skill Icon/`에는 딜싸이클의 핵심 개념
(회귀·도약·재실행·과열·빚)에 대응하는 그림이 하나도 없어서 `ASSET_MAP.md` §7이
v1 절차적 아이콘 유지를 결정했고, 그 판단은 **이번 재스킨에서도 유효하다.**
`skill_icon.gd`(`PixelSkillIcon`)와 `generated_ui_icon.gd`는 손대지 않는다.

---

## 10. 스포트라이트 (U3)

```gdscript
var spot := UIKit.make_spotlight(ui_root)                       # 화면 전체 Control
UIKit.aim_spotlight(spot, target.get_global_rect(), 0.72)       # 구멍을 맞춘다
...
spot.queue_free()
```

조립은 **9-slice 마스크 1장 + ColorRect 4장**이다. 마스크 바깥 픽셀과 ColorRect
색이 똑같은 `#050508`이라 이음매가 안 보인다. `aim_spotlight`이 4개 사각형을
`floor`/`ceil`로 맞추므로 1px 밝은 금이 생기지 않는다.

- 구멍은 대상 사각형을 사방 32px 키운 크기다. 대상보다 여유 있게 잡힌다.
- 9-slice(여백 32)라 **어떤 비율의 사각형에도 맞는다.** 카드 한 장, 레일 한 칸,
  버튼 하나 전부. 원형 마스크로는 가로로 긴 대상의 모서리가 어둡게 남는다.
- 마스크 노드만 `TEXTURE_FILTER_LINEAR`다(`make_spotlight`이 이미 넣는다).
  `overlay-vignette.png`와 같은 이유 — 순수 알파 감쇠판이라 nearest로 늘리면
  동심 계단이 보인다. 픽셀아트 실루엣이 없으니 스타일은 안 해친다.
- 둥근 대상(인물·랜드마크)은 `UIKit.spotlight_oval()`을 `TextureRect`에 물린다.
  이것도 LINEAR로 그릴 것.

**어둡기(`dim`)를 트윈으로 반복시키지 말 것.** 켤 때 1회성 페이드(0.18s)는 되고,
"숨쉬듯 밝아졌다 어두워지는" 연출은 금지다(아래 §11).

---

## 11. 애니메이션 — 트윈 루프 금지 · 1회성 전환 허용

사용자가 명시적으로 요구한 규칙이고 AGENTS.md §3-9 / §13-8에 잠겨 있다.

**금지**

```gdscript
var t := node.create_tween().set_loops()     # ← 절대 금지
t.tween_property(node, "modulate:a", 0.42, 0.45)
t.tween_property(node, "modulate:a", 1.00, 0.45)
```

무한 반복 트윈은 온보딩·HUD·모달·이펙트·스포트라이트 어디에도 넣지 않는다.
"주목시키기 위해 깜빡이게" 하고 싶으면 아래 둘 중 하나로 한다.

**허용 ① 1회성 전환** — 반드시 끝난다.

```gdscript
node.modulate.a = 0.0
node.create_tween().tween_property(node, "modulate:a", 1.0, 0.18)
```

기존에 있는 것들: 모달 등장(0.22s QUAD/OUT + 알파 0.18s + 스케일 0.22s BACK/OUT),
배너(페이드 0.15 / 유지 / 페이드 0.3), 데미지 숫자(0.82s 상승), 씬 전환 커튼,
카메라 셰이크. 이것들은 그대로 쓴다.

**허용 ② `delta` 감쇠 float** — 강조가 시간이 지나면 저절로 0으로 간다.

```gdscript
_flash = maxf(0.0, _flash - delta / FLASH_TIME)
panel.modulate = Color.WHITE.lerp(accent, _flash)
```

기존 감쇠 상수: `RAIL_FLASH_TIME 0.45` · `RAIL_FLOW_FLASH_TIME 0.9` ·
`GHOST_FLASH_TIME 1.1` · `BOSS_RAIL_FLASH_TIME 0.42`. 새로 만들 감쇠도 이 범위에서.

> **알려진 위반 1건.** `game.gd:3305` `_build_factory_rail_bridge()`의 다리
> 아이콘에 `set_loops()` 펄스가 살아 있다. 재스킨하는 웨이브(U2)가 **이식하지 말고
> 삭제**하고, 필요하면 `delta` 감쇠로 바꿀 것.

---

## 12. 체크리스트 — 화면 하나를 끝내기 전에

- [ ] `StyleBoxFlat.new()`를 새로 만들지 않았다
- [ ] hex 색 리터럴을 새로 쓰지 않았다(의미색은 `GamePalette`에서, 표면색은 `UIKit`에서)
- [ ] 글자를 칩·함몰 층에 얹었다면 `style_label`에 `role`을 넘겼다(안 넘기면 극성이 뒤집힌다)
- [ ] 제목·강조색(`heading_color`/`accent_color`)을 칩·함몰 층에 쓰지 않았다
- [ ] 폰트 크기가 26/17/13/12/11 다섯 단 안에 있다
- [ ] `corner_radius`를 준 스타일박스가 없다
- [ ] 9-slice를 물린 노드가 전부 최소 크기(§4) 이상이다
- [ ] 새 `TextureRect`·`NinePatchRect`에 `TEXTURE_FILTER_NEAREST`를 넣었다(스포트라이트 제외)
- [ ] `set_loops()` 트윈이 0건이다
- [ ] 한글 라벨에 마크다운(`**`)이 없다
- [ ] `bash godot-game/scripts/test/run_all.sh` 종합 PASS
- [ ] 스테이지 1 낮 / 스테이지 5 밤 두 조건에서 캡처해 눈으로 대비를 봤다
- [ ] 딜싸이클 스트립 폭 증명이 그대로다 — `RAIL_BAND_RECT (461, 636, 358, 74)`에서
      `8 + (52×5 + 10×4 = 300) + 2 + 44(다이얼) + 4 = 358`, 가로 중심 `461 + 179 = 640`,
      세로 74(`--cycle-test`의 `strip_h=74` 계약)
- [ ] `RAIL_BAND_RECT`를 좌표로 쓰는 곳이 전부 상수를 읽는다 — **380·450·1048을 새로 하드코딩하지 않았다**
- [ ] 필드 HUD에 `Panel`을 새로 깔지 않았다(배경이 필요하면 로컬 스크림) ·
      `--cycle-test`의 `hud_block_pct`가 **3.35% 아래**다(현재 3.19)

> ⚠️ **위 세 항은 YZ(2026-08-10)가 갈아 끼운 것이다.** 원래 여기 있던 두 항은
> 「레일 5칸 폭 증명 `20 + 152×5 + 12×4 = 828` ⊂ 밴드 1048」과
> 「상단 HUD 폭 증명 `16 + 330 + 12 + 440 + 8 + 198 + 8 + 252 + 16 = 1280`」이었고,
> **X3 이후 둘 다 아무것도 증명하지 않는 등식이 됐다.**
>
> * 첫 항 — X3가 딜싸이클 밴드를 `1048×156 → 380×74`로, 칸을 `152×104 → 52×52`로 갈았다.
>   `152`도 `1048`도 코드에 없는 값이다. 그 뒤 Y2가 과열 8핍이 쓰던 왼쪽 20px를 빈 자리로
>   두지 않고 스트립을 통째로 22px 좁혀 **380 → 358**이 됐다. `--cycle-test hud_rail`은
>   **이름만 남고 재는 것이 바뀌었다** — 이제 「칸마다 `Exec{N}` 점이 정확히 `SLOT_EXEC_CAP`개 ·
>   켜진 개수 == `exec_count()`」다.
> * 둘째 항 — 그 등식은 「상단이 서로 맞닿은 불투명 판 넷의 한 줄이다」를 전제한다. X3가
>   **나침반 패널(198×96)을 통째로 삭제**했고(가장자리 화살표로 대체) 나머지 셋의 폭도 전부
>   바뀌었다(신상 330×132 → 256×56 · 스테이지 440×96 → 400×62 · 마왕 고스트 252×96 → 170×34).
>   **상시 불투명 판이 5장 → 0장**이 되면서 "폭의 합이 화면을 정확히 채운다"는 성질 자체가
>   재고 싶은 것이 아니게 됐다. 지금 재야 할 것은 `hud_block_pct`다.

---

## 13. 킷을 고칠 때

색이나 모양을 바꾸려면 **`build_assets_ui.gd` 위쪽 상수 테이블만** 고치고 다시 굽는다.
그리는 함수는 건드릴 일이 없다.

| 바꾸고 싶은 것 | 고칠 상수 |
|---|---|
| 톤 색 | `TONES` |
| 톤 추가/순서 | `TONE_ORDER` + `UIKit`의 `enum Tone`·`_INK_LIGHT_ON`·`_HEADING`·`_ACCENT` **세 표 전부**. 패널 시트와 리본 시트가 **같은** `TONE_ORDER`를 쓴다 |
| 톤 램프 색 | `TONES` + **`_INK_LIGHT_ON`을 다시 계산할 것**. 바탕 명도가 바뀌면 잉크 극성이 뒤집힌다 |
| 베벨 구조 | `_role_bands()` |
| 버튼 변종↔톤 | `BUTTON_VARIANTS` |
| 카드 종류·문양 | `CARD_KINDS` + `CARD_MOTIFS` |
| 키캡 목록 | `KEYCAP_KEYS` + `UIKit.KEYCAP_INDEX` |
| 글리프 목록 | `GLYPH_ORDER` + `GLYPH_BITS` + `UIKit.GLYPH_INDEX` |
| 스포트라이트 감쇠 | `_build_spotlights()`의 `0.30` / 제곱 램프 |

빌더는 난수·시각을 쓰지 않는다. 연속 2회 실행에서 10장 전부 SHA-256 동일을
확인했다(빌드 약 40ms). 굽고 나면 `--editor --quit`로 임포트할 것.

**아틀라스 열/행 순서는 코드 계약이다.** `TONE_ORDER`를 바꾸면 `UIKit.Tone` enum
값도 같이 바꿔야 하고, 안 그러면 조용히 다른 그림이 나온다(에러가 안 난다).
순서가 짝지어져 있는 곳은 여덟 군데다 — 빌더 쪽 `TONE_ORDER` `PANEL_ROLES`
`BUTTON_VARIANT_ORDER` `BUTTON_STATES` `CARD_KIND_ORDER` `CARD_STATES`
`RIBBON_SHAPES` `BAR_ORDER`와 헬퍼 쪽 동명 enum. 하나를 고치면 **반드시 짝을 같이
고치고**, 고친 뒤 `UIKit.glyph()`/`keycap()`/`pointer()`를 전부 한 번씩 불러
아틀라스 밖을 가리키지 않는지 확인할 것(리전이 넘치면 그때는 눈에 보인다).

같은 이유로 **리본 전용 열거형을 두지 않았다.** 처음엔 리본을 자주 쓸 5색만
구웠는데(`enum Ribbon { PARCHMENT, GOLD, WOOD, ABYSS, EMBER }`), GDScript 열거형은
결국 int라 `ribbon_box(UIKit.Tone.SLATE)`가 타입 오류 없이 통과하면서 EMBER 리본을
그린다. 96px 더 굽고 `Tone` 하나로 통일하는 쪽이 싸다. **새 시트를 추가할 때도
톤 축은 반드시 `TONE_ORDER` 전체를 굽는다.**

---

## 14. `UIKit` 전체 API (한 화면 요약)

`godot-game/scripts/ui/ui_kit.gd` · `class_name UIKit` · 전부 정적 함수.

| 함수 | 반환 | 쓰임 |
|---|---|---|
| `panel_box(tone, role = Role.PANEL)` | `StyleBoxTexture` | 패널·함몰·칩·슬롯칸·포커스 |
| `button_box(variant, state)` | `StyleBoxTexture` | 버튼 한 상태(보통은 `style_button`을 쓴다) |
| `card_box(kind, state = NORMAL)` | `StyleBoxTexture` | 카드 프레임 |
| `ribbon_box(tone, shape = PLAQUE)` | `StyleBoxTexture` | 헤더 리본(높이 40 고정) |
| `focus_box(tone = SLATE)` | `StyleBoxTexture` | 흰 포커스 링(톤 무관) |
| `bar_box(kind)` | `StyleBoxTexture` | 게이지 트랙·채움 |
| `variant(box)` | `StyleBox` | 공유 리소스의 복제본(고쳐 써야 할 때) |
| `keycap(name)` | `AtlasTexture?` | 키캡 26종 · 72×40 |
| `glyph(name)` | `AtlasTexture?` | 글리프 16종 · 32×32 |
| `pointer(name)` | `AtlasTexture?` | 화살표·바늘 16종 · 32×32 |
| `text_on(tone, role)` | `Color` | 본문 글자색 — **층까지 넘기면 극성이 맞는다** |
| `muted_on(tone, role)` | `Color` | 부가 글자색(본문색 @α0.78) |
| `text_color(tone)` / `muted_color(tone)` | `Color` | 위 둘의 PANEL 층 단축형 |
| `heading_color(tone)` | `Color` | 제목 글자색 — **패널 층 전용** |
| `accent_color(tone)` | `Color` | 강조 글자색 — **패널 층 전용**, 정보색 아님 |
| `is_dark_tone(tone, role)` | `bool` | 이 층이 밝은 잉크를 쓰는가 |
| `outline_color(tone, role)` / `outline_size(tone, size, role)` | `Color` / `int` | 외곽선 |
| `style_button(btn, variant, size)` | — | 5상태 + 글자색 일괄(외곽선 0 고정) |
| `style_label(lbl, tone, size, muted, outline, role)` | — | 글자색 + 외곽선 일괄 |
| `style_panel(node, tone, role)` | — | `panel` 스타일박스 주입 |
| `make_spotlight(parent)` | `Control` | 스포트라이트 조립(마스크+스크림 4장) |
| `aim_spotlight(spot, rect, dim)` | — | 구멍 위치·크기·어둡기 |
| `spotlight_oval()` | `Texture2D` | 원형 마스크(직접 `TextureRect`에) |

열거형: `Tone`(7) · `Role`(5) · `Btn`(4) · `BtnState`(4) · `Card`(5) ·
`CardState`(3) · `RibbonShape`(2) · `Bar`(4). 리본은 전용 열거형이 없고 `Tone`을 쓴다.

상수: `INK_DARK` `INK_LIGHT` `MUTED_ALPHA` ·
`FONT_TITLE/HEADING/BODY/LABEL/CAPTION` · `PANEL_CELL/MARGIN` ·
`CARD_CELL/MARGIN` · `RIBBON_W/H` · `KEYCAP_W/H` · `GLYPH_CELL` ·
`BAR_CELL/MARGIN` · `SPOTLIGHT_MARGIN` · `SPOTLIGHT_INK` · `TEX_*`(아틀라스 10장).

`keycap`/`glyph`/`pointer`는 모르는 이름에 **`null`** 을 준다. 반환값을 그대로
`TextureRect.texture`에 넣지 말고 `null` 검사를 하고 텍스트로 폴백할 것.
