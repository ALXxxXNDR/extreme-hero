# handoff-v8 — 성장 재편 · 보스 트로피 · 계약 · 결과 화면 v3

> 웨이브 **V8** (설계 `docs/GAME_DESIGN_V3.md` §5.5 · §6.5 · §2.5 · §10 #4 · 부록 A-3 ② · 부록 B의 V8). 2026-08-09.
> **읽는 사람: V9(저장 schema 3) · V10(통합·밸런스·문서).**
> 한 줄 요약: **계보와 각성이 사라지고 그 자리에 보스 트로피가 섰다.** 관문을 깨면
> 고정 스탯 하나가 즉시 붙고 특별 카드 2택1이 열리며, 버린 한 장은 늘 그랬듯 마왕에게 간다.
> 5칸이 R3로 포화하면 레벨업이 스스로 각인 드래프트로 바뀌고, 결과 화면에서
> 7일 기한의 언어가 완전히 사라졌다.

| | |
|---|---|
| 소유·수정 | `scripts/game.gd`(각성·성·결과 구역) · `scripts/player.gd` · `scripts/class_library.gd`(**폐기 stub화**) · `scripts/test/test_runner.gd` · `scripts/test/run_all.sh` · `docs/v1-archive/class_library_v3.gd.txt`(추가) · 이 문서 |
| 무접촉 | `core/status_engine.gd` · `core/rune_engine.gd` · `core/stage_clock.gd` · `core/demon_lord.gd` · `core/combat_resolver.gd` · `core/tuning.gd` · `trophy_library.gd` · `boss_library.gd` · `deal_card_library.gd` · `item_library.gd` · `monster_library.gd` · `factory_deck.gd` · `deal_cycle_controller.gd` · `enemy.gd` · `world_grid.gd` · `castle_interior.gd` · `art/` · `AGENTS.md` |
| 검증 | `--editor --quit` 오류 **0** · `run_all.sh` **14종 전부 PASS**(77초) · 비headless 캡처 3종(`--capture-castle` 5컷 · `--capture-result` 2컷 · `--capture-boss` 9컷) 육안 확인 |

---

## 0. 이 웨이브가 실제로 한 것

| # | 항목 | 결과 |
|---|---|---|
| ① | 보스 트로피 2택1 | 격파 훅 소비 → 고정 스탯 즉시 적용 → 카드 2택1 → 5칸 배치 → 미선택은 마왕에게 |
| ② | 5스테이지 타이밍 | 트로피를 **마왕전보다 먼저** 준다. 필드 복귀는 여전히 0프레임 |
| ③ | 계보·각성 정식 폐기 | 화면 2개(`lineage_choice`·`evolution`) · 함수 10개 · 폴링 호출부 10곳 삭제 |
| ④ | `class_library.gd` | 데이터 전량 삭제 → `by_id()` 하나만 남긴 shim (원본은 v1-archive) |
| ⑤ | `player.gd` | `apply_advancement` → `apply_trophy` / `restore_trophies` / 끊어진 참조 1건 정리 |
| ⑥ | 성장 천장 1안 | 레일+보관함 R3 포화 → 레벨업이 각인 드래프트로 **자동 전환** |
| ⑦ | 계약 NPC | V5의 V3-J 배선을 점검·확정 + 게이트 1건 추가 단언. 로직 변경 0 |
| ⑧ | NPC 경제 정합 | 상점가 **스테이지 스케일**(카드상·각인 세공사·밀정). 1스테이지는 v2와 동가 |
| ⑨ | 결과 화면 v3 | 트로피·시너지·상태 반응 지표 신설, v2 기한/각성 어휘 **0개** |
| ⑩ | handoff-v7 미결 7 | 사망 시 보스 노드가 결과 화면 뒤에 남던 문제 수정 |
| ⑪ | 테스트 | `--castle-test` 트로피 3묶음 + `price_scale` · `--draft-test` `growth_cap` · `--boss-test` `result` 신설 |

---

## 1. 보스 트로피 — 흐름 전체

### 1.1 실제 경로 (game.gd)

```text
보스 격파  enemy._die() → game.on_stage_boss_defeated()
  ├─ _teardown_stage_boss()                      (V7 무수정)
  ├─ pending_stage_trophy = {stage, design, enhanced, descended, day, dwell}
  ├─ state = "playing"
  ├─ advance_stage()          완전 회복 · dwell ×0.5 · 월드 재생성  (V5 무수정)
  ├─ pending_trophy_followup = "demon"  ← 5스테이지 클리어였다면
  └─ call_deferred(_open_stage_trophy_choice)

_open_stage_trophy_choice()                       game.gd:9078
  ├─ player.apply_trophy(trophy)      ① **고정** 중립 스탯 보너스 — 선택지가 아니다
  ├─ _resolve_trophy_choices(stage)   이미 가진 카드면 예비 2종으로 치환
  └─ state = "advancement_choice"     ② 카드 2택1 (v2 상태 문자열 그대로)
       └─ automated_test면 call_deferred(_choose_trophy_card, 왼쪽, 오른쪽)

_choose_trophy_card(selected, rejected)           game.gd:9176
  ├─ selected_skills += selected · rejected_skills += rejected
  ├─ boss_advancement_skills += {"branch":트로피id, "tier":스테이지, "module":debt}
  ├─ pending_boss_toast_cards = [rejected]        고스트 레일 토스트 + 슬롯 점멸
  ├─ trophy_place_pending = true
  └─ _show_factory_menu("place", instance(selected,1), "playing")   5칸 배치

_finish_factory_return()                          game.gd:3799 (배치/ESC 공통 출구)
  └─ trophy_place_pending → call_deferred(_finish_stage_trophy)

_finish_stage_trophy()                            game.gd:9210
  ├─ pending_stage_trophy.clear() · pending_trophy.clear()
  └─ followup == "demon" → call_deferred(_challenge_demon_king)
```

### 1.2 **5스테이지 처리** — handoff-v7 §11-1이 경고한 그 자리

V7은 격파 콜백에서 곧바로 `_challenge_demon_king()`을 불렀다. 그대로 두면 마왕
프리뷰가 트로피 모달 위에 떠서 **5번째 트로피가 통째로 사라진다**(설계 §5.5의
"5회 × 2장 = 10장"이 4회 8장으로 줄어든다).

검토하고 버린 대안 3개:

| 대안 | 버린 이유 |
|---|---|
| 5스테이지는 트로피를 생략한다 | 설계 완료 기준이 "트로피 **5회** 지급"이다. 그리고 5번 트로피(`흑천구의 심장` — 피해 +12 · ×1.15 · 투사체 +1 · 수호막 +1)는 **마왕전을 위해 설계된 값**이다. 빼면 마왕전 난이도가 통째로 어긋난다 |
| 마왕 프리뷰 위에 트로피 모달을 겹친다 | `overlay`는 단일 슬롯이고 `_clear_overlay()`가 앞 화면을 지운다. 두 장을 겹치려면 오버레이 스택을 새로 만들어야 한다 — 단일 포커스 모델(부록 C-1)이 무너진다 |
| `advance_stage()`를 트로피 뒤로 미룬다 | 시도했다가 되돌렸다. `clock.advance_stage()`가 `stage_started` 시그널로 월드 재생성까지 **동기 실행**하는 한 덩어리라, 그 사이에 모달을 끼우면 재생성이 모달 위에서 일어난다. 게다가 `--boss-test`의 `defeat` 묶음이 보는 "격파 0.3초 뒤 stage +1"이 깨진다 |

**채택**: 전환은 V7 그대로 즉시 하고, **마왕전 호출만** `pending_trophy_followup`으로
한 칸 미룬다. 트로피 모달의 dim이 α0.96이라 그 뒤에서 일어나는 월드 재생성은
한 프레임도 보이지 않는다. **"필드 복귀 없이 마왕전"(부록 A-1 ③)은 그대로 지켜진다** —
`--boss-test`의 `demon_direct`가 `world.get_stage()` 불변으로 이를 단언한다.

### 1.3 예비 카드 치환 규칙 (V8이 확정한 것)

`trophy_library.gd`가 "배분 규칙 자체는 V8이 배선할 때 확정한다"고 남겨 둔 항목이다.

```
_resolve_trophy_choices(stage):
  배분표 2장을 순서대로 본다.
    이미 가진 카드( 레일 5칸 · 보관함 · selected_skills )거나 같은 쌍에서 중복이면
      → RESERVE_CHOICES(zero_damage_oath · infinite_recursion) 중 아직 없는 첫 장으로 치환
    예비 2장까지 전부 겹치면 → 원본을 그대로 낸다(빈 화면보다 낫다)
```
근거: 2택1이 "1택"이 되는 것을 막는 것이 예비 2장의 존재 이유다(전조 회수·마왕 탈환
경로로 특별 카드가 손에 들어올 수 있다). 오른쪽 카드는 되도록 배분표 원본을 지켜
"스테이지가 정한 짝"이라는 감각을 남긴다.

### 1.4 evolution 연출은 버리지 않았다

v2 전직 연출의 **18줄 광선**은 트로피 모달의 배경으로 이사했다(트윈 0 · 정지 화면
한 장 · 설계 §4.8). 초상(`PORTRAIT_SCRIPT`)은 "직업이 바뀐다"는 거짓말이 되므로 뺐다.
결과적으로 **화면 3장 → 1장**, **state 3개 → 1개**가 됐다.

---

## 2. 폐기 정리 내역

### 2.1 삭제한 것 (game.gd)

| 대상 | 규모 |
|---|---|
| `_check_first_advancement()` 본문 + **호출부 10곳** | 함수 1 + 호출 10줄 |
| `_show_lineage_choice` / `_lineage_button` / `_set_lineage_index` / `_choose_lineage` | 화면 1장 |
| `_begin_advancement` / `_accept_evolution` / `_finish_advancement` | 연출 1장 |
| `_show_advancement_card_choice` / `_choose_advancement_card` | **재작성**(트로피판으로) |
| `_lineage_rune_tag_count` / `_lineage_affinity` / `_ranked_lineages` | 계보 친화도 3함수 |
| state `"lineage_choice"` · `"evolution"` + `_unhandled_input` 분기 2개 | 상태 2개 |
| var `pending_lineage_branches` / `lineage_buttons` / `lineage_choice_index` / `pending_advancement` | 4개 |
| 상수 `LINEAGE_PANEL_RECT` / `LINEAGE_CARD_SIZE` | 2개 |

`_card_element()`는 각성 구역 안에 있었지만 **V6 HUD 레일 원소 마크가 쓴다**(`game.gd:1862`).
삭제하지 않고 위쪽 독립 구역으로 구조해 왔다.

### 2.2 `class_library.gd` — 삭제가 아니라 stub

**원본 보존**: `docs/v1-archive/class_library_v3.gd.txt` (V2가 원소를 psi/poison/strike로
고친 마지막 판). v1·v2판은 이미 아카이브에 있었다.

**지우지 못한 이유 — 참조 정리 결과가 정확히 1건 남았다:**

| 파일 | v2 참조 수 | V8 이후 |
|---|---|---|
| `game.gd` | 9 | **0** |
| `player.gd` | 3 | **0** |
| `test_runner.gd` | 9 | **0** |
| `core/combat_resolver.gd` | 1 | **1** ← 남았다 |

`combat_resolver.gd:823-824`가 검격 색을 뽑을 때 `ClassLibrary.by_id(...)` 를 부른다.
그 파일은 **V6 확정 + V8 수정 금지**라 열 수 없었다. 그래서 데이터를 전부 버리고
`by_id()` 하나만 남겨 `TrophyLibrary.by_id()`로 넘긴다(117줄 → **42줄**, 대부분 주석).

> 결과적으로 v3의 검격 색 = **마지막으로 획득한 보스 트로피의 색**이다.
> 계보 색이 하던 역할을 트로피가 이어받은 셈이라 의미도 맞는다.

**V10에게**: `combat_resolver.gd`를 소유하게 되면 그 두 줄을 `TrophyLibrary.by_id()`로
바꾸고 `class_library.gd` + `.uid`를 삭제하라. 확인 한 줄:
```bash
grep -rn "ClassLibrary" godot-game/scripts | grep -v class_library.gd
```

### 2.3 `player.gd` — 필드 두 개는 **이름만 남기고 의미를 바꿨다**

```gdscript
var advancement_branch_id := ""   # → 마지막으로 획득한 트로피 id
var advancement_tier := 0         # → 획득한 트로피 수 (0~5)
var trophy_stages: Array[int] = []  # ★ 스탯 계산의 유일한 입력
```
개명하지 않은 이유도 §2.2와 같다 — `combat_resolver.gd`가 `advancement_branch_id`를
직접 읽는다. **V9가 schema 3에서 저장 키를 정리할 때 함께 정리 대상이다.**

신규/변경 함수: `apply_trophy(trophy)` · `restore_trophies(stages)` ·
`trophy_effect_summary()` · `_rebuild_stats()`의 계보 2겹 → **트로피 1겹**
(`TrophyLibrary.merge_effects`) · `get_character_name()`의 계보 이름 분기 삭제 ·
`_draw()`의 후광 조건이 `tier >= 2` → **`grade == "legend"`**.

설계 §5.5가 지목한 **끊어진 참조 1건**(`player.gd:348~352`가 존재하지 않는
`tier1_skill`/`tier2_skill` 키를 읽던 것)은 `apply_advancement` 자체가 사라지면서 해소됐다.

---

## 3. 성장 천장 1안 (설계 §10 #4 · 부록 A-3 ②)

### 3.1 "배치할 곳이 없다"의 정의 — 설계에 없어서 V8이 정했다

`GameTuning.GROWTH_CAP_AUTO_RUNE_DRAFT`(V0이 심어 둔 스위치)를 여기서 처음 소비한다.
`_growth_cap_reached()`(game.gd:5418)가 **셋이 전부 참일 때만** 천장으로 본다:

1. 레일 5칸이 전부 스킬 카드로 차 있다(빈칸 = 기본 베기가 하나도 없다)
2. 그 다섯 장이 전부 R3(`DealCardLibrary.MAX_RANK`) 포화다
3. **보관함의 스킬 카드도 전부 R3다**

③을 뺄 수 없는 이유: 보관함에 R1이 한 장이라도 있으면 새 R1과 합쳐 R2 → R3로 가는
융합 경로가 살아 있어 카드가 **여전히 성장 수단**이다. 그때 자동 전환하면 플레이어의
선택을 뺏는다. 아이템 카드는 레일 칸을 점유하지 않으므로(§5.4) 세지 않는다.

`FactoryDeck.inventory`에 **용량 상한이 없다**는 점도 확인했다(`add_inventory`는 그냥
append). 그래서 "보관함이 가득 찬다"는 개수가 아니라 **랭크 포화**로 읽는 것이 유일하게
성립하는 해석이다.

### 3.2 전환 동작

```
_show_skill_choice("level")
  └─ source == "level" ∧ GROWTH_CAP_AUTO_RUNE_DRAFT ∧ _growth_cap_reached()
       └─ _convert_level_choice_to_rune_draft()      game.gd:5437
            ├─ growth_cap_conversions += 1           (결과 화면 지표)
            ├─ 배너 "레일 5칸이 전부 R3로 찼습니다 — 이번 레벨업은 각인 강화로…"
            └─ _choose_rune_draft()                  ← **W6 경로 무수정 재사용**
                 ├─ 두 스킬 카드 → 마왕에게
                 ├─ 레벨 정산(exp −target · level +1 · xp_target = 7 + 5L)
                 └─ _show_rune_draft("level", "playing")
```
보물상자(`source == "chest"`)는 전환하지 않는다 — 천장은 **레벨업 보상**의 문제다.
`MAX_RANK`는 3 그대로다(2안 미채택 → `data_test`의 포화 단언 무변경).

---

## 4. 계약 NPC — 점검 결과와 최종 규칙

**V5가 V3-J 계수 7개를 이미 배선해 뒀고 설계 §6.5 표와 어긋나는 곳이 없었다.**
V8은 로직을 바꾸지 않았고, 규칙을 문서화하고 게이트 1건을 테스트로 못 박았다.

| 거래 | 대가 | 얻는 것 | 게이트 | 한도 |
|---|---|---|---|---|
| **정비**(`sell_day`) | `120 + 60 × 사용횟수` G | dwell **−1** | `dwell > 0` ∧ 골드 충분 | 2회 |
| **탐욕**(`buy_day`) | dwell **+1** · 각인 1개 파괴 · 마왕에게 카드 1장 | 200 G + 각인 조각 1 | 붙은 각인 ≥1 ∧ 뺄 카드 ≥1 | 2회 |
| **미래를 담보로**(`mortgage`) | dwell **+2** | epic 각인 1개 **확정**(1장만 제시) | 없음 | 2회 |

확정한 다섯 규칙(전부 `--castle-test`가 단언):
1. 세 카운터는 서로 독립이고 각각 `PACT_LIMIT`(2)에서 막힌다.
2. dwell 0에서 정비는 **열리지 않는다** — 되살 압박이 없다.
3. 대가를 낼 수 없으면 탐욕은 **열리지 않는다** — 압박 판매가 공짜 수익원이 되면 안 된다.
   (V8 신설 단언: 각인을 전부 떼면 `pact_available("buy_day") == false`)
4. 미래를 담보로는 **1장만** 제시한다 → 확정 지급 + 미선택 조각(마왕 성장) 0.
5. dwell 이동은 반드시 `_pact_shift_dwell()`을 지난다 — 잠식 해제/재점화와 균열 스케줄을
   그 자리에서 따라잡는다.

### 4.1 NPC 4종의 v3 경제 정합 — **한 곳만 어긋났다: 가격**

설계 §8 표가 "카드 상점 · 각인 세공사 · 밀정 — 유지(무수정), **가격만 스테이지 스케일**"
이라고 적어 두고 수치를 주지 않았다. 런이 v2의 3배(5스테이지)라 골드 총량도 3배가
되는데 상점가가 그대로면 4~5스테이지 상점은 "보이는 대로 다 사기"가 된다.
§6.2의 보상 감쇠는 **dwell에만** 걸리므로 전진 플레이는 감쇠를 피해 간다.

```gdscript
const STAGE_PRICE_STEP := 0.35                      # game.gd:8397 (착수 기본값)
func stage_price_scale() -> float:                  # 1 → ×1.00 … 5 → ×2.40
	return 1.0 + STAGE_PRICE_STEP * float(maxi(0, clock.stage - 1))
```
적용 대상: 카드 상점 스킬가(24~42) · 아이템가(`ItemLibrary.price_for`) ·
각인 세공사(`_rune_shop_price()`) · 밀정(`spy_reveal_cost()` / `spy_remove_cost()`).
**계약에는 걸지 않는다** — 정비 비용식은 설계가 못 박았고 이미 "사용 횟수"라는 다른
축을 쓴다. **1스테이지는 ×1.00이라 v2와 완전히 같은 값이고 기존 회귀가 0이다.**

> ⚠️ **V10**: `STAGE_PRICE_STEP`은 설계에 없는 숫자다. `balance_probe`로 확정하고
> `tuning.gd`로 옮기는 것이 옳다. 밀정 상수 2개는 `const`가 남아 있고 함수가 감싼 형태다.

---

## 5. 결과 화면 v3

`_show_result()` 머리 주석에 v2 → v3 대응표를 실어 뒀다. 실물 구성:

```
머리말 14~78    "버린 운명을 넘어섰습니다" / "마왕 토벌 · 등급 A"
                부제: 등급은 총 일수만 봅니다 — 13 S / 17 A / 23 B · 밸브 C
타임라인 84~150 **다섯 관문** 5칸 (✓ / ▶) + "총 N일차 · 낮 · 최종 체류 D"
칩 1행 156      승리 등급 · 총 일수(S≤13) · 관문·최종 체류 · 최고 과열 · **보스 트로피 N/5 · 등급**
칩 2행 212      **시너지 발동 N회** · **상태 반응 · 도트 틱** · 반격 창·각인 · 마왕 카드·각인 · 균열·처치
레일 274~452    최종 5칸 + 각인 (마왕 프리뷰와 같은 읽기 전용 렌더러 · 스크롤 0)
마왕 줄 462     받은 카드 → 상위 5장 · 잔재 · 각인 · 뜯어낸 · 회수 · RELOAD 창 · 잠식
트로피 줄 484   **획득 트로피 전체 이름 + 누적 효과 + 성장 천장 전환 횟수**   ← V8 신설
버튼 540 / 안내 606
```

**v2 기한 지표 0개**(완료 기준)는 `--boss-test`의 `result` 묶음이 기계적으로 지킨다 —
패널의 모든 Label·Button 텍스트를 모아 금지 어휘 8종(`기한` `잔여 일수` `남은 일수`
`일차 이정표` `각성` `계보` `월식` `시련 구슬`)이 0건인지 본다. 동시에 v3 신규 어휘
7종이 실재하는지도 본다.

### 5.1 시너지 발동 횟수는 어디서 세나 (combat_resolver 무수정)

`combat_resolver.gd`가 game.gd로 나오는 관문은 `spawn_synergy_effect()` 하나다
(`_announce_reactions` + `_run_status_chain`). 그 함수 **첫 줄**에서 센다 —
이펙트 예산이 꽉 차 노드를 못 만드는 순간에도 카운트는 올라간다(지표는 연출이 아니라 사건).

| 지표 | 출처 | 뜻 |
|---|---|---|
| 시너지 발동 | `run_synergy_triggers` (game.gd) | **이름 붙은** 반응(대폭 연소·전도·쇄빙·역병 발화·정신 붕괴 …) |
| 상태 반응 | `combat.status_reactions_fired` | 매트릭스 전체 반응 수(부여·갱신 포함) |
| 도트 틱 | `combat.status_dot_ticks` | `enemy.gd:548`이 올리는 도트 적용 횟수 |

뒤 둘은 **읽기만** 한다. `combat_resolver.reset()`이 런 경계에서 비워 주므로 런 스코프다.

---

## 6. 저장 (V9에게)

가산한 3키(전부 `_save_run_snapshot` / `_restore_run_snapshot` 짝 완비):

| 키 | 내용 |
|---|---|
| `trophy_stages` | `Array[int]` 1~5. **트로피 효과의 유일한 진실 원천** — 스탯이 아니라 스테이지 번호만 저장하고 `TrophyLibrary.merge_effects()`로 다시 세운다(설계 §9) |
| `growth_cap_conversions` | 성장 천장 자동 전환 횟수(결과 화면 지표) |
| `run_synergy_triggers` | 시너지 발동 횟수(결과 화면 지표) |

복원 순서: `player.restore_trophies(...)` **먼저** → 두 구 필드를 그것이 다시 세운다.
`trophy_stages`가 비어 있을 때만 구 키(`player_advancement_branch` / `_tier`)로 채운다
(테스트가 두 필드만 직접 세우는 경로 보호).

**V9가 지울 수 있는 것**: `player_advancement_branch` · `player_advancement_tier` ·
(§9의 계획대로) `boss_advancement` → `trophy_effects` 개명. 단 **`advancement_branch_id`
필드 자체는 `combat_resolver.gd`가 읽으므로 남겨야 한다** — 저장 키만 지울 수 있다.

`--save-test`는 지문에 `trophies` / `trophy_health` / `growth_cap` / `synergy` 4축을
추가했고 required_keys에 위 3키를 넣었다(지문 축 45 → **49**, 필수 키 37 → **40**).
저장 흔들기 구간의 `advancement_branch_id = "paladin"` 직접 대입은
`player.restore_trophies([1, 3])`로 교체했다 — 실제 트로피가 왕복하는지를 본다.

---

## 7. 테스트

### 7.1 `--castle-test` — 각성 2묶음 → 트로피 3묶음 + 경제 1묶음

```
CASTLE_TEST_COMPLETE castle_npcs=true shop=true refresh=true shop_equip=true fusion=true
  rune_shop=true mage=true mage_gate=true upgrade_refund=true npc_remove=true npc_swap=true
  pact_sell_day=true pact_buy_day=true pact_limit=true spy_remove=true price_scale=true
  trophy_flow=true trophy_stack=true trophy_reserve=true trophy=trophy_frost_eye stage5_price=240
```

| 묶음 | 무엇을 단언하나 |
|---|---|
| `pact_buy_day` | **가산**: 각인을 전부 떼면 탐욕이 닫힌다(대가 없는 압박 판매 금지) |
| `price_scale` | 1스테이지 = v2 동가 · 5스테이지 > 1스테이지 · 스테이지 단조 증가 · **계약은 스케일 밖** |
| `trophy_flow` | 고정 스탯 즉시 적용(체력·수호막 정확히 일치) → 2택1 자동 확정 → 버린 장이 `rejected_skills`+`boss_advancement_skills`로 → 5칸 배치 → 훅 소멸. **같은 트로피 2번 줘도 효과가 겹치지 않는다** |
| `trophy_stack` | 5회 누적 == `merge_effects` · 실제 스탯 반영 · 배분표 12종 중복 0 · **모든 쌍이 서로 다른 원소** |
| `trophy_reserve` | 이미 가진 카드가 뜨면 예비로 치환 · 안 가진 스테이지는 배분표 원본 그대로 |

삭제된 것: `awakening_day3` / `awakening_day6` / `lineage` / `tags`.

### 7.2 `--draft-test` — `growth_cap` 신설

빈 칸 하나만 있어도 전환 금지 → 5칸 R3 포화면 전환 → **보관함에 R1이 한 장이라도
있으면 다시 금지** → 보관함도 R3면 전환 → `_show_skill_choice("level")` E2E(드래프트 진입 ·
레벨 정산 · 카드 2장 마왕행 · 조각 2 지급) → `chest`는 전환하지 않는다.
`GROWTH_CAP_AUTO_RUNE_DRAFT`가 false로 뒤집히면 E2E 부분은 자동으로 건너뛴다.

### 7.3 `--boss-test` — 격파 4곳이 트로피를 지나가고 `result` 묶음 신설

`_consume_stage_trophy(slot)` 헬퍼를 새로 뒀다(2택1 → 배치까지 소화). 격파 4곳
(`defeat` · `enhanced` · `demon_direct` · `valve`)이 전부 이 헬퍼를 지난다.

```
BOSS_TEST_COMPLETE rotation=true battle_e2e=true enhanced=true defeat=true demon_direct=true
  valve=true demon_king=true telegraph=true phase=true blight=true result=true
  … timeline=5
```

| 묶음 | V8 가산분 |
|---|---|
| `defeat` | 격파 직후 상태가 `factory_place`다 · 트로피 1개 획득 · 마왕 카드 +1 · 배치 후 슬롯 4에 선택 카드 |
| `enhanced` | 4스테이지 트로피가 **전설 등급**이다(강화 보스가 전설을 떨군다) |
| `demon_direct` | **트로피가 마왕전보다 먼저** — `followup == "demon"` 상태에서 배치 후에야 프리뷰가 열린다 · `world.get_stage()` 불변 |
| `valve` | 강림 격파도 정규 보상 경로다(트로피 지급 · `descended` 플래그가 훅에 실린다) |
| `result` **신설** | 등급 5경계 · 타임라인 5칸 · 금지 어휘 8종 0건 · 필수 어휘 7종 실재 · 트로피 이름 나열 · 트로피 흐름 정리 |

### 7.4 캡처 (비headless 육안 확인 완료)

| 파일 | 확인한 것 |
|---|---|
| `castle-minimal-v2-trophy.png` **신설** | "3관문 격파 · 상급 트로피 · 홍염 천구의 깃" / "획득 확정 · 전체 피해 ×1.12 · 사거리 +34" / 서로 다른 원소 2장(타 관통 · 초 수호) / 광선 배경 |
| `castle-minimal-v2-pact.png` | dwell 3에서 **세 거래가 전부 열린다**. 머리줄에 현재 체류가 뜬다 |
| `result-minimal-v2.png` | 등급 A · 16일 · 다섯 관문 4✓ + 5▶ · 트로피 4/5 전설 · 시너지 137회 · 상태 반응 412·1893 · 트로피 줄에 4종 이름 + 누적 효과 + 천장 전환 2회 |
| `result-minimal-v2-lost.png` | 같은 지표 · 등급 "—" · 패배 문구 |
| `boss-minimal-v2-demon.png` | 5스테이지 트로피 배치 후 마왕 프리뷰. 슬롯 05에 방금 받은 `천상문 개방`이 꽂혀 있다 |

삭제: `castle-minimal-v2-lineage.png`(+ `.import` + `.godot/imported` 캐시).

---

## 8. 설계와 다르게 구현한 것

**1건.** 설계 §2.1의 흐름 표기는 "격파 → 트로피 → 완전 회복 → 스테이지 N+1 개시"인데
구현은 **격파 → 완전 회복 → 스테이지 N+1 개시 → 트로피**다(§1.2의 세 번째 대안 참조).
플레이어가 보는 순서는 같다 — 전환은 모달 뒤에서 일어나고 화면에 나타나지 않는다.

설계에 수치가 없어 V8이 정한 것 3건:
1. `STAGE_PRICE_STEP = 0.35` (§4.1) — V10 확정 대상
2. `_growth_cap_reached()`의 3조건 (§3.1) — 설계는 "배치할 곳이 없는"이라고만 적었다
3. 예비 카드 치환 규칙 (§1.3) — `trophy_library.gd`가 V8에 위임한 항목

---

## 9. V9 · V10이 바로 알아야 할 것

### V9 (저장 schema 3)

1. §6의 신규 3키 · 삭제 가능 키 · **필드는 남기고 저장 키만 지울 수 있다**는 제약.
2. **전투 중·모달 중 저장은 여전히 고려하지 않았다.** `pending_stage_trophy` /
   `pending_trophy` / `pending_trophy_followup` / `trophy_place_pending`은 저장하지 않는다.
   트로피 모달 도중에 이어하기가 필요하면 "보스방 앞 필드로 되돌린다"가 가장 싸다
   (`stage_boss_cleared = false`로 두면 문이 다시 열리고 트로피를 다시 받는다).
3. `--save-test`의 지문 4축과 required_keys 3키가 이미 들어가 있다. 재작성 시 유지할 것.

### V10 (통합 · 밸런스 · 문서)

4. **`class_library.gd`를 삭제하라** — §2.2의 두 줄만 고치면 된다.
5. **`STAGE_PRICE_STEP`을 `tuning.gd`로 옮기고 실측으로 확정하라**(§4.1).
   V7이 남긴 `STAGE_BOSS_*` 상수 6개와 같은 성격의 손잡이다.
6. **트로피 5종의 누적 스탯이 검증되지 않았다.** 5회 전부 받으면
   체력 +58 · 피해 +18 · 전체 피해 ×1.29 · 치명타 +8% · 관통 +1 · 투사체 +1 · 수호막 +2 ·
   사거리 +34 · 처치 회복 +1.5가 붙는다. V2가 "5개가 전부 누적된다는 전제로 크기를 잡았다"고
   했지만 **마왕전 60~120초 창과 함께 검증된 적은 없다**.
7. `boss_advancement_skills`의 의미가 바뀌었다(계보 카드 → 트로피 미선택 카드).
   설계 §9는 이 키를 `trophy_effects`로 개명하라고 했는데, **`demon_lord.gd`가
   `game.boss_advancement_skills`를 직접 읽으므로**(`:84` `:349-351`) 개명하려면
   그 파일도 함께 열어야 한다.
8. `--capture-castle`이 `automated_test = false`로 도는 유일한 캡처다.
   트로피 모달이 자동 확정되면 안 되기 때문이다(구 계보 화면과 같은 이유).
9. 결과 화면 금지 어휘 목록(`--boss-test` `result` 묶음)에 새 어휘를 넣고 싶으면
   **짧은 토큰을 피하라** — 처음에 `"7일"`을 넣었다가 "총 17일차"에 걸렸다.

---

## 10. 남은 위험 / 미결

| # | 내용 | 크기 | 누가 |
|---|---|---|---|
| 1 | 트로피 5종 누적 스탯이 마왕전 밸런스와 함께 검증되지 않았다(§9-6) | 중 | V10 |
| 2 | `STAGE_PRICE_STEP` 0.35는 착수 기본값이다. 실측 근거 없음 | 중 | V10 |
| 3 | 성장 천장 전환이 **실전에서 언제 처음 터지는지** 모른다. R3 5장을 모으는 데 필요한 카드 수(id당 4장 × 5 = 20장)를 5스테이지 안에 모을 수 있는지는 `balance_probe` 미측정 | 중 | V10 |
| 4 | `class_library.gd` stub이 남아 있다 — 참조 1건 때문(§2.2) | 소 | V10 |
| 5 | 트로피 모달 도중 저장/이어하기 미지원(§9-2) | 소 | V9 판정 |
| 6 | 예비 카드 2장까지 전부 겹치면 배분표 원본을 그대로 낸다 = 2택1이 1택이 될 수 있다. 실제로 도달하려면 특별 카드 12종 중 11종을 이미 쥐고 있어야 해서 사실상 불가능하지만 이론적 구멍이다 | 소 | — |
| 7 | `advancement_branch_id` / `advancement_tier`라는 이름이 의미와 어긋난 채 남아 있다(§2.3) | 소 | V10 |
| 8 | `--capture-boss`의 트로피 소화가 슬롯 4를 매번 덮어쓴다. 대표 컷 이후의 레일 구성이 "플레이어가 실제로 짤 법한" 것과 다를 수 있다(연출 검수용이라 무해) | 소 | — |
| 9 | `AGENTS.md` §1 체크포인트를 갱신하지 않았다(지시서가 수정 금지) | 소 | V10 |
