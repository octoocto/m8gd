class_name M8Scene extends Node3D

const COLOR_SAMPLE_POINT_1 := Vector2i(0, 0)
const COLOR_SAMPLE_POINT_2 := Vector2i(19, 67)
@export var COLOR_SAMPLE_POINT_3 := Vector2i(400, 67)

@export var receiver_texture: ImageTexture

## 3 colors sampled from the m8's display texture
@export var color_fg: Color
@export var color_fg2: Color
@export var color_bg: Color

## Updated by Main scene
var audio_peak := 0.0

var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

var display = M8SceneDisplay

func initialize(_display: M8SceneDisplay):
    self.display = _display

func _fft(from_hz: float, to_hz: float) -> float:
    var magnitude := spectrum_analyzer.get_magnitude_for_frequency_range(
        from_hz,
        to_hz,
        AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
    ).length()
    return clamp(magnitude, 0, 1)

func update_m8_color_samples():
    if display.m8_display_viewport != null:
        var image = receiver_texture.get_image()
        if image != null:
            color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
            color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
            color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)

func _physics_process(_delta):
    if receiver_texture != null:
        var image = receiver_texture.get_image()
        if image != null:
            color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
            color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
            color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)