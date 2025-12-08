extends PanelContainer

@onready var s_position: SettingVec3 = %Setting_Position
@onready var s_angle: SettingVec2 = %Setting_Angle
@onready var s_focus: SettingVec2 = %Setting_Focus
@onready var s_blur: SettingNumber = %Setting_Blur

@onready var button_finish: Button = %Button_Finish

var main: Main

##
## Called once on initial app startup.
##
func init(p_main: Main) -> void:
	main = p_main

	s_position.setting_connect_camera("position")
	s_angle.setting_connect_camera("angle",
		func(value: Vector2) -> void:
			main.get_scene_camera().rotation_degrees = Vector3(value.x, value.y, 0),
		func() -> Vector2:
			var rot := main.get_scene_camera().rotation_degrees
			return Vector2(rot.x, rot.y)
	)
	s_focus.setting_connect_camera_2("dof_focus_distance", "dof_focus_width")
	s_blur.setting_connect_camera("dof_blur_amount")

	button_finish.pressed.connect(main.menu_open)

	Events.scene_loaded.connect(func(_scene_path: String, _scene: M8Scene) -> void:
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
		s_position.reinit()
		s_angle.reinit()
		s_focus.reinit()
		s_blur.reinit()
		camera.set_current_transform_as_base()
		# print("camera menu: reinited")

##
## Called when any of the camera's properties have changed.
## This will change the setting values without saving to the config.
##
func on_camera_updated() -> void:
	var camera := main.get_scene_camera()
	if camera:
		s_position.set_value_no_signal(camera.position)
		s_angle.set_value_no_signal(Vector2(camera.rotation_degrees.x, camera.rotation_degrees.y))
		s_focus.set_value_no_signal(Vector2(camera.dof_focus_distance, camera.dof_focus_width))
		s_blur.set_value_no_signal(camera.dof_blur_amount)
		# print("camera menu: camera updated")

##
## Called when the camera has stopped repositioning.
## This will save the current setting values to the config.
##
func on_camera_reposition_stopped() -> void:
	var camera := main.get_scene_camera()
	if camera:
		camera.set_current_transform_as_base()
		s_position.emit_changed()
		s_angle.emit_changed()
		s_focus.emit_changed()
		s_blur.emit_changed()
		# print("camera menu: camera reposition stopped")

##
## Called when this menu is opened.
##
func menu_show() -> void:
	if !visible:
		show()
		button_finish.show()
		main.get_scene_camera().reset_transform()

##
## Called when the "small" version of this menu is opened.
## Used when editing the camera from the scene parameter menu.
##
func menu_show_small() -> void:
	show()
	button_finish.hide()

##
## Called when this menu is closed.
##
func menu_hide() -> void:
	if visible:
		hide()
		main.get_scene_camera().set_current_transform_as_base()
