# libGDM8

## Serial port documentation

### Serial connection configuration

Setting      | Value
-------------|-------
Baud rate    | 115200
Data bits    | 8
Parity       | None
Stop bits    | 1
Flow control | None

### M8 serial data stream

The M8 sends data encoded with SLIP (Serial Line Internet Protocal).

The data must first be decoded and split into commands before processing the commands separately.

### Decoding a SLIP data stream

#### SLIP special bytes

Hex Value | Description
----------|----------------------------------
0xC0      | (END) End of command
0xDB      | (ESC) Escape
0xDC      | (ESC_END) Escaped END (0xC0) byte
0xDD      | (ESC_ESC) Escaped ESC (0xDB) byte

#### General logic loop TL;DR

1. Read the first byte of the received data buffer.
2. If not escaped, and the byte is...
    1. The special byte ESC (0xDB):

        1. The loop is now escaped.
        2. Continue to Step 4.

    2. The special byte END (0xC0):

        1. The end of the command has been reached. Process the bytes in the command buffer as a complete command.
        2. Clear the command buffer.
        3. Continue to Step 4.

    3. Any other byte:

        1. Add the byte to the command buffer.
        2. Continue to Step 4.

3. If escaped, and the byte is...
    1. The special byte ESC_END (0xDC):

        1. Add the END byte 0xC0 to the command buffer.
        2. The loop is no longer escaped.
        3. Continue to Step 4.

    2. The special byte ESC_ESC (0xDD):

        1. Add the ESC byte 0xDB to the command buffer.
        2. The loop is no longer escaped.
        3. Continue to Step 4.

    3. Any other byte:

        1. An unrecognized byte has been escaped. Raise an error.

4. Read the next byte of the received data buffer and go to Step 2, or stop here if the data buffer is empty.

### Read (RX) byte commands

Commands are in the form of a packet of at least 1 byte (2-digit hex values).
Byte 0 always represents the type of command.

#### FB Key pressed/unpressed (3 bytes)

Sent when a key on the M8 has been pressed or unpressed.

Byte # | Description
-------|-----------------------------------------------------------
0      | 0xFB
1      | a field of 8 bits representing the 8 keys and their state.
2      | ??? (assumed to be unused)

##### Bit to key mappings (right-most bit to left)

Bit # | Key
------|-------
0     | Edit
1     | Option
2     | Right
3     | Play
4     | Shift
5     | Down
6     | Up
7     | Left

These are also the order of the control bits on the hardware.

#### FF System info command (6 bytes)

FF is read either on the M8 starting up or if its display has been reset.
This command contains info on the connected M8's model and firmware.

Byte # | Description
-------|-----------------------
0      | 0xFF
1      | Device type (1 - 4)
2      | Firmware major version
3      | Firmware minor version
4      | Firmware patch version
5      | Font mode

##### Device types

Value | Description
------|-------------------------
0     | Headless
1     | Beta M8
2     | Production M8 (Model 01)
3     | Production M8 (Model 02)

##### Font modes

The font modes for Model 01 also apply to Headless and Beta models.

Value | Model 01   | Model 02
------|------------|-----------
0     | Small font | Small font
1     | Big font   | Bold font
2     | Unused     | Huge font

#### 0xFE Draw rectangle (12 bytes)

Draw a rectangle on the screen. (0, 0) = top-left pixel.

The draw calls may need to be offset by a specific amount depending on the current font mode. See [this code snippet](https://github.com/octoocto/m8gd/blob/c598c109a563413b90cee74eb5f56d2845ed08aa/src/libm8.hpp#L46-L57) for the exact values.

Byte # | Description
-------|---------------------------
0      | 0xFE
1,2    | (uint16) x screen position
3,4    | (uint16) y screen position
5,6    | (uint16) width of rect
7,8    | (uint16) height of rect
9-11   | (RGB8) color RGB

#### 0xFD Draw character (12 bytes)

Draw a character on the screen.

The draw calls may need to be offset by a specific amount depending on the current font mode. See [this code snippet](https://github.com/octoocto/m8gd/blob/c598c109a563413b90cee74eb5f56d2845ed08aa/src/libm8.hpp#L46-L57) for the exact values.

Byte # | Description
-------|---------------------------
0      | 0xFD
1      | character
2,3    | (uint16) x screen position
4,5    | (uint16) y screen position
6-8    | (RGB8) foreground RGB
9-11   | (RGB8) background RGB

#### 0xFC Draw oscilloscope waveform (4 to 484 bytes)

Byte # | Description
-------|-----------------
1-3    | (RGB8) color RGB
4+     | waveform data

The waveform data is used to draw the waveform one pixel at a time.
For each value in the waveform:
The index is the x-position of the pixel.
The value is the y-position of the pixel or amplitude of the wave.

If the big font is selected, less waveform data will be sent to make room for the title text.
In this case, the waveform should be aligned to the right of the screen.

The region the waveform will be drawn in should be cleared with the background color before each waveform draw call.

#### 00 No data

00 means there is no data.
The M8 sends 00s if it is inactive and there is no data to send.

Note: being able to read 00s does not mean the M8 is disconnected.

### Write (TX) byte commands

#### "D" Disconnect (1 byte)
Send this command to disconnect from the M8. This tells the M8 to stop sending data.

Byte # | Description
-------|------------------
0      | The character "D"

#### "C" Send key signal (2 bytes)
Remotely presses/unpresses a key on the connected M8.

Byte # | Description
-------|------------------------------------------------
0      | The character "C"
1      | Field of 8 bits representing each key on the M8

#### "K" Send note (keyjazz) signal (3 bytes)
Plays a note on the connected M8.

Byte # | Description
-------|------------------
0      | The character "K"
1      | The note
2      | The velocity

#### "E" Enable display (1 byte)
Send this command to tell the M8 to start sending data.

Byte # | Description
-------|------------------
0      | The character "E"

#### "R" Reset display (1 byte)
Resets the M8's display. This will force the M8's screen to clear and re-draw.
This will also force draw calls to be sent over the serial connection.

Byte # | Description
-------|------------------
0      | The character "R"