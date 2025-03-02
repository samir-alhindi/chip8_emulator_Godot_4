extends Node2D

var RAM: PackedByteArray = []
var program_counter: int = 0x200
var adress_pointer: int = 0x0000

var registers: PackedByteArray = []
var address_register: int = 0

var stack: Array = []
var stack_pointer: int = 0

var screen: Array[PackedByteArray] = []

var delay_timer: int = 0
var sound_timer: int = 0

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
	
	screen[0][0] = 1
	screen[12][14] = 1
	# Load test upcodes into RAM:
	load_rom_into_ram(from16to8(0x00E0))
	execute_opcode()
	# put test values in registers:
	for i:int in range(16):
		registers[i] = i

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
		0x8000: #1st nibble is '8':
			match opcode & 0x000F: # Still contains more data in the last nibble.
				0x0000: # 8XY0: set VX to the value of VY.
					registers[opcode >> 8 & 0x0F] = registers[opcode >> 4 & 0x0F]
				_:
					print("Error: {opcode} is Unsupported Opcode.")
					return

		0x0000: #1st nibble is '0':
			if opcode == 0x00E0: # 00E0: Clears the screen.
				for array: PackedByteArray in screen:
					array.fill(0)
		_:
			print("Error: {opcode} is Unsupported Opcode.")
			return

func from16to8(Opcode: int) -> PackedByteArray:
	return [Opcode >> 8 ,Opcode & 0x00FF]

func _draw() -> void:
	for x: int in range(screen.size()):
		for y: int in range(screen[x].size()):
			if screen[x][y] == 1:
				var pixel: Rect2 = Rect2(Vector2(x, y), Vector2(1, 1))
				draw_rect(pixel, Color.WHITE, true)
