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

from the code repo ([Masterwork](https://github.com/GameGhost/Masterwork), a sibling of this repo), then install `my-fathers-work-template.mwm`
(rebuild it first with `..\Masterwork-Modules\scripts\repack.ps1 -Module my-fathers-work-template`
if you've changed anything) via the app's "Upload Module" flow. Play through 2-player setup —
any names/town will do — and you'll land on the **Layout Showcase**, a hub screen linking to one
demo passage per layout below, plus a "Demo Module" section (see below) that's a separate,
self-contained scenario rather than another layout demo. Each layout demo links back to the
showcase; the showcase's own last link continues into the real scoring flow
(`Scoring_01_ScoreEntry.mws.yaml` etc.), which is itself part of the catalog.

## Layout catalog

| Layout | Demo passage(s) | Reference |
|---|---|---|
| `narration` | `Showcase_Narration_Short`, `Showcase_Narration_Long` | Parchment scroll, title bar, round-tracker footer. The long variant is the scroll-behavior test |
| `introduction` | `Showcase_Introduction` | Same shape as `narration`, distinct border accent |
| `event` | `Showcase_Event` | Full-bleed dramatic passage, no card frame |
| `hub_early` / `hub_middle` / `hub_late` | `Showcase_Hub_Early` (2 cards), `Showcase_Hub_Middle` (3 cards), `Showcase_Hub_Late` (5 cards — scroll test) | Vertical stack of bordered `section` cards; border color is the only difference between the three (green/amber/red) |
| `player_setup` | The real `_Setup_0N_*.mws.yaml` passages | Not separately demoed — already exercised by normal play. One shared, template-only layout for player-count/name/town-entry chrome (00_Preparations, the "get ready to play" bridge passage, uses `narration` instead — confirmed against the real reference screenshot, not a separate layout). Named `player_setup`, not `setup` — that name is reserved for the real popup below |
| `note` / `note_clear` (popup) | `_Setup_0N_*` passages' own popups | Torn-paper note — the one popup layout that was already fully styled before this module existed |
| `setup` (popup) | Layout Showcase hub's own "Setup" pair | The real, widely-used-across-modules instructional icon popup — brought across from `cost-of-disease`, not template-specific, so this layout_id has to stay exactly `setup` (reference: Module-04). Modernized this round to the current border-image/fixed-footer/font-size-reset approach every other popup here uses |
| `end_of_round` / `end_of_generation` (popups) | Layout Showcase hub's own pairs | Parchment note with a clock-icon title, single Confirm — the two layouts share identical sizing (reference: Module-08/12) |
| `prompt` (popup) | Layout Showcase hub's own pair | Bracket-cornered card + a fixed-size numeric input (reference: Module-11) |
| `choice` (popup) | Layout Showcase hub's own trigger | Downgraded from a bespoke radio-select dialog to a generic bordered popup (reference: General-Standalone-Select-Dialog) — its real job is exercising the checkbox input style scoring needs |
| `countdown_instructions` / `countdown_action` (popups, nested) | `Showcase_Popup_RevealCountdown` | Replaces the reference app's bespoke bidding/voting component — see below. Kept as its own demo passage since the nesting needs room a hub-inlined trigger doesn't have |
| `score_panel` | `Scoring_01_ScoreEntry`, `Scoring_02_TieBreaker1`, `Scoring_03_TieBreaker2` | Purple leather background, parchment score card, section-wrapped highlighted rows |
| `ranking` | `Scoring_04_Ranking` | Leather background, `panel_ranking.png` table with baked-in row dividers |
| `game_complete` (popup) | `02_Ending`'s own popup | Pinned collage image + text + real close-button okay |

`voting`/`bidding` are intentionally absent — the engine renders those two names through a bespoke
`VotingPopupContent` component (see `RenderedPopupView.razor`), so no `layouts/` chrome or module
CSS for them has any effect. `countdown_instructions`/`countdown_action` above replace what they
were used for.

### Replacing voting/bidding: a genuinely nested popup, no engine change needed

The reference app's `ViewBiddingSystem` (Module-09/10A/10B) is ONE continuous-looking parchment
note the whole time — the instructions text never disappears or changes; only a small dark
countdown pill appears over the button once clicked. An earlier pass tried to fake this with two
separate popups chained via a self-navigating passage (matching the pattern
`_Setup_03_PlayerNameA.mws.yaml` uses for a different reason) — it worked, but looked like two
distinct popups swapping, not one continuous note, because the two stages had different content
and the close/reopen was a real (if fast) unmount/remount.

`Showcase_Popup_RevealCountdown.mws.yaml` now does this with a real **nested popup** instead: a
`type: popup` node sitting directly inside another popup's own `content:` list. This isn't
special-cased anywhere — it falls out of the engine already treating node lists uniformly:
- `PassageYamlParser.BuildNode` is a single recursive dispatcher; nothing stops a `content:` list
  from containing another `popup` node.
- `PassageRenderer.RenderPopup` renders a popup's `content:` through the same `RenderNodeList` entry
  point used for passage-level nodes, which dispatches back to `RenderPopup` for any nested one —
  its sandboxed clone naturally chains (the inner popup's sandbox is cloned from the outer's, which
  is cloned from the live store), so state composes correctly regardless of nesting depth.
- `GameSession.FindAction` resolves one level into any top-level popup's own `Actions` list — which
  already includes a nested popup as a direct member, since the inner popup registers itself into
  the `RenderContext` created for rendering the outer's own content, and the outer folds that into
  its own `Actions`. So a click on the inner popup's Okay button resolves correctly.
- `ClosePopupAsync` commits via a *full snapshot restore* of the accepted popup's own sandbox
  (`_store.RestoreSession(popup.Sandbox.SessionSnapshot())`) — which already reflects everything
  from every ancestor sandbox it was cloned from, so accepting the inner popup correctly carries
  forward anything the outer would have (nothing, in this demo — the outer is pure instructional
  content with no state effects of its own).

Concretely: `countdown_instructions` (the outer note) is click-triggered off the passage's own
link, holds the instructions text, and has **no `okay`/`cancel` of its own** — it's a pure
container, only ever carried away by the inner popup's own navigation. `countdown_action` (the
inner popup) sits at the end of the outer's `content:`; its own `label` ("Start Bidding") renders
as an ordinary trigger button *inline within the outer's content* — exactly where the reference's
green "START BIDDING" button sits. Clicking it opens the inner popup; its `mws-popup-okay` covers
the full viewport, invisibly (`position: fixed; inset: 0; background: none; color: transparent`),
staying `pointer-events: none` until a `steps(1)` keyframe animation on the same duration as the
visible countdown pill (`content: '3' → '2' → '1' → 'REVEAL'` on a `::before`, also `steps(1)` per
segment since text can't meaningfully cross-fade) flips it to `pointer-events: auto`. Nothing to
keep in sync with JavaScript or an engine timer — both animations share one fixed duration.

Verified via a scratch xUnit harness driving `GameSession` directly (find the outer popup on
`Showcase_Popup_RevealCountdown`, find the inner nested inside its own `Actions`, accept it,
confirm it navigates) — passes. Visual confirmation against the real reference screenshots still
needs a real browser pass (`dotnet run --project src/Masterwork.App.Web`) — the CSS above is a
first cut, not yet screenshot-verified.

If you find a real gap in this mechanism while extending it further, that's worth raising as an
actual engine change — but nesting one level deep (which is all this needs) already works today.

## Demo Module (logic/expression showcase)

`Demo_Hub.mws.yaml` and the passages it links to (`Demo_Well`, `Demo_Survey`, `Demo_SurveyResult`,
`Demo_Rumors`, `Demo_Ending`) are a separate, small, actually-playable scenario — not another entry
in the layout catalog above (they reuse the plain `narration` layout throughout, aside from the
popup layouts noted below). Reached from the Layout Showcase hub's own "Demo Module" section. Where
the layout catalog exercises *visual* chrome, this exercises MWS *logic and expression* capability:

- An evolving hub whose text is gated on a visit count (`demoWellVisits`).
- A random flavor line picked via `.shuffled(...)[0]`, and a `rand_between()` roll dispatched
  through `switch` (`Demo_Well`), plus a `checkpoint`.
- An `input` field collected inside a real `prompt`-layout popup (`Demo_Survey`), rather than
  inline on the passage — matching how every other input in this module is actually presented.
- Both popup shapes on `Demo_SurveyResult`: a generic no-layout popup, and the real 2-part vote
  pattern (an outer `countdown_instructions` popup — pure instructional container, no okay/cancel
  of its own — holding an inner `countdown_action` popup directly in its own content). This is the
  same nested-popup mechanism `Showcase_Popup_RevealCountdown` demonstrates for bidding; see
  "Replacing voting/bidding" above — `voting`/`bidding` themselves are retired, no longer
  engine-special-cased, so this is the *only* correct way to build a reveal-countdown interaction
  now.
- A `.shuffled()` array iterated in full via `foreach` (`Demo_Rumors`).
- An intentionally-unresolved `{icon:...}` reference on `Demo_Hub` (shown as the engine's own
  fallback icon).
- A real terminal passage (`Demo_Ending`, reached only once `demoWellVisits >= 3`) mirroring
  `02_Ending.mws.yaml`'s own real-ending pattern exactly: `narration` with title *and* subtitle, a
  `game_complete` popup carrying the assign-driven ending name, and an Okay resolving to the
  `app::gameover` sentinel target — this genuinely ends the playthrough (deletes the autosave,
  returns to the main menu), the same as any real scenario's true ending.

This set mirrors what the Masterwork app's own former built-in demo module exercised end-to-end,
before that app-level concept was retired in favor of real, playable module content — see
[`src/Masterwork.Tests/FixtureModuleTests.cs`](https://github.com/GameGhost/Masterwork/blob/main/src/Masterwork.Tests/FixtureModuleTests.cs)
in the Masterwork repo for the same coverage, ported to an inline test fixture. `scripts/apply-template.ps1` does **not** copy these passages into target
modules (it only maps setup + scoring) — they're template-only, same as the layout catalog itself.

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
