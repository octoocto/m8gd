class_name M8Config extends Resource

const CONFIG_FILE_PATH := "user://config.res"
const PRESETS_DIR_PATH := "user://presets/"

const DEFAULT_SCENE_PATH: String = "res://scenes/floating_scene.tscn"
const DEFAULT_COLOR_KEYCAP := Color.BLACK
const DEFAULT_COLOR_BODY := Color.BLACK

const CONFIG_KEY_OVERLAY = "overlay.%s.%s"
const CONFIG_KEY_CAMERA = "camera.%s"
const CONFIG_KEY_SHADER = "filter.%s.shader.%s"
const CONFIG_KEY_SCENE_CUSTOM = "custom.%s"

const SECTION_PRESET := "preset"
const SECTION_COLORS := "colors"
const SECTION_SCENE := "scene"
const SECTION_SHADER := "shader"
const SECTION_OVERLAY := "overlay"
const SECTION_MODEL := "model"

const SECTIONS := [
	SECTION_PRESET,
	SECTION_COLORS,
	SECTION_SCENE,
	SECTION_SHADER,
	SECTION_OVERLAY,
	SECTION_MODEL,
]

var version: int = 0

# general settings
@export var splash_show := true

# scene settings
# @export var scene_parameters := {} # Dictionary[String, Dictionary]
# @export var last_scene_path: String # path to last scene opened

## The name of the current or last loaded preset.
## If not empty, the preset with this name will be loaded on startup.
@export var current_preset_name: String = ""

## The encoded string of the last loaded preset.
@export var current_preset_autosave: String = ""

@export var hotkeys_presets: Dictionary[StringName, InputEvent] = {}
@export var hotkeys_overlays: Dictionary[StringName, InputEvent] = {}

# video settings
@export var fullscreen := false
@export var window_borderless := false
@export var window_width := 960
@export var window_height := 720
@export var always_on_top := false
@export var ui_scale := 0.0
@export var ui_text_case := 0  # 0 = normal, 1 = uppercase, 2 = lowercase
@export var vsync := 1
@export var fps_cap := 8  # see %Setting_Vsync for items

# graphical settings
@export var msaa := 0
@export var taa := false
@export var dof_bokeh_shape := 1
@export var dof_blur_quality := 2
@export var scale_mode := 0
@export var render_scale := 1.0
@export var fsr_sharpness := 0.9

# visualizer settings
@export var audio_analyzer_enabled := true
@export var audio_analyzer_min_freq: int = 800
@export var audio_analyzer_max_freq: int = 1200
@export var audio_to_brightness := 0.1
@export var audio_to_aberration := 0.02

# audio settings
@export var audio_handler := 1  # 0 = Godot, 1 = SDL
@export var volume := 0.8

# misc settings
@export var debug_info := false

# contains key bindings
@export var action_events := {}  # Dictionary[String, Array]
@export var virtual_keyboard_enabled := false

var current_preset := ConfigFile.new()


static func _print(message: String) -> void:
	Log.ln("[color=green]%s[/color]" % message)


## Returns true if this script contains a default for the given setting.
##
func assert_setting_exists(setting: String) -> void:
	assert(
		get(setting) != null, "Setting %s does not exist, must define in config_file.gd" % setting
	)


func save() -> void:
	current_preset_autosave = current_preset.encode_to_text()

	var error := ResourceSaver.save(self, CONFIG_FILE_PATH)
	if error == OK:
		_print("config saved")
	else:
		printerr("failed to save config: %s" % error_string(error))


static func load() -> M8Config:
	var config: M8Config = null

	if FileAccess.file_exists(CONFIG_FILE_PATH):
		config = ResourceLoader.load(CONFIG_FILE_PATH)
		if config is M8Config:
			_print("loaded config from file")
		else:
			_print("unable to load config from file. creating new config")
	else:
		config = M8Config.new()
		_print("creating new config")

	if config.current_preset_autosave != "":
		config.current_preset.parse(config.current_preset_autosave)
		_print("loaded preset from autosave")
	elif config.current_preset_name != "":
		config.preset_load(config.current_preset_name)

	return config


##
## Get the current scene path according to the current preset and
## the current scene in the preset.
##
## Intended to be used by the main function to load the initial scene.
##
func get_current_scene_path() -> String:
	var scene_path: String = get_value(SECTION_PRESET, "scene", DEFAULT_SCENE_PATH)
	assert(scene_path != "", "current scene path cannot be empty")
	return scene_path


func list_preset_names() -> PackedStringArray:
	var dir := DirAccess.open(PRESETS_DIR_PATH)
	if dir == null:
		_print("failed to list presets: %s" % error_string(DirAccess.get_open_error()))
		return PackedStringArray()

	var array := (
		Array(dir.get_files())
		. filter(func(f: String) -> bool: return f.get_extension().to_lower() == "ini")
		. map(func(f: String) -> String: return f.get_file().get_basename())
	)

	_print("found %d presets" % array.size())
	return PackedStringArray(array)


func current_preset_exists() -> bool:
	return preset_exists(current_preset_name)


func preset_exists(preset_name: String) -> bool:
	if preset_name == "":
		return false
	var preset_path := _preset_get_path(preset_name)
	return FileAccess.file_exists(preset_path)


##
## Save the current preset.
##
func preset_save(preset_name: String, overwrite := false) -> String:
	preset_name = _validate_preset_name(preset_name)
	assert(preset_name != "", "preset name cannot be empty")

	if preset_exists(preset_name) and !overwrite:
		assert(false, "preset '%s' already exists" % preset_name)

	# make sure presets directory exists
	if not DirAccess.dir_exists_absolute(PRESETS_DIR_PATH):
		DirAccess.make_dir_absolute(PRESETS_DIR_PATH)
		_print("created presets directory: %s" % PRESETS_DIR_PATH)

	var path := _preset_get_path(preset_name)

	current_preset.save(path)
	current_preset_name = preset_name
	_print("saved preset: %s" % preset_name)
	return path


##
## Loads a preset.
##
## If [preset_name] is empty, loads an empty preset (equivalent to making a new preset).
##
func preset_load(preset_name: String) -> void:
	if preset_name != "":
		preset_name = _validate_preset_name(preset_name)
		assert(preset_exists(preset_name), "preset '%s' does not exist" % preset_name)

	current_preset = ConfigFile.new()
	current_preset.set_value(SECTION_PRESET, "scene", DEFAULT_SCENE_PATH)
	current_preset_name = preset_name

	if current_preset_name != "":
		var res := current_preset.load(_preset_get_path(current_preset_name))
		assert(
			res == OK, "failed to load preset '%s': %s" % [current_preset_name, error_string(res)]
		)

	_emit_preset_loaded()


func preset_load_last() -> void:
	if current_preset.get_sections().size() > 0:
		# looks like a preset is already loaded, so just emit the signal
		_emit_preset_loaded()
		return

	preset_load(current_preset_name)


func preset_load_new() -> void:
	preset_load("")


##
## Delete a preset.
##
## If the deleted preset is the current preset, this will also load a new empty preset.
##
func preset_delete(preset_name: String) -> void:
	preset_name = _validate_preset_name(preset_name)
	assert(preset_exists(preset_name), "preset '%s' does not exist" % _get_preset_name(preset_name))
	DirAccess.remove_absolute(_preset_get_path(preset_name))
	_print("deleted preset: %s" % [preset_name])
	if preset_name == current_preset_name:
		preset_load_new()


func preset_delete_current() -> void:
	preset_delete(current_preset_name)


func clear_scene_parameters(scene: M8Scene) -> void:
	var section := SECTION_SCENE % _validate_preset_key(scene.scene_file_path)
	if not current_preset.has_section(section):
		current_preset.erase_section(section)
		_print("erased section: %s" % section)


##
## Set a value in the current preset.
##
func set_value(section: String, key: String, value: Variant) -> void:
	section = _validate_preset_section(section)
	key = _validate_preset_key(key)

	# check if the value exists first to avoid an error
	var exists := current_preset.has_section_key(section, key)
	var last_value: Variant = null
	if exists:
		last_value = current_preset.get_value(section, key)

	if last_value != value:
		if last_value == null:
			_print("new preset value: [%s] %s = %s" % [section, key, value])
		else:
			_print("set preset value: [%s] %s = %s" % [section, key, value])
		current_preset.set_value(section, key, value)
		Events.config_preset_value_changed.emit(current_preset_name, section, key, value)


##
## Set a global config setting.
##
## This is equivalent to setting the exported variable in this resource directly.
##
func set_global_value(key: String, value: Variant) -> void:
	assert(key in self)
	if get(key) != value:
		set(key, value)
		_print("set config value: %s = %s" % [key, value])


##
## Get a value from the current preset.
##
func get_value(section: String, key: String, default: Variant) -> Variant:
	section = _validate_preset_section(section)
	key = _validate_preset_key(key)
	return current_preset.get_value(section, key, default)
	# var value: Variant = current_preset.get_value(section, key, default)
	# _print("GET preset prop: %s, value = %s" % [propname, props[propname]])
	# return value


##
## Get a global config setting.
##
func get_global_value(key: String) -> Variant:
	assert(key in self)
	var value: Variant = get(key)
	# _print("GET global prop: %s, value = %s" % [key, value])
	return value


##
## Set the current scene for the current preset.
##
## Note that this function just sets the internal config variable and
## no actual loading is done.
##
func set_scene(scene: M8Scene) -> void:
	assert(scene != null)
	set_value(SECTION_PRESET, "scene", scene.scene_file_path)


##
## Get a scene property for the current preset and current scene.
## If this property doesn't exist, set it to the value from [default].
##
func get_value_scene(scene: M8Scene, key: String, default: Variant) -> Variant:
	var section := "%s/%s" % [SECTION_SCENE, _validate_preset_key(scene.scene_file_path)]
	return get_value(section, key, default)


##
## Set a scene property for the current preset and current scene.
##
func set_value_scene(scene: M8Scene, key: String, value: Variant) -> void:
	var section := "%s/%s" % [SECTION_SCENE, _validate_preset_key(scene.scene_file_path)]
	return set_value(section, key, value)


func get_value_overlay(overlay: Control, key: String, default: Variant) -> Variant:
	var section := "%s/%s" % [SECTION_OVERLAY, _validate_preset_key(overlay.name)]
	if default == null:
		default = overlay.get(key)
	return get_value(section, key, default)


func set_value_overlay(overlay: Control, key: String, value: Variant) -> void:
	var section := "%s/%s" % [SECTION_OVERLAY, _validate_preset_key(overlay.name)]
	overlay.set(key, value)
	set_value(section, key, value)


func get_value_overlay_global(key: String, default: Variant) -> Variant:
	var section := SECTION_OVERLAY
	return get_value(section, key, default)


func set_value_overlay_global(key: String, value: Variant) -> void:
	var section := SECTION_OVERLAY
	set_value(section, key, value)


func set_value_shader(shader_rect: ShaderRect, key: String, value: Variant) -> void:
	var section := "%s/%s" % [SECTION_SHADER, _validate_preset_key(shader_rect.name)]
	set_value(section, key, value)


func get_value_shader(shader_rect: ShaderRect, key: String, default: Variant) -> Variant:
	var section := "%s/%s" % [SECTION_SHADER, _validate_preset_key(shader_rect.name)]
	return get_value(section, key, default)


func get_value_shader_global(key: String, default: Variant) -> Variant:
	var section := SECTION_SHADER
	return get_value(section, key, default)


func set_value_shader_global(key: String, value: Variant) -> void:
	var section := SECTION_SHADER
	set_value(section, key, value)


func set_value_model(key: String, value: Variant) -> void:
	set_value(SECTION_MODEL, key, value)


func get_value_model(key: String, default: Variant) -> Variant:
	return get_value(SECTION_MODEL, key, default)


func get_color(key: String) -> Color:
	return get_value(SECTION_COLORS, key, Color.WHITE)


func set_color(key: String, color: Color) -> void:
	set_value(SECTION_COLORS, key, color)


##
## Set a preset's hotkey to an [InputEvent].
##
func preset_set_hotkey(profile_name: String, event: InputEvent) -> void:
	if event:
		hotkeys_presets[profile_name] = event
		_print("set preset hotkey: %s -> %s" % [event.as_text(), profile_name])


##
## Returns a preset's hotkey ([InputEvent]). If the preset does not have a hotkey,
## returns [null].
##
func preset_get_hotkey(profile_name: String) -> Variant:
	return hotkeys_presets.get(profile_name)


func preset_delete_hotkey(profile_name: String) -> void:
	hotkeys_presets.erase(profile_name)
	_print("cleared preset hotkey for: %s" % profile_name)


func set_overlay_hotkey(overlay_node_path: String, event: InputEvent) -> void:
	if event:
		hotkeys_overlays[overlay_node_path] = event
		_print("set overlay hotkey: %s -> %s" % [event.as_text(), overlay_node_path])


func get_overlay_hotkey(overlay_node_path: String) -> Variant:
	return hotkeys_overlays.get(overlay_node_path)


func clear_overlay_hotkey(overlay_node_path: String) -> void:
	hotkeys_presets.erase(overlay_node_path)
	_print("cleared overlay hotkey for: %s" % overlay_node_path)


func find_profile_name_from_hotkey(event: InputEvent) -> String:
	for key: String in hotkeys_presets.keys():
		if event.is_match(hotkeys_presets[key]):
			return key
	return ""


func find_overlay_node_path_from_hotkey(event: InputEvent) -> String:
	for key: String in hotkeys_overlays.keys():
		if event.is_match(hotkeys_overlays[key]):
			return key
	return ""


const KEY_COLOR_HIGHLIGHT_PREFIX: StringName = "hl_color_"
const KEY_COLOR_HIGHLIGHT_DIR: StringName = KEY_COLOR_HIGHLIGHT_PREFIX + "directional"
const KEY_COLOR_HIGHLIGHT_SHIFT: StringName = KEY_COLOR_HIGHLIGHT_PREFIX + "shift"
const KEY_COLOR_HIGHLIGHT_PLAY: StringName = KEY_COLOR_HIGHLIGHT_PREFIX + "play"
const KEY_COLOR_HIGHLIGHT_OPTION: StringName = KEY_COLOR_HIGHLIGHT_PREFIX + "option"
const KEY_COLOR_HIGHLIGHT_EDIT: StringName = KEY_COLOR_HIGHLIGHT_PREFIX + "edit"


func get_color_highlight(key: String) -> Color:
	assert(
		(
			key
			in [
				KEY_COLOR_HIGHLIGHT_DIR,
				KEY_COLOR_HIGHLIGHT_SHIFT,
				KEY_COLOR_HIGHLIGHT_PLAY,
				KEY_COLOR_HIGHLIGHT_OPTION,
				KEY_COLOR_HIGHLIGHT_EDIT,
			]
		)
	)
	return get_value(SECTION_COLORS, key, Color.WHITE)


func _get_preset_name(preset_name: String) -> String:
	if preset_name == "":
		return "<unnamed preset>"
	return preset_name


func _validate_preset_name(preset_name: String) -> String:
	return preset_name.get_file().get_basename().validate_filename().to_lower()


func _validate_preset_section(section: String) -> String:
	var parts := section.split("/")
	var subsection := "/".join(parts.slice(1))
	assert(parts[0] in SECTIONS, "invalid preset section: %s" % parts[0])
	if parts.size() == 1:
		return _validate_preset_key(parts[0])
	else:
		return "%s/%s" % [_validate_preset_key(parts[0]), _validate_preset_name(subsection)]


func _validate_preset_key(key: String) -> String:
	return key.to_snake_case().to_lower()


func _preset_get_path(preset_name: String) -> String:
	return "%s%s.ini" % [PRESETS_DIR_PATH, _validate_preset_name(preset_name)]


func _emit_preset_loaded() -> void:
	Log.call_task(
		Events.preset_loaded.emit.bind(current_preset_name),
		"load profile '%s'" % _get_preset_name(current_preset_name)
	)
