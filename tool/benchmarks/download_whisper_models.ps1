param(
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot '.spike\models'
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$revision = '5359861c739e955e79d9a303bcbc70fb988958b1'
$baseUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/$revision"
$models = @(
    @{
        id = 'whisper-cpp-base-q5_1-v1.9.1'
        file = 'ggml-base-q5_1.bin'
        bytes = 59707625
        sha256 = '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898'
    },
    @{
        id = 'whisper-cpp-small-q5_1-v1.9.1'
        file = 'ggml-small-q5_1.bin'
        bytes = 190085487
        sha256 = 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb'
    },
    @{
        id = 'whisper-vad-silero-v6.2.0'
        file = 'ggml-silero-v6.2.0.bin'
        bytes = 885098
        sha256 = '2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987'
        sourceUrl = 'https://huggingface.co/ggml-org/whisper-vad/resolve/9ffd54a1e1ee413ddf265af9913beaf518d1639b/ggml-silero-v6.2.0.bin?download=true'
        sourceRevision = '9ffd54a1e1ee413ddf265af9913beaf518d1639b'
    }
)

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$files = foreach ($model in $models) {
    $modelDirectory = Join-Path $OutputRoot $model.id
    $modelPath = Join-Path $modelDirectory $model.file
    $sourceUrl = if ($model.sourceUrl) {
        $model.sourceUrl
    }
    else {
        "$baseUrl/$($model.file)?download=true"
    }
    New-Item -ItemType Directory -Force -Path $modelDirectory | Out-Null

    if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
        Write-Host "下载 $($model.id)"
        & curl.exe --fail --location --continue-at - --output $modelPath $sourceUrl
        if ($LASTEXITCODE -ne 0) {
            throw "下载失败：$($model.id)"
        }
    }

    $actualBytes = (Get-Item -LiteralPath $modelPath).Length
    $actualSha256 = (Get-FileHash -LiteralPath $modelPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualBytes -ne $model.bytes -or $actualSha256 -ne $model.sha256) {
        throw "模型校验失败：$modelPath"
    }

    [ordered]@{
        modelId = $model.id
        relativePath = $model.file
        bytes = $actualBytes
        sha256 = $actualSha256
        sourceUrl = $sourceUrl
        sourceRevision = if ($model.sourceRevision) {
            $model.sourceRevision
        }
        else {
            $revision
        }
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    whisperCppVersion = 'v1.9.1'
    whisperCppCommit = 'f049fff95a089aa9969deb009cdd4892b3e74916'
    files = @($files)
}
$manifestPath = Join-Path ([System.IO.Path]::GetDirectoryName($OutputRoot)) 'model-files.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Host "Whisper 模型已准备：$OutputRoot"
Write-Host "文件清单：$manifestPath"
