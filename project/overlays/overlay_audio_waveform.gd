extends OverlayBase

enum Type {PIXEL, BAR, LINE}

@export var type: Type = Type.BAR

# @export var size := Vector2i(320, 240)
@export_group("Analyzer", "analyzer_")
@export var analyzer_min_db := 20.0
@export_range(30.0, 240.0) var analyzer_sample_rate := 60.0:
	set(value):
		analyzer_sample_rate = value
		sample_rate = 1 / value
@export var analyzer_high_cutoff := 0.75

@export_group("Style", "style_")
@export var style_rows := 1
@export var style_mirror := false
@export var style_reverse := false
@export_range(0.0, 1.0) var style_peak_to_alpha_amount := 0.67
@export var style_bar_centered := false
@export var style_bar_interlace := false
@export var style_line_interlace := false
@export var style_line_antialiased := false
@export var style_line_width := 1.0

var peaks := []

var waveform_size: int = 0

var delta_left: float = 0.0

var sample_rate: float


func _ready() -> void:
	peaks.resize(int(size.x * style_rows))
	peaks.fill(0.0)
	sample_rate = 1 / analyzer_sample_rate

func overlay_get_properties() -> Array[String]:
	return [
		"analyzer_min_db",
		"analyzer_sample_rate",
		"analyzer_high_cutoff",
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
	]

func _colors() -> PackedColorArray:
	var colors := main.m8_get_theme_colors()
	return [colors[10], colors[11], colors[12]]

func _process(delta: float) -> void:

	waveform_size = int(size.x * style_rows)

	delta_left += delta

	while delta_left >= sample_rate:
		delta_left -= sample_rate

		if visible:
			var peak_raw := main.audio_get_peak_volume()
			var peak: float = clamp((((peak_raw.x + peak_raw.y) / 2.0) + analyzer_min_db) / analyzer_min_db, 0.0, 1.0)
			peaks.push_front(peak)

	while peaks.size() > waveform_size:
		peaks.pop_back()

	queue_redraw()

func _draw() -> void:
	if !main.audio_is_spectrum_analyzer_enabled(): return

	var magnitudes := peaks.duplicate()

	if style_mirror:
		for i in range(magnitudes.size()):
			if i < magnitudes.size():
				magnitudes.remove_at(i)

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
		if m < analyzer_high_cutoff:
			color = lerp(_colors()[0], _colors()[1], m / analyzer_high_cutoff)
		else:
			color = lerp(_colors()[1], _colors()[2], (m - analyzer_high_cutoff) / analyzer_high_cutoff)
		color.a = lerp(1.0, m, style_peak_to_alpha_amount)

		var offset := Vector2(floor(i / float(size.x)) * -int(size.x), floor(i / float(size.x)) * row_spacing + row_spacing) + Vector2(position_offset)

		if type == Type.PIXEL:
			var point := Vector2(i, clamp(-magnitudes[i] * row_spacing, -row_spacing, 0.0))
			draw_primitive([point + offset], [color], [Vector2.ZERO])

		if type == Type.BAR:
			var from: Vector2
			var to: Vector2
			if style_bar_centered:
				offset += Vector2(0, -row_spacing * 0.5)
				if style_bar_interlace:
					if i % 2 == 0:
						from = Vector2(i, 0.5)
						to = Vector2(i, -magnitudes[i] * row_spacing * 0.5)
					else:
						from = Vector2(i, 0.5)
						to = Vector2(i, magnitudes[i] * row_spacing * 0.5)
				else:
					from = Vector2(i, magnitudes[i] * row_spacing * 0.5)
					to = Vector2(i, -magnitudes[i] * row_spacing * 0.5)
			else:
				from = Vector2(i, 0)
				to = Vector2(i, -magnitudes[i] * row_spacing)
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
