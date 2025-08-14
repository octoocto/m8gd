#pragma once

#include "display_buffer.hpp"
#include "libm8.hpp"
#include "utilities.hpp"

#include <libserialport.h>
#include <SDL.h>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/bit_map.hpp>

using namespace godot;

enum M8Key
{
	M8_KEY_UP = libm8::KEY_UP,
	M8_KEY_DOWN = libm8::KEY_DOWN,
	M8_KEY_LEFT = libm8::KEY_LEFT,
	M8_KEY_RIGHT = libm8::KEY_RIGHT,
	M8_KEY_OPTION = libm8::KEY_OPTION,
	M8_KEY_EDIT = libm8::KEY_EDIT,
	M8_KEY_SHIFT = libm8::KEY_SHIFT,
	M8_KEY_PLAY = libm8::KEY_PLAY,
};
VARIANT_ENUM_CAST(M8Key);

enum M8Font
{
	M8_FONT_01_SMALL,
	M8_FONT_01_BIG,
	M8_FONT_02_SMALL,
	M8_FONT_02_BOLD,
	M8_FONT_02_HUGE
};
VARIANT_ENUM_CAST(M8Font);

static const M8Key M8_KEYS[] = {
	M8_KEY_UP, M8_KEY_DOWN, M8_KEY_LEFT, M8_KEY_RIGHT,
	M8_KEY_OPTION, M8_KEY_EDIT, M8_KEY_SHIFT, M8_KEY_PLAY};

class M8GD;

class M8GDClient : public libm8::Client
{
private:
	M8GD *m8gd;

public:
	M8GDClient(M8GD *m8gd) : m8gd(m8gd) {}
	~M8GDClient() {}

	virtual void on_disconnect() override;

	virtual void on_draw_rect(
		uint16_t x, uint16_t y,
		uint16_t w, uint16_t h,
		uint8_t r, uint8_t g, uint8_t b) override;

	virtual void on_draw_char(
		char c,
		uint16_t x, uint16_t y,
		uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
		uint8_t bg_r, uint8_t bg_g, uint8_t bg_b) override;

	virtual void on_draw_waveform(
		uint16_t x, uint16_t y,
		uint8_t r, uint8_t g, uint8_t b,
		const uint8_t *points, uint16_t size) override;

	virtual void on_key_pressed(uint8_t keybits) override;

	virtual void on_system_info(
		libm8::HardwareModel model,
		uint8_t fw_major, uint8_t fw_minor, uint8_t fw_patch,
		libm8::Font font) override;
};

class M8GD : public Node
{
	GDCLASS(M8GD, Node);
	friend class M8GDClient;

protected:
	static void _bind_methods();

	M8GDClient m8_client = M8GDClient(this);

	DisplayBuffer *display_buffer;	   // byte array used as M8 display image buffer
	Ref<Image> display_image;		   // image to use to load byte array
	Ref<ImageTexture> display_texture; // display texture

	M8Font current_font = M8_FONT_01_SMALL;
	Ref<BitMap> custom_font_bitmaps[5] = {nullptr};

	// variables set after the m8 has been connected
	int sys_model = -1;
	String sys_hardware = "";
	String sys_firmware = "";

	// keybits
	uint8_t keybits = 0b00000000;

public:
	// config variables
	uint8_t cfg_tx_timeout_ms = 5; // timeout ms for write calls

public:
	M8GD();
	~M8GD();

	// void _ready() override;
	void _process(double delta) override;
	// void process();

	// device methods
public:
	/// @brief Lists all available serial devices.
	/// @param show_all Whether to show all devices or only M8 devices.
	/// @return An array of strings containing the names of the available serial devices.
	static godot::TypedArray<godot::String> list_devices(bool show_all = false);

	/// @brief Checks if a serial port is an M8 device.
	/// @param port_name The name of the serial port to check.
	/// @return true if the serial port is an M8 device, false otherwise.
	static bool is_m8_serial_port(const String &port_name)
	{
		return libm8::is_m8_serial_port(port_name.utf8().get_data());
	}

	/// @brief Gets the description of a serial port.
	/// @param port_name The name of the serial port to get the description for.
	/// @return The description of the serial port, or an empty string if not found.
	static String get_serial_port_description(const String &port_name)
	{
		return libm8::get_serial_port_description(port_name.utf8().get_data());
	}

	/// @brief Attempts to connect to the serial port at port_name.
	///        Serial port name must be of a valid M8 device.
	/// @param port_name The name of the serial port to connect to.
	/// @param force Whether to force the connection even if the port is not an M8.
	/// @return true if the connection was successful.
	bool connect(String port_name, bool force = false);

	/// @brief Disconnects the M8 and opens the serial port.
	void disconnect();

	/// @brief Returns true if there is an M8 currently connected.
	/// @return true if there is an M8 currently connected
	bool is_connected();

	/// @brief Returns the hardware name of the current or last connected device.
	/// @return the hardware name of the connected device
	String get_hardware_name() { return sys_hardware; }

	/// @brief Returns the firmware version of the current or last connected device.
	/// @return the firmware version of the connected device
	String get_firmware_version() { return sys_firmware; }

private:
	static void sdl_audio_in_callback(void *userdata, uint8_t *stream, int len);

	float sdl_audio_peak_left = 0;
	float sdl_audio_peak_right = 0;
	uint8_t sdl_audio_volume = SDL_MIX_MAXVOLUME;

public:
	bool sdl_audio_initialized = false;

	SDL_AudioDeviceID sdl_audio_device_id_out = 0; // SDL audio device ID for output
	SDL_AudioDeviceID sdl_audio_device_id_in = 0;  // SDL audio device ID for input
	SDL_AudioSpec sdl_audio_spec_in;			   // SDL audio spec for input

	// audio methods

	/// @brief Initializes the audio subsystem.
	/// @param audio_buffer_size the size of the audio buffer
	/// @return true if successful, false otherwise
	bool sdl_audio_init(const uint16_t audio_buffer_size, String output_device_name, String input_device_name);

	void sdl_audio_shutdown();

	PackedStringArray sdl_audio_get_audio_input_devices(bool show_all);

	/// @brief Returns the peak volume of the audio stream.
	/// @return A Vector2 containing the peak volume of the left and right channels.
	Vector2 sdl_audio_get_peak_volume()
	{
		if (sdl_audio_initialized)
		{
			return Vector2(
				20 * log10(sdl_audio_peak_left),
				20 * log10(sdl_audio_peak_right));
		}
		else
		{
			return Vector2(0.0, 0.0);
		}
	}

	void sdl_audio_set_volume(float volume)
	{
		volume = CLAMP(volume, 0.0f, 1.0f);
		sdl_audio_volume = (int)(volume * SDL_MIX_MAXVOLUME);
		print("SDL: Audio volume set to %d", sdl_audio_volume);
	}

	float sdl_audio_get_volume()
	{
		return (float)sdl_audio_volume / SDL_MIX_MAXVOLUME;
	}

	bool sdl_audio_is_initialized()
	{
		return sdl_audio_initialized;
	}

	String sdl_audio_get_driver_name()
	{
		if (!sdl_audio_initialized)
		{
			return "";
		}

		return String(SDL_GetCurrentAudioDriver());
	}

	String sdl_audio_get_format_name()
	{
		if (!sdl_audio_initialized)
		{
			return "";
		}

		switch (sdl_audio_spec_in.format)
		{
		case AUDIO_S8:
			return "S8";
		case AUDIO_U8:
			return "U8";
		case AUDIO_S16LSB:
			return "S16LSB";
		case AUDIO_S16MSB:
			return "S16MSB";
		case AUDIO_S32LSB:
			return "S32LSB";
		case AUDIO_S32MSB:
			return "S32MSB";
		case AUDIO_F32LSB:
			return "F32LSB";
		case AUDIO_F32MSB:
			return "F32MSB";
		case AUDIO_U16:
			return "U16";
		default:
			return "Unknown format";
		}
	}

	int sdl_audio_get_mix_rate()
	{
		if (!sdl_audio_initialized)
		{
			return 0;
		}

		return sdl_audio_spec_in.freq;
	}

	int sdl_audio_get_buffer_size()
	{
		return sdl_audio_spec_in.samples;
	}

	float sdl_audio_get_latency()
	{
		return (float)sdl_audio_spec_in.samples * 1000 / sdl_audio_spec_in.freq;
	}

public:
	// display methods

	/// @brief Gets the M8 display texture.
	/// @return
	Ref<ImageTexture> get_display();

	void set_background_alpha(float alpha);

	/// @brief Get the M8's theme colors.
	/// @return An array of 13 colors
	PackedColorArray get_theme_colors();

	/// @brief Set one of the M8's theme color.
	void set_theme_color(uint8_t index, Color color);

	/// @brief Get the color of a specific pixel in the M8 display.
	/// @param x
	/// @param y
	/// @return the color at this pixel
	Color get_pixel(int x, int y);

	/// @brief Load a font from a bitmap file.
	/// @param bitmap
	void load_font(M8Font font, Ref<BitMap> bitmap);

public:
	// input methods

	bool is_key_pressed(M8Key key)
	{
		return keybits & key;
	}

	int get_key_state() { return keybits; }

	void set_key_pressed(M8Key key, bool pressed);

	/// @brief Send control input to the connected device.
	///
	/// @param input_code an 8-bit number representing the 8 keys on the M8
	/// and their current state.
	///
	/// UP: bit 7 (64)
	/// DOWN: bit 6 (32)
	/// LEFT: bit 8 (128)
	/// RIGHT: bit 3 (4)
	/// SHIFT: bit 5 (16)
	/// PLAY: bit 4 (8)
	/// OPTION: bit 2 (2)
	/// EDIT: bit 1 (1)
	///
	/// Examples:
	/// 00000000 = no keys are pressed
	/// 00000011 = EDIT + OPTION are pressed
	///
	void set_key_state(uint8_t keybits);

	/// @brief Send a note to play to the connected device.
	///
	/// @param note the note value (0 - 255)
	/// @param velocity the note velocity (0 - 255)
	///
	void send_keyjazz(uint8_t note, uint8_t velocity);

	void send_enable_display();

	void send_disable_display();

	/// @brief Sends the reset display command to the M8.
	///        This forces the M8 to re-send all draw commands through the serial port.
	void reset_display();

	/// @brief Sends the enable display command to the M8.
	///        the reset display signal "R" to the M8.
	///        This forces the M8 to re-send all draw commands through the serial port.
	void enable_and_reset_display();

private:
	/// @brief Attempt to read SLIP encoded data from the M8.
	///        Calls read_command() if a complete command has been decoded.
	/// @return True if the read was successful.
	bool read();

	/// @brief Copy the display buffer to display_texture.
	void copy_buffer_to_texture();

	/// @brief Set the size of the display buffer.
	/// @param width
	/// @param height
	void set_display_size(uint16_t width, uint16_t height);

	/// @brief Sets the current model of the M8 client.
	///        Also resizes the display buffer.
	/// @param model
	void set_model(libm8::HardwareModel model);

	/// @brief Sets the current model, firmware, and font mode of the M8 client.
	///        Also resizes the display buffer.
	/// @param model
	/// @param fw_1 major version
	/// @param fw_2 minor version
	/// @param fw_3 patch version
	/// @param bigfont
	void set_model(libm8::HardwareModel model, uint8_t fw_1, uint8_t fw_2, uint8_t fw_3, uint8_t font);

	void set_font(libm8::HardwareModel model, uint8_t font);

	static M8Font get_font_type(libm8::HardwareModel model, uint8_t font)
	{
		if (model == libm8::HardwareModel::MODEL_02)
		{
			switch (font)
			{
			case libm8::Font::FONT_SMALL:
				return M8Font::M8_FONT_02_SMALL;
			case libm8::Font::FONT_LARGE:
				return M8Font::M8_FONT_02_BOLD;
			case libm8::Font::FONT_HUGE:
				return M8Font::M8_FONT_02_HUGE;
			}
		}
		else
		{
			switch (font)
			{
			case libm8::Font::FONT_SMALL:
				return M8Font::M8_FONT_01_SMALL;
			case libm8::Font::FONT_LARGE:
				return M8Font::M8_FONT_01_BIG;
			}
		}
		return M8Font::M8_FONT_01_SMALL;
	}

	String get_model_name(libm8::HardwareModel model)
	{
		switch (model)
		{
		case libm8::MODEL_HEADLESS:
			return "headless";
		case libm8::MODEL_BETA:
			return "beta";
		case libm8::MODEL_01:
			return "model_01";
		case libm8::MODEL_02:
			return "model_02";
		default:
			return "unknown";
		}
	}
};
