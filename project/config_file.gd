class_name M8Config extends Resource

const CONFIG_FILE_PATH := "user://config.res"

var version = 0

# scene settings
@export var scene_parameters := {} # Dictionary[String, Dictionary]

# video settings
@export var fullscreen := false
@export var vsync := true
@export var fps_cap := 0

# graphical settings
@export var msaa := 0
@export var taa := false
@export var dof_bokeh_shape := 1
@export var dof_blur_quality := 2

# filter/shader settings
@export var filter_1 := false
@export var filter_2 := false
@export var filter_3 := false
@export var filter_4 := false
@export var crt_filter := false

# visualizer settings
@export var audio_analyzer_min_freq = 800
@export var audio_analyzer_max_freq = 1200
@export var audio_to_brightness := 0.1
@export var audio_to_ca := 0.02

# audio settings
@export var volume := 0.8

# misc settings
@export var debug_info := false

# contains key bindings
@export var action_events := {} # Dictionary[String, Array]

func save():
    var error = ResourceSaver.save(self, CONFIG_FILE_PATH, )
    if error == OK:
        print("config saved")
    else:
        printerr("failed to save config: %s" % error_string(error))

static func load() -> M8Config:
    if FileAccess.file_exists(CONFIG_FILE_PATH):
        var config = ResourceLoader.load(CONFIG_FILE_PATH)
        assert(config is M8Config)
        print("using config loaded from file")
        return config
    else:
        print("using default config")
        return M8Config.new()