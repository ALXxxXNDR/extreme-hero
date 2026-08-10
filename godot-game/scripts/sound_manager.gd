class_name SoundManager
extends Node

var _streams: Dictionary = {}

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
		"camp": _make_tone(380.0, 620.0, 0.26, 0.18, 1)
	}

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func stop_all() -> void:
	for child: Node in get_children():
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
