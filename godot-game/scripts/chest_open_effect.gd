class_name ChestOpenEffect
extends Node2D

# =============================================================================
# Y4 — 상자 열기 애니메이션 (피드백 ㉒ · FEEDBACK_Y §8 ㉒ · handoff-ya §5)
# =============================================================================
# 구판은 `_draw()`가 매 프레임 `draw_rect` 넷과 반짝이 10개를 **절차적으로** 찍었다.
# 나무통과 뚜껑이 각진 사각형이라 필드의 픽셀아트 상자(`landmark-chest.png`)와
# 전혀 다른 물건으로 보였고, 유저 피드백 ㉒가 그 어긋남을 지목했다.
# 원본은 `docs/v1-archive/chest_open_effect_y4.gd.txt`에 있다.
#
# 이제 YA가 구운 6프레임 시트(`chest-open.png` 384×64 · 셀 64)를 재생한다.
#   프레임 0~5 · 0.52초 / 6 = 프레임당 0.0867초
#
# ⚠️ **트윈 루프 금지 규칙(ui-style-v3 §11)에 걸리지 않는다.** 트윈을 쓰지 않고
#    `elapsed`로 프레임 번호만 고르며, 마지막 프레임 뒤에 `queue_free()`로
#    **1회 재생 후 사라진다**. 반복도 없고 상주 노드도 남지 않는다.
const SHEET := preload("res://art/v2/chest-open.png")
const FRAME_COUNT := 6
const FRAME_SIZE := 64.0
## 화면에 그려질 크기. 원본 64px를 ×1.5로 늘리면 픽셀이 불규칙해지므로 **정수배**만 쓴다.
const DRAW_SCALE := 2.0

var elapsed := 0.0
var duration := 0.52

func _ready() -> void:
	z_index = 18
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

## 지금 보여야 할 프레임 번호. 테스트가 직접 부를 수 있게 순수 함수로 뽑아 뒀다 —
## "0.52초 안에 6프레임이 전부 한 번씩 나오는가"가 이 효과의 유일한 계약이다.
func frame_at(time: float) -> int:
	if duration <= 0.0:
		return FRAME_COUNT - 1
	return clampi(int(floor(time / duration * float(FRAME_COUNT))), 0, FRAME_COUNT - 1)

func _draw() -> void:
	var frame := frame_at(elapsed)
	var source := Rect2(float(frame) * FRAME_SIZE, 0.0, FRAME_SIZE, FRAME_SIZE)
	var box := FRAME_SIZE * DRAW_SCALE
	# 상자 바닥이 원점에 오도록 아래 정렬한다(구판 사각형 배치와 같은 발밑 기준).
	var target := Rect2(-box * 0.5, -box + 24.0, box, box)
	draw_texture_rect_region(SHEET, target, source)
