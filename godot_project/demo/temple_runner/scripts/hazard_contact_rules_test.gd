extends Node

const Rules := preload("res://demo/temple_runner/scripts/hazard_contact_rules.gd")

var failures: Array[String] = []

func _ready() -> void:
	_expect(not Rules.should_damage("block", Vector3(1.15, 0.0, 0.0), Vector3.ZERO, false, 0), "adjacent visual lane edge should not damage against a block")
	_expect(Rules.should_damage("block", Vector3(0.0, 0.0, 0.0), Vector3.ZERO, false, 0), "centered block contact should damage")
	_expect(not Rules.should_damage("gap", Vector3(0.0, 0.55, 0.0), Vector3(0.0, -2.0, 0.0), false, 0), "airborne runner should clear a gap while descending")
	_expect(Rules.should_damage("gap", Vector3(0.0, 0.08, 0.0), Vector3(0.0, -2.0, 0.0), false, 0), "low descending runner should fall into a gap")
	_expect(not Rules.should_damage("low_gate", Vector3(0.0, 0.0, 0.0), Vector3.ZERO, true, 0), "sliding runner should clear a low gate")
	_expect(Rules.should_damage("low_gate", Vector3(0.0, 0.0, 0.0), Vector3.ZERO, false, 0), "standing runner should hit a low gate")
	_expect(not Rules.should_damage("spikes", Vector3(0.0, 0.72, 0.0), Vector3.ZERO, false, 0), "jumping runner should clear spikes")

	if failures.is_empty():
		print("PSYGODOT_HAZARD_CONTACT_RULES_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
