extends M8Scene

const GRID_OVERLAY_MATERIAL := preload("res://assets/grid_overlay.tres")

@onready var camera: M8SceneCamera3D = %Camera3D


@export var surface_color := Color(1.0, 1.0, 1.0):
	set(value):
		surface_color = value
		if %SurfaceMesh.material_override:
			%SurfaceMesh.material_override.albedo_color = value

var surface_material_custom: StandardMaterial3D = null

@export var surface_enable_grid := false:
	set(value):
		surface_enable_grid = value
		if value:
			%SurfaceMesh.material_overlay = GRID_OVERLAY_MATERIAL
			%SurfaceMesh.material_overlay.albedo_color = surface_grid_color
		else:
			%SurfaceMesh.material_overlay = null

@export var surface_grid_color := Color.WHITE:
	set(value):
		surface_grid_color = value
		if %SurfaceMesh.material_overlay:
			%SurfaceMesh.material_overlay.albedo_color = value

@export var enable_grass := false:
	set(value):
		enable_grass = value
		%GrassArea.visible = value

@export var enable_plant := true:
	set(value):
		enable_plant = value
		%PlantModel.visible = value

@export var plant_type: PlantModel.Type = PlantModel.Type.TYPE_C:
	set(value):
		plant_type = value
		%PlantModel.type = plant_type

@export var enable_directional_light := true:
	set(value):
		enable_directional_light = value
		%DirectionalLight3D.visible = value

@export var directional_light_color := Color(0.9, 0.9, 1.0, 0.25):
	set(value):
		directional_light_color = value
		%DirectionalLight3D.light_color = value
		%DirectionalLight3D.light_energy = value.a * 8
	
@export var enable_lamp_light := true:
	set(value):
		enable_lamp_light = value
		%LightLamp.visible = value

@export var lamp_light_color := Color(1, 0.9, 0.6):
	set(value):
		lamp_light_color = value
		%LightLamp.light_color = value
		%LightLamp.light_energy = value.a

@export var enable_left_light := false:
	set(value):
		enable_left_light = value
		%LightLeft.visible = value

@export var left_light_color := Color(1, 0, 0):
	set(value):
		left_light_color = value
		%LightLeft.light_color = value
		%LightLeft.light_energy = value.a * 16

@export var enable_right_light := false:
	set(value):
		enable_right_light = value
		%LightRight.visible = value

@export var right_light_color := Color(0, 0, 1):
	set(value):
		right_light_color = value
		%LightRight.light_color = value
		%LightRight.light_energy = value.a * 16

func init(p_main: Main) -> void:
	super(p_main)

	get_device_model().init(main)
	camera.init(main)

func init_menu(menu: SceneMenu) -> void:

	menu.add_section("Surface")
	var setting_surface_mode := menu.add_option_custom("surface_mode", 0, [
		"Wood",
		"Stone",
		"M8 Display",
		"Custom"
	], set_surface_mode)

	var setting_surface_tex := menu.add_file_custom("surface_texture", "", func(path: String) -> void:
		var texture := load_media_to_texture_rect(path, %VideoStreamPlayer)
		if texture is Texture2D:
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			surface_material_custom = material
			load_custom_texture()
	)

	setting_surface_mode.connect_to_visible(
		setting_surface_tex, func(value: int) -> bool: return value == 3
	)

	menu.add_auto("surface_color")

	var setting_grid := menu.add_auto("surface_enable_grid")
	setting_grid.connect_to_visible(menu.add_auto("surface_grid_color"))

	menu.add_section("Decorations")

	var setting_plant := menu.add_auto("enable_plant")
	setting_plant.connect_to_visible(menu.add_auto("plant_type"))

	menu.add_auto("enable_grass")

	menu.add_section("Lighting")

	var setting_light_dir := menu.add_auto("enable_directional_light")
	setting_light_dir.connect_to_visible(menu.add_auto("directional_light_color", "• Light Color"))
	var setting_light_lamp := menu.add_auto("enable_lamp_light")
	setting_light_lamp.connect_to_visible(menu.add_auto("lamp_light_color", "• Light Color"))
	var setting_light_left := menu.add_auto("enable_left_light")
	setting_light_left.connect_to_visible(menu.add_auto("left_light_color", "• Light Color"))
	var setting_light_right := menu.add_auto("enable_right_light")
	setting_light_right.connect_to_visible(menu.add_auto("right_light_color", "• Light Color"))


func _physics_process(delta: float) -> void:

	if main.is_menu_open(): return

	camera.update(delta)

func set_surface_mode(index: int) -> void:
	match index:
		0: # wood
			%SurfaceMesh.material_override = load("res://assets/ambientcg/wood051.tres")
			%SurfaceMesh.material_override.albedo_color = surface_color
		1: # stone
			%SurfaceMesh.material_override = load("res://assets/ambientcg/asphalt010.tres")
			%SurfaceMesh.material_override.albedo_color = surface_color
		2: # display
			%SurfaceMesh.material_override = StandardMaterial3D.new()
			%SurfaceMesh.material_override.albedo_texture = main.m8_client.get_display()
			%SurfaceMesh.material_override.albedo_color = surface_color
			%SurfaceMesh.material_override.uv1_triplanar = true
			%SurfaceMesh.material_override.uv1_scale = Vector3(0.125, 0.125, 0.125)
		3: # custom
			load_custom_texture()

func load_custom_texture() -> void:
	if surface_material_custom:
		%SurfaceMesh.material_override = surface_material_custom
		%SurfaceMesh.material_override.albedo_color = surface_color
		%SurfaceMesh.material_override.uv1_triplanar = true
		%SurfaceMesh.material_override.uv1_scale = Vector3(0.125, 0.125, 0.125)
	else:
		%SurfaceMesh.material_override = StandardMaterial3D.new()
		%SurfaceMesh.material_override.albedo_color = surface_color
