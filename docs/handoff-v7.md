# handoff-v7 — 스테이지 보스 3종 · 보스방 전투 · 강림 밸브 · 마왕 직행

> 웨이브 **V7** (설계 `docs/GAME_DESIGN_V3.md` §3 전체 · §2.1 · §6.6 · 부록 B의 V7). 2026-08-09.
> **읽는 사람: V8(성장·결과) · V9(저장) · V10(정리·밸런스).**
> 한 줄 요약: **보스문이 진짜 문이 됐다.** V5가 "진입 = 클리어"로 통과시키던 자리에
> 3칸(강화형 4칸) 딜싸이클 보스가 서고, 격파해야 다음 스테이지로 넘어가며,
> 5스테이지 보스를 잡으면 필드를 거치지 않고 그대로 마왕전이 열린다.

| | |
|---|---|
| 소유·수정 | `scripts/game.gd`(보스 구역) · `scripts/enemy.gd` · `scripts/projectile.gd` · `scripts/test/test_runner.gd` · `scripts/test/run_all.sh` · 이 문서 |
| **경계 접촉(보고 대상)** | `scripts/core/combat_resolver.gd` **3곳**(§8) — 투사체 setup 이관 2줄 + 스테이지 보스 상태 게이트 2줄 |
| 무접촉 | `core/status_engine.gd` · `core/rune_engine.gd` · `core/stage_clock.gd` · `core/demon_lord.gd` · `core/tuning.gd` · `boss_library.gd`(**한 글자도 안 고쳤다** — 데이터 조정 0건) · 나머지 라이브러리 전부 · `factory_deck.gd` · `deal_cycle_controller.gd` · `cycle_skill_effect.gd` · `world_grid.gd` · `player.gd` · `castle_interior.gd` · `art/` · `AGENTS.md` |
| 검증 | `--editor --quit` 오류 **0** · `run_all.sh` **14종 전부 PASS**(`--boss-test` 재활성 포함 · 76초) · `--capture-boss` 9컷 + `--capture-world` 육안 |

---

## 0. 이 웨이브가 실제로 한 것

| # | 항목 | 결과 |
|---|---|---|
| ① | 스테이지 보스 전투 | 프리뷰(취소 가능) → 아레나 전투. 3칸/4칸 · 각인·과열 없음 · RELOAD 0.75/0.55 |
| ② | 보스 시트 테이블 | `enemy.gd`의 마왕 하드코딩 3상수 → `BOSS_SHEETS` 6벌. foot_inset·마스크·행/프레임 |
| ③ | telegraph | V3 링 시트 3행(expand/charge/pool)을 **판정과 같은 노드**로. 트윈 0 |
| ④ | 페이즈 | 기본 HP 50% 1회 / 강화 66%·33% 2회. 선딜 ×0.86 · 피해 ×1.12 누적 |
| ⑤ | 격파 흐름 | `advance_stage()` 호출을 **격파 콜백으로 이전**(V5 임시 배선 제거) + 트로피 훅 |
| ⑥ | 마왕 직행 | 5스테이지 격파 → 필드 복귀 0프레임 → `_challenge_demon_king()` |
| ⑦ | 강림 밸브 실체화 | dwell 임계 → 필드 강림(프리뷰 없음 · 칸 +1 · HP ×1.15 · 등급 C) |
| ⑧ | 마왕전 경로 정리 | v2 `_trigger_descent()` · `demon_castle` 상호작용 **삭제**(호출부 0이던 죽은 길) |
| ⑨ | `eclipse_* → blight_*` | 개명 일괄(참조 52 + 16곳). V5가 V7에 넘긴 부채 |
| ⑩ | `projectile.gd` setup 인자 | V6의 "시그널 연결 순서 의존" 우회로 제거(handoff-v6 §11 미결 3) |
| ⑪ | 플레이어 상태이상 | 보스 패턴이 붙이는 독·연·한·유·전. `player.gd` **무수정**으로 배선 |
| ⑫ | 테스트 | `--boss-test` **전면 재작성 9묶음** + `run_all.sh` 재활성 + `--v4-test` 칸수 단언 + `--capture-boss` 9컷 재작성 |

---

## 1. 스테이지 보스 전투 — 실제 구조

### 1.1 흐름 (game.gd)

```text
보스문에서 E
  └─ _enter_boss_gate()                     stage_boss_cleared 가드
       └─ _show_stage_boss_preview()        state="boss_preview" · boss_preview_kind="stage"
            ├─ ESC → _cancel_boss_preview() 필드 복귀(§3.5 "취소 가능")
            └─ SPACE → _begin_stage_boss_battle()
                 ├─ state="boss" · 필드 마물/XP 전멸 · 플레이어를 아레나 안으로
                 └─ _spawn_stage_boss(profile, 아레나 중심, previewed=true)

강림 밸브(§6.6)
  _process 폴링 → _trigger_stage_descent()  clock.mark_descended() → 등급 C 고정
       └─ _begin_stage_boss_descent()
            └─ _spawn_stage_boss(profile, 플레이어 옆, previewed=false)   ← state는 "playing"

격파 (enemy._die() → game.on_stage_boss_defeated())
  ├─ _teardown_stage_boss()      사이클·노드·장판·플레이어 상태·HUD 원복
  ├─ pending_stage_trophy = {...}   ★ V8이 읽을 훅 (임시 배너까지가 V7)
  ├─ state="playing" · advance_stage()   ← V5 파이프라인 무수정 재사용
  └─ clock.is_run_complete() → call_deferred("_challenge_demon_king")
```

### 1.2 부품을 어떻게 재사용했나 (신규 파일 0 · 신규 state 문자열 0)

| 부품 | 스테이지 보스가 쓰는 방식 | 그 파일을 안 고친 방법 |
|---|---|---|
| `FactoryDeck` | 패턴을 카드처럼 담는 3~4칸 덱 | **`class StageBossDeck extends FactoryDeck`** 를 game.gd 안에 두고 `compile_slot()` 하나만 재정의. GDScript 메서드는 기본 가상이라 `rune_deck()` `total_reload()`도 함께 올바르게 돈다 |
| `DealCycleController` | 바늘·스텝·빚 RELOAD | `setup(..., is_boss=true)` 뒤 **`reload_scale`을 game.gd가 덮어쓴다**(0.60 → 0.75/0.55). 컨트롤러는 무수정 |
| 마왕 레일 밴드 HUD | 칸 3~5 가변 · 과열 사다리 숨김 | `active_boss_cycle()` / `active_boss_factory()` / `active_boss_is_stage()` 창구 3개를 새로 두고 기존 `_update_boss_rail`이 그것만 본다 |
| 보스 체력 패널 | 이름·칸수·페이즈·내 상태 | `update_boss_health()` 텍스트만 분기 |
| `enemy.gd` 보스 노드 | 시트·반경·페이즈만 다름 | `setup()` 시그니처 무변경 + **`configure_stage_boss(profile)`** 를 add_child **전에** 부른다 |

### 1.3 `compile_slot` 재정의가 필요했던 이유 (안 하면 3칸이 전부 "기본 베기")

`FactoryDeck.compile_slot()`은 `DealCardLibrary.ranked()`로 카드 정의를 되읽는데,
보스 패턴 id(`boss_a_stomp` …)는 그 라이브러리에 **없다**. `ranked()`는 못 찾으면
`BASIC`으로 떨어뜨리므로 3칸이 전부 기본 베기가 된다. `deal_card_library.gd`도
`factory_deck.gd`도 V7 소유가 아니라, 덱 쪽에서 한 함수만 재정의하는 것이 유일한 길이었다.

---

## 2. telegraph — **설계에서 가장 어려웠던 지점** (§3.3의 telegraph 열)

### 2.1 문제

`CycleSkillEffect`는 스텝이 시작하는 **순간(elapsed ≈ 0)** 에 판정을 낸다
(`_physics_process`의 `if elapsed <= action_duration` 블록이 pulse 0을 즉시 터뜨린다).
그 구조에서는 "0.35~1.20초 선딜 뒤에 맞는다"가 **물리적으로 불가능**하다.
`action_ratio`는 판정 창을 앞에서부터 줄일 뿐 뒤로 밀지 못한다.

### 2.2 검토하고 버린 대안 3개

| 대안 | 버린 이유 |
|---|---|
| 다음 스텝을 미리 읽어 **직전 스텝 꼬리에** 링을 띄운다 | 함정형(`trap`) 패턴의 착탄점은 `CycleSkillEffect.setup()`이 **스텝 시작 시점의 플레이어 좌표**로 고정한다. 링을 그보다 먼저 띄우면 링 자리와 착탄점이 어긋나 **선딜을 봐도 피할 수 없다.** 텔레그래프의 존재 이유가 사라진다 |
| 카드 `damage`를 0으로 두고 game.gd가 따로 때린다 | `_cycle_damage_value()`의 보스 분기에 `maxf(3.0, ...)` 하한이 있어 **패턴마다 3 피해가 새어 나간다**(60초 전투에서 100 이상) |
| `kind`를 `shield`로 바꿔 무해화 | 보스 몸에 보호막 버블이 매 패턴마다 뜬다. 시각적으로 거짓말 |

### 2.3 채택 — `kind = "boss_pattern"` + game.gd 실행

`StageBossDeck.compile_slot()`이 원래 형태를 `pattern_kind`로 옮기고 `kind`를
**`boss_pattern`** 으로 바꾼다. 이 문자열은 `combat_resolver._trigger_boss_cycle_pulse()`의
`match`에 없고 **그 match에는 `_:` 기본 분기가 없다** → v2 보스 피해 경로가 통째로 no-op이 된다.
그 자리를 `game.on_cycle_card_started()`가 받아 `_launch_stage_boss_pattern()`으로 넘긴다.

```text
슬롯 진입 → on_cycle_card_started(card.kind == "boss_pattern")
   └─ _launch_stage_boss_pattern()
        ├─ 선딜 = telegraph × 0.86^페이즈
        ├─ 착탄점 계산 (_stage_boss_pattern_points) — **시전 시점에 고정된다**
        └─ 착탄점마다 BossTelegraph 노드 1개
              lead초 차오름 → impact 1회 → (잔류면) tick_interval마다 pool_tick → 소멸
```

**링이 뜬 자리가 곧 착탄점이다** — 같은 노드의 같은 `global_position`, 같은 `radius`를
표시와 판정이 함께 쓴다. 이게 이 구조를 고른 유일하고 결정적인 이유다.

⚠️ **V10 주의**: `_trigger_boss_cycle_pulse()`의 `match`에 `_:` 기본 분기를 추가하면
보스 패턴이 **두 번** 터진다. 안전망으로 컴파일된 카드의 `damage`는 그대로 두었으므로
그 경우 피해가 이중이 된다. 분기를 추가할 일이 있으면 `boss_pattern`을 명시적으로 제외할 것.

### 2.4 링 시트 3행의 배정 (handoff-v3-assets §13-3 그대로)

| 행 | 이름 | 쓰는 패턴 |
|---:|---|---|
| 0 | `expand` | 파동형(`wave`) — A 서리 발구름 · B 도약 압살 · B+ 역병 파열 · **페이즈 전환 파동** |
| 1 | `charge` | 예고 원·선형 — A 빙주 낙하 ×3 · C 활공 참격 · C 화염 강하 · B 분열 |
| 2 | `pool` | 잔류·도포 — B 산성 분비(8초) · C 기름 날개 · C+ 흑염 회오리(3초) |

선택 규칙(코드): `lingering > 0` 또는 `paints_ground` → 2, `form ∈ {trap,pierce,slash,guard}` → 1, 나머지 → 0.

### 2.5 패턴 데이터의 특수 키를 어디서 소비하나

| 키 | 소비 지점 | 하는 일 |
|---|---|---|
| `telegraph` | `_launch_stage_boss_pattern` | 선딜(초). 페이즈마다 ×0.86 |
| `status` / `status_stacks` / `status_power` | `_strike_player_with_pattern` | 매트릭스가 안 붙였으면 데이터대로 보장 |
| `status_secondary` | 같은 곳 | 강화형의 2종 동시 부여(절반 세기) |
| `conditional_status` / `_damage_mul` | `_on_stage_boss_impact` | A-3 "chill이면 ×1.6" |
| `bonus_per_player_stack` | 같은 곳 | B-4 "독 스택만큼 더 아프다" |
| `arena_wide` | `_stage_boss_pattern_radius` / 판정 | 아레나 반경 ×0.92 · 회피 불가 |
| `random_impacts` + `hits` | `_stage_boss_pattern_points` | 플레이어 주변에 `hits`개 흩뿌림 |
| `paints_ground` + `arc` | 같은 곳 | 부채꼴로 링 3개 추가(C-1 기름 도포) |
| `lingering` | `BossTelegraph.linger` | 장판이 그 초만큼 살고 0.5초마다 틱 |
| `ignites_ground_oil` | `_ignite_stage_boss_oil` | 남은 기름 장판을 태우고 그만큼 추가 피해 |
| `summon_count` / `_hp_ratio` / `_status` | `_spawn_stage_boss_summons` | B-3 분열체 3기(보스 최대 체력 × 12%, 독 보유) |
| `anim` | (미사용) | 시트 행은 `BOSS_SHEETS`가 정한다 — `anim` 키는 소비하지 않는다(§9 미결 3) |

---

## 3. 반격 창(RELOAD) 실측 — §3.2 표가 실기에서 성립하는가

패턴 데이터의 `reload` 합계 × 배율이 곧 반격 창이다(과열 0이므로 `1 + heat×HEAT_RELOAD = 1`).
`--boss-test`가 **A의 실측치와 이 식을 직접 대조**한다(`stage_reload=1.237 expected_reload=1.237`).

| 보스 | 칸 | 한 바퀴 지속 | 빚 합계 | 배율 | **반격 창** | 한 주기 | 창 비율 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A 서릿발 외눈 | 3 | 3.90s | 1.65 | 0.75 | **1.24s** | 5.14s | 24.1% |
| B 역병 점액왕 | 3 | 4.55s | 1.80 | 0.75 | **1.35s** | 5.90s | 22.9% |
| C 홍염 천구 | 3 | 3.70s | 1.46 | 0.75 | **1.10s** | 4.80s | 22.8% |
| B+ 흑점액 변종 | 4 | 6.40s | 2.60 | **0.55** | **1.43s** | 7.83s | **18.3%** |
| C+ 흑천구 | 4 | 5.70s | 2.28 | **0.55** | **1.25s** | 6.95s | **18.0%** |
| 마왕(회귀) | 5 | 덱 의존 | 덱 의존 | 0.60 | 1.29~2.01s(실측) | — | — |

**강화형에서 창 비율이 23% → 18%로 좁아진다** — §3.4가 지정한 "반격 창 축소"가
숫자로 실현됐다. 절대 길이는 오히려 조금 길지만(칸이 하나 더 늘어 빚이 커진다)
**한 주기당 무방비 시간의 몫**이 줄어드는 것이 설계 의도와 맞는다.

---

## 4. 페이즈 — 설계가 지정하지 않아 V7이 정한 것

§3.2 표는 **전환 횟수만** 준다(기본 1회 / 강화 2회). 무엇이 바뀌는지는 비어 있었다.

| 결정 | 값 | 근거 |
|---|---|---|
| 선딜 | `× 0.86^페이즈` | 보스가 빨라졌다는 것을 **플레이어가 손으로 느끼는** 유일한 축이 선딜이다. C+ 2페이즈면 0.74배 = 활공 참격 0.35 → 0.26초 |
| 피해 | `× 1.12^페이즈` | 체력이 줄수록 위험해지되 즉사는 안 나게. 2페이즈에서 ×1.25 |
| 새 패턴 추가 | **안 한다** | 칸 수(3/4)가 §3.2 표의 확정값이고 "레일에 칸이 하나 더 생긴다"가 강화형의 시각적 승급 신호다. 페이즈로 칸을 늘리면 그 신호가 무너진다 |
| 연출 | 발구름 + 링 파동 1회 + 화면 흔들림 + 배너 | 1회성. 트윈 루프 없음 |
| 표기 | 레일 밴드 "페이즈 n / N" · 보스 발밑 고리가 하나씩 늘어남 | 정적 |

---

## 5. 강림 안전 밸브 — "도망 다니면?"의 답

설계 §6.6이 지정한 넷을 그대로 구현했다.

| 규칙 | 구현 |
|---|---|
| 프리뷰 없음 | `_begin_stage_boss_descent()`가 프리뷰를 건너뛰고 `state`를 `"playing"`에 **둔 채** 보스를 세운다 |
| 칸 +1 (A도 4칸) | `BossLibrary.slot_count(enhanced, descended=true)` |
| HP ×1.15 | `BossLibrary.hp_for(..., descended=true)` |
| 등급 C 고정 | `clock.mark_descended()` → `demon_lord.victory_grade(day, true) == "C"` |

**도망칠 곳이 없다** — 세 가지가 함께 작동한다:

1. `enemy._physics_process`의 거리 디스폰(1,650px)은 `if not is_boss` 가드가 걸려 있다.
   보스는 맵 끝까지 따라온다(`--boss-test`가 플레이어를 4,000px 밖으로 순간이동시켜 단언한다).
2. `is_boss`는 항상 `move_direction = 플레이어 방향`이다(배회·도주 분기를 안 탄다).
3. **필드를 비우지 않는다.** 아레나 전투는 잡몹을 전멸시키지만 강림은 그대로 둔다 —
   보스와 밤 물량을 동시에 상대하는 것이 밸브의 압박이다(설계 §2.1의 필드 사건).

보스가 필드에서 자기 사이클을 돌리려면 `can_cycle_run(true)`가 `playing`에서 열려야 한다.
전조(W4)가 이미 뚫어 둔 자리에 절 하나를 더했다(§8의 무접촉 원칙 안에서 game.gd 내부다).

---

## 6. 마왕전 진입 경로 — v2의 셋에서 **하나**로

| v2 경로 | v3에서 |
|---|---|
| 마왕성 랜드마크에서 `E` | **삭제.** `world_grid`가 `demon_castle` feature를 만들지 않는다(V5). `_refresh_interactable` / `_interact_with_world`의 `"demon_castle"` 분기 2줄을 지웠다 |
| 7일차 밤 끝의 마왕 강림 (`_trigger_descent`) | **삭제.** V4가 스케줄을, V5가 시그널 연결을 지워 호출부 0이던 죽은 함수(30줄)를 제거했다 |
| 자발적 도전 | **유일 경로로 승격.** `_challenge_demon_king()`의 호출자는 이제 `on_stage_boss_defeated()`의 5스테이지 분기 하나뿐이다 |

**밸브는 마왕전의 두 번째 경로가 아니다.** 밸브는 *그 스테이지의* 보스를 부르는 장치이고,
5스테이지에서 밸브를 밟으면 C+를 잡은 뒤 **같은 콜백**으로 마왕전에 들어간다.
즉 입구가 둘(문 / 강림)이고 경로는 하나다.

**필드 복귀 0프레임**: `_on_stage_started()`에 이미 있던 `clock.is_run_complete()` 가드가
월드 재생성을 막고, `_challenge_demon_king()`은 `call_deferred`로 같은 프레임 끝에 붙는다.
`--boss-test`가 `world.get_stage()`가 안 바뀌었음을 단언한다.

---

## 7. `eclipse_* → blight_*` 개명 (V5가 V7에 넘긴 부채)

| 구 이름 | 새 이름 |
|---|---|
| `eclipse_active` / `eclipse_marked` / `eclipse_sweep_timer` | `blight_active` / `blight_marked` / `blight_sweep_timer` |
| `ECLIPSE_META = "eclipse_rune"` | `BLIGHT_META = "blight_rune"` |
| `_begin_eclipse` / `_sweep_eclipse` / `_apply_eclipse_to` / `eclipse_module_pool` | `_begin_blight` / `_sweep_blight` / `_apply_blight_to` / `blight_module_pool` |
| 스냅샷 키 `"eclipse_active"` / `"eclipse_marked"` | `"blight_active"` / `"blight_marked"` (**구 키를 폴백으로 읽는다** — V6 이전 저장이 잠식을 안 잃는다) |
| `_on_clock_milestone("eclipse", …)` | `_on_clock_milestone(StageClock.MILESTONE_BLIGHT, …)` |

`test_runner.gd` 참조 16곳도 함께 갈았고 `--save-test` 지문 키 `"eclipse"`도 `"blight"`가 됐다.
**남은 구 어휘는 `GameTuning.ECLIPSE_*` 상수 6개뿐이다** — 그 파일은 V10 소유이고 값이지
식별자가 아니라 급하지 않다. `--boss-test` ⑨가 개명 회귀를 상시 감시한다.

---

## 8. 무접촉 원칙을 깬 3곳 — `combat_resolver.gd` (보고)

지시서가 "시그니처 확장 필요 시 최소 + 보고"로 허용한 범위 안에서 셋을 고쳤다.

### 8.1 투사체 setup 인자 이관 (지시 항목 6 · handoff-v6 §11 미결 3)

```gdscript
# 전(V6): body_entered에 **먼저** 연결해 실행 순서를 확보 — "연결 순서 의존" 암묵 계약
projectile.setup(game, direction, ..., travel_range)
if not card.is_empty() and not card_element(card).is_empty():
	projectile.body_entered.connect(_on_projectile_status_hit.bind(projectile, card))
game.gameplay_root.add_child(projectile)

# 후(V7): setup 인자로 넘기고 projectile.gd가 자기 직격 피해 **앞에서** 부른다
var status_card: Dictionary = card if (not card.is_empty() and not card_element(card).is_empty()) else {}
projectile.setup(game, direction, ..., travel_range, status_card)
game.gameplay_root.add_child(projectile)
```

`_on_projectile_status_hit` → **`on_projectile_card_hit`** 로 개명(외부 호출자가 생겼다).
`projectile.gd`의 `_on_body_entered`가 **`hit_ids` 등록 전에** 부른다 — 창구가 같은
중복 규칙(`projectile.hit_ids`)을 스스로 확인하므로 먼저 등록하면 조기 반환한다.
이 순서가 새 계약이고 두 파일 주석에 못 박아 두었다.

### 8.2 스테이지 보스에게 상태이상을 허용 (2줄)

```gdscript
# strike_enemy_with_card()
var status_eligible := (not bool(target.get("is_boss"))) or bool(target.get("is_stage_boss"))
# _apply_card_status_to_enemy()
if bool(target.get("is_boss")) and not bool(target.get("is_stage_boss")):
```

**왜 열었나.** §3.3 C의 교육 목표가 *"플레이어가 3스테이지에서 당한 유→화 콤보를
5스테이지에서는 자기 5칸으로 되갚는 구조"* 이고 되갚을 대상이 곧 C+다. 보스에서만
원소 레이어가 꺼지면 설계 §4 전체가 필드 잡몹 전용 장식이 된다.
**마왕은 종전대로 면역이다**(v2 회귀 0). `_run_status_aoe/chain/spread`는 여전히
`other.is_boss`로 보스를 거르므로 광역·전이가 보스를 **연쇄로** 물지는 않는다.

⚠️ V10 밸런스 주의: 대폭 연소 ×2.2 + 도트가 2,600~3,800 HP 보스에 그대로 들어간다.
전투 길이 목표 45~90초를 볼 때 **여기가 가장 큰 변수**다.

---

## 9. 설계에 없어서 정한 것 (조정 + 근거) — 8건

| # | 항목 | 결정 | 근거 |
|---|---|---|---|
| 1 | 패턴 피해 환산 | `damage × (2.0 + day×0.18) × stage_damage_base × 페이즈배율` | 마왕 식(`2.4 + d×(2+day×0.18)`)과 자릿수를 맞추되 **하한 2.4를 뺐다** — C-1 기름 날개(damage 0.25)는 §4.3대로 "그 자체로는 아프지 않아야" 한다. dwell 항은 넣지 않았다(HP와 같은 논리: 두 번 벌하지 않는다) |
| 2 | 보스 이동 속도 / 접촉 피해 | `68 + 5×(stage−1)` / `(11 + 3×(stage−1)) × stage_damage_base` | 설계 무언급. 플레이어 238의 30% 이하로 두어 **거리를 벌 수는 있되 무한 카이팅은 안 되는** 값 |
| 3 | 히트박스 반경 | A 38 / B·B+ 40 / C·C+ 48 / 마왕 58 | handoff-v3-assets §2 권장값 그대로. **`BOSS_SHEETS` 표에 셀 크기와 함께 실었다** — 두 값이 갈라지면 발밑이 어긋난다 |
| 4 | 잔류 장판 틱 | 0.5초마다 패턴 피해 × 0.28 | 8초 장판이 총 4.5배 피해가 된다. 서 있으면 죽지만 한 틱은 견딜 수 있는 값 |
| 5 | 분열체(B-3) | `split_child=true`로 스폰 → **경험치 0** | 분열체를 잡아 파밍하는 무한 루프를 막는다(V6이 `recursion` 분열에서 세운 규칙과 같은 판단) |
| 6 | 강림 시 필드 | **비우지 않는다** | §5 참조. 아레나 전투만 비운다 |
| 7 | 플레이어 도트 적용 | 0.6초로 모아서 1회 + **무적 시간 원복** | `player.take_damage()`가 피격마다 0.68초 무적을 준다. 초당 4회 도트를 그대로 흘리면 **불붙은 플레이어가 보스 패턴에 거의 무적이 된다.** 대시·스폰 무적은 그대로 도트를 막는다 |
| 8 | 강림 중 나침반 | 숨긴다(보스 레일 밴드와 자리 경쟁) | 레일 밴드가 뜨는 동안은 목적지가 하나뿐이다. 재검토 여지 있음(§11 #5) |

### 9.1 설계와 다르게 구현한 것

**없다.** §3.1~§3.5와 §6.6은 전부 표기 그대로다. 위 8건은 설계가 말하지 않은 빈칸이다.

---

## 10. 테스트

### 10.1 `--boss-test` 전면 재작성 — 9묶음

크래시 2곳(handoff-v4 §301이 지목)의 처리:

| 크래시 | 처리 |
|---|---|
| 구 `:1661-1665` "7일차 밤 끝 → 강림" 트리거 → `boss_cycle` null → `reset_cycle()` 하드 크래시 → **180초 타임아웃** | **삭제.** v3에 마왕 강림 경로 자체가 없다. 마왕전은 ⑦에서 `_challenge_demon_king()` 직접 호출로 연다 |
| 구 `:1687` `(1 + BOSS_HP_DAY_STEP × (TOTAL_DAYS − 1)) × DESCENT_HP_MUL` v2 공식 하드코딩 | **삭제.** `demon_lord.hp_multiplier(day)` **함수 자체**와 기준 개체(`DebtEnemy.new()`)를 대조한다. → `GameTuning.BOSS_HP_DAY_STEP` / `TOTAL_DAYS` 참조가 사라졌으므로 **V10이 그 두 상수를 지울 수 있다**(handoff-v4 §217의 "V7이 지울 것"이 여기서 끝났다) |

| 묶음 | 무엇을 단언하나 |
|---|---|
| `rotation` | 로테이션 [A,B,C,B+,C+] · 리그→시트 매핑 5벌 · 칸 수 3/4/(+1) · RELOAD 0.75/0.55 · 페이즈 1/2 · **함정 3건**(A는 `attack` 빈 배열 · 점액 walk==attack · foot_inset 14/12/48/0) · C+만 `intro_anim` |
| `battle_e2e` | 프리뷰 두 레일(5+3)·스크롤 0·취소 가능 → 전투 진입 → 시트 키·페이즈 임계·HP 식 일치 · **각인 0 · uses_runes/uses_heat false** · 궤적이 3칸 안 · **RELOAD 창 실측 == 빚×0.75** · 레일 밴드 3칸·과열 사다리 숨김 · **패턴이 실제로 플레이어에게 상태를 붙인다** |
| `enhanced` | B+ 칸 4 · 시트 `black_slime` · RELOAD 0.55 · 상태 2종 · HP에 dwell 항 · 레일 4칸 · **페이즈 66%→33% 2회** |
| `defeat` | 격파 → `clock.stage +1` · `stages_cleared +1` · 트로피 훅 채워짐 · 완전 회복 · 월드 재생성 · 노드·HUD·플레이어 상태 원복 |
| `demon_direct` | C+ 등장 연출 재생 중 · 격파 → `is_run_complete` · **월드 재생성 없음** · 마왕 프리뷰(`BossPreviewPanel`)가 열림 |
| `valve` | dwell 임계 → `_process` 폴링이 스스로 강림 · 프리뷰 없음 · 칸 +1 · HP ×1.15 · 필드에서 사이클 구동 · **4,000px 도주에도 생존** · 격파 후 등급 C 고정 |
| `demon_king` | 상위 5장 선별 + 각인 · 프리뷰 두 레일 · **HP 배율이 실제 체력에** · needle == `simulate_cycle` · RELOAD ×0.6 실재 · 레일 5칸·과열 8단 복귀 |
| `telegraph` | 링 노드 실재(peak > 0) · 조건부 배율 데이터 · **강화형 telegraph ×0.85 전수 대조** · 보조 상태 파생 |
| `phase` | 기본형은 50%에서 정확히 1회(20%로 더 내려도 안 늘어난다) · 피해/선딜 배율 갱신 |
| `blight` | 개명 회귀 — `blight_module_pool` / `_on_clock_milestone(MILESTONE_BLIGHT)` / `BLIGHT_META == "blight_rune"` / 이중 스윕 0 |

실측 출력:
```
BOSS_TEST_COMPLETE rotation=true battle_e2e=true enhanced=true defeat=true demon_direct=true
  valve=true demon_king=true telegraph=true phase=true blight=true
  stage_reload=1.237 expected_reload=1.237 demon_reload=1.287
  telegraphs=9 phase_shifts=3 bosses=1 blight_marked=6 steps=5
```

### 10.2 `--v4-test` 가산 (설계 부록 B V7 검증란)

`boss_runtime` 판정에 **칸 수 세 층의 경계선**을 넣었다:
`STAGE_BOSS_SLOT_COUNT(3) < _ENHANCED(4) < BOSS_SLOT_COUNT(5)` +
`BossLibrary.resolve("C", true)`의 `uses_runes` / `uses_heat`가 둘 다 false.
**5칸 + 각인 + 과열은 마왕만 가진다**(부록 A-2 ⑫)가 회귀 감시 대상이 됐다.

### 10.3 `run_all.sh`

`--boss-test` 줄의 주석을 풀었다(V5가 남긴 임시 제외 해제). **14종 전부 PASS · 76초.**

```
compile world-test v4-test castle-test rift-test stress-test smoke-test combat-test
stage-test status-test cycle-test draft-test boss-test save-test
```

### 10.4 `--capture-boss` 재작성 — 9컷 (육안 확인 결과)

| 파일 | 확인한 것 |
|---|---|
| `boss-minimal-v2-preview.png` | 내 5칸 vs **보스 3칸**. 보스 카드가 "선딜 0.55초 · 빙 파동"과 자기 지속/RELOAD를 보여 준다(라이브러리 되읽기 버그 수정 후) |
| `boss-minimal-v2-a.png` | 서릿발 외눈이 **청록**으로 아레나 중심에 접지. 레일 3칸 · "각인 없음 · 과열 없음 · 페이즈 0/1" · "반격 창 0.41초 (×0.75)" |
| `boss-minimal-v2-telegraph.png` | 링 3행이 나란히 — expand(청) / charge(황) / pool(녹)이 실루엣으로 구분된다 |
| `boss-minimal-v2-b.png` | 역병 점액왕 + 분열체 3기 + 독 장판 3개. 플레이어 상태 "독"이 패널에 뜬다 |
| `boss-minimal-v2-c-trans.png` | **C+ 흑천구 Trans 11프레임 등장 연출 중간 프레임**. 보스문 아치와 붉은 뿔탑이 뒤에 |
| `boss-minimal-v2-enhanced.png` | 레일 **4칸**(기름 날개/활공 참격/화염 강하/흑염 회오리) · 과열 사다리 **숨김** · RELOAD ×0.55 · 플레이어 상태 "연 · 유" |
| `boss-minimal-v2-reload.png` | 반격 창이 초록으로 열린 순간 · 바늘 숨김 · "지금 때려라" |
| `boss-minimal-v2-demon.png` | 5스테이지 격파 **직후** 마왕 프리뷰가 그대로 열린다(필드 복귀 0프레임) |
| `boss-minimal-v2-descent.png` | 강림 — 프리뷰 없이 필드에 내려선 4칸 보스 · 필드가 비어 있지 않다 · HUD "강림 진행 중 · 등급 C 고정" |

> 캡처 준비 함수 `_boss_capture_freeze()`를 새로 뒀다. **피격 섬광(흰 마스크 α0.7)이 덮으면
> 시트 색이 안 읽힌다** — 첫 캡처에서 청록 외눈이 흰 덩어리로 나왔다. 육안 검수의 목적이
> "외눈이 청록인가 / 천구가 붉은가"이므로 캡처 직전에 트리를 멈추고 섬광을 0으로 내린다.

`--capture-world` 회귀 없음(9컷 전부 V5 기준선과 같다).

---

## 11. V8 · V9 · V10이 바로 알아야 할 것

### V8 (성장 재편 · 결과 화면)

1. **트로피 2택1의 훅은 이미 있다.** 격파 시 `pending_stage_trophy`가 채워진다:
   ```gdscript
   {"stage": int, "design": "A"/"B"/"C", "enhanced": bool, "descended": bool, "day": int, "dwell": int}
   ```
   `on_stage_boss_defeated()`의 `_show_banner("... [V8 예정] 트로피 카드 2택1 ...")` 자리에
   모달을 띄우고 끝에 `pending_stage_trophy.clear()`만 하면 된다.
   ⚠️ `advance_stage()`가 **같은 함수에서 바로 이어진다** — 모달을 띄우려면 전환을
   모달 종료 콜백으로 미뤄야 한다(지금은 회복 → 전환이 즉시다).
2. 결과 화면 지표로 쓸 것: `stage_bosses_defeated` · `boss_reload_windows` ·
   `stage_boss_phase_shifts` · `stage_boss_telegraphs` · `clock.descended`(등급 C).
3. `_show_result`의 7일 타임라인은 **아직 v2 그대로다**(`GameTuning.TOTAL_DAYS`).
   V7의 `--boss-test`는 결과 화면을 더 이상 보지 않으므로(그 묶음 삭제) 자유롭게 갈아도 된다.

### V9 (저장 schema 3)

4. 스냅샷에 **`stage_boss_cleared` 1키를 가산**했다(복원도 짝을 맞췄다).
   `blight_active` / `blight_marked`는 개명됐고 **구 키를 폴백으로 읽는다** — schema 3에서
   폴백을 지울지 판단할 것.
5. **전투 중 저장은 고려하지 않았다.** `stage_boss` / `stage_boss_cycle` / `player_status` /
   `stage_boss_pools`는 저장되지 않는다. 보스전 도중 이어하기를 지원할 생각이면
   "보스방 앞 필드로 되돌린다"가 가장 싸다(`stage_boss_cleared = false`로 두면 문이 다시 열린다).

### V10 (통합 · 밸런스 · 문서)

6. **전투 길이(목표 45~90초) 미측정.** `BossLibrary.DESIGN_HP`(2600/3200/3800)는 V2가
   "자릿수만 맞춘 뼈대"로 둔 값이고 V7도 안 건드렸다. §8.2로 원소 시너지가 보스에
   들어가게 됐으므로 실측 없이는 예측이 안 된다. `balance_probe` 확장이 필요하다.
7. `STAGE_BOSS_DAMAGE_PER_POINT`(2.0) / `_DAY_STEP`(0.18) / `_SPEED_BASE`(68) /
   `_CONTACT_BASE`(11) / `_PHASE_DAMAGE_MUL`(1.12) / `_PHASE_TELEGRAPH_MUL`(0.86)은
   **game.gd 상단 상수**다. 밸런스 손잡이이므로 `tuning.gd`로 옮기는 것이 옳다(V7은 그 파일을 못 열었다).
8. `GameTuning.BOSS_HP_DAY_STEP` / `TOTAL_DAYS`의 마지막 참조가 사라졌다 — **이제 지울 수 있다**(§10.1).
9. `GameTuning.ECLIPSE_*` 6개도 `BLIGHT_*`로 개명 가능(식별자 개명은 V7이 끝냈고 상수만 남았다).
10. `_trigger_boss_cycle_pulse()`의 `match`에 `_:` 기본 분기를 **추가하지 말 것**(§2.3의 경고).

---

## 12. 남은 위험 / 미결

| # | 내용 | 크기 | 누가 |
|---|---|---|---|
| 1 | **보스 전투 길이 미검증.** HP도 피해도 뼈대 값이고 원소 시너지가 새로 물렸다 | 대 | V10 |
| 2 | 플레이어 도트가 무적 시간을 **원복**하는 방식이라 방패(shield_charges)는 도트에 소모된다. "독 한 틱이 방패를 먹는다"가 의도인지 판정 필요 | 소 | V10 |
| 3 | `boss_library.PATTERNS`의 `anim` 키(B-1 `jump`, C-2 `attack`)를 **소비하지 않는다.** 시트 행은 `BOSS_SHEETS`가 정하고 `trigger_boss_attack_anim()`이 리그의 `attack` 행만 본다. 점액은 walk==attack이라 결과가 같지만 데이터가 죽어 있다 | 소 | V10 |
| 4 | 선형 패턴(A-3 뇌격 · C-2 활공)의 판정은 **선분 최단거리 ≤ 반경×0.6 + 20**이다. 관통·다단(hits 2)이 선분 위 여러 지점을 때리지는 않는다 | 소 | V10 |
| 5 | 강림 중 나침반·고스트 레일이 숨는다(레일 밴드와 같은 규칙). 필드 사건이라 나침반이 살아 있는 편이 나을 수 있다 | 소 | V10 육안 |
| 6 | 보스는 `apply_cycle_slow`가 여전히 no-op이다(`enemy.gd`의 v2 가드). 한(chill)은 걸리지만 v2 slow 카드는 안 걸린다 — 두 자원의 취급이 갈린다 | 소 | V10 판정 |
| 7 | 전투 중 플레이어 사망 시 보스 노드가 트리에 남는다(`_finish_run`이 트리를 멈추고 재시작이 `_begin_run`에서 정리한다). 결과 화면 뒤에서 보스가 보일 수 있다 | 소 | V8 |
| 8 | `--capture-boss`의 강림 컷은 `set_stage_raw(3)`만 하고 월드를 다시 세우지 않아 지형이 1스테이지다(연출 검수용이라 무해) | 소 | — |
| 9 | `AGENTS.md` §1 체크포인트를 갱신하지 않았다(지시서가 수정 금지) | 소 | V10 |
