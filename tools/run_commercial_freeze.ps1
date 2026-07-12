[CmdletBinding()]
param(
    [string]$Godot = $(if ($env:FAIRYGUI_GODOT_EXE) { $env:FAIRYGUI_GODOT_EXE } else { 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' }),
    [switch]$SkipExports,
    [switch]$KeepExistingArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.commercial-freeze'))
$projectPrefix = $projectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
if (-not $artifactRoot.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Artifact path escaped the project root: $artifactRoot"
}
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable not found: $Godot"
}
if ((Test-Path -LiteralPath $artifactRoot) -and -not $KeepExistingArtifacts) {
    Remove-Item -LiteralPath $artifactRoot -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $artifactRoot -Force
$logRoot = Join-Path $artifactRoot 'logs'
$null = New-Item -ItemType Directory -Path $logRoot -Force

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Category,
        [string]$Name,
        [ValidateSet('PASS', 'WARN', 'FAIL', 'SKIP')]
        [string]$Status,
        [long]$DurationMs,
        [string]$Details = ''
    )
    $results.Add([pscustomobject]@{
        category = $Category
        name = $Name
        status = $Status
        duration_ms = $DurationMs
        details = $Details
    })
    Write-Host ('{0,-4} {1}/{2} ({3} ms) {4}' -f $Status, $Category, $Name, $DurationMs, $Details)
}

function Invoke-NativeProcess {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [int]$TimeoutMs = 45000,
        [bool]$HiddenWindow = $false
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    $psi.WorkingDirectory = $projectRoot
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    if ($HiddenWindow) {
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $null = $psi.ArgumentList.Add($argument)
    }
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutMs)
    if ($timedOut) {
        $process.Kill($true)
        $null = $process.WaitForExit(5000)
    }
    [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
    $stopwatch.Stop()
    return [pscustomobject]@{
        exit_code = $(if ($timedOut) { -1 } else { $process.ExitCode })
        timed_out = $timedOut
        duration_ms = $stopwatch.ElapsedMilliseconds
        output = $stdoutTask.Result + $stderrTask.Result
    }
}

function Get-UnexpectedDiagnostics {
    param(
        [string]$Output,
        [string[]]$AllowedErrorPatterns = @()
    )
    $unexpected = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Output -split "`r?`n")) {
        if ($line -notmatch '^(SCRIPT ERROR|ERROR:)|Parse Error|CrashHandlerException|FATAL') {
            continue
        }
        $allowed = $false
        foreach ($pattern in $AllowedErrorPatterns) {
            if ($line -match $pattern) {
                $allowed = $true
                break
            }
        }
        if (-not $allowed) {
            $unexpected.Add($line)
        }
    }
    return $unexpected.ToArray()
}

function Save-StepLog {
    param([string]$Name, [string]$Output)
    $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
    [System.IO.File]::WriteAllText((Join-Path $logRoot "$safeName.log"), $Output, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-GodotStep {
    param(
        [string]$Category,
        [string]$Name,
        [string[]]$Arguments,
        [int]$TimeoutMs = 45000,
        [bool]$HiddenWindow = $false,
        [string[]]$AllowedErrorPatterns = @(),
        [bool]$AllowNonZeroExit = $false
    )
    try {
        $run = Invoke-NativeProcess -FileName $Godot -Arguments $Arguments -TimeoutMs $TimeoutMs -HiddenWindow $HiddenWindow
        Save-StepLog -Name "$Category-$Name" -Output $run.output
        $diagnostics = @(Get-UnexpectedDiagnostics -Output $run.output -AllowedErrorPatterns $AllowedErrorPatterns)
        if ($run.timed_out) {
            Add-Result $Category $Name 'FAIL' $run.duration_ms 'Timed out.'
            return $false
        }
        if ((-not $AllowNonZeroExit -and $run.exit_code -ne 0) -or $diagnostics.Count -gt 0) {
            $detail = "Exit $($run.exit_code)."
            if ($diagnostics.Count -gt 0) {
                $detail += ' ' + ($diagnostics -join ' | ')
            }
            Add-Result $Category $Name 'FAIL' $run.duration_ms $detail
            return $false
        }
        Add-Result $Category $Name 'PASS' $run.duration_ms
        return $true
    } catch {
        Add-Result $Category $Name 'FAIL' 0 $_.Exception.Message
        return $false
    }
}

function Add-ArtifactCheck {
    param(
        [string]$Name,
        [string[]]$Paths,
        [string]$Details = ''
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $missing = @($Paths | Where-Object { -not (Test-Path -LiteralPath $_) })
    $stopwatch.Stop()
    if ($missing.Count -gt 0) {
        Add-Result 'artifact' $Name 'FAIL' $stopwatch.ElapsedMilliseconds ('Missing: ' + ($missing -join ', '))
        return $false
    }
    Add-Result 'artifact' $Name 'PASS' $stopwatch.ElapsedMilliseconds $Details
    return $true
}

$versionRun = Invoke-NativeProcess -FileName $Godot -Arguments @('--version') -TimeoutMs 10000
$godotVersion = ($versionRun.output -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
if ($versionRun.exit_code -eq 0 -and $godotVersion -ne '') {
    Add-Result 'environment' 'Godot version' 'PASS' $versionRun.duration_ms $godotVersion
} else {
    Add-Result 'environment' 'Godot version' 'FAIL' $versionRun.duration_ms "Exit $($versionRun.exit_code)."
}

$null = Invoke-GodotStep -Category 'compile' -Name 'FairyGUI preload graph' -Arguments @(
    '--headless', '--path', $projectRoot, '--check-only', '--script', 'res://addons/fairygui/fairygui.gd'
)
$null = Invoke-GodotStep -Category 'editor' -Name 'Resource import' -Arguments @(
    '--headless', '--editor', '--import', '--path', $projectRoot, '--quit-after', '3'
) -TimeoutMs 120000

$headlessExcluded = @('demo_render_probe.gd', 'editor_hint_preview_probe.gd', 'mask_probe.gd', 'render_parity_probe.gd')
$headlessTests = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*_probe.gd' |
    Where-Object { $headlessExcluded -notcontains $_.Name } |
    Sort-Object Name
$headlessTests += Get-Item -LiteralPath (Join-Path $projectRoot 'tests\smoke_test.gd')
foreach ($test in $headlessTests) {
    $null = Invoke-GodotStep -Category 'headless' -Name $test.Name -Arguments @(
        '--headless', '--path', $projectRoot, '--script', "res://tests/$($test.Name)"
    )
}

$editorLeakPatterns = @(
    '^ERROR: \d+ RID allocations of type .* were leaked at exit\.$',
    '^ERROR: \d+ resources still in use at exit'
)
$null = Invoke-GodotStep -Category 'editor' -Name 'Inspector FUI preview' -Arguments @(
    '--headless', '--editor', '--path', $projectRoot, '--script', 'res://tests/editor_hint_preview_probe.gd'
) -TimeoutMs 60000 -AllowedErrorPatterns $editorLeakPatterns -AllowNonZeroExit $true

$renderConfigurations = @(
    @{ name = 'Compatibility'; driver = 'opengl3'; method = 'gl_compatibility' },
    @{ name = 'Mobile'; driver = 'd3d12'; method = 'mobile' },
    @{ name = 'ForwardPlus'; driver = 'd3d12'; method = 'forward_plus' }
)
foreach ($configuration in $renderConfigurations) {
    foreach ($testName in @('render_parity_probe.gd', 'mask_probe.gd', 'demo_render_probe.gd')) {
        $null = Invoke-GodotStep -Category 'render' -Name "$($configuration.name)-$testName" -Arguments @(
            '--display-driver', 'windows',
            '--rendering-driver', $configuration.driver,
            '--rendering-method', $configuration.method,
            '--path', $projectRoot,
            '--script', "res://tests/$testName"
        ) -TimeoutMs 60000 -HiddenWindow $true
    }
}

$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$presetTemplate = Join-Path $PSScriptRoot 'commercial_export_presets.cfg'
$presetBackup = Join-Path $artifactRoot 'export_presets.backup.cfg'
$hadPreset = Test-Path -LiteralPath $presetPath
if ($hadPreset) {
    Copy-Item -LiteralPath $presetPath -Destination $presetBackup -Force
}

try {
    if ($SkipExports) {
        Add-Result 'export' 'Platform exports' 'SKIP' 0 'Skipped by command-line option.'
    } else {
        $templateVersion = if ($godotVersion -match '^(\d+\.\d+\.[A-Za-z0-9_]+)') { $Matches[1] } else { '' }
        $templateRoot = if ($templateVersion -ne '') { Join-Path $env:APPDATA "Godot\export_templates\$templateVersion" } else { '' }
        if ($templateRoot -eq '' -or -not (Test-Path -LiteralPath (Join-Path $templateRoot 'version.txt'))) {
            Add-Result 'environment' 'Export templates' 'FAIL' 0 "Missing templates for $templateVersion."
        } else {
            Add-Result 'environment' 'Export templates' 'PASS' 0 $templateRoot
            Copy-Item -LiteralPath $presetTemplate -Destination $presetPath -Force

            $exports = @(
                @{ name = 'Windows'; preset = 'Freeze Windows'; output = (Join-Path $artifactRoot 'windows\FairyGUI-Godot.exe'); timeout = 180000 },
                @{ name = 'Linux'; preset = 'Freeze Linux'; output = (Join-Path $artifactRoot 'linux\FairyGUI-Godot.x86_64'); timeout = 180000 },
                @{ name = 'Web'; preset = 'Freeze Web'; output = (Join-Path $artifactRoot 'web\index.html'); timeout = 180000 },
                @{ name = 'Android'; preset = 'Freeze Android'; output = (Join-Path $artifactRoot 'android\FairyGUI-Godot.apk'); timeout = 300000 },
                @{ name = 'macOS'; preset = 'Freeze macOS'; output = (Join-Path $artifactRoot 'macos\FairyGUI-Godot.zip'); timeout = 300000 },
                @{ name = 'iOS project'; preset = 'Freeze iOS'; output = (Join-Path $artifactRoot 'ios\FairyGUI-Godot'); timeout = 300000 }
            )
            foreach ($export in $exports) {
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $export.output) -Force
                $null = Invoke-GodotStep -Category 'export' -Name $export.name -Arguments @(
                    '--headless', '--path', $projectRoot, '--export-debug', $export.preset, $export.output
                ) -TimeoutMs $export.timeout
            }

            $windowsDir = Join-Path $artifactRoot 'windows'
            $windowsExe = Join-Path $windowsDir 'FairyGUI-Godot.exe'
            $windowsConsole = Join-Path $windowsDir 'FairyGUI-Godot.console.exe'
            $null = Add-ArtifactCheck -Name 'Windows bundle' -Paths @(
                $windowsExe,
                $windowsConsole,
                (Join-Path $windowsDir 'FairyGUI-Godot.pck')
            )
            if (Test-Path -LiteralPath $windowsConsole) {
                $runtime = Invoke-NativeProcess -FileName $windowsConsole -Arguments @(
                    '--headless', '--', '--fairygui-export-smoke'
                ) -TimeoutMs 60000
                Save-StepLog -Name 'runtime-Windows-export-smoke' -Output $runtime.output
                $runtimeDiagnostics = @(Get-UnexpectedDiagnostics -Output $runtime.output)
                if (-not $runtime.timed_out -and $runtime.exit_code -eq 0 -and $runtimeDiagnostics.Count -eq 0) {
                    Add-Result 'runtime' 'Windows exported package smoke' 'PASS' $runtime.duration_ms
                } else {
                    Add-Result 'runtime' 'Windows exported package smoke' 'FAIL' $runtime.duration_ms "Exit $($runtime.exit_code). $($runtimeDiagnostics -join ' | ')"
                }
            }

            $null = Add-ArtifactCheck -Name 'Linux bundle' -Paths @(
                (Join-Path $artifactRoot 'linux\FairyGUI-Godot.x86_64'),
                (Join-Path $artifactRoot 'linux\FairyGUI-Godot.pck')
            )
            $null = Add-ArtifactCheck -Name 'Web bundle' -Paths @(
                (Join-Path $artifactRoot 'web\index.html'),
                (Join-Path $artifactRoot 'web\index.js'),
                (Join-Path $artifactRoot 'web\index.wasm'),
                (Join-Path $artifactRoot 'web\index.pck')
            )
            $null = Add-ArtifactCheck -Name 'Android APK' -Paths @(
                (Join-Path $artifactRoot 'android\FairyGUI-Godot.apk')
            ) -Details 'Debug-signed arm64 APK.'
            $null = Add-ArtifactCheck -Name 'macOS bundle' -Paths @(
                (Join-Path $artifactRoot 'macos\FairyGUI-Godot.zip')
            ) -Details 'Unsigned universal archive.'
            $null = Add-ArtifactCheck -Name 'iOS Xcode project' -Paths @(
                (Join-Path $artifactRoot 'ios\FairyGUI-Godot.xcodeproj\project.pbxproj'),
                (Join-Path $artifactRoot 'ios\FairyGUI-Godot.pck')
            ) -Details 'Project generated on Windows; Xcode build and signing require macOS.'
        }
    }
} finally {
    if ($hadPreset -and (Test-Path -LiteralPath $presetBackup)) {
        Copy-Item -LiteralPath $presetBackup -Destination $presetPath -Force
    } elseif (-not $hadPreset -and (Test-Path -LiteralPath $presetPath)) {
        Remove-Item -LiteralPath $presetPath -Force
    }
}

$summary = [ordered]@{
    generated_at = [DateTime]::UtcNow.ToString('o')
    project_root = $projectRoot
    godot = $Godot
    godot_version = $godotVersion
    pass = @($results | Where-Object status -eq 'PASS').Count
    warn = @($results | Where-Object status -eq 'WARN').Count
    fail = @($results | Where-Object status -eq 'FAIL').Count
    skip = @($results | Where-Object status -eq 'SKIP').Count
    results = $results
}
$jsonPath = Join-Path $artifactRoot 'results.json'
[System.IO.File]::WriteAllText($jsonPath, ($summary | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

$markdown = [System.Collections.Generic.List[string]]::new()
$markdown.Add('# FairyGUI Godot Commercial Freeze Results')
$markdown.Add('')
$markdown.Add("- Generated: $($summary.generated_at)")
$markdown.Add("- Godot: $godotVersion")
$markdown.Add("- PASS: $($summary.pass); WARN: $($summary.warn); FAIL: $($summary.fail); SKIP: $($summary.skip)")
$markdown.Add('')
$markdown.Add('| Status | Category | Check | Duration | Details |')
$markdown.Add('| --- | --- | --- | ---: | --- |')
foreach ($result in $results) {
    $details = ([string]$result.details).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
    $name = ([string]$result.name).Replace('|', '\|')
    $markdown.Add("| $($result.status) | $($result.category) | $name | $($result.duration_ms) ms | $details |")
}
$reportPath = Join-Path $artifactRoot 'report.md'
[System.IO.File]::WriteAllLines($reportPath, $markdown, [System.Text.UTF8Encoding]::new($false))

Write-Host "Results: $jsonPath"
Write-Host "Report:  $reportPath"
if ($summary.fail -gt 0) {
    exit 1
}
exit 0
