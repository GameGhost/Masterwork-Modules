# Stands in for `claude -p` in the tests. Reads the prompt from stdin, answers every string marked
# "translate": true, and prints a result shaped like `claude -p --output-format json`.
#
# TV_FAKE_SCRIPT: optional JSON file of canned answers, { "<stage>[2]": { "<key>": { field: value } } }.
#   Stages: forward, back, judge, mine-terms (key "*"). A "2" suffix answers the revision round.
# TV_FAKE_LOG:    optional directory; one JSON file per call: { stage, round, keys, prompt }.
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
$prompt = [Console]::In.ReadToEnd()
$stage = [regex]::Match($prompt, '<!-- stage: ([\w-]+) -->').Groups[1].Value
$round = if ($prompt -match '<!-- round: 2 -->') { 2 } else { 1 }

$items = @()
$block = [regex]::Match($prompt, '(?s)<!-- strings -->\s*```json\s*(.*?)```')
if ($block.Success) { $items = @($block.Groups[1].Value | ConvertFrom-Json) }
$keys = @($items | Where-Object { $_.PSObject.Properties['translate'] -and $_.translate } | ForEach-Object key)

$script = @{}
if ($env:TV_FAKE_SCRIPT -and (Test-Path $env:TV_FAKE_SCRIPT)) {
    $script = Get-Content $env:TV_FAKE_SCRIPT -Raw | ConvertFrom-Json -AsHashtable
}
$canned = $script[$(if ($round -eq 2) { "${stage}2" } else { $stage })]
if (-not $canned) { $canned = @{} }

function Canned($key, [hashtable]$default) {
    if ($canned.ContainsKey($key)) { foreach ($k in $canned[$key].Keys) { $default[$k] = $canned[$key][$k] } }
    $default
}

$out = switch ($stage) {
    'forward' {
        foreach ($i in $items | Where-Object { $_.key -in $keys }) { Canned $i.key @{ key = $i.key; translation = "FR $($i.en)"; note = '' } }
    }
    'back' {
        foreach ($i in $items | Where-Object { $_.key -in $keys }) { Canned $i.key @{ key = $i.key; en = "BACK $($i.translation)"; note = '' } }
    }
    'judge' {
        foreach ($k in $keys) { Canned $k @{ key = $k; verdict = 'pass'; reason = ''; fix = '' } }
    }
    'mine-terms' { if ($canned.ContainsKey('*')) { $canned['*'] } }
}

if ($env:TV_FAKE_LOG) {
    $line = [ordered]@{ stage = $stage; round = $round; keys = $keys; prompt = $prompt } | ConvertTo-Json -Compress -Depth 4
    New-Item -ItemType Directory -Force $env:TV_FAKE_LOG | Out-Null
    [IO.File]::WriteAllText((Join-Path $env:TV_FAKE_LOG ('{0:d20}-{1}.json' -f [DateTime]::UtcNow.Ticks, [guid]::NewGuid())), $line)
}

$result = [ordered]@{ type = 'result'; is_error = $false; total_cost_usd = 0.01; structured_output = [ordered]@{ items = @($out) } }
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::Out.Write(($result | ConvertTo-Json -Depth 6 -Compress))
