# handoff-y6 — 발견 · 이벤트 · 재미 아이템 (`game.gd` 직렬 체인 5/6)

**근거 문서**: `docs/FEEDBACK_Y.md` §6 전체 · §8 ⑯ · §9.3 Y6 · §9.4 · 리스크 5·6·8·12 ·
`docs/handoff-y1.md` §9-F · `handoff-y2.md` §8-C · `handoff-y3.md` §9-C ·
`handoff-y4.md` §5 · §9-C · §10-11 · `handoff-y5.md` §5 · §6 · `handoff-ya.md` §5

**소유 파일**: `scripts/game.gd` · `scripts/test/test_runner.gd` ·
`scripts/test/run_all.sh` · `docs/handoff-y6.md`(이 문서)

---

## 0. 한 문장

처음엔 **성과 캠프 화살표만** 켜져 있고, 걸어가 본 곳부터 화살표가 하나씩 늘어난다.
스테이지마다 **사건 두셋**(던전·보물섬·세미 엘리트·상인·사당·발자국·무리·별똥별)이 시드로 놓이고,
**`Q` 한 칸**에 든 재미 아이템 여덟이 지도를 펼치고 낮을 늘리고 인형을 세운다.

---

## 1. 검증 결과 (전부 이 웨이브가 직접 실행)

| 검사 | 결과 |
|---|---|
| `--editor --quit` | 종료코드 **0** |
| `run_all.sh` **17종** | **전부 PASS · 2회 연속 재현**(범위 밖 실패 0건) · `--event-test`는 단독 3회 연속 |
| `rune_test` · `data_test` | 둘 다 전 플래그 true(Y6 무영향 확인) |
| `rift_probe.gd` | `failures=0 verdict=PASS` (시드 100개) |
| `terrain_probe.gd` | `verdict=PASS block_invariant=true` |
| `--capture-hud` + `--capture-world` | **18컷 / 고유 지문 18개**(프레임 흘림 0) · 육안 검수 완료 |
| 음성 대조 | 신설 단언 **9건**을 되돌려 전부 빨개지는 것을 확인(§7) |

### 1.1 계측값

```
EVENT  discover=true schedule=true site=true library=true combat=true
       items=true chest=true negative=true quiet=true
       events=4 budget=2~3 run_cap=12 chest_sum=100 threat=18 mobs=2 waves=3
RIFT   event_budget=true rifts=2 events=1        ← 균열 예산은 한 칸도 안 줄었다
SAVE   schema=4 keys=53 axes=72 mismatch=0 missing=none
CYCLE  hud_nav=true hud_block_pct=3.19           ← X3 계약 3.35% 아래 유지
GUIDE  aim=true steps=7 order=move→dash→rail→gauge→ghost→nav→edit
```

---

## 2. Y6 정의 대비 항목별 처리

| §9.3 Y6 항목 | 처리 |
|---|---|
| 발견 상태 | `discovered_features`(스테이지 스코프). 거리 ≤ **520px** 또는 **NAV_RING 안**. 성·캠프는 개시부터 발견 |
| EdgeMarker 게이팅 | `_update_edge_nav()`가 대상마다 `is_discovered()`를 먼저 본다. 화살표 **5종**(사건 추가) |
| 길잡이 스텝 ⑥ 재작성 | 「가 본 곳만 화살표가 켜집니다」로 교체. `pass == "interact"` 계약은 유지 |
| 랜덤 이벤트 8종 | 전부 구현(§3 표). 균열과 같은 배치 규약 · **새 state 0개** |
| 소비 슬롯 + `Q` | 1칸 · 좌하단 HUD(판 없음) · 교체 확인은 Y4 컴포넌트 공유 |
| 재미 아이템 8종 | 전부 구현(§4 표). 「낡은 지도」가 유저가 말한 "맵 밝히기"다 |
| 상자 재배당 | §6.4 배당 + **체력 7 · 재미 6** 신설, 위협 21% → **18%**(§5 산수 정정 주의) |
| **schema 4** | 3 → 4. 신설 5키. 버려진 런은 로비가 **한 번** 알린다(리스크 5) |

### 넘겨받아 처리한 것
- **`ui-coin-spin.png` 배선**(handoff-y4 §9-C) — 상자 골드 칸에서 4프레임 1회 재생 후
  스스로 사라지는 `CoinSpinEffect`. 트윈 없음(`chest_open_effect`와 같은 규약).
- **소비 아이템 교체 확인**(handoff-y4 §10-11의 예고) — `_show_equip_swap_confirm()`의
  껍데기·머리말·화살표·두 버튼·꼬리말을 `_build_swap_confirm_shell()`로 승격해 **두 화면이
  같은 컴포넌트를 쓴다.** 노드 이름(`EquipSwapPanel`/`Accept`/`Cancel`)은 그대로다 —
  `--v4-test`가 이름으로 물기 때문이다.

### 소속을 확인하고 **넘긴** 것
- 공유 렌더러 글자 겹침 2건(handoff-y5 §2) — YZ 몫 그대로.
- 「밤눈 부적」의 **감지 반경**을 `enemy.gd` 상수로 내리는 일 — 그 파일은 Y5·Y7 소유다.
  Y6은 `game.gd` 쪽 스윕으로 같은 결과를 만들었다(§4 표 주석).

---

## 3. 사건 8종 — 무엇이 어떻게 구현됐나

배치는 **균열과 같은 규약**이다. 스테이지 시드로 결정적, `dwell 0 / 2 / 4`에 하나씩,
스테이지 정원 2~3(시드가 정한다), 런 상한 12. **새 `state`를 만들지 않았다** —
전부 `playing` 안의 필드 사건이고, 여는 화면은 전부 기존 모달이다.

| 사건 | 조건 | 구현 | 보상 |
|---|---|---|---|
| 작은 던전 | 1스테이지 | `3 + stage`기를 **3파도**로 | 골드 `60×1.6×물가` + 각인 3택1 |
| 보물섬 | 2스테이지 · 물가 | 함정 없는 상자 **3개**(§5-2 주의) | 골드/경험/재미 아이템/장비/각인 |
| 세미 엘리트 | 2스테이지 | 이름 있는 1기 · HP ×4 · 모듈 2종 | 골드 `70×물가` + 장비 2택1 |
| 유랑 상인 | 1스테이지 | 필드 카드상 **1회** · 카드 1 + 장비 1 · **+20%** | (상점) |
| 무너진 사당 | 3스테이지 | 지금 체력의 절반을 바친다 | 각인 3택1 |
| 마왕의 발자국 | **잠식 중** | 전조격 2기 동시(`overclock`) | 마왕 각인 **2개 뜯기** |
| 굶주린 무리 | 1스테이지 · **밤** | **같은 종 8기**(첫 마리의 종을 나머지가 따른다) | 경험 `14×2.2×물가` |
| 별똥별 | 1스테이지 · **밤** | 낙하 지점 | 상자 1 + 재미 아이템 1 |

- **밤·잠식 조건은 배치가 아니라 표식의 조건이다.** 조건이 안 맞으면 표식이 아예 안 뜨고
  상호작용도 안 잡힌다 → "밤에만 나오는 사건"으로 읽힌다. 조건이 돌아오면 다시 뜬다.
- 전투형 넷(`dungeon` `semi_elite` `footprint` `pack`)은 적의 `camp_id`가 **`evt_`**로
  시작한다. `_trial_enemy_defeated()`가 `omen_` · `rift_` 옆에 한 갈래를 더 받는다.
- 난이도 스케일은 **스폰 경로가 이미 갖고 있다**(`combat.apply_stage_scaling()`).
  Y6은 마릿수(`3 + stage`)와 보상 물가(`stage_price_scale()`)만 얹었다. 밸런스 숫자 0개.

---

## 4. 재미 아이템 8종 — `Q` 한 칸

| 아이템 | 구현 한 줄 |
|---|---|
| 낡은 지도 | `_discover_all_stage_features()` — 이 스테이지 대상 전부를 발견 처리 |
| 해시계 | `clock.phase_elapsed -= 40`. **밤에는 거절**한다(낮을 늘리는 물건이다) |
| 밤눈 부적 | 다음 밤 1회. 0.25초 스윕이 **420px 밖 개체의 `set_night_raid(false)`**를 건다(§5-4) |
| 소환 뿔피리 | 640px 안 몹을 앞쪽 한 점으로 **한 번에** 옮긴다(트윈 없음) |
| 회복의 빵 | 최대 체력 **40%** 회복. 상자의 「체력 회복」 칸과 **같은 상수**를 쓴다 |
| 되돌이 종 | 성 앞으로 순간이동 + 진입 무적 + 카메라 스무딩 리셋 |
| 각인 지우개 | 각인이 가장 많은 칸을 통째로 떼고 `개수 × 22 G ×물가`를 되받는다 |
| 미끼 인형 | 8초 동안 `enemy.player`를 **인형 노드**로 갈아 끼운다(§5-3) |

- 획득처: 상자(재미 칸 6%) · 보물섬/별똥별 · 「각인 지우개」만 세공사 계열로 남겨 풀에서 뺐다.
- 이미 들고 있는데 새로 주우면 **바꿀지 묻는다.** 그 화면이 Y4의 장비 교체 확인과
  같은 컴포넌트다(껍데기·버튼·꼬리말 공유 · 카드 렌더러만 다르다).
- HUD는 좌하단 `Rect2(16, 646, 210, 46)` — **`Panel`을 깔지 않는다.** 킷 키캡(72×40의
  정확히 절반인 36×20) + 글리프 28px + 이름 한 낱말뿐이라 `hud_block_pct`가 **3.19로 무변**이다.
  효과 한 줄과 획득처는 전부 `consumable` 툴팁으로 내렸다(정보 손실 0).

---

## 5. 밟은 함정 · 다음 웨이브가 알아야 할 것

1. **⚠️ `docs/FEEDBACK_Y.md` §6.4의 새 배당 열은 합이 100이 아니라 106이다.**
   (14+13+16+15+14+7+6+6+7+5+3). 구 열은 정확히 100이므로 신설 두 칸을 더하면서
   다른 칸을 그만큼 못 뺀 산수 착오다. **문서가 명시적으로 주장한 것은 전부 지켰다** —
   위협 총량 18% · 체력 7 · 재미 6 · 각인 14(X1이 정한 값). 남은 6%p는 보상 네 칸에서
   고르게 뺐다: **골드 14→13 · 경험 13→12 · 스킬 16→14 · 아이템 15→13 = 합 100.**
   배당표는 이제 `game.gd`의 `CHEST_TABLE` **한 곳**이 정본이고, `_open_chest()`는
   임계값을 손으로 안 적는다(`chest_slice_for()`). `--event-test`가 합 100을 문다.
   문서를 고칠 권한이 없어 여기 적어 둔다.
2. **⚠️ 「보물섬」의 지형은 깎지 않았다.** §6.2는 "호수 가운데 섬 · 다리 1개"라고 적었지만
   섬과 다리는 **`world_grid.gd`·`wfc_chunk_generator.gd`**의 일이고 그 둘은 Y5 소유다.
   Y6은 **호수에 붙은 마른 자리**를 골라(`_near_water()` 8방향 프로브) 표식을 세우고
   함정 없는 상자 셋을 준다. 보상과 "함정 없음"은 스펙 그대로이고, 빠진 것은 지형 연출뿐이다.
   지형을 원하면 `world_grid`를 여는 웨이브가 `_find_event_site()`에 좌표를 넘겨받으면 된다.
3. **⚠️ 「미끼 인형」은 `enemy.gd`를 한 줄도 안 고치고 성립한다.** `DebtEnemy`가
   `player`에게 쓰는 것은 `global_position`과 `take_damage()` **둘뿐**이라(전수 확인),
   그 둘만 갖춘 `DecoyDoll` 노드로 갈아 끼우면 추적·접촉·조준이 통째로 인형을 향한다.
   되돌릴 때는 `is_instance_valid()`로 거른 뒤 `enemy.player = player`다.
   **8초가 끝나거나 인형이 사라지면 반드시 되돌려야 한다** — 안 되돌리면 그 몹은
   영원히 허공을 때린다.
4. **⚠️ 「밤눈 부적」의 −40%는 `raid_mode` 토글로 만들었다.** 밤의 습격 모드는 거리를
   안 보고 전원 추적이라(`enemy.set_night_raid(true)`) 감지 반경이라는 손잡이가 없다.
   그래서 0.25초 스윕이 **420px(기준 700 × 0.6) 밖 개체만 습격 모드에서 빼는** 방식으로
   같은 결과를 만든다. 부작용은 밤 형태(`night_form`)가 그 개체에서 풀리는 것이고,
   그것이 오히려 "나를 못 봤다"의 육안 신호가 된다. **Y7이 `enemy.gd`를 열 때
   감지 반경 배율을 진짜 필드로 만들면 이 스윕은 지워도 된다.**
5. **⚠️ 사전 안에 `Node`를 넣지 말 것.** 사건 표식을 `stage_events[i]["mark"]`에 넣었더니
   `gameplay_root.free()` 뒤 `var mark: Node2D = event_value.get("mark")`가
   **"Trying to assign invalid previously freed instance"**로 죽었다 —
   `--save-test`·`--boss-test`가 그것으로 빨개졌다(실측). 표식은 `event_marks`
   **별도 사전**(id → Node)이 들고, 사건 사전은 순수 데이터로 남겼다. 직렬화도 같이 단순해졌다.
6. **⚠️ 이어하기 뒤의 사건 따라잡기는 정상 동작이지 회귀가 아니다.** 저장 시점보다 dwell이
   앞서 있으면 복원 직후 `_maintain_event_schedule()`이 사건을 더 연다. `--save-test`가
   그것을 지문 불일치로 잡았는데, 옳은 처방은 코드가 아니라 **검사가 저장 전에 따라잡아
   두는 것**이었다(그래야 "복원 뒤에 더 안 늘어난다"를 지문이 문다).
7. **⚠️ 발견 게이팅은 "꺼져 있어도 초록"이 되기 가장 쉬운 종류의 기능이다.**
   화살표가 늘 보이면 기존 양성 단언이 전부 통과한다. 그래서 `--cycle-test`·`--event-test`
   양쪽에 **발견 전에는 없다**를 먼저 재는 줄을 넣었다. 그리고 「성은 처음부터 발견 상태」는
   **`_seed_stage_discovery()`를 직접 불러** 재야 한다 — 스폰이 성에서 400px 남짓이라
   (`--world-test castle_d`) 프레임이 한 번만 돌면 성은 어차피 근접으로 발견된다.
   시드를 지운 채로도 검사가 초록이었다(음성 대조 1차에서 실제로 그랬다).
8. **⚠️ 자리 이격 규칙은 순회만으로는 못 잰다.** "배치된 사건이 랜드마크와 떨어져 있다"는
   나쁜 자리가 **제안됐을 때만** 빨개진다 — 규칙을 통째로 꺼도 시드에 따라 초록으로
   통과했다(음성 대조 1차). `_event_site_clear()`를 **함수 단위로** 되돌려 재는 줄
   (랜드마크 한복판 · 기존 사건 옆)을 넣고서야 판별력이 생겼다.
9. **캡처는 `state == "preview"`에서 찍는다.** HUD 조각의 `visible`을
   `state == "playing"`으로 묶으면 그 조각만 QA 컷에서 사라진다(소비 칸이 첫 컷에서
   실제로 그랬다). 신상·스테이지 줄과 같이 **`inside_castle`만** 보게 고쳤다.
   화살표는 `_capture_paint_edge_nav()`가 이미 같은 함정을 우회하고 있었다.
10. **⚠️ 「밤」·「잠식」 사건은 조건이 안 맞으면 `_activate_field_event()`가 조용히 거절한다.**
    검사가 낮에 별똥별을 열려다 `state`가 `ready`에 머물러 처음에 빨개졌다 — 버그가 아니라
    설계다(§3). 그 거절 자체를 **음성 축**으로 승격했다(낮 = 표식 없음 + 발동 거절 /
    밤 = 표식 있음 + 발동). 사건을 손으로 심는 검사는 조건도 같이 맞춰야 한다.
11. **사건 좌표는 "스테이지 시드 + 플레이어 자리"로 결정적이다** — 균열
    (`spawn_rift_near(player_position)`)과 **정확히 같은 규약**이다. 같은 자리에서 다시
    깔면 같은 좌표가 나오고(`--event-test schedule`이 확인), 다른 자리에서 열리면
    다른 좌표가 나온다. 순수 시드 결정성을 원하면 균열까지 같이 바꿔야 한다.
    ⚠️ 그래서 결정성 검사는 **같은 자리에서 두 번 깔아** 비교해야 한다. 런 개시에 깔린
    사건과 직접 대조하면 스폰 구제(`_walkable_spawn_point`)가 원점을 흔든 시드에서만
    빨개져 "가끔 실패하는 검사"가 된다(실측으로 잡았다).

---

## 6. 신설 API · 신설 검사

**`game.gd` 발견**: `is_discovered()` · `mark_discovered()` · `_seed_stage_discovery()` ·
`_update_discovery()` · `_discovery_candidates()` · `_discover_all_stage_features()` ·
`_discovered_rift_compass()` · `_event_compass()` · `DISCOVER_RADIUS`
**`game.gd` 사건**: `EVENT_LIBRARY`(8종) · `stage_events` · `event_marks` ·
`events_due()` · `stage_event_budget()` · `_maintain_event_schedule()` ·
`_find_event_site()` · `_event_site_clear()` · `_nearest_field_event()` ·
`field_event_prompt()` · `_activate_field_event()` · `_event_enemy_defeated()` ·
`_finish_event()` · `_grant_safe_chests()` · `_strip_demon_runes()` ·
`_close_field_merchant()` · `field_merchant_open()` · `FieldEventMark`
**`game.gd` 소비**: `CONSUMABLES`(8종) · `consumable_item` · `_grant_consumable()` ·
`_use_consumable()` · `_horn_gather()` · `_erase_slot_runes()` · `_spawn_decoy()` ·
`_tick_night_eye()` · `_night_eye_phase()` · `_tick_y6()` · `DecoyDoll` ·
`_build_swap_confirm_shell()`(Y4와 공유) · `_show_consumable_swap_confirm()`
**`game.gd` 상자**: `CHEST_TABLE` · `chest_table_total()` · `chest_slice_weight()` ·
`chest_slice_for()` · `CoinSpinEffect` · `_spawn_coin_spin()`
**`game.gd` 저장**: `RUN_SCHEMA_VERSION = 4` · `saved_run_dropped` ·
`_serialize_stage_events()` · `_restore_stage_events()` · `_restore_discovered_features()` ·
`_lobby_run_chip_text()`

| 검사 | 무엇을 새로 무는가 |
|---|---|
| **`--event-test`** 신설 | `discover` · `schedule` · `site` · `library` · `combat`(전투형) · **`quiet`**(전투 아닌 넷) · `items` · `chest` · `negative` |
| `--cycle-test` +2 | `hud_nav`에 「발견 전에는 화살표가 없다」와 「성·캠프는 시드부터」가 붙었다 |
| `--rift-test` +1 | `event_budget` — 사건이 서도 균열 예산이 안 줄고, 두 좌표가 안 겹친다 |
| `--save-test` +5키 +4축 | `discovered_features` · `stage_events` · `run_event_count` · `consumable_item` · `night_eye_nights` / 지문 `discovered` · `events` · `event_budget` · `consumable` |
| `--guide-test` +1 | `aim`에 「성이 발견 상태라 화살표가 반드시 하나는 있다」와 그 음성 축 |
| `--capture-hud` **+1컷** | `hud-y6-discovery.png` — 발견 화살표 · 사건 표식 · 소비 칸 |

> **`run_all.sh`가 16종 → 17종이 됐다.** `--event-test`가 `--guide-test` 뒤에 들어간다.
> AGENTS.md 등 "15종"·"16종"이라 적은 문서는 오케스트레이터/YZ가 갱신해야 한다.

---

## 7. 음성 대조

신설 단언 **9건**을 되돌려 재고 전부 빨개지는 것을 확인했다.

| 되돌린 것 | 빨개진 플래그 | 진단 |
|---|---|---|
| `is_discovered()`가 항상 true | `--cycle-test hud_nav` · `--event-test discover`·`negative` | 미발견 대상의 화살표가 그대로 떴다 |
| `events_due()`가 항상 0 | `--event-test schedule`·`site` · `--rift-test event_budget` | `events=0` |
| 배당표 `heal` 7 → 9 | `--event-test chest` | `chest_sum 100 → 102` |
| 저장에서 `discovered_features` 삭제 | `--save-test snapshot`·`fields` | `missing=discovered_features` · `mismatch=1` |
| `_use_consumable()` 무력화 | `--event-test items` | 빵을 써도 체력이 안 오른다 |
| `_event_site_clear()`가 항상 true | `--event-test site` | 랜드마크 한복판이 통과했다 |
| `_seed_stage_discovery()`에서 성 삭제 | `--event-test discover` | 시드가 2개가 아니다 |
| 상인 웃돈 1.20 → 1.00 | `--event-test quiet` | 진열가가 성과 같아졌다 |
| 사건의 `night` 조건 무력화 | `--event-test negative`·`quiet` | 낮에 별똥별이 열렸다 |

> ⚠️ **위 두 줄(자리 이격 · 성 시드)은 1차 음성 대조에서 안 빨개졌다.** 순회 기반 단언과
> 프레임이 도는 상태의 근접 발견 때문이었다(§5-7 · §5-8). 함수 단위로 되돌려 재는 줄을
> 각각 추가하고서야 판별력이 생겼다 — **음성 대조를 안 돌렸으면 두 계약 모두 공허했다.**

---

## 8. 캡처 검수

`--capture-hud` **8컷** + `--capture-world` **10컷** = **18컷 / 고유 지문 18개**.
잔여 godot 인스턴스 0 확인 후 촬영(리스크 8).

| 컷 | 확인한 것 |
|---|---|
| `hud-y6-discovery.png`(신설) | ① **보스문(붉은 해골) 화살표가 없다** — 아직 안 가 본 곳이다 ② 캠프 화살표(44m)와 먼 사건 화살표(319m)는 켜져 있다 ③ 필드에 **사건 표식**(고리 + 문 실루엣)이 서 있다 ④ 좌하단 **`Q` 키캡 + 두루마리 글리프 + 「낡은 지도」**, 판 없음 |
| `hud-x3-day/-night/-reload/-tip/-blight/-stage5-night` | 회귀 없음. `hud_block_pct` 3.19 유지 |
| `world-*` 10컷 | 회귀 없음(Y6은 월드 렌더러를 안 건드린다) |

> **관찰 1건(회귀 아님)**: 소비 칸이 물가에 걸리면 청록 배경 위 청록 글자가 되어 대비가
> 얕다. 글자에 `_label()` 외곽선이 있어 읽히기는 하지만, 더 확실히 하려면 X3가 EdgeMarker에
> 쓴 **로컬 스크림**(알파 0.45 미만이면 `hud_block_pct`에 안 잡힌다)을 키캡·글리프 뒤에만
> 까는 것이 다음 수다.

---

## 9. 이 웨이브가 하지 않은 것

- `game.gd` Y7 구역(타격감 — 몹별 반응 · impact 8종 · 카메라 `cam_peak`)
- **밸런스 숫자 0개.** `core/tuning.gd` 무접촉. 사건 보상 계수(60·70·14·1.6·2.2)는
  §6.2가 적은 값을 그대로 옮긴 **착수값**이고 실측은 Y8이다. 사건이 스테이지당 2~3개
  늘어난 만큼 **런 전체 골드·XP 유입이 커졌다** — `balance_probe` ⑧⑩⑪에 반드시 반영할 것.
- 「보물섬」의 섬·다리 지형(§5-2 · `world_grid.gd` 소유 웨이브)
- 「밤눈 부적」의 감지 반경을 `enemy.gd` 필드로 승격(§5-4 · Y7)
- `vfx-burst` · `vfx-timeflow` 배선(Y7) · `ui-kit-skill-shape`(YA 미납)
- 공유 렌더러 두 곳의 글자 겹침(handoff-y5 §2 · YZ)
- 한글 스윕 — 이번에 새로 쓴 문자열(사건 8종 안내 · 아이템 8종 이름/효과 · 배너)은
  금지 어휘를 피했지만 **YZ의 전수 스윕 대상**이다
- `docs/FEEDBACK_Y.md` 자체 수정 — **§6.4 배당표의 합이 틀렸다**(§5-1). 권한이 없어 여기 적는다
- **`AGENTS.md` §1 체크포인트 갱신** — 이번 웨이브도 `AGENTS.md` 수정이 금지됐다.
  §9.1의 "매 웨이브 끝에 체크포인트 갱신" 규약과 어긋나므로 **오케스트레이터가 반영해야 한다.**
  반영할 내용은 이 문서 §0 · §1 · §6의 "**17종**" 사실과 "schema 4" 사실이다.
