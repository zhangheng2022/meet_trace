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
    throw "找不到 APK：$ApkPath"
}

$entries = & tar -tf $ApkPath
if ($LASTEXITCODE -ne 0) {
    throw '无法读取 APK ZIP 内容。'
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
    'assets/flutter_assets/assets/models/manifest.json',
    'assets/flutter_assets/assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/model.int8.onnx',
    'assets/flutter_assets/assets/models/sherpa-onnx-paraformer-zh-small-2024-03-09/tokens.txt'
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
}
$output = Join-Path $repoRoot '.spike\results\apk-inspection.json'
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($output)) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding utf8
Write-Host "APK 检查结果：$output"

if (-not $hasRequiredAbi -or
    -not $hasFlutterNotices -or
    $duplicates.Count -gt 0 -or
    $missingBundledAssets.Count -gt 0 -or
    $unexpectedModelEntries.Count -gt 0) {
    throw 'APK 模型资产或原生库检查失败，请查看检查报告。'
}
