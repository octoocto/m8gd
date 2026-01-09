extends M8Scene

const GRID_OVERLAY_MATERIAL := preload("res://assets/grid_overlay.tres")

@export var surface_color := Color(1.0, 1.0, 1.0):
	set(value):
		surface_color = value
		if surface_mesh.material_override:
			(surface_mesh.material_override as StandardMaterial3D).albedo_color = value

var surface_material_custom: StandardMaterial3D = null

@export var surface_enable_grid := false:
	set(value):
		surface_enable_grid = value
		if value:
			surface_mesh.material_overlay = GRID_OVERLAY_MATERIAL
			(surface_mesh.material_overlay as StandardMaterial3D).albedo_color = surface_grid_color
		else:
			surface_mesh.material_overlay = null

@export var surface_grid_color := Color.WHITE:
	set(value):
		surface_grid_color = value
		if surface_mesh.material_overlay:
			(surface_mesh.material_overlay as StandardMaterial3D).albedo_color = value

@export var enable_grass := false:
	set(value):
		enable_grass = value
		grass_area.visible = value

@export var enable_plant := true:
	set(value):
		enable_plant = value
		plant_model.visible = value

@export var plant_type: PlantModel.Type = PlantModel.Type.TYPE_C:
	set(value):
		plant_type = value
		plant_model.type = plant_type

@export var enable_directional_light := true:
	set(value):
		enable_directional_light = value
		directional_light.visible = value

@export var directional_light_color := Color(0.9, 0.9, 1.0, 0.25):
	set(value):
		directional_light_color = value
		directional_light.light_color = value
		directional_light.light_energy = value.a * 8

@export_range(0.0, 360.0) var directional_light_angle := 240.0:
	set(value):
		directional_light_angle = value
		directional_light.rotation_degrees.y = value

@export var enable_lamp_light := true:
	set(value):
		enable_lamp_light = value
		lamp_light.visible = value

@export var lamp_light_color := Color(1, 0.9, 0.6):
	set(value):
		lamp_light_color = value
		lamp_light.light_color = value
		lamp_light.light_energy = value.a

@export var enable_left_light := false:
	set(value):
		enable_left_light = value
		left_light.visible = value

@export var left_light_color := Color(1, 0, 0):
	set(value):
		left_light_color = value
		left_light.light_color = value
		left_light.light_energy = value.a * 16

@export var enable_right_light := false:
	set(value):
		enable_right_light = value
		right_light.visible = value

@export var right_light_color := Color(0, 0, 1):
	set(value):
		right_light_color = value
		right_light.light_color = value
		right_light.light_energy = value.a * 16

@onready var camera: M8SceneCamera3D = %Camera3D

@onready var surface_mesh: MeshInstance3D = %SurfaceMesh
@onready var grass_area: MultiMeshInstance3D = %GrassArea
@onready var plant_model: PlantModel = %PlantModel
@onready var directional_light: DirectionalLight3D = %DirectionalLight3D
@onready var lamp_light: SpotLight3D = %LightLamp
@onready var left_light: SpotLight3D = %LightLeft
@onready var right_light: SpotLight3D = %LightRight
@onready var video_player: VideoStreamPlayer = %VideoStreamPlayer


func init(p_main: Main) -> void:
	super(p_main)

	get_device_model().init(main)
	camera.init(main)


func init_menu(menu: SceneConfigMenu) -> void:
	menu.add_section("Surface")
	var setting_surface_mode := menu.add_option_custom(
		"surface_mode", 0, ["Wood", "Stone", "M8 Display", "Custom"], set_surface_mode
	)

	var setting_surface_tex := menu.add_file_custom(
		"surface_texture",
		"",
		func(path: String) -> void:
			var texture := load_media_to_texture_rect(path, video_player)
			if texture is Texture2D:
				var material := StandardMaterial3D.new()
				material.albedo_texture = texture
				surface_material_custom = material
				load_custom_texture()
	)

	setting_surface_tex.show_if(setting_surface_mode, func(value: int) -> bool: return value == 3)

	menu.add_auto("surface_color")

	var setting_grid := menu.add_auto("surface_enable_grid")
	menu.add_auto("surface_grid_color").show_if(setting_grid)

	menu.add_section("Decorations")

	var setting_plant := menu.add_auto("enable_plant")
	menu.add_auto("plant_type").show_if(setting_plant)

	menu.add_auto("enable_grass")

	menu.add_section("Lighting")

	var setting_light_dir := menu.add_auto("enable_directional_light")
	menu.add_auto("directional_light_color", "*Light Color").show_if(setting_light_dir)
	menu.add_auto("directional_light_angle", "*Light Angle").show_if(setting_light_dir)

	var setting_light_lamp := menu.add_auto("enable_lamp_light")
	menu.add_auto("lamp_light_color", "*Light Color").show_if(setting_light_lamp)

	var setting_light_left := menu.add_auto("enable_left_light")
	menu.add_auto("left_light_color", "*Light Color").show_if(setting_light_left)

	var setting_light_right := menu.add_auto("enable_right_light")
	menu.add_auto("right_light_color", "*Light Color").show_if(setting_light_right)


func _physics_process(delta: float) -> void:
	if main.is_menu_open():
		return

	camera.update(delta)


func set_surface_mode(index: int) -> void:
	print("Setting surface mode to ", index)
	var material := StandardMaterial3D.new()
	match index:
		0:  # wood
			material = load("res://assets/ambientcg/wood051.tres")
			material.albedo_color = surface_color
		1:  # stone
			material = load("res://assets/ambientcg/asphalt010.tres")
			material.albedo_color = surface_color
		2:  # display
			material.albedo_texture = main.m8c.get_display_texture()
			material.albedo_color = surface_color
			material.uv1_triplanar = true
			material.uv1_scale = Vector3(0.125, 0.125, 0.125)
		3:  # custom
			material = load_custom_texture()
	surface_mesh.material_override = material


func load_custom_texture() -> StandardMaterial3D:
	var material: StandardMaterial3D = surface_material_custom
	if material:
		material.albedo_color = surface_color
		material.uv1_triplanar = true
		material.uv1_scale = Vector3(0.125, 0.125, 0.125)
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = surface_color
	return material
