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

$requiredAbis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')
$whisperLibraryEntries = @($requiredAbis | ForEach-Object {
    "lib/$_/libmeettrace_whisper.so"
})
$missingWhisperLibraries = @($whisperLibraryEntries | Where-Object {
    $_ -notin $entries
})
$expectedBundledAssets = @(
    'assets/flutter_assets/assets/licenses/whisper-cpp-NOTICE.txt',
    'assets/flutter_assets/assets/models/manifest.json',
    'assets/flutter_assets/assets/models/whisper-cpp-base-q5_1-v1.9.1/ggml-base-q5_1.bin',
    'assets/flutter_assets/assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin'
)
$missingBundledAssets = @($expectedBundledAssets | Where-Object { $_ -notin $entries })
$forbiddenLegacyEntries = @($entries | Where-Object {
    $_ -match '(?i)(sherpa|paraformer|qwen3-asr|\.onnx$)'
})
$approvedVadAssetEntry = $expectedBundledAssets[3]
$forbiddenUnapprovedVadEntries = @($entries | Where-Object {
    $_ -match '(?i)(silero|whisper-vad)' -and $_ -ne $approvedVadAssetEntry
})
$forbiddenSmallEntries = @($entries | Where-Object {
    $_ -match '(?i)(whisper-cpp-small|ggml-small)'
})
$forbiddenUserDataEntries = @($entries | Where-Object {
    $_ -match '(?i)\.(wav|pcm|m4a|aac|mp3|ogg|flac|sqlite|sqlite3|db)$'
})
$flutterNoticesEntry = 'assets/flutter_assets/NOTICES.Z'
$hasFlutterNotices = $flutterNoticesEntry -in $entries
$baseAssetEntry = $expectedBundledAssets[2]
$baseExpectedBytes = 59707625
$baseExpectedSha256 = '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898'
$baseActualBytes = $null
$baseActualSha256 = $null
$vadExpectedBytes = 885098
$vadExpectedSha256 = '2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987'
$vadActualBytes = $null
$vadActualSha256 = $null
$suspiciousSecretEntries = @()
$secretPattern =
    '(?i)(sk-[a-z0-9_-]{20,}|AIza[0-9a-z_-]{30,}|AKIA[0-9A-Z]{16}|' +
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
try {
    $baseEntry = $archive.GetEntry($baseAssetEntry)
    if ($null -ne $baseEntry) {
        $baseActualBytes = $baseEntry.Length
        $stream = $baseEntry.Open()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $digest = $sha.ComputeHash($stream)
            $baseActualSha256 = -join ($digest | ForEach-Object { $_.ToString('x2') })
        }
        finally {
            $sha.Dispose()
            $stream.Dispose()
        }
    }
    $vadEntry = $archive.GetEntry($approvedVadAssetEntry)
    if ($null -ne $vadEntry) {
        $vadActualBytes = $vadEntry.Length
        $stream = $vadEntry.Open()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $digest = $sha.ComputeHash($stream)
            $vadActualSha256 = -join ($digest | ForEach-Object { $_.ToString('x2') })
        }
        finally {
            $sha.Dispose()
            $stream.Dispose()
        }
    }

    foreach ($entry in $archive.Entries) {
        $isSecretScanCandidate =
            $entry.FullName -match '^classes[^/]*\.dex$' -or
            $entry.FullName -match '^lib/[^/]+/libapp\.so$' -or
            ($entry.FullName -match '^assets/flutter_assets/' -and
                $entry.FullName -notmatch '^assets/flutter_assets/NOTICES\.Z$' -and
                $entry.FullName -notmatch '\.bin$')
        if (-not $isSecretScanCandidate -or
            $entry.Length -eq 0 -or
            $entry.Length -gt 20MB) {
            continue
        }
        $entryStream = $entry.Open()
        $reader = [System.IO.StreamReader]::new(
            $entryStream,
            [System.Text.Encoding]::UTF8,
            $true,
            4096,
            $false
        )
        try {
            if ($reader.ReadToEnd() -match $secretPattern) {
                $suspiciousSecretEntries += $entry.FullName
            }
        }
        finally {
            $reader.Dispose()
        }
    }
}
finally {
    $archive.Dispose()
}

$baseIntegrityMatches =
    $baseActualBytes -eq $baseExpectedBytes -and
    $baseActualSha256 -eq $baseExpectedSha256
$vadIntegrityMatches =
    $vadActualBytes -eq $vadExpectedBytes -and
    $vadActualSha256 -eq $vadExpectedSha256
$report = [ordered]@{
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    apkPath = $ApkPath
    apkBytes = (Get-Item -LiteralPath $ApkPath).Length
    requiredAbis = $requiredAbis
    whisperLibraryEntries = $whisperLibraryEntries
    missingWhisperLibraries = $missingWhisperLibraries
    missingBundledAssets = $missingBundledAssets
    forbiddenLegacyEntries = $forbiddenLegacyEntries
    forbiddenUnapprovedVadEntries = $forbiddenUnapprovedVadEntries
    forbiddenSmallEntries = $forbiddenSmallEntries
    baseAssetEntry = $baseAssetEntry
    baseExpectedBytes = $baseExpectedBytes
    baseActualBytes = $baseActualBytes
    baseExpectedSha256 = $baseExpectedSha256
    baseActualSha256 = $baseActualSha256
    baseIntegrityMatches = $baseIntegrityMatches
    vadAssetEntry = $approvedVadAssetEntry
    vadExpectedBytes = $vadExpectedBytes
    vadActualBytes = $vadActualBytes
    vadExpectedSha256 = $vadExpectedSha256
    vadActualSha256 = $vadActualSha256
    vadIntegrityMatches = $vadIntegrityMatches
    flutterNoticesEntry = $flutterNoticesEntry
    hasFlutterNotices = $hasFlutterNotices
    forbiddenUserDataEntries = $forbiddenUserDataEntries
    suspiciousSecretEntries = $suspiciousSecretEntries
}
$output = Join-Path $repoRoot '.spike\results\apk-inspection.json'
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($output)) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding utf8
Write-Host "APK inspection report: $output"

if (-not $hasFlutterNotices -or
    -not $baseIntegrityMatches -or
    -not $vadIntegrityMatches -or
    $missingWhisperLibraries.Count -gt 0 -or
    $missingBundledAssets.Count -gt 0 -or
    $forbiddenLegacyEntries.Count -gt 0 -or
    $forbiddenUnapprovedVadEntries.Count -gt 0 -or
    $forbiddenSmallEntries.Count -gt 0 -or
    $forbiddenUserDataEntries.Count -gt 0 -or
    $suspiciousSecretEntries.Count -gt 0) {
    throw 'APK Whisper model asset or native library inspection failed.'
}
