@tool
class_name AudioSpectrum
extends Control

enum Type { PIXEL, BAR, LINE }
enum ColorStyle { SCOPE, METER }

@export var type: Type = Type.BAR

@export_group("Analyzer", "analyzer_")
@export var analyzer_db_min: float = 60.0
@export_range(20, 20000, 10) var analyzer_freq_min: int = 100
@export_range(20, 20000, 10) var analyzer_freq_max: int = 10000
@export_range(0.0, 1.0, 0.01) var analyzer_smoothing: float = 0.5
@export_range(1, 2, 1) var analyzer_res_divisor: int = 1

# @export var size := Vector2i(320, 240)

@export_group("Style", "style_")
@export_range(1, 10, 1) var style_rows := 1
@export var style_mirror := false
@export var style_reverse := false
@export_range(0.0, 1.0, 0.05) var style_peak_to_alpha_amount := 0.75
@export var style_bar_gap := 0:
	set(value):
		style_bar_gap = clamp(value, 0, int(size.x) - 1)

@export var style_bar_width := 1:
	set(value):
		style_bar_width = clamp(value, 1, int(size.x))
@export var style_bar_centered := false
@export var style_bar_interlace := false
@export var style_line_interlace := false
@export var style_line_antialiased := false
@export var style_line_width := 1.0
@export var style_magnitude_multiplier := 1.0
@export var style_color_style := ColorStyle.METER
@export var style_color_high_cutoff := 0.6

var highest_peak := 0.5
var last_peaks := []

var m8c: GodotM8Client


func _ready() -> void:
	last_peaks.resize(int(size.x * style_rows))
	last_peaks.fill(0.0)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _colors_meter() -> PackedColorArray:
	if not is_instance_valid(m8c) or m8c.get_theme_colors().size() < 13:
		return PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	var colors := m8c.get_theme_colors()
	return [colors[10], colors[11], colors[12]]


func _colors_scope() -> Color:
	if not is_instance_valid(m8c) or m8c.get_theme_colors().size() < 13:
		return Color.WHITE
	return m8c.get_theme_colors()[9]


func _magnitude_to_color(magnitude: float) -> Color:
	if style_color_style == ColorStyle.SCOPE:
		# use the same color used for the oscillator waveform
		return _colors_scope()

	# use the colors for the db meter
	var colors := _colors_meter()
	var cutoff := style_color_high_cutoff
	var color: Color
	if magnitude < cutoff:
		color = lerp(colors[0], colors[1], magnitude / cutoff)
	else:
		color = lerp(colors[1], colors[2], (magnitude - cutoff) / cutoff)

	color.a = lerp(1.0, magnitude, style_peak_to_alpha_amount)

	return color


func _magnitudes_to_colors(magnitudes: PackedFloat32Array) -> PackedColorArray:
	var colors := PackedColorArray()
	for m in magnitudes:
		colors.append(_magnitude_to_color(m))
	return colors


func _position_magnitudes_to_points(
	magnitudes: PackedFloat32Array, x_positions: PackedFloat32Array
) -> PackedVector2Array:
	var row_height: float = floor(size.y / float(style_rows))
	var points := PackedVector2Array()
	for i in range(magnitudes.size()):
		var m := magnitudes[i]
		var height := m * row_height
		var pos_x := x_positions[i]
		var from: Vector2 = Vector2(pos_x, 0)
		var to: Vector2 = Vector2(pos_x, -height * style_magnitude_multiplier)
		# var offset := Vector2(
		# 	floorf(i / size.x) * int(-size.x) * analyzer_res_divisor,
		# 	floorf(i / size.x) * row_spacing + row_spacing
		# )
		var offset := Vector2(0, size.y)

		if style_bar_centered:
			offset += Vector2(0, -row_height * 0.5)
			if style_bar_interlace:
				if i % 2 == 0:
					from = Vector2(i, 0.5)
					to = Vector2(i, -m * row_height * 0.5 * style_magnitude_multiplier)
				else:
					from = Vector2(i, 0.5)
					to = Vector2(i, m * row_height * 0.5 * style_magnitude_multiplier)
			else:
				from = Vector2(i, m * row_height * 0.5 * style_magnitude_multiplier)
				to = Vector2(i, -m * row_height * 0.5 * style_magnitude_multiplier)

		points.append(from + offset)
		points.append(to + offset)

	return points


func _draw() -> void:
	if not is_instance_valid(m8c):
		return

	var magnitudes := PackedFloat32Array()
	var positions := PackedFloat32Array()

	var x := 0

	# collect positions and magnitudes
	while x < size.x:
		var freq: float = remap(x, 0, size.x, analyzer_freq_min, analyzer_freq_max)
		var magnitude: float = m8c.get_audio_magnitude_at_freq(freq)
		magnitude = remap(linear_to_db(magnitude), -analyzer_db_min, 0.0, 0.0, 1.0)
		magnitude = clamp(magnitude, 0.0, 1.0)
		var width: float = self.style_bar_width
		# var height: float = magnitude * size.y

		magnitudes.append(magnitude)
		positions.append(x)

		x += int(width + style_bar_gap)

	if style_reverse:
		magnitudes.reverse()

	if style_mirror:
		var mirrored := magnitudes.duplicate()
		mirrored.reverse()
		if magnitudes.size() % 2 == 0:  # even elements
			magnitudes.append_array(mirrored)
		else:  # odd elements
			magnitudes.append_array(mirrored.slice(1))

	assert(magnitudes.size() == positions.size())

	var points := _position_magnitudes_to_points(magnitudes, positions)
	var colors := _magnitudes_to_colors(magnitudes)

	if type == Type.PIXEL:
		for i in range(magnitudes.size()):
			var point := points[i]
			var color := colors[i]
			draw_primitive([point], [color], [Vector2.ZERO])

	if type == Type.LINE:
		for i in range(magnitudes.size()):
			var point := points[i]
			var color := colors[i]

			if i > 0:
				var prev_point := Vector2(
					positions[i - 1], -magnitudes[i - 1] * style_magnitude_multiplier
				)
				draw_line(prev_point, point, color, style_line_width)

	if type == Type.BAR:
		draw_multiline_colors(points, colors, style_bar_width)


func logrange(a: float, b: float, step: float) -> Array:
	var pow_a := log(a) / log(10)  # convert to 10^a form
	var pow_b := log(b) / log(10)  # convert to 10^b form
	var d := (pow_b - pow_a) / float(step)

	var logspace := []

	for i in range(step):
		logspace.append(pow(10, pow_a + (i * d)))

	return logspace
