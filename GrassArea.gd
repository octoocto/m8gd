@tool
extends MultiMeshInstance3D

@export var extents := Vector3(10, 0, 10)
@export var grass_mesh: Mesh
@export var num_meshes := 1000

func _ready():
	generate()

func generate():
	multimesh = MultiMesh.new()

	multimesh.mesh = grass_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D

	multimesh.instance_count = num_meshes
	multimesh.visible_instance_count = -1

	for i in range(multimesh.instance_count):
		var xform = Transform3D()

		var shift := Vector3(
			randf_range(-extents.x, extents.x),
			randf_range(-extents.y, extents.y),
			randf_range(-extents.z, extents.z)
		)

		shift.y -= clamp(Vector2(shift.x, shift.z).length() / max(extents.x, extents.z), 0, -1)

		xform = xform.translated(shift)
		multimesh.set_instance_transform(i, xform)
