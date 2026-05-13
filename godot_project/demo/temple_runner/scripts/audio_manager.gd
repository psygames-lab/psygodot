extends Node
class_name TempleRunnerAudioManager

var player: AudioStreamPlayer
var queue: Array[Dictionary] = []
var sample_rate := 22050.0
var active := true

func _ready() -> void:
	if DisplayServer.get_name().to_lower() == "headless" or OS.has_feature("headless"):
		active = false
		return
	player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 0.12
	player.stream = stream
	add_child(player)
	player.play()
	play_start()

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	active = false
	queue.clear()
	if player:
		player.stop()
		player.stream = null

func _process(_delta: float) -> void:
	if not active:
		return
	if player == null:
		return
	var generator_playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if generator_playback == null:
		return
	while generator_playback.get_frames_available() > 0 and not queue.is_empty():
		var tone := queue[0]
		var phase: float = tone.get("phase", 0.0)
		var frames_left: int = tone.get("frames", 0)
		if frames_left <= 0:
			queue.pop_front()
			continue
		var sample := sin(phase) * float(tone.get("volume", 0.15))
		generator_playback.push_frame(Vector2(sample, sample))
		phase += TAU * float(tone.get("freq", 440.0)) / sample_rate
		tone["phase"] = phase
		tone["frames"] = frames_left - 1
		queue[0] = tone
		if tone["frames"] <= 0:
			queue.pop_front()

func play_start() -> void:
	_tone(330.0, 0.08, 0.12)
	_tone(495.0, 0.12, 0.14)

func play_gem() -> void:
	_tone(820.0, 0.07, 0.12)

func play_jump() -> void:
	_tone(520.0, 0.06, 0.09)

func play_slide() -> void:
	_tone(180.0, 0.08, 0.08)

func play_hit() -> void:
	_tone(92.0, 0.18, 0.18)

func play_game_over() -> void:
	_tone(220.0, 0.12, 0.14)
	_tone(145.0, 0.18, 0.14)

func play_near_miss() -> void:
	_tone(660.0, 0.05, 0.1)
	_tone(990.0, 0.06, 0.1)

func _tone(freq: float, seconds: float, volume: float) -> void:
	if not active:
		return
	queue.append({
		"freq": freq,
		"frames": int(sample_rate * seconds),
		"volume": volume,
		"phase": 0.0
	})
