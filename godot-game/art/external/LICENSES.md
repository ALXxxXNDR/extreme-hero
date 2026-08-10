# 외부 아트 에셋 라이선스

이 디렉터리(`godot-game/art/external/`)에 스테이징된 모든 에셋의 출처·라이선스 기록입니다.
`art/generated/`(AI 생성 기존 에셋)는 이 문서의 대상이 아닙니다.

> ⚠️ **2026-08-09 갱신 — 이 요약은 바뀌었습니다.**
> 이전 판에는 "전부 CC0, 크레딧 의무 없음"이라고 적혀 있었으나,
> **game-icons.net 아이콘(3절)이 추가되면서 더 이상 사실이 아닙니다.**

**요약: 5개 팩 중 4개는 CC0 1.0 Universal(퍼블릭 도메인)이고,
`game-icons/` 1개만 CC BY 3.0 이라 크레딧 표기가 "의무"입니다.**

| 팩 | 라이선스 | 크레딧 의무 |
|---|---|---|
| `ninja-adventure/` | CC0 1.0 | ❌ 없음 |
| `kenney-particle-pack/` | CC0 1.0 | ❌ 없음 |
| `kenney-board-game-icons/` | CC0 1.0 | ❌ 없음 |
| `owlishmedia-rpg-icons/` | CC0 1.0 | ❌ 없음 |
| **`game-icons/`** | **CC BY 3.0** | ✅ **있음 — 아래 6절의 크레딧 블록을 반드시 게임 안에 표시** |

CC BY 3.0은 **상업 이용·수정·재배포를 모두 허용**하지만 **저작자 표시가 조건**입니다.
share-alike(동일조건변경허락)는 없으므로 수정본에 라이선스가 전염되지는 않습니다.
game-icons.net 동봉 `license.txt`의 요구 문구는 다음과 같습니다.

> "Please, include a mention **"Icons made by {author}"** in your derivative work."

즉 팩 이름이 아니라 **아이콘별 작가 이름**을 적어야 합니다. 실제로 우리가 남긴
113개 아이콘의 작가는 9명이며, 그대로 붙여 넣을 수 있는 블록을 **6절**에 만들어 두었습니다.

---

## 1. Ninja Adventure - Asset Pack  (주 팩)

| 항목 | 내용 |
|---|---|
| 경로 | `godot-game/art/external/ninja-adventure/` |
| 저작자 | **Pixel-boy** (https://pixel-boy.itch.io/) 와 **AAA** (https://www.instagram.com/challenger.aaa/) |
| 배포 페이지 | https://pixel-boy.itch.io/ninja-adventure-asset-pack |
| 원본 파일 | `Ninja Adventure - Asset Pack.zip` (89 MB, 2026-03-29 빌드) |
| 라이선스 | **CC0 1.0 Universal (Public Domain Dedication)** |
| 라이선스 전문 | 팩에 동봉된 `ninja-adventure/LICENSE.txt` (원문 전체) / https://creativecommons.org/publicdomain/zero/1.0/legalcode |
| 저작자 선언 원문 | `ninja-adventure/README.md` — "They are released under the Creative Commons Zero (CC0) license. You can use any and all of the assets found in this package in your own games, even commercial ones. Attribution is not required but appreciated." |
| 공식 GitHub 미러 | https://github.com/pixel-boy/NinjaAdventure (Godot 데모 프로젝트. 전체 에셋 아님) |

### 의무 사항
없음. CC0이므로 크레딧·고지·share-alike 모두 **불필요**합니다.

### 선택 사항 (저작자가 "있으면 좋겠다"고 요청한 링크)
크레딧을 넣는다면 아래 문구를 권장합니다.

```
Art: "Ninja Adventure Asset Pack" by Pixel-boy & AAA (CC0)
https://pixel-boy.itch.io/ninja-adventure-asset-pack
```

### 스테이징 시 제외한 것
- `Audio/` (96 MB, 음악 37곡 + SFX 100여 개) — 이번 임무는 아트 수급이라 제외. 필요하면 같은 CC0 조건으로 재수급 가능.
- `*.gif` 프리뷰 128개, 루트 `Example *.gif` — 문서용 애니메이션 프리뷰라 런타임 불필요.
- `Actor/Character` 100여 종 중 판타지 무관한 것(로봇·에스키모·원숭이복서·계란 등)과 `Actor/Animal` 일부 — 파일 수 절감.

---

## 2. Kenney Particle Pack  (보조 팩)

| 항목 | 내용 |
|---|---|
| 경로 | `godot-game/art/external/kenney-particle-pack/` |
| 저작자 | **Kenney** (https://kenney.nl) |
| 배포 페이지 | https://kenney.nl/assets/particle-pack |
| 직링크 | https://kenney.nl/media/pages/assets/particle-pack/f8fe0f8cb8-1677578741/kenney_particle-pack.zip |
| 라이선스 | **CC0 1.0 Universal** |
| 라이선스 전문 | 팩에 동봉된 `kenney-particle-pack/License.txt` / https://creativecommons.org/publicdomain/zero/1.0/ |

### 의무 사항
없음. 선택 크레딧 문구:

```
Particles: "Particle Pack" by Kenney (CC0) — https://kenney.nl
```

### 스테이징 시 제외한 것
- `PNG (Black background)/`, `Spritesheet/`, `Unity samples/` — 투명 배경 PNG 80종만 있으면 충분.

---

## 3. game-icons.net  (아이콘 팩 — **유일한 CC BY 팩**)

| 항목 | 내용 |
|---|---|
| 경로 | `godot-game/art/external/game-icons/<작가>/<아이콘>.svg` |
| 저작자 | **9명** (아래 6절 크레딧 블록 참조). 디렉터리 이름이 곧 작가 이름입니다. |
| 배포 페이지 | https://game-icons.net/ |
| 소스 저장소 | https://github.com/game-icons/icons |
| 직링크 | https://github.com/game-icons/icons/archive/refs/heads/master.tar.gz (3.0 MB, 전체 4,239 SVG) |
| 라이선스 | **CC BY 3.0** (일부 작가만 CC0 — 아래 주의 참조) |
| 라이선스 전문 | 팩에 동봉된 `game-icons/license.txt` (원문 전체) / https://creativecommons.org/licenses/by/3.0/ |
| 원본 파일 | `master.tar.gz`, 2026-04-24 커밋 스냅샷. 압축 해제 시 17 MB / 4,239 SVG |
| 스테이징 크기 | **113 SVG / 172 KB** (전체의 2.7%만 남김) |

### 라이선스 원문 (동봉 `license.txt` 첫 줄과 마지막 요구사항)

> "Icons provided under the Creative Commons 3.0 BY **or CC0 if mentioned below**."
> …
> "Please, include a mention **"Icons made by {author}"** in your derivative work."

### ⚠️ 작가별 라이선스 차이 — 확인 결과

`license.txt`의 작가 목록에서 **CC0로 명시된 작가는 `Viscious Speed`와 `Zeromancer` 2명뿐**입니다.
**우리가 남긴 113개 아이콘 중 이 두 작가의 것은 0개**이므로,
**남긴 아이콘은 전부 CC BY 3.0**이고 크레딧 의무가 붙습니다. (6절 블록을 쓰면 됩니다.)

### 의무 사항
**있음.** 게임의 크레딧 화면·README·배포 페이지 중 최소 한 곳에 6절 블록을 표시해야 합니다.
share-alike는 없으므로 아이콘을 색칠·변형·합성해도 우리 코드/아트에 라이선스가 전염되지 않습니다.

### 파일 포맷 주의 (다음 단계 래스터화에서 중요)

- 모든 SVG는 `512×512` viewBox에 **`<path>` 정확히 2개**뿐입니다.
  `<g>`·`transform`·그라디언트·`<text>`·`clip-path`·`stroke`가 **하나도 없습니다** (4,180개 전수 검사 완료).
- **1번째 path `<path d="M0 0h512v512H0z"/>` 는 검은 배경 사각형**입니다.
  그냥 래스터화하면 **검은 정사각형**이 나옵니다 (`opaque=True` 확인함).
  투명 배경으로 뽑으려면 이 path를 먼저 제거해야 합니다. 명령은 **8-1절** 참조.
- 2번째 path가 `fill="#fff"` 흰색 전경입니다. Godot에서 `modulate`로 원소별 색을 입히면 됩니다.

### 스테이징 시 제외한 것
- 전체 4,239개 중 **4,126개 삭제.** 저장소를 가볍게 유지하려고 필요한 113개만 남겼습니다.
  전체 재수급 방법은 7절에 그대로 적어 두었습니다.
- `badges/` 59개 — 256×256 원형 배지 파생본. 작가 디렉터리가 아니라 스타일 변형이라 제외.
- `.git/`, `.gitignore`, `CONTRIBUTING.md`, `colorize-svgs.sh`, `rasterize-svgs.sh` — 저장소에 `.git`을 남기지 않기 위해 tarball로 받았고, 스크립트는 전체 세트 전제라 제외.

---

## 4. Kenney Board Game Icons  (스택 카운터 · 타이머 · 버스트)

| 항목 | 내용 |
|---|---|
| 경로 | `godot-game/art/external/kenney-board-game-icons/` |
| 저작자 | **Kenney** (https://kenney.nl) |
| 배포 페이지 | https://kenney.nl/assets/board-game-icons |
| 직링크 | https://kenney.nl/media/pages/assets/board-game-icons/19cae04050-1721645690/kenney_board-game-icons.zip |
| 라이선스 | **CC0 1.0 Universal** |
| 라이선스 전문 | 팩에 동봉된 `kenney-board-game-icons/License.txt` / http://creativecommons.org/publicdomain/zero/1.0/ |
| 원본 파일 | `kenney_board-game-icons.zip` (1.0 MB, v1.1 / 2024-07-22) |
| 스테이징 크기 | **512 파일 / 480 KB** (64px PNG 255 + SVG 255 + `License.txt` + `Preview.png`) |

### 왜 이걸 골랐나 — 우리가 없던 것을 정확히 메움

| 부족했던 것 | 이 팩의 대응 파일 |
|---|---|
| **독/저주 스택 카운터 배지** | `tag_1`~`tag_10`, `tag_empty`, `tag_infinite`, `tag_shield_1`~`tag_shield_10`, `tag_shield_infinite`, `tag_d6_*` — **숫자가 박힌 배지 그 자체** |
| **버스트/터짐(스택 폭발)** | `exploding`, `exploding_6` |
| **시간 감속 / 가속 표시** | `timer_CW_25/50/75`, `timer_CCW_25/50/75` (**시계방향=가속, 반시계=감속**으로 바로 대응), `timer_0`, `timer_100`, `hourglass`, `hourglass_top`, `hourglass_bottom`, `arrow_clockwise`, `arrow_counterclockwise` |
| **더미/스택 표현** | `tokens_stack`, `tokens`, `cards_stack`, `cards_stack_high`, `token_add`, `token_remove`, `token_subtract` |
| 카드 게임 UI (스킬 28장 구조) | `card_*`, `cards_*` 40여 종 (draw/discard/shuffle/tap/flip/fan) |

**스타일 적합성:** 투명 배경 위 **흰색 실루엣**이라 game-icons.net을 흰색·투명으로 뽑은 것과
시각 언어가 정확히 같습니다. 두 팩을 한 UI에 섞어도 이질감이 없습니다.

### 의무 사항
없음. 선택 크레딧 문구:

```
Icons: "Board Game Icons" by Kenney (CC0) — https://kenney.nl
```

### 스테이징 시 제외한 것
- `PNG/Double (128px)` — 64px PNG와 SVG가 있으면 중복.
- `Tilesheet/` — 개별 파일로 쓰므로 불필요.
- `Vector/overview.svg`, `Vector/overview.swf` — 카탈로그 프리뷰 / Flash.
- `Visit Kenney.url`, `Visit Patreon.url`, `Thumbs.db`.

### 파일 포맷 주의 — **이 팩 SVG에는 `viewBox`가 없습니다**

`Vector/*.svg`의 루트 태그에 `width`/`height`/`viewBox`가 **전부 없어서**
ImageMagick이 `must specify image size` 오류로 **읽지 못합니다.**
게다가 좌표계가 **원점 중심(-32…+32)** 이라 `viewBox="0 0 64 64"`를 넣으면 잘립니다.
정답은 **`viewBox="-32 -32 64 64"`** 입니다 (동봉 64px PNG와 RMSE 0.0385로 일치 확인).
명령은 **8-2절** 참조. 128px 이하로 쓸 거면 **동봉된 64px PNG를 그냥 쓰는 편이 간단합니다.**

---

## 5. OwlishMedia — RPG UI Icons  (버프/디버프 상태 아이콘)

| 항목 | 내용 |
|---|---|
| 경로 | `godot-game/art/external/owlishmedia-rpg-icons/icons/` |
| 저작자 | **OwlishMedia** (https://opengameart.org/users/owlishmedia) |
| 배포 페이지 | https://opengameart.org/content/rpg-ui-icons |
| 직링크 | https://opengameart.org/sites/default/files/RPG_Icons_Pack_OwlishMedia.zip |
| 라이선스 | **CC0 1.0 Universal** |
| 라이선스 전문 | https://creativecommons.org/publicdomain/zero/1.0/ — **⚠️ 팩에 라이선스 파일이 없습니다(아래 참조)** |
| 원본 파일 | `RPG_Icons_Pack_OwlishMedia.zip` (46,334 바이트, 2018년 업로드) |
| 스테이징 크기 | **108 PNG / 32 KB** (전량 유지) |

### ⚠️ 라이선스 파일을 우리가 만들어 넣었습니다

원본 zip 안에는 **PNG 108개뿐, 라이선스 파일이 없습니다.**
CC0 부여는 OpenGameArt 제출 페이지의 `License(s): CC0` 필드에만 기록돼 있고
`http://creativecommons.org/publicdomain/zero/1.0/`로 링크됩니다 (2026-08-09 페이지 직접 확인).
근거가 파일과 함께 남도록 `owlishmedia-rpg-icons/LICENSE.txt`를 **우리가 작성**했으며,
그 파일 안에 "저자 배포물이 아님"을 명시해 두었습니다.

### 왜 이걸 골랐나 — 유일하게 남아 있던 "버프/디버프 상태 아이콘 세트" 공백을 메움

상태 이상 25종이 이름 그대로 들어 있습니다:
`berserk` `blind` `brave` `buff` `charm` `confuse` `cure` `debuff` `eagle_eye` `frozen`
`nausea` `poison_` `regen` `shield_` `shy` `silence` `sleep` `slow` `smoulder` `special`
`stone` `strengthen` `stunned` `swift` `weaken`

속성 10종(`fire` `ice` `water` `wind` `earth` `light` `darkness` `lightning` `cosmos` `non-elemental`)과
시간 표시(`hourglass` `clock` `slow`)도 포함됩니다.

**스타일 적합성:** 16×16(22개) / 32×32(86개) **컬러 픽셀아트**라
주 팩 Ninja Adventure의 16px 컬러 픽셀아트와 같은 계열입니다.
단, 3·4절의 **단색 벡터 아이콘과는 시각 언어가 다릅니다.**
→ 권장 분리: **컬러 픽셀 = 인게임 상태 배지**, **단색 벡터 = 스킬 카드·메뉴 UI**.

### 의무 사항
없음. 선택 크레딧 문구:

```
Status icons: "RPG UI Icons" by OwlishMedia (CC0)
https://opengameart.org/content/rpg-ui-icons
```

---

## 6. 크레딧 블록 (game-icons.net — **의무. 그대로 복사해서 쓰세요**)

게임 크레딧 화면 / README / 배포 페이지 중 **최소 한 곳**에 아래를 넣어야 합니다.
아래 9명은 `art/external/game-icons/` 에 **실제로 남아 있는 113개 아이콘의 작가 전원**입니다.
(아이콘을 추가·삭제하면 이 목록도 갱신해야 합니다. 검증 명령은 **8-4절**에 있습니다.)

```
Icons made by Lorc, Delapouite, Sbed, Skoll, Willdabeast, Felbrigg,
DarkZaitzev, Cathelineau and Carl Olsen — available at https://game-icons.net
Licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/)
```

더 격식 있는(작가별 링크 포함) 버전이 필요하면 아래를 쓰세요.

```
Icons from game-icons.net, licensed CC BY 3.0:
  Icons made by Lorc          — https://lorcblog.blogspot.com
  Icons made by Delapouite    — https://delapouite.com
  Icons made by Sbed          — https://opengameart.org/content/95-game-icons
  Icons made by Skoll         — https://game-icons.net
  Icons made by Willdabeast   — https://wjbstories.blogspot.com
  Icons made by Felbrigg      — https://blackdogofdoom.blogspot.co.uk
  Icons made by DarkZaitzev   — https://darkzaitzev.deviantart.com
  Icons made by Cathelineau   — https://game-icons.net
  Icons made by Carl Olsen    — https://twitter.com/unstoppableCarl
```

### 작가별 보유 아이콘 (감사·갱신용)

| 작가 | 개수 | 아이콘 |
|---|---:|---|
| **Lorc** | 68 | barbed-spear, bleeding-eye, bloody-sword, brain-freeze, bright-explosion, broadsword, burning-dot, burst-blob, cog, corner-explosion, cracked-ball-dunk, cross-mark, cursed-star, cycle, dripping-goo, empty-hourglass, energy-arrow, engagement-ring, explosion-rays, fire-bomb, frozen-orb, gem-necklace, ghost-ally, goo-explosion, gooey-molecule, guillotine, heavy-lightning, heavy-timer, hourglass, ice-spear, icicles-aura, lightning-arc, lion, locked-chest, magic-swirl, magnifying-glass, meditation, meteor-impact, mine-explosion, poison-bottle, poison-gas, psychic-waves, raining, ringed-planet, saber-slash, sands-of-time, shield-reflect, skull-crack, skull-crossed-bones, skull-shield, snowflake-2, spiky-explosion, spill, splash, sprint, star-swirl, stopwatch, striking-splinter, strong, sword-slice, targeting, tension-snowflake, thunder-struck, time-bomb, time-trap, tornado, trident, triple-scratches |
| **Delapouite** | 31 | alarm-clock, anticlockwise-rotation, armor-upgrade, backward-time, boomerang, boomerang-cross, bracer, chest, cleaver, clockwise-rotation, coins, coins-pile, crosshair, extra-time, fog, gold-stack, health-potion, player-time, ring, shield-bash, split-arrows, stack, stars-stack, stockpiles, temporary-shield, time-synchronization, two-coins, up-card, upgrade, viking-shield, war-axe |
| **Sbed** | 5 | cancel, fire, lava, poison-cloud, shield |
| **Skoll** | 3 | oil-drum, open-chest, sound-waves |
| **Willdabeast** | 2 | chain-lightning, gold-bar |
| **Felbrigg** | 1 | dodge |
| **DarkZaitzev** | 1 | death-juice |
| **Cathelineau** | 1 | holy-oak |
| **Carl Olsen** | 1 | flame |
| | **113** | |

---

## 검토했으나 **제외**한 후보와 사유

| 팩 | 라이선스 | 제외 사유 |
|---|---|---|
| **Tiny Swords** (Pixel Frog, https://pixelfrog-assets.itch.io/tiny-swords) | 현행판: 상업 사용·수정 허용, **재배포/재판매/재패키징 금지**. 별도로 `TS_old version_CC0 Licensed` 구버전(Update 010)은 CC0. | ① 64px 유화풍 ↔ 주 팩 16px 플랫 = 스타일 충돌이 치명적. ② 적 유닛이 고블린 3종(Torch/TNT/Barrel)뿐이라 몹 10종+마왕을 못 채움. ③ 지형이 절벽 고저차(elevation) 기반 오토타일이라 이 게임의 평면 LAND/WATER 9종 WFC 구조와 맞지 않음. ④ 현행판의 재배포 금지 조항은 스프라이트 원본을 저장소에 그대로 커밋하는 방식과 충돌. → **스테이징하지 않음.** |
| **LPC (Liberated Pixel Cup)** / OpenGameArt | CC-BY-SA 3.0 + GPL 3.0 (share-alike) | 커버리지는 넓지만 다수 작가 기여라 팩 내부 스타일 편차가 있고, share-alike가 수정 아트에 전염됨. CC0 단일 작가 팩이 있으므로 굳이 감수할 이유 없음. |
| **Kenney Roguelike/RPG pack**, Roguelike Characters, Fantasy Town Kit | CC0 | 애니메이션 프레임이 없는 정적 스프라이트이고 VFX가 전무. 결국 다른 팩과 섞어야 해서 일관성 원칙에 반함. |
| **CraftPix 무료 섹션** | 자체 라이선스. 재배포 금지 + 조건부 크레딧 | 조건이 팩·항목마다 달라 라이선스 명확성이 떨어짐. CC0 대안이 있으므로 배제. |
| **pixel-boy RpgMix / IconMix** (주 팩과 **같은 작가**, 스타일 완벽 일치) | **유료.** "Resell, redistribute, or share the assets on their own" 금지 + NFT/AI 학습 금지 | 무료가 아니므로 이번 임무 범위 밖. 예산이 생기면 스타일 일관성을 유지한 채 확장할 수 있는 1순위 후보. |
| **pixel-boy FreeMix** (같은 작가, 무료) | 무료지만 CC0 아님(재배포 금지 계열) | 주 팩이 이미 같은 작가의 CC0 슈퍼셋이라 추가 이득이 거의 없음. 라이선스 단순화를 위해 배제. |

### 2026-08-09 추가 조사분 (VFX 공백 메우기용으로 검토)

| 팩 | 라이선스 | 제외 사유 |
|---|---|---|
| **Kenney Generic Items** (https://kenney.nl/assets/generic-items) | CC0 (문제 없음) | ① **장르 불일치가 결정적.** 163개가 노트북·스마트폰·드라이버·주방기구 등 **현대 사물**이라 판타지 RPG에 쓸 게 사실상 없음. ② 파일명이 `genericItem_color_001`…`_163` 으로 **의미 없는 일련번호**라 검색·매핑 비용이 큼. ③ 우리가 찾던 버프/디버프·스택·시간 표현이 **하나도 없음**. → 라이선스는 깨끗하지만 **쓸모가 없어서** 제외. |
| **Kenney Game Icons** (https://kenney.nl/assets/game-icons) | CC0 (문제 없음) | 내용이 **시스템 UI 아이콘**(게임패드 버튼, 재생/일시정지, 음량, 메뉴, 트로피, 화살표)임. 스킬·상태이상·VFX와 무관. 게임패드 입력 UI가 필요해지면 그때 재검토 가치 있음. |
| **Kenney UI Pack / Cursor Pack** | CC0 | 9-patch 패널·버튼·커서 중심인데 **주 팩 Ninja Adventure의 `Ui/Theme/` 가 이미 9-patch 전 세트를 제공**함. 스타일이 섞이면 오히려 손해라 제외. |
| **LPC / OpenGameArt "700+ RPG icons" (Lorc)** | CC-BY 3.0 | **game-icons.net과 같은 작가(Lorc)의 같은 아이콘 세트**임. 3절에서 이미 상위 세트를 받았으므로 **완전 중복**. |
| **CraftPix 무료 RPG 아이콘** | 자체 라이선스, 재배포 금지 | 원본 파일을 저장소에 커밋하는 방식과 충돌. 기존 판단과 동일하게 배제. |
| **itch.io "700+ RPG icons" 류 유사 팩 다수** | 팩마다 상이·불명확 | 다수가 **로그인/이메일 입력 후 다운로드**를 요구하거나 라이선스 문구가 페이지에 없음. "모호하면 제외" 원칙에 따라 손대지 않음. |

---

## 조달 방법 메모 (재현용)

itch.io 무료/PWYP 에셋은 로그인 없이 아래 순서로 받을 수 있습니다.

1. `GET https://<user>.itch.io/<game>` → HTML에서 `name="csrf_token"` 추출
2. `POST https://<user>.itch.io/<game>/download_url` (body: `csrf_token=...`) → 다운로드 페이지 URL(JSON)
3. 다운로드 페이지 `GET` → `data-upload_id="..."` 와 새 `csrf_token` 추출
4. `POST https://<user>.itch.io/<game>/file/<upload_id>` (body: `csrf_token=...`) → 서명된 CDN URL (유효기간 60초)
5. 즉시 `GET`

Kenney는 에셋 페이지 HTML 안의 `https://kenney.nl/media/pages/assets/<slug>/<hash>/kenney_<slug>.zip` 직링크를 그대로 `curl` 하면 됩니다.
해시가 바뀌므로 하드코딩하지 말고 매번 아래처럼 뽑아 쓰세요.

```sh
curl -sSL "https://kenney.nl/assets/board-game-icons" \
  | grep -oE 'https://kenney\.nl/media/pages/assets/[^"]*\.zip' | sort -u
```

### 7. 2026-08-09 추가분 — 실제로 실행한 명령 그대로

#### 7-1. game-icons.net 전체 세트 재수급

**저장소에는 113개만 있습니다.** 전체 4,239개가 필요하면 아래를 그대로 실행하세요.
`.git`을 남기지 않으려고 `git clone`이 아니라 **tarball**을 씁니다.

```sh
mkdir -p /tmp/gi && cd /tmp/gi
curl -sSL -o icons-master.tar.gz \
  https://github.com/game-icons/icons/archive/refs/heads/master.tar.gz
tar xzf icons-master.tar.gz          # -> icons-master/ (17 MB, 4,239 SVG)
```

레이아웃은 **`<작가>/<아이콘>.svg`** 로 평평합니다.
(game-icons.net 웹 zip의 `icons/<작가>/originals/svg/` 구조가 **아님**에 주의.)
**디렉터리 이름이 곧 작가 이름**이므로 크레딧은 경로에서 바로 뽑을 수 있습니다.
SVG 내부에는 `<title>`·메타데이터가 없습니다.

우리가 남긴 113개를 다시 고르는 방법 (6절 표의 이름을 `keep.txt`에 한 줄씩 `작가/이름` 형식으로):

```sh
DST=godot-game/art/external/game-icons
mkdir -p "$DST" && cp /tmp/gi/icons-master/license.txt /tmp/gi/icons-master/README.md "$DST"/
while read -r p; do mkdir -p "$DST/$(dirname "$p")"; cp "/tmp/gi/icons-master/$p" "$DST/$p"; done < keep.txt
```

#### 7-2. Kenney Board Game Icons

```sh
curl -sSL -o /tmp/bgi.zip \
  "https://kenney.nl/media/pages/assets/board-game-icons/19cae04050-1721645690/kenney_board-game-icons.zip"
unzip -q /tmp/bgi.zip -d /tmp/bgi
DST=godot-game/art/external/kenney-board-game-icons
mkdir -p "$DST/PNG"
cp "/tmp/bgi/License.txt" "/tmp/bgi/Preview.png" "$DST"/
cp -R "/tmp/bgi/PNG/Default (64px)" "$DST/PNG/Default (64px)"
cp -R "/tmp/bgi/Vector/Icons"       "$DST/Vector"
find "$DST" -name 'Thumbs.db' -delete
```

#### 7-3. OpenGameArt — OwlishMedia RPG UI Icons

OpenGameArt 첨부 파일은 **로그인 없이 직접 `curl`** 됩니다.

```sh
DST=godot-game/art/external/owlishmedia-rpg-icons
mkdir -p "$DST/icons"
curl -sSL -o /tmp/owl.zip \
  "https://opengameart.org/sites/default/files/RPG_Icons_Pack_OwlishMedia.zip"
unzip -q /tmp/owl.zip -d "$DST/icons"
```

`LICENSE.txt`는 원본 zip에 없으므로 우리가 작성한 것을 유지하세요(5절 참조).
라이선스 필드는 아래로 재확인할 수 있습니다.

```sh
curl -sSL https://opengameart.org/content/rpg-ui-icons \
  | sed 's/<[^>]*>/ /g' | grep -o 'License(s):.\{0,60\}'
# -> License(s):&nbsp;   CC0   Collections:&nbsp; ...
```

---

## 8. SVG → PNG 래스터화 (다음 단계용 · **검증 완료된 명령**)

로컬 ImageMagick 7.1.2 에는 **librsvg 델리게이트가 없습니다**
(`magick -version`의 Delegates 목록에 `rsvg` 없음). 그래도 **내장 MSVG 렌더러로 충분합니다** —
game-icons SVG가 `<path>` 2개짜리 단순 도형뿐이기 때문입니다.

**검증 방법:** 113개 전부를 ImageMagick과 resvg(= game-icons 공식 스크립트가 쓰는 렌더러)로
각각 64px 렌더링해 RMSE 비교 → **최대 0.057, 대부분 0.03~0.04**. 안티에일리어싱 차이일 뿐
형태 차이는 없음(육안 대조도 동일). **따라서 별도 툴 설치 불필요.**

### 8-1. game-icons.net (`art/external/game-icons/**.svg`)

**검은 배경 path를 먼저 지워야 합니다.** 지우지 않으면 결과가 검은 정사각형입니다.

```sh
# 아이콘 1개 -> 투명 배경 흰색 64px PNG
sed 's|<path d="M0 0h512v512H0z"/>||' in.svg > /tmp/t.svg
magick -background none -density 400 /tmp/t.svg -resize 64x64 out.png
```

전체 일괄 변환:

```sh
SRC=godot-game/art/external/game-icons
OUT=/tmp/icons-png; mkdir -p "$OUT"
find "$SRC" -name '*.svg' | while read -r f; do
  a=$(basename "$(dirname "$f")"); n=$(basename "$f" .svg)
  sed 's|<path d="M0 0h512v512H0z"/>||' "$f" > /tmp/t.svg
  magick -background none -density 400 /tmp/t.svg -resize 128x128 "$OUT/${a}__${n}.png"
done
```

- `-density 400` = 512pt viewBox를 약 2,844px로 그린 뒤 축소 → 다운샘플링 품질 확보용.
  더 큰 출력이 필요하면 density를 같이 올리세요(예: 256px 출력 → `-density 800`).
- 색을 입히려면 `-fill '#ff6a3d' -colorize 100` 을 붙이거나, Godot에서 `modulate`로 처리.
- 113개 전량 변환에 **약 23초** 걸렸습니다(단일 스레드).

### 8-2. Kenney Board Game Icons (`Vector/*.svg`)

이쪽은 **`viewBox`가 없어서 위 명령이 그대로는 실패**합니다
(`magick: must specify image size ... ReadMVGImage`).
좌표계가 원점 중심이라 **`viewBox="-32 -32 64 64"`** 를 주입해야 합니다.

```sh
sed 's|<svg |<svg viewBox="-32 -32 64 64" |' in.svg > /tmp/t.svg
magick -background none -density 800 /tmp/t.svg -resize 128x128 out.png
```

(동봉된 `PNG/Default (64px)/*.png` 와 RMSE 0.0385로 일치 확인.
**128px 이하로만 쓸 거면 동봉 PNG를 그대로 쓰는 게 제일 간단합니다.**)

### 8-3. 대안 렌더러 (필요해지면)

ImageMagick으로 안 되는 SVG를 만나면 resvg를 쓰세요. 설치 불필요:

```sh
npx --yes @resvg/resvg-js-cli --fit-width 128 in.svg out.png
```

단, resvg도 **`viewBox` 없는 SVG는 잘못 프레이밍**하므로 8-2의 주입이 똑같이 필요합니다.
(`svgexport`/`sharp-cli`는 시도하지 않았습니다 — ImageMagick으로 충분해서 불필요.)

### 8-4. 크레딧 블록 검증 (아이콘을 추가·삭제한 뒤 반드시)

6절 작가 목록이 실제 파일과 어긋나지 않았는지 확인:

```sh
find godot-game/art/external/game-icons -name '*.svg' \
  | sed 's|.*/game-icons/||; s|/.*||' | sort | uniq -c | sort -rn
```

출력된 작가가 6절 크레딧 블록의 9명과 일치해야 합니다.
`viscious-speed` 또는 `zeromancer` 가 새로 등장하면 그 둘은 **CC0**이므로
크레딧 의무 대상이 아닙니다(그래도 표기해서 손해 볼 건 없습니다).
