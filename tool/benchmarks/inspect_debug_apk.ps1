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
$nativeLibraries = $entries | Where-Object { $_ -match '^lib/[^/]+/.*\.so$' }
$abis = $nativeLibraries |
    ForEach-Object { ($_ -split '/')[1] } |
    Sort-Object -Unique
$duplicates = $nativeLibraries |
    ForEach-Object { [System.IO.Path]::GetFileName($_) } |
    Group-Object |
    Where-Object { $_.Count -gt $abis.Count }
$expectedBundledAssets = @(
    'assets/flutter_assets/assets/licenses/paraformer-small-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/qwen3-asr-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/silero-vad-NOTICE.txt',
    'assets/flutter_assets/assets/licenses/silero-vad-LICENSE.txt',
    'assets/flutter_assets/assets/models/manifest.json',
    'assets/flutter_assets/assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/model.int8.onnx',
    'assets/flutter_assets/assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/tokens.txt',
    'assets/flutter_assets/assets/models/silero-vad-manifest.json',
    'assets/flutter_assets/assets/models/silero-vad-int8-2025-07-11/silero_vad.int8.onnx'
)
$bundledModelEntries = $entries | Where-Object {
    $_ -match '^assets/flutter_assets/assets/(models|licenses)/'
}
$missingBundledAssets = $expectedBundledAssets | Where-Object {
    $_ -notin $entries
}
$unexpectedModelEntries = $entries | Where-Object {
    ($_ -match '(?i)qwen3-asr|encoder\.int8\.onnx|decoder\.int8\.onnx|\.onnx$') -and
    ($_ -notin $expectedBundledAssets)
}
$requiredAbi = 'arm64-v8a'
$hasRequiredAbi = $requiredAbi -in $abis
$flutterNoticesEntry = 'assets/flutter_assets/NOTICES.Z'
$hasFlutterNotices = $flutterNoticesEntry -in $entries
$vadAssetEntry = 'assets/flutter_assets/assets/models/silero-vad-int8-2025-07-11/silero_vad.int8.onnx'
$vadExpectedBytes = 212860
$vadExpectedSha256 = 'c36d490aff5ab924ca6c7aeec4d8f6bd3d22db6fa17611b9c5b17eae58ac3a20'
$vadActualBytes = $null
$vadActualSha256 = $null
$vadIntegrityMatches = $false

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
try {
    $vadEntry = $archive.GetEntry($vadAssetEntry)
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
        $vadIntegrityMatches =
            $vadActualBytes -eq $vadExpectedBytes -and
            $vadActualSha256 -eq $vadExpectedSha256
    }
}
finally {
    $archive.Dispose()
}

$report = [ordered]@{
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    apkPath = $ApkPath
    apkBytes = (Get-Item -LiteralPath $ApkPath).Length
    requiredAbi = $requiredAbi
    hasRequiredAbi = $hasRequiredAbi
    abis = @($abis)
    nativeLibraries = @($nativeLibraries)
    suspiciousDuplicateLibraries = @($duplicates | ForEach-Object { $_.Name })
    bundledModelEntries = @($bundledModelEntries)
    missingBundledAssets = @($missingBundledAssets)
    unexpectedModelEntries = @($unexpectedModelEntries)
    flutterNoticesEntry = $flutterNoticesEntry
    hasFlutterNotices = $hasFlutterNotices
    vadAssetEntry = $vadAssetEntry
    vadExpectedBytes = $vadExpectedBytes
    vadActualBytes = $vadActualBytes
    vadExpectedSha256 = $vadExpectedSha256
    vadActualSha256 = $vadActualSha256
    vadIntegrityMatches = $vadIntegrityMatches
}
$output = Join-Path $repoRoot '.spike\results\apk-inspection.json'
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($output)) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding utf8
Write-Host "APK inspection report: $output"

if (-not $hasRequiredAbi -or
    -not $hasFlutterNotices -or
    -not $vadIntegrityMatches -or
    $duplicates.Count -gt 0 -or
    $missingBundledAssets.Count -gt 0 -or
    $unexpectedModelEntries.Count -gt 0) {
    throw 'APK model asset or native library inspection failed.'
}
