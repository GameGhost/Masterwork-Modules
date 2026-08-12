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
| `layouts/` | **template-canonical** — copied verbatim from `Masterwork-Modules/my-fathers-work-template/layouts/`, not hand-diverged, except `narration`/`introduction`/`hub_early`/`hub_middle`/`hub_late` each prepend one `let roundNum = min(_ProgressRound + 1, 9)` node (see each file's own comment) — the template assumes a module supplies `roundNum` (1-9) directly, but this module's own progress tracking is the extractor's `_ProgressRound` (0-based rounds-completed count, see `progress-map.json` below), so it's derived rather than a real module variable. Re-copy from the template for any layout that *doesn't* need this adaptation; re-apply it by hand to the five that do | Layout-chrome files (`layouts/{layout_id}.mws.yaml}`) rendered around passages/popups sharing that `layout` value — see [`docs/mws-format-latest.md`](https://github.com/GameGhost/Masterwork/blob/main/docs/mws-format-latest.md) §8. `countdown_instructions`/`countdown_action` (a nested popup pair) replaced the old flat `voting`/`bidding` layouts once the bespoke `VotingPopupContent` component they relied on was retired |
| `assets/` | **split ownership** — `audio/sfx/`, `fonts/`, `images/{backgrounds,borders,inputs,popup,progress}/`, and `style.css` are template-canonical (copied verbatim from `my-fathers-work-template/assets/`, re-copy wholesale rather than hand-editing); `icons/` combines both (template wins on a filename collision); everything else — `audio/bgm/`, `audio/vo/`, loose files directly under `images/` (the `picture_tcod_*`/`scenario_tile_*`/`scenariobox3d_disease` scenario art), and `images/setup/` (card/token art) — is this module's own and template-agnostic |
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
