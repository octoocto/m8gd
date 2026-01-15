use super::HardwareType;

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
