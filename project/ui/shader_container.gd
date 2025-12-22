@tool
class_name ShaderContainer
extends Container

var main: Main

var _shader_rects: Array[ShaderRect]


func _ready() -> void:
	self.main = await Main.get_instance()

	var back_buffer_copy := BackBufferCopy.new()
	back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer_copy, false, INTERNAL_MODE_FRONT)

	_shader_rects.assign(find_children("*", "ShaderRect", false, true))


func _physics_process(_delta: float) -> void:
	if not main:
		return

	# crt_shader_3.material.set_shader_parameter(
	# 	"aberration", main.audio_level * main.visualizer_aberration_amount
	# )
	# crt_shader_3.material.set_shader_parameter(
	# 	"brightness", 1.0 + (main.audio_level * main.visualizer_brightness_amount)
	# )


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_on_update()


func get_shader_rects() -> Array[ShaderRect]:
	return _shader_rects


func has_shader_parameter(shader_mat: ShaderMaterial, shader_parameter: String) -> bool:
	for d: Dictionary in shader_mat.shader.get_shader_uniform_list():
		if d.name == shader_parameter:
			return true
	return false


func get_shader_parameter(shader_rect: ShaderRect, shader_parameter: String) -> Variant:
	var shader_mat: ShaderMaterial = shader_rect.shader_material
	assert(
		has_shader_parameter(shader_mat, shader_parameter),
		(
			"shader parameter does not exist in %s: %s"
			% [shader_mat.shader.resource_path, shader_parameter]
		)
	)
	return shader_mat.get_shader_parameter(shader_parameter)


func set_shader_parameter(
	shader_rect: ShaderRect, shader_parameter: String, value: Variant
) -> void:
	var shader_mat: ShaderMaterial = shader_rect.shader_material
	assert(
		has_shader_parameter(shader_mat, shader_parameter),
		(
			"shader parameter does not exist in %s: %s"
			% [shader_mat.shader.resource_path, shader_parameter]
		)
	)
	shader_mat.set_shader_parameter(shader_parameter, value)


func _on_update() -> void:
	for c in get_children():
		if c is Control:
			fit_child_in_rect(c, Rect2(Vector2.ZERO, size))
