@tool
class_name ShaderRect
extends ColorRect

@export var shader_material: ShaderMaterial


func _ready() -> void:
	if shader_material:
		material = shader_material
	else:
		material = null

	var back_buffer_copy := BackBufferCopy.new()
	add_child(back_buffer_copy)
	back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	back_buffer_copy.set_owner(self)

	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func get_uniform_list() -> Array:
	if not shader_material:
		return []
	# return shader_material.shader.get_shader_uniform_list().filter(
	# 	func(d: Dictionary) -> bool: return d.hint_string != ""
	# )
	return shader_material.shader.get_shader_uniform_list()
