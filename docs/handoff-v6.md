# handoff-v6 — 원소 상태이상 전투 통합 (L2 실전 배선)

> 웨이브 **V6** (설계 `docs/GAME_DESIGN_V3.md` §4 전체 · 부록 B의 V6). 2026-08-09.
> **읽는 사람: V7(보스) · V8(성장·결과) · V9(저장) · V10(정리·밸런스).**
> 한 줄 요약: **`StatusEngine`(V1)이 순수 규칙으로만 있던 상태에서 실제 전투에 배선됐다.
> 카드를 꽂으면 상태가 붙고, 매트릭스 42칸이 실기에서 터지며, 78기 상태 만연에서
> fps 저하가 측정 한계 이하(0±0.5%)다.**

| | |
|---|---|
| 소유·수정 | `scripts/enemy.gd` · `scripts/core/combat_resolver.gd` · `scripts/game.gd`(HUD·VFX·L1 다리 구역) · `scripts/core/tuning.gd`(**상수 1개 추가**) · `scripts/test/test_runner.gd` · 이 문서 |
| 무접촉 | `core/status_engine.gd`(버그 0건 — 한 글자도 안 고쳤다) · `core/rune_engine.gd` · `core/stage_clock.gd` · `core/demon_lord.gd` · `world_grid.gd` · `projectile.gd` · `cycle_skill_effect.gd` · `deal_cycle_controller.gd` · 라이브러리 전부 · `art/` · `run_all.sh` · `AGENTS.md` |
| 아카이브 | `docs/v1-archive/enemy_v2.gd.txt` · `docs/v1-archive/combat_resolver_v2.gd.txt` (수정 직전 원본) |
| 검증 | `--editor --quit` 오류 0 · `run_all.sh` **13종 전부 PASS**(`--boss-test`는 V5가 남긴 임시 제외 그대로) · 캡처 육안 |

---

## 0. 이 웨이브가 실제로 한 것

| # | 항목 | 결과 |
|---|---|---|
| ① | 상태 부여·반응 실전 배선 | 근접·투사체·연쇄·광역·수호 **5경로 전부**. 이벤트 6종 집행 |
| ② | `enemy.gd` 상태 보유·틱·핍 | 11칸 배열 · 기존 타이머 블록에 `tick_dot` 얹기 · `source` 인자 · 핍 · 마스크 틴트 |
| ③ | 시너지 VFX·라벨 | `vfx-synergy.png` 5행 + 부유 라벨 11종. 트윈 0 |
| ④ | V5 인계 2건 + 훅 ③ | 스테이지 배율 정식 이관(**임시 우회로 삭제 확인**) · 몹 티어 스테이지 배선 · 물량 3함수 dwell화 |
| ⑤ | V4 인계 1건 | `enemy.gd`의 마왕 기저 HP → `DemonLord.boss_base_health()` (부채 상한 45 실전 적용) |
| ⑥ | 전역 킬 체인 깊이 가드 | `GameTuning.STATUS_KILL_CHAIN_DEPTH_MAX = 3` (근거 §5) |
| ⑦ | 레일 원소 마크 7종 | v2 어휘(광·혈·철)로 남아 독·유·타·초 **16장이 빈 마크**였던 회귀 수정 |
| ⑧ | 테스트 | `--combat-test`에 통합 6묶음 신설 · `--stress-test`를 상태 활성 3구간 측정으로 재작성 |

---

## 1. 통합 지점 목록 (파일:함수)

### 1.1 `core/combat_resolver.gd` — 집행자

| 함수 | 하는 일 |
|---|---|
| `strike_enemy_with_card(target, card, damage, center) -> float` | **카드 한 방이 적에게 들어가는 유일한 창구.** 증폭 → 매트릭스 → 직격 → 이벤트. 반환은 실제로 들어간 피해(흡혈이 먹는다) |
| `card_element(card)` | 카드 원소(인스턴스에 태그가 없으면 정의를 되읽는다) |
| `card_status_power(card)` | 카드가 정하는 상태 세기. **지금은 항상 1.0** — 채널만 뚫려 있다(§7 미결 1) |
| `status_range_bonus(center, radius, card)` | 증기의 범위 +50%를 **타격 전에** `preview()`로 묻는다 |
| `_apply_card_status_to_enemy(target, card, center, result, damage)` | 넉백 합산(쇄빙 ×2 · L1 경직 +0.2) → 이벤트 집행 → v2의 slow/pull |
| `_run_status_events(...)` | 이벤트 6종 분배 + `suppressed` 누적 + 반응 라벨 |
| `_run_status_aoe / _run_status_chain / _run_status_spread` | 역병 발화·감전 유막 / ★전도 / ★대폭 연소 기름 전파 |
| `_announce_reactions(...)` | 시너지 버스트 + 부유 라벨(프레임당 라벨 4장 상한) |
| `_on_projectile_status_hit(body, projectile, card)` | **투사체 경로.** `projectile.gd` 무수정 — `body_entered`에 먼저 붙는다(§2.3) |
| `begin_status_frame()` | 프레임 예산 되감기 · 킬 체인 깊이 0 · 라벨 카운터 0 · 예산 peak 기록 |
| `apply_stage_scaling(enemy)` | 스테이지 기저 배율의 **유일한** 적용 지점(V5 스윕 이관) |
| `enemy_defeated / _enemy_defeated_body` | 전역 킬 체인 깊이 가드 |
| `current_spawn_interval / current_enemy_limit / night_raid_burst_count` | v2의 `cycle_number` → **dwell 축**(handoff-v5 훅 ③) |
| `maintain_field_population / spawn_enemy_instance` | `MonsterLibrary.roll` → **`roll_for_stage`**(handoff-v5 §6.1) |

호출부(v2에서 `take_damage` + `_apply_card_status_to_enemy` 2줄이던 자리):
`apply_cycle_melee` · `trigger_cycle_card_pulse`의 `chain` / `area·orbit·ground` / `shield`.

### 1.2 `enemy.gd` — 보유자

| 지점 | 하는 일 |
|---|---|
| `var st_state` (선언부) | `StatusEngine.make_state()` — **1기당 한 번**. 참조 타입이라 제자리 갱신 |
| `_physics_process` 타이머 블록 (`cycle_slow_timer` 바로 뒤) | `tick_dot()` 1줄 + `if dot > 0` 일 때만 `take_damage(..., SOURCE_DOT)` |
| `_physics_process` 이동 | `current_speed *= StatusEngine.move_multiplier(st_state)` |
| `take_damage(..., source)` | **5번째 인자.** `SOURCE_DOT`이면 `provoke()`·피격 섬광 우회 |
| `_die()` | `StatusEngine.clear(st_state)` |
| `_draw_field_monster()` | 4단 틴트 뒤에 **우세 상태 마스크 틴트** 1줄 |
| `_draw_status_pips()` | 머리 위 핍(별도 루프 · y=-radius-32 · 정적) |
| `setup()` 보스 분기 | `DemonLord.boss_base_health()` 호출로 교체 |

### 1.3 `game.gd` — HUD·VFX·L1 다리

| 지점 | 하는 일 |
|---|---|
| `_process` | `combat.begin_status_frame()` 1줄 (**`_sweep_stage_scaling()` 삭제**) |
| `current_cycle_step / current_cycle_potency / current_cycle_stun_bonus` | **L1→L2를 잇는 유일한 통로.** `step_record["potency"]`/`["stun_bonus"]`를 실행 중인 스텝에서 되읽는다 |
| `class SynergyBurst` · `spawn_synergy_effect` · `synergy_label_color` | 시너지 1회성 버스트(트윈 0 · `MAX_TRANSIENT_EFFECTS` 공유) |
| `RAIL_ELEMENT_MARK` | 6종 → **7종**(화빙뇌독유타초) |
| `spawn_player_projectile` 래퍼 | `card` 인자 1개 추가(기본값 `{}`) |

### 1.4 `core/tuning.gd`

`STATUS_KILL_CHAIN_DEPTH_MAX = 3` **한 줄만** 추가했다(V0이 "V6이 정한다"로 비워 둔 자리).
V3-M 블록 안이고, V0 머리주석의 "설계에 수치가 없어 선언하지 못한 것" 2번 항목을
✅로 갱신했다.

---

## 2. 호출 순서 함정 5건 — 어떻게 처리했나

handoff-v1 §5.2가 경고한 다섯 개다. 전부 `strike_enemy_with_card()` 한 함수 안에 있다.

### 2.1 기름 소모 **전에** `incoming_multiplier`
```gdscript
dealt *= StatusEngine.incoming_multiplier(target.st_state, element)   # ①
dealt *= StatusEngine.consume_shock(target.st_state)                  # ①
status_result = StatusEngine.apply(...)                               # ②  ← 여기서 기름이 탄다
target.take_damage(dealt, center)                                     # ③
```
`--combat-test`의 `blaze_live`가 `oil_mul=2.2000`으로 실측 단언한다.

### 2.2 **매트릭스를 직격 피해보다 앞에** 둔 것 (설계에 없던 판단)
v2 호출부는 `take_damage` → `_apply_card_status_to_enemy` 순이었다. 그대로 두면
**마지막 일격으로 죽은 적에게서 역병 발화·대폭 연소가 아예 안 터진다.** 비원소 2종이
"상태를 거둬들이는 마무리 칸"이라는 §4.4 설계 의도 1은 마무리 일격일수록 터져야
성립하므로, 순서를 뒤집으면 의도가 가장 필요한 순간에만 사라진다. 그래서 ②를 ③ 앞으로 옮겼다.

### 2.3 `spread` 깊이 인자
`_run_status_spread()`가 `event["depth"]`를 그대로 `ctx["depth"]`로 되넘긴다.
`--combat-test`의 `budget_guard`가 `status_max_depth_seen == 1`을 단언한다 —
**0이면 깊이 인자를 안 넘긴 것**이므로 이 한 줄이 함정을 정확히 잡는다.

### 2.4 `chain_damage` 단일 식
`_run_status_chain()`은 감쇠식을 자체 구현하지 않고 `StatusEngine.chain_damage(event, hop)`만 부른다.
`--combat-test`의 `conduction`이 실측 피해 4개를 **같은 함수 반환값과** 대조한다.

### 2.5 증기 `range_bonus` 선반영
`status_range_bonus()`가 타격 **전에** `preview()`로 묻고 반경에 곱한다.
`apply()`가 사후에 내는 `E_RANGE_BONUS` 이벤트는 이벤트 루프에서 **의도적으로 무시**한다
(주석 명시 — 둘 다 먹이면 범위가 ×2.25가 된다).

---

## 3. 성능 실측 (설계 §4.7 완료 기준 "fps 저하 10% 이내")

`--stress-test`를 **3구간 비교 측정**으로 재작성했다. 절대 fps는 기기마다 다르지만
세 값의 비율은 이 코드가 만든 비용이므로 회귀 감시에 쓸 수 있다.

| 구간 | 조건 | fps (4회 실측 평균) |
|---|---|---:|
| A 청정 | 마물 104기 · 상태 0건 | **144.4** |
| B 만연 | 104기 전원 독(스택3)+연, 절반 한, 1/3 유 | **144.5** |
| C 폭풍 | B + 화염/뇌 광역 펄스(반응 예산이 실제로 물린다) | **141.1** |

* **상태 만연의 fps 저하 = 0.0 ~ +0.5% (측정 오차 이내).** 목표 10%를 두 자릿수로 통과한다.
* 반응 폭풍까지 켜도 **−2.3%**.
* v2 기준선(수정 전 `--stress-test`, 같은 기기 3회) = **145** → 구간 A와 동일하다.

| 지표 | 실측 |
|---|---|
| 도트 틱 | **1,662회 / 6초** (104기 × 4회/초 × ≈4초 = 이론치와 일치. 규칙 2의 0.25초 버퍼가 실제로 물린다) |
| 반응 발동 | 765 ~ 818회 |
| **반응 예산 초과** | **0건.** `budget_peak = 24 = cap` (한 프레임도 24를 넘지 않았다) |
| 예산 포화 프레임 | 4프레임(= 광역 펄스 4회). 그 프레임에서 질의 이벤트 257~288개가 억제됐다 |
| 전파 깊이 최대 | **1** (= `STATUS_PROPAGATION_DEPTH`) |
| 킬 체인 깊이 최대 | **0~1** (상한 3에 한참 못 미친다 — 가드는 여유 있게 열려 있다) |

**예산 히트율 해석**: 78기 밤에 화염 광역 한 방이면 질의 이벤트 요청이 **프레임당 130개**
수준까지 뛴다(독 걸린 적마다 역병 발화 1 + 기름 적마다 전파 1). 예산 24는 그중 18%만
통과시킨다. 이게 설계 의도다 — `StatusEngine._emit()`이 **질의 이벤트만** 자르고 상태
수치는 절대 안 건드리므로, 예산이 바닥나도 대폭 연소의 연 지속은 5.0초 그대로다
(`--combat-test`의 `budget_guard`가 이것까지 단언한다).

---

## 4. 이중 적용 검증 (V5 인계 ①)

| 확인 | 결과 |
|---|---|
| `grep -rn "STAGE_SCALE_META\|_sweep_stage_scaling\|_apply_stage_scaling_to" godot-game/` | **실행 코드 0건** (남은 것은 전부 주석과 `has_method()` 회귀 단언) |
| `game.gd:_process`의 스윕 호출 | 삭제 |
| `--combat-test` `stage_scale` | 스테이지 1 dwell 0 → 다섯 배율이 **정확히 1.0** · 마물 HP == `MonsterLibrary.health_for()` 원값 (= v2 등가) |
| 같은 판정 | 스테이지 3 dwell 4 → HP == 라이브러리값 × 배율 **1회분**, 제곱이 아님을 명시 단언 |
| `--stage-test` `stage_pipe` ⑥ | 메타 표식 세기를 **라이브러리 기저값 × 배율 대조**로 교체 |

### 4.1 이관하면서 바뀐 것 3가지 (전부 개선 방향)

1. **적용 시점**: 스폰 다음 프레임 폴링 → `spawn_enemy_instance()` 안에서 **1기당 정확히 1회**.
   V5가 "체력을 `max_health`로 되돌리지 말 것"이라고 경고한 함정(`--v4-test` `live_direction`이
   6회 중 1회 실패)은 **여기서는 존재하지 않는다** — `add_child` 전이라 지울 피해가 없다.
2. **적용 위치**: `setup()` 직후 / `force_module`·`mark_trial` **앞**. 검은 갑주(방패 = max_health
   비율)와 균열 정예 ×3이 배율이 걸린 체력 위에서 계산된다.
3. **분열체 경험치**: V5 스윕은 `maxi(1, ...)`이라 xp 0짜리 분열체에 1을 줬다.
   `if xp_value > 0` 가드를 넣어 0은 0으로 남긴다(무한 분열 파밍 방지 규칙 복원).

---

## 5. 전역 킬 체인 깊이 상한 — **3** (근거)

`GameTuning.STATUS_KILL_CHAIN_DEPTH_MAX = 3`.

**왜 필요한가.** 도트로 죽은 적도 `_die()` → `enemy_defeated()`를 그대로 탄다. 그 안에서
성스러운 파동(반경 275 광역)과 뇌 연쇄(4~6체)가 터지고 그 피해가 또 적을 죽이면
**재귀로 다시 들어온다.** v2에는 파동 자기 자신만 막는 `hotfix_burst_running` 빗장뿐이라
파동→연쇄→파동 **교차 재귀는 열려 있었고**, v3는 도트가 0.25초마다 78기를 동시에
죽일 수 있어 그 구멍이 실제로 열린다.

**왜 3인가.** v2에서 실제로 도달 가능한 최대 깊이가 정확히 3이다:

```
1 카드/도트가 직접 처치  →  2 성스러운 파동이 처치  →  3 그 처치의 뇌 연쇄가 처치
```

3으로 자르면 **v2의 타격감을 1비트도 잃지 않으면서** 4단째부터의 눈덩이만 끊긴다.

| 후보 | 왜 아닌가 |
|---|---|
| 1 (= 상태 전파 깊이와 동일) | v2의 "파동이 적을 쓸어 담는" 연출이 통째로 사라진다. 이건 신규 기능이 아니라 기존 보상이다 |
| 2 | 뇌 연쇄가 파동 처치에 절대 못 붙어 체감이 달라진다 |
| **3** | v2 도달 가능 최대치와 정확히 같다 |
| 4+ | 파동 하나가 최대 78체를 때리므로 깊이 1당 이론 분기가 78배다. 밤 물량에서 폭발한다 |

**상한을 넘겨도 보상은 그대로 준다.** 경험치·골드·킬 카운트·트로피 경로는 언제나 실행하고
**2차 연출(파동·연쇄)만** 끊는다. 보상을 끊으면 게임 규칙이 프레임률에 종속되는데
그건 성능 보호가 아니다 — `StatusEngine._emit()`이 예산 고갈 때 상태 수치를 안 건드리는 것과
같은 판단이다. 억제 횟수는 `combat.kill_chain_suppressed`로 노출된다.

실측: 스트레스 조건에서도 관측된 최대 깊이는 **0~1**이다. 가드는 안전망이지 상시 작동 장치가 아니다.

---

## 6. 설계에 없어서 정한 것 (조정 + 근거) — 7건

| # | 항목 | 결정 | 근거 |
|---|---|---|---|
| 1 | 한(chill) 감속과 v2 `cycle_slow`의 합성 | **곱** (min 아님) | 서로 **다른 자원**이다. 빙 카드로 얼리고 slow 카드를 겹치는 것이 §4.6 빌드 ②의 의도인데 `min`이면 둘 중 하나가 통째로 무의미해진다. 두 배율 모두 하한이 있어(0.35 / 0.65) 곱해도 0.2275 밑으로 안 간다 |
| 2 | 보스에게 상태를 붙이는가 | **안 붙인다**(V6에서는) | `apply_cycle_slow`가 이미 보스 no-op이고, 보스 상태·페이즈는 부록 B가 **V7 소유**로 명시했다. `strike_enemy_with_card`의 `is_boss` 분기 한 곳만 열면 된다(§7 인계 1) |
| 3 | 도트의 피격 섬광 | **없음** | 초당 4회로 번쩍이면 상태 핍이 오히려 안 읽힌다. 도트 피드백은 핍 + 마스크 틴트가 맡는다 |
| 4 | 전이·전파의 **원점 제외** | 제외한다 | 전도는 "전이"이므로 1차 대상은 이미 직격을 맞았다. 기름 전파는 방금 대폭 연소로 태운 기름을 같은 프레임에 다시 바르면 소모가 무의미해진다 |
| 5 | 증기 `range_bonus`의 조회 대상 | 기저 반경 안에서 **한을 가진 적이 하나라도 있으면** 적용 | 범위는 대상별이 아니라 타격별 속성이다. `element == "fire"`일 때만 질의하므로 나머지 6원소에서는 `String` 비교 한 번이 전부다 |
| 6 | 시너지 부유 라벨 상한 | **프레임당 4장** (`combat_resolver.MAX_REACTION_LABELS_PER_FRAME`) | 밸런스가 아니라 가독성 가드라 `GameTuning`이 아니라 파일 안에 뒀다. 78기 밤에 광역 화염 한 방이면 "역병 발화!"가 수십 장 겹쳐 글자가 서로를 지운다(캡처 실측). **버스트는 안 자른다** — 이미 `MAX_TRANSIENT_EFFECTS`가 묶는다 |
| 7 | 투사체 경로의 쇄빙 넉백 | 카드 넉백 프로필 × (배율 − 1)을 **증분으로** 추가 | 투사체는 자기 `impact_force`를 스스로 내므로, 근접 경로의 "프로필 × 배율"과 총량이 같아지는 유일한 방법이다 |

### 6.1 설계와 다르게 구현한 것

**없다.** §4.4 매트릭스 42칸과 §4.7 성능 4규칙은 전부 표기 그대로다.
위 7건은 설계가 말하지 않은 빈칸이고, 6건은 각각 한 줄만 고치면 되도록 지점을 좁혀 두었다.

---

## 7. 투사체 경로 — `projectile.gd`를 안 고치고 배선한 방법

관통 계열 6장(`earth_splitter` 화 · `boomerang_blade` 유 · `targeting` 뇌 ·
`blade_fan` 초 · `recursion` 타)은 `TechProjectile`이 `body.take_damage()`를 **직접** 부른다.
`projectile.gd`는 V6 소유가 아니라 열 수 없었다.

```gdscript
# combat_resolver.spawn_player_projectile()
projectile.body_entered.connect(_on_projectile_status_hit.bind(projectile, card))
game.gameplay_root.add_child(projectile)   # ← _ready()가 자기 핸들러를 여기서 붙인다
```

**`add_child` 전에 연결하므로 투사체 자신의 `_on_body_entered`보다 먼저 실행된다**
(Godot 시그널 콜백은 연결 순서대로 불린다). 그래서 기름·전 표식을 `apply()`가 소모하기
전에 물을 수 있다. 중복 판정은 투사체의 `hit_ids`를 그대로 읽어 같은 규칙을 쓴다.

⚠️ **증폭분은 별도 타격으로 낸다.** `projectile.damage`에 곱해 두면 관통·도탄의
**다음 대상까지** 그 배율을 끌고 간다(기름 없는 적이 ×2.2를 맞는다).

> V10이 `projectile.gd`를 열 수 있게 되면 이 우회로를 `setup()`의 `card` 인자로 바꾸는 편이
> 읽기 쉽다. 지금 구조도 정확하지만 "연결 순서에 의존한다"는 암묵 계약이 하나 늘었다.

---

## 8. V5·V4 인계 처리 결과

| 인계 | 출처 | 처리 |
|---|---|---|
| 스테이지 배율 임시 스윕 | handoff-v5 §6 · 훅 ④ | ✅ `combat.apply_stage_scaling()`로 이관 · 임시 코드 3종 삭제 확인(§4) |
| 몹 스테이지 티어 배선 | handoff-v5 §6.1 | ✅ `maintain_field_population` · `spawn_enemy_instance` 둘 다 `roll_for_stage(rng, clock.stage, is_night)` |
| **물량 3함수** | handoff-v5 훅 ③ | ✅ **함께 처리했다.** `cycle_number`(총 일수) → `StageClock.*_at(dwell)`. §9 참조 |
| 마왕 기저 HP 이중 식 | handoff-v4 V3-I ② | ✅ `DemonLord.boss_base_health(debts, items, power)` 호출로 교체 |
| 전역 킬 체인 깊이 상한 | handoff-v1 §6 위험 3 | ✅ 3 (§5) |
| 증기 선반영 | handoff-v1 §6 위험 4 | ✅ `status_range_bonus()` |

### 8.1 물량 3함수를 함께 처리한 이유

지시 범위에는 2건만 있었지만 handoff-v5의 훅 표가 ③을 **V6 소유**로 명시했고,
같은 파일의 인접 3함수라 남겨 두면 다음 웨이브가 또 열어야 한다. 더 중요한 이유는
설계 V3-D가 **"`day`를 소비하는 것이 금지된다"**고 못 박은 지점이 정확히 이 셋이라는
것이다(v3에서 `day_number`는 상한 없는 기록 카운터가 됐다).

**동작 델타**: 1스테이지 dwell 0에서 낮 상한 30 → **27**, 밤 상한 34 → **30**, 밤 개시소환 5 → **3**.
dwell이 오르면 `min(d,6)`까지 따라 올라 d=6에서 낮 45 / 밤 48로 포화한다.
`--v4-test`의 `early_ranged_gate`(상한 ≤40 · 간격 ≥0.5 · 개시소환 ≤6)는 그대로 통과한다.
`game.is_night`을 밤 판정의 진실 원천으로 **유지**했다 — `clock.is_night`으로 바꾸면
낮/밤을 손으로 세팅하는 테스트 4종이 전부 어긋난다.

### 8.2 마왕 HP 변화

`enemy.gd:119`가 부채 상한 없이 22.0/장을 곱하고 있었다. 이제 `min(debts, 45)`가 걸린다.
부채 45장 이하인 런에서는 **1비트도 안 바뀌고**, 그 위에서만 눌린다.
`--boss-test`의 기준 개체 대조(`DebtEnemy.new()`)와 `balance_probe`가 이제 실기와 같은 함수를 본다.

---

## 9. 테스트

### 9.1 `--combat-test` — V6 통합 6묶음 (신설)

v2의 "12초 방치" 소크는 **그대로 남기고** 앞에 통합 검사를 붙였다.
검사 구간에는 `await`를 넣지 않는다 — 프레임이 안 넘어가므로 자연 스폰·평타가
측정 사이에 끼어들 수 없다(전부 델타 측정). 시작 시 필드를 비우고
`spawn_timer`를 잠근 뒤 끝에서 되돌린다.

| 묶음 | 무엇을 단언하나 |
|---|---|
| `status_e2e` | 근접 카드 한 방 → 연 부여 + 핍 등록 + 지속 == `BURN_DURATION` · 빙 카드 → 한 부여 + `move_multiplier < 1` + 연 소화 · **투사체 카드 실제 명중 → 연 부여** |
| `blaze_live` | 기름 유무 두 대상의 실측 피해비 == **2.2000** · 기름 소모 · 연 지속 ×2.5 · 연 틱 위력 ×3 · 도트가 실제로 깎인다 |
| `conduction` | 감속 적 5기 배치 → **정확히 4체** 전이 · 한 없는 대조군 무피해 · 반경 밖 무피해 · 도약 4개가 `StatusEngine.chain_damage()`와 일치 · 1차 대상의 한 보존 |
| `dot_kill` | 도트로 깎이지만 `was_hit`·`aggro` **불변**(behavior 3 목격자도 불변) · 도트 킬이 kills +1 · XP 구슬 생성 · 킬 체인 깊이 ≤ 상한+1 |
| `budget_guard` | 32회 연속 발동 → 예산 사용 **정확히 24** · 억제 ≥ 8 · **예산 고갈에도 대폭 연소 지속 불변** · `spread` 깊이 == 1 · 이웃에 기름 전파 확인 · 프레임 되감기 후 24 복원 |
| `stage_scale` | 임시 스윕 함수 부재 · 스테이지 1 dwell 0에서 다섯 배율 == 1.0 & HP == 라이브러리 원값 · 스테이지 3 dwell 4에서 **1회분만** 곱해짐 |

실측 출력:
```
COMBAT_TEST_COMPLETE state=playing status_e2e=true blaze_live=true conduction=true
  dot_kill=true budget_guard=true stage_scale=true kills=1 enemies=12 phase=day
  oil_mul=2.2000 blaze_ratio=7.5000 chain_hops=4 dot_ticks=3 reactions=73
  suppressed=8 chain_depth=1
```

### 9.2 `--stress-test` — 상태 활성 3구간 (재작성)

§3의 표가 그 결과다. 합격 기준에 **기기 독립 지표 5개**를 새로 넣었다:
`budget_peak <= cap` · `max_depth <= 1` · `kill_chain_peak <= 3+1` · `dot_ticks > 0` ·
`reactions > 0`. fps는 여전히 **보고만** 한다(AGENTS.md §11).

### 9.3 손대지 않은 것

`--status-test`는 **엔진 단위 그대로**다(`StatusTest.run_all()` 7묶음 · 42칸).
실전 통합은 위 두 곳이 본다 — 두 스위트가 겹치지 않는다.
`run_all.sh`는 **한 글자도 안 고쳤다**(`--boss-test` 임시 주석 포함).

### 9.4 검증 결과

```
godot --headless --path godot-game --editor --quit   → SCRIPT ERROR / Parse Error / ERROR: 0줄
bash godot-game/scripts/test/run_all.sh              → 13종 전부 PASS (62초)
   compile world-test v4-test castle-test rift-test stress-test smoke-test
   combat-test stage-test status-test cycle-test draft-test save-test
```

캡처(비headless · `art/screenshots/qa/`):

| 파일 | 육안 확인한 것 |
|---|---|
| `effects-minimal-v2-status.png` (**신설**) | 핍 5종 실루엣이 전부 갈린다 — 녹색 원(독) / 주황 위뾰족(연) / 청색 마름모(한) / 흑색 아래뾰족(유) / 황색 지그재그(전). 4종 걸린 개체가 **정확히 3개**에서 잘린다. 본체 마스크 틴트도 상태별로 읽힌다 |
| `effects-minimal-v2-synergy.png` (**신설**) | 대폭 연소(주황 폭발 · 행 0)와 전도(청색 뇌광 · 행 1) 버스트가 개체마다 뜨고, 부유 라벨 "대폭 연소!" "감전 유막!" "전도!"가 색으로 구분된다. 라벨은 프레임당 4장으로 잘려 겹치지 않는다 |
| `hud-minimal-v2-day.png` | 레일 원소 마크가 **타·뇌·화·타**로 뜬다(수정 전에는 `cleave`/`rapid_slash`가 빈 마크였다) |

> 캡처 도중 관측된 부수 확인 1건: 대폭 연소의 기름 전파(반경 130)가 이웃 적에게 유를
> 옮기고, 그 적이 다음 뇌 타격에서 **감전 유막**을 냈다. 매트릭스가 전파를 통해
> 실제로 연결된다는 육안 증거다(설계가 의도한 창발이며 깊이 1에서 정확히 멈춘다).

---

## 10. V7이 바로 알아야 할 것

1. **보스에게 상태를 붙이려면** `combat_resolver.strike_enemy_with_card()`의
   `is_boss_target` 분기 **한 곳**만 열면 된다. `enemy.st_state`는 보스도 이미 갖고 있고
   `tick_dot`도 이미 돌고 있다(상태가 없어 항상 0을 반환할 뿐이다).
   보스 핍은 `_draw_boss()`에 `_draw_status_pips()` 한 줄을 넣으면 된다.
2. **보스 패턴의 `status` 페이로드**(`BossLibrary.PATTERNS`의 `status` 키)는
   `StatusEngine.set_status(target_state, status, {"power": ..., "damage": ...})`로 심는다.
   매트릭스를 돌리고 싶으면 `StatusEngine.apply()`를 쓰되 **`ctx["budget"]`에
   `combat.status_budget`을 반드시 넘길 것** — 안 넘기면 그 경로만 무제한이 된다.
3. `--boss-test`를 되살릴 때 **`enemy.gd:setup()`의 마왕 HP 식이 바뀌었다**(§8.2).
   테스트의 기준 개체(`DebtEnemy.new()`)도 같은 함수를 타므로 대조는 그대로 성립한다.
4. `eclipse_*` 식별자 개명은 여전히 **V7 몫**이다. V6은 손대지 않았다.
5. `game.gd`의 스테이지·보스·성장 구역은 손대지 않았다. V6이 만진 game.gd 구역은
   `_process` 2줄 · HUD 상수 1개 · 위임 래퍼 1줄 · **신규 블록 2개**(L1 다리 · 시너지 VFX)뿐이다.

## 11. 남은 위험 / 미결

| # | 내용 | 크기 | 누가 |
|---|---|---|---|
| 1 | `card_status_power()`가 **항상 1.0** — 카드 데이터에 상태 세기 축이 없다. 채널은 뚫려 있고 함수 하나만 고치면 된다 | 중 | V10 (V3-L에 카드별 계수를 넣을지 판단) |
| 2 | 반응 예산 24가 78기 밤에서 요청의 **18%만** 통과시킨다. 게임 규칙이 아니라 연출이 잘리는 것이지만, 역병 발화가 눈에 잘 안 띄면 예산을 올리거나 `E_AOE_DAMAGE`를 예산 밖으로 뺄지 판단이 필요하다 | 중 | V10 |
| 3 | 투사체 배선이 **시그널 연결 순서에 의존**한다(§7). `projectile.gd`를 열 수 있는 웨이브가 `setup()` 인자로 바꾸는 편이 안전하다 | 소 | V10 |
| 4 | 상태는 저장되지 않는다. `_die()`/`clear()`만 있고 스냅샷 경로가 없다 — 설계 부록 B V9가 "복원 후 전부 0"으로 명시했으므로 **의도된 상태**다 | 소 | V9 (확인만) |
| 5 | 낮 동시 개체 상한이 30 → 27로 내려갔다(§8.1). dwell 곡선의 정상 결과지만 초반 체감이 조금 한산해졌을 수 있다 | 소 | V10 육안 |
| 6 | 한(chill)과 v2 `slow`가 곱으로 합성돼 이론 하한이 이동속도 ×0.2275다. 둘 다 최대로 겹치는 덱이 실제로 만들어지는지는 미확인 | 소 | V10 |
| 7 | 도트 킬은 `provoke()`를 안 부르므로 **behavior 1(도망)의 도주 반응도 안 난다.** 도트만으로 죽는 이끼콩은 가만히 서서 죽는다 — 성능 규칙 3의 필연적 대가다 | 소 | V10 판정 |
