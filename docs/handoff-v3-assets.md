# handoff — V3 에셋 파이프라인 (딜싸이클 용사 v3)

| | |
|---|---|
| 웨이브 | **V3** — 에셋 파이프라인 (`scripts/` 미접촉) |
| 소유 | `godot-game/art/v2/build_assets_v3.gd`(신규) · `godot-game/art/v2/ASSET_MAP.md` · 산출 PNG 20장 · 이 문서 |
| 의존 | V0 (`tuning.gd`의 V3-N 블록을 읽기 전용으로 참조) |
| 병렬 | V1 · V2 · V4와 완전 병렬 |
| 코드 로직 변경 | **0건.** `.gd` 게임 로직·`test_runner`·`run_all.sh`·`art/external` 원본 전부 무수정 |
| 근거 문서 | `docs/GAME_DESIGN_V3.md` §3 · §4.3~§4.8 · §7 · 부록 B V3 |

에셋의 좌표·색·행 배정 **정본은 `godot-game/art/v2/ASSET_MAP.md` §9~§16**입니다.
이 문서는 그 위에서 **다른 웨이브가 알아야 할 것만** 추립니다.

---

## 1. 무엇을 만들었나 — 20장

| 묶음 | 파일 | 소비 웨이브 |
|---|---|---|
| 지형 3벌 | `terrain-atlas-verdant/waste/abyss.png` | **V5** |
| 스테이지 보스 5시트 | `boss-frost-cyclops` / `plague-slime` / `black-slime` / `crimson-tengu` / `black-tengu.png` | **V7** |
| 원소 VFX 5벌 | `vfx-element-ice/poison/flame/oil/thunder.png` | **V6** |
| 상태 핍 | `vfx-status-pips.png` | **V6** |
| 시너지 버스트 | `vfx-synergy.png` | **V6** |
| 바닥 텔레그래프 | `vfx-telegraph-ring.png` | **V7** (V6도 장판에 재사용) |
| 스테이지 오버레이 | `overlay-fog.png` · `overlay-vignette.png` | **V5** |
| 랜드마크 2종 | `landmark-boss-gate.png` · `landmark-camp.png` | **V5** |

`art/v2/`의 v2 산출물 33장은 **한 장도 덮어쓰지 않았습니다**(mtime·해시 확인).
`build_assets.gd`(W11)도 무수정입니다. 총 33 → **53장**.

### 재생성

```bash
godot --headless --path godot-game --script res://art/v2/build_assets_v3.gd   # 0.3초
godot --headless --path godot-game --editor --quit                            # .import 갱신
```

---

## 2. 다른 웨이브가 쓸 경로표

### V5 — 스테이지 진행 · 월드

```gdscript
# world_grid.gd:8  const TERRAIN_ATLAS := preload(...)  →  딕셔너리 + var
const TERRAIN_ATLASES := {
    "verdant": preload("res://art/v2/terrain-atlas-verdant.png"),
    "waste":   preload("res://art/v2/terrain-atlas-waste.png"),
    "abyss":   preload("res://art/v2/terrain-atlas-abyss.png"),
}
# 어느 스테이지가 어느 벌을 쓰는지는 tuning.STAGE_TERRAIN_ATLAS 가 이미 들고 있다.
#   ["verdant", "verdant", "waste", "waste", "abyss"]
```

- **셀 규격은 v2와 완전히 동일**합니다 — 160×128 / 5열×4행 / 셀 32×32 / `ATLAS_CELL_INSET = 0`.
  `wfc_chunk_generator.TILE_RULES`도 그대로 먹습니다. 바꿀 것은 `TERRAIN_ATLAS` 상수 하나뿐입니다.
- **`terrain-atlas-verdant.png`는 `terrain-atlas-na.png`와 바이트 단위로 동일**합니다.
  1·2스테이지 렌더가 v2와 픽셀 하나 안 달라진다는 뜻이라, 회귀 캡처 비교가 쉽습니다.
- 오버레이: `overlay-fog.png`(nearest · 정적 전면 쿼드 · α는 `tuning.STAGE_FOG_ALPHA`) /
  `overlay-vignette.png`(**이 한 장만 `TEXTURE_FILTER_LINEAR`** · `tuning.STAGE_VIGNETTE`).
- 랜드마크: `landmark-boss-gate.png`(192×128) · `landmark-camp.png`(192×128).
  둘 다 v2 랜드마크와 같은 **밑변 기준** 배치입니다.

### V6 — 원소 상태이상 통합

```gdscript
# cycle_skill_effect.gd — element 키로 시트 선택. 셀은 5벌 전부 80.0 하나다.
const VFX_ELEMENT := {
    "ice":     preload("res://art/v2/vfx-element-ice.png"),      # 10f  800x80
    "poison":  preload("res://art/v2/vfx-element-poison.png"),   #  8f  640x80
    "fire":    preload("res://art/v2/vfx-element-flame.png"),    #  5f  400x80
    "oil":     preload("res://art/v2/vfx-element-oil.png"),      # 11f  880x80
    "thunder": preload("res://art/v2/vfx-element-thunder.png"),  #  5f  400x80
}
const VFX_ELEMENT_CELL := 80.0     # 기존 VFX_EXPLOSION_CELL 과 같은 값
# 앵커는 셀 중앙 — 기존 렌더러의 `origin - box * 0.5` 를 그대로 쓰면 된다.
```

- `strike` 타 / `psi` 초는 **전용 시트가 없습니다.** 설계 §4.4대로 상태를 만들지 않는
  소비자이므로, 기존 `vfx-core.png` 행0(참격) · 행2(마법진)를 `effect_color`로 물들여 씁니다.
- 상태 핍 `vfx-status-pips.png` — 80×32 · 셀 16×16 · 5열 · 마스크 offset.y = 16.
  **열 순서 = `[poison, burn, chill, oil, shock]`** (설계 §4.8의 독/연/한/유/전 순서 그대로).
  설계는 "8×8 색 사각"이라고 적었지만 **실루엣까지 다르게** 만들었습니다
  (원 / 위로 뾰족 / 마름모 / 아래로 뾰족 / 지그재그) — 5스테이지는 주기의 62%가 밤이라
  색만으로는 구분이 죽습니다. 코드 비용은 `draw_rect` → `draw_texture_rect_region` 한 줄입니다.
- 시너지 `vfx-synergy.png` — 768×480 · 셀 96×96 · **8열 × 5행**.
  행 순서 `[대폭 연소, 전도, 역병 발화, 쇄빙, 정신 붕괴]`.
  나머지 시너지 3종(증기 · 감전 유막 · 터뜨리기)은 기존 시트 재사용을 권합니다(ASSET_MAP §13-2).
- 장판 잔류(`oil` 도포 · 산성 분비)는 `vfx-telegraph-ring.png` **행 2 `pool`**을 쓰면 됩니다.

### V7 — 보스 3종 · 보스방

```gdscript
# enemy.gd 의 하드코딩 3상수(BOSS_CELL / BOSS_MASK_OFFSET / BOSS_SHEET) → 보스별 테이블
const BOSS_SHEETS := {
#   key               sheet                                   cell            mask_y  foot_inset  rows
    "frost_cyclops": {"tex": ".../boss-frost-cyclops.png", "cell": Vector2(100,100), "mask_y":  300, "foot": 14,
                      "idle": [0,5], "walk": [1,6], "hit": [2,3], "attack": []},
    "plague_slime":  {"tex": ".../boss-plague-slime.png",  "cell": Vector2(124,104), "mask_y":  312, "foot": 12,
                      "idle": [0,5], "walk": [1,13], "hit": [2,5], "attack": [1,13]},
    "black_slime":   {"tex": ".../boss-black-slime.png",   "cell": Vector2(124,104), "mask_y":  312, "foot": 12,
                      "idle": [0,5], "walk": [1,13], "hit": [2,5], "attack": [1,13]},
    "crimson_tengu": {"tex": ".../boss-crimson-tengu.png", "cell": Vector2(164,164), "mask_y":  820, "foot": 48,
                      "idle": [0,6], "walk": [1,10], "hit": [2,8], "attack": [3,15], "trans": [4,11]},
    "black_tengu":   {"tex": ".../boss-black-tengu.png",   "cell": Vector2(164,164), "mask_y":  820, "foot": 48,
                      "idle": [0,6], "walk": [1,10], "hit": [2,8], "attack": [3,15], "trans": [4,11]},
    "demon_king":    {"tex": ".../boss-demon-king.png",    "cell": Vector2(144,288), "mask_y": 1440, "foot":  0,
                      "idle": [0,12], "walk": [1,12], "hit": [2,8], "attack_r": [3,8], "attack_l": [4,8]},
}
# [행 index, 프레임 수]
```

`foot_inset`이 v2 마왕과 다른 이유: 마왕 시트는 48×48 애니를 셀 아래쪽에 붙여 구웠지만,
v3 보스는 애니마다 프레임 한 변이 통일돼 있어 **원본 프레임을 통째로 복사**했습니다
(원작자가 맞춘 발밑 정렬이 그대로 보존됩니다). 그리기 식만 한 항 늘리면 됩니다.

```gdscript
destination = Rect2(-CELL.x * 0.5, foot + FOOT_INSET - CELL.y, CELL.x, CELL.y)
```

로테이션(설계 §3.1 · `tuning.STAGE_BOSS_DESIGN` = `["A","B","C","B","C"]`):

| 스테이지 | 설계 | 시트 |
|---:|---|---|
| 1 | A 서릿발 외눈 | `boss-frost-cyclops.png` |
| 2 | B 역병 점액왕 | `boss-plague-slime.png` |
| 3 | C 홍염 천구 | `boss-crimson-tengu.png` |
| 4 | B+ 흑점액 변종 | `boss-black-slime.png` |
| 5 | C+ 흑천구 | `boss-black-tengu.png` |
| 종료 | 마왕 | `boss-demon-king.png` (v2 무변경) |

**세 가지 주의:**

1. **A는 `attack` 행이 비어 있습니다**(원본에 Attack 애니가 없음). 설계 §3.1대로
   공격은 발구름 → 바닥 링이며 **사지 애니메이션이 필요 없습니다.**
   `vfx-telegraph-ring.png` **행 0 `expand`** + 보스 스케일 펄스(`delta` 감쇠)로 구현하세요.
2. **점액은 `walk`와 `attack`이 같은 행(1 = Jump 13f)입니다.** 슬라임의 이동이 곧
   도약이고, 설계 §3.3 B-1 "도약 압살"이 바로 이 애니입니다.
3. **`trans` 행(11f)은 C+ 등장 연출 전용**입니다. 소형(16×16) → 대형(65×57) → 정착(53×33)이
   프레임 안에서 완결됩니다. C 시트에도 같은 행이 있어 필요하면 재사용 가능합니다.

권장 히트박스 반경(결정권은 V7): A **38** · B/B+ **40** · C/C+ **48** · 마왕 58(유지).
바닥 그림자는 `Rect2(-radius, radius*0.72, radius*2, 14)`가 마왕(`-58,42,116,18`)과 비례가 맞습니다.

---

## 3. 5단 톤 컨셉 요약

**아틀라스 3벌 + 런타임 그레이드 5단**입니다. 아틀라스만으로 5벌을 만들지 않은 것은
타협이 아니라 **소스가 4팔레트뿐이라는 실측 결과**입니다(설계 §7.1이 지적한 그대로).

| 스테이지 | 이름 | 아틀라스 | 컨셉 한 줄 | 험악해지는 축 |
|---:|---|---|---|---|
| 1 | 왕국 변경 | verdant | 밝은 초원. v2와 **픽셀 하나 안 다르다** | — (기준점) |
| 2 | 시든 숲 | verdant | 같은 초원인데 볕이 바랬다 | 채도 −12% · 낮 −4초 |
| 3 | 잿빛 벌판 | **waste** | 초원이 **모래**가 된다. 안개가 낀다 | 바탕 교체 · 안개 0.10 · 밤이 낮을 앞선다 |
| 4 | 역병의 늪 | waste | 모래 위에 녹색 독기가 앉는다 | 녹색 α0.08 · 안개 0.16 |
| 5 | 심연 | **abyss** | 물이 **자주**, 땅이 **재색**. 거의 항상 밤 | 채도 −35% · 안개 0.24 · 비네트 · **주기의 62%가 밤** |

**낮/밤 길이 자체가 그래픽 가중치의 절반입니다.** 72/45 → 48/78. 필터를 겹치는 것보다
"거의 항상 밤"이 훨씬 강한 험악함이고 상수 2개면 됩니다(`tuning.STAGE_DAY_DURATION` / `_NIGHT_`).

### 육안 검증 결과

3벌 아틀라스에 V3-N 그레이드를 실제로 먹여 **5단 × 낮/밤 10컷**을 렌더해 확인했습니다.

- 5단이 서로 **명확히 구분**됩니다(초록 / 바랜 초록 / 모래 / 늪 / 자주 회색).
- 가장 어두운 **5단 밤**에서도 물↔뭍 경계, 흰 포말선, 다리 판자, 데코 실루엣이 **전부 판독**됩니다.
- 자주 블록의 뭍 바탕(`#b3957f`)과 살구 밴드에 곱을 먹인 바탕이 **정확히 일치**해
  호수 가장자리에서 색이 한 칸도 튀지 않습니다(v2가 잔디에서 확인한 함정을 3벌 다 통과).
- 셀 18(성 안뜰)·19(캠프/균열 바닥)만 바이옴 틴트를 **안 걸었습니다** — 18은
  `castle-floor.png`와 같은 원본이어야 성 안팎이 이어지고, 19는 아레나라 눈에 띄어야 합니다.
  심연에서 따뜻한 돌바닥이 섬처럼 남지만 그레이드가 눌러 주는 것까지 확인했습니다.

---

## 4. 보스 3종 최종 선정 · 대체 판단

설계 §3.1의 선정을 **실측으로 재확인하고 그대로 채택**했습니다(프레임 수 전부 일치).

| 설계 | 소스 | 실측 프레임 | 채택 |
|---|---|---|:--:|
| A 서릿발 외눈 | `DemonCyclop2` 50×50 | Idle 5 · Walk 6 · Hit 3 (Attack 없음) | ✔ |
| B 역병 점액왕 | `GiantSlime2` 62×52 | Idle 5 · Hit 5 · Jump 13 (Walk/Attack 없음) | ✔ |
| C 홍염 천구 | `TenguRed` 82×82 | Idle 6 · Walk 10 · Attack 15 · Hit 8 · **Trans 11** | ✔ |
| B+ | `GiantSlime` + 자주 | 동일 규격 | ✔ |
| C+ | `TenguRed` + 암색 | 동일 규격 · Trans를 등장 연출로 | ✔ |

**A만 원본 색을 바꿨습니다 — 설계에 없던 판단이라 여기 남깁니다.**
`DemonCyclop2`는 **녹색** 외눈인데 `mob-ogre`(`Monster/Cyclope2`)도 **녹색 외눈**입니다.
1스테이지에서 잡몹과 보스의 팔레트·실루엣이 겹칩니다(실측 확인). 게다가 이름이 서릿발이고
패턴이 빙+뇌입니다. 그래서 HSV 색상만 +128° 돌려 청록으로 만들었습니다 — 명도 대비는
그대로라 실루엣·디테일 손실이 0입니다. **되돌리려면 `BOSS_SHEETS["frost-cyclops"]["hsv"]`를
`[0.0, 1.0, 1.0]`로 두고 다시 굽기만 하면 됩니다.** V10이 판정해 주세요.

**대체 후보는 살아 있습니다.** A가 플레이테스트에서 밋밋하면 설계 §3.1이 예비로 남긴
`Boss/GiantBamboo`(62×62 균일 · Idle 6 / Walk 12 / Attack 5 / Hit 4 / Charge 3 — 실측 확인)로
바꿉니다. `BOSS_SHEETS`의 `dir` / `frame` / `rows` 세 값만 갈아끼우면 되고,
`GiantBamboo`는 **Attack 행이 있어** V7의 `attack: []` 예외가 사라지는 이점까지 있습니다.
파이프라인 변경은 0입니다.

**버린 후보 재확인**: `GiantBlueSamurai`는 마왕과 픽셀 단위로 같은 리그라 실루엣이 겹칩니다.
`DragonBlue/Green`은 파츠 조립형(Head/Body/Wing 개별 PNG)이라 현재 파이프라인 밖입니다.

**배율**: 스테이지 보스 전부 **×2**, 마왕만 ×3(v2 유지). ×3으로 구우면 외눈 몸통이
111×99가 되어 마왕(105×117)과 붙습니다 — 최종 보스의 유일성이 배율에서 깨지는 것이
픽셀 크기 통일보다 큰 손해입니다. ×2는 몹(32px 셀)과 같은 배율이라 화면에 세 번째 픽셀
크기도 안 생깁니다.

---

## 5. 상태 VFX 매핑표

### 5-1. 상태 5종 → 핍 · 원소 시트

| 상태 | 한글 | 핍 열 | 실루엣 | 색 | 부여 원소 | 원소 시트 |
|---|---|---:|---|---|---|---|
| `poison` | 독 | 0 | 원 | `#83c65c` | `poison` | `vfx-element-poison.png` (8f) |
| `burn` | 연 | 1 | 위로 뾰족 | `#e78a45` | `fire` | `vfx-element-flame.png` (5f) |
| `chill` | 한 | 2 | 마름모 | `#67c7d4` | `ice` | `vfx-element-ice.png` (10f) |
| `oil` | 유 | 3 | 아래로 뾰족 | `#1b1622` (외곽선 `#8a7fa3`) | `oil` | `vfx-element-oil.png` (11f) |
| `shock` | 전 | 4 | 지그재그 | `#f4d35e` | `thunder` | `vfx-element-thunder.png` (5f) |

### 5-2. 시너지 → 이펙트

| 시너지 | 매트릭스 칸 | 에셋 | 비고 |
|---|---|---|---|
| **★대폭 연소** | `fire` × `oil` | `vfx-synergy.png` **행 0** | 간판 콤보. 반경 130 `oil` 전파는 `pool` 행으로 표시 |
| **★전도** | `thunder` × `chill` | `vfx-synergy.png` **행 1** | 최대 4체 도약 — 도약마다 행1 1회 |
| 역병 발화 | `fire` × `poison` | `vfx-synergy.png` **행 2** | 반경 90 |
| 쇄빙 | `strike` × `chill` | `vfx-synergy.png` **행 3** | 넉백 ×2 · 경직 0.35s |
| 정신 붕괴(psi 수확) | `psi` × 전 상태 | `vfx-synergy.png` **행 4** | 단일 대상 |
| 증기 | `fire` × `chill` | `vfx-element-flame` + `vfx-smoke`(v2) | 전용 행 없음 — 범위 +50%라 기존 폭발/연기로 충분 |
| 감전 유막 | `thunder` × `oil` | `vfx-element-thunder` + `pool` 행 | 전용 행 없음 |
| 터뜨리기 | `strike` × `poison` | `vfx-core`(v2) 행1 원형 참격 | 전용 행 없음 |

전용 행을 5개로 끊은 근거: 설계 §4.8이 시너지 피드백을 **"1회성 정적 강조 — 버스트 + 부유 라벨"**로
못 박았습니다(트윈 루프 금지). 8종 전부에 시트를 주면 그 규칙과 무관하게 시트만 늘어납니다.

### 5-3. 보스 패턴 → 텔레그래프

| 패턴 | 보스 | 텔레그래프 |
|---|---|---|
| 서리 발구름 (wave · 0.55s) | A | `vfx-telegraph-ring` **행 0 `expand`** |
| 빙주 낙하 (trap · 0.80s · 예고 원 3개) | A | **행 1 `charge`** ×3 |
| 뇌격 방출 (pierce · 0.45s) | A | `vfx-element-thunder` |
| 도약 압살 (wave · 0.70s) | B | **행 0 `expand`** + 시트 행1 Jump 13f |
| 산성 분비 (trap · 8초 잔류 ×3) | B | **행 2 `pool`** ×3 |
| 역병 파열 (wave · 1.10s) | B+ | **행 0** + `vfx-synergy` 행2 |
| 기름 날개 (wave · 0.50s · 부채꼴 도포) | C | **행 2 `pool`** |
| 활공 참격 (slash · 0.35s) | C | 시트 행3 Attack 15f (텔레그래프 최단 → 링 없음) |
| 화염 강하 (trap · 0.85s) | C | **행 1 `charge`** → `vfx-synergy` 행0 |
| 흑염 회오리 (wave · 1.20s · 3초 지속) | C+ | **행 2 `pool`** + `vfx-element-flame` |

---

## 6. 검증

| 항목 | 결과 |
|---|---|
| 빌드 실행 | `BUILD_ASSETS_V3_COMPLETE files=20 ms≈320` · 에러 0 |
| **결정성** | 연속 2회 실행 → **20장 전부 SHA-256 동일** |
| `--editor --quit` | **ERROR/WARNING 0줄** · 신규 `.import` 20개 생성 (art/v2 총 53개) |
| v2 산출물 무손상 | `terrain-atlas-na.png` · `boss-demon-king.png` · `vfx-core.png` · `build_assets.gd` mtime 불변 |
| `terrain-atlas-verdant` ↔ `terrain-atlas-na` | **바이트 동일** (1·2스테이지 렌더 회귀 위험 0) |
| 마스크 정합 | 보스 5시트의 아래 절반 알파 == 위 절반 알파 (검증) |
| 육안 검증 | 5단 톤 10컷 · 보스 5시트 전 행 · 원소 5벌 · 핍 5종(밝은/어두운 배경) · 시너지 5행 · 링 3행 · 랜드마크 2종 |
| `run_all.sh` | **실행하지 않음**(지시대로) |

### 육안 검증에서 실제로 고친 것 3건

1. **피격 섬광이 초록으로 번쩍였다.** NA 보스 `Hit.png`의 섬광 프레임이 주황 `#ff9554`(색상 24°)로
   구워져 있어 HSV 회전에 같이 끌려갔습니다. 서릿발 외눈은 Hit 행이 3프레임인데 그 **첫 프레임**이
   섬광이라 피격마다 1/3이 초록이었습니다. → `hue_keep = [0°, 40°]`(색상만 보존, 채도·명도는 적용)를
   추가해 섬광은 주황으로 남깁니다.
2. **독 VFX가 "빛"으로 읽혔다.** `Plant` 시트를 −14°(황록)로 돌렸더니 그냥 노란 섬광이 됐습니다.
   → +26°(에메랄드) + 채도 1.45로 바꿔 산성 초록을 만들었습니다.
3. **기름 VFX가 "진흙"으로 읽혔다.** `Water`를 −38°로 돌리니 올리브가 됐습니다.
   → +112°(자주) · 채도 0.40 · 명도 0.30. 완전 무채색이면 밤 지형에 묻히고 채도가 높으면 독과 헷갈립니다.

추가로 **흑천구 명도를 0.52 → 0.60으로 올렸습니다.** 0.52는 스테이지 5의
`CanvasModulate #2f2f52` + 안개 α0.24 + 비네트를 다 먹고 나면 실루엣이 배경에 묻힙니다.

---

## 7. 설계 문서와의 델타 (V10이 부록 A에 반영할 것)

| # | 설계 | 실제 | 근거 |
|---|---|---|---|
| 1 | 부록 B V3 "PNG 33 → 약 44장" | **53장** | 초과 9장은 전부 설계 **본문**이 요구하지만 부록 B 목록에 안 잡힌 것 — C+ 전용 시트(§3.1) · Thunder 5f 시트(부록 B ④를 `vfx-core` 덮어쓰기 대신 신규 파일로) · 상태 핍(§4.8) · 시너지(§4.8) · 텔레그래프(§3.1·§3.3) · 오버레이 2(§7.3) · 랜드마크 2(§2.3·§3.5) |
| 2 | 부록 B V3 "`build_assets.gd` 소유·파라미터화" | **`build_assets_v3.gd` 신설**, v2 빌더 무수정 | 오케스트레이터 지시("v2 빌드 산출물을 덮어쓰지 말고 v3 신규 파일로"). `v1-archive/build_assets_v2.gd.txt`와의 대조 가치도 보존된다 |
| 3 | §3.1 A = `DemonCyclop2`(색 지정 없음) | **HSV +128° 청록** | `mob-ogre`도 녹색 외눈이라 1스테이지 잡몹/보스 팔레트 충돌(실측). 이름·원소(서릿발·빙뇌)와도 정합. 되돌리기 1줄 |
| 4 | §3.1 B+ = "`_apply_tint` 자주" | **HSV 회전** | 곱연산은 소스에 없는 채널을 못 올린다 — `#79b8ce`의 R을 자주까지 곱해 올리면 다른 색이 표백된다 |
| 5 | §4.8 "8×8 색 사각" | **8×8 색 사각 + 실루엣 5종** | 5스테이지는 주기의 62%가 밤이라 색만으로는 구분이 죽는다. 코드 비용 한 줄 차이 |
| 6 | §7.2 "손댈 지점은 정확히 5곳" | 신규 파일이라 해당 없음 | 매핑은 `TERRAIN_BIOMES` 딕셔너리 한 곳에 모았다 |
| 7 | 설원 팔레트 `(208, 0)` | **미배정 · 예비** | v3 5단에 자리가 없다. ASSET_MAP §10에 좌표만 기록해 뒀다 |

**설계가 옳았음을 실측으로 재확인한 것**: `TilesetWater`의 4팔레트 블록 좌표 · `TilesetField` 5밴드 ·
보스 5종 전 애니 프레임 수 · `TenguRed/Trans.png` 11프레임 변신 · **"용암 팔레트는 존재하지 않는다"**.

---

## 8. 남은 위험

| 위험 | 크기 | 대응 |
|---|---|---|
| C/C+ 시트가 2460×1640 (각 ~73 KB) | 소 | 픽셀아트라 PNG 압축이 잘 먹는다. VRAM은 나눠서 8 MB 남짓 — 마왕 시트(1728×2880)를 이미 쓰고 있으므로 새 위험이 아니다 |
| `overlay-vignette.png`만 LINEAR 필터 | 소 | ASSET_MAP §14와 이 문서 §2에 명시. V5가 노드 하나에 `TEXTURE_FILTER_LINEAR`를 박으면 끝 |
| 텐구는 넓고 마왕은 높다 | 소 | 공격 프레임 130×92 vs 마왕 105×117. 폭은 텐구가 넓지만 **높이는 마왕이 압도**한다. 날개 짐승 vs 사무라이라 실루엣 성격도 다르다. V10 육안 판정 대상 |
| 셀 18·19가 심연에서 따뜻하게 남는다 | 소 | 의도(성 안팎 연속성 · 아레나 가시성). 그레이드 적용 후 눈에 거슬리지 않는 것까지 확인. 거슬리면 `TERRAIN_BIOMES`에 `floor_tint` 한 키만 추가하면 된다 |
| A의 `attack` 행 부재 | 중 | **V7이 반드시 알아야 한다.** 위 §2 V7 표와 ASSET_MAP §11에 명시. 대체안(`GiantBamboo`)도 살려 뒀다 |
