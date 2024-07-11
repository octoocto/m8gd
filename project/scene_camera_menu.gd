extends PanelContainer

var main: M8SceneDisplay

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	%Button_Finish.pressed.connect(func() -> void:
		main.menu_open()
	)

	%Spin_PosX.value_changed.connect(func(value: float) -> void:
		_cam().position.x=value
	)

	%Spin_PosY.value_changed.connect(func(value: float) -> void:
		_cam().position.y=value
	)

	%Spin_PosZ.value_changed.connect(func(value: float) -> void:
		_cam().position.z=value
	)

	%Spin_AngP.value_changed.connect(func(value: float) -> void:
		_cam().rotation.x=deg_to_rad(value)
	)

	%Spin_AngY.value_changed.connect(func(value: float) -> void:
		_cam().rotation.y=deg_to_rad(value)
	)

	%Spin_FocalLength.value_changed.connect(func(value: float) -> void:
		_cam().dof_focus_distance=value
	)

	%Spin_FocalWidth.value_changed.connect(func(value: float) -> void:
		_cam().dof_focus_width=value
	)

	%Slider_Blur.value_changed.connect(func(value: float) -> void:
		_cam().dof_blur_amount=value
	)

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

func _cam() -> HumanizedCamera3D:
	return main.current_scene.get_3d_camera()

func update_fields() -> void:
	if main.current_scene.has_3d_camera():

		%Spin_PosX.value = _cam().position.x
		%Spin_PosY.value = _cam().position.y
		%Spin_PosZ.value = _cam().position.z
		
		%Spin_AngP.value = rad_to_deg(_cam().rotation.x)
		%Spin_AngY.value = rad_to_deg(_cam().rotation.y)

		%Spin_FocalLength.value = _cam().dof_focus_distance
		%Spin_FocalWidth.value = _cam().dof_focus_width

		%Slider_Blur.value = _cam().dof_blur_amount
		%Label_Blur.text = "%04.2f" % _cam().dof_blur_amount

func menu_open() -> void:
	if !visible:
		visible = true
		%Button_Finish.visible = true
		_cam().set_transform_to_base()

func menu_open_as_info() -> void:
	visible = true
	%Button_Finish.visible = false

func menu_close() -> void:
	if visible:
		visible = false
		_cam().set_current_transform_as_base()