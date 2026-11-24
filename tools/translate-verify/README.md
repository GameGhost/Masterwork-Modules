# translate-verify

Translates a scenario's strings, or the app's interface strings, into another language and checks
every one by round trip. It's the agent pass of the French (fr-CA) work: it revises the official
drafts that reconciliation left, writes the strings that have no official French, and verifies the
official ones. The process was decided in
[GameGhost/Masterwork#23](https://github.com/GameGhost/Masterwork/issues/23).

## What it does

For one scenario (or the app), in this order:

| Stage | Who | What |
|---|---|---|
| terms | agent, once per scenario | Mines the scenario's own names (cards, places, characters) from its official English–French pairs into `.source/terms.<locale>.yaml`. |
| forward | agent, per passage | Writes French for every `draft` and missing string, a whole passage at a time, given the passage's aligned French. |
| checks | `checktranslation --fix` | Normalizes typography, then runs the integrity and term checks. |
| back | agent, per passage | Translates the French back into English, blind: it sees only the French, its passage and the term base reversed. |
| judge | agent, per passage | Compares English, back-translation and French. Verdict per string, with a minimal fix for every fail. |
| revision | checks, then agents | Typo and integrity fixes are re-checked deterministically only. Meaning and term fixes are back-translated and judged once more. |
| write | — | The locale file with `# origin:` comments, and the report. |

Every agent stage is a separate headless `claude -p` call, with no tools and no project context.

Verdicts are `pass`, `fail: meaning`, `fail: typo`, `fail: term` and `fail: integrity`. Official
strings keep their wording unless they fail. A change of mood in official narration fails on
meaning. Any hard check failure stops a string from passing.

After one revision round a string that still fails is **unresolved**. It ships its latest attempt
that passes the hard checks. If none does, the input is kept rather than ship a broken placeholder
or marker: a draft stays `draft` (so the next run picks it up again), and a missing string stays
missing, so the app falls back to English. Fix such strings by hand and run again.

## Before you run it

- PowerShell 7.2 or later.
- [Claude Code](https://claude.com/claude-code), signed in, with `claude` on the `PATH` (or pass `-Agent`).
- The .NET SDK and a [Masterwork](https://github.com/GameGhost/Masterwork) checkout beside this
  repo (or pass `-CodeRepoPath`). The runner builds its `Masterwork.ModulePacker`, whose
  `checktranslation` command runs the checks (`docs/translation-checks.md` there).
- For a scenario: its starting `fr-CA.restext` from `Masterwork.Extractor reconcile`
  (`docs/extractor.md` in Masterwork). Without it every string is written from scratch.

## Running it

A scenario. Mine its term list first and review it, since every later stage uses it:

```powershell
./tools/translate-verify/translate-verify.ps1 -Module a-time-of-war -StopAfter terms
# review and commit a-time-of-war/.source/terms.fr-CA.yaml, then:
./tools/translate-verify/translate-verify.ps1 -Module a-time-of-war
```

The app's interface strings:

```powershell
./tools/translate-verify/translate-verify.ps1 -Resx <Masterwork>/src/Masterwork.App.Shared/Resources/AppStrings.resx
```

| Option | Effect |
|---|---|
| `-Locale` | Default `fr-CA`. Needs `terms.<locale>.yaml` and `style.<locale>.md` here. |
| `-Model` | Passed to `claude` as `--model`. Default: Claude Code's own default. |
| `-Parallel` | Agent calls at once. Default 4. |
| `-StopAfter terms` / `forward` | Stop after mining the term list, or after the drafts. |
| `-UnityDrafts <json>` | Key → Unity app French, used as drafts for missing strings. Default: `.source/unity-drafts.<locale>.json` if present. |
| `-WorkDir` | Stage outputs. Default `.translate-verify/<module>/<locale>/` (gitignored). |
| `-Report` | Default `<module>/.source/_translate-report.<locale>.md`, beside the reconciliation report. For the app, `report.md` in the work directory. |
| `-CodeRepoPath`, `-NoBuild` | The Masterwork checkout; skip rebuilding the packer. |
| `-Agent` | The agent command and leading arguments, instead of `claude`. |
| `-TimeoutMinutes` | How long one agent call may run before it's stopped and retried. Default 20. |

A full scenario is about three calls per passage, around a thousand for an official scenario.

### Stopping and resuming

Each agent answer is saved under the work directory with a hash of its exact request. Run the same
command again and finished calls are skipped, so an interrupted or failed run picks up where it
stopped. A call whose input changed (an edited string or term, a new forward draft) runs again, and
only that one: unchanged French keeps its back-translation.

The locale file and report are written only at the end. Running again after a finished run
verifies the written file afresh: every string is then in the verify bucket.

## Output

**Scenario:** `<locale>.restext`, rewritten in the English file's order with a `# origin:` line
above each key (the spec's String origin, `docs/mws-format-latest.md` §3 in Masterwork). A verified
string keeps the origin its input had:

| Input | Output origin |
|---|---|
| `official`, unchanged (typography normalization doesn't count) | `official` |
| `official`, fixed by the judge | `official, revised` |
| `draft` | `official, revised` |
| missing, with a Unity draft | `unity, revised` |
| missing | `agent` |

Keys from `en-US.overrides.restext` go to `<locale>.overrides.restext`, so each file checks cleanly
against its English. Keys used only in dev-note passages are left alone.

**App:** `AppStrings.<locale>.resx`, changed values rewritten in place and missing keys added. Resx
has no origin comments.

**Report:** bucket counts (passed first time, revised, unresolved, input kept, typography
normalized), then every changed or failed string, unresolved first, then every string that passed
unchanged. Each shows its English, French, back-translation, verdict and reason, check results, any
revision and the translator's notes.

## Term base

Two layers, both used by the forward agent, the judge and the checks, and reversed for the
back-translator:

- `terms.fr-CA.yaml` (here): the shared game terms. The official rulebook, *Le Secret de mon père*
  (Origames), comes first, then the Cradle French, then the Unity French.
- `<module>/.source/terms.fr-CA.yaml`: the scenario's own names, mined from its official pairs.
  It's written only when it doesn't exist; delete it to mine again. Review it like code.

Each entry has `en`, `fr` and an optional `note` for the agents, and `source`/`target` patterns for
`checktranslation`; `forbidden` patterns are hard failures. The format is in
`docs/translation-checks.md` in Masterwork. Keep one `key: value` per line: the runner reads the
agent fields itself.

Register and typography rules are in `style.fr-CA.md`. A new locale needs its own
`terms.<locale>.yaml` and `style.<locale>.md`; the prompts and checks are locale-neutral.

## Tests

```powershell
./tools/translate-verify/tests/run-tests.ps1
```

They run the runner on a small fixture scenario with a scripted stand-in for `claude`
(`tests/fake-agent.ps1`) and the real `checktranslation`, so they need the Masterwork checkout but
no agent calls.
