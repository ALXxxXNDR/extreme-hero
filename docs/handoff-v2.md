# handoff-v2 — V2 콘텐츠 데이터 재저작 (v3)

> 웨이브: **V2 (콘텐츠 데이터 — 28장 7원소 · 아이템 개명 · 보스/트로피 라이브러리)**
> 작성 2026-08-09 · 근거 `docs/GAME_DESIGN_V3.md` §3 · §4.2 · §4.5 · §5 · §6.3 · 부록 A · 부록 B V2
> 선행: V0(안전망·상수 골격) 완료 · 병렬: V1 상태엔진 · V3 에셋 · V4 스테이지 클럭

---

## 0. 한 줄 요약

**신규 카드 id 0개로 28장 = 7원소 × 4장을 세웠고, 아이템 36종을 판타지로 개명했으며,
`boss_library.gd`·`trophy_library.gd` 두 개를 신설하고 L1 반응을 3쌍 → 7쌍으로 확장했다.**
`game.gd` · `test_runner.gd` · `run_all.sh` · `status_engine.gd` · `stage_clock.gd` ·
`demon_lord.gd` · `tuning.gd` · `world_grid.gd` · 에셋은 **한 글자도 건드리지 않았다.**

---

## 1. 손댄 파일

| 파일 | 성격 | 내용 |
|---|---|---|
| `scripts/deal_card_library.gd` | 수정 | 28장 승격 · 7원소 재배치 · 개명 · 조회 헬퍼 4종 추가 |
| `scripts/core/rune_engine.gd` | 수정(상단 상수 + `simulate_cycle` 3곳) | `ELEMENTS` 6→7 · `REACTIONS` 3→7쌍 · `potency`/`stun_bonus` 채널 |
| `scripts/item_library.gd` | 수정(데이터) | 57종 중 **36종 개명**. `id`·`effects`·`desc` 무변경 |
| `scripts/monster_library.gd` | 수정(가산) | `tier`/`stage` 키 + 스테이지 축 API 8종 + `cultist` 개명 |
| `scripts/trophy_library.gd` | **신규** | `class_name TrophyLibrary`. 트로피 5종 × 2택1 + 예비 2 |
| `scripts/boss_library.gd` | **신규** | `class_name BossLibrary`. 보스 3종 × 4패턴 + 리그 5벌 |
| `scripts/class_library.gd` | 수정(3줄) | `element` 문자열만 v3 승계. **삭제하지 않았다**(§7) |
| `scripts/test/data_test.gd` | 수정 | 판정 11 → **17종** |
| `scripts/test/rune_test.gd` | 수정 | 판정 16 → **19종** |
| `docs/handoff-v2.md` | 신규 | 이 문서 |

`palette.gd`는 **건드리지 않았다** — 조사 결과 원소가 아니라 **카드 id**로 색을 고르고 있어
(`match skill_id`) 원소 재편의 영향을 받지 않는다. `skill_icon.gd`도 무변경(id 고정의 배당금).

---

## 2. 28장 최종 표 (7원소 × 4장 · 신규 id 0개)

| 원소 | id | 이름 | 형태 | kind | range | 근/원 |
|---|---|---|---|---|---:|---|
| 화(火) | `flame_field` | 업화의 장막 | 설치 | ground | 112 | **근접** |
| 화(火) | `meteor_blade` | 운석검 강림 | 설치 | ground | 235 | 중거리 |
| 화(火) | `earth_splitter` | 용암 균열 | 관통 | projectile | 620 | **원거리** |
| 화(火) | `lion_roar` | 업염 사자후 | 파동 | area | 215 | 중거리 |
| 빙(氷) | `dash_blade` | 설한 섬격 | 참격 | dash | 185 | **근접** |
| 빙(氷) | `frost_ring` | 빙결 파문 | 파동 | area | **268** | **원거리** |
| 빙(氷) | `guardian_blade` | 빙정 호위검 | 수호 | orbit | 102 | 근접 |
| 빙(氷) | `moon_barrier` | **빙정 결계** | 수호 | shield | 0 | 근접 |
| 뇌(雷) | `thunder` | 뇌전 심판 | 파동 | chain | 410 | **원거리** |
| 뇌(雷) | `time_cut` | 섬전 순참 | 참격 | melee | 116 | **근접** |
| 뇌(雷) | `targeting` | 뇌창 유도 | 관통 | projectile | 520 | 원거리 |
| 뇌(雷) | `phantom_step` | **뇌영 잔상진** | **수호**(←참격) | dash | 205 | 중거리 |
| 독(毒) | `whirlwind` | **역병 회전참** | 파동 | area | **262** | **원거리** |
| 독(毒) | `blood_pact` | **역병의 서약** | 참격 | melee | 142 | **근접** |
| 독(毒) | `execution` | **독월 처형** | 참격 | melee | 158 | 근접 |
| 독(毒) | `cross_cut` | **맹독 십자참** | 참격 | melee | 165 | 근접 |
| 유(油) | `gravity_well` | **기름 늪** | 설치 | ground | 175 | **근접** |
| 유(油) | `sword_rain` | **역청 폭우** | 설치 | ground | 145 | 근접 |
| 유(油) | `aura` | **역청 안개** | **설치**(←파동) | area | 136 | 근접 |
| 유(油) | `boomerang_blade` | **역청 회귀검** | 관통 | projectile | 540 | **원거리** |
| 타(打) | `cleave` | 반월참 | 참격 | melee | 176 | **근접** |
| 타(打) | `rapid_slash` | 삼연참 | 참격 | melee | 126 | 근접 |
| 타(打) | `thrust` | 관통 창격 | 관통 | melee | 228 | 중거리 |
| 타(打) | `recursion` | 회귀 검기 | 관통 | projectile | 480 | **원거리** |
| 초(超) | `shield_bash` | **염동 방패치기** | 수호 | melee | 122 | **근접** |
| 초(超) | `holy_pulse` | **초념 파동** | 파동 | area | 245 | 중거리 |
| 초(超) | `battle_trance` | **초월 명상** | 수호 | area | 125 | 근접 |
| 초(超) | `blade_fan` | **염동 검선** | 관통 | projectile | 510 | **원거리** |

**형태 분포**: 참격 7 · 관통 6 · 파동 5 · 설치 5 · 수호 5 = 28 (전부 ≥5 → 삼각이 5형태 전부에서 가능)
**원소 분포**: 7원소 × 정확히 4장 (아이콘 아틀라스 7×4 = 28칸과 정확히 일치)
**legacy**: 0장. 구 legacy 8종(`aura` `cross_cut` `lion_roar` `phantom_step` `sword_rain`
`boomerang_blade` `battle_trance` `blade_fan`)은 전부 드래프트 풀로 승격됐고 id는 그대로다.

### 2.1 설계와 다르게 한 것 3건 (전부 근거 있음)

**① `range` 상향 2건 — 설계가 구조적으로 강제했다.**
§5.1의 완료 기준은 "원소당 근접(<200) ≥1 · 원거리(≥260) ≥1"인데, 28장 중 `range ≥ 260`인
카드는 **다섯 장뿐**이다(`earth_splitter` 620 · `boomerang_blade` 540 · `targeting` 520 ·
`blade_fan` 510 · `recursion` 480). **5 < 7**이므로 §5.3의 배치를 어떻게 섞어도 두 원소는
원거리 카드를 가질 수 없다. §5.3 배치표는 **한 글자도 바꾸지 않고**, 비어 있던 두 원소(빙·독)의
광역 카드 사거리를 올리고 그만큼 reload/damage로 지불했다.

| 카드 | range | reload | damage | 근거 |
|---|---|---|---|---|
| `frost_ring` | 205 → **268** | 0.53 → 0.60 | 1.05 → 0.95 | 냉기 파동 = 빙의 시그니처. chill을 넓게 까는 것이 §4.4 전도의 전제다 |
| `whirlwind` | 148 → **262** | 0.46 → 0.58 | 0.82 → 0.72 | 독은 **넓게 깔고 쌓는** 원소다(§4.4). 광역 적용기가 없으면 `strike`/`fire`가 터뜨릴 스택이 안 생긴다 |

**V10 balance_probe가 확정할 것.** 실측 영향: `data_test`의 대표 5칸 덱 평균 RELOAD
2.71초 → **2.69초**(목표 3.0 ± 1.0 안).

**② 형태 이동 2건 — "형태당 ≥5"를 맞추기 위한 최소 이동.**
v2는 참격 8 / 관통 6 / 파동 6 / 설치 4 / 수호 4였다. 설치·수호가 4장이라 기준 미달이다.

| 카드 | 형태 | 근거 |
|---|---|---|
| `aura` | 파동 → **설치** | 기름은 바닥에 눌어붙는다. 9틱 지속 장판이라 원래도 설치에 가까웠고, §5.3의 "oil 4장은 설치·파동·투척"에 부합한다 |
| `phantom_step` | 참격 → **수호** | 세 잔상이 대신 맞아 준다. 돌진 회피기의 재해석 |

이 둘을 고른 이유: 설계 §4.6의 **실증 빌드 3종이 지목한 카드 14장의 형태를 하나도
건드리지 않는 유일한 조합**이다. 그래서 §4.6의 "1·3·5 참격 → 삼각" 같은 서술이 그대로 성립한다.

**③ L1 반응 키 `chill>strike` → `ice>strike`.** §5절(§4.5 표)은 네 번째 신규 반응의 키를
`chill>strike`로 적었는데 `chill`은 **원소가 아니라 L2 상태**이고 L1의 키는 정의상 원소 쌍이다
(`reaction_of(prev_element, element)`). 문자 그대로 넣으면 영원히 조회되지 않는 죽은
데이터가 된다. `chill`을 만드는 원소는 `ice` 하나뿐이므로 `ice>strike`로 옮겨 적었고
의미("직전 칸이 냉기면 이번 타격의 경직 +0.2초")는 설계 의도 그대로다.

---

## 3. L1 덱 레벨 반응 7쌍 (`rune_engine.gd`)

```
"ice>thunder"  → shock          감전 (v2 유지) — 광역 추가타 +35%. **유일하게 피해를 준다**
"fire>ice"     → steam          증기 (v2 유지) — 범위 +50%
"fire>thunder" → overcharge     과충전 (v2 유지) — 과열 +1 무상
"oil>fire"     → ignite         인화 (신규) — 이 칸의 potency ×1.5
"poison>fire"  → plague_prime   역병 발화 준비 (신규) — potency ×1.3
"ice>strike"   → shatter_prep   쇄빙 준비 (신규) — 경직 +0.2s
"*>psi"        → resonant_drain 공명 흡수 (신규) — 빚 −0.15초
```

**신규 채널 2개가 `step_record`에 들어갔다** — `potency`(기본 1.0) · `stun_bonus`(기본 0.0).
덤으로 `element` · `prev_element`도 실었다(V6의 레일 반응 화살표·시너지 라벨이 쓴다).

- **`*>psi` 와일드카드**: `reaction_of()`가 정확 일치 → `*>현재원소` 순으로 본다.
  직전 칸이 **비어 있으면**(기본 베기 = 태그 없음) 어떤 반응도 서지 않는다.
- **공명 흡수는 최종 RELOAD가 아니라 `debt`에서 뺀다.** RELOAD는 `debt × (1 + 과열 × 0.18)`이라
  최종값에서 빼면 과열이 높을수록 감면이 커지는(설계에 없는) 보너스가 생긴다. `debt`는
  `maxf(0, ...)`로 클램프돼 음수 RELOAD가 나오지 않는다(`rune_test`가 단언).
- **L1은 직접 피해를 주지 않는다**(§4.1 분리 규칙). 신규 4쌍 중 어느 것도 `damage_total`을
  건드리지 않는다 — `rune_test._check_l1_reactions()`가 대조군 덱으로 매번 증명한다.

### V6에게 (`combat_resolver` 배선)
상태 부여 시 `step_record["potency"]`를 곱하고, 경직에 `step_record["stun_bonus"]`를 더하면 된다.
`RuneEngine.reaction_potency(reaction)`가 배율을, `RuneEngine.reaction_name(reaction)`이
한글 표기("인화", "대폭 연소" 라벨용 원문)를 준다.

---

## 4. 아이템 개명 36종 (전 → 후) · id 무변경

`name` 키만 바꿨다. `id` · `effects` · `desc` · `rarity` · `slot` · `weapon_type` · `symbol` 전부 무변경.
**아래 표에 없는 21종은 이미 판타지였고 그대로 뒀다.**

| id | 전 | 후 |
|---|---|---|
| `c_rapier_01` | 급한 견습 레이피어 | 성급한 견습 세검 |
| `c_rapier_02` | 초침 레이피어 | 찰나의 세검 |
| `c_rapier_03` | 가벼운 은빛침 | 가벼운 은빛 침검 |
| `c_greatsword_01` | **무거운 야근검** | 무거운 파수검 |
| `c_greatsword_02` | 철판 대검 | 무쇠판 대검 |
| `c_dagger_02` | **잔업용 쌍칼 한쪽** | 짝 잃은 쌍검 |
| `c_neck_01` | 초보자의 모래시계 목걸이 | 견습의 모래시계 목걸이 |
| `c_neck_02` | 싸구려 톱니 목걸이 | 값싼 톱니 부적 |
| `c_neck_03` | 행운 1그램 펜던트 | 한 줌 행운의 펜던트 |
| `c_ring_01` | **납기 반지** | 약속의 반지 |
| `c_ring_02` | 은근한 회복 반지 | 은은한 회복 반지 |
| `c_ring_03` | **경험 많은 척 반지** | 허풍쟁이의 반지 |
| `c_brace_01` | **대시 출석 팔찌** | 질주의 팔찌 |
| `c_brace_03` | 손목용 숫돌 | 손목 숫돌 |
| `c_brace_04` | 급조한 체인 팔찌 | 급조한 사슬 팔찌 |
| `r_rapier_01` | 분침의 레이피어 | 시간을 베는 세검 |
| `r_greatsword_01` | **주말 반납 대검** | 불면의 대검 |
| `r_neck_01` | 고장 덜 난 회중시계 | 금 간 회중시계 |
| `r_neck_02` | **재장전 감독관 목걸이** | 속결 술사의 목걸이 |
| `r_neck_03` | 파란 별의 이름표 | 푸른 별의 인장 |
| `r_ring_01` | **두 번째 서명 반지** | 메아리 서약의 반지 |
| `r_brace_01` | 순간이동 흉내 팔찌 | 설익은 도약의 팔찌 |
| `r_brace_03` | 파란 방진 팔찌 | 푸른 방벽 팔찌 |
| `u_rapier_01` | 시간 절도 레이피어 | 시간을 훔치는 세검 |
| `u_greatsword_01` | **회의종결 대검** | 결단의 대검 |
| `u_dagger_01` | **세 번 확인한 단검** | 세 번 벼린 단검 |
| `u_neck_01` | **보랏빛 공장장 목걸이** | 보랏빛 대장장의 목걸이 |
| `u_ring_02` | 피의 배당 반지 | 피의 공물 반지 |
| `u_ring_03` | **보라색 경력 반지** | 보라색 연륜의 반지 |
| `u_brace_01` | 무적은 짧게 팔찌 | 찰나 무적의 팔찌 |
| `h_rapier_01` | 시간을 찢는 초침 | 시간을 찢는 바늘 |
| `h_greatsword_01` | **마감파괴 대검 아포칼립스** | 종말을 부르는 대검 |
| `h_neck_01` | **영웅의 납기 조작기** | 영웅의 시간 왜곡석 |
| `h_ring_01` | 두 번 누르는 왕의 반지 | 두 번 울리는 왕의 반지 |
| `h_ring_02` | **불사 야근 반지** | 죽지 않는 자의 반지 |
| `h_brace_01` | **빨간 칼퇴 팔찌** | 붉은 질풍 팔찌 |

> ⚠️ `game.gd:6786`이 상점 오퍼에 **이름을 복사 저장**한다 → v2 세이브에 옛 이름이 남는다.
> **V9의 schema 3 폐기가 자동 해결한다**(설계 §9 · §10 리스크 #9). 별도 조치 불필요.

스킬 개명은 §2 표의 굵은 이름 14장(원소가 바뀐 카드 + 형태가 바뀐 카드)이고,
트로피 카드 개명은 §6 표에 있다. 몹은 `cultist` "월식 주술사" → **"잠식 주술사"** 1건.

---

## 5. 보스 3종 (`scripts/boss_library.gd`)

### 5.1 리그 5벌 (§3.1 실측표를 코드로 옮긴 것)

| 키 | 이름 | 소스 | 셀 | 애니메이션 | 특기 |
|---|---|---|---|---|---|
| `A` | 서릿발 외눈 | `DemonCyclop2` | 50×50 | idle5 walk6 hit3 | **Attack 없음** → 발구름 + 바닥 링 VFX로 흡수. 예비 `GiantBamboo` |
| `B` | 역병 점액왕 | `GiantSlime2` | 62×52 | idle5 hit5 jump13 | **Walk/Attack 없음** → 이동·공격을 전부 Jump로 |
| `C` | 홍염 천구 | `TenguRed` | 82×82 | idle6 walk10 attack15 hit8 trans11 | 가장 풍부 |
| `B+` | 흑점액 변종 | `GiantSlime` + 자주 틴트 `9a5bb5` | 62×52 | 동일 | |
| `C+` | 흑천구 | `TenguRed` + 암색 틴트 `3b2b46` | 82×82 | 동일 | `intro_anim: "trans"` — 소형→대형 변신 11f를 **등장 연출**로 |

### 5.2 패턴 12개 (디자인 3 × 4)

`PATTERNS[design]`은 **항상 4개**를 든다. 기본형은 앞 3개(3칸), 강화형은 4개 전부(4칸),
강림(§6.6)은 기본형 + 1칸이라 **A도 4칸**이 된다.

| 디자인 | 칸 | 패턴 | 원소 | 형태 | telegraph | status | 비고 |
|---|---|---|---|---|---:|---|---|
| **A** | 1 | 서리 발구름 | ice | wave | 0.55 | chill | 반경 260 링 |
| | 2 | 빙주 낙하 | ice | trap | 0.80 | chill ×1.35 | 예고 원 3개 |
| | 3 | 뇌격 방출 | thunder | pierce | 0.45 | shock | **chill이면 피해 ×1.6** |
| | 4 | 빙하 붕괴 | ice | wave | 1.05 | chill ×1.6 | ⚠️ **설계 미지정 · 강림 전용 뼈대** |
| **B** | 1 | 도약 압살 | poison | wave | 0.70 | poison ×2스택 | Jump 13f |
| | 2 | 산성 분비 | poison | trap | 0.60 | poison | 장판 3개 · 8초 잔류 |
| | 3 | 분열 | **(없음)** | guard | 0.90 | **(없음)** | 소형 3기 · HP 12% · 독 보유 |
| | 4 | 역병 파열 | poison | wave | 1.10 | poison ×2 | 전체 화면 · 스택당 +0.35 |
| **C** | 1 | 기름 날개 | oil | wave | 0.50 | oil | 피해 0.25 · 바닥 도포 |
| | 2 | 활공 참격 | strike | slash | 0.35 | (없음) | 가장 빠름 |
| | 3 | 화염 강하 | fire | trap | 0.85 | burn | 기름 위 = 대폭 연소 |
| | 4 | 흑염 회오리 | fire | wave | 1.20 | burn | 3초 잔류 · 잔여 기름 전부 인화 |

**패턴은 카드와 같은 스키마**(`PATTERN_REQUIRED_KEYS` 17키)이므로 `DealCycleController` ·
`FactoryDeck.ensure_slot_count()` · 마왕 레일 밴드 HUD가 **그대로 먹는다**. 추가 키는
`status` · `telegraph` 둘뿐이고, 선택 키(`summon_count` `lingering` `arena_wide`
`paints_ground` `ignites_ground_oil` `conditional_status` `bonus_per_player_stack`)는
V7이 실행할 때 읽는 힌트다.

### 5.3 강화형 파생 — 데이터 한 벌로

`BossLibrary.patterns(design, enhanced, descended)` 하나가 §3.4 규칙을 전부 적용한다.
**강화형 데이터를 두 벌 저작하지 않았다.**

```
칸 3 → 4                     GameTuning.STAGE_BOSS_SLOT_COUNT(_ENHANCED)
RELOAD 0.75 → 0.55           GameTuning.STAGE_BOSS_RELOAD_MUL(_ENHANCED)
telegraph 전부 × 0.85        GameTuning.STAGE_BOSS_TELEGRAPH_MUL_ENHANCED
상태 1종 → 2종               BossLibrary.secondary_status(design)  A=shock B=burn C=oil
페이즈 1회 → 2회             GameTuning.STAGE_BOSS_PHASES(_ENHANCED)
```

`resolve(design, enhanced, descended)`가 완성 딕셔너리를 낸다.
**`uses_runes: false` · `uses_heat: false` · `uses_reload: true`** — 이 세 줄이
"5칸 + 각인 + 과열은 마왕만 가진다"(부록 A-2 ⑫)의 기계적 경계다.

### 5.4 ⚠️ `DESIGN_HP`는 뼈대다

`hp_for(design, stage_hp_base, dwell, descended)`가 §3.4 식을 구현한다:
`DESIGN_HP[design] × stage_hp_base × (1 + 0.08 × dwell) × (강림이면 1.15)`.
**왼쪽 항의 값(A 2600 / B 3200 / C 3800)은 설계에 없다.** 자릿수만 맞춘 뼈대이고
근거는 v2 실측 두 개(hellhound 682 HP · 마왕 기저 611 HP)뿐이다.
**V10이 balance_probe로 확정한다.** 그때까지 이 숫자에서 다른 수치를 유도하지 말 것.

### 5.5 로테이션은 여기 없다

`GameTuning.STAGE_BOSS_DESIGN = ["A","B","C","B","C"]` / `STAGE_BOSS_ENHANCED = [f,f,f,t,t]`가
정본이다(V0이 이미 선언). `boss_library`는 `design`/`enhanced`를 **받아서** 쓴다 —
로테이션을 두 곳에 두지 않기 위해서다. V7은 tuning에서 읽어 `resolve()`에 넘기면 된다.

---

## 6. 보스 트로피 12종 배분 (`scripts/trophy_library.gd`)

보스를 잡으면 ①**중립 스탯 보너스 1개(고정)** + ②**특별 카드 2택1**을 받는다.
고른 쪽은 레일에, **버린 쪽은 마왕에게**(불변 원칙, 부록 A-1 ⑨).

| 스테이지 | 보스 | 트로피 이름 | 고정 스탯 보너스 | 2택1 (등급) |
|---|---|---|---|---|
| 1 | A | 서릿발 외눈의 뿔 | 체력 +24 · 수호막 +1 | `holy_verdict` **초념 연속 심판**(초) / `crimson_loop` **역병의 난무**(독) — 상급 |
| 2 | B | 역병 점액왕의 핵 | 피해 +6 · 처치마다 체력 +1.5 | `dragon_pierce` 용창 관통격(타) / `pain_compiler` 고통 연성진(독) — 상급 |
| 3 | C | 홍염 천구의 깃 | 전체 피해 ×1.12 · 사거리 +34 | `echo_thrust` 잔영 연속 찌르기(타) / `aegis_process` 영겁의 방패 파동(초) — 상급 |
| 4 | B+ | 흑점액의 응결핵 | 체력 +34 · 치명타 +8% · 관통 +1 | `red_moon_execution` **독월 최후의 참격**(독) / `sky_dragon_array` 천룡 진형 폭주(타) — **전설** |
| 5 | C+ | 흑천구의 심장 | 피해 +12 · 전체 피해 ×1.15 · 투사체 +1 · 수호막 +1 | `heavens_gate` 천상문 개방(초) / `immortal_frenzy` 불멸의 광란(독) — **전설** |
| 예비 | — | (중복 방지 대체 후보) | — | `zero_damage_oath` 불가침의 서약(초) / `infinite_recursion` 영겁 회귀 창술(타) |

- **5회 × 2장 = 10장 + 예비 2장 = SPECIALS 12종을 정확히 소진한다**(§5.5 "거의 다 소진").
  `data_test`가 12종 전량이 배분표에 정확히 한 번씩 나타나는지 단언한다.
- **2택1 두 장은 언제나 서로 다른 원소다.** 그래야 선택이 "어느 쪽이 세냐"가 아니라
  "내 5칸이 지금 어느 원소를 원하냐"가 된다(결속·공명과 맞물린다). `data_test`가 단언한다.
- `effect` 스키마는 **`player._apply_class_effect()`가 읽는 것과 정확히 같다.**
  함수 본문은 무변경이고 **입력 딕셔너리만** 여기서 온다(§5.5 지시 그대로).
  `data_test`가 미지의 키(조용히 무시되는 오타)를 잡는다.
- `merge_effects(stages)`가 저장 키 `trophy_effects`(§9) 복원용 병합을 한다 —
  곱연산 키(`damage_mul` `interval_mul`)는 곱하고 나머지는 더한다.
- **SPECIALS 12종의 계보 색을 지웠다**: "성기사 전용." 같은 문구 제거, 원소 승계
  (light→psi / blood→poison / iron→strike), 이름 4건 개명
  (초념 연속 심판 · 역병의 난무 · 독월 최후의 참격 · 천상문/불가침 desc 정리).
  `tier2` 키는 **남겼다** — 각성 표식이 아니라 **트로피 등급**으로 재해석된다.

### V8에게
`advancement_choice` 모달은 `TrophyLibrary.choices_for(stage)`를,
고정 보너스는 `TrophyLibrary.effect_for(stage)`를 `player._apply_class_effect()`에 그대로 넘기면 된다.
`class_library.gd` 삭제 시 참조 22곳(game.gd 9 · player.gd 3 · combat_resolver.gd 1 · test_runner.gd 9)을
함께 끊을 것. 원본은 `docs/v1-archive/class_library_v2.gd.txt`에 있다.

---

## 7. `class_library.gd`를 어떻게 처리했나 (소유권 판단)

**삭제하지 않았고, 호환 shim도 만들지 않았다.** 설계 부록 B V2의 소유권 경계
("`class_library.gd`는 삭제하지 않고 남긴다 — V8이 참조를 끊은 뒤 삭제")를 그대로 따랐다.
`TrophyLibrary`와 `ClassLibrary`는 **class_name이 달라 공존해도 아무것도 깨지지 않는다.**
`game.gd`의 22개 호출부는 전부 그대로 컴파일되고 실행된다.

**다만 `element` 문자열 3개는 바꿨다** (`light`→`psi` · `blood`→`poison` · `iron`→`strike`,
`element_name`/`tier*_desc`의 한글 표기 동반). 이유:

> 원소 재편은 개명이 아니라 **역할 승계**다. 옛 문자열을 남기면
> `game._lineage_rune_tag_count("light")`가 **존재하지 않는 원소**를 세게 되어 2차 각성
> 조건이 영원히 충족되지 않는다. 실측으로 확인했다 — 바꾸기 전
> `--castle-test`가 `awakening_day6=false lineage=paladin tags=0`으로 실패했고,
> 세 문자열을 승계시킨 뒤 `awakening_day6=true lineage=lancer tags=3`으로 **복구됐다.**

계보 구조 · 수치 · 이름 · `tier*_choices` · `tier*_effect`는 한 글자도 건드리지 않았다.

---

## 8. 몹 스테이지 티어 (`monster_library.gd`)

**v2의 일수(`unlock`) 게이팅은 한 줄도 바꾸지 않았다.** 아래는 전부 가산이다 —
game.gd가 아직 일수 축으로 스폰하고, 스테이지 축으로 갈아끼우는 것은 V4/V5의 일이다.

| 스테이지 | 새로 합류 | 티어 | 누적 종 수 | 설계 §6.3 표기 |
|---|---|---|---:|---|
| 1 | 이끼콩 · 들멧돼지 · 뿔임프 · 붉은 늑대 | T1 | **4** | T1 4종 |
| 2 | 떠도는 해골 · 굶주린 그림자 | T2 | **6** | T1+T2 6종 |
| 3 | 푸른 위습 · 황야 오우거 | T3 | **8** | T2+T3 8종 |
| 4 | 잠식 주술사 | T3 | **9** | T3 9종 |
| 5 | 밤의 지옥견 | T4 | **10** | T3+T4 10종 |

> ⚠️ **설계 §6.3의 티어 이름과 종 수가 서로 어긋난다.** "T2+T3 8종"이 성립하려면 T3=6이어야
> 하는데 그러면 총합이 10을 넘는다. **종 수 4·6·8·9·10은 완전히 일관되므로 그쪽을 정본으로
> 삼고 풀을 누적으로 구현했다.** 티어 이름은 "그 스테이지에 새로 합류하는 무리의 격" 라벨로 남긴다.
>
> **누적을 고른 이유**: 5스테이지에서 하위 몹이 사라지면 dwell 물량 곡선
> (`base + 3 × min(d,6)`)이 채울 개체가 없어진다. 상위 몹만 78기를 세우면 난이도가 아니라 벽이다.
> 강해지는 것은 종 구성이 아니라 §6.2의 배율이 한다.

신규 API: `stage_unlock` · `tier_of` · `tier_ids` · `stage_pool` · `stage_spawn_allowed` ·
`stage_aggro_gate_ok` · `stage_spawn_weight` · `stage_spawn_table` · `stage_table_ok` ·
`roll_for_stage`. 상수: `STAGE_COUNT_REF` · `STAGE_SPECIES_COUNT` · `TIER_NAMES` · `RANGED_MIN_STAGE`.

**낮 선공몹 게이트의 v3 대응**: 일수가 무한해진 이상 일차 기반 게이트는 의미가 없으므로
`stage_aggro_gate_ok()`는 **스테이지 1 낮만** 막는다(사용자 요구 "처음에는 순한 몹만"의 v3 판).
밤은 전원 습격 모드라 항상 통과 — 1스테이지 밤에도 붉은 늑대가 나온다.

### V4/V5에게
`combat_resolver`의 스폰 경로를 `MonsterLibrary.roll(rng, cycle, ...)` →
`roll_for_stage(rng, stage, ...)`로 갈아끼우면 된다. **dwell 배율은 곱하지 않는다** —
`stage_spawn_weight()`는 구성비만 내고, §6.2의 HP/피해/물량/정예 배율은 V4가 따로 곱한다.

---

## 9. 프로브 결과

| 검증 | 결과 |
|---|---|
| `godot --headless --editor --quit` | **오류 0 · 경고 0** (전역 클래스 등록 정상) |
| `godot --headless -s res://scripts/test/rune_test.gd` | **exit 0** — 판정 19종 전부 true |
| `godot --headless -s res://scripts/test/data_test.gd` | **exit 0** — 판정 17종 전부 true |
| `-- --v4-test` | **PASS** (`=false` 0건) |
| `-- --castle-test` | **PASS** (`awakening_day6=true lineage=lancer tags=3`) |
| `-- --draft-test` | **PASS** |
| `-- --boss-test` | **FAIL — V2 소관 아님.** §10 참조 |

`run_all.sh`는 지시대로 실행하지 않았다(오케스트레이터의 직렬 최종 검증).

### 음성 대조 (각 1건 · 즉시 원복 확인)

| 프로브 | 주입한 결함 | 잡아낸 판정 | 원복 후 |
|---|---|---|---|
| `rune_test` | `REACTIONS`에서 `oil>fire` 한 줄 삭제 | `reactions_7`(3줄) + `reaction_channels`(2줄) → `RUNE_TEST_FAILED` | `RUNE_TEST_COMPLETE` |
| `data_test` | `lion_roar` 원소 fire → psi | `element_exact` — "원소 fire가 3장 / psi가 5장" → `DATA_TEST_FAILED` | `DATA_TEST_COMPLETE` |

### 검증력을 낮추지 않았다 — 오히려 올렸다

| 프로브 | v2 | v3 | 신규 판정 |
|---|---:|---:|---|
| `rune_test` | 16 | **19** | `elements_7`(순서·중복·비원소 위치) · `reactions_7`(7쌍 전수 + 와일드카드 + 음성 대조) · `reaction_channels`(potency/stun/RELOAD 3채널 + **"L1은 피해를 주지 않는다" 대조군 증명** + 음수 RELOAD 클램프) |
| `data_test` | 11 | **17** | `legacy_zero` · `element_exact`(정확히 4장) · `range_coverage`(근접/원거리) · `monster_stages` · `trophy_table` · `boss_table` |

기존 판정은 **하나도 완화하지 않았고 한 건은 강화했다** — `tag_playable`의 형태 하한을
v2의 ≥3에서 **≥5로 올렸다**(§5.1 완료 기준).

### rune_test의 몬테카를로 인구가 v3 재편에도 흔들리지 않는 이유
`CARDS` 배열의 인덱스 0~4 원소를 **화·빙·뇌·독·유**로 뒀다. 이 다섯은 L1 반응표에서
인접쌍이 `fire>ice`(증기)·`ice>thunder`(감전) 둘뿐이라 **v2와 반응 구성이 완전히 같다.**
수치와 배열 위치도 그대로라 §3.9 종료성 밴드의 기준선이 보존된다
(실측: `worst_mean_steps` 8.98 · `worst_cap_rate` 0.007 — v2와 동일).
신규 4쌍은 `_check_l1_reactions()`가 **전용 2·3칸 덱**으로 따로 검증한다.

### 주요 실측치

```
skills_total=28  skills_draft=28  skills_legacy=0  specials=12
el_fire=4 el_ice=4 el_thunder=4 el_poison=4 el_oil=4 el_strike=4 el_psi=4
fm_slash=7 fm_pierce=6 fm_wave=5 fm_trap=5 fm_guard=5
reload_bare=2.39 reload_mid=3.06 reload_rewind=2.25 reload_tempo=1.10 reload_heavy=4.64
reload_mean=2.69  (목표 3.0 ± 1.0)
stage1..5_species=4,6,8,9,10   tier1..4_count=4,2,3,1
trophies=5 trophy_cards_used=10 trophy_cards_reserve=2
boss_designs=3 boss_patterns=12 boss_hp_dwell4_mul=1.32 (몹 곡선 1.75보다 완만 ✓)
element_count=7 reaction_count=7 drain_debt_delta=0.1500
```

---

## 10. 지금 깨져 있는 것 1건 — **V2 소관 아님 (V4/V5 진행 중)**

`--boss-test`가 `SCRIPT ERROR: Invalid call. Nonexistent function 'reset_cycle' in base 'Nil'`로 죽는다.

- **위치**: `test_runner.gd:1512` `game.boss_cycle.reset_cycle()` — **⑥⑦ 강림 E2E** 구간.
- **원인**: V4가 `deadline_clock.gd`를 `StageClock`을 상속하는 **1.4KB 껍데기**로 교체했고,
  그 파일 주석이 스스로 밝히듯 `descent_triggered` **발화를 중단**했다
  ("시그널은 남기되 발화하지 않음 — V5가 배선 교체"). 강림이 안 일어나니 보스전이 시작되지
  않고 `game.boss_cycle`이 null인 채로 테스트가 진행된다.
- **V2와 무관하다는 근거**: 이 경로는 카드·아이템·몹·트로피·보스 **데이터를 한 번도 읽지 않는다.**
  같은 하네스의 `--v4-test`(보스 5칸·프리뷰·런타임 단언 포함)와 `--castle-test`는 전부 통과한다.
- **해소 시점**: 설계 부록 B가 예정한 대로 **V5**(강림 배선을 `descent_valve_ready()` 폴링으로
  교체) → **V7**(`--boss-test` 수정: 로테이션·B+/C+·마왕전 직행).

`--editor --quit`은 오류 0이므로 타 파일발 컴파일 오류는 없다(재시도 불필요).

---

## 11. 후속 웨이브가 바로 쓸 수 있는 것

| 필요한 것 | 부르면 되는 것 |
|---|---|
| V6 · 상태 부여 시 위력 배율 | `step_record["potency"]` (기본 1.0) |
| V6 · 쇄빙 경직 가산 | `step_record["stun_bonus"]` (기본 0.0) |
| V6 · 레일 반응 화살표 | `RuneEngine.reaction_name(reaction)` · `step_record["element"]` / `["prev_element"]` |
| V6 · 레일 원소 마크 7종 | `DealCardLibrary.element_name/element_role/element_is_producer` |
| V7 · 보스 한 마리 통째 | `BossLibrary.resolve(design, enhanced, descended)` |
| V7 · 보스 HP | `BossLibrary.hp_for(design, GameTuning.STAGE_HP_BASE[stage-1], dwell, descended)` |
| V7/V8 · 트로피 2택1 | `TrophyLibrary.choices_for(stage)` |
| V8 · 트로피 고정 보너스 | `TrophyLibrary.effect_for(stage)` → `player._apply_class_effect()` |
| V9 · `trophy_effects` 복원 | `TrophyLibrary.merge_effects(stages)` |
| V4/V5 · 스테이지 스폰 | `MonsterLibrary.roll_for_stage(rng, stage, night)` · `stage_pool(stage)` |
| UI · 카드 사거리 등급 | `DealCardLibrary.range_class(card)` → `"melee"/"mid"/"ranged"` |

## 12. V10이 확정해야 할 수치 4건

1. `BossLibrary.DESIGN_HP` — A 2600 / B 3200 / C 3800은 **자릿수만 맞춘 뼈대**다.
2. `frost_ring` · `whirlwind`의 range/reload/damage 상향분(§2.1 ①).
3. `TrophyLibrary` 고정 보너스 5종의 누적 크기 (체력 +58 · 피해 +18 · 전체 피해 ×1.288 등).
4. `BossLibrary.PATTERNS`의 damage/duration/action_ratio/reload/range/arc/hits —
   설계가 준 것은 element·form·telegraph·효과 서술 넷뿐이고 나머지는 카드 스케일 추정이다.
