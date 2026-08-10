class_name SoundManager
extends Node

# =============================================================================
# 재생 스로틀 (사용자 피드백 30)
# =============================================================================
# `play()`는 호출마다 AudioStreamPlayer를 새로 만든다. 78기 동시 전투에서는
# 발소리·타격음·발사음이 초당 수백 번 들어오므로 귀도 프레임도 버티지 못한다.
# 게이트를 여기 한 곳에 둔다 — 호출부(game.play_sound)는 그대로 부르기만 한다.
#
# ① 사운드별 최소 재생 간격(초). 표에 없는 이름은 쿨다운 없음(모달·연출 단발음).
#    광역 카드가 한 프레임에 78기를 때려도 "impact"는 한 번만 난다.
const COOLDOWNS := {
	"step": 0.15,
	"impact": 0.09,
	"shoot": 0.05,
	"hit": 0.05,
	"hurt": 0.08,
	"collect": 0.06,
	# UI 클릭: 연타·드래그로 `pressed`가 몰려도 한 번만 딸깍한다.
	"click": 0.04
}
# ② 동시에 살아 있는 AudioStreamPlayer 총 개수 상한. 넘으면 조용히 드롭한다.
#    자식 수를 그대로 세므로 카운터가 어긋날 여지가 없고, 헤드리스 더미 드라이버가
#    `finished`를 내지 않아도 노드가 12개에서 멈춘다.
#    ⚠️ BGM 플레이어는 이 셈에서 **빠진다**(`_live_player_count()` 참조) — 상시
#    재생이라 세면 상한 12칸 중 한 칸을 영구 점유하고, 더 나쁘게는 "재생 안 함"
#    판정에 걸려 회수당한다.
const MAX_ACTIVE_PLAYERS := 12

# =============================================================================
# BGM — 플레이어 **한 대**를 끝까지 재사용한다
# =============================================================================
# 효과음은 호출마다 노드를 새로 만들지만 BGM은 `_bgm_player` 하나에 트랙만 갈아
# 끼운다. 같은 트랙을 다시 요청하면 처음부터 다시 틀지 않는다 — 낮↔밤 전환은
# **속도만** 바뀌어야 하고 거기서 곡이 0초로 되감기면 전환이 아니라 사고로 들린다.
#
# ⚠️ 속도는 `AudioStreamPlayer.pitch_scale`이다. 이 값은 **음정도 함께 바꾼다**
#    (리샘플링이라 0.9배속이면 반음 이상 낮아진다). 템포만 바꾸는 기능은 Godot
#    기본에 없다 — "배속" 요구를 그대로 이 값에 매핑한 결과다.
const BGM_TRACKS := {
	"menu": "res://audio/bgm_menu.wav",
	"field": "res://audio/bgm_field.wav",
	"boss": "res://audio/bgm_boss.mp3",
	"demon": "res://audio/bgm_demon.mp3"
}
## 트랙별 기본 음량(dB). 효과음에 묻히지도, 효과음을 덮지도 않는 자리에서 시작한다.
## 이 값은 **Master 버스 위**에 얹힌다 — 설정의 「전체 음량」(`master_volume_db`는
## Master 버스 볼륨을 직접 움직인다)은 그대로 먹고, 「효과음」 슬라이더
## (`effects_volume_db`)는 먹지 않는다. 그쪽은 `play()`의 인자에만 더해지는 값이라
## 음악에 걸리면 "효과음 0으로" 했을 때 음악까지 사라진다.
const BGM_VOLUME_DB := {
	"menu": -14.0,
	"field": -12.0,
	"boss": -11.0,
	"demon": -11.0
}
const BGM_PITCH_DEFAULT := 1.0
## 필드 낮 0.9배속 · 밤 1.2배속 · 스테이지 보스 1.1배속 (사용자 지정).
const BGM_PITCH_DAY := 0.9
const BGM_PITCH_NIGHT := 1.2
const BGM_PITCH_STAGE_BOSS := 1.1

var _streams: Dictionary = {}
## 사운드 이름 -> 다음 재생이 허용되는 시각(초, `Time.get_ticks_msec()` 기준).
## 일시정지와 무관한 벽시계라 모달이 열려 있어도 쿨다운이 정상적으로 흐른다.
var _next_play_time: Dictionary = {}
var _bgm_player: AudioStreamPlayer = null
## 트랙 이름 -> 로드된 AudioStream. 한 번 읽으면 런 끝까지 들고 있는다
## (필드곡 하나가 3.7MB라 매 전환마다 다시 읽으면 그 프레임이 튄다).
var _bgm_cache: Dictionary = {}
var _bgm_track := ""

## ⚠️ **종료 시 스트림 참조를 반드시 끊는다.**
## `_bgm_cache`가 `AudioStream`을 들고 있고 `_bgm_player.stream`도 하나를 참조하는데,
## 엔진이 내려갈 때 그게 남아 있으면 `ERROR: 1 resources still in use at exit`가 찍힌다.
## 그 한 줄은 기능 실패가 아니지만 `run_all.sh`가 `^ERROR:`로 잡아 **테스트를 무더기로
## 빨갛게 만든다**(실측: 17종 중 11종). 캐시를 비우고 플레이어의 스트림을 떼면 사라진다.
func _exit_tree() -> void:
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null
	_bgm_cache.clear()
	_streams.clear()
	_bgm_track = ""


func _ready() -> void:
	_streams = {
		"shoot": _make_tone(420.0, 700.0, 0.055, 0.18, 1),
		"hit": _make_tone(150.0, 85.0, 0.075, 0.28, 0),
		"collect": _make_tone(680.0, 1080.0, 0.085, 0.22, 1),
		"hurt": _make_tone(170.0, 55.0, 0.18, 0.42, 0),
		"choice": _make_tone(390.0, 920.0, 0.36, 0.28, 1),
		"debt": _make_tone(260.0, 70.0, 0.42, 0.32, 0),
		"boss": _make_tone(90.0, 210.0, 0.75, 0.42, 0),
		"win": _make_tone(440.0, 1320.0, 0.72, 0.32, 1),
		"night": _make_tone(180.0, 72.0, 0.72, 0.28, 0),
		"chest": _make_tone(520.0, 1180.0, 0.34, 0.25, 1),
		"camp": _make_tone(380.0, 620.0, 0.26, 0.18, 1),
		# 발소리: 흙을 밟는 둔탁한 저음. 아주 짧고 아주 작게 굽는다 — 이동 중 계속
		# 반복되는 유일한 소리라 여기서 크면 다른 모든 소리를 덮는다.
		# 62Hz까지 떨어뜨려 봤더니 노트북 스피커에서 아예 안 들려 95Hz에서 끊는다.
		# "hit"(150→85Hz)과 대역이 겹치지만 길이가 절반이고 14배 조용해 헷갈리지 않는다.
		"step": _make_tone(175.0, 95.0, 0.045, 0.12, 0),
		# 카드 타격음: "hit"(150→85Hz 0.075초 사인)보다 짧고 밝게, 그리고 **내려꽂는**
		# 스윕이라 올라가는 "shoot"(420→700Hz)과도 귀로 구분된다.
		"impact": _make_tone(900.0, 520.0, 0.042, 0.20, 1),
		# UI 클릭: 이 표에서 **가장 짧다**(28ms). 필드 소리와 겹칠 일이 거의 없지만
		# 겹쳐도 길이로 갈린다 — "impact"(42ms)는 내려꽂고 이쪽은 짧게 올려친다.
		# 「선택 확정」음("choice", 360ms)과 한 버튼에서 같이 나므로 확실히 작게 굽는다.
		"click": _make_tone(980.0, 1560.0, 0.028, 0.15, 1)
	}
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	# 모달(보스 프리뷰·설정·카드 선택)이 트리를 멈춰도 음악은 흘러야 한다.
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	# 스트림 자체가 반복 재생이면 이 신호는 오지 않는다. 온다는 건 루프 설정이
	# 어디선가 풀렸다는 뜻이라 이어서 한 번 더 튼다(보험 · 아래 `_force_loop` 참조).
	_bgm_player.finished.connect(_on_bgm_finished)

# =============================================================================
# BGM 공개 API
# =============================================================================
## 트랙을 갈아 끼운다. **같은 트랙이면 처음부터 다시 틀지 않고 속도만 갱신한다.**
## 모르는 트랙 이름은 조용히 무시한다 — 호출부가 화면 상태 문자열을 그대로 넘기는
## 구조라 이름 하나 어긋났다고 게임이 멈추면 안 된다.
## ⚠️ **헤드리스에서는 BGM 스트림을 아예 읽지 않는다.**
## 헤드리스에는 오디오 장치가 없어 소리가 나지도 않는데, 18MB WAV를 로드하면 엔진이
## 종료할 때 그 리소스를 놓지 못해 `ERROR: 1 resources still in use at exit`가 찍힌다.
## `run_all.sh`는 그 줄을 `^ERROR:`로 잡아 **테스트를 무더기로 실패 처리**한다
## (실측: 매 실행 무작위로 5~11종). 실기 플레이에는 영향이 0이다 —
## 이 분기는 창이 없는 실행에서만 탄다. 음악 로직(트랙 선택·배속·낮밤 전환)은
## 그대로 돌고, 재생만 건너뛴다.
static func _audio_available() -> bool:
	return DisplayServer.get_name() != "headless"

func play_bgm(track: String, pitch: float = BGM_PITCH_DEFAULT) -> void:
	if not _audio_available():
		# 스트림만 안 읽는다. **트랙 선택과 배속은 그대로 세운다** — 낮 0.9 / 밤 1.2 같은
		# 규칙은 오디오 장치 없이도 검증돼야 하고, 이 두 값은 리소스를 안 붙든다.
		_bgm_track = track
		if is_instance_valid(_bgm_player):
			_bgm_player.pitch_scale = pitch
		return
	if _bgm_player == null or not BGM_TRACKS.has(track):
		return
	if _bgm_track == track:
		set_bgm_pitch(pitch)
		return
	var stream := _bgm_stream(track)
	if stream == null:
		return
	_bgm_track = track
	_bgm_player.stream = stream
	_bgm_player.volume_db = float(BGM_VOLUME_DB.get(track, -12.0))
	_bgm_player.pitch_scale = maxf(pitch, 0.01)
	_bgm_player.play()

## 재생 중인 곡의 속도(=배속)만 바꾼다. 낮↔밤 전환이 부르는 자리다.
## 다시 말하지만 **음정도 같이 바뀐다.**
func set_bgm_pitch(pitch: float) -> void:
	if _bgm_player == null:
		return
	var value := maxf(pitch, 0.01)
	if not is_equal_approx(_bgm_player.pitch_scale, value):
		_bgm_player.pitch_scale = value

func stop_bgm() -> void:
	_bgm_track = ""
	if _bgm_player != null:
		_bgm_player.stop()

func bgm_track() -> String:
	return _bgm_track

func bgm_pitch() -> float:
	return 0.0 if _bgm_player == null else _bgm_player.pitch_scale

func bgm_playing() -> bool:
	return _bgm_player != null and _bgm_player.playing

## 테스트 단언용 손잡이. 스트림이 실제로 물렸는지·루프가 켜졌는지를 코드로 본다
## (헤드리스에는 오디오 장치가 없어 귀로는 아무것도 확인할 수 없다).
func bgm_player() -> AudioStreamPlayer:
	return _bgm_player

func _bgm_stream(track: String) -> AudioStream:
	if _bgm_cache.has(track):
		return _bgm_cache[track]
	var path := String(BGM_TRACKS.get(track, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("BGM 트랙을 찾을 수 없습니다: %s" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("BGM 트랙 로드 실패: %s" % path)
		return null
	_force_loop(stream)
	_bgm_cache[track] = stream
	return stream

## 임포터 설정이 어긋나 있어도 **반드시** 반복 재생이 되게 만든다.
## 정본은 `.import` 쪽이다(WAV `edit/loop_mode=2` · MP3 `loop=true`). 여기는 그게
## 유실됐을 때를 위한 이중 잠금이다 — WAV는 `loop_mode`+`loop_end`(프레임 단위)를,
## MP3는 `loop` 한 값을 본다. 두 리소스 타입의 루프 API가 서로 다르다.
func _force_loop(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav != null:
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_begin = 0
			# `get_length()`는 초, `loop_end`는 프레임이다. 마지막 한 프레임을 빼
			# 경계에서 샘플 밖을 읽지 않게 한다.
			wav.loop_end = maxi(0, int(wav.get_length() * float(wav.mix_rate)) - 1)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return
	var mp3 := stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true

func _on_bgm_finished() -> void:
	if _bgm_player != null and _bgm_player.stream != null:
		_bgm_player.play()

## 효과음 표에 이 이름이 있는가. `play()`는 없는 이름을 조용히 무시하므로
## "울릴 소리가 아예 없다"와 "쿨다운에 걸렸다"를 테스트가 구분할 수 없다.
func has_sound(sound_name: String) -> bool:
	return _streams.has(sound_name)

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var cooldown := float(COOLDOWNS.get(sound_name, 0.0))
	if cooldown > 0.0:
		var now := float(Time.get_ticks_msec()) * 0.001
		if now < float(_next_play_time.get(sound_name, 0.0)):
			return
		_next_play_time[sound_name] = now + cooldown
	if _live_player_count() >= MAX_ACTIVE_PLAYERS:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## 아직 울리고 있는 플레이어 수. 세는 김에 끝난 노드를 거둔다 — 어떤 이유로든
## `finished`를 놓친 노드가 쌓이면 상한이 **영구 침묵**으로 굳기 때문이다.
## 순회 길이는 상한 자신이 묶으므로 78기 전투에서도 12칸을 넘지 않는다.
func _live_player_count() -> int:
	var live := 0
	for child: Node in get_children():
		var stream_player := child as AudioStreamPlayer
		# BGM 플레이어는 효과음 풀이 아니다. 세지도, 회수하지도 않는다.
		if stream_player == null or stream_player == _bgm_player or stream_player.is_queued_for_deletion():
			continue
		if stream_player.playing:
			live += 1
		else:
			stream_player.queue_free()
	return live

func stop_all() -> void:
	_next_play_time.clear()
	# BGM은 **멈추기만** 한다. 노드를 free하면 다음 프레임의 `_update_bgm()`이
	# 해제된 참조를 잡는다(테스트 정리 절차가 매번 이 함수를 부른다).
	stop_bgm()
	for child: Node in get_children():
		if child == _bgm_player:
			continue
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			child.free()

func _make_tone(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	volume: float,
	waveform: int
) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0

	for index in sample_count:
		var progress := float(index) / float(maxi(sample_count - 1, 1))
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / float(sample_rate)
		var raw_wave := sin(phase)
		if waveform == 1:
			raw_wave = signf(raw_wave) * 0.68 + raw_wave * 0.32
		var envelope := pow(1.0 - progress, 1.8) * minf(progress * 18.0, 1.0)
		var sample := int(clampf(raw_wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
