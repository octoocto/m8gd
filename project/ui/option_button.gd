@tool
class_name UIOptionButton
extends UIBase

signal pressed
signal item_selected(index: int)
signal item_focused(index: int)

var item_count: int:
	get():
		return option_button.item_count

var selected: int:
	get():
		return option_button.selected
	set(value):
		option_button.selected = value

@onready var option_button: OptionButton = $OptionButton

@onready var stylebox_normal: StyleBox
@onready var stylebox_hover: StyleBox
@onready var stylebox_pressed: StyleBox
@onready var stylebox_disabled: StyleBox


func _on_ready() -> void:
	option_button.get_popup().canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)

	option_button.pressed.connect(pressed.emit)
	option_button.item_selected.connect(item_selected.emit)
	option_button.item_focused.connect(item_focused.emit)

	reset_size()


func _generate_styleboxes() -> void:
	option_button.remove_theme_stylebox_override("normal")
	stylebox_normal = get_theme_stylebox("normal", "OptionButton").duplicate()
	stylebox_hover = stylebox_normal.duplicate()
	stylebox_pressed = stylebox_normal.duplicate()
	stylebox_disabled = stylebox_normal.duplicate()
	option_button.add_theme_stylebox_override("normal", stylebox_normal)
	option_button.add_theme_stylebox_override("hover", stylebox_hover)
	option_button.add_theme_stylebox_override("pressed", stylebox_pressed)
	option_button.add_theme_stylebox_override("disabled", stylebox_disabled)


func _on_changed() -> void:
	_generate_styleboxes()

	if stylebox_normal:
		stylebox_normal.bg_color = _pal("button_bg_normal")
		stylebox_hover.bg_color = _pal("button_bg_hover")
		stylebox_pressed.bg_color = _pal("button_bg_pressed")
		stylebox_disabled.bg_color = _pal("button_bg_disabled")

	option_button.disabled = not enabled


func get_popup() -> PopupMenu:
	return option_button.get_popup()


func clear() -> void:
	option_button.clear()


func add_item(text: String, id: int = -1) -> void:
	option_button.add_item(_format_text(text), id)


func set_item_icon(index: int, icon: Texture2D) -> void:
	option_button.set_item_icon(index, icon)


func set_item_metadata(index: int, metadata: Variant) -> void:
	option_button.set_item_metadata(index, metadata)


func get_item_text(index: int) -> String:
	return option_button.get_item_text(index)


func get_item_metadata(index: int) -> Variant:
	return option_button.get_item_metadata(index)


func select(index: int) -> void:
	option_button.select(index)
