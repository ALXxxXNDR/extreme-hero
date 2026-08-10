# handoff-v9 — 저장 schema 3 확정 · 이어하기 E2E

> 웨이브 **V9** (설계 `docs/GAME_DESIGN_V3.md` §9 · 부록 B의 V9). 2026-08-09.
> **읽는 사람: V10(통합·밸런스·문서) — 이 문서의 §9가 남은 정리 목록 전량이다.**
> 한 줄 요약: **`RUN_SCHEMA_VERSION`을 3으로 올려 v2 세이브를 폐기하고, 이어하기가
> 스테이지·체류·잠식·트로피·균열·시각 상태까지 통째로 되살아나게 했다.**
> 그 과정에서 **이어하기가 월드를 틀린 시드로 세우던 회귀 1건**을 찾아 고쳤고,
> **전투 중 저장 정책**을 "전투가 열려 있는 동안은 저장을 쉰다"로 확정했다.

| | |
|---|---|
| 소유·수정 | `scripts/game.gd`(저장 구역 · 로비 버튼 · `_rebuild_stage_world` 시그니처) · `scripts/test/test_runner.gd`(`--save-test` 전면 재작성 · 지문 · `--capture-lobby`) · `scripts/test/run_all.sh`(주석) · `art/screenshots/qa/lobby-minimal-v2.png`(내용 갱신) · 이 문서 |
| 무접촉 | `core/*.gd` 6종 전부 · `world_grid.gd` · `player.gd` · `factory_deck.gd` · `deal_cycle_controller.gd` · `enemy.gd` · 라이브러리 6종 · `castle_interior.gd` · `art/`(생성 스크립트) · `AGENTS.md` · `docs/GAME_DESIGN_V3.md` · `docs/v1-archive/` |
| 검증 | `--editor --quit` 오류 **0** · `run_all.sh` **14종 전부 PASS**(78초) · `--capture-lobby` 육안 확인 · 비headless 12초 라이브 실행 오류 **0줄** |

---

## 0. 이 웨이브가 실제로 한 것

| # | 항목 | 결과 |
|---|---|---|
| ① | `RUN_SCHEMA_VERSION` 2 → **3** | v1·v2 스냅샷 **둘 다** 폐기. 크래시 없이 "새 런"으로 떨어진다 |
| ② | 키 확정 | **49키**. 폐기 6 · 개명 1 · 신규 3 (§1 표) |
| ③ | **복원 순서 회귀 수정** | 시드를 월드 재생성 **뒤에** 복원해 이어하기가 다른 지형을 만들던 버그(§2) |
| ④ | 전투 중 저장 정책 | 마왕전 · 보스방 · 강림 보스 · 트로피 모달 4구간에서 **저장을 쉰다**(§3) |
| ⑤ | 개명 폴백 | `SNAPSHOT_LEGACY_KEYS` 표 하나로 모았다. 흩어진 `get(new, get(old))` 제거(§4) |
| ⑥ | 랜드마크 복원 | 저장된 성·캠프·보스문 좌표를 되박는다(결정성 보험 · §2.3) |
| ⑦ | 시각 상태 스냅 | 로드 직후 조명·안개·그레이드를 **보간 없이** 그 스테이지 값으로(§5) |
| ⑧ | 로비 이어하기 표기 | "이어하기 · 3스테이지 잿빛 벌판 · 11일차 · 08:32"(§6) |
| ⑨ | `--save-test` 재작성 | 지문 49 → **68축** · 묶음 6종 신설 · 스테이지 3/체류 5 시나리오(§7) |

---

## 1. schema 3 최종 키 — 49개

### 1.1 전체 목록 (`_save_run_snapshot()` 작성 순서 그대로)

| # | 키 | 내용 | V9 |
|---|---|---|---|
| 1 | `schema_version` | 항상 3 | |
| 2 | `character_id` | 선택 캐릭터 | |
| 3 | `playtime` | `elapsed_time` | |
| 4~8 | `level` `experience` `xp_target` `kills` `gold` | 진행·자원 | |
| 9 | `deadline_clock` | `StageClock.to_snapshot()` 9키(day/night/elapsed/descended/stage/dwell/stages_cleared/descent_used/run_elapsed) | |
| 10 | `demon_lord` | `DemonLord.to_snapshot()` 7키 | |
| 11 | `omen_night_count` | 전조 밤 수 | |
| 12~15 | `player_position` `player_health` `player_skills` `player_trophies` | 플레이어 | |
| 16 | `trophy_stages` | **트로피 효과의 유일한 진실 원천** — 번호만 저장하고 `TrophyLibrary.merge_effects()`가 다시 세운다 | |
| 17 | `growth_cap_conversions` | 성장 천장 자동 전환 횟수 | |
| 18 | `run_synergy_triggers` | 시너지 발동 횟수 | |
| 19~20 | `player_shields` `player_rollbacks` | 충전 | |
| 21~23 | `factory_slots` `factory_inventory` `factory_equipment` | 5칸+각인 · 보관함 · 장비 4부위 | |
| 24 | `run_cycle_seed` | 바늘·월드·균열이 전부 여기서 파생 | |
| 25~27 | `selected_skills` `rejected_skills` `boss_items` | 카드 이력 | |
| 28 | **`trophy_effects`** | 트로피 2택1에서 **버린** 카드(= 마왕 몫). 구 `boss_advancement` | **개명** |
| 29~30 | `opened_features` `camp_states` | 랜드마크 개방 · 캠프 | |
| 31~32 | `rift_state` `rift_states` | 균열 좌표·시드·예산(월드) + 진행도(게임). **스테이지 스코프**다 | |
| 33~35 | `pact_uses` `rune_shop_purchases` `spy_revealed` | 성 NPC | |
| 36~37 | `blight_active` `blight_marked` | 잠식 | |
| 38 | `stage_boss_cleared` | 이 스테이지 관문 격파 여부 | |
| 39~42 | `stage_index` `stage_dwell` `stage_seed` `stages_cleared` | 스테이지 축 | |
| 43~44 | `stage_descent_pending` `camp_rest_used` | 스테이지 스코프 | |
| 45~46 | `run_peak_heat` `boss_reload_windows` | 런 기록 | |
| 47 | **`total_days`** | `deadline_clock.day`의 최상위 복사본. **로비가 클럭을 만들지 않고 사전만 읽기 때문**이다 | **신규** |
| 48 | **`stage_landmarks`** | 성·캠프·보스문 좌표 3종(결정성 보험 · §2.3) | **신규** |
| 49 | **`stage_bosses_defeated`** | 격파 수(결과 화면 지표). 저장하지 않으면 이어하기로 조용히 0이 됐다 | **신규** |

### 1.2 폐기 6키

| 폐기한 키 | 왜 | 대체 |
|---|---|---|
| `player_advancement_branch` | 계보 폐기(V8). 값은 트로피에서 파생된다 | `trophy_stages` → `player.restore_trophies()`가 두 필드를 다시 세운다 |
| `player_advancement_tier` | 〃 | 〃 |
| `boss_advancement` | 이름이 거짓말이 됐다(계보 카드 → 트로피 미선택 카드) | **`trophy_effects`로 개명** |
| `cycle_number` | v1 시절 클럭 낱개 폴백. v3에서 7일 상한이 사라져 **의미까지 변했다** | `deadline_clock.day` |
| `is_night` | 〃 | `deadline_clock.night` |
| `phase_elapsed` | 〃 | `deadline_clock.elapsed` |

⚠️ **필드는 남는다.** `player.advancement_branch_id` / `advancement_tier`는
`combat_resolver.gd:823`이 읽고, `boss_advancement_skills`는 `demon_lord.gd:84 :349-351`이
읽는다. V9가 지운 것은 **저장 키뿐**이다(handoff-v8 §6의 제약 그대로).

`--save-test`의 `dropped_keys` 단언이 이 6키 + `eclipse_active` / `eclipse_marked`가
스냅샷에 **되살아나지 않는지**를 매번 확인한다(복사·붙여넣기 회귀 방지).

### 1.3 일부러 저장하지 않는 것

| 대상 | 이유 |
|---|---|
| `player_status` · `player_status_dot_total` | 설계 §9 — 전투 중 수 초짜리 휘발 상태. **복원 후 전부 0**(`--save-test` `visual` 묶음이 단언) |
| `stage_boss` · `stage_boss_cycle` · `stage_boss_factory` · `stage_boss_pools` · `boss` · `boss_cycle` | 전투 중에는 저장 자체를 안 한다(§3) |
| `stage_boss_telegraphs` · `stage_boss_phase_shifts` | **보스 1회전 스코프**다(`_spawn_stage_boss()`가 리셋). 저장 시점엔 항상 0 |
| `shop_offers` · `shop_refresh_count` | 상점 1회 방문 스코프(`_open_shop()`이 리셋). 성 안에서는 저장이 안 돈다 |
| `boss_peak_heat` · `active_omen` · `inside_camp` · `stage_scaled_enemies` | 전투/필드 파생값. 복원 후 스스로 다시 채워진다 |

### 1.4 설계 §9와 다르게 한 것 — 1건

설계 §9의 신규 키 목록에 **`stage_boss_defeated`(스테이지별 격파 기록 배열)** 가 있는데
**넣지 않았다.** V8이 트로피를 도입하면서 격파 4경로(`defeat` · `enhanced` ·
`demon_direct` · `valve`)가 **전부** 트로피를 지나가게 됐고, 그래서
`trophy_stages`가 이미 "보스를 깬 스테이지 번호 배열"이다. 같은 사실을 두 배열에
적으면 어긋날 자리만 생긴다. 대신 격파 **수**만 `stage_bosses_defeated`로 저장했다.

---

## 2. 복원 순서 — V9가 잡은 회귀

### 2.1 무엇이 깨져 있었나

```
구 순서 : clock 복원 → (스테이지가 다르면) 월드 재생성 → … → run_cycle_seed 복원
```

`stage_world_seed(n) = absi(run_cycle_seed ^ (n * 2654435761)) | 1`이다. 즉 월드를
세우는 시점에 **`run_cycle_seed`가 이미 저장값이어야 한다.** 그런데 복원이 그보다
30줄 뒤에 있었다.

* 실기 이어하기는 앱을 껐다 켠 뒤다 → `run_cycle_seed == 0` → `_begin_run()`이
  `rng.randi()`로 **새 시드**를 뽑는다 → 그 시드로 월드가 선다.
* 저장이 **스테이지 1**이면 `world.get_stage() == clock.stage`라 재생성 조건에
  걸리지도 않는다 → 틀린 시드로 만든 월드를 그대로 썼다.
* 결과: 이어하기를 하면 **지형·성·캠프·보스문·균열 후보 자리가 통째로 달라졌다.**
  `opened_features`("이 상자는 열었다")가 존재하지 않는 상자를 가리키고,
  나침반이 다른 곳을 가리킨다.

**V8까지의 `--save-test`는 이걸 못 봤다.** 살아 있는 게임 인스턴스에서
`_begin_run(snapshot)`을 부르면 `run_cycle_seed`가 리셋되지 않아 **우연히 같은 시드**가
재사용됐기 때문이다. V9가 테스트에 `game.run_cycle_seed = 0` 한 줄(콜드 스타트 흉내)을
넣자 즉시 `world_seed` 불일치로 잡혔다.

### 2.2 새 순서 (`_restore_run_snapshot()`)

```
① run_cycle_seed + player_cycle.cycle_seed_base
② clock.from_snapshot()
③ _rebuild_stage_world(clock.stage, snapshot.stage_seed)   ← 조건 없이 항상
④ _restore_stage_landmarks()
⑤ 스테이지 스코프 · 마왕 · 균열 · 성 NPC · 잠식
⑥ 덱(5칸 · 각인 · 보관함 · 장비)
⑦ 플레이어(트로피 먼저 → _rebuild_stats → 체력/보호막/좌표) + 상태이상 0
⑧ 월드 표시(opened_features · 캠프 · 보스문) + _snap_world_lighting()
```

`_rebuild_stage_world(stage_number, seed_override := 0)`에 **두 번째 인자가 생겼다.**
0이면 종전대로 `stage_world_seed()`를 쓰고, 0이 아니면 그 시드를 그대로 쓴다.
이어하기만 이 인자를 쓴다 — `stage_world_seed()` 식이 나중에 바뀌어도 **이미 저장된
런의 지형이 흔들리지 않는다.**

### 2.3 랜드마크 write-back

`_restore_stage_landmarks()`는 저장된 성·캠프·보스문 좌표를 `world.stage_landmarks`에
되박고 `world._landmark_chunks`를 다시 세운다. 시드를 먼저 복원했으므로 보통은
**같은 값을 같은 값으로 덮는다**(멱등). 존재 이유는 생성식이 바뀐 뒤에 열린 세이브다.

⚠️ `_landmark_chunks`는 `world_grid.gd`의 사적 캐시다. V9는 그 파일을 열 수 없어
game.gd에서 직접 세웠다(랜드마크 좌표에서 기계적으로 파생되는 값이라 위험이 없다).
`world_grid.gd`에 공개 setter가 생기면 갈아탈 것 — §9 #5.

---

## 3. 전투 중 저장 정책 — **"전투가 열려 있는 동안은 쉰다"**

### 3.1 판정

`_run_save_blocked_reason()`이 막는 4구간. `state` 하나로는 부족하다 —
**강림 보스는 `state`가 `"playing"` 그대로**이기 때문이다(§6.6).

| 사유 문자열 | 구간 | 판정식 |
|---|---|---|
| `boss_battle` | 마왕전 · 보스방 아레나 | `state == "boss"` |
| `stage_boss_descended` | 강림 밸브로 필드에 내려온 스테이지 보스 | `stage_boss_active()` |
| `trophy_modal` | 격파 → 2택1 → 배치까지의 모달 사슬 | `pending_stage_trophy` / `pending_trophy` / `pending_trophy_followup` / `trophy_place_pending` 중 하나라도 살아 있음 |
| (그 외) | 성 내부 · 편집 · 상점 · 드래프트 · 결과 | `state != "playing"` — 종전 규칙 |

`_save_run_snapshot()`은 이 넷 중 하나라도 걸리면 **파일을 건드리지 않고 돌아간다.**
공개 창구는 `run_save_allowed()`다(테스트·문서가 같은 판정을 본다).

### 3.2 5초 주기 자동 저장이 전투 중 어떻게 도는가 (확인 완료)

`_process()`의 자동 저장 틱은 `state not in ["playing", "boss"]` 가드 **뒤**에 있다.

* 필드(`playing`) — 5초마다 실제로 파일을 쓴다.
* 보스전(`boss`) — 타이머는 계속 돌고 `_save_run_snapshot()`이 불리지만
  **`run_save_allowed()`가 false라 즉시 반환한다. 디스크 I/O가 0이다.**
* 성 내부(`castle_interior`) — `_process` 맨 위에서 `return`한다. 종전과 같다.
* 전투가 끝나면 다음 틱(≤5초)에 자동으로 다시 쓴다. **영구히 막히지 않는다.**

### 3.3 왜 이 정책인가 — 버린 대안 둘

| 대안 | 왜 버렸나 |
|---|---|
| 전투 상태를 저장한다 | 보스 노드·보스 덱·보스 사이클·장판/소환 풀·플레이어 상태이상·telegraph 진행도를 전부 직렬화해야 한다. "선딜 0.4초 남은 telegraph"를 되살릴 방법이 없어 **반드시 어딘가 어긋난다** |
| 저장하되 보스방 앞으로 정규화해 적는다 | 그 "전투 전 값"을 따로 들고 있어야 한다 = 결국 전투 전 스냅샷을 보관하는 것과 같고 코드만 는다 |

**채택안의 손실은 정확히 0이다.** 보스전은 45~90초 창이고 도중에 얻는 영구 자원이
없다(트로피는 격파 **뒤에** 나온다). 반대로 지원했다면 "격파 직후 트로피를 받기 전"에
이어하기를 하는 순간 트로피가 증발하거나 두 번 나오는 구멍이 생긴다.

플레이어가 잃는 최대치 = 보스방에 들어간 뒤의 진행. 스냅샷은 문 앞 필드 상태이고
`stage_boss_cleared == false`라 **문이 다시 열려 있다**(handoff-v7 §11-5가 제안한 그 값).

### 3.4 남는 구멍 1개 (판정 필요 — §9 #7)

**성 내부(`castle_interior`)에서는 저장이 돌지 않는다.** 카드를 사고 각인을 붙인 뒤
성 안에서 앱이 죽으면 그 거래가 통째로 사라진다. v2부터 있던 동작이고 V9가 바꾸지
않았다. 고치려면 "성을 나갈 때 1회 저장"(`_leave_castle()`에 한 줄)이 가장 싸다.

---

## 4. 개명 폴백 — `SNAPSHOT_LEGACY_KEYS`

### 4.1 형태

```gdscript
const SNAPSHOT_LEGACY_KEYS: Dictionary = {
	"blight_active":  ["eclipse_active"],    # V7: 월식 → 잠식
	"blight_marked":  ["eclipse_marked"],    # V7: 〃
	"trophy_effects": ["boss_advancement"]   # V9: 계보 카드 → 트로피 미선택 카드
}
```

표에는 **실제로 일어난 개명만** 적는다. 가공의 구 키를 넣으면 다음 사람이 없는
역사를 찾게 된다.

`_snapshot_value(snapshot, key, fallback)`이 새 키 → 구 키 → 기본값 순으로 본다.
**`_restore_run_snapshot()`은 `snapshot.get()`을 한 번도 직접 부르지 않는다** —
전부 이 함수를 지난다. 그래서 다음 개명은 표에 한 줄만 더하면 끝난다.

### 4.2 지금 이 표는 한 건도 발화하지 않는다 (의도)

schema 3 게이트(`< RUN_SCHEMA_VERSION` → 폐기)가 구 세이브를 **먼저** 버리기
때문이다. 그래도 남긴 이유는 둘이다.

1. 개명은 v3에서 실제로 일어났고(`eclipse_*` → `blight_*` V7 · `boss_advancement` →
   `trophy_effects` V9), 폴백을 지웠다는 사실을 **코드가 아니라 표로** 남겨야
   다음 개명 때 "어디에 넣어야 하는지"를 다시 찾지 않는다.
2. 지우려면 **이 표만 비우면 된다.** 호출부는 한 줄도 안 바뀐다(§9 #4).

`--save-test`의 `fallback` 묶음이 표가 **죽지 않았는지**를 단위 수준으로 확인한다
(구 키만 있을 때 읽히는가 · 새 키가 있으면 새 키가 이기는가 · 둘 다 없으면 기본값인가).

### 4.3 값 수준의 개명은 폴백이 필요 없다 (조사 결과)

V2 웨이브의 개명 36+14+12건은 전부 **`name`만 바꾸고 `id`는 고정**이었다
(설계 §5.4의 "`name` 키만 바꾸고 `id`는 금지"). 스냅샷에 박히는 것은 id이므로
카드·아이템·각인·트로피 어느 것도 폴백이 필요 없다. 설계 §10 리스크 #9
("카드 이름 교체가 상점 오퍼 이름 스냅샷에 남는다")는 **`shop_offers`를 저장하지
않는 것 + schema 3 폐기**로 이중으로 해소됐다.

---

## 5. 시각 상태 — 로드 직후 스냅

`_snap_world_lighting()`이 복원 마지막에 조명·안개·그레이드를 **보간 없이** 맞춘다.

문제였던 것: `_update_world_lighting()`은 프레임마다 `lerp(delta * 2.0)`로 다가가는
함수라, 이어하기 직후에는 흰색(`_begin_run()`의 초기값)에서 목표색까지 약 1초가
걸렸다. 5스테이지 밤(`#2f2f52`)으로 이어하면 **화면이 한 번 하얗게 번쩍인 뒤**
어두워졌다. 로드는 "전환"이 아니라 "그 순간으로 돌아가기"이므로 즉시 값이 맞다.

맞추는 것 4종: `canvas_modulate.color`(스테이지별 낮/밤 색) · `world.night_amount` ·
안개/초록/비네트 가시성(`_apply_stage_grade()`) · 안개 틴트.
아틀라스·채도는 `world.begin_stage()`가 이미 스테이지에서 정한다.

`--save-test`의 `visual` 묶음이 **스테이지 상수와 직접 대조**한다(지문 대조가 아니다 —
기대값이 `GameTuning`에 있으므로 "복원 후 값이 저장 전과 같다"보다 강한 단언이다).

---

## 6. 로비 이어하기 표기

```
이어하기 · 3스테이지 잿빛 벌판 · 11일차 · 08:32
```

* 데이터 경로: `_load_progress()`가 스냅샷 사전에서 `playtime` / `stage_index` /
  `total_days`를 그대로 읽어 `saved_run_playtime` / `saved_run_stage` /
  `saved_run_total_days`에 담는다. **로비는 클럭도 월드도 만들지 않으므로**
  최상위 키가 필요했다(그래서 `total_days`를 신설했다 — §1.1 #47).
* 문구는 `_saved_run_label()` 하나가 만든다(버튼 생성부에서 분리 — 테스트가 부른다).
* `_load_progress()`가 **스키마도 거른다.** 폐기 대상(schema < 3) 스냅샷이 남아 있으면
  `saved_run_available`을 false로 내린다. 이 줄이 없으면 버튼만 활성인데 누르면
  `_continue_saved_run()`이 빈 사전을 받아 로비로 되튀는 상태가 된다.
* 육안 확인: `art/screenshots/qa/lobby-minimal-v2.png`(§8).

---

## 7. `--save-test` 재작성

### 7.1 시나리오

`advance_stage()`를 **실제 전이 경로로 두 번** 태워 스테이지 3에 올린 뒤
(월드 재생성·랜드마크 재배치·균열 예산 초기화가 실기와 같은 순서로 일어난다)
체류 5 · 11일차 밤 19.5초 · 잠식 활성 · 트로피 2개 · 균열 2개(1 클리어) ·
캠프 휴식 소진 · 각인 3개 · 장비 2부위 · 계약 3종 사용으로 흔든다.

⚠️ **흔들기는 반드시 전이 뒤에** 한다. 전이가 스테이지 스코프 상태(잠식·균열·
`opened_features`·`camp_rest_used`)를 지우기 때문이다.

⚠️ `stage_descent_pending`은 **일부러 false**로 둔다. true면 밸브가 당겨졌다는 뜻이고
그 상태에서는 저장 자체가 막힌다(§3) — 지문 왕복을 볼 수 없게 된다.

### 7.2 출력

```
SAVE_TEST_COMPLETE snapshot=true fields=true rift=true combat_save=true visual=true
  fallback=true transition=true lobby=true stage_setup=true legacy_reject=true cleared=true
  schema=3 keys=49 axes=68 mismatch=0 missing=none
  저장 차단 사유 3구간: boss_battle,trophy_modal,stage_boss_descended
  이어하기 표기: 이어하기 · 3스테이지 잿빛 벌판 · 11일차 · 08:32
```

| 묶음 | 무엇을 단언하나 |
|---|---|
| `stage_setup` | 전이 2회로 스테이지 3 · `stages_cleared` 2 · 월드도 3 |
| `snapshot` | 필수 49키 전원 존재 · **폐기 8키 부활 0** · 최상위 키와 클럭 사전의 정합(`stage_index`==3 · `total_days`==`deadline_clock.day` · 랜드마크 3종) |
| `fields` | 지문 **68축** 정확 일치(드리프트 4축은 "되감기지 않았는가"만) |
| `rift` | 균열 좌표·클리어·예산이 그대로. 나침반이 다른 곳을 가리키지 않는다 |
| `combat_save` **신설** | 필드에서는 저장이 열려 있고, **마왕전 · 트로피 모달 · 강림 보스** 3구간에서 `playtime`을 9999로 흔들고 저장해도 파일이 512.5 그대로다. 전투를 걷으면 다시 열린다 |
| `visual` **신설** | 복원 직후 아틀라스 `waste` · 채도 1.00 · 밤 · `night_amount` 1.0 · `canvas_modulate` == `STAGE_NIGHT_MODULATE[2]` · 안개 보임/초록 안 보임/비네트 안 보임 · **상태이상 전부 0** |
| `fallback` **신설** | `SNAPSHOT_LEGACY_KEYS` 3종이 실제로 발화 · 새 키 우선 · 둘 다 없으면 기본값 |
| `transition` **신설** | 3→4 전이 **직후** 저장·복원 → 스테이지 4 · dwell 2(5×0.5) · `stages_cleared` 3 · 아틀라스 `waste` · 저장된 `stage_seed` == 살아 있는 시드 · 랜드마크 3종 좌표 일치 · 잠식 꺼짐(4스테이지 임계 3 > dwell 2) |
| `lobby` **신설** | `saved_run_stage`==3 · `saved_run_total_days`==11 · 문구에 "3스테이지" "잿빛 벌판" "11일차" "08:32" |
| `legacy_reject` | **v1(버전 키 없음)과 schema 2를 둘 다** 버린다 + 로비도 같은 판정을 한다 |
| `cleared` | `_clear_run_save()`가 스테이지·일수 캐시까지 0으로 내린다 |

### 7.3 콜드 스타트 흉내 — 이 검사의 핵심 한 줄

```gdscript
game.run_cycle_seed = 0        # ← 이 줄이 없으면 §2의 회귀를 못 잡는다
game._begin_run(snapshot)
```

실기 이어하기는 앱 재시작이라 시드가 0이다. 0으로 되돌리지 않으면 살아 있는
인스턴스의 시드가 재사용돼 **복원 순서가 틀려도 월드가 우연히 같게 나온다.**
검증: §2의 구 순서를 일부러 되살려 돌리자 `world_seed(7409100697→8335420547)`
불일치와 `transition=false`로 즉시 FAIL이 났다(복구 후 다시 PASS).

### 7.4 지문 가산 19축

`stage` `dwell` `stages_cleared` `total_days` `clock_descended` `descent_used`
`run_elapsed`(드리프트) `stage_descent_pending` `camp_rest_used` `stage_boss_cleared`
`stage_bosses_defeated` `world_stage` `world_seed` `world_atlas` `world_gate_cleared`
`landmarks`(3종 좌표) `grade_saturation` `grade_green` `status_total`

**드리프트 키는 4개다**: `phase` `playtime` `blight_marked` `run_elapsed`.
나머지 64축은 정확 일치를 요구한다.

---

## 8. 캡처

`--capture-lobby`가 이제 **저장이 있는 상태**를 찍는다. 그전까지 이 컷은 항상
"이어하기 · 저장된 모험 없음"(비활성 회색 버튼)이라, 이어하기 표기가 회귀해도
캡처로는 알 수 없었다. 캡처 루틴이 실제 런을 스테이지 3까지 올려 저장한 뒤
`_show_menu()`로 나온다.

| 파일 | 확인한 것 |
|---|---|
| `lobby-minimal-v2.png` **갱신** | 이어하기 버튼이 **활성(청록 테두리)** 이고 "이어하기 · 3스테이지 잿빛 벌판 · 11일차 · 08:32"가 한 줄에 들어간다(잘림 없음) |

⚠️ 이 캡처는 `user://the_unchosen_progress.cfg`에 **schema 3 세이브를 남긴 채 끝난다.**
다른 검사는 그 파일을 읽지 않으므로 무해하고, `--save-test`가 끝에서 지운다.
`run_all.sh` 전체를 캡처 뒤에 돌려 오염이 없음을 확인했다(14종 PASS).

---

## 9. V10이 바로 알아야 할 것 — 남은 정리 목록 전량

V7 §11·§12, V8 §9·§10, V9가 남긴 것을 **한 표로 합쳤다.** 이게 v3의 마지막 정리 목록이다.

### 9.1 V9가 새로 남긴 것

| # | 내용 | 크기 | 어디 |
|---|---|---|---|
| 1 | **보스 전투 길이 미측정**은 여전하다. V9는 전투에 손대지 않았다 | 대 | §9.2 #10 |
| 2 | `stage_bosses_defeated`와 `clock.stages_cleared`는 **항상 같은 값**이다. 하나로 합칠 수 있다(합치면 저장 키도 1개 준다) | 소 | `game.gd` `stage_clock.gd` |
| 3 | 설계 §9의 `stage_boss_defeated`(배열)를 **넣지 않았다**(§1.4). 설계 문서 쪽을 고치는 게 맞다 | 소 | `GAME_DESIGN_V3.md` §9 |
| 4 | `SNAPSHOT_LEGACY_KEYS`는 **지금 한 건도 발화하지 않는다**(§4.2). 지우려면 표만 비우면 된다. 남길지 지울지 V10 판정 | 소 | `game.gd` |
| 5 | `_restore_stage_landmarks()`가 `world._landmark_chunks`(사적 캐시)를 직접 쓴다. `world_grid.gd`에 `set_stage_landmarks()`를 만들어 옮기는 게 옳다 | 소 | `world_grid.gd` |
| 6 | `--capture-lobby`가 진행 파일에 세이브를 남긴다(§8). 캡처 끝에 `_clear_run_save()`를 넣을지 판정 | 소 | `test_runner.gd` |
| 7 | **성 내부에서는 저장이 돌지 않는다**(§3.4). "성을 나갈 때 1회 저장" 한 줄로 닫을 수 있다 | 중 | `game.gd` |
| 8 | 결과 화면이 `stage_bosses_defeated` · `stage_boss_telegraphs` · `stage_boss_phase_shifts`를 **아직 읽지 않는다**(handoff-v7 §11-2가 지표로 쓰라고 남긴 셋 중 둘) | 소 | `game.gd` `_show_result` |

### 9.2 V7·V8이 남긴 것 (그대로 유효)

| # | 내용 | 크기 | 출처 |
|---|---|---|---|
| 9 | **`class_library.gd`를 삭제하라** — 참조 1건(§2.2)만 고치면 된다 | 소 | v8 §9-4 |
| 10 | **보스 전투 길이(목표 45~90초) 미검증.** `BossLibrary.DESIGN_HP`(2600/3200/3800)는 뼈대 값이고 원소 시너지가 새로 물렸다. `balance_probe` 확장 필요 | 대 | v7 §12-1 |
| 11 | **트로피 5종 누적 스탯이 마왕전 60~120초 창과 함께 검증된 적이 없다** | 중 | v8 §9-6 |
| 12 | `STAGE_BOSS_*` 상수 6개(`DAMAGE_PER_POINT` 2.0 · `_DAY_STEP` 0.18 · `_SPEED_BASE` 68 · `_CONTACT_BASE` 11 · `_PHASE_DAMAGE_MUL` 1.12 · `_PHASE_TELEGRAPH_MUL` 0.86)를 `tuning.gd`로 옮겨라 | 중 | v7 §11-7 |
| 13 | `STAGE_PRICE_STEP`(0.35)도 `tuning.gd`로 + 실측 확정 | 중 | v8 §9-5 |
| 14 | `GameTuning.BOSS_HP_DAY_STEP` / `TOTAL_DAYS` — 마지막 참조가 사라졌다. **이제 지울 수 있다** | 소 | v7 §11-8 |
| 15 | `GameTuning.ECLIPSE_*` 상수 6개 → `BLIGHT_*` 개명 가능(식별자 개명은 V7이 끝냈다) | 소 | v7 §11-9 |
| 16 | `boss_advancement_skills` 필드명 개명은 `demon_lord.gd`를 함께 열어야 한다. `advancement_branch_id` / `advancement_tier`도 이름이 의미와 어긋난 채 남아 있다 | 소 | v8 §9-7 §10-7 |
| 17 | 성장 천장 전환이 **실전에서 언제 처음 터지는지** 모른다(R3 5장 = id당 4장 × 5 = 20장) | 중 | v8 §10-3 |
| 18 | 플레이어 도트가 무적 시간을 **원복**해 방패(shield_charges)가 도트에 소모된다. 의도인지 판정 | 소 | v7 §12-2 |
| 19 | `boss_library.PATTERNS`의 `anim` 키(B-1 `jump` · C-2 `attack`)를 소비하지 않는다 | 소 | v7 §12-3 |
| 20 | 선형 패턴(A-3 뇌격 · C-2 활공)의 관통·다단이 선분 위 여러 지점을 때리지 않는다 | 소 | v7 §12-4 |
| 21 | 강림 중 나침반·고스트 레일이 숨는다. 필드 사건이라 나침반은 살아 있는 편이 나을 수 있다 | 소 | v7 §12-5 |
| 22 | 보스는 `apply_cycle_slow`가 no-op이다(`enemy.gd`의 v2 가드). 한(chill)은 걸리는데 v2 slow는 안 걸린다 | 소 | v7 §12-6 |
| 23 | 예비 카드 2장까지 전부 겹치면 2택1이 1택이 될 수 있다(사실상 도달 불가능한 이론적 구멍) | 소 | v8 §10-6 |
| 24 | **`AGENTS.md` §1 체크포인트 갱신** + v3 전면 개정 | 중 | v7 §12-9 · v8 §10-9 |

### 9.3 건드리지 말 것

* `_trigger_boss_cycle_pulse()`의 `match`에 `_:` 기본 분기를 **추가하지 말 것**(v7 §2.3).
* `--capture-castle`은 `automated_test = false`로 도는 유일한 캡처다(트로피 모달이
  자동 확정되면 안 된다 · v8 §9-8).
* 결과 화면 금지 어휘에 **짧은 토큰을 넣지 말 것**(`"7일"`이 "총 17일차"에 걸렸다 · v8 §9-9).
* `--save-test`의 `game.run_cycle_seed = 0` 한 줄을 지우지 말 것(§7.3).
* `player.rollback_charges`는 저장 흔들기에서 **0으로 두어야 한다**. v3에는
  `rollback_capacity`를 올리는 카드·장비·트로피가 없어 1을 넣으면 정상 클램프가 FAIL로 잡힌다.

---

## 10. 검증 로그

| 항목 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | SCRIPT ERROR / ERROR **0** |
| `bash godot-game/scripts/test/run_all.sh` | **14종 + 컴파일 전부 PASS** · 78초 |
| `--save-test` 단독 | 묶음 11종 전부 true · 지문 68축 · 불일치 0 |
| 회귀 재현 시험 | §2의 구 복원 순서를 되살리자 `fields=false transition=false` FAIL → 복구 후 PASS |
| `--capture-lobby` (비headless) | 이어하기 버튼 활성 + 스테이지 표기 육안 확인 |
| 비headless 라이브 실행 12초 | 오류 **0줄** |
