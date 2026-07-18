# View Requirements

Working document for building out the real visual treatment of each layout, one section at a
time. **Add notes/corrections inline as we go** — headings marked `TBD`/`OPEN QUESTION` are things
I couldn't confirm from the screenshots and asset files I've looked at so far.

Status legend: 🔲 not started · 🟡 rough pass exists (from an earlier session, needs rework per the
notes below) · ✅ matches reference closely.

This revision supersedes the first draft. Source of truth is now
`Masterwork-Design/Reference/Screenshots/screenshot-summary.md` (the authoritative per-screenshot
catalog, naming convention `<prefix>-NN[L]-<description>.png`) cross-checked against the actual
asset files currently in `my-fathers-work-template/assets/`. Anywhere this doc names an asset file,
it's been confirmed to exist on disk under that exact name.

---

## 1. Cross-cutting architecture

These apply to (almost) every view and should be built once, generically, rather than per-layout.

### 1.1 Responsive strategy — resolved

Two treatments, switched at the existing `min-width: 48rem` breakpoint (`app.css`'s existing
mobile/desktop split — no new breakpoint needed):

- **Wide (≥48rem)**: full letterboxed frame. Background and border images stretch/squash to fill
  the viewport edge-to-edge; aspect ratio is **not** preserved.
- **Narrow (phone portrait, <48rem)**: an alternate treatment where the border art is shown only as
  thin strips at the top and bottom of the viewport, cropped and sized to the width of the
  progress-bar segment (see §1.4) rather than the full frame. Content extends to the left/right
  edges with just a basic reading margin — no side border art at all in this mode.

**OPEN QUESTION**: the narrow-mode border strip is a *crop* of the same border PNG used in wide
mode (not a separate asset) — need to confirm the crop rectangle (pixel/percentage row range) is
consistent enough across all border images to do this with one CSS rule (e.g. `object-position`)
rather than per-image tuning.

### 1.2 Three-layer composite per view — confirmed

The frame art has a transparent/black interior and a built-in cutout for the progress bar (only on
the borders that have one — see §1.3). Every view with a border is a stack of (bottom to top):

1. **Content layer** — background image (full-bleed) + the actual passage/popup content. **This is
   the only layer that scrolls.** Title text sits either above the border (overlapping it) or
   pinned to the top of the view, outside the scrolling region.
2. **Progress bar layer** (only on views that have one — §1.4) — behind the border, in front of
   content, positioned to land inside the border's cutout.
3. **Border layer** — the frame PNG, full view size, `pointer-events: none` so clicks pass through.
4. **App chrome** (back button, timeline scrubber, options gear) — always on top, fixed position,
   structurally outside `PassageView` already (`Play.razor`) — layouts must not fight with it.

Popups follow the same model at popup-container size: fixed (or fixed-max) size frame, scrollable
content region inside.

**Implementation latitude (confirmed)**: layout `.mws.yaml` files can supply the border/progress
images via `image` nodes with a `style` field mapping to a CSS class; CSS then positions them,
disables interaction (`pointer-events: none`), and layers them via `z-index` as needed. Whether a
given image lives in the layout's `header`/`footer` region or is just absolutely-positioned via CSS
is an implementation detail — "whatever is easiest and most maintainable" per your note.

### 1.3 Border image assignments — confirmed

| Layout | Border asset | Progress-bar cutout? | Reference |
|---|---|---|---|
| `narration` (incl. `Preparations`, ending narration) | `narration_normal.png` | Yes | Module-01, 03, 13 |
| `introduction` | `narration_intro.png` | Yes | Module-02 |
| `hub_early` | `hub_red.png` | Yes | Module-05 |
| `hub_middle` | `hub_blue.png` | Yes | Module-06 |
| `hub_late` | `hub_brown.png` | Yes | Module-07 |
| `event` (`ck2`-tagged passages) | *same as `narration`* — see §2 `event`, this is not a distinct border | Yes | Module-03D |
| Setup passages (count/name/town) | `main.png` | **No** — plain perimeter border, no bottom notch | Setup-01/03/05 |
| Scoring/Ranking passages | `main.png` | No | Scoring-05 |

Corrects the first draft's assumption that every border shares the same cutout geometry — confirmed
from Setup-01's screenshot that `main.png` has **no** progress-bar notch (no round tracker is shown
on setup/scoring screens at all, which checks out — those happen outside any generation/round).

**Unused border assets** (in `assets/images/borders/` now but no screenshot reference identified
yet): `narration_gold.png`, `ending_gold.png`, `ending_normal.png`, `ending_circle_highlight.png`,
`vignette.png`. Leaving them in the pack for now per your note — fine to stay unreferenced.

### 1.4 Round progress bar (`narration`, `introduction`, `hub_early`/`middle`/`late`, `event`) — confirmed

Three parts, confirmed against `assets/images/progress/`:

1. **Bar background** (`progress/background.png`) — one wide strip, pre-divided into 3 color
   segments (green/amber/red — one per generation). Clipped (`clip-path`) to reveal only up to the
   current round; sized/positioned to match the border, adjusting for aspect-ratio changes caused by
   viewport size (confirmed — not a set of pre-clipped images).
2. **Per-round label overlays** (`progress/{I1,I2,I3,II1,II2,II3,III1,III2,III3}-{diffuse,glow}.png`)
   — `-glow` = current round, `-diffuse` = a passed round, unreached rounds get no overlay. Must be
   sized/positioned to fit their border-cutout slot **while preserving their own aspect ratio** (for
   legibility) — confirmed, don't stretch these to fill the slot. The `I2-diffuse.png` filename typo
   from the first draft has been fixed on disk.
3. **Border cutout** — fixed-aspect image; progress-bar layer must be positioned relative to the
   same box the border image occupies (not the scrollable content) to stay aligned.

**Implementation sketch** (unchanged from first draft, still the plan): layout chrome computes
"reached" rounds from an integer session variable (1–9), renders one `image` node per reached round
with a `style` selecting a hard-coded CSS position/slot, and a `switch`/`conditional` on round count
picks the bar-background's clip-path class.

Last session's rough pass (`layouts/narration.mws.yaml` etc.) used a `foreach` over all 9 labels as
colored text pills, always showing all 9. That gets replaced by the above.

### 1.5 Type system — resolved

- Base scale: 100% = **16pt**, applied via the existing `--mws-text-scale` custom property on
  `body`. Content sized in `em` inherits this; border art (fixed-proportion raster) doesn't respond
  and isn't expected to.
- Add `text-lg` / `text-xl` utility classes (em-based, relative to the scaled base) — usable both in
  hand-authored passages/popups and in extractor-generated output (e.g. end-of-round/generation
  popup headers).
- New font **`germania-one`** (already added: `assets/fonts/germania-one-v21-latin-regular.{ttf,woff2}`
  + `germania-one.css`) — use for most title/subtitle styling and button text (matches the
  metal-embossed look in every screenshot's title bar and the `CONTINUE`/`CONFIRM` button faces).
  Not yet wired into `style.css` — needs a `font-family` rule on the title/subtitle/button classes.

### 1.6 Links, actions, and buttons — new, from `screenshot-summary.md`'s style notes

- **Inline links/popup triggers** always render wrapped in square-bracket images, color keyed to
  context: **brown** (`inputs/bracket-brown-left.png` / `bracket-brown-right.png`) on any
  parchment-background surface (narration, introduction, popups, setup, scoring, ending); **blue**
  (`inputs/bracket-blue-left.png` / `bracket-blue-right.png`) inside hub sections. Hover = brighter
  text, pressed = darker text, no visited state.
- **Popup action buttons** (okay/cancel) use one of three graphical button styles with text overlay:
  `inputs/button_green.png`, `inputs/button_brown.png`, `inputs/button_red.png`. Red is always
  Cancel unless otherwise noted. Popups in the original app never show a Cancel action, but
  Masterwork's popup model allows one — needs a sane default style when present. Hover = brighter
  text (optionally grow slightly, staying centered, content must not shift). Pressed = text returns
  to normal, button fades to 60% opacity.
- Need generic utility classes (e.g. `.mws-button-green` / `-brown` / `-red`) so any link or popup
  trigger can be turned into a standard button, plus the existing bracket-link styling as a second,
  separate utility axis (a node can be a bracketed inline link, a graphical button, or neither).
- `inputs/bracket-metal-left.png` / `bracket-metal-right.png` also exist but aren't called out by
  any screenshot yet — **OPEN QUESTION**: guess is these are for the hub's non-section top-level
  links (as opposed to blue-bracketed links inside a hub `section`)? Need confirmation or another
  screenshot.

---

## 2. Per-view catalog

Screenshot filenames below are exact, from `Masterwork-Design/Reference/Screenshots/`.

### `narration` — 🟡 needs the layered-frame rework (§1.2–1.4)

- **Reference**: `Module-01A/B-Preparations*.png`, `Module-03A-Standard-Narration.png`,
  `Module-03B/C` (hidden section behind a guard link, then revealed), `Module-03E` (inline centered
  image nodes), `Module-03F` (long title, wraps).
- **Structure**: title across the top edge of the frame (not scrolling) → scrollable parchment-page
  content region → round-tracker footer in the border's bottom cutout. Back + pause buttons pinned
  top-left (app chrome, not layout content).
- **Assets**: border `narration_normal.png`; content background — module-specific
  `scenario_narration_background.png` with fallback to `backgrounds/leather_large.png` (the
  standard-name-with-fallback pattern needs support, see §3); content-panel `backgrounds/panel_parchment.png`;
  scrollbar — no image asset, just a thin CSS bar (white) over a dark track, per the summary notes.
  Inline links: brown brackets (§1.6).
- **`Module-01` "Preparations"** is just `narration` with a slightly larger title — no separate
  layout needed, treat as a narration passage.
- No subtitle appears in any narration screenshot, but the format should still support one (per the
  summary notes) — confirm subtitle styling once we have a screenshot that uses it (the ending
  narration, `Module-13`, does use both title and subtitle — see below).

### `introduction` — 🟡 needs full rework against real reference now available

- **Reference**: `Module-02A/B-Generation-I-Introduction*.png`.
- **Structure**: same frame shape as `narration` but with `narration_intro.png`'s ornate gold
  Celtic-knot border. Content panel is `backgrounds/panel_parchment.png` inside a scrollable area.
  Links use the same brown-bracket styling as narration.
- **OPEN QUESTION — title/subtitle prominence**: your note says title/subtitle are *inverted* in
  prominence here vs. elsewhere. Looking at `Module-02A`, "YELLOW FEVER" (large) sits above
  "GENERATION I" (small) — the same large-over-small relationship as the hub screenshots
  ("YELLOW FEVER" / "EARLY YEARS"). I don't see an inversion in the image itself, so I may be
  missing what you meant (a different screenshot? a CSS-class-naming inversion rather than a visual
  one?) — flagging rather than guessing.
- **Assets**: background — same standard-name-with-fallback pattern as narration
  (`scenario_narration_background.png` → `leather_large.png`).

### `event` (`ck2`-tagged passages) — 🔲 not started — **decision made, needs an extractor change**

- **Reference**: `Module-03D-Standard-Narration-with-Special-Event-Overlay.png`.
- **What the screenshot actually shows**: a passage that is visually identical to a normal
  `narration` passage (same `narration_normal.png` border, same progress bar, same parchment
  content) with a large "SPECIAL EVENT" banner (orange embossed text, flanked by
  `popup/special_event_line_left.png` / `special_event_text.png` / `special_event_line_right.png`)
  overlaid across the middle of the page. Per the historical Unity behavior (`ViewSpecialEvent`),
  this banner fades in then fades out, leaving the ordinary narration content visible underneath —
  it is a **transient overlay effect**, not a distinct background/border treatment.
- **Decided**: fold `ck2` into the `narration` branch of `CradleExtractor.InferLayout`
  (`CradleExtractor.cs:1050-1053`) rather than aliasing a separate `event` layout — `event` stops
  existing as a distinct `layout:` value. A `ck2`-tagged passage instead needs some other marker
  (`style` field on the passage, or a dedicated flag) that `narration`'s chrome/CSS can key the
  banner overlay off of. **This is an extractor code change** — not yet made; needs to happen before
  re-extracting `cost-of-disease` (which currently has passages tagged `layout: event` from the old
  behavior) or any other module with `ck2`-tagged content.
- **OPEN QUESTION**: is the banner's fade-in/out timing/trigger meant to play once on passage entry
  (CSS animation, `animation-fill-mode: forwards` ending in `display: none` or `opacity: 0`), or does
  it need to be re-triggerable (e.g. on `StepBack`/replay)? Assuming "plays once per render" is fine
  unless you say otherwise.

### `hub_early` / `hub_middle` / `hub_late` — 🟡 needs border-image + real progress bar

- **Reference**: `Module-05A/B-Hub-Early-Years*.png` (red), `Module-06-Hub-Middle-Years.png` (blue),
  `Module-07-Hub-Late-Years.png` (brown).
- **Structure**: title + subtitle (e.g. "Yellow Fever" / "Early Years") pinned to the top → 
  scrollable vertical stack of bordered sections → round-tracker footer in the border cutout.
- **Assets**: background `backgrounds/leather_splattered.png`; section border
  `borders/hub_section.png` (also carries its own transparent dark background — no separate flat
  panel color needed); scrollbar `inputs/scroll_bar_lg.png` (a real image asset here, unlike
  narration's plain-CSS scrollbar); inline links use **blue** brackets
  (`bracket-blue-left/right.png`), matching hub's distinct link-color rule from §1.6.
- Sections are not collapsible — full text always visible, matches using `section` nodes with
  `collapsed: false` (as last session's rough pass already did).
- Gold background highlight seen in the screenshot is a Unity-only effect with no corresponding
  asset — per your note, omit it for now.

### `setup` passage layout (player count / name entry / town name) — 🟡 built, needs visual verification

Built: `layouts/setup.mws.yaml` (background + border image layer), `style.css`'s `layout-setup`
block (three-layer composite, real `leather_large.png`/`main.png` assets), `setup-title`/
`setup-alert`/`setup-input` content styles, and `btn-players-2/3/4` picker-button styles using the
real `players_2/3/4.png` icon assets (closes the old "no engine support for image-backed nav
buttons" TODO — it's a CSS `background-image` on the link, no engine change needed). All
`Setup_01`–`Setup_07` passages now use `layout: 'setup'`. Verified against the scratch test harness
(module loads with no new warnings, all asset references resolve, full setup→showcase flow drives
through) — **not yet viewed in a browser**, so treat as unverified visually until you've looked at
it. Narrow-viewport top/bottom-strip treatment (§1.1) deliberately deferred — shared infrastructure
better built once when we hit narration/hub, not duplicated here first.

- **Reference**: `Setup-01-Player-Count.png`, `Setup-03A/B-Player-Name-Entry*.png`,
  `Setup-05-Town-Name-Entry.png`.
- **Decided**: one shared `setup` passage layout, not three separate layout files — chrome
  (`backgrounds/leather_large.png` background, `main.png` border, no progress-bar cutout, see §1.3)
  is identical across all three; content differences are per-passage authoring, same pattern
  `narration` already uses for varying content. No layout files exist yet for these, so this is a
  clean start, not a rename.
- **Screen-specific content** (authored per-passage against the shared `setup` chrome):
  - **Player count** (`Setup-01`): 3 large buttons (`inputs/players_2.png` / `players_3.png` /
    `players_4.png`, each with a "N Players" caption below), centered on one row, reflowing to
    stacked on narrow viewports.
  - **Player name entry** (`Setup-03`): an info/alert row (darkened translucent background, gold
    text — uses the `icons/alert.png` icon) + prompt + a text input (`inputs/input_large.png`) +
    Continue.
  - **Town name entry** (`Setup-05`): same shape as name entry, plus a large "The Village" title.
- A gold background highlight is again a Unity-only effect — omit per your note.

### `note` (popup) — 🟡 built, needs visual verification

Built: `layouts/note.mws.yaml` (empty chrome, CSS-only) and `style.css`'s `layout-note` block —
`popup_paper_torn.png` background, `button_brown.png` Okay button. `Setup_02`'s intro blurb and the
greeting branches of `Setup_03`–`Setup_07` now render as auto-display `note` popups instead of
inline passage text (matches the reference screenshots more closely — see below). Same verification
caveat as `setup` above: passes the scratch harness, not yet seen in a browser.

- **Reference**: `Setup-02-Player-Intro.png`, `Setup-04-Player-Greeting.png`,
  `Setup-06-Town-Name-Greeting.png` — three different moments (scenario intro blurb, per-player
  greeting, town-name greeting) that all use the **same simple torn-parchment popup**: header-free,
  just body text + a single action button.
- **Assets**: `backgrounds/popup_paper_torn.png`, standard brown button.
- **Distinct from the `setup` popup layout below** — that one (`Module-04`) has an icon/pin
  illustration and a different background asset (`popup_parchment_border.png` vs
  `popup_paper_torn.png`). These are two different popup shapes that happen to share the word
  "setup" informally.

### `setup` (popup) — 🟡 needs asset-name reconciliation, otherwise close

- **Reference**: `Module-04A/B/C-Setup-Popup*.png` — instructional popup with a pinned icon
  illustration, appearing (A) triggered by a link, (B) auto-shown over an empty passage, (C)
  auto-shown over a hub passage.
- **Structure**: parchment background, "Setup" title (localizable), scrollable content area, fixed
  icon image with extra pin/stud decoration, two buttons centered on the bottom edge.
- **Assets**: `backgrounds/popup_parchment_border.png`; `popup/setup_icon_background.png`;
  `popup/setup_brass_stud.png` (there's also a `popup/setup_paperclip.png` not mentioned in the
  summary table — **OPEN QUESTION**: is the paperclip used here too, or a leftover from a different
  screen?); standard green Okay / red Cancel buttons.

### `end_of_round` / `end_of_generation` (popups) — 🟡 rework with the short-popup asset

- **Reference**: `Module-08A/B-End-of-Round-popup*.png` (alt B = different body text, same layout),
  `Module-12-End-of-Generation-popup.png` (same layout, different header text — should be the same
  popup layout with header text supplied by the popup node, not two separate layouts).
- **Structure**: fixed-size popup, header with clock icon, body text, single button centered on the
  bottom edge.
- **Assets**: `backgrounds/popup_parchment_border_short.png` (note: **short** variant — different
  from the plain `popup_parchment_border.png` used by `setup`/score-help; first draft had this
  slightly wrong), `popup/generation_time.png` (clock icon), standard green button.

### Bidding preamble popup — `Module-09` — 🟡 rework, reuses `end_of_round`'s short-popup shape

- **Reference**: `Module-09-Bidding-Preamble-popup.png`.
- **Structure**: parchment popup, text, single standard green button — structurally identical to
  `end_of_round`'s shape. **OPEN QUESTION**: should this literally be the same layout as
  `end_of_round`/`end_of_generation` (same `popup_parchment_border_short.png`), just with different
  content, or does it deserve its own layout id since it's semantically a different moment? Leaning
  toward reusing the same layout — no visual difference identified.

### `reveal_countdown` — 🟡 rework against real reference (now available)

- **Reference**: `Module-10A-Bidding-Popup-countdown.png` (shows a number, e.g. "1"),
  `Module-10B-Bidding-Popup-reveal.png` (shows "REVEAL" text).
- **Structure**: fixed background image (`backgrounds/popup_reveal.png`), large centered text (the
  countdown digit, then "REVEAL"), sized to fit the panel. Backdrop is a **lightened**
  semi-transparent overlay — unusual, most popups darken the background; this one brightens it.
  Dismissed by clicking **anywhere** on the popup once the countdown completes (not a specific
  button) — confirms the earlier note that this needs the whole-popup-clickable interaction, not
  just an unlocked button.
- **Confirms the two-stage chaining approach** from the original implementation plan (self-navigating
  passage flipping a `_revealStage` variable between two auto-display popups) is still the right
  mechanism — no engine change needed. The CSS detail changes though: instead of a hidden/disabled
  button becoming clickable, the **entire popup surface** needs `pointer-events` re-enabled only
  after the countdown animation completes (same `animation-fill-mode: forwards` timing trick, applied
  to the popup's click-catcher rather than a button).

### `prompt` (popup) — 🔲 not started — new layout, decided name

- **Reference**: `Module-11A-Input-popup.png`, `Module-11B-Input-popup-with-numeric-value.png`.
- **Structure**: fixed border popup, larger-than-normal prompt text (centered, no scrolling), a
  large input field centered on/below the bottom edge (text centered inside it, no numeric
  spinners), action buttons centered near the bottom (below the input).
- **Assets**: `backgrounds/popup_bordered.png`, `inputs/input_large.png`, standard brown (okay) /
  red (cancel) buttons.
- **Decided**: a genuinely new layout the first draft missed entirely (used for in-game numeric/text
  prompts, e.g. the bidding amount or the "Legacy of Charity" heart-token count shown in one of the
  reference screenshots), named `prompt`, kept separate from `choice` — `choice` is a dark box for
  radio-style selection, `prompt` is a parchment numeric/text input, visually and functionally
  different.

### `choice` — 🟡 rework, now has real assets for the previously-missing radio group

- **Reference**: `General-Standaline-Select-Dialog.png` ("Choose Audio Voice").
- **Structure**: dark bordered box (`backgrounds/panel_general.png`, window background
  `leather_large.png` if used as a passage rather than a popup), large centered header, centered
  content, Continue button.
- **Assets now exist for real radio buttons**: `inputs/radio_selected.png` / `radio_unselected.png`
  — the first draft's "no radio-group input type, using a checkbox as a stand-in" gap can likely be
  closed now, **but** this is still an MWS-format question: does the format need an actual
  radio-group input type, or can this be built as N boolean/checkbox-style inputs styled with the
  radio assets and app-level logic ensuring only one is set? **Flagging as a format discussion**,
  not blocking the CSS/asset work.

### `score_panel` (`ScoreEntry` / `TieBreaker1` / `TieBreaker2`) — 🟡 rework with real assets

- **Reference**: `Scoring-01-Score-Entry.png`, `Scoring-02-Score-Entry-Help-popup.png`,
  `Scoring-03A/B-Tie-Break-1*.png`, `Scoring-04A/B-Tie-Break-2*.png`.
- **Structure**: floating panel/popup look — window background `backgrounds/leather_purple.png`,
  window border `main.png`, inner popup panel `backgrounds/popup_parchment_border.png`. Table-style
  Player/Score (or Player/Checkbox) rows, one per player (2–4 based on player count). A small help
  button (`inputs/button_question.png`) opens a help popup with additional scoring detail.
- **Confirms the `section`-wrapping requirement**: each player row needs a highlighted background
  (`inputs/player_highlight.png`, described as "color inverted, semi-transparent") — per your note,
  this needs each score/tie-break row wrapped in a `section` node so the highlight can be applied as
  a section background, rather than the current flat sequence of `text`/`input` nodes. This is a
  **hand-authored passage change**, not a layout/CSS-only change — flagged again under §3.
  Score input: `inputs/input_small.png`. Continue: standard brown button.
- **Tie-Break 1** (checked-completion): checkbox assets `inputs/checkbox_outline.png` +
  `inputs/checkbox_checkmark.png`, same row/table shape as score entry otherwise.
  **Tie-Break 2** (estate-upgrade count): identical shape to score entry, numeric input.
- **Help popup**: same `popup_parchment_border.png` background, same `player_highlight.png` section
  styling per scoring-detail row, close button `inputs/button_close.png`.

### `ranking` — 🟡 rework with real assets

- **Reference**: `Scoring-05-Rankings-dual-winner.png`.
- **Structure**: standard background/border (`backgrounds/leather_large.png` + `main.png` — **not**
  a distinct "dark stone panel" as the first draft guessed), a ranking-specific inner panel
  (`backgrounds/panel_ranking.png`), one row per player: rank ordinal (left, orange/tan), player
  name (right), crown icon after the name **only for players who actually placed 1st** (confirmed —
  the "every row shows a crown" note from the first draft was a screenshot-state artifact, not
  intentional; `Scoring-05`'s "dual winner" filename literally documents a tie-for-first case where
  2 of 4 players get a crown and the other 2 don't). Standard brown Continue button below.
- **Asset name resolved**: `ranking_crown.png` lives at `assets/images/inputs/ranking_crown.png` (an
  `image://inputs/ranking_crown` reference), not `icons/crown.png` — the first draft's proposed fix
  (rename into `icons/`) is unnecessary; just use an `image` node instead of the `{icon:...}` inline
  pattern in `Scoring_04_Ranking.mws.yaml`, as originally suggested.

### `game_complete` (popup) — 🟡 asset name correction needed, otherwise close

- **Reference**: `Module-14-Ending-Gameover-popup.png`.
- **Structure**: large parchment popup, centered pinned photo-collage image overlapping the top
  edge, Okay button (`inputs/button_close.png`, no label) positioned over the popup's top-right
  corner.
- **Asset name correction**: background is `backgrounds/popup_parchment_border.png` (the **long**
  variant, not the `_short` one used by `end_of_round`) — worth double-checking last session's rough
  pass used the right one.

### Ending narration — 🟡 same as `narration`, confirm subtitle styling

- **Reference**: `Module-13A/B-Ending*.png`.
- **Structure**: identical to standard `narration` (title **and** subtitle both used here — the one
  screenshot that actually exercises the subtitle). The only addition is the "continue to game over"
  action, styled as a graphical floating button in the bottom-right corner of the view rather than an
  inline bracketed link — `inputs/button_forward_orange.png`. This is stylable via the popup/link's
  own `label`-style override, not a new layout.

---

## 3. Hand-authored passage / extractor-pipeline implications

Flagging up front, per your note, since these are code changes layered on top of the pure
CSS/asset/layout work above and probably deserve separate scoping:

1. **`event` layout mapping** (§2 `event`) — decided: fold `ck2` into the `narration` branch of
   `CradleExtractor.InferLayout`, replacing the separate `"event"` layout value with some other
   marker `narration`'s chrome can key its banner overlay off of. Not yet implemented — re-running
   extraction on any module with `ck2`-tagged passages (`cost-of-disease` currently has some tagged
   `layout: event` from the old behavior) will need this landed first.
2. **Score/tie-break row `section` wrapping** (§2 `score_panel`) — `ScoreEntry`, `TieBreaker1`,
   `TieBreaker2` passage overrides need each player row restructured from flat `text`/`input`
   sequences into `section`-wrapped rows so `player_highlight.png` can be applied as a per-row
   background. Hand-authored override change, not extractor.
3. **Radio-group input** (§2 `choice`) — format-level question (new input type vs. styled
   booleans); not blocking, but worth a decision before building `choice` for real.
4. **Standard-name-with-fallback background pattern** (§2 `narration`/`introduction`) —
   `scenario_narration_background.png` (module-specific) falling back to `backgrounds/leather_large.png`
   (shared) needs to be a supported resolution behavior, not just a convention — **OPEN QUESTION**:
   does `AssetResolver`/CSS already support an image-not-found fallback chain, or does this need new
   engine/CSS work (e.g. a CSS `background-image` list with multiple `url()` fallbacks isn't
   standard — more likely this means the module CSS always references
   `image://scenario_narration_background`, and each real module supplies that file, with
   `leather_large.png` used only in the *template* module where no module-specific art exists)?

## 4. Not in scope here (app-level, not module content)

Main menu, options/settings, pause popup (`Module-00`), help, scenario select
(`App-01`–`App-04`), log book/achievements gallery — either app-shell chrome (not a module's
`layouts/` folder) or Phase 3 (achievements, deferred). Listed for completeness only.
