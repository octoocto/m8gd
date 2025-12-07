@tool
class_name MainMenu
extends MenuBase

const ICON_LOAD := preload("res://assets/icon/Load.png")
const ICON_WARNING := preload("res://assets/icon/StatusWarning.png")

@onready var tab_container: TabContainer = %TabContainer
@onready var devices: MenuBase = %DeviceMenu
@onready var button_exit: Button = %ButtonExit


func _menu_init() -> void:
	button_exit.pressed.connect(func() -> void:
		main.quit()
	)
	%ButtonClose.pressed.connect(func() -> void:
		visible = false
	)
	for i in tab_container.get_tab_count():
		var tab := tab_container.get_tab_control(i)
		if tab.has_method("get_tab_title"):
			tab_container.set_tab_title(i, tab.get_tab_title())
	%DisplayRect.texture = main.m8_client.get_display()

	_init_menu_profiles()

##
## Setup the profile menu controls.
##
func _init_menu_profiles() -> void:
	var _setup_as_button := func() -> void:
		# ensure this function gets called after _setup_as_list
		await get_tree().process_frame
		%OptionProfiles.clear()
		%OptionProfiles.add_item("Load profile...")
		%OptionProfiles.set_item_icon(0, ICON_LOAD)

	var _setup_as_list := func() -> void:
		%OptionProfiles.clear()
		%OptionProfiles.add_item("<default>")

		for profile_name: String in main.list_profile_names():
			%OptionProfiles.add_item(profile_name)

		%OptionProfiles.select(-1)

	var _update_ui := func() -> void:
		if main.is_using_default_profile():
			%LineEditProfileName.text = "<default>"
			%LineEditProfileName.editable = false
			%LineEditProfileName.select_all_on_focus = false
			%ButtonProfileDelete.disabled = true
		else:
			%LineEditProfileName.text = main.get_current_profile_name()
			%LineEditProfileName.editable = true
			%LineEditProfileName.select_all_on_focus = true
			%ButtonProfileDelete.disabled = false
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

	%OptionProfiles.pressed.connect(_setup_as_list)
	%OptionProfiles.get_popup().popup_hide.connect(_setup_as_button)
	%OptionProfiles.item_selected.connect(func(index: int) -> void:
		if index == 0:
			_load_default_profile.call()
		elif index > 0:
			_load_profile.call(%OptionProfiles.get_item_text(index))

		_setup_as_button.call()
	)

	%LineEditProfileName.text_submitted.connect(func(new_text: String) -> void:
		main.rename_profile(new_text)
		%LineEditProfileName.release_focus()
	)

	%LineEditProfileName.focus_exited.connect(_update_ui)

	%ButtonProfileCreate.pressed.connect(func() -> void:
		_load_profile.call(main.create_new_profile())
	)

	%ButtonProfileReset.pressed.connect(func() -> void:
		main.reset_scene_to_default()
	)

	%ButtonProfileDelete.pressed.connect(func() -> void:
		main.delete_profile(main.get_current_profile_name())
		_update_ui.call()
	)
