class_name TrackOscilloscope
extends Control

var m8c: GodotM8Client
var track_index: int = 0

var buffer: PackedFloat32Array = PackedFloat32Array()

var color: Color = Color.WHITE

var width: int = 240


func init(p_m8c: GodotM8Client, p_track_index: int) -> void:
	self.m8c = p_m8c
	self.track_index = p_track_index

	self.m8c.theme_colors_updated.connect(
		func(colors: PackedColorArray) -> void:
			self.color = colors[9]
			queue_redraw()
	)


func _physics_process(_delta: float) -> void:
	buffer = m8c.get_audio_track_buffer(self.track_index)
	custom_minimum_size = Vector2(width, 48)
	if buffer.size() > width:
		queue_redraw()


func _draw() -> void:
	if buffer.size() == 0:
		return

	for i in range(width):
		var pos := Vector2(i, clampf((buffer[i] + 0.5) * size.y, 0, size.y))
		if not is_zero_approx(buffer[i]):
			draw_primitive([pos], [color], [Vector2.ZERO])
