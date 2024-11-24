class_name M8Config extends Resource

const CONFIG_FILE_PATH := "user://config.res"

const DEFAULT_COLOR_KEYCAP := Color.BLACK
const DEFAULT_COLOR_BODY := Color.BLACK

var version: int = 0

# general settings
@export var splash_show := true

# scene settings
@export var scene_parameters := {} # Dictionary[String, Dictionary]
@export var last_scene_path: String # path to last scene opened

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
@export var fps_cap := 0

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
@export var audio_to_ca := 0.02

# audio settings
@export var volume := 0.8

# misc settings
@export var debug_info := false

# contains key bindings
@export var action_events := {} # Dictionary[String, Array]
@export var virtual_keyboard_enabled := false

## Returns true if this script contains a default for the given setting.
##
func assert_setting_exists(setting: String) -> void:
	assert(get(setting) != null, "Setting %s does not exist, must define in config_file.gd" % setting)

func save() -> void:
	var error := ResourceSaver.save(self, CONFIG_FILE_PATH)
	if error == OK:
		print("config saved")
	else:
		printerr("failed to save config: %s" % error_string(error))

static func load() -> M8Config:
	if FileAccess.file_exists(CONFIG_FILE_PATH):
		var config: M8Config = ResourceLoader.load(CONFIG_FILE_PATH)
		assert(config is M8Config)
		print("using config loaded from file")
		return config
	else:
		print("using default config")
		return M8Config.new()