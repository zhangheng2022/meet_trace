param(
    [Parameter(Mandatory = $true)]
    [string]$MsixPath,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedPublisher,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion,
    [string]$ExpectedIdentityName = 'com.meettrace.app',
    [string]$ReportPath,
    [switch]$RequireSignature
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$MsixPath = [System.IO.Path]::GetFullPath($MsixPath)
if (-not (Test-Path -LiteralPath $MsixPath -PathType Leaf)) {
    throw "MSIX not found: $MsixPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($MsixPath)
try {
    $entryMap = @{}
    foreach ($entry in $archive.Entries) {
        $entryMap[$entry.FullName.Replace('\', '/')] = $entry
    }
    $entries = @($entryMap.Keys | Sort-Object)
    if (-not $entryMap.ContainsKey('AppxManifest.xml')) {
        throw 'MSIX does not contain AppxManifest.xml.'
    }
    $manifestReader = [System.IO.StreamReader]::new($entryMap['AppxManifest.xml'].Open())
    try {
        [xml]$manifest = $manifestReader.ReadToEnd()
    } finally {
        $manifestReader.Dispose()
    }
} finally {
    $archive.Dispose()
}

$identity = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
$application = $manifest.SelectSingleNode("//*[local-name()='Application']")
$targetFamily = $manifest.SelectSingleNode("//*[local-name()='TargetDeviceFamily']")
$capabilities = @($manifest.SelectNodes("//*[local-name()='Capability' or local-name()='DeviceCapability']") |
    ForEach-Object { $_.GetAttribute('Name') })

$requiredEntries = @(
    'meettrace.exe',
    'flutter_windows.dll',
    'data/app.so',
    'data/icudtl.dat',
    'data/flutter_assets/NOTICES.Z',
    'data/flutter_assets/assets/models/manifest.json',
    'data/flutter_assets/assets/models/silero-vad-manifest.json',
    'data/flutter_assets/assets/models/speaker-diarization-manifest.json',
    'data/flutter_assets/assets/licenses/sense-voice-NOTICE.txt',
    'data/flutter_assets/assets/licenses/sense-voice-LICENSE.txt',
    'data/flutter_assets/assets/licenses/silero-vad-NOTICE.txt',
    'data/flutter_assets/assets/licenses/silero-vad-LICENSE.txt',
    'data/flutter_assets/assets/licenses/pyannote-segmentation-NOTICE.txt',
    'data/flutter_assets/assets/licenses/pyannote-segmentation-LICENSE.txt',
    'data/flutter_assets/assets/licenses/3d-speaker-NOTICE.txt',
    'data/flutter_assets/assets/licenses/3d-speaker-LICENSE.txt',
    'Assets/StoreLogo.png',
    'Assets/Square44x44Logo.png',
    'Assets/Square150x150Logo.png'
)
$missingEntries = @($requiredEntries | Where-Object { $_ -notin $entries })
$forbiddenWeights = @($entries | Where-Object {
    $_ -match '(?i)(\.onnx$|\.tflite$|\.tar\.bz2$|/tokens\.txt$|/model\.int8(?:\.bin)?$|paraformer|qwen3-asr|sense-voice-.*/model|silero_vad.*\.onnx)'
})
$forbiddenUserData = @($entries | Where-Object {
    $_ -match '(?i)\.(wav|pcm|m4a|aac|mp3|ogg|flac|sqlite|sqlite3|db)$'
})
$forbiddenCredentials = @($entries | Where-Object {
    $_ -match '(?i)(^|/)(\.env(?:\..*)?|[^/]+\.(pfx|p12|pem|key|keystore|jks))$'
})
$hasSignature = 'AppxSignature.p7x' -in $entries
$authenticodeStatus = 'NotChecked'
$signerSubject = $null
if ($RequireSignature) {
    $authenticodeCommand = Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue
    if ($null -eq $authenticodeCommand) {
        throw 'Authenticode verification is unavailable on this platform.'
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $MsixPath
    $authenticodeStatus = $signature.Status.ToString()
    if ($null -ne $signature.SignerCertificate) {
        $signerSubject = $signature.SignerCertificate.Subject
    }
}

$checks = [ordered]@{
    identityNameMatches = $null -ne $identity -and $identity.GetAttribute('Name') -ceq $ExpectedIdentityName
    publisherMatches = $null -ne $identity -and $identity.GetAttribute('Publisher') -ceq $ExpectedPublisher
    versionMatches = $null -ne $identity -and $identity.GetAttribute('Version') -ceq $ExpectedVersion
    architectureIsX64 = $null -ne $identity -and $identity.GetAttribute('ProcessorArchitecture') -ceq 'x64'
    executableMatches = $null -ne $application -and $application.GetAttribute('Executable') -ceq 'meettrace.exe'
    targetIsWindows10_22H2 = $null -ne $targetFamily -and
        $targetFamily.GetAttribute('Name') -ceq 'Windows.Desktop' -and
        $targetFamily.GetAttribute('MinVersion') -ceq '10.0.19045.0'
    hasInternetClient = 'internetClient' -in $capabilities
    hasMicrophone = 'microphone' -in $capabilities
    hasRunFullTrust = 'runFullTrust' -in $capabilities
    signatureRequirementMet = -not $RequireSignature -or
        ($hasSignature -and $authenticodeStatus -ceq 'Valid')
    signerSubjectMatchesPublisher = -not $RequireSignature -or
        ($null -ne $signerSubject -and $signerSubject -ceq $ExpectedPublisher)
}

$report = [ordered]@{
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    msixPath = $MsixPath
    msixBytes = (Get-Item -LiteralPath $MsixPath).Length
    sha256 = (Get-FileHash -LiteralPath $MsixPath -Algorithm SHA256).Hash.ToLowerInvariant()
    identity = if ($null -eq $identity) { $null } else { [ordered]@{
        name = $identity.GetAttribute('Name')
        publisher = $identity.GetAttribute('Publisher')
        version = $identity.GetAttribute('Version')
        architecture = $identity.GetAttribute('ProcessorArchitecture')
    }}
    hasSignature = $hasSignature
    authenticodeStatus = $authenticodeStatus
    signerSubject = $signerSubject
    checks = $checks
    requiredEntries = $requiredEntries
    missingEntries = $missingEntries
    forbiddenWeights = $forbiddenWeights
    forbiddenUserData = $forbiddenUserData
    forbiddenCredentials = $forbiddenCredentials
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $repoRoot 'build\windows\msix\msix-inspection.json'
}
$ReportPath = [System.IO.Path]::GetFullPath($ReportPath)
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($ReportPath)) | Out-Null
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding utf8
Write-Host "MSIX inspection report: $ReportPath"

$failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
if ($failedChecks.Count -gt 0 -or $missingEntries.Count -gt 0 -or
    $forbiddenWeights.Count -gt 0 -or $forbiddenUserData.Count -gt 0 -or
    $forbiddenCredentials.Count -gt 0) {
    throw 'MSIX identity, signature, or content inspection failed.'
}
