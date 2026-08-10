# art/v2 — Ninja Adventure 런타임 에셋 지도 (W11 + v3 + U0 + YA)

이 폴더의 PNG는 **전부 빌드 스크립트가 생성한 산출물**입니다. 직접 편집하지 마세요.
원본은 `art/external/ninja-adventure/`(CC0 · Pixel-boy & AAA)와 `art/external/kenney-particle-pack/`(CC0 · Kenney)이며
원본 폴더는 손대지 않았습니다.

빌더는 **네 개**이고 서로 파일명이 겹치지 않습니다.

| 빌더 | 굽는 것 | 산출 | 문서 |
|---|---|---:|---|
| `build_assets.gd` (W11) | v2 런타임 에셋 전부 | 33장 | 아래 **§0 ~ §8** |
| `build_assets_v3.gd` (v3) | 스테이지 지형 3벌 · 스테이지 보스 5시트 · 원소/상태/시너지 VFX · 텔레그래프 · 오버레이 · 랜드마크 2종 | 20장 | 아래 **§9 ~ §16** |
| `build_assets_ui.gd` (U0) | UI 재스킨 킷 — 패널/버튼/카드/리본 9-slice · 키캡 · 포인터 · 글리프 · 게이지 · 스포트라이트 마스크 | 10장 | 아래 **§17 ~ §18** + `docs/ui-style-v3.md` |
| `build_assets_y.gd` (YA) | 마왕 초상 2종 · 스킬 아이콘 28종 · 마왕 필드 시트 재슬라이스 · 장비 부위 4종 · 재화 4종 · 상자 6프레임 · VFX 3종 | 15장 | 아래 **§19 ~ §21** + `docs/handoff-ya.md` |

```bash
# 재생성 (원본 -> art/v2/*.png) — 순서 무관, 서로 파일을 안 덮는다
godot --headless --path godot-game --script res://art/v2/build_assets.gd
godot --headless --path godot-game --script res://art/v2/build_assets_v3.gd
godot --headless --path godot-game --script res://art/v2/build_assets_ui.gd
godot --headless --path godot-game --script res://art/v2/build_assets_y.gd

# 새 PNG를 Godot 리소스로 임포트 (.import 파일 생성/갱신)
godot --headless --path godot-game --editor --quit
```

매핑을 바꾸려면 각 빌더 상단의 상수표만 고치고 위 네 줄을 다시 돌리면 됩니다
(v2: `MOB_SHEETS` / `MOB_TINT` / `PLAYER_SHEETS` / `CASTLE_NPCS` / `_build_terrain()`의 `match cell`,
v3: `TERRAIN_BIOMES` / `BOSS_SHEETS` / `ELEMENT_VFX` / `PIP_GLYPH` / `SYNERGY_ROWS`,
U0: `TONES` / `TONE_ORDER` / `BUTTON_VARIANTS` / `CARD_KINDS` / `KEYCAP_KEYS` / `GLYPH_*`).

**결정성**: 두 빌더 다 난수·시각을 쓰지 않습니다. v3 빌더는 연속 2회 실행에서
**20장 전부 SHA-256 동일**을 확인했습니다(빌드 시간 약 0.3초).

---

## 0. 전 에셋 공통 규격

| 항목 | 값 | 근거 |
|---|---|---|
| 확대 | **nearest ×2** (마왕만 ×3, §4) | 화면에 두 가지 픽셀 크기가 섞이면 픽셀아트가 무너진다. 커 보여야 하는 것은 배율이 아니라 **원본 프레임 크기**로 커진다 |
| 합성 순서 | 16px 원본 좌표계에서 합성 → **마지막에 한 번만** ×2 | 확대 후 합성하면 픽셀 격자가 반 칸 어긋난다 |
| 4방향 열 순서 | **0=아래(정면) 1=위(뒤) 2=왼쪽 3=오른쪽** | NA 원본 시트 규약. 코드의 `_sprite_column()`이 이 순서를 전제한다 |
| 색 변조 | 시트 **아래 절반의 흰 실루엣 마스크**를 원하는 색·알파로 덧그린다 | ShaderMaterial을 쓰면 같은 `_draw()` 안의 체력바·게이지까지 물든다 |
| 텍스처 필터 | 각 노드 `_ready()`에서 `TEXTURE_FILTER_NEAREST` 명시 | project.godot 기본값도 Nearest지만 노드별로 못 박아 둔다 |

---

## 1. 지형 — `terrain-atlas-na.png` (160×128 · 5열×4행 · 셀 32×32)

`world_grid.gd`의 셀 번호 계약(`ATLAS_COLUMNS=5` / `ATLAS_ROWS=4`)은 v1과 **완전히 동일**합니다.
`wfc_chunk_generator.TILE_RULES`가 실제로 참조하는 셀은 12개뿐이고, 나머지 물가 8종은 회전(`turn`)으로 만듭니다.

| 셀 | 규칙 이름 | 원본 파일 | 소스 좌표(16px) | 비고 |
|---:|---|---|---|---|
| 0 | `grass` | `TilesetField.png` | (16, 64) | 바탕 #adbc3a. **물 타일셋의 물가 잔디와 바탕색이 완전히 같다**(히스토그램 확인) |
| 1 | `grass_tuft` | 0번 + `TilesetNature.png` | (64, 160) | 억새 뭉치 |
| 2 | `grass_flower` | 0번 + `TilesetNature.png` | (16, 176) | 노란 들꽃 |
| 3, 4 | (미사용) | `TilesetField.png` | (16, 64) | 잘못 참조돼도 안 깨지게 잔디로 채움 |
| 5 | `water` | `TilesetWater.png` | (16, 112) | 3×3 연못의 중앙 = 트인 물 |
| 6 | `shore_north` | `TilesetWater.png` | (16, 96) | 연못 위쪽 물가. `turn 1/2/3`으로 E/S/W 생성 |
| 7, 8, 9 | (회전으로 생성) | 〃 | 〃 | 셀 6과 같은 그림을 넣어 둠 |
| 12 | `shore_south_east` | `TilesetWater.png` | (32, 128) | 연못 우하 모서리(뭍이 E+S). `turn 1/2/3`으로 나머지 3모서리 |
| 10, 11, 13 | (회전으로 생성) | 〃 | 〃 | 셀 12와 같은 그림 |
| 14 | `bridge` | `TilesetWater.png` | (64, 208) | 나무 데크. 판자가 세로라 가로 3칸 다리에서 침목처럼 읽힌다 |
| 15 | `forest` | 0번 + `TilesetNature.png` | (0, 160) | 덤불 |
| 16 | `rocks` | 0번 + `TilesetNature.png` | (272, 272) + (304, 272) | 회색 바위 2덩이 겹침 |
| 17 | `ruins` (미사용) | `TilesetFloor.png` (16,16) + 바위 | — | `TILE_RULES` weight 0이고 호출부도 없음 |
| 18 | `courtyard` | `TilesetFloor.png` | (16, 16) | 성·마왕성 안전 바닥 |
| 19 | `camp` | `TilesetFloor.png` | (16, 128) | 균열 아레나 흙바닥 |

### 데코 외곽선 눅이기 (`_soften_outline`)

NA의 잔풀·꽃·덤불·바위는 거의 검은 외곽선을 두르고 있다. 원작에서는 레벨 디자이너가 드문드문 놓아서 문제가 없지만,
우리 WFC는 **잔디 타일의 19%를 데코로 채운다**(tuft 13 + flower 3.2 + forest 2.9 + rocks 1.6 / 총 가중치 90.7).
1차 캡처에서 들판 전체가 검은 낙서처럼 보였다. 그래서 셀 1·2·15·16·17과 `landmark-tree`에 한해
**밝기 0.20 미만인 픽셀만 진한 올리브(#454f21)로 치환**한다. 형태는 남고 대비만 내려간다.
물가·다리·바닥 셀은 원본 그대로 둔다(외곽선이 없다).

### 인셋: `ATLAS_CELL_INSET` 2 → **0**

v1 아틀라스는 셀마다 어두운 테두리가 구워져 있어 2px를 깎아야 했습니다(안 깎으면 화면 전체에 40px 격자 그물).
NA 타일셋은 애초에 이어 붙이라고 만든 것이라 테두리가 없습니다. **1px이라도 깎으면 물가의 흰 포말 선이 잘려
호수 가장자리가 두 번 끊겨 보이므로 0이 정답**입니다.

번짐 걱정은 없습니다 — 32px 소스를 40px로 늘릴 때 목적지 픽셀 중심은 소스 `[L+0.4, L+31.6]` 안에만 떨어져서
옆 셀을 샘플링하지 않습니다(`center = L + (i+0.5)*32/40`, i∈[0,39]).

---

## 2. 플레이어 — `player-swordsman.png` / `player-archer.png` / `player-mage.png` (각 128×384)

- 위 절반(y 0~191) = 그림, 아래 절반(y 192~383) = 흰 실루엣 마스크
- 셀 32×32 · 열 = 방향 4 · 행 = **0~3 걷기 / 4 대기 / 5 공격**

| character_id | 원본 |
|---|---|
| `swordsman` 왕국 검사 | `Actor/Character/Knight/SeparateAnim/` (판금 기사 + 검 휘두르기) |
| `archer` 방랑 궁사 | `Actor/Character/Hunter/SeparateAnim/` |
| `mage` 별빛 마법사 | `Actor/Character/SorcererOrange/SeparateAnim/` |

`SeparateAnim`을 고른 이유: 통합 `SpriteSheet.png`(64×112)보다 슬라이싱이 안전하고
Walk/Idle/Attack이 이미 분리돼 있어 행 의미가 흔들리지 않습니다.

---

## 3. 몹 10종 + 내려간 3종 — `mob-<visual>.png` (각 128×256)

키는 `monster_library.gd`의 `visual` 값입니다. 셀 32×32 · 열 = 방향 4 · 행 = 걷기 프레임 4.
색 보정은 **런타임 modulate가 아니라 빌드 때 곱연산으로 구워** 두었습니다(밤 변이·피격 플래시가 쓰는 modulate 예산과 겹치지 않게).

| id | 이름 | visual | 원본 (`Actor/`) | 구운 색보정 | 선택 근거 |
|---|---|---|---|---|---|
| `mossling` | 이끼콩 | `blob` | `Monster/Larva` | — | 이끼색 마디벌레. 이름 그대로 "콩" 실루엣 |
| `boar` | 들멧돼지 | `boar` | `Monster/Bear` | — | `Animal/WildBoar`가 생김새는 완벽하지만 **측면 2프레임뿐**. 4방향 일관성을 우선해 곰형 돌진 짐승으로 대체 |
| `imp` | 뿔임프 | `imp` | `Monster/Beast` | — | 붉은 뿔 악마. 집단반격 종의 대표 실루엣 |
| `wolf` | 붉은 늑대 | `wolf` | `Monster/Racoon` | ×(1.30, 0.70, 0.62) | 4방향 사족 포식자 중 늑대에 가장 가까운 실루엣. 붉게 구워 이름과 맞춤 |
| `skeleton` | 떠도는 해골 | `skeleton` | `Monster/Skull` | — | `Character/Skeleton`(전신)보다 **떠다니는 두개골**이 "떠도는"에 부합하고 4×4 규격도 통일된다 |
| `shade` | 굶주린 그림자 | `shade` | `Monster/Spirit` | ×(0.66, 0.58, 0.86) | 흰 유령을 창백한 보라로 구워 그림자화 |
| `wisp` | 푸른 위습 | `wisp` | `Monster/Flam2` | — | 이름까지 일치하는 푸른 불꽃 정령 |
| `ogre` | 황야 오우거 | `ogre` | `Monster/Cyclope2` | — | 녹색 외눈 거구. 프레임을 꽉 채워 반경 18.75와 균형이 맞는다 |
| `cultist` | 월식 주술사 | `cultist` | `Character/SorcererBlack/SeparateAnim/Walk` | ×(0.82, 0.78, 1.00) | `Monster/`에 후드 술사가 없음. **Character의 Walk.png가 몹 시트와 완전히 같은 64×64 4×4 규격**이라 규격 통일이 깨지지 않는다 |
| `hellhound` | 밤의 지옥견 | `hellhound` | `Monster/Grey Trex` | ×(0.92, 0.40, 0.44) | `Animal/DogBlack`은 측면 2프레임. 4방향 사족 야수 중 `Racoon`(늑대가 씀)과 **실루엣이 겹치지 않는** 유일한 대형 포식자 |
| — | (내려감) | `bat` | `Monster/BlueBat` | — | v2에서 빠진 `cave_bat`. variant 분기 총망라 유지용 |
| — | (내려감) | `beetle` | `Monster/Mollusc` | — | v2에서 빠진 `iron_beetle` |
| — | (내려감) | `ooze` | `Monster/Slime2` | — | v2에서 빠진 `royal_ooze` |

내려간 3종의 시트를 남긴 이유: `enemy.gd`의 variant 분기가 총망라를 유지해야 미등록 종이 스폰돼도 크래시가 나지 않습니다.

---

## 4. 마왕 — `boss-demon-king.png` (1728×2880)

원본 `Actor/Boss/GiantRedSamurai` — 초승달 투구를 쓴 붉은 마검사. **검사 vs 마왕** 구도에 최적입니다.

- 위 절반(y 0~1439) = 그림, 아래 절반(y 1440~2879) = 흰 실루엣 마스크
- 셀 **144×288**, 12열 × 5행 (다른 에셋과 달리 ×3으로 구웠다 — 아래 참조)

| 행 | 애니메이션 | 프레임 | 원본 프레임 |
|---:|---|---:|---|
| 0 | Idle | 12 | 48×48 |
| 1 | Walk | 12 | 48×48 |
| 2 | Hit | 8 | 48×48 |
| 3 | AttackRight | 8 | 48×96 |
| 4 | AttackLeft | 8 | 48×96 |

48×48 애니는 셀 **아래쪽에 붙여** 구웠습니다. 공격 프레임은 검이 위로 48px 더 크기 때문에,
바닥 정렬을 맞춰야 대기↔공격 전환에서 마왕이 위아래로 튀지 않습니다.

### 마왕만 ×3 — 전 에셋 중 유일한 배율 예외

원본 프레임은 48px지만 **사무라이 몸통은 그 안에서 26px밖에 안 됩니다.** ×2로 구우면 화면상 약 52×60px가 되어
반지름 58(지름 116px) 히트박스의 절반도 못 채웁니다. 1차 캡처에서 최종 보스가 플레이어의 1.7배로만 보였습니다.
픽셀 크기 불일치보다 이쪽이 큰 손해라고 판단해 마왕 시트만 ×3(셀 144×288)으로 굽습니다.
`enemy.gd`의 `BOSS_CELL` / `BOSS_MASK_OFFSET` 상수 두 개가 이 값을 들고 있습니다.

---

## 5. VFX

| 파일 | 크기 | 구성 | 원본 |
|---|---|---|---|
| `vfx-core.png` | 256×256 | 4행 × 4프레임 · 셀 64×64 | 행0 `FX/Attack/SlashCurved` · 행1 `FX/Attack/CircularSlash` · 행2 `FX/Magic/Circle/SpriteSheetWhite` · 행3 `FX/Elemental/Thunder` |
| `vfx-explosion.png` | 720×80 | 9프레임 80×80 | `FX/Elemental/Explosion` — **원본이 40×40이라 40px 타일 격자와 정확히 맞는 유일한 시트** |
| `vfx-projectile.png` | 128×32 | 4프레임 32×32 | `FX/Projectile/Fireball` — 원본이 -Y라 빌드 때 90도 돌려 +X로 통일 |
| `vfx-energyball.png` | 128×32 | 4프레임 32×32 | `FX/Projectile/EnergyBall` — 위와 같이 +X로 회전 |
| `vfx-arrow.png` | 26×10 | 1프레임 | `FX/Projectile/Arrow` — 원본이 이미 +X |
| `vfx-blade.png` | 70×18 | 1프레임 | `FX/Projectile/BigKunai` — 원본이 이미 +X |
| `vfx-shield.png` | 288×52 | 6프레임 48×52 | `FX/Magic/Shield/SpriteSheetBlue` |
| `vfx-smoke.png` | 384×64 | 6프레임 64×64 | `FX/Smoke/Smoke` |

### ⚠️ 방향 축 (v1 교훈)

`cycle_skill_effect.gd`의 `VFX_SLASH_SOURCE_DIRECTION`는 **원본 스프라이트가 향하는 축**입니다.
v1 생성 아틀라스는 `Vector2.LEFT`였지만 **NA 참격은 `+X`(오른쪽)를 향합니다.**
그래서 W11에서 `Vector2.RIGHT`로 바꿨습니다. 이 축이 어긋나면 v1처럼 이펙트가 180° 뒤집힙니다.

NA 투사체는 **시트마다 기준축이 다릅니다** — `Arrow`·`BigKunai`는 +X인데 `Fireball`·`EnergyBall`은 -Y(위)입니다.
런타임에 시트별로 축을 기억하는 건 딱 v1이 밟은 지뢰라서, `build_assets.gd`의 `_rotate_square_frames_cw()`가
**빌드 단계에서 전부 +X로 돌려 굽습니다.** 코드가 지킬 규칙은 "모든 방향성 VFX는 +X를 향한다" 한 문장뿐입니다.

`effect_color` modulate는 곱연산이라 철·혈처럼 어두운 원소색을 폭발 시트에 그대로 곱하면 주황 불덩이가
진흙색으로 죽습니다(1차 캡처에서 실제로 그랬습니다). 폭발만 `_vfx_flame_tint()`가
`Color.WHITE.lerp(effect_color, 0.45)`로 밝기를 지키고 색조만 입힙니다.

원소별(철/빙/뇌/광/혈/화) 구분은 **스프라이트 교체가 아니라 `effect_color` modulate**로 합니다.
NA 참격·마법진은 흰색 계열이라 색이 잘 물들고, 20종 스킬이 같은 시트를 공유해도 서로 구분됩니다.

---

## 6. 월드 랜드마크 · 성 내부

| 파일 | 크기 | 합성 내용 |
|---|---|---|
| `landmark-castle.png` | 256×176 | `TilesetHouse`(128,0,64,48) 아치 성채 + `TilesetTowers`(0,64,32,32) 석탑 ×2 |
| `landmark-demon-castle.png` | 256×176 | `TilesetVillageAbandoned`(192,96,64,80) 이끼 낀 검은 성채 + `TilesetTowers`(288,32,32,32) 붉은 뿔탑 ×2 |
| `landmark-ruin.png` | 128×96 | `TilesetVillageAbandoned`(0,0,64,48) 무너진 이끼 석벽 |
| `landmark-tree.png` | 64×64 | `TilesetNature`(0,0,32,32) 나무 1그루 (`_draw_grove`가 5그루 배치) |
| `landmark-chest.png` | 32×32 | `Items/Treasure/LittleTreasureChest` 닫힘 프레임 |
| `castle-floor.png` | 32×32 | `TilesetFloor`(16,16) — 지형 셀 18과 같은 원본이라 성 안팎이 이어진다 |
| `castle-npcs.png` | 192×64 | 열 0 `Villager`(카드상) · 1 `Master`(각인 세공사) · 2 `Noble`(계약자) · 3 `NinjaDark`(밀정) · 4 `OldMan`(기타) · 5 `Princess`(예비). 전부 `SeparateAnim/Idle.png` 정면 프레임 |

랜드마크는 **밑변 기준**으로 놓습니다(`world_grid._draw_landmark`). 세로 중심을 기준으로 놓으면 지형 위에 떠 보입니다.
밤 색조(`_landmark_tint()`)도 타일과 같은 값을 씁니다 — 지형만 어두워지면 성이 화면에서 떠 버립니다.

---

## 7. 교체하지 **않은** 것 (판단과 근거)

| 대상 | 결정 | 근거 |
|---|---|---|
| 스킬 아이콘 `art/generated/ui/skill-atlas-minimal-v2-runtime.png` | **v1 유지** | NA `Ui/Skill Icon/Spell/` 32종에는 딜싸이클의 핵심 개념(회귀·도약·재실행·과열·빚)에 대응하는 그림이 **하나도 없다**. 20종 카드에 임의 배정하면 아이콘이 정보를 잃는다. 반대로 v1 아이콘은 카드 의미(달+검, 발톱, 불 고리, 회오리, 낙뢰, 검비)에 맞춰 그려졌고 40px·24px 양쪽에서 판독된다 |
| 아이템 아이콘 `item-atlas-minimal-v2-runtime.png` | **v1 유지** | 위와 같은 이유. NA `Items & Weapon` 아이콘은 12종뿐이라 장비 풀을 못 덮는다 |
| HUD 아틀라스 `factory-hud-atlas-minimal-v2-runtime.png` | **v1 유지** | 어두운 HUD 팔레트에 맞춰 만든 것. NA 나무 테마 9-patch로 갈면 HUD 전체 레이아웃을 다시 짜야 하고 W5가 세운 좌표 계약이 흔들린다 |
| 로비 배경 `backgrounds/lobby-minimal-v2.png` | **v1 유지** | 이미 픽셀아트이고, 달빛 평원 · 왼쪽 성 · 오른쪽 마왕성 · 검을 든 주인공이라는 **이 게임의 구도 그 자체**다. NA 타일로 만든 탑다운 잔디밭은 타이틀 컷으로 열등하다. 타이틀 일러스트가 인게임보다 고해상도인 것은 픽셀아트에서 표준 관례다 |
| 캐릭터 선택 카드 `characters/*-card-minimal-v2.png` | **v1 유지** | 로비와 같은 화법의 초상 카드. 16px 스프라이트를 확대해 넣으면 정보량이 줄어든다 |
| `art/generated/` 전체 · `art/external/` 원본 | **삭제 안 함** | 참조만 끊었다. 되돌리려면 preload 경로 한 줄씩만 바꾸면 된다 |

---

## 8. 크레딧

전부 **CC0 (Public Domain)** 라 표기 의무는 없지만, 미덕으로 남깁니다.

- **Ninja Adventure Asset Pack** — Pixel-boy & AAA (https://pixel-boy.itch.io/ninja-adventure-asset-pack) · CC0
- **Kenney Particle Pack** — Kenney (https://kenney.nl) · CC0

상세 출처·라이선스 원문은 `art/external/LICENSES.md` 참조.

---
---

# Part II — v3 산출물 (`build_assets_v3.gd` · 20장)

설계 근거: `docs/GAME_DESIGN_V3.md` §3(보스 3종) · §4.3~§4.8(상태이상·시너지) · §7(그래픽 가중치) · 부록 B V3.
상수 근거: `scripts/core/tuning.gd`의 **V3-N 블록**(`STAGE_TERRAIN_ATLAS` `STAGE_DAY_MODULATE`
`STAGE_NIGHT_MODULATE` `STAGE_FOG_ALPHA` `STAGE_SATURATION` `STAGE_GREEN_OVERLAY_ALPHA` `STAGE_VIGNETTE`).

## 9. v3 공통 규격 — v2에서 이어받은 것과 새로 정한 것

| 항목 | 값 | 근거 |
|---|---|---|
| 확대 | **nearest ×2** (오버레이 2장만 ×1) | v2 규칙 그대로. 마왕 ×3 예외도 그대로 유지 |
| 합성 순서 | 원본 좌표계에서 합성 → 마지막에 한 번만 정수배 | v2 규칙 그대로 |
| 방향축 | 방향성 VFX는 **빌드 단계에서 +X** | v2 규칙 그대로. v3 신규 VFX는 전부 무방향(방사·장판) |
| **색 변종** | 곱연산이 아니라 **HSV 회전** | 곱연산은 소스에 없는 채널을 못 올린다. 청색 점액(#79b8ce)의 R을 0xbc까지 곱해 올리면 다른 색까지 표백된다. HSV 회전은 명도 대비를 그대로 보존한다 |
| **hue_keep** | 보스 `Hit.png`의 피격 섬광(주황 #ff9554 · 색상 24°)은 회전에서 제외 | 같이 돌리면 **서릿발 외눈이 초록으로 번쩍인다**(1차 빌드 실측 — 3프레임 Hit 행의 첫 프레임이라 피격마다 1/3이 초록이었다). 피격 섬광은 원소와 무관한 신호라 따뜻한 색이 맞다 |
| **Kenney 파티클** | 합성 단계에서만 bilinear 축소 | 512px 소프트 알파를 40~55px로 줄여 쓴다. 최종 정수배는 여전히 nearest라 픽셀 격자는 안 깨진다 |

---

## 10. 지형 3벌 — `terrain-atlas-{verdant,waste,abyss}.png` (각 160×128 · 5열×4행 · 셀 32×32)

`world_grid.gd`의 셀 번호 계약(`ATLAS_COLUMNS=5` / `ATLAS_ROWS=4` / `ATLAS_CELL_INSET=0`)은
v2 아틀라스와 **한 글자도 다르지 않습니다.** 벌만 늘었습니다.

> **`terrain-atlas-verdant.png`는 `terrain-atlas-na.png`와 바이트 단위로 동일합니다**(검증됨).
> V5는 v2 아틀라스를 지우지 않고 그대로 둔 채 딕셔너리 참조만 갈아끼우면 됩니다.

### 실측 정정 — 소스 팔레트는 4종이고 "용암"은 없다

`TilesetWater.png`(448×272) 안에 **동일 레이아웃 3×3 물가 블록이 4벌** 실재합니다(직접 크롭해 확인).
블록 내부 상대 좌표는 4벌 모두 같습니다 — 트인 물 `+(16,16)` / 위쪽이 뭍인 물가 `+(16,0)` / 우하 모서리 `+(32,32)`.

| 블록 | origin | 뭍 바탕 | 액체 | v3 배정 |
|---|---|---|---|---|
| 잔디 | (0, 96) | `#adbc3a` | `#71ddee` 청록 | **verdant** |
| 모래 | (0, 0) | `#ffad5d` | `#71ddee` 청록 | **waste** |
| 설원 | (208, 0) | `#ffffff` | `#d4f5fa` 빙판 | **미배정 · 예비** |
| 자주 | (208, 96) | `#b3957f` | `#bc84b5` **자주** | **abyss** |

`INVENTORY.md` L110의 "용암/보라" 병기는 과장입니다 — **용암 팔레트는 존재하지 않습니다.**
설계 §7.1의 정정을 그대로 따라 자주(`#bc84b5`)를 심연에 씁니다.

### 바탕색 정합 (호수 가장자리에서 색이 튀지 않게)

물가 블록의 **뭍 바탕색**과 `TilesetField.png`(80×240 · 5밴드) 바탕색을 히스토그램으로 맞췄습니다.

| 아틀라스 | water_origin | grass_src (TilesetField) | 바탕 곱 | 결과 바탕 | 데코 곱 | 외곽선 |
|---|---|---|---|---|---|---|
| `verdant` | (0, 96) | `Rect2i(16,64,16,16)` 잔디 `#adbc3a` | — | `#adbc3a` **정확히 일치** | — | `#454f21` |
| `waste` | (0, 0) | `Rect2i(16,16,16,16)` 모래 `#ffad5d` | — | `#ffad5d` **정확히 일치** | ×(0.94,0.84,0.62) | `#59451f` |
| `abyss` | (208, 96) | `Rect2i(16,160,16,16)` 살구 `#ffcba9` | ×(0.702,0.729,0.749) | `#b3957f` **정확히 일치** | ×(0.58,0.54,0.70) | `#33293f` |

살구 → 자주 블록 뭍의 곱 계수는 눈대중이 아니라 `0xb3/0xff, 0x95/0xcb, 0x7f/0xa9`를 계산한 값입니다.

### 셀 대응표 (3벌 공통 · W = water_origin)

| 셀 | 규칙 | 소스 |
|---:|---|---|
| 0, 3, 4 | `grass` / 예비 | `TilesetField` **grass_src** (바탕 곱 적용) |
| 1 | `grass_tuft` | 바탕 + `TilesetNature`(64,160) 억새 (데코 곱) |
| 2 | `grass_flower` | 바탕 + `TilesetNature`(16,176) 들꽃 (데코 곱) |
| 5 | `water` | `TilesetWater` **W + (16,16)** |
| 6~9 | `shore_north` (6만 실사용) | `TilesetWater` **W + (16,0)** |
| 10~13 | `shore_south_east` (12만 실사용) | `TilesetWater` **W + (32,32)** |
| 14 | `bridge` | `TilesetWater`(64,208) — **3벌 공용**. 사람이 놓은 나무판이라 바이옴이 바뀌어도 같은 게 맞다 |
| 15 | `forest` | 바탕 + `TilesetNature`(0,160) 덤불 (데코 곱) |
| 16 | `rocks` | 바탕 + `TilesetNature`(272,272)+(304,272) (데코 곱) |
| 17 | `ruins`(미사용) | `TilesetFloor`(16,16) + 바위 |
| 18 | `courtyard` | `TilesetFloor`(16,16) — **바이옴 틴트 없음** |
| 19 | `camp` | `TilesetFloor`(16,128) — **바이옴 틴트 없음** |

**셀 18·19를 물들이지 않은 이유**: 18은 `castle-floor.png`와 같은 원본이어야 성 안팎이 이어집니다(§6 계약).
19는 균열/캠프 아레나 바닥이고, 아레나는 원래 눈에 띄어야 합니다. 심연에서 따뜻한 돌 바닥이
섬처럼 남는 것은 "안전 지대"로 읽히므로 손해가 아닙니다. 런타임 그레이드가 어차피 눌러 줍니다(육안 확인함).

### 5단 톤 — 아틀라스 3벌 × 런타임 그레이드 (설계 §7.3 · V5가 배선)

**아틀라스만으로 5단을 만들지 않습니다.** 소스 팔레트가 4종뿐이라 5벌은 애초에 불가능하고,
낮/밤 길이 자체가 그래픽 가중치의 절반입니다(5스테이지는 한 주기의 62%가 밤).

| 스테이지 | 이름 | 아틀라스 | 낮/밤(초) | 주간 modulate | 야간 modulate | 채도 | 안개 α | 녹색 α | 비네트 |
|---:|---|---|---|---|---|---:|---:|---:|:--:|
| 1 | 왕국 변경 | `verdant` | 72/45 | `#ffffff` | `#8995c9` | 1.00 | 0.00 | 0.00 | — |
| 2 | 시든 숲 | `verdant` | 68/52 | `#e3ddc8` | `#6d7aa8` | 0.88 | 0.00 | 0.00 | — |
| 3 | 잿빛 벌판 | `waste` | 62/60 | `#d9c3a3` | `#5a5c86` | 1.00 | 0.10 | 0.00 | — |
| 4 | 역병의 늪 | `waste` | 56/68 | `#b8b48c` | `#48547a` | 1.00 | 0.16 | 0.08 | — |
| 5 | 심연 | `abyss` | 48/78 | `#8a7794` | `#2f2f52` | 0.65 | 0.24 | 0.00 | ✔ |

**육안 검증 완료** — 5단 × 낮/밤 10컷을 실제 아틀라스에 그레이드를 먹여 렌더해 확인했습니다.
1·2단(초록·바랜 초록), 3·4단(모래·늪), 5단(자주 회색)이 명확히 구분되고,
가장 어두운 **5단 밤**에서도 물/뭍 경계선과 흰 포말, 다리 판자, 데코 실루엣이 전부 판독됩니다.

---

## 11. 스테이지 보스 5시트 (설계 §3.1 · V7이 소비)

전부 `_with_mask` 규약(위 절반 그림 / 아래 절반 흰 실루엣) — v2 마왕 시트와 동일합니다.

### 배율 판단 — **스테이지 보스는 전부 ×2, 마왕만 ×3(v2 유지)**

불투명 bbox 실측 → 화면 몸통 크기:

| 대상 | 원본 프레임 | 몸통 bbox | 배율 | 화면 몸통 |
|---|---|---|---:|---|
| 몹 전체 | 16×16 | — | ×2 | 32×32 셀 |
| A 외눈 | 50×50 | 37×33 | **×2** | 74×66 |
| B/B+ 점액 | 62×52 | 40×22 (점프 정점 38×38) | **×2** | 80×44 |
| C/C+ 천구 | 82×82 | 53×33 (공격 65×46) | **×2** | 106×66 (공격 130×92) |
| 마왕 | 48×48 | 35×39 | ×3 (v2) | **105×117** |

×3으로 구우면 외눈이 111×99가 되어 마왕(105×117)과 붙습니다. **최종 보스의 유일성이
배율에서 깨지는 것**이 픽셀 크기 통일보다 큰 손해라고 판단했습니다. 덤으로 ×2는 몹과 같은
배율이라 화면에 세 번째 픽셀 크기가 생기지 않습니다(마왕 ×3 하나만 예외로 남습니다).

### 시트 규격표 (V7이 그대로 상수로 옮기면 되는 값)

| 파일 | 로테이션 | 전체 | 셀(px) | 열 | 행 | 마스크 offset.y | `foot_inset` |
|---|---|---|---|---:|---:|---:|---:|
| `boss-frost-cyclops.png` | **A** · 1스테이지 | 600×600 | 100×100 | 6 | 3 | 300 | 14 |
| `boss-plague-slime.png` | **B** · 2스테이지 | 1612×624 | 124×104 | 13 | 3 | 312 | 12 |
| `boss-black-slime.png` | **B+** · 4스테이지 | 1612×624 | 124×104 | 13 | 3 | 312 | 12 |
| `boss-crimson-tengu.png` | **C** · 3스테이지 | 2460×1640 | 164×164 | 15 | 5 | 820 | 48 |
| `boss-black-tengu.png` | **C+** · 5스테이지 | 2460×1640 | 164×164 | 15 | 5 | 820 | 48 |
| `boss-demon-king.png` (v2) | 마왕 | 1728×2880 | 144×288 | 12 | 5 | 1440 | 0 |

`foot_inset` = **셀 바닥에서 스프라이트 접지선까지의 거리(저장 px)**. 마왕은 셀 아래쪽 정렬로
구워서 0이지만, v3 보스는 원본 프레임을 통째로 복사해 원작자 정렬을 보존했으므로 값이 있습니다.
그리기 식:

```gdscript
destination = Rect2(-CELL.x * 0.5, foot + FOOT_INSET - CELL.y, CELL.x, CELL.y)
# 이러면 스프라이트 접지선이 정확히 y = foot 에 놓인다.
```

### 행 배정 (행 0/1/2 = Idle/이동/Hit — 마왕과 같은 우선순위 로직을 그대로 쓸 수 있다)

| 시트 | 행0 | 행1 | 행2 | 행3 | 행4 | `walk_row` | `attack_row` |
|---|---|---|---|---|---|---:|---:|
| frost-cyclops | Idle 5f | Walk 6f | Hit 3f | — | — | 1 | **없음(-1)** |
| plague-slime | Idle 5f | **Jump 13f** | Hit 5f | — | — | 1 | 1 |
| black-slime | Idle 5f | **Jump 13f** | Hit 5f | — | — | 1 | 1 |
| crimson-tengu | Idle 6f | Walk 10f | Hit 8f | **Attack 15f** | **Trans 11f** | 1 | 3 |
| black-tengu | Idle 6f | Walk 10f | Hit 8f | **Attack 15f** | **Trans 11f** | 1 | 3 |

- **A는 Attack 행이 없습니다**(원본에 없음). 설계 §3.1대로 공격은 **발구름 → 바닥 링**이며
  사지 애니메이션이 필요 없습니다 → `vfx-telegraph-ring.png` 행0(`expand`) + 보스 스케일 펄스.
- **점액은 Walk가 없습니다.** 슬라임의 이동은 곧 점프이므로 행1이 이동이자 공격입니다(설계 §3.3 B-1 "도약 압살").
- **`Trans` 11f는 C+ 등장 연출 전용**입니다(설계 §3.1). 소형→대형 변신이 프레임 안에서 완결됩니다
  (f0 몸통 16×16 → f6 65×57 → f10 53×33 정착). C 시트에도 같은 행이 들어 있어 필요하면 재사용 가능합니다.

### 색 변종

| 시트 | 원본 | HSV (색상°, 채도×, 명도×) | hue_keep | 판단 |
|---|---|---|---|---|
| frost-cyclops | `Boss/DemonCyclop2` (녹색) | **(+128, 0.82, 1.02)** | 0~40° | 원본이 녹색인데 **`mob-ogre`(`Monster/Cyclope2`)도 녹색 외눈**이라 1스테이지에서 잡몹과 보스의 팔레트·실루엣이 겹친다(실측). 이름이 서릿발이고 패턴이 빙+뇌다 → 청록으로 회전. 되돌리려면 `(0,1,1)` 한 줄 |
| plague-slime | `Boss/GiantSlime2` (녹색·붉은 눈) | (0, 1.00, 1.00) | — | 이미 독의 색. 무보정 |
| black-slime | `Boss/GiantSlime` (청색) | **(+118, 1.05, 0.80)** | 0~40° | 설계 §3.1 "자주 틴트". 청색 → 자주 + 한 단계 어둡게 |
| crimson-tengu | `Boss/TenguRed` | (0, 1.00, 1.00) | — | 무보정 |
| black-tengu | `Boss/TenguRed` | **(−14, 0.58, 0.60)** | — | 명도 0.52까지 눌러 봤더니 스테이지 5의 `#2f2f52` + 안개 α0.24 + 비네트를 먹고 나면 실루엣이 배경에 묻힌다. **0.60이 하한** |

**대체 후보(설계 §3.1)**: A가 플레이테스트에서 밋밋하면 `Boss/GiantBamboo`
(62×62 균일 · Idle 6 / Walk 12 / Attack 5 / Hit 4 / Charge 3 — 실측 확인)로 교체합니다.
`BOSS_SHEETS["frost-cyclops"]`의 `dir` / `frame` / `rows`만 갈아끼우면 되고 파이프라인 변경은 0입니다.

### V7 참고 — 권장 히트박스 반경 (결정권은 V7)

몸통 폭의 절반 + 여유: A **38** · B/B+ **40** · C/C+ **48** · 마왕 58(v2 유지).
바닥 그림자 사각은 `Rect2(-radius, radius*0.72, radius*2, 14)` 정도가 v2 마왕(`-58,42,116,18`)과 비례가 맞습니다.

---

## 12. 원소 VFX 5벌 — `vfx-element-*.png` (전부 셀 **80×80** · 1행)

**셀을 80으로 통일한 것이 이 묶음의 핵심**입니다. 기존 `vfx-explosion.png`의 셀이 정확히 80이라
`cycle_skill_effect.gd`가 이미 가진 `VFX_EXPLOSION_CELL := 80.0` **하나로 5벌을 전부 그릴 수 있습니다**.
40px 소스 셀은 타일 한 칸과 같아서 장판 판정과 그림이 어긋나지 않습니다.

**앵커 = 셀 중앙.** v2 VFX 렌더러가 전부 `origin - box * 0.5`로 그리므로 중앙 정렬이 아니면
V6가 시트마다 앵커를 기억해야 합니다. 프레임은 40×40 셀 가운데에 놓았습니다.

| 파일 | 원소 | 크기 | 프레임 | 원본 | 원본 프레임 | HSV | 비고 |
|---|---|---|---:|---|---|---|---|
| `vfx-element-ice.png` | `ice` 빙 | 800×80 | 10 | `FX/Elemental/Ice/SpriteSheet` | 32×32 | (0,1,1) | 무보정 |
| `vfx-element-poison.png` | `poison` 독 | 640×80 | 8 | `FX/Elemental/Plant/SpriteSheet` | 30×28 | **(+26, 1.45, 0.92)** | 전용 독 시트가 소스에 없다(실측). −14°(황록)로 돌려 봤더니 그냥 노랗게 떠서 "빛"으로 읽혔다 → +26°(에메랄드) + 채도 상향 |
| `vfx-element-flame.png` | `fire` 화 | 400×80 | 5 | `FX/Elemental/Flam/SpriteSheet` | 40×30 | (0,1,1) | 무보정 |
| `vfx-element-oil.png` | `oil` 유 | 880×80 | 11 | `FX/Elemental/Water/SpriteSheet` | 40×33 | **(+112, 0.40, 0.30)** | **기름 전용 시트 없음**(실측). −38°로 돌리면 올리브가 되어 "진흙"으로 읽혔다 → +112°(자주) · 채도 0.40. 완전 무채색이면 밤 지형에 묻히고, 채도가 높으면 독과 헷갈린다 |
| `vfx-element-thunder.png` | `thunder` 뇌 | 400×80 | 5 | `FX/Elemental/Thunder/SpriteSheet` | 32×28 | (0,1,1) | v2 `vfx-core` 행3은 4프레임만 썼다. **미사용 5번째 프레임을 편입**(설계 부록 B V3 ④). `vfx-core.png`는 v2 산출물이라 덮지 않고 별도 시트로 뺐다 |

`strike` 타 / `psi` 초는 **상태를 만들지 않는 소비자**(설계 §4.4 설계 의도 1)라 전용 원소 시트가 없습니다.
기존 `vfx-core.png` 행0(참격) · 행2(마법진)를 `effect_color`로 물들여 씁니다.

---

## 13. 상태 핍 · 시너지 · 텔레그래프

### 13-1. `vfx-status-pips.png` (80×32 · 셀 16×16 · 5열 · 마스크 offset.y = 16)

설계 §4.8은 "8×8 색 사각"이라고만 적었습니다. 사각 5개는 **야간 틴트에서 구분이 죽습니다**
(5스테이지는 주기의 62%가 밤이고 `CanvasModulate`가 `#2f2f52`). 같은 8×8 예산 안에서
**실루엣까지 다르게** 만들어 색이 다 죽어도 모양으로 읽히게 했습니다. 코드 비용은
`draw_rect` → `draw_texture_rect_region` 한 줄 차이입니다.

| 열 | 상태 | 한글 | 실루엣 | 본색 | 외곽선 |
|---:|---|---|---|---|---|
| 0 | `poison` | 독 | **원** | `#83c65c` `GamePalette.GREEN` | `#10151f` |
| 1 | `burn` | 연 | **위로 뾰족한 불꽃** | `#e78a45` `ORANGE` | `#10151f` |
| 2 | `chill` | 한 | **마름모** | `#67c7d4` `CYAN` | `#10151f` |
| 3 | `oil` | 유 | **아래로 뾰족한 방울** | `#1b1622` 흑유 | `#8a7fa3` **밝게** — 검은 방울에 어두운 외곽선을 두르면 사라진다 |
| 4 | `shock` | 전 | **지그재그 번개** | `#f4d35e` `YELLOW` | `#10151f` |

색은 설계 §4.8의 "독 녹 / 연 주 / 한 청 / 유 흑 / 전 황"을 `GamePalette` 값으로 못 박은 것입니다.
아래 절반의 흰 마스크는 "상태 강조 플래시"를 색 없이 흰색으로 덧그리기 위한 것으로,
몹·보스 시트와 완전히 같은 규약입니다. 최대 3개 표시(`tuning.STATUS_PIP_MAX`)는 V6가 지킵니다.

### 13-2. `vfx-synergy.png` (768×480 · 셀 96×96 · 8열 × 5행)

각 행 = **Kenney 소프트 글로우(팽창·감쇠) 위에 NA 픽셀 프레임**. 픽셀아트만으로는
"지금 특별한 게 터졌다"가 안 읽히고, Kenney만 쓰면 스타일이 깨집니다. 글로우는 아래 깔고
픽셀 프레임을 위에 얹어 **실루엣은 항상 픽셀아트**가 되게 했습니다.
글로우: 셀의 0.45배 → 1.15배로 팽창, 알파 `(1-t)² × 0.78`.
NA 원본 프레임 수는 `floori(i × n / 8)`로 8프레임에 리샘플합니다 — **고르기만 하고 보간하지 않습니다**.

| 행 | 시너지 | 매트릭스 칸 | NA 소스 | Kenney | 글로우 색 |
|---:|---|---|---|---|---|
| 0 | **★대폭 연소** | `fire` ↓ × `oil` → | `FX/Elemental/Explosion` 9f | `light_01` | `#ff852a` |
| 1 | **★전도** | `thunder` ↓ × `chill` → | `FX/Elemental/Thunder` 5f | `light_03` | `#94dbff` |
| 2 | 역병 발화 | `fire` ↓ × `poison` → | `FX/Elemental/Plant` 8f (+26°) | `smoke_04` | `#85f252` |
| 3 | 쇄빙 | `strike` ↓ × `chill` → | `FX/Elemental/Ice` 10f | `star_08` | `#b8edff` |
| 4 | 정신 붕괴(psi 수확) | `psi` ↓ × 전 상태 | `FX/Magic/Circle/SpriteSheetWhite` 4f | `light_02` | `#c799ff` |

★ = 사용자가 명시적으로 요구한 두 조합(설계 §4.4).
남은 시너지 3종(증기 · 감전 유막 · 터뜨리기)은 전용 행이 없습니다 — 각각
`vfx-element-flame` / `vfx-element-thunder` / `vfx-core` 행1(원형 참격)을 `effect_color`로
물들여 재사용하면 됩니다. 5행으로 끊은 이유는 **설계가 "1회성 정적 강조"라고 못 박았기 때문**이고
(트윈 루프 금지), 8종 전부에 전용 시트를 주면 그 규칙과 무관하게 시트만 늘어납니다.

### 13-3. `vfx-telegraph-ring.png` (1024×384 · 셀 128×128 · 8열 × 3행)

**전부 흰색 계열로 구웠습니다** — 원소 구분은 스프라이트 교체가 아니라 `effect_color`
modulate로 한다는 W11 규약 그대로입니다. 원은 **정원**입니다(이 게임은 탑다운이고
`enemy._draw`의 오라도 전부 정원). 절차적으로 그렸으므로 난수가 없습니다.

| 행 | 이름 | 내용 | 쓰는 곳 |
|---:|---|---|---|
| 0 | `expand` | 반경 8→30, 두께 4→1, 알파 1.0→0.18 + 8방향 눈금 | **A의 발구름 확산 링**(Attack 애니 부재를 메우는 바로 그것) · 파동형 패턴 전반 |
| 1 | `charge` | 바깥 테두리 고정 + 안쪽이 8프레임에 걸쳐 차오름 | **telegraph 진행도**. A-2 빙주 낙하 예고 원 3개 · C-3 화염 강하 |
| 2 | `pool` | 반경 27, 가장자리를 결정론적 사인 2개로 흔든 장판 + 밝은 립 | **잔류 장판**. B-2 산성 분비(8초) · C-1 기름 도포 · C+ 흑염 회오리 |

행0의 8방향 눈금이 없으면 정원의 크기 변화가 안 읽혀 확산 속도가 보이지 않습니다.

---

## 14. 스테이지 오버레이 · v3 랜드마크

| 파일 | 크기 | 배율 | 내용 · 사용 |
|---|---|---:|---|
| `overlay-fog.png` | 320×180 | ×1 | `FX/Environment/Fog.png` 원본 그대로. **픽셀 구름이라 nearest로 그릴 것.** 화면 전체를 덮는 **정적 쿼드**(흐르게 하지 않는다 — 트윈 루프 금지). 타일러블 아님. 알파는 `tuning.STAGE_FOG_ALPHA` |
| `overlay-vignette.png` | 256×144 | ×1 | 절차적 방사 감쇠(중심 투명 → 모서리 α0.86 검정). `tuning.STAGE_VIGNETTE`가 true인 5스테이지에만. ⚠️ **이 한 장만 `TEXTURE_FILTER_LINEAR`로 그릴 것** — 부드러운 전면 감쇠라 nearest로 늘리면 동심원 계단이 보인다. 픽셀아트 실루엣이 없는 순수 감쇠판이라 스타일을 해치지 않는다(Kenney 글로우와 같은 논리) |
| `landmark-boss-gate.png` | 192×128 | ×2 | `TilesetHouse`(128,0,64,48) 아치를 HSV(−18, 0.34, 0.40)로 흑화 + `TilesetTowers`(288,32) 붉은 뿔탑 ×2. **성(밝은 아치+석탑) → 보스문(검은 아치+붉은 뿔탑) → 마왕성(이끼 낀 검은 성채+붉은 뿔탑)**으로 같은 부품이 3단계로 험악해진다. 성(256×176)보다 작게 구워 "성이 아니라 문"으로 읽힌다 |
| `landmark-camp.png` | 192×128 | ×2 | `tileset_camp`(112,0,48,48) 천막 + (192,48,32,32) 돌 화덕 + (0,112,32,16) 통나무 울타리. 설계 §3.6 "성이랑 똑같아"는 **내부 서비스** 이야기다 — 필드 랜드마크는 성과 달라야 나침반에서 구분된다 |

랜드마크는 **밑변 기준**으로 놓습니다(`world_grid._draw_landmark`) — v2 규약 그대로입니다.

**범위 메모**: 이 랜드마크 2종은 설계 부록 B의 V3 항목에는 없지만 §2.3(스테이지마다 성·캠프·보스문 3종)과
§3.5(아레나 입구 문 스프라이트)가 요구하는 것이고, **`art/v2/`는 V3의 소유**라 V5가 직접 만들 수 없습니다.
V5가 막히지 않도록 여기서 함께 구웠습니다.

---

## 15. v3 산출 목록 (20장 · 총 532 KB)

| 파일 | 크기(px) | 용량 |
|---|---|---:|
| `terrain-atlas-verdant.png` | 160×128 | 2,230 B |
| `terrain-atlas-waste.png` | 160×128 | 2,232 B |
| `terrain-atlas-abyss.png` | 160×128 | 2,290 B |
| `boss-frost-cyclops.png` | 600×600 | 10,200 B |
| `boss-plague-slime.png` | 1612×624 | 17,539 B |
| `boss-black-slime.png` | 1612×624 | 16,940 B |
| `boss-crimson-tengu.png` | 2460×1640 | 74,346 B |
| `boss-black-tengu.png` | 2460×1640 | 73,009 B |
| `vfx-element-ice.png` | 800×80 | 2,075 B |
| `vfx-element-poison.png` | 640×80 | 1,733 B |
| `vfx-element-flame.png` | 400×80 | 2,335 B |
| `vfx-element-oil.png` | 880×80 | 3,346 B |
| `vfx-element-thunder.png` | 400×80 | 1,160 B |
| `vfx-status-pips.png` | 80×32 | 607 B |
| `vfx-synergy.png` | 768×480 | 78,603 B |
| `vfx-telegraph-ring.png` | 1024×384 | 12,598 B |
| `overlay-fog.png` | 320×180 | 1,976 B |
| `overlay-vignette.png` | 256×144 | 6,328 B |
| `landmark-boss-gate.png` | 192×128 | 2,126 B |
| `landmark-camp.png` | 192×128 | 2,093 B |

**PNG 총합 33 → 53장.** 설계 부록 B의 예상치는 "약 44장"(지형 3 + 보스 4 + 원소 VFX 4)이었고,
초과분 9장은 전부 설계 본문이 요구하지만 부록 B의 산출 목록에 안 잡힌 것들입니다 —
C+ 전용 시트 1(§3.1) · `Thunder` 5프레임 시트 1(부록 B ④를 `vfx-core` 덮어쓰기 대신 신규 파일로) ·
상태 핍 1(§4.8) · 시너지 1(§4.8) · 텔레그래프 1(§3.1·§3.3) · 오버레이 2(§7.3) · 랜드마크 2(§2.3·§3.5).

## 16. v3 크레딧 delta

v2와 같은 두 팩만 씁니다. 새로 끌어 쓴 원본 경로:

- `Actor/Boss/DemonCyclop2` `GiantSlime` `GiantSlime2` `TenguRed` — Ninja Adventure · CC0
- `FX/Elemental/{Ice,Plant,Flam,Water,Thunder}` `FX/Environment/Fog.png` — Ninja Adventure · CC0
- `Backgrounds/Tilesets/tileset_camp.png` · `TilesetWater.png`의 모래·자주 팔레트 블록 — Ninja Adventure · CC0
- `light_01` `light_02` `light_03` `smoke_04` `star_08` — Kenney Particle Pack · CC0

---
---

# Part III — UI 재스킨 킷 (`build_assets_ui.gd` · 10장)

스타일 규격의 단일 진실 원천은 **`docs/ui-style-v3.md`** 입니다. 이 절은 "무엇이
구워졌고 어디서 왔는가"만 기록합니다. 톤 색표·9-slice 사용법·버튼 상태 규약·
모달 골격·트윈 규칙은 전부 그 문서에 있습니다.

헬퍼는 `scripts/ui/ui_kit.gd`(`class_name UIKit`)입니다. U1~U3는 아틀라스를 직접
자르지 말고 이 헬퍼를 부릅니다.

## 17. UI 킷 10장

### 17-1. 공통 규격 — v3에서 이어받은 것과 U0가 새로 정한 것

| 항목 | 값 | 근거 |
|---|---|---|
| 확대 | **nearest ×2** (스포트라이트 2장만 ×1) | 필드는 16px 원본을 ×2로 구워 32px 셀로 만든 뒤 **40px 타일에 그리므로** 실효 아트 픽셀이 2.5px(비정수 → 2px·3px 혼재)다. UI는 정수 배율을 지킬 수 있는 유일한 층이라 정확히 ×2(2.0px)로 잡았다. 1.25배 차이가 남지만, 2.5로 맞추면 UI 격자까지 울퉁불퉁해진다 — 뒤집으려면 지형을 32px 타일로 옮기는 게 먼저다 |
| 합성 순서 | 16px 원본 좌표계에서 그리고 **마지막에 한 번만** ×2 | v2·v3와 동일 |
| 9-slice 여백 | **패널 10 · 카드 16 · 스포트라이트 32** — 이 셋이 전부(리본 18 · 게이지 4는 헬퍼가 넣는다) | 역할·톤이 몇 개든 여백이 같아야 U1~U3가 시트마다 찾아보지 않는다. 그래서 그림을 여백에 맞춘 게 아니라 **여백을 먼저 정하고 그림을 짰다** |
| 색 출처 | NA `Palette.png`(10×9 · 52색) + `Ui/Theme/Theme Wood` | 필드와 같은 팔레트를 안 쓰면 톤이 미묘하게 어긋난다. 파생색(hover/pressed/disabled/well)은 전부 계산이라 색 결정 지점이 램프 7개뿐이다 |
| 필터 | `TEXTURE_FILTER_NEAREST` | 예외는 스포트라이트 마스크 2장(LINEAR) — `overlay-vignette.png`와 같은 논리 |
| 결정성 | 난수·시각 없음 | 연속 2회 실행에서 **10장 전부 SHA-256 동일** 확인(빌드 약 40ms) |

**베벨 생성기 하나가 패널·버튼·카드·리본·슬롯칸·게이지를 전부 그린다.**
사각형을 바깥에서 안으로 "고리"로 나누고 고리마다 색을 준다(`_bevel()`).
모서리는 45° 마이터로 상 > 하 > 좌 > 우 우선순위 — 위가 항상 이기므로 "빛은
위에서 온다"가 7개 톤 전부에서 흔들리지 않는다. 어느 역할이든 고리 5개까지만
써서 나머지 6×6이 균일한 중앙이 되게 짰고, 그래서 여백이 전부 5(원본)다.

### 17-2. NA UI 원본 실사 — 있던 것과 합성한 것

`Ui/` 아래 PNG 359장을 전수 조사한 결과입니다.

| 필요한 것 | NA에 있었나 | 처리 |
|---|---|---|
| 9-slice 패널 | **있다** — `Ui/Theme/Theme Wood/nine_path_panel{,_2,_3,_disabled,_interior}.png` + `nine_path_bg{,_2}.png` + `inventory_cell.png` (전부 16×16) + `Ui/Theme/Wip/`에 대체 테마 12종 | **구조만 차용하고 픽셀은 새로 짰다.** 원본은 여백이 L6 T6 R5 B5로 비대칭이고, Wip 12종은 장식 무늬 때문에 균일한 중앙이 없어 9-slice가 뭉개진다. 원본 Wood의 색 6종(`ffad5d f06733 9b513c 46402e a3754e f38c4c`)은 `WOOD` 톤에 **그대로** 들어 있다 |
| 버튼 4상태 | **있다** — `button_{normal,hover,pressed,disabled}.png` (16×8) | 세로 8px라 여백 5를 못 만든다. 패널과 같은 16×16 생성기로 다시 구웠다. 원본은 pressed가 색만 어두워지는데, 이 킷은 **베벨을 함몰로 뒤집는다**(구조로 구분) |
| 탭·체크박스·라디오·슬라이더 | **있다** (`tab*` `checked` `radio_*` `*_slidder_grabber`) | 이번 킷에 **넣지 않았다.** 이 게임의 화면에 탭·체크박스·라디오가 없다. 필요해지면 원본을 그대로 ×2해서 쓸 것 |
| 카드 프레임 | **없다** | 합성. 패널 생성기를 24×24·여백 8로 돌리고 좌상단 8×8 모서리 블록에 5×5 문양을 찍었다(9-slice 모서리는 안 늘어나므로 크기와 무관하게 모양이 같다) |
| 헤더 리본 | 부분적 — `Ui/Dialog/ChoiceBox.png`(64×20)가 가장 근접 | 합성. ChoiceBox는 여백이 4라 얇고 끝 장식이 없다. 24×20 생성기 + V홈 컷으로 새로 만들었다 |
| 키캡 | **있다** — `Ui/Input/Keyboard/` 45종 + `Ui/Input/Mouse/` 7종 (그중 26종 채택) | **원본 그대로 ×2.** 완성된 픽셀아트라 손댈 이유가 없다. 셀 72×40 안에 중앙 정렬만 했다 |
| 화살표·포인터 | 부분적 — `Ui/Theme/Theme Wood/arrow_{left,right}.png`(16×16) · `Ui/Arrow.png`(13×13) | 원본 3장 + **회전**으로 8방향을 만들고, 바늘·캐럿·불릿·닫기·«»·⋯·그립 8종은 합성 |
| 글리프 | 절반 — `Items/`에 보석·모래시계·두루마리·책·가방, `Ui/Receptacle/IconHeart.png` | 그 6종은 원본 중앙 배치. 체크·X·＋·－·별·마름모·경고·정보 + **동전·열쇠** 10종은 합성. 동전·열쇠는 원본(`GoldCoin` 7×7 · `GoldKey` 12×8)이 32px 셀 안에서 다른 글리프(26~30px)와 무게가 안 맞아 같은 14px 규격으로 새로 그렸다 |
| 게이지 | **있다** — `Ui/Receptacle/`에 구형 7 × 진행 7색, 사각형 5종, `LifeBarMini`(18×4) | 원본은 전부 **고정 크기 스프라이트**라 임의 폭 게이지에 못 쓴다. 8×8·여백 2 9-slice로 새로 만들었다. 채움은 순백이라 `modulate`로 의미색을 준다 |
| 스포트라이트 소프트 마스크 | **없다**(NA는 픽셀아트 팩이라 그라데이션이 없다) | 절차적 생성. `overlay-vignette.png`와 같은 제곱 램프 |
| 스킬 아이콘 | 있지만 **안 쓴다** | §7 1행의 판단이 이번에도 유효하다 — NA `Ui/Skill Icon/` 32종에 딜싸이클 핵심 개념(회귀·도약·재실행·과열·빚)에 대응하는 그림이 하나도 없다. `skill_icon.gd`는 그대로 둔다 |
| 한글 폰트 | **없다** — `Ui/Font/`는 라틴 전용 | 폰트는 기존 것을 유지. 이 킷은 프레임과 색만 바꾼다 |

### 17-3. 시트별 규격

| 파일 | 크기 | 셀 | 격자 | 9-slice 여백 | 내용 · 원본 |
|---|---|---|---|---|---|
| `ui-kit-panels.png` | 224×160 | 32×32 | 7열(톤) × 5행(역할) | 10 | 톤 `parchment gold wood verdant slate abyss ember` × 역할 `panel inset chip cell focus`. 합성 |
| `ui-kit-buttons.png` | 128×128 | 32×32 | 4열(변종) × 4행(상태) | 10 | 변종 `primary(wood) neutral(slate) danger(ember) quiet(gold)` × 상태 `normal hover pressed disabled`. 합성 |
| `ui-kit-cards.png` | 240×144 | 48×48 | 5열(종류) × 3행(상태) | 16 | `skill item rune trophy boss` × `normal selected disabled`. 좌상단 문양 + **기하 3종**(융기·흰 이중 링·함몰)으로 갈린다. 합성 |
| `ui-kit-ribbon.png` | 336×80 | 48×40 | 7열(톤) × 2행(모양) | L16 T18 R16 B18 | `plaque` / `notched`(V홈). **높이 40 고정**, 가로만 늘린다. 합성. 열 순서는 패널과 같은 `TONE_ORDER` — 어긋나면 int enum이라 조용히 다른 색이 나온다 |
| `ui-kit-keycaps.png` | 360×240 | 72×40 | 5열 × 6행 | — | 키보드 24 + 마우스 2 = 26종. `Ui/Input/Keyboard/*` `Ui/Input/Mouse/*` **원본 ×2** |
| `ui-kit-pointers.png` | 256×64 | 32×32 | 8열 × 2행 | — | 셰브론4 · 포인터4 = `Theme Wood/arrow_{left,right}` + `Ui/Arrow.png` 회전. 바늘·캐럿·불릿·닫기·«»·⋯·그립 8종 합성 |
| `ui-kit-glyphs.png` | 256×64 | 32×32 | 8열 × 2행 | — | 앞 10종 합성(전부 흰색 — 호출부가 `modulate`로 색을 준다) / 뒤 6종은 `Items/Resource/GemPurple` `Items/Object/{Hourglass,Book,Bag}` `Items/Scroll/Scroll` `Ui/Receptacle/IconHeart` 원본 중앙 배치 |
| `ui-kit-bars.png` | 64×16 | 16×16 | 4열 | 4 | `track_dark track_light fill fill_gloss`. 합성. **트랙 최소 16×16** — 그보다 짧으면 둥근 끝이 뭉개진다 |
| `ui-kit-spotlight-rect.png` | 96×96 | — | — | **32** | 사각 구멍 + 소프트 가장자리. ⚠️ **×1 · `TEXTURE_FILTER_LINEAR`** |
| `ui-kit-spotlight-oval.png` | 256×256 | — | — | — | 원형 구멍. ⚠️ **×1 · `TEXTURE_FILTER_LINEAR`** |

### 17-4. 톤 램프 7종 (색 결정 지점 전부)

슬롯 7개 = 베벨 고리 7개. `outline`은 전 톤 공통 `#141b1b`(NA 팔레트 (8,0)).

| 톤 | hi | mid | lo | edge | shade | fill |
|---|---|---|---|---|---|---|
| `parchment` | `ffe18d` | `eecf9b` | `c8966b` | `965340` | `d2b37d` | `fce2ca` |
| `gold` | `ffe18d` | `f1c471` | `d78b4a` | `965340` | `d2b37d` | `ffcb8d` |
| `wood` | `ffad5d` | `f06733` | `9b513c` | `46402e` | `a3754e` | `f38c4c` |
| `verdant` | `adbc3a` | `a8a129` | `56864c` | `345a52` | `56864c` | `74a334` |
| `slate` | `abc2bc` | `8d977f` | `5f7160` | `141b1b` | `2d697b` | `345a52` |
| `abyss` | `d3a2c0` | `a5608b` | `8f3e56` | `141b1b` | `543c52` | `3b3643` |
| `ember` | `ff9554` | `e46d3a` | `8f3e56` | `543c52` | `9c6546` | `d14b34` |

파생 5종은 계산입니다: `fill_hi = fill.lightened(0.14)` ·
`well = fill.lerp(edge, 0.42)` · `well2 = fill.lerp(edge, 0.68)` ·
hover = 전 슬롯 `lightened(0.16)`(`fill`만 0.26) · disabled = HSV(sat×0.20, val×0.74).

> `well`을 `darkened()`로 안 만든 이유: `darkened`는 검정으로 끌고 가서
> parchment의 크림빛이 갈색 진흙이 된다(실측). `edge` 쪽으로 lerp하면 3단 배경
> 계층 내내 톤의 색상 성격이 유지됩니다 — v3 §9의 "곱연산 대신 HSV"와 같은 성격의 문제.
>
> `ember`의 `fill`을 벽돌빛 `#d14b34`로 내린 이유: `wood`(`#f38c4c`)와 둘 다 주황
> 계열이라 명도만 다르면 스킬 카드와 보스 카드가 안 갈립니다(실측). 새 톤을 넣을 때
> 이미 있는 7색과 명도만 다른 색을 고르지 마세요.
>
> hover에서 `fill`만 0.26인 이유: `lightened`는 남은 거리의 비율이라 밝은 톤에서
> 거의 안 움직입니다. parchment fill은 채널당 4밖에 안 바뀌어 hover가 보이지
> 않았습니다(실측). 지금은 4변종 전부 채널당 14~46 움직입니다.

**잉크 극성은 (톤, 역할) 쌍이 정합니다.** 밝은 톤도 칩 층에서는 중간 갈색이 되어
어두운 잉크가 무너집니다(wood 칩 `#7d5837` 위 `#141b1b`는 2.76:1). `UIKit`의
`_INK_LIGHT_ON` 7×5 표가 **구운 픽셀에서 계산한** 극성이고, 톤 램프를 바꾸면
그 표도 다시 계산해야 합니다. 자세한 대비 실측치는 `docs/ui-style-v3.md` §3.

### 17-5. 스테이지 5단 톤과의 관계

**HUD 톤은 스테이지에 따라 바꾸지 않습니다.** 필드는 §10의 5단으로 어두워지지만
HUD가 같이 어두워지면 5스테이지에서 정보가 안 읽힙니다. `slate`(`#345a52` 바탕 +
`#f2eaf1` 글자 + 검은 외곽선)는 스테이지 1 낮(`#ffffff`)과 스테이지 5 밤
(`#2f2f52` + 안개 α0.24 + 비네트) 양쪽에서 대비를 유지하도록 고른 값입니다.
스테이지 색은 UI가 아니라 필드가 표현합니다.

`abyss` 톤만 §10의 abyss 바이옴(`#b3957f` 바탕 + 자주 물)과 같은 계열이라
마왕·잠식 같은 "심연 소속" 요소에 씁니다. 5스테이지에서 HUD 전체를 `abyss`로
갈면 UI가 배경에 잠깁니다.

### 17-6. 산출 목록 (10장 · 총 29 KB)

| 파일 | 크기(px) | 용량 |
|---|---|---|
| `ui-kit-panels.png` | 224×160 | 2,275 B |
| `ui-kit-buttons.png` | 128×128 | 2,001 B |
| `ui-kit-cards.png` | 240×144 | 2,705 B |
| `ui-kit-ribbon.png` | 336×80 | 2,078 B |
| `ui-kit-keycaps.png` | 360×240 | 3,015 B |
| `ui-kit-pointers.png` | 256×64 | 1,323 B |
| `ui-kit-glyphs.png` | 256×64 | 1,989 B |
| `ui-kit-bars.png` | 64×16 | 202 B |
| `ui-kit-spotlight-rect.png` | 96×96 | 1,511 B |
| `ui-kit-spotlight-oval.png` | 256×256 | 13,009 B |

**PNG 총합 53 → 63장.** v2 33장과 v3 20장은 U0 빌드 전후로 바이트가 바뀌지 않았습니다
(파일명이 전부 `ui-kit-` 접두사라 겹칠 수 없습니다).

## 18. U0 크레딧 delta

앞의 두 파트와 같은 팩만 씁니다(Kenney는 안 씁니다). 새로 끌어 쓴 원본 경로:

- `Palette.png` — Ninja Adventure · CC0 (톤 램프 7종의 색 출처)
- `Ui/Theme/Theme Wood/{nine_path_panel, nine_path_bg, nine_path_bg_2, inventory_cell, button_*, arrow_left, arrow_right}` — Ninja Adventure · CC0 (구조 참조 + `wood` 톤 색 6종)
- `Ui/Input/Keyboard/*` `Ui/Input/Mouse/{MouseButtonLeft,MouseButtonRight}` — Ninja Adventure · CC0 (키캡 26종 원본 그대로)
- `Ui/Arrow.png` — Ninja Adventure · CC0 (포인터 4방향)
- `Ui/Receptacle/IconHeart.png` · `Items/Resource/GemPurple` · `Items/Object/{Hourglass,Book,Bag}` · `Items/Scroll/Scroll` — Ninja Adventure · CC0 (글리프 6종)

---

# Part IV — 피드백 라운드 산출물 (`build_assets_y.gd` · YA · 15장)

```bash
godot --headless --path godot-game --script res://art/v2/build_assets_y.gd
godot --headless --path godot-game --editor --quit
```

빌더는 이제 **네 개**입니다. YA도 앞선 셋과 파일명이 하나도 겹치지 않습니다.
다만 **YA만 예외가 하나 있습니다** — 스킬 아이콘 아틀라스는 `art/v2/` 말고
`art/generated/ui/skill-atlas-minimal-v2-runtime.png`에도 **같은 그림을 한 번 더**
씁니다(§19-2). 이 예외의 이유와 되돌리는 법은 그 절에 적어 두었습니다.

## 19. YA 산출물

### 19-1. 마왕 초상 2종 — `portrait-demon-lord-{96,48}.png`

사용자 피드백 ①("필드 토스트·밀정 화면이 아직 구버전 마왕을 쓴다"). 구버전은
에셋이 아니라 `scripts/pixel_portrait.gd`의 **벡터 드로잉**입니다 —
`draw_rect` 몇 개로 만든 검은 사각형 + 돌뿔 + 붉은 눈.

| 파일 | 크기 | 원본 | 액자 |
|---|---|---|---|
| `portrait-demon-lord-96.png` | 96×96 | `Actor/Boss/GiantRedSamurai/Faceset.png` 38×38 | 48px 원본 · 잉크 1 + 베벨 2 + 심연 바탕 |
| `portrait-demon-lord-48.png` | 48×48 | 같은 보스 `Idle.png` 프레임 0의 머리 `Rect2i(38, 6, 20, 20)` | 24px 원본 · 잉크 1 + 베벨 1 |

**둘의 원본이 다른 것은 의도입니다.** Faceset은 38×38이라 24px 액자에 안 들어가고,
픽셀아트는 줄이면 깨집니다. 그래서 작은 쪽은 **애초에 16px 밀도로 그려진 필드
스프라이트의 머리**를 잘라 씁니다 — 작게 읽히도록 그려진 그림이라 48px에서도
"금색 초승달 투구 + 붉은 얼굴 + 흰 송곳니"가 그대로 남습니다.
둘 다 ×2라 **화면상 픽셀 한 칸의 크기는 완전히 같습니다.**

액자 색은 U0 톤 램프의 `abyss`(§17-4)를 그대로 씁니다.

### 19-2. 스킬 아이콘 28종 — `ui-skill-icons.png` (448×256 · 7열×4행 · 셀 64)

사용자 피드백 ②("스킬 이미지가 너무 어려워, 알아보기 쉽게"). 구 아틀라스
(`art/generated/ui/skill-atlas-minimal-v2-runtime.png`, v1 AI 생성)는 초승달·검·
소용돌이가 뒤섞인 추상화라 22px HUD 칸에서 서로 구분되지 않았습니다.

교체본의 설계는 **정보를 세 축으로 쪼갠 것**이 전부입니다.

| 축 | 표현 | 근거 |
|---|---|---|
| **원소 7계** | 판 **색** (`game.gd`의 `ELEMENT_COLOR` 그대로) | 색은 크기를 안 탄다. 22px로 줄어도 남는 유일한 정보 |
| **형태 5종** | 판 **실루엣** (아래 표) | 색약 대비. 색과 다른 축이라 둘이 서로를 보강한다 |
| **동작** | 판 위 20×20 **글리프** (잉크 + 크림 하이라이트) | 카드마다 다른 유일한 축 |

형태 → 실루엣:

| 형태 | 판 모양 | 읽히는 뜻 |
|---|---|---|
| 참격 `slash` | 우상·좌하 모서리를 크게 베어 낸 사각 | 칼자국 |
| 관통 `pierce` | 오른쪽이 뾰족한 화살촉 | 앞으로 꿰뚫는다 |
| 파동 `wave` | 원 | 사방으로 퍼진다 |
| 설치 `trap` | 모서리를 조금 깎은 팔각(네모에 가깝다) | 바닥에 놓는다 |
| 수호 `guard` | 위는 각지고 아래로 좁아지는 방패 | 막는다 |

#### 이 시트가 반드시 지켜야 하는 계약 2개

`skill_icon.gd`가 아틀라스를 **그대로 그리지 않습니다.** 셀마다
`_build_trimmed()`로 배경을 flood fill 해서 지우고, 남은 내용의 **경계상자**를
`_draw_contained()`로 칸에 맞춰 늘립니다. 따라서:

1. **28칸의 경계상자가 전부 26×26이어야 한다.** 안 그러면 아이콘마다 화면
   크기가 달라집니다. 원·팔각·방패·화살촉이 전부 26×26을 꽉 채우도록
   `_plate_mask()`가 사방 끝 픽셀을 강제로 남깁니다.
2. **판 바깥 사방 3px(구운 뒤 6px)은 완전 투명이어야 한다.**
   `_build_trimmed()`는 셀 바깥 4px 링(`TILE_RING`)에 등장한 색만 "타일 색"으로
   보고 지웁니다. 여백이 6px면 그 링에 투명만 있으므로 판 색이 타일 색으로
   오인돼 파먹히는 일이 원천적으로 없습니다.

#### ⚠️ 기존 런타임 경로에 덮어씁니다

`skill_icon.gd`는 `res://art/generated/ui/skill-atlas-minimal-v2-runtime.png`를
`preload` 합니다. 이번 임무 조건이 **게임 .gd 로직 무수정**이라, 빌더가 같은 그림을
그 경로에도 한 번 더 씁니다(규격·셀 순서가 완전히 동일해서 코드 변경이 필요 없습니다).

- 원본은 `tmp/ya-backup/skill-atlas-minimal-v2-runtime.orig.png`에 떠 뒀습니다
  (res:// 바깥이라 Godot가 임포트하지 않습니다).
- 되돌리려면 그 파일을 도로 복사하고 `--editor --quit`을 한 번 돌리면 됩니다.
- 드롭인을 그만두려면 `build_assets_y.gd`의 `_build_skill_atlas()` 마지막 줄
  (`_save(sheet, LEGACY_SKILL_ATLAS, SCALE, true)`)만 지우고, 대신
  `skill_icon.gd`의 `GENERATED_SKILL_ATLAS` preload를 `res://art/v2/ui-skill-icons.png`로
  바꾸면 됩니다. **셀 순서(`GENERATED_SKILL_INDEX`)는 어느 쪽이든 그대로입니다.**

셀 순서는 `SKILL_ORDER` 배열이 들고 있고, `_verify_cards()`가 빌드 때마다
`DealCardLibrary.by_id()`로 28장의 원소·형태를 대조합니다(어긋나면 assert로 죽습니다).

### 19-3. 마왕 필드 시트 재슬라이스 — `boss-demon-king-v2.png` (1728×2880)

**§4의 규격 기술에 오류가 있습니다.** `Actor/Boss/GiantRedSamurai/Idle.png`(576×48)를
§4는 "48×48 프레임 12장"이라고 적고 있는데, 빈 열을 실측하면 내용 덩어리가
**6개**(0-12 / 83-108 / 179-204 / 275-300 / 371-396 / 467-492 가 비어 있음)이고
한 덩어리의 폭이 **70px**입니다. 쌍검을 벌린 사무라이는 48px에 안 들어갑니다.
**실제 규격은 96×48 6프레임**입니다. Walk도 6장, Hit는 96×48 4장,
AttackRight/Left는 96×96 4장입니다.

그 결과 현재 `boss-demon-king.png`는 사무라이 하나가 셀 두 칸에 걸쳐 구워져 있고
(행 0 내용 덩어리 = x 39-248 / 327-536 / … 폭 210 · 간격 288, 셀 경계 144의 배수와
어긋남), `enemy.gd`가 셀 하나를 그리면 **마왕의 절반만** 나옵니다.

`boss-demon-king-v2.png`는 **`enemy.gd`의 상수를 하나도 안 바꾸고** 이걸 고칩니다.

| 항목 | 기존 `boss-demon-king.png` | `boss-demon-king-v2.png` |
|---|---|---|
| 시트 | 1728×2880 | 1728×2880 (동일) |
| 셀 | 144×288 | 144×288 (동일) |
| `mask_y` / `foot` | 1440 / 0 | 1440 / 0 (동일) |
| 행별 프레임 | 12/12/8/8/8 | 12/12/8/8/8 (동일) |
| 배율 | ×3 | **×2** |
| 잘라 낸 창 | 48×48 (프레임을 반으로 자름) | **96px 프레임의 가운데 72px** — ×2 하면 144 = 셀 폭 정확히 |
| 프레임 채우기 | — | 실프레임 6/6/4/4/4장을 **한 장씩 두 번** 넣어 12/12/8/8/8 |

프레임을 두 번씩 넣으므로 애니메이션은 **절반 속도로 정상 재생**됩니다(그림이
반으로 잘리는 것보다 낫다는 판단). 쓰려면 `enemy.gd`의 `BOSS_SHEETS["demon_king"]["tex"]`
**한 줄만** 바꾸면 됩니다. 파일명이 다르므로 `build_assets.gd`의 산출물은 그대로입니다.

### 19-4. 장비 부위 4종 — `ui-slot-silhouettes.png` / `ui-slot-badges.png` (각 160×40)

사용자 피드백 ⑤. 셀 40×40(원본 20), 순서는 `item_library.gd`의 slot 키 순서
= `weapon / necklace / ring / bracelet`.

| 파일 | 색 | 쓰임 |
|---|---|---|
| `ui-slot-silhouettes.png` | 무채(GREY 램프) | **빈 슬롯** 자리표시. 채도가 0이라 "아직 없음"으로 읽힌다 |
| `ui-slot-badges.png` | 금판 + 잉크 픽토그램 + 크림 후광 1px | **장비 카드**의 부위 배지 |

넷 다 여기서 도형으로 그립니다(NA에 팔찌가 없고, 있는 것도 24×24 배경 사각에
갇혀 있어 굵기·시선 높이가 안 맞습니다). 두 번 갈아엎은 판단 2건을 남깁니다.

- **목걸이**: 처음엔 타원 고리 + 아래 보석으로 그렸더니 **전구·돋보기로 읽혔습니다.**
  사슬 두 가닥이 V자로 모이는 모양으로 바꿨습니다.
- **팔찌**: 매끈한 납작 타원으로 그렸더니 **반지와 실루엣이 겹쳤습니다.**
  구슬 8개를 타원으로 꿴 모양으로 바꿔 반지(원형 밴드 + 마름모 보석)와 갈랐습니다.

### 19-5. 재화 4종

사용자 피드백 ⑥. 픽셀아트는 줄이면 깨지므로 **크기별로 따로 굽습니다.**

| 파일 | 크기 | 쓰임 | 원본 |
|---|---|---|---|
| `ui-coin-small.png` | 16×16 | 가격 문자열 옆 인라인 | 손으로 찍은 8×8 비트맵 |
| `ui-coin-large.png` | 40×40 | 지불 버튼 · 상점 헤더 | `_coin(20)` (도형) |
| `ui-coin-spin.png` | 80×20 | 보상 팝업의 도는 금화 4프레임 | `Items/Treasure/Coin2.png` 원본 그대로 |
| `ui-coin-pile.png` | 48×32 | 총액 · 정산 요약 | `_coin(12)` 3장 겹침 |

NA `Items/Treasure/GoldCoin.png`(7×7)는 **납작한 사각형**이라 키우면 동전으로 안
보입니다(실측). 그래서 정지 금화 3종은 도형으로 그립니다.
8px에서는 원 판정이 사각형으로 뭉개져서 소형만 손으로 찍었습니다.

### 19-6. 상자 열기 6프레임 — `chest-open.png` (384×64 · 셀 64)

사용자 피드백 ④. 현재 `chest_open_effect.gd`는 `draw_rect` 세 개로 상자를 흉내
내고 뚜껑을 위로 밀어 올립니다. NA `Items/Treasure/LittleTreasureChest.png`(32×16)에
**닫힘·열림 두 프레임이 이미 있어서** 그 사이를 6프레임으로 채웠습니다.

| 프레임 | 내용 |
|---:|---|
| 0 | 닫힘 |
| 1 | 들썩(1px 위로) — 예비동작 |
| 2 | 열림 + 빛 트임 + 반짝이 4 |
| 3 | 빛기둥 최대 + 반짝이 6 |
| 4 | 빛 잦아듦 + 반짝이 퍼짐 |
| 5 | 열림 유지 + 반짝이 3 |

빛은 **위로 갈수록 넓어집니다.** 좁아지게 그렸더니 굴뚝 연기로 읽혔습니다(실측).
반짝이 배치는 난수가 아니라 index로 각도를 만들어 결정적입니다.

### 19-7. VFX 보강 3종

사용자 피드백 ③. 기존 NA + Kenney에 **없던 것 셋**만 만듭니다.

| 파일 | 크기 | 구성 | 색 |
|---|---|---|---|
| `vfx-stack-badge.png` | 160×32 | 셀 32 · 5칸 = 스택 1~5 | **중립(흰 점 + 어두운 판)** — `modulate`로 상태색을 입힌다 |
| `vfx-burst.png` | 384×64 | 셀 64 · 6프레임 | **중립(크림)** — 같은 이유 |
| `vfx-timeflow.png` | 192×96 | 셀 48 · 4프레임 × 2행 (행0 느려짐 / 행1 빨라짐) | 색을 갖는다 — 느림 청록(빙) / 빠름 노랑(뇌) |

- **스택 배지**: 기존 `vfx-status-pips.png`(§13-1)는 상태의 **종류**만 말하고
  **개수**를 말하지 못합니다. 1~5를 **주사위 눈 배치**로 찍어 세지 않고 모양으로
  읽게 했습니다.
- **버스트**: 불 폭발(`vfx-explosion.png`)과 구분되어야 하므로 불꽃이 아니라
  **고리 + 파편 8개**입니다. 타(打)가 쌓인 상태를 깨뜨리는 그림입니다.
- **시간 흐름**: 몸통은 NA `Items/Object/Hourglass.png` 그대로, 오른쪽 8px에
  화살표(느림 = 아래 1개 / 빠름 = 위 2개)를 붙이고 프레임마다 1px 흘립니다.
  이 둘만 색을 갖는 이유는 **색 자체가 정보**이기 때문입니다.

### 19-8. 산출 목록 (15장 · 총 75 KB)

| 파일 | 크기(px) | 용량 |
|---|---|---|
| `portrait-demon-lord-96.png` | 96×96 | 1,290 B |
| `portrait-demon-lord-48.png` | 48×48 | 662 B |
| `boss-demon-king-v2.png` | 1728×2880 | 54,669 B |
| `ui-skill-icons.png` | 448×256 | 12,612 B |
| `ui-slot-silhouettes.png` | 160×40 | 649 B |
| `ui-slot-badges.png` | 160×40 | 1,089 B |
| `ui-coin-small.png` | 16×16 | 178 B |
| `ui-coin-large.png` | 40×40 | 436 B |
| `ui-coin-spin.png` | 80×20 | 403 B |
| `ui-coin-pile.png` | 48×32 | 396 B |
| `chest-open.png` | 384×64 | 1,289 B |
| `vfx-stack-badge.png` | 160×32 | 319 B |
| `vfx-burst.png` | 384×64 | 1,207 B |
| `vfx-timeflow.png` | 192×96 | 1,431 B |

(+ 드롭인 사본 1장 = `art/generated/ui/skill-atlas-minimal-v2-runtime.png` 448×256)

**PNG 총합 63 → 77장.** v2 33장 · v3 20장 · U0 10장은 YA 빌드 전후로 바이트가
바뀌지 않습니다(§19-2의 드롭인 한 장만 예외이고, 그건 `art/generated/` 쪽입니다).

## 20. YA 크레딧 delta

새로 끌어 쓴 **원본 경로**(전부 Ninja Adventure · CC0):

- `Actor/Boss/GiantRedSamurai/{Faceset,Idle,Walk,Hit,AttackRight,AttackLeft}.png` — 초상 2종 + 재슬라이스 시트
- `Items/Treasure/{LittleTreasureChest,Coin2}.png` — 상자 6프레임 · 회전 금화
- `Items/Object/Hourglass.png` — 시간 흐름 2행

**새로 스테이징했지만 이번 라운드에 굽지는 않은 팩 3개**가 있습니다
(`art/external/LICENSES.md` 3~5절). 판단 근거는 §21에 적었습니다.

## 21. 웹 무료 팩을 왜 스테이징만 하고 안 썼나

`game-icons.net`(CC BY 3.0 · 113개) · `kenney-board-game-icons`(CC0 · 255개) ·
`owlishmedia-rpg-icons`(CC0 · 108개)를 받아 두었습니다. 스킬 아이콘 28종에
쓸지 실제로 래스터화해서 비교했고, **안 쓰기로 했습니다.**

- game-icons.net SVG를 20px로 래스터화하면 **안티에일리어싱이 회색 번짐으로 남습니다.**
  NA의 하드에지 16px 픽셀아트와 같은 화면에 놓으면 두 가지 그림 매체가 섞여 보입니다.
- 알파를 45%에서 이진화하면 번짐은 사라지지만, 획이 굵은 것
  (`broadsword` `burst-blob` `gem-necklace` `ring`)만 살아남고
  `bracer` `stack` 같은 세밀한 것은 1px 노이즈로 부서집니다.
- 무엇보다 **획 굵기를 통제할 수 없습니다.** 22px HUD 칸에서 읽히려면 모든 획이
  2px 이상이어야 하는데, 원본 SVG는 그 제약을 모르고 그려졌습니다.

그래서 28종은 20×20 격자에 직접 찍었습니다. 세 팩은 **라이선스 정리와 검증된
래스터화 명령까지 끝내서** 남겨 둡니다 — 32px 이상에서 쓰는 메뉴 아이콘이나
비픽셀 UI가 필요해지면 그대로 꺼내 쓸 수 있습니다(`LICENSES.md` §8).

> ⚠️ `game-icons/`는 **유일한 CC BY 팩**입니다. 저장소에 파일이 들어 있는 것만으로도
> 재배포에 해당하므로 `LICENSES.md` §6의 크레딧 블록을 게임 안에 넣어야 합니다.
> 그 의무를 지고 싶지 않다면 **`art/external/game-icons/` 디렉터리를 지우면 됩니다** —
> 이번 라운드 산출물 중 그 팩에 의존하는 것은 하나도 없습니다.
