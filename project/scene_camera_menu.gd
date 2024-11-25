extends PanelContainer

const PROP_POS := "__cam_pos"
const PROP_ANG := "__cam_ang"
const PROP_FLEN := "__cam_flen"
const PROP_FWID := "__cam_fwid"
const PROP_BLUR := "__cam_blur"
const PROP_MOUSE := "__cam_mouse"
const PROP_HUMAN := "__cam_human"

var main: M8SceneDisplay

func _setprop(property: String, value: Variant) -> void:
	main.config.set_scene_property(property, value)

func _getprop(property: String, default: Variant = null) -> Variant:
	return main.config.get_scene_property(property, default)

func init(p_main: M8SceneDisplay) -> void:
	main = p_main

	%Spin_PosX.value_changed.connect(func(value: float) -> void:
		_cam().position.x = value
		_setprop(PROP_POS, _cam().position)
	)

	%Spin_PosY.value_changed.connect(func(value: float) -> void:
		_cam().position.y = value
		_setprop(PROP_POS, _cam().position)
	)

	%Spin_PosZ.value_changed.connect(func(value: float) -> void:
		_cam().position.z = value
		_setprop(PROP_POS, _cam().position)
	)

	%Spin_AngP.value_changed.connect(func(value: float) -> void:
		_cam().rotation.x = deg_to_rad(value)
		_setprop(PROP_ANG, _cam().rotation)
	)

	%Spin_AngY.value_changed.connect(func(value: float) -> void:
		_cam().rotation.y = deg_to_rad(value)
		_setprop(PROP_ANG, _cam().rotation)
	)

	%Spin_FocalLength.value_changed.connect(func(value: float) -> void:
		_cam().dof_focus_distance = value
		_setprop(PROP_FLEN, value)
	)

	%Spin_FocalWidth.value_changed.connect(func(value: float) -> void:
		_cam().dof_focus_width = value
		_setprop(PROP_FWID, value)
	)

	%Slider_Blur.value_changed.connect(func(value: float) -> void:
		_cam().dof_blur_amount = value
		_setprop(PROP_BLUR, value)
	)

	%Button_Finish.pressed.connect(func() -> void:
		main.menu_open()
	)

	main.menu.get_node("%Check_MouseCamera").toggled.connect(func(toggled_on: bool) -> void:
		_setprop(PROP_MOUSE, toggled_on)
	)

	main.menu.get_node("%Check_HumanCamera").toggled.connect(func(toggled_on: bool) -> void:
		_setprop(PROP_HUMAN, toggled_on)
	)

	main.m8_scene_changed.connect(func(_scene_path: String, scene: M8Scene) -> void:

		if !scene.has_3d_camera(): return

		var cam := scene.get_3d_camera()

		_getprop(PROP_POS, cam.position)
		_getprop(PROP_ANG, cam.rotation)
		_getprop(PROP_FLEN, cam.dof_focus_distance)
		_getprop(PROP_FWID, cam.dof_focus_width)
		_getprop(PROP_BLUR, cam.dof_blur_amount)

		cam.position = _getprop(PROP_POS)
		cam.rotation = _getprop(PROP_ANG)
		cam.base_position = _getprop(PROP_POS)
		cam.base_rotation = _getprop(PROP_ANG)

		%Spin_PosX.value_changed.emit(_getprop(PROP_POS).x)
		%Spin_PosY.value_changed.emit(_getprop(PROP_POS).y)
		%Spin_PosZ.value_changed.emit(_getprop(PROP_POS).z)

		%Spin_AngP.value_changed.emit(rad_to_deg(_getprop(PROP_ANG).x))
		%Spin_AngY.value_changed.emit(rad_to_deg(_getprop(PROP_ANG).y))

		%Spin_FocalLength.value_changed.emit(_getprop(PROP_FLEN))
		%Spin_FocalWidth.value_changed.emit(_getprop(PROP_FWID))
		%Slider_Blur.value_changed.emit(_getprop(PROP_BLUR))

		main.menu.get_node("%Check_MouseCamera").button_pressed = _getprop(PROP_MOUSE, true)
		main.menu.get_node("%Check_HumanCamera").button_pressed = _getprop(PROP_HUMAN, true)

		cam.mouse_controlled_pan_zoom = _getprop(PROP_MOUSE)
		cam.humanized_movement = _getprop(PROP_HUMAN)

		update_fields()
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