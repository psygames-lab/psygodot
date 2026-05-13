extends Node

func _ready() -> void:
	call_deferred("_start_validation")

func _start_validation() -> void:
	var err := get_tree().change_scene_to_file("res://scenes/ArenaSurvivorGame.tscn")
	if err != OK:
		push_error("Unable to start ArenaSurvivorGame for validation: %s" % err)
		get_tree().quit(1)
