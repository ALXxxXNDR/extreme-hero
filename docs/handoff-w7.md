# W7 인수인계 — 콘텐츠 데이터 (스킬 20+12 · 몬스터 10 · 태그)

대상: **W2**(사이클 런타임) · **W9**(성·NPC·각성) · **W11**(시각 테마) · **W12**(통합·밸런스)
기준 문서: `docs/GAME_DESIGN_V2.md` §3.8 · §4.1 · §5.1~5.3 · §9.3 · §9.5 · §7 W7,
**부록 C-6**(RELOAD 재기준) · **C-8**(W1 이탈 승인), `docs/handoff-w1.md` §2 · §3.5 · §8

## 0. 산출물

| 파일 | 상태 |
|---|---|
| `godot-game/scripts/deal_card_library.gd` | 재저작 (원본 → `docs/v1-archive/deal_card_library.gd.txt`) |
| `godot-game/scripts/monster_library.gd` | 재저작 (원본 → `docs/v1-archive/monster_library.gd.txt`) |
| `godot-game/scripts/test/data_test.gd` | 신규. standalone `-s` 데이터 테스트 |
| `docs/handoff-w7.md` | 이 문서 |

**손대지 않은 파일**: `game.gd` · `test_runner.gd` · `run_all.sh` · `rune_engine.gd` ·
`rune_test.gd` · `item_library.gd`(§5.4로 무수정 확정) · `class_library.gd`(W9 몫) · world 파일 전부.

```bash
godot --headless --path godot-game --editor --quit                    # 오류 0
godot --headless --path godot-game -s res://scripts/test/data_test.gd # DATA_TEST_COMPLETE / exit 0
godot --headless --path godot-game -s res://scripts/test/rune_test.gd # RUNE_TEST_COMPLETE / exit 0 (회귀)
```

---

## 1. 스킬 20종 (v2 드래프트 풀)

태그는 §3.8의 **원소 6 × 형태 5**다. 키 이름은 `element` / `form` — `RuneEngine.ELEMENTS` ·
`RuneEngine.FORMS`와 **글자까지 같아야** 공명·결속·삼각·반응이 켜진다(data_test가 매 실행 대조).

| id | 이름 | 원소 | 형태 | kind | duration | reload | v1 reload |
|---|---|---|---|---|---:|---:|---:|
| `cleave` | 반월참 | 철 | 참격 | melee | 0.98 | 0.31 | 0.48 |
| `rapid_slash` | 삼연참 | 철 | 참격 | melee | 1.05 | 0.26 | 0.42 |
| `thrust` | 관통 창격 | 철 | 관통 | melee | 0.88 | 0.29 | 0.46 |
| `recursion` | 회귀 검기 | 철 | 관통 | projectile | 1.10 | 0.46 | 0.72 |
| `dash_blade` | 설한 섬격 | 빙 | 참격 | dash | 0.86 | 0.36 | 0.60 |
| `frost_ring` | 빙결 파문 | 빙 | 파동 | area | 1.28 | 0.53 | 0.86 |
| `gravity_well` | 서리 심연 | 빙 | 설치 | ground | 1.70 | 0.67 | 1.08 |
| `guardian_blade` | 빙정 호위검 | 빙 | 수호 | orbit | 1.65 | 0.48 | 0.78 |
| `thunder` | 뇌전 심판 | 뇌 | 파동 | chain | 1.15 | 0.50 | 0.82 |
| `time_cut` | 섬전 순참 | 뇌 | 참격 | melee | 0.82 | 0.12 | 0.14 |
| `targeting` | 뇌창 유도 | 뇌 | 관통 | projectile | 0.84 | 0.26 | 0.40 |
| `shield_bash` | 성벽 방패치기 | 광 | 수호 | melee | 0.90 | 0.36 | 0.55 |
| `moon_barrier` | 월광 보호막 | 광 | 수호 | shield | 0.94 | 0.50 | 0.82 |
| `holy_pulse` | 성광 파동 | 광 | 파동 | area | 1.40 | 0.65 | 1.05 |
| `whirlwind` | 혈풍 회전참 | 혈 | 파동 | area | 1.30 | 0.46 | 0.72 |
| `blood_pact` | 피의 서약 | 혈 | 참격 | melee | 1.05 | 0.38 | 0.62 |
| `execution` | 혈월 처형 | 혈 | 참격 | melee | 1.62 | 0.77 | 1.25 |
| `flame_field` | 업화의 장막 | 화 | 설치 | ground | 1.60 | 0.60 | 0.95 |
| `meteor_blade` | 운석검 강림 | 화 | 설치 | ground | 1.95 | 0.98 | 1.65 |
| `earth_splitter` | 용암 균열 | 화 | 관통 | projectile | 1.32 | 0.62 | 1.00 |

분포: **원소** 철4 · 빙4 · 뇌3 · 광3 · 혈3 · 화3 / **형태** 참격6 · 관통4 · 파동4 · 설치3 · 수호3.
→ 어떤 원소로도 3칸 결속을, 어떤 형태로도 삼각 배열(1·3·5칸)을 만들 수 있다. data_test가 강제한다.

**설계 의도 하나**: 각성 계보의 조건 카드끼리 원소를 맞췄다.
성기사 `shield_bash`+`moon_barrier` = 광, 광전사 `whirlwind`+`blood_pact` = 혈,
창기사 `thrust`+`recursion` = 철. 각성 특별 카드도 같은 원소라 **각성 = 태그 축**이 된다.

`id`는 한 개도 바꾸지 않았다. 이름·설명만 직장 풍자 → 판타지로 통일했다(§7 W7 ②).
`skill_icon.gd`의 id→아이콘 매핑 28개가 그대로 산다.

## 2. 특별 스킬 12종 (§5.3 "전량 유지")

| id | 계보 | tier | 원소 | 형태 | duration | reload | v1 reload |
|---|---|---|---|---|---:|---:|---:|
| `holy_verdict` | 성기사 | 1 | 광 | 참격 | 1.35 | 0.43 | 0.72 |
| `aegis_process` | 성기사 | 1 | 광 | 수호 | 1.18 | 0.41 | 0.66 |
| `heavens_gate` | 크루세이더 | 2 | 광 | 파동 | 1.15 | 0.46 | 0.75 |
| `zero_damage_oath` | 크루세이더 | 2 | 광 | 수호 | 1.25 | 0.48 | 0.78 |
| `crimson_loop` | 광전사 | 1 | 혈 | 참격 | 1.32 | 0.24 | 0.38 |
| `pain_compiler` | 광전사 | 1 | 혈 | 파동 | 1.05 | 0.43 | 0.72 |
| `red_moon_execution` | 적월기사 | 2 | 혈 | 참격 | 1.36 | 0.22 | 0.34 |
| `immortal_frenzy` | 적월기사 | 2 | 혈 | 파동 | 1.20 | 0.31 | 0.50 |
| `dragon_pierce` | 창기사 | 1 | 철 | 관통 | 1.10 | 0.38 | 0.62 |
| `echo_thrust` | 창기사 | 1 | 철 | 관통 | 1.18 | 0.30 | 0.48 |
| `sky_dragon_array` | 용창기사 | 2 | 철 | 관통 | 1.42 | 0.26 | 0.42 |
| `infinite_recursion` | 용창기사 | 2 | 철 | 관통 | 1.50 | 0.23 | 0.36 |

특별 카드는 `ranked()`에서 랭크 성장을 받지 않는다(v1 그대로).
`immortal_frenzy` 이름만 "퇴근 거부 광란" → "불멸의 광란"으로 바꿨다.

## 3. v1에서 내린 카드 8종 — **지우지 않고 `legacy: true`**

오케스트레이터 권고를 그대로 따랐다. 8종은 `SKILLS` 배열에 **남아 있고**(28종 유지)
`draft_pool()` / `draft_ids()` / `random_two()` 세 곳에서만 빠진다.

| id | 이름 | 원소·형태 | 내린 이유 |
|---|---|---|---|
| `aura` | 혈무 오라 | 혈·파동 | `whirlwind`·`frost_ring`과 "주변 지속 광역"이 겹친다. 형태 특색 없음 |
| `cross_cut` | 십자 교차참 | 철·참격 | `cleave`+`rapid_slash`의 하위 호환. 근접 2타 슬롯 과잉 |
| `lion_roar` | 사자후 충격파 | 화·파동 | `holy_pulse`와 광역 파동 중복. knockback 어휘는 §5.4로 장비가 담당 |
| `phantom_step` | 잔영 질주 | 뇌·참격 | `dash_blade`와 돌진 중복 |
| `sword_rain` | 검우 강림 | 빙·설치 | `meteor_blade`와 무작위 낙하 설치 중복 |
| `boomerang_blade` | 회귀 투검 | 철·관통 | `recursion`과 튕김 투사체 중복 |
| `battle_trance` | 전투 몰입 | 광·수호 | `moon_barrier`(수호) + `blood_pact`(흡혈)로 분해되는 하이브리드 |
| `blade_fan` | 부채꼴 검기 | 광·관통 | `targeting`·`earth_splitter`와 원거리 관통 중복. 20종 압축의 마지막 한 장 |

이렇게 한 이유:
- `test_runner.gd`의 `skill_variety_ok`가 `SKILLS.size() >= 28`을 본다 → **v4-test가 깨지지 않는다.**
- `skill_icon.gd`의 아이콘 인덱스(0~27)가 legacy 카드에도 그대로 매핑돼 있다.
- `cycle_skill_effect.gd`가 `cross_cut`·`sword_rain`·`phantom_step`·`lion_roar`·`battle_trance`를
  id로 분기한다 → 연출 코드 무수정.
- `test_runner.gd`가 `sword_rain`·`blade_fan`을 직접 `place_card`한다 → `by_id`가 계속 찾는다.
- 세이브에 legacy 카드가 들어 있어도 복원된다.

**실제 삭제는 W12 통합 때 판단할 것.** 그때는 위 5개 파일을 함께 봐야 한다.

## 4. 랭크 — 상한 R3 (§5.2 · §9.3)

```gdscript
DealCardLibrary.MAX_RANK              # 3
DealCardLibrary.rank_formula(rank)    # {rank, damage_mul, duration_mul, reload_mul, range_mul}
#   R1 ×1.00 / R2 ×1.55 / R3 ×2.10 (피해)  ·  duration ×0.94^(r−1)  ·  reload ×0.95^(r−1)
```

**중요 — v1 융합 경제를 깨지 않으려고 두 층으로 나눴다.**

| 층 | 값 | 이유 |
|---|---|---|
| 저장 랭크 (`instance()`, `ranked()["rank"]`) | 1~5 그대로 | `class_library.gd`의 각성 조건이 `"rank":5`이고 `factory_deck.fuse()`·`demon_lord.gd`가 1~5로 융합한다. 여기를 3으로 클램프하면 **각성이 도달 불가**가 되고 v4-test의 advancement 검사가 죽는다 |
| 수치 성장 (`ranked()`의 damage/duration/reload/range) | **R3에서 포화** | §5.2 "상한 R3" |

`ranked()`는 `effective_rank` 키를 추가로 돌려준다(실제 적용된 1~3).
UI가 "R5"를 띄우면서 수치는 R3인 상태는 **의도된 과도기**다.
W9가 각성 조건을 `day >= 3` / `rune_tag_count >= 3`으로 바꾸고(§5.3),
W12가 융합 상한을 4장=R3으로 정리하면 저장 랭크도 1~3으로 좁힐 수 있다.

## 5. RELOAD 재기준 — 실측 (부록 C-6)

부록 C-6은 "v1의 **약 50%에서 출발**, 목표 평균 사이클 RELOAD **≈3초**"다.
50%로 시작해 시뮬레이션으로 올려 맞췄고, 최종 착지점은 **v1의 약 60%**
(드래프트 20종 평균 `reload` 0.769초 → **0.463초**).

`data_test.gd`가 대표 5칸 덱 5종 × 400사이클을 `RuneEngine.simulate_cycle`에 넣어 실측한다.

| 덱 | 구성 | 평균 RELOAD |
|---|---|---:|
| `bare` | 카드 5장, 각인 0개 (카드 reload만의 무게) | **2.32초** |
| `mid` | 표준 중반 덱, 각인 12개를 5칸에 고르게 (§5.1의 보유량) | **3.08초** |
| `rewind` | 되감기 엔진(§3.10) — 스텝이 늘어 빚이 가장 크게 붙는 축 | **2.24초** |
| `tempo` | 도약 템포(§3.10) — `skip_1`·`toll`·`free_reload`·삼각 배열 | **1.10초** |
| `heavy` | 카드 reload 상위 5장만 (최악 조건) | **4.79초** |
| **전체 평균** | | **2.71초** |

- 목표 ≈3초를 **표준 덱이 정확히 맞춘다**(3.08). 판정 밴드는 전체 평균 3.0±1.0.
- 최악 덱도 `RELOAD_CAP` 6.0초에 닿지 않는다(4.79).
- 도약 템포가 1.10초로 표준의 1/3 → 부록 C-6의 "빚 최소화 축"이 실제로 보상받는다.
- W1 §6.5가 경고한 "무작위 인구 평균 4.32초"는 해소됐다(카드 데이터만으로 −37%).

`duration`도 함께 압축했다(드래프트 20종 평균 1.50초 → **1.22초**, 최소 0.82).
최소값 0.82를 지킨 이유: `test_runner.gd`의 `skill_variety_ok`가 전 카드에 `duration >= 0.8`을 요구한다.

## 6. 몬스터 10종 (§9.3) — 7일 클럭

`unlock`은 이제 **일수**다. `game.gd`의 `cycle_number`가 W0/W4에서 `clock.day_number`의
별칭이 되었으므로(`game.gd` L202~208) **`spawn_allowed(cycle, night, override)` 시그니처를
하나도 바꾸지 않았다.** §4.1의 "게이팅 코드는 손대지 않는다. 상수만 재매핑" 그대로다.

| id | 이름 | behavior | unlock(일) | weight | growth | night_mul | slash_hits | module |
|---|---|---:|---:|---:|---:|---:|---:|---|
| `mossling` | 이끼콩 | 1 도망 | 1 | 24.0 | 0.0 | 1.30 | 2.6 | — |
| `boar` | 들멧돼지 | 2 반격 | 1 | 21.0 | 0.0 | 0.72 | 3.6 | — |
| `imp` | 뿔임프 | 3 집단반격 | 1 | 17.0 | 0.0 | 0.85 | 3.2 | — |
| `wolf` | 붉은 늑대 | **4 선공** | 1 | 12.0 | 0.6 | 0.95 | 4.2 | — |
| `skeleton` | 떠도는 해골 | 2 | 2 | 12.0 | 1.2 | 1.10 | 5.0 | — |
| `shade` | 굶주린 그림자 | **4 선공** | 3 | 9.0 | 1.8 | 1.50 | 6.0 | — |
| `wisp` | 푸른 위습 | 3 | 4 | 5.0 | 1.4 | 1.15 | 3.6 | **targeting**(원거리) |
| `ogre` | 황야 오우거 | 2 | 5 | 5.0 | 2.0 | 1.35 | 9.0 | firewall |
| `cultist` | 월식 주술사 | 3 | 5 | 5.0 | 2.0 | 1.55 | 5.6 | hotfix |
| `hellhound` | 밤의 지옥견 | **4 선공** | 6 | 4.5 | 2.4 | 2.10 | 10.0 | overclock |

`wolf`는 unlock 1이지만 **낮에는 3일차부터** 나온다(`aggro_gate_ok`). 1·2일차 낮은 완전히 평화롭고
밤에는 1일차부터 선공몹이 있다 — 기존 게이팅의 정신 그대로다.

### 6.1 해금 리듬과 실측 곡선

| 일 | 신규 | 등장 종 수(밤) | 기대 체력 |
|---:|---|---:|---:|
| 1 | 이끼콩·들멧돼지·뿔임프·붉은 늑대 | 4 | 50.9 |
| 2 | 떠도는 해골 | 5 | 71.0 |
| 3 | 굶주린 그림자 · **낮 선공몹 해금** | 6 | 97.2 |
| 4 | 푸른 위습 · **원거리 해금** | 7 | 118.6 |
| 5 | 황야 오우거 · 월식 주술사 | 9 | 156.2 |
| 6 | 밤의 지옥견 | 10 | 246.8(7일) |
| 7 | — (강림 준비) | 10 | |

data_test가 매 실행 검증하는 단조성 3종: 등장 종 수 비감소 · 최대 `slash_hits` 비감소 ·
기대 체력 **엄격 증가**. 낮 선공몹 비중도 램프업한다(3일 7.1% → 5일 14.4%).

### 6.2 내린 몬스터 3종

| id | 이름 | 이유 |
|---|---|---|
| `royal_ooze` | 왕관 점액 | `mossling`과 behavior 1 · 점액 비주얼이 겹친다 |
| `cave_bat` | 동굴 박쥐 | 선공 고속 추격이 `wolf`·`shade`와 겹친다. 선공몹 3종이면 하네스 요구를 충족한다 |
| `iron_beetle` | 철갑 딱정벌레 | 느린 탱커 역할이 `ogre`와 겹친다. `firewall` 모듈은 `ogre`가 물려받았다 |

### 6.3 상수 변경

| 상수 | v1 | v2 | 근거 |
|---|---:|---:|---|
| `CYCLE_HEALTH_GAIN` | 0.18 | **0.28** | §9.3 |
| `AGGRO_DAY_UNLOCK_CYCLE` | 5 | **3** | §4.1 "3일차 선공몹 해금" · §7 W7 ③ |
| `RANGED_MIN_UNLOCK_CYCLE` | 3 | **4** | §4.1 "4일차 원거리 해금" |
| `MAX_UNLOCK_CYCLE` | 5 | **6** | §7 W7 완료 기준 "unlock ≤ 6" |
| `EARLY_MONSTER_DECAY_STEP` / `_FLOOR` | 0.11 / 0.38 | **0.13 / 0.34** | 7일 곡선 압축 |
| 최상위 `slash_hits` | 12.0(ogre) | **10.0**(hellhound) | §9.5 "12→10" |

---

## 7. **오케스트레이터가 처리해야 할 것 — v4-test 한 줄**

`test_runner.gd`는 W4 소유라 손대지 않았다. 아래 **한 곳**만 갱신하면 v4-test가 다시 통과한다.

```gdscript
# godot-game/scripts/test/test_runner.gd L294
- var early_day_peace_ok := MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE >= 5 and MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE <= 10
+ var early_day_peace_ok := MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE >= 3 and MonsterLibrary.AGGRO_DAY_UNLOCK_CYCLE <= 10
```

- 이 상한 `5`는 v1의 무한 라운드 시절 값이다. 7일 런에서 5는 5·6·7 사흘만 남겨 §4.1을 어긴다.
- `core/tuning.gd` L25에 W4가 남긴 주석("재매핑(AGGRO 5→3 등)은 W7 데이터 웨이브 몫")이
  이 변경을 W7에 명시적으로 위임했다.
- **같은 줄 외에 고칠 곳은 없다.** L301의 `range(1, AGGRO_DAY_UNLOCK_CYCLE)`,
  L313/L316의 램프업 검사는 상수에서 파생되므로 3으로도 그대로 통과한다(실측 7.1% → 14.4%).
- `skills28`(L164 `SKILLS.size() >= 28`)은 legacy 보존으로 **갱신이 필요 없다.**
  풀 크기를 정말 20으로 좁히고 싶으면 `DealCardLibrary.draft_pool().size() == 20`으로 바꾸면 된다.

### run_all.sh 등록 스니펫 (W4/오케스트레이터가 원할 때)

`data_test.gd`는 게임을 로드하지 않는 standalone `-s` 스크립트라 `--data-test` 플래그
하네스와 형식이 다르다. 두 가지 방법이 있다.

```bash
# ㉠ run_all.sh에 별도 블록으로 (rune_test와 같은 방식)
godot --headless --path godot-game -s res://scripts/test/data_test.gd
#   합격: DATA_TEST_COMPLETE ... / exit 0,  불합격: DATA_TEST_FAILED ... / exit 1
```

```gdscript
# ㉡ 기존 ALL_TESTS 배열에 넣고 싶으면 test_runner.gd에 얇은 래퍼를 두고
ALL_TESTS=( ... "--data-test:DATA_TEST_COMPLETE" )
# 출력 규약은 이미 맞춰 뒀다(판정은 전부 `=true`, 정보성 값은 숫자, `=false` 문자열 없음).
```

---

## 8. W2 · W9 · W11 체크리스트

### W2 (사이클 런타임)
- 칸의 카드는 `DealCardLibrary.ranked(instance)`로 만들어 `RuneEngine.make_slot(card, runes)`에
  넣어라. 엔진이 실제로 읽는 키는 `damage` `reload` `duration` `element` `form` 다섯 개다.
- **`element`/`form`을 빼먹으면 공명·결속·삼각·반응이 전부 조용히 꺼진다.** 크래시가 안 나서
  못 알아챈다. `RuneEngine.bond_mask(deck)`가 전부 `false`면 이 문제다.
- 빈 칸에 `DealCardLibrary.BASIC`을 넣어도 태그가 비어 있어 결속에 기여하지 않는다. **의도된 것이다** —
  카드 0장인 1일차 레일이 5칸 결속 + 삼각 배열을 공짜로 얻는 걸 막는다.
- 사이클 RELOAD는 `simulate_cycle().reload`가 이미 완성값이다(빚 × 과열 × 삼각할인 × `reload_scale`).
  카드 `reload`를 런타임에서 다시 더하지 마라 — 이중 계산이 된다.
- 부록 C-7의 `heat_gate` 문턱 3→2는 **W2가 `rune_engine.gd`에서** 내린다. W7은 엔진을 안 건드렸다.

### W9 (성·NPC·각성)
- `class_library.gd`의 조건 카드 6종(`shield_bash` `moon_barrier` `whirlwind` `blood_pact`
  `thrust` `recursion`)은 전부 v2 드래프트 풀에 살아 있다. data_test가 이걸 강제한다 —
  풀에서 빼면 테스트가 즉시 실패한다.
- 각성 조건을 §5.3대로 `day >= 3` / `rune_tag_count >= 3`으로 바꿀 때, 계보별 **원소**를 쓰면 된다:
  성기사=`light` · 광전사=`blood` · 창기사=`iron`. 특별 카드 12종도 같은 원소로 맞춰 뒀다.
- **`game.gd` L4250 `skill_swap` NPC가 `SKILLS`에서 직접 무작위 추출한다** —
  legacy 카드가 나올 수 있다. `DealCardLibrary.draft_pool()`(또는 `draft_ids()`)로 바꿔라.
  같은 이유로 상점·전조 회수 등 "새 카드를 주는" 모든 경로는 `draft_pool()`을 써야 한다.
  (`game.gd` L2836의 레벨업 2택1은 `random_two()`를 쓰는데 그건 이미 풀만 뽑도록 고쳐 뒀다.)

### W11 (시각 테마·에셋)
- `art/external/INVENTORY.md`의 몬스터 13행 중 **`royal_ooze` · `cave_bat` · `iron_beetle`
  3행은 이제 쓰이지 않는다.** 나머지 10행의 id·`visual` 값은 v1 그대로라 매핑이 유효하다.
- 스킬 아이콘: `skill_icon.gd`의 id→인덱스 28개가 전부 유효하다(legacy 포함). 아이콘 작업은
  v2 풀 20종을 우선하면 된다.
- `test_runner.gd` L854 `_run_night_preview()`가 `cave_bat`·`iron_beetle`을 강제 스폰한다.
  `combat_resolver.gd` L240이 빈 archetype을 무작위 roll로 폴백하므로 **크래시는 없고**
  캡처 화면에 다른 몹이 나올 뿐이다. `--capture-night` 그림을 정확히 맞추려면 그 목록을
  `["wolf","skeleton","wisp","shade","ogre","cultist","hellhound"]`로 바꾸면 된다(W4 소유 파일).

### W12 (통합·밸런스)
- **`CYCLE_HEALTH_GAIN = 0.28`은 §9.3의 명시값이지만 근거 계산이 어긋나 있다.** §9.3은
  `power_level == day − 1`(7일차 ×2.68)을 가정하는데, 실제 필드 스폰은
  `combat_resolver.gd` L245의 `(day−1)×1.1 + (level−1)×0.32 + min(경과/180, 2.5)`라
  7일차·레벨 15에서 ≈13.6 → **실체력 배율 ×4.8**이다. §9.5가 이미 1차 조정안으로
  0.28 → 0.24를 제시해 뒀다. `monster_library.gd` 한 줄이다.
- legacy 카드 8종의 실제 삭제(§3 표 참조). 함께 봐야 할 파일 5개를 §3에 적어 뒀다.
- 저장 랭크 1~5 → 1~3 정리(§4).

## 9. 데이터 테스트가 보장하는 것

`data_test.gd` 판정 11종. 전부 `=true`여야 exit 0.

| 판정 | 내용 |
|---|---|
| `card_schema` | 필수 키 16종 · `duration >= 0.8` · 피해 카드의 `range`>0 · 경직>0 · 음수 없음 |
| `draft_pool` | 풀 정확히 20종 · legacy가 풀/`random_two` 300회에 안 섞임 · legacy도 `by_id`로 살아 있음 |
| `tag_vocabulary` | `DealCardLibrary.ELEMENTS/FORMS` == `RuneEngine.ELEMENTS/FORMS` (오타 1글자를 잡는다) |
| `tag_coverage` | 전 카드 태그가 유효 집합 소속 · BASIC은 무태그 |
| `tag_playable` | 원소마다 3장 이상(결속 가능) · 형태마다 3장 이상(삼각 가능) |
| `rank_formula` | 단조성 · MAX_RANK 포화 · R3 = ×2.10 · `ranked()`가 저장 랭크 보존 |
| `reload_baseline` | 대표 5칸 덱 5종 × 400사이클 평균이 3.0±1.0초 · 전부 `RELOAD_CAP` 이하 |
| `monster_schema` | 10종 · 필수 키 12종 · unlock 1~6 · `slash_hits` ≤ 10 · 선공몹 3종 이상 |
| `monster_curve` | 7일 단조성(종 수·최대 `slash_hits` 비감소, 기대 체력 엄격 증가) |
| `monster_gates` | 1일차 낮 선공몹 0 · 1일차 밤 선공몹 존재 · 원거리 해금 전 0 · 선공몹 램프업 |
| `unique_ids` | 카드/몬스터 id 중복 0 · 각성 조건 카드 6종이 풀에 존재 |

음성 대조 확인: `thunder`의 `element`를 `"thundr"`로 한 글자 망가뜨리면
`tag_coverage`와 `tag_playable`이 동시에 잡고 exit 1을 낸다(원복 완료).
