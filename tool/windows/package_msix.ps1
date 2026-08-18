param(
    [string]$BuildDirectory,
    [string]$Publisher,
    [string]$PublisherDisplayName,
    [string]$IdentityName,
    [string]$PackageVersion,
    [string]$OutputPath,
    [string]$MakeAppxPath,
    [switch]$MicrosoftStore,
    [switch]$DevelopmentProbe
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

function Resolve-PackageVersion {
    param([string]$RequestedVersion)

    if (-not [string]::IsNullOrWhiteSpace($RequestedVersion)) {
        return $RequestedVersion
    }

    $pubspec = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Raw
    $match = [regex]::Match(
        $pubspec,
        '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*(?:#.*)?$'
    )
    if (-not $match.Success) {
        throw 'pubspec.yaml version must use major.minor.patch+build.'
    }
    return '{0}.{1}.{2}.{3}' -f $match.Groups[1].Value,
        $match.Groups[2].Value,
        $match.Groups[3].Value,
        $match.Groups[4].Value
}

function Assert-PackageVersion {
    param([string]$Version)

    if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
        throw 'MSIX PackageVersion must contain exactly four numeric parts.'
    }
    foreach ($part in $Version.Split('.')) {
        $value = [uint32]$part
        if ($value -gt 65535) {
            throw 'Every MSIX PackageVersion part must be between 0 and 65535.'
        }
    }
}

function Resolve-MakeAppx {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = [System.IO.Path]::GetFullPath($RequestedPath)
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            throw "MakeAppx.exe not found: $resolved"
        }
        return $resolved
    }

    $command = Get-Command makeappx.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:WindowsSdkVerBinPath)) {
        $candidates += Join-Path $env:WindowsSdkVerBinPath 'x64\makeappx.exe'
    }

    $sdkRoots = @()
    foreach ($registryPath in @(
        'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    )) {
        if (Test-Path -LiteralPath $registryPath) {
            $kitsRoot = (Get-ItemProperty -LiteralPath $registryPath).KitsRoot10
            if (-not [string]::IsNullOrWhiteSpace($kitsRoot)) {
                $sdkRoots += $kitsRoot
            }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
        $sdkRoots += Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
    }

    foreach ($sdkRoot in ($sdkRoots | Sort-Object -Unique)) {
        $sdkBin = Join-Path $sdkRoot 'bin'
        if (Test-Path -LiteralPath $sdkBin -PathType Container) {
            $candidates += Get-ChildItem -LiteralPath $sdkBin -Directory |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'x64\makeappx.exe' }
        }
        $candidates += Join-Path $sdkRoot 'App Certification Kit\makeappx.exe'
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }
    throw 'MakeAppx.exe was not found. Install the Windows SDK or pass -MakeAppxPath.'
}

function Escape-XmlValue {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

if ($MicrosoftStore -and $DevelopmentProbe) {
    throw 'MicrosoftStore and DevelopmentProbe are mutually exclusive.'
}
if ($MicrosoftStore) {
    $storeIdentityPath = Join-Path $repoRoot 'windows\packaging\msix\store_identity.json'
    if (-not (Test-Path -LiteralPath $storeIdentityPath -PathType Leaf)) {
        throw 'Microsoft Store identity configuration is missing.'
    }
    $storeIdentity = Get-Content -LiteralPath $storeIdentityPath -Raw | ConvertFrom-Json
    if ($storeIdentity.schemaVersion -ne 1) {
        throw 'Microsoft Store identity schemaVersion is unsupported.'
    }
    $IdentityName = [string]$storeIdentity.identityName
    $Publisher = [string]$storeIdentity.publisher
    $PublisherDisplayName = [string]$storeIdentity.publisherDisplayName
}

if ([string]::IsNullOrWhiteSpace($Publisher) -or $Publisher -notmatch '^CN=') {
    throw 'Publisher must be the complete certificate Subject and start with CN=.'
}
if ([string]::IsNullOrWhiteSpace($IdentityName) -or
    $IdentityName -notmatch '^[A-Za-z0-9.-]{3,50}$') {
    throw 'IdentityName must contain 3-50 letters, digits, periods, or hyphens.'
}
if ($DevelopmentProbe) {
    if ($Publisher -ne 'CN=MeetTrace Development') {
        throw 'DevelopmentProbe must use the fixed CN=MeetTrace Development publisher.'
    }
    $PublisherDisplayName = 'MeetTrace Development'
} elseif ($Publisher -match '(?i)(development|example|contoso|localhost|test)') {
    throw 'Development or placeholder publishers cannot create a production MSIX.'
}
if ([string]::IsNullOrWhiteSpace($PublisherDisplayName)) {
    throw 'PublisherDisplayName must be a non-empty value.'
}

$PackageVersion = Resolve-PackageVersion -RequestedVersion $PackageVersion
Assert-PackageVersion -Version $PackageVersion
if ($MicrosoftStore) {
    $storeVersionParts = $PackageVersion.Split('.')
    if ([uint32]$storeVersionParts[0] -eq 0) {
        throw 'Microsoft Store MSIX PackageVersion major must be greater than 0.'
    }
    if ([uint32]$storeVersionParts[3] -ne 0) {
        throw 'Microsoft Store reserves the fourth PackageVersion part; it must be 0.'
    }
    if ($PackageVersion -notmatch '^1\.0\.[1-9][0-9]*\.0$') {
        throw 'Microsoft Store PackageVersion must use 1.0.<shared build number>.0.'
    }
}

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $repoRoot 'build\windows\x64\runner\Release'
}
$BuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory)
if (-not (Test-Path -LiteralPath $BuildDirectory -PathType Container)) {
    throw "Windows Release bundle not found: $BuildDirectory"
}
foreach ($requiredPath in @(
    'meettrace.exe',
    'flutter_windows.dll',
    'data\app.so',
    'data\icudtl.dat',
    'data\flutter_assets\NOTICES.Z'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $BuildDirectory $requiredPath) -PathType Leaf)) {
        throw "Windows Release bundle is incomplete: $requiredPath"
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot 'build\windows\msix\meettrace-windows-x64.msix'
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
if ([System.IO.Path]::GetExtension($OutputPath) -ne '.msix') {
    throw 'OutputPath must end in .msix.'
}
New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($OutputPath)) | Out-Null

$makeAppx = Resolve-MakeAppx -RequestedPath $MakeAppxPath
$templatePath = Join-Path $repoRoot 'windows\packaging\msix\AppxManifest.xml.template'
$assetsPath = Join-Path $repoRoot 'windows\packaging\msix\Assets'
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $assetsPath -PathType Container)) {
    throw 'MSIX manifest template or visual assets are missing.'
}

$stagingParent = Join-Path $repoRoot 'build\windows\msix\.staging'
New-Item -ItemType Directory -Force -Path $stagingParent | Out-Null
$stagingPath = Join-Path $stagingParent ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $stagingPath | Out-Null

try {
    Copy-Item -Path (Join-Path $BuildDirectory '*') -Destination $stagingPath -Recurse -Force
    Copy-Item -LiteralPath $assetsPath -Destination (Join-Path $stagingPath 'Assets') -Recurse -Force

    $manifest = Get-Content -LiteralPath $templatePath -Raw
    $manifest = $manifest.Replace('{{IDENTITY_NAME}}', (Escape-XmlValue $IdentityName))
    $manifest = $manifest.Replace('{{PUBLISHER}}', (Escape-XmlValue $Publisher))
    $manifest = $manifest.Replace('{{PUBLISHER_DISPLAY_NAME}}', (Escape-XmlValue $PublisherDisplayName))
    $manifest = $manifest.Replace('{{VERSION}}', $PackageVersion)
    if ($manifest -match '{{[A-Z_]+}}') {
        throw 'MSIX manifest contains unresolved placeholders.'
    }
    Set-Content -LiteralPath (Join-Path $stagingPath 'AppxManifest.xml') -Value $manifest -Encoding utf8

    & $makeAppx pack /o /v /h SHA256 /d $stagingPath /p $OutputPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw "MakeAppx failed with exit code $LASTEXITCODE."
    }

    $packageHash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $metadata = [ordered]@{
        capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
        artifact = [System.IO.Path]::GetFileName($OutputPath)
        bytes = (Get-Item -LiteralPath $OutputPath).Length
        sha256 = $packageHash
        identityName = $IdentityName
        publisher = $Publisher
        packageVersion = $PackageVersion
        architecture = 'x64'
        distribution = if ($MicrosoftStore) { 'microsoftStore' } elseif ($DevelopmentProbe) { 'developmentProbe' } else { 'direct' }
        publisherDisplayName = $PublisherDisplayName
        developmentProbe = [bool]$DevelopmentProbe
        microsoftStore = [bool]$MicrosoftStore
        signed = $false
    }
    $metadataPath = "$OutputPath.packaging.json"
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath -Encoding utf8
    Write-Output "Unsigned MSIX created: $OutputPath"
    Write-Output "Packaging metadata: $metadataPath"
} finally {
    $resolvedStaging = [System.IO.Path]::GetFullPath($stagingPath)
    $resolvedParent = [System.IO.Path]::GetFullPath($stagingParent) + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedStaging.StartsWith($resolvedParent, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedStaging)) {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
