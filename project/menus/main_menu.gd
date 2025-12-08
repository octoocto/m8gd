@tool
class_name MainMenu
extends MenuBase

const ICON_LOAD := preload("res://assets/icon/Load.png")
const ICON_WARNING := preload("res://assets/icon/StatusWarning.png")

@onready var tab_container: TabContainer = %TabContainer
@onready var devices: MenuBase = %DeviceMenu
@onready var button_exit: Button = %ButtonExit

@onready var button_close: Button = %ButtonClose

@onready var option_profiles: OptionButton = %OptionProfiles
@onready var line_edit_profile_name: LineEdit = %LineEditProfileName
@onready var button_profile_create: Button = %ButtonProfileCreate
@onready var button_profile_reset: Button = %ButtonProfileReset
@onready var button_profile_delete: Button = %ButtonProfileDelete

@onready var input_menu: InputMenu = %InputMenu

@onready var display_rect: TextureRect = %DisplayRect

func _menu_init() -> void:
	button_exit.pressed.connect(func() -> void:
		main.quit()
	)
	button_close.pressed.connect(func() -> void:
		visible = false
	)
	for i in tab_container.get_tab_count():
		var tab := tab_container.get_tab_control(i)
		if tab.has_method("get_tab_title"):
			tab_container.set_tab_title(i, tab.get_tab_title())
	display_rect.texture = main.m8_client.get_display()

	_init_menu_profiles()

##
## Setup the profile menu controls.
##
func _init_menu_profiles() -> void:
	var _setup_as_button := func() -> void:
		# ensure this function gets called after _setup_as_list
		await get_tree().process_frame
		option_profiles.clear()
		option_profiles.add_item("Load profile...")
		option_profiles.set_item_icon(0, ICON_LOAD)

	var _setup_as_list := func() -> void:
		option_profiles.clear()
		option_profiles.add_item("<default>")

		for profile_name: String in main.list_profile_names():
			option_profiles.add_item(profile_name)

		option_profiles.select(-1)

	var _update_ui := func() -> void:
		if main.is_using_default_profile():
			line_edit_profile_name.text = "<default>"
			line_edit_profile_name.editable = false
			line_edit_profile_name.select_all_on_focus = false
			button_profile_delete.disabled = true
		else:
			line_edit_profile_name.text = main.get_current_profile_name()
			line_edit_profile_name.editable = true
			line_edit_profile_name.select_all_on_focus = true
			button_profile_delete.disabled = false
		_setup_as_button.call()
		%InputMenu.refresh_profile_hotkeys()

	var _load_profile := func(profile_name: String) -> void:
		if main.load_profile(profile_name):
			_update_ui.call()

	var _load_default_profile := func() -> void:
		main.load_default_profile()
		_update_ui.call()

	Events.profile_loaded.connect(func(_profile_name: String) -> void:
		_update_ui.call()
	)

	_update_ui.call()

	option_profiles.pressed.connect(_setup_as_list)
	option_profiles.get_popup().popup_hide.connect(_setup_as_button)
	option_profiles.item_selected.connect(func(index: int) -> void:
		if index == 0:
			_load_default_profile.call()
		elif index > 0:
			_load_profile.call(option_profiles.get_item_text(index))

		_setup_as_button.call()
	)

	line_edit_profile_name.text_submitted.connect(func(new_text: String) -> void:
		main.rename_profile(new_text)
		line_edit_profile_name.release_focus()
	)

	line_edit_profile_name.focus_exited.connect(_update_ui)

	button_profile_create.pressed.connect(func() -> void:
		_load_profile.call(main.create_new_profile())
	)

	button_profile_reset.pressed.connect(func() -> void:
		main.reset_scene_to_default()
	)

	button_profile_delete.pressed.connect(func() -> void:
		main.delete_profile(main.get_current_profile_name())
		_update_ui.call()
	)
