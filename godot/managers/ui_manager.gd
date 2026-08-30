## Manages menus and other general UI.
class_name UIManager extends Resource

const THEME: UITheme = preload("res://ui/theme/menu_theme.tres")
const DEFAULT_PALETTE: ColorPalette = preload("res://ui/theme/palette.tres")

signal palette_changed()

@export var palette := DEFAULT_PALETTE.colors:
	set(value):
		palette = value
		self.palette_changed.emit()

var _main: Main


func _init(main: Main) -> void:
	self._main = main
	# self._main.m8c.theme_changed.connect(
	# 	func(colors: PackedColorArray) -> void:
	# 		self.palette = colors,
	# )
