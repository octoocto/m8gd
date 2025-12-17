@tool
extends MenuBase

enum ConnectAction { CONNECT, DISCONNECT, RECONNECT }

@onready var label_serial_status: UILabel2 = %LabelSerialStatus
@onready var label_audio_status: UILabel2 = %LabelAudioStatus
@onready var list_serial_ports: ItemList = %ListSerialPorts
@onready var list_audio_devices: ItemList = %ListAudioDevices
@onready var button_refresh: UIButton = %ButtonRefresh
@onready var button_connect: UIButton = %ButtonConnect

@onready var s_show_all_devices: SettingBool = %SShowAllDevices

var dm: DeviceManager

var selected_serial_port: String = ""
var selected_audio_device: String = ""
var show_all_devices: bool:
	get():
		return s_show_all_devices.value
var connect_action := ConnectAction.CONNECT


func get_tab_title() -> String:
	return "Devices"


func _on_refresh() -> void:
	refresh_device_list()


##
## Setup the device connection menu controls.
##
func _on_menu_init() -> void:
	dm = main.device_manager

	Events.serial_device_connected.connect(func() -> void: _on_changed())
	Events.audio_device_connected.connect(func() -> void: _on_changed())

	list_serial_ports.item_selected.connect(func(_index: int) -> void: _on_changed())
	list_audio_devices.item_selected.connect(func(_index: int) -> void: _on_changed())

	button_connect.pressed.connect(
		func() -> void:
			if connect_action == ConnectAction.DISCONNECT:
				dm.disconnect_audio_device()
				dm.disconnect_serial_device()
				dm.stop_waiting_for_devices()
				_on_changed()
				return

			if selected_serial_port and selected_serial_port != dm.current_serial_device:
				if dm.current_serial_device:
					dm.disconnect_serial_device()
				dm.connect_serial_device(selected_serial_port, show_all_devices)

			if selected_audio_device and selected_audio_device != dm.current_audio_device:
				if dm.current_audio_device:
					dm.disconnect_audio_device()
				dm.connect_audio_device(selected_audio_device, show_all_devices)

			_on_changed()
	)

	button_refresh.pressed.connect(
		func() -> void:
			_on_refresh()
			_on_changed()
	)

	s_show_all_devices.value_changed.connect(
		func(_value: bool) -> void:
			_on_refresh()
			_on_changed()
	)

	_on_refresh()
	_on_changed()

	get_tree().process_frame.connect(
		func() -> void:
			if main and main.is_menu_open():
				var volume := main.audio_get_peak_volume()
				%Bar_AudioLevelL.value = max(-1000, volume.x)
				%Bar_AudioLevelR.value = max(-1000, volume.y)
	)

	# auto refresh list
	visibility_changed.connect(
		func() -> void:
			_on_refresh()
			_on_changed()
			# if visible:
			# 	for item: int in list_audio_devices.get_selected_items():
			# 		list_audio_devices.item_selected.emit(item)
			# 	for item: int in list_serial_ports.get_selected_items():
			# 		list_serial_ports.item_selected.emit(item)
	)


func _on_changed() -> void:
	if not dm:
		return

	print("Device menu changed")

	var selected_serial_ports := list_serial_ports.get_selected_items()
	var selected_audio_devices := list_audio_devices.get_selected_items()

	if (
		connect_action == ConnectAction.CONNECT
		and selected_serial_ports.size() == 0
		and selected_audio_devices.size() == 0
	):
		button_connect.enabled = false
	else:
		button_connect.enabled = true

	selected_serial_port = (
		list_serial_ports.get_item_metadata(selected_serial_ports[0])
		if selected_serial_ports.size()
		else ""
	)
	selected_audio_device = (
		list_audio_devices.get_item_metadata(selected_audio_devices[0])
		if selected_audio_devices.size()
		else ""
	)

	if dm.current_serial_device or dm.current_audio_device:
		if (
			selected_serial_port != dm.current_serial_device
			or selected_audio_device != dm.current_audio_device
		):
			button_connect.text = "Connect"
			connect_action = ConnectAction.CONNECT
		else:
			button_connect.text = "Disconnect"
			connect_action = ConnectAction.DISCONNECT
	else:
		button_connect.text = "Connect"
		connect_action = ConnectAction.CONNECT

	print("selected serial port: %s" % selected_serial_port)
	print("selected audio device: %s" % selected_audio_device)

	for i in range(list_serial_ports.item_count):
		var serial_device: String = list_serial_ports.get_item_metadata(i)
		if serial_device == main.device_manager.current_serial_device:
			list_serial_ports.set_item_text(i, "> %s" % serial_device)
		else:
			list_serial_ports.set_item_text(i, serial_device)

	for i in range(list_audio_devices.item_count):
		var audio_device: String = list_audio_devices.get_item_metadata(i)
		if audio_device == main.device_manager.current_audio_device:
			list_audio_devices.set_item_text(i, "> %s" % audio_device)
		else:
			list_audio_devices.set_item_text(i, audio_device)


func set_status_serialport(text: String) -> void:
	%LabelSerialStatus.text = text


func set_status_audiodevice(text: String) -> void:
	%LabelAudioStatus.text = text


func refresh_device_list() -> void:
	list_serial_ports.clear()
	list_audio_devices.clear()

	for device: String in dm.list_serial_devices(show_all_devices):
		var index := list_serial_ports.add_item(device)
		list_serial_ports.set_item_metadata(index, device)

		if not M8GD.is_m8_serial_port(device):
			list_serial_ports.set_item_icon(index, ICON_WARNING)
			list_serial_ports.set_item_tooltip(index, "This port might not be an M8 device.")

	for device: String in dm.list_audio_devices(show_all_devices):
		var index := list_audio_devices.add_item(device)
		list_audio_devices.set_item_metadata(index, device)

	for i in range(list_serial_ports.item_count):
		if list_serial_ports.get_item_metadata(i) == main.device_manager.current_serial_device:
			list_serial_ports.select(i)
			break
		elif list_serial_ports.get_item_metadata(i) == main.device_manager.last_serial_device:
			list_serial_ports.select(i)
			break

	for i in range(list_audio_devices.item_count):
		if list_audio_devices.get_item_text(i) == main.device_manager.current_audio_device:
			list_audio_devices.select(i)
			break
		elif list_audio_devices.get_item_text(i) == main.device_manager.last_audio_device:
			list_audio_devices.select(i)
			break
