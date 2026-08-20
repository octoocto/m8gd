extends M8Scene

const GRID_OVERLAY_MATERIAL := preload("res://assets/grid_overlay.tres")

@export_group("Surface Material", "surface_")

@export var surface_mode := SurfaceMode.WOOD:
	set(value):
		surface_mode = value
		self._update_surface()

@export_subgroup("surface_mode", "SurfaceMode.IMAGE")
@export_file var surface_texture := "":
	set(value):
		surface_texture = value
		self._set_surface_texture(value)

@export var surface_color := Color(1.0, 1.0, 1.0):
	set(value):
		surface_color = value
		self._update_surface()

@export_range(0, 360) var surface_rotation := 0:
	set(value):
		surface_rotation = value
		self._update_surface()

@export_range(0.0, 1.0) var surface_metallic := 0.0:
	set(value):
		surface_metallic = value
		self._update_surface()

@export_range(0.0, 1.0) var surface_roughness := 1.0:
	set(value):
		surface_roughness = value
		self._update_surface()

@export var surface_enable_grid := false:
	set(value):
		surface_enable_grid = value
		self._update_surface()

@export var surface_grid_color := Color.WHITE:
	set(value):
		surface_grid_color = value
		self._update_surface()

@export_group("Misc")

@export var enable_grass := false:
	set(value):
		enable_grass = value
		grass_area.visible = value

@export_group("Desk Plant", "plant_")

@export var plant_enabled := true:
	set(value):
		plant_enabled = value
		plant_model.visible = value

@export var plant_type: PlantModel.Type = PlantModel.Type.TYPE_C:
	set(value):
		plant_type = value
		plant_model.type = plant_type

@export_group("Lighting")

@export var enable_directional_light := true:
	set(value):
		enable_directional_light = value
		directional_light.visible = value

@export_subgroup("enable_directional_light", "true")
@export var directional_light_color := Color(0.9, 0.9, 1.0, 0.25):
	set(value):
		directional_light_color = value
		directional_light.light_color = value
		directional_light.light_energy = value.a * 8

@export_subgroup("enable_directional_light", "true")
@export_range(0.0, 360.0) var directional_light_angle := 240.0:
	set(value):
		directional_light_angle = value
		directional_light.rotation_degrees.y = value

@export var enable_lamp_light := true:
	set(value):
		enable_lamp_light = value
		lamp_light.visible = value

@export_subgroup("enable_lamp_light", "true")
@export var lamp_light_color := Color(1, 0.9, 0.6):
	set(value):
		lamp_light_color = value
		lamp_light.light_color = value
		lamp_light.light_energy = value.a

@export var enable_left_light := false:
	set(value):
		enable_left_light = value
		left_light.visible = value

@export_subgroup("enable_left_light", "true")
@export var left_light_color := Color(1, 0, 0):
	set(value):
		left_light_color = value
		left_light.light_color = value
		left_light.light_energy = value.a * 16

@export var enable_right_light := false:
	set(value):
		enable_right_light = value
		right_light.visible = value

@export_subgroup("enable_right_light", "true")
@export var right_light_color := Color(0, 0, 1):
	set(value):
		right_light_color = value
		right_light.light_color = value
		right_light.light_energy = value.a * 16

var surface_material_custom: StandardMaterial3D = null

@onready var camera: CameraRig3D = %CameraRig3D

@onready var surface_mesh: MeshInstance3D = %SurfaceMesh
@onready var grass_area: MultiMeshInstance3D = %GrassArea
@onready var plant_model: PlantModel = %PlantModel
@onready var directional_light: DirectionalLight3D = %DirectionalLight3D
@onready var lamp_light: SpotLight3D = %LightLamp
@onready var left_light: SpotLight3D = %LightLeft
@onready var right_light: SpotLight3D = %LightRight
@onready var video_player: VideoStreamPlayer = %VideoStreamPlayer

enum SurfaceMode {
	WOOD,
	STONE,
	M8_DISPLAY,
	SOLID_COLOR,
	IMAGE,
}


func init() -> void:
	get_device_model().init(self.main)


func _set_surface_texture(path: String) -> void:
	var texture := load_media_to_texture_rect(path, video_player)
	if texture is Texture2D:
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		self.surface_material_custom = material
		_update_surface()


func _update_surface() -> void:
	if not self.is_inside_tree():
		return

	print("Setting surface mode to ", self.surface_mode)
	var material := StandardMaterial3D.new()
	match self.surface_mode:
		SurfaceMode.WOOD:
			material = load("res://assets/ambientcg/wood051.tres")
		SurfaceMode.STONE:
			material = load("res://assets/ambientcg/asphalt010.tres")
		SurfaceMode.M8_DISPLAY:
			material.albedo_texture = self.main.m8c.get_display_texture()
			material.uv1_triplanar = true
			material.uv1_scale = Vector3(0.125, 0.125, 0.125)
		SurfaceMode.IMAGE:
			material = _get_custom_texture()
			material.uv1_triplanar = true
			material.uv1_scale = Vector3(0.125, 0.125, 0.125)
		SurfaceMode.SOLID_COLOR:
			material = StandardMaterial3D.new()

	material.albedo_color = self.surface_color
	material.metallic = self.surface_metallic
	material.roughness = self.surface_roughness

	self.surface_mesh.rotation_degrees.y = self.surface_rotation

	self.surface_mesh.material_override = material

	if self.surface_enable_grid:
		self.surface_mesh.material_overlay = GRID_OVERLAY_MATERIAL
		(self.surface_mesh.material_overlay as StandardMaterial3D).albedo_color = self.surface_grid_color
	else:
		self.surface_mesh.material_overlay = null


func _get_custom_texture() -> StandardMaterial3D:
	var material: StandardMaterial3D = self.surface_material_custom
	if not material:
		material = StandardMaterial3D.new()
	return material
