@tool
class_name BackgroundContainer
extends ScalableContainer

const BALATRO_SHADER_PATH = "res://shaders/backgrounds/balatro.tres"

enum BackgroundMode {
	M8_BACKGROUND_COLOR,
	M8_DISPLAY,
	IMAGE,
	BALATRO,
}

@export var mode := BackgroundMode.M8_BACKGROUND_COLOR:
	set(value):
		mode = value
		self._update()

## The path to an image or video file, if the background mode is [BackgroundMode.IMAGE].
@export_file var texture_file := "":
	set(value):
		texture_file = value
		self._update()

@export_range(0.0, 2.0, 0.01) var brightness: float = 1.0:
	set(value):
		brightness = value
		self._update()

@export_range(0.0, 1.0, 0.01) var tint_amount: float = 0.0:
	set(value):
		tint_amount = value
		self._update()

@export_range(0.0, 8.0, 0.1) var blur_amount: float = 4.0:
	set(value):
		blur_amount = value
		self._update()

@onready var video_stream_player: VideoStreamPlayer = %VideoStreamPlayer
@onready var color_rect: ColorRect = %ColorRect
@onready var texture_rect: TextureRect = %TextureRect
@onready var post_process_rect: ColorRect = %PostProcessRect

var main: Main


func _ready() -> void:
	super()
	self.main = await Main.get_instance()
	self.main.m8c.background_color_changed.connect(
		func(_color: Color) -> void:
			_update(),
	)
	self.main.m8c.theme_changed.connect(
		func(_colors: PackedColorArray) -> void:
			_update(),
	)
	_update()


func _update() -> void:
	if not is_inside_tree():
		return

	var m8_theme := self.main.m8_get_theme_colors()

	match self.mode:
		BackgroundMode.M8_BACKGROUND_COLOR:
			self.texture_rect.visible = false
			self.color_rect.material = null
			self.color_rect.color = m8_theme[0]
		BackgroundMode.BALATRO:
			self.texture_rect.visible = false
			var material: ShaderMaterial = load(BALATRO_SHADER_PATH)
			material.set_shader_parameter("colour_1", m8_theme[5])
			material.set_shader_parameter("colour_2", m8_theme[0])
			material.set_shader_parameter("colour_3", m8_theme[1])
			self.color_rect.material = material
			self.color_rect.color = Color.WHITE
		BackgroundMode.M8_DISPLAY:
			self.texture_rect.visible = true
			self.texture_rect.texture = self.main.m8c.get_display_texture()
		BackgroundMode.IMAGE:
			self.texture_rect.visible = true
			self.texture_rect.texture = _load_texture(self.texture_file)

	_get_post_process_shader().set_shader_parameter("brightness", self.brightness)
	_get_post_process_shader().set_shader_parameter("tint_color", m8_theme[0])
	_get_post_process_shader().set_shader_parameter("tint_amount", self.tint_amount)
	_get_post_process_shader().set_shader_parameter("blur_amount", self.blur_amount)


##
## Load an image or video from a path and retrieve its texture, if possible.
##
func _load_texture(path: String) -> Texture2D:
	var vsp := self.video_stream_player
	assert(is_instance_valid(vsp))
	vsp.stop()

	# try to load an image from this path
	var ext := path.get_extension()
	match ext:
		"png", "jpg", "jpeg", "hdr":
			print("scene: loading image")
			var image := Image.load_from_file(path)
			return ImageTexture.create_from_image(image)
		"ogv":
			print("scene: loading video")
			vsp.stream = load(path)
			vsp.play()
			return vsp.get_video_texture()
		_:
			Log.ln("tried to load a texture with an invalid extension: %s" % path)

	return null


func _get_post_process_shader() -> ShaderMaterial:
	assert(self.post_process_rect.material is ShaderMaterial)
	return self.post_process_rect.material as ShaderMaterial
