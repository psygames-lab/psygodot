extends Node3D
class_name TempleRunnerWorldBuilder

signal runner_area_touched(area: Area3D)

const DirectorScript := preload("res://demo/temple_runner/scripts/obstacle_director.gd")
const SEGMENT_LENGTH := 13.0
const SEGMENT_COUNT := 18

var director
var segments: Array[Node3D] = []
var next_segment_index := 0

func _ready() -> void:
	name = "TempleWorld"
	director = DirectorScript.new()
	add_child(director)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		if child != director:
			child.queue_free()
	segments.clear()
	next_segment_index = 0
	for i in range(SEGMENT_COUNT):
		_spawn_segment(-float(i) * SEGMENT_LENGTH)

func scroll(delta: float, speed: float) -> void:
	for segment in segments:
		segment.position.z += speed * delta
	var farthest_z := _farthest_segment_z()
	for segment in segments:
		if segment.position.z > SEGMENT_LENGTH:
			_clear_segment(segment)
			segment.position.z = farthest_z - SEGMENT_LENGTH
			farthest_z = segment.position.z
			director.decorate_segment(segment, next_segment_index, SEGMENT_LENGTH)
			_connect_areas(segment)
			next_segment_index += 1

func get_active_hazards() -> Array[Area3D]:
	var hazards: Array[Area3D] = []
	for segment in segments:
		for area in _collect_areas(segment):
			if area.get_meta("runner_active", true) and area.get_meta("runner_kind", "") != "gem":
				hazards.append(area)
	return hazards

func _spawn_segment(z: float) -> void:
	var segment := Node3D.new()
	segment.name = "Segment_%03d" % next_segment_index
	segment.position.z = z
	add_child(segment)
	segments.append(segment)
	director.decorate_segment(segment, next_segment_index, SEGMENT_LENGTH)
	_connect_areas(segment)
	next_segment_index += 1

func _clear_segment(segment: Node3D) -> void:
	for child in segment.get_children():
		child.queue_free()

func _farthest_segment_z() -> float:
	var farthest := 0.0
	for i in range(segments.size()):
		if i == 0 or segments[i].position.z < farthest:
			farthest = segments[i].position.z
	return farthest

func _connect_areas(root: Node) -> void:
	for area in _collect_areas(root):
		if not area.body_entered.is_connected(_on_area_body_entered):
			area.body_entered.connect(_on_area_body_entered.bind(area))

func _collect_areas(root: Node) -> Array[Area3D]:
	var result: Array[Area3D] = []
	for child in root.get_children():
		if child is Area3D:
			result.append(child)
		result.append_array(_collect_areas(child))
	return result

func _on_area_body_entered(body: Node3D, area: Area3D) -> void:
	if body.name == "Runner" and bool(area.get_meta("runner_active", true)):
		runner_area_touched.emit(area)
