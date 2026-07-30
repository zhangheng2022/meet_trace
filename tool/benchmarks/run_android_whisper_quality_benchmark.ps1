[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CorpusManifest,

    [string]$DeviceId,

    [string]$SmallModelPath = ".spike/models/whisper-cpp-small-q5_1-v1.9.1/ggml-small-q5_1.bin",

    [ValidateSet("baseline", "preview", "final")]
    [string[]]$Profiles = @("baseline", "preview", "final"),

    [ValidateRange(1, 32)]
    [int]$ThreadCount = 2,

    [string]$OutputDirectory = ".spike/results/whisper-quality/android-emulator"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$smallExpectedBytes = 190085487
$smallExpectedSha256 = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
$observationMarker = "MEETTRACE_WHISPER_QUALITY_OBSERVATION:"
$completeMarker = "MEETTRACE_WHISPER_QUALITY_COMPLETE:"
$remoteRoot = $null
$adb = $null
$resolvedDeviceId = $null

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
        throw "$Label 不是文件：$($resolved.Path)"
    }
    return $resolved.Path
}

function Resolve-AdbPath {
    $sdkCandidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    )
    $flutterConfig = & flutter config --list 2>$null
    foreach ($line in $flutterConfig) {
        if ($line -match "android-sdk:\s*(.+)$") {
            $sdkCandidates += $Matches[1].Trim()
        }
    }
    foreach ($sdk in $sdkCandidates) {
        if ([string]::IsNullOrWhiteSpace($sdk)) {
            continue
        }
        $candidate = Join-Path $sdk "platform-tools\adb.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }
    throw "找不到 adb；请配置 ANDROID_SDK_ROOT 或 flutter config --android-sdk。"
}

function Resolve-X64EmulatorDevice {
    param([string]$RequestedDeviceId)

    if (-not [string]::IsNullOrWhiteSpace($RequestedDeviceId)) {
        return $RequestedDeviceId
    }
    $devices = (& flutter devices --machine | Out-String) | ConvertFrom-Json
    $matches = @($devices | Where-Object {
        $_.targetPlatform -eq "android-x64" -and $_.emulator -eq $true
    })
    if ($matches.Count -ne 1) {
        throw "需要且只能有一个运行中的 Android x86_64 模拟器；当前为 $($matches.Count) 个。"
    }
    return $matches[0].id
}

function Assert-NativeSuccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action
    )

    if ($LASTEXITCODE -ne 0) {
        throw "$Action 失败，退出码：$LASTEXITCODE"
    }
}

function Get-RelativeOutputReference {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rootWithSeparator = $Root.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    $rootUri = New-Object System.Uri($rootWithSeparator)
    $pathUri = New-Object System.Uri($Path)
    return [System.Uri]::UnescapeDataString(
        $rootUri.MakeRelativeUri($pathUri).ToString()
    )
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$Depth = 12
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

if ($Profiles.Count -eq 0) {
    throw "Profiles 不能为空。"
}
$profileIds = @(
    @(
        foreach ($profile in $Profiles) {
            switch ($profile) {
                "baseline" { "baseline-fixed-greedy-v1" }
                "preview" { "preview-greedy-low-latency-v1" }
                "final" { "final-beam-quality-v1" }
            }
        }
    ) | Select-Object -Unique
)

$manifestPath = Resolve-ExistingFile -Path $CorpusManifest -Label "Corpus manifest"
$resolvedSmallModel = Resolve-ExistingFile -Path $SmallModelPath -Label "Whisper Small 模型"
$smallFile = Get-Item -LiteralPath $resolvedSmallModel
if ($smallFile.Length -ne $smallExpectedBytes) {
    throw "Whisper Small 模型字节数不匹配。"
}
$smallHash = (Get-FileHash -LiteralPath $resolvedSmallModel -Algorithm SHA256).Hash.ToLowerInvariant()
if ($smallHash -ne $smallExpectedSha256) {
    throw "Whisper Small 模型 SHA-256 不匹配。"
}

$outputRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repoRoot -ChildPath $OutputDirectory)
)
$spikeRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repoRoot -ChildPath ".spike")
)
$spikePrefix = $spikeRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith(
        $spikePrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "OutputDirectory 必须位于仓库已忽略的 .spike 目录内。"
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$transcriptRoot = Join-Path $outputRoot "transcripts"
[System.IO.Directory]::CreateDirectory($transcriptRoot) | Out-Null
$preparedCorpusPath = Join-Path $outputRoot "prepared-corpus.private.json"
$deviceManifestHostPath = Join-Path $outputRoot "device-run.private.json"
$rawLogPath = Join-Path $outputRoot "android-benchmark.private.log"
$rawObservationsPath = Join-Path $outputRoot "raw-observations.private.json"
$runEvidencePath = Join-Path $outputRoot "benchmark-run.json"

Push-Location $repoRoot
try {
    & dart run tool/benchmarks/prepare_whisper_quality_corpus.dart `
        --manifest $manifestPath `
        --repository-root $repoRoot `
        --output $preparedCorpusPath
    Assert-NativeSuccess -Action "Corpus manifest 校验"
    $preparedCorpus = Get-Content -LiteralPath $preparedCorpusPath -Raw -Encoding UTF8 |
        ConvertFrom-Json

    $adb = Resolve-AdbPath
    $resolvedDeviceId = Resolve-X64EmulatorDevice -RequestedDeviceId $DeviceId
    $state = (& $adb -s $resolvedDeviceId get-state).Trim()
    if ($state -ne "device") {
        throw "Android 模拟器未就绪：$resolvedDeviceId ($state)"
    }
    $emulatorFlag = (& $adb -s $resolvedDeviceId shell getprop ro.kernel.qemu).Trim()
    $abi = (& $adb -s $resolvedDeviceId shell getprop ro.product.cpu.abi).Trim()
    if ($emulatorFlag -ne "1" -or $abi -ne "x86_64") {
        throw "当前目标必须是 Android x86_64 模拟器；实际 ABI：$abi。"
    }
    $apiLevel = [int]((& $adb -s $resolvedDeviceId shell getprop ro.build.version.sdk).Trim())
    $deviceLabel = "android-emulator-x86_64-api-$apiLevel"

    $remoteRoot = "/data/local/tmp/meettrace-quality-$([Guid]::NewGuid().ToString('N'))"
    if ($remoteRoot -notmatch "^/data/local/tmp/meettrace-quality-[0-9a-f]{32}$") {
        throw "临时设备目录不符合安全边界。"
    }
    & $adb -s $resolvedDeviceId shell mkdir -p $remoteRoot | Out-Null
    Assert-NativeSuccess -Action "创建设备临时目录"

    $deviceSamples = @()
    for ($index = 0; $index -lt $preparedCorpus.samples.Count; $index++) {
        $sample = $preparedCorpus.samples[$index]
        $remotePath = "$remoteRoot/sample-$($index.ToString('D3')).pcm"
        & $adb -s $resolvedDeviceId push $sample.sourcePath $remotePath *> $null
        Assert-NativeSuccess -Action "推送去敏 PCM sample-$($index.ToString('D3'))"
        $deviceSamples += [ordered]@{
            id = $sample.id
            path = $remotePath
            sha256 = $sample.sha256
            bytes = [long]$sample.bytes
            durationMs = [double]$sample.durationMs
            expectedKeyFacts = @($sample.expectedKeyFacts)
        }
    }

    $remoteSmallModel = "$remoteRoot/ggml-small-q5_1.bin"
    & $adb -s $resolvedDeviceId push $resolvedSmallModel $remoteSmallModel *> $null
    Assert-NativeSuccess -Action "推送 Whisper Small 模型"

    $deviceManifest = [ordered]@{
        schemaVersion = 1
        corpusId = $preparedCorpus.id
        deviceId = $deviceLabel
        threadCount = $ThreadCount
        samples = $deviceSamples
        models = @(
            [ordered]@{
                modelId = "whisper-cpp-base-q5_1-v1.9.1"
                modelVersion = "v1.9.1-q5_1"
                source = "bundledBase"
                path = $null
                profileIds = $profileIds
            },
            [ordered]@{
                modelId = "whisper-cpp-small-q5_1-v1.9.1"
                modelVersion = "v1.9.1-q5_1"
                source = "deviceFile"
                path = $remoteSmallModel
                profileIds = $profileIds
            }
        )
    }
    Write-JsonFile -Value $deviceManifest -Path $deviceManifestHostPath
    $remoteDeviceManifest = "$remoteRoot/device-run.json"
    & $adb -s $resolvedDeviceId push $deviceManifestHostPath $remoteDeviceManifest *> $null
    Assert-NativeSuccess -Action "推送设备评测清单"

    $flutterArguments = @(
        "test",
        "integration_test/android_whisper_quality_benchmark_test.dart",
        "-d",
        $resolvedDeviceId,
        "--dart-define=MEETTRACE_WHISPER_QUALITY_DEVICE_MANIFEST=$remoteDeviceManifest"
    )
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $flutterOutput = & flutter @flutterArguments 2>&1
        $flutterExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $flutterOutput | ForEach-Object { "$_" } |
        Set-Content -LiteralPath $rawLogPath -Encoding UTF8
    if ($flutterExitCode -ne 0) {
        throw "Android Whisper 质量评测失败；私有日志：$rawLogPath"
    }

    $observationLines = @(
        Get-Content -LiteralPath $rawLogPath -Encoding UTF8 |
            Where-Object { $_.StartsWith($observationMarker) }
    )
    $completeLine = Get-Content -LiteralPath $rawLogPath -Encoding UTF8 |
        Where-Object { $_.StartsWith($completeMarker) } |
        Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($completeLine)) {
        throw "Android 评测完成标记缺失；私有日志：$rawLogPath"
    }
    $completion = $completeLine.Substring($completeMarker.Length) | ConvertFrom-Json
    if ($observationLines.Count -ne [int]$completion.observationCount) {
        throw "原始观测数量与完成标记不一致。"
    }

    $observations = @()
    for ($index = 0; $index -lt $observationLines.Count; $index++) {
        $payload = $observationLines[$index].Substring($observationMarker.Length) |
            ConvertFrom-Json
        $transcriptPath = Join-Path $transcriptRoot "transcript-$($index.ToString('D4')).json"
        Write-JsonFile -Value $payload.transcript -Path $transcriptPath
        $observation = [ordered]@{}
        foreach ($property in $payload.observation.PSObject.Properties) {
            $observation[$property.Name] = $property.Value
        }
        $observation["transcriptRef"] = Get-RelativeOutputReference `
            -Root $outputRoot `
            -Path $transcriptPath
        $observations += $observation
    }

    $rawObservations = [ordered]@{
        schemaVersion = 2
        execution = [ordered]@{
            platform = "android-emulator"
            deviceId = $deviceLabel
            abi = $abi
            apiLevel = $apiLevel
            threadCount = $ThreadCount
            windowDurationMs = 2000
            energyStatus = "not_collected"
            thermalStatus = "not_collected"
        }
        observations = $observations
    }
    Write-JsonFile `
        -Value $rawObservations `
        -Path $rawObservationsPath `
        -Depth 20

    & powershell -NoProfile -ExecutionPolicy Bypass `
        -File tool/benchmarks/run_whisper_quality_matrix.ps1 `
        -CorpusManifest $manifestPath `
        -RawObservations $rawObservationsPath `
        -OutputDirectory $outputRoot
    Assert-NativeSuccess -Action "Whisper 质量指标聚合"

    $runEvidence = [ordered]@{
        schemaVersion = 1
        status = "passed"
        capturedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
        platform = "android-emulator"
        deviceId = $deviceLabel
        abi = $abi
        apiLevel = $apiLevel
        corpusId = $preparedCorpus.id
        sampleCount = [int]$completion.sampleCount
        observationCount = [int]$completion.observationCount
        profileIds = $profileIds
        modelIds = @(
            "whisper-cpp-base-q5_1-v1.9.1",
            "whisper-cpp-small-q5_1-v1.9.1"
        )
        windowDurationMs = 2000
        energyStatus = "not_collected"
        thermalStatus = "not_collected"
        privateArtifacts = @(
            "prepared-corpus.private.json",
            "device-run.private.json",
            "android-benchmark.private.log",
            "raw-observations.private.json",
            "transcripts/"
        )
        reports = @("quality-report.json", "quality-report.csv")
    }
    Write-JsonFile -Value $runEvidence -Path $runEvidencePath

    Write-Output "Android Whisper 质量评测完成：$runEvidencePath"
    Write-Output "质量报告：$(Join-Path $outputRoot 'quality-report.json')"
}
finally {
    if ($null -ne $adb -and
        $null -ne $resolvedDeviceId -and
        $null -ne $remoteRoot -and
        $remoteRoot -match "^/data/local/tmp/meettrace-quality-[0-9a-f]{32}$") {
        & $adb -s $resolvedDeviceId shell rm -rf -- $remoteRoot *> $null
    }
    Pop-Location
}
