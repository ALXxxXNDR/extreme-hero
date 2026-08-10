# W8 인수인계 — 월드·랜드마크 (동적 균열)

> 작성: W8 구현 웨이브 / 2026-08-07
> 수정한 파일: `godot-game/scripts/world_grid.gd` **단 하나**.
> `wfc_chunk_generator.gd`는 **한 줄도 고치지 않았다**(설계 §7.1 "유지(무수정)" 유지).
> `game.gd`·`test_runner.gd`·`enemy.gd`는 건드리지 않았다. 아래 §3이 그쪽에서 붙일 훅 목록이다.

---

## 1. 신설 API — `WorldGrid` (`scripts/world_grid.gd`)

### 1.1 수명주기

| 시그니처 | 반환 | 설명 |
|---|---|---|
| `begin_run_rifts(run_seed: int) -> void` | — | 런 시작 시 1회. 균열 목록·예산·시드를 초기화한다. **`_begin_run()`에서 반드시 부를 것.** |
| `spawn_rift_near(player_position: Vector2, run_seed: int = -1) -> Dictionary` | 균열 사전 / `{}` | 균열 1개를 연다. `run_seed >= 0`이면 그 값으로 시드를 덮어쓴다(보통 생략). 거절 시 빈 사전. |
| `despawn_rift(rift_id: String) -> bool` | 성공 여부 | 월드에서 지운다. **런당 3회 예산은 돌려주지 않는다.** |
| `set_rift_cleared(rift_id: String, cleared: bool = true) -> bool` | 성공 여부 | 클리어 표시(렌더가 체크 마크로 바뀐다). |

### 1.2 조회

| 시그니처 | 반환 | 설명 |
|---|---|---|
| `get_rifts() -> Array[Dictionary]` | 복사본 배열 | 전체 목록 |
| `get_rift(rift_id: String) -> Dictionary` | 복사본 | id로 1개 |
| `get_active_rift() -> Dictionary` | 복사본 | 가장 최근에 열린 **미클리어** 균열 |
| `get_nearest_rift(point, radius := 520.0, include_cleared := false) -> Dictionary` | 복사본 | 근접 판정용. 기본 반경 520px은 구 `_check_trial_camps()`의 값 그대로 |
| `rift_at(point: Vector2) -> Dictionary` | 복사본 | 이 점이 어느 균열 아레나 안인지 |
| `get_rift_compass(point: Vector2) -> Dictionary` | `{id, position, distance, direction}` | HUD 나침반용(§5.5의 "나침반") |
| `rift_budget_remaining() -> int` | 0~3 | 남은 개설 횟수 |
| `get_last_rift_result() -> String` | `"ok"` / `"budget_exhausted"` / `"no_site"` / `"none"` / `"restored"` | 직전 요청 결과 |

### 1.3 저장/이어하기 (W12용)

| 시그니처 | 설명 |
|---|---|
| `export_rift_state() -> Dictionary` | `{"seed":int, "spawned":int, "rifts":Array}`. ConfigFile 변형 저장이라 `Vector2`가 그대로 들어간다 |
| `import_rift_state(data: Dictionary) -> void` | 위 사전을 그대로 되돌린다 |

### 1.4 균열 사전(Dictionary) 스키마

```gdscript
{
  "id": "rift_0",        # String. 요청 순번 기반. enemy.camp_id에 그대로 넣어 쓰면 된다
  "index": 0,            # int. 0/1/2 — 렌더 색상 선택에도 쓰인다
  "position": Vector2,   # 균열 중심(월드 좌표)
  "radius": 150.0,       # 안전 바닥 반지름 = 아레나 반지름 (SAFE_ZONE_RIFT)
  "ring": 122.0,         # 렌더 링 반지름 (RIFT_RING_RADIUS)
  "distance": 1028.5,    # 개설 당시 플레이어와의 거리
  "attempts": 1,         # 몇 번째 후보에서 자리가 났는지(진단용)
  "cleared": false
}
```

---

## 2. 배치 규칙 요약

| # | 규칙 | 상수 |
|---|---|---|
| ① | **런당 3개**. 4번째 요청은 거절(`"budget_exhausted"`) | `RIFT_MAX_PER_RUN := 3` |
| ② | 플레이어로부터 **900~1,400px** 링 위 | `RIFT_MIN_DISTANCE` / `RIFT_MAX_DISTANCE` |
| ③ | **결정적** — 후보 각도·거리를 `_hash(런 시드, 요청 순번, RIFT_SALT)` 해시열에서 뽑는다. `RandomNumberGenerator` 스트림에 **의존하지 않는다** | `RIFT_SALT := 7717`, 후보 96개 |
| ④ | 발판(중심 ± `SAFE_ZONE_RIFT/40 + 2` 타일 사각형)이 **전부 마른 땅**인 자리만 통과 | `SAFE_ZONE_RIFT := 150.0` |
| ⑤ | 마왕성·시작 성·시련 캠프·다른 균열과 각자의 안전 반경 + 여유만큼 이격 | `RIFT_CLEARANCE := 110.0` |
| ⑥ | 랜드마크 피처(성)와도 이격. 상자·숲·유적은 바닥에 묻히지 않을 만큼만 이격 | — |
| ⑦ | 통과한 자리의 바닥은 성·캠프와 **같은 오버레이 규칙**으로 안전 타일(`T_CAMP`)을 깐다 → 균열 안은 항상 `is_walkable() == true` | `_resolved_tile_id()` |

### 왜 `add_dry_zone()`을 런타임에 부르지 않았나 (설계 판단 기록)

성·캠프는 `_init()`에서 `terrain_generator.add_dry_zone()`으로 호수를 미리 밀어낸다.
그런데 `add_dry_rect()`는 **청크 캐시와 호수 캐시를 통째로 비운다**. 균열은 낮 도중에
열리므로 그때 캐시를 날리면 ①수십 청크 재생성 히치 ②플레이어 눈앞에서 호수가 사라지는
지형 팝 ③`--world-test`의 `deterministic` 표본이 흔들릴 여지가 생긴다.

그래서 **후보 단계에서 "`add_dry_zone`이 덮었을 사각형이 이미 전부 마른 땅"인 자리만
통과시키는** 방식으로 바꿨다. 등록해도 타일이 한 칸도 안 바뀌는 자리만 고르는 것이므로
등록 자체를 생략할 수 있고, 결과는 dry zone을 등록한 것보다 **더 강한 보장**이다
(사각형 안에 호수 조각이 0개임을 실측으로 확인). 생성기 무수정 목표도 함께 지켜진다.
프로브 실측: 균열 3개 × 169타일 전부 `wet_tiles=0`, 아레나 72개 표본 전부 이동 가능.

---

## 3. 후속 웨이브가 연결할 훅 — game.gd / test_runner.gd

W8은 `game.gd`를 건드리지 않았다. 아래는 **호출 시그니처만** 적은 연결 지시서다.

### 3.1 W4(기한·마왕) — 런 시작과 2·4·6일차 개설

| 위치 | 할 일 |
|---|---|
| `_begin_run()` (현 L3145~) | `world.begin_run_rifts(<런 시드>)` 1줄. 런 시드는 `rng.seed` 또는 `GameTuning`의 런 시드 값을 그대로 넘긴다. 없으면 `Time.get_unix_time_from_system()` 기반 정수라도 **저장 스냅샷에 남길 수 있는 값**이어야 이어하기 후에도 같은 좌표가 나온다 |
| 낮 시작 전이(`_toggle_day_night()` → 낮 진입, 일수 2·4·6) | `var rift: Dictionary = world.spawn_rift_near(player.global_position)`<br>`if rift.is_empty(): (다음 프레임 재시도 — "no_site"는 예산을 안 먹는다)`<br>`else: _show_banner("균열이 열렸다", ...); ` 나침반 갱신 |

> `spawn_rift_near()`가 `{}`를 돌려준 이유는 `world.get_last_rift_result()`로 구분한다.
> `"no_site"`면 재시도해도 되고, `"budget_exhausted"`면 재시도하면 안 된다.

### 3.2 W9(성·NPC·각성) — 균열 진입·정예 스폰·보상

구 시련 캠프 3함수를 **그대로 복제해 이름만 바꾸면 된다**. 대응표:

| 구(시련 캠프) | 신(균열) | 바뀌는 부분 |
|---|---|---|
| `camp_states` 사전 | `world.get_rifts()` | 상태를 world_grid가 들고 있다. game.gd는 진행 카운터(`remaining`)만 따로 들면 된다 |
| `_check_trial_camps()` | `_check_rifts()` | `for direction in camp_states` → `var near := world.get_nearest_rift(player.global_position, 520.0)` 1줄로 대체 |
| `_activate_trial_camp(direction)` | `_activate_rift(rift_id)` | 정예 수 **9 → 3~5**(§5.5). `_spawn_enemy_instance(pos, behavior, "", false, rift_id, is_elite, "", true)` — 5번째 인자 `camp_id`에 `rift["id"]`를 그대로 넣는다. `enemy.mark_trial()`이 그대로 받는다 |
| `_trial_enemy_defeated(direction)` | `_rift_enemy_defeated(rift_id)` | 전멸 시 `world.set_rift_cleared(rift_id)` 호출. 보상은 **각인 3택1 + 골드 + 체력 전회복**(구 `player.add_trophy_orb()` 구슬 보상은 폐기 — 전직 게이트가 사라졌으므로) |
| `enemy_defeated()` L3148~3149 | 변경 없음 | `enemy.camp_id`가 `"rift_0"` 형태로 들어올 뿐이다. 분기만 `_rift_enemy_defeated()`로 |

정예 배율은 §5.5에 따라 `is_camp_elite` 경로의 **×5 → ×3** 하향이 필요하다 —
`enemy.gd` L462/475/529 소관이며 W8 범위 밖이다.

### 3.3 W5(HUD) — 나침반

```gdscript
var compass: Dictionary = world.get_rift_compass(player.global_position)
if not compass.is_empty():
    # compass["direction"] : Vector2 (단위벡터), compass["distance"] : float
```

### 3.4 W12(저장)

`_save_run_snapshot()`에 `"rift_state": world.export_rift_state()`,
`_restore_run_snapshot()`에 `world.import_rift_state(snapshot.get("rift_state", {}))`.
런 시드도 함께 저장해야 이어하기 후 4번째·5번째 요청까지 같은 좌표가 나온다.

### 3.5 W8 후속 — `--world-test`에 `rift_near` 항목 추가 (test_runner.gd 소관)

설계 §11 W8의 완료 기준은 `--world-test`에 `rift_near` 항목 신설을 요구한다.
`test_runner.gd`는 W0 소유라 W8이 건드리지 않았다. 추가할 코드:

```gdscript
game.world.begin_run_rifts(20260807)
var probe_origin := Vector2(180.0, -120.0)
var rift: Dictionary = game.world.spawn_rift_near(probe_origin)
var rift_distance: float = probe_origin.distance_to(rift["position"]) if not rift.is_empty() else 0.0
var rift_near := not rift.is_empty() and rift_distance >= 900.0 and rift_distance <= 1400.0 \
    and game.world.is_walkable(rift["position"])
# 뒷정리 — 이후 표본이 균열 바닥에 걸리지 않게
game.world.begin_run_rifts(0)
```
`WORLD_TEST_COMPLETE ... rift_near=%s` 형태로 출력에 넣고 `world_passed`에 AND한다.
그때까지의 대체 검증은 `scripts/test/rift_probe.gd`다(§5).

---

## 4. 시련 캠프 4곳 비활성화 방법

`world_grid.gd` 최상단:

```gdscript
const TRIAL_CAMPS_ENABLED := true   # ← 이 한 줄을 false로 바꾸면 끝난다
```

`false`로 뒤집으면 다음 4곳이 **동시에** 꺼진다.

| 위치 | 꺼지는 것 |
|---|---|
| `_init()` | 캠프 4곳의 호수 마른 구역 등록 (그 자리에 호수가 다시 생길 수 있다) |
| `_resolved_tile_id()` | 캠프 바닥 안전 타일 덮개 |
| `_draw()` | `_draw_trial_camp()` 렌더 |
| `get_trial_camps()` | 빈 사전을 돌려준다 |

**API는 전부 남아 있다.** `TRIAL_CAMPS` 상수, `get_trial_camps()`,
`set_cleared_trial_camps()`, `_draw_trial_camp()` 어느 것도 지우지 않았다.

`get_trial_camps()`가 빈 사전을 돌려주므로 호출부는 **한 줄도 고칠 필요가 없다**:

- `game.gd:2526` `for direction in world.get_trial_camps():` → 0회 반복 → `camp_states`가 빈 채로 남는다
- `game.gd:2667` `_check_trial_camps()` → 빈 사전 순회 → 아무 일도 안 한다
- `test_runner.gd:127` `for trial_position in game.world.get_trial_camps().values():` → 0회 반복 → `special_walkable`이 그대로 true

**뒤집는 시점**: §3.1~3.2의 균열 훅이 `game.gd`에 붙어 실제로 균열이 열리기 시작하는
웨이브(W4 또는 W9)의 **마지막 단계**. 그전에 뒤집으면 시련 콘텐츠가 통째로 사라지고
대체물이 없는 구간이 생긴다.

---

## 5. 검증 결과 (2026-08-07)

### 5.1 컴파일

```
godot --headless --path godot-game --editor --quit
→ exit=0, SCRIPT ERROR / Parse Error / ERROR: 0줄
```

### 5.2 `run_all.sh` — 컴파일 + 6종 전부 PASS

```
PASS  compile         exit=0
PASS  world-test      exit=0
PASS  v4-test         exit=0
PASS  v4-castle-test  exit=0
PASS  stress-test     exit=0
PASS  smoke-test      exit=0
PASS  combat-test     exit=0
==================== 종합 결과: PASS ====================
```

`--world-test` 불변식 전부 유지:
```
WORLD_TEST_COMPLETE starter=castle demon=demon_castle river_blocked=true bridge_open=true
special_walkable=true wfc_local=true seams=true streaming=true deterministic=true bounded=true
algorithm=streaming_simple_tiled_wfc cache=51 demon_distance=8628
```

### 5.3 균열 자체 검증 — `scripts/test/rift_probe.gd`

```
godot --headless --path godot-game -s res://scripts/test/rift_probe.gd
```

```
[1] determinism same_seed_identical=1 other_seed_differs=1
    req#0 seedA=(-691.49, 426.26) seedA_rerun=(-691.49, 426.26) seedB=(-600.03, -756.16)
    req#1 seedA=(493.42, 576.11)  seedA_rerun=(493.42, 576.11)  seedB=(1555.23, -285.56)
    req#2 seedA=(-1575.52, 2665.98) seedA_rerun=(-1575.52, 2665.98) seedB=(-1642.46, 670.02)
    req#0 distance=1028.5px bound=900~1400 attempts=1 inside=1
    req#1 distance=1201.1px bound=900~1400 attempts=1 inside=1
    req#2 distance=1195.7px bound=900~1400 attempts=2 inside=1
[2] distance pass=1
    req#0 wet_tiles=0/169 blocked_samples=0/72 floor_is_safe_tile=1 demon_gap=9437(min 470) castle_gap=1159(min 450) camp_gap=3757(min 435) ok=1
    req#1 wet_tiles=0/169 blocked_samples=0/72 floor_is_safe_tile=1 demon_gap=8622(min 470) castle_gap=861(min 450)  camp_gap=3837(min 435) ok=1
    req#2 wet_tiles=0/169 blocked_samples=0/72 floor_is_safe_tile=1 demon_gap=11560(min 470) castle_gap=3440(min 450) camp_gap=2023(min 435) ok=1
[3] no_overlap pass=1
[4] budget granted=3/3 fourth_rejected=1 reason=budget_exhausted remaining=0 pass=1
RIFT_PROBE_COMPLETE failures=0 verdict=PASS
```

> 프로브는 `run_all.sh`의 `ALL_TESTS`에 넣지 않았다(`run_all.sh`는 W0/W12 소유).
> 출력에 `=false` 문자열이 없도록 판정을 `pass=1`/`pass=0`으로 찍는다 —
> 나중에 `ALL_TESTS`에 추가해도 규약을 깨지 않는다. 추가할 때 쓸 마커는
> `RIFT_PROBE_COMPLETE`이고, 실패 시 종료 코드 1을 낸다.

---

## 6. 하지 않은 것 (범위 밖 — 오케스트레이터 판단 필요)

설계 §11 W8 표에는 있으나 이번 웨이브 지시 범위(균열 API + 캠프 플래그)에 없어
**의도적으로 손대지 않은** 항목이다.

| 항목 | 현재 값 | 설계 목표 | 왜 안 했나 |
|---|---|---|---|
| 마왕성 거리 | `DEMON_CASTLE_POSITION := Vector2(6840, -5260)` (8,628px) | 5,600px | 지시 범위 밖. `--world-test`가 `demon_distance`를 출력하고 W10·W4가 이 좌표를 참조하므로 단독 변경 시 충돌 위험. 바꿀 때는 `_init()`의 dry zone과 `find_walkable_near()`의 240px 회피 반경이 함께 따라간다(코드는 좌표만 바꾸면 자동으로 맞는다) |
| 성 밀도 | `_feature_for_chunk()` `roll < 9` (9%) | 7일 안에 3~4회 방문 가능 | 지시 범위 밖. 바꿀 지점은 `_feature_for_chunk()`의 확률 구간 한 줄뿐이다 |
| `_draw_trial_camp` → `_draw_rift` 개명 | 두 함수 **공존** | 개명·재활용 | 캠프 렌더러를 지우면 `TRIAL_CAMPS_ENABLED := true`인 현재 상태가 깨진다. 플래그를 `false`로 뒤집는 웨이브에서 `_draw_trial_camp()`를 삭제하면 된다 |
| 정예 배율 ×5 → ×3 | 미변경 | ×3 | `enemy.gd` 소관 (W8 담당 파일 아님) |

## 7. 주의

- **`wfc_chunk_generator.gd` 무수정** — WFC 알고리즘·호수 레이어·청크 스트리밍·시드 체계
  (`WORLD_SEED := 20260804`) 전부 그대로다. 지형 아틀라스 좌표 체계도 손대지 않았다(테마 교체는 W11).
- 원본은 `docs/v1-archive/world_grid.gd.txt`에 보존했다(부록 C-2 규약).
- git commit 하지 않았다(부록 C-2).
- `_resolved_tile_id()`는 타일마다 균열 3개까지 거리 검사를 추가로 한다. 캠프 4곳 검사가
  이미 있던 자리라 비용 증가는 없는 것과 같다(`--stress-test` fps=144 유지 확인).
