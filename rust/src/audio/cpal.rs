use crate as m8;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, Host, OutputCallbackInfo, StreamConfig};
use enum_map::EnumMap;
use m8::audio;
use m8::{Error, SpectrumAnalyzer};
use ringbuf::traits::{Consumer, Producer, Split};
use rubato::audioadapter_buffers::direct::InterleavedSlice;
use rubato::{self, Resampler};
use std::collections::{HashSet, VecDeque};
use std::sync::{Arc, Mutex};

use m8::audio::BUFFER_SIZE;
use m8::audio::LATENCY_BUFFER_SIZE;
use m8::audio::OSC_BUFFER_SIZE;

// use super::SAMPLE_RATE;
const SAMPLE_RATE: usize = 48000;

pub struct CpalAudioBackend {
    host: Host,
    multichannel_enabled: bool,
    input_device: Option<AudioStream>,
    output_device: Option<AudioStream>,
    track_buffers: Arc<Mutex<EnumMap<m8::Track, RingVec>>>,
    volume: Arc<Mutex<f32>>,
    volume_peaks: Arc<Mutex<[f32; 2]>>,

    spectrum_analyzer_enabled: Arc<Mutex<bool>>,
    spectrum: Arc<Mutex<SpectrumAnalyzer>>,
}

impl CpalAudioBackend {
    pub fn new() -> Result<Self, Error> {
        Ok(Self {
            host: cpal::default_host(),
            multichannel_enabled: false,
            input_device: None,
            output_device: None,
            track_buffers: Arc::new(Mutex::new(EnumMap::from_fn(|_| {
                RingVec::new(OSC_BUFFER_SIZE)
            }))),

            volume: Arc::new(Mutex::new(1.0)),
            volume_peaks: Arc::new(Mutex::new([0.0; 2])),

            spectrum_analyzer_enabled: Arc::new(Mutex::new(true)),
            spectrum: Arc::new(Mutex::new(SpectrumAnalyzer::new(SAMPLE_RATE as u32))),
        })
    }
}

impl super::AudioBackend for CpalAudioBackend {
    fn start(
        &mut self,
        input_device_name: Option<String>,
        output_device_name: Option<String>,
    ) -> Result<(), Error> {
        let usb_audio_mode = m8::UsbAudioMode::from(self.multichannel_enabled);
        let input_devices = find_input_devices(
            &self.host,
            &input_device_name,
            usb_audio_mode.num_channels(),
        )?;
        let output_device = find_output_device(&self.host, &output_device_name)?;

        let config_out = find_output_stream_config(&output_device)?;

        // println!("  Buffer size: {:?}", config_in.buffer_size);
        // let latency_ms = 20.0;
        // let latency_frames = (latency_ms / 1000.0) * config_in.sample_rate as f32;
        // let latency_samples = latency_frames as usize * 2 as usize;
        // let ring = HeapRb::<f32>::new(latency_samples * 2);

        let audio_buffer_size = BUFFER_SIZE * 4;
        let audio_buffer = ringbuf::HeapRb::<f32>::new(audio_buffer_size);
        let (mut data_prod, data_cons) = audio_buffer.split();
        for _ in 0..audio_buffer_size {
            data_prod.try_push(0.0).unwrap();
        }

        // println!("Using latency buffer of {} samples", latency_samples);
        println!("Using data buffer size: {}", audio_buffer_size);
        println!("Using multichannel mode: {usb_audio_mode:?}");

        if input_devices.is_empty() {
            return Err(Error::AudioError(
                "cpal-audio: No valid input devices found".to_string(),
            ));
        }

        for (device, config) in input_devices {
            let buffer_size = match &config.buffer_size {
                cpal::BufferSize::Fixed(size) => *size as usize,
                cpal::BufferSize::Default => panic!("buffer size is not fixed"),
            };
            if AudioStream::can_open_input(&device, &config) {
                self.input_device = Some(AudioStream::open_input(
                    device,
                    config,
                    self.on_input_data_received(
                        buffer_size,
                        data_prod,
                        Arc::clone(&self.track_buffers),
                    ),
                )?);
                break;
            }
        }

        if self.input_device.is_none() {
            return Err(Error::AudioError(
                "cpal-audio: Unable to open any input devices".to_string(),
            ));
        }

        let input_buffer_size = self.input_device.as_ref().unwrap().stream.buffer_size()?;
        let input_sample_rate = self.input_device.as_ref().unwrap().config.sample_rate;

        let output_buffer_size = match config_out.buffer_size {
            cpal::BufferSize::Fixed(size) => size,
            cpal::BufferSize::Default => panic!("buffer size is not fixed"),
        };
        let output_sample_rate = config_out.sample_rate;

        println!("cpal-audio: input buffer size = {input_buffer_size}");
        println!("cpal-audio: input sample rate = {input_sample_rate}");
        println!("cpal-audio: output buffer size = {output_buffer_size}");
        println!("cpal-audio: output sample rate = {output_sample_rate}");

        let resampler = rubato::Fft::<f32>::new(
            input_sample_rate as usize,
            output_sample_rate as usize,
            input_buffer_size as usize,
            2,
            rubato::FixedSync::Both,
        )
        .expect("failed to create resampler");

        self.output_device = Some(AudioStream::open_output(
            output_device,
            config_out,
            self.on_output_data_requested(
                data_cons,
                resampler,
                input_buffer_size as usize,
                output_buffer_size as usize,
            ),
        )?);

        Ok(())
    }

    fn stop(&mut self) -> Result<(), Error> {
        self.input_device = None;
        self.output_device = None;
        Ok(())
    }

    fn is_running(&self) -> bool {
        self.input_device.is_some() && self.output_device.is_some()
    }

    fn set_multichannel_mode(&mut self, enabled: bool) -> Result<(), Error> {
        self.multichannel_enabled = enabled;
        Ok(())
    }

    fn list_input_devices(&self) -> Result<Vec<String>, Error> {
        let names: Vec<String> = self
            .host
            .input_devices()
            .map_err(|e| Error::AudioError(e.to_string()))?
            .filter_map(|device| {
                device.supports_input().then_some(())?;
                let desc = device.description().ok()?;
                let config_range = device.default_input_config().ok()?;
                Some((device, desc, config_range, config_range.config()))
            })
            .filter_map(|(device, desc, config_range, config)| {
                if desc.name().contains("M8") {
                    println!("found input device: {}", desc.name());
                    println!("- supports input: {:?}", desc.supports_input());
                    println!("- supports output: {:?}", desc.supports_output());
                    println!("- device type: {:?}", desc.device_type());
                    println!("- interface type: {:?}", desc.interface_type());
                    println!("- direction: {:?}", desc.direction());
                    println!("- manufacturer: {:?}", desc.manufacturer());
                    println!("- driver: {:?}", desc.driver());
                    println!("- address: {:?}", desc.address());
                    println!("- channels: {}", config.channels);
                    println!("- sample rate: {}", config.sample_rate);
                    println!("- sample format: {:?}", config_range.sample_format());
                    println!("- buffer size range: {:?}", config_range.buffer_size());
                    println!("- buffer size: {:?}", config.buffer_size);
                    Some(device.to_string())
                } else {
                    None
                }
            })
            .collect::<HashSet<_>>()
            .into_iter()
            .collect();
        Ok(names)
    }

    fn list_output_devices(&self) -> Result<Vec<String>, Error> {
        let names: Vec<String> = self
            .host
            .output_devices()
            .map_err(|e| Error::AudioError(e.to_string()))?
            .filter_map(|dev| dev.description().ok())
            .filter_map(|desc| Some(desc.name().to_string()))
            .collect();
        Ok(names)
    }

    fn volume(&mut self) -> Result<f32, Error> {
        Ok(*self.volume.lock().as_deref().unwrap())
    }

    fn set_volume(&mut self, new_volume: f32) -> Result<(), Error> {
        *self.volume.lock().as_deref_mut().unwrap() = new_volume;
        Ok(())
    }

    fn peaks_linear(&mut self) -> Result<[f32; 2], Error> {
        match self.volume_peaks.lock() {
            Ok(peaks) => Ok(*peaks),
            Err(_) => Ok([0.0, 0.0]),
        }
    }

    fn value_at_frequency(&mut self, frequency: f32) -> Result<f32, Error> {
        if self.is_spectrum_analyzer_enabled()? {
            if let Ok(spectrum) = self.spectrum.lock() {
                return Ok(spectrum.value_at_frequency(frequency));
            };
        }
        Ok(0.0)
    }

    fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) -> Result<(), Error> {
        if let Ok(spectrum_analyzer_enabled) = self.spectrum_analyzer_enabled.lock().as_deref_mut()
        {
            *spectrum_analyzer_enabled = enabled;
        }
        Ok(())
    }

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error> {
        Ok(*self.spectrum_analyzer_enabled.lock().as_deref().unwrap())
    }

    fn input_spec(&self) -> Result<audio::AudioSpec, Error> {
        if let Some(device) = self.input_device.as_ref() {
            Ok(audio::AudioSpec {
                host: self.host.id().to_string(),
                format: "F32".to_string(),
                num_channels: device.config.channels as usize,
                sample_rate: device.config.sample_rate as usize,
                buffer_size: device.stream.buffer_size()? as usize,
            })
        } else {
            Ok(audio::AudioSpec {
                host: "n/a".to_string(),
                format: "n/a".to_string(),
                num_channels: 2,
                sample_rate: 44100,
                buffer_size: BUFFER_SIZE,
            })
        }
    }

    fn track_buffer(&self, track: m8::Track) -> Result<Vec<f32>, Error> {
        if let Ok(track_buffers) = self.track_buffers.lock() {
            Ok(track_buffers[track].to_vec())
        } else {
            Ok(Vec::new())
        }
    }
}

impl CpalAudioBackend {
    fn on_input_data_received(
        &self,
        buffer_size: usize,
        mut data_prod: ringbuf::HeapProd<f32>,
        track_buffers: Arc<Mutex<EnumMap<m8::Track, RingVec>>>,
    ) -> impl FnMut(&[f32], &cpal::InputCallbackInfo) + Send + 'static {
        let usb_audio_mode = m8::UsbAudioMode::from(self.multichannel_enabled);
        let num_channels = usb_audio_mode.num_channels();

        move |data, _| {
            // let expected = buffer_size * num_channels as usize;
            // if data.len() != expected {
            //     println!(
            //         "CPAL: Input callback - expected {expected} samples, got {}",
            //         data.len()
            //     );
            //     // return;
            // }

            // println!("CPAL: Input callback with {} samples", data.len());

            let Ok(mut track_buffers) = track_buffers.lock() else {
                return;
            };

            let chunks = data.chunks_exact(num_channels as usize);

            match usb_audio_mode {
                m8::UsbAudioMode::MULTICHANNEL => {
                    for sample in chunks {
                        for (track, track_data) in track_buffers.iter_mut() {
                            let (left_idx, right_idx) = track.channels();
                            let (left, right) = (sample[left_idx], sample[right_idx]);
                            track_data.push((left + right) / 2.0);

                            if track == m8::Track::Mix {
                                let _ = data_prod.try_push(left).and(data_prod.try_push(right));
                            }
                        }
                    }
                }
                m8::UsbAudioMode::STEREO => {
                    let track = m8::Track::Mix;
                    let track_data = &mut track_buffers[track];
                    for sample in chunks {
                        let (left_idx, right_idx) = track.channels();
                        let (left, right) = (sample[left_idx], sample[right_idx]);
                        track_data.push((left + right) / 2.0);

                        let _ = data_prod.try_push(left).and(data_prod.try_push(right));
                    }
                }
            }
        }
    }

    fn on_output_data_requested(
        &self,
        mut data_cons: ringbuf::HeapCons<f32>,
        mut resampler: rubato::Fft<f32>,
        buffer_size_in: usize,
        buffer_size_out: usize,
    ) -> impl FnMut(&mut [f32], &OutputCallbackInfo) + Send + 'static {
        let volume = self.volume.clone();
        let volume_peaks = self.volume_peaks.clone();
        let spectrum = self.spectrum.clone();
        let spectrum_enabled = self.spectrum_analyzer_enabled.clone();

        let mut buffer_in = vec![0.0; buffer_size_in * 2];
        let mut buffer_out = vec![0.0; buffer_size_out * 2];

        move |data, _| {
            let Ok(volume) = volume.lock() else {
                return;
            };
            let Ok(peaks) = &mut volume_peaks.lock() else {
                return;
            };
            let Ok(spectrum_enabled) = spectrum_enabled.lock() else {
                return;
            };

            peaks[0] = 0.0;
            peaks[1] = 0.0;

            data_cons.pop_slice(&mut buffer_in);

            let adapter_in = match InterleavedSlice::new(&buffer_in, 2, buffer_size_in) {
                Ok(adapter_in) => adapter_in,
                Err(e) => {
                    println!("size error when creating adapter_in:\n{e}");
                    return;
                }
            };
            let mut adapter_out =
                match InterleavedSlice::new_mut(&mut buffer_out, 2, buffer_size_out) {
                    Ok(adapter_out) => adapter_out,
                    Err(e) => {
                        println!("size error when creating adapter_out:\n{e}");
                        return;
                    }
                };

            if let Err(e) = resampler.process_into_buffer(&adapter_in, &mut adapter_out, None) {
                println!("error when resampling:\n{e}");
                return;
            }

            // println!("CPAL: Output callback with {} samples", data.len());

            for (i, sample) in data.iter_mut().enumerate() {
                let value = buffer_out[i];
                if value.abs() > peaks[i % 2] {
                    peaks[i % 2] = value.abs();
                }
                *sample = value * *volume;
            }

            if *spectrum_enabled && let Ok(mut spectrum) = spectrum.lock() {
                let len_pow2 = data.len().checked_ilog2().map(|exp| 1 << exp).unwrap_or(0);
                spectrum.update_fft(&data[..len_pow2]);
            }
        }
    }
}

impl From<cpal::Error> for Error {
    fn from(e: cpal::Error) -> Error {
        Error::AudioError(e.to_string())
    }
}

struct RingVec {
    deque: VecDeque<f32>,
    capacity: usize,
    // vec: Vec<f32>,
    // marker: usize,
}

impl RingVec {
    fn new(capacity: usize) -> Self {
        let mut deque = VecDeque::with_capacity(capacity);
        deque.make_contiguous().fill(0.0);
        Self { deque, capacity }
        // let vec = vec![0.0; capacity];
        // Self { vec, marker: 0 }
    }

    fn push(&mut self, value: f32) {
        if self.deque.len() == self.capacity {
            self.deque.pop_front();
        }
        self.deque.push_back(value);
        // self.vec[self.marker] = value;
        // self.marker = (self.marker + 1) % self.vec.capacity();
    }

    fn to_vec(&self) -> Vec<f32> {
        self.deque.clone().into()
        // self.vec.clone()
    }
}

fn find_input_devices(
    host: &Host,
    name: &Option<String>,
    channels: u16,
) -> Result<Vec<(cpal::Device, cpal::StreamConfig)>, Error> {
    println!("cpal-audio: Finding input devices with name: {name:?}");
    let devices = host
        .input_devices()?
        // filter to only devices with a valid name and description
        .filter_map(|device| {
            let desc = device.description().ok()?;
            if (match &name {
                Some(n) => desc.name().contains("M8") && n == &device.to_string(),
                None => desc.name().contains("M8"),
            }) && desc
                .driver()
                .is_some_and(|driver| !driver.to_lowercase().contains("sink"))
                && device.supports_input()
            {
                Some(device)
            } else {
                None
            }
        })
        // find a suitable config for each device
        .filter_map(|device| {
            if let Some(config) = find_input_stream_config(&device, 44100, channels).ok() {
                Some((device, config))
            } else if let Some(config) = find_input_stream_config(&device, 48000, channels).ok() {
                Some((device, config))
            } else {
                None
            }
        })
        .collect::<Vec<(cpal::Device, cpal::StreamConfig)>>();

    println!("cpal-audio: Found {} valid input devices", devices.len());
    Ok(devices)
}

fn find_output_device(host: &Host, name: &Option<String>) -> Result<Device, Error> {
    println!("cpal-audio: Finding output device with name: {name:?}");
    let device = match name {
        None => host.default_output_device(),
        Some(name) => host
            .output_devices()?
            .find(|device| device.description().is_ok_and(|desc| name == desc.name())),
    };
    if let Some(device) = device {
        println!(
            "cpal-audio: Found output device: {}",
            device.description()?.name()
        );
        Ok(device)
    } else {
        Err(Error::AudioError(
            "cpal-audio: No output device found".to_string(),
        ))
    }
}

fn find_input_stream_config(
    device: &Device,
    sample_rate: u32,
    channels: u16,
) -> Result<StreamConfig, Error> {
    let sample_format = cpal::SampleFormat::F32;
    let buffer_size = BUFFER_SIZE as u32;
    // let buffer_size = 1024u32;

    println!(
        "cpal-audio: Finding input stream config for device: {}, driver: {:?}, channels: {}",
        device.to_string(),
        device.description()?.driver(),
        channels
    );

    let supported_config = device
        .supported_input_configs()?
        .filter_map(|config_range| {
            // println!("- config range: {:?}", config_range);
            config_range.try_with_sample_rate(sample_rate)
        })
        .find(|config| {
            println!(
                "- config: {{ channels: {}, sample_format: {:?}, buffer_size: {:?} }}",
                config.channels(),
                config.sample_format(),
                config.buffer_size()
            );
            config.channels() == channels
                && config.sample_format() == sample_format
                && match config.buffer_size() {
                    cpal::SupportedBufferSize::Unknown => false,
                    cpal::SupportedBufferSize::Range { .. } => true,
                }
        })
        .ok_or(Error::AudioError(
            "Unable to find a valid input config".to_string(),
        ))?;

    let buffer_size = match supported_config.buffer_size() {
        cpal::SupportedBufferSize::Range { min, max } => {
            if &buffer_size >= min && &buffer_size <= max {
                buffer_size
            } else {
                println!("cpal-audio: using buffer size {min} instead of {buffer_size}");
                *min
            }
        }
        cpal::SupportedBufferSize::Unknown => buffer_size,
    };
    let mut config = supported_config.config();
    config.buffer_size = cpal::BufferSize::Fixed(buffer_size);
    Ok(config)
}

fn find_output_stream_config(device: &Device) -> Result<StreamConfig, Error> {
    let sample_format = cpal::SampleFormat::F32;
    let sample_rate = SAMPLE_RATE as u32;
    let buffer_size = BUFFER_SIZE as u32;
    // let buffer_size = 1024u32;
    let channels = 2u16;

    println!(
        "cpal-audio: Finding output stream config for device: {}, driver: {:?}, channels: {}",
        device.to_string(),
        device.description()?.driver(),
        channels
    );

    let supported_config = device
        .supported_output_configs()?
        .find(|config| {
            config.channels() == channels
                && config.contains_rate(sample_rate)
                && config.sample_format() == sample_format
                && match config.buffer_size() {
                    cpal::SupportedBufferSize::Unknown => false,
                    cpal::SupportedBufferSize::Range { .. } => true,
                }
        })
        .ok_or(Error::AudioError(
            "Unable to find a valid output config".to_string(),
        ))?;

    let buffer_size = match supported_config.buffer_size() {
        cpal::SupportedBufferSize::Range { min, max } => {
            if &buffer_size >= min && &buffer_size <= max {
                buffer_size
            } else {
                println!("cpal-audio: using buffer size {min} instead of {buffer_size}");
                *min
            }
        }
        cpal::SupportedBufferSize::Unknown => buffer_size,
    };

    Ok(StreamConfig {
        sample_rate,
        buffer_size: cpal::BufferSize::Fixed(buffer_size),
        channels,
    })
}

struct AudioStream {
    // pub device: cpal::Device,
    pub config: cpal::StreamConfig,
    pub stream: cpal::Stream,
}

impl AudioStream {
    fn open_input(
        device: cpal::Device,
        config: cpal::StreamConfig,
        callback: impl FnMut(&[f32], &cpal::InputCallbackInfo) + Send + 'static,
    ) -> Result<Self, Error> {
        let name = device.to_string();
        let desc = device.description()?;
        let id = device.id()?;
        let driver = desc.driver();
        println!(
            "cpal-audio: Opening input stream for device: {name} \n\
             -     id: {id:?} \n\
             - driver: {driver:?} \n\
             - config: {config:?}",
        );
        let stream = device.build_input_stream(
            config,
            callback,
            |err| eprintln!("Input stream error: {}", err),
            None,
        )?;
        stream.play()?;
        Ok(Self {
            // device,
            config,
            stream,
        })
    }

    fn open_output(
        device: cpal::Device,
        config: cpal::StreamConfig,
        callback: impl FnMut(&mut [f32], &cpal::OutputCallbackInfo) + Send + 'static,
    ) -> Result<Self, Error> {
        let name = device.to_string();
        let desc = device.description()?;
        let id = device.id()?;
        let driver = desc.driver();
        println!(
            "cpal-audio: Opening output stream for device: {name} \n\
             -     id: {id:?} \n\
             - driver: {driver:?} \n\
             - config: {config:?}",
        );
        let stream = device.build_output_stream(
            config,
            callback,
            |err| eprintln!("Output stream error: {}", err),
            None,
        )?;
        stream.play()?;
        Ok(Self {
            // device,
            config,
            stream,
        })
    }

    fn can_open_input(device: &cpal::Device, config: &cpal::StreamConfig) -> bool {
        device
            .build_input_stream(
                config.clone(),
                |_: &[f32], _| return,
                |err| eprintln!("Input stream error: {}", err),
                None,
            )
            .is_ok()
    }
}
