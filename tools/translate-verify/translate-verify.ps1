<#
.SYNOPSIS
    Translates and round-trip-verifies a scenario's restext, or the app's resx, into another language.

.DESCRIPTION
    Stages, each agent stage one headless `claude -p` call per passage (or per group of app strings):
        terms     (scenario only, once) mine the scenario's own term list from its official aligned pairs
        forward   write French for drafts and missing strings, a whole passage at a time
        checks    `Masterwork.ModulePacker checktranslation --fix`: typography, integrity, terms
        back      blind back-translation: the French, its passage and the reversed term base only
        judge     English vs back-translation vs French: a verdict and a minimal fix for each string
        revision  fixes re-checked; meaning and term fixes back-translated and judged once more
        write     the locale file with `# origin:` comments, and the report
    Every agent answer is stored under -WorkDir with a hash of its request, so a rerun resumes where
    the last one stopped. See README.md.

.PARAMETER Module
    A scenario directory (en-US.restext, the reconciled <Locale>.restext, passages/).
.PARAMETER Resx
    The app's English AppStrings.resx. The translation is AppStrings.<Locale>.resx beside it.
.PARAMETER Locale
    Target locale. Needs terms.<Locale>.yaml and style.<Locale>.md beside this script.
.PARAMETER WorkDir
    Stage outputs. Default: .translate-verify/<module or app>/<Locale> at the repo root (gitignored).
.PARAMETER Report
    Default: <Module>/.source/_translate-report.<Locale>.md, or report.md in -WorkDir for the app.
.PARAMETER UnityDrafts
    JSON object of key -> Unity app French, used as drafts for missing strings.
    Default: <Module>/.source/unity-drafts.<Locale>.json when it exists.
.PARAMETER CodeRepoPath
    The Masterwork checkout whose checktranslation runs the checks. Default: the sibling of this repo.
.PARAMETER NoBuild
    Don't build Masterwork.ModulePacker first.
.PARAMETER Agent
    The agent command and any leading arguments. Default: claude.
.PARAMETER Model
    Passed to the agent as --model. Default: the agent's own default.
.PARAMETER Parallel
    Agent calls run at once.
.PARAMETER TimeoutMinutes
    How long one agent call may run before it is stopped and retried.
.PARAMETER StopAfter
    terms: stop once the scenario term list is written, to review it. forward: stop after the drafts.

.EXAMPLE
    ./tools/translate-verify/translate-verify.ps1 -Module a-time-of-war -StopAfter terms
    Mines A Time of War's term list into a-time-of-war/.source/terms.fr-CA.yaml for review.

.EXAMPLE
    ./tools/translate-verify/translate-verify.ps1 -Module a-time-of-war
    The whole pass. Run it again after an interruption to resume.

.EXAMPLE
    ./tools/translate-verify/translate-verify.ps1 -Resx ../Masterwork/src/Masterwork.App.Shared/Resources/AppStrings.resx
    Verifies AppStrings.fr-CA.resx and adds its missing strings.
#>
#Requires -Version 7.2
[CmdletBinding(DefaultParameterSetName = 'Module')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Module')][string]$Module,
    [Parameter(Mandatory, ParameterSetName = 'Resx')][string]$Resx,
    [string]$Locale = 'fr-CA',
    [string]$WorkDir,
    [string]$Report,
    [string]$UnityDrafts,
    [string]$CodeRepoPath = (Join-Path $PSScriptRoot '..' '..' '..' 'Masterwork'),
    [switch]$NoBuild,
    [string[]]$Agent = @('claude'),
    [string]$Model,
    [int]$Parallel = 4,
    [int]$TimeoutMinutes = 20,
    [ValidateSet('terms', 'forward', 'all')][string]$StopAfter = 'all'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$Utf8 = [Text.UTF8Encoding]::new($false)
Import-Module (Join-Path $PSScriptRoot 'TranslateVerify.psm1') -Force

$prompts = Join-Path $PSScriptRoot 'prompts'
$sharedTerms = Join-Path $PSScriptRoot "terms.$Locale.yaml"
$styleFile = Join-Path $PSScriptRoot "style.$Locale.md"
foreach ($f in $sharedTerms, $styleFile) { if (-not (Test-Path $f)) { throw "No $(Split-Path -Leaf $f) for $Locale beside this script." } }
$language = [Globalization.CultureInfo]::GetCultureInfo($Locale).EnglishName

# --- Scope -------------------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Module') {
    $Module = (Resolve-Path $Module).Path
    $name = Split-Path -Leaf $Module
    $scenarioTerms = Join-Path $Module ".source/terms.$Locale.yaml"
    if (-not $UnityDrafts -and (Test-Path (Join-Path $Module ".source/unity-drafts.$Locale.json"))) { $UnityDrafts = Join-Path $Module ".source/unity-drafts.$Locale.json" }
    $unity = if ($UnityDrafts) { Get-Content $UnityDrafts -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable } else { @{} }
    if (-not (Test-Path (Join-Path $Module "$Locale.restext"))) { Write-Warning "No $Locale.restext in $Module; every string is translated from scratch." }
    $scope = Get-ModuleScope $Module $Locale $unity
    $title = $name
    $manifest = Join-Path $Module 'manifest.yaml'
    if ((Test-Path $manifest) -and (Get-Content $manifest -Raw) -match "(?m)^title:\s*['`"]?(.*?)['`"]?\s*$") {
        $title = $Matches[1]
        if ($title -match '^restext://(.+)$') { $title = (Read-Restext (Join-Path $Module 'en-US.restext')).Values[$Matches[1]] ?? $name }
    }
    if (-not $Report) { $Report = Join-Path $Module ".source/_translate-report.$Locale.md" }
}
else {
    $Resx = (Resolve-Path $Resx).Path
    $localeResx = $Resx -replace '\.resx$', ".$Locale.resx"
    $name = 'app'
    $title = 'the app interface'
    $scenarioTerms = $null
    $scope = Get-ResxScope $Resx $localeResx
}
if (-not $WorkDir) { $WorkDir = Join-Path $PSScriptRoot "../../.translate-verify/$name/$Locale" }
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$WorkDir = (Resolve-Path $WorkDir).Path
if (-not $Report) { $Report = Join-Path $WorkDir 'report.md' }

$strings = $scope.Records
$units = $scope.Units
Write-Host "$title ($Locale): $($strings.Count) strings in $($units.Count) units; $(@($strings.Values | Where-Object Bucket -eq 'draft').Count) drafts, $(@($strings.Values | Where-Object Bucket -eq 'gap').Count) missing"

# --- Tools -------------------------------------------------------------------------------------
$cmd = Get-Command $Agent[0] -ErrorAction SilentlyContinue
if (-not $cmd) { throw "Agent command '$($Agent[0])' not found. Install Claude Code, or pass -Agent." }
$agentCmd = if ($cmd.Source -like '*.ps1') { @((Get-Process -Id $PID).Path, '-NoProfile', '-File', $cmd.Source) + @($Agent | Select-Object -Skip 1) }
else { @($cmd.Source) + @($Agent | Select-Object -Skip 1) }
# An empty directory, so the agent loads no project instructions.
$agentCwd = Join-Path ([IO.Path]::GetTempPath()) 'translate-verify-agent'
New-Item -ItemType Directory -Force $agentCwd | Out-Null

$packer = Join-Path (Resolve-Path $CodeRepoPath).Path 'src/Masterwork.ModulePacker'
if (-not (Test-Path $packer)) { throw "No Masterwork.ModulePacker under $CodeRepoPath. Pass -CodeRepoPath." }
if (-not $NoBuild) {
    dotnet build $packer -nologo -v q | Out-Null
    if ($LASTEXITCODE) { throw 'Building Masterwork.ModulePacker failed.' }
}
$checker = @('dotnet', 'run', '--project', $packer, '--no-build', '--')

$agentParams = @{ Agent = $agentCmd; Model = $Model; Parallel = $Parallel; TimeoutMinutes = $TimeoutMinutes; Cwd = $agentCwd }
$allAnswers = [Collections.Generic.List[object]]::new()
function Invoke-Stage([string]$Label, $Jobs) {
    if (-not @($Jobs).Count) { return @{} }
    Write-Host "Stage: $Label"
    $answers = Invoke-AgentJobs -Jobs $Jobs @agentParams
    foreach ($a in $answers.Values) { $allAnswers.Add($a) }
    $answers
}
function New-AgentJob([string]$Stage, [string]$Template, $Unit, [hashtable]$Values, $Expected, [string]$Dir = $Stage) {
    @{ Stage = $Stage; Name = $Unit.Id; Prompt = (Format-Prompt (Join-Path $prompts $Template) $Values)
        System = "You are one stage of a translation pipeline for a board game companion app. Follow the instructions in the message and answer only through the structured output."
        Schema = (Get-Schema $(if ($Stage -eq 'mine-terms') { 'mine' } else { $Stage }))
        OutFile = (Join-Path $WorkDir "$Dir/$($Unit.Id).json"); ExpectedKeys = $Expected }
}

# --- Term base ---------------------------------------------------------------------------------
$layers = @(@{ Title = 'Game terms (shared)'; Base = (Read-TermBase $sharedTerms); Path = (Resolve-Path $sharedTerms).Path })
if ($scenarioTerms -and -not (Test-Path $scenarioTerms)) {
    $pairs = @($strings.Values | Where-Object { $_.Bucket -eq 'verify' -and $_.Origin -eq 'official' } | ForEach-Object { [ordered]@{ key = $_.Key; en = $_.En; fr = $_.Fr } })
    $n = 0
    $jobs = foreach ($chunk in @(Split-Chunks $pairs 150)) {
        New-AgentJob 'mine-terms' 'mine-terms.md' @{ Id = 'chunk-{0:d3}' -f (++$n) } @{
            TITLE = $title; LANGUAGE = $language; LOCALE = $Locale; TERMS = (Format-TermTable $layers); STRINGS = (ConvertTo-PromptJson $chunk) } $null 'terms'
    }
    $mined = Invoke-Stage 'terms' $jobs
    $terms = @(Merge-MinedTerms @($mined.Values | ForEach-Object { $_.items }) $layers[0].Base)
    [IO.File]::WriteAllText($scenarioTerms, (Format-MinedTermBase $terms $title $Locale), $Utf8)
    Write-Host "Wrote $($terms.Count) scenario terms to $scenarioTerms. Review them before the forward stage."
}
if ($StopAfter -eq 'terms') { return }
if ($scenarioTerms -and (Test-Path $scenarioTerms)) {
    $layers += @{ Title = "Scenario terms ($title)"; Base = (Read-TermBase $scenarioTerms); Path = (Resolve-Path $scenarioTerms).Path }
}
$termPaths = @($layers | ForEach-Object Path)
$common = @{ LANGUAGE = $language; LOCALE = $Locale; STYLE = [IO.File]::ReadAllText($styleFile); TERMS = (Format-TermTable $layers)
    FORBIDDEN = (Format-Forbidden $layers); REVERSED_TERMS = (Format-TermTable $layers -Reversed) }
function Get-Subject($Unit) {
    if ($scope.Kind -eq 'resx') { "the $($Unit.Name) of the app's own interface" } else { "the passage ``$($Unit.Name)`` of the scenario *$title*" }
}
function Get-Status($Rec) {
    switch ($Rec.Bucket) { 'draft' { 'draft' } 'gap' { 'missing' } default { $Rec.Origin ?? 'existing' } }
}
function Merge-Values([hashtable]$Values) { $v = $common.Clone(); foreach ($k in $Values.Keys) { $v[$k] = $Values[$k] }; $v }

foreach ($rec in $strings.Values) {
    foreach ($f in 'Forward', 'ForwardNote', 'Cand1', 'Checks1', 'Back1', 'BackNote1', 'Judge1', 'Fix', 'Cand2', 'Checks2', 'Back2', 'BackNote2', 'Judge2', 'Status', 'Problem', 'Final', 'Written', 'FinalOrigin') { $rec[$f] = $null }
    $rec.KeptInput = $false
}

# --- Forward -----------------------------------------------------------------------------------
$jobs = foreach ($unit in $units) {
    $todo = @($unit.Keys | Where-Object { $strings[$_].Bucket -in 'draft', 'gap' })
    if (-not $todo) { continue }
    $items = foreach ($k in $unit.Context) {
        $rec = $strings[$k]
        $i = [ordered]@{ key = $k; status = (Get-Status $rec); en = $rec.En; fr = $rec.Fr; translate = ($k -cin $todo) }
        if ($i.translate -and $rec.Unity) { $i.unityDraft = $rec.Unity }
        if ($i.translate -and $rec.Passages.Count -gt 1) { $i.alsoUsedIn = @($rec.Passages | Select-Object -Skip 1) }
        $i
    }
    New-AgentJob 'forward' 'forward.md' $unit (Merge-Values @{ SUBJECT = (Get-Subject $unit); STRINGS = (ConvertTo-PromptJson $items) }) $todo
}
$answers = Invoke-Stage 'forward' @($jobs)
foreach ($a in $answers.Values) { foreach ($i in $a.items) { $strings[$i.key].Forward = $i.fr; $strings[$i.key].ForwardNote = $i.note } }
if ($StopAfter -eq 'forward') { return }

# --- Checks ------------------------------------------------------------------------------------
# Checks every record's $Field and returns key -> result; a string the checker didn't report fails.
function Invoke-CheckRound([string]$Name, $Recs, [string]$Field) {
    $pairs = @($Recs | ForEach-Object { @{ Key = $_.Key; En = $_.En; Fr = $_[$Field] } })
    Write-Host "Stage: checks ($Name)"
    $checks = Invoke-Checks -Name $Name -Kind $scope.Kind -Locale $Locale -Pairs $pairs -TermBases $termPaths -WorkDir $WorkDir -Checker $checker
    foreach ($p in $pairs) {
        if (-not $checks.ContainsKey($p.Key)) { $checks[$p.Key] = @{ Fr = $p.Fr; Fixed = $false; Failures = @('missing: no candidate'); Flags = @() } }
    }
    $checks
}
foreach ($rec in $strings.Values) { $rec.Cand1 = if ($rec.Bucket -eq 'verify') { $rec.Fr } else { $rec.Forward } }
$checks = Invoke-CheckRound 'first' @($strings.Values) 'Cand1'
foreach ($rec in $strings.Values) { $rec.Checks1 = $checks[$rec.Key]; $rec.Cand1 = $rec.Checks1.Fr }

# --- Back-translation and judge ----------------------------------------------------------------
function Get-BackJobs([int]$Round, [string[]]$Keys) {
    foreach ($unit in $units) {
        $todo = @($unit.Keys | Where-Object { $_ -cin $Keys -and $null -ne ($strings[$_].Cand2 ?? $strings[$_].Cand1) })
        if (-not $todo) { continue }
        $items = foreach ($k in $unit.Context) {
            $fr = $strings[$k].Cand2 ?? $strings[$k].Cand1
            if ($null -ne $fr) { [ordered]@{ key = $k; fr = $fr; translate = ($k -cin $todo) } }
        }
        $values = @{ SUBJECT = (Get-Subject $unit); REVERSED_TERMS = $common.REVERSED_TERMS; LANGUAGE = $language; ROUND = "<!-- round: $Round -->"; STRINGS = (ConvertTo-PromptJson $items) }
        New-AgentJob "back" 'backtranslate.md' $unit $values $todo $(if ($Round -eq 2) { 'back2' } else { 'back' })
    }
}
function Get-JudgeJobs([int]$Round, [string[]]$Keys) {
    foreach ($unit in $units) {
        $todo = @($unit.Keys | Where-Object { $_ -cin $Keys })
        if (-not $todo) { continue }
        $items = foreach ($k in $unit.Context) {
            $rec = $strings[$k]
            if ($k -cnotin $todo) { [ordered]@{ key = $k; en = $rec.En; fr = ($rec.Cand2 ?? $rec.Cand1); translate = $false }; continue }
            $checksN = if ($Round -eq 2) { $rec.Checks2 } else { $rec.Checks1 }
            $i = [ordered]@{ key = $k; status = (Get-Status $rec); en = $rec.En; fr = $(if ($Round -eq 2) { $rec.Cand2 } else { $rec.Cand1 })
                backTranslation = $(if ($Round -eq 2) { $rec.Back2 } else { $rec.Back1 }); backTranslatorNote = $(if ($Round -eq 2) { $rec.BackNote2 } else { $rec.BackNote1 })
                checks = [ordered]@{ failures = @($checksN.Failures); flags = @($checksN.Flags) }; translate = $true }
            if ($rec.Bucket -eq 'draft') { $i.officialInput = $rec.Fr }
            if ($rec.Unity) { $i.unityDraft = $rec.Unity }
            if ($rec.ForwardNote) { $i.translatorNote = $rec.ForwardNote }
            if ($Round -eq 2) { $i.previousAttempt = $rec.Cand1; $i.previousVerdict = "$($rec.Judge1.verdict): $($rec.Judge1.reason)" }
            $i
        }
        $values = Merge-Values @{ SUBJECT = (Get-Subject $unit); ROUND = "<!-- round: $Round -->"; STRINGS = (ConvertTo-PromptJson $items) }
        New-AgentJob "judge" 'judge.md' $unit $values $todo $(if ($Round -eq 2) { 'judge2' } else { 'judge' })
    }
}

$allKeys = @($strings.Keys)
$answers = Invoke-Stage 'back-translation' @(Get-BackJobs 1 $allKeys)
foreach ($a in $answers.Values) { foreach ($i in $a.items) { $strings[$i.key].Back1 = $i.en; $strings[$i.key].BackNote1 = $i.note } }
$answers = Invoke-Stage 'judge' @(Get-JudgeJobs 1 $allKeys)
foreach ($a in $answers.Values) { foreach ($i in $a.items) { $strings[$i.key].Judge1 = $i } }

# --- Revision ----------------------------------------------------------------------------------
foreach ($rec in $strings.Values) {
    $j = $rec.Judge1
    if ($j.verdict -eq 'pass') {
        if ($rec.Checks1.Failures.Count) { $rec.Status = 'unresolved'; $rec.Problem = 'The judge passed a string that fails the hard checks.' }
        else { $rec.Status = 'pass' }
    }
    elseif (-not "$($j.fix)".Trim()) { $rec.Status = 'unresolved'; $rec.Problem = 'The judge gave no fix.' }
    else { $rec.Fix = $j.fix }
}
$revised = @($strings.Values | Where-Object { $null -ne $_.Fix })
if ($revised) {
    $checks = Invoke-CheckRound 'revision' $revised 'Fix'
    foreach ($rec in $revised) { $rec.Checks2 = $checks[$rec.Key]; $rec.Cand2 = $rec.Checks2.Fr }
    foreach ($rec in $revised | Where-Object { $_.Judge1.verdict -in 'fail: typo', 'fail: integrity' }) {
        if ($rec.Checks2.Failures.Count) { $rec.Status = 'unresolved'; $rec.Problem = 'The fix fails the hard checks.' } else { $rec.Status = 'revised' }
    }
    $again = @($revised | Where-Object { $_.Judge1.verdict -in 'fail: meaning', 'fail: term' } | ForEach-Object Key)
    if ($again) {
        $answers = Invoke-Stage 'back-translation (revision)' @(Get-BackJobs 2 $again)
        foreach ($a in $answers.Values) { foreach ($i in $a.items) { $strings[$i.key].Back2 = $i.en; $strings[$i.key].BackNote2 = $i.note } }
        $answers = Invoke-Stage 'judge (revision)' @(Get-JudgeJobs 2 $again)
        foreach ($a in $answers.Values) { foreach ($i in $a.items) { $strings[$i.key].Judge2 = $i } }
        foreach ($k in $again) {
            $rec = $strings[$k]
            if ($rec.Judge2.verdict -eq 'pass' -and -not $rec.Checks2.Failures.Count) { $rec.Status = 'revised' }
            else { $rec.Status = 'unresolved'; $rec.Problem = if ($rec.Checks2.Failures.Count) { 'The fix fails the hard checks.' } else { 'The revision failed the judge again.' } }
        }
    }
}

# --- Final strings and origins -----------------------------------------------------------------
foreach ($rec in $strings.Values) {
    $rec.Final = switch ($rec.Status) {
        'pass' { $rec.Cand1 }
        'revised' { $rec.Cand2 }
        default {
            # Unresolved: the latest attempt that passes the hard checks.
            if ($null -ne $rec.Cand2 -and -not $rec.Checks2.Failures.Count) { $rec.Cand2 }
            elseif ($null -ne $rec.Cand1 -and -not $rec.Checks1.Failures.Count) { $rec.Cand1 }
            else { $null }
        }
    }
    if ($null -eq $rec.Final) {
        # No clean attempt: keep the input. Verified text keeps its typography normalization, which is mechanical.
        $rec.KeptInput = $true
        $rec.Written = if ($rec.Bucket -eq 'verify') { $rec.Cand1 } else { $rec.Fr }
        $rec.FinalOrigin = $rec.Origin
        continue
    }
    $rec.Written = $rec.Final
    $rec.FinalOrigin = switch ($rec.Bucket) {
        'draft' { 'official, revised' }
        'gap' { if ($rec.Unity) { 'unity, revised' } else { 'agent' } }
        default { if ($rec.Origin -eq 'official' -and $rec.Final -cne $rec.Cand1) { 'official, revised' } else { $rec.Origin } }
    }
}

# --- Write -------------------------------------------------------------------------------------
if ($scope.Kind -eq 'restext') {
    $main = @{}; $over = @{}
    foreach ($k in $scope.Preserved.Keys) {
        $p = $scope.Preserved[$k]
        $target = if ($p.File -eq 'overrides') { $over } else { $main }
        $target[$k] = $p
    }
    foreach ($rec in $strings.Values) {
        if ($null -eq $rec.Written) { continue }
        $target = if ($rec.File -eq 'overrides') { $over } else { $main }
        $target[$rec.Key] = @{ Value = $rec.Written; Origin = $rec.FinalOrigin }
    }
    $header = @("# Masterwork locale file — $Locale", '# Format: Key=Value  (one string per line)',
        '# Each key''s "# origin:" is one of official | official, revised | unity, revised | agent,',
        '# or draft (official French still awaiting the agent pass). Verified by tools/translate-verify.')
    [IO.File]::WriteAllText((Join-Path $Module "$Locale.restext"), (Format-Restext $scope.MainLayout $main $header), $Utf8)
    if ($over.Count -or $scope.HasOverrides) {
        [IO.File]::WriteAllText((Join-Path $Module "$Locale.overrides.restext"), (Format-Restext $scope.OverridesLayout $over $header), $Utf8)
    }
}
else {
    $values = @{}
    foreach ($rec in $strings.Values) { if ($null -ne $rec.Written -and $rec.Written -cne $rec.Fr) { $values[$rec.Key] = $rec.Written } }
    if (Test-Path $localeResx) {
        $bytes = [IO.File]::ReadAllBytes($localeResx)
        $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $text = Update-ResxText ([IO.File]::ReadAllText($localeResx)) $values
        [IO.File]::WriteAllText($localeResx, $text, [Text.UTF8Encoding]::new($bom))
    }
    else { [IO.File]::WriteAllText($localeResx, (Format-ResxFile $values), $Utf8) }
}

$cost = ($allAnswers | ForEach-Object { [double]($_.cost ?? 0) } | Measure-Object -Sum).Sum
New-Item -ItemType Directory -Force (Split-Path $Report) | Out-Null
[IO.File]::WriteAllText($Report, (Format-Report -Records @($strings.Values) -Title $title -Locale $Locale -Calls $allAnswers.Count -Cost $cost -Kind $scope.Kind), $Utf8)

$statusCounts = $strings.Values | Group-Object Status | ForEach-Object { "$($_.Count) $($_.Name)" }
Write-Host "Done: $($statusCounts -join ', '). Report: $Report"
