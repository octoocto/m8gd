extends Node2D

enum Type {BAR, CIRCLE}

@export var type: Type = Type.BAR
@export var interlace: bool = true
@export var mirror: bool = true
@export var line_width: int = 1

@export var spectrum_res: int = 32
@export var spectrum_db_min: float = 60.0
@export var spectrum_freq_min: float = 400.0
@export var spectrum_freq_max: float = 5000.0

@export var spectrum_width: float = 64.0
@export var spectrum_height: float = 64.0

@export_range(0.0, 1.0) var spectrum_smoothing: float = 0.5

var main: M8SceneDisplay

var last_peaks := []

func _ready() -> void:
	last_peaks.resize(spectrum_res)
	last_peaks.fill(0.0)

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if !main.audio_is_spectrum_analyzer_enabled(): return

	var bar_width := spectrum_width / spectrum_res
	var logspace := logrange(spectrum_freq_min, spectrum_freq_max, spectrum_res + 1)

	var polygon_points := []

	for i in range(logspace.size() - 1):

		var magnitude := main.audio_fft(logspace[i], logspace[i + 1])
		var height: float = clamp((spectrum_db_min + linear_to_db(magnitude)) / spectrum_db_min, 0.0, 1.0) * spectrum_height

		# var height_avg = max(height, lerp(height, last_peaks[i], spectrum_smoothing))
		var height_avg: float = lerp(height, last_peaks[i], spectrum_smoothing)
		last_peaks[i] = height_avg

		if type == Type.BAR:
			var pos: Vector2
			if interlace:
				pos = Vector2(i * bar_width, height_avg * (1 - 2 * (i % 2)))
			else:
				pos = Vector2(i * bar_width, height_avg)
			polygon_points.append(pos)
			# var rect := Rect2(pos.x, pos.y, bar_width, 1.0)
			# draw_rect(rect, Color.WHITE)

		if type == Type.CIRCLE:
			polygon_points.append(Vector2.UP.rotated(PI * i / float(spectrum_res - 1)) * (height_avg * 8.0 + 16.0))

	if type == Type.BAR:
		# polygon_points.push_front(Vector2(0, -0.01))
		# polygon_points[0].y = 0
		if mirror:
			# polygon_points[- 1].y = 0
			var mirrored_points := polygon_points.map(func(vec: Vector2) -> Vector2:
				return vec.reflect(Vector2.UP)
			)
			polygon_points.reverse()
			polygon_points.append_array(mirrored_points)
		# for point in polygon_points:
		# 	draw_line(point, point + Vector2.UP * 2, Color.WHITE, 4)
		draw_polyline(polygon_points, Color.WHITE, line_width, false)
		# draw_multiline(polygon_points, Color.WHITE)
		# draw_colored_polygon(polygon_points, Color.WHITE)
		# draw_colored_polygon(mirrored_points, Color.WHITE)
		# draw_colored_polygon(polygon_points.map(func(vec): return vec.reflect(Vector2.RIGHT)), Color.WHITE)
		# draw_colored_polygon(mirrored_points.map(func(vec): return vec.reflect(Vector2.RIGHT)), Color.WHITE)
		# draw_line(Vector2(-spectrum_width, 0), Vector2(spectrum_width, 0), Color.WHITE, 1)

	if type == Type.CIRCLE:
		# add mirrored points to polygon
		var mirrored_points := polygon_points.map(func(vec: Vector2) -> Vector2:
			return vec.reflect(Vector2.UP)
		)
		mirrored_points.reverse()
		mirrored_points.pop_back()
		mirrored_points.pop_front()
		polygon_points.append_array(mirrored_points)

		draw_colored_polygon(polygon_points, Color.WHITE)
		# draw_polyline(polygon_points, Color.WHITE, 4, true)

func logrange(a: float, b: float, step: float) -> Array:
	var pow_a := log(a) / log(10) # convert to 10^a form
	var pow_b := log(b) / log(10) # convert to 10^b form
	var d := (pow_b - pow_a) / float(step)

	var logspace := []

	for i in range(step):
		logspace.append(pow(10, pow_a + (i * d)))

	return logspace
