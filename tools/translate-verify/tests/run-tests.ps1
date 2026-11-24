<#
.SYNOPSIS
    Tests for translate-verify.ps1: each runs the runner on a small fixture module with a scripted
    fake agent (fake-agent.ps1) and the real `checktranslation` from a Masterwork checkout.
.PARAMETER CodeRepoPath
    The Masterwork checkout. Default: the sibling of this repo.
.PARAMETER Filter
    Runs only the tests whose name matches this wildcard.
#>
param(
    [string]$CodeRepoPath = (Join-Path $PSScriptRoot '../../../../Masterwork'),
    [string]$Filter = '*'
)
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot '../translate-verify.ps1'
$fake = Join-Path $PSScriptRoot 'fake-agent.ps1'
$CodeRepoPath = (Resolve-Path $CodeRepoPath).Path
$NB = [char]0x00A0

dotnet build (Join-Path $CodeRepoPath 'src/Masterwork.ModulePacker') -nologo -v q | Out-Null
if ($LASTEXITCODE) { throw 'Building Masterwork.ModulePacker failed.' }

$script:failures = 0
$script:ran = 0
function Test([string]$Name, [scriptblock]$Body) {
    if ($Name -notlike $Filter) { return }
    $script:ran++
    try { & $Body; Write-Host "PASS $Name" -ForegroundColor Green }
    catch { $script:failures++; Write-Host "FAIL $Name`n     $($_.Exception.Message)`n$($_.ScriptStackTrace)" -ForegroundColor Red }
}
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function AssertEqual($Expected, $Actual, [string]$What) {
    if ("$Expected" -cne "$Actual") { throw "$What`n       expected: $Expected`n       actual:   $Actual" }
}

# A three-passage scenario: Hall (official, draft and gap keys), a dev note, and an override passage.
function New-Fixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) "tv-test-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $mod = Join-Path $root 'mini'
    New-Item -ItemType Directory -Force "$mod/passages", "$mod/passages-override", "$mod/.source" | Out-Null
    Set-Content "$mod/en-US.restext" -Encoding utf8 -Value @'
# MasterWork locale file — en-US
# Format: Key=Value  (one string per line)

# Hall strings
Hall_001=Welcome to the hall!
Hall_002=Gain **3 VP** and one {icon:creepy_icon}.
Hall_003=Continue
Shared_Close=Close
NoteOnly_001=A note for authors.
'@
    Set-Content "$mod/en-US.overrides.restext" -Encoding utf8 -Value @'
# Hand-authored overrides.

Setup_Title=The Village
'@
    Set-Content "$mod/fr-CA.restext" -Encoding utf8 -Value @'
# Masterwork locale file — fr-CA

# Hall strings
# origin: official
Hall_001=Bienvenue dans la salle !
# origin: draft
Hall_002=Gagnez **3 PV** et un {icon:creepy_icon}. Continuer
# origin: official
Shared_Close=Fermer
'@
    Set-Content "$mod/passages/00001-Hall.mws.yaml" -Encoding utf8 -Value @'
format: 'mws/0.4'
passage_id: 'Hall'
nodes:
- type: 'text'
  value: 'restext://Hall_001'
- type: 'text'
  value: 'restext://Hall_002'
- type: 'link'
  label: 'restext://Hall_003'
  target: 'Next'
- type: 'link'
  label: 'restext://Shared_Close'
'@
    Set-Content "$mod/passages/00002-9Note.mws.yaml" -Encoding utf8 -Value @'
format: 'mws/0.4'
passage_id: '9Note'
nodes:
- type: 'text'
  value: 'restext://NoteOnly_001'
- type: 'link'
  label: 'restext://Shared_Close'
'@
    Set-Content "$mod/passages-override/_Setup.mws.yaml" -Encoding utf8 -Value @'
format: 'mws/0.4'
passage_id: 'Setup'
title: 'restext://Setup_Title'
nodes:
- type: 'link'
  label: 'restext://Shared_Close'
'@
    Set-Content "$mod/.source/terms.fr-CA.yaml" -Encoding utf8 -Value @'
terms:
  - en: 'Hall'
    fr: 'salle'
    source: '\bhall\b'
    target: 'salle'
'@
    [pscustomobject]@{ Root = $root; Module = $mod; Work = (Join-Path $root 'work'); Log = (Join-Path $root 'agent-log'); Script = (Join-Path $root 'script.json') }
}

function Invoke-Runner($Fixture, [hashtable]$Script = @{}, [hashtable]$Extra = @{}) {
    $Script | ConvertTo-Json -Depth 6 | Set-Content $Fixture.Script -Encoding utf8
    $env:TV_FAKE_SCRIPT = $Fixture.Script
    $env:TV_FAKE_LOG = $Fixture.Log
    $params = @{ Module = $Fixture.Module; WorkDir = $Fixture.Work; CodeRepoPath = $CodeRepoPath; NoBuild = $true; Parallel = 2
        Agent = @('pwsh', '-NoProfile', '-File', $fake) }
    foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] }
    & $runner @params | Out-Null
}

function Get-Calls($Fixture) {
    if (-not (Test-Path $Fixture.Log)) { return @() }
    @(Get-ChildItem $Fixture.Log -Filter *.json | Sort-Object Name | ForEach-Object { Get-Content $_.FullName -Raw -Encoding utf8 | ConvertFrom-Json })
}

# key -> @{ Value; Origin } from a written restext file.
function Read-Written([string]$Path) {
    $map = @{}; $origin = $null
    foreach ($line in Get-Content $Path -Encoding utf8) {
        if ($line -match '^# origin: (.*)$') { $origin = $Matches[1]; continue }
        if ($line -match '^([^#=\s][^=]*)=(.*)$') { $map[$Matches[1]] = @{ Value = $Matches[2]; Origin = $origin }; $origin = $null }
    }
    $map
}

$goodForward = @{ forward = @{
        Hall_002 = @{ fr = 'Gagnez **3 PV** et un {icon:creepy_icon}.'; note = 'Cut the button text.' }
        Hall_003 = @{ fr = 'Continuer' }
        Setup_Title = @{ fr = 'Le Village' }
    } }

Test 'a clean run writes every string with its origin' {
    $f = New-Fixture
    Invoke-Runner $f $goodForward
    $fr = Read-Written "$($f.Module)/fr-CA.restext"
    AssertEqual "Bienvenue dans la salle!" $fr.Hall_001.Value 'official string, typography normalized'
    AssertEqual 'official' $fr.Hall_001.Origin 'normalizing typography keeps the origin'
    AssertEqual 'Gagnez **3 PV** et un {icon:creepy_icon}.' $fr.Hall_002.Value 'draft'
    AssertEqual 'official, revised' $fr.Hall_002.Origin 'a draft becomes official, revised'
    AssertEqual 'agent' $fr.Hall_003.Origin 'a gap is agent'
    AssertEqual 'official' $fr.Shared_Close.Origin 'shared official key'
    Assert (-not $fr.ContainsKey('NoteOnly_001')) 'a dev-note-only key is left out'
    Assert (-not $fr.ContainsKey('Setup_Title')) 'an override key goes to the overrides file'
    $ov = Read-Written "$($f.Module)/fr-CA.overrides.restext"
    AssertEqual 'Le Village' $ov.Setup_Title.Value 'override key'
    AssertEqual 'agent' $ov.Setup_Title.Origin 'override gap origin'
    Assert (Test-Path "$($f.Module)/.source/_translate-report.fr-CA.md") 'the report sits beside the reconciliation report'
}

Test 'a rerun resumes without repeating finished agent calls' {
    $f = New-Fixture
    Invoke-Runner $f $goodForward
    $first = (Get-Calls $f).Count
    Assert ($first -gt 0) 'the first run calls the agent'
    # Restore the input, as if the first run had stopped before writing.
    Copy-Item "$($f.Module)/fr-CA.restext" "$($f.Root)/written.restext"
    Remove-Item "$($f.Module)/fr-CA.overrides.restext"
    $fx = New-Fixture; Copy-Item "$($fx.Module)/fr-CA.restext" "$($f.Module)/fr-CA.restext" -Force
    Invoke-Runner $f $goodForward
    AssertEqual $first (Get-Calls $f).Count 'agent calls after the rerun'
    AssertEqual (Get-Content "$($f.Root)/written.restext" -Raw) (Get-Content "$($f.Module)/fr-CA.restext" -Raw) 'same output'
}

Test 'an edited string reruns only the passage it belongs to' {
    $f = New-Fixture
    Invoke-Runner $f $goodForward
    $before = (Get-Calls $f).Count
    $fx = New-Fixture; Copy-Item "$($fx.Module)/fr-CA.restext" "$($f.Module)/fr-CA.restext" -Force
    Remove-Item "$($f.Module)/fr-CA.overrides.restext"
    (Get-Content "$($f.Module)/en-US.overrides.restext" -Raw) -replace 'The Village', 'The Hamlet' | Set-Content "$($f.Module)/en-US.overrides.restext" -Encoding utf8
    Invoke-Runner $f $goodForward
    $new = @(Get-Calls $f | Select-Object -Skip $before)
    # The French didn't change, so its back-translation stands; the judge sees the new English.
    AssertEqual 'forward,judge' (($new | ForEach-Object stage) -join ',') 'stages rerun'
    Assert (-not ($new | Where-Object { $_.keys -contains 'Hall_001' })) 'the Hall passage is not rerun'
}

Test 'the back-translator sees only French and the reversed term base' {
    $f = New-Fixture
    Invoke-Runner $f $goodForward
    $back = @(Get-Calls $f | Where-Object stage -eq 'back')
    AssertEqual 2 $back.Count 'one back-translation call per passage'
    foreach ($c in $back) {
        foreach ($english in 'Welcome to the hall', 'Gain **3 VP**', 'The Village') {
            Assert (-not $c.prompt.Contains($english)) "the back-translation prompt contains English: $english"
        }
    }
    $hall = @($back | Where-Object { $_.keys -contains 'Hall_001' })[0]
    Assert ($hall.prompt -match '\| salle \| Hall \|') 'scenario terms are reversed (French | English)'
    Assert ($hall.prompt -match '\| Le Secret de mon père \|') 'shared terms are reversed'
    Assert ($hall.prompt.Contains('Bienvenue dans la salle!')) 'the passage French is there'
}

Test 'a typo fix is re-checked deterministically only' {
    $f = New-Fixture
    $s = $goodForward.Clone()
    $s.judge = @{ Hall_001 = @{ verdict = 'fail: typo'; reason = 'salle is fine; test fix'; fix = 'Bienvenue dans la grande salle !' } }
    Invoke-Runner $f $s
    Assert (-not (Get-Calls $f | Where-Object round -eq 2)) 'no second back-translation or judge'
    $fr = Read-Written "$($f.Module)/fr-CA.restext"
    AssertEqual 'Bienvenue dans la grande salle!' $fr.Hall_001.Value 'the fix ships, typography normalized'
    AssertEqual 'official, revised' $fr.Hall_001.Origin 'a fixed official string'
}

Test 'a meaning fix is back-translated and judged again, and a second fail ships as unresolved' {
    $f = New-Fixture
    $s = $goodForward.Clone()
    $s.judge = @{ Hall_003 = @{ verdict = 'fail: meaning'; reason = 'wrong'; fix = 'Poursuivre' }; Shared_Close = @{ verdict = 'fail: term'; reason = 'term'; fix = 'Quitter' } }
    $s.judge2 = @{ Hall_003 = @{ verdict = 'fail: meaning'; reason = 'still wrong'; fix = 'Avancer' } }
    Invoke-Runner $f $s
    $round2 = @(Get-Calls $f | Where-Object round -eq 2)
    AssertEqual 'back,judge' (($round2 | ForEach-Object stage | Select-Object -Unique) -join ',') 'second round stages'
    AssertEqual 'Hall_003,Shared_Close' ((@($round2 | Where-Object stage -eq 'judge')[0].keys | Sort-Object) -join ',') 'only the failed strings are judged again'
    $fr = Read-Written "$($f.Module)/fr-CA.restext"
    AssertEqual 'Poursuivre' $fr.Hall_003.Value 'the latest attempt ships'
    AssertEqual 'Quitter' $fr.Shared_Close.Value 'a revision that passes ships'
    AssertEqual 'official, revised' $fr.Shared_Close.Origin 'revised official'
    $report = Get-Content "$($f.Module)/.source/_translate-report.fr-CA.md" -Raw
    Assert ($report.IndexOf('### `Hall_003`: No French, unresolved') -lt $report.IndexOf('### `Shared_Close`: Official, revised')) 'unresolved strings come first'
    Assert ($report.IndexOf('### `Shared_Close`') -lt $report.IndexOf('## Passed with wording unchanged')) 'changed strings come before passed ones'
    Assert ($report -match '\| No French \| 2 \| 1 \| 0 \| 1 \| 0 \| 0 \|') 'bucket counts'
}

Test 'a fix that breaks a placeholder falls back to the last clean attempt or the input' {
    $f = New-Fixture
    $s = @{ forward = @{ Hall_002 = @{ fr = 'Gagnez **3 PV** et un.' }; Hall_003 = @{ fr = 'Continuer' }; Setup_Title = @{ fr = 'Le Village' } }
        judge = @{
            Hall_002 = @{ verdict = 'fail: integrity'; reason = 'icon lost'; fix = 'Gagnez **3 PV**.' }
            Hall_001 = @{ verdict = 'fail: integrity'; reason = 'test'; fix = 'Bienvenue {x}!' }
        } }
    Invoke-Runner $f $s
    $fr = Read-Written "$($f.Module)/fr-CA.restext"
    AssertEqual 'Gagnez **3 PV** et un {icon:creepy_icon}. Continuer' $fr.Hall_002.Value 'no clean attempt: the draft input is kept'
    AssertEqual 'draft' $fr.Hall_002.Origin 'and stays a draft'
    AssertEqual 'Bienvenue dans la salle!' $fr.Hall_001.Value 'the clean first attempt ships'
    AssertEqual 'official' $fr.Hall_001.Origin 'unchanged official'
}

Test 'a Unity draft makes a missing string unity, revised' {
    $f = New-Fixture
    '{ "Setup_Title": "Le village" }' | Set-Content "$($f.Module)/.source/unity-drafts.fr-CA.json" -Encoding utf8
    Invoke-Runner $f $goodForward
    $forward = @(Get-Calls $f | Where-Object { $_.stage -eq 'forward' -and $_.keys -contains 'Setup_Title' })[0]
    Assert ($forward.prompt.Contains('"unityDraft": "Le village"')) 'the forward agent gets the Unity draft'
    AssertEqual 'unity, revised' (Read-Written "$($f.Module)/fr-CA.overrides.restext").Setup_Title.Origin 'origin'
}

Test 'the scenario term list is mined once and the run can stop to review it' {
    $f = New-Fixture
    Remove-Item "$($f.Module)/.source/terms.fr-CA.yaml"
    $s = @{ 'mine-terms' = @{ '*' = @(
                @{ en = 'Great Hall'; fr = 'Grande salle'; note = '' },
                @{ en = 'Great Hall'; fr = 'grand hall'; note = '' },
                @{ en = 'Great Hall'; fr = 'Grande salle'; note = 'f.' },
                @{ en = 'Round'; fr = 'manche'; note = 'already shared' },
                @{ en = 'Masterworks'; fr = "Chefs-d'œuvre"; note = 'a shared pattern covers it' }) } }
    Invoke-Runner $f $s @{ StopAfter = 'terms' }
    $yaml = Get-Content "$($f.Module)/.source/terms.fr-CA.yaml" -Raw
    Assert ($yaml.Contains("fr: 'Grande salle'")) 'the most frequent French wins'
    Assert ($yaml.Contains('also seen: grand hall')) 'variants are noted'
    Assert (-not $yaml.Contains("'Round'")) 'shared terms are skipped'
    Assert (-not $yaml.Contains("'Masterworks'")) 'terms a shared pattern covers are skipped'
    AssertEqual 'mine-terms' ((Get-Calls $f | ForEach-Object stage) -join ',') 'the run stopped after mining'
    # The written file is a valid term base for the checks too.
    Invoke-Runner $f $goodForward
    Assert ((Get-Calls $f | Where-Object stage -eq 'mine-terms').Count -eq 1) 'mined once'
    Assert (@(Get-Calls $f | Where-Object stage -eq 'judge')[0].prompt.Contains('| Great Hall | Grande salle |')) 'mined terms reach the judge'
}

Test 'the app resx is verified and missing keys are added' {
    $root = Join-Path ([IO.Path]::GetTempPath()) "tv-test-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Force $root | Out-Null
    $enResx = Join-Path $root 'AppStrings.resx'
    Set-Content $enResx -Encoding utf8 -Value @'
<?xml version="1.0" encoding="utf-8"?>
<root>
  <data name="MainMenu_Play" xml:space="preserve"><value>Play</value></data>
  <data name="MainMenu_Help" xml:space="preserve"><value>&lt;b&gt;Help&lt;/b&gt; for {0}</value></data>
  <data name="Help_Title" xml:space="preserve"><value>How to play</value></data>
</root>
'@
    Set-Content (Join-Path $root 'AppStrings.fr-CA.resx') -Encoding utf8 -Value @'
<?xml version="1.0" encoding="utf-8"?>
<root>
  <data name="MainMenu_Play" xml:space="preserve"><value>Jouer</value></data>
  <data name="MainMenu_Help" xml:space="preserve"><value>&lt;b&gt;Aide&lt;/b&gt; pour {0} ?</value></data>
</root>
'@
    $f = [pscustomobject]@{ Root = $root; Work = "$root/work"; Log = "$root/agent-log"; Script = "$root/script.json" }
    @{ forward = @{ Help_Title = @{ fr = 'Comment jouer' } } } | ConvertTo-Json -Depth 5 | Set-Content $f.Script -Encoding utf8
    $env:TV_FAKE_SCRIPT = $f.Script; $env:TV_FAKE_LOG = $f.Log
    & $runner -Resx $enResx -WorkDir $f.Work -CodeRepoPath $CodeRepoPath -NoBuild -Agent pwsh, -NoProfile, -File, $fake | Out-Null
    $text = Get-Content (Join-Path $root 'AppStrings.fr-CA.resx') -Raw
    Assert ($text.Contains('<value>&lt;b&gt;Aide&lt;/b&gt; pour {0}?</value>')) "typography normalized and markup kept:`n$text"
    Assert ($text.Contains('<data name="Help_Title" xml:space="preserve"><value>Comment jouer</value></data>')) 'missing key added'
    Assert (-not $text.Contains('# origin')) 'no origin comments in resx'
    AssertEqual 'forward' (@(Get-Calls $f)[0].stage) 'forward runs for the missing key'
    Assert (Test-Path "$($f.Work)/report.md") 'the app report goes to the work directory'
}

Write-Host "`n$($script:ran - $script:failures)/$($script:ran) passed"
if ($script:failures) { exit 1 }
