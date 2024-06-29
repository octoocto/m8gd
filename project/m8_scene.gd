class_name M8Scene extends Node3D

const DEFAULT_PROFILE = "__main"

# const COLOR_SAMPLE_POINT_1 := Vector2i(0, 0)
# const COLOR_SAMPLE_POINT_2 := Vector2i(19, 67)
# const COLOR_SAMPLE_POINT_3 := Vector2i(400, 67)

# @export var receiver_texture: ImageTexture

## 3 colors sampled from the m8's display texture
# @export var color_fg: Color
# @export var color_fg2: Color
# @export var color_bg: Color

## Updated by Main scene
var audio_peak := 0.0

var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

var main: M8SceneDisplay

func initialize(p_main: M8SceneDisplay):
    main = p_main

    var config: M8Config = main.config

    # populate scene parameters in menu

    # add scene parameter dict to config if not exists
    if !config.scene_parameters.has(scene_file_path):
        config.scene_parameters[scene_file_path] = {}

    # clear menu
    clear_scene_vars()

    config_load_profile(DEFAULT_PROFILE)

    # add menu items
    var export_vars := get_export_vars()
    for v in export_vars:
        var property = v.name
        if v.hint_string == "bool":
            push_scene_var_bool(property)
        if v.hint_string == "Color":
            push_scene_var_color(property)

func clear_scene_vars():
    var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

    for c in grid.get_children():
        grid.remove_child(c)
        c.queue_free()

func push_scene_var_bool(property: String):
    var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

    var label = Label.new()
    var sep = VSeparator.new()
    var button = CheckButton.new()

    label.text = property.capitalize()
    label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
    button.button_pressed = get(property)
    button.toggled.connect(func(toggled_on: bool):
        set(property, toggled_on)
        config_update_property(DEFAULT_PROFILE, property)
    )

    grid.add_child(label)
    grid.add_child(sep)
    grid.add_child(button)

func push_scene_var_color(property: String):
    var grid: GridContainer = main.menu.get_node("%ContainerSceneVars")

    var label = Label.new()
    var sep = VSeparator.new()
    var button = ColorPickerButton.new()

    label.text = property.capitalize()
    label.size_flags_horizontal = Control.SIZE_FILL + Control.SIZE_EXPAND
    button.color = get(property)
    button.color_changed.connect(func(color: Color):
        set(property, color)
    )

    grid.add_child(label)
    grid.add_child(sep)
    grid.add_child(button)

func get_export_vars() -> Array:
    return get_property_list().filter(func(prop):
        return prop["usage"] == (
            PROPERTY_USAGE_SCRIPT_VARIABLE +
            PROPERTY_USAGE_STORAGE +
            PROPERTY_USAGE_EDITOR
        )
    )

func config_get_profile(profile_name: String) -> Dictionary:
    if !main.config.scene_parameters[scene_file_path].has(profile_name):
        print("scene: initializing profile '%s'" % profile_name)
        main.config.scene_parameters[scene_file_path][profile_name] = {}

    var profile: Dictionary = main.config.scene_parameters[scene_file_path]
    assert(profile is Dictionary)
    # print("scene: using profile '%s'" % profile_name)
    return profile

func config_load_profile(profile_name: String) -> void:
    print("scene: %s: loading profile '%s'" % [scene_file_path, profile_name])
    var export_vars := get_export_vars()
    for v in export_vars:
        var property = v.name
        set(property, config_get_property(profile_name, property))

func config_get_property(profile_name: String, property: String) -> Variant:
    var profile := config_get_profile(profile_name)

    # set parameter from config, or add parameter to config
    if profile.has(property):
        print("scene: %s: setting property '%s' from config" % [profile_name, property])
    else:
        print("scene: %s: adding property '%s' to config" % [profile_name, property])
        profile[property] = get(property)

    return profile[property]

func config_update_property(profile_name: String, property: String) -> void:
    print("scene: updating property '%s' in config" % property)
    config_get_profile(profile_name)[property] = get(property)

func _fft(from_hz: float, to_hz: float) -> float:
    var magnitude := spectrum_analyzer.get_magnitude_for_frequency_range(
        from_hz,
        to_hz,
        AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
    ).length()
    return clamp(magnitude, 0, 1)

# func update_m8_color_samples():
#     if main.m8_display_viewport != null:
#         var image = receiver_texture.get_image()
#         if image != null:
#             color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
#             color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
#             color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)

# func _physics_process(_delta):
#     if receiver_texture != null:
#         var image = receiver_texture.get_image()
#         if image != null:
#             color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
#             color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
#             color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)
