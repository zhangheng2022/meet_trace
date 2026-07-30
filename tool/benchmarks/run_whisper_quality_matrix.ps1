[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CorpusManifest,

    [Parameter(Mandatory = $true)]
    [string]$RawObservations,

    [string]$OutputDirectory = ".spike/results/whisper-quality"
)

$ErrorActionPreference = "Stop"

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
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$observations = Get-Content -LiteralPath $observationsPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($manifest.deidentified -ne $true) {
    throw "Corpus manifest 必须声明 deidentified=true"
}
if ($null -eq $manifest.samples -or $manifest.samples.Count -lt 20) {
    throw "Corpus manifest 必须至少包含 20 段"
}
if ($null -eq $observations.observations) {
    throw "Raw observations 缺少 observations 数组"
}
if ($observations.schemaVersion -ne 2) {
    throw "Raw observations schemaVersion 必须为 2"
}

$sampleIds = @{}
foreach ($sample in $manifest.samples) {
    if ([string]::IsNullOrWhiteSpace($sample.id)) {
        throw "Corpus sample id 不能为空"
    }
    if ($sampleIds.ContainsKey($sample.id)) {
        throw "Corpus sample id 重复：$($sample.id)"
    }
    $sampleIds[$sample.id] = $true

    if ([string]::IsNullOrWhiteSpace($sample.pathEnv)) {
        throw "Corpus sample $($sample.id) 缺少 pathEnv"
    }
    $audioPath = [Environment]::GetEnvironmentVariable($sample.pathEnv)
    if ([string]::IsNullOrWhiteSpace($audioPath)) {
        throw "环境变量 $($sample.pathEnv) 未配置"
    }
    $resolvedAudio = Resolve-ExistingFile -Path $audioPath -Label "Corpus audio"
    if ($resolvedAudio -match '\.(?i:wav|pcm|m4a|aac|mp3|ogg|flac)$') {
        $actualHash = (Get-FileHash -LiteralPath $resolvedAudio -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne "$($sample.sha256)".ToLowerInvariant()) {
            throw "Corpus sample $($sample.id) SHA-256 不匹配"
        }
    }
    else {
        throw "Corpus sample $($sample.id) 必须是受支持的本地音频"
    }
}

$outputRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path (Get-Location) -ChildPath $OutputDirectory)
)
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$combinedPath = Join-Path $outputRoot "quality-input.json"
$jsonPath = Join-Path $outputRoot "quality-report.json"
$csvPath = Join-Path $outputRoot "quality-report.csv"

$combined = [ordered]@{
    schemaVersion = 2
    corpus = $manifest
    observations = $observations.observations
}
Write-JsonFile -Value $combined -Path $combinedPath

dart run tool/benchmarks/whisper_quality_metrics.dart `
    --input $combinedPath `
    --output-json $jsonPath `
    --output-csv $csvPath
if ($LASTEXITCODE -ne 0) {
    throw "Whisper quality metrics 计算失败，退出码：$LASTEXITCODE"
}

Write-Output "Whisper quality JSON: $jsonPath"
Write-Output "Whisper quality CSV: $csvPath"
