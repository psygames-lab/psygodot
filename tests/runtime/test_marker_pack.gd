extends SceneTree

# Run from the framework project against a game's exported PCK.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected: -- PACK_PATH EXPECTED_CATALOG_ID")
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(args[0]):
		push_error("Unable to mount export pack")
		quit(1)
		return
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://telemetry/marker_config.json"))
	var valid: bool = config is Dictionary and config.get("catalog_id") == args[1]
	for path in ["res://telemetry/event_catalog.json", "res://analysis/hed/mapping.json", "res://analysis/hed/events.json"]:
		if FileAccess.file_exists(path):
			push_error("Offline catalog/HED file unexpectedly bundled: " + path)
			valid = false
	print("Marker export pack: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
