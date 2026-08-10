# handoff-y1 — 규칙·데이터 골격 (Y 라운드 첫 웨이브 · `game.gd` 미접촉)

2026-08-09 · 웨이브 **Y1**(설계 문서 §9.3의 **Y0**) · 근거 `docs/FEEDBACK_Y.md` §1~§5 · §7.2 · §7.3

수정 파일 9개 — `scripts/core/rune_engine.gd`(전면 재작성) · `scripts/factory_deck.gd` ·
`scripts/deal_card_library.gd`(재저작) · `scripts/monster_library.gd` · `scripts/core/tuning.gd` ·
`scripts/core/status_engine.gd`(1건 가산) · `scripts/test/rune_test.gd`(전면 재작성) ·
`scripts/test/data_test.gd`(갱신) · `docs/handoff-y1.md`(이 문서)

**한 줄도 안 건드린 것**: `game.gd` · `enemy.gd` · `world_grid.gd` · `combat_resolver.gd` ·
`deal_cycle_controller.gd` · `test_runner.gd` · `run_all.sh` · `ui_kit.gd` · `status_test.gd` ·
`balance_probe.gd` · `art/` 전부. git 커밋 0건.

원본 보존: `docs/v1-archive/rune_engine_v3_24.gd.txt` · `deal_card_library_v3_x1.gd.txt` ·
`monster_library_v3.gd.txt` · `rune_test_w1.gd.txt`

---

## 0. 한 문장

**과열을 「한 칸은 한 바퀴에 두 번까지」(`SLOT_EXEC_CAP = 2`)로 갈아끼워 종료성을 확률에서
산수로 옮기고, 각인 24종을 칸 10 + 레일 5 = 15종으로 전면 교체하고, 속성 7계의 한자를 버리고
색을 다시 배정하고, 스킬 28장을 「쌓는다 / 터뜨린다」 콤보 언어로 다시 썼다.
`game.gd`는 아직 옛 API를 부르지만 deprecated 셔틀 덕에 컴파일과 실행이 살아 있다.**

---

## 1. 검증 결과 (전부 이 웨이브가 직접 실행)

| 검사 | 결과 |
|---|---|
| `godot --headless --path godot-game --editor --quit` | **오류 0 · 경고 0 · 종료 코드 0** |
| `-s res://scripts/test/rune_test.gd` | **PASS** · 판정 35/35 `=true` · 종료 코드 **0** |
| `-s res://scripts/test/data_test.gd` | **PASS** · 판정 32/32 `=true` · 종료 코드 **0** |
| `--status-test` (status_engine 가산 회귀) | **PASS** · 7묶음 전부 `=true` · `status_test.gd` 무접촉 |
| 음성 대조 | rune_test 3건 주입 → `RUNE_TEST_FAILED` · data_test 3건 주입 → `DATA_TEST_FAILED` |
| `run_all.sh` | **실행하지 않음**(다른 에이전트와 경합 · 설계 지시대로) |

`godot-game/` 안 임시 파일 잔여 **0건**.

> **`--editor --quit`이 통과한다는 것이 이 웨이브의 핵심 성과다.** 각인 id가 전부 바뀌었는데도
> 13,436줄짜리 `game.gd`가 컴파일된다 — deprecated 셔틀(§4)이 그 값을 한다.

---

## 2. 각인 15종 최종표 (§2.1 · §2.2)

### 칸 각인 10종 (`scope: "slot"`)

| # | id | 이름 | family | cond | roll | p | mag | 레어 |
|---|---|---|---|---|---|---|---|---|
| 1 | `twice` | 두 번 치기 | flow | always | ✓ | 0.35–0.60 | 1.0 | 일반 |
| 2 | `back_one` | 한 칸 뒤로 | flow | always | ✓ | 0.30–0.55 | 1.0 | 일반 |
| 3 | `jump_one` | 한 칸 건너뛰기 | flow | always | ✓ | 0.35–0.60 | 1.0 | 일반 |
| 4 | `strong` | 힘주기 | combat | always | — | 1.0 | 0.25–0.40 | 일반 |
| 5 | `wide` | 넓히기 | combat | always | — | 1.0 | 0.20–0.35 | 일반 |
| 6 | `quick` | 서두르기 | tempo | always | ✓ | 0.40–0.65 | 1.0 | 희귀 |
| 7 | `first_hit` | 첫 칸 힘 | conditional | `first` | — | 1.0 | 0.50–0.80 | 희귀 |
| 8 | `twin_cast` | 쌍둥이 | parallel | `prev_slot` | ✓ | 0.40–0.65 | 0.5 | 희귀 |
| 9 | `trade_skip` | 두 번 치고 건너뛰기 | flow | always | — | 1.0 | 1.0 | 영웅 |
| 10 | `finisher` | 마무리 | flow | `kill` | — | 1.0 | 1.0 | 영웅 |

### 레일 각인 5종 (`scope: "rail"`)

| # | id | 이름 | family | roll | p | mag | 레어 |
|---|---|---|---|---|---|---|---|
| 11 | `rail_fast` | 빨리 감기 | tempo | — | 1.0 | 지속 −15% | 일반 |
| 12 | `rail_power` | 모두 힘주기 | combat | — | 1.0 | 피해 +12% | 희귀 |
| 13 | `rail_rest` | 짧은 휴식 | tempo | — | 1.0 | 쉬는 시간 −20% | 희귀 |
| 14 | `rail_color` | 같은 색 보너스 | combat | — | 1.0 | +25%(공명 가산) | 희귀 |
| 15 | `rail_loop` | 되돌이 | flow | ✓ | 0.45–0.65 | 1.0 | 영웅 |

**계약 3개가 테스트로 못 박혀 있다**: 15키 정확 · 일반 6/희귀 6/영웅 3 ·
`family == "flow"`가 정확히 `{twice, back_one, jump_one, trade_skip, finisher, rail_loop}` 6종
(§2.6의 `RUNE_SHOP_FLOW_PREMIUM` 대상 목록과 **집합 동등** — 상점 가격식이 여기 걸려 있다).
폐기 24종 id는 카탈로그·`rune_scope()`·`roll_rune()` 삼중으로 부재 확인.

### 데이터 모델 신설
```gdscript
const SLOT_EXEC_CAP := 2                  # 한 칸은 한 바퀴에 두 번까지
const STEP_CAP := 2 * SLOT_COUNT + 2      # = 12. 게임 규칙이 아니라 방어 단언
const RAIL_RUNE_CAP := 3
const RAIL_SAME_ID_CAP := 1
"scope": "slot" | "rail"                  # 각인 정의 새 키
opts["rail_runes"]: Array[Dictionary]     # simulate_cycle 새 입력
FLOW_DELTA = {"back_one": -2, "jump_one": 1}   # "정상 다음 칸 대비 오프셋"으로 재정의
```
`FLOW_DELTA` 재정의 근거: 이동식이 `move = 1 + delta`라서 `back_one`은 `move = -1`(바로 앞 칸),
`jump_one`은 `move = 2`(다음 칸 건너뜀)가 된다. §2.1의 문구와 정확히 일치한다.

칸 감쇠 4겹(`RUNE_STACK_CAP 5` · `SAME_ID_STACK_CAP 3` · `DUP_P_FALLOFF 0.55` ·
`CONGESTION_FALLOFF 0.80`)과 `RESONANCE_DAMAGE 0.15`는 **값 그대로 유지**(§2.4).

---

## 3. 종료성 — 확률이 아니라 산수 (§1.3)

### 이동 알고리즘 (`simulate_cycle`)
```
1. 앙코르(twice / finisher / trade_skip)는 executed[cursor] < 2일 때만 소비. 막히면 조용히 버린다
2. move = 1 + delta + carried_delta
3. raw = cursor + direction * move  (역방향은 경계에서 클램프)
4. 진행 방향 이탈 → rail_loop가 무장돼 있고 미사용이면 방향 반전, 아니면 "complete"
5. 건너뛰기 스캔: executed[raw] >= 2 이면 진행 방향으로 다음 칸을 훑는다
6. 스캔이 범위를 벗어나면 "all_used"
```

### 실측 (25,001 사이클)

| 인구 | 사이클 | 평균 스텝 | 최대 스텝 | `overload` | `guard` | `slot_exec > 2` |
|---|---|---|---|---|---|---|
| 무작위(n 1–5 · 각인 0–5 · 레일 0–3) | 10,000 | **3.86** | **10** | **0** | **0** | **0** |
| 흐름 확정 최대 | 2,000 | 9.10 | 10 | 0 | 0 | 0 |
| `rail_loop` + 흐름 최대 | 2,000 | 9.76 | 10 | 0 | 0 | 0 |
| `trade_skip` + `finisher`(kill 1.0) | 2,000 | 6.00 | 6 | 0 | 0 | 0 |
| 각인 0개 순수 5칸 | 2,000 | 5.00 | 5 | 0 | 0 | 0 |
| 엣지 스윕(n=1–5 · 방향 ±1 · p 1.0) | 나머지 | — | **정확히 2n** | 0 | 0 | 0 |

칸 수별 최대 스텝 `{n1:2, n2:4, n3:6, n4:8, n5:10}` — **2n 상한이 tight하게 달성된다.**
평균 RELOAD 2.26초.

**새 회귀 계약**: `end_reason == "overload"` **0건**(구 「과부하율 0.70%」를 대체) ·
`max(slot_exec) ≤ 2` 위반 0건 · `step_count ≤ 2n` 위반 0건.

### `rail_loop` 10스텝 (§2.2 "이번 설계의 상징")
400시드 중 무장된 299건 **전부**가
`step_count == 10` · `visited == [0,1,2,3,4,4,3,2,1,0]` · `slot_exec == [2,2,2,2,2]`.
대조군(레일 각인 없음) 5스텝 `[0,1,2,3,4]`.

---

## 4. deprecated 셔틀 — `game.gd`를 살려 둔 장치

과열은 규칙에서 사라졌지만 **심볼은 전부 남아 있고 중립값을 돌려준다.** 각 지점에
`# DEPRECATED (Y0) — 소비자 제거는 Y2 몫` 주석이 붙어 있다(28곳).

**상수**: `HEAT_MAX` 8(게임이 8핍 루프를 돈다) · `HEAT_DECAY` **1.0** · `HEAT_DAMAGE` **0.0** ·
`HEAT_RELOAD` **0.0** · `REENTRY_FALLOFF` **1.0** · `HEAT_GATE_MIN` 2 · `BOND_MIN_RUN` 3 ·
`BOND_FIRE_COST` **1.0** · `TRIANGLE_RELOAD_DISCOUNT` **0.0** · `OVERCHARGE_HEAT_BONUS` **0** ·
`REPEAT_CAP` 2 · `ECHO_POWER` · `CHORUS_POWER` · `OVERLAP_POWER` · `LINK_POWER` ·
`SHOCK_SPLASH` · `STEAM_RANGE_BONUS` · `IGNITE_POTENCY_MULT` · `PLAGUE_POTENCY_MULT` ·
`SHATTER_PREP_STUN` · `RESONANT_DRAIN_RELOAD` · `ELEMENTS` · `FORMS` · `REACTIONS` ·
`REACTION_WILDCARD` · `RARITY_*` · `DEFAULT_CARD`

**무동작화한 함수**: `heat_from_load()` → 항상 0 · `damage_multiplier()` → 항상 1.0 ·
`bond_mask()` → 전부 false · `triangle_ok()` → 항상 false ·
`effective_probability()` → load 무시 · `condition_ok("heat_gate")` → 항상 false.
나머지 함수 30개는 시그니처 무변경.

**반환 Dictionary 셔틀 키**: `heat_curve`(0) · `peak_heat`(0) · `end_heat`(0) ·
`deviation_load`(0.0) · `carry_heat`(0) · `overloaded`(방어 단언 도달 시에만).
스텝 레코드 23키 전건 유지(`heat` 0 · `reverse` false · `link` −1 · `bond` false).

**신설**: `rune_scope(id)` · `ids_by_scope(scope)` · `resolve_rail()` ·
결과 키 `slot_exec` / `rail_loop_armed` / `rail_fired` · `preview().mean_exec_slots`.
참조 0건이던 `TOLL_REFUND` · `LAST_CALL_REFUND` · `HEAT_GATE_MULT` · `ODD_RANGE_BONUS`는 삭제.

**셔틀이 실수로 되살아나면 잡힌다** — `rune_test.heat_neutral` · `data_test.rune_heat_neutral`.

### `FactoryDeck` 레일 각인
`var rail_runes: Array[Dictionary]` + `attach_rail_rune()` / `detach_rail_rune()` /
`rail_rune_ids()` / `rail_rune_count()` / `rune_opts()`.
`attach_rune()`은 `scope == "rail"` 각인을 **거부**한다. `rune_deck()`은 시그니처·동작 무변경.
**직렬화는 붙이지 않았다** — 저장 키 `rail_runes`는 schema 4에서 Y6가 붙인다.

---

## 5. 속성 재작명과 색 재배정 (§3.2)

| 내부 id(**불변**) | 구 표시 | **새 이름** | 구 색 | **새 색** | 색 이름 |
|---|---|---|---|---|---|
| `fire` | 화(火) | **불** | `e78a45` | **`e2452f`** | 빨강 |
| `ice` | 빙(氷) | **얼음** | `67c7d4` | `67c7d4` | 하늘 |
| `thunder` | 뇌(雷) | **번개** | `f4d35e` | `f4d35e` | 노랑 |
| `poison` | 독(毒) | **독** | `83c65c` | `83c65c` | 연두 |
| `oil` | 유(油) | **기름** | `7563a8` | **`7a5230`** | 갈색 |
| `strike` | 타(打) | **타격** | `c3bda4` | `c3bda4` | 회색 |
| `psi` | 초(超) | **정신** | `bd6ac8` | `bd6ac8` | 자주 |

### 스테일 `color` 키 버그 — 데이터 쪽은 고쳤다 (§3.3 ⚠️ · 리스크 ⑩)
카드별 `color`가 원소와 **완전히 무관**했다. 실사로 확인한 대표 사례:
`thunder`(번개) 카드가 청록 `67c7d4` · `whirlwind`(독) 카드가 붉은색 `d95763` ·
`cross_cut`(독) 카드가 크림색 `fff3d0`.
→ **40장 중 36장의 `color`를 그 카드 원소의 새 색으로 정합**시켰다(이미 맞던 4장 제외).
`BASIC`은 원소가 없어 `f4d35e` 유지. `color` 키 자체는 VFX(`cycle_skill_effect.gd`)가 아직
읽으므로 지우지 않았다 — 키를 VFX 전용으로 좁히는 것은 Y4의 일이다.
회귀 방지로 `data_test.card_color_matches_element` 신설.

> ⚠️ **지금 `game.gd`의 `ELEMENT_COLOR`(`:1888`)는 아직 옛 주황/보라다.** 카드 `color`와
> 서로 다른 값을 가진 상태이므로 **불·기름 두 원소에서 HUD와 카드가 다른 색을 그린다.**
> Y4가 `ELEMENT_COLOR`를 올리면 해소된다(§9 목록 D).

---

## 6. 스킬 28종 콤보 언어 (§4.1~4.5)

`id` 42개 · 수치 18키 · `element` · `form` · 배열 순서 **전부 무변경**.
`name` · `desc` 교체 + **`combo` · `impact` · `silhouette` 3키 신설.**

### 형식 (§4.2)
`desc` = 무엇을 하는가(횟수 포함) **≤16자** · `combo` = 무엇과 어울리는가 **≤18자**.
40장 실측 위반 **0건**(`data_test.card_text_limits`가 감시).

### 이름 대조 (28장)
| id | 구 → 신 | | id | 구 → 신 |
|---|---|---|---|---|
| flame_field | 업화의 장막 → **불바다** | | gravity_well | 기름 늪(동일) |
| meteor_blade | 운석검 강림 → **불덩이 세 개** | | sword_rain | 역청 폭우 → **기름 비** |
| earth_splitter | 용암 균열 → **용암 가르기** | | aura | 역청 안개 → **기름 안개** |
| lion_roar | 업염 사자후 → **불사자 포효** | | boomerang_blade | 역청 회귀검 → **기름 회귀검** |
| dash_blade | 설한 섬격 → **서리 돌진** | | cleave | 반월참 → **반달 베기** |
| frost_ring | 빙결 파문 → **얼음 물결** | | rapid_slash | 삼연참(동일) |
| guardian_blade | 빙정 호위검 → **얼음 호위검** | | thrust | 관통 창격 → **관통 찌르기** |
| moon_barrier | 빙정 결계 → **얼음 방패** | | recursion | 회귀 검기 → **되돌이 검기** |
| thunder | 뇌전 심판 → **벼락 심판** | | shield_bash | 염동 방패치기 → **방패 밀치기** |
| time_cut | 섬전 순참 → **번개 교차베기** | | holy_pulse | 초념 파동 → **정신 파동** |
| targeting | 뇌창 유도 → **번개 창** | | battle_trance | 초월 명상 → **정신 집중** |
| phantom_step | 뇌영 잔상진 → **번개 잔상** | | blade_fan | 염동 검선 → **정신 부채** |
| whirlwind | 역병 회전참 → **독바람 회전** | | | |
| blood_pact | 역병의 서약 → **독의 서약** | | | |
| execution | 독월 처형 → **독의 처형** | | | |
| cross_cut | 맹독 십자참 → **맹독 십자** | | | |

SPECIALS 12장도 같은 형식으로 재작성(예: 천상문 개방 → **열린 하늘문** ·
불멸의 광란 → **죽지 않는 광란** · 영겁 회귀 창술 → **끝없이 도는 창**).

### 실루엣 (§4.4) — 아이콘 절반값의 근거
`SILHOUETTES` 14종(인덱스 0~13, §4.4 표 순서):
`slash · combo_slash · heavy_slash · thrust · dash · throw · homing · chain · wave · orbit · field · rain · vortex · shield`
**유일성 계약 충족** — `(element, silhouette)` **28쌍 전부 고유**.
`silhouette_pairs_unique()` 신설 + `data_test.silhouette_unique`가 감시.

### 충격 프로필 (§7.3)
`IMPACTS` 8종. 문서 지정 16장은 그대로, 표에 없던 12장은 데이터 쪽에서 배정하고 근거를 주석으로 남겼다
(`targeting`=pin · `thunder`=stagger · `whirlwind`=push · `cross_cut`=pop · `recursion`=pop 등).
`knockback_profile()`은 **지우지 않고** authored `impact` 우선 분기를 앞에 넣었다. 기존 `kind` 기반 값은 폴백.

### `cross_cut`의 "두 배로 쌓는다" (§4.5)
카드 데이터에 `"status_stack_bonus": 2.0` **한 장에만** 추가.
`status_engine._row_poison()`에 `stack_bonus` 채널 1건 가산(**기본값 1.0** · 첫 부여 경로는 1.0 고정):
```gdscript
"poison": _row_poison(state, strength, p, maxf(1.0, float(ctx.get("stack_bonus", 1.0))), out)
```
`status_test` **무접촉 PASS** — 동작이 한 톨도 안 바뀌었다는 증거다.
`combat_resolver`가 카드 키를 `ctx`로 넘기는 배선은 후속 웨이브 몫. 한(chill) 강화 계수는 열지 않았다.

---

## 7. 몹 패턴 데이터 (§5.2 · §5.4 · §7.2)

`behavior`(1~4)는 **한 줄도 안 바꿨다**(62개 호출부). 그 위에 직교 축을 얹었다.

| id | 이름 | behavior | **habit** | kb / stun / slow | 피격 연출 |
|---|---|---|---|---|---|
| mossling | 이끼콩 | 1 | herd 무리 | 1.6 / 1.4 / 1.3 | 튕겨 날아가며 이끼 조각이 흩어진다 |
| boar | 들멧돼지 | 2 | guard 텃세 | 0.5 / 0.7 / 0.8 | 버티고 서서 흙먼지 (+`kb_zero_while_charging`) |
| imp | 뿔임프 | 3 | herd 무리 | 1.1 / 1.0 / 1.0 | 뒤로 한 바퀴 구른다 |
| wolf | 붉은 늑대 | 4 | hunt 사냥꾼 | 1.3 / 0.8 / 1.2 | 옆으로 쭉 미끄러진다 |
| skeleton | 떠도는 해골 | 2 | guard 텃세 | 1.0 / **1.5** / 0.6 | 뼈 조각이 튀고 한참 굳어 있는다 |
| shade | 굶주린 그림자 | 4 | stalk 매복 | 1.8 / 1.2 / 1.5 | 반쯤 흩어졌다가 다시 뭉친다 |
| wisp | 푸른 위습 | 3 | shy 겁쟁이 | **2.0** / 1.0 / 1.4 | 저 멀리까지 밀려난다 |
| ogre | 황야 오우거 | 2 | guard 텃세 | **0.25** / 0.4 / 0.7 | 거의 밀리지 않고 한 걸음만 물러난다 |
| cultist | 잠식 주술사 | 3 | stalk 매복 | 0.9 / 1.1 / 1.0 | 후드가 크게 흔들린다 |
| hellhound | 밤의 지옥견 | 4 | hunt 사냥꾼 | 0.7 / 0.6 / 1.1 | 발톱으로 땅을 긁으며 버틴다 |

신설 상수: `HABITS`(5) · `HABIT_SHY_FLEE_RANGE 260` · `HABIT_HERD_RADIUS 230` ·
`HABIT_HERD_SPAWN_MIN/MAX 3/5` · `HABIT_HERD_SPAWN_RADIUS 120` ·
`HABIT_STALK_NIGHT_SPEED 1.20` · `HABIT_HUNT_DAY_STAGE 3`.
조회: `habit_of()` · `habit_name()` · `habit_desc()` · `habit_ids()` · `habit_table_ok()` ·
`reaction_profile()` · `reaction_table_ok()` · `habit_terrain_scale()`.

### 지형 × 습성 가중 (§5.3 · 데이터만)
풀(grass/tuft/flower) `herd` ×1.8 · 숲 `stalk` ×2.2 · 바위 `guard` ×1.8 ·
물가(`shore_*`) `shy` ×1.6 · 폐허 `hunt` ×1.5.

> ⚠️ **실제 WFC 타일 이름은 `grass_tuft` / `grass_flower`다**(`wfc_chunk_generator.gd:76-77`).
> §5.3이 적은 `tuft` / `flower`로만 두면 배선 후에도 풀 행이 영원히 안 걸린다.
> `habit_terrain_scale()`이 실제 이름을 스펙 키로 접어 준다.
> 또 `world_grid.gd`에는 `get_tile_id()`(int)만 있고 §5.3이 가정한 `tile_kind_at()`은 **없다.**
> Y5가 만들어야 한다.

### 낮 선공 0 (§5.4)
```gdscript
static func stage_aggro_gate_ok(stage: int, night: bool) -> bool:
	return night or stage >= 3      # 이전: stage >= 2
```
효과 실측: 1스테이지 낮 무변경(원래 선공 0) · **2스테이지 낮에서 wolf가 사라진다** ·
3스테이지 이상 무변경 · 밤은 전 스테이지 무변경.
일수 축(`aggro_gate_ok` · `AGGRO_DAY_UNLOCK_CYCLE`)은 건드리지 않았다.

> ⚠️ **§5.4가 약속한 "도망가는 것들도 남는다"는 아직 성립하지 않는다.** `shy`가 붙은 종은
> `wisp` 하나뿐이고 3스테이지에 해금된다. 1·2스테이지 낮은 **무리 + 텃세뿐**이다.
> 도망 그림을 정말 원하면 `shy`를 1티어 종에 하나 더 붙여야 한다 — 설계 판단이 필요하다.

---

## 8. 밸런스 상수 (§5.5 · §1.6 · §2.6)

| 상수 | 이전 | **새 값** |
|---|---|---|
| `MonsterLibrary.CYCLE_HEALTH_GAIN` | 0.24 | **0.16** |
| `STAGE_HP_BASE` | `[1.00,1.55,2.10,2.65,3.20]` | **`[1.00,1.35,1.70,2.05,2.40]`** |
| `DWELL_HP_LINEAR` | 0.14 | **0.10** |
| `DWELL_HP_QUAD` | 0.012 | **0.007** |
| `DWELL_COUNT_STEP` | 3 | **4** |
| `DWELL_COUNT_SATURATION` | 6 | **8** |
| `DWELL_ELITE_STEP` | 0.03 | **0.04** |
| `DWELL_ELITE_CAP` | 0.35 | **0.45** |
| `NIGHT_ENEMY_LIMIT_STEP` | 4 | **5** |
| `BOSS_RELOAD_MUL` | 0.6 | **0.42** |
| `RUNE_SHOP_RAIL_PREMIUM` | — | **1.20**(신설) |

`MAX_ENEMIES 78` 무변경. `STAGE_BOSS_RELOAD_MUL` 0.75 / `_ENHANCED` 0.55 무변경(Y8 재측정 대상).
`RUNE_SHOP_PASSIVE_PREMIUM` 1.15 **값 유지 · 근거 문구만 교체**
("과열을 한 톨도 안 올린다" → **"굴리지 않고 항상 켜져 있다"**).

### ⚠️ 설계 문서 §5.5의 산수 오류 2건 (문서를 고쳐야 한다)

```
hellhound @ power_level 13.6
  0.24 → 16.0 × 10.0 × (1 + 0.24×13.6) = 682.2 HP   ← 문서의 682 맞음
  0.16 → 16.0 × 10.0 × (1 + 0.16×13.6) = 508.2 HP   ← 문서는 560이라 적었다. 실제 508

dwell H(12)
  구 1 + 0.14(12) + 0.012(144) = 4.408                ← 문서의 ×4.4 맞음
  신 1 + 0.10(12) + 0.007(144) = 3.208                ← 문서는 ×2.2라 적었다. 실제 ×3.21
```
×2.2는 `1 + 0.10×12`와 정확히 같다 — **문서를 쓸 때 2차항을 빠뜨렸다.**
코드에는 정정값과 "계산값이지 실측이 아니며 Y8이 재확정한다"를 함께 적어 뒀다.
**`docs/FEEDBACK_Y.md` §5.5의 「560 HP」와 「×2.2」를 고쳐야 Y8이 잘못된 목표를 쫓지 않는다.**

### ⚠️ 세 축이 곱해진 총량이 §5.5가 암시한 것보다 훨씬 크다
5스테이지 · dwell 12 · power_level 13.6에서 세 축의 곱이 **60.1 → 24.5 = 몹 HP −59%**다.
`STAGE_HP_BASE` 행만 보면 −25%로 읽히지만 실제는 그 두 배가 넘는다.
수입은 dwell 12에서 XP −14.7% · 골드 −11.9%. 킬당 효율 0.476 → 0.558로 여전히 1 미만이라
체류 압박의 **방향**은 살아 있지만 눌리는 힘이 약해졌다. **Y8이 반드시 실측할 것.**

### ⚠️ 결정이 필요한 불변식 1건
`test_runner.gd:3969`가 **`DWELL_DAMAGE_LINEAR × 2.0 == DWELL_HP_LINEAR`** 를 단언한다.
구값 `0.07 × 2 = 0.14` ✓ → 신값 `0.07 × 2 = 0.14 ≠ 0.10` **깨진다.**
§5.5는 **HP 세 축만** 내리라고 했고 피해 축은 언급하지 않았다. 두 갈래다.

- **(가) 0.07 유지 + 단언 교체** — 설계 의도("난이도는 HP가 아니라 패턴·물량")에 맞는다.
  dwell이 깊어질수록 몹이 상대적으로 더 아파지므로 체류 압박이 HP 벽이 아닌 형태로 남는다.
  **이 웨이브의 권고안이다.** Y5/Y8이 `--stage-test`의 곡선 표를 새 값으로 갈아끼우면서 이 줄을 지운다.
- **(나) `DWELL_DAMAGE_LINEAR` 0.07 → 0.05** — 불변식은 지켜지지만 몹 피해도 함께 내려가
  "난이도를 올린다"는 §5.5의 방향과 반대로 간다.

**밸런스 판단이라 이 웨이브 범위 밖이다. Y8이 결정한다.**

### ⚠️ 지금 무효인 변경 2건
- `NIGHT_ENEMY_LIMIT_STEP` — 리포지토리 전체에 **소비자 0건**이다
  (`stage_clock.gd:281`이 `dwell_count_bonus`를 쓴다). 4→5는 현재 no-op이고,
  실제 밤 물량 상향은 `DWELL_COUNT_STEP` 쪽에서 온다.
- `RUNE_SHOP_RAIL_PREMIUM` — 선언만 됐고 읽는 곳이 없다. Y3이 `game.gd:9933~9950`의
  가격식에 항을 넣어야 산다.

---

## 9. 후속 웨이브 수정 목록 (직접 고치지 않았다)

### A. Y2 — 런타임이 죽은 각인을 보고 있다 (**최우선**)

| 위치 | 문제 |
|---|---|
| `deal_cycle_controller.gd:234-235` | `_rolled(step,"echo")`가 영원히 false. **`twin_cast`가 런타임에 발사되지 않는다** — 엔진의 `damage_total`에는 쌍둥이 피해가 들어 있어 **계획 피해 > 실제 피해** 괴리가 생긴다. `"echo"`→`"twin_cast"` · `ECHO_POWER`→`TWIN_POWER` |
| `deal_cycle_controller.gd:240,243` | `_rolled(step,"chorus")` 영원히 false → 블록 삭제 |
| `deal_cycle_controller.gd:229,231` | `step["link"]`가 항상 −1 → 죽은 코드 삭제 |
| `deal_cycle_controller.gd:237` | `passive_magnitude(...,"overlap")` 항상 0.0 → 삭제 |
| `deal_cycle_controller.gd:164,171` | `rune_deck()`만 넘기고 **`rail_runes` 미주입** → 레일 각인이 실전에서 전혀 작동하지 않는다. `opts.merge(factory.rune_opts())` |
| `game.gd:2717` | 편집 미리보기도 `rail_runes` 미주입 → 미리보기와 실전이 **함께** 틀린다 |
| `game.gd:1845-1847` | 각인 → 흐름 배너 매핑이 구 id 8종 |
| `game.gd:2612-2613` | 미리보기 델타 표가 구 id 8종. 새 `FLOW_DELTA`(`back_one:-2` · `jump_one:+1`)와 정합 필요 |
| 과열 HUD | `game.gd:1581-1583 · 1728 · 1741-1742 · 2084-2087 · 2142 · 2156 · 2172-2173 · 2271 · 2713-2721 · 5866-5867 · 11231 · 11482 · 11953 · 11961-11966` 전부 0을 그린다. §1.4대로 **8핍 온도계 → 밟은 횟수 점 1~2개** |
| 결속·삼각 | `game.gd:3313-3376` 정보 패널이 "없음" 고정. §2.5대로 `EDIT_BOND_RECT (42,342,1156,8)` 자리를 레일 각인 글리프 줄로 |
| `game.gd:11482` | 결과 화면 「최고 과열」 칩 → **「한 바퀴 최다 칸 수」** |

### B. Y3 — 게임플레이 파손: 레일 각인이 칸 상점에 섞여 나온다

| 위치 | 문제 |
|---|---|
| `game.gd:7303` `_roll_rune_draft` | `all_rune_ids()`를 그대로 돌려 **레일 각인 5종이 칸 3택1에 등장**한다. 고르면 `attach_rune`이 거부해 **죽은 선택지**가 된다 → `RuneEngine.ids_by_scope("slot")` 또는 레일 부착 UI 분기 |
| `game.gd:561` · `11119` | `demon_lord.set_rune_catalog(all_rune_ids())` — 마왕이 레일 각인을 칸에 주려다 `:11130`에서 조용히 실패 |
| `game.gd:8143` | 전조 덱 같은 경로 |
| `game.gd:9933-9950` | `RUNE_SHOP_RAIL_PREMIUM` 항 추가(§2.6) |

### C. Y4 — 색·어휘

- `game.gd:1888` `ELEMENT_COLOR` → `fire e2452f` · `oil 7a5230`.
  hex 리터럴 금지 규칙 때문에 `GamePalette`에 `EMBER_RED` · `OIL_BROWN` 신설 권장(§3.3)
- `game.gd:4484` `_factory_card_color()` → `_element_color()` 폴백 구조.
  흘러드는 곳 11군데: `:1759 · 3082 · 3430 · 3450 · 3497 · 3561 · 3607 · 4183 · 4225 · 4378 · 4503`
- `game.gd:1855-1858` `RAIL_ELEMENT_MARK` `화빙뇌독유타초` → **`불얼번독기타정`**.
  읽는 곳 6군데: `:2259 · 3070 · 3452 · 3643 · 4462 · 12746`
- `game.gd:7631` `"무속성"` 문자열 복제 — `element_name()` 기본값이 `"속성 없음"`으로 바뀌어 표기가 갈린다
- `game.gd:5783-5787` 온보딩 모조 레일이 라이브러리를 안 읽고 가짜 태그를 직접 쓴다(`"화 참격"` 등)
- `skill_icon.gd` `GENERATED_SKILL_INDEX` 28엔트리 → `id → 실루엣 인덱스(0~13)`.
  `DealCardLibrary.SILHOUETTES` 배열 순서가 그 인덱스다 (**YA 에셋 이후**)
- 한자 병기 잔여: `game.gd:1866-1882 · 2177 · 3114 · 6968` ·
  `status_engine.gd:454 · 467 · 511 · 562 · 588 · 624 · 635 · 661`(행 헤더 주석 8곳)

### D. 지금 상태에서 **실패가 확정된** 테스트 단언

| 위치 | 왜 |
|---|---|
| `test_runner.gd:1686` | `hot_reload > expected_debt` — `HEAT_RELOAD = 0.0`이라 양변이 같다 → **false** |
| `test_runner.gd:1732` | `damage_multiplier(3,2) < damage_multiplier(3,0)` — 둘 다 1.0 → **false** |
| `test_runner.gd:1746-1772` | `hot_damage > cold_damage × 2.4` 과열 피해 단언 → **false** |
| `test_runner.gd:1711` | `step_count > FactoryDeck.SLOT_COUNT`(5)면 실패 — 새 상한은 **10** |
| `test_runner.gd:1835` · `2802` | `rail_heat_segments.size() == HEAT_MAX` — HUD 온도계 삭제와 함께 |
| `test_runner.gd:1885` | 툴팁 **필수 문자열 `"과열"`** — 금지 어휘가 됐으므로 교체 필수 |
| `test_runner.gd:1861-1866` | 첫 칸 화(火) 카드 아이콘 색 대조 — `ELEMENT_COLOR` 변경과 함께 움직여야 한다 |
| `test_runner.gd:3945-3990` | `--stage-test` dwell 곡선 표 7행 전부 신값과 어긋난다 |
| `test_runner.gd:3969` | 위 §8의 불변식 — **결정 필요** |
| `test_runner.gd:952` · `2505` · `2552-2553` · `2807` | `uses_heat` · `boss_rail_heat_cells` 가시성 |
| `test_runner.gd:2028-2035` | `--cycle-test` 출력 키 `heat_damage=` `reentry=` |
| `test_runner.gd:831` | `night_one_limit <= 40` 교차점이 dwell 4 → 3으로 당겨졌다 |
| `test_runner.gd:1806` | `step_count > STEP_CAP` 검사 → 새 계약인 **`end_reason == "overload"` 0건**으로 강화 권장 |

**폐기 id를 `roll_rune()`에 넘기는 지점** (크래시는 없고 **각인 없는 덱으로 조용히 통과**한다 — 이번 라운드에서 실제로 data_test가 그 상태였다):
`test_runner.gd:584 · 596 · 600 · 769 · 1697-1698 · 1794 · 2196-2197 · 2255 · 3074-3076 ·
4549-4550 · 4746-4750 · 4785 · 4918 · 4954-4960 · 5018 · 5123 · 5194 · 5301-5303 · 5477 · 5480-5481`

### E. Y8 — `balance_probe.gd` 재작성 (이 파일 없이는 §1.6 재측정이 무의미하다)
- 덱 정의 각인 배열이 전부 폐기 id: `:58 · 64 · 70 · 80 · 85 · 90 · 643 · 648 · 653 · 658 · 663 · 675 · 680 · 685`
- `:276-290` · `:323-336` `link`/`echo`/`overlap`/`chorus` 재현 코드가 전부 죽었다
- `:464`(단언 `:481-486`) · `:555` dwell 곡선 · `:863` · `:931` · `:1007` · `:1037` 신값 반영
- `:910` `_stage_pool_stats`에 낮 선공 게이트가 없어 **프로브와 실제 스포너가 이제 서로 다른 답을 낸다**

### F. Y6 — 저장
`factory_deck.rail_runes` 직렬화 미구현. schema 4에 저장 키 `rail_runes` 추가.

---

## 10. 밟은 함정 · 후속 웨이브가 알아야 할 것

1. **`-s res://scripts/test/status_test.gd`는 영원히 멈춘다.** 그 파일은
   `class_name StatusTest / extends RefCounted`라 MainLoop 검사에 걸리고, macOS Godot이
   `--headless`에서도 `NSAlert` 모달을 띄워 CPU 0%로 블록된다(로그도 비고 타임아웃도 없다).
   진짜 진입점은 **`-- --status-test`** (`run_all.sh:275`). rune_test·data_test는 `SceneTree`라 `-s`가 맞다.
2. **폐기된 각인 id는 조용히 사라진다.** `roll_rune()`이 `{}`를 돌려주고 `attach_rune()`이 false를
   내지만 아무도 안 본다 → **덱이 무각인으로 돌면서 테스트는 통과한다.** data_test의 RELOAD
   기준선이 몇 라운드째 아무것도 재고 있지 않았다. 새 data_test는 미지 id를 실패로 올린다.
   **다른 웨이브도 각인 id를 갈아끼울 때 같은 방어를 넣을 것.**
3. **`resolve_rail()`이 `rail_loop` 굴림을 `P_CAP`(0.75)으로 클램프한다**(`rune_engine.gd:579`).
   실전 범위가 0.45~0.65라 안 걸리지만, 테스트에서 `p = 1.0`을 줘도 확정이 아니다
   (실측 무장률 0.76). rune_test는 `rail_loop_armed` 분기로 양쪽을 다 검증한다.
4. **`REPEAT_CAP = 2`는 죽은 상수가 됐다.** `SLOT_EXEC_CAP` 때문에 앙코르는 칸당 최대 1회만
   소비 가능해 `mini()`가 절대 안 걸린다. 해롭지는 않다 — Y2 정리 후보.
5. **`trade_skip`을 `FLOW_DELTA`에 넣으면 안 된다.** 확정 각인이라 두 번째 실행에서도 delta가
   다시 붙어 **두 칸을 건너뛴다.** 엔진은 앙코르가 실제로 소비될 때만 `carried_delta += 1`이
   되도록 플래그로 넘긴다. 실측 `visited [0,0,2,3,4]`.
6. **되돌이 바퀴의 `end_reason`은 `"all_used"`가 아니라 `"complete"`다.** 설계가 요구한 것은
   "정확히 10스텝"뿐이고 그건 충족된다. 테스트는 둘 다 허용한다.
7. **§4.3 표 자신이 §4.2의 16자 상한을 3장에서 어긴다** — `moon_barrier` 17 · `shield_bash` 18 ·
   `battle_trance` 17. 데이터는 상한 쪽을 택해 16자로 줄였다
   (`안 때리고 막 두 겹을 얻는다` / `두 번 밀쳐 막 한 겹 얻는다` / `세 번 치며 체력과 막 얻는다`).
   **문서 표를 데이터에 맞춰 고치는 편이 좋다.**
8. **`time_cut`의 `combo`에 em dash(`—`)가 들어 있다**(§4.3 표 원문 그대로).
   픽셀 폰트에 글리프가 없으면 두부가 뜬다. `--capture-choice` 육안 검수 항목.
   `·`로 바꾸면 정확히 18자로 상한 안이다.
9. **`haste_self` impact에 `stun 0.04`를 줬다.** §7.3은 넉백·경직 둘 다 "—"지만 0.0으로 두면
   `data_test.gd:162-166`과 `test_runner.gd:561-564`의 "피해를 주는 카드는 경직이 있어야 한다"
   단언이 `time_cut`·`phantom_step`·`battle_trance` 3장에서 깨진다. 기존 눈금 바닥값보다 낮은 값이다.
10. **data_test의 `reload_baseline` 밴드를 3.0±1.0 → 2.3±1.0으로 내렸다.** 근거는 과열 항
    소멸이다(`빚 × (1 + 과열 × 0.18)` → `빚`). 실측 평균 **2.29초**
    (bare 2.39 · mid 2.29 · rewind 2.40 · tempo 0.51 · heavy 3.85).
    무각인 기준선의 상한은 `RELOAD_BARE_MAX = 3.0`으로 분리했다 — `quick`·`rail_rest`가 이제
    RELOAD를 **내리는** 방향으로도 움직여 bare가 전체 평균보다 낮으리라는 보장이 사라졌기 때문이다.
11. **`data_test`는 `run_all.sh`의 `ALL_TESTS` 목록에 없다**(`rune_test`·`status_test`·
    `balance_probe`·`rift_probe`도 마찬가지). 자동으로 빨개지는 것은 `--stage-test` 하나다.
    나머지는 standalone으로 직접 돌려야 보인다.

---

## 11. 이 웨이브가 하지 않은 것 (범위 밖 · 다음 웨이브 몫)

- `game.gd` 계열 전부(Y2~Y7) · `enemy.gd` 습성 배선(Y5) · 아이콘 시트와 인덱스(YA → Y4)
- `test_runner.gd` · `run_all.sh` 기능 테스트 재작성(각 화면 웨이브)
- `balance_probe.gd` 재작성과 보스 HP 5개 · 마왕 HP · 반격 창 실측(Y8)
- 저장 schema 4(Y6) · 한글 전수 스윕과 온보딩 재작성(YZ)
- `docs/FEEDBACK_Y.md` 자체 수정 — §5.5의 산수 오류 2건과 §4.3의 글자수 초과 3건은
  **보고만 하고 문서는 건드리지 않았다.** 설계 문서의 소유자가 고치는 것이 맞다.
