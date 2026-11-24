# Helpers for translate-verify.ps1. See README.md for the process.
Set-StrictMode -Version 3.0
#Requires -Version 7.2
$ErrorActionPreference = 'Stop'

$script:Utf8 = [Text.UTF8Encoding]::new($false)
$script:ChunkSize = 40

#region Restext and resx

# Lines of a restext file in order, its values, and the `# origin:` comment directly above each key.
function Read-Restext([string]$Path) {
    $lines = [Collections.Generic.List[hashtable]]::new()
    $values = [ordered]@{}
    $origins = @{}
    if (Test-Path -LiteralPath $Path) {
        $origin = $null
        foreach ($raw in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
            $line = $raw.TrimStart([char]0xFEFF)
            if ($line.Trim().Length -eq 0) { $lines.Add(@{ Kind = 'blank' }); $origin = $null; continue }
            if ($line.TrimStart().StartsWith('#')) {
                if ($line -match '^\s*#\s*origin:\s*(.+?)\s*$') { $origin = $Matches[1] }
                else { $lines.Add(@{ Kind = 'comment'; Text = $line }); $origin = $null }
                continue
            }
            $eq = $line.IndexOf('=')
            if ($eq -le 0) { throw "${Path}: not a Key=Value line: $line" }
            $key = $line.Substring(0, $eq).Trim()
            $lines.Add(@{ Kind = 'key'; Key = $key })
            $values[$key] = $line.Substring($eq + 1)
            if ($origin) { $origins[$key] = $origin }
            $origin = $null
        }
    }
    @{ Lines = $lines; Values = $values; Origins = $origins }
}

# Writes the entries that appear in the English layout, in its order. The comment block directly
# above a run of keys is its heading, written only when one of those keys is.
function Format-Restext($Layout, [hashtable]$Entries, [string[]]$Header) {
    $sb = [Text.StringBuilder]::new()
    foreach ($h in $Header) { [void]$sb.Append($h).Append("`n") }
    $heading = [Collections.Generic.List[string]]::new()
    $previousWasKey = $false
    $written = @{}
    foreach ($line in $Layout) {
        if ($line.Kind -ne 'key') {
            if ($previousWasKey -or $line.Kind -eq 'blank') { $heading.Clear() }
            if ($line.Kind -eq 'comment') { $heading.Add($line.Text) }
            $previousWasKey = $false
            continue
        }
        $previousWasKey = $true
        $entry = $Entries[$line.Key]
        if (-not $entry -or $written.ContainsKey($line.Key)) { continue }
        $written[$line.Key] = $true
        if ($written.Count -eq 1 -or $heading.Count) { [void]$sb.Append("`n") }
        if ($heading.Count) {
            foreach ($c in $heading) { [void]$sb.Append($c).Append("`n") }
            $heading.Clear()
        }
        if ($entry.Origin) { [void]$sb.Append('# origin: ').Append($entry.Origin).Append("`n") }
        [void]$sb.Append($line.Key).Append('=').Append($entry.Value).Append("`n")
    }
    $sb.ToString()
}

$script:ResxData = [regex]::new('<data\s+name="(?<name>[^"]*)"(?<attrs>[^>]*)>\s*<value>(?<value>.*?)</value>', 'Singleline')

function ConvertFrom-XmlText([string]$Raw) {
    ([xml]"<v xml:space=`"preserve`">$Raw</v>").DocumentElement.InnerText
}
function ConvertTo-XmlText([string]$Value) {
    $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

# The string entries of a resx file, name -> decoded value, in file order.
function Read-Resx([string]$Path) {
    $values = [ordered]@{}
    if (Test-Path -LiteralPath $Path) {
        foreach ($m in $script:ResxData.Matches([IO.File]::ReadAllText($Path))) {
            if ($m.Groups['attrs'].Value -match '\b(type|mimetype)=') { continue }
            $values[$m.Groups['name'].Value] = ConvertFrom-XmlText $m.Groups['value'].Value
        }
    }
    $values
}

# Rewrites changed values in place and adds new keys before </root>, leaving everything else as it was.
function Update-ResxText([string]$Text, [hashtable]$Values) {
    $seen = @{}
    $updated = $script:ResxData.Replace($Text, {
            param($m)
            $name = $m.Groups['name'].Value
            $seen[$name] = $true
            if (-not $Values.ContainsKey($name)) { return $m.Value }
            $v = $m.Groups['value']
            $m.Value.Substring(0, $v.Index - $m.Index) + (ConvertTo-XmlText $Values[$name]) + $m.Value.Substring($v.Index - $m.Index + $v.Length)
        })
    $new = @($Values.Keys | Where-Object { -not $seen.ContainsKey($_) })
    if (-not $new) { return $updated }
    $nl = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $added = ($new | ForEach-Object { "  <data name=`"$_`" xml:space=`"preserve`"><value>$(ConvertTo-XmlText $Values[$_])</value></data>$nl" }) -join ''
    $at = $updated.LastIndexOf('</root>')
    $updated.Substring(0, $at) + $added + $updated.Substring($at)
}

function Format-ResxFile([Collections.IDictionary]$Values) {
    $sb = [Text.StringBuilder]::new("<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<root>`n")
    foreach ($k in $Values.Keys) { [void]$sb.Append("  <data name=`"$k`" xml:space=`"preserve`"><value>$(ConvertTo-XmlText $Values[$k])</value></data>`n") }
    [void]$sb.Append("</root>`n")
    $sb.ToString()
}

#endregion

#region Scope: which strings a run covers

# Same rule as Masterwork.Extractor reconcile: authoring notes left in the Cradle scripts.
function Test-DevNotePassage([string]$Id, [string[]]$Tags) {
    $Id -match '(?i)note|example' -or ($Id -replace ' ', '') -match '(?i)^VariableList' -or
    $Id -cin 'Extra Code', 'DECREESLIST', 'OUTDATEDFirstPara', 'FixIt' -or ($Tags | Where-Object { $_ -ieq 'NOTE' })
}

# Passages in load order: passages/ by file name, then passages-override/ (same id replaces in place).
function Get-Passages([string]$ModuleDir) {
    $byId = [ordered]@{}
    foreach ($dir in 'passages', 'passages-override') {
        $path = Join-Path $ModuleDir $dir
        if (-not (Test-Path $path)) { continue }
        foreach ($f in Get-ChildItem $path -Filter '*.mws.yaml' | Sort-Object Name) {
            $text = [IO.File]::ReadAllText($f.FullName)
            $idMatch = [regex]::Match($text, "(?m)^passage_id:\s*(?:'((?:[^']|'')*)'|`"([^`"]*)`"|(\S.*?))\s*$")
            $id = if ($idMatch.Success) { (($idMatch.Groups[1..3] | Where-Object Success | Select-Object -First 1).Value) -replace "''", "'" } else { $f.BaseName -replace '\.mws$', '' }
            $tags = @()
            $block = [regex]::Match($text, "(?m)^tags:[ \t]*\r?\n((?:[ \t]*-[^\r\n]*(?:\r?\n|$))+)")
            if ($block.Success) { $tags = @([regex]::Matches($block.Groups[1].Value, "-\s*['`"]?([^'`"\r\n]*)") | ForEach-Object { $_.Groups[1].Value.Trim() }) }
            $inline = [regex]::Match($text, '(?m)^tags:\s*\[(.*)\]')
            if ($inline.Success) { $tags = @($inline.Groups[1].Value -split ',' | ForEach-Object { $_.Trim(" '`"") }) }
            $keys = @([regex]::Matches($text, 'restext://([A-Za-z0-9_\-]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            $byId[$id] = @{ Id = $id; Keys = $keys; DevNote = [bool](Test-DevNotePassage $id $tags) }
        }
    }
    @($byId.Values)
}

# Consecutive slices of at most $Size items, each emitted as one array.
function Split-Chunks($Items, [int]$Size) {
    $Items = @($Items)
    for ($i = 0; $i -lt $Items.Count; $i += $Size) { , @($Items[$i..([Math]::Min($i + $Size, $Items.Count) - 1)]) }
}

function New-UnitId([int]$Index, [string]$Name) {
    '{0:d4}-{1}' -f $Index, ($Name -replace '[^A-Za-z0-9_\-]', '_')
}

# Every string a scenario run covers, grouped into units of work (one per passage).
# Bucket: verify (has French), draft (reconcile's `draft`), gap (no French).
function Get-ModuleScope([string]$ModuleDir, [string]$Locale, [hashtable]$UnityDrafts) {
    $enMain = Read-Restext (Join-Path $ModuleDir 'en-US.restext')
    $enOv = Read-Restext (Join-Path $ModuleDir 'en-US.overrides.restext')
    $frMain = Read-Restext (Join-Path $ModuleDir "$Locale.restext")
    $frOv = Read-Restext (Join-Path $ModuleDir "$Locale.overrides.restext")

    $en = [ordered]@{}; $file = @{}
    foreach ($k in $enMain.Values.Keys) { $en[$k] = $enMain.Values[$k]; $file[$k] = 'main' }
    foreach ($k in $enOv.Values.Keys) { $en[$k] = $enOv.Values[$k]; $file[$k] = 'overrides' }
    $fr = @{}; $frOrigin = @{}
    foreach ($src in $frMain, $frOv) { foreach ($k in $src.Values.Keys) { $fr[$k] = $src.Values[$k]; $frOrigin[$k] = $src.Origins[$k] } }

    $passages = Get-Passages $ModuleDir
    $usedBy = @{}; $usedAny = @{}
    foreach ($p in $passages) {
        foreach ($k in $p.Keys) {
            $usedAny[$k] = $true
            if (-not $p.DevNote) { if (-not $usedBy.ContainsKey($k)) { $usedBy[$k] = [Collections.Generic.List[string]]::new() }; $usedBy[$k].Add($p.Id) }
        }
    }
    $inScope = { param($k) -not ($usedAny.ContainsKey($k) -and -not $usedBy.ContainsKey($k)) }

    $units = [Collections.Generic.List[hashtable]]::new()
    $unitOf = @{}
    foreach ($p in $passages | Where-Object { -not $_.DevNote }) {
        $context = @($p.Keys | Where-Object { $en.Contains($_) })
        $owned = @($context | Where-Object { -not $unitOf.ContainsKey($_) })
        if (-not $owned) { continue }
        $id = New-UnitId ($units.Count + 1) $p.Id
        foreach ($k in $owned) { $unitOf[$k] = $id }
        $units.Add(@{ Id = $id; Name = $p.Id; Keys = $owned; Context = $context })
    }
    $loose = @($en.Keys | Where-Object { -not $unitOf.ContainsKey($_) -and (& $inScope $_) })
    foreach ($chunk in @(Split-Chunks $loose $script:ChunkSize)) {
        $id = New-UnitId ($units.Count + 1) 'Unplaced'
        foreach ($k in $chunk) { $unitOf[$k] = $id }
        $units.Add(@{ Id = $id; Name = 'strings used outside passages'; Keys = $chunk; Context = $chunk })
    }

    $records = [ordered]@{}
    $preserved = @{}
    foreach ($k in $en.Keys) {
        if (-not $unitOf.ContainsKey($k)) {
            if ($fr.ContainsKey($k)) { $preserved[$k] = @{ Value = $fr[$k]; Origin = $frOrigin[$k]; File = $file[$k] } }
            continue
        }
        $origin = $frOrigin[$k]
        $bucket = if (-not $fr.ContainsKey($k)) { 'gap' } elseif ($origin -eq 'draft') { 'draft' } else { 'verify' }
        $records[$k] = @{
            Key = $k; En = $en[$k]; Fr = $fr[$k]; Origin = $origin; Bucket = $bucket; File = $file[$k]; Unit = $unitOf[$k]
            Unity = if ($bucket -eq 'gap' -and $UnityDrafts -and $UnityDrafts.ContainsKey($k)) { $UnityDrafts[$k] } else { $null }
            Passages = @(if ($usedBy.ContainsKey($k)) { $usedBy[$k] })
        }
    }
    @{ Kind = 'restext'; Records = $records; Units = $units; Preserved = $preserved; MainLayout = $enMain.Lines; OverridesLayout = $enOv.Lines
        HasOverrides = (Test-Path (Join-Path $ModuleDir "$Locale.overrides.restext")) }
}

# The app UI: one unit per key prefix (MainMenu_, Help_, …), split into chunks.
function Get-ResxScope([string]$EnglishPath, [string]$LocalePath) {
    $en = Read-Resx $EnglishPath
    $fr = Read-Resx $LocalePath
    $groups = [ordered]@{}
    foreach ($k in $en.Keys) {
        $prefix = ($k -split '_', 2)[0]
        if (-not $groups.Contains($prefix)) { $groups[$prefix] = [Collections.Generic.List[string]]::new() }
        $groups[$prefix].Add($k)
    }
    $units = [Collections.Generic.List[hashtable]]::new()
    $records = [ordered]@{}
    foreach ($prefix in $groups.Keys) {
        foreach ($chunk in @(Split-Chunks @($groups[$prefix]) $script:ChunkSize)) {
            $id = New-UnitId ($units.Count + 1) $prefix
            $units.Add(@{ Id = $id; Name = "app strings $prefix*"; Keys = $chunk; Context = $chunk })
            foreach ($k in $chunk) {
                $records[$k] = @{ Key = $k; En = $en[$k]; Fr = $fr[$k]; Origin = $null; Bucket = $(if ($fr.Contains($k)) { 'verify' } else { 'gap' })
                    File = 'resx'; Unit = $id; Unity = $null; Passages = @() }
            }
        }
    }
    @{ Kind = 'resx'; Records = $records; Units = $units; Preserved = @{} }
}

#endregion

#region Term base

function ConvertFrom-YamlScalar([string]$s) {
    $s = $s.Trim()
    if ($s.StartsWith("'")) { return $s.Substring(1, $s.LastIndexOf("'") - 1).Replace("''", "'") }
    if ($s.StartsWith('"')) { return ($s.Substring(1, $s.LastIndexOf('"') - 1) -replace '\\"', '"' -replace '\\\\', '\') }
    ($s -replace '\s+#.*$', '').Trim()
}

# Reads the fields the agents use (en, fr, note) from a term-base YAML file written in this tool's
# shape: `terms:` entries of `key: scalar` lines, and a `forbidden:` list. The checks read the
# same file's `source`/`target` patterns themselves.
function Read-TermBase([string]$Path) {
    $terms = [Collections.Generic.List[hashtable]]::new()
    $forbidden = [Collections.Generic.List[string]]::new()
    $section = $null; $entry = $null
    foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^(\w+):\s*(\[\s*\])?\s*$') { $section = $Matches[1]; $entry = $null; continue }
        if ($section -eq 'forbidden' -and $line -match '^\s*-\s+(.*)$') { $forbidden.Add((ConvertFrom-YamlScalar $Matches[1])); continue }
        if ($section -ne 'terms') { continue }
        if ($line -match '^\s*-\s+(\w+):\s*(.*)$') { $entry = @{}; $terms.Add($entry); $entry[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2]; continue }
        if ($entry -and $line -match '^\s+(\w+):\s*(.*)$') { $entry[$Matches[1]] = ConvertFrom-YamlScalar $Matches[2]; continue }
        throw "${Path}: can't read line: $line"
    }
    foreach ($t in $terms) { if (-not ($t['en'] -and $t['fr'])) { throw "${Path}: every term needs 'en' and 'fr' for the agents (entry with source '$($t['source'])')." } }
    @{ Terms = $terms; Forbidden = $forbidden }
}

function ConvertTo-MarkdownCell([string]$s) { ($s -replace '\|', '\|').Trim() }

# Term tables for the prompts. Reversed (French → English) for the blind back-translator.
function Format-TermTable($Layers, [switch]$Reversed) {
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($layer in $Layers) {
        if (-not $layer.Base.Terms.Count) { continue }
        $lines.Add("### $($layer.Title)"); $lines.Add('')
        if ($Reversed) {
            $lines.Add('| French | English |'); $lines.Add('|---|---|')
            foreach ($t in $layer.Base.Terms) { $lines.Add("| $(ConvertTo-MarkdownCell $t.fr) | $(ConvertTo-MarkdownCell $t.en) |") }
        }
        else {
            $lines.Add('| English | French | Notes |'); $lines.Add('|---|---|---|')
            foreach ($t in $layer.Base.Terms) { $lines.Add("| $(ConvertTo-MarkdownCell $t.en) | $(ConvertTo-MarkdownCell $t.fr) | $(ConvertTo-MarkdownCell ($t['note'] ?? '')) |") }
        }
        $lines.Add('')
    }
    if (-not $lines.Count) { return '(none)' }
    $lines -join "`n"
}

function Format-Forbidden($Layers) {
    $all = @($Layers | ForEach-Object { $_.Base.Forbidden })
    if (-not $all) { return '(none)' }
    ($all | ForEach-Object { "- ``$_``" }) -join "`n"
}

function ConvertTo-YamlQuoted([string]$s) { "'" + $s.Replace("'", "''") + "'" }
function ConvertTo-RegexLiteral([string]$s) { [regex]::Replace($s, '[\\.*+?()\[\]{}|^$#]', '\$0') }

# Merges the mined terms: one entry per English term (its most frequent French), skipping terms
# the shared base already has.
function Merge-MinedTerms($Items, $Shared) {
    $known = @{}
    foreach ($t in $Shared.Terms) { $known[$t.en.ToLowerInvariant()] = $true }
    $sharedSources = @($Shared.Terms | Where-Object { $_['source'] } | ForEach-Object { [regex]::new($_.source, 'IgnoreCase') })
    $byEn = [ordered]@{}
    foreach ($i in $Items) {
        $en = "$($i.en)".Trim(); $fr = "$($i.fr)".Trim()
        if (-not $en -or -not $fr -or $known.ContainsKey($en.ToLowerInvariant())) { continue }
        # A shared term's own pattern covers it ("Masterwork", "VP", "Round"), whatever its label says.
        if ($sharedSources | Where-Object { $_.Match($en).Value -eq $en }) { continue }
        $k = $en.ToLowerInvariant()
        if (-not $byEn.Contains($k)) { $byEn[$k] = @{ En = $en; Fr = @{}; Note = '' } }
        $byEn[$k].Fr[$fr] = 1 + ($byEn[$k].Fr[$fr] ?? 0)
        if (-not $byEn[$k].Note -and $i['note']) { $byEn[$k].Note = "$($i.note)".Trim() }
    }
    foreach ($e in $byEn.Values | Sort-Object { $_.En }) {
        $fr = ($e.Fr.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
        $others = @($e.Fr.Keys | Where-Object { $_ -cne $fr })
        $note = (@($e.Note) + @($others | ForEach-Object { "also seen: $_" }) | Where-Object { $_ }) -join '; '
        @{ en = $e.En; fr = $fr; note = $note }
    }
}

function Format-MinedTermBase($Terms, [string]$Title, [string]$Locale) {
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("# Per-scenario $Locale term base: $Title. Mined by tools/translate-verify from the scenario's")
    $lines.Add('# official aligned pairs: card, place and character names the agents would otherwise invent.')
    $lines.Add('# Review it before the forward stage. The shared game terms are in tools/translate-verify.')
    $lines.Add('terms:')
    foreach ($t in $Terms) {
        $edgeL = if ($t.en -match '^\w') { '\b' } else { '' }
        $edgeR = if ($t.en -match '\w$') { '\b' } else { '' }
        $lines.Add("  - en: $(ConvertTo-YamlQuoted $t.en)")
        $lines.Add("    fr: $(ConvertTo-YamlQuoted $t.fr)")
        if ($t.note) { $lines.Add("    note: $(ConvertTo-YamlQuoted $t.note)") }
        $lines.Add("    from: 'mined'")
        $lines.Add("    source: $(ConvertTo-YamlQuoted "$edgeL$(ConvertTo-RegexLiteral $t.en)$edgeR")")
        $lines.Add("    target: $(ConvertTo-YamlQuoted (ConvertTo-RegexLiteral $t.fr))")
    }
    if (-not $Terms) { $lines[$lines.Count - 1] = 'terms: []' }
    ($lines -join "`n") + "`n"
}

#endregion

#region Agent calls

function Get-TextHash([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:Utf8.GetBytes($Text))).Substring(0, 16)
}

# Runs one headless agent call per job and stores each answer in its OutFile with a hash of the
# exact request. A job whose stored hash matches is skipped, so an interrupted run resumes, and a
# changed input (an edited string, a new term) reruns only what it affects.
# Job: @{ Stage; Name; Prompt; System; Schema; OutFile; ExpectedKeys (or $null) }
function Invoke-AgentJobs {
    param($Jobs, [string[]]$Agent, [string]$Model, [int]$Parallel, [int]$TimeoutMinutes, [string]$Cwd, [int]$Attempts = 2)
    $results = @{}
    $pending = [Collections.Generic.List[hashtable]]::new()
    foreach ($job in $Jobs) {
        $job.Hash = Get-TextHash ("$($job.Stage)`n$Model`n$($Agent -join ' ')`n$($job.System)`n$($job.Schema)`n$($job.Prompt)")
        if (Test-Path -LiteralPath $job.OutFile) {
            $stored = [IO.File]::ReadAllText($job.OutFile) | ConvertFrom-Json -AsHashtable
            if ($stored.hash -eq $job.Hash) { $results[$job.OutFile] = $stored; continue }
        }
        $pending.Add($job)
    }
    if ($pending.Count) { Write-Host "  $($pending.Count) agent call(s), $($Jobs.Count - $pending.Count) already done" }

    for ($attempt = 1; $attempt -le $Attempts -and $pending.Count; $attempt++) {
        New-Item -ItemType Directory -Force -Path ($pending | ForEach-Object { Split-Path $_.OutFile }) | Out-Null
        $pending | ForEach-Object -ThrottleLimit ([Math]::Max(1, $Parallel)) -Parallel {
            $job = $_
            $agent = $using:Agent
            $psi = [Diagnostics.ProcessStartInfo]::new($agent[0])
            foreach ($a in @($agent | Select-Object -Skip 1) + @('-p', '--output-format', 'json', '--tools', '', '--no-session-persistence',
                    '--strict-mcp-config', '--system-prompt', $job.System, '--json-schema', $job.Schema)) { $psi.ArgumentList.Add($a) }
            if ($using:Model) { $psi.ArgumentList.Add('--model'); $psi.ArgumentList.Add($using:Model) }
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
            $utf8 = [Text.UTF8Encoding]::new($false)
            $psi.StandardInputEncoding = $utf8; $psi.StandardOutputEncoding = $utf8; $psi.StandardErrorEncoding = $utf8
            $psi.WorkingDirectory = $using:Cwd
            $raw = "$($job.OutFile).raw"; $err = "$($job.OutFile).err"
            Remove-Item -LiteralPath $raw, $err -ErrorAction SilentlyContinue
            try {
                $p = [Diagnostics.Process]::Start($psi)
                $out = $p.StandardOutput.ReadToEndAsync(); $se = $p.StandardError.ReadToEndAsync()
                $p.StandardInput.Write($job.Prompt); $p.StandardInput.Close()
                if (-not $p.WaitForExit([int]($using:TimeoutMinutes) * 60000)) { $p.Kill($true); throw "timed out after $($using:TimeoutMinutes) min" }
                $p.WaitForExit()
                if ($p.ExitCode -ne 0) { throw "exit code $($p.ExitCode): $($se.Result) $($out.Result)" }
                [IO.File]::WriteAllText($raw, $out.Result, $utf8)
            }
            catch { [IO.File]::WriteAllText($err, "$_", $utf8) }
        }

        $failed = [Collections.Generic.List[hashtable]]::new()
        foreach ($job in $pending) {
            $raw = "$($job.OutFile).raw"
            try {
                if (-not (Test-Path -LiteralPath $raw)) { throw (Get-Content -LiteralPath "$($job.OutFile).err" -Raw -ErrorAction SilentlyContinue) }
                $r = [IO.File]::ReadAllText($raw) | ConvertFrom-Json -AsHashtable
                if ($r['is_error']) { throw "agent error: $($r['result'])" }
                if ($null -eq $r['structured_output'] -or $null -eq $r['structured_output']['items']) { throw 'no structured output in the answer' }
                $items = @($r['structured_output']['items'])
                if ($null -ne $job.ExpectedKeys) {
                    $got = @($items | ForEach-Object { $_['key'] })
                    $missing = @($job.ExpectedKeys | Where-Object { $_ -cnotin $got })
                    $extra = @($got | Where-Object { $_ -cnotin $job.ExpectedKeys })
                    $dupes = @($got | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
                    if ($missing -or $extra -or $dupes) { throw "answer keys don't match: missing [$($missing -join ', ')], unexpected [$($extra -join ', ')], repeated [$($dupes -join ', ')]" }
                }
                $stored = [ordered]@{ hash = $job.Hash; stage = $job.Stage; unit = $job.Name; cost = $r['total_cost_usd'] ?? 0; items = $items }
                [IO.File]::WriteAllText($job.OutFile, ($stored | ConvertTo-Json -Depth 8), $script:Utf8)
                Remove-Item -LiteralPath $raw, "$($job.OutFile).err" -ErrorAction SilentlyContinue
                $results[$job.OutFile] = $stored | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable
            }
            catch {
                [IO.File]::WriteAllText("$($job.OutFile).err", "$_", $script:Utf8)
                Remove-Item -LiteralPath $raw -ErrorAction SilentlyContinue
                if ($attempt -eq $Attempts) { Write-Warning "$($job.Stage) $($job.Name): $_" }
                $failed.Add($job)
            }
        }
        $pending = $failed
    }
    if ($pending.Count) {
        throw "$($pending.Count) agent call(s) failed; see the .err files under the work directory. Rerun to retry; finished calls are kept."
    }
    $results
}

#endregion

#region Checks

# Runs `checktranslation --fix` over candidate strings. Returns key -> @{ Fr (fixed); Fixed; Failures; Flags }.
function Invoke-Checks {
    param([string]$Name, [string]$Kind, [string]$Locale, $Pairs, [string[]]$TermBases, [string]$WorkDir, [string[]]$Checker)
    $dir = Join-Path $WorkDir "checks/$Name"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $result = @{}
    $en = [ordered]@{}; $fr = [ordered]@{}
    foreach ($p in $Pairs) {
        $en[$p.Key] = $p.En
        if ($p.Fr -match '[\r\n]') { $result[$p.Key] = @{ Fr = $p.Fr; Fixed = $false; Failures = @('multi-line: the translation has a line break'); Flags = @() } }
        elseif ($null -ne $p.Fr) { $fr[$p.Key] = $p.Fr }
    }
    if ($Kind -eq 'resx') {
        $src = Join-Path $dir 'AppStrings.resx'; $tgt = Join-Path $dir "AppStrings.$Locale.resx"
        [IO.File]::WriteAllText($src, (Format-ResxFile $en), $script:Utf8)
        [IO.File]::WriteAllText($tgt, (Format-ResxFile $fr), $script:Utf8)
    }
    else {
        $src = Join-Path $dir 'en-US.restext'; $tgt = Join-Path $dir "$Locale.restext"
        [IO.File]::WriteAllText($src, (($en.Keys | ForEach-Object { "$_=$($en[$_])`n" }) -join ''), $script:Utf8)
        [IO.File]::WriteAllText($tgt, (($fr.Keys | ForEach-Object { "$_=$($fr[$_])`n" }) -join ''), $script:Utf8)
    }
    $json = Join-Path $dir 'report.json'
    $checkArgs = @('checktranslation', $src, $tgt, '--locale', $Locale, '--fix', '--json', $json)
    foreach ($t in $TermBases) { $checkArgs += @('--termbase', $t) }
    $output = & $Checker[0] @($Checker | Select-Object -Skip 1) @checkArgs 2>&1
    if ($LASTEXITCODE -gt 1 -or -not (Test-Path $json)) { throw "checktranslation failed (exit $LASTEXITCODE):`n$($output -join "`n")" }
    $report = [IO.File]::ReadAllText($json) | ConvertFrom-Json -AsHashtable
    if ($report.fileProblems) { throw "checktranslation found file problems in ${tgt}: $($report.fileProblems | ConvertTo-Json -Compress)" }
    foreach ($s in $report.strings) {
        if ($result.ContainsKey($s.key) -or $null -eq $s.target) { continue }
        $result[$s.key] = @{
            Fr = $s.target; Fixed = [bool]$s.fixed
            Failures = @($s.failures | ForEach-Object { "$($_.check): $($_.detail)" })
            Flags = @($s.flags | ForEach-Object { "$($_.check): $($_.detail)" })
        }
    }
    $result
}

#endregion

#region Prompts

function Format-Prompt([string]$Template, [hashtable]$Values) {
    $text = [IO.File]::ReadAllText($Template)
    foreach ($k in $Values.Keys) { $text = $text.Replace("{{$k}}", [string]$Values[$k]) }
    $text
}

function ConvertTo-PromptJson($Items) { ConvertTo-Json -InputObject @($Items) -Depth 6 }

$script:Schemas = @{
    forward = '{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","properties":{"key":{"type":"string"},"fr":{"type":"string"},"note":{"type":"string"}},"required":["key","fr","note"]}}},"required":["items"]}'
    back    = '{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","properties":{"key":{"type":"string"},"en":{"type":"string"},"note":{"type":"string"}},"required":["key","en","note"]}}},"required":["items"]}'
    judge   = '{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","properties":{"key":{"type":"string"},"verdict":{"type":"string","enum":["pass","fail: meaning","fail: typo","fail: term","fail: integrity"]},"reason":{"type":"string"},"fix":{"type":"string"}},"required":["key","verdict","reason","fix"]}}},"required":["items"]}'
    mine    = '{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","properties":{"en":{"type":"string"},"fr":{"type":"string"},"note":{"type":"string"}},"required":["en","fr","note"]}}},"required":["items"]}'
}
function Get-Schema([string]$Stage) { $script:Schemas[$Stage] }

#endregion

#region Report

function Format-ReportText($s) {
    if ($null -eq $s) { return '—' }
    $v = "$s".Replace([string][char]0x00A0, '⍽')
    if ($v.Contains('`')) { '`` ' + $v + ' ``' } else { '`' + $v + '`' }
}

function Get-BucketLabel($Rec, [string]$Kind) {
    switch ($Rec.Bucket) {
        'draft' { 'Draft' }
        'gap' { if ($Rec.Unity) { 'No French, Unity draft' } else { 'No French' } }
        default { if ($Kind -eq 'resx') { 'Existing' } elseif ($Rec.Origin -eq 'official' -or -not $Rec.Origin) { 'Official' } else { "Verified ($($Rec.Origin))" } }
    }
}

function Format-Checks($Checks) {
    if (-not $Checks) { return '—' }
    $parts = @($Checks.Failures | ForEach-Object { "**$_**" }) + @($Checks.Flags)
    $text = if ($parts) { $parts -join '; ' } else { 'clean' }
    if ($Checks.Fixed) { $text += ' (typography normalized)' }
    $text
}

# Bucket counts, then changed or failed strings (unresolved first), then passed ones.
function Format-Report {
    param($Records, [string]$Title, [string]$Locale, [int]$Calls, [double]$Cost, [string]$Kind)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("# $Locale translate-verify report: $Title"); $lines.Add('')
    $lines.Add('Generated by `tools/translate-verify` in Masterwork-Modules. Each string went through the deterministic checks (`checktranslation`), a blind back-translation and a judge. A failed string got one revision round: typo and integrity fixes are re-checked deterministically, meaning and term fixes are back-translated and judged again. `⍽` marks a non-breaking space; **bold** check results are hard failures.')
    $lines.Add('')
    $lines.Add(('Agent calls: {0}. Reported cost: ${1:N2}.' -f $Calls, $Cost)); $lines.Add('')
    $lines.Add('## Summary'); $lines.Add('')
    $lines.Add('| Bucket | Strings | Passed first time | Revised | Unresolved | Input kept | Typography normalized |')
    $lines.Add('|---|---:|---:|---:|---:|---:|---:|')
    $groups = @($Records | Group-Object { Get-BucketLabel $_ $Kind })
    foreach ($g in $groups + @([pscustomobject]@{ Name = '**Total**'; Group = $Records; Count = @($Records).Count })) {
        $c = { param($f) @($g.Group | Where-Object $f).Count }
        $lines.Add("| $($g.Name) | $($g.Count) | $(& $c { $_.Status -eq 'pass' }) | $(& $c { $_.Status -eq 'revised' }) | $(& $c { $_.Status -eq 'unresolved' }) | $(& $c { $_.KeptInput }) | $(& $c { $_.Checks1 -and $_.Checks1.Fixed }) |")
    }
    $lines.Add('')
    $lines.Add('An unresolved string ships its latest attempt that passes the hard checks. When no attempt does, the input is kept: a draft stays `draft`, a missing string stays missing and the app falls back to English.')
    $lines.Add('')

    $changed = { $_.Status -ne 'pass' -or $_.Bucket -ne 'verify' -or ($null -ne $_.Final -and $_.Final -cne $_.Cand1) }
    $rank = @{ unresolved = 0; revised = 1; pass = 2 }
    $sections = @(
        @{ Title = 'Changed or failed'; Items = @($Records | Where-Object $changed | Sort-Object { $rank[$_.Status] }, { [array]::IndexOf($Records, $_) }) }
        @{ Title = 'Passed with wording unchanged'; Items = @($Records | Where-Object { -not (& $changed) }) }
    )
    foreach ($s in $sections) {
        $lines.Add("## $($s.Title) ($($s.Items.Count))"); $lines.Add('')
        foreach ($r in $s.Items) {
            $lines.Add("### ``$($r.Key)``: $(Get-BucketLabel $r $Kind), $($r.Status)"); $lines.Add('')
            if ($r.Passages.Count) { $lines.Add("- **Passage:** $($r.Passages -join ', ')") }
            if ($Kind -ne 'resx') { $lines.Add("- **Origin:** $($r.FinalOrigin ?? 'not written')") }
            $lines.Add("- **English:** $(Format-ReportText $r.En)")
            if ($r.Bucket -ne 'verify' -and $null -ne $r.Fr) { $lines.Add("- **Official French (input):** $(Format-ReportText $r.Fr)") }
            if ($r.Unity) { $lines.Add("- **Unity draft:** $(Format-ReportText $r.Unity)") }
            $lines.Add("- **French:** $(Format-ReportText $r.Cand1)")
            $lines.Add("- **Back-translation:** $(Format-ReportText $r.Back1)$(if ($r.BackNote1) { " ($($r.BackNote1))" })")
            $lines.Add("- **Verdict:** $($r.Judge1.verdict)$(if ($r.Judge1.reason) { " — $($r.Judge1.reason)" })")
            $lines.Add("- **Checks:** $(Format-Checks $r.Checks1)")
            if ($null -ne $r.Fix) {
                $lines.Add("- **Revision:** $(Format-ReportText $r.Cand2)")
                $lines.Add("  - **Checks:** $(Format-Checks $r.Checks2)")
                if ($r.Judge2) {
                    $lines.Add("  - **Back-translation:** $(Format-ReportText $r.Back2)$(if ($r.BackNote2) { " ($($r.BackNote2))" })")
                    $lines.Add("  - **Verdict:** $($r.Judge2.verdict)$(if ($r.Judge2.reason) { " — $($r.Judge2.reason)" })")
                }
                else { $lines.Add('  - Re-checked deterministically only.') }
            }
            if ($r.Status -eq 'unresolved') {
                $shipped = if ($r.KeptInput) { if ($null -ne $r.Written) { "input kept: $(Format-ReportText $r.Written)" } else { 'not written (English fallback)' } } else { Format-ReportText $r.Written }
                $lines.Add("- **Unresolved:** $($r.Problem) Ships: $shipped")
            }
            if ($r.ForwardNote) { $lines.Add("- **Translator note:** $($r.ForwardNote)") }
            $lines.Add('')
        }
    }
    ($lines -join "`n")
}

#endregion

Export-ModuleMember -Function *
