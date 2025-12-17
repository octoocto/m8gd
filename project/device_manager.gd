## Manages M8 serial and audio device connections.
class_name DeviceManager

enum AudioHandler { GODOT, SDL }

const AUDIO_BUFFER_SIZE := 1024
const DEVICE_SCAN_INTERVAL := 5.0

var main: Main

var audio_handler: AudioHandler = AudioHandler.GODOT

var audio_monitor: AudioStreamPlayer

var current_serial_device: String = ""
var current_audio_device: String = ""
var last_serial_device: String = ""
var last_audio_device: String = ""

var is_waiting_for_serial_device := false
var is_waiting_for_audio_device := false
var next_device_scan := 0.0

var is_audio_connecting := false


func _process(delta: float) -> void:
	if next_device_scan <= 0.0:
		# scan for serial ports
		if not is_serial_device_connected() and is_waiting_for_serial_device:
			print("serial: scanning for serial ports...")
			connect_serial_device()

		# scan for audio devices
		if is_audio_device_connected():
			check_audio_device()
		elif is_serial_device_connected() and is_waiting_for_audio_device:
			print("audio: scanning for audio devices...")
			connect_audio_device()

		next_device_scan = DEVICE_SCAN_INTERVAL
	else:
		next_device_scan -= delta


func init(main: Main) -> void:
	self.main = main
	self.audio_monitor = main.audio_monitor


func start_waiting_for_devices() -> void:
	is_waiting_for_serial_device = true
	is_waiting_for_audio_device = true


func stop_waiting_for_devices() -> void:
	is_waiting_for_serial_device = false
	is_waiting_for_audio_device = false


func list_serial_devices(show_all: bool = false) -> Array[String]:
	return M8GD.list_devices(show_all)


func connect_serial_device(port: String = "", force: bool = false) -> void:
	if port == "":
		if len(list_serial_devices()) > 0:
			port = list_serial_devices()[0]
		else:
			print("serial: no M8 serial ports found")
			main.print_to_screen("No valid M8 devices found! Waiting for device...")
			main.menu.menu_devices.set_status_serialport("Not connected: no valid M8 devices found")
			is_waiting_for_serial_device = true
			return

	disconnect_serial_device()

	if not main.m8_client.connect(port, force):
		print("serial: failed to connect to port: %s", port)
		main.menu.menu_devices.set_status_serialport(
			"Not connected: failed to connect to port: %s" % port
		)
		is_waiting_for_serial_device = false
		return

	current_serial_device = port
	last_serial_device = port
	main.m8_connected.emit()
	Events.serial_device_connected.emit()

	print("serial: connected to port: %s" % port)
	main.print_to_screen("connected to serial port: %s" % port)
	main.menu.menu_devices.set_status_serialport("Connected to: %s" % port)

	await connect_audio_device()


func disconnect_serial_device() -> void:
	if not is_serial_device_connected():
		return

	main.m8_client.disconnect()
	current_serial_device = ""
	main.m8_disconnected.emit()

	main.print_to_screen("disconnected serial device")
	main.menu.menu_devices.set_status_serialport("Not connected (Disconnected)")

	disconnect_audio_device()


func is_serial_device_connected() -> bool:
	return current_serial_device != ""


func list_audio_devices(show_all: bool = false) -> Array[String]:
	var devices: Array[String] = []
	if audio_handler == AudioHandler.SDL:
		for dev: String in main.m8_client.sdl_audio_get_audio_input_devices(show_all):
			devices.append(dev)
	else:
		for dev in AudioServer.get_input_device_list():
			if show_all or dev.contains("M8"):
				devices.append(dev)
	return devices


## Connect to and monitor an audio input device with name [device].
## If [device] is empty, automatically connect to a valid M8 audio input device.
func connect_audio_device(device: String = "", force: bool = false) -> void:
	if device == "":
		if len(list_audio_devices()) > 0:
			device = list_audio_devices()[0]
		else:
			print("audio: no M8 audio devices found")
			main.menu.menu_devices.set_status_audiodevice("Not connected: no M8 audio device found")
			return

	if not device in list_audio_devices(force):
		print("audio: audio device not found: %s" % device)
		main.menu.menu_devices.set_status_audiodevice(
			"Not connected: audio device not found: %s" % device
		)
		return

	if is_audio_connecting:
		return

	is_audio_connecting = true

	disconnect_audio_device()

	print("audio: initializing audio using handler: %s" % AudioHandler.keys()[audio_handler])

	match audio_handler:
		AudioHandler.GODOT:
			# delay
			await main.get_tree().create_timer(0.1).timeout

			# connect to input device
			print("audio: connecting new input device: %s" % device)
			AudioServer.input_device = device

			print("audio: adding audio monitor")
			audio_monitor = AudioStreamPlayer.new()
			audio_monitor.stream = AudioStreamMicrophone.new()
			audio_monitor.bus = "Analyzer"
			main.add_child(audio_monitor)

			# delay
			main.menu.menu_devices.set_status_audiodevice("Starting...")
			await main.get_tree().create_timer(0.1).timeout

			audio_monitor.playing = true
			current_audio_device = device

		AudioHandler.SDL:
			print("audio: initializing SDL audio")
			if not main.m8_client.sdl_audio_init(AUDIO_BUFFER_SIZE, "", device):
				print("audio: failed to connect to device %s" % device)
				main.menu.menu_devices.set_status_audiodevice(
					"Not connected: failed to connect to: %s" % device
				)
				is_audio_connecting = false
				return

	current_audio_device = device
	last_audio_device = device
	is_audio_connecting = false
	is_waiting_for_audio_device = true  # auto connect again if there are any random disconnects
	print("audio: connected to device %s" % device)
	main.print_to_screen(
		"connected to audio device (%s): %s" % [AudioHandler.keys()[audio_handler], device]
	)
	main.menu.menu_devices.set_status_audiodevice("Connected to: %s" % device)
	Events.audio_device_connected.emit()


func disconnect_audio_device() -> void:
	if not is_audio_device_connected():
		return

	# disconnect current input device
	if AudioServer.input_device != "":
		print("audio: disconnecting current input device")
		AudioServer.input_device = ""

	# remove current audio monitor
	if is_instance_valid(audio_monitor):
		print("audio: removing audio monitor")
		main.remove_child(audio_monitor)
		audio_monitor.playing = false
		audio_monitor.stream = null
		audio_monitor.queue_free()
		audio_monitor = null

	# disconnect audio device (SDL)
	if main.m8_client.sdl_audio_is_initialized():
		print("audio: shutting down SDL audio")
		main.m8_client.sdl_audio_shutdown()

	current_audio_device = ""
	is_waiting_for_audio_device = false
	main.print_to_screen("disconnected audio device")
	main.menu.menu_devices.set_status_audiodevice("Not connected")


func reset_audio_device() -> void:
	if is_audio_device_connected():
		disconnect_audio_device()
		connect_audio_device(last_audio_device)


func is_audio_device_connected() -> bool:
	return current_audio_device != ""


## Check if the audio device is still connected. If not, disconnect.
func check_audio_device() -> void:
	if is_audio_connecting:
		return

	if audio_handler == AudioHandler.GODOT and is_instance_valid(audio_monitor):
		if !AudioServer.input_device in AudioServer.get_input_device_list():
			print("audio: input device no longer connected")
			disconnect_audio_device()

		if !audio_monitor.playing or audio_monitor.stream_paused:
			print("audio: stream stopped, reconnecting...")
			connect_audio_device(current_audio_device)


func audio_set_handler(handler: AudioHandler) -> void:
	if handler == audio_handler:
		return

	audio_handler = handler
	print("audio: setting audio handler to %s" % AudioHandler.keys()[audio_handler])

	reset_audio_device()


func audio_set_volume(volume: float) -> void:
	AudioServer.set_bus_volume_linear(0, volume)
	main.m8_client.sdl_audio_set_volume(volume)


func audio_get_peak_volume() -> Vector2:
	match audio_handler:
		AudioHandler.GODOT:
			return Vector2(
				AudioServer.get_bus_peak_volume_left_db(0, 0),
				AudioServer.get_bus_peak_volume_right_db(0, 0)
			)
		AudioHandler.SDL:
			return main.m8_client.sdl_audio_get_peak_volume()
	return Vector2.ZERO


func audio_get_driver_name() -> String:
	match audio_handler:
		AudioHandler.GODOT:
			return AudioServer.get_driver_name()
			# return ProjectSettings.get_setting("audio/driver/driver")
		AudioHandler.SDL:
			return main.m8_client.sdl_audio_get_driver_name()
	return ""


func audio_get_mix_rate() -> float:
	match audio_handler:
		AudioHandler.GODOT:
			return AudioServer.get_mix_rate()
		AudioHandler.SDL:
			return float(main.m8_client.sdl_audio_get_mix_rate())
	return 0.0


func audio_get_latency() -> float:
	match audio_handler:
		AudioHandler.GODOT:
			return AudioServer.get_output_latency()
		AudioHandler.SDL:
			return float(main.m8_client.sdl_audio_get_latency())
	return 0.0
