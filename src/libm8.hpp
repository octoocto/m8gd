#pragma once

#include "utilities.hpp"
#include <cstdio>
#include <libserialport.h>

// max amount of bytes that can be received in one read
#define RX_BUFFER_SIZE 1024

// max amount of bytes that can be stored in one command
#define CMD_BUFFER_SIZE 1024

// max zero-byte reads before automatically disconnecting
#define MAX_ZERO_READS 1024

#define M8_SP_BAUD_RATE 115200
// #define M8_SP_BAUD_RATE 9600
#define M8_SP_DATA_BITS 8
#define M8_SP_PARITY SP_PARITY_NONE
#define M8_SP_STOP_BITS 1
#define M8_SP_FLOWCONTROL SP_FLOWCONTROL_NONE

namespace libm8
{
	const uint16_t M8_USB_VID = 0x16C0;
	const uint16_t M8_USB_PID = 0x048A;

	const uint16_t RES_MODEL_01[] = {320, 240};
	const uint16_t RES_MODEL_02[] = {480, 320};

	enum HardwareModel
	{
		MODEL_HEADLESS = 0,
		MODEL_BETA = 1,
		MODEL_01 = 2,
		MODEL_02 = 3
	};

	enum Font
	{
		FONT_SMALL = 0, // normal font in model01/model02
		FONT_LARGE = 1, // big font in model01; bold font in model02
		FONT_HUGE = 2	// huge font in model02; unused in model01
	};

	struct FontParameters
	{
		int8_t screen_y_offset; // offset of all draw calls
		int8_t font_y_offset;	// y-offset of fonts
		uint8_t waveform_max;	// max height of waveform
	};

	const FontParameters FONT_01_SMALL = {0, 3, 24};
	const FontParameters FONT_01_BIG = {-40, 4, 22};
	const FontParameters FONT_02_SMALL = {-2, 5, 38};
	const FontParameters FONT_02_BOLD = {-2, 4, 38};
	const FontParameters FONT_02_HUGE = {-54, 4, 24};

	enum Keys
	{
		KEY_UP = 1 << 6,
		KEY_DOWN = 1 << 5,
		KEY_LEFT = 1 << 7,
		KEY_RIGHT = 1 << 2,
		KEY_SHIFT = 1 << 4,
		KEY_PLAY = 1 << 3,
		KEY_OPTION = 1 << 1,
		KEY_EDIT = 1 << 0
	};

	enum CommandRX
	{
		DRAW_RECT = 0xFE,
		DRAW_RECT_SIZE_1 = 12,
		DRAW_RECT_SIZE_2 = 9,
		DRAW_RECT_SIZE_3 = 8,
		DRAW_RECT_SIZE_4 = 5,

		DRAW_CHAR = 0xFD,
		DRAW_CHAR_SIZE = 12,

		DRAW_OSC = 0xFC,
		DRAW_OSC_SIZE_MIN = 1 + 3,
		DRAW_OSC_SIZE_MAX = 1 + 3 + 480,

		KEY_PRESS = 0xFB,
		KEY_PRESS_SIZE = 3,

		SYSTEM_INFO = 0xFF,
		SYSTEM_INFO_SIZE = 6,
	};

	enum CommandTX
	{
		TX_CONTROL_KEYS = 'C',	 // [1]: field of key states
		TX_KEYJAZZ = 'K',		 // [1]: note, [2]: velocity
		TX_ENABLE_DISPLAY = 'E', // no args
		TX_RESET_DISPLAY = 'R',	 // no args
		TX_DISCONNECT = 'D',	 // no args
		TX_THEME_COLOR = 'S'	 // [1]: index [234]: rgb
	};

	enum SLIPSpecialBytes
	{
		SLIP_END = 0xC0,
		SLIP_ESC = 0xDB,
		SLIP_ESC_END = 0xDC,
		SLIP_ESC_ESC = 0xDD,
	};

	enum Error
	{
		OK = 0,
		// command reader errors
		ERR_CMD_BUFFER_OVERFLOW = 1, // tried to add more bytes than RX_BUFFER_SIZE
		// ERR_CMD_HANDLER_NOT_IMPLEMENTED = 2, // function not overriden correctly
		ERR_CMD_HANDLER_INVALID_SIZE = 3, // read a command with an invalid size
		ERR_CMD_HANDLER_INVALID_CMD = 4,  // read a command not recognized
		// read() errors
		ERR_SLIP_INVALID_ESCAPED_CHAR = 5,
		// libserialport errors
		ERR_SP_INVALID_ARGS = 6,
		ERR_SP_FAILED = 7,
		ERR_SP_MEM = 8,
		ERR_SP_NOT_SUPPORTED = 9,
		// connect() errors
		ERR_DEVICE_NOT_FOUND = 10,
		// general errors
		ERR_NOT_CONNECTED = 11,
	};

	static bool is_m8_serial_port(sp_port *port)
	{
		int usb_vid, usb_pid;
		sp_get_port_usb_vid_pid(port, &usb_vid, &usb_pid);
		return usb_vid == M8_USB_VID && usb_pid == M8_USB_PID;
	}

	static FontParameters get_font_params(uint8_t model, uint8_t font)
	{
		if (model == MODEL_02)
		{
			switch (font)
			{
			case FONT_SMALL:
				return FONT_02_SMALL;
			case FONT_LARGE:
				return FONT_02_BOLD;
			case FONT_HUGE:
				return FONT_02_HUGE;
			}
		}
		else
		{
			switch (font)
			{
			case FONT_SMALL:
				return FONT_01_SMALL;
			case FONT_LARGE:
				return FONT_01_BIG;
			}
		}
		printerr("unable to find correct font parameters! (model=%d, font=%d)", model, font);
		return FONT_01_SMALL;
	}

	static uint16_t decode_u16(uint8_t *data, uint8_t start)
	{
		return data[start] | (uint16_t)data[start + 1] << 8;
	}

	class Client
	{
	private:
		sp_port *m8_port = nullptr;

		uint8_t rx_buffer[RX_BUFFER_SIZE] = {0}; // raw data buffer

		uint8_t cmd_buffer[CMD_BUFFER_SIZE] = {0}; // decoded data buffer
		uint32_t cmd_size = 0;

		int zero_reads = 0;

	public:
		Client() {}
		~Client()
		{
			disconnect();
			sp_free_port(m8_port);
		}

	private:
		Error sp_to_m8(sp_return code)
		{
			char *error_msg;
			switch (code)
			{
			case SP_ERR_ARG:
				return ERR_SP_INVALID_ARGS;
			case SP_ERR_FAIL:
				error_msg = sp_last_error_message();
				printerr("libserialport: failed: %s", error_msg);
				sp_free_error_message(error_msg);
				return ERR_SP_FAILED;
			case SP_ERR_MEM:
				return ERR_SP_MEM;
			case SP_ERR_SUPP:
				return ERR_SP_NOT_SUPPORTED;
			default:
				return OK;
			}
		}

	private: // methods to override
		/// @brief Called when the M8 is disconnected and port is freed.
		virtual void on_disconnect() = 0;

		/// @brief Called when the M8 sends a DRAW_RECT command. (12 bytes)
		virtual void on_draw_rect(
			uint16_t x, uint16_t y,
			uint16_t w, uint16_t h,
			uint8_t r, uint8_t g, uint8_t b) = 0;

		// /// @brief Called when the M8 sends a DRAW_RECT command. (9 bytes)
		// virtual void on_draw_rect(
		// 	uint16_t x, uint16_t y,
		// 	uint16_t w, uint16_t h) = 0;

		// /// @brief Called when the M8 sends a DRAW_RECT command. (8 bytes)
		// virtual void on_draw_rect(
		// 	uint16_t x, uint16_t y,
		// 	uint8_t r, uint8_t g, uint8_t b) = 0;

		// /// @brief Called when the M8 sends a DRAW_RECT command. (5 bytes)
		// virtual void on_draw_rect(uint16_t x, uint16_t y) = 0;

		/// @brief Called when the M8 sends a DRAW_CHAR command.
		virtual void on_draw_char(
			char c,
			uint16_t x, uint16_t y,
			uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
			uint8_t bg_r, uint8_t bg_g, uint8_t bg_b) = 0;

		/// @brief Called when the M8 sends a DRAW_OSC command.
		virtual void on_draw_waveform(
			uint16_t x, uint16_t y,
			uint8_t r, uint8_t g, uint8_t b,
			const uint8_t *points, uint16_t size) = 0;

		/// @brief Called when a key has been pressed/unpressed on the M8.
		virtual void on_key_pressed(uint8_t keybits) = 0;

		virtual void on_system_info(
			HardwareModel model,
			uint8_t fw_major, uint8_t fw_minor, uint8_t fw_patch,
			Font font) = 0;

	public:
		/// @brief Send a command to the M8.
		/// @param data an array of bytes containing the command and arguments
		/// @param size the size of the array
		Error send_command(const uint8_t (&data)[], size_t size)
		{
			if (m8_port == nullptr)
				return ERR_NOT_CONNECTED;

			sp_return result = sp_blocking_write(m8_port, data, size, 10);
			return sp_to_m8(result);
		}

		Error send_reset_display()
		{
			return send_command({TX_RESET_DISPLAY}, 1);
		}

		Error send_enable_display()
		{
			return send_command({TX_ENABLE_DISPLAY}, 1);
		}

		Error send_disable_display()
		{
			return send_command({TX_DISCONNECT}, 1);
		}

		Error disconnect()
		{
			if (is_connected())
			{
				send_disable_display();
				on_disconnect();
				sp_close(m8_port);
				sp_free_port(m8_port);
				m8_port = nullptr;
				cmd_size = 0;	// also reset cmd_buffer
				zero_reads = 0; // also reset zero_reads counter
								// print("disconnected");
			}
			return OK;
		}

		Error send_keyjazz(uint8_t note, uint8_t velocity)
		{
			return send_command({TX_KEYJAZZ, note, velocity}, 3);
		}

		Error send_control_keys(uint8_t keystate)
		{
			return send_command({TX_CONTROL_KEYS, keystate}, 2);
		}

		Error send_theme_color(uint8_t index, uint8_t r, uint8_t g, uint8_t b)
		{
			return send_command({TX_THEME_COLOR, index, r, g, b}, 5);
		}

		Error connect(godot::String port_name);

		bool is_connected()
		{
			return m8_port != nullptr;
		}

		Error read();

	private:
		/// @brief Append a byte to the command buffer.
		/// @param byte
		Error cmd_buffer_append(uint8_t byte)
		{
			if (cmd_size == RX_BUFFER_SIZE)
			{
				return ERR_CMD_BUFFER_OVERFLOW;
			}
			cmd_buffer[cmd_size++] = byte;
			return OK;
		}

		/// @brief Read and process the command buffer.
		/// @return true if the command was successfully processed.
		Error read_command(uint8_t *cmd_buffer, const uint16_t &cmd_size);
	};
}