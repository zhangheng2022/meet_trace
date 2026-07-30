#[cfg(any(target_os = "android", target_os = "ios", test))]
use std::path::Path;

#[cfg(any(target_os = "android", target_os = "ios"))]
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

#[cfg(any(target_os = "android", target_os = "ios", test))]
const SAMPLE_RATE: usize = 16_000;
#[cfg(any(target_os = "android", target_os = "ios", test))]
const MAX_PROBE_SECONDS: usize = 30;

pub struct WhisperProbeResult {
    pub model_type: String,
    pub segment_count: u32,
    pub transcript: String,
    pub sample_count: u32,
}

#[flutter_rust_bridge::frb]
pub fn probe_whisper_model(
    model_path: String,
    pcm_f32: Vec<f32>,
    language: Option<String>,
) -> Result<WhisperProbeResult, String> {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        return probe_whisper_model_mobile(model_path, pcm_f32, language);
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        let _ = (model_path, pcm_f32, language);
        Err("unsupported_platform".to_owned())
    }
}

#[cfg(any(target_os = "android", target_os = "ios"))]
fn probe_whisper_model_mobile(
    model_path: String,
    pcm_f32: Vec<f32>,
    language: Option<String>,
) -> Result<WhisperProbeResult, String> {
    validate_probe_input(&model_path, &pcm_f32)?;

    let context = WhisperContext::new_with_params(&model_path, WhisperContextParameters::default())
        .map_err(|error| format!("model_load_failed: {error}"))?;
    let model_type = context
        .model_type_readable_str()
        .map_err(|error| format!("model_type_failed: {error}"))?
        .to_owned();
    let mut state = context
        .create_state()
        .map_err(|error| format!("state_create_failed: {error}"))?;
    let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
    params.set_n_threads(1);
    params.set_language(language.as_deref());
    params.set_translate(false);
    params.set_no_context(true);
    params.set_single_segment(true);
    params.set_print_special(false);
    params.set_print_progress(false);
    params.set_print_realtime(false);
    params.set_print_timestamps(false);

    state
        .full(params, &pcm_f32)
        .map_err(|error| format!("inference_failed: {error}"))?;

    let transcript = state
        .as_iter()
        .map(|segment| {
            segment
                .to_str_lossy()
                .map(|text| text.into_owned())
                .map_err(|error| format!("segment_decode_failed: {error}"))
        })
        .collect::<Result<Vec<_>, _>>()?
        .join("");

    Ok(WhisperProbeResult {
        model_type,
        segment_count: state.full_n_segments().max(0) as u32,
        transcript,
        sample_count: pcm_f32.len() as u32,
    })
}

#[cfg(any(target_os = "android", target_os = "ios", test))]
fn validate_probe_input(model_path: &str, pcm_f32: &[f32]) -> Result<(), String> {
    if !Path::new(model_path).is_file() {
        return Err("model_not_found".to_owned());
    }
    if pcm_f32.is_empty() {
        return Err("pcm_empty".to_owned());
    }
    if pcm_f32.len() > SAMPLE_RATE * MAX_PROBE_SECONDS {
        return Err("pcm_too_long".to_owned());
    }
    if pcm_f32.iter().any(|sample| !sample.is_finite()) {
        return Err("pcm_not_finite".to_owned());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::validate_probe_input;

    #[test]
    fn rejects_empty_pcm() {
        let model = std::env::current_exe().expect("current executable path");
        assert_eq!(
            validate_probe_input(model.to_str().expect("UTF-8 executable path"), &[]),
            Err("pcm_empty".to_owned())
        );
    }

    #[test]
    fn rejects_non_finite_samples() {
        let model = std::env::current_exe().expect("current executable path");
        assert_eq!(
            validate_probe_input(model.to_str().expect("UTF-8 executable path"), &[f32::NAN]),
            Err("pcm_not_finite".to_owned())
        );
    }
}
