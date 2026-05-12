extends Control

func _ready() -> void:
    var label := Label.new()
    label.text = "PsyGodot MVP scaffold"
    label.position = Vector2(24, 24)
    add_child(label)
