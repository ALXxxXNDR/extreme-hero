# 외부 아트 에셋 인벤토리 · 활용안

확정 테마: **"Ninja Adventure" 16×16 탑다운 픽셀아트 (CC0, 단일 작가)**
보조: **Kenney Particle Pack (CC0, 스타일 중립 가산 파티클)**

- 총 용량 **11 MB / 1,453 파일** (오디오·GIF 프리뷰 제외)
- 라이선스·출처는 [`LICENSES.md`](./LICENSES.md) 참조. **전부 CC0, 크레딧 의무 없음.**
- 이 문서는 "제안"입니다. 게임 코드는 건드리지 않았습니다.

## 테마를 이걸로 정한 이유

| 기준 | 판단 |
|---|---|
| **일관성** | 몹·플레이어·지형·VFX·UI·아이콘이 전부 **한 작가(Pixel-boy & AAA)의 단일 팔레트**에서 나옴. 팩을 섞을 필요가 없어 "한 게임처럼 보인다"가 자동으로 성립. |
| **커버리지** | 게임이 필요로 하는 6개 축(지형/플레이어/몹/보스/VFX/UI)을 **한 팩이 전부** 채움. 다른 무료 팩 중 이걸 해내는 건 없음. |
| **라이선스** | CC0. 크레딧·share-alike·재배포 제한 전부 없음 → 배포·수정·저장소 커밋 모두 무위험. |
| **퀄리티** | 개별 스프라이트 해상도(16px)는 Tiny Swords(64px)보다 낮음. 하지만 Tiny Swords는 적 3종뿐이라 몹 10종+마왕을 못 채우고, 섞으면 스타일이 깨짐. **일관성 > 개별 퀄리티** 원칙에 따라 이쪽. |

---

## 1. 디렉터리 구조

```
godot-game/art/external/
├── LICENSES.md
├── INVENTORY.md                       (이 문서)
├── ninja-adventure/
│   ├── LICENSE.txt  README.md  Palette.png
│   ├── Actor/
│   │   ├── Monster/          66종  (4방향 × 4프레임, 64×64 시트)
│   │   ├── Boss/             20종  (개별 Idle/Walk/Hit 시트)
│   │   ├── Character/        38종  (판타지 관련만 선별)
│   │   ├── Animal/           19종  (측면뷰 2프레임)
│   │   └── CharacterAnimated/ 풀 액션 세트 1종 + 장착 무기 5종
│   ├── Backgrounds/
│   │   ├── Tilesets/         19장  (Field/Water/Nature/Floor/Relief/VillageAbandoned/Towers/camp/Dungeon/House/Desert 등)
│   │   ├── Animated/         물결·폭포·깃발·꽃·풍차 등
│   │   └── Vehicles/
│   ├── FX/                   Attack 8 · Slash 6 · Elemental 13 · Magic 10 · Projectile 17 · Particle 14 · Smoke 2 · Environment 2
│   ├── Items/                무기 23계열 · 물약 · 두루마리 · 보물 · 자원 · 음식 · 도구
│   └── Ui/                   Skill Icon 24×24 (Spell 32 + Item 12 + Job 12 + Meteo 4) · Theme 9-patch 12종 · Dialog · Receptacle(HP/MP) · Emote 30 · Font
└── kenney-particle-pack/
    └── PNG (Transparent)/    81장 (circle/dirt/fire/flame/flare/light/magic/muzzle/scorch/scratch/slash/smoke/spark/star/symbol/trace/twirl/window)
```

## 2. 스프라이트 규격 (중요)

| 자산군 | 시트 크기 | 레이아웃 |
|---|---|---|
| `Actor/Monster/*/…png` | **64×64** | **열 = 방향 4(정면/후면/좌/우), 행 = 프레임 4.** 셀 16×16 |
| `Actor/Character/*/SpriteSheet.png` | 64×112 | 열 = 방향 4, 행 = 프레임 7. 셀 16×16 |
| `Actor/Character/*/SeparateAnim/` | `Walk.png` 64×64 (4방향×4프레임), `Idle/Attack/Jump.png` 64×16 (4방향×1프레임), `Dead/Item/Special*.png` 16×16 | **통합 시트보다 이쪽이 슬라이싱하기 안전함** |
| `Actor/Boss/*` | 각기 다름 (예: `DemonCyclop/Idle.png` 250×50 = 50×50 5프레임, `GiantRedSamurai/Idle.png` 576×48 = 48×48 12프레임) | 파일별로 `높이 = 프레임 한 변` |
| `Actor/Animal/*` | 28×13 ~ 36×17 | **측면뷰 2프레임.** 4방향 아님 → 좌우 플립으로만 쓸 수 있음 |
| `Ui/Skill Icon/**` | 24×24 | 아이콘마다 `*Disabled.png` 흑백 버전 동봉 |
| `Ui/Theme/Theme Wood/*` | 8×8 ~ 26×14 | Godot `StyleBoxTexture` 9-patch용 |
| `Backgrounds/Tilesets/*` | 각기 다름 | 전부 **16px 그리드** |

---

## 3. 지형 40px 대응 — **가능. 코드 수정 없이 아틀라스 교체만으로 됨.**

### 기존 계약 (읽기만 함, 변경 없음)

`scripts/world_grid.gd` / `scripts/wfc_chunk_generator.gd`에서 확인한 사실:

- `TILE = 40`은 **화면상 크기**입니다. `_draw_tile()`은
  `draw_texture_rect_region(TERRAIN_ATLAS, Rect2(pos, Vector2(40,40)), source_rect, tint)`을 호출하므로
  **원본 셀 픽셀 크기는 자유**입니다. 무엇을 넣든 40px로 스케일됩니다.
- `ATLAS_COLUMNS = 5`, `ATLAS_ROWS = 4` → 아틀라스는 **5열 × 4행 격자**여야 하고, 셀 번호 = `행*5 + 열`.
- `ATLAS_CELL_INSET = 2` → 셀마다 사방 2 소스픽셀을 잘라냅니다(셀 한 변의 25%로 클램프).
- 현재 아틀라스 `art/generated/world/terrain-atlas-wfc-v2-runtime.png` = **160×128 → 셀 32×32**.

> **권장: 교체본도 160×128(5×4 of 32×32)로 만들 것.**
> Ninja Adventure 타일은 16×16이므로 nearest로 ×2 업스케일해서 32×32 셀에 넣으면,
> `ATLAS_CELL_INSET=2`가 현재와 똑같은 비율(6.25%)만 깎아냅니다.
> 16px 셀 그대로 쓰면 2px가 12.5%를 먹어 타일 가장자리가 잘립니다.

### 필요한 셀 12개 → 소스 대응표

`TILE_RULES`가 실제로 참조하는 `atlas` 번호는 **0,1,2,5,6,12,14,15,16,17,18,19** 뿐입니다(3,4,7~11,13은 미사용).
물가 8종은 셀 6(4방향 회전)과 셀 12(4방향 회전)를 돌려 씁니다.

| 셀 | 규칙 | 소스 파일 | 소스 좌표(px) | 검증 |
|---|---|---|---|---|
| 0 | `grass` | `Backgrounds/Tilesets/TilesetField.png` | (16, 64, 16, 16) — 연녹색 평면 채움 | ✅ 눈으로 확인 |
| 1 | `grass_tuft` | 셀 0 + `TilesetNature.png` 잔디 뭉치 데코 합성 | 잔디 뭉치 열 다수 존재 | ✅ |
| 2 | `grass_flower` | 셀 0 + `TilesetNature.png` 꽃(해바라기/데이지/붉은꽃) 합성 | ✅ |
| 5 | `water` | `TilesetWater.png` | (16, 128, 16, 16) — 트인 물 | ✅ |
| 6 | `shore_north` | `TilesetWater.png` | (16, 112, 16, 16) — 위쪽이 땅인 물가. turn 1/2/3으로 E/S/W 생성 | ✅ |
| 12 | `shore_south_east` | `TilesetWater.png` | (32, 144, 16, 16) — 오른쪽+아래가 땅인 모서리. turn 1/2/3으로 나머지 3모서리 | ✅ |
| 14 | `bridge` | `TilesetWater.png` 나무 데크 블록 | 대략 (0,192)~(176,272) 영역의 가로 판자 런 | ✅ |
| 15 | `forest` | `TilesetNature.png` 나무 군집(2×2/3×3 여러 종) | ✅ |
| 16 | `rocks` | `TilesetNature.png` 바위 군집(갈색/회색 2계열) | ✅ |
| 17 | `ruins` | `TilesetVillageAbandoned.png` 이끼 낀 무너진 석벽·폐가 | ✅ |
| 18 | `courtyard` | `TilesetFloor.png` 석재 바닥 | ✅ |
| 19 | `camp` | `tileset_camp.png` 천막·모닥불·나무궤짝 | ✅ |

`TilesetWater.png`(448×272 = 28×17 타일)의 **잔디↔물 팔레트 블록 구조** (직접 크롭해서 확인):

```
        col0        col1        col2
row7  좌상 모서리   위쪽 물가   우상 모서리
row8  왼쪽 물가    ■트인 물■   오른쪽 물가
row9  좌하 모서리   아래 물가   우하 모서리        ← 셀12 = (col2,row9)
row10 가로 물줄기 좌/중/우 캡
row12~16  나무 데크(다리)
```
즉 WFC가 요구하는 **물 9종(물 1 + 변 4 + 모서리 4)이 전부 존재**합니다.
같은 레이아웃이 사막(주황)·설원(흰)·용암/보라 팔레트로도 있어 나중에 바이옴 확장이 가능합니다.

### 랜드마크 (성/마왕성/유적)
`world_grid.gd`의 성은 현재 `draw_rect` 절차적 그리기입니다. 스프라이트로 갈 때 후보:

| 대상 | 후보 |
|---|---|
| 시작 성 | `TilesetTowers.png` 회색/베이지 석탑 + `TilesetHouse.png` |
| 마왕성 | `TilesetTowers.png` **적/흑 변종** + `TilesetDungeon.png` |
| 유적 | `TilesetVillageAbandoned.png` (통짜로 최적) |
| 시련 캠프 | `tileset_camp.png` (천막·모닥불·통나무·궤짝 세트) |
| 상자 | `Items/Treasure/` |

---

## 4. 몹 10종+ / 마왕 매핑안

`scripts/monster_library.gd`의 `MONSTERS` 14종 + 마왕에 대한 제안입니다.
**Primary는 전부 4방향×4프레임 64×64 시트**라서 애니메이션 규격이 통일됩니다.
Alt는 "생김새가 더 딱 맞지만 규격이 다른" 대안입니다.

| # | id / 이름 | visual | Primary (4방향 64×64) | Alt |
|---|---|---|---|---|
| 1 | `mossling` 이끼콩 | blob | `Actor/Monster/Larva` (이끼색 애벌레) | `Monster/Slime4`, `Monster/Mushroom` |
| 2 | `boar` 들멧돼지 | boar | `Actor/Monster/Bear` (적갈색 돌진형 짐승) | `Actor/Animal/WildBoar` — 생김새는 완벽하지만 **측면뷰 2프레임** |
| 3 | `imp` 뿔임프 | imp | `Actor/Monster/Beast` (붉은 뿔 악마) | `Actor/Character/DemonRed` |
| 4 | `wolf` 붉은 늑대 | wolf | `Actor/Animal/DogOrange` (적갈색 개과, **측면뷰 2프레임**) | 4방향이 필수면 `Monster/Racoon` 또는 `Monster/Beast2` |
| 5 | `cave_bat` 동굴 박쥐 | bat | `Actor/Monster/BlueBat` | `Monster/YellowsBat` |
| 6 | `skeleton` 떠도는 해골 | skeleton | `Actor/Character/Skeleton` (전신 해골, 걷기 有) | `Monster/Skull`(떠다니는 두개골 — "떠도는"에 더 부합), `Character/SkeletonDemon` |
| 7 | `royal_ooze` 왕관 점액 | ooze | `Actor/Monster/Slime2` (보석 박힌 녹색 점액) | `Monster/Slime4`, `Monster/Slime3` |
| 8 | `iron_beetle` 철갑 딱정벌레 | beetle | `Actor/Monster/Mollusc` (붉은 갑각) | `Monster/Mollusc2`(녹색), `Monster/SpiderRed` |
| 9 | `shade` 굶주린 그림자 | shade | `Actor/Monster/Spirit` (흰 유령) | `Monster/Spirit2`, `Character/Spirit` |
| 10 | `wisp` 푸른 위습 | wisp | `Actor/Monster/Flam2` (**푸른 불꽃 정령** — 이름까지 일치) | `Monster/LanternGreen`, `Monster/Eye` |
| 11 | `ogre` 황야 오우거 | ogre | `Actor/Monster/Cyclope2` (녹색 외눈 거구) | `Monster/Cyclope`(적색) |
| 12 | `cultist` 월식 주술사 | cultist | `Actor/Character/SorcererBlack` (후드 술사) | `Character/NinjaMageBlack`, `Character/Shaman` |
| 13 | `hellhound` 밤의 지옥견 | hellhound | `Actor/Animal/DogBlack` + 붉은 `modulate` (**측면뷰 2프레임**) | 4방향 필수면 `Monster/Beast2` |
| ★ | **마왕 (Demon King)** | boss | `Actor/Boss/GiantRedSamurai` — **48×48, Idle/Walk 12프레임, AttackLeft/Right 8프레임, Charge 6프레임, Hit.** 초승달 투구를 쓴 붉은 마검사. 검사 vs 마왕 구도에 최적 | `Boss/DemonCyclop`(50×50 붉은 외눈 악마, Idle 5 / Walk 6 / Hit 3), `Boss/DemonCyclop2`(녹색) |

**남는 보스 후보(중간보스·시련 캠프 정예용):** `DragonBlue/Green`(다관절), `GiantFlam`, `GiantSlime`, `GiantSpirit`, `TenguRed/Blue`, `SquidRed/Green`, `GiantRacoon(Gold)`, `GiantBlueSamurai`, `GiantBamboo`, `GiantFrog` — 총 20종.

### 플레이어 (검사 1종)
| 후보 | 경로 | 비고 |
|---|---|---|
| **1순위** | `Actor/Character/Knight/` | 회색 판금 기사. `SeparateAnim/`에 Idle·Walk·**Attack(검 휘두르기 4방향)**·Jump·Dead·Item·Special1/2 전부 분리 제공 |
| 2순위 | `Actor/Character/KnightGold/` | 금색 변종. 각성/승급 연출용으로 같이 쓰기 좋음 |
| 3순위 | `Actor/Character/Samurai`, `SamuraiBlue`, `SamuraiRed` | 카타나 검사 |
| 무기 교체 | `Items/Weapons/` 23계열 (Sword, Sword2, BigSword, Katana, Rapier, Lance, Club, Axe, Bow, MagicWand …) + `Actor/CharacterAnimated/Weapon/`(장착 애니메이션용 Katana/Axe/Hammer/Pickaxe/Net) |

### NPC (성 내부)
`Character/Princess`, `Noble`, `Master`, `OldMan`, `OldWoman`, `Villager1~3`, `Woman`, `Boy`, `Monk`, `Hunter`, `Sultan`, `Statue`, `GoldStatue`

---

## 5. VFX 커버리지 (스킬 이펙트)

게임의 스킬 종류(베기·투사체·장판·폭발·보호막)에 대한 대응입니다.

| 스킬 종류 | 에셋 | 규격 |
|---|---|---|
| **베기 (근접 아크)** | `FX/Attack/SlashCurved`, `SlashDoubleCurved`, `CircularSlash`, `Cut`, `CutX`, `Claw`, `ClawDouble` | 128×32 = **32×32 4프레임** |
| | `FX/Attack/CutDouble` | 160×32 = 32×32 5프레임 |
| | `FX/Slash/SpriteSheetSlash01~03`, `SpriteSheetArc`, `SpriteSheetCircular`, `SpriteSheetMulti` | 대형 참격. `Multi`만 270×30(30×30 9프레임), 나머지는 비정규 → 수동 슬라이싱 필요 |
| **투사체** | `FX/Projectile/Fireball`, `EnergyBall`, `SpriteSheetRock` | 64×16 = 16×16 4프레임 |
| | `FX/Projectile/BigEnergyBall` | 96×24 = 24×24 4프레임 |
| | `FX/Projectile/CanonBall` | 80×16 = 16×16 5프레임 |
| | `Arrow`(13×5), `Kunai`(14×5), `Shuriken`(32×16 2프레임), `IceSpike`, `PlantSpike`, `BigShuriken`, `BigKunai` | 단발/비정규 |
| | `FX/Projectile/Shuriken/SpriteSheet.png`(690×54), `Kunai/SpriteSheet.png`(650×59) | 발사→비행→명중 풀시퀀스 |
| **장판 / 마법진** | `FX/Magic/Circle/SpriteSheetOrange`, `SpriteSheetWhite` | 128×32 = 32×32 4프레임 |
| | `FX/Magic/Circle/SpriteSheetSpark`(6프레임), `SpriteSheetSpark2`(5프레임) | 32×32 |
| | `FX/Elemental/Plant`, `Ice`(320×32 10프레임), `Water`, `WaterPillar`, `RockSpike`(540×48) | 속성 장판 |
| **폭발** | `FX/Elemental/Explosion/SpriteSheet.png` | 360×40 = **40×40 9프레임** (40px 타일과 딱 맞음) |
| | `FX/Elemental/Flam`(200×30), `FX/Smoke/Smoke`(192×32 = 32×32 6프레임), `SmokeCircular` | 후속 연기 |
| **보호막** | `FX/Magic/Shield/SpriteSheetBlue`, `SpriteSheetYellow` | 144×26 (비정규, 6프레임 추정) |
| | `FX/Magic/Aura/SpriteSheet.png` | 125×24 지속 오라 |
| **버프 / 강화** | `FX/Magic/Boost`(424×35), `FX/Magic/Spirit`(160×32 5프레임, 3색), `FX/Magic/Spark`(270×35) | 딜싸이클 스택 연출에 적합 |
| **낙뢰 / 암석** | `FX/Elemental/Thunder`(160×28), `Rock`/`RockB`(420×30 = 30×30 14프레임) | |
| **피격/사망 파편** | `FX/Particle/Rock`, `RockGray`, `Wood`, `Vase`, `Grass`, `Leaf`, `Spark`, `Fire`(96×12 8프레임) | |
| **환경/분위기** | `FX/Environment/Fog.png`(320×180), `Raylight.png`(216×102), `FX/Particle/Rain`, `Snow`, `Clouds` | **밤 연출**에 바로 쓸 수 있음 |
| **가산 글로우 (보조 팩)** | `kenney-particle-pack/PNG (Transparent)/` 81장 — `light_0x`, `magic_0x`, `flare_0x`, `star_0x`, `spark_0x`, `muzzle_0x`, `scorch_0x`, `trace_0x`, `twirl_0x` 등 | 512px 소프트 알파. `BlendMode.ADD`로 픽셀 VFX 아래/위에 깔아 발광·잔광을 만드는 용도. **스타일이 없는 텍스처**라 16px 아트와 충돌하지 않음 |

**요약: 요구한 5종(베기/투사체/장판/폭발/보호막)이 전부 커버됨.** 특히 폭발이 40×40 프레임이라 40px 타일 그리드와 정확히 맞아떨어집니다.

---

## 6. UI 커버리지

| 요소 | 에셋 |
|---|---|
| 스킬 아이콘 | `Ui/Skill Icon/Spell/` **32종** (Fireball, Explosion, RockSpike, Heal, Counter, Cut, Camouflage, Necromancy, Alchemy, AttackUpgrade, DefenseUpgrade, LuckUpgrade, MagicWeapon, Vision, Mist, Death, Downgrade, Permutation, WaterCanon, Book×8, Orb×5 …) — 각 24×24 + Disabled 흑백판 |
| 아이템/장비 아이콘 | `Ui/Skill Icon/Items & Weapon/` 12종 (Armor, Helmet, Boot, Ring, Amulet, Guard, Scroll, Money, Arrow, Kunai, Shuriken, Hook) |
| 행동 아이콘 | `Ui/Skill Icon/Job & Action/` 12종 (Punch, Interact, Potion, Repair, Mine, Harvest, Talk, Sing …) |
| 날씨/시간 | `Ui/Skill Icon/Meteo/` 4종 (Sun, Moon, Rain, Snow) — **낮/밤 주기 표시**에 바로 사용 |
| 패널 / 프레임 | `Ui/Theme/Theme Wood/` 9-patch 완전 세트 (nine_path_panel ×5, bg ×2, focus, inventory_cell, button 6상태, checkbox/radio, slider, tab 5상태, arrow) + `Ui/Theme/Wip/`에 **대체 테마 12종**(Metal×3, Wood×4, Bamboo, Dark, Red, Map, Bubble, Bocal)의 nine_path_panel |
| 다이얼로그 | `Ui/Dialog/` DialogBox(300×58), DialogBoxFaceset, ChoiceBox, FacesetBox, Yes/No 버튼 |
| HP / MP 게이지 | `Ui/Receptacle/` — 구형 게이지(배경 7종 × 진행 7색, 32×32), 사각 게이지(가방/대나무/병/두루마리/나무 배경 + 진행바), Heart ×3, LifeBarMini(18×4, **몹 머리 위 체력바**용) |
| 초상화 | 모든 `Actor/**/Faceset.png` 38×38 (몹·보스·캐릭터 전원 보유) — 스킬 선택/도감 UI에 사용 가능 |
| 이모트 | `Ui/Emote/emote1~30.png` |
| 폰트 | `Ui/Font/NormalFont.ttf`, `font8x8.png`, `font24x30.png` — **라틴 전용, 한글 없음.** 한글 UI는 기존 폰트 유지 필요 |
| 입력 아이콘 | `Ui/Input/` 키보드·게임패드 |

---

## 7. 통합 시 주의점

1. **한글 폰트 없음.** `Ui/Font/`는 라틴 전용입니다. 한국어 텍스트는 기존 폰트를 계속 써야 합니다.
2. **`Actor/Animal/*`은 4방향이 아님.** 측면뷰 2프레임이라 상하 이동 시 어색합니다. 4방향이 필요하면 `Actor/Monster/*`(전부 64×64 4방향)에서 고르세요.
3. **16px → 40px는 2.5배 비정수 스케일**입니다. 현재 프로젝트도 32px 아틀라스를 40px로 그리고 있으므로 동작은 동일하지만, `TEXTURE_FILTER_NEAREST`에서 픽셀 크기가 불균일해집니다. 지형 아틀라스는 위 3절대로 **×2 업스케일 후 32px 셀**로 만들면 현재와 같은 품질이 나옵니다. 캐릭터/몹은 ×2(32px) 또는 ×3(48px) 배치를 권장합니다.
4. **비정규 시트가 꽤 있습니다.** 표에 "비정규"로 표시한 것들은 `높이 = 프레임 한 변`이 성립하지 않으므로 `AtlasTexture`로 수동 슬라이싱하거나 Aseprite로 재정렬해야 합니다.
5. **`art/generated/`는 손대지 않았습니다.** 폐기 여부는 별도 판단.
6. Godot 에디터를 열면 1,400여 개 PNG가 일괄 임포트됩니다(최초 1회 수십 초). 쓰지 않을 그룹은 `.gdignore`로 배제하거나 디렉터리를 지우면 됩니다.

---

## 8. 2026-08-09 추가 팩 3개 (YA 라운드)

라이선스·재수급 절차의 정본은 [`LICENSES.md`](./LICENSES.md) 3~5절입니다.
**⚠️ 이제 이 디렉터리가 전부 CC0는 아닙니다** — `game-icons/`만 CC BY 3.0이고
크레딧 표기가 의무입니다.

| 팩 | 경로 | 라이선스 | 내용 | 용량 |
|---|---|---|---|---:|
| game-icons.net | `game-icons/<작가>/<아이콘>.svg` | **CC BY 3.0** | 단색 SVG 113개 (원소·시간·재화·장비·상태) | 476 KB |
| Kenney Board Game Icons | `kenney-board-game-icons/` | CC0 1.0 | 64px PNG 255 + SVG 255 (스택·타이머·버스트) | 2.1 MB |
| OwlishMedia RPG UI Icons | `owlishmedia-rpg-icons/icons/` | CC0 1.0 | 16px 컬러 픽셀 22개 + 32px 흰 실루엣 86개 (버프/디버프) | 436 KB |

### 스타일 정합 — 셋을 섞으면 안 되는 이유

| 팩 | 매체 | NA(16px 하드에지 컬러)와 |
|---|---|---|
| game-icons.net | 벡터 실루엣 | 32px 미만으로 래스터화하면 회색 번짐이 남아 **안 섞인다** |
| Kenney Board Game | 벡터 실루엣 | 같음 |
| OwlishMedia 16px | **컬러 픽셀아트** | 밀도가 같아 **섞인다**. 상태 배지에 바로 쓸 수 있다 |
| OwlishMedia 32px | 흰 실루엣 | 픽셀이지만 무채라 인게임보다 메뉴 쪽 |

### YA 라운드에서의 판정

세 팩 모두 **스테이징만 하고 굽지는 않았습니다.** 스킬 아이콘 28종에 쓸 수
있는지 실제로 래스터화해 비교한 결과와 근거는 `art/v2/ASSET_MAP.md` §21에 있습니다.
요약: 22px HUD 칸에서 읽히려면 모든 획이 2px 이상이어야 하는데 벡터 원본은
그 제약을 모르고 그려졌고, 이진화로 번짐을 지우면 가는 획이 부서집니다.

바로 꺼내 쓸 수 있는 후보(다음 웨이브용):

- `owlishmedia-rpg-icons/icons/{poison_,smoulder,frozen,slow,swift,strengthen,weaken,shield_,regen,special}.png`
  — 16px 컬러. StatusEngine 5상태(독·연·한·유·전) + 버프/디버프 배지에 밀도가 맞습니다.
- `kenney-board-game-icons/` — 64px PNG가 이미 있어 SVG를 안 건드려도 됩니다(≥32px UI용).
- `game-icons/` — 메뉴·도감처럼 **64px 이상**에서만. 쓰면 CC BY 크레딧 의무가 발생합니다.
