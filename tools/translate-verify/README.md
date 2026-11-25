# translate-verify

Translates a scenario's strings, or the app's interface strings, from English into another
language and checks every one by round trip. It works the same for any language and any starting
point:

- **An official translation** (the first use: the French edition's text, reconciled by
  `Masterwork.Extractor reconcile`). It revises the drafts reconciliation left, writes the strings
  that have no official translation, and verifies the official ones.
- **A community translation**: a `<locale>.restext` written by hand, with or without
  `# origin:` comments. It verifies every string and fills the gaps.
- **Nothing**: it writes the whole locale from scratch, with each string verified the same way.

The process was decided in [GameGhost/Masterwork#23](https://github.com/GameGhost/Masterwork/issues/23).

## What it does

For one scenario (or the app), in this order:

| Stage | Who | What |
|---|---|---|
| terms | agent, once per scenario | Mines the scenario's own names (cards, places, characters) from its existing translation into `.source/terms.<locale>.yaml`. |
| forward | agent, per passage | Translates every `draft` and missing string, a whole passage at a time, given the passage's aligned translation. |
| checks | `checktranslation --fix` | Normalizes typography for the locale, then runs the integrity and term checks. |
| back | agent, per passage | Translates the translation back into English, blind: it sees only the translation, its passage and the term base reversed. |
| judge | agent, per passage | Compares English, back-translation and translation. Verdict per string, with a minimal fix for every fail. |
| revision | checks, then agents | Typo and integrity fixes are re-checked deterministically only. Meaning and term fixes are back-translated and judged once more. |
| write | — | The locale file with `# origin:` comments, and the report. |

Every agent stage is a separate headless `claude -p` call, with no tools and no project context.

Verdicts are `pass`, `fail: meaning`, `fail: typo`, `fail: term` and `fail: integrity`. Text a
person translated (official or existing) keeps its wording unless it fails, and a change of mood in
its narration fails on meaning. Agent-written text is held to the English fully. Any hard check
failure stops a string from passing.

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
- `terms.<locale>.yaml` and `style.<locale>.md` for the target locale, here. See
  [A new language](#a-new-language).
- Optionally, the scenario's starting `<locale>.restext`: the official French from
  `Masterwork.Extractor reconcile` (`docs/extractor.md` in Masterwork), or a community translation.
  Without one every string is written from scratch.

## Running it

A scenario. Mine its term list first and review it, since every later stage uses it:

```powershell
./tools/translate-verify/translate-verify.ps1 -Module a-time-of-war -Locale fr-CA -StopAfter terms
# review and commit a-time-of-war/.source/terms.fr-CA.yaml, then:
./tools/translate-verify/translate-verify.ps1 -Module a-time-of-war -Locale fr-CA
```

The term list is mined from strings a person translated: `official`, or with no origin comment.
With no starting translation there is nothing to mine, and the file is written empty.

The app's interface strings:

```powershell
./tools/translate-verify/translate-verify.ps1 -Resx <Masterwork>/src/Masterwork.App.Shared/Resources/AppStrings.resx -Locale fr-CA
```

| Option | Effect |
|---|---|
| `-Locale` | Required. Needs `terms.<locale>.yaml` and `style.<locale>.md` here. |
| `-Model` | Passed to `claude` as `--model`. Default: Claude Code's own default. |
| `-Parallel` | Agent calls at once. Default 4. |
| `-StopAfter terms` / `forward` | Stop after mining the term list, or after the drafts. |
| `-Drafts <json>` | Earlier translations from another source, revised for missing strings (below). Default: `.source/drafts.<locale>.json` if present. |
| `-WorkDir` | Stage outputs. Default `.translate-verify/<module>/<locale>/` (gitignored). |
| `-Report` | Default `<module>/.source/_translate-report.<locale>.md`, beside the reconciliation report. For the app, `report.md` in the work directory. |
| `-CodeRepoPath`, `-NoBuild` | The Masterwork checkout; skip rebuilding the packer. |
| `-Agent` | The agent command and leading arguments, instead of `claude`. |
| `-TimeoutMinutes` | How long one agent call may run before it's stopped and retried. Default 20. |

A full scenario is about three calls per passage, around a thousand for an official scenario.

### Prior drafts

A drafts file gives earlier translations of strings the locale file lacks: the Unity app's French,
say, or an older community translation. The forward agent revises them instead of starting from
nothing.

```json
{
  "origin": "unity",
  "description": "the Unity app's French",
  "strings": { "Setup_Title": "Le village" }
}
```

A revised draft gets the origin `<origin>, revised`. The format spec lists the origins the app
knows (`docs/mws-format-latest.md` §3 in Masterwork); use one of those.

### Stopping and resuming

Each agent answer is saved under the work directory with a hash of its exact request. Run the same
command again and finished calls are skipped, so an interrupted or failed run picks up where it
stopped. A call whose input changed (an edited string or term, a new forward draft) runs again, and
only that one: an unchanged translation keeps its back-translation.

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
| no origin comment (a community translation) | none, as before |
| `draft` | `official, revised` |
| missing, with a prior draft | `<origin>, revised` |
| missing | `agent` |

Keys from `en-US.overrides.restext` go to `<locale>.overrides.restext`, so each file checks cleanly
against its English. Keys used only in dev-note passages are left alone.

**App:** `AppStrings.<locale>.resx`, changed values rewritten in place and missing keys added. Resx
has no origin comments.

**Report:** bucket counts (passed first time, revised, unresolved, input kept, typography
normalized), then every changed or failed string, unresolved first, then every string that passed
unchanged. Each shows its English, translation, back-translation, verdict and reason, check
results, any revision and the translator's notes.

## Term base

Two layers, both used by the forward agent, the judge and the checks, and reversed for the
back-translator:

- `terms.<locale>.yaml` (here): the shared game terms for one language. For fr-CA the official
  rulebook, *Le Secret de mon père* (Origames), comes first, then the Cradle French, then the
  Unity French.
- `<module>/.source/terms.<locale>.yaml`: the scenario's own names, mined from its existing
  translation. It's written only when it doesn't exist; delete it to mine again. Review it like
  code.

Each entry has `en`, `translation` and an optional `note` for the agents, and `source`/`target`
patterns for `checktranslation`; `forbidden` patterns are hard failures. The format is in
`docs/translation-checks.md` in Masterwork. Keep one `key: value` per line: the runner reads the
agent fields itself.

## A new language

The prompts, the runner and the checks are language-neutral. A language needs two files here:

- `terms.<locale>.yaml`: the game's terms, from the publisher's edition in that language if there
  is one. Start from `terms.fr-CA.yaml`'s English column.
- `style.<locale>.md`: register (how narration, instructions to players and buttons are written)
  and typography. It goes into the forward and judge prompts as is. `style.fr-CA.md` is the
  example.

`checktranslation` checks any locale with neutral defaults, but normalizes typography only for a
locale with its own rules (fr-CA today; `TranslationLocale` in Masterwork, see
`docs/translation-checks.md` there). The language name in the prompts comes from the locale.

## Tests

```powershell
./tools/translate-verify/tests/run-tests.ps1
```

They run the runner on a small fixture scenario with a scripted stand-in for `claude`
(`tests/fake-agent.ps1`) and the real `checktranslation`, so they need the Masterwork checkout but
no agent calls.
