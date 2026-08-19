class_name M8Scene extends Node3D

var main: Main


func _ready() -> void:
	self.main = await Main.get_instance()
	assert(self.main, "Main was not ready")

	Log.call_task(self.init, "init scene '%s'" % self.name)
	reload()

	Events.preset_loaded.connect(
		func(_profile_name: String) -> void:
			reload(),
	)


func init() -> void:
	pass


func reload() -> void:
	Log.ln("reloading scene %s from config..." % self.scene_file_path)

	var config := self.main.config
	for prop_name in get_scene_property_names():
		var prop_value: Variant = config.get_value_scene(self, prop_name, get(prop_name))
		self.set(prop_name, prop_value)

	Log.ln("reloading scene %s from config done" % self.scene_file_path)


##
## Called by the scene menu when it is first opened.
## Add settings to the menu here.
##
func init_menu(menu: SceneConfigMenu) -> void:
	Log.ln("populating scene config menu...")

	var group_prefix: String = ""
	var condition_target: String = ""
	var condition_expr: String = ""
	var expr := Expression.new()

	for prop in get_scene_property_list():
		var prop_name: String = prop.name
		if _is_export_group(prop):
			group_prefix = prop.hint_string
			menu.add_section(prop_name)
		elif _is_export_subgroup(prop):
			condition_target = prop.name
			condition_expr = prop.hint_string
		elif _is_export_var(prop):
			var setting_name := prop_name.trim_prefix(group_prefix).capitalize()
			if condition_target.is_empty():
				menu.add_auto(prop_name, setting_name)
			else:
				var setting := menu.get_setting(condition_target)
				var error := expr.parse(condition_expr)
				assert(setting, "could not find setting from property: %s" % condition_target)
				assert(error == OK, "could not parse expression: %s" % condition_expr)
				var expr_value: Variant = expr.execute([], self, true, true)

				menu.add_auto(prop_name, setting_name).show_if(
					setting,
					func(value: Variant) -> bool:
						return value == expr_value,
				)

				condition_target = ""
				condition_expr = ""

		else:
			assert(false, "unrecognized property: %s" % prop)

	Log.ln("populating scene config menu done")


##
## Returns true if this scene contains a DeviceModel.
##
func has_device_model() -> bool:
	return has_node("%M8Model") and %M8Model is DeviceModel


##
## Returns the DeviceModel in this scene is there is one. Returns null if not.
##
func get_device_model() -> DeviceModel:
	return %M8Model


##
## Returns true if this scene contains a Camera3D.
##
func has_3d_camera() -> bool:
	return has_node("%CameraRig3D") and %CameraRig3D is CameraRig3D


##
## Returns the Camera3D in this scene is there is one. Returns null if not.
##
func get_3d_camera() -> CameraRig3D:
	return %CameraRig3D if has_node("%CameraRig3D") else null


##
## Load an image or video and apply its texture to a texture rect, if possible.
##
func load_media_to_texture_rect(path: String, vsp: VideoStreamPlayer = null) -> Texture2D:
	if is_instance_valid(vsp):
		vsp.stop()

	# try to load an image from this path
	var ext := path.get_extension()
	match ext:
		"png", "jpg", "jpeg", "hdr":
			print("scene: loading image")
			var image := Image.load_from_file(path)
			return ImageTexture.create_from_image(image)
		"ogv":
			if is_instance_valid(vsp):
				print("scene: loading video")
				vsp.stream = load(path)
				vsp.play()
				return vsp.get_video_texture()

	return null


func get_auto_display_integer_scale() -> int:
	var window_size: Vector2i = get_window().size
	var display_size: Vector2i = main.m8c.get_display_size()
	var intscale := 1

	while (
		(intscale + 1) * display_size.x <= window_size.x
		and (intscale + 1) * display_size.y <= window_size.y
	):
		intscale += 1

	return (int) (intscale / main.display_get_scale())


func get_value(setting: String) -> Variant:
	return main.config.get_value_scene(self, setting, get(setting))


func get_scene_property_list() -> Array[Dictionary]:
	return get_property_list().filter(
		func(prop: Dictionary) -> bool:
			return _is_export_group(prop) or _is_export_var(prop) or _is_export_subgroup(prop),
	)


func _is_export_group(prop: Dictionary) -> bool:
	return (
		(prop.usage & PROPERTY_USAGE_GROUP)
		and prop.name
		not in [
			"Process",
			"Physics Interpolation",
			"Auto Translate",
			"Editor Description",
			"Transform",
			"Visibility",
		]
	)


func _is_export_subgroup(prop: Dictionary) -> bool:
	return ((prop.usage & PROPERTY_USAGE_SUBGROUP) and prop.name != "Thread Group")


func _is_export_var(prop: Dictionary) -> bool:
	return (
		prop.usage & PROPERTY_USAGE_STORAGE and prop.usage & PROPERTY_USAGE_EDITOR
		and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
		and not (prop.name as String).begins_with("_")
	)


## Return a list of properties that should be config settings.
func get_scene_property_names() -> Array[String]:
	var array: Array[String] = []
	array.assign(
		get_scene_property_list()
		.filter(
			func(prop: Dictionary) -> bool:
				return _is_export_var(prop),
		)
		.map(
			func(prop: Dictionary) -> String:
				return prop.name,
		),
	)
	return array
