<#
.SYNOPSIS
    Repacks Masterwork content modules into .mwm bundles, with optional semver version bumping.

.DESCRIPTION
    Wraps Masterwork.ModulePacker (in the Masterwork code repo) to rebuild {module}.mwm at this
    repo's root from each module directory's current contents. Run this any time module content
    changes and you want the packaged bundle to reflect it — packaging is a pure repackaging step,
    it never re-runs extraction or validates content (see ModulePackage.WriteToBytes in the code
    repo, and this repo's own CLAUDE.md "Bundling" section).

.PARAMETER Module
    Repack only this module (a directory name at the repo root, e.g. 'cost-of-disease'). If
    omitted, every module directory (anything containing a manifest.yaml) is repacked.

.PARAMETER IncrementVersion
    Bump the module's manifest.yaml 'version' field before repacking, using semver rules: 'patch'
    increments the patch number; 'minor' increments minor and resets patch to 0; 'major' increments
    major and resets minor+patch to 0. Requires -Module — bumping every module's version in one
    pass is never what you want.

.PARAMETER CodeRepoPath
    Path to the Masterwork code repo (holds Masterwork.ModulePacker). Defaults to the sibling-repo
    layout documented in this repo's CLAUDE.md ('..\Masterwork' relative to this repo's root).

.EXAMPLE
    .\scripts\repack.ps1
    Repacks every module.

.EXAMPLE
    .\scripts\repack.ps1 -Module cost-of-disease -IncrementVersion patch
    Bumps cost-of-disease's version (e.g. 0.1.0 -> 0.1.1) and repacks it.

.EXAMPLE
    .\scripts\repack.ps1 -Module my-fathers-work-template -WhatIf
    Previews what would happen without writing anything.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Module,

    [ValidateSet('major', 'minor', 'patch')]
    [string]$IncrementVersion,

    [string]$CodeRepoPath = (Join-Path $PSScriptRoot '..' '..' 'Masterwork')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$packerProject = Join-Path $CodeRepoPath 'src' 'Masterwork.ModulePacker'

if ($IncrementVersion -and -not $Module) {
    throw "-IncrementVersion requires -Module (bumping every module's version in one pass is not supported)."
}

if (-not (Test-Path $packerProject)) {
    throw "Masterwork.ModulePacker project not found at '$packerProject'. Pass -CodeRepoPath if the code repo isn't a sibling of this one."
}

function Get-ModuleDirectories {
    if ($Module) {
        $dir = Join-Path $repoRoot $Module
        if (-not (Test-Path (Join-Path $dir 'manifest.yaml'))) {
            throw "No manifest.yaml found under '$dir'."
        }
        return , (Get-Item -LiteralPath $dir)
    }

    return Get-ChildItem -Path $repoRoot -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName 'manifest.yaml')
    }
}

function Step-Version {
    param([string]$Version, [string]$Part)

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Version '$Version' is not in major.minor.patch form."
    }
    $majorN = [int]$Matches[1]
    $minorN = [int]$Matches[2]
    $patchN = [int]$Matches[3]

    switch ($Part) {
        'major' { $majorN++; $minorN = 0; $patchN = 0 }
        'minor' { $minorN++; $patchN = 0 }
        'patch' { $patchN++ }
    }

    return "$majorN.$minorN.$patchN"
}

function Update-ManifestVersion {
    param([string]$ManifestPath, [string]$Part)

    $text = Get-Content -Raw -LiteralPath $ManifestPath
    if ($text -notmatch "(?m)^version:\s*(['`"])(?<version>[^'`"]+)\1") {
        throw "Could not find a quoted 'version:' line in $ManifestPath."
    }
    $quote = $Matches[1]
    $oldVersion = $Matches['version']
    $newVersion = Step-Version -Version $oldVersion -Part $Part

    if ($PSCmdlet.ShouldProcess($ManifestPath, "Bump version $oldVersion -> $newVersion")) {
        $pattern = "(?m)^version:\s*$quote[^$quote]+$quote"
        $replacement = "version: $quote$newVersion$quote"
        Set-Content -LiteralPath $ManifestPath -Value ($text -replace $pattern, $replacement) -NoNewline
        Write-Host "  version: $oldVersion -> $newVersion"
    }
}

foreach ($dir in Get-ModuleDirectories) {
    Write-Host "$($dir.Name):"

    if ($IncrementVersion) {
        Update-ManifestVersion -ManifestPath (Join-Path $dir.FullName 'manifest.yaml') -Part $IncrementVersion
    }

    $outputPath = Join-Path $repoRoot "$($dir.Name).mwm"
    if ($PSCmdlet.ShouldProcess($outputPath, "Repack from $($dir.FullName)")) {
        & dotnet run --project $packerProject -- $dir.FullName $outputPath
        if ($LASTEXITCODE -ne 0) {
            throw "Packing failed for $($dir.Name)."
        }
    }
}
