# W9 인수인계 — 균열 완결 · 각성 v2 · 성 NPC 4종

> 작성: W9 구현 웨이브 / 2026-08-07
> 대상: **W10**(마왕전·결과 화면) · **W12**(통합·저장·밸런스) · W11(에셋)
> 검증: `--editor --quit` 오류 0 · `run_all.sh` **컴파일 + 10종 전부 PASS** ·
> `rift_probe` / `data_test` / `rune_test` 전부 PASS · 캡처 육안 검수 완료.

수정한 파일 5개:
`game.gd` · `class_library.gd` · `castle_interior.gd` · `test/test_runner.gd` · `test/run_all.sh`
\+ `world_grid.gd` **한 줄**(`TRIAL_CAMPS_ENABLED`).
`rune_engine` · `factory_deck` · `deal_cycle_controller` · `combat_resolver` · `deal_card_library` ·
`monster_library` · `item_library` · `enemy.gd` · `player.gd`는 **한 줄도 고치지 않았다.**

원본 보존(부록 C-2): `docs/v1-archive/class_library.gd.txt` · `docs/v1-archive/castle_interior.gd.txt`
(`game.gd.txt` · `world_grid.gd.txt` · `test_runner.gd.txt`는 이전 웨이브가 이미 보존).

---

## 1. 균열(Rift) 완결 — 설계 §5.5

### 1.1 훅 3개 (handoff-w8 §3.1~3.2 지시서 그대로)

| 위치 | 코드 |
|---|---|
| `_begin_run()` (run 시드 확정 직후) | `world.begin_run_rifts(run_cycle_seed)` |
| `_on_clock_milestone()` — `rift_1` / `rift_2` / `second_awakening` | `_maintain_rift_schedule()` |
| `_on_day_started()` (매일) · 계약 NPC의 일수 이동 직후 | `_maintain_rift_schedule()` |
| `_process()` 상호작용 폴링(0.12s) | `_check_rifts()` — 구 `_check_trial_camps()` 자리 |
| `_trial_enemy_defeated()` | `camp_id.begins_with("rift_")` → `_rift_enemy_defeated()` |

**개설을 "이정표 1회성 이벤트"가 아니라 스케줄 따라잡기로 구현했다.**

```gdscript
RIFT_SCHEDULE_DAYS = [2, 4, 6]
rifts_due(day)            # day까지 열려 있어야 하는 개수 (0/1/1/2/2/3/3)
_maintain_rift_schedule() # 열린 수 < due 이고 예산이 남아 있으면 채운다
```

이렇게 한 이유 두 가지:
1. `spawn_rift_near()`가 `"no_site"`로 실패해도 **다음 낮에 자동 재시도**된다(예산을 안 먹으므로).
2. 계약 NPC(§3)가 일수를 건너뛰어도 균열이 통째로 증발하지 않는다.

성 안에서 일수가 넘어간 경우를 위해 `_spawn_scheduled_rift()`는
`player.global_position` 대신 `field_return_position`을 쓴다(성 내부 좌표는 월드 좌표가 아니다).

### 1.2 정예 웨이브와 보상

| 항목 | v1 시련 캠프 | **v2 균열** |
|---|---|---|
| 상태 소유 | `camp_states`(4방향 고정) | `world.get_rifts()` + `game.rift_states`(진행 카운터만) |
| 마릿수 | 9 (정예 1) | **3~5 전부 정예** — `3 + rift["index"]`로 결정적 |
| 정예 배율 | ×5 | **×3** (`RIFT_ELITE_HEALTH_SCALE = 0.6`을 스폰 직후 곱한다) |
| 보상 | 시련 구슬 1개 | **각인 3택1(W6 드래프트 재사용) + 60 G + 체력 전회복** |
| 접근 반경 | 520px | 520px (그대로) |

> **정예 배율을 `enemy.gd`에서 내리지 않은 이유**: `mark_trial()`의 ×5는 `enemy.gd` 소유이고
> W9 담당 파일이 아니다. 스폰 직후 `max_health *= 0.6`으로 같은 결과를 냈고, 시련 캠프 경로는
> 어차피 꺼져 있어 다른 사용처가 없다. `enemy.gd`를 여는 웨이브가 상수를 3.0으로 바꾸면
> `RIFT_ELITE_HEALTH_SCALE`을 1.0으로 되돌리면 된다.

보상 드래프트는 `_show_rune_draft("rift", "playing")` 한 줄이다. **새 화면을 만들지 않았다.**
`state != "playing"`(성 안·모달 중)이면 골드·회복만 주고 드래프트는 열지 않는다.

### 1.3 시련 캠프 철거

- `world_grid.gd`의 `TRIAL_CAMPS_ENABLED := false` — **이번 웨이브가 world_grid에 넣은 유일한 변경.**
- `game.gd`에서 `_check_trial_camps()` · `_activate_trial_camp()` · 구슬 보상 경로를 **삭제**했다.
- `_trial_enemy_defeated()`는 **이름을 유지**한다 — `combat_resolver.enemy_defeated()`가
  `camp_id`를 여기로 보내기 때문이다. 지금은 순수 디스패처(전조 / 균열 2분기)다.
- `camp_states`(항상 빈 사전)와 `player.trophy_orbs`(항상 빈 배열)는 **저장 스키마 호환을 위해 남겼다.**
  `world_grid`의 `TRIAL_CAMPS` 상수·`get_trial_camps()`·`_draw_trial_camp()`도 그대로다.
- `--rift-test`의 `camps_off` 플래그가 "캠프가 정말 꺼졌는가"를 매 실행 단언한다.

HUD 나침반(W5)은 코드 변경 없이 즉시 살아났다 — `--capture-hud`에서
`균열 ↙ · 103m` / `남은 개설 2 / 3`이 표시되는 것을 육안 확인했다.

---

## 2. 각성(Awakening) v2 — 설계 §5.3

### 2.1 규칙 최종본

| 시점 | 조건 | 흐름 |
|---|---|---|
| **3일차** (`demon_castle_open` 이정표) | 없음 | **계보 3종 택1** → 각성 연출 → 특별 카드 2택1(미선택→마왕) → 배치 화면 |
| **6일차** (`second_awakening` 이정표) | 해당 계보 **원소 칸의 각인 ≥ 3** | 각성 연출 → 2차 특별 카드 2택1 → 배치 화면 |

- 폐기: R5 카드 2종 조건 · 대응 무기 조건 · 시련 구슬 4개 · 전승 현자 NPC ·
  `factory.consume_skill()` 재료 소모 · `player.clear_trophy_orbs()`.
- **각성의 대가는 시간이다.** 카드는 한 장도 사라지지 않는다.
- 2차 조건은 시간이 아니라 **빌드**다. 6일차에 못 채워도 조건을 채우는 순간 열린다
  (`_finish_rune_draft()`가 각인 부착 직후 다시 폴링한다).

### 2.2 `class_library.gd` — 구조 유지, 세 키 교체

```gdscript
ClassLibrary.AWAKENING_TIER1_DAY       # 3
ClassLibrary.AWAKENING_TIER2_DAY       # 6
ClassLibrary.AWAKENING_TIER2_RUNE_TAGS # 3
ClassLibrary.by_element(element) / unlock_day(tier) / required_rune_tags(tier)   # 신설
```

| 제거 | 신설 |
|---|---|
| `weapon_type` | `element` — 성기사 `light` · 광전사 `blood` · 창기사 `iron` |
| `skills` (R5 재료 2종) | `element_name` — `"광(光)"` 등 UI 표기 |
| `rank` (5) | — |

**3계보 · tier1/tier2 이름 · `tier1_choices`/`tier2_choices`(= SPECIALS 12종) · `effects` · `color`는
한 글자도 바꾸지 않았다.** `desc` 문장만 "시련 구슬" 서사에서 "원소 축" 서사로 바꿨다.

### 2.3 계보 선택 로직

```gdscript
_lineage_affinity(element)      # 레일 5칸 + 보관함에서 그 원소 카드 장수
_ranked_lineages()              # 친화도 내림차순 (동률은 정의 순서 — 결정적)
_lineage_rune_tag_count(element)# 그 원소 카드가 놓인 칸에 붙은 각인 총 개수
```

- 3종을 **전부 보여 주고** 친화도 1위를 맨 왼쪽·포커스·`· 추천` 배지로 제시한다.
  설계 §5.3의 "계보 3종 택1"을 지키면서 원소 분포를 의사결정 정보로 노출한 형태다.
- `automated_test`면 화면을 만들지 않고 친화도 1위를 즉시 확정한다(기존 전직 UI와 같은 규약).
- 키보드는 `state == "lineage_choice"`에서 **자체 처리**한다 —
  W6의 `_handle_choice_keyboard`를 건드리지 않으려는 것으로, 전조 보상(W4)과 같은 패턴이다.

> **⚠️ `_lineage_rune_tag_count`의 정의 근거**: `RuneEngine.RUNES`에는 `element` 키가 **없다.**
> 원소는 카드가 들고 있다. 그래서 "계보 태그 각인"을 **"그 원소 칸을 각인으로 키웠는가"**로 읽었다.
> §3.8의 태그 체계(공명·결속은 전부 칸의 원소를 본다)와 정합하며, 각성이 곧 "원소 축 몰빵"이 된다.

### 2.4 ⚠️ 카드 인스턴스에는 태그가 없다 (함정)

`DealCardLibrary.instance(id, rank)` → `{kind, id, rank}` — **`element`/`form`이 없다.**
태그는 정의(`by_id`)에만 있고 `ranked()`가 합쳐 준다. 따라서 `factory.slots[i]["card"]`를
직접 읽어 `element`를 꺼내면 **항상 빈 문자열**이다. W9는 `_card_element(card)` 헬퍼를 두고
정의를 통해 해석한다. 새 코드에서 원소를 볼 일이 있으면 이 헬퍼를 쓸 것.

---

## 3. 성 NPC 4종 — 설계 §7.2

**네 명이 모든 성에 전부 선다.** v1은 6종 중 4개를 뽑았지만 v2는 종류가 정확히 4개다.
순서만 성 id 해시로 결정적으로 회전시키고(`_castle_services()`), 좌표 셔플은
v1 그대로 `castle_interior.setup()`이 같은 해시로 처리한다.

| id | 이름 | 하는 일 |
|---|---|---|
| `card_shop` | 딜싸이클 카드상 | 스킬 2 + 장비 2 · 새로고침 `10 + 6n` G |
| `rune_shop` | 각인 세공사 | ①각인 3택1 구매 ②**카드 합성(통합)** ③칸 배율 강화 3종 |
| `pact` | 계약자 | 기한 3거래 (§4.4) · 각 방향 런당 2회 |
| `spy` | 밀정 | 마왕 각인 훔쳐보기 / 하나 지우기 |

### 3.1 카드 상점 — v2 정합 2건

1. **스킬 제안이 `DealCardLibrary.draft_pool()`(20종)에서만 나온다.** v1은 `SKILLS`(28종)를 써서
   W7이 내린 legacy 8종이 상점에 나왔다. `skill_swap` NPC의 교체 카드도 같이 고쳤다
   (handoff-w7 §8 "새 카드를 주는 모든 경로는 draft_pool()").
2. **아이템 구매가 장비 4부위로 직행한다**(§5.4). 보관함 경유가 아니다.
   같은 부위에 있던 장비는 보관함으로 밀려난다. 레일 칸은 하나도 먹지 않는다.

### 3.2 각인 세공사 — W2가 안전화해 둔 자리를 v2 의미로 교체

W2 §6이 "골드로 환산"만 해 두고 W9에 넘긴 "레일 강화술사" 자리다. 세 창구를 한 NPC로 모았다.

| 창구 | 값 | 비고 |
|---|---|---|
| 각인 3택1 | `70 + 30 × 구매횟수` G | `_show_rune_draft("rune_shop", "castle_interior")` — 끝나면 성 안으로 복귀 |
| 카드 합성 | 무료 | 구 `card_fusion` NPC를 그대로 통합. 랭크 체계·`fusion_candidates()` 무변경 |
| 칸 배율 | 95 / 72 / 78 G | `repeat` / `duration` / `reload`. W2가 "5칸에서도 유효"로 남긴 3종 |

랭크 표기 문구만 v2 정합으로 고쳤다: `최대 RANK 5` → `수치 성장은 R3에서 포화`
(저장 랭크 1~5 유지 · handoff-w7 §4의 2층 구조 그대로).

### 3.3 계약자 (§4.4)

```gdscript
PACT_LIMIT = 2          # 각 거래 런당 2회
PACT_SELL_GOLD = 90
pact_available(kind) / pact_uses_left(kind)   # 공개 API
```

| 거래 | 대가 | 얻는 것 | 게이트 |
|---|---|---|---|
| 하루를 판다 | 기한 −1일 | 각인 3택1 + 90 G | `days_left() > 1` |
| 하루를 산다 | 각인 1개 파괴 + 마왕에게 카드 1장 헌납 | 기한 +1일 | `day > 1` + 각인 보유 + 스킬 카드 보유 |
| 미래를 담보로 | 마왕 각인 +2 (`grant_boss_rune_shards(4)`) | **영웅 등급 각인 1개 확정** | 없음 |

- 일수 이동은 `clock.set_day_raw()` + `set_night_raw(false)` + `set_phase_elapsed_raw(0)`.
  **시그널을 내지 않으므로 이정표가 두 번 울리지 않는다.** 대신 `_pact_shift_day()`가
  `_maintain_rift_schedule()`를 불러 건너뛴 균열을 따라잡는다.
- "미래를 담보로"는 `_show_rune_draft(..., RuneEngine.RARITY_EPIC, 1)` — **1장만 제시**해
  확정 지급으로 만들고 미선택 조각(추가 마왕 성장)이 생기지 않게 했다.

### 3.4 밀정

| 거래 | 비용 | 효과 |
|---|---|---|
| 각인을 훔쳐본다 | 35 G | 마왕 5칸의 각인 **이름**을 공개(`spy_revealed`, 런당 1회) |
| 각인 하나를 지운다 | 85 G | 각인이 가장 많이 쌓인 칸에서 `demon_lord.strip_rune()` |

전조 격파(§4.5)와 함께 마왕 스노볼의 두 번째 밸브다. 화면은 마왕 5칸 요약을 함께 보여 준다.

### 3.5 v1 잔존 경로

`skill_remove`(망각의 사제) · `skill_swap`(운명의 직조사) · `merchant` · `boss_remove` ·
`armorer` · `inn`은 **NPC로 배치되지 않지만 `_use_service()` 경로와 `_service_info()` 항목이 살아 있다.**
`--castle-test`의 `npc_remove` / `npc_swap` 회귀가 그대로 통과한다. 완전 삭제는 W12 판단.

---

## 4. 테스트

### 4.1 `--castle-test` (구 `--v4-castle-test` · 전면 재작성)

플래그 17종. 옛 플래그 `--v4-castle-test`도 같은 메서드로 남겼다(다른 스크립트 호환).
마커는 `CASTLE_TEST_COMPLETE`.

```
CASTLE_TEST_COMPLETE castle_npcs=true shop=true refresh=true shop_equip=true fusion=true
  rune_shop=true mage=true mage_gate=true upgrade_refund=true npc_remove=true npc_swap=true
  pact_sell_day=true pact_buy_day=true pact_limit=true spy_remove=true
  awakening_day3=true awakening_day6=true lineage=paladin tags=3
```

| 플래그 | 검사 |
|---|---|
| `castle_npcs` | NPC 4종 = `CASTLE_SERVICES_V2` · 같은 성 id면 같은 순서(결정성) |
| `shop` `refresh` | 4칸 · 스킬은 `draft_ids()` 안에서만 · 새로고침 골드 차감 |
| `shop_equip` | 아이템 구매 → `factory.equipment` +1, **레일 칸에 아이템 0개** |
| `fusion` | 합성 → `get_rank_count(id, 2) == 1` |
| `rune_shop` | 골드 차감 → `rune_draft` 3택 → 2단계 → 부착 → `castle_interior` 복귀 · 다음 가격 상승 |
| `mage` `mage_gate` `upgrade_refund` | 칸 배율 회귀 3종(W2가 남긴 것 그대로) |
| `npc_remove` `npc_swap` | v1 NPC 경로 회귀 + 교체 카드가 드래프트 풀 안 |
| `pact_sell_day` | 일수 +1 · 골드 +90 · 각인 상자 진입 · 잔여 횟수 1 |
| `pact_buy_day` | 일수 −1 · 각인 −1 · `rejected_skills` +1 |
| `pact_limit` | 2회 소진 시 `pact_available` false · 담보 거래가 조각 +4 · **제시 각인이 epic 1장** |
| `spy_remove` | `rune_count` −1 · `stripped_runes` +1 · 골드 −85 · 훔쳐보기 1회 |
| `awakening_day3` | 3일차 → 계보 확정 → 특별 카드 → `advancement_tier == 1` · 미선택 1장이 마왕에게 |
| `awakening_day6` | 조건 미달/5일차에는 안 열리고, 6일차 + 태그 3에서만 tier 2 |

### 4.2 `--rift-test` (신설 · 균열 E2E)

```
RIFT_TEST_COMPLETE begin=true schedule=true spawn=true wave=true clear=true reward=true
  reclear=true budget=true camps_off=true elites=3 rifts=3 distance=1079
```

스폰(2일차 이정표 실경로) → 접근 → 정예 3~5기 → 중복 스폰 없음 → 전멸 → 클리어 표시 →
보상(골드·전회복·각인 3택1) → 부착 → 재활성화 안 됨 → 예산 3개 상한 → 시련 캠프 OFF.

### 4.3 `run_all.sh`

`ALL_TESTS`에서 `--v4-castle-test` → `--castle-test`로 교체하고 `--rift-test`를 추가했다(총 10종).
`ALL_CAPTURES`에 `--capture-castle` 추가.

```
PASS compile / world-test / v4-test / castle-test / rift-test / stress-test /
     smoke-test / combat-test / deadline-test / cycle-test / draft-test
==================== 종합 결과: PASS ====================   (49초)
```

`--deadline-test`의 이정표 검사는 손대지 않았고 그대로 통과한다 —
새 훅은 `_on_day_started` / `_on_clock_milestone`에 붙었고, 그 테스트는 **밤 전이**와
**순수 클럭 인스턴스**를 쓰기 때문에 서로 닿지 않는다.

별도 실행 테스트도 회귀 없음: `rift_probe` `failures=0` · `data_test` 11종 true · `rune_test` 16종 true.

### 4.4 캡처 (비headless 육안 검수 완료)

| 파일 | 확인한 것 |
|---|---|
| `castle-minimal-v2-room.png` | NPC 4명(밀정/계약자/딜싸이클 카드상/각인 세공사) 이름표가 HUD에 안 가림 |
| `castle-minimal-v2-rune-shop.png` | 창구 3개 · 가격 · 합성 가능 조합 수 |
| `castle-minimal-v2-pact.png` | 거래 3종 · 잔여 횟수 · 조건 미달 거래가 회색(하루를 산다) |
| `castle-minimal-v2-spy.png` | 마왕 5칸 카드명 + 각인 이름(열람 후) |
| `castle-minimal-v2-lineage.png` | 계보 3장 · 추천 배지 · 원소 표기 |
| `world-minimal-v2-rift.png` | 균열 아레나(안전 바닥 + 마젠타 링) + 왕관 쓴 정예 3기 |
| `hud-minimal-v2-day.png` | `균열 ↙ · 103m` `남은 개설 2 / 3` · 칸의 **원소 마크**(철/뇌/화) |

`--preview-trial`은 `--preview-rift`와 같은 균열 프리뷰로 교체했다(캠프가 꺼져 옛 코드가 크래시했다).
`--preview-evolution`은 3일차 각성 경로로 갱신했다.

---

## 5. ⚠️ 소유권 경계를 넘은 곳 (보고 대상 · 전부 가산)

| # | 위치 | 소유 | 변경 | 이유 |
|---|---|---|---|---|
| 1 | `_rail_element_mark()` | W5 | 1줄 | `factory.slots[i]["card"]`가 원시 인스턴스라 **원소 마크가 항상 빈칸**이었다. `_card_element()`로 정의를 통해 해석. **레이아웃 무변경** |
| 2 | `_finish_rune_draft()` 끝 | W6 | 1줄 `_check_first_advancement()` | 2차 각성 조건이 "각인 개수"라 각인 부착이 유일한 조건 변화 지점이다 |
| 3 | `_show_rune_draft` / `_roll_rune_draft` | W6 | 선택 인자 2개(`rarity_filter` `option_count`) 추가 | 계약 "미래를 담보로"의 영웅 각인 확정. **기본값이 있어 기존 호출부 무변경** |
| 4 | `_save_run_snapshot` / `_restore_run_snapshot` | W12 | 키 5개 추가 | handoff-w8 §3.4가 W12에 준 그 스니펫. 지금 안 넣으면 이어하기 후 균열이 통째로 재활성화된다 |
| 5 | `_run_v4_test`의 `physical_e` 단언 | W2 | `services.has("card_fusion")` → `"rune_shop"` | 성 구성이 4종 고정으로 바뀌어 구 단언이 즉시 실패 |
| 6 | `world_grid.gd` | W8 | `TRIAL_CAMPS_ENABLED := false` | **지시서가 허용한 한 줄** |

저장 스키마에 추가한 키: `rift_state`(= `world.export_rift_state()`) · `rift_states` ·
`pact_uses` · `rune_shop_purchases` · `spy_revealed`. `schema_version`은 2 그대로 뒀다
(가산 키만 늘었고 없는 키는 전부 기본값을 탄다). **버전을 올릴지는 W12 판단이다.**

---

## 6. 남겨 둔 것 · 다음 웨이브 체크리스트

### W10 (마왕전 · 결과 화면)
- `demon_lord.strip_rune()` 사용처가 **전조(W4) · 밀정(W9)** 둘로 늘었다. 프리뷰에서 뜯긴 각인 수
  (`stripped_runes.size()`)를 표시하면 두 밸브가 실제로 작동했음이 읽힌다.
- `spy_revealed`가 켜져 있으면 마왕 프리뷰에서도 각인 **이름**을 그대로 보여 주는 게 자연스럽다
  (지금은 밀정 화면에서만 보인다).
- 승리 등급 `demon_lord.victory_grade(clock.day_number, clock.descended)`는 그대로다.
  단 **계약으로 일수가 움직인다** — 등급이 "지금 몇 일차인가"만 보므로 하루를 사면 등급이 내려간다.
  의도된 대가지만 결과 화면 문구가 그 사실을 말해 주는 편이 좋다.
- 각성 특별 카드는 `player.class_skill_id`에 그대로 들어간다(v1 계약 무변경).

### W12 (통합 · 저장 · 밸런스)
- **미구현 이정표 1건: `eclipse`(5일차 월식 — 마왕이 필드 몹에게 각인 배포).** 배너만 있다.
  설계 §4.1/§6.4 소관이며 W7/W10 경계라 W9는 손대지 않았다.
- 죽은 스키마 정리: `camp_states`(항상 빈 사전) · `player.trophy_orbs`(항상 빈 배열) ·
  `world_grid.get_castle_services()`(호출부 0) · `world_grid.TRIAL_CAMPS` 상수 ·
  `_draw_trial_camp()` · `player.gd`의 구슬 렌더 루프(L623).
- **밸런스 손잡이 (W9가 새로 만든 숫자)**

  | 상수 | 값 | 관측점 |
  |---|---|---|
  | `RIFT_ELITE_HEALTH_SCALE` | 0.6 (= ×5 → ×3) | `--rift-test`의 클리어 소요 |
  | `RIFT_REWARD_GOLD` | 60 | 7일 총 골드 수입 |
  | `RUNE_SHOP_BASE_PRICE` / `_STEP` | 70 / 30 | 런당 각인 총량(설계 §5.1 추정 12~13개) |
  | `PACT_SELL_GOLD` | 90 | "하루를 판다"가 지배 전략이 되는지 |
  | `SPY_REVEAL_COST` / `SPY_REMOVE_COST` | 35 / 85 | 마왕 각인 최종 수 |
  | `ClassLibrary.AWAKENING_TIER2_RUNE_TAGS` | 3 | 2차 각성 도달률 |

- 균열 예산 3개 · 각성 2회 · 계약 6회(3거래 × 2)가 전부 소진되는 런이 정상인지 실기 확인 필요.
- 설계가 요구했으나 W8이 남긴 미결 2건은 그대로다: 마왕성 거리 8,628 → 5,600, 성 밀도 9% → 상향.
  **성 밀도는 이제 더 민감하다** — 계약·각인 상점이 성에만 있어서, 성을 못 만나면 v2의 성장 축 하나가 통째로 막힌다.

### W11 (에셋)
- `castle_interior.gd::service_visual()`에 v2 4종 항목이 들어갔다. NPC 스프라이트를 붙일 자리는
  `_draw_npc()` 하나뿐이며 색·이름 매핑은 그 static 함수가 단일 창구다.
- 계보 선택 화면(`_lineage_button`)은 지금 텍스트 카드다. 계보 초상화가 들어오면
  `body_panel` 상단 3px 색 바 자리를 그대로 쓰면 된다.

---

## 7. 알아 둘 함정

1. **카드 인스턴스에 `element`/`form`이 없다**(§2.4). 원소를 볼 때는 `_card_element()`를 쓸 것.
2. **`_check_first_advancement()`는 이름과 달리 1·2차를 모두 본다.** 호출부 8곳과 test_runner를
   지키려고 이름만 유지했다. 각성 게이트를 새로 폴링할 곳이 생기면 이 함수를 부르면 된다.
3. **계약의 일수 이동은 시그널을 내지 않는다.** `set_day_raw()`를 직접 쓰는 새 코드는
   `_maintain_rift_schedule()` + `_check_first_advancement()`를 뒤에 붙일 것(`_pact_shift_day()` 참조).
4. **균열 개설은 "이정표 1회"가 아니라 "밀린 만큼 채우기"다.** 개수를 세는 쪽(`rifts_due`)을
   고치지 않고 `RIFT_SCHEDULE_DAYS`만 바꾸면 스케줄 전체가 따라온다.
5. **`_grant_rift_reward()`는 `state == "playing"`일 때만 드래프트를 연다.** 성 안에서 균열이
   클리어되는 경로는 없지만, 방어선을 지워서 모달 위에 모달이 겹치지 않게 할 것.
6. **`lineage_choice`는 자체 키보드 처리다.** W6의 `_handle_choice_keyboard`에 넣지 말 것 —
   그쪽은 `choice_buttons` 단일 포커스 모델이고 계보는 3칸 전용 포커스를 쓴다.
7. 공용 위젯 팩토리(`_style_button`)의 focus 스타일박스는 버튼 전체에 계보 색을 깐다.
   밝은 색(성기사 노랑) 카드에서 본문이 묻히므로 `_lineage_button`은 **안쪽에 불투명 판**을 하나 깔았다.
   같은 문제가 있는 새 카드 UI는 이 패턴을 쓸 것(`_style_button`은 공용이라 건드리지 않는다).
8. `--castle-test`는 계보를 **친화도로 결정**하므로 덱 구성이 바뀌면 `lineage=`가 달라진다.
   테스트는 그걸 전제로 `advancement_branch_id`를 읽어 원소 카드를 고른다 — 하드코딩하지 말 것.
