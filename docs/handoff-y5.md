# handoff-y5 — 필드 생태 (`game.gd` 직렬 체인 4/6)

**근거 문서**: `docs/FEEDBACK_Y.md` §5 전체 · §9.3 Y5 · §9.4 · 리스크 3·4·8 ·
`docs/handoff-y1.md` §7(습성 데이터 명세) · `docs/handoff-y4.md` §5 · §8.1 · §9-A

**소유 파일**: `scripts/game.gd` · `scripts/enemy.gd` · `scripts/world_grid.gd` ·
`scripts/wfc_chunk_generator.gd` · `scripts/core/combat_resolver.gd` ·
`scripts/test/test_runner.gd` · `scripts/test/rift_probe.gd` · `scripts/test/run_all.sh` ·
`scripts/test/terrain_probe.gd`(신설) · `docs/handoff-y5.md`(이 문서)

---

## 0. 한 문장

돌이 길을 막고 물이 2%에서 **15.7%**로 늘었으며, 몹 열 종이 **습성 다섯**으로 갈려
낮에는 무리 지어 배회하고 도망가고 매복하고, **1·2스테이지 낮에는 아무도 먼저 덤비지 않는다.**

---

## 1. 검증 결과 (전부 이 웨이브가 직접 실행)

| 검사 | 결과 |
|---|---|
| `--editor --quit` | 종료코드 **0** |
| `run_all.sh` **16종** | **전부 PASS · 3회 연속 재현** (범위 밖 실패 0건) |
| `rift_probe.gd` | `failures=0 verdict=PASS` (검사 5종 · **시드 100개**) |
| `terrain_probe.gd`(신설) | `verdict=PASS` · 300/300 표본이 계약 창 안 · 블록 불변식 위반 **0** |
| `--capture-world` | 10컷 · **고유 지문 10개**(프레임 흘림 0) · 육안 검수 완료 |

### 1.1 계측값

```
WORLD  wet stage1=0.1612 stage3=0.1568 stage5=0.1639  band=0.12~0.20
       castle_d=785 camp_d=2929 gate_d=3449          ← 캠프가 보스문보다 먼저
FIELD  wired species=10 checked=10 mismatch=0 habits=5/5
       day shy_gain=198px shy_aggro_frames=0 stalk_drift=0.0px guard_far_aggro=0
           herd_return=95px hunt_s3=1 hunt_s2=0
       aggro s2_spawned=149 s2_behavior4=0 · s3_spawned=117 s3_behavior4=8 · gate=[0 0 1 1]
       terrain rolls=2400 forest_stalk=29.0% grass_stalk=12.2%
                          grass_herd=42.2%  forest_herd=24.1%
       herd stood=4 wanted=4 spread=70px(max 120) limit=59 peak=59 cap=78
       detour found=1 detour_frames=28 on_rock=0 moved=233px
STRESS surge_rolls=200 surge_groups=144 surge_peak=59 surge_limit=59 surge_cap=78
TERRAIN aggregate wet=0.1568 (470,508 / 3,000,000) · min=0.126 max=0.200 · 300/300 in band
```

---

## 2. Y5 정의 대비 항목별 처리

| §9.3 Y5 항목 | 처리 |
|---|---|
| 돌 충돌 | `is_walkable()` = 「물 **또는 돌**이면 불가」(다리 예외). 플레이어·적 공용 |
| 물 증량 | `LAKE_CELL 18→13` · `LAKE_CHANCE 9→19` · 반지름 `[1,1,2,2,2,3]→[2,3,3,3,3,4]` → **15.7%** |
| habit 5종 | `enemy.gd`에 습성 층 신설. 낮/밤이 코드에서 실제로 갈린다(§4) |
| 지형 스폰 가중 | `combat_resolver.roll_archetype_for_terrain()` 신설 — 자리를 먼저 잡고 지형이 종을 정한다 |
| 무리 스폰 | `herd`가 뽑히면 3~5기 동시. 개체 상한 절대 불가침 |
| 낮/밤 패턴 | 밤은 `raid_mode` 그대로, 낮은 습성 층. **1·2스테이지 낮 선공 0을 런타임으로 보증** |

### 넘겨받아 처리한 것
- **`vfx-stack-badge.png` 배선**(handoff-y4 §9-A) — 몹 머리 위 핍 줄 오른쪽, 독 **2겹부터**,
  `STATUS_TINTS["poison"]` 곱, 16×16으로 눌러 그림. 정적(트윈 없음).
- **`--capture-world` 대표 컷 수리**(handoff-y4 §8.1) — 균열 컷 뒤 플레이어를 원래 자리로
  되돌리고 카메라 스무딩을 리셋한다. 지문이 실제로 갈렸다(전: 동일 → 후: 다름).

### 소속을 확인하고 **넘긴** 것
- **공유 렌더러 글자 겹침 2건**(handoff-y4 §8.4) — `_build_preview_slot()`(소비자 **7곳**:
  마왕 프리뷰 2 · 스테이지 보스 프리뷰 2 · 밀정 1 · 결과 화면 1 · 편집 1)과
  `_card_block_panel()`(교체 확인 1곳). **둘 다 필드 생태가 아니다** — 보스 프리뷰는 Y2,
  밀정은 Y3, 결과·교체 확인은 Y4의 화면이다. Y5 정의(§9.3)에 없으므로 손대지 않았다.
  **YZ 몫이다**(리스크 ⑨의 "합치지 말 것"이 그대로 유효).

---

## 3. 물 증량 — 상수 셋은 **같이** 움직여야 한다

비율만 맞추면 되는 줄 알고 두 번 헤맸다. 버린 후보를 남긴다:

| 후보 | 총합 | 실제 화면 | 판정 |
|---|---|---|---|
| `CHANCE 41` · 반지름 `[1,2,2,2,2,2]` | 16.1% | 작은 **물웅덩이 노이즈** | ✗ "바다"로 안 읽힘 |
| `CHANCE 9` · 반지름 `[4,4,4,5,5,5]` | 14.9% | 호수는 크지만 한 화면에 **0.46개** → 절반은 물 0 | ✗ 늘어난 게 안 보임 |
| **`CHANCE 19` · 반지름 `[2,3,3,3,3,4]`** | **15.7%** | 한 화면 약 1개 · 지름 10~18칸(400~720px) | ✓ 채택 |

> ⚠️ 첫 후보는 **300 표본 중 19개가 계약 창 밖**이었다(10.4~20.9%). 채택안은 **300/300**이다.
> `docs/FEEDBACK_Y.md` §5.1은 "`LAKE_CELL`과 반지름만 만진다"라고 적었지만, 그 둘만으로는
> **총량과 "화면에 보이는가"를 동시에 만족시킬 수 없다.** `LAKE_CHANCE`가 세 번째 손잡이다.
> **2x2 블록 합집합 규칙과 짝수 정렬은 한 줄도 안 건드렸다** — 프로브가 매번 확인한다
> (`impossible_shapes=0` · 젖은 칸 268,748개 검사).

---

## 4. 습성 5종이 코드에서 어떻게 갈리는가

`_update_field_aggro()`는 맨 위에서 `raid_mode`(밤)면 즉시 반환한다 → **습성 층은 전부 낮 규칙**이다.

| 습성 | 낮 | 밤 |
|---|---|---|
| `herd` 무리 | 배회 중심이 개체 자리가 아니라 **무리 중심**(`herd_center`). 3~5기 동시 스폰 | 함께 몰려온다(`raid_mode`) |
| `shy` 겁쟁이 | 260px 안이면 `aggro=false` + `flee_timer` 갱신 — **맞아도 도망간다** | 돌변해 덤빈다(`raid_mode`) |
| `guard` 텃세 | 165px 안이면 반격. 추격이 끝나도 **집을 새로 잡지 않는다** | 추적 |
| `stalk` 매복 | 210px 밖이면 **이동 방향 자체가 `Vector2.ZERO`** (배회를 안 탄다) | 추적 + 속도 ×1.20 |
| `hunt` 사냥꾼 | 310px 감지. 단 `stage_aggro_gate_ok(stage,false)`가 false면 **강제로 꺼진다** | 추적 |

### 낮 선공 0은 **두 겹**이다
스폰 필터(`stage_spawn_allowed`)만으로는 **밤에 태어나 아침까지 살아남은 늑대**를 못 막는다.
그래서 ① 습성 층이 매 프레임 끄고 ② `set_night_raid(false)`(새벽)가 한 번 더 끈다.
검사도 두 겹이다 — 데이터 축 `gate=[0 0 1 1]` + 런타임 축 `s2_behavior4=0` / `s3_behavior4=8`
(**음성 축이 없으면 "아무것도 안 스폰돼서 통과"와 구분이 안 된다**).

### 돌 우회 (리스크 3)
추적 중에는 이동 방향이 플레이어 직선이라 기존 `wander_direction.rotated(90°)`가 **아무 일도 안 한다**.
막히면 이동 방향을 좌우 90°로 꺾어 `radius*1.8` 앞을 물어 **뚫리는 쪽**을 고르고 `detour_timer=0.45`.
타이머가 끝나면 직선 추적 복귀 — **무한 루프가 아니다.** 실측 `detour_frames=28 on_rock=0 moved=233px`.

---

## 5. 밟은 함정 · 다음 웨이브가 알아야 할 것

1. **⚠️ 아레나·랜드마크 덮개가 타일 *중심*만 봤다 — 돌 충돌이 그 반 칸을 무기로 만들었다.**
   Y5 이전에는 덮개 밖으로 삐져나온 반 칸에 잔디가 놓여도 아무 문제가 없었다. 돌을 막는 순간
   **균열 아레나 가장자리(중심 142px)가 통행 불가**가 됐다 — 그 칸의 중심은 155px이라 덮개 밖이다.
   `rift_probe` ③이 잡았다(`blocked_samples=1/72 kind=rocks`). `_cover_hits()`로 고쳤다 —
   **원과 조금이라도 겹치는 칸은 전부 덮는다**(중심 거리 < 반지름 + 반 대각선 28.3px).
   성·캠프·보스문에도 같은 규칙이 걸린다.
2. **⚠️ 물이 늘자 캠프가 보스문보다 바깥으로 밀려났다.** `_nearest_dry_spot()`은 최대 800px까지
   아무 방향으로나 흔드는데, 마른 자리가 귀해지자 그 흔들림이 커졌다(`camp_d 4190 > gate_d 4117`).
   "정비하고 들어간다"의 기계적 실체가 깨진다. `_nearest_dry_spot()`에 **거리 상한 인자**를 더해
   캠프만 `보스문 거리 − SAFE_ZONE_CAMP` 안으로 묶었다. 못 찾으면 원래 자리(보스문–스폰 선 위)로
   떨어지고 그 자리는 **정의상 보스문보다 가깝다.** 성·보스문 호출은 기본값이라 무변경이다.
3. **⚠️ 스폰 자리가 처음으로 막힐 수 있게 됐다.** 원점(0,0)에는 랜드마크 덮개도 dry zone도 없었다.
   `world_grid`에 `SAFE_ZONE_SPAWN 120px` dry zone을 깔아 물을 막고, 돌은 dry zone으로 못 막으므로
   `game._walkable_spawn_point()`가 한 번 더 구제한다. **이어하기 복원 뒤에도 부른다** —
   저장될 때는 멀쩡했던 자리가 새 규칙에서는 막힐 수 있다.
4. **⚠️ 검사 세 개가 "매 실행 난수"였고 Y5가 난수 줄기를 밀자 드러났다.** 전부 Y5 회귀가 아니라
   **원래 있던 흔들림**이다. 셋 다 재현 가능하게 고쳤다:
   - `--draft-test target_prose <= 2` — 어떤 각인이 뽑히느냐에 달려 있었다(실측 10회 중 1회 실패).
     드래프트 직전에 시드를 박았다. **상한 2가 옳은지는 Y3/YZ 판단이다** — 가장 긴 각인이 뽑히면
     20자 이상 줄이 셋이 된다. 그때는 시드를 지우고 15종 전수로 재는 것이 정답이다.
   - `--world-test wet` — 창 **하나**(160타일)로 쟀더니 큰 호수가 들락거리며 계약이 뒤집혔다.
     **멀리 떨어진 네 창을 합산**한다(창당 200타일 · 표본 약 17,956개). 실측 숫자를 한 줄 더 찍는다 —
     `wet=false`만 보고는 얼마나 벗어났는지 알 수 없어 두 번 헤맸다.
   - `--save-test fields` — 저장 지점이 새 규칙에서 막힌 자리면 **복원 쪽만** 구제가 걸려
     좌표 왕복 지문이 어긋났다. 검사가 저장 전에 걸을 수 있는 자리로 맞춘다(구제 경로 자체는
     `--field-test`가 따로 문다).
5. **⚠️ 디버그 `print`가 `=false`를 찍으면 `run_all.sh`가 통째로 FAIL이 된다.**
   `enemy.gd`에 남아 있던 `print("Y5BLOCK … detouring=%s")`가 정확히 그랬다 — 추적 몹이 지형에
   막히는 **모든** 검사를 빨갛게 만들 수 있었다. `combat_resolver`의 스폰당 `print`도 함께 지웠다.
   무리 스폰 관측은 `combat.last_herd_stood` / `last_herd_wanted` 변수로 바꿨다.
6. `MonsterLibrary`는 **한 줄도 안 고쳤다.** 지형 가중은 공개 API 셋
   (`stage_pool` · `stage_spawn_allowed` · `stage_spawn_weight`)에 `habit_terrain_scale()`을
   곱하는 조합일 뿐이다 — 밸런스의 정본은 여전히 그 파일 하나다.
7. **v3의 임프 무리 블록을 삭제했다**(`behavior==3 and not night and randf()<0.45`).
   imp의 습성이 `herd`라 새 무리 경로와 완전히 겹친다 — 남겨 두면 같은 무리가 두 번 서서
   개체 상한을 이중으로 먹고, 밤에는 임프만 무리를 못 짓는 낡은 규칙이 남는다.
8. **`current_enemy_limit()`은 `MAX_ENEMIES 78`로 클램프된다 — 코드로 확인했다**
   (FEEDBACK_Y §12 추측 3 해소). `StageClock.night_enemy_limit_at()` / `day_enemy_limit_at()`
   둘 다 `mini(GameTuning.MAX_ENEMIES, …)`다. 무리 스폰은 그 위에서 남은 자리만큼만 자른다
   (`surge_peak=59 ≤ surge_limit=59 ≤ cap=78`).

---

## 6. 신설 API · 신설 검사

**`wfc_chunk_generator.gd`**: `is_rock_tile(id)` · `tile_name(id)`
**`world_grid.gd`**: `tile_kind_at(point)` · `is_rock_at(point)` ·
`measure_terrain_mix(center, tile_span, stride)` · `_cover_hits()` ·
`_nearest_dry_spot(..., max_from_spawn)` · `SAFE_ZONE_SPAWN`
**`enemy.gd`**: `habit` · `herd_center` · `set_herd_center()` · `detour_direction` · `detour_timer` ·
`HABIT_STALK_AMBUSH_RANGE 210` · `HABIT_GUARD_RANGE 165`
**`combat_resolver.gd`**: `roll_archetype_for_terrain(tile_kind)` · `last_herd_stood` · `last_herd_wanted`
**`game.gd`**: `_walkable_spawn_point(origin)`

| 검사 | 무엇을 새로 무는가 |
|---|---|
| `--world-test` **+5** | `wet`(12~20% · 4창 합산) · `rock_blocks` · `landmark_reach` · `spawn_open` · `tile_kind` |
| **`--field-test`** 신설 | `habit_wired` · `habit_day` · `day_aggro_zero` · `terrain_spawn` · `herd_spawn` · `rock_detour` |
| `--stress-test` +1 | `surge` — 무리 동시 스폰이 상한 근처 200굴림에서 78을 안 넘는다 |
| `rift_probe` +1 | ⑤ `seed_robustness` — **시드 100개** 배치 실패 0 · 랜드마크 3종 보행 가능 |
| `terrain_probe` 신설 | 물 비율 300표본 + **2x2 블록 불변식** + 지도 덤프(사람 눈용) |

> **`run_all.sh`가 15종 → 16종이 됐다.** `--field-test`가 `--world-test` 바로 뒤에 들어간다.
> AGENTS.md 등 "15종"이라 적은 문서는 오케스트레이터/YZ가 갱신해야 한다.

---

## 7. 음성 대조

이 웨이브의 새 단언은 **되돌려 재는 것**으로 판별력을 확인했다(총 16건).
`--field-test` 12건 + `rift_probe` 3건은 **테스트 안에서 상태를 심는 방식**으로 했다
(소유 밖 파일을 흔들지 않기 위해서다). 대표적인 것만 적는다:

| 되돌린 것 | 빨개진 플래그 | 진단 수치 |
|---|---|---|
| 개체 1기의 `habit`을 손으로 바꿈 | `habit_wired` | `mismatch 0→1` |
| 위습 `habit="hunt"`(겁쟁이 무력화) | `habit_day` | `shy_aggro_frames 0→66` · `shy_gain +198→−88px` |
| 그림자 `habit="hunt"`(매복 정지 무력화) | `habit_day` | `stalk_drift 0.0→3.0px` |
| `set_herd_center()` 생략 | `habit_day` | `herd_return +95→−8px` |
| 스테이지 3에서 "스테이지 2" 인구조사 | `day_aggro_zero` | `s2_behavior4 0→16` |
| forest 대신 grass를 두 번 굴림 | `terrain_spawn` | `forest_stalk 28.6→12.4%`(격차 소멸) |
| 상한+20까지 채움 | `herd_spawn` · `surge` | `peak 59→78 > limit 59` · `groups 6→0` |
| 추적자를 돌 반대편에 배치 | `rock_detour` | `detour_frames 28→0` · `moved 233→60px` |
| 예산+1 균열 요청 | `rift_probe ⑤` | 5시드 전부 `reason=budget_exhausted` |

> ⚠️ **`herd_spawn`·`surge`의 `groups>0`은 빼놓을 수 없다.** 무리가 한 번도 안 나면
> "상한을 안 넘었다"가 공허하게 통과한다 — 이 라운드에서 세 웨이브 연속 나온 함정의 같은 얼굴이다.

---

## 8. 캡처 검수

`--capture-world` **10컷 / 고유 지문 10개**. 잔여 godot 인스턴스 0 확인 후 촬영(리스크 8).

| 컷 | 확인한 것 |
|---|---|
| `world-minimal-v2.png` | **대표 컷이 순수 월드로 돌아왔다**(전에는 균열 컷과 지문이 같았다). 돌·무리·성 안뜰 |
| `-stage3-day.png` | **호수 + 물가 포말선이 깨끗하다**(2x2 블록 불변식의 육안 증거). 돌 흩뿌림 |
| `-stage5-night.png` | 5스테이지 밤 + 안개 + 비네트에서 돌·몹·체력바가 전부 읽힌다 |
| `-landmark-camp.png` | 캠프·보스문 덮개 **안에 돌이 하나도 없다**(§5-1 덮개 수리의 육안 증거). 호수 물가 |
| 나머지 | 회귀 없음 |

> **관찰 1건(회귀 아님)**: 스테이지 1 시작 화면에는 물이 안 보일 수 있다. 스폰 dry zone(120px)과
> 성 dry zone(190px)이 시작 시야를 꽤 덮고, 호수가 한 화면에 평균 1개라 없는 화면도 나온다.
> 총량은 15.7%이고 걸어 나가면 곧 만난다. 시작 화면에서까지 물을 보이고 싶다면
> `SAFE_ZONE_SPAWN`을 줄이는 대신 **스폰이 물가에 붙는 위험**을 같이 재야 한다.

---

## 9. 이 웨이브가 하지 않은 것

- `game.gd` Y6~Y7 구역(발견 내비 · 랜덤 이벤트 · 재미 아이템 · 타격감)
- **밸런스 숫자 0개.** `core/tuning.gd` 무접촉 — §5.5의 HP·물량 신값은 Y0이 이미 넣었고
  재측정은 Y8이다. `--stage-test`의 dwell 곡선 대조표도 Y8 몫으로 남겼다
  (handoff-y1 §8의 `DWELL_DAMAGE_LINEAR` 불변식은 **Y2가 이미 교체했다** — 확인함)
- 공유 렌더러 두 곳의 글자 겹침(§2 · YZ)
- `vfx-burst` · `vfx-timeflow` 배선(Y7) · `ui-coin-spin`(Y6) · `ui-kit-skill-shape`(YA 미납)
- `--draft-test target_prose` **상한 2의 적정성 판단**(§5-4 · Y3/YZ)
- `docs/FEEDBACK_Y.md` 자체 수정 — **§5.1의 "`LAKE_CELL`과 반지름만 만진다"는 실제로는
  부족했다**(§3). 문서를 고칠 권한이 없어 여기 적어 둔다.
- **`AGENTS.md` §1 체크포인트 갱신** — 이번 웨이브도 `AGENTS.md` 수정이 금지됐다.
  §9.1의 "매 웨이브 끝에 체크포인트 갱신" 규약과 어긋나므로 **오케스트레이터가 반영해야 한다.**
  반영할 내용은 이 문서 §0 · §1 · §6의 "16종" 사실이다.
