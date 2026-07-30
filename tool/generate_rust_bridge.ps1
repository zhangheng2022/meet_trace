param()

$ErrorActionPreference = 'Stop'

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (-not (Test-Path -LiteralPath $cargoBin -PathType Container)) {
    throw "Rust cargo bin directory not found: $cargoBin"
}

$env:PATH = "$cargoBin;$env:PATH"
$env:CARGO_TARGET_DIR = Join-Path $env:TEMP 'meettrace-asr-cargo-target'
$codegen = Get-Command flutter_rust_bridge_codegen -ErrorAction Stop
$version = & $codegen.Source --version
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read flutter_rust_bridge_codegen version.'
}
if ($version -notmatch '\b2\.12\.0\b') {
    throw "Expected flutter_rust_bridge_codegen 2.12.0, got: $version"
}

& $codegen.Source generate --config-file flutter_rust_bridge.yaml
if ($LASTEXITCODE -ne 0) {
    throw "flutter_rust_bridge_codegen failed with exit code $LASTEXITCODE."
}
