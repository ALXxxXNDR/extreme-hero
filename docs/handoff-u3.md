# handoff-u3 — 스포트라이트 온보딩 길잡이 신설 + 필드 HUD 킷 마감

작성: U3 · 2026-08-09 · 대상: 문서 갱신 웨이브 · 다음 웨이브

사용자 요구는 한 줄이었다 — "게임 시작했을 때, 어둡게 처리하면서 집중할 곳만 밝게 해서,
유저 간단한 조작감이나 필요한 거 온보딩 길잡이 만들어줘."

UI 재스킨 시리즈(U0 킷 → U1 로비/온보딩 → U2 모달/편집)의 **마지막 웨이브**다.
두 가지를 했다: ① U2가 남긴 필드 HUD `_panel_style` 12곳을 킷으로 마감했고,
② 필드에서 조작과 HUD를 스텝별로 짚어 주는 **스포트라이트 길잡이**를 신설했다.

정보 구조 · 좌표 계약 · 화면 흐름 · 조작 · 저장 스키마는 **한 글자도 안 바꿨다.**

---

## 0. 30초 요약

| 항목 | 결과 |
|---|---|
| 필드 HUD `_panel_style` 잔존 | **12 → 0.** `_panel_style()` 함수 자체를 삭제 |
| `StyleBoxFlat.new()` 프로젝트 전체 | **0건** (U2가 1건 남겨 뒀던 것 = 그 함수) |
| 길잡이 | **7스텝 · `playing` 서브모드 · 새 state 0개 · 트윈 루프 0** |
| 신설 검사 | `--guide-test` (기능 검사 13종 → **14종**) |
| 신설 캡처 | `--capture-guide` 4컷 (시각 캡처 14종 → **15종**) |
| `run_all.sh` | **15/15 PASS** (컴파일 + 기능 14 · 84초) |
| 비headless 실기 관찰 | `--guide-test` 창 실행 1회 · 오류 0줄 · `=false` 0건 |

---

## 1. 스포트라이트 길잡이 — 발동에서 완료까지

### 1.1 왜 새 state를 안 만들었나 (판단 ①)

**`state`는 `"playing"` 그대로이고 `guide_active` 한 값이 서브모드를 연다.**
AGENTS.md §4가 허용한 두 선택지("새 state 또는 playing 서브모드") 중 후자다.

이유는 하나다. 길잡이 ①②가 **"실제로 걸어 보고 · 실제로 대시해 보고 넘어간다"**라
시간이 흘러야 하고 플레이어가 움직여야 한다. 새 state를 만들면 아래가 **전부 닫힌다**:

```
clock.tick(delta)                 _process의 `if state == "playing"` 안
combat.tick_population(delta)     동상
_refresh_interactable() / _check_rifts()
can_player_dash()  →  state in ["playing", "boss"]
can_player_attack()
run_save_allowed() →  state == "playing"
_unhandled_input의 E · ESC 분기
```

= 길잡이 안에서 걷지도 대시하지도 못한다. 그래서 서브모드가 유일하게 성립하는 선택이었다.

**대가**: `state == "playing"`으로 "지금 평범한 필드인가"를 판정하는 코드가 길잡이 중에도
참을 받는다. 강림 보스가 `state == "playing"`인 것과 같은 종류의 함정이라, 공개 창구를
`guide_active` 하나로 통일해 뒀다(`stage_boss_active()`와 같은 결).

### 1.2 일시정지 대신 안전 상태 (판단 ②)

같은 이유로 `get_tree().paused`를 **쓰지 않는다.** 대신 길잡이가 도는 동안 프레임마다:

| 안전 장치 | 값 | 걷는 시점 |
|---|---|---|
| 스폰 억제 | `combat.spawn_timer = max(현재, 4.0)` | 종료 시 `min(현재, 1.2)`로 즉시 되돌림 |
| 무적 유지 | `player.invulnerability = max(현재, 1.2)` | 종료 시 `MODAL_RETURN_INVULN` 유예로 인계 |

1스테이지 첫 낮은 T1 몹만 나오지만, **조작을 처음 배우는 40초 사이에 죽는 일은 없어야 한다.**
딜싸이클은 계속 돈다 — 그게 ③ "공격 버튼은 없다"를 눈으로 증명하는 유일한 방법이라
일부러 막지 않았다(캡처 `guide-minimal-v2.png`에서 바늘이 실제로 돌고 있다).

클럭은 **안 멈춘다.** 길잡이는 7스텝 40초 안팎이고 1스테이지 낮은 72초라 첫 낮 안에 끝난다.
설령 밤으로 넘어가도 길잡이가 깨지는 곳은 없다 — 약속한 것은 "첫 낮에 **시작**한다"다.

### 1.3 저장 정책 (판단 ③)

`_run_save_blocked_reason()`에 **다섯 번째 구간 `"guide"`**를 더했다. 길잡이가 도는 동안
자동 저장이 **쉰다**(보스전 정책과 같은 판단, 설계 §9).

- "튜토리얼 절반"이라는 상태를 schema 3에 새 키로 넣는 값이 안 맞는다.
- 잃는 것은 **런 시작 40초**뿐이고, 그 사이 영구 자원은 안 생긴다.
- 길잡이가 끝나는 순간 `_finish_guide()`가 한 번 저장한다.
- **`guide_seen`은 런 스냅샷이 아니라 설정(`[settings]`)에 산다.** 런을 지워도 남는다.

### 1.4 스텝 최종 구성 (7개)

순서는 **U1의 온보딩 1페이지가 사용자에게 한 약속**이다(handoff-u1 §3).
1페이지 부제가 `이동 · 대시 · 상호작용 · ESC 편집 화면`이고 본문에 "필드에 들어가면
길잡이가 하나씩 짚어 줍니다"라고 문자로 써 뒀다. 그 넷이 ① ② ⑥ ⑦이다.

| # | id | 짚는 곳(구멍) | 안내문 제목 | 통과 조건 | 키캡 |
|---:|---|---|---|---|---|
| 1 | `move` | **플레이어**(추적) | 먼저 움직여 봅니다 | 입력을 넣은 채 실제로 220px 이동 | `W A S D` |
| 2 | `dash` | **플레이어**(추적) | 위험하면 대시로 빠집니다 | 대시가 실제로 나감 | `SHIFT` |
| 3 | `rail` | 하단 5칸 + 바늘 | **공격 버튼은 없습니다** | `SPACE` | `SPACE` |
| 4 | `gauge` | 과열 온도계 ∪ 빚 게이지 | 과열과 빚을 봅니다 | `SPACE` | `SPACE` |
| 5 | `ghost` | 우상단 마왕 고스트 레일 | 버린 카드가 저기 쌓입니다 | `SPACE` | `SPACE` |
| 6 | `compass` | 나침반 패널 | 성 · 캠프 · 보스문을 찾습니다 | **`E`를 실제로 누름** | `E` |
| 7 | `edit` | 레일 밴드 전체 | ESC로 다섯 칸을 편집합니다 | **`ESC`** → 편집 화면이 열리며 완료 | `ESC` |

**⑥에 상호작용(E)을 접어 넣은 이유.** 오케스트레이터의 권장 골격에는 E가 없었지만
온보딩 1페이지는 E를 약속했다("문서 순서 우선"). 길잡이 시점의 필드에는 상호작용할
대상이 근처에 없으므로("성 ↗ 320m") **"어디에 있는지"와 "무엇으로 들어가는지"를 한
스텝으로 묶었다** — 나침반을 밝히고 "앞에 서서 E를 누르면 들어갑니다. 지금 한 번 눌러
보세요"라고 시킨다. 스텝 8개로 늘리는 것보다 짧고, 두 정보가 실제로 한 문장이다.

**과열과 빚을 한 스텝으로 묶은 이유.** 둘은 같은 밴드의 두 게이지이고 한 문장으로 이어진다
("한 바퀴가 끝나면 빚만큼 쉬었다가 다시 돕니다"). 구멍은 `Rect2.merge()`로 두 사각형의
합집합을 쓴다 — 세로 온도계(오른쪽 끝)와 가로 빚 막대(아래)가 한 구멍에 들어온다.

### 1.5 진행 · 스킵 규약

| 입력 | 스텝 ①②⑥⑦ (해 보라고 시킨 스텝) | 스텝 ③④⑤ (보여 주는 스텝) |
|---|---|---|
| 안내한 입력 | **통과**(`guide_completed_steps`에 기록) | — |
| `SPACE` | 개별 **건너뛰기**(기록 안 남음) | **다음**(기록 남음) |
| `ESC` | 확인 칩 → `ESC` 한 번 더 = **전체 스킵** | 동상 |
| 확인 칩에서 `SPACE` | 계속하기(칩만 닫힘) | 동상 |

**⑦의 ESC만 예외다.** 마지막 스텝은 ESC가 곧 과제라 확인 칩을 띄우지 않고
길잡이를 끝낸 뒤 **키를 그대로 흘려 보내** 편집 화면이 열린다("열면 완료" 규약).
`_handle_guide_key()`가 `false`를 돌려주는 두 자리가 정확히 이것과 ⑥의 E다 —
길잡이가 키를 먹지 않아야 그 키의 원래 동작(편집 열기 · 실제 상호작용)이 살아난다.

전체 스킵이든 정상 완료든 **`guide_seen = true`로 친다.** 건너뛴 사람에게 다음 런에서
또 띄우면 그건 벌이다. 되살리는 창구는 설정의 「온보딩 다시 표시」 하나다.

### 1.6 발동 조건

```
guide_should_trigger(resuming) = not resuming and not guide_seen and not guide_active
_maybe_start_guide(resuming)   = 위 + (automated_test == false) + (커맨드라인 인자 없음)
```

정책(`guide_should_trigger`)과 하네스 게이트(`_maybe_start_guide`)를 **일부러 갈랐다.**
`--guide-test` / `--capture-guide`는 인자를 달고 도니까 스스로는 안 열리고
`_start_guide()`를 직접 부른다. 그래야 정책 자체를 단언할 수 있다.

호출 지점은 `_begin_run()` 꼬리 **한 줄**이다. 이어하기(`_continue_saved_run` →
`_begin_run(snapshot)`)는 `resuming == true`라 절대 안 열린다.

### 1.7 층 구조 — `_process`를 한 줄도 안 건드렸다

길잡이는 **자기 프레임을 스스로 돈다.**

```
hud (Control · 화면 전체)
 ├─ 상단 4패널 · 보스 패널 · 상호작용 칩 · 레일 밴드 · 마왕 레일 밴드
 └─ GuideLayer  ← hud의 **마지막 자식** · process_mode = ALWAYS
      ├─ UIKit.make_spotlight()   9-slice 마스크 1 + 스크림 4 (dim 0.72)
      └─ GuideCaption             SLATE 패널 760×118
           ├─ 스텝 칩(CHIP) 「3 / 7」
           ├─ 제목 FONT_HEADING · 본문 FONT_BODY(autowrap)
           ├─ 킷 키캡 실물 72×40 × 최대 4
           └─ 힌트 FONT_CAPTION(muted) 「SPACE 건너뛰기 · ESC 길잡이 그만」
```

- **`hud`의 마지막 자식**이라 HUD 위에 그려진다. 모달(`overlay`)은 `ui_root` 직속이라
  이 층보다 **뒤에** 붙어 위로 올라온다 → 레벨업이 떠도 스크림이 두 겹이 안 된다.
  그래도 두 그림이 겹치는 것 자체가 산만하므로 `state != "playing"`이면 스스로 숨는다.
- `process_mode = ALWAYS`라 모달로 트리가 멈춰도 숨김 판정이 돈다. 덕분에
  **`game.gd` `_process`의 웨이브 소유 구역(W3/W4/W5/W8/W9/W10/W12/V5/V6/V7)을
  한 줄도 건드리지 않았다.**
- `_unhandled_input`에는 U3 구역 4줄을 새로 넣었다(W6 ESC 블록 **바로 위**).
  모달 상태는 그 위에서 전부 `return` 하므로 여기 닿는 것은 필드뿐이다.

### 1.8 안내판 자리 — 구멍을 피해 두 자리를 오간다

```
구멍이 y ≥ 290에서 시작하면  → 위 자리 (260, 150) 760×118  [상단 HUD 아래끝 142 + 8]
그 외(구멍이 화면 위쪽)      → 아래 자리 (260, 400) 760×118  [흐름 배너 532 위]
```

- ①② 플레이어(구멍 ≈ y 280~440) · ③④⑦ 하단 밴드 → **위**
- ⑤ 고스트 레일 · ⑥ 나침반(구멍 y 0~138) → **아래**

자리는 **스텝에 들어갈 때 한 번만** 정한다. 플레이어를 따라 구멍이 흔들려도 글자가 같이
떨면 읽을 수 없기 때문이다(구멍만 매 프레임 재조준한다 — 트윈이 아니라 추적이다).

### 1.9 트윈 — 1회성 2개, 루프 0

| 어디 | 무엇 | 길이 |
|---|---|---|
| 길잡이 켤 때 | `guide_root.modulate:a` 0 → 1 | 0.18s |
| 스텝이 바뀔 때 | `guide_caption.modulate:a` 0 → 1 | 0.14s |

둘 다 반드시 끝난다. `set_loops()` 프로젝트 전체 **0건** 유지(주석 언급 1건 제외).
스포트라이트 `dim`은 상수 0.72로 **한 번** 세팅한다 — "숨쉬듯" 밝아지는 연출 없음.

### 1.10 런 시작 배너를 걷는다

배너는 `ui_root` 직속이라 **스크림 위로 올라온다.** 런 시작 배너와 길잡이는 정확히 같은
프레임에 뜨므로, 그대로 두면 어두워진 화면 한가운데 밝은 띠가 홀로 떠 있어 스포트라이트가
깨져 보였다(첫 캡처 실측). `_start_guide()`가 `active_banner`를 걷는다 — 스테이지 이름은
상단 스테이지 패널이 계속 말하고 있다.

---

## 2. 필드 HUD 킷 마감 — `_panel_style` 12곳

**레이아웃 · 정보 구조 · 좌표는 한 픽셀도 안 바꿨다**(W5/V5 확정). 스타일박스만 갈았다.

| 행(구) | 대상 | v3 |
|---:|---|---|
| 835 | 상호작용 칩 `interaction_text` | `panel_box(SLATE, CHIP)` |
| 842 | 보스 HP 패널 | `panel_box(SLATE, PANEL)` |
| 1158 | 고스트 레일 슬롯(생성) | `_kit_cell_style(ABYSS, 틴트)` |
| 1207 | 마왕 레일 밴드 | `panel_box(ABYSS, PANEL)` |
| 1229 | 마왕 레일 슬롯(생성) | `_kit_cell_style(ABYSS, 틴트)` |
| 1488 | 마왕 레일 슬롯(캐시 갱신) | 동상 |
| 1595 | 딜싸이클 레일 밴드 | `panel_box(SLATE, PANEL)` |
| 1666 | 레일 슬롯(생성) | `_kit_cell_style(SLATE, 틴트)` |
| 1855 | 레일 슬롯(캐시 갱신) | 동상 |
| 10741 | 고스트 슬롯(캐시 갱신) | `_kit_cell_style(ABYSS, 틴트)` |
| 10813 | 배너 | `panel_box(SLATE, PANEL)` |
| 11336 | `_hud_panel()` | `panel_box(tone, PANEL)` · **tone 인자 신설**(기본 SLATE) |

`_panel_style()`은 호출부가 0이 되어 **삭제**했다. 원본 12블록 + 함수는
`docs/v1-archive/game_field_hud_style_u3.gd.txt`(449행)에 있다.
v1 토큰(`UI_MODAL_BG` `UI_PANEL_BG` `UI_CHIP_BG` `UI_EDGE` `UI_EDGE_SOFT` ·
`UI_BORDER_*`)은 **안 지웠다** — 12px 미만 게이지·핍의 `ColorRect` 색으로 아직 쓰인다.

### 2.1 톤 배정 — SLATE 기본, 마왕 소속 둘만 ABYSS

ui-style-v3 §2 톤 표를 그대로 따랐다. "필드 위에 얹히는 것 전부" = SLATE,
"마왕 · **고스트 레일** · 잠식" = ABYSS.

| HUD 부품 | 톤 | 근거 |
|---|---|---|
| 신상 · 스테이지 · 나침반 패널 · 레일 밴드 · 배너 · 상호작용 칩 · 보스 HP 패널 | SLATE | §2 "필드 위에 얹히는 것 전부" |
| **마왕 고스트 레일**(패널 + 5칸) | **ABYSS** | §2가 이름을 대고 지정 |
| **마왕 레일 밴드**(보스전 · 고스트 레일 자리를 넘겨받는다) | **ABYSS** | 같은 소속 · 톤이 이어져야 화면이 안 튄다 |

상단 4패널 중 우상단 하나만 자줏빛이라 **"저기는 내 것이 아니라 마왕의 것"**이 색만으로
읽힌다(`hud-minimal-v2-day.png` 육안 확인).

**보스 HP 패널은 EMBER가 아니라 SLATE다.** EMBER로 구우면 그 위의 RED 이름과 RED 체력
게이지가 같은 주황 계열에 묻힌다(§6이 WOOD↔EMBER에 대해 경고한 것과 같은 문제).
"보스"라는 정체는 붉은 글자와 붉은 채움이 이미 말한다.

### 2.2 칸의 상태 = 색 두 개 → **곱 틴트 하나**

v1은 칸의 상태(비활성 / 활성 / RELOAD / 1회성 강조)를 `bg_color` + `border_color`로 말했다.
킷 칸은 그림이 하나라 색 자리가 `modulate_color`(곱연산)뿐이다.

```gdscript
func _kit_cell_style(tone: UIKit.Tone, tint: Color) -> StyleBoxTexture:
    var box := UIKit.variant(UIKit.panel_box(tone, UIKit.Role.CELL)) as StyleBoxTexture
    box.modulate_color = tint
    return box
```

- **의미색은 그대로 실린다** — 카드색 · 과열 램프 · RELOAD 청 · 강조 플래시 전부.
- 곱연산이라 v1의 `darkened(0.86)`을 그대로 쓰면 칸이 새까매진다.
  `Color.WHITE.lerp(의미색, k)` 형태로 다시 잡았다(상수 7개, `HUD_*_TINT_*`).
- 활성 칸은 "테두리가 두껍다"가 아니라 **"밝다"**로 갈린다(밝기 차 약 1.5배).
- `style_key` 캐시 경로 3곳은 키를 `틴트|활성` 문자열로 바꿔 그대로 살렸다.

> ⚠️ **`UIKit.variant()`로 복제한다.** 킷이 주는 박스는 캐시된 공유 인스턴스라
> 그 자리에서 `modulate_color`를 고치면 같은 박스를 쓰는 다른 화면까지 같이 바뀐다
> (U2가 handoff-u2 §5.2에서 정확히 경고한 자리다).

**흰 포커스 링(`focus_box`)은 쓰지 않았다.** ui-style-v3 §8이 "활성 슬롯 = `focus_box()`
겹치기"를 권했지만, handoff-u2 §5.5가 "흰 포커스 링과 스포트라이트를 한 화면에서 동시에
쓰지 말 것"이라고 못 박았다. **길잡이 ③④⑦이 정확히 그 레일을 짚는 순간**이라 두 신호가
겹친다. 틴트 밝기로 갈랐다.

### 2.3 의미색 글자를 명도만 끌어올렸다 — `_hud_ink()`

v1 HUD 판은 거의 검정(`#0f1521`)이라 `GamePalette` 원색이 그대로 읽혔다.
킷 SLATE 판은 바탕이 `#345a52`(teal)라 어두운 계열이 **3:1 밑으로 떨어진다.**

| 색 | v1 판 위 | SLATE 판 위 | 조치 후 |
|---|---:|---:|---:|
| `BLUE` (수호/부활) | 3.33 | **1.71** | 3.30 |
| `RED` (보스명 · 밤 · 나침반 · 강림 예고) | — | 2.02 | 3.41 |
| `MAGENTA` (다음 체류 · 균열) | — | 2.21 | 3.34 |
| `MUTED` `CYAN` `GREEN` `YELLOW` `TEXT` `ORANGE` | — | 3.2~6.6 | **한 톨도 안 바뀜** |

첫 캡처에서 "수호 0 · 부활 0"이 사실상 안 보였다(실측 1.71:1). `_hud_ink(color)`가
**색상(hue)은 건드리지 않고 명도만** 문턱(`get_luminance() ≥ 0.66`)까지 올린다.
`lightened(k)`는 채널마다 `c + (1-c)k`라 휘도도 `L + (1-L)k`로 선형이므로 필요한 k를
반복 없이 한 번에 푼다. 이미 밝은 색은 그대로 반환된다.

적용 지점 11곳 — `shield_text` · `compass_text` · `dwell_milestone_text` · `boss_text` ·
고스트 레일 제목 + `_update_stage_panel`/`_update_compass_panel`의 동적 `font_color` 6곳.

**이것은 §2 "의미색은 바꾸지 않는다"의 테두리 안이다** — 색을 다른 색으로 바꾼 게
아니라 같은 색을 밝게 했다(V11이 나침반에서 이미 쓴 수법과 같다).

### 2.4 12px 미만은 전부 `ColorRect` 유지 (§13)

레일 슬롯 바닥 게이지 10px · 빚 게이지 808×10 · 각인 핍 10px · 과열 온도계 8단 11px ·
일차 핍 24×10 · 체력/경험 트랙 · HUD 구분선 1px · 액센트 바 3px — **손대지 않았다.**
액센트 바 2개(`_hud_panel` · 배너)는 킷 9-slice 여백 10 안쪽으로 **x만 4px 들여놨다**
(v1의 x=1·2는 테두리 그림 위였다). 세로 좌표·크기·색은 그대로다.

---

## 3. 검증 결과

| 검사 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | 오류 0 · Parse Error 0 |
| `bash godot-game/scripts/test/run_all.sh` | **15/15 PASS** (컴파일 + 기능 14종 · 84초) |
| `--guide-test` (신설) | PASS · 15플래그 전부 true |
| `--cycle-test` `hud_rail` · `hud_ghost` | PASS (레일 폭 증명·좌표 무회귀) |
| `--v4-test` `edit_layout` · `single_focus` | PASS |
| `--save-test` 지문 67축 | mismatch=0 (`blocked_reason` 3구간 무변경) |
| **비headless 실기 관찰** | `godot --path godot-game -- --guide-test` 창 실행 1회 — 길잡이 **7스텝 전체 흐름**(move→dash→rail→gauge→ghost→compass→edit)을 실제 렌더 프레임 위에서 통과. `SCRIPT ERROR`/`ERROR:` **0줄** · `=false` **0건** · exit 0 |
| `--capture-guide`(신설 4컷) · `--capture-hud`(4컷) · 나머지 13종 | 전부 `error=0` · 육안 확인 |

### `--guide-test`가 보는 것 (15플래그)

```
contract  스텝 표가 온보딩 1페이지 약속을 지키는가(순서 · 개수 6~8 · 통과 조건 ·
          키캡 이름이 전부 UIKit.keycap()에 실제로 있는가 — 없으면 조용히 텍스트 폴백된다)
trigger   새 런=열림 · 이어하기=안 열림
resume    이미 본 사람=안 열림 · 자동 테스트에서 스스로 안 열림
start     레이어 · 스포트라이트 · 안내판이 실제로 서는가
policy    길잡이 중 저장 차단("guide") · 스폰 억제 · 무적 · **끝나면 다시 열리는가**
move      입력 **없이** 밀려난 거리는 안 쌓이고, 입력을 넣고 걸으면 스텝이 넘어간다
dash      스텝 진입 시 쿨타임이 돌아오고, 실제 대시로 넘어간다
aim       구멍이 레일 밴드/나침반과 실제로 겹치고, 안내판이 위·아래로 뒤집힌다
skip      SPACE 개별 스킵(보여 주는 스텝은 통과로 기록 · 시킨 스텝은 기록 안 남음)
interact  E가 스텝을 넘기면서 **키를 흘려 보낸다**(실제 상호작용이 살아 있다)
finish    마지막 ESC가 키를 흘려 보내고 길잡이가 끝난다
persist   `settings/guide_seen`이 파일에 남는다
abort     ESC 확인 칩 → SPACE 계속 → ESC ESC 전체 스킵
reset     설정의 「온보딩 다시 표시」가 길잡이도 **함께** 되살린다
abandon   로비 복귀 시 층이 접히고 **본 것으로 치지 않는다**
```

> 이 검사는 실기 설정 파일(`settings/guide_seen`)을 건드린다. 시작할 때 원래 값을 떠 두고
> 끝에서 되돌린다 — `--capture-lobby`가 세이브를 치우는 것과 같은 규약이다.

### `--capture-guide` 4컷

```
bash godot-game/scripts/test/run_all.sh --captures --capture-guide
  guide-minimal-v2-move.png      ① 이동 — 구멍이 플레이어를 문다 · 안내판 위 자리 · WASD 키캡 4장
  guide-minimal-v2-rail.png      ③ 5칸 레일 — 구멍이 하단 밴드의 칸 다섯 · SPACE 키캡
  guide-minimal-v2-compass.png   ⑥ 나침반 — 구멍이 상단이라 **안내판이 아래로 뒤집힌다** · E 키캡
  guide-minimal-v2-confirm.png   ESC 확인 칩 — ESC·SPACE 키캡 2장
  guide-minimal-v2.png           대표 = ③ 5칸 레일(필드 HUD 킷 교체도 같은 장에서 검수된다)
```

**첫 촬영에서 스크림이 거의 안 보였다** — 컷을 `process_frame` 2회 뒤에 찍어서 켜기
페이드(0.18s)가 아직 0.2쯤이었다. `create_timer(0.35)`로 고쳤다. **새 캡처를 붙이는
웨이브는 1회성 페이드가 끝난 뒤에 찍을 것.**

### ui-style-v3 §12 체크리스트 자가 점검 (U3 범위)

- [x] `StyleBoxFlat.new()` **프로젝트 전체 0건**(`_panel_style` 삭제로 마지막 1건 제거)
- [x] hex 색 리터럴 신규 0건 (U3 범위 `Color("…")` 0건 · 틴트는 전부 계산 상수)
- [x] 칩·함몰 층 글자에 `role` 전달 (안내판 스텝 칩 = `Role.CHIP`)
- [x] `heading_color`/`accent_color`는 패널 층에서만
- [x] 폰트 26/17/13/12/11 — 길잡이는 17/13/11 세 단만 쓴다
- [x] `corner_radius` 신규 0건
- [x] 9-slice 최소 크기: 안내판 760×118 · 스텝 칩 88×24 · 레일 칸 152×104 ·
      고스트 칸 44×32 · 마왕 레일 칸 72×52 · 상호작용 칩 600×42 · 배너 820×58 — 전부 24 이상
- [x] 새 `TextureRect` 전부 NEAREST(`_kit_keycap` 경유) · 스포트라이트 마스크만 LINEAR(킷이 넣는다)
- [x] **`set_loops()` 프로젝트 전체 0건**
- [x] 한글 라벨에 마크다운 0건
- [x] `run_all.sh` 종합 PASS
- [x] 12px 미만 게이지는 `ColorRect` 유지 (§2.4)
- [x] 레일 5칸 폭 증명(`20 + 152×5 + 12×4 = 828` ⊂ 밴드 1048) · 상단 HUD 폭 증명 — **손대지 않음**
- [x] 스테이지 1 낮 / 5 밤 대비 점검 — `--capture-hud` 4컷 육안. §2.3의 대비 회귀 1건을
      실측으로 잡아 고쳤다

---

## 4. AGENTS.md 갱신 필요 목록 (U3는 수정 금지였다)

오케스트레이터/문서 웨이브가 마감할 것. **U1·U2가 남긴 항목도 아직 살아 있다.**

| § | 지금 문서 | 고쳐야 할 값 |
|---|---|---|
| §0 문서 메타 | `문서 최종 갱신 2026-08-09 KST (V10)` | `(U3)` |
| §1 체크포인트 | `active_request` v3 개편 · `last_verified` 13종 | UI 재스킨 U0~U3 완료로 갱신 · `guide_test: pass` 추가 · `captures_12` → `captures_15` (64컷) |
| §2 30초 실행 | `run_all.sh # 컴파일 1 + 기능 검사 13종` | **14종** |
| §2 `--preview-*` 목록 | — | 변경 없음(길잡이는 프리뷰가 아니라 캡처다) |
| **§4 조작 표** | `Esc` = 5칸 편집 화면 / `Space` = 선택 확정 | **길잡이 중 규약 추가**: `SPACE` = 개별 건너뛰기·다음 / `ESC` = 확인 칩 → 한 번 더 = 전체 스킵(마지막 스텝의 `ESC`만 편집 화면을 연다) |
| **§4 화면 흐름** | `게임 시작 → 캐릭터 선택 → 온보딩 5페이지 → 1스테이지 필드` | 온보딩은 **4페이지**(U1이 이미 4로 줄였다) · 그 뒤 `→ 1스테이지 필드 + 첫 낮 스포트라이트 길잡이 7스텝(최초 1회)` |
| **§4 상태 목록** | 표에 `playing` 한 줄 | **새 state는 안 만들었다.** `playing` 행에 각주: "`guide_active == true`면 스포트라이트 길잡이 서브모드. 시간은 흐르고 스폰만 억제·무적 유지, **자동 저장은 쉰다**. 강림 보스와 같은 종류의 함정이니 `state == \"playing\"`만으로 '평범한 필드'를 판정하지 말 것" |
| §5 코드 지도 | `game.gd 10,993행` / `test_runner.gd 4,577행` / `run_all.sh 250행` | **12,006 / 4,900 / 264** |
| §5 코드 지도 | `test_runner.gd … 기능 검사 13종 · 프리뷰 14종 · 시각 캡처 12종` | **기능 14종 · 프리뷰 14종 · 시각 캡처 15종** |
| §5 최상위 구조 | `screenshots/qa/ ← 시각 캡처 산출물(40컷)` | **64컷** |
| §6 저장 흐름 | `_run_save_blocked_reason()`이 막는 **4구간** | **5구간** — `guide`(길잡이 진행 중) 추가 |
| §9(에셋 판단) 828행 | `캡처가 저장된다(12종 40컷)` | **15종 64컷** |
| §10 변경표 855행 | `자동 검사 · 기능 13종` | 14종 |
| **§11** 877~980 | `기능 검사 13종 + 컴파일 (요약표는 14행)` / `시각 캡처 12종 (40컷)` | **기능 검사 14종(요약표 15행)** / **시각 캡처 15종(64컷)**. 목록에 `--guide-test`(마커 `GUIDE_TEST_COMPLETE`)와 `--capture-guide`(4컷) 추가 |
| §11 1200·1203행 | `기능 13종 전부 PASS (78초)` / `--captures → 12종 40컷` | 14종(84초) / 15종 64컷 |
| §13 AI 작업 규칙 | `_panel_style()` 언급이 있으면 | **삭제됐다.** 새 스타일박스는 전부 `UIKit`에서. `StyleBoxFlat.new()` 프로젝트 0건 |
| §12 알려진 한계 | — | 아래 §5의 3건을 옮길 것 |

> U1·U2가 이미 요청한 갱신(캡처 12종 → 13종 → 14종)은 **U3의 15종에 흡수된다.**
> 한 번만 고치면 된다.

---

## 5. 남은 것 · 알려진 사항

1. **길잡이 중에는 ESC로 편집 화면을 못 연다**(①~⑥). ESC가 확인 칩으로 잡히기 때문이다.
   7스텝 40초짜리 잠금이고 ⑦이 곧 "ESC를 눌러 보라"라 실질 손해는 없다. 뒤집으려면
   전체 스킵 키를 ESC 말고 다른 키로 옮겨야 하는데, 그건 사용자 지시(ESC 전체 스킵)와 어긋난다.

2. **길잡이 도중 레벨업 모달이 뜨면 길잡이 층이 숨는다**(모달이 닫히면 그 스텝에서 이어진다).
   스폰을 억제해도 시작 population이 남아 있어 딜싸이클이 잡을 수 있다. 실측상 40초 안에
   레벨업까지 가는 일은 드물지만 0은 아니다. 층이 겹치는 사고는 막았고, 이어짐도 정상이다.

3. **`--capture-result`는 여전히 패배 컷만 찍는다**(U2 §7-4가 남긴 것). PARCHMENT + GOLD
   리본(승리) 조합은 아직 육안 검수 창구가 없다.

4. **`_hud_ink()`의 문턱 0.66은 SLATE(`#345a52`) 기준으로 잡았다.** HUD 톤을 바꾸는 웨이브가
   생기면 이 상수도 다시 계산해야 한다(ui-style-v3 §13의 "톤 램프를 바꾸면 `_INK_LIGHT_ON`을
   다시 계산할 것"과 같은 종류의 짝이다).

5. **v1-archive 보존.** `docs/v1-archive/game_field_hud_style_u3.gd.txt`(449행)에 교체 전
   12블록 + `_panel_style()` + `_hud_panel()` 원본이 들어 있다. U2가 남긴 권고
   ("다음 웨이브는 착수 전에 `git add -A && git commit`을 한 번 할 것")는 **이번에도
   못 지켰다** — AGENTS.md §0-7이 커밋을 금지하고 있어 사용자 지시가 필요하다.

---

## 6. U3 소유 범위 (다음 웨이브가 겹치지 말 것)

```
game.gd
  RAIL_SLOT_TINT_* / GHOST_SLOT_TINT_* / BOSS_SLOT_TINT_*     (필드 HUD 칸 틴트 7상수)
  HUD_INK_MIN_LUMA / _hud_ink()
  _kit_cell_style() / _hud_panel(tone 인자)
  GUIDE_CAPTION_* / GUIDE_PLAYER_BOX / GUIDE_DIM / GUIDE_FADE / GUIDE_STEP_FADE
  GUIDE_MOVE_GOAL / GUIDE_SAFE_SPAWN_HOLD / GUIDE_SAFE_INVULN / GUIDE_STEPS
  class GuideLayer
  guide_active / guide_step / guide_confirm / guide_completed_steps
  guide_move_distance / guide_last_player_position / guide_seen
  guide_root / guide_spotlight / guide_caption / guide_count_label
  guide_title_label / guide_body_label / guide_keycap_row / guide_hint_label
  guide_should_trigger / _maybe_start_guide / _start_guide / _finish_guide / _abandon_guide
  _build_guide_layer / _clear_guide_layer / guide_step_data
  _apply_guide_step / _paint_guide_step / _paint_guide_confirm
  _guide_target_rect / _aim_guide / _tick_guide / _advance_guide / _handle_guide_key
  _unhandled_input의 "=== U3 소유 ===" 4줄
  _run_save_blocked_reason()의 ⑤ guide 구간
  _load_progress/_save_progress/_reset_onboarding_hide의 guide_seen 3줄

test_runner.gd
  ROUTINES의 --guide-test / --capture-guide 2줄 · _run_visual_capture의 "guide" 분기
  _run_guide_test / _run_guide_capture

run_all.sh
  ALL_TESTS의 --guide-test 1줄 · ALL_CAPTURES의 --capture-guide 1줄
```

**길잡이는 U1/U2 확정 화면을 가리키기만 한다** — 로비·온보딩·모달·편집 화면의 코드는
한 줄도 안 건드렸다. `ui_kit.gd`도 무수정이다(버그 0건 · 소비만 했다).
