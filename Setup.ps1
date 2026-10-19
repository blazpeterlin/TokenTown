#requires -Version 7.0
<#
.SYNOPSIS
Installs the standalone Windows Copilot sandbox baseline, MCP servers, skills, and instructions.
.EXAMPLE
.\Setup.ps1 -WhatIf
.EXAMPLE
.\Setup.ps1
.EXAMPLE
.\Setup.ps1 -Check
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $TargetDirectory = $(if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { [IO.Path]::Combine($HOME, '.copilot') }),
    [string] $WorkspaceRoot = 'D:\GeniRepos',
    [string[]] $ReadOnlyRoots = @('C:\', 'D:\'),
    [switch] $Check,
    [string] $PackageDirectory = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows) { throw 'This setup requires Windows.' }
if (-not [IO.Path]::IsPathFullyQualified($TargetDirectory)) { throw 'TargetDirectory must be an absolute path.' }
if (-not [IO.Path]::IsPathFullyQualified($WorkspaceRoot)) { throw 'WorkspaceRoot must be an absolute path.' }
foreach ($path in $ReadOnlyRoots) {
    if (-not [IO.Path]::IsPathFullyQualified($path)) { throw 'ReadOnlyRoots must contain absolute paths.' }
}
$TargetDirectory = [IO.Path]::GetFullPath($TargetDirectory)
$PackageDirectory = [IO.Path]::GetFullPath($PackageDirectory)

function Read-JsonObject([string] $Path) {
    if (-not [IO.File]::Exists($Path)) { return @{} }
    $value = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) -AsHashtable -Depth 100
    if ($value -isnot [System.Collections.IDictionary]) { throw "Expected a JSON object in $Path." }
    return $value
}

function ConvertTo-CanonicalJson($Value) {
    if ($Value -is [System.Collections.IDictionary]) {
        $sorted = [ordered]@{}
        foreach ($key in ($Value.Keys | Sort-Object)) {
            $sorted[$key] = ConvertTo-CanonicalJson $Value[$key]
        }
        return $sorted
    }
    if ($Value -is [array]) {
        return ,@($Value | ForEach-Object { ConvertTo-CanonicalJson $_ })
    }
    return $Value
}

function Get-JsonFingerprint($Value) {
    return ConvertTo-Json -InputObject (ConvertTo-CanonicalJson $Value) -Depth 100 -Compress
}

# Build the entire write list before touching the target. Invalid configuration fails without partial installation.
$writes = [Collections.Generic.List[object]]::new()
function Add-FileWrite([string] $RelativePath, [byte[]] $Bytes) {
    $targetPath = [IO.Path]::Combine($TargetDirectory, $RelativePath)
    if ([IO.File]::Exists($targetPath)) {
        $existing = [Convert]::ToBase64String([IO.File]::ReadAllBytes($targetPath))
        if ($existing -ceq [Convert]::ToBase64String($Bytes)) { return }
    }
    $writes.Add([pscustomobject]@{ RelativePath = $RelativePath; Path = $targetPath; Bytes = $Bytes })
}

$settingsPath = [IO.Path]::Combine($TargetDirectory, 'settings.json')
$settings = Read-JsonObject $settingsPath
$beforeSettings = Get-JsonFingerprint $settings
$baseline = Read-JsonObject ([IO.Path]::Combine($PackageDirectory, 'settings.json'))
if (-not $baseline.Contains('sandbox')) { throw 'The settings template is incomplete.' }
$baseline.sandbox.userPolicy.filesystem.readwritePaths = @([IO.Path]::Combine($TargetDirectory, 'session-state'))
if ([IO.Directory]::Exists($WorkspaceRoot)) {
    $baseline.sandbox.userPolicy.filesystem.readwritePaths = @($WorkspaceRoot) + $baseline.sandbox.userPolicy.filesystem.readwritePaths
} else {
    Write-Host "Workspace directory '$WorkspaceRoot' does not exist; omitting its read/write grant."
}
$baseline.sandbox.userPolicy.filesystem.readonlyPaths = @($ReadOnlyRoots)
foreach ($key in $baseline.Keys) { $settings[$key] = $baseline[$key] }
if ($beforeSettings -cne (Get-JsonFingerprint $settings)) {
    $text = (ConvertTo-Json -InputObject $settings -Depth 100) + [Environment]::NewLine
    Add-FileWrite 'settings.json' ([Text.UTF8Encoding]::new($false).GetBytes($text))
}

$mcpPath = [IO.Path]::Combine($TargetDirectory, 'mcp-config.json')
$mcp = Read-JsonObject $mcpPath
$beforeMcp = Get-JsonFingerprint $mcp
if (-not $mcp.Contains('mcpServers')) { $mcp['mcpServers'] = @{} }
if ($mcp.mcpServers -isnot [System.Collections.IDictionary]) { throw "mcpServers must be an object in $mcpPath." }
$mcpBaseline = Read-JsonObject ([IO.Path]::Combine($PackageDirectory, 'mcp-config.json'))
if (-not $mcpBaseline.Contains('mcpServers')) { throw 'The MCP template is incomplete.' }
# Replace each managed server in full: merging could retain a wildcard or incompatible HTTP/authentication settings.
foreach ($name in $mcpBaseline.mcpServers.Keys) { $mcp.mcpServers[$name] = $mcpBaseline.mcpServers[$name] }
if ($beforeMcp -cne (Get-JsonFingerprint $mcp)) {
    $text = (ConvertTo-Json -InputObject $mcp -Depth 100) + [Environment]::NewLine
    Add-FileWrite 'mcp-config.json' ([Text.UTF8Encoding]::new($false).GetBytes($text))
}

# config.json is CLI-managed state: only append the workspace to trustedFolders, never rewrite other entries.
$configPath = [IO.Path]::Combine($TargetDirectory, 'config.json')
$config = Read-JsonObject $configPath
$trusted = if ($config.Contains('trustedFolders')) { @($config.trustedFolders | Where-Object { $_ }) } else { @() }
$trustedRoot = 'D:\GeniRepos'
if (-not ($trusted | Where-Object { "$_".TrimEnd('\') -ieq $trustedRoot })) {
    $config['trustedFolders'] = @($trusted) + $trustedRoot
    $text = (ConvertTo-Json -InputObject $config -Depth 100) + [Environment]::NewLine
    Add-FileWrite 'config.json' ([Text.UTF8Encoding]::new($false).GetBytes($text))
}

$skillsRoot = [IO.Path]::Combine($PackageDirectory, 'skills')
foreach ($skillDir in [IO.Directory]::GetDirectories($skillsRoot)) {
    if (-not [IO.File]::Exists([IO.Path]::Combine($skillDir, 'SKILL.md'))) { throw "Missing SKILL.md in $skillDir." }
    foreach ($sourcePath in [IO.Directory]::GetFiles($skillDir, '*', [IO.SearchOption]::AllDirectories)) {
        $relativePath = [IO.Path]::GetRelativePath($skillsRoot, $sourcePath)
        Add-FileWrite ([IO.Path]::Combine('skills', $relativePath)) ([IO.File]::ReadAllBytes($sourcePath))
    }
}

$localReposTemplate = [IO.File]::ReadAllText([IO.Path]::Combine($PackageDirectory, 'instructions', 'local-repos.instructions.md'))
$localReposText = $localReposTemplate.Replace('{{WorkspaceRoot}}', $WorkspaceRoot.TrimEnd('\'))
Add-FileWrite 'instructions\local-repos.instructions.md' ([Text.UTF8Encoding]::new($false).GetBytes($localReposText))

$sourcePath = [IO.Path]::Combine($PackageDirectory, 'instructions', 'logging.instructions.md')
Add-FileWrite 'instructions\logging.instructions.md' ([IO.File]::ReadAllBytes($sourcePath))

$gitSourcePath = [IO.Path]::Combine($PackageDirectory, 'instructions', 'git.instructions.md')
Add-FileWrite 'instructions\git.instructions.md' ([IO.File]::ReadAllBytes($gitSourcePath))

Write-Host "Target: $TargetDirectory"
foreach ($write in $writes) {
    $label = if ($Check) { 'Would have updated' } elseif ($WhatIfPreference) { 'Would update' } else { 'Updating' }
    Write-Host "$label [$($write.RelativePath)]"
}
if ($Check) {
    if ($writes.Count -gt 0) { throw "Configuration drift: $($writes.Count) file(s) need updating." }
    Write-Host 'All selected setup files match.'
    return
}
if ($writes.Count -eq 0) {
    Write-Host 'Already configured; no changes.'
    return
}

$backupRoot = [IO.Path]::Combine($TargetDirectory, 'setup-backups', [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ'))
foreach ($write in $writes) {
    if ($PSCmdlet.ShouldProcess($write.Path, 'Back up existing file and install managed configuration')) {
        if ([IO.File]::Exists($write.Path)) {
            $backupPath = [IO.Path]::Combine($backupRoot, $write.RelativePath)
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backupPath))
            [IO.File]::Copy($write.Path, $backupPath, $false)
        }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($write.Path))
        [IO.File]::WriteAllBytes($write.Path, $write.Bytes)
    }
}
if (-not $WhatIfPreference) {
    Write-Host 'Setup applied. Existing files were backed up under setup-backups. Restart Copilot CLI and authenticate MCP interactively.'
}
