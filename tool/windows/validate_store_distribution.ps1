[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('InstallUninstall', 'Update')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+-alpha\.[1-9][0-9]*$')]
    [string]$ReleaseId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^1\.0\.[1-9][0-9]*\.0$')]
    [string]$ExpectedVersion,

    [ValidatePattern('^$|^1\.0\.[1-9][0-9]*\.0$')]
    [string]$PreviousVersion = '',

    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$storeId = '9PHHSJMWK06G'
$identityName = 'zhangheng2026.MeetTrace'
$publisher = 'CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B'
$packageFamilyName = 'zhangheng2026.MeetTrace_vaaj3dqegb9y0'
$applicationId = 'MeetTrace'
$processName = 'meettrace'
$operations = [System.Collections.Generic.List[string]]::new()
$startedAt = [DateTimeOffset]::UtcNow
$cleanupInstalledPackage = $false
$upgradeAttempted = $false
$succeeded = $false
$failure = $null
$caughtError = $null

function Write-Receipt {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Succeeded,

        [AllowNull()]
        [string]$Failure
    )

    $parent = Split-Path -Parent $ReceiptPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $receipt = [ordered]@{
        schemaVersion = 1
        releaseId = $ReleaseId
        validationMode = $Mode
        storeId = $storeId
        packageIdentity = $identityName
        packageFamilyName = $packageFamilyName
        expectedVersion = $ExpectedVersion
        previousVersion = if ($Mode -eq 'Update') { $PreviousVersion } else { $null }
        architecture = 'X64'
        startedAtUtc = $startedAt.ToString('O')
        completedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
        succeeded = $Succeeded
        operations = @($operations)
        failure = $Failure
    }
    $receipt | ConvertTo-Json -Depth 6 | Set-Content `
        -LiteralPath $ReceiptPath -Encoding utf8
}

function Invoke-WinGet {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $operations.Add("winget $($Arguments -join ' ')")
    & winget @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed with exit code $LASTEXITCODE"
    }
}

function Get-MeetTracePackage {
    $packages = @(Get-AppxPackage -Name $identityName -ErrorAction SilentlyContinue)
    if ($packages.Count -gt 1) {
        throw 'More than one MeetTrace package is installed for the validation user.'
    }
    if ($packages.Count -eq 0) {
        return $null
    }
    return $packages[0]
}

function Wait-MeetTracePackage {
    param(
        [Parameter(Mandatory = $true)][bool]$Present,
        [int]$TimeoutSeconds = 180
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $package = Get-MeetTracePackage
        if ($Present -eq ($null -ne $package)) {
            return $package
        }
        Start-Sleep -Seconds 2
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Timed out waiting for MeetTrace package present=$Present."
}

function Assert-PackageIdentity {
    param(
        [Parameter(Mandatory = $true)]$Package,
        [Parameter(Mandatory = $true)][string]$Version
    )

    if ($Package.Name -cne $identityName -or
        $Package.Publisher -cne $publisher -or
        $Package.PackageFamilyName -cne $packageFamilyName -or
        $Package.Version.ToString() -cne $Version -or
        $Package.Architecture.ToString() -cne 'X64') {
        throw 'Installed Microsoft Store package identity does not match the fixed contract.'
    }
}

function Initialize-WindowValidationApi {
    if ($null -ne ('MeetTraceWindowValidation' -as [type])) {
        return
    }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class MeetTraceWindowValidation
{
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr windowHandle, int command);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr windowHandle);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
'@
}

function Wait-MeetTraceMainWindow {
    param(
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [int]$TimeoutSeconds = 60
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($null -ne $process) {
            $process.Refresh()
            if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                return $process.MainWindowHandle
            }
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw 'MeetTrace did not expose a main window in time.'
}

function Assert-SingleInstanceLaunch {
    $operations.Add(
        'launch shell:AppsFolder twice and require one process plus restored foreground window'
    )
    Initialize-WindowValidationApi
    Get-Process -Name $processName -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    $appUserModelId = "$packageFamilyName!$applicationId"
    try {
        Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$appUserModelId"
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
        do {
            $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
            if ($processes.Count -gt 0) {
                break
            }
            Start-Sleep -Seconds 2
        } while ([DateTimeOffset]::UtcNow -lt $deadline)
        if ($processes.Count -ne 1) {
            throw 'MeetTrace did not start as exactly one process.'
        }

        $originalProcessId = $processes[0].Id
        $windowHandle = Wait-MeetTraceMainWindow -ProcessId $originalProcessId
        $null = [MeetTraceWindowValidation]::ShowWindowAsync($windowHandle, 6)
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
        do {
            if ([MeetTraceWindowValidation]::IsIconic($windowHandle)) {
                break
            }
            Start-Sleep -Milliseconds 250
        } while ([DateTimeOffset]::UtcNow -lt $deadline)
        if (-not [MeetTraceWindowValidation]::IsIconic($windowHandle)) {
            throw 'MeetTrace main window could not be minimized before activation validation.'
        }

        Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$appUserModelId"
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
        $activated = $false
        do {
            $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
            if ($processes.Count -eq 1 -and $processes[0].Id -eq $originalProcessId) {
                $processes[0].Refresh()
                $windowHandle = $processes[0].MainWindowHandle
                if ($windowHandle -ne [IntPtr]::Zero -and
                    -not [MeetTraceWindowValidation]::IsIconic($windowHandle) -and
                    [MeetTraceWindowValidation]::GetForegroundWindow() -eq $windowHandle) {
                    $activated = $true
                    break
                }
            }
            Start-Sleep -Milliseconds 250
        } while ([DateTimeOffset]::UtcNow -lt $deadline)
        if (-not $activated) {
            throw 'Second launch did not restore and foreground the existing MeetTrace window.'
        }
    } finally {
        Get-Process -Name $processName -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Remove-MeetTracePackage {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $package = Get-MeetTracePackage
    if ($null -eq $package) {
        return
    }
    if (-not $PSCmdlet.ShouldProcess(
            $package.PackageFullName,
            'Remove current-user Appx package')) {
        throw 'Store validation cannot complete without removing the current-user package.'
    }
    $operations.Add('Remove-AppxPackage current-user package')
    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
    $null = Wait-MeetTracePackage -Present $false
}

try {
    if ($env:MEETTRACE_DEDICATED_STORE_VALIDATION -cne '1' -or
        $env:GITHUB_EVENT_NAME -cne 'repository_dispatch' -or
        $env:GITHUB_REF -cne 'refs/heads/master') {
        throw 'Store validation is restricted to a dedicated repository_dispatch runner on master.'
    }
    if ($Mode -eq 'Update' -and [string]::IsNullOrWhiteSpace($PreviousVersion)) {
        throw 'Update validation requires PreviousVersion.'
    }
    if ($Mode -eq 'Update' -and
        ([version]$ExpectedVersion -le [version]$PreviousVersion)) {
        throw 'ExpectedVersion must be greater than PreviousVersion.'
    }

    $os = Get-CimInstance Win32_OperatingSystem
    if ([Environment]::Is64BitOperatingSystem -ne $true -or
        [int]$os.ProductType -ne 1 -or
        [version]$os.Version -lt [version]'10.0.19045.0') {
        throw 'Store validation requires a Windows 10 22H2 or newer x64 client.'
    }
    if ($null -eq (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Windows Package Manager winget is required.'
    }
    $sourceList = (& winget source list --disable-interactivity | Out-String)
    if ($LASTEXITCODE -ne 0 -or $sourceList -notmatch '(?m)^msstore\s+') {
        throw 'winget msstore source is unavailable.'
    }

    $identityPath = Join-Path $PSScriptRoot `
        '..\..\windows\packaging\msix\store_identity.json'
    $identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
    if ($identity.identityName -cne $identityName -or
        $identity.publisher -cne $publisher -or
        $identity.packageFamilyName -cne $packageFamilyName -or
        $identity.storeId -cne $storeId) {
        throw 'Repository Store identity differs from the validation contract.'
    }

    $existing = Get-MeetTracePackage
    if ($Mode -eq 'InstallUninstall') {
        if ($null -ne $existing) {
            throw 'Clean install validation requires no pre-existing MeetTrace package.'
        }
        $cleanupInstalledPackage = $true
        Invoke-WinGet @(
            'install', '--id', $storeId, '--source', 'msstore', '--exact',
            '--architecture', 'x64', '--silent', '--accept-package-agreements',
            '--accept-source-agreements', '--disable-interactivity'
        )
    } else {
        if ($null -eq $existing) {
            throw 'Update validation requires a pre-installed Store package.'
        }
        Assert-PackageIdentity -Package $existing -Version $PreviousVersion
        $upgradeAttempted = $true
        Invoke-WinGet @(
            'upgrade', '--id', $storeId, '--source', 'msstore', '--exact',
            '--architecture', 'x64', '--silent', '--accept-package-agreements',
            '--accept-source-agreements', '--disable-interactivity'
        )
        $cleanupInstalledPackage = $true
    }

    $installed = Wait-MeetTracePackage -Present $true
    Assert-PackageIdentity -Package $installed -Version $ExpectedVersion
    Assert-SingleInstanceLaunch
    Remove-MeetTracePackage
    $cleanupInstalledPackage = $false
    $succeeded = $true
} catch {
    $failure = $_.Exception.Message
    $caughtError = $_
} finally {
    try {
        if ($cleanupInstalledPackage) {
            Remove-MeetTracePackage
        } elseif ($upgradeAttempted) {
            $packageAfterFailure = Get-MeetTracePackage
            if ($null -ne $packageAfterFailure -and
                $packageAfterFailure.Version.ToString() -cne $PreviousVersion) {
                Remove-MeetTracePackage
            }
        }
    } catch {
        $succeeded = $false
        $cleanupFailure = "Cleanup failed: $($_.Exception.Message)"
        $failure = if ([string]::IsNullOrWhiteSpace($failure)) {
            $cleanupFailure
        } else {
            "$failure; $cleanupFailure"
        }
        if ($null -eq $caughtError) {
            $caughtError = $_
        }
    }
    Write-Receipt -Succeeded $succeeded -Failure $failure
}

if ($null -ne $caughtError) {
    throw $caughtError
}
