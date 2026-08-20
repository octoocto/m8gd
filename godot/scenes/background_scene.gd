class_name BackgroundScene extends M8Scene

@export_group("Background", "background_")

@export var background_mode := BackgroundContainer.BackgroundMode.M8_BACKGROUND_COLOR:
	set(value):
		background_mode = value
		self.bg.mode = value

@export_file var background_file := "":
	set(value):
		background_file = value
		self.bg.texture_file = value

@export_range(0.0, 2.0, 0.01) var background_brightness: float = 1.0:
	set(value):
		background_brightness = value
		self.bg.brightness = value

@export_range(0.0, 1.0, 0.01) var background_theme_tint: float = 0.0:
	set(value):
		background_theme_tint = value
		self.bg.tint_amount = value

@export_range(0.0, 8.0, 0.1) var background_blur_amount: float = 4.0:
	set(value):
		background_blur_amount = value
		self.bg.blur_amount = value

@onready var bg: BackgroundContainer = %BackgroundContainer
