param(
    [string]$DeviceId = '3f842cd0',
    [string]$ModelRoot,
    [string]$SampleWave,
    [int]$RecordingSeconds = 30,
    [string]$AndroidSdkRoot,
    [ValidateSet('all', 'paraformer', 'qwen')]
    [string]$ModelFilter = 'all'
)

$ErrorActionPreference = 'Stop'

function Read-SharedText {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        $reader = [System.IO.StreamReader]::new($stream)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$spikeRoot = Join-Path $repoRoot '.spike'
if ([string]::IsNullOrWhiteSpace($ModelRoot)) {
    $ModelRoot = Join-Path $spikeRoot 'models'
}
if ([string]::IsNullOrWhiteSpace($SampleWave)) {
    $SampleWave = Join-Path $spikeRoot 'samples\public-speech-5m.wav'
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    $AndroidSdkRoot = $env:ANDROID_SDK_ROOT
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    $AndroidSdkRoot = 'D:\AndroidSdk'
}

$ModelRoot = [System.IO.Path]::GetFullPath($ModelRoot)
$SampleWave = [System.IO.Path]::GetFullPath($SampleWave)
$adb = Join-Path $AndroidSdkRoot 'platform-tools\adb.exe'
$packageName = 'com.example.meetily_ai'
$modelIds = switch ($ModelFilter) {
    'paraformer' { @('sherpa-onnx-paraformer-zh-small-2024-03-09') }
    'qwen' { @('sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25') }
    default {
        @(
            'sherpa-onnx-paraformer-zh-small-2024-03-09',
            'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25'
        )
    }
}

if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
    throw "找不到 adb：$adb"
}
if (-not (Test-Path -LiteralPath $SampleWave -PathType Leaf)) {
    throw "找不到 5 分钟样本：$SampleWave"
}
foreach ($modelId in $modelIds) {
    $modelPath = Join-Path $ModelRoot $modelId
    if (-not (Test-Path -LiteralPath $modelPath -PathType Container)) {
        throw "找不到模型目录：$modelPath"
    }
}

$remoteTemp = $null
Push-Location $repoRoot
try {
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
        throw 'Debug APK 构建失败。'
    }

    $apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    & $adb -s $DeviceId install -r $apk
    if ($LASTEXITCODE -ne 0) {
        throw 'Debug APK 安装失败。'
    }

    $stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $remoteTemp = "/data/local/tmp/meetily-step01-$stamp"
    & $adb -s $DeviceId shell mkdir -p "$remoteTemp/models"
    foreach ($modelId in $modelIds) {
        & $adb -s $DeviceId push (Join-Path $ModelRoot $modelId) "$remoteTemp/models/"
        if ($LASTEXITCODE -ne 0) {
            throw "推送模型失败：$modelId"
        }
    }
    & $adb -s $DeviceId push $SampleWave "$remoteTemp/sample.wav"
    if ($LASTEXITCODE -ne 0) {
        throw '推送样本失败。'
    }

    $privateRoot = (& $adb -s $DeviceId shell "run-as $packageName pwd").Trim()
    if ([string]::IsNullOrWhiteSpace($privateRoot)) {
        throw '无法解析应用私有目录。'
    }
    & $adb -s $DeviceId shell "run-as $packageName sh -c 'rm -rf files/spike && mkdir -p files/spike/output && cp -R $remoteTemp/models files/spike/ && cp $remoteTemp/sample.wav files/spike/sample.wav'"
    if ($LASTEXITCODE -ne 0) {
        throw '复制模型和样本到应用私有目录失败。'
    }
    & $adb -s $DeviceId shell pm grant $packageName android.permission.RECORD_AUDIO

    $deviceModelRoot = "$privateRoot/files/spike/models"
    $deviceSample = "$privateRoot/files/spike/sample.wav"
    $deviceOutput = "$privateRoot/files/spike/output"
    $resultsRoot = Join-Path $spikeRoot 'results'
    New-Item -ItemType Directory -Force -Path $resultsRoot | Out-Null
    $stdoutLog = Join-Path $resultsRoot 'integration-test.stdout.log'
    $stderrLog = Join-Path $resultsRoot 'integration-test.stderr.log'
    $flutter = (Get-Command flutter).Source
    $arguments = @(
        'test',
        'integration_test/asr_spike_test.dart',
        '-d', $DeviceId,
        "--dart-define=MEETILY_SPIKE_MODEL_ROOT=$deviceModelRoot",
        "--dart-define=MEETILY_SPIKE_SAMPLE_WAV=$deviceSample",
        "--dart-define=MEETILY_SPIKE_OUTPUT_ROOT=$deviceOutput",
        "--dart-define=MEETILY_SPIKE_RECORDING_SECONDS=$RecordingSeconds",
        "--dart-define=MEETILY_SPIKE_MODEL_FILTER=$ModelFilter"
    )
    $process = Start-Process -FilePath $flutter -ArgumentList $arguments `
        -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

    $permissionGrantedAfterTestInstall = $false
    $grantDeadline = [DateTimeOffset]::UtcNow.AddMinutes(5)
    while (-not $process.HasExited -and -not $permissionGrantedAfterTestInstall) {
        if (Test-Path -LiteralPath $stdoutLog) {
            $currentStdout = Read-SharedText -Path $stdoutLog
            if ($currentStdout -match 'Installing .+app-debug\.apk') {
                & $adb -s $DeviceId shell pm grant $packageName android.permission.RECORD_AUDIO
                if ($LASTEXITCODE -ne 0) {
                    throw '测试 APK 安装后的录音权限授权失败。'
                }
                $permissionGrantedAfterTestInstall = $true
            }
        }
        if ([DateTimeOffset]::UtcNow -ge $grantDeadline) {
            throw '等待 Flutter 安装测试 APK 超时，无法授予录音权限。'
        }
        if (-not $permissionGrantedAfterTestInstall) {
            Start-Sleep -Milliseconds 500
            $process.Refresh()
        }
    }

    $process.WaitForExit()
    $stdout = Read-SharedText -Path $stdoutLog
    $reportPatterns = [ordered]@{
        'asr-results.json' = 'MEETILY_ASR_REPORT:(\{[^\r\n]+\})'
        'recording-continuity.json' = 'MEETILY_RECORDING_REPORT:(\{[^\r\n]+\})'
    }
    foreach ($entry in $reportPatterns.GetEnumerator()) {
        $match = [regex]::Match($stdout, $entry.Value)
        if ($match.Success) {
            [System.IO.File]::WriteAllText(
                (Join-Path $resultsRoot $entry.Key),
                $match.Groups[1].Value,
                [System.Text.UTF8Encoding]::new($false)
            )
        }
    }

    $temperature = (& $adb -s $DeviceId shell dumpsys battery | Select-String 'temperature').ToString().Trim()
    $device = [ordered]@{
        capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
        manufacturer = (& $adb -s $DeviceId shell getprop ro.product.manufacturer).Trim()
        model = (& $adb -s $DeviceId shell getprop ro.product.model).Trim()
        android = (& $adb -s $DeviceId shell getprop ro.build.version.release).Trim()
        api = (& $adb -s $DeviceId shell getprop ro.build.version.sdk).Trim()
        abi = (& $adb -s $DeviceId shell getprop ro.product.cpu.abi).Trim()
        batteryTemperatureAfterRun = $temperature
        peakRssSource = '每个 ASR 运行由 Dart ProcessInfo.currentRss 以 100ms 周期采样，见 asr-results.json'
    }
    $device | ConvertTo-Json -Depth 6 | Set-Content `
        -LiteralPath (Join-Path $resultsRoot 'device-metrics.json') -Encoding utf8
    if ($process.ExitCode -ne 0) {
        throw "真机集成测试失败，已尽量回收指标。查看 $stdoutLog 和 $stderrLog"
    }
    Write-Host "Step 01 原始结果：$resultsRoot"
} finally {
    if (
        -not [string]::IsNullOrWhiteSpace($remoteTemp) -and
        $remoteTemp.StartsWith('/data/local/tmp/meetily-step01-')
    ) {
        & $adb -s $DeviceId shell rm -rf -- $remoteTemp
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "未能清理设备临时目录：$remoteTemp"
        }
    }
    Pop-Location
}
