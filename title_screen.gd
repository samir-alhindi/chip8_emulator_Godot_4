extends Node

const ROM_NAME_LABEL: PackedScene = preload("res://rom_name_label.tscn")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	$CanvasLayer/Buttons.show()
	$CanvasLayer/Roms.hide()
	$CanvasLayer/Settings.hide()

func _on_load_rom_button_pressed() -> void:
	$CanvasLayer/Buttons.hide()
	$CanvasLayer/Roms.show()
	
	# Load ROMs as buttons:
	var ROMs_path: StringName = "res://ROMs/"
	var dir: DirAccess = DirAccess.open(ROMs_path)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var label: Label = ROM_NAME_LABEL.instantiate()
		label.text = file_name
		$CanvasLayer/Roms/HBoxContainer/RomNames.add_child(label)
		file_name = dir.get_next()

func _on_settings_pressed() -> void:
	$CanvasLayer/Buttons.hide()
	$CanvasLayer/Settings.show()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_bg_picker_button_color_changed(color: Color) -> void:
	Emulator.background_color = color

func _on_sprite_picker_button_color_changed(color: Color) -> void:
	Emulator.sprite_color = color

# Return from Settings to main menu
func _on_return_pressed() -> void:
	$CanvasLayer/Buttons.show()
	$CanvasLayer/Settings.hide()
