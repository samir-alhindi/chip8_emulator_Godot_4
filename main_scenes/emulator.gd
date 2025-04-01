extends Node2D

var RAM: PackedByteArray = []
var program_counter: int = 0x200
var adress_pointer: int = 0x0000

var registers: PackedByteArray = []
var index_register: int = 0

var stack: Array = []
var stack_pointer: int = 0

var screen: Array[PackedByteArray] = []

var delay_timer: int = 0
var sound_timer: int = 0

var instruction_rate: int = 800  # Instructions per second
var time_accumulator: float = 0.0

# if halted is false then the game is running.
# if true then the game has stopped running.
var halted: bool = false:
	set(value):
		halted = value
		if value == true:
			print("game halted !")
		else:
			print("game continue...")
var last_opcode: int

var pong_path: StringName = "Pong (1 player).ch8"
var rom_3_path: StringName = "3-corax+.ch8"
var rom_4_path: StringName = "4-flags.ch8"
var rom_6_path: StringName = "6-keypad.ch8"

func _ready() -> void:
	# Init RAM, Registers and screen:
	RAM.resize(4 * 1024)
	RAM.fill(0x0000)
	registers.resize(16)
	registers.fill(0x0000)
	screen.resize(64)
	for array: PackedByteArray in screen:
		array.resize(32)
		array.fill(0x0000)
	
	# Load test upcodes into RAM:
	var rom: PackedByteArray = open_read_and_get_ROM("C:\\Users\\Samir\\Documents\\chip8\\ROMs\\" + rom_6_path) 
	load_rom_into_ram(rom)
	#RAM[0x1FF] = 2

func _process(delta: float) -> void:
	time_accumulator += delta
	while time_accumulator >= (1.0 / instruction_rate) and not halted:
		execute_opcode()
		program_counter += 2  # Each Chip-8 instruction is 2 bytes
		time_accumulator -= (1.0 / instruction_rate)
	queue_redraw()
	
	if Input.is_anything_pressed() and halted:
		var keys: = PackedStringArray([
		"1", "2", "3", "C", "4", "5", "6", "D",
		"7", "8", "9", "E", "A", "0", "B", "F"])
		for key: String in keys:
			if Input.is_action_just_pressed(key):
				var last_key_pressed: StringName = key
				var temp: int = last_key_pressed.hex_to_int()
				registers[last_opcode >> 8 & 0x0F] = temp
				last_opcode = 0x0000
				halted = false
				break

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
				stack_pointer -= 1
		
		0x1000: # 1st nibble is '1':
			# 1NNN: Jumps to address NNN.
			program_counter = (opcode & 0x0FFF) - 2 # Subtract 2 so it our PC increment doesn't ruin our address.
		
		0x2000: # 1st nibble is '2':
			# 2NNN: Calls subroutine at NNN.
			stack.append(program_counter) # Push current PC to stack so we can return later.
			stack_pointer += 1
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
				
				0x0002: # 8XY2: Sets VX to VX and VY. (bitwise AND operation).
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] & registers[opcode >> 4 & 0x00F]
				
				0x0003: # 8XY3: Sets VX to VX XOR VY.
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 8 & 0x0F] ^ registers[opcode >> 4 & 0x00F]
				
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
					# 8XY6: vX = vY >> 1, Set VF to the bit that was shifted out.
					var bit_shifted_out: int = registers[opcode >> 4 & 0x0F] & 0x0001
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x0F] >> 1
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
					# 8XYE: vX = vY << 1, Set VF to the bit that was shifted out.
					var Y_nibble: int = registers[opcode >> 4 & 0x0F]
					var bit_shifted_out: int = (Y_nibble >> 3) & 0x1
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x0F] << 1
					registers[0xF] = bit_shifted_out # Set VF to the bit that was shifted out
				
				
				_:
					print("ERROR: 0x%x is unknown opcode." % opcode)
					return
		
		0x9000: # 1st nibble is '9':
			# 9XY0: Skips the next instruction if VX does not equal VY.
			if registers[opcode >> 8 & 0x0F] != registers[opcode >> 4 & 0x00F]:
				program_counter += 2

		0xA000: # 1st nibble is 'A'
			index_register = opcode & 0x0FFF
		
		0xD000: # 1st nibble is 'D':
			# DXYN: Draws a sprite at coordinate (VX, VY)...
			registers[0xF] = 0 # VF register must be cleared first.
			var x_pos: int = registers[opcode >> 8 & 0xF] % 64
			var y_pos: int = registers[opcode >> 4 & 0xF] % 32
			for N: int in range(opcode & 0x000F):
				var Nth_byte: int = RAM[index_register + N]
				for i: int in range(8):
					if x_pos >= 64: x_pos = x_pos % 64 # wrap coordinates when reaching end of screen.
					screen[x_pos][y_pos] = screen[x_pos][y_pos] ^ (Nth_byte << i & 0b10000000)
					if screen[x_pos][y_pos] ^ (Nth_byte << i & 0b10000000) != 0: # Check if pixel collision.
						registers[0xF] = 1 # add 1 to the flag register VF.
					x_pos += 1
				y_pos += 1
				x_pos -= 8
				if y_pos >= 32: y_pos = y_pos % 32 # wrap coordinates when reaching end of screen.
				queue_redraw()
		
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
	
		0xF000: # 1st nibble is 'F':
			match opcode & 0x00FF: # Last 2 nibbles still contain more data.
				0x000A: # FX0A: Game is halted, A key press is awaited, and then stored in VX.
					last_opcode = opcode
					halted = true
				
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
						registers[i] = RAM[index_register + i]
				
				0x0055: # FX55:
					var num_of_times_to_iterate: int = opcode >> 8 & 0x0F
					for i: int in range(num_of_times_to_iterate + 1):
						RAM[index_register + i] = registers[i]
			
				0x001E: # FX1E: Adds VX to I. VF is not affected.
					index_register += registers[opcode >> 8 & 0x0F]
			
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
				draw_rect(pixel, Color.WHITE, true)
