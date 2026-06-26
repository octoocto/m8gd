class_name TrackOscilloscope
extends Control

@export var track_index: int = 0

var m8c: GodotM8Client

var buffer: PackedFloat32Array = PackedFloat32Array()

var color: Color = Color.WHITE

var width: int = 320
var height: int = 24
var height_multiplier: float = 4.0
var position_offset := Vector2i.ZERO


static func create(m8c: GodotM8Client, track_index: int) -> TrackOscilloscope:
	var osc := TrackOscilloscope.new()
	osc.init(m8c, track_index)
	return osc


func init(p_m8c: GodotM8Client, p_track_index: int) -> void:
	self.m8c = p_m8c
	self.track_index = p_track_index

	self.m8c.theme_colors_updated.connect(
		func(colors: PackedColorArray) -> void:
			self.color = colors[9]
			queue_redraw()
	)


func _physics_process(_delta: float) -> void:
	if not visible or not is_instance_valid(self.m8c):
		return

	self.buffer = self.m8c.get_audio_track_buffer(self.track_index)
	custom_minimum_size = Vector2(self.width, self.height)
	if self.buffer.size() > self.width:
		queue_redraw()


func _draw() -> void:
	if self.buffer.size() == 0:
		return

	for i in range(self.width):
		var pos := Vector2(i, clampf((self.buffer[i] * -self.height_multiplier + 0.5) * self.size.y, 0, self.size.y)) + Vector2(self.position_offset)
		if not is_zero_approx(self.buffer[i]):
			draw_primitive([pos], [self.color], [Vector2.ZERO])
