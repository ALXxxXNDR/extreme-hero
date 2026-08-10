# W1 인수인계 — 순수 각인 규칙 엔진

대상: **W2**(사이클 런타임) · **W6**(편집 화면·드래프트) · **W7**(콘텐츠 데이터)
기준 문서: `docs/GAME_DESIGN_V2.md` §3 전체, §7 W1 정의, **부록 C-1**(본문보다 우선)

## 0. 산출물

| 파일 | 역할 |
|---|---|
| `godot-game/scripts/core/rune_engine.gd` | `class_name RuneEngine`. 각인 24종 데이터 + 순수 규칙 함수 + 한 사이클 시뮬레이터 |
| `godot-game/scripts/test/rune_test.gd` | 단독 실행 테스트(SceneTree 확장). 32,000 사이클 몬테카를로 + 규칙 단위 검증 16종 |
| `docs/handoff-w1.md` | 이 문서 |

**기존 파일은 한 개도 건드리지 않았다.** `game.gd`·`test_runner.gd`·`run_all.sh`·
`factory_deck.gd`·`tuning.gd` 전부 무수정. 검증: `bash godot-game/scripts/test/run_all.sh`
→ 기존 6종 전부 PASS(종합 PASS, 28초).

## 1. 실행 명령

```bash
# 전역 클래스 캐시 갱신 + 컴파일 검사 (신규 class_name 추가 후 최초 1회 필수)
godot --headless --path godot-game --editor --quit          # 오류 0

# 각인 엔진 단독 테스트
godot --headless --path godot-game -s res://scripts/test/rune_test.gd
#   합격 → `RUNE_TEST_COMPLETE ...=true ... <수치>` 한 줄 + exit 0
#   불합격 → `RUNE_TEST_DETAIL ...` 여러 줄 + `RUNE_TEST_FAILED failed=...` + exit 1

# 기존 하네스 회귀 (W1이 아무것도 안 깼다는 증명)
bash godot-game/scripts/test/run_all.sh                      # 종합 PASS
```

`run_all.sh`는 W0 소유라 손대지 않았다. `--rune-test`를 셸에 편입하고 싶으면
`ALL_TESTS`에 `"--rune-test:RUNE_TEST_COMPLETE"`를 추가하고 `test_runner.gd`에서
`RuneEngine`을 호출하는 얇은 래퍼를 두면 된다. 출력 규약은 이미 맞춰 뒀다
(판정은 전부 `=true`, 정보성 값은 숫자 — `=false` 문자열을 절대 내지 않는다).

## 2. 데이터 모델 — 부록 C-1이 요구한 것

```gdscript
card := {"id", "damage", "reload", "duration", "element", "form"}   # W7이 채운다
rune := {"id": String, "p": float, "mag": float}                    # 드래프트 시 굴린 인스턴스
slot := {"card": Dictionary, "runes": Array}                        # ← 칸이 각인 스택을 소유
deck := Array[slot]                                                 # 5칸
```

**각인은 칸에 붙는다.** 덱은 칸 객체의 배열이므로 배열 원소를 통째로 바꾸면
각인이 칸과 함께 따라간다 — 부록 C-1의 "칸 위치 교환" 요구가 데이터 구조로 자동 충족된다.

| 조작 | 함수 | 결과 |
|---|---|---|
| 칸 순서 교환 | `RuneEngine.swap_slots(deck, a, b)` | 카드 + 각인이 **함께** 이동 |
| 카드만 이동 | `RuneEngine.move_card(deck, a, b)` | `card` 필드만 교환, 각인은 제자리 |

W6는 편집 화면에서 이 두 조작을 **별개 제스처**로 노출해야 한다(부록 C-1: 두 조작이 공존).
테스트 `slot_swap` / `rune_travel`이 구조적 이동과 시뮬레이션 상 발동 위치 양쪽을 검증한다.

전부 순수 `Dictionary`·`Array`다. 클래스 인스턴스가 아니므로 `var_to_str` / `JSON`으로
그대로 저장·복원된다(W12 세이브 대비).

## 3. 엔진 API 요약

### 3.1 카탈로그 · 드래프트 (W6 · W7)

```gdscript
RuneEngine.RUNES                       # Dictionary: id -> 정의 (24개)
RuneEngine.all_rune_ids() -> Array[String]
RuneEngine.ids_by_rarity(r) -> Array[String]      # "common" | "rare" | "epic"
RuneEngine.ids_by_family(f) -> Array[String]      # flow|parallel|conditional|tempo|combat
RuneEngine.roll_rune(id, rng) -> Dictionary       # 확률·크기를 범위에서 굴린 인스턴스
```

### 3.2 칸 조립 (W6)

```gdscript
RuneEngine.make_slot(card, runes) -> Dictionary
RuneEngine.make_deck(slots) -> Array
RuneEngine.attach_rune(slot, inst) -> bool        # 상한 초과면 false, 아무 변화 없음
RuneEngine.same_id_count(slot, id) -> int
RuneEngine.swap_slots(deck, a, b) -> bool
RuneEngine.move_card(deck, a, b) -> bool
```

### 3.3 확률 규칙 (§3.4) — 전부 순수, UI 툴팁이 직접 호출 가능

```gdscript
RuneEngine.merged_probability(instances) -> float   # 여집합 곱 + 중복 감쇠
RuneEngine.merged_magnitude(instances) -> float     # 크기 중복 감쇠
RuneEngine.congestion_scale(rune_count) -> float    # 과밀 페널티
RuneEngine.effective_probability(base_p, load, congestion) -> float   # 최종 (P_CAP 클램프)
RuneEngine.heat_from_load(load, heat_bonus) -> int
RuneEngine.damage_multiplier(heat, reentry) -> float
RuneEngine.condition_ok(cond, ctx) -> bool
```

### 3.4 한 칸 판정 — W1 완료 기준 ② (순수 함수)

```gdscript
RuneEngine.resolve(slot_runes: Array, ctx: Dictionary, rng) -> Dictionary
```

`ctx`: `deviation_load`(float) `heat`(int) `reentry`(int) `bond`(bool) `element`
`prev_element` `prev_index`(int) `killed`(bool) `slot_index`(int) `bookmark`(int)

반환 키: `repeat` `delta` `reverse` `jump_to` `set_bookmark` `fired[]` `fire_cost`
`fire_count` `damage_bonus` `damage_mult` `range_bonus` `pierce_bonus` `duration_mult`
`debt_delta` `free_reload` `link_next` `echo_power` `chorus_power` `overlap_power`
`afterburn` `toll`

### 3.5 태그 상호작용 (§3.8) — W6 편집 화면이 실시간으로 그린다

```gdscript
RuneEngine.bond_mask(deck) -> Array[bool]          # 결속 구간 (같은 원소 3칸 연속)
RuneEngine.resonance_bonus(deck, i) -> float       # 인접 공명 +15%
RuneEngine.triangle_ok(deck) -> bool               # 1·3·5칸 같은 형태 → RELOAD −12%
RuneEngine.reaction_of(prev_el, el) -> String      # "" | shock | steam | overcharge
```

### 3.6 한 사이클 시뮬레이션 — **W2와 W6의 단일 진실 원천**

```gdscript
RuneEngine.simulate_cycle(deck, cycle_seed: int, opts := {}) -> Dictionary
```

`opts`(전부 선택): `start_load`(잔열 이월) · `kill_chance` · `kills`(Array[bool], W2가 실제
처치 결과 주입) · `reload_scale`(보스전 ×0.6) · `direction`

반환:

| 키 | 내용 |
|---|---|
| `steps` | 스텝별 궤적 배열 (아래) |
| `step_count` `overloaded` `end_reason` | `complete` / `overload` / `reverse_home` / `guard` |
| `damage_total` `damage_mul_sum` | 총 피해(카드 계수 포함) / 배율 합 |
| `heat_curve` `peak_heat` `end_heat` `deviation_load` | 과열 곡선 |
| `fired` `fire_count` | 발동한 각인 id 전체 |
| `reload_debt` `reload` | 누적 빚 / 최종 RELOAD(초) |
| `carry_heat` | 잔열(afterburn)이 다음 사이클로 넘길 과열 |
| `visited` `reactions` | 방문 칸 순서 / 발생한 원소 반응 |

스텝 레코드: `index slot card_id reentry heat damage_mul damage direction duration
fired[] delta repeat reverse link range_bonus pierce_bonus reaction bond debt`

```gdscript
RuneEngine.trace_signature(cycle) -> String     # 궤적 지문 (결정성 검증 · 미리보기 캐시 키)
RuneEngine.preview(deck, seed, samples, opts) -> Dictionary
#   -> {samples, mean_steps, mean_damage, mean_reload, mean_peak_heat, overload_rate, bond, triangle}
```

**W2와 W6는 반드시 `simulate_cycle`을 공유하라.** W6가 자체 근사식을 쓰면 미리보기와
실제 궤적이 어긋난다. W2는 반환된 `steps[]`를 프레임에 펼치기만 하면 되고
(`duration`이 스텝별로 이미 haste 반영된 값이다), W6는 같은 `steps[]`를 레일 화살표로 그린다.

**결정성**: 같은 `(deck, cycle_seed, opts)`면 100% 같은 궤적. 엔진은 `randf()`·`randomize()`·
`Time`을 전혀 쓰지 않는다. W2는 사이클마다 시드를 명시적으로 넘겨야 하고(예: 런 시드 +
사이클 번호), 그 시드를 세이브에 넣으면 리플레이가 공짜로 된다.

## 4. 각인 24종 최종 표

확률은 **드래프트 시 범위 안에서 굴린다**(§3.3). "확정"은 굴리지 않는 패시브이며
**과열을 전혀 올리지 않는다** — 조건 각인과 함께 "과열 예산을 안 먹는" 안전한 선택지다.

### A. 흐름 (Flow) — 바늘을 움직인다

| id | 이름 | 효과 | 확률 | 등급 | 조건 |
|---|---|---|---|---|---|
| `rewind_1` | 되감기 | delta −1 | 18~42% | 일반 | — |
| `rewind_2` | 깊은 되감기 | delta −2 | 12~28% | 희귀 | — |
| `skip_1` | 도약 | delta +1 (건너뛴 칸 미실행·빚 없음) | 20~45% | 일반 | — |
| `repeat` | 앙코르 | 같은 칸 1회 더 (REPEAT_CAP 2) | 15~35% | 일반 | — |
| `echo` | 메아리 | 이전 칸 카드를 위력 60%로 추가 발동 | 20~40% | 희귀 | 이전 칸 존재 |
| `reverse` | 역행 | 진행 방향 반전 | 10~22% | 영웅 | — |
| `bookmark` | 각인점 | 표식 없으면 이 칸을 표식으로, 있으면 표식으로 점프 | 12~25% | 영웅 | — |
| `kill_repeat` | 도륙 | 앙코르 | **75%**(P_CAP) | 희귀 | 이 칸으로 처치 |

### B. 동시 (Parallel) — 칸을 결합한다

| id | 이름 | 효과 | 확률 | 등급 | 조건 |
|---|---|---|---|---|---|
| `link_next` | 연결 | 다음 칸 동시 실행 + 바늘이 통과 | 18~38% | 희귀 | — |
| `chorus` | 합주 | 양옆 칸 위력 30% 동반 발동 | 25~50% | 일반 | — |
| `overlap` | 겹침 | 이전 칸 효과 35% 잔류 | 확정 | 일반 | 이전 칸 존재 |

### C. 조건 (Conditional) — 5칸이 서로를 본다

| id | 이름 | 효과 | 확률 | 등급 | 조건 |
|---|---|---|---|---|---|
| `tag_chain` | 연쇄 | 피해 +25~55% | 30~55% | 일반 | 직전 실행 칸과 같은 원소 |
| `heat_gate` | 열기 | 피해 ×1.8 | 22~45% | 희귀 | 과열 ≥3 |
| `first_strike` | 선봉 | 피해 +40~80% | 28~50% | 일반 | 이번 사이클 첫 실행 |
| `last_call` | 마감 | RELOAD 빚 −0.15초 | 30~55% | 일반 | 재진입 |
| `odd_even` | 홀짝 | 홀수 실행 피해 +25~50% / 짝수 범위 +30% | 25~45% | 일반 | — |

### D. 템포 (Tempo) — 시간을 만진다

| id | 이름 | 효과 | 확률 | 등급 | 조건 |
|---|---|---|---|---|---|
| `haste` | 단축 | 이 칸 duration −12~25% | 25~45% | 일반 | — |
| `refund` | 상환 | 빚 −0.2~0.5초 | 22~42% | 희귀 | — |
| `toll` | 통행세 | 이 칸을 도약으로 건너뛸 때마다 빚 −0.4초 | 확정 | 희귀 | 트리거 |
| `free_reload` | 무상 | 이 칸의 reload를 0으로 | 25~50% | 일반 | — |
| `afterburn` | 잔열 | RELOAD 후 과열을 floor(H/2)만큼 유지 | 확정 | 영웅 | — |

### E. 전투 (Combat) — `item_library.gd`의 `effects` 어휘 재사용

| id | 이름 | 효과 | 확률 | 등급 |
|---|---|---|---|---|
| `edge` | 예기 | 이 칸 피해 +18~40% (`damage`) | 확정 | 일반 |
| `reach` | 확장 | 이 칸 범위 +15~35% (`range`) | 확정 | 일반 |
| `barb` | 미늘 | 이 칸 관통 +1 (`pierce`) | 확정 | 희귀 |

등급 분포: **일반 13 · 희귀 8 · 영웅 3 = 24종.**

## 5. 설계에서 벗어난 결정과 근거

§7 W1 비고("산출물이 §3과 다르면 §3을 고치고 오케스트레이터에 보고")에 따른 보고 항목이다.
**모두 상수 한 줄 또는 데이터 한 줄로 되돌릴 수 있게 만들어 뒀다.**

### D-1. E계열 각인 3종만 승격 (§3.3 E)
§3.3 제목은 24종인데 실제 목록은 A8+B3+C5+D5=21종 + E계열 "어휘 8개"라 합이 안 맞는다.
E는 개별 각인 목록이 아니라 어휘 규정이므로, 그중 **칸 단위로 읽히는 3개**(damage·range·
pierce)만 각인으로 승격해 정확히 24종을 맞췄다. 나머지(hits·crit·lifesteal·knockback·
shield)는 §5.4에 따라 장비가 이미 담당하므로 중복 저작하지 않았다.
→ W7이 더 필요하다고 판단하면 `RUNES`에 같은 형식으로 추가하면 된다(`roll: false`).

### D-2. `kill_repeat`도 P_CAP·과열 감쇠를 탄다 (§3.3 A)
원문은 "확률 아님, 조건". 하지만 처치가 계속되는 밤 습격에서는 조건이 상시 참이 되어
확정 앙코르가 무한히 걸린다(STEP_CAP이 잡지만 매 사이클 과부하가 된다). 기본 확률 1.0에
§3.4의 공통 규칙(과밀 → 감쇠 → P_CAP)을 그대로 적용해 **조건 충족 시 최대 75%**로 만들었다.
실측(도륙 15장 + 처치율 100%): 평균 8.45스텝, STEP_CAP 도달 0.00%.

### D-3. 결속 구간의 과열 면제 → 반값 (`BOND_FIRE_COST = 0.5`) (§3.8)
원문은 "결속 구간 안에서 발동하는 각인은 과열을 올리지 않는다"(= 0.0).
0.0으로 실측하면 무한 루프는 없지만(STEP_CAP이 잡는다) 설계 내부 모순이 드러난다.

- §3.5의 핵심 아이디어("감쇠와 보상을 같은 카운터에 묶는다")가 결속 안에서만 꺼진다.
- §3.10의 대표 아키타입 **되감기 엔진**은 축이 "과열 극대화"인데 태그 전략이 3칸 결속이다.
  과열이 0이면 그 빌드의 코어 각인 `heat_gate`(과열 ≥3 조건)가 **영원히 안 터진다.**

실측(결속 덱 = 5칸 동일 원소 + 흐름 각인 최대, 2,000 사이클):

| `BOND_FIRE_COST` | 사이클당 발동 | 평균 최고 과열 | STEP_CAP 도달률 |
|---:|---:|---:|---:|
| 0.00 (원문) | 9.44 | 0.00 | 6.40% |
| 0.25 | 5.68 | 0.91 | 0.55% |
| **0.50 (채택)** | **4.44** | **1.78** | **0.05%** |
| 1.00 (특전 없음) | 3.27 | 3.03 | 0.00% |

0.5는 결속 특전(발동 +36% vs 특전 없음)과 과열 성장을 동시에 남기고, 감쇠가
`0.62^0.5n = 0.787^n`으로 여전히 기하 수렴한다. **상수 한 줄만 0.0으로 바꾸면 원문 복귀.**

### D-4. 스텝 내부 순서 변경 — 각인 판정을 카드 실행보다 앞으로 (§3.2)
원문 순서는 `damage_mul 계산(3) → 카드 실행(4) → 각인 판정(6)`이다. 그런데 C계열·E계열은
**이 칸의** 피해를 바꾸는 각인이라 카드보다 늦게 굴리면 수치가 성립하지 않는다.
`칸 진입 → 각인 판정 → 카드 실행(버프 반영) → 이동`으로 바꿨다. 피해에 쓰는 `heat`는
여전히 **굴리기 전** 값이라 §3.2 3번의 의미는 보존된다.
연출상으로도 "칸 진입 → 각인 플래시 → 강화된 카드 발동"이 더 잘 읽힌다(W2 연출 참고).

### D-5. 한 칸 중복 강화의 감쇠 4겹 (부록 C-1이 W1에 위임한 부분)
"한 칸 몰빵이 유일 정답이 되지 않게" 요구에 대한 답:

| 장치 | 값 | 효과 |
|---|---:|---|
| `RUNE_STACK_CAP` | 5 | 한 칸 각인 총 개수 하드 상한 |
| `SAME_ID_STACK_CAP` | 3 | 같은 id 사본 하드 상한 |
| `DUP_P_FALLOFF` | 0.55 | k번째 사본의 확률 기여 ×0.55^(k−1). 여집합 곱과 겹쳐 3사본 = 사실상 1.5사본 |
| `DUP_MAG_FALLOFF` | 0.60 | 수치형 각인(피해 +x%)의 중복 이득 ×0.60^(k−1) |
| `CONGESTION_FALLOFF` | 0.80 | 4개째부터 그 칸의 **모든** 확률 ×0.80^(초과수) — 기존 각인까지 깎는다 |
| (규칙) | — | **이동형 각인은 중복해도 delta가 커지지 않는다.** 확률만 오른다 |

마지막 규칙이 중요하다. 되감기 2장이 delta −2가 되면 `rewind_2`(희귀)의 존재 이유가 사라진다.

실측 근거: 같은 각인 3장을 한 칸에 몰면 합성 확률이 3칸에 흩어 놓은 것의 **47.6%**다
(`stack_vs_spread=0.4759`). 한 칸 몰빵 덱(0번 칸 5스택)은 평균 5.79스텝 / 발동 0.80회로,
5칸에 고르게 편 덱(8.98스텝 / 3.64회)에 완패한다. **"넓게 펴라"가 지배 전략으로 유지된다.**

### D-6. `bookmark`(각인점)의 동작 확정 (§3.3 A)
원문 "이 칸을 표식으로. 다른 칸에서 표식으로 점프"는 발동 주체가 모호하다.
결정적으로 확정했다: **발동 시 표식이 없거나 자기 자신이면 이 칸을 표식으로 설정하고
이동 없음. 표식이 다른 칸에 있으면 그 칸으로 점프하고 표식을 소모한다.**
점프는 delta보다 우선하며 방향은 유지된다.

### D-7. `heat`를 float 부하와 int 표시로 분리
`deviation_load`(float, 감쇠 지수) / `heat = clamp(floor(load) + heat_bonus, 0, HEAT_MAX)`
(int, 표시·피해·RELOAD). D-3의 반값 비용과 과충전 반응의 "무상 +1"을 §3.5의 단일 카운터
안에서 표현하기 위해 필요했다. 결속·과충전이 없으면 `load == 발동 횟수`라 §3.5와 동일하다.

## 6. 몬테카를로 결과 (32,000 사이클)

`RUNE_TEST_COMPLETE` 한 줄에 전부 나온다. 아래는 판독본이다.

### 6.1 종료성 — §3.9의 4중 안전망 실측

| 항목 | 결과 |
|---|---|
| 무한 루프 | **0회** (엔진 방어 가드 `HARD_LOOP_GUARD` 발동 0회) |
| STEP_CAP 초과 궤적 | **0개** (32,000 사이클 전부 ≤ 14스텝) |
| RELOAD 상한 초과 | **0회** (전부 ≤ 6.0초, 음수 0회) |

### 6.2 최악 빌드 — §3.9의 "기대 스텝 10.9" 대조

§3.9의 추정은 "5칸 기본 + 누적 발동 5.9회가 **전부 스텝을 늘린다**"는 계산이다.
즉 **스텝을 늘리는 흐름 각인만** 담은 덱이 그 추정의 대상이다
(5칸 × `rewind_1`+`rewind_2`+`repeat` × 확률 최대치, 2,000 사이클).

| 지표 | 설계 예측 | 실측 | 판정 |
|---|---:|---:|---|
| 평균 스텝 | ≈10.9 (요구 <11) | **8.98** | 요구 충족 |
| STEP_CAP 도달률 | <3% | **0.70%** | 요구 충족 |
| 사이클당 발동 | ≈5.9 | **3.64** | 아래 참조 |
| 평균 최고 과열 | — | **3.64** | §3.5 "평범 = 과열 3"과 일치 |

발동 횟수가 예측의 62%인 이유: §3.2의 정규 알고리즘은 **한 칸 안에서도** 각인이 하나
터질 때마다 `deviations`를 올린 뒤 다음 각인을 굴린다(원문 pseudo 6번 루프). 그래서 각인
3개짜리 칸의 기대 발동은 `0.75×3 = 2.25`가 아니라 **≈1.55**다. §3.9의 "스텝당 2.25"
추정이 이 칸 내부 감쇠를 빼먹었다. **정규 알고리즘(§3.2)을 따랐고 상수는 바꾸지 않았다.**

`HEAT_DECAY`를 올리면 예측값 10.9에 더 가까워지지만 STEP_CAP 도달률이 급격히 나빠진다
(같은 최악 빌드, 2,000 사이클):

| `HEAT_DECAY` | 평균 스텝 | STEP_CAP 도달률 | §3.9 요구(<11 · <3%) |
|---:|---:|---:|---|
| **0.62 (설계값·채택)** | **8.98** | **0.70%** | 충족 |
| 0.70 | 9.67 | 2.10% | 충족 (더 뜨거운 게임을 원하면 여기) |
| 0.76 | 10.36 | 8.05% | **도달률 위반** |
| 0.88 | 12.37 | 47.55% | 양쪽 위반 |

0.62가 §3.9의 두 요구를 모두 충족하므로 **바꾸지 않았다.** 10.9는 요구가 아니라 추정이었고,
요구는 "평균 <11 · 도달률 <3%"였다. 밸런스 패스에서 과열을 더 뜨겁게 하고 싶으면 0.70이
안전한 상한이다.

### 6.3 무작위 드래프트 인구 10,000 사이클

| 지표 | 값 |
|---|---:|
| 평균 스텝 | 5.13 |
| 사이클당 발동 | 1.22 |
| 평균 최고 과열 | 1.21 |
| STEP_CAP 도달률 | 0.00% |
| 평균 RELOAD | 4.32초 ← **주의, §6.5** |

과열 분포(최고 과열의 확률):

| 과열 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 비율 | 25.5% | 40.8% | 23.5% | 7.6% | 2.1% | 0.33% | 0.07% | 0.01% | 0.00% |

이 인구는 24종 전체에서 균등 추출한 **무작위** 덱이라 조건·확정 각인 비중이 높다.
의도적으로 조립한 덱의 기준선은 §6.4의 `archetype`을 보라.

### 6.4 극단·아키타입 조합 (각 2,000 사이클) — 전부 무한 루프·크래시 0

| 덱 | 구성 | 평균 스텝 | 발동 | 최고 과열 | STEP_CAP |
|---|---|---:|---:|---:|---:|
| `allin` | 0번 칸에 5스택 몰빵, 나머지 빈 칸 | 5.79 | 0.80 | 0.80 | 0.00% |
| `rewind5` | 5칸 전부 되감기 ×3 | 7.53 | 2.53 | 2.53 | 0.00% |
| `repeat5` | 5칸 전부 앙코르 ×3 | 7.29 | 2.29 | 2.29 | 0.00% |
| `reverse5` | 5칸 전부 역행 ×3 | 4.07 | 1.22 | 1.04 | 0.05% |
| `bookmark5` | 5칸 전부 각인점 ×3 | 6.55 | 1.73 | 1.62 | 0.10% |
| `link5` | 5칸 전부 연결 ×3 | 3.62 | 1.63 | 1.69 | 0.00% |
| `bond` | 5칸 동일 원소(결속 최대) + 흐름 최대 | 6.37 | 4.44 | 1.78 | 0.05% |
| `kill` | 도륙 ×15 + 처치율 100% | 8.45 | 3.45 | 3.45 | 0.00% |
| `mixed` | 전 방향 흐름 혼합(중립 대조군) | 5.87 | 3.08 | 3.16 | 0.00% |
| `archetype` | §3.10 되감기 엔진 (각인 7개 + 3칸 결속) | 5.97 | 1.85 | 0.48 | 0.00% |

빈 덱·빈 칸·존재하지 않는 각인 id에도 크래시 없음(`extreme_safe`가 검증).

### 6.5 W2·W7이 봐야 할 밸런스 신호 두 가지

**① RELOAD가 너무 무겁다.** 무작위 인구의 평균 RELOAD가 **4.32초**로 `RELOAD_CAP` 6.0초에
근접한다. §3.7의 빚 누적 모델(카드 실행마다 `card.reload` 가산) × 5스텝에 현행 카드의
`reload`(0.14~1.65, 평균 0.72)를 곱하면 구조적으로 이렇게 된다. 상한이 밸런스를 대신
떠받치고 있는 상태다. **W7이 카드 `reload` 값을 재저작할 때 v1 값을 그대로 옮기면 안 된다**
— v1은 "한 바퀴 합계"였고 v2는 "실행마다 가산"이라 같은 숫자가 다른 무게를 갖는다.
목표는 평범한 사이클 RELOAD 1.5~2.5초 수준이며, 카드 `reload`를 대략 절반으로 낮추는
것이 출발점이다.

**② §3.10 되감기 엔진 아키타입이 설계대로 작동하지 않는다.** 축은 "과열 극대화"인데
태그 전략이 3칸 결속이라 과열이 억제된다(실측 최고 과열 0.48). D-3에서 0.5로 완화해도
코어 각인 `heat_gate`(과열 ≥3)가 거의 안 터진다. **§3.8과 §3.10 중 하나를 고쳐야 한다.**
선택지: ㉮ 되감기 엔진의 태그 전략을 결속이 아닌 것으로 바꾼다 ㉯ `heat_gate` 문턱을
3 → 2로 낮춘다 ㉰ 결속 특전을 과열 면제가 아닌 다른 것(RELOAD 할인 등)으로 바꾼다.
**W1이 임의로 정하지 않았다. 오케스트레이터 판단 필요.**

## 7. 튜닝 상수 위치

전부 `rune_engine.gd` 상단에 모여 있다. `core/tuning.gd`(GameTuning)와 **겹치는 이름은
현재 하나도 없다**(GameTuning은 낮/밤·스폰·토스트·씬전환만 가진다). `RELOAD_CAP` 등을
게임 전역으로 승격하고 싶으면 W2가 GameTuning으로 옮기고 여기서는 참조만 남길 것 —
W1 시점에 옮기면 W0 산출물을 수정하게 되므로 하지 않았다.

| 그룹 | 상수 |
|---|---|
| 흐름(§9.1) | `SLOT_COUNT` `START_SLOTS` `RUNE_SLOTS_PER_SLOT` `HEAT_MAX` `HEAT_DECAY` `HEAT_DAMAGE` `HEAT_RELOAD` `REENTRY_FALLOFF` `P_CAP` `STEP_CAP` `REPEAT_CAP` `RELOAD_CAP` |
| 중복 강화(부록 C-1) | `RUNE_STACK_CAP` `SAME_ID_STACK_CAP` `DUP_P_FALLOFF` `DUP_MAG_FALLOFF` `CONGESTION_FALLOFF` |
| 태그(§3.8) | `BOND_MIN_RUN` `BOND_FIRE_COST` `RESONANCE_DAMAGE` `TRIANGLE_RELOAD_DISCOUNT` `OVERCHARGE_HEAT_BONUS` `STEAM_RANGE_BONUS` `SHOCK_SPLASH` |
| 동시 발동 | `ECHO_POWER` `CHORUS_POWER` `OVERLAP_POWER` `LINK_POWER` |
| 템포 | `TOLL_REFUND` `LAST_CALL_REFUND` `HEAT_GATE_MULT` `HEAT_GATE_MIN` `ODD_RANGE_BONUS` |
| 방어 | `HARD_LOOP_GUARD` (여기 걸리면 엔진 버그다. 테스트가 `end_reason=="guard"`로 잡는다) |

## 8. W2 · W6 · W7 체크리스트

**W2 (사이클 런타임)**
- `simulate_cycle`을 사이클 시작 시 한 번 호출하고 `steps[]`를 프레임에 펼쳐라.
  스텝 도중 다시 굴리면 결정성이 깨진다.
- 시드는 명시적으로 넘겨라(런 시드 + 사이클 번호 권장). 세이브에 넣으면 리플레이가 된다.
- `kills` 배열로 실제 처치 결과를 주입해야 `kill_repeat`이 동작한다. 미주입 시 미발동.
  실전에서는 처치 여부가 카드 실행 후에야 확정되므로, 궤적을 스텝 단위로 재계산하는
  증분 모드가 필요하면 `resolve`를 직접 스텝마다 호출하고 ctx를 손으로 갱신하라
  (`simulate_cycle` 본문이 그 참조 구현이다).
- 시그널 매핑: `slot_entered` ← `step.slot`/`step.reentry`, `rune_fired` ← `step.fired[]`,
  `heat_changed` ← `step.heat`, `debt_changed` ← `step.debt`,
  `cycle_completed(steps, max_heat)` ← `step_count`/`peak_heat`, `overloaded()` ← `overloaded`.
- `carry_heat`를 다음 사이클의 `opts.start_load`로 넘겨야 `afterburn`(잔열)이 동작한다.
- 보스 RELOAD ×0.6은 `opts.reload_scale`.

**W6 (편집 화면·드래프트)**
- 미리보기는 `preview(deck, seed, 64)`. 칸을 옮길 때마다 다시 부르면 된다(2,000 사이클
  기준 3.5초이므로 64 샘플은 체감 즉시).
- 레일 위 배지: `bond_mask` / `resonance_bonus` / `triangle_ok`를 그대로 그려라.
- 드래프트 UI는 "**강화할 칸을 고르세요**"로 묻고, `attach_rune`이 `false`를 반환하면
  상한 초과다(총 5개 / 같은 id 3개). 4개째부터 과밀 페널티가 붙는다는 것을 반드시 표시할 것
  — 안 그러면 플레이어가 몰빵하고 왜 약해지는지 모른다.
- 각인 툴팁의 실효 확률은 `effective_probability(merged_probability(...), 0.0, congestion_scale(n))`.

**W7 (콘텐츠 데이터)**
- 카드에 `element`(6종) / `form`(5종) 키를 추가해야 §3.8 전체가 켜진다. 현재
  `deal_card_library.gd`에는 없어서 공명·결속·삼각·반응이 전부 비활성이다.
- `reload` 값 재저작 필수(§6.5 ①).
- 각인 드래프트 풀은 `ids_by_rarity` / `ids_by_family`로 구성하고, 인스턴스는 반드시
  `roll_rune(id, rng)`로 만들어라. `p`를 직접 박으면 §3.3의 "같은 각인이라도 다른 물건"
  감각이 사라진다.
