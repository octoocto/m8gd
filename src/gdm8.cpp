#include "gdm8.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <bitset>

void M8GDClient::on_disconnect()
{
	// print("disconnecting from port");
	m8gd->display_buffer->clear(0, 0, 0);
	m8gd->copy_buffer_to_texture();
	m8gd->emit_signal("disconnected");
}

void M8GDClient::on_draw_rect(
	uint16_t x, uint16_t y,
	uint16_t w, uint16_t h,
	uint8_t r, uint8_t g, uint8_t b)
{
	bool theme_completed = m8gd->display_buffer->colors.size() == 13;
	uint8_t bg_r = m8gd->display_buffer->bg_r;
	uint8_t bg_g = m8gd->display_buffer->bg_g;
	uint8_t bg_b = m8gd->display_buffer->bg_b;

	m8gd->display_buffer->draw_rect(x, y, w, h, r, g, b);

	if (!theme_completed)
	{
		if (m8gd->display_buffer->colors.size() == 13)
		{
			// theme updated
			m8gd->emit_signal("theme_changed", m8gd->get_theme_colors(), true);
		}
		else if (bg_r != m8gd->display_buffer->bg_r ||
				 bg_g != m8gd->display_buffer->bg_g ||
				 bg_b != m8gd->display_buffer->bg_b)
		{
			// background color changed
			m8gd->emit_signal("theme_changed", m8gd->get_theme_colors(), false);
		}
	}
}

void M8GDClient::on_draw_char(
	char c,
	uint16_t x, uint16_t y,
	uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
	uint8_t bg_r, uint8_t bg_g, uint8_t bg_b)
{
	m8gd->display_buffer->draw_char(c, x, y, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b);
}

void M8GDClient::on_draw_waveform(
	uint16_t x, uint16_t y,
	uint8_t r, uint8_t g, uint8_t b,
	const uint8_t *points, uint16_t size)
{
	m8gd->display_buffer->draw_waveform(x, y, r, g, b, points, size);
}

void M8GDClient::on_key_pressed(uint8_t keybits)
{
	// m8gd->emit_signal("keystate_changed", (int)keybits);

	static uint8_t last_keybits = 0;

	if (keybits != last_keybits)
	{
		m8gd->keybits = keybits;
		for (const M8Key key : M8_KEYS)
		{
			// detect press
			if (!(last_keybits & key) && keybits & key)
			{
				m8gd->emit_signal("key_pressed", key, true);
			}
			// detect unpress
			if (last_keybits & key && !(keybits & key))
			{
				m8gd->emit_signal("key_pressed", key, false);
			}
		}
		last_keybits = keybits;
	}
}

void M8GDClient::on_system_info(
	libm8::HardwareModel model,
	uint8_t fw_major, uint8_t fw_minor, uint8_t fw_patch,
	libm8::Font font)
{
	m8gd->set_model(model, fw_major, fw_minor, fw_patch, font);
}

void M8GD::_bind_methods()
{
	ADD_SIGNAL(MethodInfo("system_info", PropertyInfo(Variant::STRING, "hardware"), PropertyInfo(Variant::STRING, "firmware")));
	ADD_SIGNAL(MethodInfo("font_changed", PropertyInfo(Variant::INT, "font")));
	ADD_SIGNAL(MethodInfo("theme_changed", PropertyInfo(Variant::PACKED_COLOR_ARRAY, "colors"), PropertyInfo(Variant::BOOL, "complete")));
	ADD_SIGNAL(MethodInfo("key_pressed", PropertyInfo(Variant::INT, "keycode"), PropertyInfo(Variant::BOOL, "pressed")));
	ADD_SIGNAL(MethodInfo("disconnected"));

	BIND_ENUM_CONSTANT(M8_KEY_UP);
	BIND_ENUM_CONSTANT(M8_KEY_DOWN);
	BIND_ENUM_CONSTANT(M8_KEY_LEFT);
	BIND_ENUM_CONSTANT(M8_KEY_RIGHT);
	BIND_ENUM_CONSTANT(M8_KEY_OPTION);
	BIND_ENUM_CONSTANT(M8_KEY_EDIT);
	BIND_ENUM_CONSTANT(M8_KEY_SHIFT);
	BIND_ENUM_CONSTANT(M8_KEY_PLAY);

	BIND_ENUM_CONSTANT(M8_FONT_01_SMALL);
	BIND_ENUM_CONSTANT(M8_FONT_01_BIG);
	BIND_ENUM_CONSTANT(M8_FONT_02_SMALL);
	BIND_ENUM_CONSTANT(M8_FONT_02_BOLD);
	BIND_ENUM_CONSTANT(M8_FONT_02_HUGE);

	ClassDB::bind_static_method("M8GD", D_METHOD("list_devices", "show_all"), &M8GD::list_devices);
	ClassDB::bind_static_method("M8GD", D_METHOD("is_m8_serial_port", "port_name"), &M8GD::is_m8_serial_port);
	ClassDB::bind_static_method("M8GD", D_METHOD("get_serial_port_description", "port_name"), &M8GD::get_serial_port_description);

	ClassDB::bind_method(D_METHOD("connect", "device", "force"), &M8GD::connect, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("is_connected"), &M8GD::is_connected);
	ClassDB::bind_method(D_METHOD("disconnect"), &M8GD::disconnect);
	ClassDB::bind_method(D_METHOD("get_hardware_name"), &M8GD::get_hardware_name);
	ClassDB::bind_method(D_METHOD("get_firmware_version"), &M8GD::get_firmware_version);

	ClassDB::bind_method(D_METHOD("is_key_pressed"), &M8GD::is_key_pressed);
	ClassDB::bind_method(D_METHOD("get_key_state"), &M8GD::get_key_state);
	ClassDB::bind_method(D_METHOD("set_key_pressed", "key", "pressed"), &M8GD::set_key_pressed);
	ClassDB::bind_method(D_METHOD("set_key_state", "keybits"), &M8GD::set_key_state);
	ClassDB::bind_method(D_METHOD("send_keyjazz", "note", "velocity"), &M8GD::send_keyjazz);

	ClassDB::bind_method(D_METHOD("get_display"), &M8GD::get_display);
	ClassDB::bind_method(D_METHOD("set_display_background_alpha", "alpha"), &M8GD::set_background_alpha);
	ClassDB::bind_method(D_METHOD("get_display_pixel", "x", "y"), &M8GD::get_pixel);
	ClassDB::bind_method(D_METHOD("get_theme_colors"), &M8GD::get_theme_colors);
	ClassDB::bind_method(D_METHOD("set_theme_color", "index", "color"), &M8GD::set_theme_color);
	ClassDB::bind_method(D_METHOD("load_font", "font_type", "bitmap"), &M8GD::load_font);

	ClassDB::bind_method(D_METHOD("send_enable_display"), &M8GD::send_enable_display);
	ClassDB::bind_method(D_METHOD("send_disable_display"), &M8GD::send_disable_display);
	ClassDB::bind_method(D_METHOD("send_reset_display"), &M8GD::reset_display);

	ClassDB::bind_method(D_METHOD("sdl_audio_init", "audio_buffer_size", "output_device_name", "input_device_name"), &M8GD::sdl_audio_init, DEFVAL(""), DEFVAL(""), DEFVAL(1024));
	ClassDB::bind_method(D_METHOD("sdl_audio_shutdown"), &M8GD::sdl_audio_shutdown);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_peak_volume"), &M8GD::sdl_audio_get_peak_volume);
	ClassDB::bind_method(D_METHOD("sdl_audio_is_initialized"), &M8GD::sdl_audio_is_initialized);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_volume"), &M8GD::sdl_audio_get_volume);
	ClassDB::bind_method(D_METHOD("sdl_audio_set_volume", "volume"), &M8GD::sdl_audio_set_volume);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_driver_name"), &M8GD::sdl_audio_get_driver_name);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_format_name"), &M8GD::sdl_audio_get_format_name);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_buffer_size"), &M8GD::sdl_audio_get_buffer_size);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_latency"), &M8GD::sdl_audio_get_latency);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_mix_rate"), &M8GD::sdl_audio_get_mix_rate);
	ClassDB::bind_method(D_METHOD("sdl_audio_get_audio_input_devices", "show_all"), &M8GD::sdl_audio_get_audio_input_devices, DEFVAL(false));
}

M8GD::M8GD()
{
	display_buffer = nullptr;
	set_display_size(320, 240);
}

M8GD::~M8GD()
{
	delete display_buffer;
	disconnect();
}

void M8GD::_process(double delta)
{
	if (m8_client.is_connected())
	{
		read();
		copy_buffer_to_texture();
	}
}

bool M8GD::is_connected()
{
	return m8_client.is_connected();
}

bool M8GD::connect(String target_port_name, bool force)
{
	print("connecting to port \"%s\"...", target_port_name);

	libm8::Error error = m8_client.connect(target_port_name, force);

	if (error == libm8::OK)
	{
		print("connected to port \"%s\"!", target_port_name);
		return true;
	}

	return false;
}

void M8GD::disconnect()
{
	if (m8_client.is_connected())
	{
		libm8::Error error = m8_client.disconnect();

		if (error == libm8::OK)
		{
			print("disconnected!");
		}
		else
		{
			printerr("error when trying to disconnect: %d", error);
		}
	}
}

void M8GD::set_key_pressed(M8Key key, bool pressed)
{
	bool changed = false;
	if (keybits & key && !pressed)
	{
		keybits = keybits & ~key; // set bit to 0
		changed = true;
	}
	else if (!(keybits & key) && pressed)
	{
		keybits = keybits | key; // set bit to 1
		changed = true;
	}
	if (changed)
	{
		if (keybits == M8_KEY_UP + M8_KEY_DOWN + M8_KEY_LEFT + M8_KEY_RIGHT)
		{
			reset_display();
		}
		else
		{
			m8_client.send_control_keys(keybits);
		}
	}
}

void M8GD::set_key_state(uint8_t keybits)
{
	// only receive 0b00000000 (no keys pressed) if previous call had a key press.
	// fixes issues with mixed input from both local and remote.
	if (keybits != this->keybits)
	{
		this->keybits = keybits;
		if (keybits == M8_KEY_UP + M8_KEY_DOWN + M8_KEY_LEFT + M8_KEY_RIGHT)
		{
			reset_display();
		}
		else
		{
			m8_client.send_control_keys(keybits);
		}
	}
}

void M8GD::set_model(libm8::HardwareModel model)
{
	if (model == libm8::MODEL_02)
	{
		set_display_size(libm8::RES_MODEL_02[0], libm8::RES_MODEL_02[1]);
	}
	else // model 01 res also applies to beta and headless
	{
		set_display_size(libm8::RES_MODEL_01[0], libm8::RES_MODEL_01[1]);
	}
	sys_model = int(model);
}

void M8GD::set_model(libm8::HardwareModel model,
					 uint8_t fw_1, uint8_t fw_2, uint8_t fw_3, uint8_t font)
{
	static uint8_t font_last = 0xFF;

	switch (model)
	{
	case libm8::MODEL_HEADLESS:
		sys_hardware = "headless";
		break;
	case libm8::MODEL_BETA:
		sys_hardware = "beta";
		break;
	case libm8::MODEL_01:
		sys_hardware = "model_01";
		break;
	case libm8::MODEL_02:
		sys_hardware = "model_02";
		break;
	}

	sys_firmware = godot::vformat("%d.%d.%d", fw_1, fw_2, fw_3);

	// resize display buffer if different model
	if ((int)model != sys_model)
	{
		set_model(model);
		emit_signal("system_info", sys_hardware, sys_firmware);
	}

	// emit "font_changed" if requested font is different
	if (font_last == 0xFF || font != font_last)
	{
		font_last = font;
		set_font(model, font);
	}

	display_buffer->colors.clear();
}

void M8GD::set_display_size(uint16_t width, uint16_t height)
{
	// print("setting display buffer size to (%d, %d)", width, height);

	uint8_t bg_alpha = 0xFF;

	if (display_buffer != nullptr)
	{
		bg_alpha = display_buffer->bg_alpha;
		delete display_buffer;
	}

	display_buffer = new DisplayBuffer(width, height);
	display_buffer->set_font(custom_font_bitmaps[current_font]);
	display_buffer->set_background_alpha(bg_alpha);
	display_image = Image::create(width, height, false, Image::FORMAT_RGBA8);

	if (display_texture == nullptr)
	{
		display_texture = ImageTexture::create_from_image(display_image);
	}
	else
	{
		display_texture->set_image(display_image);
	}
}

void M8GD::copy_buffer_to_texture()
{
	display_image->set_data(display_buffer->width, display_buffer->height, false, Image::FORMAT_RGBA8, display_buffer->byte_array);
	display_texture->update(display_image);
}

Ref<ImageTexture> M8GD::get_display()
{
	return display_texture;
}

PackedColorArray M8GD::get_theme_colors()
{
	if (display_buffer->colors.size() < 13)
	{
		PackedColorArray colors;
		colors.resize(13);
		colors.fill(Color(1, 1, 1));
		colors[0] = Color(
			display_buffer->bg_r / 255.0,
			display_buffer->bg_g / 255.0,
			display_buffer->bg_b / 255.0,
			1.0);
		return colors;
	}
	return display_buffer->colors;
}

void M8GD::set_background_alpha(float a)
{
	if (a < 0.0)
		a = 0.0;
	if (a > 1.0)
		a = 1.0;

	display_buffer->set_background_alpha((uint8_t)(a * 255));
}

Color M8GD::get_pixel(int x, int y)
{
	color c = display_buffer->get_pixel(x, y);
	return Color(
		c.r / 255.0,
		c.g / 255.0,
		c.b / 255.0,
		1.0);
}

void M8GD::load_font(M8Font font, Ref<BitMap> bitmap)
{
	custom_font_bitmaps[font] = bitmap;
	if (font == current_font)
	{
		display_buffer->set_font(custom_font_bitmaps[current_font]);
	}
	print("set font %d to bitmap of size (%d, %d)", font, bitmap->get_size().x, bitmap->get_size().y);
}

void M8GD::reset_display()
{
	m8_client.send_reset_display();
}

void M8GD::enable_and_reset_display()
{
	m8_client.send_enable_display();
	m8_client.send_reset_display();
}

bool M8GD::read()
{
	libm8::Error error = m8_client.read();

	if (error != libm8::OK)
	{
		printerr("read() failed, error code = %d", error);
		return false;
	}

	return true;
}

void M8GD::send_keyjazz(uint8_t note, uint8_t velocity)
{
	m8_client.send_keyjazz(note, velocity);
}

void M8GD::set_theme_color(uint8_t index, Color color)
{
	// ERR_FAIL_COND_MSG(index > 12, vformat("Invalid color index %d", index));

	const uint32_t rgba32 = color.to_rgba32();
	uint8_t *rgba = (uint8_t *)&rgba32;
	libm8::Error err = m8_client.send_theme_color(index, rgba[3], rgba[2], rgba[1]);
	// print("set theme color at idx %d to %02X %02X %02X", index, rgba[3], rgba[2], rgba[1]);

	ERR_FAIL_COND_MSG(err != libm8::OK, vformat("Failed to send command, error code = %d", err));
}

void M8GD::send_enable_display()
{
	m8_client.send_enable_display();
}

void M8GD::send_disable_display()
{
	m8_client.send_disable_display();
}

godot::TypedArray<godot::String> M8GD::list_devices(bool show_all)
{
	TypedArray<String> port_names;
	struct sp_port **port_list;

	print("listing serial ports...");

	enum sp_return result = sp_list_ports(&port_list);

	if (result != SP_OK)
	{
		printerr("failed to list ports!");
		return port_names;
	}

	for (int i = 0; port_list[i] != nullptr; i++)
	{
		struct sp_port *port = port_list[i];
		int usb_vid, usb_pid;
		char *port_name = sp_get_port_name(port);
		sp_get_port_usb_vid_pid(port, &usb_vid, &usb_pid);

		enum sp_transport transport = sp_get_port_transport(port);

		if (transport != SP_TRANSPORT_USB)
		{
			continue;
		}

		print("found serial port: %s (%04X:%04X)", port_name, usb_vid, usb_pid);

		if (libm8::is_m8_serial_port(port) || show_all)
		{
			// if the port is an M8 serial port or we want to show all ports
			if (libm8::is_m8_serial_port(port))
			{
				print("detected M8 serial port: %s (%04X:%04X)", port_name, usb_vid, usb_pid);
			}
			port_names.append(port_name);
		}
	}
	sp_free_port_list(port_list);

	print("finished listing serial ports, found %d devices", port_names.size());

	return port_names;
}

void M8GD::set_font(libm8::HardwareModel model, uint8_t font)
{
	current_font = M8GD::get_font_type(model, font);

	emit_signal("font_changed", current_font);
	print("requested font: %d", font);

	libm8::FontParameters font_params = libm8::get_font_params(model, font);

	display_buffer->screen_offset_y = font_params.screen_y_offset;
	display_buffer->font_offset_y = font_params.font_y_offset;
	display_buffer->waveform_max = font_params.waveform_max;
	display_buffer->set_font(custom_font_bitmaps[current_font]);
}

void M8GD::sdl_audio_in_callback(void *userdata, uint8_t *stream, int len)
{
	M8GD *m8gd = (M8GD *)userdata;
	std::vector<uint8_t> data_mix(len, 0);

	// adjust incoming data for volume
	// M8 audio input format is AUDIO_F32SYS
	SDL_MixAudioFormat(data_mix.data(), stream, m8gd->sdl_audio_spec_in.format, len, m8gd->sdl_audio_volume);

	// push audio input data to output device
	SDL_QueueAudio(m8gd->sdl_audio_device_id_out, data_mix.data(), len);

	// calculate the peak volume from the audio stream

	bool is_float = false;
	void *samples;
	int sample_count = 0;

	switch (m8gd->sdl_audio_spec_in.format)
	{
	case AUDIO_F32SYS:
	case AUDIO_F32MSB:
	{
		samples = (float *)data_mix.data();
		sample_count = len / sizeof(float);
		is_float = true;
		break;
	}
	case AUDIO_S16SYS:
	case AUDIO_S16MSB:
	{
		samples = (int16_t *)data_mix.data();
		sample_count = len / sizeof(int16_t);
		is_float = false;
		break;
	}
	default:
	{
		return;
	}
	}

	float peak_left = 0, peak_right = 0;

	for (int i = 0; i < sample_count; i += 2)
	{
		float sample_left, sample_right;
		if (is_float)
		{
			sample_left = abs(((float *)samples)[i]);
			sample_right = abs(((float *)samples)[i + 1]);
		}
		else
		{
			sample_left = abs(((int16_t *)samples)[i]) / 32768.0f;
			sample_right = abs(((int16_t *)samples)[i + 1]) / 32768.0f;
		}
		if (sample_left > peak_left)
		{
			peak_left = sample_left;
		}
		if (sample_right > peak_right)
		{
			peak_right = sample_right;
		}
	}

	m8gd->sdl_audio_peak_left = peak_left;
	m8gd->sdl_audio_peak_right = peak_right;
}

PackedStringArray M8GD::sdl_audio_get_audio_input_devices(bool show_all)
{
	PackedStringArray devices;

	if (!sdl_audio_initialized)
	{
		// temporarily initialize audio
		if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0)
		{
			printerr("SDL: Failed to initialize audio subsystem! (SDL error: %s)", SDL_GetError());
			return devices;
		}
	}

	int num_audio_devices = SDL_GetNumAudioDevices(SDL_TRUE);
	if (num_audio_devices < 1)
	{
		printerr("SDL: No audio input devices found! (SDL error: %s)", SDL_GetError());
		return devices;
	}

	for (int i = 0; i < num_audio_devices; i++)
	{
		const char *device_name = SDL_GetAudioDeviceName(i, SDL_TRUE);
		if (device_name &&
			(show_all || SDL_strstr(device_name, "M8") != NULL))
		{
			// only add M8 audio input devices or all devices if show_all is true
			print("SDL: Found audio input device %d: %s", i, device_name);
			devices.append(device_name);
		}
	}

	if (!sdl_audio_initialized)
	{
		SDL_QuitSubSystem(SDL_INIT_AUDIO);
	}

	return devices;
}

bool M8GD::sdl_audio_init(const uint16_t audio_buffer_size, String output_device_name, String input_device_name)
{
	if (sdl_audio_initialized)
	{
		printerr("SDL: Audio subsystem already initialized!");
		return false;
	}

	int m8_device_id = -1;

	print("SDL: Initializing audio subsystem");

	// Initialize SDL audio
	if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0)
	{
		printerr("SDL: Failed to initialize audio subsystem! (SDL error: %s)", SDL_GetError());
		return false;
	}

	const int num_audio_devices = SDL_GetNumAudioDevices(SDL_TRUE);
	if (num_audio_devices < 1)
	{
		printerr("SDL: No audio devices found! (SDL error: %s)", SDL_GetError());
		return false;
	}

	if (input_device_name.is_empty())
	{
		for (int i = 0; i < num_audio_devices; i++)
		{
			const char *device_name = SDL_GetAudioDeviceName(i, SDL_TRUE);
			if (device_name)
			{
				print("SDL: Found audio device %d: %s", i, device_name);
			}
			else
			{
				printerr("SDL: Failed to get audio device name! (SDL error: %s)", SDL_GetError());
			}

			if (SDL_strstr(device_name, "M8") != NULL)
			{
				m8_device_id = i; // store the index of the M8 audio device
			}
		}

		if (m8_device_id == -1)
		{
			printerr("SDL: No M8 audio device found! (SDL error: %s)", SDL_GetError());
			return false;
		}

		print("SDL: Found M8 audio device: %s", SDL_GetAudioDeviceName(m8_device_id, SDL_TRUE));

		input_device_name = SDL_GetAudioDeviceName(m8_device_id, SDL_TRUE);
	}

	SDL_AudioSpec want_in, have_in, want_out, have_out;

	SDL_zero(want_out);
	want_out.freq = 44100;
	want_out.format = AUDIO_S16SYS;
	want_out.channels = 2;
	want_out.samples = audio_buffer_size;

	if (output_device_name.is_empty() || output_device_name.to_lower() == "default")
	{
		// Use the default audio output device
		print("SDL: Opening audio output device: default");
		sdl_audio_device_id_out = SDL_OpenAudioDevice(
			NULL, SDL_FALSE,
			&want_out, &have_out, SDL_AUDIO_ALLOW_ANY_CHANGE);
	}
	else
	{
		print("SDL: Opening audio output device: %s", output_device_name);
		sdl_audio_device_id_out = SDL_OpenAudioDevice(
			output_device_name.utf8().get_data(), SDL_FALSE,
			&want_out, &have_out, SDL_AUDIO_ALLOW_ANY_CHANGE);
	}

	if (sdl_audio_device_id_out == 0)
	{
		printerr("SDL: Failed to open output audio device! (SDL error: %s)", SDL_GetError());
		return false;
	}

	SDL_zero(want_in);
	want_in.freq = 44100;
	want_in.format = AUDIO_S16SYS;
	want_in.channels = 2;
	want_in.samples = audio_buffer_size;
	want_in.callback = sdl_audio_in_callback;
	want_in.userdata = (void *)this;

	print("SDL: Opening audio input device: %s", input_device_name);
	sdl_audio_device_id_in = SDL_OpenAudioDevice(
		input_device_name.utf8().get_data(), SDL_TRUE,
		&want_in, &have_in, SDL_AUDIO_ALLOW_ANY_CHANGE);

	if (sdl_audio_device_id_in == 0)
	{
		printerr("SDL: Failed to open input audio device! (SDL error: %s)", SDL_GetError());
		return false;
	}

	sdl_audio_spec_in = have_in;

	SDL_PauseAudioDevice(sdl_audio_device_id_out, 0);
	SDL_PauseAudioDevice(sdl_audio_device_id_in, 0);

	sdl_audio_initialized = true;

	print("SDL: Audio input device format: %d Hz, %d channels", have_in.freq, have_in.channels);
	print("SDL:     sample size: %d", have_in.samples);
	print("SDL:     format: %s", sdl_audio_get_format_name());

	return true;
}

void M8GD::sdl_audio_shutdown()
{
	if (!sdl_audio_initialized)
		return;

	print("SDL: Closing audio devices");

	SDL_PauseAudioDevice(sdl_audio_device_id_out, 1);
	SDL_PauseAudioDevice(sdl_audio_device_id_in, 1);
	SDL_CloseAudioDevice(sdl_audio_device_id_out);
	SDL_CloseAudioDevice(sdl_audio_device_id_in);

	SDL_QuitSubSystem(SDL_INIT_AUDIO);

	print("SDL: Audio subsystem shut down");

	sdl_audio_initialized = false;
}