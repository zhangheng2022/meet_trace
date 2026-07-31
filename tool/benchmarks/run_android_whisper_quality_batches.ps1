[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CorpusManifest,

    [Parameter(Mandatory = $true)]
    [string]$EnvironmentFile,

    [string]$DeviceId,

    [string]$SmallModelPath = ".spike/models/whisper-cpp-small-q5_1-v1.9.1/ggml-small-q5_1.bin",

    [ValidateSet("base", "small")]
    [string[]]$Models = @("base", "small"),

    [ValidateSet("baseline", "preview", "final")]
    [string[]]$Profiles = @("baseline", "preview", "final"),

    [ValidateSet("fixed-window", "vad-segmented", "vad-recall")]
    [string[]]$Pipelines = @("fixed-window", "vad-segmented", "vad-recall"),

    [ValidateSet("product-meeting", "public-regression", "synthetic-smoke")]
    [string]$RequiredEvidenceClass = "product-meeting",

    [ValidateRange(1, 32)]
    [int]$ThreadCount = 2,

    [string]$OutputDirectory = ".spike/results/whisper-quality/android-emulator-batches",

    [string]$ReleaseInputPath = "docs/quality/evidence/android-emulator/phase-0-4-release-input.json",

    [string]$ReleaseReportPath = "docs/quality/evidence/android-emulator/phase-0-4-release-report.json",

    [string]$QualityEvidenceOutput = "docs/quality/evidence/product-meeting/quality-report.json",

    [string]$QualityEvidenceRef = "docs/quality/evidence/product-meeting/quality-report.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
        throw "$Label is not a file: $($resolved.Path)"
    }
    return $resolved.Path
}

function Assert-NativeSuccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action
    )

    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed with exit code $LASTEXITCODE"
    }
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
    throw "adb not found; configure ANDROID_SDK_ROOT or flutter config --android-sdk."
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
        throw "Exactly one running Android x86_64 emulator is required; found $($matches.Count)."
    }
    return $matches[0].id
}

function Invoke-AdbChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdbPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Action
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $AdbPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) {
        $detail = ($output | ForEach-Object { "$_" }) -join [Environment]::NewLine
        throw "$Action failed with exit code $exitCode. $detail"
    }
    return @($output | ForEach-Object { "$_" })
}

function Get-TextSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return -join (
            $algorithm.ComputeHash($bytes) |
                ForEach-Object { $_.ToString("x2") }
        )
    }
    finally {
        $algorithm.Dispose()
    }
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

function Get-ModelId {
    param([string]$Model)

    if ($Model -eq "base") {
        return "whisper-cpp-base-q5_1-v1.9.1"
    }
    return "whisper-cpp-small-q5_1-v1.9.1"
}

function Get-ProfileId {
    param([string]$Profile)

    switch ($Profile) {
        "baseline" { return "baseline-fixed-greedy-v1" }
        "preview" { return "preview-greedy-low-latency-v1" }
        "final" { return "final-beam-quality-v1" }
    }
}

function Get-PipelineId {
    param([string]$Pipeline)

    switch ($Pipeline) {
        "fixed-window" { return "fixed-window-v1" }
        "vad-segmented" { return "vad-segmented-v1" }
        "vad-recall" { return "vad-recall-035-v1" }
    }
}

function Test-CompletedBatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BatchRoot,

        [Parameter(Mandatory = $true)]
        [string]$ManifestSha256,

        [Parameter(Mandatory = $true)]
        [string]$ModelId,

        [Parameter(Mandatory = $true)]
        [string]$ProfileId,

        [Parameter(Mandatory = $true)]
        [string]$PipelineId,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedDeviceLabel,

        [Parameter(Mandatory = $true)]
        [int]$ExpectedThreadCount
    )

    $evidencePath = Join-Path $BatchRoot "benchmark-run.json"
    $rawPath = Join-Path $BatchRoot "raw-observations.private.json"
    $reportPath = Join-Path $BatchRoot "quality-report.json"
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $rawPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        return $false
    }
    try {
        $evidence = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 |
            ConvertFrom-Json
        $raw = Get-Content -LiteralPath $rawPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
        if ($evidence.schemaVersion -ne 1 -or
            $evidence.status -ne "passed" -or
            $evidence.corpusManifestSha256 -ne $ManifestSha256 -or
            (@($evidence.modelIds) -join "`0") -ne $ModelId -or
            (@($evidence.profileIds) -join "`0") -ne $ProfileId -or
            (@($evidence.pipelineIds) -join "`0") -ne $PipelineId -or
            $evidence.deviceId -ne $ExpectedDeviceLabel -or
            $raw.schemaVersion -ne 4 -or
            $raw.execution.corpusManifestSha256 -ne $ManifestSha256 -or
            $raw.execution.deviceId -ne $ExpectedDeviceLabel -or
            [int]$raw.execution.threadCount -ne $ExpectedThreadCount -or
            $report.schemaVersion -ne 4 -or
            $report.status -ne "passed" -or
            $report.corpusManifestSha256 -ne $ManifestSha256 -or
            $report.execution.deviceId -ne $ExpectedDeviceLabel -or
            [int]$evidence.sampleCount -le 0 -or
            [int]$evidence.observationCount -ne [int]$evidence.sampleCount -or
            @($raw.observations).Count -ne [int]$evidence.sampleCount) {
            return $false
        }
        $observedSampleIds = @{}
        $batchPrefix = [System.IO.Path]::GetFullPath($BatchRoot).TrimEnd("\", "/") +
            [System.IO.Path]::DirectorySeparatorChar
        foreach ($observation in @($raw.observations)) {
            if ([string]::IsNullOrWhiteSpace([string]$observation.sampleId) -or
                $observedSampleIds.ContainsKey([string]$observation.sampleId) -or
                $observation.modelId -ne $ModelId -or
                $observation.profileId -ne $ProfileId -or
                $observation.pipelineId -ne $PipelineId -or
                [System.IO.Path]::IsPathRooted([string]$observation.transcriptRef) -or
                "$($observation.transcriptSha256)" -notmatch "^[0-9a-f]{64}$") {
                return $false
            }
            $transcriptPath = [System.IO.Path]::GetFullPath(
                (Join-Path $BatchRoot ([string]$observation.transcriptRef))
            )
            if (-not $transcriptPath.StartsWith(
                    $batchPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -or
                -not (Test-Path -LiteralPath $transcriptPath -PathType Leaf)) {
                return $false
            }
            $actualTranscriptSha256 = (
                Get-FileHash -LiteralPath $transcriptPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
            if ($actualTranscriptSha256 -ne "$($observation.transcriptSha256)") {
                return $false
            }
            $observedSampleIds[[string]$observation.sampleId] = $true
        }
        if ($observedSampleIds.Count -ne [int]$evidence.sampleCount -or
            @($report.summaries).Count -ne 1 -or
            $report.summaries[0].modelId -ne $ModelId -or
            $report.summaries[0].profileId -ne $ProfileId -or
            $report.summaries[0].pipelineId -ne $PipelineId -or
            [int]$report.summaries[0].sampleCount -ne [int]$evidence.sampleCount) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

function Publish-CompletedBatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AttemptRoot,

        [Parameter(Mandatory = $true)]
        [string]$BatchRoot,

        [Parameter(Mandatory = $true)]
        [string]$OutputRoot
    )

    $outputPrefix = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd("\", "/") +
        [System.IO.Path]::DirectorySeparatorChar
    $attemptFull = [System.IO.Path]::GetFullPath($AttemptRoot)
    $batchFull = [System.IO.Path]::GetFullPath($BatchRoot)
    if (-not $attemptFull.StartsWith(
            $outputPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not $batchFull.StartsWith(
            $outputPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path -LiteralPath $attemptFull -PathType Container)) {
        throw "Batch promotion paths must remain inside OutputDirectory."
    }

    $backupRoot = Join-Path $OutputRoot (
        "superseded\$([System.IO.Path]::GetFileName($BatchRoot))-" +
        [Guid]::NewGuid().ToString("N")
    )
    $backupFull = [System.IO.Path]::GetFullPath($backupRoot)
    if (-not $backupFull.StartsWith(
            $outputPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Superseded batch path must remain inside OutputDirectory."
    }
    [System.IO.Directory]::CreateDirectory(
        [System.IO.Path]::GetDirectoryName($backupFull)
    ) | Out-Null
    [System.IO.Directory]::CreateDirectory(
        [System.IO.Path]::GetDirectoryName($batchFull)
    ) | Out-Null
    $hadExistingBatch = Test-Path -LiteralPath $batchFull -PathType Container
    try {
        if ($hadExistingBatch) {
            Move-Item -LiteralPath $batchFull -Destination $backupFull
        }
        Move-Item -LiteralPath $attemptFull -Destination $batchFull
    }
    catch {
        if (-not (Test-Path -LiteralPath $batchFull) -and
            (Test-Path -LiteralPath $backupFull -PathType Container)) {
            Move-Item -LiteralPath $backupFull -Destination $batchFull
        }
        throw
    }
    if (Test-Path -LiteralPath $backupFull -PathType Container) {
        Write-Output "Preserved superseded batch for recovery: $backupFull"
    }
}

if ($Models.Count -eq 0 -or
    $Profiles.Count -eq 0 -or
    $Pipelines.Count -eq 0) {
    throw "Models, Profiles and Pipelines must not be empty."
}
if (@($Models | Select-Object -Unique).Count -ne $Models.Count -or
    @($Profiles | Select-Object -Unique).Count -ne $Profiles.Count -or
    @($Pipelines | Select-Object -Unique).Count -ne $Pipelines.Count) {
    throw "Models, Profiles and Pipelines must not contain duplicates."
}

$manifestPath = Resolve-ExistingFile -Path $CorpusManifest -Label "Corpus manifest"
$environmentPath = Resolve-ExistingFile -Path $EnvironmentFile -Label "Environment file"
$manifestSha256 = (
    Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
}
else {
    [System.IO.Path]::GetFullPath(
        (Join-Path -Path $repoRoot -ChildPath $OutputDirectory)
    )
}
$spikeRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repoRoot -ChildPath ".spike")
)
$spikePrefix = $spikeRoot.TrimEnd("\", "/") +
    [System.IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith(
        $spikePrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "OutputDirectory must be inside the ignored repository .spike directory."
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$canonicalSpikeRoot = (Resolve-Path -LiteralPath $spikeRoot).Path
$canonicalOutputRoot = (Resolve-Path -LiteralPath $outputRoot).Path
$canonicalSpikePrefix = $canonicalSpikeRoot.TrimEnd("\", "/") +
    [System.IO.Path]::DirectorySeparatorChar
if (-not $canonicalOutputRoot.StartsWith(
        $canonicalSpikePrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "OutputDirectory resolves outside the ignored repository .spike directory."
}

$adb = Resolve-AdbPath
$resolvedDeviceId = Resolve-X64EmulatorDevice -RequestedDeviceId $DeviceId
$emulatorFlag = (
    Invoke-AdbChecked `
        -AdbPath $adb `
        -Arguments @("-s", $resolvedDeviceId, "shell", "getprop", "ro.kernel.qemu") `
        -Action "Read Android emulator flag" |
        Out-String
).Trim()
$abi = (
    Invoke-AdbChecked `
        -AdbPath $adb `
        -Arguments @("-s", $resolvedDeviceId, "shell", "getprop", "ro.product.cpu.abi") `
        -Action "Read Android device ABI" |
        Out-String
).Trim()
if ($emulatorFlag -ne "1" -or $abi -ne "x86_64") {
    throw "Target must be an Android x86_64 emulator; actual ABI: $abi."
}
$apiLevel = [int]((
        Invoke-AdbChecked `
            -AdbPath $adb `
            -Arguments @("-s", $resolvedDeviceId, "shell", "getprop", "ro.build.version.sdk") `
            -Action "Read Android API level" |
            Out-String
    ).Trim())
$deviceSerialFingerprint = (
    Get-TextSha256 -Value $resolvedDeviceId
).Substring(0, 12)
$expectedDeviceLabel = "android-emulator-x86_64-api-$apiLevel-$deviceSerialFingerprint"

$environment = Get-Content -LiteralPath $environmentPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$previousEnvironment = @{}
$batchRecords = @()
$rawPaths = @()

Push-Location $repoRoot
try {
    foreach ($property in $environment.PSObject.Properties) {
        if ($property.Name -notmatch "^[A-Z][A-Z0-9_]*$" -or
            [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            throw "Environment file contains an invalid key or path."
        }
        $previousEnvironment[$property.Name] = [Environment]::GetEnvironmentVariable(
            $property.Name,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            $property.Name,
            [string]$property.Value,
            [EnvironmentVariableTarget]::Process
        )
    }

    $totalCount = $Models.Count * $Profiles.Count * $Pipelines.Count
    $completedCount = 0
    foreach ($model in $Models) {
        foreach ($profile in $Profiles) {
            foreach ($pipeline in $Pipelines) {
                $modelId = Get-ModelId -Model $model
                $profileId = Get-ProfileId -Profile $profile
                $pipelineId = Get-PipelineId -Pipeline $pipeline
                $batchName = "$model-$profile-$pipeline"
                $batchRoot = Join-Path $outputRoot "batches\$batchName"
                $rawPath = Join-Path $batchRoot "raw-observations.private.json"
                $complete = Test-CompletedBatch `
                    -BatchRoot $batchRoot `
                    -ManifestSha256 $manifestSha256 `
                    -ModelId $modelId `
                    -ProfileId $profileId `
                    -PipelineId $pipelineId `
                    -ExpectedDeviceLabel $expectedDeviceLabel `
                    -ExpectedThreadCount $ThreadCount
                if ($complete) {
                    Write-Output "Reuse completed batch [$($completedCount + 1)/$totalCount]: $batchName"
                }
                else {
                    Write-Output "Run batch [$($completedCount + 1)/$totalCount]: $batchName"
                    $attemptRoot = Join-Path $outputRoot (
                        "attempts\$batchName-$([Guid]::NewGuid().ToString('N'))"
                    )
                    try {
                        $benchmarkArguments = @{
                            CorpusManifest = $manifestPath
                            SmallModelPath = $SmallModelPath
                            Models = @($model)
                            Profiles = @($profile)
                            Pipelines = @($pipeline)
                            RequiredEvidenceClass = $RequiredEvidenceClass
                            ThreadCount = $ThreadCount
                            OutputDirectory = $attemptRoot
                            SkipReleaseEvaluation = $true
                        }
                        $benchmarkArguments["DeviceId"] = $resolvedDeviceId
                        & (Join-Path $repoRoot "tool\benchmarks\run_android_whisper_quality_benchmark.ps1") `
                            @benchmarkArguments
                        if (-not (Test-CompletedBatch `
                                -BatchRoot $attemptRoot `
                                -ManifestSha256 $manifestSha256 `
                                -ModelId $modelId `
                                -ProfileId $profileId `
                                -PipelineId $pipelineId `
                                -ExpectedDeviceLabel $expectedDeviceLabel `
                                -ExpectedThreadCount $ThreadCount)) {
                            throw "Batch did not produce valid completion evidence: $batchName"
                        }
                        Publish-CompletedBatch `
                            -AttemptRoot $attemptRoot `
                            -BatchRoot $batchRoot `
                            -OutputRoot $outputRoot
                    }
                    catch {
                        $batchError = $_
                        $attemptFull = [System.IO.Path]::GetFullPath($attemptRoot)
                        $attemptPrefix = $outputRoot.TrimEnd("\", "/") +
                            [System.IO.Path]::DirectorySeparatorChar
                        if (-not $attemptFull.StartsWith(
                                $attemptPrefix,
                                [System.StringComparison]::OrdinalIgnoreCase
                            )) {
                            throw $batchError
                        }
                        $failureLog = Join-Path $attemptRoot "android-benchmark.private.log"
                        $failedBatch = [ordered]@{
                            id = $batchName
                            modelId = $modelId
                            profileId = $profileId
                            pipelineId = $pipelineId
                            status = "failed"
                            attemptRef = $attemptFull.Substring(
                                $attemptPrefix.Length
                            ).Replace("\", "/")
                            privateLogRef = $null
                            privateLogSha256 = $null
                        }
                        if (Test-Path -LiteralPath $failureLog -PathType Leaf) {
                            $failureLogFull = [System.IO.Path]::GetFullPath($failureLog)
                            $failedBatch.privateLogRef = $failureLogFull.Substring(
                                $attemptPrefix.Length
                            ).Replace("\", "/")
                            $failedBatch.privateLogSha256 = (
                                Get-FileHash -LiteralPath $failureLog -Algorithm SHA256
                            ).Hash.ToLowerInvariant()
                        }
                        try {
                            Write-JsonFile -Value ([ordered]@{
                                    schemaVersion = 1
                                    status = "failed"
                                    failedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
                                    corpusManifestSha256 = $manifestSha256
                                    deviceId = $expectedDeviceLabel
                                    abi = $abi
                                    apiLevel = $apiLevel
                                    threadCount = $ThreadCount
                                    completedBatchCount = $completedCount
                                    expectedBatchCount = $totalCount
                                    batches = $batchRecords
                                    failedBatch = $failedBatch
                                }) -Path (Join-Path $outputRoot "batch-progress.json") -Depth 16
                        }
                        catch {
                            Write-Warning "Unable to persist failed batch progress: $($_.Exception.GetType().FullName)"
                        }
                        throw $batchError
                    }
                }
                $rawPaths += $rawPath
                $batchRecords += [ordered]@{
                    id = $batchName
                    modelId = $modelId
                    profileId = $profileId
                    pipelineId = $pipelineId
                    rawObservationsSha256 = (
                        Get-FileHash -LiteralPath $rawPath -Algorithm SHA256
                    ).Hash.ToLowerInvariant()
                    status = "passed"
                }
                $completedCount++
                Write-JsonFile -Value ([ordered]@{
                        schemaVersion = 1
                        status = "running"
                        corpusManifestSha256 = $manifestSha256
                        deviceId = $expectedDeviceLabel
                        abi = $abi
                        apiLevel = $apiLevel
                        threadCount = $ThreadCount
                        completedBatchCount = $completedCount
                        expectedBatchCount = $totalCount
                        batches = $batchRecords
                    }) -Path (Join-Path $outputRoot "batch-progress.json") -Depth 16
            }
        }
    }

    $mergedRawPath = Join-Path $outputRoot "raw-observations.private.json"
    $mergeArguments = @(
        "run",
        "tool/benchmarks/merge_whisper_quality_observations.dart",
        "--manifest",
        $manifestPath,
        "--repository-root",
        $repoRoot,
        "--output",
        $mergedRawPath,
        "--overwrite"
    )
    foreach ($rawPath in $rawPaths) {
        $mergeArguments += @("--input", $rawPath)
    }
    & dart @mergeArguments
    Assert-NativeSuccess -Action "Merge completed Whisper quality batches"

    & powershell -NoProfile -ExecutionPolicy Bypass `
        -File tool/benchmarks/run_whisper_quality_matrix.ps1 `
        -CorpusManifest $manifestPath `
        -RawObservations $mergedRawPath `
        -RequiredEvidenceClass $RequiredEvidenceClass `
        -OutputDirectory $outputRoot
    Assert-NativeSuccess -Action "Aggregate merged Whisper quality matrix"

    $runEvidence = [ordered]@{
        schemaVersion = 1
        status = "passed"
        capturedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
        kind = "resumable-quality-matrix"
        corpusManifestSha256 = $manifestSha256
        deviceId = $expectedDeviceLabel
        abi = $abi
        apiLevel = $apiLevel
        threadCount = $ThreadCount
        batchCount = $batchRecords.Count
        observationCount = (
            Get-Content -LiteralPath $mergedRawPath -Raw -Encoding UTF8 |
                ConvertFrom-Json
        ).observations.Count
        mergedRawObservationsSha256 = (
            Get-FileHash -LiteralPath $mergedRawPath -Algorithm SHA256
        ).Hash.ToLowerInvariant()
        batches = $batchRecords
        reports = @("quality-report.json", "quality-report.csv")
    }
    Write-JsonFile -Value $runEvidence -Path (Join-Path $outputRoot "batch-run.json") -Depth 16
    Write-JsonFile -Value ([ordered]@{
            schemaVersion = 1
            status = "passed"
            corpusManifestSha256 = $manifestSha256
            deviceId = $expectedDeviceLabel
            abi = $abi
            apiLevel = $apiLevel
            threadCount = $ThreadCount
            completedBatchCount = $batchRecords.Count
            expectedBatchCount = $batchRecords.Count
            batches = $batchRecords
        }) -Path (Join-Path $outputRoot "batch-progress.json") -Depth 16

    if ($RequiredEvidenceClass -eq "product-meeting") {
        & dart run tool/benchmarks/build_phase_0_4_quality_input.dart `
            --template $ReleaseInputPath `
            --quality-report (Join-Path $outputRoot "quality-report.json") `
            --quality-evidence-output $QualityEvidenceOutput `
            --quality-evidence-ref $QualityEvidenceRef `
            --output $ReleaseInputPath
        Assert-NativeSuccess -Action "Build phase 0-4 quality input"

        & dart run tool/benchmarks/evaluate_alpha_release.dart `
            --input $ReleaseInputPath `
            --output $ReleaseReportPath `
            --repository-root $repoRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Phase 0-4 quality gates did not reach Go; inspect $ReleaseReportPath"
        }
    }

    Write-Output "Resumable Android Whisper matrix completed: $(Join-Path $outputRoot 'batch-run.json')"
    Write-Output "Quality report: $(Join-Path $outputRoot 'quality-report.json')"
}
finally {
    foreach ($entry in $previousEnvironment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable(
            $entry.Key,
            $entry.Value,
            [EnvironmentVariableTarget]::Process
        )
    }
    Pop-Location
}
