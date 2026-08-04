param(
    [string]$ApkPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
}
$ApkPath = [System.IO.Path]::GetFullPath($ApkPath)
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw "APK not found: $ApkPath"
}

$entries = & tar -tf $ApkPath
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read APK ZIP entries.'
}

$requiredAssets = @(
    'assets/flutter_assets/assets/models/manifest.json',
    'assets/flutter_assets/assets/models/silero-vad-manifest.json',
    'assets/flutter_assets/assets/models/speaker-diarization-manifest.json',
    'assets/flutter_assets/assets/licenses/sense-voice-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/sense-voice-LICENSE.txt',
    'assets/flutter_assets/assets/licenses/silero-vad-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/silero-vad-LICENSE.txt',
    'assets/flutter_assets/assets/licenses/pyannote-segmentation-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/pyannote-segmentation-LICENSE.txt',
    'assets/flutter_assets/assets/licenses/3d-speaker-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/3d-speaker-LICENSE.txt'
)
$missingAssets = @($requiredAssets | Where-Object { $_ -notin $entries })
$forbiddenWeights = @($entries | Where-Object {
    $_ -match '(?i)(\.onnx$|\.tflite$|\.tar\.bz2$|/tokens\.txt$|/model\.int8(?:\.bin)?$|paraformer|qwen3-asr|sense-voice-.*/model|silero_vad.*\.onnx)'
})
$forbiddenUserData = @($entries | Where-Object {
    $_ -match '(?i)\.(wav|pcm|m4a|aac|mp3|ogg|flac|sqlite|sqlite3|db)$'
})
$nativeLibraries = @($entries | Where-Object { $_ -match '^lib/[^/]+/.*\.so$' })
$abis = @($nativeLibraries | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
$hasArm64 = 'arm64-v8a' -in $abis
$hasNotices = 'assets/flutter_assets/NOTICES.Z' -in $entries

$report = [ordered]@{
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    apkPath = $ApkPath
    apkBytes = (Get-Item -LiteralPath $ApkPath).Length
    abis = $abis
    hasArm64 = $hasArm64
    hasFlutterNotices = $hasNotices
    requiredAssets = $requiredAssets
    missingAssets = $missingAssets
    forbiddenWeights = $forbiddenWeights
    forbiddenUserData = $forbiddenUserData
}
$output = Join-Path $repoRoot '.spike\results\apk-inspection.json'
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($output)) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding utf8
Write-Host "APK inspection report: $output"

if (-not $hasArm64 -or -not $hasNotices -or $missingAssets.Count -gt 0 -or
    $forbiddenWeights.Count -gt 0 -or $forbiddenUserData.Count -gt 0) {
    throw 'APK model weight or packaging inspection failed.'
}
