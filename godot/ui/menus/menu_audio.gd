@tool
extends MenuBase

@onready var s_audio_handler: SettingBase = %Setting_AudioHandler
@onready var s_volume: SettingBase = %Setting_Volume
@onready var l_audio_driver: UILabel2 = %LabelAudioDriver
@onready var l_audio_format: UILabel2 = %LabelAudioFormat
@onready var l_audio_channels: UILabel2 = %LabelAudioChannels
@onready var l_audio_rate: UILabel2 = %LabelAudioRate
@onready var l_audio_buffer: UILabel2 = %LabelAudioBuffer
@onready var l_audio_latency: UILabel2 = %LabelAudioLatency
@onready var s_sa_enable: SettingBase = %Setting_SAEnable


func _on_menu_init() -> void:
	s_audio_handler.setting_connect_global(
		"audio_handler",
		func(value: int) -> void:
			main.device_manager.audio_set_handler(value),
	)

	s_volume.setting_connect_global(
		"volume",
		func(value: float) -> void:
			var volume: float = pow(value, 2)
			main.m8c.set_volume(volume),
	)

	var audio_latency_update_timer := Timer.new()
	add_child(audio_latency_update_timer)
	audio_latency_update_timer.start(1.0)
	audio_latency_update_timer.timeout.connect(
		func() -> void:
			if visible:
				var spec := self.main.m8c.get_audio_spec()
				l_audio_driver.text = spec["driver_name"]
				l_audio_format.text = spec["format"]
				l_audio_channels.text = "%d" % spec["num_channels"]
				l_audio_rate.text = "%d Hz" % spec["sample_rate"]
				l_audio_buffer.text = "%d" % spec["buffer_size"]
				l_audio_latency.text = "%.2f ms" % spec["latency_ms"],
	)

	s_sa_enable.setting_connect_global(
		"audio_analyzer_enabled",
		func(value: bool) -> void:
			main.m8c.set_spectrum_analyzer_enabled(value),
	)
