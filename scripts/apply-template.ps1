<#
.SYNOPSIS
    Copies my-fathers-work-template's shared style/layout/setup/scoring content into a real module.

.DESCRIPTION
    Mechanical copy only, covering exactly: assets/style.css, assets/fonts/, every layouts/*.mws.yaml
    chrome file, and the setup (_Setup_0N_*.mws.yaml) + scoring (score entry/tie-break/ranking)
    passages, landing in the target's passages-override/ folder. Never touches passages/
    (extractor-owned), _variables.yaml, en-US.restext, manifest.yaml, or .source/ — see the module
    ownership table in this repo's CLAUDE.md.

    This is the mechanical half of "harvest the template's design back into a real module" — a
    `git diff` + manual reconciliation inside the target module is still expected afterward for
    anything it had already customized on top of the template's generic version (e.g.
    cost-of-disease's scoring passages carry real per-scenario logic by now). See this repo's
    my-fathers-work-template/README.md for the full workflow.

.PARAMETER TargetModule
    Directory name of the module to copy into (e.g. 'cost-of-disease'), relative to this repo's root.

.PARAMETER TemplateModule
    Directory name of the source template module. Defaults to 'my-fathers-work-template'.

.EXAMPLE
    .\scripts\apply-template.ps1 -TargetModule cost-of-disease -WhatIf
    Previews what would be copied without touching anything.

.EXAMPLE
    .\scripts\apply-template.ps1 -TargetModule cost-of-disease
    Copies for real. Follow up with `git diff` inside cost-of-disease/ before committing.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$TargetModule,

    [string]$TemplateModule = 'my-fathers-work-template'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repoRoot $TemplateModule
$dst = Join-Path $repoRoot $TargetModule

if (-not (Test-Path (Join-Path $src 'manifest.yaml'))) {
    throw "Template module not found: $src"
}
if (-not (Test-Path (Join-Path $dst 'manifest.yaml'))) {
    throw "Target module not found: $dst"
}

function Copy-TrackedFile {
    param([string]$RelativeSourcePath, [string]$RelativeDestPath = $RelativeSourcePath)

    $from = Join-Path $src $RelativeSourcePath
    if (-not (Test-Path $from)) {
        Write-Warning "Skipping (not present in template): $RelativeSourcePath"
        return
    }

    $to = Join-Path $dst $RelativeDestPath
    if ($PSCmdlet.ShouldProcess($to, "Copy from $from")) {
        $toDir = Split-Path -Parent $to
        if (-not (Test-Path $toDir)) {
            New-Item -ItemType Directory -Path $toDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $from -Destination $to -Force
        Write-Host "Copied $RelativeSourcePath -> $RelativeDestPath"
    }
}

function Copy-TrackedDirectory {
    param([string]$RelativeDir)

    $from = Join-Path $src $RelativeDir
    if (-not (Test-Path $from)) {
        Write-Warning "Skipping (not present in template): $RelativeDir"
        return
    }

    $to = Join-Path $dst $RelativeDir
    if ($PSCmdlet.ShouldProcess($to, "Copy directory from $from")) {
        New-Item -ItemType Directory -Path $to -Force | Out-Null
        Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force
        Write-Host "Copied $RelativeDir/ -> $RelativeDir/"
    }
}

# Style + fonts
Copy-TrackedFile 'assets/style.css'
Copy-TrackedDirectory 'assets/fonts'

# Layout chrome — every file currently in the template
Copy-TrackedDirectory 'layouts'

# Setup passages — same filenames in both template and target's passages-override/
$setupFiles = @(
    '_Setup_01_PlayerCountSelect.mws.yaml',
    '_Setup_02_PlayerNameIntro.mws.yaml',
    '_Setup_03_PlayerNameA.mws.yaml',
    '_Setup_04_PlayerNameB.mws.yaml',
    '_Setup_05_PlayerNameC.mws.yaml',
    '_Setup_06_PlayerNameD.mws.yaml',
    '_Setup_07_TownNameEntry.mws.yaml'
)
foreach ($file in $setupFiles) {
    Copy-TrackedFile "passages/$file" "passages-override/$file"
}

# Scoring passages — the template names these Scoring_0N_*; real modules use the shorter
# _ScoreEntry/_TieBreaker1/_TieBreaker2/_Ranking convention established in cost-of-disease.
$scoringFileMap = [ordered]@{
    'Scoring_01_ScoreEntry.mws.yaml'  = '_ScoreEntry.mws.yaml'
    'Scoring_02_TieBreaker1.mws.yaml' = '_TieBreaker1.mws.yaml'
    'Scoring_03_TieBreaker2.mws.yaml' = '_TieBreaker2.mws.yaml'
    'Scoring_04_Ranking.mws.yaml'     = '_Ranking.mws.yaml'
}
foreach ($entry in $scoringFileMap.GetEnumerator()) {
    Copy-TrackedFile "passages/$($entry.Key)" "passages-override/$($entry.Value)"
}

Write-Host "`nDone. Review with 'git diff' inside $TargetModule/ before committing."
