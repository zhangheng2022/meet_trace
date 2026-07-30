[CmdletBinding()]
param(
    [string]$DeviceId,

    [string]$SmallModelPath = ".spike/models/whisper-cpp-small-q5_1-v1.9.1/ggml-small-q5_1.bin",

    [ValidateSet("base", "small")]
    [string[]]$Models = @("base"),

    [ValidateSet("baseline", "preview", "final")]
    [string[]]$Profiles = @("baseline"),

    [ValidateSet("fixed-window", "vad-segmented", "vad-recall")]
    [string[]]$Pipelines = @("fixed-window", "vad-segmented"),

    [ValidateSet("train", "validation", "test")]
    [string]$Split = "validation",

    [ValidateRange(0, 100000)]
    [int]$Offset = 0,

    [ValidateRange(20, 100)]
    [int]$RowPoolSize = 100,

    [ValidateRange(20, 100)]
    [int]$SampleCount = 20,

    [ValidateRange(0.1, 60)]
    [double]$MinimumDurationSeconds = 1,

    [ValidateRange(0.1, 60)]
    [double]$MaximumDurationSeconds = 3,

    [string]$CorpusDirectory = ".spike/corpora/ascend-public-regression-v1",

    [string]$OutputDirectory = ".spike/results/whisper-quality/ascend-public-regression-v1"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ($SampleCount -gt $RowPoolSize) {
    throw "SampleCount must not exceed RowPoolSize."
}
if ($MaximumDurationSeconds -lt $MinimumDurationSeconds) {
    throw "MaximumDurationSeconds must not be less than MinimumDurationSeconds."
}

Push-Location $repoRoot
$previousEnvironment = @{}
try {
    & dart run tool/benchmarks/fetch_ascend_public_regression.dart `
        --repository-root $repoRoot `
        --output-directory $CorpusDirectory `
        --split $Split `
        --offset $Offset `
        --row-pool-size $RowPoolSize `
        --sample-count $SampleCount `
        --minimum-duration-seconds $MinimumDurationSeconds `
        --maximum-duration-seconds $MaximumDurationSeconds
    if ($LASTEXITCODE -ne 0) {
        throw "ASCEND corpus preparation failed with exit code $LASTEXITCODE."
    }

    $corpusRoot = if ([System.IO.Path]::IsPathRooted($CorpusDirectory)) {
        [System.IO.Path]::GetFullPath($CorpusDirectory)
    }
    else {
        [System.IO.Path]::GetFullPath(
            (Join-Path -Path $repoRoot -ChildPath $CorpusDirectory)
        )
    }
    $manifestPath = Join-Path $corpusRoot "manifest.private.json"
    $environmentPath = Join-Path $corpusRoot "environment.private.json"
    $environment = Get-Content `
        -LiteralPath $environmentPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    foreach ($property in $environment.PSObject.Properties) {
        if ($property.Name -notmatch "^[A-Z][A-Z0-9_]*$") {
            throw "Generated environment key is invalid."
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

    $benchmarkArguments = @{
        CorpusManifest = $manifestPath
        SmallModelPath = $SmallModelPath
        Models = $Models
        Profiles = $Profiles
        Pipelines = $Pipelines
        RequiredEvidenceClass = "public-regression"
        OutputDirectory = $OutputDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $benchmarkArguments["DeviceId"] = $DeviceId
    }
    & (Join-Path $repoRoot "tool\benchmarks\run_android_whisper_quality_benchmark.ps1") `
        @benchmarkArguments
    if ($LASTEXITCODE -ne 0) {
        throw "ASCEND Android regression failed with exit code $LASTEXITCODE."
    }
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
