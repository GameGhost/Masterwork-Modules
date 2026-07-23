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

**Resolved (proven on `player_setup`)**: not a pre-cropped asset — a pure CSS `transform: scaleX(1.6667)`
on the border `<img>` under the narrow media query, which crops 20% off each side and stretches the
remaining 60% to fill the width. `1.6667` is a starting value (20%-off-each-side), easy to retune
per layout if a different border's usable frame proportions differ; switch to real pre-cropped
top/bottom assets later only if the stretch starts looking soft. This is now a proven, reusable
pattern — see §1.7.

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
| `ck2`-tagged ("special event") passages | *same as `narration`* — not a distinct layout at all, see §2 | Yes | Module-03D |
| Setup passages (count/name/town) | `main.png` | **No** — plain perimeter border, no bottom notch | Setup-01/03/05 |
| Scoring/Ranking passages | `main.png` | No | Scoring-05 |

Corrects the first draft's assumption that every border shares the same cutout geometry — confirmed
from Setup-01's screenshot that `main.png` has **no** progress-bar notch (no round tracker is shown
on setup/scoring screens at all, which checks out — those happen outside any generation/round).

**Unused border assets** (in `assets/images/borders/` now but no screenshot reference identified
yet): `narration_gold.png`, `ending_gold.png`, `ending_normal.png`, `ending_circle_highlight.png`,
`vignette.png`. Leaving them in the pack for now per your note — fine to stay unreferenced.

**Border rendering, updated**: every bordered layout's frame (`main.png` included, even though
setup has no progress bar) now renders via one shared CSS `border-image` 9-slice, not a per-layout
`image` node — see §1.7/§1.8's amendment for why, and for how this let the round progress bar
(§1.4) assume one fixed frame thickness across every layout that has one.

### 1.4 Round progress bar (`narration`, `introduction`, `hub_early`/`middle`/`late`) — ✅ built and visually approved

Built and confirmed against `assets/images/progress/`, driven by an integer `roundNum` session
variable (1–9) each layout's `footer` region reads (see `layouts/narration.mws.yaml`/
`introduction.mws.yaml`/`layouts/hub_early.mws.yaml` et al. — hub's own progress bar was built and
visually confirmed this round, reusing the identical mechanism):

1. **Bar background** (`progress/background.png`) — one wide strip, pre-divided into 3 color
   segments (green/amber/red — one per generation). A `switch on: roundNum` with 9 cases picks one
   of 9 `.style-progress-bg-N` classes, each a `clip-path: inset(0 X% 0 0)` revealing `N/9` of the
   strip. Both the shared positioning rule (`[class*="style-progress-bg-"]`) and the 9 individual
   `clip-path` rules are `position: fixed` against the true viewport, same box the border image
   itself occupies, so they stay aligned regardless of `.mws-passage-body`'s own scroll position.
2. **Per-round label overlays** (`progress/{I1,I2,I3,II1,II2,II3,III1,III2,III3}-{diffuse,glow}.png`)
   — `-glow` = current round, `-diffuse` = a passed round, unreached rounds get no image node at all
   (a pair of nested `conditional`s per round in the layout `.mws.yaml`, not a single `switch`, since
   "not yet reached" needs to render nothing). Each of the 9 `.style-progress-label-N` rules sets
   only its own `left` (tuned per-label against the live bar) — the shared rule must **not** also
   set `left`, see the specificity note below.
3. **Border cutout, fixed-width-aware positioning**: every bordered layout's frame now renders at
   the same shared fixed `border-image-width` (px, §1.7/§1.8's amendment), so `left`/`width` here
   use `calc((100vw - Npx) / 100vw * Xvw + Ypx)` instead of a plain `Xvw + Ypx` — the
   `(100vw - Npx) / 100vw` factor rescales the usual vw-based proportion down to the viewport's
   *remaining* width after the border's own fixed margins, and `+ Ypx` shifts in by that same fixed
   margin, so the bar's position stays constant *relative to the border's own inner edge* at any
   viewport size, the same way a plain vh/vw value keeps something constant relative to the whole
   viewport. `N`/`Y` differ slightly between hub_* and narration/introduction — same shared
   border-image-width, but the bar's own cutout position within it isn't pixel-identical between the
   border assets (style.css's own comment has the exact numbers).

**Narrow-viewport variant**: a `@media (max-width: 45.99rem)` block recomputes `left`/`width` for
both the bar background and each of the 9 labels, matching the border's own narrow-mode
`scaleX(1.6667)` crop-and-stretch (§1.1) so the bar continues to land inside the now-stretched
cutout. Same shared-rule-vs-per-variant split as the wide rules.

**CSS specificity pitfall hit and fixed this session** — worth calling out since it'll recur:
the shared `[class*="style-progress-label-"]` rule briefly also set `left`, "as a placeholder."
Because that selector (`.mws-passage.layout-narration .mws-image[class*="..."]`) has *higher*
specificity than the individual `.mws-image.style-progress-label-N { left: ...; }` rules (4
class-level selector components vs. 2), the shared rule's `left` silently won regardless of which
label was rendered — every label sat at the same spot no matter the round. **Rule of thumb**: a
shared/grouped rule must only set properties every variant needs *identically* (position, sizing,
z-index); the one property that's supposed to differ per variant must never also appear in the
shared rule, or the per-variant override becomes dead code. A related, separate bug hit earlier in
the same area: hand-edited per-label narrow-mode overrides missing the comma between grouped
selector lines (`.layout-introduction .mws-image.style-progress-label-1\n.layout-narration ...`
without a `,` between them merges two selectors into one invalid combined descendant selector,
silently matching nothing).

Last session's rough pass (`layouts/narration.mws.yaml` etc., pre-dating this work) used a `foreach`
over all 9 labels as colored text pills, always showing all 9 — fully replaced by the above.

### 1.5 Type system — resolved and built

- Base scale: 100% = **16pt**, applied via the existing `--mws-text-scale` custom property on
  `body`. Content sized in `em` inherits this; border art (fixed-proportion raster) doesn't respond
  and isn't expected to.
- `text-sm` / `text-lg` / `text-xl` utility classes built (`style.css`, em-based, relative to the
  scaled base) — usable both in hand-authored passages/popups and in extractor-generated output
  (e.g. end-of-round/generation popup headers). `text-sm` added this session for content that reads
  better smaller (a long intro paragraph on `player_setup`'s town-name screen).
- Font **`germania-one`** wired into `style.css`: `.mws-passage-title`/`.mws-passage-subtitle`/
  `.mws-popup-header` and every standard graphical button (§1.6) use it. Body copy stays
  `Averia Libre` throughout, including form inputs (which don't inherit `font-family` from
  ancestors by default in most browsers — needs an explicit rule on the `<input>` itself, not just
  its wrapper).

### 1.6 Links, actions, and buttons

**Standard graphical buttons — resolved and built.** One shared rule in `style.css` (keyed by a
combined selector across every popup Okay button using this shape plus `.mws-link.style-btn-brown`
/ `-green` / `-red`) covers sizing/shape/states; each color variant only sets its own
`background-image`/`color`/`text-shadow`:
- `inputs/button_brown.png`, `inputs/button_green.png`, `inputs/button_red.png` — sizing is
  **`rem`-based, not `em`** (see §1.7 for why — this was the fix for buttons rendering at different
  sizes depending on which layout hosted them).
- Labels are **uppercase** (`text-transform: uppercase`).
- Hover = `brightness(1.15)` filter + an explicit per-variant `:hover` color (needed because
  app.css's own `.mws-link:hover` rule otherwise wins on specificity and silently reverts a link
  button's color to the default link blue).
- Pressed = `transform: scale(0.85); opacity: 0.75` (transform/opacity only, never
  width/height/padding, so it can't reflow neighboring content) — applied generally to every
  `.mws-popup-okay`/`.mws-popup-cancel` and every `.style-btn-{color}` link.
- Still open: red is built but not yet exercised by any real content (no popup here sets a
  `cancel:` field yet) — matches the general style note that Red should default to Cancel.

**Inline bracketed links — still not built** (deferred along with narration/hub, per §1.1). Always
render wrapped in square-bracket images, color keyed to context: **brown**
(`inputs/bracket-brown-left.png` / `bracket-brown-right.png`) on any parchment-background surface
(narration, introduction, popups, setup, scoring, ending); **blue**
(`inputs/bracket-blue-left.png` / `bracket-blue-right.png`) inside hub sections. Hover = brighter
text, pressed = darker text, no visited state.

`inputs/bracket-metal-left.png` / `bracket-metal-right.png` also exist but aren't called out by any
screenshot yet — **OPEN QUESTION**: guess is these are for the hub's non-section top-level links (as
opposed to blue-bracketed links inside a hub `section`)? Need confirmation or another screenshot.

### 1.7 App chrome & single-scroll architecture — proven on `player_setup`, reuse for every future layout

Built and visually approved (not just planned) on `player_setup` — this is now the reference
implementation for every other bordered layout, not something to re-derive per-layout:

- **`.mws-play-chrome` must be `position: fixed; top/left/right: 0`** in module CSS. App.css's
  default is `position: sticky`, which still occupies its own space in normal document flow and
  pushes `.mws-passage` down by however tall it renders — `sticky` alone doesn't give a
  layout-independent top clearance. Safe to override from module CSS since it's only injected while
  this module is actually playing (cleared on leaving `/play`).
- **`body { height: 100vh; overflow: hidden; }`** + the layout's own root class as
  `display: flex; flex-direction: column; height: 100vh; overflow: hidden;` with
  `padding-top` reserving clearance for the now-fixed chrome bar, and `.mws-passage-body` as the
  `flex: 1; min-height: 0; overflow-y: auto` child, is what gives a layout **exactly one
  scrollbar** (never a second, outer page-level one) and lets content scroll internally if it's
  taller than the available space — unified across wide and narrow, no per-breakpoint duplication
  needed.
- **A known app.css bug**: `@media (min-width: 48rem) { .mws-passage { max-width: 40rem;
  margin: 0 auto; padding: 1.5rem; } }` is a *generic* rule (no `layout-` qualifier) that silently
  caps every passage's outer box to 640px wide on anything ≥48rem. Every bordered layout needs its
  own `.mws-passage.layout-{id} { max-width: none; margin: 0; ... }` to override it (2-class
  selectors beat the bare 1-class one regardless of which sits in a media query) — **worth fixing
  in app.css directly instead of re-overriding per layout**, flagged under §3.
- **Popups must reset their own `font-size`.** A popup node's DOM position is a descendant of
  whatever passage hosts it — `position: fixed` only escapes layout/containing-block, not CSS
  inheritance — so a popup silently inherits the host passage's own font-size bump (e.g.
  `player_setup`'s `1.6em`) unless its own container rule sets an explicit `font-size`. Every popup
  layout needs this reset; `note`/`note_clear`/`setup` all do it now (`font-size: 0.8em` on
  `.mws-popup-container`) — `setup` was missing this until this round, see its own entry below.
- **A `transform` on any ancestor hijacks `position: fixed` descendants.** If an element needs to
  center itself via `left: 50%; transform: translateX(-50%)` *and* contains a `position: fixed`
  descendant (e.g. a popup footer that must stay anchored to the true viewport), that transform
  makes the element the fixed descendant's containing block instead of the viewport — silently
  breaking the fixed positioning. Center via `left`/`right` insets instead when this applies (see
  `note`'s narrow-mode container).
- **Standard graphical buttons must size in `rem`, not `em`**, for the identical reason — sizing
  otherwise compounds against whatever ambient font-size the *hosting* layout happens to use, so
  the same button renders at different sizes in a popup vs. inline in a passage. See §1.6.
- **A decorative image with a baked-in transparent gutter/drop-shadow, or a full-viewport border
  frame, needs `border-image` 9-slicing, not `object-fit: fill`/`background-size: 100% 100%` — and
  `border-image` can't live on an `image` node, so it moved to a CSS pseudo-element.** Superseded
  from an earlier version of this note (originally: "give the gutter-y image its own `position:
  fixed` `image` node, matched to `.mws-passage-body`'s box" — that fixed *alignment* but not the
  gutter's own internal stretch distortion). Both `narration`/`introduction`'s parchment panel
  (`backgrounds/panel_parchment.png`) and every layout's outer border frame now render via
  `border-image`: the slice marks off a fixed region from each source edge, `border-image-width`
  renders it at a fixed on-screen thickness, and only the flat straight runs between corners
  stretch — each along a single axis only. `border-image` and an `<img>`'s own `src` bitmap don't
  mix (the `<img>` still paints its own content, undistorted-border or not), so this lives on a
  `content: ''` `::before`/`::after` pseudo-element instead — the `style-layer-border`/
  `style-layer-parchment` `image` nodes have been removed from every layout `.mws.yaml`. `z-index`
  order unchanged: background (-1) → parchment pseudo-element (0) → border pseudo-element (1) → text
  content (1, same layer as the border since it never visually overlaps it). See §1.8's amendment
  for the unit this settled on (fixed `px`, not `vh`/`vw`) and why.

### 1.8 `vh`/`vw` vs `rem`/`em` — sizing convention

Two independent scaling mechanisms are in play in this file, and mixing them up is what caused most
of the positioning bugs this session (the parchment gutter drift, the progress-bar padding not
tracking the border, buttons sized differently per host layout). Pick the unit by asking **what is
this element's size actually relative to?**

- **`vh`/`vw` — for anything whose size or position must track the *viewport-scaled border/
  background art*.** The background/border/parchment layers themselves are `100vw`/`100vh` with
  `object-fit: fill`, so they stretch/squash to the window on every resize (§1.1, §1.2). Anything
  that has to stay visually locked to a specific spot on that art — the round-progress-bar tray and
  its 9 labels (§1.4), the parchment content-panel and the `.mws-passage-body` box matched to it
  (§1.7), a bordered layout's own outer padding (`narration`/`introduction`'s `10vh 4vw` — the
  border's own frame thickness grows/shrinks with the viewport, so the padding keeping content clear
  of it has to grow/shrink the same way, or it drifts under/over the frame as the window resizes) —
  needs `vh`/`vw`, not `rem`/`em`/`%`. A `%` value is relative to the *element's own box*, which
  usually isn't the same thing as "the viewport the border art is scaled to," so it doesn't
  substitute for `vh`/`vw` here even though it looks similar.
- **`rem`/`em` — for text, and for chrome/art that should scale with the reading-text baseline
  rather than the viewport.** Already documented at the top of `style.css` (the FONT-SCALING
  CONVENTION note): `em` for anything sizing actual reading text (inherits the already-scaled
  computed size, so it tracks `--mws-text-scale`); `rem` for chrome that deliberately should *not*
  grow with text — border widths on small UI chrome, and fixed-aspect button/backing art (§1.6's
  standard buttons, sized in `rem` specifically so the same button doesn't render at a different
  size depending on which layout's own font-size happens to host it).
- **A third case that looks like it needs `vh`/`vw` but doesn't: centered floating dialogs sized to
  their own art's aspect ratio.** `note`/`note_clear`'s container no longer even needs a fixed
  `aspect-ratio` (see the amendment below — it moved to `border-image`, so `height: auto` sizes to
  content now), but the underlying point still holds: a popup isn't pinned to a specific spot on a
  full-viewport border image the way `.mws-passage-body` is, so it doesn't need viewport-locked
  coordinates at all — `rem`-based `max-width` plus `height: auto` already lets it size itself
  relative to the space available. If a future popup's own art needs to sit flush against a screen
  edge instead, reach for `vh`/`vw` then — the choice is about what the element's size is
  *conceptually* relative to, not a blanket rule.

**Amendment — border-image sizing settled on fixed `px`, not `vh`/`vw`, and this section's earlier
guidance is superseded for that specific case.** Every bordered layout's outer frame, and
narration/introduction's parchment panel, moved to `border-image` 9-slicing this round (§1.2/§1.3/
§1.7's own amendment) — `object-fit: fill`/`background-size: 100% 100%` stretched a border's corners
and straight edges by whatever non-uniform factor the current viewport aspect ratio produced;
`border-image` keeps each corner at a fixed on-screen thickness and only stretches the straight
edge runs between them, each along a single axis. That fix only works cleanly if
`border-image-width` is a *single* value shared across both axes (or literally the same computed
`px` regardless of viewport) — pairing `vh` for top/bottom with `vw` for left/right (this section's
original recommendation) still leaves the four *corner* regions scaling non-uniformly, since `vh`
and `vw` track different axes at different rates unless the viewport happens to be square. The
fix actually shipped: every bordered layout (`player_setup` included) now shares one fixed-`px`
`border-image-width`/`-slice`, and the content-clearance padding/box insets that have to stay
flush against that border (passage padding, the parchment panel's own box, `.mws-passage-body`'s
inset) moved to matching fixed `px` alongside it — a `vh`/`vw` clearance value paired with a
now-fixed-`px` border would drift out of sync with it as the viewport resized, the same class of
problem this section originally used `vh`/`vw` to solve, just inverted (now the border is the fixed
reference, not the viewport). The round progress bar (§1.4) still needs to track the *viewport*
proportionally (a bar filling `N/9` of the available width), so it uses `calc()` to combine both:
`(100vw - border-margin-px) / 100vw * Xvw + border-margin-px` rescales a normal vw-based proportion
down to the space remaining after the border's fixed margins, then shifts in by that same fixed
margin — the general shape to reach for whenever something needs to be proportional to the
viewport **and** flush against a fixed-thickness border at the same time.

---

## 2. Per-view catalog

Screenshot filenames below are exact, from `Masterwork-Design/Reference/Screenshots/`.

### `narration` — ✅ built and visually approved

Built and confirmed across many rounds of screenshot feedback: real three-layer composite
(`leather_large.png` background image node + a `panel_parchment.png` content-panel `border-image`
and a `narration_normal.png` outer-frame `border-image`, both CSS pseudo-elements — §1.7/§1.8's
amendment), the single-scrollbar/fixed-chrome architecture (§1.7), narrow-mode border crop (§1.1),
the real round progress bar (§1.4), embossed uppercase title/subtitle styling (multi-directional
`text-shadow` stack), and brown-bracket inline links (§1.6). Passage outer padding, the parchment
panel's own box, and `.mws-passage-body`'s inset are all fixed `px` now (§1.8's amendment) so they
stay flush against the border's own now-fixed-`px` thickness at any viewport size.

- **Reference**: `Module-01A/B-Preparations*.png`, `Module-03A-Standard-Narration.png`,
  `Module-03B/C` (hidden section behind a guard link, then revealed), `Module-03E` (inline centered
  image nodes), `Module-03F` (long title, wraps).
- **Structure**: title across the top edge of the frame (not scrolling) → scrollable parchment-page
  content region → round-tracker footer in the border's bottom cutout. Back + pause buttons pinned
  top-left (app chrome, not layout content).
- **Assets**: border `narration_normal.png`; content background `backgrounds/leather_large.png`
  (the module-specific-background-with-fallback idea from the first draft is deferred, see §3 item
  5 — the template currently just uses the shared leather background directly); content-panel
  `backgrounds/panel_parchment.png`; scrollbar — no image asset, just a thin CSS bar (white) over a
  dark track, per the summary notes. Inline links: brown brackets (§1.6).
- **`Module-01` "Preparations"** is just `narration` with a slightly larger title — no separate
  layout needed, treat as a narration passage.
- No subtitle appears in any narration screenshot, but the format still supports one — confirm
  subtitle styling once we have a screenshot that uses it (the ending narration, `Module-13`, does
  use both title and subtitle — see below).

### `introduction` — ✅ built and visually approved

Same shape as `narration` above, sharing every rule via the combined `.layout-narration,
.layout-introduction` selectors in `style.css` — only the border asset differs
(`narration_intro.png`'s ornate gold Celtic-knot border vs. `narration_normal.png`). Built and
confirmed alongside `narration` in the same rounds of feedback.

- **Reference**: `Module-02A/B-Generation-I-Introduction*.png`.
- **Structure**: same frame shape as `narration` but with `narration_intro.png`. Content panel is
  `backgrounds/panel_parchment.png` inside a scrollable area. Links use the same brown-bracket
  styling as narration.
- **OPEN QUESTION — title/subtitle prominence**: your note says title/subtitle are *inverted* in
  prominence here vs. elsewhere. Looking at `Module-02A`, "YELLOW FEVER" (large) sits above
  "GENERATION I" (small) — the same large-over-small relationship as the hub screenshots
  ("YELLOW FEVER" / "EARLY YEARS"). I don't see an inversion in the image itself, so I may be
  missing what you meant (a different screenshot? a CSS-class-naming inversion rather than a visual
  one?) — flagging rather than guessing. Still unresolved; the built version uses the same
  large-title/small-subtitle relationship as narration.
- **Assets**: background `backgrounds/leather_large.png`, same as narration (see its own entry
  above re: the deferred module-specific-background-with-fallback idea).

### Special event overlay (`ck2`-tagged passages) — ✅ built, extractor change shipped

**How Cradle marks it**: purely a passage-registration tag, nothing inside the passage body itself.
Every Cradle passage registers via `base.Passages["Name"] = new StoryPassage("Name", new string[]
{ "tag1", ... }, mainMethod)` in its own `_Init` method; `"ck2"` in that array (alongside `"ck"` for
hub) is the tag. Confirmed against the two real `ck2` passages in `cost-of-disease`
(`AngryMobStorybook`, `TipsnTricks`) — their own bodies are ordinary text/lineBreak/link content
with no special call. The actual "show overlay + play sound" behavior lived entirely in the
original Unity app's own passage-tracking code, outside Cradle/MWS — the tag alone is the signal.

**Extractor change, implemented**: `CradleExtractor.InferLayout` no longer maps `ck2` → a distinct
`"event"` layout — a `ck2`-tagged passage gets `layout: "narration"` like any other (the old
`event` layout is retired, including this template's own `layouts/event.mws.yaml`). A new
`InsertSpecialEventOverlay` step (called from `BuildPassages`, after node-list finalization —
title/subtitle heading-hoisting already ran and still works normally, so a `ck2` passage's own
leading bold heading still becomes its `Title` exactly as before) prepends a single synthesized
`text` node — `{ Template: "Special Event", Style: "special-event" }` — to the passage's own
content when the tag is present. Nothing engine-side changed; `layout`/`style` were already
generic, module-CSS-driven hooks (format spec §8), so this needed no new node type or reader
change, only the extractor decision of *what* to emit.

**Template-side implementation, built and demoed** (`Showcase_Event.mws.yaml`, now `layout:
'narration'`, hand-authoring the same node shape extraction would produce): the synthesized text
node's own content is visually hidden (`color: transparent`, kept for accessibility — a screen
reader still announces "Special Event") in favor of the three overlay images — the center banner
as the node's own `background-image`, the two flanking light-beam lines as `::before`/`::after`
(the same technique the bracket links already use, chosen specifically because `::before`/`::after`
don't render on a *replaced* element like an `image` node's `<img>` — a `text` node avoids that).
`position: fixed; inset: 0` makes it a full-viewport layer regardless of where in the passage's
scrollable content it was authored, both for the centered-on-screen placement the reference shows
and so a `steps(1)`-keyframed `pointer-events` animation running on the same 3.5s timeline as the
opacity fade can block clicks on the rest of the passage for the display's duration ("non-
interactive during the display") without touching every link's own styling — `z-index: 999`, above
the passage's own content but below `.mws-play-chrome` (1002), so back/pause navigation stays
reachable throughout.

- **Reference**: `Module-03D-Standard-Narration-with-Special-Event-Overlay.png`.
- **Sound cue — deferred** (per your note): would attach to the same synthesized node, since it
  plays on the same "passage just rendered" trigger as the fade-in: no mechanism designed yet.
- **Not yet done**: `cost-of-disease`'s own `AngryMobStorybook`/`TipsnTricks` passages still carry
  `layout: 'event'` from the old extraction — that only updates on a real re-extraction run, a
  separate, bigger action on a module this session hasn't otherwise touched, not done as a side
  effect of this change. `app.css`'s own `.mws-passage.layout-event` rule (a purple left border)
  is deliberately left in place until then, so those two passages don't go fully unstyled in the
  interim.

### `hub_early` / `hub_middle` / `hub_late` — ✅ built and visually approved

Built and confirmed: real three-layer composite (`leather_splattered.png` background + a
`border-image` outer frame on a `.mws-passage::after` pseudo-element, §1.2/§1.7/§1.8 — no parchment
panel, unlike narration/introduction: content is a left-aligned, scrollable stack of individually
bordered `hub-card` sections directly over the leather background), the single-scrollbar/
fixed-chrome architecture (§1.7) with a real `scroll_bar_lg.png` scrollbar-thumb image, narrow-mode
border crop (§1.1), the real round progress bar (§1.4, using the same fixed-`px`-aware `calc()`
positioning as narration/introduction), the same embossed title/subtitle treatment as narration/
introduction, and blue-bracket inline links (§1.6). Each `hub-card` section frame
(`borders/hub_section.png`) is its own `border-image` 9-slice too — its interior is fully
transparent (no baked-in gutter/shadow the way `panel_parchment.png` has), filled with a plain
translucent color behind the border-image layer for legibility over the leather background.

- **Reference**: `Module-05A/B-Hub-Early-Years*.png` (red), `Module-06-Hub-Middle-Years.png` (blue),
  `Module-07-Hub-Late-Years.png` (brown).
- **Structure**: title + subtitle (e.g. "Yellow Fever" / "Early Years") pinned to the top → 
  scrollable vertical stack of bordered sections → round-tracker footer in the border cutout.
- **Assets**: background `backgrounds/leather_splattered.png`; outer border `hub_red.png` /
  `hub_blue.png` / `hub_brown.png` (per-generation, same shared `border-image` slice/width as every
  other bordered layout — §1.8's amendment); section border `borders/hub_section.png`; scrollbar
  `inputs/scroll_bar_lg.png` (a real image asset here, unlike narration's plain-CSS scrollbar);
  inline links use **blue** brackets (`bracket-blue-left/right.png`), matching hub's distinct
  link-color rule from §1.6.
- Sections are not collapsible — full text always visible, matches using `section` nodes with
  `collapsed: false`.
- Gold background highlight seen in the screenshot is a Unity-only effect with no corresponding
  asset — per your note, omit it for now.
- The showcase index (`Example_Entry`/`01_Entry.mws.yaml`) itself uses `layout: 'hub_early'` and was
  restructured into grouped `hub-card` sections (Story Passages / Hub Passages / Popups) with an
  explicit round selector, so it doubles as an extra live example of this layout's card styling.

### `player_setup` passage layout (player count / name entry / town name) — ✅ built and visually approved

Built and confirmed across multiple rounds of screenshot feedback, wide and narrow: real
three-layer composite (`leather_large.png` background + `main.png` border, `main.png` has no
progress-bar cutout per §1.3), the single-scrollbar/fixed-chrome architecture (§1.7), narrow-mode
border crop (§1.1), `setup-alert`/`setup-input`/`setup-input-label` content styles, and
`btn-players-2/3/4` picker buttons using the real `players_2/3/4.png` assets (the old "no engine
support for image-backed nav buttons" note was overly cautious — it's a plain CSS `background-image`
on the link, no engine change needed). All `Setup_01`–`Setup_07` passages use `layout:
'player_setup'` with a shared title mechanism (passage-level `title:` field, not an inline text
node, so every setup screen's heading is pixel-identical). Input text color `#F2B781`, no native
focus outline. Continue links use the standard `btn-brown` button (§1.6) everywhere — every setup
passage was previously missing a `style:` on this link entirely, silently falling back to the
default blue underlined link.

**Renamed from `setup` to `player_setup` this round** — `setup` is the real, widely-used-across-
modules *popup* layout (the instructional icon popup, copied from cost-of-disease — see its own
entry below), and layout chrome is looked up purely by string regardless of whether a passage or a
popup uses the name (`docs/mws-format-latest.md` §8). This template's own passage-level chrome has
no equivalent real cross-module name to match (the `_Setup_0N_*.mws.yaml` passages are hand-rolled,
mirroring the reference app's player onboarding directly, and supersede whatever similarly-named
passages the extractor produces from leftover/unused Cradle source) — `player_setup` is a
template-only name, chosen just to stay clearly distinct from the popup.

- **Reference**: `Setup-01-Player-Count.png`, `Setup-03A/B-Player-Name-Entry*.png`,
  `Setup-05-Town-Name-Entry.png`.
- **Decided**: one shared `player_setup` passage layout, not three separate layout files — chrome
  (`backgrounds/leather_large.png` background, `main.png` border, no progress-bar cutout, see §1.3)
  is identical across all three; content differences are per-passage authoring, same pattern
  `narration` already uses for varying content.
- **Screen-specific content** (authored per-passage against the shared `player_setup` chrome):
  - **Player count** (`Setup-01`): 3 large buttons (`inputs/players_2.png` / `players_3.png` /
    `players_4.png`, each with a "N Players" caption below), centered on one row, reflowing to
    stacked on narrow viewports.
  - **Player name entry** (`Setup-03`): an info/alert row (darkened translucent background, gold
    text — uses the `icons/alert.png` icon) + prompt + a text input (`inputs/input_large.png`) +
    Continue.
  - **Town name entry** (`Setup-05`): same shape as name entry, plus a large "The Village" title.
- A gold background highlight is again a Unity-only effect — omit per your note.

### `setup_scenario` — resolved, not a real layout need

`00_Preparations.mws.yaml` was using `layout: 'setup_scenario'` (a genuine, distinct layout id —
confirmed against `cost-of-disease/layouts/setup_scenario.mws.yaml`, a real if still-unbuilt stub
there too), which read as a gap needing its own chrome built. Checked against the actual reference
screenshot (`Module-01A-Preparations.png`) instead of assuming: it's visually identical to any
other `narration` passage — same border/parchment/progress-bar chrome (footer shows "I-1"), just a
slightly larger title — matching what this doc's own `narration` entry already said about
`Module-01`. Repointed to `layout: 'narration'` directly; `setup_scenario` as a distinct built
layout isn't needed by this template after all.

`00_Preparations` is also now the one live example of `image` node `size`/`align` (format spec §6)
in this module — the reference screenshot shows the scenario-box art centered and modestly sized
mid-paragraph. Investigating this surfaced a real render gap in the code repo, now fixed: the
extractor and format reader already carried `size`/`align` correctly through the full pipeline
(`ImageNode` → `RenderedImage`), but `RenderedImageView.razor` silently dropped both when
generating the `<img>` tag. Fixed there (mirrors `RenderedTextView.razor`'s existing `AlignClass`
pattern; `size` applies as an inline `width: {N}px` — the most direct reading of the format spec's
"unitless size hint, units unspecified") plus matching `.mws-image.align-*` rules added to
`app.css`. Full `dotnet test` suite (526 tests) still green.

### `note` / `note_clear` (popup) — ✅ built and visually approved

Built and confirmed across multiple rounds: `layouts/note.mws.yaml` + `layouts/note_clear.mws.yaml`
(both empty chrome, CSS-only) and `style.css`'s shared `layout-note`/`layout-note_clear` rules —
`popup_paper_torn.png` background sized to its own aspect ratio on wide, a viewport-percentage box
on narrow (§1.7's fixed-footer pattern), standard `btn-brown` Okay button.

**`note_clear` is a new layout not in the original plan** — identical to `note` in every rule except
the backdrop, which is transparent instead of the standard darkened one (a single
`.mws-popup-overlay.layout-note_clear { background: transparent; }` override). Used for
`Setup_02`'s intro popup and the greeting popups of `Setup_03`–`Setup_06`, which show over an
already-empty `player_setup`-layout passage — nothing underneath worth dimming. `Setup_07`'s town-name
confirmation popup uses plain `note` (with backdrop) instead — it's the moment that hands off out of
the setup flow into real module content, where dimming the passage behind it reads better.

- **Reference**: `Setup-02-Player-Intro.png`, `Setup-04-Player-Greeting.png`,
  `Setup-06-Town-Name-Greeting.png` — three different moments (scenario intro blurb, per-player
  greeting, town-name greeting) that all use the **same simple torn-parchment popup**: header-free,
  just body text + a single action button.
- **Assets**: `backgrounds/popup_paper_torn.png`, standard brown button.
- **Distinct from the `setup` popup layout below** — that one (`Module-04`) has an icon/pin
  illustration and a different background asset (`popup_parchment_border.png` vs
  `popup_paper_torn.png`). These are two different popup shapes that happen to share the word
  "setup" informally.

### `setup` (popup) — ✅ locked in

This is the **real, widely-used-across-modules** instructional icon popup — brought across from
`cost-of-disease` (not template-specific content), so this layout_id has to stay exactly `setup` to
match every other module; renaming it (as an earlier pass in this session briefly, incorrectly did,
to `setup_info`) isn't an option — that would need an extractor change to match everywhere else
`setup` is already emitted, and this template is supposed to demonstrate the real names, not invent
new ones. The collision this created with this template's own passage-level chrome was real, but
belonged to the *other* side — see `player_setup`'s own entry above for how that got renamed
instead.

Modernized to match the current bordered-popup approach every other popup on this page now uses,
on top of the cost-of-disease original: `border-image` instead of `background-size: 100% 100%`
(measured `popup_parchment_border.png`'s own gutter: thin and uniform, ~1–1.5% each side — same
corner-distortion reasoning as everywhere else, §1.8), an explicit `font-size` reset (§1.7's own
rule that every popup layout needs one — missing here until now, silently inheriting whatever the
host passage's own ambient size happened to be), and a fixed-viewport footer (`position: fixed` +
`transform: translateX(-50%)`, matching `note`) instead of `position: absolute` relative to the
container, so the buttons stay reachable regardless of how tall the scrollable content area gets.

Demoed directly on the Layout Showcase hub (`Example_Entry`) now, not a separate passage — two
click-triggered variants side by side ("Okay only" / "Okay + Cancel") so both button counts are
exercised against the same layout. Okay always `target: 'Example_Entry', snapshot: false` — since
the trigger already lives on the hub, this is a no-op navigation that just closes the popup in
place; still explicit (not omitted) for consistency with how a real module's own end_of_round-style
popups use `target`.

- **Reference**: `Module-04A/B/C-Setup-Popup*.png` — instructional popup with a pinned icon
  illustration, appearing (A) triggered by a link, (B) auto-shown over an empty passage, (C)
  auto-shown over a hub passage.
- **Structure**: parchment background, "Setup" title (localizable), scrollable content area, fixed
  icon image with extra pin/stud decoration, two buttons centered on the bottom edge.
- **Assets**: `backgrounds/popup_parchment_border.png`; `popup/setup_icon_background.png`;
  `popup/setup_brass_stud.png` (there's also a `popup/setup_paperclip.png` not mentioned in the
  summary table — **OPEN QUESTION**, still unresolved: is the paperclip used here too, or a
  leftover from a different screen?); standard green Okay / red Cancel buttons.

### `end_of_round` / `end_of_generation` (popups) — ✅ locked in

Built and confirmed — corrected a real asset-name bug found while rebuilding: the previous rough
pass referenced `backgrounds/popup_parchment_ragged.png`, which doesn't exist in this pack at all
(the popup silently fell back to no background). Now uses the correct
`popup_parchment_border_short.png` per the summary table. Two distinct layout ids sharing one CSS
block via combined selectors (identical sizing, only header/body text differs per instance) — see
`docs/mws-format-latest.md` §7's own worked examples, which already treat `end_of_round` and
`end_of_generation` as separate layout values, not one shared name. The clock icon is a
`.style-popup-title::before` CSS pseudo-element now, not a separate `header:` region image node —
`{icon:...}` inline syntax only ever resolves `icon://`, and `generation_time.png` lives under
`assets/images/popup/`, so a header region would have needed extra CSS just to sit inline with the
title text on one row anyway; the pseudo-element sidesteps both problems.

Demoed directly on the Layout Showcase hub, same okay-only/okay+cancel pairing as `setup`.

- **Reference**: `Module-08A/B-End-of-Round-popup*.png` (alt B = different body text, same layout),
  `Module-12-End-of-Generation-popup.png` (same layout, different header text — confirmed the same
  popup layout *shape*, header text supplied by the popup node itself, but still two layout ids per
  the format spec's own examples — see above).
- **Structure**: fixed-size popup, icon + title on one row, body text, single button centered on the
  bottom edge.
- **Assets**: `backgrounds/popup_parchment_border_short.png`, `popup/generation_time.png` (clock
  icon), standard green button.

### Bidding preamble popup — `Module-09` — 🟡 still open, not built this round

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

### `prompt` (popup) — ✅ locked in

Built and confirmed. `popup_bordered.png` (961×299, corner-bracket ornaments only — measured: opaque
art touches the canvas edge with no connecting frame between corners, so `border-image` mostly just
keeps the corners themselves from stretching) holds the instructional prompt text, no scroll. The
`<input>` itself is a **fixed size** (`20rem` × `3.2rem`, not a percentage/`max-width`-constrained
box like `.style-setup-input`) per your note — reads as the same prominent, centered field
regardless of the popup's own container width, reusing `input_large.png` (same asset/technique as
setup's own input). Demoed directly on the Layout Showcase hub, okay-only/okay+cancel pair, bound
to a dedicated `demoInputValue` session variable.

- **Reference**: `Module-11A-Input-popup.png`, `Module-11B-Input-popup-with-numeric-value.png`.
- **Structure**: fixed border popup, larger-than-normal prompt text (centered, no scrolling), a
  large fixed-size input field below it, action buttons anchored to the true viewport (same
  fixed-footer technique `note` uses) below that.
- **Assets**: `backgrounds/popup_bordered.png`, `inputs/input_large.png`, standard brown (okay) /
  red (cancel) buttons.
- Named `prompt`, not `input` — `input` is already a node type name (format spec §6), and this
  layout's own content always includes an `input` node; keeping the two distinct avoids "input the
  layout" vs. "input the node" ambiguity in prose/comments elsewhere.

### `choice` — ✅ locked in — not a real requirement, generic bordered popup only

Re-scoped this round, not fully reworked: per your note, this was never a real requirement beyond
*at most* `General-Standalone-Select-Dialog.png` itself (screenshot-summary.md's own General-01
breakdown: "could be adapted to either a passage or popup layout as needed... Fixed size panel.
Large header, centered. Content, centered") — a generic bordered popup, not a bespoke radio-select
UI worth building out. The radio-button assets (`radio_selected.png`/`radio_unselected.png`)
mentioned in the prior draft are **not** used — a true radio-group input type is still an open
MWS-format question (unchanged from before, not blocking), and this layout's real ongoing job is
exercising the **checkbox** input style, which scoring's Tie-Break 1 genuinely needs
(`Scoring-03A/B`). Built a general (not choice-specific) `.mws-input input[type="checkbox"]` style
using `checkbox_outline.png`/`checkbox_checkmark.png` — reusable as-is once `score_panel` is built.

- **Reference**: `General-Standalone-Select-Dialog.png` ("Choose Audio Voice") — filename corrected
  from the first draft's "Standaline" typo.
- **Structure**: dark bordered box (`backgrounds/panel_general.png`, measured: opaque right to every
  edge, no transparent gutter — a solid riveted-metal frame, still moved to `border-image` so the
  corner rivets don't stretch into ovals at a different aspect ratio than the card's own), centered
  header, centered content, Continue button.
- Demoed directly on the Layout Showcase hub — a single trigger (not an okay-only/okay+cancel pair
  like the other popups this round, since it's not one of the four real requirements), showing the
  checkbox styling via the existing "Feminine" boolean demo content.

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

**Done this session**: `en-US.restext` written for the template, covering every user-facing string
in the seven `Setup_*` and four `Scoring_*` hand-authored passages (`Setup_*`/`Scoring_*`/
`Common_*` keys — one shared `Common_Continue` reused everywhere the label is literally
"Continue"). None of these passages reference cost-of-disease's extracted restext keys
(`TCOD_TownName_*`, `PlayerNameIntro_*`, `NameEntryTownConfirm_*`, `Number_*_Lower`) anymore. Still
to do: copy this restext (plus the passages/layouts themselves) back into the real modules during
template integration — the keys are namespaced specifically so they won't collide with a target
module's own extracted restext.

Still open, layered on top of the pure CSS/asset/layout work above and probably deserving separate
scoping:

1. ~~`event` layout mapping~~ — **done**, see §2's special event overlay entry. Still outstanding:
   re-running extraction on `cost-of-disease` (its `AngryMobStorybook`/`TipsnTricks` passages still
   carry the old `layout: event` until that happens) — a separate, bigger action not taken as a
   side effect of the extractor change itself.
2. **Score/tie-break row `section` wrapping** (§2 `score_panel`) — `ScoreEntry`, `TieBreaker1`,
   `TieBreaker2` passage overrides need each player row restructured from flat `text`/`input`
   sequences into `section`-wrapped rows so `player_highlight.png` can be applied as a per-row
   background. Hand-authored override change, not extractor. Not started — `score_panel`/`ranking`
   only got their restext keys this session, no visual/structural work yet.
3. **`Scoring_04_Ranking.mws.yaml` still uses `{icon:crown}`**, which doesn't resolve — the asset is
   `assets/images/inputs/ranking_crown.png` (an `image://inputs/ranking_crown` reference), not an
   `icons/` asset. Needs an `image` node instead of the `{icon:...}` inline pattern. Confirmed still
   present, not yet fixed — will render as a missing-icon placeholder until it is.
4. **Radio-group input** (§2 `choice`) — format-level question (new input type vs. styled
   booleans); not blocking, but worth a decision before building `choice` for real.
5. **Standard-name-with-fallback background pattern** (§2 `narration`/`introduction`) —
   `scenario_narration_background.png` (module-specific) falling back to `backgrounds/leather_large.png`
   (shared) needs to be a supported resolution behavior, not just a convention — **OPEN QUESTION**:
   does `AssetResolver`/CSS already support an image-not-found fallback chain, or does this need new
   engine/CSS work (e.g. a CSS `background-image` list with multiple `url()` fallbacks isn't
   standard — more likely this means the module CSS always references
   `image://scenario_narration_background`, and each real module supplies that file, with
   `leather_large.png` used only in the *template* module where no module-specific art exists)?
6. **app.css's `.mws-passage` wide-viewport bug** (§1.7) — `@media (min-width: 48rem) {
   .mws-passage { max-width: 40rem; margin: 0 auto; padding: 1.5rem; } }` has no `layout-`
   qualifier, so it silently caps every passage to 640px wide unless that specific layout overrides
   it. `player_setup` does; every future layout will need to as well unless this gets fixed once in
   app.css directly instead. Worth doing since it'll otherwise bite every new layout the same way.
7. ~~`setup`'s own outer padding is still `rem`-based, not `vh`/`vw`~~ — **resolved**: superseded by
   §1.8's amendment, which moved every bordered layout's padding to fixed `px` (not `vh`/`vw`) to
   stay in sync with the now-fixed-`px` `border-image-width`. `player_setup`'s own padding is
   already `px` (`50px 30px 25px`) as of this round, consistent with `narration`/`introduction`/
   `hub_*`'s `50px 30px 40px` — no longer an open gap. `note`/`note_clear`/the `setup` popup remain
   a **different, intentional** case — see §1.8's third bullet — their `rem` + `border-image`/
   `height: auto` sizing is correct as-is, not meant to match the fixed-viewport-border layouts.

## 4. Not in scope here (app-level, not module content)

Main menu, options/settings, pause popup (`Module-00`), help, scenario select
(`App-01`–`App-04`), log book/achievements gallery — either app-shell chrome (not a module's
`layouts/` folder) or Phase 3 (achievements, deferred). Listed for completeness only.
