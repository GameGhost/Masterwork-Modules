# The Cost of Disease

Extracted MWS module for *The Cost of Disease*, one of the scenario scripts for the boardgame
*My Father's Work* (Renegade Game Studios). Source content under this module (and everything it was
derived from in `Reference/`) is CC BY-NC-SA 4.0 — see the repo-level `CLAUDE.md` for the licensing
boundary between this repo and the `Masterwork` code repo (never commit this module's content there).

## Layout

| Path | Owner | Purpose |
|---|---|---|
| `manifest.yaml` | hand-maintained | Module id/title/description, thumbnail, player count/playtime, entry passage, `passages`/`passages_override` paths, `style` stylesheet reference |
| `passages/` | extractor-owned | One `{NNN}-{PassageId}.mws.yaml` per passage, overwritten wholesale on every re-extraction — never hand-edit files here, edits will be silently lost |
| `passages-override/` | hand-maintained | `.mws.yaml` files applied after `passages/` at load time (`ModuleLoader.LoadFromDirectory`) — a matching `passage_id` replaces the extracted version, a new one is simply added. Currently holds the `Setup_*` onboarding flow (player count/names/town name) and `WinnerHUB`, none of which come from the Cradle source. Keep these in the current MWS format version — they don't get touched by extraction, so they can silently drift stale when the format revs |
| `layouts/` | hand-authored | Layout-chrome files (`layouts/{layout_id}.mws.yaml`) rendered around passages/popups sharing that `layout` value — see `docs/mws-format-latest.md` §8 in the code repo. `hub_early`/`hub_middle`/`hub_late` render the progress-bar-style chrome driven by `_ProgressRound` (see `progress-map.json` below); `end_of_round`/`end_of_generation`/`setup`/`voting`/`bidding` correspond to the extractor's own synthesized popup layouts |
| `assets/` | hand-authored | `style.css` (this module's own visual styling — the app only emits structural `layout-{value}`/`style-{value}` CSS class hooks, everything they look like lives here) plus `audio/`, `fonts/`, `icons/`, `images/` |
| `_variables.yaml` | extractor-owned | All session variables discovered during extraction, with inferred types/defaults. Overwritten on every re-extraction |
| `en-US.restext` | extractor-owned | Extracted locale strings (`Key=Value`, one per line). Overwritten on every re-extraction — `Common_NNN` keys can renumber between runs as the set of shared strings shifts, which is exactly why `en-US.common.restext` exists below |
| `en-US.common.restext` | hand-maintained | Curated `Key=Value` file giving *stable* names to strings that would otherwise get an auto-renumbered `Common_NNN` id on every re-extraction (fed to `--common-restext`). Any override passage referencing a Common string should use one of these curated names, not a raw `Common_NNN` |
| `.source/TheCostofDisease_Eng_v10.cs` | reference input | The Cradle 2.0.2.0 complete-class C# source this module is extracted from — CC BY-NC-SA, never commit to the code repo |

`361` passages as of the last extraction (`passages/` + `passages-override/`).

## Re-extracting

Run from `c:\Projects\Masterwork` (the code repo) after building the extractor:

```powershell
$base        = "c:\Projects\Masterwork-Design\Modules\cost-of-disease\.source"
$spritemap   = "c:\Projects\Masterwork-Design\Reference\UnityOriginalApp\Assets\Resources\TheCostOfDisease_ItemObtain.json"
$progressmap = "c:\Projects\Masterwork-Design\Modules\progress-map.json"
$modules     = "c:\Projects\Masterwork-Design\Modules"

dotnet run --project src/Masterwork.Extractor -- `
  "$base\TheCostofDisease_Eng_v10.cs" `
  "$modules\cost-of-disease\passages" `
  --variables-out "$modules\cost-of-disease" `
  --restext-out "$modules\cost-of-disease" `
  --module-title "The Cost of Disease" `
  --sprite-map $spritemap `
  --common-restext "$modules\cost-of-disease\en-US.common.restext" `
  --progress-map $progressmap
```

This only touches `passages/`, `_variables.yaml`, and `en-US.restext` — `passages-override/`,
`manifest.yaml`, `layouts/`, and `assets/` are never written by the extractor. See
`docs/extractor.md` (code repo) for the full flag reference.

## `progress-map.json`

Lives at `Modules/progress-map.json` (module-root-shared, not nested under this module) since it's
keyed by passage name and could in principle cover more than one module. For Cost of Disease it
drives two things per hub passage, both derived from `Reference/UnityOriginalApp/Assets/Scenes/
Main.unity`'s `PassageTracker` MonoBehaviour:

- **`layout`** — overrides tag-based layout inference with `hub_early`/`hub_middle`/`hub_late`
  (from `genHubEPassageList`/`genHubMPassageList`/`genHubLPassageList`), so each round of a
  generation gets its own hub chrome instead of one generic `hub` layout.
- **`progress`** (1-9) plus **`end_of_round_body`/`end_of_round_body2`** — at the
  `PassageTracker.instance.CheckProgress(...)` call site in the source, the extractor synthesizes a
  `layout: end_of_round` acknowledgement popup (matching the reference app's `ViewEndOfRound`) whose
  `onclose` sets a `_ProgressRound` session variable; `layouts/hub_early.mws.yaml` etc. turn that
  into the visible progress indicator. See the file's own `_comment` field and
  `docs/mws-format-latest.md` §8's timing note (code repo) for the full mechanism and the
  "rounds completed so far, not the round being played" semantics.

If this file goes missing, re-extraction still succeeds (`--progress-map` is optional) but every
hub passage falls back to the generic `hub` layout with no progress popup/variable at all — the
extractor logs a warning for every `CheckProgress` call site it can't find a matching entry for.
