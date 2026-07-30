param(
    [Parameter(Mandatory)]
    [string]$DeviceId,
    [string]$ModelRoot,
    [string]$AndroidSdkRoot,
    [ValidateSet('all', 'base', 'small')]
    [string]$ModelFilter = 'all'
)

$ErrorActionPreference = 'Stop'
$smallExpectedBytes = 190085487
$smallExpectedSha256 = 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ModelRoot)) {
    $ModelRoot = Join-Path $repoRoot '.spike\models'
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    $AndroidSdkRoot = $env:ANDROID_SDK_ROOT
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    throw 'Specify the Android SDK with -AndroidSdkRoot or ANDROID_SDK_ROOT.'
}

$ModelRoot = [System.IO.Path]::GetFullPath($ModelRoot)
$adb = Join-Path $AndroidSdkRoot 'platform-tools\adb.exe'
$smallModelId = 'whisper-cpp-small-q5_1-v1.9.1'
$smallModelDirectory = Join-Path $ModelRoot $smallModelId
$smallModelFile = Join-Path $smallModelDirectory 'ggml-small-q5_1.bin'
if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
    throw "adb not found: $adb"
}
if ($ModelFilter -ne 'base' -and
    -not (Test-Path -LiteralPath $smallModelFile -PathType Leaf)) {
    throw "Small model not found: $smallModelFile. Run download_whisper_models.ps1 first."
}

if ($ModelFilter -ne 'base') {
    $smallModelInfo = Get-Item -LiteralPath $smallModelFile
    if ($smallModelInfo.Length -ne $smallExpectedBytes) {
        throw "Small model size mismatch. Expected $smallExpectedBytes bytes, got $($smallModelInfo.Length)."
    }
    $smallActualSha256 = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $smallModelFile
    ).Hash.ToLowerInvariant()
    if ($smallActualSha256 -ne $smallExpectedSha256) {
        throw "Small model SHA256 mismatch. Expected $smallExpectedSha256, got $smallActualSha256."
    }
}

$remoteTemp = "/data/local/tmp/meettrace-whisper-$([Guid]::NewGuid().ToString('N'))"
if ($remoteTemp -notmatch '^/data/local/tmp/meettrace-whisper-[0-9a-f]{32}$') {
    throw 'Temporary device path is outside the allowed boundary.'
}
$resultsRoot = Join-Path $repoRoot '.spike\results'
New-Item -ItemType Directory -Force -Path $resultsRoot | Out-Null

function Invoke-FlutterTest {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & flutter @Arguments 2>&1 | Tee-Object -FilePath $LogPath
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) {
        throw "$FailureMessage Exit code: $exitCode"
    }
}

Push-Location $repoRoot
try {
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
        throw 'Debug APK build failed.'
    }
    & (Join-Path $PSScriptRoot 'inspect_debug_apk.ps1')

    if ($ModelFilter -ne 'small') {
        Invoke-FlutterTest `
            -Arguments @(
                'test',
                'integration_test/whisper_base_standard_asr_engine_test.dart',
                '-d',
                $DeviceId
            ) `
            -LogPath (Join-Path $resultsRoot 'whisper-base.stdout.log') `
            -FailureMessage 'Whisper Base integration test failed.'
    }

    if ($ModelFilter -ne 'base') {
        & $adb -s $DeviceId shell mkdir -p $remoteTemp
        & $adb -s $DeviceId push $smallModelFile "$remoteTemp/ggml-small-q5_1.bin"
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to push the Whisper Small model.'
        }
        Invoke-FlutterTest `
            -Arguments @(
                'test',
                'integration_test/whisper_small_advanced_asr_engine_test.dart',
                '-d',
                $DeviceId,
                "--dart-define=MEETTRACE_WHISPER_SMALL_MODEL_ROOT=$remoteTemp"
            ) `
            -LogPath (Join-Path $resultsRoot 'whisper-small.stdout.log') `
            -FailureMessage 'Whisper Small integration test failed.'
    }

    Write-Host "Whisper Android validation completed: $resultsRoot"
}
finally {
    if ($remoteTemp -match '^/data/local/tmp/meettrace-whisper-[0-9a-f]{32}$') {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $adb -s $DeviceId shell rm -rf -- $remoteTemp *> $null
        }
        finally {
            $ErrorActionPreference = $previousErrorAction
        }
    }
    Pop-Location
}
