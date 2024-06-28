class_name M8Config extends Resource

const CONFIG_FILE_PATH := "user://config.res"

var version = 0

# video settings
@export var fullscreen := false
@export var vsync := true
@export var fps_cap := 0

# graphical settings
@export var crt_filter := false
@export var msaa := 0
@export var taa := false
@export var dof_bokeh_shape := 1
@export var dof_blur_quality := 2

# audio settings
@export var volume := 0.8

# misc settings
@export var debug_info := false

# contains key bindings
@export var action_events: Dictionary = {}

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