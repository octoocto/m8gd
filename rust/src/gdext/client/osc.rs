use crate::audio::AudioBackend;
use godot::{builtin::math::FloatExt, classes::ImageTexture, obj::Gd};
use std::ops::{Deref, DerefMut};

use crate::Color;

use super::BufferedTexture;

enum OscDisplayType {
    /// Emulate the size and layout of the hardware's oscilloscope display.
    Emulation,
    /// Use a custom size and layout for the oscilloscope display.
    Custom {
        width: usize,
        height: usize,
        separation: u8,
    },
}

pub struct OscBufferedTexture {
    buffer: BufferedTexture,
    display_type: OscDisplayType,
    separation: u8,
    ampl_mult: f32,
}

impl Default for OscBufferedTexture {
    fn default() -> Self {
        OscBufferedTexture {
            buffer: BufferedTexture::default(),
            display_type: OscDisplayType::Emulation,
            separation: 0,
            ampl_mult: 4.0,
        }
    }
}

impl Deref for OscBufferedTexture {
    type Target = BufferedTexture;

    fn deref(&self) -> &Self::Target {
        &self.buffer
    }
}

impl DerefMut for OscBufferedTexture {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.buffer
    }
}

pub trait OscDisplay {
    fn buffer(&mut self) -> &mut OscBufferedTexture;
    fn texture(&mut self) -> Gd<ImageTexture> {
        self.buffer().texture()
    }
    fn update_size(&mut self);
    fn update_texture(&mut self);
}

impl OscDisplay for super::GodotM8Client {
    fn buffer(&mut self) -> &mut OscBufferedTexture {
        &mut self.osc_buffer
    }

    fn update_size(&mut self) {
        let (width, height, separation) = match &self.buffer().display_type {
            OscDisplayType::Emulation => {
                let (width, height) = self.hardware_type.clone().unwrap_or_default().screen_size();
                let osc_height = self.font_type.get_data().waveform_max;
                let separation = (height as u8 / 8) - osc_height;
                (width as usize, height as usize, separation)
            }
            OscDisplayType::Custom {
                width,
                height,
                separation,
            } => (width.clone(), height.clone(), separation.clone()),
        };
        self.buffer().set_size(width, height);
        self.buffer().separation = separation;
    }

    fn update_texture(&mut self) {
        if !self.buffer().is_referenced() {
            return;
        }
        let bg_color = self.bg_color.clone();
        let bg_alpha = self.bg_alpha;
        let fg_color = self
            .theme_colors
            .get(crate::THEME_INDEX_SCOPE)
            .unwrap_or(&Color::new(255, 255, 255))
            .clone();
        let width = self.get_display_size().x as usize;
        let height = self.font_type.get_data().waveform_max as f32;
        self.buffer().fill(&bg_color, &bg_alpha);
        if self.audio_backend.is_none() {
            return;
        }
        for (i, track) in [
            crate::audio::AudioTrack::Track1,
            crate::audio::AudioTrack::Track2,
            crate::audio::AudioTrack::Track3,
            crate::audio::AudioTrack::Track4,
            crate::audio::AudioTrack::Track5,
            crate::audio::AudioTrack::Track6,
            crate::audio::AudioTrack::Track7,
            crate::audio::AudioTrack::Track8,
        ]
        .into_iter()
        .enumerate()
        {
            let Ok(track_data) = self.audio_backend.as_ref().unwrap().track_buffer(track) else {
                continue;
            };
            let osc_buffer = self.buffer();
            let separation = osc_buffer.separation as usize;
            for j in 0..width {
                let sample = track_data[j] * osc_buffer.ampl_mult;
                if sample.is_zero_approx() {
                    continue;
                }
                let x = j;
                let y = (((sample + 1.0) / 2.0) * height).clamp(0.0, height) as usize;
                osc_buffer.set_pixel(x, y + (i * (height as usize + separation)), &fg_color, &255);
            }
        }

        self.buffer().update_texture();
    }
}
