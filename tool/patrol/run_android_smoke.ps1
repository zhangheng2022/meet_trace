param(
    [switch]$AllowEmulator,
    [switch]$FullSuite,
    [switch]$PreserveAppData,
    [string]$DeviceId = $env:MEETTRACE_ANDROID_DEVICE_ID,
    [string]$JavaHome = $env:MEETTRACE_JAVA_HOME,
    [ValidateRange(1, 20)]
    [int]$RepeatCount = 1,
    [ValidateNotNullOrEmpty()]
    [string[]]$Targets = @(
        'patrol_test/harness_smoke_test.dart',
        'patrol_test/meeting_list_smoke_test.dart'
    )
)

$ErrorActionPreference = 'Stop'

$fullSuiteTargets = @(
    'patrol_test/harness_smoke_test.dart',
    'patrol_test/meeting_list_smoke_test.dart',
    'patrol_test/microphone_permission_recovery_test.dart',
    'patrol_test/meeting_golden_path_test.dart',
    'patrol_test/recording_continuity_test.dart'
)

if ($FullSuite) {
    if ($PSBoundParameters.ContainsKey('Targets')) {
        throw '-FullSuite 不能与 -Targets 同时使用。'
    }
    $Targets = $fullSuiteTargets
}

function Resolve-CompatibleJavaHome {
    param(
        [string]$PreferredHome,
        [string]$FlutterJavaHome
    )

    $candidateHomes = @(
        $PreferredHome,
        $env:JAVA_HOME,
        $FlutterJavaHome
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($candidateHome in $candidateHomes) {
        $java = Join-Path $candidateHome 'bin\java.exe'
        if (-not (Test-Path -LiteralPath $java)) {
            continue
        }

        $version = (& $java -version 2>&1 | Select-Object -First 1) -join ''
        if ($version -match 'version "(17|21)(\.|\")') {
            return (Resolve-Path -LiteralPath $candidateHome).Path
        }
    }

    throw 'Patrol 需要 JDK 17 或 21；请通过 -JavaHome 或 MEETTRACE_JAVA_HOME 指定安装目录。'
}

function Invoke-PatrolInstallerAction {
    param(
        [string]$Adb,
        [string]$Serial
    )

    $resumedActivity = (& $Adb -s $Serial shell dumpsys activity activities 2>$null) -join "`n"
    if ($resumedActivity -notmatch
        'topResumedActivity=.*com\.android\.packageinstaller') {
        return
    }

    $remoteDump = "/sdcard/meettrace-patrol-installer-$PID.xml"
    & $Adb -s $Serial shell uiautomator dump $remoteDump 2>$null | Out-Null
    $rawXml = (& $Adb -s $Serial shell cat $remoteDump 2>$null) -join ''
    if ([string]::IsNullOrWhiteSpace($rawXml)) {
        return
    }

    try {
        [xml]$window = $rawXml
    } catch {
        return
    }

    $nodes = @($window.SelectNodes('//node'))
    $hasExpectedTitle = $nodes | Where-Object {
        $_.GetAttribute('resource-id') -eq 'android:id/alertTitle' -and
            $_.GetAttribute('text') -in @('会迹', 'com.meettrace.app.test')
    }
    if (-not $hasExpectedTitle) {
        return
    }

    $isInstallConfirmation = $nodes | Where-Object {
        $_.GetAttribute('resource-id') -eq
            'com.android.packageinstaller:id/install_confirm_question'
    }
    $isInstallComplete = $nodes | Where-Object {
        $_.GetAttribute('resource-id') -eq
            'com.android.packageinstaller:id/install_success'
    }
    $buttonId = if ($isInstallConfirmation) {
        'android:id/button1'
    } elseif ($isInstallComplete) {
        'android:id/button2'
    } else {
        return
    }

    $button = $nodes | Where-Object {
        $_.GetAttribute('resource-id') -eq $buttonId -and
            $_.GetAttribute('enabled') -eq 'true' -and
            $_.GetAttribute('clickable') -eq 'true'
    } | Select-Object -First 1
    if ($null -eq $button) {
        return
    }

    $bounds = $button.GetAttribute('bounds')
    if ($bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
        return
    }

    $x = ([int]$Matches[1] + [int]$Matches[3]) / 2
    $y = ([int]$Matches[2] + [int]$Matches[4]) / 2
    & $Adb -s $Serial shell input tap $x $y | Out-Null
    if ($isInstallComplete) {
        Write-Output '已自动关闭 Patrol APK 安装完成框。'
    } else {
        Write-Output '已自动确认安装 Patrol APK。'
    }
}

function Reset-PatrolRuntimePermissions {
    param(
        [string]$Adb,
        [string]$Serial
    )

    & $Adb -s $Serial shell am force-stop com.meettrace.app 2>$null
    foreach ($permission in @(
            'android.permission.RECORD_AUDIO',
            'android.permission.POST_NOTIFICATIONS'
        )) {
        & $Adb -s $Serial shell pm revoke com.meettrace.app $permission 2>$null
        & $Adb -s $Serial shell pm clear-permission-flags `
            com.meettrace.app $permission user-set user-fixed 2>$null
    }
}

function Stop-ProcessTree {
    param([int]$RootProcessId)

    $processes = @(Get-CimInstance Win32_Process)
    $processIds = [System.Collections.Generic.List[int]]::new()
    $pendingIds = [System.Collections.Generic.Queue[int]]::new()
    $pendingIds.Enqueue($RootProcessId)
    while ($pendingIds.Count -gt 0) {
        $processId = $pendingIds.Dequeue()
        $processIds.Add($processId)
        $processes |
            Where-Object { $_.ParentProcessId -eq $processId } |
            ForEach-Object { $pendingIds.Enqueue([int]$_.ProcessId) }
    }

    $processIds.Reverse()
    foreach ($processId in $processIds) {
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    }
}

function Write-PatrolProcessLogs {
    param(
        [string]$StandardOutput,
        [string]$StandardError
    )

    foreach ($log in @($StandardOutput, $StandardError)) {
        if (Test-Path -LiteralPath $log) {
            Get-Content -LiteralPath $log | ForEach-Object { Write-Host $_ }
        }
    }
}

function Invoke-PatrolTest {
    param(
        [string]$Adb,
        [string]$Dart,
        [string]$Serial,
        [string]$Target,
        [bool]$KeepAppData
    )

    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $logDirectory = Join-Path $tempBase "meettrace-patrol-$([guid]::NewGuid())"
    $standardOutput = Join-Path $logDirectory 'stdout.log'
    $standardError = Join-Path $logDirectory 'stderr.log'
    New-Item -ItemType Directory -Path $logDirectory | Out-Null

    $process = $null
    try {
        $patrolArguments = @(
            'pub',
            'global',
            'run',
            'patrol_cli:main',
            'test',
            '--device',
            $Serial,
            '--target',
            $Target
        )
        if ($KeepAppData) {
            $patrolArguments += '--no-uninstall'
        }

        $process = Start-Process `
            -FilePath $Dart `
            -ArgumentList $patrolArguments `
            -WorkingDirectory (Get-Location).Path `
            -RedirectStandardOutput $standardOutput `
            -RedirectStandardError $standardError `
            -WindowStyle Hidden `
            -PassThru

        $disconnectedAt = $null
        $foregroundRequested = $false
        $reconnectRequested = $false
        while (-not $process.HasExited) {
            $deviceState = (& $Adb -s $Serial get-state 2>$null | Select-Object -First 1) -join ''
            if ($deviceState -ne 'device') {
                if ($null -eq $disconnectedAt) {
                    $disconnectedAt = [DateTime]::UtcNow
                }
                if (-not $reconnectRequested) {
                    $reconnectRequested = $true
                    & $Adb -s $Serial reconnect device 2>$null | Out-Null
                    Write-Host "ADB 连接波动，正在重连 Android 真机：$Serial"
                }
                if (([DateTime]::UtcNow - $disconnectedAt).TotalSeconds -ge 15) {
                    Stop-ProcessTree -RootProcessId $process.Id
                    throw "Android 真机已断开：$Serial"
                }
            } else {
                $disconnectedAt = $null
                $reconnectRequested = $false
                if ($KeepAppData -and
                    -not $foregroundRequested -and
                    (Test-Path -LiteralPath $standardOutput) -and
                    (Select-String `
                        -LiteralPath $standardOutput `
                        -Pattern 'Executing tests' `
                        -Quiet)) {
                    & $Adb -s $Serial shell am start `
                        -n 'com.meettrace.app/.MainActivity' | Out-Null
                    $foregroundRequested = $true
                    Write-Host '已将保留数据的会迹测试应用切回前台。'
                }
                Invoke-PatrolInstallerAction -Adb $Adb -Serial $Serial |
                    ForEach-Object { Write-Host $_ }
            }
            Start-Sleep -Milliseconds 500
            $process.Refresh()
        }

        $process.WaitForExit()
        Write-PatrolProcessLogs `
            -StandardOutput $standardOutput `
            -StandardError $standardError
        return $process.ExitCode
    } catch {
        Write-PatrolProcessLogs `
            -StandardOutput $standardOutput `
            -StandardError $standardError
        throw
    } finally {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-ProcessTree -RootProcessId $process.Id
        }
        & $Adb -s $Serial shell rm -f "/sdcard/meettrace-patrol-installer-$PID.xml" `
            2>$null | Out-Null

        $resolvedLogDirectory = [IO.Path]::GetFullPath($logDirectory)
        if ($resolvedLogDirectory.StartsWith($tempBase) -and
            (Split-Path -Leaf $resolvedLogDirectory).StartsWith('meettrace-patrol-')) {
            Remove-Item -LiteralPath $resolvedLogDirectory -Recurse -Force
        }
    }
}

$flutterConfig = flutter config --machine | ConvertFrom-Json
$androidSdk = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else {
    $flutterConfig.'android-sdk'
}

if ([string]::IsNullOrWhiteSpace($androidSdk)) {
    throw '未找到 Android SDK；请先运行 flutter config --android-sdk <path>。'
}

$JavaHome = Resolve-CompatibleJavaHome `
    -PreferredHome $JavaHome `
    -FlutterJavaHome $flutterConfig.'jdk-dir'
$configuredFlutterJavaHome = $flutterConfig.'jdk-dir'
if ([string]::IsNullOrWhiteSpace($configuredFlutterJavaHome) -or
    -not (Test-Path -LiteralPath $configuredFlutterJavaHome) -or
    (Resolve-Path -LiteralPath $configuredFlutterJavaHome).Path -ne $JavaHome) {
    throw "Flutter 未使用目标 JDK；请先运行 flutter config --jdk-dir `"$JavaHome`"。"
}

$adbDirectory = Join-Path $androidSdk 'platform-tools'
$adb = Join-Path $adbDirectory 'adb.exe'
$patrolDirectory = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin'
$patrol = Join-Path $patrolDirectory 'patrol.bat'
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterRoot = (Resolve-Path -LiteralPath (
        Join-Path (Split-Path -Parent $flutterCommand.Source) '..'
    )).Path
$dart = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'

if (-not (Test-Path -LiteralPath $patrol)) {
    throw '未找到 Patrol CLI；请运行 dart pub global activate patrol_cli 4.6.1。'
}
if (-not (Test-Path -LiteralPath $dart)) {
    throw "未找到 Flutter 内置 Dart：$dart"
}

$env:ANDROID_HOME = $androidSdk
$env:JAVA_HOME = $JavaHome
$env:CI = 'true'
$env:PATROL_ANALYTICS_ENABLED = 'false'
$env:Path = "$(Join-Path $JavaHome 'bin');$adbDirectory;$patrolDirectory;$env:Path"

$devices = @(flutter devices --machine | ConvertFrom-Json)

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $candidateAndroidDevices = @(
        $devices | Where-Object {
            $_.targetPlatform -like 'android-*' -and
                ($AllowEmulator -or
                    ($_.targetPlatform -eq 'android-arm64' -and -not $_.emulator))
        }
    )
    if ($candidateAndroidDevices.Count -ne 1) {
        throw '请通过 -DeviceId 或 MEETTRACE_ANDROID_DEVICE_ID 指定唯一的目标 Android 设备。'
    }
    $DeviceId = $candidateAndroidDevices[0].id
}

$selectedDevice = $devices | Where-Object { $_.id -eq $DeviceId } | Select-Object -First 1
if ($null -eq $selectedDevice) {
    throw "未找到设备：$DeviceId"
}
if ($selectedDevice.targetPlatform -notlike 'android-*') {
    throw "设备必须是 Android：$DeviceId"
}
if (-not $AllowEmulator -and
    ($selectedDevice.targetPlatform -ne 'android-arm64' -or $selectedDevice.emulator)) {
    throw "设备必须是 Android arm64 真机：$DeviceId"
}

Write-Host "使用设备：$($selectedDevice.name) ($DeviceId)"
Write-Host "使用 JDK：$JavaHome"

& $patrol doctor
if ($LASTEXITCODE -ne 0) {
    throw "Patrol doctor 失败，退出码：$LASTEXITCODE"
}

# 当前 OnePlus Android 16 真机无法连接 AndroidX Test Orchestrator。
# 每个文件独立启动 instrumentation，避免前一条原生用例结束后污染下一条。
$originalStayAwake = (& $adb -s $DeviceId shell settings get global stay_on_while_plugged_in).Trim()
try {
    & $adb -s $DeviceId shell settings put global stay_on_while_plugged_in 2 | Out-Null
    & $adb -s $DeviceId shell input keyevent KEYCODE_WAKEUP | Out-Null
    & $adb -s $DeviceId shell wm dismiss-keyguard | Out-Null

    for ($run = 1; $run -le $RepeatCount; $run++) {
        Write-Host "Patrol Android 测试：第 $run/$RepeatCount 轮"
        foreach ($target in $Targets) {
            if ($PreserveAppData) {
                Reset-PatrolRuntimePermissions -Adb $adb -Serial $DeviceId
            }
            $patrolExitCode = Invoke-PatrolTest `
                -Adb $adb `
                -Dart $dart `
                -Serial $DeviceId `
                -Target $target `
                -KeepAppData $PreserveAppData
            if ($patrolExitCode -ne 0) {
                throw "Patrol 真机测试失败：$target，退出码：$patrolExitCode"
            }
        }
    }
} finally {
    $deviceState = (& $adb -s $DeviceId get-state 2>$null | Select-Object -First 1) -join ''
    if ($deviceState -eq 'device') {
        if ([string]::IsNullOrWhiteSpace($originalStayAwake) -or
            $originalStayAwake -eq 'null') {
            & $adb -s $DeviceId shell settings delete global stay_on_while_plugged_in |
                Out-Null
        } else {
            & $adb -s $DeviceId shell settings put global stay_on_while_plugged_in `
                $originalStayAwake | Out-Null
        }
    } else {
        Write-Warning '设备已断开，无法恢复运行前的 USB 常亮设置。'
    }
}
