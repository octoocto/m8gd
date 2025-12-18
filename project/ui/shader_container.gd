@tool
class_name ShaderContainer
extends Container

@onready var vhs_shader_1: ColorRect = %VHSShader1
@onready var vhs_shader_2: ColorRect = %VHSShader2
@onready var crt_shader_1: ColorRect = %CRTShader1
@onready var crt_shader_2: ColorRect = %CRTShader2
@onready var crt_shader_3: ColorRect = %CRTShader3
@onready var noise_shader: ColorRect = %NoiseShader

var main: Main


func _ready() -> void:
	self.main = await Main.get_instance()


func _physics_process(_delta: float) -> void:
	if not main:
		return

	crt_shader_3.material.set_shader_parameter(
		"aberration", main.audio_level * main.visualizer_aberration_amount
	)
	crt_shader_3.material.set_shader_parameter(
		"brightness", 1.0 + (main.audio_level * main.visualizer_brightness_amount)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_on_update()


func has_shader_parameter(shader_mat: ShaderMaterial, shader_parameter: String) -> bool:
	for d: Dictionary in shader_mat.shader.get_shader_uniform_list():
		if d.name == shader_parameter:
			return true
	return false


func get_shader_parameter(shader_node_path: NodePath, shader_parameter: String) -> Variant:
	var shader_mat: ShaderMaterial = get_node(shader_node_path).material
	assert(
		has_shader_parameter(shader_mat, shader_parameter),
		(
			"shader parameter does not exist in %s: %s"
			% [shader_mat.shader.resource_path, shader_parameter]
		)
	)
	return shader_mat.get_shader_parameter(shader_parameter)


func set_shader_parameter(
	shader_node_path: NodePath, shader_parameter: String, value: Variant
) -> void:
	var shader_mat: ShaderMaterial = get_node(shader_node_path).material
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
		fit_child_in_rect(c, Rect2(Vector2.ZERO, size))
