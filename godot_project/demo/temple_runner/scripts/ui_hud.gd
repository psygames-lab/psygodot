extends CanvasLayer
class_name TempleRunnerHud

var stat_label: Label
var center_panel: PanelContainer
var center_title: Label
var center_body: Label
var flash_label: Label

func _ready() -> void:
	layer = 10
	_build_ui()

func update_state(state) -> void:
	var heart_text := ""
	for i in range(state.hearts):
		heart_text += "H"
	if heart_text == "":
		heart_text = "-"
	stat_label.text = "Hearts %s    Score %06d    Distance %dm    Gems %d    Combo x%d    Speed %.1f" % [
		heart_text, state.score, int(state.distance), state.gems, max(1, state.combo), state.speed
	]
	center_panel.visible = state.mode != "playing"
	if state.mode == "title":
		center_title.text = "PSYGODOT TEMPLE RUNNER"
		center_body.text = "Enter or Space: start\nA/D or Left/Right: lanes\nW/Up/Space: jump    S/Down: slide\nSurvive traps, grab gems, chain near misses."
	elif state.mode == "game_over":
		center_title.text = "RUN ENDED"
		center_body.text = "Score %d    Distance %dm    Gems %d    Near Misses %d\nR or Enter: restart" % [
			state.score, int(state.distance), state.gems, state.near_misses
		]

func show_flash(text: String, color: Color) -> void:
	flash_label.text = text
	flash_label.modulate = color
	flash_label.visible = true
	var tween := create_tween()
	tween.tween_property(flash_label, "modulate:a", 1.0, 0.01)
	tween.tween_property(flash_label, "position:y", 82.0, 0.01)
	tween.tween_property(flash_label, "position:y", 42.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash_label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func(): flash_label.visible = false)

func _build_ui() -> void:
	stat_label = Label.new()
	stat_label.name = "Stats"
	stat_label.position = Vector2(18, 14)
	stat_label.add_theme_font_size_override("font_size", 22)
	stat_label.modulate = Color(0.98, 0.94, 0.78)
	add_child(stat_label)

	flash_label = Label.new()
	flash_label.name = "Flash"
	flash_label.position = Vector2(36, 82)
	flash_label.add_theme_font_size_override("font_size", 30)
	flash_label.visible = false
	add_child(flash_label)

	center_panel = PanelContainer.new()
	center_panel.name = "CenterPanel"
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.size = Vector2(720, 270)
	center_panel.position = Vector2(-360, -135)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.035, 0.84)
	style.border_color = Color(0.95, 0.72, 0.24, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	center_panel.add_theme_stylebox_override("panel", style)
	add_child(center_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	center_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	center_title = Label.new()
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_title.add_theme_font_size_override("font_size", 38)
	center_title.modulate = Color(1.0, 0.74, 0.24)
	box.add_child(center_title)

	center_body = Label.new()
	center_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_body.add_theme_font_size_override("font_size", 22)
	center_body.modulate = Color(0.92, 0.95, 0.88)
	box.add_child(center_body)
