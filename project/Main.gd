class_name M8SceneDisplay extends Panel

const MAIN_SCENE: PackedScene = preload ("res://scenes/desk_scene.tscn")

const FONT_SMALL: BitMap = preload ("res://assets/m8stealth57.bmp")
const FONT_BIG: BitMap = preload ("res://assets/m8stealth89.bmp")

const M8K_UP = 64
const M8K_DOWN = 32
const M8K_LEFT = 128
const M8K_RIGHT = 4
const M8K_SHIFT = 16
const M8K_PLAY = 8
const M8K_OPTION = 2
const M8K_EDIT = 1

signal m8_key_changed

@export var visualizer_ca_amount = 1.0
@export var visualizer_glow_amount = 0.5
@export var visualizer_brightness_amount = 0.1

@onready var audio_monitor: AudioStreamPlayer = %AudioInputMonitor

@onready var scene_viewport: SubViewport = %SceneViewport
@onready var current_scene: M8Scene = null

@onready var menu: MainMenu = %MainMenuPanel

@onready var m8_client := M8GD.new()
@onready var m8_connected := false
@onready var m8_audio_connected := false
@onready var m8_keystate: int = 0 # bitfield containing state of all 8 keys
@onready var m8_keystate_last: int = 0
@onready var m8_locally_controlled := false

var last_peak := 0.0

func _ready():

	# resize viewport with window
	DisplayServer.window_set_min_size(Vector2i(640, 480)) # 2x M8 screen size
	get_tree().get_root().size_changed.connect(on_window_size_changed)

	# initialize main menu
	print("initializing menu controls...")
	menu.initialize(self)

	# initialize main scene
	_preload_scene(MAIN_SCENE)

## Temporarily show a message on the bottom-left of the screen.
func print_blink(msg: String) -> void:
	%LabelStatus.text = msg
	%LabelStatus.modulate.a = 1.0

## Load a scene from a filepath.
func load_scene(scene_path) -> void:
	# load packed scene from file
	print("loading new scene from %s..." % scene_path)
	var packed_scene = load(scene_path.trim_suffix(".remap"))
	assert(packed_scene != null and packed_scene is PackedScene)

	_preload_scene(packed_scene)

func _preload_scene(packed_scene: PackedScene) -> void:

	# instantiate scene
	print("instantiating scene...")
	var scene: M8Scene = packed_scene.instantiate()
	assert(scene != null and scene is M8Scene)

	# remove existing scene from viewport
	if current_scene:
		print("freeing current scene...")
		scene_viewport.remove_child(current_scene)
		current_scene.queue_free()
		current_scene = null

	# add new scene and initialize
	print("adding new scene...")
	scene_viewport.add_child(scene)
	scene.initialize(self)
	current_scene = scene
	current_scene.spectrum_analyzer = AudioServer.get_bus_effect_instance(1, 0)

	print("scene loaded!")

# Signal callbacks
################################################################################

func on_window_size_changed() -> void:
	scene_viewport.size = DisplayServer.window_get_size()

# M8 client methods
################################################################################

## Automatically detect and connect to any M8 device.
func m8_connect() -> void:

	var m8_ports: Array = M8GD.list_devices()

	if m8_ports.size() and m8_client.connect(m8_ports[0]):

		m8_connected = true
		%LabelPort.text = m8_ports[0]
		print_blink("connected to M8 at %s!" % m8_ports[0])
		m8_client.keystate_changed.connect(on_m8_keystate_changed)
		m8_client.system_info.connect(on_m8_system_info)
		m8_client.font_changed.connect(on_m8_font_changed)
		m8_client.device_disconnected.connect(on_m8_disconnect)

## Automatically detect and monitor an M8 audio device.
func m8_connect_audio() -> void:

	# If the M8 device is plugged in and detected, use it as a microphone and
	# playback to the default audio output device.
	for device in AudioServer.get_input_device_list():
		if device.contains("M8"):
			AudioServer.input_device = device
			audio_monitor.stream = AudioStreamMicrophone.new()
			audio_monitor.playing = true
			m8_audio_connected = true
			print("monitoring audio with device %s" % device)

## Disconnect the M8 audio device from the monitor.
func m8_disconnect_audio() -> void:
	m8_audio_connected = false
	AudioServer.input_device = "Default"
	audio_monitor.playing = false
	print("no longer monitoring audio")

## Check if the M8 audio device still exists. If not, disconnect.
func m8_check_audio() -> void:
	for device in AudioServer.get_input_device_list():
		if device.contains("M8"):
			return
	m8_disconnect_audio()

func on_m8_keystate_changed(keystate: int) -> void:
	update_keystate(keystate, false)
	m8_locally_controlled = true

func on_m8_system_info(hardware, firmware) -> void:
	%LabelVersion.text = "%s %s" % [hardware, firmware]

func on_m8_font_changed(bigfont: bool) -> void:
	# switch between small/big fonts (Model_01)
	if bigfont:
		m8_client.load_font(FONT_BIG)
	else:
		m8_client.load_font(FONT_SMALL)

## Called when the M8 has been disconnected.
func on_m8_disconnect() -> void:

	m8_connected = false
	%LabelPort.text = ""

	m8_client.keystate_changed.disconnect(on_m8_keystate_changed)
	m8_client.system_info.disconnect(on_m8_system_info)
	m8_client.font_changed.disconnect(on_m8_font_changed)
	m8_client.device_disconnected.disconnect(on_m8_disconnect)

	if m8_audio_connected:
		m8_disconnect_audio()

	print_blink("disconnected")

func _physics_process(delta: float) -> void:

	# calculate peaks for visualizations

	var peak = db_to_linear((AudioServer.get_bus_peak_volume_left_db(1, 0) + AudioServer.get_bus_peak_volume_right_db(1, 0)) / 2.0)
	var avg_peak = (peak + last_peak) / 2.0
	last_peak = avg_peak
	
	# do shader parameter responses to audio

	var material_crt_filter: ShaderMaterial = $CRTShader.material
	material_crt_filter.set_shader_parameter("aberration", avg_peak * visualizer_ca_amount)
	# if scene is CRT_Scene:
	#     scene.crt_glow_amount = 1.0 + (avg_peak * visualizer_glow_amount)
	#     scene.brightness = 1.0 + (avg_peak * visualizer_brightness_amount)
	current_scene.audio_peak = avg_peak

	# fade out status message

	if %LabelStatus.modulate.a > 0:
		%LabelStatus.modulate.a = lerp( %LabelStatus.modulate.a, %LabelStatus.modulate.a - delta * 2.0, 0.2)

func _process(_delta: float) -> void:

	# read and update m8 display texture every frame
	if m8_connected and m8_client.read_serial_data():
		m8_client.update_texture()

	# auto connect to m8s
	if !m8_connected:
		m8_connect()

	# auto monitor audio if m8 is connected
	if m8_connected and !m8_audio_connected:
		m8_connect_audio()

	if m8_connected and m8_audio_connected:
		m8_check_audio()

	%LabelFPS.text = "%d" % Engine.get_frames_per_second()

	var is_anything_pressed := false

	for key in ["key_up", "key_down", "key_left", "key_right", "key_shift", "key_play", "key_option", "key_edit"]:
		if Input.is_action_pressed(key):
			is_anything_pressed = true
			break

	# godot action to m8 controller
	if !m8_locally_controlled or m8_locally_controlled and is_anything_pressed:

		var keystate = 0

		if Input.is_action_pressed("key_up"): keystate += M8K_UP
		if Input.is_action_pressed("key_down"): keystate += M8K_DOWN
		if Input.is_action_pressed("key_left"): keystate += M8K_LEFT
		if Input.is_action_pressed("key_right"): keystate += M8K_RIGHT
		if Input.is_action_pressed("key_shift"): keystate += M8K_SHIFT
		if Input.is_action_pressed("key_play"): keystate += M8K_PLAY
		if Input.is_action_pressed("key_option"): keystate += M8K_OPTION
		if Input.is_action_pressed("key_edit"): keystate += M8K_EDIT

		update_keystate(keystate, true)

		m8_locally_controlled = false

	if Input.is_action_just_pressed("force_read"): m8_client.update_texture()

func update_keystate(keystate: int, write: bool=false):

	if keystate != m8_keystate_last:

		m8_keystate = keystate

		if write: m8_client.send_input(m8_keystate)
		# m8.send_input(m8_keystate)

		if m8_keystate&M8K_UP and !m8_keystate_last&M8K_UP: m8_key_changed.emit("up", true)
		if !m8_keystate&M8K_UP and m8_keystate_last&M8K_UP: m8_key_changed.emit("up", false)
		if m8_keystate&M8K_DOWN and !m8_keystate_last&M8K_DOWN: m8_key_changed.emit("down", true)
		if !m8_keystate&M8K_DOWN and m8_keystate_last&M8K_DOWN: m8_key_changed.emit("down", false)
		if m8_keystate&M8K_LEFT and !m8_keystate_last&M8K_LEFT: m8_key_changed.emit("left", true)
		if !m8_keystate&M8K_LEFT and m8_keystate_last&M8K_LEFT: m8_key_changed.emit("left", false)
		if m8_keystate&M8K_RIGHT and !m8_keystate_last&M8K_RIGHT: m8_key_changed.emit("right", true)
		if !m8_keystate&M8K_RIGHT and m8_keystate_last&M8K_RIGHT: m8_key_changed.emit("right", false)
		if m8_keystate&M8K_SHIFT and !m8_keystate_last&M8K_SHIFT: m8_key_changed.emit("shift", true)
		if !m8_keystate&M8K_SHIFT and m8_keystate_last&M8K_SHIFT: m8_key_changed.emit("shift", false)
		if m8_keystate&M8K_PLAY and !m8_keystate_last&M8K_PLAY: m8_key_changed.emit("play", true)
		if !m8_keystate&M8K_PLAY and m8_keystate_last&M8K_PLAY: m8_key_changed.emit("play", false)
		if m8_keystate&M8K_OPTION and !m8_keystate_last&M8K_OPTION: m8_key_changed.emit("option", true)
		if !m8_keystate&M8K_OPTION and m8_keystate_last&M8K_OPTION: m8_key_changed.emit("option", false)
		if m8_keystate&M8K_EDIT and !m8_keystate_last&M8K_EDIT: m8_key_changed.emit("edit", true)
		if !m8_keystate&M8K_EDIT and m8_keystate_last&M8K_EDIT: m8_key_changed.emit("edit", false)

		m8_keystate_last = m8_keystate

func _input(event):

	if event is InputEventKey:
		# fullscreen ALT+ENTER toggle
		if event.pressed and event.keycode == KEY_ENTER and event.alt_pressed:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
