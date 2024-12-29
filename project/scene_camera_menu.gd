extends PanelContainer


var main: M8SceneDisplay

##
## Called once on initial app startup.
##
func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	var callback := func(_value: float) -> void:
		_update_camera()

	%Spin_PosX.value_changed.connect(callback)
	%Spin_PosY.value_changed.connect(callback)
	%Spin_PosZ.value_changed.connect(callback)
	%Spin_AngP.value_changed.connect(callback)
	%Spin_AngY.value_changed.connect(callback)
	%Spin_FocalLength.value_changed.connect(callback)
	%Spin_FocalWidth.value_changed.connect(callback)
	%Slider_Blur.value_changed.connect(callback)

	%Button_Finish.pressed.connect(func() -> void:
		main.menu_open()
	)

	main.m8_scene_changed.connect(func(_scene_path: String, _scene: M8Scene) -> void:
		update_menu()
	)

##
## Called when this menu is opened.
##
func menu_open() -> void:
	if !visible:
		update_menu()
		visible = true
		%Button_Finish.visible = true
		main.get_scene_camera().set_transform_to_base()

##
## Called when the "small" version of this menu is opened.
## Used when editing the camera from the scene parameter menu.
##
func menu_open_as_info() -> void:
	update_menu()
	visible = true
	%Button_Finish.visible = false

##
## Called when this menu is closed.
##
func menu_close() -> void:
	if visible:
		visible = false
		main.get_scene_camera().set_current_transform_as_base()

##
## Update the scene camera and the config from this menu.
##
func _update_camera() -> void:

	var camera := main.get_scene_camera()
	assert(camera != null)

	camera.position = Vector3(%Spin_PosX.value, %Spin_PosY.value, %Spin_PosZ.value)
	camera.rotation = Vector3(deg_to_rad(%Spin_AngP.value), deg_to_rad(%Spin_AngY.value), 0)
	camera.dof_focus_distance = %Spin_FocalLength.value
	camera.dof_focus_width = %Spin_FocalWidth.value
	camera.dof_blur_amount = %Slider_Blur.value

	main.save_camera()

##
## Update this menu with the current scene camera properties.
##
func update_menu() -> void:

	var camera := main.get_scene_camera()
	if camera == null: return
	
	%Spin_PosX.set_value_no_signal(camera.position.x)
	%Spin_PosY.set_value_no_signal(camera.position.y)
	%Spin_PosZ.set_value_no_signal(camera.position.z)
	
	%Spin_AngP.set_value_no_signal(rad_to_deg(camera.rotation.x))
	%Spin_AngY.set_value_no_signal(rad_to_deg(camera.rotation.y))

	%Spin_FocalLength.set_value_no_signal(camera.dof_focus_distance)
	%Spin_FocalWidth.set_value_no_signal(camera.dof_focus_width)

	%Slider_Blur.set_value_no_signal(camera.dof_blur_amount)
	%Label_Blur.text = "%04.2f" % camera.dof_blur_amount

func set_fields_editable(editable: bool) -> void:

	%Spin_PosX.editable = editable
	%Spin_PosY.editable = editable
	%Spin_PosZ.editable = editable
	%Spin_AngP.editable = editable
	%Spin_AngY.editable = editable
	%Spin_FocalLength.editable = editable
	%Spin_FocalWidth.editable = editable
	%Slider_Blur.editable = editable
	%Button_Finish.disabled = !editable
