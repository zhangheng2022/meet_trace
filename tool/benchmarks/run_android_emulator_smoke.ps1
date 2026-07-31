[CmdletBinding()]
param(
    [string]$DeviceId,
    [int]$RecordingSeconds = 30,
    [int]$NativeLifecycleCycles = 100,
    [int]$VadLifecycleCycles = 100,
    [int]$MeetingLifecycleCycles = 10,
    [string]$EvidenceDirectory = "docs/quality/evidence/android-emulator",
    [string]$ReleaseInputPath = "docs/quality/evidence/android-emulator/phase-0-4-release-input.json",
    [string]$ReleaseReportPath = "docs/quality/evidence/android-emulator/phase-0-4-release-report.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Resolve-AdbPath {
    $sdkCandidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    )
    $flutterConfig = & flutter config --list 2>$null
    foreach ($line in $flutterConfig) {
        if ($line -match "android-sdk:\s*(.+)$") {
            $sdkCandidates += $Matches[1].Trim()
        }
    }
    foreach ($sdk in $sdkCandidates) {
        if ([string]::IsNullOrWhiteSpace($sdk)) {
            continue
        }
        $candidate = Join-Path $sdk "platform-tools\adb.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }
    throw "adb not found; configure ANDROID_SDK_ROOT or flutter config --android-sdk."
}

function Resolve-X64EmulatorDevice {
    param([string]$RequestedDeviceId)

    if (-not [string]::IsNullOrWhiteSpace($RequestedDeviceId)) {
        return $RequestedDeviceId
    }
    $json = (& flutter devices --machine | Out-String) | ConvertFrom-Json
    $matches = @($json | Where-Object {
        $_.targetPlatform -eq "android-x64" -and $_.emulator -eq $true
    })
    if ($matches.Count -ne 1) {
        throw "Exactly one running Android x86_64 emulator is required; found $($matches.Count)."
    }
    return $matches[0].id
}

function Invoke-FlutterStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & flutter @Arguments 2>&1 | Tee-Object -FilePath $LogPath
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $watch.Stop()
    $rawLog = Get-Content -LiteralPath $LogPath -Raw -Encoding UTF8
    $sanitizedLog = $rawLog.Replace($repoRoot.Path, "<workspace>")
    $sanitizedLog = $sanitizedLog.Replace(
        $repoRoot.Path.Replace('\', '/'),
        "<workspace>"
    )
    Set-Content -LiteralPath $LogPath -Value $sanitizedLog -Encoding UTF8 -NoNewline
    $relativeLog = (Resolve-Path -LiteralPath $LogPath -Relative) -replace "^[.][\\/]", ""
    $logSha256 = (
        Get-FileHash -LiteralPath $LogPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $script:results += [ordered]@{
        name = $Name
        command = "flutter " + ($Arguments -join " ")
        exitCode = $exitCode
        elapsedMs = $watch.ElapsedMilliseconds
        log = $relativeLog
        logSha256 = $logSha256
    }
    if ($exitCode -ne 0) {
        throw "Step failed: $Name (exit code $exitCode)."
    }
}

function Install-And-GrantRecordingPermissions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdbPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetDeviceId,

        [Parameter(Mandatory = $true)]
        [int]$TargetApiLevel,

        [Parameter(Mandatory = $true)]
        [string]$ApkPath
    )

    & $AdbPath -s $TargetDeviceId install -r $ApkPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to install the Debug APK on the emulator."
    }
    $packageName = "com.example.meettrace"
    & $AdbPath -s $TargetDeviceId shell pm grant $packageName android.permission.RECORD_AUDIO
    if ($TargetApiLevel -ge 33) {
        & $AdbPath -s $TargetDeviceId shell pm grant $packageName android.permission.POST_NOTIFICATIONS
    }
}

function Read-JsonMarker {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $true)]
        [string]$Marker
    )

    $line = Get-Content -LiteralPath $LogPath -Encoding UTF8 |
        Where-Object { $_.StartsWith($Marker) } |
        Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Evidence marker missing: $Marker ($LogPath)"
    }
    return $line.Substring($Marker.Length) | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = ($Value | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"
    [System.IO.File]::WriteAllText(
        $Path,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if ($RecordingSeconds -lt 1) {
    throw "RecordingSeconds must be greater than zero."
}
if ($NativeLifecycleCycles -lt 1) {
    throw "NativeLifecycleCycles must be greater than zero."
}
if ($VadLifecycleCycles -lt 1) {
    throw "VadLifecycleCycles must be greater than zero."
}
if ($MeetingLifecycleCycles -lt 10) {
    throw "MeetingLifecycleCycles must be at least 10."
}

$smokeReportWritten = $false
Push-Location $repoRoot
try {
    $adb = Resolve-AdbPath
    $resolvedDeviceId = Resolve-X64EmulatorDevice -RequestedDeviceId $DeviceId
    $deviceState = (& $adb -s $resolvedDeviceId get-state).Trim()
    if ($deviceState -ne "device") {
        throw "Emulator is not ready: $resolvedDeviceId ($deviceState)."
    }
    $bootCompleted = (& $adb -s $resolvedDeviceId shell getprop sys.boot_completed).Trim()
    if ($bootCompleted -ne "1") {
        throw "Emulator boot is incomplete: $resolvedDeviceId."
    }
    $abi = (& $adb -s $resolvedDeviceId shell getprop ro.product.cpu.abi).Trim()
    if ($abi -ne "x86_64") {
        throw "Target ABI must be x86_64; actual ABI: $abi."
    }
    $apiLevel = [int]((& $adb -s $resolvedDeviceId shell getprop ro.build.version.sdk).Trim())

    $evidenceRoot = [System.IO.Path]::GetFullPath(
        (Join-Path -Path $repoRoot -ChildPath $EvidenceDirectory)
    )
    $logRoot = Join-Path $evidenceRoot "logs"
    [System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
    $script:results = @()
    $startedAt = [DateTimeOffset]::UtcNow

    Invoke-FlutterStep `
        -Name "build-android-x64-debug" `
        -Arguments @("build", "apk", "--debug", "--target-platform", "android-x64") `
        -LogPath (Join-Path $logRoot "01-build-android-x64-debug.log")

    $apkPath = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-debug.apk"

    Invoke-FlutterStep `
        -Name "whisper-base-native" `
        -Arguments @(
            "test",
            "integration_test/whisper_base_standard_asr_engine_test.dart",
            "-d",
            $resolvedDeviceId
        ) `
        -LogPath (Join-Path $logRoot "02-whisper-base-native.log")

    Install-And-GrantRecordingPermissions `
        -AdbPath $adb `
        -TargetDeviceId $resolvedDeviceId `
        -TargetApiLevel $apiLevel `
        -ApkPath $apkPath
    $recordingLogPath = Join-Path $logRoot "03-reliable-recording.log"
    Invoke-FlutterStep `
        -Name "reliable-recording" `
        -Arguments @(
            "test",
            "integration_test/reliable_recording_test.dart",
            "-d",
            $resolvedDeviceId,
            "--dart-define=MEETTRACE_RECORDING_SECONDS=$RecordingSeconds"
        ) `
        -LogPath $recordingLogPath

    $meetingFlowLogPath = Join-Path $logRoot "04-android-emulator-meeting-flow.log"
    Invoke-FlutterStep `
        -Name "android-emulator-meeting-flow" `
        -Arguments @(
            "test",
            "integration_test/android_emulator_meeting_flow_test.dart",
            "-d",
            $resolvedDeviceId,
            "--dart-define=MEETTRACE_NATIVE_LIFECYCLE_CYCLES=$NativeLifecycleCycles",
            "--dart-define=MEETTRACE_VAD_LIFECYCLE_CYCLES=$VadLifecycleCycles",
            "--dart-define=MEETTRACE_MEETING_LIFECYCLE_CYCLES=$MeetingLifecycleCycles"
        ) `
        -LogPath $meetingFlowLogPath

    $measurements = [ordered]@{
        recording = Read-JsonMarker `
            -LogPath $recordingLogPath `
            -Marker "MEETTRACE_STEP07_RECORDING:"
        meetingFlow = Read-JsonMarker `
            -LogPath $meetingFlowLogPath `
            -Marker "MEETTRACE_ANDROID_EMULATOR_FLOW:"
        asrLifecycle = Read-JsonMarker `
            -LogPath $meetingFlowLogPath `
            -Marker "MEETTRACE_ANDROID_NATIVE_CYCLES:"
        vadLifecycle = Read-JsonMarker `
            -LogPath $meetingFlowLogPath `
            -Marker "MEETTRACE_ANDROID_NATIVE_VAD:"
        recordingLifecycle = Read-JsonMarker `
            -LogPath $meetingFlowLogPath `
            -Marker "MEETTRACE_ANDROID_RECORDING_CYCLES:"
        meetingLifecycle = Read-JsonMarker `
            -LogPath $meetingFlowLogPath `
            -Marker "MEETTRACE_ANDROID_MEETING_CYCLES:"
    }

    $finishedAt = [DateTimeOffset]::UtcNow
    $report = [ordered]@{
        schemaVersion = 1
        status = "passed"
        startedAtUtc = $startedAt.ToString("O")
        finishedAtUtc = $finishedAt.ToString("O")
        elapsedMs = [long]($finishedAt - $startedAt).TotalMilliseconds
        platform = "android-emulator"
        abi = $abi
        apiLevel = $apiLevel
        recordingSeconds = $RecordingSeconds
        nativeLifecycleCycles = $NativeLifecycleCycles
        vadLifecycleCycles = $VadLifecycleCycles
        meetingLifecycleCycles = $MeetingLifecycleCycles
        results = $script:results
        measurements = $measurements
    }
    $reportPath = Join-Path $evidenceRoot "android-emulator-smoke.json"
    Write-JsonFile -Value $report -Path $reportPath
    $androidEvidenceRef = (
        Resolve-Path -LiteralPath $reportPath -Relative
    ) -replace "^[.][\\/]", ""
    $androidEvidenceRef = $androidEvidenceRef.Replace("\", "/")
    & dart run tool/benchmarks/build_phase_0_4_release_input.dart `
        --template $ReleaseInputPath `
        --android-evidence $reportPath `
        --android-evidence-ref $androidEvidenceRef `
        --output $ReleaseInputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to build the phase 0-4 release input."
    }
    & dart run tool/benchmarks/evaluate_alpha_release.dart `
        --input $ReleaseInputPath `
        --output $ReleaseReportPath
    $releaseExitCode = $LASTEXITCODE
    if ($releaseExitCode -eq 1) {
        throw "Phase 0-4 release evaluation found a failed gate."
    }
    if ($releaseExitCode -ne 0 -and $releaseExitCode -ne 2) {
        throw "Phase 0-4 release evaluation failed with exit code $releaseExitCode."
    }
    $smokeReportWritten = $true
    Write-Output "Android emulator evidence: $reportPath"
    Write-Output "Phase 0-4 release report: $ReleaseReportPath"
}
catch {
    if ($null -ne $evidenceRoot -and -not $smokeReportWritten) {
        $failureReport = [ordered]@{
            schemaVersion = 1
            status = "failed"
            capturedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
            error = $_.Exception.Message
            results = $script:results
        }
        $failurePath = Join-Path $evidenceRoot "android-emulator-smoke.json"
        Write-JsonFile -Value $failureReport -Path $failurePath
    }
    throw
}
finally {
    Pop-Location
}
