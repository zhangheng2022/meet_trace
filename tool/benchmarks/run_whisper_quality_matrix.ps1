[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CorpusManifest,

    [Parameter(Mandatory = $true)]
    [string]$RawObservations,

    [ValidateSet("product-meeting", "public-regression", "synthetic-smoke")]
    [string]$RequiredEvidenceClass = "product-meeting",

    [string]$OutputDirectory = ".spike/results/whisper-quality"
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

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$Depth = 20
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

$manifestPath = Resolve-ExistingFile -Path $CorpusManifest -Label "Corpus manifest"
$observationsPath = Resolve-ExistingFile -Path $RawObservations -Label "Raw observations"
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
$spikePrefix = $spikeRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
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
$canonicalObservationsPath = (Resolve-Path -LiteralPath $observationsPath).Path
if (-not $canonicalObservationsPath.StartsWith(
        $canonicalSpikePrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Raw observations must resolve inside the ignored repository .spike directory."
}
$observationsDirectory = Split-Path -Parent $canonicalObservationsPath
$combinedPath = Join-Path $outputRoot "quality-input.json"
$jsonPath = Join-Path $outputRoot "quality-report.json"
$csvPath = Join-Path $outputRoot "quality-report.csv"
foreach ($staleOutputFile in @($combinedPath, $jsonPath, $csvPath)) {
    if (Test-Path -LiteralPath $staleOutputFile -PathType Leaf) {
        Remove-Item -LiteralPath $staleOutputFile -Force
    }
}
$manifestSha256 = (
    Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$observations = Get-Content -LiteralPath $observationsPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($manifest.deidentified -isnot [bool]) {
    throw "Corpus manifest deidentified must be a boolean"
}
if ($manifest.schemaVersion -ne 2) {
    throw "Corpus manifest schemaVersion must be 2"
}
if ($manifest.evidenceClass -ne $RequiredEvidenceClass) {
    throw "Corpus evidenceClass must be $RequiredEvidenceClass"
}
if ($manifest.evidenceClass -eq "product-meeting" -and
    $manifest.deidentified -ne $true) {
    throw "Product meeting corpus must declare deidentified=true"
}
if ([string]::IsNullOrWhiteSpace($manifest.provenance.sourceId) -or
    [string]::IsNullOrWhiteSpace($manifest.provenance.licenseId)) {
    throw "Corpus provenance must include sourceId and licenseId"
}
if ($manifest.evidenceClass -eq "product-meeting" -and
    ("$($manifest.provenance.reviewAttestationSha256)" -notmatch "^[0-9a-f]{64}$" -or
        [string]::IsNullOrWhiteSpace("$($manifest.provenance.reviewedAtUtc)") -or
        -not "$($manifest.provenance.reviewedAtUtc)".EndsWith("Z"))) {
    throw "Product meeting provenance must bind a review attestation SHA-256 and UTC timestamp"
}
if ($null -eq $manifest.samples -or $manifest.samples.Count -lt 20) {
    throw "Corpus manifest must contain at least 20 samples"
}
if ($null -eq $observations.observations) {
    throw "Raw observations must contain an observations array"
}
if ($observations.schemaVersion -ne 4) {
    throw "Raw observations schemaVersion must be 4"
}
if ($observations.execution.corpusId -ne $manifest.id -or
    $observations.execution.corpusDeidentified -ne $manifest.deidentified -or
    $observations.execution.corpusEvidenceClass -ne $manifest.evidenceClass -or
    $observations.execution.corpusManifestSha256 -ne $manifestSha256) {
    throw "Raw observations corpus attestation does not match the manifest"
}
$declaredPipelineIds = @(
    @($observations.execution.pipelineIds) |
        ForEach-Object { "$_" } |
        Sort-Object -Unique
)
$observedPipelineIds = @(
    @($observations.observations) |
        ForEach-Object { "$($_.pipelineId)" } |
        Sort-Object -Unique
)
if ($declaredPipelineIds.Count -eq 0 -or
    ($declaredPipelineIds -join "`0") -ne ($observedPipelineIds -join "`0")) {
    throw "Raw observations pipeline attestation does not match observations"
}
$observedDeviceIds = @(
    @($observations.observations) |
        ForEach-Object { "$($_.deviceId)" } |
        Sort-Object -Unique
)
if ($observedDeviceIds.Count -ne 1 -or
    $observedDeviceIds[0] -ne "$($observations.execution.deviceId)") {
    throw "Raw observations device attestation does not match observations"
}
$transcriptPaths = @{}
foreach ($observation in @($observations.observations)) {
    $transcriptRef = "$($observation.transcriptRef)"
    $transcriptSha256 = "$($observation.transcriptSha256)".ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($transcriptRef) -or
        [System.IO.Path]::IsPathRooted($transcriptRef) -or
        $transcriptSha256 -notmatch "^[0-9a-f]{64}$") {
        throw "Every observation must bind a relative transcriptRef and transcriptSha256."
    }
    $transcriptPath = [System.IO.Path]::GetFullPath(
        (Join-Path $observationsDirectory $transcriptRef)
    )
    if (-not (Test-Path -LiteralPath $transcriptPath -PathType Leaf)) {
        throw "Transcript evidence does not exist: $transcriptRef"
    }
    $canonicalTranscriptPath = (Resolve-Path -LiteralPath $transcriptPath).Path
    if (-not $canonicalTranscriptPath.StartsWith(
            $canonicalSpikePrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Transcript evidence resolves outside the ignored repository .spike directory."
    }
    if ($transcriptPaths.ContainsKey($canonicalTranscriptPath)) {
        throw "Transcript evidence must not be reused by multiple observations."
    }
    $actualTranscriptSha256 = (
        Get-FileHash -LiteralPath $canonicalTranscriptPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($actualTranscriptSha256 -ne $transcriptSha256) {
        throw "Transcript evidence SHA-256 mismatch: $transcriptRef"
    }
    $transcriptPaths[$canonicalTranscriptPath] = $true
}

$sampleIds = @{}
foreach ($sample in $manifest.samples) {
    if ([string]::IsNullOrWhiteSpace($sample.id)) {
        throw "Corpus sample id must not be empty"
    }
    if ($sampleIds.ContainsKey($sample.id)) {
        throw "Duplicate corpus sample id: $($sample.id)"
    }
    $sampleIds[$sample.id] = $true

    if ([string]::IsNullOrWhiteSpace($sample.pathEnv)) {
        throw "Corpus sample $($sample.id) is missing pathEnv"
    }
    $audioPath = [Environment]::GetEnvironmentVariable($sample.pathEnv)
    if ([string]::IsNullOrWhiteSpace($audioPath)) {
        throw "Environment variable $($sample.pathEnv) is not configured"
    }
    $resolvedAudio = Resolve-ExistingFile -Path $audioPath -Label "Corpus audio"
    if ($resolvedAudio -match '\.(?i:wav|pcm|m4a|aac|mp3|ogg|flac)$') {
        $actualHash = (Get-FileHash -LiteralPath $resolvedAudio -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne "$($sample.sha256)".ToLowerInvariant()) {
            throw "Corpus sample $($sample.id) SHA-256 mismatch"
        }
    }
    else {
        throw "Corpus sample $($sample.id) must be a supported local audio file"
    }
}

$combined = [ordered]@{
    schemaVersion = 4
    execution = $observations.execution
    corpus = $manifest
    observations = $observations.observations
}
Write-JsonFile -Value $combined -Path $combinedPath

dart run tool/benchmarks/whisper_quality_metrics.dart `
    --input $combinedPath `
    --output-json $jsonPath `
    --output-csv $csvPath
if ($LASTEXITCODE -ne 0) {
    throw "Whisper quality metrics failed with exit code $LASTEXITCODE"
}

Write-Output "Whisper quality JSON: $jsonPath"
Write-Output "Whisper quality CSV: $csvPath"
