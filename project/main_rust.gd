extends CenterContainer

const FONT_01_SMALL: BitMap = preload("res://assets/m8_fonts/5_7.bmp")
const FONT_01_BIG: BitMap = preload("res://assets/m8_fonts/8_9.bmp")
const FONT_02_SMALL: BitMap = preload("res://assets/m8_fonts/9_9.bmp")
const FONT_02_BOLD: BitMap = preload("res://assets/m8_fonts/10_10.bmp")
const FONT_02_HUGE: BitMap = preload("res://assets/m8_fonts/12_12.bmp")

@onready var texture_rect: TextureRect = %TextureRect
@onready var rect_peak_l: ProgressBar = %RectPeakL
@onready var rect_peak_r: ProgressBar = %RectPeakR
@onready var rect_peak_l2: ProgressBar = %RectPeakL2
@onready var rect_peak_r2: ProgressBar = %RectPeakR2
@onready var label_fps: Label = %LabelFPS
@onready var audio_spectrum: AudioSpectrum = %AudioSpectrum

@onready var osc_1: TrackOscilloscope = %Osc1
@onready var osc_2: TrackOscilloscope = %Osc2
@onready var osc_3: TrackOscilloscope = %Osc3
@onready var osc_4: TrackOscilloscope = %Osc4
@onready var osc_5: TrackOscilloscope = %Osc5
@onready var osc_6: TrackOscilloscope = %Osc6
@onready var osc_7: TrackOscilloscope = %Osc7
@onready var osc_8: TrackOscilloscope = %Osc8
@onready var osc_9: TrackOscilloscope = %Osc9
@onready var osc_10: TrackOscilloscope = %Osc10
@onready var osc_11: TrackOscilloscope = %Osc11

var m8c := GodotM8Client.new()
var timer: Timer


func _ready() -> void:
	add_child(m8c)
	_initialize_m8c()

	self.timer = Timer.new()
	add_child(self.timer)
	self.timer.wait_time = 1.0
	self.timer.one_shot = false
	self.timer.timeout.connect(_on_timer_timeout)
	self.timer.start()

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _initialize_m8c() -> void:
	var serial_ports := LibM8.list_serial_ports(true)

	print("valid serial ports:")
	print(serial_ports)

	if serial_ports.size() == 0:
		return

	m8c.connect_with_serial(serial_ports[0], true)

	if not m8c.is_connected():
		print("failed to connect to serial port: %s" % serial_ports[0])
		return

	m8c.audio_start("", "")
	m8c.system_info_received.connect(_on_receive_system_info)
	m8c.theme_colors_updated.connect(
		func(colors: PackedColorArray) -> void:
			print("received theme colors:")
			for color in colors:
				print("%s" % color.to_html(false).to_upper())
	)
	print("connected to serial port: %s" % serial_ports[0])
	audio_spectrum.m8c = m8c
	osc_1.init(m8c, 1)
	osc_2.init(m8c, 2)
	osc_3.init(m8c, 3)
	osc_4.init(m8c, 4)
	osc_5.init(m8c, 5)
	osc_6.init(m8c, 6)
	osc_7.init(m8c, 7)
	osc_8.init(m8c, 8)
	osc_9.init(m8c, 9)
	osc_10.init(m8c, 10)
	osc_11.init(m8c, 11)

	texture_rect.visibility_changed.connect(
		func(visible: bool) -> void:
			if is_instance_valid(m8c):
				m8c.set_display_enabled(visible)
	)


func _on_receive_system_info(_hardware: String, _firmware: String) -> void:
	var texture: ImageTexture = m8c.get_display_texture()
	# print("got display texture: %s" % str(texture))
	texture_rect.texture = texture


func _on_timer_timeout() -> void:
	label_fps.text = "FPS: %d" % Engine.get_frames_per_second()
	if not is_instance_valid(m8c):
		return
	# print("spectrum resolution: %d" % m8c.get_audio_freq_spectrum_resolution())


func _process(delta: float) -> void:
	if not is_instance_valid(m8c):
		return

	var peaks := m8c.get_audio_peak_volume()
	peaks.x = remap(linear_to_db(peaks.x), -60.0, 0.0, 0.0, 1.0)
	peaks.y = remap(linear_to_db(peaks.y), -60.0, 0.0, 0.0, 1.0)

	var smoothing := 0.8
	var smoothing_2 := 0.1

	rect_peak_l.value = max(peaks.x, lerp(peaks.x, rect_peak_l.value, smoothing))
	rect_peak_r.value = max(peaks.y, lerp(peaks.y, rect_peak_r.value, smoothing))

	rect_peak_l2.value = max(rect_peak_l.value, rect_peak_l2.value - (smoothing_2 * delta))
	rect_peak_r2.value = max(rect_peak_r.value, rect_peak_r2.value - (smoothing_2 * delta))


func _input(event: InputEvent) -> void:
	if not is_instance_valid(m8c):
		return

	if event is InputEventKey:
		var e := event as InputEventKey
		# if e.is_pressed():
		# if e.keycode == KEY_DOWN:
		# m8c.set_volume(m8c.get_volume() - 0.05)
		# if e.keycode == KEY_UP:
		# m8c.set_volume(m8c.get_volume() + 0.05)
		match e.keycode:
			KEY_1:
				if e.is_pressed():
					m8c.set_spectrum_analyzer_enabled(not m8c.is_spectrum_analyzer_enabled())
					print("spectrum analyzer enabled: %s" % str(m8c.is_spectrum_analyzer_enabled()))
			KEY_DOWN:
				m8c.set_key_pressed(LibM8.KEY_DOWN, e.is_pressed())
			KEY_UP:
				m8c.set_key_pressed(LibM8.KEY_UP, e.is_pressed())
			KEY_LEFT:
				m8c.set_key_pressed(LibM8.KEY_LEFT, e.is_pressed())
			KEY_RIGHT:
				m8c.set_key_pressed(LibM8.KEY_RIGHT, e.is_pressed())
			# KEY_A:
			# 	if e.is_pressed():
			# 		m8c.set_audio_enabled(not m8c.is_audio_enabled())
