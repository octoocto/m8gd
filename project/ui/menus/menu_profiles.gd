@tool
extends MenuBase

@onready var option_profiles: UIOptionButton = %OptionProfiles
# @onready var line_edit_profile_name: LineEdit = %LineEditProfileName
# @onready var label_profile_name: UILabel2 = %LabelProfileName
@onready var s_profile_name: SettingString = %SettingProfileName
@onready var button_profile_create: UIButton = %ButtonProfileCreate
@onready var button_profile_reset: UIButton = %ButtonProfileReset
@onready var button_profile_delete: UIButton = %ButtonProfileDelete


func _on_menu_init() -> void:
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
			s_profile_name.set_value_no_signal("<default>")
			s_profile_name.enabled = false
			button_profile_delete.enabled = false
		else:
			s_profile_name.set_value_no_signal(main.get_current_profile_name())
			s_profile_name.enabled = true
			button_profile_delete.enabled = true
		_setup_as_button.call()
		main.menu.menu_input.refresh_profile_hotkeys()

	var _load_profile := func(profile_name: String) -> void:
		if main.load_profile(profile_name):
			_update_ui.call()

	var _load_default_profile := func() -> void:
		main.load_default_profile()
		_update_ui.call()

	Events.profile_loaded.connect(func(_profile_name: String) -> void: _update_ui.call())

	_update_ui.call()

	option_profiles.pressed.connect(_setup_as_list)
	option_profiles.get_popup().popup_hide.connect(_setup_as_button)
	option_profiles.item_selected.connect(
		func(index: int) -> void:
			if index == 0:
				_load_default_profile.call()
			elif index > 0:
				_load_profile.call(option_profiles.get_item_text(index))

			_setup_as_button.call()
	)

	# line_edit_profile_name.text_submitted.connect(
	# 	func(new_text: String) -> void:
	# 		main.rename_profile(new_text)
	# 		line_edit_profile_name.release_focus()
	# )
	#
	# line_edit_profile_name.focus_exited.connect(_update_ui)

	button_profile_create.pressed.connect(
		func() -> void: _load_profile.call(main.create_new_profile())
	)

	button_profile_reset.pressed.connect(func() -> void: main.reset_scene_to_default())

	button_profile_delete.pressed.connect(
		func() -> void:
			main.delete_profile(main.get_current_profile_name())
			_update_ui.call()
	)
