@tool
class_name UIOptionButton
extends UIBase

signal pressed
signal item_selected(index: int)
signal item_focused(index: int)

var item_count: int:
	get ():
		return option_button.item_count

var selected: int:
	get ():
		return option_button.selected
	set(value):
		option_button.selected = value

@onready var option_button: OptionButton = $OptionButton


func _on_ready() -> void:
	option_button.get_popup().canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)

	option_button.pressed.connect(pressed.emit)
	option_button.item_selected.connect(item_selected.emit)
	option_button.item_focused.connect(item_focused.emit)

	reset_size()


func _update_theme() -> void:
	var stylebox_normal: StyleBoxFlat = get_theme_stylebox("normal", "OptionButton").duplicate()
	var stylebox_hover: StyleBoxFlat = stylebox_normal.duplicate()
	var stylebox_pressed: StyleBoxFlat = stylebox_normal.duplicate()
	var stylebox_disabled: StyleBoxFlat = stylebox_normal.duplicate()

	stylebox_normal.bg_color = _pal("button_bg_normal")
	stylebox_hover.bg_color = _pal("button_bg_hover")
	stylebox_pressed.bg_color = _pal("button_bg_pressed")
	stylebox_disabled.bg_color = _pal("button_bg_disabled")

	self.option_button.add_theme_stylebox_override("normal", stylebox_normal)
	self.option_button.add_theme_stylebox_override("hover", stylebox_hover)
	self.option_button.add_theme_stylebox_override("pressed", stylebox_pressed)
	self.option_button.add_theme_stylebox_override("disabled", stylebox_disabled)

	var stylebox_popup := StyleBoxFlat.new()
	var stylebox_popup_hover := StyleBoxFlat.new()

	stylebox_popup.bg_color = _pal("bg_popup_option")
	stylebox_popup.border_color = _pal("border_popup_option")
	stylebox_popup.set_border_width_all(1)
	stylebox_popup.set_expand_margin_all(1)
	stylebox_popup.set_content_margin_all(0)
	stylebox_popup.expand_margin_top = 0
	stylebox_popup.content_margin_top = 1
	stylebox_popup_hover.bg_color = _pal("bg_popup_option_hover")

	self.option_button.get_popup().add_theme_stylebox_override("panel", stylebox_popup)
	self.option_button.get_popup().add_theme_stylebox_override("hover", stylebox_popup_hover)


func _on_changed() -> void:
	_update_theme()

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
