@tool
class_name SettingFile extends SettingBase

@export var value := "":
	set(p_value):
		value = p_value
		emit_value_changed()

@export var empty_text := "Open File...":
	set(p_value):
		empty_text = p_value
		emit_ui_changed()

@export var filters := "*.png, *.jpg, *.jpeg, *.hdr, *.ogv; Supported Filetypes":
	set(p_value):
		filters = p_value
		emit_ui_changed()

@export var edit_alpha := true:
	set(p_value):
		edit_alpha = p_value
		emit_ui_changed()

@export var show_html := true:
	set(p_value):
		show_html = p_value
		emit_ui_changed()

@export var panel_style_value: StyleBox = null:
	set(p_value):
		panel_style_value = p_value
		emit_ui_changed()

@onready var button: Button = %Button
@onready var file_dialog: FileDialog = %FileDialog
@onready var hbox: HBoxContainer = %HBoxContainer
@onready var panel_container: PanelContainer = %PanelContainer
@onready var label_name: Label = %LabelName


func _on_ready() -> void:
	button.pressed.connect(open_file_dialog)
	file_dialog.file_selected.connect(on_file_selected)


func on_file_selected(path: String) -> void:
	value = path


func open_file_dialog() -> void:
	# wrap callable as this one will be automatically disconnected
	# var callback := func(path: String) -> void: file_selected_fn.call(path)
	# %FileDialog.file_selected.connect(callback, CONNECT_ONE_SHOT)
	# %FileDialog.canceled.connect(func() -> void:
	# 	%FileDialog.files_selected.disconnect(callback)
	# , CONNECT_ONE_SHOT)
	file_dialog.show()


func _on_changed() -> void:
	if not is_inside_tree():
		await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)

	if setting_name == "":
		label_name.visible = false
		hbox.visible = false
	else:
		label_name.text = _format_text(setting_name)
		label_name.visible = true
		hbox.visible = true

	file_dialog.filters = [filters]

	panel_container.set("theme_override_styles/panel", panel_style_value)

	label_name.custom_minimum_size.x = setting_name_min_width
	hbox.set("theme_override_constants/separation", setting_name_indent)

	button.text = value.get_file() if value != "" else empty_text
