@tool
class_name SettingFile extends SettingBase

@export var value := "":
	set(p_value):
		value = p_value
		await _on_changed()
		emit_changed()

@export var empty_text := "Open File...":
	set(p_value):
		empty_text = p_value
		_on_changed()

@export var filters := "*.png, *.jpg, *.jpeg, *.hdr, *.ogv; Supported Filetypes":
	set(p_value):
		filters = p_value
		_on_changed()

@export var edit_alpha := true:
	set(p_value):
		edit_alpha = p_value
		_on_changed()

@export var show_html := true:
	set(p_value):
		show_html = p_value
		_on_changed()

@export var panel_style_value: StyleBox = null:
	set(p_value):
		panel_style_value = p_value
		_on_changed()


func _on_ready() -> void:
	%Button.pressed.connect(open_file_dialog)
	%FileDialog.file_selected.connect(on_file_selected)


func on_file_selected(path: String) -> void:
	value = path


func open_file_dialog() -> void:
	# wrap callable as this one will be automatically disconnected
	# var callback := func(path: String) -> void: file_selected_fn.call(path)
	# %FileDialog.file_selected.connect(callback, CONNECT_ONE_SHOT)
	# %FileDialog.canceled.connect(func() -> void:
	# 	%FileDialog.files_selected.disconnect(callback)
	# , CONNECT_ONE_SHOT)
	%FileDialog.show()


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)

	if setting_name == "":
		%LabelName.visible = false
		%HBoxContainer.visible = false
	else:
		%LabelName.text = setting_name
		%LabelName.visible = true
		%HBoxContainer.visible = true

	%FileDialog.filters = [filters]

	%PanelContainer.set("theme_override_styles/panel", panel_style_value)

	%LabelName.custom_minimum_size.x = setting_name_min_width
	%HBoxContainer.set("theme_override_constants/separation", setting_name_indent)

	%Button.text = value.get_file() if value != "" else empty_text


func get_color_picker() -> ColorPicker:
	return %ColorPickerButton.get_picker()
