@tool
extends MenuBase

const REBIND_COOLDOWN := 100 # ms until can rebind again

var is_key_rebinding := false
var last_rebind_time := 0.0
var key_rebind_callback: Callable

func get_tab_title() -> String:
	return "Input"

func _menu_init() -> void:
	%Setting_VirtualKeyboard.init_config_global(main, "virtual_keyboard_enabled", func(value: bool) -> void:
		main.m8_virtual_keyboard_enabled = value
	)

	get_tree().physics_frame.connect(func() -> void:
		%ButtonBindUp1.text = get_key_bind("key_up", 0)
		%ButtonBindUp2.text = get_key_bind("key_up", 1)
		%ButtonBindDown1.text = get_key_bind("key_down", 0)
		%ButtonBindDown2.text = get_key_bind("key_down", 1)
		%ButtonBindLeft1.text = get_key_bind("key_left", 0)
		%ButtonBindLeft2.text = get_key_bind("key_left", 1)
		%ButtonBindRight1.text = get_key_bind("key_right", 0)
		%ButtonBindRight2.text = get_key_bind("key_right", 1)
		%ButtonBindOpt1.text = get_key_bind("key_option", 0)
		%ButtonBindOpt2.text = get_key_bind("key_option", 1)
		%ButtonBindEdit1.text = get_key_bind("key_edit", 0)
		%ButtonBindEdit2.text = get_key_bind("key_edit", 1)
		%ButtonBindShift1.text = get_key_bind("key_shift", 0)
		%ButtonBindShift2.text = get_key_bind("key_shift", 1)
		%ButtonBindPlay1.text = get_key_bind("key_play", 0)
		%ButtonBindPlay2.text = get_key_bind("key_play", 1)
	)

	%ButtonBindUp1.button_down.connect(start_rebind_action.bind("key_up", 0))
	%ButtonBindUp2.button_down.connect(start_rebind_action.bind("key_up", 1))
	%ButtonBindDown1.button_down.connect(start_rebind_action.bind("key_down", 0))
	%ButtonBindDown2.button_down.connect(start_rebind_action.bind("key_down", 1))
	%ButtonBindLeft1.button_down.connect(start_rebind_action.bind("key_left", 0))
	%ButtonBindLeft2.button_down.connect(start_rebind_action.bind("key_left", 1))
	%ButtonBindRight1.button_down.connect(start_rebind_action.bind("key_right", 0))
	%ButtonBindRight2.button_down.connect(start_rebind_action.bind("key_right", 1))
	%ButtonBindOpt1.button_down.connect(start_rebind_action.bind("key_option", 0))
	%ButtonBindOpt2.button_down.connect(start_rebind_action.bind("key_option", 1))
	%ButtonBindEdit1.button_down.connect(start_rebind_action.bind("key_edit", 0))
	%ButtonBindEdit2.button_down.connect(start_rebind_action.bind("key_edit", 1))
	%ButtonBindShift1.button_down.connect(start_rebind_action.bind("key_shift", 0))
	%ButtonBindShift2.button_down.connect(start_rebind_action.bind("key_shift", 1))
	%ButtonBindPlay1.button_down.connect(start_rebind_action.bind("key_play", 0))
	%ButtonBindPlay2.button_down.connect(start_rebind_action.bind("key_play", 1))

	%ButtonResetBinds.button_down.connect(reset_key_rebinds.bind());

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
		_init_hotkey_node(control,
			func(event: InputEvent) -> void:
				main.config.set_overlay_hotkey(node_path, event),
			func() -> void:
				main.config.clear_overlay_hotkey(node_path)
		)
		_update_hotkey_node(control, main.config.get_overlay_hotkey(node_path))

func reset_key_rebinds() -> void:
	for action: String in [
		"key_up", "key_down", "key_left", "key_right",
		"key_shift", "key_play", "key_option", "key_edit"]:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ProjectSettings.get_setting("input/" + action).events[0])
	save_key_rebinds()
	print("keybindings reset to default")

func load_key_rebinds() -> void:
	for action: String in main.config.action_events.keys():
		var events: Array = main.config.action_events[action]
		assert(events is Array)
		for event: InputEvent in events:
			assert(event is InputEvent, "event is not InputEvent, found %s" % type_string(typeof(event)))
			InputMap.action_add_event(action, event)
	print("key bindings loaded from config")

func save_key_rebinds() -> void:
	for action: String in main.M8_ACTIONS:
		var events := InputMap.action_get_events(action)
		main.config.action_events[action] = events
	print("key bindings saved to config")

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

	%BindActionPopup.visible = true

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
	hotkey_node.get_node("ButtonBind").pressed.connect(func() -> void:
		start_rebind(func(e: InputEvent) -> void:
			rebind_fn.call(e)
			_update_hotkey_node(hotkey_node, e)
		)
	)
	hotkey_node.get_node("ButtonClear").pressed.connect(func() -> void:
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
	for child in %ProfileHotkeysContainer.get_children():
		if child != %ProfileHotkeyTemplate:
			child.queue_free()

	for profile_name: String in main.list_profile_names():
		var container: HBoxContainer = %ProfileHotkeyTemplate.duplicate()
		var event: Variant = main.config.get_profile_hotkey(profile_name)
		container.visible = true
		container.get_node("Label").text = profile_name
		_update_hotkey_node(container, event)
		%ProfileHotkeysContainer.add_child(container)

		_init_hotkey_node(container,
			func(e: InputEvent) -> void:
				main.config.set_profile_hotkey(profile_name, e)
				refresh_profile_hotkeys(),
			func() -> void:
				main.config.clear_profile_hotkey(profile_name)
				refresh_profile_hotkeys()
		)
