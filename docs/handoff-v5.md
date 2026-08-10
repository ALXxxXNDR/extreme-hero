# handoff-v5 — 스테이지 진행 · 월드/랜드마크 · 기한 UI 철거 · 그레이드

> 웨이브 **V5** (설계 `docs/GAME_DESIGN_V3.md` §2 · §6 · §7 · 부록 B). 2026-08-09.
> **읽는 사람: V6(상태이상) · V7(보스) · V8(성장·결과) · V9(저장) · V10(정리).**
> 한 줄 요약: **7일 기한이 코드에서 사라졌다. 그 자리에 5스테이지와 dwell 게이지가 섰다.**

| | |
|---|---|
| 소유·수정 | `scripts/game.gd` · `scripts/world_grid.gd` · `scripts/wfc_chunk_generator.gd`(시드 1건) · `scripts/core/stage_clock.gd`(**호환 스텁 8개 삭제만**) · `scripts/test/test_runner.gd` · `scripts/test/run_all.sh` · 이 문서 |
| 무접촉 | `enemy.gd` · `core/combat_resolver.gd` · `core/status_engine.gd` · `core/rune_engine.gd` · `core/demon_lord.gd` · `core/tuning.gd` · 라이브러리 전부 · `castle_interior.gd` · `art/` · `AGENTS.md` |
| 아카이브 | `docs/v1-archive/world_grid_v2.gd.txt` (수정 직전 원본으로 갱신) |
| 검증 | `--editor --quit` 오류 0 · `run_all.sh` **13종 전부 PASS**(`--boss-test`는 임시 제외) · 캡처 육안 |

---

## 0. 이 웨이브가 실제로 한 것

| # | 항목 | 결과 |
|---|---|---|
| ① | 스테이지 전환 파이프라인 | `_rebuild_stage_world()` / `_begin_stage()` / **`advance_stage()`** 3단. 클럭 시그널이 구동한다 |
| ② | 랜드마크 개편 | 랜덤 성 삭제 · 스테이지당 **성 1 + 캠프 1 + 보스문 1** 결정적 배치 · 나침반 3줄 |
| ③ | 지형 3벌 + 5단 그레이드 | 아틀라스 교체 · CanvasModulate 스테이지 색 · 채도 · 안개 · 늪 녹조 · 비네트 |
| ④ | 기한 UI 철거 | 7일 핍·잔여 일수·기한 타이머·일수 이정표 전부 제거 → **체류 압박 게이지 + 명명된 임계선** |
| ⑤ | 잠식(blight) | 월식을 dwell 임계로 재키잉. 스테이지 클리어 시 자동 해제 |
| ⑥ | 강림 안전 밸브 | 폴링 → 상태 플래그 + 경고 UI + 등급 C 고정 (**보스 스폰은 V7**) |
| ⑦ | 균열·전조 재키잉 | 균열 dwell 1·3 / 스테이지당 2 · 전조 dwell ≥ 2 |
| ⑧ | 등급 | 총 일수 13/17/23 + 밸브 C. 결과 화면 축을 5관문으로 교체 |
| ⑨ | StageClock 호환 스텁 8개 **삭제** | 호출부 0건(grep 확인) |
| ⑩ | 테스트 | `--world-test`·`--rift-test` 재작성 · `--stage-test`에 E2E 3묶음 추가 · `--castle-test` 계약/각성 대조표 수정 · `--boss-test` 임시 주석 |

---

## 1. 스테이지 전환 파이프라인 — V7이 붙일 자리

### 1.1 구조 (game.gd)

```text
_begin_run(snapshot)                         런 시작
   └─ clock.reset()  →  _rebuild_stage_world(1)  →  _spawn_stage_starter_population()

advance_stage()  ← ★ V7이 "보스 격파" 처리 끝에서 부르는 **유일한 진입점**
   ├─ world.set_boss_gate_cleared(true)
   ├─ 플레이어 완전 회복            (트로피 2택1은 V8)
   └─ clock.advance_stage()        dwell ×0.5 · 총 일수 이월 · stages_cleared +1
          └─ signal stage_started  →  _on_stage_started()  →  _begin_stage(n)

_begin_stage(n)
   ├─ _clear_omen() · 필드 마물/XP 오브 전멸 · combat.reset()
   ├─ _rebuild_stage_world(n)      월드 통째 재생성 (설계 §2.2)
   ├─ 스테이지 스코프 상태 초기화   잠식 · 캠프 휴식 · 강림 밸브 · 배율 카운터
   ├─ 플레이어를 (0,0)으로 · 무적 STAGE_SPAWN_INVULN(1.2s)
   ├─ _spawn_stage_starter_population()   v2와 같은 9기
   ├─ _apply_stage_grade() · _update_world_lighting(1.0)
   ├─ _check_stage_blight() · _maintain_rift_schedule()   ← 이월 dwell을 즉시 따라잡는다
   └─ 배너 "N스테이지 · 이름 · 체류 d에서 시작 · 총 D일차"
```

### 1.2 V7이 해야 할 일은 정확히 두 줄이다

`_enter_boss_gate()`(game.gd)가 지금 **자리 표시자**다:

```gdscript
func _enter_boss_gate() -> void:
	if state != "playing" or clock.is_run_complete():
		return
	_show_banner("[임시] %d스테이지 관문 통과 · 보스전 배선은 V7" % clock.stage, ...)
	if not advance_stage():          # ← V7: 이 호출을 **보스 격파 콜백으로 옮긴다**
		return
	if clock.is_run_complete():
		_challenge_demon_king()      # 5관문 격파 → 필드 복귀 없이 마왕전 (부록 A-1 ③)
```

즉 V7은 `_enter_boss_gate()`를 "프리뷰 → 보스전"으로 바꾸고, 격파 콜백에서
`advance_stage()`를 부르면 된다. **나머지는 전부 재사용된다.**

`_on_stage_started()`에 `clock.is_run_complete()` 가드가 이미 있어, 5관문 격파 시에는
월드를 다시 세우지 않는다(마왕전 직전에 빈 필드가 한 프레임 보이는 것을 막는다).

### 1.3 스테이지 시드

```gdscript
func stage_world_seed(stage_number: int) -> int:
	return absi(run_cycle_seed ^ (stage_number * 2654435761)) | 1
```

`wfc_chunk_generator`의 `const WORLD_SEED`가 `var world_seed` + `set_world_seed()`가 됐다
(**알고리즘 무수정** · 기본값이 v2와 같아 시드를 안 주면 회귀 0). `world.begin_stage()`가
`terrain_generator.set_world_seed(...)`를 부른다.

### 1.4 스테이지를 넘어 유지 / 초기화되는 것

| 유지 | 초기화 |
|---|---|
| 레벨·경험치·스탯 · 5칸 덱과 각인 · 보관함 · 장비 4부위 · 골드 · `rejected_skills` · `run_cycle_seed` · **총 일수** · dwell(×0.5) · `descended`(등급 C 고정) · `pact_uses` | 월드·지형·랜드마크 · `opened_features` · 균열 예산과 `rift_states` · 잠식 · `camp_rest_used` · `stage_descent_pending` · 필드 마물 · 플레이어 좌표 |

---

## 2. 랜드마크 배치 규칙 (world_grid.gd)

### 2.1 API

```gdscript
world.begin_stage(stage_number: int, seed_value: int) -> void   # 스테이지 개시 1회
world.get_stage() -> int
world.get_stage_landmarks() -> Dictionary     # {"castle": {...}, "camp": {...}, "boss_gate": {...}}
world.get_landmark(key: String) -> Dictionary # 복사본
world.get_castle_position() / get_camp_position() / get_boss_gate_position() -> Vector2
world.get_demon_castle_position() -> Vector2  # ⚠️ v2 이름의 호환 창구 = 보스문 좌표
world.boss_gate_at(point) -> bool             # 아레나 안쪽 판정 (V7의 이탈 판정용)
world.camp_at(point) -> bool
world.set_boss_gate_cleared(bool) -> void
world.get_stage_compass(point) -> Dictionary  # {"boss_gate"/"camp"/"castle": {position,direction,distance}}
world.stage_atlas_key / stage_saturation / stage_green_overlay   # 그레이드 조회
world.boss_gate_radius                        # SAFE_ZONE_RIFT × 2.2 = 330
```

### 2.2 배치 규칙 (전부 `stage_seed`만으로 결정 · 같은 시드면 같은 자리)

| 랜드마크 | 규칙 | 안전 반경 | 나침반 |
|---|---|---:|---|
| 보스문 | 스폰(0,0) 기준 각도 = 시드 해시 · 거리 3,600~4,200px | 330 (아레나) | 1줄 |
| 캠프 | **보스문에서 스폰 쪽으로 520px** — 반드시 보스문보다 먼저 만난다 | 175 | 1줄 병기 |
| 성 | 스폰 기준 각도 = 시드 해시 · 거리 300~420px | 190 | 2줄 |
| 균열 | v2 규칙 그대로(900~1,400px 링) · **스테이지당 2** | 150 | 3줄 |

- 셋 다 `_nearest_dry_spot()`이 "덮개 반경 전체가 마른 땅"인 자리로 밀어낸다(최대 48회 결정적 탐색).
  못 찾으면 원래 자리를 쓰고 `_resolved_tile_id()`의 바닥 덮개가 물을 가린다.
- `_features_near()`가 랜드마크를 **먼저** 얹고 그 청크의 절차 feature를 건너뛴다.
  캠프와 보스문은 520px이라 같은 청크(800px)에 들어갈 수 있어 "청크당 하나" 규칙에 맡길 수 없다.
- ⚠️ **랜드마크는 `duplicate(true)`로 흘린다.** v2 feature는 매번 새로 만드는 임시 사전이라
  호출부가 마음대로 다뤄도 됐지만 v3 랜드마크는 월드가 들고 있는 영속 객체다.
  `game._refresh_interactable()`이 그대로 담고 `current_interactable.clear()`를 부르는
  경로가 여러 곳이라 원본을 흘리면 **성이 통째로 빈 사전이 된다**(실측으로 잡은 회귀).

### 2.3 랜덤 성 삭제

`_feature_for_chunk()`의 두 리터럴이 `GameTuning.CASTLE_FEATURE_ROLL`(0) /
`CHEST_FEATURE_ROLL`(58)로 바뀌었다. **되돌리려면 그 두 상수를 9 / 49로 되돌리면 끝**이다
(설계 §2.3이 약속한 되돌림 지점). v2의 고정 분기 2개(청크 (0,-1) 시작 성 · 마왕성 청크)는 삭제됐다.

### 2.4 보스방 = 필드 위 원형 아레나

균열 렌더러를 반경 ×2.2(=330)로 복제했다. 신규 씬 0개 · 신규 `state` 0개.
`_resolved_tile_id()`가 아레나 바닥을 `T_CAMP`로 덮고, `_draw_boss_gate()`가
이중 링 + 흙길 + `landmark-boss-gate.png`(밑변 기준)를 그린다. 격파하면
`set_boss_gate_cleared(true)`로 색이 죽는다.

### 2.5 베이스 캠프 = 성과 완전히 같은 정비 공간

사용자 요구 원문("성이랑 똑같아")대로 **`castle_interior.gd`를 한 줄도 안 고쳤다.**
`_enter_castle()`이 `type == "camp"`를 보고 `inside_camp` 플래그만 세운다.
다른 것은 두 가지뿐이다:

1. 입장 배너·HUD 문구("베이스 캠프 · 보스방 앞")
2. **스테이지당 1회 완전 회복**(`camp_rest_used`) — 여관 역할(설계 §3.6 추가 1건)

> 설계 §3.6이 요구한 `castle_interior.setup(..., variant)` 파라미터화와
> `ROOM_BOUNDS` 리터럴 4곳 통합은 **하지 않았다.** 사용자 요구가 "똑같아"이고
> 서비스·NPC·좌표가 전부 같아 실익이 없다. 필요하면 V8이 결과·성 구역과 함께 한다.

---

## 3. 잠식 / 강림 밸브 상태 머신

```text
                 dwell +1 (주기 종료)
   ┌──────────────────────────────────────────────────┐
   ▼                                                  │
[평시]  dwell < STAGE_BLIGHT_DWELL[stage]             │
   │                                                  │
   │ dwell ≥ 임계 ([4,4,3,3,2])                        │
   ▼                                                  │
[잠식]  eclipse_active = true                          │
   │   · 필드 마물 전원이 마왕 잔재 모듈 100% + 각인 1개  │
   │   · HP ×1.22 · 피해 ×1.16 · 속도 ×1.05 (v2 승계)   │
   │   · 0.28초마다 신규 스폰을 스윕                     │
   │                                                  │
   │ dwell ≥ DWELL_DESCENT[stage] ([14,13,12,11,10])   │
   ▼                                                  │
[강림 대기]  stage_descent_pending = true              │
       clock.mark_descended()  → **등급 C 영구 고정**   │
       (실제 보스 스폰은 V7)                            │
                                                      │
   advance_stage() → dwell = floor(dwell × 0.5) ───────┘
       → _check_stage_blight()가 임계 아래면 [평시]로 복귀
       → stage_descent_pending = false (밸브 재무장)
```

### 3.1 코드 지점

| 이름 | 하는 일 |
|---|---|
| `_on_dwell_advanced(stage, dwell)` | 균열 따라잡기 · `_check_stage_blight()` · 이정표 배너 · HUD |
| `_check_stage_blight()` | `clock.blight_active()` → `_begin_eclipse()` / 아니면 `_end_blight()` |
| `_process` 폴링 | `clock.descent_valve_ready()` → `_trigger_stage_descent()` (**시그널 없음**) |
| `stage_descent_active()` | V7 조회 창구 |

### 3.2 ⚠️ 식별자가 아직 `eclipse_*`인 이유

`eclipse_active` · `eclipse_marked` · `ECLIPSE_META` · `_sweep_eclipse()` ·
`eclipse_module_pool()` · `_on_clock_milestone()`은 **이름만 v2 그대로다. 의미는 잠식이다.**

지울 수 없었던 이유는 하나다 — `test_runner.gd::_run_boss_test`가 이 여섯을 참조하는데
그 테스트는 **V7 소유라 V5가 고칠 수 없다.** GDScript는 정적 타입 멤버 접근을 컴파일
시점에 검사하므로 이름을 지우면 `test_runner.gd` 전체가 파스 에러가 되고 13종 테스트가
한꺼번에 죽는다. **V7이 `--boss-test`를 재작성할 때 `blight_*`로 개명할 것.**
`_on_clock_milestone(id, day)`도 그때 지운다(지금은 `id == "eclipse"`만 받는 테스트 전용 문이다).

---

## 4. UI 변경점

### 4.1 철거한 것 (7일 기한 5클러스터)

| 자리 | v2 | v3 |
|---|---|---|
| HUD 패널 제목 | "3일차 · 낮" | "**2스테이지 시든 숲 · 낮**" |
| 우상단 수치 | "잔여 7일" | "**체류 N**" (잠식 후 붉게) |
| 핍 | 일수 7개 | **스테이지 5개** |
| 게이지 | 낮/밤 진행 1줄 | 낮/밤 1줄 + **체류 압박 1줄 + 잠식 임계선 눈금** |
| 하단 좌 | "낮 39초 · 기한 13:39" | "낮 39초 · **총 6일차 · 잠식 4 / 강림 13**" |
| 하단 우 | "다음 5일차 · 월식" | "**체류 3(+1) · 두 번째 균열**" |
| 나침반 | 마왕성 / 균열 2줄 | **캠프·보스문 / 성 / 균열 3줄** + "이 스테이지 균열 1 / 2" |
| 온보딩 4p | 7일 타임라인 · "기한은 7일" | **5관문 타임라인** · "기한은 없습니다. 총 13일 이하 S…" |
| 결과 화면 | 7일 타임라인 · "도달 일차 3 / 7" · "잔여 기한" | **5관문 타임라인** · "총 일수 (S≤13)" · "관문 · 최종 체류" |
| 계약자 | "하루를 사고판다" | "**체류 압박을 사고판다**" |

변수명도 함께 바뀌었다: `deadline_panel`→`stage_panel` · `day_pips`→`stage_pips` ·
`deadline_left_text`→`dwell_text` · `milestone_text`→`dwell_milestone_text` ·
`_update_deadline_panel()`→`_update_stage_panel()` · `_build_deadline_panel()`→`_build_stage_panel()`.
신설: `dwell_track` · `dwell_fill` · `dwell_blight_mark` · `castle_text`.

**체류 압박 게이지**(설계 §10 리스크 #1이 "곡선보다 중요하다"고 못 박은 것):
0..1 = `clock.dwell_ratio()`(강림 밸브까지). 그 위에 `blight/descent` 비율 위치에
2px 세로 눈금 하나. 잠식이 켜지면 채움과 눈금이 함께 붉어진다. **트윈 0** — 폭만 즉시 반영.

### 4.2 스테이지 그레이드 — 색을 **세 계층이 나눠 갖는다**

한 색을 두 계층에서 곱하면 5스테이지가 새까매진다. 그래서 축을 갈랐다:

| 계층 | 소유 | 무엇 |
|---|---|---|
| 아틀라스 | `world_grid.TERRAIN_ATLASES` | verdant / waste / abyss (`STAGE_TERRAIN_ATLAS`) |
| 타일·랜드마크 틴트 | `world_grid._grade()` | **채도**(`STAGE_SATURATION`) + **늪 녹조**(`STAGE_GREEN_OVERLAY_ALPHA`) |
| 전역 조명 | `game._update_world_lighting()` CanvasModulate | `STAGE_DAY/NIGHT_MODULATE` |
| 화면 쿼드 | `game.stage_overlay` (ui_root · hud **밑**) | 안개 · 늪 녹조 쿼드 · 비네트 |

안개 주의 2건(캡처 실측으로 고친 것):
1. `overlay-fog.png`는 **타일러블이 아니다**(ASSET_MAP §14). `STRETCH_TILE`로 깔면
   같은 구름이 반복돼 물방울 무늬로 읽힌다 → `EXPAND_IGNORE_SIZE` + `STRETCH_SCALE`
   (320×180 → 1280×720 = 정확히 ×4라 nearest에서 픽셀이 안 밀린다).
2. 안개는 화면 공간이라 CanvasModulate 밖이다. 흰 구름을 그대로 두면 밤에 **하얀 띠**로
   읽힌다 → `_tint_stage_fog()`가 매 프레임 조명색을 곱한다.

비네트는 `TEXTURE_FILTER_LINEAR`(이 노드 하나만) · modulate α **0.55**
(원안 0.72는 5스테이지 밤에서 안개와 겹쳐 몹 실루엣이 가장자리에서 사라졌다).

---

## 5. 재키잉된 시스템 (균열 · 전조 · 계약)

| 시스템 | v2 | v3 | 코드 |
|---|---|---|---|
| 균열 | 2·4·6일차 · 런당 3 | **dwell 1·3 · 스테이지당 2 · 런 10** | `game.rifts_due(d)` → `clock.rifts_due(d)` · `world.RIFT_MAX_PER_RUN = GameTuning.RIFT_STAGE_BUDGET` |
| 전조 | 3일차 밤~ | **dwell ≥ 2 · 전 스테이지** | `game.omen_should_spawn(dwell)` → `clock.omen_should_spawn()` |
| 잠식 | 5일차~런 끝 | **dwell 임계 · 클리어 시 해제** | §3 |
| 계약 정비(`sell_day`) | 하루 판다 +90 G | **dwell −1 · 비용 120 + 60×사용횟수 G** | `pact_respite_cost()` |
| 계약 탐욕(`buy_day`) | 하루 산다 | **dwell +1 · 각인 1 파괴 + 카드 1장 → 200 G + 조각 1** | |
| 계약 담보(`mortgage`) | 마왕 각인 +2 | **dwell +2** → 영웅 각인 1 | |

저장 키(`pact_uses`의 세 키)는 **일부러 v2 이름 그대로 뒀다** — `--castle-test`와 `--save-test`의
지문 축이 그 이름을 읽는다. 라벨만 정비/탐욕으로 바뀌었다.

`world.RIFT_MAX_PER_RUN`이라는 **이름**도 유지했다(`--save-test`가 읽는다). 값의 의미만
"런당 3"에서 "**스테이지당 2**"로 바뀌었고 `begin_stage()`마다 다시 채워진다.

---

## 6. ⚠️ V6이 반드시 처리할 것 — 스테이지 배율 임시 우회로

설계가 지정한 자리는 `core/combat_resolver.gd`의 스폰·스케일 3함수인데 그 파일은
**V6 소유라 V5가 열 수 없었다**(오케스트레이터 수정 금지 목록). 그래서 월식 스윕(W10)이
쓰던 "스폰 직후 폴링" 패턴을 복제해 game.gd 쪽에서 배율을 먹인다.

```gdscript
const STAGE_SCALE_META := "stage_scale"      # ← grep 대상
func _sweep_stage_scaling() -> int            # _process(playing)에서 매 프레임
func _apply_stage_scaling_to(enemy) -> void   # 마물 1기당 딱 한 번
```

먹이는 값: `clock.enemy_hp_multiplier()`(= `STAGE_HP_BASE × H(dwell)`) ·
`enemy_damage_multiplier()` · `enemy_speed_multiplier()` · `xp_multiplier()`(H^0.5) ·
`gold_multiplier()`(H^0.4).

**V6이 `combat_resolver`에 이 계열을 심을 때 위 두 함수와 `_process`의 호출 한 줄을
반드시 지울 것.** 안 지우면 배율이 두 번 곱해진다.

두 가지 함정을 미리 적어 둔다:

1. **체력을 `max_health`로 되돌리지 말 것.** 스윕은 스폰 다음 프레임에 도는데 그 프레임의
   물리 스텝에서 이미 피해가 들어갔을 수 있다. `health = max_health`로 쓰면 그 피해가
   조용히 지워진다 — `--v4-test`의 `live_direction`이 **6회 중 1회** 실패하는 형태로
   실측됐다. 지금 코드는 **비율 보존**(`health_ratio`)이라 배율 1.0에서 완전한 no-op이다.
2. 1스테이지 dwell 0에서는 다섯 배율이 전부 정확히 1.0이라 v2와 한 픽셀도 다르지 않다.

### 6.1 함께 남은 것 — 몹 스테이지 티어 (V2 API 미배선)

`combat_resolver.maintain_field_population()`이 아직
`MonsterLibrary.roll(rng, game.cycle_number, is_night)`(일수 기반 v2 API)를 부른다.
V2가 만든 스테이지 API(`roll_for_stage` · `stage_pool` · `stage_spawn_table` …)로 바꾸려면
`combat_resolver.gd`를 열어야 해서 **V5가 못 했다. V6/V7이 함께 처리할 것.**

지금 상태가 치명적이지는 않다 — `cycle_number`(총 일수)가 스테이지를 넘어 누적되므로
3스테이지쯤(≈10일차)이면 v2 해금이 전부 열린다. 다만 §6.3 표의 "T1 4종 → T3+T4 10종"
곡선과는 다르다.

handoff-v4 훅 표 대비 상태:

| 훅 | 상태 |
|---|---|
| ① 강림 밸브 폴링 | ✅ V5 |
| ② `_begin_stage(n)` 추출 | ✅ V5 |
| ③ `combat_resolver` 물량 3함수 | ❌ **V6** (파일 소유권) |
| ④ 몹 체력·피해·속도·XP·골드 | 🟡 V5가 game.gd 스윕으로 임시 배선 → **V6이 옮길 것** |
| ⑤ 전조 게이트 | ✅ V5 |
| ⑥ 균열 스케줄 | ✅ V5 |
| ⑦ 월식 → 잠식 | ✅ V5 |
| ⑧ 강림 경로 | 🟡 상태·경고까지 V5 / 보스 스폰은 **V7** |
| ⑨ HUD 기한 패널 | ✅ V5 |
| ⑩ 온보딩 타임라인 | ✅ V5 (`grep TOTAL_DAYS` game.gd·world_grid.gd **0건**) |
| ⑪ 계약자 NPC | ✅ V5 |
| ⑫ 결과 화면 문구 | ✅ V5 (칩 구성 확장은 V8) |

---

## 7. StageClock 호환 스텁 8개 — **삭제 완료**

`total_days()` `days_left()` `run_total()` `run_remaining()` `is_final_day()`
`is_final_phase()` `milestone_for()` `milestones_up_to()` → 전부 제거.
`stage_clock.gd`의 그 자리에 "무엇으로 갈아탔는가" 표가 주석으로 남아 있다.

발화하지 않는 시그널 2개(`milestone_reached` `descent_triggered`)는 **남겨 뒀다** —
`--stage-test`의 `infinite` 항목이 "발화 0회"를 단언하는 관측점이기 때문이다.
game.gd의 `connect()` 2줄은 삭제했다.

`game.deadline_remaining()`도 삭제했다(호출부 0).

---

## 8. 저장 (V9에게)

`RUN_SCHEMA_VERSION`은 **아직 2다**(V9 소유). V5는 가산 키만 넣었다:

```
stage_index · stage_dwell · stage_seed · stages_cleared ·
stage_descent_pending · camp_rest_used · blight_active
```

클럭 스냅샷(`"deadline_clock"` 키)이 이미 `stage`/`dwell`/`stages_cleared`/`descent_used`/
`run_elapsed`를 들고 있으므로 복원의 진실 원천은 그쪽이다. `_restore_run_snapshot()`에
**월드 재생성 훅**을 넣어 뒀다:

```gdscript
clock.from_snapshot(clock_data)
if is_instance_valid(world) and world.get_stage() != clock.stage:
	_rebuild_stage_world(clock.stage)     # ← 균열 복원보다 반드시 먼저
```

V9가 할 일: 키 이름을 `"stage_clock"`으로 올리고 `stage_landmarks`를 좌표째 복원할지
결정하는 것(지금은 시드에서 결정적으로 재생성되므로 **복원 없이도 같은 자리**가 나온다 —
`--world-test`의 `seeds` 항목이 그걸 단언한다).

---

## 9. 테스트

### 9.1 재작성 / 수정 목록

| 테스트 | 처리 |
|---|---|
| `--world-test` | **전면 재작성.** 랜드마크 3종 존재·타입·보행 가능 / 배치 규칙(캠프가 보스문보다 먼저) / 스테이지 시드 결정성·차이 / 아틀라스 3벌 교체 + 5스테이지 비네트·안개·채도 / 물길·다리 / WFC 5종(v2 승계) |
| `--rift-test` | **전면 재작성.** 스테이지당 예산 2 · dwell 1·3 스케줄 · 실제 주기 진행으로 개설 · 웨이브·클리어·보상·재활성(v2 승계) · **스테이지 전환 시 예산 리필 + 이월 dwell 즉시 따라잡기** |
| `--stage-test` | **E2E 3묶음 추가**: `stage_pipe`(1→2 전환 6항 + 5관문 완주 + 마왕전 직행) · `blight_wire`(임계 점등·표식·클리어 해제) · `descent_wire`(밸브→상태→등급 C). `omen_gate`/`omen_spawn`의 일수 단언을 dwell로 재키잉 |
| `--castle-test` | 계약자 3종을 dwell 거래로 재작성 · 성 진입 좌표를 `world.get_castle_position()`으로 · **2차 각성 원소 대조표를 v3 7원소로**(V2 collateral `awakening_day6=false` 해소) |
| `--v4-test` | 성 진입 좌표 1줄 |
| `--cycle-test` | 전조 게이트 1줄(일수 → dwell) |
| `--capture-world` | **스테이지 톤 스윕 신설** — 1·3·5 × 낮/밤 6컷 + 랜드마크 2컷 |
| `--capture-hud` | 스테이지 2·체류 2 상태로 세팅 + **잠식 경고 컷 신설**(4컷째) |
| `--boss-test` | `run_all.sh`에서 **임시 주석**(아래) |

### 9.2 `--boss-test` 임시 비활성

`_run_boss_test` ⑥⑦이 v2의 "7일차 밤 끝 = 마왕전" 스케줄을 단언하는데 v3가 그 스케줄을
삭제해 `game.boss_cycle`이 `null`로 남고 `:1512`에서 하드 크래시 → `_quit_test_cleanly`에
도달하지 못해 **180초 타임아웃을 통째로 태운다**(V4가 이미 실측·보고). 테스트 코드 자체는
V7 소유라 V5가 못 고친다. `run_all.sh`의 `ALL_TESTS`에서 그 줄을 주석 처리하고
**"V7이 반드시 되살릴 것"**을 주석으로 못 박았다. `--boss-test` 플래그 자체는
`ROUTINES`에 살아 있어 개별 실행은 가능하다.

### 9.3 검증 결과

```
godot --headless --path godot-game --editor --quit        → ERROR/SCRIPT ERROR 0줄
bash godot-game/scripts/test/run_all.sh                   → 13종 전부 PASS (56초)
   compile world-test v4-test castle-test rift-test stress-test smoke-test
   combat-test stage-test status-test cycle-test draft-test save-test
```

`--stage-test` 22항목 전부 true:
`game_clock early_challenge rune_formula slot_layout omen_gate omen_spawn omen_reward
infinite dwell_monotone monotonic curve reward_decay volume blight descent_valve
carryover total_days phase_len demon_recal` **`stage_pipe blight_wire descent_wire`**

캡처(비headless · `art/screenshots/qa/`):

| 파일 | 확인한 것 |
|---|---|
| `world-minimal-v2-stage{1,3,5}-{day,night}.png` | 5단 톤이 육안으로 갈린다 — 초원 / 모래+안개 / 자주+안개+비네트. 5스테이지 밤에서도 실루엣·체력바 판독 가능 |
| `world-minimal-v2-landmark-camp.png` | 캠프(초록 링 + 천막) 오른쪽, 보스문 아레나(붉은 원 + 문) 왼쪽 — **캠프가 스폰 쪽에 있다** |
| `world-minimal-v2-landmark-boss_gate.png` | 반경 330 아레나 + 이중 링 + 문 스프라이트 + 흙길 |
| `hud-minimal-v2-day.png` | 스테이지 제목 · 체류 2 · 5핍 · 2단 게이지 · "잠식 4 / 강림 13" · 나침반 3줄 |
| `hud-minimal-v2-blight.png` | 체류 4 붉은 표기 · 게이지 붉음 · "체류 13(+9) · 보스 강림" |
| `result-minimal-v2.png` | 5관문 타임라인 · "총 일수 (S≤13)" · "관문 · 최종 체류" · "잠식 N기" |
| `onboarding-minimal-v2-p4.png` | 5관문 타임라인 · "기한은 없습니다" · 캠프/보스방·잠식/강림 칩 |

---

## 10. 판단 기록 (왜 그렇게 했는가)

| 갈림길 | 선택 | 근거 |
|---|---|---|
| 잠식 임계 | `[4,4,3,3,2]`(§6.3 표) | V0·V4의 판단을 **재확인**. §2.4 유도식 `max(2,5−stage)`는 3~5스테이지를 전부 2로 뭉개 후반 곡선이 계단이 된다 |
| `eclipse_*` 식별자 | **유지**(의미만 잠식) | `--boss-test`(V7 소유)가 6개 멤버를 참조. 지우면 `test_runner.gd` 전체 파스 에러 → 13종 동시 사망 |
| 스테이지 배율 적용 위치 | game.gd 스윕(임시) | `combat_resolver.gd`가 V6 소유. 안 하면 스테이지 전환에 기계적 차이가 0이 된다 |
| 체력 스케일 방식 | **비율 보존** | `health = max_health`는 같은 프레임의 피해를 지운다(실측 1/6 실패) |
| `castle_interior` variant | **안 만들었다** | 사용자 요구가 "성이랑 똑같아". 서비스·NPC·좌표가 전부 같아 실익이 없다 |
| 보스문 `E` 동작 | 임시로 `advance_stage()` 직행 | 게임이 1→5→마왕까지 실제로 굴러가야 V6~V8이 손으로 확인할 수 있다. V7이 한 줄 옮기면 끝 |
| 안개 렌더 | 화면 공간 쿼드 + 조명색 곱 | ASSET_MAP이 "타일러블 아님"을 명시. 월드 노드는 z=-20이라 마물 뒤로 들어간다 |
| 비네트 α | 0.72 → **0.55** | 5스테이지 밤에서 안개와 겹쳐 가장자리 실루엣이 사라졌다(캡처 실측) |
| `RIFT_MAX_PER_RUN` 이름 | **유지**(값 의미만 변경) | `--save-test`(V9 소유)가 읽는다 |
| `DEMON_CASTLE_POSITION` / `STARTER_CASTLE_POSITION` | 선언만 남김 | `test/rift_probe.gd`가 참조. 지우면 `--editor --quit`이 파스 에러 → 컴파일 검사 전체 실패 |

---

## 11. 남은 위험

| 위험 | 크기 | 대응 |
|---|---|---|
| 스테이지 배율 스윕이 V6에서 **이중 적용** | 중 | 코드·이 문서 §6에 `STAGE_SCALE_META` grep 지점 명시 |
| 몹 티어가 아직 일수 기반 | 중 | §6.1. V6/V7이 `combat_resolver`를 열 때 처리 |
| 5스테이지 밤 가독성 | 중 | 4계층(타일 밤 틴트 × CanvasModulate × 안개 × 비네트)이 겹친다. 비네트를 0.55로 낮춰 두었으나 **V10 육안 판정 대상** |
| 스테이지 시드가 런마다 무작위 | 소 | `run_cycle_seed`에서 파생하므로 테스트는 결정적이지만 **실행마다 지형이 다르다**. v2의 고정 (250,-250) 성에 기대던 테스트를 전부 `get_castle_position()`으로 옮겼다 |
| 계약 정비의 dwell −1이 잠식을 즉시 끈다 | 소 | 의도(압박을 골드로 되산다). 거래당 2회 제한이 상한이다 |
| 결과 화면 칩 구성이 아직 v2 축 | 소 | 시너지 발동 횟수 등 v3 지표는 **V8** |
| `--boss-test` 비활성 | 중 | V7이 되살린다. `run_all.sh`에 못 박았다 |
