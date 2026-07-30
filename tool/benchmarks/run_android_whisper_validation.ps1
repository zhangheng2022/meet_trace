param(
    [Parameter(Mandatory)]
    [string]$DeviceId,
    [string]$ModelRoot,
    [string]$AndroidSdkRoot,
    [ValidateSet('all', 'base', 'small')]
    [string]$ModelFilter = 'all'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ModelRoot)) {
    $ModelRoot = Join-Path $repoRoot '.spike\models'
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    $AndroidSdkRoot = $env:ANDROID_SDK_ROOT
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    throw '请通过 -AndroidSdkRoot 或 ANDROID_SDK_ROOT 指定 Android SDK。'
}

$ModelRoot = [System.IO.Path]::GetFullPath($ModelRoot)
$adb = Join-Path $AndroidSdkRoot 'platform-tools\adb.exe'
$packageName = 'com.example.meettrace'
$smallModelId = 'whisper-cpp-small-q5_1-v1.9.1'
$smallModelDirectory = Join-Path $ModelRoot $smallModelId
$smallModelFile = Join-Path $smallModelDirectory 'ggml-small-q5_1.bin'
if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
    throw "找不到 adb：$adb"
}
if ($ModelFilter -ne 'base' -and
    -not (Test-Path -LiteralPath $smallModelFile -PathType Leaf)) {
    throw "找不到 Small 模型：$smallModelFile。请先运行 download_whisper_models.ps1。"
}

$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$remoteTemp = "/data/local/tmp/meettrace-whisper-$stamp"
$privateValidationRoot = 'files/whisper-validation'
$resultsRoot = Join-Path $repoRoot '.spike\results'
New-Item -ItemType Directory -Force -Path $resultsRoot | Out-Null

Push-Location $repoRoot
try {
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
        throw 'Debug APK 构建失败。'
    }
    & (Join-Path $PSScriptRoot 'inspect_debug_apk.ps1')

    $apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    & $adb -s $DeviceId install -r $apk
    if ($LASTEXITCODE -ne 0) {
        throw 'Debug APK 安装失败。'
    }

    if ($ModelFilter -ne 'small') {
        flutter test integration_test/whisper_base_standard_asr_engine_test.dart `
            -d $DeviceId 2>&1 |
            Tee-Object -FilePath (Join-Path $resultsRoot 'whisper-base.stdout.log')
        if ($LASTEXITCODE -ne 0) {
            throw 'Whisper Base 真机集成测试失败。'
        }
    }

    if ($ModelFilter -ne 'base') {
        & $adb -s $DeviceId shell mkdir -p $remoteTemp
        & $adb -s $DeviceId push $smallModelFile "$remoteTemp/ggml-small-q5_1.bin"
        if ($LASTEXITCODE -ne 0) {
            throw '推送 Small 模型失败。'
        }
        & $adb -s $DeviceId shell `
            "run-as $packageName sh -c 'rm -rf $privateValidationRoot && mkdir -p $privateValidationRoot && cp $remoteTemp/ggml-small-q5_1.bin $privateValidationRoot/'"
        if ($LASTEXITCODE -ne 0) {
            throw '复制 Small 模型到应用私有目录失败。'
        }
        $privateRoot = (& $adb -s $DeviceId shell "run-as $packageName pwd").Trim()
        if ([string]::IsNullOrWhiteSpace($privateRoot)) {
            throw '无法解析应用私有目录。'
        }
        $deviceSmallRoot = "$privateRoot/$privateValidationRoot"
        flutter test integration_test/whisper_small_advanced_asr_engine_test.dart `
            -d $DeviceId `
            "--dart-define=MEETTRACE_WHISPER_SMALL_MODEL_ROOT=$deviceSmallRoot" 2>&1 |
            Tee-Object -FilePath (Join-Path $resultsRoot 'whisper-small.stdout.log')
        if ($LASTEXITCODE -ne 0) {
            throw 'Whisper Small 真机集成测试失败。'
        }
    }

    Write-Host "Whisper 真机验证完成：$resultsRoot"
}
finally {
    & $adb -s $DeviceId shell rm -rf -- $remoteTemp
    & $adb -s $DeviceId shell `
        "run-as $packageName sh -c 'rm -rf $privateValidationRoot'" 2>$null
    Pop-Location
}
