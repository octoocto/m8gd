use spectrum_analyzer::scaling::scale_to_zero_to_one;
use spectrum_analyzer::windows::hann_window;
use spectrum_analyzer::{FrequencyLimit, FrequencySpectrum, samples_fft_to_spectrum};

pub struct SpectrumAnalyzer {
    spectrum: FrequencySpectrum,
    sample_rate: u32,
}

impl SpectrumAnalyzer {
    pub fn new(sample_rate: u32) -> Self {
        Self {
            spectrum: FrequencySpectrum::default(),
            sample_rate,
        }
    }

    pub fn value_at_frequency(&self, frequency: f32) -> f32 {
        if self.spectrum.samples_len() > 0 {
            let min = self.spectrum.min_fr().val();
            let max = self.spectrum.max_fr().val();
            if (min..=max).contains(&frequency) {
                return self.spectrum.freq_val_exact(frequency).val();
            }
        }
        0.0
    }

    pub fn update_fft(&mut self, data: &[f32]) {
        match samples_fft_to_spectrum(
            hann_window(data).as_slice(),
            self.sample_rate,
            FrequencyLimit::All,
            Some(&scale_to_zero_to_one),
        ) {
            Ok(spectrum) => {
                self.spectrum = spectrum;
            }
            Err(e) => {
                eprintln!("FFT error: {}", e);
            }
        }
    }
}
