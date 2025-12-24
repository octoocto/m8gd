@tool
extends MenuBase

# @onready var option_profiles: UIOptionButton = %OptionProfiles
# @onready var line_edit_profile_name: LineEdit = %LineEditProfileName
# @onready var label_profile_name: UILabel2 = %LabelProfileName
@onready var s_name: SettingString = %SName

@onready var button_save: UIButton = %ButtonSave
@onready var button_load: UIButton = %ButtonLoad
@onready var button_new: UIButton = %ButtonNew
@onready var button_delete: UIButton = %ButtonDelete
@onready var button_print: UIButton = %ButtonPrint

@onready var button_cancel_loader: UIButton = %ButtonCancelLoader

@onready var label_status: UILabel = %LabelStatus

@onready var cont_config: VBoxContainer = %ConfigContainer
@onready var cont_loader: VBoxContainer = %LoaderContainer
@onready var cont_loader_list: VBoxContainer = %LoaderListContainer

var config: M8Config

var confirm_overwrite := false
var confirm_delete := false


func _on_menu_init() -> void:
	config = main.config

	Events.preset_loaded.connect(
		func(_profile_name: String) -> void:
			s_name.set_value_no_signal(config.current_preset_name)
			_on_changed()
	)
	s_name.value_changed.connect(func(_name: String) -> void: _on_changed())

	_on_changed()

	button_new.pressed.connect(
		func() -> void:
			config.preset_load_new()
			label_status.text = "Loaded default preset."
	)
	button_save.pressed.connect(
		func() -> void:
			if s_name.value == "":
				label_status.text = "Preset name cannot be empty."
				return
			if config.preset_exists(s_name.value) and not confirm_overwrite:
				label_status.text = (
					"Preset '%s' already exists.\nPress Save again to overwrite." % s_name.value
				)
				button_save.text = "Really?"
				confirm_overwrite = true
				return
			var path := config.preset_save(s_name.value, true)
			label_status.text = "Preset saved to:\n%s" % path
			_on_changed()
	)
	button_delete.pressed.connect(
		func() -> void:
			if not config.current_preset_exists():
				return
			if not confirm_delete:
				label_status.text = (
					"Preset '%s' will be deleted.\nPress Delete again to confirm."
					% config.current_preset_name
				)
				confirm_delete = true
				button_delete.text = "Really?"
				return
			var path := config._preset_get_path(config.current_preset_name)
			label_status.text = "Preset deleted:\n%s" % path
			config.preset_delete_current()
			_on_changed()
	)
	button_load.pressed.connect(
		func() -> void:
			_refresh_loader_list()
			_show_loader()
	)
	button_cancel_loader.pressed.connect(func() -> void: _show_config())
	button_print.pressed.connect(func() -> void: print(config.current_preset.encode_to_text()))


func _on_changed() -> void:
	confirm_overwrite = false
	confirm_delete = false

	button_save.text = "Save"
	button_delete.text = "Delete"
	button_save.enabled = s_name.value != ""
	button_delete.enabled = config.current_preset_exists()

	main.menu.menu_input.refresh_hotkeys_presets()


func menu_show() -> void:
	super()
	_show_config()


func _show_config() -> void:
	cont_config.visible = true
	cont_loader.visible = false


func _show_loader() -> void:
	cont_config.visible = false
	cont_loader.visible = true


func _refresh_loader_list() -> void:
	for c in cont_loader_list.get_children():
		c.queue_free()

	for preset_name: String in config.list_preset_names():
		var button: UIButton = MenuUtils.UI_BUTTON.instantiate()
		var preset_path := config._preset_get_path(preset_name)
		button.text = preset_name
		button.inline = true
		button.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.hint_text = preset_path
		button.pressed.connect(
			func() -> void:
				config.preset_load(preset_name)
				s_name.value = preset_name
				label_status.text = "Loaded preset:\n%s" % preset_path
				_show_config()
		)
		cont_loader_list.add_child(button)
