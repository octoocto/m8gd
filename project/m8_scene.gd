class_name M8Scene extends Node3D

var main: Main

func init(p_main: Main) -> void:
	main = p_main

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
	return has_node("%Camera3D") and %Camera3D is M8SceneCamera3D

##
## Returns the Camera3D in this scene is there is one. Returns null if not.
##
func get_3d_camera() -> M8SceneCamera3D:
	return %Camera3D if has_node("%Camera3D") else null

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
	var window_size: Vector2i = get_viewport().size
	var texture: Texture2D = main.m8_client.get_display()
	var intscale := 1
	while ((intscale + 1) * texture.get_size().x <= window_size.x and (intscale + 1) * texture.get_size().y <= window_size.y):
		intscale += 1
	return intscale

func get_setting(setting: String) -> Variant:
	return main.config.get_property_scene(setting)