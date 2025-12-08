@tool
extends MenuBase

@onready var s_audio_handler: SettingBase = %Setting_AudioHandler
@onready var s_volume: SettingBase = %Setting_Volume
@onready var le_audio_driver: LineEdit = %LineEditAudioDriver
@onready var le_audio_rate: LineEdit = %LineEditAudioRate
@onready var le_audio_latency: LineEdit = %LineEditAudioLatency
@onready var s_sa_enable: SettingBase = %Setting_SAEnable
@onready var s_sa_min: SettingBase = %Setting_SAMin
@onready var s_sa_max: SettingBase = %Setting_SAMax

func _menu_init() -> void:
	s_audio_handler.setting_connect_global("audio_handler", func(value: int) -> void:
		main.audio_set_handler(value)
	)

	s_volume.setting_connect_global("volume", func(value: float) -> void:
		var volume: float = pow(value, 2)
		main.audio_set_volume(volume)
	)

	var audio_latency_update_timer := Timer.new()
	add_child(audio_latency_update_timer)
	audio_latency_update_timer.start(1.0)
	audio_latency_update_timer.timeout.connect(func() -> void:
		if visible:
			le_audio_driver.placeholder_text = main.device_manager.audio_get_driver_name()
			le_audio_rate.placeholder_text = "%d Hz" % main.device_manager.audio_get_mix_rate()
			le_audio_latency.placeholder_text = "%.2f ms" % main.device_manager.audio_get_latency()
	)

	s_sa_enable.setting_connect_global("audio_analyzer_enabled", func(value: bool) -> void:
		main.audio_set_spectrum_analyzer_enabled(value)
	)
	s_sa_min.setting_connect_global("audio_analyzer_min_freq", func(value: int) -> void:
		main.visualizer_frequency_min = value
	)
	s_sa_max.setting_connect_global("audio_analyzer_max_freq", func(value: int) -> void:
		main.visualizer_frequency_max = value
	)

