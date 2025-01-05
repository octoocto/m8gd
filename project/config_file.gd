class_name M8Config extends Resource

const CONFIG_FILE_PATH := "user://config.res"

const DEFAULT_SCENE_PATH: String = "res://scenes/floating_scene.tscn"
const DEFAULT_COLOR_KEYCAP := Color.BLACK
const DEFAULT_COLOR_BODY := Color.BLACK
const DEFAULT_PROFILE := "__default__"

var version: int = 0

# general settings
@export var splash_show := true

# scene settings
# @export var scene_parameters := {} # Dictionary[String, Dictionary]
# @export var last_scene_path: String # path to last scene opened

## a dictionary in the form of:
## [codeblock]
##     profiles = {"<profile name>": profile_dict}
## [/codeblock]
## where [profile_dict] is a dictionary in the form of:
## [codeblock]
##     profile_dict = {
##         "scene_file_path": <scene file path>,
##         "scene_properties": {"<scene file path>": {}},
##         # other properties (overlays, etc.)
##         "properties": {}
##     }
## [/codeblock]
@export var profiles := {}
@export var current_profile := DEFAULT_PROFILE
@export var profile_hotkeys := {}

@export var camera_mouse_control := true
@export var camera_humanize := true

# overlay settings
@export var overlay_scale := 1
@export var overlay_apply_filters := true
@export var overlay_spectrum := false
@export var overlay_waveform := false
@export var overlay_display := false
@export var overlay_key := false

# device model settings
@export var model_color_key_up := DEFAULT_COLOR_KEYCAP
@export var model_color_key_down := DEFAULT_COLOR_KEYCAP
@export var model_color_key_left := DEFAULT_COLOR_KEYCAP
@export var model_color_key_right := DEFAULT_COLOR_KEYCAP
@export var model_color_key_option := DEFAULT_COLOR_KEYCAP
@export var model_color_key_edit := DEFAULT_COLOR_KEYCAP
@export var model_color_key_shift := DEFAULT_COLOR_KEYCAP
@export var model_color_key_play := DEFAULT_COLOR_KEYCAP
@export var model_color_body := DEFAULT_COLOR_BODY

@export var hl_opacity := 1.0
@export var hl_filters := false
@export var hl_color_directional := Color.WHITE
@export var hl_color_shift := Color.WHITE
@export var hl_color_play := Color.WHITE
@export var hl_color_option := Color.WHITE
@export var hl_color_edit := Color.WHITE

@export var model_use_linear_filter := true

# key overlay settings
@export var key_overlay_enabled := false
@export var key_overlay_style := 0

# video settings
@export var fullscreen := false
@export var window_width := 960
@export var window_height := 720
@export var always_on_top := false
@export var vsync := 1
@export var fps_cap := 8 # see %Setting_Vsync for items

# graphical settings
@export var msaa := 0
@export var taa := false
@export var dof_bokeh_shape := 1
@export var dof_blur_quality := 2
@export var scale_mode := 0
@export var render_scale := 1.0
@export var fsr_sharpness := 0.9

# filter/shader settings
@export var filter_1 := false
@export var filter_2 := false
@export var filter_3 := false
@export var filter_4 := false
@export var crt_filter := false
@export var filter_noise := false

@export var pp_vhs_smear := 1.0
@export var pp_vhs_wiggle := 0.03
@export var pp_vhs_noise_crease_opacity := 0.5
@export var pp_vhs_tape_crease_amount := 0.2
@export var pp_crt_curvature := 0.5
@export var pp_vignette_amount := 0.5

# visualizer settings
@export var audio_analyzer_enabled := true
@export var audio_analyzer_min_freq: int = 800
@export var audio_analyzer_max_freq: int = 1200
@export var audio_to_brightness := 0.1
@export var audio_to_aberration := 0.02

# audio settings
@export var volume := 0.8

# misc settings
@export var debug_info := false

# contains key bindings
@export var action_events := {} # Dictionary[String, Array]
@export var virtual_keyboard_enabled := false

static func _print(text: String) -> void:
	print_rich("[color=aqua]config> %s[/color]" % text)

## Returns true if this script contains a default for the given setting.
##
func assert_setting_exists(setting: String) -> void:
	assert(get(setting) != null, "Setting %s does not exist, must define in config_file.gd" % setting)

func save() -> void:
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

	config.init_profile(DEFAULT_PROFILE)
	return config

##
## Get the current scene path according to the current profile and
## the current scene in the profile.
##
## Intended to be used by the main function to load the initial scene.
##
func get_current_scene_path() -> String:
	if DEFAULT_PROFILE not in profiles.keys():
		init_profile(DEFAULT_PROFILE)
		return DEFAULT_SCENE_PATH

	var scene_file_path: String = profiles[current_profile]["scene_file_path"]
	assert(scene_file_path != null)
	return scene_file_path

##
## Create a new profile.
## The current scene of the new profile will be the same as the one used by
## the current profile.
##
func init_profile(profile_name: String) -> void:

	var scene_file_path: String

	# if creating the default profile, use the default scene
	if profile_name == DEFAULT_PROFILE:
		scene_file_path = DEFAULT_SCENE_PATH
	else:
		scene_file_path = get_current_scene_path()

	if profile_name not in profiles.keys():
		profiles[profile_name] = {
			"scene_file_path": scene_file_path,
			"scene_properties": {},
			"properties": {}
		}
		_print("init profile: %s" % profile_name)

func list_profile_names() -> Array:
	return profiles.keys().filter(func(profile_name: String) -> bool:
		return profile_name != DEFAULT_PROFILE
	)

##
## Rename the current profile.
##
func rename_current_profile(new_profile_name: String) -> void:
	assert(current_profile != DEFAULT_PROFILE)

	var old_profile_name := current_profile
	var profile_hotkey: InputEvent = get_profile_hotkey(old_profile_name)
	var profile_dict: Dictionary = profiles[old_profile_name]

	profiles[new_profile_name] = profile_dict
	profiles.erase(old_profile_name)
	clear_profile_hotkey(old_profile_name)

	current_profile = new_profile_name
	set_profile_hotkey(new_profile_name, profile_hotkey)

	_print("rename profile: %s -> %s" % [old_profile_name, new_profile_name])

##
## Create a new profile. A name will be generated.
##
func create_new_profile() -> String:

	var profile_name := "new profile"
	var iterations := 1

	while true:
		if profile_name not in profiles.keys():
			init_profile(profile_name)
			_print("created profile: %s" % [profile_name])
			return profile_name

		profile_name = "new profile (%d)" % iterations
		iterations += 1

	assert(false)
	return ""

##
## Delete a profile.
##
func delete_profile(profile_name: String) -> void:
	assert(profile_name in profiles.keys())
	assert(profile_name != current_profile)
	profiles.erase(profile_name)
	_print("deleted profile: %s" % [profile_name])

##
## Set the current profile. The saved current scene path of the new profile
## may or may not be the same as the last profile.
##
## Note that this function just sets the internal config variable and
## no actual loading is done.
##
func use_profile(profile_name: String) -> void:
	init_profile(profile_name)
	current_profile = profile_name
	_print("USING profile: %s" % profile_name)

func clear_scene_parameters(scene: M8Scene) -> void:
	var profile: Dictionary = profiles[current_profile]
	var scene_prop_dict: Dictionary = profile["scene_properties"]
	scene_prop_dict.erase(scene.scene_file_path)
	_print("CLEARED scene properties for path: %s" % scene.scene_file_path)

##
## Set the current scene for the current profile.
##
## Note that this function just sets the internal config variable and
## no actual loading is done.
##
func use_scene(scene: M8Scene) -> void:
	assert(scene != null)
	profiles[current_profile]["scene_file_path"] = scene.scene_file_path
	_print("USING scene file path: %s" % scene.scene_file_path)

## Get the scene properties dict for the current profile/scene.
func _get_scene_properties() -> Dictionary:
	var profile: Dictionary = profiles[current_profile]
	var scene_file_path: String = profile["scene_file_path"]
	var scene_prop_dict: Dictionary = profile["scene_properties"]

	if scene_file_path not in scene_prop_dict.keys():
		scene_prop_dict[scene_file_path] = {}
		_print("INIT scene props for scene: %s" % scene_file_path)

	return scene_prop_dict[scene_file_path]

##
## Get a scene property for the current profile and current scene.
## If this property doesn't exist, set it to the value from [default].
##
func get_property_scene(propname: String, default: Variant = null) -> Variant:
	var scene_props: Dictionary = _get_scene_properties()

	# set parameter from config, or add parameter to config
	if !scene_props.has(propname) or scene_props[propname] == null:
		scene_props[propname] = default
		_print("INIT scene prop: %s = %s" % [propname, default])

	# print("scene: profile %s: get %s=%s" % [current_profile, property, profile[property]])
	# _print("GET scene prop: %s, value = %s" % [propname, scene_props[propname]])
	return scene_props[propname]

##
## Set a scene property for the current profile and current scene.
##
func set_property_scene(propname: String, value: Variant) -> void:
	var scene_props: Dictionary = _get_scene_properties()
	if !scene_props.has(propname) or scene_props[propname] != value:
		scene_props[propname] = value
		_print("SET scene prop: %s = %s" % [propname, value])

##
## Get a property for the current profile.
##
func get_property(propname: String, default: Variant = null) -> Variant:
	var props: Dictionary = profiles[current_profile]["properties"]

	# set parameter from config, or add parameter to config
	if !props.has(propname) or props[propname] == null:
		props[propname] = default
		_print("INIT profile prop: %s = %s" % [propname, default])

	# _print("GET profile prop: %s, value = %s" % [propname, props[propname]])
	return props[propname]

##
## Set a property for the current profile.
##
func set_property(propname: String, value: Variant) -> void:
	var props: Dictionary = profiles[current_profile]["properties"]
	if !props.has(propname) or props[propname] != value:
		props[propname] = value
		_print("SET profile prop: %s = %s" % [propname, value])

##
## Set a global config setting.
##
func set_property_global(property: String, value: Variant) -> void:
	assert(property in self)
	if get(property) != value:
		set(property, value)
		_print("SET global prop: %s = %s" % [property, value])

##
## Get a global config setting.
##
func get_property_global(property: String) -> Variant:
	assert(property in self)
	var value: Variant = get(property)
	# _print("GET global prop: %s, value = %s" % [property, value])
	return value

##
## Set a profile's hotkey to an [InputEvent].
##
func set_profile_hotkey(profile_name: String, event: InputEvent) -> void:
	profile_hotkeys[profile_name] = event
	_print("set profile hotkey: %s -> %s" % [event.as_text(), profile_name])

##
## Returns a profile's hotkey ([InputEvent]). If the profile does not have a hotkey,
## returns [null].
##
func get_profile_hotkey(profile_name: String) -> Variant:
	return profile_hotkeys.get(profile_name)

func clear_profile_hotkey(profile_name: String) -> void:
	profile_hotkeys.erase(profile_name)
	_print("cleared profile hotkey for: %s" % profile_name)

func find_profile_name_from_hotkey(event: InputEvent) -> Variant:
	for key: String in profile_hotkeys.keys():
		if event.is_match(profile_hotkeys[key]):
			return key
	return null
