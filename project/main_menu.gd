class_name MainMenu extends Panel

const PATH_SCENES := "res://scenes/"

@onready var button_exit: Button = %ButtonExit

@onready var slider_volume: HSlider = %SliderVolume

# the order of paths in scene_paths[] correspond to the items in option_scenes
@onready var option_scenes: OptionButton = %OptionScenes
@onready var scene_paths := []

func initialize(main: M8SceneDisplay) -> void:

	# scan scenes folder
	var dir_scenes = DirAccess.open(PATH_SCENES)

	dir_scenes.list_dir_begin()
	var path := dir_scenes.get_next()
	while path != "":
		if path.trim_suffix(".remap").get_extension() == "tscn":
			option_scenes.add_item(path.get_file().get_basename())
			scene_paths.append(dir_scenes.get_current_dir().path_join(path))
		path = dir_scenes.get_next()

	option_scenes.item_selected.connect(func(index: int):
		main.load_scene(scene_paths[index])
	)

	# options

	slider_volume.value_changed.connect(func(value: float):
		var volume_db=- 60.0 * (1 - value)
		print("volume = %f" % volume_db)
		AudioServer.set_bus_volume_db(0, volume_db)
		%LabelVolume.text="%d%%" % round(slider_volume.value / slider_volume.max_value * 100)
	)

	%CheckButtonDebug.toggled.connect(func(toggled_on):
		main.get_node("%DebugLabels").visible=toggled_on
	)

	# video

	%CheckButtonFullscreen.button_down.connect(func():
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)

	%CheckButtonVsync.button_down.connect(func():
		if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	)

	%OptionRes.item_selected.connect(func(index):
		match index:
			1: DisplayServer.window_set_size(Vector2i(640, 480))
			2: DisplayServer.window_set_size(Vector2i(960, 720))
			3: DisplayServer.window_set_size(Vector2i(1280, 960))
			5: DisplayServer.window_set_size(Vector2i(960, 640))
			6: DisplayServer.window_set_size(Vector2i(1440, 960))
			7: DisplayServer.window_set_size(Vector2i(1920, 1280))
	)

	%SliderFPSCap.value_changed.connect(func(value: float):
		if value > 0 and value < 15: value=15
		Engine.max_fps=int(value)
	)

	# graphics

	%CheckButtonFilter.toggled.connect(func(toggled_on):
		main.get_node("%CRTShader").visible=toggled_on
	)

	%SliderDOFShape.value_changed.connect(func(value: RenderingServer.DOFBokehShape):
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(value)
		match value:
			RenderingServer.DOF_BOKEH_BOX:
				%LabelDOFShape.text="Box"
			RenderingServer.DOF_BOKEH_HEXAGON:
				%LabelDOFShape.text="Hexagon"
			RenderingServer.DOF_BOKEH_CIRCLE:
				%LabelDOFShape.text="Circle"
	)

	%SliderDOFQuality.value_changed.connect(func(value: RenderingServer.DOFBlurQuality):
		RenderingServer.camera_attributes_set_dof_blur_quality(value, true)
		match value:
			RenderingServer.DOF_BLUR_QUALITY_VERY_LOW:
				%LabelDOFQuality.text="Very Low"
			RenderingServer.DOF_BLUR_QUALITY_LOW:
				%LabelDOFQuality.text="Low"
			RenderingServer.DOF_BLUR_QUALITY_MEDIUM:
				%LabelDOFQuality.text="Medium"
			RenderingServer.DOF_BLUR_QUALITY_HIGH:
				%LabelDOFQuality.text="High"
	)

	# MSAA

	%SliderMSAA.value_changed.connect(func(value: int):
		match value:
			0:
				main.scene_viewport.msaa_3d=Viewport.MSAA_DISABLED
				%LabelMSAA.text="Disabled"
			1:
				main.scene_viewport.msaa_3d=Viewport.MSAA_2X
				%LabelMSAA.text="2X"
			2:
				main.scene_viewport.msaa_3d=Viewport.MSAA_4X
				%LabelMSAA.text="4X"
			3:
				main.scene_viewport.msaa_3d=Viewport.MSAA_8X
				%LabelMSAA.text="8X"
	)

	# TAA

	%CheckButtonTAA.toggled.connect(func(toggled_on: bool):
		# ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_taa", toggled_on)
		main.scene_viewport.use_taa=toggled_on
	)

	button_exit.pressed.connect(func():
		get_tree().quit()
	)

	%DisplayRect.texture = main.m8_client.get_display_texture()

	# M8 Screen Emission

	main.m8_scene_changed.connect(func():
		var m8=main.current_scene.get_node("%M8Model")
		if m8 is DeviceModel:
			var screen=m8.get_node("%Screen")
			var amount=screen.material_override.get_shader_parameter("emission_amount")
			%SliderScreenEmission.editable=true
			%SliderScreenEmission.value=amount
			%LabelScreenEmission.text="%0.2f" % amount
		else:
			%SliderScreenEmission.editable=false
			%LabelScreenEmission.text="N/A"
	)

	%SliderScreenEmission.value_changed.connect(func(value: float):
		var m8=main.current_scene.get_node("%M8Model")
		if m8 is DeviceModel:
			var screen=m8.get_node("%Screen")
			screen.material_override.set_shader_parameter("emission_amount", value)
			%LabelScreenEmission.text="%0.2f" % value
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		# menu on/off toggle
		if event.pressed and event.keycode == KEY_ESCAPE:
			visible = !visible

func _process(_delta) -> void:
	%CheckButtonFullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	%OptionRes.disabled = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	%CheckButtonVsync.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	%LabelFPSCap.text = "%d" % Engine.max_fps