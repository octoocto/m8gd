use super::{Color, FontType, HardwareType, KeyState};

#[derive(Debug, Clone)]
pub struct DrawRectParams {
    pub x: u16,
    pub y: u16,
    pub width: u16,
    pub height: u16,
    pub color: Option<Color>,
}

#[derive(Debug, Clone)]
pub struct DrawCharParams {
    pub c: char,
    pub x: u16,
    pub y: u16,
    pub color_fg: Color,
    pub color_bg: Color,
}

#[derive(Debug, Clone)]
pub struct DrawOscParams {
    pub color: Color,
    pub waveform: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct SystemInfo {
    pub model: HardwareType,
    pub firmware: String,
    pub font: FontType,
}

// Commands sent from the M8 device to the host
#[derive(Debug, Clone)]
pub enum CommandIn {
    // full length draw rect command
    DrawRect { params: DrawRectParams },
    // draw character
    DrawChar { params: DrawCharParams },
    // draw oscillator waveform
    DrawOsc { params: DrawOscParams },
    // receive pressed state of the 8 keys as a bit field
    GetKeyState { keystate: KeyState },
    // receive system info
    GetSystemInfo { info: SystemInfo },
}

impl CommandIn {
    pub const DRAW_RECT: u8 = 0xFE;
    pub const DRAW_CHAR: u8 = 0xFD;
    pub const DRAW_OSC: u8 = 0xFC;
    pub const GET_KEY_PRESS: u8 = 0xFB;
    pub const GET_SYSTEM_INFO: u8 = 0xFF;

    pub const DRAW_RECT_SIZE_1: usize = 12;
    pub const DRAW_RECT_SIZE_2: usize = 9;
    pub const DRAW_RECT_SIZE_3: usize = 8;
    pub const DRAW_RECT_SIZE_4: usize = 5;
    pub const DRAW_OSC_SIZE_MIN: usize = 1 + 3;
    pub const DRAW_OSC_SIZE_MAX: usize = 1 + 3 + 480;
    pub const DRAW_CHAR_SIZE: usize = 12;
    pub const KEY_PRESS_SIZE: usize = 3;
    pub const SYSTEM_INFO_SIZE: usize = 6;

    pub fn from_bytes(bytes: &[u8]) -> Option<CommandIn> {
        if bytes.is_empty() {
            return None;
        }
        let command_byte = bytes[0];
        match command_byte {
            Self::DRAW_RECT => {
                match bytes.len() {
                    Self::DRAW_RECT_SIZE_1 => Some(CommandIn::DrawRect {
                        params: DrawRectParams {
                            x: u16::from_le_bytes([bytes[1], bytes[2]]),
                            y: u16::from_le_bytes([bytes[3], bytes[4]]),
                            width: u16::from_le_bytes([bytes[5], bytes[6]]),
                            height: u16::from_le_bytes([bytes[7], bytes[8]]),
                            color: Some(Color::new(bytes[9], bytes[10], bytes[11])),
                        },
                    }),
                    // draw rect using last color
                    Self::DRAW_RECT_SIZE_2 => Some(CommandIn::DrawRect {
                        params: DrawRectParams {
                            x: u16::from_le_bytes([bytes[1], bytes[2]]),
                            y: u16::from_le_bytes([bytes[3], bytes[4]]),
                            width: u16::from_le_bytes([bytes[5], bytes[6]]),
                            height: u16::from_le_bytes([bytes[7], bytes[8]]),
                            color: None,
                        },
                    }),
                    // draw single pixel
                    Self::DRAW_RECT_SIZE_3 => Some(CommandIn::DrawRect {
                        params: DrawRectParams {
                            x: u16::from_le_bytes([bytes[1], bytes[2]]),
                            y: u16::from_le_bytes([bytes[3], bytes[4]]),
                            width: 1,
                            height: 1,
                            color: Some(Color::new(bytes[5], bytes[6], bytes[7])),
                        },
                    }),
                    // draw single pixel using last color
                    Self::DRAW_RECT_SIZE_4 => Some(CommandIn::DrawRect {
                        params: DrawRectParams {
                            x: u16::from_le_bytes([bytes[1], bytes[2]]),
                            y: u16::from_le_bytes([bytes[3], bytes[4]]),
                            width: 1,
                            height: 1,
                            color: None,
                        },
                    }),
                    _ => None,
                }
            }
            Self::DRAW_CHAR => {
                if bytes.len() != Self::DRAW_CHAR_SIZE {
                    return None;
                }
                Some(CommandIn::DrawChar {
                    params: DrawCharParams {
                        c: bytes[1] as char,
                        x: u16::from_le_bytes([bytes[2], bytes[3]]),
                        y: u16::from_le_bytes([bytes[4], bytes[5]]),
                        color_fg: Color::new(bytes[6], bytes[7], bytes[8]),
                        color_bg: Color::new(bytes[9], bytes[10], bytes[11]),
                    },
                })
            }
            Self::DRAW_OSC => {
                if bytes.len() < Self::DRAW_OSC_SIZE_MIN || bytes.len() > Self::DRAW_OSC_SIZE_MAX {
                    return None;
                }
                Some(CommandIn::DrawOsc {
                    params: DrawOscParams {
                        color: Color::new(bytes[1], bytes[2], bytes[3]),
                        waveform: bytes[4..].to_vec(),
                    },
                })
            }
            Self::GET_KEY_PRESS => {
                if bytes.len() != Self::KEY_PRESS_SIZE {
                    return None;
                }
                let keystate = KeyState::from(bytes[1]);
                Some(CommandIn::GetKeyState { keystate })
            }
            Self::GET_SYSTEM_INFO => {
                if bytes.len() != Self::SYSTEM_INFO_SIZE {
                    return None;
                }
                let model = HardwareType::from(bytes[1]);
                let font = FontType::from(&model, bytes[5]);
                let firmware = format!("{}.{}.{}", bytes[2], bytes[3], bytes[4]);
                Some(CommandIn::GetSystemInfo {
                    info: SystemInfo {
                        model,
                        firmware,
                        font,
                    },
                })
            }
            _ => None,
        }
    }
}

// Commands sent from the host to the M8 device
#[repr(u8)]
pub enum CommandOut {
    /// Sets the state of the keys on the M8.
    ControlKeys {
        keybits: u8,
    },
    /// Tells the M8 to play a note.
    KeyJazz {
        note: u8,
        velocity: u8,
    },
    /// Tells the M8 to start sending data.
    EnableDisplay,
    /// Tells the M8 to refresh the screen.
    ///
    /// This will force the M8 to redraw the entire display.
    ResetDisplay,
    /// Tells the M8 to stop sending data.
    DisableDisplay,
    /// Tells the M8 to set a color in the theme.
    ///
    /// The index should be between 0 and 12 (for 13 total colors). Requests for other indices will be ignored.
    /// Sending this command will also force the M8 to redraw the entire display.
    ThemeColor {
        index: u8,
        r: u8,
        g: u8,
        b: u8,
    },
    Ping,
}

impl CommandOut {
    pub fn to_bytes(&self) -> Vec<u8> {
        match self {
            CommandOut::ControlKeys { keybits } => vec!['C' as u8, *keybits],
            CommandOut::KeyJazz { note, velocity } => vec!['K' as u8, *note, *velocity],
            CommandOut::EnableDisplay => vec!['E' as u8],
            CommandOut::ResetDisplay => vec!['R' as u8],
            CommandOut::DisableDisplay => vec!['D' as u8],
            CommandOut::ThemeColor { index, r, g, b } => {
                vec!['S' as u8, *index, *r, *g, *b]
            }
            CommandOut::Ping => vec!['X' as u8],
        }
    }
}
