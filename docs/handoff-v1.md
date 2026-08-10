# V1 인수인계 — 상태이상 엔진 (순수 로직)

> 작성: V1 구현 웨이브 / 2026-08-09
> 한 줄 요약: **설계 §4.3 데이터 모델과 §4.4 매트릭스 42칸을 순수·결정적 API 2개
> (`apply` / `tick`)로 구현했다. 게임 파일은 한 글자도 건드리지 않았고, §4.3의 검산치
> 4개(0.8 P · 6.0 P · 7.5배 · 3.24 P)가 소수점까지 정확히 재현된다.**

---

## 0. 결과 요약

| 항목 | 결과 |
|---|---|
| `--editor --quit` | 오류 0 (`SCRIPT ERROR`/`Parse Error`/`ERROR:` 0줄) |
| `--status-test` | **판정 7묶음 전부 true · exit 0** |
| 음성 대조 | `SYN_BLAZE_DURATION_MUL` → 리터럴 2.0 주입 시 `matrix=false blaze_ratio=false budget=false` · exit 1 확인 후 원복 |
| `run_all.sh` | **실행하지 않았다**(다른 웨이브와 로그 경합. 오케스트레이터가 직렬 실행) |
| 신규 파일 | `scripts/core/status_engine.gd` · `scripts/test/status_test.gd` |
| 수정 파일 | `scripts/test/test_runner.gd` — **`_run_status_test()` 함수 본문만** |
| 무수정 확인 | `game.gd` · `enemy.gd` · `combat_resolver.gd` · `rune_engine.gd` · 라이브러리 · `run_all.sh` |

```
STATUS_TEST_COMPLETE basics=true matrix=true blaze_ratio=true conduction=true
  psi_harvest=true budget=true deterministic=true
  blaze_p=6.0000 blaze_ratio_x=7.5000 burn_p=0.8000 cells=42
  conduction_total_p=1.6236 poison_decay_p=2.7000 poison_held_p=3.2400
  psi_p=3.0450 script_dot=5.42700 tick=0.25 budget=24 depth=1
TEST_RESULT=PASS exit_code=0
```

**숫자는 하나도 심지 않았다.** `status_engine.gd`의 상수는 배열 레이아웃(`F_*`),
이벤트·반응 어휘(`E_*`/`R_*`), 순수성 가드(`TIME_EPS`/`MAX_SLICES_PER_CALL`)뿐이고
밸런스 값은 전부 `GameTuning` V3-K/L/M을 읽는다. `status_test.gd`의 기대값도 전부
`GameTuning` 대조식이라 튜닝을 고치면 테스트가 따라 움직인다(리터럴 대조는 설계
문장을 그대로 못 박은 `7.5배` 한 곳뿐이다).

### 왜 `status_test.gd`가 따로 있나

설계 부록 B의 V1 행이 `scripts/test/status_test.gd`를 V1 소유로 명시한다. V4가
`test_runner.gd`의 `_run_stage_test()`를 **동시에** 편집 중이라 공유 파일에 남기는
흔적을 최소화했다 — `_run_status_test()` 본문은 `StatusTest.run_all()`을 부르고
결과를 찍는 12줄이 전부다. `ROUTINES`·`run_all.sh`는 손대지 않았다.

---

## 1. StatusEngine API

`class_name StatusEngine extends RefCounted` · 전부 `static` · 노드·`Time`·`randf()`
참조 0건(`rune_engine.gd`와 같은 계층 규칙).

### 1.1 상태 묶음 — float 11칸

설계 §4.3의 "고정 크기 float 묶음"이다. **`Array`를 쓴 이유는 참조 타입이라서다.**
`PackedFloat32Array`는 값 타입이라 함수 안에서 고친 것이 호출자에게 안 돌아간다 —
그러면 프레임마다 78기 × 재할당이 생겨 §4.7 규칙 1이 무너진다.

| 인덱스 | 상수 | 뜻 |
|---|---|---|
| 0 | `F_POISON_TIME` | 독 남은 지속 |
| 1 | `F_POISON_STACKS` | 독 스택(1~`POISON_STACK_MAX`) |
| 2 | `F_POISON_UNIT` | 스택 1개의 한 틱 피해 = `POISON_DOT_PER_STACK × P × power` |
| 3 | `F_POISON_DECAY` | 다음 스택 −1까지 남은 초 |
| 4 | `F_BURN_TIME` | 연 남은 지속 |
| 5 | `F_BURN_UNIT` | 연 한 틱 피해 = `BURN_DOT × P × power` |
| 6 | `F_CHILL_TIME` | 한 남은 지속 |
| 7 | `F_CHILL_POWER` | 한 세기 0~1 |
| 8 | `F_OIL_TIME` | 유 남은 지속 (자체 피해 0) |
| 9 | `F_SHOCK_TIME` | 전 남은 지속 |
| 10 | `F_TICK_ACCUM` | 다음 도트 틱까지 누적 시간 |

`FIELD_COUNT = 11`. 인덱스 상수는 **공개 API**다 — V6이 직접 읽어도 되고,
`enemy.gd`가 float 필드 11개로 펼치고 싶다면 이 순서를 그대로 쓰면 된다.

### 1.2 곱셈 채널 3개 (헷갈리면 밸런스가 통째로 어긋난다)

| 이름 | 어디서 오나 | 무엇을 곱하나 |
|---|---|---|
| `ctx["damage"]` | `_cycle_damage_value()` 결과 | P의 기저 |
| `ctx["potency"]` | **L1 신규 채널**(§4.5 인화 ×1.5 · 역병 발화 준비 ×1.3) | P의 배율 |
| `P` | `= damage × potency` | 설계 §4.3·§4.4 표의 모든 "P" |
| `power`(3번째 인자) | 카드·반응이 정하는 상태 세기(기본 1.0) | 한의 감속량, 연·독의 틱 피해. **대폭 연소가 ×3 하는 것이 이 값** |

`StatusEngine.potency_damage(ctx)`가 P를 계산하는 단일 지점이다.

### 1.3 함수

| 함수 | 용도 |
|---|---|
| `make_state() -> Array` | 적 1기당 **한 번만** 만든다 |
| `clear(state)` | 전부 해제 (V9 저장 복원 · 적 풀 재사용) |
| `apply(state, element, power=1.0, ctx={}) -> Dictionary` | **매트릭스 본체.** 아래 1.4 |
| `tick_dot(state, delta) -> float` | **제로 할당 핫 패스.** `enemy._physics_process` 전용 |
| `tick(state, delta) -> Dictionary` | 도구·테스트용 래퍼(`{state, dot, expired, active}`) |
| `preview(state, element, power, ctx) -> Dictionary` | 상태를 바꾸지 않고 반응·범위 보정·증폭만 미리 본다 |
| `set_status(state, status, opts={})` | **매트릭스를 거치지 않는** 저수준 부여 |
| `has_any / has / remaining / stacks / total_remaining` | 조회 |
| `active_list / pip_list` | HUD 핍(§4.8, `STATUS_PIP_MAX`개) |
| `move_multiplier(state)` | 한 감속 배율 |
| `incoming_multiplier(state, element)` | 유의 화염 증폭 ×2.2 (**`apply()`보다 먼저** 물어야 한다) |
| `next_hit_multiplier / consume_shock` | 전 표식 +12% (조회 / 소모) |
| `tick_damage(state)` | 한 틱이 낼 도트(조회) |
| `chain_damage(event, hop_index)` | 전이 k번째 도약 피해. **엔진과 호출자가 같은 식을 쓰게 하는 지점** |
| `make_budget / budget_reset / budget_left / can_propagate` | §4.7 규칙 4 |
| `signature(state)` | 결정성 지문 |
| `SOURCE_NORMAL / SOURCE_DOT / SOURCE_REACTION` | `take_damage(..., source)` 어휘(§4.7 규칙 3) |

### 1.4 `apply()` 반환

| 키 | 내용 |
|---|---|
| `state` | **인자로 받은 그 배열**(복사본 아님. 제자리 갱신) |
| `events` | `Array[Dictionary]`. 순서대로 실행하면 된다 |
| `reactions` | `Array[String]`. 발동한 반응 키. HUD 라벨은 `REACTION_LABELS[key]` |
| `applied` | 이번에 부여/갱신된 상태 이름(`""` = 없음 — 타·초) |
| `range_bonus` | 증기가 낸 **이번 타격**의 범위 보정 |
| `cost` | 이번 호출이 먹은 반응 예산 |
| `suppressed` | 예산·깊이로 잘려 나간 질의 이벤트 수 (`--stress-test`가 볼 값) |

### 1.5 이벤트 어휘 — 엔진이 "해 달라"고 부탁하는 것 전부

엔진은 세계를 만지지 않는다. 좌표도 이웃도 모른다. 아래 6종만 내보낸다.

| `kind` | 키 | V6이 할 일 |
|---|---|---|
| `damage` | `amount` | 대상 본인에게 `take_damage(amount, ..., SOURCE_REACTION)` |
| `aoe_damage` | `amount` `radius` `apply_status?` | `query_enemies(center, radius)` 전원 피해 (+`set_status`로 표식) |
| `chain_damage` | `amount` `radius` `max_targets` `falloff` `filter` `apply_status` | 반경 내 **`filter` 상태를 가진 적만** 골라 `max_targets`까지, k번째는 `chain_damage(event, k)` |
| `spread_status` | `status` `radius` `duration` `power` `depth` | 반경 내 전원에게 `apply(other, "oil", power, {depth: event.depth, ...})` |
| `knockback` | `knockback_mul` `stun` | 기존 `apply_hit_reaction()` 경로에 곱한다 |
| `range_bonus` | `range_bonus` | 이번 타격의 범위에 더한다 |

모든 이벤트에 `kind` · `reaction` · `label`이 항상 들어 있다.
`label`이 빈 문자열이 아니면 §4.8의 1회성 부유 라벨을 띄우면 된다.

---

## 2. 매트릭스 구현표 (설계 §4.4 대비)

7행 × 6열 = **42칸 전부** `--status-test`의 `matrix` 묶음이 반응 시퀀스까지 단언한다.

| ↓적용 \ 기존→ | (없음) | poison | burn | chill | oil | shock |
|---|---|---|---|---|---|---|
| **poison** | `poison_apply` | `poison_stack` | — | `frozen_venom` 지속 ×1.5 | — | — |
| **fire** | `burn_apply` | ★`plague_ignition` r90 · `1.2 P × stacks` | `burn_refresh` | `steam` 범위 +50% | ★`blaze` power ×3 · 지속 ×2.5 · r130 유 전파(깊이 1) | — |
| **ice** | `chill_apply` | `frozen_venom` | `quench` 연 해제 | `chill_refresh` | — | — |
| **thunder** | `shock_apply` | — | — | ★`conduction` r260 · `0.55 P` · 4체 · −20%/도약 | `oiled_shock` r160 · `0.8 P` + 전 | `shock_refresh` |
| **oil** | `oil_apply` | — | `greased_flame` 연 ×2 | — | `oil_refresh` | — |
| **strike** | (없음) | `detonate` 스택 −1 · `1.0 P` | — | `shatter` 넉백 ×2 · 경직 0.35 | — | — |
| **psi** | (없음) | ← `psi_collapse` 모든 상태 남은 지속 −30% → 소모 초 × `0.5 P` 즉발 → | | | | |

### 2.1 설계에 없어서 정한 것 (조정 + 근거) — 11건

| # | 항목 | 결정 | 근거 |
|---|---|---|---|
| 1 | **여러 열 동시 반응** | 허용. 행마다 순서 고정 | 유+독이 붙은 적에게 화 = 대폭 연소 + 역병 발화. 각 열이 **다른 자원**을 소비하므로 배타로 만들 이유가 없다. 순서: 화 = 유→독→한→연부여 / 빙 = 독→연→한 / 뇌 = 한→유→전 / 타 = 독→한. **유(대폭 연소)가 연 부여보다 반드시 앞**이어야 한다 — 이번에 붙일 연의 power·지속을 바꾸기 때문 |
| 2 | **갱신은 하향하지 않는다** | 지속·틱 단위 모두 `max(기존, 신규)` | 대폭 연소가 붙은 연에 맨 불이 겹쳤다고 위력이 떨어지면 "순서가 콤보"라는 요구가 무너진다 |
| 3 | **한 "갱신·강화"의 강화량** | `power = max(기존, 신규)` | V3-L에 강화 계수가 **없다.** 숫자를 지어내면 tuning.gd가 단일 소유자라는 규칙이 깨진다. 계수가 정해지면 `_row_ice()` 한 줄만 바뀐다 |
| 4 | **독 지속 +50%의 상한** | `POISON_DURATION × 1.5` = 9.0초에서 자름 | 빙을 반복하면 남은 지속이 ×1.5씩 무한 복리가 된다. 새 상수를 만들지 않고 상한을 세우는 유일한 방법 |
| 5 | **독 스택 감쇠 시계** | 독을 적용할 때마다 `POISON_STACK_DECAY_INTERVAL`로 되감음 | "축적 → 터뜨린다"(§4.2)가 성립하려면 쌓는 동안에는 줄지 않아야 한다. 지속 상한 6초가 여전히 전체를 묶는다 |
| 6 | **독 틱 단위의 재적용** | `max(기존, 신규)` | 약한 후속 적용이 이미 쌓인 강한 독을 깎으면 안 된다 |
| 7 | **전도가 1차 대상의 한을 소모하는가** | **소모하지 않는다** | 설계가 해제를 지시한 것은 증기·쇄빙 둘뿐이다. 소모하면 §4.6 빌드 ②(빙 2칸 → 뇌 3칸)가 1회용이 된다 |
| 8 | **`power` 채널의 적용 범위** | 독·연의 틱 단위에도 곱한다 | 설계는 한·연에만 명시했지만 기본값 1.0이라 **현재 동작은 설계와 완전히 동일**하고, V2의 카드 데이터가 상태 세기를 갖게 될 때 채널이 이미 뚫려 있다 |
| 9 | **예산 고갈 시의 동작** | **세계 질의 이벤트만** 막는다. 상태 수치 계산·단일 대상 피해는 언제나 실행 | 예산이 바닥났다고 대폭 연소의 연이 안 붙으면 그건 성능 보호가 아니라 게임 규칙이 프레임률에 종속되는 것이다 |
| 10 | **깊이 제한의 대상** | 호출자가 **다른 대상에게 다시 `apply()`를 들어가게 만드는** 이벤트만 = `chain_damage` · `spread_status` | `aoe_damage`는 표식만 남기거나 아무 상태도 안 만들어 연쇄가 불가능하다. 예산은 먹지만 깊이는 안 먹는다 |
| 11 | **틱 경계** | 슬라이스 안에서 상태가 만료돼도 **그 슬라이스의 틱은 지급** | 이게 없으면 독 6초가 24틱이 아니라 23틱, 연 2초가 8틱이 아니라 7틱이 되어 §4.3 검산이 통째로 어긋난다 |

### 2.2 설계와 다르게 구현한 것

**없다.** §4.4 표의 모든 칸과 V3-L 계수 19개가 표기 그대로 들어가 있다.
위 11건은 전부 "설계가 말하지 않은 빈칸"을 메운 것이고, 그중 4건(#3 #4 #5 #7)은
나중에 수치가 정해지면 각각 한 줄만 고치면 되도록 지점을 좁혀 두었다.

---

## 3. 성능 (§4.7) — 엔진 쪽 준비 상태

| 규칙 | 엔진이 제공하는 것 | V6이 할 일 |
|---|---|---|
| 1. 새 O(N) 순회 금지 | `tick_dot()`은 **Dictionary를 만들지 않는다.** 상태가 하나도 없으면 즉시 반환 | 기존 타이머 블록(`enemy.gd` `cycle_slow_timer` 줄 근처)에 한 줄 얹기 |
| 2. 도트 0.25초 버퍼 | `tick_dot()`이 **0.25초 경계에서만** 0보다 큰 값을 돌려준다 | `if dot > 0.0:` 일 때만 `take_damage` 1회 → 78기 × 4회/초 |
| 3. `source: int` | `SOURCE_NORMAL/DOT/REACTION` 상수를 엔진이 소유 | `take_damage`에 인자 추가 · `SOURCE_DOT`이면 `provoke()`·`alert_same_species()` 우회 |
| 4. 예산 24 · 깊이 1 | `make_budget()` · `budget_reset()` · `_emit()`의 자동 검사 · `suppressed` 카운트 | `CombatResolver`에 예산 1개 두고 프레임 시작마다 `budget_reset()` |

`tick_dot()`은 delta를 `STATUS_TICK` 경계로 잘라 처리하므로 **delta를 어떻게 쪼개
넣어도 결과가 같다**(1.0초 1회 == 0.25초 4회 == 1/60초 60회). 테스트 ⑦이 단언한다.

---

## 4. 테스트 결과 — `--status-test` 7묶음

| 묶음 | 무엇을 단언하나 | 지표 |
|---|---|---|
| `basics` | 5종 부여 지속·수치가 V3-K 그대로 · 유의 자체 도트 0 · potency 채널(P = 2.0 × 1.5 = 3.0) · 스택 상한 6 · **지속 경계**(정확히 `BURN_DURATION`에 꺼지고 −0.01초에는 살아 있다) · 스택 감쇠 1.5초 주기 3회 · 갱신 무하향 · 핍 3개 | — |
| `matrix` | **42칸 전부** 반응 시퀀스 일치 + 칸별 수치 12건(반경·피해·지속·소모)을 GameTuning 대조 · 상호작용 없는 칸이 기존 상태를 안 건드림 · 유+독 동시 반응 | `cells=42` |
| `blaze_ratio` | 맨 불 8틱 = **0.8 P** · 대폭 연소 20틱 = **6.0 P** · 배수 **7.5** (셋 다 ±2%) · 독 6초 스택 3 고정 = **3.24 P** | `burn_p=0.8000` `blaze_p=6.0000` `blaze_ratio_x=7.5000` `poison_held_p=3.2400` |
| `conduction` | 전이 이벤트가 `{radius, max_targets, falloff}`를 정확히 냄 · 4체 · 도약당 −20% (0.55 / 0.44 / 0.352 / 0.2816) · 1차 대상의 한 보존 · 깊이 1에서 재전도 없음 | `conduction_total_p=1.6236` |
| `psi_harvest` | 5종 동시(합 20.3초) → 30% 소모 6.09초 → `× 0.5 × P` = **3.045 P** · 상태별 잔여가 정확히 ×0.7 · 상태 없으면 무동작 | `psi_p=3.0450` |
| `budget` | 상한 2에 5회 → 질의 이벤트 2 · 억제 3 · 사용량이 상한 초과 0 · **예산 고갈에도 대폭 연소 수치는 불변** · 깊이 1 차단 · 예산 미지정 = 무제한 · `preview()` 무변경 | — |
| `deterministic` | 40수 고정 대본 2회 지문·도트·반응 시퀀스 완전 일치 · delta 분할 불변(1회/4회/120회) · 동일 사본 동일 결과 | `script_dot=5.42700` |

**정보성 지표는 전부 숫자다.** `=false`는 실패 표시 전용이므로 run_all.sh 규약을 지킨다.

### 음성 대조

`_row_fire()`의 `GameTuning.SYN_BLAZE_DURATION_MUL`을 리터럴 `2.0`으로 바꿔 실행:

```
[matrix] 대폭 연소 연 지속 기대 5.000000 실제 4.000000
[blaze_ratio] 기름+불 / 맨 불 배수 기대 7.500000 ±2.0% 실제 6.000000
[budget] 예산 고갈 1회차의 대폭 연소 지속 기대 5.000000 실제 4.000000
STATUS_TEST_COMPLETE ... matrix=false blaze_ratio=false ... budget=false
TEST_RESULT=FAIL exit_code=1
```

3개 묶음이 독립적으로 잡았고 상세 사유가 나온다. 확인 후 즉시 원복했고 재실행 PASS.

---

## 5. V6 통합 체크리스트

### 5.1 `enemy.gd`

- [ ] 필드 1개: `var st_state: Array = StatusEngine.make_state()`
      — **적 1기당 한 번만** 만든다(스폰/`setup()`). 프레임마다 만들면 규칙 1이 무너진다.
- [ ] 기존 타이머 블록(`cycle_slow_timer = maxf(...)` 줄 바로 뒤)에 3줄:
      ```gdscript
      var st_dot := StatusEngine.tick_dot(st_state, delta)
      if st_dot > 0.0:
          take_damage(st_dot, global_position, 0.0, 0.0, StatusEngine.SOURCE_DOT)
      ```
      `tick_dot`이 이미 0.25초 버퍼다 — 밖에 또 누적기를 두지 말 것.
- [ ] 이동 속도에 `StatusEngine.move_multiplier(st_state)`를 곱한다.
      기존 `cycle_slow_multiplier`와 **곱셈으로 합성**할지 `min`으로 합성할지는 V6 판단.
- [ ] `take_damage(amount, hit_position, knockback_force, stun_duration)`에
      **5번째 인자** `source: int = StatusEngine.SOURCE_NORMAL` 추가.
      `source == StatusEngine.SOURCE_DOT`이면 `provoke()`(현재 무조건 호출)와
      `alert_same_species()`를 건너뛴다. **이건 선택이 아니다** — 도트 틱마다
      behavior 3 몹이 반경 780px 종족 경보를 쏘면 즉사한다(§4.7 규칙 3).
- [ ] 마스크 틴트 1줄: `_draw_field_monster()`의 4단계 `if` 뒤
      (`night_form / cycle_slow / hit_stun / hit_flash` 다음).
      우세 상태 = `StatusEngine.active_list(st_state)[0]`.
- [ ] 머리 위 상태 핍: 체력바 앞쪽(`y ≈ -radius - 32`)에 **별도 루프**.
      617~622의 `raid/flee/aggro` `if/elif` 체인은 배타적이라 끼우면 안 된다.
      `for pip in StatusEngine.pip_list(st_state):` — 색은 §4.8
      (독 녹 / 연 주 / 한 청 / 유 흑 / 전 황). 엔진은 색을 갖지 않는다.
- [ ] 죽거나 풀에 반납할 때 `StatusEngine.clear(st_state)`.

### 5.2 `combat_resolver.gd` — `_apply_card_status_to_enemy()`

**호출 순서가 중요하다.** 유의 화염 증폭은 `apply()`가 기름을 소모하기 **전에**
물어야 한다:

```gdscript
# ① 직격 피해 보정 (apply보다 먼저!)
var mul := StatusEngine.incoming_multiplier(target.st_state, element)
mul *= StatusEngine.consume_shock(target.st_state)      # 전 표식 +12% 소모
# ② 매트릭스
var ctx := {"damage": cycle_damage, "potency": step_potency, "depth": 0, "budget": frame_budget}
var res := StatusEngine.apply(target.st_state, element, card_power, ctx)
# ③ 이벤트 실행
for event in res["events"]: ...
# ④ HUD
if not res["reactions"].is_empty(): 부유 라벨 = StatusEngine.REACTION_LABELS[...]
```

- [ ] 프레임 예산 1개: `var status_budget := StatusEngine.make_budget()`,
      매 프레임 시작에 `StatusEngine.budget_reset(status_budget)`.
- [ ] `chain_damage` 실행: 반경 안에서 **`filter`(= `"chill"`) 상태를 가진 적만**
      골라 `max_targets`까지. k번째 피해는 반드시 `StatusEngine.chain_damage(event, k)`
      로 계산할 것 — 감쇠식을 두 벌 만들면 테스트와 런타임이 갈라진다.
      각 대상에 `StatusEngine.set_status(other, "shock")` (뇌 행을 다시 돌리지 말 것).
- [ ] `spread_status` 실행: 반경 안 전원에게
      `StatusEngine.apply(other, "oil", event.power, {..., "depth": event.depth})`.
      `depth`를 **반드시 이벤트에서 가져와 넘길 것.** 안 넘기면 깊이 가드가 무력화되고
      기름 웅덩이 연쇄 폭발이 난다.
- [ ] `range_bonus`는 **이번 타격**에 쓰는 값이다. 이미 피해를 준 뒤라면 다음 펄스에
      적용되므로, 필요하면 `StatusEngine.preview()`로 타격 전에 미리 받아 쓴다.
- [ ] 전역 킬 체인 깊이 가드 — 도트로 죽은 적도 `_die()` → `enemy_defeated()`를 탄다
      (§4.7 추가 함정). **깊이 숫자는 설계에 없다. V6이 정해서 `tuning.gd`에 넣는다**
      (V0가 "V6이 정한다"로 남겨 둔 3건 중 하나).
- [ ] `suppressed` 누적치를 `--stress-test`가 볼 수 있게 노출(예산 초과 0건 단언용).

### 5.3 V2와 맞물리는 지점

- [ ] `rune_engine.ELEMENTS`가 7계로 재편되면 `StatusEngine.ELEMENTS`
      (`poison/fire/ice/thunder/oil/strike/psi`)와 **배열 동등**이어야 한다.
      지금은 v2의 6계라 일부러 대조하지 않았다 — V6이 배선할 때 단언을 켤 것.
- [ ] `simulate_cycle()`의 `step_record["potency"]`가 `ctx["potency"]`로 들어간다.
      이게 L1→L2를 잇는 **유일한** 통로다(§4.1의 분리 규칙: L1은 직접 피해를 주지
      않고 L2는 사이클 피해 배율을 곱하지 않는다).

### 5.4 `--status-test`에 V6이 덧붙일 것

지금 스위트는 **순수 로직만** 본다. V6은 같은 루틴에 런타임 통합 단언을 얹는다:
5칸에 유→화를 꽂았을 때 실제로 대폭 연소가 터지는가 · 빙→뇌가 실제 적 4체에
전이하는가 · 78기 상태 만연에서 예산 초과 0건인가 · 도트 킬이 재귀를 만들지 않는가.
`StatusTest.run_all()`은 그대로 두고 뒤에 이어 붙이면 된다(반환 Dictionary의
`passed`를 AND 하면 판정이 합쳐진다).

---

## 6. 남은 위험

| # | 내용 | 누가 |
|---|---|---|
| 1 | 한 "강화" 계수가 설계에 없다 → 지금은 `max`. 강화가 눈에 안 보이면 V10이 계수를 정해 V3-L에 추가 | V10 |
| 2 | 독 감쇠까지 반영한 실제 총량은 스택 3에서 1.62 P, 스택 4에서 2.70 P다. 설계 §4.3의 "≈2 P"는 그 사이 근사치이므로 **틀리지 않았지만** 밸런스 실측 때 어느 쪽을 기준으로 볼지 정해야 한다 | V10 |
| 3 | 전역 킬 체인 깊이 상한값 미정 | V6 |
| 4 | `range_bonus`(증기)를 "이번 타격"에 반영하려면 `combat_resolver`가 피해 계산 **전에** `preview()`를 불러야 한다. 사후 `apply()`만 쓰면 한 펄스 늦게 적용된다 | V6 |
