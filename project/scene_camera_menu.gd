extends PanelContainer


var main: Main

##
## Called once on initial app startup.
##
func init(p_main: Main) -> void:
	main = p_main

	%Setting_Position.init_config_camera(p_main, "position")
	%Setting_Angle.init_config_camera(p_main, "angle",
		func(value: Vector2) -> void:
			main.get_scene_camera().rotation_degrees = Vector3(value.x, value.y, 0),
		func() -> Vector2:
			var rot := main.get_scene_camera().rotation_degrees
			return Vector2(rot.x, rot.y)
	)
	%Setting_Focus.init_config_camera_2(p_main, "dof_focus_distance", "dof_focus_width")
	%Setting_Blur.init_config_camera(p_main, "dof_blur_amount")

	%Button_Finish.pressed.connect(main.menu_open)

	main.scene_loaded.connect(func(_scene_path: String, _scene: M8Scene) -> void:
		on_scene_loaded()
		var camera := main.get_scene_camera()
		if camera:
			if !camera.camera_updated.is_connected(on_camera_updated):
				camera.camera_updated.connect(on_camera_updated)
			if !camera.reposition_stopped.is_connected(on_camera_reposition_stopped):
				camera.reposition_stopped.connect(on_camera_reposition_stopped)
	)

##
## Called when a scene has been loaded.
## This will reinit setting values from the config.
##
func on_scene_loaded() -> void:
	var camera := main.get_scene_camera()
	if camera:
		%Setting_Position.reinit()
		%Setting_Angle.reinit()
		%Setting_Focus.reinit()
		%Setting_Blur.reinit()
		camera.set_current_transform_as_base()
		# print("camera menu: reinited")

##
## Called when any of the camera's properties have changed.
## This will change the setting values without saving to the config.
##
func on_camera_updated() -> void:
	var camera := main.get_scene_camera()
	if camera:
		%Setting_Position.set_value_no_signal(camera.position)
		%Setting_Angle.set_value_no_signal(Vector2(camera.rotation_degrees.x, camera.rotation_degrees.y))
		%Setting_Focus.set_value_no_signal(Vector2(camera.dof_focus_distance, camera.dof_focus_width))
		%Setting_Blur.set_value_no_signal(camera.dof_blur_amount)
		# print("camera menu: camera updated")

##
## Called when the camera has stopped repositioning.
## This will save the current setting values to the config.
##
func on_camera_reposition_stopped() -> void:
	var camera := main.get_scene_camera()
	if camera:
		camera.set_current_transform_as_base()
		%Setting_Position._emit_value_changed()
		%Setting_Angle._emit_value_changed()
		%Setting_Focus._emit_value_changed()
		%Setting_Blur._emit_value_changed()
		# print("camera menu: camera reposition stopped")

##
## Called when this menu is opened.
##
func menu_open() -> void:
	if !visible:
		# update_menu()
		visible = true
		%Button_Finish.visible = true
		main.get_scene_camera().set_transform_to_base()

##
## Called when the "small" version of this menu is opened.
## Used when editing the camera from the scene parameter menu.
##
func menu_open_as_info() -> void:
	# update_menu()
	visible = true
	%Button_Finish.visible = false

##
## Called when this menu is closed.
##
func menu_close() -> void:
	if visible:
		visible = false
		main.get_scene_camera().set_current_transform_as_base()