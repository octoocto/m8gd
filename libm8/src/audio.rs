use crate::Error::AudioError;
use crate::*;

use sdl3::AudioSubsystem;
use sdl3::audio::{
    AudioDevice, AudioDeviceID, AudioRecordingCallback, AudioSpec, AudioStream, AudioStreamOwner,
    AudioStreamWithCallback,
};
use spectrum_analyzer::scaling::scale_to_zero_to_one;
use spectrum_analyzer::windows::hann_window;
use spectrum_analyzer::{FrequencyLimit, FrequencySpectrum, samples_fft_to_spectrum};

impl From<sdl3::Error> for Error {
    fn from(err: sdl3::Error) -> Self {
        AudioError(err.to_string())
    }
}

impl From<std::sync::PoisonError<std::sync::MutexGuard<'_, AudioStreamOwner>>> for Error {
    fn from(err: std::sync::PoisonError<std::sync::MutexGuard<'_, AudioStreamOwner>>) -> Self {
        AudioError(err.to_string())
    }
}

type Format = f32;

const AUDIO_FREQ: usize = 44100;

const AUDIO_FORMAT: sdl3::audio::AudioFormat = sdl3::audio::AudioFormat::f32_sys();

const AUDIO_BUFFER_SIZE: usize = 1024;

unsafe impl Send for AudioStreamHandle {}

fn input_devices(audio_subsystem: Option<AudioSubsystem>) -> Result<Vec<AudioDeviceID>, Error> {
    let audio_subsystem = match audio_subsystem {
        Some(subsystem) => subsystem,
        None => sdl3::init()
            .map_err(|s| AudioError(format!("Failed to initialize SDL3: {}", s)))?
            .audio()
            .map_err(|s| AudioError(format!("Failed to initialize SDL3 audio: {}", s)))?,
    };
    let mut ids = audio_subsystem.audio_recording_device_ids()?;
    ids.retain(|id| id.name().is_ok_and(|name| name.contains("M8")));
    Ok(ids)
}

fn output_devices(audio_subsystem: Option<AudioSubsystem>) -> Result<Vec<AudioDeviceID>, Error> {
    let audio_subsystem = match audio_subsystem {
        Some(subsystem) => subsystem,
        None => sdl3::init()
            .map_err(|s| AudioError(format!("Failed to initialize SDL3: {}", s)))?
            .audio()
            .map_err(|s| AudioError(format!("Failed to initialize SDL3 audio: {}", s)))?,
    };
    Ok(audio_subsystem.audio_playback_device_ids()?)
}

pub fn input_device_names() -> Result<Vec<String>, Error> {
    let input_devices = input_devices(None)?
        .iter()
        .filter_map(|device| device.name().ok())
        .collect();
    Ok(input_devices)
}

pub fn output_device_names() -> Result<Vec<String>, Error> {
    let output_devices = output_devices(None)?
        .iter()
        .filter_map(|device| device.name().ok())
        .collect();
    Ok(output_devices)
}

struct AudioStreamHandle(AudioStreamOwner);

struct AudioInCallback {
    output_stream: Option<AudioStreamHandle>,
    buffer: [Format; AUDIO_BUFFER_SIZE * 2],

    volume: f32,
    peaks: [f32; 2],

    spectrum_analyzer_enabled: bool,
    frequency_spectrum: Option<FrequencySpectrum>,
}

impl AudioInCallback {
    fn new(output_stream: AudioStreamOwner) -> Self {
        AudioInCallback {
            output_stream: Some(AudioStreamHandle(output_stream)),
            buffer: [Format::default(); AUDIO_BUFFER_SIZE * 2],

            volume: 1.0,
            peaks: [0.0, 0.0],

            spectrum_analyzer_enabled: true,
            frequency_spectrum: None,
        }
    }
}

impl AudioRecordingCallback<f32> for AudioInCallback {
    fn callback(&mut self, input_stream: &mut AudioStream, available: i32) {
        let Some(output_stream) = &self.output_stream else {
            // println!("No output stream available");
            return;
        };
        // println!("Audio received {} samples", available);
        self.peaks = [0.0, 0.0];

        let _ = input_stream.read_f32_samples(&mut self.buffer);

        if self.spectrum_analyzer_enabled {
            match samples_fft_to_spectrum(
                hann_window(&self.buffer).as_slice(),
                AUDIO_FREQ as u32,
                // FrequencyLimit::Range(20.0, 20000.0),
                FrequencyLimit::All,
                Some(&scale_to_zero_to_one),
            ) {
                Ok(spectrum) => {
                    self.frequency_spectrum = Some(spectrum);
                }
                Err(_) => {}
            }
        }

        for (i, sample) in self.buffer.iter_mut().take(available as usize).enumerate() {
            // apply volume
            *sample *= self.volume;

            // update peaks
            let channel = i % 2;
            let magnitude = sample.abs();
            if magnitude > self.peaks[channel] {
                self.peaks[channel] = magnitude;
            }
        }

        let _ = output_stream
            .0
            .put_data_f32(&self.buffer[..available as usize]);
    }
}

pub struct AudioBackend {
    // sdl_context: sdl2::Sdl,
    audio_subsystem: sdl3::AudioSubsystem,

    input_stream: Option<AudioStreamWithCallback<AudioInCallback>>,
    // output_stream: Option<Arc<Mutex<AudioStreamOwner>>>,
}

impl AudioBackend {
    const DESIRED_SPEC_IN: AudioSpec = AudioSpec {
        freq: Some(AUDIO_FREQ as i32),
        channels: Some(2),
        format: Some(AUDIO_FORMAT),
    };
    const DESIRED_SPEC_OUT: AudioSpec = AudioSpec {
        freq: Some(AUDIO_FREQ as i32),
        channels: Some(2),
        format: Some(AUDIO_FORMAT),
    };

    pub fn new() -> Result<Self, Error> {
        sdl3::hint::set(
            sdl3::hint::names::AUDIO_DEVICE_SAMPLE_FRAMES,
            &AUDIO_BUFFER_SIZE.to_string(),
        );
        sdl3::hint::set(sdl3::hint::names::AUDIO_DEVICE_STREAM_ROLE, "Game");

        let audio_subsystem = sdl3::init()?.audio()?;

        println!(
            "Audio drivers: {:?}",
            sdl3::audio::drivers().collect::<Vec<_>>()
        );

        Ok(AudioBackend {
            audio_subsystem,
            input_stream: None,
            // output_stream: None,
        })
    }

    pub fn peaks(&mut self) -> Option<[f32; 2]> {
        let input_stream = self.input_stream.as_mut()?;
        let callback = input_stream.lock()?;
        Some(callback.peaks)
    }

    pub fn spectrum_analyzer_enabled(&mut self) -> bool {
        let option: Option<bool> = (|| {
            let input_stream = self.input_stream.as_mut()?;
            let callback = input_stream.lock()?;
            Some(callback.spectrum_analyzer_enabled)
        })();
        option.unwrap_or(false)
    }

    pub fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) {
        let _: Option<()> = (|| {
            let input_stream = self.input_stream.as_mut()?;
            let mut callback = input_stream.lock()?;
            callback.spectrum_analyzer_enabled = enabled;
            Some(())
        })();
    }

    pub fn magnitude_at_freq(&mut self, freq: f32) -> Option<f32> {
        let input_stream = self.input_stream.as_mut()?;
        let callback = input_stream.lock()?;
        if callback.spectrum_analyzer_enabled {
            let spectrum = callback.frequency_spectrum.as_ref()?;
            return Some(spectrum.freq_val_exact(freq).val());
        }
        None
    }

    pub fn volume(&mut self) -> Option<f32> {
        let input_stream = self.input_stream.as_mut()?;
        let callback = input_stream.lock()?;
        Some(callback.volume)
    }

    pub fn set_volume(&mut self, volume: f32) -> Option<()> {
        let volume = {
            if volume > 1.0 {
                1.0
            } else if volume < 0.0 {
                0.0
            } else {
                volume
            }
        };
        let input_stream = self.input_stream.as_mut()?;
        let mut callback = input_stream.lock()?;
        callback.volume = volume;
        println!("Volume set to {:.02}", volume);
        Some(())
    }

    fn input_devices(&self) -> Result<Vec<AudioDeviceID>, Error> {
        input_devices(Some(self.audio_subsystem.clone()))
    }

    fn output_devices(&self) -> Result<Vec<AudioDeviceID>, Error> {
        output_devices(Some(self.audio_subsystem.clone()))
    }

    pub fn input_device_names(&self) -> Result<Vec<String>, Error> {
        let input_devices = self
            .input_devices()?
            .iter()
            .filter_map(|device| device.name().ok())
            .collect();
        Ok(input_devices)
    }

    pub fn output_device_names(&self) -> Result<Vec<String>, Error> {
        let output_devices = self
            .output_devices()?
            .iter()
            .filter_map(|device| device.name().ok())
            .collect();
        Ok(output_devices)
    }

    /// Get an [AudioDevice] where the name matches [preferred_input_device], or the first valid device
    /// if [None] is given.
    fn input_device(&self, preferred_input_device: Option<String>) -> Result<AudioDevice, Error> {
        let input_device_ids = self.input_devices()?;

        println!("Input devices: {:?}", input_device_ids);

        if input_device_ids.is_empty() {
            return Err(AudioError("No valid input devices found.".to_string()));
        }

        let id = match preferred_input_device {
            None => input_device_ids[0],
            Some(preferred_input_device) => {
                let input_device = input_device_ids
                    .iter()
                    .find(|id| {
                        id.name()
                            .is_ok_and(|name| name == preferred_input_device.as_str())
                    })
                    .ok_or(AudioError("Specified input device not found.".to_string()))?;
                input_device.to_owned()
            }
        };

        Ok(AudioDevice::new(id, self.audio_subsystem.to_owned()))
    }

    /// Get an [AudioDevice] where the name matches [preferred_output_device], or the default device
    /// if [None] is given.
    fn output_device(&self, preferred_output_device: Option<String>) -> Result<AudioDevice, Error> {
        let output_device_ids = self.output_devices()?;

        println!("Output devices: {:?}", output_device_ids);

        if output_device_ids.is_empty() {
            return Err(AudioError("No valid output devices found.".to_string()));
        }

        let Some(preferred_output_device) = preferred_output_device else {
            return Ok(self.audio_subsystem.default_playback_device());
        };

        let output_device = output_device_ids
            .iter()
            .find(|id| {
                id.name()
                    .is_ok_and(|name| name == preferred_output_device.as_str())
            })
            .ok_or(AudioError("Specified output device not found.".to_string()))?;

        Ok(AudioDevice::new(
            output_device.to_owned(),
            self.audio_subsystem.to_owned(),
        ))
    }

    pub fn start(
        &mut self,
        preferred_input_device: Option<String>,
        preferred_output_device: Option<String>,
    ) -> Result<(), Error> {
        let input_device = self.input_device(preferred_input_device)?;
        let output_device = self.output_device(preferred_output_device)?;

        println!(
            "Using input device: {}",
            input_device.id().name().unwrap_or("Unknown".to_string())
        );
        println!(
            "Using output device: {}",
            output_device.id().name().unwrap_or("Unknown".to_string())
        );

        let output_stream = output_device.open_device_stream(Some(&Self::DESIRED_SPEC_OUT))?;
        output_stream.resume()?;

        let input_stream = input_device.open_recording_stream_with_callback(
            &Self::DESIRED_SPEC_IN,
            AudioInCallback::new(output_stream),
        )?;

        input_stream.resume()?;

        self.input_stream = Some(input_stream);
        // self.output_stream = Some(output_stream);

        Ok(())
    }

    pub fn is_running(&self) -> bool {
        // Note that the input stream also owns the output stream
        self.input_stream.is_some()
    }
}
