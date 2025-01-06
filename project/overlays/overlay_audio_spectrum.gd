extends OverlayBase

enum Type {PIXEL, BAR, LINE}
enum ColorStyle {SCOPE, METER}

@export var type: Type = Type.BAR

@export_group("Analyzer", "analyzer_")
@export var analyzer_db_min: float = 60.0
@export_range(100, 20000, 1) var analyzer_freq_min: int = 100
@export_range(100, 20000, 1) var analyzer_freq_max: int = 10000
@export_range(0.0, 1.0, 0.01) var analyzer_smoothing: float = 0.5

# @export var size := Vector2i(320, 240)

@export_group("Style", "style_")
@export_range(1, 10, 1) var style_rows := 1
@export var style_mirror := false
@export var style_reverse := false
@export_range(0.0, 1.0, 0.05) var style_peak_to_alpha_amount := 0.75
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


func _ready() -> void:
	last_peaks.resize(int(size.x * style_rows))
	last_peaks.fill(0.0)

func overlay_get_properties() -> Array[String]:
	return [
		"analyzer_db_min",
		"analyzer_freq_min",
		"analyzer_freq_max",
		"analyzer_smoothing",
		"type",
		"style_rows",
		"style_mirror",
		"style_reverse",
		"style_peak_to_alpha_amount",
		"style_bar_centered",
		"style_bar_interlace",
		"style_line_interlace",
		"style_line_antialiased",
		"style_line_width",
		"style_magnitude_multiplier",
		"style_color_style",
		"style_color_high_cutoff"
	]

func _colors_meter() -> PackedColorArray:
	var colors := main.m8_get_theme_colors()
	return [colors[10], colors[11], colors[12]]

func _colors_scope() -> Color:
	var colors := main.m8_get_theme_colors()
	return colors[9]

func _process(_delta: float) -> void:
	if visible and main.audio_is_spectrum_analyzer_enabled():
		queue_redraw()

func _draw() -> void:

	# var logspace := logrange(analyzer_freq_min, analyzer_freq_max, analyzer_res + 1)
	# var logspace := range(analyzer_freq_min, analyzer_freq_max, (analyzer_freq_max - analyzer_freq_min) / float(analyzer_res))
	var magnitudes := []
	var res := size.x * style_rows

	highest_peak = lerp(0.1, highest_peak, 0.5)

	# for i in range(logspace.size() - 1):
	for i in range(res):

		if style_mirror and i % 2 == 1:
			continue

		var d := (analyzer_freq_max - analyzer_freq_min) / float(res)
		var db_from := i * d
		var db_to := (i + 1) * d

		if i >= last_peaks.size():
			last_peaks.resize(int(res))
			last_peaks.fill(0.0)

		# var magnitude_raw: float = clamp((analyzer_db_min + linear_to_db(main.audio_fft(logspace[i], logspace[i + 1]))) / analyzer_db_min * 2, 0.0, 1.0)
		# var magnitude_raw: float = main.audio_fft(db_from, db_to)
		var magnitude_raw: float = (linear_to_db(main.audio_fft(db_from, db_to)) + analyzer_db_min)

		if magnitude_raw > highest_peak:
			highest_peak = magnitude_raw

		magnitude_raw = clamp(magnitude_raw / highest_peak, 0.0, 1.0)

		var magnitude: float
		if magnitude_raw > last_peaks[i]:
			magnitude = magnitude_raw
		else:
			var smoothing_adjusted := analyzer_smoothing * 0.1 + 0.9
			magnitude = lerp(magnitude_raw, last_peaks[i], smoothing_adjusted)

		last_peaks[i] = magnitude
		magnitudes.append(magnitude)

		# if type == Type.CIRCLE:
		# 	polygon_points.append(Vector2.UP.rotated(PI * i / float(analyzer_res - 1)) * (height_avg * 8.0 + 16.0))

	if style_reverse:
		magnitudes.reverse()

	if style_mirror:
		var mirrored := magnitudes.duplicate()
		mirrored.reverse()
		if magnitudes.size() % 2 == 0: # even elements
			magnitudes.append_array(mirrored)
		else: # odd elements
			magnitudes.append_array(mirrored.slice(1))

	var row_spacing: float = floor(size.y / float(style_rows))
	var points: PackedVector2Array = []
	var colors: PackedColorArray = []

	for i: int in range(magnitudes.size()):
		var m: float = magnitudes[i]

		var color: Color
		match style_color_style:
			ColorStyle.SCOPE:
				color = _colors_scope()
			ColorStyle.METER:
				var cutoff := style_color_high_cutoff
				if m < cutoff:
					color = lerp(_colors_meter()[0], _colors_meter()[1], m / cutoff)
				else:
					color = lerp(_colors_meter()[1], _colors_meter()[2], (m - cutoff) / cutoff)
		color.a = lerp(1.0, magnitudes[i], style_peak_to_alpha_amount)

		var offset := Vector2(floor(i / float(size.x)) * -int(size.x), floor(i / float(size.x)) * row_spacing + row_spacing) + Vector2(position_offset)

		if type == Type.PIXEL:
			var point := Vector2(i, -m * row_spacing * style_magnitude_multiplier)
			draw_primitive([point + offset], [color], [Vector2.ZERO])

		if type == Type.BAR:
			var from: Vector2
			var to: Vector2
			if style_bar_centered:
				offset += Vector2(0, -row_spacing * 0.5)
				if style_bar_interlace:
					if i % 2 == 0:
						from = Vector2(i, 0.5)
						to = Vector2(i, -m * row_spacing * 0.5 * style_magnitude_multiplier)
					else:
						from = Vector2(i, 0.5)
						to = Vector2(i, m * row_spacing * 0.5 * style_magnitude_multiplier)
				else:
					from = Vector2(i, m * row_spacing * 0.5 * style_magnitude_multiplier)
					to = Vector2(i, -m * row_spacing * 0.5 * style_magnitude_multiplier)
			else:
				from = Vector2(i, 0)
				to = Vector2(i, -m * row_spacing * style_magnitude_multiplier)
			points.append(from + offset)
			points.append(to + offset)
			colors.append(color)
			if i == magnitudes.size() - 1:
				draw_multiline_colors(points, colors, style_line_width)

		if type == Type.LINE:
			if style_line_interlace:
				match i % 4:
					0:
						points.append(Vector2(i, (-1.0 - magnitudes[i]) * row_spacing * 0.5) + offset)
					1:
						points.append(Vector2(i, (-2.0 - magnitudes[i]) * row_spacing * 0.25) + offset)
					2:
						points.append(Vector2(i, (-1.0 + magnitudes[i]) * row_spacing * 0.5) + offset)
					3:
						points.append(Vector2(i, (-2.0 + magnitudes[i]) * row_spacing * 0.25) + offset)
				colors.append(color)
			else:
				points.append(Vector2(i, -magnitudes[i] * row_spacing) + offset)
				colors.append(color)

			if i % int(size.x) == size.x - 1:
				draw_polyline_colors(points, colors, style_line_width, style_line_antialiased)
				points.clear()
				colors.clear()
		# Type.CIRCLE:
			# add mirrored points to polygon
			# var mirrored_points := polygon_points.map(func(vec: Vector2) -> Vector2:
			# 	return vec.reflect(Vector2.UP)
			# )
			# mirrored_points.reverse()
			# mirrored_points.pop_back()
			# mirrored_points.pop_front()
			# polygon_points.append_array(mirrored_points)

			# draw_colored_polygon(polygon_points, Color.WHITE)
			# draw_polyline(polygon_points, Color.WHITE, 4, true)

	if draw_bounds:
		draw_rect(Rect2(position_offset, size), Color.WHITE, false)

func logrange(a: float, b: float, step: float) -> Array:
	var pow_a := log(a) / log(10) # convert to 10^a form
	var pow_b := log(b) / log(10) # convert to 10^b form
	var d := (pow_b - pow_a) / float(step)

	var logspace := []

	for i in range(step):
		logspace.append(pow(10, pow_a + (i * d)))

	return logspace
