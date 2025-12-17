@tool
class_name InputMenu
extends MenuBase

signal keybinds_saved

const REBIND_COOLDOWN := 100  # ms until can rebind again

@onready var s_virtual_keyboard: SettingBool = %Setting_VirtualKeyboard

@onready var bind_up_1: Button = %ButtonBindUp1
@onready var bind_up_2: Button = %ButtonBindUp2
@onready var bind_down_1: Button = %ButtonBindDown1
@onready var bind_down_2: Button = %ButtonBindDown2
@onready var bind_left_1: Button = %ButtonBindLeft1
@onready var bind_left_2: Button = %ButtonBindLeft2
@onready var bind_right_1: Button = %ButtonBindRight1
@onready var bind_right_2: Button = %ButtonBindRight2
@onready var bind_opt_1: Button = %ButtonBindOpt1
@onready var bind_opt_2: Button = %ButtonBindOpt2
@onready var bind_edit_1: Button = %ButtonBindEdit1
@onready var bind_edit_2: Button = %ButtonBindEdit2
@onready var bind_shift_1: Button = %ButtonBindShift1
@onready var bind_shift_2: Button = %ButtonBindShift2
@onready var bind_play_1: Button = %ButtonBindPlay1
@onready var bind_play_2: Button = %ButtonBindPlay2

@onready var bind_action_popup: Control = %BindActionPopup

@onready var button_reset_binds: UIButton = %ButtonResetBinds

@onready var profile_hotkey_template: HBoxContainer = %ProfileHotkeyTemplate
@onready var profile_hotkeys_container: VBoxContainer = %ProfileHotkeysContainer

var is_key_rebinding := false
var last_rebind_time := 0.0
var key_rebind_callback: Callable


func get_tab_title() -> String:
	return "Input"


func _on_menu_init() -> void:
	%Setting_VirtualKeyboard.setting_connect_global(
		"virtual_keyboard_enabled",
		func(value: bool) -> void: main.m8_virtual_keyboard_enabled = value
	)

	keybinds_saved.connect(
		func() -> void:
			_update_keybind_buttons("key_up", bind_up_1, bind_up_2)
			_update_keybind_buttons("key_down", bind_down_1, bind_down_2)
			_update_keybind_buttons("key_left", bind_left_1, bind_left_2)
			_update_keybind_buttons("key_right", bind_right_1, bind_right_2)
			_update_keybind_buttons("key_option", bind_opt_1, bind_opt_2)
			_update_keybind_buttons("key_edit", bind_edit_1, bind_edit_2)
			_update_keybind_buttons("key_shift", bind_shift_1, bind_shift_2)
			_update_keybind_buttons("key_play", bind_play_1, bind_play_2)
	)
	keybinds_saved.emit()

	_connect_keybind_buttons("key_up", bind_up_1, bind_up_2)
	_connect_keybind_buttons("key_down", bind_down_1, bind_down_2)
	_connect_keybind_buttons("key_left", bind_left_1, bind_left_2)
	_connect_keybind_buttons("key_right", bind_right_1, bind_right_2)
	_connect_keybind_buttons("key_option", bind_opt_1, bind_opt_2)
	_connect_keybind_buttons("key_edit", bind_edit_1, bind_edit_2)
	_connect_keybind_buttons("key_shift", bind_shift_1, bind_shift_2)
	_connect_keybind_buttons("key_play", bind_play_1, bind_play_2)

	button_reset_binds.pressed.connect(reset_key_rebinds.bind())

	load_key_rebinds()

	# bind overlay hotkeys
	for tuple: Array in [
		[%OverlayHotkeyWaveform, &"OverlayAudioWaveform"],
		[%OverlayHotkeySpectrum, &"OverlayAudioSpectrum"],
		[%OverlayHotkeyDisplay, &"OverlayDisplayPanel"],
		[%OverlayHotkeyKey, &"KeyOverlay"],
	]:
		var control: Control = tuple[0]
		var node_path: String = tuple[1]
		_init_hotkey_node(
			control,
			func(event: InputEvent) -> void: main.config.set_overlay_hotkey(node_path, event),
			func() -> void: main.config.clear_overlay_hotkey(node_path)
		)
		_update_hotkey_node(control, main.config.get_overlay_hotkey(node_path))


func _update_keybind_buttons(action: String, bind_1: Button, bind_2: Button) -> void:
	bind_1.text = get_key_bind(action, 0)
	bind_2.text = get_key_bind(action, 1)


func _connect_keybind_buttons(action: String, bind_1: Button, bind_2: Button) -> void:
	bind_1.button_down.connect(start_rebind_action.bind(action, 0))
	bind_2.button_down.connect(start_rebind_action.bind(action, 1))


func reset_key_rebinds() -> void:
	for action: String in [
		"key_up",
		"key_down",
		"key_left",
		"key_right",
		"key_shift",
		"key_play",
		"key_option",
		"key_edit"
	]:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ProjectSettings.get_setting("input/" + action).events[0])
	save_key_rebinds()
	Log.ln("keybinds reset to default")


func load_key_rebinds() -> void:
	for action: String in main.config.action_events.keys():
		var events: Array = main.config.action_events[action]
		assert(events is Array)
		for event: InputEvent in events:
			assert(
				event is InputEvent,
				"event is not InputEvent, found %s" % type_string(typeof(event))
			)
			InputMap.action_add_event(action, event)
	Log.ln("keybinds loaded from config")


func save_key_rebinds() -> void:
	for action: String in main.M8_ACTIONS:
		var events := InputMap.action_get_events(action)
		main.config.action_events[action] = events
	keybinds_saved.emit()
	Log.ln("keybinds saved to config")


func get_key_bind(action: String, index: int) -> String:
	var events := InputMap.action_get_events(action)
	var event: InputEvent
	if index == 0 and events.size() == 0:
		event = ProjectSettings.get_setting("input/" + action).events[0]
	elif index < events.size():
		event = events[index]
	else:
		return "----"

	return event.as_text()


##
## Open the rebind prompt. The callback function will be called
## with the InputEvent as the first argument.
##
func start_rebind(fn: Callable) -> void:
	# prevent opening rebind prompt too fast
	if Time.get_ticks_msec() - last_rebind_time < REBIND_COOLDOWN:
		return

	bind_action_popup.show()
	key_rebind_callback = fn
	is_key_rebinding = true


##
## Open the rebind prompt to rebind an action.
## The index chooses which InputEvent to rebind.
##
func start_rebind_action(action: String, index: int = 0) -> void:
	var callback := func(event: InputEvent) -> void:
		var events := InputMap.action_get_events(action)

		if events.size() <= index:
			events.append(event)
		else:
			assert(index < events.size())
			events[index] = event

		# clear all events and add modified ones
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)

		Input.action_release(action)
		save_key_rebinds()

	start_rebind(callback)


##
## Handles input while the rebind prompt is open. Called by [_input()].
##
func _handle_input_rebind(event: InputEvent) -> void:
	if is_key_rebinding:
		if event is InputEventKey and event.pressed:
			if event.keycode != KEY_ESCAPE:
				key_rebind_callback.call(event)
			end_rebind()
		if event is InputEventJoypadButton and event.pressed:
			key_rebind_callback.call(event)
			end_rebind()
		return


func end_rebind() -> void:
	is_key_rebinding = false
	last_rebind_time = Time.get_ticks_msec()
	%BindActionPopup.visible = false


func _input(event: InputEvent) -> void:
	_handle_input_rebind(event)


##
## Initialize a hotkey node (found in Controls tab, for profile and overlay hotkeys).
##
## [rebind_fn] is called when the user wants to rebind, and takes the InputEvent as an argument.
## [clear_fn] is called when the user clears the binding.
##
func _init_hotkey_node(hotkey_node: Control, rebind_fn: Callable, clear_fn: Callable) -> void:
	hotkey_node.get_node("ButtonBind").pressed.connect(
		func() -> void:
			start_rebind(
				func(e: InputEvent) -> void:
					rebind_fn.call(e)
					_update_hotkey_node(hotkey_node, e)
			)
	)
	hotkey_node.get_node("ButtonClear").pressed.connect(
		func() -> void:
			clear_fn.call()
			_update_hotkey_node(hotkey_node, null)
	)


func _update_hotkey_node(hotkey_node: Control, event: InputEvent) -> void:
	if event:
		hotkey_node.get_node("ButtonBind").text = event.as_text()
	else:
		hotkey_node.get_node("ButtonBind").text = "---"


##
## Recreate the profile hotkey UI with the current list of profiles and
## their saved hotkey bindings.
##
func refresh_profile_hotkeys() -> void:
	if not main:
		return

	for child in profile_hotkeys_container.get_children():
		if child != profile_hotkey_template:
			child.queue_free()

	for profile_name: String in main.list_profile_names():
		var container: HBoxContainer = profile_hotkey_template.duplicate()
		var event: Variant = main.config.get_profile_hotkey(profile_name)
		container.visible = true
		container.get_node("Label").text = profile_name
		_update_hotkey_node(container, event)
		profile_hotkeys_container.add_child(container)

		_init_hotkey_node(
			container,
			func(e: InputEvent) -> void:
				main.config.set_profile_hotkey(profile_name, e)
				refresh_profile_hotkeys(),
			func() -> void:
				main.config.clear_profile_hotkey(profile_name)
				refresh_profile_hotkeys()
		)
