class_name M8Scene extends Node3D

# const COLOR_SAMPLE_POINT_1 := Vector2i(0, 0)
# const COLOR_SAMPLE_POINT_2 := Vector2i(19, 67)
# const COLOR_SAMPLE_POINT_3 := Vector2i(400, 67)

# @export var receiver_texture: ImageTexture

## 3 colors sampled from the m8's display texture
# @export var color_fg: Color
# @export var color_fg2: Color
# @export var color_bg: Color

@export var m8_scene_name: String

var main: Main

func init(p_main: Main) -> void:
	main = p_main

##
## Returns this scene's property list, but only exported variables.
##
func get_export_vars() -> Array:
	return get_property_list().filter(func(prop: Dictionary) -> bool:
		return prop["usage"] == (
			PROPERTY_USAGE_SCRIPT_VARIABLE +
			PROPERTY_USAGE_STORAGE +
			PROPERTY_USAGE_EDITOR
		)
	)

##
## Returns true if this scene contains a DeviceModel.
##
func has_device_model() -> bool:
	return has_node("%DeviceModel") and %DeviceModel is DeviceModel

##
## Returns the DeviceModel in this scene is there is one. Returns null if not.
##
func get_device_model() -> DeviceModel:
	return %DeviceModel

##
## Returns true if this scene contains a Camera3D.
##
func has_3d_camera() -> bool:
	return has_node("%Camera3D") and %Camera3D is M8SceneCamera3D

##
## Returns the Camera3D in this scene is there is one. Returns null if not.
##
func get_3d_camera() -> M8SceneCamera3D:
	return %Camera3D

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

func get_setting(setting: String) -> Variant:
	return main.config.get_property_scene(setting)

# func update_m8_color_samples():
#	 if main.m8_display_viewport != null:
#		 var image = receiver_texture.get_image()
#		 if image != null:
#			 color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
#			 color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
#			 color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)

# func _physics_process(_delta):
#	 if receiver_texture != null:
#		 var image = receiver_texture.get_image()
#		 if image != null:
#			 color_fg2 = image.get_pixelv(COLOR_SAMPLE_POINT_3)
#			 color_fg = image.get_pixelv(COLOR_SAMPLE_POINT_2)
#			 color_bg = image.get_pixelv(COLOR_SAMPLE_POINT_1)
