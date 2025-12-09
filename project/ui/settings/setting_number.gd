@tool
class_name SettingNumber
extends SettingBase

var _is_int_type := false

@export var setting_value_min_width := 40:
	set(p_value):
		setting_value_min_width = p_value
		_on_changed()

@export var min_value := 0.0:
	set(value):
		min_value = value
		_on_changed()

@export var max_value := 100.0:
	set(value):
		max_value = value
		_on_changed()

@export var step := 1.0:
	set(value):
		step = value
		_on_changed()

@export var value := 0.0:
	set(p_value):
		value = p_value
		await _on_changed()
		value = %HSlider.value
		emit_changed()

@export var show_ticks := false:
	set(p_value):
		show_ticks = p_value
		_on_changed()

@export var as_percent := false:
	set(p_value):
		as_percent = p_value
		_on_changed()

@export var percent_factor := 100.0:
	set(p_value):
		percent_factor = p_value
		_on_changed()

@export var format_string := "%.2f":
	set(p_value):
		format_string = p_value
		_on_changed()

var format_fn: Callable


func _on_ready() -> void:
	%HSlider.value_changed.connect(func(p_value: float) -> void: value = p_value)
	%LineEdit.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					%LineEdit.accept_event()
					if _is_int_type:
						%LineEdit.text = "%d" % %HSlider.value
					else:
						%LineEdit.text = "%.2f" % %HSlider.value
					%LineEdit.select_all()
	)

	%LineEdit.text_submitted.connect(
		func(text: String) -> void:
			%LineEdit.deselect()
			%LineEdit.release_focus()
			_set_value_from_text(text)
	)


func set_format_function(fn: Callable) -> void:
	format_fn = fn
	_on_changed()


func _set_value_from_text(text: String) -> void:
	if _is_int_type and text.is_valid_int():
		value = text.to_int()
	elif text.is_valid_float():
		value = text.to_float()
	else:
		_on_changed()


func _update_text() -> void:
	if format_fn:
		%LineEdit.text = format_fn.call(%HSlider.value)
		return

	var eff_value: float = %HSlider.value * percent_factor if as_percent else %HSlider.value
	%LineEdit.text = format_string % eff_value


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	_is_int_type = is_zero_approx(abs(step - int(step)))

	%HSlider.step = step
	%HSlider.min_value = min_value
	%HSlider.max_value = max_value
	%HSlider.value = value
	%HSlider.editable = enabled

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)

	if setting_name == "":
		%LabelName.visible = false
	else:
		%LabelName.visible = true
		%LabelName.text = setting_name

	%LabelName.custom_minimum_size.x = setting_name_min_width
	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	_update_text()
	%LineEdit.custom_minimum_size.x = setting_value_min_width

	if show_ticks and _is_int_type:
		%HSlider.tick_count = max_value - min_value + 1
	else:
		%HSlider.tick_count = 0
