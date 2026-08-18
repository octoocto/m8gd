@tool
class_name OverlayOscillator
extends OverlayBase

@export var mix_enabled := false
@export var track_1_enabled := true
@export var track_2_enabled := true
@export var track_3_enabled := true
@export var track_4_enabled := true
@export var track_5_enabled := true
@export var track_6_enabled := true
@export var track_7_enabled := true
@export var track_8_enabled := true
@export var mod_fx_enabled := false
@export var delay_fx_enabled := false
@export var reverb_fx_enabled := false

var vp: SubViewport
var vp_container: SubViewportContainer
var vbox: VBoxContainer


func _overlay_init() -> void:
	self.custom_minimum_size = Vector2(320, 240)
	super()


func _overlay_update() -> void:
	if is_instance_valid(self.vp):
		self.vp.queue_free()
	if is_instance_valid(self.vp_container):
		self.vp_container.queue_free()
	if is_instance_valid(self.vbox):
		self.vbox.queue_free()

	self.vp_container = SubViewportContainer.new()
	self.vp_container.size = self.size
	self.vp_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(self.vp_container)

	self.vp = SubViewport.new()
	self.vp.size = self.size
	self.vp.transparent_bg = true
	self.vp_container.add_child(self.vp)

	self.vbox = VBoxContainer.new()
	self.vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	self.vbox.add_theme_constant_override("separation", 6)
	self.vp.add_child(self.vbox)

	if self.mix_enabled:
		_add_osc(0)
	if self.track_1_enabled:
		_add_osc(1)
	if self.track_2_enabled:
		_add_osc(2)
	if self.track_3_enabled:
		_add_osc(3)
	if self.track_4_enabled:
		_add_osc(4)
	if self.track_5_enabled:
		_add_osc(5)
	if self.track_6_enabled:
		_add_osc(6)
	if self.track_7_enabled:
		_add_osc(7)
	if self.track_8_enabled:
		_add_osc(8)
	if self.mod_fx_enabled:
		_add_osc(9)
	if self.delay_fx_enabled:
		_add_osc(10)
	if self.reverb_fx_enabled:
		_add_osc(11)


func _add_osc(track_index: int) -> void:
	var osc := TrackOscilloscope.create(main.m8c, track_index)
	# osc.position_offset = self.offset_transform_position
	self.vbox.add_child(osc)
