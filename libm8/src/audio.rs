mod cpal;
mod sdl;

use crate::Error;
pub use crate::audio::cpal::*;
pub use crate::audio::sdl::*;
use enum_map::Enum;

pub trait AudioBackend {
    /// Starts audio processing with the specified input and output devices.
    /// If [None] is provided for either device, the default device is used.
    fn start(
        &mut self,
        input_device: Option<String>,
        output_device: Option<String>,
    ) -> Result<(), Error>;
    fn stop(&mut self) -> Result<(), Error>;
    fn is_running(&self) -> bool;

    fn list_input_devices(&self) -> Result<Vec<String>, Error>;
    fn list_output_devices(&self) -> Result<Vec<String>, Error>;

    fn volume(&mut self) -> Result<f32, Error>;
    fn set_volume(&mut self, volume: f32) -> Result<(), Error>;

    /// Returns the peak volume in linear scale for the left and right channels.
    /// TODO: Support more than 2 channels?
    fn volume_peaks(&mut self) -> Result<[f32; 2], Error>;

    /// Returns the volume in linear scale for `frequency` in Hz.
    ///
    /// If the spectrum analyzer is disabled, returns [None].
    fn volume_at_frequency(&mut self, frequency: f32) -> Result<f32, Error>;

    fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) -> Result<(), Error>;

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error>;

    fn input_spec(&self) -> Result<AudioSpec, Error>;
    // fn output_spec(&self) -> Result<AudioSpec, Error>;

    fn track_buffer(&mut self, track: AudioTrack) -> Result<Vec<f32>, Error>;
}

pub struct AudioSpec {
    // Name of the audio driver in use.
    driver_name: String,
    // Audio format (e.g., "F32LE" for 32-bit float little-endian).
    format: String,
    // Number of audio channels (e.g., 1 for mono, 2 for stereo).
    num_channels: usize,
    // Sample rate in Hz (e.g., 44100, 48000).
    sample_rate: usize,
    // Size of the audio buffer in samples.
    buffer_size: usize,
}

impl AudioSpec {
    pub fn driver_name(&self) -> &str {
        &self.driver_name
    }
    pub fn format(&self) -> &str {
        &self.format
    }
    pub fn num_channels(&self) -> usize {
        self.num_channels
    }
    pub fn sample_rate(&self) -> usize {
        self.sample_rate
    }
    pub fn buffer_size(&self) -> usize {
        self.buffer_size
    }
    pub fn latency_ms(&self) -> f32 {
        if self.sample_rate == 0 {
            return 0.0;
        }
        (self.buffer_size as f32 / self.sample_rate as f32) * 1000.0
    }
}

/// Represents an audio track on the M8 device if set to multichannel mode.
#[derive(Debug, PartialEq, Enum)]
pub enum AudioTrack {
    Mix,
    Track1,
    Track2,
    Track3,
    Track4,
    Track5,
    Track6,
    Track7,
    Track8,
    ModFx,
    DelayFx,
    ReverbFx,
}

impl AudioTrack {
    pub fn from_index(index: usize) -> AudioTrack {
        match index {
            1 => AudioTrack::Track1,
            2 => AudioTrack::Track2,
            3 => AudioTrack::Track3,
            4 => AudioTrack::Track4,
            5 => AudioTrack::Track5,
            6 => AudioTrack::Track6,
            7 => AudioTrack::Track7,
            8 => AudioTrack::Track8,
            9 => AudioTrack::ModFx,
            10 => AudioTrack::DelayFx,
            11 => AudioTrack::ReverbFx,
            _ => AudioTrack::Mix,
        }
    }
    pub fn channels(&self) -> (usize, usize) {
        match self {
            AudioTrack::Mix => (0, 1),
            AudioTrack::Track1 => (2, 3),
            AudioTrack::Track2 => (4, 5),
            AudioTrack::Track3 => (6, 7),
            AudioTrack::Track4 => (8, 9),
            AudioTrack::Track5 => (10, 11),
            AudioTrack::Track6 => (12, 13),
            AudioTrack::Track7 => (14, 15),
            AudioTrack::Track8 => (16, 17),
            AudioTrack::ModFx => (18, 19),
            AudioTrack::DelayFx => (20, 21),
            AudioTrack::ReverbFx => (22, 23),
        }
    }
}
