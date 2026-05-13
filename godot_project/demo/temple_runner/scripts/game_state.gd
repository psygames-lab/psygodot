extends RefCounted
class_name TempleRunnerState

signal changed
signal game_over

const MODE_TITLE := "title"
const MODE_PLAYING := "playing"
const MODE_GAME_OVER := "game_over"

var mode := MODE_TITLE
var hearts := 3
var score := 0
var distance := 0.0
var combo := 0
var speed := 15.0
var gems := 0
var near_misses := 0

func reset_to_title() -> void:
	mode = MODE_TITLE
	_reset_run_values()
	changed.emit()

func start_run() -> void:
	mode = MODE_PLAYING
	_reset_run_values()
	changed.emit()

func restart_run() -> void:
	start_run()

func advance(delta: float) -> void:
	if mode != MODE_PLAYING:
		return
	distance += speed * delta
	speed = min(31.0, 15.0 + distance * 0.022)
	score += int(delta * speed * (1.0 + combo * 0.04))
	changed.emit()

func collect_gem() -> int:
	if mode != MODE_PLAYING:
		return 0
	gems += 1
	combo += 1
	var reward := 100 + combo * 25
	score += reward
	changed.emit()
	return reward

func add_near_miss() -> int:
	if mode != MODE_PLAYING:
		return 0
	near_misses += 1
	combo += 2
	var reward := 175 + combo * 20
	score += reward
	changed.emit()
	return reward

func clear_hazard(kind: String) -> int:
	if mode != MODE_PLAYING:
		return 0
	combo += 1
	var reward := 75
	if kind == "gap" or kind == "low_gate":
		reward = 125
	score += reward + combo * 10
	changed.emit()
	return reward

func take_damage() -> void:
	if mode != MODE_PLAYING:
		return
	hearts -= 1
	combo = 0
	if hearts <= 0:
		hearts = 0
		mode = MODE_GAME_OVER
		game_over.emit()
	changed.emit()

func _reset_run_values() -> void:
	hearts = 3
	score = 0
	distance = 0.0
	combo = 0
	speed = 15.0
	gems = 0
	near_misses = 0
