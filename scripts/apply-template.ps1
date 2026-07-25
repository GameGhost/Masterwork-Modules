<#
.SYNOPSIS
    Copies my-fathers-work-template's shared style/layout/asset/setup/scoring content into a real
    module, matching the ownership split documented in this repo's CLAUDE.md.

.DESCRIPTION
    Template-canonical, mirror-copied (overwrite on collision, existing target-only files are never
    deleted): assets/audio/sfx/, assets/fonts/, assets/icons/ (combines with the target's own —
    template wins only on a filename collision, the target's unique icons are left alone),
    assets/images/{backgrounds,borders,inputs,popup,progress}/, assets/style.css, and every
    layouts/*.mws.yaml. Never touches assets/audio/bgm|vo, images directly under assets/images/, or
    images/setup/ — those are the target module's own scenario-specific content.

    Also copies the template's _Setup_01..07/_Scoring_01..04 passages verbatim (same filenames) into
    the target's passages-override/, and merges every restext key they reference — plus
    Common_Close/Common_Continue — from the template's own en-US.restext into the target's
    en-US.restext (and its .source/en-US.common.restext, if present), add-only: an existing target
    key is never overwritten, and a fresh re-run only ever adds what's still missing.

    -ProgressVariable handles a real integration gap this repo's own progress-bar layouts have: they
    read a 1-based `roundNum` (1-9), but a module extracted with --progress-map support instead sets
    an extractor-synthesized 0-based "rounds completed so far" variable (cost-of-disease's own is
    _ProgressRound — see progress-map.json's _comment). When given, this inserts one
    `let roundNum = min(<ProgressVariable> + 1, 9)` node as the first header entry of
    narration/introduction/hub_early/hub_middle/hub_late's freshly-copied layout files, right after
    every re-run's fresh copy from the template (so template-side edits to those layouts keep
    flowing through — this patch is reapplied on top each time, never hand-maintained separately).
    Omit if the target module will supply roundNum directly (or doesn't use the round-progress bar).

    This is the mechanical half of "harvest the template's design back into a real module" — a
    `git diff` + manual reconciliation inside the target module is still expected afterward:
    - Any tie-in passage the target hands off to from Setup_07 (target: '00_Preparations' in the
      template's own copy) needs to already exist in the target with a real chrome layout (not the
      retired 'setup_scenario') — this script never creates or touches it.
      END/ending passages (or whatever a target module's own "game complete" passages are named)
      need their own popup checked against the template's VarEndingsPassage pattern by hand — a
      real content decision (label text, popup layout name, restext correctness), not something
      this script can safely infer per module. See my-fathers-work-template/VIEW-REQUIREMENTS.md.
    - Run the target's own scratch test harness (or build one) end-to-end afterward — this script
      doesn't validate anything it writes.

.PARAMETER TargetModule
    Directory name of the module to copy into (e.g. 'cost-of-disease'), relative to this repo's root.

.PARAMETER TemplateModule
    Directory name of the source template module. Defaults to 'my-fathers-work-template'.

.PARAMETER ProgressVariable
    Session variable to derive roundNum from (e.g. '_ProgressRound'). Omit if not needed — see
    DESCRIPTION.

.EXAMPLE
    .\scripts\apply-template.ps1 -TargetModule cost-of-disease -ProgressVariable _ProgressRound -WhatIf
    Previews what would be copied/merged without touching anything.

.EXAMPLE
    .\scripts\apply-template.ps1 -TargetModule cost-of-disease -ProgressVariable _ProgressRound
    Applies for real — this is the exact invocation that reproduces cost-of-disease's own first
    manual merge. Follow up with `git diff` inside cost-of-disease/ before committing.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$TargetModule,

    [string]$TemplateModule = 'my-fathers-work-template',

    [string]$ProgressVariable
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
    if ($PSCmdlet.ShouldProcess($to, "Mirror-copy directory from $from")) {
        New-Item -ItemType Directory -Path $to -Force | Out-Null
        Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force
        Write-Host "Copied $RelativeDir/ -> $RelativeDir/"
    }
}

# ── Template-canonical assets ────────────────────────────────────────────────
$canonicalDirs = @(
    'assets/audio/sfx',
    'assets/fonts',
    'assets/icons',
    'assets/images/backgrounds',
    'assets/images/borders',
    'assets/images/inputs',
    'assets/images/popup',
    'assets/images/progress',
    'layouts'
)
foreach ($dir in $canonicalDirs) {
    Copy-TrackedDirectory $dir
}
Copy-TrackedFile 'assets/style.css'

# ── roundNum derivation patch ─────────────────────────────────────────────────
# Runs after the fresh layouts/ copy above, so it's always reapplied on top of whatever the
# template's own copy of these files currently looks like — never hand-maintained separately.
if ($ProgressVariable) {
    $roundNumLayouts = @('narration', 'introduction', 'hub_early', 'hub_middle', 'hub_late')
    $letBlock = @"
header:
- type: 'let'
  var: 'roundNum'
  expr: 'min($ProgressVariable + 1, 9)'
"@
    foreach ($layout in $roundNumLayouts) {
        $path = Join-Path $dst "layouts/$layout.mws.yaml"
        if (-not (Test-Path $path)) {
            Write-Warning "Skipping roundNum patch (layout not present): $layout"
            continue
        }
        $text = Get-Content -LiteralPath $path -Raw
        if ($text -notmatch '(?m)^header:') {
            Write-Warning "Skipping roundNum patch (no 'header:' key found): $layout"
            continue
        }
        if ($PSCmdlet.ShouldProcess($path, "Insert roundNum <- $ProgressVariable derivation")) {
            # MatchEvaluator (not a replacement-pattern string) so $letBlock's own literal '$' text
            # (inside the 'expr' string) is never misread as a regex backreference.
            $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $letBlock }
            $patched = [regex]::new('(?m)^header:').Replace($text, $evaluator, 1)
            Set-Content -LiteralPath $path -Value $patched -NoNewline
            Write-Host "Patched layouts/$layout.mws.yaml (roundNum <- $ProgressVariable)"
        }
    }
}

# ── Setup + Scoring override passages ─────────────────────────────────────────
$overridePassages = @(
    '_Setup_01_PlayerCountSelect.mws.yaml',
    '_Setup_02_PlayerNameIntro.mws.yaml',
    '_Setup_03_PlayerNameA.mws.yaml',
    '_Setup_04_PlayerNameB.mws.yaml',
    '_Setup_05_PlayerNameC.mws.yaml',
    '_Setup_06_PlayerNameD.mws.yaml',
    '_Setup_07_TownNameEntry.mws.yaml',
    '_Scoring_01_ScoreEntry.mws.yaml',
    '_Scoring_02_TieBreaker1.mws.yaml',
    '_Scoring_03_TieBreaker2.mws.yaml',
    '_Scoring_04_Ranking.mws.yaml'
)
foreach ($file in $overridePassages) {
    Copy-TrackedFile "passages/$file" "passages-override/$file"
}

# ── Restext merge (add-only) ──────────────────────────────────────────────────
function Get-RestextKeys {
    param([string]$Path)
    $keys = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    if (-not (Test-Path $Path)) { return $keys }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^([A-Za-z0-9_]+)=(.*)$') {
            $keys[$Matches[1]] = $Matches[2]
        }
    }
    return $keys
}

$templateRestext = Get-RestextKeys (Join-Path $src 'en-US.restext')
$targetRestextPath = Join-Path $dst 'en-US.restext'
$targetRestextKeys = Get-RestextKeys $targetRestextPath

$referencedKeys = New-Object 'System.Collections.Generic.HashSet[string]'
[void]$referencedKeys.Add('Common_Close')
[void]$referencedKeys.Add('Common_Continue')
foreach ($file in $overridePassages) {
    $copiedPath = Join-Path $dst "passages-override/$file"
    if (-not (Test-Path $copiedPath)) { continue }
    $text = Get-Content -LiteralPath $copiedPath -Raw
    foreach ($m in [regex]::Matches($text, 'restext://([A-Za-z0-9_]+)')) {
        [void]$referencedKeys.Add($m.Groups[1].Value)
    }
}

$missingKeys = $referencedKeys | Where-Object { -not $targetRestextKeys.ContainsKey($_) } | Sort-Object
if ($missingKeys.Count -gt 0) {
    $newLines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($key in $missingKeys) {
        if ($templateRestext.ContainsKey($key)) {
            $newLines.Add("$key=$($templateRestext[$key])")
        }
        else {
            Write-Warning "Referenced restext key has no template value either, skipping: $key"
        }
    }

    if ($newLines.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($targetRestextPath, "Append $($newLines.Count) restext keys")) {
            Add-Content -LiteralPath $targetRestextPath -Value ''
            Add-Content -LiteralPath $targetRestextPath -Value '# passages-override/_Setup_*.mws.yaml, _Scoring_*.mws.yaml — hand-authored, template-supplied'
            Add-Content -LiteralPath $targetRestextPath -Value '# onboarding/scoring flow (masterwork.template). Curated alongside .source/en-US.common.restext'
            Add-Content -LiteralPath $targetRestextPath -Value "# so a re-extraction doesn't silently drop these — see that file's own header."
            Add-Content -LiteralPath $targetRestextPath -Value $newLines
            Write-Host "Appended $($newLines.Count) restext keys to en-US.restext"
        }

        $commonRestextPath = Join-Path $dst '.source/en-US.common.restext'
        if (Test-Path $commonRestextPath) {
            if ($PSCmdlet.ShouldProcess($commonRestextPath, "Merge $($newLines.Count) restext keys, alphabetically")) {
                $merged = (Get-Content -LiteralPath $commonRestextPath) + $newLines | Sort-Object -Unique
                Set-Content -LiteralPath $commonRestextPath -Value $merged
                Write-Host "Merged $($newLines.Count) keys into .source/en-US.common.restext (re-sorted)"
            }
        }
        else {
            Write-Warning "No .source/en-US.common.restext in target — new keys will be lost on the next re-extraction unless added there by hand."
        }
    }
}
else {
    Write-Host "No new restext keys needed — target already has everything the copied passages reference."
}

Write-Host "`nDone. Manual follow-ups this script deliberately doesn't do (see this script's own .DESCRIPTION):"
Write-Host "  - Confirm the target's own tie-in passage for Setup_07's handoff (target: '00_Preparations') exists and uses a real layout."
Write-Host "  - Check the target's own ending/game-complete passages against the template's VarEndingsPassage pattern by hand."
Write-Host "  - Review with 'git diff' inside $TargetModule/ and run the target's own test harness before committing."
