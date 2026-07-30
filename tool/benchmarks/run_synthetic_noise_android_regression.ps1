[CmdletBinding()]
param(
    [string]$DeviceId,

    [string]$SmallModelPath = ".spike/models/whisper-cpp-small-q5_1-v1.9.1/ggml-small-q5_1.bin",

    [ValidateSet("base", "small")]
    [string[]]$Models = @("base"),

    [ValidateSet("baseline", "preview", "final")]
    [string[]]$Profiles = @("baseline"),

    [ValidateSet("fixed-window", "vad-segmented", "vad-recall")]
    [string[]]$Pipelines = @(
        "fixed-window",
        "vad-segmented",
        "vad-recall"
    ),

    [ValidateRange(1, 15)]
    [int]$DurationSeconds = 3,

    [string]$CorpusDirectory = ".spike/corpora/synthetic-noise-v1",

    [string]$OutputDirectory = ".spike/results/whisper-quality/synthetic-noise-v1"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

Push-Location $repoRoot
$previousEnvironment = @{}
try {
    & dart run tool/benchmarks/generate_synthetic_noise_corpus.dart `
        --repository-root $repoRoot `
        --output-directory $CorpusDirectory `
        --duration-seconds $DurationSeconds
    if ($LASTEXITCODE -ne 0) {
        throw "Synthetic noise corpus preparation failed with exit code $LASTEXITCODE."
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
        RequiredEvidenceClass = "synthetic-smoke"
        OutputDirectory = $OutputDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $benchmarkArguments["DeviceId"] = $DeviceId
    }
    & (Join-Path $repoRoot "tool\benchmarks\run_android_whisper_quality_benchmark.ps1") `
        @benchmarkArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Synthetic noise Android regression failed with exit code $LASTEXITCODE."
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
