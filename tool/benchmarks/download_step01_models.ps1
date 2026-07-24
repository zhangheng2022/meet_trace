param(
    [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot '.spike\models'
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$downloadRoot = Join-Path ([System.IO.Path]::GetDirectoryName($OutputRoot)) 'downloads'

$models = @(
    @{
        id = 'sherpa-onnx-paraformer-zh-small-2024-03-09'
        url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2'
        archiveBytes = 77920048
        required = @('model.int8.onnx', 'tokens.txt')
    },
    @{
        id = 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25'
        url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2'
        archiveBytes = 878702423
        required = @(
            'conv_frontend.onnx',
            'encoder.int8.onnx',
            'decoder.int8.onnx',
            'tokenizer\merges.txt',
            'tokenizer\tokenizer_config.json',
            'tokenizer\vocab.json'
        )
    }
)

New-Item -ItemType Directory -Force -Path $OutputRoot, $downloadRoot | Out-Null

foreach ($model in $models) {
    $archive = Join-Path $downloadRoot "$($model.id).tar.bz2"
    $modelDir = Join-Path $OutputRoot $model.id

    if (-not (Test-Path -LiteralPath $archive)) {
        Write-Host "下载 $($model.id)"
        & curl.exe --fail --location --continue-at - --output $archive $model.url
        if ($LASTEXITCODE -ne 0) {
            throw "下载失败：$($model.id)"
        }
    }

    $actualArchiveBytes = (Get-Item -LiteralPath $archive).Length
    if ($actualArchiveBytes -ne $model.archiveBytes) {
        throw "归档大小不符：$($model.id)，预期 $($model.archiveBytes)，实际 $actualArchiveBytes"
    }

    if (-not (Test-Path -LiteralPath $modelDir)) {
        Write-Host "解压 $($model.id)"
        & tar -xjf $archive -C $OutputRoot
        if ($LASTEXITCODE -ne 0) {
            throw "解压失败：$($model.id)"
        }
    }

    foreach ($relativePath in $model.required) {
        $requiredPath = Join-Path $modelDir $relativePath
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "模型文件缺失：$requiredPath"
        }
    }
}

$files = foreach ($model in $models) {
    $modelDir = Join-Path $OutputRoot $model.id
    foreach ($file in Get-ChildItem -LiteralPath $modelDir -Recurse -File) {
        [ordered]@{
            modelId = $model.id
            relativePath = [System.IO.Path]::GetRelativePath($modelDir, $file.FullName).Replace('\', '/')
            bytes = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            sourceUrl = $model.url
        }
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    files = @($files)
}
$manifestPath = Join-Path ([System.IO.Path]::GetDirectoryName($OutputRoot)) 'model-files.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Host "模型已准备：$OutputRoot"
Write-Host "文件清单：$manifestPath"
