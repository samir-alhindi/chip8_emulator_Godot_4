extends FileDialog

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)

func _on_file_selected(path: String) -> void:
	Emulator.game_path = path
	get_tree().change_scene_to_file("uid://d531712tl7rh")

func _on_canceled() -> void:
	get_tree().quit()
