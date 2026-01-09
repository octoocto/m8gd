pub mod commands;

use core::default::Default;

pub const M8_VID: u16 = 0x16C0;
pub const M8_PID_STEREO: u16 = 0x048A;
pub const M8_PID_MULTICHANNEL: u16 = 0x048B;

pub const NUM_THEME_COLORS: usize = 13;

#[derive(Clone, PartialEq, Debug)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    pub fn new(r: u8, g: u8, b: u8) -> Self {
        Color { r, g, b }
    }
}

impl Default for Color {
    fn default() -> Self {
        Color::new(0, 0, 0)
    }
}

#[derive(Debug, Clone)]
pub enum HardwareType {
    ModelHeadless,
    ModelBeta,
    Model01,
    Model02,
}

impl HardwareType {
    const SCREEN_SIZE_MODEL_01: (u16, u16) = (320, 240);
    const SCREEN_SIZE_MODEL_02: (u16, u16) = (480, 320);

    pub fn from(byte: u8) -> HardwareType {
        match byte {
            0x00 => HardwareType::ModelHeadless,
            0x01 => HardwareType::ModelBeta,
            0x02 => HardwareType::Model01,
            0x03 => HardwareType::Model02,
            _ => HardwareType::ModelHeadless,
        }
    }

    pub fn screen_size(&self) -> (u16, u16) {
        match self {
            HardwareType::Model02 => Self::SCREEN_SIZE_MODEL_02,
            _ => Self::SCREEN_SIZE_MODEL_01,
        }
    }

    pub fn name(&self) -> String {
        match self {
            HardwareType::ModelHeadless => String::from("Headless"),
            HardwareType::ModelBeta => String::from("Beta"),
            HardwareType::Model01 => String::from("Model:01"),
            HardwareType::Model02 => String::from("Model:02"),
        }
    }
}

impl Default for HardwareType {
    fn default() -> Self {
        HardwareType::Model01
    }
}

impl ToString for HardwareType {
    fn to_string(&self) -> String {
        self.name()
    }
}

#[derive(Debug, Clone, Hash, PartialEq, Eq)]
#[repr(u8)]
pub enum FontType {
    Model01Normal,
    Model01Big,
    Model02Normal,
    Model02Bold,
    Model02Huge,
}

impl FontType {
    pub fn from(model: &HardwareType, byte: u8) -> FontType {
        match model {
            HardwareType::Model02 => match byte {
                0x00 => return FontType::Model02Normal,
                0x01 => return FontType::Model02Bold,
                0x02 => return FontType::Model02Huge,
                _ => return FontType::Model02Normal,
            },
            _ => match byte {
                0x00 => return FontType::Model01Normal,
                0x01 => return FontType::Model01Big,
                _ => return FontType::Model01Normal,
            },
        }
    }

    pub fn get_data(&self) -> &'static Font {
        match self {
            FontType::Model01Normal => &Font::FONT_01_SMALL,
            FontType::Model01Big => &Font::FONT_01_BIG,
            FontType::Model02Normal => &Font::FONT_02_SMALL,
            FontType::Model02Bold => &Font::FONT_02_BOLD,
            FontType::Model02Huge => &Font::FONT_02_HUGE,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Font {
    pub bytes: &'static [u8], // font bitmap data
    pub char_width: u8,       // width of each character in pixels
    pub char_height: u8,      // height of each character in pixels
    pub draw_y_offset: i16,   // y-offset of all draw calls
    pub char_y_offset: i16,   // y-offset of text draw calls
    pub waveform_max: u8,     // max height of waveform
}

impl Font {
    pub const FONT_01_SMALL: Font = Font {
        bytes: include_bytes!("5_7.bmp"),
        char_width: 5,
        char_height: 7,
        draw_y_offset: 0,
        char_y_offset: 3,
        waveform_max: 24,
    };
    pub const FONT_01_BIG: Font = Font {
        bytes: include_bytes!("8_9.bmp"),
        char_width: 8,
        char_height: 9,
        draw_y_offset: -40,
        char_y_offset: 4,
        waveform_max: 22,
    };
    pub const FONT_02_SMALL: Font = Font {
        bytes: include_bytes!("9_9.bmp"),
        char_width: 9,
        char_height: 9,
        draw_y_offset: -2,
        char_y_offset: 5,
        waveform_max: 38,
    };
    pub const FONT_02_BOLD: Font = Font {
        bytes: include_bytes!("10_10.bmp"),
        char_width: 10,
        char_height: 10,
        draw_y_offset: -2,
        char_y_offset: 4,
        waveform_max: 38,
    };
    pub const FONT_02_HUGE: Font = Font {
        bytes: include_bytes!("12_12.bmp"),
        char_width: 12,
        char_height: 12,
        draw_y_offset: -54,
        char_y_offset: 4,
        waveform_max: 24,
    };
}

#[derive(Clone, Copy, Debug)]
#[repr(u8)]
pub enum Key {
    Up = 1 << 6,
    Down = 1 << 5,
    Left = 1 << 7,
    Right = 1 << 2,
    Shift = 1 << 4,
    Play = 1 << 3,
    Option = 1 << 1,
    Edit = 1 << 0,
}

impl Key {
    pub const UP: u8 = Self::Up as u8;
    pub const DOWN: u8 = Self::Down as u8;
    pub const LEFT: u8 = Self::Left as u8;
    pub const RIGHT: u8 = Self::Right as u8;
    pub const SHIFT: u8 = Self::Shift as u8;
    pub const PLAY: u8 = Self::Play as u8;
    pub const OPTION: u8 = Self::Option as u8;
    pub const EDIT: u8 = Self::Edit as u8;

    pub const UP_DOWN_LEFT_RIGHT: u8 = Self::UP + Self::DOWN + Self::LEFT + Self::RIGHT;

    pub const ALL_KEYS: [&Self; 8] = [
        &Self::Up,
        &Self::Down,
        &Self::Left,
        &Self::Right,
        &Self::Shift,
        &Self::Play,
        &Self::Option,
        &Self::Edit,
    ];

    pub fn to_byte(&self) -> u8 {
        *self as u8
    }

    pub fn from_byte(byte: u8) -> Option<Key> {
        match byte {
            Self::UP => Some(Key::Up),
            Self::DOWN => Some(Key::Down),
            Self::LEFT => Some(Key::Left),
            Self::RIGHT => Some(Key::Right),
            Self::SHIFT => Some(Key::Shift),
            Self::PLAY => Some(Key::Play),
            Self::OPTION => Some(Key::Option),
            Self::EDIT => Some(Key::Edit),
            _ => None,
        }
    }
}

impl From<&Key> for u8 {
    fn from(key: &Key) -> u8 {
        key.to_byte()
    }
}

#[derive(PartialEq, Clone, Debug)]
pub struct KeyState {
    bitfield: u8,
}

impl From<u8> for KeyState {
    fn from(bitfield: u8) -> Self {
        KeyState { bitfield }
    }
}

impl From<&KeyState> for u8 {
    fn from(keystate: &KeyState) -> u8 {
        keystate.to_byte()
    }
}

impl Default for KeyState {
    fn default() -> Self {
        KeyState { bitfield: 0 }
    }
}

impl KeyState {
    pub fn new(bitfield: u8) -> KeyState {
        KeyState { bitfield }
    }

    pub fn to_byte(&self) -> u8 {
        self.bitfield
    }

    /// Returns true if this state represents the
    /// 4 directional keys being pressed.
    ///
    /// On the M8 this activates the 8-track oscilloscope view,
    /// which is not supported by any client backend, and
    /// all data transfer will halt while in this view.
    pub fn is_easter_egg(&self) -> bool {
        self.to_byte() == Key::UP_DOWN_LEFT_RIGHT
    }

    pub fn is_pressed(&self, key: &Key) -> bool {
        (self.bitfield & key.to_byte()) != 0
    }

    pub fn set_pressed(&mut self, key: &Key, pressed: bool) {
        if pressed {
            self.bitfield |= key.to_byte();
        } else {
            self.bitfield &= !key.to_byte();
        }
    }
}

/// Special bytes for parsing packets using the SLIP protocol.
#[derive(Clone, Copy)]
pub enum SlipByte {
    End = 0xC0,
    Esc = 0xDB,
    EscEnd = 0xDC,
    EscEsc = 0xDD,
    None = 0x00,
}

impl SlipByte {
    const ESC: u8 = Self::Esc as u8;
    const END: u8 = Self::End as u8;
    const ESC_END: u8 = Self::EscEnd as u8;
    const ESC_ESC: u8 = Self::EscEsc as u8;
}

impl From<&SlipByte> for u8 {
    fn from(byte: &SlipByte) -> Self {
        *byte as u8
    }
}

impl From<u8> for SlipByte {
    fn from(byte: u8) -> Self {
        match byte {
            Self::END => SlipByte::End,
            Self::ESC => SlipByte::Esc,
            Self::ESC_END => SlipByte::EscEnd,
            Self::ESC_ESC => SlipByte::EscEsc,
            _ => SlipByte::None,
        }
    }
}

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error("Buffer overflow")]
    BufferOverflow,
    /// Encountered an error while parsing an incoming command.
    #[error("Failed to parse command: {0}")]
    CommandParseError(String),
    /// No backend is available to communicate with the device.
    #[error("No backend available")]
    NoBackend,
    /// An audio-related error occured.
    #[error("Audio error: {0}")]
    AudioError(String),
    /// Was unable to find the requested device.
    #[error("Device not found")]
    DeviceNotFound,
    /// Encountered an error while attempting to connect to the device.
    #[error("Device connection error: {0}")]
    DeviceConnectionError(String),
    /// Device encountered an error while reading data.
    #[error("Device read error: {0}")]
    DeviceReadError(String),
    /// A previously connected device lost connection.
    #[error("Device not connected: {0}")]
    DeviceNotConnected(String),
}
