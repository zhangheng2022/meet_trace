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
$unexpectedModels = $entries | Where-Object {
    $_ -match 'qwen3-asr|encoder\.int8\.onnx|decoder\.int8\.onnx|model\.int8\.onnx'
}

$report = [ordered]@{
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    apkPath = $ApkPath
    apkBytes = (Get-Item -LiteralPath $ApkPath).Length
    abis = @($abis)
    nativeLibraries = @($nativeLibraries)
    suspiciousDuplicateLibraries = @($duplicates | ForEach-Object { $_.Name })
    unexpectedModelEntries = @($unexpectedModels)
}
$output = Join-Path $repoRoot '.spike\results\apk-inspection.json'
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($output)) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding utf8
Write-Host "APK 检查结果：$output"
