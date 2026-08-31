use crate as m8;

use std::ffi::CStr;
use std::os::raw::c_int;

use m8::Error;
use m8::Error::AudioError;
use m8::SpectrumAnalyzer;
use m8::audio;

use sdl3::AudioSubsystem;
use sdl3::audio::{
    AudioDevice, AudioDeviceID, AudioRecordingCallback, AudioStream, AudioStreamLockGuard,
    AudioStreamOwner, AudioStreamWithCallback,
};
use sdl3::sys::audio::{SDL_AudioFormat, SDL_AudioSpec, SDL_GetAudioDeviceFormat};
use sdl3::sys::error::SDL_GetError;

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

type SdlAudioSpec = sdl3::audio::AudioSpec;

use m8::audio::SAMPLE_RATE;

const AUDIO_FORMAT: sdl3::audio::AudioFormat = sdl3::audio::AudioFormat::f32_sys();
const BUFFER_SIZE: usize = 1024;

unsafe impl Send for AudioStreamHandle {}

fn sdl3_init_audio() -> Result<AudioSubsystem, Error> {
    Ok(sdl3::init()
        .map_err(|s| AudioError(format!("Failed to initialize SDL3: {}", s)))?
        .audio()
        .map_err(|s| AudioError(format!("Failed to initialize SDL3 audio: {}", s)))?)
}

fn get_input_device_ids() -> Result<Vec<AudioDeviceID>, Error> {
    let host = sdl3_init_audio()?;
    println!("sdl-audio: enumerating input device ids");
    let ids = host.audio_recording_device_ids()?;
    println!("sdl-audio: found {} input device ids:", ids.len());
    for id in &ids {
        println!("- {:?}", id.name());
    }
    Ok(ids)
}

fn get_output_device_ids() -> Result<Vec<AudioDeviceID>, Error> {
    let host = sdl3_init_audio()?;
    println!("sdl-audio: enumerating output device ids");
    let ids = host.audio_playback_device_ids()?;
    println!("sdl-audio: found {} output device ids", ids.len());
    Ok(ids)
}

pub fn input_device_names() -> Result<Vec<String>, Error> {
    let host = sdl3_init_audio()?;
    println!("sdl-audio: enumerating input device ids");
    let ids = host.audio_recording_device_ids()?;
    println!("sdl-audio: found {} input device ids:", ids.len());
    for id in &ids {
        println!("- {:?}", id.name());
    }

    let names: Vec<String> = ids
        .iter()
        .filter_map(|id| id.name().ok())
        .filter(|name| name.contains("M8"))
        .collect();

    println!("sdl-audio: found {} input device names", names.len());
    Ok(names)
}

pub fn output_device_names() -> Result<Vec<String>, Error> {
    let host = sdl3_init_audio()?;
    println!("sdl-audio: enumerating output device ids");
    let ids = host.audio_playback_device_ids()?;
    let names: Vec<String> = ids.iter().filter_map(|device| device.name().ok()).collect();
    println!("sdl-audio: found {} output device names", names.len());
    Ok(names)
}

struct AudioStreamHandle(AudioStreamOwner);

struct AudioInCallback {
    output_stream: Option<AudioStreamHandle>,
    buffer: Vec<f32>,

    volume: f32,
    peaks: [f32; 2],

    spectrum_analyzer_enabled: bool,
    spectrum: SpectrumAnalyzer,
}

impl AudioInCallback {
    fn new(output_stream: AudioStreamOwner, volume: f32) -> Self {
        AudioInCallback {
            output_stream: Some(AudioStreamHandle(output_stream)),
            buffer: vec![0.0; BUFFER_SIZE * 2],

            volume,
            peaks: [0.0, 0.0],

            spectrum_analyzer_enabled: true,
            spectrum: SpectrumAnalyzer::new(audio::SAMPLE_RATE as u32),
        }
    }

    fn set_buffer_size(&mut self, size: usize) {
        self.buffer.resize(size * 2, 0.0);
    }
}

impl AudioRecordingCallback<f32> for AudioInCallback {
    fn callback(&mut self, input_stream: &mut AudioStream, available: i32) {
        // println!("Audio received {} samples", available);
        if available > self.buffer.len() as i32 {
            println!("Received {} samples, resizing buffer.", available);
            self.set_buffer_size(available as usize);
        }

        let Some(output_stream) = &self.output_stream else {
            // println!("No output stream available");
            return;
        };

        self.peaks = [0.0, 0.0];

        let _ = input_stream.read_f32_samples(&mut self.buffer);

        if self.spectrum_analyzer_enabled {
            self.spectrum.update_fft(&self.buffer);
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

pub struct SdlAudioHandler {
    // sdl_context: sdl2::Sdl,
    audio_subsystem: sdl3::AudioSubsystem,

    input_stream: AudioStreamWithCallback<AudioInCallback>,
    input_stream_spec: (SdlAudioSpec, usize),

    volume: f32,
    // output_stream: Option<Arc<Mutex<AudioStreamOwner>>>,
}

impl SdlAudioHandler {
    const DESIRED_SPEC_IN: SdlAudioSpec = SdlAudioSpec {
        freq: Some(SAMPLE_RATE as i32),
        channels: Some(2),
        format: Some(AUDIO_FORMAT),
    };
    const DESIRED_SPEC_OUT: SdlAudioSpec = SdlAudioSpec {
        freq: Some(SAMPLE_RATE as i32),
        channels: Some(2),
        format: Some(AUDIO_FORMAT),
    };

    fn callback_lock(&mut self) -> Result<AudioStreamLockGuard<'_, AudioInCallback>, Error> {
        let callback = self
            .input_stream
            .lock()
            .ok_or(AudioError("Failed to lock audio stream".to_string()))?;
        Ok(callback)
    }

    /// Get an [AudioDevice] where the name matches [preferred_input_device], or the first valid device
    /// if [None] is given.
    fn input_device(
        audio_subsystem: &AudioSubsystem,
        preferred_input_device: Option<String>,
    ) -> Result<AudioDevice, Error> {
        let input_device_ids = get_input_device_ids()?;

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

        Ok(AudioDevice::new(id, audio_subsystem.to_owned()))
    }

    /// Get an [AudioDevice] where the name matches [preferred_output_device], or the default device
    /// if [None] is given.
    fn output_device(
        audio_subsystem: &AudioSubsystem,
        preferred_output_device: Option<String>,
    ) -> Result<AudioDevice, Error> {
        let output_device_ids = get_output_device_ids()?;

        println!("Output devices: {:?}", output_device_ids);

        if output_device_ids.is_empty() {
            return Err(AudioError("No valid output devices found.".to_string()));
        }

        let Some(preferred_output_device) = preferred_output_device else {
            return Ok(audio_subsystem.default_playback_device());
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
            audio_subsystem.to_owned(),
        ))
    }

    fn driver_name(&self) -> String {
        self.audio_subsystem.current_audio_driver().to_string()
    }

    fn get_audio_spec(device_id: AudioDeviceID) -> Result<(SdlAudioSpec, usize), Error> {
        unsafe {
            let mut spec = SDL_AudioSpec {
                format: SDL_AudioFormat::UNKNOWN,
                channels: 0,
                freq: 0,
            };
            let mut samples: c_int = 0;
            let ok = SDL_GetAudioDeviceFormat(device_id.id(), &mut spec, &mut samples);
            if ok == true {
                Ok((SdlAudioSpec::from(&spec), samples as usize))
            } else {
                let err = CStr::from_ptr(SDL_GetError())
                    .to_str()
                    .ok()
                    .unwrap_or("Unknown error")
                    .to_string();
                Err(AudioError(format!(
                    "Failed to get audio device format: {}",
                    err
                )))
            }
        }
    }
}

impl super::AudioHandler for SdlAudioHandler {
    fn list_input_devices() -> Result<Vec<String>, Error> {
        Ok(input_device_names()?)
    }

    fn list_output_devices() -> Result<Vec<String>, Error> {
        Ok(output_device_names()?)
    }

    fn new(
        input_device: Option<String>,
        output_device: Option<String>,
        _multichannel_enabled: bool,
    ) -> Result<Self, Error> {
        println!(
            "Audio drivers: {:?}",
            sdl3::audio::drivers().collect::<Vec<_>>()
        );

        let volume = 1.0;

        let audio_subsystem = sdl3_init_audio()?;

        sdl3::hint::set(
            sdl3::hint::names::AUDIO_DEVICE_SAMPLE_FRAMES,
            &BUFFER_SIZE.to_string(),
        );
        sdl3::hint::set(sdl3::hint::names::AUDIO_DEVICE_STREAM_ROLE, "Media");

        let input_device = Self::input_device(&audio_subsystem, input_device)?;
        let output_device = Self::output_device(&audio_subsystem, output_device)?;

        println!(
            "sdl-audio: using input device: {}",
            input_device.id().name().unwrap_or("Unknown".to_string())
        );
        println!(
            "sdl-audio: using output device: {}",
            output_device.id().name().unwrap_or("Unknown".to_string())
        );

        println!("sdl-audio: opening output stream...");
        let output_stream = output_device
            .clone()
            .open_device_stream(Some(&Self::DESIRED_SPEC_OUT))?;
        output_stream.resume()?;
        println!("sdl-audio: opening output stream done");

        println!("sdl-audio: opening input stream...");
        let cb = AudioInCallback::new(output_stream, volume);
        let input_stream =
            input_device.open_recording_stream_with_callback(&Self::DESIRED_SPEC_IN, cb)?;
        input_stream.resume()?;
        println!("sdl-audio: opening input stream done");

        let input_stream_spec = Self::get_audio_spec(input_device.id())?;

        // self.output_stream = Some(output_stream);

        Ok(SdlAudioHandler {
            audio_subsystem,
            input_stream,
            input_stream_spec,
            volume,
            // output_stream: None,
        })
    }

    fn volume(&mut self) -> Result<f32, Error> {
        Ok(self.callback_lock()?.volume)
    }

    fn set_volume(&mut self, volume: f32) -> Result<(), Error> {
        self.volume = volume.clamp(0.0, 1.0);
        println!("libm8: Setting volume to {}", self.volume);
        Ok(self.callback_lock()?.volume = self.volume)
    }

    fn peaks_linear(&mut self) -> Result<[f32; 2], Error> {
        Ok(self.callback_lock()?.peaks)
    }

    fn value_at_frequency(&mut self, frequency: f32) -> Result<f32, Error> {
        if let Ok(callback) = self.callback_lock() {
            if callback.spectrum_analyzer_enabled {
                return Ok(callback.spectrum.value_at_frequency(frequency));
            }
        }
        Ok(0.0)
    }

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error> {
        Ok(self.callback_lock()?.spectrum_analyzer_enabled)
    }

    fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) -> Result<(), Error> {
        self.callback_lock()?.spectrum_analyzer_enabled = enabled;
        Ok(())
    }

    fn input_spec(&self) -> Result<audio::AudioSpec, Error> {
        let (spec, samples) = &self.input_stream_spec;
        Ok(audio::AudioSpec {
            host: self.driver_name(),
            format: format_name(spec.format),
            num_channels: spec.channels.unwrap_or(0) as usize,
            sample_rate: spec.freq.unwrap_or(0) as usize,
            buffer_size: samples.clone(),
        })
    }

    fn track_buffer(&self, _track: m8::Track) -> Result<Vec<f32>, Error> {
        Ok(vec![0.0; BUFFER_SIZE * 2])
    }

    fn set_multichannel_mode(&mut self, _enabled: bool) -> Result<(), Error> {
        Ok(())
    }
}

fn format_name(format: Option<sdl3::audio::AudioFormat>) -> String {
    let Some(format) = format else {
        return "UNKNOWN".to_string();
    };
    match format {
        sdl3::audio::AudioFormat::U8 => "U8".to_string(),
        sdl3::audio::AudioFormat::S8 => "S8".to_string(),
        sdl3::audio::AudioFormat::S16LE => "S16LE".to_string(),
        sdl3::audio::AudioFormat::S16BE => "S16BE".to_string(),
        sdl3::audio::AudioFormat::S32LE => "S32LE".to_string(),
        sdl3::audio::AudioFormat::S32BE => "S32BE".to_string(),
        sdl3::audio::AudioFormat::F32LE => "F32LE".to_string(),
        sdl3::audio::AudioFormat::F32BE => "F32BE".to_string(),
        sdl3::audio::AudioFormat::UNKNOWN => "UNKNOWN".to_string(),
    }
}
