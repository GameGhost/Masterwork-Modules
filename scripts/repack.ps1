<#
.SYNOPSIS
    Repacks Masterwork content modules and asset packs into .mwm/.mwassets bundles, with optional
    semver version bumping.

.DESCRIPTION
    Wraps Masterwork.ModulePacker (in the Masterwork code repo) to rebuild bundles at this repo's
    root from each source directory's current contents. Run this any time content changes and you
    want the packaged bundle to reflect it — packaging is a pure repackaging step, it never
    re-runs extraction or validates content (see this repo's own CLAUDE.md "Bundling" section).

    Three modes, matching Masterwork.ModulePacker's own three packing modes:
    - 'module' (default): standard .mwm — a module's own content only, `dependencies:` left as
      declared in its manifest.yaml. This is what a real release ships.
    - 'asset': .mwassets — packs a directory with no `passages/` subfolder (an asset pack, e.g.
      mwf-common-assets) instead of a module.
    - 'standalone': .mwm with every declared asset-pack dependency's own layouts/assets/variables
      merged directly in, and `dependencies:` blanked out in the packaged manifest — loads with
      nothing else installed. Used for manual-install testing, not a real release artifact; each
      dependency is resolved against this repo's own asset-pack directories by matching id, so it
      only works for a dependency this repo actually has the source for.

.PARAMETER Mode
    'module' (default), 'asset', or 'standalone' — see DESCRIPTION.

.PARAMETER Module
    Repack only this directory (a name at the repo root, e.g. 'cost-of-disease' or
    'mwf-common-assets'). If omitted, every matching directory for the current -Mode is repacked
    ('module'/'standalone': every module directory; 'asset': every asset-pack directory).

.PARAMETER IncrementVersion
    Bump the target's manifest.yaml 'version' field before repacking, using semver rules: 'patch'
    increments the patch number; 'minor' increments minor and resets patch to 0; 'major' increments
    major and resets minor+patch to 0. Requires -Module — bumping every target's version in one pass
    is never what you want. Not valid with -Mode standalone (it repacks from the module's own
    manifest as-is; bump the module itself in 'module' mode instead).

.PARAMETER CodeRepoPath
    Path to the Masterwork code repo (holds Masterwork.ModulePacker). Defaults to the sibling-repo
    layout documented in this repo's CLAUDE.md ('..\Masterwork' relative to this repo's root).

.EXAMPLE
    .\scripts\repack.ps1
    Repacks every module to .mwm (standard mode).

.EXAMPLE
    .\scripts\repack.ps1 -Mode asset
    Repacks every asset pack (e.g. mwf-common-assets) to .mwassets.

.EXAMPLE
    .\scripts\repack.ps1 -Mode standalone -Module cost-of-disease
    Builds cost-of-disease.standalone.mwm with mwf-common-assets merged directly in, for manual
    install testing without installing the asset pack separately.

.EXAMPLE
    .\scripts\repack.ps1 -Module cost-of-disease -IncrementVersion patch
    Bumps cost-of-disease's version (e.g. 0.1.0 -> 0.1.1) and repacks it (module mode).

.EXAMPLE
    .\scripts\repack.ps1 -Module my-fathers-work-template -WhatIf
    Previews what would happen without writing anything.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('module', 'asset', 'standalone')]
    [string]$Mode = 'module',

    [string]$Module,

    [ValidateSet('major', 'minor', 'patch')]
    [string]$IncrementVersion,

    [string]$CodeRepoPath = (Join-Path $PSScriptRoot '..' '..' 'Masterwork')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$packerProject = Join-Path $CodeRepoPath 'src' 'Masterwork.ModulePacker'

if ($IncrementVersion -and -not $Module) {
    throw "-IncrementVersion requires -Module (bumping every target's version in one pass is not supported)."
}
if ($IncrementVersion -and $Mode -eq 'standalone') {
    throw "-IncrementVersion isn't valid with -Mode standalone — bump the module itself in 'module' mode instead."
}

if (-not (Test-Path $packerProject)) {
    throw "Masterwork.ModulePacker project not found at '$packerProject'. Pass -CodeRepoPath if the code repo isn't a sibling of this one."
}

function Test-IsModuleDirectory {
    param([string]$Dir)
    return (Test-Path (Join-Path $Dir 'manifest.yaml')) -and (Test-Path (Join-Path $Dir 'passages'))
}

function Test-IsAssetPackDirectory {
    param([string]$Dir)
    return (Test-Path (Join-Path $Dir 'manifest.yaml')) -and -not (Test-Path (Join-Path $Dir 'passages'))
}

function Get-ModuleDirectories {
    if ($Module) {
        $dir = Join-Path $repoRoot $Module
        if (-not (Test-IsModuleDirectory $dir)) {
            throw "No module directory (manifest.yaml + passages/) found at '$dir'."
        }
        return , (Get-Item -LiteralPath $dir)
    }

    return Get-ChildItem -Path $repoRoot -Directory | Where-Object { Test-IsModuleDirectory $_.FullName }
}

function Get-AssetPackDirectories {
    # -All ignores -Module — used in 'standalone' mode to build the full id-lookup map regardless of
    # which single module -Module is scoping the *module* side of that run to.
    param([switch]$All)

    if ($Module -and -not $All) {
        $dir = Join-Path $repoRoot $Module
        if (-not (Test-IsAssetPackDirectory $dir)) {
            throw "No asset-pack directory (manifest.yaml, no passages/) found at '$dir'."
        }
        return , (Get-Item -LiteralPath $dir)
    }

    return Get-ChildItem -Path $repoRoot -Directory | Where-Object { Test-IsAssetPackDirectory $_.FullName }
}

function Get-ManifestId {
    param([string]$ManifestPath)
    $text = Get-Content -Raw -LiteralPath $ManifestPath
    if ($text -match "(?m)^id:\s*['`"](?<id>[^'`"]+)['`"]") {
        return $Matches['id']
    }
    throw "Could not find a quoted 'id:' line in $ManifestPath."
}

function Get-ManifestDependencyIds {
    param([string]$ManifestPath)
    $text = Get-Content -Raw -LiteralPath $ManifestPath
    $ids = New-Object 'System.Collections.Generic.List[string]'
    $block = [regex]::Match($text, "(?ms)^dependencies:[ \t]*\r?\n(?<entries>(?:^-.*\r?\n(?:^[ \t]+.*\r?\n)*)*)")
    if (-not $block.Success) {
        return $ids
    }
    foreach ($m in [regex]::Matches($block.Groups['entries'].Value, "id:\s*['`"](?<id>[^'`"]+)['`"]")) {
        [void]$ids.Add($m.Groups['id'].Value)
    }
    return $ids
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

switch ($Mode) {
    'asset' {
        foreach ($dir in Get-AssetPackDirectories) {
            Write-Host "$($dir.Name):"

            if ($IncrementVersion) {
                Update-ManifestVersion -ManifestPath (Join-Path $dir.FullName 'manifest.yaml') -Part $IncrementVersion
            }

            $outputPath = Join-Path $repoRoot "$($dir.Name).mwassets"
            if ($PSCmdlet.ShouldProcess($outputPath, "Repack (asset) from $($dir.FullName)")) {
                & dotnet run --project $packerProject -- asset $dir.FullName $outputPath
                if ($LASTEXITCODE -ne 0) {
                    throw "Packing failed for $($dir.Name)."
                }
            }
        }
    }

    'module' {
        foreach ($dir in Get-ModuleDirectories) {
            Write-Host "$($dir.Name):"

            if ($IncrementVersion) {
                Update-ManifestVersion -ManifestPath (Join-Path $dir.FullName 'manifest.yaml') -Part $IncrementVersion
            }

            $outputPath = Join-Path $repoRoot "$($dir.Name).mwm"
            if ($PSCmdlet.ShouldProcess($outputPath, "Repack (module) from $($dir.FullName)")) {
                & dotnet run --project $packerProject -- module $dir.FullName $outputPath
                if ($LASTEXITCODE -ne 0) {
                    throw "Packing failed for $($dir.Name)."
                }
            }
        }
    }

    'standalone' {
        $assetPackDirs = Get-AssetPackDirectories -All
        $assetPackById = @{}
        foreach ($dir in $assetPackDirs) {
            $id = Get-ManifestId (Join-Path $dir.FullName 'manifest.yaml')
            $assetPackById[$id] = $dir.FullName
        }

        foreach ($dir in Get-ModuleDirectories) {
            Write-Host "$($dir.Name):"

            $depIds = Get-ManifestDependencyIds (Join-Path $dir.FullName 'manifest.yaml')
            $depDirs = New-Object 'System.Collections.Generic.List[string]'
            foreach ($id in $depIds) {
                if (-not $assetPackById.ContainsKey($id)) {
                    throw "$($dir.Name) depends on '$id', but no local asset-pack directory declares that id. Standalone packing needs the dependency's source here."
                }
                [void]$depDirs.Add($assetPackById[$id])
            }

            if ($depDirs.Count -eq 0) {
                Write-Warning "$($dir.Name) has no asset-pack dependencies — packing standard 'module' mode instead."
                $outputPath = Join-Path $repoRoot "$($dir.Name).mwm"
                if ($PSCmdlet.ShouldProcess($outputPath, "Repack (module) from $($dir.FullName)")) {
                    & dotnet run --project $packerProject -- module $dir.FullName $outputPath
                    if ($LASTEXITCODE -ne 0) {
                        throw "Packing failed for $($dir.Name)."
                    }
                }
                continue
            }

            $outputPath = Join-Path $repoRoot "$($dir.Name).standalone.mwm"
            if ($PSCmdlet.ShouldProcess($outputPath, "Repack (standalone) from $($dir.FullName) + $($depDirs -join ', ')")) {
                & dotnet run --project $packerProject -- standalone $dir.FullName $outputPath @depDirs
                if ($LASTEXITCODE -ne 0) {
                    throw "Standalone packing failed for $($dir.Name)."
                }
            }
        }
    }
}
