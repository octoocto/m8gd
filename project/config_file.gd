class_name M8Config extends Resource

const CONFIG_FILE_PATH := "user://config.res"

var version: int = 0

# scene settings
@export var scene_parameters := {} # Dictionary[String, Dictionary]
@export var last_scene_path: String # path to last scene opened

@export var subscene_mode := 0
@export var subscene_anchor := 0
@export var subscene_pos := Vector2i(0, 0)
@export var subscene_size := Vector2i(640, 480)

# device model settings
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

# visualizer settings
@export var audio_analyzer_enabled := false
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