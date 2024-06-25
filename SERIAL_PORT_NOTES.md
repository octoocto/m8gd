# libGDM8

## Serial port documentation

### Serial connection configuration

Baud rate: 115200
Data bits: 8
Parity: None
Stop bits: 1
Flow control: None

### M8 serial data stream

The M8 sends data encoded with SLIP.

The data must first be decoded and split into commands before processing the commands separately.

### SLIP special bytes

### Read (RX) byte commands

Commands are in the form of a packet of at least 1 byte (2-digit hex values).
Byte 0 always represents the type of command.

#### FB Key pressed/unpressed (3 bytes)

Sent when a key on the M8 has been pressed or unpressed.

Byte 0 = 0xFB
Byte 1 = a field of 8 bits representing the 8 keys and their state.
Byte 2 = ??? (assumed to be unused)

##### Bit to key mappings (right-most bit to left)

Bit 0 = Edit
Bit 1 = Option
Bit 2 = Right
Bit 3 = Play
Bit 4 = Shift
Bit 5 = Down
Bit 6 = Up
Bit 7 = Left

#### FF System info command (6 bytes)

FF is read either on the M8 starting up or if its display has been reset.
This command contains info on the connected M8's model and firmware.

Byte 0: 0xFF
Byte 1: Device type (1 - 4)
Byte 2: Firmware major version
Byte 3: Firmware minor version
Byte 4: Firmware patch version
Byte 5: Font mode

##### Device types

0 = Headless
1 = Beta M8
2 = Production M8 (Model 01)
3 = Production M8 (Model 02)

#### 0xFE Draw rectangle (12 bytes)

Byte 0: 0xFE
Byte 1,2: x screen position
Byte 3,4: y screen position
Byte 5,6: width of rect
Byte 7,8: height of rect
Byte 9:  red
Byte 10: green
Byte 11: blue

#### 0xFD Draw character (12 bytes)

Byte 0: 0xFD
Byte 1: character
Byte 2,3: x screen position
Byte 4,5: y screen position
Byte 6: foreground red
Byte 7: foreground green
Byte 8: foreground blue
Byte 9: background red
Byte 10: background green
Byte 11: background blue

#### 0xFC Draw oscilloscope waveform (4 to 484 bytes)

Byte 1,2,3: color rgb
Bytes 4+: waveform data

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
Remotely disconnect from the M8.

Byte 0: "D"

#### "C" Send key signal (2 bytes)
Remotely presses/unpresses a key on the connected M8.

Byte 0: "C"
Byte 1: field of 8 bits representing each key on the M8

#### "K" Send note (keyjazz) signal (3 bytes)
Plays a note on the connected M8.

Byte 0: "C"
Byte 1: note
Byte 2: velocity

#### "E" Enable display (1 byte)
???

Byte 0: "E"

#### "R" Reset display (1 byte)
Resets the display. This will force the M8's screen to clear and re-draw.
This will also force draw calls to be sent over the serial connection.

Byte 0: "R"