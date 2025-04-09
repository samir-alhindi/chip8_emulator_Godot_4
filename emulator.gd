class_name Emulator extends Node2D

var RAM: PackedByteArray = []
var program_counter: int = 0x200
var adress_pointer: int = 0x0000

var registers: PackedByteArray = []
var index_register: int = 0

var stack: Array = []

var screen: Array[PackedByteArray] = []

var delay_timer: int = 0
var sound_timer: int = 0

var timers_decrement_rate: int = 60 # timers decrease by "1" 60 times per second (60 Hz).
var time_accumulator: float = 0.0
var time_accumulator_2: float = 0.0
var draw_accumulator: float = 0.0

# if halted is false then the game is running.
# if true then the game has stopped running.
var halted: bool = false
var last_opcode: int
var last_key_pressed: String

@onready var beep: AudioStreamPlayer = %Beep


## ROM to load.
static var game_name: String
## color of the black screen.
static var background_color: Color = Color.BLACK
## color of the drawn sprites.
static var sprite_color: Color = Color.WHITE
## Instructions per second.
static var instructions_per_frame: int = 11

## Set VY value to VX before bit shift (8XY6, 8XYE).
var set_VX_to_VY_before_shift: bool = false
## The AND, OR and XOR opcodes (8xy1, 8xy2 and 8xy3) reset the flags register to zero.
var _8xy1_8xy2_8xy3_reset_VF: bool = false
## The save and load opcodes (Fx55 and Fx65) increment the index register.
var FX55_and_FX65_increment_I: bool = false
## Sprites wrap around the screen instead of being clipped.
var sprite_wrap: bool = false
## use VX with BNNN instead of V0
var use_V0_in_BNNN: bool = false
## Where the font data (1, 2, 3,...E, F) is stored in RAM.
var font_offset: int = 0x50

var font: PackedByteArray = [
0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
0x20, 0x60, 0x20, 0x20, 0x70, # 1
0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
0x90, 0x90, 0xF0, 0x10, 0x10, # 4
0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
0xF0, 0x10, 0x20, 0x40, 0x40, # 7
0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
0xF0, 0x90, 0xF0, 0x90, 0x90, # A
0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
0xF0, 0x80, 0x80, 0x80, 0xF0, # C
0xE0, 0x90, 0x90, 0x90, 0xE0, # D
0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
0xF0, 0x80, 0xF0, 0x80, 0x80  # F
]

func _ready() -> void:
	# Init RAM, Registers and screen:
	RAM.resize(4 * 1024)
	RAM.fill(0x0000)
	registers.resize(16)
	registers.fill(0x0000)
	screen.resize(64)
	RenderingServer.set_default_clear_color(background_color)
	for array: PackedByteArray in screen:
		array.resize(32)
		array.fill(0x0000)
	
	# Load font into RAM:
	var offset: int = font_offset
	for i: int in font:
		RAM[offset] = i
		offset += 1
	
	var rom: PackedByteArray = open_read_and_get_ROM("res://ROMs/" + game_name) 
	load_rom_into_ram(rom)

func _process(delta: float) -> void:
	time_accumulator += delta
	
	while time_accumulator >= (1.0 / 60):
		for i in range(instructions_per_frame):
			if not halted:
				execute_opcode()
				program_counter += 2  # Each Chip-8 instruction is 2 bytes.
		
		if delay_timer > 0:
			delay_timer -= 1
		if sound_timer > 0:
			beep.play()
			sound_timer -= 1
		
		queue_redraw()
		
		time_accumulator -= (1.0 / 60)

	if Input.is_anything_pressed() and halted:
		var keys: = PackedStringArray([
		"1", "2", "3", "C", "4", "5", "6", "D",
		"7", "8", "9", "E", "A", "0", "B", "F"])
		for key: String in keys:
			if Input.is_action_just_pressed(key):
				last_key_pressed = key
				var temp: int = last_key_pressed.hex_to_int()
				registers[last_opcode >> 8 & 0x0F] = temp
				last_opcode = 0x0000
				break
	
	if last_key_pressed != "":
		if Input.is_action_just_released(last_key_pressed) and halted:
			halted = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().change_scene_to_file("uid://cygcpmr1ct6el")
	elif event.is_action_pressed("reset"):
		get_tree().reload_current_scene()

func open_read_and_get_ROM(ROM_file_path: String) -> PackedByteArray:
	var ROM: FileAccess = FileAccess.open(ROM_file_path, FileAccess.READ)
	ROM.big_endian = true
	var ROM_opcodes: PackedByteArray = []
	while ROM.get_position() < ROM.get_length():
		ROM_opcodes.append(ROM.get_8())
	return ROM_opcodes

func load_rom_into_ram(ROM: PackedByteArray) -> void:
	var offset: int = 0x200
	for i: int in ROM:
		RAM[offset] = i
		offset += 1

func execute_opcode() -> void:
	# Fetch Opcode:
	var opcode: int = (RAM[program_counter] << 8) | RAM[program_counter + 1]
	
	# Decode Opcode:
	match opcode & 0xF000: # Decode the Opcode type from the 1st nibble.
	
		0x0000: #1st nibble is '0':
			if opcode == 0x00E0: # 00E0: Clears the screen.
				for array: PackedByteArray in screen:
					array.fill(0)
			
			elif opcode == 0x00EE: # 00EE: Returns from a subroutine.
				program_counter = stack.pop_back()
			
			else:
				print("ERROR: 0x%x is unknown opcode." % opcode)
				return
		
		0x1000: # 1st nibble is '1':
			# 1NNN: Jumps to address NNN.
			program_counter = (opcode & 0x0FFF) - 2 # Subtract 2 so our PC increment doesn't ruin our address.
		
		0x2000: # 1st nibble is '2':
			# 2NNN: Calls subroutine at NNN.
			stack.append(program_counter) # Push current PC to stack so we can return later.
			program_counter = (opcode & 0x0FFF) - 2 # Subtract 2 so it our PC increment doesn't ruin our address.
		
		0x3000: # 1st nibble is '3':
			 # 3XNN: Skips the next instruction if VX equals NN.
			if registers[opcode >> 8 & 0x0F] == opcode & 0x00FF:
				program_counter += 2
		
		0x4000: # 1st nibble is '4':
			# 4XNN: Skips the next instruction if VX does NOT equal NN.
			if registers[opcode >> 8 & 0x0F] != opcode & 0x00FF:
				program_counter += 2
		
		0x5000: # 1st nibble is '4':
			# 5XY0: Skips the next instruction if VX equals VY.
			if registers[opcode >> 8 & 0x0F] == registers[opcode >> 4 & 0x00F]:
				program_counter += 2

		0x6000: #1st nibble is '6': 
			registers[opcode >> 8 & 0x0F] = opcode & 0x00FF # 6XNN: Sets VX to NN
		
		0x7000: #1st nibble is '7':
			registers[opcode >> 8 & 0x0F] += opcode & 0x00FF # 7XNN: Adds NN to VX (carry flag is not changed).

		0x8000: # 1st nibble is '8':
			match opcode & 0x000F: # Still contains more data in the last nibble.
				0x0000: # 8XY0: set VX to the value of VY.
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x0F]
				
				0x0001: # 8XY1: Sets VX to VX or VY. (bitwise OR operation).
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] | registers[opcode >> 4 & 0x00F]
					# Quirk:
					if _8xy1_8xy2_8xy3_reset_VF:
						registers[0xF] = 0
				
				0x0002: # 8XY2: Sets VX to VX and VY. (bitwise AND operation).
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] & registers[opcode >> 4 & 0x00F]
					# Quirk:
					if _8xy1_8xy2_8xy3_reset_VF:
						registers[0xF] = 0
				
				0x0003: # 8XY3: Sets VX to VX XOR VY.
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] ^ registers[opcode >> 4 & 0x00F]
					# Quirk:
					if _8xy1_8xy2_8xy3_reset_VF:
						registers[0xF] = 0
				
				0x0004:
					# 8XY4: Adds VY to VX. VF is set to 1 when there's an overflow, and to 0 when there is not.
					var result: int = registers[opcode >> 8 & 0x0F] + registers[opcode >> 4 & 0xF]
					registers[opcode >> 8 & 0x0F] += registers[opcode >> 4 & 0xF]
					if result > 255: # Check if there's overflow.
						registers[0xF] = 1 # Set VF to 1 if there is
					else:
						registers[0xF] = 0 # Set VF to 0 if there's no overflow.
				
				0x0005:
					# 8XY5: VY is subtracted from VX. VF is set to 0 when there's an underflow, and 1 when there is not.
					var result: int = registers[opcode >> 8 & 0x0F] - registers[opcode >> 4 & 0x0F]
					registers[opcode >> 8 & 0x0F] -= registers[opcode >> 4 & 0x0F]
					if result < 0: # Check if there's an underflow.
						registers[0x0F] = 0 # There is and VF is set to 0.
					else:
						registers[0x0F] = 1 # There isn't and VF is set to 1.
				
				0x0006:
					# 8XY6: Shift VX value 1 bit to the right:
					# Quirk:
					if set_VX_to_VY_before_shift == true:
						# Set VX to VY before shifting
						registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x0F]
					var bit_shifted_out: int = registers[opcode >> 8 & 0x0F] & 0b0001
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] >> 1
					registers[0xF] = bit_shifted_out # Set VF to the bit that was shifted out
				
				0x0007:
					# 8XY7: Sets VX to VY minus VX. VF is set to 0 when there's an underflow, and 1 when there is not. (i.e. VF set to 1 if VY >= VX).
					var result: int = registers[opcode >> 4 & 0x00F] - registers[opcode >> 8 & 0x0F]
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x00F] - registers[opcode >> 8 & 0x0F]
					if result < 0:
						registers[0xF] = 0
					else:
						registers[0xF] = 1
				
				0x000E:
					# 8XYE: Shifts VX to the left by 1:
					if set_VX_to_VY_before_shift == true:
						# Set VX to VY before shifting
						registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x0F]
					var vx_value: int = registers[opcode >> 8 & 0x0F]
					var bit_shifted_out: int = (vx_value >> 7) & 0b1
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] << 1
					registers[0xF] = bit_shifted_out # Set VF to the bit that was shifted out
				
				_:
					print("ERROR: 0x%x is unknown opcode." % opcode)
					return
		
		0x9000: # 1st nibble is '9':
			# 9XY0: Skips the next instruction if VX does not equal VY.
			if registers[opcode >> 8 & 0x0F] != registers[opcode >> 4 & 0x00F]:
				program_counter += 2

		0xA000: # 1st nibble is 'A'
			index_register = opcode & 0x0FFF # Sets I to the address NNN.
		
		0xB000: # 1st nibble is 'B':
			# BNNN: Jumps to the address NNN plus V0.
			# Quirk
			var address: int
			if use_V0_in_BNNN == true:
				address = (opcode & 0x0FFF) + registers[0]
			elif use_V0_in_BNNN == false:
				address = (opcode & 0x0FFF) + registers[opcode >> 8 & 0x0F]
			program_counter = address - 2 # Subtract 2 so our PC increment doesn't ruin our address.
		
		
		0xC000: # 1st nibble is 'C':
			# CXNN: Sets VX to the result of a bitwise and operation on a random number (Typically: 0 to 255) and NN.
			var rand_num: int = randi() % 256
			var NN: int = opcode & 0x00FF
			var result: int = rand_num & NN
			registers[opcode >> 8 & 0x0F] = result
		
		0xD000: # 1st nibble is 'D':
			# DXYN: Draws a sprite at coordinate (VX, VY):
			var X_POS: int = registers[opcode >> 8 & 0xF] % 64
			var x_pos: int = X_POS
			var y_pos: int = registers[opcode >> 4 & 0xF] % 32
			registers[0xF] = 0 # VF register must be cleared.
			var sprite_height: int = opcode & 0x000F
			for i: int in range(sprite_height):
				var byte: int = RAM[index_register + i]
				# For each of the 8 bits in this byte:
				for j: int in range(8):
					# Get current pixel and see if it's a '1' or a '0':
					var pixel: int = 1 if (byte << j & 0b10000000) != 0 else 0
					 # Check if pixel collision.
					if screen[x_pos][y_pos] == 1 and pixel == 1:
						# Turn off pixel on screen:
						screen[x_pos][y_pos] = 0
						registers[0xF] = 1
					elif pixel == 1 and screen[x_pos][y_pos] == 0:
						screen[x_pos][y_pos] = 1
					x_pos += 1
					if x_pos >= 64:
						if not sprite_wrap:
							break
						elif sprite_wrap:
							x_pos = x_pos % 64
					
				y_pos += 1
				if y_pos >= 32:
					if not sprite_wrap:
						break
					elif sprite_wrap:
						y_pos = y_pos % 32
				x_pos = X_POS
				
	
		0xE000: # 1st nibble is 'E':
			# Still more data in last 2 nibbles:
			match opcode & 0x00FF:
				0x009E:
					# EX9E: Skips the next instruction if the key stored in VX is pressed
					#(only consider the lowest nibble).
					var key: int = registers[opcode >> 8 & 0x0F]
					var temp: String = "%X" % key
					if Input.is_action_pressed(temp):
						program_counter += 2
				
				0x00A1:
					# EX9E: Skips the next instruction if the key stored in VX is NOT pressed
					#(only consider the lowest nibble).
					var key: int = registers[opcode >> 8 & 0x0F]
					var temp: String = "%X" % key
					if not Input.is_action_pressed(temp):
						program_counter += 2
				
				_:
					print("ERROR: 0x%x is unknown opcode." % opcode)
					return
	
		0xF000: # 1st nibble is 'F':
			match opcode & 0x00FF: # Last 2 nibbles still contain more data.
				
				0x0007: # FX07: Sets VX to the value of the delay timer.
					registers[opcode >> 8 & 0x0F] = delay_timer
				
				0x000A: # FX0A: Game is halted, A key press is awaited, and then stored in VX.
					last_opcode = opcode
					halted = true
				
				0x0015: # FX15: Sets the delay timer to VX.
					delay_timer = registers[opcode >> 8 & 0x0F]
				
				0x0018: # FX18: Sets the sound timer to VX.
					sound_timer = registers[opcode >> 8 & 0x0F]
				
				0x0029: # FX29: Sets I to the location of the sprite for the character in VX(only consider the lowest nibble).
					# Extract the last nibble:
					var vx_value: int = registers[opcode >> 8 & 0x0F]
					var chr: int = vx_value & 0x0F
					# Point I to the right char in save_and_load_increment_I:
					var font_data_start_address: int = font_offset
					# Each char is 5 bytes:
					var address: int = font_data_start_address + (chr * 5)
					index_register = address
				
				0x0033: # FX33:
					var number: int = registers[opcode >> 8 & 0x0F]
					RAM[index_register + 2] = number % 10
					@warning_ignore("integer_division")
					number = floor(number / 10)
					RAM[index_register + 1] = number % 10
					@warning_ignore("integer_division")
					number = floor(number / 10)
					RAM[index_register] = number
				
				0x0065: # FX65:
					var num_of_registers_to_fill: int = opcode >> 8 & 0x0F
					for i: int in range(num_of_registers_to_fill + 1):
						# Quirk:
						if not FX55_and_FX65_increment_I:
							registers[i] = RAM[index_register + i]
						elif FX55_and_FX65_increment_I:
							registers[i] = RAM[index_register]
							index_register += 1
				
				0x0055: # FX55:
					var num_of_times_to_iterate: int = opcode >> 8 & 0x0F
					for i: int in range(num_of_times_to_iterate + 1):
						# Quirk:
						if not FX55_and_FX65_increment_I:
							RAM[index_register + i] = registers[i]
						elif FX55_and_FX65_increment_I:
							RAM[index_register] = registers[i]
							index_register += 1
						
			
				0x001E: # FX1E: Adds VX to I. VF is not affected.
					index_register += registers[opcode >> 8 & 0x0F]
					
				_:
					print("ERROR: 0x%x is unknown opcode." % opcode)
					return
			
		_:
			print("ERROR: 0x%x is unknown opcode." % opcode)
			return

func from16to8(Opcode: int) -> PackedByteArray:
	return [Opcode >> 8 ,Opcode & 0x00FF]

func _draw() -> void:
	for x: int in range(screen.size()):
		for y: int in range(screen[x].size()):
			if screen[x][y] != 0:
				var pixel: Rect2 = Rect2(Vector2(x, y), Vector2(1, 1))
				draw_rect(pixel, sprite_color, true)


func _on_set_v_xto_v_yshift_pressed() -> void:
	set_VX_to_VY_before_shift = not set_VX_to_VY_before_shift

func _on_reset_vf_pressed() -> void:
	_8xy1_8xy2_8xy3_reset_VF = not _8xy1_8xy2_8xy3_reset_VF

func _on_increment_i_pressed() -> void:
	FX55_and_FX65_increment_I = not FX55_and_FX65_increment_I

func _on_sprite_wrapping_pressed() -> void:
	sprite_wrap = not sprite_wrap

func _on_bnnn_pressed() -> void:
	use_V0_in_BNNN = not use_V0_in_BNNN
