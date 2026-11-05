class_name TriggerManager
extends RefCounted

# Generated event selectors and study codes only; no HED or device I/O.
var _buckets: Dictionary = {}

func configure(config: Dictionary) -> void:
	_buckets.clear()
	for rule in config.get("rules", []):
		var selector: Dictionary = rule["match"]
		var event_type: String = selector["event_type"]
		var event_tag: String = selector["event_tag"]
		var conditions: Array = []
		for path in selector:
			if path != "event_type" and path != "event_tag":
				conditions.append({"path": String(path).split("."), "value": selector[path]})
		if not _buckets.has(event_type):
			_buckets[event_type] = {}
		if not _buckets[event_type].has(event_tag):
			_buckets[event_type][event_tag] = []
		_buckets[event_type][event_tag].append({"id": rule["id"], "code": int(rule["code"]), "conditions": conditions})

func marker_for(event: Dictionary) -> Dictionary:
	var matches: Array = _buckets.get(event["event_type"], {}).get(event["event_tag"], [])
	var selected: Dictionary = {}
	for rule in matches:
		if _matches(event, rule["conditions"]):
			if not selected.is_empty():
				push_error("Ambiguous marker configuration for " + String(event["event_tag"]))
				return {}
			selected = rule
	if selected.is_empty():
		return {}
	return {"code": selected["code"], "label": selected["id"], "driver": "mock"}

func _matches(event: Dictionary, conditions: Array) -> bool:
	for condition in conditions:
		var value: Variant = event
		for key in condition["path"]:
			if not value is Dictionary or not value.has(key):
				return false
			value = value[key]
		var expected: Variant = condition["value"]
		var both_numbers := (value is int or value is float) and (expected is int or expected is float)
		if typeof(value) != typeof(expected) and not both_numbers:
			return false
		if value != expected:
			return false
	return true
