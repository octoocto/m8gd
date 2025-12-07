@tool
extends MenuBase

const ICON_WARNING := preload("res://assets/icon/StatusWarning.png")

var show_all_serial_ports: bool = false
var show_all_audio_devices: bool = false

@onready var list_serial_ports: ItemList = %ListSerialPorts
@onready var check_box_show_all_serial_ports: CheckBox = %CheckBoxShowAllSerialPorts
@onready var button_serial_status: Button = %SerialPortStatus
@onready var button_serial_refresh: Button = %ButtonRefreshSerialPorts
@onready var button_serial_connect: Button = %ButtonConnectSerialPort

@onready var list_audio_devices: ItemList = %ListAudioDevices
@onready var check_box_show_all_audio_devices: CheckBox = %CheckBoxShowAllAudioDevices
@onready var button_audio_status: Button = %AudioDeviceStatus
@onready var button_audio_refresh: Button = %ButtonRefreshAudioDevices
@onready var button_audio_connect: Button = %ButtonConnectAudioDevice

func get_tab_title() -> String:
	return "Devices"

##
## Setup the device connection menu controls.
##
func _menu_init() -> void:
	# serial ports
	refresh_serial_device_list()

	var fn_update_buttons := func() -> void:
		button_serial_connect.text = "Connect"
		button_serial_connect.disabled = false
		if len(list_serial_ports.get_selected_items()) == 0:
			button_serial_connect.disabled = true
			return

		var index := list_serial_ports.get_selected_items()[0]

		if main.device_manager.current_serial_device == list_serial_ports.get_item_metadata(index):
			button_serial_connect.text = "Disconnect"

	list_serial_ports.item_selected.connect(func(_index: int) -> void:
		fn_update_buttons.call()
	)

	list_serial_ports.empty_clicked.connect(func() -> void:
		list_serial_ports.deselect_all()
		fn_update_buttons.call()
	)

	check_box_show_all_serial_ports.toggled.connect(func(checked: bool) -> void:
		show_all_serial_ports = checked
		refresh_serial_device_list()
		fn_update_buttons.call()
	)

	button_serial_refresh.pressed.connect(refresh_audio_device_list)

	button_serial_connect.pressed.connect(func() -> void:
		var index: int = list_serial_ports.get_selected_items()[0]
		var port: String = list_serial_ports.get_item_metadata(index)

		if main.device_manager.current_serial_device == port:
			main.device_manager.disconnect_serial_device()
		else:
			await main.device_manager.connect_serial_device(port, true)

		refresh_serial_device_list()
		refresh_audio_device_list()
		fn_update_buttons.call()
	)

	# audio devices

	var fn_update_audio_buttons := func() -> void:
		button_audio_connect.text = "Connect"
		button_audio_connect.disabled = false

		if len(list_audio_devices.get_selected_items()) == 0:
			button_audio_connect.disabled = true
			return

		var index := list_audio_devices.get_selected_items()[0]

		if main.device_manager.current_audio_device == list_audio_devices.get_item_text(index):
			button_audio_connect.text = "Disconnect"

	refresh_audio_device_list()

	list_audio_devices.item_selected.connect(func(_index: int) -> void:
		fn_update_audio_buttons.call()
	)

	check_box_show_all_audio_devices.toggled.connect(func(checked: bool) -> void:
		show_all_audio_devices = checked
		refresh_audio_device_list()
		fn_update_audio_buttons.call()
	)

	button_audio_refresh.pressed.connect(refresh_audio_device_list)

	button_audio_connect.pressed.connect(func() -> void:
		var index: int = list_audio_devices.get_selected_items()[0]
		var text: String = list_audio_devices.get_item_text(index)
		if main.device_manager.current_audio_device == text:
			main.device_manager.disconnect_audio_device()
		else:
			await main.device_manager.connect_audio_device(text, show_all_audio_devices)
		refresh_audio_device_list()
		fn_update_audio_buttons.call()
	)

	get_tree().process_frame.connect(func() -> void:
		if main and main.is_menu_open():
			var volume := main.audio_get_peak_volume()
			%Bar_AudioLevelL.value = max(-1000, volume.x)
			%Bar_AudioLevelR.value = max(-1000, volume.y)
	)

	# auto refresh list
	visibility_changed.connect(func() -> void:
		if visible:
			refresh_serial_device_list()
			refresh_audio_device_list()
			for item: int in list_audio_devices.get_selected_items():
				list_audio_devices.item_selected.emit(item)
			for item: int in list_serial_ports.get_selected_items():
				list_serial_ports.item_selected.emit(item)
	)

func set_status_serialport(text: String) -> void:
	%SerialPortStatus.text = text

func set_status_audiodevice(text: String) -> void:
	%AudioDeviceStatus.text = text

##
## Refresh the serial device list UI.
##
func refresh_serial_device_list() -> void:
	list_serial_ports.clear()

	for port_name in M8GD.list_devices(show_all_serial_ports):
		# var port_desc := M8GD.get_serial_port_description(port_name)
		var index := list_serial_ports.add_item("%s" % [port_name])
		list_serial_ports.set_item_metadata(index, port_name)
		if not M8GD.is_m8_serial_port(port_name):
			list_serial_ports.set_item_icon(index, ICON_WARNING)
			list_serial_ports.set_item_tooltip(index,
				"This port might not be an M8 device."
			)

	for i in range(list_serial_ports.item_count):
		if list_serial_ports.get_item_metadata(i) == main.device_manager.current_serial_device:
			list_serial_ports.select(i)
			list_serial_ports.set_item_custom_bg_color(i, Color.DARK_GREEN)
			break
		elif list_serial_ports.get_item_metadata(i) == main.device_manager.last_serial_device:
			list_serial_ports.select(i)
			break


##
## Refresh the audio device list UI.
##
func refresh_audio_device_list() -> void:
	list_audio_devices.clear()

	for device in main.device_manager.list_audio_devices(show_all_audio_devices):
		list_audio_devices.add_item(device)

	for i in range(list_audio_devices.item_count):
		if list_audio_devices.get_item_text(i) == main.device_manager.current_audio_device:
			list_audio_devices.select(i)
			list_audio_devices.item_selected.emit(i)
			list_audio_devices.set_item_custom_bg_color(i, Color.DARK_GREEN)
			break
		elif list_audio_devices.get_item_text(i) == main.device_manager.last_audio_device:
			list_audio_devices.select(i)
			list_audio_devices.item_selected.emit(i)
			break

