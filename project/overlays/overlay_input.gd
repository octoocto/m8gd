@tool
class_name OverlayInputDisplay
extends OverlayBase

@export_range(0.0, 1.0, 0.01) var opacity_pressed: float = 1.0:
	set(value):
		opacity_pressed = value
		_update()

@export_range(0.0, 1.0, 0.01) var opacity_held: float = 0.8:
	set(value):
		opacity_held = value
		_update()

@export_range(0.0, 1.0, 0.01) var opacity_released: float = 0.1:
	set(value):
		opacity_released = value
		_update()

@export var use_highlight_colors: bool = true:
	set(value):
		use_highlight_colors = value
		_update()

@onready var control: Control = $Control

@onready var key_to_rect: Dictionary[int, Panel] = {
	LibM8.KEY_UP: %RectUp,
	LibM8.KEY_DOWN: %RectDown,
	LibM8.KEY_LEFT: %RectLeft,
	LibM8.KEY_RIGHT: %RectRight,
	LibM8.KEY_OPTION: %RectOption,
	LibM8.KEY_EDIT: %RectEdit,
	LibM8.KEY_SHIFT: %RectShift,
	LibM8.KEY_PLAY: %RectPlay,
}

var tweens: Dictionary[Panel, Tween] = {}


func _overlay_init() -> void:
	Events.device_key_pressed.connect(_animate_pressed)
	Events.config_preset_value_changed.connect(
		func(_profile_name: String, section: String, _property: String, _value: Variant) -> void:
			if section == main.config.SECTION_COLORS:
				_update()
	)


func _update() -> void:
	control.position = position_offset
	anchors_preset = anchors_preset

	for key: int in main.M8_KEYS:
		_animate_pressed(key, main.m8_is_key_pressed(key))


func _animate_pressed(key: int, pressed: bool) -> void:
	var rect: Panel = key_to_rect[key]

	if tweens.has(rect) and tweens[rect].is_running():
		tweens[rect].kill()
	tweens[rect] = create_tween()

	rect.modulate = _get_color(key)

	if pressed:
		rect.modulate.a = opacity_pressed
		tweens[rect].tween_property(rect, "modulate:a", opacity_held, 0.2)
	else:
		tweens[rect].tween_property(rect, "modulate:a", opacity_released, 0.1)


func _get_color(key: int) -> Color:
	if not use_highlight_colors:
		return Color.WHITE

	match key:
		LibM8.KEY_UP, LibM8.KEY_DOWN, LibM8.KEY_LEFT, LibM8.KEY_RIGHT:
			return main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_DIR)
		LibM8.KEY_SHIFT:
			return main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_SHIFT)
		LibM8.KEY_PLAY:
			return main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_PLAY)
		LibM8.KEY_OPTION:
			return main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_OPTION)
		LibM8.KEY_EDIT:
			return main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_EDIT)
		_:
			return Color.WHITE
