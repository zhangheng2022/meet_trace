pub struct RustRuntimeInfo {
    pub bridge_version: String,
    pub whisper_rs_version: String,
    pub rust_version: String,
}

#[flutter_rust_bridge::frb]
pub fn rust_runtime_info() -> RustRuntimeInfo {
    RustRuntimeInfo {
        bridge_version: "2.12.0".to_owned(),
        whisper_rs_version: "0.16.0".to_owned(),
        rust_version: "1.88.0".to_owned(),
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::rust_runtime_info;

    #[test]
    fn reports_pinned_component_versions() {
        let info = rust_runtime_info();

        assert_eq!(info.bridge_version, "2.12.0");
        assert_eq!(info.whisper_rs_version, "0.16.0");
        assert_eq!(info.rust_version, "1.88.0");
    }
}
