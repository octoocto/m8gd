extends Node

@warning_ignore("UNUSED_SIGNAL")
signal initialized(main: Main)

@warning_ignore("UNUSED_SIGNAL")
signal deinitialized()

@warning_ignore("UNUSED_SIGNAL")
signal scene_loaded(scene_path: String, scene: M8Scene)

@warning_ignore("UNUSED_SIGNAL")
signal profile_loaded(profile_name: String)
