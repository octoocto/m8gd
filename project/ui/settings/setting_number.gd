@tool
class_name SettingNumber
extends SettingBase

var _is_int_type := false

@export var setting_value_min_width := 40:
	set(p_value):
		setting_value_min_width = p_value
		emit_ui_changed()

@export var min_value := 0.0:
	set(value):
		min_value = value
		emit_ui_changed()

@export var max_value := 100.0:
	set(value):
		max_value = value
		emit_ui_changed()

@export var step := 1.0:
	set(value):
		step = value
		emit_ui_changed()

@export var value := 0.0:
	set(p_value):
		value = clamp(p_value, min_value, max_value)
		emit_value_changed()

@export var show_ticks := false:
	set(p_value):
		show_ticks = p_value
		emit_ui_changed()

@export var as_percent := false:
	set(p_value):
		as_percent = p_value
		emit_ui_changed()

@export var percent_factor := 100.0:
	set(p_value):
		percent_factor = p_value
		emit_ui_changed()

@export var format_string := "%.2f":
	set(p_value):
		format_string = p_value
		emit_ui_changed()

@onready var label: UILabel = %Label
@onready var slider: HSlider = %HSlider
@onready var line_edit: LineEdit = %LineEdit

var stylebox_slider: StyleBoxLine
var stylebox_grabber_area: StyleBoxFlat
var stylebox_grabber_area_highlight: StyleBoxFlat

var stylebox_line_edit: StyleBoxFlat

var format_fn: Callable


func _on_ready() -> void:
	slider.value_changed.connect(func(p_value: float) -> void: value = p_value)
	line_edit.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				if (
					(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
					and event.is_pressed()
				):
					line_edit.accept_event()
					if _is_int_type:
						line_edit.text = "%d" % slider.value
					else:
						line_edit.text = "%.2f" % slider.value
					line_edit.select_all()
	)

	line_edit.text_submitted.connect(
		func(text: String) -> void:
			line_edit.deselect()
			line_edit.release_focus()
			_set_value_from_text(text)
	)

	_connect_mouse_events(slider)
	# _connect_mouse_events(line_edit)


func _generate_styleboxes() -> void:
	self.stylebox_slider = _make_stylebox_unique("slider", slider)
	self.stylebox_grabber_area = _make_stylebox_unique("grabber_area", slider)
	self.stylebox_grabber_area_highlight = _make_stylebox_unique("grabber_area_highlight", slider)
	self.stylebox_line_edit = _make_stylebox_unique("normal", line_edit)

	if is_mouse_inside():
		stylebox_slider.color = _pal("slider_bg_hover")
	else:
		stylebox_slider.color = _pal("slider_bg_normal")
	stylebox_grabber_area.bg_color = _pal("slider_fg_normal")
	stylebox_grabber_area_highlight.bg_color = _pal("slider_fg_hover")

	stylebox_line_edit.bg_color = _pal("input_bg_normal")

	# if is_mouse_inside(line_edit):
	# 	stylebox_line_edit.bg_color = _pal("input_bg_hover")
	# else:
	# 	stylebox_line_edit.bg_color = _pal("input_bg_normal")


func set_format_function(fn: Callable) -> void:
	format_fn = fn
	emit_ui_changed()


func _set_value_from_text(text: String) -> void:
	if _is_int_type and text.is_valid_int():
		value = text.to_int()
	elif text.is_valid_float():
		value = text.to_float()
	else:
		emit_ui_changed()


func _update_text() -> void:
	if format_fn:
		line_edit.text = format_fn.call(slider.value)
		return

	var eff_value: float = slider.value * percent_factor if as_percent else slider.value
	line_edit.text = format_string % eff_value


func _on_changed() -> void:
	_generate_styleboxes()

	line_edit.caret_blink = true
	line_edit.add_theme_color_override("selection_color", _pal("input_selection"))
	line_edit.add_theme_color_override("caret_color", _pal("input_caret"))

	_is_int_type = is_zero_approx(absf(step - int(step)))

	slider.step = step
	slider.min_value = min_value
	slider.max_value = max_value
	slider.value = value
	slider.editable = enabled

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)

	if setting_name == "":
		label.visible = false
	else:
		label.visible = true
		label.text = _format_text(setting_name)

	label.custom_minimum_size.x = setting_name_min_width
	# %HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	_update_text()
	line_edit.custom_minimum_size.x = setting_value_min_width

	if show_ticks and _is_int_type:
		slider.tick_count = int(max_value - min_value + 1)
	else:
		slider.tick_count = 0
