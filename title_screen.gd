extends Node

const BUTTON_THEME: Theme = preload("uid://bvrvntssv7s4j")
var path: String = ""
var file: bool = false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	set_layout()

func set_layout() -> void:
	file = false
	for button: Button in %"FolderNames".get_children():
		button.queue_free()
	%"Path".text = path
	var up_button: Button = Button.new()
	up_button.text = "<---"
	up_button.pressed.connect(go_up)
	up_button.theme = BUTTON_THEME
	up_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	%FolderNames.add_child(up_button)
	var dir: DirAccess = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var button: Button = Button.new()
		button.text = file_name
		button.theme = BUTTON_THEME
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		%FolderNames.add_child(button)
		if dir.current_is_dir():
			button.pressed.connect(open_folder.bind(file_name))
		else:
			button.pressed.connect(open_file.bind(file_name))
			if not file_name.get_extension() in ["ch8", "c8"]:
				button.queue_free()
		file_name = dir.get_next()

func open_folder(folder_name: String) -> void:
	if file == true:
		path = path.get_base_dir()
	path = path + "/" + folder_name
	set_layout()

func open_file(file_name: String) -> void:
	if file == true:
		path = path.get_base_dir()
	path = path + "/" + file_name
	%"Path".text = path
	file = true
	Emulator.game_path = path
	get_tree().change_scene_to_file("uid://d531712tl7rh")

func go_up() -> void:
	if file == true:
		path = path.get_base_dir()
	path = path.get_base_dir()
	set_layout()
