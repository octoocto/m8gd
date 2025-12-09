extends Node

@warning_ignore("UNUSED_SIGNAL")
signal initialized(main: Main)

@warning_ignore("UNUSED_SIGNAL")
signal deinitialized()

@warning_ignore("UNUSED_SIGNAL")
signal scene_loaded(scene_path: String, scene: M8Scene)

@warning_ignore("UNUSED_SIGNAL")
signal profile_loaded(profile_name: String)

@warning_ignore("UNUSED_SIGNAL")
signal setting_changed(setting: SettingBase, value: Variant)

## Emitted when either the window size changed or the scale changed.
@warning_ignore("UNUSED_SIGNAL")
signal window_modified()
