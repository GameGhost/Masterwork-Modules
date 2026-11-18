# The Cost of Disease

Extracted MWS module for *The Cost of Disease*, one of the scenario scripts for the boardgame
*My Father's Work* (Renegade Game Studios). This module's own content (passages, overrides, layout
chrome, assets) is project-internal to this repo. The `.source/` Cradle file it's extracted from is
CC BY-NC-SA 4.0 (derived from the original app's own scripts) — see the repo-level `CLAUDE.md` for
the full licensing boundary (never commit `.source/` or anything CC BY-NC-SA-derived to the
[Masterwork](https://github.com/GameGhost/Masterwork) code repo).

## Layout

| Path | Owner | Purpose |
|---|---|---|
| `manifest.yaml` | hand-maintained | Module id/title/description, thumbnail, player count/playtime, entry passage, `passages`/`passages_override` paths, `style` stylesheet reference |
| `passages/` | extractor-owned | One `{NNN}-{PassageId}.mws.yaml` per passage, overwritten wholesale on every re-extraction — never hand-edit files here, edits will be silently lost |
| `passages-override/` | hand-maintained | `.mws.yaml` files applied after `passages/` at load time (`ModuleLoader.LoadFromDirectory`) — a matching `passage_id` replaces the extracted version, a new one is simply added. Holds the `_Setup_*`/`_Scoring_*` onboarding-and-scoring flow (copied verbatim from `my-fathers-work-template/passages/`, matching passage_ids `Setup_01_PlayerCountSelect`...`Setup_07_TownNameEntry`/`ScoreEntry`/`TieBreaker1`/`TieBreaker2`/`Ranking`), this module's own `00_Preparations`/`01_VarEndingsPassage` tie-in passages bridging setup/scoring into the real story content, and the 8 `END-*` ending overrides (extracted content plus an appended `game_complete` unlock popup). None of these come from the Cradle source as-is. Keep them in the current MWS format version — they don't get touched by extraction, so they can silently drift stale when the format revs |
| `layouts/` | Empty — every layout this module uses, including `narration`/`introduction`/`hub_early`/`hub_middle`/`hub_late` (roundNum already derived from `_ProgressRound`, this module's own extractor-synthesized rounds-completed count — see `progress-map.json` below), lives in `mwf-common-assets/layouts/` instead, reached via this module's own `dependencies:` entry. Would only need a local file if this module's own `--progress-map` extraction ever assigned a different progress variable name than the shared default (`scripts/apply-template.ps1 -ProgressVariable`) | Layout-chrome files (`layouts/{layout_id}.mws.yaml}`) rendered around passages/popups sharing that `layout` value — see [`docs/mws-format-latest.md`](https://github.com/GameGhost/Masterwork/blob/main/docs/mws-format-latest.md) §8 |
| `assets/` | This module's own scenario-specific content only: `audio/vo/`, `audio/bgm`/`fonts`/`images/{backgrounds,borders,inputs,popup,progress}`/`style.css`/shared `icons/` all moved to `mwf-common-assets/assets/` instead — what's left here is `icons/` entries unique to this scenario, loose files directly under `images/` (the `picture_tcod_*`/`scenario_tile_*`/`scenariobox3d_disease` scenario art), and `images/setup/` (card/token art) |
| `_variables.yaml` | extractor-owned | All session variables discovered during extraction, with inferred types/defaults. Overwritten on every re-extraction |
| `en-US.restext` | extractor-owned | Extracted locale strings (`Key=Value`, one per line). Overwritten on every re-extraction — `Common_NNN` keys can renumber between runs as the set of shared strings shifts, which is exactly why `en-US.common.restext` exists below. Also hand-appended: the `Common_Close`/`Common_Continue`/`Scoring_*`/`Setup_*` keys the `passages-override/` content above references (copied from the template's own `en-US.restext`) — curated in `.source/en-US.common.restext` too so a re-extraction doesn't drop them, see below |
| `.source/en-US.common.restext` | hand-maintained | Curated `Key=Value` file giving *stable* names to strings that would otherwise get an auto-renumbered `Common_NNN` id on every re-extraction (fed to `--common-restext`, note the `.source/` path — not the module root). Any override passage referencing a Common string should use one of these curated names, not a raw `Common_NNN` |
| `.source/TheCostofDisease_Eng_v10.cs` | extraction input | The Cradle 2.0.2.0 complete-class C# source this module is extracted from — CC BY-NC-SA, never commit to the code repo. This is the sole canonical copy re-extraction reads from |

`361` extracted passages (`passages/`) plus 11 hand-authored `passages-override/` additions
(`_Setup_01`–`07`, `_Scoring_01`–`04`) not already replacing an extracted passage_id — 373 total as
loaded (`ModuleLoader`'s `module.Passages.Count`).

## Re-extracting

Run from [Masterwork](https://github.com/GameGhost/Masterwork) (the code repo, a sibling of this repo) after building the extractor:

```powershell
$base        = "<Masterwork-Modules>/cost-of-disease/.source"
$spritemap   = "<UnityProject>/Resources/TheCostOfDisease_ItemObtain.json"
$progressmap = "<Masterwork-Modules>/progress-map.json"
$modules     = "<Masterwork-Modules>"

dotnet run --project src/Masterwork.Extractor -- `
  "$base\TheCostofDisease_Eng_v10.cs" `
  "$modules\cost-of-disease\passages" `
  --variables-out "$modules\cost-of-disease" `
  --restext-out "$modules\cost-of-disease" `
  --module-title "The Cost of Disease" `
  --sprite-map $spritemap `
  --common-restext "$base\en-US.common.restext" `
  --progress-map $progressmap
```

This only touches `passages/`, `_variables.yaml`, and `en-US.restext` — `passages-override/`,
`manifest.yaml`, `layouts/`, and `assets/` are never written by the extractor, so none of the
template-application work above needs redoing after a re-extraction. See
[`docs/extractor.md`](https://github.com/GameGhost/Masterwork/blob/main/docs/extractor.md) for the
full flag reference.

## `progress-map.json`

Lives at the repo root (`Masterwork-Modules/progress-map.json`, module-root-shared, not nested
under this module) since it's keyed by passage name and could in principle cover more than one
module. For Cost of Disease it
drives two things per hub passage, both derived from the original Unity project's `Main.unity`
scene's `PassageTracker` MonoBehaviour:

- **`layout`** — overrides tag-based layout inference with `hub_early`/`hub_middle`/`hub_late`
  (from `genHubEPassageList`/`genHubMPassageList`/`genHubLPassageList`), so each round of a
  generation gets its own hub chrome instead of one generic `hub` layout.
- **`progress`** (1-9) plus **`end_of_round_body`/`end_of_round_body2`** — at the
  `PassageTracker.instance.CheckProgress(...)` call site in the source, the extractor synthesizes a
  `layout: end_of_round` acknowledgement popup (matching the reference app's `ViewEndOfRound`) whose
  `onclose` sets a `_ProgressRound` session variable; `layouts/hub_early.mws.yaml` etc. turn that
  into the visible progress indicator. See the file's own `_comment` field and
  [`docs/mws-format-latest.md`](https://github.com/GameGhost/Masterwork/blob/main/docs/mws-format-latest.md)
  §8's timing note (in the Masterwork repo) for the full mechanism and the
  "rounds completed so far, not the round being played" semantics.

If this file goes missing, re-extraction still succeeds (`--progress-map` is optional) but every
hub passage falls back to the generic `hub` layout with no progress popup/variable at all — the
extractor logs a warning for every `CheckProgress` call site it can't find a matching entry for.
