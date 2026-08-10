#!/usr/bin/env bash
# =============================================================================
# 극딜 용사 — 전체 자동 검사 (W0 신설)
# =============================================================================
# 컴파일 검사 1회 + 기능 테스트 **16종**을 순서대로 돌리고 종합 PASS/FAIL을 낸다.
# (요약표는 컴파일 1행을 더해 **17행**이다 — 「17종」이라 세지 말 것.)
# (v2 11종 + v3 신설 2종 --stage-test / --status-test. 설계 부록 A-2 ㉖.
#  V4가 --deadline-test를 삭제했다 — 검사 항목은 --stage-test가 승계했다.
#  U3가 --guide-test를 신설했다 — 스포트라이트 온보딩 길잡이.
#  **Y5가 --field-test를 신설했다** — 필드 생태 런타임(습성 · 낮 선공 게이트 ·
#  지형 가중 스폰 · 무리 스폰과 상한 · 돌 우회). 지형 계약은 --world-test가 계속 본다.
#  **Y6가 --event-test를 신설했다** — 발견 기반 내비 · 필드 사건 8종 ·
#  소비 아이템 8종과 Q · 보물상자 배당표.
#  요약표 행 수가 16 → **17**이 됐다 = 컴파일 1 + 기능 16종.)
#
#   bash godot-game/scripts/test/run_all.sh            # 전부 실행
#   bash godot-game/scripts/test/run_all.sh --v4-test  # 지정한 플래그만 실행
#   GODOT=/path/to/godot bash .../run_all.sh           # 다른 Godot 바이너리 사용
#
# 종료 코드: 0 = 전부 PASS, 1 = 하나라도 FAIL.
# CI·다른 에이전트는 이 종료 코드만 보면 된다. 사람이 볼 요약표는 stdout에 나온다.
#
# 하나의 테스트가 FAIL로 집계되는 조건(하나라도 걸리면 FAIL):
#   ① Godot 종료 코드가 0이 아니다        -> test_runner.gd `_quit_test_cleanly(false)`
#   ② 기대한 *_TEST_COMPLETE 줄이 없다     -> 도중에 죽었거나 타임아웃
#   ③ 출력에 `=false`가 있다               -> 검사 플래그 중 하나가 거짓
#   ④ 출력에 SCRIPT ERROR / ERROR: 가 있다 -> 종료 코드가 0이어도 실패로 본다
#
# 시각 캡처(--capture-*)는 자동 PASS/FAIL 집계에 넣지 않는다. macOS 헤드리스에서
# 빈 화면이 나오기 때문에 창을 띄워야 하고, 사람 눈 검수가 목적이다(AGENTS.md §11).
# 대신 캡처 일괄 실행 모드를 둔다 — 저장된 PNG는 사람이 직접 열어 확인한다:
#
#   bash godot-game/scripts/test/run_all.sh --captures            # 전체 캡처
#   bash godot-game/scripts/test/run_all.sh --captures --capture-hud
#
# --capture-hud(W5 신설 · X3에서 6컷)는 필드 HUD를 한 번에 저장한다.
# --capture-world는 W5 이후 **HUD 없는 순수 월드**다(두 캡처의 역할이 갈렸다).
#
# V8(2026-08-09) 캡처 갱신 — 플래그 목록은 그대로다(신설 0 · 재사용만):
#   --capture-castle  컷 5가 "1차 각성 계보 3종 택1" → **보스 트로피 2택1**로 바뀌었다
#                     (`castle-minimal-v2-lineage.png` → `castle-minimal-v2-trophy.png`).
#                     계약자 컷은 dwell 3에서 찍어 세 거래가 전부 열린 그림이 된다.
#   --capture-result  v3 지표(다섯 관문 · 등급 · 트로피 · 시너지 발동)로 데이터가 바뀌었다.
#
# X1(2026-08-09) 캡처 갱신 — 플래그 목록은 여전히 그대로다(신설 0 · 컷만 늘었다):
#   --capture-choice  3컷 → **5컷**. 레벨업 모달이 "이미지 중심 2택 + 취소"로 개편됐다.
#                     level / focus / **cancel** / **growthcap** / item.
#                     검수 기준 한 줄: "읽을 게 확 줄었는가"(카드당 글자 줄 4개 이하).
#   --capture-castle  5컷 → **6컷**. 각인 세공사가 **3택 진열 + 값표 + 새로고침**이 됐다.
#                     `castle-minimal-v2-rune-shop.png` + `-rune-reroll.png`(신설).
#
# X2(2026-08-09) 캡처 갱신 — 플래그 목록 그대로(신설 0 · 파일 이름이 갈렸다):
#   --capture-rail    3컷 → **4컷**. ESC 편집 화면이 "그림 7개 + 호버 툴팁"으로 개편됐다.
#                     `rail-x2-overview.png` / `rail-x2-tip-slot.png`(칸 손잡이 호버) /
#                     `rail-x2-tip-metrics.png`(한 바퀴 지표 호버) / `rail-x2-pick.png`.
#                     구 `rail-minimal-v2-*.png` 3장은 더 이상 생성되지 않는다.
#                     검수 기준 한 줄 — **중학생 3초 테스트**: 처음 보는 사람이 컷 1만 보고
#                     ①5칸이 순서대로 돈다 ②카드를 끌어 넣는다 ③각인이 칸에 붙어 있다
#                     를 알아차리는가. 호버 컷 2장은 "지운 문장이 어디로 갔는가"의 증거다.
#
# X3(2026-08-09) 캡처 갱신 — 플래그 목록 그대로(신설 0 · 파일 이름과 컷 수가 갈렸다):
#   --capture-hud     4컷 → **6컷**. 필드 HUD가 프레임리스 오버레이 + 가장자리 화살표 +
#                     미니 딜싸이클 스트립으로 전면 재설계됐다.
#                     `hud-x3-day / -night / -reload / -tip / -blight / -stage5-night.png`
#                     구 `hud-minimal-v2-*.png` 4장은 더 이상 생성되지 않는다.
#                     **필수 검수 컷은 `hud-x3-stage5-night.png`**다 — 판을 걷어낸 HUD가
#                     무너진다면 5스테이지 밤 + 안개 + 비네트에서 무너진다. 체력 바 ·
#                     바늘 · 가장자리 화살표 · 숫자가 전부 읽히면 나머지는 자동이다.
#                     이 캡처는 로그에 `HUD_COVERAGE block_pct=… ink_pct=…`도 찍는다
#                     (HUD가 필드를 가리는 면적의 합집합. X3 이전 31.74% → 이후 참조).
#   --capture-guide   컷 3의 파일 이름이 `guide-minimal-v2-compass.png` →
#                     **`guide-x3-nav.png`**로 갈렸다(나침반 패널 → 가장자리 화살표).
#
# X4(2026-08-09) 캡처 갱신 — 플래그 목록 그대로(신설 0 · 컷 수도 그대로):
#   --capture-guide   **필드가 비어 있는 것이 정상이다.** 길잡이가 켜지는 순간
#                     `_guide_clear_threats()`가 필드 잡몹과 적 탄환을 전부 걷고,
#                     남은 것은 얼린다(사용자 피드백 ② "길잡이 중에 게임이 시작되면
#                     안 돼"). 컷에 마물이 걸어 다니면 그것이 곧 회귀 신호다.
#   --capture-onboarding
#                     4컷 그대로지만 **읽을 게 3분의 1 줄었다**(규칙 3줄 → 2줄 ·
#                     최장 줄 59자 → 31자 · 페이지 최대 560자 → 318자).
#                     검수 기준 한 줄 — "한 페이지를 3초 안에 훑을 수 있는가".
#                     1페이지에 마우스 줄(「자세히 보기 · 숫자 위에 올리면」)이,
#                     4페이지 규칙에 화살표 규약이 새로 들어갔는지도 같이 본다.
set -uo pipefail

GODOT="${GODOT:-godot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"   # .../godot-game
LOG_DIR="${PROJECT_DIR}/.test-logs"

# 테스트 1개당 상한(초). stress는 4초 대기 + combat은 12초 대기라 여유를 둔다.
TEST_TIMEOUT="${TEST_TIMEOUT:-180}"

ALL_TESTS=(
	"--world-test:WORLD_TEST_COMPLETE"
	# Y5(2026-08-10) 신설: 필드 생태 **런타임**. `--world-test`가 지형(정적 계약)을 보고
	#   이쪽은 그 위에서 사는 몹을 본다 — 습성 배선(habit_wired) · 낮 습성 5종(habit_day) ·
	#   1·2스테이지 낮 선공 0(day_aggro_zero · 데이터 축 + 런타임 스폰 축) ·
	#   지형 가중 스폰(terrain_spawn) · 무리 스폰과 개체 상한(herd_spawn) ·
	#   추적 중 돌 우회(rock_detour).
	"--field-test:FIELD_TEST_COMPLETE"
	# X2(2026-08-09): `--v4-test`에 `edit_minimal` 묶음이 늘었다 — ESC 편집 화면의
	#   ⓐ 상시 문장 라벨 0건 · 전체 글자 라벨 32개 이하 ⓑ 모드 바 소멸
	#   ⓒ 툴팁 6축 + 칸당 3축 등록 ⓓ 강제 표시 경로 동작 ⓔ 각인 툴팁 무손실
	#   ⓕ 손잡이=slot · 카드=card 제스처. `edit_layout`·`two_gesture`는 무변경 통과다.
	"--v4-test:V4_TEST_COMPLETE"
	# V8(2026-08-09): `--castle-test`의 각성 단언 2종(awakening_day3 / awakening_day6)이
	# **보스 트로피 3종**(trophy_flow / trophy_stack / trophy_reserve)과 상점가 스테이지
	# 스케일(price_scale)로 교체됐다. 계약 3거래는 그대로 유지 + 게이트 단언이 늘었다.
	# X1: `rune_shop` 묶음 전면 재작성 — 3택 진열 · 희귀도/흐름 가격 · 진열 유지 ·
	#     새로고침 계단 · 구매 시 마왕 조각 0.
	"--castle-test:CASTLE_TEST_COMPLETE"
	"--rift-test:RIFT_TEST_COMPLETE"
	"--stress-test:STRESS_TEST_COMPLETE"
	"--smoke-test:SMOKE_TEST_COMPLETE"
	"--combat-test:COMBAT_TEST_COMPLETE"
	# V4(2026-08-09): `--deadline-test`는 여기서 **삭제됐다.** 7일 하드 기한·강림
	# 스케줄이 v3에서 사라졌기 때문이다. 여전히 유효한 검사 7종(조기 도전 · 마왕 각인
	# 공식 · 5칸 구성 · 전조 게이트/스폰/보상 · 단조성)은 `--stage-test`가 승계했다.
	"--stage-test:STAGE_TEST_COMPLETE"
	"--status-test:STATUS_TEST_COMPLETE"
	"--cycle-test:CYCLE_TEST_COMPLETE"
	# V8: `growth_cap` 묶음 추가 — 성장 천장 1안(레일 5칸 + 보관함 R3 포화)의 E2E다.
	# X1: 그 천장의 출구가 "각인 드래프트 자동 전환" → **"취소가 기본 제안"**으로 바뀌었고
	#     (`GROWTH_CAP_AUTO_RUNE_DRAFT`는 false로 고정), `cancel`·`demon_floor` 두 묶음이
	#     늘었다 — 레벨업 취소의 마왕 무전달과 그 대가인 마왕 성장 하한이다.
	"--draft-test:DRAFT_TEST_COMPLETE"
	# ✅ V7(2026-08-09): `--boss-test`를 **되살렸다.** V5가 임시 제외했던 이유(v2의
	#    "7일차 밤 끝 = 마왕전" 스케줄 단언 → `boss_cycle` null → 하드 크래시 → 180초
	#    타임아웃)는 테스트를 v3 의미로 전면 재작성하면서 사라졌다. handoff-v4가 지목한
	#    크래시 2곳(강림 트리거 · v2 HP 공식 하드코딩)은 각각 삭제·교체됐다.
	#    이제 이 테스트는 스테이지 보스 3종·격파 전환·마왕 직행·강림 밸브를 본다.
	#    V8 가산: 격파 4곳이 전부 **트로피 2택1 → 5칸 배치**를 지나가고, 마지막 `result`
	#    묶음이 결과 화면 v3(5관문 타임라인 · 등급 · v2 기한 어휘 0건)를 단언한다.
	"--boss-test:BOSS_TEST_COMPLETE"
	# V9(2026-08-09): `--save-test` **전면 재작성** — 저장 schema 3 확정.
	#   런을 스테이지 3 · 체류 5 · 잠식 활성 · 트로피 2개 · 균열 2개(1 클리어)까지 끌고 가
	#   저장 → 로드 → 지문 68축(V8 49축 + 스테이지/랜드마크/그레이드 19축) 대조를 한다.
	#   신설 묶음 6종: combat_save(전투 중 저장 정책) · visual(복원 직후 낮밤·아틀라스·
	#   그레이드) · fallback(개명 폴백표) · transition(스테이지 3→4 전이 왕복) ·
	#   lobby(이어하기 표기) · legacy_reject가 **v1과 schema 2를 둘 다** 버리는지.
	"--save-test:SAVE_TEST_COMPLETE"
	# U3(2026-08-09) 신설: 스포트라이트 온보딩 길잡이(`playing` 서브모드).
	#   발동 조건(새 런=열림 / 이어하기·재방문=안 열림) · 스텝 표가 온보딩 1페이지의
	#   약속(이동·대시·상호작용·ESC)을 지키는가 · "해 보면 넘어간다" 입력 시뮬 2종 ·
	#   SPACE 개별 스킵과 ESC 확인 칩 · 길잡이 중 자동 저장 정지 · `guide_seen` 저장과
	#   설정의 「온보딩 다시 표시」 동반 초기화 · 스포트라이트 구멍이 대상을 무는가.
	# X4(2026-08-09): 두 묶음이 늘었다.
	#   freeze  길잡이 중 **세계가 멈추는가** — 필드 잡몹이 걷혔는가 · 뒤에 생긴 적도
	#           얼어붙는가 · 실제 물리 프레임에서 0px 움직이는가 · 클럭·체류·런 시계가
	#           서는가 · 끝나면 저절로 깨어나는가. (사용자 피드백 ②의 회귀 방지선)
	#   diet    온보딩 4페이지의 상시 노출 글자 수 상한 — 페이지 ≤360자 · 한 줄 ≤32자 ·
	#           규칙 ≤2줄. X2가 편집 화면에 세운 `edit_prose` 계약의 온보딩 판이다.
	#           로그에 `onb_pages=[…] onb_peak=… onb_longest=…`가 매 실행 찍힌다.
	"--guide-test:GUIDE_TEST_COMPLETE"
	# Y6(2026-08-10) 신설: 발견 게이팅(음성 축 포함) · 사건 예산과 시드 결정성 ·
	#   사건 자리 계약 · 전투형 사건 한 바퀴 · 소비 아이템 8종의 실제 효과 ·
	#   상자 배당표 합 100과 신설 두 칸의 발화.
	"--event-test:EVENT_TEST_COMPLETE"
)

# 시각 캡처 목록. TestRunner.ROUTINES의 --capture-* 플래그와 1:1로 맞춰 둔다.
ALL_CAPTURES=(
	"--capture-hud"
	"--capture-world"
	"--capture-factory"
	"--capture-rail"
	"--capture-draft"
	# U2 v3(2026-08-09) 신설 — 레벨업 2택 + 아이템 2택.
	#   ⚠️ 세 번째 선택지 「각인 강화」는 X1이 삭제했고 그 자리는 「취소 +N G」다.
	"--capture-choice"
	# U3 v3(2026-08-09) 신설 — 스포트라이트 길잡이 컷
	#   (플레이어 · 5칸 레일 · 가장자리 화살표 · ESC 확인 칩).
	#   ⚠️ X3가 나침반 패널을 삭제했다 — 세 번째 컷은 이제 가장자리 화살표 내비다.
	"--capture-guide"
	"--capture-boss"
	"--capture-castle"
	"--capture-result"
	"--capture-effects"
	"--capture-lobby"
	"--capture-character"
	# U1 v3(2026-08-09) 신설 — 설정 화면(킷 토글 3종 · 킷 게이지 슬라이더 2종).
	"--capture-settings"
	"--capture-onboarding"
)

if ! command -v "${GODOT}" >/dev/null 2>&1; then
	echo "run_all.sh: Godot 실행 파일을 찾을 수 없습니다: ${GODOT}" >&2
	echo "  GODOT=/Applications/Godot.app/Contents/MacOS/Godot bash $0 처럼 지정하세요." >&2
	exit 1
fi

# `timeout`은 macOS 기본 설치에 없다. 없으면 그냥 시간 제한 없이 돌린다.
run_with_timeout() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "${TEST_TIMEOUT}" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout "${TEST_TIMEOUT}" "$@"
	else
		"$@"
	fi
}

# ------------------------------------------------------- 캡처 모드 (--captures)
# 판정하지 않는다. 창을 띄워(--headless 없이) 실행하고 PNG 저장 여부만 알려 준다.
if [ "${1:-}" = "--captures" ]; then
	shift
	CAPTURES=()
	if [ "$#" -gt 0 ]; then
		for wanted in "$@"; do
			for entry in "${ALL_CAPTURES[@]}"; do
				[ "${entry}" = "${wanted}" ] && CAPTURES+=("${entry}")
			done
		done
		if [ "${#CAPTURES[@]}" -eq 0 ]; then
			echo "run_all.sh: 알 수 없는 캡처 플래그: $*" >&2
			echo "  사용 가능: ${ALL_CAPTURES[*]}" >&2
			exit 1
		fi
	else
		CAPTURES=("${ALL_CAPTURES[@]}")
	fi
	mkdir -p "${LOG_DIR}"
	for flag in "${CAPTURES[@]}"; do
		printf '\n=== %s ===\n' "${flag}"
		LOG="${LOG_DIR}/${flag#--}.log"
		run_with_timeout "${GODOT}" --path "${PROJECT_DIR}" -- "${flag}" >"${LOG}" 2>&1
		grep -E "VISUAL_CAPTURE_(COMPLETE|PAGE)" "${LOG}" || echo "  캡처 출력 없음 -> ${LOG}"
	done
	echo ""
	echo "캡처 PNG: ${PROJECT_DIR}/art/screenshots/qa"
	exit 0
fi

# 인자를 주면 그 플래그만 돌린다.
TESTS=()
if [ "$#" -gt 0 ]; then
	for wanted in "$@"; do
		for entry in "${ALL_TESTS[@]}"; do
			if [ "${entry%%:*}" = "${wanted}" ]; then
				TESTS+=("${entry}")
			fi
		done
	done
	if [ "${#TESTS[@]}" -eq 0 ]; then
		echo "run_all.sh: 알 수 없는 테스트 플래그: $*" >&2
		echo "  사용 가능: ${ALL_TESTS[*]%%:*}" >&2
		exit 1
	fi
else
	TESTS=("${ALL_TESTS[@]}")
fi

mkdir -p "${LOG_DIR}"
rm -f "${LOG_DIR}"/*.log 2>/dev/null || true

FAILURES=()
RESULTS=()
STARTED_AT=$(date +%s)

# ---------------------------------------------------------------- 컴파일 검사
printf '\n=== [1/%d] 컴파일·리소스 검사 (--editor --quit) ===\n' "$(( ${#TESTS[@]} + 1 ))"
COMPILE_LOG="${LOG_DIR}/compile.log"
run_with_timeout "${GODOT}" --headless --path "${PROJECT_DIR}" --editor --quit >"${COMPILE_LOG}" 2>&1
COMPILE_CODE=$?
COMPILE_ERRORS=$(grep -c -E "SCRIPT ERROR|Parse Error|^ERROR:" "${COMPILE_LOG}" 2>/dev/null || true)
COMPILE_ERRORS=${COMPILE_ERRORS:-0}
if [ "${COMPILE_CODE}" -ne 0 ] || [ "${COMPILE_ERRORS}" -ne 0 ]; then
	RESULTS+=("FAIL|compile|exit=${COMPILE_CODE} errors=${COMPILE_ERRORS}")
	FAILURES+=("compile")
	echo "  FAIL (exit=${COMPILE_CODE}, error 줄 ${COMPILE_ERRORS}개) -> ${COMPILE_LOG}"
	grep -E "SCRIPT ERROR|Parse Error|^ERROR:" "${COMPILE_LOG}" | head -20
	# 컴파일이 깨졌으면 기능 테스트는 전부 무의미하므로 여기서 끝낸다.
	echo ""
	echo "==================== 종합 결과: FAIL ===================="
	echo "컴파일이 실패해 기능 테스트를 실행하지 않았습니다."
	exit 1
fi
RESULTS+=("PASS|compile|exit=0")
echo "  PASS"

# ---------------------------------------------------------------- 기능 테스트
INDEX=1
for entry in "${TESTS[@]}"; do
	INDEX=$(( INDEX + 1 ))
	FLAG="${entry%%:*}"
	MARKER="${entry##*:}"
	NAME="${FLAG#--}"
	LOG="${LOG_DIR}/${NAME}.log"

	printf '\n=== [%d/%d] %s ===\n' "${INDEX}" "$(( ${#TESTS[@]} + 1 ))" "${FLAG}"
	run_with_timeout "${GODOT}" --headless --path "${PROJECT_DIR}" -- "${FLAG}" >"${LOG}" 2>&1
	CODE=$?

	REASONS=""
	[ "${CODE}" -ne 0 ] && REASONS="${REASONS} exit=${CODE}"
	grep -q "${MARKER}" "${LOG}" || REASONS="${REASONS} no-${MARKER}"
	grep -q -- "=false" "${LOG}" && REASONS="${REASONS} flag-false"
	grep -q -E "SCRIPT ERROR|^ERROR:" "${LOG}" && REASONS="${REASONS} script-error"

	SUMMARY=$(grep -E "${MARKER}" "${LOG}" | head -1)
	[ -n "${SUMMARY}" ] && echo "  ${SUMMARY}"

	if [ -z "${REASONS}" ]; then
		RESULTS+=("PASS|${NAME}|exit=0")
		echo "  PASS"
	else
		RESULTS+=("FAIL|${NAME}|${REASONS# }")
		FAILURES+=("${NAME}")
		echo "  FAIL —${REASONS}  -> ${LOG}"
		grep -E "SCRIPT ERROR|^ERROR:" "${LOG}" | head -10
	fi
done

# -------------------------------------------------------------------- 요약표
ELAPSED=$(( $(date +%s) - STARTED_AT ))
echo ""
echo "======================== 요약 ========================"
printf '%-8s %-18s %s\n' "결과" "검사" "비고"
printf -- '-----------------------------------------------------\n'
for row in "${RESULTS[@]}"; do
	IFS='|' read -r verdict name note <<<"${row}"
	printf '%-8s %-18s %s\n' "${verdict}" "${name}" "${note}"
done
printf -- '-----------------------------------------------------\n'
echo "소요 ${ELAPSED}초 · 로그 ${LOG_DIR}"

if [ "${#FAILURES[@]}" -eq 0 ]; then
	echo ""
	echo "==================== 종합 결과: PASS ===================="
	exit 0
fi

echo ""
echo "==================== 종합 결과: FAIL ===================="
echo "실패: ${FAILURES[*]}"
exit 1
