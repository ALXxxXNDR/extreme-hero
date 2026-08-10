# W11 인수인계 — 시각 테마 전면 교체 (Ninja Adventure)

> 작성: W11 구현 웨이브 / 2026-08-07
> 한 줄 요약: **도형(draw_rect/draw_polygon) 렌더를 전부 스프라이트로 갈아끼웠다. 게임 규칙은 한 줄도 안 바뀌었고 테스트 12종은 단언 수정 0건으로 전부 PASS다.**

---

## 0. 결과 요약

| 항목 | 결과 |
|---|---|
| `--editor --quit` | 오류 0 |
| `run_all.sh` 12종 | **전부 PASS · 테스트 단언 수정 0건** |
| `--stress-test` fps | **145** (교체 전 145 / 첫 검증 144). 마물 104기·회귀 없음 |
| 캡처 12종 비headless 육안 검수 | 전부 통과(§5) |
| 신규 런타임 에셋 | `godot-game/art/v2/` PNG **33장 · 합계 약 140 KB** |
| v1 에셋·원본 | **하나도 지우지 않았다.** 참조만 끊었다 |

수정한 게임 파일 7개 — `player.gd` · `enemy.gd` · `world_grid.gd` · `cycle_skill_effect.gd` ·
`castle_interior.gd` · `projectile.gd` · `enemy_bullet.gd`. 전부 `_draw()` 계열과 preload 상수만 손댔다.
`game.gd`는 **한 글자도 건드리지 않았다.**

재작성 전 원본은 `docs/v1-archive/`에 `player_v1.gd.txt` · `enemy_v1.gd.txt` ·
`world_grid_v1.gd.txt` · `cycle_skill_effect_v1.gd.txt`로 보존했다.

---

## 1. 에셋 파이프라인 — `art/v2/build_assets.gd`

원본 NA 시트에서 필요한 셀만 잘라 합성하고 nearest 정수배로 확대해 `art/v2/*.png`를 굽는다.

```bash
godot --headless --path godot-game --script res://art/v2/build_assets.gd   # 재생성
godot --headless --path godot-game --editor --quit                         # .import 갱신
```

매핑을 바꾸려면 이 파일 상단 상수표(`MOB_SHEETS` / `MOB_TINT` / `PLAYER_SHEETS` /
`CASTLE_NPCS` / `_build_terrain()`의 `match cell`)만 고치면 된다.
**전체 매핑 표·좌표·판단 근거는 `godot-game/art/v2/ASSET_MAP.md`에 있다.** 여기서는 결정만 요약한다.

### 1.1 파이프라인이 지키는 규칙 3가지

1. **확대는 nearest 정수배 ×2 한 종류.** (마왕만 ×3 — §3)
2. **합성은 16px 원본 좌표계에서 끝내고 마지막에 딱 한 번 확대한다.** 확대 후 합성하면 픽셀 격자가 반 칸 어긋난다.
3. **방향성 스프라이트는 빌드 단계에서 전부 +X로 돌려 굽는다.** (§4의 v1 교훈)

---

## 2. 몹 10종 + 마왕 최종 매핑

전부 `Actor/Monster/*` 규격(64×64 = 4방향 × 4프레임)으로 통일했다. 열 순서는 **0=아래 1=위 2=왼쪽 3=오른쪽**.

| id | 이름 | visual | 원본 | 색보정(빌드에 구움) | 판단 |
|---|---|---|---|---|---|
| `mossling` | 이끼콩 | `blob` | `Monster/Larva` | — | 이끼색 마디벌레 |
| `boar` | 들멧돼지 | `boar` | `Monster/Bear` | — | `Animal/WildBoar`가 생김새는 완벽하나 **측면 2프레임**뿐 → 4방향 일관성 우선 |
| `imp` | 뿔임프 | `imp` | `Monster/Beast` | — | 붉은 뿔 악마 |
| `wolf` | 붉은 늑대 | `wolf` | `Monster/Racoon` | ×(1.30, 0.70, 0.62) | 4방향 사족 포식자 중 늑대 실루엣에 가장 근접 |
| `skeleton` | 떠도는 해골 | `skeleton` | `Monster/Skull` | — | `Character/Skeleton`(전신)보다 **떠다니는 두개골**이 이름에 부합 |
| `shade` | 굶주린 그림자 | `shade` | `Monster/Spirit` | ×(0.66, 0.58, 0.86) | 흰 유령 → 창백한 보라 |
| `wisp` | 푸른 위습 | `wisp` | `Monster/Flam2` | — | 이름까지 일치하는 푸른 불꽃 |
| `ogre` | 황야 오우거 | `ogre` | `Monster/Cyclope2` | — | 녹색 외눈 거구 |
| `cultist` | 월식 주술사 | `cultist` | `Character/SorcererBlack/SeparateAnim/Walk` | ×(0.82, 0.78, 1.00) | `Monster/`에 후드 술사가 없다. **Character의 Walk.png가 몹 시트와 완전히 같은 64×64 4×4 규격**이라 규격 통일이 안 깨진다 |
| `hellhound` | 밤의 지옥견 | `hellhound` | `Monster/Grey Trex` | ×(0.92, 0.40, 0.44) | `Animal/DogBlack`은 측면 2프레임. 4방향 야수 중 `Racoon`(늑대)과 **실루엣이 겹치지 않는** 유일한 대형 포식자 |
| ★ | **마왕** | — | `Boss/GiantRedSamurai` | — | 초승달 투구 붉은 마검사. Idle 12 / Walk 12 / Hit 8 / AttackL·R 8프레임 |

v2에서 내려간 3종(`royal_ooze`·`cave_bat`·`iron_beetle`)의 variant 시트(`ooze`/`bat`/`beetle`)도
같이 구워 뒀다. `enemy.gd`의 variant 분기가 총망라를 유지해야 미등록 종이 스폰돼도 안 깨진다.

### 2.1 색 변조는 마스크 덧그리기로 한다 (셰이더 아님)

캐릭터·몹·마왕 시트는 **아래 절반에 흰 실루엣 마스크**가 한 벌 더 붙어 있다.
스프라이트를 한 번 그리고 그 위에 마스크를 원하는 색·알파로 덧그리면 색조 변조가 된다.

| 표현 | 마스크 색 |
|---|---|
| 피격 플래시 | `Color(1,1,1, 0.85)` |
| 밤 변이 | `Color(0.42, 0.10, 0.20, night_form_amount * 0.55)` (+ 기존 뿔·송곳니 폴리곤 유지) |
| 사이클 둔화 | `Color(CYAN, 0.22)` |
| 경직(hit stun) | `Color(0.78, 0.84, 1.0, 0.30)` |

**ShaderMaterial을 안 쓴 이유**: 머티리얼은 CanvasItem 단위라 같은 `_draw()` 안의 체력바·상태 핍·
왕관까지 전부 물든다. 노드를 쪼개면 되지만 그건 구조 변경이고, 마스크 방식은 텍스처 몇 KB로 끝난다.

---

## 3. 지형 아틀라스와 인셋

`terrain-atlas-na.png` **160×128 · 5열×4행 · 셀 32×32** — v1과 규격이 완전히 같아
`wfc_chunk_generator.TILE_RULES`의 셀 번호 계약은 무변경이다. 좌표표는 ASSET_MAP §1.

| 결정 | 값 | 근거 |
|---|---|---|
| `ATLAS_CELL_INSET` | 2 → **0** | v1 아틀라스는 셀마다 어두운 테두리가 구워져 있어 깎아야 했다. NA 타일은 원래 이어 붙이라고 만든 것이라 테두리가 없다. **1px만 깎아도 물가의 흰 포말 선이 잘려 호수 가장자리가 두 번 끊긴다.** 번짐은 없다 — 32px 소스를 40px로 늘릴 때 목적지 픽셀 중심은 `[L+0.4, L+31.6]` 안에만 떨어진다 |
| 잔디 바탕 | `TilesetField(16,64)` | 물 타일셋의 물가 잔디와 바탕색이 **#adbc3a로 완전히 동일**(픽셀 히스토그램 확인) → 호수 가장자리에서 색이 안 튄다. Field 쪽은 잔풀 얼룩 4px이 있어 평원이 단색 판때기로 안 보인다 |
| 데코 외곽선 | 밝기 0.20 미만 → #454f21 | WFC가 잔디 타일의 **19%를 데코로 채운다**(tuft 13 + flower 3.2 + forest 2.9 + rocks 1.6). NA 데코의 검은 외곽선을 그대로 두니 1차 캡처에서 들판이 검은 낙서처럼 보였다 |
| 마왕 배율 | ×2 → **×3** (유일한 예외) | 원본 프레임 48px인데 사무라이 몸통이 그 안에서 26px뿐이다. ×2면 화면상 52×60px로 반지름 58(지름 116px) 히트박스의 절반도 못 채운다. 1차 캡처에서 최종 보스가 플레이어의 1.7배로만 보였다 |

---

## 4. ⚠️ VFX 방향 축 — v1 교훈을 이렇게 봉인했다

v1은 생성 아틀라스의 참격이 `-X`를 향하는데 코드가 `+X`를 가정해 **이펙트가 180° 뒤집혔다.**
`cycle_skill_effect.gd`의 `VFX_SLASH_SOURCE_DIRECTION`가 그때 생긴 방어선이다.

W11에서 확인한 사실: **NA 시트는 자산마다 기준축이 다르다.**

| 시트 | 원본 축 |
|---|---|
| `FX/Attack/SlashCurved` · `CircularSlash` | +X |
| `FX/Projectile/Arrow` · `BigKunai` | +X |
| `FX/Projectile/Fireball` · `EnergyBall` | **-Y (위)** |

런타임에 시트별 축을 기억하는 건 딱 v1이 밟은 지뢰다. 그래서
**`build_assets.gd`의 `_rotate_square_frames_cw()`가 빌드 단계에서 전부 +X로 돌려 굽는다.**
코드가 지킬 규칙은 이제 한 문장뿐이다 — **"모든 방향성 VFX는 +X를 향한다."**
`VFX_SLASH_SOURCE_DIRECTION`는 `Vector2.RIGHT`가 되어 사실상 항등 회전이 됐지만,
계약을 눈에 보이게 남겨 두려고 상수는 지우지 않았다.

### 4.1 kind → 시트 배정

| kind | 시트 | 비고 |
|---|---|---|
| `melee` `dash` | `vfx-core` 행 0 (참격) | 방향 회전 有. `dash`는 `vfx-smoke`가 뒤에 깔린다 |
| `area` `orbit` | `vfx-core` 행 1 (원형 참격) | |
| `ground` · 카드 `flame_field` | `vfx-core` 행 2 (마법진) | |
| `chain` · 카드 `thunder` | `vfx-core` 행 3 (낙뢰) | |
| `projectile` | `vfx-projectile` | 궤적 위 3개, 방향 회전 有 |
| `shield` | `vfx-shield` | |
| `area`/`ground`/`orbit` · `heavy` 카드 | `vfx-explosion` 9프레임 | 착탄 중심에서 한 번 |

원소 20종 구분은 **스프라이트가 아니라 `effect_color` modulate**로 한다. NA 참격·마법진이 흰색
지배라 색이 잘 물든다. 단 **폭발만은 예외** — modulate가 곱연산이라 철·혈 같은 어두운 원소색을
그대로 곱하면 주황 불덩이가 진흙색으로 죽는다(1차 캡처에서 실제로 그랬다).
`_vfx_flame_tint()`가 `Color.WHITE.lerp(effect_color, 0.45)`로 밝기를 지키고 색조만 입힌다.

---

## 5. 캡처 육안 검수 결과 (비headless 12종)

| 캡처 | 확인한 것 | 결과 |
|---|---|---|
| `--capture-world` | 지형 이음새·물가·다리·상자·숲·랜드마크 | 40px 격자 그물 **없음**. 잔디↔물가 색 연속 |
| `--capture-hud` (낮/밤/RELOAD) | 밤 색조가 지형과 랜드마크에 **같이** 걸리는지, 밤 변이 | 통과. 성이 밤에 떠 보이지 않는다 |
| `--capture-effects` | 참격·장판·폭발·보호막·투사체 방향 정합 | 방향 어긋남 0. 1차에서 폭발이 진흙색 → `_vfx_flame_tint` 도입 후 재캡처 통과 |
| `--capture-boss` | 마왕 스프라이트·공격 모션·피격 | 1차에서 히트박스 대비 과소 → ×3으로 재빌드 후 통과 |
| `--capture-castle` | 성 내부 바닥·NPC 4종 | NPC가 서비스별로 구분된다 |
| `--capture-rail` `--capture-draft` `--capture-result` `--capture-onboarding` | HUD 회귀 | 회귀 0 (아이콘 아틀라스 유지 판단 §6) |
| `--capture-lobby` `--capture-character` | 로비·캐릭터 선택 | 회귀 0 (v1 유지 판단 §6) |

1차 캡처에서 잡아 고친 3건:
1. 들판 데코의 검은 외곽선 → 진한 올리브로 치환
2. 마왕이 히트박스의 절반 → 마왕 시트만 ×3
3. 폭발 이펙트가 진흙색 → 전용 물감 `_vfx_flame_tint`

---

## 6. 교체하지 **않은** 것 — 판단과 근거

| 대상 | 결정 | 근거 |
|---|---|---|
| 스킬 아이콘 아틀라스 | **v1 유지** | NA `Ui/Skill Icon/Spell/` 32종에 딜싸이클의 핵심 개념(회귀·도약·재실행·과열·빚)에 대응하는 그림이 **하나도 없다.** 20종 카드에 임의 배정하면 아이콘이 정보를 잃는다. v1 아이콘은 카드 의미에 맞춰 그려졌고 40px·24px 양쪽에서 판독된다 |
| 아이템 아이콘 아틀라스 | **v1 유지** | NA `Items & Weapon` 아이콘은 12종뿐이라 장비 풀을 못 덮는다 |
| HUD 아틀라스 | **v1 유지** | NA 나무 테마 9-patch로 갈면 HUD 레이아웃을 다시 짜야 하고 W5가 세운 좌표 계약이 흔들린다 |
| 로비 배경 | **v1 유지** | 이미 픽셀아트이고 **달빛 평원 · 왼쪽 성 · 오른쪽 마왕성 · 검을 든 주인공** = 이 게임의 구도 그 자체다. NA 타일로 만든 탑다운 잔디밭은 타이틀 컷으로 열등하다(실제로 만들어 비교한 뒤 폐기했다). 타이틀 일러스트가 인게임보다 고해상도인 것은 픽셀아트의 표준 관례 |
| 캐릭터 선택 카드 | **v1 유지** | 로비와 같은 화법의 초상 카드. 16px 스프라이트를 확대해 넣으면 정보량이 준다 |
| `burst_effect` `xp_orb` `chest_open_effect` `attack_effect` | **절차적 유지** | 색 사각형 파티클은 픽셀 테마와 충돌하지 않고, 색이 곧 정보다(원소·희귀도) |
| `world_grid._draw_rift` | **절차적 유지** | "차원이 찢어진 틈"에 대응하는 NA 에셋이 없다. 절차적 폴리곤이 더 정확한 그림 |

---

## 7. ⚠️ 소유권 경계 접촉 (보고 대상)

| # | 위치 | 소유 | 변경 | 판단 |
|---|---|---|---|---|
| 1 | `enemy.gd::_physics_process` | W7/W0 | 시각 전용 변수 2줄 — `visual_facing` 갱신, `boss_attack_anim` 감쇠 | 규칙 경로 무영향. 스프라이트 방향·공격 모션에 필수 |
| 2 | `enemy.gd::_fire_boss_pattern` | W10 | `boss_attack_anim = 0.62` **1줄 추가** | 마왕이 탄막을 뿌릴 때 검을 휘두르게 하는 유일한 훅 |
| 3 | `projectile.gd` / `enemy_bullet.gd` | W4 | `visual_time` 누적 1줄씩, `enemy_bullet`의 `rotation += delta*5` → `rotation = direction.angle()` | 자전은 도형 마름모용이었다. 스프라이트에는 앞뒤가 있어 방향 정렬이 맞다 |
| 4 | `castle_interior.gd` | W9 | `_ready()` 신설(텍스처 필터), `_draw()`/`_draw_npc()` 렌더만 | 좌표·판정·`service_visual` 무수정. `--castle-test` 17항목 전부 true |
| 5 | `world_grid.gd::_draw_castle` | W1 | 성 앞 흙길 사각형만 남기고 나머지 도형 삭제 | 흙길은 "입구가 여기"라는 정보라 스프라이트 밑에 깔았다 |

**시각 무관 테스트 단언 수정: 0건.** 렌더 교체로 깨진 단언이 하나도 없었다.

---

## 8. 다음 웨이브(W12)가 알아야 할 것

### 8.1 남은 시각 항목 (전부 선택 사항)

| 항목 | 현재 | 제안 |
|---|---|---|
| **정예 몹 크기** | 정예(`is_camp_elite`)는 `radius × 1.45`(반경 ~22 → 후광 지름 63px)인데 스프라이트는 32px 그대로다 | 왕관·후광이 "정예"를 이미 전달하므로 급하지 않다. 키우려면 배율 예외가 하나 더 생긴다는 점을 감안할 것 |
| **오우거·들멧돼지** | 반경 18.75 / 19인데 스프라이트 32px | 위와 같은 트레이드오프 |
| **Kenney 파티클 ADD 발광** | 미사용 | `burst_effect.gd`에 `CanvasItemMaterial(BLEND_MODE_ADD)` + `light_0x`로 잔광을 깔면 야간 전투가 화사해진다. 노드 1개 추가로 끝난다 |
| **성 내부 벽·문** | 절차적 사각형 | `TilesetHouse`의 성벽 크레넬레이션(대략 src 128,128 부근)으로 교체 가능 |
| **밤 환경 오버레이** | 없음 | `FX/Environment/Fog.png`(320×180) · `Raylight.png` · `FX/Particle/Rain`·`Snow`가 대기하고 있다 |

### 8.2 함정 (밟지 말 것)

1. **`ATLAS_CELL_INSET`를 0에서 올리지 말 것.** 물가의 흰 포말 선이 잘려 호수 가장자리가 두 번 끊긴다.
2. **마왕 시트만 ×3이다.** `enemy.gd`의 `BOSS_CELL`(144×288)·`BOSS_MASK_OFFSET`(0,1440)을 다른 몹 상수와 헷갈리지 말 것.
3. **마스크는 시트 아래 절반이다.** 시트를 새로 구우면 `_with_mask()`를 통과시켜야 하고, 그러지 않으면 마스크 소스 rect가 빈 영역을 가리켜 플래시가 사라진다(조용히 실패한다).
4. **방향성 VFX는 +X.** 새 시트를 추가할 때 원본 축이 +X가 아니면 `_rotate_square_frames_cw()`를 통과시켜라. 런타임에서 축을 보정하려 들지 말 것 — v1이 그러다 180° 버그를 냈다.
5. **몹 시트에 런타임 modulate로 종 색을 입히지 말 것.** 색보정은 `MOB_TINT`로 빌드 때 굽는다. 런타임 modulate는 피격 플래시·밤 변이·경직이 이미 쓰고 있어 예산이 겹친다.
6. **`art/generated/`와 `art/external/`은 지우지 말 것.** 참조만 끊었다. 되돌리려면 preload 경로 한 줄씩만 바꾸면 된다.
7. **`--editor --quit`을 새 PNG 생성 뒤에 반드시 한 번 돌려라.** `.import`가 없으면 `preload`가 파스 에러로 죽는다. `run_all.sh`의 1단계가 겸하지만, 빌드 직후 수동 실행이 안전하다.

### 8.3 크레딧

전부 CC0라 표기 의무는 없지만 미덕으로 남겼다(`art/v2/ASSET_MAP.md` §8).

- **Ninja Adventure Asset Pack** — Pixel-boy & AAA · CC0
- **Kenney Particle Pack** — Kenney · CC0

배포물(`README` 또는 로비 하단)에 한 줄 표기하는 것을 권한다.
