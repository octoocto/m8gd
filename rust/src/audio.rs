mod cpal;
mod sdl;

pub use cpal::*;
pub use sdl::*;

use crate as m8;

use m8::Error;

pub const LATENCY_MS: f32 = 20.0;
// number of samples to add onto the buffer due to extra latency
pub const LATENCY_BUFFER_SIZE: usize = ((LATENCY_MS / 1000.0) * SAMPLE_RATE as f32) as usize;
pub const BUFFER_SIZE: usize = 512;
pub const SAMPLE_RATE: usize = 44100;
// length of the buffer that is used for an oscillator
pub const OSC_BUFFER_SIZE: usize = 441;

pub trait AudioHandler {
    /// Starts audio processing with the specified input and output devices.
    ///
    /// Devices are identified with [String]s that are returned with [list_input_devices()]
    /// or [list_output_devices()].
    ///
    /// If [None] is provided for either device, the default device is used.
    ///
    /// # Errors
    /// May return an error if:
    /// - An invalid input or output device has been given.
    /// - Audio processing with the backend has failed for any reason.
    fn start(
        &mut self,
        input_device: Option<String>,
        output_device: Option<String>,
    ) -> Result<(), Error>;

    /// Stops audio processing.
    fn stop(&mut self) -> Result<(), Error>;

    /// Returns whether audio is currently processing.
    fn is_running(&self) -> bool;

    /// Sets whether to start audio in multichannel mode.
    ///
    /// If multichannel mode is not supported, returns [Error::AudioError].
    fn set_multichannel_mode(&mut self, enabled: bool) -> Result<(), Error>;

    fn list_input_devices(&self) -> Result<Vec<String>, Error>;
    fn list_output_devices(&self) -> Result<Vec<String>, Error>;

    fn volume(&mut self) -> Result<f32, Error>;
    fn set_volume(&mut self, volume: f32) -> Result<(), Error>;

    /// Returns the peak volume in linear scale for the left and right channels.
    /// TODO: Support more than 2 channels?
    fn peaks_linear(&mut self) -> Result<[f32; 2], Error>;

    /// Returns the volume in linear scale for `frequency` in Hz.
    ///
    /// If the spectrum analyzer is disabled, returns [None].
    fn value_at_frequency(&mut self, frequency: f32) -> Result<f32, Error>;

    fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) -> Result<(), Error>;

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error>;

    fn input_spec(&self) -> Result<AudioSpec, Error>;
    // fn output_spec(&self) -> Result<AudioSpec, Error>;

    fn track_buffer(&self, track: m8::Track) -> Result<Vec<f32>, Error>;

    fn peaks_db(&mut self) -> Result<[f32; 2], Error> {
        Ok(self.peaks_linear()?.map(|f| {
            if f <= 0.0 {
                f32::NEG_INFINITY
            } else {
                20.0 * f.log10()
            }
        }))
    }
}

pub struct AudioSpec {
    // Name of the audio driver in use.
    host: String,
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
    pub fn host(&self) -> &str {
        &self.host
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
