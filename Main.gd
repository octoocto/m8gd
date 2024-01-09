extends CenterContainer

## The name of the M8 audio input device as shown in the system.
const INPUT_DEVICE_NAME = "Digital Audio Interface (M8)"

@export var visualizer_ca_amount = 1.0
@export var visualizer_glow_amount = 0.5
@export var visualizer_brightness_amount = 0.1

@onready var audio_monitor: AudioStreamPlayer = %AudioInputMonitor


var last_peak := 0.0


func _ready():
	_audio_monitor_check()
	if not _is_m8_detected():
		print("M8 not detected. Please connect it to monitor audio.")


func _physics_process(delta):
	_audio_monitor_check()
	
	var peak = db_to_linear((AudioServer.get_bus_peak_volume_left_db(0, 0) + AudioServer.get_bus_peak_volume_right_db(0, 0)) / 2.0)
	var avg_peak = (peak + last_peak) / 2.0
	last_peak = avg_peak
	
	var material: ShaderMaterial = $ColorRect.material
	material.set_shader_parameter("ca_amount", avg_peak * visualizer_ca_amount)
	
	if %M8Scene is CRT_Scene:
		%M8Scene.crt_glow_amount = 1.0 + (avg_peak * visualizer_glow_amount)
		%M8Scene.brightness = 1.0 + (avg_peak * visualizer_brightness_amount)


func _audio_monitor_check():
	# If the M8 device is plugged in and detected, use it as a microphone and
	# playback to the default audio output device.
	if AudioServer.input_device != INPUT_DEVICE_NAME and INPUT_DEVICE_NAME in AudioServer.get_input_device_list():
		AudioServer.input_device = INPUT_DEVICE_NAME
		audio_monitor.stream = AudioStreamMicrophone.new()
		audio_monitor.playing = true
		print("M8 detected. Monitoring audio...")
		
	elif !INPUT_DEVICE_NAME in AudioServer.get_input_device_list():
		AudioServer.input_device = "Default"
		audio_monitor.playing = false
		if audio_monitor.stream != null:
			audio_monitor.stream = null
			print("M8 disconnected.")
			
func _is_m8_detected():
	return INPUT_DEVICE_NAME in AudioServer.get_input_device_list()
