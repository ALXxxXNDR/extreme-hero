# handoff-ya — 피드백 라운드 에셋 수급·제작

## 0. 한 문장

사용자 피드백 6건(마왕 초상 · 스킬 아이콘 28종 · VFX 보강 · 상자 열기 · 장비 부위 ·
재화)에 대응하는 **런타임 PNG 15장**을 새 빌더 `art/v2/build_assets_y.gd`로 굽고,
웹 무료 팩 3개를 라이선스까지 정리해 스테이징했습니다.
**게임 `.gd` 로직은 한 줄도 고치지 않았습니다.**

---

## 1. 사용자 요구 → 산출물 대조표

| # | 사용자 요구 | 산출물 | 코드 변경 필요? |
|---|---|---|---|
| ① | 마왕 PFP(토스트용 소형 · 모달용 대형) | `portrait-demon-lord-48.png` · `portrait-demon-lord-96.png` | **필요** — `pixel_portrait.gd`가 벡터로 그린다 |
| ② | 스킬 아이콘 28종 전면 교체, 속성+동작이 한눈에 | `ui-skill-icons.png` (+ 런타임 경로 드롭인) | **불필요** — 기존 경로에 그대로 덮었다 |
| ③ | VFX 보강(저주/독 스택 · 터뜨림 버스트 · 시간 느려짐/빨라짐) | `vfx-stack-badge.png` · `vfx-burst.png` · `vfx-timeflow.png` | **필요** — 새 시트라 배선이 없다 |
| ④ | 상자 열기 애니메이션 교체 | `chest-open.png` (6프레임) | **필요** — `chest_open_effect.gd`가 `draw_rect`로 그린다 |
| ⑤ | 장비 부위 실루엣 4종 + 부위 배지 | `ui-slot-silhouettes.png` · `ui-slot-badges.png` | **필요** |
| ⑥ | 재화 아이콘 소형/대형 변형 | `ui-coin-{small,large,spin,pile}.png` | **필요** |
| — | (추가 발견) 필드 마왕이 반쪽만 그려지는 버그 | `boss-demon-king-v2.png` | **한 줄** — `enemy.gd`의 `tex` preload |

②만 코드 변경 없이 즉시 반영됩니다. 나머지는 전부 **에셋만 준비된 상태**이고
배선은 다음 웨이브 몫입니다(§5에 정확한 지점을 적었습니다).

---

## 2. 스킬 아이콘 28종 — 설계와 배정표

### 2.1 왜 구 아틀라스가 안 읽혔나

구 아틀라스(`art/generated/ui/skill-atlas-minimal-v2-runtime.png`, v1 AI 생성)는
28칸이 전부 "초승달 + 검 + 소용돌이"의 변주였습니다. 직접 확대해서 보면
`cleave`(달+검) / `boomerang_blade`(달+검) / `moon_barrier`(달+방패) /
`blood_pact`(달+검+피)가 축소되면 같은 얼룩이 됩니다.
게다가 이 아이콘들은 HUD 고스트 슬롯에서 **22px**로 그려집니다.

### 2.2 정보를 세 축으로 쪼갰다

| 축 | 표현 | 크기가 줄면? |
|---|---|---|
| **원소 7계** | 판 **색** | 색은 1px까지 남는다 — 마지막까지 살아남는 축 |
| **형태 5종** | 판 **실루엣** (참격=베인 사각 / 관통=화살촉 / 파동=원 / 설치=팔각 / 수호=방패) | 22px에서도 윤곽으로 남는다. 색약 대비이기도 하다 |
| **동작** | 20×20 **글리프** (잉크 + 크림 하이라이트) | 22px에서 뭉개져도 위 둘이 카드를 좁혀 준다 |

색은 `game.gd`의 `ELEMENT_COLOR`를 그대로 씁니다(새 표를 만들지 않았습니다).
화 주황 · 빙 청록 · 뇌 노랑 · 독 초록 · 유 보라 · 타 무채 · 초 자주.

### 2.3 배정표 (28장 · 셀 번호 = `skill_icon.gd`의 `GENERATED_SKILL_INDEX`)

| 셀 | id | 원소(판 색) | 형태(판 모양) | 글리프가 그리는 **동작** |
|---:|---|---|---|---|
| 0 | `cleave` | 타 · 무채 | 참격 | 굵은 반달 한 번 쓸기 |
| 1 | `rapid_slash` | 타 · 무채 | 참격 | 짧은 사선 3줄 |
| 2 | `flame_field` | 화 · 주황 | 설치 | 바닥 띠 + 솟는 불길 2줄기 |
| 3 | `whirlwind` | 독 · 초록 | 파동 | 소용돌이 회오리 |
| 4 | `thunder` | 뇌 · 노랑 | 파동 | 굵은 벼락 + 튀는 표적 점 2개 |
| 5 | `meteor_blade` | 화 · 주황 | 설치 | 비스듬히 떨어지는 덩어리 2개 + 착탄 |
| 6 | `guardian_blade` | 빙 · 청록 | 수호 | 고리 + 주위를 도는 칼날 3개 |
| 7 | `moon_barrier` | 빙 · 청록 | 수호 | 두꺼운 방패 윤곽 + 안쪽 초승달 |
| 8 | `dash_blade` | 빙 · 청록 | 참격 | 칼 + 뒤로 끌리는 속도선 2줄 |
| 9 | `targeting` | 뇌 · 노랑 | 관통 | 오른쪽 조준환 + 왼쪽에서 박히는 창 |
| 10 | `time_cut` | 뇌 · 노랑 | 참격 | 굵은 X 교차 베기 |
| 11 | `blood_pact` | 독 · 초록 | 참격 | 칼 + 되돌아오는 큰 물방울 |
| 12 | `aura` | 유 · 보라 | 설치 | 중심 점 + 둘러싼 안개 고리 2겹 |
| 13 | `shield_bash` | 초 · 자주 | 수호 | 왼쪽 방패 + 오른쪽 충격선 3줄 |
| 14 | `execution` | 독 · 초록 | 참격 | 화면을 채우는 거대 도끼날 하나 |
| 15 | `recursion` | 타 · 무채 | 관통 | 지그재그 궤적 + 되돌아오는 화살촉 |
| 16 | `cross_cut` | 독 · 초록 | 참격 | 굵은 십자(＋) 교차 |
| 17 | `blade_fan` | 초 · 자주 | 관통 | 왼쪽 한 점에서 퍼지는 광선 3줄 |
| 18 | `gravity_well` | 유 · 보라 | 설치 | 깔때기 + 안쪽을 향한 화살표 2개 |
| 19 | `lion_roar` | 화 · 주황 | 파동 | 왼쪽 벌린 아가리 + 퍼지는 호 2겹 |
| 20 | `phantom_step` | 뇌 · 노랑 | 수호 | 진해지는 잔상 3개 |
| 21 | `sword_rain` | 유 · 보라 | 설치 | 위에서 쏟아지는 줄기 3개 + 바닥 웅덩이 |
| 22 | `boomerang_blade` | 유 · 보라 | 관통 | 초승달 + 되돌아오는 곡선 화살표 |
| 23 | `battle_trance` | 초 · 자주 | 수호 | 앉은 형상 + 위쪽 후광 + 회복 십자 |
| 24 | `holy_pulse` | 초 · 자주 | 파동 | 중심 폭발 별 + 퍼지는 고리 2겹 |
| 25 | `earth_splitter` | 화 · 주황 | 관통 | 가로로 뻗는 굵은 균열 + 오른쪽 촉 |
| 26 | `thrust` | 타 · 무채 | 관통 | 창대 + 오른쪽 삼각 창끝 |
| 27 | `frost_ring` | 빙 · 청록 | 파동 | 동심원 2겹 + 중심 눈꽃 |

**원소별 4장이 서로 안 겹치는지**가 이 표의 실제 합격 기준입니다.
같은 색·같은 판 모양이 겹치는 조합은 독·참격 3장(`blood_pact` `execution` `cross_cut`)
하나뿐이고, 셋은 물방울 / 거대 도끼날 / 십자로 실루엣이 완전히 다릅니다.

### 2.4 판독성 자평

28칸을 실제 표시 크기 **22 / 32 / 48 / 80px**로 뽑고, 그것도 카드 배경
(슬레이트 + 원소색 22% 워시) **위에 얹어서** 눈으로 봤습니다. 즉
"흰 배경에서 예쁜가"가 아니라 **"실제로 놓이는 자리에서 서로 구분되는가"**를 봤습니다.

**또렷하게 읽힘 (22px)** — 14장
`cleave` `rapid_slash` `cross_cut` `time_cut` `thrust` `execution` `blade_fan`
`frost_ring` `moon_barrier` `sword_rain` `earth_splitter` `targeting` `dash_blade` `whirlwind`

**덩어리로만 읽히지만 덩어리 모양이 맞다** (= 다른 카드와 안 헷갈린다) — 12장
`flame_field` `meteor_blade` `lion_roar` `gravity_well` `aura` `guardian_blade`
`battle_trance` `recursion` `shield_bash` `holy_pulse` `blood_pact` `thunder`
(`holy_pulse`는 사실상 **과녁**으로 읽힙니다 — 중심 별이 7px라 "고리 안의 뜨거운 점"이
됩니다. 자주색이라 청록 `frost_ring`과는 안 겹칩니다.)

**22px에서 세부가 사라짐** (48px 이상은 문제없음) — 2장
- `phantom_step` — 잔상 3개의 "사람 모양"이 사라지고 굵기 다른 막대 3개로 읽힙니다.
  의도한 정보(3겹)는 남습니다.
- `boomerang_blade` — 초승달 날은 읽히지만 되돌아오는 화살촉이 어두운 꼬리 덩어리로 뭉갭니다.

**남아 있는 유사 쌍 3건 (색으로만 갈립니다)**

| 쌍 | 왜 닮았나 | 왜 괜찮다고 봤나 |
|---|---|---|
| `frost_ring` ↔ `holy_pulse` | 둘 다 원형 판 + 동심원 | 청록 ↔ 자주. 원소색이 1순위 축이라 색만으로 갈린다 |
| `thrust` ↔ `recursion` | 둘 다 무채 화살촉 판 + 화살 | 화살 방향이 반대(→ vs ↰). 32px부터 확실 |
| `aura` ↔ `holy_pulse` | 둘 다 동심원 | 팔각 보라 ↔ 원형 자주. 판 모양과 색이 둘 다 다르다. `aura`는 고리 두 겹을 **6엽 구름 한 겹 + 밝은 코어**로 바꿔 한 번 더 갈랐다 |

22px가 쓰이는 곳은 HUD 고스트 슬롯 하나이고, 그 자리는 "무슨 카드가 꽂혀 있는지"만
알면 되는 자리라 이 정도를 상한으로 잡았습니다.
편집 화면(48px) · 선택 모달(80px)에서는 28장 전부 또렷합니다.

**만들면서 포기한 것 3건** (같은 자리를 다시 만질 사람을 위해)

- `guardian_blade` — 22px에 "고리 + 칼날 3자루 + 중심점"은 안 들어갑니다.
  칼날을 **가시**로 바꿨습니다(고리에 뭔가 붙어 돈다는 정보는 남습니다).
- `execution` — 도끼 자루를 넣을 자리가 없습니다. 참격 판이 좌하·우상 모서리를
  베어 내기 때문입니다. 거대한 날 하나로 갔습니다.
- `targeting` — 관통 판이 오른쪽으로 뾰족해서 조준환의 **동쪽 눈금**이 잘립니다.
  남·북 눈금만 두고 서쪽은 창이 대신합니다.
- 참격 판 5장(`dash_blade` `time_cut` `blood_pact` `execution` `cross_cut`)은
  **좌상→우하 대각선만 안전합니다.** 반대 대각선은 잘린 모서리에 먹힙니다.
- `gravity_well` — 안으로 향하는 화살표를 **둘** 그리면 크기·각도·배치를 어떻게
  바꿔도 **얼굴로 읽힙니다**(눈썹 두 개 + 눈). 큰 화살표 **하나**가 웅덩이로
  꽂히는 그림으로 갔습니다.
- `aura` — 구름 고리 두 겹을 넣으려면 반지름이 10px 필요한데 9px밖에 없어서
  두 겹이 늘 붙거나 1px로 얇아졌습니다. **6엽 고리 한 겹 + 굵은 코어**로 갔고,
  덤으로 `holy_pulse`와 덜 닮아졌습니다.

### 2.5 검증한 계약

`skill_icon.gd`의 트리밍 알고리즘을 파이썬으로 그대로 재현해 28칸을 통과시켰습니다.

```
Counter({(52, 52): 28})     # 28칸 전부 52×52로 트리밍됨 (26×26 원본 ×2)
non-52x52 cells: none
```

경계상자가 28칸 모두 같으므로 **아이콘마다 화면 크기가 달라지는 사고가 없습니다.**
판 색이 "타일 색"으로 오인돼 flood fill에 파먹히는 사고도 없습니다(여백 6px > `TILE_RING` 4).

---

## 3. 수급한 웹 무료 팩 (라이선스)

정본은 `godot-game/art/external/LICENSES.md`입니다. 요약:

| 팩 | 경로 | 라이선스 | 크레딧 의무 | 파일 | 용량 |
|---|---|---|---|---:|---:|
| Ninja Adventure (기존) | `ninja-adventure/` | CC0 1.0 | 없음 | 1,453 | 11 MB |
| Kenney Particle Pack (기존) | `kenney-particle-pack/` | CC0 1.0 | 없음 | 81 | — |
| **game-icons.net** (신규) | `game-icons/` | **CC BY 3.0** | **있음** | 113 SVG | 476 KB |
| Kenney Board Game Icons (신규) | `kenney-board-game-icons/` | CC0 1.0 | 없음 | 255 PNG + 255 SVG | 2.1 MB |
| OwlishMedia RPG UI Icons (신규) | `owlishmedia-rpg-icons/` | CC0 1.0 | 없음 | 108 PNG | 436 KB |

### ⚠️ CC BY 의무가 하나 생겼습니다

`LICENSES.md`의 첫 요약문은 원래 "전부 CC0, 크레딧 의무 없음"이었고 **이제 사실이
아닙니다.** game-icons.net은 아이콘마다 `"Icons made by {author}"`를 요구하고,
우리가 남긴 113개의 작가는 9명입니다(Lorc 68 · Delapouite 31 · Sbed 5 · Skoll 3 ·
Willdabeast 2 · Felbrigg 1 · DarkZaitzev 1 · Cathelineau 1 · Carl Olsen 1).
그대로 붙여 넣을 크레딧 블록은 `LICENSES.md` §6에 있습니다.

**이번 라운드 산출물 중 이 팩에 의존하는 것은 하나도 없습니다.**
의무를 지고 싶지 않으면 `art/external/game-icons/` 디렉터리를 지우면 그만입니다.

### 왜 받아 놓고 안 썼나

28종에 쓸 수 있는지 실제로 래스터화해서 비교했습니다(`ASSET_MAP.md` §21).

1. 20px 래스터화 → 안티에일리어싱 회색 번짐이 남아 NA 하드에지 픽셀아트와
   **두 가지 그림 매체**로 보입니다.
2. 알파 45% 이진화 → 번짐은 사라지지만 획이 가는 아이콘(`bracer` `stack`)이
   1px 노이즈로 부서집니다.
3. 결정적으로 **획 굵기를 통제할 수 없습니다.** 22px에서 읽히려면 모든 획이
   2px 이상이어야 하는데 원본 SVG는 그 제약을 모릅니다.

세 팩은 라이선스 정리 + **검증된 래스터화 명령**(`LICENSES.md` §8)까지 끝내서
남겨 둡니다. 32px 이상 메뉴 아이콘이 필요해지면 바로 꺼내 쓸 수 있습니다.
Kenney SVG는 `viewBox`가 없어 ImageMagick이 거부하므로 `viewBox="-32 -32 64 64"`를
주입해야 한다는 함정도 그 절에 적혀 있습니다.

---

## 4. 발견한 버그 — 필드 마왕이 반쪽만 그려진다

**에셋 쪽 문제라 여기에 적습니다.** `ASSET_MAP.md` §4는
`Actor/Boss/GiantRedSamurai/Idle.png`(576×48)를 "48×48 프레임 12장"으로 적고
있는데, 빈 열을 실측하면 내용 덩어리가 **6개**이고 한 덩어리 폭이 **70px**입니다.
쌍검을 벌린 사무라이가 48px에 들어갈 리 없습니다 — **실제는 96×48 6프레임**입니다.

그래서 구워진 `boss-demon-king.png`는 사무라이 하나가 셀 두 칸에 걸쳐 있고
(행 0 내용 = x 39-248 / 327-536 / … 폭 210 · 간격 288 ↔ 셀 경계는 144의 배수),
`enemy.gd`가 셀 하나를 그리면 마왕의 절반만 나옵니다.

`boss-demon-king-v2.png`가 **`enemy.gd` 상수를 하나도 안 바꾸고** 이걸 고칩니다
(시트 1728×2880 · 셀 144×288 · `mask_y` 1440 · `foot` 0 · 12/12/8/8/8 전부 동일).
배율을 ×3 → ×2로 낮추고 96px 프레임의 가운데 72px을 잘라 쓰며, 실프레임
6/6/4/4/4장을 한 장씩 두 번 넣어 칸을 채웁니다(애니메이션이 절반 속도로
정상 재생됩니다 — 그림이 반으로 잘리는 것보다 낫다는 판단).

**적용은 한 줄**입니다.

```gdscript
# scripts/enemy.gd · BOSS_SHEETS["demon_king"]
"tex": preload("res://art/v2/boss-demon-king-v2.png"),   # boss-demon-king.png → -v2
```

원본 `build_assets.gd`와 그 산출물은 손대지 않았습니다.

---

## 5. 경로 표 — 무엇을 어디에 배선하나

| 산출물 | 경로 | 규격 | 배선 지점 | 지금 상태 |
|---|---|---|---|---|
| 마왕 초상(대) | `art/v2/portrait-demon-lord-96.png` | 96×96 | `game.gd:7882` 부근 · 밀정/보스 모달 | `PixelPortrait` 벡터 드로잉을 `TextureRect`로 교체 필요 |
| 마왕 초상(소) | `art/v2/portrait-demon-lord-48.png` | 48×48 | `game.gd:7884` 보스 토스트(현재 74×104 `PixelPortrait`) | 〃 |
| 스킬 아이콘 | `art/v2/ui-skill-icons.png` | 448×256 · 7×4 · 셀 64 | `skill_icon.gd:4` `GENERATED_SKILL_ATLAS` | **이미 반영됨**(런타임 경로에 드롭인) |
| 〃 드롭인 사본 | `art/generated/ui/skill-atlas-minimal-v2-runtime.png` | 동일 | — | 원본 백업: `tmp/ya-backup/…orig.png` |
| 마왕 필드 시트 | `art/v2/boss-demon-king-v2.png` | 1728×2880 · 셀 144×288 | `enemy.gd:51` `BOSS_SHEETS["demon_king"]["tex"]` | 한 줄 교체 |
| 빈 슬롯 실루엣 | `art/v2/ui-slot-silhouettes.png` | 160×40 · 셀 40 · 4칸 | 편집 화면 빈 장비 칸 | 미배선 |
| 부위 배지 | `art/v2/ui-slot-badges.png` | 160×40 · 셀 40 · 4칸 | 장비 카드 헤더 | 미배선 |
| 금화(소) | `art/v2/ui-coin-small.png` | 16×16 | 가격 문자열 인라인 | 미배선 |
| 금화(대) | `art/v2/ui-coin-large.png` | 40×40 | 지불 버튼 · 상점 헤더 | 미배선 |
| 금화(회전) | `art/v2/ui-coin-spin.png` | 80×20 · 4프레임 | 보상 팝업 | 미배선 |
| 금화(더미) | `art/v2/ui-coin-pile.png` | 48×32 | 총액 · 정산 | 미배선 |
| 상자 열기 | `art/v2/chest-open.png` | 384×64 · 6프레임 · 셀 64 | `chest_open_effect.gd` 전체 | 미배선 |
| 스택 배지 | `art/v2/vfx-stack-badge.png` | 160×32 · 셀 32 · 1~5 | 몹 머리 위 상태 표시(`enemy.gd`의 핍 옆) | 미배선 · **중립색이라 `modulate` 필요** |
| 터뜨림 버스트 | `art/v2/vfx-burst.png` | 384×64 · 6프레임 · 셀 64 | 상태 폭발 시점 | 미배선 · **중립색** |
| 시간 흐름 | `art/v2/vfx-timeflow.png` | 192×96 · 셀 48 · 4프레임 × 2행 | 둔화/가속 버프 배지 | 미배선 · 행0 느림 / 행1 빠름 |

**슬롯 4종 순서는 어디서나 `weapon / necklace / ring / bracelet`** 입니다
(`item_library.gd`의 slot 키 순서와 같습니다).

---

## 6. 손대지 않은 것

- 게임 `.gd` 로직 전부(`scripts/**`). 읽기만 했습니다.
- `scripts/test/test_runner.gd` · `scripts/test/run_all.sh`.
- 형제 빌더 3개(`build_assets.gd` · `build_assets_v3.gd` · `build_assets_ui.gd`)와
  그 산출물 63장. YA 빌드 전후로 **바이트가 안 바뀝니다.**
- `art/external/ninja-adventure/` · `kenney-particle-pack/` 원본 파일.
- git. 커밋·브랜치·푸시 하지 않았습니다.

**단 하나의 예외**가 `art/generated/ui/skill-atlas-minimal-v2-runtime.png`
드롭인입니다. 이유·백업·되돌리는 법은 `ASSET_MAP.md` §19-2에 있습니다.

---

## 7. 검증

| 검사 | 결과 |
|---|---|
| `build_assets_y.gd` 실행 | **OK** — 15장 · 약 150 ms |
| `--editor --quit` 임포트 | **오류 0** (`art/v2/*.import` 77개) |
| 결정성 (연속 2회 SHA-256) | **15장 전부 동일** |
| 트리밍 계약 시뮬레이션 | **28칸 전부 52×52** (§2.5) |
| 형제 빌더 산출물 63장 | **무변경** — `art/v2/*.png` 77장 중 이번 세션에 mtime이 바뀐 것은 YA 산출 14장뿐 (표본 5장 SHA-256도 대조) |
| `run_all.sh` | **FAIL 5건 — YA와 무관** (아래) |

**결정성**: 빌더는 난수·시각을 쓰지 않습니다. 상자 반짝이·버스트 파편 배치도
index로 각도를 만듭니다.

**빌드 시 자기검증**: `_verify_cards()`가 매 빌드마다 28장의 id·원소·형태를
`DealCardLibrary.by_id()`로 대조하고 글리프 격자가 20×20인지 확인합니다.
아이콘이 엉뚱한 카드에 붙는 사고는 assert로 즉시 죽습니다.
(빌드 중 `deal_card_library.gd`가 다른 웨이브에 의해 506 → 640줄로 커졌지만
28장의 id·원소·형태는 그대로여서 이 대조는 계속 통과했습니다.)

### run_all FAIL 5건은 YA 산출물 때문이 아닙니다

```
FAIL  v4-test      rune_stack=false  slot_swap=false  two_gesture=false
FAIL  castle-test  rune_shop=false
FAIL  stage-test   curve=false  reward_decay=false
FAIL  cycle-test   debt_reload=false  flow_rune=false  reentry=false  runtime=false  slot_swap=false
FAIL  draft-test   flow_suppress=false  stack_cap=false
```

근거 셋:

1. **거짓이 된 플래그가 전부 게임 로직 축**입니다 — 각인 스택·칸 교체·제스처·
   각인 상점·난도 곡선·보상 감쇠·빚 재장전·흐름 각인. 그림과 접점이 없습니다.
2. **같은 세션 동안 다른 웨이브가 게임 스크립트 6개를 고치고 있습니다.**
   `factory_deck.gd`(22:27) · `monster_library.gd`(22:28) · `deal_card_library.gd`(22:30) ·
   `core/tuning.gd`(22:29) · `core/status_engine.gd`(22:24) · `core/rune_engine.gd`(22:26).
   `scratchpad/runall.log`(18:47)은 15종 전부 PASS였습니다.
3. **직접 격리했습니다.** 드롭인 아틀라스를 원본으로 되돌리고 `--v4-test`만
   다시 돌렸더니 **똑같이** `rune_stack=false slot_swap=false two_gesture=false`로
   실패했습니다. 그 뒤 드롭인을 복구했고 SHA-256이 `ui-skill-icons.png`와 일치함을
   확인했습니다.

`compile`은 PASS입니다 — 문법이 깨진 곳은 없습니다.

---

## 8. 남은 문제 · 다음 웨이브가 알아야 할 것

1. **`pixel_portrait.gd`는 아직 구버전 마왕을 그립니다.** 에셋은 준비됐지만
   그 파일은 `Control._draw()`로 도형을 찍는 구조라 텍스처로 바꾸려면
   노드 종류부터 바뀝니다(`Control` → `TextureRect`). 호출부는 `game.gd` 두 곳뿐입니다.
2. **`chest_open_effect.gd`도 같은 구조**입니다. 6프레임 시트를 쓰려면
   `elapsed / duration`으로 프레임 index를 골라 `draw_texture_rect_region` 하면
   되고, 현재 `duration = 0.52`에 6프레임이면 프레임당 0.087초입니다.
3. **VFX 3종은 중립색으로 구웠습니다.** 스택 배지와 버스트는 `modulate`로
   상태색을 입히는 것을 전제합니다. 그대로 그리면 흰색입니다.
4. **`ui-skill-icons.png`의 셀 순서는 `skill_icon.gd`의 `GENERATED_SKILL_INDEX`와
   묶여 있습니다.** 카드를 추가·삭제하려면 그 사전과 빌더의 `SKILL_ORDER`를
   **같이** 고쳐야 합니다. 아틀라스는 7×4 = 28칸 고정입니다.
5. **트로피 카드 12종(`SPECIALS`)은 여전히 벡터 드로잉**입니다
   (`skill_icon.gd`의 `_draw_star` 등). 아틀라스가 28칸뿐이라 자리가 없습니다.
   같은 문법(원소색 판 + 형태 실루엣 + 글리프)으로 12칸짜리 시트를 하나 더
   구우면 되고, 그때는 `skill_icon.gd`에 분기가 하나 늘어납니다.
6. **`game-icons/`의 CC BY 크레딧**을 게임 안 어딘가에 넣을지, 팩을 지울지
   결정이 필요합니다(§3).
