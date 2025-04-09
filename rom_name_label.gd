extends Label

func _on_mouse_entered() -> void:
	modulate.a = 1

func _on_mouse_exited() -> void:
	modulate.a = 0.5

func _gui_input(event) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Emulator.game_name = text
			get_tree().change_scene_to_file("uid://d531712tl7rh")
