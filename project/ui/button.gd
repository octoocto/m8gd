@tool
class_name UIButton
extends UIBase

signal pressed

@export var color_bg: Variant = -1:
	set(p_color):
		color_bg = p_color
		emit_ui_changed()

@export var color_bg_hover: Variant = -1:
	set(p_color):
		color_bg_hover = p_color
		emit_ui_changed()

@export var color_bg_pressed: Variant = -1:
	set(p_color):
		color_bg_pressed = p_color
		emit_ui_changed()

@export var color_bg_disabled: Variant = -1:
	set(p_color):
		color_bg_disabled = p_color
		emit_ui_changed()

@export var color_fg: Variant = -1:
	set(p_color):
		color_fg = p_color
		emit_ui_changed()

@export var text := "":
	set(p_text):
		text = p_text
		emit_ui_changed()

@export var text_right := "":
	set(p_text):
		text_right = p_text
		emit_ui_changed()

@export var icon: Texture2D = null:
	set(p_icon):
		icon = p_icon
		emit_ui_changed()

@export var horizontal_alignment := HORIZONTAL_ALIGNMENT_CENTER:
	set(value):
		horizontal_alignment = value
		emit_ui_changed()

@export var inline: bool = false:
	set(value):
		inline = value
		# _generate_styleboxes()
		emit_ui_changed()

@onready var hbox: HBoxContainer = %HBoxContainer
@onready var label: UILabel = %Label
@onready var label_right: UILabel = %LabelRight

@onready var panel_focus: Panel = %PanelFocus

@onready var stylebox_normal: StyleBox
@onready var stylebox_hover: StyleBox
@onready var stylebox_pressed: StyleBox
@onready var stylebox_disabled: StyleBox

var mouse_down: bool = false


func _generate_styleboxes() -> void:
	remove_theme_stylebox_override("panel")
	if inline:
		stylebox_normal = get_theme_stylebox("panel_inline", "UIButton").duplicate()
	else:
		stylebox_normal = get_theme_stylebox("panel_normal", "UIButton").duplicate()

	stylebox_hover = stylebox_normal.duplicate()
	stylebox_pressed = stylebox_normal.duplicate()
	stylebox_disabled = stylebox_normal.duplicate()


func _on_ready() -> void:
	_connect_mouse_events()
	gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb_event := event as InputEventMouseButton
				if mb_event.button_index == MOUSE_BUTTON_LEFT:
					if mb_event.pressed:
						mouse_down = true
						emit_ui_changed()
						return

					if enabled and mouse_down and is_mouse_inside():
						pressed.emit()

					mouse_down = false
					emit_ui_changed()
	)

	panel_focus.remove_theme_stylebox_override("panel")
	panel_focus.add_theme_stylebox_override("panel", get_theme_stylebox("focus"))
	focus_entered.connect(func() -> void: panel_focus.visible = true)
	focus_exited.connect(func() -> void: panel_focus.visible = false)


func _on_changed() -> void:
	_generate_styleboxes()

	if inline:
		stylebox_normal.bg_color = Color.TRANSPARENT
	else:
		stylebox_normal.bg_color = _pal_or("button_bg_normal", color_bg)

	stylebox_hover.bg_color = _pal_or("button_bg_hover", color_bg_hover)
	stylebox_pressed.bg_color = _pal_or("button_bg_pressed", color_bg_pressed)
	stylebox_disabled.bg_color = _pal_or("button_bg_disabled", color_bg_disabled)

	if not enabled:
		add_theme_stylebox_override("panel", stylebox_disabled)
	elif mouse_down:
		add_theme_stylebox_override("panel", stylebox_pressed)
	elif is_mouse_inside():
		add_theme_stylebox_override("panel", stylebox_hover)
	else:
		add_theme_stylebox_override("panel", stylebox_normal)

	if enabled:
		label.color_override = _pal_or("button_fg_normal", color_fg)
	else:
		label.color_override = _pal_or("button_fg_disabled", color_fg)

	label.text = _format_text(text)
	label_right.text = _format_text(text_right)

	label.visible = label.text != ""
	label_right.visible = label_right.text != ""

	if not label_right.visible:
		match horizontal_alignment:
			HORIZONTAL_ALIGNMENT_LEFT:
				label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			HORIZONTAL_ALIGNMENT_RIGHT:
				label.size_flags_horizontal = Control.SIZE_SHRINK_END + Control.SIZE_EXPAND
			_:
				label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER + Control.SIZE_EXPAND
	else:
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
