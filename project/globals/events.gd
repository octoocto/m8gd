@tool
extends Node

@warning_ignore("UNUSED_SIGNAL")
signal preinitialized(main: Main)

@warning_ignore("UNUSED_SIGNAL")
signal initialized(main: Main)

@warning_ignore("UNUSED_SIGNAL")
signal deinitialized

@warning_ignore("UNUSED_SIGNAL")
signal scene_loaded(scene_path: String, scene: M8Scene)

@warning_ignore("UNUSED_SIGNAL")
signal preset_loaded(preset_name: String)

@warning_ignore("UNUSED_SIGNAL")
signal setting_changed(setting: SettingBase, value: Variant)

## Emitted when either the window size changed or the scale changed.
@warning_ignore("UNUSED_SIGNAL")
signal window_modified

@warning_ignore("UNUSED_SIGNAL")
signal serial_device_connected

@warning_ignore("UNUSED_SIGNAL")
signal audio_device_connected

@warning_ignore("UNUSED_SIGNAL")
signal gui_mouse_entered(ui_element: UIBase)

@warning_ignore("UNUSED_SIGNAL")
signal gui_mouse_exited(ui_element: UIBase)

## Emitted when a key (on the connected M8) is pressed or released.
@warning_ignore("UNUSED_SIGNAL")
signal device_key_pressed(key: int, pressed: bool)

## Emitted when a property in the config for a profile changes.
@warning_ignore("UNUSED_SIGNAL")
signal config_preset_value_changed(
	profile_name: String, section: String, key: String, value: Variant
)
