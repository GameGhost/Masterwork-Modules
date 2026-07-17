# My Father's Work — Template

A design workbench, **not a playable scenario**. It exists to exercise every layout and popup
shape the app needs to support, styled for real, so the "look and feel" can be iterated on and
screenshotted in a running app before being copied into real scenario modules — and, eventually,
pulled out into a shared asset-pack dependency (see the `dependencies: []` TODO in every module's
`manifest.yaml`).

## Viewing it

```powershell
dotnet run --project src/Masterwork.App.Web
```

from the code repo (`c:\Projects\Masterwork`), then install `my-fathers-work-template.mwm`
(rebuild it first with `..\Masterwork-Modules\scripts\repack.ps1 -Module my-fathers-work-template`
if you've changed anything) via the app's "Upload Module" flow. Play through 2-player setup —
any names/town will do — and you'll land on the **Layout Showcase**, a hub screen linking to one
demo passage per layout below. Each demo links back to the showcase; the showcase's own last link
continues into the real scoring flow (`Scoring_01_ScoreEntry.mws.yaml` etc.), which is itself part
of the catalog.

## Layout catalog

| Layout | Demo passage(s) | Reference |
|---|---|---|
| `narration` | `Showcase_Narration_Short`, `Showcase_Narration_Long` | Parchment scroll, title bar, round-tracker footer. The long variant is the scroll-behavior test |
| `introduction` | `Showcase_Introduction` | Same shape as `narration`, distinct border accent |
| `event` | `Showcase_Event` | Full-bleed dramatic passage, no card frame |
| `hub_early` / `hub_middle` / `hub_late` | `Showcase_Hub_Early` (2 cards), `Showcase_Hub_Middle` (3 cards), `Showcase_Hub_Late` (5 cards — scroll test) | Vertical stack of bordered `section` cards; border color is the only difference between the three (green/amber/red) |
| `setup_player_count` / `setup_player_names` / `setup_town_name` / `setup_scenario` | The real `_Setup_0N_*.mws.yaml` passages | Not separately demoed — already exercised by normal play |
| `setup` (popup) | Any `_Setup_0N_*` passage's own popups | Torn-paper note — the one layout that was already fully styled before this module existed |
| `end_of_round` / `end_of_generation` | `Showcase_Popup_Rounds` | Parchment note with an icon header, single Confirm |
| `choice` (new) | `Showcase_Popup_Choice` | Dark bordered box for settings-style choices (reference: "Choose Audio Voice") |
| `reveal_countdown` (new) | `Showcase_Popup_RevealCountdown` | Replaces the reference app's bespoke bidding/voting component — see below |
| `score_panel` | `Scoring_01_ScoreEntry`, `Scoring_02_TieBreaker1`, `Scoring_03_TieBreaker2` | Parchment scroll on a purple gradient |
| `ranking` | `Scoring_04_Ranking` | Dark stone list panel |
| `game_complete` (popup) | `02_Ending`'s own popup | Pinned collage image + text + circular X close |

`voting`/`bidding` are intentionally absent — the engine renders those two names through a bespoke
`VotingPopupContent` component (see `RenderedPopupView.razor`), so no `layouts/` chrome or module
CSS for them has any effect. `reveal_countdown` above replaces what they were used for.

### Replacing voting/bidding: no engine change needed

Both halves of the reference app's `ViewBiddingSystem` (instructions → countdown → reveal) are
achievable with patterns the format already supports:

- **Chaining a popup from another popup's close** — `Showcase_Popup_RevealCountdown.mws.yaml` uses
  the same self-navigating-passage pattern `_Setup_03_PlayerNameA.mws.yaml` already relies on: a
  `revealStage` session variable and a `conditional` picking between two popups. Stage 0's popup
  (click-triggered) sets `revealStage = 1` in its `onclose` and `goto`s back to its own
  `passage_id`; the re-render falls into the conditional's other branch, whose popup has no
  `label` and so auto-displays immediately. No new node type.
- **CSS-animated countdown, then an inert-until-ready Okay button** — pure CSS
  (`.layout-reveal_countdown` in `assets/style.css`): the Okay button starts with
  `pointer-events: none` and a fixed-duration `animation`, whose final keyframe step flips
  `pointer-events: auto`. The visible countdown text runs off the same duration, so there's
  nothing to keep in sync with JavaScript or an engine timer.

If you find a real gap in either mechanism while extending this further, that's worth raising as
an actual engine change — but nothing here required one.

## Font scaling / responsive design

Read the comment block at the top of `assets/style.css` before adding rules. Short version: the
app's only font-scaling mechanism (`--mws-text-scale`, applied to `body`'s own font-size) does
**not** propagate to `rem`-sized descendants — only `em` does. This module's own rules use `em`
for anything sizing actual reading text, and `rem` only for chrome that should stay fixed
(borders, background-image-matched button dimensions). Screen size/aspect ratio reuses the app's
two existing breakpoints (`min-width: 48rem` / mobile) — no new ones were added.

## Copying this into a real module

Two scripts live in this repo's `scripts/` folder:

```powershell
# Preview first — never skip this on a module that already has customized content.
.\scripts\apply-template.ps1 -TargetModule cost-of-disease -WhatIf

# Then for real:
.\scripts\apply-template.ps1 -TargetModule cost-of-disease
```

This copies `assets/style.css`, `assets/fonts/`, every `layouts/*.mws.yaml` file, and the setup +
scoring passages (mapped into the target's `passages-override/` folder, e.g.
`Scoring_01_ScoreEntry.mws.yaml` → `_ScoreEntry.mws.yaml` — see the script's own comments for the
full name mapping). It never touches `passages/`, `_variables.yaml`, `en-US.restext`,
`manifest.yaml`, or `.source/` — those are extractor-owned or per-module identity, per this repo's
own `CLAUDE.md`.

**This is a mechanical copy, not a merge.** Run `git diff` inside the target module afterward and
reconcile by hand: a real module's scoring passages likely have per-scenario logic layered on top
of whatever this template's generic version currently does (variable names, branch conditions),
and blindly keeping the copy over local changes will silently discard that. The `-WhatIf` preview
exists specifically so you can decide whether now is even the right time to run this for real.

Once you're happy with a module's version, bump and repack it:

```powershell
.\scripts\repack.ps1 -Module cost-of-disease -IncrementVersion minor
```

See `scripts/repack.ps1 -?` / `scripts/apply-template.ps1 -?` (or `Get-Help <script> -Full`) for
the full parameter reference.
